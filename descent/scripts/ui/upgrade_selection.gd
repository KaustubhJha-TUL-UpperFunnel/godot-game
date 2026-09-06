class_name UpgradeSelection
extends Control

## Post-loot-room reward screen. Deals three cards and reports the one the
## player installs.

signal upgrade_chosen(upgrade: UpgradeData)

const CARD_STAGGER := 0.09

var _cards: Array[UpgradeCard] = []

@onready var _row: HBoxContainer = $Cards


func _ready() -> void:
	for child in _row.get_children():
		if child is UpgradeCard:
			var card: UpgradeCard = child
			_cards.append(card)
			card.chosen.connect(_on_card_chosen)
	hide()


func present(offers: Array[UpgradeData]) -> void:
	show()
	for index in _cards.size():
		var card := _cards[index]
		card.configure(offers[index] if index < offers.size() else null)
		if card.visible:
			card.reveal(index * CARD_STAGGER)


func dismiss() -> void:
	hide()


func _on_card_chosen(upgrade: UpgradeData) -> void:
	for card in _cards:
		card.lock()
	upgrade_chosen.emit(upgrade)
