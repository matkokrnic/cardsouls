# Story 3.2: Card schemas, `CardDatabase`, and the first authored cards

Status: ready-for-dev

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a solo developer,
I want the card schema resources, a starter card set as `.tres`, and `CardDatabase` preloading them at startup,
so that adding a card is a `.tres` with no code change, and per-colour unblockable damage can never sneak onto `CardData`.

## Acceptance Criteria

1. Schema resources in `src/state/resources/`: `CardData` (`color`, `basic_effect`, `pitch_effect`, `cast_condition`, `max_copies`), `CardEffect` as the reserved effect schema, and `CardCastCondition` (`mana_cost`, per-colour `orb_costs`, flags). Modes ②/③ derive from `color` and carry no per-card data.
2. A small starter set of cards is authored as `.tres` in `data/cards/` — enough to fill a deck with a roughly balanced colour ratio, including the GDD's *Imp Summoner* worked example. Only the Mode ① effect needs a real value in E3; `pitch_effect` is authored as a placeholder for E6.
3. `CardDatabase` (the existing autoload) preloads every card `.tres` at startup and exposes lookup by id. Content is loaded by a `systems/` service; the state layer receives card resources by injection and never reads the autoload.
4. Per-colour unblockable damage is kept out of `CardData` entirely — a fixed value per colour in balance. A `check_invariant` or a test fails if a per-card damage field ever appears.
5. The `.tres` smoke test loads every authored card and asserts required fields, a valid colour enum, and a copy cap within bounds.

## Tasks / Subtasks

- [ ] Implement `CardData`, `CardEffect`, `CardCastCondition` schemas (AC: 1)
- [ ] Author the starter card set incl. *Imp Summoner*; placeholder `pitch_effect` (AC: 2)
- [ ] Complete `CardDatabase` preload + lookup; inject resources into state (AC: 3)
- [ ] Guard against a per-card unblockable damage field (`check_invariant`/test) (AC: 4)
- [ ] Extend `.tres` smoke test (fields, colour enum, copy cap) (AC: 5)

## Dev Notes

- **Unblockable damage is per-colour, not per-card** — a fixed value per colour in balance; easy to implement wrong. [Source: docs/project-context.md#Critical Don't-Miss Rules; gdd.md#C]
- Modes ②/③ derive from `color` and carry no per-card data (Novel Pattern 6). Only Mode ① lands in E3; ④ (`pitch_effect`) is a reserved placeholder for E6. [Source: docs/game-architecture.md#Novel Pattern 6]
- State never reads `CardDatabase`; resources are injected. [Source: docs/game-architecture.md#Standard Patterns — Data access]

### Project Structure Notes

- Schemas in `src/state/resources/`; instances in `data/cards/`; `CardDatabase` autoload in `src/systems/`.

### Project Context Rules

- **Data-defined content:** new card = new `.tres`, no code. [Source: docs/project-context.md#Data as Resources]
- **State receives schema by injection, never reads a `*Service`/autoload.** [Source: docs/project-context.md#Autoloads]

### References

- [Source: stories-manual-e3.md#E3.S2]
- [Source: docs/game-architecture.md#Novel Pattern 6; #D6]
- [Source: gdd.md#A Card System — Imp Summoner]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
