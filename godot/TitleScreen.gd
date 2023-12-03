extends Spatial

var user_address
var user_balance = "0"
var user_LINK_balance = "0"

var sepolia_id = 11155111

var fuji_id = 43113

var sepolia_rpc = "https://ethereum-sepolia.publicnode.com"

var my_rpc = "http://127.0.0.1:9650/ext/bc/C/rpc"
var my_header = "Content-Type: application/json"

var rpc_list



#FUJI
var time_crystal_contract = "0xb4AeBf6624F5E8D0453C545cdF9eA2D607eEb0C2"
var chainlink_contract = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"

#SEPOLIA
#var time_crystal_contract = "0x6305A40371d5371fE181A9138b05873C002d98d5"
#var chainlink_contract = "0x779877A7B0D9E8603169DdbD7836e478b4624789"

var signed_data = ""

var tx_count 
var gas_price
var confirmation_timer = 0
var tx_ongoing = false
var tx_function_name = ""
var tx_parameter = ["None"]

var menu_open = false
var left_title = false
var exiting = false
#placeholder
var main_screen = load("res://MainScreen.tscn")
var game_world = load("res://World.tscn")
var card_game = load("res://1v1Board.tscn")
#var card_game = load("res://3DBoard.tscn")
#var card_game = load("res://CardGame.tscn")

var main_hub
var game_board

var destination

func _ready():
	$PlayButton.connect("pressed", self, "attempt_play")
	$OptionsButton.connect("pressed", self, "open_options_menu") 
	$GasButton.connect("pressed", self, "open_gas_menu") 
	$LINKButton.connect("pressed", self, "open_link_menu")
	$MenuBackground/GasFaucetButton.connect("pressed", self, "open_faucet")
	$MenuBackground/LINKFaucetButton.connect("pressed", self, "open_chainlink_faucet")
	$MenuBackground/CopyAddressButton.connect("pressed", self, "copy_address")
	$MenuBackground/CancelButton.connect("pressed", self, "close_menu")
	$PlayWarning/Proceed.connect("pressed", self, "fade", ["start_game"])
	$PlayWarning/GoBack.connect("pressed", self, "close_menu")
	$OptionsMenu/Default.connect("pressed", self, "default_rpc")
	$OptionsMenu/Save.connect("pressed", self, "set_rpc")
	$OptionsMenu/Close.connect("pressed", self, "close_menu")
	check_keystore()
	check_aes_key()
	#apparently breaks the game if an invalid rpc is input
	get_rpc()  
	get_address()
	get_balance()

var fadeout = false
var fadepause = 0
var fadein = false

var check_cards_switch = false
var check_cards_timer = 0
var pending_action
func _process(delta):
	if fadeout == true:
		$Fadeout.color.a += delta
		if $Fadeout.color.a >= 1:
			fadeout = false
			fadepause = 0.1
	if fadepause > 0:
		fadepause -= delta
		if fadepause <= 0:
			fadepause = 0
			call(pending_action)
	if fadein == true:
		$Fadeout.color.a -= delta
		if $Fadeout.color.a <= 0:
			exiting = false
			fadein = false
	
	
	if confirmation_timer > 0:
		confirmation_timer -= delta
		if confirmation_timer < 0:
			tx_ongoing = false
			
			check_cards_switch = true
	
	if check_cards_switch == true:
		check_cards_timer -= delta
		if check_cards_timer <= 0:
			#check_player_cards()
			#check_opponent_cards()
			check_cards_timer = 16
		
		
				
		


func check_keystore():
	var file = File.new()
	if file.file_exists("user://keystore") != true:
		var bytekey = Crypto.new()
		var content = bytekey.generate_random_bytes(32)
		file.open("user://keystore", File.WRITE)
		file.store_buffer(content)
		file.close()

func get_address():
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	user_address = TimeCrystal.get_address(content)
	$MenuBackground/Address.text = user_address
	file.close()
	
func check_aes_key():
	var file = File.new()
	if file.file_exists("user://aes") != true:
		var bytekey = Crypto.new()
		var content = bytekey.generate_random_bytes(16)
		file.open("user://aes", File.WRITE)
		file.store_buffer(content)
		file.close()
	
func get_rpc():
	var file = File.new()
	if file.file_exists("user://rpc") != true:
		var initial_rpc_list = {"1": "https://ethereum-sepolia.publicnode.com", "2": "https://endpoints.omniatech.io/v1/eth/sepolia/public", "3": "https://1rpc.io/sepolia"}
		file.open("user://rpc", File.WRITE)
		file.store_line(JSON.print(initial_rpc_list))
	file.close()
	
	var file2 = File.new()
	file2.open("user://rpc", File.READ)
	var content = file2.get_as_text()
	rpc_list = parse_json(content).duplicate()
	sepolia_rpc = rpc_list["1"]
	$OptionsMenu/RPC1.text = rpc_list["1"]
	$OptionsMenu/RPC2.text = rpc_list["2"]
	$OptionsMenu/RPC3.text = rpc_list["3"]
	file2.close()

func default_rpc():
	$OptionsMenu/RPC1.text = "https://ethereum-sepolia.publicnode.com"
	$OptionsMenu/RPC2.text = "https://endpoints.omniatech.io/v1/eth/sepolia/public"
	$OptionsMenu/RPC3.text = "https://1rpc.io/sepolia"
	
func set_rpc():
	var new_rpc_list = {"1": $OptionsMenu/RPC1.text, "2": $OptionsMenu/RPC2.text, "3": $OptionsMenu/RPC3.text}
	var file = File.new()
	file.open("user://rpc", File.WRITE)
	file.store_line(JSON.print(new_rpc_list))
	file.close()
	sepolia_rpc = $OptionsMenu/RPC1.text

func attempt_play():
	if menu_open == false:
		menu_open = true
		if user_LINK_balance == "0":
			$MenuOverlay.visible = true
			$PlayWarning.visible = true

func open_options_menu():
	if menu_open == false:
		menu_open = true
		$MenuOverlay.visible = true
		$OptionsMenu.visible = true
		get_rpc()

func open_gas_menu():
	if menu_open == false:
		menu_open = true
		get_balance()
		$MenuOverlay.visible = true
		$MenuBackground.visible = true
		$MenuBackground/GasBalance.visible = true
		$MenuBackground/GasURL.visible = true
		$MenuBackground/GasFaucetButton.visible = true
		$MenuBackground/LINKBalance.visible = false
		$MenuBackground/LINKURL.visible = false
		$MenuBackground/LINKFaucetButton.visible = false

func open_link_menu():
	if menu_open == false:
		menu_open = true
		$MenuOverlay.visible = true
		$MenuBackground.visible = true
		$MenuBackground/GasBalance.visible = false
		$MenuBackground/GasURL.visible = false
		$MenuBackground/GasFaucetButton.visible = false
		$MenuBackground/LINKBalance.visible = true
		$MenuBackground/LINKURL.visible = true
		$MenuBackground/LINKFaucetButton.visible = true
	
func close_menu():
	if exiting == false:
		menu_open = false
		$MenuOverlay.visible = false
		$MenuBackground.visible = false
		$PlayWarning.visible = false
		$OptionsMenu.visible = false

func copy_address():
	OS.set_clipboard(user_address)

func open_faucet():
	OS.shell_open("https://sepolia-faucet.pk910.de")

func open_chainlink_faucet():
	OS.shell_open("https://faucets.chain.link")

func fade(action, params="None"):
	if exiting == false:
		exiting = true
		pending_action = action
		if params != "None":
			destination = params
		fadeout = true



func start_game():
	for child in get_children():
		if child != $Fadeout && child != $HTTP:
			child.queue_free()
	var new_main = main_screen.instance()
	new_main.ethers = self
	add_child(new_main)
	move_child(new_main, 0)
	main_hub = new_main
	left_title = true
	fadein = true

func embark():
	for child in get_children():
		if child != $Fadeout && child != $HTTP:
			child.queue_free()
	var new_world = game_world.instance()
	add_child(new_world)
	move_child(new_world, 0)
	fadein = true

func teleport():
	$World/Player.global_transform.origin = Vector3(0,0,0)
	fadein = true

func return_to_world():
	$World/Player/Head/Camera.visible = true
	$World/Player/Head/Camera/RayCast/Reticle.visible = true
	$World/Player/Head/Camera.make_current()
	$World/DirectionalLight.visible = true
	$World/Player.menu_open = false
	$World/Player.not_options = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_board.queue_free()
	fadein = true

var console
func enter_matchmaking_queue():
	var new_game = card_game.instance()
	add_child(new_game)
	var children_length = get_children().size()
	move_child(new_game, children_length - 2)
	new_game.global_transform.origin.x += 1000
	#game_board = new_game
	#new_game.ethers = self
	game_board = new_game.get_node("UI")
	new_game.get_node("UI").ethers = self
	
	
	# Disabled for now, turn back on later
	#game_board.register_player()
	game_board.join_matchmaking()
	
	
	game_board.get_parent().get_node("WorldRotate/Pivot/BattleCamera").make_current()
	$World/Player/Head/Camera.visible = false
	$World/Player/Head/Camera/RayCast/Reticle.visible = false
	$World/DirectionalLight.visible = false
	fadein = true
	console.close()
	
	
	
func start_transaction(function_name, param=["None"]):
	if tx_ongoing == false:
		tx_function_name = function_name
		tx_parameter = param
		#tx_ongoing = true
		get_tx_count()
	else:
		print("Transaction Ongoing")

# # #    BLOCKCHAIN INTERACTION    # # # 

var http_request_delete_balance
var http_request_delete_tx_read
var http_request_delete_tx_write
var http_request_delete_gas
var http_request_delete_count

func get_balance():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_balance = http_request
	http_request.connect("request_completed", self, "get_balance_attempted")
	
	if left_title == false:
		$MenuBackground/GasBalance.text = "Refreshing..."
	
	var tx = {"jsonrpc": "2.0", "method": "eth_getBalance", "params": [user_address, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))
	

func get_balance_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())
	
	if response_code == 200:
		var balance = String(get_result["result"].hex_to_int())
		user_balance = balance
		if left_title == false:
			$MenuBackground/GasBalance.text = "Your gas balance:\n" + balance
	else:
		if left_title == false:
			$MenuBackground/GasBalance.text = "CHECK RPC"
	http_request_delete_balance.queue_free()
	

func get_tx_count():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_count = http_request
	http_request.connect("request_completed", self, "get_tx_count_attempted")
	
	var tx = {"jsonrpc": "2.0", "method": "eth_getTransactionCount", "params": [user_address, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))
	

func get_tx_count_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())
	
	if response_code == 200:
		#$Send.text = "Confirming..."
		var count = get_result["result"].hex_to_int()
		tx_count = count
	else:
		pass
		#$MenuBackground/GasBalance.text = "CHECK RPC"
	http_request_delete_count.queue_free()
	estimate_gas()


func estimate_gas():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_gas = http_request
	http_request.connect("request_completed", self, "estimate_gas_attempted")
	
	var tx = {"jsonrpc": "2.0", "method": "eth_gasPrice", "params": [], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))
	

func estimate_gas_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())
	
	if response_code == 200:
		var estimate = get_result["result"].hex_to_int()
		gas_price = int(float(estimate) * 1.12)
	else:
		pass
		#$MenuBackground/GasBalance.text = "CHECK RPC"
	http_request_delete_gas.queue_free()
	call(tx_function_name)
	

func crystal_staked():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_crystal_staked_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.crystal_staked(content, fuji_id, time_crystal_contract, my_rpc, user_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_crystal_staked_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var _crystal_id = TimeCrystal.decode_u256(raw_response)
		main_hub.crystal_id = _crystal_id
		if _crystal_id != "0":
			token_uri(_crystal_id)

func token_uri(_crystal_id):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_token_uri_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.token_uri(content, fuji_id, time_crystal_contract, my_rpc, int(_crystal_id))
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_token_uri_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var _crystal_info = TimeCrystal.decode_hex_string(raw_response)
		main_hub.crystal_info = _crystal_info
		main_hub.update_crystal()




func register_player():
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	file.close()
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.register_player_key(content, fuji_id, time_crystal_contract, my_rpc, gas_price, tx_count, aes_key, chainlink_contract, self)
	
	
func join_matchmaking():
	var password = tx_parameter[0]
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	file.close()
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.get_hand(content, fuji_id, time_crystal_contract, my_rpc, gas_price, tx_count, aes_key, password, self)

func commit_action():
	var secret = tx_parameter[0]
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	TimeCrystal.commit_action(content, fuji_id, time_crystal_contract, my_rpc, gas_price, tx_count, secret, self)
	game_board.get_node("Scroll/AwaitingOpponent").text = "RESOLVING...						RESOLVING...						RESOLVING...						RESOLVING...						"

func reveal_action():
	var password = tx_parameter[0]
	var action = tx_parameter[1]
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	TimeCrystal.reveal_action(content, fuji_id, time_crystal_contract, my_rpc, gas_price, tx_count, password, action, self)

func declare_victory():
	var password_cards = tx_parameter[0]
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	TimeCrystal.declare_victory(content, fuji_id, time_crystal_contract, my_rpc, gas_price, tx_count, password_cards, self)

func check_player_cards():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_player_cards_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.get_player_cards(content, fuji_id, time_crystal_contract, my_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_player_cards_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())
	print(get_result)
	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var target_hash = TimeCrystal.decode_bytes(raw_response).substr(8).trim_suffix(")")
		print(target_hash)
		if target_hash.length() > 3:
			game_board.get_hash_monster()
			game_board.get_node("TargetHash").text = "Target Hash:\n" + target_hash
			game_board.target_hash = target_hash
			game_board.extract_hand()
			game_board.find_player_hand = false
			game_board.get_node("Scroll/AwaitingOracle").visible = false
		#game_board.get_node("YourHand").text = "Your Hand:\n" + TimeCrystal.decode_u256_array_from_bytes(raw_response)
		#print(parse_json(TimeCrystal.decode_hex_string(raw_response)["1"]))

func check_commit(_address):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_commit_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.check_commit(content, fuji_id, time_crystal_contract, my_rpc, _address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_commit_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var commit_status = TimeCrystal.decode_bool(raw_response)
		
		# Commit Phase
		if commit_status == "true" && game_board.in_commit_phase == true:
			# Detect player commit 
			if game_board.player_commit_found == false:
				game_board.player_commit_found = true
				check_commit(game_board.opponent)
			else:
				# Then, detect opponent commit
				game_board.in_commit_phase = false
				game_board.player_commit_found = false
				game_board.in_reveal_phase = true
				game_board.reveal_action()
		
		# Reveal Phase
		if commit_status == "false" && game_board.in_reveal_phase == true:
			# Detect player reveal
			if game_board.player_commit_found == false:
				game_board.player_commit_found = true
				check_commit(game_board.opponent)
			else:
				# Then, detect opponent reveal and resolve actions
				print("resolving reveal phase")
				game_board.player_commit_found = false
				game_board.in_reveal_phase = false
				game_board.get_opponent_actions()
			
#		if commit_status == "true" && game_board.in_commit_phase == true:
#			print("entering reveal phase")
#			game_board.in_commit_phase = false
#			game_board.in_reveal_phase = true
#			game_board.reveal_action()
#
#		if commit_status == "false" && game_board.in_reveal_phase == true:
#			print("resolving reveal phase")
#			game_board.in_reveal_phase = false
#			game_board.get_opponent_actions()
			
		game_board.get_node("OpponentCommit").text = "Opponent Commit?\n" + TimeCrystal.decode_bool(raw_response)


func get_opponent_actions(opponent_address):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_opponent_actions_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.see_actions(content, fuji_id, time_crystal_contract, my_rpc, opponent_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_opponent_actions_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var opponent_actions = TimeCrystal.decode_hex_string(raw_response)
		game_board.get_node("OpponentCard").text = "Opponent Played:\n" + TimeCrystal.decode_hex_string(raw_response)
		game_board.resolve_actions(opponent_actions)


func get_player_actions():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_player_actions_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.see_actions(content, fuji_id, time_crystal_contract, my_rpc, user_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_player_actions_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var player_actions = TimeCrystal.decode_hex_string(raw_response)
		
func get_opponent():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_opponent_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.get_opponent(content, fuji_id, time_crystal_contract, my_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_opponent_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		print(raw_response)
		var opponent_address = TimeCrystal.decode_address(raw_response)
		game_board.opponent = opponent_address
		print(opponent_address)
		get_opponent_hash_monster(opponent_address)
	

func get_opponent_hash_monster(opponent_address):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_opponent_hash_monster_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.get_hash_monster(content, fuji_id, time_crystal_contract, my_rpc, opponent_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_opponent_hash_monster_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var filter = int(TimeCrystal.decode_u256(raw_response))
		var selector
		if filter <= 4:
			selector = 2
		else:
			selector = 1
		game_board.set_opponent_stats(selector)
		game_board.get_node("OpponentHashMonster").text = game_board.get_battler_info(selector)["name"]
		game_board.find_opponent = false
		game_board.battle_start_sequence = true


func get_player_hash_monster():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "get_player_hash_monster_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.get_hash_monster(content, fuji_id, time_crystal_contract, my_rpc, user_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func get_player_hash_monster_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var filter = int(TimeCrystal.decode_u256(raw_response))
		var selector
		if filter <= 4:
			selector = 2
		else:
			selector = 1
		game_board.set_player_stats(selector)
		game_board.get_node("Blue/Battler").texture = game_board.get_battler_info(selector)["image"]
		game_board.get_node("PlayerHashMonster").text = game_board.get_battler_info(selector)["name"]
		game_board.battler_fade_in = true


func check_won():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_won_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.test_win(content, fuji_id, time_crystal_contract, my_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_won_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		game_board.get_node("TestWon").text = TimeCrystal.decode_address(raw_response)

func has_seeds_remaining():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "has_seeds_remaining_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.has_seeds_remaining(content, fuji_id, time_crystal_contract, my_rpc, user_address)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func has_seeds_remaining_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var has_seeds = TimeCrystal.decode_bool(raw_response)
		if has_seeds == "true":
			main_hub.finish_registering()
		else:
			main_hub.get_node("EmbarkMenu/RegistrationConfirm").visible = true
			
			


# Called from Rust
func set_signed_data(var signature):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_write = http_request
	http_request.connect("request_completed", self, "send_transaction_attempted")
	
	var signed_data = "".join(["0x", signature])
	
	var tx = {"jsonrpc": "2.0", "method": "eth_sendRawTransaction", "params": [signed_data], "id": 7}
	print(signed_data)
	var error = http_request.request(my_rpc, 
	[my_header], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))


func send_transaction_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	print(get_result)

	if response_code == 200:
		pass
		#tx_ongoing = true
		#confirmation_timer = 7
	else:
		pass
		#$Send.text = "TX ERROR"
	
	http_request_delete_tx_write.queue_free()





#       BUTTON SELECTOR POSITIONS       #

func _on_PlayButton_mouse_entered():
	$SelectorIndicator/LeftControl.rect_position = Vector2(24,295)
	$SelectorIndicator/RightControl.rect_position = Vector2(167,295)


func _on_OptionsButton_mouse_entered():
	$SelectorIndicator/LeftControl.rect_position = Vector2(24,382)
	$SelectorIndicator/RightControl.rect_position = Vector2(238,382)


func _on_GasButton_mouse_entered():
	$SelectorIndicator/LeftControl.rect_position = Vector2(24,469)
	$SelectorIndicator/RightControl.rect_position = Vector2(238,469)


func _on_LINKButton_mouse_entered():
	$SelectorIndicator/LeftControl.rect_position = Vector2(24,554)
	$SelectorIndicator/RightControl.rect_position = Vector2(254,554)
