class_name RoomDoor
extends Node2D

## One of the three post-encounter exits. Owns its own click target, proximity
## area, copy labels, and highlight animation, so DoorSelection only has to
## hand it a DoorDestinationData and listen for `chosen`.

signal chosen(door: RoomDoor)
signal player_proximity_changed(door: RoomDoor, is_near: bool)

## Assigned per door in gameplay.tscn; the door configures itself from it.
@export var destination: DoorDestinationData
@export var loot_icon: Texture2D
@export var danger_icon: Texture2D
@export var shop_icon: Texture2D

var data: DoorDestinationData
var is_highlighted: bool = false
var is_selected: bool = false

@onready var _frame: Sprite2D = $Frame
@onready var _icon: Sprite2D = $Icon
@onready var _glow: Sprite2D = $Glow
@onready var _title: Label = $Title
@onready var _risk: Label = $Risk
@onready var _button: Button = $ClickTarget
@onready var _proximity: Area2D = $Proximity
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_button.pressed.connect(func() -> void: chosen.emit(self))
	_proximity.body_entered.connect(_on_proximity_changed.bind(true))
	_proximity.body_exited.connect(_on_proximity_changed.bind(false))
	_animation.play(&"idle")
	if destination != null:
		configure(destination)


func configure(door_destination: DoorDestinationData) -> void:
	data = door_destination
	_title.text = door_destination.display_name
	_title.add_theme_color_override(&"font_color", door_destination.accent)
	_risk.text = door_destination.risk
	_glow.modulate = Color(door_destination.accent, 0.22)

	var texture := _icon_for(door_destination.destination_type)
	if texture != null:
		_icon.texture = texture
		# Normalise every icon to roughly 64px on its long edge.
		var longest := float(maxi(texture.get_width(), texture.get_height()))
		_icon.scale = Vector2.ONE * (64.0 / longest)


func destination_type() -> int:
	return data.destination_type if data != null else RunState.RoomType.LOOT


func _icon_for(destination_type_id: int) -> Texture2D:
	match destination_type_id:
		RunState.RoomType.DANGER:
			return danger_icon
		RunState.RoomType.SHOP:
			return shop_icon
	return loot_icon


func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	_refresh_emphasis()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_refresh_emphasis()


func _refresh_emphasis() -> void:
	var emphasised := is_highlighted or is_selected
	_animation.play(&"highlight" if emphasised else &"idle")
	_frame.modulate = Color(1.15, 1.1, 0.95) if emphasised else Color.WHITE


## Plays the swing-open flourish used while the floor transition covers the screen.
func open() -> void:
	_animation.play(&"open")
	EventBus.burst_requested.emit(
		global_position, data.accent if data != null else Color.WHITE, 22, 175.0, 4.0
	)


func _on_proximity_changed(body: Node2D, is_near: bool) -> void:
	if body.is_in_group(&"player"):
		player_proximity_changed.emit(self, is_near)
