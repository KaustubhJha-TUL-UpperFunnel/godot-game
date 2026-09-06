class_name LevelHost
extends Node2D

## Holds whichever level scene the run is currently in, and answers the
## positional questions the rest of the game asks about the room: where the
## player starts, where enemies may stand, how far a projectile may travel.
##
## Every accessor tolerates having no level loaded, because the controller
## queries some of them before the first room is built.

signal level_loaded(level: Level)

const FALLBACK_BOUNDS := Rect2(105, 380, 1070, 240)

var current_level: Level = null


## Swaps in the level at `path`. Returns null if it could not be loaded, leaving
## the host empty rather than half-populated.
func load_level(path: String) -> Level:
	clear_level()
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("DESCENT: missing level scene %s" % path)
		return null

	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	var level := instance as Level
	if level == null:
		push_warning("DESCENT: %s root is not a Level" % path)
		instance.free()
		return null

	add_child(level)
	current_level = level
	level_loaded.emit(level)
	return level


func clear_level() -> void:
	current_level = null
	# Detached before freeing, so the incoming level is never briefly a sibling
	# of the outgoing one.
	for child in get_children():
		remove_child(child)
		child.queue_free()


func is_vertical() -> bool:
	return current_level != null and current_level.is_vertical()


func content_size() -> Vector2:
	return current_level.content_size if current_level != null else FALLBACK_BOUNDS.size


# --- Positional queries -------------------------------------------------------


func walkable_bounds() -> Rect2:
	if current_level == null:
		return FALLBACK_BOUNDS
	return current_level.walkable_bounds()


func player_start() -> Vector2:
	if current_level == null:
		return FALLBACK_BOUNDS.get_center()
	return current_level.player_start()


func spawn_positions() -> Array[Vector2]:
	if current_level == null:
		var empty: Array[Vector2] = []
		return empty
	return current_level.spawn_positions()


func is_blocked(point: Vector2, margin: float = 24.0) -> bool:
	if current_level == null:
		return false
	return current_level.is_blocked(point, margin)


## Where the three exit doors belong in this level. Falls back to a row across
## the top of the play area so a level missing its anchors still works.
func door_anchor(door_name: StringName, index: int) -> Vector2:
	if current_level != null:
		var anchor := current_level.door_anchor(door_name)
		if anchor != Vector2.INF:
			return anchor
	var bounds := walkable_bounds()
	var fractions := [0.22, 0.5, 0.78]
	var fraction: float = fractions[clampi(index, 0, fractions.size() - 1)]
	return Vector2(bounds.position.x + bounds.size.x * fraction, bounds.position.y - 40.0)
