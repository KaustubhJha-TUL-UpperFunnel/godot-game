class_name Torch
extends Node2D

## Wall torch. The sconce sprite can be switched off so the same scene can also
## be dropped on top of a torch that is already painted into dungeon_bg.png,
## contributing only the animated light.

@export var show_sconce: bool = true:
	set(value):
		show_sconce = value
		if is_node_ready():
			$Sconce.visible = value

@onready var _flicker: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	$Sconce.visible = show_sconce
	if show_sconce:
		$Sconce.play(&"burn")
	_flicker.play(&"flicker")
	# Offset the flame cycle so a wall of torches never pulses in unison.
	_flicker.seek(randf() * _flicker.current_animation_length, true)
