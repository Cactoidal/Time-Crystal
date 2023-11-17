// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "ILogAutomation.sol";
import "IGameLogic.sol";

contract RemixTester is FunctionsClient, ConfirmedOwner, VRFConsumerBaseV2 {
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
  uint64 subscriptionId = 1600;
  uint32 callbackGasLimit = 300000;
  

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

  enum requestType {
    TAKE_TURN,
    START_GAME,
    REGISTER_OPPONENT
  }
  

  mapping (bytes32 => address) public requestIdbyRequester;

  uint public nonceCounter = 1;
  mapping (bytes32 => requestType) public pendingRequests;
  mapping (uint => bool) public usedSeeds;
  mapping (string => bool) usedCounters;


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

    enum validationType {
    PLAYER,
    OPPONENT
  }

  struct Player {
    uint8[] inventory;
    string[] playerDecks;
    Opponent[] opponentDecks;
    uint pendingOpponentIndex;
    bool inQueue;
    bool inGame;
    uint VRFindex;
    uint[] VRFseeds;
    bool registered;
  }

  struct cardActions {
        string[] doers;
        string[] targets;
        uint[] action;
        cardKeyword[] ability;
    }

    struct gameSession {
        string[] playerHand;
        uint8 playerHealth;
        uint8 opponentHealth;
        string[] playerCards;
        string[] opponentCards;
        bytes updateBytes;
        validationType updateType;
        bool updateInFlight;
        cardActions pendingActions;
        uint8 currentTurn;
  }

    mapping (address => Player) public players;
    mapping (address => gameSession) public currentSession;

    struct Opponent {
        string key;
        string deck;
        string iv;
        bool registered;
    }

    function registerPlayer() public {
        require (players[msg.sender].registered == false);
        players[msg.sender].inventory = [10,11,12,13,14,15,16,17,18,19,20];
        createPlayerDeck([0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,10]);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        
    }

    function createPlayerDeck(uint8[20] memory cardIndices) public {
        uint8[] memory inventory = players[msg.sender].inventory;
        string memory newDeck = "";
        for (uint y = 0; y < 20; y++) {
            newDeck = string.concat(newDeck, Strings.toString(inventory[cardIndices[y]]));
            if (y != 19) {
                newDeck = string.concat(newDeck, ",");
            }
        }
        players[msg.sender].playerDecks.push(newDeck);
    }

    //RSA-encrypted AES key, AES-encrypted deck/logic, and the iv used to encrypt
    //all provided as base64 strings
    //automation will submit after manipulating inventory into an array of strings
    function registerOpponentDeck(string calldata _key, string calldata _deck, string calldata _iv) public {
        require (players[msg.sender].inGame == false);
        require (players[msg.sender].inQueue == false);
        players[msg.sender].inQueue = true;

        Opponent memory newOpponentDeck;
        newOpponentDeck.key = _key;
        newOpponentDeck.deck = _deck;
        newOpponentDeck.iv = _iv;

        players[msg.sender].opponentDecks.push(newOpponentDeck);

        emit AwaitingAutomation(msg.sender);

    }


    function submitOpponentDeck(address _player, string memory _inventory) internal {
        
        FunctionsRequest.Request memory req;
        req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, register_opponent_source);
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;

    
        string[] memory args = new string[](4);
        args[0] = players[_player].opponentDecks[players[_player].pendingOpponentIndex].key;
        args[1] = players[_player].opponentDecks[players[_player].pendingOpponentIndex].deck;
        args[2] = players[_player].opponentDecks[players[_player].pendingOpponentIndex].iv;
        args[3] = _inventory;

        req.setArgs(args);

        
        s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        requestIdbyRequester[s_lastRequestId] = _player;
        pendingRequests[s_lastRequestId] = requestType.REGISTER_OPPONENT;
    }


    //counter here is a base64 string
    //seed will eventually come from VRF and be validated
    //I will need to validate the counter later
    function startGame (uint _seed, string calldata _counter) external {
    //require (usedCounters[_counter] == false);
    //require (usedSeeds[_seed] == false);
    //usedSeeds[_seed] = true;
    //usedCounters[_counter] = true;
    require (players[msg.sender].inQueue == false);
    require (players[msg.sender].inGame == false);
    players[msg.sender].inGame = true;

    gameSession memory newSession;

    newSession.playerHealth = 15;
    newSession.opponentHealth = 15;
    newSession.currentTurn = 1;

    currentSession[msg.sender] = newSession;

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


  function playerTakeTurn (bytes memory _actions) external {
    require (players[msg.sender].inGame == true);
    require (currentSession[msg.sender].updateInFlight == false);
    currentSession[msg.sender].updateInFlight = true;
    currentSession[msg.sender].updateType = validationType.PLAYER;
    currentSession[msg.sender].updateBytes = _actions;
    emit AwaitingAutomation(msg.sender);
  }


    //time to move this into checkUpkeep
    function progressGame (uint8 _action, address _player) internal {

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
    requestIdbyRequester[s_lastRequestId] = _player;
    pendingRequests[s_lastRequestId] = requestType.TAKE_TURN;


  }

    function getPlayerCards() public view returns (string[] memory) {
        return currentSession[msg.sender].playerCards;
    }

    function getOpponentCards() public view returns (string[] memory) {
        return currentSession[msg.sender].opponentCards;
    }

   function resetGame() public {
        currentTurn = 1;
        string[] memory empty;
        opponentCards = empty;
        playerCards = empty;
    }




//            FUNCTIONS REQUEST FULFILLMENT            //


  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    
    if (pendingRequests[requestId] == requestType.START_GAME) {
        string[3] memory newCards;
        uint index = 0;
        for (uint8 i = 0; i < 3; i++) {
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
        address player = requestIdbyRequester[requestId];
        currentSession[player].updateBytes = response;
        currentSession[player].updateType = validationType.OPPONENT;
        emit AwaitingAutomation(player);
    }
    else if (pendingRequests[requestId] == requestType.REGISTER_OPPONENT) {
        address player = requestIdbyRequester[requestId];
        players[player].inQueue = false;
        uint valid = abi.decode(response, (uint));
        if (valid == 1) {
            players[player].opponentDecks[players[player].pendingOpponentIndex].registered = true;
        }
        players[player].pendingOpponentIndex += 1;
    }
    
    s_lastResponse = response;
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
    cardKeyword traitA;
    cardKeyword traitB;
    uint8 energyCost;
  }



  mapping (string => cardTraits) cards;


  function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address player = address(uint160(uint256(log.topics[1])));
        
        if (players[player].inQueue == true) {
            uint8[] memory inventory = players[player].inventory;
            string memory inventoryString = "";
            for (uint y = 0; y < inventory.length; y++) {
                inventoryString = string.concat(inventoryString, Strings.toString(inventory[y]));
                if (y != inventory.length - 1) {
                    inventoryString = string.concat(inventoryString, ",");
                }
            }
            performData = abi.encode(player, inventoryString, requestType.REGISTER_OPPONENT);
            upkeepNeeded = true;
            return (upkeepNeeded, performData);
        }
        
        
        gameSession memory session = currentSession[player];
        string[] memory fieldCards = session.opponentCards;
        bool valid = true;
        
        string memory playerDrawnCard;
        uint8 usedEnergy = 0;
    
        upkeepNeeded = true;

        if (valid == true) {



            performData = abi.encode(playerDrawnCard);
        }
        else{

            //even in the case of an invalid action, pending actions must still resolve.
            performData = abi.encode("not valid");
        }

        return (upkeepNeeded, performData);
    
  }


//is forwarding enabled on testnet?
    function performUpkeep(
        bytes calldata performData
    ) external {
       // require(msg.sender == forwarder);
        (address player, string memory params, requestType upkeepType) = abi.decode(performData, (address, string, requestType));
        if (upkeepType == requestType.REGISTER_OPPONENT) {
            submitOpponentDeck(player, params);
        }
        
        
        
        (string memory opponentCard, string memory playerCard) = abi.decode(performData, (string, string));
        opponentCards.push(opponentCard);
        playerCards.push(playerCard);
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



  event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
  event AwaitingAutomation(address indexed _player);
  event UpkeepFulfilled(bytes indexed _performData);



  
}
