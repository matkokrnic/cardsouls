---
baseline_commit: 9031f6c7a341f3b2d72d2fba2024568ad58e9d87
---

# Story 1.9: Roll with i-frames

Status: review

## Story

As a player,
I want a stamina-costing roll that displaces me in the direction I held at the moment of input and ignores contacts for exactly the authored i-frame ticks (with the hurtbox left enabled),
so that i-frames are deterministic and headless-testable and the exact i-frame boundary is asserted on ticks.

## Acceptance Criteria

1. **Fixed substrate — re-verify, never re-implement (B3 rescope).** The `ROLLING` transition, its stamina cost and rejection (`StaminaPool.spend()` at the step-3 policy seat; `action_rejected(&"roll", &"insufficient_stamina")`; cost read inline, CONSTRAINT C), and the full 1-3 cancellability table (roll cancels attack recovery; never windup/active; STUNNED and DEAD accept nothing) are FIXED SUBSTRATE from 1-3/1-4, test-pinned (`test_pin_roll_cancel_resets_chain_sequence`, `test_roll_at_cost_minus_one_rejected_with_signal`, `test_roll_at_exactly_cost_succeeds`, `test_roll_deducts_cost_at_the_transition`). This story re-verifies them and re-implements nothing. 1-9's deltas are exactly: (a) roll displacement (AC 2, 1-9/R6) and (b) the step-4 iframe drop (AC 3-4, 1-9/R1/R2/R3).
2. **Roll displacement (1-9/R6) — the story core.** Direction is captured at ROLLING entry — the world-space, camera-rotated `move_dir`; `HeroState.facing` fallback when the stick is neutral — into a NEW snapshotted `HeroState` field. A new ROLLING branch in `_resolve_movement` overrides velocity at `roll_distance / roll_duration_seconds`: CONSTANT velocity, direction LOCKED for the whole roll, the FIRST consumer of `roll_distance`, both balance values read inline (CONSTRAINT C). No curve, no steering during the roll — future tuning stories, not this one. NAMED PLAYER-FACING BEHAVIOR CHANGE: today a rolling hero steers freely at full `move_speed` with live input; after 1-9 direction is locked and speed is roll-derived. State writes `velocity`; the actor never applies its own displacement (F1). No new balance field.
3. **Iframe negation is a FACT DROP, pre-dedupe (1-9/R1).** An iframed contact is a fact DROP, not a resolution: step 4 drops it BEFORE dedupe registration, the same family as the existing DEAD-target drop. No damage, no `hit_landed`, no mana — and the swing keeps its chance: if the i-frames expire while the swing's active window is still open, the next gathered fact resolves normally. The ladder rule (one resolution per swing per target, R-D4) is untouched — a dropped fact never resolves. Ladder order: DEAD drop -> iframe drop (new) -> dedupe accept/register -> BLOCKING/facing (deflect -> block) -> full damage. No ladder crossing is possible: ROLLING and BLOCKING are mutually exclusive by the single `action_state` enum (1-9/R4, recorded as verified).
4. **Derived invulnerability, judged on the window (+grace) alone (1-9/R2, 1-9/R3).** Invulnerability is DERIVED — a new `HeroState.is_iframe_open()` accessor over the EXISTING `roll_iframe` window plus a per-tick grace transient mirroring `_deflect_closed_this_tick` (recomputed in `tick_timers()`, write-before-read inside `advance()`, EXCLUDED from `to_snapshot()`). No stored `is_invulnerable`, no new snapshot field for it. The hurtbox `Area3D` is never disabled — the fact still arrives and state decides. Negation is judged on the window (+grace) ALONE, never on `state == ROLLING` (1-9/R3). Entry-edge semantics (1-9/R2, recorded): under the F1 one-tick fact lag the judged span is the physical span shifted one tick — at the ENTRY edge a contact whose physics predate the roll press by one tick is negated; intentional and player-favorable; net coverage equals the authored tick count. This EXTENDS the R-N2 precedent (which litigated only the close edge) to both edges.
5. **Derived phases; no new data; the subset premise becomes an audit bound (1-9/R3).** The roll's phases are DERIVED from the two existing windows (the `attack_phase()` precedent): i-frames = `roll_iframe` running; recovery = `roll_duration` running AND `roll_iframe` not. No third window, no new balance field, no iframe start offset — both windows open at ROLLING entry (status quo, `enter_roll`). NEW authoring-audit bound in `test_balance_authoring.gd`: `roll_iframe` ticks <= `roll_duration` ticks (the R-N6 defect-by-construction family). Supporting invariant, now an obligation (1-9/R3): both roll windows start ONLY in `enter_roll` and no code path stops either before expiry; any future early-stop path must re-open this ruling.
6. **No dodge cue/signal (1-9/R5).** 1-9 ships NO signal — under drop semantics there is no resolution to signal. If 1-10's combat-cues gate wants a dodge cue, it raises that itself and owns the cost of surfacing drops.
7. **Headless tests.** The negation boundary pair under grace semantics, SAME swing (a contact resolving on the last iframe tick negates via the grace read; the first post-iframe tick's fact deals full damage); the drop-not-register pin (a post-iframe fact from the SAME swing lands — the swing kept its chance); no mana and no `hit_landed` on a negated contact; direction capture (from `move_dir`, under a non-identity camera basis, and the facing fallback on neutral); the ROLLING velocity override + direction-locked pin (mid-roll input changes neither direction nor speed); the iframe-drop-precedes-dedupe pin; mid-roll `apply_balance` (in-flight windows keep their duration — CONSTRAINT C); the AC 5 audit bound; a one-line roll-during-active-frames drop pin (completes the AC wording — the windup drop is already pinned). PLUS one integration test: real input, the actor displaces in the intended world direction.

## Tasks / Subtasks

- [x] `HeroState`: NEW snapshotted roll-direction field; `is_iframe_open()` accessor; `_roll_iframe_closed_this_tick` per-tick transient in `tick_timers()` (AC: 2, 4)
- [x] Step 3: capture the roll direction at ROLLING entry (camera-rotated `move_dir`; `facing` fallback on neutral); ROLLING branch in `_resolve_movement` overriding velocity at `roll_distance / roll_duration_seconds` (AC: 2)
- [x] Step 4: iframe drop BEFORE dedupe registration, slotted next to the DEAD-target drop (AC: 3, 4)
- [x] Audit bound: `roll_iframe` ticks <= `roll_duration` ticks in `test_balance_authoring.gd` (AC: 5)
- [x] Headless tests per AC 7 + the integration displacement test (AC: 7)
- [x] Golden: measure BEFORE first edit and after; author `roll_distance` in `_golden_config` (gate finding 1-9/N1); restructure deliberately (P2 attack overlapping P1's roll iframes); at most ONE re-baseline with the three named causes (see Golden prediction below)
- [x] Live smoke check: three-part protocol (see Live smoke check below) — **performed by the operator 2026-07-27**
- [ ] Close-out decision-log entry: outcomes record, obligation status — **close-out commit, after review**

## Dev Notes

- **1-9/R1 mechanics.** The drop slots next to the DEAD-target drop in `_resolve_contacts()` — before `register_swing_hit`, so a dropped fact never consumes the swing. The runner re-gathers a fresh fact every tick the hitbox overlaps, so the same swing's later facts arrive on their own; the first post-iframe fact resolves normally.
- **1-9/R2 grace.** Mirror `_deflect_closed_this_tick` exactly: a per-tick transient recomputed in every `tick_timers()`, write-before-read inside `advance()` (step 2 writes, step 4 reads, nothing reads it across ticks), excluded from `to_snapshot()` with the same replay-soundness argument (replay recomputes it identically inside each tick).
- **1-9/R3 window-alone soundness.** The invariant that makes window-alone safe: ROLLING exits only on `roll_duration` expiry, the `rolling` table row accepts no input, and the debug reset touches neither action states (except DEAD -> IDLE) nor windows — so the audited bound `roll_iframe <= roll_duration` closes the only inversion path, and inversion becomes a config defect by construction. Window-alone (not state-AND-window) also keeps the grace tick alive when iframe close coincides with duration close — a state check would clip exactly the physically-last-tick contact the grace exists to protect.
- **1-9/R6 numbers.** Authored: `roll_distance` 3.0 over `roll_duration_seconds` 0.5 = 6.0 u/s vs `move_speed` 5.0 — a roll outruns running; at 60 Hz, 30 ticks x 0.1 = exactly 3.0 units.
- **Parked lunge compatibility (recorded).** The 1-7 attack-lunge finding stays parked ("when animations exist"); roll displacement is the same sanctioned family — state-layer authored displacement consumed through `velocity`, F1 intact — precedent-compatible, not a trigger.
- **Gate finding 1-9/N1.** `_golden_config` does not author `roll_distance` (defaults 0.0): the golden restructure MUST author it, or the hash encodes a zero-speed roll and the golden guards nothing about displacement.
- **Smoke (R-D6).** The dummy never swings; flip slot 1 to `KEYBOARD_P2` for the supervised check only; shipped default stays P2=NULL. The DEAD-slot residuals (a dead hero can walk; a corpse mid-swing can be credited damage/mana) stay ACCEPTED for supervised E1 smoke checks (1-8 AND 1-9); the fix trigger stays story 2-3.

### Golden prediction (1-9/R7)

Predicted to MOVE; at most ONE re-baseline; THREE separately named causes; measured in BOTH directions (hash recorded before the first edit and after); all non-golden tests proven green first.

1. **Snapshot shape** — the new stored roll-direction field in `to_snapshot()` (it is read across ticks, so excluding it would be a replay hole; sufficient alone to move the hash).
2. **Exercised path + authored value** — `_golden_config` gains `roll_distance` (currently unauthored there, defaulting 0.0 — gate finding 1-9/N1), and t17-21 velocity becomes the locked roll override instead of live-input steering (the recorded sequence has non-zero move input on roll ticks).
3. **Deliberate restructure** — P2 gains an attack timed so its active window overlaps P1's roll iframes; one fact targeting P1 is negated during the iframes, a second fact one tick after close lands full damage, pinned by a new sequence-coverage test (the `test_golden_sequence_exercises_block_and_deflect` pattern).

Dev discipline: the intermediate empirical measurement (mechanics in, OLD sequence unchanged) isolates causes 1+2 from 3; both predictions measured in both directions, never trusted. Exact boundary ticks live in dedicated non-golden tests, never in the golden.

### Live smoke check (1-9/R8)

The R-D6 acceptance is IN FORCE for 1-9 (recorded at the 1-8 close-out). Temporary flip of runner slot 1 to `KEYBOARD_P2` (exported array); the shipped default stays P2=NULL. Three-part protocol on the throwaway overlay's HitLabel:

1. **Control** — P1 stands in P2's swing: a damage number appears (proves range and aim).
2. **Dodge** — same position, timed roll through the swing: NO number (the negation; P1 is not blocking, so no deflect ambiguity).
3. **Late roll** — the i-frames end inside the active window: a number appears. This part is a LIVE CHECK of the 1-9/R1 drop ruling — under register semantics a same-swing post-iframe number is impossible.

Collateral hazard (known, restated): the editor save for the flip re-normalizes BOTH `src/main/main.tscn` and `project.godot`. Inspect `git diff project.godot` BEFORE reverting; revert both by full path: `git checkout -- src/main/main.tscn project.godot`.

### Project Structure Notes

- `src/state/hero_state.gd` (roll-direction field + snapshot delta, `is_iframe_open()`, grace transient), `src/state/match_state.gd` (entry-time direction capture, ROLLING branch in `_resolve_movement`, step-4 iframe drop), `test/state/` (new roll-iframe suite, audit bound, determinism restructure), `test/integration/` (displacement test). NO runner changes (gathering is untouched); NO balance schema changes.
- NO architecture-doc edits: the amendment queue (world-space facing contract + `null_controller.gd` Directory Tree) stands untriggered; the global N4 comment-hygiene queue stays untouched.

### Project Context Rules

- **CONSTRAINT C:** `roll_distance`, `roll_duration_seconds` (as `roll_duration_ticks`), and the window tick counts are read inline at the moment of use; never cache the `BalanceTicks` object.
- **State/visual separation:** invulnerability is a state fact; visuals never gate damage; the hurtbox stays enabled. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Integer-tick timing** for i-frames; the boundary is asserted on ticks. [Source: docs/project-context.md#Deterministic timing]
- **D5 queued signals:** nothing new enqueues (1-9/R5 — no signal ships).
- **Docs and code never share a commit.**

### References

- [Source: stories-manual-e1.md#E1.S9]
- [Source: gdd.md#Primary Mechanics — Roll]
- [Source: docs/game-architecture.md#Spatial Model, F1]
- [Source: decision-log.md#Session 2026-07-27 — Story 1-9 readiness gate (operator decisions)]
- [Source: decision-log.md#Session 2026-07-26 — Story 1-8 readiness gate (R-D6, R-N2)]

## Readiness Gate (2026-07-27)

Report-only gate returned **NOT READY** — five blocking findings: B1 (AC2's stored `is_invulnerable` flag contradicted the derived-window idiom, and the negation semantics were unspecified against the R-D4 one-resolution ladder), B2 (AC3's three-balance-phase model and iframe start offset contradicted the shipped shape — no third field exists and `enter_roll` opens both windows at entry), B3 (the story presented the 1-3/1-4 substrate — ROLLING transition, stamina cost, cancellability — as new work), B4 (no golden prediction despite guaranteed snapshot-shape and exercised-path changes), B5 (no live-smoke section despite the R-D6 acceptance being in force for 1-9 by name). All resolved by operator decision (Matko): rulings 1-9/R1 (fact DROP pre-dedupe, DEAD-drop family), 1-9/R2 (+1 grace tick via per-tick transient; precedent extended to both edges), 1-9/R3 (window-alone judgment + audit bound + early-stop invariant obligation), 1-9/R4 (ladder position recorded as verified), 1-9/R5 (no signal), 1-9/R6 (displacement in scope: locked direction, constant velocity, first `roll_distance` consumer), 1-9/R7 (golden MOVES, three named causes), 1-9/R8 (three-part smoke protocol) — applied to this story 2026-07-27; promoted backlog -> ready-for-dev. Full record: decision-log.md, Session 2026-07-27 — Story 1-9 readiness gate.

## Dev Agent Record

### Agent Model Used

Claude Fable 5 (claude-fable-5)

### Debug Log References

- Baseline (before first edit): state harness 130 tests / 600 assertions PASS at 9031f6c; golden `298c40f65d5f3191d2d7c2eacdccdd443c49fe24b0492d66e088318ed840f23f` confirmed green.
- Golden-protocol step-2 INTERMEDIATE measurement (mechanics A-E in + `roll_distance` authored in `_golden_config`, OLD sequence unchanged): hash moved to `3138e35bfb1af9b4d86e94b198dc86e5156c200589b15f38194d3713ff736874`, the golden the ONLY red test (140 tests / 633 assertions otherwise green).
- Cause-2 ISOLATION run (same state, `roll_distance` authoring temporarily removed): hash IDENTICAL `3138e35b...6874` — cause 2 measured hash-neutral; the intermediate movement is cause 1 (snapshot shape) alone.
- Post-restructure proof run: 141 tests, only `test_state_matches_golden` red with the FINAL hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` in its expected-vs-actual output; GOLDEN constant then updated EXACTLY ONCE.
- Final: state harness 141 tests / 640 assertions PASS; all 8 integration tests PASS individually (7 existing + new `test_roll_displacement.gd`: dx=3.000000 dz=0.000000, mid-roll velocity (6,0,0), stopped after); editor scan produced ONLY the two new `.uid` sidecars — no `main.tscn`/`project.godot` collateral (verified via git status).

### Completion Notes List

- **1-9/R6 landed as gated.** `enter_roll` gained a `direction` parameter (MatchState computes policy — the `_roll_world_direction` helper mirrors `_resolve_movement`'s clamp/identity/rotation mapping, NORMALIZED, with the world-space-facing fallback on a neutral stick; HeroState only stores). `_resolve_actions`/`_try_transition` now carry `intent`/`slot` so the ROLLING edge captures from the same press that fires it. `_resolve_movement` gained the ROLLING override branch: `roll_direction * (roll_distance / roll_duration_seconds)`, both read inline (CONSTRAINT C — pinned: a mid-roll reload changes the speed next tick while in-flight windows keep their duration). The facing update still runs during a roll (the ATTACKING-commitment precedent: velocity-only, facing tracks input). The stale "ROLL half is 1-9's" comments amended at both sites.
- **1-9/R1/R3 landed as gated.** The iframe drop sits in `_resolve_contacts` directly after the DEAD-target drop, BEFORE `register_swing_hit`, judged via `is_iframe_open()` — window (+grace) alone, no state check. Pinned from both sides: the same swing's post-grace fact LANDS (drop-not-register / drop-precedes-dedupe), and the equality-edge config (iframe == duration) negates on the grace tick AFTER ROLLING already exited (window-alone).
- **1-9/R2 landed WITHOUT a snapshot field.** `_roll_iframe_closed_this_tick` mirrors `_deflect_closed_this_tick` exactly: recomputed in `tick_timers()`, write-before-read inside every `advance()`, excluded from `to_snapshot()`. Boundary pinned in FACT-ARRIVAL ticks per the gate's precision requirement: close+1 arrival negates via the transient, close+2 lands full, SAME swing.
- **Golden (1-9/R7): ONE re-baseline** `298c40f6...` -> `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, measured both directions, reconciled cause by cause: (1) SNAPSHOT SHAPE moved the hash as predicted (the one new `roll_direction` field; P1's t17 roll stores `(-1, 0, 0)` via the facing fallback — on the hashed record); (2) EXERCISED PATH + AUTHORED VALUE was predicted a mover but MEASURED NON-MOVER — roll velocities are per-tick transients overwritten before the hashed t24 snapshot (the 1-5 cause-(c) lesson holding again), proven by the isolation run (identical intermediate hash with and without the `roll_distance` authoring); `roll_distance` stays authored for path coverage per 1-9/N1; (3) DELIBERATE RESTRUCTURE moved the hash as predicted — P2 attacks t15 (block release and attack entry fire the same tick; active 18-21 over P1's roll iframes), the t19 arrival drops on the grace tick, the t20 arrival lands full damage (P1 120 -> 108, P2 mana 0 -> 12), pinned by `test_golden_sequence_exercises_iframe_negation`; the transitions pin widened to P2's fifth edge. Nothing moved that was not predicted.
- **Suite:** 130 -> 141 state tests / 600 -> 640 assertions (9 new roll-iframe tests + the audit bound + the golden coverage pin); integration 7 -> 8, all green individually.
- **Fences respected:** `match_runner.gd` untouched (gathering unchanged); no balance-schema fields; no new signals and nothing new enqueues (1-9/R5); no architecture-doc / board / decision-log edits in this pass; STUNNED guard green; DECISION A intact; `slot_controller_kinds` default untouched.
- **Live smoke check NOT performed — awaits the operator after review** (three-part protocol in the Live smoke check section; part 3 live-checks the 1-9/R1 drop ruling). Close-out decision-log entry rides the later docs commit.
- **Live smoke check PASSED (2026-07-27, operator; temporary KEYBOARD_P2 flip on slot 1 — reverted, never committed).** All three parts on the throwaway HitLabel: (1) CONTROL — standing in P2's swing, the damage number appeared; (2) DODGE — a timed roll through the swing produced NO number; (3) LATE ROLL — the i-frames expired inside the active window and the number appeared — the LIVE confirmation of the 1-9/R1 drop ruling (under register semantics a same-swing post-iframe number is impossible). Cleanup note: a second editor session left the flip baked into `main.tscn`; caught at the close-out chain's Step 0 baseline check and reverted by the operator by full path before anything was staged (`project.godot` was clean) — the 1-8 editor-save-collateral lesson repeated; procedural consequence recorded in the close-out decision-log entry.

### File List

- `src/state/hero_state.gd` — `roll_direction` (snapshotted, the ONE 1-9 snapshot delta); `_roll_iframe_closed_this_tick` transient + `is_iframe_open()` (1-9/R2/R3); `enter_roll(duration, iframe, direction)`; `tick_timers()` recomputes the transient
- `src/state/match_state.gd` — `intent`/`slot` threaded through `_resolve_actions`/`_try_transition`; `_roll_world_direction` capture helper (1-9/R6); ROLLING override in `_resolve_movement`; step-4 iframe drop pre-dedupe (1-9/R1/R3); comment amendments at the touched sites
- `test/state/test_roll_iframes.gd` (+ `.uid`) — NEW: 9 tests — running-iframe drop, the fact-arrival boundary pair (grace close+1 / full close+2, same swing), window-alone equality edge, direction capture (normalized+locked / facing fallback / camera basis), mid-roll reload (CONSTRAINT C), roll-during-active drop, snapshot shape pin
- `test/state/test_balance_authoring.gd` — `test_authored_roll_iframe_within_roll_duration` (1-9/R3 bound, compared in ticks)
- `test/state/test_determinism.gd` — GOLDEN re-baselined with the three causes reconciled in the header; `_golden_config` authors `roll_distance` 3.0 (1-9/N1); P2 attack t15 + t19/t20 facts; `test_golden_sequence_exercises_iframe_negation`; transitions pin widened
- `test/integration/test_roll_displacement.gd` (+ `.uid`) — NEW: full-chain displacement — neutral-stick roll via facing fallback, dx == roll_distance, straight, mid-roll velocity from state, stop after
- `docs/implementation-artifacts/1-9-roll-with-iframes.md` — this record

## Change Log

- 2026-07-22: Story authored (Set B batch, before stories 1-3..1-8 were implemented).
- 2026-07-27: Readiness gate NOT READY (B1-B5); operator rulings 1-9/R1..1-9/R8 applied; story rewritten; Status backlog -> ready-for-dev.
- 2026-07-27: Dev pass complete — mechanics, tests (141/640 + 8 integration), golden re-baselined `298c40f6...` -> `33817201...` (one re-baseline; three causes reconciled both directions — cause 2 measured NON-MOVER, the 1-5 cause-(c) precedent); smoke check and close-out docs await operator review; Status ready-for-dev -> review.
- 2026-07-27: Operator smoke check PASSED (three-part protocol; part 3 confirms the 1-9/R1 drop ruling live); the flip collateral from a second editor session caught and reverted at the close-out Step 0; review approved.
