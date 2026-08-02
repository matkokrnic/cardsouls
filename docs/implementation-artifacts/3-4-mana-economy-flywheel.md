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

## Dev Pass Record

Dev pass model: **Claude Opus 4.8**. This section records that pass's substance; the commit chain
that lands it (evaluator/tests/data commit, this doc commit, the board-promotion commit, and the
decision-log close-out) is a separate session, **Claude Sonnet 5** — see Agent Model Used below.

- **Suite outcome.** State harness 192 tests / 917 assertions / 0 failed -> **208 tests / 977
  assertions / 0 failed**; all 14 integration tests PASS individually; zero `SCRIPT ERROR` lines
  across the harness output.
- **Golden — three measurements, in order (matches the Golden Prediction section exactly):**
  1. **Evaluator swap alone** (AC2's proof artifact) — the direct `balance.melee_hit_mana` grant
     replaced by the `EconomyEvaluator` call over the authored `melee_hit` rule, both authored
     `.tres` already present. Measured **UNMOVED**: `96ac5f64...`. Proves the refactor is a true
     no-op on the melee case.
  2. **Passive rung landed, fixture untouched** (`BalanceTicks.mana_regen_per_tick` +
     `ManaPool.advance_regen` + the step-5 seat, `_golden_config`'s `mana_regen_per_second` still
     its default `0.0`) — measured **UNMOVED**, still `96ac5f64...`. Isolates the SEAT from the
     COVERAGE VALUE: a `BalanceTicks` field is load-time config, never snapshotted, so it cannot
     move the hash by existing.
  3. **Fixture coverage value edited** — `_golden_config` authors `mana_regen_per_second 75.0`
     (1.25/tick). Measured **MOVED**: `96ac5f64...` -> `98d0c7eb...`. This is the ONE named cause;
     re-baselined once.
  - **Coverage-value rationale (selector-bug guard).** 75.0/s was chosen deliberately DISTINCT from
    this fixture's stamina rate (60.0/s = 1.0/tick): if the evaluator's field lookup ever picked up
    `stamina_regen_per_tick` instead of `mana_regen_per_tick` for the passive rule, the two rates
    coinciding would let that selector bug hide inside an unchanged hash. 75.0/s (1.25/tick) also
    stays clear of the 90.0 mana cap over the 24-tick record (30.0 accrued + one 12.0 hit = 42.0 at
    t24, left UNCLAMPED so the hash encodes the accumulation) and is exactly representable in
    binary, so every expected value in the golden-sequence tests is an exact equality, no tolerance.
- **Mutation table.** Each row: mutate in place, run the suite, restore from an out-of-repo backup
  copy (SHA256-compared before mutating and after restoring; `git checkout --` never used).
  | # | Mutation | Result |
  |---|---|---|
  | M1 | DEAD suppression removed from `_regen_mana` | 1 failure — `test_dead_hero_gains_no_passive_mana_on_its_one_dead_tick` |
  | M2 | `EconomyEvaluator` caches `BalanceTicks` in a static var | 10 failures incl. `test_mid_match_reload_changes_the_very_next_tick_regen_rate` — the process-wide static poisoned 9 OTHER tests |
  | M2b | Same defect scoped per-`MatchState` (narrower rerun) | 1 failure, crisp — `test_mid_match_reload_changes_the_very_next_tick_regen_rate` |
  | M3 | BLOCKING suppressed too (mana mirrors stamina) | 1 failure — `test_blocking_hero_still_gains_passive_mana_while_stamina_is_suppressed` |
  | M4 | Melee grant leaks to the target as well | 6 failures — 2 mana-economy, 1 contact-resolution, 3 determinism (incl. the golden) |
  | M5 | `passive_tick.tres` renamed to name `stamina_regen_per_tick` | 29 failures across 6 files — the `.tres` CONTENT is load-bearing everywhere, including the golden |
  | M6 | `_flag_open` always returns true | 5 failures — 3 mana-economy, 2 contact-resolution |
- **Provability honesty.** Three crash-guards are NOT claimed mutation-proven: the `home == null`
  guard in `EconomyEvaluator._amount` (a pre-injection `MatchState`), the type check on the
  dereferenced value in that same method (`value is float or value is int`), and the `dir == null`
  guard in `load_rules` (a missing directory). No test deletes any of these three and asserts a
  crash in their absence — the same class of admission 3-1 made for its own crash-guards (3-1/R6).
  Admitted partial: no dedicated preload-list mutation was run (there is no preload list — sourcing
  is a live directory scan) — the directory-scan claim is accepted on M5 above plus the
  different-directory assertions in `test_rule_set_is_a_directory_scan_not_a_hardcoded_list`.
- **KAKO decisions (what/how, recorded for the record):**
  - **Rule sourcing.** A directory scan of `data/economy/`, sorted before loading — the first
    `load()` call to appear anywhere in `src/state/`. Forced by two constraints together: AC2
    requires the evaluator swap to be a behaviour-preserving no-op (an injection seam would force
    every existing fixture to inject rules before mana generation worked at all), and the autoload
    fence rules out a new service (a new autoload is a `project.godot` edit this story does not
    make).
  - **Rules name a field, never carry an amount.** A rule is structure (which field, which faucet),
    not a gameplay number.
  - **Evaluator computes, pools apply.** `amount_for()` returns a float and touches no pool — a
    deliberate departure from the architecture doc's Novel Pattern 5 sketch (which has the
    evaluator call `player.mana.add()` itself), so the mutation stays inside
    `MatchState.advance()`'s ordered dispatch (D2) where every other mutation already lives. Filed
    as the architecture amendment queue's fifth member.
- **Review outcome: PASS**, four items:
  - **D1 — rule sourcing ACCEPTED**, with three named consequences: it NARROWS BC/R3 — the standing
    "authored data cannot move the determinism golden" property now applies to balance/tuning data
    ONLY (`data/balance/*.tres`, never read by the hashed run); `data/economy/*.tres` is a DIFFERENT
    class — the rule set IS loaded and read by the production code path the golden run exercises, so
    rule content is load-bearing for the hash exactly like code (proven by M5's 29 failures above);
    it is no-reload-by-design (rules load once, like FeatureFlags — a rule edit needs a restart, not
    a hot-reload path, since none of AC1-AC6 asked for one, and this is deliberately NOT a DEBT B
    member — hot-reloadable rules would be their own story with both DEBT B halves); and it carries
    the export-packing remap risk as a named flag with no owner (`DirAccess` scan + `ends_with(
    ".tres")` is fragile under export remap — zero impact today, activates on the first
    export/packaging story).
  - **D2 — two golden pins rewritten as `12.0 + N * PASSIVE_PER_TICK`** within the same named cause:
    the pre-existing flat `12.0` mana assertions in `test_golden_sequence_exercises_block_and_deflect`
    (t13, t24) and `test_golden_sequence_exercises_iframe_negation` (t20, t24) now read as the melee
    amount plus the accumulated passive ticks — both changes trace to measurement 3 above, no second
    cause.
  - **D3 — folded into the architecture amendment queue's fifth member**, now expanded to include:
    rules-name-a-field vs Novel Pattern 5's amount-float sketch, compute-vs-apply, the loader, and
    the new `data/economy/` directory absent from the Directory Tree.
  - **D4 — partial accepted**: the provability-honesty admission above (three crash-guards not
    mutation-proven, no dedicated preload-list mutation) was reviewed and accepted as sufficient
    rather than extended.

**Smoke Record.** Two live runs, shipped default configuration, flag ON, zero manual edits between
runs.
- **Run 1** confirmed: passive creep visible on both mana bars; an attacker-only jump on a
  confirmed hit; BLOCKING keeps filling (the sealed non-suppression, AC4).
- **Run 2** confirmed: a kill, round-over, and stable fps throughout.
- **S1 (parked, PROVISIONAL TUNING).** Operator observation: the passive rate may read too fast.
  Parked to the 3-2 forcing point per the E3 criterion — a round should finance 2-4 loop cycles, and
  that's unjudgeable before cards have costs to spend mana against. A retune later is a
  golden-neutral `chore(balance)`: the golden's own fixture authors its own coverage value,
  independent of the shipped `.tres`.
- **S2 (parked, PROVISIONAL TUNING).** Operator observation: `melee_hit_mana` at ~10% of the mana
  bar per hit may be too high; operator suggests 5% or less. Same forcing point and same
  golden-neutral retune path as S1.
- **S3 (parked, named open finding).** Operator question: should a blocked hit pay reduced mana
  (e.g. 2% vs the current 5%) rather than the same amount as an unblocked hit? Today's behavior —
  a blocked hit pays FULL mana, identical to an unblocked one — is the LOCKED 1-8 decision (block
  does not touch the attacker's economy at all, deliberate for E1). A reduction would be a NEW
  mechanism (a new balance field, and a golden mover), not a tuning change, so it is recorded as an
  open finding rather than folded into S1/S2. Forcing point: 3-2 / the tuning pass.
- **S4 (parked, named open design question, no owner).** Live observation: a respawn appears to
  carry full mana. Verified against the code, not assumed: `_reset_player`
  (`match_state.gd:777-781`) only heals hp to max and clears a `DEAD` action state back to `IDLE` —
  it never touches the mana (or stamina) pool at all. So "full mana at respawn" is leftover mana
  the hero had already accumulated before dying, surviving the reset untouched, not the reset
  granting anything (the `attack_index` precedent — reset is deliberately narrow). Forcing point:
  the first real round-flow story, or the tuning pass, whichever comes first.
- **DEAD-freeze live observation — WAIVED.** The DEAD-suppression behavior is headless-proven
  (`test_dead_hero_gains_no_passive_mana_on_its_one_dead_tick` plus mutation M1) and visually
  indistinguishable in live play at the moment it would matter, since the mana clamp absorbs both
  the suppressed and unsuppressed cases identically at cap. No live-observation follow-up needed.
- **R-D6 re-invoked and SPENT** on this story (see Live Smoke section above).
- The playtest-log entries for these runs are the OPERATOR's own words — not reproduced or edited
  here.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

### Completion Notes List

- Dev pass (2026-08-02, Claude Opus 4.8): implemented AC1-AC6 — see Dev Pass Record above for
  the three golden measurements, the mutation table, the KAKO decisions, and the review outcome.
- Live smoke (2026-08-02, two runs, operator Matko): see Smoke Record above for findings
  S1-S4 and the DEAD-freeze waiver.

### File List

- data/economy/melee_hit.tres (new)
- data/economy/passive_tick.tres (new)
- src/state/economy/economy_evaluator.gd (new)
- src/state/economy/economy_evaluator.gd.uid (new)
- src/state/resources/resource_generation_rule.gd (new)
- src/state/resources/resource_generation_rule.gd.uid (new)
- src/state/match_state.gd
- src/state/pools/mana_pool.gd
- src/state/timing/balance_ticks.gd
- test/state/test_balance_config.gd
- test/state/test_determinism.gd
- test/state/test_mana_economy.gd (new)
- test/state/test_mana_economy.gd.uid (new)
