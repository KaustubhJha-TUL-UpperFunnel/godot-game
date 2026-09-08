class_name AnimatedMonster
extends EnemyBase

## Runtime-backed enemy using the numbered movement and attack image sequences
## in assets/animations. Keeping one scene for all variants makes adding a new
## monster folder enough to put that monster into the floor rotation.

const MOVEMENT_ROOT := "res://descent/assets/animations/movement"
const ATTACK_ROOT := "res://descent/assets/animations/attacks"
const MAX_SEQUENCE_FRAMES := 16

@export_range(1, 18, 1) var monster_id: int = 1
@export var attack_range: float = 62.0
@export var attack_interval: float = 1.05

var _attacking: bool = false
var _visual_foot_offset: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func configure_variant(id: int) -> void:
	monster_id = clampi(id, 1, 18)


func _on_ready_configured() -> void:
	_build_animations()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_align_current_frame_to_feet)
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
	if distance <= attack_range and _attack_timer <= 0.0:
		_attacking = true
		_attack_timer = attack_interval
		_sprite.play(&"attack")
		return Vector2.ZERO
	if _sprite.animation != &"move":
		_sprite.play(&"move")
	return direction * speed


func can_damage_player() -> bool:
	if not _attacking or _sprite.animation != &"attack":
		return false
	var frame_count := _sprite.sprite_frames.get_frame_count(&"attack")
	return _sprite.frame >= maxi(1, int(frame_count * 0.45))


func _on_animation_finished() -> void:
	if _sprite.animation != &"attack":
		return
	_attacking = false
	_sprite.play(&"move")


func _impact_color() -> Color:
	return Color(0.82, 0.35, 0.25)


func _death_color() -> Color:
	return Color(0.5, 0.12, 0.18)
