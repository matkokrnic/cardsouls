---
baseline_commit: 45ef05dd3f0fd4c4636d62c3e9c57e7c75a58008
---

# Story 4.5: Pooling / 60 FPS Exit

Status: authored

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the E4 milestone owner,
I want a measured 60 FPS verdict at 20 concurrent units with totems firing, with pooling built
only if that measurement fails,
so that E4's exit criterion ("60 FPS holds with many units; flags toggle cleanly") is closed by
evidence rather than by speculative machinery (`E4-P/R8`).

## Acceptance Criteria

**(a) Harness and measurement**

1. A repeatable way exists to reach 20 concurrent units and keep the count at ~20 by re-summoning
   as units die (deaths are part of the measured spawn/death event stream) for the whole measured
   round (minions + totems, both players combined), with combat totems firing, without touching
   `src/state/` or adding a new state intake — HALT and report if it cannot be built this way
   (tier-escalation call, operator's). A round ends on hero death; if 20 hostile units end rounds
   too fast to measure, the heroes are kept clear of the fight (mechanism: OQ 1).
2. Frame time is measured over a FULL ROUND, both split-screen viewports active, 20 units present,
   combat totems firing: (i) sustained — average and p95 frame time; (ii) worst single frame at
   each spawn and death event during the round. Must not be vsync-masked — with vsync on, wall
   frame time quantizes to 16.67 / 33.3 ms and hides both headroom and p95; the run disables vsync
   for the measurement or reads per-frame cost from the engine's process + physics time monitors.
3. CPU, GPU, and resolution at measurement time are recorded in this story.
4. The pass/fail line is exactly `4-5/R1`'s criterion below — no other number decides it.

**(b) The `4-5/R1` criterion**

5. PASS requires BOTH: sustained frame time <= 16.67 ms (one 60 Hz frame, 1/60 s) (average AND
   p95) across the full round, AND no single frame at a spawn or death event exceeds ~33 ms.
   Either failing is a FAIL. `4-5/R1` (operator, 2026-09-01): 20 concurrent units (minions +
   totems, both players); projectiles neither counted nor capped; no hard unit cap, economy-only —
   supersedes `4-3/R18`'s 16-unit figure by content ("required if the measured frame rate drops
   below 60 fps at 16 concurrent units on the reference machine"). The two measurement forms
   (avg/p95; worst spawn/death frame, ~33 ms) are this story's PROPOSED criterion, ratified by
   promotion to ready-for-dev — NOT `4-3/R18`, NOT themselves a ruling.
6. Projectiles are neither counted toward the 20 nor capped — as many as the live totems produce
   during the round enter the measurement as a side effect, not a controlled variable.
7. No hard unit cap exists or is added by this story; the economy (mana/stamina costs gating
   summons) is the only limit. Measured: `grep -n "max_units\|unit_cap\|MAX_UNITS"
   src/state/unit_board.gd src/main/match_runner.gd` — no matches; no unit-count ceiling in either
   file's spawn path.

**(c) Disposition**

8. If PASS: `src/systems/pool/` stays empty (only `.gitkeep`), `unit_actor.gd`'s "POOLED BY
   NOBODY THIS STORY (4-5)" header is corrected to state the measured outcome, and the GDD's
   E4-row pooling obligation ("Autonomous minion AI ..., pooling, throttled targeting, 3 totem
   subtypes") is closed by ruling, citing this measurement as evidence — no pooling code ships.
9. If FAIL: only the failing node class (units, projectiles, or both, per which sub-condition
   failed and which node type the hitch traces to) is pooled, owned by `match_runner.gd` (the
   existing spawn/free sites, the `UNIT_SCENE`/`TOTEM_SCENE` preload constants) or a runner-owned
   helper under `src/systems/pool/` — never `src/state/`, untouched either way.

**(d) Named observations, not ACs to fix**

10. The board-growth cost question from the 4-4 review (M4: append-only projectile board,
    `4-3a/R9` consequence) is OUT of scope as code. The measurement observes whether board growth
    has a measurable per-tick cost with totems firing at 20 units; whether that becomes a
    decision-log line at E4 close-out or its own Tier A story is the operator's call from the
    number.
11. The playtest-log 31.8. blinking observation (~4 minions bunched, flickering) is expected to
    reproduce at 20 units. NAME the cause as a finding — physics push jitter vs. overlapping-mesh
    rendering — not an AC. A fix is out of scope unless the dev pass finds a one-line
    presentation change and reports it as bycatch.

**(e) Flags and scope boundary**

12. E4's "flags toggle cleanly" exit criterion is covered by one live run with `minions` and
    `totems` both OFF (`data/feature_flags.tres`), confirming no crash/error and a clean match —
    unless an existing test already proves it (cite by content instead).
13. `src/state/` is untouched regardless of the measurement's outcome — AC 9 scopes any pooling
    to the runner/presentation layer, so no `src/state/` change is expected under either
    disposition. If the dev pass finds otherwise, that is a tier-escalation finding to report,
    not to implement past.

## Non-Goals

- Building pooling speculatively ahead of the measurement (`E4-P/R8`).
- A hard unit cap of any kind (AC 7); capping or counting projectiles (AC 6).
- Fixing the bunched-minion flicker (AC 11) or the append-only projectile board (AC 10) — both
  named findings, not fixes; AC 10's disposition is the operator's.
- Throttled-targeting retuning — the retarget cadence is `4-2/R5`'s settled ground.
- Any change to `4-4-totems`, `4-3`-series minion behavior, or `4-6`/`4-6a` camera/lock-on — this
  story observes their combined runtime cost, it does not modify them.

## Dev Notes

- **Tier and its proof obligation.** Tier B (`E4-P/R8`, discharged at `4-1` close-out: "`4-1`
  shipped units actor-owned with counts-only state, so pooling is runner/presentation machinery,
  not a state-layer concern; the ratified golden clause is the proof obligation"). Measure golden
  hash + the 28-key snapshot set before/after: both must be UNMOVED for Tier B to hold, whichever
  disposition (AC 8 or AC 9) fires — see Golden Prediction below.
- **Where the 20-unit instrument goes.** `DebugInstrumentPanel`
  (`src/ui/debug/debug_instrument_panel.gd`) is the established pattern for a runner-reaching,
  presentation-owned control: every existing control there is a Callable the runner hands over
  before `add_child` (`save_record`, `reload_balance`, `reveal_opponent_hand`), never a state
  handle. A new trigger would follow that shape. Alternatives per the operator's framing: live
  balance reload (already wired, `3-0d/R13`) to cheapen summon costs during the run, or a
  dedicated `test/`-tools scene driving the runner outside the card-cost gate. Which shape is the
  dev pass's call (OQ 1); the constraint is fixed — no `src/state/` touch, no new state intake,
  HALT and report if none work (AC 1).
- **Summon/spawn mechanics already in place, reusable as-is.** `match_runner.gd` computes
  `batch_size` from the gap between a card's authored `count` and the caster's live actor count,
  and its `_compute_spawn_positions` places each new member in a rear arc, unbounded in
  candidates. Reaching 20 is driving enough summon casts through this existing path — no new
  spawn mechanism is implied.
- **Totems must be FIRING, not just present.** `4-4-totems`' Combat Totem projectile attack must
  stay active per side through the round — an inert totem understates the per-tick cost
  (targeting, projectile flight, contact resolution) the criterion measures.
- **`unit_actor.gd`'s class header** carries the exact "POOLED BY NOBODY THIS STORY (4-5)" comment
  AC 8/AC 9 correct — the one place in the codebase that names this story by number today.
- **No existing test measures frame time or FPS.** `test_debug_instruments.gd`'s layout guard is
  the closest "geometry, not appearance" precedent (`PROC/R8`) but measures rects, not timing —
  new machinery, likely `Performance`/`Engine.get_frames_per_second()` read from a debug/tooling
  seat outside `src/state/` (D3(b)/A2 already forbids `Engine` reads there).
- **No unit-count ceiling exists**, measured: `grep -n "max_units\|unit_cap\|MAX_UNITS"
  src/state/unit_board.gd src/main/match_runner.gd` finds no matches — the fact AC 7 states.

### Project Structure Notes

- Pooling code, if AC 9 fires, lives under `src/systems/pool/` (reserved, currently only
  `.gitkeep`) or in `match_runner.gd` at the existing `UNIT_SCENE`/`TOTEM_SCENE`
  instantiate/`queue_free()` sites — never `src/state/`, never a new top-level folder.
- The measurement harness (OQ 1) lives under `src/ui/debug/`, `src/controllers/`, or `test/` —
  not `src/state/`.

### Project Context Rules

- F1: exactly one `func _physics_process`, in `match_runner.gd` — pooling or harness code must not
  add a second.
- D3(a): `Input.*` only under `src/controllers/`.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in `src/state/` — frame-time measurement
  necessarily reads `Engine`/`Performance`, which is exactly why it cannot live there.
- Docs and code never share a commit; ASCII commit messages via `git commit -F <tempfile outside
  the repo>`; PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Tier B, fixed at authoring per `E4-P/R8`; may be raised, never lowered, mid-story. No separate
  readiness gate for Tier B — the operator reviews in the browser before promotion.

## Golden Prediction (inverse form — the Tier B escalation clause)

**Prediction: the golden hash and the 28-key snapshot set do NOT move, under EITHER disposition
(AC 8 pass, or AC 9 fail-and-pool).** Measured, not assumed, per Tier B's golden-clause
discipline (`E4-P/R9`).

- **Golden hash** (`test/state/test_determinism.gd`):
  `GOLDEN := "aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f"`. Recorded at this
  story's baseline HEAD `45ef05dd3f0fd4c4636d62c3e9c57e7c75a58008` (== `origin/main`) as BEFORE.
- **Snapshot key set** (`test/state/test_card_observation.gd`,
  `test/state/test_draw_delay_and_reshuffle.gd`): the same 28-key set `4-6a` left unmoved,
  recorded at this baseline as BEFORE.

**Escalation clause:** the dev pass runs the full suite before touching any file and after the
diff is complete, recording both values in the Dev Agent Record. If either differs from BEFORE,
STOP and escalate — do not re-baseline, do not proceed as Tier B. Pooling recycles nodes instead
of instantiating/freeing them, a presentation-lifecycle change that should not touch state — but
that must be MEASURED, not assumed, exactly as `4-6a`'s own escalation clause treated its
rig-side smoothing change.

## Live Smoke

Per `PROC/R8` (applies to both tiers): any AC hinging on on-screen appearance goes to the operator
at first render; machine checks assert only geometry/numbers.

- **The 20-unit measurement itself (AC 2-5):** frame-time numbers are machine-read, but the setup
  (harness reaches 20 units, totems visibly firing, both viewports active) is confirmed by the
  operator's eye first.
- **Flags-off clean run (AC 12):** operator confirms no crash and a clean match, unless an
  existing test already proves it.
- **Blinking/flicker reproduction (AC 11):** observed and named by the operator, not fixed.

Record all three in `docs/playtest-log.md` by the operator's own hand.

## Budget (`PROC/R7`)

Larger than `4-B1`'s ~1h baseline, carrying new measurement machinery (no existing frame-time
harness to build on): 13 ACs, one new harness surface (OQ 1), a conditional pooling
implementation sized by the measurement's outcome. Budget: **~3h**, dev pass plus code review
agent-side wall clock (operator smoke, browser ruling turns, close-out docs/commit excluded, per
`PROC/R7`). TRIPWIRE: on crossing the budget, STOP AND REPORT remaining work — never push
through. Scaling down is the operator's call.

### References

- [Source: sprint-status.yaml, `4-5-pooling-60fps-exit` story_notes] — prior board framing:
  "BACKLOG, Tier B (assigned at 4-1 close-out, E4-P/R8 discharged) ... Criterion fixed by 4-3/R18
  ... 4-6 smoke observed minion meshes flickering/overlapping when ~4 units bunch up."
- [Source: decision-log.md, `E4-P/R8`, `4-3/R18`, `E4-P/R9`, `PROC/R7`, `PROC/R8`] —
  no-speculative-pooling ruling + discharge; the superseded 16-unit criterion this story's
  `4-5/R1` raises to 20; Tier A/B policy and golden-clause decisiveness; Tier B budget-tripwire
  and legibility-routes-to-smoke rules this story's Budget/Live Smoke sections apply.
- [Source: epics.md, "E4 — Minions & Totems"; gdd.md, epic table E4 row] — Exit criteria ("60 FPS
  holds with many units; flags toggle cleanly") and the "pooling" committed obligation AC 8/AC 9
  discharge.
- [Source: src/actors/minions/unit_actor.gd] — the "POOLED BY NOBODY THIS STORY (4-5)" header
  comment AC 8/AC 9 correct.
- [Source: src/main/match_runner.gd] — `UNIT_SCENE`/`TOTEM_SCENE` preloads, `_physics_process`
  (F1), the summon batch-size/spawn-position machinery (`_compute_spawn_positions`) this story
  reuses to reach 20 units; grepped with `unit_board.gd` for a unit-count ceiling (AC 7), none found.
- [Source: src/ui/debug/debug_instrument_panel.gd] — the Callable-handoff, runner-reaching control
  pattern (`save_record`, `reload_balance`, `reveal_opponent_hand`) a new trigger would follow.
- [Source: data/feature_flags.tres] — shipped defaults (`minions = true`, `totems = true`) the AC
  12 flags-off pass toggles.
- [Source: test/state/test_determinism.gd] — golden hash constant this story's Golden Prediction
  section measures against.
- [Source: docs/playtest-log.md, entry `31.8.`] — the bunched-minion flicker observation AC 11
  names.
- [Source: sprint-status.yaml, `4-4-totems` story_notes] — M4 (append-only projectile board)
  origin, AC 10's disposition question.

## Open Questions

1. **Measurement-harness mechanism**, and how heroes stay clear if rounds end too fast (AC 1).
   DebugInstrumentPanel trigger, live balance reload to cheapen summon costs, or a `test/`-tools
   scene — dev-pass call, constrained by AC 1 (no `src/state/` touch, no new state intake; halt
   and report if none work).
2. **Frame-time read source.** `Performance` vs. `Engine.get_frames_per_second()` vs. manual delta
   accumulation, and which node/script owns the read — D3(b)/A2 fixes WHERE it cannot live, not
   the mechanism (vsync-off vs. reading the engine's time monitors instead is this OQ's call; AC 2
   fixes only that the number must be unmasked).
3. **If AC 9 fires, which node class(es) get pooled** and whether one helper serves both units and
   projectiles — depends on which sub-condition failed and what the measurement traces the hitch
   to; not decidable before the numbers exist.
4. **AC 10's disposition** (decision-log line at E4 close-out vs. a new Tier A story) is the
   operator's call from the measured number, not a dev-pass decision.

## Tasks / Subtasks

- [ ] Resolve OQ 1; build the 20-unit, both-totems-firing harness without touching `src/state/`
      (AC 1). HALT and report if impossible without one.
- [ ] Resolve OQ 2; implement sustained (avg/p95) and worst-single-frame (spawn/death) measurement
      over a full round (AC 2, AC 3).
- [ ] Run the measurement; apply the `4-5/R1` criterion (AC 5); record CPU/GPU/resolution (AC 3).
- [ ] Disposition: AC 8 (pass) or AC 9 (fail — pool the failing node class(es), resolve OQ 3).
- [ ] Flags-off clean run (AC 12) unless an existing test already proves it.
- [ ] Name the flicker cause (AC 11) and board-growth observation (AC 10) as findings; do not fix.
- [ ] Measure golden + snapshot key set before/after; operator live smoke on the three surfaces.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
