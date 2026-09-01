---
baseline_commit: 45ef05dd3f0fd4c4636d62c3e9c57e7c75a58008
---

# Story 4.5: Pooling / 60 FPS Exit

Status: done

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

- [x] Resolve OQ 1; build the 20-unit, both-totems-firing harness without touching `src/state/`
      (AC 1). HALT and report if impossible without one.
- [x] Resolve OQ 2; implement sustained (avg/p95) and worst-single-frame (spawn/death) measurement
      over a full round (AC 2, AC 3).
- [x] Run the measurement; apply the `4-5/R1` criterion (AC 5); record CPU/GPU/resolution (AC 3).
- [x] Disposition: AC 8 (pass) or AC 9 (fail — pool the failing node class(es), resolve OQ 3).
- [x] Flags-off clean run (AC 12) unless an existing test already proves it.
- [x] Name the flicker cause (AC 11) and board-growth observation (AC 10) as findings; do not fix.
- [x] Measure golden + snapshot key set before/after; operator live smoke on the three surfaces.
      (Golden and key set measured unmoved both sides; the three live-smoke surfaces are the
      operator's own hand and are NOT claimed here — see Completion Notes.)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.
Dev pass (2026-09-01): Claude Opus 5, via `gds-dev-story`.

### Debug Log References

- `test/perf/perf_20_units_live.gd`, run four times (2026-09-01). Run 1 measured an INERT arena —
  21 standing units, zero deaths, zero projectiles for a full minute — and was discarded rather
  than reported; runs 2-3 were harness iterations at unforced window sizes; run 4 is the
  AUTHORITATIVE one, at a forced 1920x1080. The harness writes
  `user://perf_4_5_run.json` (`C:/Users/matko/AppData/Roaming/Godot/app_userdata/CardSouls/`) and
  prints the same JSON to stdout.
- `test/perf/flags_off_live.gd`, run twice (AC 12): once with the shipped flags ON, once with both
  OFF. See the mutation table.
- Full record of the pass, including the diffs shown before staging: `C:\dev\_45-dev.md` (outside
  the repo).

### Completion Notes List

**THE MEASUREMENT (AC 2, AC 3) — authoritative run, 3600 ticks (60 s at 60 Hz), 14483 rendered
frames, both split-screen viewports live, vsync DISABLED at runtime and `Engine.max_fps = 0`
(`vsync_mode` 0 and `max_fps` 0 are recorded in the run's own output, so the disable is evidenced
rather than asserted).**

| measure | value | threshold | verdict |
| --- | --- | --- | --- |
| sustained frame time, average | **4.14 ms** | <= 16.67 ms | PASS |
| sustained frame time, p95 | **7.52 ms** | <= 16.67 ms | PASS |
| worst single frame at a spawn or death event | ~~**10.39 ms**~~ **VOID — see Code Review Corrections (R-1); re-measured 15.46 ms** | <= ~33 ms | PASS |
| worst single frame anywhere in the round | 25.42 ms | (no clause) | — |
| frames over 16.67 ms | 4 of 14483 (0.03%) | — | — |
| frames over 33.3 ms | **0** | — | — |

Supporting series from the same run: p50 3.63 ms, p99 8.43 ms; measured GPU render time 1.37 ms
average (1.46 ms p95), so the frame is CPU-bound with the GPU an order of magnitude clear.
**CORRECTION (R-3): the GPU half of that sentence is WITHDRAWN.** The 1.37 ms was measured on the
ROOT viewport, which in `main.tscn` only composites the two player `SubViewport` textures and the
HUD — both `Camera3D`s live inside those SubViewports, so the number excluded essentially all of
the 3D work. "The GPU is an order of magnitude clear" is not established by it. The CPU-bound
conclusion itself survives on the wall/tick split, which never depended on the GPU series.

**The pessimistic reading, stated because it is the one a 60 Hz build actually lives in.** With
vsync off the engine renders ~241 fps, so only 3600 of the 14483 frames carried a physics tick.
Those tick-carrying frames — the only kind that exists at a vsync-locked 60 Hz — average
**7.15 ms** (against 3.15 ms for the rest; marginal cost of one full tick = **4.00 ms**), and their
worst is 25.42 ms. Their p95 is not computed directly but is BOUNDED: only 4 frames in the entire
run exceed 16.67 ms, and 5% of 3600 is 180, so the tick-subset p95 is necessarily under 16.67 ms.
The criterion passes on the strict reading as well as the headline one.

**AC 4 / AC 5 — VERDICT: PASS**, on both halves of `4-5/R1`'s criterion and by roughly a 4x margin
on the sustained half. No other number was allowed to decide it.

**AC 3 — the machine.** CPU 12th Gen Intel Core i5-12500H (16 threads); GPU NVIDIA GeForce RTX 3050
Laptop GPU, D3D12 feature level 12_0, Forward+; resolution 1920x1080 windowed, FORCED by the
harness (two earlier runs inherited 1920x1111 and 1152x648 from the window manager and therefore
two different GPU loads — a measurement the story must be reproducible from cannot have its pixel
count chosen by the desktop); Godot 4.6.3-stable, Windows, `physics_ticks_per_second` 60.

**AC 1 — the population, and what the harness had to do to make it real.** 20 concurrent LIVING
units, minions and totems, both players combined: measured `live_avg` **19.86**, min 16, max 21
across the whole window, with ~~64 spawn events and 43 death events~~ **43 spawn and 42 death
events (CORRECTED, R-2: the 64 was a lifetime total that included the 21 units the build phase put
on the board — 21 build + 43 measured = 64)** in the measured stream (the
population is HELD at ~20 by re-summoning as units die, which is what puts deaths in the stream
rather than letting the count decay). Combat totems firing: 1 on P1 and 3 on P2 at the end, with
the two projectile boards reaching 44 and 38 records — projectiles neither counted toward the 20
nor capped (AC 6), 0.40 alive on average and 3 at peak.

OQ 1 RESOLVED — a `test/`-tools script, not a `DebugInstrumentPanel` trigger and not a live balance
reload: it is the only one of the three that adds NO shipping surface. It follows
`test_summon_actor_live.gd` exactly — a `--script` SceneTree loading the real `main.tscn` and
driving real Input Map presses through `KeyboardController` into the runner's single
`_physics_process`. `src/state/` is untouched and no state intake is added (AC 13 holds): the state
calls are the existing public `mana.add` / `stamina.add` / `hero.heal` and read-only board queries,
from a test seat, as that file already does.

How the heroes are kept clear (AC 1's named risk): they are made UNKILLABLE by healing them to full
every tick, rather than moved away. Moving them would make the minions walk away from each other
and understate the load; healing keeps 20 hostile units permanently engaged on two stationary
targets and keeps `round_over` from latching and freezing the run mid-measurement.

**The first run measured NOTHING, and the reason is a shipped-content fact worth recording.** It
reported 21 standing units, ZERO deaths and ZERO projectiles for a full minute. The cause is not a
harness bug: the `standard` priority authored for every summoned unit is `prefer_hero = false` with
first-living-index ordering, so every minion on a side acquires the opposing board's INDEX 0 and
walks at it. The two walls meet in the middle, jam against each other's collision bodies, and never
come within `stop_distance` of a target standing behind the enemy line — so nobody swings and
nobody dies. Meanwhile each Combat totem had acquired the enemy HERO, which at the untouched spawn
separation sits ~11.5 m away, outside the authored 8 m firing range — so no totem ever fired. Two
harness additions fix it, both recorded in the file: the heroes are CLOSED to +/-2.0 m at build
start (an actor-position write; position is actor-owned, `4-3/R2`), which brings the enemy hero
inside totem range, and both heroes SWING on a fixed cadence, which is the only death source a
stationary observer can drive once the minions cannot reach what they acquired. An aggregate at the
end of an inert run would have looked like a comfortable PASS; it would have been measuring an
empty arena.

**AC 7 — no hard unit cap.** Re-measured at this HEAD:
`grep -n "max_units\|unit_cap\|MAX_UNITS" src/state/unit_board.gd src/main/match_runner.gd` returns
no matches, and this story adds none — the economy remained the only limit, and the harness reached
20 units by paying it (topped-up mana) rather than by raising a ceiling.

**AC 8 — DISPOSITION TAKEN (pass).** `src/systems/pool/` stays empty (`.gitkeep` only, unchanged
and unstaged this pass); `unit_actor.gd`'s "POOLED BY NOBODY THIS STORY (4-5)" header now states
the measured outcome and the numbers behind it, with an explicit note that the result belongs to
this content at this population on the recorded machine and should be re-measured before being
treated as permanent. No pooling code ships. AC 9 did not fire, so OQ 3 is moot and is recorded as
such rather than answered.

**AC 12 — flags-off clean run.** No existing test discharges it: the nearest,
`test/state/test_targeting_service.gd`, proves the EVALUATOR returns `REASON_MINIONS_FLAG_CLOSED`
with the flag closed — a pure-function fact about a static evaluator that says nothing about
whether the real scene comes up, ticks and plays a clean match. So `test/perf/flags_off_live.gd`
was built and run in both directions (mutation table below). With `minions` and `totems` both OFF:
420 frames, 8 summon casts driven, **0 unit records ever reached either board**, no round-over, no
hero death, no `SCRIPT ERROR` / `ERROR:` in the run's output, exit 0. Clean. The operator's own
confirmation at live smoke still stands as the ratifying observation (`PROC/R8`).

**AC 10 — the board-growth observation (M4), NOT fixed.** Measured directly: the unit board grew
from **21 records to 64** across the measured round (append-only, `4-3a/R9`), a 3x growth in the
arrays every per-tick loop walks — and the frame-time trend over the same window is **flat**:
first-quarter wall average 4.154 ms against last-quarter 4.166 ms, a +0.3% drift that is inside
run-to-run noise. Board growth had NO measurable per-tick cost at this scale with totems firing.
**QUALIFIED (R-5):** a review re-run of the same window measured 4.039 -> 4.311 ms, +6.7% early to
late. The trend is therefore not reliably "flat" across runs, and the quarters are taken over ALL
rendered frames (~3/4 of which carry no tick), which dilutes a per-tick drift roughly 4x. "No
measurable per-tick cost" should be read as "no cost large enough to separate from run-to-run
noise with this instrument", which is a weaker claim and still supports AC 10's disposition.
Whether that becomes a decision-log line at E4 close-out or its own Tier A story is the operator's
call from this number (AC 10 reserves it), and the number says the pressure is low.

**AC 11 — the bunched-minion flicker, cause NAMED not fixed, with the evidence for it.** The story
offers two candidates, physics push jitter versus overlapping-mesh rendering. The evidence points
at **overlapping-mesh rendering**, and against push jitter. **CORRECTION (R-4): the three bodies
cited below are CORPSES, not live units, and this conclusion is WITHDRAWN as evidenced — see Code
Review Corrections.** Three live units were observed at
`(1.4,-0.1)`, `(1.5,0.1)` and `(1.6,-0.0)` — within 0.1-0.2 m of each other, while the spawn
placement's own clearance radius is 0.9 m, so the skinned bodies are deeply interpenetrating rather
than merely adjacent. Their velocities at the same moment were pinned at **0.0**, not oscillating:
`move_and_slide()` had zeroed them against the opposing wall of bodies. Push jitter would show as
small non-zero velocities alternating in sign; a static deep overlap of two near-identical animated
meshes is the classic depth-fight, and it matches the playtest note (flicker while ~4 minions walk
INTO each other, i.e. exactly while they are interpenetrating and mutually blocked). Named as a
candidate cause on this evidence — no fix, and no one-line presentation change was found that would
have qualified as bycatch.

**Bycatch / open findings, none blocking.**
1. Four `.uid` files for scripts committed by earlier stories (`test/integration/
   test_camera_smoothing_live.gd.uid`, `test_lock_marker_live.gd.uid`, `test_lock_on_live.gd.uid`,
   `test/state/test_lock_on.gd.uid`) were generated by this pass's editor import run and are left
   UNTRACKED and uncommitted — they belong to `4-6`/`4-6a`, not to this story, and committing them
   here would smuggle unreviewed files into a 4-5 commit. Reported for the operator's chain.
2. Four frames of 14483 exceeded 16.67 ms (max 25.42 ms), none of them at a spawn or death event
   and none above 33.3 ms. Recorded as an observation, not a finding against the criterion, which
   they do not breach.
3. An earlier, lower-resolution iteration of the run recorded a single 269.75 ms frame. It did not
   reproduce in the authoritative run (max 25.42 ms) and no `max_index` was captured for it, so it
   is reported as an unexplained one-off rather than characterised.

**Tier B held (the golden clause, `E4-P/R9`).** Full suite run EXACTLY twice (`PROC/R1`), before
any file was touched and after the diff was complete:

| | BEFORE (at `23cf3f6`, untouched tree) | AFTER (diff complete) |
| --- | --- | --- |
| golden hash | `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f` | UNMOVED, same value |
| snapshot key set | 28 keys (`EXPECTED_PLAYER_SNAPSHOT_KEYS`) | UNMOVED, 28 keys |
| state harness | 566 tests, 0 failed, 4377 assertions | 566 tests, 0 failed, 4377 assertions |
| integration | 46 files, all PASS | 46 files, all PASS |
| result | ALL TESTS PASSED | ALL TESTS PASSED |

Neither moved, so no escalation was triggered and Tier B stands. Expected: the whole diff is one
comment block plus two files under `test/perf/` that nothing in `src/` references. Disclosed
deviation: the BEFORE invocation was piped through `tail -60`, which cut the harness's own count
line; the counts were recovered by re-running the STATE HARNESS ALONE at the same untouched tree
before any edit — a partial run, not a third full-suite run, so `PROC/R1`'s budget of exactly two
is intact.

**Mutation proofs (provenance: MEASURED).** Targets restored from copies taken OUTSIDE the repo,
never `git checkout --`.

| # | guard | mutation | expected | observed | restore |
| --- | --- | --- | --- | --- | --- |
| M1 | `test/perf/flags_off_live.gd` non-vacuity | `data/feature_flags.tres`: `minions = true` -> `false`, `totems = true` -> `false` | the check must flip its own expectation and still hold: units required to reach a board with the layers ON, required NOT to with them OFF | ON: `casts=8 max_unit_records=8` -> PASS. OFF: `casts=8 max_unit_records=0` -> PASS. A check that ignored the flags would have failed one of the two. | copied back from `C:\dev\_45scratch\feature_flags.tres.orig`; SHA256 `05eba18a…4fb3` identical before and after |
| M2 | the perf harness's own subject | (not a mutation — recorded here because it is the same class of proof) the harness ABORTS up front if `flags.minions` or `flags.totems` is off, so a run that measured an empty arena because the layers were closed cannot report a number | abort, not a number | not triggered in the authoritative run (both flags on) | n/a |

`project.godot` byte-identity across the `.uid` import pass: SHA256 taken before and after the
`godot --headless --editor --quit --path .` run, `sha256sum -c` reported `project.godot: OK`, so
the editor touched nothing and no restore was needed.

**Not claimed here.** The three live-smoke surfaces (`PROC/R8`) are the operator's own hand and are
NOT asserted by this pass: the 20-unit setup confirmed by eye, the flags-off clean match, and the
flicker reproduction/naming. The machine numbers above are the machine-checkable half only.

### Code Review Corrections (2026-09-01, `gds-code-review`)

The review reproduced the measurement and audited the instrument. **The VERDICT is unchanged and
unchallenged: PASS on both halves of `4-5/R1`, so AC 8's disposition stands and no pooling ships.**
Five recorded numbers did not survive, none of them the verdict. The harness fix is its own commit;
the decision log gets a forward-append correction note, never an edit.

**R-1 — "worst spawn/death frame 10.39 ms" was mis-attributed by one tick, and is VOID.** A
`SceneTree` subclass's `_physics_process` is the MainLoop callback, which the engine runs BEFORE it
propagates the physics notification to nodes — so the harness always ran before `MatchRunner`.
Polling the board at the top of a tick read what the runner left at the end of the PREVIOUS one, so
a spawn or death resolved on tick N was flagged onto the frame carrying tick N+1: the frame AFTER
the one that paid for `instantiate()` / `queue_free()`. 10.39 ms is therefore the worst frame
*adjacent to* an event, not *at* one — and it is the number `4-5/R1`'s ~33 ms half is decided on.
Attribution fixed (`_observe_events()` moved to `_process`), and a review re-run of the full 3600-
tick window with the corrected instrument measured **worst event frame 15.46 ms** (index 14564)
against the ~33 ms ceiling — **still PASS, by better than 2x**. The original run's per-frame data
does not survive, so 10.39 cannot be retro-corrected; 15.46 ms is a fresh measurement on the same
machine and content, and it is the number that should be cited.

**R-2 — "64 spawn events and 43 death events in the measured stream" were lifetime totals.**
`_observe_events()` runs from the first tick (the cursors must stay current through build), and the
counters were never scoped to the window, so the 21 units the build phase put on the board were
counted as measured-window spawns. The corrected harness reports the split directly and the
arithmetic closes exactly: **21 build spawns + 43 measured spawns = 64**; deaths **1 build + 42
measured = 43**. In-window figures are **43 spawns and 42 deaths**.

**R-3 — the GPU cross-check measured a compositing pass.** See the correction inline above. This
also means OQ 2 (ii)'s cross-check was not, as run, watching the subject it was built to watch; the
wall-clock primary number is unaffected, and the tick/no-tick split carries the CPU-bound
conclusion on its own.

**R-4 — AC 11's evidence is a corpse pile, and the naming is WITHDRAWN as evidenced.** The
diagnostic that produced the three coordinates walked actor slots 0..4 filtered only on
`is_instance_valid` — the OLDEST board indices, hence the likeliest to be dead. A corpse stays a
valid actor for 600 ticks (`match_runner._free_dead_unit_actors`), its collision is disabled the
tick it dies, and `_approach_unit_actors` skips dead indices so its velocity is never driven. The
review added an `L`/`D` liveness tag and re-ran: at `t=360` the p2 line reads
`D2:k0@(1.4,-0.1)v0.00 D3:k0@(1.5,0.1)v0.00 D4:k0@(1.6,-0.0)v0.01` — **the exact three coordinates
this record cites as "three live units", all three tagged DEAD**. Corpses interpenetrate at 0.1-0.2
m *because their collision is off*, and sit at v0.00 *because nothing drives them*, so both halves
of the argument are explained by deadness rather than by depth-fighting. Live bunched units in the
same runs sit ~0.5-0.7 m apart (still inside the 0.9 m spawn clearance) with velocities pinned at
0.00 — which still argues against push jitter, but is NOT the deep interpenetration the conclusion
rested on. **AC 11's cause returns to UNNAMED**, with one new candidate the corrected instrument
made visible and worth carrying forward: a 600-tick corpse with collision off, overlapping live
bodies and other corpses, is itself a depth-fight source at 20 units, and it was not among the two
candidates the story offered. Naming it remains out of scope here (AC 11 forbids the fix, and the
story only ever asked for a name); this is a finding for the operator, not a disposition taken.

**R-5 — the AC 10 flat-trend number is run-dependent.** See the qualification inline above.

**AC 2's "FULL ROUND" is a PROXY, and is now stated as one (review target T4).** The harness heals
both heroes to full every tick, so `round_over` never latches and no round ever ends; what is
measured is a fixed 3600-tick (60 s) window, not a round. This is LEGITIMATE rather than a
deviation — AC 1 explicitly anticipates it ("if 20 hostile units end rounds too fast to measure,
the heroes are kept clear of the fight") and delegates the mechanism to OQ 1, which resolved to
unkillable heroes. But "over a FULL ROUND" in AC 2 was discharged by a 60 s proxy chosen to be
longer than an observed round and held at ~20 units for its whole length, and the record should say
so rather than let "full round" read as a round that ran to its end. The proxy is the stronger
measurement of the two (a real round would end when a hero dies, i.e. at a moment chosen by the
combat rather than by the criterion), which is why it is recorded as satisfying AC 1/AC 2 as
written and not as a gap.

**What the review re-ran, and what reproduced.** The full suite once (566 tests / 4377 assertions /
0 failed, 46 integration files, ALL PASS; golden `aa3566d7…` and the 28-key set both UNMOVED —
Tier B holds, and `git diff 23cf3f6..4b75cd6 --stat -- src/state/ project.godot data/` is empty).
The measurement was reproduced with the harness AS COMMITTED at the same forced 1920x1080: avg
**5.31 ms**, p95 **10.79 ms**, worst event frame 19.34 ms, 0 frames over 33.3 — **PASS on both
halves**, numbers higher than the authoritative run's but the verdict identical. Notably the entire
`population` block came back BIT-IDENTICAL to the authoritative run (same `live_avg` to 12 decimal
places, same 49/49 casts, same 867 build frames), so the simulation is deterministic run to run and
only the timing varies — which makes this measurement more reproducible than the record claimed.
The corrected-harness run additionally computes the criterion's own population directly:
**tick-carrying p95 = 8.40 ms** against 16.67, so the sustained half no longer rests on the
record's bounding argument. That run did see 2 frames above 33.3 ms (max 48.6 ms), neither at an
event, where the authoritative run saw none — run-to-run variance in the tail, no breach of a
criterion that speaks only to event frames, but it means "0 frames over 33.3 ms" is a property of
that run rather than of the build. AC 12 was re-run in BOTH directions with the backup-outside-repo
and SHA-verified restore ritual: ON `casts=8 max_unit_records=8` PASS, OFF `casts=8
max_unit_records=0` PASS, `data/feature_flags.tres` restored to `05eba18a…4fb3`, byte-identical.

### Live Smoke Results (operator, 2026-09-01)

**1 — Setup confirmed by eye.** ~20 units on the board, both split-screen viewports live, combat
totems firing (projectiles toward the heroes at the centre); unit-vs-unit and unit-vs-totem combat
visible on both sides (shipped `standard` priority, first time seen at this scale).

**2 — Flags-off run clean by eye.** Casts play, nothing spawns, no crash; the run self-terminates
after a few seconds. Flags restored to ON afterward, `git status` clean.

**3 — Flicker REPRODUCED.** Rare: when many units pile up, a region of the screen flickers and the
camera stutters briefly. Walking/attacking bodies and stuck standing bodies flicker for certain;
corpses possibly (operator unsure, declined to probe further). Operator's judgement: infrequent and
not a situation seen in real play. AC 11's cause stays UNNAMED (`4-5/R2`'s corpse-collision finding
is one of three candidates alongside physics push and overlapping live meshes), deferred to the
playtest block, non-blocking.

**Also recorded.** Minions freeze when an obstacle sits in front of them until something moves
(known cause: `approach()` does not distinguish arrived from blocked, deferred 4-3 work). The rare
stutter is consistent with the measured non-event tail frames (the review re-run's 48.6 ms outlier).

### File List

- `test/perf/perf_20_units_live.gd` (new) — the 20-unit frame-time measurement harness.
- `test/perf/perf_20_units_live.gd.uid` (new).
- `test/perf/flags_off_live.gd` (new) — the AC 12 flags-off live check.
- `test/perf/flags_off_live.gd.uid` (new).
- `src/actors/minions/unit_actor.gd` (modified) — AC 8: the pooling header now states the measured
  outcome. Comment only.
- `docs/implementation-artifacts/4-5-pooling-60fps-exit.md` (modified) — this record; Status,
  Tasks, Dev Agent Record, File List.
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — the skill's own board write and
  the team override's correction of it (`PROC/R9`), plus this story's `story_notes` line.
- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md` (modified) — forward
  append of `4-5/R1`.

NOT in this list, deliberately: the four stray `.uid` files named under Bycatch, which this pass
generated but does not own.
