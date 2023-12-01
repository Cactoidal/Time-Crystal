extends Control


var ethers
var opponent
var draw_camera
var camera



var card_flip = load("res://CardFlip.tscn")

# hand extraction
var deck = [10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30]
var password
var target_hash
var thread
var hand = []
var password_cards
var combination
var guessHash

# commit-reveal

var action_password
var action_id



# stats

var player_max_hp
var player_hp
var opponent_max_hp
var opponent_hp
var player_energy = 0
var opponent_energy = 0
var player_pow
var player_def
var opponent_pow
var opponent_def

func _ready():
	
	$RegisterPlayer.connect("pressed", self, "register_player")
	$JoinMatchmaking.connect("pressed", self, "join_matchmaking") 
	$CheckHand.connect("pressed", self, "check_hand") 
	$CommitAction.connect("pressed", self, "commit_action") 
	$RevealAction.connect("pressed", self, "reveal_action")
	$DeclareVictory.connect("pressed", self, "declare_victory")
	$CheckWon.connect("pressed", self, "check_won")
	$GetOpponent.connect("pressed", self, "get_opponent")
	$CheckOpponentCommit.connect("pressed", self, "did_opponent_commit")
	
	$CheckHashMonster.connect("pressed", self, "get_hash_monster")
	$CheckOpponentHashMonster.connect("pressed", self, "get_opponent_hash_monster")
	$CheckPlayerBoard.connect("pressed", self, "get_player_actions")
	$CheckOpponentBoard.connect("pressed", self, "get_opponent_actions")
	$Overlay/EndGame/Return.connect("pressed", self, "end_game")
	
	camera = get_parent().get_node("WorldRotate/Pivot/BattleCamera")
	#randomize()
	#var randomizer = Crypto.new()
	#var bytes = Crypto.new()
	password = "hello".sha256_text().left(20)
	action_password = password
	action_id = "10"
	
	
	#password = (String(bytes.generate_random_bytes(16))).sha256_text().left(20)

func join_matchmaking():
	ethers.start_transaction("join_matchmaking", [password])

func register_player():
	ethers.start_transaction("register_player")

func check_hand():
	ethers.check_player_cards()
	
func get_opponent():
	ethers.get_opponent()

# * #	
func get_hash_monster():
	ethers.get_player_hash_monster()

# * #
func get_opponent_hash_monster():
	#must retrieve opponent address first
	ethers.get_opponent_hash_monster(opponent)
	
func commit_action(action):
	action_id = action
	#action_id = $CardEntry.text
	var secret = action_password + action_id
	ethers.start_transaction("commit_action", [secret])
	in_commit_phase = true

# * #
func did_player_commit():
	ethers.check_commit(ethers.user_address)
	
func did_opponent_commit():
	ethers.check_commit(opponent)

func reveal_action():
	ethers.start_transaction("reveal_action", [action_password, action_id])

# * #
func get_player_actions():
	ethers.get_player_actions()

# * #
func get_opponent_actions():
	ethers.get_opponent_actions(opponent)
	
func declare_victory():
	ethers.start_transaction("declare_victory", [password_cards])

func check_won():
	ethers.check_won()
	
func fade_queue_scene(delta):
	if $Blue.modulate.a > 0:
		$Blue.modulate.a -= delta
		if $Blue.modulate.a < 0:
			$Blue.modulate.a = 0
	camera.global_transform.origin.y += delta/3
	camera.global_transform.origin.z += delta/4.2
	camera.get_parent().rotate_y(0.001)
	
	

var hand_wait_simulation_timer = 1
#var hand_wait_simulation_timer = 11
var simulate_opponent_wait = false
var opponent_wait_simulation_timer = 18
#var opponent_wait_simulation_timer = 1

var started = false
var check_timer = 2
var find_player_hand = true
var battler_fade_in = false
var draw_sequence = false
var draw_timer = 1
var find_opponent = false
var battle_start_sequence = false
#var battle_start_timer = 45
var battle_start_timer = 60
var battle_ongoing = false
var fade_in_battler_stats = false
var player_commit_found = false
var in_commit_phase = false
var in_reveal_phase = false

var fade_in_ending = false

#var revealed = true
func _process(delta):
#	if revealed == true:
#		reveal_action()
#		revealed = false
#
	if hand_wait_simulation_timer > 0:
		hand_wait_simulation_timer -= delta
		
	
	if opponent_wait_simulation_timer > 0 && simulate_opponent_wait == true:
		opponent_wait_simulation_timer -= delta
	
	if battler_fade_in == true:
		$Blue/Battler.modulate.a += delta
		if $Blue/Battler.modulate.a > 1:
			$Blue/Battler.modulate.a = 1
			battler_fade_in = false
			
	if fade_in_battler_stats == true:
		if $OpponentStats.modulate.a < 1:
			$OpponentStats.modulate.a += delta
			if $OpponentStats.modulate.a > 1:
				$OpponentStats.modulate.a = 1
				
		if $PlayerStats.modulate.a < 1:
			$PlayerStats.modulate.a += delta
			if $PlayerStats.modulate.a > 1:
				$PlayerStats.modulate.a = 1
				fade_in_battler_stats = false
	
	if fade_in_ending == true:
		if $Overlay.modulate.a < 1:
			$Overlay.modulate.a += delta
			if $Overlay.modulate.a > 1:
				$Overlay.modulate.a = 1
	
	if draw_sequence == true:
		if draw_timer > 0:
			draw_timer -= delta
				
			if draw_timer < 0:
				print("flip")
				card_flip()
				draw_timer = 1
				if card_selector > 5:
					draw_sequence = false
					find_opponent = true
					$Scroll/AwaitingOpponent.start_scroll = true
					$Scroll/AwaitingOpponent.visible = true
					check_timer = 2
					print("draw sequence over")
		
		
	
	
	if battle_start_sequence == true:
		$Scroll/AwaitingOpponent.text = "BATTLE STARTING...						BATTLE STARTING...						BATTLE STARTING...						BATTLE STARTING...						"
		fade_queue_scene(delta)
		battle_start_timer -= delta*3
		if battle_start_timer < 0:
			battle_start_sequence = false
			battle_ongoing = true
			fade_in_battler_stats = true
			$Scroll/AwaitingOpponent.text = "CHOOSE ACTION...						CHOOSE ACTION...						CHOOSE ACTION...						CHOOSE ACTION...						"
			print("battle started")
			for card in $Cards.get_children():
				card.activated = true
				card.glow(player_energy)
		
	if check_timer > 0:
		check_timer -= delta
		if check_timer < 0:
			
			if find_player_hand == true && hand_wait_simulation_timer <= 0:
				check_hand()
				get_hash_monster()
				simulate_opponent_wait = true
			
			if find_opponent == true && opponent_wait_simulation_timer <= 0:
				get_opponent()
			
			if battle_ongoing == true:
				print("waiting for cards")
			
			if in_commit_phase == true || in_reveal_phase == true:
				if player_commit_found == true:
					did_opponent_commit()
				else:
					did_player_commit()
				
				
			check_timer = 10
	
	if started == true:
		if got == false:
			if !thread.is_alive():
				got = true
				thread.wait_to_finish()
				var first_card = combination.substr(0,2)
				var second_card = combination.substr(2,2)
				var third_card = combination.substr(4,2)
				var fourth_card = combination.substr(6,2)
				var fifth_card = combination.substr(8,2)
				var sixth_card = combination.substr(10,2)
				hand = [int(first_card), int(second_card), int(third_card), int(fourth_card), int(fifth_card), int(sixth_card)]
				draw_sequence = true
			
				$YourHand.text = "Your Hand: " + first_card + ", " + second_card + ", " + third_card + ", " + fourth_card + ", " + fifth_card + ", " + sixth_card
				#$YourHand.text = "Your Hand:\n" + combination
				
				$HandCards.text = "Hand Cards:\n\n" + get_card_info(int(first_card))["name"] + "\n" + get_card_info(int(second_card))["name"] + "\n" + get_card_info(int(third_card))["name"] + "\n" + get_card_info(int(fourth_card))["name"] + "\n" + get_card_info(int(fifth_card))["name"] + "\n" + get_card_info(int(sixth_card))["name"]

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
										#default card "Attack" (99) always at the end
											var guess = password + String(number1) + String(number2) + String(number3) + String(number4) + String(number5) + String(99)
											if guess.sha256_text() == target_hash:
												password_cards = guess
												combination = guess.substr(20)
												guessHash = guess.sha256_text()
												return

var card_selector = 0
var card_destination = Vector2(73,73)
func card_flip():
	var new_card = card_flip.instance()
	new_card.card_info = get_card_info(hand[card_selector])
	new_card.card_destination = card_destination
	new_card.ethers = self
	card_selector += 1
	card_destination.y += 90
	$Cards.add_child(new_card)

func set_player_stats(battler_id):
	var stats = get_battler_info(battler_id)
	$PlayerStats/Name.text = stats["name"]
	$PlayerStats/Type.text = "TYPE " + stats["type"]
	$PlayerStats/HP.text = "HP: " + String(stats["HP"]) + " / " + String(stats["HP"])
	$PlayerStats/POW.text = "POW: " + String(stats["POW"])
	$PlayerStats/DEF.text = "DEF: " + String(stats["DEF"])
	player_max_hp = stats["HP"]
	player_hp = stats["HP"]
	player_pow = stats["POW"]
	player_def = stats["DEF"]
	get_parent().get_node("WorldRotate/Player").texture = stats["3Dimage"]

func set_opponent_stats(battler_id):
	var stats = get_battler_info(battler_id)
	$OpponentStats/Name.text = stats["name"]
	$OpponentStats/Type.text = "TYPE " + stats["type"]
	$OpponentStats/HP.text = "HP: " + String(stats["HP"]) + " / " + String(stats["HP"])
	$OpponentStats/POW.text = "POW: " + String(stats["POW"])
	$OpponentStats/DEF.text = "DEF: " + String(stats["DEF"])
	opponent_max_hp = stats["HP"]
	opponent_hp = stats["HP"]
	opponent_pow = stats["POW"]
	opponent_def = stats["DEF"]
	get_parent().get_node("WorldRotate/Opponent").texture = stats["3Dimage"]

func resolve_actions(opponent_actions):
	var player_action = get_card_info(int(action_id))
	var opponent_action = get_card_info( int(opponent_actions.substr(opponent_actions.length()-2,2)) )

	player_energy -= player_action["cost"]
	opponent_energy -= opponent_action["cost"]
	
	var player_atk = player_pow * player_action["attack"]
	var player_block = player_def * player_action["defense"]
	
	var opponent_atk = opponent_pow * opponent_action["attack"]
	var opponent_block = opponent_def * opponent_action["defense"]
	
	if opponent_action["type"] == "power":
		player_atk = player_pow * (player_action["attack"] + player_action["counter_bonus"])
		player_block = 0
	if player_action["type"] == "power":
		opponent_atk = opponent_pow * (opponent_action["attack"] + opponent_action["counter_bonus"])
		opponent_block = 0
	
	var player_damage_dealt = int(clamp(player_atk - opponent_block, 10, 10000))
	var opponent_damage_dealt = int(clamp(opponent_atk - player_block, 10, 10000))
	
	opponent_hp = int(clamp(opponent_hp - player_damage_dealt, 0, 10000))
	player_hp = int(clamp(player_hp - opponent_damage_dealt, 0, 10000))
	player_energy += 1 + player_action["gain"]
	opponent_energy += 1 + opponent_action["gain"]
	
	$PlayerStats/HP.text = "HP: " + String(player_hp) + " / " + String(player_max_hp)
	$OpponentStats/HP.text = "HP: " + String(opponent_hp) + " / " + String(opponent_max_hp)
	$PlayerStats/EnergySquare/Energy.text = "Energy\n" + String(player_energy)
	$OpponentStats/EnergySquare/Energy.text = "Energy\n" + String(opponent_energy)
	
	if opponent_hp == 0:
		declare_victory()
		$Scroll/AwaitingOpponent.text = "VICTORY!						VICTORY!						VICTORY!						VICTORY!						"
		$Overlay.visible = true
		fade_in_ending = true
	else:
		$Scroll/AwaitingOpponent.text = "CHOOSE ACTION...						CHOOSE ACTION...						CHOOSE ACTION...						CHOOSE ACTION...						"
		for card in $Cards.get_children():
			card.activated = true
	
func end_game():
	ethers.fade("return_to_world")

#add the correct cost/gain/counter values
func get_card_info(card_id):
	match card_id:
		10: return {"id": "10", "type": "normal", "name": "Laser", "attack": 1, "defense": 0, "cost": 0, "gain": 0, "counter_bonus": 2}
		11: return {"id": "11", "type": "normal", "name": "Energy Wave", "attack": 1, "defense": 0, "cost": 0, "gain": 1, "counter_bonus": 0}
		12: return {"id": "12", "type": "normal", "name": "Pulsar", "attack": 1, "defense": 0, "cost": 1, "gain": 0, "counter_bonus": 5}
		13: return {"id": "13", "type": "normal", "name": "Bonk", "attack": 1, "defense": 0, "cost": 0, "gain": 0, "counter_bonus": 2}
		14: return {"id": "14", "type": "normal", "name": "Irradiate", "attack": 1, "defense": 0, "cost": 0, "gain": 1, "counter_bonus": 0}
		15: return {"id": "15", "type": "normal", "name": "Cold Glow", "attack": 0, "defense": 1, "cost": 0, "gain": 1, "counter_bonus": 0}
		16: return {"id": "16", "type": "normal", "name": "Ice Barrier", "attack": 0, "defense": 1, "cost": 0, "gain": 1, "counter_bonus": 0}
		17: return {"id": "17", "type": "normal", "name": "Sun Guard", "attack": 1, "defense": 1, "cost": 1, "gain": 0, "counter_bonus": 2}
		18: return {"id": "18", "type": "normal", "name": "Crunch", "attack": 2, "defense": 0, "cost": 1, "gain": 0, "counter_bonus": 4}
		19: return {"id": "19", "type": "normal", "name": "Rainbow Shroud", "attack": 1, "defense": 2, "cost": 2, "gain": 1, "counter_bonus": 1}
		20: return {"id": "20", "type": "normal", "name": "Aurora", "attack": 1, "defense": 2, "cost": 1, "gain": 0, "counter_bonus": 0}
		21: return {"id": "21", "type": "power", "name": "Power Beam", "attack": 1, "defense": 0, "cost": 2, "gain": 0, "counter_bonus": 2}
		22: return {"id": "22", "type": "power", "name": "Rust", "attack": 1, "defense": 1, "cost": 2, "gain": 0, "counter_bonus": 0}
		23: return {"id": "23", "type": "power", "name": "Crystallize", "attack": 1, "defense": 1, "cost": 2, "gain": 0, "counter_bonus": 0}
		24: return {"id": "24", "type": "power", "name": "Disrupt", "attack": 1, "defense": 0, "cost": 2, "gain": 0, "counter_bonus": 5}
		25: return {"id": "25", "type": "power", "name": "Explosion", "attack": 2, "defense": 0, "cost": 3, "gain": 0, "counter_bonus": 0}
		26: return {"id": "26", "type": "power", "name": "Crystal Laser", "attack": 1, "defense": 1, "cost": 2, "gain": 0, "counter_bonus": 0}
		27: return {"id": "27", "type": "power", "name": "Distintegrate", "attack": 2, "defense": 0, "cost": 3, "gain": 0, "counter_bonus": 0}
		28: return {"id": "28", "type": "power", "name": "Void Shield", "attack": 1, "defense": 2, "cost": 3, "gain": 0, "counter_bonus": 2}
		29: return {"id": "29", "type": "power", "name": "Seeker Missile", "attack": 2, "defense": 0, "cost": 3, "gain": 0, "counter_bonus": 3}
		30: return {"id": "30", "type": "energy", "name": "Energy Charge", "attack": 0, "defense": 0, "cost": 0, "gain": 3, "counter_bonus": 0}
		99: return {"id": "99", "type": "normal", "name": "Attack", "attack": 1, "defense": 0, "cost": 0, "gain": 0, "counter_bonus": 0}
		
func get_battler_info(battler_id):
	match battler_id:
		1: return {"id":"1", "type":"CRYSTAL", "name":"LINK-chan", "HP": 100, "POW": 40, "DEF": 40, "image": load("res://linkchan.png"), "3Dimage": load("res://linkchan3D.png")}
		2: return {"id":"2", "type":"CONSTRUCT", "name":"AVAX-chan", "HP": 200, "POW": 20, "DEF": 20, "image": load("res://avaxchan.png"), "3Dimage": load('res://avaxchan3D.png')}
		
