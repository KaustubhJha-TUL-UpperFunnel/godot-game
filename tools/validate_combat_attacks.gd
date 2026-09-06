extends Node

## Regression checks for repeated projectile/ice damage and hold-release aiming.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var monster_scene := load(
		"res://descent/scenes/actors/animated_monster.tscn"
	) as PackedScene
	var projectile_scene := load("res://descent/scenes/actors/projectile.tscn") as PackedScene
	var player_scene := load("res://descent/scenes/actors/player.tscn") as PackedScene
	var monster := monster_scene.instantiate() as AnimatedMonster
	var second_monster := monster_scene.instantiate() as AnimatedMonster
	get_tree().root.add_child(monster)
	get_tree().root.add_child(second_monster)
	monster.configure(1, false, 1.0)
	second_monster.configure(1, false, 1.0)
	monster.set_combat_enabled(true)
	second_monster.set_combat_enabled(true)
	monster.position = Vector2(500.0, 500.0)
	second_monster.position = Vector2(700.0, 500.0)

	var barrier := StaticBody2D.new()
	barrier.collision_layer = 4
	barrier.position = Vector2(350.0, 500.0)
	var barrier_shape := CollisionShape2D.new()
	var barrier_rect := RectangleShape2D.new()
	barrier_rect.size = Vector2(40.0, 180.0)
	barrier_shape.shape = barrier_rect
	barrier.add_child(barrier_shape)
	get_tree().root.add_child(barrier)

	var initial_health := monster.health.current
	var second_initial_health := second_monster.health.current
	_launch_projectile(projectile_scene, 8.0)
	await get_tree().create_timer(0.9).timeout
	_launch_projectile(projectile_scene, 8.0)
	await get_tree().create_timer(0.9).timeout
	if not is_equal_approx(monster.health.current, initial_health - 16.0):
		_fail("Repeated projectiles did not pass through a platform and damage twice.")
		return
	if not is_equal_approx(second_monster.health.current, second_initial_health - 16.0):
		_fail("Projectiles did not continue through the first enemy to the next.")
		return

	await get_tree().create_timer(0.06).timeout
	var before_ice := monster.health.current
	monster.take_hit(6.0, Vector2.RIGHT, EventBus.DamageStyle.ICE)
	await get_tree().create_timer(0.06).timeout
	monster.take_hit(6.0, Vector2.RIGHT, EventBus.DamageStyle.ICE)
	if not is_equal_approx(monster.health.current, before_ice - 12.0):
		_fail("Repeated ice damage did not affect the enemy.")
		return

	var player := player_scene.instantiate() as PlayerAvatar
	get_tree().root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.input.movement_enabled = true
	player.input.attack_enabled = true
	player.velocity = Vector2(120.0, 40.0)
	if not player.begin_projectile_aim():
		_fail("Fire button hold did not enter aiming mode.")
		return
	if player.velocity != Vector2.ZERO or not player._aim_guide.visible:
		_fail("Player did not become idle while aiming.")
		return
	var mana_before := player.mana.current
	if not player.release_projectile_aim():
		_fail("Fire button release did not cast the projectile.")
		return
	if not is_equal_approx(player.mana.current, mana_before - PlayerAvatar.FIRE_COST):
		_fail("Released projectile did not spend mana exactly once.")
		return

	print("combat attack checks: passed")
	get_tree().quit()


func _launch_projectile(scene: PackedScene, amount: float) -> void:
	var projectile := scene.instantiate() as Projectile
	projectile.bounds = Rect2(0.0, 0.0, 1000.0, 1000.0)
	projectile.setup(true, Vector2(200.0, 500.0), Vector2.RIGHT * 720.0, amount)
	get_tree().root.add_child(projectile)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
