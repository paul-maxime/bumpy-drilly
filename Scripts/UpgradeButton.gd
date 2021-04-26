extends Button

func _input(event):
	if event is InputEventKey and event.is_pressed() and event.scancode == KEY_U:
		emit_signal("pressed")
