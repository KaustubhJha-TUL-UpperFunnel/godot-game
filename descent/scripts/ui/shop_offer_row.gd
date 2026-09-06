class_name ShopOfferRow
extends PanelContainer

## One line of merchant stock: name, effect, price, and a buy button that
## greys out when the player cannot afford it or has already taken it.

signal purchase_requested(offer: ShopOfferData)

var offer: ShopOfferData
var is_sold: bool = false

@onready var _name: Label = $Rows/Name
@onready var _description: Label = $Rows/Description
@onready var _buy: Button = $Rows/Buy


func _ready() -> void:
	_buy.pressed.connect(func() -> void: purchase_requested.emit(offer))


func configure(data: ShopOfferData, price: int) -> void:
	offer = data
	is_sold = false
	visible = data != null
	if data == null:
		return
	_name.text = data.display_name.to_upper()
	_description.text = data.description
	_buy.text = "%d COINS" % price


func set_purchasable(purchasable: bool) -> void:
	_buy.disabled = is_sold or not purchasable


func mark_sold() -> void:
	is_sold = true
	_buy.disabled = true
	_buy.text = "SOLD"
	modulate = Color(0.62, 0.66, 0.7)
