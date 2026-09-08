class_name UpgradeCard
extends PanelContainer

## One of the three reward choices. Colour, border, and visual icon come from
## the upgrade's purpose and rarity so the player can immediately read the value
## and function of a card before reading its text.

signal chosen(upgrade: UpgradeData)

const RARITY_COLORS := {
	"COMMON": Color("9fb3bd"),
	"UNCOMMON": Color("6fd3a5"),
	"RARE": Color("ffd26a"),
}

const RARITY_STARS := {
	"COMMON": "★ COMMON ★",
	"UNCOMMON": "★★ UNCOMMON ★★",
	"RARE": "★★★ RARE ★★★",
}

const UPGRADE_METADATA := {
	0: {
		"category": "OFFENSE",
		"stat": "+25% WEAPON DAMAGE",
		"tag_color": Color("ff5252"),
	},
	1: {
		"category": "ATTACK SPEED",
		"stat": "+15% ATK SPEED",
		"tag_color": Color("ffb142"),
	},
	2: {
		"category": "PROJECTILE SPEED",
		"stat": "+30% SHOT SPEED",
		"tag_color": Color("ff793f"),
	},
	3: {
		"category": "MULTI-SHOT",
		"stat": "+1 PROJECTILE",
		"tag_color": Color("ff5252"),
	},
	4: {
		"category": "MOBILITY",
		"stat": "+15% MOVE SPEED",
		"tag_color": Color("2ed573"),
	},
	5: {
		"category": "DASH COOLDOWN",
		"stat": "-20% DASH CD",
		"tag_color": Color("1e90ff"),
	},
	6: {
		"category": "VITALITY",
		"stat": "+25 MAX HP (+14 HEAL)",
		"tag_color": Color("ff4757"),
	},
	7: {
		"category": "PIERCE",
		"stat": "+1 PROJECTILE PIERCE",
		"tag_color": Color("a55eea"),
	},
	8: {
		"category": "RICOCHET",
		"stat": "+20% RICOCHET CHANCE",
		"tag_color": Color("eccc68"),
	},
	9: {
		"category": "REGENERATION",
		"stat": "+4 HP / ROOM CLEAR",
		"tag_color": Color("2ed573"),
	},
}

var upgrade: UpgradeData

@onready var _rarity: Label = $Rows/RarityHeader/Rarity
@onready var _category_label: Label = $Rows/CategoryPill/CategoryLabel
@onready var _icon: UpgradeIcon = $Rows/IconContainer/UpgradeIcon
@onready var _name: Label = $Rows/Name
@onready var _stat_label: Label = $Rows/StatBanner/StatLabel
@onready var _stat_banner: PanelContainer = $Rows/StatBanner
@onready var _description: Label = $Rows/Description
@onready var _stacks: Label = $Rows/Stacks
@onready var _take: Button = $Rows/Take
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_take.focus_mode = Control.FOCUS_NONE
	_take.pressed.connect(_on_take_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(data: UpgradeData) -> void:
	upgrade = data
	visible = data != null
	if data == null:
		return

	var accent: Color = RARITY_COLORS.get(data.rarity, RARITY_COLORS["COMMON"])
	var rarity_text: String = RARITY_STARS.get(data.rarity, data.rarity)
	_rarity.text = rarity_text
	_rarity.add_theme_color_override(&"font_color", accent)

	var meta: Dictionary = UPGRADE_METADATA.get(data.upgrade_id, {
		"category": "UPGRADE",
		"stat": data.description.to_upper(),
		"tag_color": accent,
	})

	_category_label.text = meta.get("category", "UPGRADE")
	_category_label.add_theme_color_override(
		&"font_color", meta.get("tag_color", accent).lightened(0.3)
	)

	_stat_label.text = meta.get("stat", data.description.to_upper())
	_stat_label.add_theme_color_override(&"font_color", meta.get("tag_color", accent))

	_name.text = data.display_name.to_upper()
	_name.add_theme_color_override(&"font_color", accent)
	_description.text = data.description

	_icon.configure(data.upgrade_id, data.rarity)

	# Update card border style to match rarity and category theme
	var style := get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if style != null:
		style.border_color = accent.lerp(meta.get("tag_color", accent), 0.28)
		add_theme_stylebox_override(&"panel", style)

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
	_take.release_focus()
	_animation.play(&"take")
	chosen.emit(upgrade)


func _on_mouse_entered() -> void:
	if not _take.disabled:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
