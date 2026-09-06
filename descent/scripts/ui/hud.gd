class_name Hud
extends Control

## Persistent combat readout: vitals, run counters, active upgrades, and the
## boss bar.
##
## Reads from RunState and the player's components via signals, so
## GameplayController only has to tell it about things it cannot observe
## itself (how many enemies are left, which boss is on screen).

const BOSS_BAR_COLOR := Color(0.85, 0.24, 0.35)

var _player: PlayerAvatar
var _catalog: UpgradeCatalog

@onready var _health: StatBar = $Vitals/Health
@onready var _mana: StatBar = $Vitals/Mana
@onready var _floor: Label = $RunInfo/Floor
@onready var _room: Label = $RunInfo/Room
@onready var _modifier: Label = $RunInfo/Modifier
@onready var _coins: Label = $RunInfo/Counters/Coins
@onready var _echoes: Label = $RunInfo/Counters/Echoes
@onready var _objective: Label = $Objective
@onready var _upgrades: VBoxContainer = $Upgrades
@onready var _boss_panel: PanelContainer = $BossPanel
@onready var _boss_name: Label = $BossPanel/Rows/Name
@onready var _boss_bar: StatBar = $BossPanel/Rows/Bar


func _ready() -> void:
	RunState.coins_changed.connect(_on_coins_changed)
	RunState.floor_changed.connect(_on_floor_changed)
	RunState.upgrades_changed.connect(_rebuild_upgrade_list)
	SaveManager.echoes_changed.connect(_on_echoes_changed)

	_boss_bar.fill_color = BOSS_BAR_COLOR
	_boss_panel.hide()
	_on_coins_changed(RunState.coins)
	_on_echoes_changed(SaveManager.echoes_total)


func bind(player: PlayerAvatar, catalog: UpgradeCatalog) -> void:
	_player = player
	_catalog = catalog
	player.health.health_changed.connect(_health.set_values)
	player.mana.mana_changed.connect(_mana.set_values)
	_health.set_values(player.health.current, player.health.maximum)
	_mana.set_values(player.mana.current, player.mana.maximum)
	_rebuild_upgrade_list()


## Called at the start of every floor after its sequential map is loaded.
func refresh_room_header() -> void:
	_on_floor_changed(RunState.floor_number)
	_room.text = "MAP %02d" % RunState.floor_number
	_modifier.hide()


func set_enemies_remaining(count: int) -> void:
	_objective.visible = count > 0
	_objective.text = "ENEMIES REMAINING: %d" % count


func show_objective(text: String) -> void:
	_objective.visible = not text.is_empty()
	_objective.text = text


func show_boss(display_name: String, health: HealthComponent) -> void:
	_boss_name.text = display_name
	_boss_panel.show()
	_boss_bar.set_values(health.current, health.maximum)
	health.health_changed.connect(_boss_bar.set_values)


func hide_boss() -> void:
	_boss_panel.hide()


func _on_coins_changed(coins: int) -> void:
	_coins.text = "COINS  %d" % coins


func _on_echoes_changed(total: int) -> void:
	_echoes.text = "ECHOES  %d" % total


func _on_floor_changed(floor_number: int) -> void:
	_floor.text = "FLOOR %d / %d" % [floor_number, RunState.FINAL_FLOOR]


## Rebuilt wholesale rather than diffed; the list is at most ten short rows and
## only changes when an upgrade is taken.
func _rebuild_upgrade_list() -> void:
	for child in _upgrades.get_children():
		child.queue_free()
	if _catalog == null:
		return

	for upgrade_id: int in RunState.run_upgrades:
		var upgrade := _catalog.by_id(upgrade_id)
		if upgrade == null:
			continue
		var row := Label.new()
		row.text = "x%d  %s" % [RunState.upgrade_level(upgrade_id), upgrade.display_name.to_upper()]
		row.add_theme_font_size_override(&"font_size", 13)
		row.add_theme_color_override(&"font_color", Color("9ad7c6"))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_upgrades.add_child(row)
