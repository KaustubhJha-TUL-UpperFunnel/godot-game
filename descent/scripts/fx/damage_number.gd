class_name DamageNumber
extends Node2D

## Floating hit number. Colour and size come from the EventBus damage style so
## a critical finisher reads differently from chip damage or a heal tick.

const STYLE_COLORS := {
	EventBus.DamageStyle.NORMAL: Color(1, 1, 1),
	EventBus.DamageStyle.CRITICAL: Color(1, 0.85, 0.25),
	EventBus.DamageStyle.PLAYER_HURT: Color("ff4444"),
	EventBus.DamageStyle.FIRE: Color("ff6622"),
	EventBus.DamageStyle.ICE: Color("66eeff"),
	EventBus.DamageStyle.HEAL: Color("6ef08a"),
}

@onready var _label: Label = $Label
@onready var _animation: AnimationPlayer = $AnimationPlayer


func show_amount(amount: float, style: EventBus.DamageStyle) -> void:
	var rounded := int(roundf(amount))
	_label.text = ("+%d" % rounded) if style == EventBus.DamageStyle.HEAL else str(rounded)
	_label.add_theme_color_override(
		&"font_color", STYLE_COLORS.get(style, Color.WHITE)
	)
	if style == EventBus.DamageStyle.CRITICAL:
		_label.add_theme_font_size_override(&"font_size", 24)

	_animation.play(&"float_up")
	_animation.animation_finished.connect(func(_name: StringName) -> void: queue_free())
