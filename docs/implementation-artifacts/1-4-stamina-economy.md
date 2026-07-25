# Story 1.4: Stamina economy

Status: backlog

## Story

As a player,
I want stamina to regenerate a fixed per-tick amount and gate roll through one deduction path and one lockout rule,
so that "I had nothing left" is a legible, deterministic outcome rather than a scattered inline check.

## Acceptance Criteria

1. **Regen amount — single owner, legal home (D2/D3).** `StaminaPool` gains regeneration: a **fixed per-tick amount** applied in `advance()` step 5, with a regen-delay window that restarts on every stamina spend. `BalanceConfig.stamina_regen_per_second` is the **sole authority** for the regen amount — no rule `.tres`, no second home. The per-tick amount is converted **once at load** into a derived field `BalanceTicks.stamina_regen_per_tick`, computed in `from_config()` from `stamina_regen_per_second` and `TimingWindow.TICK_HZ`. Consumers read `ms.balance_ticks.stamina_regen_per_tick` **inline at the moment of use** — CONSTRAINT C forbids caching a reference to the `BalanceTicks` object, not storing derived values inside it.
2. **Regen conditions (D6).** Stamina regenerates in **every** action state EXCEPT: (1) while the post-spend delay window is counting, and (2) while the hero is in `BLOCKING`. No other state suppresses regen.
3. **One deduction path (D4).** Every stamina cost routes through **one** deduction path; in 1-4 it is used by **roll only**. Basic attack is **free** — it costs no stamina, per the GDD's resource-consumers list (`gdd.md:139`) and resource table (`gdd.md:319`). The cost is read inline from the injected balance at the moment of the transition; no action subtracts stamina inline elsewhere. `BLOCKING` entry is free — no stamina check, no deduction. `deflect_stamina_cost` remains a pure data field with **no consumer until 1-8**; reserved E5 unblockable costs stay flag-off, not built.
4. **Lockout + rejection semantics (D5).** Zero-stamina lockout is a **precondition on the transition-table evaluation**: with insufficient stamina the roll transition never fires and the hero stays in its current state. The rejected edge returns false and **falls through to the next `INPUT_PRIORITY` candidate in the same tick** — identical to the capped-chain reject pinned in 1-3 (`match_state.gd` `_try_transition`; `test_action_state.gd` fallthrough pin); max one transition per tick is unchanged: a stamina-rejected roll must let a same-tick lower-priority block press fire. Attack, being higher priority and free, is never stamina-rejected. A queued `action_rejected(action, reason)` is emitted for the rejected press **even if a lower-priority action succeeds that tick** (loss legibility is mandatory). The signal is owned by `HeroState`, declared next to `action_state_changed` (`hero_state.gd:15`), emitted through the existing D5 queued mechanism. **No runner seam is built in 1-4** — there is no consumer yet; the 1-10 seam obligation is recorded in the decision-log. The 1-3 capped-chain reject stays **silent**: 1-4 introduces `action_rejected` for the stamina-rejected roll only and must not widen the signal to cover the chain cap — changing that is a separate decision, not a 1-4 implementation detail. The reason-string vocabulary is the dev's choice.
5. **Start full (D9).** After `apply_balance()`, each pool's current stamina is set to the authored maximum.
6. **Snapshot + golden (D8).** The regen-delay window **is snapshotted** — a mid-count window excluded from the snapshot is a determinism/replay hole — and that is a deliberate snapshot **shape change**. Additionally, `_golden_config()` (`test_determinism.gd:51-64`) is extended with real stamina values so the golden sequence actually exercises spend, regen, and the delay window. `_golden_config()` is a fixed in-test config, so its values are chosen for **coverage, not game feel**: the authored regen delay must be short enough that, after the t17 roll spend, the delay expires AND regen visibly runs before the run ends at t24. An explicit assertion pins this — stamina dips below maximum after the t17 roll and increases again before the final tick — the same guard against a silently-inert sequence that `test_recorded_sequence_exercises_all_transitions` provides for the transitions. Because the golden hashes the **final snapshot only** (`test_determinism.gd:134-137` — `_run()` hashes `ms.to_snapshot()` once, after the sequence), `_golden_config()` values must additionally leave the pool **MID-REGEN at t24** — below maximum and above the immediate post-spend value — so the hashed state itself encodes both the spend and the regen; a regen fast enough to refill by t24 would leave the final stamina value identical to a run that never spent. The recorded intent sequence itself (attack/chain/roll/block, extended in 1-3b) is **not** changed. That is ONE re-baseline with TWO causes, which must be named **separately** in both the commit message and the Dev Agent Record — same pattern as 65811b3. The golden path stays on the in-test `_golden_config`, never the authored `.tres`.
7. **Authoring audit extension (D7).** `test_balance_authoring.gd` gains a **new non-duration assertion class**, kept visually separate from the existing duration block: `max_stamina > 0`, `stamina_regen_per_second > 0`, `roll_stamina_cost > 0`. EXEMPT, each with a one-line reason in the file header exactly like `stun_seconds`: `deflect_stamina_cost` — no consumer until 1-8; `stamina_regen_delay_seconds` — 0 is legitimate tuning (no delay), not a defect.
8. Headless tests: regen reaches max in the expected tick count and never overshoots; the delay window restarts on spend; an action at exactly the cost succeeds and at cost-minus-one is rejected with the signal; `stamina_changed` fires only on actual change.

**OUT OF SCOPE (D1 / DEBT D):** 1-4 does **not** create `EconomyEvaluator`, `ResourceGenerationRule`, or `src/state/economy/`. Stamina spend is implemented directly in the step-3 evaluation alongside the existing transition logic, and regen directly in `advance()` step 5. The D6 evaluator is **deferred, not abandoned** — see decision-log DEBT D; the 1-5 mana hook is the trigger that must reconcile against it.

## Tasks / Subtasks

- [ ] Add derived field `stamina_regen_per_tick` to `BalanceTicks.from_config()` (from `stamina_regen_per_second` and `TimingWindow.TICK_HZ`) (AC: 1)
  - [ ] Amend the comment at `balance_ticks.gd:10-11`: `BalanceTicks` is the home for **load-time derived tick-domain values**, not only duration→tick conversions
- [ ] Add fixed per-tick regen + restart-on-spend delay window to `StaminaPool`; apply in `advance()` step 5; suppress while the delay window is counting or the hero is `BLOCKING` (AC: 1, 2)
- [ ] Route the roll cost through one deduction path in the step-3 evaluation; cost read inline from the injected balance at the moment of the transition (AC: 3)
- [ ] Make insufficient stamina a transition-evaluation precondition: rejected edge returns false and falls through per `INPUT_PRIORITY`; emit queued `action_rejected(action, reason)` from `HeroState` (AC: 4)
- [ ] Set current stamina to the authored maximum after `apply_balance()` (AC: 5)
- [ ] Snapshot the regen-delay window; extend `_golden_config()` with real stamina values; ONE deliberate re-baseline, TWO causes named separately in commit message + Dev Agent Record (65811b3 pattern) (AC: 6)
  - [ ] Author `_golden_config()` stamina values for coverage, not feel: the regen delay expires and regen visibly runs between the t17 roll spend and t24, AND the pool is left mid-regen at t24 (below maximum, above the immediate post-spend value) so the final hashed state encodes spend + regen; assert stamina dipped below maximum after t17 and rose again before the final tick (precedent: `test_recorded_sequence_exercises_all_transitions`)
- [ ] Extend `test_balance_authoring.gd` with the non-duration assertion class + the two header-documented exemptions (AC: 7)
- [ ] Headless tests (AC: 8), including two explicit pins (AC: 4):
  - [ ] Fallthrough pin: a stamina-rejected roll press lets a lower-priority same-tick block press fire on that same tick
  - [ ] Rejected-emit pin: `action_rejected` is emitted for the rejected roll press even when the lower-priority block succeeds that tick

## Dev Notes

- Fixed per-tick regen (per-second value converted once at load) — never `rate × delta`; `advance()` has no `delta`. [Source: docs/game-architecture.md#D2 A1 follow-up]
- Lockout is a **precondition** (transition never fires), not a post-hoc rejection — the gate lives in the one transition-table evaluation from 1-3. [Source: stories-manual-e1.md#E1.S4 item 3]
- **D4 precedent:** `deflect_stamina_cost` is authored data with no consumer until 1-8 — exactly as `stun_seconds` was in 1-1 (data field, no code path). The consuming story is `1-8-block-and-deflect.md:16` (deflect deducts through this story's single path and degrades to plain block at zero).
- **Basic attack is free by GDD design** (`gdd.md:139`, `:319`); stamina throttles evasion and defence, while attack is the mana faucet that 1-5 hooks. Gating attack would lock the poorest player out of their only generator and invert pillar P2. A proposal to charge attack was raised and rejected at this gate.
- **D6 rationale:** `BLOCKING` entry is free (D4), so if regen continued through block, holding block would have zero cost and pillar P2 ("aggression is economy") would be unenforced; block costs **time** instead of stamina.
- **D9 scope limit:** setting current stamina to the authored maximum after `apply_balance()` does NOT address the broader constructor/`apply_balance` double-injection issue (runner placeholder constants feeding `MatchState.new()`, partially overwritten at match start); that remains story 3-1.
- **DEBT D (D1):** the D6 evaluator/rule schema is deferred at this gate — a rule schema shaped by a single continuous per-tick rule would be shaped by the least representative case. See decision-log, Session 2026-07-24/25 — Story 1-4 readiness gate.

### Project Structure Notes

- `src/state/pools/stamina_pool.gd` (regen + delay window + snapshot), `src/state/timing/balance_ticks.gd` (`stamina_regen_per_tick` + comment amendment), `src/state/match_state.gd` (step-3 gate/deduction + step-5 regen), `src/state/hero_state.gd` (`action_rejected`), `test/state/` (headless tests, audit extension, golden re-baseline). No `BalanceConfig` schema change and no `.tres` edit — every field 1-4 needs is already authored. **No `src/state/economy/`** (DEBT D).

### Project Context Rules

- **Feature flags / graceful degradation:** the reserved unblockable cost path is flag-off; state reads injected `FeatureFlags`, never the service. [Source: docs/project-context.md#HARD RULE — Feature flags]
- **Loss legibility** (GDD Success Metrics): the player must be able to say why they lost — hence `action_rejected`. [Source: gdd.md#Success Metrics]

### References

- [Source: stories-manual-e1.md#E1.S4]
- [Source: gdd.md#Primary Mechanics — Hero resources; #Economy and Resources]
- [Source: docs/game-architecture.md#Novel Pattern 1 (Tick + Signal-Queue, D2+D5 — the queued mechanism `action_rejected` and `stamina_changed` ride); #Novel Pattern 2 (Pool + Queued Signal + Config Injection — `StaminaPool`'s pattern)]
- [Source: decision-log.md#CONSTRAINT C (Session 2026-07-22 — Story 1-1 close-out) — read `ms.balance_ticks` inline, never cache the object]
- [Source: decision-log.md#Session 2026-07-24/25 — Story 1-4 readiness gate (DEBT D; BalanceTicks widening; action_rejected seam obligation)]

## Readiness Gate

- 2026-07-24: gds-check-implementation-readiness run against this story (authored 2026-07-22 in the original batch, before 1-3 / 1-3b / 1-3c landed). Verdict **NOT READY** — eight blocking findings: (1) AC4's "existing `EconomyEvaluator`" did not exist anywhere in `src/`; (2) two authoritative homes for the regen amount (`stamina_regen_per_second` vs the rule schema's `amount`); (3) "converted once at load" had no legal home under CONSTRAINT C; (4) block/deflect gating contradicted 1-8 and current code; (5) rejection semantics vs `INPUT_PRIORITY` unpinned; (6) regen conditions implicit; (7) audit-test extension undecided; (8) golden/snapshot re-baseline unstated. All eight were resolved by **operator decision** (Matko, D1–D9, recorded in chat), applied to this document, with the cross-story entries (DEBT D, BalanceTicks widening, `action_rejected` 1-10 seam obligation) recorded in decision-log Session 2026-07-24/25 — Story 1-4 readiness gate. Advisories folded in: non-greenfield inventory (`StaminaPool`/`spend()`/balance fields already exist — this story is wiring plus one schema field (`BalanceTicks.stamina_regen_per_tick`, a load-time derived tick-domain field — not a `BalanceConfig` change, per the second-pass record), not schema work), constructor start-full quirk (D9), `action_rejected` ownership pinned (D5). Status stays backlog — promotion is a separate step.
- 2026-07-25: second pass. The post-edit gate re-run (2026-07-24) surfaced two NEW blocking findings caused by the operator's own D4/D7 wording, which had introduced "attack" into the deduction path and the audit: BLOCKING-1 — an attack stamina cost contradicts the GDD (`gdd.md:139` resource-consumers list; `:319` resource table — basic attack is not a stamina consumer) and would invert P2; BLOCKING-2 — per-swing chain cost unpinned. Resolved by operator decision: BLOCKING-1 → **roll-only**, "attack" withdrawn as a wording error, the GDD affirmed and unchanged (no edits to `gdd.md` or `stories-manual-e1.md`); BLOCKING-2 moot. This document rewritten to roll-only accordingly (story statement, AC3, AC4, AC7, tasks, structure notes); rejection recorded in decision-log Session 2026-07-24/25 — Story 1-4 readiness gate ("Basic attack stays FREE"). First-pass record above kept intact.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
