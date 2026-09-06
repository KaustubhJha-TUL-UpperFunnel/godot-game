class_name FxDirector
extends Node2D

## Turns EventBus presentation requests into actual nodes in the world.
##
## Every burst and damage number in the game is parented here, which keeps
## short-lived effects out of the actor tree (so an enemy freeing itself never
## takes its own death particles with it) and caps them in one place.

@export var burst_scene: PackedScene
@export var damage_number_scene: PackedScene
## Hard ceiling so a boss volley cannot spawn unbounded effect nodes.
@export var max_live_effects: int = 90


func _ready() -> void:
	EventBus.burst_requested.connect(_on_burst_requested)
	EventBus.damage_number_requested.connect(_on_damage_number_requested)


func _on_burst_requested(
	world_position: Vector2, color: Color, count: int, speed: float, size: float
) -> void:
	if burst_scene == null or get_child_count() >= max_live_effects:
		return
	var burst: ImpactBurst = burst_scene.instantiate()
	add_child(burst)
	burst.global_position = world_position
	burst.burst(color, count, speed, size)


func _on_damage_number_requested(
	world_position: Vector2, amount: float, style: EventBus.DamageStyle
) -> void:
	if damage_number_scene == null or get_child_count() >= max_live_effects:
		return
	var number: DamageNumber = damage_number_scene.instantiate()
	add_child(number)
	number.global_position = world_position + Vector2(randf_range(-14.0, 14.0), -16.0)
	number.show_amount(amount, style)
