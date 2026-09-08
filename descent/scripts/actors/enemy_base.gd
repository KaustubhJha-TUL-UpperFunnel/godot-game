class_name EnemyBase
extends CharacterBody2D

## Shared behaviour for every enemy: stat rollup from an EnemyData resource,
## movement with anti-stuck steering, hit reactions, and death payout.
##
## Subclasses only implement _steer(), which returns the velocity the archetype
## wants this frame. Anything an archetype needs to fire off (a projectile, a
## summon, a floor hazard) is emitted as a signal for GameplayController.

signal died(enemy: EnemyBase, coin_reward: int, was_elite: bool)
signal shot_requested(origin: Vector2, direction: Vector2, damage: float)
signal summon_requested(origin: Vector2)
signal hazard_requested(origin: Vector2, radius: float)

## Base statline; assign the matching .tres from descent/data/enemies/.
@export var stats: EnemyData
## Radius at which the player takes contact damage from this enemy.
@export var contact_radius: float = 36.0
## Radius projectiles use when testing a hit against this enemy.
@export var projectile_radius: float = 24.0
## The boss is authored at its final strength, so it opts out of floor scaling.
@export var scales_with_floor: bool = true
## How much of the sprite height the overhead health bar floats above the feet.
@export var health_bar_height: float = 62.0
## The boss reports to the dedicated boss bar in the HUD instead.
@export var show_overhead_health_bar: bool = true

const KNOCKBACK_ON_HIT := 85.0
const HIT_INVULNERABILITY := 0.035
const STUCK_THRESHOLD := 5.0
const STUCK_TIMEOUT := 0.7
const STEERING_ACCELERATION := 1000.0
const PLATFORM_GRAVITY := 1850.0
const PLATFORM_JUMP_SPEED := 840.0
const MAX_PLATFORM_SWITCH_HEIGHT := 190.0
const SAFE_EDGE_LOOKAHEAD := 34.0
const WALLS_LAYER_NUMBER := 3
const DROP_IGNORE_SECONDS := 0.12

var speed: float = 120.0
var base_damage: float = 10.0
var contact_damage: float = 10.0
var coin_reward: int = 2
var is_elite: bool = false
var difficulty_pressure: float = 1.0
var combat_enabled: bool = false
var is_dead: bool = false

var facing: Vector2 = Vector2.RIGHT
var locked_direction: Vector2 = Vector2.RIGHT
var movement_bounds: Rect2 = Rect2(105, 380, 1070, 240)
var player: Node2D
var level: Level

var _age: float = 0.0
var _attack_timer: float = 0.7
var _state_timer: float = 0.0
var _stuck_time: float = 0.0
var _last_progress_position: Vector2
var _vertical_level: bool = false
var _drop_ignore_time: float = 0.0

@onready var health: HealthComponent = $Health
@onready var _flash: HitFlash = $Flash
@onready var _health_bar: HealthBar = $HealthBar
@onready var _telegraph: Line2D = $Telegraph


func _ready() -> void:
	add_to_group(&"enemies")
	health.depleted.connect(_die)
	health.health_changed.connect(_on_health_changed)
	_last_progress_position = global_position
	_health_bar.position.y = -health_bar_height
	_health_bar.visible = false
	_telegraph.visible = false
	_on_ready_configured()


## Subclass hook for one-time visual setup.
func _on_ready_configured() -> void:
	pass


## Applies the archetype statline plus floor, elite, and difficulty scaling.
func configure(floor_number: int, elite: bool, pressure: float) -> void:
	is_elite = elite
	difficulty_pressure = maxf(0.75, pressure)

	var maximum := 42.0
	if stats != null:
		maximum = stats.maximum_health
		speed = stats.movement_speed
		contact_damage = stats.damage
		coin_reward = stats.coin_reward
	else:
		contact_damage = base_damage

	if scales_with_floor:
		maximum *= 1.0 + float(maxi(0, floor_number - 1)) * 0.11
		contact_damage = (contact_damage + float(floor_number - 1) * 1.25) * (1.0 + float(floor_number - 1) * 0.035)
		coin_reward += int(floor_number / 3.0)
		if is_elite:
			maximum *= 1.75
			speed *= 1.13
			contact_damage *= 1.35
			coin_reward *= 2

	speed *= difficulty_pressure
	contact_damage *= difficulty_pressure
	health.configure(maximum, true)

	if is_elite:
		scale = Vector2.ONE * 1.2
		_flash.set_base_color(Color(1.2, 1.1, 0.8))


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled and not is_dead
	if not combat_enabled:
		velocity = Vector2.ZERO


func configure_navigation(room: Level) -> void:
	level = room
	_vertical_level = room != null and room.is_vertical()
	motion_mode = (
		CharacterBody2D.MOTION_MODE_GROUNDED
		if _vertical_level
		else CharacterBody2D.MOTION_MODE_FLOATING
	)
	up_direction = Vector2.UP
	floor_snap_length = 10.0 if _vertical_level else 1.0
	_drop_ignore_time = 0.0
	set_collision_mask_value(WALLS_LAYER_NUMBER, true)


func _physics_process(delta: float) -> void:
	if is_dead or not combat_enabled or player == null:
		return

	_age += delta
	_attack_timer -= delta

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	facing = to_player / distance if distance > 0.01 else Vector2.RIGHT

	var desired := _steer(delta, facing, distance)
	desired = _unstick(desired, delta)

	if _vertical_level:
		_update_platform_navigation(desired, delta)
	else:
		velocity = velocity.move_toward(desired, STEERING_ACCELERATION * delta)
	move_and_slide()

	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	if not _vertical_level:
		position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)


func _update_platform_navigation(desired: Vector2, delta: float) -> void:
	_tick_drop_collision(delta)

	var current := level.supporting_platform(position, projectile_radius, 52.0)
	var target := level.supporting_platform(player.position, 20.0, 62.0)
	var horizontal := desired.x

	if current != null and target != null and current != target:
		var route_target := level.next_platform_toward(
			current,
			target,
			(projectile_radius + 4.0) * 2.0,
			MAX_PLATFORM_SWITCH_HEIGHT
		)
		if route_target != null:
			if level.platforms_share_route(current, route_target):
				var route_range := route_target.navigation_x_range()
				var route_x := (route_range.x + route_range.y) * 0.5
				if route_range.y - route_range.x >= projectile_radius * 2.0:
					route_x = clampf(
						player.position.x,
						route_range.x + projectile_radius,
						route_range.y - projectile_radius
					)
				horizontal = signf(route_x - position.x) * maxf(absf(horizontal), speed * 0.7)
			else:
				horizontal = _approach_platform_switch(current, route_target, horizontal)

	if is_on_floor() and current != null and absf(horizontal) > 0.1:
		var look_x := position.x + signf(horizontal) * (projectile_radius + SAFE_EDGE_LOOKAHEAD)
		var own_surface := current.surface_y_at(look_x, 2.0)
		if is_inf(own_surface) \
			and not level.has_support_below(look_x, position.y, 68.0, current):
			horizontal = 0.0

	velocity.x = move_toward(velocity.x, horizontal, STEERING_ACCELERATION * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + PLATFORM_GRAVITY * delta, PLATFORM_GRAVITY)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _approach_platform_switch(
	current: LevelPlatform, target: LevelPlatform, fallback_horizontal: float
) -> float:
	var current_range := current.navigation_x_range()
	var target_range := target.navigation_x_range()
	var overlap_left := maxf(current_range.x, target_range.x)
	var overlap_right := minf(current_range.y, target_range.y)
	var switch_margin := projectile_radius + 4.0
	if overlap_right - overlap_left < switch_margin * 2.0:
		return fallback_horizontal

	var switch_x := clampf(
		player.position.x, overlap_left + switch_margin, overlap_right - switch_margin
	)
	var toward_switch := signf(switch_x - position.x) * maxf(absf(fallback_horizontal), speed * 0.7)
	if absf(position.x - switch_x) > 18.0:
		return toward_switch

	var current_y := current.surface_y_at(position.x, 20.0)
	var target_y := target.surface_y_at(position.x, 20.0)
	if is_inf(current_y) or is_inf(target_y):
		return fallback_horizontal
	var height_delta := current_y - target_y

	if height_delta > 28.0 and height_delta <= MAX_PLATFORM_SWITCH_HEIGHT and is_on_floor():
		velocity.y = -PLATFORM_JUMP_SPEED
	elif height_delta < -28.0 and is_on_floor() and _drop_ignore_time <= 0.0:
		_begin_controlled_drop()
	return toward_switch


func _begin_controlled_drop() -> void:
	_drop_ignore_time = DROP_IGNORE_SECONDS
	set_collision_mask_value(WALLS_LAYER_NUMBER, false)
	position.y += 7.0
	velocity.y = 130.0


func _tick_drop_collision(delta: float) -> void:
	if _drop_ignore_time <= 0.0:
		return
	_drop_ignore_time -= delta
	if _drop_ignore_time <= 0.0:
		set_collision_mask_value(WALLS_LAYER_NUMBER, true)


## Returns the velocity this archetype wants. Overridden by every subclass.
func _steer(_delta: float, _direction: Vector2, _distance: float) -> Vector2:
	return Vector2.ZERO


## Nudges the enemy sideways when it has been pressed against geometry, so a
## pack does not pile up permanently on a pillar corner.
func _unstick(desired: Vector2, delta: float) -> Vector2:
	if global_position.distance_to(_last_progress_position) < STUCK_THRESHOLD \
			and desired.length_squared() > 1.0:
		_stuck_time += delta
		if _stuck_time > STUCK_TIMEOUT:
			_stuck_time = 0.45
			return desired.rotated(1.15 if get_instance_id() % 2 == 0 else -1.15)
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
		_last_progress_position = global_position
	return desired


func _on_health_changed(_current: float, _maximum: float) -> void:
	if show_overhead_health_bar:
		_health_bar.set_ratio(health.ratio())


# --- Damage and death --------------------------------------------------------


func take_hit(amount: float, direction: Vector2, style: int = EventBus.DamageStyle.NORMAL) -> float:
	if is_dead or not combat_enabled:
		return 0.0
	# Distinct fire projectiles are already deduplicated per target by
	# Projectile, so a prior hit's tiny generic invulnerability window must not
	# make a following bolt appear to pass through harmlessly.
	if style == EventBus.DamageStyle.FIRE:
		health.clear_invulnerability()
	var dealt := health.take_damage(amount, HIT_INVULNERABILITY, global_position - direction)
	if dealt <= 0.0:
		return 0.0

	_flash.flash()
	if direction.length_squared() > 0.01:
		velocity += direction.normalized() * (KNOCKBACK_ON_HIT * _knockback_resistance())

	EventBus.damage_number_requested.emit(global_position, dealt, style)
	EventBus.burst_requested.emit(global_position, _impact_color(), 5, 110.0, 2.8)
	return dealt


## Called by DeathZone. Goes straight to death rather than through take_hit,
## which ignores everything while the room intro is still playing — an enemy
## nudged into the pit before the fight starts should still fall.
func fall_to_death() -> void:
	_die()


## Bosses shrug off most knockback.
func _knockback_resistance() -> float:
	return 1.0


func _impact_color() -> Color:
	return Color("ffd26a")


func _death_color() -> Color:
	return Color("ff4f62")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	combat_enabled = false
	velocity = Vector2.ZERO
	set_collision_layer(0)
	set_collision_mask(0)
	_telegraph.visible = false

	EventBus.burst_requested.emit(
		global_position, Color("ffd26a") if is_elite else _death_color(), 13, 165.0, 4.0
	)
	died.emit(self, coin_reward, is_elite)
	queue_free()


# --- Telegraph helper --------------------------------------------------------


## Draws the red wind-up line that warns the player about an incoming attack.
func _show_telegraph(direction: Vector2, length: float, width: float) -> void:
	_telegraph.points = PackedVector2Array([Vector2.ZERO, direction * length])
	_telegraph.width = width
	_telegraph.visible = true


func _hide_telegraph() -> void:
	_telegraph.visible = false
