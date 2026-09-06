class_name HealthBar
extends Node2D

## Overhead hit-point bar for enemies. Stays hidden at full health so a room
## of untouched enemies does not clutter the arena.

@export var bar_width: float = 54.0
@export var bar_height: float = 7.0
@export var hide_when_full: bool = true

@onready var _backdrop: ColorRect = $Backdrop
@onready var _fill: ColorRect = $Fill

var _ratio: float = 1.0


func _ready() -> void:
	_apply_layout()
	set_ratio(_ratio)


func _apply_layout() -> void:
	_backdrop.position = Vector2(-bar_width * 0.5 - 2.0, -2.0)
	_backdrop.size = Vector2(bar_width + 4.0, bar_height + 4.0)
	_fill.position = Vector2(-bar_width * 0.5, 0.0)
	_fill.size = Vector2(bar_width, bar_height)


func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if not is_node_ready():
		return
	_fill.size = Vector2(bar_width * _ratio, bar_height)
	visible = not (hide_when_full and _ratio >= 0.99)
