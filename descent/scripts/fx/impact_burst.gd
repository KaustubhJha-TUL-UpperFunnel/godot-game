class_name ImpactBurst
extends CPUParticles2D

## One-shot particle puff. FxDirector spawns these for every hit, death, spell
## and dash; the node removes itself once the last particle dies.


func burst(color: Color, count: int, speed: float, size: float) -> void:
	self.color = color
	amount = maxi(1, count)
	initial_velocity_min = speed * 0.25
	initial_velocity_max = speed
	scale_amount_min = size * 0.6 / 32.0
	scale_amount_max = size * 1.4 / 32.0
	emitting = true
	# lifetime covers the longest-lived particle, plus a frame of slack.
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)
