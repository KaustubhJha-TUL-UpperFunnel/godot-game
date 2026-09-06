extends Node

## Autoload: owns everything that survives a run.
##
## Persists to user://descent_save_v1.json through a temp-file swap so a crash
## mid-write cannot corrupt an existing save. Anything read off disk is
## validated before it is trusted; malformed saves fall back to defaults.

signal echoes_changed(total: int)
signal permanent_changed(index: int, level: int)

const SAVE_PATH := "user://descent_save_v1.json"
const TEMP_PATH := "user://descent_save_v1.tmp"
const BACKUP_PATH := "user://descent_save_v1.backup"
const SCHEMA_VERSION := 1
const MAX_ECHOES := 100000000

enum Track { REINFORCED_ARMOR, SHARPENED_BLADE, SWIFT_BOOTS, RICOCHET_RUNES, SECOND_WIND }

## Display copy and cost curve for the permanent upgrade tracks shown in the
## main menu. Index order must match the Track enum.
const TRACKS: Array = [
	{
		"name": "REINFORCED ARMOR",
		"description": "+5 starting maximum health",
		"base_cost": 18,
		"max_level": 5,
	},
	{
		"name": "SHARPENED BLADE",
		"description": "+5% starting weapon damage",
		"base_cost": 22,
		"max_level": 5,
	},
	{
		"name": "SWIFT BOOTS",
		"description": "+5% starting movement speed",
		"base_cost": 20,
		"max_level": 5,
	},
	{
		"name": "RICOCHET RUNES",
		"description": "Unlock Ricochet Core in run upgrades",
		"base_cost": 42,
		"max_level": 1,
	},
	{
		"name": "SECOND WIND",
		"description": "Unlock one revive per run",
		"base_cost": 58,
		"max_level": 1,
	},
]

var echoes_total: int = 0
var permanent_levels: Array[int] = [0, 0, 0, 0, 0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


# --- Progression queries -----------------------------------------------------


func track_count() -> int:
	return TRACKS.size()


func max_level(index: int) -> int:
	return TRACKS[index]["max_level"]


func level(index: int) -> int:
	return permanent_levels[index]


func is_maxed(index: int) -> bool:
	return permanent_levels[index] >= max_level(index)


func cost(index: int) -> int:
	return TRACKS[index]["base_cost"] * (permanent_levels[index] + 1)


func can_afford(index: int) -> bool:
	return not is_maxed(index) and echoes_total >= cost(index)


func starting_max_health() -> float:
	return 100.0 + float(permanent_levels[Track.REINFORCED_ARMOR]) * 5.0


func damage_multiplier() -> float:
	return 1.0 + float(permanent_levels[Track.SHARPENED_BLADE]) * 0.05


func speed_multiplier() -> float:
	return 1.0 + float(permanent_levels[Track.SWIFT_BOOTS]) * 0.05


func has_ricochet_unlock() -> bool:
	return permanent_levels[Track.RICOCHET_RUNES] > 0


func has_second_wind() -> bool:
	return permanent_levels[Track.SECOND_WIND] > 0


# --- Mutations ---------------------------------------------------------------


func award_echoes(amount: int) -> void:
	if amount <= 0:
		return
	echoes_total = clampi(echoes_total + amount, 0, MAX_ECHOES)
	echoes_changed.emit(echoes_total)
	save_game()


func buy_permanent(index: int) -> bool:
	if index < 0 or index >= TRACKS.size():
		return false
	if is_maxed(index):
		EventBus.toast_requested.emit("ALREADY MAXED", 1.2)
		return false
	var price := cost(index)
	if echoes_total < price:
		EventBus.toast_requested.emit("NOT ENOUGH ECHOES", 1.2)
		return false
	echoes_total -= price
	permanent_levels[index] += 1
	echoes_changed.emit(echoes_total)
	permanent_changed.emit(index, permanent_levels[index])
	save_game()
	EventBus.toast_requested.emit("PERMANENT UPGRADE INSTALLED", 1.4)
	return true


func reset_progress() -> void:
	echoes_total = 0
	permanent_levels = [0, 0, 0, 0, 0]
	echoes_changed.emit(echoes_total)
	for index in TRACKS.size():
		permanent_changed.emit(index, 0)
	save_game()


# --- Disk ---------------------------------------------------------------------


func load_game() -> void:
	echoes_total = 0
	permanent_levels = [0, 0, 0, 0, 0]
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("DESCENT: save file could not be opened; defaults loaded.")
		return
	var text := file.get_as_text()
	file.close()

	if not _apply_validated(JSON.parse_string(text)):
		echoes_total = 0
		permanent_levels = [0, 0, 0, 0, 0]
		push_warning("DESCENT: malformed save rejected; safe defaults loaded.")

	echoes_changed.emit(echoes_total)


func save_game() -> void:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"echoes": clampi(echoes_total, 0, MAX_ECHOES),
		"permanent_levels": permanent_levels.duplicate(),
	}

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("DESCENT: unable to open temporary save file.")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

	var main_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)

	DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(main_absolute, backup_absolute)

	if DirAccess.rename_absolute(temp_absolute, main_absolute) == OK:
		DirAccess.remove_absolute(backup_absolute)
	else:
		push_error("DESCENT: save replacement failed; restoring backup.")
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(backup_absolute, main_absolute)


func _apply_validated(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value

	var schema: Variant = data.get("schema_version")
	if typeof(schema) != TYPE_FLOAT and typeof(schema) != TYPE_INT:
		return false
	if int(schema) != SCHEMA_VERSION:
		return false

	var loaded_echoes := int(data.get("echoes", -1))
	if loaded_echoes < 0 or loaded_echoes > MAX_ECHOES:
		return false

	var levels: Variant = data.get("permanent_levels")
	if typeof(levels) != TYPE_ARRAY or (levels as Array).size() != TRACKS.size():
		return false

	var validated: Array[int] = []
	for index in TRACKS.size():
		var entry: Variant = (levels as Array)[index]
		if typeof(entry) != TYPE_FLOAT and typeof(entry) != TYPE_INT:
			return false
		var entry_level := int(entry)
		if entry_level < 0 or entry_level > max_level(index):
			return false
		validated.append(entry_level)

	echoes_total = loaded_echoes
	permanent_levels = validated
	return true
