extends RayCast



func _ready():
	pass 
	
func _process(delta):
	if is_colliding():
		$Reticle.color.a = 0.8
		if get_collider().name == "Console":
			if get_collider().get_parent().get_active_material(0).emission_energy < 1:
				get_collider().get_parent().get_active_material(0).emission_energy += delta*2
			if Input.is_action_just_pressed("3dclick"):
				get_collider().get_parent().player = get_parent().get_parent().get_parent()
				get_collider().get_parent().activate_console()
	else:
		$Reticle.color.a = 0.3
