class_name UnitSwingDedupe
extends RefCounted

## Story 4-3b (AC 16, `4-3b/R14` as amended): the per-unit SWING DEDUPE RECORDS — the unit-attacker
## twin of `HeroState._swing_dedupe` (hero_state.gd), and the one piece of this story's new unit
## attack state that does NOT live on `UnitBoard`.
##
## WHY IT IS A CLASS BESIDE THE BOARD RATHER THAN A SIXTH PARALLEL ARRAY. `unit_board.gd`'s own
## header rule forbids a non-scalar per-record field: every value crossing a tick boundary there is
## a plain scalar, with no nested typed array to lose its element type and no Dictionary whose
## iteration order could decide anything. A dedupe record is a LIST OF TARGET ADDRESSES — a nested
## array by construction — so it cannot join the board without repealing the rule that keeps objects
## and unordered containers out of the hash. `4-3b/R14` accepted the cost by name: one small new
## state class.
##
## WHY THE UNIT DOES NOT SHARE THE HERO'S RECORDS, measured (`4-3b/R12`). A unit cannot share the
## hero's monotonic `attack_index`: it is incremented only when a HERO starts a swing and it is
## snapshotted, so driving it from unit swings would move hero-observed values — an unnamed golden
## cause. It cannot share the hero's `_swing_dedupe` records either: their grace lifetime is driven
## by the HERO's own active window, which has nothing to do with a unit's. So the unit gets its own
## counter (on the board, AC 16) and its own records (here), and the hero side is untouched.
##
## ONE LIVE RECORD PER UNIT, AND THAT IS THE ONE PLACE THE SHAPE DIVERGES FROM THE HERO'S. A hero
## can hold SEVERAL records at once, because a chain pressed on the first recovery tick starts a new
## swing while the old record is still in its grace tick. A unit has NO CHAIN (the Non-Goals: no
## movesets, no multiple attacks per minion), and its rhythm is strictly windup -> active ->
## recovery -> idle, so a second swing cannot begin before the previous record has expired. The
## record is therefore keyed by BOARD INDEX alone, carrying the `attack_index` it belongs to, rather
## than by a per-unit dictionary of attack indices — the simpler structure that the actual rhythm
## permits, not a narrowing of the hero's contract.
##
## GRACE SEMANTICS ARE THE HERO'S VERBATIM (hero_state.gd:134-144): -1 means the swing's active
## window is still open (record alive); 1 means the window closed and the record lives exactly ONE
## more tick, absorbing the F1 one-tick fact lag (a contact gathered on the last active tick arrives
## the tick after close and is still legitimate); erased at 0.
##
## SNAPSHOTTED (AC 16), for the reason the hero's records are: mid-swing dedupe state excluded from
## the snapshot would be a determinism/replay hole. The payload is built canonically — records
## emitted in ASCENDING BOARD INDEX — so a `Dictionary`'s iteration order never reaches the hash.

## Board index -> {"attack_index": int, "hit": Array (of [slot, index] pairs), "grace": int}.
## PRIVATE and reached only through the methods below; nothing hands a caller a handle into it.
var _records: Dictionary = {}


## Open a record for the unit at `board_index`, called at the moment its ACTIVE window opens — the
## unit twin of `HeroState.enter_attack`'s record creation. Grace -1: the window is open.
##
## UNCONDITIONAL OVERWRITE, and that is correct rather than sloppy: one live record per unit (see
## the header), so an existing record here belongs to a swing whose active window has already
## closed and whose grace tick this unit's next active window cannot legitimately reach. Writing
## over it is what keeps "the record describes the CURRENT swing" true by construction.
func open(board_index: int, attack_index: int) -> void:
	_records[board_index] = {"attack_index": attack_index, "hit": [], "grace": -1}


## The unit twin of `HeroState.register_swing_hit` (hero_state.gd), including every reason it has.
## Returns true iff the fact's `attack_index` matches this unit's LIVE record AND this swing has not
## already registered that TARGET ADDRESS — and then records the address, so a second same-swing
## contact against the same address returns false. A false return means the fact is DROPPED (stale,
## unknown, or duplicate).
##
## SO A UNIT SWING CLEAVES (AC 4). Overlapping three targets in one active window produces three
## separate registrations rather than one, because the key is the full `[slot, index]` ADDRESS and
## not a bare slot — the `4-3a/R16` widening applied to the second attacker kind.
##
## CANONICAL ORDER ON INSERTION (`4-3a/R22`, followed rather than reinvented): the hit list is kept
## SORTED by target address, `[slot, index]` ascending, never left in append order. A cleave lets one
## swing register several addresses in a single tick and their arrival order is whatever the runner's
## physics overlap query happened to produce — a query that pins no ordering. This list is
## snapshotted and hashed, so an unpinned arrival order would make the hash depend on physics-query
## ordering. Sorting on INSERTION (rather than at snapshot time) keeps the stored state itself
## canonical, which is the simpler invariant to hold. `Array.sort()` on an array of `[slot, index]`
## arrays compares element-wise, so it sorts lexically for free.
func register(board_index: int, attack_index: int, target_slot: int, target_index: int) -> bool:
	if not _records.has(board_index):
		return false
	var record: Dictionary = _records[board_index]
	if int(record["attack_index"]) != attack_index:
		return false
	var hit: Array = record["hit"]
	var address: Array[int] = [target_slot, target_index]
	if address in hit:
		return false
	hit.append(address)
	hit.sort()
	return true


## Called when a unit's ACTIVE window closes: the record enters its single grace tick, exactly as
## `HeroState.tick_timers()` does for a hero whose active window just stopped. A unit with no record
## (it never opened one, or the record already expired) is a no-op rather than an error — the caller
## is a per-tick phase transition, not an assertion site.
func close(board_index: int) -> void:
	if _records.has(board_index):
		_records[board_index]["grace"] = 1


## Advance every record's grace by one tick, erasing at zero — the hero's own `tick_timers()` loop
## verbatim. Records with grace -1 (window still open) are untouched.
func tick() -> void:
	for board_index: int in _records.keys():
		var grace := int(_records[board_index]["grace"])
		if grace <= 0:
			continue
		grace -= 1
		if grace == 0:
			_records.erase(board_index)
		else:
			_records[board_index]["grace"] = grace


## Emptied by the DEBUG RESET ONLY, cleared in the same seat that clears the board — for
## `UnitBoard.clear()`'s own reason applied to the container beside it: the two are one collection
## expressed as two, and a dedupe record surviving a board clear would key an index that no longer
## names the unit it was opened for.
func clear() -> void:
	_records.clear()


## Review fix pass (4-3b, F2): called when the unit at `board_index` DIES, from the one call site
## that already knows it (`_resolve_unit_contact`, immediately after `apply_damage_at`). Without
## this seat a unit killed during its own ACTIVE window leaves its record open FOREVER: the record
## opens with `grace == -1` (window open) at `open()` and only `close()` — called from
## `_advance_unit_attacks`'s phase transition — moves it to a grace tick `tick()` can erase, but
## that function SKIPS dead units entirely (`is_alive_at` false), so a corpse's still-open record
## never reaches `close()` and `tick()`'s own `grace <= 0: continue` guard means it never touches
## a `-1` record either. Nothing ever removes it: hashed state grows one entry per unit that dies
## mid-window and never shrinks, keyed by a board index the board itself never recycles.
##
## ERASED OUTRIGHT rather than routed through `close()`'s one-tick grace: the grace exists to
## absorb the F1 one-tick fact lag for THIS unit's own future facts as an attacker, but a dead
## attacker's facts are already dropped one rung earlier, by `_attacker_is_dead`, before they can
## ever reach dedupe registration — so the extra tick has nothing left to protect. A no-op if the
## unit never opened a record (died before its first swing) or the record already closed and
## erased through the normal path, the same "caller is a per-tick phase transition, not an
## assertion site" discipline `close()` documents above.
func discard(board_index: int) -> void:
	_records.erase(board_index)


func size() -> int:
	return _records.size()


## AC 16's snapshot payload. CANONICAL BY CONSTRUCTION: records are emitted in ASCENDING BOARD
## INDEX, and each is a flat `[board_index, attack_index, hit...]`-shaped entry rather than the
## stored Dictionary, so no `Dictionary` iteration order and no key ordering can reach the hash.
## `CanonicalHash` would sort a Dictionary's keys anyway; building the payload sorted here means the
## guarantee does not depend on that, which is the same reason the hit list is sorted on insertion
## rather than at snapshot time.
##
## Freshly built each call, and the hit list is DUPLICATED, so no caller receives a handle into a
## live record (the `4-0` review's aliased-array finding, not repeated).
func snapshot() -> Array:
	var indices: Array = _records.keys()
	indices.sort()
	var out: Array = []
	for board_index: int in indices:
		var record: Dictionary = _records[board_index]
		out.append([board_index, int(record["attack_index"]), int(record["grace"]),
				(record["hit"] as Array).duplicate(true)])
	return out
