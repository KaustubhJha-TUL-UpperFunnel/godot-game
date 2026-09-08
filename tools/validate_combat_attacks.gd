extends Node

## Regression checks for repeated projectile/ice damage and hold-release aiming.

var _fireball_count: int = 0


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
	monster.queue_free()
	second_monster.queue_free()
	await get_tree().process_frame
	if not await _check_all_monster_variants(monster_scene, projectile_scene):
		return

	var player := player_scene.instantiate() as PlayerAvatar
	get_tree().root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.input.movement_enabled = true
	player.input.attack_enabled = true
	player.fireball_cast.connect(
		func(_origin: Vector2, _direction: Vector2, _damage: float) -> void:
			_fireball_count += 1
	)
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
	if _fireball_count != 1:
		_fail("One fire release emitted more than one projectile.")
		return

	player._fire_cooldown.stop()
	if not player.begin_projectile_aim():
		_fail("Could not re-enter aiming for the jump cancellation check.")
		return
	player.input.request_touch_jump()
	player._update_platformer_velocity(1.0 / 60.0)
	if player._projectile_aiming or player._aim_guide.visible:
		_fail("Jump preserved the projectile aiming state.")
		return
	if player.release_projectile_aim() or _fireball_count != 1:
		_fail("Jump cancellation released an extra projectile.")
		return

	print("combat attack checks: passed")
	get_tree().quit()


func _launch_projectile(scene: PackedScene, amount: float) -> void:
	var projectile := scene.instantiate() as Projectile
	projectile.bounds = Rect2(0.0, 0.0, 1000.0, 1000.0)
	projectile.setup(true, Vector2(200.0, 500.0), Vector2.RIGHT * 720.0, amount)
	get_tree().root.add_child(projectile)


func _check_all_monster_variants(
	monster_scene: PackedScene, projectile_scene: PackedScene
) -> bool:
	for variant in range(1, 19):
		var monster := monster_scene.instantiate() as AnimatedMonster
		monster.configure_variant(variant)
		get_tree().root.add_child(monster)
		monster.configure(1, false, 1.0)
		monster.set_combat_enabled(true)
		monster.position = Vector2(500.0, 500.0)
		var before := monster.health.current
		_launch_projectile(projectile_scene, 4.0)
		await get_tree().create_timer(0.55).timeout
		if not is_equal_approx(monster.health.current, before - 4.0):
			_fail("Projectile missed monster variant %d." % variant)
			return false
		monster.queue_free()
		await get_tree().process_frame
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
