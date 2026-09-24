class_name MatchState
extends RefCounted

## D1/D2 root of the pure state layer. Owns the two PlayerStates, the reserved PitchState,
## the shared SignalQueue, and the single seeded gameplay RNG (F2). Pure RefCounted — no
## scene, no Input, no autoload, no wall-clock. The runner owns THIS object (no autoload
## for live state) and is the only thing that calls advance()/drain_signals().
##
## D2: advance(intents) is the ONE ordered call site that advances gameplay time. It only
## ENQUEUES signals; the runner drains them after it returns (D5).

## Owned by MatchState, relayed to the EventBus autoload by the runner (state never touches
## an autoload). loser_index: 0 = P1, 1 = P2. Re-arms when the debug reset clears the
## round latch (story 1-7, D-1): fires once per DEATH, not once per match.
signal round_ended(loser_index: int)

## Story 2-6 (AC 1, 2-6/R5/R6): the RESET counterpart to round_ended — a no-argument, ownerless
## round-lifecycle event (a debug reset is a whole-match event, not per-player, the round_ended
## analogy inverted). Pushed QUEUED and UNCONDITIONALLY by _apply_debug_reset() on EVERY debug
## reset (D5), relayed by the runner to EventBus.round_started exactly the way round_ended is.
## The single CLEAR trigger for the round-over label (HudRoot.on_round_started); round_ended
## stays the single SET. No prime-on-connect: a HUD consumer must receive an actual reset event.
signal round_started()

## Story 1-7 (N1): MatchState-owned two-player event (the round_ended analogy — a hit has
## an attacker AND a target, so it is not per-hero). Queued in step 4 when a contact is
## CONFIRMED, drained by the runner after advance() (D5). target_hp is the target's
## REMAINING HP after the damage. Consumers subscribe through the runner seam
## (match_runner.connect_hit_landed) and never hold a MatchState handle.
signal hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)

## Story 6-3b (AC 1): one player's Pitch Zone, as the pitch HUD renders it -- the OWNER slot, the staged
## card id (`PitchState.NO_CARD` when empty), its origin hand slot (`PitchState.NO_HAND_SLOT` when
## empty), READY read live at the emission instant (never latched), and the countdown as
## `remaining_ticks` of `duration_ticks` (both 0 when empty). Consumers subscribe through the runner's
## match-level seam (`match_runner.connect_pitch_changed`, the `hit_landed` shape) and never hold a
## MatchState handle; BOTH HudRoots receive BOTH zones and tell them apart by the owner slot.
##
## HOMED HERE, NOT ON `PitchState`: READY needs the zone, the owner's `OrbPool` and the injected
## `flags` together, and only MatchState holds all three. `PitchState` stays a signal-free container.
##
## NO ORB COST, NO SHORTFALL AND NO PER-COLOUR ORB NUMBER RIDES THE PAYLOAD (operator ruling
## 2026-09-15): a zone shows the card, the countdown and READY, so no number exists here that could
## reveal a player's exact orb count to the other (`6-3-split/R-INFO`, satisfied by construction).
##
## QUEUED from ONE helper (`_queue_pitch_changed`) at exactly six seats: stage, activate, expiry, debug
## reset, an orb grant inside a staged window, and the authored step-6 countdown throttle. Every
## emission READS the live zone and pool; nothing hashed is added (FORMAT_VERSION and the snapshot key
## set are untouched, AC 9).
signal pitch_changed(slot: int, card_id: StringName, hand_slot: int, ready: bool,
		remaining_ticks: int, duration_ticks: int)

## Story 1-8 (R-D4): MatchState-owned two-player event (the hit_landed precedent — a
## deflect has an attacker AND a target). Queued in step 4 when a contact resolves as a
## DEFLECT (fully negated: no damage, no hit_landed, no mana), drained by the runner
## after advance() (D5). NO runner connect seam in 1-8 — the FIRST consumer (1-10
## CombatCues) inherits the seam obligation, the action_rejected precedent.
##
## STORY 5-5 (AC 13) WIDENS THE PAYLOAD WITH A THIRD ARGUMENT, `defense_color`, and does NOT build a
## tenth observation channel. This signal is now shared by THREE conceptually distinct mechanisms
## under one name that literally says "deflect": melee block-timing parry, a unit's melee swing
## parried, and a card-cast colour-matched negation of an unblockable (`_resolve_charge_landing`,
## the SECOND emit site). A new, more precisely named signal was REFUSED because the observation
## seam family is frozen (`5-4/AC 15`, pinned in test_architecture_invariants.gd) and the payload
## shape is otherwise identical -- a NAMED trade-off, not a free lunch. If a later story
## finds the conflation confusing (a consumer that must distinguish WHICH negation happened), that
## is a fresh finding for that story.
##
## THE MELEE EMIT SITE PASSES `PlayerState.NO_TELEGRAPH_COLOR` (-1): an explicit "no colour to
## report" sentinel, not a fourth invented value -- the same token reused a fourth context over
## (telegraph, `5-4`'s orb-grant guard, `defense_color`'s resting value, now this).
##
## THE ATTACKER STAYS A TYPED BARE INT (`4-3b/R15`, pinned in test_architecture_invariants.gd).
## Widening the PARAMETER LIST is not widening the attacker: the pin's claim is about the attacker's
## TYPE, and it is untouched here.
signal deflect_landed(attacker_slot: int, target_slot: int, defense_color: int)

## Story 3-5a (AC 5): a Mode ① cast RESOLVED — queued in step 6 after the mana is spent, the
## card has left the hand for the discard, and the replacement has been drawn. Payload is the
## casting slot and the card that resolved.
##
## DELIBERATELY UNCONSUMED IN E3, and that is the correct state rather than a gap: the story's
## Dev Notes rule that "a resolved cast queuing an unconsumed signal is the correct E3 state; a
## fake placeholder actor is not". Nothing binds it — there is NO runner connect_ seam and no
## presentation consumer — so the observation-seam family (seven then, nine as of 5-4/R4) is
## untouched. The FIRST consumer inherits the seam obligation, exactly as action_rejected
## (1-4 -> 1-10) and deflect_landed (1-8 -> 1-10) each did.
##
## CARRIES THE CARD ID, NOT A CardEffect. The injected map is COSTS (AC 4), so the state layer
## never receives a card's effect content and cannot emit it without a second injected map
## built for a signal that has no listener — speculative machinery of exactly the kind the
## pose_id retirement precedent exists to prevent. A consumer that needs the effect resolves
## `id -> CardEffect` on the presentation side, where CardDatabase is already readable.
##
## Story 6-5a (AC 7): A THIRD ARGUMENT, `mode` -- the `Enums.ModeKind` the card resolved in, as an int.
## Without it a consumer cannot tell a Mode ① cast of a card from a Mode ④ ACTIVATION of the same card,
## and only those two can carry a buff. Emitted at all four resolution sites, each passing its own
## mode. No new seam: the arity grows, the seam family does not.
signal card_cast_resolved(slot: int, card_id: StringName, mode: int)

## Story 3-5b (AC 6): a player's discard has just been folded back into their deck and they are
## VULNERABLE for the authored window. Queued in step 6 at the reshuffle, drained by the runner
## after advance() (D5) and RELAYED onto the ownerless EventBus — the round_started /
## round_ended mechanism exactly (E3-RG/R3), because "this player's deck ran out" is a match-wide
## public fact rather than a per-entity state change.
##
## NOT A NEW OBSERVATION SEAM. The frozen family (2-6/R7, nine as of 5-4/R4) is per-slot
## CONNECT-seam observation; this rides the bus, where
## round_started and round_ended already live, and the runner bridges it in _ready() with a plain
## relay and no new seam. The payload is the vulnerable player's SLOT INDEX and nothing else —
## no card, no count, no window handle.
signal reshuffle_vulnerable_window_opened(slot: int)

## Story 4-3b (AC 13, `4-3b/R17b`): the contact fact's KIND marker. A STRIKE is a landed hitbox
## overlap — everything `push_contact` has ever carried, which is why it is the zero value. A REACH
## PROBE is the throttled "this unit's acquired target is within reach" relation, dropped at the top
## of the step-4 ladder; it delivers no damage and its only effect is permitting a windup to start.
##
## PLAIN INT CONSTANTS RATHER THAN AN `enum`, matching how the fact's other fields are typed: the
## marker rides the recorded contact ROW as a scalar (`intent_recorder.gd`), and a row element is an
## int either way — an enum here would only be a type the record cannot carry.
const CONTACT_STRIKE := 0
const CONTACT_REACH_PROBE := 1

## Story 5-2 (AC 17, `5-2/R6`): the two CHARGE-REACH kinds -- the UNTETHERED, every-tick
## hero-to-hero relation the mode (2) landing check reads on the exact tick a chargeup expires.
##
## TWO KINDS RATHER THAN ONE KIND PLUS A PAYLOAD, and that is what makes the fact carry an EXPLICIT
## inside/outside VALUE instead of encoding the answer in its own presence. `_push_reach_probe`'s
## convention -- push only when in reach, absence means out of reach -- is DISQUALIFIED here BY
## NAME: absence there is ambiguous three ways (out of reach, not probed on this cadence, actor not
## spawned), and a landing check has no freshness tolerance to spend on it (`is_in_reach_at`'s
## window means "confirmed RECENTLY"; an expiry tick needs "confirmed NOW"). Here the runner pushes
## on EVERY tick a hero is CHARGING and the KIND says which answer it measured, so absence stays a
## THIRD value (`REACH_UNKNOWN`) that lands nothing rather than a silent "outside".
##
## THE ANSWER RIDES THE KIND because the recorded contact ROW already carries `kind` as a scalar
## (`intent_recorder.gd`): a new VALUE on an existing element changes no row shape, needs no new
## capture channel, and leaves every record written since FORMAT_VERSION 4 replayable. A seventh
## `push_contact` parameter would have changed the row and forced a version bump for one boolean.
const CONTACT_CHARGE_REACH_INSIDE := 2
const CONTACT_CHARGE_REACH_OUTSIDE := 3

## Story 5-2 (AC 17): the resting value of the per-slot charge-reach latch -- NO FACT HAS BEEN
## PUSHED. Deliberately a THIRD value rather than a default of "outside": a headless MatchState with
## no runner, and the tick a chargeup BEGINS (the runner gathers before advance(), so the entry tick
## carries no fact yet), both sit here, and reading either as "outside" would silently decide a
## landing that no measurement was ever taken for.
const REACH_UNKNOWN := -1


## Story 5-2 (AC 17): whether a contact kind is one of the two CHARGE-REACH kinds. The ONE predicate
## the seam and the landing check both dispatch on -- nothing re-derives the pair inline, the
## `is_projectile_index` discipline applied one partition over. STATIC and therefore outside the
## public INTAKE surface by construction (test_intent_recorder.gd's scan matches `^func`), exactly
## as the three projectile address helpers below are.
static func is_charge_reach_kind(kind: int) -> bool:
	return kind == CONTACT_CHARGE_REACH_INSIDE or kind == CONTACT_CHARGE_REACH_OUTSIDE


## Story 4-4 (`E4-P/R12`): THE PROJECTILE PARTITION of the contact address space. `E4-P/R12` rules
## that a projectile "needs its own attacker identity and dedupe, not a `[slot, index]` unit-board
## address"; this is that identity, expressed as a THIRD PARTITION of the existing index half rather
## than as a third element on the pair.
##
## THE WHOLE SCHEME, in one place: `index >= 0` addresses a unit at that board index, `index == -1`
## (`TargetingService.HERO_INDEX`) addresses that slot's hero, and `index <= -2` addresses that
## slot's projectile at `PROJECTILE_INDEX_BASE - index`. Three partitions, one int, one convention.
##
## WHY NOT A WIDER TUPLE. The fact rides the recorded contact ROW as plain scalars
## (`intent_recorder.gd`) and every existing hero and unit call site passes a two-element pair; a
## third element would change the recorded row shape, break every replay made before this story, and
## force every call site to learn a field that two of the three partitions would leave at a constant.
##
## THE ENCODING IS ALWAYS DONE THROUGH THE TWO HELPERS BELOW, never by writing `-2 - i` at a call
## site — the `UnitBoard.has_index` discipline: a convention re-derived inline is a convention that
## can be got wrong in one place and right everywhere else.
const PROJECTILE_INDEX_BASE := -2


## The contact-address index half naming projectile `index` on its owner's board.
static func projectile_attacker_index(index: int) -> int:
	return PROJECTILE_INDEX_BASE - index


## Whether a contact address's index half names a PROJECTILE. The public predicate every rung of the
## step-4 ladder dispatches on; nothing re-derives `<= PROJECTILE_INDEX_BASE` inline.
static func is_projectile_index(attacker_index: int) -> bool:
	return attacker_index <= PROJECTILE_INDEX_BASE


## The projectile board index a contact address names. The inverse of
## `projectile_attacker_index`, and an involution on this partition — which is what makes the pair
## impossible to get half-right.
static func projectile_index_of(attacker_index: int) -> int:
	return PROJECTILE_INDEX_BASE - attacker_index

var p1: PlayerState
var p2: PlayerState
var pitch: PitchState        # fizzle-deadline owner (D8): both players' Pitch Zones (story 6-2)

## Injected via apply_balance() (story 1-1). `balance` holds the non-duration authored
## values; `balance_ticks` holds every `*_seconds` field pre-converted to integer ticks —
## the ONLY form in which those durations may be read inside advance() (A1).
var balance: BalanceConfig
var balance_ticks: BalanceTicks

## Story 1-5 (B3): the injected FeatureFlags — the first flag consumer in state. The
## runner reads FeatureFlagsService ONCE at match start and injects here; state NEVER
## reads the service (HARD RULE). Load-once, no reload path — deliberately unlike
## balance. EXCLUDED from to_snapshot(): flags are CONFIG, not state (the 1-2
## camera-basis analog), so the golden hash never depends on the flag object. Null
## (pre-injection, most headless tests) closes every flag-gated path — inert, like the
## balance null guards.
var flags: FeatureFlags

var _queue: SignalQueue
var _rng: RandomNumberGenerator  # the ONLY randomness source in the state layer (F2/A2)
var _tick := 0
var _round_over := false

## Per-slot camera basis (story 1-2) — an input-like PUSHED spatial fact, same category as
## InputIntent: the runner reads each rig and pushes it here in step 2. Fixed two-slot
## array, one per player — NEVER a single global basis (SEAM CHOICE 2: split-screen stays a
## config change). EXCLUDED from to_snapshot() like the intent stream; while the camera is
## fixed (all of E1) the basis is deterministic, so X5 replay is unaffected. Defaults to
## identity: with no basis pushed (tick 0, headless tests) move_dir is world-space (AC 4).
var _camera_bases: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]

## Story 4-6 (AC 2, `4-6/R6`): PER-SLOT LOCK DIRECTION -- the world-space planar unit direction
## from this slot's hero to its locked target, gathered by the runner and pushed here every tick.
## THE `_camera_bases` CATEGORY EXACTLY, and that is the ruling rather than a resemblance: the
## target's POSITION is actor-owned (F1) and `src/state/` holds no world coordinates, so the
## direction cannot be computed here and cannot be queried from here (D3(b)/A2). It arrives as a
## pushed fact through `set_lock_direction`, the `set_camera_basis` / `push_contact` seam family,
## and `_is_facing` has consumed a runner-gathered `Vector2` direction this exact way since 1-8.
##
## EXCLUDED from to_snapshot() and CAPTURED BY ITS OWN RECORD CHANNEL, the `_camera_bases`
## classification verbatim (test_replay_identity.gd exclusion (c)) -- NOT a fourth unhashed
## cross-tick argument, the same one argument now covering two pushed spatial arrays.
##
## Vector2.ZERO IS "NO FACT THIS TICK" and is the resting value: with nothing pushed (tick 0, and
## every headless state test that does not drive one) facing is LEFT UNCHANGED, exactly as an
## identity basis short-circuits movement to the E0 world-space mapping. A degenerate co-located
## target produces no direction and is dropped at the gather, the `push_contact` zero-direction
## rule verbatim.
var _lock_directions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

## Story 6-5b (AC 18, `6-5b/R6`): PER-SLOT DRAIN TARGET -- the board index of the own living minion
## this slot's hero is FACING most directly, gathered by the runner and pushed here every tick.
##
## THE `_lock_directions` CATEGORY EXACTLY, and the ruling says so by name: the selection is "computed
## by the runner from actor positions (hero + every living minion actor of that board) and pushed into
## state as a fact, on the `push_contact` precedent". `src/state/` holds no world coordinates and may
## not query the scene (D3(b)/A2), so the angle cannot be computed here -- and, unlike a direction,
## the ANSWER is an INDEX, so what crosses inward is already a board address rather than geometry.
##
## IT IS AN INDEX AND NOT A DIRECTION FOR A MEASURED REASON: if state received a facing VECTOR it
## would still need every minion's position to pick a minion with it, which is exactly the read this
## layer cannot make. Pushing the resolved answer is what keeps the whole selection off the state
## side and ON the replay tap -- "not recomputed inside `advance()` from anything position-shaped",
## the ruling's own clause.
##
## EXCLUDED from `to_snapshot()` and CAPTURED BY ITS OWN RECORD CHANNEL (`capture_push_drain_target`),
## the `_camera_bases` / `_lock_directions` classification verbatim -- the same one argument now
## covering three pushed arrays, never a new unhashed cross-tick exemption.
##
## `NO_DRAIN_TARGET` IS "NO FACT" and is the resting value: every headless fixture that never drives a
## push sits here, and `_drain_target_index` degrades to the board's own lowest living minion rather
## than refusing a cast the gate already allowed. See `_apply_drain`.
var _drain_targets: Array[int] = [NO_DRAIN_TARGET, NO_DRAIN_TARGET]

## The resting value of `_drain_targets`: no minion pushed this tick. `-1` rather than a second
## sentinel, because a board index is never negative (`UnitBoard.has_index`) -- so it collides with
## nothing and needs no separate "was anything pushed" flag.
const NO_DRAIN_TARGET := -1

## Story 1-5 (B7): queued contact facts, drained deterministically in advance() step 4.
## Input-like PUSHED facts, same category as InputIntent and the camera basis: plain
## recordable data (three ints per fact — X5 replay records them alongside intents; the
## actual recording is RE-HOMED to the story that lands IntentRecorder, 1-7 gate D-4;
## this seam's only obligation is staying recordable), EXCLUDED from to_snapshot()
## like the intent stream. In live play the runner pushes facts in frame step 2, so they
## reflect tick N-1's post-movement physics flush (F1 one-tick lag — absorbed by the
## dedupe grace tick, see HeroState._swing_dedupe).
var _contact_queue: Array[Dictionary] = []

## Story 5-2 (AC 17, `5-2/R6`): THE PER-SLOT CHARGE-REACH LATCH -- for each slot, the charge-reach
## answer the runner pushed for that slot's HERO as the attacker, held as the KIND itself
## (`CONTACT_CHARGE_REACH_INSIDE` / `_OUTSIDE`, or `REACH_UNKNOWN` for "nothing measured").
##
## STORY 6-1d (AC 1/AC 4/AC 6) CHANGES WHAT THE KIND MEANS AND HOW LONG IT LIVES, in `push_contact`
## where the two rules are written. WHAT: `INSIDE` is no longer "the enemy centre is within the
## authored per-colour radius" but "the tracked blade actually OVERLAPPED the defender's body, and
## did so within that radius" -- honest geometry, with the authored number surviving only as an
## upper bound that can REMOVE a hit. HOW LONG: it is the verdict of the WHOLE committed flight
## rather than of the landing tick alone -- cleared on every pre-commit push and absorbing on
## `INSIDE` once the contact window is open. `REACH_UNKNOWN` keeps its `5-2` meaning exactly: a
## third value that is not `OUTSIDE`, so "no measurement was ever taken" is never mistaken for "a
## measurement said no".
##
## IT IS NOT QUEUED, and that separation is what AC 20 requires rather than a shortcut. The landing
## check resolves at STEP 3(a), and the contact queue drains at STEP 4 -- a queued charge-reach fact
## would arrive one whole step after the tick that needs it, so the timer exit and the landing check
## could not land in the same step. `push_contact` therefore routes these two kinds HERE instead of
## into the queue: same single intake, same capture channel, different destination.
##
## THE SECOND ARRAY IS THE AUTO-AIM FACT (AC 12), and it is the SAME fact rather than a second one:
## the charge-reach push already carries the planar TARGET-TO-ATTACKER direction every contact fact
## has carried since 1-8, and the enemy-hero heading AC 12 needs is its negation. Aiming at the
## enemy HERO specifically (Ruling 8) is therefore structural -- the fact is pushed hero-to-hero and
## cannot address a minion -- rather than a filter applied to `_lock_directions`, which CAN.
##
## EXCLUDED FROM to_snapshot(), the `_lock_directions` / `_camera_bases` classification verbatim:
## these are runner-gathered pushed facts riding their own capture channel, not state the tick
## produces. A replay restores them by replaying the pushes, exactly as it restores a lock direction.
var _charge_reach: Array[int] = [REACH_UNKNOWN, REACH_UNKNOWN]
var _charge_reach_dirs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

## Story 6-1d review fix (`6-1d/R8`): THE CONTACT BEARING -- for each slot, the planar TARGET -> ATTACKER
## direction carried by the push that LATCHED `INSIDE` into `_charge_reach`, written in the SAME arm and
## only there. `_charge_reach_dirs` above keeps being written on EVERY push, because the CHARGING facing
## track (auto-aim during the chargeup) reads it; this store is what the landing's ARC reads, so the
## verdict and the bearing it is judged against are one measurement again.
##
## CLEARED WITH THE VERDICT, never on its own: in `push_contact`'s clearing arm, at the CAST SEAT and in
## `_reset_player` (`6-1d/R9`). EXCLUDED FROM to_snapshot() for `_charge_reach`'s reason verbatim -- it is
## a runner-pushed fact restored on replay by replaying the pushes (`test_replay_identity.gd` exclusion
## (c)).
var _charge_contact_dirs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

## Story 6-6b (AC 9): THE LOCKED COUNTER BEARING, per DEFENDER slot -- the planar defender-to-attacker
## bearing captured at the PRESS, which `_resolve_movement`'s counter-busy branch reads on every tick
## of the busy span for BOTH of the two things a counter needs to point at the attacker:
##   * THE TRAVEL (AC 9, widened post-smoke by R-S1/R-S2 from BLUE alone to RED and BLUE);
##   * THE FACING (R-S3), locked for the WHOLE busy span. The smoke found the defender counter-moving
##     in whatever direction it happened to be facing -- GREEN's throw animation playing one way while
##     the dagger flew another, RED jumping past the attacker's shoulder. One bearing feeds both, so
##     the body cannot point one way while the counter travels another.
##
## IT IS A COPY OF A PUSHED FACT, WHICH IS ITS WHOLE CLASSIFICATION -- `_charge_contact_dirs` directly
## above in every respect the argument turns on. The value copied is `_charge_reach_dirs[attacker_slot]`,
## the hero-to-hero bearing the runner pushes on EVERY chargeup tick (`push_contact`, `:969`). It ALREADY
## runs defender-to-attacker -- every contact fact's `dir` runs TARGET -> ATTACKER (the `1-8` convention)
## and the counter's defender IS the attacker's target -- so the read uses it UNNEGATED (see the branch).
## The member header said "negated at the read" through this story's dev pass; it was wrong and the code
## was right (REVIEW finding L1). NOT `_lock_directions`, which `:4186-4190` records can
## legitimately point at a MINION -- the charge-reach fact is pushed hero-to-hero by construction, so
## "travel toward the ATTACKER" is structural rather than filtered.
##
## LOCKED AT THE PRESS AND NEVER RE-READ, which is AC 9's requirement and not a convenience: a
## successful counter TEARS THE ATTACKER DOWN, and `push_contact`'s clearing arm then zeroes the live
## bearing one push later -- a branch re-reading it every tick would slide to a halt mid-slide the
## instant the counter landed.
##
## THE ZERO-FACT FALLBACK IS AN EXPLICIT GATE AT THE PRESS (AC 9), and the REVIEW's finding H1 is why
## it cannot be the resting value alone: `_charge_reach_dirs` is written on EVERY push and CLEARED
## NOWHERE -- not by `push_contact`'s clearing arm (which clears only `_charge_reach` and
## `_charge_contact_dirs`, the M11 measurement), not at the cast seat, and not in `_reset_player`.
## Its `Vector2.ZERO` rest (`:284`) therefore holds only until the FIRST chargeup of the process, after
## which the store keeps the last bearing that chargeup pushed, across rounds and across a debug reset.
## So the press gates on the other hero ACTUALLY BEING `CHARGING` -- "no live chargeup" in the AC's own
## words -- and copies `Vector2.ZERO` otherwise. A counter that answers nothing goes nowhere.
##
## EXCLUDED FROM to_snapshot() on `_charge_reach` / `_charge_reach_dirs` / `_charge_contact_dirs`'
## classification VERBATIM (`test_replay_identity.gd` exclusion (c)): a runner-pushed spatial fact,
## never produced by the tick, captured by `capture_push_contact` and restored on a replay by replaying
## those pushes -- the press that copies it falls on the same tick with the same pushes behind it, so
## the copy is identical. An ARRAY on argument (c), NOT a fourth argument:
## `UNHASHED_CROSS_TICK_MEMBERS` stays at FOUR. Cleared in `_reset_player` beside the two stores above,
## for their reason and not as an eighth named reset exception -- none of the three is one.
var _counter_travel_dirs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

## Story 5-6 (AC 7): THE DODGE RUNG'S OBSERVATION POINT, per slot — each hero's `is_iframe_open()`
## AS OF THE START OF STEP 3, captured before ANY same-tick press has been resolved.
##
## IT EXISTS BECAUSE THE PREDICATE ALONE IS NOT SYMMETRIC ACROSS THE TWO SEATS, which is a measured
## fact about this function's own ordering rather than a hypothetical. Step 3 runs
## `_resolve_actions(p1)` fully — timer exits INCLUDING `_resolve_charge_landing`, then p1's
## input-driven edges — before `_resolve_actions(p2)` runs at all. So a charge landing on SLOT 0
## resolves BEFORE the defender's (p2's) same-tick roll press is read, while a charge landing on
## SLOT 1 resolves AFTER the defender's (p1's) same-tick roll press has already opened its iframe.
## Reading `target.hero.is_iframe_open()` live at the landing would therefore let a same-tick roll
## dodge from ONE seat and not the other: a seat-dependent mechanic, which nothing in this game is.
##
## THE CONTRACT THIS PINS: a roll PRESSED on the very tick the charge lands dodges on NEITHER slot;
## a roll from the PREVIOUS tick — the `1-9/R2` grace-tick transient included, since this reads the
## same `is_iframe_open()` predicate the generic step-4 ladder does — dodges on BOTH, identically.
## Proven by the four-case two-slot boundary test in test_unblockable_defense.gd.
##
## CAPTURED, NOT RESTRUCTURED. The alternative shape — hoisting both slots' charge landings ahead of
## every press — would reorder a step that four stories' worth of timing claims already rest on, to
## buy the same contract. A two-element per-tick latch is the smaller change and states the contract
## where a reader of the landing will see it.
##
## PER-TICK, NEVER CROSS-TICK: written at the top of step 3 on every tick that reaches step 3, and
## read only later within that same step — the `HeroState._deflect_closed_this_tick` /
## `_roll_iframe_closed_this_tick` classification verbatim, which is why it is EXCLUDED from
## to_snapshot() with no determinism or replay hole. A round-over tick returns at step 1b and neither
## writes nor reads it; the next tick that does reach step 3 overwrites it before any read.
##
## Story 6-6a review (D1): the latch also reads true for a hero getting up from a knockdown ON THIS TICK
## (`_gets_up_this_tick`), whose get-up iframes open later in this same step. A read, not a new member.
var _iframe_open_at_step3: Array[bool] = [false, false]

## Story 6-6b (AC 8): THE COUNTER'S OBSERVATION POINT, per slot -- the colour this hero could answer an
## unblockable with AS OF THE START OF STEP 3, or `NO_TELEGRAPH_COLOR` when it could answer nothing.
## The `_iframe_open_at_step3` shape directly above, for the same measured reason and with the same
## per-tick lifetime.
##
## ONE INT CARRIES EVERY CONJUNCT (window still running, alive, not
## STUNNED, not getting up, and the colour itself) because they are ONE question -- "may this hero
## counter right now, and in what colour" -- and splitting them into a bool array plus a live colour
## read would let the two halves be captured at different instants.
##
## IT EXISTS BECAUSE THE JUDGEMENT IS A CROSS-PLAYER READ AND STEP 3 IS ORDERED. Step 3 runs
## `_resolve_actions(p1)` -- the CHARGING arm's counter judgement included -- completely before
## `_resolve_actions(p2)`. A LIVE read of the defender's facts would therefore let P1's seat write
## `STUNNED` onto P1 and P2's seat then see a stunned defender and refuse its own counter: with both
## heroes committed and both holding a matching RUNNING window on one tick, ONE counter would land
## instead of two, and WHICH one would depend on seat order. The capture makes both seats judge the
## facts as they stood before either resolved, so BOTH counters land and BOTH heroes go down -- the
## `6-6a` simultaneous-landing precedent, not a trade decided by seat order.
##
## PER-TICK, NEVER CROSS-TICK: written at the top of step 3 on every tick that reaches step 3 and read
## only later within that same step -- `_iframe_open_at_step3`'s classification verbatim, which is why
## it is EXCLUDED from to_snapshot() with no determinism or replay hole. A round-over tick returns at
## step 1b and neither writes nor reads it.
var _counter_color_at_step3: Array[int] = [NO_COUNTER_COLOR, NO_COUNTER_COLOR]

## The resting value of `_counter_color_at_step3` -- "this hero can counter nothing this tick". It is
## `PlayerState.NO_TELEGRAPH_COLOR`'s own value under a name that says what the ABSENCE means here,
## because the two facts coincide but are not the same statement: a hero may hold a window whose colour
## is a real colour and still be captured as unable to answer (dead, stunned, or getting up).
const NO_COUNTER_COLOR := PlayerState.NO_TELEGRAPH_COLOR

## Story 6-6a (AC 3/AC 6/AC 12, operator ruling R-PRESS): THE DEFERRED LANDING PACKAGE, per ATTACKER
## slot -- true when that slot's unblockable landed UNANSWERED this tick (the ladder's third tier), and
## its package is owed to the opposing hero.
##
## WHY THE PACKAGE CANNOT APPLY AT THE LANDING. `_resolve_charge_landing` runs inside the CASTER's step-3
## seat, and step 3 is p1 actions -> p1 movement -> p2 actions -> p2 movement. A knockdown written there
## would land on p2 BEFORE p2's own same-tick presses were read, but on p1 AFTER p1's -- the first
## CROSS-PLAYER write in step 3, and exactly the seat-dependence `_iframe_open_at_step3` above exists to
## refuse. It would also flip a p2 victim whose OWN chargeup lands this tick to `STUNNED` before its
## landing arm runs, cancelling that landing (AC 6's simultaneous trade).
##
## THE PINNED OUTCOME, identical for both seats: a press on the tick an incoming knockdown lands ALWAYS
## resolves first -- stamina or card spent, action taken -- and the knockdown then overwrites the
## resulting state. "Press" covers the step-6 CARD presses as well as step 3's attack/roll/block (R-PRESS
## names the card spend), so the package is applied AFTER step 6 (`_apply_landing_packages`), not merely
## after step 3.
##
## THE UNIT OF DEFERRAL IS THE WHOLE PACKAGE -- damage, the knockdown write, and the `hit_landed` push,
## in that internal order (AC 12) -- never the `STUNNED` write alone. The LADDER itself (reach, colour
## counter, dodge rung, orb grant) still resolves at the landing: only what happens TO the victim moves.
##
## A BOOL, NOT A RECORD: the package's content is fully determined by the attacker slot (the target is the
## opposing hero, the damage is the authored percent of its max hp, read inline at the apply seat).
##
## PER-TICK, NEVER CROSS-TICK: written only at step 3 and consumed-and-cleared at the apply seat later in
## the SAME advance(), with no return between the two -- the `_iframe_open_at_step3` classification
## verbatim, which is why it is EXCLUDED from to_snapshot() with no determinism or replay hole.
var _landing_package_pending: Array[bool] = [false, false]

## Story 6-6a review (D2, operator ruling): WAS THE `hit_landed` BEING EMITTED RIGHT NOW A BLOCKED HIT --
## the step-4 non-deflect block branch, `block_damage_multiplier` applied, the `_is_facing` arc passed?
## A presentation consumer cannot tell that from the payload (a full-damage hit from outside the arc on a
## BLOCKING hero looks the same), and the payload stays at four (`TelegraphController.on_hit_landed`'s
## fixed arity), so the runner reads this beside it on the `stun_flavor` shape.
##
## SET ONLY BY `_emit_hit_landed`, around the one emit it wraps, and false again before it returns. So it
## describes the SAME hit the consumer is handling off the FIFO drain -- never a live or per-tick summary,
## which would be wrong the moment two hits on one hero share a tick (one blocked, one from behind).
##
## PER-TICK, NEVER CROSS-TICK: written and cleared inside a single queued emission, false at every point
## `advance()` or `to_snapshot()` can observe it. EXCLUDED from to_snapshot() on the `_queue` /
## `_landing_package_pending` classification; it decides nothing in state.
var _hit_landed_blocked := false

## Story 3-3 (AC 2): the injected deck COMPOSITION — plain StringName ids, retained so the
## step-6 deal seat can lay a fresh pile down on BOTH of its occasions (match start and debug
## reset) without a discard pile to recover cards from. EXCLUDED from to_snapshot() for the
## same reason `flags` is: this is injected CONTENT, not state (the snapshot carries COUNTS
## only, AC 5). NEW OBLIGATION for the intent-recorder story (3-0c): this composition must
## enter the replay record alongside seed and intents, or a replay silently depends on the
## contents of data/cards/, which change without a trace.
var _deck_contents: Array[StringName] = []

## Story 3-3 (AC 7/AC 9): the one-shot latch that arms the step-6 deal. Set by the injection
## seam (match start) and re-set by _apply_debug_reset(); cleared when the seat actually runs.
## EXCLUDED from to_snapshot(): it is consumed inside the same advance() that armed it whenever
## balance is present, and it is derivable from the replay record (seed + injection + intents)
## in the one case where it is not.
var _deck_deal_pending := false

## Story 3-5a (AC 4): the injected per-card CAST COSTS, id -> CardCastCondition. ONE MATCH-WIDE
## MAP, not a per-player pair: 3-3 locked that both players receive the same injected
## composition through one seam, so a per-player cost map would be two copies of one fact.
## Asymmetric decks (and with them asymmetric costs) arrive with real deckbuilding in E4/E5+;
## until then this shape is an INHERITED CONSEQUENCE, not a defect.
##
## EXCLUDED FROM to_snapshot(), by the _deck_contents / _deck_deal_pending precedent: this is
## injected CONTENT, not evolving state, and it never changes after match start. That exclusion
## is also what makes its StringName KEYS safe. Keys of this kind must NEVER reach the snapshot:
## CanonicalHash sorts dictionary keys, and Array[StringName].sort() was MEASURED on this engine
## (4.6.3) to order by INTERNAL POINTER rather than lexicographically — deterministic within one
## process, NOT across runs or builds. Both determinism tests run in a single process, so a
## StringName key inside the hash would pass green while replay was already broken and no guard
## in the suite would catch it.
##
## NEW OBLIGATION for the intent-recorder story (3-0c), the twin of the one _deck_contents
## already carries: this map must enter the replay record alongside seed, intents and the
## injected composition, or a replay silently depends on the contents of data/cards/.
var _card_costs: Dictionary[StringName, CardCastCondition] = {}

## Story 4-1 (AC 2): the injected per-card EFFECT map — `_card_costs`'s twin, carrying the same
## obligations for the same reasons. Runner-derived, injected once at match start, keyed by the
## same plain StringName ids; no file under src/state/ may name CardDatabase, CARDS_DIR or
## data/cards, so this is the only way a CardEffect reaches this layer. It rides the replay
## record on its own capture channel (`4-1/R1`, `4-1/R2`) for the reason stated directly above:
## without it a replay would silently depend on the contents of data/cards/.
##
## NEVER HASHED, exactly like `_card_costs` and `_deck_contents`. This is injected CONTENT — it
## is never produced by the tick and never changes except through a seam that IS a capture
## channel — which is the classification test_replay_identity.gd's member pin records it under.
var _card_effects: Dictionary[StringName, CardEffect] = {}

## Story 5-2 (AC 4, `5-2/R1`): the injected per-card COLOUR map, id -> `Enums.CardColor` -- the
## THIRD injection seam, `_card_costs`'s and `_card_effects`'s twin in every respect, carrying the
## same obligations for the same reasons. It exists so that `src/state/` can learn a card's colour
## while STILL never reading a `CardData` (`card_data.gd:5`): the runner is the only reader of
## CardDatabase, and what crosses the boundary here is a plain id mapped to a plain enum int.
##
## NEVER HASHED, like both of its siblings: this is injected CONTENT, never produced by the tick,
## and it changes only through a seam that IS a capture channel. The colour that DOES reach the hash
## is the one COPIED onto `PlayerState.charge_color` at a cast -- a single int, not this map.
var _card_colors: Dictionary[StringName, Enums.CardColor] = {}

## Story 6-2 (AC 1/AC 2, discharging `E6-P/R9`): the injected per-card PITCH COST map, id ->
## CardCastCondition -- the FIFTH injection seam, `_card_costs`'s twin in every respect but ONE. It
## carries Mode ④'s price (mana paid at staging, orbs read as READY afterwards), which genuinely differs
## per mode, so it is its own map rather than a wider Mode ① record.
##
## THE ONE DIFFERENCE: IT IS NOT TOTAL. `inject_pitch_costs` enforces no totality over the composition,
## because a card whose pitch cost is unauthored is ordinary, legal content (AC 2) that refuses to
## stage with `REASON_NO_PITCH_COST`, not a load-time crash.
##
## NEVER HASHED, like all four siblings: injected CONTENT, never produced by the tick, changed only
## through a seam that IS a capture channel (`capture_inject_pitch_costs`). What reaches the hash is the
## orb price COPIED into `PitchState` at staging.
var _pitch_costs: Dictionary[StringName, CardCastCondition] = {}

## Story 6-5a (AC 6): the injected per-card PITCH EFFECT map, id -> CardEffect -- the SIXTH injection
## seam, `_card_effects`'s twin for Mode ④, resolved at ACTIVATION (`_resolve_pitch_activate`) and
## never at staging. NOT TOTAL, on `_pitch_costs`'s ruling: a card with no pitch effect authored is
## legal content whose activation resolves to `REASON_NO_EFFECT_ENTRY`.
##
## NEVER HASHED, like all five siblings: injected CONTENT, changed only through a seam that IS a capture
## channel (`capture_inject_pitch_effects`).
var _pitch_effects: Dictionary[StringName, CardEffect] = {}


## Story 3-1 (AC 1/AC 3): construction takes ONE match-scoped params object and nothing
## else. The five positional floats are gone — max_hp, move_speed, max_stamina and max_mana
## now arrive ONLY through apply_balance() (BalanceConfig is their single source of truth),
## and the seed arrives here, once, never re-applied. Both players are therefore constructed
## STAT-LESS (AC 5 / 3-1/R3): a MatchState that never received apply_balance() has zeroed
## bounds and is inert — no regen, no contact resolution, no round end.
func _init(params: MatchParams) -> void:
	_queue = SignalQueue.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = params.seed_value
	p1 = PlayerState.new(_queue)
	p2 = PlayerState.new(_queue)
	pitch = PitchState.new()
	# Story 4-6 (`CC/R2`, AC 2): THE RESTING LOCK IS THE OPPOSING HERO, and it is seeded HERE
	# because this is the only place that knows which slot each PlayerState is. Story 6-8 (AC 20)
	# adds an unlocked state but NOT at rest: a match starts locked, and so does the round after a
	# debug reset (`_reset_lock` below is called from both). A locked target's death still snaps
	# back to this same address (AC 21); an unlocked player has no target to lose.
	_reset_lock(p1, 1)
	_reset_lock(p2, 0)


## The single ordered dispatch (D2). intents = [p1_intent, p2_intent]. Enqueues signals
## only — never emits. Player order is fixed P1 -> P2 for determinism.
func advance(intents: Array[InputIntent]) -> void:
	var p1_intent := intents[0]
	var p2_intent := intents[1]
	_tick += 1

	# 1. Ingest intents        debug reset only (story 1-7, D-2): intent-carried so the
	#    mutation stays inside the ordered dispatch (D2) and rides the recorded intent
	#    stream for free once the X5 recorder lands. Attack/block/roll presses are still
	#    read directly by the step-3 transition evaluation.
	if p1_intent.debug_reset or p2_intent.debug_reset:
		_apply_debug_reset()
	# 1b. Round-over freeze (story 2-6, AC 1, 2-6/R6 — the 2-3/R10 named gap's owner): once the
	#    round is over, HALT both heroes and return, skipping steps 2 through 8 for this tick, so
	#    the surviving hero stops moving instead of gliding on. Seated AFTER step 1 (reset
	#    ingestion), NEVER hoisted ahead of it (the R6 ordering): a debug reset landing on the SAME
	#    tick the round is frozen cleared _round_over just above, so movement resolution resumes
	#    THAT tick, not one tick later. _tick already incremented at the top, so frozen ticks still
	#    advance the counter — a reset landing on tick N stays deterministic.
	#    Velocity is zeroed on EVERY frozen tick (2-6 operator ruling, close-out micro-decision):
	#    the runner reads HeroState.velocity into move_and_slide() every physics frame regardless
	#    of this early return, so a skipped write would leave the corpse (or any hero moving at the
	#    kill instant) sliding at its last live speed forever — exactly the 2-3/R14 residual, now
	#    honoured HERE instead of the step-3 DEAD branch. This is the standing 2-3 asymmetry rule
	#    applied unchanged: a field read downstream must be WRITTEN, a display-only field may be
	#    SKIPPED, so facing is left untouched and its last value persists (2-3/R14). The 2-3/R13
	#    one-tick carry is intact: on the KILL tick movement resolves at step 3 and DEAD is set at
	#    step 8, so the freeze only begins the NEXT tick — the corpse still carries its final
	#    velocity for exactly that one tick before step 1b zeroes it. Golden CANNOT prove this: the
	#    recorded sequence never reaches a round-over (story Dev Notes / test_determinism).
	if _round_over:
		p1.hero.velocity = Vector3.ZERO
		p2.hero.velocity = Vector3.ZERO
		return
	# 1c. Story 4-6 (AC 3/AC 9/AC 10): THE LOCK SEAT -- ingest each slot's retarget RESULT off its
	#    intent, then re-validate the standing lock. Seated HERE, after the step-1b freeze and
	#    BEFORE step 3, for two reasons that pull the same way: a click or flick must take effect
	#    on the tick it was pressed (AC 9's "instantly", the same tick-N rule step 3 applies to
	#    attack/block/roll presses), and step 3's facing write reads the result. A round-over tick
	#    returns above and never reaches this line, which is exactly what AC 3 means by the freeze
	#    making target resolution inert when the opposing hero is the thing that died.
	#
	#    THE VALIDATION HALF RUNS TWICE, and the second seat (4b) is not redundancy -- see there.
	#    This one catches a lock whose target the step-1 DEBUG RESET just cleared off the board.
	_resolve_lock(p1, p1_intent, 1)
	_resolve_lock(p2, p2_intent, 0)
	# 2. Advance D4 timers   (hero windows + each pool's regen-delay window — every window
	#    advances here, step 5 reads the result; unguarded like the hero timers, since a
	#    pre-injection MatchState never started a delay window)
	p1.hero.tick_timers()
	p2.hero.tick_timers()
	p1.stamina.tick_timers()
	p2.stamina.tick_timers()
	# Story 3-5b (AC 3/AC 8): the pending-draw window and its vulnerable-window sibling advance
	# HERE, beside every other D4 timer, and step 6 reads the result — the StaminaPool
	# _regen_delay idiom verbatim (ticked at step 2, consumed at step 5). Seating the tick here
	# buys AC 8's frozen-tick contract for FREE: step 1b returns above, so a round-over tick
	# never reaches this line and no window advances during the freeze. Unguarded like its
	# neighbours — a pre-injection MatchState never started either window.
	p1.pending_draw.tick()
	p2.pending_draw.tick()
	p1.vulnerable_window.tick()
	p2.vulnerable_window.tick()
	# Story 5-2 (AC 10): the mode (2) CHARGEUP counts down HERE, beside every other D4 timer, and
	# the step-3(a) seat below reads the result -- the `pending_draw` idiom verbatim (ticked at step
	# 2, consumed later in the same tick), and A1 satisfied by construction: one integer tick per
	# advance(), never a float accumulator and never a seconds value. Unguarded like its
	# neighbours, because a pre-injection MatchState never started the window.
	p1.charge_window.tick()
	p2.charge_window.tick()
	# Story 6-1c (AC 2/AC 4): the LANDING window counts down beside its chargeup sibling, on the
	# identical idiom -- ticked here, read at step 3(a). Which of the two is still running is what
	# says whether a charging hero is in its chargeup, committed to its launch, or landing THIS tick.
	p1.landing_window.tick()
	p2.landing_window.tick()
	# Story 5-5 (AC 2): the mode ③ DEFENSE WINDOW counts down HERE, beside its chargeup sibling and
	# every other D4 timer; the LANDING seat (AC 9) reads the result. The `charge_window` idiom
	# verbatim, and A1 satisfied by construction: one integer tick per advance(), never a float
	# accumulator and never a seconds value. Unguarded like its neighbours, because a pre-injection
	# MatchState never started the window. THIS IS THE ONLY LINE IN THE CODEBASE THAT ADVANCES IT --
	# no landing path, defended or not, touches it (AC 11).
	p1.defense_window.tick()
	p2.defense_window.tick()
	# Story 6-5a (AC 8): the TIMED-RULE SEAT counts down HERE, beside every other D4 window, on the
	# identical idiom -- ticked in one place, read at the seats that apply each rule. A round-over tick
	# returns at step 1b and never reaches this line, so a running buff freezes with the round.
	p1.tick_rules()
	p2.tick_rules()
	# Story 6-2 (AC 9/AC 14e): both Pitch Zone FIZZLE countdowns advance HERE, beside every other D4
	# timer, and the step-6 expiry seat reads the result -- the `pending_draw` idiom verbatim (ticked at
	# step 2, consumed later in the same tick). Seated after step 1b, so a round-over tick never reaches
	# this line and a staged card's countdown FREEZES with the round (the `2-6/R14` shape every other
	# countdown here shares). Unguarded like its neighbours: an empty zone's window is stopped.
	pitch.tick()
	# Story 4-3b (AC 1): the UNIT attack rhythm counts down HERE, beside every other D4 timer, and
	# the step-3 seat below reads the result — the hero's own `tick_timers()` shape, for a container
	# instead of an object (A1: integer ticks, one per advance(), never a float accumulator). The
	# unit dedupe records advance their grace tick in the same breath, exactly as the hero's records
	# do inside `HeroState.tick_timers()`. Unguarded like its neighbours: a pre-injection MatchState
	# has an empty board and no records, so both calls are no-ops.
	p1.units.tick_attack_timers()
	p2.units.tick_attack_timers()
	p1.unit_dedupe.tick()
	p2.unit_dedupe.tick()
	# Story 6-5b (AC 4): the CORPSE COUNTDOWNS advance HERE, beside every other D4 timer and in the
	# same breath as the board's attack rhythm -- one integer tick per advance(), never a float
	# accumulator and never a `Time`/`OS`/`Engine` read from this layer (A1/D3(b)). Seated after step
	# 1b, so a corpse does NOT age during the round-over freeze: the `4-1/R5` posture that the board
	# persists through round-over rather than blinking out, now true of corpses for free.
	#
	# THE ACTOR NO LONGER COUNTS ANYTHING (AC 2). `UnitActor.LINGER_TICKS` / `_linger_ticks` are gone;
	# this is the ONE clock a corpse has, and the runner hands the actor its remaining value to react
	# to. `MatchRunner` calls this from nothing -- it is inside `advance()`, so the 3-0b debug pause
	# freezes it exactly as it froze the actor-owned linger, by not advancing at all.
	p1.units.tick_corpses()
	p2.units.tick_corpses()
	# 3. Resolve actions       per slot P1 -> P2: action transitions FIRST (a press on
	#    tick N takes effect on tick N), then intended velocity from move_dir. Transitions
	#    never write velocity — both halves of the 1-3 coupling deferral now live in
	#    _resolve_movement (1-5 attack commitment; 1-9 roll override reading the
	#    entry-locked roll_direction, captured here in step 3 at the ROLLING transition).
	# Story 5-6 (AC 7): THE DODGE RUNG'S OBSERVATION POINT, captured HERE and nowhere else — after
	# step 2 has advanced every window (so the `1-9/R2` grace-tick transient is already recomputed for
	# this tick) and BEFORE the first press of this tick is resolved. See `_iframe_open_at_step3` for
	# why the landing cannot simply read the predicate live. Story 6-6a review (D1): a hero whose
	# knockdown ran out at THIS tick's step 2 counts as iframed too -- see `_gets_up_this_tick`.
	_iframe_open_at_step3[0] = p1.hero.is_iframe_open() or _gets_up_this_tick(p1.hero)
	_iframe_open_at_step3[1] = p2.hero.is_iframe_open() or _gets_up_this_tick(p2.hero)
	# Story 6-6b (AC 8): the COUNTER's observation point, captured HERE and nowhere else, on the exact
	# line above's seat and for the seat-symmetry reason `_counter_color_at_step3` states. Taken after
	# step 2 has advanced every window (so a window that emptied at this tick's step 2 is captured as
	# spent) and BEFORE either seat's `_resolve_actions` has resolved anything.
	_counter_color_at_step3[0] = _counter_color_of(p1)
	_counter_color_at_step3[1] = _counter_color_of(p2)
	_resolve_actions(p1, p1_intent, 0)
	var p1_actually_running := _resolve_movement(p1, p1_intent, 0)
	_resolve_actions(p2, p2_intent, 1)
	var p2_actually_running := _resolve_movement(p2, p2_intent, 1)
	# 3b. Story 4-3b (AC 1/AC 13): the UNIT attack rhythm's phase progression — the step-3 FAMILY's
	#    third member, seated after both heroes for the same fixed P1 -> P2 determinism every other
	#    per-player loop in this function follows. It is AI-driven, not input-driven: no
	#    `InputIntent`, no `TRANSITION_TABLE` row, no stamina spend and no chain (AC 11). What it
	#    borrows from `_resolve_actions` is only the WINDOW-ADVANCE SHAPE — read the timer step 2
	#    just advanced, and move the phase when it reaches its boundary.
	_advance_unit_attacks(p1)
	_advance_unit_attacks(p2)
	# 3c. Story 4-4 (AC 15/AC 19): the PROJECTILE FLIGHT ADVANCE — the step-3 family's fourth
	#    member, seated after both unit seats for the same fixed P1 -> P2 determinism, and BEFORE
	#    step 4 for a load-bearing reason: a shot whose budget expires on this tick must be dead by
	#    the time the ladder judges the facts it produced, so a fact gathered under the F1 one-tick
	#    lag from an already-expired shot drops at the dead-attacker rung — which is what AC 19's
	#    "removed from the world" has to mean for a fact still in flight — rather than landing a hit
	#    the shot had no budget left for.
	#
	#    IT ADVANCES A CLOCK AND AN ODOMETER, NOTHING ELSE. The heading is actor-owned and never
	#    enters this layer; what advances here is the acceleration clock (which decides the current
	#    speed) and the path length (which decides the end).
	_advance_projectiles(p1)
	_advance_projectiles(p2)
	# 4. Resolve contacts      (story 1-5) drain the queued facts in push order: dedupe/
	#    liveness acceptance -> damage -> record confirmed hits for step 5. Damage and
	#    dedupe ONLY here — mana is step 5's seat, keeping the documented D2 order
	#    truthful (N4).
	var confirmed_hits := _resolve_contacts()
	# 4b. Story 4-6 (AC 3, `4-6/R4`/`4-6/R5`): THE CORPSE-FREE SNAP. When the locked target is a
	#    minion or totem and it dies, the lock moves to the opposing hero IMMEDIATELY, the SAME
	#    TICK -- no corpse-hold window, even though the corpse itself lingers on the board for
	#    several ticks (`4-3d`, test_unit_corpse_linger_live.gd). Step 4 is the ONLY seat that can
	#    kill a unit, so "same tick" means exactly "seated right after it": validating only at
	#    step 1c would leave the hashed end-of-tick snapshot pointing at a corpse for one tick,
	#    which is a corpse-hold window one tick long wearing a different name.
	#
	#    IDEMPOTENT, which is what makes running it twice honest rather than a smell: it either
	#    finds a live addressed unit and returns, or resets to the opposing hero. Nothing it does
	#    depends on how many times it has run this tick.
	_validate_lock(p1, 1)
	_validate_lock(p2, 0)
	# 5. Resource generation   stamina regen (story 1-4) then mana — melee-hit AND the
	#    passive tick (story 3-4), P1 -> P2. Stamina is still DIRECT; mana is now the D6
	#    EVALUATOR path (DEBT D's extraction, re-triggered at E3 exactly as the 1-5
	#    resolution said it would be): _generate_mana asks EconomyEvaluator for each
	#    authored rule's amount and applies it to the pool. Same single null guard rationale
	#    as step 3: a pre-injection MatchState stays inert, no scattered checks below.
	if balance_ticks != null:
		_regen_stamina(p1, p1_actually_running)
		_regen_stamina(p2, p2_actually_running)
		_generate_mana(confirmed_hits)
	# 6. Card / economy        the DECK DEAL seat (story 3-3, AC 7/AC 9) — the ONE seat, serving
	#    BOTH occasions: match start (armed by the injection seam) and the debug reset (armed at
	#    step 1 THIS tick, so a reset's reshuffle lands on the reset tick, not one later). Seated
	#    HERE rather than in inject_deck() so "the seeded RNG is consumed only inside advance()"
	#    stays provable (F2) — and because the debug reset is an intent in the recorded stream,
	#    the reset-time reshuffle is replay-safe for free.
	#    [E3 card play/draw — 3-5; E6 pitch resolution]
	#    Story 3-5a (AC 2/AC 9): the CAST dispatch shares this one seat, seated AFTER the deal so
	#    a cast committed on the very first tick has a hand to cast FROM. Card actions are READ
	#    HERE, never ingested at step 1 (step 1 ingests the debug reset and nothing else) —
	#    matching the E2-CO/R3 precedent already applied to move_dir/attack/block/roll. Fixed
	#    P1 -> P2 order, like every other per-player loop in this function.
	_deal_pending_decks()
	_resolve_card_action(p1, p1_intent, 0)
	_resolve_card_action(p2, p2_intent, 1)
	#    Story 6-2 (AC 11/AC 14e): the PITCH FIZZLE EXIT, seated AFTER the card dispatch and BEFORE the
	#    pending-draw delivery, and both edges are load-bearing. After the dispatch, so a card staged
	#    THIS tick against a zero-tick countdown fizzles on its own staging tick rather than one late.
	#    Before the delivery, so the replacement the fizzle owes rides the SAME delivery pass: with a
	#    zero delay too, the vacated slot is refilled on the fizzle tick itself -- `_resolve_basic_cast`'s
	#    zero-delay degrade, reached from a different debt.
	_resolve_pitch_expiry(p1, 0)
	_resolve_pitch_expiry(p2, 1)
	#    Story 6-3b (AC 1 site (f), AC 5): the PITCH HUD COUNTDOWN THROTTLE, at the tail of the fizzle
	#    exit so a card that fizzled THIS tick is already empty and never throttles. Only a STAGED zone,
	#    and only on a multiple of the authored interval (`_tick % interval`, the step-7 retarget
	#    throttle's shape) -- presentation gets no per-tick timing-window firehose (`2-6/R7`). It also
	#    refreshes READY, which is how a mid-window balance reload lowering `max_orbs_per_color` reaches
	#    the HUD within one interval. NO NEW STATE: `_tick` is already hashed, and the emission reads.
	#    A round-over tick returned at step 1b, so nothing emits while the countdown is frozen.
	for pitch_slot: int in 2:
		if pitch.is_staged(pitch_slot) \
				and _tick % balance_ticks.pitch_countdown_push_interval_ticks == 0:
			_queue_pitch_changed(pitch_slot)
	#    Story 3-5b (AC 3/AC 5): the PENDING-DRAW DELIVERY, third and last in this one seat, and
	#    the ordering is load-bearing in both directions. AFTER the cast dispatch, because a
	#    derived delay of ZERO ticks must still refill on the cast tick (TimingWindow.start(0)
	#    leaves is_running false, so the delivery below fires immediately) — that is what makes a
	#    zero delay degrade EXACTLY to 3-5a's instant refill instead of arriving one tick late,
	#    and it is what lets the golden isolate the delay's SEAT from its authored CONTENT.
	#    INSIDE step 6, because a delivery may need to reshuffle, and the reshuffle must consume
	#    the seeded RNG in the SAME seat _deal_pending_decks() already occupies — F2 ("the seeded
	#    RNG is consumed only inside advance()") stays provable by inspection, and machine-checked
	#    since AC 16. A naive "tick and draw together at step 2" would have opened a second seat.
	_deliver_pending_draw(p1, 0)
	_deliver_pending_draw(p2, 1)
	# 6b. Story 6-6a (AC 3/AC 6, R-PRESS): THE LANDING-PACKAGE SEAT -- every unanswered unblockable that
	#    landed at step 3 this tick is applied to its victim HERE, after BOTH seats' step-3 presses and
	#    step-6 card presses have resolved, so a same-tick press resolves first on either seat and the
	#    knockdown then overwrites the result. Before step 8, so a lethal landing still ends the round on
	#    its own tick. Fixed P1 -> P2 package order, like every other per-player loop in this function.
	_apply_landing_packages()
	# 7. Board update          the SHARED THROTTLED TARGETING TICK (story 4-2, AC 7, `4-2/R15`).
	#    This line replaces the literal `[E4 minion/totem throttled-tick seam]` comment that
	#    reserved the seat from E4 planning onward — the seat is now filled by the thing it was
	#    reserved for, not by something that merely fits.
	#
	#    A SHARED TICK INSIDE advance(), NOT `Area3D` OVERLAP QUERIES, and that is a DETERMINISM
	#    ruling rather than a performance one (`4-2/R15`). Overlap queries were rejected BY NAME:
	#    they are physics-frame, live outside src/state/, and Jolt's results are not guaranteed
	#    bit-stable across a recording and its replay — the same reasoning that rejected
	#    physics-timing contact detection at 1-7 (`D-4`). Evaluated here, the outcome is hashable by
	#    construction and replay-safe for free, exactly like every other step-1-through-8
	#    computation.
	#
	#    SEATED BETWEEN CARD RESOLUTION (step 6) AND THE RESOLUTION CHECK (step 8) because a unit's
	#    target must be knowable before step 8 asks "is anything dead" — even though this story adds
	#    no death consequence of its own (movement, combat, HP and death are all 4-3's, `4-2/R4`).
	#    A unit summoned by THIS tick's step-6 cast is therefore already on the board when this runs:
	#    if this tick IS a throttle boundary, the unit acquires its first target immediately, in this
	#    same advance() call; otherwise it acquires at the next boundary tick.
	#
	#    Dev Note (`4-2/R18`): `test_targeting_service.gd`'s `_summon()` helper appends straight to
	#    `player.units` and never runs step 6, so it cannot exercise either half of this — a future
	#    story testing step-6-adjacent behaviour needs a real cast fixture (see `_match_for_cast`
	#    there), not that helper.
	_update_unit_targets()
	# 8. Resolution check
	_check_resolution()


## X3 hot-reload seam (story 1-1): the runner passes the (re)loaded BalanceConfig here.
## Re-injects bounds set_maximum-style (re-clamp + re-signal, queued per D5) and
## re-converts every `*_seconds` duration ONCE via BalanceTicks. A TimingWindow already
## in flight keeps its original duration; the new tick counts take effect at its next
## start() (D4/A1). Player order fixed P1 -> P2 for determinism.
##
## Story 3-1 (AC 4, 3-1/R2): this is ALSO match start now that the constructor carries no
## stats, and the two occasions differ in exactly one place — hp. FIRST injection is
## detected from `balance == null` (a DERIVED fact, no new field to keep in sync, and
## nothing else writes `balance`); it is passed down rather than re-derived per player so
## both players are read from the same decision.
func apply_balance(config: BalanceConfig) -> void:
	var first_injection := balance == null
	balance = config
	balance_ticks = BalanceTicks.from_config(config)
	_apply_balance_to_player(p1, config, first_injection)
	_apply_balance_to_player(p2, config, first_injection)


## Story 1-5 (B3): one-time flag injection at match start. Runner-only, exactly once —
## flags have NO reload path (deliberately unlike apply_balance); state never reads
## FeatureFlagsService.
func inject_feature_flags(value: FeatureFlags) -> void:
	flags = value


## Story 3-3 (AC 2): the deck-content INJECTION SEAM — the inject_feature_flags precedent
## above, followed exactly: runner-only, ONCE at match start, CONTENT ONLY, and NO reload path
## (deliberately unlike apply_balance). This is the ONLY way deck content reaches src/state/;
## no file under src/state/ may name CardDatabase, CARDS_DIR or data/cards (AC 1/AC 8), so the
## runner reads the autoload, derives the composition (AC 4) and hands plain StringName ids in.
##
## CONTENT ONLY, NEVER THE DEAL: the ids are retained here and the shuffle + fill happen at the
## step-6 seat inside advance(). Calling this does not consume one bit of the seeded RNG — the
## property test_injection_alone_deals_nothing_and_consumes_no_rng pins.
##
## AC 10: an EMPTY injected deck is a programming error, ENFORCED AT THE SEAM (Invariant.check,
## the push_contact precedent — a plain static class, export-surviving, no autoload). This is
## the DETECTOR the ownerless export-packaging remap risk flag gained instead of an owner: a
## data/cards/ that degrades to empty under export remap becomes a LOUD failure at match start
## rather than a silently empty deck nobody notices.
func inject_deck(contents: Array[StringName]) -> void:
	Invariant.check(not contents.is_empty(), "injected deck content must be non-empty (empty card set or a failed export remap?)")
	_deck_contents = contents.duplicate()
	_deck_deal_pending = true


## Story 3-5a (AC 4): the CAST-COST injection seam — the inject_deck precedent directly above,
## followed exactly: runner-only, ONCE at match start, CONTENT ONLY, and NO reload path
## (deliberately unlike apply_balance). This is the ONLY way cast costs reach src/state/; no
## file under src/state/ may name CardDatabase, CARDS_DIR or data/cards, so the runner reads the
## autoload, derives the map and hands plain ids + CardCastCondition resources in.
##
## MUST BE CALLED AFTER inject_deck(). The second check below reads _deck_contents, so the
## ordering is not a style preference — it is what makes the check mean anything. The runner
## calls the two in that order and test_card_play.gd pins the guard.
##
## TWO checks, both Invariant.check at the seam (the inject_deck / push_contact precedent — a
## plain static class, export-surviving, no autoload):
##   1. NON-EMPTY, the inject_deck rationale verbatim: a data/cards/ that degrades to empty
##      under an export remap becomes a LOUD failure at match start rather than a match in
##      which every cast silently refuses with `unknown_card`.
##   2. TOTAL OVER THE COMPOSITION: every id that can ever reach a hand has a cost entry. A
##      hand is filled only from the deck, and the deck is laid down only from the injected
##      composition, so this check makes an unknown id AT CAST TIME structurally unreachable —
##      which is precisely why CastEvaluator carries no live crash guard for it (AC 4's
##      "unreachable rather than a new crash guard").
func inject_card_costs(costs: Dictionary[StringName, CardCastCondition]) -> void:
	Invariant.check(not costs.is_empty(),
		"injected cast costs must be non-empty (empty card set or a failed export remap?)")
	for id in _deck_contents:
		Invariant.check(costs.has(id),
			"injected deck id %s has no cast cost entry — inject_card_costs must be total over the composition" % id)
	_card_costs = costs.duplicate()


## Story 4-1 (AC 2): the CARD-EFFECT injection seam — the inject_card_costs precedent directly
## above, followed VERBATIM (`E4-P/R4`, which explicitly does not relitigate the seam shape):
## runner-only, ONCE at match start, CONTENT ONLY, and NO reload path. This is the ONLY way
## CardEffects reach src/state/; the runner reads the CardDatabase autoload, derives the map and
## hands plain ids + CardEffect resources in.
##
## THE INJECTION ORDER IS DECK -> COSTS -> EFFECTS (`4-1/R8`), and the last leg is load-bearing
## for the same reason the first two are: the totality check below reads `_deck_contents`, so
## effects-before-deck would validate against an EMPTY composition and pass vacuously. The runner
## calls all three in that order, IntentRecorder.SOUND_CONTENT_ORDER pins it in the record, and
## replay_inject_content() refuses any other order.
##
## TWO checks, both Invariant.check at the seam, the inject_card_costs pair exactly:
##   1. NON-EMPTY: a data/cards/ that degraded to empty under an export remap becomes a LOUD
##      failure at match start rather than a match in which every summon silently lands on
##      CardEffectResolver's missing-entry default.
##   2. TOTAL OVER THE COMPOSITION: every id that can ever reach a hand has an effect entry.
##
## INJECTION IS OPTIONAL STATE-SIDE, AND THE TWO OBLIGATIONS MUST NOT BE CONFLATED (`4-1/R3`).
## Not calling this at all is legal here — every MatchState-building fixture that predates this
## story does exactly that, and its casts land on CardEffectResolver.REASON_NO_EFFECT_ENTRY, the
## honest default. What is MANDATORY is RECORD-side: IntentRecorder.missing_match_start_channels()
## treats a missing effects channel as malformed for a v2 record, and the live runner always
## injects. Optional-at-the-seam, required-in-the-record: two different obligations on one channel.
func inject_card_effects(effects: Dictionary[StringName, CardEffect]) -> void:
	Invariant.check(not effects.is_empty(),
		"injected card effects must be non-empty (empty card set or a failed export remap?)")
	for id in _deck_contents:
		Invariant.check(effects.has(id),
			"injected deck id %s has no card effect entry — inject_card_effects must be total over the composition" % id)
	_card_effects = effects.duplicate()


## Story 5-2 (AC 4, `5-2/R1`): the CARD-COLOUR injection seam -- `inject_card_costs` and
## `inject_card_effects` directly above, followed VERBATIM: runner-only, ONCE at match start,
## CONTENT ONLY, no reload path, and the same two seam checks in the same order.
##
## IT IS THE FOURTH CONTENT CHANNEL AND IT GOES LAST, for the reason the other three are ordered:
## the totality check below reads `_deck_contents`, so colours-before-deck would validate against an
## EMPTY composition and pass vacuously. `IntentRecorder.SOUND_CONTENT_ORDER` pins deck -> costs ->
## effects -> colours into the record and `replay_inject_content()` refuses any other order.
##
## THIS IS THE SOURCE AC 21's TELEGRAPH COLOUR READS FROM, and it is why `5-2` needs a seam at all
## rather than a lookup: colour is authored on `CardData`, nothing under `src/state/` may name a
## `CardData` or CardDatabase, and the telegraph fact is state the snapshot carries.
##
## TWO checks, both Invariant.check at the seam, the pair its two siblings use:
##   1. NON-EMPTY: a data/cards/ that degraded to empty under an export remap becomes a LOUD failure
##      at match start rather than a match in which every telegraph is silently RED.
##   2. TOTAL OVER THE COMPOSITION: every id that can ever reach a hand has a colour entry, which is
##      what makes an unknown id at cast time structurally unreachable here too.
func inject_card_colors(colors: Dictionary[StringName, Enums.CardColor]) -> void:
	Invariant.check(not colors.is_empty(),
		"injected card colours must be non-empty (empty card set or a failed export remap?)")
	for id in _deck_contents:
		Invariant.check(colors.has(id),
			"injected deck id %s has no card colour entry - inject_card_colors must be total over the composition" % id)
	_card_colors = colors.duplicate()


## Story 6-2 (AC 2, `E6-P/R9`): the PITCH-COST injection seam -- the fifth content channel, and the
## four seams above followed for everything but their checks: runner-only, ONCE at match start,
## CONTENT ONLY, no reload path, a copy retained. It rides the record on its own capture channel
## (`capture_inject_pitch_costs`), so a card re-priced in data/cards/ after a recording cannot change
## what a replay's staging pays.
##
## NO `Invariant.check` AT ALL, AND THAT IS THE AC (AC 2), not an omission. Its siblings enforce
## non-empty and total-over-the-composition because a missing Mode ① cost or colour is a broken card.
## A missing PITCH cost is not: the pitch numbers are provisional content, and a card added without one
## is legal -- it simply refuses to stage with `REASON_NO_PITCH_COST`. An EMPTY map is legal for the
## same reason (no card authors pitch content). Enforcing totality here would turn authoring a new card
## into a load-time crash.
##
## ORDER-INSENSITIVE, UNLIKE ITS SIBLINGS: with no check reading `_deck_contents`, nothing about this
## seam depends on the composition already being in. It is still injected LAST, after the colours, so
## `IntentRecorder.SOUND_CONTENT_ORDER` stays one straight line the runner and the record both follow.
func inject_pitch_costs(costs: Dictionary[StringName, CardCastCondition]) -> void:
	_pitch_costs = costs.duplicate()


## Story 6-5a (AC 6): the PITCH-EFFECT injection seam -- the sixth content channel, `inject_pitch_costs`
## directly above followed for everything including its ABSENCE of checks, and for its reason: a card
## without a pitch effect is legal content, and an empty map is legal. Injected LAST, after the pitch
## costs, so `IntentRecorder.SOUND_CONTENT_ORDER` stays one straight line.
func inject_pitch_effects(effects: Dictionary[StringName, CardEffect]) -> void:
	_pitch_effects = effects.duplicate()


## Story 1-5 (B7): the contact intake seam — 1-7's real runner-gathered facts MUST enter
## through this same call, never a second path. Plain recordable data (X5): attacker
## slot, target slot, the attacker's HeroState.attack_index at gather time, and (story
## 1-8, R-B3 — the FOUR-field fact, superseding the original three-int shape) the
## world-space planar direction from the TARGET to the ATTACKER, computed by the runner
## FROM POSITIONS ONLY. The runner reports the spatial fact; state alone compares it
## against the target's facing (the arc gate is step-4 policy). Queued here, drained in
## advance() step 4. Headless tests feed synthetic facts through this API. A malformed
## fact is a programming error, ENFORCED at the seam (review R1 — Invariant.check, a
## plain static class, no autoload): slots must be 0 or 1, a self-contact is malformed
## in 1v1 (operator decision; 1-7's gate revisits if real gathering ever needs
## otherwise), and a zero direction is directionless — no spatial fact.
##
## STORY 4-3a (AC 3): THE TARGET WIDENS FROM A BARE SLOT TO A TARGET ADDRESS, `[slot, index]`,
## on the `4-2/R2` pair convention ALREADY SET — `index >= 0` addresses a board unit at that
## index, `index == -1` addresses that slot's hero. That is the exact convention
## `unit_board.gd`'s own target pair uses for what a unit has ACQUIRED, so the contact fact's
## target and a unit's acquired target are now ONE addressing scheme rather than two that
## could drift. Every hero-vs-hero call site passes `[target_slot, -1]` and resolves
## identically to the bare-slot behaviour it replaces.
##
## THE SELF-CONTACT INVARIANT STAYS STRICT, AND AC 6 RIDES ON IT (`4-3a/R21b`): attacker and
## target SLOTS must still differ, so a hero's hitbox overlapping its OWN slot's unit is a
## malformed fact here. That is why the friendly-fire filter sits at GATHER time in the runner
## rather than as a state-side check — a same-slot fact must never reach this seam at all.
##
## STORY 4-3b (AC 3): THE ATTACKER WIDENS TOO, from a bare `attacker_slot: int` to a `[slot, index]`
## pair — the SAME `4-2/R2` convention `4-3a` already spent on the TARGET half, so the fact's two
## addresses are now ONE addressing scheme applied twice rather than two that could drift.
##
## KIND-AGNOSTIC, NOT A HERO/MINION TWO-CASE ENUM. `index == -1` addresses that slot's HERO — every
## existing hero-attacker call site resolves identically under `[slot, -1]` — and `index >= 0`
## addresses a board unit at that index. Totems and hero-cast projectiles are already NAMED future
## users of this exact opening (the Non-Goals), and a two-case shape would need re-widening the
## moment either lands.
##
## THE WIDENING IS SCOPED TO THIS FACT DICTIONARY. THE SIGNALS DO NOT WIDEN (`4-3b/R15`, measured):
## `hit_landed` and `deflect_landed` both carry a typed BARE INT attacker, and both shipped consumers
## UNDERSCORE it and gate solely on the TARGET slot (telegraph_controller.gd) — so a minion damaging
## a hero already flashes and stings the correct hero with no change at all. Widening the payload
## would break two typed callbacks for zero behavioural gain. Pinned in
## test_architecture_invariants.gd.
##
## STORY 4-3b (AC 13, `4-3b/R17b`): THE SIXTH FIELD, `kind`. `_resolve_contacts` treats every queue
## entry as a landed STRIKE, so the REACH PROBE — the fact that tells state a unit's acquired target
## is within reach and may be wound up at — needs a marker or it would deal damage. A probe is
## dropped at the very TOP of the ladder: no damage, no dedupe registration, no `confirmed_hits`
## entry, no mana and no signal. Its ONLY effect is permitting a windup to start.
##
## THE PARAMETER IS REQUIRED, NEVER DEFAULTED, and that is deliberate: a defaulted `kind` would let
## a future probe producer silently omit it and deal damage — precisely the class of silent failure
## AC 14 exists to close on the two attacker-side rungs.
##
## THIS IS STILL ONE INTAKE, WHICH IS WHY IT IS LEGAL UNDER `4-3/R2`. No second public intake method
## ships: the recorder derives its capture channel set from `MatchState`'s public intake surface by a
## source scan (`3-0c` AC 1), so a `push_reach_probe()` sibling would BE a new channel. A parameter
## is not. And no position and no velocity travels inward — state learns a RELATION, exactly as it
## has learned the position-DERIVED `dir` since 1-8.
func push_contact(attacker: Array[int], target: Array[int], attack_index: int,
		target_to_attacker: Vector2, kind: int) -> void:
	Invariant.check(attacker.size() == 2,
		"contact attacker must be a [slot, index] pair, got %d element(s)" % attacker.size())
	var attacker_slot := attacker[0] if attacker.size() == 2 else -1
	var attacker_index := attacker[1] if attacker.size() == 2 else -1
	Invariant.check(attacker_slot == 0 or attacker_slot == 1,
		"contact attacker_slot must be 0 or 1, got %d" % attacker_slot)
	# Story 4-4 (`E4-P/R12`): the attacker index half now has THREE partitions, so the old
	# `>= HERO_INDEX` bound is replaced rather than widened by exception: any index at or above the
	# hero is a hero-or-unit address, and any index at or below `PROJECTILE_INDEX_BASE` is a
	# projectile. Nothing is left in between, so the check still refuses nothing valid and admits
	# nothing meaningless — which is what an address-space bound is for.
	Invariant.check(attacker_index >= TargetingService.HERO_INDEX
			or is_projectile_index(attacker_index),
		("contact attacker index must be >= -1 (a unit or the hero) or <= %d (a projectile), got %d")
				% [PROJECTILE_INDEX_BASE, attacker_index])
	Invariant.check(kind == CONTACT_STRIKE or kind == CONTACT_REACH_PROBE
			or is_charge_reach_kind(kind),
		"contact kind must be CONTACT_STRIKE, CONTACT_REACH_PROBE or a CHARGE-REACH kind, got %d"
				% kind)
	Invariant.check(target.size() == 2,
		"contact target must be a [slot, index] pair, got %d element(s)" % target.size())
	var target_slot := target[0] if target.size() == 2 else -1
	var target_index := target[1] if target.size() == 2 else -1
	Invariant.check(target_slot == 0 or target_slot == 1,
		"contact target slot must be 0 or 1, got %d" % target_slot)
	Invariant.check(target_index >= TargetingService.HERO_INDEX,
		"contact target index must be >= -1 (-1 is the hero), got %d" % target_index)
	Invariant.check(attacker_slot != target_slot,
		"self-contact fact is malformed in 1v1 (attacker == target == %d)" % attacker_slot)
	Invariant.check(not target_to_attacker.is_zero_approx(),
		"contact target_to_attacker direction must be non-zero (no spatial fact)")
	# Story 5-2 (AC 17/AC 20): the CHARGE-REACH kinds LATCH instead of QUEUEING, and the split is
	# seated here -- after every check above, so a charge-reach fact is validated exactly as
	# strictly as a strike -- because the landing check reads at step 3(a) and this queue drains at
	# step 4. See `_charge_reach`'s own comment. The latch is keyed by the ATTACKER slot: the fact
	# describes THAT hero's relation to the enemy hero, and only that hero's chargeup reads it.
	if is_charge_reach_kind(kind):
		_charge_reach_dirs[attacker_slot] = target_to_attacker
		# STORY 6-1d (AC 4/AC 5/AC 6): THE LATCH STOPS BEING "THE LAST ANSWER" AND BECOMES "THE
		# FLIGHT'S VERDICT", and both halves of that are written here rather than at the landing.
		#
		# OUTSIDE THE CONTACT WINDOW THE LATCH IS CLEARED, not written (AC 4). The runner keeps
		# pushing every chargeup tick because the FACING TRACK needs the direction above, but a
		# chargeup touch must credit nothing -- damage is the LANDING's verdict alone, and the
		# chargeup window runs before the launch has even started (`6-9`: the press commits the
		# attack, but the commit is what STARTS the flight, not what lands it).
		# `register_swing_hit`'s dictionary record is not adopted here at all, and this
		# store cannot grow: it is a fixed TWO-element `Array[int]`, one slot per hero, for the life
		# of the match.
		#
		# THE REAPING BETWEEN ATTACKS IS OWNED, NOT EMERGENT (`6-1d/R9`). The dev pass relied on this
		# clearing arm alone to reset the verdict before each commit, which silently required at least
		# one pre-commit push -- a one-tick chargeup has none, and a stale absorbing `INSIDE` from the
		# previous attack then credited a flight in which nothing was measured. The verdict and its
		# bearing are now cleared at the CAST SEAT (`_resolve_unblockable_cast`) and in
		# `_reset_player`; this arm still clears too, and that is what keeps chargeup touches out.
		#
		# INSIDE THE WINDOW `INSIDE` IS ABSORBING (AC 6's supersession of `6-1c` AC 3). Contact is
		# evaluated on every committed tick, and a defender touched on ANY of them is hit even if it
		# has cleared the blade by the landing tick. The surviving half is structural: a defender
		# clear on EVERY evaluated tick never writes `INSIDE`, so it still misses.
		#
		# EXACTLY ONE RESOLUTION PER SWING (AC 5) IS A CONSEQUENCE OF THE TYPE, not of a counter: N
		# ticks of contact collapse into ONE latched int, and `_resolve_charge_landing` still fires
		# exactly once, on the tick `landing_window` closes. There is no second landing check to
		# dedupe against. In 1v1 the melee `[attack_index, target]` key degenerates to the attacker
		# slot alone -- mode ② has exactly one possible target (the enemy hero, minions are neither
		# targets nor obstacles) and a chargeup never calls `_start_swing`, so `attack_index` does
		# not move across a chargeup and would key nothing.
		var charging: PlayerState = p1 if attacker_slot == 0 else p2
		# THE BEARING IS LATCHED IN THE ARM THAT LATCHES `INSIDE`, and only there (`6-1d/R8`). The
		# landing's arc is judged against the direction of the push that recorded the contact, not
		# against the last push's. An `OUTSIDE` after an `INSIDE` writes neither half.
		#
		# AN IN-ARC CONTACT IS ABSORBING (`6-1d/R13`). Neither "first contact" nor "last contact" is
		# the rule: if ANY contact tick of the committed flight had a bearing inside the colour's arc,
		# the landing is a HIT. So an `INSIDE` push re-latches both halves UNLESS the verdict is
		# already `INSIDE` and the bearing already latched passes `_is_in_charge_arc` -- a later
		# out-of-arc touch never overwrites an earlier in-arc one, while an out-of-arc latch is still
		# replaced by any later touch. The arc still only REMOVES a hit: a flight whose contacts were
		# ALL out of arc latches an out-of-arc bearing and misses at the landing.
		#
		# THE ARC IS ONLY EVER ASKED OF THE BEARING ALREADY LATCHED, NEVER OF THE PUSH BEING LATCHED,
		# and that ordering is what keeps the COMMIT TICK correct. The commit tick's push is the first
		# inside the contact window, and it arrives BEFORE that tick's `advance()` -- before the step-2
		# `charge_window.tick()` closes the chargeup, i.e. before the tick that freezes the facing for
		# the flight has run. Nothing is latched on it (the cast seat, and the clearing arm on any
		# pre-commit push, left `REACH_UNKNOWN`, `6-1d/R9`), so it simply latches and no arc is
		# evaluated against a facing the rule has not yet seen frozen. (Measured: step 2 stops the
		# chargeup before `_resolve_movement`, so the commit tick's own push does not re-aim the
		# facing either -- but the rule does not depend on that detail.) Every later push in the
		# window arrives after the freeze (`6-1c`), so "does the latched bearing already pass" is asked
		# against exactly the facing the landing's `_is_in_charge_arc` will read.
		if not charging.is_contact_window_open():
			_charge_reach[attacker_slot] = REACH_UNKNOWN
			_charge_contact_dirs[attacker_slot] = Vector2.ZERO
		elif kind == CONTACT_CHARGE_REACH_INSIDE:
			if not (_charge_reach[attacker_slot] == CONTACT_CHARGE_REACH_INSIDE
					and _is_in_charge_arc(charging, attacker_slot)):
				_charge_reach[attacker_slot] = kind
				_charge_contact_dirs[attacker_slot] = target_to_attacker
		elif _charge_reach[attacker_slot] != CONTACT_CHARGE_REACH_INSIDE:
			_charge_reach[attacker_slot] = kind
		return
	_contact_queue.append({
		"attacker": attacker_slot,
		"attacker_index": attacker_index,
		"target": target_slot,
		"target_index": target_index,
		"attack_index": attack_index,
		"dir": target_to_attacker,
		"kind": kind,
	})


## Runner step-2 push (story 1-2). slot: 0 = P1, 1 = P2 — out-of-range is a programming
## error (fixed-size fact; the array index asserts). State never reads the camera; it only
## receives this pushed value.
##
## LOAD-BEARING (DECISION A): while the camera is fixed (all of E1) the hero ROOT must
## never be rotated — body/facing rotation belongs on a child mesh node. The rig is a
## child of the hero root, so a rotated root would fold hero rotation into this pushed
## basis and break camera-relative "forward" (and the identity short-circuit in
## _resolve_movement). The runner therefore pushes the rig's LOCAL basis, guarded by
## test_root_rotation_isolation.gd; a story that needs a rotating root must decouple the
## rig from hero rotation deliberately (deferred DECISION B).
func set_camera_basis(slot: int, camera_basis: Basis) -> void:
	_camera_bases[slot] = camera_basis


## Runner step-2 push (story 4-6, AC 2, `4-6/R6`). The WORLD-SPACE PLANAR direction from this
## slot's hero to its locked target, gathered by the runner from the two actor positions it
## already owns -- the `_gather_contact_facts` `target_to_attacker` computation verbatim, one
## level up. slot: 0 = P1, 1 = P2; the array index asserts on anything else.
##
## STATE NEVER QUERIES THE SCENE (D3(b)/A2). This is the confirmed mechanism `4-6/R6` names: a
## pushed per-tick fact through the `set_camera_basis` / `push_contact` seam family, never a live
## camera or node read from inside `src/state/`. `_is_facing` has consumed a runner-gathered
## direction this exact way since 1-8, so this adds no new KIND of channel.
##
## Vector2.ZERO means NO FACT (a co-located target, or an address whose actor the runner has not
## spawned): facing is left at its last value rather than snapped to a garbage heading.
func set_lock_direction(slot: int, direction: Vector2) -> void:
	_lock_directions[slot] = direction


## Runner step-2 push (story 6-5b, AC 18, `6-5b/R6`). The BOARD INDEX of the own living minion this
## slot's hero is facing most directly -- smallest angle between hero facing and the hero-to-minion
## direction, ties broken by smaller distance then lower index -- resolved by the runner from the
## actor positions it already owns. slot: 0 = P1, 1 = P2; the array index asserts on anything else.
##
## STATE NEVER QUERIES THE SCENE (D3(b)/A2), and it never re-runs the selection either. This is the
## `set_lock_direction` seam family's fourth member and its shape verbatim: a pushed per-tick fact,
## captured by its own record channel, consumed inside `advance()` by exactly one seat
## (`_apply_drain`).
##
## NOT NAMED `drain_*` (story Dev Notes, a real hazard rather than a style note):
## `test_intent_recorder.gd` pins `EXEMPT_CARRIES_NO_DATA_INWARD := "drain_signals"` by EXACT STRING
## against this class's public surface, and a sibling called `drain_target(...)` would leave a reader
## unable to tell an exemption from an intake by name. `push_*` is also the truthful prefix: this
## carries data INWARD and has a capture channel, which `drain_signals` does not.
##
## `NO_DRAIN_TARGET` IS A LEGAL PUSH, not an error: the runner sends it on a tick where the caster has
## no living minion in front of it, which is the honest answer and the resting value.
func push_drain_target(slot: int, index: int) -> void:
	_drain_targets[slot] = index


## Emit all queued signals. Called by the runner AFTER advance() returns (D5).
func drain_signals() -> void:
	_queue.drain()


## Story 6-6a review (D2): true only while a BLOCKED hit's `hit_landed` is being emitted -- see
## `_hit_landed_blocked`. A `hit_landed` consumer calls this from inside its handler.
func hit_landed_was_blocked() -> bool:
	return _hit_landed_blocked


## Story 6-6a review (D2): the step-4 hero-contact `hit_landed`, emitted with `_hit_landed_blocked` raised
## for exactly its own duration. The signal and its four-argument payload are unchanged.
func _emit_hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float,
		blocked: bool) -> void:
	_hit_landed_blocked = blocked
	hit_landed.emit(attacker_slot, target_slot, damage, target_hp)
	_hit_landed_blocked = false


func to_snapshot() -> Dictionary:
	return {
		"tick": _tick,
		"rng_state": _rng.state,   # captured so the determinism hash catches RNG desync
		"round_over": _round_over,
		"p1": p1.to_snapshot(),
		"p2": p2.to_snapshot(),
		"pitch": pitch.to_snapshot(),
	}


## Story 3-0b (AC 2): READ-ONLY DEBUG accessor — per slot, the remaining ticks of the action
## windows that are currently RUNNING, as COMPUTED PLAIN INTEGERS derived from
## TimingWindow.remaining_ticks(). Slot order is fixed [P1, P2]; window order within a slot is
## HeroState's declaration order. A window that is not running is ABSENT (the AC's "active
## windows"), so the payload is small — at most two or three entries per slot in practice.
##
## This is DEBUG INSTRUMENTATION, NOT an eighth observation seam: the runner POLLS it after
## advance() and pushes the plain payload into DebugInstrumentPanel. No signal, no state handle,
## no mutator — presentation receives VALUES, never internals, the same discipline the observation
## seams already follow (the standing "hands the state layer's internals to presentation"
## objection is answered by the return type: ints keyed by name). to_snapshot() is deliberately
## NOT extended, so the replay contract never learns this instrument exists.
func debug_window_ticks_remaining() -> Array[Dictionary]:
	return [_running_window_ticks(p1.hero), _running_window_ticks(p2.hero)]


## The per-hero half of debug_window_ticks_remaining(). The TimingWindow objects are read and
## discarded INSIDE this function — only ints leave it.
static func _running_window_ticks(hero: HeroState) -> Dictionary:
	var out: Dictionary = {}
	var windows: Array = [
		[&"windup", hero.windup],
		[&"active", hero.active],
		[&"recovery", hero.recovery],
		[&"chain", hero.chain],
		[&"deflect", hero.deflect],
		[&"iframe", hero.roll_iframe],
		[&"roll", hero.roll_duration],
		[&"stun", hero.stun],
	]
	for entry: Array in windows:
		var window: TimingWindow = entry[1]
		if window.is_running:
			out[entry[0]] = window.remaining_ticks()
	return out


## Step-3 transition evaluation (story 1-3). EVALUATES HeroState.TRANSITION_TABLE — the
## table data lives on HeroState next to the enum; this is only the evaluator. Durations
## are read from balance_ticks.<field> inline at the moment a transition fires and passed
## into the window's start() (CONSTRAINT C: never cache the BalanceTicks object — a
## running window keeps its old duration across a reload; the next start() picks up the
## new one, guarded by test_balance_config.gd).
func _resolve_actions(player: PlayerState, intent: InputIntent, slot: int) -> void:
	# DEBT A deferral (story 1-3, deliberate): the runner never calls apply_balance() yet,
	# so in live play balance_ticks is null and actions are INERT until the follow-up
	# story wires apply_balance at match start + re-baselines the golden (both DEBT A
	# halves together). This is THE one guard — no scattered null checks below it.
	if balance_ticks == null:
		return
	var hero := player.hero
	# (a) Timer-driven progression/exits — windows were advanced in step 2; read results.
	match hero.action_state:
		HeroState.ActionState.ATTACKING:
			match hero.attack_phase():
				&"windup_done":
					hero.active.start(balance_ticks.attack_active_ticks)
				&"active_done":
					hero.recovery.start(balance_ticks.attack_recovery_ticks)
					hero.chain.start(balance_ticks.attack_chain_window_ticks)
				&"attack_done":
					hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.ROLLING:
			if not hero.roll_duration.is_running:
				hero.set_action_state(HeroState.ActionState.IDLE)
		# Story 5-6 (AC 12): THE STUN'S ONLY EXIT, on the `ROLLING` arm directly above's exact shape.
		# Without this arm a stunned hero would never leave `STUNNED` at all — `stun` would tick to
		# zero and stay there forever, because nothing else in this function reads it and this `match`
		# has no default arm.
		#
		# NATURAL EXPIRY ONLY (Ruling 3, reasserting the `1-9` precedent): nothing this story adds cuts
		# a running `stun` window short anywhere, exactly as `ROLLING`'s arm gives `roll_duration` and
		# `CHARGING`'s gives `charge_window`. The debug reset's fifth exception (AC 13) is a RESET, not
		# an early stop — it clears the window and the state together, outside normal play.
		#
		# STORY 6-6a (AC 8/AC 9): THE GET-UP. This timer exit -- and ONLY this one; the debug reset writes
		# the same `STUNNED -> IDLE` from `_reset_player` and arms nothing -- opens the get-up iframes when
		# the stun that just ran out was a KNOCKDOWN, told apart by the window's own snapshotted duration
		# (`BalanceTicks.is_knockdown_stun`, no stored reason field). Presentation plays `get_up` off the
		# SAME fact: the window this line starts is what the runner forwards.
		HeroState.ActionState.STUNNED:
			if not hero.stun.is_running:
				hero.set_action_state(HeroState.ActionState.IDLE)
				# Story 6-6a review (D1): `_gets_up_this_tick` restates this arming condition for the
				# step-3 dodge latch, which is taken BEFORE this arm runs. Keep the two in step.
				if balance_ticks.is_knockdown_stun(hero.stun.duration_ticks()):
					hero.get_up_iframe.start(balance_ticks.get_up_iframe_ticks)
		HeroState.ActionState.BLOCKING:
			if not intent.is_held(&"block"):
				hero.set_action_state(HeroState.ActionState.IDLE)
		# Story 5-2 (AC 20, `5-2/R3`): the CHARGEUP TIMER EXIT, and the landing check rides it. This
		# is the seat AC 20 names, and the two halves are ONE arm on purpose: the exit and the
		# landing must resolve on the SAME tick, and reading the reach fact here (a latch written
		# before advance() -- `_charge_reach`) rather than through the step-4 contact queue is what
		# makes that possible. State never pulls from the runner mid-advance(); the fact is already
		# present or it is `REACH_UNKNOWN`.
		#
		# A DEAD HERO CANNOT REACH THIS ARM (AC 15), and the guard is the `match` itself rather than
		# a test inside it: death writes `action_state = DEAD` at step 8, so a corpse's row is
		# `dead`, this arm is not evaluated, and nothing returns it to IDLE. That is the strongest
		# form of the F3 finding's answer -- the corpse-resurrecting branch is not written, not
		# merely guarded -- and it is the same structural argument the `ROLLING` arm above relies on.
		# STORY 6-9 (AC 1, 2, 6): THE PRESS COMMITS, AND THIS ARM READS NO INTENT AT ALL. Mode 2 is
		# click-to-commit: the card and the stamina are spent on the press inside
		# `_resolve_unblockable_cast`, and the attack carries to its landing with no further input
		# from that player. Story `6-1`'s early-release `elif` -- a `card_cast` held key going false
		# while the chargeup window still ran, the paid feint -- IS DELETED, and with it the only
		# intent read this seat ever had. There is nothing to hold and nothing to cancel.
		#
		# THE FOUR EXITS FROM `CHARGING` ARE ALL NON-INPUT, which is what makes "a press commits"
		# structural rather than asserted: the landing below, the colour counter judging it (`6-6b`,
		# the branch above), a knockdown abandoning it (`6-6a/R1`, `:3776-3778`) and death / the
		# debug reset (`_reset_player`). No branch here tests a key, so no key can add a fifth.
		#
		# THE TELEGRAPH FACT RESTS AGAIN AT THE LANDING (AC 5) WITHOUT ANY CLEAR BEING WRITTEN HERE.
		# `PlayerState.to_snapshot`'s `telegraph` is DERIVED under an `action_state == CHARGING`
		# gate, and `_resolve_charge_landing` writes `IDLE` / `STUNNED` synchronously, so the gate
		# hides the colour by construction. The three explicit three-part teardowns that remain --
		# the knockdown abandonment, the colour-counter teardown and `_reset_player` -- are all
		# non-input edges; the one that hung off the release edge left with the `elif`.
		#
		# THE CARD AND THE STAMINA STAY SPENT (AC 3). Nothing on any path through this arm refunds,
		# un-discards or credits: the spend ran an entire chargeup ago, and the only question left
		# open at the commit is which verdict the landing or the counter returns.
		#
		# STORY 6-1c (AC 2/AC 4): THE LANDING RIDES THE LANDING WINDOW, AND THE CHARGEUP'S CLOSE IS
		# THE COMMIT. The arm reads two windows that started together at the cast (see
		# `PlayerState.landing_window`): the landing fires when the LANDING window stops. Between the
		# two -- chargeup closed, landing window running -- the hero is IN FLIGHT and this arm does
		# nothing at all, so `_resolve_movement` carries the launch. That middle phase is the whole
		# of the commit; it needs no branch of its own, and no flag.
		# STORY 6-6b (AC 3): THE COLOUR COUNTER IS JUDGED HERE, FIRST, INSIDE THIS SAME ARM. The
		# attacker's own CHARGING seat is where the counter resolves, because the counter's whole
		# subject is THIS attack: the commit tick and every launch tick before the first honest
		# contact are exactly the ticks this arm runs with the chargeup window closed.
		#
		# BEFORE THE LANDING, AND THE ORDER IS THE AC. `_resolve_charge_landing` is this arm's first
		# branch, so a counter and a landing that fall on the same tick -- which is every tick when a
		# colour authors no launch span at all -- resolve as a COUNTER. The counter tears the attack
		# down and writes `STUNNED`, so returning here is what keeps "exactly one `set_action_state`
		# per outcome" (the `5-6` rule) true: the landing's trailing `IDLE` is never reached.
		#
		# IT IS NOT GATED ON THE LANDING WINDOW, deliberately: the judged span runs from the commit
		# THROUGH the landing tick (on which `landing_window` has already stopped), and the
		# `_resolve_color_counter` gate below reads the chargeup's close instead -- the one fact that
		# says "committed".
		HeroState.ActionState.CHARGING:
			if _resolve_color_counter(player, slot):
				return
			if not player.landing_window.is_running:
				_resolve_charge_landing(player, slot)
	# STORY 6-6a POST-SMOKE RULING `6-6a/R7`: THE GET-UP IS A LOCKED ACTION. The live
	# smoke found the hero able to act the instant `get_up` starts -- attack, roll, card, block all
	# available while the AC 8 iframes still ran -- which reads as "teleport to your feet" and, with the
	# window covering unblockables too, made the get-up a free 2 s of invulnerable offence (review
	# finding D3). The window is now a LOCK as well as a shield.
	#
	# IT SITS BETWEEN (a) AND (b), WHICH IS THE WHOLE OF ITS SCOPE: the timer arms above still run (this
	# is where the window itself is opened, one tick before anything could read it), and only the
	# INPUT-DRIVEN edges below are refused. Attack, roll and block therefore drop SILENTLY, which is not
	# a new contract but the one `STUNNED` already has -- its table row carries no edges, so a press on a
	# downed hero is dropped with no `action_rejected` either. The card seat (`_resolve_card_action`,
	# step 6) DOES announce, for the same reason it announces for `STUNNED`: that path refuses by an
	# explicit gate with a reason token, not by an empty row.
	#
	# A HELD BLOCK IS NOT BUFFERED. `block` is an `is_pressed` edge, so a hold carried through the
	# get-up produces no `BLOCKING` when the window empties; re-pressing engages it. That is the
	# existing hold semantics unchanged (`3-0b/R23`/`R24` untouched), not a new rule about block.
	#
	# THE AC 8 I-FRAMES THEMSELVES ARE UNTOUCHED: same window, same duration, still registered in
	# `is_iframe_open()`, still covering unblockables (R-IFRAME-UNBLOCKABLE), and `_gets_up_this_tick`
	# (the D1 latch) still reads its own arming condition at step 3. The two compose: the latch defers
	# the ATTACKER's landing package on the exit tick, this lock refuses the VICTIM's own presses.
	if hero.is_getting_up():
		return
	# STORY 6-6b (AC 2): THE COUNTER BUSY LOCK -- the step-3 half. A hero whose counter window is
	# running is mid-counter and takes no input: attack, roll and block all drop here, exactly as they
	# do for a hero getting up and for a `STUNNED` one.
	#
	# SEATED BESIDE THE GET-UP LOCK, AND BELOW THE TIMER ARMS ABOVE, which is the whole of its scope
	# and is what AC 1's "a swing or roll in progress still finishes on its own contract" requires: a
	# hero that cast DEFENSE mid-swing keeps its `ATTACKING` arm, its windows and its phase machine,
	# and only its NEW presses are refused.
	#
	# IT DROPS SILENTLY, the get-up lock's own register and for its reason: a table row that refuses
	# has never emitted `action_rejected`, and `STUNNED`'s empty row is the precedent. The CARD seat
	# (`_resolve_card_action`, step 6) announces instead, with `REASON_COUNTERING`.
	#
	# BUSY IS DERIVED FROM THE WINDOW AND NOTHING ELSE -- no new `ActionState`, which is what keeps
	# `test_unblockable_defense.gd::test_the_cast_introduces_no_action_state_of_its_own` green
	# unedited (`6-6a`'s `is_getting_up()` precedent, applied a second time).
	if player.defense_window.is_running:
		return
	# (b) Input-driven edges from the current table row. A press with no entry in the row
	# is dropped, never buffered (AC 5). Fixed INPUT_PRIORITY order = deterministic
	# same-tick tiebreak; at most one transition fires per tick.
	var row := hero.transition_row()
	if not HeroState.TRANSITION_TABLE.has(row):
		return
	var edges: Dictionary = HeroState.TRANSITION_TABLE[row]
	for action: StringName in HeroState.INPUT_PRIORITY:
		if intent.is_pressed(action) and edges.has(action) \
				and _try_transition(player, edges[action], intent, slot):
			return


## Fire one table edge. Returns false when a gated edge rejects — the chain cap (silent,
## story 1-3) or the roll stamina precondition (emits action_rejected, story 1-4) — so a
## lower-priority same-tick press may still be considered.
## intent/slot ride along for the ROLLING edge only (story 1-9): the entry-time roll
## direction is captured from the SAME press that fires the transition.
func _try_transition(player: PlayerState, target: HeroState.ActionState, intent: InputIntent,
		slot: int) -> bool:
	var hero := player.hero
	match target:
		HeroState.ActionState.ATTACKING:
			var chaining := hero.action_state == HeroState.ActionState.ATTACKING
			if chaining:
				# Chain edge: only inside the chain window and below the authored cap.
				# attack_chain_length is a COUNT, not a duration — it lives on balance,
				# not balance_ticks; read inline under the same no-caching rule.
				# FIRST, before the stamina seat below: a capped press is not an attempt
				# to attack, so it must not be charged (and stays SILENT, story 1-3).
				if not hero.chain.is_running or hero.chain_index + 1 >= balance.attack_chain_length:
					return false
			# The THIRD step-3 policy seat of the deduction MECHANISM (stamina-cost
			# corrective pass, E3-RG/R2; decision (d) RESOLVED at DP/R2 — the basic attack
			# costs stamina as an ANTI-SPAM lever, the 1-5 mana faucet is untouched).
			# Follows the ROLL precedent exactly, not deflect's: charged AT ENTRY per swing
			# (chain included), and unaffordable = the 1-4 FALLTHROUGH, never deflect's
			# degrade — there is no degraded attack to fall back to. Cost and delay read
			# inline (CONSTRAINT C). Nothing above this line mutated hero state, so a
			# rejected attack costs nothing, enters no state, and leaves chain_index alone.
			if not player.stamina.spend(
					balance.attack_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"attack", &"insufficient_stamina")
				return false
			if chaining:
				hero.chain_attack(balance_ticks.attack_windup_ticks)
			else:
				hero.enter_attack(balance_ticks.attack_windup_ticks)
		HeroState.ActionState.ROLLING:
			# A step-3 policy seat of the single deduction MECHANISM (StaminaPool.spend,
			# D4/story 1-4; R-D1 reconciliation). No longer the ONLY one: the basic attack
			# gained a cost in the E3-RG/R2 corrective pass and shares this seat's shape
			# (see the ATTACKING case above). BLOCKING entry stays free (block costs TIME
			# via the D6 regen suppression).
			# Deflect's policy seat is step 4 — spend at deflect LANDING, never at entry
			# (story 1-8, R-D1). Cost and delay are read inline at the moment of the
			# transition (CONSTRAINT C). Insufficient stamina is a PRECONDITION (D5): the
			# edge rejects and falls through per INPUT_PRIORITY, and the queued
			# action_rejected keeps the loss legible even if a lower-priority press fires.
			if not player.stamina.spend(
					balance.roll_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"roll", &"insufficient_stamina")
				return false
			# Story 6-5a (R2): BLOODHOUND STEP IS CONSUMED HERE, and only here -- BELOW the stamina
			# refusal, so a roll refused for stamina leaves the armed trigger untouched for the next
			# attempt. The boosted roll keeps its duration; its distance multiplier rides a ROLL_BOOST
			# rule that runs exactly as long as the roll (read by `_resolve_movement`), and its i-frames
			# are multiplied and then CLAMPED to the roll's duration, so the `1-9/R3` audit's
			# i-frames <= roll invariant holds for the boosted roll too (min(2 x 18, 30) = 30).
			var iframe_ticks := balance_ticks.roll_iframe_ticks
			if player.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED):
				iframe_ticks = mini(int(round(float(iframe_ticks)
						* player.rule_b[PlayerState.RULE_BLOODHOUND_ARMED])),
						balance_ticks.roll_duration_ticks)
				player.start_rule(PlayerState.RULE_ROLL_BOOST, balance_ticks.roll_duration_ticks,
						player.rule_a[PlayerState.RULE_BLOODHOUND_ARMED], 0.0)
				player.cancel_rule(PlayerState.RULE_BLOODHOUND_ARMED)
			else:
				player.cancel_rule(PlayerState.RULE_ROLL_BOOST)
			hero.enter_roll(balance_ticks.roll_duration_ticks, iframe_ticks,
					_roll_world_direction(hero, intent.move_dir, slot))
		HeroState.ActionState.BLOCKING:
			# Story 1-8 (R-D1): affordability PRECONDITION only — no spend, no regen-delay
			# restart at entry; the spend happens at deflect LANDING (step 4). Unaffordable
			# = DEGRADE, not the 1-4 fallthrough: the block edge still fires as a plain
			# block, only the window is denied, and the queued rejection names "deflect"
			# because that is the thing denied. Cost read inline (CONSTRAINT C).
			var can_deflect := player.stamina.get_current() >= balance.deflect_stamina_cost
			hero.enter_block(balance_ticks.deflect_window_ticks, can_deflect)
			if not can_deflect:
				hero.reject_action(&"deflect", &"insufficient_stamina")
	return true


## Story 4-3b (AC 1/AC 12/AC 13): ONE PLAYER'S BOARD, advanced one tick through the unit attack
## rhythm. The step-3 unit seat.
##
## THE PHASE LADDER IS windup -> active -> recovery -> idle, WITH NO OTHER EDGES. There is no chain
## (a unit has one attack, Non-Goals), no input edge (nothing presses anything), no stamina or
## resource gate (AC 11 — the rhythm itself is the only limiter), no stun edge (AC 10 — the `stun`
## field keeps ZERO inbound edges and this story does not open one), and NO CANCEL: a swing whose
## target dies or is retargeted mid-windup COMPLETES INTO EMPTY AIR (`4-3b/R18`), because a cancel
## would be a second way a swing can end, against the no-interruption Non-Goal. Damage taken
## mid-swing does not interrupt it either; only DEATH ends the attacker, and that is AC 15's rung in
## the contact ladder rather than an edge here.
##
## THE BOUNDARY IS "THE COUNTDOWN STEP 2 JUST ADVANCED REACHED ZERO", which is the hero's
## `attack_phase()` -> `&"windup_done"` shape expressed against a stored int instead of three
## `TimingWindow` objects (per-record objects are what `unit_board.gd`'s header rule forbids).
##
## WHY RECOVERY -> IDLE AND THE NEXT WINDUP HAPPEN IN THE SAME PASS. AC 13 pins the back-to-back
## cycle at EXACTLY windup + active + recovery ticks with NO throttle remainder added. A unit whose
## in-reach flag is set must therefore begin its next windup on the very tick recovery ends, not on
## the next tick and certainly not at the next probe — so the idle test below runs after the ladder,
## against the phase this same pass may have just written. That is the whole reason the flag is a
## STORED cross-tick carrier rather than a per-tick observation.
##
## WHAT MAY BEGIN A WINDUP, exactly (AC 13, `4-3b/R17a`): the unit is ALIVE, it is IDLE, and its
## IN-REACH FLAG IS SET. Never a free-running cycle, never an "arrived" flag, and never a distance
## this layer computes — position is actor-owned (`4-3/R2`) and this layer has none. The flag is set
## only by the step-4 seat below, from a fact the runner pushed.
##
## A DEAD UNIT IS SKIPPED ENTIRELY, phases frozen where they stood. Nothing gathers a corpse's
## hitbox — CORRECTED BY STORY 4-3d, which changed the reason without changing the fact: the
## runner no longer frees a corpse's actor the same tick, it LINGERS for 10 s, so the hitbox is
## inert because 4-3d's AC 4 disables the actor's collision nodes, not because the actor is gone.
## Nothing may start a corpse swinging either, so
## advancing its ladder would be state kept for no reader — and `is_alive_at` is the board's own
## liveness predicate, never a re-derived `hp > 0` (`4-3a/R14`).
##
## STORY 4-4 (AC 6/AC 9/AC 10): THE DURATIONS ARE PER-KIND NOW. The three flat
## `balance_ticks.minion_attack_*_ticks` fields this seat used to read are gone; each unit's phase
## lengths come from ITS OWN kind's attack record, resolved through the record's kind index and read
## INLINE at the moment of use (CONSTRAINT C).
##
## A KIND THAT AUTHORS NO ATTACK NEVER ENTERS THE LADDER AT ALL (AC 3: "the accelerators never
## attack"), and that is an AUTHORING fact rather than a code branch over kind names: the two
## accelerator totems author an empty `attacks` list, `attack_ticks` resolves to null, and the unit
## is skipped. It cannot wind up, cannot open a hitbox and cannot fire.
##
## A UNIT MID-SWING WHEN ITS KIND STOPS RESOLVING (an X3 reload that shortened `unit_kinds`) is
## skipped too, which FREEZES it in its current phase rather than advancing it with invented
## durations. That is the honest degradation: the phase countdown has already been ticked by step 2,
## so the unit simply stops progressing rather than snapping to a phase no authored record describes.
func _advance_unit_attacks(player: PlayerState) -> void:
	if balance_ticks == null:
		return
	var board := player.units
	for index in board.size():
		if not board.is_alive_at(index):
			continue
		var kind_index := board.kind_index_at(index)
		var kind_ticks := balance_ticks.kind_ticks_at(kind_index)
		if kind_ticks == null:
			continue
		var attack_ticks := kind_ticks.attack_at(0)
		if attack_ticks == null:
			continue
		# Story 4-4 (AC 14): the AUTHORED record beside its derived tick record. Both are read
		# INLINE at the point of use (CONSTRAINT C) and through the SAME index, which is what keeps
		# `UnitKindTicks`'s index-alignment contract a single fact rather than two lookups that could
		# disagree. Null here means the same thing null means above — this kind does not attack.
		var kind := balance.kind_at(kind_index) if balance != null else null
		var attack := kind.attack_at(0) if kind != null else null
		if attack == null:
			continue
		if board.attack_phase_at(index) != UnitBoard.AttackPhase.IDLE \
				and board.attack_ticks_at(index) == 0:
			match board.attack_phase_at(index):
				UnitBoard.AttackPhase.WINDUP:
					# The ACTIVE window opens, and the dedupe record for THIS swing opens with it —
					# the `HeroState` pairing of "a live record exists exactly while the swing can
					# still land" expressed for a unit. Keyed by the counter `begin_windup_at`
					# returned, re-read here from the board so the two can never disagree.
					board.set_phase_at(index, UnitBoard.AttackPhase.ACTIVE,
							attack_ticks.active_ticks)
					player.unit_dedupe.open(index, board.attack_count_at(index))
					# Story 4-4 (AC 14): THE LAUNCH SEAT. An attack whose record authors a projectile
					# fires ONE at the windup-to-active transition — the same moment a melee attack's
					# hitbox opens, so "the swing lands here" is one moment for both kinds of attack
					# rather than two that could drift.
					#
					# THE DEDUPE RECORD IS STILL OPENED ABOVE, and deliberately so even though a
					# projectile attack's hitbox never gathers (`_gather_unit_facts` skips it). The
					# record is opened by the PHASE, not by the weapon; making it conditional would
					# put a second is-this-a-projectile test in the one place the phase ladder is
					# supposed to be uniform, to save a record nothing ever registers into.
					#
					# A PROJECTILE IS LAUNCHED EVEN WITH NO ACQUIRED TARGET. It carries the
					# no-target pair, finds no position to home on and flies straight until its
					# budget expires — which is the honest behaviour, and it is unreachable in
					# shipped play anyway: the windup that led here could only begin because a reach
					# probe reported the ACQUIRED target in range.
					if attack.projectile != null:
						player.projectiles.add(board.target_slot_at(index),
								board.target_index_at(index), board.kind_index_at(index), index)
				UnitBoard.AttackPhase.ACTIVE:
					# The window closes and the record enters its single GRACE tick, absorbing the F1
					# one-tick fact lag exactly as the hero's does: a contact gathered on the last
					# active tick arrives the tick after close and is still legitimate.
					board.set_phase_at(index, UnitBoard.AttackPhase.RECOVERY,
							attack_ticks.recovery_ticks)
					player.unit_dedupe.close(index)
				UnitBoard.AttackPhase.RECOVERY:
					board.set_phase_at(index, UnitBoard.AttackPhase.IDLE, 0)
		# Story 4-4 (AC 10/AC 13): THE CADENCE GATE joins the two conditions that were already here,
		# as a third AND rather than as a branch — a unit may begin its next attack only once its
		# firing cooldown has expired. `is_attack_ready_at` is the board's own public predicate and
		# nothing here re-derives `attack_cooldown_at(i) == 0` inline (the `has_index` /
		# `is_alive_at` discipline: a guard consulting a copy is guarding the copy).
		#
		# AC 13's HOLD-FIRE FALLS OUT OF THE IN-REACH CONDITION ALREADY PRESENT, and needs no rung
		# of its own — which is exactly `4-4/R10`'s "post-selection gate" rather than a distance
		# based re-selection. The unit has ALREADY acquired its target by its authored priority
		# (step 7); the reach probe measures that acquired target against this kind's authored
		# `range` and only then sets the flag. A target held beyond range never sets it, so the
		# totem never winds up, "regardless of how long it remains in that state" — there is no
		# timeout path and no re-selection by distance anywhere in this file.
		#
		# ...AND THAT ARGUMENT WAS HALF TRUE, WHICH IS WHY `4-4/R14` EXISTS. "A target held beyond
		# range never sets it" covers a target that was NEVER in range; it did not cover a target
		# that was in range once and then LEFT. The cadence AND directly above is what made the
		# difference matter: before this story the gate was consumed on the next IDLE tick, and now
		# a confirmation can sit unconsumed for a whole cooldown while the target walks away. The
		# fix is in `UnitBoard._in_reach_ticks` — `is_in_reach_at` now means "confirmed RECENTLY"
		# rather than "confirmed ever", on a window derived from the probe cadence. This condition
		# is unchanged; what it reads has a shelf life.
		#
		# THE SHIPPED MINION IS UNMOVED BY THE NEW CONDITION: it authors a 0.0 cadence, so its
		# cooldown is 0 on the tick recovery ends and the third AND is already true.
		if board.attack_phase_at(index) == UnitBoard.AttackPhase.IDLE \
				and board.is_in_reach_at(index) \
				and board.is_attack_ready_at(index):
			# CONSUMES the flag (inside `begin_windup_at`), which is its ONLY clearing path — there
			# is no negative probe and absence of overlap is not a fact (AC 13's consequence (ii)).
			# The locked direction needs no write here: it already holds the latest known heading to
			# the acquired target, refreshed by the step-4 seat only while IDLE, and from this
			# moment nothing writes it again until the swing ends. THAT FREEZE IS THE LOCK (AC 12).
			board.begin_windup_at(index, attack_ticks.windup_ticks, attack_ticks.cadence_ticks)


## Story 4-4 (AC 15/AC 19): advance every LIVE projectile on one player's board by one tick — the
## acceleration clock and the travel odometer, and nothing else.
##
## THE SPEED IS DERIVED, NEVER STORED (see `projectile_board.gd`'s header): the record holds the
## firing kind's INDEX, and every authored number is read through it INLINE on every tick
## (CONSTRAINT C). That is what lets a shot outlive the totem that fired it without carrying five
## stale copies of authored data, and what makes an X3 retune take effect on shots already in the
## air rather than only on the next one.
##
## THE RUNNER MOVES THE ACTOR BY THE DISTANCE THIS SEAT CHARGED, through
## `projectile_step_distance_at()` below — and that claim USED TO BE FALSE, which is review finding
## H2. The runner called `projectile_speed_at(board, index)` AFTER `advance()` returned, and
## `advance_at` had already incremented the flight clock by then; since the speed is a pure function
## of that clock, the actor was permanently ONE TICK AHEAD on the acceleration curve relative to the
## budget it was being charged against. Not a determinism defect (position is actor-owned and never
## hashed), but AC 19's "travels at most 60 m" was measured on the odometer while the visible shot
## travelled slightly farther, and the overshoot scales linearly with
## `acceleration_per_second_squared` — so a retune would have widened it silently.
##
## THE ODOMETER IS THE REFERENCE, not the actor, and that is the direction the fix takes: launch
## speed must apply on a shot's FIRST tick, which is `flight_ticks == 0` — the pre-increment value
## this seat reads. The runner now asks for the distance charged on the tick that just completed
## rather than re-deriving a speed from a clock that has moved. That is also why the budget is
## spendable without a position ever entering this layer.
##
## A SHOT WHOSE KIND NO LONGER RESOLVES IS CONSUMED rather than frozen — an X3 reload that shortened
## `unit_kinds` leaves it with no authored speed and no authored budget, and a projectile that can
## neither move nor expire would hang in the air forever. Ending it is the honest degradation.
func _advance_projectiles(player: PlayerState) -> void:
	if balance == null or balance_ticks == null:
		return
	var board := player.projectiles
	for index in board.size():
		if not board.is_alive_at(index):
			continue
		var profile := _projectile_profile_at(board, index)
		if profile == null:
			board.consume_at(index)
			continue
		# One tick's distance at this tick's derived speed, read at the flight clock's PRE-INCREMENT
		# value — `advance_at` below is what moves the clock on. `TimingWindow.TICK_HZ` is the
		# project's single clock (the runner `check_invariant`s it against `physics_ticks_per_second`
		# at startup), so this is the integer-tick integration A1 requires — never a wall-clock delta.
		var distance := _step_distance_at_flight_ticks(board, index, board.flight_ticks_at(index))
		board.advance_at(index, distance, profile.travel_budget)


## The CURRENT SPEED of one live projectile, in world units per second — the acceleration profile
## (AC 15) evaluated at this shot's flight clock.
##
## PUBLIC as the state layer's ONE expression of the authored curve, so nothing outside it may keep a
## duplicated copy that a retune could desynchronise. It is a PURE QUERY — it touches no board and
## mutates nothing — which is the same classification `unit_attack_phase_multiplier` already carries
## for the same reason (`4-3c1/R5`'s `EXEMPT_PURE_QUERY`).
##
## THE RUNNER DOES NOT USE THIS ONE, and that changed at review finding H2. It used to, to move the
## actor — and reading it AFTER `advance()` returned meant reading the flight clock one tick after
## the odometer had been charged. The runner asks `projectile_step_distance_at` below instead, which
## names its tick explicitly. What still reads this is the curve's own tests and anything that wants
## "how fast is this shot going right now", which is a question about the CURRENT clock and is
## answered correctly by exactly this.
##
## THE CURVE IS AUTHORED DATA AND THERE IS EXACTLY ONE OF IT (`4-4/R3`): launch speed until the
## authored delay has elapsed, then linear acceleration, clamped at the authored ceiling. No branch
## anywhere selects a different curve by kind — a kind that wants to behave differently authors
## different numbers.
##
## THE CEILING IS NOT COSMETIC. Without it an authored acceleration would grow the speed without
## bound over a long flight, and a step longer than a hurtbox is wide would tunnel straight through
## it — the projectile would pass through its target instead of hitting it.
func projectile_speed_at(board: ProjectileBoard, index: int) -> float:
	return _speed_at_flight_ticks(board, index, board.flight_ticks_at(index))


## Story 4-4 (review finding H2): THE DISTANCE THIS SHOT FLEW ON THE TICK THAT JUST COMPLETED, in
## world units — the value the runner moves the actor by, and the SAME number
## `_advance_projectiles` charged against the 60 m budget on that tick.
##
## PUBLIC for `projectile_speed_at`'s reason verbatim (a projectile's POSITION is actor-owned, so the
## state layer may only EXPOSE the arithmetic), and a PURE QUERY on the same footing — it touches no
## board and mutates nothing. It joins the `EXEMPT_PURE_QUERIES` set in test_intent_recorder.gd, and
## it needs no capture channel for its two siblings' reason: a replay that reproduces the board
## reproduces this answer, and nothing reaches MatchState through it.
##
## THE `- 1` IS THE F1 ONE-TICK LAG, NOT AN OFF-BY-ONE. The runner's drive phase runs AFTER
## `advance()` has returned, and `ProjectileBoard.advance_at` increments the flight clock as part of
## charging the odometer — so by the time this is called the clock reads the NEXT tick's value. The
## tick whose distance was actually spent is the one before it. Asking for the SPENT DISTANCE rather
## than for a speed is what makes "one arithmetic, two readers" true by construction: both readers
## now name the same tick explicitly instead of one of them inferring it from a clock that has moved.
func projectile_step_distance_at(board: ProjectileBoard, index: int) -> float:
	return _step_distance_at_flight_ticks(board, index, board.flight_ticks_at(index) - 1)


## One tick's distance at the speed this shot carries at flight tick `ticks`. The single conversion
## from the authored curve to a per-tick displacement, so neither reader divides by `TICK_HZ` itself.
func _step_distance_at_flight_ticks(board: ProjectileBoard, index: int, ticks: int) -> float:
	return _speed_at_flight_ticks(board, index, ticks) / TimingWindow.TICK_HZ


## The authored curve, evaluated at an EXPLICIT flight tick rather than at whatever the board's clock
## happens to read. Both public seams above name their tick through this one function, which is what
## H2's fix rests on: there is no path left that infers the tick instead of stating it.
func _speed_at_flight_ticks(board: ProjectileBoard, index: int, ticks: int) -> float:
	var profile := _projectile_profile_at(board, index)
	if profile == null:
		return 0.0
	var delay := _projectile_acceleration_delay_ticks_at(board, index)
	if ticks <= delay:
		return profile.launch_speed
	var accelerating_seconds := float(ticks - delay) / TimingWindow.TICK_HZ
	return minf(profile.max_speed,
			profile.launch_speed + profile.acceleration_per_second_squared * accelerating_seconds)


## This shot's authored projectile profile, resolved through the KIND INDEX its record stores. Null
## for a kind an X3 reload has removed, or one whose attack record authors no projectile — the
## second is unreachable in shipped play (only a projectile attack launches one) and is answered
## honestly rather than asserted, on this file's standing total-function posture.
func _projectile_profile_at(board: ProjectileBoard, index: int) -> ProjectileProfile:
	var kind := balance.kind_at(board.kind_index_at(index))
	if kind == null:
		return null
	var attack := kind.attack_at(0)
	return attack.projectile if attack != null else null


## The acceleration delay in TICKS, read off the derived tick record rather than re-converted here —
## A1's single seconds-to-ticks boundary is `BalanceTicks.from_config()` and nothing else may
## convert. Zero for an unresolvable kind, which only ever pairs with a null profile above.
func _projectile_acceleration_delay_ticks_at(board: ProjectileBoard, index: int) -> int:
	var kind_ticks := balance_ticks.kind_ticks_at(board.kind_index_at(index))
	if kind_ticks == null:
		return 0
	var record := kind_ticks.attack_at(0)
	return record.projectile_acceleration_delay_ticks if record != null else 0


## Story 1-9 (1-9/R6): the entry-time roll direction — the same camera-rotated world
## mapping _resolve_movement uses (clamp, identity short-circuit, yaw-only rotation),
## NORMALIZED (constant roll speed needs a unit direction), with the hero's world-space
## facing as the fallback when the stick is neutral. Computed ONCE at the transition;
## the stored value is locked for the whole roll.
##
## STORY 4-6, OPERATOR RULING `4-6/R7`: THE NEUTRAL-STICK FALLBACK IS NOW INVERTED -- with the
## stick at rest the roll goes AWAY from the locked target, not toward it. This is the DS/ER
## locked-on neutral-dodge convention (the backstep direction), delivered as the ORDINARY roll:
## same animation, same i-frames, same distance and duration, no new move and no new mechanic.
## Once facing became target-derived (AC 2) the old fallback stopped meaning "the way I was last
## heading" and started meaning "straight at the thing I am locked to", which is the one
## direction a dodge must not default to.
##
## DIRECTED STICK INPUT IS UNCHANGED: below the neutral branch the roll follows the stick
## exactly as it always has. The ruling is explicitly REVERSIBLE -- one sign, revisited at
## playtest -- which is why it is one operator, not a branch.
##
## Story 6-8 (AC 4): the backstep is now LOCK-CONDITIONAL. While unlocked there is no target to back
## away from, and facing is input-derived again (AC 3), so the neutral roll reverts to the pre-`4-6`
## rule verbatim: FORWARD, along the last heading.
func _roll_world_direction(hero: HeroState, move_dir: Vector2, slot: int) -> Vector3:
	if move_dir.is_zero_approx():
		var forward := Vector3(hero.facing.x, 0.0, hero.facing.y).normalized()
		var player: PlayerState = p1 if slot == 0 else p2
		return -forward if player.is_locked() else forward
	var dir := move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	return world_dir.normalized()


## Step-4 contact resolution (story 1-5). Drains the queue in push order; for each fact,
## a DEAD target drops the fact outright (story 1-7, D-3 — dropped BEFORE resolution: no
## damage, no dedupe registration, no confirmed hit, so no step-5 mana; closes the
## corpse-mana-farming defect found at the 1-7 gate), then an open target iframe drops
## it the same way (story 1-9, 1-9/R1 — the second target-state drop; see the inline
## comment for the ladder position), then the attacker's dedupe decides
## acceptance (live record for the fact's attack_index + target not already hit this
## swing — stale, unknown, and duplicate facts are DROPPED). Story 1-8 (R-D4): dedupe
## registration happens for EVERY outcome — one resolution per swing per target, whether
## it lands full, blocked, or deflected; a resolved swing's later facts cannot
## re-resolve. Outcome ladder for an accepted fact (all balance reads inline,
## CONSTRAINT C): a BLOCKING target facing the attacker (the arc gate, R-D2/R-D3)
## either DEFLECTS — window open per the +1 grace read (R-N2) AND the deflect cost
## spends at LANDING (R-D1; a failed spend, the R-N7 multi-deflect edge, degrades this
## contact to a block) — fully negated: no damage, no hit_landed, NO step-5 mana, only
## the queued deflect_landed; or BLOCKS — damage x block_damage_multiplier, still a
## CONFIRMED hit (reduced hit_landed + full step-5 mana — block deliberately does not
## touch the attacker's economy in E1). Not facing (or not blocking) = full damage
## regardless of the window — no parry from behind. Returns the attacker slots of
## confirmed hits, in confirmation order, for step 5's mana seat. Pre-injection guard
## mirrors _resolve_actions: without balance the queue still drains (facts are
## per-tick, never carried) but nothing resolves.
func _resolve_contacts() -> Array[int]:
	var confirmed: Array[int] = []
	if _contact_queue.is_empty():
		return confirmed
	if balance == null:
		_contact_queue.clear()
		return confirmed
	for position in _canonical_contact_order():
		var fact: Dictionary = _contact_queue[position]
		var attacker_index := int(fact["attacker_index"])
		var attacker := p1 if int(fact["attacker"]) == 0 else p2
		var target := p1 if int(fact["target"]) == 0 else p2
		# Story 4-3b (AC 13): THE IN-REACH SET, deliberately ABOVE every drop below it — including
		# the probe drop, the dead-target drop and dedupe. A landed strike is PROOF of reach and
		# stronger proof than a probe (it is the same overlap test), and a fact that drops for some
		# OTHER reason still observed the overlap that produced it. Scoped to the unit's own ACQUIRED
		# TARGET inside the helper.
		_mark_reach_from_fact(attacker, attacker_index, fact)
		# Story 4-3b (AC 13, `4-3b/R17b`): THE REACH-PROBE DROP, at the very TOP of the ladder, ahead
		# of the dead-target drop and every rung after it. A probe yields no damage, no dedupe
		# registration, no `confirmed_hits` entry, no mana and no signal, and it never reaches
		# `_resolve_unit_contact`. Its ONLY effect is the flag set directly above, which permits a
		# windup to start. The F1 one-tick lag applies to a probe exactly as to a strike, so a windup
		# begins the tick AFTER reach is observed.
		if int(fact["kind"]) == CONTACT_REACH_PROBE:
			continue
		# Story 4-3a (AC 3/AC 2, `4-3a/R20`): THE UNIT-TARGET BRANCH. A target address whose index
		# is >= 0 addresses a BOARD UNIT, and a unit shares only the rungs it actually HAS.
		# Expressed as a branch inside this ladder rather than a helper beside it (`4-3a/R20`
		# permits either), so the SHARED rungs are visibly the same lines in the same ORDER:
		# dead-target drop, dead-attacker drop, dedupe. What it SKIPS is skipped because a unit
		# structurally lacks it, not because this story chose not to implement it — iframes,
		# deflect and block are all properties of a HERO target: a unit has no roll, no defense
		# window, no action state and no facing.
		if int(fact["target_index"]) != TargetingService.HERO_INDEX:
			_resolve_unit_contact(fact, attacker, target)
			continue
		if target.hero.action_state == HeroState.ActionState.DEAD:
			continue
		# Story 2-3 (AC3, 2-3/R6): attacker-side DEAD FACT DROP — the same rung and the same
		# DEAD-drop family as the target drop above: PRE-DEDUPE, ahead of the iframe drop and
		# register_swing_hit. A dead attacker's fact delivers NOTHING (no damage, no
		# hit_landed, no mana, no deflect signal). Placed before register_swing_hit so the
		# corpse's fact never consumes the swing's one resolution; attack_index stays
		# untouched. The in-flight window is NOT stopped or shortened here — it keeps ticking
		# to expiry by design (1-9/R3 intact); it simply resolves to nothing.
		#
		# STORY 4-3b (AC 14): THE MECHANISM WAS REPLACED HERE, exactly as `4-3a/R24` instructed. That
		# ruling accepted the two-copy duplication of this check and named its own trigger: "If a
		# THIRD copy of this check appears in a future story, that is the signal to replace the
		# mechanism (e.g. a shared dead-attacker guard both ladders call into) rather than to keep
		# tightening this two-copy pattern." This story is that story -- it needed the check to
		# dispatch on ATTACKER KIND in BOTH ladders -- so both now call `_attacker_is_dead` and there
		# is no duplicated condition left to keep in agreement.
		if _attacker_is_dead(attacker, attacker_index):
			continue
		# Story 1-9 (1-9/R1): iframe FACT DROP — not a resolution. Judged on the window
		# (+grace) ALONE, never on state == ROLLING (1-9/R3), and BEFORE dedupe
		# registration (the DEAD-drop family): a dropped fact never consumes the swing,
		# so if the i-frames expire inside the swing's active window the next gathered
		# fact resolves normally. No damage, no hit_landed, no mana, no signal (1-9/R5).
		if target.hero.is_iframe_open():
			# Story 4-4 (AC 16, `4-4/R4`): THE I-FRAME DROP IS ALSO WHAT ENDS A PROJECTILE'S HOMING,
			# on the same tick and at the same rung. The rung itself is UNCHANGED — the fact is
			# dropped exactly as it has been since `1-9/R1`, before dedupe, with no damage, no
			# signal and no mana — and this line adds a SECOND CONSEQUENCE for one attacker kind
			# rather than a second rung that could fall out of step with the first.
			#
			# THE PROJECTILE IS NOT CONSUMED HERE, and the asymmetry against AC 18 is the whole
			# point: a blocked or deflected shot is STOPPED (AC 18), while a shot that passes
			# through i-frames keeps flying — it just stops steering. From this tick on it holds its
			# last heading, which is the actor's own state and needs no value pushed to it: the
			# runner simply stops asking where the target is.
			#
			# `4-4/R5` IS THE OTHER HALF, and it is enforced by ABSENCE: nothing anywhere ends
			# homing when a target merely leaves the flight path, because a miss is not an event and
			# produces no fact to hang such a rung on.
			if is_projectile_index(attacker_index):
				attacker.projectiles.end_homing_at(projectile_index_of(attacker_index))
			continue
		if not _register_attacker_hit(attacker, attacker_index, int(fact["attack_index"]),
				int(fact["target"]), TargetingService.HERO_INDEX):
			continue
		# Story 4-4 (AC 9): DAMAGE AGAINST A HERO IS NOW ATTACKER-DERIVED TOO, and the unification is
		# BIT-FOR-BIT BEHAVIOUR-PRESERVING at the shipped authoring rather than a retune. A HERO
		# attacker still reads `attack_damage_percent_of_max_hp` against the target's own maximum —
		# unchanged, so hero-versus-hero is the code it was. A UNIT attacker now reads ITS OWN KIND's
		# attack-record damage, which is what AC 9 means by the record carrying damage: the record
		# describes what THIS attack does, not what happens to be done to it.
		#
		# WHY IT MOVES NOTHING TODAY, MEASURED: the shipped minion's record authors 3.0 damage, and
		# the value it replaces for a unit attacker was `attack_damage_percent_of_max_hp` (3.0) /
		# 100 * hero `max_hp` (100.0) = 3.0. Identical. The golden therefore does not move on this
		# line, which is why it is not one of this story's named re-baseline causes.
		#
		# IT IS ALSO WHAT MAKES THE PROJECTILE'S DAMAGE AUTHORED (AC 14/AC 15). Without it a Combat
		# totem's shot would deal the HERO's own swing percentage — a number belonging to a different
		# attacker entirely — and the totem's authored damage would decide nothing.
		var damage := _damage_against_hero(attacker, attacker_index, target)
		var blocked := false
		if target.hero.action_state == HeroState.ActionState.BLOCKING \
				and _is_facing(target.hero, fact["dir"]):
			if target.hero.is_deflect_window_open() and target.stamina.spend(
					balance.deflect_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				# Story 4-4 (AC 18, `4-4/R6`): A DEFLECTED PROJECTILE IS CONSUMED — it "does not
				# continue flying past a blocked or deflected hit". Seated on the deflect path
				# itself rather than once below, because this path `continue`s: the deflect is
				# FULLY NEGATED (no damage, no `hit_landed`, no mana, `1-8`'s R-D4 unchanged) and
				# never reaches the common consumption line further down.
				_consume_projectile_attacker(attacker, attacker_index)
				# Story 5-5 (AC 13): the melee/unit parry reports NO COLOUR -- this negation is
				# colour-blind by construction, and the sentinel says so rather than a colour it
				# would have to invent. Today's untinted cue is what the consumer keeps rendering.
				_queue.push(deflect_landed.emit.bind(int(fact["attacker"]), int(fact["target"]),
						PlayerState.NO_TELEGRAPH_COLOR))
				# STORY 5-6 (AC 9/AC 10, `E5-P/R1`): THE DEFLECT'S CONSEQUENCE FOR ITS ATTACKER, and
				# the SECOND authored inbound edge to `STUNNED` (the last until story 6-6a added the
				# knockdown in `_apply_landing_packages`, the third).
				#
				# HERO ATTACKERS ONLY, gated on `attacker_index == TargetingService.HERO_INDEX` — the
				# `4-3b/R4` mana-gate discriminant applied a second time to a second hero-only
				# consequence. `attacker` (the `PlayerState`) is already resolved whether the fact came
				# from the hero or from one of that player's minions, so `attacker_index` is the field
				# that actually distinguishes "this fact's origin was the hero itself".
				#
				# A UNIT IS EXCLUDED BY `4-3b/R7`, CARRIED FORWARD UNCHANGED ("deflecting a minion does
				# NOT stun it, for now") — and structurally true regardless: a unit has no
				# `ActionState` and no `stun` window to enter. The gate exists because a HERO does,
				# not merely as an extra guard. test_block_deflect.gd's existing negative guard is
				# re-run UNEDITED as this story's own proof the gate holds.
				#
				# IT INTERRUPTS THE SWING IMMEDIATELY (the story's Open Question, shipped on the
				# recommended reading): the attacker is necessarily `ATTACKING` with `active` running
				# when a contact fact was gathered from it, so this write REPLACES `ATTACKING` and
				# abandons the swing's `active`/`recovery`/`chain` windows mid-flight. The orphaned
				# windows keep ticking to their own expiry (`1-9`'s never-early-stop discipline) and
				# are harmless ONLY BECAUSE AC 11 ships with this: `is_hitbox_active()` now also
				# requires `ATTACKING`, so the orphaned `active` window cannot gather a further fact
				# from a hero the game is already punishing for that swing.
				#
				# THE DRAIN USES `add(-x)`, NOT `spend()` (AC 10), and the distinction is the contract
				# rather than a preference. `spend()` REFUSES OUTRIGHT when the amount exceeds the
				# balance — correct for a VOLUNTARY, affordability-gated cost (roll, attack, the
				# defender's own deflect cost two lines above), where an unaffordable action simply
				# does not happen. A PUNITIVE drain is the opposite: it must ALWAYS apply, floored at
				# zero, never silently skipped because the attacker happened to be poor. `add()` already
				# clamps to `[0, maximum]` and is the mechanism `refill()` and the per-tick regen use
				# for an unconditional adjustment. It also does NOT restart `_regen_delay` (only
				# `spend()` does), which is the correct scope: the penalty moves the CURRENT balance,
				# not the regen cadence — a consequence, not a cost.
				#
				# NO PER-TICK "ALREADY PUNISHED" GUARD, deliberately (`5-6` fix pass, review finding
				# M2, MEASURED not assumed): this rung cannot run twice for the same attacker against
				# this SAME hero target in one tick. A hero owns exactly one `active` TimingWindow
				# (`hero_state.gd:112`), so at most one hitbox is live for it at any instant and the
				# match_runner can gather at most one contact fact from it per tick against a given
				# target — there is no second swing to produce a second fact while the first is still
				# `active`. A duplicate fact naming the SAME `attack_index` against this target would in
				# any case drop at `_register_attacker_hit`'s dedupe rung above, strictly BEFORE this
				# branch in the ladder. A guard here would be defending against a fact this ladder's own
				# earlier rungs already make unreachable.
				if attacker_index == TargetingService.HERO_INDEX:
					attacker.hero.stun.start(balance_ticks.deflect_stun_ticks)
					attacker.hero.set_action_state(HeroState.ActionState.STUNNED)
					attacker.stamina.add(-balance.deflect_stamina_penalty)
				continue
			damage *= balance.block_damage_multiplier
			blocked = true
		# Story 6-5a (AC 9): THE DAMAGE FUNNEL, seated AFTER the block multiplier.
		#
		# 6-5a REVIEW N1: the dev pass said "and never reordered with it", which is a claim no test can
		# falsify and none makes -- both steps are scalar multiplies, so `(d * BLOCK) * 2.0` and
		# `(d * 2.0) * BLOCK` are the same number (the authored factors are powers of two, so exactly
		# the same, not merely close). THE ORDER IS UNOBSERVABLE, at rest and under Bloodlust alike.
		# What IS load-bearing is that the funnel sees post-block damage at all: Vampiric Aura heals off
		# the hp actually removed, so the funnel must not run on a number the block has yet to cut.
		# Should a non-commuting step (a clamp, a floor) ever land between them, the order becomes real
		# and a test must be added in the same breath.
		# At rest (no Bloodlust on either side) it returns `damage` untouched, so every hit this seat has
		# ever resolved is bit-identical. The hp read around `take_damage` is what makes Vampiric Aura
		# heal the damage ACTUALLY removed (N10): after block and every multiplier, capped by what the
		# target had left.
		damage = _funnel_damage(attacker, attacker_index, target, TargetingService.HERO_INDEX, damage)
		var hp_before := target.hero.get_hp()
		target.hero.take_damage(damage)
		_apply_lifesteal(attacker, attacker_index, hp_before - target.hero.get_hp())
		# Story 6-5a (R5): FROSTBITE'S TRIGGER SEAT -- a CONFIRMED hero melee hit on the enemy hero,
		# BLOCKED INCLUDED (blocked is confirmed, `1-8`). The deflect path `continue`d above and the
		# i-frame drop earlier, so neither reaches this line; unit targets branched off before the
		# hero ladder, and projectile / unit attackers fail the hero-index gate.
		if attacker_index == TargetingService.HERO_INDEX:
			_consume_frostbite(attacker, target)
		# Story 4-3b (AC 8, `4-3b/R5`): `hit_landed` IS emitted when a UNIT damages a HERO — the hero
		# is really hurt, so the telegraph flash and sting on that hero are correct. A DELIBERATE
		# ASYMMETRY against `4-3a/R12`'s suppression for unit TARGETS, recorded here so a later gate
		# does not re-litigate it as an inconsistency: the two are not the same rule. Payload
		# UNCHANGED per AC 3 — the bare-int attacker slot is enough, because the consumer gates on the
		# TARGET (telegraph_controller.gd underscores the attacker).
		#
		# Story 6-6a review (D2): pushed through `_emit_hit_landed` so the drain can say whether THIS hit
		# took the block branch above -- the payload itself is still the unchanged four.
		_queue.push(_emit_hit_landed.bind(
			int(fact["attacker"]), int(fact["target"]), damage, target.hero.get_hp(), blocked))
		# Story 4-3b (AC 7, `4-3b/R4`): A UNIT-SOURCED CONFIRMATION GENERATES NO MANA, and THIS LINE
		# is the whole mechanism — the `4-3a/R3` unit-TARGET precedent applied to the unit-ATTACKER
		# side. `_generate_mana` awards per entry in the list this function returns, so keeping a
		# unit-sourced confirmation OUT of the list is the gate. There is deliberately NO second check
		# inside `_generate_mana` to keep in agreement with this one. Otherwise summoning becomes a
		# mana engine — and a blocked hit still confirms.
		if attacker_index == TargetingService.HERO_INDEX:
			confirmed.append(int(fact["attacker"]))
		# Story 4-4 (AC 18, `4-4/R6`): THE COMMON CONSUMPTION LINE — a BLOCKED hit and a FULL hit
		# both end the shot here. Together with the deflect path above, every outcome that RESOLVES
		# consumes the projectile; the only outcomes that do not are the ones that DROP the fact
		# (dead target, dead attacker, i-frames), which is exactly right — a dropped fact is not a
		# hit, and AC 16 is explicit that the i-frame case keeps flying.
		#
		# SEATED AFTER `take_damage` AND THE SIGNAL, so a consumed shot has still delivered
		# everything the hit owed. Order matters only for readability here — nothing between reads
		# the projectile's liveness — but the sequence "resolve, then end" is the honest one.
		_consume_projectile_attacker(attacker, attacker_index)
	_contact_queue.clear()
	return confirmed


## Story 4-4 (AC 18, `4-4/R6`): end this fact's attacker if it is a PROJECTILE, and do nothing for
## any other attacker kind. A one-line helper rather than the test written out at each of the three
## resolving outcomes (deflect, block, full), because the three must never disagree about what
## "resolved" means — and because a fourth outcome added later gets it by calling this rather than by
## remembering the encoding.
##
## `consume_at` IS IDEMPOTENT and lenient on the index, so this is safe to call on every resolution
## without first asking whether the attacker is a projectile at all.
func _consume_projectile_attacker(attacker: PlayerState, attacker_index: int) -> void:
	if not is_projectile_index(attacker_index):
		return
	attacker.projectiles.consume_at(projectile_index_of(attacker_index))


## Story 4-3b (AC 5): THE CANONICAL RESOLUTION ORDER ACROSS ATTACKERS — SLOT ASCENDING, THEN BOARD
## INDEX ASCENDING, the `4-2/R3` tie-break this project already established for minion targeting,
## with the queue POSITION as a final tie-break so the sort is stable.
##
## WHY ORDER ACROSS ATTACKERS IS PLAYER-VISIBLE AND MUST NOT BE INCIDENTAL: deflect spends stamina
## PER FACT (the ladder above), so with two minions landing on one hero in one tick the FIRST fact
## resolved is deflected and the SECOND falls through to blocked damage once the stamina runs out.
## Which minion is which must not be decided by unpinned physics-query or gather order.
##
## PINNED HERE RATHER THAN ONLY IN THE RUNNER, and that is the difference between a convention and a
## mechanism (the standing `3-0d/R20` preference for impossible-by-construction over
## detectable-by-inspection). The runner ALSO gathers in this order — hero then units, slot 0 then
## slot 1 — but a canonical order that lives only in the gather seat would be re-established by
## every future fact producer that remembers to. Sorting HERE makes the property hold for facts fed
## in ANY order, which is exactly what AC 5's non-vacuous pin feeds in.
##
## HERO-VS-HERO IS BIT-FOR-BIT UNMOVED, provably: a hero attacker's address is `[slot, -1]`, the
## runner has always gathered slot 0 before slot 1, and this sort is STABLE — so a queue containing
## only hero facts comes out of it in exactly the order it went in.
##
## THE INDICES ARE SORTED, NOT THE QUEUE. Sorting the fact dictionaries themselves would need a
## comparator over dictionaries and would lose the arrival position that makes the sort stable; an
## `Array[int]` of positions costs one small allocation on ticks that have facts at all, which are
## already the ticks allocating `confirmed`.
func _canonical_contact_order() -> Array[int]:
	var order: Array[int] = []
	for i in _contact_queue.size():
		order.append(i)
	order.sort_custom(_contact_precedes)
	return order


## STORY 4-4: WHERE PROJECTILES LAND IN THIS ORDER, stated rather than left to be discovered. The
## comparison is unchanged — slot ascending, then attacker INDEX ascending, then queue position — and
## a projectile's index is `PROJECTILE_INDEX_BASE - i`, i.e. -2, -3, -4, ... So within one slot the
## order is: projectiles NEWEST-FIRST (the most negative index sorts first), then the hero at -1,
## then units ascending from 0.
##
## THAT IS DETERMINISTIC AND STABLE, WHICH IS ALL `4-3b/R5` REQUIRES — its content is that the order
## must not be decided by unpinned physics-query order, not that any particular attacker kind goes
## first. It is also unobservable in shipped play today: the multi-attacker consequence `4-3b/R5`
## names is the per-fact deflect stamina drain, and a deflected projectile is CONSUMED (AC 18) rather
## than falling through to a second resolution, so two shots landing in one tick spend at most what
## two facts would have spent in any order.
##
## HERO-VERSUS-HERO IS STILL BIT-FOR-BIT UNMOVED: no projectile fact exists in a hero-only queue, and
## the sort remains stable.
func _contact_precedes(a: int, b: int) -> bool:
	var fa: Dictionary = _contact_queue[a]
	var fb: Dictionary = _contact_queue[b]
	var slot_a := int(fa["attacker"])
	var slot_b := int(fb["attacker"])
	if slot_a != slot_b:
		return slot_a < slot_b
	var index_a := int(fa["attacker_index"])
	var index_b := int(fb["attacker_index"])
	if index_a != index_b:
		return index_a < index_b
	return a < b


## Story 4-3b (AC 13): SET the sourcing unit's IN-REACH FLAG from a fact it produced — of EITHER
## KIND, probe or strike.
##
## COUNTING STRIKES CLOSES A REFRESH HOLE, and it is the trap this AC exists to name: the fact's KIND
## is decided by PHASE, so while a unit's active window is open the SAME overlap produces a STRIKE
## rather than a probe. A throttle tick landing inside an active window would therefore refresh
## nothing, and after recovery the unit would wait for the next probe — the same jitter the flag
## exists to remove, merely less often. A landed strike is PROOF of reach, and stronger proof than a
## probe since it is the identical overlap test, so counting it closes the hole with no new mechanism
## and no extra stream volume.
##
## SCOPED TO THE ACQUIRED TARGET, AND THAT DOES NOT FOLLOW FROM AC 4 READ ALONE. AC 4's cleave
## deliberately lets one swing damage BYSTANDERS the unit never aimed at; letting a bystander refresh
## "in reach" would keep a unit swinging at a target it has actually lost. Only the FLAG is scoped
## here — never which targets a cleave may damage.
##
## A HERO-SOURCED FACT RETURNS IMMEDIATELY: heroes have no reach flag, and a hero's swing is
## input-driven.
##
## THE LOCKED DIRECTION IS REFRESHED IN THE SAME BREATH, AND ONLY WHILE THE SWING CAN STILL LAND
## (AC 12). The fact's field is TARGET-to-ATTACKER, so the unit's attack direction is its NEGATION —
## storing it un-negated would lock a backwards swing. Once a WINDUP has begun this branch cannot
## fire again until the ACTIVE window has closed, so the value FREEZES across windup and active:
## that freeze IS the lock, and it needs no sixth "is locked" field.
##
## THE FREEZE COVERS WINDUP AND ACTIVE, NOT RECOVERY, AND THE STORY DID NOT SETTLE WHICH — REPORTED
## AS A DEV-PASS FINDING RATHER THAN CHOSEN QUIETLY. AC 12 states the freeze runs "from windup start
## until the swing ends", which read literally includes recovery; but with AC 13's back-to-back cycle
## a continuously in-reach unit is IDLE only inside the single step-3 pass that ends recovery and
## begins the next windup, so NO fact can ever arrive while it is idle and the direction would freeze
## at its FIRST value FOREVER — contradicting AC 12's own stated consequence that the lock is "up to
## one throttle interval stale", which bounds the staleness at one interval. The two clauses cannot
## both hold across a back-to-back cycle. The reading taken satisfies BOTH: AC 12's stated feel is
## "a swing that misses when the target steps aside DURING WINDUP/ACTIVE is the intended feel" — it
## names those two phases and not recovery — and during RECOVERY the hitbox is shut, so nothing can
## land and refreshing harms nothing while keeping staleness bounded as promised. If the operator
## wants the literal reading instead, this condition is the one line that changes.
func _mark_reach_from_fact(attacker: PlayerState, attacker_index: int, fact: Dictionary) -> void:
	if attacker_index == TargetingService.HERO_INDEX:
		return
	# Story 4-4: a PROJECTILE-sourced fact returns immediately, for the hero's own reason one line
	# above — projectiles have no reach flag and no windup for one to permit. The reach flag is a
	# property of a unit deciding when to swing, and a shot has already been fired.
	if is_projectile_index(attacker_index):
		return
	if not attacker.units.has_index(attacker_index):
		return
	if attacker.units.target_slot_at(attacker_index) != int(fact["target"]):
		return
	if attacker.units.target_index_at(attacker_index) != int(fact["target_index"]):
		return
	attacker.units.mark_in_reach_at(attacker_index, _reach_freshness_ticks())
	var phase := attacker.units.attack_phase_at(attacker_index)
	if phase != UnitBoard.AttackPhase.WINDUP and phase != UnitBoard.AttackPhase.ACTIVE:
		attacker.units.set_attack_dir_at(attacker_index, -(fact["dir"] as Vector2))


## Story 4-4 (`4-4/R14`): HOW LONG A REACH CONFIRMATION STAYS CURRENT, in ticks. DERIVED, never
## authored, and that derivation is the whole ruling: a confirmation older than ONE PROBE CADENCE
## can no longer be current, because the runner re-probes on that cadence and would have
## re-confirmed by now if the target were still in range. The `+ 1` is the F1 ONE-TICK FACT LAG —
## a probe gathered on tick N is consumed by `advance()` on N+1, so a window of exactly
## `minion_retarget_interval_ticks` would expire the confirmation on the very tick its successor
## arrives and leave a one-tick hole in every cadence for no reason.
##
## READ INLINE OFF `BalanceTicks` ON EVERY CALL (CONSTRAINT C), never copied onto a record: an X3
## reload that retunes `minion_retarget_interval_seconds` changes the window for confirmations made
## after it, and no unit carries a stale copy of the old cadence.
##
## THE NULL FALLBACK IS THE STRICTEST WINDOW, not the most permissive. With no `BalanceTicks` there
## is no cadence to derive from, so the window is ONE TICK — the smallest value that is not "stale on
## arrival". A unit in that state cannot swing anyway (its phase durations come from the same
## object), so the fallback can only ever be conservative. This helper is also the sole guarantee
## that `UnitBoard.mark_in_reach_at` is never handed a non-positive window; the container does not
## re-check it, because every `Invariant.check` in that class is a BOUND guard by its own pinned
## discipline.
func _reach_freshness_ticks() -> int:
	if balance_ticks == null:
		return 1
	return balance_ticks.minion_retarget_interval_ticks + 1


## Story 4-3b (AC 14, rung (a)): THE DEAD-ATTACKER DROP, DISPATCHED ON ATTACKER KIND.
##
## THE DEFECT THIS REPLACES WAS SILENT. Both ladders read `attacker.hero.action_state == DEAD`, which
## for a UNIT attacker asks whether its OWNER HERO is dead — so a LIVE minion owned by a DEAD hero had
## every one of its facts dropped, with no damage, no signal and no error. A unit attacker's liveness
## is its OWN board record's, resolved from the widened address of AC 3.
##
## AC 15 IS WHAT PROVES THIS RUNG DOES ITS JOB from the other direction: contact facts carry the F1
## one-tick lag, so a fact gathered while the unit was alive can arrive after it died, and this is the
## rung that drops it. Placed BEFORE dedupe registration for the `2-3/R6` reason unchanged — a
## corpse's fact must never consume the swing's one resolution against that address.
##
## THE THIRD COPY THAT `4-3a/R24` NAMED IN ADVANCE. That ruling accepted the two-copy duplication and
## said explicitly: "If a THIRD copy of this check appears in a future story, that is the signal to
## replace the mechanism (e.g. a shared dead-attacker guard both ladders call into) rather than to
## keep tightening this two-copy pattern." This story is that future story, so the mechanism is
## replaced as instructed rather than a third copy added.
##
## STORY 4-4: THE THIRD ATTACKER KIND joins the dispatch, which is exactly what this function was
## extracted to make cheap. A projectile's liveness is its own board record's — false once it has
## been consumed (AC 18) or its budget has expired (AC 19) — and AC 19's "removed from the world"
## depends on this rung: the F1 one-tick lag means a shot that expired at step 3c can still have a
## fact arriving at step 4, and this is where that fact drops.
func _attacker_is_dead(attacker: PlayerState, attacker_index: int) -> bool:
	if attacker_index == TargetingService.HERO_INDEX:
		return attacker.hero.action_state == HeroState.ActionState.DEAD
	if is_projectile_index(attacker_index):
		return not attacker.projectiles.is_alive_at(projectile_index_of(attacker_index))
	return not attacker.units.is_alive_at(attacker_index)


## Story 4-3b (AC 14, rung (b)): DEDUPE REGISTRATION, DISPATCHED ON ATTACKER KIND — the second
## silently-failing attacker-side rung, and the more damaging of the two.
##
## THE DEFECT THIS REPLACES WAS SILENT AND TOTAL. Both ladders called `attacker.hero.register_swing_hit(...)`,
## the OWNER HERO's registrar, which returns false for a unit's `attack_index` because a unit never
## starts a hero swing and so never opens a record under that key — so EVERY UNIT HIT VANISHED with no
## damage, no signal and no error. A unit's dedupe is its OWN (AC 16): its own monotonic counter on the
## board, its own records in `UnitSwingDedupe`.
##
## WHY THE UNIT CANNOT SHARE THE HERO'S, measured (`4-3b/R12`): the hero's `attack_index` is
## incremented only by hero swings and IS snapshotted, so driving it from unit swings would move
## hero-observed values — an unnamed golden cause; and the hero's records expire off the HERO's own
## active window, which has nothing to do with a unit's.
##
## STORY 4-4: A PROJECTILE'S DEDUPE IS ITS LIVENESS, AND THAT IS WHY THIS BRANCH REGISTERS NOTHING.
## The two existing branches keep a HIT LIST because one swing may cleave several targets while
## refusing to hit any ONE of them twice. A projectile cannot cleave: resolving CONSUMES it (AC 18
## and the full-damage path alike), so "has this shot already resolved" and "is this shot still
## alive" are the same question — and answering it from one field is what stops the two drifting.
##
## THE LIVENESS TEST IS NOT REDUNDANT WITH THE RUNG ABOVE. `_attacker_is_dead` runs BEFORE this on
## both ladders, so this branch is reached only for a live shot — but two facts from ONE tick can
## both name the same shot (two hurtboxes overlapped at once), and the first to resolve consumes it.
## This is the rung that drops the second.
func _register_attacker_hit(attacker: PlayerState, attacker_index: int, attack_index: int,
		target_slot: int, target_index: int) -> bool:
	if attacker_index == TargetingService.HERO_INDEX:
		return attacker.hero.register_swing_hit(attack_index, target_slot, target_index)
	if is_projectile_index(attacker_index):
		return attacker.projectiles.is_alive_at(projectile_index_of(attacker_index))
	return attacker.unit_dedupe.register(attacker_index, attack_index, target_slot, target_index)


## Story 4-3a (AC 2/AC 3/AC 5/AC 7, `4-3a/R20`): one contact fact whose target address names a
## BOARD UNIT. The step-4 ladder's unit half, and it is deliberately SHORT — the rungs a hero
## target carries that a unit structurally lacks are absent, not stubbed.
##
## THE SHARED RUNGS ARE IN THE SAME ORDER AS THE HERO LADDER, which is the whole of `4-3a/R20`'s
## requirement:
##   1. DEAD-TARGET DROP. The hero ladder's first rung, and a unit has one now — that is this
##      story. A dead unit's record stays at its index carrying hp 0 (the hole, AC 7), and a fact
##      addressing it is DROPPED, which is what AC 8 means by "stops being addressable as an attack
##      target by a later swing". `is_alive_at` also reads false for an out-of-range index, so a
##      fact naming a record that does not exist drops on the same rung rather than crashing.
##   2. DEAD-ATTACKER DROP. Identical to the hero ladder's, same rung, same reason (2-3/R6): a
##      corpse's fact delivers NOTHING, and it is placed BEFORE dedupe so the corpse never consumes
##      the swing's one resolution against this address.
##   3. DEDUPE, through the widened `[attack_index, slot, index]` key (`4-3a/R16`). This is what
##      lets one swing cleave through several units while still refusing to hit any ONE of them
##      twice.
##
## WHAT IS SKIPPED AND WHY: the IFRAME drop (a unit does not roll), the DEFLECT branch (a unit has
## no defense window and no stamina to pay a deflect with) and the BLOCK multiplier plus its facing
## gate (a unit has no action state and no facing to judge an arc against). All three are properties
## of a HERO target. `4-3b` ships the unit as an ATTACKER; none of these becomes a unit property
## then either.
##
## DAMAGE IS THE DEDICATED FLAT FIELD, read INLINE at this point of use (CONSTRAINT C) and NOT
## `attack_damage_percent_of_max_hp` (`4-3a/R8`, decided by Matko) — see the field's own comment on
## BalanceConfig for why a percentage of the target's own maximum would make hits-to-kill a constant
## and `unit_max_hp` cosmetic.
##
## TWO THINGS DELIBERATELY DO NOT HAPPEN HERE, and each is its own AC:
##   * NO `hit_landed` (AC 5-adjacent, `4-3a/R12`): the signal carries a SLOT only and its shipped
##     consumer flashes and stings the HERO of that slot, so emitting it on a unit hit would flash
##     an untouched hero whose hp did not change. The legible event this story ships is DEATH.
##   * NO `confirmed.append` — and THAT IS AC 5's entire mechanism. Step 5's `_generate_mana` awards
##     `melee_hit_mana` per entry in the list this function returns, so a unit-target confirmation
##     staying OUT of that list is what makes killing minions generate no mana. There is no second
##     gate inside `_generate_mana` to keep in agreement with this one.
func _resolve_unit_contact(fact: Dictionary, attacker: PlayerState, target: PlayerState) -> void:
	var index := int(fact["target_index"])
	if not target.units.is_alive_at(index):
		return
	# Story 4-3b (AC 14/AC 17): BOTH attacker-side rungs now DISPATCH ON ATTACKER KIND, through the
	# same two helpers the hero ladder calls -- which is `4-3a/R24`'s own instruction discharged (it
	# named a THIRD copy of the dead-attacker check as the signal to replace the mechanism rather
	# than tighten the two-copy pattern, and this story would have been that third copy).
	#
	# AC 17 FALLS OUT OF EXACTLY THIS AND NEEDS NO SEPARATE PATH: unit-versus-unit damage is this
	# same ladder with the ATTACKER address naming a unit instead of a hero. Both attacker kinds read
	# the same `unit_damage_per_hit` against the same `unit_max_hp`, so a minion dies to another
	# minion in the same number of hits it takes from a hero, by construction.
	var attacker_index := int(fact["attacker_index"])
	if _attacker_is_dead(attacker, attacker_index):
		return
	if not _register_attacker_hit(attacker, attacker_index, int(fact["attack_index"]),
			int(fact["target"]), index):
		return
	# Story 4-3a (AC 7, `4-3a/R21a`): DEATH IS RESOLVED HERE, immediately after damage is applied,
	# and it needs no line of its own — a record is dead exactly when its hp reaches 0, so the clamp
	# inside `apply_damage_at` IS the death. Nothing is removed, nothing is compacted and no other
	# record's index moves: the corpse stays at this index as a hole (AC 7), and the two named
	# liveness seats (`4-3a/R14`) stop driving it because they consult `is_alive_at`.
	#
	# THE STEP-1b ROUND-OVER FREEZE NEEDS NO SPECIAL CASE, and this is the MEASURED claim
	# `4-3a/R21a` narrowed the Open Question to rather than an assertion: step 1b returns from
	# advance() before step 4 is ever reached, so a frozen tick never resolves a contact and
	# therefore never kills a unit. Pinned in test_unit_damage_and_death.gd.
	# Story 6-5a (AC 9): the UNIT damage seat, through the same funnel as the hero seats -- a minion on
	# either side is Bloodlust's, a totem never is (R3). Vampiric Aura heals off a hero's hit on a unit
	# too (R4: all damage the caster's hero deals), measured as the hp the unit actually lost.
	# Story 6-5b (AC 3/AC 6, `6-5b/R13`): the corpse lifetime is read INLINE here (CONSTRAINT C) and
	# handed down, so a lethal hit routes through `UnitBoard.kill_at` inside `apply_damage_at` and
	# leaves a corpse -- the FIRST of the death seat's exactly three callers. A combat-hit death is
	# therefore indistinguishable in its aftermath from a Culling kill or a Drain sacrifice (AC 6),
	# because all three write the corpse through the same function with the same argument.
	var unit_hp_before := target.units.hp_at(index)
	target.units.apply_damage_at(index, _funnel_damage(attacker, attacker_index, target, index,
			_damage_against_unit(attacker, attacker_index)), _corpse_ticks_for(target, index))
	_apply_lifesteal(attacker, attacker_index, unit_hp_before - target.units.hp_at(index))
	# Story 4-4 (AC 16 second sentence / AC 18): a projectile that lands on a UNIT is consumed here,
	# the hero ladder's common consumption line applied to the short ladder. AC 16's second sentence
	# is satisfied BY ABSENCE rather than by code: this ladder has no i-frame, block or deflect rung
	# — a unit structurally lacks all three — so there is nowhere a unit-targeted shot's homing could
	# end early, and it ends only at contact or at the 60 m budget, exactly as the AC states.
	#
	# REACHABLE ONLY ONCE A FUTURE KIND AUTHORS A UNIT-PREFERRING PRIORITY (the AC says so in as many
	# words): the shipped Combat totem is hero-preferring by `4-4/R9`, so its shots address heroes.
	# This line is therefore the correct behaviour written once, not a path the shipped build takes.
	_consume_projectile_attacker(attacker, attacker_index)
	# Review fix pass (4-3b, F2): a unit that DIES here can never close its own swing-dedupe
	# record through the normal per-tick path again -- `_advance_unit_attacks` skips dead units
	# entirely, so a corpse killed mid-ACTIVE-window would otherwise leave that record open
	# forever. This is the one place death is already known, so the record is discarded right
	# here rather than adding a second liveness seat elsewhere. A no-op if this unit never opened
	# a record, or one already closed and erased normally. See `UnitSwingDedupe.discard`.
	if not target.units.is_alive_at(index):
		target.unit_dedupe.discard(index)


## Story 4-4 (AC 6/AC 9): what ONE confirmed hit against a unit takes off it, DISPATCHED ON ATTACKER
## KIND — the successor to the single flat `balance.unit_damage_per_hit` this seat used to read.
##
## THE OLD FIELD HAD TWO READERS THAT WERE NEVER THE SAME FACT, and AC 6 splitting it is what makes
## that visible. `4-3a/R8` created it for the HERO-versus-unit case ("the DEDICATED FLAT damage one
## confirmed hero swing takes off a unit"); `4-3b`'s AC 17 then reused it for UNIT-versus-unit,
## noting approvingly that "both attacker kinds read the same `unit_damage_per_hit`". AC 6 moves
## damage-per-hit per kind and AC 9 puts it on the attack RECORD — which is the ATTACKER's property.
## So the two readers separate:
##
##   * A UNIT ATTACKER deals ITS OWN KIND's authored attack damage. That is the per-kind conversion,
##     and it is what makes a Combat totem's shot and a minion's swing differ without a branch.
##   * A HERO ATTACKER deals `balance.hero_damage_to_unit` — the same flat number under a name that
##     says whose damage it is. `4-3a/R8`'s reasoning for why it must be FLAT rather than
##     `attack_damage_percent_of_max_hp` is UNCHANGED and now stronger: with `max_hp` itself per
##     kind, a percentage would make hits-to-kill a constant across every authored kind and make
##     every kind's authored maximum cosmetic.
##
## AN UNRESOLVABLE ATTACKER KIND DEALS NOTHING (0.0), the graceful-degradation direction every
## authored-data miss in this project takes: a record written under an authored list that a live X3
## reload has since shortened stops hurting anything rather than dealing an invented number. Same
## answer for a kind that authors no attack — an accelerator totem cannot produce a strike fact in
## the first place (it never winds up), so this branch is defence in depth.
## Story 4-4 (AC 9): what one confirmed hit against a HERO takes off it, dispatched on attacker kind
## — the twin of `_damage_against_unit` directly below, and the two are deliberately separate
## functions rather than one with a target-kind parameter, because the HERO-attacker branches differ
## in a way no shared expression captures: against a hero the attacker's own swing is a PERCENTAGE
## of the target's maximum (`4-3a/R8`'s reasoning applies only to unit targets), while against a
## unit it is the flat `hero_damage_to_unit`.
##
## THE HERO BRANCH IS UNTOUCHED CODE. `attack_damage_percent_of_max_hp / 100.0 * max_hp` is the
## expression story 1-5 shipped and nothing about it changes, which is what keeps hero-versus-hero
## combat — and therefore the bulk of the golden fixture — bit-for-bit unmoved.
##
## A UNIT ATTACKER READS ITS OWN KIND'S ATTACK RECORD, with the same two graceful-degradation misses
## `_damage_against_unit` documents (an unresolvable kind, a kind with no attack) answering 0.0 for
## the same reason.
func _damage_against_hero(attacker: PlayerState, attacker_index: int,
		target: PlayerState) -> float:
	if attacker_index == TargetingService.HERO_INDEX:
		return balance.attack_damage_percent_of_max_hp / 100.0 * target.hero.get_max_hp()
	return _attacker_attack_damage(attacker, attacker_index)


func _damage_against_unit(attacker: PlayerState, attacker_index: int) -> float:
	if attacker_index == TargetingService.HERO_INDEX:
		return balance.hero_damage_to_unit
	return _attacker_attack_damage(attacker, attacker_index)


## The authored attack damage of a NON-HERO attacker — a unit's own kind, or, for a projectile, the
## kind that FIRED it. Shared by both target ladders above because the answer does not depend on what
## is being hit: an attack record says what THAT attack does (AC 9).
##
## THE PROJECTILE READS THE FIRING KIND'S RECORD, NOT A COPY TAKEN AT LAUNCH, which is how a shot
## outlives its source without carrying stale authored data (`projectile_board.gd`'s header). The
## totem may already be dead; its KIND is config and is not.
##
## BOTH MISSES ANSWER 0.0 — an unresolvable kind (an X3 reload shortened `unit_kinds` under a live
## record) and a kind that authors no attack. The graceful-degradation direction every authored-data
## miss in this project takes: a record written under an authored list that no longer describes it
## stops hurting anything rather than dealing an invented number.
func _attacker_attack_damage(attacker: PlayerState, attacker_index: int) -> float:
	var kind_index := attacker.projectiles.kind_index_at(projectile_index_of(attacker_index)) \
			if is_projectile_index(attacker_index) \
			else attacker.units.kind_index_at(attacker_index)
	var kind := balance.kind_at(kind_index)
	if kind == null:
		return 0.0
	var attack := kind.attack_at(0)
	return attack.damage if attack != null else 0.0


## Story 6-5a (AC 9, R3): THE DAMAGE FUNNEL -- ONE function every damage seat calls with the damage it
## has already computed (block / dodge multipliers included), returning what Bloodlust makes of it. The
## four seats are the melee/unit/projectile-on-hero seat in `_resolve_contacts`, the unit seat in
## `_resolve_unit_contact`, the dodged-unblockable seat and the unblockable landing package.
##
## BIT-IDENTICAL AT REST, by construction rather than by `x * 1.0`: with no Bloodlust running on either
## side neither branch is taken and `damage` comes back as the same float it went in.
##
## THE BUFFED BODIES ARE THE HERO AND ITS MINIONS, NEVER A TOTEM (R3) -- and never a projectile, which
## today only a totem fires. Outgoing uses the attacker side's dealt multiplier, incoming the target
## side's taken multiplier; both sides buffed compound (2x out, then 2x in).
func _funnel_damage(attacker: PlayerState, attacker_index: int, target: PlayerState,
		target_index: int, damage: float) -> float:
	if attacker.is_rule_active(PlayerState.RULE_BLOODLUST) \
			and _is_bloodlust_body(attacker, attacker_index):
		damage *= attacker.rule_a[PlayerState.RULE_BLOODLUST]
	if target.is_rule_active(PlayerState.RULE_BLOODLUST) and _is_bloodlust_body(target, target_index):
		damage *= target.rule_b[PlayerState.RULE_BLOODLUST]
	return damage


## Whether `index` on `player`'s side is a body Bloodlust covers: the hero, or a MINION on the board.
## The minion test reads the record's kind index against the authored minion kind's index -- the
## resolver's `KIND_MINION` name, never a second literal.
func _is_bloodlust_body(player: PlayerState, index: int) -> bool:
	if index == TargetingService.HERO_INDEX:
		return true
	if is_projectile_index(index):
		return false
	return player.units.kind_index_at(index) == balance.kind_index_of(CardEffectResolver.KIND_MINION)


## Story 6-5a (R4, N10): VAMPIRIC AURA -- the caster's HERO heals `lifesteal_fraction` of the damage it
## ACTUALLY removed. `removed` is measured by the caller as the target's hp before minus after, so it is
## already past block, every multiplier and the target's own floor. Minion, totem and projectile damage
## never heal (the hero-index gate); a dead caster never heals.
##
## RETURNS THE HEAL IT ACTUALLY APPLIED (R6: a one-shot effect's delta, clamped by the caster's max hp),
## so a later undo has something to reverse.
##
## 6-5a REVIEW N8: THE hp-BASED LIVENESS GATE (`hero.is_alive()`, i.e. hp > 0) IS DELIBERATE AND MUST NOT
## BE "MADE CONSISTENT" WITH `_attacker_is_dead`, which tests `action_state == DEAD`. The two disagree on
## exactly one tick and that is the point: on a MUTUAL-KILL tick a hero at 0 hp has not yet been written
## `DEAD` (step 8 does that), so its queued fact still resolves and deals full funnelled damage -- but a
## heal here would put it back above zero BEFORE step 8 reads liveness, reviving the attacker and
## flipping the round's outcome. Switching this gate to `action_state != DEAD` introduces that revive.
## Pinned by `test_spell_framework.gd::test_vampiric_aura_never_revives_its_caster_on_a_mutual_kill`.
func _apply_lifesteal(attacker: PlayerState, attacker_index: int, removed: float) -> float:
	if attacker_index != TargetingService.HERO_INDEX \
			or not attacker.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA) \
			or removed <= 0.0 or not attacker.hero.is_alive():
		return 0.0
	var before := attacker.hero.get_hp()
	attacker.hero.heal(removed * attacker.rule_a[PlayerState.RULE_VAMPIRIC_AURA])
	return attacker.hero.get_hp() - before


## Story 6-5b (AC 1/AC 2, `6-5b/R2`/`6-5b/R10`): THE CORPSE LIFETIME one death at `index` should seed,
## in ticks -- and the ONE place the TOTEM/HERO EXCLUSION is expressed.
##
## IT IS A ZERO FOR ANYTHING THAT LEAVES NO CORPSE, rather than a branch at each of the death seat's
## three callers. `UnitBoard` is a pure container and holds no policy about kinds (see `kill_at`), so
## the decision has to be made here, where `balance` is -- and making it a VALUE rather than a
## conditional call is what keeps all three callers identical and AC 6 true by construction.
##
## THE TOTEM TEST IS THE SAME `kind_index_at` LOOKUP `live_kind_count` ALREADY USES (AC 1's own
## requirement), against the resolver's `KIND_MINION` name and never a second literal. A record whose
## kind an X3 reload has since removed reads `NO_KIND_INDEX` and leaves no corpse -- the
## graceful-degradation direction every authored-data miss in this file takes.
##
## HEROES NEED NO CLAUSE HERE AT ALL (`6-5b/R10`'s other half): a hero is not a `UnitBoard` record, so
## no hero death can reach the death seat. That exclusion is structural, not a check.
##
## `balance` / `balance_ticks` ARE READ INLINE AND MAY BE NULL: a pre-injection `MatchState` (every
## fixture that never calls `apply_balance`) answers 0, which leaves no corpse rather than crashing --
## the `_resolve_actions` pre-injection guard family's own direction.
func _corpse_ticks_for(player: PlayerState, index: int) -> int:
	if balance_ticks == null or not _is_own_minion(player, index):
		return 0
	return balance_ticks.corpse_lifetime_ticks


## Story 6-5b (AC 1/AC 8/AC 10/AC 18): is the record at `index` on `player`'s board a MINION -- the
## one predicate behind "leaves a corpse", "Culling kills it" and "Drain may sacrifice it".
##
## SEPARATE FROM `_corpse_ticks_for` ABOVE, AND THE SEPARATION IS LOAD-BEARING rather than tidy. The
## first draft of this pass used `_corpse_ticks_for(...) > 0` as the minion test, which silently
## conflated two independent facts: with `corpse_lifetime_seconds` authored 0.0 -- a legal degenerate
## value the balance audit permits in tests -- every minion would have read as a non-minion and
## Culling would have killed NOTHING while still spending its orb. "Which kinds are minions" is
## authored content; "how long their corpses last" is a tunable. One predicate each.
##
## THE `kind_index_at` LOOKUP IS `live_kind_count`'s (AC 1's own requirement), against the resolver's
## `KIND_MINION` constant and never a second StringName literal. `NO_KIND_INDEX` can never match a
## record's stored index (the cast seat refuses to add one), so an unauthored or reload-orphaned kind
## answers false -- the graceful-degradation direction.
func _is_own_minion(player: PlayerState, index: int) -> bool:
	if balance == null or not player.units.has_index(index):
		return false
	return player.units.kind_index_at(index) == balance.kind_index_of(CardEffectResolver.KIND_MINION)


## Story 6-5a (R5): the armed Frostbite trigger is CONSUMED by this confirmed hero melee hit and the slow
## lands on the struck enemy hero -- a REFRESH if one is already running (N10). A trigger that is not
## armed does nothing.
##
## 6-5a REVIEW N2 (operator ruling): THE TRIGGER IS NOT SPENT ON A HIT THAT CAN CARRY NO SLOW. Two such
## hits, both of which the dev pass consumed for nothing:
##   (a) THE KILLING BLOW -- the hit that drops the enemy to 0 hp. `_end_round` clears the slow on the
##       same tick, so cancelling here would burn a 4-mana card's whole payload on a corpse. The gate is
##       hp-based (`is_alive()`), matching `_apply_lifesteal`'s, because `DEAD` is not written until
##       step 8 (see that function's own N8 note).
##   (b) A ZERO-OR-SHORTER SLOW -- an effect authored with `slow_duration_seconds` that converts to <= 0
##       ticks. `start_rule` would cancel the slot (N3) while the trigger was spent regardless.
## Both leave the trigger ARMED for the next confirmed hit, the stamina-refused roll's precedent (R2).
func _consume_frostbite(attacker: PlayerState, target: PlayerState) -> void:
	if not attacker.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED):
		return
	if not target.hero.is_alive():
		return
	if int(attacker.rule_b[PlayerState.RULE_FROSTBITE_ARMED]) <= 0:
		return
	target.start_rule(PlayerState.RULE_FROSTBITE_SLOW,
			int(attacker.rule_b[PlayerState.RULE_FROSTBITE_ARMED]),
			attacker.rule_a[PlayerState.RULE_FROSTBITE_ARMED], 0.0)
	attacker.cancel_rule(PlayerState.RULE_FROSTBITE_ARMED)


## Story 4-6 (AC 9/AC 10/AC 11): the step-1c LOCK seat for one player. INGEST then VALIDATE.
##
## A retarget is a plain `[slot, index]` ADDRESS the runner already resolved against the live
## scene -- this layer performs no candidate search, no screen-space work and no distance test.
## `retarget_slot == InputIntent.NO_RETARGET` is a tick with no click and no flick, which leaves
## the standing lock alone: there is no unlock value, because `CC/R2` gives lock-on no unlocked
## state (AC 10, and a flick with no candidate is a no-op the RUNNER produces by sending no
## request at all).
##
## Story 5-1a (AC 1/AC 2, `5-1a/R3`/`5-1a/R9`): the address is now GATED rather than merely
## reported on. Through 4-6 this seat called `Invariant.check` twice and then assigned
## UNCONDITIONALLY on the next two lines -- `Invariant.check` is `push_error` + `assert`
## (`src/systems/invariant.gd:11-14`), and `assert` is stripped in an exported build, so an
## exported build logged the violation and wrote the malformed address into the hashed
## `lock_target` key anyway (`player_state.gd:267`). The branch below is what a stripped `assert`
## cannot skip, and the two `Invariant.check`s are GONE rather than kept alongside it: a retained
## one would print `INVARIANT VIOLATED`, which `test/run_all.sh` greps for and fails the whole
## suite on, so the check and AC 2's own test cannot both be green (`5-1a/R9`).
func _resolve_lock(player: PlayerState, intent: InputIntent, opposing_slot: int) -> void:
	if _is_applicable_retarget(intent):
		player.lock_target_slot = intent.retarget_slot
		player.lock_target_index = intent.retarget_index
	_validate_lock(player, opposing_slot)


## Story 5-1a (AC 1, `4-6` finding M3): TRUE only for an address this layer will actually apply.
##
## REJECTION, NOT A CLAMP (the story's Open Question 2, answered by declining to write): a
## malformed address leaves `lock_target_slot`/`lock_target_index` at whatever they already held,
## so nothing is written to the hashed key on that tick and the next `_validate_lock` still runs
## over the STANDING lock. A clamp would invent an address no one asked for.
##
## The resting `NO_RETARGET` (-1) falls out of the slot test rather than needing its own line, but
## it is named first because it is a DIFFERENT fact about the tick -- no click and no flick (AC 10)
## -- and a reader who has to derive that from `-1 != 0 and -1 != 1` will eventually derive it
## wrong.
static func _is_applicable_retarget(intent: InputIntent) -> bool:
	if intent.retarget_slot == InputIntent.NO_RETARGET:
		return false
	# Story 6-8 (AC 1/AC 2): THE UNLOCK REQUEST is exactly the sentinel address and nothing near it --
	# `[UNLOCKED_SLOT, HERO_INDEX]` applies, while `[UNLOCKED_SLOT, 0]` still falls through to the
	# malformed rejection below. Written as an address so the two guarded assignments in
	# `_resolve_lock` stay the seat's only writes (`5-1a/R9`'s scan).
	if intent.retarget_slot == PlayerState.UNLOCKED_SLOT:
		return intent.retarget_index == TargetingService.HERO_INDEX
	return (intent.retarget_slot == 0 or intent.retarget_slot == 1) \
			and intent.retarget_index >= TargetingService.HERO_INDEX


## Story 4-6 (AC 3, `4-6/R4`/`4-6/R5`): the lock's liveness rule, and the whole of it. A HERO
## address is always valid -- a slot always has a hero, and a DEAD one means the round is over
## and step 1b has already frozen the tick. A UNIT address is valid only while that board index
## exists AND is alive; the instant it is not, the lock snaps to the opposing hero with no
## corpse-hold window, despite the corpse lingering on the board (`4-3d`).
##
## `has_index` BEFORE `is_alive_at`, in that order and not the reverse: a debug reset clears the
## board outright, so the index can be GONE rather than merely dead, and `is_alive_at` on a
## cleared board would read past its arrays.
##
## IDEMPOTENT BY CONSTRUCTION, which is what lets step 1c and step 4b both call it.
##
## Story 6-8 (AC 2/AC 21): the UNLOCKED sentinel carries `HERO_INDEX` in its index half, so it takes
## the hero early-return below and is never "snapped" back -- an unlocked player stays unlocked
## until they relock. That is structural, not a second branch.
func _validate_lock(player: PlayerState, opposing_slot: int) -> void:
	if player.lock_target_index == TargetingService.HERO_INDEX:
		return
	var owner: PlayerState = p1 if player.lock_target_slot == 0 else p2
	if owner.units.has_index(player.lock_target_index) \
			and owner.units.is_alive_at(player.lock_target_index):
		return
	_reset_lock(player, opposing_slot)


## Story 4-6 (`CC/R2`): THE ONE DEFAULT, in one place. The opposing hero, always -- at
## construction, after a debug reset, and after the locked target dies. Callers pass the
## opposing slot because a PlayerState does not know its own index.
func _reset_lock(player: PlayerState, opposing_slot: int) -> void:
	player.lock_target_slot = opposing_slot
	player.lock_target_index = TargetingService.HERO_INDEX


## Story 1-8 (R-D2/R-D3): the facing gate — pure state policy over the runner-reported
## direction fact. True iff the target-to-attacker direction lies within +/- half the
## authored arc of the target's world-space facing (angle_to is magnitude-independent,
## so neither vector needs normalizing; the arc is read inline, CONSTRAINT C). Exact
## float comparison, deliberately no epsilon: a direction at EXACTLY arc/2 lands on
## float rounding, which is fine — real directions are continuous, and the guarded
## behavior is both sides OF the arc, not the measure-zero boundary ray.
func _is_facing(hero: HeroState, target_to_attacker: Vector2) -> bool:
	return absf(hero.facing.angle_to(target_to_attacker)) \
			<= deg_to_rad(balance.block_facing_arc_degrees * 0.5)


## Story 6-1c (AC 5, `6-1c/R3`): THE ARC HALF OF HONEST REACH -- pure state policy over the
## runner-reported direction fact, the 1-8 `_is_facing` shape directly above adopted UNCHANGED for
## mode (2). The runner computes the radius KIND and the planar TARGET -> ATTACKER direction from
## positions only and never reads `facing`; the ANGLE is judged here, against the attacker's frozen
## committed direction (the facing the commit freeze holds), using the colour's authored arc.
##
## THE SIGN: the fact runs target -> attacker (the 1-8 convention) and the attack points attacker ->
## target, so the defender's bearing is the fact's NEGATION -- the same negation the auto-aim applies.
##
## 360 AND ABOVE IS RADIAL and answers true without a comparison, so the GREEN jump needs no special
## case and an unauthored arc (the 360 default) is the pre-6-1c circle exactly. The direction read is
## `_charge_contact_dirs[slot]`, latched by `push_contact` in the SAME arm that latches the `INSIDE`
## kind, so the two halves of the gate always describe the same measurement.
##
## THAT SENTENCE WAS FALSE FOR ONE COMMIT, and the history is recorded so it is not re-broken. Through
## 6-1c both halves were overwritten on every push and so both described the last tick. Story 6-1d's
## dev pass (`e7afe21`) made the verdict ABSORBING across the flight but left this reading the
## every-push `_charge_reach_dirs`, so a verdict from one tick was judged against a bearing from
## another. The 6-1d review fix (`6-1d/R8`) restored it with the latched bearing, and `6-1d/R13` made an
## in-arc latch absorbing (`push_contact` asks this function of the latched bearing). The arc is still a
## conjunct that can only REMOVE a hit the geometry admitted: it reads nothing unless the kind is
## already `INSIDE`, and it can never turn an `OUTSIDE` into a hit.
func _is_in_charge_arc(player: PlayerState, slot: int) -> bool:
	var arc := balance.unblockable_arc_degrees_for(player.charge_color)
	if arc >= 360.0:
		return true
	return absf(player.hero.facing.angle_to(-_charge_contact_dirs[slot])) <= deg_to_rad(arc * 0.5)


## Step-5 mana generation (story 3-4, AC 1/AC 2) — the D6 EVALUATOR seat. The direct
## `balance.melee_hit_mana` grant story 1-5 shipped here is GONE, not kept behind a flag:
## the authored `melee_hit` rule now names that same field and the evaluator dereferences
## it, so this is a refactor of the one existing path and NOT a second call site.
## `melee_mana_generation` is still the off-switch, but it is DATA on the rule now
## (`required_flag`), so both flag configurations run through the same evaluator call —
## flag OFF simply resolves to 0.0 and ManaPool.add() no-ops. No flags injected reads the
## same way (graceful degradation, unchanged from 1-5).
## The live `balance` / `balance_ticks` / `flags` are passed IN on every call and never
## retained by the evaluator (CONSTRAINT C — it is static and stateless).
##
## STORY 4-3a (AC 5, decided by Matko — `4-3a/R3`): A CONFIRMED HIT AGAINST A UNIT GENERATES NO
## MANA, and this function is deliberately UNCHANGED by that. The gate is upstream, at the one place
## the list is built: `_resolve_unit_contact` never appends to `confirmed_hits`, so a unit-target
## confirmation cannot reach the melee rung below. A second check HERE would be a second gate to
## keep in agreement with the first, and the first is the one that owns the list.
##
## Note the rung this runs to (`4-3a/R21c`, a citation correction): the PASSIVE rung at the bottom
## is part of this seat, not a separate one — a pre-gate citation of "733-739" clipped it.
func _generate_mana(confirmed_hits: Array[int]) -> void:
	var rules := EconomyEvaluator.authored_rules()
	var per_hit := EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
			EconomyEvaluator.MANA, balance, balance_ticks, flags)
	for slot in confirmed_hits:
		var attacker := p1 if slot == 0 else p2
		attacker.mana.add(per_hit)
	# The PASSIVE rung (story 3-4, AC 4) — the second faucet, same step, same slot, fixed
	# P1 -> P2 order. Sealed semantics: no delay window, suppressed for DEAD only, NOT
	# suppressed for BLOCKING (mana building behind a block IS the flywheel's point, and
	# block already pays through the stamina suppression — it is not double-charged).
	# The round-over freeze needs NO guard here: step 1b returns before step 5 is reached,
	# so a frozen tick never runs this at all.
	var per_tick := EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_PASSIVE_TICK,
			EconomyEvaluator.MANA, balance, balance_ticks, flags)
	_regen_mana(p1, per_tick)
	_regen_mana(p2, per_tick)
	# THE MANA ACCELERATOR RUNG (story 4-4, AC 20) — the THIRD `amount_for` call site, and the story
	# named it as a requirement rather than leaving it to be discovered: `EconomyEvaluator` has been
	# able to LOAD a `mana_accelerator` rule since 3-4 (its header even predicted this totem by
	# name), but nothing scans authored rules BY SOURCE, so a rule nobody asks for is loaded and
	# never queried. This is the asking.
	#
	# GATED THREE WAYS, and each gate is a different question:
	#   * THE CADENCE, `_tick % mana_accelerator_interval_ticks` — AC 20's "on some authored
	#     cadence". The divisor is clamped >= 1 at the conversion boundary, so an authored 0 means
	#     "every tick" rather than a divide-by-zero (the `minion_retarget_interval_ticks` shape).
	#   * HOW MANY LIVE ACCELERATORS ARE ON THAT PLAYER'S OWN BOARD — "while a Mana Accelerator totem
	#     is alive", generalised from a bool to a COUNT by story 5-1 (AC 5, `R-M9` Reading A per
	#     `E5-P/R3`). Per-player and read fresh every boundary tick, so the faucet opens the tick the
	#     totem is summoned and closes the tick it dies, with no teardown path to forget.
	#
	# STORY 5-1 (AC 5): THE BOOL GATE IS GONE AND THE COUNT IS THE MULTIPLIER. Each of a player's own
	# live accelerators pays its own authored amount on the same cadence tick — Reading A, linear and
	# player-countable ("each totem contributes its own effect where it sits"), NOT the compounding
	# cadence Reading B that `E5-P/R3` rejected as superlinear. `N = 0` pays nothing, exactly as the
	# bool gate did: `accelerated * 0` is `0.0`, and `ManaPool.add(0.0)` early-returns before mutating
	# or signalling (`mana_pool.gd:20-25`), so the un-gated call is byte-identical to not calling —
	# which is why removing the `if` is safe rather than merely tidy.
	#   * THE `totems` FLAG, which is DATA on the authored rule (`required_flag`) rather than a
	#     fourth check here — the project-context HARD RULE satisfied the way `melee_hit.tres`
	#     already satisfies it, so both flag configurations run through the same evaluator call and
	#     a closed flag simply resolves to 0.0.
	#
	# IT ROUTES THROUGH `_regen_mana`, NOT `mana.add()` DIRECTLY, so a DEAD owner earns nothing —
	# the standing `2-3/R5` doctrine that a corpse runs no economy, inherited rather than re-stated.
	if _tick % balance_ticks.mana_accelerator_interval_ticks == 0:
		var accelerated := EconomyEvaluator.amount_for(rules,
				EconomyEvaluator.SOURCE_MANA_ACCELERATOR, EconomyEvaluator.MANA, balance,
				balance_ticks, flags)
		_regen_mana(p1, accelerated * live_kind_count(p1, CardEffectResolver.KIND_MANA_ACCELERATOR))
		_regen_mana(p2, accelerated * live_kind_count(p2, CardEffectResolver.KIND_MANA_ACCELERATOR))


## Step-5 passive mana (story 3-4, AC 4) — the POLICY seat beside _regen_stamina's (D6).
## Mana's suppression set is deliberately NARROWER than stamina's: DEAD only. A corpse runs
## no economy (the standing 2-3/R5 doctrine), but a blocking hero keeps charging.
func _regen_mana(player: PlayerState, amount_per_tick: float) -> void:
	var suppressed := player.hero.action_state == HeroState.ActionState.DEAD
	player.mana.advance_regen(amount_per_tick, suppressed)


## Step-5 stamina regen (story 1-4). The per-tick amount is read inline from balance_ticks
## (CONSTRAINT C); the pool owns the mechanism (fixed add + post-spend delay window), THIS
## is the policy seat (D6): regen is suppressed while the hero is BLOCKING — block entry is
## free, so block must cost time or holding it would be free and P2 ("aggression is
## economy") unenforced; suppressed likewise while DEAD, since a corpse runs no economy
## (story 2-3). Every other action state regenerates.
func _regen_stamina(player: PlayerState, actually_running: bool) -> void:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero is skipped the SAME way a BLOCKING one already is
	# (the D6 suppression) — a corpse runs no economy. This extends the existing suppression
	# flag; it is a DIFFERENT function and step from the P2 movement gate (do not merge them).
	var state := player.hero.action_state
	# Story 5-2 (AC 14, `5-2/R4`): CHARGING JOINS THE SUPPRESSION LIST, beside BLOCKING and DEAD and
	# for BLOCKING's exact reason: the chargeup costs TIME as well as stamina, and a hero whose pool
	# refilled while rooted would pay less for mode (2) the longer the window is. One more term on
	# the existing flag, never a second gate.
	# Story 6-7 (AC 8): RUNNING JOINS THE SUPPRESSION LIST, a fourth disjunct on the same policy
	# seat -- `actually_running` is the exact AC 7 predicate this tick's `_resolve_movement` already
	# computed (Dev Notes Open Question 5: computed once and handed back, never re-derived here),
	# so a run-held-but-forced-to-walk tick (the R6 lockout) never wrongly suppresses regen the
	# moment the design needs it running so the bar can cross the resume threshold (Fact M3).
	var suppressed := state == HeroState.ActionState.BLOCKING \
			or state == HeroState.ActionState.DEAD \
			or state == HeroState.ActionState.CHARGING \
			or actually_running
	# Story 4-4 (AC 21, `4-4/R11`): THE STAMINA ACCELERATOR, applied HERE as a factor on the derived
	# per-tick rate — the dev-pass mechanism choice the AC leaves open, and the reasoning is recorded
	# in the story's Dev Agent Record rather than only here.
	#
	# OWNER-ONLY IS STRUCTURAL, NOT CHECKED (`4-4/R11`: "only the summoning player's hero's stamina
	# regen is raised ... the opponent's regen is untouched"). This seat is ALREADY per-player and it
	# consults `player.units` — that player's OWN board — so there is no cross-player path to get
	# wrong. A totem on P1's board cannot reach this line for P2 because P2's call passes P2.
	#
	# NOT A PER-PLAYER DERIVED RATE AT `apply_balance()`, and that is the `3-1/R2` boundary rather
	# than a preference. The per-pool reload contract governs POOL BOUNDS (stamina: `set_maximum` +
	# `refill`); a regen multiplier is not a bound, and deriving it at reload time would make the
	# accelerator's effect depend on WHEN a reload happened instead of on whether the totem is alive
	# right now — a totem summoned mid-round would do nothing until the next reload, and one that
	# died would keep paying out. Read at the regen seat, the factor tracks liveness exactly, and it
	# returns to the non-accelerated value on the tick the totem dies with nothing to tear down.
	#
	# THE POOL IS UNTOUCHED. `advance_regen(amount, suppressed)` already takes the amount per call,
	# so the pool still owns only the MECHANISM and this stays the POLICY seat (D6).
	# STORY 5-1 (AC 7, `5-1/R1`): LINEAR, NOT `mult^N`. The bool gate and the single authored
	# multiplier are replaced by `1 + N x step`, where `N` is the player's own live stamina
	# accelerator count. Matko's ruling, by content: the player counts totems rather than exponents,
	# `mult^N` explodes at the third totem, and this is the shape the mana seat already had. The
	# authored `step` is DERIVED so that `N = 1` reproduces today's shipped factor exactly
	# (`1 + 1 x 0.5 = 1.5`), so the FIRST totem does not move balance — only the second and third do.
	#
	# THE MULTIPLICATION IS UNGATED, and that is deliberate rather than careless. At `N = 0` the
	# factor is `1 + 0 x step = 1`, the exact identity, so the non-accelerated rate is unchanged
	# without an `if` to keep in agreement with anything. It also makes M2's defect structurally
	# impossible instead of merely re-audited: an unauthored `step` defaults to `0.0`, which under an
	# ADDITIVE term is the identity at every `N` — where the OLD multiplicative field's `0.0` default
	# ZEROED the regen of the one player who actually had a totem (`4-4` M2, `_44-review.md:330`).
	#
	# `balance` IS NULL-GUARDED for `has_live_kind`'s own reason, verbatim: the gate used to swallow a
	# null balance before the field was ever dereferenced, and un-gating the arithmetic must not
	# quietly turn that into a crash. A null balance degrades to the identity, not to an error.
	var per_tick := balance_ticks.stamina_regen_per_tick
	var accelerators := live_kind_count(player, CardEffectResolver.KIND_STAMINA_ACCELERATOR)
	var step := 0.0 if balance == null else balance.stamina_accelerator_regen_step
	per_tick *= 1.0 + float(accelerators) * step
	player.stamina.advance_regen(per_tick, suppressed)
	# Story 6-7 (AC 10, `6-7/R14`): THE LATCH CLEARS HERE, automatically, the instant stamina
	# reaches the authored resume threshold -- the earliest a crossing tick's OWN gait read can
	# reflect it is therefore the NEXT tick's `_resolve_movement` (this function runs AFTER it in
	# advance()'s step order), matching AC 10's "next tick, no re-press" ruling exactly.
	if balance != null and player.hero.run_locked_out and player.stamina.get_current() \
			>= balance.run_resume_stamina_percent / 100.0 * balance.max_stamina:
		player.hero.run_locked_out = false


## Story 4-4 (AC 20/AC 21): whether `player`'s OWN board carries a LIVE unit of the named kind.
##
## PUBLIC because both accelerator seats and the tests that pin them ask it, and because it is the
## one expression of "this totem is currently doing its job" — a second copy at either seat would be
## a second thing to keep in agreement, which is the `UnitBoard.has_index` discipline applied one
## level up.
##
## IT IS A PURE QUERY over plain facts: a name in, a bool out, no mutation and nothing retained. It
## is NOT an intake and carries no capture channel, for `unit_attack_phase_multiplier`'s reason —
## but unlike that one it takes NO data inward that a replay would have to restore, since a replay
## that reproduces the board reproduces this answer.
##
## LIVENESS IS `UnitBoard.is_alive_at`, never a re-derived `hp > 0` (`4-3a/R14`), so a dead totem's
## hole stops the faucet on the tick it dies without a second liveness seat existing anywhere.
##
## AN UNAUTHORED KIND NAME ANSWERS FALSE rather than tripping a guard: `kind_index_of` returns
## `NO_KIND_INDEX`, which no record can carry (the cast seat refuses to add one), so the scan finds
## nothing. A faucet whose kind is not authored is simply shut — the graceful-degradation direction.
## Story 5-1 (AC 1): kept as a ONE-LINE FORWARD onto the counting sibling rather than retired, so
## every existing caller and the tests that pin them read the same answer from the same scan. Two
## loops answering "is there one" and "how many" would be two things to keep in agreement, which is
## the very duplication this function's own header rejects one level down.
func has_live_kind(player: PlayerState, kind_name: StringName) -> bool:
	return live_kind_count(player, kind_name) > 0


## Story 5-1 (AC 1): how many LIVE units of the named kind sit on `player`'s OWN board — the bool
## above generalised to the count both accelerator seats now multiply by (AC 5, AC 7).
##
## IT INHERITS EVERY PROPERTY OF ITS PREDECESSOR RATHER THAN RESTATING THEM: pure query, per-owner,
## `UnitBoard.is_alive_at` liveness (never a re-derived `hp > 0`, `4-3a/R14`), and the KIND-LOOKUP
## EARLY-OUT — an unauthored kind name answers `0` at the lookup, BEFORE the board is scanned, the
## same graceful degradation `has_live_kind` answered `false` with. That early-out is load-bearing
## for the golden (AC 11): `_golden_config` authors only `&"minion"`, so both accelerator names miss
## the lookup and `N` is identically `0` for both players on every recorded tick.
##
## NO CAP OF ANY KIND (AC 4, an explicit non-goal): nothing here clamps the count. `N` is bounded
## only by the deck's `max_copies` and by totems being killable — both facts that already exist
## outside this story.
func live_kind_count(player: PlayerState, kind_name: StringName) -> int:
	if balance == null:
		return 0
	var kind_index := balance.kind_index_of(kind_name)
	if kind_index == BalanceConfig.NO_KIND_INDEX:
		return 0
	var count := 0
	for index in player.units.size():
		if player.units.is_alive_at(index) and player.units.kind_index_at(index) == kind_index:
			count += 1
	return count


## Step-6 deck deal (story 3-3, AC 7/AC 9) — the ONE SEAT. Runs at most once per tick, and only
## when something armed it: the match-start injection or a debug reset ingested at step 1 this
## same tick. There is no round-start event in the game (round_started fires only FROM the debug
## reset, whose own comment calls it an operator affordance and not a gameplay path), so "round
## start" for the fill means exactly those two occasions and nothing else.
##
## Player order is fixed P1 -> P2 for determinism, and both piles are laid down from the SAME
## injected composition and shuffled against the SAME generator in turn — which is how the two
## players get different orders out of one seed without a second RNG ever existing.
##
## `balance == null` joins the pre-injection guard family (step 3's _resolve_actions, step 5's
## regen, step 4's twin): hand_size has no value to read yet. The latch is deliberately NOT
## cleared on that path, so a match that receives its deck before its balance still deals on the
## first tick after apply_balance() instead of silently never dealing.
func _deal_pending_decks() -> void:
	if not _deck_deal_pending or balance == null:
		return
	_deck_deal_pending = false
	_deal_player(p1)
	_deal_player(p2)


## The per-player half: full composition down, shuffle, hand emptied, then fill from the TOP.
##
## The debug-reset occasion RESTORES the full composition rather than returning cards from
## anywhere — there is nowhere to return them TO (no discard pile ships, AC 11) — and AC 9 pins
## the post-reset counts to the same hand_size / deck_size - hand_size pair as match start.
##
## hand_size is read INLINE at the moment of use (CONSTRAINT C): a snapshot-the-value read in
## the TimingWindow.start() shape, never a cached BalanceConfig reference, so a hot reload takes
## effect at the next deal instead of half-applying to one already in flight.
##
## The is_empty() stop is a FLOOR here too, but it is no longer the LAST word: story 3-5b gives
## the pile a way back (the lazy reshuffle at delivery time), and the authoring audit still keeps
## hand_size <= deck_size so this initial fill never reaches the floor.
func _deal_player(player: PlayerState) -> void:
	player.deck.set_contents(_deck_contents)
	_shuffle_deck(player.deck)
	# Story 4-0 (AC 1, `4-0/R2`): the WIDTH is established HERE, at the deal seat, and nowhere
	# else. `balance.hand_size` is read INLINE at the moment of use (CONSTRAINT C) and handed in;
	# `Hand` never learns of BalanceConfig, never holds a config reference and never names
	# hand_size. A Hand that has never been dealt to therefore has width 0, which is what keeps
	# the pre-deal `hand_size` snapshot reading 0 without a special case.
	player.hand.clear(balance.hand_size)
	# Story 3-5a: the discard is emptied HERE, beside the hand, because this is the seat that
	# re-lays the whole composition. Without it a debug reset would restore every card to the
	# deck AND leave the played ones in the discard, so "deck + hand + discard is a permutation
	# of the injected composition" — the property test_card_play.gd pins — would break on the
	# first reset after a cast. This is the reset's discard answer; the RESHUFFLE (returning the
	# discard to the deck mid-round) is 3-5b's and is deliberately not here.
	player.discard.clear()
	# Story 3-5b (AC 9): the debug reset KILLS a pending draw, and the owed card is NOT restored
	# — it is already back in the pile, because this seat re-lays the FULL injected composition
	# two lines above. Conservation is therefore restored by construction and 3-3's AC 9 post-reset
	# count pin needs no special case. start(0) is the kill: TimingWindow.start() sets is_running
	# from `duration_ticks > 0`, so a zero duration leaves the window stopped AND its snapshot at
	# all-zeros — no bespoke stop() path, which is what keeps AC 7's early-abort scan honest.
	player.pending_draw_owed.clear()
	player.pending_draw.start(0)
	# Story 4-0 (AC 5, `4-0/R4`): the fill loop is REWRITTEN, not merely reviewed. `hand.clear()`
	# now PRE-FILLS the authored width with markers (the width arriving from here, read inline per
	# CONSTRAINT C — `Hand` never names hand_size), so the old `hand.add()` append would have
	# written PAST that width and produced a 2 * hand_size array. An indexed in-place write is
	# mandatory, and `Hand.add` no longer exists precisely so this could not be got wrong quietly.
	#
	# The post-fill state is UNCHANGED from before this story for every case the authored balance
	# reaches: the authoring audit keeps hand_size <= deck_size, so the is_empty() floor below is
	# never hit and every slot holds a card with no hole left behind. The floor is retained anyway
	# — it is the same defensive stop the pre-4-0 loop carried, and a hand_size > deck_size
	# authoring would leave trailing HOLES rather than a short hand, which AC 3 then refuses per
	# slot instead of silently renumbering the rest.
	for slot_index in balance.hand_size:
		if player.deck.is_empty():
			break
		player.hand.fill_at(slot_index, player.deck.draw_top())
	# Story 3-6 (AC 2): the FIRST of the three announcement seats — one per seat that moves a
	# card, placed after the whole occasion completes rather than per container touched, so the
	# deal announces one settled payload instead of three intermediate ones.
	player.notify_cards_changed()


## Story 3-5a (AC 2/AC 9): the CARD-ACTION dispatch — a PRIVATE MatchState method called at
## step 6, deliberately not a free function and not a new class, because the mutation must stay
## inside advance()'s ordered dispatch (D2) where every other mutation lives. The architecture
## doc's Novel Pattern 6 sketch shows a free-standing `resolve()` with no owning class named;
## nothing of that shape existed in src/ and none is introduced here (the eighth
## architecture-amendment-queue member).
##
## FROZEN TICKS NEVER REACH THIS FUNCTION, and that is the whole frozen-tick contract: step 1b
## returns before step 2, so on a round-over tick no intent is ingested at all and a committed
## cast is DROPPED SILENTLY — no state change, no signal, not even a rejection. That is
## CONSISTENT with every other intent during the freeze (attack, block, roll and move are all
## dropped the same way, for the same structural reason) and it is why card intent is NOT read
## inside step 1b. Emitting a rejection for casts alone would require reading card intent there
## and would make a cast the ONE action with freeze feedback — a privilege nothing else has.
## This closes the readiness-gate finding that no contract existed for a cast on a frozen tick:
## the contract is silence, ruled and pinned (test_card_play.gd::test_cast_on_a_frozen_tick_is
## _dropped_silently), not an omission for a later gate to rediscover as a defect.
##
## The DEAD guard below is the LIVE-tick counterpart and is DEFENSE IN DEPTH, in the same family
## as the DEAD branches at step 3 (_resolve_movement), step 4 (_resolve_contacts) and step 5
## (_generate_mana): DEAD and _round_over are set TOGETHER by _end_round, and cleared together by
## the debug reset, so a DEAD player is always also frozen and this branch is unreachable in
## natural play. Its siblings are unreachable for the same reason and are guarded anyway; each is
## pinned by the same forced-DEAD test idiom (`set_action_state(DEAD)` with _round_over left
## FALSE), which is how this one is proven non-vacuous too. It returns SILENTLY, like every
## sibling — a corpse gets no rejection feedback.
##
## NO `balance == null` GUARD, deliberately unlike its step-3/4/5 neighbours: that family exists
## to stop reads of unset balance FIELDS, and this path reads none. Costs come from the injected
## map and values from the pools. A pre-injection match has an empty hand, so a commit there
## takes the empty-slot rejection, which is a true statement about that match rather than an
## inert-guard violation.
func _resolve_card_action(player: PlayerState, intent: InputIntent, slot: int) -> void:
	if not intent.card_commit:
		return
	if player.hero.action_state == HeroState.ActionState.DEAD:
		return
	# Story 6-6a post-smoke ruling `6-6a/R7`: THE GET-UP IS A LOCKED ACTION -- the CARD
	# half of it. One gate ahead of the mode dispatch covers all four modes, so an unblockable
	# initiation, a defense answer, a summon and a pitch are refused identically while the AC 8 window
	# runs; the per-mode `STUNNED` gates further down are untouched and still do their own job.
	#
	# IT ANNOUNCES, unlike the step-3 half (see `_resolve_actions`): this path refuses by an explicit
	# gate with a reason token, exactly as it does for `STUNNED`, so the player hears why. BELOW the
	# DEAD guard, deliberately -- a corpse gets no rejection feedback, and its sibling guards all sit
	# under that same line.
	if player.hero.is_getting_up():
		player.hero.reject_action(&"card_cast", REASON_GETTING_UP)
		return
	# STORY 6-6b (AC 2): THE COUNTER BUSY LOCK -- the CARD half, one gate ahead of the mode dispatch
	# exactly as the get-up gate directly above is, so all four modes (basic, unblockable initiation,
	# defense, pitch) are refused identically while a counter runs. It ANNOUNCES for the get-up gate's
	# stated reason: this path refuses by an explicit gate with a reason token, so the player hears why.
	#
	# IT SUPERSEDES `5-5`'s "re-casting while a window is already running RESTARTS it" dev-pass choice,
	# which was a choice about a PRE-ARM: restarting a busy span mid-counter would let a second press
	# extend the root -- and, post-R-S6, the counter window with it -- indefinitely. The card and the
	# stamina are NOT spent on the refusal (this gate precedes every mutation), so a mashed second press
	# costs nothing but the refusal.
	if player.defense_window.is_running:
		player.hero.reject_action(&"card_cast", REASON_COUNTERING)
		return
	# Story 6-2 (AC 17a): EVERY declared `Enums.ModeKind` now has its own arm below, so the `_` arm is no
	# longer a guarded stub for an unshipped mode -- it is the total-function default for an int that
	# is not a ModeKind at all (a corrupt intent), and reaching it is still a programming error, not a
	# player-facing refusal. Invariant.check is the guard helper.
	match intent.card_mode:
		Enums.ModeKind.BASIC:
			_resolve_basic_cast(player, intent.card_slot, slot)
		# Story 5-2 (AC 1): mode (2) gets its own arm in this same `match`, and stops reaching the
		# guarded stub below. TWO of the four modes remain unreachable -- DEFENSE is `5-5`'s and
		# PITCH is E6's -- so the `_` arm keeps its `Invariant.check(false` verbatim and
		# test_card_play.gd's source scan is NARROWED rather than deleted (AC 9).
		Enums.ModeKind.UNBLOCKABLE:
			_resolve_unblockable_cast(player, intent.card_slot, slot)
		# Story 5-5 (AC 1): mode ③ gets its own arm in this same `match`. ONE of the four modes
		# now remains unreachable -- PITCH is E6's -- so the `_` arm keeps its
		# `Invariant.check(false` verbatim and test_card_play.gd's source scan is NARROWED a
		# SECOND time rather than deleted (the `5-2/R8` precedent, applied again).
		Enums.ModeKind.DEFENSE:
			_resolve_defense_cast(player, intent.card_slot, slot)
		# Story 6-2 (AC 3): mode ④ gets its own arm, the fourth and last. Story 6-3a (AC 5) branches it
		# on `card_activate`: `false` (the resting value, and every pre-6-3a commit) STAGES the armed hand
		# slot exactly as before; `true` ACTIVATES this player's own staged card. Reusing this arm is
		# what hands activation the DEAD guard above and `advance()`'s round-over freeze for free.
		Enums.ModeKind.PITCH:
			if intent.card_activate:
				_resolve_pitch_activate(player, slot)
			else:
				_resolve_pitch_stage(player, intent.card_slot, slot)
		_:
			Invariant.check(false,
				"card mode %d has no dispatch arm (every declared ModeKind resolves; this int is not one)"
						% int(intent.card_mode))


## Story 3-5a (AC 5): Mode ① resolution — mana spent, card out of the hand, card into the
## discard, effect signal queued.
##
## STORY 3-5b (AC 3) AMENDS THE LAST STEP: the replacement is no longer drawn here. 3-5a's
## instant refill is REPLACED by a debt plus a timer, delivered at the end of step 6 (see
## _deliver_pending_draw). Everything else about this function is unchanged, including the fact
## that the mana spend, the hand removal and the discard all still happen within this one tick.
##
## REJECTIONS RIDE THE SHIPPED SEAM (AC 7): HeroState.reject_action — the same queued
## action_rejected signal and the same per-slot observation seam that already carries the
## insufficient-stamina roll rejection to StateInspector. No new signal, no new seam, seam count
## unchanged. The action name is the prefix-free &"card_cast", matching the &"roll"/&"attack"
## vocabulary the existing rejections use.
##
## THE EVALUATOR COMPUTES, THE POOL APPLIES (AC 3): CastEvaluator returns a reason and touches
## nothing; the spend below goes through ManaPool.spend(), inside this ordered dispatch. The
## spend cannot fail after an ALLOWED verdict — the evaluator has just compared the same cost
## against the same live reading — so a false return is a programming error and says so.
func _resolve_basic_cast(player: PlayerState, hand_slot: int, slot: int) -> void:
	# Story 4-0 (AC 3): TWO paths to ONE reason. The bound check survives and is now a WIDTH bound;
	# the HOLE test joins it as a SECOND path to the SAME refusal, not a new one and not a
	# replacement for the first. `Hand.is_slot_empty` folds both together — it reports "holds no
	# card" for an out-of-range index too — so the two cases cannot drift apart into two reasons.
	#
	# NO SIBLING TOKEN SHIPS (`3-5b/R8`'s surviving clause): CastEvaluator.REASON_EMPTY_SLOT is
	# reused verbatim, riding the same shipped HeroState.reject_action / action_rejected seam and
	# the same per-slot observation seam 3-5a already ships. A hole IS an empty slot — inventing
	# REASON_HOLE would be naming the mechanism instead of the player-visible fact.
	#
	# `3-5b/R8`'s "a cast is not gated on a pending draw" SURVIVES NARROWED (`4-0/R5`): no cast is
	# gated on the DEBT — nothing here consults pending_draw_owed, and casting a DIFFERENT slot
	# with a draw in flight still resolves. What is refused is a cast against the slot whose OWN
	# replacement is in flight, which is a statement about that slot being empty, not about the
	# debt. "Mana stays the only throttle" is SUPERSEDED: mana remains the only ECONOMIC throttle,
	# and slot occupancy is now a second, structural, player-observable precondition.
	# STORY 5-6 (AC 16): THE CHARGING HOLE CLOSES, and it closes HERE -- the FIRST gate, ahead of the
	# empty-slot check, mirroring `_resolve_defense_cast`'s exact ordering (state gate before slot
	# gate). Until this story `_resolve_basic_cast` read `action_state` NOWHERE in its body: `5-5`'s
	# AC 3 states the omission BY DESIGN for BLOCKING/ATTACKING/ROLLING ("an instant summon that
	# interrupts nothing"), but that reasoning never covered CHARGING, and `5-5`'s own Open Questions
	# named the gap and assigned it here. A hero mid-chargeup could summon; a stunned hero could too.
	#
	# TWO ARMS, ONE GATE, TWO REASONS. `REASON_UNBLOCKABLE_COMMITTED` is reused VERBATIM for CHARGING
	# (it already reads true: "cannot cast because committed to an unblockable"); the STUNNED arm takes
	# the shared `REASON_STUNNED`, since "committed to an unblockable" does not describe a stunned
	# caster.
	#
	# NOTHING ELSE ABOUT MODE (1) OR THE `5-2` CHARGEUP CHANGES (Non-Goals):
	# `_resolve_unblockable_cast`, `_unblockable_refusal_reason` and `TRANSITION_TABLE` are untouched.
	if player.hero.action_state == HeroState.ActionState.CHARGING:
		player.hero.reject_action(&"card_cast", REASON_UNBLOCKABLE_COMMITTED)
		return
	elif player.hero.action_state == HeroState.ActionState.STUNNED:
		player.hero.reject_action(&"card_cast", REASON_STUNNED)
		return
	if player.hand.is_slot_empty(hand_slot):
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_EMPTY_SLOT)
		return
	# Story 4-0 (AC 7, second part): the ORDERING BELOW IS PINNED, not incidental. The hole is
	# refused at the guard directly above, BEFORE the cost map is ever consulted — so the empty
	# marker can never reach `_card_costs.get(id)` and can never be evaluated for affordability.
	# That is what makes "a hole is never rendered as an affordable card" true on the STATE side
	# by construction rather than by a lookup that happens to miss. Do not move the cost lookup
	# above the guard, and do not add a path that reaches it with an unvalidated slot.
	var id: StringName = player.hand.to_array()[hand_slot]
	var condition: CardCastCondition = _card_costs.get(id)
	var reason := CastEvaluator.refusal_reason(condition, player.mana.get_current(),
			player.orbs, flags)
	if reason != CastEvaluator.ALLOWED:
		player.hero.reject_action(&"card_cast", reason)
		return
	# Story 6-5b (AC 13/AC 21, `6-5b/R14`): THE BOARD-AWARE PRE-SPEND GATE, seated HERE -- immediately
	# beside the insufficient-mana refusal directly above and BEFORE the spend on the next line, which
	# is the ruling's own wording. Nothing below this point can be reached without a target, and
	# nothing above it has mutated anything, so a refusal leaves the mana, the hand and the board
	# exactly as they were (AC 13's "nothing is spent").
	#
	# IT SUPERSEDES, FOR THESE FOUR EFFECTS ONLY, `4-1/R3`/`4-1/R10`'s "NOTHING BELOW THIS LINE IS
	# CONDITIONAL ON THE VERDICT" and 6-5a AC 5 with it -- `6-5b/R14` says so explicitly. That rule
	# was about the RESOLVER's verdict, which is computed after the cast has already happened; this is
	# a PRECONDITION consulted before it happens, which is why it can be a player-facing refusal at
	# all. The unconditional rule stands unweakened for every other effect: the comment below this
	# function's spend sequence is untouched and still true of every id with no board requirement.
	var gate := _board_refusal_reason(player, _card_effects.get(id))
	if gate != &"":
		player.hero.reject_action(&"card_cast", gate)
		return
	Invariant.check(player.mana.spend(condition.mana_cost),
		"an ALLOWED cast must be affordable — CastEvaluator and ManaPool disagree")
	var played := player.hand.remove_at(hand_slot)
	player.discard.add(played)
	# Story 4-1 (AC 1/AC 4/AC 5/AC 6): CardEffect's FIRST CONSUMER, seated here because `played`
	# is the id the effect map is keyed by and this is the moment the cast has actually happened.
	# The evaluator COMPUTES and this line APPLIES (D6): CardEffectResolver returns one of four
	# named outcomes and touches nothing, and the ONE outcome that mutates appends the record here,
	# inside advance()'s ordered dispatch, exactly as the mana spend goes through ManaPool.spend()
	# five lines above.
	#
	# NOTHING BELOW THIS LINE IS CONDITIONAL ON THE VERDICT, and that is AC 5's whole content: the
	# cast has already passed CastEvaluator, so mana stays spent, the card stays discarded and the
	# replacement stays owed for EVERY outcome — a `spell_*` no-op, a missing entry and an unknown
	# prefix are all SUCCESSFUL casts that happen to put nothing on the board.
	#
	# NO reject_action, ON ANY PATH (`4-1/R3`, `4-1/R10`). The refusal seam directly above this
	# function's two guards is for casts that did NOT happen; rendering a resolved cast as a
	# player-facing refusal would be a lie about the match. The reason is a RETURNED VALUE, and
	# asserting it in the unit suite is the whole of its contract — which is why it is not stored,
	# not signalled and not snapshotted.
	#
	# `flags` is read INLINE (CONSTRAINT C), never cached, exactly as the CastEvaluator call above
	# reads it.
	# Story 4-4 (AC 1): THE TOTEM/MINION SPLIT LANDS HERE, at cast time, which is what AC 1 means by
	# "each resolve to a distinct on-board kind AT CAST TIME". The resolver answers two questions in
	# sequence — is this a summon at all (unchanged), and if so WHICH kind — and this seat APPLIES
	# the second answer by turning the kind NAME into the plain int index the record stores.
	#
	# STORY 6-5a (AC 4/AC 5): the APPLY half now lives in `_apply_card_effect`, SHARED with pitch
	# activation so the whole-id dispatch has exactly one apply seat. The summon branch moved there
	# verbatim; its behaviour is unchanged.
	_apply_card_effect(player, _card_effects.get(played), slot)
	# Story 6-5a (AC 10): the hashed last-resolved-card record, written at the resolution seat.
	player.record_resolved_card(played, Enums.ModeKind.BASIC)
	# Story 3-5b (AC 3): the replacement is now OWED, not drawn. 3-5a's instant refill lived
	# exactly here; it is REPLACED, not kept behind a flag. The debt is incremented and the window
	# started, and the delivery happens at the end of this same step 6 — immediately if the
	# derived delay is zero ticks, `delay` ticks later otherwise.
	#
	# A CAST IS NOT GATED ON A PENDING DRAW (AC 3): no check above this line consults the debt, no
	# new rejection reason ships, and mana remains the only throttle. Casting again with a draw in
	# flight simply owes a second card.
	#
	# balance_ticks is read INLINE (CONSTRAINT C) and is non-null here by construction, which is
	# why this seat keeps its "NO balance == null guard" property: a hand can only be non-empty if
	# the step-6 deal ran, and the deal returns early while balance is null.
	#
	# STORY 4-0 (AC 4): the debt records WHICH SLOT. `hand_slot` is the slot just vacated one line
	# above, appended to the FIFO so the replacement lands back in it rather than at the end of the
	# hand. Two casts against two different slots each owe their own slot, and neither delivery can
	# ever land in the other's.
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	# Story 3-6 (AC 2): the SECOND announcement seat. The hand is one short here and stays so
	# until the delivery announces again — which is a true statement about the match and exactly
	# what the HUD should render while a draw is in flight, not a gap to paper over.
	player.notify_cards_changed()
	_queue.push(card_cast_resolved.emit.bind(slot, played, Enums.ModeKind.BASIC))


## Story 6-5a (AC 4/AC 5, AC 15/AC 16): THE ONE APPLY SEAT for a resolved card effect, reached from the
## two resolutions that can carry one -- a Mode ① cast and a Mode ④ ACTIVATION. `CardEffectResolver`
## COMPUTES the outcome and touches nothing; this function APPLIES it inside `advance()`'s ordered
## dispatch (D6). Every outcome that is not handled below -- a no-op, a closed layer, a missing entry,
## an unknown id -- applies nothing, and the cast has still resolved (`4-1/R3`/`4-1/R10`): nothing here
## refunds and nothing reaches `reject_action`.
##
## EVERY BUFF IS STARTED ON THE CASTER'S TIMED-RULE SEAT, with its authored seconds converted to ticks
## here, once, at the application (A1). Re-applying a running buff REFRESHES it (N10, `start_rule`).
## `balance` is non-null on both paths by construction: a card only resolves after the step-6 deal ran.
##
## STORY 6-5b: IT TAKES THE CASTER'S SLOT, because DRAIN's target arrives as a per-slot runner-pushed
## fact (`6-5b/R6`) and this is the seat that consumes it. Every other arm ignores it; the parameter
## is threaded rather than re-derived from `player == p1` because both existing call sites already
## hold the slot and a second derivation would be a second thing to get wrong.
func _apply_card_effect(player: PlayerState, effect: CardEffect, slot: int) -> void:
	match CardEffectResolver.outcome(effect, flags):
		CardEffectResolver.OUTCOME_SUMMON:
			# Story 4-4 (AC 1/AC 6): the kind index and THAT KIND'S authored maximum are both read
			# INLINE here (CONSTRAINT C) and handed DOWN to the board, which is what keeps `UnitBoard` a
			# pure container with no config dependency — the `4-3a/R6` shape, widened by exactly one
			# argument.
			var kind_index := balance.kind_index_of(CardEffectResolver.kind_for(effect))
			var kind := balance.kind_at(kind_index)
			# AN UNAUTHORED KIND PUTS NOTHING ON THE BOARD, LOUDLY-BY-ABSENCE RATHER THAN SILENTLY AS A
			# MINION (`BalanceConfig.kind_index_of`'s own "never a fallback to another kind" contract).
			# A cast that resolves to an unauthored kind is a SUCCESSFUL cast that happens to put nothing
			# on the board, exactly as a `spell_*` no-op is — and it takes no `reject_action`.
			if kind != null:
				player.units.add(kind.max_hp, kind_index)
		CardEffectResolver.OUTCOME_BLOODLUST:
			player.start_rule(PlayerState.RULE_BLOODLUST,
					TimingWindow.seconds_to_ticks(effect.duration_seconds),
					effect.damage_dealt_multiplier, effect.damage_taken_multiplier)
		CardEffectResolver.OUTCOME_VAMPIRIC_AURA:
			player.start_rule(PlayerState.RULE_VAMPIRIC_AURA,
					TimingWindow.seconds_to_ticks(effect.duration_seconds),
					effect.lifesteal_fraction, 0.0)
		CardEffectResolver.OUTCOME_BLOODHOUND_STEP:
			player.start_rule(PlayerState.RULE_BLOODHOUND_ARMED,
					TimingWindow.seconds_to_ticks(effect.duration_seconds),
					effect.roll_distance_multiplier, effect.roll_iframe_multiplier)
		CardEffectResolver.OUTCOME_FROSTBITE:
			# The slow's own duration rides the trigger as TICKS (`b`), converted here once, so the
			# consuming hit starts the slow without re-reading the effect.
			player.start_rule(PlayerState.RULE_FROSTBITE_ARMED,
					TimingWindow.seconds_to_ticks(effect.duration_seconds),
					effect.slow_speed_multiplier,
					float(TimingWindow.seconds_to_ticks(effect.slow_duration_seconds)))
		# Story 6-5b: the four OWN-MINION / CORPSE arms. Each is ONE call to a named helper below
		# rather than inline arithmetic, for the reason the buff arms are one `start_rule` call each:
		# this `match` says WHAT resolves and the helper says HOW, so the apply seat stays a readable
		# list of outcomes as the family grows.
		CardEffectResolver.OUTCOME_CULLING:
			_apply_culling(player, effect)
		CardEffectResolver.OUTCOME_GRAVE_WARD:
			_apply_grave_ward(player, effect)
		CardEffectResolver.OUTCOME_RAISE_DEAD:
			_apply_raise_dead(player, effect)
		CardEffectResolver.OUTCOME_DRAIN:
			_apply_drain(player, effect, slot)


## Story 6-5b (AC 8, `6-5b/R5`/`6-5b/R15`): CULLING -- kill up to `kill_cap` of the caster's OWN LIVING
## MINIONS and grant `mana_per_kill` for exactly the ones killed.
##
## THE SECOND OF THE DEATH SEAT'S THREE CALLERS, and it KILLS WITHOUT DAMAGING (`6-5b/R4`, AC 7):
## `UnitBoard.kill_at` is reached directly, so `_funnel_damage` and `_apply_lifesteal` are not on this
## path at all. Bloodlust cannot double a Culling kill and Vampiric Aura cannot heal off one, because
## there is no damage number anywhere in this function for either to read.
##
## BOARD-INDEX ORDER, OLDEST FIRST (AC 8): `living_indices()` is ascending by construction, so a cap
## below the living count kills the oldest `kill_cap` minions. TOTEMS ARE EXCLUDED by the same
## `kind_index_at` lookup AC 1 uses at the death seat -- reached here through `_corpse_ticks_for`'s
## own minion test rather than a second copy of it, which is what makes AC 10's "totems untouched"
## and AC 1's "totems leave no corpse" one decision instead of two that could disagree.
##
## THE OPPONENT IS UNREACHABLE, not filtered (AC 10): `player` is the caster, and a `UnitBoard` belongs
## to exactly one player. There is no code here that could address the other board.
##
## MANA IS GRANTED PER KILL THE SEAT ACTUALLY MADE, counted off `kill_at`'s own return value rather
## than re-derived from liveness afterwards, and it goes through `ManaPool.add` -- so the EXISTING pool
## clamp loses the surplus of an over-cap Culling (`6-5b/R5`) with no second ceiling here.
func _apply_culling(player: PlayerState, effect: CardEffect) -> void:
	var killed := 0
	for index: int in player.units.living_indices():
		if killed >= effect.kill_cap:
			break
		if not _is_own_minion(player, index):
			continue   # a TOTEM (or a reload-orphaned kind): never Culling's target (AC 10)
		if player.units.kill_at(index, _corpse_ticks_for(player, index)):
			killed += 1
	if killed > 0:
		player.mana.add(effect.mana_per_kill * float(killed))


## Story 6-5b (AC 11/AC 12, `6-5b/R7`): GRAVE WARD -- add this effect's authored extension to the
## remaining lifetime of every corpse the caster owns AT THIS INSTANT.
##
## NOTHING IS STORED ON `PlayerState` (the ruling's own clause): no `RULE_*` slot, no `RULE_COUNT`
## bump. The seat was ruled out on two independent contradictions, both recorded in the story: the
## rule seat REFRESHES by construction (`start_rule` cancels then starts) and so cannot express AC
## 12's additive stacking, and `clear_rules()` fires at round end while a corpse must survive it.
##
## "AT THIS INSTANT" IS THE WHOLE OF AC 11's SECOND SENTENCE and it costs nothing: the loop walks
## `corpse_indices()` as it is NOW, so a corpse created on a later tick was never in this list and is
## untouched by this cast. There is no stored "wards are active" state for a later death to consult.
##
## THE SECONDS ARE CONVERTED TO TICKS HERE, ONCE, at the application (A1) -- the buff arms' own
## discipline applied to a per-corpse countdown instead of a rule window.
func _apply_grave_ward(player: PlayerState, effect: CardEffect) -> void:
	var extension := TimingWindow.seconds_to_ticks(effect.duration_seconds)
	for index: int in player.units.corpse_indices():
		player.units.extend_corpse_at(index, extension)


## Story 6-5b (AC 14/AC 16/AC 17, `6-5b/R8`): RAISE DEAD -- every one of the caster's OWN corpses
## becomes a live minion, and each is CONSUMED by the raise.
##
## A NEW RECORD AT A NEW INDEX, NEVER A REVIVAL OF THE HOLE (`4-1/R9`, unchanged since 4-3a): the
## raised minion enters through `UnitBoard.add`, which only ever appends. That ruling is what makes
## AC 14's "no hole is ever reused" true by construction rather than by a check here.
##
## THE CORPSE LIST IS TAKEN BEFORE THE FIRST APPEND, and the ordering is load-bearing: `add()` grows
## the same arrays `corpse_indices()` walks, and a fresh record carries no corpse, so re-reading the
## list mid-loop would be reading a list that is growing underneath it. Taken once, it is also what
## fixes the raised records' ORDER to ascending corpse order.
##
## IT ENTERS AT THE CORPSE'S OWN KIND's MAXIMUM, scaled by the authored percentage. The kind comes
## from the DEAD RECORD rather than from a `KIND_MINION` literal, which is both more honest and
## narrower: only minions leave corpses (`_corpse_ticks_for`), so the two agree today, and if a later
## story gives a second kind a corpse, a raise reproduces THAT kind instead of silently minion-ising
## it. An unresolvable kind (an X3 reload shortened `unit_kinds`) raises NOTHING and the corpse is
## still consumed -- the graceful-degradation direction, and the corpse is genuinely spent either way.
##
## AC 17 NEEDS NO CODE: the raised record is an ordinary board record, so its next death goes through
## the same death seat and leaves a fresh corpse like any other.
func _apply_raise_dead(player: PlayerState, effect: CardEffect) -> void:
	for index: int in player.units.corpse_indices():
		var kind := balance.kind_at(player.units.kind_index_at(index))
		player.units.consume_corpse_at(index)
		if kind == null:
			continue
		player.units.add(kind.max_hp * effect.raise_hp_percent / 100.0,
				player.units.kind_index_at(index), index)


## Story 6-5b (AC 18-20, `6-5b/R6`): DRAIN -- sacrifice exactly ONE of the caster's own living minions
## and heal the caster's hero.
##
## THE THIRD OF THE DEATH SEAT'S THREE CALLERS, and it KILLS WITHOUT DAMAGING for `_apply_culling`'s
## reason verbatim (`6-5b/R4`, AC 7): `kill_at` directly, no damage number anywhere, so neither
## Bloodlust nor Vampiric Aura has anything to read.
##
## THE TARGET IS THE RUNNER'S PUSHED FACT AND IS NEVER RECOMPUTED HERE (AC 18). The facing-angle
## selection needs actor POSITIONS, which `src/state/` may not read (D3(b)/A2), so the runner computes
## it and pushes it through `push_drain_target` -- the `push_contact` / `set_lock_direction` precedent,
## which is what puts it on the replay tap and makes a replay reproduce the exact same sacrifice.
##
## AN ABSENT OR STALE FACT FALLS BACK TO THE LOWEST LIVING OWN MINION, and this is a DEGRADE, not a
## second selection rule. Three ways to get here: a headless fixture that never pushed (every unit
## test), a pushed index whose minion has since died inside this same tick, and a malformed push. In
## all three the pre-spend gate has already established that a living own minion EXISTS, so refusing
## now would spend the mana for nothing; the lowest index is the board's own canonical first candidate
## (`living_indices()` ascending, `4-2/R3`'s index order) and it is position-free, so it cannot
## reintroduce a spatial read. AC 22's first sentence is satisfied by it either way: with exactly one
## own living minion, the fallback and the fact name the same record.
func _apply_drain(player: PlayerState, effect: CardEffect, slot: int) -> void:
	var index := _drain_target_index(player, slot)
	if index < 0:
		return
	if player.units.kill_at(index, _corpse_ticks_for(player, index)):
		# AC 20: clamped at the caster's own maximum by `HeroState.heal`, which never overheals -- the
		# same seat and the same clamp `_apply_lifesteal` relies on, reused rather than re-derived.
		player.hero.heal(effect.heal_amount)


## The board index Drain sacrifices: the runner's pushed facing choice when it still names a living
## own MINION, otherwise the lowest living own minion (see `_apply_drain`). `-1` when the caster has
## none at all -- a state the pre-spend gate (AC 21) normally prevents this seat from ever seeing.
func _drain_target_index(player: PlayerState, slot: int) -> int:
	var pushed := _drain_targets[slot]
	if pushed >= 0 and player.units.is_alive_at(pushed) and _is_own_minion(player, pushed):
		return pushed
	for index: int in player.units.living_indices():
		if _is_own_minion(player, index):
			return index
	return -1


## Story 5-2 (AC 2, `5-2/R11`): the S6 GATE's reason -- named, and named HERE rather than on
## `CastEvaluator`, because `CastEvaluator` is not consulted on this path at all (AC 5, `5-2/R2`)
## and a `REASON_*` constant living on an evaluator that never returns it would be a lie about where
## the refusal comes from. The VOCABULARY is the evaluator's (`REASON_EMPTY_SLOT`-style: a lowercase
## StringName naming the player-visible fact), which is the part AC 2 actually asks for.
const REASON_UNBLOCKABLE_COMMITTED := &"unblockable_committed"

## Story 5-6 (AC 15/AC 16): the SECOND state-shaped refusal reason, named HERE beside its sibling for
## that constant's own stated rule -- `CastEvaluator` is not consulted on EITHER refusal path, so a
## `REASON_*` living on it would be a lie about where the refusal comes from. What is borrowed from
## `CastEvaluator` is therefore narrower than "its vocabulary": only the TOKEN CONVENTION (a lowercase
## `StringName` naming the player-visible fact, `REASON_EMPTY_SLOT`-style).
##
## A SEPARATE REASON RATHER THAN REUSING `REASON_UNBLOCKABLE_COMMITTED` a fourth time, because "an
## unblockable is committed" does not read true for a STUNNED caster -- the stun may have come from a
## deflected melee swing with no unblockable anywhere in it.
##
## ONE SHARED CONSTANT SERVES BOTH REFUSAL SEATS (`_resolve_defense_cast` and `_resolve_basic_cast`),
## the `REASON_EMPTY_SLOT` reuse precedent applied a second time: the player-visible fact is the same
## fact in both places, so inventing a per-seat token would name the mechanism instead of the fact.
const REASON_STUNNED := &"stunned"

## Story 6-6a post-smoke ruling `6-6a/R7`: a cast attempted while the caster is GETTING
## UP. A SEPARATE TOKEN rather than a fourth reuse of `REASON_STUNNED`, on that constant's own stated
## reason: the token names the PLAYER-VISIBLE FACT, and a hero getting up is not stunned -- it is IDLE,
## its stun window has already run out, and its get-up window is what refuses. Telling the player
## "stunned" there would be a false statement about a state they can see has ended. Same lowercase
## `StringName` convention, minted here for the same reason `REASON_STUNNED` is: `CastEvaluator` sees
## neither fact.
##
## ONE SEAT, EVERY MODE: this is raised in `_resolve_card_action` ahead of the mode dispatch, so all
## four modes (basic, unblockable initiation, defense, pitch) refuse identically. The per-mode
## `REASON_STUNNED` gates below are untouched.
const REASON_GETTING_UP := &"getting_up"

## Story 6-6b (AC 2): a cast attempted while the caster is MID-COUNTER -- its counter window running,
## its body committed to the counter presentation. A SEPARATE TOKEN rather than a reuse of
## `REASON_GETTING_UP` or `REASON_STUNNED`, on `REASON_GETTING_UP`'s own stated reason: the token names
## the PLAYER-VISIBLE FACT, and a countering hero is neither stunned nor getting up -- it is IDLE, it
## holds no stun window, and what refuses it is the counter it is already committed to. Same lowercase
## `StringName` convention, minted here because `CastEvaluator` sees this fact no more than it sees the
## other two.
##
## ONE SEAT, EVERY MODE: raised in `_resolve_card_action` ahead of the mode dispatch, beside the get-up
## gate, so all four modes refuse identically. The per-mode `STUNNED` / `CHARGING` gates below are
## untouched and still do their own job.
const REASON_COUNTERING := &"countering"


## Story 6-2 (AC 5): a card with NO INJECTED PITCH COST refuses to stage with THIS reason -- minted here
## rather than borrowing `CastEvaluator.REASON_UNKNOWN_CARD`, whose own header documents it
## "UNREACHABLE BY CONSTRUCTION" because `inject_card_costs` is total. `inject_pitch_costs` deliberately
## is NOT total (AC 2), so this refusal is a real, reachable path for any card whose pitch content is
## unauthored, and reusing that constant would falsify its documented invariant. Lowercase StringName
## naming the player-visible fact, the `REASON_STUNNED` token convention.
const REASON_NO_PITCH_COST := &"no_pitch_cost"

## Story 6-2 (AC 6): ONE STAGED CARD PER PLAYER. A stage attempt while this player's zone already holds
## a card -- waiting or READY alike -- refuses with this reason: never a crash and never a silent
## overwrite of the card already there. A state-side OCCUPANCY conflict the evaluator never sees, so it
## lives here beside `REASON_UNBLOCKABLE_COMMITTED` / `REASON_STUNNED` and not on `CastEvaluator`.
const REASON_PITCH_ZONE_OCCUPIED := &"pitch_zone_occupied"

## Story 6-5b (AC 9/AC 21, `6-5b/R14`): CULLING or DRAIN pressed with no own living minion. A
## state-side BOARD fact the evaluator never sees, so it lives here beside its `REASON_STUNNED` /
## `REASON_PITCH_ZONE_OCCUPIED` siblings and not on `CastEvaluator` -- that class answers "can this
## player AFFORD this", and having something to kill is not a price.
const REASON_NO_OWN_MINION := &"no_own_minion"

## Story 6-5b (AC 13/AC 15, `6-5b/R14`): GRAVE WARD or RAISE DEAD pressed with no own corpse. Its OWN
## token rather than a reuse of the one above, on `REASON_EMPTY_PITCH_ZONE`'s stated reasoning: an
## empty board and a board with living minions but no corpses are different player-visible facts, and
## a player who just watched Culling fill the field with corpses needs to hear which one it was.
const REASON_NO_OWN_CORPSE := &"no_own_corpse"


## Story 6-5b (AC 9/AC 13/AC 15/AC 21, `6-5b/R14`): the BOARD PRECONDITION `effect` cannot resolve
## without, as a refusal reason, or `&""` for "may proceed".
##
## ONE FUNCTION, TWO GATES (mode ① at `_resolve_basic_cast`, mode ④ at `_resolve_pitch_activate`), and
## that is what makes `6-5b/R9`'s "identically whether the card is being cast or pitch-activated" true
## by construction instead of by two conditions kept in agreement. It is also why Culling (Vanguard's
## PITCH) and Raise Dead (Grave Ward's PITCH) get the same refusal test their normal-mode siblings do,
## which is the clause of that ruling most easily lost.
##
## WHICH EFFECTS HAVE A PRECONDITION IS THE RESOLVER'S ANSWER, not a literal id list here -- see
## `CardEffectResolver.board_requirement_for`. This function turns that requirement into a reading of
## THIS player's board and nothing else.
##
## THE EMPTY-MEANS-ALLOWED CONVENTION IS `CastEvaluator`'s, borrowed as a shape exactly as
## `_unblockable_refusal_reason` borrows it; `CastEvaluator.refusal_reason` is not called and cannot
## be reached from here.
##
## NO `Invariant.check` ON THIS PATH (`5-1a/R7`, the standing rule for player-reachable refusals):
## `Invariant.check` is `push_error` + `assert`, and `assert` is stripped in an exported build -- so a
## guard written that way would log in the editor and let the cast through in the shipped game.
##
## Review fix (6-5b review, MAJOR-1): A CLOSED spell layer is not a refusal -- the cast resolves and
## applies nothing, exactly like the 6-5a buffs with the layer closed. `board_requirement_for` itself
## reads no flags (by design, see its own docstring), so the closed-layer reading is taken here, through
## the SAME call `_apply_card_effect` uses to decide whether to apply anything (`CardEffectResolver.outcome`)
## -- never a second flag check with its own semantics that could drift from the resolver's.
func _board_refusal_reason(player: PlayerState, effect: CardEffect) -> StringName:
	if CardEffectResolver.outcome(effect, flags) == CardEffectResolver.REASON_SPELLS_FLAG_CLOSED:
		return &""
	match CardEffectResolver.board_requirement_for(effect):
		CardEffectResolver.NEEDS_OWN_LIVING_MINION:
			for index: int in player.units.living_indices():
				if _is_own_minion(player, index):
					return &""
			return REASON_NO_OWN_MINION
		CardEffectResolver.NEEDS_OWN_CORPSE:
			# AC 13/AC 15 read "no own corpse AT ALL", which is exactly `corpse_indices()` being empty
			# -- the same list Grave Ward extends and Raise Dead consumes, so the gate and the apply can
			# never disagree about whether there was anything to act on.
			return &"" if not player.units.corpse_indices().is_empty() else REASON_NO_OWN_CORPSE
	return &""


## Story 6-2 (AC 3-8a/AC 12): mode ④ resolution -- STAGING. The card leaves the hand into its owner's
## Pitch Zone, its mana is paid, and its public countdown starts. `_resolve_basic_cast` is the shape;
## every difference is ruled, and each is named where it happens.
##
## THE GUARD ORDER IS LAYER FLAG -> STATE GATE -> EMPTY SLOT -> OCCUPIED ZONE -> PITCH-COST LOOKUP ->
## FLAG + MANA. The layer gate first is modes ② and ③'s `5-2/R13` ordering: "does this layer exist at
## all" precedes "may I use it right now". The state gate mirrors `_resolve_basic_cast`'s CHARGING /
## STUNNED pair, reasons included. The empty-slot guard precedes the cost lookup for `4-0`'s AC 7
## reason (a hole never reaches a cost map). Nothing above the spend mutates anything, so every refusal
## leaves the hand, the mana, the orbs and the zone untouched (AC 5).
##
## `CastEvaluator.refusal_reason` IS NOT CALLED (AC 4): its orb check would refuse a player who has not
## banked the orbs yet, and staging is exactly how a player commits BEFORE banking them. The flag + mana
## half is `CastEvaluator.flag_and_mana_refusal_reason`, which `refusal_reason` itself calls -- so the
## two paths share that half by construction.
##
## THE HOLE IS MADE, THE DEBT IS NOT (AC 3/AC 8, Fact 7's ruling). `hand.remove_at()` vacates the slot
## exactly as a cast does, but NOTHING is appended to `pending_draw_owed` here: the slot is held empty
## and RESERVED -- its index is recorded in the zone -- and the replacement is owed only when the card
## LEAVES the zone (`_resolve_pitch_expiry`). Nothing can deal into it meanwhile: delivery only ever
## fills an OWED slot.
##
## THE OPTIONAL ORB CLEAR (AC 12) fires AFTER the spend and hole and BEFORE the record exists, so READY is
## first read against the cleared pool. It is keyed to the ACT of staging -- "pitching clears", not
## "the price clears" -- so a zero-orb-cost card clears the pool too when the switch is ON.
## `OrbPool.reset_all()` is reused (its second call site; `_reset_player` is the first).
##
## NO `card_cast_resolved` IS QUEUED: nothing resolved -- the card is waiting, not played. The ONE
## announcement is `notify_cards_changed()` (AC 8a), because the hand's occupancy changed.
##
## FROZEN TICKS AND A DEAD HERO never reach this function, inherited from `_resolve_card_action`
## unchanged, exactly as for modes ① to ③.
func _resolve_pitch_stage(player: PlayerState, hand_slot: int, slot: int) -> void:
	# The LAYER GATE, read INLINE (CONSTRAINT C) from the INJECTED flags; null reads CLOSED, and
	# `CastEvaluator.REASON_FLAG_CLOSED` is borrowed as a constant -- modes ② and ③'s shape exactly.
	if flags == null or not flags.pitch_zone:
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_FLAG_CLOSED)
		return
	if player.hero.action_state == HeroState.ActionState.CHARGING:
		player.hero.reject_action(&"card_cast", REASON_UNBLOCKABLE_COMMITTED)
		return
	elif player.hero.action_state == HeroState.ActionState.STUNNED:
		player.hero.reject_action(&"card_cast", REASON_STUNNED)
		return
	if player.hand.is_slot_empty(hand_slot):
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_EMPTY_SLOT)
		return
	if pitch.is_staged(slot):
		player.hero.reject_action(&"card_cast", REASON_PITCH_ZONE_OCCUPIED)
		return
	var id: StringName = player.hand.to_array()[hand_slot]
	var condition: CardCastCondition = _pitch_costs.get(id)
	if condition == null:
		player.hero.reject_action(&"card_cast", REASON_NO_PITCH_COST)
		return
	var reason := CastEvaluator.flag_and_mana_refusal_reason(condition,
			player.mana.get_current(), flags)
	if reason != CastEvaluator.ALLOWED:
		player.hero.reject_action(&"card_cast", reason)
		return
	Invariant.check(player.mana.spend(condition.mana_cost),
		"an ALLOWED staging must be affordable — CastEvaluator and ManaPool disagree")
	var staged := player.hand.remove_at(hand_slot)
	# `balance` / `balance_ticks` are non-null below the empty-slot guard, `_resolve_basic_cast`'s
	# reason: a hand is non-empty only once the step-6 deal ran, and the deal needs balance.
	if balance.pitch_stage_clears_orbs:
		player.orbs.reset_all()
	pitch.stage(slot, staged, hand_slot, condition.orb_costs, balance_ticks.pitch_stage_timer_ticks)
	_queue_pitch_changed(slot)  # Story 6-3b (AC 1 site (a))
	player.notify_cards_changed()


## Story 6-3a (AC 6): an activation press with NOTHING in the player's own Pitch Zone. Its own token rather
## than `CastEvaluator.REASON_EMPTY_SLOT`: an empty ZONE is a different player-visible fact from an empty
## HAND SLOT, and both are reachable from the same Y button (L3 released vs L3 held with nothing armed).
## The `REASON_PITCH_ZONE_OCCUPIED` token convention, and seated beside it for the same reason.
const REASON_EMPTY_PITCH_ZONE := &"empty_pitch_zone"

## Story 6-3a (AC 6): an activation press on a staged card whose orb price is not banked yet. READY is
## derived live (`PitchState.is_ready`), so this refusal is a reading of the pool at the press, not a flag.
const REASON_PITCH_NOT_READY := &"pitch_not_ready"


## Story 6-3a (AC 5-10): mode ④ ACTIVATION -- the payoff half of the pitch. The player's own staged card
## resolves: its orb price is spent, it goes to the discard, the zone clears, and the vacated hand slot's
## replacement is owed. `_resolve_pitch_expiry` is the shape for everything after the spend.
##
## THE GUARD ORDER IS LAYER FLAG -> STUNNED -> EMPTY ZONE -> NOT READY. Layer first and the state gate
## second is `_resolve_pitch_stage`'s own ordering ("does this layer exist" precedes "may I use it right
## now"); the two zone facts follow. Nothing above the spend mutates anything, so every refusal leaves
## the orbs, the zone, its countdown, the discard and the owed list untouched.
##
## STUNNED IS REFUSED, CHARGING IS NOT (`6-3a-gate/R-HERO-STATE`): a stun is a punishment a button press
## must not step around; a chargeup is the player's own choice. DEAD and the round-over freeze need no
## guard here -- `_resolve_card_action` and `advance()` stop both before this function is reached.
##
## NO EXPIRY GUARD (`6-3a-gate/R-EXPIRY`). `pitch.is_expired()` is read nowhere on this path: on the tick
## a staged card's countdown closes, card dispatch runs BEFORE the fizzle exit in step 6, so a press on
## that exact tick ACTIVATES. Ruled in the player's favour.
##
## ONLY THE PRICED ORBS ARE SPENT (`6-3-split/R-SPEND`), read off `pitch.staged_orb_costs()` -- the same
## seat `is_ready()` reads -- and walked in `CastEvaluator.sorted_orb_colors()` order. Surplus and unpriced
## colours are untouched. NO `Invariant.check` on the spend, unlike the mana spend at staging: with the
## orbs layer OFF, READY reads satisfied regardless of the pool, and `OrbPool.add` floors at 0 (silently,
## no signal when nothing moved), so a floored spend is the graceful-degrade rule working, not a
## disagreement. MANA is not touched: it was paid at staging.
##
## `card_cast_resolved` IS QUEUED, unlike staging and the fizzle: activation IS a resolution -- the
## `4-1/R3`/`4-1/R10` "a no-op spell is still a successful cast" ruling. No per-card effect resolves here.
##
## THE OWED REFILL RESTARTS THE SHARED `pending_draw` WINDOW at the full delay, exactly as every other
## append does -- including one already in flight for a different slot.
func _resolve_pitch_activate(player: PlayerState, slot: int) -> void:
	if flags == null or not flags.pitch_zone:
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_FLAG_CLOSED)
		return
	if player.hero.action_state == HeroState.ActionState.STUNNED:
		player.hero.reject_action(&"card_cast", REASON_STUNNED)
		return
	if not pitch.is_staged(slot):
		player.hero.reject_action(&"card_cast", REASON_EMPTY_PITCH_ZONE)
		return
	if not pitch.is_ready(slot, player.orbs, flags):
		player.hero.reject_action(&"card_cast", REASON_PITCH_NOT_READY)
		return
	# Story 6-5b (AC 9/AC 15, `6-5b/R14`): THE MODE ④ HALF OF THE BOARD-AWARE GATE, fired BEFORE THE
	# ORB SPEND on the next lines -- which is the ruling's own clause, and the reason it sits here
	# rather than beside the mode ① gate's mana spend: orbs are what mode ④ pays at activation.
	#
	# WHAT A REFUSAL LEAVES BEHIND is the whole of AC 9/AC 15 and every part of it is a consequence of
	# this seat, not of code below it:
	#   * the ORBS are not spent -- the spend is below this return;
	#   * the card STAYS STAGED and stays READY -- `pitch.clear(slot)` is below this return, and READY
	#     is derived live from the pool (`PitchState.is_ready`), which this path has not touched;
	#   * its COUNTDOWN KEEPS RUNNING toward the normal fizzle -- the countdown is `pitch.tick()`'s at
	#     step 2 and nothing here stops it, so the card fizzles on its own schedule if no target ever
	#     appears, and the player may press again on any tick before that;
	#   * the STAGING MANA STAYS SPENT (`match_state.gd`'s standing no-refund rule at the fizzle exit,
	#     `6-5b/R14` citing it): it was paid at staging for a chance, and this refusal is not the
	#     chance expiring.
	# READ ONCE INTO A LOCAL and used at BOTH the gate and the apply below. Reading the map twice would
	# be harmless today and is refused anyway: `test_deck_and_hand.gd` pins that ACTIVATION consumes the
	# pitch-effect map EXACTLY ONCE (6-5a AC 6), and that pin exists so the seat cannot quietly become two
	# lookups that a later change could let disagree.
	var pitch_effect: CardEffect = _pitch_effects.get(pitch.staged_card_id(slot))
	var gate := _board_refusal_reason(player, pitch_effect)
	if gate != &"":
		player.hero.reject_action(&"card_cast", gate)
		return
	var orb_costs := pitch.staged_orb_costs(slot)
	for color: Enums.CardColor in CastEvaluator.sorted_orb_colors(orb_costs):
		player.orbs.add(color, -int(orb_costs[color]))
	var card_id := pitch.staged_card_id(slot)
	var hand_slot := pitch.staged_hand_slot(slot)
	player.discard.add(card_id)
	pitch.clear(slot)
	_queue_pitch_changed(slot)  # Story 6-3b (AC 1 site (b))
	# Story 6-5a (AC 6): THE PITCH EFFECT RESOLVES HERE, AT ACTIVATION -- after the orbs are spent and the
	# card has left the zone, through the same apply seat a Mode ① cast uses, off the card's PITCH effect
	# (the sixth injected map). Staging (`_resolve_pitch_stage`) stays cost-only and reads no effect. The
	# header's "No per-card effect resolves here" is SUPERSEDED by this line.
	_apply_card_effect(player, pitch_effect, slot)
	# Story 6-5a (AC 10): the second APPLY seat of the last-resolved-card record.
	player.record_resolved_card(card_id, Enums.ModeKind.PITCH)
	# `balance_ticks` is non-null here by construction: a card is staged only after the step-6 deal ran.
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	player.notify_cards_changed()
	_queue.push(card_cast_resolved.emit.bind(slot, card_id, Enums.ModeKind.PITCH))


## Story 6-2 (AC 8/AC 8a/AC 11): THE FIZZLE EXIT -- one of the two ways a card leaves the Pitch Zone
## (story 6-3a adds activation, directly above; cancel has no owning story). When a staged card's countdown has closed, READY or not,
## the card goes to its owner's DISCARD (never back to the hand), and ONLY NOW is the replacement owed:
## the reserved slot index is appended to `pending_draw_owed` and the window started at the normal
## delay, the identical FIFO `_resolve_basic_cast` feeds, triggered at a different tick. This is the
## GDD's "fizzle -> discarded + draw" as exactly ONE draw.
##
## THE MANA IS NOT REFUNDED. It was paid at staging for a chance; the chance expired.
##
## THE SECOND ANNOUNCEMENT SEAT (AC 8a), its own call rather than a reuse of the staging one: the discard
## pile and the owed list both changed on this tick.
func _resolve_pitch_expiry(player: PlayerState, slot: int) -> void:
	if not pitch.is_expired(slot):
		return
	var hand_slot := pitch.staged_hand_slot(slot)
	player.discard.add(pitch.staged_card_id(slot))
	pitch.clear(slot)
	_queue_pitch_changed(slot)  # Story 6-3b (AC 1 site (c))
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	player.notify_cards_changed()


## Story 5-2 (AC 2, `5-2/R11`): THE S6 GATE -- whether this hero may initiate mode (2) right now, as
## a reason or `&""` for "may proceed". The empty-means-allowed convention is `CastEvaluator`'s, and
## it is the only thing borrowed from it: `refusal_reason` is NOT called anywhere on this path.
##
## A SMALL SIBLING GUARD RATHER THAN AN INLINE `if`, which is the Open Question's second option: it
## makes the gate directly testable against a state without building a cast, and it keeps the
## refused states readable as one list instead of a condition threaded through the spend sequence.
##
## NO `Invariant.check` ANYWHERE ON THIS PATH (`5-1a/R7`): this is a PLAYER-REACHABLE refusal, and
## `Invariant.check` is `push_error` + `assert`, with `assert` stripped in an exported build -- so a
## guard written that way would log in the editor and let the cast through in the shipped game,
## which is the exact defect `5-1a` was raised to close on the lock seat.
##
## THE FOURTH STATE IS `CHARGING` AND AC 2 DOES NOT NAME IT. The AC names ROLLING, BLOCKING and
## ATTACKING; a hero already mid-chargeup is added here on the AC's own stated reason ("only a
## duration effect, rooting the hero, needs a reachability gate" -- AC 3), because without it a
## second commit during a chargeup spends a second card and a second 20 stamina, restarts the
## window, and overwrites the live telegraph `5-3` is about to render. Flagged in the dev pass
## report as an addition beyond AC 2's named three rather than folded in silently.
##
## THE FIFTH STATE IS `STUNNED`, ADDED IN THE `5-6` FIX PASS (review finding H1) rather than by the
## dev pass. AC 15's own opening sentence ("STUNNED forbids every action by construction") implies
## this seat, and the dev pass's Non-Goals/AC 16 text left this function untouched on the reading
## that AC 16 only ever named `_resolve_basic_cast` -- but the review found the gap live: nothing
## here gated `STUNNED`, so `_resolve_unblockable_cast`'s unconditional `set_action_state(CHARGING)`
## on a successful cast OVERWROTE `STUNNED` outright, un-rooting a stunned hero and letting it cast a
## fresh unblockable to answer the very commitment (a deflected melee swing, a color-counter
## negation) that stunned it -- the exact escape AC 15's own rationale for gating `CHARGING` here
## ("a duration effect, rooting the hero, needs a reachability gate") already covers for `STUNNED`
## identically. The reason is `REASON_STUNNED` (AC 15's shared constant, `_resolve_basic_cast` and
## `_resolve_defense_cast`'s own token), not `REASON_UNBLOCKABLE_COMMITTED` -- "committed to an
## unblockable" does not describe a stunned caster, the same distinction AC 15 already draws for its
## two seats. The story's own Non-Goals ("`_unblockable_refusal_reason` ... untouched") and AC 16's
## closing sentence are AMENDED by this fix pass to carve out exactly this one-arm addition; nothing
## else about mode (2) changes, `TRANSITION_TABLE` gains no row, and `_resolve_basic_cast` is
## unaffected (it never calls this function).
##
## `BASIC` IS NOT GATED BY THIS AND MUST NOT BE (AC 3): `_resolve_basic_cast` never calls it. A
## basic cast is an instant summon that interrupts nothing and deliberately runs parallel to melee.
static func _unblockable_refusal_reason(hero: HeroState) -> StringName:
	var state := hero.action_state
	if state == HeroState.ActionState.ROLLING \
			or state == HeroState.ActionState.BLOCKING \
			or state == HeroState.ActionState.ATTACKING \
			or state == HeroState.ActionState.CHARGING:
		return REASON_UNBLOCKABLE_COMMITTED
	if state == HeroState.ActionState.STUNNED:
		return REASON_STUNNED
	return &""


## Story 5-2 (AC 1/AC 2/AC 5/AC 6/AC 7): mode (2) resolution -- THE INITIATION HALF of the RGB read
## exchange. `_resolve_basic_cast` directly above is the shape this follows; the differences are all
## ruled, and each is named where it happens.
##
## THE GUARD ORDER IS S6 GATE -> EMPTY SLOT -> STAMINA, and it is a dev-pass choice worth stating.
## AC 5 pins the empty-slot guard ahead of the COST check, which it is. The S6 gate goes ahead of
## both because it answers a different question -- whether mode (2) may be initiated AT ALL on this
## tick -- and a hero refused mid-roll should hear the reason that actually blocked it rather than
## a report about the slot. Reversing the first two would satisfy AC 5's letter equally; the choice
## is recorded here so it can be overturned in one line.
##
## NO MANA AND NO ORB EVALUATION RUNS (AC 5, `5-2/R2`): `CastEvaluator.refusal_reason` is not called
## and cannot be reached from this function. Stamina affordability is the ONLY cost refusal, and it
## goes through `StaminaPool.spend` directly -- the FOURTH spend seat, joining roll, attack and
## deflect, and passing `stamina_regen_delay_ticks` exactly as the other three do so the spend
## restarts the regen delay identically (`5-2/R4`).
##
## THE `unblockable` FEATURE FLAG IS CONSULTED, AND IT IS THE FIRST THING THIS FUNCTION ASKS
## (`5-2/R13`, amending `5-2/R2`). The dev pass shipped this path flag-blind under `5-2/R2`'s
## original wording and RAISED that as a conflict with project-context's feature-flag HARD RULE; the
## ruling withdrew the flag half as an operator error. A gameplay layer that cannot be switched off
## is the defect. What `5-2/R2` was protecting against was ROUTING THE CHECK THROUGH
## `CastEvaluator`, and that protection is intact and unweakened: the REASON CONSTANT is borrowed,
## `refusal_reason` is not called, and no mana or orb reading is taken anywhere on this path.
##
## THE FLAG PRECEDES THE S6 GATE, deliberately: "does this layer exist at all" is a different and
## prior question to "may I use it right now". A hero mid-roll in a build with the unblockable layer
## switched off should hear that the layer is closed, not that it is busy.
##
## `balance` AND `balance_ticks` ARE NON-NULL BELOW THE EMPTY-SLOT GUARD, by construction and for
## `_resolve_basic_cast`'s exact reason: a hand can only be non-empty if the step-6 deal ran, and
## the deal returns early while balance is null. This is why the guard order matters structurally as
## well as legibly -- the stamina read sits behind it.
##
## FROZEN TICKS NEVER REACH THIS FUNCTION and a DEAD hero never reaches it either: both are
## INHERITED from `_resolve_card_action` unchanged (step 1b returns before step 2, and the DEAD
## guard sits above the dispatch), so a mode (2) commit on a frozen tick is dropped silently exactly
## as a BASIC one is, for the same structural reason and with no new contract.
func _resolve_unblockable_cast(player: PlayerState, hand_slot: int, slot: int) -> void:
	# Story 5-2 (`5-2/R13`): the LAYER GATE. `flags` is read INLINE (CONSTRAINT C), never cached,
	# and it is the INJECTED resource -- `FeatureFlagsService` is not named anywhere under
	# `src/state/` and is not named here. A NULL `flags` reads as CLOSED, which is the shipped
	# reading of every layer gate in this layer (`CardEffectResolver._minions_open`,
	# `TargetingService`, `CastEvaluator._flag_open`): a layer that cannot be VERIFIED open stays
	# shut, which is the graceful-degradation direction rather than the permissive one.
	#
	# `CastEvaluator.REASON_FLAG_CLOSED` is borrowed as a CONSTANT and nothing more. Inventing a
	# second token for "this layer is off" would name the same player-visible fact twice -- the
	# `REASON_EMPTY_SLOT` reuse in `_resolve_basic_cast`, applied again for the same reason.
	if flags == null or not flags.unblockable:
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_FLAG_CLOSED)
		return
	var refusal := _unblockable_refusal_reason(player.hero)
	if refusal != &"":
		player.hero.reject_action(&"card_cast", refusal)
		return
	if player.hand.is_slot_empty(hand_slot):
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_EMPTY_SLOT)
		return
	# The 1-4 FALLTHROUGH shape, not deflect's degrade: there is no degraded unblockable to fall
	# back to, so an unaffordable commit refuses and NOTHING is spent. Nothing above this line
	# mutated state, so a refused cast leaves the hand, the discard and the debt untouched.
	# `&"insufficient_stamina"` is the shipped vocabulary verbatim -- the same reason the roll and
	# attack seats queue, because it is the same fact about the same pool.
	if not player.stamina.spend(balance.unblockable_stamina_cost,
			balance_ticks.stamina_regen_delay_ticks):
		player.hero.reject_action(&"card_cast", &"insufficient_stamina")
		return
	# AC 6: the card leaves the hand and enters the discard, the replacement is owed on the VACATED
	# slot, and the observation channel announces -- `_resolve_basic_cast`'s ordering mirrored
	# exactly, all inside this one tick.
	var played := player.hand.remove_at(hand_slot)
	player.discard.add(played)
	# AC 21 / Ruling 2: COLOUR SELECTS THE TELEGRAPH, NOT THE DAMAGE. The colour is COPIED off the
	# injected map into a plain int here and the map itself is never hashed; damage is one authored
	# value for all three colours in this story (`5-6` ships the ladder).
	#
	# A MISSING ENTRY DEGRADES TO "NO COLOUR" rather than to RED, which is the graceful-degradation
	# direction every authored-data miss in this project takes (`CardEffectResolver`'s
	# missing-entry default, `BalanceConfig.kind_index_of`'s refusal to substitute). It is
	# UNREACHABLE in live play -- `inject_card_colors`'s totality check closes it at the seam -- and
	# reachable only in a fixture that injects no colours, where inventing RED would be a lie the
	# snapshot would then carry.
	player.charge_color = int(_card_colors[played]) if _card_colors.has(played) \
			else PlayerState.NO_TELEGRAPH_COLOR
	# AC 10: the chargeup window, read INLINE from the tick domain (CONSTRAINT C) and never from a
	# seconds float. AC 7 (`5-2/R7`): entry is a DIRECT `set_action_state` call AT THE CAST SEAT --
	# `HeroState.TRANSITION_TABLE` gains NO row, because CHARGING has no `&"attack"`-style inbound
	# PRESS to map from. The card layer drives this edge; the table's input-priority rows do not.
	# That is exactly why test_action_state.gd's zero-inbound-CHARGING assertion stays true and is
	# re-proven UNEDITED (AC 8).
	player.charge_window.start(balance_ticks.unblockable_chargeup_ticks)
	# Story 6-1c (AC 2/AC 4): the LANDING window starts in the same breath, with its FULL duration --
	# the chargeup plus this colour's launch span, both read inline from the tick domain (CONSTRAINT
	# C) and AFTER `charge_color` is set above, because the span is the colour's. Starting it here
	# rather than at the commit is what lets a mid-attack reload move neither the commit nor the
	# landing (see `PlayerState.landing_window`).
	player.landing_window.start(balance_ticks.unblockable_chargeup_ticks
			+ balance_ticks.unblockable_launch_ticks_for(player.charge_color))
	# Story 6-1d review fix (`6-1d/R9`): THE CONTACT VERDICT AND ITS BEARING START EVERY ATTACK FROM
	# "NOTHING MEASURED", cleared HERE beside the windows that bound the flight. Owned rather than left
	# to the pre-commit pushes, which a one-tick chargeup never gets -- see `push_contact`.
	_charge_reach[slot] = REACH_UNKNOWN
	_charge_contact_dirs[slot] = Vector2.ZERO
	player.hero.set_action_state(HeroState.ActionState.CHARGING)
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	player.notify_cards_changed()
	_queue.push(card_cast_resolved.emit.bind(slot, played, Enums.ModeKind.UNBLOCKABLE))


## Story 5-5 (AC 1/AC 3-8): mode ③ resolution -- THE ANSWER HALF of the RGB read exchange.
## `_resolve_unblockable_cast` directly above is the shape this follows; every difference is ruled
## and named where it happens.
##
## THE GUARD ORDER IS LAYER FLAG -> CHARGING -> EMPTY SLOT -> STAMINA, mode ②'s order verbatim and
## for its stated reasons: "does this layer exist at all" precedes "may I use it right now", which
## precedes a report about the slot, which precedes the cost.
##
## THE LAYER GATE IS `flags.unblockable`, THE SAME FLAG MODE ② READS (AC 3) -- no new `FeatureFlags`
## field. Defending only matters where an unblockable exists to defend against, so a closed
## `unblockable` layer closes mode ③ too. Read INLINE (CONSTRAINT C), never cached, `flags == null`
## reading CLOSED exactly as every other layer gate in this file does, and
## `CastEvaluator.REASON_FLAG_CLOSED` borrowed as a CONSTANT -- the same borrow mode ② already makes.
##
## EXACTLY ONE STATE-BASED REFUSAL: `CHARGING` (AC 4, operator ruling). `ROLLING`, `BLOCKING` and
## `ATTACKING` are ALL ALLOWED -- the defender must be able to answer mid-swing, mid-roll and
## mid-block. A chargeup is a large committal attack by the operator's own ruling, and a commitment
## coverable by a defense is not a commitment: the caster moved first and carries the risk. It also
## keeps the layers alternating rather than overlapping -- a defender reading a telegraph knows a
## charging hero can do nothing back.
##
## THE REASON IS `REASON_UNBLOCKABLE_COMMITTED`, REUSED VERBATIM rather than invented. This gate is
## the identical single-state check `_unblockable_refusal_reason` already makes for `CHARGING`, and
## the existing name reads true here without qualification: an unblockable IS committed, which is
## exactly why this hero cannot also cast DEFENSE. `CastEvaluator` has no state-shaped reason at all
## (its five constants are EMPTY_SLOT / UNKNOWN_CARD / FLAG_CLOSED / INSUFFICIENT_MANA /
## INSUFFICIENT_ORBS), so `MatchState`'s own sibling constant is the only candidate.
##
## NO MANA AND NO ORB EVALUATION RUNS, mode ②'s property inherited unchanged:
## `CastEvaluator.refusal_reason` is not called and cannot be reached from here. Stamina is the ONLY
## cost refusal and it is the FIFTH spend seat (roll, attack, unblockable, deflect precede it),
## passing `stamina_regen_delay_ticks` exactly as the other four do. The `1-4` FALLTHROUGH shape,
## never deflect's degrade -- there is no degraded defense to fall back to.
##
## RE-CASTING WHILE A WINDOW IS ALREADY RUNNING RESTARTS IT, and that is a DEV-PASS CHOICE the story
## left open (Deferred). `TimingWindow.start()` restarts naturally and the `charge_window` precedent
## for a fresh cast overwriting an in-flight one points the same way; a refusal would need a new
## reason constant the operator has not asked for. The card and the stamina are spent either way
## (AC 7), so the restart is not free.
##
## NO ACTION STATE, NO ROOTING, NO SLOWING (AC 5, negative). This function introduces no
## `HeroState.ActionState` member and changes no movement multiplier. The ONE `set_action_state` call
## below is a transition to the EXISTING `IDLE`, taken ONLY from `BLOCKING`.
##
## FROZEN TICKS NEVER REACH THIS FUNCTION and a DEAD hero never reaches it either: both are
## INHERITED from `_resolve_card_action` unchanged, exactly as for modes ① and ②.
func _resolve_defense_cast(player: PlayerState, hand_slot: int, slot: int) -> void:
	if flags == null or not flags.unblockable:
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_FLAG_CLOSED)
		return
	# Story 5-6 (AC 15): the EXISTING `CHARGING` gate WIDENED to a second state rather than joined by
	# a second `if` — both are commitments the caster cannot answer from, and expressing them as one
	# gate keeps "a committed hero cannot cast defense" a single fact. Each arm keeps its OWN reason:
	# `REASON_UNBLOCKABLE_COMMITTED` already reads true for a charging caster, and does not for a
	# stunned one.
	#
	# THIS ONLY PREVENTS ARMING A NEW WINDOW. An ALREADY-RUNNING `defense_window` cast before the stun
	# landed is untouched by this story and keeps ticking down at its ordinary step-2 rate -- exactly
	# `5-5` AC 11's wrong-colour survival, and the story's Deferred item resolved by measurement:
	# nothing here reads or writes `defense_window`/`defense_color`, so there is no interaction to
	# build. It is pinned by a test anyway (the `5-5` referenced-not-edited discipline is about not
	# EDITING those fields, not about leaving the claim unasserted).
	if player.hero.action_state == HeroState.ActionState.CHARGING:
		player.hero.reject_action(&"card_cast", REASON_UNBLOCKABLE_COMMITTED)
		return
	if player.hero.action_state == HeroState.ActionState.STUNNED:
		player.hero.reject_action(&"card_cast", REASON_STUNNED)
		return
	if player.hand.is_slot_empty(hand_slot):
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_EMPTY_SLOT)
		return
	if not player.stamina.spend(balance.defense_stamina_cost,
			balance_ticks.stamina_regen_delay_ticks):
		player.hero.reject_action(&"card_cast", &"insufficient_stamina")
		return
	# AC 7: the card leaves the hand and enters the discard on EVERY commit, hit or miss -- the
	# replacement owed on the VACATED slot, the observation channel announcing, and
	# `card_cast_resolved` queued. `_resolve_unblockable_cast`'s ordering mirrored exactly, all
	# inside this one tick and all UNCONDITIONAL on what happens later at any landing.
	var played := player.hand.remove_at(hand_slot)
	player.discard.add(played)
	# AC 8: the colour is read from the SAME `_card_colors` injected map mode ② already reads, and
	# copied into a plain int. A MISSING ENTRY DEGRADES TO "NO COLOUR" rather than to an invented
	# colour -- the identical unreachable-in-live-play sentinel family the cast-time and grant-time
	# `charge_color` cases already established (`inject_card_colors`'s totality check closes it at
	# the seam).
	player.defense_color = int(_card_colors[played]) if _card_colors.has(played) \
			else PlayerState.NO_TELEGRAPH_COLOR
	# AC 2: the reaction window opens the INSTANT the cast commits, read INLINE from the tick domain
	# (CONSTRAINT C) and never from a seconds float.
	#
	# STORY 6-6b (AC 1/AC 2): THE WINDOW IS NOW THE COLOUR'S BUSY SPAN, and `defense_window_seconds`
	# is superseded as its length. ONE window still, with two spans read off it: it RUNS for the whole
	# counter presentation (busy), and its short ELIGIBILITY head -- read as elapsed ticks at
	# `_counter_color_of` -- is when a commit or launch tick can still be answered. The key
	# `defense = [colour, remaining_ticks]`, its arity and its resting `[-1, 0]` are all unchanged;
	# only what `remaining` counts down means.
	#
	# THE COLOUR IS KNOWN ONE LINE ABOVE, which is what makes a per-colour length cost nothing in
	# window shape. A degraded cast (the sentinel) derives ZERO ticks and opens no window at all --
	# see `BalanceTicks.counter_busy_ticks_for` for why that is the ruled degrade.
	player.defense_window.start(balance_ticks.counter_busy_ticks_for(player.defense_color))
	# STORY 6-6b (AC 9): BLUE's TRAVEL DIRECTION IS LOCKED HERE, at the press, from the live
	# charge-reach bearing of the OTHER slot -- the hero-to-hero fact the runner pushes on every
	# chargeup tick. Written for EVERY colour and read only by BLUE's movement branch, because a lock
	# that only ran for one colour would leave a stale bearing behind for the next press to inherit;
	# writing it unconditionally makes "this press's fact" structural.
	#
	# THE ZERO-TRAVEL FALLBACK IS THE `CHARGING` GATE BELOW, not the store's resting value (REVIEW
	# finding H1). `_charge_reach_dirs` is written on every push and cleared NOWHERE, so it rests at
	# `Vector2.ZERO` only until the first chargeup of the process and holds that chargeup's last
	# bearing afterwards -- across rounds and across a debug reset. AC 9's fallback says "no live
	# chargeup", so this reads exactly that and copies zero otherwise. NOTE the tick ordering it
	# depends on: a chargeup ABANDONED at step 3 of this very tick -- countered (`6-6b`) or knocked
	# down (`6-6a/R1`) -- has already left `CHARGING` by the time this step-6 seat runs, and such a
	# press correctly locks nothing. Since `6-9` no INPUT can produce that edge at all; the two
	# non-input abandonments still can.
	var counter_attacker: PlayerState = p2 if slot == 0 else p1
	_counter_travel_dirs[slot] = _charge_reach_dirs[1 - slot] \
			if counter_attacker.hero.action_state == HeroState.ActionState.CHARGING \
			else Vector2.ZERO
	# AC 5: the ONE state write, and it is BLOCKING-ONLY. This ratifies `5-2/R17` ("casting drops the
	# block") and gives it its FIRST real exercise -- mode ① never calls `set_action_state` at all,
	# and mode ②'s unconditional CHARGING write is unreachable from a blocking hero because
	# `_unblockable_refusal_reason` refuses the cast outright while BLOCKING. Mode ③ is the first
	# cast that is not state-gated against BLOCKING, so it is the first that can genuinely drop one.
	#
	# `ATTACKING` AND `ROLLING` ARE DELIBERATELY LEFT UNTOUCHED, and an unconditional IDLE here would
	# be a live defect rather than merely over-broad: from ATTACKING it would leave the swing's
	# `active` window running and still pushing contacts while the hero is no longer rooted and moves
	# at full speed, with the phase machine never reaching `attack_done`. The swing or roll finishes
	# on its own contract exactly as if no card had been cast.
	#
	# `HeroState.TRANSITION_TABLE` GAINS NO ROW, the identical `5-2/R7` reasoning: the card layer
	# drives this edge directly, not an inbound press the table maps.
	if player.hero.action_state == HeroState.ActionState.BLOCKING:
		player.hero.set_action_state(HeroState.ActionState.IDLE)
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	player.notify_cards_changed()
	_queue.push(card_cast_resolved.emit.bind(slot, played, Enums.ModeKind.DEFENSE))


## Story 5-2 (AC 15-20): THE LANDING, resolved at step 3(a) on the tick the chargeup window expires.
## Reached ONLY from the `CHARGING` arm of `_resolve_actions`, which a DEAD hero cannot enter.
##
## THE REACH CHECK IS READ, NOT COMPUTED. `_charge_reach[slot]` is the runner's every-tick answer
## (AC 17) and this layer never sees a distance, a position or the authored per-colour reach --
## `4-3/R2`'s position ownership intact, `F1` untouched. `REACH_UNKNOWN` lands NOTHING and is NOT
## the same value as OUTSIDE: absence means no measurement was taken, which is a different fact from
## a measurement that said "too far", and the distinction is what keeps a missing push from silently
## deciding a hit.
##
## THE CARD AND THE STAMINA STAY SPENT ON EVERY OUTCOME (AC 19). Nothing below is conditional on the
## hit: AC 6 already ran at the cast, an entire chargeup ago, and mode (2) is fully committal
## (Ruling 4). A miss is a miss -- no damage, no orb, no HP change on either side. THE ORB HALF IS
## NO LONGER A FORWARD REFERENCE: story 5-4 landed the grant inside the landed branch below
## (`_grant_landing_orbs`), so "no orb on a miss" is now a property of where that call sits rather
## than a promise about a story that had not shipped.
##
## AN ENEMY THAT DIED FIRST IS NOT HIT (AC 16). Like its step-3/4/5/6 siblings this branch is
## unreachable in natural play -- DEAD and `_round_over` are set together, and step 1b returns
## before step 2 -- and is written anyway, in exactly that defense-in-depth family, proven
## non-vacuous by the same forced-DEAD idiom (`set_action_state(DEAD)` with `_round_over` left
## FALSE).
##
## NO BLOCK, NO DEFLECT, NO BLOCK ARC. The attack is UNBLOCKABLE by name: `block_damage_multiplier`,
## `is_deflect_window_open()` and `_is_facing` are all deliberately absent from this function.
##
## STORY 6-1c (AC 5) ADDS AN ARC, AND IT IS THE ATTACKER'S, NOT THE DEFENDER'S. `_is_facing` asks
## whether the DEFENDER faces its attacker (a block); `_is_in_charge_arc` asks whether the defender
## lies inside the ATTACKER's per-colour threat shape, around the attacker's frozen committed
## direction. It joins the reach KIND in the one entry gate below and answers nothing a block does.
##
## STORY 6-6b RETIRES THE DEFENSE RUNG THIS PARAGRAPH USED TO DESCRIBE. `5-5` seated the
## colour-matched answer HERE, inside the landed branch below; `5-6` hung the attacker's stun off it.
## Both are gone (6-6b AC 5): the colour answer is judged in the ATTACKER's own CHARGING arm, at the
## COMMIT and on every pre-contact launch tick, and a counter RETURNS from that arm before this
## function is called at all. So this function no longer reads or writes `defense_window` /
## `defense_color` on any path, and every landing that reaches it was, by construction, not countered.
## What is unchanged: it still consults NEITHER the block multiplier, NOR the deflect window, NOR the
## facing arc, and the tiers below it are `5-6`'s, minus the colour rung (Non-Goals).
##
## NO MANA. `_generate_mana` awards per entry in the list `_resolve_contacts` returns, and a landing
## resolved here never enters that list -- the `4-3b/R4` gate applied to a second non-swing source,
## by the same mechanism (staying out of the list) rather than by a second check inside the faucet.
##
## `hit_landed` IS EMITTED, on the shipped payload unchanged: the enemy hero really is hurt, so the
## telegraph flash and sting on that hero are correct -- `4-3b/R5`'s reasoning for the unit-attacker
## case, which turns on the TARGET being a damaged hero rather than on who swung.
##
## `balance` IS NON-NULL HERE by construction: a chargeup can only have been started by a cast that
## already read `balance.unblockable_stamina_cost`.
func _resolve_charge_landing(player: PlayerState, slot: int) -> void:
	var opposing_slot := 1 - slot
	var target := p2 if slot == 0 else p1
	# STORY 6-1c (AC 5/AC 6): THE ONE REACH GATE GROWS ONE CONJUNCT, AND STAYS ONE GATE. The runner's
	# KIND still answers the per-colour RADIUS; `_is_in_charge_arc` answers the per-colour ARC against
	# the frozen committed direction. Both sit in this single condition, ahead of the ladder, so an
	# attack outside either reaches NONE of the rungs below -- no second landing check exists, and no
	# rung is reachable around this one.
	#
	# STORY 6-1d (AC 1/AC 4/AC 5/AC 6): THIS LINE IS UNEDITED, and that is the claim. Contact became
	# honest geometry sampled on every committed tick, but it arrives through the SAME latch, gates
	# the SAME single ladder, and fires exactly once on the tick `landing_window` closes. The whole
	# change lives in what `push_contact` writes into `_charge_reach[slot]` and when -- see there.
	# The arc conjunct is still state policy over the runner's direction fact and can still only
	# REMOVE a hit the geometry admitted; it never widens one. Since `6-1d/R8` it reads the bearing
	# latched WITH the `INSIDE` verdict, so both conjuncts judge the same tick's measurement.
	if _charge_reach[slot] == CONTACT_CHARGE_REACH_INSIDE and _is_in_charge_arc(player, slot) \
			and target.hero.is_alive():
		# STORY 6-6b (AC 5): THE LANDING-TICK NEGATION RUNG IS RETIRED, AND ITS ABSENCE IS THE AC.
		# `5-5` seated the colour answer HERE, on the landing tick, against a window armed up to 1.5 s
		# earlier; `5-6` hung the attacker's `color_counter_stun_ticks` off it. Both are gone. The colour
		# answer is now judged in the ATTACKER's own CHARGING arm, at the COMMIT and on every pre-contact
		# launch tick (`_resolve_color_counter`), and it KNOCKS THE ATTACKER DOWN rather than stunning it.
		#
		# SO AN ELIGIBLE WINDOW ON THE LANDING TICK WITH FIRST CONTACT ALREADY REGISTERED DOES NOT NEGATE,
		# and that is structural rather than a new check: a counter returns from the CHARGING arm before
		# this function is ever called, so any landing that reaches this line was not countered.
		#
		# `defense_window` / `defense_color` ARE NO LONGER READ OR WRITTEN HERE AT ALL. Nothing consumes
		# the window any more -- it ends by expiry or by the debug reset and by nothing else -- which is
		# what makes `5-5` AC 11's wrong-colour survival true BY CONSTRUCTION instead of by a branch
		# placement a mutation could move (AC 5: the mutation proof moves to the observable half).
		#
		# WHAT IS BYTE-UNTOUCHED IN BEHAVIOUR (AC 5): the dodge rung directly below and the
		# unanswered-package tier under it. The dodge rung becomes the ladder's FIRST sub-rung instead of
		# its middle one, which changes its SEAT and nothing it does -- it is still the universal,
		# card-less fallback, and it still stuns nobody.
		# STORY 5-6 (AC 7): THE DODGE RUNG — the ladder's MIDDLE tier, and entirely new logic rather
		# than a pre-existing behaviour surfaced. This function's own header enumerates what it does
		# NOT consult (no block, no deflect, no arc) and, measured, it never consulted the defender's
		# iframe either: the generic step-4 contact ladder's `1-9/R1` iframe drop
		# (`_resolve_contacts`) is a STRUCTURALLY SEPARATE function and none of it applies here.
		#
		# THE PREDICATE IS READ FROM THE STEP-3 LATCH, NOT LIVE (AC 7's correction) — see
		# `_iframe_open_at_step3` for why a live read would make the dodge seat-dependent. It is the
		# defender's slot that is indexed, i.e. `opposing_slot`.
		#
		# READ-ONLY (AC 8): `roll_iframe` is neither consumed nor cleared here, and
		# `_roll_iframe_closed_this_tick` is untouched — the SAME "read the predicate, drop the
		# outcome" idiom the generic ladder uses. Dodging an unblockable neither ends the iframe
		# window early nor extends it; it runs its own course exactly as `1-9/R3` already requires for
		# every other contact.
		#
		# NO STUN ON THIS BRANCH, deliberately and not by oversight: Ruling 1b names an attacker
		# consequence for the COLOUR counter (above) and none for a dodge. Do not add one by analogy.
		#
		# NO ORB GRANT EITHER WAY (Ruling 1b): `_grant_landing_orbs` is simply not called on this
		# branch, the same "stay out of the list" mechanism the mana gate uses rather than a second
		# check inside the grant.
		if _iframe_open_at_step3[opposing_slot]:
			# THE MULTIPLY-AND-EMIT-AT-SURVIVING-MAGNITUDE PRECEDENT (`block_damage_multiplier`,
			# `:1447-1456`): the full damage is computed exactly as the Ruling 1c path below computes
			# it and then scaled. At the authored `dodged_unblockable_damage_multiplier = 0.0` the
			# effective damage is EXACTLY zero, so the guard below suppresses the emit entirely and a
			# clean dodge is SILENT — the same full suppression the colour-match tier gets, not a
			# zero-magnitude `hit_landed` a consumer would render as a hit for no damage. Retune the
			# multiplier positive and the same lines emit at the surviving magnitude, with no code
			# change: that is what makes this a genuine rung rather than a hardcoded "None".
			var dodged := balance.unblockable_damage_percent_of_max_hp / 100.0 \
					* target.hero.get_max_hp() * balance.dodged_unblockable_damage_multiplier
			# Story 6-5a (AC 9): the funnel is SEATED after the dodge multiplier, the block seat's
			# seating. Like there the ORDER is unobservable -- both are scalar factors, so the product
			# is the same either way (6-5a REVIEW N1); what the seating buys is that `_apply_lifesteal`
			# below measures the hp a POST-dodge number actually removed. A zero stays zero through any
			# order, so a clean dodge stays silent under Bloodlust too.
			dodged = _funnel_damage(player, TargetingService.HERO_INDEX, target,
					TargetingService.HERO_INDEX, dodged)
			if dodged > 0.0:
				var dodged_hp_before := target.hero.get_hp()
				target.hero.take_damage(dodged)
				_apply_lifesteal(player, TargetingService.HERO_INDEX,
						dodged_hp_before - target.hero.get_hp())
				_queue.push(hit_landed.emit.bind(slot, opposing_slot, dodged, target.hero.get_hp()))
		else:
			# AC 18: the `attack_damage_percent_of_max_hp` expression verbatim, against the TARGET's
			# own maximum, under the name that says which attack it belongs to. One value for all
			# three colours in this story (Ruling 2). Story 5-6 (Ruling 1c): the ladder's THIRD tier
			# — the UNANSWERED landing — reached only when neither the colour counter nor the dodge
			# answered it, and UNTOUCHED by this story beyond becoming an `else`.
			#
			# STORY 6-6a (AC 3/AC 6/R-PRESS): THE DAMAGE, THE KNOCKDOWN AND `hit_landed` ARE NO LONGER
			# APPLIED HERE -- they are one LANDING PACKAGE, owed to the victim and applied after step 6 by
			# `_apply_landing_packages` (see `_landing_package_pending` for why a write at this seat would
			# be seat-dependent). The orb grant STAYS: it is the CASTER's payout for a landing this ladder
			# has already decided, not something that happens to the victim.
			_landing_package_pending[slot] = true
			_grant_landing_orbs(player)
	# AC 20: the exit is UNCONDITIONAL on hit or miss, and it is the last thing that happens so the
	# damage above is applied while the hero is still, conceptually, mid-attack. The telegraph key
	# stops being reported the moment this line runs, because `PlayerState.to_snapshot()` derives it
	# from `CHARGING` rather than from a flag something has to remember to clear.
	#
	# STORY 5-6 (AC 5): it now covers THREE of the four outcomes rather than all four — the negation
	# returns above with its own single `STUNNED` write. Miss, dodge and full damage all still end
	# here, exactly once each.
	player.hero.set_action_state(HeroState.ActionState.IDLE)


## Story 6-6a (AC 3/AC 5/AC 6/AC 7/AC 12): THE LANDING PACKAGE, applied at step 6b -- see
## `_landing_package_pending` for why it is deferred from the landing and why the unit of deferral is the
## whole package. For each owed slot, in fixed P1 -> P2 order, the INTERNAL ORDER is pinned:
##   1. DAMAGE -- the unanswered tier's expression verbatim, against the victim's own maximum.
##   2. THE KNOCKDOWN, the THIRD authored inbound edge to `STUNNED` (after the colour counter and the
##      melee deflect), written on the VICTIM -- never the caster, whose own `CHARGING -> IDLE` exit at
##      the landing is untouched ("one write per outcome" holds per hero). GATED on `is_alive()` AFTER
##      the damage, so a lethal landing writes nothing here and step 8 writes `DEAD` alone -- no phantom
##      `STUNNED` for presentation to see and then have stomped.
##   3. `hit_landed` -- pushed AFTER the knockdown write, so a presentation consumer mirroring the
##      action state through the SAME FIFO drain has already left `BLOCKING` by the time it reads the
##      hit (AC 12: no stale `block_impact` on a knockdown).
##
## THE FLOOR RULE (AC 7, R-STUNSTACK): a victim ALREADY in a knockdown takes the damage and the signal but
## NO write -- the running window is neither restarted nor extended, so a downed hero cannot be held down
## by repeated landings. A victim in an ORDINARY stun (colour counter or deflect) is NOT floored: the
## write proceeds, `stun.start` REPLACES the shorter window and the flavor becomes knockdown -- a ONE-WAY
## escalation (once down, the floor holds), so no lock can result. That escalation is a same-state
## `STUNNED -> STUNNED` write and emits nothing (`HeroState.set_action_state`); presentation re-reads the
## flavor at `hit_landed`, which this package pushes right after.
##
## A CHARGING VICTIM ABANDONS ITS CHARGEUP (AC 5): `charge_window`, `landing_window` and `charge_color`
## are cleared with the state write as ONE fact -- the same three lines the colour-counter teardown and
## `_reset_player` write (`6-1`'s release arm wrote them too; `6-9` deleted that arm). The
## card and the stamina stay spent. `_charge_reach`/`_charge_contact_dirs` are NOT cleared, for `6-1d/R9`'s
## reason ("cleared with the verdict, never on its own"), exactly as the counter teardown leaves them.
##
## `balance` and `balance_ticks` are non-null: a package is only ever owed by a landing, which needs both.
func _apply_landing_packages() -> void:
	for slot: int in 2:
		if not _landing_package_pending[slot]:
			continue
		_landing_package_pending[slot] = false
		var opposing_slot := 1 - slot
		var target := p2 if slot == 0 else p1
		var damage := balance.unblockable_damage_percent_of_max_hp / 100.0 * target.hero.get_max_hp()
		# Story 6-5a (AC 9): the landing seat's funnel; the caster (`slot`'s player) is the attacker.
		var caster := p1 if slot == 0 else p2
		damage = _funnel_damage(caster, TargetingService.HERO_INDEX, target,
				TargetingService.HERO_INDEX, damage)
		var landing_hp_before := target.hero.get_hp()
		target.hero.take_damage(damage)
		_apply_lifesteal(caster, TargetingService.HERO_INDEX, landing_hp_before - target.hero.get_hp())
		var already_down := target.hero.action_state == HeroState.ActionState.STUNNED \
				and balance_ticks.is_knockdown_stun(target.hero.stun.duration_ticks())
		if target.hero.is_alive() and not already_down:
			var was_charging := target.hero.action_state == HeroState.ActionState.CHARGING
			target.hero.stun.start(balance_ticks.knockdown_stun_ticks)
			target.hero.set_action_state(HeroState.ActionState.STUNNED)
			if was_charging:
				target.charge_window.start(0)
				target.landing_window.start(0)
				target.charge_color = PlayerState.NO_TELEGRAPH_COLOR
		_queue.push(hit_landed.emit.bind(slot, opposing_slot, damage, target.hero.get_hp()))


## Story 6-6b (AC 1/AC 3/AC 7/AC 8): CAN THIS HERO ANSWER AN UNBLOCKABLE RIGHT NOW, AND IN WHAT COLOUR?
## Returns the colour, or `NO_COUNTER_COLOR` for every reason it cannot. Called ONLY from the step-3
## capture (`_counter_color_at_step3`), never live at a judgement -- see that member for why.
##
## POST-SMOKE (R-S6): THE WHOLE BUSY SPAN IS THE COUNTER WINDOW. The short ELIGIBILITY HEAD this
## function used to measure -- `duration_ticks() - remaining_ticks() <= counter_eligibility_ticks` --
## IS GONE, with the authored field and its tick twin. The operator's ruling after the live smoke:
## "as long as you initiate the defence before the attack touches you, it should defend". So the one
## timing question left is `is_running`, and "too early" now means the counter RAN OUT before the
## attack committed -- the counter was spent, the press was never refused. `6-6b` AC 6's feint bait is
## SUPERSEDED by `6-9` (click-to-commit): there is no feint left to bait with, so every paid chargeup
## reaches a judged tick. The widening this paragraph describes is itself untouched.
##
## THE PRESS STILL CANNOT ANSWER ITS OWN TICK, and that stays structural rather than a boundary to
## defend: the press resolves at STEP 6, after that tick's step 3, so a window pressed on the commit
## tick is not yet running when this is read.
##
## THE DEFENDER-STATE GATES ARE AC 7's, and they close the `6-6a` deferred-work item "a downed hero
## keeps a defense window armed ... and can colour-counter while down". `5-5`/`5-6` refused only the
## ARMING of a new window (`_resolve_defense_cast`'s CHARGING/STUNNED gates) and the old landing rung
## read no defender state at all, so a window armed before a knockdown went on answering from the
## floor. A hero getting up is caught by `is_getting_up()`; a hero whose knockdown runs out at THIS
## tick's step 2 is still `STUNNED` here (`_gets_up_this_tick`'s own arming condition says so), so the
## exit tick needs no separate clause.
##
## THE SENTINEL IS NOT EXCLUDED HERE, deliberately: it is excluded at the JUDGEMENT
## (`_resolve_color_counter`), on BOTH sides at once, because the rule `5-5`'s review fix established
## is symmetric -- a degraded defense must never answer a degraded chargeup, and stating it once where
## both colours are in hand is what keeps the two halves from drifting apart. In practice a degraded
## cast opens no window at all (`BalanceTicks.counter_busy_ticks_for`), so this returns early anyway.
##
## `balance_ticks` IS STILL CHECKED, even though no count is read here any more: the capture runs on
## every tick of every match, including the pre-injection ones a headless fixture can build, and the
## rest of the counter path (the busy span that opened this window) cannot exist without it.
func _counter_color_of(player: PlayerState) -> int:
	if balance_ticks == null or not player.defense_window.is_running:
		return NO_COUNTER_COLOR
	if not player.hero.is_alive():
		return NO_COUNTER_COLOR
	if player.hero.action_state == HeroState.ActionState.STUNNED:
		return NO_COUNTER_COLOR
	if player.hero.is_getting_up():
		return NO_COUNTER_COLOR
	return player.defense_color


## Story 6-6b (AC 3, the ruled commit-tick ordering): is THIS the tick this attack committed on -- the
## first tick its chargeup window reads closed?
##
## READ OFF THE TWO WINDOWS' OWN SNAPSHOTTED DURATIONS, never off `balance_ticks`, and that is what
## makes it survive a mid-flight balance reload: `TimingWindow.start()` snapshots the duration, and a
## running window keeps it (D4). `landing_window` was started at the cast with chargeup + launch, and
## `charge_window` with the chargeup alone, so the tick `landing_window`'s ELAPSED count first equals
## `charge_window`'s whole duration is exactly the tick the chargeup closed. Both windows are ticked
## once each at step 2 and neither is restarted mid-flight, so the equality holds on exactly one tick.
##
## WHY THE COMMIT TICK NEEDS NAMING AT ALL. `_resolve_color_counter` must NOT consult `_charge_reach`
## on it: a defender already in reach at the commit can still be countered (the operator's ruling),
## and any `INSIDE` present at that judgement is NECESSARILY this tick's own push -- the cast seat
## cleared the latch (`6-1d/R9`), `push_contact` writes a verdict only inside the contact window and
## CLEARS outside it, and `is_contact_window_open()` first reads true on the commit tick itself
## (`player_state.gd:327-328`). On every LATER judged tick the live latch read stands, because a latch
## there means a contact has registered, whichever tick wrote it. Zero new state, `push_contact`
## unedited.
##
## THE DEGENERATE CASE IS NAMED, NOT GUARDED: with a 0-tick chargeup the cast seat starts a window
## that never runs, the CHARGING arm first runs on the NEXT tick with `landing_window` already one
## tick elapsed, and this returns false there -- so a zero-chargeup attack is judged with the latch
## live from its first judged tick. The authoring audit keeps a 0-tick chargeup out of the shipped
## `.tres`, exactly as it does for every other window whose zero degrade is defined rather than fatal.
func _is_commit_tick(player: PlayerState) -> bool:
	return player.landing_window.duration_ticks() - player.landing_window.remaining_ticks() \
			== player.charge_window.duration_ticks()


## Story 6-6b (AC 3/AC 4/AC 8): THE COLOUR COUNTER, judged and resolved at the ATTACKER's own step-3
## CHARGING seat. Returns true when the counter LANDED, which the caller reads as "this arm is done".
##
## THE JUDGED SPAN IS THE COMMIT THROUGH THE LANDING TICK, expressed as "the chargeup window has
## stopped". That is the one fact that says LAUNCHED (`6-1c`: chargeup running = pre-launch, stopped =
## committed to the flight), and it stays true on the landing tick, which is what AC 5's "a counter on
## the landing tick with no contact ever registered lands rather than the attack whiffing" requires.
## During the chargeup this returns false at the first line, so a counter pressed against a chargeup
## that is then ABANDONED BY A KNOCKDOWN (`6-6a/R1`) expires silently and the defender still pays the
## card, the stamina and the busy time. `6-9` retired the other way that could happen: no input
## feints any more, so an unanswered counter is now the knockdown case or none at all.
##
## EVERY FACT ABOUT THE DEFENDER COMES FROM THE STEP-3 CAPTURE (AC 8) and not one is read live, so the
## mutual case resolves seat-symmetrically: both counters land and both heroes go down. The ATTACKER's
## facts are read live because they are this seat's OWN hero -- no ordering hazard exists for them.
##
## THE SENTINEL EXCLUSION IS `5-5`'s REVIEW FIX, KEPT VERBATIM and for its measured reason: the
## totality check that keeps both colours off the sentinel is `Invariant.check`, i.e. assert()-backed
## and STRIPPED IN EXPORTED BUILDS, so without an explicit exclusion a degraded defense (colour -1)
## would compare equal to a degraded chargeup (colour -1) and answer it. Two failures must never make
## a counter.
##
## WHAT LANDING DOES, in order and all of it (AC 4):
##   1. `deflect_landed` on the EXISTING seam, carrying the ANSWERED COLOUR -- the signal's second
##      emit site, the first being the melee/unit parry, which passes `NO_TELEGRAPH_COLOR` and keeps
##      its untinted cue. The colour sentinel is what tells the two apart downstream.
##   2. THE ATTACK IS TORN DOWN -- the `6-6a` CHARGING-abandonment triple verbatim (`charge_window`,
##      `landing_window`, `charge_color`). The card and the stamina STAY SPENT.
##   3. THE ATTACKER IS KNOCKED DOWN, reusing the existing knockdown PACKAGE unchanged:
##      `knockdown_stun_ticks` read inline (CONSTRAINT C), the `BalanceTicks.is_knockdown_stun` flavour
##      classifier, and with it the get-up lock and the get-up iframes the STUNNED timer exit arms. No
##      new stun kind, no new duration field, and NO DAMAGE.
## The defender takes no damage, no `hit_landed` is emitted, and `_grant_landing_orbs` never runs --
## all three by not being reached, never by a suppressing branch.
##
## IT IS A NEW FOURTH AUTHORED `STUNNED` ENTRY POINT, argued the way `6-6a` argued its third and pinned
## by `test_action_state.gd`: a DIFFERENT SUBJECT (the attacker, punished for being answered -- the
## knockdown site punishes the victim for failing to answer), a DIFFERENT SEAT (the attacker's own
## step 3, not step 6b's deferred package), and NO DAMAGE. It is NOT the `6-6a` seat and cannot reuse
## it: `_apply_landing_packages` writes the VICTIM and applies damage unconditionally.
##
## NO CROSS-PLAYER WRITE HAPPENS HERE, which is why `_landing_package_pending`'s prohibition does not
## bite: the only hero written is `player`, this seat's own. The DEFENDER is only READ -- and read
## from the capture. The `already_down` floor rule does not apply either: a CHARGING attacker is not
## down. `_resolve_movement` follows immediately and its STUNNED branch roots the attacker.
##
## EXACTLY ONE `set_action_state` PER OUTCOME (the `5-6` rule): `CHARGING -> STUNNED` directly, with no
## `IDLE` in between, because the caller returns before `_resolve_charge_landing`'s trailing `IDLE`.
##
## `_charge_reach` / `_charge_contact_dirs` ARE DELIBERATELY NOT CLEARED, `6-1d/R9`'s "cleared with the
## verdict, never on its own" applied exactly as the knockdown teardown applies it: with
## `landing_window` stopped, `is_contact_window_open()` is false and the very next push takes the
## clearing arm, and the next cast seat resets both anyway.
##
## `balance_ticks` IS NON-NULL HERE by construction: a hero can only be CHARGING because a cast read it.
func _resolve_color_counter(player: PlayerState, slot: int) -> bool:
	if player.charge_window.is_running:
		return false
	var defender_slot := 1 - slot
	var answered := _counter_color_at_step3[defender_slot]
	if answered == NO_COUNTER_COLOR or player.charge_color == PlayerState.NO_TELEGRAPH_COLOR:
		return false
	if answered != player.charge_color:
		return false
	if not _is_commit_tick(player) and _charge_reach[slot] == CONTACT_CHARGE_REACH_INSIDE:
		return false
	_queue.push(deflect_landed.emit.bind(slot, defender_slot, answered))
	player.charge_window.start(0)
	player.landing_window.start(0)
	player.charge_color = PlayerState.NO_TELEGRAPH_COLOR
	player.hero.stun.start(balance_ticks.knockdown_stun_ticks)
	player.hero.set_action_state(HeroState.ActionState.STUNNED)
	return true



## Story 6-6a review (D1, operator ruling: the exit tick is part of the get-up): does this hero get up
## from a KNOCKDOWN on THIS tick? True when its knockdown `stun` ran out at this tick's step 2 and the
## step-3 STUNNED arm is about to write IDLE and open the get-up iframes.
##
## WHY THE STEP-3 LATCH NEEDS IT. `_iframe_open_at_step3` is taken before either seat's
## `_resolve_actions`, and the get-up window only starts INSIDE the victim's STUNNED arm, so on the exact
## exit tick the latch read false: an unblockable landing there was unanswered, and at step 6b the victim
## was already IDLE (not floored), so it was knocked straight back down -- with its fresh get-up window
## still running under the new knockdown, and repeatably, every exit tick. Step-4 melee on that same tick
## already read the live predicate AFTER the arm and was dropped, so the two attack types disagreed.
##
## The arm's own arming condition restated, no new storage: STUNNED, `stun` no longer running, the window
## a knockdown by the one classifier, and a get-up window actually authored (a zero window arms nothing
## and so protects nothing). Read before both seats, so it stays seat-symmetric. A knockdown with ticks
## left (the tick before the exit) is still down: its landing is not dodged and hits the floor rule.
func _gets_up_this_tick(hero: HeroState) -> bool:
	return hero.action_state == HeroState.ActionState.STUNNED and not hero.stun.is_running \
			and balance_ticks != null and balance_ticks.get_up_iframe_ticks > 0 \
			and balance_ticks.is_knockdown_stun(hero.stun.duration_ticks())


## Story 5-4 (AC 1/AC 4-7): THE PAYOUT HALF of the RGB read exchange -- a landed unblockable credits
## its attacker orbs of the spent card's own colour. Reached ONLY from the landed branch above, so
## a miss pays nothing without a second test saying so.
##
## COMPUTED BY THE SAME PURE EVALUATOR `_generate_mana` CALLS (AC 1). No second evaluator, no inline
## formula: `EconomyEvaluator.amount_for` sums the authored `data/economy/unblockable_landing.tres`
## rule against the live balance and flags, and THIS function applies the number -- the PURE/APPLY
## split `EconomyEvaluator`'s own header states as doctrine (it computes, MatchState applies), not a
## free placement choice.
##
## NO SECOND FLAG GATE (AC 6). `flags.orbs` is read ONCE, as DATA, by `_flag_open` inside the
## evaluator, because the rule carries `required_flag = &"orbs"`. A closed flag sums to 0.0 and the
## `> 0` guard below turns that into no call and no signal at all -- the `melee_mana_generation`
## precedent verbatim ("a faucet that cannot be verified open stays shut"), never a duplicated check
## here. The damage above is deliberately OUTSIDE this function: a closed orbs layer still lands a
## full-damage hit.
##
## THE COLOUR IS READ, NEVER RECOMPUTED (AC 5). `player.charge_color` has been resident since the
## cast (`_resolve_unblockable_cast`, an entire chargeup ago) and this is a read of that one fact.
## The `NO_TELEGRAPH_COLOR` guard is the SAME recorded family as the cast-time sentinel case at the
## `charge_color` assignment above -- one unreachable-in-live-play case seen from both ends, not two:
## `inject_card_colors`'s totality check closes it at the seam, and a fixture that injects no colours
## grants NOTHING rather than crediting an invented RED.
##
## `roundi`, NOT `int()` (AC 4), and the conversion happens ONCE, here. `amount_for` returns a float
## because it SUMS over rules; `OrbPool` stores ints. The sum of authored ints is exact at these
## magnitudes today, so the two spellings agree -- `roundi` is chosen for the day a second `orbs`
## rule is authored and the sum stops being whole, where truncation would silently swallow it.
## Negative results are impossible (every authored `orbs` amount is non-negative) and are not
## guarded for; the `> 0` guard below is about the ZERO case, not the negative one.
func _grant_landing_orbs(player: PlayerState) -> void:
	if player.charge_color == PlayerState.NO_TELEGRAPH_COLOR:
		return
	var grant := roundi(EconomyEvaluator.amount_for(EconomyEvaluator.authored_rules(),
			EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING, EconomyEvaluator.ORBS,
			balance, balance_ticks, flags))
	# AC 7: a zero grant calls neither `add` nor emits `orbs_changed`, so a closed-flag landing
	# produces no observable orb event AT ALL. Distinct from `OrbPool.add`'s own internal
	# no-op-on-no-change short circuit (AC 8) -- that one is about a clamp that changed nothing,
	# this one is about a faucet that paid nothing.
	if grant > 0:
		player.orbs.add(player.charge_color, grant)
		# Story 6-3b (AC 1 site (e)): the one seat where orbs GROW inside a staged window, so READY
		# reaches the pitch HUD on the tick it becomes true rather than up to one throttle interval
		# late. Only a staged zone -- an empty one has no READY to flip.
		var grant_slot := 0 if player == p1 else 1
		if pitch.is_staged(grant_slot):
			_queue_pitch_changed(grant_slot)


## Story 6-3b (AC 1): THE ONE EMISSION HELPER for `pitch_changed`, called from the six seats that doc
## enumerates. Every value is READ at the call: the zone's card and hand slot, READY derived live
## against the owner's pool and the injected flags, and the countdown off the zone's own `"fizzle"`
## snapshot entry -- no new `PitchState` or `MatchState` accessor, no new member, no latch. Queued with
## its payload bound at push (D5), the `card_cast_resolved` shape.
func _queue_pitch_changed(slot: int) -> void:
	var owner: PlayerState = p1 if slot == 0 else p2
	var fizzle: Dictionary = pitch.to_snapshot()["p1" if slot == 0 else "p2"]["fizzle"]
	var duration := int(fizzle["duration_ticks"])
	_queue.push(pitch_changed.emit.bind(slot, pitch.staged_card_id(slot), pitch.staged_hand_slot(slot),
			pitch.is_ready(slot, owner.orbs, flags), duration - int(fizzle["elapsed_ticks"]), duration))


## Step-6 delivery of ONE owed replacement (story 3-5b, AC 3/AC 5/AC 7/AC 10). Seated after the
## cast dispatch; see the call site for why both halves of that ordering are load-bearing.
##
## The window is READ, never stopped: a delivery is due when the debt is non-zero and the window
## is not running, which is true both for a window that expired at step 2 and for one that was
## started with a zero duration this very tick. Exactly ONE card per expiry, then the window
## RESTARTS while the debt is still above zero, so four casts in flight deliver four cards one at
## a time rather than four at once.
##
## DEATH DROPS THE DELIVERY, NEVER THE WINDOW (AC 7). 1-9/R3 stays locked — no early-stop path
## ships anywhere in this file; a dead player's window ticks out normally and the CARD is simply
## discarded, the 1-9/R1 fact-drop idiom applied literally. The debt is still consumed, because a
## corpse that came back would otherwise be handed a backlog. Like its step-3/4/5/6 siblings this
## branch is UNREACHABLE in natural play (3-5/R6: DEAD and _round_over are set together and
## cleared together, so a DEAD player is always also frozen and step 1b returns before step 2) —
## it is defense in depth in exactly that family, and is proven non-vacuous the same way each of
## them is, by the forced-DEAD idiom (`set_action_state(DEAD)` with _round_over left FALSE).
func _deliver_pending_draw(player: PlayerState, slot: int) -> void:
	if player.pending_draw_owed.is_empty() or player.pending_draw.is_running:
		return
	# Story 4-0 (AC 4): the debt is popped as a SLOT, not decremented as a count. FIFO — the
	# oldest cast is served first, which is the tie-break the Deferred section leaves free and
	# requires only that no delivery ever land in a slot it wasn't owed to. The pop happens
	# BEFORE the DEAD branch, exactly as the decrement did: a corpse still consumes its debt, so
	# one that came back is not handed a backlog (AC 7, 3-5b).
	var owed_slot: int = player.pending_draw_owed.pop_front()
	if player.hero.action_state != HeroState.ActionState.DEAD:
		_draw_one_replacement(player, slot, owed_slot)
	else:
		# STORY 4-B1 (code review D1): THE DEBT SHRANK, SO THE OBSERVER MUST HEAR ABOUT IT, even
		# though no card moved. "It moved no card, so it does not announce" was correct until 4-B1
		# put `pending_draw_owed` INTO what the cards_changed channel renders: the HUD draws the
		# in-flight caption from the owed list, so a silent pop leaves the vacated slot painted
		# IN_FLIGHT_CAPTION forever with nothing left that will ever repaint it — the permanent
		# hole made indistinguishable from an in-flight slot all over again, which is the exact
		# deferred-work.md finding this story exists to discharge. The announcement carries no new
		# key and no new value; the payload is the same three fields it always was.
		player.notify_cards_changed()
	if not player.pending_draw_owed.is_empty():
		player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)


## The draw itself, with the LAZY reshuffle in front of it (story 3-5b, AC 5/AC 10).
##
## LAZY, NOT EAGER: nothing happens at deck_size == 0: the pile is refilled at the moment a draw
## would otherwise find it empty, which is the only moment the state layer can observe the need.
##
## BOTH EMPTY IS A NO-OP DEGRADE, NEVER A CRASH (AC 10). No Invariant.check ships on this path,
## deliberately unlike the injection seams: reachability here depends on AUTHORED BALANCE NUMBERS
## (a small deck against a long delay drains both piles), and a crash path reachable from authored
## data is not acceptable. The owed card is consumed by the caller either way, the hand simply
## stays short — hand_size is permitted to reach 0 — and NO vulnerable window opens, because
## there was nothing to reshuffle.
## STORY 4-0 (AC 4/AC 8): the drawn card is written INTO THE OWED SLOT, never appended. That one
## substitution is what the whole story buys — the card in the slot the player cast is the exact
## card its replacement refills, rather than a rename of whichever card slid into that position.
##
## AC 8 RULES WHAT THE BOTH-EMPTY DEGRADE NOW MEANS, and it is design, not an observation. The
## debt is consumed by the caller either way; under this shape the consequence is that the HOLE
## PERSISTS and that slot refuses through AC 3 for the rest of the round. The same cards are lost
## as before this story — what changed is that the loss is addressed to a specific,
## permanently-refusing slot rather than to a shorter hand. "hand_size is permitted to reach 0"
## survives and now reads as occupied_count() reaching 0 against a still-full-width hand.
func _draw_one_replacement(player: PlayerState, slot: int, hand_slot: int) -> void:
	if player.deck.is_empty():
		if player.discard.is_empty():
			# STORY 4-B1 (code review D1): the both-empty degrade ANNOUNCES before returning. Same
			# reason as the DEAD pop in the caller: the debt has already been consumed there, and
			# since 4-B1 the owed list is part of what the channel's consumer RENDERS, so a silent
			# return leaves this slot painted IN_FLIGHT_CAPTION with no repaint ever coming. The
			# hand did not move — the DEBT did, and that is now an observable change. The comment
			# below ("the both-empty degrade returns above without announcing") described the
			# pre-4-B1 contract and is superseded here.
			player.notify_cards_changed()
			return
		_reshuffle_discard_into_deck(player, slot)
	player.hand.fill_at(hand_slot, player.deck.draw_top())
	# Story 3-6 (AC 2): the THIRD and last announcement seat. Seated AFTER the lazy reshuffle
	# above rather than inside it, so a delivery that had to refill the pile announces ONE
	# settled payload — the reshuffled deck count and the refilled hand together. The both-empty
	# degrade used to return above WITHOUT announcing, because it moved no card; since 4-B1's code
	# review it announces too, because the DEBT moving is itself observable (see there).
	player.notify_cards_changed()


## Story 3-5b (AC 5/AC 6): this player's discard folded back into this player's deck, inside the
## one existing step-6 RNG seat.
##
## NO NEW `Deck` OR `Hand` METHOD, and that is a delivered constraint rather than a style note:
## the whole operation is expressible with the containers' shipped surface (set_contents +
## the shared shuffle helper + clear), which is what keeps the Deck/Hand method-name fence green.
## A `Deck.reshuffle()` would kill that fence.
##
## THIS PLAYER'S OWN DISCARD ONLY. It never touches the opponent's piles and never re-derives a
## fresh composition from the injected content — a reshuffled pile is exactly the cards this
## player has played, which is what makes the four-term conservation property hold across it.
## `draw_top()` takes the LAST element (the fixed "top is the back" convention, 3-3), so the
## shuffle above decides what the reshuffled pile hands back first.
func _reshuffle_discard_into_deck(player: PlayerState, slot: int) -> void:
	player.deck.set_contents(player.discard.to_array())
	_shuffle_deck(player.deck)
	player.discard.clear()
	# AC 6: the window and its announcement, together and nowhere else. The window's duration is
	# read INLINE (CONSTRAINT C) so a mid-match reload takes effect at the next reshuffle while an
	# already-running window keeps its own. The signal is QUEUED (D5) and relayed by the runner.
	player.vulnerable_window.start(balance_ticks.reshuffle_vulnerable_window_ticks)
	_queue.push(reshuffle_vulnerable_window_opened.emit.bind(slot))


## INVARIANT F2, MACHINE-CHECKED (story 3-5b, AC 16 — `3-5b/R17` corrected by `3-5b/R18`).
##
## THE ONE SEEDED-SHUFFLE CALL SITE IN `src/`. Both shuffle OCCASIONS route through here — the
## match-start/debug-reset deal (_deal_player) and the lazy reshuffle above — so
## `shuffle_with_rng(` appears in exactly TWO places in the whole of `src/`: its definition in
## deck.gd and this one line. test_architecture_invariants.gd pins that count.
##
## Why a helper rather than two call sites: F2 ("the seeded RNG is consumed only inside
## advance()") has been cited as a contract by 3-3, 3-5a and 3-5b and was REVIEW-ENFORCED ONLY —
## the D3(b)/A2 scan bans GLOBAL RNG in src/state/, not a SECOND SEEDED SEAT, so nothing in the
## suite would have failed if `_rng` had grown a second consumer. This story is the first that
## could introduce one. Collapsing both occasions onto one line makes "one seat" literally true
## rather than approximately true, and makes it countable.
func _shuffle_deck(deck: Deck) -> void:
	deck.shuffle_with_rng(_rng)


## Step-7 throttled targeting (story 4-2, AC 5/AC 7/AC 8/AC 11) — the shared tick `4-2/R15` ruled.
##
## THROTTLED, NOT PER-FRAME PER-UNIT, and the mechanism is `_tick % interval` (`4-2/R5`(c)): NO NEW
## STATE and NO NEW HASH KEY for the counter itself. `_tick` is already hashed and already
## monotonic, so the cadence rides state that exists rather than adding a per-unit or per-match
## timer — which is also why a replay reproduces the cadence for free.
##
## `balance_ticks == null` JOINS THE PRE-INJECTION GUARD FAMILY (step 3's _resolve_actions, step 5's
## regen, step 6's deal, step 4's `balance == null` twin): the interval has no value to read yet, and
## a modulo against a zeroed BalanceTicks field would divide by zero. THE one guard — no scattered
## checks below it.
##
## THE INTERVAL IS READ INLINE (CONSTRAINT C), never cached: a mid-match X3 reload changes the
## cadence from the next tick, and nothing holds a reference to the BalanceTicks object. It cannot be
## zero here — BalanceTicks clamps it to >= 1 at the single conversion boundary (`4-2/R5`(d)), so an
## authored 0 means "every tick" instead of a crash.
##
## `apply_balance` IS DELIBERATELY UNTOUCHED BY THIS STORY (`4-2/R5`(b)). The per-pool reload
## contract (`3-1/R2`) governs POOL BOUNDS; a shared cadence is not one, so there is no per-player
## injection seat for it and none may be invented.
##
## THE RULE SET IS RESOLVED BY NAME, ONCE PER BOUNDARY TICK (`4-2/R17`): the sorted, directory-scanned
## set is asked for `PRIORITY_STANDARD` specifically, never for "whatever sorts first". A missing
## name yields a null priority, which TargetingService reports as REASON_NO_PRIORITY_DATA and turns
## into a NO-TARGET pair — a named outcome, never a crash and never a silent substitution of the
## other authored rule (AC 6).
##
## STORY 4-4 (AC 7, `4-4/R8`): THE HARDCODED `PRIORITY_STANDARD` LOOKUP IS GONE — each unit's
## priority is resolved from ITS OWN KIND's authored `priority_name`. That is the whole of
## `4-2/R17`(c) as assigned here by `4-3/R6`, and the paragraph above it describes what SURVIVES the
## change rather than what it replaces: the rule set is still the sorted directory scan, still
## resolved BY NAME and never by "whatever sorts first", a missing name still yields a null priority
## which `TargetingService` reports as `REASON_NO_PRIORITY_DATA` and turns into a NO-TARGET pair,
## and another rule is still NEVER silently substituted.
##
## THE RULE SET IS FETCHED ONCE PER BOUNDARY TICK, NOT ONCE PER UNIT, which is what keeps this the
## SHARED scan the Performance Rule asks for. What moved inside the per-unit loop is only the NAME
## LOOKUP against that already-loaded set — a linear walk of the two or three authored rules, not a
## directory scan.
func _update_unit_targets() -> void:
	if balance_ticks == null:
		return
	if _tick % balance_ticks.minion_retarget_interval_ticks != 0:
		return
	var priorities := TargetingService.authored_priorities()
	# Fixed P1 -> P2 order, like every other per-player loop in this function's file. The OPPOSING
	# slot is passed explicitly rather than derived inside the evaluator, which is what keeps
	# `4-2/R3`'s "own-side units are never candidates" structural: the evaluator can only ever name
	# the slot it is handed.
	_retarget_units(p1, p2, 1, priorities)
	_retarget_units(p2, p1, 0, priorities)


## One player's board, retargeted against the OPPOSING side only (`4-2/R3`).
##
## THE CANDIDATE FACTS ARE READ ONCE PER BOARD, NOT ONCE PER UNIT: the opposing hero's liveness and
## the opposing board's size are the same for every unit on this board, so hoisting them out of the
## loop is what keeps this a SHARED scan rather than N independent ones — the Performance Rule's
## actual content, not just its cadence.
##
## EVERY UNIT ON A BOARD NO LONGER RESOLVES TO THE SAME TARGET, and story 4-4 is the story this
## paragraph named in advance. It used to read: "EVERY UNIT ON A BOARD RESOLVES TO THE SAME TARGET
## THIS STORY ... 4-3's movement and 4-4's totems differentiate the verdict without moving this
## seat." The verdict is differentiated now and the SEAT DID NOT MOVE — what changed is one lookup
## inside the loop: each unit's priority comes from its own kind (AC 7, `4-4/R8`), so a Combat totem
## and a minion standing on the same board can and do acquire different targets.
##
## THE HOISTED FACTS ARE STILL HOISTED. The opposing hero's liveness and the opposing board's living
## indices are per-BOARD facts, identical for every unit here, and hoisting them is what keeps this a
## SHARED scan rather than N independent ones — the Performance Rule's actual content. Only the
## per-unit half (which priority governs THIS unit) sits inside the loop, because only it varies.
##
## LIVENESS IS `is_alive()`, NOT `action_state == DEAD`, and the distinction is load-bearing on the
## kill tick: step 8 sets DEAD after this step runs, so on the tick a hero's hp reaches zero the
## action state has not caught up yet while `is_alive()` already reports the truth. Judging on the
## state would let a unit acquire a corpse for one tick.
func _retarget_units(owner: PlayerState, opponent: PlayerState, opposing_slot: int,
		priorities: Array[MinionPriority]) -> void:
	if owner.units.is_empty():
		return
	var hero_alive := opponent.hero.is_alive()
	# Story 4-3a (AC 8, `4-3a/R14`): THE TARGETING LIVENESS SEAT — the first of the two this story
	# names. The candidate scan now hands the evaluator the opposing board's LIVING indices instead
	# of its SIZE, so a dead unit's index is not a candidate. Hoisted out of the loop with
	# `hero_alive` for the reason this function's header already gives: these are per-BOARD facts,
	# identical for every unit on this board, and hoisting them is what keeps this a SHARED scan.
	var opposing_living := opponent.units.living_indices()
	for index in owner.units.size():
		# Story 4-4 (AC 7, `4-4/R8`): THE PER-KIND PRIORITY READ. The kind's authored
		# `priority_name` is resolved against the already-loaded rule set BY NAME, and a kind that
		# names a priority `data/minions/` does not author resolves to null — which
		# `TargetingService.reason_for` reports as `REASON_NO_PRIORITY_DATA` and turns into a
		# NO-TARGET pair. NEVER a silent substitution of another rule (AC 7's carried-forward
		# contract), and never a fallback to `PRIORITY_STANDARD`: falling back would make a typo in
		# an authored kind indistinguishable from correct authoring.
		#
		# AN UNRESOLVABLE KIND takes the same path for the same reason — a null kind names no
		# priority, so `priority_named` is asked for the empty name, finds nothing, and the unit
		# holds no target.
		var kind := balance.kind_at(owner.units.kind_index_at(index)) if balance != null else null
		var priority_name: StringName = kind.priority_name if kind != null else &""
		var priority := TargetingService.priority_named(priorities, priority_name)
		# The evaluator COMPUTES, this line APPLIES (D6) — TargetingService touches no board, and
		# UnitBoard.set_target_at is reached only from here. `flags` is read INLINE (CONSTRAINT C),
		# exactly as the step-6 CardEffectResolver call reads it; a closed `minions` flag returns a
		# no-target pair, so a flag-off unit never acquires a target (AC 5).
		var pair := TargetingService.target_for(
			priority, opposing_slot, hero_alive, opposing_living, flags)
		owner.units.set_target_at(index, pair[0], pair[1])


## Story 6-7 (`6-7/R13`): clauses (1)-(3) of the ONE "actually running" predicate -- run key
## held, move_dir non-zero (the controllers already apply deadzone, D3(a); this is a plain
## zero-check at the state boundary), and action_state reads movement normally (none of
## ATTACKING/ROLLING/CHARGING/STUNNED/BLOCKING -- `6-7/R9`/`R10`/`R17`). Clauses (4)/(5) -- the
## latch and the stamina-empty read -- are the caller's job, since they also drive the
## latch-SET decision, which this pure clause-(1)-(3) fact alone does not.
static func _run_pursuit_active(state: HeroState.ActionState, intent: InputIntent) -> bool:
	if state == HeroState.ActionState.ATTACKING \
			or state == HeroState.ActionState.ROLLING \
			or state == HeroState.ActionState.CHARGING \
			or state == HeroState.ActionState.STUNNED \
			or state == HeroState.ActionState.BLOCKING:
		return false
	return intent.is_held(&"run") and not intent.move_dir.is_zero_approx()


func _resolve_movement(player: PlayerState, intent: InputIntent, slot: int) -> bool:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero exhibits no live movement. ASYMMETRIC by
	# downstream consumption (see story Dev Notes): velocity is EXPLICITLY written to zero
	# EVERY tick — HeroActor.drive() reads hero_state.velocity straight into move_and_slide()
	# (hero.gd:26), so a SKIPPED write would leave the last live velocity in place and the
	# corpse would slide forever; facing is SKIPPED (this early return never reaches the
	# facing write below), so its last value persists unchanged — that persistence IS the
	# freeze, storing nothing new (hero.gd:34 only reads facing to derive a display yaw).
	# No new snapshot field: only velocity's VALUE on the DEAD branch changes.
	if player.hero.action_state == HeroState.ActionState.DEAD:
		player.hero.velocity = Vector3.ZERO
		return false
	var actually_running := false
	var dir := intent.move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()  # analog safety; never speed up past move_speed
	# move_dir is CAMERA-space (story 1-2): rotated to world by the slot's pushed basis,
	# yaw only. Identity (nothing pushed — AC 4) short-circuits to the exact E0 planar
	# mapping (intent XY -> world XZ), a true no-op so headless tests and the determinism
	# golden are untouched. velocity stays the REAL world velocity the runner reads (D3);
	# the runner never rotates it afterwards (AC 6).
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	# Story 1-5 (B6, operator decision): attack commitment — while ATTACKING the resolved
	# VELOCITY is scaled by an attack-phase multiplier (authored 0.0 = full root), read
	# inline at the moment of use (CONSTRAINT C). Velocity ONLY — the facing update below
	# is never scaled by the multiplier. ATTACKING is unreachable pre-injection (the step-3
	# balance_ticks guard), so `balance` is non-null on this branch.
	# Story 3-0b (AC5, DEBT E member 2): the multiplier is now PER PHASE — the single flat
	# field is gone and _attack_phase_multiplier() selects windup/active/recovery from
	# HeroState.attack_phase(). No new state: the phase is already derived from which
	# window is running.
	# Story 1-9 (1-9/R6): the ROLL half of the same coupling deferral — while ROLLING the
	# velocity is the entry-locked roll_direction at roll_distance / roll_duration_seconds
	# (the ruling's exact quotient; a SPEED derivation, not window timing — timing stays
	# balance_ticks), both read inline at the moment of use (CONSTRAINT C: a mid-roll
	# reload changes the speed next tick while in-flight windows keep their duration).
	# Live input steers nothing until the roll ends; the facing update below still runs
	# (the ATTACKING-commitment precedent: velocity-only, facing tracks input). ROLLING is
	# unreachable pre-injection too, and the authoring audit guarantees
	# roll_duration_seconds > 0.
	if player.hero.action_state == HeroState.ActionState.ROLLING:
		# Story 6-5a (R2): a BLOODHOUND-boosted roll covers `roll_distance_multiplier` times the distance
		# in the SAME duration -- the speed is what scales. An unboosted roll takes the original
		# expression, untouched, so every roll this seat has ever resolved is bit-identical.
		if player.is_rule_active(PlayerState.RULE_ROLL_BOOST):
			player.hero.velocity = player.hero.roll_direction \
					* (balance.roll_distance * player.rule_a[PlayerState.RULE_ROLL_BOOST]
							/ balance.roll_duration_seconds)
		else:
			player.hero.velocity = player.hero.roll_direction \
					* (balance.roll_distance / balance.roll_duration_seconds)
	elif player.hero.action_state == HeroState.ActionState.CHARGING:
		# Story 5-2 (AC 11, `5-2/R5`): HARD-ROOTED. A literal zero, not a multiplier read from
		# balance -- `5-2/R5` refuses a `charging_move_speed_multiplier` field BY NAME, because a
		# non-zero multiplier is not rooted and authoring one would make "rooted" a tuning value a
		# retune could quietly switch off. The DEAD branch at the top of this function writes zero
		# the same way and for the same downstream reason: `HeroActor.drive()` reads this field into
		# `move_and_slide()` every physics frame, so a SKIPPED write would leave the last live
		# velocity in place and the rooted hero would glide through its own chargeup.
		#
		# THE LUNGE AND THE PHASE MULTIPLIER ARE BOTH BELOW THIS BRANCH and neither applies: they
		# belong to ATTACKING, and mode (2) is not a swing.
		#
		# STORY 6-1c (AC 4): THE ROOT HOLDS FOR THE CHARGEUP ONLY. Once the chargeup window has closed
		# the attack is COMMITTED and the LAUNCH carries the hero along its frozen facing
		# (`_charge_launch_velocity`); `5-2/R5`'s literal zero is untouched for every chargeup tick,
		# which is the phase that ruling was about. Input steers neither phase: `world_dir` is never
		# read on this branch.
		if player.charge_window.is_running:
			player.hero.velocity = Vector3.ZERO
		else:
			player.hero.velocity = _charge_launch_velocity(player)
	elif player.hero.action_state == HeroState.ActionState.STUNNED:
		# Story 5-6 (AC 14): HARD-ROOTED, as a THIRD sibling of the two branches above rather than a
		# new mechanism. `5-2/R5`'s reasoning applies identically and verbatim: a LITERAL ZERO, never
		# a `stunned_move_speed_multiplier` read from balance, because a non-zero multiplier is not
		# rooted and authoring one would make "rooted" a tuning value a retune could quietly soften.
		# The write must happen rather than be skipped for the same downstream reason `CHARGING` and
		# `DEAD` write it: `HeroActor.drive()` reads this field into `move_and_slide()` every physics
		# frame, so a skipped write would leave the last live velocity in place and the stunned hero
		# would glide through its own punish.
		#
		# FACING IS DELIBERATELY LEFT TO FALL THROUGH to the generic lock-direction branch below.
		# Ruling 3 forbids ACTION and MOVEMENT, not the visual heading — the same fallthrough
		# `ROLLING` and `ATTACKING` already get (facing tracks the lock while velocity is overridden),
		# not a new carve-out.
		player.hero.velocity = Vector3.ZERO
	elif player.hero.is_getting_up():
		# Story 6-6a post-smoke ruling `6-6a/R7`: THE GET-UP IS A LOCKED ACTION -- the
		# MOVEMENT half. A FOURTH sibling of the three branches above, written in their exact shape and
		# for their exact reasons: a LITERAL ZERO, never a `get_up_move_speed_multiplier` read from
		# balance (`5-2/R5`'s refusal, applied a third time -- a non-zero multiplier is not rooted), and
		# the write HAPPENS rather than being skipped, because `HeroActor.drive()` reads this field into
		# `move_and_slide()` every physics frame and a skipped write would leave the last live velocity
		# in place, sliding the hero across the floor through its own get-up.
		#
		# THE STATE HERE IS `IDLE`, which is why this branch keys on the WINDOW and not on a state: the
		# knockdown's timer exit writes `IDLE` and opens the window in the same arm (step 3(a)), so
		# `action_state` has nothing left to distinguish. It sits BELOW the three state branches so
		# their behaviour is bit-identical to before this pass; the window cannot legitimately be open
		# in any of those states anyway, since every entry to them is refused while it runs.
		#
		# FACING FALLS THROUGH to the generic lock-direction branch below, `STUNNED`'s own carve-out
		# repeated verbatim: the ruling forbids ACTION and MOVEMENT, not the visual heading.
		player.hero.velocity = Vector3.ZERO
	elif player.defense_window.is_running \
			and player.hero.action_state != HeroState.ActionState.ATTACKING:
		# Story 6-6b (AC 2/AC 9): THE COUNTER-BUSY MOVEMENT BRANCH -- a FIFTH sibling of the four
		# branches above, written in the get-up branch's exact shape (`:4085`) and for its exact
		# reason: it keys on a WINDOW and not on a state, because the counter introduces no
		# `ActionState` of its own and `action_state` has nothing left to distinguish.
		#
		# IT SITS BELOW THE FOUR BRANCHES ABOVE so their behaviour is bit-identical to before this pass.
		# ROLLING co-occurs and WINS from up there, by design: AC 1 requires a swing or roll in progress
		# to finish on its own contract, so a hero that cast DEFENSE mid-roll keeps rolling and this
		# branch takes over when the roll ends. The get-up branch co-occurs too -- a window armed before
		# a knockdown keeps ticking through it (`5-5`, and `_counter_color_of`'s own `is_getting_up()`
		# gate exists because that state is reachable) -- and the GET-UP WINS, which since R-S1 is a
		# visible answer rather than two zeroes agreeing: a hero getting up off the floor stays rooted
		# instead of being carried by the counter travel of a window that outlived its knockdown.
		# `DEAD` never reaches here at all: the early return at the top of this function zeroes a
		# corpse's velocity first.
		#
		# `ATTACKING` IS THE ONE SIBLING THAT IS NOT A BRANCH ABOVE -- it lives in the `else` arm below,
		# where the phase multiplier and the `3-0b` LUNGE are applied -- so AC 1's "finishes on its own
		# contract" has to be said HERE, in this branch's own condition, or the busy root silently eats
		# the lunge of a swing that cast DEFENSE mid-flight. The dev pass's comment claimed ATTACKING
		# won "from above" and the code gave it the root instead (REVIEW finding H2); the guard below is
		# what makes the claim true, and the swing's own contract is unchanged from before this story.
		#
		# GREEN WRITES A LITERAL ZERO -- `5-2/R5`'s refusal of a tunable "rooted", applied a fourth
		# time -- and the write HAPPENS rather than being skipped for its siblings' downstream reason:
		# `HeroActor.drive()` reads this field into `move_and_slide()` every physics frame, so a
		# skipped write would leave the last live velocity in place and slide the hero through its
		# own counter. GREEN moves nothing because its counter throws a DAGGER across the gap
		# (presentation, AC 11) instead of carrying the body.
		#
		# RED AND BLUE WRITE REAL TRAVEL, the `1-9` roll's own expression: an authored distance over a
		# span, both read INLINE at the moment of use (CONSTRAINT C). POST-SMOKE (R-S1/R-S2) that is
		# two colours rather than one, and they carry DIFFERENT PROFILES over the same derivation:
		#   * BLUE, forward-only for the whole span -- the slide, which stops when it arrives because
		#     `move_and_slide()` meets the attacker's collider.
		#   * RED, FORWARD then BACKWARD, net ZERO: out along the bearing for the jump's share of the
		#     span (`counter_travel_forward_fraction_red`) and back by the SAME authored distance over
		#     whatever is left of it. The smoke found RED stomping the air beside a standing attacker;
		#     this is what makes the jump arrive on its head and the backflip return it. Its collider
		#     is stepped out of the way for the span by PRESENTATION (`HeroActor`, R-S1) -- state never
		#     learns a position (`4-3/R2`) and knows nothing about who is solid.
		#
		# THE TICK COUNT THE SPEEDS DIVIDE BY IS `duration - 1`, NOT the busy span, and that is what
		# makes RED's net zero EXACT rather than nearly so. Movement resolves at step 5 and the press
		# at step 6, so the press tick itself never travels; the window's last tick empties at step 2
		# and this branch is not entered on it either. The moving ticks are therefore exactly the
		# elapsed counts 1..duration-1, and each leg's speed is its own distance over its own share of
		# THOSE. Under two moving ticks there is no room for a profile at all and travel is zero.
		#
		# THE SIGN: `_counter_travel_dirs` holds the charge-reach bearing, which runs TARGET ->
		# ATTACKER by the `1-8` convention (here: defender -> attacker, since the counter's defender IS
		# the attacker's target). Travel toward the attacker is therefore the fact UNNEGATED -- and the
		# same bearing feeds the FACING lock below, where hero -> target is the same direction again.
		#
		# ZERO TRAVEL IS THE FALLBACK AND COSTS NO BRANCH: an early press with no live chargeup locked
		# `Vector2.ZERO`, and zero times any speed is zero. What STOPS the travel is
		# `HeroActor.drive()` / `move_and_slide()` -- the attacker's collider, the `5-0d` arena edge --
		# and state never learns a position (`4-3/R2` intact).
		var travel := Vector3.ZERO
		var distance := 0.0 if balance == null \
				else balance.counter_travel_distance_for(player.defense_color)
		var moving_ticks := player.defense_window.duration_ticks() - 1
		if distance > 0.0 and moving_ticks >= 2:
			var elapsed := player.defense_window.duration_ticks() \
					- player.defense_window.remaining_ticks()
			var forward_ticks := moving_ticks
			if player.defense_color == Enums.CardColor.RED:
				forward_ticks = clampi(int(round(balance.counter_travel_forward_fraction_red
						* float(moving_ticks))), 1, moving_ticks - 1)
			var outbound := elapsed <= forward_ticks
			var leg_ticks := forward_ticks if outbound else moving_ticks - forward_ticks
			var to_attacker := _counter_travel_dirs[slot]
			var speed := distance / (float(leg_ticks) / TimingWindow.TICK_HZ)
			travel = Vector3(to_attacker.x, 0.0, to_attacker.y) * speed * (1.0 if outbound else -1.0)
		player.hero.velocity = travel
	else:
		var state := player.hero.action_state
		# Story 6-7 (AC 6/AC 16): GAIT SELECTION, landing before the speed read it replaces,
		# alongside (never inside) the ROLLING/CHARGING/STUNNED carve-outs above. `balance ==
		# null` keeps the pre-injection fallback the ordinary case always had (plain
		# `hero.move_speed`, no gait) -- ATTACKING/ROLLING/CHARGING/STUNNED are already
		# documented unreachable pre-injection, but IDLE is not, and this branch is IDLE's home.
		var speed: float
		if balance == null:
			speed = player.hero.move_speed
		else:
			# `6-7/R13`: clauses (1)-(3) from `_run_pursuit_active`, plus (4) the latch and (5)
			# the honest-empty stamina read (`6-7/R16`, `is_zero_approx`) -- evaluated against
			# stamina BEFORE this tick's own drain below. Review finding 2 (fix-pass correction):
			# a PRE-drain-only read let a player dodge the latch by releasing run on the very
			# tick the drain empties the pool (that tick still reads non-empty here, and the
			# NEXT tick's `pursuing` is false if the key is released, so the latch never sets).
			# The drain below now ALSO sets the latch, same tick, the instant its own spend()
			# leaves the pool at `is_zero_approx` -- so the latch is live from the emptying tick
			# itself, one tick earlier than AC 9's original "tick-301" reading (corrected: the
			# residual now reads zero AND locked-out starting the SAME tick the drain reaches it).
			var pursuing := _run_pursuit_active(state, intent)
			var stamina_empty := is_zero_approx(player.stamina.get_current())
			if pursuing and stamina_empty:
				player.hero.run_locked_out = true
			actually_running = pursuing and not player.hero.run_locked_out and not stamina_empty
			if state == HeroState.ActionState.BLOCKING:
				# `6-7/R10` (AC 16): BLOCKING is forced to walk speed regardless of the run key --
				# it already suppresses regen (`_regen_stamina`'s own disjunct), and letting it
				# also run at full speed would put two different stamina policies on one state.
				speed = balance.walk_speed
			elif actually_running:
				speed = player.hero.move_speed
			else:
				speed = balance.walk_speed
			# Story 6-5a (R5): FROSTBITE'S SLOW scales the gait just chosen -- walk, run AND block-walk
			# (the ruling's named spec widening), and nothing else: roll, CHARGING, counter travel and
			# the stun/get-up roots are separate branches above, and the attack LUNGE below is added
			# after this and is never scaled. Unslowed, `speed` is untouched.
			#
			# 6-5a REVIEW N4 (operator ruling): THE `ATTACKING` GATE. R5 enumerates THREE gaits and the
			# attack is not one of them -- but an ATTACKING hero falls through the BLOCKING /
			# `actually_running` ladder to `walk_speed` and would be scaled here, a FOURTH gait the
			# ruling never named. It is latent at shipped tuning only because all three
			# `attack_*_move_speed_multiplier` values are authored `0.0`, so the product is zero either
			# way; the moment a retune makes any phase multiplier non-zero, a TUNING-ONLY edit would
			# change what the slow means. Gated here instead, so the three named gaits are the three
			# scaled gaits at any tuning. Pinned by
			# `test_spell_framework.gd::test_the_frostbite_slow_never_scales_the_attacking_gait`, which
			# authors non-zero phase multipliers IN TEST (never in data/, `BC/R3`).
			if player.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW) \
					and state != HeroState.ActionState.ATTACKING:
				speed *= player.rule_a[PlayerState.RULE_FROSTBITE_SLOW]
		# Story 3-0b (AC6): the attack LUNGE, ADDED to the input-driven velocity rather than
		# replacing it — the phase multiplier keeps scaling what the player steers, and the
		# lunge is the separate committed push the swing itself carries. At the authored
		# multipliers (0.0 = full root) the lunge is therefore the whole of the attack's
		# velocity, which is the intended shape: input steers nothing mid-swing, the swing
		# still carries the hero forward.
		var lunge := Vector3.ZERO
		if state == HeroState.ActionState.ATTACKING:
			speed *= _attack_phase_multiplier(player.hero.attack_phase())
			lunge = _attack_lunge_velocity(player.hero)
		player.hero.velocity = world_dir * speed + lunge
		# 6-5a REVIEW N5 (operator ruling): THE FROSTBITE SLOW DOES NOT SCALE THIS DRAIN, and that is
		# the RULED behaviour rather than an oversight -- a slowed hero pays the FULL stamina price for
		# HALF the distance. The slow's tax is the distance, not the pool; R5 names no stamina term, and
		# scaling the drain here would hand the slowed player a second, unstated effect (a longer sprint
		# for the same bar) in the middle of being punished. `actually_running` above is likewise
		# computed BEFORE the slow, so being slowed neither starts nor stops a run. The drain was already
		# unscaled in the dev pass; what this pass adds is the ruling and its pin,
		# `test_spell_framework.gd::test_the_frostbite_slow_halves_run_speed_and_not_run_stamina_drain`.
		#
		# Story 6-7 (AC 7): THE DRAIN SEAT, ratified -- `spend()` with the requested amount
		# clamped to `get_current()`, which is what lets the pool reach an honest zero (`6-7/R16`)
		# instead of refusing just above it, and restarts the regen-delay window on every
		# actually-running tick (AC 17's 0.8s release delay, the same mechanism a roll/attack/
		# deflect spend already gives).
		if actually_running:
			player.stamina.spend(
					minf(balance_ticks.run_stamina_drain_per_tick, player.stamina.get_current()),
					balance_ticks.stamina_regen_delay_ticks)
			# Review finding 2: close the latch bypass at its source -- if THIS tick's own
			# drain is what leaves the pool empty, the latch must already be set before a
			# later tick can read `pursuing` as false (run released) and skip it entirely
			# (the release-on-the-emptying-tick exploit the comment above names).
			if is_zero_approx(player.stamina.get_current()):
				player.hero.run_locked_out = true
	# Story 4-6 (AC 2, `CC/R1`(i)): FACING IS TARGET-DERIVED, NOT INPUT-DERIVED. Still
	# WORLD-SPACE planar (story 1-7 review R1, unchanged) and still reaching the actor through
	# this one field, so the 1-7b single-yaw-source contract at hero.gd:31-42 is untouched
	# (AC 6) -- what changed is WHAT feeds it, not the route or the space.
	#
	# THE ZERO-GUARD ON MOVEMENT IS GONE, which is the whole point: a locked hero faces its
	# target while strafing, backing off, or standing perfectly still. The guard that replaces
	# it is on the FACT, not the input -- an absent lock direction (nothing pushed, a co-located
	# target, an actor the runner has not spawned) leaves facing at its last value, which is the
	# same "no new information, keep the last heading" rule the old guard expressed about input.
	#
	# THE TWO CARVE-OUTS ARE ELSEWHERE AND UNCHANGED: the DEAD early return at the top of this
	# function (2-3/R14) never reaches this line, and the round-over freeze (step 1b, 2-6/R6)
	# returns before movement resolves at all. On both, facing is left at its last value under
	# the standing "a display-only field may be SKIPPED" rule. THAT CLASSIFICATION IS NOW IN
	# TENSION with facing feeding `_is_facing` -- a pre-existing tension this story INHERITS and
	# deliberately does not resolve (AC 2 says so in as many words); both branches also freeze
	# everything else that could act on it, so nothing observable rides on it today.
	#
	# `world_dir` STILL FEEDS VELOCITY ABOVE and is untouched by this: camera-relative movement
	# and target-relative facing are two seams now, split exactly here.
	# Story 5-2 (AC 12, Ruling 3/Ruling 8): AUTO-AIM OVERRIDES THE LOCK WHILE CHARGING, and it must,
	# because the two answer different questions. `_lock_directions[slot]` points at whatever this
	# slot has LOCKED, which since 4-6 can legitimately be a MINION; mode (2) targets the enemy HERO
	# and nothing else, so a charging hero facing its locked minion would telegraph at one thing and
	# land on another. The charge-reach fact is pushed hero-to-hero by construction, so reusing its
	# direction makes "aims at the enemy hero specifically" structural rather than filtered.
	#
	# THE SIGN: every contact fact's `dir` runs TARGET -> ATTACKER (the 1-8 convention), and facing
	# runs hero -> target, so this is its negation. The fact is already a unit vector.
	#
	# AN ABSENT FACT LEAVES FACING ALONE, exactly as an absent lock direction does one line below --
	# the same "no new information, keep the last heading" rule, which is what the entry tick needs:
	# the runner gathers BEFORE advance(), so the tick a cast enters CHARGING carries no fact yet and
	# the hero holds the heading it had when it committed.
	#
	# STORY 6-1c (AC 2/AC 7): THE COMMIT FREEZE IS THE THIRD RUNG OF THE FACING CARVE-OUT LADDER, and
	# it joins it BY CONSTRUCTION rather than as a flag: the aim is re-read only while the CHARGEUP
	# window runs. From the tick that window closes -- the commit -- through the landing, this branch
	# writes nothing, so facing holds the heading of the last chargeup tick, and that held value IS
	# the committed direction every later reader uses (the launch velocity, the landing arc). It is
	# derived, never stored: no field records it, because `facing` already carries it. The other two
	# rungs are untouched -- the DEAD return at the top of this function (2-3/R14) and the round-over
	# freeze (step 1b, 2-6/R6) -- and, like them, the freeze skips the write rather than writing.
	#
	# STORY 6-8 (AC 3): FACING IS TARGET-DERIVED ONLY WHILE LOCKED. An unlocked hero's facing reverts
	# to the pre-`4-6` rule verbatim -- the camera-rotated movement direction `world_dir`, behind the
	# old zero-guard on the INPUT, so a neutral stick leaves facing unchanged and rotating the camera
	# alone (a basis change with no movement) turns nothing. The CHARGING override stays FIRST for
	# both states: mode (2) aims at the enemy hero whether or not the player holds a lock. The DEAD
	# and round-over carve-outs return above this line exactly as before (AC 22).
	#
	# STORY 6-6b POST-SMOKE (R-S3): THE COUNTER'S FACING LOCK IS THE FOURTH RUNG, and it is FIRST
	# because it is the most specific: a countering hero is answering ONE attacker and must be turned
	# to it for the WHOLE busy span. The smoke found the opposite -- the defender counter-moved in
	# whatever direction it was already facing, so GREEN's throw animation played one way while the
	# dagger flew another, and RED's jump left the attacker over its shoulder.
	#
	# THE BEARING IS THE ONE THE TRAVEL USES, read from the same press-time lock (`_counter_travel_dirs`)
	# so the body can never point one way while the counter carries it another. It runs defender ->
	# attacker (the `1-8` convention, see the travel branch), and facing runs hero -> target, which
	# here is the same direction -- so it is used UNNEGATED, unlike the CHARGING aim below.
	#
	# THE ZERO-GUARD IS THE RULED FALLBACK, not a convenience: with nothing charging at the press the
	# lock copied `Vector2.ZERO`, and facing is then left ALONE -- the "no new information, keep the
	# last heading" rule this whole ladder is built on. A counter that answers nothing turns nowhere.
	#
	# NO CARVE-OUT IS WEAKENED BY SITTING FIRST: a countering hero cannot be CHARGING (the busy gate
	# refuses initiating one, and `_resolve_defense_cast` refuses casting while CHARGING), so the rung
	# below it is unreachable at the same time rather than merely outranked. This writes on every busy
	# tick, which is what "for the whole busy span" means, and normal steering resumes on the first
	# tick after the window empties.
	var lock_dir := _lock_directions[slot]
	if player.defense_window.is_running and not _counter_travel_dirs[slot].is_zero_approx():
		player.hero.facing = _counter_travel_dirs[slot]
	elif player.hero.action_state == HeroState.ActionState.CHARGING:
		var aim := _charge_reach_dirs[slot]
		if player.charge_window.is_running and not aim.is_zero_approx():
			player.hero.facing = -aim
	elif not player.is_locked():
		if not dir.is_zero_approx():
			player.hero.facing = Vector2(world_dir.x, world_dir.z)
	elif not lock_dir.is_zero_approx():
		player.hero.facing = lock_dir
	# Story 6-7 (Dev Notes, Open Question 5): the ONE "actually running" fact for this tick,
	# handed back to advance() so `_regen_stamina`'s suppression disjunct (AC 8) reads the exact
	# same value this function used for its own speed/drain decisions above -- computed once,
	# never re-derived, so the two seats can never disagree.
	return actually_running


## Story 3-0b (AC5): per-phase attack movement multiplier. Selects one of the three
## BalanceConfig fields from HeroState.attack_phase(), read inline at the moment of use
## (CONSTRAINT C).
##
## BOUNDARY VALUES: attack_phase() also returns windup_done/active_done/attack_done on a
## phase-boundary tick (step 2 stopped a window, step 3 has not yet started the next). Step
## 3(a) normally starts the successor BEFORE _resolve_movement runs, so an ATTACKING hero
## is on a running window here — but a degenerate 0-tick authored phase can leave a *_done
## value visible, so the mapping is TOTAL rather than relying on that. It groups the
## boundary values exactly the way HeroState.transition_row() already does (windup +
## windup_done together, active + active_done together), so the two phase consumers agree
## on where a boundary tick belongs instead of inventing a second grouping; attack_done
## falls to recovery as the last phase that ran.
func _attack_phase_multiplier(phase: StringName) -> float:
	match phase:
		&"windup", &"windup_done":
			return balance.attack_windup_move_speed_multiplier
		&"active", &"active_done":
			return balance.attack_active_move_speed_multiplier
		_:
			return balance.attack_recovery_move_speed_multiplier


## Story 4-3c1 (AC 2, `4-3c/R19`, seat ruled by `4-3c1/R1`): the MINION's per-phase attack
## movement multiplier — the unit-side parallel of `_attack_phase_multiplier()` above, selecting
## one of the three `minion_attack_<phase>_move_speed_multiplier` fields from a unit's own
## `UnitBoard.AttackPhase`.
##
## PURE, PUBLIC, AND IT ONLY EXPOSES THE RULE — it never applies it, and that asymmetry with the
## hero is the point of `4-3c1/R1`. The hero's `velocity` IS hashed state (`hero_state.gd:5-9`),
## so `_resolve_movement` both computes the hero's multiplier and writes the scaled velocity. A
## unit's velocity is ACTOR-owned (`unit_actor.gd:143-151`; there is no `Vector3` on `UnitBoard`),
## so this layer can only ever hand the rule out: the runner reads it inline at the
## `UnitActor.approach()` call site (CONSTRAINT C — no caching to a field, here or there) and
## passes a scaled speed in. Same shape as the contact fact — a derived fact crosses the
## state/actor seam, ownership of the write does not.
##
## IDLE RETURNS 1.0 EXPLICITLY, AND THERE IS NO CATCH-ALL FALL-THROUGH TO A PHASE FIELD
## (`4-3c1/R2`). This is where the hero's shape must NOT be mirrored literally. `attack_phase()`
## returns one of a three-value StringName set, so the hero's `_:` arm safely means "recovery";
## `AttackPhase` is a FOUR-value enum whose fourth value, IDLE, is the phase a unit spends nearly
## all of its life in. A literal mirror would map IDLE onto `minion_attack_recovery_move_speed_
## multiplier` (authored 0.0) and permanently root EVERY unit, including ones that have never
## swung — a shipped-immobile minion layer with nothing failing. The default arm therefore returns
## the identity, and only the three ATTACKING phases select a field.
##
## TAKES `int`, NOT `UnitBoard.AttackPhase`, on the project's own existing convention for carrying
## this enum across a call boundary: `UnitBoard.attack_phase_at()` is declared `-> int`
## (`unit_board.gd:359`) and `UnitAnimationController.on_unit_tick()` takes `phase: int`
## (`unit_animation_controller.gd:108`). The arms below compare against the named enum values, so
## the domain is still stated where it matters.
##
## STORY 4-4 (AC 6, the B5 inventory): IT TAKES THE UNIT'S KIND INDEX. The three globals it used to
## read are gone from `BalanceConfig`; the three multipliers are now per kind, so the seat has to be
## told WHICH kind is asking. The runner passes `player.units.kind_index_at(index)` at the one call
## site, beside the phase it already passes — no new coupling, the same "state exposes the rule, the
## actor owns the velocity" split `4-3c1/R1` established.
##
## AN UNRESOLVABLE KIND YIELDS FULL SPEED (1.0), not zero, and the direction is deliberate: a null
## kind means the authored list changed under a live record (an X3 reload that shortened
## `unit_kinds`), and rooting every affected unit in place would read as a freeze, while running
## them at full speed reads as "the multipliers stopped applying" — the smaller and more legible
## degradation. It joins the IDLE branch below rather than getting its own, because both answers are
## the same number for the same reason: no authored multiplier governs this tick.
func unit_attack_phase_multiplier(phase: int, kind_index: int) -> float:
	var kind := balance.kind_at(kind_index)
	if kind == null:
		return 1.0
	match phase:
		UnitBoard.AttackPhase.WINDUP:
			return kind.attack_windup_move_speed_multiplier
		UnitBoard.AttackPhase.ACTIVE:
			return kind.attack_active_move_speed_multiplier
		UnitBoard.AttackPhase.RECOVERY:
			return kind.attack_recovery_move_speed_multiplier
		_:
			# IDLE and any phase added later: full, unmodified speed. NOT a field lookup.
			return 1.0


## Story 3-0b (AC6): the attack lunge as a STATE-SIDE velocity term — the sanctioned form
## from the 1-7 close-out ("an authored lunge displacement in balance data, applied by the
## STATE layer as a velocity curve during the swing"). NEVER root motion: no AnimationPlayer
## sample reaches this function, so replay never depends on animation and DECISION A / the
## in-place rule stand untouched.
##
## Speed derivation follows the ROLL precedent verbatim (roll_distance /
## roll_duration_seconds, the neighbouring branch): the authored DISPLACEMENT divided by the
## span it is spent over. A *_seconds float is read here for the same reason the roll reads
## one — this is a SPEED derivation, not window timing; all timing stays on balance_ticks
## (CONSTRAINT C: both operands are read inline at the moment of use, so a mid-swing reload
## changes the speed next tick while in-flight windows keep their duration).
##
## PHASE SCOPE (ruled, story AC6): live during WINDUP and ACTIVE only. The lunge is the
## commitment forward INTO the swing; drifting through recovery is a different feel decision
## and is not this term's. Boundary values are grouped exactly as _attack_phase_multiplier()
## groups them, so the two consumers never disagree about which phase a boundary tick is in.
##
## Direction is HeroState.facing — world-space planar since 1-7/R1, so no basis knowledge is
## needed here and none of the camera mapping above applies to it. Facing is read LIVE
## rather than entry-locked (the roll's stored roll_direction shape), which keeps the lunge
## out of the snapshot entirely: no new state field, no snapshot-shape change. A hero that
## turns mid-swing therefore lunges along its new facing — the "velocity-only commitment,
## facing tracks input" rule this function already follows for the multiplier.
##
## Guards: a zero-or-negative span would divide to INF and poison the snapshot, and a
## zero facing has no direction to lunge along. Both yield no lunge. The authoring audit
## already keeps the shipped windup/active durations > 0; this guard covers in-test and
## pre-authoring configs, which the roll branch can skip only because ROLLING is
## unreachable before its own authored duration exists.
func _attack_lunge_velocity(hero: HeroState) -> Vector3:
	var phase := hero.attack_phase()
	var committed := phase == &"windup" or phase == &"windup_done" \
			or phase == &"active" or phase == &"active_done"
	if not committed:
		return Vector3.ZERO
	var span := balance.attack_windup_seconds + balance.attack_active_seconds
	if span <= 0.0 or hero.facing.is_zero_approx():
		return Vector3.ZERO
	var dir := hero.facing.normalized()
	return Vector3(dir.x, 0.0, dir.y) * (balance.attack_lunge_distance / span)


## Story 6-1c (AC 4): THE LAUNCH as a STATE-SIDE velocity term -- `_attack_lunge_velocity`'s shape
## directly above, for mode (2): the colour's authored DISPLACEMENT over its authored SPAN, along the
## hero's facing. Never root motion and never adaptive: nothing here reads where the defender is, so
## the attacker travels the same fixed distance whether the target stood still, closed in or ran.
##
## FACING IS THE COMMITTED DIRECTION HERE, not a live one, and that is a property of the caller: this
## runs only once the chargeup window has closed, and from that tick `_resolve_movement` stops writing
## `facing` (the commit freeze). Reading it LIVE is therefore reading the frozen value.
##
## STORY 6-1d (AC 7) REWRITES THE SPEED, IN TWO NAMED PARTS. The DIRECTION, the fixed-not-adaptive
## rule, the frozen-facing property and the total distance travelled are all untouched.
##
## (a) P6 ADOPTED (`6-1c/R12`, Fact 6). The span is taken from the TICK domain
##     (`unblockable_launch_ticks_for` / `TimingWindow.TICK_HZ`) instead of from the authored
##     `*_seconds` float. The two agreed only because today's authored spans happen to be
##     tick-aligned; a retune to, say, 0.26 s rounds UP to 16 ticks but is divided by 0.26 s, so the
##     hero covers the authored distance before the window closes and keeps going -- overshoot by
##     construction (0.27 s rounds DOWN to 16 and undershoots instead: the same class, the other
##     sign). Reading the span the LANDING actually uses removes the class.
##
## (b) THE TRAVEL IS FRONT-LOADED (`6-1c/R10(b)`, GREEN the named subject). A flat speed spends the
##     same distance on the last tick as on the first, which is what makes the long GREEN leap read
##     as a lurch arriving on the landing tick. The per-tick displacement now runs down a straight
##     ramp across the launch, `2 - (2i+1)/L` of the flat share on launch tick `i` -- `2 - 1/L` (just
##     under twice the flat share) at the start, `1/L` at the end, and the weights SUM TO EXACTLY
##     `L`, so the total distance covered is the authored one to the float. Nothing is authored for the ramp:
##     shape is not a feel knob here, the DISTANCE and the SPAN are, and both stay where they were.
##
## NO NEW HASHED FIELD AND NO NEW TICK CONTRACT (AC 7's halt condition, checked rather than
## assumed): the launch tick index is DERIVED from `landing_window`'s own duration minus its
## remaining ticks, the same window the landing and the progress push already read, so nothing is
## stored, nothing is snapshotted, and `landing_window`'s duration and close tick are exactly as
## `6-1c` left them.
##
## THE SPAN AND THE INDEX COME FROM THE WINDOWS, NEVER FROM A LIVE BALANCE READ (`6-1d/R10`). Both
## windows snapshot their durations at the cast and keep them across a balance hot-reload
## (`TimingWindow.start`), so `L = landing.duration - charge.duration` and
## `i = (landing.duration - landing.remaining) - charge.duration` describe the flight that is actually
## running. The dev pass read `L` live off `balance_ticks`; a mid-flight reload that shortened the span
## then drove the raw index negative and the clamp pinned it at the ramp's PEAK share for many ticks,
## multiplying the travel. The authored DISTANCE is still read live, so a retuned distance takes effect
## at once but can only scale the total, never pin the index.
##
## Guards, the lunge's own: a zero-or-negative span has no speed (an unauthored launch -- the landing
## then resolves on the chargeup-close tick anyway, so this branch is never reached for it) and a
## zero facing has no direction. The index is clamped into `[0, L-1]` so a caller outside the launch
## can only ever read a real launch tick's share, never a negative or runaway one.
func _charge_launch_velocity(player: PlayerState) -> Vector3:
	if balance_ticks == null:
		return Vector3.ZERO
	var chargeup_ticks := player.charge_window.duration_ticks()
	var launch_ticks := player.landing_window.duration_ticks() - chargeup_ticks
	if launch_ticks <= 0 or player.hero.facing.is_zero_approx():
		return Vector3.ZERO
	var index := clampi(player.landing_window.duration_ticks()
			- player.landing_window.remaining_ticks() - chargeup_ticks, 0, launch_ticks - 1)
	var share := 2.0 - float(2 * index + 1) / float(launch_ticks)
	var flat_speed := balance.unblockable_launch_distance_for(player.charge_color) \
			* TimingWindow.TICK_HZ / float(launch_ticks)
	var dir := player.hero.facing.normalized()
	return Vector3(dir.x, 0.0, dir.y) * (flat_speed * share)


## Yaw-only camera-space -> world mapping (AC 3): the basis' right/back columns are
## flattened onto XZ and renormalized, so camera pitch mathematically cannot tilt or
## shrink movement. Degenerate columns (camera looking straight up/down) fall back to the
## world-space mapping rather than producing NaNs.
static func _camera_relative_dir(dir: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var back := Vector3(camera_basis.z.x, 0.0, camera_basis.z.z)
	if right.is_zero_approx() or back.is_zero_approx():
		return Vector3(dir.x, 0.0, dir.y)
	return right.normalized() * dir.x + back.normalized() * dir.y


## Story 3-1 (AC 4, 3-1/R2): the PER-POOL reload contract. The three pools are deliberately
## NOT symmetric, and the asymmetry is the contract, not an oversight:
##   hp      — set_max_hp re-clamps the CURRENT value into the new bound and never raises it
##             (hero_state.gd), so a reload preserves the hp a player has fought down to.
##             That leaves match start with nothing to fill it, hence `first_injection`
##             below: without it a stat-less hero would sit at 0 hp and start the match dead
##             (3-1/R4, the finding that forced this seat to exist at all).
##   stamina — set_maximum + refill on EVERY injection (D9, story 1-4, UNCHANGED): stamina
##             is the moment-to-moment resource and a reload hands it back full.
##   mana    — set_maximum ONLY, on every injection including the first. NEVER refilled:
##             ManaPool's own contract is that mana starts empty and is built by the
##             flywheel (mana_pool.gd:4-5), so a reload-refill would hand a free full bar
##             mid-match and break the buildup P2 depends on. set_maximum re-clamps the
##             current value into the new bound (ManaPool.set_maximum -> add(0.0)), which is
##             all a rescale may do to a player's earned mana.
## Match start therefore yields FULL hp, FULL stamina, EMPTY mana.
func _apply_balance_to_player(player: PlayerState, config: BalanceConfig,
		first_injection: bool) -> void:
	player.hero.set_max_hp(config.max_hp)
	if first_injection:
		# The one match-start-only write. heal() clamps at the maximum set just above, so
		# this is "fill to the authored max" and nothing else — the _reset_player idiom.
		player.hero.heal(config.max_hp)
	player.hero.move_speed = config.move_speed
	player.stamina.set_maximum(config.max_stamina)
	# D9 (story 1-4): start FULL at the authored maximum — every apply_balance, reload
	# included (test_mid_match_reload_refills_stamina_to_max). Story 3-1 reconciled the
	# constructor/apply_balance double injection this comment used to defer: there is no
	# constructor seeding left to double-write.
	player.stamina.refill()
	player.mana.set_maximum(config.max_mana)
	# Story 5-4 (AC 10): orbs join the per-pool reload contract on MANA's side of the asymmetry,
	# not stamina's -- set_maximum ONLY, on EVERY injection including the first, NEVER a refill.
	# Orbs are EARNED (the mode (2) payout), so handing back a full pool on a reload would be the
	# same defect the mana line above exists to avoid, one resource over. Match start still yields
	# EMPTY orbs, and for the reason the header's mana entry gives: a fresh PlayerState constructs
	# its OrbPool at all-zero, so there is nothing for this line to preserve at the first injection
	# and nothing for it to invent.
	player.orbs.set_maximum(config.max_orbs_per_color)


## Story 3-1 (AC 5, 3-1/R3): joins the `balance_ticks == null` gated family (step 3's
## _resolve_actions, step 5's regen/mana, step 4's `balance == null` twin). A pre-injection
## MatchState is stat-less as well as inert, so its heroes sit at 0 hp — unguarded, the
## FIRST tick of a never-injected match would resolve a round end against a hero that was
## never given any hp to lose. Read inline like every other guard (CONSTRAINT C).
func _check_resolution() -> void:
	if balance_ticks == null:
		return
	if _round_over:
		return
	if not p1.hero.is_alive():
		_end_round(p1, 0)
	elif not p2.hero.is_alive():
		_end_round(p2, 1)


## Story 1-7 (D-3): the ONLY entry into ActionState.DEAD — a step-8 resolution outcome,
## never a table edge (the table's dead row accepts nothing; exit is only the D-1 debug
## reset). Presentation learns of death through the same queued action_state_changed
## channel as every transition (the locked observation seam).
func _end_round(loser: PlayerState, loser_index: int) -> void:
	_round_over = true
	# Story 6-5a (N10): round end clears every running timed rule and armed trigger on BOTH sides -- the
	# one clear this function has ever carried, named as an operator ruling rather than a precedent.
	#
	# Story 6-5a (REVIEW B1, operator ruling): the LAST-RESOLVED-CARD record clears here too, beside the
	# rules and for the rules' reason -- it is round-crossing hashed state, and a round that has ended
	# holds no card that "was just resolved" for 6-5f's Counterspell to answer.
	p1.clear_rules()
	p2.clear_rules()
	p1.clear_resolved_card()
	p2.clear_resolved_card()
	loser.hero.set_action_state(HeroState.ActionState.DEAD)
	_queue.push(round_ended.emit.bind(loser_index))


## Story 1-7 (D-1, operator decision): ROUND-SCOPED debug reset — every slot's HP back to
## max and the round latch cleared; NOTHING else (pools, dedupe records, in-flight
## windows, and actor-owned positions untouched — a live hero mid-swing swings on). A
## DEAD hero returns to IDLE (a "clear action state" entry), which NEVER touches
## attack_index (monotonic dedupe contract, pinned at the 1-6 gate). Deliberately NOT
## flag-gated: operator affordance, not a gameplay path (exception recorded in the
## decision log). Fixed P1 -> P2 order for determinism.
##
## STORY 4-1 (AC 8, `4-1/R5`): "NOTHING else" NOW CARRIES ONE NAMED EXCEPTION -- the per-player
## UNIT BOARD, cleared in _reset_player below. It is NAMED here rather than silently violated,
## and it is the RESET path ALONE: _end_round is deliberately UNTOUCHED, so the board persists
## through the round-over freeze instead of blinking out at the instant of death, which is how
## every other piece of round-crossing state already behaves. "No stale units into a fresh
## round" is delivered by this path and nothing else. The runner frees the matching grey-box
## actors off the round_started relay this function already queues below -- no new EventBus
## event ships (AC 8).
##
## STORY 5-3 (fix pass): A SECOND NAMED EXCEPTION -- the mode (2) CHARGEUP (action state, window and
## colour), cleared in _reset_player below. Named here for the same reason the unit board is, and
## for a stronger one: it is a CORRECTION, not an addition. A chargeup could otherwise cross a round
## boundary and land inside the next round (the trace is in _reset_player). "A live hero mid-swing
## swings on" is unchanged for every OTHER in-flight window; the chargeup is the one whose survival
## is a defect rather than a feature, because step 1b freezes its clock while leaving it armed.
##
## STORY 5-4 (AC 13): A THIRD NAMED EXCEPTION -- the per-player ORB POOL, cleared in _reset_player
## below. Named here for the unit board's own reason (per-player state that must not cross a round
## boundary, and this path is the only round boundary this codebase has), and _end_round is again
## deliberately UNTOUCHED: a clear there would delete the winner's freshly-earned orbs at the instant
## of death, before the round-over freeze displays them.
##
## The parked mana-survives-reset finding stays PARKED -- and orbs deliberately do NOT follow mana
## here, a NAMED divergence: orbs are a per-round stake in the RPS exchange, mana is a persistent
## flywheel.
##
## STORY 5-5 (AC 12): A FOURTH NAMED EXCEPTION -- the mode (3) DEFENSE WINDOW and its colour, cleared
## in _reset_player below for the chargeup's traced reason verbatim (step 1b freezes the clock while
## leaving the window armed, so it would answer a landing in the NEXT round).
##
## STORY 5-6 (AC 13): A FIFTH NAMED EXCEPTION -- the hero's `stun` WINDOW and the `STUNNED` action
## state, cleared together in _reset_player below for the identical traced reason. `_end_round` again
## gains no matching clear.
##
## STORY 6-2 (AC 14d): A SIXTH NAMED EXCEPTION -- both players' PITCH ZONES, emptied in _reset_player
## below. A staged card must not survive into the redeal (its id would exist twice) and its countdown,
## frozen by step 1b, must not fizzle in the next round. `_end_round` again gains no matching clear.
##
## STORY 6-6a (AC 9): A SEVENTH NAMED EXCEPTION -- the hero's GET-UP IFRAME window, stopped in
## _reset_player below. Traced the `5-6` way: step 1b returns BEFORE step 2's `tick_timers()`, so a
## get-up window armed just before the other hero died stops counting but stays armed, and would carry
## invulnerability into the NEXT round. The reset's own `STUNNED -> IDLE` exit from a knockdown ARMS
## NOTHING (only the step-3 timer exit does), so this clear covers the one window a reset could inherit.
## `_end_round` again gains no matching clear.
##
## STORY 6-5a (N10): AN EIGHTH NAMED EXCEPTION -- the TIMED-RULE SEAT (every buff and armed trigger),
## cleared in _reset_player below. Unlike the seven above, `_end_round` DOES gain the matching clear, by
## operator ruling: a running Bloodlust must not survive into the round-over freeze either.
##
## STORY 6-5a (REVIEW B1, operator ruling): A NINTH NAMED EXCEPTION -- the LAST-RESOLVED-CARD RECORD,
## cleared in _reset_player below and, like the eighth, in `_end_round` as well. The dev pass left it
## cleared by NEITHER path, which made it the only round-crossing hashed field added since 4-1 without a
## named exception: a reset re-armed the deal while the per-player snapshot still hashed the card
## resolved BEFORE the reset, so a reset match and a fresh match were not at the same resting snapshot
## at the same point. It follows `timed_rules` exactly, and both directions are pinned by
## `test_spell_framework.gd::test_round_end_and_the_debug_reset_clear_every_rule`.
##
## These are NINE named exceptions; they do not open the reset's contract generally.
func _apply_debug_reset() -> void:
	_round_over = false
	_reset_player(p1)
	_reset_player(p2)
	# Story 4-6 (`CC/R2`): the lock returns to the opposing hero with the board it addressed.
	# Seated HERE rather than in `_reset_player` for the reason `_init` seats it here: the
	# OPPOSING SLOT is knowledge this function has and the per-player helper does not. It pairs
	# with `player.units.clear()` inside that helper exactly as the dedupe and projectile clears
	# do -- a lock addressing a board index the clear just deleted would name a unit that no
	# longer exists, the same class of dangling address those two clears exist to prevent.
	_reset_lock(p1, 1)
	_reset_lock(p2, 0)
	# Story 3-3 (AC 9): RE-ARM the step-6 deal seat — the reshuffle and refill happen THERE,
	# inside this same advance(), never here. A reset that lands before any injection has no
	# composition to lay down, so the latch is left alone rather than armed against nothing.
	# The parked finding that MANA survives a reset stays PARKED with the first round-flow
	# story: this story only participates in this function beside the hp heal and introduces
	# no round lifecycle of its own.
	if not _deck_contents.is_empty():
		_deck_deal_pending = true
	# Story 2-6 (AC 1, 2-6/R5): announce the reset UNCONDITIONALLY on every debug reset — the
	# round lifecycle previously emitted only on END (round_ended), never on reset, which is the
	# 2-4 close-out MICRO-DECISION 1 gap (the round-over label survived a reset because nothing
	# signalled it). Queued (D5) like every state signal; the runner relays it post-drain.
	_queue.push(round_started.emit)


func _reset_player(player: PlayerState) -> void:
	var hero := player.hero
	# STORY 5-3 (fix pass, operator ruling): CHARGING JOINS DEAD IN THE "CLEAR ACTION STATE" ENTRY,
	# AND ITS WINDOW IS STOPPED IN THE SAME BREATH -- the SECOND named exception to the reset's
	# "NOTHING else / in-flight windows untouched" contract (the unit board is the first, `4-1/R5`).
	#
	# THE DEFECT IT CLOSES, traced rather than assumed. Step 1b (`:350-353`) returns BEFORE the
	# step-2 `charge_window.tick()` (`:388-389`), so once `_round_over` latches a chargeup STOPS
	# COUNTING but stays armed; and this function forced IDLE only from DEAD, so a hero that was
	# CHARGING when the other one died came out of the reset still CHARGING with a live window. That
	# window then ticks down inside the NEXT round and `_resolve_charge_landing` applies the PREVIOUS
	# round's chargeup -- a hit nobody in the new round pressed for.
	#
	# THE THREE FIELDS ARE CLEARED TOGETHER because they are ONE FACT in three parts (the state, the
	# window, the colour), exactly as the board / dedupe / projectile clears below are one collection
	# expressed as three: a stopped window under a CHARGING state, or a colour with no window, are
	# each half of a telegraph and neither is a thing this game has.
	#
	# THE ROUND-OVER FREEZE ITSELF IS DELIBERATELY NOT TOUCHED (operator ruling, story text): a
	# telegraph left lit on the round-over screen is the same class as every other pose the freeze
	# holds, it is cosmetic, and it ends HERE -- `set_action_state` queues the transition the
	# presentation controllers already clear their shape on.
	#
	# STORY 5-6 (AC 13): `STUNNED` JOINS THIS ENTRY AS THE FIFTH NAMED EXCEPTION to the reset's
	# "NOTHING else / in-flight windows untouched" contract (the unit board is first, `4-1/R5`; the
	# chargeup second, `5-3`; the orb pool third, `5-4`; the defense window fourth, `5-5` AC 12), and
	# its window is stopped in the same breath below for the identical traced reason.
	#
	# THE DEFECT IT CLOSES, traced on exactly the `5-3`/`5-5` shape: step 1b returns BEFORE step 2's
	# `tick_timers()`, so once `_round_over` latches a running `stun` window STOPS COUNTING but stays
	# ARMED. Without this exception a hero stunned just before the other one died would come out of
	# the reset still `STUNNED` with a live window, carrying the stun into the NEXT round exactly as
	# an uncleared chargeup or defense window would — and, because AC 12's timer arm is the only
	# normal-play exit, it would then serve out the previous round's punish in the new one.
	#
	# THE ROUND-OVER FREEZE ITSELF IS UNTOUCHED, the same "latched round-over freezes but does not
	# disarm the window" property `5-3`/`5-5` already established: this is a RESET-time clear, not an
	# `_end_round`-time one.
	if hero.action_state == HeroState.ActionState.DEAD \
			or hero.action_state == HeroState.ActionState.CHARGING \
			or hero.action_state == HeroState.ActionState.STUNNED:
		hero.set_action_state(HeroState.ActionState.IDLE)
	hero.heal(hero.get_max_hp())
	player.charge_window.start(0)
	# Story 6-1c: the landing window is part of the same one fact and is stopped with it -- a launch
	# frozen by the round-over freeze must not land inside the next round, the exact defect the
	# chargeup clear above closes for the chargeup half.
	player.landing_window.start(0)
	player.charge_color = PlayerState.NO_TELEGRAPH_COLOR
	# Story 6-1d review fix (`6-1d/R9`): the contact verdict and its bearing are part of the same fact
	# and are cleared with it, so a flight frozen by the round-over freeze credits nothing next round.
	var reset_slot := 0 if player == p1 else 1
	_charge_reach[reset_slot] = REACH_UNKNOWN
	_charge_contact_dirs[reset_slot] = Vector2.ZERO
	# Story 6-6b (AC 15): BLUE's locked counter-travel bearing is cleared beside the two stores above,
	# on their classification and NOT as an eighth named reset exception -- none of the three is one.
	# They are runner-pushed spatial facts, not the per-player hashed state the seven exceptions are
	# about; clearing this one is what keeps a bearing locked before the round ended from carrying a
	# direction into the next round's first press.
	_counter_travel_dirs[reset_slot] = Vector2.ZERO
	# Story 6-5b (AC 18): this slot's pushed DRAIN TARGET, cleared beside the three stores above and
	# on their classification -- a runner-pushed fact, not one of the named per-player hashed-state
	# exceptions. It clears because a board index pushed before the reset names a record
	# `units.clear()` below is about to delete, and a stale index surviving into the next round would
	# be a Drain aimed at a minion that no longer exists.
	_drain_targets[reset_slot] = NO_DRAIN_TARGET
	# STORY 6-2 (AC 14d): THE SIXTH NAMED EXCEPTION -- this player's PITCH ZONE, emptied with its
	# countdown stopped. Without it the step-6 deal this same reset re-arms would lay the FULL composition
	# back down while the staged card's id still sat in the zone -- one card in two places -- and a
	# countdown frozen by the round-over freeze would fizzle into the next round. NOTHING goes to the
	# discard and NO replacement is owed: the deal re-lays the whole composition, which is where the
	# staged card returns to (the `pending_draw_owed.clear()` reasoning in `_deal_player`). The spent
	# mana is not refunded, the parked mana-survives-reset finding unchanged.
	pitch.clear(reset_slot)
	_queue_pitch_changed(reset_slot)  # Story 6-3b (AC 1 site (d))
	# Story 5-6 (AC 13): the stun window, stopped in the same breath as the state clear above — one
	# fact in two parts, exactly as the chargeup's three and the defense window's two are.
	hero.stun.start(0)
	# Story 6-6a (AC 9): THE SEVENTH NAMED EXCEPTION -- the get-up iframes, stopped beside the stun whose
	# knockdown arms them (see _apply_debug_reset's header for the trace).
	hero.get_up_iframe.start(0)
	# STORY 5-5 (AC 12): THE FOURTH NAMED EXCEPTION to the reset's "NOTHING else / in-flight windows
	# untouched" contract -- the mode ③ DEFENSE WINDOW and its colour, cleared here immediately
	# beside the chargeup on the identical `start(0)` / `= NO_TELEGRAPH_COLOR` shape, and for the
	# identical traced reason. Step 1b returns BEFORE the step-2 `defense_window.tick()`, so once
	# `_round_over` latches a defense window STOPS COUNTING but stays armed; carried into the NEXT
	# round it would let a same-colour landing from an entirely new round be negated by a card played
	# in the round before.
	#
	# THE CHARGEUP CLEAR IS THREE FIELDS AND THIS ONE IS TWO, and the asymmetry is deliberate rather
	# than a narrower copy: the chargeup owns an `ActionState` (so `action_state` is part of its one
	# fact), and mode ③ owns none at all (AC 5). There is no third field here to forget.
	#
	# `_end_round` GAINS NO MATCHING CLEAR, the `5-4` orb finding applied to a second field:
	# `_end_round` has never cleared per-player economy or timer state, the debug reset is this
	# codebase's ONE round-boundary transition mechanism, and a clear inside `_end_round` would end a
	# still-open defense the instant the OTHER hero dies -- before the round-over freeze displays
	# anything -- which has no precedent anywhere in this file.
	player.defense_window.start(0)
	player.defense_color = PlayerState.NO_TELEGRAPH_COLOR
	# Story 4-1 (AC 8, `4-1/R5`): the ONE named exception to the reset's "NOTHING else" contract
	# -- see _apply_debug_reset's header. Seated in the PER-PLAYER helper because the board is
	# per-player, and reached only from the reset: no round-end path clears it.
	player.units.clear()
	# Story 4-3b (AC 16): the unit dedupe records are cleared WITH the board, in the same seat and
	# under the same named exception -- they key BOARD INDICES, so a record surviving a board clear
	# would key an index that no longer names the unit it was opened for. The two are one collection
	# expressed as two, exactly as UnitBoard's own eight arrays are one expressed as eight.
	player.unit_dedupe.clear()
	# Story 4-4 (AC 14): the PROJECTILE board is cleared in the same seat, under the same named
	# exception, and the pairing is load-bearing rather than tidy. A projectile record stores the
	# board index of the unit that fired it and the `[slot, index]` address of what it was fired at;
	# surviving a board clear, both would name records that no longer exist. Clearing the two
	# together is what keeps "units gone but their shots still flying" unrepresentable.
	player.projectiles.clear()
	# STORY 5-4 (AC 13): THE THIRD NAMED EXCEPTION to the reset's "NOTHING else" contract -- the
	# per-player ORB POOL, cleared here beside the board / dedupe / projectiles / chargeup for the
	# same reason they are: this is per-player state that must not survive a round boundary, and the
	# debug reset is this codebase's ONLY round-boundary transition (there is no automatic
	# round-restart path). Orbs are a PER-ROUND STAKE in the RPS exchange, which is why they follow
	# the board's precedent rather than mana's -- the parked "mana survives reset" finding stays
	# parked and UNTOUCHED, and this divergence between the two pools is NAMED, not accidental.
	#
	# `_end_round` gains NO matching clear, deliberately: clearing there would delete the WINNER's
	# freshly-earned orbs the instant the loser dies, before the round-over freeze even displays
	# them -- against the freeze-survives-until-reset behaviour every other piece of round-crossing
	# state already has (`4-1/R5`'s reasoning for the unit board, verbatim).
	#
	# `reset_all()` is REUSED, not reinvented: OrbPool authored it for E6's Pitch-Effect activation
	# (all three colours to zero, TDD 8.2). Different call site, same method, no modification -- and
	# its own no-op-on-already-empty guard means a reset with no orbs earned signals nothing.
	player.orbs.reset_all()
	# Story 6-5a (N10): the eighth named exception -- every timed rule and armed trigger, see
	# `_apply_debug_reset`.
	player.clear_rules()
	# Story 6-5a (REVIEW B1, operator ruling): the ninth named exception -- the last-resolved-card
	# record, cleared beside the rules and for the same reason, see `_apply_debug_reset`.
	player.clear_resolved_card()
