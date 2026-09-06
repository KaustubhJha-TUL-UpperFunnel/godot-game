extends Node

## Regression check for the contextual air-climb and upward dash boost.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_scene := load(
		"res://descent/assets/scenes/levels/map_01_fire_vertical.tscn"
	) as PackedScene
	var player_scene := load("res://descent/scenes/actors/player.tscn") as PackedScene
	var level := level_scene.instantiate() as Level
	var player := player_scene.instantiate() as PlayerAvatar
	get_tree().root.add_child(level)
	get_tree().root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.configure_level(level)
	player.input.movement_enabled = true

	var platform := level.platforms()[0]
	var x_range := platform.navigation_x_range()
	var x := (x_range.x + x_range.y) * 0.5
	var surface_y := platform.surface_y_at(x)
	var expected_y := surface_y - 19.0
	player.position = Vector2(x, expected_y + 120.0)

	if not player._try_climb_overhead(220.0):
		push_error("Air climb did not find the platform overhead.")
		get_tree().quit(1)
		return
	if player._climb_duration <= 0.0:
		push_error("Air climb did not start a smooth transition.")
		get_tree().quit(1)
		return
	player._update_climb_transition(1.0)
	if not is_equal_approx(player.position.y, expected_y):
		push_error("Air climb did not place the player on the platform.")
		get_tree().quit(1)
		return

	player.position.y += 80.0
	player.velocity.y = -100.0
	player.input.touch_move = Vector2(0.0, -PlayerInput.TOUCH_STICK_RADIUS)
	if not player.start_dash() or player._dash_direction.y > -0.9:
		push_error("Up + dash while airborne did not produce an upward boost.")
		get_tree().quit(1)
		return

	print("player traversal checks: passed")
	get_tree().quit()
