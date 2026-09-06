@tool
class_name DeathZone
extends Area2D

## The bottom of a vertical level. Anything that falls in is gone — no damage
## roll, no invulnerability window, no knockback out of it.
##
## Kept separate from `HazardZone` on purpose: a hazard is a cost you can choose
## to pay, a death zone is the floor not being there. Enemies fall in too, which
## is why this one also masks the enemy layer.

signal body_fell(body: Node2D)

const HAZARD_LAYER := 16  # enemy_attacks
const PLAYER_AND_ENEMIES := 1 | 2

@export var size: Vector2 = Vector2(1200, 160):
	set(value):
		size = Vector2(maxf(value.x, 8.0), maxf(value.y, 8.0))
		_apply()

## Why this kills, for the death message and for the editor.
@export var hazard_name: String = "THE FALL"

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = HAZARD_LAYER
	collision_mask = PLAYER_AND_ENEMIES
	monitoring = not Engine.is_editor_hint()
	_apply()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _apply() -> void:
	if not is_node_ready():
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	body_fell.emit(body)
	if body.has_method("fall_to_death"):
		body.fall_to_death()
	elif body.has_method("take_damage"):
		body.take_damage(99999.0, body.global_position)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-size * 0.5, size)
	var tint := Color(1.0, 0.15, 0.75)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.20), true)
	draw_rect(rect, tint, false, 3.0)
	# Hatching, so a death zone is never mistaken for a hazard at a glance.
	var step := 48.0
	var x := rect.position.x
	while x < rect.end.x:
		draw_line(
			Vector2(x, rect.end.y),
			Vector2(minf(x + rect.size.y, rect.end.x), rect.position.y),
			Color(tint.r, tint.g, tint.b, 0.45),
			1.5
		)
		x += step
