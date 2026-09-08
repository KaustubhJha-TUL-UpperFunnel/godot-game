class_name LevelAuditBot
extends Node

## Drives the real PlayerAvatar through its normal touch-input and ability APIs.
## The bot fights, dodges nearby threats, and uses the platform graph instead
## of teleporting, so a disconnected or badly authored map remains observable.

signal status_changed(message: String)
signal issue_detected(message: String)

const STICK_RADIUS := PlayerInput.TOUCH_STICK_RADIUS
const MELEE_DISTANCE := 76.0
const FIRE_MIN_DISTANCE := 95.0
const DODGE_RADIUS := 155.0
const STUCK_SAMPLE_SECONDS := 2.5
const STUCK_DISTANCE := 18.0
const ACTION_INTERVAL := 0.18
const DROP_HOLD_SECONDS := 0.32
const MIN_DASH_INTERVAL := 2.4

var enabled: bool = true

var _gameplay: GameplayController
var _player: PlayerAvatar
var _level: Level
var _target: EnemyBase
var _action_time: float = 0.0
var _dash_lockout: float = 0.0
var _drop_hold_left: float = 0.0
var _issue_cooldown: float = 0.0
var _stuck_time: float = 0.0
var _last_sample_position: Vector2 = Vector2.ZERO
var _stuck_reports: int = 0


func bind(gameplay: GameplayController) -> void:
	_gameplay = gameplay
	_player = gameplay.player
	_on_floor_started()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_stop_input()


func _physics_process(delta: float) -> void:
	if (
		not enabled
		or _gameplay == null
		or _player == null
		or _player.is_dead
		or _gameplay.state != GameplayController.State.COMBAT
	):
		_stop_input()
		return

	_level = _gameplay.level_host.current_level
	_target = _pick_target()
	if _level == null or _target == null:
		_stop_input()
		return

	_action_time = maxf(0.0, _action_time - delta)
	_dash_lockout = maxf(0.0, _dash_lockout - delta)
	_issue_cooldown = maxf(0.0, _issue_cooldown - delta)
	var desired := _desired_movement(_target)
	if _drop_hold_left > 0.0:
		_drop_hold_left = maxf(0.0, _drop_hold_left - delta)
		_player.input.set_touch_state(Vector2(0.0, STICK_RADIUS), Vector2.ZERO, false)
		_player.input.touch_attack = false
		_use_survival_items()
		status_changed.emit("HOLDING DOWN TO DROP")
		return

	var dodge := _dodge_direction()
	if dodge.length_squared() > 0.01:
		desired = (desired * 0.35 + dodge * 1.25).normalized()
		_try_dash(dodge)
		status_changed.emit("DODGING THREATS")

	desired = _avoid_authored_hazards(desired)
	var aim := _target.global_position - _player.global_position
	_player.input.set_touch_state(desired * STICK_RADIUS, aim, false)

	var distance := aim.length()
	_player.input.touch_attack = distance <= MELEE_DISTANCE and _same_platform(_target)
	_use_survival_items()
	_use_combat_abilities(distance)
	_tick_stuck_recovery(delta, desired)


func _pick_target() -> EnemyBase:
	var best: EnemyBase = null
	var best_score := INF
	for enemy in _gameplay.living_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var score := _player.global_position.distance_squared_to(enemy.global_position)
		if _level != null and _level.is_vertical():
			var player_platform := _level.supporting_platform(_player.position, 17.0, 80.0)
			var enemy_platform := _level.supporting_platform(
				enemy.position, enemy.projectile_radius, 80.0
			)
			if player_platform != null and enemy_platform != null and player_platform != enemy_platform:
				var route := _level.next_platform_toward(
					player_platform, enemy_platform, 42.0, 220.0, 420.0
				)
				if route == null:
					score += 10000000.0
		if score < best_score:
			best = enemy
			best_score = score
	return best


func _desired_movement(enemy: EnemyBase) -> Vector2:
	var offset := enemy.global_position - _player.global_position
	if not _level.is_vertical():
		if offset.length() <= MELEE_DISTANCE * 0.82:
			return -offset.normalized() * 0.2
		return offset.normalized()
	return _vertical_movement(enemy, offset)


func _vertical_movement(enemy: EnemyBase, offset: Vector2) -> Vector2:
	var player_platform := _level.supporting_platform(_player.position, 17.0, 85.0)
	var enemy_platform := _level.supporting_platform(
		enemy.position, enemy.projectile_radius, 85.0
	)
	if player_platform == null:
		_try_air_climb()
		return Vector2(signf(offset.x), 0.0)
	if enemy_platform == null or player_platform == enemy_platform:
		return Vector2(signf(offset.x), 0.0) if absf(offset.x) > 42.0 else Vector2.ZERO

	var direct_drop := _direct_drop_movement(player_platform, enemy_platform)
	if direct_drop != Vector2.INF:
		return direct_drop
	if enemy.position.y > _player.position.y + 24.0:
		var lower_platform := _nearest_lower_overlapping_platform(player_platform)
		if lower_platform != null:
			var staged_drop := _direct_drop_movement(player_platform, lower_platform)
			if staged_drop != Vector2.INF:
				return staged_drop

	var next_platform := _level.next_platform_toward(
		player_platform, enemy_platform, 42.0, 220.0, 420.0
	)
	if next_platform == null:
		_report_stuck("no authored platform route to target")
		# Do not repeat jump/dash forever when the platform graph says there is
		# no route. Hold position and let ranged attacks continue the clear.
		return Vector2.ZERO

	var from_range := player_platform.navigation_x_range()
	var next_range := next_platform.navigation_x_range()
	var left := maxf(from_range.x, next_range.x)
	var right := minf(from_range.y, next_range.y)
	var target_x := (
		(left + right) * 0.5
		if right >= left
		else clampf(_player.position.x, next_range.x, next_range.y)
	)
	var next_surface := next_platform.surface_y_at(
		clampf(target_x, next_range.x, next_range.y), 8.0
	)
	var current_surface := player_platform.surface_y_at(
		clampf(target_x, from_range.x, from_range.y), 8.0
	)
	var horizontal := signf(target_x - _player.position.x)

	if next_surface < current_surface - 18.0:
		if absf(target_x - _player.position.x) <= 48.0:
			_try_jump_or_dash()
		return Vector2(horizontal, -0.15)

	if next_surface > current_surface + 24.0:
		if absf(target_x - _player.position.x) <= 44.0 and _player.is_on_floor():
			return Vector2(0.0, 1.0)
		return Vector2(horizontal, 0.15)

	return Vector2(horizontal, 0.0)


func _direct_drop_movement(
	player_platform: LevelPlatform, enemy_platform: LevelPlatform
) -> Vector2:
	var from_range := player_platform.navigation_x_range()
	var enemy_range := enemy_platform.navigation_x_range()
	var left := maxf(from_range.x, enemy_range.x)
	var right := minf(from_range.y, enemy_range.y)
	if right - left < 38.0:
		return Vector2.INF

	var sample_x := (left + right) * 0.5
	var from_surface := player_platform.surface_y_at(sample_x, 8.0)
	var enemy_surface := enemy_platform.surface_y_at(sample_x, 8.0)
	if is_inf(from_surface) or is_inf(enemy_surface) or enemy_surface <= from_surface + 24.0:
		return Vector2.INF

	var horizontal_distance := sample_x - _player.position.x
	if absf(horizontal_distance) > 34.0:
		status_changed.emit("ALIGNING ABOVE LOWER ENEMY")
		return Vector2(signf(horizontal_distance), 0.0)
	if _player.is_on_floor():
		_drop_hold_left = DROP_HOLD_SECONDS
		status_changed.emit("DROPPING TO ENEMY BELOW")
		return Vector2(0.0, 1.0)
	return Vector2.ZERO


func _nearest_lower_overlapping_platform(
	player_platform: LevelPlatform
) -> LevelPlatform:
	var from_range := player_platform.navigation_x_range()
	var current_surface := player_platform.surface_y_at(
		clampf(_player.position.x, from_range.x, from_range.y), 8.0
	)
	var best: LevelPlatform = null
	var best_drop := INF
	for platform in _level.platforms():
		if platform == player_platform:
			continue
		var candidate_range := platform.navigation_x_range()
		var left := maxf(from_range.x, candidate_range.x)
		var right := minf(from_range.y, candidate_range.y)
		if right - left < 38.0:
			continue
		var sample_x := (left + right) * 0.5
		var candidate_surface := platform.surface_y_at(sample_x, 8.0)
		var drop := candidate_surface - current_surface
		if drop > 24.0 and drop < best_drop:
			best = platform
			best_drop = drop
	return best


func _try_jump_or_dash() -> void:
	if _action_time > 0.0:
		return
	if _player.is_on_floor():
		_action_time = ACTION_INTERVAL
		_player.input.request_touch_jump()
		status_changed.emit("JUMPING TO NEXT PLATFORM")
		return
	_try_air_climb()


func _try_air_climb() -> void:
	if _action_time > 0.0:
		return
	_action_time = ACTION_INTERVAL
	_player.input.request_touch_jump()
	# Upward dash is the fallback when the contextual climb cannot quite reach.
	_player.input.touch_move = Vector2(0.0, -STICK_RADIUS)
	if _dash_lockout <= 0.0 and _player.dash_ready_ratio() >= 0.999:
		if _player.start_dash():
			_dash_lockout = MIN_DASH_INTERVAL
	status_changed.emit("CLIMBING BETWEEN PLATFORMS")


func _dodge_direction() -> Vector2:
	var danger := Vector2.ZERO
	var projectiles := _gameplay.get_node("Actors/Projectiles")
	for child in projectiles.get_children():
		var projectile := child as Projectile
		if projectile == null or projectile.friendly:
			continue
		var away := _player.global_position - projectile.global_position
		var distance := away.length()
		if distance > 0.01 and distance < DODGE_RADIUS:
			danger += away.normalized() * (1.0 - distance / DODGE_RADIUS)

	var hazards := _gameplay.get_node("Actors/Hazards")
	for child in hazards.get_children():
		var hazard := child as Hazard
		if hazard == null:
			continue
		var away := _player.global_position - hazard.global_position
		var danger_distance := hazard.radius + 55.0
		if away.length() < danger_distance:
			danger += away.normalized() * 1.5

	for enemy in _gameplay.living_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var away := _player.global_position - enemy.global_position
		if away.length() > 0.01 and away.length() < 62.0:
			danger += away.normalized() * 0.65
	return danger.normalized() if danger.length_squared() > 0.01 else Vector2.ZERO


func _avoid_authored_hazards(desired: Vector2) -> Vector2:
	if desired.length_squared() <= 0.01 or _level == null:
		return desired
	var ahead := _player.position + desired.normalized() * 58.0
	if not _level.is_hazardous(ahead, 17.0):
		return desired.normalized()
	for angle in [PI * 0.5, -PI * 0.5, PI]:
		var candidate := desired.rotated(angle).normalized()
		if not _level.is_hazardous(_player.position + candidate * 58.0, 17.0):
			status_changed.emit("AVOIDING MAP HAZARD")
			return candidate
	return Vector2.ZERO


func _try_dash(direction: Vector2) -> void:
	if (
		_action_time > 0.0
		or _dash_lockout > 0.0
		or _player.dash_ready_ratio() < 0.999
	):
		return
	_action_time = ACTION_INTERVAL
	_player.input.touch_move = direction * STICK_RADIUS
	if _player.start_dash():
		_dash_lockout = MIN_DASH_INTERVAL


func _use_survival_items() -> void:
	if _player.health.ratio() < 0.42 and _player.health_potions > 0:
		_player.use_health_potion()
	if _player.mana.current < 9.0 and _player.mana_potions > 0:
		_player.use_mana_potion()


func _use_combat_abilities(distance: float) -> void:
	if _action_time > 0.0:
		return
	var nearby := 0
	for enemy in _gameplay.living_enemies:
		if (
			is_instance_valid(enemy)
			and not enemy.is_dead
			and enemy.global_position.distance_to(_player.global_position)
				<= PlayerAvatar.ICE_RADIUS + enemy.projectile_radius
		):
			nearby += 1
	if nearby >= 2 and _player.slot_cooldown_ratio(PlayerAvatar.Slot.ICE) <= 0.001:
		if _player.cast_frost_nova():
			_action_time = ACTION_INTERVAL
			status_changed.emit("CASTING FROST NOVA")
			return
	if (
		(distance >= FIRE_MIN_DISTANCE or not _same_platform(_target))
		and _player.slot_cooldown_ratio(PlayerAvatar.Slot.FIRE) <= 0.001
		and _player.mana.has(PlayerAvatar.FIRE_COST)
	):
		if _player.begin_projectile_aim():
			_player.release_projectile_aim()
			_action_time = ACTION_INTERVAL
			status_changed.emit("CASTING FIREBALL")


func _same_platform(enemy: EnemyBase) -> bool:
	if _level == null or not _level.is_vertical():
		return true
	var player_platform := _level.supporting_platform(_player.position, 17.0, 75.0)
	var enemy_platform := _level.supporting_platform(
		enemy.position, enemy.projectile_radius, 75.0
	)
	return (
		player_platform != null
		and enemy_platform != null
		and (
			player_platform == enemy_platform
			or _level.platforms_share_route(player_platform, enemy_platform)
		)
	)


func _tick_stuck_recovery(delta: float, desired: Vector2) -> void:
	if desired.length_squared() <= 0.01:
		_stuck_time = 0.0
		_last_sample_position = _player.position
		return
	_stuck_time += delta
	if _stuck_time < STUCK_SAMPLE_SECONDS:
		return
	var travelled := _player.position.distance_to(_last_sample_position)
	_stuck_time = 0.0
	_last_sample_position = _player.position
	if travelled >= STUCK_DISTANCE:
		_stuck_reports = 0
		return
	_stuck_reports += 1
	_try_jump_or_dash()
	if _stuck_reports >= 2:
		_report_stuck("bot made no movement progress")


func _report_stuck(reason: String) -> void:
	if _issue_cooldown > 0.0:
		return
	_issue_cooldown = 2.0
	var message := "WARN: %s at %s" % [reason, str(_player.position.round())]
	issue_detected.emit(message)
	status_changed.emit(reason.to_upper())


func _on_floor_started() -> void:
	_level = _gameplay.level_host.current_level if _gameplay != null else null
	_target = null
	_action_time = 0.0
	_dash_lockout = 0.0
	_drop_hold_left = 0.0
	_issue_cooldown = 0.0
	_stuck_time = 0.0
	_stuck_reports = 0
	_last_sample_position = _player.position if _player != null else Vector2.ZERO
	status_changed.emit("SEEKING ENEMIES")


func floor_started() -> void:
	_on_floor_started()


func _stop_input() -> void:
	if _player == null:
		return
	_player.input.set_touch_state(Vector2.ZERO, Vector2.ZERO, false)
	_player.input.touch_attack = false
