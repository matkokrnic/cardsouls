---
baseline_commit: b95613b64e2502653d82d2e556b7c12d0f279453
---

# Story 4.2: Minion AI and throttled targeting

Status: done

> **Scope note.** Position 5 of the E4 order (`E4-P/R1`, decision-log Session 2026-08-07 -- E4
> ratification): 4-0 -> 4-0a -> 4-B1 -> 4-1 (done) -> **4-2** -> 4-3 -> 4-4 -> 4-5. Tier A
> (`E4-P/R9`: touches `src/state/`, the golden, and determinism) -- full ritual applies:
> readiness gate with numbered rulings -> dev pass -> code review -> live smoke where `R-D6`
> attaches -> close-out. **NAMED BUDGET LINE (this authoring pass): E4 planning named 4-2 the
> largest story of the epic; if the readiness gate returns more than 8 blocking findings, it
> splits via `gds-correct-course` rather than absorbing them in place -- named now so a split is
> planned, not a rescue, on the `E4-P/R2` precedent 4-1 itself carried.**
>
> **Two questions this authoring pass deliberately does NOT decide** -- both reserved for this
> story's own readiness gate, with evidence in hand: where a unit's position lives, and whether
> throttled targeting is a shared in-`advance()` tick or `Area3D` overlap queries (or the "and/or"
> epics.md leaves open). See Open Questions below. Everything else in this file is written to not
> presuppose either answer.

## Story

As a player,
I want summoned minions to autonomously pick a target using data-defined priority rules and act
on it on a throttled cadence,
so that a unit on the board threatens play instead of standing inert after it spawns.

## Acceptance Criteria

1. **`MinionPriority` is a D6 data-defined `.tres`, the `ResourceGenerationRule`/
   `CardCastCondition` precedent applied unchanged (`E4-P/R5`).** Pure schema, no logic
   (`src/state/resources/minion_priority.gd`, currently absent from the tree -- confirmed by
   directory listing). **Ruled (`4-2/R16`): the schema is PARAMETRIC, not type-name-keyed** -- it
   is false as originally written that "new priority types [are] addable with zero code changes",
   because selection POLICY is code. Fields carry PARAMETERS a generic evaluator applies (target
   side, prefer-hero, ordering mode), on the `ResourceGenerationRule` `amount_field` precedent where
   the rule names a FIELD and the evaluator stays generic -- never a gameplay NUMBER baked in if a
   shared balance field already owns it. Exactly TWO `.tres` files are authored this story, the two
   expressible today: **Standard** and **Hero-Seeker**. `Tank` (needs HP, 4-3) and `Bomber`/AoE
   (needs position, 4-3/4-4) are named DEFERRED, not authored. An unrecognized or unauthored
   parameter falls to a named returned reason (AC 6's second reason).
2. **`TargetingService` is a pure, fully static evaluator in `src/state/`, a SIBLING of
   `EconomyEvaluator`/`CastEvaluator`/`CardEffectResolver`, not a branch inside any of them
   (D6, `E4-P/R5`).** THE one place `MinionPriority` rules are read. Computes a target verdict
   per unit; touches no board, no pool, no container -- the caller (`MatchState.advance()`'s
   ordered dispatch) applies whatever the verdict implies (D6: the evaluator computes, the
   caller applies). Stateless by construction: nothing is retained between calls (CONSTRAINT C).
3. **`MinionPriority` rules are loaded by directory scan from `data/minions/`, the
   `EconomyEvaluator.load_rules`/`RULES_DIR` precedent verbatim** -- sorted filename order,
   non-rule resources skipped, a missing directory degrades to an empty rule set rather than
   failing. Rules are STRUCTURE, loaded once; they are not injected the way `BalanceConfig` and
   `FeatureFlags` are (the `E4-P/R5` precedent's own stated reason: a new injection seam would
   force every existing fixture to inject rules before targeting worked at all).
4. **`MinionPriority` `.tres` content joins golden discipline BY RULING (`E4-P/R6`), the `4-1/R4`
   template applied verbatim.** `4-1/R4` forbids an AC asserting a measured golden dependency the
   Golden Prediction itself later calls conditional -- this AC previously did exactly that, and is
   RESTATED to fix it. Two halves, neither a claim of an unmeasured shift: (a) `.tres` content under
   `data/minions/` joins golden discipline as a determinism-relevant class of change carrying review
   burden, narrowing `BC/R3`, the `3-4/R6` precedent; (b) the MACHINE half -- an authoring test
   asserting every `.tres` in `data/minions/` loads as a `MinionPriority` and carries recognized
   parameters. The "load-bearing for the hash" claim moves OUT of this AC and into the Golden
   Prediction, where `4-2/R2`'s hashed target index pair makes the dependency unconditional anyway.
5. **Targeting is gated on `FeatureFlags.minions` (already `true` in `data/feature_flags.tres`,
   shipped by 4-1), degrading gracefully when off** -- the project-context HARD RULE, made
   concrete for this story's own layer: a unit with the flag closed never acquires a target,
   exactly the way 4-1's summon resolution gates on the same flag. State-layer code receives
   `FeatureFlags` by injection and never reads `FeatureFlagsService` directly.
6. **Every outcome is a named returned value, never an `Invariant.check` crash.** An empty board,
   no eligible candidates, or an unrecognized priority type all read as an honest, named "no
   target" outcome -- never a crash, never silently indistinguishable from "target acquired and
   it happens to be null." At minimum two distinct reasons, on the `CastEvaluator.REASON_*` /
   `CardEffectResolver` constant-vocabulary precedent: no living candidate exists, and priority
   data is missing/unrecognized for the unit's type.
7. **Target re-evaluation is throttled, not per-frame per-unit** -- the project-context Performance
   Rule made concrete: "target-acquisition scans ... must NOT run every frame for every unit. Use
   a shared, throttled tick (e.g. re-target every ~0.1-0.25 s)." **Ruled (`4-2/R5`), all four
   previously-underdetermined parts of "balance-authored cadence":**
   (a) a new authoring field `minion_retarget_interval_seconds` on `BalanceConfig` AND a derived
   `minion_retarget_interval_ticks` on `BalanceTicks`, on the `draw_replacement_delay_seconds` ->
   `_ticks` precedent;
   (b) `apply_balance` is NOT touched -- the per-pool contract (`3-1/R2`) governs pool bounds and a
   cadence is not one; a dev pass must not invent a per-player injection seat for it;
   (c) the counter is `_tick % interval` -- no new state, no new hash key;
   (d) the degenerate value is defined: the interval clamps to at least 1 tick always, so an
   authored 0 means every tick.
   `_golden_config()` MUST author a real (non-degenerate) cadence on the `DRAW_DELAY_TICKS`
   precedent, or the throttle measures a false non-move -- a task, not a hope (see Tasks).
   `MatchState.advance()` already reserves the seat: step 7, `match_state.gd:279`, currently the
   literal comment `[E4 minion/totem throttled-tick seam]`.
8. **Target selection is deterministic under a fixed candidate set and a fixed tie-break rule**,
   stated and tested explicitly -- ties never resolve by iteration order over a `Dictionary` or by
   `Array[StringName].sort()`'s internal-pointer ordering (the measured hazard this codebase names
   repeatedly). **Ruled (`4-2/R3`):** the candidate set is the OPPOSING side ONLY -- the opposing
   hero plus the units on the opposing player's board. Own-side units are never candidates. THE
   tie-break (not "or an equivalent stable, authored ordering" -- that alternative is deleted): the
   total order is slot ascending (the fixed P1 -> P2 order, `match_state.gd:177`) then board index
   ascending.
9. **`UnitBoard` gains the identity content its own header reserves for this story's consumer**
   (`unit_board.gd:29`: "`4-2`'s gate rules on position ownership with `TargetingService` as a
   real consumer; whatever content a unit then needs is added THERE, against something that reads
   it"). At minimum a stable per-unit identity TargetingService can address survives 4-1's
   count-only shape -- what else a record carries (position, owner side, priority-type reference)
   is bounded by Open Question 1's ruling below (`4-2/R14`), not decided by this AC. This is a
   necessary consequence of AC 2 having a real thing to select FROM, not a scope choice.
   **Measured, `4-2/R8`:** this identity extension moves NEITHER the key set NOR the golden ON ITS
   OWN -- `UnitBoard` is a bare int today, `size()` returns the collection length, `unit_count`
   emits the same value whether the extension ships or not. Predicted a NON-MOVER in the Golden
   Prediction, confirmed by the key set holding at ten if no key ships. See Golden Prediction for
   the golden's two actual (separately named) movers this story.
10. **Replay parity holds under the shared in-`advance()` throttled tick ruled at Open Question 2
    (`4-2/R15`).** It is hashable by construction and needs no new recorder channel (the
    `IntentRecorder` content-channel package is untouched). `test_replay_identity.gd`'s coverage
    extends to whatever new state this story adds, and a driven run replays to a bit-identical
    hash. **Ruled (`4-2/R7`), discharged by `4-2/R14`'s deferral, not by argument:** with no new
    recorded fact channel, `FORMAT_VERSION` stays 2. A unit's board record and the
    directory-scanned `MinionPriority` content are DERIVED STATE and CONTENT respectively, not
    record channels, so no bump is owed. Residual hazard, previously unnamed, named here: a replay
    reproduces a run only if `data/minions/` is unchanged -- exactly as it already only reproduces
    if `data/economy/` is unchanged (pre-existing, not new).
11. **The applied target is a HASHED INDEX PAIR (`4-2/R2`).** A throttle makes an acquired target
    unavoidable cross-tick state -- it cannot be recomputed for free every tick the way a stateless
    per-frame scan could be. The verdict `TargetingService` computes, once stored, is `[slot,
    index]` on the `pending_draw_owed` precedent (`player_state.gd:94-95`, "these are slot
    INDICES, the counts-and-indices rule intact"): `slot` and `index` are both plain `int`s, where
    `index >= 0` addresses a unit on the `slot`-identified player's board and `index == -1`
    addresses that player's hero. No identity, no object, no `StringName` reaches the hash. It
    enters the snapshot.

## Deferred / Out of scope

- **Minion movement** (4-3) -- **Ruled (`4-2/R4`):** movement IS OUT of this story. Without
  movement a unit stands in a decorative legibility row the runner places, so distance-based
  targeting over that placement would be a fake mechanic (this is also why Open Question 1's
  position-ownership question is deferred again, at `4-2/R14` below, rather than answered here).
  A unit that acquires a target does not damage it, either -- minion combat is also 4-3's. No HP,
  no attack resolution, no death consequence for a targeted unit this story. Whatever an "engage"
  outcome from `TargetingService` implies for a unit's approach, it stops short of both movement
  and a hit.
- **Totems** (4-4) -- `MinionPriority` targets active board units; totem-specific
  behaviour (e.g. a totem's own targeting exemption, or being itself a valid Bomber/AoE candidate)
  is not authored or tested here beyond whatever falls out of the totem clause's positionless,
  type/kind-less unit records still holding at this story's start.
- **Object pooling / performance** (4-5) -- units and any targeting-support nodes stay plain
  instantiated/freed content this story; 4-5's tier and failure criterion are still undecided
  (`E4-P/R8`), owned by 4-1's close-out, not reopened here.
- **Real per-priority-type tuning values**, and the `Tank`/`Bomber`-AoE priority types themselves
  (`4-2/R16` -- they need HP and position respectively, neither of which this story ships) --
  playtest-grade balancing of aggro ranges, AoE clump thresholds, etc. is iteration work, not this
  story's gate.

## Open Questions -- ruled at THIS story's readiness gate

### Open Question 1 -- Where does a unit's position live? -- RULED: DEFERRED AGAIN, to 4-3 (`4-2/R14`)

**Deferred here from `4-1/R12` (`E4-P/R7`)**, which named this story's gate as the place a real
consumer (`TargetingService`) exists to force the decision, rather than let it default to whatever
seemed convenient when no consumer did. **Ruled: this is NOT a second can-kick.** `4-1/R12`
deferred because no consumer existed at all; `4-2/R4` (above) takes movement out of this story, and
a `TargetingService` without movement is still not that consumer -- movement is the forcing point,
because distance-based targeting over a decorative, runner-placed row would be a fake mechanic
(`4-2/R4`'s own reasoning). The question is therefore deferred again, to **4-3**, WITH movement
named as its owner -- not left open by default.

Consequences of this ruling, stated explicitly:
- `FORMAT_VERSION` stays 2 -- no new recorded fact channel, no v2 refusal, no `REQUIRED_KEYS` or
  `EXPECTED_INTAKE_SURFACE` moves (this is also `4-2/R7`'s premise, below).
- **F1 is untouched** -- position stays actor-owned; `UnitBoard`'s per-unit identity (AC 9) still
  carries no `Vector3`.
- **4-2 targets over the AUTHORED ORDER of `4-2/R3`** (slot ascending, then board index
  ascending), never over distance. The two named futures from `4-1/R12`'s Dev Notes (an inward
  position/distance relay vs. state-owned floats reaching the hash) remain live options, unchanged
  in substance, now owned by 4-3's gate rather than this one.

### Open Question 2 -- Throttled tick vs. `Area3D` overlap queries -- RULED: a shared throttled tick evaluated inside `advance()` (`4-2/R15`)

**This is a determinism question, not a performance one (`E3-R/R5.2`, `E4-P/R7`).** `epics.md`'s
own wording -- "throttled tick (~0.1-0.25 s) **and/or** `Area3D` overlap queries" -- hid that the
two are not interchangeable implementations of the same seam; they place the targeting fact on
OPPOSITE SIDES of the state/visual seam. **Ruled: `Area3D` overlap queries are REJECTED, by
name** -- physics-frame, live outside `src/state/`, not hashable, the same reasoning that rejected
physics-timing contact detection at 1-7 (`D-4`): Jolt's overlap results are not guaranteed
bit-stable across a recording and its replay.

The shipped mechanism is **a shared throttled tick evaluated INSIDE `advance()`** on a fixed
integer-tick cadence (the A1/`TimingWindow` precedent, concretized by `4-2/R5`'s cadence fields).
It is hashable by construction, reads whatever facts already live in state (the authored order,
per Open Question 1's deferral), and its outcome is deterministic and replay-safe for free, exactly
like every other step-1-through-8 computation.

Consequences of this ruling, stated explicitly:
- No fourth collision layer, no new observation seam -- `test_runner_observation_seams_are_exactly_
  eight` (`test_architecture_invariants.gd`) is untouched by this story.
- The Dev Notes paragraph below about that same guard, written for the `Area3D` branch that did not
  ship, is MOOT -- the reasoning stays (it explains why the guard is not at risk), it is not
  deleted.

## Tasks / Subtasks

**`4-2/R6` (BLOCKING, ruled): every AC below gets a named falsifiable test on its own task line --
a guard that cannot fall is this project's repeat failure (`2-4/D1`, `2-6/D1`).**

- [x] Author `MinionPriority` (`src/state/resources/minion_priority.gd`), the D6 schema precedent,
      PARAMETRIC per `4-2/R16` (target side, prefer-hero, ordering mode fields) -- test:
      `test_minion_priority.gd` asserts the schema loads and exposes those parameters (AC: 1)
- [x] Author exactly TWO `data/minions/*.tres` files -- `Standard` and `Hero-Seeker` (`4-2/R16`;
      `Tank` and `Bomber`/AoE are named-deferred, not authored) -- test: an authoring test in the
      `test_balance_authoring.gd` family asserting every `.tres` in `data/minions/` loads as a
      `MinionPriority` and carries recognized parameters (AC: 1, 4).
      **`Standard` governs every unit; `Hero-Seeker` is AUTHORED BUT TEST-ONLY (`4-2/R17`,
      condition 2)** -- nothing in the shipped path selects it, and `src/` may not name it (scanned
      by `test_minion_authoring.gd`). It is not speculative machinery: without a differing pair
      there is no way to prove the evaluator is generic rather than a hardcoded branch, which is the
      same non-vacuity argument the golden's measured pairs rest on.
- [x] Write `TargetingService` (`src/state/targeting/targeting_service.gd` -- `4-2/R12`, NOT under
      `economy/`), the directory-scan loader, and the deterministic tie-break (opposing side only,
      slot-then-index order, `4-2/R3`) -- test: `test_targeting_service.gd` covering the loader,
      the candidate-set restriction, and the tie-break order (AC: 2, 3, 8)
- [x] Extend `UnitBoard`/`PlayerState.units` with per-unit identity (position stays OUT, `4-2/R14`
      defers it to 4-3) -- test: `test_targeting_service.gd` or `test_unit_board.gd` asserting the
      identity is stable and addressable, and a golden/key-set measurement confirming the
      NON-MOVER prediction (`4-2/R8`) (AC: 9)
- [x] Author `minion_retarget_interval_seconds` (`BalanceConfig`) and derived
      `minion_retarget_interval_ticks` (`BalanceTicks`), on the `draw_replacement_delay_seconds`
      precedent, clamped to >= 1 tick (`4-2/R5`) -- test: `test_balance_config.gd`/
      `test_balance_ticks.gd` covering the derivation and the clamp at an authored 0 (AC: 7)
- [x] `_golden_config()` authors a real, non-degenerate retarget cadence, on the
      `DRAW_DELAY_TICKS` precedent (`4-2/R5`) -- otherwise the throttle measures a false non-move;
      this is a task, not a hope (AC: 7, Golden Prediction)
- [x] Wire the throttled evaluation into `MatchState.advance()` step 7's reserved seat
      (`match_state.gd:279`), the ruled shared in-`advance()` tick (`4-2/R15`), storing the
      `[slot, index]` verdict (`4-2/R2`) -- test, as a NAMED PAIR (`4-2/R6`): (a) the POSITIVE
      direction -- a target IS acquired against a populated opposing candidate set (a test that
      only ever asserts "no target" passes vacuously and does not satisfy this); (b) a BEHAVIOURAL
      NEGATIVE -- change the candidate set mid-interval and confirm the applied target does NOT
      change until the throttle's boundary tick, and DOES change at it (not instrumentation
      counting calls) (AC: 7, 8, 11)
- [x] Gate targeting on `FeatureFlags.minions`; matrix-test ON/OFF -- test: a flag-off unit never
      acquires a target, on the 4-1 gating precedent (AC: 5)
- [x] Assert the authored `data/minions/` priority set loads NON-EMPTY under the headless harness
      (`4-2/R11`) -- AC 3's graceful-degradation-on-missing-directory clause means a silent load
      failure would otherwise look like a passing test (AC: 3)
- [x] Update or assert the snapshot key-set pin (`test_card_observation.gd`, find by content) --
      it moves when `4-2/R2`'s target key ships (`4-2/R6`) (AC: 9, 11)
- [x] Golden re-baseline: measure and separate the TWO separately-named causes this story predicts
      (snapshot-shape, from `4-2/R2`'s key; behavioural, from a throttled target actually being
      acquired), each in both directions, exactly as every prior multi-cause re-baseline in this
      project has, per the Golden Prediction below (AC: 4, 11)
- [x] Replay parity coverage for the shared in-`advance()` throttled tick (`4-2/R15`) -- extend
      `test_replay_identity.gd` to the new hashed state; `FORMAT_VERSION` stays 2 (`4-2/R7`,
      `4-2/R14`) (AC: 10)
- [x] Comment-only: re-point the two shipped comments naming 4-2 as minion-movement owner to 4-3
      (`4-2/R4`) -- `src/actors/minions/unit_actor.gd` and `src/main/match_runner.gd`, found by
      content. Landed as THIS readiness-gate pass's own separate commit
      (`chore(4-3): re-point minion movement ownership comments`), not the dev pass's --
      comment-only, no behaviour change.

## Dev Notes

- **Read before touching, `economy_evaluator.gd` and `card_effect_resolver.gd`**: both are the
  shape `TargetingService` must match -- fully static, stateless, a directory-scan loader for
  authored `.tres` rule content, a header declaring itself "THE one place" its kind of data is
  read. Do not fold targeting into either file; each existing evaluator's header would contradict
  a targeting read if folded in, the same reasoning that kept `CardEffectResolver` a sibling
  rather than a branch.
- **Read before touching, `unit_board.gd`**: its own header already names this story
  ("`4-2`'s gate rules on position ownership with `TargetingService` as a real consumer; whatever
  content a unit then needs is added THERE") -- extending it is not a scope choice, it is the
  header's own stated plan being executed. Do not remove the totem clause's type/kind-less
  guarantee or 4-1's positionless guarantee without the gate's explicit ruling; both are still
  standing facts until Open Question 1 resolves them.
- **Read before touching, `match_state.gd:279`**: the reserved comment
  `# 7. Board update          [E4 minion/totem throttled-tick seam]` is the literal seat AC 7
  fills. Read the full `advance()` ordered dispatch (steps 1-8, `match_state.gd:178-281`) before
  adding to it -- step 7 sits between resource generation (step 5) / card resolution (step 6) and
  the resolution check (step 8), so a unit's target must be knowable before step 8 asks "is
  anything dead," even though this story adds no death consequence itself.
- **`data/minions/` and `src/state/resources/minion_priority.gd` do not exist yet** (confirmed:
  `data/minions/` holds only `.gitkeep`; no `minion_priority.gd` anywhere in the tree). This story
  is the first to put real content in both, exactly as 4-1 was the first to put real content in
  `src/actors/minions/`.
- **The golden fixture's board is no longer guaranteed empty from this story onward.** 4-1's
  golden fixture casts a `summon_*` card at tick 22 (`4-1/R6`); once `MinionPriority` content is a
  directory-scanned, always-loaded rule set (the `EconomyEvaluator` precedent, not an injected
  one), that unit begins evaluating targets on whatever cadence AC 7 ships from the tick after it
  spawns, with the `minions` flag already `true` in the fixture's shipped flags. This is a REAL,
  not hypothetical, coupling to authored `data/minions/*.tres` content on the golden's own path --
  flagged here so the gate does not discover it as a surprise finding.
- **`FeatureFlags.minions` is already `true` in the shipped `data/feature_flags.tres`** (4-1's
  implementation decision, code-reviewed and accepted). This story does not flip it; it is already
  live, so AC 5's ON path is exercised by the shipped default, not a test-only fixture flag flip.
- **MOOT as of `4-2/R15`: the runner's observation-seam count is currently pinned at eight**
  (`test_architecture_invariants.gd`, `test_runner_observation_seams_are_exactly_eight`). This note
  was written for the possibility that Open Question 2 resolved toward an `Area3D`-based mechanism
  needing a new `connect_*` seam -- that guard would then have needed the same kind of named,
  reviewed amendment `3-6/R2` and 4-1 both set precedent for. `4-2/R15` rejected the `Area3D`
  branch by name, so this guard is untouched by this story; the reasoning is kept here rather than
  deleted, since a future story reopening Open Question 2's rejected branch would need it again.
- **The snapshot key set is currently ten** (`test_card_observation.gd:230-231`:
  `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs", "pending_draw",
  "pending_draw_owed", "stamina", "unit_count"]`). It goes to eleven this story, on `4-2/R2`'s
  ruling: the shape is the `[slot, index]` pair AC 11 states, not the count-only guess this note
  originally offered ("a count of units-with-an-acquired-target ... is the shape to reach for") --
  superseded by the ruling, kept here so the reasoning for why counts-only was the DEFAULT
  assumption is not lost. `AC 9`'s identity extension itself still follows the counts-only
  precedent (`4-2/R8`: no unit identity, no `StringName`, no object reference reaches the hash) --
  it is `R2`'s target-verdict key, not AC 9's identity, that grows the set.
- **RULED AT THE DEV PASS, `4-2/R17` (operator, this session): `Standard` governs every unit, and
  `Hero-Seeker` is AUTHORED BUT TEST-ONLY.** The gap this closes was not covered by `R1`-`R16`: AC 1
  ships exactly two `.tres` files, but 4-1's totem clause ships unit records type/kind-less and
  `4-2/R14` adds no field to them, so nothing in the shipped path could select between the two.
  Three conditions, all binding: (1) the selection is an EXPLICIT NAMED CONSTANT resolved BY NAME
  from the sorted rule set (`TargetingService.PRIORITY_STANDARD`), never "whatever sorts first" --
  and if the named rule is absent that falls to AC 6's missing/unrecognized-data reason and returns a
  named no-target outcome, never a silent substitution of the other rule; (2) `Hero-Seeker` stays
  authored but **TEST-ONLY**, in those words -- nothing in the shipped path selects it, `src/` may not
  name it, and it is not speculative machinery because without a differing pair there is no way to
  prove the evaluator is generic rather than a hardcoded branch; (3) per-unit priority CHOICE gets a
  named forcing point rather than staying open -- the first story where units actually differ (4-3
  combat / 4-4 totems), and that story, not this one, may add a field to the unit record. In live 1v1
  play today the two rules coincide anyway: with the opposing board empty, `Standard`'s units-first
  ordering falls through to the opposing hero, which is also what `Hero-Seeker` picks.
- **RULED, `4-2/R9`: DEBT B is fully discharged and a new `data/minions/` `load()` inherits
  nothing from it.** `CACHE_MODE_IGNORE` exists only on `BalanceConfigService.reload()`, and only
  because balance has a LIVE reload trigger. `MinionPriority` content is directory-scanned,
  always-loaded structure (AC 3), on the `EconomyEvaluator` precedent, with no reload path -- the
  dev pass must not add a reload path or a cache mode for it by analogy.
- **CITATION CORRECTION, `4-2/R10`: the `Array[StringName].sort()` internal-pointer hazard is NOT
  in `project-context.md` -- it lives in CODE.** The exact sites: `player_state.gd:77` and
  `player_state.gd:206-207` (the comments on Deck/Hand/DiscardPile explaining why they stay
  `StringName`-only and out of any sorted comparison), and `test_determinism.gd:170` (why the
  injected cost map's `StringName` keys stay out of the hash). Point at those, not at
  `project-context.md`, for this specific hazard. The DICTIONARY sorted-key rule IS in
  `project-context.md`, under Testing Rules (`project-context.md:131`, "never insertion-order
  `Dictionary` iteration"). Also live for any `MinionPriority` parameter lookup table: the
  `3-0d/R21` gotcha, already documented at `project-context.md:163` -- `Dictionary.has(key)` is
  TRUE for a key whose value is `null`, so a parameter-presence check must also check the value's
  type before trusting it.

### Project Structure Notes

- `src/state/resources/minion_priority.gd`: new D6 schema (AC 1). Directory Tree already reserves
  the name (`game-architecture.md:590`, tagged `(E4)`); `MinionPriority` stays in
  `src/state/resources/` where the architecture already reserves it (`4-2/R12`).
- `data/minions/`: first real content, replacing the `.gitkeep`-only directory (AC 1).
- `src/state/targeting/targeting_service.gd`: `TargetingService`. **Corrected, `4-2/R12`**:
  NOT under `src/state/economy/` -- `economy/` holds three economy evaluators and targeting would
  hand that name to every E4 story after this one. This corrects an earlier pass of this same
  checklist that had firmed the path to `economy/`; the D6 sibling relationship to
  `card_effect_resolver.gd` (AC 2, 3) is unchanged, only the directory moves.
- `src/state/unit_board.gd`, `src/state/player_state.gd`: `UnitBoard` gains per-unit identity
  (AC 9, no position -- `4-2/R14`); `PlayerState.to_snapshot()` gains the `[slot, index]` target
  key (AC 11, `4-2/R2`, RULED, no longer conditional).
- `src/state/match_state.gd`: step 7's reserved seat (`match_state.gd:279`) gains the shared
  in-`advance()` throttled tick (AC 7, `4-2/R15`).
- `test/state/`: new `test_targeting_service.gd` (or similarly named) for AC 2/3/6/8; existing
  golden/snapshot/replay-identity/architecture-invariant suites extended per every ruling above.

### Project Context Rules

- **The evaluator COMPUTES, the caller APPLIES (D6).** `TargetingService` returns a verdict; any
  mutation happens inside `MatchState.advance()`'s ordered dispatch. [Source:
  docs/game-architecture.md D6; economy_evaluator.gd, cast_evaluator.gd, card_effect_resolver.gd
  headers]
- **Any `.tres` injected into or read by the state layer joins golden discipline, treated as
  code.** [Source: decision-log.md `E4-P/R6`; `3-4/R6`; project-context.md "Golden isolation"]
- **CONSTRAINT C: read `balance`/injected/authored values inline, never cache.**
  [Source: project-context.md]
- **HARD RULE -- Feature flags.** Targeting checks the injected `FeatureFlags` and degrades
  gracefully when off; state-layer code never reads `FeatureFlagsService` directly.
  [Source: project-context.md]
- **Throttled tick, never per-frame per-unit distance loops.**
  [Source: project-context.md Performance Rules]
- **Guard mechanism over guard pattern**: any deliberately amended machine-checked scan (intake
  surface, observation-seam count) is a named, reviewed exception, the `3-6/R2` precedent, never a
  widened regex. [Source: project-context.md]

### References

- [Source: decision-log.md Session 2026-08-07 -- E4 ratification, `E4-P/R1`, `E4-P/R2`, `E4-P/R5`,
  `E4-P/R6`, `E4-P/R7`, `E4-P/R9`]
- [Source: docs/implementation-artifacts/4-1-basic-summon-resolution.md -- Open Question / Dev
  Notes `4-1/R12`, `unit_board.gd`'s own header]
- [Source: docs/game-architecture.md D6 (`game-architecture.md:399`), D9 (`game-architecture.md:450`),
  `advance()` ordered dispatch step 7 (`game-architecture.md:266`), Directory Tree
  (`src/state/resources/minion_priority.gd (E4)`, `data/minions/ (4-1, PLANNED)`)]
- [Source: src/state/economy/economy_evaluator.gd; src/state/economy/cast_evaluator.gd;
  src/state/economy/card_effect_resolver.gd; src/state/unit_board.gd; src/state/player_state.gd;
  src/state/hero_state.gd:1-9; src/state/match_state.gd:178-281]
- [Source: src/main/match_runner.gd:729 (`_gather_contact_facts`)]
- [Source: src/state/resources/feature_flags.gd:19 (`minions`); data/feature_flags.tres]
- [Source: test/state/test_card_observation.gd:230-231; test/state/test_intent_recorder.gd:37-40;
  test/state/test_live_reload.gd:42,115-119; test/state/test_architecture_invariants.gd
  (`test_runner_observation_seams_are_exactly_eight`); test/state/test_determinism.gd:336 (GOLDEN)]
- [Source: `docs/game-architecture.md:452`, the architecture's own characterisation of this seam --
  "a `TargetingService` interface (throttled shared-tick provider, story 4-2)" -- support for
  `4-2/R15`]
- [Source: `src/state/player_state.gd:77,206-207`; `test/state/test_determinism.gd:170` (the
  `Array[StringName].sort()` internal-pointer hazard, `4-2/R10`); `docs/project-context.md:131`
  (Dictionary sorted-key rule); `docs/project-context.md:163` (`3-0d/R21`, `Dictionary.has()` true
  for `null`)]

## Golden Prediction

**Ruled at the readiness gate: this story MOVES the golden, with TWO separately named causes.**
Neither is asserted as an already-measured shift -- no dev pass has run yet -- but both are now
PREDICTED AS MOVERS, not offered conditionally the way the pre-gate text did (the exact form
`4-1/R4` forbids, corrected out of AC 4 by `4-2/R1`). Each must be measured in both directions at
the dev pass, isolated on its own, per this project's standing multi-cause re-baseline discipline.

1. **Snapshot-shape cause (mover), from `4-2/R2`'s target key.** AC 11's `[slot, index]` verdict
   enters the snapshot. It moves the golden at its introduction the same way `unit_count` (4-1),
   `discard_size` (3-5a), and `pending_draw_owed` (4-0) each did -- present at an all-"no target"
   value before any unit ever acquires one. Unconditional, because `4-2/R2` ruled the storage
   representation rather than leaving it open.
2. **Behavioural cause (mover), from a throttled target actually being acquired.** The golden
   fixture already casts a `summon_*` card at tick 22 with `minions` flag on (4-1, confirmed).
   `_golden_config()` MUST author a real, non-degenerate `minion_retarget_interval_ticks`
   (`4-2/R5`'s own task, on the `DRAW_DELAY_TICKS` precedent) -- once it does, the spawned unit's
   `[slot, index]` verdict is written from the first throttle boundary after it spawns onward, and
   the hash moves from that tick forward. If `_golden_config()` shipped a degenerate cadence
   instead, this cause would measure a FALSE non-move -- named here so the dev pass does not
   mistake an unauthored cadence for a genuine non-mover.
3. **Non-mover, `4-2/R8`: AC 9's identity extension, on its own.** `UnitBoard` is a bare int
   today, `size()` returns the collection length, `unit_count` emits the same value whether the
   identity extension ships or not -- predicted a NON-mover, CONFIRMED by the key set holding at
   ten if AC 11's key is the only one that ships (the golden's two real movers above are both
   `4-2/R2`'s key and its behaviour, not AC 9's identity itself).
4. **Possible non-mover: `rng_state`.** Nothing about tie-break selection should consume RNG
   (`4-2/R3`: a fixed, authored total order, not a random one) -- predicted a non-mover, to be
   CONFIRMED by an explicit test on the `3-5b`/`4-0`/`4-1` precedent of testing predicted
   non-movers rather than assuming them.

No baseline hash is recorded here as a target, per the standing rule (3-3 gate) that a Golden
Prediction baseline is re-derived from `test_determinism.gd`'s `GOLDEN` constant at gate time. The
BEFORE value for this authoring pass: `GOLDEN := "78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5"`
(`test/state/test_determinism.gd:336`), the value 4-1 shipped. Suite BEFORE: 399 state tests / 2517
assertions, 0 failed, plus the integration suite, all PASS (measured this authoring pass,
`bash test/run_all.sh`).

## Live Smoke

**REQUIRED**, on the Tier A default and this story's own player-facing claim, **rewritten at the
gate per `4-2/R13`.** With movement out (`4-2/R4`), "does not sit permanently inert" is
UNFALSIFIABLE by observation -- a unit that never moves gives a naive observer nothing to watch
for. The smoke gets a visible signal instead: **the grey box ROTATES to face its acquired
target.** This is PURELY PRESENTATIONAL -- the runner reads both node positions and the applied
target from the snapshot (AC 11's `[slot, index]`), on 4-1's own precedent of reading the snapshot
for presentation; it opens no new observation seam.

Script, at minimum: summon a unit against a live opposing hero/unit and confirm the grey box
visibly rotates to face whichever target `TargetingService` acquired once the retarget throttle
fires; confirm the rotation follows if the candidate set changes at a throttle boundary (not
mid-interval, per AC 7's behavioural-negative test); confirm `FeatureFlags.minions = false`
degrades to today's 4-1 behaviour (unit present, inert, no rotation). The script includes a kill.

**`R-D6` is RE-INVOKED on this gate** -- measured SPENT on 4-1's smoke (2026-08-09), so this is
the next player-facing story carrying a live smoke, and the two-human kill-acceptance ritual
reattaches here and is consumed normally.

## Review Findings

`gds-code-review`, run against the working tree (HEAD == origin/main == `63631bc`, uncommitted dev
pass) per `PROC/R2`'s two-layer shape -- Blind Hunter and Edge Case Hunter run in parallel; the
Acceptance Auditor's checklist ran INLINE in the main session rather than as a third layer.

**Verdict: 1 DECISION ITEM, 0 PATCHES, 0 findings dismissed.** No HIGH findings. Suite measured
once: 441 state tests / 3439 assertions / 0 failed, 26 integration files all PASS -- matches the Dev
Agent Record's AFTER figures exactly.

- **Blind Hunter**: completed, no stall. 1 finding.
- **Edge Case Hunter**: completed, no stall. 1 finding -- the same defect, found independently.
- **Inline acceptance-auditor checklist**: PASS on every targeted check (`4-2/R17` named-resolution
  and no-substitution; no position/type/kind/priority field on the unit record; `UnitBoard`'s two
  parallel arrays cannot desync -- `add()`/`clear()` always move both together and every writer is
  bound-checked; CONSTRAINT C -- balance read inline, no cached `balance_ticks` reference anywhere
  in the new code; presentation side clean -- no state handle, no signal into state, no new
  `connect_*`, no per-frame allocation (`target_slot_at`/`target_index_at` used, never `target_at`
  in the hot path), no targeting decision on the presentation side; new test files and the new
  integration test are non-vacuous, including `test_minion_authoring.gd`'s deliberate
  sorted-first-disagrees-with-selected proof; snapshot key set is eleven in both pins
  (`test_card_observation.gd`, `test_draw_delay_and_reshuffle.gd`) and `test_data_resources.gd`'s
  `E1_BALANCE_FIELDS` includes `minion_retarget_interval_seconds`). Evidence audit of the Dev Agent
  Record's checkable claims: the 17-row mutation table's M6/M7/M13 rows are backed by real,
  non-tautological guards (read directly, not re-run); `FORMAT_VERSION` untouched at 2;
  `apply_balance` untouched; the observation-seam family adds no `connect_*`/signal (still a poll,
  per the 3b/3c pattern); no reload path or cache mode on the new `data/minions/` loader. The
  golden-chain intermediate hash (`23518ba4`) and AC 9's non-mover claim are internally consistent
  with the shipped `GOLDEN` value and the M1/M2/M3 measurements recorded in
  `test_determinism.gd`'s header, though only the final `73a86005` value and the recorded
  intermediate strings were checked -- the intermediate hashes were not independently re-derived
  (out of scope per PROC/R1's one-suite-run budget).

### [Review][Decision] Step-7 comment overstates a guarantee: a unit CAN acquire a target on its own spawn tick

Both layers converged on this independently. `src/state/match_state.gd:295-296`, the comment
directly above the step-7 seat, states as an unqualified rule: "A unit summoned by THIS tick's
step-6 cast is therefore already on the board when this runs, and acquires its first target at the
next throttle boundary rather than on the spawn tick."

This is false whenever the spawn tick and a throttle boundary coincide. `_retarget_units()`
(`match_state.gd:225-238`) iterates `owner.units.size()` -- which already includes a unit appended
moments earlier in the same tick's step 6 -- with no exclusion for units added this tick. Whenever
`_tick % minion_retarget_interval_ticks == 0` on the summon tick itself, the new unit acquires a
target immediately, same-tick. This isn't hypothetical: `test_replay_identity.gd`'s own new comment
documents exactly this happening at its recorded cast tick (interval clamped to 1, "the unit
therefore acquires the opposing hero on t20 itself"), and the golden fixture's
`RETARGET_INTERVAL_TICKS := 23` was deliberately chosen so the t22 cast tick is NOT a multiple of
23 -- i.e., the golden fixture was tuned specifically to avoid exercising the coincidence the
step-7 comment says can't happen. With the shipped authored cadence (12 ticks, from the 0.2s
`data/balance/balance_config.tres` value), any real-play summon landing on a tick divisible by 12
hits the same coincidence.

Not a crash, not a determinism/replay hazard (both paths are still hashable and replay-safe), and
not a violation of any stated AC or ruling -- nothing in `4-2/R1`-`R17` requires "never on the spawn
tick." It's a documentation/invariant-accuracy defect: the comment asserts a guarantee the code
does not provide, and `4-3` (which builds movement/HP consequences on top of this same target
state) could reasonably rely on that stated guarantee being true. Also untested either way: every
throttle test in `test_targeting_service.gd` summons via the `_summon()` test helper (which appends
directly to `player.units`, bypassing `advance()`'s step 6) before any `_advance()` call, so no test
exercises a real step-6 cast landing on a boundary tick within the same `advance()` invocation.

**This needs Matko's ruling, not a mechanical patch**, because the fix is a choice between two
different intended behaviors: (a) the comment is simply wrong and should be corrected to describe
the actual (harmless) behavior, or (b) the comment states the intended contract and the code should
skip newly-added units for this tick's evaluation, deferring their first acquisition to the next
boundary as documented. Both are legitimate designs; nothing already ruled picks one.

**RESOLVED, `4-2/R18` (operator ruling, this session): option (a). The comment is wrong; the
behaviour stays.** A unit acquiring a target on its spawn tick when that tick is a throttle
boundary is the better behaviour -- more responsive, and 4-3 builds movement and combat on this
same target. Deferring it would need per-tick "added this tick" tracking with no gameplay reason
behind it -- machinery without a consumer, which this project refuses. Shipped:
1. `src/state/match_state.gd:295-299` (the step-7 seat comment) rewritten to state the actual
   behaviour POSITIVELY: a unit summoned by this tick's step-6 cast is already on the board when
   step 7 runs, so if this tick IS a throttle boundary it acquires immediately, in the same
   `advance()` call; otherwise it acquires at the next boundary. A Dev Note was added alongside it
   recording that `test_targeting_service.gd`'s `_summon()` helper bypasses step 6 and cannot
   exercise either half of this.
2. A named pair added to `test/state/test_targeting_service.gd`, both driven through a REAL step-6
   cast (`_match_for_cast`, the `test_card_effect_resolution.gd` deck/costs/effects shape, not
   `_summon()`): `test_a_same_tick_summon_acquires_a_target_when_its_cast_tick_is_a_boundary` (cast
   tick 2, interval 2 -- the unit holds an acquired target at the END of that same `advance()`
   call) and `test_a_same_tick_summon_waits_for_the_next_boundary_when_its_cast_tick_is_not_one`
   (cast tick 2, interval 5 -- the unit holds no-target until it is later advanced to tick 5, where
   it acquires).

No behaviour change. Suite run once after: 443 state tests / 3450 assertions / 0 failed, 26
integration files all PASS (delta from the review's 441/3439: +2 state tests, +11 assertions). The
golden was asserted, not re-baselined -- `73a86005` unmoved.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 -- authoring pass, 2026-08-10.
Claude Opus 5 (1M context) -- dev pass, 2026-08-10, via `gds-dev-story`.

### Debug Log References

Suite BEFORE (measured at open): **399 state tests / 2517 assertions / 0 failed**, plus **25
integration files, all PASS** (`bash test/run_all.sh`, exit 0). `GOLDEN` read from
`test_determinism.gd:336` as `78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5`;
per-player snapshot key set read by content as **ten** keys.

> **Correction to the pass's stated BEFORE values.** The brief gave "24 integration"; the measured
> count is **25** integration files (`ls test/integration/test_*.gd`). AFTER is 26 -- one file added
> by this story, not two.

Suite AFTER (measured at close): **441 state tests / 3439 assertions / 0 failed**, plus **26
integration files, all PASS** (`bash test/run_all.sh`, exit 0). Delta +42 state tests,
+922 assertions, +1 integration file.

**Editor scan (`3-0c/R13`, run IN this pass, not deferred to the chain).** Two runs of
`godot --headless --editor --quit --path .`: the first after the `class_name` files existed
(registered `MinionPriority` and `TargetingService`, printed in the `update_scripts_classes` step),
the second after the new test files existed. `project.godot` SHA256 was
`8879DE490EDDA78051595F189FB9BB6F2E75384FEBAFF142C8958EC107970004` before the first scan and
**unchanged after both** -- no autoload, Input Map or main-scene collateral. Per-diff collateral check:
the only files either scan produced are `.uid` siblings, listed in the File List below.

**`.uid` finding, and it CORRECTS the known gap carried from the 4-1 chain.** The gap was recorded as
"the scan generates `.uid` siblings only for `class_name` files, NOT for plain `.gd` test scripts".
Measured here, that is not the mechanism: it is an ORDERING artefact. After the first scan the two
`class_name` files had `.uid` siblings and the four new test scripts had none -- because the test
scripts did not yet exist when that scan ran. A second scan, with every file present, generated all
four (`test_minion_priority.gd.uid`, `test_minion_authoring.gd.uid`, `test_targeting_service.gd.uid`,
`test_unit_aim_live.gd.uid`), matching the repo's existing convention that every `test_*.gd` carries
one. The practical rule is therefore "scan LAST, after every new `.gd` exists", not "test scripts
never get a `.uid`".

### Completion Notes List

**AC-by-AC.** AC 1 -- `MinionPriority` authored as a pure parametric schema
(`src/state/resources/minion_priority.gd`), `target_side` / `prefer_hero` / `ordering_mode` /
`priority_name`; two `.tres` authored (`standard`, `hero_seeker`); `Tank`/`Bomber` deferred, and the
deferral is stated at the enum members that would carry them. AC 2 -- `TargetingService` is a fully
static, stateless sibling under `src/state/targeting/` (`4-2/R12`), taking plain facts rather than a
`PlayerState`, so "touches no board" is structural. AC 3 -- directory scan, sorted, non-rule entries
skipped, missing directory degrades to empty; loaded once, no reload path and no cache mode
(`4-2/R9`). AC 4 -- (a) is a ruling about review burden and is not asserted as a measurement; (b)
ships as `test_minion_authoring.gd`. AC 5 -- gated on injected `FeatureFlags.minions`, ON/OFF/absent
all covered, at the evaluator AND through the real step-7 seat. AC 6 -- four named returned reasons,
no `Invariant.check` anywhere in the evaluator (scanned); the missing/unrecognized reason is reachable
three ways from authored data. AC 7 -- shared `_tick % interval` throttle at step 7, both halves of
the named pair shipped (positive acquisition; behavioural negative changing the candidate set
mid-interval). AC 8 -- opposing side only, slot-then-index ascending, determinism asserted. AC 9 --
`UnitBoard` is an ordered collection whose identity is the board index; measured a golden and key-set
NON-MOVER on its own. AC 10 -- replay parity green, `FORMAT_VERSION` untouched at 2, and
`test_replay_identity.gd` now asserts its recorded run actually acquires a target so the coverage is
named rather than incidental. AC 11 -- `unit_targets` ships as `[slot, index]` int pairs.

**Live Smoke: PENDING OPERATOR.** Not closed by this pass. The machine half is shipped and green
(`test/integration/test_unit_aim_live.gd`: the grey box's yaw matches a yaw recomputed from the two
node positions, with both non-vacuity halves asserted), and the presentational rotation itself is in
`UnitActor.aim_at()` plus the runner's step 3d. The human half -- legibility, the candidate-set change
at a boundary, flag-off degradation, and the `R-D6` two-human kill acceptance -- is the operator's.

**`4-2/R17` (operator ruling, this session).** Recorded in Dev Notes above with its full reasoning,
for the close-out chain to carry into the decision-log. Summary: `Standard` governs every unit,
resolved by an explicit named constant from the sorted set; `Hero-Seeker` is authored but TEST-ONLY;
per-unit priority choice is forced at 4-3/4-4, which is also the only story allowed to add a field to
the unit record. No type or priority field was added to the record in this pass.

**Two corrections to the story's own predictions, both measured rather than argued.**
1. The Golden Prediction expected an unauthored `_golden_config()` cadence to measure a FALSE
   NON-MOVE. It does not. `4-2/R5`(d)'s clamp makes an unauthored 0.0 derive to 1 tick, i.e. "every
   tick", so the target is acquired anyway -- unauthored and authored-at-23 hash IDENTICALLY
   (`73a86005` both ways). The cadence VALUE is hash-neutral for this fixture and cannot be
   otherwise: the hash sees only the final snapshot, the acquired pair is the same whichever boundary
   produced it, and this fixture's candidate set never changes. What authoring the cadence actually
   buys is that the golden sits on the THROTTLED path rather than the every-tick one. The throttle's
   TIMING is proven where it can be, in `test_targeting_service.gd`'s behavioural negative. Full
   reasoning is at `RETARGET_INTERVAL_TICKS` in `test_determinism.gd`.
2. AC 1's "new priority types addable with zero code changes" was already corrected by `4-2/R16`;
   this pass adds the concrete consequence that an `ordering_mode` vocabulary of one member is the
   honest shape today, because the deferred modes (nearest, lowest-HP) need facts 4-3 ships. Named at
   the enum rather than left implicit.

**Golden chain -- ONE re-baseline, `78bd2b97` -> `73a86005`, four measurements.** Each cause isolated
on its own, in the order below; the full record is in `test_determinism.gd`'s header.

| # | What was in place | Hash | Verdict |
|---|---|---|---|
| M0 | inherited baseline | `78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5` | -- |
| M1 | **AC 9 identity extension ALONE** -- `UnitBoard` reshaped to an ordered collection with per-unit target storage; `to_snapshot()` untouched | `78bd2b97...b0b5e5` | **NON-MOVER, measured** (`4-2/R8` confirmed). Not vacuous: the fixture's t22 cast appends a record and the record carries its no-target pair -- it is simply not hashed yet |
| M2 | **+ cause (a), snapshot shape** -- `unit_targets` key ships; step-7 tick NOT yet wired, so no unit could acquire anything and the key entered at an all-no-target value | `23518ba4b39c5cd5b70be9b304d8254f4d16a2506c84fd2e9165933f8a3ca922` | **MOVER** (isolated by construction, the 4-1 cause-1 method) |
| M3a | **+ step-7 tick wired, cadence UNAUTHORED** in `_golden_config()` (derives to 1 tick) | `73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5` | measured to isolate the cadence VALUE |
| M3 | **+ cause (b), behavioural** -- `RETARGET_INTERVAL_TICKS = 23` authored, so the unit summoned at t22 acquires `[1, -1]` at the t23 boundary and still holds it at the hashed t24 | `73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5` | **MOVER vs M2** (`23518ba4` -> `73a86005`); **identical to M3a**, which is finding 1 above |

Both directions: M1 vs M0 is the non-mover in both (adding the extension leaves `78bd2b97`); M2's key
removed returns to M1 (mutation M13 below); M3's behaviour suppressed returns to the no-target value
(the `NO_BOUNDARY_INTERVAL_TICKS = 7` pair inside
`test_the_throttled_targeting_consumes_no_rng`).

**The two predicted NON-MOVERS, each confirmed with a non-vacuous pair rather than assumed.**
(i) AC 9's identity extension -- M1 above, and the key set held at ten at that step. (ii) `rng_state`
-- `test_the_throttled_targeting_consumes_no_rng`, built on the
`test_the_summon_consumes_no_rng` shape: same fixture, same cast, same summon, differing ONLY in
whether the cadence ever reaches a boundary while the unit exists (23 vs 7). The acquired target is
asserted to DIFFER across the pair (`[[1,-1]]` vs `[[-1,-1]]`) so the `rng_state` equality cannot be
vacuous.

**Snapshot key-set pin: TEN -> ELEVEN, moved deliberately in BOTH places that carry it.** There are
two independent pins, and the second was found by the closing suite run rather than by reading:
`test_card_observation.gd` (`test_the_observation_channel_adds_no_snapshot_key`, which also gained a
separate `keys.size() == 11` assertion so the COUNT is a named quantity in its own right) and
`test_draw_delay_and_reshuffle.gd` (`EXPECTED_PLAYER_SNAPSHOT_KEYS`). A third guard,
`test_data_resources.gd`'s reflection-based `E1_BALANCE_FIELDS` completeness check, also failed on the
new `BalanceConfig` field and was extended. All three failing BEFORE they were updated is their own
non-vacuity proof, recorded as rows M15-M17 below.

**Mutation table.** Every row: the file backed up OUTSIDE the repo (scratchpad) and SHA256'd, ONE
byte-level mutation applied, ONLY the affected test file run (`PROC/R1`), restored by COPYING THE
BACKUP BACK (never `git checkout --`), and the SHA re-verified against the pre-mutation value.
Provenance per row is the claim the mutation attacks. Every row FELL.

| # | File mutated | Mutation (the claim it attacks) | Test file run | Verdict | Restore |
|---|---|---|---|---|---|
| M1 | `src/state/targeting/targeting_service.gd` | AC 8 / AC 1 -- `prefer_hero` branch INVERTED | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M2 | `src/state/targeting/targeting_service.gd` | AC 8 -- tie-break takes the LAST unit index instead of ascending-first | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M3 | `src/state/targeting/targeting_service.gd` | AC 5 -- flag/data ORDER reversed (data consulted before the flag) | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M4 | `src/state/targeting/targeting_service.gd` | AC 6 -- `ordering_mode` vocabulary check removed (any authored int accepted) | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M5 | `src/state/targeting/targeting_service.gd` | AC 5 -- no flags injected treated as OPEN instead of closed | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M6 | `src/state/targeting/targeting_service.gd` | `4-2/R17`(1) -- `priority_named` FALLS BACK to the sorted-first rule instead of returning null | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M7 | `src/state/match_state.gd` | AC 7 -- THROTTLE REMOVED (step 7 runs every tick) | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M8 | `src/state/match_state.gd` | `4-2/R3` -- OWN slot passed as the candidate side instead of the opposing one | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M9 | `src/state/timing/balance_ticks.gd` | `4-2/R5`(d) -- the `>= 1` tick CLAMP removed from the conversion boundary | `test_balance_config.gd` | **FAIL** | restored, SHA verified |
| M10 | `src/state/unit_board.gd` | `3-0c/R15` -- the public bound predicate WIDENED (upper bound dropped) | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M11 | `src/state/unit_board.gd` | `3-0c/R15` -- one guard RE-DERIVES the bound inline instead of consulting the predicate | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M12 | `src/state/unit_board.gd` | AC 7 -- `set_target_at` also APPENDS, so targeting changes the board length | `test_targeting_service.gd` | **FAIL** | restored, SHA verified |
| M13 | `src/state/player_state.gd` | AC 11 -- the `unit_targets` snapshot key removed | `test_card_observation.gd` | **FAIL** | restored, SHA verified |
| M14 | `src/main/match_runner.gd` | `4-2/R13` -- the runner's AIM step removed (state targets, nothing renders it) | `test_unit_aim_live.gd` (integration) | **FAIL** | restored, SHA verified |
| M15 | -- | AC 11 -- the real key addition, against `test_draw_delay_and_reshuffle.gd`'s SECOND key-set pin | `test_draw_delay_and_reshuffle.gd` | **FAIL** (observed live, before the pin was moved) | n/a -- the change is the shipped one |
| M16 | -- | AC 11 -- the real key addition, against `test_card_observation.gd`'s pin | `test_card_observation.gd` | **FAIL** (observed live, before the pin was moved) | n/a -- the change is the shipped one |
| M17 | -- | AC 7 -- the real `BalanceConfig` field, against `test_data_resources.gd`'s reflection completeness check | `test_data_resources.gd` | **FAIL** (observed live, before the list was extended) | n/a -- the change is the shipped one |

**M6 is worth reading as a finding, not just a row.** On its FIRST run it PASSED -- a `priority_named`
that silently substituted the sorted-first rule survived every test in the pass, because every test
asked for a name that exists. That made `4-2/R17`'s "never silently substitute another rule" an
unguarded claim, and a violation of it would have changed which priority governs the entire game with
nothing failing. `test_an_absent_priority_name_resolves_to_null_never_to_another_rule` was added in
response and M6 then fell. The mutation harness found this; reading did not.

**Not touched, deliberately.** `apply_balance` (`4-2/R5`(b) -- no per-player injection seat for the
cadence); `FORMAT_VERSION`, still 2 (`4-2/R7`); `IntentRecorder` and its channels; the eight-seam
observation family (`4-2/R15`'s own stated consequence -- the aim step is a POLL in the step-3b/3c
family, no `connect_*`); `data/cards/`; `test_architecture_invariants.gd`.

**Pre-existing defect noticed, NOT fixed (out of scope).** `test_determinism.gd`'s header carries a
truncated, duplicated fragment of the 4-0 re-baseline record (two lines beginning "Re-baselined by
STORY 4-0 ... reproduced in both" that run straight into the 4-1 heading, with the complete 4-0 record
appearing again further down). It is comment-only and predates this pass; the 4-2 record was inserted
above it rather than reflowing it. Flagged for the close-out chain.

### File List

**New -- source (2 files + 2 `.uid`)**
- `src/state/resources/minion_priority.gd` (+ `.uid`)
- `src/state/targeting/targeting_service.gd` (+ `.uid`)

**New -- authored content (2)**
- `data/minions/standard.tres`
- `data/minions/hero_seeker.tres`

**New -- tests (4 files + 4 `.uid`)**
- `test/state/test_minion_priority.gd` (+ `.uid`)
- `test/state/test_minion_authoring.gd` (+ `.uid`)
- `test/state/test_targeting_service.gd` (+ `.uid`)
- `test/integration/test_unit_aim_live.gd` (+ `.uid`)

**Modified -- source (6)**
- `src/state/match_state.gd` -- step 7's seat filled: `_update_unit_targets()` / `_retarget_units()`
- `src/state/player_state.gd` -- the `unit_targets` snapshot key
- `src/state/unit_board.gd` -- identity extension, target storage, `has_index()` predicate
- `src/state/resources/balance_config.gd` -- `minion_retarget_interval_seconds`
- `src/state/timing/balance_ticks.gd` -- `minion_retarget_interval_ticks` + the `>= 1` clamp
- `src/actors/minions/unit_actor.gd` -- `aim_at()`, presentational only
- `src/main/match_runner.gd` -- step 3d aim poll, `_aim_unit_actors()`, `_target_world_position()`

**Modified -- authored content (1)**
- `data/balance/balance_config.tres` -- `minion_retarget_interval_seconds = 0.2`

**Modified -- tests (7)**
- `test/state/test_determinism.gd` -- golden re-baseline + record, `RETARGET_INTERVAL_TICKS`, cadence
  authored in `_golden_config()`, two new tests, `_make_match_with_retarget_interval()`
- `test/state/test_card_observation.gd` -- key-set pin ten -> eleven + a separate count assertion
- `test/state/test_draw_delay_and_reshuffle.gd` -- the second key-set pin
- `test/state/test_data_resources.gd` -- `E1_BALANCE_FIELDS` completeness
- `test/state/test_balance_config.gd` -- derivation + clamp (both directions)
- `test/state/test_balance_authoring.gd` -- authored cadence band audit
- `test/state/test_replay_identity.gd` -- member classification for the reshaped board,
  `targeting_service` exempt, plus the AC 10 coverage assertion

**Story file** -- `docs/implementation-artifacts/4-2-minion-ai-throttled-targeting.md` (permitted
sections, plus two operator-directed edits: the `4-2/R17` Dev Notes entry and the TEST-ONLY wording on
the `.tres` task line).

NO COMMITS were made; the tree is left dirty by design for the close-out chain.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-10 | 0.1 | Story authored against the E4 ratification (`E4-P/R1`, `E4-P/R2`, `E4-P/R5`, `E4-P/R6`, `E4-P/R7`, `E4-P/R9`) and 4-1's discharged obligations (`4-1/R12`, `unit_board.gd`'s reserved header). Ten ACs covering `MinionPriority` (D6 schema), `TargetingService` (D6 sibling evaluator), directory-scan loading, golden discipline, feature-flag gating, named no-target outcomes, the throttled `advance()` step-7 seat, deterministic tie-break, `UnitBoard` identity extension, and replay parity. Two Open Questions (unit position ownership; throttled-tick vs `Area3D`) presented with full evidence and deliberately NOT decided, reserved for this story's own readiness gate. Golden Prediction states expected causes in both directions, none asserted as measured. Status `authored`, awaiting operator review. | Claude Sonnet 5 |
| 2026-08-10 | 0.2 | Readiness gate rulings `4-2/R1`-`4-2/R16` applied (operator-ratified). AC 1 restated PARAMETRIC (two authored `.tres`, Tank/Bomber deferred); AC 4 restated on the `4-1/R4` by-ruling template; AC 7 fixes all four parts of the balance-authored cadence; AC 8 fixes the candidate set (opposing side only) and THE tie-break (slot then index); AC 9 gains the measured non-mover finding; AC 10 discharged by `4-2/R14`'s deferral (`FORMAT_VERSION` stays 2) plus the named residual replay hazard; new AC 11 states the hashed `[slot, index]` target representation. Deferred section corrected: minion MOVEMENT is out, owned by 4-3, with the two shipped ownership comments re-pointed (separate commit). Both Open Questions rewritten as RULED: Open Question 1 deferred again to 4-3 with movement as the forcing point (not a second can-kick); Open Question 2 ruled a shared throttled tick inside `advance()`, `Area3D` rejected by name. Tasks rewritten with a named falsifiable test per AC, the `4-2/R6` positive/negative pair, the snapshot-pin task, and the `src/state/targeting/` path (`4-2/R12`, corrected off `economy/`). Dev Notes amended (not replaced): `4-2/R9` DEBT B note, `4-2/R10` citation correction plus the live `3-0d/R21` gotcha, the observation-seam paragraph marked MOOT per `4-2/R15` with its reasoning kept. Golden Prediction rewritten: two named MOVERS (snapshot-shape from the target key, behavioural from an acquired throttled target), AC 9's identity extension confirmed a separate non-mover, `rng_state` still predicted non-mover. Live Smoke rewritten per `4-2/R13`: the grey box rotates to face its acquired target, purely presentational, no new observation seam; `R-D6` re-invoked. Status `authored` -> `ready-for-dev`. | Claude Sonnet 5 |
| 2026-08-10 | 0.4 | **Review resolution** (`4-2/R18`, operator ruling). Resolved the review's single decision item: the step-7 seat comment overstated a guarantee (falsely claiming a same-tick-summoned unit never acquires before the next boundary). Ruled the comment wrong and the behaviour right -- a same-tick acquisition when the spawn tick is itself a boundary is more responsive and is what 4-3 builds on; deferring it would add per-tick tracking machinery with no consumer. `match_state.gd`'s step-7 comment rewritten positively, with a Dev Note on `_summon()`'s step-6 bypass; a named pair of tests added to `test_targeting_service.gd`, driven through a real step-6 cast (`_match_for_cast`), covering both the same-tick-boundary acquisition and the wait-for-next-boundary case. No behaviour change. Suite 441/3439 -> **443 state tests / 3450 assertions / 0 failed**, 26 integration files all PASS; golden asserted unmoved at `73a86005`. No commits; tree left dirty for the close-out chain. Status unchanged (`review`). | Claude Sonnet 5 |
| 2026-08-10 | 0.3 | **Dev pass** (`gds-dev-story`). Implemented `MinionPriority` (parametric D6 schema), `TargetingService` (static D6 sibling under `src/state/targeting/`, directory-scan loader, opposing-side-only candidate set, slot-then-index tie-break, four named returned outcomes), the `UnitBoard` identity extension (ordered collection, board index as identity, per-unit `[slot, index]` target storage, `has_index()` predicate), the `minion_retarget_interval_seconds` / `_ticks` pair with the `>= 1` clamp at the conversion boundary, two authored `data/minions/*.tres`, the step-7 shared throttled tick in `MatchState.advance()`, the `unit_targets` snapshot key, and the presentational `UnitActor.aim_at()` + runner aim poll the live smoke needs. Operator ruling **`4-2/R17`** recorded in Dev Notes (Standard governs all units, resolved by named constant; Hero-Seeker authored but TEST-ONLY; per-unit priority choice forced at 4-3/4-4). Golden re-baselined ONCE, `78bd2b97` -> `73a86005`, with four measurements isolating each cause: AC 9's identity extension measured a NON-MOVER alone, the snapshot-shape cause `78bd2b97` -> `23518ba4`, the behavioural cause `23518ba4` -> `73a86005`; `rng_state` confirmed a non-mover against a non-vacuous pair. TWO of the story's own predictions CORRECTED by measurement: the unauthored cadence does NOT measure a false non-move (the clamp makes it 'every tick', hashing identically to the authored value), and the cadence VALUE is hash-neutral for this fixture. Snapshot key set ten -> eleven, moved deliberately in BOTH pins that carry it plus the reflection field-list guard. 17-row mutation table with per-row provenance, every row falling; M6 exposed an unguarded `4-2/R17` claim and a test was added in response. Suite 399/2517 -> **441 state tests / 3439 assertions / 0 failed**, 25 -> 26 integration files, all PASS. Live Smoke is PENDING OPERATOR (machine half shipped and green in `test_unit_aim_live.gd`). No commits; tree left dirty for the close-out chain. Status `ready-for-dev` -> `review`. | Claude Opus 5 (1M context) |
