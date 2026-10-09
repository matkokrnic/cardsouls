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

## Story 6-5d (AC 5/AC 7/AC 30, `6-5d/R1`/`R2`, Open Question 5): THE VARIABLE COST'S TWO FROZEN
## FACTS, per slot.
##
## `_mana_spent` IS RECORDED FOR EVERY STAGING, VARIABLE OR FIXED, and that uniformity is deliberate
## rather than incidental: it means "what this staging actually paid", which is a true and useful fact
## about a fixed-price card too, and it leaves the staging seat with no is-this-variable branch to get
## wrong. `_locked_damage` is 0.0 for every card that authors no `damage_per_mana`, which is every
## pitch card but Fireball today.
##
## THEY ARE TWO FACTS, NOT ONE EXPRESSED TWICE, and Open Question 5 is exactly why. `_mana_spent` is
## HOW MUCH THE PLAYER PAID (AC 5's "the staged card remembers the spent amount") -- a player-facing
## quantity. `_locked_damage` is the FROZEN PRODUCT `damage_per_mana x mana spent` (AC 7). At staging
## the second is derivable from the first, and after an authored `damage_per_mana` retune it is NOT:
## freezing the product is what makes "mana gained or lost after staging cannot change a staged card's
## damage" survive a retune too, which is the boundary the dev pass was asked to pick and pin.
##
## BOTH ARE HASHED (`to_snapshot` below), unlike `_orb_costs`. The `3-2` close-out excluded card
## `.tres` CONTENT from the hashed run so repricing a card cannot re-baseline the golden -- and
## neither of these is content: they are the outcome of a PLAYER ACTION against a live pool, the same
## class of fact as `mana` itself. They cross ticks and decide an outcome (what the Fireball hits
## for), so `4-3a/R17`'s test puts them in the hash.
var _mana_spent: Array[float] = [0.0, 0.0]
var _locked_damage: Array[float] = [0.0, 0.0]

## Story 7-4 (AC 6/AC 8/AC 10, `7-4/R2`/`R11`): THE FRESH ORBS, per slot -- `Enums.CardColor` -> count of
## orbs EARNED while a SORCERY sits in this zone. Credited only through `credit_fresh_orbs` (whose one
## caller is `MatchState._grant_landing_orbs`, the only orb faucet), and only for a staged sorcery; an
## instant's count stays empty. It counts the GRANT, not what the bank kept: an orb earned into a colour
## already at its cap still counts here while the pool clamps (`7-4/R11`).
##
## HASHED (`to_snapshot`), unlike the card's speed: it is not content but the outcome of play across
## ticks, and it decides when the card can resolve -- `_mana_spent`'s class of fact. It STARTS EMPTY at
## every `stage()` and empties in `clear()`, the zone's one exit seat, so an empty zone never carries one.
## READY stays DERIVED: there is still no latch, only this count and the live pool.
var _fresh_orbs: Array[Dictionary] = [{}, {}]


## Put `card_id`, staged from `hand_slot`, into `slot`'s zone and start its countdown. The caller
## (MatchState._resolve_pitch_stage) has already refused an occupied zone, so an overwrite here is a
## programming error and says so.
## Story 6-5d (AC 5/AC 7): `mana_spent` and `locked_damage` arrive as ARGUMENTS the caller has already
## computed, on `UnitBoard.add(max_hp)`'s discipline verbatim: this is a pure container and never reads
## an effect, a `BalanceConfig` or a pool. A fixed-cost staging passes 0.0 for both.
func stage(slot: int, card_id: StringName, hand_slot: int, orb_costs: Dictionary,
		duration_ticks: int, mana_spent: float, locked_damage: float) -> void:
	Invariant.check(not is_staged(slot),
		"pitch zone %d already holds %s -- the already-staged refusal was bypassed" % [slot, _card_ids[slot]])
	Invariant.check(card_id != NO_CARD, "cannot stage the empty card id into pitch zone %d" % slot)
	_card_ids[slot] = card_id
	_hand_slots[slot] = hand_slot
	_orb_costs[slot] = orb_costs.duplicate()
	_fizzle[slot].start(duration_ticks)
	_mana_spent[slot] = mana_spent
	_locked_damage[slot] = locked_damage
	# Story 7-4 (AC 8): every staging starts with nothing earned -- an orb banked before (or on) this
	# tick never counts toward a sorcery.
	_fresh_orbs[slot] = {}


## Empty `slot`'s zone and stop its countdown. Used by the fizzle exit, by activation (story 6-3a) and
## by the debug reset; a no-op on an already-empty zone.
func clear(slot: int) -> void:
	_card_ids[slot] = NO_CARD
	_hand_slots[slot] = NO_HAND_SLOT
	_orb_costs[slot] = {}
	_fizzle[slot].start(0)
	# Story 6-5d: cleared WITH the record, so an empty zone can never carry a stale price or a stale
	# frozen damage into the hash -- the `telegraph` gate's guarantee bought by a clear instead of a
	# gate, because this snapshot has no "is a card staged" conditional to hang one on.
	_mana_spent[slot] = 0.0
	_locked_damage[slot] = 0.0
	# Story 7-4 (AC 8): the fresh count leaves with the card, at all three exits (activation, fizzle,
	# debug reset) because all three come through here.
	_fresh_orbs[slot] = {}


## Story 7-4 (AC 6/AC 10): `amount` orbs of `color` were EARNED into `slot`'s owner's bank while a sorcery
## sits in the zone. The caller decides that it is a staged sorcery (it holds the injected speed); this
## container only counts. Counts the full `amount` whatever the pool kept (`7-4/R11`).
func credit_fresh_orbs(slot: int, color: Enums.CardColor, amount: int) -> void:
	Invariant.check(is_staged(slot), "fresh orbs credited to the empty pitch zone %d" % slot)
	_fresh_orbs[slot][color] = int(_fresh_orbs[slot].get(color, 0)) + amount


## Story 7-4 (AC 13): the orbs earned since staging, per colour, BY VALUE. Empty for an empty zone and
## for an instant.
func fresh_orbs(slot: int) -> Dictionary:
	return _fresh_orbs[slot].duplicate()


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
##
## Story 7-4 (AC 4-6/AC 9, `7-4/R14`): `sorcery` is the staged card's speed, READ by the caller off the
## injected pitch-cost map at every call and never cached here. An instant asks the bank alone (the rule
## above, byte for byte). A sorcery ALSO needs its price covered by the orbs earned since staging --
## AND still by the bank, which only matters after a hot reload lowers the orb cap and clamps the pool.
## The same degrade rule applies to both halves, so an empty price or the orbs layer off reads READY for
## either speed.
func is_ready(slot: int, orbs: OrbPool, flags: FeatureFlags, sorcery: bool = false) -> bool:
	if not is_staged(slot):
		return false
	var orb_costs := staged_orb_costs(slot)
	if not CastEvaluator.orb_costs_affordable(orb_costs, orbs, flags):
		return false
	return not sorcery or CastEvaluator.orb_costs_covered_by(orb_costs, _fresh_orbs[slot], flags)


## Story 6-3a (AC 7/AC 11): the staged card's orb price, BY VALUE -- the ONE read seat for it. `is_ready()`
## directly above and `MatchState._resolve_pitch_activate`'s spend both read through here, so the READY
## check and the spend can never price the card two different ways. An accessor, not a member: nothing
## about `to_snapshot()` changes. An empty zone reads `{}`.
func staged_orb_costs(slot: int) -> Dictionary:
	return _orb_costs[slot].duplicate()


## Story 6-5d (AC 5): the mana this staging actually spent -- the fixed price for a fixed-cost card,
## `min(pool, mana_cap)` for a variable one. 0.0 for an empty zone.
func staged_mana_spent(slot: int) -> float:
	return _mana_spent[slot]


## Story 6-5d (AC 7): the damage frozen at staging -- `damage_per_mana x mana spent`, no rounding.
## 0.0 for a card authoring no `damage_per_mana`, and for an empty zone.
func staged_locked_damage(slot: int) -> float:
	return _locked_damage[slot]


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
		# Story 6-5d (AC 30): the variable cost's two frozen facts -- see the members for why they are
		# two keys and why they are hashed at all. Plain floats, the `unit_hp` class; resting 0.0.
		"mana_spent": _mana_spent[slot],
		"locked_damage": _locked_damage[slot],
		# Story 7-4 (AC 8/AC 11): the orbs earned since staging, ALL THREE orb colours always present with
		# ASCII keys (the `OrbPool.to_snapshot` shape), so the key set never depends on what was earned.
		# Resting zeros for an empty zone and for an instant.
		"fresh_orbs": {
			"red": int(_fresh_orbs[slot].get(Enums.CardColor.RED, 0)),
			"blue": int(_fresh_orbs[slot].get(Enums.CardColor.BLUE, 0)),
			"green": int(_fresh_orbs[slot].get(Enums.CardColor.GREEN, 0)),
		},
	}
