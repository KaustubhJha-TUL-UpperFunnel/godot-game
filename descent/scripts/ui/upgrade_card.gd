class_name UpgradeCard
extends PanelContainer

## One of the three reward choices. Colour and border come from the upgrade's
## rarity so the player can read the value of a card before reading its text.

signal chosen(upgrade: UpgradeData)

const RARITY_COLORS := {
	"COMMON": Color("9fb3bd"),
	"UNCOMMON": Color("6fd3a5"),
	"RARE": Color("ffd26a"),
}

var upgrade: UpgradeData

@onready var _rarity: Label = $Rows/Rarity
@onready var _name: Label = $Rows/Name
@onready var _description: Label = $Rows/Description
@onready var _stacks: Label = $Rows/Stacks
@onready var _take: Button = $Rows/Take
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_take.pressed.connect(_on_take_pressed)


func configure(data: UpgradeData) -> void:
	upgrade = data
	visible = data != null
	if data == null:
		return

	var accent: Color = RARITY_COLORS.get(data.rarity, RARITY_COLORS["COMMON"])
	_rarity.text = data.rarity
	_rarity.add_theme_color_override(&"font_color", accent)
	_name.text = data.display_name.to_upper()
	_name.add_theme_color_override(&"font_color", accent)
	_description.text = data.description

	var owned := RunState.upgrade_level(data.upgrade_id)
	_stacks.visible = owned > 0
	_stacks.text = "OWNED x%d" % owned


## Staggered so the three cards deal in one after another.
func reveal(delay: float) -> void:
	modulate.a = 0.0
	_take.disabled = true
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	_take.disabled = false
	_animation.play(&"deal")


## Stops the other two cards being clicked once a choice is committed.
func lock() -> void:
	_take.disabled = true


func _on_take_pressed() -> void:
	if upgrade == null:
		return
	_take.disabled = true
	_animation.play(&"take")
	chosen.emit(upgrade)
