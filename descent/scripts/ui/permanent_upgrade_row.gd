class_name PermanentUpgradeRow
extends PanelContainer

## One permanent progression track in the main menu. Pips show the levels
## bought so far; the button shows the next price.

signal buy_requested(track_index: int)

var track_index: int = 0

@onready var _name: Label = $Rows/Header/Name
@onready var _description: Label = $Rows/Description
@onready var _pips: HBoxContainer = $Rows/Header/Pips
@onready var _buy: Button = $Rows/Buy


func _ready() -> void:
	_buy.custom_minimum_size.y = 44.0
	_buy.pressed.connect(_request_buy)


func bind(index: int) -> void:
	track_index = index
	var track: Dictionary = SaveManager.TRACKS[index]
	_name.text = track["name"]
	_description.text = track["description"]
	_build_pips(track["max_level"])
	refresh()


func refresh() -> void:
	var owned := SaveManager.level(track_index)
	for pip_index in _pips.get_child_count():
		var pip: ColorRect = _pips.get_child(pip_index)
		pip.color = Color("ffd26a") if pip_index < owned else Color(0.16, 0.19, 0.23)

	if SaveManager.is_maxed(track_index):
		_buy.text = "MAXED"
		_buy.disabled = true
		return
	_buy.text = "%d ECHOES" % SaveManager.cost(track_index)
	_buy.disabled = not SaveManager.can_afford(track_index)


func _request_buy() -> void:
	if _buy.disabled:
		return
	buy_requested.emit(track_index)


func _build_pips(max_level: int) -> void:
	for child in _pips.get_children():
		child.queue_free()
	for _index in max_level:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 8)
		pip.color = Color(0.16, 0.19, 0.23)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)
