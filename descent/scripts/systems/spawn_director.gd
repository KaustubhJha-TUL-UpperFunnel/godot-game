class_name SpawnDirector
extends Node

## Decides what fills a room: how many enemies, which archetypes, how strong,
## and where they stand.
##
## The archetype mix widens with depth (slimes only at first, then shooters,
## then chargers) so each floor introduces a new thing to read rather than
## simply more of the same.

signal enemy_spawned(enemy: EnemyBase)

## Never exceed this, regardless of floor or danger stacking.
const MAX_ENEMIES := 12
## Spawn points closer than this to the player are rejected as ambushes.
const MIN_PLAYER_CLEARANCE := 170.0
const OVERCLOCKED_PRESSURE := 1.22

@export var slime_scene: PackedScene
@export var goblin_scene: PackedScene
@export var sorcerer_scene: PackedScene
@export var boss_scene: PackedScene
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

	if RunState.current_room_type == RunState.RoomType.BOSS:
		var boss := _spawn(boss_scene, level, player, container, _boss_position(level))
		if boss != null:
			boss.configure(floor_number, false, 1.0)
			spawned.append(boss)
		return spawned

	var count := _encounter_size(difficulty)
	var pressure := _encounter_pressure(difficulty)
	var elite_chance := _elite_chance(difficulty)
	var positions := _pick_positions(level, player, count, rng)

	for index in count:
		var scene := _scene_for(index, floor_number)
		var enemy := _spawn(scene, level, player, container, positions[index])
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


## Archetype rotation. The first enemy is the melee anchor; shooters join from
## floor 2 and chargers from floor 3, both on a fixed cadence so the mix stays
## legible instead of randomly lopsided.
func _scene_for(index: int, floor_number: int) -> PackedScene:
	if index == 0:
		return goblin_scene if floor_number >= 2 else slime_scene
	if floor_number >= 2 and index % 3 == 1:
		return sorcerer_scene
	if floor_number >= 3 and index % 4 == 3:
		return goblin_scene
	return slime_scene


func _boss_position(level: LevelHost) -> Vector2:
	var bounds := level.walkable_bounds()
	return Vector2(bounds.get_center().x, bounds.position.y + bounds.size.y * 0.32)


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
		if player != null and point.distance_to(player.position) < MIN_PLAYER_CLEARANCE:
			continue
		if level.is_blocked(point):
			continue
		chosen.append(point)

	var bounds := level.walkable_bounds()
	while chosen.size() < count:
		chosen.append(
			Vector2(
				rng.randf_range(bounds.position.x + 60.0, bounds.end.x - 60.0),
				rng.randf_range(bounds.position.y + 30.0, bounds.end.y - 30.0)
			)
		)
	return chosen


func _shuffle(points: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for index in range(points.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := points[index]
		points[index] = points[swap]
		points[swap] = held


func _spawn(
	scene: PackedScene, level: LevelHost, player: PlayerAvatar, container: Node2D, at: Vector2
) -> EnemyBase:
	if scene == null:
		return null
	var enemy: EnemyBase = scene.instantiate()
	enemy.position = at
	enemy.player = player
	enemy.movement_bounds = level.walkable_bounds()
	container.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy
