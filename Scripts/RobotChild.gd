extends AnimatedSprite

const PLAYER_SPEED = 96.0 * 3
const BLOCK_SIZE = Vector2(96, 96)

var is_moving = false
var destination: Vector2 = Vector2(0, 0)
var previous_rotation: float
var target_rotation: float
var rotation_step: float

func _ready():
	destination = position
	target_rotation = rotation

func _process(delta):
	if not is_moving:
		return
	if position != destination:
		if destination.distance_to(position) < delta * PLAYER_SPEED:
			position = destination
			is_moving = false
		else:
			var direction = (destination - position).normalized()
			position += direction * delta * PLAYER_SPEED
	if rotation != target_rotation:
		rotation_step = min(1.0, rotation_step + delta * 3.5)
		rotation = lerp_angle(previous_rotation, target_rotation, rotation_step)

func move_to_block(pos):
	is_moving = true
	destination = pos * BLOCK_SIZE + BLOCK_SIZE / 2
	target_rotation = (position - destination).angle() + PI / 2
	previous_rotation = rotation
	rotation_step = 0.0
