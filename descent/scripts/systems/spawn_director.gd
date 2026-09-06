class_name SpawnDirector
extends Node

## Decides how many animated monsters fill a floor, which visual variants they
## use, how strong they are, and where they may safely stand.

signal enemy_spawned(enemy: EnemyBase)

## Never exceed this, regardless of floor or danger stacking.
const MAX_ENEMIES := 12
## Spawn points closer than this to the player are rejected as ambushes.
const MIN_PLAYER_CLEARANCE := 170.0
const OVERCLOCKED_PRESSURE := 1.22

@export var enemy_scene: PackedScene
@export_dir var difficulty_directory: String = "res://descent/data/difficulty"

## One DifficultyData per floor, in floor order.
var difficulty_table: Array[DifficultyData] = []


func _ready() -> void:
	for resource in ResourceDirectory.load_all(difficulty_directory):
		if resource is DifficultyData:
			difficulty_table.append(resource)
	difficulty_table.sort_custom(
		func(a: DifficultyData, b: DifficultyData) -> bool: return a.floor_number < b.floor_number
	)


func difficulty_for(floor_number: int) -> DifficultyData:
	for entry in difficulty_table:
		if entry != null and entry.floor_number == floor_number:
			return entry
	return difficulty_table.back() if not difficulty_table.is_empty() else null


## Fills `container` with the encounter for the current RunState room and
## returns the enemies it created.
func populate(
	level: LevelHost, player: PlayerAvatar, container: Node2D, rng: RandomNumberGenerator
) -> Array[EnemyBase]:
	var spawned: Array[EnemyBase] = []
	var floor_number := RunState.floor_number
	var difficulty := difficulty_for(floor_number)
	if difficulty == null:
		push_warning("DESCENT: no difficulty data for floor %d" % floor_number)
		return spawned

	var count := _encounter_size(difficulty)
	var pressure := _encounter_pressure(difficulty)
	var elite_chance := _elite_chance(difficulty)
	var positions := _pick_positions(level, player, count, rng)

	for index in positions.size():
		var variant := wrapi((floor_number - 1) * 3 + index, 0, 18) + 1
		var enemy := _spawn(enemy_scene, level, player, container, positions[index], variant)
		if enemy == null:
			continue
		enemy.configure(floor_number, rng.randf() < elite_chance, pressure)
		spawned.append(enemy)

	return spawned


func _encounter_size(difficulty: DifficultyData) -> int:
	var count := difficulty.enemy_count
	match RunState.current_room_type:
		RunState.RoomType.LOOT:
			count = maxi(2, count - 2)
		RunState.RoomType.DANGER:
			count += 2
	return clampi(count, 1, MAX_ENEMIES)


func _encounter_pressure(difficulty: DifficultyData) -> float:
	var pressure := difficulty.pressure
	if RunState.current_room_type == RunState.RoomType.DANGER \
			and RunState.danger_modifier == "OVERCLOCKED":
		pressure *= OVERCLOCKED_PRESSURE
	return pressure


func _elite_chance(difficulty: DifficultyData) -> float:
	var chance := difficulty.elite_chance
	if RunState.current_room_type == RunState.RoomType.DANGER:
		chance += 0.22
	return clampf(chance, 0.0, 0.85)


## Shuffles the level's authored markers, drops any that are inside cover or
## on top of the player, and tops up with jittered fallbacks if that leaves
## fewer slots than the encounter needs.
func _pick_positions(
	level: LevelHost, player: PlayerAvatar, count: int, rng: RandomNumberGenerator
) -> Array[Vector2]:
	var candidates := level.spawn_positions()
	_shuffle(candidates, rng)

	var chosen: Array[Vector2] = []
	for point in candidates:
		if chosen.size() >= count:
			break
		var safe := level.safe_spawn_position(point)
		if safe == Vector2.INF:
			continue
		if player != null and safe.distance_to(player.position) < MIN_PLAYER_CLEARANCE:
			continue
		if _too_close_to_chosen(safe, chosen):
			continue
		chosen.append(safe)

	var bounds := level.walkable_bounds()
	var attempts := 0
	while chosen.size() < count and attempts < count * 30:
		attempts += 1
		var requested := Vector2(
			rng.randf_range(bounds.position.x + 60.0, bounds.end.x - 60.0),
			rng.randf_range(bounds.position.y + 30.0, bounds.end.y - 30.0)
		)
		var safe := level.safe_spawn_position(requested)
		if safe == Vector2.INF:
			continue
		if player != null and safe.distance_to(player.position) < MIN_PLAYER_CLEARANCE:
			continue
		if _too_close_to_chosen(safe, chosen):
			continue
		chosen.append(safe)
	if chosen.size() < count:
		push_warning(
			"DESCENT: only %d safe enemy spawns available for requested %d" \
			% [chosen.size(), count]
		)
	return chosen


func _too_close_to_chosen(point: Vector2, chosen: Array[Vector2]) -> bool:
	for other in chosen:
		if point.distance_to(other) < 58.0:
			return true
	return false


func _shuffle(points: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for index in range(points.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := points[index]
		points[index] = points[swap]
		points[swap] = held


func _spawn(
	scene: PackedScene,
	level: LevelHost,
	player: PlayerAvatar,
	container: Node2D,
	at: Vector2,
	variant: int
) -> EnemyBase:
	if scene == null:
		return null
	var enemy: EnemyBase = scene.instantiate()
	if enemy is AnimatedMonster:
		(enemy as AnimatedMonster).configure_variant(variant)
	var safe := level.safe_spawn_position(at, maxf(20.0, enemy.projectile_radius))
	if safe == Vector2.INF:
		enemy.free()
		return null
	enemy.position = safe
	enemy.player = player
	enemy.movement_bounds = level.walkable_bounds()
	container.add_child(enemy)
	enemy.configure_navigation(level.current_level)
	enemy_spawned.emit(enemy)
	return enemy
