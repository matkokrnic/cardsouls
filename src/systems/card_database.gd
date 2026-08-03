extends Node

## Autoload. Loads all card .tres at startup into a lookup dict, keyed by the card's `id`
## FIELD. State-layer code never reads this autoload; card data is passed in by the runner /
## card system — machine-checked by test_state_layer_never_names_card_data
## (test/state/test_architecture_invariants.gd, story 3-2 AC 5), which is why no file under
## src/state/ may name CARDS_DIR or the cards path.
##
## LOAD-ONCE AT STARTUP, NO RELOAD PATH — the shipped contract, not a placeholder (the
## FeatureFlags load-once shape). Cards are CONTENT: a new card is a new .tres and no code
## change, which is also why card content is deliberately kept OUT of the hashed determinism
## run (3-2 Golden Prediction) — otherwise adding a card would re-baseline the golden.

const CARDS_DIR := "res://data/cards/"

var _cards: Dictionary = {}


func _ready() -> void:
	_load_all()


## Index every CardData .tres in CARDS_DIR by its `id` field.
##
## DELIBERATE DUPLICATE of EconomyEvaluator.load_rules()
## (src/state/economy/economy_evaluator.gd) — the same sorted, single-directory,
## extension-filtered scan, written twice on purpose. A shared helper is DEFERRED to a THIRD
## scan: these two sit on opposite sides of the state/systems layer boundary and a shared
## helper has no honest home today (3-2 gate ruling). The two must be kept in step by hand
## until then, and the ownerless export-packaging remap risk filed at 3-4/R8 (a raw directory
## scan can degrade to an empty set under export remap, with no error) is EXTENDED to cover
## data/cards/ — an empty CARD set is a worse failure than an empty rule set.
##
## SORTED because the loaded set must never depend on filesystem enumeration order. Indexed
## by the `id` FIELD, never the filename — identity survives a rename (3-2 gate ruling), and
## the filename mirroring the id is convention only. A resource that does not cast to
## CardData is skipped, so a stray .tres in the directory cannot poison the set; a missing
## directory yields an empty set rather than failing. Both of those are CRASH guards, not
## behaviour a mutation can prove.
func _load_all() -> void:
	_cards.clear()
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var card := load(CARDS_DIR + file_name) as CardData
		if card == null:
			continue
		_cards[card.id] = card


func get_card(id: StringName) -> Resource:
	return _cards.get(id)


func has_card(id: StringName) -> bool:
	return _cards.has(id)


## How many cards loaded. A READ accessor beside get_card/has_card — the observation seam the
## integration test needs to prove the set is not silently empty (3-2 AC 6). Nothing here
## exposes an ORDER: dictionary iteration order is never a contract, and any later ordered
## read sorts explicitly.
func card_count() -> int:
	return _cards.size()


## Story 3-3 (AC 3): the ONE ordered read over the loaded ids — EXPLICITLY sorted, never
## dictionary iteration order (which card_count's header above already says is not a contract).
## This is the "any later ordered read sorts explicitly" that header anticipated.
##
## Returns a FRESH array, so no caller can reach the backing dictionary through it. get_card,
## has_card and card_count are UNCHANGED — this is an addition, not a widening of them.
##
## Its one production consumer is match_runner's deck composition (AC 4), which walks this in
## order taking up to each card's max_copies. Sorting HERE rather than at the consumer is what
## makes "the deck composition never depends on filesystem enumeration order" a property of the
## database instead of a habit of whoever reads it.
## SORTED AS STRINGS, DELIBERATELY, and this is load-bearing rather than stylistic: Godot's
## StringName comparison operators order by INTERNAL POINTER, not lexicographically, so
## `Array[StringName].sort()` yields an allocation-dependent order that looks sorted, is
## deterministic within one process, and is NOT stable across runs or builds. Measured here on
## 4.6.3: it returned frost_dart, ember_lash, bramble_snare, ... — a deck composition built on
## that would be exactly the filesystem-order dependency this accessor exists to prevent. The
## round-trip through String is what makes "explicitly sorted" true.
func sorted_ids() -> Array[StringName]:
	var names: Array[String] = []
	for id: StringName in _cards.keys():
		names.append(String(id))
	names.sort()
	var ids: Array[StringName] = []
	for name in names:
		ids.append(StringName(name))
	return ids
