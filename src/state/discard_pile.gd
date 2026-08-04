class_name DiscardPile
extends RefCounted

## Story 3-5a (AC 6): the per-player discard pile — the THIRD pure container, alongside Deck
## and Hand and built to the same shape as both. PURE RefCounted, owned by PlayerState, no RNG
## of its own, no SignalQueue, and nothing here names CardDatabase, CARDS_DIR or data/cards.
##
## StringName IDS ONLY, never CardData references — the same hard rule Deck and Hand carry, and
## for the same measured reason: CanonicalHash has NO OBJECT BRANCH and falls through to a
## string conversion yielding a PER-ALLOCATION instance id, so an object in a container that
## ever reaches the snapshot would make two identical matches hash differently. This pile is
## snapshotted as a COUNT (PlayerState.to_snapshot's "discard_size"), so its ORDER is not
## hash-visible — exactly like the deck's.
##
## WHERE CARDS COME FROM: the single step-6 cast dispatch in MatchState, and nowhere else. A
## card is removed from the Hand and pushed here in the same tick, so "hand + discard + deck"
## stays a permutation of the injected composition — pinned by
## test_card_play.gd::test_cast_conserves_the_injected_multiset.
##
## NOT HERE, BY THE 3-5a/3-5b SPLIT: no reshuffle, no deck-exhaustion handling, and no
## vulnerable window. Those are 3-5b's, together with the delayed replacement draw that makes
## exhaustion reachable at all. This story draws the replacement INSTANTLY, so the pile only
## ever grows and the deck only ever shrinks within one round.

var _cards: Array[StringName] = []


## The ONE way a card enters the pile. Called from MatchState's step-6 cast dispatch.
func add(id: StringName) -> void:
	_cards.append(id)


## Emptied by the debug reset, which restores the full composition to the deck rather than
## returning these cards anywhere — the pile has no "return to deck" path in this story
## (that is the 3-5b reshuffle, deliberately absent here).
func clear() -> void:
	_cards.clear()


func size() -> int:
	return _cards.size()


func is_empty() -> bool:
	return _cards.is_empty()


## READ accessor returning a COPY (Deck.to_array / Hand.to_array's twin), so no caller can
## mutate the pile through it. Order is DISCARD order — oldest first, newest last — and is
## deliberately absent from the snapshot, which carries the COUNT alone.
func to_array() -> Array[StringName]:
	return _cards.duplicate()
