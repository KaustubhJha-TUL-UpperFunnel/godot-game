@tool
class_name LevelPlatform
extends StaticBody2D

## A standable surface in a vertical level: a ledge, a bridge deck, or one of
## the floating stones over the pit.
##
## The art is already painted into the level background, so this node carries no
## visuals of its own. It draws its outline in the editor only, which is what
## makes a generated level reviewable by dragging handles around.
##
## Sits on the `walls` layer so the colliders the player and every enemy already
## mask against pick it up without any of them learning a new layer.

const WALLS_LAYER := 4

## Passable from below and from the sides, solid underfoot. Bridges and the
## small floating stones want this; a tier floor with rooms beneath does not.
@export var one_way: bool = false:
	set(value):
		one_way = value
		_apply()

@export var size: Vector2 = Vector2(240, 32):
	set(value):
		size = Vector2(maxf(value.x, 8.0), maxf(value.y, 8.0))
		_apply()

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = WALLS_LAYER
	collision_mask = 0
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	# A fresh shape per node: a shape declared in the scene file would be shared
	# by every instance of it, so resizing one platform would resize them all.
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.one_way_collision = one_way
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-size * 0.5, size)
	var tint := Color(0.35, 1.0, 0.55) if not one_way else Color(1.0, 0.85, 0.3)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.20), true)
	draw_rect(rect, tint, false, 2.0)
	# Mark the standable face so the up direction is unambiguous at a glance.
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), tint, 4.0)
