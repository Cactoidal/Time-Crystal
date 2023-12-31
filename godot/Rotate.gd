extends MeshInstance

var clickable = false
var card_nodes
var info_square_overlay
var ui
var player_unit_index

var mod = 1
var card_info
var mapped_card

var targeting = false

var attacking = false

var selected = false

func _process(delta):
	rotate_y(0.01 * mod)
	if clickable == true:
		if Input.is_action_just_pressed("3dclick"):
			activate()

func set_info(card):
	card_info = card
	$Info/Name.text = card["name"] + " Crystal"
	$Info/Attack.text = "Attack: " + str(card["attack"])
	$Info/Defense.text = "Defense: " + str(card["defense"])
	$Info/Traits.text = "Traits: " + card["keywordB"]
	if card["type"] == "construct":
		$Info/Choices/Attack.visible = true
	else:
		$Info/Choices/Attack.visible = false
	if card["keywordB"] == "":
		$Info/Choices/UseAbility.visible = false
	else:
		$Info/Choices/UseAbility.visible = true
	$Info/Choices/UseAbility.text = "Use " + card["keywordB"]
	$Info/Choices/Attack.connect("pressed", self, "attack")
	$Info/Choices/UseAbility.connect("pressed", self, "use_ability")
	$Info/Choices/Cancel.connect("pressed", self, "cancel")

func attack():
	attacking = true
	ui.actions.append(self)
	ui.board_targeting_activated = false
	info_square_overlay.visible = false
	selected = false
	$Info.visible = false
	$Info/Choices.visible = false
	for image in card_nodes:
		if !image in ui.actions:
			image.get_node("Overlay").visible = false
	for action in ui.actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true
	ui.action_count += 1
	ui.get_node("Actions").text = "Actions\n" + str(ui.action_count) + "/ 4"
	ui.action_strings.append("\n" + card_info["name"] + " Attacked(0)")
	if ui.action_count == 4:
		ui.action_strings[3] += "\n\nACTIONS MAXED"
	ui.get_node("ActionsLog").text = ""
	for line in ui.action_strings:
		ui.get_node("ActionsLog").text += line
	if ui.oracle_used == true:
		ui.get_node("ActionsLog").text += "\nORACLE CALLED"
	
func use_ability():
	ui.get_node("Targeting").visible = true
	ui.get_node("Targeting").set_point_position(0, ui.get_parent().get_node("WorldRotate/Camera").unproject_position(global_transform.origin) - Vector2(100,40))
	targeting = true
	$Info.visible = false
	$Info/Choices.visible = false
	ui.seeking_target = true
	ui.active_card = card_info.duplicate()
	ui.pending_actor = self

func cancel():
	ui.board_targeting_activated = false
	info_square_overlay.visible = false
	selected = false
	$Info.visible = false
	$Info/Choices.visible = false
	for image in card_nodes:
		if !image in ui.actions:
			image.get_node("Overlay").visible = false
	for action in ui.actions:
			if !action in card_nodes:
				if action.mapped_card != null:
					action.mapped_card.get_node("Overlay").visible = true


func _on_Area_mouse_entered():
	$Info.visible = true
	if selected == false:
		$Info.rect_position = $Info.get_global_mouse_position()
		if $Info.rect_position.x > 600:
			 $Info.rect_position.x -= 200
		if $Info.rect_position.y > 280:
			$Info.rect_position.y -= 140
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	clickable = true

func _on_Area_mouse_exited():
	if selected == false || targeting == true:
		$Info.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	clickable = false

#I'll need to allow blocking as well
func activate():
	if selected == false:
		if ui.board_targeting_activated == false && $Info/Team.text == "Player":
			selected = true
			$Info.visible = true
			$Info/Choices.visible = true
			if card_info["type"] == "construct":
				if attacking == true:
					$Info/Choices/Attack.visible = false
				else:
					$Info/Choices/Attack.visible = true
			info_square_overlay.visible = true
			ui.board_targeting_activated = true
			for image in card_nodes:
				image.get_node("Overlay").visible = true
		else:
			if ui.seeking_target == true:
				ui.target = self
				ui.open_target_confirm()
	else:
		if ui.seeking_target == true:
			ui.target = self
			ui.open_target_confirm()
