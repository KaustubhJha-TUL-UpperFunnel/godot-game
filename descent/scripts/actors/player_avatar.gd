class_name PlayerAvatar
extends CharacterBody2D

## The armoured knight. Owns movement, the three-step sword combo, the dash,
## and the hotbar slots. Damage numbers and impact bursts are announced
## through EventBus so the knight never needs a reference to the HUD or camera.

signal fireball_cast(origin: Vector2, direction: Vector2, damage: float)
signal frost_nova_cast(origin: Vector2, radius: float, damage: float)
signal melee_landed(target: Node2D, damage: float, combo_step: int)
signal dash_started(origin: Vector2)
signal jump_started()
signal platform_climbed()
signal platform_dropped()
signal health_potion_used()
signal mana_potion_used()
signal hurt(amount: float)
signal died()

enum Slot { SWORD, FIRE, ICE, DASH, POTION_HEALTH, POTION_MANA, JUMP, DROP }

const COMBO_DURATIONS: Array[float] = [0.30, 0.28, 0.38]
## Fraction of each swing's duration at which the blade actually connects.
const COMBO_STRIKE_POINTS: Array[float] = [0.30, 0.28, 0.35]
const COMBO_DAMAGE: Array[float] = [1.0, 1.18, 1.0]  # step 3 uses finisher_multiplier

const DASH_SPEED := 820.0
const DASH_DURATION := 0.16
const DASH_INVULNERABILITY := 0.22
const HURT_INVULNERABILITY := 0.55
const FLOOR_SPAWN_PROTECTION := 1.0
const KNOCKBACK_ON_HURT := 170.0
const FACING_DEADZONE := 0.15

const FIRE_COST := 15.0
const FIRE_COOLDOWN := 2.8
const FIRE_DAMAGE_SCALE := 1.85
const FIRE_PROJECTILE_SPEED := 720.0
const AIM_GUIDE_LENGTH := 140.0
const AIM_ORIGIN_OFFSET := Vector2(0.0, -44.0)

const ICE_COST := 20.0
const ICE_COOLDOWN := 4.0
const ICE_DAMAGE_SCALE := 1.45
const ICE_RADIUS := 175.0

const POTION_HEAL := 35.0
const POTION_MANA_RESTORE := 35.0
const POTION_SPEED_BUFF := 1.4
const POTION_SPEED_BUFF_DURATION := 6.0

const PLATFORM_GRAVITY := 1850.0
const JUMP_SPEED := 830.0
const BODY_RADIUS := 17.0
const AIR_CLIMB_REACH := 220.0
const CLIMB_HORIZONTAL_REACH := 42.0
const DASH_CLIMB_CONTACT_HEIGHT := 128.0
const AIR_CLIMB_DURATION := 0.18
const DASH_CLIMB_DURATION := 0.12
const CLIMB_ARC_HEIGHT := 8.0
const DROP_HOLD_SECONDS := 0.18
const DROP_IGNORE_SECONDS := 0.16
const WALLS_LAYER_NUMBER := 3

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
var _projectile_aiming: bool = false
var _level: Level
var _vertical_level: bool = false
var _drop_hold_time: float = 0.0
var _drop_ignore_time: float = 0.0
var _drop_consumed: bool = false
var _climb_start: Vector2 = Vector2.ZERO
var _climb_target: Vector2 = Vector2.ZERO
var _climb_elapsed: float = 0.0
var _climb_duration: float = 0.0

@onready var health: HealthComponent = $Health
@onready var mana: ManaComponent = $Mana
@onready var input: PlayerInput = $Input
@onready var _facing: Node2D = $Facing
@onready var _body: Node2D = $Facing/Body
@onready var _sprite: AnimatedSprite2D = $Facing/Body/Sprite
@onready var _flash: HitFlash = $Flash
@onready var _hitbox: MeleeHitbox = $MeleeHitbox
@onready var _aim_guide: Line2D = $AimGuide
@onready var _dash_cooldown: Timer = $DashCooldown
@onready var _fire_cooldown: Timer = $FireCooldown
@onready var _ice_cooldown: Timer = $IceCooldown
@onready var _dash_trail: CPUParticles2D = $DashTrail
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health.depleted.connect(_on_health_depleted)
	input.slot_activated.connect(activate_slot)
	input.slot_hold_changed.connect(_on_input_slot_hold_changed)
	_hitbox.hit_landed.connect(_on_melee_hit_landed)
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_update_collider_offset()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_drop_collision(delta)
	_update_facing()

	if _climb_duration > 0.0:
		_update_climb_transition(delta)
		_clamp_to_bounds()
		_update_locomotion_animation()
		return

	var upward_dashing := _dash_time_left > 0.0 and _dash_direction.y < -0.5
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * DASH_SPEED
	else:
		_update_attack(delta)
		if _vertical_level:
			_update_platformer_velocity(delta)
		else:
			velocity = velocity.move_toward(_desired_velocity(), acceleration * delta)

	if _climb_duration <= 0.0:
		move_and_slide()
	if upward_dashing:
		_try_climb_overhead(DASH_CLIMB_CONTACT_HEIGHT, DASH_CLIMB_DURATION)
	_clamp_to_bounds()
	_update_locomotion_animation()


func _tick_timers(delta: float) -> void:
	_speed_buff_left = maxf(0.0, _speed_buff_left - delta)


func _desired_velocity() -> Vector2:
	if not input.movement_enabled or is_dead or _projectile_aiming:
		return Vector2.ZERO
	var attack_drag := 1.0
	if is_attacking():
		attack_drag = 0.55 if combo_step == 3 else 0.72
	var buff := POTION_SPEED_BUFF if _speed_buff_left > 0.0 else 1.0
	return input.move_vector * base_speed * speed_multiplier * buff * attack_drag


func configure_level(level: Level) -> void:
	_level = level
	_vertical_level = level != null and level.is_vertical()
	motion_mode = (
		CharacterBody2D.MOTION_MODE_GROUNDED
		if _vertical_level
		else CharacterBody2D.MOTION_MODE_FLOATING
	)
	up_direction = Vector2.UP
	floor_snap_length = 12.0 if _vertical_level else 1.0
	_drop_hold_time = 0.0
	_drop_ignore_time = 0.0
	_drop_consumed = false
	_climb_duration = 0.0
	set_collision_mask_value(WALLS_LAYER_NUMBER, true)
	_update_collider_offset()


func _update_collider_offset() -> void:
	var shape_node := _collision_shape if _collision_shape != null else get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.position.y = -BODY_RADIUS if _vertical_level else 0.0


func _update_platformer_velocity(delta: float) -> void:
	var wanted := _desired_velocity()
	velocity.x = move_toward(velocity.x, wanted.x, acceleration * delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + PLATFORM_GRAVITY * delta, PLATFORM_GRAVITY)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	var jump_requested := input.consume_jump()
	if jump_requested:
		# Jump is a movement action, so it disarms fire aiming without casting.
		# This also covers keyboard jump, which does not pass through Hotbar.
		_cancel_projectile_aim()
	if jump_requested and not is_dead:
		if is_on_floor():
			velocity.y = -JUMP_SPEED
			_drop_hold_time = 0.0
			jump_started.emit()
		else:
			_try_climb_overhead(AIR_CLIMB_REACH, AIR_CLIMB_DURATION)

	_update_drop_through(delta)


## A second jump while airborne is a contextual climb, not a free double jump.
## It succeeds only when a safe platform is directly above or just beyond the
## player's shoulder reach.
func _try_climb_overhead(max_height: float, duration: float = AIR_CLIMB_DURATION) -> bool:
	if not _vertical_level or _level == null:
		return false

	var best_platform: LevelPlatform = null
	var best_position := Vector2.ZERO
	var best_height := INF
	for platform in _level.platforms():
		var x_range := platform.navigation_x_range()
		if (
			position.x < x_range.x - CLIMB_HORIZONTAL_REACH
			or position.x > x_range.y + CLIMB_HORIZONTAL_REACH
		):
			continue

		var target_x := (x_range.x + x_range.y) * 0.5
		if x_range.y - x_range.x >= BODY_RADIUS * 2.0:
			target_x = clampf(position.x, x_range.x + BODY_RADIUS, x_range.y - BODY_RADIUS)
		var surface_y := platform.surface_y_at(target_x, 1.0)
		if is_inf(surface_y):
			continue
		var target := Vector2(target_x, surface_y - 2.0)
		var climb_height := position.y - target.y
		if climb_height < BODY_RADIUS or climb_height > max_height:
			continue
		if not _level.is_safe_spawn(target, BODY_RADIUS):
			continue
		if climb_height < best_height:
			best_platform = platform
			best_position = target
			best_height = climb_height

	if best_platform == null:
		return false

	_climb_start = position
	_climb_target = best_position
	_climb_elapsed = 0.0
	_climb_duration = maxf(0.01, duration)
	velocity.y = 0.0
	_dash_time_left = 0.0
	floor_snap_length = 12.0
	return true


func _update_climb_transition(delta: float) -> void:
	_climb_elapsed = minf(_climb_elapsed + delta, _climb_duration)
	var progress := _climb_elapsed / _climb_duration
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	position = _climb_start.lerp(_climb_target, eased)
	position.y -= sin(progress * PI) * CLIMB_ARC_HEIGHT
	velocity = Vector2.ZERO
	if progress >= 1.0:
		position = _climb_target
		_climb_duration = 0.0
		platform_climbed.emit()


func _update_drop_through(delta: float) -> void:
	if input.consume_drop():
		_begin_platform_drop()
		return
	if not input.drop_held():
		_drop_hold_time = 0.0
		_drop_consumed = false
		return
	if _drop_ignore_time > 0.0:
		return
	if _drop_consumed or not is_on_floor() or not _floor_is_platform():
		_drop_hold_time = 0.0
		return
	_drop_hold_time += delta
	if _drop_hold_time < DROP_HOLD_SECONDS:
		return
	_begin_platform_drop()


func _begin_platform_drop() -> void:
	if _drop_ignore_time > 0.0:
		return
	if _drop_consumed or not is_on_floor() or not _floor_is_platform():
		return
	_drop_hold_time = 0.0
	_drop_consumed = true
	_drop_ignore_time = DROP_IGNORE_SECONDS
	set_collision_mask_value(WALLS_LAYER_NUMBER, false)
	position.y += 8.0
	velocity.y = 120.0
	platform_dropped.emit()


func _tick_drop_collision(delta: float) -> void:
	if _drop_ignore_time <= 0.0:
		return
	_drop_ignore_time -= delta
	if _drop_ignore_time <= 0.0:
		set_collision_mask_value(WALLS_LAYER_NUMBER, true)


func _floor_is_platform() -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y > -0.45:
			continue
		var platform := collision.get_collider() as LevelPlatform
		if platform != null:
			return true
	return false


func _clamp_to_bounds() -> void:
	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	if not _vertical_level:
		position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)


func _update_facing() -> void:
	_aim_direction = (
		input.move_vector.normalized()
		if _projectile_aiming and input.move_vector.length_squared() > 0.04
		else input.aim_vector
	)
	if _projectile_aiming:
		_aim_guide.points = PackedVector2Array([
			AIM_ORIGIN_OFFSET, AIM_ORIGIN_OFFSET + _aim_direction * AIM_GUIDE_LENGTH
		])
	else:
		if is_instance_valid(_aim_guide):
			_aim_guide.hide()
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
	if _projectile_aiming:
		_sprite.speed_scale = 1.0
		_apply_facing()
		if _sprite.animation != &"idle" or not _sprite.is_playing():
			_sprite.play(&"idle")
		return
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
	if _projectile_aiming and index != Slot.FIRE:
		_cancel_projectile_aim()
	match index:
		Slot.SWORD:
			_request_attack()
		Slot.FIRE:
			if _projectile_aiming:
				release_projectile_aim()
			else:
				begin_projectile_aim()
		Slot.ICE:
			cast_frost_nova()
		Slot.DASH:
			start_dash()
		Slot.POTION_HEALTH:
			use_health_potion()
		Slot.POTION_MANA:
			use_mana_potion()
		Slot.JUMP:
			_cancel_projectile_aim()
			input.request_touch_jump()
		Slot.DROP:
			_cancel_projectile_aim()
			if _vertical_level:
				input.request_touch_drop()


func _on_input_slot_hold_changed(index: int, held: bool) -> void:
	if index != Slot.FIRE:
		return
	if held:
		begin_projectile_aim()
	else:
		release_projectile_aim()


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
	if _projectile_aiming:
		_cancel_attack()
		return

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
	_cancel_projectile_aim()
	if _vertical_level:
		var upward_boost := input.up_held() and (
			not is_on_floor() or velocity.y < -1.0 or input.jump_requested()
		)
		if upward_boost:
			input.consume_jump()
			_dash_direction = Vector2.UP
		else:
			var horizontal := input.move_vector.x
			if absf(horizontal) < 0.1:
				horizontal = -1.0 if _facing_left else 1.0
			_dash_direction = Vector2(signf(horizontal), 0.0)
	else:
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


func begin_projectile_aim() -> bool:
	if (
		not input.movement_enabled
		or not input.attack_enabled
		or is_dead
		or not _fire_cooldown.is_stopped()
		or not mana.has(FIRE_COST)
	):
		return false
	_projectile_aiming = true
	_dash_time_left = 0.0
	_cancel_attack()
	if _vertical_level:
		velocity.x = 0.0
	else:
		velocity = Vector2.ZERO
	_aim_guide.points = PackedVector2Array([
		AIM_ORIGIN_OFFSET, AIM_ORIGIN_OFFSET + _aim_direction * AIM_GUIDE_LENGTH
	])
	_aim_guide.show()
	return true


func release_projectile_aim() -> bool:
	if not _projectile_aiming:
		return false
	_projectile_aiming = false
	_aim_guide.hide()
	return cast_fireball()


func _cancel_projectile_aim() -> void:
	_projectile_aiming = false
	if is_instance_valid(_aim_guide):
		_aim_guide.hide()


func cast_fireball() -> bool:
	if not input.movement_enabled or not input.attack_enabled or is_dead:
		return false
	if not _fire_cooldown.is_stopped() or not mana.try_spend(FIRE_COST):
		return false
	_cancel_projectile_aim()
	_fire_cooldown.start(FIRE_COOLDOWN)
	var spawn_pos := global_position + AIM_ORIGIN_OFFSET + _aim_direction * 24.0
	fireball_cast.emit(
		spawn_pos, _aim_direction, weapon_damage * FIRE_DAMAGE_SCALE
	)
	EventBus.burst_requested.emit(spawn_pos, Color("ff6622"), 15, 170.0, 4.0)
	EventBus.shake_requested.emit(3.5, 0.09)
	return true


func cast_frost_nova() -> bool:
	if not input.movement_enabled or not input.attack_enabled or is_dead:
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
	health_potion_used.emit()
	return true


func use_mana_potion() -> bool:
	if is_dead or mana_potions <= 0:
		return false
	mana_potions -= 1
	mana.restore(POTION_MANA_RESTORE)
	_speed_buff_left = POTION_SPEED_BUFF_DURATION
	EventBus.toast_requested.emit("ELIXIR: +MANA, +40% SPEED", 1.4)
	mana_potion_used.emit()
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


func restore_full_health() -> void:
	if not is_dead:
		health.heal(health.maximum)


func prepare_floor_spawn() -> void:
	velocity = Vector2.ZERO
	_dash_time_left = 0.0
	_climb_duration = 0.0
	_drop_hold_time = 0.0
	_drop_ignore_time = 0.0
	_drop_consumed = false
	set_collision_mask_value(WALLS_LAYER_NUMBER, true)
	health.grant_invulnerability(FLOOR_SPAWN_PROTECTION)


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
	_cancel_projectile_aim()
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
		_cancel_projectile_aim()
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
	_cancel_projectile_aim()
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
