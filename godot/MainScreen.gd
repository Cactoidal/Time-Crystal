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
	
	
#func _process(delta):
#	pass

func open_embark_menu():
	$EmbarkMenu.visible = true

func close_embark_menu():
	$EmbarkMenu.visible = false

func open_confirm_embark(destination):
	$Buttons.confirm = true
	$EmbarkMenu/Overlay.visible = true
	$EmbarkMenu/ConfirmEmbark.visible = true
	get_node("EmbarkMenu/" + destination + "Name").visible = true
	pending_destination = destination
	$EmbarkMenu/ConfirmEmbark/Question.text = "Travel to " + destination + "?"

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

