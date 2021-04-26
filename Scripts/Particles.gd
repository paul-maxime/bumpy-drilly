extends CPUParticles2D

var life: float = 0

func _process(delta):
	life += delta
	if life > lifetime * 3:
		queue_free()
