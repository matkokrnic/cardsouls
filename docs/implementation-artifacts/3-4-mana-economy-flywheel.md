# Story 3.4: Mana economy and the melee→mana flywheel

Status: ready-for-dev

> **Scope note.** The E3 revisit gate has RUN (2026-07-31, decision-log Session 2026-07-31 — E3
> revisit gate (outcome), rulings E3-RG/R1..R12); this story was amended per that outcome in commit
> `10b96a1`. This story then passed its OWN readiness gate (2026-08-02) after the fixes recorded
> in this revision. DP/R3 waived the separate external playtest that the original revisit banner
> demanded.

## Story

As a player,
I want melee hits and a passive tick to fund mana through an authored `.tres` rule set evaluated by
a pure evaluator,
so that the P2 aggression flywheel is observable in play and both `melee_mana_generation` flag
configurations remain playable.

## Acceptance Criteria

1. **Scope.** A pure `EconomyEvaluator` plus a `ResourceGenerationRule` resource (both
   `src/state/economy/` and `src/state/resources/` respectively — verified by content, neither
   exists anywhere in `src/` today) land in this story, authored as exactly two rule instances:
   `melee_hit` (a refactor of the live direct-grant path) and `passive_tick` (new). `CardCastCondition`
   is STRIPPED from this story's scope — it is designed in 3-2 against the working evaluator (ORDER
   ruling). Nothing in 3-4 gates card casts. No new snapshot field lands anywhere in this story.
2. **Replacement proof.** The direct grant inside `MatchState._generate_mana` — which today applies
   `balance.melee_hit_mana` to the attacker on every confirmed hit, gated on the injected
   `FeatureFlags.melee_mana_generation` (shipped since story 1-5; live since 2-4/R13; traced
   end-to-end at BC/R3) — is FULLY REPLACED by evaluator invocation, not left in place behind it. No
   new call site is created for melee-hit generation; the evaluator takes over the rule this hook
   already applies. Proof artifact: with the evaluator swap alone — before the passive rung and
   before any fixture edit — the golden hash
   `96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b` is UNMOVED. This single
   measurement IS the proof and IS step (1) of the Golden Prediction below; it is one measurement,
   named once.
3. **Flag scope.** `FeatureFlags.melee_mana_generation` OFF → only the `passive_tick` rule produces
   mana; ON → both rules do; both configurations run through the evaluator (no second, flag-gated
   code path). The flags resource is injected into state; state never reads `FeatureFlagsService`.
4. **Passive mechanism.** `ManaPool` gains a regen mechanism (`advance_regen`-shaped, mirroring
   `StaminaPool.advance_regen`; `ManaPool.refill()` remains forbidden — the no-refill contract stays
   pinned by `test_mid_match_reload_sets_mana_maximum_but_never_refills`). A derived
   `mana_regen_per_tick` lands on `BalanceTicks`, converted once per load from `mana_regen_per_second`
   (precedent: `stamina_regen_per_tick`). The evaluator's `passive_tick` rung sits at STEP 5 of the
   `advance()` ladder — the resource-generation slot `_generate_mana` already occupies. Sealed
   semantics: NO delay window — passive regen is unconditional while alive; SUPPRESSED for DEAD; NOT
   suppressed for BLOCKING. (The round-over freeze halts it automatically because step 1b returns
   before step 5 is reached — a no-action consequence, recorded as a Dev Note, not an AC.)
5. **Behavior.** Flag ON, N confirmed hits → authored `melee_hit_mana` per hit; flag OFF → passive
   gain only; clamp at `max_mana`; attacker-source filtering (only the attacker's pool gains on a
   confirmed hit). PLUS a value-provable DEAD-suppression test: a hero held DEAD for exactly one tick
   before the round-over freeze gains no passive mana on that tick.
6. **CONSTRAINT C.** The evaluator reads `ms.balance` / `ms.balance_ticks` inline at the point of use
   and never caches a reference (`apply_balance` swaps the whole `BalanceTicks` object). Value-provable
   test: mid-match `apply_balance` with a different `mana_regen_per_second` → the very next tick
   regenerates at the new rate. This also exercises the per-pool reload contract (mana `set_maximum` +
   clamp, no refill).

## Tasks / Subtasks

- [ ] Construct `ResourceGenerationRule` (`src/state/resources/`) and the pure `EconomyEvaluator`
      (`src/state/economy/economy_evaluator.gd`); author `melee_hit` + `passive_tick` `.tres` rule
      instances (AC: 1)
- [ ] Replace the direct grant in `MatchState._generate_mana` with evaluator invocation; measure the
      golden unmoved with the swap alone, before the passive rung lands (AC: 2)
- [ ] Implement `melee_mana_generation` flag scope — both configurations run through the evaluator,
      OFF drops only the `melee_hit` rule (AC: 3)
- [ ] Add `ManaPool` regen mechanism, `mana_regen_per_tick` on `BalanceTicks`, and the step-5 ladder
      seat; DEAD suppressed, BLOCKING not suppressed, no delay window (AC: 4)
- [ ] Flag-matrix + clamp + source-filtering + DEAD-suppression headless tests (AC: 5)
- [ ] CONSTRAINT C reload-rate test — mid-match `apply_balance` changes the very next tick's mana
      regen rate (AC: 6)

## Dev Notes

- The test of whether this story was done right: the Mana Accelerator totem (E4) is a **new `.tres`, no code change**. That is D6's economy-wide, data-defined scope. [Source: stories-manual-e3.md#E3.S4 item 1; docs/game-architecture.md#D6; #Novel Pattern 5]
- **`ResourceGenerationRule`/`EconomyEvaluator` do not exist in `src/` today**, even though `docs/game-architecture.md` describes them as already landed in several places with no "Planned (E3)" qualifier: the Directory Tree lists `economy/economy_evaluator.gd` and `resources/resource_generation_rule.gd`/`card_cast_condition.gd` as though present (`game-architecture.md:548,553`), unlike the `MatchState` config object, which IS explicitly marked "Planned (E3)" (`game-architecture.md:613`); the D6 capability table marks the feature "E0/E3 · Full" (`:107,190`); the Testable-without-engine-runtime table lists "the D6 evaluators" as already testable (`:511`); Novel Pattern 5 (`:788-806`) is written as existing code. Read the architecture doc's evaluator sections as a SPEC to build against, not a description of shipped code. [Source: decision-log.md E3-RG/R8]
- **The melee-hit hook does not need wiring — it is already live and shipped.** `MatchState._generate_mana` grants `balance.melee_hit_mana` flat to the attacker for every confirmed hit (full damage AND block-mitigated damage both confirm; only a deflect, an iframe drop, or a DEAD-slot drop withhold it), gated on the injected `FeatureFlags.melee_mana_generation`. This story's job on that path is the REFACTOR (rule-driven via the evaluator, proof obligation in AC2) plus the NEW passive-tick income — not standing up a call site that already exists. The superseded citation to `stories-manual-e1.md#E1.S5`'s evaluator framing (that manual's item 3) is replaced: that framing was declared superseded at the 1-5 gate itself ("the 1-5 story text is cleaned of every evaluator reference... superseded by this entry; the manual is not edited"). [Source: decision-log.md:224; decision-log.md E3-RG/R8; match_runner.gd; 2-4/R13 (decision-log:727); BC/R3 (decision-log:1017)]
- Fixed per-tick passive amount, never `rate × delta`. [Source: docs/game-architecture.md#D2 A1 follow-up]
- **What `ManaPool` lacks that `StaminaPool` has.** `StaminaPool` regens via a `BalanceTicks`-derived per-tick rate (`stamina_regen_per_tick`, derived once at load from `stamina_regen_per_second`) ticked every `advance()` in step 2 (`StaminaPool.tick_timers()`) and consumed in step 5 via `advance_regen(amount_per_tick, suppressed)`. `ManaPool` (`src/state/pools/mana_pool.gd`) has only `add`/`spend`/`set_maximum` — no regen method, no `BalanceTicks` field, and no seat anywhere in the tick ladder. The `passive_tick` rule needs its own derived per-tick value (`mana_regen_per_tick` on `BalanceTicks`, mirroring the stamina precedent) at the step-5 seat (AC4). [Source: decision-log.md E3-RG/R8; src/state/timing/balance_ticks.gd; src/state/pools/mana_pool.gd]
- **Rationale for AC1/AC2's scope framing (moved out of the ACs at this gate).** The evaluator's non-existence and the architecture doc's already-landed framing (Directory Tree, D6 capability table, Testable-without-engine-runtime table, Novel Pattern 5 — citations above) are findings that FORCE constructing the evaluator and its rule resource to be first-class acceptance criteria rather than a background assumption the story could lean on as already done. `CardCastCondition` is excluded from those citations deliberately — it ships nowhere in this story (AC1); 3-2 designs it against the working evaluator this story delivers.
- **Sealed decision: no delay window on passive regen, with reasoning.** Unlike stamina's `_regen_delay` window, passive mana regen has no analogous delay — it is dead machinery until the first mana spender lands (3-2/3-5), so it arrives just-in-time then rather than being speculatively built now.
- **Sealed decision: DEAD suppressed, BLOCKING not suppressed, with reasoning.** DEAD follows the standing "a corpse runs no economy" doctrine already applied to stamina (2-3/R5, `_regen_stamina`'s `suppressed := state == BLOCKING or state == DEAD`). Mana's suppression set is narrower: BLOCKING is deliberately NOT suppressed, because mana buildup behind a block is the flywheel's point (a player turtling still charges mana while their opponent's swings pay for it), and block already pays its own cost through stamina suppression — mana does not need to double-charge it.
- **Step-5 seat is the documented ladder meaning.** `advance()`'s own step-5 comment already reads "Resource generation — stamina regen (story 1-4) then melee-hit mana (story 1-5)" (`match_state.gd`); the `passive_tick` rung joins that same step, in the same slot `_generate_mana` occupies today.
- **Round-over freeze, no action needed.** Step 1b (`if _round_over: ... return`) returns before step 2 is ever reached on a frozen tick, so step 5's resource generation — passive mana included — is skipped automatically once the round ends. No guard is added for this in step 5 itself.
- **Shipped HUD context (moved out of the old AC4, which this AC replaces).** The `mana_changed` seam is already live: `MatchState.connect_mana_changed` (`match_runner.gd:291`, called from `_wire_hud`/`_wire_debug` at `match_runner.gd:125,140`) primes on connect and feeds both `HudRoot.on_mana_changed` (2-4) and `StateInspector.on_mana_changed`. This story adds no new HUD wiring — the bar the E2 HUD already renders will simply move once the passive rung produces nonzero values.
- **Architecture amendment queue gains a FIFTH member.** Standing queue (unflushed since E2-CO/R1, `f80f90e`): (1) the `assets/` Directory Tree gap — the tree lists `assets/` as a single unexpanded line, no itemized children (3-0a/R10); (2) import post-processing as a repo pattern — `strip_model_anim.gd`, an `EditorScenePostImport` `@tool` script, first use of that import hook (3-0a/R10); (3) a new artifact type under `assets/` — an import-time `.gd` script beside its source asset plus a committed `AnimationLibrary` `.res` (3-0a/R10); (4) a non-`Controller` class under `src/controllers/` — `debug_input_reader.gd` (3-0b/R17 Pass 1). This gate adds a FIFTH: `docs/game-architecture.md`'s E0/E3 evaluator attribution (Directory Tree, D6 capability table, Testable-without-engine-runtime table) and Novel Pattern 5 both need reconciling against the evaluator this story actually constructs, once it ships. Flush point unchanged: the next architecture amendment queue flush (pattern: E2-CO/R1), not this story.

### Project Structure Notes

- `ResourceGenerationRule` schema under `src/state/resources/`; `.tres` rule instances under `data/` (rules/balance); evaluator `src/state/economy/economy_evaluator.gd`; `ManaPool` in `src/state/pools/`.

### Project Context Rules

- **Feature flags / graceful degradation; state reads injected `FeatureFlags`, never the service.** [Source: docs/project-context.md#HARD RULE — Feature flags]
- **Flag matrix testing:** both ON and OFF paths asserted. [Source: docs/project-context.md#Testing Rules]

### References

- [Source: stories-manual-e3.md#E3.S4]
- [Source: gdd.md#B Mana Economy; #P2]
- [Source: docs/game-architecture.md#D6; #Novel Pattern 5]

## Golden Prediction

**MOVES, exactly ONE named cause.** Baseline is concrete:
`96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b`, unmoved through 3-1. The cause is
NOT a `BalanceTicks` seat — `BalanceTicks` is load-time config, never snapshotted, so it is
structurally incapable of moving the hash on its own. The single named cause is: `_golden_config()`
must author a NONZERO `mana_regen_per_second` coverage value (precedent: `attack_stamina_cost` 6.0,
`roll_distance` 3.0 fixture coverage — the dev pass picks and names the value), which activates the
passive rung in the hashed determinism run. Without that fixture edit the passive tick is
hash-neutral: the authored `.tres` value (`0.25`, per 3-1/R1) CANNOT reach the golden on its own —
`_golden_config()` builds its fixture in-test and never loads `data/balance/balance_config.tres`
(proven at BC/R3, re-confirmed by SC/R6 and the 3-0b gate) — so the fixture defaults the field to
`0.0` and the passive rung stays a no-op in the recorded sequence until the fixture is deliberately
edited.

Measurement order: (1) evaluator swap alone (AC2's proof artifact) = UNMOVED — confirms the refactor
is a true no-op on the melee case; (2) the passive rung lands PLUS the `_golden_config()` fixture
coverage edit = MOVES — one re-baseline, the fixture edit is the named cause.

## Live Smoke

**REQUIRED, full two-human, on the shipped default configuration, flag ON only.** R-D6 live-smoke
acceptance ATTACHES to this story and is SPENT here — this is the first player-facing story since
3-1, which shipped no player-facing code path and left R-D6 available (last spent 3-0a/R15). The
smoke carries one named question for the playtest-log: "flywheel or bookkeeping" — the operator
(Matko) writes the playtest-log entry; the dev pass NEVER writes `docs/playtest-log.md`. The flag-OFF
leg is headless-only (AC3/AC5) — no `feature_flags.tres` edit for any live run.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

### Completion Notes List

### File List
