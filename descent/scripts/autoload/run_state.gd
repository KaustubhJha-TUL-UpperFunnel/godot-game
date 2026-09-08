extends Node

## Autoload: owns everything scoped to a single run and nothing that outlives it.
##
## GameplayController drives the transitions; the HUD and summary screens read
## from here rather than reaching into gameplay nodes.

signal coins_changed(coins: int)
signal floor_changed(floor_number: int)
signal upgrades_changed()

enum RoomType { STANDARD, LOOT, DANGER, SHOP, BOSS }

const FINAL_FLOOR := LevelLibrary.PLAYABLE_LEVEL_COUNT

const ROOM_TYPE_NAMES := {
	RoomType.STANDARD: "STANDARD CHAMBER",
	RoomType.LOOT: "LOOT CHAMBER",
	RoomType.DANGER: "DANGER CHAMBER",
	RoomType.SHOP: "MERCHANT VAULT",
	RoomType.BOSS: "WARDEN SANCTUM",
}

const DANGER_MODIFIERS: Array[String] = ["OVERCLOCKED", "CROSSFIRE", "SPIKE PULSE"]

var floor_number: int = 1
var coins: int = 0
var echoes_earned: int = 0
var enemies_defeated: int = 0
var coins_collected: int = 0
var danger_rooms_cleared: int = 0

var current_room_type: RoomType = RoomType.STANDARD
var next_room_type: RoomType = RoomType.STANDARD
var danger_modifier: String = ""

## Scene paths from LevelLibrary. The previous one is held only so a floor never
## reuses the level the player just walked out of.
var previous_level_path: String = ""
var current_level_path: String = ""

## upgrade_id -> stacks taken this run.
var run_upgrades: Dictionary = {}

var second_wind_used: bool = false
var victory: bool = false
var echoes_committed: bool = false
var level_audit_active: bool = false
var _debug_floor_override_applied: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin_run() -> void:
	floor_number = 1
	coins = 0
	echoes_earned = 0
	enemies_defeated = 0
	coins_collected = 0
	danger_rooms_cleared = 0
	current_room_type = RoomType.STANDARD
	next_room_type = RoomType.STANDARD
	danger_modifier = ""
	previous_level_path = ""
	current_level_path = ""
	run_upgrades.clear()
	second_wind_used = false
	victory = false
	echoes_committed = false
	_debug_floor_override_applied = false
	apply_debug_floor_override()
	coins_changed.emit(coins)
	floor_changed.emit(floor_number)
	upgrades_changed.emit()


## Development builds can start on a specific sequential map with:
##   Godot --path <project> -- --floor=10
## Release builds always begin on floor one.
func apply_debug_floor_override() -> void:
	if not OS.is_debug_build() or _debug_floor_override_applied:
		return
	_debug_floor_override_applied = true
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--floor="):
			continue
		var value := argument.trim_prefix("--floor=")
		if not value.is_valid_int():
			push_warning("DESCENT: invalid debug floor '%s'" % value)
			return
		floor_number = clampi(value.to_int(), 1, FINAL_FLOOR)
		print("DESCENT debug start: floor %d" % floor_number)
		return


func room_type_name() -> String:
	return ROOM_TYPE_NAMES.get(current_room_type, "STANDARD CHAMBER")


func is_final_floor() -> bool:
	return floor_number >= FINAL_FLOOR


# --- Currency ----------------------------------------------------------------


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_collected += amount
	coins_changed.emit(coins)


func can_afford(price: int) -> bool:
	return coins >= price


func spend_coins(price: int) -> bool:
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	return true


# --- Run upgrades ------------------------------------------------------------


func record_upgrade(upgrade_id: int) -> void:
	run_upgrades[upgrade_id] = upgrade_level(upgrade_id) + 1
	upgrades_changed.emit()


func upgrade_level(upgrade_id: int) -> int:
	return int(run_upgrades.get(upgrade_id, 0))


func has_upgrade(upgrade_id: int) -> bool:
	return upgrade_level(upgrade_id) > 0


# --- Floor flow --------------------------------------------------------------


func advance_floor(destination: RoomType = RoomType.STANDARD) -> void:
	next_room_type = destination
	floor_number = mini(FINAL_FLOOR, floor_number + 1)
	floor_changed.emit(floor_number)


func roll_danger_modifier(rng: RandomNumberGenerator) -> String:
	danger_modifier = DANGER_MODIFIERS[rng.randi_range(0, DANGER_MODIFIERS.size() - 1)]
	return danger_modifier


## Totals the run reward, banks it through SaveManager, and guards against
## being called twice (death and victory can both race to finish a run).
func finish_run(was_victory: bool) -> int:
	if echoes_committed:
		return echoes_earned
	echoes_committed = true
	victory = was_victory
	echoes_earned += (
		floor_number * 3
		+ danger_rooms_cleared * 5
		+ int(enemies_defeated / 4.0)
		+ (25 if was_victory else 0)
	)
	SaveManager.award_echoes(echoes_earned)
	return echoes_earned
