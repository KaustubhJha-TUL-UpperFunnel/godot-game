class_name ShopPanel
extends Control

## Merchant vault storefront. Non-blocking: it sits over the arena while the
## player is still free to walk around, and the doors are already open.

signal purchase_requested(offer: ShopOfferData)

var _catalog: ShopCatalog
var _player: PlayerAvatar
var _rows: Array[ShopOfferRow] = []

@onready var _row_container: HBoxContainer = $Frame/Rows/Offers
@onready var _coins: Label = $Frame/Rows/Coins


func _ready() -> void:
	for child in _row_container.get_children():
		if child is ShopOfferRow:
			var row: ShopOfferRow = child
			_rows.append(row)
			row.purchase_requested.connect(_on_purchase_requested)
	RunState.coins_changed.connect(func(_coin_total: int) -> void: refresh())
	hide()


func present(catalog: ShopCatalog, player: PlayerAvatar) -> void:
	_catalog = catalog
	_player = player
	for index in _rows.size():
		var offer: ShopOfferData = (
			catalog.offers[index] if index < catalog.offers.size() else null
		)
		_rows[index].configure(offer, catalog.price_for(offer, RunState.floor_number))
	show()
	refresh()


func dismiss() -> void:
	hide()


## Marks the row bought; called by GameplayController only when the purchase
## actually went through.
func confirm_purchase(offer: ShopOfferData) -> void:
	for row in _rows:
		if row.offer == offer:
			row.mark_sold()
	refresh()


func refresh() -> void:
	if _catalog == null or not visible:
		return
	_coins.text = "YOUR COINS: %d" % RunState.coins
	for row in _rows:
		var price := _catalog.price_for(row.offer, RunState.floor_number)
		row.set_purchasable(
			RunState.can_afford(price) and _catalog.is_useful(row.offer, _player)
		)


func _on_purchase_requested(offer: ShopOfferData) -> void:
	purchase_requested.emit(offer)
