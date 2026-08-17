---
baseline_commit: 09ee13a7a5b408ff2b6d4d22b3764b3628092127
---

# Story 4.3c1: Swing commitment (minions rooted during their own attack)

Status: review

## What this story inherits

This story implements decision-log ruling `4-3c/R19` (Session 2026-08-15, "4-3c live smoke, yaw
convention and rooting-during-swing scope"): **units are ROOTED during their own swing, mirroring
the hero.** The ruling itself is explicit that it was recorded with **NO slot granted** — its own
closing line reads "This ruling TOUCHES `src/state/match_state.gd` and MOVES THE GOLDEN — it is NOT
`4-3c` and NOT `4-3d`; it needs its own story and slot, NONE granted here." **No slot existed for
this work until the operator granted one on 2026-08-16 — this story IS that slot.** Nothing about
this work was already scheduled or implied to be assigned; it is being opened for the first time
here.

The ruling's own measurements, carried forward verbatim rather than re-derived:

- **Nothing currently gates unit movement on attack phase.** Neither `_approach_unit_actors`
  (`src/main/match_runner.gd:795-856`) nor `UnitActor.approach()`
  (`src/actors/minions/unit_actor.gd:143-151`) reads `attack_phase_at`. Measured max speed on a
  non-IDLE tick is the full authored `unit_move_speed` (3.0) — a unit can be mid-swing and still
  moving at full speed today.
- **The hero is already rooted, and this story mirrors that shape.** `match_state.gd:1713`/`:1715`
  scales the hero's velocity by `_attack_phase_multiplier()` (`match_state.gd:1738-1745`), reading
  one of three `BalanceConfig` fields selected by `HeroState.attack_phase()`. Those three hero
  fields are authored 0.0 at `data/balance/balance_config.tres:21-23`
  (`attack_windup_move_speed_multiplier`, `attack_active_move_speed_multiplier`,
  `attack_recovery_move_speed_multiplier`) — full root. Only `attack_lunge_distance` (`:24`, 0.5)
  moves him, as a separate additive velocity term (`_attack_lunge_velocity`, story `3-0b` AC6).
- **A swing that leaves reach mid-flight still COMPLETES, and that is DELIBERATELY KEPT, not
  reopened here.** A unit's swing begins only while in reach (`match_state.gd:775-782`); the phase
  machine that advances it (`match_state.gd:755-774`) runs on tick counters with no reach re-check
  once started. Under a root rule, a target that steps out of reach mid-swing simply eats (or
  dodges) a committed attack that cannot be cancelled — the ruling names this "the correct
  commitment punishment." This story inherits that behavior as already-ratified context; it is not
  this story's decision to make or unmake.
- **Accepted cost, stated plainly by the ruling and restated here: minions become KITEABLE.** A
  player who keeps a minion permanently mid-swing by staying just outside melee range denies it any
  net approach. This is the intended shape of giving units the same commitment the hero has, not an
  overlooked side effect.

## Story

As a player facing summoned minions,
I want a minion to plant its feet the instant it commits to a swing — the same commitment the hero
already carries — rather than sliding toward me at full speed while its claw is raised,
so that a minion's attack reads as a real, punishable commitment instead of a free, costless
approach, and I have room to read and react to it (including by kiting it).

## Acceptance Criteria

Each acceptance criterion below is independently failable on its own named observable — that
independent failability is the rule; the count is a consequence of applying it, not a target in
itself. Lunge (non-goal, see Non-Goals) and the golden/test-impact work (dev-pass tasks, see
Tasks/Subtasks) are deliberately not listed here as ACs — neither is independently failable as a
criterion of this story's outcome; both are still required work, tracked below.

1. **`BalanceConfig` gains three new minion attack-phase move-speed multipliers, distinct from the
   hero's three fields, authored 0.0.** Named observable: loading `data/balance/balance_config.tres`
   exposes three fields following the hero's `attack_<phase>_move_speed_multiplier` convention,
   `minion_`-prefixed, each reading `0.0`. Fails independently if any field is missing, misnamed, or
   non-zero. **Rationale to record in Dev Notes: sharing the hero's three keys would permanently
   couple minion feel to hero feel** — a future hero retune (or the reverse) would silently retune
   minions too, with no way to diverge them later without a migration.
   **BC/R3 answer, stated here rather than left for the dev pass:** these three fields fall under
   `BC/R3` as narrowed by `3-4/R6` — authored `.tres` values never read by `_golden_config`, so they
   are hash-neutral (see Golden Impact). That narrowing does **NOT** mean "no test edit required" —
   see AC 3.

2. **A unit's velocity is scaled by its own attack-phase multiplier while it is WINDUP, ACTIVE, or
   RECOVERY, mirroring the hero's `_attack_phase_multiplier()` shape** — same three-way phase
   selection over the three attacking phases, same "authored 0.0 = full root" semantics, same
   CONSTRAINT C discipline (multiplier read inline at the point of use off the config the runner
   already applied, never cached to a field). **IDLE, and any other non-attacking phase, must return
   `1.0` — full, unmodified speed.** This is the case the story exists to get right: `attack_phase_at`
   is a FOUR-value enum (`match_state.gd:755-774`) — IDLE, WINDUP, ACTIVE, RECOVERY — not a three-way
   split, and a naive mirror of the hero's three-way match with an `_:` catch-all silently maps IDLE
   onto the recovery field (authored `0.0`), rooting every unit permanently, including ones that have
   never attacked. Named observable: at the authored 0.0/0.0/0.0 multipliers, a unit's commanded
   velocity is fully zeroed for the whole swing (WINDUP, ACTIVE, RECOVERY) and is the ordinary,
   unmodified `unit_move_speed` while IDLE. Fails independently if a unit's commanded velocity is
   nonzero during any of the three attacking phases, or is zeroed (or otherwise scaled) while IDLE.
   **Observable is bound to COMMANDED velocity, not raw position** — `approach()` calls
   `move_and_slide()` even at zero velocity (`unit_actor.gd:151`), so bare "position observed to
   change" would fail on depenetration/shoving alone in a crowd, for a reason this story does not
   cause. A unit with NO neighbour in contact must show planar displacement of EXACTLY 0.0 while
   WINDUP/ACTIVE/RECOVERY — that is the machine-assertable observable. **The crowd case is a LIVE
   SMOKE observation, not a machine assertion**: a unit shoved by neighbours while its own commanded
   velocity is zero could in principle depenetrate and move — this is POSSIBLE, not something ever
   observed; `4-3`'s own close-out smoke measured several units on one target with no jitter or
   mutual pushing. No numeric tolerance is bound here for it. Binding it to `STOPPED_EPSILON`
   (`test_unit_approach_live.gd:56`) would import a constant out of a test this story is expected to
   break (see Expected test impact) — ruled out for that reason, not merely undecided (operator,
   2026-08-16).

3. **The two authoring guards for the AC 1 fields are both in place.** Named observable: each of the
   three new fields appears in `E1_BALANCE_FIELDS` (`test/state/test_data_resources.gd:15-72`,
   hand-maintained, NOT automatic — checked by the reflective-completeness guard at `:116-122`); each
   is covered by a minion-side non-negative audit twin of `test_balance_authoring.gd:365`. Fails
   independently if any field is absent from `E1_BALANCE_FIELDS` or unaudited for non-negativity —
   independent of AC 1, since a field can be correctly authored and still ship unaudited.

## Non-Goals (explicit)

- **No lunge for minions.** The hero's `attack_lunge_distance` (`0.5`, `balance_config.tres:24`) is a
  separate, additive velocity term layered on top of the phase multiplier (`_attack_lunge_velocity`,
  `3-0b` AC6) — it is deliberately **NOT** mirrored here. A lunge would reintroduce committed
  movement during the swing through a different door than the one this story closes. An explicit
  non-goal, not a deferred TODO with no owner — available to a later story if minions read as too
  static without one.
- **Per-kind (per minion type) multipliers or reach values.** One shared set of three scalars, on
  the same "minions run one shared set of scalars" posture `4-3b`/`4-3c` both took; per-kind
  divergence is `4-4`'s opening act, not this story's.
- **Any change to the hero's own three multipliers or lunge.** The hero's fields and behavior are
  untouched; this story only adds a parallel minion-side set.

## Tasks / Subtasks

- [x] Add three `minion_attack_<phase>_move_speed_multiplier` fields to
      `src/state/resources/balance_config.gd`, authored 0.0/0.0/0.0 in
      `data/balance/balance_config.tres` (AC: 1)
- [x] Add the three new fields BY HAND to `E1_BALANCE_FIELDS`
      (`test/state/test_data_resources.gd:15`) — not automatic, the guard is a hand-maintained
      literal (AC: 3)
- [x] Add a minion-side twin of `test_authored_attack_move_speed_multipliers_are_non_negative`
      (`test/state/test_balance_authoring.gd:365`) asserting the three new
      `minion_attack_*_move_speed_multiplier` fields are non-negative (AC: 3)
- [x] Add `unit_attack_phase_multiplier(phase)` to `src/state/match_state.gd`, reading the three new
      minion fields for WINDUP/ACTIVE/RECOVERY and returning `1.0` for IDLE and any other
      non-attacking phase — do NOT implement this as a literal mirror of
      `_attack_phase_multiplier()`'s three-way match with an `_:` catch-all (`:1738-1745`); the
      hero's phase is a three-value set, the unit's `attack_phase_at` is a four-value enum including
      IDLE (`match_state.gd:755-774`), and a literal mirror roots every unit permanently (AC: 2)
- [x] Wire the multiplier in: DECIDED at the `_approach_unit_actors` call site
      (`match_runner.gd:844-845`, which currently passes `balance.unit_move_speed` in
      unconditionally) per CONSTRAINT C — read inline, no cached field — but WRITTEN inside
      `UnitActor.approach()` (`unit_actor.gd:143-151`), which is the only place a unit's velocity is
      set (the velocity write and the `move_and_slide()` call at `:150-151`) (AC: 2)
- [x] Update the `match_runner.gd:817-838`/`:847-854` "exactly two zeroing paths" comment block to
      name the new third path (through `approach()`, which calls `move_and_slide()`, unlike the
      other two) — do not leave a stale "exactly two" comment in place (AC: 2)
- [x] Add a NEW integration test file proving AC 2 (operator's ruling: a new file, not an extension
      of `test_unit_approach_live.gd` — that file is already an expected casualty this story must
      repair, and bundling "fix the old assertion" with "prove the new behaviour" would hide both;
      `4-3c`'s precedent is `test_unit_attack_retrigger.gd`, which got its own file for the same
      reason). The new file asserts: a unit with NO neighbour in contact shows planar displacement
      of EXACTLY 0.0 across WINDUP/ACTIVE/RECOVERY, and the ordinary, unmodified `unit_move_speed`
      while IDLE. Per `4-3c/R6`'s mutation-proven discipline, it must name and fall to a naive `_:`
      catch-all mirror of `_attack_phase_multiplier()` (`4-3c1/R2`'s whole content) — that mutation
      must turn it RED. Integration baseline moves from 36 to 37 files (AC: 2)
- [x] Confirm no lunge term is added for minions; record the non-goal in Dev Notes (Non-Goal)
- [x] Measure the golden BOTH directions (before/after); identify and name the exact cause(s) of any
      movement (snapshot key, behavioral divergence, or both) — see Golden Impact
- [x] Read each of `test_unit_approach_live.gd`, `test_two_units_converge_live.gd`,
      `test_unit_attack_live.gd`, `test_unit_combat_live.gd`, `test_unit_clip_selection.gd` against
      the new behavior, one by one; fix or extend any that now assert something false — see Expected
      test impact
- [x] Run the full suite; confirm zero `SCRIPT ERROR`/`Parse Error`/`INVARIANT VIOLATED`, and that
      `project.godot` is byte-identical if the editor was opened for `.tres` authoring
- [x] Check for orphaned `godot` processes at the start and end of the dev pass (`4-3b/R31`)

## Dev Notes

- **The seat is RULED (operator, 2026-08-16), not an open question for the dev pass.** A pure
  `unit_attack_phase_multiplier(phase)` function lives in `src/state/match_state.gd`, mirroring the
  shape of `_attack_phase_multiplier()` (`match_state.gd:1738-1745`), and is read INLINE by the
  runner at the point of use, `match_runner.gd:844-845` (CONSTRAINT C — no caching). **Why the hero
  precedent does NOT transfer directly, recorded because it is the point of the ruling:** the hero's
  `velocity` IS hashed state (`hero_state.gd:5-9`), so scaling it at `match_state.gd:1713`/`:1715` is a
  state-internal write — match_state both computes and applies the multiplier for the hero. A unit's
  velocity is actor-owned (`unit_actor.gd:143-151`; no `Vector3` on `UnitBoard`), so `match_state`
  can only ever EXPOSE the rule (a pure function of phase), never APPLY it — the runner is the one
  that reads the exposed value and passes a scaled speed into `UnitActor.approach()`. This is the
  same shape as the contact fact precedent: a derived fact crosses the state/actor seam, ownership of
  the write does not.
- **Golden Impact — read this before touching anything.** The golden run is **state-only**
  (`test_determinism.gd:624`, `_golden_config`) — no `match_runner.gd`, no actors, nothing that
  drives `_physics_process`. `UnitBoard.is_in_reach_at` is set only by a runner-pushed reach probe,
  the push itself being `match_state.gd:1013` (`mark_in_reach_at`); `_approach_unit_actors` never runs in
  that harness at all, and unit position/velocity are actor-owned, never a `Vector3` on `UnitBoard`
  (`unit_board.gd:22-53`). A new `BalanceConfig` field this story adds is therefore **hash-neutral
  by construction** — the same shape `3-4/R6` already established for an authored field nothing in
  the golden's own execution path reads. **Predicted UNMOVED, for that named reason** — not because
  the story is small, and not because of the golden clause (Tier A here comes from touching
  `src/state/`, see below). The dev pass still measures both directions per standing practice; if it
  moves, that is a surprise requiring its own isolated cause, not the expected outcome.
  - `4-3` (approach/collision): golden UNMOVED both directions.
  - `4-3a` (damage/death): golden moved ONCE, one named cause (the unit `hp` snapshot key).
  - `4-3b` (attack rhythm): golden re-baselined once at the dev pass, one named cause (snapshot key
    set twelve -> eighteen); unmoved at re-measurement afterward.
  - `4-3c` (rig adoption): golden UNMOVED, measured both directions.
- **Expected test impact — the measured casualty SET, to be checked one by one, not a single
  prediction.** Any live-integration test that spawns a unit and samples its movement, velocity, or
  animation clip while it can plausibly be mid-swing is in scope for a read-through:
  - `test/integration/test_unit_approach_live.gd` — samples `global_position` tick-over-tick.
    `unit_stop_distance` (1.5) is smaller than `minion_attack_reach_distance` (1.8), a 0.3-unit band
    where a unit can be "in reach" (able to begin windup) while still actively closing. Its assertion
    at `:225` (`absf(distance - _stop_distance) <= _stop_band`) is an EXPECTED FAILURE this story
    causes, near-certain in that band: after this story a unit that begins windup before closing to
    `unit_stop_distance` stops rooted at whatever distance the swing began at, not at the authored
    stop distance — the dev pass must fix this test, not merely read it through.
  - `test/integration/test_two_units_converge_live.gd` — two units converging is exactly the shape
    where one can enter windup before it finishes closing.
  - `test/integration/test_unit_attack_live.gd` — asserts on attack behavior directly; now overlaps
    a phase where velocity is force-zeroed rather than merely unthrottled.
  - `test/integration/test_unit_combat_live.gd` — broader combat scenario, same movement-during-attack
    overlap risk.
  - `test/integration/test_unit_clip_selection.gd` — measured IMMUNE, not at risk, despite sampling
    velocity: `unit_animation_controller.gd:120-123` returns `attack` BEFORE the idle/walk speed
    check ever runs (`:124`), so a rooted unit's zero velocity cannot reach the idle/walk split while
    attacking; the test also drives `on_unit_tick(alive, phase, speed)` synthetically (`:64-65`,
    `:88-90`) rather than observing a live unit's actual velocity, so it never exercises the real
    approach/root interaction at all. No change expected here.
  - An independent sweep of the remaining live-integration suite found nothing else omitted:
    `test_unit_attack_retrigger.gd`, `test_unit_rig_clips.gd`, `test_unit_aim_live.gd`,
    `test_unit_vertical_alignment.gd`, and `test_unit_model_facing.gd` all assert no live unit
    movement, so none are in scope for this change.
  - The two authoring guards above (`E1_BALANCE_FIELDS`, the non-negative audit twin) — test edits,
    not incidental passes.
  Each must be read in full against the new behavior and fixed or confirmed unaffected individually
  — do not assume the set is complete or that any one member needs no change without reading it.
- **This story adds a THIRD velocity-zeroing path, and it is not the same shape as the existing
  two.** `match_runner.gd:817-838` and `:847-854` name and defend EXACTLY TWO skip paths that zero a
  unit's velocity directly (`NO_TARGET_SLOT` and the unresolved-position fall-through), with an
  explicit "THE OTHER THREE SKIPS IN THIS LOOP ARE NOT ON THIS LIST AND MUST NOT BE ADDED TO IT"
  warning in the source comment (`:835-838`) — no test currently asserts the two-path count, so this
  constraint (`4-3c/R5`/`R12`) lives only in that comment. Rooting a unit during its own swing adds a
  **third** zeroing, but it goes through a different door: the zeroed speed is DECIDED at the
  `_approach_unit_actors` call site (`match_runner.gd:844-845`, the point that currently passes
  `balance.unit_move_speed` in unconditionally), per CONSTRAINT C, and then WRITTEN inside
  `UnitActor.approach()` (`unit_actor.gd:143-151`) — the only place a unit's velocity is set. Unlike
  the two comment-listed skip paths, `approach()`'s non-early-return branch DOES call
  `move_and_slide()` (`unit_actor.gd:151`) even when the resulting velocity is zero. The
  dev pass must say this explicitly in its own notes and must update the
  `match_runner.gd:817-838`/`:847-854` comment block to account for the new path — silently leaving
  a stale "exactly two" comment in place while a third exists is itself a defect this story would
  introduce.
- **`4-3c1/R3` inherits `4-3c/R5`/`R12`'s "exactly two velocity-zeroing paths" list, and that
  inherited ruling cites stale coordinates.** `4-3c/R12` (decision-log:7022-7024) cites
  `match_runner.gd:776-777` and `:780` for the two velocity-zeroing writes; measured, those writes
  are at `:839` and `:855` today. The dev pass updating the ruled comment block will meet a ruling
  whose coordinates no longer resolve, and must not silently re-derive them — the mismatch itself
  must be named in the dev pass's own notes, not quietly worked around.
- **`unit_stop_distance` (1.5) vs `minion_attack_reach_distance` (1.8), both authored,
  `data/balance/balance_config.tres:34,40`.** This 0.3-unit gap is the band described above; it is
  pre-existing authored data, not something this story introduces or should retune.

### Project Structure Notes

- `src/state/resources/balance_config.gd` — three new minion phase-multiplier fields (AC 1).
- `data/balance/balance_config.tres` — the three new fields authored 0.0 (AC 1).
- `src/state/match_state.gd` — `unit_attack_phase_multiplier(phase)`, the ruled seat (AC 2); see Dev
  Notes for why the hero precedent does not transfer directly.
- `src/main/match_runner.gd` — `_approach_unit_actors` (`:795-856`) reads the resulting multiplier
  inline at the `UnitActor.approach()` call site, `:844-845` (AC 2).
- `src/actors/minions/unit_actor.gd` — `approach()` (`:143-151`) is where the scaled speed is
  actually written to velocity (AC 2).
- `test/integration/test_unit_approach_live.gd`, `test_two_units_converge_live.gd`,
  `test_unit_attack_live.gd`, `test_unit_combat_live.gd`, `test_unit_clip_selection.gd` — each
  checked against the new behavior, updated if needed — see Expected test impact.
- `test/state/test_data_resources.gd` — `E1_BALANCE_FIELDS` (`:15-72`) is a hand-maintained literal;
  the three new fields must be added to it by hand or the reflective-completeness guard
  (`:116-122`) fails the suite.
- `test/state/test_balance_authoring.gd` — needs a minion-side twin of the non-negative audit
  (`:365`) for the three new fields.

### Project Context Rules

- **CONSTRAINT C — read authored values inline at the point of use, never cached to a field.** The
  minion phase multiplier must be read the same way the hero's is: off the config the runner already
  applied, at the moment velocity is computed. [Source: `match_state.gd:1730-1745` (the hero's
  `_attack_phase_multiplier`, the analogous seat) and `match_runner.gd:796-797` (the runner's own
  CONSTRAINT C citation for the unit-approach seat); CLAUDE.md]
- **D3(b)/A2 — no global RNG / `Time` / `OS` / `Engine` in `src/state/`.** Nothing in this story
  needs any of those; noted as a guardrail since this story does add code to `src/state/`.
  [Source: CLAUDE.md]
- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** This story adds no new tick loop;
  it reads an existing per-tick seat. [Source: CLAUDE.md]
- **The golden clause is decisive (E4-P/R9).** This story is Tier A because it touches
  `src/state/` — not because of story size or how much it feels like a small tuning pass. [Source:
  GDD decision-log, Session 2026-08-07, ruling `E4-P/R9`; CLAUDE.md "Story tiers"]

### References

- [Source: decision-log.md, Session 2026-08-15, `4-3c/R19` — the ruling this story implements,
  verbatim measurements quoted above]
- [Source: `src/state/match_state.gd:1682-1745` — the hero's attack-phase move-speed multiplier
  mechanism (`_attack_phase_multiplier`), the shape this story mirrors]
- [Source: `src/state/match_state.gd:748-782` — `_advance_unit_attacks`, the unit attack-phase
  machine (tick-counter advance, no reach re-check) and the in-reach-gated swing start]
- [Source: `src/main/match_runner.gd:795-856` — `_approach_unit_actors`, where a unit's approach
  speed is currently set unconditionally from `balance.unit_move_speed`]
- [Source: `src/actors/minions/unit_actor.gd:143-151` — `UnitActor.approach()`, speed passed in by
  the caller, no phase awareness of its own]
- [Source: `src/state/unit_board.gd:22-53` — position/velocity stay actor-owned, never a `Vector3`
  in the board; informs the Golden Impact reasoning above]
- [Source: `data/balance/balance_config.tres:21-24` (hero fields), `:33-40` (unit/minion fields)]
- [Source: docs/implementation-artifacts/sprint-status.yaml — story_notes for `4-3`, `4-3a`, `4-3b`,
  `4-3c`, the golden-movement pattern this story's Golden Impact section is measured against]
- [Source: CLAUDE.md — Load-bearing invariants (F1, D3a, D3b/A2), Story tiers, golden clause]
- [Source: GDD decision-log, Session 2026-08-07, `E4-P/R9` — Tier A/B policy and the golden clause]

## Golden Prediction

**Predicted UNMOVED, by construction — not a softened claim.** The golden run is state-only
(`test_determinism.gd:624`, `_golden_config`): no `match_runner.gd`, no actors, `_approach_unit_actors`
never executes, and `is_in_reach_at` is set only by a runner-pushed probe that this harness never
drives. Unit position/velocity are actor-owned, never a `Vector3` on `UnitBoard`. A new
`BalanceConfig` field this story adds is hash-neutral by construction (`3-4/R6`) because nothing on
the golden's execution path reads it. Tier A applies here because this story touches
`src/state/match_state.gd`, per the golden clause's own text (`E4-P/R9`) — not because the golden is
expected to move. The dev pass still measures both directions per standing practice; a measured move
would be a surprise requiring its own isolated, named cause, not the expected result.

`project.godot` byte-identity is measured in both directions if the editor is opened for `.tres`
authoring, on the `3-0a`/R3 protocol this project applies to every story that does.

## Live Smoke

**REQUIRED, Tier A default** (this story ships player-facing combat-feel behavior for a
live-killable actor class, and its accepted cost — kiteable minions — is exactly the kind of thing
that must be felt, not just measured).

- A minion visibly **stops closing distance the instant it begins its swing** and does not resume
  moving until the swing (windup/active/recovery) ends.
- **Kiting reads as intended, not as a bug**: backing away from a minion mid-swing lets the player
  create distance it cannot immediately close, and this should feel like a deliberate tradeoff
  (commitment for the minion, an opening for the player) rather than the minion looking "stuck" or
  broken.
- Several minions attacking simultaneously show no new jitter, sliding, or desync between their
  visible pose and their (lack of) movement.
- The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent
  writes it on the operator's behalf.

## Live Smoke Results

The operator ran the live smoke on 2026-08-17 and wrote `docs/playtest-log.md` by hand (the entry
dated 17.8). **PASSED**: a minion that commits to a swing plants its feet for the whole of it,
ordinary approach movement is unregressed, and the original defect (a minion sliding at full speed
mid-swing) is closed.

**Recorded explicitly as NOT a `4-3c1` defect:** the moment damage lands and the visible strike do
not coincide, which puts the parry window in a misleading place. This is `4-3d` AC 5's live symptom
— the strike/impact alignment work that story already carries as an open question — not something
this story introduces or is responsible for fixing.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-16.
Claude Opus 5 — dev pass, 2026-08-17. Editor never opened; the three `.tres` fields were a textual
edit (Incident #6 protocol).

### Debug Log References

**Measurements, both directions. State harness and each integration file in its own process.**

| Measurement | Before | After |
|---|---|---|
| State harness | 497 tests / 3878 assertions / 0 failed | **499 / 3895 / 0** |
| Integration files | 36, all PASS | **37, all PASS** |
| Golden | `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf` | **UNMOVED, same hash** |
| `project.godot` | — | **byte-identical (`git diff` empty), `physics_ticks_per_second=60` present** |
| Orphaned `godot` processes | none | none |

The state counts MOVED BY TWO TESTS AND SEVENTEEN ASSERTIONS overall, with three named causes, all
of them this story's own required work: the AC 3 non-negative audit twin (+1 test) and the three new
`E1_BALANCE_FIELDS` entries (which the two-assertion existence/non-negativity loop and the
reflective guard both walk) account for +1 test / +13 assertions at the dev pass; the follow-up pass
then added `test_match_state.gd::test_unit_attack_phase_multiplier_selects_the_right_field`
(+1 test / +4 assertions, mutation-proven), closing Completion Note 6's named gap. No behavioural
cause. **The golden did NOT move**, exactly as the
Golden Prediction said and for the reason it named — the golden run is state-only,
`_approach_unit_actors` never executes there, and the three new authored fields are hash-neutral
per `3-4/R6`. No re-baseline; `test_determinism.gd`'s `GOLDEN` constant is untouched.

**MUTATION TABLE — provenance MEASURED, not reasoned.**

| Mutation | Applied to | Expected | Observed |
|---|---|---|---|
| Replace the explicit `IDLE -> 1.0` arm of `unit_attack_phase_multiplier()` with a naive `_:` catch-all returning `minion_attack_recovery_move_speed_multiplier` — a literal mirror of the hero's `_attack_phase_multiplier()`, i.e. exactly `4-3c1/R2`'s content | `src/state/match_state.gd` | `test_unit_swing_root_live.gd` RED | **RED**, two named messages: `IDLE_NOT_MOVING: worst IDLE tick deviated 0.050000 from the authored unit_move_speed travel of 0.050000 — IDLE must return 1.0 (4-3c1/R2), never a phase field` and `PHASE_NEVER_OBSERVED(WINDUP/ACTIVE/RECOVERY): 0 stable pairs, need 5` — the unit was rooted from spawn, so it never closed to reach and never swung at all |

Restore protocol followed: `src/state/match_state.gd` was copied to a scratchpad OUTSIDE the repo
and SHA256'd (`58d4ed58800a8a125fa9459835933db0d0175c2cde5ee5d0300e2f99c406ee16`) BEFORE the
mutation, and restored by COPY-BACK, never `git checkout --`. Post-restore SHA256 re-measured and
identical.

**Green baseline for the same file:** `windup=53/0.000000 active=11/0.000000 recovery=5/0.000000`
stable pairs / worst per-tick planar displacement, `idle_pairs=123 idle_worst_dev=0.000000`,
`contacts=0`. The displacement is EXACTLY `0.000000` in all three attacking phases, as AC 2 asks —
not a small number under a tolerance.

### Completion Notes List

**1. THREE FINDINGS THE STORY DID NOT PREDICT. All three are for the decision-log, as rulings, at
the operator's discretion — none is written into the story's AC or Dev Notes text.**

**(a) `test_unit_approach_live.gd:225` DID NOT FAIL. The story's "EXPECTED FAILURE, near-certain"
prediction is measured WRONG, and the mechanism is now known.** The test passes untouched, before
and after, with `at_authored_distance=true` and the unit parked within `_stop_band` (0.08) of the
authored `unit_stop_distance` (1.5). The cause is the reach probe's THROTTLE, which the story's
band analysis did not account for: `_push_reach_probe` fires only when
`_probe_counter % minion_retarget_interval_ticks == 0` (`match_runner.gd:1115`), i.e. every 12
ticks at the authored 0.2 s. A unit closing at 0.05/tick covers **0.6 units between probes**, which
is twice the width of the 0.3-unit band between `unit_stop_distance` (1.5) and
`minion_attack_reach_distance` (1.8). With the shipped spawn geometry no probe lands inside that
band: the unit closes past it un-probed, halts at 1.5 by the pre-existing stop rule, and only then
is found in reach — so it begins its swing **already parked at the authored distance**, and rooting
changes nothing it does. Nothing was changed in that file: it still asserts exactly what it was
written to prove, and it is still true. **THE FRAGILITY IS THE FINDING, NOT THE PASS:** this holds
because of where the probe phase happens to land relative to the shipped spawn distance. A probe
that did land inside the band would root the unit at up to 1.8 and turn `:225` red, so a retune of
`unit_move_speed`, `minion_retarget_interval_seconds`, `unit_stop_distance`,
`minion_attack_reach_distance`, or a change of spawn position could flip it. Flagged for a ruling;
NOT hardened here, because hardening it is a scope decision and the measurement says no repair is
owed.

**(b) A GUARD THE STORY DID NOT NAME WENT RED, and fixing it widened a ruled derivation rule.**
`test_intent_recorder.gd::test_every_match_state_intake_has_a_capture_channel` pins MatchState's
public intake surface by set equality and derives "intake" as *any public method taking at least
one parameter*. `unit_attack_phase_multiplier(phase)` is public BY RULING (`4-3c1/R1` — a unit's
velocity is actor-owned, so the runner must read the rule at the point of use) and takes a
parameter, so the guard claimed it as a tenth intake and demanded a
`capture_unit_attack_phase_multiplier` channel. It is not an intake: it is a **pure query**, a
function of its argument alone, returning a float and writing nothing, and a replay that reproduces
the inputs reproduces the phase and hence the return value. Handled as a **second named exemption**
(`EXEMPT_PURE_QUERY`) beside the existing `drain_signals` one, with its reason recorded in the
source, rather than by loosening the parameter proxy into "returns void" — so every future
parameterised method still lands in `intakes` by default and has to be argued out one at a time.
This is a widening of a ruled guard's derivation rule and wants a decision-log entry.

**(c) `4-3c/R12`'s CITED COORDINATES ARE STALE, named here rather than silently re-derived, as
`4-3c1/R3` requires.** `4-3c/R12` (decision-log:7022-7024) cites `match_runner.gd:776-777` and
`:780` for the two velocity-zeroing writes. Measured at this pass, before any edit of mine, those
two writes were at `:839` and `:855`. The two writes are identified by WHAT THEY ARE, not by
coordinates that drift as the comment block grows around them: the `NO_TARGET_SLOT` skip (the first
of the two SKIP paths, `unit.velocity = Vector3.ZERO` immediately before its `continue`) and the
unresolved-position fall-through (the second SKIP path, the same zeroing reached when
`_target_world_position` returns null rather than a `Vector3`). Measured again on this date
(2026-08-17), after the comment block grew to record the new third path, the same two writes now sit
at `:856` and `:888` — coordinates are given here as a measurement of the moment, not as the
identifying fact; the mismatch itself, and that it will recur, is recorded in the source comment as
well as here.

**2. The three ruled constraints, each discharged.** `4-3c1/R1` — `unit_attack_phase_multiplier()`
is a pure function in `src/state/match_state.gd`, read INLINE by the runner at the
`UnitActor.approach()` call site with no caching to any field on either side (CONSTRAINT C);
`match_state` never applies it, the runner folds it into the speed argument and `UnitActor` owns
the write. `4-3c1/R2` — IDLE returns `1.0` from an explicit default arm that is NOT a field lookup;
only the three attacking enum values select a field; mutation-proven above. `4-3c1/R3` — the
`match_runner.gd` comment block is updated in this same pass to record that a THIRD zeroing now
exists and why it is deliberately not a third member of the two-SKIP-path list (it does not skip;
it drives the unit at a speed that happens to be zero, and unlike both listed paths it DOES call
`move_and_slide()`).

**3. Signature note.** The seat takes `phase: int`, not `phase: UnitBoard.AttackPhase`, on the
project's own existing convention for carrying this enum across a call boundary
(`UnitBoard.attack_phase_at() -> int`, `UnitAnimationController.on_unit_tick(phase: int)`). The
arms compare against the named enum values, so the domain is still stated. This is not the
signature change the escalation clause contemplated — the IDLE case did not force anything.

**4. The casualty set, read one by one.** `test_unit_approach_live.gd` — **unchanged**, passes,
see finding (a) for the measured reason its predicted failure did not occur.
`test_two_units_converge_live.gd` — **unchanged**, passes; same throttle mechanism, both units halt
at the stop distance before a probe finds them in reach. `test_unit_attack_live.gd` — **unchanged**,
passes; it pins gather ORDER and attack bookkeeping, and a rooted attacker changes neither.
`test_unit_combat_live.gd` — **unchanged**, passes. `test_unit_clip_selection.gd` — **unchanged**,
passes; the story's IMMUNE prediction is the one that held, for the reason it gave (the controller
returns `attack` before the idle/walk speed split is ever reached, and the test drives
`on_unit_tick` synthetically). All 37 integration files were then run individually to confirm no
sixth casualty outside the named set.

**5. Non-goal confirmed.** No lunge term was added for minions. `attack_lunge_distance` has no
`minion_` twin, no additive velocity term exists on the unit path, and the reason is recorded in
the new field block in `balance_config.gd` so a later reader meets it at the field rather than only
in this story.

**6. Flagged by the dev pass as not done; ruled and added in the follow-up pass.** The dev pass
routed AC 2's proof deliberately through the new integration file and shipped no state test, leaving
the `4-3c1/R2` IDLE rule — the single defect three gates existed to prevent — guarded only by a
~230-frame live test, and recommended (not taken) a four-line state test over all four enum values
as sharper and cheaper. That recommendation was ruled and taken: `test/state/test_match_state.gd`
now carries `test_unit_attack_phase_multiplier_selects_the_right_field`, asserting all four
`UnitBoard.AttackPhase` values (IDLE returns `1.0` from the explicit non-field arm; WINDUP, ACTIVE,
and RECOVERY each read their own authored field), mutation-proven. The `4-3c1/R2` IDLE rule is now
guarded at both layers — a four-assertion state test and the live integration file — not the live
file alone.

**7. Live smoke is REQUIRED and has NOT been performed.** Tier A default, and the story asks for it
explicitly (a minion visibly planting its feet, kiting reading as intended, several minions
attacking without new jitter). The operator writes the `docs/playtest-log.md` entry by hand, before
the commit chain.

### File List

- `src/state/resources/balance_config.gd` — three new `minion_attack_<phase>_move_speed_multiplier`
  fields with their obligation block (AC 1)
- `data/balance/balance_config.tres` — the three fields authored 0.0, textual edit, editor never
  opened (AC 1)
- `src/state/match_state.gd` — `unit_attack_phase_multiplier(phase)`, the ruled seat (AC 2,
  `4-3c1/R1`, `4-3c1/R2`)
- `src/main/match_runner.gd` — inline multiplier read at the `UnitActor.approach()` call site, and
  the amended velocity-zeroing path comment block (AC 2, `4-3c1/R3`)
- `test/state/test_data_resources.gd` — three hand-added `E1_BALANCE_FIELDS` entries (AC 3)
- `test/state/test_balance_authoring.gd` — new
  `test_authored_minion_attack_move_speed_multipliers_are_non_negative` (AC 3)
- `test/state/test_intent_recorder.gd` — second named exemption `EXEMPT_PURE_QUERY` and the widened
  derivation-rule note (unforeseen guard, see Completion Note 1(b))
- `test/integration/test_unit_swing_root_live.gd` — NEW, proves AC 2, mutation-proven (integration
  baseline 36 -> 37)
- `test/state/test_match_state.gd` — `test_unit_attack_phase_multiplier_selects_the_right_field`,
  added in the follow-up pass closing Completion Note 6's named gap, mutation-proven
- `docs/implementation-artifacts/sprint-status.yaml` — `story_notes` and `last_updated`; the board
  entry stays `ready-for-dev` per CFG/R2

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-16 | Claude Sonnet 5 | Story authored, implementing `4-3c/R19` (recorded 2026-08-15 with no slot granted; the operator granted this story's slot 2026-08-16). Scope: minions get their own three attack-phase move-speed multipliers (authored 0.0, not the hero's fields reused); no lunge for minions (explicit non-goal); full root matching the hero. Golden Impact named as this story's biggest hazard — predicted MOVED, must be measured and the cause named, not silently accepted. `test/integration/test_unit_approach_live.gd` named as the likely test casualty up front. Status `authored`, board `backlog`. (superseded by the third fix pass) |
| 2026-08-16 | Claude Sonnet 5 | Readiness-gate fix pass (docs only, no code/tests/commits touched). Applied all seven gate findings. Status stays `authored`, board stays `backlog`. |
| 2026-08-16 | Claude Sonnet 5 | Second readiness-gate fix pass (docs only, no code/tests/commits touched). Applied all eight gate findings. Status stays `authored`, board stays `backlog`. |
| 2026-08-16 | Claude Sonnet 5 | Third readiness-gate fix pass (docs only, no code/tests/commits touched). Applied all six gate findings, including the operator's AC 2 tolerance ruling and three new decision-log entries (`4-3c1/R1-R3`). Status stays `authored`, board stays `backlog`. |
| 2026-08-17 | Claude Opus 5 | DEV PASS. All tasks complete. Golden UNMOVED both directions (`4a089063`), no re-baseline. State harness 497/3878/0 -> 498/3891/0, the delta fully accounted for by AC 3's own two guards. Integration 36 -> 37, all PASS. `project.godot` byte-identical, `physics_ticks_per_second=60` present, editor never opened. Three findings for the operator's decision-log: `test_unit_approach_live.gd:225` did NOT fail (the reach probe's 12-tick throttle steps over the 0.3-unit band — the prediction is measured wrong, and the pass is fragile against a retune); the ruled public seat tripped `test_intent_recorder.gd`'s intake-surface guard and needed a second named exemption, widening a ruled derivation rule; `4-3c/R12`'s cited coordinates confirmed stale. Live smoke REQUIRED and not yet performed. Status `authored` -> `review`, board stays `ready-for-dev` (CFG/R2). Nothing staged, nothing committed. |
| 2026-08-17 | Claude Sonnet 5 | Record fix pass (docs only): rewrote Completion Note 6 to reflect the added state test, corrected the measurement table to 499/3895, restated Completion Note (c)'s SKIP-path coordinates as measured-on-date and identified by what they are, and added Live Smoke Results (PASSED; strike/impact mismatch handed to `4-3d` AC 5). Status stays `review`, board stays `ready-for-dev`. |
| 2026-08-16 | Claude Sonnet 5 | Final readiness-gate fix pass (docs only, no code/tests/commits touched). Applied all six gate findings: removed the misapplied `4-3/R26` citation and stated crowd depenetration as possible, not observed; added AC 2's proving task (new integration test file, baseline 36 -> 37); corrected the `STOPPED_EPSILON` citation to `:56`; appended a supersession note to change-log row one; recorded that `4-3c/R12`'s cited coordinates no longer resolve; added decision-log pointers at `4-3c/R5` and `4-3c/R12` for their amendment by `4-3c1/R3`. Status stays `authored`, board stays `backlog`. |
