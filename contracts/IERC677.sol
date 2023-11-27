// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC677 {
  function onTokenTransfer(address _sender, uint _value, bytes memory _data) external;

  function onNftTransfer(address _sender, uint _value, bytes memory _data) external;
}
