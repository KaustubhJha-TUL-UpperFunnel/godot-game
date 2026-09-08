class_name UpgradeIcon
extends Control

## Procedural visual icon for each upgrade. Renders clean, high-contrast,
## stylized vector iconography clearly communicating what the upgrade does.

var upgrade_id: int = 0
var rarity: String = "COMMON"

const RARITY_ACCENTS := {
	"COMMON": Color("9fb3bd"),
	"UNCOMMON": Color("6fd3a5"),
	"RARE": Color("ffd26a"),
}

const CATEGORY_COLORS := {
	0: Color("ff5252"), # Copper Bore - Damage
	1: Color("ffb142"), # Rapid Relay - Atk Speed
	2: Color("ff793f"), # Accelerator - Shot Speed
	3: Color("ff5252"), # Split Chamber - Multi-shot
	4: Color("2ed573"), # Fleet Gears - Move Speed
	5: Color("1e90ff"), # Dash Coils - Dash CD
	6: Color("ff4757"), # Vital Casing - Max HP
	7: Color("a55eea"), # Phase Needle - Pierce
	8: Color("eccc68"), # Ricochet Core - Ricochet
	9: Color("2ed573"), # Recovery Loop - Room Heal
}


func configure(id: int, item_rarity: String) -> void:
	upgrade_id = id
	rarity = item_rarity
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.5)
	var radius := minf(w, h) * 0.44

	var theme_color: Color = CATEGORY_COLORS.get(upgrade_id, Color.WHITE)
	var rarity_accent: Color = RARITY_ACCENTS.get(rarity, Color("9fb3bd"))

	# Outer glowing aura
	draw_circle(center, radius + 4.0, Color(theme_color.r, theme_color.g, theme_color.b, 0.16))
	draw_circle(center, radius + 2.0, Color(theme_color.r, theme_color.g, theme_color.b, 0.28))

	# Dark badge backplate
	draw_circle(center, radius, Color(0.04, 0.065, 0.095, 0.96))

	# Badge border with rarity-tinted theme color
	var border_color := theme_color.lerp(rarity_accent, 0.35)
	draw_arc(center, radius, 0.0, TAU, 36, border_color, 2.2, true)

	# Inner subtle ring
	draw_arc(center, radius - 4.0, 0.0, TAU, 32, Color(theme_color.r, theme_color.g, theme_color.b, 0.22), 1.0, true)

	# Draw specific iconography
	match upgrade_id:
		0:
			_draw_damage(center)
		1:
			_draw_attack_speed(center)
		2:
			_draw_projectile_speed(center)
		3:
			_draw_split_chamber(center)
		4:
			_draw_move_speed(center)
		5:
			_draw_dash_coils(center)
		6:
			_draw_vital_casing(center)
		7:
			_draw_phase_needle(center)
		8:
			_draw_ricochet_core(center)
		9:
			_draw_recovery_loop(center)
		_:
			_draw_generic(center)


func _draw_damage(c: Vector2) -> void:
	# Downward sword blade
	var tip := c + Vector2(0.0, 17.0)
	var left_shoulder := c + Vector2(-5.0, -5.0)
	var right_shoulder := c + Vector2(5.0, -5.0)
	var blade_pts := PackedVector2Array([left_shoulder, right_shoulder, tip])
	draw_polygon(blade_pts, PackedColorArray([Color(0.85, 0.92, 1.0), Color(0.85, 0.92, 1.0), Color(1.0, 1.0, 1.0)]))
	# Blade fuller line
	draw_line(c + Vector2(0.0, -5.0), c + Vector2(0.0, 12.0), Color(0.55, 0.65, 0.75), 1.2, true)
	# Crossguard
	draw_line(c + Vector2(-11.0, -5.0), c + Vector2(11.0, -5.0), Color(1.0, 0.8, 0.3), 3.0, true)
	# Grip and pommel
	draw_line(c + Vector2(0.0, -5.0), c + Vector2(0.0, -14.0), Color(0.7, 0.5, 0.25), 2.2, true)
	draw_circle(c + Vector2(0.0, -15.0), 2.5, Color(1.0, 0.8, 0.3))

	# Fiery damage slash wave cutting across
	draw_arc(c + Vector2(-2.0, 3.0), 16.0, -0.9, 1.2, 16, Color(1.0, 0.2, 0.2, 0.95), 3.0, true)
	draw_arc(c + Vector2(-2.0, 3.0), 20.0, -0.6, 0.9, 14, Color(1.0, 0.65, 0.2, 0.7), 1.8, true)
	# Spark burst
	draw_circle(c + Vector2(10.0, 8.0), 2.0, Color(1.0, 0.9, 0.4))
	draw_circle(c + Vector2(-11.0, -2.0), 1.6, Color(1.0, 0.9, 0.4))


func _draw_attack_speed(c: Vector2) -> void:
	# Twin swift daggers crossed
	# Blade 1 (top-left to bottom-right)
	draw_line(c + Vector2(-13.0, -13.0), c + Vector2(11.0, 11.0), Color(1.0, 0.9, 0.4), 2.6, true)
	draw_line(c + Vector2(11.0, 11.0), c + Vector2(16.0, 16.0), Color(1.0, 1.0, 0.8), 3.2, true)
	# Blade 2 (top-right to bottom-left)
	draw_line(c + Vector2(13.0, -13.0), c + Vector2(-11.0, 11.0), Color(1.0, 0.75, 0.25), 2.6, true)
	draw_line(c + Vector2(-11.0, 11.0), c + Vector2(-16.0, 16.0), Color(1.0, 0.95, 0.6), 3.2, true)
	# Center flash
	draw_circle(c, 3.2, Color(1.0, 1.0, 1.0))

	# Rapid slash motion streaks
	draw_arc(c, 19.0, -2.2, -1.2, 10, Color(1.0, 0.85, 0.3, 0.8), 2.0, true)
	draw_arc(c, 19.0, 0.9, 1.9, 10, Color(1.0, 0.85, 0.3, 0.8), 2.0, true)
	draw_line(c + Vector2(-18.0, 2.0), c + Vector2(-9.0, 7.0), Color(1.0, 1.0, 0.5, 0.7), 1.5, true)
	draw_line(c + Vector2(9.0, -7.0), c + Vector2(18.0, -2.0), Color(1.0, 1.0, 0.5, 0.7), 1.5, true)


func _draw_projectile_speed(c: Vector2) -> void:
	# High-velocity fireball rocketing forward to the right
	# Speed streaks trailing behind to the left
	draw_line(c + Vector2(-22.0, -6.0), c + Vector2(-4.0, -6.0), Color(1.0, 0.5, 0.1, 0.5), 1.5, true)
	draw_line(c + Vector2(-24.0, 0.0), c + Vector2(0.0, 0.0), Color(1.0, 0.7, 0.2, 0.7), 2.2, true)
	draw_line(c + Vector2(-22.0, 6.0), c + Vector2(-4.0, 6.0), Color(1.0, 0.5, 0.1, 0.5), 1.5, true)

	# Flame outer corona
	draw_circle(c + Vector2(5.0, 0.0), 10.0, Color(1.0, 0.35, 0.05, 0.85))
	# Inner glowing fire core
	draw_circle(c + Vector2(6.0, 0.0), 6.5, Color(1.0, 0.75, 0.2))
	draw_circle(c + Vector2(7.0, 0.0), 3.5, Color(1.0, 1.0, 0.75))

	# Forward velocity arrow
	var head_pts := PackedVector2Array([
		c + Vector2(15.0, 0.0),
		c + Vector2(10.0, -4.5),
		c + Vector2(11.0, 0.0),
		c + Vector2(10.0, 4.5),
	])
	draw_polygon(head_pts, PackedColorArray([Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.2), Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.2)]))


func _draw_split_chamber(c: Vector2) -> void:
	# Multi-shot: 1 projectile entering chamber on left, splitting into 3 divergent flaming bolts
	# Origin bolt
	draw_line(c + Vector2(-20.0, 0.0), c + Vector2(-9.0, 0.0), Color(1.0, 0.85, 0.4), 2.5, true)
	draw_circle(c + Vector2(-20.0, 0.0), 2.5, Color(1.0, 0.6, 0.2))

	# Splitter chamber node
	draw_circle(c + Vector2(-8.0, 0.0), 4.5, Color(0.9, 0.7, 0.2))
	draw_circle(c + Vector2(-8.0, 0.0), 2.5, Color(1.0, 1.0, 0.9))

	# 3 divergent projectile lines
	var bolt_end_top := c + Vector2(14.0, -13.0)
	var bolt_end_mid := c + Vector2(18.0, 0.0)
	var bolt_end_bot := c + Vector2(14.0, 13.0)

	draw_line(c + Vector2(-6.0, -2.0), bolt_end_top, Color(1.0, 0.45, 0.1, 0.85), 2.0, true)
	draw_line(c + Vector2(-4.0, 0.0), bolt_end_mid, Color(1.0, 0.55, 0.15, 0.9), 2.4, true)
	draw_line(c + Vector2(-6.0, 2.0), bolt_end_bot, Color(1.0, 0.45, 0.1, 0.85), 2.0, true)

	# 3 distinct projectile orbs
	for pt in [bolt_end_top, bolt_end_mid, bolt_end_bot]:
		draw_circle(pt, 5.0, Color(1.0, 0.3, 0.1))
		draw_circle(pt, 3.2, Color(1.0, 0.8, 0.2))
		draw_circle(pt, 1.5, Color(1.0, 1.0, 0.9))


func _draw_move_speed(c: Vector2) -> void:
	# Winged boot / swift boots
	# Boot foot
	var foot := PackedVector2Array([
		c + Vector2(-6.0, -8.0),
		c + Vector2(-2.0, -8.0),
		c + Vector2(-2.0, 3.0),
		c + Vector2(11.0, 5.0),
		c + Vector2(12.0, 9.0),
		c + Vector2(-8.0, 9.0),
		c + Vector2(-8.0, 2.0),
	])
	draw_polygon(foot, PackedColorArray([
		Color(0.2, 0.75, 0.85), Color(0.25, 0.85, 0.95), Color(0.3, 0.9, 1.0),
		Color(0.4, 1.0, 1.0), Color(0.3, 0.9, 1.0), Color(0.2, 0.7, 0.8), Color(0.2, 0.7, 0.8)
	]))

	# Wing feathers spreading up-left
	draw_line(c + Vector2(-5.0, 0.0), c + Vector2(-16.0, -11.0), Color(0.7, 1.0, 1.0), 2.4, true)
	draw_line(c + Vector2(-4.0, -4.0), c + Vector2(-14.0, -16.0), Color(0.85, 1.0, 1.0), 2.4, true)
	draw_line(c + Vector2(-3.0, -7.0), c + Vector2(-9.0, -18.0), Color(0.7, 1.0, 1.0), 2.0, true)

	# Forward wind chevrons >>
	draw_polyline(PackedVector2Array([c + Vector2(13.0, -3.0), c + Vector2(17.0, 0.0), c + Vector2(13.0, 3.0)]), Color(0.5, 1.0, 0.9, 0.9), 1.8)
	draw_polyline(PackedVector2Array([c + Vector2(18.0, -3.0), c + Vector2(22.0, 0.0), c + Vector2(18.0, 3.0)]), Color(0.5, 1.0, 0.9, 0.6), 1.8)


func _draw_dash_coils(c: Vector2) -> void:
	# Dash ghost trails
	# Faint ghost 1
	draw_circle(c + Vector2(-14.0, 0.0), 6.0, Color(0.15, 0.6, 0.9, 0.25))
	# Faint ghost 2
	draw_circle(c + Vector2(-5.0, 0.0), 8.0, Color(0.2, 0.75, 1.0, 0.45))
	# Main dash form
	draw_circle(c + Vector2(6.0, 0.0), 10.0, Color(0.3, 0.9, 1.0, 0.9))
	draw_circle(c + Vector2(6.0, 0.0), 5.5, Color(0.8, 1.0, 1.0, 1.0))

	# Refresh coil loops (cooldown reduction arrows wrapping)
	draw_arc(c, 18.0, -0.6, 1.8, 14, Color(0.4, 0.85, 1.0, 0.85), 2.2, true)
	# Coil arrow
	draw_polyline(PackedVector2Array([c + Vector2(13.0, 12.0), c + Vector2(8.0, 18.0), c + Vector2(14.0, 20.0)]), Color(0.6, 1.0, 1.0), 2.0)
	draw_arc(c, 18.0, 2.6, 5.0, 14, Color(0.4, 0.85, 1.0, 0.85), 2.2, true)
	draw_polyline(PackedVector2Array([c + Vector2(-13.0, -12.0), c + Vector2(-8.0, -18.0), c + Vector2(-14.0, -20.0)]), Color(0.6, 1.0, 1.0), 2.0)


func _draw_vital_casing(c: Vector2) -> void:
	# Armored shield crest outline
	var shield := PackedVector2Array([
		c + Vector2(-15.0, -12.0),
		c + Vector2(0.0, -16.0),
		c + Vector2(15.0, -12.0),
		c + Vector2(13.0, 4.0),
		c + Vector2(0.0, 17.0),
		c + Vector2(-13.0, 4.0),
	])
	draw_polygon(shield, PackedColorArray([
		Color(0.35, 0.08, 0.12, 0.85), Color(0.45, 0.1, 0.15, 0.85), Color(0.35, 0.08, 0.12, 0.85),
		Color(0.25, 0.06, 0.1, 0.85), Color(0.3, 0.08, 0.12, 0.85), Color(0.25, 0.06, 0.1, 0.85)
	]))
	draw_polyline(shield, Color(1.0, 0.75, 0.25), 2.0)
	draw_line(shield[-1], shield[0], Color(1.0, 0.75, 0.25), 2.0)

	# Vibrant Heart inside
	var heart_c := c + Vector2(0.0, -1.0)
	draw_circle(heart_c + Vector2(-4.5, -2.5), 5.0, Color(1.0, 0.2, 0.3))
	draw_circle(heart_c + Vector2(4.5, -2.5), 5.0, Color(1.0, 0.2, 0.3))
	var heart_tri := PackedVector2Array([
		heart_c + Vector2(-8.5, -1.0),
		heart_c + Vector2(8.5, -1.0),
		heart_c + Vector2(0.0, 10.0),
	])
	draw_polygon(heart_tri, PackedColorArray([Color(1.0, 0.2, 0.3), Color(1.0, 0.2, 0.3), Color(1.0, 0.2, 0.3)]))

	# Healing cross in center of heart
	draw_line(heart_c + Vector2(-3.5, 0.5), heart_c + Vector2(3.5, 0.5), Color.WHITE, 1.8, true)
	draw_line(heart_c + Vector2(0.0, -3.0), heart_c + Vector2(0.0, 4.0), Color.WHITE, 1.8, true)


func _draw_phase_needle(c: Vector2) -> void:
	# Shield barrier being punctured through
	# Barrier line / arc in center
	draw_arc(c + Vector2(1.0, 0.0), 16.0, -1.4, 1.4, 16, Color(0.4, 0.65, 1.0, 0.65), 3.5, true)
	draw_arc(c + Vector2(1.0, 0.0), 12.0, -1.2, 1.2, 14, Color(0.6, 0.8, 1.0, 0.4), 1.8, true)

	# Pierce lance shooting straight through barrier from left to right
	draw_line(c + Vector2(-22.0, 0.0), c + Vector2(17.0, 0.0), Color(0.95, 0.35, 1.0), 2.8, true)
	draw_line(c + Vector2(-15.0, 0.0), c + Vector2(15.0, 0.0), Color(1.0, 0.85, 1.0), 1.4, true)

	# Piercing lance tip
	var lance_tip := PackedVector2Array([
		c + Vector2(23.0, 0.0),
		c + Vector2(15.0, -4.5),
		c + Vector2(17.0, 0.0),
		c + Vector2(15.0, 4.5),
	])
	draw_polygon(lance_tip, PackedColorArray([Color(1.0, 0.9, 1.0), Color(0.9, 0.3, 1.0), Color(1.0, 0.9, 1.0), Color(0.9, 0.3, 1.0)]))

	# Impact phase ripple rings where it pierces
	draw_arc(c + Vector2(1.0, 0.0), 5.0, 0.0, TAU, 12, Color(1.0, 0.8, 1.0, 0.9), 1.5, true)
	draw_arc(c + Vector2(1.0, 0.0), 9.0, 0.0, TAU, 14, Color(0.8, 0.4, 1.0, 0.6), 1.2, true)


func _draw_ricochet_core(c: Vector2) -> void:
	# Angled bounce surfaces (mirrors)
	# Top right mirror
	draw_line(c + Vector2(7.0, -17.0), c + Vector2(19.0, -7.0), Color(0.6, 0.85, 1.0), 3.5, true)
	# Bottom left mirror
	draw_line(c + Vector2(-18.0, 8.0), c + Vector2(-8.0, 18.0), Color(0.6, 0.85, 1.0), 3.5, true)

	# Bouncing laser beam
	var p1 := c + Vector2(-20.0, -12.0)
	var p2 := c + Vector2(13.0, -12.0) # hits top mirror
	var p3 := c + Vector2(-13.0, 13.0) # bounces to bottom mirror
	var p4 := c + Vector2(19.0, 13.0)  # bounces out to right

	draw_line(p1, p2, Color(1.0, 0.75, 0.2, 0.8), 2.2, true)
	draw_line(p2, p3, Color(1.0, 0.85, 0.3, 0.95), 2.5, true)
	draw_line(p3, p4, Color(1.0, 0.75, 0.2, 0.8), 2.2, true)

	# Collision impact sparks
	draw_circle(p2, 3.5, Color(1.0, 1.0, 0.8))
	draw_circle(p3, 3.5, Color(1.0, 1.0, 0.8))

	# Arrowhead on exit
	draw_polyline(PackedVector2Array([c + Vector2(14.0, 10.0), p4, c + Vector2(14.0, 16.0)]), Color(1.0, 0.9, 0.4), 2.0)


func _draw_recovery_loop(c: Vector2) -> void:
	# Circular rejuvenation / healing loop
	var ring_r := 16.0
	draw_arc(c, ring_r, 0.0, TAU, 28, Color(0.25, 0.85, 0.45, 0.85), 3.0, true)

	# Loop circulation arrows
	draw_polyline(PackedVector2Array([c + Vector2(-1.0, -ring_r - 4.0), c + Vector2(4.0, -ring_r), c + Vector2(-1.0, -ring_r + 4.0)]), Color(0.5, 1.0, 0.6), 2.0)
	draw_polyline(PackedVector2Array([c + Vector2(1.0, ring_r - 4.0), c + Vector2(-4.0, ring_r), c + Vector2(1.0, ring_r + 4.0)]), Color(0.5, 1.0, 0.6), 2.0)

	# Central glowing healing cross
	draw_line(c + Vector2(-7.0, 0.0), c + Vector2(7.0, 0.0), Color(0.9, 1.0, 0.9), 3.0, true)
	draw_line(c + Vector2(0.0, -7.0), c + Vector2(0.0, 7.0), Color(0.9, 1.0, 0.9), 3.0, true)

	# Floating green sparkle glints
	draw_circle(c + Vector2(-12.0, -12.0), 2.0, Color(0.5, 1.0, 0.6, 0.9))
	draw_circle(c + Vector2(12.0, 12.0), 2.0, Color(0.5, 1.0, 0.6, 0.9))
	draw_circle(c + Vector2(13.0, -11.0), 1.5, Color(1.0, 0.95, 0.5, 0.8))


func _draw_generic(c: Vector2) -> void:
	draw_circle(c, 12.0, Color(0.7, 0.8, 0.9))
	draw_circle(c, 6.0, Color(1.0, 1.0, 1.0))
