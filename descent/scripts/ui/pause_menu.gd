class_name PauseMenu
extends Control

## Pause overlay. Runs with PROCESS_MODE_ALWAYS so its buttons still respond
## while the rest of the tree is frozen, and for the same reason it owns the
## pause key: nothing else in the gameplay tree receives input once paused.

signal pause_requested()
signal resume_requested()
signal abandon_requested()

@onready var _resume: Button = $Frame/Rows/Resume
@onready var _abandon: Button = $Frame/Rows/Abandon
@onready var _confirm: Label = $Frame/Rows/Confirm

var _abandon_armed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_abandon.pressed.connect(_on_abandon_pressed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		resume_requested.emit()
	else:
		pause_requested.emit()


func open() -> void:
	_reset_abandon()
	show()
	_resume.grab_focus()


func close() -> void:
	hide()


## Abandoning ends the run for good, so it takes two clicks.
func _on_abandon_pressed() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		_abandon.text = "CONFIRM ABANDON"
		_confirm.show()
		return
	abandon_requested.emit()


func _reset_abandon() -> void:
	_abandon_armed = false
	_abandon.text = "ABANDON RUN"
	_confirm.hide()
