extends EnemyBase

## The Floor 8 Warden. Walks the player down while cycling radial bolt volleys;
## below half health it speeds up, fires wider volleys, and starts summoning
## minions and dropping ground hazards.

signal phase_changed(phase: int)

const PHASE_TWO_THRESHOLD := 0.5
const PHASE_ONE_SPEED_SCALE := 0.8
const PHASE_TWO_SPEED_SCALE := 1.25
const PHASE_ONE_VOLLEY := 8
const PHASE_TWO_VOLLEY := 12
const PHASE_ONE_INTERVAL := 1.8
const PHASE_TWO_INTERVAL := 1.25
const RADIAL_DAMAGE := 11.0
const AIMED_DAMAGE := 16.0
const HAZARD_RADIUS := 72.0

var phase: int = 1

var _volley_index: int = 0
var _spin: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _idle_animation: AnimationPlayer = $IdleAnimation


func _on_ready_configured() -> void:
	_idle_animation.play(&"loom")


func _steer(_delta: float, direction: Vector2, _distance: float) -> Vector2:
	_update_phase()

	if _attack_timer <= 0.0:
		_fire_volley(direction)

	var scale_factor := PHASE_TWO_SPEED_SCALE if phase == 2 else PHASE_ONE_SPEED_SCALE
	return direction * speed * scale_factor


func _update_phase() -> void:
	var wanted := 2 if health.ratio() < PHASE_TWO_THRESHOLD else 1
	if wanted == phase:
		return
	phase = wanted
	_sprite.modulate = Color(1.0, 0.6, 0.5) if phase == 2 else Color.WHITE
	EventBus.toast_requested.emit("THE WARDEN AWAKENS", 2.0)
	EventBus.shake_requested.emit(9.0, 0.4)
	phase_changed.emit(phase)


func _fire_volley(direction: Vector2) -> void:
	var count := PHASE_TWO_VOLLEY if phase == 2 else PHASE_ONE_VOLLEY
	for index in count:
		var angle := TAU * float(index) / float(count) + _spin
		shot_requested.emit(
			global_position,
			Vector2.from_angle(angle),
			RADIAL_DAMAGE,
			Projectile.Visual.DEFAULT
		)
	shot_requested.emit(
		global_position, direction, AIMED_DAMAGE, Projectile.Visual.DEFAULT
	)

	if phase == 2 and _volley_index % 2 == 0:
		summon_requested.emit(global_position - direction * 70.0)
		if player != null:
			hazard_requested.emit(player.global_position, HAZARD_RADIUS)

	_volley_index += 1
	_spin += 0.29
	_attack_timer = PHASE_TWO_INTERVAL if phase == 2 else PHASE_ONE_INTERVAL
	EventBus.shake_requested.emit(4.0, 0.15)


func _knockback_resistance() -> float:
	return 0.2


func _impact_color() -> Color:
	return Color(0.95, 0.35, 0.15)


func _death_color() -> Color:
	return Color("58e6ff")
