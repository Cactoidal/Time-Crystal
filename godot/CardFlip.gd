extends Control


var card_info
var card_destination
var ui_card

#refers to game board
var ethers


#func _ready():
#	card_destination = get_parent().get_node("Spot1")
#	ui_card = get_parent().get_parent().get_parent().get_node("UI/Card1")

func _ready():
	$TextureRect/Viewport/Card/Back/Viewport/Name.text = card_info["name"]
	$TextureRect/Viewport/Card/Back/Viewport/Energy.text = String(card_info["cost"])
	$TextureRect/Viewport/Card/Back/Viewport/ATKDEF.text = "ATK" + String(card_info["attack"]) + " | DEF" + String(card_info["defense"])
	if card_info["type"] == "power":
		$TextureRect/Viewport/Card/Back/Viewport/Extra.text = "IGNORE DEF"
		$TextureRect/Viewport/Card/Back/Viewport/TextureRect.texture = load("res://power_card.png")
	elif card_info["gain"] > 0:
		$TextureRect/Viewport/Card/Back/Viewport/Extra.text = "ENERGY +" + String(card_info["gain"])
	elif card_info["counter_bonus"] > 0:
		$TextureRect/Viewport/Card/Back/Viewport/Extra.text = "COUNTER x" + String(card_info["counter_bonus"])
	rect_position = Vector2(500,300)
	$Tween.interpolate_property(self, "rect_position", self.rect_position, card_destination, 4.2, Tween.TRANS_QUAD, Tween.EASE_OUT, 0)
	$Tween.start()
	

var test_time = 5
func _process(delta):
	if $TextureRect.modulate.a < 1:
		$TextureRect.modulate.a += delta
		
	if $TextureRect/Viewport/Card.rotation.y < 3.13:
		$TextureRect/Viewport/Card.rotate_y(0.01)
	
	if activated == true:
		$TextureRect/Viewport/Card/Back/Viewport/Overlay.visible = false
	else:
		$TextureRect/Viewport/Card/Back/Viewport/Overlay.visible = true
	
	if test_time > 0:
		test_time -= delta
		if test_time <= 0:
			#ui_card.visible = true
			#queue_free()
			return



var activated = false
func _on_TextureButton_pressed():	
	if activated == true:
		$TextureRect/Confirm.visible = true
		for card in get_parent().get_children():
			if card != self:
				card._on_Cancel_pressed()


func _on_Confirm_pressed():
	$TextureRect/Confirm.visible = false
	for card in get_parent().get_children():
		card.activated = false
	ethers.commit_action(card_info["id"])


func _on_Cancel_pressed():
	$TextureRect/Confirm.visible = false

func glow(energy):
	if energy >= card_info["cost"]:
		activated = true
	else:
		activated = false


func _on_Confirm_mouse_entered():
	$TextureRect/Confirm/Green/Overlay.visible = false

func _on_Confirm_mouse_exited():
	$TextureRect/Confirm/Green/Overlay.visible = true

func _on_Cancel_mouse_entered():
	$TextureRect/Confirm/Red/Overlay.visible = false

func _on_Cancel_mouse_exited():
	$TextureRect/Confirm/Red/Overlay.visible = true
