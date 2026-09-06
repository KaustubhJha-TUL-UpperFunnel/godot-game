class_name StatBar
extends Control

## Horizontal resource bar used for the player's health and mana and for the
## boss bar. The "chip" layer trails behind the fill after a hit so the player
## can see how much a blow actually cost them.

@export var fill_color: Color = Color("ff4f62"):
	set = set_fill_color
@export var chip_color: Color = Color(0.65, 0.15, 0.2, 0.85)
@export var label_format: String = "%d / %d"
@export var show_label: bool = true
@export var chip_delay: float = 0.25
@export var chip_duration: float = 0.35

var _ratio: float = 1.0
var _chip_tween: Tween

@onready var _fill: ColorRect = $Fill
@onready var _chip: ColorRect = $Chip
@onready var _label: Label = $Value


func _ready() -> void:
	resized.connect(_apply_ratio)
	_chip.color = chip_color
	_fill.color = fill_color
	_label.visible = show_label
	_apply_ratio()


func set_fill_color(color: Color) -> void:
	fill_color = color
	if is_node_ready():
		_fill.color = color


func set_values(current: float, maximum: float) -> void:
	var previous := _ratio
	_ratio = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	_apply_ratio()

	if show_label:
		_label.text = label_format % [ceili(maxf(0.0, current)), ceili(maximum)]

	if _ratio < previous:
		_animate_chip(previous)
	else:
		_chip.size.x = _fill.size.x


func _apply_ratio() -> void:
	if not is_node_ready():
		return
	_fill.size = Vector2(size.x * _ratio, size.y)
	_chip.size.y = size.y
	_chip.size.x = maxf(_chip.size.x, _fill.size.x)


func _animate_chip(from_ratio: float) -> void:
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_chip.size.x = size.x * from_ratio
	_chip_tween = create_tween()
	_chip_tween.tween_interval(chip_delay)
	_chip_tween.tween_property(_chip, "size:x", _fill.size.x, chip_duration)
