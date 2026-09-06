class_name CameraShake
extends Camera2D

## Screen shake driven entirely off EventBus.shake_requested, so any actor can
## ask for a kick without knowing which camera is active.
##
## Requests do not queue: a stronger shake overrides a weaker one that is still
## playing, which stops a long fight from accumulating into a constant rumble.

const DECAY_CURVE := 2.0

var _strength: float = 0.0
var _duration: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	EventBus.shake_requested.connect(shake)
	set_process(false)


func shake(strength: float, duration: float) -> void:
	if strength <= _strength and _time_left > 0.0:
		return
	_strength = strength
	_duration = maxf(0.01, duration)
	_time_left = _duration
	set_process(true)


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		_strength = 0.0
		set_process(false)
		return

	var falloff: float = pow(_time_left / _duration, DECAY_CURVE)
	var amplitude: float = _strength * falloff
	offset = Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude) * 0.65)
