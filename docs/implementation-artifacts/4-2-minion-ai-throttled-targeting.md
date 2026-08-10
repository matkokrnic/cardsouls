---
baseline_commit: b95613b64e2502653d82d2e556b7c12d0f279453
---

# Story 4.2: Minion AI and throttled targeting

Status: authored

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
   directory listing). Fields name a priority TYPE (`Standard`, `Hero-Seeker`, `Tank`,
   `Bomber`/AoE per `epics.md`) plus whatever selection parameters that type needs -- never a
   gameplay NUMBER baked in if a shared balance field already owns it (the `ResourceGenerationRule`
   `amount_field` precedent). New priority types are addable via a new `.tres` in `data/minions/`,
   zero code changes.
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
4. **`MinionPriority` `.tres` content joins golden discipline, treated as code
   (`E4-P/R6`, narrowing `BC/R3`, the `3-4/R6` precedent).** Unlike `data/balance/`, this content
   is load-bearing for the golden hash once a unit exists on the golden fixture's board and the
   `minions` flag is on -- the same standing property `data/economy/*.tres` already carries
   (project-context.md, "Golden isolation"). This is a RULING about review burden and a measured
   golden dependency together, not a claim of an unmeasured shift -- see Golden Prediction.
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
   a shared, throttled tick (e.g. re-target every ~0.1-0.25 s)." The cadence value is
   balance-authored (never a hardcoded literal), on the `TimingWindow`/A1 integer-tick precedent
   if the gate rules the tick shape (Open Question 2). `MatchState.advance()` already reserves the
   seat: step 7, `match_state.gd:279`, currently the literal comment
   `[E4 minion/totem throttled-tick seam]`.
8. **Target selection is deterministic under a fixed candidate set and a fixed tie-break rule**,
   stated and tested explicitly -- ties never resolve by iteration order over a `Dictionary` or by
   `Array[StringName].sort()`'s internal-pointer ordering (the measured hazard this codebase names
   repeatedly). The tie-break is cast order or an equivalent stable, authored ordering.
9. **`UnitBoard` gains the identity content its own header reserves for this story's consumer**
   (`unit_board.gd:29`: "`4-2`'s gate rules on position ownership with `TargetingService` as a
   real consumer; whatever content a unit then needs is added THERE, against something that reads
   it"). At minimum a stable per-unit identity TargetingService can address survives 4-1's
   count-only shape -- what else a record carries (position, owner side, priority-type reference)
   is bounded by Open Questions 1 and 2 below, not decided by this AC. This is a necessary
   consequence of AC 2 having a real thing to select FROM, not a scope choice.
10. **Replay parity holds for whichever mechanism the gate selects (Open Question 2).** If the
    gate rules a shared in-`advance()` throttled tick: it is hashable by construction and needs no
    new recorder channel (the `IntentRecorder` content-channel package is untouched). If the gate
    rules `Area3D` overlap queries (or a mix): the query result crosses into state exactly like a
    contact fact does (`push_contact`, the `_gather_contact_facts` precedent) and the recorded
    fact -- not the query -- is what replay reproduces. Either way, `test_replay_identity.gd`'s
    coverage extends to whatever new state this story adds, and a driven run replays to a
    bit-identical hash.

## Deferred / Out of scope

- **Minion combat** (4-3) -- a unit that acquires a target does not damage it. No HP, no attack
  resolution, no death consequence for a targeted unit this story. Whatever an "engage" outcome
  from `TargetingService` implies for a unit's approach/movement, it stops short of a hit.
- **Totems** (4-4) -- `MinionPriority` targets active board units; totem-specific
  behaviour (e.g. a totem's own targeting exemption, or being itself a valid Bomber/AoE candidate)
  is not authored or tested here beyond whatever falls out of the totem clause's positionless,
  type/kind-less unit records still holding at this story's start.
- **Object pooling / performance** (4-5) -- units and any targeting-support nodes stay plain
  instantiated/freed content this story; 4-5's tier and failure criterion are still undecided
  (`E4-P/R8`), owned by 4-1's close-out, not reopened here.
- **Real per-priority-type tuning values** beyond what is needed to prove all four named types
  (`Standard`, `Hero-Seeker`, `Tank`, `Bomber`/AoE) select distinguishably -- playtest-grade
  balancing of aggro ranges, AoE clump thresholds, etc. is iteration work, not this story's gate.

## Open Questions -- reserved for THIS story's readiness gate

### Open Question 1 -- Where does a unit's position live?

**Deferred here from `4-1/R12` (`E4-P/R7`), which is now discharged**: 4-1 shipped `UnitBoard`
positionless by ruling, naming this story's gate as the place a real consumer (`TargetingService`)
exists to force the decision, rather than let it default to whatever seemed convenient when no
consumer did.

**The measured precedent, unchanged since 4-1's own readiness gate:** `hero_state.gd:5` states
outright, "Pure RefCounted -- no scene, no Input, no position (position is actor-owned, F1)."
`HeroState` owns `velocity`, `facing`, `roll_direction` -- intent/derived quantities -- never a
position. `match_runner.gd:_gather_contact_facts` (line 729) reads `actor.global_position`
directly off the scene node and pushes only a DERIVED fact into state via `push_contact`; position
itself never crosses into `src/state/`.

**Two named futures, carried forward verbatim in substance from `4-1/R12`'s Dev Notes:**
(a) an INWARD position/distance channel -- the runner (or a per-unit actor) derives whatever fact
`TargetingService` actually needs (e.g. "nearest enemy unit id and its distance band") from
`global_position` reads off scene nodes, and pushes that fact into state on the
`push_contact`/`_gather_contact_facts` shape, so `TargetingService` itself never sees a raw
`Vector3`; vs.
(b) STATE-OWNED floats reaching the hash directly on the unit record -- a new architectural
asymmetry against the hero precedent, not a forced choice, but one that would let
`TargetingService` compute distances itself without a per-tick derived-fact relay.

**Why this story's gate, not 4-1's or a later one:** `TargetingService` is the first real
consumer that needs to ask "how far / who is nearest," which is exactly the question 4-1 had no
consumer to answer honestly. AC 9 above extends `UnitBoard` with identity; it deliberately does
NOT extend it with position, leaving that choice to this ruling.

### Open Question 2 -- Throttled tick vs. `Area3D` overlap queries

**This is a determinism question, not a performance one (`E3-R/R5.2`, `E4-P/R7`).** `epics.md`'s
own wording -- "throttled tick (~0.1-0.25 s) **and/or** `Area3D` overlap queries" -- hides that
the two are not interchangeable implementations of the same seam; they place the targeting fact
on OPPOSITE SIDES of the state/visual seam:

- A shared throttled tick evaluated INSIDE `advance()` on a fixed integer-tick cadence (the A1/
  `TimingWindow` precedent) is hashable by construction. It can read whatever facts already live
  in state (or whatever Open Question 1 adds) and its outcome is deterministic and replay-safe
  for free, exactly like every other step-1-through-8 computation.
- `Area3D` overlap queries are PHYSICS-FRAME, live outside `src/state/`, and are NOT hashable --
  Jolt's overlap results are not guaranteed bit-stable across a recording and its replay (the same
  reasoning 1-7's gate rejected physics-timing contact detection for, `D-4`). Using them for
  targeting would mean the ACQUIRED target itself is a physics artifact that must cross into state
  as a derived fact (coupling this question to Open Question 1's answer (a)), or targeting logic
  would have to live partly outside `src/state/` altogether -- a bigger seam change than this
  story's ACs currently assume.

**Both are presented with this framing; this pass does not pick.** The gate rules between them
(or a specific division of labour between the two) with AC 7's reserved `advance()` seat and this
evidence in hand.

## Tasks / Subtasks

- [ ] Author `MinionPriority` (`src/state/resources/minion_priority.gd`), the D6 schema precedent
      (AC: 1)
- [ ] Author `data/minions/*.tres` -- at minimum one `.tres` per named priority type (`Standard`,
      `Hero-Seeker`, `Tank`, `Bomber`/AoE) sufficient to prove distinguishable selection (AC: 1, 6)
- [ ] Write `TargetingService` (`src/state/economy/targeting_service.gd`, the `CardEffectResolver`
      sibling location per the D6 precedent), the directory-scan loader, and the deterministic
      tie-break (AC: 2, 3, 6, 8)
- [ ] Extend `UnitBoard`/`PlayerState.units` with per-unit identity, resolving Open Question 1's
      scope for THIS story (position or not) per the gate's ruling (AC: 9)
- [ ] Wire the throttled evaluation into `MatchState.advance()` step 7's reserved seat
      (`match_state.gd:279`), per the gate's ruling on Open Question 2 (AC: 7, 10)
- [ ] Gate targeting on `FeatureFlags.minions`; matrix-test ON/OFF (AC: 5)
- [ ] Golden re-baseline: measure and separate every cause exactly as every prior multi-cause
      re-baseline in this project has, per the Golden Prediction below (AC: 4)
- [ ] Replay parity coverage for whichever mechanism the gate selects (AC: 10)

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
- **The runner's observation-seam count is currently pinned at eight**
  (`test_architecture_invariants.gd`, `test_runner_observation_seams_are_exactly_eight`). If Open
  Question 2 resolves toward an `Area3D`-based mechanism needing a new `connect_*` seam, that guard
  needs the same kind of named, reviewed amendment `3-6/R2` and 4-1 both set precedent for -- not
  a default assumption either way.
- **The snapshot key set is currently ten** (`test_card_observation.gd:230-231`:
  `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs", "pending_draw",
  "pending_draw_owed", "stamina", "unit_count"]`). Whatever AC 9's identity extension needs to
  cross into the hash (if anything) follows the counts-only precedent every card-container key in
  this file already keeps -- no unit identity, no target identity, as a `StringName` or object
  reference reaching the hash is the standing failure mode. A count of units-with-an-acquired-
  target, if the gate finds one useful, is the shape to reach for before a richer one.

### Project Structure Notes

- `src/state/resources/minion_priority.gd`: new D6 schema (AC 1). Directory Tree already reserves
  the name (`game-architecture.md:590`, tagged `(E4)`).
- `data/minions/`: first real content, replacing the `.gitkeep`-only directory (AC 1).
- `src/state/economy/targeting_service.gd`: `TargetingService`, the D6 sibling, beside
  `card_effect_resolver.gd` (AC 2, 3).
- `src/state/unit_board.gd`, `src/state/player_state.gd`: `UnitBoard` gains per-unit identity
  (AC 9); `to_snapshot()` may gain a key, counts-only, if the gate finds one needed.
- `src/state/match_state.gd`: step 7's reserved seat (`match_state.gd:279`) gains real content
  (AC 7).
- `test/state/`: new `test_targeting_service.gd` (or similarly named) for AC 2/3/6/8; existing
  golden/snapshot/replay-identity/architecture-invariant suites extended per the gate's rulings.

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

## Golden Prediction

**MOVES -- causes named in both directions, not asserted as a measured shift (no dev pass has run
yet):**

1. **Likely snapshot-shape cause, IF AC 9 or the gate adds any new key.** Any new counts-only key
   (e.g. units-with-a-target) would move the golden at its introduction the same way `unit_count`
   (4-1), `discard_size` (3-5a), and `pending_draw_owed` (4-0) each did -- present at an all-zero
   value before any unit ever targets anything. NOT asserted as certain: the gate may find AC 9's
   identity extension needs no new hashed key at all (an internal id used only for tie-break
   selection, never surfaced).
2. **Likely behavioural cause.** The golden fixture already casts a `summon_*` card at tick 22 with
   `minions` flag on (4-1, confirmed). Once `MinionPriority` content exists as always-loaded
   directory content (per AC 3's `EconomyEvaluator` precedent), the spawned unit begins evaluating
   targets from the tick after it spawns onward, under whatever cadence AC 7 ships -- if that
   evaluation writes anything into state (a target id, a target-acquired flag), the hash moves
   from that tick forward. If the gate instead finds targeting produces no state-visible effect
   this story (e.g. only presentation/actor-side reads the verdict), this cause is a NON-mover,
   to be measured and stated plainly either way.
3. **Possible non-mover: `rng_state`.** Nothing about tie-break selection should consume RNG (AC
   8: deterministic tie-break, not a random one) -- predicted a non-mover, to be CONFIRMED by an
   explicit test on the `3-5b`/`4-0`/`4-1` precedent of testing predicted non-movers rather than
   assuming them.

No baseline hash is recorded here as a target, per the standing rule (3-3 gate) that a Golden
Prediction baseline is re-derived from `test_determinism.gd`'s `GOLDEN` constant at gate time. The
BEFORE value for this authoring pass: `GOLDEN := "78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5"`
(`test/state/test_determinism.gd:336`), the value 4-1 shipped. Suite BEFORE: 399 state tests / 2517
assertions, 0 failed, plus the integration suite, all PASS (measured this authoring pass,
`bash test/run_all.sh`).

## Live Smoke

**REQUIRED**, on the Tier A default and this story's own player-facing claim: a summoned unit
visibly acquires and acts on a target, which is exactly the kind of claim this project judges
live rather than headless (the `3-0a`/`3-6`/`4-0`/`4-1` precedent). Script depends on what the
gate rules for Open Questions 1/2 and is finalized at the gate, not here; at minimum: summon a
unit, confirm it does not sit permanently inert once a valid candidate exists, and confirm
`FeatureFlags.minions = false` degrades to today's 4-1 behaviour (unit present, inert). **`R-D6`
is RE-INVOKED on this gate** -- measured SPENT on 4-1's smoke (2026-08-09), so this is the next
player-facing story carrying a live smoke and the two-human kill-acceptance ritual reattaches
here.

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
