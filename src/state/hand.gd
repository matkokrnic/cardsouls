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
## STORY 4-0 REPLACES THE SHAPE: this is now a FIXED-WIDTH, HOLE-AWARE container (AC 1). Before
## this story it was a plain shrinking Array[StringName]: `remove_at` called `Array.remove_at`,
## which SHIFTS every later element left, so casting the card in slot 1 renamed the card in slot
## 2 to "slot 1" under the player's fingers and the replacement appended at the end. That shift
## was the literal mechanism of the bug. Every position now holds either a card id or the
## explicit EMPTY marker, and the array's LENGTH never changes except at a deal.
##
## THE WIDTH ARRIVES FROM THE CALLER (AC 1, `4-0/R2`). This class never learns of BalanceConfig,
## never holds a config reference and never names `hand_size` — the deal seat passes the width
## into clear(), reading `balance.hand_size` INLINE at the moment of use per CONSTRAINT C. A Hand
## that has never been dealt to therefore has width 0, which is what keeps a pre-deal
## `hand_size` snapshot reading 0 without a special case.
##
## Note for E6: a staged Pitch Zone card still counts toward the hand, so a future pitch path
## must not shrink this container (project-context, Critical Don't-Miss Rules).

## Story 4-0 (AC 7, `4-0/R3`): the empty marker is the empty StringName, RULED rather than
## chosen. Two shipped facts force it. (a) `hud_root.gd`'s caption line renders `str(hand_ids[i])`
## against a payload that is now always full width, so its `else ""` branch is DEAD and the MARKER
## VALUE itself decides the caption — any marker but this one renders visible garbage in the
## vacated slot, which is exactly the defect 3-6 AC 1 shipped to prevent ("a caption left behind
## is a card the player can see and cannot cast"). (b) The marker/card-id collision is impossible
## BY CONSTRUCTION, and the guard ALREADY SHIPS: test_card_authoring.gd's
## test_every_id_is_non_empty_and_unique asserts `card.id != &""` over every authored card. That
## assertion is load-bearing FOR THIS CONSTANT — see the comment re-pointing it there.
const EMPTY := &""

var _cards: Array[StringName] = []


## Emptied at the deal seat before each fill — the debug reset restores the full composition
## rather than returning cards from anywhere, because there is nowhere to return them TO (no
## discard pile ships, AC 11).
##
## STORY 4-0: `clear` now takes the WIDTH and PRE-FILLS it with markers, so the container leaves
## this call at its full width holding nothing. That is what makes an indexed in-place fill
## possible at the deal seat (AC 5) — and it is also why `add()` no longer exists: an appending
## method against a pre-filled width would write PAST the width and produce a 2 * hand_size array.
## The overflow is prevented BY CONSTRUCTION (the method is gone) rather than by a guard some
## later caller can route around (project-context: guard mechanism over guard pattern, `3-0d/R20`).
##
## A width of 0 is legitimate and is the never-dealt state; a NEGATIVE width is a programming
## error and says so.
func clear(width: int) -> void:
	Invariant.check(width >= 0, "hand width %d is negative" % width)
	_cards.clear()
	_cards.resize(width)
	_cards.fill(EMPTY)


## Story 4-0 (AC 2, `4-0/R1`): SIZE MEANS WIDTH. The two readings the old `size()` conflated —
## "how many positions does this hand have" and "how many of them hold a card" — are
## irreconcilable under one method once a hole is expressible, and the gate enumerated nine
## consumers that split across them. The split is explicit rather than implied, and each consumer
## was re-pointed by hand.
func size() -> int:
	return _cards.size()


## Story 4-0 (AC 2): what `size()` meant BEFORE this story — the number of positions actually
## holding a card. The snapshot key `hand_size` binds HERE, which is what preserves that key's
## meaning unchanged across the shape change, keeps 3-5b's four-term conservation identity
## (`occupied + owed == hand_size`) true, and keeps `3-5b/R8`'s "hand_size is permitted to reach
## 0" a meaningful statement rather than one that could never be true against a fixed width.
func occupied_count() -> int:
	var n := 0
	for id in _cards:
		if id != EMPTY:
			n += 1
	return n


## Story 4-0 (AC 2): "no OCCUPIED slots" — NOT `_cards.is_empty()`. Once the backing array is
## pre-filled to its width it is never empty again after the first deal, so the bare array read
## would be permanently false and silently wrong.
func is_empty() -> bool:
	return occupied_count() == 0


## Story 4-0: is the position at `index` a hole? Out of range counts as "holds no card", which is
## what lets the cast guard treat an out-of-range slot and a hole as the same refusal (AC 3)
## without the caller doing the bound arithmetic twice.
func is_slot_empty(index: int) -> bool:
	if index < 0 or index >= _cards.size():
		return true
	return _cards[index] == EMPTY


## READ accessor returning a COPY (Deck.to_array's twin). Order is the draw order off the top
## of the shuffled pile; like the deck's, it is deliberately absent from the snapshot, which
## carries the COUNT alone (AC 5).
##
## STORY 4-0: this is the WIDTH view — always `size()` elements, with EMPTY at every hole. It is
## what `cards_changed` carries to the HUD (the nine-consumer table binds it to WIDTH), because a
## renderer laying out a fixed row of slots needs the holes to be positionally present rather
## than compacted away. Callers that want the CARDS, not the layout, use `occupied_ids()`.
func to_array() -> Array[StringName]:
	return _cards.duplicate()


## Story 4-0: the OCCUPANCY view — the ids actually held, holes filtered out, in slot order.
## `occupied_count()`'s twin, and the read the four-term conservation proofs need: a permutation
## check over the injected composition must see the cards, never the markers.
func occupied_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _cards:
		if id != EMPTY:
			out.append(id)
	return out


## Story 3-5a (AC 6): the REMOVAL method this container did not have. Before this story the
## hand exposed add/clear/size/is_empty/to_array only, and `to_array` returns a DUPLICATE — so
## no caller could take a card out of a hand at all, which is precisely why playing a card
## needed this seat rather than a mutation through the read accessor.
##
## Returns the removed id so the ONE caller (MatchState's step-6 cast dispatch) can hand it
## straight to the discard pile without a second lookup that could disagree with this one.
##
## STORY 4-0 (AC 1): the removal is an IN-PLACE HOLE WRITE. `Array.remove_at` is gone — it is the
## shift this story exists to delete. Casting the card in slot N now changes ONLY slot N; every
## other slot's contents AND index are byte-for-byte unchanged, immediately and for as long as N
## stays a hole.
##
## Bounds are a PROGRAMMING ERROR, not a runtime condition, and are enforced here rather than
## trusted: the dispatch already rejects an out-of-range or empty slot through the
## action_rejected path BEFORE reaching this call (CastEvaluator.REASON_EMPTY_SLOT), so an
## index arriving here out of range means the guard above it was bypassed. Invariant.check is
## the export-surviving form (X1), matching push_contact and the injection seams.
##
## STORY 4-0 RE-POINTS THAT INVARIANT TO OCCUPANCY. Under fixed width every index below the width
## is in range, so a pure bound check would go silently VACUOUS the moment this shape landed — it
## exists to catch a bypassed step-6 guard, and the guard it backs now refuses HOLES as well as
## out-of-range slots. Checking occupancy is what keeps it catching the same class of error it was
## written for.
func remove_at(index: int) -> StringName:
	Invariant.check(not is_slot_empty(index),
		"hand slot %d holds no card (hand is %d wide, %d occupied) — the step-6 guard was bypassed"
				% [index, _cards.size(), occupied_count()])
	var id: StringName = _cards[index]
	_cards[index] = EMPTY
	return id


## Story 4-0 (AC 1/AC 4): the IN-PLACE FILL — a card written into ONE named position. This is the
## seat the whole story turns on: the delayed replacement lands in the slot its cast VACATED
## rather than at the end of the array, so a slot's identity under the player's fingers survives
## a cast. It is also the deal's fill (AC 5), which is why the deal loop no longer appends.
##
## Writing over an OCCUPIED slot would silently destroy a card, so it is refused rather than
## permitted: every shipped caller writes into a hole it is owed, and one that does not has a
## bug that must not degrade into a lost card.
func fill_at(index: int, id: StringName) -> void:
	Invariant.check(index >= 0 and index < _cards.size(),
		"hand slot %d out of range (hand is %d wide)" % [index, _cards.size()])
	Invariant.check(id != EMPTY, "cannot fill hand slot %d with the empty marker" % index)
	Invariant.check(_cards[index] == EMPTY,
		"hand slot %d already holds %s — a fill would destroy a card" % [index, _cards[index]])
	_cards[index] = id
