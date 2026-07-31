# Story 3.1: `MatchState` config object + card/economy balance schema

Status: backlog

> **⚠ E3 REVISIT GATE (verbatim from stories-manual-e3.md) — read before implementing any E3 story.**
> These stories are provisional and must be reviewed after the first E1/E2 playtest, before implementation. They were written before anyone had played the melee layer against a human, and they rest on assumptions about how melee actually feels — attack cadence, how much downtime a player has between exchanges, whether there is any attention left over for a hand of cards at all. That is exactly the P4 question this project exists to answer, and it cannot be answered from a document.
> The gate is a real step, not a formality: after the E2 playtest, re-read the E3 stories against `docs/playtest-log.md` and either confirm each story, amend it, or delete it. Record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing.

## Story

As a solo developer about to add card and economy fields,
I want `MatchState`'s five positional constructor floats folded into one injected config object and the E3 balance fields added and tick-converted,
so that the refactor happens while call sites are still few, and every new number is authored data re-applied by hot-reload.

## Acceptance Criteria

1. `MatchState`'s five positional constructor floats (`seed`, `max_hp`, `move_speed`, `max_stamina`, `max_mana`) are folded into a single injected config/params object, and the small number of existing call sites are updated. Doing this before E3 adds fields is the point of the scheduled timing.
2. The balance schema is extended with the E3 fields: `hand_size`, `deck_size`, `max_mana`, `mana_regen_per_second`, `melee_hit_mana` (renamed from `mana_per_melee_hit` — that field already ships as `melee_hit_mana`, `balance_config.gd:44`/`data/balance/balance_config.tres:21`; a second field of the same meaning under a different name would author a duplicate, not extend the schema), `draw_replacement_delay_seconds`, `reshuffle_vulnerable_window_seconds`, `default_copies_per_card`. All three mana numbers (`max_mana`, `mana_regen_per_second`, `melee_hit_mana`) are authored TOGETHER as one coherent set per the E3 revisit gate (decision-log E3-RG/R1) — not tuned independently of each other or of 3-2's card costs.
3. Every new `*_seconds` field is converted to ticks once at load through the 1.1 conversion boundary. The X3 re-conversion path re-injects the new bounds into `ManaPool` on `apply_balance()` — this is currently a TEST-ONLY path: no live mid-match reload trigger exists yet (DEBT B, decision-log Session 2026-07-22, still live at every close-out through 2-6/3-0a), so "hot-reload" here means what `test_mid_match_reload_refills_stamina_to_max`-style tests exercise via a direct `apply_balance()` call, not a runtime-triggerable event. Word the AC and its tests accordingly — do not imply a player-facing reload trigger exists.
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
- **The constructor/`apply_balance` double injection (`match_state.gd:544`).** Today `MatchState._init` sets `move_speed`/`max_stamina` (among others) from the five positional floats, and `apply_balance()` sets the SAME two fields again from the injected `BalanceConfig` (`_apply_balance_to_player`, `match_state.gd:539-545`) plus refills stamina to the new max (D9). Folding the constructor floats into the config object does not remove this double write by itself: name explicitly which injection survives as the single source of truth for `move_speed`/`max_stamina` going forward — the constructor should stop setting values `apply_balance()` immediately overwrites, so there is exactly one write path per field, not two that happen to agree at match start. [Source: decision-log.md E3-RG/R9; match_state.gd:539-545]
- **The seed does NOT go into `BalanceConfig` or any hot-reloadable resource (decision-log E3-RG/R9, locked).** It lives in a separate match-scoped params object, injected once at construction, never re-applied by `apply_balance()` — a reload that re-seeds the RNG mid-match is a determinism hole. Do not fold `seed` into the same config object `apply_balance()` consumes, even though the "Planned (E3)" architecture note names it alongside the other four constructor floats. [Source: decision-log.md E3-RG/R9; match_state.gd:59,92-93,175-178; game-architecture.md#Planned (E3) — MatchState config object]
- **`ManaPool` vs `StaminaPool` refill-on-reload reconciliation.** Verified by content: `_apply_balance_to_player` calls `player.stamina.set_maximum()` THEN `player.stamina.refill()` (full refill to the new max, the D9 ruling) on every `apply_balance()` — but makes no corresponding call on `player.mana` at all today, because `BalanceConfig` has no `max_mana` field yet. Once `max_mana` lands in this story, decide explicitly whether `ManaPool.set_maximum()` is called on reload (bounds re-injection, uncontroversial) and whether mana is ALSO refilled to full the way stamina is — the latter would be wrong: `ManaPool`'s own doc comment states "Mana starts empty and is built by the flywheel" (`mana_pool.gd:4-5`), so a reload-refill would hand a free full bar mid-match and break the flywheel P2 depends on. The two pools are not symmetric and must not be made so by accident. [Source: decision-log.md E3-RG/R1; match_state.gd:539-545; mana_pool.gd:4-5,45-47]
- **The basic-attack stamina cost is NOT this story's seat.** `epics.md:96-97` still reads as though 3-1 "carries OPEN decision (d)... as a seat if the E2 retro adopts it" — that text is stale (decision-log DP/R2 already resolved decision (d) to YES, and decision-log E3-RG/R2 assigns the value + implementation to a STANDALONE corrective pass that lands BEFORE this story, in the shape of the melee-damage corrective, precisely so its certain golden re-baseline carries exactly one named cause). By the time this story's dev pass starts, the stamina-cost field and its golden re-baseline already exist upstream; this story consumes that state, it does not create it. [Source: decision-log.md E3-RG/R2; decision-log.md:1037,1039; epics.md:96-97]

### Project Structure Notes

- `src/state/match_state.gd` constructor; schema in `src/state/resources/balance_config.gd`; `ManaPool` re-inject via `set_maximum`.

### Project Context Rules

- **State receives schema by injection, never reads a `*Service`.** [Source: docs/project-context.md#Autoloads; docs/game-architecture.md#Novel Pattern 2]
- **Zero hardcoded numbers; hot-reloadable balance.** [Source: docs/project-context.md#Data as Resources]

### References

- [Source: stories-manual-e3.md#E3.S1]
- [Source: docs/game-architecture.md#Planned (E3) — MatchState config object]

## Golden Prediction

**NONE, measured in both directions.** This story re-threads five existing values (seed, max_hp,
move_speed, max_stamina, max_mana) through a config object instead of five positional floats, and adds
new balance fields that nothing yet reads (`hand_size`, `deck_size`, `mana_regen_per_second`, etc. are
authored but unconsumed until 3-3/3-4). No new `advance()` path, no new `to_snapshot()` field, and the
final values reaching state are unchanged if the constructor/`apply_balance` double-injection reconciliation
(above) resolves to the same numbers a match starts with today. Baseline hash `33817201...21da2`
(`test_state_matches_golden`). Any movement is a stop-and-report finding, never a silent re-baseline —
per the 1-5 cause-(c) lesson, the prediction is measured, not trusted.

## Live Smoke

**NOT REQUIRED.** This story touches only `src/state/` (the constructor/config refactor) and
`src/state/resources/balance_config.gd` (new fields); it adds no actor, controller, or presentation
code, and consumes no observation seam. Nothing here is exercisable in a way a live smoke would reveal
that the headless suite (the extended `.tres` smoke test + determinism regression, AC4) does not already
cover. If the dev pass finds this untrue — e.g. a call site the story missed touches presentation — that
is a scope finding for `decision-log.md`, not a reason to skip the smoke silently.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
