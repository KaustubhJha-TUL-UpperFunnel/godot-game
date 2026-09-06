class_name UpgradeData
extends Resource

## One offerable run upgrade. `upgrade_id` is the stable key that
## UpgradeCatalog uses to apply the effect to the player.

@export var upgrade_id: int = 0
@export var display_name: String = "Upgrade"
@export var description: String = ""
@export_enum("COMMON", "UNCOMMON", "RARE") var rarity: String = "COMMON"
@export var value: float = 0.0
