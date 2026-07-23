# Story 1.3: Hero action-state machine + action timing windows

Status: ready-for-dev

## Story

As a player,
I want every melee action to be a transition in one explicit table driven by integer-tick timing windows,
so that combat is deterministic, headless-testable, and the presentation layer learns what the hero is doing through a single queued signal.

## Acceptance Criteria

1. `ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }` stays **exactly these six states** on `HeroState` (the enum already exists — no members added or removed; it is the presentation vocabulary 1.10 subscribes to), plus an explicit transition table evaluated by `MatchState` in `advance()` step 3 from `InputIntent` + the active `TimingWindow`s.
   - `CHARGING` is reserved for E5 and unreachable in E1 — the transition is absent, not stubbed as a fake path.
   - `STUNNED` gets the same treatment: declared, with **zero inbound transitions in E1** — the entry transition is absent, not stubbed. Its "accepts no input" row (AC 3) is table data that is **present but unreachable**. The stun `TimingWindow` is owned and advanced (AC 2) but never `start()`ed by any E1 code path. **None of this resolves OPEN decision (a)** (attacker consequence on basic-attack deflect) — that decision stays open and stays Matko's. [Source: decision-log.md#Session 2026-07-22 — OPEN (a)]
   - Windup / active / recovery are **phases within ATTACKING**, expressed by which attack window is currently running — not extra enum states and not extra signals in this story.
2. `HeroState` owns **eight** `TimingWindow`s. `HeroState` is NOT greenfield — reconcile with the existing file: **rename `chargeup` → `windup` and `defense` → `deflect`, keep `stun`, add `active`, `recovery`, `chain`, `roll_iframe`, `roll_duration`.** `tick_timers()` advances all eight in `advance()` step 2, one tick per call, **before** any transition is evaluated. The order (timers advance first, transitions read the result) is written down in the file.
   - **CONSTRAINT C plumbing:** when a transition fires, `MatchState` reads `ms.balance_ticks.<field>` **inline at that moment** and passes the tick count into the window's `start()`. **No `BalanceTicks`-typed field on `HeroState` or anywhere in the state machine** — `apply_balance()` swaps the whole `BalanceTicks` object on reload, so a cached reference would hold stale durations. The behavior asserted by `test_balance_config.gd` (a running window keeps its original duration across a mid-match reload; the next `start()` picks up the new duration) is the behavior this plumbing must preserve. [Source: decision-log.md#CONSTRAINT C]
   - **DEBT A guard (deliberate deferral, see Dev Notes):** **one** guard at the top of the step-3 transition evaluation — if `balance_ticks == null`, transition evaluation is skipped entirely. No scattered per-field null checks.
3. Cancellability is data on the transition table, not scattered `if`s: which states/phases accept a new attack, roll, block, or nothing. E1 convention, **per-phase on the ATTACKING row**: **windup non-cancellable, active non-cancellable, recovery roll-cancellable**; `STUNNED` accepts no input (row present but unreachable, per AC 1). Any deviation is a playtest decision; the table stays one readable block.
   - **Attack chains are in scope as pure transition logic:** ATTACKING → ATTACKING when the attack press lands inside the chain window, capped by `attack_chain_length`. A persistent `chain_index: int` on `HeroState` tracks the position, resets when the attack sequence ends, and enters `to_snapshot()` (AC 6). `attack_chain_length` lives on `BalanceConfig` and deliberately **NOT** on `BalanceTicks` (it is a count, not a duration): `MatchState` reads `ms.balance.attack_chain_length` inline at transition time, under the same no-caching rule as CONSTRAINT C. **Damage application is explicitly out of scope** (later story).
4. Every transition emits a queued `action_state_changed(previous, current)` pushed to the `SignalQueue` (never emitted mid-tick). This is a **modification of existing code, not a new addition**: the signal exists today as single-arg `action_state_changed(state)` and `set_action_state()` emits it — both change to `(previous, current)`. There are no existing subscribers or test assertions on the old signature. This remains the single hook the presentation layer (1.10) and HUD (E2) subscribe to.
5. Headless tests drive fixed intent sequences over N ticks, with **`apply_balance(<test config>)` called in setup** so the machine is fully exercised headless (the live-play deferral of AC 2 must not blind the tests): each action reaches and leaves its states on the exact expected tick; inputs during a non-cancellable window are dropped rather than buffered; the chain advances only inside the chain window and caps at `attack_chain_length`; the emitted signal sequence (after `drain_signals()`) matches the expected list.
   - **STUNNED guard test (bite-verified):** a test enumerates the transition table and **fails on any inbound STUNNED edge**. Verify the bite both ways, like `test_root_rotation_isolation.gd`: temporarily wire a fake inbound edge and confirm the test fails, remove it and confirm it passes.
6. **Snapshot + golden re-baseline (deliberate, snapshot-shape-only).** `HeroState.to_snapshot()` changes exactly as follows: the `chargeup` and `defense` keys are replaced by `windup` and `deflect`; five new window entries are added (`active`, `recovery`, `chain`, `roll_iframe`, `roll_duration`); the new persistent `chain_index` is added. The determinism golden in `test_determinism.gd` therefore moves: regenerate it **deliberately** and record the old → new hash in the Dev Agent Record. This re-baseline is caused by **snapshot shape only** and is **separate from the future DEBT A re-baseline** — different cause: that one happens when the golden path starts calling `apply_balance` at match start, which is **NOT** this story. The two re-baselines never share one silent change.

## Tasks / Subtasks

- [ ] Transition table (AC: 1, 3)
  - [ ] Six-state enum unchanged; table one readable block; per-phase cancellability data on the ATTACKING row (windup and active non-cancellable, recovery roll-cancellable)
  - [ ] Leave **both** CHARGING and STUNNED inbound transitions absent (not stubbed); STUNNED row is data, present but unreachable; nothing resolves OPEN decision (a)
  - [ ] Chain logic: ATTACKING → ATTACKING inside the chain window; `chain_index: int` on `HeroState`, reset when the sequence ends; read `ms.balance.attack_chain_length` inline at transition time (no caching); no damage application
- [ ] Window reconciliation + ownership (AC: 2)
  - [ ] Rename `chargeup` → `windup`, `defense` → `deflect`; keep `stun`; add `active`, `recovery`, `chain`, `roll_iframe`, `roll_duration`; `tick_timers()` advances all eight
  - [ ] Update the existing tests touching the old names (`test/state/test_balance_config.gd`, `test/state/test_economy_and_hero.gd`) as part of this story
  - [ ] Comment the timers-first / transitions-read order in the file
- [ ] CONSTRAINT C plumbing + DEBT A guard (AC: 2)
  - [ ] Step-3 evaluation in `MatchState` reads `ms.balance_ticks.<field>` inline when a transition fires and passes the tick count into `start()`; no `BalanceTicks`-typed field anywhere in the state machine
  - [ ] Single `balance_ticks == null` guard that skips transition evaluation entirely
- [ ] Ordering inside `advance()` (AC: 1, 2, 5)
  - [ ] Per slot in step 3: transitions evaluate **before** `_resolve_movement` — a press on tick N takes effect on tick N
  - [ ] 1-3 transitions neither read nor write `velocity` — action/movement coupling lands in 1-5 (attack) / 1-9 (roll)
  - [ ] Step 1 stays a no-op; update the step-1 reserved comment in `match_state.gd` ("parse attack/block/roll presses") to point at the step-3 evaluation so it does not rot
- [ ] Signal migration (AC: 4)
  - [ ] Change the existing `action_state_changed(state)` declaration and `set_action_state()` to `(previous, current)`; queued push via `SignalQueue` unchanged; confirm no existing subscribers
- [ ] InputIntent key contract (AC: 1, 5)
  - [ ] Intent `pressed`/`held` keys are **prefix-free** (`&"attack"`, `&"block"`, `&"roll"`); the `p1_`/`p2_` prefix is the controller's private Input Map mapping — adjust `keyboard_controller.gd` to write prefix-free keys into the intent
  - [ ] Update the one existing consumer of prefixed intent keys — `test/state/test_controller.gd` asserts `is_held(&"p1_attack")` — and verify no other consumer exists
  - [ ] Zero Input Map / `project.godot` changes (J/K/L for p1 and the p2 set are already mapped)
- [ ] Headless tests (AC: 5)
  - [ ] `apply_balance(<test config>)` in setup; exact-tick entry/exit per action; inputs during non-cancellable windows dropped, not buffered; chain window + cap; signal sequence after `drain_signals()` matches the expected list
  - [ ] STUNNED inbound-edge guard test, bite-verified both ways
- [ ] Snapshot + golden (AC: 6)
  - [ ] `to_snapshot()` key changes exactly as listed in AC 6; regenerate the golden deliberately; record old → new hash in the Dev Agent Record (cause: snapshot shape only — NOT the DEBT A re-baseline)

## Dev Notes

- Pure enum + transition table chosen over a scene `StateMachine` (scene-coupled, `_process`-driven, cannot be tested headless — would violate D1/X6). [Source: docs/game-architecture.md#Hero Action-State Representation]
- Timers advance in `advance()` step 2; transitions resolve in step 3 reading the advanced result. Never flip this order. [Source: docs/game-architecture.md#D2]
- **DEBT A stance — deliberate deferral (option b).** `match_runner.gd` still runs on E0 placeholder constants and never calls `apply_balance()`; its constants carry no action durations, so `balance_ticks` is null in live play. Consequence of the AC 2 guard: **live-play actions are inert until a dedicated follow-up story** wires `apply_balance(BalanceConfigService.get_config())` at match start and re-baselines the golden — that follow-up story carries **both DEBT A halves together**, per the decision log. AC 5 tests call `apply_balance` in setup, so the machine is fully exercised headless in this story. Authored `.tres` duration values remain playtest placeholders whose live tuning becomes meaningful only after that follow-up story. [Source: decision-log.md#DEBT A]
- **STUNNED stays unreachable.** `stun_seconds` / `stun_ticks` are data only (`balance_config.gd` / `balance_ticks.gd` already say so); wiring any inbound STUNNED edge would resolve OPEN decision (a) by accident. The guard test in AC 5 is the executable form of this constraint. [Source: decision-log.md#Session 2026-07-22]
- **Ordering and coupling.** Within step 3, per slot: transitions evaluate before `_resolve_movement`, so a press on tick N takes effect on tick N. This story's transitions do not read or write `velocity`; whether ATTACKING/ROLLING constrain or produce velocity is deferred to 1-5 / 1-9. Step 1 ("ingest intents") stays a no-op — the table reads `InputIntent` directly in step 3.
- **No new phase signals.** Windup/active/recovery are readable off which window is running; 1-10 subscribes to `action_state_changed` only. `action_state_changed` is the **only** channel telling visuals what the hero is doing — no other code path may. [Source: stories-manual-e1.md#E1.S3 item 4]

### Project Structure Notes

- `src/state/hero_state.gd` — enum (unchanged), eight windows (renames + additions per AC 2), `chain_index`, signal signature change, `to_snapshot()` changes.
- `src/state/match_state.gd` — step-3 transition evaluation (before `_resolve_movement`), CONSTRAINT C inline reads, the single `balance_ticks == null` guard, step-1 comment update.
- `src/state/timing/timing_window.gd` — used as-is; no changes.
- `src/state/input/input_intent.gd` — no schema change (the generic `pressed`/`held` dictionaries suffice); document the prefix-free key contract.
- `src/controllers/keyboard_controller.gd` — write prefix-free action keys into the intent (D3(a) untouched: `Input.*` stays only here).
- Tests — new headless action-state suite under `test/state/`; updates to `test/state/test_balance_config.gd`, `test/state/test_economy_and_hero.gd` (old window names), `test/state/test_controller.gd` (prefix-free intent keys) and `test/state/test_determinism.gd` (golden re-baseline per AC 6).
- **Zero Input Map / `project.godot` changes.**

### Project Context Rules

- **Queued signals (D5):** enqueue during `advance()`, drain after; no state-to-state signals. [Source: docs/project-context.md#Signals over polling]
- **Entity state** is a pure enum + transitions in the state layer, never a scene `StateMachine`. [Source: docs/game-architecture.md#Standard Patterns]
- **No hardcoded gameplay numbers:** every duration is read from `balance_ticks`, `attack_chain_length` from `balance`; cancellability booleans are table structure, not balance values. [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: stories-manual-e1.md#E1.S3]
- [Source: docs/game-architecture.md#Hero Action-State Representation; #D2; #D4]
- [Source: decision-log.md#Session 2026-07-22 — OPEN (a); #DEBT A; #CONSTRAINT C]
- [Source: decision-log.md#Session 2026-07-23 — DECISION A (untouched by this story: no root rotation, no rig/basis contact)]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### Golden Re-baseline (old → new hash, cause: snapshot shape — AC 6)

### File List
