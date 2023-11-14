extends Control


var ethers
var deck = {"1": "01", "2": "27", "3": "84", "4": "03", "5": "17", "6": "49", "7": "18", "8": "78", "9": "69", "10": "04"}

func _ready():
	$RegisterOpponent.connect("pressed", self, "register_opponent") 
	$RegisterPlayer.connect("pressed", self, "register_player")
	$StartGame.connect("pressed", self, "start_game")
	$ResetGame.connect("pressed", self, "reset_game")
	$PlayCard.connect("pressed", self, "play_card")

func register_opponent():
	ethers.start_transaction("register_opponent", JSON.print(deck))

func register_player():
	ethers.start_transaction("register_player", JSON.print(deck))

func start_game():
	ethers.start_transaction("start_new_card_game")
	
func reset_game():
	ethers.start_transaction("reset_game")

func play_card():
	ethers.start_transaction("play_card", $CardIndex.text)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
