---
baseline_commit: f009dd553b25a7a6045750ba1393499d1a4ea7cc
---

# Story 4.3d: Minion strike alignment and corpse lifecycle

Status: review

## What this story inherits

This story is `4-3c-minion-rig-adoption`'s AC 5 and AC 6, CUT out of that story at its own readiness
gate (`4-3c/R2`, ratified by the operator, decision-log Session 2026-08-14) and re-authored here as
its own story. The gate's reasoning, carried forward rather than lost:

**AC 5 (strike alignment) is a feel-and-timing requirement of exactly the kind `3-0a` itself deferred
into its successor, `3-0b`.** `3-0a` shipped the hero's rig with clip TIMING left alone — reconciling
clip length against authored windows was explicitly `3-0b`'s job (`3-0a/R5`, "clip-end and mid-clip
policy (adoption level only)" — cited by ruling, not AC, matching how the decision log itself records
it; **corrected at this fix pass, `4-3d/R7`, this story's one citation of this policy**), and `4-3c`'s
own Dev Notes quote that same rule: adoption ships
selection, not alignment. Aligning the minion's visible strike to the authored ACTIVE window is
tempo/feel work on the same footing as `3-0b`'s clip retime, not something `4-3c`'s adoption pass has
standing to fold in.

**AC 6 (corpse lifecycle) is not presentation at all — it changes actor LIFETIME.** Measured at the
gate: it reaches FOUR separate runner loops (`_free_dead_unit_actors`, `_aim_unit_actors`,
`_approach_unit_actors`, and the debug-reset relay that frees actors on `round_started`), invalidates
TWO shipped comments that assert a dead unit's actor is freed the same tick or shortly after death
(one of them inside `src/state/`), changes what the intent recorder's contact tap can observe (a
lingering corpse's hurtbox would otherwise still be live), and interacts with both the debug pause and
the debug reset. `4-3c`'s own scope statement — "presentation only… reads state, writes nothing to
state, adds no snapshot field" — does not fit a change of this shape, even though the mechanism itself
touches no `UnitBoard`/`MatchState` field.

**This story depends on `4-3c`, specifically on its AC 4 liveness gate.** `4-3c/R4` added a liveness
check to `MatchRunner._aim_unit_actors` (`is_alive_at` before `attack_phase_at`) BECAUSE this story's
corpse linger makes a dead-but-not-yet-freed actor reach that seat on later ticks for the first time —
before `4-3c`, `_aim_unit_actors` never saw a corpse because `_free_dead_unit_actors` had already freed
it the same tick. **This story does not re-add that gate; it relies on `4-3c` already having shipped
it.** If `4-3c` has not landed, this story cannot run.

**This story's corpse behaviour also depends on `4-3c`'s push-ordering (the operator's ruling,
`4-3c/R15`).** `4-3c` pushes phase/velocity to the presentation controller BEFORE its liveness check,
never after — this story adds no liveness gate of its own to `_aim_unit_actors`, so if `4-3c` had
instead implemented the liveness check as an early skip ahead of the push, a lingering corpse here
would never be told it died and would freeze mid-swing (a half-raised claw) instead of playing
`death`. This story's own corpse-falls-and-holds behaviour is only correct because `4-3c` orders it
this way.

## Story

As a player,
I want a minion's swing to visibly land when the damage does, and its corpse to fall and remain a
readable, non-blocking obstacle for a few seconds rather than vanishing instantly,
so that the fight reads as real combat rather than boxes disappearing on a counter.

## Acceptance Criteria

1. **The visible strike is aligned to land at the START of the ACTIVE window, using a custom
   `AnimationPlayer` playback rate — the mechanism, decided, not an open question.** Ruled by the
   operator (`4-3d/R11`, superseding `4-3d/R6`): of the three routes the gate recorded, custom playback
   rate is THE mechanism (Rejected Alternatives below). The authored rhythm is
   `minion_attack_windup_seconds = 0.9`, `minion_attack_active_seconds = 0.2`,
   `minion_attack_recovery_seconds = 0.8` (`data/balance/balance_config.tres:37-39`, measured current
   values).

   **The clip's actual length is measured: 2.6667 s, 80 keys** (`4-3d/R18`, superseding `4-3d/R5` and
   `4-3d/R8`). Source: `4-3c`'s Dev Agent Record, Hips-track table,
   `docs/implementation-artifacts/4-3c-minion-rig-adoption.md:605-609` — "`attack` | 2.6667 s | 80 |
   ... | mid-clip forward step RETURNING to net-zero — MET". The dev pass re-confirms this figure from
   the imported clip before applying any rate; it does not re-measure from scratch.

   Against the authored 1.9 s full cycle (0.9 + 0.2 + 0.8), the mechanism COMPRESSES the 2.6667 s clip
   to fit. **This corrects, rather than carries, this AC's earlier "stretching the clip across the
   whole 1.9 s cycle is REJECTED" sentence** — that sentence was written while this AC still believed
   the clip's length was unmeasured and possibly shorter than the cycle (a scenario that would need
   stretching to fill it); measured, the clip is LONGER than the cycle, so the mechanism compresses it,
   and the stretching scenario the sentence rejected does not arise. The independent reasoning behind
   that sentence still holds and is restated: **decoupling the visible swing from the real hit window
   is REJECTED** — the animation must not lie about when it hits — not "fitting the clip to the cycle,"
   which is exactly what the ruled mechanism does.

   **The dev pass measures which frame of the clip carries the visible claw-strike pose — the STRIKE
   FRAME — by eye, scrubbing the imported clip, recorded as a timestamp or frame number in Dev Notes.
   The rate is derived FROM that measurement, not assumed ahead of it** (`4-3d/R13`). A
   hips-displacement excursion peak is NOT accepted as a proxy for the strike frame: the hips peak is
   where the root translates furthest (the lunge/step), the strike frame is where the claw arrives —
   different measurements, and nothing in this story or `4-3c` states the first may stand in for the
   second. Any figure describing "the hips-displacement peak at t = 1.4333 s" is unverified in this
   repo: `1.4333 s` is `walk`'s clip length in `4-3c`'s own table
   (`4-3c-minion-rig-adoption.md:608`), not a time-of-peak for `attack`, and no time-of-peak column
   exists for `attack`'s mid-clip excursion (recorded there only as a magnitude, 1.1722).

   **REOPEN CONDITION, arithmetic corrected** (`4-3d/R14`, arithmetic amended by `4-3d/R19`). Let `T`
   be the measured strike frame's timestamp within the 2.6667 s clip. Aligning the strike to the START
   of the ACTIVE window requires rate `r = T / 0.9`; the clip's effective duration is then
   `2.6667 / r = 2.4 / T`. Break-even is `T = 1.263 s` (`r = 1.40`, duration exactly 1.90 s — fits the
   cycle exactly). `T > 1.263 s`: duration falls BELOW the cycle — the clip ends early and holds its
   final pose for the remainder of the cycle, a cost of its own, not a free branch (see Live Smoke
   below). `T < 1.263 s`: duration rises ABOVE the cycle — chained swings still
   truncate. `T < 0.9 s`: `r < 1.0` — the swing would play SLOWER than authored.

   **STOP CONDITION, upper bound removed** (`4-3d/R20`, amending `4-3d/R19`'s stated trigger the same
   way `4-3d/R19` amended `4-3d/R14`'s — `4-3d/R19` is untouched and stands as the record). **The dev
   pass STOPS at that measurement and returns the mechanism choice to the operator, rather than
   improvising, ONLY if the required rate `r < 1.0`** — equivalently, in the variable the dev pass
   actually measures, **`T < 0.9 s`**. Derivation: `r < 1.0` means the swing plays SLOWER than
   authored, directly contradicting `4-3d/R11`'s accepted consequence below. There is NO upper stop,
   because none is derivable and none is needed — the mechanism is self-bounding. The latest possible
   strike frame is the clip's own end, `T = 2.6667 s`, giving `r = 2.963` and an effective duration of
   `2.4 / 2.6667 = 0.9 s`; the rate cannot run away past that. **Admissible strike-frame timestamps are
   simply `T >= 0.9 s`** — no upper limit — matching `r >= 1.0`.

   Above `r = 1.0` (`T >= 0.9 s`) the dev pass PROCEEDS and RECORDS, in Dev Notes: the measured `T`,
   the derived `r`, the effective clip duration (`2.4 / T`), and which artefact results — truncation
   (`T < 1.263 s`) or held final pose (`T > 1.263 s`), with its duration per cycle. The operator's eye
   rules on it at Live Smoke.

   **Truncation is explicitly NOT a stop condition.** `4-3d/R15` already rules it a Live Smoke watch
   item; the arithmetic above shows exactly when it survives (`T < 1.263 s`), and it survives with the
   alignment still achieved.

   **Rejected Alternatives** (`4-3d/R11`):
   - **(b) A partial clip range** and **(c) a `custom_speed`/start-offset play call** are both
     REJECTED. Both require playback to begin partway into the clip to land the strike in the active
     window, which removes the front of the windup — the anticipation the player reads to time a
     parry.
   - **Accepted consequence**, in the operator's words: the whole swing plays visibly faster than
     authored, complete and uncut, and that is accepted.

   **Priority, ruled** (`4-3d/R15`). Alignment of the visible strike beats elimination of the
   `4-3c`-observed ~0.767 s end-of-clip truncation (`4-3c-minion-rig-adoption.md:853-857`, anchor
   "CONSEQUENCE, stated plainly and NOT fixed here… each chained swing now truncates the final
   ~0.767s (28.7%) of the clip"; carried at `sprint-status.yaml:111`). Whether the ruled rate also closes that truncation depends on the
   measured strike frame and is not assumed here — the truncation's readability has never been judged
   by eye, unlike the strike/impact mismatch, which is an observed live defect (`4-3c1`'s Live Smoke).
   If the ruled rate still leaves chained swings truncated, that is a Live Smoke watch item, not a gate
   blocker.

   **Withdrawn** (`4-3d/R12`, corrected by append). The WITHDRAWN band (1.4035–1.5926) and peak-time
   figure (1.4333 s) were both derived from the unverified hips-peak-as-strike-frame conflation above
   and are withdrawn, along with the claim that a single rate value fixes both the strike alignment and
   the truncation — that withdrawal is not a claim that no rate figure appears anywhere in this story.
   The break-even rate stated above (`r = 1.40`) is a different, legitimate figure: a definitional
   consequence of the two measured inputs (clip length, authored windup), not of the withdrawn
   conflation, and it stands. The dev pass still computes its own rate from its own measured strike
   frame; no ruled answer is handed to it.

2. **The corpse is retained for 10 seconds.** Today
   `MatchRunner._free_dead_unit_actors` (`match_runner.gd:682-691`) frees a dead unit's actor the
   SAME tick death is detected — before this story, that is invisible, because there is nothing to see
   fall. This story changes that seat: on first detecting `is_alive_at(index) == false` for a
   previously-live actor, the actor is **not** freed immediately, and stays `is_instance_valid` for the
   full linger — retention is asserted and guarded on that fact alone (AC 3 states the tick-counted
   mechanism). The player being able to walk through the corpse is AC 4's effect, produced by AC 4's
   own mechanism (collision disabled) and guarded there, not here.

3. **The linger is TICK-COUNTED, the timer lives ON THE ACTOR, and it honours the debug pause and
   debug reset.** Never a parallel runner-local array. Two measured reasons, both load-bearing: a
   wall-clock timer keeps running while the game is paused, so a corpse would vanish mid-inspection
   during a paused step-through (`3-0b`'s deterministic step/pause, AC1/AC2, would be visibly broken by
   this story if the linger ignored it); and a parallel runner-local array survives the debug reset
   that clears the actors, which would either leak stale entries or need its own reset-relay wiring a
   per-actor timer does not. The actor is freed once its timer reaches 10 seconds (600 ticks at
   60 Hz).

4. **Collision is disabled for ALL of the unit's collision nodes, not a subset — `Collision`,
   `Hurtbox`, AND `Hitbox` together — from a seat OUTSIDE any physics callback.** This is what makes
   the corpse walkable: a hero driven into the corpse's position ends up past it, falsifiable by that
   position delta alone — the walk-through observable lives here, not on AC 2 (`4-3d/R16`'s
   independent-falsifiability standard; AC 2 retains only retention, a separate falsifiable property).
   Leaving the
   `Hurtbox` live keeps a lingering corpse detectable to a hero's hitbox query, which writes
   recording/replay-stream noise (`3-0c`'s recorder taps the contact channel before this seam runs;
   `match_state.gd:1101`'s dead-target drop means gameplay is NOT at risk — a fact landing on a dead
   record is dropped before dedupe and `register_swing_hit` — so this is a cleanliness requirement, not
   a correctness one). **The disable is DEFERRED to a seat outside any physics callback, not applied
   inline** where death is first observed: changing collision flags from inside a physics callback
   (`_physics_process`, `_integrate_forces`, or a signal fired from one) makes the engine emit an error
   line — this half is an engine-behaviour assumption, to be confirmed live by the dev pass (run once
   inline, observe, defer) rather than one already measured in this repo. What IS measured is that the
   harness fails the suite on any such line: `4-3b`'s review-fix pass tightened `test/run_all.sh`
   (`:18-19`, `:32-33`) to `grep -qE "SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:"` on both the
   state-harness and integration exits — an inline disable that emits `^ERROR:` would fail the suite it
   must run under. The dev pass finds the correct non-callback seat (e.g. deferred via
   `call_deferred`, or moved to a seat that already runs outside physics callbacks) and records which
   one and why. `Collision`, `Hurtbox`, and `Hitbox` need different properties disabled per node — the
   per-node property is a dev-pass measurement, not fixed here; the guard is the visible EFFECT
   (`get_overlapping_areas()` returns empty against the corpse), not any one property read.

5. **The `death` clip (loop disabled, `4-3c` AC 3) plays once and holds its final pose for the
   remainder of the 10 s**, on the `3-0a/R5` clip-end/mid-clip policy already cited above (What this
   story inherits) — applied verbatim, not re-cited under a different number here. **The guard is the
   visible EFFECT**: from the clip's end through the last tick before the actor is freed — i.e. through
   tick N+599, reusing AC 2/3's already-bound retention count (`is_instance_valid` at N+599, freed at
   N+600) — the corpse's `AnimationPlayer` playback position remains pinned at the clip's end, and no
   other clip is selected in that span. Not a `loop`-flag read.

**Collateral corrections, named rather than left to silently disagree with the code (not independent
acceptance criteria):**

- **Two shipped comments assert the invariant AC 2-5 break, both corrected:**
  - `src/state/match_state.gd:744-747` — `_advance_unit_attacks`'s header comment: "A DEAD UNIT IS
    SKIPPED ENTIRELY… Nothing gathers a corpse's hitbox (the runner frees its actor the same tick)."
    This is `src/state/`, and the dev pass's own scope statement below says this story makes NO
    behavioural change under `src/state/` — the comment is corrected in place (the actor is no
    longer freed the same tick; the hitbox is inert because collision is disabled, not because the
    actor is gone) with no other line in the file touched.
  - `src/main/match_runner.gd:1083-1084` (re-cited from the stale `975-978`; verbatim anchor
    "`is_instance_valid()` guarded, and the liveness seat consulted -- a corpse's actor is freed after
    `advance()`, but a unit killed between gathers must not still be swinging.") — this is
    `_gather_unit_facts`'s header comment (the unit-hitbox GATHER pass, not the aim pass this story
    previously named). Corrected to state that a corpse's actor now LINGERS rather than being freed
    after `advance()`, with the rest of the sentence (why a mid-gather kill must not still swing) left
    standing — that reasoning is unaffected by the linger.
- **The clip's net displacement (AC 5) is ACCEPTED, but NOT on `4-3c`'s own cited reasoning — that
  reasoning was hero-specific and does not transfer.** `3-0a`/R9 accepted the hero's `death` topple
  because `_end_round()` freezes BOTH heroes' velocity for the remainder of the round, so nothing
  competes with the clip's own translation — a minion dying does NOT end the round, so that argument
  does not apply here. **The correct reason, measured at the gate:** `_approach_unit_actors`
  (`match_runner.gd:795`, gate at `:811`, `if not player.units.is_alive_at(index):`) already gates on
  `is_alive_at`, so a dead unit is NEVER driven by `UnitActor.approach()` again — nothing ever calls
  `move_and_slide()` on a dead unit's actor, so there is nothing for the `death` clip's own translation
  to compete with, for the same structural reason as the hero's case but reached by a different path
  (liveness-gated driving, not a round-over freeze). This is the reason the dev pass writes into Dev
  Notes; the `3-0a`/R9 citation from `4-3c`'s own authoring pass is corrected, not inherited.

**Scope statement, corrected from a blanket "no `src/state/` change" to what is actually true:**
**no BEHAVIOURAL change under `src/state/`; one comment corrected** (`match_state.gd:744-747`,
above). `UnitBoard`'s record for that index, and the index itself, remain UNCHANGED by this story —
the board record and its permanently-unrecycled index (`UnitBoard.add()` only ever grows,
`unit_board.gd`, `4-3a`'s own shipped precedent) already outlive the actor today; this story only
delays when the ACTOR catches up to that fact, and corrects one comment that described the old
timing.

*(`4-3d/R16` records this split of the former single AC 2 into ACs 2-5, each independently
falsifiable, plus the collateral corrections above kept out of AC numbering because they are not
independently falsifiable behaviour. The walk-through observable now sits on AC 4, correcting an
earlier fix pass's wording that guarded it on AC 2 while its only failure mode ran through AC 4's
mechanism — `4-3d/R16`'s own standard, not a new ruling.)*

## Non-Goals (explicit)

- **Any BalanceConfig field for the linger duration.** 10 seconds is fixed by this AC, not authored —
  the same "adoption/lifecycle mechanism, not a tuning pass" posture `4-3c` took for the idle/walk
  epsilon.
- **Object pooling for the linger.** `4-5`'s tier (`4-1` close-out, `E4-P/R8`) is unaffected; this
  story still plain-instantiates and `queue_free()`s.
- **Per-kind alignment or per-kind linger duration.** One shared mechanism, on the same "minions run
  one shared set of scalars" posture `4-3b`/`4-3c` both took; per-kind conversion is `4-4`'s opening
  act.

## Tasks / Subtasks

- [x] Re-confirm `attack.fbx`'s real clip length (2.6667 s, already measured in `4-3c`) via the same
      headless-script method used for the Hips-track table, from the imported library, before applying
      any rate (AC: 1)
- [x] Measure which frame carries the visible claw-strike pose; record as a timestamp/frame number
      in Dev Notes; check the REOPEN CONDITION before proceeding (AC: 1)
- [x] Compute the custom `AnimationPlayer` rate from the measured strike frame and apply it; guard the
      EFFECT — the clip's playback position at the moment the ACTIVE window opens — not the rate value
      or the clip name (AC: 1)
- [x] Change `_free_dead_unit_actors`'s seat: on first observing alive-to-dead, start a tick-counted
      linger timer living ON THE ACTOR (not a parallel runner array); free the actor once it reaches
      10 s (600 ticks at 60 Hz) (AC: 2, 3)
- [x] Guard retention as an effect: the corpse actor is still `is_instance_valid` at tick N+599 and
      null at N+600 (a tick count, not a timer-field read) (AC: 2, 3)
- [x] Guard walkthrough as an effect: a hero driven into the corpse's position ends up past it
      (a position delta), not a collision-layer property read (AC: 4)
- [x] Guard the paused step-through as an effect: advance real frames while `_paused`, assert the
      corpse survives AND its tick counter did not move (AC: 3)
- [x] Guard the debug reset as an effect: corpse count is 0 after `round_started`, and no orphaned
      node is left in the tree (AC: 3)
- [x] Disable `Collision`, `Hurtbox`, and `Hitbox` together, from a seat OUTSIDE any physics callback
      (deferred or otherwise), the instant death is first observed; run once inline first to observe
      the engine's `^ERROR:` behaviour, then move to the deferred seat; confirm the tightened
      `^ERROR:`-failing test harness stays clean (AC: 4)
- [x] Guard collision-disabled as an effect: the hero hitbox's `get_overlapping_areas()` returns EMPTY
      against a corpse, and the recorder's contact channel for that tick is empty (AC: 4)
- [x] Guard the death-clip hold as an effect: from the clip's end through tick N+599 (reusing AC 2/3's
      already-bound retention count), the corpse's `AnimationPlayer` playback position stays pinned at
      the clip's end and no other clip is selected in that span (AC: 5)
- [x] DELETE `test_unit_clip_selection.gd` Part B's inherited `push_line < gate_line` source-order/
      indentation assertion — `4-3d/R17` REPLACES it, does not extend it (AC: 5, `4-3d/R17`)
- [x] Write the behavioural replacement for Part B, in Part A's shape
      (`_assert_clip_content_changes`, effect-based): a corpse frozen in a half-raised claw versus one
      playing `death`, the effect the deleted assertion could not see (AC: 5, `4-3d/R17`)
- [x] Correct the two shipped comments (`match_state.gd:744-747`, `match_runner.gd:1083-1084`) to match
      the new lifecycle; confirm no other `src/state/` line changes (collateral)
- [x] Confirm the debug-reset relay (`_free_unit_actors`, `match_runner.gd:912-918`, called from
      `_relay_round_started` at `:635`) already frees a lingering corpse with no change — it frees
      every entry in `_unit_actors[slot]` regardless of liveness — by test, not by edit (AC: 3)
- [x] Write the corrected `death`-net-displacement reasoning into Dev Notes (liveness-gated driving,
      not a round-over freeze) (AC: 5)
- [x] Measure the golden BOTH directions (before/after); confirm the hash `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf` unmoved (AC: Golden
      Prediction)
- [x] Measure `project.godot` byte-identity both directions (AC: Golden Prediction)
- [x] Check for orphaned `godot` processes at the start and end of the dev pass (`4-3b/R31`)

## Dev Notes

- **Inherited from `4-3c`'s H1 fix pass:** `death` was never reachable end-to-end live in `4-3c`
  (its actor was freed the same tick death was observed); this story's corpse linger is what finally
  makes that push and its live proof possible, and owes it.
- **Dependency on `4-3c`, stated precisely.** This story requires `4-3c`'s AC 4 liveness gate on
  `_aim_unit_actors` to already be shipped — without it, a lingering corpse reaching that seat on a
  later tick would read a frozen `attack_phase` and could visibly re-swing or mis-aim. This story adds
  no liveness gate of its own; it is the reason `4-3c`'s gate exists.
- **The FIVE runner loops this story reaches, measured.** `_free_dead_unit_actors` (the linger
  itself); `_aim_unit_actors` (now sees a lingering corpse, guarded by `4-3c`'s gate);
  `_approach_unit_actors` (`match_runner.gd:795`, gate at `:811`,
  `if not player.units.is_alive_at(index): continue` — confirmed a NO-OP for a corpse, which is the
  basis of the corrected `death`-displacement reasoning above); `_gather_unit_facts`
  (`match_runner.gd:1083-1084`) — the unit-hitbox GATHER pass, whose shipped header comment this story
  invalidates and corrects (collateral, above); it now iterates over actor arrays containing corpses
  for up to 600 ticks, which is the seat AC 4's collision-disable exists to keep clean — a lingering
  corpse at this seat that is not collision-clean pollutes the intent recorder's contact channel, the
  same cleanliness concern AC 4 states; and the debug-reset relay `_free_unit_actors`
  (`match_runner.gd:912-918`, called from `_relay_round_started` at `:635`) — this loop is **confirmed
  a NO-OP for a lingering corpse**, not a change site: it frees every entry in `_unit_actors[slot]`
  unconditionally, live or corpse, with no liveness check, so a lingering corpse is already covered
  today. The task is to confirm this by test, not to edit the loop.
- **Collision-disable seat, to be measured and recorded by the dev pass.** The harness half is
  measured: `test/run_all.sh` (`:18-19`, `:32-33`) fails the suite on any `^ERROR:` line, tightened by
  `4-3b`'s review-fix pass — this is not a cosmetic warning, it is a suite-failing condition. **Citation
  corrected at the second fix pass (`4-3d/R9`)**: this `^ERROR:`-failing behaviour cites `test/run_all.sh`
  itself, not `4-3b/R31` — `4-3b/R31` is the orphaned-`godot`-process ruling, a different check entirely
  (see the Task list). The
  engine half — that changing collision shape/monitoring flags from inside a physics callback raises
  such an error — is NOT measured anywhere in this repo; it is an engine-behaviour assumption to be
  confirmed live by the dev pass (run the disable once inline, observe the harness result, then move
  to the deferred seat). The exact deferred seat (a `call_deferred` call from within
  `_free_dead_unit_actors`, or moving the disable to a seat that already runs outside the physics
  callback chain) is a dev-pass measurement, not fixed here.
- **`Collision`/`Hurtbox`/`Hitbox` need different properties disabled, measured at the gate.**
  `unit_actor.tscn:22-26` — `Hurtbox` ships `collision_layer = 2`, `collision_mask = 0`,
  `monitoring = false` already; what makes it detectable is its LAYER and `monitorable` (default
  true), not `monitoring`. `unit_actor.tscn:33-36` — `Hitbox` ships `collision_layer = 4`,
  `collision_mask = 2`, `monitorable = false` already; its live property is `monitoring`. `Collision`
  (`:17-19`) is a `CollisionShape3D` needing its own `disabled` property. The three nodes are
  correctly named in AC 4; which property per node is a dev-pass measurement. The guard is the
  effect — `get_overlapping_areas()` empty against the corpse — not a property read.
- **Named mutations, one per guard, PROVISIONAL.** Four of the nine (1, 4, 5, 6, below) target seats
  this story explicitly defers to the dev pass (the linger-timer seat, the non-callback collision-
  disable seat, the per-node collision property). This table is the provisional draft; **the dev pass
  MUST re-derive every mutation against the seat it actually picks and replace this table with the
  measured one before the story is considered guard-complete** — on this project's standing mutation-
  table practice (`4-3c`'s "Mutation row 6, provenance MEASURED"; `3-4`'s "mutation table M1-M6 all
  confirmed"). Each must turn its guard RED:
  1. AC 1 playback-position guard — hardcode the rate to 1.0, ignoring the measured strike frame;
     playback position at ACTIVE-open drifts off target. The guard must fail this mutation at a
     tolerance no wider than the T-to-0.9s delta at the shipped strike frame (order 0.3–0.45 s at a
     mid-band `T`); a tolerance wider than that passes this null-implementation mutation vacuously and
     must be tightened.
  2. AC 2/3 retention guard — revert the linger, free the actor the same tick death is detected;
     `is_instance_valid` is already false well before tick N+599.
  3. AC 4 walk-through guard — skip AC 4's collision-disable; the hero is blocked before reaching the
     corpse's position, no position delta past it.
  4. AC 3 pause guard — drive the linger timer off wall-clock delta instead of a tick count; the
     counter advances while `_paused`.
  5. AC 3 reset guard — track linger corpses in a parallel array the debug-reset relay does not
     iterate; a corpse survives `round_started` as an orphaned node.
  6. AC 4 collision guard — disable only `Hitbox`, leave `Collision`/`Hurtbox` live;
     `get_overlapping_areas()` returns non-empty against the corpse. Dependent on AC 4's per-node
     togglability measurement (Dev Notes) — if `Collision`/`Hurtbox`/`Hitbox` are not independently
     toggleable as measured, this mutation's premise does not hold and it must be re-seated against
     whichever grouping the dev pass measures.
  7. AC 3 relay no-op guard — add a liveness skip to `_free_unit_actors` so it no longer frees corpses
     unconditionally; a lingering corpse survives `round_started` instead of being freed.
  8. Part B behavioural guard — revert `4-3c/R15`'s push-before-liveness-skip ordering; a lingering
     corpse freezes mid-swing instead of playing `death`.
  9. AC 5 hold-final-pose guard — re-enable `loop` on the `death` clip; playback position does not stay
     pinned at the clip's end.
- **Golden Prediction reasoning, stated rather than assumed.** Like `4-3c`, this story touches no
  `src/state/` field and adds no `BalanceConfig`/snapshot field — its one `src/state/` edit is a
  comment correction, not a behavioural change. `test/state/test_determinism.gd` runs `MatchState`
  alone with no runner, no physics, and no actor, so nothing here is reachable from that fixture.
  **Predicted UNMOVED, current golden `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`
  (`test/state/test_determinism.gd:458`) — to be MEASURED IN BOTH DIRECTIONS at the dev pass.**
- **Deferred observations from the review fix pass (2026-08-26), traps for later rather than work
  for now — named, not fixed:**
  - The deferred collision-disable's "one frame of live collision" claim (`unit_actor.gd`,
    `begin_corpse_linger`) is a timing assumption, not a guarantee — it would become a real defect
    if a `call_deferred` flush ever landed more than one tick after the disable is queued (physics
    catch-up / multi-substep ticking), leaving a corpse's collision live for longer than one frame.
  - The AC 5 pose-hold guard reads only `mixamorig_Hips` — it would become a real defect if some
    other bone kept animating after the `death` clip's own end while Hips itself stayed still.
  - A lingering corpse's collision is disabled and never re-enabled — this would become a real
    defect the moment any future mechanic makes a unit alive again mid-linger (no such mechanic
    exists today), producing a live-driven actor that nothing can ever collide with.
  - The AC 1 alignment guard derives its target from authored `minion_attack_windup_seconds`
    (raw seconds), not from `attack_windup_ticks / 60.0` (the tick-rounded value the runner
    actually advances by) — these coincide today because 0.9s × 60 divides evenly to 54 ticks with
    no rounding; it would become a real defect if the authored windup were ever retuned to a value
    that does not divide evenly into 1/60s ticks.

### Project Structure Notes

- `src/main/match_runner.gd` — `_free_dead_unit_actors` gains the linger + deferred collision-disable
  (AC 2-4); its mutation-shape comment near `_gather_unit_facts` (`1083-1084`) corrected.
- `src/actors/minions/unit_actor.gd` or `unit_actor.tscn` — wherever the dev pass seats the per-actor
  linger timer (AC 2-3) and the per-node collision-disable properties (AC 4).
- `src/actors/minions/` — the `4-3c` presentation controller's `AnimationPlayer` call for the attack
  clip gains the AC 1 alignment mechanism (custom playback rate).
- `src/state/match_state.gd` — ONE comment corrected (`744-747`); no behavioural line changes.
- `test/integration/test_unit_clip_selection.gd` — Part B's inherited source-order/indentation
  assertion (`push_line < gate_line`) is REPLACED, not extended (`4-3d/R17`), by a behavioural
  assertion in Part A's shape (`_assert_clip_content_changes`, effect-based).

### Project Context Rules

- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** The linger timer is ticked from an
  existing per-tick seat, not a new `_process`/`_physics_process`. [Source: docs/project-context.md;
  CLAUDE.md]
- **HARD RULE — state/visual separation.** The linger and collision-disable are actor/runner-local;
  no `UnitBoard`/`MatchState` field is written. [Source: docs/project-context.md:69-73]
- **Determinism / pause discipline.** The linger must respect the `3-0b` deterministic step/pause —
  tick-counted, not wall-clock. [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md
  AC1/AC2]
- **`.tscn`/config edits are textual with the editor closed** unless asset/AnimationPlayer work
  requires it, under the `3-0a`/R3 protocol. [Source: CLAUDE.md; 3-0a/R3]

### References

- [Source: docs/implementation-artifacts/4-3c-minion-rig-adoption.md — full file, especially AC 4's
  liveness gate (`4-3c/R4`) this story depends on, the "AC 5 and AC 6 are CUT" note, and the
  Hips-track measurement table (`:605-609`, `attack` 2.6667 s / 80 keys)]
- [Source: decision-log.md Session 2026-08-14 — `4-3c/R2` (the cut, ratified), every
  `4-3d`-bound ruling recorded there, and Session 2026-08-26 (this fix pass, `4-3d/R11`-`R18`)]
- [Source: docs/implementation-artifacts/3-0a-rig-adoption.md — AC5 clip-end/mid-clip policy;
  `3-0a`/R9 death-topple acceptance (hero-specific reasoning, corrected for this story)]
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md — AC1/AC2 deterministic
  step/pause; the clip-retime precedent (`tools/retime_clips.gd`) as the class of work this AC 1
  belongs to]
- [Source: src/main/match_runner.gd:682-691 (`_free_dead_unit_actors`), 795-811
  (`_approach_unit_actors`, the `is_alive_at` gate at line 811), 912-918 (`_free_unit_actors`, the
  debug-reset relay, confirmed a no-op for a corpse), 1083-1084 (the comment to correct, header of
  `_gather_unit_facts`)]
- [Source: src/state/match_state.gd:744-747 (the comment to correct), :1101 (the dead-target drop
  that makes AC 4's collision disable a cleanliness requirement, not a correctness one)]
- [Source: src/actors/minions/unit_actor.tscn:17-19 (`Collision`), :22-26 (`Hurtbox`), :33-36
  (`Hitbox`) — the per-node properties AC 4 disables]
- [Source: data/balance/balance_config.tres:37-39 (authored attack-rhythm durations)]
- [Source: test/run_all.sh:18-19, :32-33 (the `^ERROR:`-failing harness guard)]
- [Source: docs/project-context.md — F1, HARD RULE state/visual separation]

## Golden Prediction

**Predicted UNMOVED, measured in BOTH directions at the dev pass. Current golden:
`4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`** (`test/state/test_determinism.gd:458`).
This story's one `src/state/` edit is a comment correction with no behavioural change; it adds no
`BalanceConfig`/`BalanceTicks` field and writes no `MatchState`/`UnitBoard`/`PlayerState` snapshot
field. `test/state/test_determinism.gd` runs `MatchState` alone with no runner, no physics, and no
actor, so nothing this story ships is reachable from that fixture.

**`project.godot` byte-identity is ALSO measured in both directions**, on the `3-0a`/R3 protocol this
project applies to every story that opens the editor.

## Live Smoke

**REQUIRED**, Tier A default (this story ships player-facing timing and lifecycle behaviour for a
live-killable actor class). No `.tscn` flip needed — the shipped default (`slot_controller_kinds =
[0, 1]`) already gives two live human slots.

- The **visible strike lands when the damage lands**, not visibly before or after (AC 1's alignment,
  judged live, not only by the recorded frame number).
- The **sped-up windup still reads as a windup a player can time a parry against.** This is the
  accepted cost of the ruled mechanism (the whole swing plays visibly faster than authored) — the
  Live Smoke is the only place it can be falsified.
- **Chained swings — whichever artefact the measured rate produces**, truncation if `T < 1.263 s` or a
  held final pose if `T > 1.263 s` — judged by eye for readability. The project has already judged one
  of these worse: `4-3c-minion-rig-adoption.md:853-857` (anchor "CONSEQUENCE, stated plainly and NOT
  fixed here") ruled the truncation "strictly better than the held-pose defect it replaces", and
  `:894` — the `2026-08-15` DEFECT B1 FIX PASS Change Log row, anchor "the `_select` dedup held the
  finished clip's final pose for ~9.7s", NOT the `2026-08-14` readiness-gate row above it — records
  that the held pose IS the `4-3c` defect-B1 `4-3c1` shipped a guard
  (`test_unit_attack_retrigger.gd`) to kill. This is the only place either artefact is judged.
- The **corpse falls and stays down for about ten seconds** (AC 2/3), **and the operator can walk
  through it** (AC 4 — the walk-through observable moved to AC 4 this cycle, `4-3d/R16`) — confirm
  nothing blocks him and nothing looks like it snapped back to standing.
- **Paused step-through**: with the debug pause held, confirm a lingering corpse does NOT vanish or
  advance while the game is paused (the tick-counted timer, not wall-clock) (AC 3).
- **Debug reset**: confirm a lingering corpse is cleared by the debug reset along with everything
  else, not left behind as an orphaned node (AC 3).

The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent
writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-14 (readiness-gate fix pass on `4-3c`, this story split out).

Claude Opus 5 (1M context) — DEV PASS, 2026-08-26.

### Debug Log References

- `tools/measure_strike_frame.gd` (new, committed) — the AC 1 strike-frame measurement, headless.
- Baseline suite (twice, before any edit): `499 tests, 0 failed, 3895 assertions`, 37 integration
  files, ALL TESTS PASSED.
- Final suite (twice, after): `499 tests, 0 failed, 3895 assertions`, 40 integration files, ALL
  TESTS PASSED.

### Completion Notes List

**1. AC 1 — THE MEASUREMENT, AND THE STOP CONDITION CLEARED.**

`T = 1.3000 s` (frame 39 of 80). `r = T / 0.9 = 1.4444`. `r >= 1.0`, so the STOP CONDITION
(`4-3d/R20`) does NOT trigger and the pass proceeded.

- **Effective clip duration** = `2.4 / T` = `2.6667 / 1.4444` = **1.8462 s** against the 1.9 s
  authored cycle.
- **`T > 1.263 s`, so the artefact is the HELD FINAL POSE branch**, not truncation: **0.0538 s
  (3.2 ticks at 60 Hz) of held final pose per chained swing**. The `~0.767 s` (28.7%) end-of-clip
  truncation `4-3c` shipped is CLOSED as a side effect. `4-3d/R15` ruled that closure subordinate
  to the alignment; it is not claimed as a goal met. Both are Live Smoke watch items and neither
  blocked this pass.

**METHOD, recorded because `4-3d/R13` requires it.** The story words the measurement as "by eye,
scrubbing the imported clip". The editor is the one tool this project will not open (`3-0a/R3`;
six recorded incidents), so the scrub was done numerically by `tools/measure_strike_frame.gd`,
which samples all 81 frame boundaries of the imported `attack` clip and reports, per frame, each
hand and forearm bone's position **relative to the hips** — the arm's own extension with the
body's lunge divided out — resolved into the model instance's space, whose `+Z` is the actor
root's forward.

- The **LEFT hand is the striking limb**, decisively: it reaches `0.8337` forward of the hips
  against the right hand's `0.7303`, and `1.60` forward in actor space against the right's `0.80`.
- Its forward extension **peaks at frame 39, `t = 1.3000 s`**, where its speed also collapses
  (`20.5 → 14.1 → 10.3` units/s) — an arrival, not a pass-through. The right arm is in
  anti-phase, sweeping back as the left arrives.
- Cross-check: measuring the same hand's ABSOLUTE forward position (lunge included) puts the peak
  one frame later at `1.3333 s` (`r = 1.4815`, duration 1.80 s). Same branch, same conclusion; the
  relative-to-hips figure is the one shipped, because it is the arm's own strike.

**THE HIPS PEAK IS AT `t = 1.4333 s`, 0.1333 s LATER, and it is NOT what shipped.** This
incidentally confirms the provenance of the WITHDRAWN figures (`4-3d/R12`/`R21`): `1.4333 / 0.9 =
1.5926`, exactly the upper end of the withdrawn band. `4-3d/R13`'s ruling that the hips peak is
not a strike-frame proxy is vindicated by measurement — the two differ by four clip frames.

**MECHANISM.** `AnimationPlayer.play(clip, -1.0, rate)` — the per-play `custom_speed`, applied
only to `attack`. Deliberately NOT `speed_scale`, which is a property of the whole player and
would speed up `idle`/`walk`/`death` too. Playback still starts at frame 0 and the whole clip
plays, complete and uncut, which is what separates this from rejected alternatives (b) and (c).

**2. AC 4 — A STORY PREMISE MEASURED FALSE. NEEDS A RULING (non-blocking; the AC's requirement was
implemented as written).**

AC 4 states that changing collision flags from inside a physics callback "makes the engine emit an
error line", and flags it as an engine-behaviour assumption for this pass to confirm live. **It is
FALSE on this build.** Measured exactly as the task asked: `disable_all_collision()` was called
INLINE from `_free_dead_unit_actors` (itself inside `_physics_process`), and a real kill was driven
through `test_unit_combat_live.gd`. stderr carried **no `ERROR:` line and no `SCRIPT ERROR`**, and
all three writes took effect. Godot's "function blocked" guard fires while the physics server is
FLUSHING SIGNALS; `_physics_process` is not inside that flush.

**The deferral shipped anyway**, because AC 4 requires the SEAT and only its RATIONALE was wrong —
and the seat is independently correct (it is the only version that stays safe if this disable is
ever reached from an `area_entered`/`body_entered` handler, which IS inside the flush). The
rationale is corrected in place in `unit_actor.gd`. **The operator may wish to rule on whether the
AC's now-unsupported justification should be struck from the story text.**

**3. AC 4 — the per-node properties, measured.** `Collision` (CollisionShape3D) → `disabled`;
`Hurtbox` (Area3D, `monitoring` already false) → `monitorable`; `Hitbox` (Area3D, `monitorable`
already false) → `monitoring`. The three ARE independently toggleable, which is what lets
mutation 6 be seated as the story drafted it.

**4. AC 5 — the guard is the BONE POSE, not the playback position. A correction to the AC's
wording, not a weakening of it.** MEASURED (and already recorded from the other side in
`test_unit_clip_selection.gd`): when a NON-LOOPING clip ends, Godot's AnimationPlayer STOPS —
`current_animation` clears to `""` — while the final pose stays on screen.

**CORRECTED AT THE REVIEW FIX PASS (2026-08-26).** This note previously also claimed
`current_animation_position` returns `0` once the clip ends, and gave that as the reason AC 5's
literal playback-position wording is unimplementable. **Re-measured, independently, twice (a
synthetic clip and the real `death` clip): that half is FALSE.** `current_animation_position`
does not reset to `0` — it stays PINNED at the clip's own length (`4.6000` for `death`) once the
clip stops. `current_animation` clearing to `""` is the only part of the original claim that
holds.

This does not change what shipped: the bone-pose assertion stays as written, because it is the
STRONGER claim, not a workaround for an unimplementable one. A pinned playback-position guard
would read as correct even if something else were overwriting the actual pose on screen (a rogue
track, a pose fed in from elsewhere); the bone pose is what AC 5 is actually about — that the
corpse visibly stops moving — and only the pose can see that directly. What AC 5 visibly asks
about is that THE POSE DOES NOT MOVE, and that is what shipped: the corpse's `mixamorig_Hips` pose
is sampled from past the clip's end (`death` is 4.6000 s) through tick N+599 and must not change,
must differ from the pose the unit held alive, and no other clip may be selected in that span.

**5. `4-3d/R17` — Part B DELETED and REPLACED, and the replacement caught the defect.** The
source-order/indentation assertion is gone from `test_unit_clip_selection.gd`. Its behavioural
replacement lives in `test_unit_corpse_linger_live.gd` (`_reference_pose`): the corpse must hold
the pose the `death` clip ENDS ON and must not hold the pose the `attack` clip ends on. Both
references are built by driving a throwaway unit instance's own AnimationPlayer to each clip's end.
**Mutation 8 (move the push below the liveness gate) turns it RED with exactly the right
diagnostic**: `held_pose_IS_the_attack_clip's_end (4-3c/R15 ordering broken -- the corpse was
never told it died)`. The blind spot `4-3c` recorded is closed.

**6. `test_unit_combat_live.gd`'s AC 11 assertion was INVALIDATED by this story and is corrected,
not weakened.** It asserted "the corpse's actor is gone and its array slot is a HOLE" three frames
after the kill — correct when written, and an assertion of the DEFECT once the linger ships. It now
asserts the corpse is LINGERING and still at its own index; the 600-tick expiry and the hole belong
to `test_unit_corpse_linger_live.gd`, which counts them. This is the same shape of correction
`4-3b` made to that file's AC 6 instrument, recorded in the file. **No other test depended on the
same-tick free** (swept).

**7. AC 5's `death`-net-displacement reasoning, written as the story asks.** The clip's net
displacement is accepted because `_approach_unit_actors` (`match_runner.gd`, gate
`if not player.units.is_alive_at(index)`) already gates on liveness, so `UnitActor.approach()` —
the only caller of `move_and_slide()` on a unit — is never reached for a dead unit. Nothing
competes with the `death` clip's own translation. This is LIVENESS-GATED DRIVING, **not** the
hero's `3-0a/R9` round-over freeze, which is hero-specific and does not transfer (a dying minion
does not end the round).

**8. The debug-reset relay is CONFIRMED A NO-OP, by test.** `_free_unit_actors` frees every entry
in `_unit_actors[slot]` unconditionally, live or corpse. Not edited. Proven by
`test_unit_corpse_walkthrough_live.gd` stage 4, which checks the ARRAYS *and* the TREE for orphaned
`UnitActor` nodes; mutation 7 (add a liveness skip there) turns it RED.

**9. A COUPLING INTRODUCED, named rather than left to be discovered. Worth a ruling.** The shipped
rate is a presentation-local constant (`ATTACK_PLAYBACK_RATE = ATTACK_STRIKE_FRAME_SECONDS /
ATTACK_ALIGNED_WINDUP_SECONDS`), on `WALK_SPEED_EPS`'s precedent — the controller does not read
`BalanceConfigService` (CONSTRAINT C). That means **re-tuning `minion_attack_windup_seconds` no
longer is a pure one-line `.tres` edit for this one field**: the alignment would silently drift.
This does NOT breach the standing `BC/R3` isolation fact (no golden move, no test *literal* to
edit), but it does mean `test_unit_strike_alignment_live.gd` goes RED on such a retune — by design:
it reads the authored windup at run time and fails if it and the constant disagree, naming the
re-derivation needed. The alternative (push the windup into `on_unit_tick`, deriving the rate per
tick) is an API change to the presentation seam and was NOT taken unasked. **Operator's call.**

**10. MUTATION TABLE — RE-DERIVED AGAINST THE SHIPPED SEATS AND MEASURED. This replaces the
story's provisional table.** Every mutation was applied, run, confirmed RED, restored, and the
restore verified by SHA256.

| # | AC | Mutation, at the seat that actually shipped | Guard | Result |
|---|---|---|---|---|
| 1 | 1 | `UnitAnimationController._playback_rate()` returns `1.0` | `test_unit_strike_alignment_live` | **RED** — playback at ACTIVE-open reads 0.9161/0.9241/0.9156 s; worst miss 0.3844 s vs 0.0800 s tolerance |
| 2 | 2/3 | `_free_dead_unit_actors` frees on the tick death is observed (pre-4-3d) | `test_unit_corpse_linger_live` | **RED** — retention never reaches 599 |
| 3 | 4 | drop `$Collision.disabled = true`, keep both areas | `test_unit_corpse_walkthrough_live` | **RED** — hero blocked by the corpse, no position delta past it |
| 4a | 3 | `advance_corpse_linger()` driven by `Time.get_ticks_msec()` instead of the tick count | `test_unit_corpse_linger_live` | **RED** — corpse counted 565 ticks where the runner ran 523 ticking frames |
| 4b | 3 | hoist `_free_dead_unit_actors` OUT of the runner's `ticking` gate | `test_unit_corpse_linger_live` | **RED** — `counter_moved_while_paused(122->123)` |
| 5 | 3 | *(provisional: "track corpses in a parallel array the reset does not iterate")* | — | **DOES NOT APPLY** — see below |
| 6 | 4 | disable ONLY `$Hitbox`, leave `$Collision`/`$Hurtbox` live | `test_unit_corpse_walkthrough_live` | **RED** |
| 7 | 3 | add a liveness skip to `_free_unit_actors` | `test_unit_corpse_walkthrough_live` | **RED** — corpse survives `round_started` as an orphan |
| 8 | Part B | move the `on_unit_tick` push BELOW `_aim_unit_actors`' liveness gate | `test_unit_corpse_linger_live` | **RED** — corpse holds the ATTACK clip's end pose |
| 9 | 5 | make the `death` clip LOOP | `test_unit_corpse_linger_live` | **RED** — pose keeps moving past the clip's end |

**Mutation 5's premise does not hold at the shipped seat, and the story told this pass to say so
rather than force it.** There IS no parallel runner-local array to mutate: AC 3 required the timer
to live on the actor and it does (`UnitActor._linger_ticks`). Its intended failure — a corpse
surviving the debug reset as an orphaned node — is produced instead by **mutation 7**, which is
run and RED, and which is checked against the TREE and not only the arrays. Mutation 5 and 7
collapse into one at this seat.

**Provisional mutation 4 was ALSO mis-derived and is split into 4a/4b.** Applied literally
(wall-clock timer, seat unchanged), it does NOT make the counter advance while paused — the seat
sits inside the `ticking` gate, so nothing runs at all while paused — and the first run of it came
back **GREEN**. Two corrections followed: the guard gained an INDEPENDENT count of the runner's
ticking frames from death to free (so a counter that counts something other than ticks is visible
at all), which turns 4a RED; and 4b was added as the mutation that actually produces the
advances-while-paused defect at this seat.

**11. Two shipped comments corrected, as collateral.** `src/state/match_state.gd`
(`_advance_unit_attacks` header) — the corpse's hitbox is inert because AC 4 disables collision,
not because the actor is gone; **no other line in that file changed, and no behavioural change
under `src/state/`**. `src/main/match_runner.gd` (`_gather_unit_facts` header) — a corpse's actor
now lingers rather than being freed after `advance()`, with the mid-gather-kill reasoning left
standing.

**12. MEASUREMENTS.**

- **Golden: UNMOVED**, both directions. `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`
  before and after. Not re-baselined. The story's prediction holds.
- **State harness: UNMOVED**, `499 tests, 0 failed, 3895 assertions` — run TWICE before, TWICE
  after, all four identical.
- **Integration: 37 → 40 files, all PASS.** Three added
  (`test_unit_strike_alignment_live.gd`, `test_unit_corpse_linger_live.gd`,
  `test_unit_corpse_walkthrough_live.gd`).
- **`project.godot`: BYTE-IDENTICAL**, `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`
  before and after; `common/physics_ticks_per_second=60` intact. **The editor was never opened.**
- **Zero orphaned `godot` processes** at the start and at the end (`4-3b/R31`).

**13. A LEAK THE HARNESS WOULD HAVE FAILED ON, found and fixed.** A `*_live.gd` file that calls
`quit()` MID-SWING, with the minion's AnimationPlayer still playing, makes the engine print
`ERROR: 1 resources still in use at exit` — which `test/run_all.sh` (`:32-33`) greps and fails the
suite on. Every existing `*_live.gd` runs to a natural end and never hit it. The three new files
free the `Main` scene before `quit()`; the reason is recorded in each.

### File List

- `src/actors/minions/unit_animation_controller.gd` — MODIFIED (AC 1: the measured strike frame,
  the derived playback rate, `_playback_rate()`, the per-clip `play()` call)
- `src/actors/minions/unit_actor.gd` — MODIFIED (AC 2/3/4: `LINGER_TICKS`, `_linger_ticks`,
  `is_lingering()`, `begin_corpse_linger()`, `advance_corpse_linger()`, `disable_all_collision()`)
- `src/main/match_runner.gd` — MODIFIED (AC 2/3: `_free_dead_unit_actors` becomes the linger seat;
  collateral: `_gather_unit_facts` header comment corrected)
- `src/state/match_state.gd` — MODIFIED (collateral: ONE comment corrected, no behavioural change)
- `test/integration/test_unit_strike_alignment_live.gd` — ADDED (AC 1)
- `test/integration/test_unit_corpse_linger_live.gd` — ADDED (AC 2, AC 3, AC 5, and `4-3d/R17`'s
  behavioural replacement for the deleted Part B)
- `test/integration/test_unit_corpse_walkthrough_live.gd` — ADDED (AC 4, and AC 3's reset half)
- `test/integration/test_unit_clip_selection.gd` — MODIFIED (Part B DELETED per `4-3d/R17`)
- `test/integration/test_unit_combat_live.gd` — MODIFIED (its AC 11 assertion, invalidated by this
  story's linger, corrected)
- `tools/measure_strike_frame.gd` — ADDED (the AC 1 strike-frame measurement, headless and
  reproducible)

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-14 | Claude Sonnet 5 | Story authored, split out of `4-3c-minion-rig-adoption`'s AC 5/AC 6 at that story's readiness-gate fix pass (`4-3c/R2`, decision-log Session 2026-08-14). Carries the gate's measurements and rulings for strike alignment (clip length unmeasured, three alignment-mechanism options left as an open question for the operator) and corpse lifecycle (all-collision disable deferred outside physics callbacks, tick-counted actor-owned linger timer, two shipped comments named as collateral, death-displacement reasoning corrected from the hero-specific `3-0a`/R9 citation to the minion's own liveness-gated-driving argument). Depends on `4-3c`'s AC 4 liveness gate; cannot run before it. Status `authored`, board `backlog`. |
| 2026-08-14 | Claude Sonnet 5 | SECOND READINESS GATE FIX PASS (`4-3d/R7`-`R10`, decision-log Session 2026-08-14, "4-3c/4-3d second readiness gate, fix pass"). New dependency stated (`4-3d/R10`, recorded): this story's corpse behaviour also depends on `4-3c`'s push-ordering (operator's ruling, `4-3c/R15`) — this story adds no liveness gate of its own, so a lingering corpse is only told it died because `4-3c` pushes before it skips. `4-3d/R7`: the hold-final-pose policy cited once, as `3-0a/R5` (matching the decision log), not twice under two different AC numbers. `4-3d/R8`: the "approximately 2.7 s" clip-length estimate restated as this story's own unverified figure, not quoted from a `4-3c` line the cut deleted. `4-3d/R9`: the harness `^ERROR:`-failing behaviour re-cited to `test/run_all.sh` itself — `4-3b/R31` is the orphaned-process ruling, not this one. No code touched — docs only. |
| 2026-08-15 | Claude Sonnet 5 | AC 5 gains an input from `4-3c`'s Live Smoke: the ~0.767s end-of-clip truncation readability (1.9s cycle vs 2.6667s clip) is unrated by eye, carried here as an open observation. No code touched — docs only. |
| 2026-08-26 | Claude Sonnet 5 | THIRD READINESS GATE FIX PASS (`4-3d/R11`-`R18`, decision-log Session 2026-08-26, "4-3d third readiness gate, fix pass" — 5 blocking, 5 major, 5 minor findings applied). AC 1's mechanism is now DECIDED (custom playback rate, `4-3d/R11`, superseding `4-3d/R6`) with (b)/(c) recorded as Rejected Alternatives, a withdrawn rate band and hips-peak figure (`4-3d/R12`), the hips-displacement peak ruled NOT a strike-frame proxy (`4-3d/R13`), a REOPEN CONDITION added (`4-3d/R14`), and a priority ruling that alignment beats truncation elimination (`4-3d/R15`). The clip length (2.6667 s) is now stated as measured fact, citing `4-3c`'s own table, superseding `4-3d/R5` and `4-3d/R8` (`4-3d/R18`). The former single AC 2 is split into ACs 2-5, each independently falsifiable (`4-3d/R16`). `match_runner.gd` coordinates re-cited from the stale `975-978`/`770` to the current `1083-1084`/`795-811`, by content search, with anchor text quoted. AC 4's Hurtbox rationale corrected to a recording/replay-stream cleanliness argument (citing `match_state.gd:1101`'s dead-target drop), and the per-node collision property corrected (`monitorable` vs `monitoring` vs `disabled`) rather than naming one property for all three nodes. The debug-reset relay Dev Note corrected from "must free a lingering corpse too" to a confirmed no-op. The `^ERROR:` claim split into its measured half (the harness) and its assumed half (the engine behaviour, to be confirmed live by the dev pass). Guards for every AC now named as visible effects, not identifiers or source-order (`4-3d/R17`), including the behavioural replacement `test_unit_clip_selection.gd` Part B owes. `baseline_commit` re-baselined to `f009dd5`. Golden hash named explicitly (`4a089063...`) in both the Golden Prediction section and its Task. Status stays `authored`, board stays `backlog` — promotion is the operator's act. No code touched — docs only. |
| 2026-08-26 | Claude Sonnet 5 | FOURTH READINESS GATE FIX PASS, second docs-only correction pass (`4-3d/R19`, decision-log Session 2026-08-26, "4-3d fourth readiness gate, fix pass" — 1 blocking, 6 major, 7 minor findings applied). BLOCKING: the REOPEN CONDITION's arithmetic was inverted; corrected with the derivation shown (`r = T / 0.9`, effective duration `2.4 / T`, break-even `T = 1.263 s`), and its stop trigger replaced with a rate-band condition, `r` outside `[1.0, 2.0]` (`4-3d/R19`, amending `4-3d/R14`'s stated trigger, not its stop-condition mechanism); truncation is explicitly confirmed NOT a stop condition. `4-3b/R27` and `4-3b/R26` citations removed from AC 1 where they did not support their claims. AC 5 gains a named EFFECT guard (playback position pinned at clip end) and a guard task; it had none before. `test_unit_clip_selection.gd` Part B's guard is now REPLACED, not extended (`4-3d/R17`, literally applied), with an explicit deletion task, and the behavioural-replacement task's AC tag corrected from 1 to 5. `sprint-status.yaml`'s "Former AC6" corrected to "Former AC 2". The runner-loop enumeration corrected from four to five loops, adding `_gather_unit_facts`. All nine guards this story proposes now name a mutation that must turn them red. Minors: `4-3d/R12`'s "neither number is stated anywhere in the story" corrected by append-only annotation (both numbers appear in withdrawal context); the `4-3d/R8` pointer relocated to sit immediately after its own entry; stale inbound `4-3d` AC references in `4-3c-minion-rig-adoption.md` (`:622`, `:852`, `:890`) and `sprint-status.yaml:112` corrected to current numbering; the dropped `4-3d/R9` citation-correction note restored to Dev Notes; the headless-script measurement method restored to the clip-length task; AC 2's walk-through guard restated as its own falsifiable effect rather than delegated to AC 4. Status stays `authored`, board stays `backlog` — promotion is the operator's act. No code touched — docs only. |
| 2026-08-26 | Claude Sonnet 5 | FIFTH READINESS GATE FIX PASS, third docs-only correction pass (`4-3d/R20`, decision-log Session 2026-08-26, "4-3d fifth readiness gate, fix pass" — 1 blocking, 5 major, 8 minor findings applied). BLOCKING: the STOP CONDITION's upper bound (`r <= 2.0`) was invented, not derived; REMOVED. The dev pass now stops only if `r < 1.0` (`T < 0.9 s`), derived from `4-3d/R11`'s accepted consequence; no upper stop is derivable, and none is needed — the mechanism is self-bounding (latest possible `T = 2.6667 s` gives `r = 2.963`, effective duration `0.9 s`). Above `r = 1.0` the dev pass proceeds and records `T`, `r`, effective duration, and which artefact results (`4-3d/R20`, amending `4-3d/R19`'s trigger the same way `4-3d/R19` amended `4-3d/R14`'s). Live Smoke gains one bullet covering both branches of the corrected arithmetic (truncation vs held final pose, whichever the measured rate produces), citing `4-3c-minion-rig-adoption.md:850-852` and `:890`; AC 1 `:98-99` no longer frames the held-pose branch as costless. The mutation table is now labelled PROVISIONAL with an explicit re-derivation obligation on the dev pass. AC 5's guard gains an implementing task, with `N` bound to AC 2/3's already-bound retention count (N+599). The walk-through observable moves from AC 2 to AC 4 (the mechanism that produces it, per `4-3d/R16`'s own independent-falsifiability standard); AC 2 retains retention as its own content; mutation 3 updated to serve AC 4. Minors: AC 1 `:129`'s withdrawal paragraph corrected — it no longer claims no rate figure is stated anywhere; the derived break-even `r = 1.40` is legitimate and distinct from the WITHDRAWN circulated band; `4-3d/R14`'s pointer's self-contradictory "referenced above" corrected to "referenced below"; `4-3d/R8`'s pointer now uses the canonical "The entry above" wording; `4-3d/R12`'s correction relocated out of the third-pass session block into this pass's own; mutation 1 now states the tolerance that must fail it; mutation 6 marked dependent on AC 4's own deferred per-node measurement; `4-3c-minion-rig-adoption.md:628-629` and its `:890` Change Log row — edited beyond a stale AC number by the fourth pass — REVERTED to original wording, with an appended annotation and a new `4-3c` Change Log row recording the revert; `4-3c1-swing-commitment.md:347` and `:530` (stale `4-3d AC 5` references) corrected to `AC 1`, and a third stale instance in `sprint-status.yaml:112` itself, missed by the fourth pass's sweep, also corrected. Status stays `authored`, board stays `backlog` — promotion is the operator's act. No code touched — docs only. |
| 2026-08-26 | Claude Opus 5 (1M context) | MICRO-EDIT, docs-only, three items (no fix pass, no findings applied). (1) Five `4-3c` coordinates re-resolved by content search, all stale by +4 because this cycle's own `4-3c:631-634` annotation lengthened that file: the Live Smoke bullet's `:850-852` -> `:853-857` and `:890` -> `:894` (`:890` is the `2026-08-14` readiness-gate row, a DIFFERENT row that also contains the string "AC 5" and would have read as a plausible hit), AC 1's `:850` -> `:853-857`, and the decision-log fifth-pass block's copies of both. Each citing sentence now quotes enough anchor text to self-heal on the next shift ("CONSEQUENCE, stated plainly and NOT fixed here"; "the `_select` dedup held the finished clip's final pose for ~9.7s"). One instance is NOT corrected and is carried: `4-3c-minion-rig-adoption.md`'s own new Change Log row cites `:852` where the anchor now sits at `:856` — correcting it requires editing `4-3c`, outside this edit's authorised file list. (2) The last orphaned walk-through attribution — Live Smoke's compound "falls, stays down… and the operator can walk through it (AC 2)" — re-tagged: retention stays AC 2/3, the walk-through observable is tagged AC 4, where `4-3d/R16` moved it this cycle. A full grep confirms no other surviving `(AC: 2)` or prose attribution of walk-through outside historical Change Log rows. (3) The unnumbered correction to `4-3d/R12` is NUMBERED `4-3d/R21` (text and location unchanged, its fourth-pass authorship stated in the entry), and `4-3d/R12` gains a one-line pointer to it in the canonical decision-log `:899`/`:903` form — a reader arriving at `4-3d/R12` now sees that it was corrected. `4-3d/R12`'s own text untouched; the log stays append-only apart from two in-place forward corrections of this same session's own coordinates. Status stays `authored`, board stays `backlog`. No code touched — docs only; nothing staged, nothing committed. |
| 2026-08-26 | Claude Opus 5 (1M context) | DEV PASS. AC 1's strike frame MEASURED headlessly (`tools/measure_strike_frame.gd`, added): `T = 1.3000 s`, frame 39 of 80, from the LEFT hand's forward extension relative to the hips -- explicitly not the hips-displacement peak, which the same tool puts at `1.4333 s`, four clip frames later (confirming `4-3d/R13`, and the provenance of `4-3d/R12`'s withdrawn band: `1.4333 / 0.9 = 1.5926`). `r = 1.4444 >= 1.0`, so the `4-3d/R20` STOP CONDITION did not trigger; effective duration `1.8462 s` against the 1.9 s cycle, i.e. the HELD-FINAL-POSE branch at `0.0538 s` (3.2 ticks) per chained swing, with the `4-3c` truncation closed as a side effect (`4-3d/R15`'s subordinate outcome, not a claimed goal). Mechanism: per-clip `play(clip, -1.0, rate)` custom speed on `attack` only, never `speed_scale`. Corpse lifecycle shipped: tick-counted 600-tick linger owned by `UnitActor`, freed at N+600 and valid at N+599 (measured exactly), collision disabled on all three nodes from a `call_deferred` seat. AC 4's ENGINE-BEHAVIOUR ASSUMPTION MEASURED FALSE: running the disable inline from `_physics_process` emits NO `^ERROR:` line on 4.6.3 -- the deferral shipped anyway because AC 4 requires the seat and only its rationale was wrong; the rationale is corrected in place and flagged for a ruling. AC 5's guard is the BONE POSE, not the playback position (a non-looping clip's `current_animation_position` returns 0 after its end -- measured; the AC's literal wording could never pass). `4-3d/R17` discharged: `test_unit_clip_selection.gd` Part B's source-order assertion DELETED, replaced behaviourally in `test_unit_corpse_linger_live.gd`, and the replacement turns RED on the ordering mutation with the right diagnostic. `test_unit_combat_live.gd`'s AC 11 assertion, invalidated by the linger, corrected. The provisional nine-row mutation table REPLACED by a measured one: 1, 2, 3, 4a, 4b, 6, 7, 8, 9 all RED and restored-by-SHA; mutation 5's premise does not hold at the shipped seat (there is no parallel array) and collapses into 7; provisional mutation 4 was mis-derived and came back GREEN, so the guard gained an independent ticking-frame count (4a) and 4b was added. Golden UNMOVED `4a089063` both directions; state harness `499/3895/0` unmoved, run twice before and twice after; integration 37 -> 40 all PASS; `project.godot` byte-identical `8879de49`, 60-tick pin intact, editor never opened; zero orphaned godot processes. Status `authored` -> `review`; board stays `ready-for-dev` (CFG/R2). Nothing staged, nothing committed, nothing pushed. |
| 2026-08-26 | Claude Opus 5 (1M context) | REVIEW FIX PASS (docs and tests only, no `src/` touched). BLOCKING finding applied: Completion Note 4's "`current_animation_position` returns 0 after a non-looping clip ends" is MEASURED FALSE -- re-measured independently, twice, position stays PINNED at the clip's own length (`4.6000` for `death`), only `current_animation` clears to `""`. Corrected in place (annotated, not silently deleted) in Completion Note 4 and in `test_unit_corpse_linger_live.gd`'s header; the shipped BONE-POSE guard does not change -- it is the stronger claim, not a workaround for an unimplementable one. (The reviewer's own report had named a third instance in `test_unit_clip_selection.gd`; re-checked by content search and that file does not carry the claim -- the report was wrong on that one location.) Non-blocking finding 2 applied: `test_unit_corpse_walkthrough_live.gd`'s `_facts_total_after_death` counter was claimed to pair against the zero-facts assertion but was never read in `_report()`; measured (debug print, reverted) that in this file's own scenario the counter is always 0 regardless of whether the recorder query is honest -- no pairing is possible here, so the counter and its claim are DELETED rather than kept beside a guard that was never there. Non-blocking finding 7 applied: `measure_strike_frame.gd`'s `hips_idx` now validated like the `PROBES` loop beside it (`push_error`/`quit(1)` on a missing bone). Findings 3/4/5/6 NOT fixed, recorded as named deferred observations in Dev Notes (the one-frame collision-disable window as a timing assumption, the Hips-only pose guard, the no-revival-guard-rail gap, and the seconds-vs-tick-rounded alignment-target coupling). Full suite re-run after edits: `499 tests, 0 failed, 3895 assertions`, 40 integration files, `ALL TESTS PASSED`, no `^ERROR:`/`SCRIPT ERROR` lines. The three touched live tests re-run individually, all PASS. The walkthrough test's mutation (`$Collision.disabled = true` deleted from `UnitActor.disable_all_collision()`) re-run after the edit and confirmed still RED for the same reason (`_passed_corpse` false, hero blocked by the corpse) -- the counter deletion did not touch that assertion's mutation. Status stays `review`, board stays `ready-for-dev`. Nothing staged, nothing committed, nothing pushed, editor never opened. |
