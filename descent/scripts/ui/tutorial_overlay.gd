class_name TutorialOverlay
extends Control

## Non-blocking tutorial prompt. GameplayController advances it only after the
## player performs the requested mechanic; the icon is taken from the real
## movement stick or hotbar slot currently enabled for that lesson.

signal skip_requested()

@onready var _icon: TextureRect = $Prompt/Rows/Lesson/Icon
@onready var _title: Label = $Prompt/Rows/Lesson/Copy/Title
@onready var _instruction: Label = $Prompt/Rows/Lesson/Copy/Instruction
@onready var _progress: Label = $Prompt/Rows/Progress
@onready var _skip: Button = $Prompt/Rows/Skip


func _ready() -> void:
	_skip.pressed.connect(func() -> void: skip_requested.emit())
	hide()


func show_step(
	title: String,
	instruction: String,
	icon: Texture2D,
	step_number: int,
	total_steps: int
) -> void:
	_title.text = title
	_instruction.text = instruction
	_icon.texture = icon
	_icon.visible = icon != null
	_progress.text = "LESSON %d / %d  ·  DO IT NOW" % [step_number, total_steps]
	show()


func finish() -> void:
	hide()
