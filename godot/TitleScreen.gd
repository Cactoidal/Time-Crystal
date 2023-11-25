extends Spatial

var user_address
var user_balance = "0"
var user_LINK_balance = "0"

var sepolia_id = 11155111

var sepolia_rpc = "https://ethereum-sepolia.publicnode.com"

var rpc_list

var time_crystal_contract = "0xaE1C069Ea6AeAEc457DdA7052677c962607eb80F"

var chainlink_contract = "0x779877A7B0D9E8603169DdbD7836e478b4624789"

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
var card_game = load("res://3DBoard.tscn")
#var card_game = load("res://CardGame.tscn")

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
			fadepause = 1
	if fadepause > 0:
		fadepause -= delta
		if fadepause >= 0:
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
	add_child(new_main)
	move_child(new_main, 0)
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

var console
func start_card_game():
	var new_game = card_game.instance()
	add_child(new_game)
	var children_length = get_children().size()
	move_child(new_game, children_length - 2)
	new_game.global_transform.origin.x += 1000
	#game_board = new_game
	#new_game.ethers = self
	game_board = new_game.get_node("UI")
	new_game.get_node("UI").ethers = self
	$World/Player/Head/Camera.queue_free()
	$World/DirectionalLight.queue_free()
	fadein = true
	console.close()
	
	
func start_transaction(function_name, param=["None"]):
	if tx_ongoing == false:
		tx_function_name = function_name
		tx_parameter = param
		tx_ongoing = true
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
	
	var error = http_request.request(sepolia_rpc, 
	[], 
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
	
	var error = http_request.request(sepolia_rpc, 
	[], 
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
	
	var error = http_request.request(sepolia_rpc, 
	[], 
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




func register_player():
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	file.close()
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.register_player_key(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, aes_key, chainlink_contract, self)
	
	
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
	TimeCrystal.get_hand(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, aes_key, password, self)

func make_move():
	var card = tx_parameter[0]
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	TimeCrystal.make_move(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, card, self)

func declare_victory():
	var password_cards = tx_parameter[0]
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	TimeCrystal.declare_victory(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, password_cards, self)

func create_player_deck():
	var deck = tx_parameter[0]
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	file.close()
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.create_player_deck(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, deck, self)


func check_player_cards():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_player_cards_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.get_player_cards(content, sepolia_id, time_crystal_contract, sepolia_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(sepolia_rpc, 
	[], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_player_cards_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		var target_hash = TimeCrystal.decode_bytes(raw_response).substr(8).trim_suffix(")")
		print(target_hash)
		game_board.get_node("TargetHash").text = "Target Hash:\n" + target_hash
		game_board.target_hash = target_hash
		game_board.extract_hand()
		#game_board.get_node("YourHand").text = "Your Hand:\n" + TimeCrystal.decode_u256_array_from_bytes(raw_response)
		#print(parse_json(TimeCrystal.decode_hex_string(raw_response)["1"]))

func check_opponent_cards():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_opponent_cards_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.see_opponent_board(content, sepolia_id, time_crystal_contract, sepolia_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(sepolia_rpc, 
	[], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_opponent_cards_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		game_board.get_node("OpponentCard").text = "Opponent Played:\n" + TimeCrystal.decode_u256_array(raw_response)


func check_won():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_won_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.test_win(content, sepolia_id, time_crystal_contract, sepolia_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(sepolia_rpc, 
	[], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))

func check_won_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		game_board.get_node("TestWon").text = TimeCrystal.decode_hex_string(raw_response)



# Called from Rust
func set_signed_data(var signature):
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_write = http_request
	http_request.connect("request_completed", self, "send_transaction_attempted")
	
	var signed_data = "".join(["0x", signature])
	
	var tx = {"jsonrpc": "2.0", "method": "eth_sendRawTransaction", "params": [signed_data], "id": 7}
	print(signed_data)
	var error = http_request.request(sepolia_rpc, 
	[], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))


func send_transaction_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	print(get_result)

	if response_code == 200:
		tx_ongoing = true
		confirmation_timer = 7
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
