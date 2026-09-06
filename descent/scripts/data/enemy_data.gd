class_name EnemyData
extends Resource

## Base statline for one enemy archetype. Floor scaling and elite multipliers are
## applied on top of these values by EnemyBase.configure().

@export var display_name: String = "Enemy"
@export var maximum_health: float = 40.0
@export var movement_speed: float = 120.0
@export var damage: float = 10.0
@export var coin_reward: int = 2
