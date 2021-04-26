extends Node2D

const SPEED = 25.0

var lifespan: float = 1.5
var remaining_lifespan: float

var sounds: Dictionary = {
	"upgrade": preload("res://Sounds/Upgrade.wav"),
	"ore": preload("res://Sounds/Ore.wav"),
}

func _ready():
	remaining_lifespan = lifespan

func _process(delta: float):
	remaining_lifespan -= delta
	if remaining_lifespan <= 0:
		queue_free()
		return
	modulate.a = remaining_lifespan / lifespan
	position.y -= delta * SPEED

func set_text(text: String):
	get_node("Label").text = text

func set_sound(type: String):
	if sounds.has(type):
		get_node("AudioStreamPlayer").stream = sounds[type]
	else:
		get_node("AudioStreamPlayer").stream = null
