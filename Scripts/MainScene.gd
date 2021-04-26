extends Node2D

var block_scene = preload("res://Scenes/Block.tscn")
var break_particles_scene = preload("res://Scenes/BreakParticles.tscn")

var tex_block = preload("res://Textures/Block.png")
var tex_cooper = preload("res://Textures/BlockCooper.png")
var tex_hiddenite = preload("res://Textures/BlockHiddenite.png")
var tex_gold = preload("res://Textures/BlockGold.png")
var tex_sapphire = preload("res://Textures/BlockSapphire.png")
var tex_emerald = preload("res://Textures/BlockEmerald.png")
var tex_ruby = preload("res://Textures/BlockRuby.png")

const MAP_WIDTH = 100
const MAP_HEIGHT = 100

const PLAYER_SPEED = 96.0 * 3
const MINING_SPEED = 96.0

var map = []
var block_size: Vector2

var player: AnimatedSprite
var player_light: Light2D
var player_destination: Vector2
var player_is_moving: bool = false
var player_is_mining: bool = false

var previous_rotation: float
var player_rotation: float
var rotation_step: float

var drill_sound_player
var sound_player

var money: int = 0
var current_upgrade: int = 0
var upgrade_button: Button

func _ready():
	generate_world()
	player = get_node("Robot")
	player_light = get_node("Robot/Light2D")
	drill_sound_player = get_node("DrillSoundPlayer")
	sound_player = get_node("SoundPlayer")
	upgrade_button = get_node("CanvasLayer/UpgradeButton")
	player.position = Vector2(block_size.x * (MAP_WIDTH / 2), block_size.y * -1) + block_size / 2
	player_destination = player.position
	player_rotation = player.rotation
	update_light()
	update_upgrade_price()
	upgrade_button.connect("pressed", self, "purchase_upgrade")

func _input(event):
	pass

func _process(delta):
	process_keyboard_movement()
	process_mouse_movement()
	process_drilling_animation()
	process_player_movement(delta)

func process_keyboard_movement():
	if player_is_moving:
		return
	var direction = Vector2()
	if Input.is_key_pressed(KEY_DOWN):
		direction += Vector2(0, 1)
	if Input.is_key_pressed(KEY_UP):
		direction += Vector2(0, -1)
	if Input.is_key_pressed(KEY_LEFT):
		direction += Vector2(-1, 0)
	if Input.is_key_pressed(KEY_RIGHT):
		direction += Vector2(1, 0)
	if direction.length() == 1:
		move_player(direction)

func process_mouse_movement():
	if player_is_moving or not Input.is_mouse_button_pressed(BUTTON_LEFT):
		return

	if get_node("CanvasLayer/UpgradeButton").pressed:
		return

	var viewport_size = get_viewport().size
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_delta = mouse_pos - viewport_size / 2
	
	if abs(mouse_delta.x) > abs(mouse_delta.y):
		if mouse_delta.x > 0:
			move_player(Vector2(1, 0))
		if mouse_delta.x < 0:
			move_player(Vector2(-1, 0))
	if abs(mouse_delta.x) < abs(mouse_delta.y):
		if mouse_delta.y > 0:
			move_player(Vector2(0, 1))
		if mouse_delta.y < 0:
			move_player(Vector2(0, -1))

func process_drilling_animation():
	if player_is_mining and !player.playing:
		player.play()
	if !player_is_mining and player.playing:
		player.stop()
		player.frame = 0

	if player_is_mining:
		if !drill_sound_player.is_playing():
			drill_sound_player.play()
	else:
		if drill_sound_player.is_playing():
			drill_sound_player.stop()

func process_player_movement(delta):
	if not player_is_moving:
		return
	var speed = get_mining_speed(player_destination.y) if player_is_mining else PLAYER_SPEED
	var destination = player_destination * block_size + block_size / 2
	var distance = player.position.distance_to(destination)
	if distance > speed * delta:
		var movement = destination - player.position
		movement = movement.normalized()
		player.position += movement * delta * speed
		if player_is_mining:
			break_block_step(player_destination)
	else:
		player_is_moving = false
		if player_is_mining:
			break_block_end(player_destination)
		player_is_mining = false
		player.position = destination
	update_light()

func update_light():
	var efficiency = get_efficiency_at(player.position.y / block_size.y)
	player_light.texture_scale = 3.0 * efficiency

func get_efficiency_at(y):
	return clamp(1.0 - (y - current_upgrade * 10.0) / 25.0, 0.0, 2.0)

func get_mining_speed(y):
	return get_efficiency_at(y) * MINING_SPEED

func move_player(direction: Vector2):
	player.apply_rotation(direction.angle() - PI / 2)
	var destination = player.get_block_position() + direction
	if destination.x >= 0 and destination.y >= 0 and destination.x < MAP_WIDTH and destination.y < MAP_HEIGHT:
		var efficiency = get_efficiency_at(destination.y)
		if efficiency < 0.1:
			return
		player_is_moving = true
		player_destination = destination
		break_block_start(destination)

func break_block_start(pos):
	if not is_instance_valid(map[pos.x][pos.y]):
		return

	var particles = break_particles_scene.instance()
	particles.position = pos * block_size + Vector2(block_size.x / 2, block_size.y / 3)
	particles.one_shot = true
	particles.lifetime /= get_efficiency_at(pos.y)
	add_child(particles)

	player_is_mining = true

func break_block_step(pos):
	map[pos.x][pos.y].modulate.a = player.distance_to_block(player_destination)

func break_block_end(pos):
	if map[pos.x][pos.y].texture != tex_block:
		money += get_money_from_tex(map[pos.x][pos.y].texture)
		sound_player.play()
	map[pos.x][pos.y].queue_free()
	map[pos.x][pos.y] = null

func generate_world():
	for x in range(MAP_WIDTH):
		map.append([])
		for y in range(MAP_HEIGHT):
			var block = block_scene.instance()
			block_size = block.texture.get_size()
			map[x].append(block)
			block.position = Vector2(x, y) * block_size
			block.set_texture(get_block_type(y))
			get_node("World").add_child(block)

func get_block_type(y):
	if (randi() % 100) < (y - 75) / 8:
		return tex_ruby
	if (randi() % 100) < (y - 60) / 7:
		return tex_emerald
	if (randi() % 100) < (y - 45) / 6:
		return tex_sapphire
	if (randi() % 100) < (y - 30) / 5:
		return tex_gold
	if (randi() % 100) < (y - 15) / 4:
		return tex_hiddenite
	if (randi() % 100) < y / 3:
		return tex_cooper
	return tex_block

func get_money_from_tex(tex):
	match tex:
		tex_ruby:
			return 1000
		tex_emerald:
			return 500
		tex_sapphire:
			return 200
		tex_gold:
			return 100
		tex_hiddenite:
			return 50
		tex_cooper:
			return 10
	return 0

func get_selected_block():
	var pos = get_selected_pos()
	if pos.x >= 0 and pos.y >= 0 and pos.x < MAP_WIDTH and pos.y < MAP_HEIGHT:
		return map[pos.x][pos.y]
	return null

func get_selected_pos():
	var pos = get_local_mouse_position() / block_size
	return Vector2(int(floor(pos.x)), int(floor(pos.y)))

func get_upgrade_price():
	match current_upgrade:
		0: return 30
		1: return 100
		2: return 250
		3: return 500
		4: return 1000
		5: return 2000
		6: return 5000
		7: return 8000
	return 15000

func update_upgrade_price():
	upgrade_button.text = "Upgrade: $" + str(get_upgrade_price())

func purchase_upgrade():
	if money >= get_upgrade_price():
		money -= get_upgrade_price()
		current_upgrade += 1
		update_upgrade_price()
		update_light()
