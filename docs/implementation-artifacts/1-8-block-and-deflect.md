# Story 1.8: Block and Deflect

Status: ready-for-dev

## Story

As a player,
I want to hold block to reduce incoming damage while facing the attacker and time my block press into a deflect window to negate a hit entirely at a stamina cost,
so that the defensive layer is legible, the most feel-sensitive number is hot-reloadable, and the exact window boundary is asserted on ticks.

## Acceptance Criteria

1. **Facing-gated block mitigation.** `BLOCKING` entry on press and exit on release exist since 1-3 and are unchanged. NEW: a contact resolving in step 4 against a `BLOCKING` target that is FACING the attacker takes `damage x block_damage_multiplier`. The facing test runs in STATE: the fact's world-space target-to-attacker direction is compared against the target's own `HeroState.facing` (world-space since the 1-7 R1 contract) within +/- `block_facing_arc_degrees / 2`. A target NOT facing the attacker takes full damage regardless of the deflect window (R-D3 — no parry or block from behind). All balance values are read inline at the point of use (CONSTRAINT C).
2. **Deflect = window + grace + facing, spend at landing.** A contact resolving inside the deflect window — judged at resolution time WITH a +1 grace tick (the dedupe-grace precedent, R-N2), so a contact physically inside the window's last tick that arrives one tick late per F1 still deflects and authored `deflect_window_seconds` means what it says — AND within the facing arc is a **deflect**: no damage, `deflect_stamina_cost` spent AT LANDING via `StaminaPool.spend()` with its regen delay stated explicitly, and `deflect_landed` queued. `deflect_landed(attacker_slot, target_slot)` is MatchState-owned (the `hit_landed` precedent: a deflect has an attacker AND a target), queued via D5, with NO runner seam in 1-8 — the first consumer is 1-10, which inherits the connect-seam obligation (the `action_rejected` precedent). The same contact after the grace-extended window is an ordinary block (AC 1).
3. **Entry precondition and degrade path.** At the BLOCKING transition, if `stamina < deflect_stamina_cost` the deflect window never opens (`enter_block` gains a no-window path), `action_rejected(&"deflect", &"insufficient_stamina")` is queued, and block proceeds as a plain block. BLOCKING entry itself stays FREE — the locked 1-4 ruling is upheld; block's cost remains regen suppression. This is a DEGRADE, not the 1-4 fallthrough: the block edge still fires, only the window is denied, and the rejection names `&"deflect"` because that is the thing denied. "One stamina deduction path" is reconciled per R-D1: `StaminaPool.spend()` is the single deduction MECHANISM; policy seats are per-consumer (roll in step 3, deflect in step 4). Affordability at entry guarantees the landing spend: stamina cannot change while BLOCKING (regen suppressed, no reachable spends).
4. **Outcome semantics (R-D4).** Blocked AND deflected contacts BOTH register the swing-hit — one resolution per swing per target regardless of outcome; a blocked or deflected swing's later facts cannot re-resolve. A **blocked** hit is a CONFIRMED hit: reduced damage applied, `hit_landed` fires with the reduced amount, and the attacker earns full flat `melee_hit_mana` (block deliberately does NOT touch the attacker's economy in E1 — recorded in the decision log; the defender's economic counter is deflect only). A **deflected** contact is FULLY negated: no damage, no `hit_landed`, no mana — `deflect_landed` is the only signal.
5. **Four-field contact fact (R-B3 pin).** The fact widens to `[attacker_slot, target_slot, attack_index, world-space direction from target to attacker]`, computed by the runner FROM POSITIONS ONLY. The runner must NOT read `HeroState.facing` and must NOT compute a "relative angle" — that would leak policy into the runner; the arc comparison happens in state, step 4. `push_contact` remains the SOLE intake; the new field is validated at the seam like the others; the fact stays plain recordable data so X5 recordability is preserved and the IntentRecorder story inherits four-field facts (D-4's "three-int" wording is superseded — noted in the decision log now, full supersession at close-out).
6. **Balance schema and audits (R-D2 / R-N6).** ONE new `BalanceConfig` field: `block_facing_arc_degrees` (Defense group), first authored value `180.0` (front half-plane), hot-tunable. Audit deltas: lift the `deflect_stamina_cost` exemption and assert `> 0` (roll precedent — a free deflect unguards the economy); add `block_damage_multiplier` with bounds `0 < m < 1` (0.0 = free total negation that obsoletes deflect; >= 1.0 = no-op or self-harm); add `block_facing_arc_degrees` with bounds `> 0` and `<= 360`. `deflect_window_seconds` is already audited.
7. **Hot-reload meaning (R-B5 pin).** "Tunable by hot-reload" means exactly: a mid-match `apply_balance()` call swaps `balance_ticks` and the NEXT `enter_block` picks up the new window length; in-flight windows keep their duration (CONSTRAINT C / the 1-1 reload principle). Proven HEADLESS via `apply_balance` (the 1-4 `test_mid_match_reload_refills_stamina_to_max` precedent). NO live reload trigger, NO `CACHE_MODE_IGNORE`, NO recording changes — DEBT B stays re-homed to the IntentRecorder story.
8. **Untouched guards.** The STUNNED inbound-edge guard stays green (zero inbound edges); the `stun` window is never started and `stun_seconds` stays data-only; `roll_iframe` x contact stays untouched (1-9's half of the fence); the attacker's consequence on a deflect stays OUT of scope — open decision (a) (decision-log Session 2026-07-22) is REFERENCED, not duplicated and not resolved (R-D5).
9. **Headless tests.** The exact window boundary on named ticks, both sides, under grace semantics (a contact resolving on the last inside tick AND on the grace tick deflects; the first tick past the grace blocks); the block multiplier arithmetic; back-facing block takes full damage; back-facing INSIDE the window takes full damage (no parry from behind, R-D3); zero-stamina entry degrades to plain block and emits the rejection; a repeated same-swing fact cannot re-resolve after a block or a deflect; mana and `hit_landed` semantics for both outcomes per AC 4. Optional if cheap (R-N7): a second swing's contact inside the same window with insufficient remaining stamina degrades to a block gracefully.

## Tasks / Subtasks

- [ ] Balance schema: add `block_facing_arc_degrees` to the Defense group; author `180.0` in `balance_config.tres` (AC: 6)
- [ ] Audit deltas in `test_balance_authoring.gd`: lift the `deflect_stamina_cost` exemption (`> 0`); `block_damage_multiplier` `0 < m < 1`; `block_facing_arc_degrees` `> 0`, `<= 360` (AC: 6)
- [ ] Entry gate: no-window path in the BLOCKING transition + `action_rejected(&"deflect", &"insufficient_stamina")`; BLOCKING entry stays free (AC: 3)
- [ ] Runner: widen the gathered fact to four fields — world-space target-to-attacker direction FROM POSITIONS ONLY; validate the new field at the `push_contact` seam (AC: 5)
- [ ] Step-4 resolution: facing gate (state-side arc comparison), block multiplier, deflect with the +1 grace tick, spend at landing, `deflect_landed` (MatchState-owned, no runner seam), swing-hit registration for both outcomes, mana/`hit_landed` semantics (AC: 1, 2, 4)
  - [ ] Amend the stale `match_state.gd` step-3 comment "Deflect joins this path in 1-8" to the R-D1 mechanism/policy-seat wording (AC: 3)
- [ ] Headless tests per AC 9 (AC: 9)
- [ ] Golden: measure BEFORE first edit and after; restructure the sequence DELIBERATELY (author real defense values in `_golden_config`, add an exercises-block-and-deflect pin test); at most ONE re-baseline with separately named causes; exact boundary ticks live in dedicated non-golden tests (see Golden prediction below)
- [ ] Live smoke check: TEMPORARY flip of runner slot 1 to `KEYBOARD_P2` (exported array); the shipped default stays P2=NULL; the NAMED GAP "DEAD-slot residuals" is ACCEPTED for this supervised smoke check per R-D6 — record the acceptance in the Completion Notes (AC: 1, 2)
- [ ] Close-out decision-log entry: D-4 four-field supersession (full), outcomes record, obligation status

## Dev Notes

- **R-D1 mechanics.** Affordability PRECONDITION at block entry (check only — no spend, no regen-delay restart at entry); SPEND at deflect landing in step 4. Stamina is constant while BLOCKING (regen suppressed by the D6 policy, no spend paths reachable from the empty blocking row), so the entry check guarantees the landing spend succeeds — no failed-spend hole. If a second swing's contact lands in the same window after the pool dropped below cost (multi-deflect edge), the spend fails and that contact degrades to a block gracefully (R-N7).
- **R-N2 grace.** The deflect window is judged at resolution time WITH a +1 grace tick, mirroring the dedupe grace that absorbs the same F1 one-tick fact lag. Without it the effective live window would be one tick shorter than authored on the most feel-sensitive number in E1.
- **The deflect TimingWindow already exists** (1-3): `hero_state.gd` owns the `deflect` window, `enter_block` opens it, `match_state.gd` passes `balance_ticks.deflect_window_ticks` inline. 1-8's real delta is: the stamina gate on opening, the step-4 consumer with grace-tick resolution, the facing gate, the outcome semantics, and the tests (R-N1 — do not rebuild what exists).
- **OPEN decision (a) stays OPEN (R-D5).** What happens to the attacker on a deflect — stun, stagger, stamina penalty, or nothing — is undecided; the decision-log OPEN entry (Session 2026-07-22) is the record and satisfies this story's log-the-question obligation. No E1 code path may wire an attacker consequence; the STUNNED guard test enumerates this. In E1 a deflect delivers: full negation, denial of the attacker's `melee_hit_mana`, and the `deflect_landed` cue hook (consumed at 1-10).
- **Runner reports facts, state decides (R-B3).** The runner computes the fourth fact field from actor positions only. Reading `HeroState.facing` or computing a relative angle in the runner would move the facing policy out of state — forbidden.
- **Smoke check (R-D6).** Blocking cannot be felt against the NullController dummy (it never swings). Flip slot 1 to `KEYBOARD_P2` for the supervised check only; deaths are avoidable (100 HP / 6% chip) and the D-1 debug reset revives on demand. The DEAD-slot residuals (a dead hero can walk; a corpse mid-swing can be credited damage/mana) are consciously accepted for E1 smoke checks (1-8 AND 1-9); the gap's fix trigger is story 2-3, the first story that SHIPS a human-driven-killable configuration.

### Golden prediction (R-N3)

Predicted to MOVE; at most ONE re-baseline with separately named causes; measured in BOTH directions (hash recorded before the first edit and after); all non-golden tests proven green first.

- **Primary cause — exercised-path resolution change.** The recorded sequence already straddles the new mechanics: P2 blocks t1 and holds through t5; the one synthetic fact resolves at t5. Corrected boundary arithmetic under the grace ruling (gate Step-0.3): the deflect window (4 ticks) RUNS on t1-t4 and closes in t5's step 2; the t5 fact models a t4 physics contact arriving with the F1 one-tick lag — physically inside the window's last running tick — so under the +1 grace tick it falls INSIDE and, fed a front-facing direction, resolves as a DEFLECT (P2 HP stays 120, no `hit_landed`, P1 mana stays 0, P2 spends the deflect cost). The gate report's original "one tick outside / ordinary block" reading is superseded by the grace ruling.
- The dev pass must NOT inherit this boundary by luck: restructure the sequence deliberately, author real defense values in `_golden_config` (`block_damage_multiplier`, `deflect_stamina_cost`, `block_facing_arc_degrees`), and add an exercises-block-and-deflect pin test (the 1-4/1-5 guard pattern). Exact boundary ticks belong in dedicated non-golden tests.
- **Snapshot shape: predicted NONE.** Prefer DERIVED deflect-consumed state (dedupe registration + window state) — no new snapshot field. If a stored field proves necessary, it is a separately named re-baseline cause.

### Project Structure Notes

- `src/state/match_state.gd` (entry gate in the BLOCKING transition; step-4 facing gate, mitigation, deflect resolution, spend at landing, `deflect_landed`), `src/state/hero_state.gd` (`enter_block` no-window path; swing-hit registration serves both outcomes), `src/state/resources/balance_config.gd` + `data/balance/balance_config.tres` (`block_facing_arc_degrees`), `src/main/match_runner.gd` (four-field fact from positions), `test/state/` (boundary, facing, degrade, outcome, audit tests). The deflect window is `src/state/timing/timing_window.gd` machinery already in place.
- NO architecture-doc edits (R-D7): the amendment queue (world-space facing contract + `null_controller.gd` Directory Tree) stands untriggered; the four-field fact contract's canonical home is the decision log.

### Project Context Rules

- **CONSTRAINT C:** every balance read (`block_damage_multiplier`, `deflect_stamina_cost`, `block_facing_arc_degrees`, `deflect_window_ticks`) is inline at the moment of use; never cache the `BalanceTicks` object.
- **Graceful degradation:** insufficient stamina degrades (plain block + queued rejection), never errors. [Source: docs/game-architecture.md#Error Handling]
- **D5 queued signals:** `deflect_landed` and `action_rejected` enqueue during `advance()`; the runner drains after.
- **State purity (D3(b)/A2):** the facing comparison lives in state; positions stay actor-owned (F1) — the runner reports the direction fact.
- **Docs and code never share a commit.**
- Deflect/parry gets a crisp signature cue on the `CombatCues` bus (1-10). [Source: gdd.md#Audio and Music]

### References

- [Source: stories-manual-e1.md#E1.S8]
- [Source: gdd.md#Primary Mechanics — Block/Deflect; #F]
- [Source: decision-log.md#OPEN — Attacker consequence on basic-attack deflect (Session 2026-07-22)]
- [Source: decision-log.md#Session 2026-07-26 — Story 1-8 readiness gate (operator decisions)]

## Readiness Gate (2026-07-26)

Report-only gate returned **NOT READY** — five blocking findings: B1 (AC contradiction on deflect deduction timing; one reading priced block entry against the locked 1-4 ruling), B2 (facing gate had no rule and no data home), B3 (contact-fact schema widening unstated against the three-int `push_contact` contract), B4 (dedupe/mana/`hit_landed` semantics for blocked and deflected outcomes unspecified), B5 (hot-reload wording risked pulling DEBT B into scope). All resolved by operator decision (Matko): rulings R-D1 (precondition at entry / spend at landing / one-mechanism reconciliation), R-D2 (`block_facing_arc_degrees`, authored 180.0), R-D3 (arc gates both outcomes), R-D4 (outcome semantics; block does not touch attacker economy in E1), R-D5 (decision (a) stays OPEN), R-D6 (temporary KEYBOARD_P2 smoke flip; NAMED GAP accepted for 1-8/1-9 smoke checks; trigger reinterpreted to 2-3), R-D7 (arch amendment queue untriggered), R-N2 (+1 grace tick), plus the R-B3 and R-B5 pins — applied to this story the same day; promoted backlog -> ready-for-dev. Full record: decision-log.md, Session 2026-07-26 — Story 1-8 readiness gate.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-07-22: Story authored (Set B batch, before any E1 code existed).
- 2026-07-26: Readiness gate NOT READY (B1-B5); operator rulings R-D1..R-D7 + R-N2 + R-B3/R-B5 pins applied; story rewritten; Status backlog -> ready-for-dev.
