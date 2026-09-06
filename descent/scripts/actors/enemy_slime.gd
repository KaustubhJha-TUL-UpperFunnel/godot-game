extends EnemyBase

## Chaser archetype. Beelines at the player and only threatens on contact.
## The hop is an AnimationPlayer loop; the face swaps to the angry texture the
## moment it takes a scratch.

@export var cute_texture: Texture2D
@export var angry_texture: Texture2D

@onready var _sprite: Sprite2D = $Facing/Sprite
@onready var _facing_pivot: Node2D = $Facing
@onready var _hop: AnimationPlayer = $HopAnimation


func _on_ready_configured() -> void:
	_sprite.texture = cute_texture
	health.damaged.connect(_on_damaged)
	# Desynchronise the pack so a room of slimes does not hop in lockstep.
	_hop.play(&"hop")
	_hop.seek(randf() * _hop.current_animation_length, true)


func _steer(_delta: float, direction: Vector2, _distance: float) -> Vector2:
	_facing_pivot.scale.x = -1.0 if direction.x < 0.0 else 1.0
	return direction * speed


func _on_damaged(_amount: float, _source: Vector2) -> void:
	_sprite.texture = angry_texture


func _impact_color() -> Color:
	return Color(0.58, 0.92, 0.35)


func _death_color() -> Color:
	return Color(0.32, 0.72, 0.22)
