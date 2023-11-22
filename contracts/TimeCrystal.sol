// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "ILogAutomation.sol";
import "IGameLogic.sol";

contract TimeCrystal is FunctionsClient, ConfirmedOwner, VRFConsumerBaseV2 {
    using FunctionsRequest for FunctionsRequest.Request;


    //            CHAINLINK AUTOMATION, FUNCTIONS, AND VRF VARIABLES          //

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

    address LINKToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
  
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
    }

    

    //          GAME STATE VARIABLES        //

    mapping (address => string) keys;
    mapping (address => bytes) public hands;
    mapping (address => uint[]) vrfSeeds;
    mapping (address => bool) public inGame;
    mapping (address => bool) public inQueue;
    mapping (address => uint) public currentMatch;
    mapping (address => address) public currentOpponent;
    mapping (address => bool) public isPlayer1;
    mapping (address => uint) public lastCommit;

    //Test
    string public testWin = "Not yet";

    address[2] matchmaker;
    uint matchIndex;
    bytes[] player1;
    bytes[] player2;

    mapping (bytes32 => address) public functionsRequestIdbyRequester;
    mapping (uint => address) public vrfRequestIdbyRequester;
    mapping (address => upkeepType) pendingUpkeep;

    enum upkeepType {
        MATCHMAKING,
        CHECK_VICTORY
    }


    //                 PLAYER GAME INTERACTIONS                 //


    // Register the player AES key and banked VRF values.
    // RSA-encrypted AES key is provided as a base64 string.
    function registerPlayerKey(string calldata _key) external {
        keys[msg.sender] = _key;
        requestRandomWords();
  }

    // The player needs to provide a deposit to deter griefing and self-farming.
    // This is either a separate function (a pool from which the deposit can be slashed)
    // Or the deposit is provided when getting the hand.

    // Prepare for a game by asking the oracle for a SHA256 hash containing secret information.
    // Encrypted secret password + inventory, and iv are provided as base64 strings.
    // The Functions callback will trigger the Automation DON, pushing the player into the matchmaking queue.
    function getHand(string calldata secrets, string calldata iv) external {
        require (inGame[msg.sender] == false);
        require (inQueue[msg.sender] == false);
        require (hands[msg.sender].length == 0);

        uint[] memory seeds = vrfSeeds[msg.sender];

        if (seeds.length == 0) {
            revert("Call VRF");
        }

        inQueue[msg.sender] = true;

        //Test
        testWin = "Not yet";

        FunctionsRequest.Request memory req;
        req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, start_game_source);
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;

        string[] memory args = new string[](4);
        args[0] = keys[msg.sender];
        args[1] = secrets;
        args[2] = iv;
        args[3] = Strings.toString(seeds[seeds.length - 1]);
        //args[4] = on-chain deck
        vrfSeeds[msg.sender].pop();
        

        req.setArgs(args);
        //req.setBytesArgs(args);

        s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        functionsRequestIdbyRequester[s_lastRequestId] = msg.sender;
    }


    // Evaluates the effect of a card.  All cards are assumed to be valid.
    // Players must wait 3 blocks in between cards.
    // Note to self: keep it simple.
    function makeMove() external {
        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        require(lastCommit[msg.sender] + 3 <= block.number);
        lastCommit[msg.sender] = block.number;
        if (isPlayer1[msg.sender]) {

        }

    }


    // End the game by providing the constituent values of your oracle-generated hash.
    // Automation will check your win condition, and the validity of your cards.
    function declareVictory(bytes calldata secret) external {
        //potentially the secret could come in as bytes32 instead, or a string
        require(inQueue[msg.sender] == false);
        require(keccak256(abi.encode(hands[msg.sender])) == keccak256(abi.encode(sha256(secret))));

        // The game immediately ends and goes to Automation to determine the winner
        address opponent = currentOpponent[msg.sender];

        inQueue[opponent] = true;
        inGame[opponent] = false;
        inQueue[msg.sender] = true;
        inGame[msg.sender] = false;

        pendingUpkeep[msg.sender] = upkeepType.CHECK_VICTORY;
        emit AwaitingAutomation(msg.sender);
    }



    //              GODOT VIEW FUNCTIONS            //


    // Public Getters:

    //      keys(msg.sender)

    //      Retrieves the SHA256 hash of the player's secret password, random cards, and inventory.
    //      hands(msg.sender)

    //      inQueue(msg.sender)

    //      inGame(msg.sender)

    //      eth.blockNumber 

    //      testWin()

    function seeBoard() public view returns (bytes memory) {
        if (isPlayer1[msg.sender] == true) {
            return player1[currentMatch[msg.sender]];
        }
        else {
            return player2[currentMatch[msg.sender]];
        }
    }

    function seeOpponentBoard() public view returns (bytes memory) {
        if (isPlayer1[msg.sender] == true) {
            return player2[currentMatch[msg.sender]];
        }
        else {
            return player1[currentMatch[msg.sender]];
        }
    }

    function hasSeedsRemaining() public view returns (bool) {
        if (vrfSeeds[msg.sender].length > 0) {
            return true;
        }
        else {
            return false;
        }
    }



    //              VRF REQUEST FULFILLMENT              //

    // 10 VRF values are banked for use as seeds when asking Chainlink Functions for a random hand.
    // This is also the payment gateway for the player.  Players must provide LINK upfront to cover
    // the cost of Chainlink services used during play.
 
    function requestRandomWords() private {
        // pay LINK to cover 10 matches here
        // player must approve allowance first
        IERC20(LINKToken).transferFrom(msg.sender, address(this), 1e18);
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            10
            );
        vrfRequestIdbyRequester[requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        vrfSeeds[vrfRequestIdbyRequester[requestId]] = randomWords;
    }





    //            FUNCTIONS REQUEST FULFILLMENT            //


    // Provides a secret hand drawn from a secretly shuffled deck.  Also contains secret inventory selected by the player.
    // Asks Chainlink Automation to move the player into matchmaking.
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {

        address player = functionsRequestIdbyRequester[requestId];

        // Response is a SHA256 hash against which the player will run a birthday attack
        // to extract the encoded secret random cards
        hands[player] = response;

        // Moves player to matchmaking queue
        if (err.length == 0) {
            pendingUpkeep[player] = upkeepType.MATCHMAKING;
            emit AwaitingAutomation(player);
            }
    
        s_lastError = err;
        emit RequestFulfilled(requestId, response);
  }





    //       AUTOMATION AND GAMEPLAY VALIDATION          //

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
  ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address player = address(uint160(uint256(log.topics[1])));
        upkeepNeeded = true;
        performData = abi.encode("");
        if (pendingUpkeep[player] == upkeepType.MATCHMAKING) {

        }
        if (pendingUpkeep[player] == upkeepType.CHECK_VICTORY) {
            // Extract win condition
            //secret[secret.length-1]
            //if valid:
            // Evaluate the player's cards against the provided secret

            //else:
            //other player wins automatically
            // declareWinner(currentOpponent[msg.sender])

        }
        //currentOpponent[player]
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


    // MATCHMAKING: Moves the player into the queue, and starts a game if two players are ready.
    // CHECK_VICTORY: Evaluates the player's win condition, and their secret cards against their used cards.
    function performUpkeep(
        bytes calldata performData
    ) external {
        require(msg.sender == forwarder);

        (address player, bytes memory params) = abi.decode(performData, (address, bytes));
        
        if (pendingUpkeep[player] == upkeepType.MATCHMAKING) {
            // Test Opponent
            matchmaker[0] = vrfCoordinator;

            address _player1 = matchmaker[0];
            address _player2 = matchmaker[1];
            if (_player1 == address(0x0)) {
                matchmaker[0] = player;
                }
            else {
                matchmaker[1] = player;

                matchIndex++;

                currentMatch[_player1] = matchIndex;
                isPlayer1[_player1] = true;
                currentOpponent[_player1] = matchmaker[1];
                player1.push(bytes(""));
                inQueue[_player1] = false;
                inGame[_player1] = true;
                matchmaker[0] = address(0x0);

                currentMatch[_player2] = matchIndex;
                isPlayer1[_player2] = false;
                currentOpponent[_player2] = matchmaker[0];
                player2.push(bytes(""));
                inQueue[_player2] = false;
                inGame[_player2] = true;
                matchmaker[1] = address(0x0); 
                }
            }

        else if (pendingUpkeep[player] == upkeepType.CHECK_VICTORY) {

            // Declare winner and disburse reward / deposit

            // Reinitialize both players
            inQueue[player] = false;
            inGame[player] = false;
            hands[player] = bytes("");

            address opponent = currentOpponent[player];

            inQueue[opponent] = false;
            inGame[opponent] = false;
            hands[opponent] = bytes("");


            //Test 
            testWin = "You won!";
            }

        emit UpkeepFulfilled(performData);

        }

 



    //          MAINTENANCE FUNCTIONS AND EVENTS            //



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

    function withdrawLink() external {
        IERC20(LINKToken).transferFrom(address(this), owner(), IERC20(LINKToken).balanceOf(address(this)));
    }


    event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
    event AwaitingAutomation(address indexed _player);
    event UpkeepFulfilled(bytes indexed _performData);

  
}
