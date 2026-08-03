class_name Hand
extends RefCounted

## Story 3-3 (AC 1): the per-player hand. PURE RefCounted, owned by PlayerState. Same
## discipline as Deck: StringName ids only (never CardData references, AC 5), no RNG of its
## own, and nothing naming CardDatabase, CARDS_DIR or data/cards.
##
## A CONTAINER ONLY. No card effect, no cast evaluator, no play path and no discard ship here
## (AC 11) — the hand is filled at MatchState's ONE step-6 deal seat and read by nothing else
## yet. The card-play story (3-5) owns the first consumer.
##
## SIZE DOES NOT VARY in this story: the fill target is the authored hand_size, read inline at
## the seat. OPEN decision (e) — "does the number of cards in a hand ever vary?" — is CARRIED,
## not resolved, and no variable-size path is built speculatively.
##
## Note for E6: a staged Pitch Zone card still counts toward the hand, so a future pitch path
## must not shrink this container (project-context, Critical Don't-Miss Rules).

var _cards: Array[StringName] = []


func add(id: StringName) -> void:
	_cards.append(id)


## Emptied at the deal seat before each fill — the debug reset restores the full composition
## rather than returning cards from anywhere, because there is nowhere to return them TO (no
## discard pile ships, AC 11).
func clear() -> void:
	_cards.clear()


func size() -> int:
	return _cards.size()


func is_empty() -> bool:
	return _cards.is_empty()


## READ accessor returning a COPY (Deck.to_array's twin). Order is the draw order off the top
## of the shuffled pile; like the deck's, it is deliberately absent from the snapshot, which
## carries the COUNT alone (AC 5).
func to_array() -> Array[StringName]:
	return _cards.duplicate()
