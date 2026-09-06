class_name HitStop
extends Node

## Briefly slows time when a sword hit lands, so heavy blows read as heavy.
##
## Implemented with Engine.time_scale rather than by skipping physics frames,
## which keeps animations, tweens and particles in sync with the pause.

@export var slowed_scale: float = 0.08

var _time_left: float = 0.0


func _ready() -> void:
	# Must keep processing while time is squeezed, and while the tree is paused
	# so a mid-hit pause cannot leave the game permanently slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.hitstop_requested.connect(request)
	set_process(false)


func request(duration: float) -> void:
	_time_left = maxf(_time_left, duration)
	Engine.time_scale = slowed_scale
	set_process(true)


func _process(_delta: float) -> void:
	# Unscaled clock, otherwise the freeze would also slow its own countdown.
	_time_left -= 1.0 / maxf(1.0, Engine.get_frames_per_second())
	if _time_left <= 0.0:
		release()


func release() -> void:
	_time_left = 0.0
	Engine.time_scale = 1.0
	set_process(false)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
