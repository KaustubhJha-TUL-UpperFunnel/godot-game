extends Node

## Autoload: the only place that swaps the top-level scene.
##
## The three scenes below are the whole game; everything else is instanced
## inside one of them. Transitions fade through scene_fade.tscn so a swap never
## shows a single-frame flash of the next scene mid-setup.

const BOOT := "res://descent/scenes/boot.tscn"
const MAIN_MENU := "res://descent/scenes/main_menu.tscn"
const GAMEPLAY := "res://descent/scenes/gameplay.tscn"
const LEVEL_AUDIT := "res://tools/visual_level_audit.tscn"

const FADE_SCENE := preload("res://descent/scenes/ui/scene_fade.tscn")

var _fade: CanvasLayer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = FADE_SCENE.instantiate()
	add_child(_fade)


func goto_main_menu() -> void:
	_change_scene(MAIN_MENU)


func goto_gameplay() -> void:
	RunState.level_audit_active = false
	RunState.begin_run()
	_change_scene(GAMEPLAY)


func goto_level_audit() -> void:
	_change_scene(LEVEL_AUDIT)


func quit_game() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true

	get_tree().paused = false
	await _fade.fade_out()
	get_tree().change_scene_to_file(path)
	# Let the incoming scene finish _ready() before revealing it.
	await get_tree().process_frame
	await _fade.fade_in()

	_busy = false
