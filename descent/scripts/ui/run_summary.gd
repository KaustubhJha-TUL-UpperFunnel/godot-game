class_name RunSummary
extends Control

## End-of-run screen for both outcomes. Reads the already-finalised totals off
## RunState; banking the echoes is RunState.finish_run()'s job, not this
## screen's, so the numbers here are purely a report.

signal continue_requested()

const VICTORY_ACCENT := Color("6fd3a5")
const DEFEAT_ACCENT := Color("ff4f62")

@onready var _title: Label = $Frame/Rows/Title
@onready var _subtitle: Label = $Frame/Rows/Subtitle
@onready var _stats: VBoxContainer = $Frame/Rows/Stats
@onready var _reward: Label = $Frame/Rows/Reward
@onready var _continue: Button = $Frame/Rows/Continue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	hide()


func present(victory: bool) -> void:
	var accent := VICTORY_ACCENT if victory else DEFEAT_ACCENT
	_title.text = "THE DEPTHS ARE CLEARED" if victory else "YOU FELL"
	_title.add_theme_color_override(&"font_color", accent)
	_subtitle.text = (
		"You reached the surface with the Warden's core."
		if victory
		else "Floor %d claimed you. The echoes remain." % RunState.floor_number
	)

	_fill_stats()
	_reward.text = "ECHOES BANKED: %d" % RunState.echoes_earned
	_reward.add_theme_color_override(&"font_color", accent)

	show()
	_continue.grab_focus()


func _fill_stats() -> void:
	for child in _stats.get_children():
		child.queue_free()

	_add_stat("FLOOR REACHED", "%d / %d" % [RunState.floor_number, RunState.FINAL_FLOOR])
	_add_stat("ENEMIES DEFEATED", str(RunState.enemies_defeated))
	_add_stat("COINS COLLECTED", str(RunState.coins_collected))
	_add_stat("DANGER ROOMS CLEARED", str(RunState.danger_rooms_cleared))
	_add_stat("UPGRADES INSTALLED", str(RunState.run_upgrades.size()))


func _add_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override(&"font_size", 15)
	name_label.add_theme_color_override(&"font_color", Color("9fb3bd"))

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override(&"font_size", 17)

	row.add_child(name_label)
	row.add_child(value_label)
	_stats.add_child(row)
