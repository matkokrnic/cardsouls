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

## ------------------------------------------------------------------------------------------
## STORY 6-5b (AC 1-5, `6-5b/R17`): THE CORPSE, as THREE more parallel arrays on the DEAD UNIT'S OWN
## BOARD INDEX. Ruling `6-5b/R17` closed the story's Open Question 1 on exactly this shape: "corpse
## data lives on `UnitBoard`, at the dead unit's own board index (no separate container); a consumed
## or expired corpse is marked there."
## ------------------------------------------------------------------------------------------
## A SEPARATE CONTAINER WAS THE REJECTED OPTION, and the reason is this file's own hole discipline. A
## corpse IS a dead record -- `hp <= 0` at a stable index that is never removed and never reused
## (`4-1/R9`) -- so a sibling container keyed by board index would be a second structure holding one
## fact, and the first thing it would need is a rule for what happens when the two disagree about
## whether index 3 is a corpse. Here they cannot disagree: `has_corpse_at` reads BOTH halves.
##
## STILL PLAIN SCALARS, STILL INDEX-ALIGNED, so the header's "no nested typed array, no Dictionary, no
## StringName" reasoning covers all three unchanged.
##
## AND STILL POSITIONLESS (`6-5b/R1`, F1). A corpse in state knows WHOSE board it is on (by which
## `UnitBoard` holds it), WHICH now-dead index it is tied to (its own position in these arrays) and
## HOW LONG IT HAS LEFT. Where it lies is read off the ACTOR by the runner, exactly as every other
## position in this project is -- Raise Dead's placement included (AC 14).

## Ticks of corpse left at each index. ZERO MEANS NO CORPSE, on the `_attack_cooldown` precedent that
## a countdown at rest is simply zero -- and it is why there is no `_is_corpse: Array[bool]` beside
## it: two fields expressing one fact is exactly how a corpse ends up simultaneously present and
## gone, which is this file's own standing warning (see `_hp`).
##
## SEEDED ONLY AT THE DEATH SEAT (`kill_at`) and counted down one per `advance()` by `tick_corpses()`
## (A1 -- integer ticks, never a float accumulator, never an `Engine`/`OS`/`Time` read). It reaches
## zero exactly once and stays there: the record is never revived, because a raise APPENDS a new
## record rather than reusing the hole.
var _corpse_ticks: Array[int] = []

## AC 24: whether GRAVE WARD has ever extended the corpse at this index -- the per-corpse "was
## extended" mark, which `6-5b/R7` requires to last until that corpse is REMOVED (expired or raised)
## rather than for a window of its own.
##
## IT CANNOT BE DERIVED, and that is measured rather than assumed. "Remaining exceeds the authored
## default" is true only immediately after the extension and false a second later, so the mark would
## flicker off while the corpse it marks is still standing there tinted.
##
## A SEPARATE FIELD FROM `_corpse_ticks` BECAUSE IT IS A SEPARATE FACT -- how long is left, and
## whether a card touched it. `unit_targets`' FUSION precedent does not apply: a target is one fact in
## two ints that must never drift apart, whereas these two move independently every tick.
var _corpse_extended: Array[bool] = []

## AC 14: the board index of the CORPSE this record was raised from, or `NO_RAISE_SOURCE` for every
## record that entered by an ordinary summon.
##
## IT EXISTS FOR ONE CONSUMER AND ONE FRAME. Raise Dead places the new minion at the corpse's own
## location, which is ACTOR-owned (`6-5b/R1`) -- so the state layer cannot place it and must instead
## say WHICH corpse's actor the runner should read. The runner's spawn poll reads this on the tick the
## record appears, before `_free_dead_unit_actors` frees that corpse (AC 25), which is the ordering
## AC 14's last clause pins.
##
## PERMANENT ON THE RECORD rather than cleared after the read, on this file's own append-only
## posture: "this record was raised from the corpse at index N" stays true for the record's whole
## life, and a field cleared one frame later would be a second thing to get the timing of right.
var _raised_from: Array[int] = []

## The resting value of `_raised_from` -- a record nobody raised. `-1`, which is not a valid board
## index by `has_index`, so it collides with no real source.
const NO_RAISE_SOURCE := -1

## ------------------------------------------------------------------------------------------
## STORY 6-5f (AC 23, `6-5f/R32`): THE FOURTH CORPSE ARRAY -- the hp this record held IMMEDIATELY BEFORE
## its death. The operator ruled it "a NEW hashed field, its own golden cause", and this is where
## `6-5b/R17` already put corpse data: on `UnitBoard`, at the dead unit's own board index.
## ------------------------------------------------------------------------------------------
## IT CANNOT BE DERIVED, and the reason is `kill_at`'s own arithmetic: the death seat writes `_hp[index] =
## 0.0`, so the value it overwrote exists nowhere afterwards. `4-3a`'s clamp comment says so from the other
## side ("two units killed by differently-sized hits hash the same"), which is exactly the information this
## array preserves and the snapshot deliberately used to drop.
##
## WHY IT IS NEEDED AT ALL: a Counterspell reversal puts a killed minion back "at the hp it had immediately
## before death" (`6-5f/R29`), which is DELIBERATELY NOT Raise Dead's number. `_apply_raise_dead` enters a
## minion at `kind.max_hp * raise_hp_percent / 100.0` because it revives a corpse from scratch; a reversal
## undoes a kill it just watched happen and must put back exactly what was there. Two different numbers, so
## the narrower one needs its own fact.
##
## WRITTEN AT THE DEATH SEAT, FOR EVERY DEATH, WHATEVER THE CAUSE -- not only for the two 6-5f reverses
## today. A contact kill, a Culling, a Drain and a Corpse Bomb all pass through `kill_at`, and a per-cause
## write would be four places that could disagree about what "immediately before" means. It is also what
## lets `6-5g`'s Corpse Bomb reversal reuse the general restore rule (AC 23) with no new field.
##
## ZERO FOR A LIVING RECORD, on `_corpse_ticks`' own precedent that a resting value is simply zero -- and
## it is why there is no `_died: Array[bool]` beside it: liveness is already `_hp > 0.0` and a second
## expression of "this record has died" is this file's standing warning (see `_hp`).
##
## IT OUTLIVES THE CORPSE, deliberately, unlike `_corpse_ticks`. `consume_corpse_at` and expiry both
## remove the corpse and neither clears this, on `_raised_from`'s own append-only posture: "this record
## died holding 4 hp" stays true for the record's whole life, and a field cleared when the corpse went
## would be a second thing to get the timing of right. Nothing reads it for a record with no corpse --
## the restore rule requires the corpse (AC 23's "a corpse already gone means the minion is NOT restored").
var _hp_at_death: Array[float] = []


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
##
## STORY 6-5b (AC 14): it takes a THIRD, DEFAULTED argument -- the board index of the corpse this
## record was RAISED from, or `NO_RAISE_SOURCE` for every ordinary summon. Defaulted rather than
## required so the summon seat and every existing fixture are untouched, and so the only caller that
## passes it is the one that actually raised something.
func add(max_hp: float, kind_index: int, raised_from: int = NO_RAISE_SOURCE) -> void:
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
	# Story 6-5b (AC 1): a LIVING record is not a corpse and carries no corpse countdown -- the honest
	# empty value every field above enters at, applied to the two corpse fields. A minion raised from a
	# corpse is no exception: it enters ALIVE with its own empty corpse state, which is what makes AC 17
	# (a raised minion that dies again leaves a fresh corpse) fall out of the death seat rather than
	# needing a path of its own.
	_corpse_ticks.append(0)
	_corpse_extended.append(false)
	_raised_from.append(raised_from)
	# Story 6-5f (AC 23): a living record has not died, so it holds the resting zero -- the honest empty
	# value every field above enters at, applied to the fourth corpse field. A minion RESTORED by a
	# Counterspell reversal is no exception: it enters ALIVE through this same function at its recorded
	# pre-death hp, with its OWN empty death record, so a second death writes a fresh one.
	_hp_at_death.append(0.0)


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
	# Story 6-5b (AC 5): the three CORPSE arrays are cleared with their ten siblings, for the header's
	# own reason applied to thirteen arrays -- one collection expressed as thirteen, and an index
	# present in one but not the others would be a corpse belonging to a record that no longer exists.
	#
	# THIS LINE IS THE WHOLE OF AC 5. `MatchState._reset_player` (the DEBUG RESET) is this function's
	# one caller and `MatchState._end_round` is deliberately untouched, so corpses clear at exactly the
	# point units already clear today and persist through the round-over freeze -- `4-1/R5`'s standing
	# rule, inherited rather than restated as a second rule about corpses.
	_corpse_ticks.clear()
	_corpse_extended.clear()
	_raised_from.clear()
	# Story 6-5f (AC 23): cleared with its thirteen siblings, for the header's own reason applied to
	# fourteen arrays -- one collection expressed as fourteen, and an index present in one but not the
	# others would be a death record belonging to a record that no longer exists.
	_hp_at_death.clear()


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
## STORY 6-5b (AC 3, `6-5b/R13`): IT TAKES THE CORPSE LIFETIME AND ROUTES A LETHAL HIT THROUGH THE
## DEATH SEAT below. The clamp is no longer written here, and that is the point of AC 3's "beside
## `apply_damage_at`, so the hp clamp and the corpse write cannot diverge": there is now exactly ONE
## expression of "this unit's hp reaches zero", and it is the one that also writes the corpse.
##
## `corpse_ticks` IS READ INLINE BY THE CALLER (CONSTRAINT C) and handed down, exactly as `max_hp` and
## `kind_index` are at `add()`: reading balance here would make a pure container depend on config. It
## is also where the TOTEM EXCLUSION lands (AC 1 / `6-5b/R10`) -- the caller resolves the record's
## kind and hands down ZERO for anything that leaves no corpse, so this container holds no policy
## about which kinds get one.
##
## A NON-LETHAL HIT IS UNCHANGED, bit for bit: the subtraction below is the same arithmetic 4-3a
## shipped, and nothing about a surviving unit's hp moves.
func apply_damage_at(index: int, amount: float, corpse_ticks: int) -> void:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	if _hp[index] - amount <= 0.0:
		kill_at(index, corpse_ticks)
		return
	_hp[index] = _hp[index] - amount


## ------------------------------------------------------------------------------------------
## STORY 6-5b (AC 3, `6-5b/R13`): THE DEATH SEAT. It is CREATED here, and the ruling says so in as
## many words -- none existed: "the hp clamp inside `apply_damage_at` IS the death
## (`match_state.gd:2350-2352`); death today is a derived predicate, `is_alive_at`, not an event."
## ------------------------------------------------------------------------------------------
## EXACTLY THREE CALLERS (AC 3), and no cause-specific corpse-creation code exists anywhere else:
##   1. `apply_damage_at` directly above, on behalf of the STEP-4 CONTACT PATH -- the only route by
##      which damage can be lethal. The contact path reaches death THROUGH the damage it applies, so
##      its caller is the damage seat rather than a second call beside it; a `if now dead then kill`
##      at the contact seat would be exactly the divergence AC 3 forbids, because the clamp would
##      already have happened and the corpse write would be a separate decision.
##   2. `MatchState`'s CULLING apply seat.
##   3. `MatchState`'s DRAIN apply seat.
## Both of the latter KILL WITHOUT DAMAGING (`6-5b/R4`): they reach this function directly and never
## pass through `apply_damage_at`, so `_funnel_damage`'s Bloodlust multipliers and
## `_apply_lifesteal`'s Vampiric Aura heal are structurally unreachable from them (AC 7) -- not
## skipped by a flag, but by not being on the path at all.
##
## IDEMPOTENT FOR AN ALREADY-DEAD UNIT (AC 3), and it reports which it was. A second hit on a corpse
## finds `hp <= 0`, returns `false` and writes NOTHING -- so it cannot restart a countdown a Grave
## Ward has already extended, cannot clear the extended mark, and cannot create a second corpse. That
## is the property that lets `apply_damage_at` call it unconditionally on any lethal-looking amount.
##
## RETURNS WHETHER THIS CALL IS THE DEATH, so a caller that has to pay for exactly the kills it made
## (Culling's mana per minion killed, AC 8) counts the seat's own answer rather than re-deriving
## liveness after the fact.
func kill_at(index: int, corpse_ticks: int) -> bool:
	Invariant.check(has_index(index),
		"unit board index %d is out of range (board holds %d units)" % [index, size()])
	if _hp[index] <= 0.0:
		return false
	# Story 6-5f (AC 23, `6-5f/R32`): the pre-death hp is captured HERE, in the same statement pair as the
	# hp write and the corpse write, and BEFORE the zero -- the only tick on which the value still exists.
	# Its placement inside this function rather than at the three callers is what AC 23's "a NEW hashed
	# fact" means structurally: one death seat, one capture, so no cause can record a different notion of
	# "immediately before". The idempotent early return above it is what keeps a second hit on a corpse
	# from overwriting the real number with a zero.
	_hp_at_death[index] = _hp[index]
	_hp[index] = 0.0
	# AC 1: the corpse is created HERE, in the same statement pair as the hp write, for EVERY minion
	# death regardless of cause. A zero lifetime (a totem, or an authored 0.0) writes a corpse that is
	# already expired, which `has_corpse_at` reads as no corpse at all -- the one expression of "this
	# kind leaves no corpse", decided by the caller and rendered here as a value rather than a branch.
	_corpse_ticks[index] = maxi(0, corpse_ticks)
	_corpse_extended[index] = false
	return true


## AC 1/AC 4: is there a corpse at `index` right now? BOTH HALVES ARE READ -- the record is dead AND
## its countdown has not run out -- which is what makes a corpse impossible to disagree with itself
## about (see `_corpse_ticks`). An out-of-range index reads FALSE rather than tripping the bound, on
## `is_alive_at`'s precedent and for its caller's reason: every consumer (the runner's corpse poll,
## Grave Ward, Raise Dead) treats "no such record" and "no corpse there" as the same correct answer.
func has_corpse_at(index: int) -> bool:
	return has_index(index) and _hp[index] <= 0.0 and _corpse_ticks[index] > 0


## AC 2: the remaining lifetime the ACTOR reads (through the runner) to drive its own visual and
## collision lifecycle. Zero for a living record and for an expired or consumed corpse alike.
## `has_corpse_at`'s leniency, for its reason.
func corpse_ticks_at(index: int) -> int:
	return _corpse_ticks[index] if has_index(index) else 0


## AC 24: has Grave Ward extended the corpse at `index`? The tint's one source of truth.
func is_corpse_extended_at(index: int) -> bool:
	return has_index(index) and _corpse_extended[index]


## AC 14: which corpse this record was raised from, or `NO_RAISE_SOURCE`. Bound enforcement follows
## `corpse_ticks_at`, not `kind_index_at`: the runner's spawn poll reads it for an index it has just
## appended and an out-of-range answer is "nobody raised this", which is correct for a record that
## does not exist.
func raised_from_at(index: int) -> int:
	return _raised_from[index] if has_index(index) else NO_RAISE_SOURCE


## AC 11/AC 12 (`6-5b/R7`): GRAVE WARD -- ADD `ticks` to what this corpse has LEFT, and mark it
## extended. ADDITIVE AND NOT A REFRESH, which is the ruling's own distinction and the reason this is
## `+=` rather than `=`: two casts add two extensions' worth of remaining time, so the second cast's
## result is the value immediately before it plus exactly one extension (AC 12).
##
## A NON-CORPSE IS A NO-OP rather than a bound trip, and that is what keeps "a corpse created AFTER
## the cast is untouched" (AC 11) true by construction: the caller walks the corpses that exist at
## resolution, and anything that is not one absorbs nothing. The MARK is written only when the
## extension actually lands, so a living unit never carries it.
func extend_corpse_at(index: int, ticks: int) -> void:
	if not has_corpse_at(index):
		return
	_corpse_ticks[index] += maxi(0, ticks)
	_corpse_extended[index] = true


## Story 6-5f (AC 23, `6-5f/R29`/`R32`): the hp this record held immediately before it died, or `0.0` for a
## record that is still alive. `corpse_ticks_at`'s bound leniency and for its reason: the one consumer is
## the reversal restore, which has already established through `has_corpse_at` that there IS a corpse at
## this index, and "no such record" and "never died" lead to the same correct answer -- restore nothing.
func hp_at_death_at(index: int) -> float:
	return _hp_at_death[index] if has_index(index) else 0.0


## Story 6-5g (AC 22): PUT HP BACK on a LIVING record -- the seat a Counterspell reversal uses to refund what
## a countered spell took off a unit that SURVIVED it (a damaged totem, a wounded minion).
##
## A NAMED RESTORE RATHER THAN `apply_damage_at(index, -amount, _)`, which would work arithmetically and is
## the wrong shape: it would make a negative damage an idiom of the DAMAGE seat, whose docstring promises a
## clamp at zero and a corpse write, and its `corpse_ticks` argument would be meaningless on every call. This
## is `restore_corpse_at`'s own pairing, one level down: the undo of a change gets its own name.
##
## A DEAD RECORD IS REFUSED, not revived: a unit the spell KILLED comes back through the general restore rule
## (`MatchState._restore_killed_minions`, at its pre-death hp, consuming its own corpse), and a resurrection
## hidden inside an hp adder is exactly the divergence `4-1/R9` forbids.
##
## NO CEILING IS NEEDED AND NONE IS WRITTEN. The only caller refunds the hp its own recorded hit ACTUALLY
## removed, so the result cannot exceed what the record held before that hit -- and this container stores no
## maximum to clamp against (`add()` takes the kind's maximum as the starting hp and keeps no copy).
func restore_hp_at(index: int, amount: float) -> void:
	if not is_alive_at(index) or amount <= 0.0:
		return
	_hp[index] = _hp[index] + amount


## Story 6-5f (AC 19/AC 20): PUT A CORPSE BACK at `index` with an explicit remaining lifetime and extended
## mark -- the one seat a Counterspell reversal uses to undo a change to a corpse's COUNTDOWN.
##
## TWO REVERSALS, ONE SEAT, and that is why it takes the lifetime rather than a delta. Grave Ward's reversal
## subtracts the extension it added (AC 19) and Raise Dead's returns a consumed corpse with the remaining
## time it would have had by now (AC 20); both compute a target remaining and both need the mark restored
## to what it was before the cast. A `shrink_corpse_at(index, ticks)` would express the first and not the
## second, and `extend_corpse_at(index, -ticks)` cannot express either -- it clamps its argument at zero and
## sets the mark unconditionally, which is correct for the card it serves and wrong for undoing it.
##
## A NON-ZERO LIFETIME ON A LIVING RECORD IS REFUSED, not clamped: a corpse belongs to a dead record by
## definition (`has_corpse_at` reads both halves), and a living unit that also had a countdown would be the
## exact "simultaneously present and gone" state this file's header warns about. The guard is the liveness
## test rather than `has_corpse_at`, because Raise Dead's reversal restores a corpse that is currently GONE
## -- that is the whole point of it.
##
## A NON-POSITIVE LIFETIME CLEARS THE MARK WITH IT, unconditionally, which is `consume_corpse_at`'s own
## rule (`6-5b/R7` scopes the mark to "until that corpse is removed") reached from a different direction:
## reaching zero here IS a removal, so AC 19's "any corpse whose remaining time is then <= 0 disappears on
## this same tick" and AC 20's "EXCEPT one that would already have naturally expired" are both this clamp
## rather than a branch at either caller.
func restore_corpse_at(index: int, ticks: int, extended: bool) -> void:
	if not has_index(index) or _hp[index] > 0.0:
		return
	_corpse_ticks[index] = maxi(0, ticks)
	_corpse_extended[index] = extended and ticks > 0


## AC 14: RAISE DEAD -- the corpse at `index` is CONSUMED. The countdown goes to zero, which is the
## same "removed from state" an expiry reaches, so there is ONE way a corpse stops existing and
## `has_corpse_at` needs no second condition. The extended MARK is cleared with it: `6-5b/R7` scopes
## the mark to "until that corpse is removed", and this is a removal.
##
## THE RECORD ITSELF IS UNTOUCHED AND STAYS A HOLE. Raising does not revive this index -- the raised
## minion is a NEW record at a NEW index (`4-1/R9`, holes never reused) -- so the dead record remains
## exactly the dead record it was, minus its corpse.
func consume_corpse_at(index: int) -> void:
	if not has_corpse_at(index):
		return
	_corpse_ticks[index] = 0
	_corpse_extended[index] = false


## AC 11/AC 14/AC 16: the indices holding a corpse RIGHT NOW, ascending -- the candidate set Grave
## Ward extends and Raise Dead consumes, and the set whose EMPTINESS is the refusal both cards test
## (AC 13/AC 15).
##
## FRESHLY BUILT AND ASCENDING BY CONSTRUCTION, on `living_indices()`'s precedent exactly: it walks
## the board in index order, so Raise Dead's new records are appended in corpse order and Grave Ward's
## extension order cannot depend on anything but the board. No caller receives a handle.
##
## IT IS THE REASON AC 16 NEEDS NO CODE OF ITS OWN: this is one player's board, so "never the
## opponent's corpses" is a property of WHICH `UnitBoard` the caller asked, not of a filter it has to
## remember to apply.
func corpse_indices() -> Array[int]:
	var out: Array[int] = []
	for i in _corpse_ticks.size():
		if has_corpse_at(i):
			out.append(i)
	return out


## AC 4: count every corpse down by one tick, called from `advance()` step 2 beside
## `tick_attack_timers()` -- the same seat, the same A1 discipline (one integer tick per `advance()`,
## never a float accumulator), and the same round-over behaviour for free (step 1b returns before
## step 2, so a frozen tick ages no corpse).
##
## CLAMPED AT ZERO for `tick_attack_timers()`'s stated reason: "expired" is a STATE that
## `has_corpse_at` reads, not a moment a countdown passes through on its way negative. A corpse whose
## lifetime reaches zero is thereby removed from state -- it can no longer be extended
## (`extend_corpse_at` no-ops), raised (`corpse_indices()` omits it) or observed as existing.
func tick_corpses() -> void:
	for i in _corpse_ticks.size():
		if _corpse_ticks[i] > 0:
			_corpse_ticks[i] -= 1


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


## Story 6-5b (AC 1/AC 14): THREE new snapshot payloads, on the `unit_hp` side of this file's own
## precedent (one array -> one key) rather than the `unit_targets` fusion, because a countdown, a mark
## and a provenance index are three INDEPENDENT facts and fusing any of them would hide which one
## moved when the golden moves -- the same argument `attack_phase_snapshot`'s block makes for its five.
##
## ALL THREE CROSS TICKS AND DECIDE AN OUTCOME, which is `4-3a/R17`'s test for whether a value may sit
## outside the hash. The countdown decides whether a corpse can still be raised at all; the mark
## decides what the corpse renders as for the rest of its life and cannot be recomputed from anything
## else on the record; the raise source decides where the raised minion stands.
##
## PLAIN INTS AND BOOLS, so no StringName, no object and NO POSITION reaches the hash -- a raise
## source is a board INDEX, the counts-and-indices rule (`4-2/R2`) exactly, and the corpse's actual
## LOCATION stays actor-owned and never enters this file (`6-5b/R1`). The ORDER IS MEANINGFUL and
## CanonicalHash preserves it: a corpse belonging to the wrong record is a real divergence.
func corpse_ticks_snapshot() -> Array:
	return _corpse_ticks.duplicate()


func corpse_extended_snapshot() -> Array:
	return _corpse_extended.duplicate()


func raised_from_snapshot() -> Array:
	return _raised_from.duplicate()


## Story 6-5f (AC 23/AC 28, `6-5f/R32`): the FOURTH corpse payload, on this file's own `unit_hp` side of
## the precedent (one array -> one key), because "what this record died holding" is an INDEPENDENT fact from
## its countdown, its mark and its provenance -- fusing it would hide which one moved when the golden moves.
##
## IT CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`): it decides the hp a restored minion enters at, and
## it cannot be recomputed from anything else on the record -- `kill_at` overwrote the only other copy with
## zero, ticks ago. It is the operator's own named golden cause (`6-5f/R32`).
##
## PLAIN FLOATS, the `unit_hp` payload's own type and branch, so no StringName and no object reaches the
## hash. The ORDER IS MEANINGFUL and CanonicalHash preserves it: a death record belonging to the wrong unit
## is a real divergence.
func hp_at_death_snapshot() -> Array:
	return _hp_at_death.duplicate()


## AC 11's snapshot payload: one `[slot, index]` pair per record, in board-index order. The ORDER IS
## MEANINGFUL and CanonicalHash preserves it (the `pending_draw_owed` precedent) — a target held by
## the wrong unit is a real divergence the hash should see. Freshly built each call, so no caller
## receives a handle into this container.
func targets_snapshot() -> Array:
	var out: Array = []
	for i in _target_slots.size():
		out.append([_target_slots[i], _target_indices[i]])
	return out
