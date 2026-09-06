class_name ShopOfferData
extends Resource

## One purchasable item in the merchant vault. The final price scales with the
## current floor; see ShopCatalog.price_for().

@export_enum("REPAIR", "MAX_HEALTH", "RANDOM_UPGRADE") var offer_kind: int = 0
@export var display_name: String = "Repair"
@export var description: String = ""
@export var base_price: int = 12
