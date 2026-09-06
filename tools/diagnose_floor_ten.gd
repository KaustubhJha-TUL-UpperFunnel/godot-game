extends Node

## Runs floor ten without input and reports the first unexpected health/fall event.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RunState.begin_run()
	RunState.floor_number = 10
	var gameplay_scene := load("res://descent/scenes/gameplay.tscn") as PackedScene
	var gameplay := gameplay_scene.instantiate() as GameplayController
	get_tree().root.add_child(gameplay)
	gameplay.set_physics_process(false)

	var player := gameplay.player
	player.input.touch_move = Vector2(0.0, PlayerInput.TOUCH_STICK_RADIUS)
	for frame in 240:
		await get_tree().physics_frame
		if player.is_dead:
			push_error(
				"Floor ten death at %.2fs, position %s"
				% [float(frame + 1) / 60.0, player.position]
			)
			get_tree().quit(1)
			return

	var level := gameplay.level_host.current_level
	if level.is_hazardous(player.position, 17.0):
		push_error("Floor ten ended with the player inside a hazard.")
		get_tree().quit(1)
		return
	print(
		"floor ten held-down runtime: survived 4s at ",
		player.position,
		" with ",
		player.health.current,
		" HP"
	)
	get_tree().quit()
