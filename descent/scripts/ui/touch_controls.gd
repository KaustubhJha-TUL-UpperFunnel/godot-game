class_name TouchControls
extends Control

## A fixed, translucent movement stick on the lower-left. Actions live in the
## circular hotbar buttons on the right, leaving the playfield unobscured.
##
## Listens through _unhandled_input so a tap on the hotbar or a menu button is
## consumed by that button first and never also drags a stick.

const STICK_RADIUS := 85.0
const STICK_MARGIN := Vector2(132.0, 132.0)

var _player_input: PlayerInput

var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_delta: Vector2 = Vector2.ZERO

@onready var _move_stick: Control = $MoveStick
@onready var _move_knob: Control = $MoveStick/Knob


func _ready() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	visible = touch_available
	set_process_unhandled_input(touch_available)
	resized.connect(_layout_stick)
	_layout_stick()


func bind(player_input: PlayerInput) -> void:
	_player_input = player_input


## Floor/UI transitions invalidate the active finger so a held joystick cannot
## carry movement or a drop command into the next map.
func reset_controls() -> void:
	_end()
	_push_state()


func set_tutorial_enabled(enabled: bool, highlighted: bool = false) -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	set_process_unhandled_input(touch_available and enabled)
	if not enabled:
		_end()
		_push_state()
	_move_stick.modulate = (
		Color(1.25, 1.2, 0.75, 1.0)
		if highlighted
		else Color(0.3, 0.34, 0.4, 0.35)
	)


func clear_tutorial_state() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	set_process_unhandled_input(touch_available)
	_move_stick.modulate = Color.WHITE


func tutorial_icon() -> Texture2D:
	var base := $MoveStick/Base as TextureRect
	return base.texture


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.x < size.x * 0.40 and _move_touch == -1:
			_begin(event.index, event.position)
	elif event.index == _move_touch:
		_end()
	_push_state()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch:
		_move_delta = _clamped(event.position - _move_origin)
		_move_knob.position = _move_delta
	_push_state()


func _begin(index: int, at: Vector2) -> void:
	_move_touch = index
	_move_origin = _move_stick.position
	_move_delta = _clamped(at - _move_origin)
	_move_knob.position = _move_delta


func _end() -> void:
	_move_touch = -1
	_move_delta = Vector2.ZERO
	_move_knob.position = Vector2.ZERO


func _layout_stick() -> void:
	_move_stick.position = Vector2(STICK_MARGIN.x, size.y - STICK_MARGIN.y)
	_move_origin = _move_stick.position


func _clamped(offset: Vector2) -> Vector2:
	return offset.limit_length(STICK_RADIUS)


func _push_state() -> void:
	if _player_input == null:
		return
	_player_input.set_touch_state(_move_delta, Vector2.ZERO, false)
