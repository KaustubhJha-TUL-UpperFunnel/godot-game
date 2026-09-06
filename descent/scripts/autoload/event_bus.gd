extends Node

## Autoload: one-way notification channel for presentation-only effects.
##
## Gameplay nodes announce that something felt impactful; FxDirector, the HUD
## and the camera decide what to do about it. Keeping these off direct node
## references means an enemy does not need to know the camera exists.
##
## Anything that changes game rules should use a normal node signal instead.

enum DamageStyle { NORMAL, CRITICAL, PLAYER_HURT, FIRE, ICE, HEAL }

signal toast_requested(message: String, duration: float)
signal shake_requested(strength: float, duration: float)
signal hitstop_requested(duration: float)
signal damage_number_requested(position: Vector2, amount: float, style: DamageStyle)
signal burst_requested(position: Vector2, color: Color, count: int, speed: float, size: float)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
