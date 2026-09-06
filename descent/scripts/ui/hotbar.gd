class_name Hotbar
extends Control

## The six ability slots along the bottom of the screen.
##
## Clicking a slot goes through the same PlayerAvatar.activate_slot() path as
## the keyboard, so mouse-only and keyboard play behave identically.

signal slot_pressed(index: int)

var _player: PlayerAvatar
var _slots: Array[HotbarSlot] = []

@onready var _row: HBoxContainer = $Row


func _ready() -> void:
	for child in _row.get_children():
		if child is HotbarSlot:
			var slot: HotbarSlot = child
			_slots.append(slot)
			slot.activated.connect(_on_slot_activated)
	set_process(false)


func bind(player: PlayerAvatar) -> void:
	_player = player
	set_process(player != null)


func _process(_delta: float) -> void:
	if _player == null:
		return
	for slot in _slots:
		slot.set_cooldown(
			_player.slot_cooldown_ratio(slot.slot_index),
			_player.slot_cooldown_seconds(slot.slot_index)
		)
		slot.set_charges(_player.slot_charges(slot.slot_index))


func _on_slot_activated(index: int) -> void:
	slot_pressed.emit(index)
	if _player == null:
		return
	_player.activate_slot(index)
	for slot in _slots:
		if slot.slot_index == index:
			slot.flash_use()
