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
4. Deck exhaustion → reshuffle with the vulnerable window as a `TimingWindow` on the player. Visibility to both players rides an OWNERLESS `EventBus` event (the `round_started`/`round_ended` precedent), carrying which player is vulnerable as payload — the shipped HUD is bound per-slot and structurally cannot see the opponent's state any other way (decision-log E3-RG/R3). **What "vulnerable" costs mechanically is not specified in the GDD; it is NOT invented here** — OPEN decision (b) already carries this question (decision-log, Session 2026-07-22, lettered `(b)` at DP/R4); the state and signal are emitted and decision (b) is left open, not re-logged as new.
5. Headless tests: hand refills to `hand_size` at round start; playing a card draws exactly one after the authored delay; a staged-card slot (reserved for E6) would still count toward the hand; exhaustion reshuffles the discard pile and opens the vulnerable window for the authored ticks; same-seed draw sequences match.

## Tasks / Subtasks

- [ ] Implement pure `Deck`/`Hand` owned by `PlayerState`, sized from balance (AC: 1)
- [ ] Draw only from the seeded RNG inside `advance()` step 6; same-seed determinism test (AC: 2)
- [ ] Draw-on-play delay as a `TimingWindow` (0 = instant) (AC: 3)
- [ ] Reshuffle-on-exhaustion with a vulnerable window signalled over the ownerless `EventBus` event per decision-log E3-RG/R3 (AC: 4)
  - [ ] **OPEN DECISION (b) — leave it OPEN:** what a reshuffle vulnerable window costs mechanically is already logged (decision-log, Session 2026-07-22, lettered `(b)` at DP/R4) — emit state + signal only, invent no cost, do not re-log the question as new
- [ ] Headless tests incl. same-seed draw match (AC: 5)

## Dev Notes

- **OPEN DECISION (b) (must stay OPEN, do not invent):** what a reshuffle **"vulnerable window" costs mechanically**. Already logged (decision-log, Session 2026-07-22; lettered `(b)` at DP/R4) — this story's job is to emit the vulnerable state + signal, not to re-log the question as though it were new. [Source: stories-manual-e3.md#E3.S3 item 4; gdd.md#A Deck & hand; decision-log.md DP/R4]
- Draw from the seeded RNG only inside `advance()` — a draw from anywhere else silently breaks replay (the F2 hole the architecture closed). [Source: docs/game-architecture.md#Determinism & Replay]
- The draw-replacement delay (instant vs ~1s) is an open feel question — build it as data so the playtest decides. [Source: gdd.md#A Deck & hand]
- **Hand size does NOT vary in this story's first version.** OPEN decision (e) — "does the number of cards in a hand ever vary?" — is carried, not resolved, by this story: the operator's stated intent is a first version where the hand is always 4 and refills the moment a card is played, with variants (non-automatic draw, conditional draw, timed refill) explored later. Do not silently assume a fixed hand of 4 without citing this; do not build a variable-size path speculatively. [Source: decision-log.md:801; epics.md:100-101]
- **The vulnerable-window visibility channel is the ownerless `EventBus` event ruled at the E3 revisit gate**, not a per-slot HUD seam — the shipped HUD (`HudRoot`) is bound per-slot and structurally cannot see the opponent's state (2-4/R7, 2-5/R11). Follow the `round_started`/`round_ended` precedent: `match_runner` relays a queued state signal onto `EventBus`, both viewports' `HudRoot` instances subscribe to the SAME event. [Source: decision-log.md E3-RG/R3]

### Project Structure Notes

- `src/state/` `deck.gd`/`hand.gd` owned by `player_state.gd`; RNG owned by `match_state.gd`; windows via `timing_window.gd`. Decision-log entry recorded, not resolved.

### Project Context Rules

- **Seeded RNG consumed only inside `advance()`;** no bare global RNG in `src/state/`. [Source: docs/project-context.md#Controllers & state-layer determinism, A2]
- **Pitch Zone does not reduce hand size** — a staged card still counts toward the hand of 4 (reserved E6). [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: stories-manual-e3.md#E3.S3]
- [Source: gdd.md#A Card System — Deck & hand]
- [Source: docs/game-architecture.md#Determinism & Replay]

## Golden Prediction

**MOVES — NOT NONE, TWO separately named causes.** (1) SNAPSHOT SHAPE / EXERCISED PATH: draw consumes the
seeded gameplay RNG inside `advance()` (AC2), and `rng_state` is already part of the hashed snapshot
(`match_state.gd:242`) — any draw in the recorded determinism sequence moves the hash. (2) SNAPSHOT VALUE:
`PlayerState.to_snapshot()` already emits `"hand_size": hand.size()`, but `hand` is declared `[]` and never
mutated anywhere in `src/` today (2-5/R1) — this story is what finally makes it non-zero, a second,
independent cause. This breaks the golden-unmoved streak recorded at 3-0a close-out ("the SEVENTH
consecutive story", decision-log:1003) — expected and not a defect. Measure both directions per the
project's standing discipline (1-5 cause-(c) lesson): isolate cause (1) from cause (2) with an intermediate
run (mechanics in, sequence unchanged) before restructuring the sequence to also exercise reshuffle.
Baseline hash `33817201...21da2`. [Source: decision-log.md E3-RG/R11]

## Live Smoke

Deck/hand/draw/reshuffle are pure `src/state/` mechanics with no actor or presentation surface of their
own in this story (3-6 owns the HUD rendering). A live smoke is not required to prove AC1-4 — the headless
tests (AC5) are the correct proof. If the dev pass wants to observe draw/reshuffle timing feel before 3-6
exists, that is a finding for `docs/playtest-log.md`, written by the operator's own hand, never invented
here.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
