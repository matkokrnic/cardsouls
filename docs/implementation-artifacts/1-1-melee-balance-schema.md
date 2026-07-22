# Story 1.1: Melee balance schema + hot-reloadable seconds→ticks conversion

Status: ready-for-dev

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

- [ ] Create `balance_config.gd` (`class_name BalanceConfig`) schema (AC: 1)
  - [ ] Add the hero/stamina/attack/defense/roll/stun `@export` groups; author placeholder `.tres` under `data/balance/`
- [ ] Build the single seconds→ticks conversion boundary (AC: 2)
  - [ ] Route every `*_seconds` through `TimingWindow.seconds_to_ticks()` once at load; expose only tick counts to state
- [ ] Wire the X3 hot-reload path for the new fields (AC: 3)
  - [ ] Add `MatchState.apply_balance(config)`: re-injects bounds via `set_maximum` and re-converts durations; in-flight windows keep their original duration
- [ ] Tests (AC: 4, 5, 6)
  - [ ] Extend `.tres` smoke test for presence + non-negativity
  - [ ] Conversion boundary cases (0 → 0, sub-tick → 1, round at halfway)
  - [ ] Mid-match reload does not disturb an in-flight window

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

### Debug Log References

### Completion Notes List

### File List
