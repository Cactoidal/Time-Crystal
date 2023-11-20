// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IGameLogic {

    function checkHandSize(bytes memory _hand) external pure returns (bool);

    function getData(bytes memory hand, bytes memory actions) external pure returns (uint8, uint8, bytes[] memory, bytes[] memory, bytes[] memory);

    function checkHandActions (uint8 leadByte, bytes[] memory _hand, bytes[] memory handActions, bytes[] memory playerField, bytes[] memory opponentField) external view returns (bool);

    function checkFieldActions (uint8 leadByte, bytes[] memory fieldActions, bytes[] memory _playerField, bytes[] memory opponentField) external pure returns (bool);

    function doHandActions (uint8 leadByte, bytes[] memory handActions, bytes[] memory _playerField, bytes[] memory _opponentField) external view returns (bytes[] memory, uint8[4] memory, uint8[4] memory, uint8);

    function doFieldActions (uint8 leadByte, bytes[] memory fieldActions, bytes[] memory _playerField, bytes[] memory _opponentField, uint8[4] memory _destructible, uint8[4] memory _damaged, uint8 destructionIndex) external view returns (bytes[] memory, uint8[4] memory, uint8[4] memory);

    function applyEffects (bytes[] memory _playerField, bytes[] memory _opponentField, uint8[4] memory _destructible, uint8[4] memory _damaged, uint8 playerHealth, uint8 opponentHealth) external view returns (bytes[] memory, bytes[] memory, uint8, uint8);
}
