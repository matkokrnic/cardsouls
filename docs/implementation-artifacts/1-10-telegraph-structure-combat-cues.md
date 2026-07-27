# Story 1.10: Telegraph structure and combat cues (presentation layer)

Status: ready-for-dev

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

- [ ] Create `src/state/resources/telegraph_profile.gd` (D7 schema home), THEN author `TelegraphProfile` `.tres` for each E1 melee action in `data/telegraphs/`; exported controller-owned `ActionState` -> profile map (AC: 1)
- [ ] Define the audio bus layout (`CombatCues` + `Music` + `Ambience`) saved at `res://default_bus_layout.tres`; route combat cues through `CombatCues` (AC: 2)
- [ ] Land the owed seams `connect_hero_action_rejected` + `connect_deflect_landed` in `match_runner.gd`; wire the telegraph controller as first consumer of both (AC: 3)
- [ ] Implement read-only `telegraph_controller.gd` consuming only the sanctioned channels (AC: 4)
- [ ] Land the deflect spark + sting FIRST, then hit reaction and remaining outcome cues (AC: 5)
- [ ] Extend `test_architecture_invariants.gd` with the cues-layer banned-token scan (AC: 6)
- [ ] Run the two-phase live smoke per the protocol below (AC: 5, 6)

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

### Debug Log References

### Completion Notes List

### File List
