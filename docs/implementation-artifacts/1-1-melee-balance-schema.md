---
baseline_commit: 427ef4fdbe26bdf973bc5d18c31e968192d0ec6c
---

# Story 1.1: Melee balance schema + hot-reloadable seconds→ticks conversion

Status: done

## Story

As a solo developer tuning soulsborne feel,
I want every E1 melee number authored in a balance `.tres` and converted from seconds to integer ticks exactly once at load and at hot-reload,
so that I can retune combat timing mid-match without a restart and the state layer never sees a float duration.

## Acceptance Criteria

1. Create `src/state/resources/balance_config.gd` (`class_name BalanceConfig`, `extends Resource`) carrying all E1 melee fields as grouped `@export`s: hero (`max_hp`, `move_speed`); stamina (`max_stamina`, `stamina_regen_per_second`, `stamina_regen_delay_seconds`, `roll_stamina_cost`, `deflect_stamina_cost`); attack (`attack_windup_seconds`, `attack_active_seconds`, `attack_recovery_seconds`, `attack_chain_window_seconds`, `attack_chain_length`, `attack_damage_percent_of_max_hp`); defense (`block_damage_multiplier`, `deflect_window_seconds`); roll (`roll_iframe_seconds`, `roll_duration_seconds`, `roll_distance`); stun (`stun_seconds` — data field only, see Dev Notes). Real values are first-guess placeholders authored in `data/balance/`, treated as TBD-in-playtest.
2. A single conversion boundary (`BalanceTicks` helper or a `to_ticks()` block on the injected config wrapper) converts every `*_seconds` field to a tick count **once**, at load and at X3 reload, via `TimingWindow.seconds_to_ticks()` (`round()`, clamped `>= 1` for any non-zero duration). No `*_seconds` field reaches `advance()`.
3. The X3 hot-reload path is wired end-to-end for the new fields: `BalanceConfigService` reloads the `.tres` → `MatchState.apply_balance(config)` re-injects pool bounds (`set_maximum`-style, re-clamp + re-signal) and re-converts durations. A `TimingWindow` already in flight keeps its original duration; the new value takes effect at its next `start()`.
4. The `.tres` smoke test asserts every new field is present and non-negative; a headless conversion test asserts `0.0 s → 0 ticks`, a sub-tick non-zero duration → exactly 1 tick, and `round()` (not floor/ceil) at the halfway boundary.
5. A headless test proves a mid-match reload does not disturb an in-flight window: start a window, tick partway, apply a config with a different duration, assert the running window finishes on its original tick count while the next `start()` uses the new one.
6. `bash test/run_all.sh` exits zero, including the new conversion and hot-reload tests.

## Tasks / Subtasks

- [x] Create `balance_config.gd` (`class_name BalanceConfig`) schema (AC: 1)
  - [x] Add the hero/stamina/attack/defense/roll/stun `@export` groups; author placeholder `.tres` under `data/balance/`
- [x] Build the single seconds→ticks conversion boundary (AC: 2)
  - [x] Route every `*_seconds` through `TimingWindow.seconds_to_ticks()` once at load; expose only tick counts to state
- [x] Wire the X3 hot-reload path for the new fields (AC: 3)
  - [x] Add `MatchState.apply_balance(config)`: re-injects bounds via `set_maximum` and re-converts durations; in-flight windows keep their original duration
- [x] Tests (AC: 4, 5, 6)
  - [x] Extend `.tres` smoke test for presence + non-negativity
  - [x] Conversion boundary cases (0 → 0, sub-tick → 1, round at halfway)
  - [x] Mid-match reload does not disturb an in-flight window

## Dev Notes

- This is the E1 entry point: it establishes the balance-authoring + tick-conversion discipline every later E1 story reads from. Nothing downstream may hardcode a gameplay number or read a `*_seconds` value inside `advance()`.
- The conversion happens **once** (load / X3 reload), never per tick — a per-tick `round()` would reintroduce float coupling. `seconds_to_ticks` uses `round()` with a `>= 1`-tick clamp for any non-zero duration so a sub-tick window still opens rather than never firing. [Source: docs/game-architecture.md#D4 — Timing-Window Primitive; Novel Pattern 4]
- In-flight window on reload keeps its original duration (no proportional rescale) — replay must reproduce recorded reload events, not an interpolation. [Source: docs/game-architecture.md#D4/A1]
- Pool re-injection uses the `set_maximum` re-clamp + re-signal pattern. [Source: docs/game-architecture.md#Novel Pattern 2]
- Implementing 1-1 supersedes the "BalanceConfig schema/`.tres` authored in E3" comment in `src/systems/balance_config_service.gd`; that comment must be updated at implementation time.
- `stun_seconds` is a duration field only. No E1 code path enters `STUNNED` — the only E1-plausible stun trigger is attacker-stun-on-deflect, which is OPEN decision (a) and must NOT be wired in E1. Adding this field does not resolve (a). (see decision-log.md)
- No runtime reload trigger is in E1 scope; "wired end-to-end" (AC 3) means `reload()` → `apply_balance` → pools/windows, proven by the headless tests (AC 5). Do not add a debug keybind or any Input Map / `project.godot` edit.

### Project Structure Notes

- Schema: create `src/state/resources/balance_config.gd` (`class_name BalanceConfig`) — new in this story, as is `MatchState.apply_balance(config)`. Loader/service already exists: `src/systems/balance_config_service.gd` (autoload, hot-reload). State receives the `BalanceConfig` schema by injection and never reads `BalanceConfigService`. [Source: docs/game-architecture.md#Schema vs Loader; Novel Pattern 2]
- Authored instances live in `data/balance/`.

### Project Context Rules

- **Zero hardcoded gameplay numbers** — balance lives in `.tres`. [Source: docs/project-context.md#Data as Resources]
- **Deterministic timing (A1):** integer ticks via `TimingWindow`; `TICK_HZ` must equal `physics/common/physics_ticks_per_second`. Never a float accumulator or engine `Timer`. [Source: docs/project-context.md#Deterministic timing]
- **X3 hot-reload** is a config-layer requirement, not a debug nicety; `FeatureFlags` is load-once, balance is hot-reloadable. [Source: docs/game-architecture.md#BINDING X3]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/stories-manual-e1.md#E1.S1]
- [Source: docs/game-architecture.md#D4; #Novel Pattern 4; #Novel Pattern 2; #BINDING X3]
- [Source: docs/project-context.md#Deterministic timing; #Data as Resources]

## Dev Agent Record

### Agent Model Used

Claude Fable 5 (claude-fable-5) via Claude Code / gds-dev-story.

### Debug Log References

- Rebuilt the global class cache after adding the new `class_name`s (`godot --headless --editor --quit --path .`), then ran `bash test/run_all.sh`: 36 state tests / 141 assertions PASS, integration PASS, ALL TESTS PASSED.
- Determinism golden verified unchanged: `test_determinism.gd::test_state_matches_golden` passes against the pre-existing GOLDEN hash (`MatchState` constructor and `to_snapshot()` untouched; `apply_balance` is purely additive).
- Architecture invariants green: F1 single `_physics_process`, D3(a) Input only in controllers, D3(b) no nondeterministic source in `src/state/`.

### Completion Notes List

- **Schema (AC 1):** `BalanceConfig` carries all 19 E1 fields in `@export_group`s. Script defaults are all zero **on purpose** — no gameplay number lives in code; authored first-guess values live only in `data/balance/balance_config.tres` (the exact path `BalanceConfigService.CONFIG_PATH` already pointed at).
- **Conversion boundary (AC 2):** `BalanceTicks` (`src/state/timing/balance_ticks.gd`, beside `timing_window.gd`) is the single seconds→ticks boundary; `from_config()` converts all nine `*_seconds` fields via `TimingWindow.seconds_to_ticks()` once per `apply_balance`. `stamina_regen_per_second` is a rate, not a `*_seconds` duration, so it is deliberately not converted here (per-tick regen math belongs to the stamina story).
- **Hot-reload path (AC 3):** `MatchState.apply_balance(config)` stores `balance` + `balance_ticks` and re-injects bounds P1→P2: `StaminaPool.set_maximum` (existing) plus new `HeroState.set_max_hp` written in the same set_maximum-style re-clamp + re-signal pattern; `move_speed` is re-assigned directly (public var). All re-signals go through the SignalQueue (D5) — proven by the test asserting nothing emits before `drain_signals()`.
- **stun_seconds / stun_ticks are data-only:** converted like every duration but nothing starts a stun window; no code path enters `STUNNED`. Open decision (a) untouched.
- **Scope kept:** no debug keybind, no Input Map / `project.godot` edit, no runner change (the E0 placeholder constants in `match_runner.gd` are the E3-designated injection point and folding them into config injection is not tasked in 1-1), no sprint-status.yaml edit.
- **Stale comment fixed:** `balance_config_service.gd` no longer claims the schema is "authored in E3"; `_config`/`get_config()` now typed `BalanceConfig`.
- **Observation for review (unchanged, not mapped to any task/AC):** `reload()` uses `load()`, which returns the *cached* resource if the `.tres` is already loaded — a mid-session on-disk edit would need `ResourceLoader.load(..., CACHE_MODE_IGNORE)` to be picked up. Harmless in E1 (no runtime reload trigger is in scope) but worth deciding when a real trigger lands.

### File List

- `src/state/resources/balance_config.gd` (new, + `.uid`)
- `src/state/timing/balance_ticks.gd` (new, + `.uid`)
- `src/state/match_state.gd` (modified — `balance`/`balance_ticks` fields, `apply_balance`, `_apply_balance_to_player`)
- `src/state/hero_state.gd` (modified — `set_max_hp`)
- `src/systems/balance_config_service.gd` (modified — comment refresh + `BalanceConfig` typing)
- `data/balance/balance_config.tres` (new — authored placeholder values, TBD-in-playtest)
- `test/state/test_balance_config.gd` (new, + `.uid` — 7 tests for AC 2/3/4/5)
- `test/state/test_data_resources.gd` (modified — E1 field presence + non-negativity smoke test)
- `docs/implementation-artifacts/1-1-melee-balance-schema.md` (this story record)

## Change Log

- 2026-07-22: Story 1-1 implemented — BalanceConfig schema + authored `.tres`, BalanceTicks single seconds→ticks conversion boundary, `MatchState.apply_balance` X3 hot-reload seam, tests (7 new + smoke extension). Full suite green; determinism golden unchanged. Status → review.
