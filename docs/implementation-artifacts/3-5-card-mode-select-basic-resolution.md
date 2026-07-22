# Story 3.5: Card-mode selection input and Basic (Mode ①) resolution

Status: backlog

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. This is the story most likely to be rewritten. Whether a real-time mode selection is viable at all depends on how much attention the melee layer leaves free, which the first playtest measures.

## Story

As a player,
I want to select a card and play it in Mode ① under real-time pressure, paying mana through `CardCastCondition`, with the E5/E6 modes left as guarded stubs,
so that the card layer resolves as far as E3 honestly goes without inventing minions, orbs, or pitch.

## Acceptance Criteria

1. `InputIntent` is extended with the card fields (selected hand slot, selected mode, play/stage/cancel actions), produced in the controllers only. **One** provisional mode-select scheme (radial, hold-modifier + slot, or per-mode bind) is implemented as the controller's concern, so swapping schemes touches `src/controllers/` and nothing else.
2. Card actions are ingested in `advance()` step 1 and resolved in step 6 through the `resolve()` dispatch of Novel Pattern 6. `ModeKind.BASIC` resolves; `UNBLOCKABLE_INIT`, `UNBLOCKABLE_DEFENSE`, and `PITCH` remain stubs guarded by `check_invariant`/feature flag.
3. Every cast is gated through `CardCastCondition` evaluated against `PlayerState` — never an inline mana comparison at the call site. With orbs flagged off, a condition's orb costs degrade to mana-only (the documented graceful-degradation example).
4. Mode ① resolves as far as E3 honestly goes: pay the mana, discard, trigger the 3.3 draw, and emit the effect through the `CardEffect` seam. Real minions/totems are E4 — a resolved summon that queues a signal nothing consumes yet is correct; a fake placeholder actor is not.
5. Headless tests: a cast at exactly the cost succeeds and one below is rejected with a signal the HUD can show; the card leaves the hand and a replacement is drawn; the E5/E6 modes are unreachable in E3; the RNG state after a cast is identical for the same seed and inputs.

## Tasks / Subtasks

- [ ] Extend `InputIntent` with card fields; implement ONE mode-select scheme in controllers (AC: 1)
- [ ] Ingest card actions step 1; dispatch via `resolve()` step 6; keep ②/③/④ guarded stubs (AC: 2)
- [ ] Gate every cast through `CardCastCondition` against `PlayerState`; orbs-off → mana-only (AC: 3)
- [ ] Resolve Mode ①: pay mana, discard, draw, emit via `CardEffect` seam (no fake actor) (AC: 4)
- [ ] Headless tests incl. same-seed RNG-after-cast determinism (AC: 5)

## Dev Notes

- Only Mode ① lands in E3; ②/③ are E5 and ④ is E6 — their `resolve()` branches stay guarded stubs (a resolved summon queuing an unconsumed signal is the correct E3 state; a fake placeholder actor is not). [Source: stories-manual-e3.md#Before you start; #E3.S5 item 4; docs/game-architecture.md#Novel Pattern 6]
- Mode-select scheme is the controller's concern so swapping it touches only `src/controllers/`. The card-mode-select UX is an open, high-P4 question — implement one provisional scheme, do not treat it as settled. [Source: gdd.md#Controls — Card-mode selection UX; stories-manual-e3.md#E3.S5 item 1]
- Cast gating via `CardCastCondition`, never inline mana compare; orbs-off degrades to mana-only. [Source: docs/game-architecture.md#D6]

### Project Structure Notes

- `InputIntent` in `src/state/input/`; card fields produced in `src/controllers/`; `resolve()` dispatch in `src/state/`; `CardEffect` seam in `src/state/resources/`.

### Project Context Rules

- **Card resolution computed in the state layer;** visuals never decide. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Graceful degradation:** orbs off → mana-only cast. [Source: docs/project-context.md#HARD RULE — Feature flags]

### References

- [Source: stories-manual-e3.md#E3.S5]
- [Source: gdd.md#Controls — Card-mode selection UX]
- [Source: docs/game-architecture.md#Novel Pattern 6]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
