# Story 1.4: Stamina economy

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want stamina to regenerate a fixed per-tick amount and gate roll and deflect through one deduction path and one lockout rule,
so that "I had nothing left" is a legible, deterministic outcome rather than a scattered inline check.

## Acceptance Criteria

1. `StaminaPool` gains regeneration: a **fixed per-tick amount** converted once at load from `stamina_regen_per_second` (never `rate × delta`), applied in `advance()` step 5, with a regen-delay window that restarts on every stamina spend.
2. Every stamina cost routes through **one** deduction path used by roll, deflect, and (reserved, flag-off until E5) unblockable init/defense. Costs come from injected balance; no action subtracts stamina inline.
3. Zero-stamina lockout is a **precondition on the transition table**, not a post-hoc failure: with insufficient stamina the roll/deflect transition never fires and the hero stays in its current state. A queued `action_rejected(action, reason)` is emitted (loss legibility is mandatory).
4. Generation is expressed as a `ResourceGenerationRule` `.tres` (`source: &"passive_tick"`, `resource: &"stamina"`) evaluated by the existing `EconomyEvaluator`, so the Stamina Accelerator totem (E4) is a new `.tres` rather than code. If the evaluator does not yet cover stamina, extend it here.
5. Headless tests: regen reaches max in the expected tick count and never overshoots; the delay window restarts on spend; an action at exactly the cost succeeds and at cost-minus-one is rejected with the signal; `stamina_changed` fires only on actual change.

## Tasks / Subtasks

- [ ] Add fixed per-tick regen + restart-on-spend delay window to `StaminaPool` (AC: 1)
- [ ] Route all stamina costs through one injected-cost deduction path (AC: 2)
- [ ] Make zero-stamina a transition-table precondition; emit `action_rejected` (AC: 3)
- [ ] Express stamina passive-tick as a `ResourceGenerationRule` `.tres` via `EconomyEvaluator` (AC: 4)
  - [ ] Extend the evaluator to cover stamina if needed
- [ ] Headless tests (AC: 5)

## Dev Notes

- Fixed per-tick regen (per-second value converted once at load) — never `rate × delta`; `advance()` has no `delta`. [Source: docs/game-architecture.md#D2 A1 follow-up]
- Lockout is a **precondition** (transition never fires), not a post-hoc rejection — this keeps the gate in the one transition table from 1.3. [Source: stories-manual-e1.md#E1.S4 item 3]
- Expressing regen as a data rule now is what makes the E4 Stamina Accelerator a `.tres`, not a code change — the economy-wide scope D6 was written for. [Source: docs/game-architecture.md#D6]

### Project Structure Notes

- `src/state/pools/stamina_pool.gd`, `src/state/economy/economy_evaluator.gd`, rule `.tres` under `data/balance/` or a rules folder. Reserved E5 unblockable costs are flag-off, not built.

### Project Context Rules

- **Feature flags / graceful degradation:** the reserved unblockable cost path is flag-off; state reads injected `FeatureFlags`, never the service. [Source: docs/project-context.md#HARD RULE — Feature flags]
- **Loss legibility** (GDD Success Metrics): the player must be able to say why they lost — hence `action_rejected`. [Source: gdd.md#Success Metrics]

### References

- [Source: stories-manual-e1.md#E1.S4]
- [Source: gdd.md#Primary Mechanics — Hero resources; #Economy and Resources]
- [Source: docs/game-architecture.md#D6; #Novel Pattern 2; #Novel Pattern 5]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
