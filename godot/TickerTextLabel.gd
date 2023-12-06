extends RichTextLabel

var start_scroll = false

export (float) var scroll_speed = 60

func _process(delta):
	if start_scroll:
		rect_position.x -= scroll_speed * delta
		if rect_position.x < -rect_size.x:
			rect_position.x = get_parent().get_rect().size.x
