# Story 3.1: `MatchState` config object + card/economy balance schema

Status: ready-for-dev

> **⚠ E3 REVISIT GATE (verbatim from stories-manual-e3.md) — read before implementing any E3 story.**
> These stories are provisional and must be reviewed after the first E1/E2 playtest, before implementation. They were written before anyone had played the melee layer against a human, and they rest on assumptions about how melee actually feels — attack cadence, how much downtime a player has between exchanges, whether there is any attention left over for a hand of cards at all. That is exactly the P4 question this project exists to answer, and it cannot be answered from a document.
> The gate is a real step, not a formality: after the E2 playtest, re-read the E3 stories against `docs/playtest-log.md` and either confirm each story, amend it, or delete it. Record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a solo developer about to add card and economy fields,
I want `MatchState`'s five positional constructor floats folded into one injected config object and the E3 balance fields added and tick-converted,
so that the refactor happens while call sites are still few, and every new number is authored data re-applied by hot-reload.

## Acceptance Criteria

1. `MatchState`'s five positional constructor floats (`seed`, `max_hp`, `move_speed`, `max_stamina`, `max_mana`) are folded into a single injected config/params object, and the small number of existing call sites are updated. Doing this before E3 adds fields is the point of the scheduled timing.
2. The balance schema is extended with the E3 fields: `hand_size`, `deck_size`, `max_mana`, `mana_regen_per_second`, `mana_per_melee_hit`, `draw_replacement_delay_seconds`, `reshuffle_vulnerable_window_seconds`, `default_copies_per_card`. All values TBD-in-playtest.
3. Every new `*_seconds` field is converted to ticks once at load through the 1.1 conversion boundary, and the X3 hot-reload path re-converts them and re-injects the new bounds into `ManaPool`.
4. The `.tres` smoke test and the determinism regression are extended to cover the new config shape, so a missing/renamed field fails a test rather than surfacing as a mysterious zero mid-playtest.
5. State injection discipline holds: state receives the config object and the `FeatureFlags` resource by injection and never reads `BalanceConfigService` or `FeatureFlagsService`. The architecture invariant test is re-run after the refactor.

## Tasks / Subtasks

- [ ] Fold the five positional floats into one injected config object; update call sites (AC: 1)
- [ ] Add the E3 balance fields (AC: 2)
- [ ] Tick-convert new `*_seconds` via the 1.1 boundary; wire X3 re-inject into `ManaPool` (AC: 3)
- [ ] Extend `.tres` smoke test + determinism regression for the new shape (AC: 4)
- [ ] Re-run the architecture invariant test; confirm injection discipline (AC: 5)

## Dev Notes

- This refactor is explicitly scheduled for E3, while call sites are few; retrofitting after many callers exist is the failure mode. [Source: docs/game-architecture.md#Planned (E3) — MatchState config object]
- Reuses the 1.1 single conversion boundary and X3 re-injection pattern. [Source: stories-manual-e1.md#E1.S1; docs/game-architecture.md#Novel Pattern 2]

### Project Structure Notes

- `src/state/match_state.gd` constructor; schema in `src/state/resources/balance_config.gd`; `ManaPool` re-inject via `set_maximum`.

### Project Context Rules

- **State receives schema by injection, never reads a `*Service`.** [Source: docs/project-context.md#Autoloads; docs/game-architecture.md#Novel Pattern 2]
- **Zero hardcoded numbers; hot-reloadable balance.** [Source: docs/project-context.md#Data as Resources]

### References

- [Source: stories-manual-e3.md#E3.S1]
- [Source: docs/game-architecture.md#Planned (E3) — MatchState config object]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
