---
baseline_commit: b95613b64e2502653d82d2e556b7c12d0f279453
---

# Story 4.2: Minion AI and throttled targeting

Status: ready-for-dev

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

- [ ] Author `MinionPriority` (`src/state/resources/minion_priority.gd`), the D6 schema precedent,
      PARAMETRIC per `4-2/R16` (target side, prefer-hero, ordering mode fields) -- test:
      `test_minion_priority.gd` asserts the schema loads and exposes those parameters (AC: 1)
- [ ] Author exactly TWO `data/minions/*.tres` files -- `Standard` and `Hero-Seeker` (`4-2/R16`;
      `Tank` and `Bomber`/AoE are named-deferred, not authored) -- test: an authoring test in the
      `test_balance_authoring.gd` family asserting every `.tres` in `data/minions/` loads as a
      `MinionPriority` and carries recognized parameters (AC: 1, 4)
- [ ] Write `TargetingService` (`src/state/targeting/targeting_service.gd` -- `4-2/R12`, NOT under
      `economy/`), the directory-scan loader, and the deterministic tie-break (opposing side only,
      slot-then-index order, `4-2/R3`) -- test: `test_targeting_service.gd` covering the loader,
      the candidate-set restriction, and the tie-break order (AC: 2, 3, 8)
- [ ] Extend `UnitBoard`/`PlayerState.units` with per-unit identity (position stays OUT, `4-2/R14`
      defers it to 4-3) -- test: `test_targeting_service.gd` or `test_unit_board.gd` asserting the
      identity is stable and addressable, and a golden/key-set measurement confirming the
      NON-MOVER prediction (`4-2/R8`) (AC: 9)
- [ ] Author `minion_retarget_interval_seconds` (`BalanceConfig`) and derived
      `minion_retarget_interval_ticks` (`BalanceTicks`), on the `draw_replacement_delay_seconds`
      precedent, clamped to >= 1 tick (`4-2/R5`) -- test: `test_balance_config.gd`/
      `test_balance_ticks.gd` covering the derivation and the clamp at an authored 0 (AC: 7)
- [ ] `_golden_config()` authors a real, non-degenerate retarget cadence, on the
      `DRAW_DELAY_TICKS` precedent (`4-2/R5`) -- otherwise the throttle measures a false non-move;
      this is a task, not a hope (AC: 7, Golden Prediction)
- [ ] Wire the throttled evaluation into `MatchState.advance()` step 7's reserved seat
      (`match_state.gd:279`), the ruled shared in-`advance()` tick (`4-2/R15`), storing the
      `[slot, index]` verdict (`4-2/R2`) -- test, as a NAMED PAIR (`4-2/R6`): (a) the POSITIVE
      direction -- a target IS acquired against a populated opposing candidate set (a test that
      only ever asserts "no target" passes vacuously and does not satisfy this); (b) a BEHAVIOURAL
      NEGATIVE -- change the candidate set mid-interval and confirm the applied target does NOT
      change until the throttle's boundary tick, and DOES change at it (not instrumentation
      counting calls) (AC: 7, 8, 11)
- [ ] Gate targeting on `FeatureFlags.minions`; matrix-test ON/OFF -- test: a flag-off unit never
      acquires a target, on the 4-1 gating precedent (AC: 5)
- [ ] Assert the authored `data/minions/` priority set loads NON-EMPTY under the headless harness
      (`4-2/R11`) -- AC 3's graceful-degradation-on-missing-directory clause means a silent load
      failure would otherwise look like a passing test (AC: 3)
- [ ] Update or assert the snapshot key-set pin (`test_card_observation.gd`, find by content) --
      it moves when `4-2/R2`'s target key ships (`4-2/R6`) (AC: 9, 11)
- [ ] Golden re-baseline: measure and separate the TWO separately-named causes this story predicts
      (snapshot-shape, from `4-2/R2`'s key; behavioural, from a throttled target actually being
      acquired), each in both directions, exactly as every prior multi-cause re-baseline in this
      project has, per the Golden Prediction below (AC: 4, 11)
- [ ] Replay parity coverage for the shared in-`advance()` throttled tick (`4-2/R15`) -- extend
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

Not yet run -- populated at the code-review pass.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 -- authoring pass, 2026-08-10.

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-10 | 0.1 | Story authored against the E4 ratification (`E4-P/R1`, `E4-P/R2`, `E4-P/R5`, `E4-P/R6`, `E4-P/R7`, `E4-P/R9`) and 4-1's discharged obligations (`4-1/R12`, `unit_board.gd`'s reserved header). Ten ACs covering `MinionPriority` (D6 schema), `TargetingService` (D6 sibling evaluator), directory-scan loading, golden discipline, feature-flag gating, named no-target outcomes, the throttled `advance()` step-7 seat, deterministic tie-break, `UnitBoard` identity extension, and replay parity. Two Open Questions (unit position ownership; throttled-tick vs `Area3D`) presented with full evidence and deliberately NOT decided, reserved for this story's own readiness gate. Golden Prediction states expected causes in both directions, none asserted as measured. Status `authored`, awaiting operator review. | Claude Sonnet 5 |
| 2026-08-10 | 0.2 | Readiness gate rulings `4-2/R1`-`4-2/R16` applied (operator-ratified). AC 1 restated PARAMETRIC (two authored `.tres`, Tank/Bomber deferred); AC 4 restated on the `4-1/R4` by-ruling template; AC 7 fixes all four parts of the balance-authored cadence; AC 8 fixes the candidate set (opposing side only) and THE tie-break (slot then index); AC 9 gains the measured non-mover finding; AC 10 discharged by `4-2/R14`'s deferral (`FORMAT_VERSION` stays 2) plus the named residual replay hazard; new AC 11 states the hashed `[slot, index]` target representation. Deferred section corrected: minion MOVEMENT is out, owned by 4-3, with the two shipped ownership comments re-pointed (separate commit). Both Open Questions rewritten as RULED: Open Question 1 deferred again to 4-3 with movement as the forcing point (not a second can-kick); Open Question 2 ruled a shared throttled tick inside `advance()`, `Area3D` rejected by name. Tasks rewritten with a named falsifiable test per AC, the `4-2/R6` positive/negative pair, the snapshot-pin task, and the `src/state/targeting/` path (`4-2/R12`, corrected off `economy/`). Dev Notes amended (not replaced): `4-2/R9` DEBT B note, `4-2/R10` citation correction plus the live `3-0d/R21` gotcha, the observation-seam paragraph marked MOOT per `4-2/R15` with its reasoning kept. Golden Prediction rewritten: two named MOVERS (snapshot-shape from the target key, behavioural from an acquired throttled target), AC 9's identity extension confirmed a separate non-mover, `rng_state` still predicted non-mover. Live Smoke rewritten per `4-2/R13`: the grey box rotates to face its acquired target, purely presentational, no new observation seam; `R-D6` re-invoked. Status `authored` -> `ready-for-dev`. | Claude Sonnet 5 |
