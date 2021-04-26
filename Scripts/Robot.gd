extends AnimatedSprite

const BLOCK_SIZE = Vector2(96.0, 96.0)

var previous_rotation: float
var target_rotation: float
var rotation_step: float

func _process(delta):
	if rotation != target_rotation:
		rotation_step = min(1.0, rotation_step + delta * 3.5)
		rotation = lerp_angle(previous_rotation, target_rotation, rotation_step)

func get_block_position():
	var pos = (position - BLOCK_SIZE / 2) / BLOCK_SIZE
	return Vector2(int(round(pos.x)), int(round(pos.y)))

func distance_to_block(block):
	return block.distance_to((position - BLOCK_SIZE / 2) / BLOCK_SIZE)

func apply_rotation(new_rotation):
	if target_rotation != new_rotation:
		previous_rotation = target_rotation
		target_rotation = new_rotation
		rotation_step = 0.0
