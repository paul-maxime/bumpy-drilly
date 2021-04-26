extends Label

func _process(_delta):
	var robot = get_node("../../Robot")
	var depth = str(round(-(robot.position.y + 48.0) / 96.0 * 10.0) / 10)
	text = "Depth: " + depth
