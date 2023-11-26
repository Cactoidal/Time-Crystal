// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILogAutomation.sol";
import "./IERC677.sol";

contract NewGamePlus is FunctionsClient, ConfirmedOwner, VRFConsumerBaseV2 {
    using FunctionsRequest for FunctionsRequest.Request;

    // SEPOLIA

    bytes32 public donId;
    address private forwarder;

    bytes public s_lastError;

    string public source;
    FunctionsRequest.Location public secretsLocation;
    bytes encryptedSecretsReference;
   
    uint64 constant subscriptionId = 1686;
    uint32 constant callbackGasLimit = 300000;

    uint64 constant vrf_subscriptionId = 7168;
    address s_owner;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 s_keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint16 constant requestConfirmations = 3;
    uint32 constant vrfCallbackGasLimit = 500000;

    address LINKToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
  
    constructor(address router, bytes32 _donId, string memory _source, FunctionsRequest.Location _location, bytes memory _reference, cardTraits[] memory _cards) FunctionsClient(router) VRFConsumerBaseV2(vrfCoordinator) ConfirmedOwner(msg.sender) {
        donId = _donId;
        source = _source;
        secretsLocation = _location;
        encryptedSecretsReference = _reference;
        COORDINATOR = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        for (uint z = 0; z < _cards.length; z++) {
            cards[Strings.toString(z + 10)] = _cards[z];
        }
    }


      //            CHAINLINK AUTOMATION, FUNCTIONS, AND VRF VARIABLES        //

    mapping (address => string) keys;
    mapping (address => bytes) public hands;
    mapping (address => uint[]) vrfSeeds;
    mapping (string => bool) public usedCSPRNGIvs;
    uint ivNonce;

    mapping (bytes32 => address) public functionsRequestIdbyRequester;
    mapping (uint => address) public vrfRequestIdbyRequester;
    mapping (address => upkeepType) pendingUpkeep;

     enum upkeepType {
        MATCHMAKING,
        CHECK_VICTORY
    }


    //          GAME STATE VARIABLES        //

    address[2] matchmaker;
    uint matchIndex;
    mapping (address => uint) public currentMatch;
    string[] player1;
    string[] player2;
    address[] whoseTurn;
    mapping (address => bool) public inGame;
    mapping (address => bool) public inQueue;
    mapping (address => address) public currentOpponent;
    mapping (address => bool) public isPlayer1;
    mapping (address => uint) public lastCommit;

     //Test
    string public testWin = "Not yet";



    //                 PLAYER GAME INTERACTIONS                 //


    // transferAndCall executes the following:
    // Registers the player AES key.  RSA-encrypted AES key is provided as a base64 string.
    // Calls VRF. 10 VRF values are banked for use as seeds when asking Chainlink Functions for a random hand.
    // This is also the payment gateway for the player.  Players provide LINK upfront to cover the cost of services.
      function onTokenTransfer(address _sender, uint _value, bytes memory _data) external {
        require(msg.sender == LINKToken);
        // pay LINK to cover 10 matches here
        // turned off for testing
        //require(_value == 1e18);
        string memory _key = abi.decode(_data, (string));
        

       // uint256 requestId = COORDINATOR.requestRandomWords(
        //    s_keyHash,
        //    vrf_subscriptionId,
        //    requestConfirmations,
        //    vrfCallbackGasLimit,
        //    10
        //    );

        vrfSeeds[_sender] = [77777777777, 777777777777, 777777777777, 777777777777, 777777777777];
        keys[_sender] = _key;
        //vrfRequestIdbyRequester[requestId] = _sender;
    }


    // Prepare for a match by asking the Functions oracle for a SHA256 hash containing secret information.
    // AES-encrypted secret password + inventory, and iv are provided as base64 strings.
    // In addition, another (unique) iv must be passed for use by the CSPRNG key.
    // The Functions callback will trigger the Automation DON, pushing the player into the matchmaking queue.
    function getHand(string calldata secrets, string calldata secretsIv, string calldata csprngIv) external {
        require (inGame[msg.sender] == false);
        require (inQueue[msg.sender] == false);
        require (hands[msg.sender].length == 0);
        require (usedCSPRNGIvs[csprngIv] == false);

        uint[] memory seeds = vrfSeeds[msg.sender];

        if (seeds.length == 0) {
            revert("Call VRF");
        }

        usedCSPRNGIvs[csprngIv] = true;
        inQueue[msg.sender] = true;

        //Test
        testWin = "Not yet";

        FunctionsRequest.Request memory req;
        req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, source);
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;

        string[] memory args = new string[](6);
        args[0] = keys[msg.sender];
        args[1] = secrets;
        args[2] = secretsIv;
        args[3] = Strings.toString(seeds[seeds.length - 1]);
        args[4] = csprngIv;
        args[5] = Strings.toString(ivNonce);
        //args[6] = on-chain deck
        ivNonce++;
        vrfSeeds[msg.sender].pop();
        
        req.setArgs(args);
        //req.setBytesArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        functionsRequestIdbyRequester[requestId] = msg.sender;
    }


    // Card is appended to action string for later evaluation
    // Card must have a valid mapping in the cards list
    function makeMove(string memory action) external {
        uint matchId = currentMatch[msg.sender];
        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        
        // Disabled for testing
        //require(whoseTurn[matchId] == msg.sender);
        
        require(cards[action].cardNumber != 0);
        
        lastCommit[msg.sender] = block.number;
        if (isPlayer1[msg.sender]) {
            player1[matchId] = string.concat(player1[matchId], action);
        }
        else {
            player2[matchId] = string.concat(player2[matchId], action);
        }
        whoseTurn[matchId] = currentOpponent[msg.sender];

    }


    // End the game by providing the constituent values of your oracle-generated hash.
    // Automation will check whether you actually won, and if your played cards were truly in your hand.
    function declareVictory(string calldata secret) external {
        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        //hand may need to be abi.encoded?
        require(keccak256(hands[msg.sender]) == keccak256(abi.encodePacked(sha256(abi.encodePacked(secret)))));

        // The game immediately ends and goes to Automation to determine the winner
        address opponent = currentOpponent[msg.sender];

        inQueue[opponent] = true;
        inGame[opponent] = false;
        inQueue[msg.sender] = true;
        inGame[msg.sender] = false;

        pendingUpkeep[msg.sender] = upkeepType.CHECK_VICTORY;

        emit AwaitingAutomation(msg.sender, secret);
    }

    // It must not be your turn, your opponent must not have acted for 7 blocks, and the
    // game's end can't already be pending.
    function forceEnd() public {
        require (inGame[msg.sender] == true);
        require (inQueue[msg.sender] == false);
        require (block.number >= lastCommit[currentOpponent[msg.sender]] + 7);
        require (whoseTurn[currentMatch[msg.sender]] != msg.sender);

        inGame[msg.sender] = false;
        hands[msg.sender] = bytes("");

        address opponent = currentOpponent[msg.sender];

        inGame[opponent] = false;
        hands[opponent] = bytes("");

        //Test
        testWin = "You won!";
    }




    //              VRF REQUEST FULFILLMENT              //

    // Banks 10 VRF values
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        vrfSeeds[vrfRequestIdbyRequester[requestId]] = randomWords;
        emit VRFFulfilled(requestId);
    }





    //            FUNCTIONS REQUEST FULFILLMENT            //


    // Provides a secret hand, drawn from a secretly shuffled deck.
    // Asks Chainlink Automation to move the player into matchmaking.
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {

        address player = functionsRequestIdbyRequester[requestId];

        // Response is a SHA256 hash against which the player will run a birthday attack
        // to extract the encoded secret random cards.
        hands[player] = response;

        // Moves player to matchmaking queue.
        if (err.length == 0) {
            pendingUpkeep[player] = upkeepType.MATCHMAKING;
            emit AwaitingAutomation(player, "");
            }
        else {
            s_lastError = err;
        }
        emit RequestFulfilled(requestId, response);
  }





    //       AUTOMATION AND GAMEPLAY VALIDATION          //

    enum cType {
    NORMAL,
    POWER,
    COUNTER,
    ENERGY
  }

    struct cardTraits {
    uint8 cardNumber;
    string cardName;
    cType cardType;
    uint8 attack;
    uint8 defense;
    uint8 energyCost;
    uint8 energyGain;
    uint8 counterBonus;
  }

    mapping (string => cardTraits) cards;

    struct hashMonster {
        uint HP;
        uint POW;
        uint DEF;
    }

    function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address player = address(uint160(uint256(log.topics[1])));
        upkeepNeeded = true;
        bool valid = true;
        if (pendingUpkeep[player] == upkeepType.MATCHMAKING) {
            performData = abi.encode(player);
        }


        if (pendingUpkeep[player] == upkeepType.CHECK_VICTORY) {
            // Opponent set as default winner
            performData = abi.encode(currentOpponent[player]);
            bytes memory _cards = bytes32ToBytes(log.topics[2]);
            bytes memory _actions;
            bytes memory _opponentActions;
            if (isPlayer1[player]) {
                _actions = bytes(player1[currentMatch[player]]);
                _opponentActions = bytes(player2[currentMatch[player]]);
            }
            else {
                _actions = bytes(player2[currentMatch[player]]);
                _opponentActions = bytes(player1[currentMatch[player]]);
            }
            uint actionsLength = _actions.length;
            if (actionsLength / 2 > _cards.length) {
                valid = false;
            }
            else {
                // Check if actions are valid

                // The strings will always contain valid cards because of the require statement
                // in makeMove().  The question is whether those cards were actually possessed
                // by the player.
                bytes[5] memory cardList;
                bytes[] memory actionList = new bytes[](actionsLength);
                uint8 index = 0;
                for (uint8 i = 0; i < 5; i++) {
                    bytes memory newCard = new bytes(2);
                    newCard[0] = _cards[index];
                    index += 1;
                    newCard[1] = _cards[index];
                    index += 1;
                    cardList[i] = (newCard);
                }
                index = 0;
                for (uint8 i = 0; i < actionsLength / 2; i++) {
                    bytes memory action = new bytes(2);
                    action[0] = _actions[index];
                    index += 1;
                    action[1] = _actions[index];
                    index += 1;
                    actionList[i] = (action);
                    bool inHand = false;
                    for (uint8 d; d < 5; d++) {
                        if (keccak256(action) == keccak256(cardList[d])) {
                            inHand = true;
                        }
                    }
                    if (inHand == false) {
                        valid = false;
                    }

                    }
                
                // Get opponent actions

                // The opponent action string will be the same size as the player's action string,
                // otherwise the player will not have been able to declare victory (i.e. stuck in
                // the reveal phase) and would instead win using forceEnd().
                bytes[] memory opponentActionList = new bytes[](actionsLength);
                index = 0;
                for (uint8 i = 0; i < actionsLength / 2; i++) {
                    bytes memory action = new bytes(2);
                    action[0] = _opponentActions[index];
                    index += 1;
                    action[1] = _opponentActions[index];
                    index += 1;
                    opponentActionList[i] = (action);
                }


                // Get hashMonsters

                // The hash randomly determines if you will be playing CONSTRUCT or CRYSTAL
                // You should design your deck to play both
                // Eventually there will be different types of CONSTRUCTs and CRYSTALs
                hashMonster memory playerMonster;
                hashMonster memory opponentMonster;

                playerMonster = getHashMonsterStats(getHashMonster(player));
                opponentMonster = getHashMonsterStats(getHashMonster(currentOpponent[player]));

                // Check Actions against hashMonster
                // POWER attacks ignore DEF
                // COUNTER attacks will do extra damage after being hit by a POWER attack

                // Winner's HP is NOT checked, because a cheating opponent could have reduced your HP to 0
                // and attempted to wait you out instead of proving.  However, the opponent's defensive effects 
                // will be fully accounted for when checking their HP.  A cheater will lose 100% of the time
                // if you just keep attacking them until their HP is 0.
                if (valid == true) {

                    uint totalDamage;
                    uint bankedEnergy;

                    for (uint8 r; r < actionsLength / 2; r++) {

                        cardTraits memory playerCard = cards[string(actionList[r])];
                        cardTraits memory opponentCard = cards[string(opponentActionList[r])];

                        // Check energy cost
                        if (playerCard.energyCost > bankedEnergy) {
                            valid = false;
                        }
                        else {
                            bankedEnergy -= playerCard.energyCost;
                        }

                        // Calculate damage.  POWER attacks ignore defense, but take more damage from counter cards.
                        uint opponentDEF = opponentMonster.DEF * opponentCard.defense;
                        uint playerATK = playerMonster.POW * playerCard.attack;
                        uint damageDealt;

                        // Opponents can be countered if they used a POWER attack.
                        if (opponentCard.cardType == cType.POWER) {
                            playerATK = playerMonster.POW * (playerCard.attack + playerCard.counterBonus);
                        }

                        // NORMAL attacks are reduced by defense.  Damage floor is 10.
                        if (playerCard.cardType == cType.NORMAL) {
                            if (opponentDEF > playerATK) {
                                damageDealt = 10;
                            }
                            else {
                                damageDealt = (playerATK - opponentDEF);
                            }
                        }
                        // POWER attacks ignore defense.
                        else if (playerCard.cardType == cType.POWER) {
                            damageDealt = playerATK;
                        }

                        totalDamage += damageDealt;

                        bankedEnergy += playerCard.energyGain;

                        // Pure ENERGY cards do not have a damage calculation.

                        }
                        
                    if (totalDamage < opponentMonster.HP) {
                        valid = false;
                        }

                    if (valid == true) {
                        // Player wins
                        performData = abi.encode(player);
                        }
                    }

                }

            }
            return (upkeepNeeded, performData);
        }
 


    // MATCHMAKING: Moves the player into the queue, and starts a game if two players are ready.
    // CHECK_VICTORY: Declares the winner, and removes the players from the game.
    function performUpkeep(
        bytes calldata performData
    ) external {
        require(msg.sender == forwarder);

        (address player) = abi.decode(performData, (address));
        
        if (pendingUpkeep[player] == upkeepType.MATCHMAKING) {
            
            // TEST OPPONENT
            matchmaker[0] = vrfCoordinator;
            hands[vrfCoordinator] = abi.encodePacked(sha256("test"));

            
            if (matchmaker[0] == address(0x0)) {
                matchmaker[0] = player;
                }
            else {
                matchmaker[1] = player;

                address _player1 = matchmaker[0];
                address _player2 = matchmaker[1];
                
                uint newMatchId = matchIndex;

                currentMatch[_player1] = newMatchId;
                isPlayer1[_player1] = true;
                currentOpponent[_player1] = matchmaker[1];
                player1.push("");
                inQueue[_player1] = false;
                inGame[_player1] = true;
                

                // To prevent force-ending immediately before a player can act
                lastCommit[_player1] = block.number;
                lastCommit[_player2] = block.number + 15;
                whoseTurn.push(_player1);

                currentMatch[_player2] = newMatchId;
                isPlayer1[_player2] = false;
                currentOpponent[_player2] = matchmaker[0];
                player2.push("");
                inQueue[_player2] = false;
                inGame[_player2] = true;

                matchmaker[0] = address(0x0);
                matchmaker[1] = address(0x0); 

                matchIndex++;
                }
            }

        else if (pendingUpkeep[player] == upkeepType.CHECK_VICTORY) {

            // Declare winner and disburse reward / deposit

            // the encoded address "player" is the winner, while the opponent has lost

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

    //https://ethereum.stackexchange.com/questions/40920/convert-bytes32-to-bytes
    function bytes32ToBytes(bytes32 data) internal pure returns (bytes memory) {
        uint i = 0;
        while (i < 32 && uint8(data[i]) != 0) {
            ++i;
        }
        bytes memory result = new bytes(i);
        i = 0;
        while (i < 32 && data[i] != 0) {
            result[i] = data[i];
            ++i;
        }
        return result;
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

    function getHashMonster(address _player) public view returns (uint number) {
        uint hashNumber = uint(bytes32(hands[_player]));
        for (uint z; z < 10; z++) {
            number = hashNumber;
            while ( number >= 10) {
                number /= 10;
                }
                if (number == z) {
                    return number;
                    }
                }

    }

    function getHashMonsterStats(uint id) public pure returns (hashMonster memory monster) {
        if (id <= 4) {
            // Construct
            monster.HP = 100;
            monster.POW = 20;
            monster.DEF = 10;
                }
        else {
            // Crystal
            monster.HP = 50;
            monster.POW = 75;
            monster.DEF = 40;
                }
        return monster;

    }

    function getOpponent() public view returns (address) {
        return currentOpponent[msg.sender];
    }

    function seeBoard() public view returns (string memory) {
        if (isPlayer1[msg.sender] == true) {
            return player1[currentMatch[msg.sender]];
        }
        else {
            return player2[currentMatch[msg.sender]];
        }
    }

    function seeOpponentBoard() public view returns (string memory) {
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
        IERC20(LINKToken).transfer(owner(), IERC20(LINKToken).balanceOf(address(this)));
    }

    event VRFFulfilled(uint indexed _id);
    event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
    event AwaitingAutomation(address indexed _player, string indexed _cards);
    event UpkeepFulfilled(bytes indexed _performData);

  
}
