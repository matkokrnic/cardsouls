# Story 3.2: Card schemas, `CardDatabase`, and the first authored cards

Status: ready-for-dev

> **Scope note.** The E3 revisit gate has RUN (2026-07-31, decision-log Session 2026-07-31 — E3
> revisit gate (outcome), rulings E3-RG/R1..R12); this story was CONFIRMED as written apart from two
> cosmetic fixes (naming the existing `Enums.CardColor` instead of a second enum; citing the GDD as the
> source of the copies-per-card bound), applied the same session in commit `10b96a1`. DP/R3 waived the
> separate external playtest that the original revisit banner demanded. This story then passed its OWN
> readiness gate (2026-08-03) after the fixes recorded in this revision — the confirm proved shallow
> (see Dev Notes).

## Story

As a solo developer,
I want the card schema resources, a starter card set as `.tres`, and `CardDatabase` preloading them at startup,
so that adding a card is a `.tres` with no code change, and per-colour unblockable damage can never sneak onto `CardData`.

## Acceptance Criteria

1. **Card schema.** `CardData` lands at `src/state/resources/card_data.gd` as a pure schema
   (`src/state/resources/` is the "Resource SCHEMA classes — pure data vocabulary" tier; no logic).
   Exports: `id` of type `StringName`; `color` using the EXISTING `Enums.CardColor { RED, BLUE, GREEN }`
   (`src/state/enums.gd`); `basic_effect`; `pitch_effect`; `cast_condition`; `max_copies`. `CardEffect`
   lands in the same folder as a schema. No damage field of any kind on `CardData`.
2. **Cast condition schema, and NO evaluator.** `CardCastCondition` lands at
   `src/state/resources/card_cast_condition.gd` carrying `mana_cost` as a LITERAL float, per-colour orb
   costs keyed by `Enums.CardColor`, and a required-flag `StringName` in the same shape
   `ResourceGenerationRule.required_flag` uses (`src/state/resources/resource_generation_rule.gd`).
   `src/state/economy/` is NOT touched by this story: no cast evaluator ships here, because its first
   consumer is the card-play story (3-5), designed there against a working `EconomyEvaluator` rather
   than a hypothetical one — the reason `CardCastCondition` was stripped out of 3-4's own scope back to
   this story ("STRIPPED to 3-2, designed there against the working evaluator this story delivers,"
   3-4's gate finding B1, decision-log Session 2026-08-02 — Story 3-4 readiness gate).
3. **Authored starter set.** `data/cards/` contains NINE card `.tres` files, three per colour, one at 2
   mana / one at 3 mana / one at 5 mana within each colour. Every `id` is non-empty and unique across
   the set. `max_copies` is authored per card in the 2–3 range the GDD specifies — "Deck **20 cards**;
   max copies per card **2–3**, configurable per card in data" (GDD §A. Card System — "Deck & hand.",
   `gdd.md:193`) — such that a 20-card deck is constructible. `pitch_effect` is left unauthored on every
   card: the pitch mode is reserved for a later epic (E6), and this story does not author pitch costs.
4. **Loader.** `CardDatabase._load_all()` (`src/systems/card_database.gd`, already registered as an
   autoload — `project.godot` needs NO edit and must not be touched) replaces its no-op body with a
   sorted, single-directory scan of its `CARDS_DIR` filtered on the `.tres` extension, indexing by the
   `id` FIELD inside the resource, not by filename. The scan runs once at startup with no reload path.
   It carries a comment cross-referencing the equivalent scan in `EconomyEvaluator.load_rules()`
   (`src/state/economy/economy_evaluator.gd`), and that scan carries the reciprocal comment — the
   duplication is deliberate and recorded (see Dev Notes).
5. **Cards stay outside the hashed determinism run.** No file under `src/state/` names `CARDS_DIR` or
   the cards resource path; card data reaches the state layer by injection only, if and when a later
   story needs it. Pinned by a test in the existing `test/state/test_architecture_invariants.gd` shape,
   and that guard must be PROVEN TO FAIL when the thing it protects is removed.
6. **Tests.** The existing recursive data sweep
   (`test/state/test_data_resources.gd::test_every_data_tres_loads`) already loads every `.tres` under
   `data/` and therefore covers the new cards for load-only with no edit — and it is NOT sufficient on
   its own. Two additions: (i) a new state-harness test asserting the authored field set, the colour
   enum values, the copies-cap bounds, and id uniqueness; (ii) a new INTEGRATION test that instantiates
   the autoload, asserts the loader returns exactly the authored card count, and asserts every authored
   id resolves. The integration test is required because the state harness runs without autoloads, and
   because a silently empty card dictionary would today be noticed by nothing.
7. **Unblockable stays out of card data.** A test fails if a per-card damage or unblockable field
   appears on `CardData`. This AC carries ONLY that negative guard: per-colour unblockable damage is a
   fixed value in balance, that value does not exist yet, and the feature flag guarding it
   (`FeatureFlags.unblockable`) is marked for a later epic — authoring it is not this story's business.

## Tasks / Subtasks

- [ ] Implement `CardData`, `CardEffect` schemas (AC: 1)
- [ ] Implement `CardCastCondition` schema; confirm `src/state/economy/` is untouched (AC: 2)
- [ ] Author the nine-card starter set (three colours × {2, 3, 5} mana), `pitch_effect` left unauthored
      (AC: 3)
- [ ] Complete `CardDatabase._load_all()`: sorted directory scan of `CARDS_DIR`, index by the `id`
      field; add the cross-reference comment paired with `EconomyEvaluator.load_rules()` (AC: 4)
- [ ] Add the state-layer guard against `src/state/` naming `CARDS_DIR`/the cards path, mutation-proven
      (AC: 5)
- [ ] New state-harness test (field set, colour enum, copies-cap bounds, id uniqueness) + new
      integration test (autoload card count, id resolution) (AC: 6)
- [ ] Negative-guard test: no damage/unblockable field on `CardData` (AC: 7)

## Dev Notes

- **Unblockable damage is per-colour, not per-card** — a fixed value per colour in balance; easy to implement wrong. [Source: docs/project-context.md#Critical Don't-Miss Rules; gdd.md#C]
- Modes ②/③ derive from `color` and carry no per-card data (Novel Pattern 6). Only Mode ① lands in E3; ④ (`pitch_effect`) is a reserved placeholder for E6. [Source: docs/game-architecture.md#Novel Pattern 6]
- State never reads `CardDatabase`; resources are injected. [Source: docs/game-architecture.md#Standard Patterns — Data access]
- `color` is `Enums.CardColor`, not a new enum — `OrbPool.get_count`/`add` already switch on `Enums.CardColor.RED/BLUE/GREEN` (`orb_pool.gd:21-34`); `CardData` reuses the same vocabulary so a card's colour and its orb/unblockable colour are the same value, never two enums that must be kept in sync by hand. [Source: src/state/enums.gd; src/state/pools/orb_pool.gd]
- Copy-cap bound is GDD-sourced, not invented: 2–3 copies per card, per-card configurable. [Source: gdd.md:193]
- **The cast-evaluator contract inherited by the card-play story.** Whatever evaluates `CardCastCondition`
  in 3-5 is pure and static, computes but does not apply — pools apply the spend. `ManaPool.spend()`
  (`src/state/pools/mana_pool.gd`) already returns a bool and changes nothing when unaffordable, the
  same shape `EconomyEvaluator.amount_for()` uses on the generation side. This is binding on 3-5, not
  re-litigated there.
- **`mana_cost` is a literal float on the condition, NOT the name of a balance field.** This is a
  deliberate break from the resource-rule mirror: `ResourceGenerationRule.amount_field` names a
  `BalanceConfig`/`BalanceTicks` field because every gameplay NUMBER in this project lives in balance,
  but a card's price is per-card CONTENT, not a tunable shared across many things. Recorded so a later
  reader does not "fix" it into a field name.
- **Card identity is a field inside the `.tres`, not the filename.** It survives a rename, and the
  deck-shuffle story (3-3) will make deck order hash-visible, which turns card identity into a replay
  contract. Filename mirroring the `id` is convention only. Any ordered exposure of the card set is
  explicitly sorted; dictionary iteration order is never a contract.
- **The copies cap is per-card data, not a `BalanceConfig` field.** That ruling was assigned to this
  story at 3-1's own gate (the Q1 scope-strip rider: "`default_copies_per_card` is likely per-card data
  rather than a `BalanceConfig` field, which 3-2 judges") and is discharged here as AC3's `max_copies`
  export.
- **The pacing measuring stick.** One buildup→bluff→payoff cycle is taken to cost about 11 mana (one
  5-cost pitch plus two 3-cost plays: 5 + 3 + 3). Against the authored mana set — `max_mana = 10.0`,
  `melee_hit_mana = 1.0` per confirmed hit, `mana_regen_per_second = 0.25`
  (`data/balance/balance_config.tres`) — a 3-cost card is funded by 12s of passive income alone or 3
  confirmed hits alone; a 5-cost card by 20s of passive income alone or 5 hits alone. On passive income
  alone, with no melee: a 60s round generates 15 mana of cumulative income (60 × 0.25), enough for one
  5-cost card plus most of a second 3-cost; a 120s round generates 30 mana, enough for roughly two full
  11-mana cycles with 8 left toward a third — before melee income is even counted. This is consistent
  with the E3-RG/R1 criterion (~2-4 cycles per round) once melee hits are added on top. This cycle cost
  is a measuring stick with NO consumer in code — it exists so the mana rate has something to be judged
  against, not to be authored anywhere.
- **Parked findings and their seats (from 3-4's live smoke, decision-log 3-4/R11).** S1 (passive rate
  possibly too fast) and S2 (a melee hit granting ~10% of the bar where 5% or less is wanted) named this
  story as their forcing point. This story discharges that by AUTHORING PRICES and ruling ownership
  (AC3, above), not by retuning: the retune is a separate golden-neutral `chore(balance)` commit whose
  forcing point moves to the first smoke in which a card can actually be cast, because the "2-4 cycles
  per round" criterion is unjudgeable before then. S3 (should a blocked hit pay reduced mana?) gets its
  own seat entirely — it is a new mechanism (a new balance field, a golden mover) and it would reverse
  the locked 1-8 decision that a block deliberately does not touch the attacker's economy. S4 (mana
  appears to survive a reset) belongs to the first round-flow story and is NOT inherited here — verified
  against `MatchState._reset_player()` (`src/state/match_state.gd`), which never touches mana or
  stamina, so the observation is leftover pre-death mana, not a grant.
- **Scan duplication is deliberate.** A shared helper between `CardDatabase._load_all()` and
  `EconomyEvaluator.load_rules()` is deferred to a third scan, because the two current scans sit on
  opposite sides of the state/systems layer boundary and a shared helper has no honest home today. The
  existing ownerless export-packaging remap risk (3-4/R8: a raw directory scan filtered on extension can
  break under export remap, degrading to an empty set with no error) is EXTENDED to cover
  `data/cards/` as well as `data/economy/`, rather than filed a second time; an empty card set is a
  worse failure than an empty rule set.
- **Crash guards, pre-declared.** The loader will need null guards (a missing directory, a `.tres` that
  fails to cast to `CardData`) that a GDScript null dereference cannot prove by mutation, because such a
  dereference aborts only the current function and leaves the caller running (the crash-guard-blind
  family, permanently recorded at 3-1/R6, re-applied at 3-4/R10 D4). Those guards are crash guards and
  the dev pass must NOT manufacture mutation proofs for them.
- **Divergences from the architecture doc, to be reconciled at the epic close-out** (this story adds the
  SIXTH member to the amendment queue, which currently holds five — 3-4/R4, R9): the `CardData` sketch
  under "Novel Pattern 6 — Four-Mode Card Resolution" lists FOUR exports (`color`, `basic_effect`,
  `pitch_effect`, `cast_condition`) where this story ships SIX (`id` and `max_copies` added);
  `CardEffect` appears in no schema list under "Schema vs Loader (class_name uniqueness)" (which
  enumerates `FeatureFlags`, `BalanceConfig`, `CardData`, `ResourceGenerationRule`, `CardCastCondition`,
  `TelegraphProfile`, `MinionPriority`, `EquipmentData` — no `CardEffect`) and in no Directory Tree line
  (the `src/state/resources/` listing names `card_data.gd · resource_generation_rule.gd ·
  card_cast_condition.gd` only, no `card_effect.gd`). The "already landed" framing carries in TWO
  places, both verified by content, not one: the "D6 — Data-Defined Economy (Binding Constraint #3)"
  section states plainly "E0 lands the types + evaluator interface; E3 authors the concrete `.tres`"
  and lists `ResourceGenerationRule`'s fields as `source`, `resource`, `amount`, `trigger` — a shape
  the shipped evaluator does not use; and "Novel Pattern 5 — Data-Defined Economy Evaluator" sketches
  the same superseded shape as working code (`amount: float`, `EconomyEvaluator.apply()` mutating a
  pool directly), which this project's shipped evaluator explicitly departed from
  (`amount_domain`/`amount_field`, compute-not-apply — 3-4/R9). Make NO edit to the architecture doc.

### Readiness-gate findings and rulings (2026-08-03)

- **The invariant-helper finding.** The story text carried `check_invariant` in its old AC4 — a name
  that names no real symbol. The shipped helper is `Invariant.check` (`src/systems/invariant.gd`). The
  sibling card-play story (3-5) had this exact name corrected at the E3 revisit gate (commit `10b96a1`);
  3-2 carried the wrong name through untouched because it was CONFIRMED rather than amended at that same
  gate — the clearest evidence that the confirm proved shallow. AC7 above drops the mechanism name
  entirely, stating only the verifiable claim (a test fails), so there is nothing left to misname.
- **Premise corrections.** (i) The decision log records no per-story ruling enumerating verified claims
  for this story — only that it was "implementable as written apart from two cosmetic fixes," and that
  framing is the E3-RG entry's own summary, not a per-claim audit; the per-claim framing in this gate's
  report is new. (ii) The GDD's second referenced price — Mode ④ Pitch, "Mana (higher) + orbs" — is a
  MODE of the same card, not a second card (`gdd.md`: "Card anatomy... a Basic effect + mana cost, and a
  Pitch effect + cost"); that price is reserved for a later epic and is not authored live here. (iii)
  Four smoke findings from 3-4 are parked, not three (S1-S4, decision-log 3-4/R11). (iv) The claim that
  authoring a hand-size balance field would move the golden is FALSE: `PlayerState.to_snapshot()` reads
  the hand array's own size, and the golden fixture builds its `BalanceConfig` in-test, so a balance
  field is hash-neutral by construction — what moves the golden is POPULATING the hand, which belongs to
  the deck story (3-3). This is the gate's most valuable finding.
- **Nine blocking findings, resolved:** stale E3-revisit banner plus a dangling cross-reference to 3-1
  (fixed by the Scope note above); an unsatisfiable injection clause (old AC3 implied `CardDatabase`
  both preloads AND injects into state with no consumer — AC2's economy-evaluator exclusion and AC4's
  loader-only scope resolve this); an AC asserting a balance field that does not exist and belongs to a
  later epic (old AC4's per-colour damage value — replaced by AC7's negative-only guard); the wrong
  invariant-helper name (above); a golden baseline stale across three intervening re-baselines (the
  stamina-cost corrective pass, 3-0b Pass 2, and the 3-4 economy re-baseline — `33817201...` →
  `98d0c7eb...`, Golden Prediction section below); undeclared inherited scope (the copies-cap ruling from 3-1's Q1
  rider, now named in Dev Notes); unspecified card identity and iteration order (Dev Notes); two schema
  divergences from the architecture doc (the sixth amendment-queue member, Dev Notes); silence on the
  parked findings (S1-S4 seats, Dev Notes).
- **Rulings, restated from Dev Notes above:** schema-only with the cast evaluator deferred to 3-5
  (AC2); `mana_cost` a literal, not a balance-field name; `id` as a field, never the filename; the
  copies cap as per-card data; cards kept outside the hashed run with the deliberate rules/cards
  asymmetry recorded; the tuning retune (S1/S2) and the blocked-hit mechanism (S3) each get a separate
  seat; the scan-helper deferral with the extended export-remap flag; the new integration test and why
  the state harness cannot cover it (AC6).
- **Operator's sealed design decisions.** The buildup→bluff→payoff cycle cost is taken as roughly 11
  mana, after the deck-throughput reading (a full pass through the 20-card deck) was considered and
  rejected — the GDD's cycle is buildup→bluff→payoff, not a deck pass. A nine-card starter set ships at
  three per colour, with a preference on record for four or five per colour later, deferred because
  adding a card is a `.tres` with no code change.
- **Note for the remaining epic stories.** The same stale banner residue found here is present in 3-3,
  3-5, and 3-6; their own gates should not spend a finding rediscovering it.

### Project Structure Notes

- Schemas in `src/state/resources/`; instances in `data/cards/`; `CardDatabase` autoload in `src/systems/`.

### Project Context Rules

- **Data-defined content:** new card = new `.tres`, no code. [Source: docs/project-context.md#Data as Resources]
- **State receives schema by injection, never reads a `*Service`/autoload.** [Source: docs/project-context.md#Autoloads]

### References

- [Source: stories-manual-e3.md#E3.S2]
- [Source: docs/game-architecture.md#Novel Pattern 6; #D6]
- [Source: gdd.md#A Card System — Imp Summoner; #A Card System — Deck & hand]
- [Source: decision-log.md Session 2026-07-31 — E3 revisit gate (outcome), E3-RG/R1]
- [Source: decision-log.md Session 2026-08-02 — Story 3-4 readiness gate; 3-4 close-out]
- [Source: decision-log.md Session 2026-08-03 — Story 3-2 readiness gate]

## Golden Prediction

**Baseline:** `98d0c7ebfdbe01a97622b185a7e3388428793cc87e323751c2ffb5b6f58f81ff` (the `GOLDEN` constant in
`test_determinism.gd`, current — the 3-4 re-baseline).

**Prediction: NONE, measured in both directions** (before the first edit and after the last). Reasons,
all verifiable:

- The hashed run constructs its own `BalanceConfig` and `FeatureFlags` in-test (`_golden_config()`) and
  loads nothing from `data/`.
- The state harness instantiates no autoloads at all, so `CardDatabase` never runs inside a state-harness
  test.
- AC5 forbids the state layer from reaching card data by any route.

**Standing consequence.** Card `.tres` content is NOT load-bearing for the hash and must not become so —
if a later story needs cards inside the tick loop, they arrive by injection and the golden fixture
authors its own coverage value, exactly as `_golden_config()` already does for balance and economy
fields. This is a DELIBERATE ASYMMETRY with the economy rules (`data/economy/*.tres`), which ARE
load-bearing — a rule-field rename moved the golden and failed 29 tests (3-4/R6, mutation M5). The
reason for the asymmetry: the rule set is two files and a fixed mechanism (`melee_hit`, `passive_tick`),
while cards are a growing content library — making card content hash-bearing would mean that adding a
card re-baselines the golden, defeating the "add a card = a `.tres`, no code" promise this story exists
to deliver.

## Live Smoke

**NOT REQUIRED**, with a corrected reason. The original reason ("no actor, controller, or HUD surface")
is true but incomplete: this story DOES put new code in the live boot path, because `CardDatabase`'s
`_ready()` (calling `_load_all()`) runs in every live run and in every integration run — it is an
autoload, not a story-gated seam. That is observable only as absence of failure, and the proof is
headless: the integration runner already greps each run for script errors, parse errors, and invariant
violations. Nothing this story ships is visible to a player: no HUD, no input, no state consumer.

The live-smoke acceptance criterion (R-D6) is currently SPENT (3-4/R11, first player-facing story since
3-1) and is re-invoked by the next story that ships player-facing behaviour — the card-play story (3-5),
not this one.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

### Completion Notes List

- Readiness-gate fix pass (2026-08-03): the rulings applied in this revision were provided by the
  operator at this story's readiness gate; this pass rewrote the file around them.

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-31 | 0.2 | E3 revisit-gate outcome (commit `10b96a1`): CONFIRMED as written apart from two cosmetic fixes — named the existing `Enums.CardColor` instead of a second enum; cited the GDD as the source of the copies-per-card bound. Golden Prediction and Live Smoke sections added. Status stayed backlog pending this story's own readiness gate. | Claude Opus 4.8 |
| 2026-08-03 | 0.3 | Readiness-gate fix pass (NOT READY on first read -> fixed and promoted, same session; sixteenth logged Set B readiness gate). AC set replaced with seven verifiable claims (card schema; cast-condition schema with no evaluator; nine-card starter set; loader; cards outside the hashed run; test surface incl. a new integration test; the unblockable negative guard). Stale E3-revisit banner and dangling 3-1 cross-reference replaced with a Scope note in the 3-1/3-4 pattern. The wrong `check_invariant` name in the old AC4 dropped entirely — the sibling 3-5 story had it corrected to `Invariant.check` at the revisit gate; this story carried the wrong name through untouched because it was confirmed, not amended, the clearest evidence the confirm proved shallow. Golden Prediction baseline corrected from `33817201...` — stale across three intervening re-baselines (the stamina-cost corrective pass, 3-0b Pass 2, and the 3-4 economy re-baseline) — to `98d0c7eb...`, prediction NONE in both directions. Live Smoke kept NOT REQUIRED with the corrected reason (the autoload's `_ready()` runs in the live boot path; the integration runner's headless script-error grep is the proof). Dev Notes appended with the evaluator contract inherited by 3-5, the literal-vs-field `mana_cost` ruling, card identity as a field not a filename, the copies-cap-is-per-card ruling, the pacing measuring-stick arithmetic, the parked-findings seats (S1/S2 here, S3 its own seat, S4 to the round-flow story), the deliberate scan-duplication note with the extended remap flag, the pre-declared crash guards, and the sixth architecture-amendment-queue member. Status backlog -> ready-for-dev; `sprint-status.yaml` and `stories-manual-e3.md` updated alongside. | Claude Opus 4.8 |
