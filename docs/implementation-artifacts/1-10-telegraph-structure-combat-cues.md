# Story 1.10: Telegraph structure and combat cues (presentation layer)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want every E1 action to carry a `TelegraphProfile` and a distinct audible cue on a dedicated `CombatCues` bus, driven entirely by queued state signals,
so that after every exchange I can say what happened, and the legibility structure E5 reuses exists from the start.

## Acceptance Criteria

1. `TelegraphProfile` `.tres` instances for the E1 melee actions are authored in `data/telegraphs/` (`shape_id`, `sting_id`, `color`, `pose_id`), referenced by the action, not embedded in it. `TelegraphProfile` is standalone so E5's colour telegraphs reuse the same type.
2. The audio bus layout has a dedicated **`CombatCues`** bus, separate from `Music` and `Ambience`, so functional cues cannot be masked. Attack/hit/deflect/roll and the `action_rejected` cue route through it. Placeholder sounds are fine; the bus layout is not.
3. `telegraph_controller.gd` in `src/actors/hero/` is a **read-only** subscriber to the state signals from 1.3–1.9. It reads which telegraph is active and drives shape + sound. It never calls a state mutator and never decides an outcome — the dependency direction is visuals → state, always.
4. The deflect spark, hit reaction, and outcome cues land now (loss legibility is mandatory per GDD Success Metrics — E1 is where the habit is established, not retrofitted).
5. Verification is of direction, not aesthetics: an integration test (or the architecture invariant test) asserts nothing under `src/actors/**/telegraph_controller.gd` or `src/ui/` calls a state mutator, plus a manual check that every E1 action produces a distinct audible cue on `CombatCues`.

## Tasks / Subtasks

- [ ] Author `TelegraphProfile` `.tres` for each E1 melee action in `data/telegraphs/` (AC: 1)
- [ ] Define the audio bus layout with a dedicated `CombatCues` bus; route combat cues (AC: 2)
- [ ] Implement read-only `telegraph_controller.gd` subscribing to 1.3–1.9 state signals (AC: 3)
- [ ] Land deflect spark, hit reaction, outcome cues (AC: 4)
- [ ] Assert presentation never mutates state; verify distinct cue per action (AC: 5)

## Dev Notes

- This is **structure, not polish** (D7): it exists in E1 so E5's colour telegraphs reuse the same `TelegraphProfile` type and `CombatCues` bus rather than forcing a retrofit. State owns *which* telegraph is active; the controller only reads. [Source: docs/game-architecture.md#D7; #BINDING D7]
- Dependency direction is strictly visuals → state; the telegraph controller is presentation-only under D5. [Source: docs/game-architecture.md#Architectural Boundaries]
- Loss legibility is mandatory (Success Metrics): after every exchange the player must be able to say what happened. [Source: gdd.md#Success Metrics; #Legibility Principle]

### Project Structure Notes

- `src/actors/hero/telegraph_controller.gd` (read-only), profiles in `data/telegraphs/`, bus layout in the Godot audio bus config. Direction check can extend `test/state/test_architecture_invariants.gd` or an integration test.

### Project Context Rules

- **State/visual separation HARD RULE:** presentation reads signals, never mutates state. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Telegraph = shape + sound, not hue alone** (colorblind-safe, <0.5s). [Source: gdd.md#Legibility Principle]

### References

- [Source: stories-manual-e1.md#E1.S10]
- [Source: docs/game-architecture.md#D7; #BINDING D7]
- [Source: gdd.md#Legibility Principle; #Audio and Music]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
