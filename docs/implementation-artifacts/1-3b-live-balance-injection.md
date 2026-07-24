---
baseline_commit: b8ba7143a89b301b406106f5ed2da43941b08a04
---

# Story 1.3b: Live balance injection (DEBT A retirement)

Status: done

## Story

As a player,
I want the authored balance values injected into the live match at start,
so that live-play actions actually run and tuning data/balance/balance_config.tres changes the game I feel.

## Acceptance Criteria

1. `match_runner.gd` calls `ms.apply_balance(BalanceConfigService.get_config())` exactly once at match start, before the first tick. This retires DEBT A half 1; the 1-3 `balance_ticks == null` guard stays in place as a permanent invariant, it just never fires in a normally started match.
2. The determinism golden path starts calling `apply_balance` — with a FIXED in-test config (constructed in the test, like test_action_state.gd's `_config()`), deliberately NOT the authored `.tres`: playtest tuning of the `.tres` must never move the golden. The recorded intent sequence is extended to exercise attack, roll, block, and one chain, so the golden now guards transition determinism. One deliberate re-baseline with BOTH causes listed (apply_balance enters the golden path; intent sequence extended), old -> new hash in the Dev Agent Record. This retires DEBT A half 2.
3. A permanent authoring-audit test loads the real `data/balance/balance_config.tres` and asserts every action `*_seconds` field (attack windup/active/recovery/chain window, deflect window, roll iframe/duration) is > 0.0 and `attack_chain_length` >= 1 — the 1-3 phase mechanism degenerates on 0-tick phases, so zero-authored values are defects, not tuning. `stun_seconds` is exempt (data-only until OPEN decision (a)).
4. An integration test (test_hero_movement.gd pattern: real main scene, simulated input) proves the live path end to end: a simulated p1 attack press puts the hero into ATTACKING in the running scene — the proof that DEBT A is actually dead in the game, not just in headless setups. The test observes the transition via the queued `action_state_changed` signal (the D5-sanctioned channel), NOT by reaching into the runner's private `_match_state`: observing via the signal proves the queue drain path end-to-end, not just that the state field changed.

## Tasks / Subtasks

- [x] Runner wiring (AC: 1)
  - [x] `apply_balance(BalanceConfigService.get_config())` once at match start; guard untouched
- [x] Golden path (AC: 2)
  - [x] Fixed in-test config into the golden setup (never the authored .tres); extend the recorded intent sequence (attack, roll, block, one chain); single deliberate re-baseline, both causes recorded
- [x] Authoring audit (AC: 3)
  - [x] Permanent test over the real .tres: all action durations > 0.0, chain length >= 1, stun exempt
- [x] Live integration proof (AC: 4)
  - [x] Simulated p1 attack press in the real scene -> ATTACKING, asserted via the queued `action_state_changed` signal (never via the runner's private `_match_state`)
  - [x] Correct the provenance comment at `test/integration/test_hero_movement.gd:12`: `MOVE_SPEED := 5.0` is commented "matches match_runner._MOVE_SPEED (E0 placeholder)", but once `apply_balance` runs at match start the live `move_speed` comes from `data/balance/balance_config.tres`. The values coincide today so nothing breaks, but the comment's provenance becomes wrong and tuning `move_speed` in the `.tres` would fail this test with a misleading message — rewrite the comment to name the config as the real source

## Dev Notes

- This story retires DEBT A (decision-log): both halves land together, per the locked obligation. No state-layer changes expected — runner, tests, and (if the audit fails) `.tres` authoring only.
- CONSTRAINT C untouched: injection happens once at start; mid-match reload remains DEBT B territory (still deferred).
- The golden's config lives in the test on purpose: the golden guards determinism, not tuning values.
- Inherited, not introduced here: the runner still builds `MatchState.new()` from E0 placeholder constants, which `apply_balance` then partially overwrites (mana stays constructor-driven — `BalanceConfig` has no mana field); story 3-1 folds the constants into the config object, so do not "fix" it in this story.

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

## Readiness Gate

- 2026-07-24: gds-check-implementation-readiness run against this story. Verdict **READY**, zero blocking findings, three advisories: (1) pin the AC 4 observation channel to `action_state_changed` rather than the runner's private `_match_state`; (2) correct the `test_hero_movement.gd:12` MOVE_SPEED provenance comment; (3) note the inherited constructor-placeholder overlap with `apply_balance` (3-1 territory). All three are folded into this document (AC 4, its task list, and Dev Notes).

## Dev Agent Record

### Agent Model Used

claude-fable-5 (Claude Code)

### Debug Log References

- Red-phase run: state harness failed ONLY on `test_state_matches_golden` (old golden vs. new hash), all other 59 tests green — confirming the hash moved for the two declared causes and nothing else regressed.
- One parse fix in `test_live_attack.gd` (`:=` cannot infer from a Variant comparison; typed `var ok: bool` explicitly).
- Final run: `bash test/run_all.sh` → state harness 60 tests / 0 failed / 234 assertions, all 4 integration tests PASS, `ALL TESTS PASSED`.

### Completion Notes List

- **AC 1 — runner wiring.** `match_runner._ready()` now calls `_match_state.apply_balance(BalanceConfigService.get_config())` exactly once at match start, before the first tick, with an `Invariant.check` that the config loaded (a silently-null config would reproduce the exact DEBT A symptom). The 1-3 `balance_ticks == null` guard in `MatchState._resolve_actions` is untouched — permanent invariant, never fires in a normally started match.
- **AC 2 — GOLDEN RE-BASELINE (deliberate, once).** Old `d3f42defd2f442056d22eb43d480ef665f5e1083d3458b1db4ffdf48b932bcf7` → new `40b5a8041c327b416ca235af65fc7c05f494d8b1d7a2e2b2761190b86da1d613`. TWO causes, each named in the test header: (1) `apply_balance` now runs on the golden path, with a FIXED config constructed in the test (`_golden_config()`, modeled on `test_action_state.gd`'s `_config()`) — never `data/balance/*.tres`, so playtest tuning cannot move the golden; (2) the recorded intent sequence widened from 6 movement-only ticks to 24 ticks exercising attack (t1), one chain (t9, self-transition), roll as a recovery roll-cancel (t17), and block press/hold/release (p2, t1–t6). Added `test_recorded_sequence_exercises_all_transitions`, which pins the exact p1/p2 `action_state_changed` sequences so the golden can never silently degrade back to guarding movement only.
- **AC 3 — authoring audit.** New permanent `test/state/test_balance_authoring.gd` loads the REAL `.tres` and asserts all seven action `*_seconds` fields > 0.0 and `attack_chain_length >= 1`. `stun_seconds` exemption stated in the test header (data-only until OPEN decision (a)). The audit passed against the current authored values — no `.tres` change was needed.
- **AC 4 — live integration proof.** New `test/integration/test_live_attack.gd` (test_hero_movement.gd pattern: real `main.tscn`, simulated `p1_attack` press) asserts IDLE → ATTACKING via the queued `action_state_changed` signal. To keep the test off the runner's private `_match_state`, added a minimal read-only subscription seam to the runner — `connect_hero_action_state_changed(slot, callback)` — consistent with the architecture rule that the runner wires signal subscriptions and consumers never hold a MatchState handle. This is the one runner addition beyond the `apply_balance` call, made to satisfy the AC 4 observation-channel constraint (readiness-gate advisory 1).
- **Provenance comment** at `test/integration/test_hero_movement.gd` MOVE_SPEED fixed: names `data/balance/balance_config.tres` (injected via `apply_balance`) as the live source, replacing the stale "matches match_runner._MOVE_SPEED (E0 placeholder)".
- **Untouched, per hard constraints:** DEBT B (`reload()` caching / `CACHE_MODE_IGNORE`), CONSTRAINT C inline `balance_ticks` reads, the Input Map, InputIntent's prefix-free keys, and the constructor-placeholder overlap (runner constants still feed `MatchState.new()`, partially overwritten by `apply_balance`; mana stays constructor-driven — 3-1 territory).
- **Board note:** `sprint-status.yaml` locks lifecycle states to exactly backlog → ready-for-dev → done, so no `in-progress`/`review` state was written there; the story Status above is the review marker. Board promotion to `done` happens at close-out per project convention.
- `.uid` sidecars for the two new test files will be generated by the editor on next scan; none were produced by the headless runs.

### File List

- `src/main/match_runner.gd` (modified — apply_balance at match start + read-only subscription seam)
- `test/state/test_determinism.gd` (modified — fixed in-test golden config, widened 24-tick sequence, sequence-exercise pin test, re-baselined GOLDEN)
- `test/state/test_balance_authoring.gd` (new — permanent authoring audit over the real .tres)
- `test/integration/test_live_attack.gd` (new — live attack press → ATTACKING via queued signal)
- `test/integration/test_hero_movement.gd` (modified — MOVE_SPEED provenance comment only)
- `docs/implementation-artifacts/1-3b-live-balance-injection.md` (modified — this story file)

## Change Log

- 2026-07-24: Story 1-3b implemented — DEBT A retired (both halves together: runner `apply_balance` at match start + deliberate golden re-baseline `d3f42def…bcf7` → `40b5a804…d613`); permanent authoring audit and live integration proof added. Full suite green (60 state tests / 234 assertions + 4 integration tests).
