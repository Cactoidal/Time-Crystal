CONTRACTS AND CHAINLINK


* [TimeCrystal.sol](https://github.com/Cactoidal/Time-Crystal/blob/main/contracts/TimeCrystal.sol) - Contains all game logic, secured by Chainlink Functions, VRF, and Automation (Log Trigger and Forwarder)
  
* [get_hand.js](https://github.com/Cactoidal/Time-Crystal/blob/main/contracts/get_hand.js) - Functions source code for decrypting player secrets and drawing random secret cards

RUST

* [lib.rs](https://github.com/Cactoidal/Time-Crystal/blob/main/godot/rust/lib.rs) - Godot-Rust and ethers-rs used to format and decode calldata, openssl used for encryption

GODOT

* [TitleScreen.gd](https://github.com/Cactoidal/Time-Crystal/blob/main/godot/TitleScreen.gd) - main script, containing all eth_call functions

* [1v1.gd](https://github.com/Cactoidal/Time-Crystal/blob/main/godot/1v1.gd) - secrets extraction, battle logic, and game process loop / flags

* Everything else: user interfaces, scenes, art assets
  

