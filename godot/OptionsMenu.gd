extends Control

var player

func _ready():
	$Menu/Cancel.connect("pressed", self, "close_menu")

func close_menu():
	player.menu_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
