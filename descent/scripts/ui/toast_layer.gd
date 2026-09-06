class_name ToastLayer
extends Control

## Single-line status messages ("ELIXIR: +MANA", "NOT ENOUGH COINS").
##
## Only one toast is visible at a time; a newer message replaces whatever is
## on screen rather than queueing, because the newest one is always the one
## the player just caused.

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Message
@onready var _animation: AnimationPlayer = $AnimationPlayer

var _hide_at: float = 0.0


func _ready() -> void:
	EventBus.toast_requested.connect(show_message)
	_panel.hide()
	set_process(false)


func show_message(message: String, duration: float = 1.5) -> void:
	_label.text = message
	_panel.show()
	_animation.play(&"pop")
	_hide_at = _now() + maxf(0.3, duration)
	set_process(true)


func _process(_delta: float) -> void:
	if _now() < _hide_at:
		return
	set_process(false)
	_animation.play(&"fade_out")
	await _animation.animation_finished
	# A new toast during the fade re-shows the panel; don't hide it out from under it.
	if not is_processing():
		_panel.hide()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
