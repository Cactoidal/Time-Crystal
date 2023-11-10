extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


var grow_time = 0
var blow_up = true
var ramp_speed = 0.005
var grow = 0
func _process(delta):
	rotate_y(ramp_speed)
	if blow_up == true:
		ramp_speed += 0.00005
		grow += 0.0012
		get_active_material(0).set_shader_param("grow",grow)
		#get_active_material(0).params_grow_amount += 0.001
		grow_time += delta
		if grow_time > 3:
			blow_up = false
	else:
		grow -= 0.0012
		get_active_material(0).set_shader_param("grow",grow)
		#get_active_material(0).params_grow_amount -= 0.001
		grow_time -= delta
		ramp_speed -= 0.00005
		if grow_time < 0:
			blow_up = true		
