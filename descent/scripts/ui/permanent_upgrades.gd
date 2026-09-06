class_name PermanentUpgrades
extends Control

## The between-runs shop for permanent tracks. Rows are built from
## SaveManager.TRACKS so adding a track needs no scene edits.

signal closed()

@export var row_scene: PackedScene

var _rows: Array[PermanentUpgradeRow] = []

@onready var _list: VBoxContainer = $Frame/Rows/List
@onready var _echoes: Label = $Frame/Rows/Echoes
@onready var _close: Button = $Frame/Rows/Close


func _ready() -> void:
	_close.pressed.connect(_on_close_pressed)
	SaveManager.echoes_changed.connect(_on_echoes_changed)
	SaveManager.permanent_changed.connect(func(_index: int, _level: int) -> void: _refresh())
	_build_rows()
	hide()


func open() -> void:
	_refresh()
	show()
	_close.grab_focus()


func _build_rows() -> void:
	if row_scene == null:
		return
	for index in SaveManager.track_count():
		var row: PermanentUpgradeRow = row_scene.instantiate()
		_list.add_child(row)
		row.bind(index)
		row.buy_requested.connect(_on_buy_requested)
		_rows.append(row)


func _refresh() -> void:
	_on_echoes_changed(SaveManager.echoes_total)
	for row in _rows:
		row.refresh()


func _on_echoes_changed(total: int) -> void:
	_echoes.text = "ECHOES: %d" % total


func _on_buy_requested(track_index: int) -> void:
	SaveManager.buy_permanent(track_index)


func _on_close_pressed() -> void:
	hide()
	closed.emit()
