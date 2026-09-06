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

## Platforms with the same non-empty traversal group are one continuous route
## for navigation. Use this for a staircase made from multiple collision
## shapes, where treating every step/slope as a separate floor would make
## enemies repeatedly jump or drop between pieces.
@export var traversal_group: StringName = &""

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


## Long centre-line of the platform, shifted to the visually upper edge. This
## deliberately does not use the local "top" edge: some authored staircase
## slopes are rotated more than 90 degrees, which reverses their local normal
## while their standable face is still the upper edge on screen.
func navigation_segment() -> PackedVector2Array:
	var half := size * 0.5
	var a := transform * Vector2(-half.x, 0.0)
	var b := transform * Vector2(half.x, 0.0)
	var thickness := absf(size.y * scale.y) * 0.5
	a.y -= thickness
	b.y -= thickness
	return PackedVector2Array([a, b])


func navigation_x_range() -> Vector2:
	var segment := navigation_segment()
	return Vector2(
		minf(segment[0].x, segment[1].x),
		maxf(segment[0].x, segment[1].x)
	)


## Returns the surface y at x, or INF when x is outside this platform.
func surface_y_at(x: float, margin: float = 0.0) -> float:
	var segment := navigation_segment()
	var a := segment[0]
	var b := segment[1]
	var x_range := navigation_x_range()
	if x < x_range.x - margin or x > x_range.y + margin:
		return INF
	if absf(b.x - a.x) < 0.001:
		return minf(a.y, b.y)
	var ratio := clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
	return lerpf(a.y, b.y, ratio)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-size * 0.5, size)
	var tint := Color(0.35, 1.0, 0.55) if not one_way else Color(1.0, 0.85, 0.3)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.20), true)
	draw_rect(rect, tint, false, 2.0)
	# Mark the standable face so the up direction is unambiguous at a glance.
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), tint, 4.0)
