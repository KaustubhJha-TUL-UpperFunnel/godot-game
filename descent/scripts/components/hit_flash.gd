class_name HitFlash
extends Node

## Blows out the target sprite's modulate for a few frames on impact.
## Shared by the player and every enemy so hit feedback stays consistent.

## Sprite to blow out, relative to this node.
@export var target_path: NodePath = ^"../Sprite"
@export var duration: float = 0.12
@export var flash_color: Color = Color(2.2, 2.2, 2.2)

var target: CanvasItem

var _base_color := Color.WHITE
var _remaining: float = 0.0


func _ready() -> void:
	target = get_node_or_null(target_path) as CanvasItem
	if target != null:
		_base_color = target.modulate
	set_process(false)


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		if target != null:
			target.modulate = _base_color
		set_process(false)


## Overrides the resting colour, e.g. when an enemy is marked elite.
func set_base_color(color: Color) -> void:
	_base_color = color
	if target != null and _remaining <= 0.0:
		target.modulate = color


func flash() -> void:
	if target == null:
		return
	target.modulate = flash_color
	_remaining = duration
	set_process(true)


func is_flashing() -> bool:
	return _remaining > 0.0
