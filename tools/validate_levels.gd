extends SceneTree

## Runtime companion to check_levels.py. That script reads the .tscn text and
## checks the node tree is well formed; this one actually loads every level
## inside the engine and exercises the accessors GameplayController and
## SpawnDirector call, which is the part text parsing cannot prove.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       --script res://tools/validate_levels.gd
##
## Exits non-zero if any level fails, so it can gate a commit.

func _init() -> void:
	var paths := LevelLibrary.all_paths()
	print("levels found: %d" % paths.size())
	var failures := 0
	var flat := 0
	var vertical := 0

	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			print("FAIL load: %s" % path)
			failures += 1
			continue

		var node := packed.instantiate()
		var level := node as Level
		if level == null:
			print("FAIL not a Level: %s" % path)
			failures += 1
			node.free()
			continue

		# Mirror LevelHost: a level is only ever read while it sits in the tree.
		root.add_child(level)

		var bounds := level.walkable_bounds()
		var start := level.player_start()
		var spawns := level.spawn_positions()

		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			print("FAIL empty walkable bounds: %s" % path)
			failures += 1
		if spawns.is_empty():
			print("FAIL no spawn points: %s" % path)
			failures += 1
		var safe_start := level.safe_spawn_position(start)
		if safe_start == Vector2.INF:
			print("FAIL no safe player start: %s" % path)
			failures += 1

		if level.is_vertical():
			vertical += 1
			if level.platforms().is_empty():
				print("FAIL vertical with no platforms: %s" % path)
				failures += 1
			if level.death_zones().is_empty():
				print("FAIL vertical with no death zone: %s" % path)
				failures += 1
		else:
			flat += 1
			# A metadata-vertical hybrid may intentionally fall back to its
			# WalkableRegion until platform collision is authored.
			if level.kind == Level.Kind.FLAT and not level.death_zones().is_empty():
				print("FAIL flat level has a death zone: %s" % path)
				failures += 1

		root.remove_child(level)
		level.free()

	print("flat: %d  vertical: %d" % [flat, vertical])
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
