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

## ------------------------------------------------------------------------------------------
## STORY 4-3a (AC 1): THE THIRD PARALLEL ARRAY — hp.
## ------------------------------------------------------------------------------------------
## The `4-2/R17(c)` permission spent, on EXACTLY this one field (`4-3a/R6`). Still a PLAIN FLOAT per
## record and still index-aligned with the two above, so the "no nested typed array, no Dictionary,
## no StringName" reasoning in this file's header covers it unchanged.
##
## NO PER-UNIT MAXIMUM, deliberately. Maximum HP is authored ONCE on `BalanceConfig.unit_max_hp` and
## shared by every minion, because no unit differs from another yet — the ratified totem clause
## keeps the record type/kind-less, so a per-record maximum would be N copies of one authored
## number. A unit enters at that maximum, passed IN to `add()` by the caller (below).
##
## LIVENESS IS DERIVED FROM THIS FIELD AND STORED NOWHERE (`is_alive_at`, `hp > 0.0`) — the
## `HeroState.is_alive()` shape verbatim. There is deliberately no separate `_alive: Array[bool]`:
## two fields expressing one fact is exactly how a corpse ends up simultaneously dead and alive.
## THIS IS ALSO THE HOLE REPRESENTATION AC 7 asks for. A dead unit's record is not removed and not
## blanked — it stays at its index carrying `hp <= 0`, which is what makes the hole a value rather
## than a second structure to keep in sync.
var _hp: Array[float] = []

## ------------------------------------------------------------------------------------------
## STORY 4-3b (AC 16, `4-3b/R14` AS AMENDED AT THE GATE): FIVE MORE PARALLEL ARRAYS — the unit
## ATTACK RHYTHM. `4-3a` spent the `4-2/R17`(c) permission on `hp` alone and gave `4-3b` NO advance
## permission (`4-3a/R6`); this story obtained its own grant, and the grant is FIVE scalar fields.
## ------------------------------------------------------------------------------------------
## STILL PLAIN SCALARS, STILL INDEX-ALIGNED, so the header's "no nested typed array, no Dictionary,
## no StringName" reasoning covers all five unchanged. The DEDUPE HIT LIST — the sixth thing a unit
## swing needs — is precisely the field that CANNOT live here, because it is a list of addresses;
## it lives in `UnitSwingDedupe` beside the board, which is that class's whole reason for existing.
##
## THE DURATIONS ARE NOT HERE. Windup/active/recovery lengths are GLOBAL, authored once on
## `BalanceConfig` and shared by every minion (AC 1), because no unit differs from another yet — the
## same reasoning that keeps `unit_max_hp` off the record. What is per-record is only WHERE IN THE
## RHYTHM this particular unit is.

## Which phase of its swing the unit at each index is in. A STORED enum rather than a derived one,
## and that is the one place this diverges from `HeroState`, deliberately: a hero derives its phase
## from WHICH `TimingWindow` OBJECT is running (`attack_phase()`), and per-record OBJECTS are exactly
## what this file's header rule forbids. An int per record is the scalar form of the same fact.
enum AttackPhase { IDLE, WINDUP, ACTIVE, RECOVERY }

var _attack_phase: Array[int] = []

## Ticks remaining in the CURRENT phase, counted down one per `advance()` (A1 — integer ticks, never
## a float accumulator). Zero while IDLE. It crosses ticks and decides an outcome, so it is
## snapshotted (`4-3a/R17`'s standing reasoning).
var _attack_ticks: Array[int] = []

## The ATTACKER-TO-TARGET planar direction captured at windup start (AC 12) — a `Vector2`, which
## `CanonicalHash` has an explicit branch for (`test/canonical_hash.gd`, TYPE_VECTOR2), which is the
## condition AC 12 attaches to the dev pass's free choice of encoding. It is a VALUE type carrying no
## element type to lose and no iteration order to depend on, so the header rule holds.
##
## IT IS THE NEGATION OF THE FACT'S OWN FIELD. The contact fact carries TARGET-to-ATTACKER
## (`push_contact`'s `target_to_attacker`, computed by the runner as `attacker - target`), so a unit's
## attack direction is that vector NEGATED — storing it un-negated would lock a backwards swing.
##
## THE FREEZE IS THE LOCK, AND IT NEEDS NO SIXTH FIELD (AC 12's own implementation note): while the
## swing cannot land this field is refreshed to the latest known direction to the acquired target,
## and across WINDUP and ACTIVE nothing writes it. `set_attack_dir_at` is therefore called only under
## a phase test at its one call site — see `MatchState._mark_reach_from_fact`, whose docstring
## records why the freeze covers windup and active rather than running through recovery, and that
## the story did not settle it.
var _attack_dir: Array[Vector2] = []

## The unit's OWN monotonic swing counter — the `HeroState.attack_index` equivalent, keying its
## entries in `UnitSwingDedupe`. Its own rather than the hero's, and `4-3b/R12` measured why: the
## hero's counter is incremented only by hero swings and is snapshotted, so driving it from unit
## swings would move hero-observed values.
var _attack_count: Array[int] = []

## AC 13's IN-REACH FLAG — the fifth granted field, added by the gate's amendment to `4-3b/R14`.
## SET by any contact fact this unit sources against its ACQUIRED TARGET, of either kind (probe or
## strike); CONSUMED when a windup starts; cleared by nothing else. There is NO negative probe:
## absence of overlap is not a fact and cannot clear this (AC 13's consequence (ii)).
##
## STORED because the probe and the windup happen on DIFFERENT TICKS — this flag is precisely the
## cross-tick carrier between them — and because it is what lets the next swing begin the instant
## recovery ends instead of waiting up to a full throttle interval for the next probe. Without it the
## observed attack rate would be windup+active+recovery PLUS a jittering remainder, and AC 1's
## authored durations would stop describing the rate a player actually sees.
##
## ------------------------------------------------------------------------------------------
## STORY 4-4 (`4-4/R14`): A CONFIRMATION NOW HAS A SHELF LIFE, so this is a COUNTDOWN OF FRESH
## TICKS rather than a bare bool. `is_in_reach_at` still answers the yes/no question every caller
## asks (`> 0`); the number itself is read only here and by `in_reach_snapshot`.
## ------------------------------------------------------------------------------------------
## THE DEFECT IT CLOSES, measured at this story's review: set-only was safe while the windup
## condition was `IDLE and is_in_reach_at`, because a flag a probe set was consumed on the very next
## IDLE tick. `4-4` added the CADENCE as a third AND, and that turned a flag consumed within a tick
## into a flag BANKED FOR A WHOLE COOLDOWN. A hero inside the Combat totem's 8 m range at tick N sets
## it; the totem is 120 ticks into its 2.0 s cadence so nothing consumes it; the hero walks away at
## 5.0 m/s; no probe clears it (by ruling); and at N+120 the totem winds up and fires a homing shot
## at a target ~18 m away — more than twice its authored range. AC 13 says a target beyond range is
## fired upon NEVER, and one shot per departure is not never.
##
## THE FIX IS NOT A NEGATIVE PROBE, and `4-3b` AC 13(ii) stands untouched: nothing observes an
## ABSENCE of overlap and nothing clears this from outside. What changed is that a POSITIVE
## confirmation stops being CURRENT once it is old enough that the runner would have re-confirmed it
## by now if the target were still in range. `4-4/R14` DERIVES that window rather than authoring it:
## one probe cadence (`minion_retarget_interval_ticks`) PLUS the F1 one-tick fact lag. The seeding
## caller reads it inline off `BalanceTicks` (CONSTRAINT C) — see `MatchState._mark_reach_from_fact`.
##
## THE SHIPPED MINION IS UNMOVED, and that is the property that makes this a defect fix rather than a
## rhythm change: a probe re-seeds the window every `minion_retarget_interval_ticks` ticks and the
## window is one tick LONGER than that, so a continuously-in-range target never lets the countdown
## reach zero. Only a unit whose confirmation has genuinely gone unrenewed loses it.
##
## IT IS HASHED IN FULL, as the COUNT and not as its boolean projection, by `4-3a/R17` directly: a
## value that CROSSES TICKS and DECIDES AN OUTCOME (whether the next windup may begin) cannot sit
## outside the hash, and how much freshness is LEFT decides exactly that. Snapshotting only the
## predicate would have kept `4-4`'s golden unmoved at the price of two states that differ hashing
## the same, and the operator refused that trade by name: the golden is re-baselined instead,
## `d94337cd` -> `a96b123e`, one cause, key set unchanged at 27 and only this key's rendering moved
## (`false` -> `0`). `UNHASHED_CROSS_TICK_MEMBERS` therefore STAYS AT THREE — see
## `test_replay_identity.gd`, where this member is classified HASHED beside its nine siblings.
var _in_reach_ticks: Array[int] = []

## ------------------------------------------------------------------------------------------
## STORY 4-4 (AC 1/AC 2): THE KIND INDEX — the field the ratified TOTEM CLAUSE reserved for THIS
## story, and the header clause directly above that says the record is "STILL ... TYPE/KIND-LESS" is
## hereby DISCHARGED rather than quietly relaxed.
## ------------------------------------------------------------------------------------------
## The clause's own stated purpose was that "uniform `summon_*` treatment does not pre-commit
## `4-4`'s differentiation" — i.e. it withheld the shape until the story that had to choose it. This
## is that story: three totem kinds must resolve to distinct on-board kinds at cast time (AC 1) and
## then differ in speed, hp, priority and attack capability. A record with no kind cannot.
##
## A PLAIN INT INDEX INTO `BalanceConfig.unit_kinds`, NEVER THE `StringName` KIND NAME, and that is
## the same rule the header states for every other field here: no StringName goes anywhere near this
## container, because `Array[StringName].sort()` orders by INTERNAL POINTER on this engine
## (player_state.gd:77, 206-207) — deterministic within one process, NOT across runs or builds. The
## index hashes cleanly, and it is STABLE because the authored list's ORDER is authored.
##
## IT IS THE ONLY DIFFERENTIATING FIELD ADDED, and deliberately so. The eleven converted globals do
## NOT get eleven parallel arrays: every one of them is read THROUGH this index, inline at the point
## of use (CONSTRAINT C), off the live `MatchState.balance`. Copying them per record would be N
## copies of one authored number and each copy would go stale on the next X3 reload — which is the
## exact failure CONSTRAINT C exists to prevent.
##
## `BalanceConfig.NO_KIND_INDEX` NEVER REACHES THIS ARRAY: the cast seat refuses to add a record for
## an unresolved kind (see `MatchState._resolve_basic_cast`), so a record on the board always names
## an index that was valid when it was written. `kind_at()` may still return null for it after an X3
## reload shortened the authored list, and every reading seat treats a null kind as "this unit does
## nothing" rather than crashing the tick.
var _kind_index: Array[int] = []

## STORY 4-4 (AC 10): the FIRING-CADENCE COOLDOWN, in ticks — the ninth parallel array, and the one
## field AC 10's "its own firing cadence as a number on that record" needs on the record side.
##
## SEEDED AT WINDUP START (inside `begin_windup_at`, from the kind's authored `cadence_ticks`) and
## counted down one per `advance()` beside every other D4 timer. A new windup may begin only when it
## has reached zero — so the cadence is measured from WINDUP START, not from the swing's end, which
## is what makes an authored cadence SHORTER than windup+active+recovery degrade to back-to-back
## rather than to overlapping swings.
##
## IT IS A SEPARATE COUNTDOWN FROM `_attack_ticks` AND MUST NOT BE FOLDED INTO IT. `_attack_ticks`
## counts the CURRENT PHASE and is zeroed on entering IDLE; the cadence must keep counting THROUGH
## idle, because its whole job is to hold a totem idle between shots. Two facts, two fields — the
## header's own "two fields expressing one fact" warning cuts the other way here.
##
## THE SHIPPED MINION AUTHORS 0.0 CADENCE, so its cooldown is already expired the moment recovery
## ends and its rhythm is bit-for-bit what 4-3b shipped. This array's ARRIVAL still moves the golden
## (a new all-zero snapshot key), which is a named shape cause in the Dev Agent Record.
var _attack_cooldown: Array[int] = []


## The ONE way a unit enters the board. Called from MatchState's step-6 cast dispatch, once per
## resolved `summon_*` cast. It enters holding the honest NO-TARGET pair rather than a placeholder
## that could be mistaken for an acquired target of slot 0 — everything else a record carries is
## acquired later, by the step-7 tick, and a freshly summoned unit has acquired nothing yet.
##
## STORY 4-3a (AC 1): it now TAKES ONE ARGUMENT, the authored maximum HP, and that is the whole
## reason the argument exists rather than a `BalanceConfig` reference on this class: reading balance
## HERE would make a pure container depend on config and would cache nothing legitimately
## (CONSTRAINT C). The caller reads `balance.unit_max_hp` INLINE at the cast seat and hands the
## value down. A unit enters at that maximum, on the `HeroState._init(... max_hp ...)` precedent.
##
## STORY 4-3a (AC 7, `4-3a/R9`): STILL AN UNCONDITIONAL APPEND, AND THAT IS A RULING, NOT AN
## OVERSIGHT. A summon following a death lands at a NEW index — it NEVER fills a dead unit's hole.
## Reuse would silently re-point a stale throttled `unit_targets` reference at a DIFFERENT live
## unit, which is the exact aliasing the hole discipline exists to prevent, and a future pooling
## story (`4-5`) is precisely the change that would introduce a free list "for free". If this
## function ever grows a "find a free slot" branch, that ruling is being reversed and needs its own.
##
## STORY 4-4 (AC 1/AC 2): it TAKES A SECOND ARGUMENT, the record's KIND INDEX, and that argument
## exists for the identical reason `max_hp` does — reading `BalanceConfig` here would make a pure
## container depend on config. The caller resolves the cast id to a kind index and hands the plain
## int down. AC 2's "no second hp/damage/death mechanism is authored" is satisfied by this signature
## and nothing else: a totem enters through THIS function, at ITS kind's authored maximum, and dies
## through `apply_damage_at`'s clamp exactly as a minion does.
func add(max_hp: float, kind_index: int) -> void:
	var pair := TargetingService.no_target()
	_target_slots.append(pair[0])
	_target_indices.append(pair[1])
	_hp.append(max_hp)
	# Story 4-3b (AC 16): a unit enters IDLE, with nothing counting down, no locked direction, no
	# swing behind it and NOT in reach. The honest empty value for all five, on the same reasoning
	# `add()` already applies to the no-target pair: a freshly summoned unit has acquired nothing,
	# observed nothing and swung at nothing. In particular it must NOT enter in-reach — a unit that
	# began winding up before any probe ever reported reach is exactly the free-running cycle AC 13
	# forbids.
	_attack_phase.append(AttackPhase.IDLE)
	_attack_ticks.append(0)
	_attack_dir.append(Vector2.ZERO)
	_attack_count.append(0)
	_in_reach_ticks.append(0)
	# Story 4-4: the kind is the one thing a fresh record is NOT empty about — it is decided at cast
	# time (AC 1: "each resolve to a distinct on-board kind AT CAST TIME") and never changes again.
	# The cooldown enters expired, on the same honest-empty-value reasoning every field above uses: a
	# freshly summoned totem has fired nothing, so nothing is holding it back from its first shot.
	_kind_index.append(kind_index)
	_attack_cooldown.append(0)


## Emptied by the DEBUG RESET ONLY, never by round end (`4-1/R5`): the board persists through
## the round-over freeze rather than blinking out at the instant of death, matching how every
## other piece of round-crossing state already behaves. MatchState._reset_player is the one
## caller; MatchState._end_round is deliberately untouched.
##
## Both arrays are cleared TOGETHER — they are one collection expressed as two, and an index that
## existed in one but not the other would be a record with half a target.
## Story 4-3a: `_hp` is cleared with its two siblings, for the header's own stated reason applied to
## a third array — they are ONE collection expressed as three, and an index that existed in one but
## not the others would be a record with half a target or no liveness at all.
func clear() -> void:
	_target_slots.clear()
	_target_indices.clear()
	_hp.clear()
	# Story 4-3b: the five attack-rhythm arrays are cleared with their siblings, for the header's own
	# reason applied to eight arrays instead of three — they are ONE collection expressed as eight,
	# and an index that existed in one but not the others would be a record with a phase but no
	# liveness, or a countdown belonging to a unit that no longer exists.
	_attack_phase.clear()
	_attack_ticks.clear()
	_attack_dir.clear()
	_attack_count.clear()
	_in_reach_ticks.clear()
	# Story 4-4: cleared with their nine siblings, for the header's own reason applied to ten arrays
	# instead of eight — one collection expressed as ten, and an index present in one but not the
	# others would be a record with a kind but no liveness.
	_kind_index.clear()
	_attack_cooldown.clear()


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


## Story 4-3a (AC 1): the record's hp. Same bound enforcement as `target_at` and for the same
## reason — every caller iterates `size()`, so an out-of-range index means the caller's own loop is
## wrong and returning a plausible 0.0 would read as "dead" and hide it.
func hp_at(index: int) -> float:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _hp[index]


## Story 4-3a (AC 7/AC 8): THE LIVENESS PREDICATE, derived from hp and stored nowhere — the
## `HeroState.is_alive()` shape verbatim (`_hp > 0.0`), for its reason verbatim.
##
## THE PUBLIC PREDICATE BOTH NAMED LIVENESS SEATS ARE WIRED TO (`4-3a/R14`): the targeting seat
## (through `living_indices()` below) and the runner's DRIVE-phase approach loop. Nothing may
## re-derive `hp > 0` inline at either seat, on the `has_index` precedent directly above — a guard
## consulting a copy is guarding the copy.
##
## AN OUT-OF-RANGE INDEX READS AS NOT ALIVE rather than tripping the bound, and that is the one
## deliberate divergence from `hp_at` above. CORRECTED (`4-3a/R23`, review finding): the runner's
## actor array is NOT actually a source of out-of-range reads at either named liveness seat — spawn
## resyncs the actor array's size against the board in the same tick, so the two never desync at
## `living_indices()` or the DRIVE-phase approach loop. The real caller this leniency exists for is
## `MatchState._resolve_unit_contact`'s dead-target rung: a contact FACT can name a stale or
## malformed target index (see `test_a_fact_naming_a_nonexistent_index_is_dropped_not_a_crash`), and
## for that caller "there is no such record" and "that record is dead" lead to the same correct
## action, DROP the fact — an Invariant.check would be printing at a caller that is behaving
## correctly against untrusted input.
func is_alive_at(index: int) -> bool:
	return has_index(index) and _hp[index] > 0.0


## Story 4-3a (AC 2): apply one confirmed hit's damage. The ONE mutator of hp, reached only from
## MatchState's step-4 contact resolution — the `set_target_at` discipline (one writer, inside the
## ordered dispatch) applied to the second piece of record content.
##
## CLAMPED AT ZERO, never negative, mirroring `HeroState._set_hp`. A corpse at exactly 0.0 makes
## `is_alive_at` false and keeps the snapshot value stable no matter how much overkill the last hit
## carried — two units killed by differently-sized hits hash the same, which is the honest reading
## (both are dead) and keeps the golden from moving on overkill arithmetic.
##
## NO SIGNAL. Units have no per-record signal channel and this story does not open one: `hit_landed`
## is deliberately NOT emitted for a unit target (`4-3a/R12` — its payload carries a slot only, and
## its shipped consumer would flash an untouched HERO whose hp did not change). The legible event
## this story ships is DEATH, and presentation observes it by POLLING `is_alive_at` (the runner's
## existing spawn/aim/approach poll shape), so the locked count of eight `connect_*` seams is
## untouched. (`seven` here until 4-3e AC 6(b): the family moved to EIGHT at `3-6/R2`, and
## `test_architecture_invariants.gd` has pinned it ever since, today as
## `test_runner_observation_seams_are_exactly_ten` (nine since 5-4 AC 15, ten since 6-3b AC 1). Stale
## citation, one word.)
func apply_damage_at(index: int, amount: float) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_hp[index] = maxf(0.0, _hp[index] - amount)


## Story 4-3a (AC 8, `4-3a/R15`): the LIVING board indices, ascending, freshly built each call.
##
## THIS IS THE CANDIDATE SET `TargetingService` NOW TAKES, in place of the bare
## `opposing_unit_count: int` it took through 4-2. A COUNT structurally cannot skip a hole: with a
## dead unit at index 0 the evaluator's `return [opposing_slot, 0]` would hand back the CORPSE, and
## its `REASON_NO_LIVING_CANDIDATE` branch tests a count that a hole keeps non-zero. An array of
## plain ints is still a PLAIN FACT, so the evaluator's stated contract ("plain facts, never a
## `PlayerState`") is preserved rather than weakened.
##
## ASCENDING BY CONSTRUCTION — it is built by walking the board in index order — which is the INDEX
## half of `4-2/R3`'s total order (slot ascending, then board index ascending) satisfied at the
## source rather than by a sort the evaluator would have to trust.
func living_indices() -> Array[int]:
	var out: Array[int] = []
	for i in _hp.size():
		if _hp[i] > 0.0:
			out.append(i)
	return out


## Story 4-3a (AC 9, `4-3a/R17`): the hp snapshot payload — one float per record, in board-index
## order. `hp` CROSSES TICKS AND DECIDES AN OUTCOME, so it does not sit outside the hash; that is
## the same argument the swing-dedupe record's own docstring makes for why mid-swing dedupe state is
## snapshotted, and the one `pending_draw` won on.
##
## THE ORDER IS MEANINGFUL and CanonicalHash preserves it, exactly as it does for `unit_targets`
## directly below: hp held by the wrong unit is a real divergence the hash should see. THIS IS ALSO
## HOW A HOLE REACHES THE HASH — a dead unit is a 0.0 at a stable index, so the snapshot carries the
## hole's position, not merely the fact that a hole exists.
##
## Freshly built each call, so no caller receives a handle into this container.
func hp_snapshot() -> Array:
	return _hp.duplicate()


## ------------------------------------------------------------------------------------------
## STORY 4-3b (AC 16): the attack-rhythm accessors.
## ------------------------------------------------------------------------------------------
## THEY MATCH THE SHAPE OF THE EXISTING PER-RECORD ACCESSORS and that is AC 16's own requirement:
## NON-ALLOCATING SINGLE-VALUE reads (`target_slot_at` / `target_index_at` / `hp_at`), never a
## pair-allocating getter — the runner reads several of these every physics frame for every spawned
## unit, which is exactly the hot path the project-context Performance Rule names.
##
## BOUND ENFORCEMENT FOLLOWS `hp_at`, NOT `is_alive_at`: an out-of-range index here is a programming
## error, because every caller iterates `size()` or has already passed `has_index`. `is_alive_at`'s
## deliberate leniency exists for ONE caller — the contact ladder's dead-target rung, which judges
## untrusted fact data — and none of these is that caller.

func attack_phase_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _attack_phase[index]


## The runner's hitbox-gather predicate, and the unit twin of `HeroState.is_hitbox_active()`
## (`active.is_running`) including its reason: the runner queries overlaps ONLY while state flags the
## swing active. DERIVED from the stored phase, never a second stored flag — two fields expressing
## one fact is how a swing ends up simultaneously active and not.
func is_hitbox_active_at(index: int) -> bool:
	return has_index(index) and _attack_phase[index] == AttackPhase.ACTIVE


func attack_ticks_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _attack_ticks[index]


func attack_dir_at(index: int) -> Vector2:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _attack_dir[index]


func attack_count_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _attack_count[index]


func is_in_reach_at(index: int) -> bool:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _in_reach_ticks[index] > 0


## Story 4-4 (AC 1): the record's KIND INDEX. Bound enforcement follows `hp_at`, not `is_alive_at`,
## on the reason stated above the attack-rhythm accessors: every caller iterates `size()` or has
## already passed `has_index`, so an out-of-range read here is the caller's own loop being wrong,
## and returning a plausible 0 would silently make that unit a MINION.
func kind_index_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _kind_index[index]


## Story 4-4 (AC 10): ticks remaining before this unit's next attack may begin. Same bound
## enforcement and same reason as `kind_index_at` directly above.
func attack_cooldown_at(index: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	return _attack_cooldown[index]


## THE PUBLIC PREDICATE THE WINDUP GATE IS WIRED TO (the `has_index` / `is_alive_at` discipline: a
## guard that consults a copy is guarding the copy). `MatchState._advance_unit_attacks` must not
## re-derive `attack_cooldown_at(i) == 0` inline — this is the one expression of "may this unit
## begin its next attack yet", and a second copy is a second thing to keep in agreement.
func is_attack_ready_at(index: int) -> bool:
	return has_index(index) and _attack_cooldown[index] == 0


## SET-ONLY, never cleared here, and the asymmetry is AC 13's consequence (ii) made structural:
## absence of overlap is NOT a fact, so there is no negative probe and nothing outside a windup start
## may clear this. A `set_in_reach_at(i, false)` would be exactly the clearing path the AC forbids —
## the flag is cleared by `begin_windup_at` CONSUMING it, and by its own AGE running out.
##
## STORY 4-4 (`4-4/R14`): `fresh_ticks` is how long this confirmation stays CURRENT, DERIVED by the
## caller off the probe cadence (see `_in_reach_ticks`). It is a RE-SEED, not an increment: a second
## confirmation inside the window restarts the shelf life rather than extending it, so the flag
## always means "confirmed within the last `fresh_ticks` ticks" and never "confirmed a lot".
##
## `fresh_ticks` IS NOT RE-CHECKED HERE, and that is this file's own discipline rather than an
## omission: every `Invariant.check` in this class is a BOUND guard wired to `has_index()` (pinned by
## `test_targeting_service.gd::test_every_board_bound_guard_is_wired_to_that_predicate`), and a
## container holds no policy about the values it is handed. The window's positivity is guaranteed
## where it is DERIVED — `MatchState._reach_freshness_ticks()` adds 1 to `BalanceTicks`'s own
## `minion_retarget_interval_ticks`, which carries the `maxi(1, ...)` clamp (`balance_ticks.gd`,
## the single conversion boundary), or falls back to its own strictest 1 with no `BalanceTicks` at
## all — so it cannot be zero without one of those two changing.
func mark_in_reach_at(index: int, fresh_ticks: int) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_in_reach_ticks[index] = fresh_ticks


## The LATEST KNOWN direction to the acquired target, refreshed while the unit is IDLE (AC 12). The
## IDLE test lives at the call site rather than in here, because this class is a container and the
## phase it would have to consult is policy: `MatchState` decides when a direction may still move,
## the same way it decides when a target may be written (`set_target_at`'s one-writer discipline).
func set_attack_dir_at(index: int, dir: Vector2) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_attack_dir[index] = dir


## Begin a swing: CONSUME the in-reach flag, enter WINDUP for `windup_ticks`, and advance this unit's
## own monotonic swing counter. Returns the new counter value, which is the `attack_index` the
## swing's contact facts will be stamped with and the key its `UnitSwingDedupe` record is opened
## under — returned rather than re-read so the caller cannot key a record off a different number
## than the one the counter now holds.
##
## THE FLAG IS CONSUMED HERE AND NOWHERE ELSE (AC 13). That is the ONLY clearing path.
##
## STORY 4-4 (AC 10): it also SEEDS THE FIRING-CADENCE COOLDOWN, from the authored `cadence_ticks`
## the caller reads inline off this unit's kind. Seeding HERE — at windup start, in the same call
## that consumes the reach flag and advances the counter — is what makes the cadence measured from
## windup start rather than from the swing's end (see `_attack_cooldown`'s own comment). The shipped
## minion authors a zero cadence and is therefore unaffected.
func begin_windup_at(index: int, windup_ticks: int, cadence_ticks: int) -> int:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_in_reach_ticks[index] = 0
	_attack_phase[index] = AttackPhase.WINDUP
	_attack_ticks[index] = windup_ticks
	_attack_count[index] += 1
	_attack_cooldown[index] = cadence_ticks
	return _attack_count[index]


## Enter `phase` for `ticks` ticks. The phase-progression mutator `MatchState`'s step-3 unit seat
## drives; entering IDLE zeroes the countdown, because a countdown that outlived its phase would be
## a second source of truth for "is this unit swinging".
func set_phase_at(index: int, phase: AttackPhase, ticks: int) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	_attack_phase[index] = phase
	_attack_ticks[index] = 0 if phase == AttackPhase.IDLE else ticks


## Count down every non-IDLE record by one tick, called from `advance()` step 2 beside every other
## D4 timer — the `HeroState.tick_timers()` seat and shape, for a container instead of an object.
## Clamped at zero: the step-3 seat reads "countdown reached zero" as the phase boundary, so a
## countdown running negative would make the boundary a moment rather than a state.
##
## A DEAD UNIT'S RECORD IS TICKED LIKE ANY OTHER and that is deliberate — a corpse's countdown is
## inert either way (nothing gathers a dead unit's hitbox, and `_advance_unit_attacks` skips it), and
## a liveness test here would put a second liveness seat in a container that has no business holding
## policy.
func tick_attack_timers() -> void:
	# Story 4-4 (AC 10): the CADENCE COOLDOWN counts down here too, and UNCONDITIONALLY — not under
	# the IDLE `continue` below. That is the whole difference between the two countdowns: the phase
	# countdown is meaningless while IDLE, whereas the cadence exists PRECISELY to run while the unit
	# is idle and waiting for its next shot. Clamped at zero for its sibling's reason — the windup
	# gate reads "reached zero" as a state, not as a moment.
	for i in _attack_cooldown.size():
		if _attack_cooldown[i] > 0:
			_attack_cooldown[i] -= 1
	# Story 4-4 (`4-4/R14`): the REACH CONFIRMATION ages here too, and unconditionally for the
	# cadence cooldown's reason directly above — a confirmation goes stale while the unit sits IDLE
	# waiting for its cooldown, which is exactly the state the `IDLE: continue` below skips. Clamped
	# at zero so "stale" is a state and not a moment.
	for i in _in_reach_ticks.size():
		if _in_reach_ticks[i] > 0:
			_in_reach_ticks[i] -= 1
	for i in _attack_phase.size():
		if _attack_phase[i] == AttackPhase.IDLE:
			continue
		if _attack_ticks[i] > 0:
			_attack_ticks[i] -= 1


## AC 16's snapshot payloads — FIVE separate keys, one per array, on the `unit_hp` precedent
## (one array -> one key) rather than the `unit_targets` one (two arrays -> one fused key of pairs).
## MEASURED CHOICE, not a default: `unit_targets` fuses because a target IS one logical fact
## expressed as two ints, and splitting it would let a slot and an index drift into different keys.
## These five are five INDEPENDENT facts about a unit — a phase, a countdown, a direction, a counter
## and a flag — and fusing any of them would hide which one moved when the golden moves.
##
## Each is freshly built, so no caller receives a handle into this container, and the ORDER IS
## MEANINGFUL exactly as it is for `unit_hp`: a phase held by the wrong unit is a real divergence.
func attack_phase_snapshot() -> Array:
	return _attack_phase.duplicate()


func attack_ticks_snapshot() -> Array:
	return _attack_ticks.duplicate()


func attack_dir_snapshot() -> Array:
	return _attack_dir.duplicate()


func attack_count_snapshot() -> Array:
	return _attack_count.duplicate()


## Story 4-4 (`4-4/R14`): THE COUNT, not its boolean projection — the key `unit_in_reach` now renders
## an int per unit rather than a bool. That is what keeps `_in_reach_ticks` HASHED state under
## `4-3a/R17` with no exclusion to argue about, and it is the ONE cause of this story's third golden
## re-baseline (`d94337cd` -> `a96b123e`); the key SET did not move.
func in_reach_snapshot() -> Array:
	return _in_reach_ticks.duplicate()


## Story 4-4 (AC 1/AC 10/AC 12): the two new snapshot payloads, on the `unit_hp` side of this
## file's own precedent (one array -> one key), because a kind and a cooldown are two INDEPENDENT
## facts about a unit and fusing them would hide which one moved when the golden moves.
##
## BOTH CROSS TICKS AND DECIDE AN OUTCOME, which is `4-3a/R17`'s test for whether a value may sit
## outside the hash. The kind decides every authored number the unit is governed by, for its whole
## life, and cannot be recomputed from anything else on the record — the cast that chose it is long
## gone. The cooldown decides when the next shot may begin and is exactly the cross-tick carrier
## between one shot and the next.
##
## PLAIN INTS, so no StringName and no object reaches the hash — see `_kind_index`'s own comment for
## why the NAME is deliberately not what is stored. The ORDER IS MEANINGFUL and CanonicalHash
## preserves it: a kind held by the wrong unit is a real divergence.
func kind_index_snapshot() -> Array:
	return _kind_index.duplicate()


func attack_cooldown_snapshot() -> Array:
	return _attack_cooldown.duplicate()


## AC 11's snapshot payload: one `[slot, index]` pair per record, in board-index order. The ORDER IS
## MEANINGFUL and CanonicalHash preserves it (the `pending_draw_owed` precedent) — a target held by
## the wrong unit is a real divergence the hash should see. Freshly built each call, so no caller
## receives a handle into this container.
func targets_snapshot() -> Array:
	var out: Array = []
	for i in _target_slots.size():
		out.append([_target_slots[i], _target_indices[i]])
	return out
