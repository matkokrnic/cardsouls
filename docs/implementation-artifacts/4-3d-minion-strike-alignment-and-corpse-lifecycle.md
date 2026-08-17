---
baseline_commit: 1ddff872cdbc677b78d06992c61928b58730d9b6
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

1. **The attack clip is aligned so its visible strike lands at the START of the ACTIVE window.**
   Ruled by the operator, and it is the reason the rig story (`4-3c`) runs before `4-4`
   (`4-3b/R27`). The authored rhythm is `minion_attack_windup_seconds = 0.9`,
   `minion_attack_active_seconds = 0.2`, `minion_attack_recovery_seconds = 0.8`
   (`data/balance/balance_config.tres:37-39`, measured current values — `4-3b/R26`'s cut-form
   retune already moved windup `0.5 -> 0.9`). **Stretching the clip across the whole 1.9 s cycle is
   REJECTED** — that is exactly the failure the operator already found on the hero ("too fast but it
   looks slow", `4-3b`'s own inherited finding from `3-0a`'s hero playtest): the visible swing and
   the real hit window must agree, or the animation lies about when it hits.

   **The clip's actual length has NOT been measured by anyone — the gate could not measure it.
   Corrected at this fix pass (`4-3d/R8`): an earlier estimate of approximately 2.7 s had circulated,
   but that figure no longer appears anywhere in `4-3c` after its own cut, and quoting it as `4-3c`'s
   estimate would be quoting a deleted line. Restated here as this story's own UNVERIFIED figure — not
   a number this story may assume.**
   The dev pass measures `attack.fbx`'s real length first (via the same headless-script method used
   for the Hips-track table), before anything else in this AC proceeds — **which alignment mechanisms
   are even available depends on that measured length** (a clip shorter than the 0.9 s windup cannot
   simply be delayed into the windup and still fit its swing before the active window opens; a clip
   much longer than the 1.9 s full cycle constrains a custom-speed route differently than a clip near
   1.9 s does). The dev pass then measures which frame(s) of the clip carry the visible claw-strike
   pose (by eye, scrubbing the imported clip, recorded as a timestamp or frame number in Dev Notes)
   and aligns clip playback so that frame lands at the first tick of the ACTIVE window
   (`minion_attack_windup_seconds` elapsed after windup starts).

   **OPEN QUESTION for this story's own gate, not decided here:** which alignment mechanism to use.
   Recorded as three options with their consequences, the operator's call:
   - **(a) Custom playback rate on the `AnimationPlayer`** (`AnimationPlayer.speed_scale` or a
     per-clip rate) — stretches or compresses the WHOLE clip (windup pose through follow-through) to
     fit the authored cycle. Consequence: every part of the swing changes speed together, including
     parts that were not the problem; simplest mechanism, one number.
   - **(b) A partial clip range** — plays only the sub-range of the clip that contains windup through
     strike, skipping unused frames. Consequence: recoil/follow-through frames may be cut short or
     dropped; needs the measured clip length to know what is being cut.
   - **(c) An `AnimationPlayer.play()` call with a `custom_speed`/start-offset** — starts playback
     partway into the clip so the strike frame lands where authored timing needs it, without
     necessarily changing speed. Consequence: the pre-strike windup pose the player sees is whatever
     frame the clip happens to be at that offset, which may not read as the beginning of a windup.

   The operator has not yet ruled on which of these he wants; this AC states the requirement (measured
   alignment against real clip content) and the three routes, not the choice.

   **Additional AC 5 input, from `4-3c`'s Live Smoke check (2026-08-15): the readability of the
   ~0.767s end-of-clip truncation has NOT yet been rated by eye** — measured against the 1.9s cycle
   vs the 2.6667s clip, carried here as an open observation, not yet a finding either way.

   **Additional AC 5 input, from `4-3c1`'s Live Smoke check (2026-08-17): the strike/impact mismatch
   is now a felt symptom with a named consequence** — the moment damage lands and the visible strike
   do not coincide, which puts the parry window in a misleading place; this is the evidence AC 5's
   three-way mechanism choice was waiting on, not a new defect.

2. **The corpse stays 10 seconds and the player can walk through it.** Today
   `MatchRunner._free_dead_unit_actors` (`match_runner.gd:682-691`) frees a dead unit's actor the
   SAME tick death is detected — before this story, that is invisible, because there is nothing to see
   fall. This story changes that seat: on first detecting `is_alive_at(index) == false` for a
   previously-live actor, the actor is **not** freed immediately. Instead a **presentation-only
   linger timer** starts; the actor is freed once that timer reaches 10 seconds.

   **The linger is TICK-COUNTED and seated inside the existing tick gate, with its timer living ON
   THE ACTOR — never in a parallel runner-local array.** Two measured reasons, both load-bearing: a
   wall-clock timer keeps running while the game is paused, so a corpse would vanish mid-inspection
   during a paused step-through (`3-0b`'s deterministic step/pause, AC1/AC2, would be visibly broken by
   this story if the linger ignored it); and a parallel runner-local array survives the debug reset
   that clears the actors, which would either leak stale entries or need its own reset-relay wiring a
   per-actor timer does not.

   **Collision is disabled for ALL of the unit's collision nodes, not a subset — `Collision`,
   `Hurtbox`, AND `Hitbox` together.** Measured at the gate: leaving the `Hurtbox` live writes facts
   into the intent RECORDING that no tick consumes (`3-0c`'s recorder taps the contact channel BEFORE
   this seam runs), which corrupts the record with dead-actor noise a replay never asked for. **The
   disable is DEFERRED to a seat outside any physics callback, not applied inline** where death is
   first observed: changing collision flags from inside a physics callback makes the engine emit an
   error line, and `4-3b`'s own review-fix pass tightened the test harness to fail the suite on any
   `^ERROR:` line — an inline disable would break the harness it must run under. The dev pass finds
   the correct non-callback seat (e.g. deferred via `call_deferred`, or moved to a seat that already
   runs outside physics callbacks) and records which one and why.

   **The `death` clip (loop disabled, `4-3c` AC 3) plays once and holds its final pose for the
   remainder of the 10 s**, on the `3-0a/R5` clip-end/mid-clip policy already cited above (What this
   story inherits) — applied verbatim, not re-cited under a different number here.

   **The clip's net displacement is ACCEPTED, but NOT on `4-3c`'s own cited reasoning — that
   reasoning was hero-specific and does not transfer.** `3-0a`/R9 accepted the hero's `death` topple
   because `_end_round()` freezes BOTH heroes' velocity for the remainder of the round, so nothing
   competes with the clip's own translation — a minion dying does NOT end the round, so that argument
   does not apply here. **The correct reason, measured by the gate:** `_approach_unit_actors`
   (`match_runner.gd:770`) already gates on `is_alive_at`, so a dead unit is NEVER driven by
   `UnitActor.approach()` again — nothing ever calls `move_and_slide()` on a dead unit's actor, so
   there is nothing for the `death` clip's own translation to compete with, for the same structural
   reason as the hero's case but reached by a different path (liveness-gated driving, not a
   round-over freeze). This is the reason the dev pass writes into Dev Notes; the `3-0a`/R9 citation
   from `4-3c`'s own authoring pass is corrected, not inherited.

   **Two shipped comments assert the invariant this AC breaks, both must be corrected as collateral,
   named rather than left to silently disagree with the code.**
   - `src/state/match_state.gd:744-747` — `_advance_unit_attacks`'s header comment: "A DEAD UNIT IS
     SKIPPED ENTIRELY… Nothing gathers a corpse's hitbox (the runner frees its actor the same tick)."
     This is `src/state/`, and the dev pass's own scope statement below says this story makes NO
     behavioural change under `src/state/` — the comment is corrected in place (the actor is no
     longer freed the same tick; the hitbox is inert because collision is disabled, not because the
     actor is gone) with no other line in the file touched.
   - `src/main/match_runner.gd:975-978` — the aim-pass mutation-shape comment: "a corpse's actor is
     freed after `advance()`, but a unit killed between gathers must not still be swinging." Corrected
     to state that a corpse's actor now LINGERS rather than being freed after `advance()`, with the
     rest of the sentence (why a mid-gather kill must not still swing) left standing — that reasoning
     is unaffected by the linger.

   **Scope statement, corrected from a blanket "no `src/state/` change" to what is actually true:**
   **no BEHAVIOURAL change under `src/state/`; one comment corrected** (`match_state.gd:744-747`,
   above). `UnitBoard`'s record for that index, and the index itself, remain UNCHANGED by this story
   — the board record and its permanently-unrecycled index (`UnitBoard.add()` only ever grows,
   `unit_board.gd`, `4-3a`'s own shipped precedent) already outlive the actor today; this story only
   delays when the ACTOR catches up to that fact, and corrects one comment that described the old
   timing.

## Non-Goals (explicit)

- **Any BalanceConfig field for the linger duration.** 10 seconds is fixed by this AC, not authored —
  the same "adoption/lifecycle mechanism, not a tuning pass" posture `4-3c` took for the idle/walk
  epsilon.
- **Object pooling for the linger.** `4-5`'s tier (`4-1` close-out, `E4-P/R8`) is unaffected; this
  story still plain-instantiates and `queue_free()`s.
- **Per-kind alignment or per-kind linger duration.** One shared mechanism, on the same "minions run
  one shared set of scalars" posture `4-3b`/`4-3c` both took; per-kind conversion is `4-4`'s opening
  act.
- **Deciding the AC 1 alignment mechanism.** Recorded as an Open Question for this story's own gate,
  per AC 1 — not decided in this authoring pass.

## Tasks / Subtasks

- [ ] Measure `attack.fbx`'s real clip length via the headless-script method (AC: 1)
- [ ] Measure which frame(s) carry the visible claw-strike pose; record as a timestamp/frame number
      in Dev Notes (AC: 1)
- [ ] Bring the AC 1 mechanism choice (custom rate / partial range / custom-speed start-offset) to the
      operator as this story's own gate Open Question; implement the ruled choice (AC: 1)
- [ ] Change `_free_dead_unit_actors`'s seat: on first observing alive-to-dead, start a tick-counted
      linger timer living ON THE ACTOR (not a parallel runner array); free the actor once it reaches
      10 s (600 ticks at 60 Hz); confirm the timer respects the debug pause and is cleared by the
      debug reset (AC: 2)
- [ ] Disable `Collision`, `Hurtbox`, and `Hitbox` together, from a seat OUTSIDE any physics callback
      (deferred or otherwise), the instant death is first observed; confirm the tightened
      `^ERROR:`-failing test harness stays clean (AC: 2)
- [ ] Correct the two shipped comments (`match_state.gd:744-747`, `match_runner.gd:975-978`) to match
      the new lifecycle; confirm no other `src/state/` line changes (AC: 2)
- [ ] Write the corrected `death`-net-displacement reasoning into Dev Notes (liveness-gated driving,
      not a round-over freeze) (AC: 2)
- [ ] Measure the golden BOTH directions (before/after); confirm the hash unmoved (AC: Golden
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
- **The four runner loops this story reaches, measured.** `_free_dead_unit_actors` (the linger
  itself); `_aim_unit_actors` (now sees a lingering corpse, guarded by `4-3c`'s gate); `_approach_unit_actors`
  (already gates on `is_alive_at`, `match_runner.gd:770` — confirmed a NO-OP for a corpse, which is
  the basis of the corrected `death`-displacement reasoning above); and the debug-reset relay that
  frees all actors on `round_started` (must free a lingering corpse too, not just live units — confirm
  by test).
- **Collision-disable seat, to be measured and recorded by the dev pass.** Godot raises an engine
  error when collision shape/monitoring flags are changed from inside a physics callback
  (`_physics_process`, `_integrate_forces`, or a signal fired from one) — **citation corrected at this
  fix pass (`4-3d/R9`): `4-3b/R31` is the orphaned-`godot`-process ruling, not this one.** The real
  citation is the harness itself, `test/run_all.sh`, tightened by `4-3b`'s review-fix pass to fail on
  any `^ERROR:` line — this is not a cosmetic warning, it is a suite-failing condition. The exact
  deferred seat (a `call_deferred` call
  from within `_free_dead_unit_actors`, or moving the disable to a seat that already runs outside the
  physics callback chain) is a dev-pass measurement, not fixed here.
- **Golden Prediction reasoning, stated rather than assumed.** Like `4-3c`, this story touches no
  `src/state/` field and adds no `BalanceConfig`/snapshot field — its one `src/state/` edit is a
  comment correction, not a behavioural change. `test/state/test_determinism.gd` runs `MatchState`
  alone with no runner, no physics, and no actor, so nothing here is reachable from that fixture.
  **Predicted UNMOVED — to be MEASURED IN BOTH DIRECTIONS at the dev pass.**

### Project Structure Notes

- `src/main/match_runner.gd` — `_free_dead_unit_actors` gains the linger + deferred collision-disable
  (AC 2); its mutation-shape comment near `_aim_unit_actors` (`975-978`) corrected.
- `src/actors/minions/unit_actor.gd` or `unit_actor.tscn` — wherever the dev pass seats the per-actor
  linger timer (AC 2).
- `src/actors/minions/` — the `4-3c` presentation controller's `AnimationPlayer` call for the attack
  clip gains the AC 1 alignment mechanism.
- `src/state/match_state.gd` — ONE comment corrected (`744-747`); no behavioural line changes.

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
  liveness gate (`4-3c/R4`) this story depends on, and the "AC 5 and AC 6 are CUT" note]
- [Source: decision-log.md Session 2026-08-14 — `4-3c/R2` (the cut, ratified), and every
  `4-3d`-bound ruling recorded there]
- [Source: docs/implementation-artifacts/3-0a-rig-adoption.md — AC5 clip-end/mid-clip policy;
  `3-0a`/R9 death-topple acceptance (hero-specific reasoning, corrected for this story)]
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md — AC1/AC2 deterministic
  step/pause; the clip-retime precedent (`tools/retime_clips.gd`) as the class of work this AC 1
  belongs to]
- [Source: src/main/match_runner.gd:682-691 (`_free_dead_unit_actors`), 754-782
  (`_approach_unit_actors`, the `is_alive_at` gate at line 770), 975-978 (the comment to correct)]
- [Source: src/state/match_state.gd:744-747 (the comment to correct)]
- [Source: data/balance/balance_config.tres:37-39 (authored attack-rhythm durations)]
- [Source: docs/project-context.md — F1, HARD RULE state/visual separation]

## Golden Prediction

**Predicted UNMOVED, measured in BOTH directions at the dev pass.** This story's one `src/state/`
edit is a comment correction with no behavioural change; it adds no `BalanceConfig`/`BalanceTicks`
field and writes no `MatchState`/`UnitBoard`/`PlayerState` snapshot field. `test/state/test_determinism.gd`
runs `MatchState` alone with no runner, no physics, and no actor, so nothing this story ships is
reachable from that fixture.

**`project.godot` byte-identity is ALSO measured in both directions**, on the `3-0a`/R3 protocol this
project applies to every story that opens the editor.

## Live Smoke

**REQUIRED**, Tier A default (this story ships player-facing timing and lifecycle behaviour for a
live-killable actor class). No `.tscn` flip needed — the shipped default (`slot_controller_kinds =
[0, 1]`) already gives two live human slots.

- The **visible strike lands when the damage lands**, not visibly before or after (AC 1's alignment,
  judged live, not only by the recorded frame number).
- The **corpse falls, stays down for about ten seconds, and the operator can walk through it** (AC 2)
  — confirm nothing blocks him and nothing looks like it snapped back to standing.
- **Paused step-through**: with the debug pause held, confirm a lingering corpse does NOT vanish or
  advance while the game is paused (the tick-counted timer, not wall-clock).
- **Debug reset**: confirm a lingering corpse is cleared by the debug reset along with everything
  else, not left behind as an orphaned node.

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
