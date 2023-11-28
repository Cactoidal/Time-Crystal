extends Control

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
	

var register_timer = 0
var registered = false
func _process(delta):
	if register_timer > 0:
		register_timer -= delta
		if register_timer < 0:
			if registered == false:
				get_parent().has_seeds_remaining()
				register_timer = 10
			else:
				register_timer = 0
		
			
		

func open_embark_menu():
	$EmbarkMenu.visible = true
	get_parent().has_seeds_remaining()

func close_embark_menu():
	$EmbarkMenu.visible = false
	$EmbarkMenu/RegistrationConfirm.visible = false

func open_confirm_embark(destination):
	$Buttons.confirm = true
	$EmbarkMenu/Overlay.visible = true
	$EmbarkMenu/ConfirmEmbark.visible = true
	get_node("EmbarkMenu/" + destination + "Name").visible = true
	pending_destination = destination
	$EmbarkMenu/ConfirmEmbark/Question.text = "Travel to " + destination + "?"

func register():
	$EmbarkMenu/RegistrationConfirm/Prompt.visible = false
	$EmbarkMenu/RegistrationConfirm/Register.visible = false
	$EmbarkMenu/RegistrationConfirm/Registering.visible = true
	$EmbarkMenu/Overlay.visible = true
	register_timer = 30
	get_parent().start_transaction("register_player")

func finish_registering():
	registered = true
	$EmbarkMenu/RegistrationConfirm/Prompt.visible = true
	$EmbarkMenu/RegistrationConfirm/Register.visible = true
	$EmbarkMenu/RegistrationConfirm/Registering.visible = false
	$EmbarkMenu/RegistrationConfirm.visible = false
	$EmbarkMenu/RegistrationOverlay.visible = false
	$EmbarkMenu/Overlay.visible = false
	

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

