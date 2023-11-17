// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "ILogAutomation.sol";

contract GameLogic is ConfirmedOwner {

    constructor() ConfirmedOwner(msg.sender) {

    }

    address forwarder;
    address game;

    function setForwarder(address _forwarder) external onlyOwner {
        forwarder = _forwarder;
    }

    function setGameContract(address _game) external onlyOwner {
        game = _game;
    }




    function checkLog(
    Log calldata log,
    bytes memory checkData
  ) public {

  }

  function performUpkeep(
        bytes calldata performData
    ) external {
    require(msg.sender == forwarder);
    
    }

}
