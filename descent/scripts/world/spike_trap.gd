class_name SpikeTrap
extends Area2D

## Floor spikes that retract and thrust on a fixed cycle. The player can read
## the retracted state and walk across safely between thrusts.

signal player_speared(damage: float)

@export var cycle_seconds: float = 2.4
@export var damage: float = 16.0

var _armed: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _cycle: Timer = $CycleTimer
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_cycle.wait_time = cycle_seconds
	_cycle.timeout.connect(_toggle)
	_cycle.start()
	_animation.play(&"retracted")


func _toggle() -> void:
	_armed = not _armed
	_animation.play(&"thrust" if _armed else &"retracted")

	if not _armed:
		return
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			player_speared.emit(damage)


func is_armed() -> bool:
	return _armed
