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
2. Card actions are read directly at step 6 ("Card / economy resolution") and resolved there through the `resolve()` dispatch of Novel Pattern 6 — NOT ingested at step 1. Verified by content: step 1 applies ONLY the intent-carried debug reset (story 1-7, D-2); the rest of each player's `InputIntent` (`move_dir`, attack/block/roll) is read directly by its own resolution step (step 3), not staged at step 1 — this exact misreading of the ladder was already corrected once, at the E2 close-out (E2-CO/R3: "the code applies only the debug reset at step 1... `move_dir` and attack/block/roll are read by `_resolve_actions` at step 3"). Card fields on `InputIntent` follow the same pattern: read at step 6, not staged at step 1. `ModeKind.BASIC` resolves; `UNBLOCKABLE_INIT`, `UNBLOCKABLE_DEFENSE`, and `PITCH` remain stubs guarded by `Invariant.check` (`src/systems/invariant.gd` — not `check_invariant`, which names no real symbol) and/or feature flag.
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
- **Input Map ownership.** The earlier ruling that new `project.godot` Input Map actions "land here and only here" bound only 3-0b's deterministic step/pause actions (E3-P/R2) — it was never meant to freeze the Input Map for the whole epic, and the E3 revisit gate amended that wording to read as scoped, not absolute (decision-log E3-RG/R7). This story may add its own card actions (play/stage/cancel, per-mode binds) under the same discipline already used for controller-facing actions elsewhere: named actions, textual edit with the editor closed, diff reviewed. [Source: decision-log.md E3-RG/R7]

### Project Structure Notes

- `InputIntent` in `src/state/input/`; card fields produced in `src/controllers/`; `resolve()` dispatch in `src/state/`; `CardEffect` seam in `src/state/resources/`.

### Project Context Rules

- **Card resolution computed in the state layer;** visuals never decide. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Graceful degradation:** orbs off → mana-only cast. [Source: docs/project-context.md#HARD RULE — Feature flags]

### References

- [Source: stories-manual-e3.md#E3.S5]
- [Source: gdd.md#Controls — Card-mode selection UX]
- [Source: docs/game-architecture.md#Novel Pattern 6]

## Golden Prediction

**MOVES.** A successful cast pays mana (new field on the hashed snapshot), discards from `hand`, and
triggers a draw from `3-3`'s deck — a draw consumes the seeded gameplay RNG, and `rng_state` is part of
the hashed snapshot (`match_state.gd:242`). A cast in the recorded determinism sequence therefore moves
the hash through at least two causes: the economy-field write (mana spent) and the RNG draw it triggers.
Measure in both directions and isolate causes exactly as 1-5/1-8/1-9 did for their multi-cause
re-baselines — do not bundle them into one unnamed "cards changed things" cause.

## Live Smoke

**REQUIRED — this is the P4 pressure test.** The story's own revisit note names it: "whether a real-time
mode selection is viable at all depends on how much attention the melee layer leaves free." Headless tests
prove correctness (cost gating, discard/draw, guarded stubs); they cannot prove the mode-select scheme is
usable under real-time combat pressure. Runs on the shipped default (two live humans). Judge against P4:
during an active exchange, can a player select a card and mode without the attempt reading as "stopped to
use a menu"? Record the verdict — pass, fails, or rewrite-candidate — in `docs/playtest-log.md`; this
story is explicitly flagged as "the story most likely to be rewritten" and the smoke is what decides that,
not a style preference.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
