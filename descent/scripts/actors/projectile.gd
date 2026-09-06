class_name Projectile
extends Area2D

## Every bolt in the game: the player's fireball and the sorcerer/boss shots.
##
## Collision layers are assigned in setup() from the `friendly` flag, so one
## scene covers both directions of fire. Actors are recognised by having a
## take_hit() method; anything else it touches is treated as wall geometry.

enum Element { PLAIN, FIRE, ICE }

const ELEMENT_COLORS := {
	Element.PLAIN: Color("58e6ff"),
	Element.FIRE: Color("ff6622"),
	Element.ICE: Color("66eeff"),
}

const HOSTILE_COLOR := Color("ff4f62")
const FRIENDLY_LIFETIME := 1.7
const HOSTILE_LIFETIME := 3.2
const FRIENDLY_RADIUS := 5.0
const HOSTILE_RADIUS := 6.5

# Layer bits from project.godot: player=1, enemies=2, walls=3,
# player_attacks=4, enemy_attacks=5.
const LAYER_PLAYER := 1
const LAYER_ENEMIES := 2
const LAYER_WALLS := 4
const LAYER_PLAYER_ATTACKS := 8
const LAYER_ENEMY_ATTACKS := 16

var friendly: bool = true
var damage: float = 10.0
var pierce: int = 0
var ricochets: int = 0
var element: Element = Element.PLAIN
var bounds: Rect2 = Rect2(105, 380, 1070, 240)

var _velocity: Vector2 = Vector2.RIGHT
var _life_left: float = FRIENDLY_LIFETIME
var _radius: float = FRIENDLY_RADIUS

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _core: Sprite2D = $Core
@onready var _glow: Sprite2D = $Glow
@onready var _trail: Line2D = $Trail


func setup(
	is_friendly: bool,
	spawn_position: Vector2,
	shot_velocity: Vector2,
	shot_damage: float,
	shot_pierce: int = 0,
	shot_ricochets: int = 0,
	shot_element: Element = Element.PLAIN
) -> void:
	friendly = is_friendly
	global_position = spawn_position
	_velocity = shot_velocity
	damage = shot_damage
	pierce = shot_pierce
	ricochets = shot_ricochets
	element = shot_element
	_life_left = FRIENDLY_LIFETIME if friendly else HOSTILE_LIFETIME
	_radius = FRIENDLY_RADIUS if friendly else HOSTILE_RADIUS

	if friendly:
		collision_layer = LAYER_PLAYER_ATTACKS
		collision_mask = LAYER_ENEMIES | LAYER_WALLS
	else:
		collision_layer = LAYER_ENEMY_ATTACKS
		collision_mask = LAYER_PLAYER | LAYER_WALLS


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_appearance()
	rotation = _velocity.angle()


func _apply_appearance() -> void:
	var color: Color = ELEMENT_COLORS[element] if friendly else HOSTILE_COLOR
	var sprite_scale := _radius / 16.0
	_core.scale = Vector2.ONE * sprite_scale
	_glow.scale = Vector2.ONE * sprite_scale * 1.6
	_glow.modulate = Color(color, 0.55)
	_core.modulate = color
	_trail.default_color = Color(color, 0.6)
	_trail.width = _radius * 1.5
	_shape.shape.radius = _radius


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		_expire(false)
		return

	global_position += _velocity * delta
	rotation = _velocity.angle()

	if not bounds.has_point(global_position):
		_hit_boundary()


## Reflects off the arena edge when the projectile has ricochets left,
## otherwise fizzles out.
func _hit_boundary() -> void:
	if not friendly or ricochets <= 0:
		_expire(true)
		return
	ricochets -= 1
	if global_position.x < bounds.position.x or global_position.x > bounds.end.x:
		_velocity.x *= -1.0
	if global_position.y < bounds.position.y or global_position.y > bounds.end.y:
		_velocity.y *= -1.0
	global_position.x = clampf(global_position.x, bounds.position.x + 2.0, bounds.end.x - 2.0)
	global_position.y = clampf(global_position.y, bounds.position.y + 2.0, bounds.end.y - 2.0)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_hit"):
		_hit_wall()
		return

	body.take_hit(damage, _velocity.normalized(), _damage_style())
	EventBus.burst_requested.emit(global_position, _color(), 5, 100.0, 2.5)
	if friendly:
		EventBus.shake_requested.emit(2.0, 0.06)

	if pierce > 0:
		pierce -= 1
		global_position += _velocity.normalized() * 12.0
	else:
		_expire(false)


func _hit_wall() -> void:
	if friendly and ricochets > 0:
		ricochets -= 1
		_velocity = -_velocity
		global_position += _velocity.normalized() * 12.0
		return
	_expire(true)


func _expire(spark: bool) -> void:
	if spark:
		EventBus.burst_requested.emit(global_position, _color(), 4, 65.0, 2.0)
	queue_free()


func _color() -> Color:
	return ELEMENT_COLORS[element] if friendly else HOSTILE_COLOR


func _damage_style() -> int:
	if not friendly:
		return EventBus.DamageStyle.PLAYER_HURT
	match element:
		Element.FIRE:
			return EventBus.DamageStyle.FIRE
		Element.ICE:
			return EventBus.DamageStyle.ICE
	return EventBus.DamageStyle.NORMAL
