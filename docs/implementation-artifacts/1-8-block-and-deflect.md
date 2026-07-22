# Story 1.8: Block and Deflect

Status: backlog

## Story

As a player,
I want to hold block to reduce incoming damage and time a press into a deflect window to negate it entirely at a stamina cost,
so that the defensive layer is legible, the most feel-sensitive number is hot-reloadable, and the exact window boundary is asserted on ticks.

## Acceptance Criteria

1. Block is a held state: entering `BLOCKING` on hold, leaving on release, with damage multiplied by `block_damage_multiplier` when a contact resolves against a blocking target **facing the attacker**. Facing is a spatial fact — the runner reports the attacker's relative angle, state decides whether the block applies.
2. Deflect is a `TimingWindow` opened on the block press: a contact resolving inside the window is a **deflect** (no damage, stamina cost paid, `deflect_landed` queued); the same contact after the window is an ordinary block. The window length lives in balance and is tunable by hot-reload without restarting the match.
3. **The attacker's consequence on a deflect stays OUT of scope for E1.** A deflect negates damage and emits its cue; attacker stagger/punish is **not** specified in the GDD for basic attacks and must **not** be invented here. The question is logged in `decision-log.md`, not guessed at in code.
4. Deflect stamina is deducted through the 1.4 single deduction path and obeys the same lockout: with insufficient stamina the deflect window never opens and blocking degrades to plain block (with `action_rejected` emitted).
5. Headless tests: a contact one tick inside the window deflects and one tick outside blocks (the exact boundary, both sides); block reduces damage by the authored multiplier; a back-facing block does not apply; deflect at zero stamina degrades to block and emits the rejection.

## Tasks / Subtasks

- [ ] Implement held `BLOCKING` with facing-gated `block_damage_multiplier` (AC: 1)
  - [ ] Facing comes from a runner-reported spatial fact; state decides
- [ ] Implement the deflect `TimingWindow`; inside → deflect, after → block (AC: 2)
- [ ] Deduct deflect stamina via the 1.4 path; degrade to block + `action_rejected` at zero (AC: 4)
- [ ] **OPEN QUESTION — do NOT resolve:** log "attacker consequence on a deflect of a basic attack" in `decision-log.md`; implement no stagger/punish (AC: 3)
- [ ] Headless tests: exact both-side window boundary; multiplier; back-facing; zero-stamina degrade (AC: 5)

## Dev Notes

- **OPEN QUESTION (must stay OPEN, route to decision-log, do not invent):** what happens to the **attacker on a deflect of a basic attack**. The GDD does not specify stagger/punish for basic attacks; inventing one here would fabricate design. Emit the deflect cue and negate damage only; add the question to `decision-log.md`. [Source: stories-manual-e1.md#E1.S8 item 3]
- The deflect window is the single most feel-sensitive number in E1 — it must be hot-reloadable mid-match (X3). [Source: stories-manual-e1.md#E1.S8 item 2; docs/game-architecture.md#BINDING X3]
- Facing is a spatial fact (actor reports, state decides). [Source: docs/game-architecture.md#Spatial Model]

### Project Structure Notes

- `src/state/hero_state.gd` (block/deflect states + window), deflect window as `src/state/timing/timing_window.gd`, deduction via 1.4 path. Decision-log entry in `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md` (recorded, not resolved).

### Project Context Rules

- **`check_invariant`/graceful degradation:** insufficient stamina degrades, never errors. [Source: docs/game-architecture.md#Error Handling]
- Deflect/parry gets a crisp signature cue on the `CombatCues` bus (1.10). [Source: gdd.md#Audio and Music]

### References

- [Source: stories-manual-e1.md#E1.S8]
- [Source: gdd.md#Primary Mechanics — Block/Deflect; #F]
- [Source: decision-log.md#OPEN (playtest) — combat timing items]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
