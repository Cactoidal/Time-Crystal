// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "ILogAutomation.sol";

contract RemixTester is FunctionsClient, ConfirmedOwner {
  using FunctionsRequest for FunctionsRequest.Request;

  bytes32 public donId;
  address private forwarder;

  bytes32 public s_lastRequestId;
  bytes public s_lastResponse;
  bytes public s_lastError;

  string public start_game_source;
  string public take_turn_source;
  FunctionsRequest.Location public secretsLocation;
  bytes encryptedSecretsReference;
  uint64 subscriptionId = 1600;
  uint32 callbackGasLimit = 300000;
  

  constructor(address router, bytes32 _donId, string memory _source,  string memory _source2, FunctionsRequest.Location _location, bytes memory _reference) FunctionsClient(router) ConfirmedOwner(msg.sender) {
    donId = _donId;
    start_game_source = _source;
    take_turn_source = _source2;
    secretsLocation = _location;
    encryptedSecretsReference = _reference;
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

    enum validationType {
    PLAYER,
    OPPONENT
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

    mapping (address => bool) inSession;
    mapping (address => gameSession) currentSession;
    mapping (address => bool) awaitingAutomation;

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
    require (inSession[msg.sender] == false);
    inSession[msg.sender] = true;

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
    require (inSession[msg.sender] == true);
    require (currentSession[msg.sender].updateInFlight == false);
    currentSession[msg.sender].updateInFlight = true;
    currentSession[msg.sender].updateType = validationType.PLAYER;
    currentSession[msg.sender].updateBytes = _actions;
    emit AwaitingOpponentValidation(msg.sender);
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
        emit AwaitingOpponentValidation(player);
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
    cType cardType;
    uint8 attack;
    uint8 defense;
    cardKeyword traitA;
    cardKeyword traitB;
    uint8 energyCost;
  }



  mapping (string => cardTraits) cards;


    //for now, write the opponent logic only.
  function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address player = address(uint160(uint256(log.topics[1])));
        gameSession memory session = currentSession[player];
        string[] memory fieldCards = session.opponentCards;
        bool valid = true;
        
        string memory playerDrawnCard;
        uint8 usedEnergy = 0;
        uint8 newFieldCards = 0;

        //decode lead byte for action count
        //only 4 actions allowed per turn
        uint8 actionCount = uint8(session.updateBytes[0]);
        if (actionCount > 4) {
            valid = false;
        }

        //sort actions
        bytes[] memory actions = new bytes[](actionCount);
        string[] memory cardStrings = new string[](actionCount);
        uint8 stringIndex = 0;
        uint8 index = 1;
        for (uint i = 0; i < actionCount; i++) {
            bytes memory card = new bytes(6);
            for (uint j = 0; j < 6; j++) {
                card[j] = session.updateBytes[index];
                index++;
            }
            actions[i] = (card);
            //draw the player card if returning from OPPONENT turn
            if (session.updateType == validationType.OPPONENT) {
                bytes memory playerCard;
                playerCard[0] = session.updateBytes[index];
                index++;
                playerCard[1] = session.updateBytes[index];
                playerDrawnCard = string(card);
            }
        }

            //validate and load actions into phases 
            //do not need to check if the player owns the card, since the deck has already been validated
        
        
        for (uint k = 0; k < actionCount; k++) {
                bytes memory _card = new bytes(2);
                
                uint8 _cardId = uint8(actions[k][0]);
                _card[0] = actions[k][1];
                _card[1] = actions[k][2];
                uint8 targetPlayer = uint8(actions[k][3]);
                uint8 targetCard = uint8(actions[k][4]);
                uint8 action = uint8(actions[k][5]);
                cardStrings[k] = string(_card);

                cardTraits memory card = cards[string(_card)];

                usedEnergy += card.energyCost;

                //bytes32 target = keccak256(abi.encode("NONE"));

               // if (targetPlayer == 1) {
               //     if (targetCard == 0) {
                //        target = keccak256(abi.encode("PLAYER"));
                //    }
                //    else {
                //        for (uint p = 0; p < session.playerCards.length; p++) {
                //            bool exists;
                //            if (keccak256(abi.encode(session.playerCards[p])) == keccak256(abi.encode(string(_card)))) {

                //    }
                    
               // }

               // bool has = false;
               // for (uint p = 0; p < session.playerHand.length; p++) {
               //     if (keccak256(abi.encode(session.playerHand[p])) == keccak256(abi.encode(string(_card)))) {
               //         has = true;
               //         }
               //     }     
               // if (has == false) {
               //     valid = false;
                //    }

               
                        
                
                // each player can have 9 persistent cards on the field
                // special targets are
                // 00: NONE, 10: PLAYER, 20: OPPONENT
                // otherwise cards can be targeted by their index in their respective array


                //(1: PLAY CARD, 2: ABILITY, 3: BLOCK, 4: ATTACK)
                if (action > 4 || action == 0) {
                    valid = false;
                }

                else {
                    //CONSTRUCT
                    if (card.cardType == cType.CONSTRUCT) {
                      //  if (session.opponentCards.length >= 9) {
                       //     valid = false;
                        //}                            

                        if (action == 1) {
                            newFieldCards++;
                            //enters field, triggers drop effect, otherwise does nothing
                            //drop effects on constructs and crystals are always traitA
                            if (card.traitA == cardKeyword.ST_SHIELD) {

                            }
                            if (card.traitA == cardKeyword.ST_HEAL1) {
                            

                            }
                            if (card.traitA == cardKeyword.ST_DAMAGE1) {

                            }
                            
                        }
                        else if (action == 2) {
                            //is construct on the field?
                            cardStrings[stringIndex] = (string(_card));
                            stringIndex++;
                            //does construct have ability?
                            //does target exist and is valid?
                            //does ability
                            //usedEnergy += ability energy cost
                            
                        }
                        else if (action == 3) {
                            //is construct on the field?
                            cardStrings[stringIndex] = (string(_card));
                            stringIndex++;
                            //does target exist and is valid?
                            //blocks target
                        }
                        else if (action == 4) {
                            //is construct on the field?
                            cardStrings[stringIndex] = (string(_card));
                            stringIndex++;
                            //does target exist and is valid?
                            //attacking has no target without AIM keyword
                        }


                        }
                    
                    //CRYSTAL
                    if (card.cardType == cType.CRYSTAL) {
                     //   if (session.updateType == validationType.OPPONENT) {
                      //      if (session.opponentCards.length >= 9) {
                      //          valid = false;
                       //     }
                      //  }
        
                        if (action == 1) {
                            newFieldCards++;
                            //enters field, triggers drop effect, otherwise does nothing
                            //drop effects on constructs and crystals are always traitA
                            
                        }
                        else if (action == 2) {
                            //is crystal on the field?
                            cardStrings[stringIndex] = (string(_card));
                            stringIndex++;
                            //does crystal have ability?
                            //does target exist and is valid?
                            //does ability
                            //usedEnergy += ability energy cost
                            
                        }
                        //can't attack or block, but can be attacked

                        }
                    

                    //POWER
                    if (card.cardType == cType.POWER) {
                        //does not persist
                        if (action == 1) {
                            //does drop effect, may or may not have target
                            
                        }
                        else {
                            valid = false;
                        }
                            
                        }
                    
                    //ORACLE
                    if (card.cardType == cType.ORACLE) {
                        //does not persist
                        //appends itself to request
                        if (action == 1) {
                            //does drop effect, may or may not have target
                            
                        }
                        else {
                            valid = false;
                        }
                            
                        }
                       




                        }

                }

                // check energy used against max energy
                if (usedEnergy > currentSession[player].currentTurn) {
                    valid = false;
                }

                //check if ability-using persistent cards exist on field
                for (uint y = 0; y < cardStrings.length; y++) {
                    bool has = false;
                    for (uint p = 0; p < fieldCards.length; p++) {
                        if (keccak256(abi.encode(cardStrings[y])) == keccak256(abi.encode(""))) {
                            has = true;
                        }
                        else if (keccak256(abi.encode(cardStrings[y])) == keccak256(abi.encode(string(fieldCards[p])))) {
                            has = true;
                            }
                        }
                    if (has == false) {
                    valid = false;
                }
                }

                //check that there will be no more than 9 persistent cards on the field
                if (fieldCards.length + newFieldCards > 9) {
                    valid = false;
                }
                
  

            

            //execute pending actions against interrupts and update state and pending actions

        if (currentSession[player].updateType == validationType.PLAYER) {
            

            //write the game state and new pending actions into a JSON to give to Functions DON
            //call functions DON

        }


        if (currentSession[player].updateType == validationType.OPPONENT) {

            //return opponent actions and player drawn card
            //call turn complete
        }

        //finalizedActions
        //newPendingActions

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
  event AwaitingPlayerValidation(address indexed _player);
  event AwaitingOpponentValidation(address indexed _player);
  event UpkeepFulfilled(bytes indexed _performData);



  
}
