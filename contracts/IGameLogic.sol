// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IGameLogic {

    function checkHandActions (uint8 leadByte, bytes[] memory _hand, bytes[] memory handActions, bytes[] memory playerField, bytes[] memory opponentField) external view returns (bool);

    function checkFieldActions (uint8 leadByte, bytes[] memory fieldActions, bytes[] memory _playerField, bytes[] memory opponentField) external pure returns (bool);

    function doHandActions (uint8 leadByte, bytes[] memory handActions, bytes[] memory _playerField, bytes[] memory _opponentField) external view returns (bytes[] memory);

}
