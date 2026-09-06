class_name TouchControls
extends Control

## Twin virtual sticks for touch devices: drag on the left half to move, drag
## on the right half to aim and swing.
##
## Listens through _unhandled_input so a tap on the hotbar or a menu button is
## consumed by that button first and never also drags a stick.

const STICK_RADIUS := 85.0
## Ignore the aim stick until it is pushed past this, so a tap is a swing
## rather than a swing in an arbitrary direction.
const AIM_DEADZONE := 12.0

var _player_input: PlayerInput

var _move_touch: int = -1
var _aim_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _aim_origin: Vector2 = Vector2.ZERO
var _move_delta: Vector2 = Vector2.ZERO
var _aim_delta: Vector2 = Vector2.ZERO

@onready var _move_stick: Control = $MoveStick
@onready var _move_knob: Control = $MoveStick/Knob
@onready var _aim_stick: Control = $AimStick
@onready var _aim_knob: Control = $AimStick/Knob


func _ready() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	visible = touch_available
	set_process_unhandled_input(touch_available)
	_move_stick.hide()
	_aim_stick.hide()


func bind(player_input: PlayerInput) -> void:
	_player_input = player_input


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.x < size.x * 0.5:
			_begin(event.index, event.position, true)
		else:
			_begin(event.index, event.position, false)
	elif event.index == _move_touch:
		_end(true)
	elif event.index == _aim_touch:
		_end(false)
	_push_state()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch:
		_move_delta = _clamped(event.position - _move_origin)
		_move_knob.position = _move_delta
	elif event.index == _aim_touch:
		_aim_delta = _clamped(event.position - _aim_origin)
		_aim_knob.position = _aim_delta
	_push_state()


func _begin(index: int, at: Vector2, is_move: bool) -> void:
	if is_move:
		_move_touch = index
		_move_origin = at
		_move_delta = Vector2.ZERO
		_move_stick.position = at
		_move_knob.position = Vector2.ZERO
		_move_stick.show()
	else:
		_aim_touch = index
		_aim_origin = at
		_aim_delta = Vector2.ZERO
		_aim_stick.position = at
		_aim_knob.position = Vector2.ZERO
		_aim_stick.show()


func _end(is_move: bool) -> void:
	if is_move:
		_move_touch = -1
		_move_delta = Vector2.ZERO
		_move_stick.hide()
	else:
		_aim_touch = -1
		_aim_delta = Vector2.ZERO
		_aim_stick.hide()


func _clamped(offset: Vector2) -> Vector2:
	return offset.limit_length(STICK_RADIUS)


func _push_state() -> void:
	if _player_input == null:
		return
	# Holding the aim stick past the deadzone is what fires; a stationary
	# thumb keeps swinging, matching how attack_held works on mouse.
	var firing := _aim_touch != -1 and _aim_delta.length() > AIM_DEADZONE
	_player_input.set_touch_state(_move_delta, _aim_delta, firing)
