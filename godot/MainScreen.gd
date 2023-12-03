extends Control

var ethers
var crystal_id = 0
var crystal_info
var seeds_remaining = 0

var pending_destination
var exiting = false

func _ready():
	$Buttons/EmbarkButton.connect("pressed", self, "open_embark_menu")
	$EmbarkMenu/Return.connect("pressed", self, "close_embark_menu")
	$EmbarkMenu/CavesButton.connect("pressed", self, "open_confirm_embark", ["Caves"])
	$EmbarkMenu/CraterButton.connect("pressed", self, "open_confirm_embark", ["Crater"])
	$EmbarkMenu/PrecipiceButton.connect("pressed", self, "open_confirm_embark", ["Precipice"])
	$EmbarkMenu/ConfirmEmbark/Confirm.connect("pressed", self, "confirm_embark")
	$EmbarkMenu/ConfirmEmbark/Cancel.connect("pressed", self, "close_confirm_embark")
	$EmbarkMenu/RegistrationConfirm/Register.connect("pressed", self, "register")
	
	$MintCrystal/Register.connect("pressed", self, "mint")	
	check_for_crystal()

var refresh_timer = 0
var registered = false
var mint_timer = 0
func _process(delta):
	if refresh_timer > 0:
		refresh_timer -= delta
		if refresh_timer < 0:
			if registered == false:
				get_parent().has_seeds_remaining()
				refresh_timer = 10
			else:
				refresh_timer = 0
		
	if mint_timer > 0:
		mint_timer -= delta
		if mint_timer < 0:
			if registered == false:
				check_for_crystal()
				mint_timer = 10
			else:
				mint_timer = 0

			
func check_for_crystal():
	#temp skipped for now
	#ethers.crystal_staked()
	ethers.token_uri(1)

func update_crystal():
	registered = true
	var info = parse_json(crystal_info)
	$MintCrystal.visible = false
	$Buttons/NFTFrame/NFTBackground/Info.visible = true
	$Buttons/NFTFrame/NFTBackground/Info/CrystalID.text = info["name"]
	$Buttons/NFTFrame/NFTBackground/Info/Stats.text = "SEEDS: " + String(info["traits"][0]["value"]) + "\n\nENERGY: " + String(info["traits"][2]["value"]) + "\n\nEXP: " + String(info["traits"][1]["value"]) + "\n\nDECK: Standard"
	seeds_remaining = int(info["traits"][0]["value"])

func open_embark_menu():
	if registered == true:
		$EmbarkMenu.visible = true
		if seeds_remaining == 0:
			$EmbarkMenu/RegistrationConfirm.visible = true
		else:
			$EmbarkMenu/RegistrationConfirm.visible = false
			finish_registering()

func close_embark_menu():
	$EmbarkMenu.visible = false
	$EmbarkMenu/RegistrationConfirm.visible = false

func open_confirm_embark(destination):
	$Buttons.confirm = true
	$EmbarkMenu/Overlay.visible = true
	$EmbarkMenu/ConfirmEmbark.visible = true
	get_node("EmbarkMenu/" + destination + "Name").visible = true
	pending_destination = destination
	var nametext
	match destination:
		"Caves": nametext = "Snowfall Arena"
		"Crater": nametext = "Crystal Crater"
		"Precipice": nametext = "Pinnacle Arena"
	$EmbarkMenu/ConfirmEmbark/Question.text = "Travel to " + nametext + "?"

func register():
	$EmbarkMenu/RegistrationConfirm/Prompt.visible = false
	$EmbarkMenu/RegistrationConfirm/Register.visible = false
	$EmbarkMenu/RegistrationConfirm/Registering.visible = true
	$EmbarkMenu/Overlay.visible = true
	refresh_timer = 30
	get_parent().start_transaction("register_player")

func finish_registering():
	registered = true
	$EmbarkMenu/RegistrationConfirm/Prompt.visible = true
	$EmbarkMenu/RegistrationConfirm/Register.visible = true
	$EmbarkMenu/RegistrationConfirm/Registering.visible = false
	$EmbarkMenu/RegistrationConfirm.visible = false
	$EmbarkMenu/RegistrationOverlay.visible = false
	$EmbarkMenu/Overlay.visible = false
	$Overlay.visible = false
	update_crystal()

# * #
func mint():
	$Overlay.visible = true
	$MintCrystal/Prompt.visible = false
	$MintCrystal/Register.visible = false
	$MintCrystal/Registering.visible = true
	mint_timer = 30
	get_parent().start_transaction("register_player")
	

func confirm_embark():
	if exiting == false:
		exiting = true
		get_parent().fade("embark", pending_destination)

func close_confirm_embark():
	if exiting == false:
		$Buttons.confirm = false
		$Buttons.call("_on_" + pending_destination + "Button_mouse_exited")
		get_node("EmbarkMenu/" + pending_destination + "Name").visible = false
		$EmbarkMenu/Overlay.visible = false
		$EmbarkMenu/ConfirmEmbark.visible = false

