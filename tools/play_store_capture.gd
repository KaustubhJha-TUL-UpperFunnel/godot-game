extends Node

## Windowed capture of eight distinct campaign maps for Google Play screenshots.
## Looks like a release session: HUD, hotbar, touch controls, no audit chrome.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility \
##     --resolution 1280x720 res://tools/play_store_capture.tscn

const GAMEPLAY_SCENE := preload("res://descent/scenes/gameplay.tscn")
const BOT_SCRIPT := preload("res://tools/level_audit_bot.gd")
const OUT_DIR := "res://googleplayresources/_raw"
const CAPTURE_SIZE := Vector2i(1280, 720)

## Biome-distinct flat rooms, one each, so the store page shows different art.
const MAP_NEEDLES: Array[String] = [
	"map_04_fire_infernal_shrine_flat",
	"map_11_ice_throne_room_flat",
	"map_16_poison_blight_catacombs_flat",
	"map_20_water_flooded_crypt_flat",
	"map_29_crystal_starlight_vault_flat",
	"map_32_nature_verdant_ruins_flat",
	"map_37_shadow_tomb_ancients_flat",
	"map_42_gold_gilded_vault_flat",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_window()
	SaveManager.tutorial_completed = true
	RunState.begin_run()
	RunState.coins = 132
	RunState.echoes_earned = 1

	var floors := _resolve_floors()
	if floors.size() != MAP_NEEDLES.size():
		push_error("PLAY STORE CAPTURE: expected %d maps, resolved %d" % [MAP_NEEDLES.size(), floors.size()])
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayController
	add_child(gameplay)
	move_child(gameplay, 0)
	_prepare_release_look(gameplay)

	var bot: LevelAuditBot = BOT_SCRIPT.new()
	add_child(bot)
	bot.bind(gameplay)

	for index in floors.size():
		var floor_number: int = floors[index]
		print("PLAY STORE CAPTURE: %d/%d floor %02d" % [index + 1, floors.size(), floor_number])
		RunState.floor_number = floor_number
		RunState.floor_changed.emit(floor_number)
		gameplay.begin_room()
		_prepare_release_look(gameplay)
		_arm_player(gameplay)
		bot.floor_started()
		bot.set_enabled(false)

		await get_tree().create_timer(GameplayController.INTRO_SECONDS + 0.15).timeout
		_prepare_release_look(gameplay)
		_arm_player(gameplay)
		bot.set_enabled(true)
		await get_tree().create_timer(1.7).timeout
		bot.set_enabled(false)
		_prepare_release_look(gameplay)
		_arm_player(gameplay)
		await _capture(index + 1, RunState.current_level_path)

	print("PLAY STORE CAPTURE: done")
	get_tree().quit()


func _configure_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	DisplayServer.window_set_min_size(CAPTURE_SIZE)
	get_viewport().size = CAPTURE_SIZE
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _prepare_release_look(gameplay: GameplayController) -> void:
	var touch := gameplay.get_node_or_null("UI/TouchControls") as Control
	if touch:
		touch.visible = true
	var tutorial := gameplay.get_node_or_null("UI/TutorialOverlay") as Control
	if tutorial:
		tutorial.hide()
	var pause := gameplay.get_node_or_null("UI/PauseMenu") as Control
	if pause:
		pause.hide()
	var revive := gameplay.get_node_or_null("UI/RewardedRevive") as Control
	if revive:
		revive.hide()
	var summary := gameplay.get_node_or_null("UI/RunSummary") as Control
	if summary:
		summary.hide()
	_dismiss_banners(gameplay)


func _arm_player(gameplay: GameplayController) -> void:
	if gameplay.player.is_dead:
		gameplay.player.revive(1.0)
	else:
		gameplay.player.restore_full_health()
	gameplay.player.health.grant_invulnerability(60.0)
	gameplay.player.set_control_enabled(true, true)


func _dismiss_banners(gameplay: GameplayController) -> void:
	var announcement := gameplay.get_node_or_null("UI/Announcement") as Announcement
	if announcement:
		announcement.dismiss_now()
	var upgrades := gameplay.get_node_or_null("UI/UpgradeSelection") as Control
	if upgrades:
		upgrades.hide()


func _resolve_floors() -> Array[int]:
	var paths := LevelLibrary.playable_paths()
	var floors: Array[int] = []
	for needle in MAP_NEEDLES:
		var found := 0
		for index in paths.size():
			if paths[index].get_file().begins_with(needle):
				found = index + 1
				break
		if found == 0:
			push_error("PLAY STORE CAPTURE: missing map %s" % needle)
			continue
		floors.append(found)
		print("PLAY STORE CAPTURE: %s -> floor %d" % [needle, found])
	return floors


func _capture(ordinal: int, level_path: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("PLAY STORE CAPTURE: viewport image was null")
		return
	var stem := level_path.get_file().get_basename()
	var dest := "%s/%02d-%s.png" % [OUT_DIR, ordinal, stem]
	var abs_path := ProjectSettings.globalize_path(dest)
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("PLAY STORE CAPTURE: save failed %s (%s)" % [abs_path, err])
		return
	print("PLAY STORE CAPTURE: wrote %s (%dx%d)" % [abs_path, image.get_width(), image.get_height()])
