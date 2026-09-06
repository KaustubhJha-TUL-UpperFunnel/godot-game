class_name ShopCatalog
extends Node

## The merchant's stock: pricing rules and what each purchase actually does.
##
## Prices climb with depth so a shop on floor 7 is not trivially cheap after a
## long run of coin income.

enum Kind { REPAIR, MAX_HEALTH, RANDOM_UPGRADE }

const REPAIR_AMOUNT := 45.0
const MAX_HEALTH_AMOUNT := 15.0
const MAX_HEALTH_HEAL := 10.0

@export_dir var offer_directory: String = "res://descent/data/shop"
## Mystery purchases pull from the same pool the reward screen uses.
@export var upgrade_catalog: UpgradeCatalog

var offers: Array[ShopOfferData] = []


func _ready() -> void:
	for resource in ResourceDirectory.load_all(offer_directory):
		if resource is ShopOfferData:
			offers.append(resource)
	offers.sort_custom(
		func(a: ShopOfferData, b: ShopOfferData) -> bool: return a.offer_kind < b.offer_kind
	)


func price_for(offer: ShopOfferData, floor_number: int) -> int:
	if offer == null:
		return 0
	# Repair is the cheap staple, so it scales at half the rate of the rest.
	var step := 1 if offer.offer_kind == Kind.REPAIR else 2
	return offer.base_price + floor_number * step


## True when the offer would do nothing right now (full health, empty pool),
## which lets the shop grey the button out instead of taking the coins.
func is_useful(offer: ShopOfferData, player: PlayerAvatar) -> bool:
	if offer == null or player == null:
		return false
	if offer.offer_kind == Kind.REPAIR:
		return player.health.current < player.health.maximum
	return true


## Charges the player and applies the effect. Returns false if unaffordable,
## in which case nothing is spent.
func purchase(
	offer: ShopOfferData, player: PlayerAvatar, floor_number: int, rng: RandomNumberGenerator
) -> bool:
	if offer == null or player == null:
		return false

	var price := price_for(offer, floor_number)
	if not RunState.can_afford(price):
		EventBus.toast_requested.emit("NOT ENOUGH COINS", 1.2)
		return false

	match offer.offer_kind:
		Kind.REPAIR:
			if not is_useful(offer, player):
				EventBus.toast_requested.emit("ALREADY AT FULL HEALTH", 1.2)
				return false
			RunState.spend_coins(price)
			var healed := player.heal(REPAIR_AMOUNT)
			EventBus.damage_number_requested.emit(
				player.global_position, healed, EventBus.DamageStyle.HEAL
			)
			EventBus.toast_requested.emit("REPAIRED +%d HP" % int(healed), 1.4)
		Kind.MAX_HEALTH:
			RunState.spend_coins(price)
			player.add_max_health(MAX_HEALTH_AMOUNT, MAX_HEALTH_HEAL)
			EventBus.toast_requested.emit("+%d MAX HEALTH" % int(MAX_HEALTH_AMOUNT), 1.4)
		Kind.RANDOM_UPGRADE:
			var upgrade: UpgradeData = null
			if upgrade_catalog != null:
				upgrade = upgrade_catalog.draw_one(rng)
			if upgrade == null:
				EventBus.toast_requested.emit("MERCHANT IS OUT OF STOCK", 1.2)
				return false
			RunState.spend_coins(price)
			upgrade_catalog.apply(upgrade, player)
		_:
			return false

	EventBus.burst_requested.emit(
		player.global_position, Color("ffd26a"), 16, 150.0, 3.5
	)
	return true
