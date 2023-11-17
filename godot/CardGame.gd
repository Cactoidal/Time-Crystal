extends Control


var ethers
#var deck = {"1": "10", "2": "11", "3": "12", "4": "13", "5": "14", "6": "15", "7": "16", "8": "17", "9": "18", "10": "19", "11": "20", "12": "21", "13": "22", "14": "23", "15": "24", "16": "25", "17": "26", "18": "27", "19": "28", "20": "29"}

#just straight-up card values
var opponentDeck = "10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,20"

#card indices of player inventory
var playerDeck = "0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,10"
var playerDeckId = 0
var opponentDeckId = 0

func _ready():
	$RegisterOpponent.connect("pressed", self, "register_opponent") 
	$RegisterPlayer.connect("pressed", self, "register_player")
	$StartGame.connect("pressed", self, "start_game")
	$ResetGame.connect("pressed", self, "reset_game")
	$PlayCard.connect("pressed", self, "play_card")

func register_opponent():
	ethers.start_transaction("register_opponent", [opponentDeck])

func register_player():
	ethers.start_transaction("register_player")

func create_deck():
	ethers.start_transaction("create_player_deck", [playerDeck])

func start_game():
	ethers.start_transaction("start_new_card_game", [playerDeckId, opponentDeckId])
	
func reset_game():
	ethers.start_transaction("reset_game")

func play_card():
	ethers.start_transaction("play_card", [$CardIndex.text])

#func _process(delta):
#	pass
