class_name HotbarSlot
extends Control

## One ability button. Shows its icon, hotkey, remaining cooldown as a sweeping
## shade, and a charge count for the potion slots.

signal activated(index: int)
signal hold_changed(index: int, held: bool)

@export var slot_index: int = 0
@export var hotkey: String = "1"
@export var icon: Texture2D
@export var accent: Color = Color("e2ae52")

@onready var _icon: TextureRect = $Icon
@onready var _hotkey: Label = $Hotkey
@onready var _charges: Label = $Charges
@onready var _cooldown_shade: ColorRect = $CooldownShade
@onready var _cooldown_label: Label = $Seconds
@onready var _button: Button = $Press
@onready var _animation: AnimationPlayer = $AnimationPlayer

var _on_cooldown: bool = false


func _ready() -> void:
	_icon.texture = icon
	_icon.modulate = accent.lightened(0.35)
	_hotkey.text = hotkey
	_button.pressed.connect(func() -> void: activated.emit(slot_index))
	_button.button_down.connect(func() -> void: hold_changed.emit(slot_index, true))
	_button.button_up.connect(func() -> void: hold_changed.emit(slot_index, false))
	_button.mouse_entered.connect(func() -> void: _animation.play(&"hover"))
	_button.mouse_exited.connect(func() -> void: _animation.play(&"idle"))
	set_charges(-1)
	set_cooldown(0.0, 0.0)


## `ratio` is the fraction of the cooldown still to run, so 0 means ready.
func set_cooldown(ratio: float, seconds_left: float) -> void:
	var busy := ratio > 0.001
	# A rectangular sweep would cover the borderless mobile icon; the numeric
	# countdown carries the same information without adding a button frame.
	_cooldown_shade.visible = false
	_cooldown_label.visible = busy
	if busy:
		_cooldown_label.text = "%.1f" % seconds_left
	elif _on_cooldown:
		_animation.play(&"ready")
	_on_cooldown = busy


## Pass -1 for slots that have no charge count (sword, spells, dash).
func set_charges(count: int) -> void:
	_charges.visible = count >= 0
	_charges.text = str(count)
	_charges.add_theme_color_override(
		&"font_color", Color("ff4f62") if count == 0 else Color("f2f4f5")
	)


func flash_use() -> void:
	_animation.play(&"use")
