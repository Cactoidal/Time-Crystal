// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IERC677.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TCNFT is ERC721 {

    address timeCrystalContract;
    address LINKToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    constructor() ERC721("test", "TEST") {
    //constructor() ERC721("Time Crystal", "CRYSTAL") {
    }

    uint crystalId = 1;

    function onTokenTransfer(address _sender, uint _value, bytes memory _data) external {
        require(msg.sender == LINKToken);
        // pay LINK to mint here
        // turned off for testing
        //require(_value == 1e18);
        _mint(_sender, crystalId);
        crystalId++;
    }

    //test
    function setContract(address _contract) external {
        timeCrystalContract = _contract;
    }



    function transferAndCall(
    address from,
    address to,
    uint id,
    bytes memory data
  )
    public
    virtual
    returns (bool success)
  {
    require(to == timeCrystalContract);
    super.transferFrom(from, to, id);
    emit Transfer(msg.sender, to, id);
    if (isContract(to)) {
      contractFallback(to, id, data);
    }
    return true;
  }


  // PRIVATE

  function contractFallback(
    address to,
    uint id,
    bytes memory data
  )
    private
  {
    IERC677 receiver = IERC677(to);
    receiver.onNftTransfer(msg.sender, id, data);
  }

  function isContract(
    address addr
  )
    private
    view
    returns (bool hasCode)
  {
    uint length;
    assembly { length := extcodesize(addr) }
    return length > 0;
  }
}
