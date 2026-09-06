class_name GameplayController
extends Node2D

## The run loop. Owns the room state machine and is the single place that
## wires actors to UI:
##
##   intro -> combat -> cleared -> upgrade -> transition -> next floor...
##
## Actors never talk to the HUD and the HUD never reaches into the level;
## everything crosses through here or through EventBus.

enum State { INTRO, COMBAT, CLEARED, REWARD, TRANSITION, FINISHED }

const INTRO_SECONDS := 1.05
const CLEARED_SECONDS := 0.8
const UPGRADE_OFFER_COUNT := 3
const SECOND_WIND_FRACTION := 0.5

const FIREBALL_SPREAD := 0.16
const ENEMY_SHOT_SPEED := 340.0
const CROSSFIRE_SPREAD := 0.32
const SPIKE_PULSE_INTERVAL := 3.4
const SPIKE_PULSE_RADIUS := 62.0
const SPIKE_PULSE_DAMAGE := 14.0
const DANGER_COIN_MULTIPLIER := 2

const DEBUG_HURT_AMOUNT := 25.0
const DEBUG_HEAL_AMOUNT := 30.0
const DEBUG_COIN_GRANT := 50
const DEBUG_ECHO_GRANT := 100

@export var projectile_scene: PackedScene
@export var hazard_scene: PackedScene

var state: State = State.INTRO
var living_enemies: Array[EnemyBase] = []

var _rng := RandomNumberGenerator.new()
var _spike_pulse_timer: float = 0.0
@onready var level_host: LevelHost = $LevelHost
@onready var player: PlayerAvatar = $Actors/Player
@onready var _enemies: Node2D = $Actors/Enemies
@onready var _projectiles: Node2D = $Actors/Projectiles
@onready var _hazards: Node2D = $Actors/Hazards
@onready var _spawn_director: SpawnDirector = $Systems/SpawnDirector
@onready var _upgrades: UpgradeCatalog = $Systems/UpgradeCatalog

@onready var _camera: Camera2D = $Camera

@onready var _intro_timer: Timer = $Timers/IntroTimer
@onready var _cleared_timer: Timer = $Timers/ClearedTimer

@onready var _hud: Hud = $UI/Hud
@onready var _hotbar: Hotbar = $UI/Hotbar
@onready var _upgrade_selection: UpgradeSelection = $UI/UpgradeSelection
@onready var _announcement: Announcement = $UI/Announcement
@onready var _touch_controls: TouchControls = $UI/TouchControls
@onready var _pause_menu: PauseMenu = $UI/PauseMenu
@onready var _run_summary: RunSummary = $UI/RunSummary
@onready var _floor_transition: FloorTransition = $TransitionLayer/FloorTransition


func _ready() -> void:
	_rng.randomize()
	_connect_player()
	_connect_ui()

	player.reset_for_run(
		SaveManager.starting_max_health(),
		SaveManager.damage_multiplier(),
		SaveManager.speed_multiplier()
	)
	_hud.bind(player, _upgrades)
	_hotbar.bind(player)
	_touch_controls.bind(player.input)

	begin_room()


func _connect_player() -> void:
	player.fireball_cast.connect(_on_fireball_cast)
	player.frost_nova_cast.connect(_on_frost_nova_cast)
	player.died.connect(_on_player_died)


func _connect_ui() -> void:
	_intro_timer.timeout.connect(_on_intro_finished)
	_cleared_timer.timeout.connect(_on_cleared_finished)
	_upgrade_selection.upgrade_chosen.connect(_on_upgrade_chosen)
	_pause_menu.pause_requested.connect(_set_paused.bind(true))
	_pause_menu.resume_requested.connect(_set_paused.bind(false))
	_pause_menu.abandon_requested.connect(_on_abandon_requested)
	_run_summary.continue_requested.connect(func() -> void: SceneRouter.goto_main_menu())


# --- Room lifecycle ----------------------------------------------------------


## Builds the room for the current floor and starts the appropriate state.
func begin_room() -> void:
	_clear_transient_nodes()
	_touch_controls.reset_controls()

	RunState.current_room_type = RunState.RoomType.STANDARD
	RunState.next_room_type = RunState.RoomType.STANDARD
	RunState.danger_modifier = ""

	_load_level()
	player.position = level_host.player_start()
	player.restore_full_health()
	player.prepare_floor_spawn()
	player.refill_floor_charges()
	_hud.refresh_room_header()
	_hud.hide_boss()
	_spike_pulse_timer = SPIKE_PULSE_INTERVAL
	_enter_encounter()


## Loads this floor's map in sequence, then fits the camera and player bounds.
func _load_level() -> void:
	var path := LevelLibrary.path_for_floor(RunState.floor_number)
	RunState.previous_level_path = path
	RunState.current_level_path = path
	level_host.load_level(path)

	_frame_level()
	player.configure_level(level_host.current_level)
	player.movement_bounds = level_host.walkable_bounds()


## Levels are authored in their map's own pixel space, which is larger than the
## viewport, so the camera zooms out to frame the whole room rather than every
## level being redrawn to fit the window.
func _frame_level() -> void:
	var content := level_host.content_size()
	if content.x <= 0.0 or content.y <= 0.0:
		return
	var viewport := get_viewport_rect().size
	var fit := minf(viewport.x / content.x, viewport.y / content.y)
	_camera.zoom = Vector2(fit, fit)
	_camera.position = content * 0.5


func _enter_encounter() -> void:
	living_enemies = _spawn_director.populate(level_host, player, _enemies, _rng)
	for enemy in living_enemies:
		_bind_enemy(enemy)

	_hud.set_enemies_remaining(living_enemies.size())
	state = State.INTRO
	player.set_control_enabled(true, false)
	_announcement.announce(
		"FLOOR %d" % RunState.floor_number,
		_intro_subtitle(),
		_intro_accent(),
		INTRO_SECONDS * 0.7
	)
	_intro_timer.start(INTRO_SECONDS)


func _intro_subtitle() -> String:
	return "MAP %02d" % RunState.floor_number


func _intro_accent() -> Color:
	return Color("e2ae52")


func _on_intro_finished() -> void:
	if state != State.INTRO:
		return
	state = State.COMBAT
	player.set_control_enabled(true, true)
	for enemy in living_enemies:
		enemy.set_combat_enabled(true)
	if living_enemies.is_empty():
		_on_room_cleared()


func _on_enemy_died(enemy: EnemyBase, coin_reward: int, was_elite: bool) -> void:
	living_enemies.erase(enemy)
	RunState.enemies_defeated += 1

	RunState.add_coins(coin_reward)
	if was_elite:
		RunState.echoes_earned += 1

	if state != State.COMBAT:
		return
	_hud.set_enemies_remaining(living_enemies.size())
	if living_enemies.is_empty():
		_on_room_cleared()


func _on_room_cleared() -> void:
	state = State.CLEARED
	player.set_control_enabled(true, false)
	_upgrades.apply_room_clear_effects(player)
	player.restore_full_health()
	_despawn_hostile_projectiles()
	_hud.show_objective("")
	_announcement.announce("FLOOR CLEARED", _clear_subtitle(), Color("6fd3a5"), CLEARED_SECONDS)
	_cleared_timer.start(CLEARED_SECONDS)


func _clear_subtitle() -> String:
	return "CHOOSE AN UPGRADE"


func _on_cleared_finished() -> void:
	if state != State.CLEARED:
		return
	_enter_reward()


func _enter_reward() -> void:
	state = State.REWARD
	player.set_control_enabled(false, false)
	_upgrade_selection.present(_upgrades.draw_offers(UPGRADE_OFFER_COUNT, _rng))


func _on_upgrade_chosen(upgrade: UpgradeData) -> void:
	_upgrades.apply(upgrade, player)
	player.restore_full_health()
	_upgrade_selection.dismiss()
	if RunState.is_final_floor():
		_finish_run(true)
		return
	state = State.TRANSITION
	player.set_control_enabled(false, false)

	RunState.advance_floor()
	await _floor_transition.play(RunState.floor_number)
	begin_room()


# --- Combat plumbing ---------------------------------------------------------


func _bind_enemy(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.shot_requested.connect(_on_enemy_shot_requested)
	enemy.hazard_requested.connect(_on_hazard_requested)


func _physics_process(delta: float) -> void:
	if state != State.COMBAT:
		return
	_apply_contact_damage()
	_tick_spike_pulse(delta)


## Enemies have no hitbox of their own; standing inside one hurts, and the
## player's own invulnerability window keeps it from draining health per frame.
func _apply_contact_damage() -> void:
	if player.is_dead:
		return
	for enemy in living_enemies:
		if enemy.is_dead:
			continue
		if enemy.has_method("can_damage_player") and not bool(enemy.call(&"can_damage_player")):
			continue
		if player.global_position.distance_to(enemy.global_position) <= enemy.contact_radius:
			player.take_damage(enemy.contact_damage, enemy.global_position)
			return


## SPIKE PULSE danger modifier: the floor itself starts erupting.
func _tick_spike_pulse(delta: float) -> void:
	if RunState.danger_modifier != "SPIKE PULSE":
		return
	_spike_pulse_timer -= delta
	if _spike_pulse_timer > 0.0:
		return
	_spike_pulse_timer = SPIKE_PULSE_INTERVAL
	var bounds := level_host.walkable_bounds()
	var requested := Vector2(
		_rng.randf_range(bounds.position.x + 70.0, bounds.end.x - 70.0),
		_rng.randf_range(bounds.position.y + 40.0, bounds.end.y - 40.0)
	)
	var safe := level_host.safe_spawn_position(requested, SPIKE_PULSE_RADIUS)
	if safe != Vector2.INF:
		_spawn_hazard(safe, SPIKE_PULSE_RADIUS, SPIKE_PULSE_DAMAGE)


func _on_fireball_cast(origin: Vector2, direction: Vector2, damage: float) -> void:
	var count := player.projectile_count
	var speed := PlayerAvatar.FIRE_PROJECTILE_SPEED * player.projectile_speed_multiplier
	# Fan the extra bolts symmetrically around the aim direction.
	var base_angle := direction.angle() - FIREBALL_SPREAD * float(count - 1) * 0.5

	for index in count:
		var heading := Vector2.from_angle(base_angle + FIREBALL_SPREAD * float(index))
		var ricochets := 1 if _rng.randf() < player.ricochet_chance else 0
		_spawn_projectile(
			true, origin, heading * speed, damage, player.projectile_pierce, ricochets,
			Projectile.Element.FIRE
		)


func _on_frost_nova_cast(origin: Vector2, radius: float, damage: float) -> void:
	for enemy in living_enemies.duplicate():
		if enemy.is_dead:
			continue
		if origin.distance_to(enemy.global_position) > radius + enemy.projectile_radius:
			continue
		enemy.take_hit(damage, enemy.global_position - origin, EventBus.DamageStyle.ICE)


func _on_enemy_shot_requested(origin: Vector2, direction: Vector2, damage: float) -> void:
	_spawn_projectile(false, origin, direction.normalized() * ENEMY_SHOT_SPEED, damage)

	if RunState.danger_modifier != "CROSSFIRE":
		return
	for offset in [-CROSSFIRE_SPREAD, CROSSFIRE_SPREAD]:
		_spawn_projectile(
			false,
			origin,
			direction.normalized().rotated(offset) * ENEMY_SHOT_SPEED,
			damage * 0.7
		)


func _on_hazard_requested(origin: Vector2, radius: float) -> void:
	_spawn_hazard(origin, radius, SPIKE_PULSE_DAMAGE)


func _spawn_projectile(
	friendly: bool,
	origin: Vector2,
	shot_velocity: Vector2,
	damage: float,
	pierce: int = 0,
	ricochets: int = 0,
	element: Projectile.Element = Projectile.Element.PLAIN
) -> void:
	if projectile_scene == null:
		return
	var bolt: Projectile = projectile_scene.instantiate()
	bolt.bounds = level_host.walkable_bounds().grow(30.0)
	bolt.setup(friendly, origin, shot_velocity, damage, pierce, ricochets, element)
	_projectiles.add_child(bolt)


func _spawn_hazard(origin: Vector2, radius: float, damage: float) -> void:
	if hazard_scene == null:
		return
	var hazard: Hazard = hazard_scene.instantiate()
	hazard.setup(origin, radius, damage)
	_hazards.add_child(hazard)


func _despawn_hostile_projectiles() -> void:
	for child in _projectiles.get_children():
		var bolt: Projectile = child
		if not bolt.friendly:
			bolt.queue_free()


func _clear_transient_nodes() -> void:
	living_enemies.clear()
	for group: Node2D in [_enemies, _projectiles, _hazards]:
		for child in group.get_children():
			child.queue_free()


# --- Run end -----------------------------------------------------------------


func _on_player_died() -> void:
	if state == State.FINISHED:
		return
	if SaveManager.has_second_wind() and not RunState.second_wind_used:
		RunState.second_wind_used = true
		player.revive(SECOND_WIND_FRACTION)
		# Reviving where you died would put the knight back inside the pit that
		# killed him, with no floor to land on.
		if level_host.is_vertical():
			player.position = level_host.player_start()
		player.set_control_enabled(true, state == State.COMBAT)
		EventBus.toast_requested.emit("SECOND WIND", 2.0)
		EventBus.shake_requested.emit(10.0, 0.35)
		return
	_finish_run(false)


func _finish_run(victory: bool) -> void:
	state = State.FINISHED
	player.set_control_enabled(false, false)
	for enemy in living_enemies:
		enemy.set_combat_enabled(false)
	_upgrade_selection.dismiss()
	_hud.show_objective("")

	RunState.finish_run(victory)
	_run_summary.present(victory)


func _on_abandon_requested() -> void:
	_set_paused(false)
	_finish_run(false)


# --- Input -------------------------------------------------------------------


func _set_paused(paused: bool) -> void:
	if state == State.FINISHED:
		return
	get_tree().paused = paused
	if paused:
		_pause_menu.open()
	else:
		_pause_menu.close()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if OS.is_debug_build():
		_handle_debug_input(event)


## Debug shortcuts (F1-F7) are compiled into debug builds only.
func _handle_debug_input(event: InputEvent) -> void:
	if event.is_action(&"debug_clear_room"):
		for enemy in living_enemies.duplicate():
			enemy.take_hit(99999.0, Vector2.RIGHT)
	elif event.is_action(&"debug_hurt"):
		player.take_damage(DEBUG_HURT_AMOUNT, player.global_position + Vector2.LEFT)
	elif event.is_action(&"debug_heal"):
		player.heal(DEBUG_HEAL_AMOUNT)
	elif event.is_action(&"debug_add_coins"):
		RunState.add_coins(DEBUG_COIN_GRANT)
	elif event.is_action(&"debug_add_echoes"):
		SaveManager.award_echoes(DEBUG_ECHO_GRANT)
	elif event.is_action(&"debug_next_floor"):
		if state != State.FINISHED:
			if RunState.is_final_floor():
				_finish_run(true)
			else:
				RunState.advance_floor()
				begin_room()
	elif event.is_action(&"debug_reset_save"):
		SaveManager.reset_progress()
