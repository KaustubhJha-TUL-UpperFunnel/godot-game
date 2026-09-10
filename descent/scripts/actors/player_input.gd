class_name PlayerInput
extends Node

## Single place where every control scheme is read: keyboard, mouse, and the
## the on-screen movement stick from touch_controls.tscn.
##
## Abilities and jump are expressed as hotbar slot actions so a key press, a
## mouse click, and a thumb on a touch button take the same path into the player.

signal slot_activated(index: int)
signal slot_hold_changed(index: int, held: bool)

## Action name -> ability slot. Jump is consumed separately by platform physics.
const SLOT_ACTIONS := {
	"attack": 0,
	"ability_fire": 1,
	"ability_ice": 2,
	"dash": 3,
	"potion_health": 4,
	"potion_mana": 5,
}

const TOUCH_STICK_RADIUS := 85.0

## Movement is allowed while a floor is active.
@export var movement_enabled: bool = false
## Attacking is combat-only, so upgrade and pause UI taps never swing the sword.
@export var attack_enabled: bool = false

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.RIGHT
var attack_held: bool = false

var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_attack: bool = false
var _touch_jump_queued: bool = false
var _touch_drop_queued: bool = false
var _tutorial_restricted: bool = false
var _tutorial_movement_allowed: bool = true
var _tutorial_allowed_slot: int = -1

@onready var _actor: Node2D = get_parent()


func _process(_delta: float) -> void:
	_read_movement()
	_read_aim()
	_read_attack_hold()
	_read_slot_presses()


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.get_name() == "Android"


func _gui_blocks_click_attack() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _read_movement() -> void:
	if not movement_enabled or (_tutorial_restricted and not _tutorial_movement_allowed):
		move_vector = Vector2.ZERO
		return

	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := touch_move / TOUCH_STICK_RADIUS
	move_vector = stick if stick.length() > keyboard.length() else keyboard
	if move_vector.length() > 1.0:
		move_vector = move_vector.normalized()


func _read_aim() -> void:
	var aim := touch_aim
	# The right aim stick is intentionally gone on mobile. Face the direction
	# the movement stick is held so action buttons remain one-thumb friendly.
	if aim.length() <= 12.0 and touch_move.length() > 12.0:
		aim = touch_move
	if aim.length() <= 12.0:
		aim = _actor.get_global_mouse_position() - _actor.global_position
	if aim.length_squared() > 0.01:
		aim_vector = aim.normalized()


func _read_attack_hold() -> void:
	# Android emulates a mouse from every finger, so a held stick must never
	# look like a held sword. Attacks are one tap on the hotbar (or key 1).
	var attack_allowed := not _tutorial_restricted or _tutorial_allowed_slot == 0
	attack_held = (
		attack_enabled
		and attack_allowed
		and not _is_mobile()
		and (Input.is_action_pressed("attack") or touch_attack)
	)


func _read_slot_presses() -> void:
	if not movement_enabled:
		return
	for action: String in SLOT_ACTIONS:
		var slot: int = SLOT_ACTIONS[action]
		if _tutorial_restricted and slot != _tutorial_allowed_slot:
			continue
		# Mobile attacks come from the sword hotbar button. Emulated mouse
		# presses from the movement stick must not swing the blade.
		if action == "attack":
			if (
				not _is_mobile()
				and Input.is_action_just_pressed(action)
				and not _gui_blocks_click_attack()
			):
				slot_activated.emit(slot)
			continue
		# Fire is charged while held and released through a separate signal.
		if action == "ability_fire":
			if Input.is_action_just_pressed(action):
				slot_hold_changed.emit(SLOT_ACTIONS[action], true)
			if Input.is_action_just_released(action):
				slot_hold_changed.emit(SLOT_ACTIONS[action], false)
			continue
		if Input.is_action_just_pressed(action):
			slot_activated.emit(SLOT_ACTIONS[action])


## Called by touch_controls.tscn as the player drags the virtual sticks.
func set_touch_state(move_delta: Vector2, aim_delta: Vector2, firing: bool) -> void:
	touch_move = move_delta
	touch_aim = aim_delta
	touch_attack = firing


func request_touch_jump() -> void:
	_touch_jump_queued = true


func jump_requested() -> bool:
	var jump_allowed := not _tutorial_restricted or _tutorial_allowed_slot == PlayerAvatar.Slot.JUMP
	return movement_enabled and jump_allowed and (
		Input.is_action_just_pressed(&"jump") or _touch_jump_queued
	)


func consume_jump() -> bool:
	if not movement_enabled:
		_touch_jump_queued = false
		return false
	var requested := jump_requested()
	_touch_jump_queued = false
	return requested


func request_touch_drop() -> void:
	_touch_drop_queued = true


func drop_requested() -> bool:
	var drop_allowed := not _tutorial_restricted or _tutorial_allowed_slot == PlayerAvatar.Slot.DROP
	return movement_enabled and drop_allowed and _touch_drop_queued


func consume_drop() -> bool:
	if not movement_enabled:
		_touch_drop_queued = false
		return false
	var requested := drop_requested()
	_touch_drop_queued = false
	return requested


func up_held() -> bool:
	var movement_allowed := not _tutorial_restricted or _tutorial_movement_allowed
	return movement_enabled and movement_allowed and (
		Input.is_action_pressed(&"move_up")
		or touch_move.y <= -TOUCH_STICK_RADIUS * 0.65
	)


func drop_held() -> bool:
	# Stick-down no longer drops through platforms; that is the Drop button.
	# Keyboard S still works on desktop.
	var drop_allowed := not _tutorial_restricted or _tutorial_allowed_slot == PlayerAvatar.Slot.DROP
	return movement_enabled and drop_allowed and Input.is_action_pressed(&"move_down")


func clear_touch_state() -> void:
	touch_move = Vector2.ZERO
	touch_aim = Vector2.ZERO
	touch_attack = false
	_touch_jump_queued = false
	_touch_drop_queued = false


func set_tutorial_restrictions(movement_allowed: bool, allowed_slot: int) -> void:
	_tutorial_restricted = true
	_tutorial_movement_allowed = movement_allowed
	_tutorial_allowed_slot = allowed_slot
	if not movement_allowed:
		touch_move = Vector2.ZERO
	if allowed_slot != PlayerAvatar.Slot.SWORD:
		touch_attack = false
	if allowed_slot != PlayerAvatar.Slot.JUMP:
		_touch_jump_queued = false
	if allowed_slot != PlayerAvatar.Slot.DROP:
		_touch_drop_queued = false


func clear_tutorial_restrictions() -> void:
	_tutorial_restricted = false
	_tutorial_movement_allowed = true
	_tutorial_allowed_slot = -1
