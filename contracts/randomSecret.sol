// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RemixTester is FunctionsClient, ConfirmedOwner {
  using FunctionsRequest for FunctionsRequest.Request;

  bytes32 public donId;

  bytes32 public s_lastRequestId;
  bytes public s_lastResponse;
  bytes public s_lastError;

  string public send_source;
  string public decrypt_source;
  FunctionsRequest.Location public secretsLocation;
  bytes encryptedSecretsReference;
  uint64 subscriptionId = 1600;
  uint32 callbackGasLimit = 300000;
  

  constructor(address router, bytes32 _donId, string memory _source,  string memory _source2, FunctionsRequest.Location _location, bytes memory _reference) FunctionsClient(router) ConfirmedOwner(msg.sender) {
    donId = _donId;
    send_source = _source;
    decrypt_source = _source2;
    secretsLocation = _location;
    encryptedSecretsReference = _reference;
  }

  enum requestType {
    SEND,
    RECEIVE,
    DECRYPT
  }

  struct encryptParams {
    uint seed;
    uint nonce;
    string counter;
  }
  
  mapping (address => bool) public inSession;

  mapping (address => uint) public sessionIndex;
  mapping (address => encryptParams[]) public sessions;

  mapping (bytes32 => address) public requestIdbyRequester;

  mapping (address => bytes) public returnedSecret;

  uint public nonceCounter = 1;
  mapping (bytes32 => requestType) public pendingRequests;
  mapping (uint => bool) public usedSeeds;
  mapping (string => bool) usedCounters;

  mapping (address => string) registeredKeys;
  mapping (address => bool) playerKeyRegistered;

  mapping (address => bytes) public decryptedMessage;



  
  //            SECRET RANDOMNESS           // 


  // Validate user-supplied counter
  function getCounter(uint8[16] calldata _counter) internal returns(string memory counter) {
        counter = "";
        for (uint i = 0; i < 16; i++) {
            require (_counter[i] >= 0 && _counter[i] <= 255);
            counter = string.concat(counter, Strings.toString(_counter[i]));
            if (i < 15) {
                counter = string.concat(counter, ",");
            }
        require (usedCounters[counter] == false);
        usedCounters[counter] = true;
        }
        //could this instead be sent with abi.encode() instead of converting to string?
        //bytes memory lol = abi.encode(_counter);
        return counter;
    }

   // Initialize session by mapping seed, nonce, and counter
   // this seed will eventually come from VRF
   // _counter can also be bytes
  function initializeSession(
    uint _seed,
    uint8[16] calldata _counter
  ) external {
    //require (_seed > 22646721157554672332427423894789798297842898279);
    require (usedSeeds[_seed] == false);
    require (inSession[msg.sender] == false);
    string memory counter = getCounter(_counter);
    usedSeeds[_seed] = true;
    inSession[msg.sender] = true;

    encryptParams memory newParams;
    newParams.seed = _seed;
    newParams.nonce = nonceCounter;
    nonceCounter++;
    newParams.counter = counter;

    sessions[msg.sender].push(newParams);

    //I could put an initial Functions call here with the player's first move
    
  }

  // Use seed and iv to regenerate secret (player will later provide other params in this call)
  function examineSecret (
  ) external {
    require (inSession[msg.sender] == true);
    FunctionsRequest.Request memory req;
    req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, decrypt_source);
    req.secretsLocation = secretsLocation;
    req.encryptedSecretsReference = encryptedSecretsReference;

    encryptParams memory currParams = sessions[msg.sender][sessionIndex[msg.sender]];

    string[] memory args = new string[](3);
    args[0] = Strings.toString(currParams.seed);
    args[1] = Strings.toString(currParams.nonce);
    args[2] = currParams.counter;

    req.setArgs(args);
    //req.setBytesArgs([]);

    s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    requestIdbyRequester[s_lastRequestId] = msg.sender;
    pendingRequests[s_lastRequestId] = requestType.DECRYPT;


  }



//              KEY EXCHANGE             // 

    //supply encrypted key as base64 string
    function registerPlayerKey(string calldata _key) public {
        //require (     keccak256(abi.encode(registeredKeys[msg.sender])) == keccak256(abi.encode(""))      );
        require (playerKeyRegistered[msg.sender] == false);
        playerKeyRegistered[msg.sender] = true;
        registeredKeys[msg.sender] = _key;
    }

    
    //supply encrypted message and iv as base64 strings
    function sendDONMessage (string calldata _message, string calldata _iv) external {
    require (playerKeyRegistered[msg.sender] == true);
    FunctionsRequest.Request memory req;
    req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, send_source);
    req.secretsLocation = secretsLocation;
    req.encryptedSecretsReference = encryptedSecretsReference;

    string[] memory args = new string[](3);
    args[0] = registeredKeys[msg.sender];
    args[1] = _iv;
    args[2] = _message;

    req.setArgs(args);
    //req.setBytesArgs(args);

    s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    requestIdbyRequester[s_lastRequestId] = msg.sender;
    pendingRequests[s_lastRequestId] = requestType.SEND;


  }








//            REQUEST FULFILLMENT            //

  // SEND: send encrypted message to DON
  // RECEIVE: receive encrypted message from DON
  // DECRYPT: decrypt secret randomness
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    if (pendingRequests[requestId] == requestType.SEND) {
        address player = requestIdbyRequester[requestId];
        decryptedMessage[player] = response;

    }
    else if (pendingRequests[requestId] == requestType.DECRYPT) {
        address player = requestIdbyRequester[requestId];
        inSession[player] = false;
        sessionIndex[player] += 1;
        returnedSecret[player] = response;
    }
    
    s_lastResponse = response;
    s_lastError = err;
    emit RequestFulfilled(requestId, response);
  }





  /**
   * @notice Set the DON ID
   * @param newDonId New DON ID
   */
  function setDonId(bytes32 newDonId) external onlyOwner {
    donId = newDonId;
  }



  event RequestFulfilled(bytes32 indexed _id, bytes indexed _response);
  
}
