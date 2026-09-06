class_name DoorPrompt
extends Control

## Bottom-of-screen hint shown while the knight is standing in a door's
## proximity area. Clicking a door works too, so this is a nudge rather than
## the only way through.

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Text


func _ready() -> void:
	_panel.hide()


func show_for(door: RoomDoor) -> void:
	if door == null or door.data == null:
		return
	_label.text = "PRESS E TO ENTER  -  %s" % door.data.display_name.to_upper()
	_label.add_theme_color_override(&"font_color", door.data.accent)
	_panel.show()


func dismiss() -> void:
	_panel.hide()
