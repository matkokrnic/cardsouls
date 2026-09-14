class_name PitchState
extends RefCounted

## D8 sole owner of the fizzle shared-deadline. The fizzle deadline is a D4 TimingWindow owned here;
## every system QUERIES this object, none holds its own copy of fizzle time (Binding Constraint #4).
##
## STORY 6-2 FILLS THE RESERVED SEAT. The zone is PER-PLAYER and fully independent (`E6-P/R4`), and it
## stays ONE object owned by MatchState under the ONE existing `"pitch"` snapshot key (AC 14a) -- a
## `PitchState` on each `PlayerState` would remove `"pitch"` from the pinned top-level key set and add
## two per-player keys in its place. The per-slot records are INDEX-ALIGNED ARRAYS, the
## `MatchState._lock_directions[slot]` / `UnitBoard` shape: slot 0 is P1, slot 1 is P2, and every
## member below is two entries long for the life of the object.
##
## A STAGED-CARD RECORD is two hashed facts plus a countdown: the card id, and the hand slot it was
## staged FROM (held empty and reserved until the card leaves the zone, AC 3/AC 8). An EMPTY zone
## reads `NO_CARD` / `NO_HAND_SLOT`, and a stopped window.
##
## `card_id`/`hand_slot` ARE HASHED (AC 14b) -- a deliberate departure from `3-3`'s counts-only rule,
## safe here because the staged card is PUBLIC by GDD design, unlike hand contents. THE ORB PRICE IS
## NOT HASHED: it is card `.tres` CONTENT, and `3-2`'s close-out ruled card content out of the hashed
## run permanently (repricing a card must never re-baseline the golden). `_orb_costs` below stays an
## unhashed per-slot cache for `is_ready()` alone -- excluded from `to_snapshot()` on purpose. The
## "frozen at staging" guarantee this cache exists for comes from the injection discipline (the price
## is copied once, at staging, off a map injected once at match start with no reload path), not from
## being hashed; hashing it was never required for that guarantee to hold.
##
## THERE IS NO READY FLAG, AND THAT IS AC 10 BY CONSTRUCTION. Mana is spent at staging, orbs only grow
## inside the window, so "is this staged card ready" is DERIVED from the live pool every time it is
## asked (`is_ready`) and never latched into a member a replay would have to reproduce.
##
## A PURE CONTAINER, the `UnitBoard` discipline: it mutates only when MatchState's ordered dispatch
## tells it to, owns no RNG, reads no balance and names no card library. The ONE thing it borrows is
## `CastEvaluator.orb_costs_affordable`, a static pure function, so the sorted-colour iteration READY
## depends on lives in exactly one place.

## "No card staged" -- the empty StringName, `Hand.EMPTY`'s value and reasoning: no authored card can
## carry it (test_card_authoring.gd pins every id non-empty).
const NO_CARD := &""
## "No hand slot reserved". Readers test the NAME, never a bare -1.
const NO_HAND_SLOT := -1

var _card_ids: Array[StringName] = [NO_CARD, NO_CARD]
var _hand_slots: Array[int] = [NO_HAND_SLOT, NO_HAND_SLOT]
## Per slot: `Enums.CardColor` -> count, copied BY VALUE at staging so a later edit to the injected
## condition cannot re-price a card already in the zone. UNHASHED (see the class doc above) -- read
## only through `staged_orb_costs()`, never emitted through `to_snapshot()`.
var _orb_costs: Array[Dictionary] = [{}, {}]
var _fizzle: Array[TimingWindow] = [TimingWindow.new(), TimingWindow.new()]


## Put `card_id`, staged from `hand_slot`, into `slot`'s zone and start its countdown. The caller
## (MatchState._resolve_pitch_stage) has already refused an occupied zone, so an overwrite here is a
## programming error and says so.
func stage(slot: int, card_id: StringName, hand_slot: int, orb_costs: Dictionary,
		duration_ticks: int) -> void:
	Invariant.check(not is_staged(slot),
		"pitch zone %d already holds %s -- the already-staged refusal was bypassed" % [slot, _card_ids[slot]])
	Invariant.check(card_id != NO_CARD, "cannot stage the empty card id into pitch zone %d" % slot)
	_card_ids[slot] = card_id
	_hand_slots[slot] = hand_slot
	_orb_costs[slot] = orb_costs.duplicate()
	_fizzle[slot].start(duration_ticks)


## Empty `slot`'s zone and stop its countdown. Used by the fizzle exit, by activation (story 6-3a) and
## by the debug reset; a no-op on an already-empty zone.
func clear(slot: int) -> void:
	_card_ids[slot] = NO_CARD
	_hand_slots[slot] = NO_HAND_SLOT
	_orb_costs[slot] = {}
	_fizzle[slot].start(0)


## One tick off both countdowns, P1 then P2. A stopped window ignores the tick (TimingWindow.tick).
func tick() -> void:
	_fizzle[0].tick()
	_fizzle[1].tick()


func is_staged(slot: int) -> bool:
	return _card_ids[slot] != NO_CARD


## A staged card whose countdown has closed. Asked once per tick by the fizzle exit.
func is_expired(slot: int) -> bool:
	return is_staged(slot) and not _fizzle[slot].is_running


func staged_card_id(slot: int) -> StringName:
	return _card_ids[slot]


func staged_hand_slot(slot: int) -> int:
	return _hand_slots[slot]


## AC 10: READY, DERIVED LIVE. A staged card whose orb price `orbs` satisfies right now -- with an
## empty price, or the `orbs` layer off, reading satisfied (the `CastEvaluator` graceful-degrade rule).
## An empty zone is never ready. Reads, never writes: nothing here consumes or signals.
func is_ready(slot: int, orbs: OrbPool, flags: FeatureFlags) -> bool:
	return is_staged(slot) and CastEvaluator.orb_costs_affordable(staged_orb_costs(slot), orbs, flags)


## Story 6-3a (AC 7/AC 11): the staged card's orb price, BY VALUE -- the ONE read seat for it. `is_ready()`
## directly above and `MatchState._resolve_pitch_activate`'s spend both read through here, so the READY
## check and the spend can never price the card two different ways. An accessor, not a member: nothing
## about `to_snapshot()` changes. An empty zone reads `{}`.
func staged_orb_costs(slot: int) -> Dictionary:
	return _orb_costs[slot].duplicate()


## Both zones, slot-keyed like MatchState's own `p1` / `p2`. The card id rides as a String VALUE --
## never a key, the StringName-sort hazard this layer avoids everywhere. The orb price is NOT a
## member here (see the class doc's `3-2` note) -- a consumer that needs it derives it from the
## already-hashed `card_id` through the injected pitch-cost map (`MatchState._pitch_costs`).
func to_snapshot() -> Dictionary:
	return {"p1": _zone_snapshot(0), "p2": _zone_snapshot(1)}


func _zone_snapshot(slot: int) -> Dictionary:
	return {
		"card_id": String(_card_ids[slot]),
		"hand_slot": _hand_slots[slot],
		"fizzle": _fizzle[slot].to_snapshot(),
	}
