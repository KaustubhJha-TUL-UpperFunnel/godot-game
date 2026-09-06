class_name Announcement
extends Control

## Centre-screen banner reused for the floor intro ("FLOOR 3 / DANGER CHAMBER")
## and the room-cleared flourish. One scene, two callers, no duplicated layout.

@onready var _title: Label = $Panel/Rows/Title
@onready var _subtitle: Label = $Panel/Rows/Subtitle
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	hide()


func announce(title: String, subtitle: String, accent: Color, hold_seconds: float) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_subtitle.add_theme_color_override(&"font_color", accent)

	show()
	_animation.play(&"reveal")
	await get_tree().create_timer(hold_seconds).timeout
	if not is_inside_tree():
		return
	_animation.play(&"dismiss")
	await _animation.animation_finished
	hide()


func dismiss_now() -> void:
	hide()
