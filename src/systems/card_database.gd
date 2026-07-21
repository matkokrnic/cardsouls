extends Node

## Autoload. Loads all card .tres at startup into a lookup dict. Empty in E0 — cards
## are authored in E3. State-layer code never reads this autoload; card data is passed
## in by the runner / card system.

const CARDS_DIR := "res://data/cards/"

var _cards: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	_cards.clear()
	# E3: scan CARDS_DIR for *.tres and index by resource id. Empty until then.


func get_card(id: StringName) -> Resource:
	return _cards.get(id)


func has_card(id: StringName) -> bool:
	return _cards.has(id)
