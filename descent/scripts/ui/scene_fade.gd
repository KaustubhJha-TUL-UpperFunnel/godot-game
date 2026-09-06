extends CanvasLayer

## Full-screen curtain used by SceneRouter to hide scene swaps.

const DURATION := 0.22

@onready var _curtain: ColorRect = $Curtain


func fade_out() -> void:
	await _tween_alpha(1.0)


func fade_in() -> void:
	await _tween_alpha(0.0)


func _tween_alpha(target: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_curtain, "color:a", target, DURATION)
	await tween.finished
