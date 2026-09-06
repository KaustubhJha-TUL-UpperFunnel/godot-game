class_name FloorTransition
extends Control

## The "drop straight to the next floor" wipe: a lit shaft, speedlines, and the
## knight falling through it. Awaited by GameplayController, which rebuilds the
## next room behind it while the screen is covered.

signal finished()

@onready var _label: Label = $Caption
@onready var _speedlines: CPUParticles2D = $Speedlines
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	hide()
	_speedlines.emitting = false


func play(next_floor: int) -> void:
	_label.text = "DESCENDING TO FLOOR %d" % next_floor
	show()
	_speedlines.emitting = true
	_animation.play(&"fall")
	await _animation.animation_finished
	_speedlines.emitting = false
	hide()
	finished.emit()
