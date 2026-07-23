# Story 1.3b: Live balance injection (DEBT A retirement)

Status: backlog

## Story

As a player,
I want the authored balance values injected into the live match at start,
so that live-play actions actually run and tuning data/balance/balance_config.tres changes the game I feel.

## Acceptance Criteria

1. `match_runner.gd` calls `ms.apply_balance(BalanceConfigService.get_config())` exactly once at match start, before the first tick. This retires DEBT A half 1; the 1-3 `balance_ticks == null` guard stays in place as a permanent invariant, it just never fires in a normally started match.
2. The determinism golden path starts calling `apply_balance` — with a FIXED in-test config (constructed in the test, like test_action_state.gd's `_config()`), deliberately NOT the authored `.tres`: playtest tuning of the `.tres` must never move the golden. The recorded intent sequence is extended to exercise attack, roll, block, and one chain, so the golden now guards transition determinism. One deliberate re-baseline with BOTH causes listed (apply_balance enters the golden path; intent sequence extended), old -> new hash in the Dev Agent Record. This retires DEBT A half 2.
3. A permanent authoring-audit test loads the real `data/balance/balance_config.tres` and asserts every action `*_seconds` field (attack windup/active/recovery/chain window, deflect window, roll iframe/duration) is > 0.0 and `attack_chain_length` >= 1 — the 1-3 phase mechanism degenerates on 0-tick phases, so zero-authored values are defects, not tuning. `stun_seconds` is exempt (data-only until OPEN decision (a)).
4. An integration test (test_hero_movement.gd pattern: real main scene, simulated input) proves the live path end to end: a simulated p1 attack press puts the hero into ATTACKING in the running scene — the proof that DEBT A is actually dead in the game, not just in headless setups.

## Tasks / Subtasks

- [ ] Runner wiring (AC: 1)
  - [ ] `apply_balance(BalanceConfigService.get_config())` once at match start; guard untouched
- [ ] Golden path (AC: 2)
  - [ ] Fixed in-test config into the golden setup (never the authored .tres); extend the recorded intent sequence (attack, roll, block, one chain); single deliberate re-baseline, both causes recorded
- [ ] Authoring audit (AC: 3)
  - [ ] Permanent test over the real .tres: all action durations > 0.0, chain length >= 1, stun exempt
- [ ] Live integration proof (AC: 4)
  - [ ] Simulated p1 attack press in the real scene -> ATTACKING

## Dev Notes

- This story retires DEBT A (decision-log): both halves land together, per the locked obligation. No state-layer changes expected — runner, tests, and (if the audit fails) `.tres` authoring only.
- CONSTRAINT C untouched: injection happens once at start; mid-match reload remains DEBT B territory (still deferred).
- The golden's config lives in the test on purpose: the golden guards determinism, not tuning values.

### Project Structure Notes

- `src/main/match_runner.gd` — the apply_balance call.
- `test/state/test_determinism.gd` — golden setup + intent sequence + re-baseline.
- New audit test under `test/state/`; new/extended integration test under `test/integration/`.
- `data/balance/balance_config.tres` — only if the audit finds zero-authored action values.

### Project Context Rules

- Balance is injected, state never reads the service. [Source: docs/project-context.md]
- No hardcoded gameplay numbers — the audit enforces authored non-zero, it does not supply values. [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: decision-log.md#DEBT A; #Session 2026-07-23 — Story 1-3 close-out]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
