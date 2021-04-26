extends Node2D

var block_scene = preload("res://Scenes/Block.tscn")
var break_particles_scene = preload("res://Scenes/BreakParticles.tscn")
var floating_text = preload("res://Scenes/FloatingText.tscn")
var robot_child_scene = preload("res://Scenes/RobotChild.tscn")

var tex_block = preload("res://Textures/Block.png")
var tex_cooper = preload("res://Textures/BlockCooper.png")
var tex_malachite = preload("res://Textures/BlockMalachite.png")
var tex_gold = preload("res://Textures/BlockGold.png")
var tex_emerald = preload("res://Textures/BlockEmerald.png")
var tex_ruby = preload("res://Textures/BlockRuby.png")
var tex_diamond = preload("res://Textures/BlockDiamond.png")
var tex_unbreakable = preload("res://Textures/Unbreakable.png")

var sound_earthquake = preload("res://Sounds/Earthquake.ogg")
var music_ending = preload("res://Sounds/dark_fantasy_studio_bad_robots.ogg")

const MAP_WIDTH: int = 100
const MAP_HEIGHT: int = 100

const PLAYER_SPEED = 96.0 * 3
const MINING_SPEED = 96.0

var map = []
var block_size: Vector2

onready var player = get_node("Robot")
onready var player_light = get_node("Robot/Light2D")
var player_destination: Vector2
var player_is_moving: bool = false
var player_is_mining: bool = false

var previous_rotation: float
var player_rotation: float
var rotation_step: float

onready var drill_sound_player = get_node("DrillSoundPlayer")

var money: int = 0
var current_upgrade: int = 0
onready var upgrade_button = get_node("CanvasLayer/UpgradeButton")

var is_escaping: bool = false
onready var robot_child = get_node("RobotChild")

var is_animating = false
var shake_time = 0
var next_shake = 0
var fadeout = 0

var tooltip_delay = 0

func _ready():
	generate_world()
	player.position = Vector2(block_size.x * (MAP_WIDTH / 2.0), block_size.y * -1) + block_size / 2.0
	robot_child.position = Vector2(block_size.x * (MAP_WIDTH / 2.0), block_size.y * MAP_HEIGHT) + block_size / 2.0
	player_destination = player.position
	player_rotation = player.rotation
	update_light()
	update_upgrade_price()
	var _ignored = upgrade_button.connect("pressed", self, "purchase_upgrade")
	player.play()

func _process(delta):
	process_keyboard_movement()
	process_mouse_movement()
	process_drilling_animation()
	process_player_movement(delta)
	process_animations(delta)

func _input(event):
	if event is InputEventKey and event.is_pressed() and event.scancode == KEY_UP and Input.is_key_pressed(KEY_M):
		money += 10000
		create_floating_text(player.get_block_position(), "Cheatcode: +$10000", "none")

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
	if player_is_mining and player.animation != "Mining":
		player.animation = "Mining"
		player.play()
	if !player_is_mining and player.animation != "Idle":
		player.animation = "Idle"
		player.play()

	if !is_escaping and !is_animating:
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
	if is_animating:
		return
	player.apply_rotation(direction.angle() - PI / 2)
	var destination = player.get_block_position() + direction
	if not is_escaping and destination.y >= MAP_HEIGHT:
		is_animating = true
		start_shake()
		get_node("MusicPlayer").stop()
	if is_escaping and destination.y < 0:
		is_animating = true
		robot_child.is_moving = false
		end_shake()
		get_node("CanvasLayer/FadeOutRectangle").visible = true
	if destination.x >= 0 and destination.y >= 0 and destination.x < MAP_WIDTH and destination.y < MAP_HEIGHT:
		var efficiency = get_efficiency_at(destination.y)
		if efficiency < 0.1:
			return
		if is_escaping:
			if is_instance_valid(map[destination.x][destination.y]):
				if tooltip_delay <= 0:
					tooltip_delay = 1.0
					create_floating_text(player.get_block_position(), "Can't mine while escaping!", "none")
				return
			robot_child.move_to_block(player.get_block_position())
		elif destination.x != player.get_block_position().x:
			robot_child.move_to_block(Vector2(destination.x, MAP_HEIGHT))
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
		var block_money = get_money_from_tex(map[pos.x][pos.y].texture)
		money += block_money
		create_floating_text(pos, "$ " + str(block_money), "ore")
	map[pos.x][pos.y].queue_free()
	map[pos.x][pos.y] = null

func create_floating_text(pos: Vector2, text: String, type: String):
	var floating_text_instance: Node2D = floating_text.instance()
	floating_text_instance.set_text(text)
	floating_text_instance.position = pos * block_size + Vector2(block_size.x, 0) / 2
	floating_text_instance.set_sound(type)
	match type:
		"upgrade":
			floating_text_instance.lifespan = 3.0
		"story":
			floating_text_instance.lifespan = 5.0
	add_child(floating_text_instance)

func generate_world():
	randomize()
	for x in range(MAP_WIDTH):
		map.append([])
		for y in range(MAP_HEIGHT):
			var block = block_scene.instance()
			block_size = block.texture.get_size()
			map[x].append(block)
			block.set_texture(get_block_type(y))
			block.position = Vector2(x, y) * block_size
			$World.add_child(block)
		var block = block_scene.instance()
		block.set_texture(tex_unbreakable)
		block.position = Vector2(x, MAP_WIDTH + 1) * block_size
		$World.add_child(block)
	for y in range(MAP_HEIGHT + 1):
		var block1 = block_scene.instance()
		block1.set_texture(tex_unbreakable)
		block1.position = Vector2(-1, y) * block_size
		$World.add_child(block1)
		var block2 = block_scene.instance()
		block2.set_texture(tex_unbreakable)
		block2.position = Vector2(MAP_HEIGHT, y) * block_size
		$World.add_child(block2)

func get_block_type(y):
	if (randi() % 100) < (y - 75) / 8:
		return tex_diamond
	if (randi() % 100) < (y - 60) / 7:
		return tex_ruby
	if (randi() % 100) < (y - 45) / 6:
		return tex_emerald
	if (randi() % 100) < (y - 30) / 5:
		return tex_gold
	if (randi() % 100) < (y - 15) / 4:
		return tex_malachite
	if (randi() % 100) < y / 3:
		return tex_cooper
	return tex_block

func get_money_from_tex(tex):
	match tex:
		tex_diamond:
			return 1000
		tex_ruby:
			return 500
		tex_emerald:
			return 250
		tex_gold:
			return 100
		tex_malachite:
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
	if money < get_upgrade_price():
		create_floating_text(player.get_block_position(), "Not enough money", "none")
		return
	money -= get_upgrade_price()
	current_upgrade += 1
	update_upgrade_price()
	update_light()
	create_floating_text(player.get_block_position(), "Mining speed increased\nVision increased", "upgrade")

func process_animations(delta):
	if tooltip_delay > 0:
		tooltip_delay -= delta
	process_camera_shake(delta)
	if is_animating:
		if not is_escaping:
			if shake_time <= 0:
				is_animating = false
				is_escaping = true
				create_floating_text(player.get_block_position(), "Escape with the child!", "story")
				$MusicPlayer.stream = music_ending
				$MusicPlayer.play()
				$CanvasLayer/UpgradeButton.visible = false
				$CanvasLayer/MoneyLabel.visible = false
				$CanvasLayer/DepthLabel.visible = false
		else:
			player.position.y -= delta * PLAYER_SPEED
			player.rotation = PI
			robot_child.position.y -= delta * PLAYER_SPEED
			robot_child.rotation = PI
			fadeout += delta / 3.0
			if fadeout > 1.0:
				var _ignored = get_tree().change_scene("res://Scenes/GameOver.tscn")
			else:
				$CanvasLayer/FadeOutRectangle.color.a = fadeout
	elif is_escaping and !is_animating and shake_time <= 0:
		next_shake -= delta
		if next_shake <= 0:
			start_shake()

func start_shake():
	shake_time = 5.0
	next_shake = randf() * 5.0 + 5.0
	drill_sound_player.volume_db = 10
	drill_sound_player.pitch_scale = 1
	drill_sound_player.stream = sound_earthquake
	drill_sound_player.play()

func end_shake():
	shake_time = 0
	$CanvasLayer/FadeOutRectangle.visible = false
	$CanvasLayer/FadeOutRectangle.color.a = 0
	player.get_node("Camera2D").set_offset(Vector2.ZERO)
	drill_sound_player.stop()

func process_camera_shake(delta):
	if shake_time > 0:
		shake_time -= delta
		if shake_time > 0:
			drill_sound_player.volume_db -= delta * 4.0
			var force_x = randf() * shake_time * 4 - shake_time * 2
			var force_y = randf() * shake_time * 4 - shake_time * 2
			$CanvasLayer/FadeOutRectangle.visible = true
			$CanvasLayer/FadeOutRectangle.color.a = shake_time / 8.0
			player.get_node("Camera2D").set_offset(Vector2(force_x, force_y))
		else:
			end_shake()
