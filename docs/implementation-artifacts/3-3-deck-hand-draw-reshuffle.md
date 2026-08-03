# Story 3.3: Deck, hand, draw, and reshuffle

Status: ready-for-dev

> **Scope note.** The E3 revisit gate has RUN (2026-07-31, decision-log Session 2026-07-31 — E3
> revisit gate (outcome), rulings E3-RG/R1..R12); this story was amended per that outcome in commit
> `10b96a1`. This story then passed its OWN readiness gate (2026-08-03) after the fixes recorded in
> this revision — the story's scope is further NARROWED from the amended version at this gate:
> discard, reshuffle-on-exhaustion, the vulnerable window, and the draw-on-play delay all move to 3-5
> (see Dev Notes).

## Story

As a player,
I want a deck to be shuffled and my hand filled from it in the pure state layer, using only the seeded RNG inside `advance()`,
so that a match starts with a deterministic, replay-safe deck and hand.

## Acceptance Criteria

1. `Deck` and `Hand` are pure `RefCounted` classes under `src/state/`, owned by `PlayerState`. Neither names `CardDatabase`, `CARDS_DIR` or `data/cards`, and neither calls any global-RNG API.
2. `MatchState` exposes a deck-content injection seam following the `inject_feature_flags` precedent: once at match start, content only, NO reload path. Deck content reaches `src/state/` only through it. The runner is the only production caller and the only reader of `CardDatabase`.
3. `CardDatabase` gains exactly one explicitly-sorted ordered accessor over its loaded ids. `get_card`, `has_card` and `card_count` are unchanged.
4. Deck composition is derived deterministically: walk the sorted ids, taking up to each card's `max_copies`, until `deck_size` is reached. This is provisional FIXTURE composition and is not the deckbuilding seat.
5. Deck elements are `StringName` ids — never `CardData` references, never bare indices. `PlayerState.to_snapshot()` carries COUNTS only, never card identities. A test proves two independently constructed matches with the same seed and a populated deck hash identically.
6. `BalanceConfig` gains `deck_size` and `hand_size`. Both are counts and live on `BalanceConfig`, not `BalanceTicks`, and are read inline at point of use. Both appear in `E1_BALANCE_FIELDS`. `test_balance_authoring.gd` audits `deck_size > 0`, `hand_size > 0` and `hand_size <= deck_size`. `draw_replacement_delay_seconds` does NOT land in this story.
7. The deck is shuffled by an explicit in-place Fisher-Yates against `MatchState`'s seeded RNG, invoked only from `advance()` step 6. One seat serves both occasions (match start and debug reset). Tests prove: same seed gives identical order; different seed gives different order; the result is a permutation of the input multiset.
8. `test_architecture_invariants.gd` gains a guard banning implicit-global-RNG collection APIs (`.shuffle(`, `.pick_random(`, bare `seed(`) and the token `CardDatabase` under `src/state/`. It is non-vacuous in both the ways the existing card guard is — the banned token must be real somewhere and the scan must be proven to visit files — and is mutation-proven.
9. The hand fills to `hand_size` from the top of the shuffled deck at match start and again on debug reset. Thereafter `PlayerState.to_snapshot()["hand_size"]` equals `hand_size`, and the deck's remaining count equals `deck_size - hand_size`.
10. An `Invariant.check` at the injection seam rejects an empty injected deck.
11. Negative guard: no discard pile, reshuffle path, deck-exhaustion handling, vulnerable window, draw-on-play delay, `EventBus` signal, card effect or cast evaluator ships. No file under `src/ui/`, no `project.godot` Input Map entry, and no observation seam is modified.
12. `test_determinism.gd` is re-baselined exactly ONCE, with each cause named separately, isolated by its own measurement and reproduced in both directions, plus a `test_golden_sequence_exercises_*` pin proving the recorded sequence genuinely exercises the shuffle and the fill.

## Tasks / Subtasks

- [ ] Implement pure `Deck`/`Hand` under `src/state/`, owned by `PlayerState`, no `CardDatabase`/RNG names (AC: 1)
- [ ] Add the deck-content injection seam on `MatchState`, `inject_feature_flags` precedent, runner-only caller (AC: 2)
- [ ] Add one sorted ordered accessor to `CardDatabase` over its loaded ids (AC: 3)
- [ ] Derive deck composition deterministically from sorted ids honouring `max_copies` up to `deck_size` (AC: 4)
- [ ] Deck elements as `StringName` ids only; snapshot carries counts, not identities; cross-match hash test (AC: 5)
- [ ] Author `deck_size`/`hand_size` on `BalanceConfig`, add to `E1_BALANCE_FIELDS`, authoring audit (AC: 6)
- [ ] Implement Fisher-Yates shuffle against the seeded RNG inside `advance()` step 6, one seat for match start and debug reset (AC: 7)
- [ ] Extend `test_architecture_invariants.gd` with the implicit-global-RNG-API + `CardDatabase`-in-`src/state/` guard, mutation-proven (AC: 8)
- [ ] Fill the hand to `hand_size` from the shuffled deck at match start and on debug reset (AC: 9)
- [ ] `Invariant.check` rejecting an empty injected deck at the injection seam (AC: 10)
- [ ] Negative-guard tests: no discard/reshuffle/exhaustion/vulnerable-window/draw-delay/EventBus/effect/evaluator/UI/Input-Map/observation-seam surface ships (AC: 11)
- [ ] Re-baseline `test_determinism.gd` exactly once, causes isolated and reproduced both directions, plus a sequence-exercises-the-shuffle-and-fill pin (AC: 12)

## Dev Notes

- SUPERSEDED at the readiness gate (2026-08-03) -- this story emits nothing; decision (b) stays open, unchanged. **OPEN DECISION (b) (must stay OPEN, do not invent):** what a reshuffle **"vulnerable window" costs mechanically**. Already logged (decision-log, Session 2026-07-22; lettered `(b)` at DP/R4) — this story's job is to emit the vulnerable state + signal, not to re-log the question as though it were new. [Source: stories-manual-e3.md#E3.S3 item 4; gdd.md#A Deck & hand; decision-log.md DP/R4]
- Draw from the seeded RNG only inside `advance()` — a draw from anywhere else silently breaks replay (the F2 hole the architecture closed). [Source: docs/game-architecture.md#Determinism & Replay]
- SUPERSEDED at the readiness gate (2026-08-03) -- the delay field lands at 3-5 with its consumer. The draw-replacement delay (instant vs ~1s) is an open feel question — build it as data so the playtest decides. [Source: gdd.md#A Deck & hand]
- SUPERSEDED at the readiness gate (2026-08-03) -- the value is authored as `hand_size`; the operator's intent is unchanged. **Hand size does NOT vary in this story's first version.** OPEN decision (e) — "does the number of cards in a hand ever vary?" — is carried, not resolved, by this story: the operator's stated intent is a first version where the hand is always 4 and refills the moment a card is played, with variants (non-automatic draw, conditional draw, timed refill) explored later. Do not silently assume a fixed hand of 4 without citing this; do not build a variable-size path speculatively. [Source: decision-log.md:801; epics.md:100-101]
- SUPERSEDED at the readiness gate (2026-08-03) -- the channel ruling still stands, but the event itself is 3-5's, not this story's. **The vulnerable-window visibility channel is the ownerless `EventBus` event ruled at the E3 revisit gate**, not a per-slot HUD seam — the shipped HUD (`HudRoot`) is bound per-slot and structurally cannot see the opponent's state (2-4/R7, 2-5/R11). Follow the `round_started`/`round_ended` precedent: `match_runner` relays a queued state signal onto `EventBus`, both viewports' `HudRoot` instances subscribe to the SAME event. [Source: decision-log.md E3-RG/R3]
- Deck composition is derived from the loaded card set by sorted-id fill honouring `max_copies`. Provisional fixture composition; real deck selection is E4/E5 or later. `max_copies` gains its first consumer here.
- Deck order is NOT hash-visible: the snapshot carries counts, and order stays derivable from seed plus composition. NEW OBLIGATION for the intent-recorder story (3-0c): the injected deck composition must enter the replay record alongside seed, intents and reload events — otherwise a replay depends on the contents of `data/cards/`, which change without a trace.
- Scope narrowed at the readiness gate: discard, refill-on-play, deck exhaustion with reshuffle, and the vulnerable window all move to 3-5, together with their triggers. Reason: with 4 drawn from 20 at round start and nothing else drawing, exhaustion is unreachable and the discard pile would be permanently empty. The `EventBus` channel ruling from the E3 revisit gate — an ownerless match-wide event on the `round_started`/`round_ended` precedent, carrying which player is vulnerable, explicitly NOT an eighth member of the per-slot observation seam family — remains binding on whichever story lands the event.
- Open decision (b), the mechanical cost of the reshuffle vulnerable window, stays OPEN and is not re-logged. It was not the binding constraint here; the missing trigger was.
- Open decision (e), whether hand size ever varies, is carried, not resolved. The first version is always `hand_size` with no variants. `draw_replacement_delay_seconds` lands at 3-5 so that the field and its seat arrive together, avoiding a dead `BalanceConfig` field, a dead `BalanceTicks` field, an `E1_BALANCE_FIELDS` entry and an audit exemption for a consumer one story away.
- ONE SEAT: shuffle and fill both execute inside `advance()`, never in the injection call. This keeps "the RNG is consumed only inside `advance()`" provable, and because the debug reset is an intent in the stream, the reset-time reshuffle is replay-safe.
- There is no round-start event in the game: `round_started` fires only from the debug reset, whose own comment calls it an operator affordance and not a gameplay path. "Round start" for the fill therefore means match start (the first balance injection) and the debug reset.
- The parked finding that mana survives a reset stays PARKED with the first round-flow story. This story only participates in the reset function beside the hp heal; it introduces no round lifecycle. Do not fix it in passing.
- `Array.shuffle()` was measured on this engine (4.6.3) drawing from the GLOBAL RNG and leaving a per-instance `RandomNumberGenerator` untouched, and the shipped nondeterminism guard does not catch it — a `deck.shuffle()` under `src/state/` passes the suite today while silently destroying replay. That is why AC7 specifies the algorithm and AC8 extends the guard.
- A `CardData` reference must never enter the snapshot: the canonical hash has no object branch and falls through to a string conversion yielding a per-allocation instance id, which would fail the same-seed determinism test outright.
- The export-remap risk flag now has a DETECTOR (AC10) rather than an owner: an empty card directory in an exported build turns from a silent empty deck into a loud failure. The flag itself stays open, downgraded.
- CONSTRAINT C applies: `deck_size` and `hand_size` are read inline at point of use. Reading a size at the seat is a snapshot-the-value read in the `TimingWindow.start()` shape, not a cached `BalanceTicks` reference.
- Architecture amendment queue gains a SEVENTH member: the doc states the banned nondeterminism surface as a concept rather than naming the implicit-global-RNG collection APIs; `Deck` and `Hand` need Directory Tree lines and places in the state-layer inventories (the same gap `CardEffect` already has as the sixth member); and, conditionally, if a vulnerable-window signal ever lands, the `EventBus` header and the seam registry both enumerate the bus as exactly `match_started`/`round_started`/`round_ended` and need reconciling.
- PERMANENT RULE, from this gate and the one before it: a story's Golden Prediction baseline is re-derived from the `GOLDEN` constant at gate time and never copied from story text. Two consecutive stories shipped a stale baseline.

### Project Structure Notes

- `src/state/` `deck.gd`/`hand.gd` owned by `player_state.gd`; RNG owned by `match_state.gd`; windows via `timing_window.gd`. Decision-log entry recorded, not resolved.

### Project Context Rules

- **Seeded RNG consumed only inside `advance()`;** no bare global RNG in `src/state/`. [Source: docs/project-context.md#Controllers & state-layer determinism, A2]
- **Pitch Zone does not reduce hand size** — a staged card still counts toward the hand of 4 (reserved E6). [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: stories-manual-e3.md#E3.S3]
- [Source: gdd.md#A Card System — Deck & hand]
- [Source: docs/game-architecture.md#Determinism & Replay]
- [Source: decision-log.md Session 2026-07-31 — E3 revisit gate (outcome), E3-RG/R1]
- [Source: decision-log.md Session 2026-08-03 — Story 3-3 readiness gate]

## Golden Prediction

**Baseline:** `98d0c7ebfdbe01a97622b185a7e3388428793cc87e323751c2ffb5b6f58f81ff` (the `GOLDEN` constant in
`test_determinism.gd`, current).

**Prediction: MOVES — ONE re-baseline, THREE separately named causes.**

- **Cause 1 — SNAPSHOT SHAPE, an unconditional mover.** Every key `Deck`/`Hand` add to `PlayerState.to_snapshot()` moves the hash even when every authored size is zero.
- **Cause 2 — FIXTURE COVERAGE VALUE `deck_size`, via RNG consumption.** `rng_state` is hashed and nothing consumes the RNG today. Fisher-Yates over n elements draws exactly n-1 times regardless of what the elements are, so this cause is driven by `deck_size` alone and is independent of card identity. CONDITIONAL: with the fixture's default `deck_size` of 0 the shuffle draws zero times and this is a MEASURED NON-MOVER, so the fixture must author a coverage value — coverage, not feel; deliberately not the authored 20; deliberately distinct from every other count in the fixture so a selector bug lands on a different value rather than coinciding.
- **Cause 3 — FIXTURE COVERAGE VALUE `hand_size`.** `to_snapshot()` already emits `hand_size` and it is 0 today. CONDITIONAL on the same fixture authoring and dependent on cause 2 — an empty deck fills no hand.
- **NOT a cause: card content.** `data/cards/` is unreachable from the state harness (no autoloads) and the fixture authors its own opaque deck identities, so adding a card must never re-baseline this hash.

**Measurement order, each step a measurement, one re-baseline commit at the end:**

- M0 before the first edit -> `98d0c7eb...` (pins the baseline honestly)
- M1 Deck/Hand exist, nothing snapshotted, sizes 0 -> UNMOVED
- M2 snapshot keys added, sizes still 0 -> MOVED (cause 1 alone)
- M3 `deck_size` authored > 1, `hand_size` still 0 -> MOVED (cause 2 alone)
- M4 `hand_size` authored > 0 -> MOVED (cause 3); this is the final GOLDEN
- Reverse: toggle `hand_size` to 0 and reproduce M3; toggle `deck_size` to 0 and reproduce M2. Both must reproduce exactly.

Non-golden tests green at M0 and at M4.

## Live Smoke

**NOT REQUIRED**, with the honest reason: this story ships no player-facing surface (no HUD, no input,
no visible actor behaviour), and a shuffle's determinism is not observable by a human at all. If the
runner-side injection seam ships, the story does put new code in the live boot path; the honest proof
of that is headless — `run_all.sh` greps for `SCRIPT ERROR`, `Parse Error` and `INVARIANT VIOLATED` —
plus one integration test asserting the injected deck is non-empty. The smoke acceptance criterion (the
one spent at 3-4 against two live killable human slots) stays SPENT and is re-invoked by the card-play
story, 3-5, not by this one.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-31 | 0.2 | E3 revisit-gate amendment (commit `10b96a1`): AC4 reworded to route the vulnerable-window signal over the `EventBus` channel (E3-RG/R3); the "log the question" task replaced with "leave OPEN decision (b) open" (already logged, DP/R4); OPEN decision (e) cited for hand-size behaviour; Golden Prediction and Live Smoke sections added. Status stayed backlog pending this story's own readiness gate. | not recorded |
| 2026-08-03 | 0.3 | Readiness-gate fix pass (NOT READY on first read -> fixed and promoted, same session; seventeenth logged Set B readiness gate). Stale E3-REVISIT-GATE banner replaced with a Scope note in the 3-1/3-4 pattern. AC set replaced with twelve verifiable claims about shipped software (pure `Deck`/`Hand`; a `MatchState` deck-content injection seam on the `inject_feature_flags` precedent; one sorted `CardDatabase` accessor; deterministic sorted-id fixture composition; `StringName`-only deck elements with counts-only snapshotting; `deck_size`/`hand_size` on `BalanceConfig`; an explicit Fisher-Yates shuffle inside `advance()` step 6; an extended architecture-invariants guard against implicit-global-RNG APIs and `CardDatabase` in `src/state/`; hand fill to `hand_size` at match start and debug reset; an `Invariant.check` against an empty injected deck; a broad negative guard against discard/reshuffle/exhaustion/vulnerable-window/draw-delay/EventBus/effect/evaluator/UI surfaces; a single re-baseline with three separately measured causes). Golden Prediction baseline corrected from the three-re-baselines-stale `33817201...` (the stamina-cost corrective pass, 3-0b Pass 2, and the 3-4 economy re-baseline) to `98d0c7eb...`; the false "breaks the golden-unmoved streak" claim removed outright (the streak was already broken by those three intervening re-baselines); prediction MOVES, one re-baseline, three separately named causes (snapshot shape; the `deck_size`-driven RNG-consumption coverage value; the `hand_size` coverage value), measured in five steps M0-M4 plus a two-step reverse. Live Smoke kept NOT REQUIRED with the corrected reason (no player-facing surface; the autoload injection seam's presence in the live boot path is proven headless by the integration runner's script-error grep). Dev Notes appended with the scope-narrowing rationale (deck exhaustion unreachable with only an initial 4-of-20 fill), the empirical `Array.shuffle()`-uses-the-global-RNG measurement and the gap in the shipped nondeterminism guard, the deck-composition ownership ruling, the `CardDatabase` sorted-accessor ruling, the intent-recorder obligation (deck composition must enter the replay record), the ONE-SEAT shuffle/fill discipline, the CONSTRAINT C inline-read reminder, and the seventh architecture-amendment-queue member. Task list rewritten to mirror the twelve ACs. Status stays backlog -> ready-for-dev; `sprint-status.yaml` updated alongside; `stories-manual-e3.md`'s E3.S3 exit criterion corrected to match (companion commit), the numbered items left untouched per the 3-2 precedent. | Claude Sonnet 5 |
