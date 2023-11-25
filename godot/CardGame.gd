extends Control

var card = load("res://Card.tscn")
var paramecium = load("res://Paramecium.tscn")
var crystal = load("res://Crystal.tscn")
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

var board
var board_nodes = []
var selected_board_index

var player_units = ["10", "11", "15"]
var opponent_units = ["11", "10", "15"]

var player_mapped_to_board_index = []
var opponent_mapped_to_board_index = []

var board_targeting_activated = false

var action_count = 0
#var max_energy = 1
var max_energy = 10
var used_energy = 0

var seeking_target = false
var pending_actor
var active_card
var target = "None"

var actions = []
var action_strings = []

var oracle_used = false


# hand extraction

var deck = [10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30]
var password
var target_hash
var thread
var discovered_hand
var password_cards
var combination
var guessHash



func _ready():
	
	$RegisterPlayer.connect("pressed", self, "register_player")
	$JoinMatchmaking.connect("pressed", self, "join_matchmaking") 
	$CheckHand.connect("pressed", self, "check_hand") 
	$MakeMove.connect("pressed", self, "make_move") 
	$DeclareVictory.connect("pressed", self, "declare_victory")
	$CheckWon.connect("pressed", self, "check_won")
	
	$EndTurn.connect("pressed", self, "open_end_turn_confirm")
	
	card_nodes = [$Card1, $Card2, $Card3, $Card4, $Card5, $Card6]
	board = get_parent().get_node("WorldRotate")
	board_nodes = board.get_children()
	
	#randomize()
	#var randomizer = Crypto.new()
	#var bytes = Crypto.new()
	password = "hello".sha256_text().left(20)
	#password = (String(bytes.generate_random_bytes(16))).sha256_text().left(20)
	
	$Card1/TextureButton.connect("pressed", self, "play_from_hand", [$Card1])
	$Card2/TextureButton.connect("pressed", self, "play_from_hand", [$Card2])
	$Card3/TextureButton.connect("pressed", self, "play_from_hand", [$Card3])
	$Card4/TextureButton.connect("pressed", self, "play_from_hand", [$Card4])
	$Card5/TextureButton.connect("pressed", self, "play_from_hand", [$Card5])
	$Card6/TextureButton.connect("pressed", self, "play_from_hand", [$Card6])
	
	$ActionConfirm/Confirm.connect("pressed", self, "action_confirmed")
	$ActionConfirm/Cancel.connect("pressed", self, "action_canceled")
	$Revert.connect("pressed", self, "revert_action")
	$EndTurnConfirm/Confirm.connect("pressed", self, "end_turn_confirmed")
	$EndTurnConfirm/Cancel.connect("pressed", self, "end_turn_canceled")
	
	$TargetConfirm/Confirm.connect("pressed", self, "target_confirmed")
	$TargetConfirm/Cancel.connect("pressed", self, "target_canceled")
	
	populate_cards()
	map_random_spaces()
	assign_units()

#fix name later
func join_matchmaking():
	ethers.start_transaction("join_matchmaking", [password])

func register_player():
	ethers.start_transaction("register_player")

func check_hand():
	ethers.check_player_cards()
	
func make_move():
	ethers.start_transaction("make_move", [$CardEntry.text])
	
func declare_victory():
	ethers.start_transaction("declare_victory", [password_cards])

func check_won():
	ethers.check_won()


func create_deck():
	ethers.start_transaction("create_player_deck", [playerDeck])

var confirming_target = false


var started = false
func _process(delta):
	if confirming_target == false:
		$Targeting.set_point_position(1, get_global_mouse_position() - Vector2(90,40))
	if started == true:
		if got == false:
			if !thread.is_alive():
				got = true
				thread.wait_to_finish()
				print(guessHash)
				$YourHand.text = "Your Hand:\n" + combination

var got = false
func extract_hand():
	started = true
	thread = Thread.new()
	thread.start(self, "extract")
	

func extract():
	for number1 in deck:
			for number2 in deck:
					for number3 in deck:
							for number4 in deck:
									for number5 in deck:
											for number6 in range(10):
												var guess = password + String(number1) + String(number2) + String(number3) + String(number4) + String(number5) + String(number6)
												if guess.sha256_text() == target_hash:
													password_cards = guess
													combination = guess.substr(20)
													guessHash = guess.sha256_text()
													return

#everything has a type, name, and cost
#constructs have attack and defense, crystals have only defense
#cards can have two keywords.  for crystals and constructs, keywordA is always a drop effect
#need to imeplement drop abilities, multiple abilities, and separate ability energy costs
func get_card_info(card_id):
	match card_id:
		10: return {"id": "10", "type": "construct", "name": "Paramecium", "cost": 0, "attack": 1, "defense": 1, "keywordA": "", "keywordB": ""}
		11: return {"id": "11", "type": "construct", "name": "Attacker", "cost": 1, "attack": 2, "defense": 1, "keywordA": "", "keywordB": ""}
		12: return {"id": "12", "type": "construct", "name": "Defender", "cost": 2, "attack": 1, "defense": 4, "keywordA": "SHIELD", "keywordB": ""}
		13: return {"id": "13", "type": "construct", "name": "Sapper", "cost": 3, "attack": 2, "defense": 2, "keywordA": "DAMAGE 1", "keywordB": ""}
		14: return {"id": "14", "type": "construct", "name": "Destroyer", "cost": 4, "attack": 4, "defense": 4, "keywordA": "", "keywordB": ""}
		
		15: return {"id": "15", "type": "crystal", "name": "Regeneration", "cost": 2, "attack": 0, "defense": 3, "keywordA": "", "keywordB": "REGENERATE"}
		16: return {"id": "16", "type": "crystal", "name": "Healing", "cost": 2, "attack": 0, "defense": 3, "keywordA": "", "keywordB": "HEAL 1"}
		
		17: return {"id": "17", "type": "power", "name": "Crystallize", "cost": 2, "attack": 0, "defense": 0, "keywordA": "DESTROY", "keywordB": ""}
		18: return {"id": "18", "type": "power", "name": "Shield", "cost": 1, "attack": 0, "defense": 0, "keywordA": "SHIELD", "keywordB": ""}
		
		19: return {"id": "19", "type": "oracle", "name": "Randomness", "cost": 2, "attack": 0, "defense": 0, "keywordA": "RANDOM", "keywordB": ""}
		20: return {"id": "20", "type": "oracle", "name": "Knowledge", "cost": 1, "attack": 0, "defense": 0, "keywordA": "DRAW +1", "keywordB": ""}

func get_new_card_info(card_id):
	match card_id:
		10: return {"id": "10", "type": "normal", "name": "Laser", "cost": 0, "attack": 20, "defense": 0}
		11: return {"id": "11", "type": "normal", "name": "Energy Wave", "cost": 0, "attack": 20, "defense": 0}
		12: return {"id": "12", "type": "normal", "name": "Pulsar", "cost": 0, "attack": 30, "defense": 0}
		13: return {"id": "13", "type": "normal", "name": "Bonk", "cost": 0, "attack": 20, "defense": 0}
		14: return {"id": "14", "type": "normal", "name": "Irradiate", "cost": 0, "attack": 25, "defense": 0}
		15: return {"id": "15", "type": "normal", "name": "Cold Glow", "cost": 0, "attack": 15, "defense": 15}
		16: return {"id": "16", "type": "normal", "name": "Ice Barrier", "cost": 0, "attack": 20, "defense": 20}
		17: return {"id": "17", "type": "normal", "name": "Sun Guard", "cost": 0, "attack": 20, "defense": 20}
		18: return {"id": "18", "type": "normal", "name": "Crunch", "cost": 0, "attack": 25, "defense": 0}
		19: return {"id": "19", "type": "normal", "name": "Rainbow Shroud", "cost": 0, "attack": 20, "defense": 20}
		20: return {"id": "20", "type": "normal", "name": "Aurora", "cost": 0, "attack": 20, "defense": 20}
		21: return {"id": "21", "type": "power", "name": "Power Beam", "cost": 0, "attack": 20, "defense": 0}
		22: return {"id": "22", "type": "power", "name": "Rust", "cost": 0, "attack": 20, "defense": 0}
		23: return {"id": "23", "type": "normal", "name": "Crystallize", "cost": 0, "attack": 20, "defense": 20}
		24: return {"id": "24", "type": "normal", "name": "Disrupt", "cost": 0, "attack": 20, "defense": 0}
		25: return {"id": "25", "type": "power", "name": "Explosion", "cost": 0, "attack": 30, "defense": 0}
		26: return {"id": "26", "type": "normal", "name": "Crystal Laser", "cost": 0, "attack": 30, "defense": 0}
		27: return {"id": "27", "type": "power", "name": "Distintegrate", "cost": 0, "attack": 30, "defense": 0}
		28: return {"id": "28", "type": "normal", "name": "Void Shield", "cost": 0, "attack": 20, "defense": 30}
		29: return {"id": "29", "type": "normal", "name": "Seeker Missile", "cost": 0, "attack": 30, "defense": 0}
		30: return {"id": "30", "type": "normal", "name": "Prismatic Cloud", "cost": 0, "attack": 20, "defense": 20}
		

func populate_cards():
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
		

func map_random_spaces():
	randomize()
	for node in range(15):
		player_mapped_to_board_index.append(board_nodes[node])
	
	for node in range(15,30):
		opponent_mapped_to_board_index.append(board_nodes[node])
		
	player_mapped_to_board_index.shuffle()
	opponent_mapped_to_board_index.shuffle()

func assign_units():			
	for unit in range(player_units.size()):
		var card_info = get_card_info(int(player_units[unit]))
		var mesh
		if card_info["type"] == "construct":
			mesh = paramecium.instance()
		elif card_info["type"] == "crystal":
			mesh = crystal.instance()
		player_mapped_to_board_index[unit].add_child(mesh)
		mesh.set_info(card_info.duplicate())
		mesh.get_node("Info/Team").text = "Player"
		mesh.info_square_overlay = $InfoSquareOverlay
		mesh.card_nodes = card_nodes
		mesh.ui = self
		mesh.player_unit_index = unit
		mesh.global_transform.origin.y += 1
		mesh.rotate_y(0.4)
		
		
	for unit in range (opponent_units.size()):
		var card_info = get_card_info(int(opponent_units[unit]))
		var mesh
		if card_info["type"] == "construct":
			mesh = paramecium.instance()
		elif card_info["type"] == "crystal":
			mesh = crystal.instance()
		opponent_mapped_to_board_index[unit].add_child(mesh)
		mesh.mod = -1
		mesh.set_info(card_info.duplicate())
		mesh.get_node("Info/Team").text = "Opponent"
		mesh.info_square_overlay = $InfoSquareOverlay
		mesh.card_nodes = card_nodes
		mesh.ui = self
		mesh.global_transform.origin.y += 1
		mesh.rotate_y(0.4)
	
	
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
			#add drop abilities
			if card_info["type"] in ["power"] || card_info["keywordA"] in ["SHIELD", "DAMAGE 1", "REGENERATE"]:
				$Targeting.set_point_position(0, unit.rect_position)
				$Targeting.visible = true
				$InfoSquareOverlay.visible = true
				board_targeting_activated = true
				seeking_target = true
				active_card = card_info.duplicate()
				pending_actor = unit
			else:
				open_action_confirm()
		#else:
			#put indicator here
			#print("Actions Maxed")
	else:
		for image in card_nodes:
			if !image in actions:
				image.get_node("Overlay").visible = false
		for action in actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true
		$Targeting.visible = false
		playing = false
		$InfoSquareOverlay.visible = false
		board_targeting_activated = false


var confirmable = false
func open_action_confirm():
	$Overlay.visible = true
	$ActionConfirm.visible = true
	$ActionConfirm/OracleCalled.visible = false
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
		$ActionConfirm/Question.text = "Request " + card_info["name"] + "\nfrom oracle?"
		if oracle_used == true:
			$ActionConfirm/OracleCalled.visible = true
	else:
		$ActionConfirm/Question.text = "Deploy " + card_info["name"] + "?"

func action_confirmed():
	var card_info = get_card_info(hand[selected_card_index])
	var placed = false
	if card_info["type"] == "oracle":
		if oracle_used == true:
			return
	elif card_info["type"] in ["construct", "crystal"]:
		if player_units.size() == 9:
			return
	if confirmable == true:
		#target = "None"
		#active_card = null
		$Overlay.visible = false
		$ActionConfirm.visible = false
		playing = false
		if card_info["type"] == "oracle":
			oracle_used = true
		if card_info["type"] in ["construct", "crystal"]:
			place_unit(card_info.duplicate())
			placed = true
		for image in card_nodes:
			if image != card_nodes[selected_card_index]:
				if !image in actions:
					image.get_node("Overlay").visible = false
		for action in actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true
		card_nodes[selected_card_index].get_node("Overlay").visible = true
		if placed == false:
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
		if oracle_used == true:
			$ActionsLog.text += "\nORACLE CALLED"

func action_canceled():
	$Overlay.visible = false
	$ActionConfirm.visible = false
	playing = false
	for image in card_nodes:
		if !image in actions:
			image.get_node("Overlay").visible = false
	for action in actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true


#add drop abilities
func open_target_confirm():
	confirming_target = true
	$Overlay.visible = true
	$TargetConfirm.visible = true
	#will need to be altered to accommodate drop abilities
	var keyword
	if active_card["type"] == "power":
		keyword = "keywordA"
	else:
		keyword = "keywordB"
	var if_crystal = ""
	if target.card_info["type"] == "crystal":
		if_crystal = " Crystal"
	var team = target.get_node("Info/Team").text
	$TargetConfirm/Question.text = "Use " + active_card[keyword] + "\non " + team + "'s\n"+ target.card_info["name"] + if_crystal + "?"
	$TargetConfirm/Cost.text = str(active_card["cost"])
	if used_energy + active_card["cost"] > max_energy:
		$TargetConfirm/NoEnergy.visible = true
		confirmable = false
	else:
		$TargetConfirm/NoEnergy.visible = false
		confirmable = true
		
		
func target_confirmed():
	if confirmable == true:
		confirming_target = false
		$Overlay.visible = false
		$Targeting.visible = false
		$TargetConfirm.visible = false
		$InfoSquareOverlay.visible = false
		playing = false
		board_targeting_activated = false
		
		#will need to be altered to accommodate drop abilities
		var keyword
		if active_card["type"] == "power":
			keyword = "keywordA"
		else:
			keyword = "keywordB"
		
	
		actions.append(pending_actor)
		for image in card_nodes:
			if selected_card_index != null:
				if image != card_nodes[selected_card_index]:
					if !image in actions:
						image.get_node("Overlay").visible = false
			else:
				if !image in actions:
						image.get_node("Overlay").visible = false
		for action in actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true
		
		if !pending_actor in card_nodes:
			pending_actor.targeting = false
			pending_actor.selected = false
			#this is a placeholder and could be replaced by "using_ability"
			pending_actor.attacking = true
		else:
			card_nodes[selected_card_index].get_node("Overlay").visible = true
		
		action_count += 1
		used_energy += active_card["cost"]
		$Actions.text = "Actions\n" + str(action_count) + "/ 4"
		$Energy.text = "Energy\n" + str(used_energy) + " / " + str(max_energy)
		
		action_strings.append("\nUsed " + active_card[keyword] + "\non " + target.card_info["name"] + "(" + str(active_card["cost"]) + ")")
		if action_count == 4:
			action_strings[3] += "\n\nACTIONS MAXED"
		$ActionsLog.text = ""
		for line in action_strings:
			$ActionsLog.text += line
		if oracle_used == true:
			$ActionsLog.text += "\nORACLE CALLED"
		
		target = "None"
		active_card = null
		pending_actor = null


func target_canceled():
	if !pending_actor in card_nodes:
		pending_actor.targeting = false
		pending_actor.selected = false
	target = "None"
	active_card = null
	pending_actor = null
	confirming_target = false
	playing = false
	board_targeting_activated = false
	$Overlay.visible = false
	$Targeting.visible = false
	$TargetConfirm.visible = false
	$InfoSquareOverlay.visible = false
	for image in card_nodes:
		if selected_card_index != null:
			if image != card_nodes[selected_card_index]:
				if !image in actions:
					image.get_node("Overlay").visible = false
		else:
			if !image in actions:
				image.get_node("Overlay").visible = false
	for action in actions:
		if !action in card_nodes:
			if action.mapped_card != null:
				action.mapped_card.get_node("Overlay").visible = true

func revert_action():
	if action_count > 0:
		var reverted = actions.pop_back()
		if reverted in card_nodes:
			var index = card_nodes.find(reverted)
			var card_info = get_card_info(hand[index])
			reverted.get_node("Overlay").visible = false
			used_energy -= card_info["cost"]
			if card_info["type"] == "oracle":
				oracle_used = false
		else:
			if reverted.attacking == true:
				reverted.attacking = false;
				#placeholder until constructs also can use ability from field
				if reverted.card_info["type"] == "crystal":
					used_energy -= reverted.card_info["cost"]
			#elif to preclude removing a same-turn attack following a placement
			elif reverted.mapped_card != null:
				var index = card_nodes.find(reverted.mapped_card)
				var card_info = get_card_info(hand[index])
				reverted.mapped_card.get_node("Overlay").visible = false
				used_energy -= card_info["cost"]
				player_units.remove(reverted.player_unit_index)
				reverted.queue_free()
			#reverting cost of unit on field using ability
			else:
				used_energy -= reverted.card_info["cost"]
		action_count -= 1
		$Actions.text = "Actions\n" + str(action_count) + "/ 4"
		$Energy.text = "Energy\n" + str(used_energy) + " / " + str(max_energy)
		action_strings.pop_back()
		$ActionsLog.text = ""
		for line in action_strings:
			$ActionsLog.text += line
		if oracle_used == true:
			$ActionsLog.text += "\nORACLE CALLED"


func place_unit(card_info):
	var mesh
	if card_info["type"] == "construct":
		mesh = paramecium.instance()
	elif card_info["type"] == "crystal":
		mesh = crystal.instance()
	player_units.append(card_info["id"])
	player_mapped_to_board_index[player_units.size() - 1].add_child(mesh)
	mesh.set_info(card_info.duplicate())
	mesh.get_node("Info/Team").text = "Player"
	mesh.info_square_overlay = $InfoSquareOverlay
	mesh.card_nodes = card_nodes
	mesh.ui = self
	mesh.global_transform.origin.y += 1
	mesh.player_unit_index = player_units.size() - 1
	mesh.rotate_y(0.4)
	mesh.mapped_card = card_nodes[selected_card_index]
	actions.append(mesh)
	

func open_end_turn_confirm():
	$Overlay.visible = true
	$EndTurnConfirm.visible = true
	$EndTurnConfirm/Cost.text = "Energy Used:\n" + str(used_energy) + " / " + str(max_energy)
	$EndTurnConfirm/Question.text = "End Turn?\n\n"
	for line in action_strings:
		$EndTurnConfirm/Question.text += line

func end_turn_confirmed():
	$Overlay.visible = false
	$EndTurnConfirm.visible = false

func end_turn_canceled():
	$Overlay.visible = false
	$EndTurnConfirm.visible = false
