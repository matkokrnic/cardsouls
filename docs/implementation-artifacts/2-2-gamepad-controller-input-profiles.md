# Story 2.2: Gamepad controller and P1/P2 input profiles

Status: backlog

## Story

As a player,
I want a gamepad controller that emits the identical `InputIntent` shape as the keyboard, with named P1/P2 action sets,
so that a gamepad drives either slot indistinguishably downstream — the equivalence that makes E7's bot a config swap.

## Acceptance Criteria

1. The P1/P2 Input Map action sets are completed for every E1 action plus the actions E3 needs (play-card, stage-card, mode-select), using named actions and physical keycodes — never raw keycodes read inline, never a second controller class per player.
2. `gamepad_controller.gd` is the second `Controller` implementation, mapping stick input to `move_dir` and buttons to the same named actions, with a deadzone value authored in config rather than hardcoded. It emits the identical `InputIntent` shape — the runner cannot tell it apart from keyboard.
3. Device assignment is explicit: which joypad device index maps to which slot, and behaviour on disconnect (the intent goes neutral; the match does not crash and does not pause). This logic lives in the controller, never in the runner or state.
4. The D3 invariant holds after adding the implementation: `grep -rn "Input\." src/` matches only under `src/controllers/`, and the architecture invariant test still passes unmodified.
5. An integration test proves a synthetic gamepad-style intent and an equivalent keyboard intent produce byte-identical `HeroState` outcomes over N ticks.

## Tasks / Subtasks

- [ ] Complete P1/P2 named Input Map action sets (E1 + E3 actions) (AC: 1)
- [ ] Implement `gamepad_controller.gd` emitting identical `InputIntent`; config deadzone (AC: 2)
- [ ] Handle device index → slot mapping and disconnect (neutral, no crash/pause) in the controller (AC: 3)
- [ ] Confirm the D3 grep + invariant test unchanged (AC: 4)
- [ ] Integration test: gamepad vs keyboard intent → byte-identical `HeroState` over N ticks (AC: 5)

## Dev Notes

- One controller class per input *kind*, taking a `"p1"`/`"p2"` prefix — never a class per player. [Source: docs/project-context.md#Platform & Build Rules]
- Input-source equivalence downstream is exactly what makes E7's scripted bot a config swap. [Source: stories-manual-e2.md#E2.S2 item 5; docs/game-architecture.md#D3]
- Disconnect handling stays in the controller (D3): the runner and state never learn about hardware. [Source: docs/game-architecture.md#D3]

### Project Structure Notes

- `src/controllers/gamepad_controller.gd`; Input Map in `project.godot` (intentional, reviewed edit); deadzone in config.

### Project Context Rules

- **D3(a):** `Input.*` only under `src/controllers/`. [Source: docs/project-context.md#Controllers & state-layer determinism]
- **Named actions, physical keycodes**; no raw keycodes inline. [Source: docs/project-context.md#Platform & Build Rules]

### References

- [Source: stories-manual-e2.md#E2.S2]
- [Source: docs/game-architecture.md#D3; #Novel Pattern 3]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
