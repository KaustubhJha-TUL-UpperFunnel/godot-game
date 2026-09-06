extends Node

## Regression check that floor two starts outside every instant-death hazard.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RunState.begin_run()
	RunState.floor_number = 2
	var gameplay_scene := load("res://descent/scenes/gameplay.tscn") as PackedScene
	var gameplay := gameplay_scene.instantiate() as GameplayController
	get_tree().root.add_child(gameplay)
	await get_tree().create_timer(0.2).timeout

	var player := gameplay.player
	var level := gameplay.level_host.current_level
	if player.is_dead or player.health.current <= 0.0:
		_fail("Player died immediately after entering floor two.")
		return
	if level.is_hazardous(player.position, 17.0):
		_fail("Floor two placed the player inside a hazard.")
		return
	for hazard in level.hazard_zones():
		if hazard.get_overlapping_bodies().has(player):
			_fail("Floor two hazard physically overlaps the player start.")
			return

	print("floor two start check: passed at ", player.position)
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
