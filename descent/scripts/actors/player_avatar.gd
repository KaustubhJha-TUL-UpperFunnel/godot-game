class_name PlayerAvatar
extends CharacterBody2D

## The armoured knight. Owns movement, the three-step sword combo, the dash,
## and the six hotbar slots. Damage numbers and impact bursts are announced
## through EventBus so the knight never needs a reference to the HUD or camera.

signal fireball_cast(origin: Vector2, direction: Vector2, damage: float)
signal frost_nova_cast(origin: Vector2, radius: float, damage: float)
signal melee_landed(target: Node2D, damage: float, combo_step: int)
signal dash_started(origin: Vector2)
signal hurt(amount: float)
signal died()

enum Slot { SWORD, FIRE, ICE, DASH, POTION_HEALTH, POTION_MANA }

const COMBO_DURATIONS: Array[float] = [0.30, 0.28, 0.38]
## Fraction of each swing's duration at which the blade actually connects.
const COMBO_STRIKE_POINTS: Array[float] = [0.30, 0.28, 0.35]
const COMBO_DAMAGE: Array[float] = [1.0, 1.18, 1.0]  # step 3 uses finisher_multiplier

const DASH_SPEED := 820.0
const DASH_DURATION := 0.16
const DASH_INVULNERABILITY := 0.22
const HURT_INVULNERABILITY := 0.55
const KNOCKBACK_ON_HURT := 170.0
const FACING_DEADZONE := 0.15

const FIRE_COST := 15.0
const FIRE_COOLDOWN := 2.8
const FIRE_DAMAGE_SCALE := 1.85
const FIRE_PROJECTILE_SPEED := 720.0

const ICE_COST := 20.0
const ICE_COOLDOWN := 4.0
const ICE_DAMAGE_SCALE := 1.45
const ICE_RADIUS := 175.0

const POTION_HEAL := 35.0
const POTION_MANA_RESTORE := 35.0
const POTION_SPEED_BUFF := 1.4
const POTION_SPEED_BUFF_DURATION := 6.0

@export var base_speed: float = 285.0
@export var acceleration: float = 1800.0
@export var base_weapon_damage: float = 20.0
@export var melee_reach: float = 84.0
@export var finisher_multiplier: float = 1.5
@export var dash_cooldown_seconds: float = 1.15
@export var starting_health_potions: int = 2
@export var starting_mana_potions: int = 1

## Walkable floor of the room; LevelHost.walkable_bounds() feeds this in.
var movement_bounds: Rect2 = Rect2(105, 380, 1070, 240)

# Run-upgrade modifiers, all reset by reset_for_run().
var weapon_damage: float = 20.0
var speed_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var projectile_speed_multiplier: float = 1.0
var projectile_count: int = 1
var projectile_pierce: int = 0
var ricochet_chance: float = 0.0
var dash_cooldown_multiplier: float = 1.0

var health_potions: int = 2
var mana_potions: int = 1

var is_dead: bool = false
var combo_step: int = 0

var _aim_direction: Vector2 = Vector2.RIGHT
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_elapsed: float = 0.0
var _attack_duration: float = 0.0
var _combo_window: float = 0.0
var _combo_queued: bool = false
var _strike_emitted: bool = false
var _dash_time_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _speed_buff_left: float = 0.0
var _facing_left: bool = false
var _turning: bool = false

@onready var health: HealthComponent = $Health
@onready var mana: ManaComponent = $Mana
@onready var input: PlayerInput = $Input
@onready var _facing: Node2D = $Facing
@onready var _body: Node2D = $Facing/Body
@onready var _sprite: AnimatedSprite2D = $Facing/Body/Sprite
@onready var _flash: HitFlash = $Flash
@onready var _hitbox: MeleeHitbox = $MeleeHitbox
@onready var _dash_cooldown: Timer = $DashCooldown
@onready var _fire_cooldown: Timer = $FireCooldown
@onready var _ice_cooldown: Timer = $IceCooldown
@onready var _dash_trail: CPUParticles2D = $DashTrail


func _ready() -> void:
	health.depleted.connect(_on_health_depleted)
	input.slot_activated.connect(activate_slot)
	_hitbox.hit_landed.connect(_on_melee_hit_landed)
	_sprite.animation_finished.connect(_on_sprite_animation_finished)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_facing()

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * DASH_SPEED
	else:
		_update_attack(delta)
		velocity = velocity.move_toward(_desired_velocity(), acceleration * delta)

	move_and_slide()
	_clamp_to_bounds()
	_update_locomotion_animation()


func _tick_timers(delta: float) -> void:
	_speed_buff_left = maxf(0.0, _speed_buff_left - delta)


func _desired_velocity() -> Vector2:
	if not input.movement_enabled or is_dead:
		return Vector2.ZERO
	var attack_drag := 1.0
	if is_attacking():
		attack_drag = 0.55 if combo_step == 3 else 0.72
	var buff := POTION_SPEED_BUFF if _speed_buff_left > 0.0 else 1.0
	return input.move_vector * base_speed * speed_multiplier * buff * attack_drag


func _clamp_to_bounds() -> void:
	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)


func _update_facing() -> void:
	_aim_direction = input.aim_vector
	if is_attacking() or absf(_aim_direction.x) < FACING_DEADZONE:
		return

	var wants_left := _aim_direction.x < 0.0
	if wants_left == _facing_left:
		return

	_facing_left = wants_left
	if _dash_time_left > 0.0:
		_apply_facing()
		return
	_play_turn_animation(wants_left, _aim_direction.y >= 0.0)


func _update_locomotion_animation() -> void:
	if is_attacking() or _dash_time_left > 0.0:
		return
	if _turning:
		return
	_play_locomotion_animation()


func _play_locomotion_animation() -> void:
	var moving := velocity.length_squared() > 40.0
	var wanted: StringName = &"run" if moving else &"idle"
	_sprite.speed_scale = 1.0
	_apply_facing()
	if _sprite.animation != wanted or not _sprite.is_playing():
		_sprite.play(wanted)


func _play_turn_animation(turning_left: bool, through_front: bool) -> void:
	_turning = true
	# Rotation frames already contain both sides, so do not mirror this sequence.
	_facing.scale.x = 1.0
	_sprite.speed_scale = 1.0
	var animation_name: StringName
	if through_front:
		animation_name = &"turn_front_left" if turning_left else &"turn_front_right"
	else:
		animation_name = &"turn_back_left" if turning_left else &"turn_back_right"
	_sprite.play(animation_name)


func _apply_facing() -> void:
	# Locomotion and slash art face right; mirror the shared pivot for left.
	_facing.scale.x = -1.0 if _facing_left else 1.0


func _on_sprite_animation_finished() -> void:
	if not _turning:
		return
	_turning = false
	_apply_facing()
	_update_locomotion_animation()


# --- Hotbar ------------------------------------------------------------------


func activate_slot(index: int) -> void:
	if is_dead:
		return
	match index:
		Slot.SWORD:
			_request_attack()
		Slot.FIRE:
			cast_fireball()
		Slot.ICE:
			cast_frost_nova()
		Slot.DASH:
			start_dash()
		Slot.POTION_HEALTH:
			use_health_potion()
		Slot.POTION_MANA:
			use_mana_potion()


func slot_cooldown_ratio(index: int) -> float:
	match index:
		Slot.FIRE:
			return _timer_ratio(_fire_cooldown, FIRE_COOLDOWN)
		Slot.ICE:
			return _timer_ratio(_ice_cooldown, ICE_COOLDOWN)
		Slot.DASH:
			return _timer_ratio(_dash_cooldown, dash_cooldown_seconds * dash_cooldown_multiplier)
	return 0.0


func slot_cooldown_seconds(index: int) -> float:
	match index:
		Slot.FIRE:
			return _fire_cooldown.time_left
		Slot.ICE:
			return _ice_cooldown.time_left
		Slot.DASH:
			return _dash_cooldown.time_left
	return 0.0


func slot_charges(index: int) -> int:
	match index:
		Slot.POTION_HEALTH:
			return health_potions
		Slot.POTION_MANA:
			return mana_potions
	return -1


func _timer_ratio(timer: Timer, full: float) -> float:
	if timer.is_stopped() or full <= 0.0:
		return 0.0
	return clampf(timer.time_left / full, 0.0, 1.0)


func dash_ready_ratio() -> float:
	return 1.0 - slot_cooldown_ratio(Slot.DASH)


# --- Sword combo -------------------------------------------------------------


func is_attacking() -> bool:
	return _attack_duration > 0.0


func attack_progress() -> float:
	if _attack_duration <= 0.0:
		return 0.0
	return clampf(_attack_elapsed / _attack_duration, 0.0, 1.0)


func _request_attack() -> void:
	if is_attacking():
		_combo_queued = combo_step < 3
	elif _combo_window > 0.0 and combo_step < 3:
		_begin_swing(combo_step + 1)
	else:
		_begin_swing(1)


func _begin_swing(step: int) -> void:
	combo_step = clampi(step, 1, 3)
	_attack_direction = _aim_direction
	if absf(_attack_direction.x) >= FACING_DEADZONE:
		_facing_left = _attack_direction.x < 0.0
	_attack_duration = COMBO_DURATIONS[combo_step - 1] / maxf(0.25, attack_speed_multiplier)
	_attack_elapsed = 0.0
	_combo_window = 0.0
	_combo_queued = false
	_strike_emitted = false
	_play_slash_visual()


func _cancel_attack() -> void:
	var was_showing_slash := _sprite.animation == &"slash"
	_combo_queued = false
	_strike_emitted = false
	combo_step = 0
	_attack_elapsed = 0.0
	_attack_duration = 0.0
	_combo_window = 0.0
	if was_showing_slash:
		_play_locomotion_animation()


func _update_attack(delta: float) -> void:
	if not input.movement_enabled:
		_cancel_attack()
		return

	if input.attack_held:
		_request_attack()

	if _attack_duration <= 0.0:
		if _combo_window > 0.0:
			_combo_window = maxf(0.0, _combo_window - delta)
			if _combo_window <= 0.0:
				combo_step = 0
		return

	_attack_elapsed += delta
	if not _strike_emitted and attack_progress() >= COMBO_STRIKE_POINTS[combo_step - 1]:
		_strike_emitted = true
		_swing_hitbox()

	if _attack_elapsed < _attack_duration:
		return

	var completed := combo_step
	_attack_duration = 0.0
	_attack_elapsed = 0.0
	if _combo_queued and completed < 3:
		_begin_swing(completed + 1)
	else:
		_combo_queued = false
		_combo_window = (0.30 if completed == 3 else 0.23) / maxf(0.25, attack_speed_multiplier)


func _swing_hitbox() -> void:
	var is_finisher := combo_step == 3
	var multiplier := finisher_multiplier if is_finisher else COMBO_DAMAGE[combo_step - 1]
	_hitbox.strike(
		_attack_direction, weapon_damage * multiplier, combo_step, 1.25 if is_finisher else 1.0
	)
	_lunge(_attack_direction, 20.0 if is_finisher else 14.0)


func _on_melee_hit_landed(target: Node2D, damage: float, step: int) -> void:
	if not target.has_method("take_hit"):
		return
	var style := (
		EventBus.DamageStyle.CRITICAL if step == 3 else EventBus.DamageStyle.NORMAL
	)
	target.take_hit(damage, _attack_direction, style)
	melee_landed.emit(target, damage, step)
	EventBus.shake_requested.emit(6.5 if step == 3 else 3.8, 0.12)
	EventBus.hitstop_requested.emit(0.04)


func _play_slash_visual() -> void:
	_turning = false
	_apply_facing()
	var frame_count := _sprite.sprite_frames.get_frame_count(&"slash")
	var base_speed := _sprite.sprite_frames.get_animation_speed(&"slash")
	var visual_duration := float(frame_count) / base_speed
	_sprite.speed_scale = visual_duration / _attack_duration
	_sprite.play(&"slash")


func _lunge(direction: Vector2, distance: float) -> void:
	# The pivot is mirrored when facing left, so lunge along the local axis.
	var local := Vector2(absf(direction.normalized().x) * distance, 0.0)
	var tween := create_tween()
	tween.tween_property(_body, "position", local, _attack_duration * 0.35)
	tween.tween_property(_body, "position", Vector2.ZERO, _attack_duration * 0.65)


# --- Dash --------------------------------------------------------------------


func start_dash() -> bool:
	if not input.movement_enabled or is_dead or not _dash_cooldown.is_stopped():
		return false
	_dash_direction = (
		input.move_vector.normalized()
		if input.move_vector.length_squared() > 0.04
		else _aim_direction
	)
	_dash_time_left = DASH_DURATION
	_dash_cooldown.start(dash_cooldown_seconds * dash_cooldown_multiplier)
	health.grant_invulnerability(DASH_INVULNERABILITY)
	_cancel_attack()
	_dash_trail.restart()
	dash_started.emit(global_position)
	EventBus.burst_requested.emit(global_position, Color(0.35, 0.9, 1.0, 0.7), 12, 125.0, 3.0)
	return true


# --- Spells and potions ------------------------------------------------------


func cast_fireball() -> bool:
	if not input.movement_enabled or is_dead:
		return false
	if not _fire_cooldown.is_stopped() or not mana.try_spend(FIRE_COST):
		return false
	_fire_cooldown.start(FIRE_COOLDOWN)
	fireball_cast.emit(
		global_position + _aim_direction * 24.0, _aim_direction, weapon_damage * FIRE_DAMAGE_SCALE
	)
	EventBus.burst_requested.emit(global_position, Color("ff6622"), 15, 170.0, 4.0)
	EventBus.shake_requested.emit(3.5, 0.09)
	return true


func cast_frost_nova() -> bool:
	if not input.movement_enabled or is_dead:
		return false
	if not _ice_cooldown.is_stopped() or not mana.try_spend(ICE_COST):
		return false
	_ice_cooldown.start(ICE_COOLDOWN)
	frost_nova_cast.emit(global_position, ICE_RADIUS, weapon_damage * ICE_DAMAGE_SCALE)
	EventBus.burst_requested.emit(global_position, Color("66eeff"), 25, 210.0, 4.5)
	EventBus.shake_requested.emit(4.5, 0.12)
	return true


func use_health_potion() -> bool:
	if is_dead or health_potions <= 0 or health.current >= health.maximum:
		return false
	health_potions -= 1
	var gained := health.heal(POTION_HEAL)
	EventBus.damage_number_requested.emit(
		global_position, gained, EventBus.DamageStyle.HEAL
	)
	return true


func use_mana_potion() -> bool:
	if is_dead or mana_potions <= 0:
		return false
	mana_potions -= 1
	mana.restore(POTION_MANA_RESTORE)
	_speed_buff_left = POTION_SPEED_BUFF_DURATION
	EventBus.toast_requested.emit("ELIXIR: +MANA, +40% SPEED", 1.4)
	return true


func refill_floor_charges() -> void:
	health_potions = starting_health_potions
	mana_potions = starting_mana_potions


# --- Damage ------------------------------------------------------------------


func take_hit(amount: float, _direction: Vector2, _style: int = 0) -> float:
	return take_damage(amount, global_position - Vector2(1, 0))


func take_damage(amount: float, source_position: Vector2) -> float:
	if is_dead or not input.movement_enabled:
		return 0.0
	var dealt := health.take_damage(amount, HURT_INVULNERABILITY, source_position)
	if dealt <= 0.0:
		return 0.0

	_flash.flash()
	var away := global_position - source_position
	if away.length_squared() > 0.01:
		velocity += away.normalized() * KNOCKBACK_ON_HURT

	EventBus.damage_number_requested.emit(
		global_position, dealt, EventBus.DamageStyle.PLAYER_HURT
	)
	EventBus.shake_requested.emit(minf(13.0, 4.0 + dealt * 0.3), 0.18)
	EventBus.burst_requested.emit(global_position, Color("ff4f62"), 8, 145.0, 3.0)
	Input.vibrate_handheld(45)
	hurt.emit(dealt)
	return dealt


func heal(amount: float) -> float:
	return health.heal(amount)


## Called by DeathZone. A fall is not damage: the invulnerability window from a
## dash must not carry the knight across the bottom of a pit, and there is no
## knockback to apply because there is nothing to be knocked back onto.
func fall_to_death() -> void:
	if is_dead:
		return
	_dash_time_left = 0.0
	velocity = Vector2.ZERO
	health.clear_invulnerability()
	health.take_damage(health.current, 0.0, global_position)


func _on_health_depleted() -> void:
	if is_dead:
		return
	is_dead = true
	set_control_enabled(false, false)
	_cancel_attack()
	died.emit()


func revive(health_fraction: float) -> void:
	is_dead = false
	health.revive(health_fraction)
	mana.restore(mana.maximum)
	set_control_enabled(true, true)
	EventBus.burst_requested.emit(global_position, Color("58e6ff"), 30, 210.0, 5.0)


# --- Run lifecycle -----------------------------------------------------------


func set_control_enabled(movement: bool, attacks: bool) -> void:
	input.movement_enabled = movement and not is_dead
	input.attack_enabled = attacks and not is_dead
	if not movement:
		velocity = Vector2.ZERO
		input.clear_touch_state()
		_cancel_attack()


func reset_for_run(max_health: float, damage_multiplier: float, run_speed_multiplier: float) -> void:
	is_dead = false
	health.configure(max_health, true)
	mana.reset()

	weapon_damage = base_weapon_damage * damage_multiplier
	speed_multiplier = run_speed_multiplier
	attack_speed_multiplier = 1.0
	projectile_speed_multiplier = 1.0
	projectile_count = 1
	projectile_pierce = 0
	ricochet_chance = 0.0
	dash_cooldown_multiplier = 1.0

	refill_floor_charges()
	_speed_buff_left = 0.0
	_dash_time_left = 0.0
	_dash_cooldown.stop()
	_fire_cooldown.stop()
	_ice_cooldown.stop()
	_cancel_attack()
	velocity = Vector2.ZERO
	set_control_enabled(false, false)
	show()


# --- Upgrade hooks (called by UpgradeCatalog) --------------------------------


func add_damage_multiplier(amount: float) -> void:
	weapon_damage *= 1.0 + amount


func add_attack_speed(amount: float) -> void:
	attack_speed_multiplier += amount


func add_projectile_speed(amount: float) -> void:
	projectile_speed_multiplier += amount


func add_projectile() -> void:
	projectile_count = mini(projectile_count + 1, 4)


func add_move_speed(amount: float) -> void:
	speed_multiplier += amount


func reduce_dash_cooldown(amount: float) -> void:
	dash_cooldown_multiplier = maxf(0.45, dash_cooldown_multiplier - amount)


func add_max_health(amount: float, bonus_heal: float) -> void:
	health.set_maximum(health.maximum + amount, false, bonus_heal)


func add_pierce() -> void:
	projectile_pierce = mini(projectile_pierce + 1, 3)


func add_ricochet(chance: float) -> void:
	ricochet_chance = minf(1.0, ricochet_chance + chance)
