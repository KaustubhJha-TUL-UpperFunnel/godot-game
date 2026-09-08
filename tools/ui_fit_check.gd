extends Node

## Editor-only harness: opens the permanent upgrades panel over the main menu,
## reports whether it fits the 1280x720 design viewport, and drops a screenshot
## in builds/ for eyeballing.

const MENU := "res://descent/scenes/main_menu.tscn"
const SHOT := "res://builds/ui_permanent_upgrades.png"


func _ready() -> void:
	var menu: Control = (load(MENU) as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame

	var panel: Control = menu.get_node("PermanentUpgrades")
	panel.open()

	# `--stress N` pads the list with clone rows to prove the frame still fits
	# once more tracks are added to SaveManager.TRACKS.
	var stress := 0
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--stress":
		stress = args[1].to_int()
	if stress > 0:
		var list: Control = panel.get_node("Frame/Rows/Scroll/List")
		var template: Control = list.get_child(0)
		for _i in stress:
			list.add_child(template.duplicate())

	# Containers need a couple of frames to settle their minimum sizes.
	for _i in 4:
		await get_tree().process_frame

	var view := get_viewport().get_visible_rect().size
	var frame: Control = panel.get_node("Frame")
	var rows: Control = frame.get_node("Rows")
	var close: Control = rows.get_node("Close")

	print("viewport      : %s" % view)
	print("frame rect    : pos %s size %s" % [frame.position, frame.size])
	print("frame min     : %s" % frame.get_combined_minimum_size())
	print("rows min      : %s" % rows.get_combined_minimum_size())
	print("close bottom  : %.1f" % (close.global_position.y + close.size.y))

	var bottom := frame.position.y + frame.size.y
	var overflow_y := maxf(0.0, bottom - view.y) + maxf(0.0, -frame.position.y)
	if overflow_y > 0.0:
		print("RESULT: OVERFLOWS vertically by %.1f px" % overflow_y)
	else:
		print("RESULT: fits (%.1f px of vertical slack)" % (view.y - frame.size.y))

	for _i in 2:
		await get_tree().process_frame
	var shot := SHOT if stress == 0 else SHOT.replace(".png", "_stress.png")
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(shot))
	print("screenshot -> %s" % shot)
	get_tree().quit()
