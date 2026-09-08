class_name UpgradeCatalog
extends Node

## Owns the run-upgrade pool and is the only place that knows how an
## UpgradeData turns into a stat change on the player.
##
## The pool is every .tres in the upgrades folder, so adding an upgrade means
## dropping a file in there and adding one match arm below.

## Ricochet Core stays out of the pool until the permanent track unlocks it.
const RICOCHET_ID := 8
## Recovery Loop is passive; GameplayController reads the stack after each room.
const RECOVERY_LOOP_ID := 9

const VITAL_CASING_HEAL := 14.0
const RECOVERY_LOOP_HEAL := 4.0

@export_dir var upgrade_directory: String = "res://descent/data/upgrades"

var upgrades: Array[UpgradeData] = []


func _ready() -> void:
	for resource in ResourceDirectory.load_all(upgrade_directory):
		if resource is UpgradeData:
			upgrades.append(resource)
	upgrades.sort_custom(
		func(a: UpgradeData, b: UpgradeData) -> bool: return a.upgrade_id < b.upgrade_id
	)


func by_id(upgrade_id: int) -> UpgradeData:
	for upgrade in upgrades:
		if upgrade != null and upgrade.upgrade_id == upgrade_id:
			return upgrade
	return null


## Returns up to `count` distinct upgrades to show on the reward screen.
func draw_offers(count: int, rng: RandomNumberGenerator) -> Array[UpgradeData]:
	var pool := _available()
	var drawn: Array[UpgradeData] = []
	while drawn.size() < count and not pool.is_empty():
		drawn.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return drawn


## A single random upgrade, used by the merchant's mystery purchase.
func draw_one(rng: RandomNumberGenerator) -> UpgradeData:
	var pool := _available()
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _available() -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []
	for upgrade in upgrades:
		if upgrade == null:
			continue
		if upgrade.upgrade_id == RICOCHET_ID and not SaveManager.has_ricochet_unlock():
			continue
		pool.append(upgrade)
	return pool


## Applies the effect and records the stack on RunState.
func apply(upgrade: UpgradeData, player: PlayerAvatar) -> void:
	if upgrade == null or player == null:
		return

	match upgrade.upgrade_id:
		0:
			player.add_damage_multiplier(upgrade.value)
		1:
			player.add_attack_speed(upgrade.value)
		2:
			player.add_projectile_speed(upgrade.value)
		3:
			player.add_projectile()
		4:
			player.add_move_speed(upgrade.value)
		5:
			player.reduce_dash_cooldown(upgrade.value)
		6:
			player.add_max_health(upgrade.value, VITAL_CASING_HEAL)
		7:
			player.add_pierce()
		RICOCHET_ID:
			player.add_ricochet(upgrade.value)
		RECOVERY_LOOP_ID:
			player.heal(RECOVERY_LOOP_HEAL)
		_:
			push_warning("DESCENT: unhandled upgrade id %d" % upgrade.upgrade_id)

	RunState.record_upgrade(upgrade.upgrade_id)
	EventBus.toast_requested.emit("%s UPGRADED" % upgrade.display_name.to_upper(), 1.5)


## Between-room trickle heal granted by Recovery Loop stacks.
func apply_room_clear_effects(player: PlayerAvatar) -> void:
	var stacks := RunState.upgrade_level(RECOVERY_LOOP_ID)
	if stacks > 0 and player != null:
		player.heal(RECOVERY_LOOP_HEAL * float(stacks))
