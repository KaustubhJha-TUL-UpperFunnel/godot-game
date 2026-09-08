class_name AnimatedMonster
extends EnemyBase

## Runtime-backed enemy using the numbered movement and attack image sequences
## in assets/animations. Keeping one scene for all variants makes adding a new
## monster folder enough to put that monster into the floor rotation.

const MOVEMENT_ROOT := "res://descent/assets/animations/movement"
const ATTACK_ROOT := "res://descent/assets/animations/attacks"
const MAX_SEQUENCE_FRAMES := 16
const MELEE_RANGE := 62.0
const RANGED_CONFIGS := {
	2: {
		"visual": Projectile.Visual.ARROW,
		"range": 460.0,
		"interval": 1.55,
		"damage_scale": 0.9,
		"origin_y": -34.0,
	},
	6: {
		"visual": Projectile.Visual.PURPLE_ORB,
		"range": 420.0,
		"interval": 1.7,
		"damage_scale": 0.85,
		"origin_y": -48.0,
	},
	7: {
		"visual": Projectile.Visual.DRAGON_FIRE,
		"range": 390.0,
		"interval": 1.85,
		"damage_scale": 1.0,
		"origin_y": -30.0,
	},
	10: {
		"visual": Projectile.Visual.BLUE_SKULL,
		"range": 440.0,
		"interval": 1.75,
		"damage_scale": 0.9,
		"origin_y": -42.0,
	},
	16: {
		"visual": Projectile.Visual.RED_ORB,
		"range": 430.0,
		"interval": 1.65,
		"damage_scale": 0.95,
		"origin_y": -48.0,
	},
}

@export_range(1, 18, 1) var monster_id: int = 1
@export var attack_range: float = 62.0
@export var attack_interval: float = 1.05

var _attacking: bool = false
var _ranged_attack: bool = false
var _shot_fired: bool = false
var _visual_foot_offset: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func configure_variant(id: int) -> void:
	monster_id = clampi(id, 1, 18)


func _on_ready_configured() -> void:
	_build_animations()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_align_current_frame_to_feet)
	_sprite.frame_changed.connect(_on_attack_frame_changed)
	_sprite.play(&"move")
	_align_current_frame_to_feet()

	# Small stat differences keep the eighteen visual variants readable without
	# reintroducing the old hard-coded slime/goblin/sorcerer archetypes.
	speed = 108.0 + float(monster_id % 5) * 7.0
	base_damage = 8.0 + float(monster_id % 4)
	contact_damage = base_damage
	coin_reward = 2 + int(monster_id / 6.0)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"move")
	frames.set_animation_loop(&"move", true)
	frames.set_animation_speed(&"move", 10.0)
	frames.add_animation(&"attack")
	frames.set_animation_loop(&"attack", false)
	frames.set_animation_speed(&"attack", 13.0)

	var move_first := _append_sequence(frames, &"move", MOVEMENT_ROOT)
	_append_sequence(frames, &"attack", ATTACK_ROOT)
	_sprite.sprite_frames = frames

	if move_first != null:
		var height := maxf(1.0, float(move_first.get_height()))
		var visual_scale := clampf(82.0 / height, 0.68, 1.2)
		_sprite.scale = Vector2.ONE * visual_scale
		var body_radius := clampf(
			float(move_first.get_width()) * visual_scale * 0.22, 16.0, 27.0
		)
		var visual_height := _maximum_frame_height(frames) * visual_scale
		var capsule := CapsuleShape2D.new()
		capsule.radius = body_radius
		capsule.height = maxf(body_radius * 2.0, visual_height)
		_body_shape.shape = capsule
		# Keep the capsule's bottom at the floor while extending its hit area up
		# through the visible torso instead of leaving a tiny circle at the feet.
		_body_shape.position.y = body_radius - capsule.height * 0.5
		_visual_foot_offset = body_radius
		_align_current_frame_to_feet()
		projectile_radius = body_radius + 6.0
		contact_radius = body_radius + 24.0
		health_bar_height = visual_height - body_radius + 12.0
		_health_bar.position.y = -health_bar_height


func _append_sequence(
	frames: SpriteFrames, animation: StringName, root: String
) -> Texture2D:
	var first: Texture2D = null
	for frame_number in range(1, MAX_SEQUENCE_FRAMES + 1):
		var path := "%s/monster-%d/%d.png" % [root, monster_id, frame_number]
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		if first == null:
			first = texture
		frames.add_frame(animation, texture)
	return first


func _maximum_frame_height(frames: SpriteFrames) -> float:
	var maximum := 1.0
	for animation in [&"move", &"attack"]:
		for frame_index in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, frame_index)
			if texture != null:
				maximum = maxf(maximum, float(texture.get_height()))
	return maximum


## Source frames have different canvas sizes. Repositioning every frame around
## its bottom edge keeps the monster's feet fixed on the physics body.
func _align_current_frame_to_feet() -> void:
	if _sprite.sprite_frames == null:
		return
	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture != null:
		_sprite.position = Vector2(
			0.0,
			_visual_foot_offset - float(texture.get_height()) * _sprite.scale.y * 0.5
		)


func _steer(_delta: float, direction: Vector2, distance: float) -> Vector2:
	_sprite.flip_h = direction.x < 0.0
	if _attacking:
		return Vector2.ZERO
	if _attack_timer <= 0.0:
		if distance <= MELEE_RANGE:
			_begin_attack(direction, false)
			return Vector2.ZERO
		if _has_ranged_attack() and distance <= _ranged_range():
			_begin_attack(direction, true)
			return Vector2.ZERO
	if _has_ranged_attack() and distance > MELEE_RANGE and distance <= _ranged_range():
		return Vector2.ZERO
	if _sprite.animation != &"move":
		_sprite.play(&"move")
	return direction * speed


func _begin_attack(direction: Vector2, ranged: bool) -> void:
	_attacking = true
	_ranged_attack = ranged
	_shot_fired = false
	locked_direction = direction
	_attack_timer = _ranged_interval() if ranged else attack_interval
	if ranged:
		_show_telegraph(direction, minf(120.0, _ranged_range()), 3.0)
	else:
		_hide_telegraph()
	_sprite.play(&"attack")


func can_damage_player() -> bool:
	if _ranged_attack or not _attacking or _sprite.animation != &"attack":
		return false
	var frame_count := _sprite.sprite_frames.get_frame_count(&"attack")
	return _sprite.frame >= maxi(1, int(frame_count * 0.45))


func _on_attack_frame_changed() -> void:
	if (
		not _attacking
		or not _ranged_attack
		or _shot_fired
		or _sprite.animation != &"attack"
	):
		return
	var frame_count := _sprite.sprite_frames.get_frame_count(&"attack")
	if _sprite.frame < maxi(1, int(float(frame_count) * 0.55)):
		return
	_shot_fired = true
	_hide_telegraph()
	var config: Dictionary = RANGED_CONFIGS[monster_id]
	var origin := (
		global_position
		+ Vector2(0.0, float(config["origin_y"]))
		+ locked_direction * 24.0
	)
	shot_requested.emit(
		origin,
		locked_direction,
		contact_damage * float(config["damage_scale"]),
		int(config["visual"])
	)


func _on_animation_finished() -> void:
	if _sprite.animation != &"attack":
		return
	_attacking = false
	_ranged_attack = false
	_shot_fired = false
	_hide_telegraph()
	_sprite.play(&"move")


func _has_ranged_attack() -> bool:
	return RANGED_CONFIGS.has(monster_id)


func _ranged_range() -> float:
	if not _has_ranged_attack():
		return 0.0
	return float((RANGED_CONFIGS[monster_id] as Dictionary)["range"])


func _ranged_interval() -> float:
	if not _has_ranged_attack():
		return attack_interval
	return float((RANGED_CONFIGS[monster_id] as Dictionary)["interval"]) / difficulty_pressure


func _impact_color() -> Color:
	return Color(0.82, 0.35, 0.25)


func _death_color() -> Color:
	return Color(0.5, 0.12, 0.18)
