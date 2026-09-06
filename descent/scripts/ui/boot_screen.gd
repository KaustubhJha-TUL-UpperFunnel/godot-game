class_name BootScreen
extends Control

## First scene of the game. Warms the resource cache for the scenes gameplay
## instantiates mid-run, so a floor transition never stalls on a first-time
## load, then hands off to the main menu.

## Scenes gameplay spawns at runtime rather than having in its tree from the
## start; these are the ones worth paying for up front.
const PRELOAD_PATHS: Array[String] = [
	"res://descent/scenes/gameplay.tscn",
	"res://descent/scenes/main_menu.tscn",
	"res://descent/scenes/actors/enemy_slime.tscn",
	"res://descent/scenes/actors/enemy_goblin.tscn",
	"res://descent/scenes/actors/enemy_sorcerer.tscn",
	"res://descent/scenes/actors/enemy_boss.tscn",
	"res://descent/scenes/actors/projectile.tscn",
	"res://descent/scenes/world/hazard.tscn",
	"res://descent/scenes/fx/impact_burst.tscn",
	"res://descent/scenes/fx/damage_number.tscn",
]

## Held so the cached resources are not collected before gameplay asks for them.
var _warmed: Array[Resource] = []
var _index: int = 0

@onready var _progress: ProgressBar = $Center/Rows/Progress
@onready var _status: Label = $Center/Rows/Status
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_progress.max_value = PRELOAD_PATHS.size()
	_animation.play(&"flicker")
	_warm_next()


## One resource per frame keeps the progress bar honest and the window
## responsive without needing a background thread.
func _warm_next() -> void:
	if _index >= PRELOAD_PATHS.size():
		_finish()
		return

	var path := PRELOAD_PATHS[_index]
	_status.text = path.get_file().to_upper()
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource != null:
			_warmed.append(resource)
	else:
		push_warning("DESCENT: boot could not find %s" % path)

	_index += 1
	_progress.value = _index
	await get_tree().process_frame
	_warm_next()


func _finish() -> void:
	_status.text = "READY"
	await get_tree().create_timer(0.25).timeout
	SceneRouter.goto_main_menu()
