@tool
class_name HazardZone
extends Area2D

## A painted-in hazard: the lava channel, the sludge pool, the arcane vent.
##
## Unlike `Hazard`, which is spawned at runtime and telegraphs before it fires,
## this one is authored into a level and is always on. Standing in it costs
## health on a tick rather than every frame, so the damage rate does not depend
## on the physics step.
##
## Set `instant_death` for the ones that are not survivable — the surface of a
## magma lake rather than a grate you can dash across.

const HAZARD_LAYER := 16  # enemy_attacks
const PLAYER_LAYER := 1

@export var size: Vector2 = Vector2(200, 64):
	set(value):
		size = Vector2(maxf(value.x, 8.0), maxf(value.y, 8.0))
		_apply()

@export var damage: float = 14.0
@export var tick_seconds: float = 0.55
@export var instant_death: bool = false:
	set(value):
		instant_death = value
		queue_redraw()

## Retained for old scene compatibility. Monsters are always hazard-immune;
## pits remain lethal through DeathZone instead.
@export var affects_enemies: bool = false:
	set(value):
		affects_enemies = value
		_apply_layers()

## Purely descriptive, so the flavour survives into the editor and the HUD.
@export var hazard_name: String = "LAVA"

var _cooldown: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring = not Engine.is_editor_hint()
	_apply_layers()
	_apply()


func _apply_layers() -> void:
	collision_layer = HAZARD_LAYER
	collision_mask = PLAYER_LAYER


func _apply() -> void:
	if not is_node_ready():
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	var bodies := get_overlapping_bodies()
	if bodies.is_empty():
		return
	_cooldown = tick_seconds

	for body in bodies:
		if not body.has_method("take_damage"):
			continue
		var amount := 99999.0 if instant_death else damage
		body.take_damage(amount, _push_origin(body))


## Damage knocks the victim away from the hazard, so a hit nudges the player out
## of the pool instead of leaving them parked in it.
func _push_origin(body: Node2D) -> Vector2:
	var local := to_local(body.global_position)
	var half := size * 0.5
	# Whichever axis they are closest to escaping along is the one to shove them.
	if absf(local.x) / maxf(half.x, 1.0) > absf(local.y) / maxf(half.y, 1.0):
		return to_global(Vector2(0.0, local.y))
	return to_global(Vector2(local.x, 0.0))


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-size * 0.5, size)
	var tint := Color(1.0, 0.25, 0.2) if instant_death else Color(1.0, 0.55, 0.15)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.22), true)
	draw_rect(rect, tint, false, 2.0)
