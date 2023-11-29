extends Control


var card_selector
var card_destination
var ui_card

#func _ready():
#	card_destination = get_parent().get_node("Spot1")
#	ui_card = get_parent().get_parent().get_parent().get_node("UI/Card1")

func _ready():
	rect_position = Vector2(500,300)
	$Tween.interpolate_property(self, "rect_position", self.rect_position, card_destination, 4.2, Tween.TRANS_QUAD, Tween.EASE_OUT, 0)
	$Tween.start()

var test_time = 5
func _process(delta):
#	var card_location = $Card.global_transform.origin
#	var spot_location = card_destination.global_transform.origin
#	$Card.move_and_slide((spot_location - card_location) / 2, Vector3.UP)
	if $TextureRect/Viewport/Card.rotation.y < 3.13:
		$TextureRect/Viewport/Card.rotate_y(0.01)
	
	if test_time > 0:
		test_time -= delta
		if test_time <= 0:
			#ui_card.visible = true
			#queue_free()
			return
