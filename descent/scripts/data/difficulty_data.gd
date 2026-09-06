class_name DifficultyData
extends Resource

## Per-floor encounter budget. SpawnDirector reads the entry matching the
## current floor to decide how many enemies to place and how hard they hit.

@export var floor_number: int = 1
@export var enemy_count: int = 3
@export var pressure: float = 1.0
@export var elite_chance: float = 0.0
