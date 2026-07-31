# Story 3.4: Mana economy and the melee→mana flywheel

Status: backlog

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. Whether melee-funded mana feels like a flywheel or like bookkeeping is precisely what the first playtest tells you.

## Story

As a player,
I want melee hits to fund mana through an authored `.tres` rule with no new call site, and the `melee_mana_generation` flag to degrade gracefully,
so that the P2 aggression flywheel is observable in play and both flag paths remain playable.

## Acceptance Criteria

1. `ResourceGenerationRule` and `CardCastCondition` (`src/state/resources/`) and the pure `EconomyEvaluator` (`src/state/economy/economy_evaluator.gd`) are CONSTRUCTED by this story — verified by content, none of the three exists anywhere in `src/` today; this is first-class scope, not a background assumption the story can lean on as already done. Mana sources are authored as `ResourceGenerationRule` `.tres`: `passive_tick` (a fixed per-tick amount converted once at load, never `rate × delta`) and `melee_hit` (a burst on a confirmed contact). The Mana Accelerator totem (E4) must be addable later as a third `.tres` with no code change.
2. The evaluator FULLY REPLACES the existing direct melee-hit-mana path, not sits behind it — proof obligation: the mana amounts for the melee case are shown unchanged, before and after (a provable refactor, not a rewrite). This is a REFACTOR of an already-live path plus NEW passive-tick income, not new wiring: verified by content, `MatchState._generate_mana` already grants `balance.melee_hit_mana` on every confirmed hit, gated on the injected `FeatureFlags.melee_mana_generation` (shipped since story 1-5; confirmed live at 2-4/R13 and traced end-to-end at BC/R3). No new call site is created for melee-hit generation — the evaluator takes over the rule this hook already applies.
3. `FeatureFlag: melee_mana_generation` is graceful degradation: off → the passive rule alone applies and the game stays playable, with no error and no special-case path. The flags resource is injected into state; state never reads `FeatureFlagsService`.
4. `ManaPool` regen and bounds complete through the injected config, with a queued `mana_changed` signal connected to the mana bar the E2 HUD already renders.
5. Headless tests cover the flag matrix: with the flag on, N landed hits produce the authored mana; with it off, only passive accrues; the pool clamps at max; the evaluator applies exactly the rules matching a source and ignores the rest.

## Tasks / Subtasks

- [ ] Author `passive_tick` + `melee_hit` `ResourceGenerationRule` `.tres` (AC: 1)
- [ ] Attach the `melee_hit` rule to the existing 1.5 hook — no new call site/branch (AC: 2)
- [ ] Implement `melee_mana_generation` flag graceful degradation (off → passive only) (AC: 3)
- [ ] Complete `ManaPool` regen/bounds + queued `mana_changed`; connect to the E2 mana bar (AC: 4)
- [ ] Flag-matrix headless tests (on/off, clamp, source filtering) (AC: 5)

## Dev Notes

- The test of whether this story was done right: the Mana Accelerator totem (E4) is a **new `.tres`, no code change**. That is D6's economy-wide, data-defined scope. [Source: stories-manual-e3.md#E3.S4 item 1; docs/game-architecture.md#D6; #Novel Pattern 5]
- **`ResourceGenerationRule`/`CardCastCondition`/`EconomyEvaluator` do not exist in `src/` today**, even though `docs/game-architecture.md` describes them as already landed in several places with no "Planned (E3)" qualifier: the Directory Tree lists `economy/economy_evaluator.gd` and `resources/resource_generation_rule.gd`/`card_cast_condition.gd` as though present (`game-architecture.md:548,553`), the D6 capability table marks the feature "E0/E3 · Full" (`:107,190`), the Testable-without-engine-runtime table lists "the D6 evaluators" as already testable (`:511`), and Novel Pattern 5 (`:788-806`) is written as existing code. Read the architecture doc's evaluator sections as a SPEC to build against, not a description of shipped code. [Source: decision-log.md E3-RG/R8]
- **The melee-hit hook does not need wiring — it is already live and shipped.** `MatchState._generate_mana` grants `balance.melee_hit_mana` flat to the attacker for every confirmed hit (full damage AND block-mitigated damage both confirm; only a deflect, an iframe drop, or a DEAD-slot drop withhold it), gated on the injected `FeatureFlags.melee_mana_generation`. This story's job on that path is the REFACTOR (rule-driven via the evaluator, proof obligation above) plus the NEW passive-tick income — not standing up a call site that already exists. The superseded citation to `stories-manual-e1.md#E1.S5`'s evaluator framing (that manual's item 3) is replaced: that framing was declared superseded at the 1-5 gate itself ("the 1-5 story text is cleaned of every evaluator reference... superseded by this entry; the manual is not edited"). [Source: decision-log.md:224; decision-log.md E3-RG/R8; match_runner.gd; 2-4/R13 (decision-log:727); BC/R3 (decision-log:1017)]
- Fixed per-tick passive amount, never `rate × delta`. [Source: docs/game-architecture.md#D2 A1 follow-up]
- **What `ManaPool` lacks that `StaminaPool` has.** `StaminaPool` regens via a `BalanceTicks`-derived per-tick rate (`stamina_regen_per_tick`, derived once at load from `stamina_regen_per_second`) ticked every `advance()` in step 2 (`StaminaPool.tick_timers()`). `ManaPool` (`src/state/pools/mana_pool.gd`) has only `add`/`spend`/`set_maximum` — no regen method, no `BalanceTicks` field, and no seat anywhere in the tick ladder. The `passive_tick` rule needs its own derived per-tick value (e.g. `mana_regen_per_tick` on `BalanceTicks`, mirroring the stamina precedent) and its own seat — step 2 alongside stamina, or step 5 alongside the existing melee-hit generation; this story picks one and states why. [Source: decision-log.md E3-RG/R8; src/state/timing/balance_ticks.gd; src/state/pools/mana_pool.gd]

### Project Structure Notes

- Rules `.tres` under `data/` (rules/balance); evaluator `src/state/economy/economy_evaluator.gd`; `ManaPool` in `src/state/pools/`.

### Project Context Rules

- **Feature flags / graceful degradation; state reads injected `FeatureFlags`, never the service.** [Source: docs/project-context.md#HARD RULE — Feature flags]
- **Flag matrix testing:** both ON and OFF paths asserted. [Source: docs/project-context.md#Testing Rules]

### References

- [Source: stories-manual-e3.md#E3.S4]
- [Source: gdd.md#B Mana Economy; #P2]
- [Source: docs/game-architecture.md#D6; #Novel Pattern 5]

## Golden Prediction

**MOVES, at least one re-baseline, cause named separately from the refactor itself.** The refactor
(direct path -> evaluator) is required to be a NO-OP on the melee case by its own proof obligation (AC2),
so it alone should NOT move the hash — measure it in isolation first and confirm. The NEW passive-tick
income is the actual cause: it changes mana's value over time in the recorded determinism sequence the
moment it is authored non-zero, and (if `passive_tick` gets a `BalanceTicks` seat) adds a derived field.
Isolate: (1) evaluator swap alone, hash unchanged — confirms the proof obligation; (2) passive tick added,
hash moves — the named cause. Baseline hash is whatever 3-1/3-2/3-3 leave it at; do not assume
`33817201...21da2` still applies once earlier E3 stories have landed.

## Live Smoke

**REQUIRED at flag-matrix granularity, not full two-human.** The flag matrix (AC5, `melee_mana_generation`
on/off) is headless-provable; what a live smoke adds is whether the flywheel READS as a flywheel during a
real exchange — the mana bar the E2 HUD already renders should visibly climb on landed hits. Runs on the
shipped default (two live killable humans, no `.tscn` edit, per the 2-3/R7 no-flip-line pattern). Record
whether melee-funded mana feels like a flywheel or like bookkeeping in `docs/playtest-log.md` — the
E3.S4 revisit note names this as exactly what the first playtest was supposed to tell you.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
