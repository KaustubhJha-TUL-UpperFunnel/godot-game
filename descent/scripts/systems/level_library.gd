class_name LevelLibrary
extends RefCounted

## The catalogue of level scenes in descent/assets/scenes/levels/.
##
## There is one level per painted map, so dropping a new scene into the folder is
## enough to put it into the rotation — nothing here is hand-listed.
##
## Orientation is read off the filename rather than by loading the scene, so
## picking a level costs nothing. `Level.kind` inside the scene is the real
## authority and the two are generated together — keep the suffix if you rename.

const LEVELS_DIRECTORY := "res://descent/assets/scenes/levels"

const VERTICAL_SUFFIX := "_vertical"

## Vertical levels are authored, marked, and reviewable, but the knight still
## moves top-down with no gravity and no jump, so a side-on room would have him
## hovering over the pit. Flip this on with the platformer movement, not before.
const INCLUDE_VERTICAL := false


## Every level scene, sorted, so the run order is stable between sessions.
static func all_paths() -> Array[String]:
	var paths: Array[String] = []
	# Exported builds rename scenes to `<file>.remap`; load the original path.
	for entry in DirAccess.get_files_at(LEVELS_DIRECTORY):
		var file_name := entry.trim_suffix(".remap")
		if not file_name.ends_with(".tscn"):
			continue
		paths.append(LEVELS_DIRECTORY.path_join(file_name))
	paths.sort()
	if paths.is_empty():
		push_warning("DESCENT: no level scenes found in %s" % LEVELS_DIRECTORY)
	return paths


static func is_vertical(path: String) -> bool:
	return path.get_basename().ends_with(VERTICAL_SUFFIX)


## Built by hand rather than with Array.filter(), which hands back an untyped
## Array and would fail the typed return.
static func flat_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in all_paths():
		if not is_vertical(path):
			paths.append(path)
	return paths


static func vertical_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in all_paths():
		if is_vertical(path):
			paths.append(path)
	return paths


## The levels the run is allowed to hand the player right now.
static func playable_paths() -> Array[String]:
	return all_paths() if INCLUDE_VERTICAL else flat_paths()


## Picks a level for a floor, avoiding an immediate repeat.
static func pick(rng: RandomNumberGenerator, exclude: String = "") -> String:
	var pool := playable_paths()
	if pool.is_empty():
		return ""
	if pool.size() > 1 and not exclude.is_empty():
		var without: Array[String] = []
		for path in pool:
			if path != exclude:
				without.append(path)
		pool = without
	return pool[rng.randi_range(0, pool.size() - 1)]
