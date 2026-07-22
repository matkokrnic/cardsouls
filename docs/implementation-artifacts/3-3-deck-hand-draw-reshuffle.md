# Story 3.3: Deck, hand, draw, and reshuffle

Status: backlog

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. The draw-replacement delay in particular is a feel decision that the melee playtest informs.

## Story

As a player,
I want deck/hand/draw/reshuffle to run in the pure state layer from the seeded RNG inside `advance()`, with the draw delay and reshuffle window as data,
so that card flow is replay-safe and a playtest can answer the open feel questions by editing a `.tres`.

## Acceptance Criteria

1. `Deck` and `Hand` are implemented in `src/state/` as pure objects owned by `PlayerState`: shuffle, draw, discard, and reshuffle-on-exhaustion, sized from balance (`deck_size`, `hand_size`).
2. Draw is exclusively from the seeded gameplay RNG owned by `MatchState`, consumed only inside `advance()` step 6. A test proves two matches with the same seed draw identical sequences.
3. Draw-on-play uses the delay as **data**: `draw_replacement_delay_seconds` converted to a `TimingWindow`, where zero means instant. Instant vs delayed is an open feel question built so a playtest answers it by editing a `.tres`.
4. Deck exhaustion → reshuffle with the vulnerable window as a `TimingWindow` on the player, flagged visually to both players via a queued signal. **What "vulnerable" costs mechanically is not specified in the GDD; it is NOT invented here** — the state and signal are emitted and the question is logged in `decision-log.md`.
5. Headless tests: hand refills to `hand_size` at round start; playing a card draws exactly one after the authored delay; a staged-card slot (reserved for E6) would still count toward the hand; exhaustion reshuffles the discard pile and opens the vulnerable window for the authored ticks; same-seed draw sequences match.

## Tasks / Subtasks

- [ ] Implement pure `Deck`/`Hand` owned by `PlayerState`, sized from balance (AC: 1)
- [ ] Draw only from the seeded RNG inside `advance()` step 6; same-seed determinism test (AC: 2)
- [ ] Draw-on-play delay as a `TimingWindow` (0 = instant) (AC: 3)
- [ ] Reshuffle-on-exhaustion with a signalled vulnerable window (AC: 4)
  - [ ] **OPEN QUESTION — do NOT resolve:** log "what a reshuffle vulnerable window costs mechanically" in `decision-log.md`; emit state + signal only, invent no cost
- [ ] Headless tests incl. same-seed draw match (AC: 5)

## Dev Notes

- **OPEN QUESTION (must stay OPEN, route to decision-log, do not invent):** what a reshuffle **"vulnerable window" costs mechanically**. The GDD specifies the window exists (~1.5–2s, flagged visually) but not its mechanical cost. Emit the vulnerable state + queued signal to both players; add the cost question to `decision-log.md` — do not invent a penalty. [Source: stories-manual-e3.md#E3.S3 item 4; gdd.md#A Deck & hand]
- Draw from the seeded RNG only inside `advance()` — a draw from anywhere else silently breaks replay (the F2 hole the architecture closed). [Source: docs/game-architecture.md#Determinism & Replay]
- The draw-replacement delay (instant vs ~1s) is an open feel question — build it as data so the playtest decides. [Source: gdd.md#A Deck & hand]

### Project Structure Notes

- `src/state/` `deck.gd`/`hand.gd` owned by `player_state.gd`; RNG owned by `match_state.gd`; windows via `timing_window.gd`. Decision-log entry recorded, not resolved.

### Project Context Rules

- **Seeded RNG consumed only inside `advance()`;** no bare global RNG in `src/state/`. [Source: docs/project-context.md#Controllers & state-layer determinism, A2]
- **Pitch Zone does not reduce hand size** — a staged card still counts toward the hand of 4 (reserved E6). [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: stories-manual-e3.md#E3.S3]
- [Source: gdd.md#A Card System — Deck & hand]
- [Source: docs/game-architecture.md#Determinism & Replay]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
