extends Node

## Visible autonomous playthrough of all playable maps. The bot uses the real
## player input/ability APIs, advances only after every enemy is defeated, and
## takes the strongest upgrade offered between floors.

const GAMEPLAY_SCENE := preload("res://descent/scenes/gameplay.tscn")
const BOT_SCRIPT := preload("res://tools/level_audit_bot.gd")
const PLAYER_RADIUS := 17.0

var _gameplay: GameplayController
var _bot: LevelAuditBot
var _paths: Array[String] = []
var _results: Dictionary = {}
var _index: int = -1
var _paused: bool = false
var _finished: bool = false

@onready var _pause: Button = $AuditUI/Controls/Pause
@onready var _exit: Button = $AuditUI/Controls/Exit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.pressed.connect(_toggle_pause)
	_exit.pressed.connect(_return_to_menu)

	RunState.begin_run()
	RunState.level_audit_active = true
	_paths = LevelLibrary.all_paths()

	_gameplay = GAMEPLAY_SCENE.instantiate() as GameplayController
	add_child(_gameplay)
	move_child(_gameplay, 0)

	_bot = BOT_SCRIPT.new() as LevelAuditBot
	add_child(_bot)
	_bot.bind(_gameplay)
	_bot.issue_detected.connect(_on_runtime_issue)

	_gameplay.audit_floor_started.connect(_on_floor_started)
	_gameplay.audit_floor_cleared.connect(_on_floor_cleared)
	_gameplay.audit_upgrade_selected.connect(_on_upgrade_selected)
	_gameplay.audit_issue_reported.connect(_on_runtime_issue)
	_gameplay.audit_completed.connect(_finish_audit)

	# Gameplay's first floor enters the tree before this parent can connect.
	_on_floor_started(RunState.floor_number)


func _on_floor_started(floor_number: int) -> void:
	if _finished:
		return
	_index = clampi(floor_number - 1, 0, maxi(0, _paths.size() - 1))
	var path := RunState.current_level_path
	if not _results.has(path):
		_results[path] = [] as Array[String]

	_bot.set_enabled(true)
	_bot.floor_started()
	print("LEVEL AUDIT: starting floor %02d - %s" % [floor_number, path])
	_write_report()
	_inspect_after_spawn.call_deferred(path)


func _inspect_after_spawn(path: String) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _finished or path != RunState.current_level_path:
		return
	_record_findings(path, _inspect_current_level())


func _on_floor_cleared(floor_number: int) -> void:
	_bot.set_enabled(false)
	var path := RunState.current_level_path
	_record_findings(path, _inspect_current_level())
	print("LEVEL AUDIT: floor %02d cleared" % floor_number)
	_gameplay.audit_select_upgrade_and_continue.call_deferred()


func _on_upgrade_selected(display_name: String) -> void:
	print("LEVEL AUDIT: selected upgrade %s" % display_name)
	_write_report()


func _inspect_current_level() -> Array[String]:
	var findings: Array[String] = []
	var level := _gameplay.level_host.current_level
	if level == null:
		findings.append("FAIL: level scene did not load")
		return findings

	if _index < 0 or _index >= _paths.size():
		findings.append("FAIL: floor index is outside the level catalogue")
	elif RunState.current_level_path != _paths[_index]:
		findings.append("FAIL: loaded path does not match requested floor")
	if LevelLibrary.PLAYABLE_LEVEL_COUNT != _paths.size():
		findings.append(
			"FAIL: expected %d maps but found %d"
			% [LevelLibrary.PLAYABLE_LEVEL_COUNT, _paths.size()]
		)

	if RunState.floor_number == 1:
		if not RunState.run_upgrades.is_empty():
			findings.append("FAIL: audit did not start with zero run upgrades")
		if not is_equal_approx(_gameplay.player.health.maximum, 100.0):
			findings.append("FAIL: permanent health upgrade leaked into starting build")
		if not is_equal_approx(
			_gameplay.player.weapon_damage, _gameplay.player.base_weapon_damage
		):
			findings.append("FAIL: permanent damage upgrade leaked into starting build")
		if not is_equal_approx(_gameplay.player.speed_multiplier, 1.0):
			findings.append("FAIL: permanent speed upgrade leaked into starting build")

	var bounds := level.walkable_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		findings.append("FAIL: walkable bounds are empty")
	if level.spawn_positions().is_empty():
		findings.append("FAIL: no enemy spawn markers")
	if level.safe_spawn_position(level.player_start(), PLAYER_RADIUS) == Vector2.INF:
		findings.append("FAIL: authored player start has no safe floor")
	if level.is_hazardous(_gameplay.player.position, PLAYER_RADIUS):
		findings.append("FAIL: player entered an authored hazard")

	if level.is_vertical():
		if level.platforms().is_empty():
			findings.append("FAIL: vertical map has no platforms")
		if level.death_zones().is_empty():
			findings.append("FAIL: vertical map has no death zone")
		if not _gameplay.living_enemies.is_empty():
			_check_vertical_routes(level, findings)
	elif level.kind == Level.Kind.VERTICAL:
		findings.append("WARN: vertical metadata fell back to flat movement")

	for enemy in _gameplay.living_enemies:
		if not is_instance_valid(enemy):
			findings.append("FAIL: encounter contains an invalid enemy")
		elif level.is_hazardous(enemy.position, enemy.projectile_radius):
			findings.append("FAIL: enemy entered an authored hazard")

	_check_spawn_spacing(level.spawn_positions(), findings)
	return findings


func _check_vertical_routes(level: Level, findings: Array[String]) -> void:
	var player_platform := level.supporting_platform(
		_gameplay.player.position, PLAYER_RADIUS, 90.0
	)
	if player_platform == null:
		findings.append("WARN: player currently has no supporting platform")
		return
	for enemy in _gameplay.living_enemies:
		var enemy_platform := level.supporting_platform(
			enemy.position, enemy.projectile_radius, 90.0
		)
		if enemy_platform == null:
			findings.append("WARN: enemy currently has no supporting platform")
			continue
		if (
			enemy_platform != player_platform
			and level.next_platform_toward(
				player_platform,
				enemy_platform,
				42.0,
				220.0,
				420.0
			) == null
		):
			findings.append("WARN: enemy has no authored platform route from player")


func _check_spawn_spacing(spawns: Array[Vector2], findings: Array[String]) -> void:
	for first in spawns.size():
		for second in range(first + 1, spawns.size()):
			if spawns[first].distance_to(spawns[second]) < 32.0:
				findings.append("WARN: enemy spawn markers overlap")
				return


func _record_findings(path: String, incoming: Array[String]) -> void:
	if path.is_empty():
		return
	var findings: Array[String] = _results.get(path, [] as Array[String])
	for finding in incoming:
		if not findings.has(finding):
			findings.append(finding)
			print("LEVEL AUDIT %s: %s" % [path.get_file(), finding])
	_results[path] = findings
	_write_report()


func _on_runtime_issue(message: String) -> void:
	_record_findings(RunState.current_level_path, [message])


func _toggle_pause() -> void:
	_paused = not _paused
	_bot.set_enabled(not _paused)
	get_tree().paused = _paused
	_pause.text = "RESUME AUDIT" if _paused else "PAUSE AUDIT"


func _finish_audit() -> void:
	_finished = true
	_bot.set_enabled(false)
	var failed_levels := 0
	var warning_levels := 0
	for path: String in _results:
		var findings: Array = _results[path]
		var failed := false
		var warned := false
		for finding: String in findings:
			failed = failed or finding.begins_with("FAIL:")
			warned = warned or finding.begins_with("WARN:")
		failed_levels += 1 if failed else 0
		warning_levels += 1 if warned else 0

	_pause.text = "AUDIT COMPLETE"
	_pause.disabled = true
	_write_report()
	print("LEVEL AUDIT: all %d levels cleared" % _results.size())


func _total_upgrade_stacks() -> int:
	var total := 0
	for upgrade_id: int in RunState.run_upgrades:
		total += RunState.upgrade_level(upgrade_id)
	return total


func _write_report() -> void:
	var lines: Array[String] = [
		"DESCENT AUTONOMOUS LEVEL AUDIT",
		"Maps visited: %d / %d" % [_results.size(), _paths.size()],
		"Current floor: %d" % RunState.floor_number,
		"Completed: %s" % str(_finished),
		"Starting build: 0 upgrades",
		"Final upgrade stacks: %d" % _total_upgrade_stacks(),
		"",
	]
	for path: String in _paths:
		if not _results.has(path):
			continue
		var findings: Array = _results[path]
		lines.append(path)
		if findings.is_empty():
			lines.append("  PASS")
		else:
			for finding: String in findings:
				lines.append("  %s" % finding)
		lines.append("")

	var file := FileAccess.open("user://level_audit_report.txt", FileAccess.WRITE)
	if file == null:
		push_error("LEVEL AUDIT: could not write report")
		return
	file.store_string("\n".join(lines))
	file.close()


func _return_to_menu() -> void:
	_paused = false
	get_tree().paused = false
	RunState.level_audit_active = false
	SceneRouter.goto_main_menu()


func _exit_tree() -> void:
	RunState.level_audit_active = false
