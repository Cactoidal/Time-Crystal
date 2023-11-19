extends Control

var card = load("res://Card.tscn")
var ethers
#var deck = {"1": "10", "2": "11", "3": "12", "4": "13", "5": "14", "6": "15", "7": "16", "8": "17", "9": "18", "10": "19", "11": "20", "12": "21", "13": "22", "14": "23", "15": "24", "16": "25", "17": "26", "18": "27", "19": "28", "20": "29"}

#just straight-up card values
var opponentDeck = "10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,20"

#card indices of player inventory
var playerDeck = "0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,10"
var playerDeckId = 0
var opponentId = 0
var opponentDeckId = 0

#var your_hand = '{"1": "10", "2": "11", "3": "12", "4": "13", "5": "14"}'
var your_hand = '{"1": "10", "2": "11", "3": "17", "4": "15", "5": "19"}'

var hand = []
var card_nodes = []
var selected_card_index

var action_count = 0
#var max_energy = 1
var max_energy = 10
var used_energy = 0

var target = "None"

var actions = []
var action_strings = []

var mapped_to_board_index = []



func _ready():
	$RegisterOpponent.connect("pressed", self, "register_opponent") 
	$RegisterPlayer.connect("pressed", self, "register_player")
	$StartGame.connect("pressed", self, "start_game")
	$ResetGame.connect("pressed", self, "reset_game")
	$PlayCard.connect("pressed", self, "play_card")
	
	card_nodes = [$Card1, $Card2, $Card3, $Card4, $Card5, $Card6]
	
	$Card1/TextureButton.connect("pressed", self, "play_from_hand", [$Card1])
	$Card2/TextureButton.connect("pressed", self, "play_from_hand", [$Card2])
	$Card3/TextureButton.connect("pressed", self, "play_from_hand", [$Card3])
	$Card4/TextureButton.connect("pressed", self, "play_from_hand", [$Card4])
	$Card5/TextureButton.connect("pressed", self, "play_from_hand", [$Card5])
	$Card6/TextureButton.connect("pressed", self, "play_from_hand", [$Card6])
	
	$ActionConfirm/Confirm.connect("pressed", self, "action_confirmed")
	$ActionConfirm/Cancel.connect("pressed", self, "action_canceled")
	$Revert.connect("pressed", self, "revert_action")
	
	get_hand()

func register_opponent():
	ethers.start_transaction("register_opponent", [opponentDeck])

func register_player():
	ethers.start_transaction("register_player")

func create_deck():
	ethers.start_transaction("create_player_deck", [playerDeck])

func start_game():
	ethers.start_transaction("start_new_card_game", [playerDeckId, opponentId, opponentDeckId])
	
func reset_game():
	ethers.start_transaction("reset_game")

func play_card():
	ethers.start_transaction("play_card", [$CardIndex.text])

func _process(delta):
	$Targeting.set_point_position(1, get_global_mouse_position() - Vector2(90,40))
	#$Line2D.points[1].position = get_global_mouse_position()

#everything has a type, name, and cost
#constructs have attack and defense, crystals have only defense
#cards can have two keywords.  for crystals and constructs, keywordA is always a drop effect
func get_card_info(card_id):
	match card_id:
		10: return {"type": "construct", "name": "Paramecium", "cost": 0, "attack": 1, "defense": 1, "keywordA": "", "keywordB": ""}
		11: return {"type": "construct", "name": "Attacker", "cost": 1, "attack": 2, "defense": 1, "keywordA": "", "keywordB": ""}
		12: return {"type": "construct", "name": "Defender", "cost": 2, "attack": 1, "defense": 4, "keywordA": "SHIELD", "keywordB": ""}
		13: return {"type": "construct", "name": "Sapper", "cost": 3, "attack": 2, "defense": 2, "keywordA": "DAMAGE 1", "keywordB": ""}
		14: return {"type": "construct", "name": "Destroyer", "cost": 4, "attack": 4, "defense": 4, "keywordA": "", "keywordB": ""}
		
		15: return {"type": "crystal", "name": "Regeneration", "cost": 2, "attack": 0, "defense": 3, "keywordA": "", "keywordB": "REGENERATE"}
		16: return {"type": "crystal", "name": "Healing", "cost": 2, "attack": 0, "defense": 3, "keywordA": "", "keywordB": "HEAL 1"}
		
		17: return {"type": "power", "name": "Crystallize", "cost": 2, "attack": 0, "defense": 0, "keywordA": "DESTROY", "keywordB": ""}
		18: return {"type": "power", "name": "Shield", "cost": 1, "attack": 0, "defense": 0, "keywordA": "SHIELD", "keywordB": ""}
		
		19: return {"type": "oracle", "name": "Randomize", "cost": 2, "attack": 0, "defense": 0, "keywordA": "RANDOM", "keywordB": ""}
		20: return {"type": "oracle", "name": "Knowledge", "cost": 1, "attack": 0, "defense": 0, "keywordA": "DRAW +1", "keywordB": ""}

func get_hand():
	var inc_hand = parse_json(your_hand)
	var new_hand = []
	for card in inc_hand:
		new_hand.push_back(int(inc_hand[card]))
	hand = new_hand
	set_card_values()
	
func set_card_values():
	for image in card_nodes:
		image.visible = false
	for card in range(hand.size()):
	#for card in [0,4]:
		var card_info = get_card_info(hand[card])
		card += 1
		get_node("Card" + str(card) + "/TextureButton").texture_normal = load("res://" + card_info["type"] + "_card_base.png")
		get_node("Card" + str(card) + "/Name").text = card_info["name"]
		get_node("Card" + str(card) + "/CostSquare/Cost").text = str(card_info["cost"])
		if card_info["type"] == "construct":
			get_node("Card" + str(card) + "/Attack").text = str(card_info["attack"])
			get_node("Card" + str(card) + "/Defense").text = str(card_info["defense"])
		else:
			get_node("Card" + str(card) + "/Attack").text = ""
			get_node("Card" + str(card) + "/Defense").text = ""
		if card_info["type"] == "crystal":
			get_node("Card" + str(card) + "/Defense").text = str(card_info["defense"])
		get_node("Card" + str(card) + "/KeywordA").text = card_info["keywordA"]
		get_node("Card" + str(card) + "/KeywordB").text = card_info["keywordB"]
		get_node("Card" + str(card)).visible = true
		
		#temporary
		if card_info["type"] == "oracle":
			get_node("Card" + str(card) + "/KeywordA").material = null
			get_node("Card" + str(card) + "/KeywordB").material = null
			get_node("Card" + str(card) + "/Name").material = null
		

var playing = false
func play_from_hand(unit):
	if playing == false:
		if action_count < 4:
			playing = true
			selected_card_index = card_nodes.find(unit)
			for image in card_nodes:
				if image != unit:
					image.get_node("Overlay").visible = true
				else:
					image.get_node("Overlay").visible = false
					
			var card_info = get_card_info(hand[selected_card_index])
			if card_info["type"] in ["power"] || card_info["keywordA"] in ["SHIELD", "DAMAGE 1", "REGENERATE"]:
				$Targeting.set_point_position(0, unit.rect_position)
				$Targeting.visible = true
			else:
				open_action_confirm()
		else:
			#put indicator here
			print("Actions Maxed")
	else:
		for image in card_nodes:
			if !image in actions:
				image.get_node("Overlay").visible = false
		$Targeting.visible = false
		playing = false
		

func play_from_field(unit):
	pass


var confirmable = false
func open_action_confirm():
	$Overlay.visible = true
	$ActionConfirm.visible = true
	var card_info = get_card_info(hand[selected_card_index])
	$ActionConfirm/Cost.text = "Energy Cost:\n" + str(card_info["cost"])
	if used_energy + card_info["cost"] > max_energy:
		$ActionConfirm/NoEnergy.visible = true
		confirmable = false
	else:
		$ActionConfirm/NoEnergy.visible = false
		confirmable = true

	if target != "None":
		if card_info["type"] == "power":
			$ActionConfirm/Question.text = "Use " + card_info["name"] + "\non " + target + "?"
		else:
			$ActionConfirm/Question.text = "Deploy " + card_info["name"] + "\n and use " + card_info["keywordA"] + "\non " + target + "?"
	elif card_info["type"] == "crystal":
		$ActionConfirm/Question.text = "Deploy " + card_info["name"] + " Crystal?"
	elif card_info["type"] == "oracle":
		$ActionConfirm/Question.text = "Request oracle for " + card_info["name"] + "?"
	else:
		$ActionConfirm/Question.text = "Deploy " + card_info["name"] + "?"

func action_confirmed():
	if confirmable == true:
		$Overlay.visible = false
		$ActionConfirm.visible = false
		playing = false
		var card_info = get_card_info(hand[selected_card_index])
		for image in card_nodes:
			if image != card_nodes[selected_card_index]:
				if !image in actions:
					image.get_node("Overlay").visible = false
		card_nodes[selected_card_index].get_node("Overlay").visible = true
		actions.append(card_nodes[selected_card_index])
		action_count += 1
		used_energy += card_info["cost"]
		$Actions.text = "Actions\n" + str(action_count) + "/ 4"
		$Energy.text = "Energy\n" + str(used_energy) + " / " + str(max_energy)
		action_strings.append("\nPlayed " + card_info["name"] + "(" + str(card_info["cost"]) + ")")
		if action_count == 4:
			action_strings[3] += "\n\nACTIONS MAXED"
		$ActionsLog.text = ""
		for line in action_strings:
			$ActionsLog.text += line

func action_canceled():
	$Overlay.visible = false
	$ActionConfirm.visible = false
	playing = false
	for image in card_nodes:
		if !image in actions:
			image.get_node("Overlay").visible = false
	

func revert_action():
	if action_count > 0:
		var reverted = actions.pop_back()
		var index = card_nodes.find(reverted)
		var card_info = get_card_info(hand[index])
		reverted.get_node("Overlay").visible = false
		action_count -= 1
		used_energy -= card_info["cost"]
		$Actions.text = "Actions\n" + str(action_count) + "/ 4"
		$Energy.text = "Energy\n" + str(used_energy) + " / " + str(max_energy)
		action_strings.pop_back()
		$ActionsLog.text = ""
		for line in action_strings:
			$ActionsLog.text += line
