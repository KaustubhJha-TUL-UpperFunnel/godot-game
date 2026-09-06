class_name Hazard
extends Area2D

## Timed ground eruption. Pulses a red telegraph ring first so the player can
## step out, then damages anything still standing in it.
##
## Used by the hazard-grid layout, the SPIKE PULSE danger modifier, and the
## boss's phase-two ground slams.

@export var radius: float = 55.0
@export var telegraph_seconds: float = 0.7
@export var active_seconds: float = 0.8
@export var damage: float = 12.0

var _is_active: bool = false
var _time_left: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _ring: Sprite2D = $Ring
@onready var _animation: AnimationPlayer = $AnimationPlayer


func setup(
	spawn_position: Vector2,
	hazard_radius: float,
	hazard_damage: float,
	telegraph: float = 0.7,
	active: float = 0.8
) -> void:
	global_position = spawn_position
	radius = hazard_radius
	damage = hazard_damage
	telegraph_seconds = telegraph
	active_seconds = active


func _ready() -> void:
	var circle: CircleShape2D = _shape.shape
	circle.radius = radius
	# soft_circle.tres is 64px across, so a unit of scale is 32px of radius.
	_ring.scale = Vector2.ONE * (radius / 32.0)
	_shape.disabled = true
	_time_left = telegraph_seconds
	_animation.play(&"telegraph")


func _physics_process(delta: float) -> void:
	_time_left -= delta

	if not _is_active:
		if _time_left <= 0.0:
			_erupt()
		return

	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)

	if _time_left <= 0.0:
		queue_free()


func _erupt() -> void:
	_is_active = true
	_time_left = active_seconds
	_shape.disabled = false
	_animation.play(&"erupt")
	EventBus.burst_requested.emit(global_position, Color(1, 0.45, 0.2), 10, 150.0, 3.5)
