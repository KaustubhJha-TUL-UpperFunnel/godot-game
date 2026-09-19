class_name RewardedRevive
extends Control

## Death-time offer: watch a rewarded ad to continue the run. Must be a player
## tap; AdMob does not allow rewarded ads that start on their own.

signal revive_requested()
signal declined()

@onready var _watch: Button = $Frame/Rows/Watch
@onready var _give_up: Button = $Frame/Rows/GiveUp


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch.pressed.connect(_on_watch_pressed)
	_give_up.pressed.connect(_on_give_up_pressed)
	hide()


func open() -> void:
	_watch.disabled = false
	_give_up.disabled = false
	show()
	_watch.grab_focus()


func close() -> void:
	hide()


func _on_watch_pressed() -> void:
	_watch.disabled = true
	_give_up.disabled = true
	revive_requested.emit()


func _on_give_up_pressed() -> void:
	close()
	declined.emit()


func restore_choices() -> void:
	_watch.disabled = false
	_give_up.disabled = false
	show()
	_give_up.grab_focus()
