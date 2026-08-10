class_name UnitBoard
extends RefCounted

## Story 4-1 (AC 4): the per-player BOARD — the collection `docs/game-architecture.md` D9
## reserved for this story ("PlayerState will gain a `units`/board collection with its first
## consumer, story 4-1"). The FOURTH pure container, alongside Deck, Hand and DiscardPile and
## built to the same shape as all three: PURE RefCounted, owned by PlayerState, no RNG, no
## SignalQueue, no scene reference, and nothing here names CardDatabase, CARDS_DIR or
## data/cards.
##
## ONE RECORD PER RESOLVED `summon_*` CAST, APPENDED IN CAST ORDER. The single writer for the
## record itself is MatchState's step-6 cast dispatch, through CardEffectResolver's verdict — the
## same "one seat, inside the ordered dispatch" rule the three sibling containers carry. Since
## story 4-2 there is a SECOND writer for record CONTENT ONLY (never for record existence):
## MatchState's step-7 throttled targeting tick, which writes the acquired target and can neither
## add nor remove a record.
##
## ------------------------------------------------------------------------------------------
## STORY 4-2 (AC 9): THE IDENTITY EXTENSION `4-1`'s OWN HEADER RESERVED FOR THIS STORY.
## ------------------------------------------------------------------------------------------
## 4-1 shipped this class as a bare `int`, and said so deliberately: "`4-2`'s gate rules on
## position ownership with `TargetingService` as a real consumer; whatever content a unit then
## needs is added THERE, against something that reads it." That consumer now exists, so the count
## becomes an ORDERED COLLECTION. Extending it is the header's own stated plan being executed, not
## a scope choice.
##
## THE IDENTITY IS THE BOARD INDEX, AND NOTHING ELSE IS ADDED. A record is addressed by its
## position in cast order; that index is stable because records are only ever APPENDED (the single
## step-6 writer) and the collection is only ever emptied WHOLE (the debug reset). This is exactly
## the identity AC 11's `[slot, index]` pair addresses, so the addressing scheme and the stored
## verdict are the same fact rather than two that could drift.
##
## STILL POSITIONLESS AND STILL TYPE/KIND-LESS. Three clauses that emptied the 4-1 record are
## UNCHANGED and must not be quietly relaxed: `4-2/R14` defers position ownership AGAIN, to 4-3,
## with movement named as the forcing point (position stays actor-owned, no `Vector3` here); the
## ratified TOTEM CLAUSE keeps the record free of a type/kind field, so uniform `summon_*`
## treatment does not pre-commit `4-4`'s differentiation; and `4-2/R17` keeps a PRIORITY reference
## off the record too, with the first story where units actually differ (4-3 / 4-4) named as the
## story allowed to add one.
##
## WHAT A RECORD CARRIES IS THEREFORE: its index (implicit), plus the target it has acquired.
##
## TWO PARALLEL `Array[int]`s, NOT AN ARRAY OF PAIRS, and the shape is deliberate. Every value
## crossing a tick boundary here is a PLAIN INT — no nested typed array to lose its element type on
## the way in or out, no Dictionary whose iteration order could decide anything, and no StringName
## anywhere near a comparison (`Array[StringName].sort()` orders by INTERNAL POINTER on this
## engine — player_state.gd:77, 206-207). The `[slot, index]` PAIR shape AC 11 states is assembled
## for the snapshot in `targets_snapshot()` and exists nowhere else.
##
## SNAPSHOTTED AS A COUNT PLUS THE TARGET PAIRS. `unit_count` stays bound to `size()` exactly as
## 4-1 shipped it — the identity extension moves it not at all, which is `4-2/R8`'s measured
## non-mover prediction — and `unit_targets` is AC 11's separate new key. No identity, no effect
## id, no position and no object reaches the hash from this file.

## Index-aligned, one entry per record, in cast order. A record's target is its pair
## (`_target_slots[i]`, `_target_indices[i]`): slot `-1` (TargetingService.NO_TARGET_SLOT) means NO
## TARGET, and with a real slot an index of `-1` addresses that player's HERO while `>= 0`
## addresses a unit on that player's board (AC 11).
var _target_slots: Array[int] = []
var _target_indices: Array[int] = []


## The ONE way a unit enters the board. Called from MatchState's step-6 cast dispatch, once per
## resolved `summon_*` cast. Still takes NO ARGUMENT: everything a record carries beyond its index
## is acquired later, by the step-7 tick, and a freshly summoned unit has acquired nothing yet — so
## it enters holding the honest NO-TARGET pair rather than a placeholder that could be mistaken for
## an acquired target of slot 0.
func add() -> void:
	var pair := TargetingService.no_target()
	_target_slots.append(pair[0])
	_target_indices.append(pair[1])


## Emptied by the DEBUG RESET ONLY, never by round end (`4-1/R5`): the board persists through
## the round-over freeze rather than blinking out at the instant of death, matching how every
## other piece of round-crossing state already behaves. MatchState._reset_player is the one
## caller; MatchState._end_round is deliberately untouched.
##
## Both arrays are cleared TOGETHER — they are one collection expressed as two, and an index that
## existed in one but not the other would be a record with half a target.
func clear() -> void:
	_target_slots.clear()
	_target_indices.clear()


func size() -> int:
	return _target_slots.size()


func is_empty() -> bool:
	return _target_slots.is_empty()


## THE PUBLIC PREDICATE the four bound guards below are wired to (`3-0c/R15`). Those guards are
## `Invariant.check`s, and an `Invariant.check` can never be proven by FIRING it: headless, it prints
## and continues with exit 0, so a test that "proves" a guard by tripping it proves nothing. The
## working shape is a public predicate tested in BOTH directions plus a source scan that every guard
## actually consults it -- both in test_targeting_service.gd. Nothing else in this file may re-derive
## the bound inline, or the scan is guarding a copy instead of the original.
func has_index(index: int) -> bool:
	return index >= 0 and index < size()


## The target acquired by the unit at `index`, as AC 11's `[slot, index]` pair. An out-of-range
## index is a programming error rather than a no-target answer: every caller iterates `size()`, so a
## bad index means the caller's own loop is wrong and returning a plausible-looking pair would hide
## it. Enforced at the seam with Invariant.check, the push_contact / inject_deck precedent.
func target_at(index: int) -> Array[int]:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return [_target_slots[index], _target_indices[index]]


## Read-only single-int accessors for the presentation side, which reads a target every physics
## frame for every spawned actor and must not allocate a pair to do it (the project-context
## Performance Rule on per-frame allocations in hot paths). Same bound enforcement as `target_at`.
func target_slot_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _target_slots[index]


func target_index_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _target_indices[index]


## The ONE writer of record content, called from MatchState's step-7 throttled tick and nowhere
## else. It can neither add nor remove a record — `add()` owns existence — so the board's length is
## unaffected by targeting no matter what the evaluator returns.
func set_target_at(index: int, slot: int, unit_index: int) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_target_slots[index] = slot
	_target_indices[index] = unit_index


## AC 11's snapshot payload: one `[slot, index]` pair per record, in board-index order. The ORDER IS
## MEANINGFUL and CanonicalHash preserves it (the `pending_draw_owed` precedent) — a target held by
## the wrong unit is a real divergence the hash should see. Freshly built each call, so no caller
## receives a handle into this container.
func targets_snapshot() -> Array:
	var out: Array = []
	for i in _target_slots.size():
		out.append([_target_slots[i], _target_indices[i]])
	return out
