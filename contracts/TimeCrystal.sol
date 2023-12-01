// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ILogAutomation.sol";
import "./IERC677.sol";

contract TimeCrystal is FunctionsClient, ConfirmedOwner, VRFConsumerBaseV2, ERC721 {
    using FunctionsRequest for FunctionsRequest.Request;

 

    bytes32 public donId;
    address private forwarder;

    bytes public s_lastError;

    string public source;
    FunctionsRequest.Location public secretsLocation;
    bytes encryptedSecretsReference;

    // FUJI

    uint64 constant subscriptionId = 1573;
    uint32 constant callbackGasLimit = 300000;

    uint64 constant vrf_subscriptionId = 806;
    address s_owner;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 s_keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint16 constant requestConfirmations = 3;
    uint32 constant vrfCallbackGasLimit = 500000;

    address LINKToken = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    // SEPOLIA
   
    //uint64 constant subscriptionId = 1686;
    //uint32 constant callbackGasLimit = 300000;

    //uint64 constant vrf_subscriptionId = 7168;
    //address s_owner;
    //VRFCoordinatorV2Interface COORDINATOR;
    //address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    //bytes32 s_keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    //uint16 constant requestConfirmations = 3;
    //uint32 constant vrfCallbackGasLimit = 500000;

    //address LINKToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
  
    constructor(address router, bytes32 _donId, string memory _source, FunctionsRequest.Location _location, bytes memory _reference, cardTraits[] memory _cards) FunctionsClient(router) VRFConsumerBaseV2(vrfCoordinator) ConfirmedOwner(msg.sender) ERC721("Test", "TEST") {
        donId = _donId;
        source = _source;
        secretsLocation = _location;
        encryptedSecretsReference = _reference;
        mintOver = block.number + 10000;
        COORDINATOR = VRFCoordinatorV2Interface(0x2eD832Ba664535e5886b75D64C46EB9a228C2610);
        for (uint z = 0; z < _cards.length; z++) {
            cards[Strings.toString(_cards[z].cardNumber)] = _cards[z];
        }
    }


      //            CHAINLINK AUTOMATION, FUNCTIONS, AND VRF VARIABLES        //

    mapping (address => string) keys;
    mapping (string => bool) public usedCSPRNGIvs;
    uint ivNonce;

    mapping (bytes32 => address) public functionsRequestIdbyRequester;
    mapping (uint => address) public vrfRequestIdbyRequester;
    mapping (address => upkeepType) pendingUpkeep;

     enum upkeepType {
        MATCHMAKING,
        CHECK_VICTORY
    }

    //          CRYSTAL NFT VARIABLES       //

    uint mintOver;
    mapping (address => uint) crystalStaked;
    uint crystalId = 1;
    mapping (uint => uint[]) vrfSeeds;
    mapping (uint => uint) crystalEXP;
    mapping (uint => uint) crystalEnergy;
    mapping (uint => uint) crystalTimeSeed;


    //          GAME STATE VARIABLES        //

    mapping (address => bytes) public hands;
    address[2] matchmaker;
    uint matchIndex;
    mapping (address => uint) public currentMatch;
    mapping (address => string) public playerActions;
    mapping (address => bool) public inGame;
    mapping (address => bool) public inQueue;
    mapping (address => address) public currentOpponent;
    mapping (address => bytes) public hashCommit;
    mapping (address => uint) public lastCommit;
    mapping (uint => gamePhase) public currentPhase;

    enum gamePhase {
        COMMIT,
        REVEAL
    }

     //Test
    address public testWin = vrfCoordinator;



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
        uint crystal = crystalStaked[_sender];

        if (mintOver > block.number && crystal == 0) {
            uint newId = crystalId;
            _mint(address(this), newId);
            crystalStaked[_sender] = newId;
            crystal = newId;
            crystalTimeSeed[newId] = block.timestamp;
            crystalEnergy[newId] = 100;
            crystalId++;
        }
        else {
            require(crystal != 0);
        }
        
        //inQueue[msg.sender] = true;
       // uint256 requestId = COORDINATOR.requestRandomWords(
        //    s_keyHash,
        //    vrf_subscriptionId,
        //    requestConfirmations,
        //    vrfCallbackGasLimit,
        //    10
        //    );

        vrfSeeds[crystal] = [77777777777, 777777777777, 777777777777, 777777777777, 777777777777];

        if (_data.length != 0) {
            string memory _key = abi.decode(_data, (string));
            keys[_sender] = _key;
            }
        //vrfRequestIdbyRequester[requestId] = _sender;
    }


    // Prepare for a match by asking the Functions oracle for a SHA256 hash containing secret information.
    // AES-encrypted secret password, and iv are provided as base64 strings.
    // In addition, another (unique) iv must be passed for use by the CSPRNG key.
    // The Functions callback will trigger the Automation DON, pushing the player into the matchmaking queue.
    function getHand(string calldata secrets, string calldata secretsIv, string calldata csprngIv) external {
        require (inGame[msg.sender] == false);
        require (inQueue[msg.sender] == false);
        require (hands[msg.sender].length == 0);
        require (usedCSPRNGIvs[csprngIv] == false);

        uint crystal = crystalStaked[msg.sender];

        uint[] memory seeds = vrfSeeds[crystal];

        if (seeds.length == 0) {
            revert("Call VRF");
        }

        usedCSPRNGIvs[csprngIv] = true;
        inQueue[msg.sender] = true;

        //Test
        testWin = vrfCoordinator;

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
        vrfSeeds[crystal].pop();
        
        req.setArgs(args);
        //req.setBytesArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        functionsRequestIdbyRequester[requestId] = msg.sender;
    }


    // For testing,
    // Put in a mock opponent that mirrors my actions

    // Provide a hash of your action, kept secret until both players have committed
    function commitAction(bytes memory _actionHash) external {
        uint matchId = currentMatch[msg.sender];

        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        require(currentPhase[matchId] == gamePhase.COMMIT);
        require(hashCommit[msg.sender].length == 0);

        hashCommit[msg.sender] = _actionHash;
        lastCommit[msg.sender] = block.number;

        // TEST
        hashCommit[currentOpponent[msg.sender]] = _actionHash;

        // If opponent has committed, change phase to REVEAL
        if (hashCommit[currentOpponent[msg.sender]].length != 0) {
            currentPhase[matchId] = gamePhase.REVEAL;
        }
    }



    // Provide the secret password and action used to create the commit hash
    // Action is appended to action string for later evaluation 
    // Action must have a valid mapping in the cards list
    function revealAction(string memory password, string memory action) external {
        uint matchId = currentMatch[msg.sender];

        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        require(currentPhase[matchId] == gamePhase.REVEAL);
        require(bytes(password).length == 20);
        require(cards[action].cardNumber != 0);

        string memory revealed = string.concat(password, action);
        //might need to fool with the abi.encode
        require(keccak256(hashCommit[msg.sender]) == keccak256(abi.encode(sha256(abi.encode(revealed)))));

        playerActions[msg.sender] = string.concat(playerActions[msg.sender], action);

        hashCommit[msg.sender] = bytes("");
        lastCommit[msg.sender] = block.number;

        // TEST
        address opponent = currentOpponent[msg.sender];
        playerActions[opponent] = string.concat(playerActions[opponent], action);
        hashCommit[opponent] = bytes("");

        // If opponent has revealed, change phase to COMMIT
        if (hashCommit[currentOpponent[msg.sender]].length == 0) {
            currentPhase[matchId] = gamePhase.COMMIT;
        }
    }


    // End the game by providing the constituent values of your oracle-generated hash.
    // Automation will check whether you actually won, and if your played cards were truly in your hand.
    function declareVictory(string calldata secret) external {
        //do I need to check the length of secret to prevent a length extension attack?
        require(inGame[msg.sender] == true);
        require(inQueue[msg.sender] == false);
        // Victory must be declared during the COMMIT phase, to prevent passing action strings 
        // of different lengths to the Automation DON
        require(currentPhase[currentMatch[msg.sender]] == gamePhase.COMMIT);

        // Must provide secret password + extracted cards to match the oracle-committed hand hash
        require(keccak256(hands[msg.sender]) == keccak256(abi.encodePacked(sha256(abi.encodePacked(secret)))));

        // The game immediately ends and goes to Automation to determine the winner
        address opponent = currentOpponent[msg.sender];

        inQueue[opponent] = true;
        inGame[opponent] = false;
        inQueue[msg.sender] = true;
        inGame[msg.sender] = false;

        // pendingUpkeep is set for both players, as either could potentially win
        pendingUpkeep[msg.sender] = upkeepType.CHECK_VICTORY;
        pendingUpkeep[opponent] = upkeepType.CHECK_VICTORY;

        emit AwaitingAutomation(msg.sender, bytes32(bytes(secret)));
    }

   

    // Your opponent must not have committed (or revealed) for 7 blocks after your most recent commit (or reveal),
    // and the game's end can't already be pending.

    function forceEnd() public {
        address opponent = currentOpponent[msg.sender];

        require (inGame[msg.sender] == true);
        require (inQueue[msg.sender] == false);
        require (lastCommit[msg.sender] > lastCommit[opponent]);
        require (block.number >= lastCommit[msg.sender] + 7);
    
        inGame[msg.sender] = false;
        hands[msg.sender] = bytes("");
        currentOpponent[msg.sender] = address(0x0);
        hashCommit[msg.sender] = bytes("");

        inGame[opponent] = false;
        hands[opponent] = bytes("");
        currentOpponent[opponent] = address(0x0);
        hashCommit[opponent] = bytes("");

        //Test
        testWin = msg.sender;
    }




    //              VRF REQUEST FULFILLMENT              //

    // Banks 10 VRF values
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        address requester = vrfRequestIdbyRequester[requestId];
        vrfSeeds[crystalStaked[requester]] = randomWords;
        inQueue[requester] = false;
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
            inQueue[player] = false;
        }
        emit RequestFulfilled(requestId, response);
  }





    //       AUTOMATION AND GAMEPLAY VALIDATION          //

    enum cType {
    NORMAL,
    POWER,
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

            bytes memory _actions = bytes(playerActions[player]);
            bytes memory _opponentActions = bytes(playerActions[currentOpponent[player]]);

            uint actionsLength = _actions.length;
            
            // Check if actions are valid

            // The strings will always contain valid cards because of the require statement
            // in revealAction().  The question is whether those cards were actually
            // in the player's hand.
            bytes[6] memory cardList;
            bytes[] memory actionList = new bytes[](actionsLength);
           
            uint8 index = 20;
            for (uint8 i = 0; i < 6; i++) {
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
                for (uint8 d; d < 6; d++) {
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
            // the commit phase) and would instead win using forceEnd().
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

                    // Gain 1 passive energy per turn, plus energy from cards.
                    bankedEnergy += (playerCard.energyGain + 1);

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
                currentOpponent[_player1] = matchmaker[1];
                playerActions[_player1] = "";
                inQueue[_player1] = false;
                inGame[_player1] = true;

                currentMatch[_player2] = newMatchId;
                currentOpponent[_player2] = matchmaker[0];
                playerActions[_player2] = "";
                inQueue[_player2] = false;
                inGame[_player2] = true;
                
                // To prevent force-ending immediately before a player can act
                lastCommit[_player1] = block.number;
                lastCommit[_player2] = block.number;
                currentPhase[newMatchId] = gamePhase.COMMIT;

                matchmaker[0] = address(0x0);
                matchmaker[1] = address(0x0); 

                matchIndex++;
                }
            }

        else if (pendingUpkeep[player] == upkeepType.CHECK_VICTORY) {

            // Declare winner and disburse reward / deposit

            // The encoded address "player" is the winner, while their opponent has lost
            address opponent = currentOpponent[player];
            uint playerCrystal = crystalStaked[player];
            uint opponentCrystal = crystalStaked[opponent];
            
            // Both players gain EXP, the winning crystal absorbs half the energy of the opponent crystal
            crystalEXP[playerCrystal] += 100 + getTimePhase(playerCrystal);
            crystalEXP[opponentCrystal] += 20 + getTimePhase(opponentCrystal);
            crystalEnergy[playerCrystal] += (crystalEnergy[opponentCrystal] / 2);
            crystalEnergy[opponentCrystal] /= 2; 

            // Reinitialize both players
            inQueue[player] = false;
            inGame[player] = false;
            hands[player] = bytes("");
            currentOpponent[msg.sender] = address(0x0);
            hashCommit[msg.sender] = bytes("");

            inQueue[opponent] = false;
            inGame[opponent] = false;
            hands[opponent] = bytes("");
            currentOpponent[opponent] = address(0x0);
            hashCommit[opponent] = bytes("");
            


            //Test 
            testWin = player;
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


    //                  NFT FUNCTIONS                   //

    function unstake() external {
        require(!inQueue[msg.sender]);
        require(!inGame[msg.sender]);
        uint crystal = crystalStaked[msg.sender];
        require(crystal != 0);
        crystalStaked[msg.sender] = 0;
        transferFrom(address(this), msg.sender, crystal);
    }

    function stake(uint _crystal) external {
        require (crystalStaked[msg.sender] == 0);
        require (ownerOf(_crystal) == msg.sender);
        crystalStaked[msg.sender] = _crystal;
        approve(address(this), _crystal);
        transferFrom(msg.sender, address(this), _crystal);
    }

    function getTimePhase(uint _crystal) public view returns (uint) {
        uint seed = block.timestamp - crystalTimeSeed[_crystal];
        return seed % 7;
    }

    function tokenURI(uint _crystal) public view override returns (string memory uri) {
        uri = "{";
        uri = string.concat(uri, '"description": "test","name":');
        uri = string.concat(uri, '"');
        uri = string.concat(uri, 'Test #');
        uri = string.concat(uri,Strings.toString(_crystal));
        uri = string.concat(uri,'","traits": [ {"trait_type":"Remaining');
        uri = string.concat(uri, '","value":"');
        uri = string.concat(uri, Strings.toString(vrfSeeds[_crystal].length));
        uri = string.concat(uri, '"');
        uri = string.concat(uri, "},{");
        // temp commented out for size limit
        //uri = string.concat(uri, '"trait_type":"Phase","value":');
        //uri = string.concat(uri, '"');
        //uri = string.concat(uri, Strings.toString(getTimePhase(_crystal)));
        //uri = string.concat(uri, '"');
        //uri = string.concat(uri, "},{");
        uri = string.concat(uri, '"trait_type":"EXP","value":');
        uri = string.concat(uri, '"');
        uri = string.concat(uri, Strings.toString(crystalEXP[_crystal]));
        uri = string.concat(uri, '"');
        uri = string.concat(uri, "},{");
        uri = string.concat(uri, '"trait_type":"Energy","value":');
        uri = string.concat(uri, '"');
        uri = string.concat(uri, Strings.toString(crystalEnergy[_crystal]));
        uri = string.concat(uri, '"');
        uri = string.concat(uri, "} ] }");
        return uri;
    }



     //              GODOT VIEW FUNCTIONS            //


    // Public Getters:

    //      keys(address)

    //      Retrieves the SHA256 hash of the player's secret password, random cards, and inventory.
    //      hands(address)

    //      inQueue(address)

    //      inGame(address)

    //      currentOpponent(address)

    //      playerActions(address)

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
            monster.HP = 200;
            monster.POW = 20;
            monster.DEF = 20;
                }
        else {
            // Crystal
            monster.HP = 100;
            monster.POW = 40;
            monster.DEF = 40;
                }
        return monster;

    }


    function checkCommit(address _player) external view returns (bool) {
        return (hashCommit[_player].length != 0);
    }

    function hasSeedsRemaining(address _player) public view returns (bool) {
        if (vrfSeeds[crystalStaked[_player]].length > 0) {
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
    event AwaitingAutomation(address indexed _player, bytes32 indexed _cards);
    event UpkeepFulfilled(bytes indexed _performData);

  
}
