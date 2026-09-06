class_name MeleeHitbox
extends Area2D

## Cone-shaped sword arc in front of the player.
##
## The collision polygon is authored in player.tscn, so tuning reach and swing
## width is a matter of dragging points in the editor rather than editing code.
## The area only reports overlaps on the frame a strike lands; the rest of the
## time it is disabled so it costs nothing.

signal hit_landed(target: Node2D, damage: float, combo_step: int)

@export var base_reach: float = 84.0

var _pending_damage: float = 0.0
var _pending_combo_step: int = 0
var _reach_scale: float = 1.0


func _ready() -> void:
	monitoring = false


## Aims the cone, then waits one physics frame so the physics server can report
## overlaps at the new transform before we resolve the hit.
func strike(direction: Vector2, damage: float, combo_step: int, reach_scale: float = 1.0) -> void:
	_pending_damage = damage
	_pending_combo_step = combo_step
	_reach_scale = reach_scale

	rotation = direction.angle()
	scale = Vector2.ONE * reach_scale
	monitoring = true

	await get_tree().physics_frame
	if not is_inside_tree():
		return

	for body in get_overlapping_bodies():
		if body is Node2D:
			hit_landed.emit(body, _pending_damage, _pending_combo_step)

	monitoring = false


func current_reach() -> float:
	return base_reach * _reach_scale
