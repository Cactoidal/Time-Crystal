extends Spatial

var user_address
var user_balance = "0"
var user_LINK_balance = "0"

var sepolia_id = 11155111

var sepolia_rpc = "https://ethereum-sepolia.publicnode.com"
#var sepolia_rpc = "https://endpoints.omniatech.io/v1/eth/sepolia/public"

var rpc_list

var time_crystal_contract = "0x6ED5B20D2159BF20D311f0bF3E850C7737C09Da2"

var signed_data = ""

var tx_count 
var gas_price
var confirmation_timer = 0
var tx_ongoing = false
var tx_function_name = ""

var menu_open = false

func _ready():
	$PlayButton.connect("pressed", self, "attempt_play")
	$OptionsButton.connect("pressed", self, "open_options_menu") 
	$GasButton.connect("pressed", self, "open_gas_menu") 
	$LINKButton.connect("pressed", self, "open_link_menu")
	$MenuBackground/GasFaucetButton.connect("pressed", self, "open_faucet")
	$MenuBackground/LINKFaucetButton.connect("pressed", self, "open_chainlink_faucet")
	$MenuBackground/CancelButton.connect("pressed", self, "close_menu")
	#$PlayWarning/Proceed.connect("pressed", self, "start_game")
	$PlayWarning/GoBack.connect("pressed", self, "close_menu")
	$OptionsMenu/Default.connect("pressed", self, "default_rpc")
	$OptionsMenu/Save.connect("pressed", self, "set_rpc")
	$OptionsMenu/Close.connect("pressed", self, "close_menu")
	check_keystore()
	check_aes_key()
	get_rpc()
	get_address()
	get_balance()
	
#func _process(delta):
#	pass


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
		$MenuBackground/GasBalance.text = "Your gas balance:\n" + balance
	else:
		$MenuBackground/GasBalance.text = "CHECK RPC"
	http_request_delete_balance.queue_free()
	
	

func begin_register_key():
	tx_function_name = "register_key"
	get_tx_count()

func begin_send_message():
	tx_function_name = "send_message"
	get_tx_count()


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
		$Send.text = "Confirming..."
		var count = get_result["result"].hex_to_int()
		tx_count = count
	else:
		$MenuBackground/GasBalance.text = "CHECK RPC"
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
		$MenuBackground/GasBalance.text = "CHECK RPC"
	http_request_delete_gas.queue_free()
	call(tx_function_name)




func register_key():
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.register_player_key(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, aes_key, self)


func send_message():
	var message = $Message.text
	var file = File.new()
	file.open("user://aes", File.READ)
	var aes_key = file.get_buffer(16)
	var file2 = File.new()
	file2.open("user://keystore", File.READ)
	var content = file2.get_buffer(32)
	file2.close()
	TimeCrystal.send_don_message(content, sepolia_id, time_crystal_contract, sepolia_rpc, gas_price, tx_count, aes_key, message, self)

func check_message():
	var http_request = HTTPRequest.new()
	$HTTP.add_child(http_request)
	http_request_delete_tx_read = http_request
	http_request.connect("request_completed", self, "check_message_attempted")
	
	var file = File.new()
	file.open("user://keystore", File.READ)
	var content = file.get_buffer(32)
	file.close()
	var calldata = TimeCrystal.check_returned_message(content, sepolia_id, time_crystal_contract, sepolia_rpc)
	
	var tx = {"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": time_crystal_contract, "input": calldata}, "latest"], "id": 7}
	
	var error = http_request.request(sepolia_rpc, 
	[], 
	true, 
	HTTPClient.METHOD_POST, 
	JSON.print(tx))


func check_message_attempted(result, response_code, headers, body):
	
	var get_result = parse_json(body.get_string_from_ascii())

	if response_code == 200:
		var raw_response = get_result.duplicate()["result"]
		$Return.text = TimeCrystal.decode_hex_string(raw_response)



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
		confirmation_timer = 8
	else:
		$Send.text = "TX ERROR"
	
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
