extends MeshInstance

var player
var activated = false

func _ready():
	$ConfirmConsole/Cancel.connect("pressed", self, "close_console")
	$ConfirmConsole/Confirm.connect("pressed", self, "confirm")


func _process(delta):
	if get_active_material(0).emission_energy > 0:
		get_active_material(0).emission_energy -= delta

func close_console():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player.menu_open = false
	player.not_options = false
	$ConfirmConsole.visible = false
	$Overlay.visible = false
	activated = false

func activate_console():
	if activated == false:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		activated = true
		player.menu_open = true
		player.not_options = true
		$Overlay.visible = true
		$ConfirmConsole.visible = true
		

func confirm():
	
	#$ConfirmConsole.visible = false
	#$Overlay.visible = false
	player.get_parent().get_parent().console = self
	player.get_parent().get_parent().fade("enter_matchmaking_queue")
	
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#player.menu_open = false
	#player.not_options = false
	#get_parent().get_parent().get_node("Door").queue_free()
	#get_parent().get_parent().get_node("Edifice").queue_free()

func close():
	$ConfirmConsole.visible = false
	$Overlay.visible = false
	
