---
baseline_commit: f009dd553b25a7a6045750ba1393499d1a4ea7cc
---

# Story 4.3d: Minion strike alignment and corpse lifecycle

Status: authored

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

- [ ] Re-confirm `attack.fbx`'s real clip length (2.6667 s, already measured in `4-3c`) via the same
      headless-script method used for the Hips-track table, from the imported library, before applying
      any rate (AC: 1)
- [ ] Measure which frame carries the visible claw-strike pose; record as a timestamp/frame number
      in Dev Notes; check the REOPEN CONDITION before proceeding (AC: 1)
- [ ] Compute the custom `AnimationPlayer` rate from the measured strike frame and apply it; guard the
      EFFECT — the clip's playback position at the moment the ACTIVE window opens — not the rate value
      or the clip name (AC: 1)
- [ ] Change `_free_dead_unit_actors`'s seat: on first observing alive-to-dead, start a tick-counted
      linger timer living ON THE ACTOR (not a parallel runner array); free the actor once it reaches
      10 s (600 ticks at 60 Hz) (AC: 2, 3)
- [ ] Guard retention as an effect: the corpse actor is still `is_instance_valid` at tick N+599 and
      null at N+600 (a tick count, not a timer-field read) (AC: 2, 3)
- [ ] Guard walkthrough as an effect: a hero driven into the corpse's position ends up past it
      (a position delta), not a collision-layer property read (AC: 4)
- [ ] Guard the paused step-through as an effect: advance real frames while `_paused`, assert the
      corpse survives AND its tick counter did not move (AC: 3)
- [ ] Guard the debug reset as an effect: corpse count is 0 after `round_started`, and no orphaned
      node is left in the tree (AC: 3)
- [ ] Disable `Collision`, `Hurtbox`, and `Hitbox` together, from a seat OUTSIDE any physics callback
      (deferred or otherwise), the instant death is first observed; run once inline first to observe
      the engine's `^ERROR:` behaviour, then move to the deferred seat; confirm the tightened
      `^ERROR:`-failing test harness stays clean (AC: 4)
- [ ] Guard collision-disabled as an effect: the hero hitbox's `get_overlapping_areas()` returns EMPTY
      against a corpse, and the recorder's contact channel for that tick is empty (AC: 4)
- [ ] Guard the death-clip hold as an effect: from the clip's end through tick N+599 (reusing AC 2/3's
      already-bound retention count), the corpse's `AnimationPlayer` playback position stays pinned at
      the clip's end and no other clip is selected in that span (AC: 5)
- [ ] DELETE `test_unit_clip_selection.gd` Part B's inherited `push_line < gate_line` source-order/
      indentation assertion — `4-3d/R17` REPLACES it, does not extend it (AC: 5, `4-3d/R17`)
- [ ] Write the behavioural replacement for Part B, in Part A's shape
      (`_assert_clip_content_changes`, effect-based): a corpse frozen in a half-raised claw versus one
      playing `death`, the effect the deleted assertion could not see (AC: 5, `4-3d/R17`)
- [ ] Correct the two shipped comments (`match_state.gd:744-747`, `match_runner.gd:1083-1084`) to match
      the new lifecycle; confirm no other `src/state/` line changes (collateral)
- [ ] Confirm the debug-reset relay (`_free_unit_actors`, `match_runner.gd:912-918`, called from
      `_relay_round_started` at `:635`) already frees a lingering corpse with no change — it frees
      every entry in `_unit_actors[slot]` regardless of liveness — by test, not by edit (AC: 3)
- [ ] Write the corrected `death`-net-displacement reasoning into Dev Notes (liveness-gated driving,
      not a round-over freeze) (AC: 5)
- [ ] Measure the golden BOTH directions (before/after); confirm the hash `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf` unmoved (AC: Golden
      Prediction)
- [ ] Measure `project.godot` byte-identity both directions (AC: Golden Prediction)
- [ ] Check for orphaned `godot` processes at the start and end of the dev pass (`4-3b/R31`)

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

### Debug Log References

### Completion Notes List

### File List

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
