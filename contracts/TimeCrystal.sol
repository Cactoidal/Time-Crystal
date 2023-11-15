// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "ILogAutomation.sol";

contract RemixTester is FunctionsClient, ConfirmedOwner, AutomationCompatibleInterface {
  using FunctionsRequest for FunctionsRequest.Request;

  bytes32 public donId;
  address private s_keeperRegistryAddress;

  bytes32 public s_lastRequestId;
  bytes public s_lastResponse;
  bytes public s_lastError;

  string public start_game_source;
  string public take_turn_source;
  FunctionsRequest.Location public secretsLocation;
  bytes encryptedSecretsReference;
  uint64 subscriptionId = 1600;
  uint32 callbackGasLimit = 300000;
  

  constructor(address router, bytes32 _donId, string memory _source,  string memory _source2, FunctionsRequest.Location _location, bytes memory _reference, address _keeperRegistryAddress) FunctionsClient(router) ConfirmedOwner(msg.sender) {
    donId = _donId;
    start_game_source = _source;
    take_turn_source = _source2;
    secretsLocation = _location;
    encryptedSecretsReference = _reference;
    setKeeperRegistryAddress(_keeperRegistryAddress);
  }

  enum requestType {
    TAKE_TURN,
    START_GAME
  }
  


  mapping (bytes32 => address) public requestIdbyRequester;

  uint public nonceCounter = 1;
  mapping (bytes32 => requestType) public pendingRequests;
  mapping (uint => bool) public usedSeeds;
  mapping (string => bool) usedCounters;

  mapping (address => string) registeredKeys;
  mapping (address => bool) playerKeyRegistered;

  mapping (address => bytes) public decryptedMessage;


//             NEW GAME STUFF             //    

    //temp
    string[3] public currentOpponent;
    uint8 public currentTurn = 1;
    string[] public opponentCards;
    string[] public playerCards;
    uint public gameSeed;
    string public gameCounter;
    string gameNonce = "1";
    string public playerDeck;

    function registerPlayerDeck(string calldata _deck) public {
        playerDeck = _deck;
    }

    //RSA-encrypted AES key, AES-encrypted deck/logic, and the iv used to encrypt
    //all provided as base64 strings
    function registerOpponentDeck(string calldata _key, string calldata _deck, string calldata _iv) public {
        
        string[3] memory newOpponent;
        newOpponent[0] = _key;
        newOpponent[1] = _deck;
        newOpponent[2] = _iv;
        currentOpponent = newOpponent;
    }


    //counter here is a base64 string
    //seed will eventually come from VRF and be validated
    //I will need to validate the counter later
    function startGame (uint _seed, string calldata _counter) external {
    //require (usedCounters[_counter] == false);
    //require (usedSeeds[_seed] == false);
    //usedSeeds[_seed] = true;
    //usedCounters[_counter] = true;
    FunctionsRequest.Request memory req;
    req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, start_game_source);
    req.secretsLocation = secretsLocation;
    req.encryptedSecretsReference = encryptedSecretsReference;
    
    gameSeed = _seed;
    gameCounter = _counter;
    
    string[] memory args = new string[](4);
    args[0] = Strings.toString(_seed);
    args[1] = _counter;
    args[2] = gameNonce;
    args[3] = playerDeck;

    req.setArgs(args);
    //req.setBytesArgs(args);

    s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    requestIdbyRequester[s_lastRequestId] = msg.sender;
    pendingRequests[s_lastRequestId] = requestType.START_GAME;


  }

    function progressGame (uint8 _action) external {

    FunctionsRequest.Request memory req;
    req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, take_turn_source);
    req.secretsLocation = secretsLocation;
    req.encryptedSecretsReference = encryptedSecretsReference;

    
    string[] memory args = new string[](9);
    args[0] = playerCards[_action];
    args[1] = currentOpponent[0];
    args[2] = currentOpponent[1];
    args[3] = currentOpponent[2];
    args[4] = Strings.toString(currentTurn);
    args[5] = Strings.toString(gameSeed);
    args[6] = gameCounter;
    args[7] = gameNonce;
    args[8] = playerDeck;

    playerCards[_action] = playerCards[playerCards.length - 1];
    playerCards.pop();

    currentTurn += 1;

    req.setArgs(args);
    //req.setBytesArgs(args);

    s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    requestIdbyRequester[s_lastRequestId] = msg.sender;
    pendingRequests[s_lastRequestId] = requestType.TAKE_TURN;


  }

    function getPlayerCards() public view returns (string[] memory) {
        return playerCards;
    }

    function getOpponentCards() public view returns (string[] memory) {
        return opponentCards;
    }

   function resetGame() public {
        currentTurn = 1;
        string[] memory empty;
        opponentCards = empty;
        playerCards = empty;
    }




//            REQUEST FULFILLMENT            //


  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    
    if (pendingRequests[requestId] == requestType.START_GAME) {
        string[3] memory newCards;
        uint index = 0;
        for (uint i = 0; i < 3; i++) {
            bytes memory card = new bytes(2);
            card[0] = response[index];
            index += 1;
            card[1] = response[index];
            index += 1;
            newCards[i] = string(card);
        }
        playerCards = newCards;
    }

    else if (pendingRequests[requestId] == requestType.TAKE_TURN) {

        emit WaitingForUpkeep(requestIdbyRequester[requestId], response);
        //bytes memory opponentCard = new bytes(2);
        //bytes memory playerCard = new bytes(2);
        //opponentCard[0] = response[0];
        //opponentCard[1] = response[1];
        //playerCard[0] = response[2];
        //playerCard[1] = response[3];
        //opponentCards.push(string(opponentCard));
        //playerCards.push(string(playerCard));
    }
    
    s_lastResponse = response;
    s_lastError = err;
    emit RequestFulfilled(requestId, response);
  }


//  AUTOMATION AND GAMEPLAY VALIDATION  //

  enum cType {
    CONSTRUCT,
    CRYSTAL,
    ORACLE
  }

  enum cardKeyword {
    DESTROY,
    DAMAGE1,
    DAMAGE2,
    REGENERATE2,
    HEAL1,
    SHIELD
  }

  struct cardTraits {
    cType cardType;
    uint8 attack;
    uint8 defense;
    cardKeyword traitA;
    cardKeyword traitB;
  }

  mapping (uint => cardTraits) cards;

  struct gameSession {
    uint8 playerHealth;
    uint8 opponentHealth;
    uint8[] playerCards;
    uint8[] opponentCards;
  }

  mapping (address => bool) inSession;
  mapping (address => gameSession) currentSession;
  mapping (address => bool) awaitingAutomation;


  function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        bytes memory opponentCard = new bytes(2);
        bytes memory playerCard = new bytes(2);
        opponentCard[0] = log.topics[2][0];
        opponentCard[1] = log.topics[2][1];
        playerCard[0] = log.topics[2][3];
        playerCard[1] = log.topics[2][4];
        //opponentCards.push(string(opponentCard));
        //playerCards.push(string(playerCard));
        upkeepNeeded = true;
        performData = abi.encode(string(opponentCard), string(playerCard));
        return (upkeepNeeded, performData);

  }


    /**
     * @notice Called by Chainlink Automation Node to send funds to underfunded addresses
     * @param performData The abi encoded list of addresses to fund
     */
    function performUpkeep(
        bytes calldata performData
    ) external override onlyKeeperRegistry {
        (string memory opponentCard, string memory playerCard) = abi.decode(performData, (string, string));
        opponentCards.push(string(opponentCard));
        playerCards.push(string(playerCard));
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

    /**
     * @notice Sets the Chainlink Automation registry address
     */
    function setKeeperRegistryAddress(
        address keeperRegistryAddress
    ) public onlyOwner {
        require(keeperRegistryAddress != address(0));
        s_keeperRegistryAddress = keeperRegistryAddress;
    }

    modifier onlyKeeperRegistry() {
        if (msg.sender != s_keeperRegistryAddress) {
            revert OnlyKeeperRegistry();
        }
        _;
    }

    error OnlyKeeperRegistry();




  event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
  event WaitingForUpkeep(address indexed _player, bytes indexed _gameData);
  event UpkeepFulfilled(bytes indexed _performData);

    //is this needed?
   function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
    }

  
}
