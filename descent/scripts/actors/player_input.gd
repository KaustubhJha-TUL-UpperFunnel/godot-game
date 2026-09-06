class_name PlayerInput
extends Node

## Single place where every control scheme is read: keyboard, mouse, and the
## on-screen sticks from touch_controls.tscn.
##
## Abilities are expressed as hotbar slot indices so a key press, a mouse click
## on the hotbar, and a thumb on a touch button all take the same path into
## PlayerAvatar.activate_slot().

signal slot_activated(index: int)

## Action name -> hotbar slot. Mirrors the six slots shown in hotbar.tscn.
const SLOT_ACTIONS := {
	"attack": 0,
	"ability_fire": 1,
	"ability_ice": 2,
	"dash": 3,
	"potion_health": 4,
	"potion_mana": 5,
}

const TOUCH_STICK_RADIUS := 85.0

## Movement is allowed in combat, door selection, and the shop.
@export var movement_enabled: bool = false
## Attacking is combat-only, so clicks on shop and door UI never swing the sword.
@export var attack_enabled: bool = false

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.RIGHT
var attack_held: bool = false

var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_attack: bool = false

@onready var _actor: Node2D = get_parent()


func _process(_delta: float) -> void:
	_read_movement()
	_read_aim()
	_read_attack_hold()
	_read_slot_presses()


func _read_movement() -> void:
	if not movement_enabled:
		move_vector = Vector2.ZERO
		return

	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := touch_move / TOUCH_STICK_RADIUS
	move_vector = stick if stick.length() > keyboard.length() else keyboard
	if move_vector.length() > 1.0:
		move_vector = move_vector.normalized()


func _read_aim() -> void:
	var aim := touch_aim
	if aim.length() <= 12.0:
		aim = _actor.get_global_mouse_position() - _actor.global_position
	if aim.length_squared() > 0.01:
		aim_vector = aim.normalized()


func _read_attack_hold() -> void:
	attack_held = attack_enabled and (Input.is_action_pressed("attack") or touch_attack)


func _read_slot_presses() -> void:
	if not movement_enabled:
		return
	for action: String in SLOT_ACTIONS:
		# The attack slot is driven by attack_held so the combo can be chained.
		if action == "attack":
			continue
		if Input.is_action_just_pressed(action):
			slot_activated.emit(SLOT_ACTIONS[action])


## Called by touch_controls.tscn as the player drags the virtual sticks.
func set_touch_state(move_delta: Vector2, aim_delta: Vector2, firing: bool) -> void:
	touch_move = move_delta
	touch_aim = aim_delta
	touch_attack = firing


func clear_touch_state() -> void:
	touch_move = Vector2.ZERO
	touch_aim = Vector2.ZERO
	touch_attack = false
