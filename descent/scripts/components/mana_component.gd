class_name ManaComponent
extends Node

## Regenerating spell resource for the player's fire and ice abilities.

signal mana_changed(current: float, maximum: float)

@export var maximum: float = 60.0
@export var starting: float = 40.0
@export var regen_per_second: float = 8.0

var current: float = 40.0


func _ready() -> void:
	current = clampf(starting, 0.0, maximum)
	mana_changed.emit(current, maximum)


func _process(delta: float) -> void:
	if current < maximum:
		current = minf(maximum, current + regen_per_second * delta)
		mana_changed.emit(current, maximum)


func ratio() -> float:
	return clampf(current / maxf(1.0, maximum), 0.0, 1.0)


func has(amount: float) -> bool:
	return current >= amount


## Spends mana only when the full cost is available, so an ability never
## half-fires and leaves the player drained.
func try_spend(amount: float) -> bool:
	if current < amount:
		return false
	current -= amount
	mana_changed.emit(current, maximum)
	return true


func restore(amount: float) -> void:
	current = minf(maximum, current + amount)
	mana_changed.emit(current, maximum)


func reset() -> void:
	current = clampf(starting, 0.0, maximum)
	mana_changed.emit(current, maximum)
