// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "ILogAutomation.sol";
import "IGameLogic.sol";

contract TimeCrystal is FunctionsClient, ConfirmedOwner, VRFConsumerBaseV2 {
  using FunctionsRequest for FunctionsRequest.Request;

  bytes32 public donId;
  address private forwarder;
  address public gameAutomation;

  bytes32 public s_lastRequestId;
  bytes public s_lastResponse;
  bytes public s_lastError;

  string public start_game_source;
  string public take_turn_source;
  string public register_opponent_source;
  FunctionsRequest.Location public secretsLocation;
  bytes encryptedSecretsReference;
    //uint64 subscriptionId = 1600;
  uint64 subscriptionId = 1686;
  uint32 callbackGasLimit = 300000;

  uint64 s_subscriptionId;
    address s_owner;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 s_keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint16 requestConfirmations = 3;
  

  constructor(address _vrfCoordinator, address router, address _gameAutomation, bytes32 _donId, string memory _source,  string memory _source2, string memory _source3, FunctionsRequest.Location _location, bytes memory _reference, cardTraits[] memory _cards) FunctionsClient(router) VRFConsumerBaseV2(_vrfCoordinator) ConfirmedOwner(msg.sender) {
    donId = _donId;
    start_game_source = _source;
    take_turn_source = _source2;
    register_opponent_source = _source3;
    secretsLocation = _location;
    encryptedSecretsReference = _reference;
    gameAutomation = _gameAutomation;
    for (uint z = 0; z < _cards.length; z++) {
        cards[Strings.toString(z + 10)] = _cards[z];
    }
    initialize();
  }

    enum requestType {
        GET_HAND,
        CHECK_VICTORY
  }

    mapping (address => string) keys;
    mapping (address => bytes) public hands;
    mapping (address => uint[]) vrfSeeds;
    mapping (address => bool) public inGame;
    mapping (address => bool) public inQueue;
    mapping (address => uint) public currentMatch;
    mapping (address => bool) public isPlayer1;

    address[2] matchmaker;
    uint matchIndex;
    bytes[] player1;
    bytes[] player2;

    mapping (bytes32 => address) public functionsRequestIdbyRequester;
    mapping (bytes32 => requestType) public pendingFunctionsRequests;
    mapping (uint => address) public vrfRequestIdbyRequester;

    // Register the user AES key and banked VRF values.
    // RSA-encrypted AES key is provided as a base64 string.
    function registerPlayerKey(string calldata _key) external {
        keys[msg.sender] = _key;
        requestRandomWords();
  }

    // Prepare for a game by asking the oracle for a SHA256 hash containing secret information.
    // Encrypted secret password + inventory, and iv are provided as base64 strings.
    function getHand(string calldata secrets, string calldata iv) external {
        require (inGame[msg.sender] == false);
        require (inQueue[msg.sender] == false);
        require (hands[msg.sender].length == 0);
        if (vrfSeeds[msg.sender].length == 0) {
            revert("Call VRF");
        }
        //pay LINK here
        inQueue[msg.sender] = true;

        FunctionsRequest.Request memory req;
        req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, start_game_source);
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;

        string[] memory args = new string[](3);
        args[0] = secrets;
        args[1] = iv;
        args[2] = Strings.toString(vrfSeeds[msg.sender][vrfSeeds[msg.sender].length - 1]);
        vrfSeeds[msg.sender].pop();

        req.setArgs(args);
        //req.setBytesArgs(args);

        s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        functionsRequestIdbyRequester[s_lastRequestId] = msg.sender;
        pendingFunctionsRequests[s_lastRequestId] = requestType.GET_HAND;
    }

    // Joins the matchmaking room.
    function joinGame() external {
        require(inGame[msg.sender] == false);
        inGame[msg.sender] = true;
        if (matchmaker[0] == address(0x0)) {
            matchmaker[0] = msg.sender;
        }
        else {
            matchmaker[1] = msg.sender;
            startGame();
        }
    }

    // Assigns the players their index in the dueling match arrays.
    function startGame() internal {
        currentMatch[matchmaker[0]] = matchIndex;
        isPlayer1[matchmaker[0]] = true;
        player1.push(bytes(""));
        matchmaker[0] = address(0x0);
        currentMatch[matchmaker[1]] = matchIndex;
        isPlayer1[matchmaker[1]] = false;
        player2.push(bytes(""));
        matchmaker[1] = address(0x0);
    }

    // Evaluates the effect of a card.  All cards are assumed to be valid.
    function makeMove() external {

    }

   // function randomEvent() external {
    // require(msg.sender == forwarder);

    //}

    // End the game by providing the constituent values of your oracle-generated hash.
    // If the win condition has been fulfilled, Automation will check your values against the cards you have played.
    function declareVictory() external {

    }

    function requestRandomWords() private {
        //pay LINK here
        uint256 requestId = COORDINATOR.requestRandomWords(
    s_keyHash,
    s_subscriptionId,
    requestConfirmations,
    callbackGasLimit,
    20
  );
  vrfRequestIdbyRequester[requestId] = msg.sender;
}

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        vrfSeeds[vrfRequestIdbyRequester[requestId]] = randomWords;
    }



//            FUNCTIONS REQUEST FULFILLMENT            //


    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {

        if (pendingFunctionsRequests[requestId] == requestType.GET_HAND) {
            inQueue[functionsRequestIdbyRequester[requestId]] = false;
            hands[functionsRequestIdbyRequester[requestId]] = response;
            }
    
    s_lastError = err;
    emit RequestFulfilled(requestId, response);
  }


//  AUTOMATION AND GAMEPLAY VALIDATION  //

    enum cType {
    CONSTRUCT, //persistent units
    CRYSTAL,  //persistent structures
    POWER, //tactical spells
    ORACLE //strategic spells
  }

    enum cardKeyword {
    NONE,
    DESTROY,  //destroy target
    DAMAGE1,  //deal 1 damage to target
    DAMAGE2, //deal 2 damage to target
    REGENERATE2, //spend 2 energy to regenerate
    HEAL1, //player heals 1 damage 
    SHIELD, //prevent damage to target
    AIM, //may pick target when attacking
    ST_SHIELD, //give shield when entering the field
    ST_HEAL1, //heals player for 1 when entering the field
    ST_DAMAGE1 //deals 1 damage to target when entering the field
    //DRAW
    //QUERY
  }

    struct cardTraits {
    uint8 cardNumber;
    string cardName;
    cType cardType;
    uint8 attack;
    uint8 defense;
    cardKeyword keywordA;
    cardKeyword keywordB;
    uint8 energyCost;
  }



    mapping (string => cardTraits) cards;

    function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        address player = address(uint160(uint256(log.topics[1])));
        upkeepNeeded = true;
        performData = abi.encode("");
        //performData = abi.encode(player, requestType.REGISTER_PLAYER, abi.encode(stuff));
        return (upkeepNeeded, performData);
  }

  //credit: stackoverflow
    function strToUint(string memory _str) public pure returns(uint256 result) {
    
    for (uint256 i = 0; i < bytes(_str).length; i++) {
        if ((uint8(bytes(_str)[i]) - 48) < 0 || (uint8(bytes(_str)[i]) - 48) > 9) {
            return 0;
        }
        result += (uint8(bytes(_str)[i]) - 48) * 10**(bytes(_str).length - i - 1);
    }
    
    return result;
    }



    function performUpkeep(
        bytes calldata performData
    ) external {
       // require(msg.sender == forwarder);

        //(address player, requestType upkeepType, bytes memory params) = abi.decode(performData, (address, requestType, bytes));
        

            emit UpkeepFulfilled(performData);

        }

 

  /**
   * @notice Set the DON ID
   * @param newDonId New DON ID
   */
    function setDonId(bytes32 newDonId) external onlyOwner {
        donId = newDonId;
  }

    function updateSecret(bytes calldata _secrets) external onlyOwner {
        encryptedSecretsReference = _secrets;
  }

   
    function setForwarderAddress(
        address _forwarder
    ) public onlyOwner {
       forwarder = _forwarder;
    }

    bool initialized;
    function initialize() public {
        if (!initialized) {
            initialized = true;
            //playerHands.push("");
            //gameUpdates.push("");
        }
    }


    event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
    event AwaitingAutomation(address indexed _player);
    event UpkeepFulfilled(bytes indexed _performData);

  
}
