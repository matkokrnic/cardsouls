# Story 2.3: Opponent slot becomes a second human

Status: backlog

## Story

As two players,
I want the opponent slot to become a second human purely by changing slot 1's controller kind at the single 1.6 config point,
so that human-vs-human melee is achieved with no hero/actor/state edit, and the first real feel notes get written down.

## Acceptance Criteria

1. Slot 1's controller changes from `NullController` to a real controller through the single configuration point built in 1.6 — and this is the **entire** change required in `src/`. Any additional edit to hero, actor, or state code is a defect in the 1.6 seam; fix the seam, not the symptom.
2. A lightweight match-setup selection (a small pre-match scene or config resource) chooses each slot's controller kind: keyboard-p1 / keyboard-p2 / gamepad / null. This is the same affordance E7 extends with `scripted`, so it is shaped as data now.
3. Per-player state stays genuinely separate and privately consumed: each HUD root subscribes only to its own player's signals. No HUD element reads the opponent's `PlayerState`, even for something currently harmless like HP — the habit protects the E3 hand.
4. Determinism survives two live controllers: an `InputIntent` stream from a real two-human round replays through `ReplayController` on both slots to the same final state hash (the first real exercise of the X5 path).
5. A full human-vs-human round is played and first impressions of spacing, attack weight, deflect timing, and stamina pressure are recorded in `docs/playtest-log.md` in prose — including what feels wrong. This log is the input to the E3 revisit gate.

## Tasks / Subtasks

- [ ] Flip slot 1 to a real controller via the 1.6 config point only (AC: 1)
  - [ ] Confirm zero hero/actor/state edits; if any needed, fix the seam
- [ ] Add match-setup selection (keyboard-p1 / keyboard-p2 / gamepad / null) as data (AC: 2)
- [ ] Enforce per-HUD subscription to own player's signals only (AC: 3)
- [ ] Record a two-human round; replay via `ReplayController` both slots → identical hash (AC: 4)
- [ ] Play a full round; write prose feel notes in `docs/playtest-log.md` (AC: 5)

## Dev Notes

- This story is the proof of DECISION (a): because the dummy was a full `PlayerState`+`HeroActor` on `NullController`, second-human is a controller swap and nothing else. A required src edit anywhere else means the E1.S6 seam is wrong. [Source: stories-manual-e2.md#E2.S3 item 1; stories-manual-e1.md#E1.S6]
- The feel log written here is explicitly the **input to the E3 revisit gate** — E3 is provisional until this playtest exists. [Source: stories-manual-e3.md#Revisit gate]
- No HUD element reads the opponent's `PlayerState` — the habit that protects the E3 private hand. [Source: stories-manual-e2.md#E2.S3 item 3]

### Project Structure Notes

- Controller swap at the `src/main/match_runner.gd` config point; match-setup as a small scene or config resource; `ReplayController` in `src/controllers/`; log at `docs/playtest-log.md`.

### Project Context Rules

- **Controller abstraction:** dummy → PvP → bot is a config swap. [Source: gdd.md#Controls; epics.md#Sequencing invariants]
- **Determinism / replay (X5):** seed + intents reproduce the round. [Source: docs/game-architecture.md#Determinism & Replay]

### References

- [Source: stories-manual-e2.md#E2.S3]
- [Source: stories-manual-e3.md#Revisit gate]
- [Source: epics.md#E1; #E2; #E7]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
