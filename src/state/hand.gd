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

## ------------------------------------------------------------------------------------------
## STORY 6-5e (AC 16-19, Open Question 1): THE COVER LAYER -- a SECOND, ORDERED LAYER PER SLOT.
## ------------------------------------------------------------------------------------------
## A Rocksling stone that lands on a hero plants a BOULDER on top of one of that hero's slots
## (ruling 6): the card already there STAYS in place, becomes unplayable, and reappears -- in the
## SAME slot, unmoved -- the instant the Boulder is removed (ruling 7). `Hand` as 4-0 shipped it has
## no concept of two things in one slot, and the dev pass owned the shape (the story's own Open
## Question 1, which fixes the BEHAVIOUR and leaves the data shape here).
##
## A PARALLEL ARRAY, NOT A WRAPPER VALUE TYPE AND NOT A SIBLING CONTAINER, and each rejection has a
## reason:
##   * a WRAPPER per slot (replacing the bare `StringName`) would change the type of `_cards`, and
##     `_cards` is what `to_array()` hands to the `cards_changed` payload, what `occupied_ids()`
##     permutes against the injected composition in 3-5b's four-term conservation proof, and what
##     every one of the nine 4-0 consumers reads. The cover is ADDITIVE state; re-typing the card
##     layer to express it would make every existing reader pay for it.
##   * a SIBLING per-player container keyed by slot index would put "which slot is covered" one
##     object away from "what is in that slot", and the two must be cleared, resized and dealt
##     TOGETHER -- `Hand.clear(width)` is the one seat that knows the width, and a sibling would
##     need the width told to it a second time.
## What is left is a parallel array cleared, resized and filled in the same breath as `_cards`, which
## is `UnitBoard`'s own "one collection expressed as N arrays" discipline applied to two.
##
## THE UNDERLYING CARD NEVER LEAVES ITS SLOT, and that is what keeps `fill_at`'s and `remove_at`'s
## invariants meaningful for it (the story's Dev Notes requirement): covering is not a hand mutation.
## `fill_at` therefore still writes a delayed replacement into a COVERED but card-empty slot with no
## special case (AC 18: the owed refill lands UNDERNEATH the Boulder), because it reads and writes
## `_cards` alone.
##
## `EMPTY` IS THE UNCOVERED MARKER, the card layer's own constant reused rather than a second
## sentinel: "nothing here" is one fact and a Boulder id is a card id, so the two layers share a
## vocabulary and a slot can never be half-covered.
var _covers: Array[StringName] = []


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
## STORY 6-5e: THE COVER LAYER IS CLEARED AND RESIZED IN THE SAME BREATH, so the two arrays are one
## collection expressed as two and a width they disagree on is unrepresentable. A deal therefore lays
## down an UNCOVERED hand, which is what makes the debug reset's Boulder teardown (AC 23) true through
## this seat as well as through `clear_covers()`.
func clear(width: int) -> void:
	Invariant.check(width >= 0, "hand width %d is negative" % width)
	_cards.clear()
	_cards.resize(width)
	_cards.fill(EMPTY)
	_covers.clear()
	_covers.resize(width)
	_covers.fill(EMPTY)


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
## STORY 6-5e (AC 18): UNCHANGED, AND THAT IS THE POINT. A slot covered by a Boulder whose card layer
## is empty is filled here with no special case -- the owed replacement lands UNDERNEATH the Boulder
## rather than being blocked or redirected -- because this function reads and writes the CARD layer
## alone and the cover is not a card. The occupied-slot refusal still guards the card it was written
## for.
func fill_at(index: int, id: StringName) -> void:
	Invariant.check(index >= 0 and index < _cards.size(),
		"hand slot %d out of range (hand is %d wide)" % [index, _cards.size()])
	Invariant.check(id != EMPTY, "cannot fill hand slot %d with the empty marker" % index)
	Invariant.check(_cards[index] == EMPTY,
		"hand slot %d already holds %s — a fill would destroy a card" % [index, _cards[index]])
	_cards[index] = id


## ------------------------------------------------------------------------------------------
## STORY 6-5e: THE COVER LAYER'S OWN SURFACE.
## ------------------------------------------------------------------------------------------

## Is this slot covered? LENIENT ON THE INDEX, on `is_slot_empty`'s own precedent and for its reason:
## the callers include the four mode-dispatch refusal gates, which judge a slot index that arrived on an
## intent, and "there is no such slot" must not trip a guard. An out-of-range slot is not covered.
func is_covered(index: int) -> bool:
	if index < 0 or index >= _covers.size():
		return false
	return _covers[index] != EMPTY


## PLANT a cover on one named slot (AC 16/AC 18). The card layer is not read and not written.
##
## THE OCCUPANCY OF THE CARD LAYER IS IRRELEVANT HERE, deliberately: ruling 6 covers a card and an
## EMPTY mid-draw-delay hole through the SAME placement, so a guard on the card would refuse half the
## ruling. What IS refused is DOUBLE-COVERING, which is the cover layer's own `fill_at`: a second
## Boulder on one slot would lose the first and make `cover_count()` disagree with what is on the board.
## The eligible-slot pick excludes covered slots already (AC 16), so reaching this is a bypassed caller.
func cover_at(index: int, id: StringName) -> void:
	Invariant.check(index >= 0 and index < _covers.size(),
		"hand slot %d out of range (hand is %d wide)" % [index, _covers.size()])
	Invariant.check(id != EMPTY, "cannot cover hand slot %d with the empty marker" % index)
	Invariant.check(_covers[index] == EMPTY,
		"hand slot %d is already covered by %s — the eligible-slot pick excludes covered slots"
				% [index, _covers[index]])
	_covers[index] = id


## LIFT the cover off one named slot and return the id that was on it (AC 21/AC 27). The card beneath
## is UNTOUCHED and is therefore immediately playable again, in the same slot, unmoved -- AC 21's "the
## underlying card was never removed from the hand" is this function not naming `_cards`.
##
## `remove_at`'s INVARIANT SHAPE, for its reason: every shipped caller has already established that
## the slot is covered (the Mode ① fork asks `is_covered`, Boom walks `covered_indices()`), so an
## uncovered index arriving here means the guard above it was bypassed.
func uncover_at(index: int) -> StringName:
	Invariant.check(is_covered(index),
		"hand slot %d carries no cover (hand is %d wide, %d covered) — the caller's guard was bypassed"
				% [index, _covers.size(), cover_count()])
	var id: StringName = _covers[index]
	_covers[index] = EMPTY
	return id


## THE VISIBLE LAYER at one slot: the cover if there is one, otherwise the card, otherwise `EMPTY`.
##
## THE ORDER IS THE WHOLE MECHANIC (ruling 6: the Boulder "sits ON TOP"), expressed once here so the
## Mode ① dispatch, the HUD payload and any later reader cannot each pick their own layering. LENIENT
## ON THE INDEX, `is_slot_empty`'s reason again.
func visible_id_at(index: int) -> StringName:
	if index < 0 or index >= _cards.size():
		return EMPTY
	if _covers[index] != EMPTY:
		return _covers[index]
	return _cards[index]


## `to_array()`'s VISIBLE twin -- the width view with every cover on top of its slot, freshly built.
##
## THIS IS WHAT `cards_changed` CARRIES (AC 24/AC 24a), and choosing it over a second payload element is
## the reason the HUD needs no new observation seam for the covered-slot look: `_render_hand_row`'s
## existing first branch renders whatever id a slot shows, so it renders the Boulder, never the card
## beneath it, and it does so IN PRECEDENCE over the `pending_draw_owed` branch for free -- a covered
## slot shows a non-EMPTY id and the owed branch is an `elif`. AC 24a's precedence is therefore a
## property of this ordering rather than of a branch someone has to keep in the right place.
##
## `to_array()` IS UNCHANGED and still returns the CARD layer, because that is what the four-term
## conservation proofs and `occupied_ids()` are about. Two readings, two methods -- the `size()` /
## `occupied_count()` split of story 4-0, applied to a second axis.
func visible_array() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(_cards.size())
	for i in _cards.size():
		out[i] = visible_id_at(i)
	return out


## HOW MANY COVERS ARE LIVE (S1, `6-5e/R28`): the Boulder slow's one input, and Boom's count of what it
## would detonate. A pure fold over the cover layer, never a stored counter -- a second member could
## disagree with the array, which is `PitchState`'s no-ready-flag argument verbatim.
func cover_count() -> int:
	var n := 0
	for id in _covers:
		if id != EMPTY:
			n += 1
	return n


## THE COVERED SLOT INDICES, ASCENDING BY CONSTRUCTION -- `ProjectileBoard.living_indices()`'s shape and
## its reason: Boom detonates every one of them in one resolution (AC 27) and needs a deterministic
## order at the source rather than from a sort it would have to trust.
func covered_indices() -> Array[int]:
	var out: Array[int] = []
	for i in _covers.size():
		if _covers[i] != EMPTY:
			out.append(i)
	return out


## THE HASHED PER-SLOT COVER MASK (AC 38, Golden Prediction cause 1). A plain `Array[bool]` -- a type
## `CanonicalHash` has an explicit branch for -- and never the ids: every cover is the one Boulder card,
## so the id would be a constant repeated per slot, and a `StringName` reaching the hash is the failure
## mode every card-container key in `player_state.gd` exists to avoid.
##
## WHAT IS UNDERNEATH IS NOT HERE, AND THAT IS ARGUED RATHER THAN OMITTED (AC 38's "or is a pure
## function of hashed facts"). The covered card never leaves `_cards`, so "what id is underneath" is
## exactly `to_array()[slot]` -- the hand's own contents, which ride the THIRD member of
## `test_replay_identity.gd`'s unhashed-cross-tick exclusion set (the card containers' contents and
## order, sound because seed plus injected composition plus the recorded intent stream reproduce them).
## Hashing it here would not add a fact; it would move an existing excluded fact into the hash and
## poison it with a StringName.
func covers_snapshot() -> Array:
	var out: Array = []
	out.resize(_covers.size())
	for i in _covers.size():
		out[i] = _covers[i] != EMPTY
	return out


## TEAR DOWN every cover, leaving the card layer and the width untouched (AC 23). The round-end and
## debug-reset seat: every covered card returns to normal playable status in its own slot, unmoved,
## which is this function not naming `_cards`.
##
## A NO-OP ON AN UNCOVERED HAND, so the two callers need no `cover_count()` guard first.
func clear_covers() -> void:
	_covers.fill(EMPTY)
