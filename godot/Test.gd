extends Control


var user_address
var user_balance = "0"

var sepolia_id = 11155111

#If the RPC is down, you can find a list at https://chainlist.org/chain/11155111
var sepolia_rpc = "https://ethereum-sepolia.publicnode.com"
#var sepolia_rpc = "https://endpoints.omniatech.io/v1/eth/sepolia/public"

var time_crystal_contract = "0x4F32123A2Bae554C77966835607C6a50fe04583d"

var signed_data = ""

var tx_count 
var gas_price
var confirmation_timer = 0
var tx_ongoing = false
var tx_function_name = ""

func _ready():
	#$Encrypted.text = TimeCrystal.test_encrypt()
	$Register.connect("pressed", self, "begin_register_key")
	$Send.connect("pressed", self, "begin_send_message")
	#$Copy.connect("pressed", self, "copy_address")
	#$GetGas.connect("pressed", self, "open_faucet")
	#$GetLINK.connect("pressed", self, "open_chainlink_faucet")
	#$Refresh.connect("pressed", self, "get_balance")
	check_keystore()
	check_aes_key()
	get_address()
	get_balance()

func _process(delta):
	if confirmation_timer > 0:
		confirmation_timer -= delta
		if confirmation_timer < 0:
			tx_ongoing = false

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
	$Address.text = user_address
	file.close()

func copy_address():
	OS.set_clipboard(user_address)

func open_faucet():
	OS.shell_open("https://sepolia-faucet.pk910.de")

func open_chainlink_faucet():
	OS.shell_open("https://faucets.chain.link")


func check_aes_key():
	var file = File.new()
	if file.file_exists("user://aes") != true:
		var bytekey = Crypto.new()
		var content = bytekey.generate_random_bytes(16)
		file.open("user://aes", File.WRITE)
		file.store_buffer(content)
		file.close()


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
	
	$GasBalance.text = "Refreshing..."
	
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
		$GasBalance.text = balance
	else:
		$GasBalance.text = "CHECK RPC"
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
		$GasBalance.text = "CHECK RPC"
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
		$GasBalance.text = "CHECK RPC"
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
