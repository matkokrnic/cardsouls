# Story 1.10: Telegraph structure and combat cues (presentation layer)

Status: done

## Story

As a player,
I want every E1 action to carry a `TelegraphProfile` and a distinct audible cue on a dedicated `CombatCues` bus, driven entirely by queued state signals,
so that after every exchange I can say what happened, and the legibility structure E5 reuses exists from the start.

## Acceptance Criteria

1. `src/state/resources/telegraph_profile.gd` is created FIRST (`class_name TelegraphProfile`, `extends Resource`; exported `shape_id: StringName`, `sting_id: StringName`, `color: Color`, `pose_id: StringName`), per the architecture Directory Tree (the D7 schema home) — the `.tres` instances have no class to instance without it. Then `TelegraphProfile` `.tres` instances for the E1 melee actions are authored in `data/telegraphs/`. The `ActionState` -> `TelegraphProfile` mapping is CONTROLLER-OWNED (gate ruling 1-10/R1): exported on the telegraph controller, presentation side — no state object ever references a `TelegraphProfile`. `TelegraphProfile` is standalone so E5's colour telegraphs reuse the same type.
2. The audio bus layout has a dedicated **`CombatCues`** bus, separate from `Music` and `Ambience`, so functional cues cannot be masked. Attack/hit/deflect/roll and the `action_rejected` cue route through it. Placeholder sounds are fine; the bus layout is not. The layout is saved at the DEFAULT path `res://default_bus_layout.tres` — no `project.godot` edit needed or wanted; any `project.godot` diff at review is automatically suspect.
3. The two owed runner seams land here: `connect_hero_action_rejected(slot, callback)` (HeroState-owned signal, per-slot, mirroring `connect_hero_action_state_changed` including the slot `Invariant.check`) and `connect_deflect_landed(callback)` (MatchState-owned, match-level, mirroring `connect_hit_landed`). The telegraph controller is the first consumer of BOTH. Neither seam nor consumer ever touches `_match_state`. [Source: decision-log — 1-4 gate `action_rejected` seam obligation; 1-8 R-D4]
4. `telegraph_controller.gd` in `src/actors/hero/` is a **read-only** subscriber consuming EXCLUSIVELY the sanctioned channels: `connect_hero_action_state_changed`, `connect_hit_landed`, the two new seams from AC 3, and `EventBus.round_ended` for the round-end cue — the queued state signals from 1-3..1-8 (1-9 deliberately shipped none — 1-9/R5). No other channel; no `_match_state`; no state-object handles. It reads which telegraph is active and drives shape + sound. It never calls a state mutator and never decides an outcome — the dependency direction is visuals → state, always.
5. The deflect spark + sting is the story's FIRST-PRIORITY deliverable (1-8 close-out finding: the parry is hard to time with no feedback — the deflect was observable only as the absence of a number). Hit reaction and the remaining outcome cues follow (loss legibility is mandatory per GDD Success Metrics — E1 is where the habit is established, not retrofitted).
6. Verification is of direction, not aesthetics: `test/state/test_architecture_invariants.gd` gains a FOURTH test — a banned-token scan asserting nothing under `src/actors/**/telegraph_controller.gd` or `src/ui/` calls a state mutator (the exact token list is a dev-pass decision; the MECHANISM is fixed here — no "integration test or invariant test" ambiguity). The manual per-action cue check belongs to the live smoke below.

## Tasks / Subtasks

- [x] Create `src/state/resources/telegraph_profile.gd` (D7 schema home), THEN author `TelegraphProfile` `.tres` for each E1 melee action in `data/telegraphs/`; exported controller-owned `ActionState` -> profile map (AC: 1)
- [x] Define the audio bus layout (`CombatCues` + `Music` + `Ambience`) saved at `res://default_bus_layout.tres`; route combat cues through `CombatCues` (AC: 2)
- [x] Land the owed seams `connect_hero_action_rejected` + `connect_deflect_landed` in `match_runner.gd`; wire the telegraph controller as first consumer of both (AC: 3)
- [x] Implement read-only `telegraph_controller.gd` consuming only the sanctioned channels (AC: 4)
- [x] Land the deflect spark + sting FIRST, then hit reaction and remaining outcome cues (AC: 5)
- [x] Extend `test_architecture_invariants.gd` with the cues-layer banned-token scan (AC: 6)
- [x] Run the two-phase live smoke per the protocol below (AC: 5, 6) — operator-run, after review (1-10/R3)

## Golden Prediction

**NONE** — conditional on 1-10/R1 (controller-owned mapping; no state-side profile reference) and 1-10/R2 (no dodge cue). Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` is measured BEFORE the first edit and AFTER the last, in BOTH directions; it must be identical; never re-baselined. State harness green both runs; integration files run individually. Precedents: 1-6, 1-7b. Any dev-pass desire for a new signal (dodge or otherwise) is a SCOPE STOP, not an implementation decision.

## Live Smoke (single-use acceptance, gate ruling 1-10/R3)

The spent R-D6 acceptance is re-invoked for THIS story only, consumed on use. The rejection cue is self-triggerable (P1 rolls its own stamina below `deflect_stamina_cost`, then enters block — the degraded entry emits `action_rejected`) and the hit-reaction cue is observable on the dummy (P1 swings, the dummy is the `hit_landed` target), so the protocol is TWO-PHASE to minimize time in the flipped state:

- **Phase 1 (NO flip, shipped defaults):** roll sting on entry; rejection cue via self-drain; hit-reaction cue on the dummy; first distinctness pass by ear.
- **Phase 2 (KEYBOARD_P2 flip on runner slot 1, exported `slot_controller_kinds`; shipped default stays P2 = NULL):** deflect spark + sting (P2 swings, P1 timed block) clearly distinct from the block chip (with the reduced number via the throwaway HitLabel); a successful dodge produces NO cue (deliberate — absence is the correct observation); final distinctness check: every E1 action identifiable by ear alone on the `CombatCues` bus.

DEAD-slot residuals (a dead hero can walk; a corpse mid-swing can be credited damage/mana) are ACCEPTED for the supervised smoke only; the fix trigger remains story 2-3, unchanged. Binding procedure (1-9 close-out): after every smoke flip, revert BOTH collateral files by full path (`git checkout -- src/main/main.tscn project.godot`) with a look at the `git diff project.godot` first, AND re-verify `git status` + the collateral diff IMMEDIATELY before any commit chain begins, not earlier in the session. Editor dialog: always "Reload from disk", never "Ignore external changes".

## Dev Notes

- This is **structure, not polish** (D7): it exists in E1 so E5's colour telegraphs reuse the same `TelegraphProfile` type and `CombatCues` bus rather than forcing a retrofit. State owns *which* telegraph is active; the controller only reads. [Source: docs/game-architecture.md#D7; #BINDING D7]
- Dependency direction is strictly visuals → state; the telegraph controller is presentation-only under D5. [Source: docs/game-architecture.md#Architectural Boundaries]
- Loss legibility is mandatory (Success Metrics): after every exchange the player must be able to say what happened. [Source: gdd.md#Success Metrics; #Legibility Principle]
- **Ruling 1-10/R1 — mapping home:** the `ActionState` -> `TelegraphProfile` map is controller-owned (exported on the controller); state untouched. E5 reuse note: in E5, state will own "which telegraph/color is active" as a gameplay fact (required for RPS resolution), but the fact -> profile translation stays presentation, same seam pattern as now.
- **Deliberate omission (1-10/R2):** no dodge cue in 1-10 (1-9/R5). An iframe drop stays signal-less; revisit at 2-6 with playtest evidence.
- **Fences:** 1-10 ships NO code under `src/ui/` — bars, readouts, and HUD are E2 territory (E2 fence). `debug_state_overlay.gd` is throwaway and is neither extended nor imitated — the cues layer is a parallel consumer of the same seams.
- **Cues layer home:** `src/actors/hero/telegraph_controller.gd`, attached as a per-hero node inside `hero.tscn`; `AudioStreamPlayer` children targeting the `CombatCues` bus; spark/reaction VFX as sibling child nodes (FacingMarker precedent: authored in-scene, no import pipeline where avoidable); wired by the runner through the four connect seams, signal payloads only, never a state handle. **HARD CONSTRAINT:** the controller must NOT declare `_physics_process` — the F1 invariant scan covers all of `src/` and would fail the suite; presentation timing uses `_process`, tweens, or the audio players themselves.
- **Audio note:** buses created via the editor Audio panel, layout saved at the default path (AC 2). Placeholder audio goes through the import pipeline (editor scan) — same collateral hazard as below.
- **Dev-time `.uid` note:** new `.gd` files get `.uid` only via the sanctioned editor scan (`godot --headless --editor --quit --path .`) with a post-scan check that nothing else was rewritten; the 1-9 editor-collateral rule binds the whole dev pass.

### Project Structure Notes

- Schema: `src/state/resources/telegraph_profile.gd` (D7 home); profiles in `data/telegraphs/`; controller: `src/actors/hero/telegraph_controller.gd` (read-only, per-hero node in `hero.tscn`); bus layout at `res://default_bus_layout.tres`. The direction check extends `test/state/test_architecture_invariants.gd` (fourth test — mechanism fixed at the gate).

### Project Context Rules

- **State/visual separation HARD RULE:** presentation reads signals, never mutates state. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Telegraph = shape + sound, not hue alone** (colorblind-safe, <0.5s). [Source: gdd.md#Legibility Principle]

### References

- [Source: stories-manual-e1.md#E1.S10]
- [Source: docs/game-architecture.md#D7; #BINDING D7]
- [Source: gdd.md#Legibility Principle; #Audio and Music]
- [Source: decision-log.md#Session 2026-07-27 — Story 1-10 readiness gate (operator decisions)]

## Dev Agent Record

### Agent Model Used

Claude Fable 5 (claude-fable-5)

### Debug Log References

- Baseline harness (BEFORE first edit): 141 tests / 640 assertions, PASS; `test_state_matches_golden` green against the pinned `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`.
- Bus layout headless check (scratchpad script, not committed): `bus_count=4 names=Master, CombatCues, Music, Ambience`, CombatCues sends to Master — the DEFAULT path loads with zero `project.godot` edit.
- Editor scan (`godot --headless --editor --quit --path .`): exit 0, no errors; produced ONLY the two new `.gd.uid` files and the seven `.wav.import` files. `git diff -- src/main/main.tscn` and `git diff -- project.godot` both EMPTY — zero collateral this pass.
- Bite proof (AC 6): planted `hero_state.take_damage(1.0)` in `telegraph_controller.gd`; harness failed exactly there — `assert_eq: got 1, expected 0 (state mutator token in the read-only cues/ui layer: res://src/actors/hero/telegraph_controller.gd:130 [take_damage(] hero_state.take_damage(1.0))`, `=== 142 tests, 1 failed ===`, exit 1. Plant removed; suite green again.
- Final harness (AFTER last edit): 142 tests / 645 assertions, PASS; golden BYTE-IDENTICAL (prediction NONE confirmed in both directions). Assertion delta 640 -> 645 fully accounted: +2 from the new invariant test, +3 from `test_every_data_tres_loads` asserting per authored `.tres` (the three new telegraph profiles — which also proves they load headless).
- All 8 integration tests run INDIVIDUALLY: PASS, exit 0 each (camera_relative, root_rotation_isolation, hero_movement, live_attack, debug_overlay, contact_pipeline, visible_facing, roll_displacement); logs clean of script errors.
- Windows note: `godot.exe` detaches stdout in this shell; harness runs used `C:\Godot\godot_console.exe` (same binary family, console subsystem) to capture output.
- Live smoke (2026-07-27, two-phase per 1-10/R3, operator-run): **Phase 1 (no flip)** — attack cone + sting PASS; chain re-sting CONFIRMED (static cone, one sting per chained swing); roll sting PASS; block shield + sting PASS; rejection buzz PASS; hit reaction PASS; round-end cue plays exactly once. **Phase 2 (KEYBOARD_P2 flip on slot 1, since reverted)** — deflect spark + ping with NO hit reaction PASS; block chip thud + flash PASS. Zero collateral after the revert (`main.tscn` and `project.godot` clean, verified by `git status` + diff). ONE finding: **S1 — RollDisc invisible** (CylinderMesh radius 0.45 < hero BoxMesh half-extent 0.5, at y -0.9 entirely inside the opaque body box — occluded from every angle).
- S1 fix pass (2026-07-27, same day, text edit to `hero.tscn` only — no editor invocation, no new files): `CylinderMesh_tgdisc` top/bottom radius 0.45 -> 0.8, RollDisc origin y -0.9 -> -0.95. Post-fix re-verify: harness 142 tests / 645 assertions PASS, `test_state_matches_golden` and `test_cues_layer_never_calls_state_mutators` green, golden constant untouched; all 8 integration tests individually PASS exit 0. Disc re-smoke still pending (the live-smoke task stays unticked until then).
- Disc re-smoke (2026-07-27, post-S1 fix, operator-run, no flip, no editor): PASS — colored ring visible around the hero base during the roll, clears on roll end.

### Completion Notes List

- **Delegated decision — banned-token list (AC 6):** the list is the state layer's public MUTATOR surface plus the handle tokens that make it reachable: MatchState (`advance(`, `drain_signals(`, `push_contact(`, `apply_balance(`, `inject_feature_flags(`, `set_camera_basis(`, `MatchState.new`, `_match_state`), HeroState (`take_damage(`, `heal(`, `set_max_hp(`, `set_action_state(`, `reject_action(`, `enter_attack(`, `chain_attack(`, `enter_roll(`, `enter_block(`, `register_swing_hit(`, `tick_timers(`), pools (`spend(`, `add(`, `refill(`, `set_maximum(`, `advance_regen(`, `reset_all(`). Rationale: reads stay legal (the guard is on WRITES — D5 direction, not data access); generic-looking tokens are kept deliberately because a false positive fails loudly and costs a rename, while a missed mutator costs the invariant; `TimingWindow.start(`/`tick(` are omitted because they are unreachable without a handle token that is already banned, and `.start(`/`.tick(` would false-positive on legitimate presentation Timers/tweens. The test also asserts `telegraph_controller.gd` EXISTS under `src/actors/`, so a rename cannot silently un-guard the layer. Mechanism = the F1 scan's contains-on-comment-stripped-lines, per the gate.
- **R1 map shape (implementation choice):** the controller-owned exported map is THREE named `TelegraphProfile` exports (`attack_profile` / `block_profile` / `roll_profile`) folded into a `Dictionary[HeroState.ActionState, TelegraphProfile]` in `_ready()`, rather than one exported typed Dictionary — hand-authored `.tscn` serialization of typed dictionaries is fragile, named slots are self-documenting, and the map still lives exclusively on the controller (1-10/R1 intact). Only the three REACHABLE E1 acting states are mapped (STUNNED is unreachable, CHARGING is E5, IDLE/DEAD deliberately cue-less).
- **Profile indirection:** `shape_id`/`sting_id` name the controller's child nodes (`Shapes/<shape_id>`, `<sting_id>` AudioStreamPlayer), so swapping a cue is a data edit. `pose_id` is authored (`PoseAttack`/`PoseBlock`/`PoseRoll`) but consumed by nothing until the animation rig lands (DEBT E member 4).
- **Telegraph shapes are non-yawing root-relative markers** (attack cone + block shield overhead, roll disc underfoot): nothing in the cues layer rotates, so the 1-7b single-yaw-source contract holds — no second `atan2` anywhere. Tint via per-instance `material_override` built in `_ready()` (unshaded; no shared sub-resource material, so the two heroes cannot cross-tint).
- **Slot identity stays out of the controller:** match-level payloads (`hit_landed`, `deflect_landed`, `round_ended`) get the hero's slot BOUND as a trailing arg at wiring time (the overlay precedent); the controller compares payload slots against it and holds no state.
- **Round-end cue** plays on the LOSING hero's controller only — one audible cue, no doubling across the two per-hero controllers (implementation choice; revisit if a match-level cue host ever exists).
- **Deflect spark + sting landed first** (AC 5 priority), then hit reaction (thud + red flash on the TARGET), then the remaining cues (per-action stings, rejection buzz, round-end). All timing is tweens/audio players — NO `_physics_process` (F1 hazard closed), no code under `src/ui/` (E2 fence), no new signals (1-10/R2 — no dodge cue; the iframe drop stays signal-less).
- **Placeholder audio:** seven tiny generated PCM wavs (distinct pitch/timbre per cue: 880 Hz attack, 523 Hz block, 349->494 Hz roll sweep, bright 1568+2093 Hz deflect ping, 160->90 Hz hit thud, 196 Hz square reject buzz, 784->392 Hz round-end fall). The generator script was scratchpad-only (validation-by-script, not worth a committed test — the committed artifact is the wavs plus the `.tres` load audit).
- The two seam docstrings in `match_runner.gd` record the obligations they retire (1-4 gate `action_rejected` seam; 1-8 R-D4 `deflect_landed` consumer/seam).
- State layer untouched except the data-only `telegraph_profile.gd` (its D7 schema home); no snapshot change, no `advance()` change — golden hash identical both directions.
- **Smoke finding S1 (fixed):** the RollDisc telegraph was authored radius 0.45 at y -0.9 — smaller than the hero BoxMesh half-extent (0.5) and fully inside the opaque body box, so it was occluded from every angle. Fix: radius 0.8, y -0.95 — the disc must EXCEED the box half-extent to read as a colored ground ring around the hero's base; it now protrudes 0.3 beyond the body just above floor level. Scene-text-only change; verified by the full re-run (harness + 8 integration tests green, golden untouched).

### File List

- `src/state/resources/telegraph_profile.gd` — NEW (D7 schema; AC 1)
- `src/state/resources/telegraph_profile.gd.uid` — NEW (editor scan)
- `data/telegraphs/attack.tres`, `data/telegraphs/block.tres`, `data/telegraphs/roll.tres` — NEW (AC 1)
- `default_bus_layout.tres` — NEW (AC 2; default path, no `project.godot` edit)
- `assets/audio/sting_attack.wav`, `sting_block.wav`, `sting_roll.wav`, `cue_deflect.wav`, `cue_hit.wav`, `cue_reject.wav`, `cue_round_end.wav` (+ their seven `.import` files) — NEW (AC 2 placeholder cues)
- `src/actors/hero/telegraph_controller.gd` — NEW (AC 4/5)
- `src/actors/hero/telegraph_controller.gd.uid` — NEW (editor scan)
- `src/actors/hero/hero.tscn` — MODIFIED (TelegraphController node + AudioStreamPlayer children on CombatCues + in-scene primitive VFX; AC 4/5)
- `src/actors/hero/hero.gd` — MODIFIED (`telegraph_controller` @onready exposure for runner wiring)
- `src/main/match_runner.gd` — MODIFIED (two new seams + five-channel wiring of both controllers; AC 3)
- `test/state/test_architecture_invariants.gd` — MODIFIED (fourth test: cues-layer banned-token scan; AC 6)
- `docs/implementation-artifacts/1-10-telegraph-structure-combat-cues.md` — MODIFIED (this record)

## Change Log

- 2026-07-27 — Dev pass (no commits): ACs 1-6 implemented and verified headless (harness 142/645 green, golden identical both directions, 8/8 integration tests individually green, invariant-test bite proven). Live smoke (two-phase, 1-10/R3) deliberately NOT run — operator-owned, post-review. Status left at ready-for-dev pending review verdict.
- 2026-07-27 — Smoke fix pass S1 (no commits): live smoke passed both phases except S1 (RollDisc occluded inside the body box); fixed by scene-text edit to `hero.tscn` (disc radius 0.45 -> 0.8, y -0.9 -> -0.95). Re-verified: harness 142/645 green with golden untouched, 8/8 integration tests individually green. Disc re-smoke pending; live-smoke task checkbox deliberately left unticked.
- 2026-07-27 — Disc re-smoke PASS; live smoke fully complete. Story enters the commit chain.
