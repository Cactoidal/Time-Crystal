// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "ITimeCrystal.sol";

contract GameLogic is ConfirmedOwner {

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
    cardKeyword keywordA;
    cardKeyword keywordB;
    uint8 energyCost;
  }

  mapping (string => cardTraits) cards;

    constructor(cardTraits[] memory _cards) ConfirmedOwner(msg.sender) {
         for (uint z = 0; z < _cards.length; z++) {
            cards[Strings.toString(z + 10)] = _cards[z];
        }

    }

    function checkHandSize(bytes memory _hand) external pure returns (bool) {
        bool valid = true;
        uint handSize = _hand.length / 2;
        if (handSize > 6) {
            valid = false;
        }
        return (valid);
    }

    function getData(bytes memory hand, bytes memory actions) external pure returns (uint8, uint8, bytes[] memory, bytes[] memory, bytes[] memory) {
            uint handSize = hand.length;
            uint8 handIndex = 0;
            bytes[] memory arrHand = new bytes[](handSize);
            for (uint8 i = 0; i < handSize; i++) {
                bytes memory card = new bytes(2);
                card[0] = hand[handIndex];
                handIndex += 1;
                card[1] = hand[handIndex];
                handIndex += 1;
                arrHand[i] = card;
            }

            uint8 leadByte1 = uint8(actions[0]);
            uint8 leadByte2 = uint8(actions[1]);
           
            uint8 index = 2;
            bytes[] memory handActions = new bytes[](leadByte1);
            bytes[] memory fieldActions = new bytes[](leadByte2);
            for (uint8 j = 0; j < leadByte1 + leadByte2; j++) {
                bytes memory action = new bytes(4);
                action[0] = actions[index];
                index += 1;
                action[1] = actions[index];
                index += 1;
                action[2] = actions[index];
                index += 1;
                action[3] = actions[index];
                index += 1;
                if (j < leadByte1) {
                    handActions[j] = action;
                }
                else {
                    fieldActions[j-leadByte1] = action;
                }
            }
            return(leadByte1, leadByte2, arrHand, handActions, fieldActions);
    }


    function checkHandActions (uint8 leadByte, bytes[] memory _hand, bytes[] memory handActions, bytes[] memory playerField, bytes[] memory opponentField) external view returns (bool) {
        bytes[] memory hand = _hand;
        uint handSize = hand.length;
        uint playerFieldSize = playerField.length;
        uint opponentFieldSize = opponentField.length;
        for (uint8 k = 0; k < leadByte; k++) {
            bytes memory cardId = new bytes(2);
            uint8 targetTeam;
            uint8 targetIndex;
            cardId[0] = handActions[k][0];
            cardId[1] = handActions[k][1];
            targetTeam = uint8(handActions[k][2]);
            targetIndex = uint8(handActions[k][3]);
            cardTraits memory targetCard = cards[string(opponentField[targetIndex])];
            bool exists = false;
            uint8 selector;
            //check if hand contains acting card

            for (uint8 l = 0; l < handSize; l++) {
                if (keccak256(cardId) == keccak256(hand[l])) {
                    exists = true;
                    selector = l;
                    }
                }

            if (exists == false) {
                return(false);
                }
            else {
                hand[selector] = hand[hand.length - 1];
                hand[hand.length - 1] = new bytes(2);
                }

            //validate action by card type and target
            //7: No Target  8: Opponent is Target   9: Player is Target
            if (targetTeam == 8) {
                if (targetIndex >= opponentFieldSize) {
                    return(false);
                    }
                }
            else if (targetTeam == 9) {
                if (targetIndex >= playerFieldSize) {
                        return(false);
                    }
                }

            cardTraits memory card = cards[string(cardId)];
            //This is the player turn, so automatically these types of cards enter the player field
            if (card.cardType == cType.CRYSTAL || card.cardType == cType.CONSTRUCT) {
                if (playerFieldSize == 9) {
                    return(false);
                }
                else {
                    playerFieldSize += 1;
                    }
                }

        }

    return(true);
  }

  
  function checkFieldActions (uint8 leadByte, bytes[] memory fieldActions, bytes[] memory _playerField, bytes[] memory opponentField) external pure returns (bool) {
        bytes[] memory playerField = _playerField;
        uint playerFieldSize = playerField.length;
        uint opponentFieldSize = opponentField.length;
        for (uint8 k = 0; k < leadByte; k++) {
            uint8 unitIndex;
            uint8 unitAction;
            uint8 targetTeam;
            uint8 targetIndex;
            unitIndex = uint8(fieldActions[k][0]);
            unitAction = uint8(fieldActions[k][1]);
            targetTeam = uint8(fieldActions[k][2]);
            targetIndex = uint8(fieldActions[k][3]);
        
            if (unitIndex >= playerFieldSize) {
                return false;
            }
            

            //validate action by card type and target
            //7: No Target  8: Opponent is Target   9: Player is Target
            if (targetTeam == 8) {
                if (targetIndex >= opponentFieldSize) {
                    return(false);
                    }
                }
            else if (targetTeam == 9) {
                if (targetIndex >= playerFieldSize) {
                        return(false);
                    }
                }

            //cardTraits memory card = cards[string(playerField[unitIndex])];
                }
    return(true);
  }






  function doHandActions (uint8 leadByte, bytes[] memory handActions, bytes[] memory _playerField, bytes[] memory _opponentField) external view returns (bytes[] memory) {
        bytes[] memory playerField = _playerField;
        bytes[] memory opponentField = _opponentField;
        uint playerFieldSize = playerField.length;
        uint opponentFieldSize = opponentField.length;
        uint8 destructionIndex;
        uint8[4] memory destructible = [9,9,9,9];
        uint8[4] memory damaged = [9,9,9,9];
        for (uint8 k = 0; k < leadByte; k++) {
            bytes memory cardId = new bytes(2);
            uint8 targetTeam;
            uint8 targetIndex;
            cardId[0] = handActions[k][0];
            cardId[1] = handActions[k][1];
            targetTeam = uint8(handActions[k][2]);
            targetIndex = uint8(handActions[k][3]);
            cardTraits memory targetCard = cards[string(opponentField[targetIndex])];
            cardTraits memory card = cards[string(cardId)];
            //This is the player turn, so automatically these types of cards enter the player field
            if (card.cardType == cType.CRYSTAL || card.cardType == cType.CONSTRUCT) {
                bytes[] memory newPlayerField = new bytes[](playerFieldSize + 1);
                for (uint8 i = 0; i < playerFieldSize; i++) {
                    newPlayerField[i] = playerField[i];
                }
                newPlayerField[playerFieldSize] = cardId;
                playerFieldSize++;
                playerField = newPlayerField;
            }
            
            if (card.keywordA == cardKeyword.DESTROY) {
                destructible[destructionIndex] = targetIndex;
                destructionIndex++;
            }
            else if (card.keywordA == cardKeyword.DAMAGE1) {
                if (targetCard.defense == 1) {
                    destructible[destructionIndex] = targetIndex;
                    destructionIndex++;
                }
                else {
                    damaged[destructionIndex] = targetIndex;
                    destructionIndex++;
                }
             }

    
        }
        return(playerField);
    }

}
