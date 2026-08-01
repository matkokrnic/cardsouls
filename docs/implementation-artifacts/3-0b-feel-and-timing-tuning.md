# Story 3.0b: Feel and timing tuning

Status: backlog

## Story

As a solo developer building CardSouls,
I want the melee combat loop's timing, movement, and legibility judged and tuned against the real skinned rig delivered in 3-0a,
so that the five DEBT E judgments and the 3-0a live-smoke findings are resolved with logged verdicts, and combat reads correctly to a naive observer, before the card system builds on top of it.

## Acceptance Criteria

1. Deterministic step/pause exists for a running match: pause halts `advance()` ticking; single-step advances exactly one tick per press. The step/pause Input Map actions land in this story and only here — the E3 revisit gate scoped this rule: card-play actions belong to 3-5. `project.godot` edited textually with the editor closed, diff reviewed.
2. The debug instrument panel from 2-6 shows a read-only, per-slot countdown of active action windows. Channel (ruled — build exactly this): `MatchState` gains a read-only debug accessor returning plain values (per-slot window remaining in ticks); the runner polls it after each `advance()` and pushes the payload into the panel. This is debug instrumentation, NOT an eighth observation seam; no state handle enters `src/ui/` (banned-token scan stays green); the snapshot is not extended.
3. Clip vs authored window reconciliation, direction locked: animation serves gameplay timing, never the reverse — clips are trimmed/retimed to authored windows. Sole exception: a playtest verdict that an authored window itself is wrong, and that becomes a separately logged decision, never a silent retime.
4. Roll no longer detaches from the body. Criterion: the yellow roll telegraph disc reads as UNDER the character for the entire roll, in both viewports.
5. Per-phase movement multipliers (windup/active/recovery) replace the single flat `attack_move_speed_multiplier` (DEBT E member 2).
6. Attack lunge is implemented as state-side velocity, never root motion extraction (3-0a ruling, in-place rule).
7. Block in-between frames get a logged verdict. The deliverable is the decision; changing the animation is optional. Trade-off on record: today's instant pop = zero latency between press and guard.
8. The final feel/timing verdict (DEBT E member 1) is made and logged: attack tempo and roll tempo judged against live play, with the operator observation in Dev Notes as input. Outcome = decision-log entry plus any chore(balance) value edits it mandates.
9. Attack and block stings are made audibly distinct (finding S8): by sound alone a listener can tell attack from block.
10. `pose_id` gets a consumer, or an explicit logged retirement with reasoning (DEBT E member 4 names it).
11. Legibility validated with a genuine naive observer per `docs/legibility-protocol.md`: sub-0.5 s recognition, shape AND sound judged separately, half viewport. Passes only with AC9 resolved.
12. Open decision (c) — variable analog magnitude — gets its verdict. The toggle shipped in 2-6 as an authored field on `data/gamepad_profile.tres` (default = normalization); outcome logged, default confirmed or flipped.
13. Collision box height (2.0) vs paladin model height (~1.725) gets a logged verdict; the deliverable is the decision, change optional.

## Tasks / Subtasks

- [ ] Add the step/pause Input Map actions to `project.godot` (hand edit, editor CLOSED, `git diff` reviewed); gate `_match_state.advance(intents)` in `match_runner.gd` behind pause/single-step state (AC: 1)
- [ ] Add a read-only debug accessor on `MatchState` returning per-slot active-window remaining ticks (plain `Dictionary`/`Array` values, `TimingWindow.remaining_ticks()` already exists as the primitive); poll it in the runner after `advance()` and push the payload into `DebugInstrumentPanel` as a new instrument; confirm the banned-token scan (`test_architecture_invariants.gd`) and `to_snapshot()` both stay unchanged (AC: 2)
- [ ] Reconcile each non-looping clip (`attack`, `roll`, `death`) against its authored tick window — retime/trim the clip, never the window, unless a window itself is judged wrong (logged separately) (AC: 3)
- [ ] Fix the roll Hips excursion so the telegraph disc reads under the character in both viewports — either swap to a smaller-excursion roll/dodge clip, or zero the Hips XZ position track in `paladin_anims.res` while keeping Y (3-0a/R14 names both routes; do not re-attempt an In Place re-download, already ruled ineffective) (AC: 4)
- [ ] Replace `BalanceConfig.attack_move_speed_multiplier` with three per-phase fields (windup/active/recovery); read the phase via `HeroState.attack_phase()` in `match_state.gd::_resolve_movement` (AC: 5)
- [ ] Add an authored lunge displacement in balance data, applied by the state layer as a velocity curve during the attack swing (the 1-7 close-out's sanctioned form — never `AnimationPlayer`-driven root motion, which would break F1 and make replay depend on animation sampling) (AC: 6)
- [ ] Judge the block clip's instant pop against adding transition frames; log the verdict and the recorded trade-off either way; only touch the clip if the verdict says soften it (AC: 7)
- [ ] Run live play against the operator's tempo observation (Dev Notes); log the DEBT E member 1 verdict in the decision-log; apply any `chore(balance)` `.tres` edits the verdict mandates (AC: 8)
- [ ] Make the attack and block stings audibly distinct (swap/edit `assets/audio/sting_attack.wav` and/or `sting_block.wav`); re-run the legibility protocol's audio-only check to confirm discrimination (AC: 9)
- [ ] Wire `pose_id` (`TelegraphProfile`, already authored `PoseAttack`/`PoseBlock`/`PoseRoll`) to a real consumer, or log an explicit retirement with reasoning if no consumer is warranted (AC: 10)
- [ ] Run the definitive legibility protocol pass with a genuine naive observer (the previous candidate is disqualified) per `docs/legibility-protocol.md`: half viewport, shape and sound judged separately, sub-0.5 s recognition, attack-vs-block audio discrimination included; only after AC9 lands; operator writes the `docs/playtest-log.md` entry by hand (AC: 11)
- [ ] Judge open decision (c): keep `GamepadProfile.normalize_move_magnitude = true` as default, or flip it; log the verdict (AC: 12)
- [ ] Judge the collision box height (2.0, `BoxShape3D_qp0e8` in `hero.tscn`) against the paladin model height (~1.725); log the verdict; resize only if the verdict says to (AC: 13)
- [ ] Measure golden per the Golden Prediction section below (isolation runs for AC5 and AC6, one re-baseline naming both causes); confirm AC8's `.tres` edits move nothing (AC: 5, 6, 8)
- [ ] Run the Live Smoke section below; operator writes the `docs/playtest-log.md` entry by hand before the commit chain (AC: 1-13)

## Dev Notes

- **Operator tempo observation (input to AC8, not a verdict):** the attack is too fast but does not feel fast because the attack animation is too slow; the roll feels too slow.
- **Measured roll detachment:** Hips excursion ~1.27 (3D) / ~1.09 (planar XZ) — the 3-0a Dev Notes measured table (`docs/implementation-artifacts/3-0a-rig-adoption.md`, R9 evidence table). Known fix options: a clip with smaller excursion, or zeroing Hips XZ while keeping Y. This story does not pre-pick; AC4's criterion (disc reads under the character, both viewports) decides which route passes.
- **Roll clip is longer than `roll_duration`,** so it gets cut off today under the existing clip-end/mid-clip policy (3-0a/R5, story AC4: a state transition arriving mid-clip wins immediately, no blending) — input to AC3.
- **Block has no in-between frames today** — instant pop, held-pose clip (input to AC7).
- **DECISION A untouched.** `test/integration/test_root_rotation_isolation.gd` must survive; the hero root never rotates; the single `atan2` yaw seat in `HeroActor.drive()` (`hero.gd`) is not this story's to touch.
- **No eighth observation seam (AC2).** The countdown channel is exactly the runner-fed debug payload described in AC2 — a polled read-only accessor pushed by the runner after `advance()`, not a new signal seam and not a `to_snapshot()` addition. `TimingWindow.remaining_ticks()` (`src/state/timing/timing_window.gd`) already returns `maxi(0, _duration_ticks - _elapsed_ticks)` — the primitive this accessor reads per active window, per slot.
- **Input Map edits are textual, editor closed** (standing repo rule); `git diff` reviewed after. Note: `match_runner.gd`'s `_physics_process` is the ONE seat where `_match_state.advance(intents)` is called (invariant F1) — but D3(a) (`Input.* only under src/controllers/`, machine-checked by `test_architecture_invariants.gd::test_input_only_in_controllers`) means the pause/step actions cannot be read with `Input.*` directly in the runner. Read them through a controller-layer component under `src/controllers/` (mirroring the existing `KeyboardController`/`GamepadController` shape) that the runner polls for plain booleans, the same seam discipline the p1/p2 controllers already follow.
- **The legibility protocol lives in `docs/legibility-protocol.md`**, already delivered by 2-6 and rehearsed once (solo, explicitly a procedure dry run — decision-log 2-6/R20). This story runs the DEFINITIVE pass: a genuine naive observer, not the dry run. **A naive observer IS available for AC11 — the previous candidate is disqualified (he has played the game).**
- **`playtest-log.md` entries are written only by the operator, by hand, BEFORE the commit chain** — never by an agent (2-6/R11, restated at 3-0a's Live Smoke section).
- **AC5/AC6 code locations.** `src/state/match_state.gd::_resolve_movement` (~line 507-541) currently reads `balance.attack_move_speed_multiplier` uniformly across all attack phases (line 533) and has no lunge term. `HeroState.attack_phase()` (`src/state/hero_state.gd:245`) already derives `windup`/`active`/`recovery`/`windup_done`/`active_done`/`attack_done` from the three `TimingWindow`s (`windup`, `active`, `recovery`) — the per-phase multiplier lookup reads this, no new state needed. `BalanceConfig.attack_move_speed_multiplier` (`src/state/resources/balance_config.gd:43`) is the field AC5 replaces; its doc comment already flags "per-phase multipliers wait for animations" as the deferral this story pays off.
- **AC6 sanctioned form, quoted from the 1-7 close-out finding** (decision-log, Session "Story 1-7 close-out"): "the sanctioned form is an authored lunge displacement in balance data, applied by the STATE layer as a velocity curve during the swing, with the animation matching it visually." True root motion (an `AnimationPlayer` moving the `CharacterBody3D`) is explicitly rejected — it breaks F1 (presentation deciding position) and makes replay depend on animation sampling. The roll velocity override in the same function (lines 527-529: `player.hero.velocity = player.hero.roll_direction * (balance.roll_distance / balance.roll_duration_seconds)`) is the direct precedent shape for an attack-phase lunge term.
- **AC9/AC11 ordering is locked:** AC11 (definitive legibility pass) "passes only with AC9 resolved" — do the sting-distinctness pass before the naive-observer run, not after.
- **`pose_id` (AC10).** Authored today in all three `data/telegraphs/*.tres` (`PoseAttack`/`PoseBlock`/`PoseRoll`) via `TelegraphProfile.pose_id` (`src/state/resources/telegraph_profile.gd:19`, comment: "reserved vocabulary for the animation rig (DEBT E — consumed when real [rig lands])"). The rig landed in 3-0a; this story is the trigger to either wire a consumer (e.g. selecting an animation variant or blend by pose) or log why no consumer is warranted.
- **AC12 (`data/gamepad_profile.tres`).** `GamepadProfile.normalize_move_magnitude` (`src/controllers/gamepad_profile.gd`) already ships `true` as the authored default (2-6/R8) with the debug-panel toggle flipping it in memory only. This story's obligation is the VERDICT (keep or flip the default), not new plumbing — the toggle and the field already exist.
- **AC13 (collision box).** `hero.tscn`'s `Collision` node uses `BoxShape3D_qp0e8`, `size = Vector3(1, 2, 1)` — height 2.0. The paladin's actual height was measured ~1.8 at 3-0a's import check (AC2, root_scale 1.0); this story's stated figure is ~1.725 — remeasure if the two disagree materially before logging the verdict. Changing this value, if the verdict calls for it, touches `hero.tscn` only (no `src/state/` field carries a hero height).
- **Editor-collateral standing rule.** Opening the Godot editor for any reason (clip retiming, `AnimationLibrary` edits) risks deleting the `common/physics_ticks_per_second=60` pin from `project.godot` and reordering `config/features` (the fifth-and-counting recorded incident, 3-0a Dev Notes). Check `git status` after every editor session; restore `project.godot` if it moved.
- **Golden precedent for isolating two causes in one re-baseline (stamina-cost pass, BC/R3-R7, decision-log Session 2026-08-01):** authored `.tres` balance values are isolated from both the golden and the unit suite — `_golden_config()` in `test_determinism.gd` builds its own in-test `BalanceConfig` literals, never loading `data/balance/balance_config.tres`. That isolation covers VALUES only (AC8's tuning edits) — it does NOT cover a change that adds a new movement-multiplier seat or a new velocity term (AC5, AC6), both of which move the golden once `_golden_config()` is given non-neutral values for the new fields.

### Non-goals (hard)

- Card-play Input Map actions (mode select, play/stage/cancel) — those belong to 3-5 (E3-RG/R7 scopes the "Input Map lands here and only here" rule to this story's step/pause actions alone; it does not freeze the Input Map for the rest of the epic).
- A `FeatureFlags` overlay for anything touched here — `FeatureFlags` stays load-once and runtime-immutable (2-6/R4, locked); the debug panel's switches are presentation/controller-local only, never a flag.
- Any new observation seam beyond the AC2 polled debug accessor — no eighth seam, no `to_snapshot()` extension.
- Card system work of any kind (deck, hand, mana, card HUD) — this story is melee-only, ahead of the card stories per the E3 revisit gate's ORDER ruling.

### Project Structure Notes

- `project.godot` — new step/pause Input Map actions (AC1). Hand edit, editor closed, diff reviewed. No other Input Map or `config/features` change.
- `src/controllers/` — new component reading the step/pause actions (`Input.*` stays confined here per D3(a)); the runner polls it, mirroring the existing controller pattern.
- `src/main/match_runner.gd` — `_physics_process` gates `_match_state.advance(intents)` on pause/step (AC1); polls the new `MatchState` debug accessor and pushes the payload to `DebugInstrumentPanel` after `advance()` (AC2).
- `src/state/match_state.gd` — new read-only debug accessor (AC2, no snapshot change); `_resolve_movement` gains per-phase multiplier lookup (AC5) and a lunge velocity term during the attack swing (AC6).
- `src/state/resources/balance_config.gd` / `data/balance/balance_config.tres` — `attack_move_speed_multiplier` replaced by three per-phase fields (AC5); new lunge field(s) (AC6); any AC8 tuning edits.
- `src/ui/debug/debug_instrument_panel.gd` — new read-only countdown instrument (AC2), following the existing switch-instrument pattern; no state handle.
- `assets/characters/paladin/` — clip retiming/trimming (AC3), roll Hips-track fix (AC4), block transition frames if the AC7 verdict calls for it.
- `assets/audio/sting_attack.wav` / `sting_block.wav` — made audibly distinct (AC9).
- `src/state/resources/telegraph_profile.gd` / consumer site — `pose_id` wired or retired (AC10).
- `data/gamepad_profile.tres` — AC12 verdict, default confirmed or flipped.
- `src/actors/hero/hero.tscn` — collision box height, only if the AC13 verdict calls for a resize.
- `docs/legibility-protocol.md` — the definitive pass's result recorded per its existing table format (AC11).
- `docs/playtest-log.md` — operator's hand, before the commit chain (AC8, AC11, Live Smoke).

### Project Context Rules

- **`Input.*` only under `src/controllers/`; no global RNG / `Time` / `OS` / `Engine` in `src/state/`.** [Source: docs/game-architecture.md — invariants D3, A2] Directly load-bearing for AC1: the step/pause actions must be read through a controller-layer component, not inline in `match_runner.gd`.
- **Exactly one `_physics_process` in `src/`, in `match_runner.gd` (F1).** Pause/step gates the existing call to `advance()`; it does not add a second physics loop. [Source: docs/game-architecture.md — invariant F1]
- **Presentation reads state through runner-wired seams; visuals → state is the only allowed dependency direction — never a state handle, never a mutator.** The AC2 countdown is a plain-value payload the runner pushes, not a handle into `src/ui/`. [Source: docs/project-context.md — Signals over polling; Architectural Boundaries]
- **`.tscn`/`project.godot` edits are textual with the editor closed; `git status` checked after any editor scan and `project.godot` restored if the tick-rate pin or `config/features` order moved.** [Source: CLAUDE.md — Git discipline; standing repo rule; 3-0a Dev Notes editor-collateral incident]
- **Docs and code never share a commit.** [Source: CLAUDE.md — Commit conventions]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:87-89 — E3 committed obligations, DEBT E split]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — E3-P/R2 (DEBT E split across the two rig stories), E3-P/R6 (rig story authorship, Golden Prediction + Live Smoke required), E3-RG/R7 (Input Map ownership scoped to this story's step/pause actions), E3-RG/R11 (Golden Prediction + Live Smoke sections not negotiable)]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — 1-10/R4 (DEBT E registry, its four members), 2-6/R3 (step/pause rerouted here), 2-6/R7 (window countdown deferred here, NO EIGHTH SEAM), 2-6/R19 S8 finding, 2-6/R20 (legibility dry-run vs definitive verdict), 2-6/R8 (analog-magnitude toggle), 599/OPEN DECISION (c)]
- [Source: docs/implementation-artifacts/3-0a-rig-adoption.md — Dev Notes Hips-track measured table (3-0a/R9 evidence), 3-0a/R13 (three live-smoke findings), 3-0a/R14 (In Place correction)]
- [Source: docs/legibility-protocol.md — the repeatable procedure, rehearsal notes, deviation requirement]
- [Source: src/state/hero_state.gd#attack_phase — windup/active/recovery phase derivation]
- [Source: src/state/match_state.gd#_resolve_movement — current flat multiplier + roll velocity-override precedent]
- [Source: src/state/timing/timing_window.gd#remaining_ticks — AC2's debug-countdown primitive]
- [Source: src/controllers/gamepad_profile.gd#normalize_move_magnitude — AC12's existing toggle]
- [Source: src/ui/debug/debug_instrument_panel.gd — AC2's instrument pattern, no state handle]
- [Source: test/state/test_architecture_invariants.gd — F1, D3(a), D3(b)/A2 guards]

## Golden Prediction

- **MOVES — third re-baseline ever, with exactly TWO named causes: AC5 (per-phase movement multipliers) and AC6 (attack lunge velocity), both state-side, both exercised by the golden fixture once the in-test golden config gives them non-neutral values** (the stamina-cost precedent, decision-log BC/R3-R7).
- **Interim measurement between the two causes (isolation runs)** so each is attributed separately: measure after AC5 lands alone, then again after AC6 lands, so the re-baseline record names both causes distinctly rather than conflating them.
- **AC8 tuning of authored `.tres` values does NOT move the golden** — `test_determinism.gd`'s `_golden_config()` builds its fixture in-test and never loads `data/balance/balance_config.tres` (proven on the melee-damage corrective pass; restated at the stamina-cost pass, BC/R3). If the golden moves from anything other than the two named causes (AC5, AC6), stop and report — do not silently re-baseline a third time.
- **Baseline to hold going in:** golden hash `7fbb4b7f589251d25a13d6b49138b416266031e124cdae1c07e99e0f4fc119d1`; 169 state tests / 784 assertions / 0 failed; 10 integration files run individually, all green (measured at story creation).

## Live Smoke

- **Two-human smoke on the delivered default config** (`slot_controller_kinds` default = both keyboard slots), zero `.tscn` edits. R-D6 smoke acceptance is re-invoked on this story's gate (live smoke against killable human slots).
- **Naive-observer legibility run per `docs/legibility-protocol.md`:** half viewport, shape and sound judged separately, sub-0.5 s recognition, including attack-vs-block audio discrimination (S8). The playtest-log entry is the operator's hand.
- **What is checked beyond the protocol:** the roll disc reads under the character for the whole roll in both viewports (AC4); pause/single-step work against a live match (AC1); the debug panel's window countdown displays plausible, decreasing values per slot (AC2); attack tempo and roll tempo read as intended per the AC8 verdict.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (this story-creation pass; the repo's commit trailer / Change Log authorship
convention below stays the separately-ruled constant "Claude Opus 4.8" — not re-raised here).

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-01 | 0.1 | Story created (backlog): ACs 1-13 verbatim from the operator's readiness-gate scope, Golden Prediction + Live Smoke sections; Dev Notes ground each AC in the current repo (attack_phase() phase derivation, TimingWindow.remaining_ticks(), the D3(a)/F1 constraint on where step/pause input is read, the already-shipped normalize_move_magnitude and pose_id fields). Status stays backlog pending this story's own readiness gate. | Claude Opus 4.8 |
