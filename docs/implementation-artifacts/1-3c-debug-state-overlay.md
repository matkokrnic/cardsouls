# Story 1.3c: Debug state overlay

Status: backlog

## Story

As the solo developer,
I want an on-screen debug overlay showing each hero's current action state,
so I can hand-feel the 1-3 state machine (windup, chain window, roll-cancel timing) before 1-4 builds stamina costs on those durations.

## Acceptance Criteria

1. A debug overlay (CanvasLayer with two Labels, one per player) displays each hero's current action state name, updated EXCLUSIVELY via `match_runner.connect_hero_action_state_changed`. No MatchState handle, no polling, no reading runner privates. The chain self-transition (ATTACKING -> ATTACKING) must be visibly distinguishable — e.g. the label shows a swing counter that increments on the self-transition and resets on any exit from ATTACKING. Everything shown must be derivable from the signal arguments alone.
2. The seam gains its first-consumer obligation from the decision-log (Session 2026-07-24): assert `slot` is 0 or 1 in `connect_hero_action_state_changed` (today any slot != 0 silently maps to p2). This RETIRES that obligation — the Dev Agent Record must say so, and the close-out marks it retired in the decision-log.
3. Zero state-layer changes: no edits under `src/state/`. The overlay is debug tooling, not gameplay. See the EXPLICIT FENCE in Dev Notes: E2 builds the real HUD; this overlay stays a throwaway debug tool.
4. Full suite stays green and the determinism golden hash does NOT move — the overlay lives outside the state layer, so ANY golden movement is a defect, not a re-baseline.

## Tasks / Subtasks

- [ ] Overlay node (AC: 1)
  - [ ] CanvasLayer + two Labels (one per player slot) showing the current action state NAME; state derived from the signal's `(previous, current)` arguments only
  - [ ] Swing counter per label: increments on the ATTACKING -> ATTACKING self-transition, resets on any exit from ATTACKING — the chain must be visibly distinguishable
- [ ] Seam assert — first-consumer obligation (AC: 2)
  - [ ] `assert`/guard in `connect_hero_action_state_changed` that `slot` is 0 or 1; record the obligation as RETIRED in the Dev Agent Record
- [ ] Runner wiring (AC: 1, 3)
  - [ ] The runner instantiates the overlay and wires both slots via the seam ("the runner wires subscriptions"); overlay never touches MatchState or runner privates
  - [ ] No edits under `src/state/`
- [ ] Verification (AC: 4)
  - [ ] `bash test/run_all.sh` green; golden hash unmoved (any movement is a defect, not a re-baseline)
  - [ ] Manual smoke check: run the main scene; press attack (single + chained), roll (including a recovery roll-cancel), and block on p1 while p2 blocks — verify both labels track the transitions and the swing counter distinguishes the chain. Record the observed behavior in the Dev Agent Record.

## Dev Notes

- **EXPLICIT FENCE:** E2 builds the real HUD. This overlay stays a THROWAWAY debug tool and may be deleted or replaced then — E2 stories must still consume the seam (`connect_hero_action_state_changed`), not copy this overlay's internals.
- Labels initialize to IDLE at match start: the signal only fires on transitions, so the overlay must not wait for a first emission to show something sane.
- The runner instantiates and wires the overlay — consistent with the architecture rule that the runner wires signal subscriptions; the overlay receives callbacks, never a state handle.
- Node location: under `src/main/` or `src/debug/` — dev's choice, noted in the File List.
- Everything displayed must be derivable from the signal arguments alone (`previous`, `current`): the swing counter is derived (increment on self-transition, reset on exit), never read from state.

### Project Structure Notes

- `src/main/match_runner.gd` — the slot assert (AC 2) + overlay instantiation/wiring.
- New overlay script/scene under `src/main/` or `src/debug/` (dev's choice, noted in the File List).
- No files under `src/state/` may change (AC 3).
- `test/state/test_determinism.gd` — must NOT change; the golden stands.

### References

- [Source: decision-log.md#Session 2026-07-24 — Story 1-3b close-out — observation seam locked + first-consumer obligation]
- [Source: decision-log.md#Session 2026-07-23 — Story 1-3 close-out — the state machine being observed]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log
