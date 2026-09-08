class_name MainMenu
extends Control

## Hub between runs: start a descent, spend echoes on permanent tracks, quit.

@onready var _descend: Button = $Panel/Rows/Descend
@onready var _upgrades_button: Button = $Panel/Rows/Upgrades
@onready var _tutorial_button: Button = $Panel/Rows/Tutorial
@onready var _quit: Button = $Panel/Rows/Quit
@onready var _echoes: Label = $Panel/Rows/Echoes
@onready var _best: Label = $Panel/Rows/Best
@onready var _permanent: PermanentUpgrades = $PermanentUpgrades


func _ready() -> void:
	_descend.pressed.connect(func() -> void: SceneRouter.goto_gameplay())
	_upgrades_button.pressed.connect(_permanent.open)
	_tutorial_button.pressed.connect(_start_tutorial)
	_quit.pressed.connect(func() -> void: SceneRouter.quit_game())
	_permanent.closed.connect(_descend.grab_focus)
	SaveManager.echoes_changed.connect(_on_echoes_changed)

	# Desktop builds get a quit button; on mobile the OS owns that gesture.
	_quit.visible = not OS.has_feature("mobile")
	_on_echoes_changed(SaveManager.echoes_total)
	_best.text = _unlock_summary()
	_descend.grab_focus()


func _start_tutorial() -> void:
	SaveManager.restart_tutorial()
	SceneRouter.goto_gameplay()


func _on_echoes_changed(total: int) -> void:
	_echoes.text = "ECHOES: %d" % total
	_best.text = _unlock_summary()


func _unlock_summary() -> String:
	var unlocked: Array[String] = []
	for index in SaveManager.track_count():
		if SaveManager.level(index) > 0:
			unlocked.append(SaveManager.TRACKS[index]["name"])
	if unlocked.is_empty():
		return "NO PERMANENT UPGRADES INSTALLED"
	return "ACTIVE: %s" % ", ".join(unlocked)
