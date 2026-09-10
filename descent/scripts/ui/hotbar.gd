class_name Hotbar
extends Control

## Action cluster in the bottom-right: a large sword, with fire/ice at its
## top-left, potions above, and jump/dash/drop underneath.

signal slot_pressed(index: int)

var _player: PlayerAvatar
var _slots: Array[HotbarSlot] = []


func _ready() -> void:
	for child in get_children():
		if child is HotbarSlot:
			var slot: HotbarSlot = child
			_slots.append(slot)
			slot.activated.connect(_on_slot_activated)
			slot.hold_changed.connect(_on_slot_hold_changed)
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
	# Fire aims on hold and casts on release. Sword fires on finger-down so
	# a tap does not also swing again when the button comes up.
	if index != PlayerAvatar.Slot.FIRE and index != PlayerAvatar.Slot.SWORD:
		_player.activate_slot(index)
	if index == PlayerAvatar.Slot.SWORD:
		return
	for slot in _slots:
		if slot.slot_index == index:
			slot.flash_use()


func _on_slot_hold_changed(index: int, held: bool) -> void:
	if _player == null:
		return
	match index:
		PlayerAvatar.Slot.SWORD:
			if held:
				_player.activate_slot(PlayerAvatar.Slot.SWORD)
				for slot in _slots:
					if slot.slot_index == index:
						slot.flash_use()
		PlayerAvatar.Slot.FIRE:
			if held:
				_player.begin_projectile_aim()
			else:
				_player.release_projectile_aim()


func set_tutorial_slot(allowed_slot: int) -> void:
	for slot in _slots:
		var enabled := slot.slot_index == allowed_slot
		slot.set_tutorial_enabled(enabled, enabled)


func clear_tutorial_slot() -> void:
	for slot in _slots:
		slot.set_tutorial_enabled(true)


func tutorial_icon(slot_index: int) -> Texture2D:
	for slot in _slots:
		if slot.slot_index == slot_index:
			return slot.tutorial_icon()
	return null
