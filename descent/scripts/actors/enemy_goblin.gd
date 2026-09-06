extends EnemyBase

## Charger archetype. Creeps forward, freezes to telegraph a dagger rush, then
## commits to a locked-in line so the player can sidestep it.

enum Phase { APPROACH, WIND_UP, CHARGE, RECOVER }

const APPROACH_SPEED_SCALE := 0.45
const CHARGE_SPEED := 610.0
const WIND_UP_TIME := 0.72
const CHARGE_TIME := 0.58
const RECOVER_TIME := 0.7
const CHARGE_TRIGGER_RANGE := 520.0
const ATTACK_INTERVAL := 1.55

var _phase: Phase = Phase.APPROACH

@onready var _facing_pivot: Node2D = $Facing
@onready var _stride: AnimationPlayer = $StrideAnimation


func _on_ready_configured() -> void:
	_stride.play(&"stride")
	_stride.seek(randf() * _stride.current_animation_length, true)


func _steer(delta: float, direction: Vector2, distance: float) -> Vector2:
	if _phase != Phase.CHARGE:
		_facing_pivot.scale.x = -1.0 if direction.x < 0.0 else 1.0

	match _phase:
		Phase.APPROACH:
			if _attack_timer <= 0.0 and distance < CHARGE_TRIGGER_RANGE:
				_enter_wind_up(direction)
			return direction * speed * APPROACH_SPEED_SCALE

		Phase.WIND_UP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_phase = Phase.CHARGE
				_state_timer = CHARGE_TIME
				_hide_telegraph()
			return Vector2.ZERO

		Phase.CHARGE:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_phase = Phase.RECOVER
				_state_timer = RECOVER_TIME
			return locked_direction * CHARGE_SPEED * difficulty_pressure

		Phase.RECOVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_phase = Phase.APPROACH
				_attack_timer = ATTACK_INTERVAL
			return Vector2.ZERO

	return Vector2.ZERO


func _enter_wind_up(direction: Vector2) -> void:
	_phase = Phase.WIND_UP
	_state_timer = WIND_UP_TIME
	locked_direction = direction
	_show_telegraph(direction, 145.0, 6.0)


func _impact_color() -> Color:
	return Color(0.38, 0.62, 0.22)


func _death_color() -> Color:
	return Color(0.22, 0.38, 0.14)
