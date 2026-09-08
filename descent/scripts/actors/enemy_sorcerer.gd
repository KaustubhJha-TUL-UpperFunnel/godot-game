extends EnemyBase

## Shooter archetype. Holds a mid-range band, strafing sideways, and stops dead
## to telegraph before each bolt so the shot is always readable.

enum Phase { KITE, CASTING }

const TOO_CLOSE := 230.0
const TOO_FAR := 390.0
const APPROACH_SPEED_SCALE := 0.75
const STRAFE_SPEED_SCALE := 0.65
const CAST_WIND_UP := 0.5
const CAST_INTERVAL := 1.35
const BOLT_DAMAGE_SCALE := 0.85

var _phase: Phase = Phase.KITE

@onready var _facing_pivot: Node2D = $Facing
@onready var _float_animation: AnimationPlayer = $FloatAnimation


func _on_ready_configured() -> void:
	_float_animation.play(&"hover")
	_float_animation.seek(randf() * _float_animation.current_animation_length, true)


func _steer(delta: float, direction: Vector2, distance: float) -> Vector2:
	_facing_pivot.scale.x = -1.0 if direction.x < 0.0 else 1.0

	if _phase == Phase.CASTING:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_release_bolt()
		return Vector2.ZERO

	if _attack_timer <= 0.0:
		_begin_cast(direction)
		return Vector2.ZERO

	if distance < TOO_CLOSE:
		return -direction * speed
	if distance > TOO_FAR:
		return direction * speed * APPROACH_SPEED_SCALE
	# Circle-strafe inside the comfortable band.
	return Vector2(-direction.y, direction.x) * speed * STRAFE_SPEED_SCALE


func _begin_cast(direction: Vector2) -> void:
	_phase = Phase.CASTING
	_state_timer = CAST_WIND_UP
	locked_direction = direction
	_show_telegraph(direction, 95.0, 3.0)


func _release_bolt() -> void:
	_phase = Phase.KITE
	_attack_timer = CAST_INTERVAL / difficulty_pressure
	_hide_telegraph()
	shot_requested.emit(
		global_position + locked_direction * 20.0,
		locked_direction,
		contact_damage * BOLT_DAMAGE_SCALE,
		Projectile.Visual.DEFAULT
	)


func _impact_color() -> Color:
	return Color(0.55, 0.35, 0.75)


func _death_color() -> Color:
	return Color(0.35, 0.18, 0.52)
