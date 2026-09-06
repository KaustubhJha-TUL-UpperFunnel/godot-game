class_name HealthComponent
extends Node

## Hit points with an invulnerability window, as a node so it can be dropped
## under any actor and inspected in the editor.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_position: Vector2)
signal healed(amount: float)
signal depleted()

@export var maximum: float = 100.0:
	set(value):
		maximum = maxf(1.0, value)
		current = minf(current, maximum)
@export var start_full: bool = true

var current: float = 100.0
var _invulnerable_for: float = 0.0


func _ready() -> void:
	if start_full:
		current = maximum
	health_changed.emit(current, maximum)


func _process(delta: float) -> void:
	_invulnerable_for = maxf(0.0, _invulnerable_for - delta)


func configure(new_maximum: float, fill: bool = true) -> void:
	maximum = maxf(1.0, new_maximum)
	current = maximum if fill else clampf(current, 0.0, maximum)
	_invulnerable_for = 0.0
	health_changed.emit(current, maximum)


func ratio() -> float:
	return clampf(current / maxf(1.0, maximum), 0.0, 1.0)


func is_dead() -> bool:
	return current <= 0.0


func is_invulnerable() -> bool:
	return _invulnerable_for > 0.0


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_for = maxf(_invulnerable_for, seconds)


## Drops the window early. Only for things no amount of armour survives, like
## the bottom of a pit; ordinary damage must never call this.
func clear_invulnerability() -> void:
	_invulnerable_for = 0.0


## Returns how much damage actually landed, which is 0 when blocked by
## invulnerability. Callers use that to decide whether to play a hit reaction.
func take_damage(
	amount: float, invulnerability: float = 0.0, source_position: Vector2 = Vector2.ZERO
) -> float:
	if amount <= 0.0 or is_dead() or is_invulnerable():
		return 0.0

	var before := current
	current = maxf(0.0, current - amount)
	_invulnerable_for = maxf(_invulnerable_for, invulnerability)

	var dealt := before - current
	health_changed.emit(current, maximum)
	damaged.emit(dealt, source_position)
	if is_dead():
		depleted.emit()
	return dealt


func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0
	var before := current
	current = minf(maximum, current + amount)
	var gained := current - before
	if gained > 0.0:
		health_changed.emit(current, maximum)
		healed.emit(gained)
	return gained


func set_maximum(new_maximum: float, keep_ratio: bool = false, bonus_heal: float = 0.0) -> void:
	var previous_ratio := ratio()
	maximum = maxf(1.0, new_maximum)
	current = maximum * previous_ratio if keep_ratio else minf(current + bonus_heal, maximum)
	health_changed.emit(current, maximum)


func revive(health_fraction: float) -> void:
	configure(maximum, true)
	current = maximum * clampf(health_fraction, 0.1, 1.0)
	health_changed.emit(current, maximum)
