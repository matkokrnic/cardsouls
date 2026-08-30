extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

## RE-BASELINED BY STORY 4-4'S REVIEW FIX PASS (`4-4/R14`), d94337cd -> a96b123e, ONE CAUSE.
##   1. SNAPSHOT VALUE SHAPE, not the key SET. `unit_in_reach` was a bool per unit and is now an INT
##      per unit — the number of ticks a reach confirmation stays CURRENT. The key set does NOT move
##      (still TWENTY-SEVEN), and no behaviour in this fixture moved either: the fixture's every
##      contact fact is HERO-sourced, so `_mark_reach_from_fact` returns before marking and the
##      countdown sits at its empty value for the whole run. What changed is how CanonicalHash
##      RENDERS that value — `false` -> `0` — which is the entire delta. MEASURED both ways: with
##      `in_reach_snapshot()` projecting the count back down to a bool the fixture reproduces
##      d94337cd exactly, and with the count itself it reads a96b123e.
##   2. `rng_state` — a non-mover, and structurally so: nothing about a reach confirmation's shelf
##      life consumes RNG. Confirmed by the measurement above being fully explained by the one
##      key's rendering.
##
## WHY THE COUNT IS HASHED RATHER THAN ITS PREDICATE, since the cheaper option was available and was
## measured: `4-3a/R17` says a value that CROSSES TICKS and DECIDES AN OUTCOME cannot sit outside the
## hash, and how much freshness is left decides whether the next windup may begin. Hashing only the
## bool would have kept this golden unmoved at the price of two genuinely different states hashing
## the same, and `UNHASHED_CROSS_TICK_MEMBERS` going 3 -> 4 in test_replay_identity.gd. The operator
## refused that trade by name and spent the re-baseline instead; the exclusion set STAYS AT THREE.

## NOT RE-BASELINED BY STORY 4-4, PASS 3 OF 3 (the accelerator faucets) — d94337cd UNMOVED, and the
## non-move is MEASURED AND NAMED rather than a step that was skipped. AC 12 requires the
## accelerators to be considered as their own cause "separate from any cause introduced by the
## per-kind conversion or the projectile", and this is that consideration's result.
##
## THE THREE CANDIDATE CAUSES, each predicted and each confirmed a NON-MOVER:
##   1. THE AUTHORED RULE SET GREW, two rules to three (`data/economy/mana_accelerator.tres`). This
##      is the one candidate that could NOT be dismissed on `BC/R3` grounds, because `3-4/R6`
##      narrowed that isolation explicitly: `data/economy/*.tres` rule CONTENT is load-bearing for
##      the golden, since production code scans that directory on the golden's own path. MEASURED
##      UNMOVED, and the reason is structural: `EconomyEvaluator.amount_for` filters by SOURCE, the
##      new rule's source is `mana_accelerator`, and the two rungs whose results this fixture SPENDS
##      ask for `melee_hit` and `passive_tick`. A rule that matches no queried source contributes
##      nothing. (D3, corrected at the review: the third `amount_for` call IS reached on every tick
##      — the cadence divisor clamps to >= 1 — it simply discards its result behind the liveness
##      gate. The sentence used to read as though the call never happened; cause 2 below always
##      said otherwise.)
##   2. THE THIRD `_generate_mana` CALL SITE. Reached on every cadence boundary, but gated on a LIVE
##      accelerator on that player's own board — and the fixture's authored kind is a MINION, so
##      `has_live_kind` is false for both players on every tick of the recorded sequence. The rung
##      runs and pays nothing.
##   3. THE STAMINA REGEN FACTOR. The same gate on the same board, so the multiplier is never
##      applied and `_regen_stamina` computes the identical per-tick amount it always has. Stamina
##      IS hashed (both players' pools are in the snapshot and the fixture spends and regenerates
##      through the whole run), so this is the candidate with the most exposure — and it is exactly
##      why it is worth stating as measured rather than assumed.
## NOT a cause either: `mana_accelerator_mana`, `mana_accelerator_interval_seconds` and
## `stamina_accelerator_regen_multiplier` are unauthored in `_golden_config` and default to 0.0 —
## and the cadence's derived divisor clamps to 1, so the boundary test is true every tick, which
## means the rung is EXERCISED on every tick rather than skipped. The gate that stops it is the
## liveness test, not the cadence, which is the stronger of the two ways this could have been a
## non-mover.
##
## RE-BASELINED BY STORY 4-4, PASS 2 OF 3 (the projectile), 836afc01 -> d94337cd, ONE CAUSE — and
## the fact that there is only one is itself a measured finding rather than an omission.
##   1. SNAPSHOT SHAPE (the ONE mover). `PlayerState.to_snapshot()` gains SEVEN keys, the whole
##      projectile board: `projectile_targets`, `projectile_kind`, `projectile_source`,
##      `projectile_alive`, `projectile_homing`, `projectile_flight_ticks`,
##      `projectile_travelled`. ISOLATED BY CONSTRUCTION rather than by a staged mutation (the 4-1
##      cause-1 method): the golden fixture's authored kind is a MINION whose attack record carries
##      no projectile, so the fixture is structurally incapable of launching one and all seven keys
##      enter the hash at an EMPTY array. MEASURED: 836afc01 -> d94337cd, the value below.
##      The key set moves TWENTY -> TWENTY-SEVEN here, pinned by test_card_observation.gd.
##   2. BEHAVIOUR — THERE IS NONE IN THIS FIXTURE, AND THAT IS A REPORTED GAP RATHER THAN A CLEAN
##      RESULT. Every previous board story (4-1's summon, 4-2's acquired target, 4-3a's hp) got its
##      behaviour inside determinism coverage BY CONSTRUCTION, because the fixture's ONE recorded
##      cast at t22 was enough to move the value before the hash is taken at t24. A projectile
##      cannot reach the hash on that timeline.
##
##      THE TICK ARITHMETIC, CORRECTED AT THE REVIEW (D2 — the dev pass wrote t25). Measured against
##      `advance()`'s actual step order: step 3b `_advance_unit_attacks` runs BEFORE step 4
##      `_resolve_contacts`, and step 7 `_update_unit_targets` runs LAST. The unit is summoned at
##      t22; at t23 step 4 it still holds the no-target pair, and the retarget that gives it a target
##      happens at t23 step 7, AFTER — so the earliest scope-matching mark is t24, the windup it
##      permits begins at t25, and the windup-to-active transition that LAUNCHES is t26. The error
##      ran against the pass's own margin (t26 > t24 > the hashed tick), so the conclusion held a
##      fortiori; the number was still wrong and is fixed here.
##
##      AND THE REMEDY SENTENCE THIS BLOCK USED TO CARRY WAS FALSE (D1 — corrected at the review).
##      It said getting a projectile into the golden "requires extending the recorded sequence past
##      t24". IT DOES NOT, and a follow-up story starting from that sentence would extend the
##      fixture and still measure nothing. TWO INDEPENDENT STRUCTURAL REASONS, either alone
##      sufficient: (i) `mark_in_reach_at` is reached only from `_mark_reach_from_fact`, which
##      returns immediately for a HERO attacker, and every fact this fixture pushes is hero-sourced
##      — so `unit_in_reach` is empty forever at EVERY tick count and the unit can never wind up;
##      (ii) the fixture's kind comes from `UnitKindFixture.melee()`, which never sets
##      `attack.projectile`, so the launch branch is dead regardless. Reason (ii) is the same
##      "isolated by construction" argument this entry's cause 1 rests on, which is why it is
##      load-bearing here and not a coincidence. Bringing a shot into this hash needs a fixture that
##      pushes a UNIT-sourced probe against a kind authoring a projectile — a redesign, not a longer
##      sequence, and one that would re-baseline every unrelated key at once.
##      SO THE PROJECTILE'S BEHAVIOUR IS GUARDED BY ITS OWN HEADLESS TESTS
##      (test_projectile_flight.gd) AND BY test/integration/test_projectile_flight_live.gd, NOT by
##      this hash. Recorded here, and in the Dev Agent Record, as a known coverage boundary for the
##      operator rather than left to be discovered at a later gate.
##   3. `rng_state` — PREDICTED A NON-MOVER, CONFIRMED. Nothing about a projectile consumes RNG:
##      launch is a deterministic consequence of a phase transition, the speed curve is authored
##      arithmetic, and homing is a rate-limited rotation the RUNNER performs. Confirmed by the
##      measurement above being fully explained by the seven empty keys.
## NOT a cause: `data/balance/balance_config.tres`'s authored `ProjectileProfile` (the fixture is
## built in-test and never loads it), nor the new `projectile_actor.tscn` / `totem_actor.tscn` — the
## state harness instantiates no scene at all.
##
## RE-BASELINED BY STORY 4-4, PASS 1 OF 3 (the per-kind data conversion), 4a089063 -> 836afc01, TWO
## CAUSES MEASURED SEPARATELY AND IN ORDER against the inherited 4a089063 value.
##
## AC 12 REQUIRES THE THREE STORY-LEVEL CAUSES TO BE MEASURED SEPARATELY — "the per-kind data
## conversion named as its own measured cause, separate from any cause introduced by the projectile
## or the accelerator faucets" — so 4-4 re-baselines THREE TIMES, once per build commit, rather than
## once at the end with three entangled causes. This entry is the FIRST; the projectile's and the
## accelerators' entries are added above it by their own commits.
##   1. SNAPSHOT SHAPE (a mover, predicted). `PlayerState.to_snapshot()` gains TWO keys: `unit_kind`
##      (the per-record kind INDEX, AC 1) and `unit_attack_cooldown` (the firing-cadence countdown,
##      AC 10). ISOLATED BY A STAGED VALUE rather than by construction, because unlike 4-1/4-2 the
##      conversion cannot ship without SOME authored kind — with none, the cast seat puts no record
##      on the board at all and `unit_count`/`unit_hp` coverage would silently vanish instead of
##      moving. So `GOLDEN_UNIT_MAX_HP` was staged at 0.0 for this measurement, which reproduces the
##      fixture's pre-4-4 behaviour EXACTLY: `unit_max_hp` was never authored in `_golden_config`,
##      defaulted to 0.0, and the t22 summon's record has entered DEAD-on-arrival in this hash since
##      4-3a. At that staging the ONLY delta from the inherited value is the two new keys, both at
##      their zero payloads (`[0]` and `[0]`). MEASURED: 4a089063 ->
##      93ecf7e99d9996dbda0fe66979f243b580d7e8f9e7e8a9a23277d45bb3394306.
##      The key set moves EIGHTEEN -> TWENTY here, pinned by test_card_observation.gd.
##   2. THE CONVERSION'S CONTENT (a mover). `GOLDEN_UNIT_MAX_HP` restored to its real coverage value
##      7.0, so the summoned record now enters ALIVE and `unit_hp` moves `[0.0]` -> `[7.0]`.
##      MEASURED on top of cause 1: 93ecf7e9 -> 836afc01, the value below.
##   3. AC 7's PER-KIND PRIORITY READ — PREDICTED A NON-MOVER, and the prediction is STRUCTURAL
##      rather than merely measured: `_update_unit_targets`'s removed hardcoded
##      `TargetingService.PRIORITY_STANDARD` lookup is replaced by a read of the asking kind's
##      authored `priority_name`, and `_golden_config`'s kind authors `&"standard"` — the same name
##      the constant carried. The evaluator therefore receives the identical `MinionPriority` object
##      it received before, and the acquired `[1, -1]` verdict this hash has encoded since 4-2 is
##      unmoved. Confirmed by the two measurements above being fully explained by their own causes.
##   4. AC 10's CADENCE GATE — PREDICTED A NON-MOVER on the fixture, CONFIRMED. The new third
##      condition on the windup gate reads `is_attack_ready_at`, and the fixture's kind authors a 0.0
##      cadence (the shipped minion authoring), so the cooldown is 0 whenever the gate is consulted.
##      The fixture's unit never reaches the gate at all — it is dead at cause 1's staging and, at
##      cause 2's, alive but never in reach — so the gate is hash-neutral here by two independent
##      routes. Its real proof is test_unit_attack_rhythm.gd, not this hash.
##   5. `rng_state` — PREDICTED A NON-MOVER, on the 4-1 / 4-2 precedent of explicitly testing a
##      predicted non-mover. Nothing about which KIND a cast summons is random: the id -> kind name
##      lookup is a Dictionary `get()` by a known key and the name -> index lookup is a linear walk
##      of an authored list. CONFIRMED by test_the_summon_consumes_no_rng, which is unchanged and
##      still asserts `unit_count` differs across its pair so the comparison cannot be vacuous.
## NOT a cause: the authored `data/balance/balance_config.tres`, whose eleven converted globals moved
## into `unit_kinds` — `_golden_config` is built in-test and never loads it, so the standing `BC/R3`
## isolation survives the conversion intact. Nor is `data/minions/hero_preferring.tres`, the new
## third authored priority (AC 8): the fixture's kind names `standard`, and a file the golden path
## never resolves cannot move the hash.
##
## RE-BASELINED BY STORY 4-2 (minion AI and throttled targeting), 78bd2b97 -> 73a86005, ONE
## re-baseline, TWO MOVERS and TWO NON-MOVERS, each measured SEPARATELY and IN ORDER against the
## inherited 78bd2b97 value — the 4-1 three-step method (312522d8 -> 542a05c0 -> 78bd2b97) repeated.
##   0. AC 9's IDENTITY EXTENSION, ALONE — PREDICTED A NON-MOVER (`4-2/R8`), MEASURED A NON-MOVER.
##      UnitBoard stops being a bare `int` and becomes an ordered collection with per-unit target
##      storage, and PlayerState.to_snapshot() is NOT yet touched. MEASURED UNMOVED at 78bd2b97,
##      bit-identical to the inherited value: `unit_count` stays bound to `size()`, and `size()`
##      returns the same collection length the count returned. The extension is NOT VACUOUS at this
##      step — the fixture's t22 cast appends a record and the record carries its (no-target) pair —
##      it simply is not hashed yet, which is exactly the property `4-2/R8` predicted.
##   1. SNAPSHOT SHAPE (a mover, predicted, `4-2/R2`). PlayerState.to_snapshot() gains
##      `unit_targets`, the per-unit `[slot, index]` pair list (AC 11), on the `unit_count` (4-1) /
##      `discard_size` (3-5a) / `pending_draw_owed` (4-0) precedent. ISOLATED BY CONSTRUCTION rather
##      than by a staged mutation, the 4-1 cause-1 method verbatim: the key ships before the step-7
##      tick is wired, so at this measurement no unit could acquire anything and the key entered the
##      hash at an all-NO-TARGET value. MEASURED: 78bd2b97 ->
##      23518ba4b39c5cd5b70be9b304d8254f4d16a2506c84fd2e9165933f8a3ca922.
##      The key set moves TEN -> ELEVEN here, pinned by test_card_observation.gd.
##   2. BEHAVIOUR — a target ACTUALLY ACQUIRED at a throttle boundary (a mover, predicted). The
##      step-7 seat is wired and _golden_config authors RETARGET_INTERVAL_TICKS 23, so the unit
##      summoned by the t22 cast acquires `[1, -1]` (the opposing HERO — P2's board is empty, so
##      Standard's units-first ordering falls through) at t23 and still holds it at the hashed t24.
##      MEASURED on top of cause 1: 23518ba4 -> 73a86005, the value below.
##   3. `rng_state` — PREDICTED A NON-MOVER, CONFIRMED rather than assumed, on the 3-5b / 4-0 / 4-1
##      precedent. Nothing about tie-break selection consumes RNG (`4-2/R3`: a fixed authored total
##      order, not a random one). Measured against the tightest available pair — same fixture, same
##      cast, targeting reaching a boundary vs. never reaching one — in
##      test_the_throttled_targeting_consumes_no_rng below, which asserts the acquired target
##      DIFFERS across the pair so the rng_state comparison cannot be vacuous (the
##      test_the_summon_consumes_no_rng shape verbatim).
## THE CADENCE VALUE IS NOT A CAUSE, MEASURED AND NAMED rather than assumed either way. An
## unauthored cadence derives to 1 tick (`4-2/R5`(d)'s clamp) and hashes IDENTICALLY to the authored
## 23 — 73a86005 both ways — because the hash sees only the final snapshot and the acquired pair is
## the same whichever boundary produced it. This CORRECTS the Golden Prediction's expectation that an
## unauthored cadence would measure a false NON-MOVE; see RETARGET_INTERVAL_TICKS for the full
## reasoning and for why the throttle's TIMING is proven in test_targeting_service.gd instead.
## NOT a cause either: the authored data/minions/*.tres, and not data/balance/balance_config.tres.
## `_golden_config` is built in-test and the golden path resolves its priority from the SCANNED
## authored set — so `data/minions/` content IS on the golden's own path (AC 4(a)'s ruling is about
## review burden, `4-1/R4`), but its two authored files carry only the parameters that produce the
## measured verdict above; re-tuning the authored retarget interval cannot re-baseline this hash.
## Standing `BC/R3` isolation is intact.
##
## RE-BASELINED BY STORY 4-1 (basic summon resolution), 312522d8 -> 78bd2b97, TWO CAUSES,
## MEASURED SEPARATELY AND IN ORDER against the inherited 312522d8 value:
##   1. SNAPSHOT SHAPE (a mover, predicted). PlayerState.to_snapshot() gains `unit_count`, the
##      per-player board COUNT (AC 9), on the deck_size / hand_size / discard_size precedent. This
##      cause was ISOLATED BY CONSTRUCTION rather than by a staged mutation: the key ships before
##      the fixture injects any effects, so at this measurement the golden fixture's board was
##      structurally incapable of moving off zero and the key entered the hash at an all-zero,
##      no-op value — exactly how 3-5a's `discard_size` and 4-0's `pending_draw_owed` reshape each
##      moved it alone. MEASURED: 312522d8 -> 542a05c042501e5ba45dfd94415f7fe38fabe7779e2db0bfeb0c70af427dcbda.
##   2. BEHAVIOUR — the t22 SUMMON (a mover, CONFIRMED at the readiness gate as `4-1/R6` rather
##      than merely predicted). _golden_effects() and _golden_flags()'s `minions = true` land
##      together: they are ONE cause, not two, because either alone leaves the resolver answering
##      a non-summoning outcome and `unit_count` pinned at 0 for the whole run. The fixture's ONE
##      recorded cast is at CAST_TICK 22 and the hash is taken at t24, so the moved value is LIVE
##      at hash time — which is what puts the resolver inside determinism coverage BY
##      CONSTRUCTION. MEASURED on top of cause 1: 542a05c0 -> 78bd2b97, the value below.
##   3. `rng_state` — PREDICTED A NON-MOVER, and CONFIRMED rather than assumed, on the 3-5b / 4-0
##      precedent of explicitly testing a predicted non-mover. Nothing about which unit appears is
##      random, so appending a record must consume no RNG. Measured against the tightest available
##      pair (same fixture, same cast, effects injected vs. not) in
##      test_the_summon_consumes_no_rng below, which asserts `unit_count` DIFFERS across the pair
##      so the rng_state comparison cannot be vacuous.
## NOT a cause: the authored data/cards/ effect ids, and not data/feature_flags.tres either.
## _golden_effects() builds its map in-test over _golden_deck's opaque ids and _golden_flags()
## constructs its own FeatureFlags — so re-authoring a real card's effect_id, or flipping the
## authored minions flag, cannot re-baseline this hash. Standing `BC/R3` isolation is intact, and
## AC 3's golden-discipline narrowing is a RULING about review burden, not a measured coupling
## (`4-1/R4`).
##
## RE-BASELINED BY STORY 4-0 (hand slot stability), 40eb5554 -> 312522d8, three causes measured in
## both directions. Measured in order, one edit at a time, against the inherited 40eb5554 value:
##   1. SNAPSHOT SHAPE (the ONE mover, predicted): "pending_draw_owed" changes SHAPE from a plain
##      int COUNT to the FIFO of owed SLOT INDICES (AC 4/AC 6). `3-5b/R8`'s "a plain int COUNT and
##      nothing more" is SUPERSEDED; its two-key COUNT bound survives, since no third key ships.
##      Measured LAST, on top of causes 2 and 3 already in place, so it measures the key shape
##      alone: 40eb5554 -> 312522d8, the value below. REVERSE REPRODUCED EXACTLY — re-emitting the
##      key as `pending_draw_owed.size()` with every behavioural change still live returned this
##      fixture to 40eb5554 bit-identically, which is what makes "the shape is the whole cause"
##      a measurement rather than an inference.
##   2. BEHAVIOUR — PREDICTED A NON-MOVER at the readiness gate (`4-0/R7`), MEASURED A NON-MOVER
##      here, and NOT re-derived from scratch per the story's instruction. The concern was a
##      fixture issuing a second cast against the SAME numeric card_slot before the first
##      replacement lands: under the old append model both resolved, under slot stability the
##      second targets a hole and REJECTS (AC 3). The gate read all three hashing fixtures by
##      content and found each issues EXACTLY ONE cast (this file at _play_sequence, CAST_SLOT 3
##      of a 9-wide hand; test_record_file.gd and test_replay_identity.gd, slot 1 of 3). This
##      story changed no hashing fixture's cast count, so the gate's finding stands and the
##      measurement below is its confirmation.
##   3. THE `hand_size` KEY VALUE — added by the gate (`4-0/R7`), and a NON-MOVER IF AND ONLY IF
##      AC 2 is honoured. It is NOT free: this fixture casts at t22 and hashes at t24 against an
##      11-tick delay, so a HOLE IS LIVE AT HASH TIME. `Hand.size()` now means WIDTH, and bound to
##      it the key would read 9 where it reads 8 today. MEASURED, not asserted, and in both
##      directions: bound to `hand.size()` this fixture hashes 2ce19380 — a genuine drift with
##      nothing to do with this story — and bound to `hand.occupied_count()` per `4-0/R1` it holds
##      at the inherited 40eb5554. That measurement is the whole justification for splitting
##      `size()` from `occupied_count()` rather than letting one method carry both readings.
## CAUSES 2 AND 3 WERE MEASURED TOGETHER AND THEN SEPARATED: with cause 1 staged out, the entire
## behavioural change plus the occupancy binding held this fixture at 40eb5554 unmoved; cause 3
## was then isolated by the width mutation above, which moved it. Cause 2 is therefore independently
## confirmed — the only remaining variable in that unmoved run.
## NOT a cause: the marker value itself. `Hand.EMPTY` never enters the snapshot — the hand
## contributes a COUNT, and holes are absent from it by construction (AC 6).
##
## Re-baselined by STORY 3-5b (draw-replacement delay, deck exhaustion, reshuffle, vulnerable
## window), ONE re-baseline, FOUR separately named causes — predicted in the story's Golden
## Prediction and each ISOLATED BY ITS OWN MEASUREMENT and REPRODUCED IN BOTH DIRECTIONS.
## Measured in order, one edit at a time:
##   0. THE ZERO POINT, isolated FIRST from an even earlier step (the 3-3 / 3-5a cause-1 method):
##      PlayerState OWNING both new TimingWindows and the debt counter, the whole pending-draw
##      mechanism PRESENT in match_state.gd but inert, and the fixture priced 0.0 — with NOTHING
##      snapshotted. MEASURED UNMOVED at c4b9f897, the pre-story value. The fields' mere existence
##      is hash-neutral, which is what makes causes 1 and 2 measure the KEYS and nothing else.
##   1. SNAPSHOT SHAPE, KEY ONE (a mover, unconditional and predicted): PlayerState.to_snapshot()
##      gains "pending_draw", the TimingWindow.to_snapshot() dictionary, on the shipped StaminaPool
##      `"regen_delay": _regen_delay.to_snapshot()` precedent. Taken at ALL-ZERO values with the
##      mechanism still inert, so this measures the KEY alone — c4b9f897 -> 9bcfcd7a. Sufficient
##      alone to move the hash.
##   2. SNAPSHOT SHAPE, KEY TWO (a mover, predicted): "pending_draw_owed", the int debt, added ON
##      TOP of cause 1 and still all-zero — 9bcfcd7a -> b5b4da8d. Adding ONE KEY AT A TIME is what
##      separates causes 1 and 2; measuring them together would have left neither named.
##      NOTE, and it corrects the story's own Golden Prediction: its C2 is CAPTIONED "the
##      vulnerable-window snapshot key", but AC 4 rules the snapshot gains EXACTLY TWO keys and
##      names them both, and AC 2 rules that nothing may READ the vulnerable window — a snapshot
##      read is a read. The window is therefore NOT hashed (see player_state.gd for why that is
##      safe: state nothing reads cannot change an outcome), and C2's real subject is this second
##      pending-draw key. Everything else in C2's text — added on top of C1, all-zero, no
##      behaviour change, reversible to C1 bit-identically — describes it exactly.
##   3. THE AUTHORED DELAY, in TWO steps, isolating the SEAT from its CONTENT (the M2 precedent):
##      (a) THE MECHANISM ITSELF — the step-2 tick, the step-6 delivery, the debt increment at the
##          cast, the lazy reshuffle and the vulnerable-window signal all re-enabled, with the
##          fixture still priced 0.0 — MEASURED UNMOVED, still b5b4da8d, BIT-IDENTICAL to cause 2.
##          A zero derived delay degrades EXACTLY to 3-5a's instant refill (TimingWindow.start(0)
##          leaves the window stopped, so the delivery fires inside the cast tick), which is why
##          the delivery is seated AFTER the cast dispatch. The mechanism is structurally
##          incapable of moving this hash on its own.
##      (b) THE FIXTURE COVERAGE VALUE (a mover — the ONE behavioural cause): _golden_config now
##          authors DRAW_DELAY_TICKS 11. The cast lands at t22 and the run hashes at t24, so the
##          replacement is STILL IN FLIGHT on the record: P1's hand_size 9 -> 8, deck_size 8 -> 9,
##          pending_draw running with 9 ticks left and pending_draw_owed 1. b5b4da8d -> 40eb5554,
##          the value below. Guarded by test_golden_sequence_exercises_the_recorded_cast.
##   4. rng_state — PREDICTED A NON-MOVER, MEASURED A NON-MOVER, in BOTH directions. Forward:
##      test_the_recorded_cast_consumes_no_rng stays green — draw_top() consumes nothing whether
##      it fires on the cast tick or eleven ticks later, and _golden_config leaves EIGHT cards in
##      each pile against ONE recorded cast, so this fixture cannot reach a reshuffle at all.
##      REVERSE, and it is what makes the forward half non-vacuous: a reshuffle DOES move
##      rng_state, measured in a separate non-golden fixture driven to exhaustion
##      (test_draw_delay_and_reshuffle.gd and test/integration/test_deck_reshuffle.gd, which
##      additionally proves it on the AUTHORED config).
## REVERSE, both directions reproduced EXACTLY: removing only cause 2's key reproduced 9bcfcd7a
## (cause 2 isolated); re-pricing the fixture delay back to 0.0 reproduced b5b4da8d (cause 3(b)
## isolated, and a genuine one-value toggle).
## NOT a cause: the RESHUFFLE, the VULNERABLE WINDOW or its authored duration — none is reachable
## on this sequence, and the window is not a snapshot key. Nor is CARD CONTENT, still: data/cards/
## remains unreachable from the state harness and _golden_deck / _golden_costs author this
## fixture's own opaque ids. Nor is data/balance/balance_config.tres: _golden_config is built
## in-test, so the BC/R3 property that authored TUNING cannot move this hash survives intact —
## which is exactly why the two new authored values needed their own bespoke audit.
## Previous golden c4b9f897138a2b36dbce11f939b2892379919909c17df1696cde24a75c070e2e
## (story 3-5a, card-mode select + Mode (1) resolution — the record below).
##
## Re-baselined by STORY 3-5a (card-mode select + Mode (1) resolution), ONE re-baseline, THREE
## separately named causes plus ONE predicted-and-measured NON-MOVER — predicted in the story's
## Golden Prediction, each ISOLATED BY ITS OWN MEASUREMENT and REPRODUCED IN BOTH DIRECTIONS.
## Measured in order, one edit at a time:
##   1. SNAPSHOT SHAPE (a mover, unconditional and predicted): PlayerState.to_snapshot() gains
##      "discard_size" beside the deck/hand counts. Taken with the pile EMPTY and no cast in the
##      sequence, so this measures the KEY and nothing else — ad42841e -> a079c111. Sufficient
##      alone to move the hash.
##      Isolated FIRST from an even earlier step, the 3-3 cause-1 method repeated: DiscardPile
##      existing and being OWNED by PlayerState, with nothing snapshotted, MEASURED UNMOVED at
##      ad42841e (the golden test PASSED at that step).
##   2. THE RECORDED CAST's CONTAINER EFFECT (a mover, predicted): P1 commits a cast at
##      CAST_TICK 22 with the price authored at 0.0, so the containers move and the pool does
##      not. deck_size 8 -> 7 and discard_size 0 -> 1 on P1 alone. a079c111 -> 41e0f221.
##      NOTE, and it refines the story's own wording: hand_size does NOT move. AC 5's refill is
##      INSTANT, so the hand goes 9 -> 8 -> 9 inside one tick and the end-of-tick snapshot never
##      sees the gap. The visible movers are the deck and the discard.
##   3. THE FIXTURE COVERAGE VALUE CAST_MANA_COST (a mover, predicted, and separable from cause 2
##      exactly because cause 2 was taken at a zero price): 7.0 is paid out of P1's accumulation,
##      41.5 -> 34.5 at the hashed t24. 41e0f221 -> c4b9f897, the value below.
##   4. rng_state — PREDICTED A NON-MOVER, MEASURED A NON-MOVER. Deck.draw_top() reads
##      _cards[size - 1] and remove_at()s it; it takes no rng argument and consumes nothing, and
##      the only RNG consumer in Deck is shuffle_with_rng (3-3). This story adds no reshuffle
##      (that is 3-5b), so the replacement draw cannot advance the generator. Measured rather
##      than reasoned, and the measurement is KEPT as a permanent test
##      (test_the_recorded_cast_consumes_no_rng, which runs the sequence with and without the
##      cast and compares rng_state directly) because a PRIOR version of this story's Golden
##      Prediction claimed the opposite.
## INTERMEDIATE measurement, isolating the SEAT from the AUTHORED VALUES (the 3-3/3-4 precedent):
## with the whole mechanism in place — the cost-injection seam, the step-6 dispatch, the
## evaluator, the discard container, the Input Map actions and the runner wiring — but the fixture
## committing NO cast, the hash was a079c111, BIT-IDENTICAL to cause 1 alone. The cast machinery
## is structurally incapable of moving this hash without a cast actually landing.
## REVERSE, both directions reproduced EXACTLY: toggling CAST_MANA_COST back to 0.0 reproduced
## 41e0f221 (cause 3 isolated); suppressing the cast as well (CAST_TICK 0, a genuine one-value
## toggle) reproduced a079c111 (cause 2 isolated).
## NOT a cause: CARD CONTENT, still. data/cards/ remains unreachable from the state harness and
## _golden_costs prices this fixture's OWN opaque ids, so adding or repricing a real card can
## never re-baseline this hash — the promise the epic exists to deliver, now extended to costs.
## Nor is the injected cost MAP itself: it is excluded from to_snapshot(), which is also what
## keeps its StringName KEYS out of the hash (Array[StringName].sort() orders by internal POINTER
## on this engine, so such a key would hash green in-process while replay was already broken).
## Previous golden ad42841edcd549660de44a9cf1b6c916b2a090a9c973ec44ec8ecd1960434f08
## (story 3-3, deck/hand/draw — the record below).
##
## Re-baselined by STORY 3-3 (deck, hand, draw), ONE re-baseline, THREE separately named causes
## — predicted in the story's Golden Prediction and each ISOLATED BY ITS OWN MEASUREMENT and
## REPRODUCED IN BOTH DIRECTIONS. Measured in order, one edit at a time:
##   1. SNAPSHOT SHAPE (a mover, unconditional and predicted): PlayerState.to_snapshot() gains
##      "deck_size" beside the "hand_size" key E0 already emitted. Taken with BOTH counts still
##      at zero, so this measures the KEY and nothing else — 98d0c7eb -> b2e58eca. Sufficient
##      alone to move the hash.
##      Isolated FIRST from an even earlier step: Deck and Hand existing and being owned by
##      PlayerState, with nothing snapshotted, MEASURED UNMOVED at 98d0c7eb.
##   2. THE FIXTURE COVERAGE VALUE deck_size, VIA RNG CONSUMPTION (a mover, predicted):
##      _golden_config authors deck_size 17, which is also what sizes the fixture's injected
##      composition, so the step-6 Fisher-Yates finally has a pile to permute. rng_state IS
##      hashed and NOTHING consumed the RNG before this story; the shuffle draws exactly
##      size - 1 = 16 times per player, 32 draws in all. b2e58eca -> 8cb49431. The cause is the
##      SIZE alone and is independent of card identity — see _golden_deck's opaque ids.
##   3. THE FIXTURE COVERAGE VALUE hand_size (a mover, predicted, and dependent on cause 2 —
##      an empty deck fills no hand): _golden_config authors hand_size 9, so each player's deal
##      moves 9 cards off the top and both snapshotted counts change together, 17/0 -> 8/9.
##      8cb49431 -> ad42841e, the value below.
## INTERMEDIATE measurement, isolating the SEAT from the AUTHORED VALUES (the 3-4 and
## stamina-cost precedent): with the whole mechanism in place — the injection seam, the step-6
## deal, the Fisher-Yates, the BalanceConfig fields, the authored .tres values, the runner
## wiring — but _golden_config authoring NEITHER count, the hash was b2e58eca, BIT-IDENTICAL to
## cause 1 alone. The seat is structurally incapable of moving this hash on its own.
## REVERSE, both directions reproduced EXACTLY: toggling hand_size back to 0 reproduced
## 8cb49431 (cause 3 isolated); toggling deck_size back to 0 as well reproduced b2e58eca (cause
## 2 isolated, and the injection gate makes that a genuine one-value toggle).
## NOT a cause: CARD CONTENT. data/cards/ is unreachable from the state harness (no autoloads)
## and _golden_deck authors its own opaque identities, so adding a card can never re-baseline
## this hash — the promise the epic exists to deliver. Deck ORDER is not a cause either: the
## snapshot carries COUNTS only (AC 5), so the order is invisible to the hash even though it is
## what the shuffle produces. Nor is the authored balance_config.tres: _golden_config is built
## in-test, so the BC/R3 property that authored TUNING cannot move this hash survives intact.
## Previous golden 98d0c7ebfdbe01a97622b185a7e3388428793cc87e323751c2ffb5b6f58f81ff
## (story 3-4, mana economy — the record below).
##
## Re-baselined by STORY 3-4 (mana economy and the melee->mana flywheel), ONE re-baseline,
## ONE named cause — predicted in the story's Golden Prediction and confirmed in BOTH
## directions by THREE measurements taken in order:
##   1. THE EVALUATOR SWAP ALONE (AC2's proof artifact) — PREDICTED UNMOVED, MEASURED
##      UNMOVED. MatchState._generate_mana's direct `balance.melee_hit_mana` grant is DELETED
##      and replaced by an EconomyEvaluator lookup over an authored `melee_hit` rule that
##      names that same field, with the melee_mana_generation flag moved onto the rule as
##      data (`required_flag`). Both authored `.tres` rules were present for this
##      measurement, so the rule files' mere existence is measured hash-neutral too. Hash
##      after this step: 96ac5f64... — bit-identical to the pre-story value, which is what
##      makes the refactor provably behaviour-preserving on the melee case.
##   2. THE PASSIVE RUNG ITSELF (BalanceTicks.mana_regen_per_tick + ManaPool.advance_regen +
##      the step-5 seat) — MEASURED UNMOVED, still 96ac5f64... This isolates the SEAT from
##      the AUTHORED COVERAGE VALUE, the same way the 3-0b and stamina-cost passes did: with
##      _golden_config's mana_regen_per_second still defaulting to 0.0 the rung adds 0.0 per
##      tick and ManaPool.add(0.0) is a no-op. Confirms a BalanceTicks seat is structurally
##      incapable of moving the hash on its own (it is load-time config, never snapshotted).
##   3. THE FIXTURE COVERAGE VALUE (a mover — the ONE named cause): _golden_config now
##      authors mana_regen_per_second 75.0 = 1.25 per tick, which activates the passive rung
##      inside the hashed run. Both heroes accumulate 24 x 1.25 = 30.0 on top of their one
##      confirmed hit's 12.0, so both end t24 at 42.0 mana instead of 12.0 — visible in the
##      final snapshot because mana has no sink in E1 and the value is left UNCLAMPED under
##      the 90.0 cap. Guarded by test_golden_sequence_exercises_passive_mana_regen below.
## NOT a cause: snapshot SHAPE is untouched — the passive faucet has NO delay window (sealed
## decision, AC4), so unlike StaminaPool the mana pool gains no TimingWindow and
## ManaPool.to_snapshot() still emits exactly {current, maximum}. Nor is the rule set: the
## authored `.tres` carry no gameplay numbers (only which balance field each faucet reads),
## so the BC/R3 property that authored tuning cannot move this hash survives intact.
## Previous golden 96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b
## (story 3-0b Pass 2, below; held unchanged through 3-1).
##
## Re-baselined by STORY 3-0b PASS 2 (AC5 per-phase movement multipliers + AC6 attack
## lunge), ONE re-baseline, TWO predicted causes — one moved, one measured non-moving,
## exactly the fork the story's Golden Prediction section recorded in advance:
##   1. AC5 PER-PHASE MULTIPLIERS — PREDICTED A MOVER, MEASURED A MOVER, but the SEAT is
##      not the cause: the AUTHORED COVERAGE VALUE is. The flat attack_move_speed_multiplier
##      is replaced by three per-phase fields selected via HeroState.attack_phase(); at the
##      hashed t24 P1 is IDLE and P2 is in its t15 swing's RECOVERY with move (1,0), so the
##      RECOVERY field alone is visible in the hash. _golden_config authors 0.25/0.5/0.75
##      (windup/active/recovery) where the flat field was 0.0, moving P2's final velocity
##      from ZERO to 6.0 * 0.75 = 4.5 on +X.
##      EMPIRICAL ISOLATION, both directions: toggling ONLY the recovery value back to 0.0
##      (windup 0.25 / active 0.5 left in place) reproduced the OLD golden 7fbb4b7f exactly.
##      That measures two things at once — the per-phase SEAT itself is hash-NEUTRAL when
##      the visible phase carries the old flat value, and the windup/active coverage values
##      are MEASURED NON-MOVERS (attack velocities on earlier ticks are per-tick transients
##      overwritten before t24 — the 1-5 cause-(c) lesson holding a third time).
##   2. AC6 ATTACK LUNGE — PREDICTED A MOVER, MEASURED A NON-MOVER (the 1-9 cause-2 shape).
##      The hash after AC6 landed was BIT-IDENTICAL to the hash after AC5 alone. REASON: the
##      lunge is ruled live during WINDUP and ACTIVE only, and at t24 P1 is IDLE while P2 is
##      in RECOVERY — no lunge term exists at the hashed tick — while the lunge velocities on
##      the swing ticks that DO carry it are the same per-tick transients as above. The
##      fixture was deliberately NOT redesigned to make the prediction come true; the
##      authored 2.0 is path coverage, and test_golden_sequence_exercises_per_phase_movement
##      _and_lunge proves that coverage is real (P1's t5 velocity IS the lunge alone).
## Step-2 INTERMEDIATE measurement (AC5 in, AC6 not yet written):
## 96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b — identical to the final
## value below, which IS the measurement that makes AC6 a non-mover.
## NOT a cause: snapshot SHAPE is untouched — the per-phase lookup adds no state (the phase
## was already derived from which window is running) and the lunge reads facing LIVE rather
## than storing an entry-locked direction, so unlike the roll it adds no snapshot field.
## Previous golden 7fbb4b7f589251d25a13d6b49138b416266031e124cdae1c07e99e0f4fc119d1
## (the stamina-cost corrective pass below; held unchanged through 3-0b Pass 1, whose
## step/pause and window-countdown work is runner/debug-only and reaches no state field).
##
## Re-baselined by the STAMINA-COST CORRECTIVE PASS (E3-RG/R2; decision (d) RESOLVED at
## DP/R2 — the basic attack costs stamina), ONE re-baseline, ONE named cause: the basic
## attack gained a stamina cost. Reconciled in both directions, two contributing halves
## measured apart:
##   1. THE SEAT ITSELF (a mover): the attack's spend follows the ROLL precedent verbatim
##      (operator ruling), so attack ENTRY restarts the post-spend regen-delay window — and
##      does so even at a 0.0 cost, since the window restarts on any SUCCESSFUL spend. On
##      this sequence P2's t15 attack alone costs 3 regen ticks: P2 stamina 30.0 -> 27.0.
##      Sufficient alone to move the hash.
##   2. AUTHORED COVERAGE VALUE (a mover): _golden_config authors attack_stamina_cost 6.0,
##      paid at P1's t1 attack and t9 chain and at P2's t15 attack. P1 40 -> 34 -> (regen)
##      39 -> 33 -> (regen) 38, so the t17 roll now spends from 38 (23.0 post-spend, 28.0
##      at t24 instead of 25.0/30.0); P2 20 -> 14 -> 21.0 at t24.
## Step-2 INTERMEDIATE measurement (mechanics in, _golden_config's cost still 0.0):
## d101980f315d43265325d68674dae79f67acc7210c0ecd8c092cc45df9581512 — isolates cause 1 from
## cause 2, and reproduced by toggling the authored 6.0 back off after the fact.
## NOT a cause: snapshot SHAPE is untouched — the attack seat adds no field, and the
## regen-delay window it restarts was already snapshotted (StaminaPool.to_snapshot, D8).
## Previous golden 338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2
## (story 1-9, roll with i-frames — the three causes recorded below; held unchanged through
## 3-0a and the melee-damage corrective, which moved no authored value the golden reads).
##
## Re-baselined in story 1-9 (roll with i-frames), ONE re-baseline; the gate predicted
## THREE causes (1-9/R7) and measurement reconciled them in both directions:
##   1. SNAPSHOT SHAPE (a mover, as predicted): HeroState.to_snapshot() gains
##      "roll_direction" on both players; P1's t17 roll stores (-1, 0, 0) via the
##      neutral-stick FACING FALLBACK. Sufficient alone to move the hash.
##   2. EXERCISED PATH + AUTHORED VALUE — PREDICTED A MOVER, MEASURED NON-MOVER:
##      _golden_config authors roll_distance 3.0 and t17-21 velocity is the locked roll
##      override, but roll velocities are per-tick transients overwritten before the
##      hashed final t24 snapshot (the 1-5 cause-(c) lesson holding again). EMPIRICAL:
##      the step-2 intermediate hash was IDENTICAL with and without the roll_distance
##      line — the authoring is path coverage, not a hash cause.
##   3. DELIBERATE RESTRUCTURE (a mover, as predicted): P2 gains an attack at t15
##      (active 18-21, over P1's roll iframes); the t19 arrival DROPS on the iframe
##      grace tick and the t20 arrival from the SAME swing lands FULL damage — P1
##      120 -> 108 HP, P2 mana 0 -> 12 on the hashed record (guarded by
##      test_golden_sequence_exercises_iframe_negation below).
## Step-2 INTERMEDIATE measurement (mechanics in, OLD sequence unchanged):
## 3138e35bfb1af9b4d86e94b198dc86e5156c200589b15f38194d3713ff736874 — isolates causes
## 1+2 from 3 (and the cause-2 toggle run above pins the movement to cause 1 alone).
## The 1-9/R2 iframe grace marker is a per-tick transient excluded from the snapshot
## (HeroState._roll_iframe_closed_this_tick, the _deflect_closed_this_tick mirror) — no
## snapshot contribution, exactly as gated.
## Previous golden 298c40f65d5f3191d2d7c2eacdccdd443c49fe24b0492d66e088318ed840f23f
## (story 1-8, block and deflect: four-field facts + the outcome ladder; two named
## causes — the t5 grace-tick deflect + the deliberate two-span/defense-values
## restructure; snapshot shape verified not a cause).
## Previous golden 39564e83831819d4486d6216e9030535029de1298168ebeee720ab4812705353
## (story 1-5, basic attack chain: dedupe snapshot shape + authored combat-economy
## values + the t5 synthetic hit; held unchanged through 1-6, 1-7, and 1-7b — three
## consecutive NONE predictions confirmed by measurement).
## Previous golden 871f8132f28f2192ec0edb0a0081b1e61ec87924c027a0ee2ddfdb1018f02a5c
## (story 1-4, stamina economy: snapshot shape + authored stamina values).
## Previous golden 40b5a8041c327b416ca235af65fc7c05f494d8b1d7a2e2b2761190b86da1d613
## (story 1-3b, DEBT A retirement: apply_balance on the golden path + widened sequence).
## Previous golden d3f42defd2f442056d22eb43d480ef665f5e1083d3458b1db4ffdf48b932bcf7
## (story 1-3, snapshot-shape re-baseline).
## Previous golden 312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c
## (story 4-0, hand slot stability: pending_draw_owed shape).
## Previous golden 78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5
## (story 4-1, basic summon resolution: unit_count key + the t22 summon).
## Previous golden 73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5
## (story 4-2, throttled targeting: unit_targets key + the acquired pair; held unmoved by 4-3).
##
## ---------------------------------------------------------------------------------------------
## STORY 4-3a RE-BASELINE (AC 9, `4-3a/R17`) -- ONE re-baseline, TWO causes PREDICTED, ONE MEASURED
## AS A REAL MOVER. Both were measured INDEPENDENTLY and in BOTH DIRECTIONS before this line moved:
##
##   CAUSE 1, the `unit_hp` snapshot key -- A REAL MOVER, and the only one.
##     73a86005 -> 35c38c0e, measured with cause 2 held OFF. The golden fixture summons one unit at
##     t22 (`f.minions = true` in _golden_flags, `unit_count` 1 at the hash tick), so the new key
##     enters carrying that unit's authored maximum. THE FIXTURE IS DELIBERATELY NOT EXTENDED TO
##     INJURE A UNIT -- that would be a third cause and is out of this story's re-baseline scope --
##     so this is the snapshot-SHAPE cause only, the 4-1 `unit_count` / 3-5a `discard_size` pattern.
##
##   CAUSE 2, the widened `[attack_index, slot, index]` swing-dedupe key -- PREDICTED A MOVER,
##     MEASURED A NON-MOVER. With cause 1 held OFF and the widened key ON, this file hashed
##     73a86005 EXACTLY -- the unmoved golden. The MECHANISM was measured rather than guessed: at
##     the hash tick (t24) BOTH heroes' `swing_dedupe.records` dictionaries are EMPTY, because every
##     record opened by the t5/t13/t19/t20 facts has passed its grace tick and been erased. A
##     widened key over an empty record set has nothing to hash. It would move a fixture that
##     hashed MID-SWING, which is what test_contact_resolution.gd's dedupe snapshot pin does -- and
##     that pin DID move, which is where the shape change is proven instead.
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with BOTH causes
##     held off, this file hashed 73a86005 -- so every other change this story ships (the widened
##     `push_contact` target address, the `TargetingService` array-of-living-indices signature, the
##     two liveness seats, unit damage, death, actor freeing, FORMAT_VERSION 3) is a MEASURED golden
##     NON-MOVER. The mover is the key, and nothing else.
##
## ---------------------------------------------------------------------------------------------
## STORY 4-3b: THE NINTH RE-BASELINE, 35c38c0e -> 4a089063. ONE CAUSE, MEASURED IN BOTH DIRECTIONS,
## and TWO PREDICTED NON-MOVERS MEASURED RATHER THAN CITED.
## ---------------------------------------------------------------------------------------------
##   THE FIXTURE STRUCTURALLY CANNOT REACH A UNIT ATTACK, which is what makes the accounting short.
##     This file runs `MatchState` ALONE -- no runner, no physics, no `Area3D`, no overlap query;
##     its contact facts are HAND-AUTHORED literals pushed straight through the seam, every authored
##     attacker is a HERO and every authored target is a hero; and its single unit is summoned by
##     the t22 cast, two ticks before the hash at t24. That unit has no hitbox to overlap, nothing
##     to overlap with, and no reach fact -- so it cannot windup, cannot swing, and cannot register
##     a hit. THE FIXTURE IS NOT EXTENDED (`4-3b/R22`), for the reason `4-3a` declined: giving it
##     physics or a synthetic hitbox would make the determinism golden depend on the very machinery
##     `D3(b)`/`A2` keep out of `src/state/`.
##
##   THE ONE CAUSE: the SNAPSHOT KEY SET, twelve -> eighteen. The fixture's summoned unit
##     contributes its IDLE-but-present attack state from t22 -- phase IDLE, countdown 0, a zero
##     locked direction, counter 0, flag false -- plus an empty `unit_swing_dedupe`. A value that
##     crosses ticks and decides an outcome does not sit outside the hash (`4-3a/R17`), so all six
##     keys are hashed and their mere PRESENCE is the mover.
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with the six new keys
##     held off `PlayerState.to_snapshot()` and EVERYTHING ELSE this story ships left in place, this
##     file hashed 35c38c0e EXACTLY -- the pre-story golden, unchanged. Measured at the dev pass by
##     deleting those six lines, running this file, and restoring from a SHA256-verified out-of-repo
##     copy.
##
##   NON-MOVER 1, THE WIDENED ATTACKER ADDRESS AND THE KIND MARKER (AC 3 / AC 13), MEASURED not
##     asserted: it falls out of the reverse-direction run above. Every hand-authored fact in this
##     fixture is a hero attacker, and `[slot, -1]` with `CONTACT_STRIKE` resolves through the
##     widened seam to the identical `PlayerState` and the identical hashed outcomes the bare int
##     produced -- if it had not, the keys-removed run would have diverged from 35c38c0e and it did
##     not. The marker is likewise a non-mover for a structural reason: facts are per-tick and never
##     snapshotted.
##
##   NON-MOVER 2, THE UNIT DEDUPE CAUSE, PREDICTED FALSIFIED AND MEASURED FALSIFIED -- recorded
##     because `4-3a`'s own gate had a prediction reversed by not measuring one. `4-3a/R27`
##     falsified the hero-side dedupe cause because every record had EXPIRED by t24; here the reason
##     is STRONGER: the unit's records CANNOT EXIST AT ALL by the hash tick, because the fixture's
##     unit never swings. Pinned permanently by
##     `test_the_fixtures_unit_reaches_the_hash_tick_idle_with_no_dedupe_record` below, so the claim
##     is a live assertion rather than a comment.
##
##   CAUSES UNREACHABLE HERE, named so nobody reads a green golden as coverage of them: the phase
##     progression through real tick counts, the cleave and its canonical order (AC 4), the
##     cross-attacker ordering (AC 5), the friendly-fire gather filter (AC 6), the attacker-kind
##     dispatch (AC 14), the killed-mid-swing drop (AC 15), and the reach trigger INCLUDING its
##     throttled cadence (AC 13 -- there is no runner here, so the probe pass never runs at all).
##     They are proven in test_unit_attack_rhythm.gd, test_contact_resolution.gd,
##     test_unit_damage_and_death.gd and test/integration/test_unit_attack_live.gd.
## ---------------------------------------------------------------------------------------------
const GOLDEN := "a96b123e67ef8330b5bb07c1bafefaf5204e9bf9982eded936f8d69b29afa522"

## Story 4-4 (AC 6/AC 12): the golden fixture's authored MINION KIND values — coverage-not-feel like
## every number in `_golden_config`, and deliberately NOT the authored 9.0 / 3.0.
##
## `GOLDEN_UNIT_MAX_HP` IS THIS STORY'S CAUSE-2 STAGING KNOB. At 0.0 the t22 summon's record enters
## DEAD, exactly as it did through 4-3a/4-3b when `unit_max_hp` was an unauthored 0.0 default — which
## is what let cause 1 (the two new snapshot keys) be measured in isolation. At 7.0 the record enters
## ALIVE and `unit_hp` moves off 0.0, which is cause 2. Both measurements are recorded above.
const GOLDEN_UNIT_MAX_HP := 7.0
const GOLDEN_UNIT_DAMAGE := 2.0

const SEED := 1337
const MAX_HP := 120.0
const MOVE_SPEED := 6.0
const MAX_STAMINA := 40.0
const MAX_MANA := 90.0
## Story 3-4 (AC 7): the passive faucet's fixture COVERAGE rate, expressed per tick because
## that is the form the ladder consumes. 75.0 per second / 60 Hz = 1.25 — see _golden_config.
const PASSIVE_PER_TICK := 1.25
## Story 3-3 (AC 12): the deck/hand fixture COVERAGE values — coverage, NOT feel, like every
## number in _golden_config. Deliberately NOT the authored 20 / 4, and deliberately DISTINCT
## from every other count this fixture carries ({2, 3, 4, 5, 6, 10, 12, 15, 20, 24, 40, 60, 75,
## 90, 120, 180}), so a selector bug that read the wrong field lands on a different number and
## MOVES the hash rather than silently coinciding with one. The derived counts are distinct too:
## 17 - 9 = 8 cards left in the pile and 16 Fisher-Yates draws per player, neither of which
## appears anywhere else here either.
const DECK_SIZE := 17
const HAND_SIZE := 9

## Story 3-5a (AC 12): the CAST fixture values — coverage, NOT feel, like every number here.
##
## THE FIXTURE MUST AUTHOR ITS OWN CAST-COST CONTENT. data/cards/ is unreachable from the state
## harness (no autoloads) and _golden_deck's ids are nothing the card library contains, so without
## costs authored HERE every card-shaped cause would measure a FALSE NON-MOVER: the cast would
## simply be refused and nothing would happen. That is why the injection below exists at all.
##
## CAST_TICK 22 puts the cast on a tick where P1 is IDLE (the t17 roll ends t21), so no action
## state is in flight around it and the cast's effect on the record is unambiguous. P1 holds
## 12.0 + 22 * 1.25 = 39.5 mana by then, comfortably above the price, so the cast LANDS rather
## than measuring a refusal by accident.
## CAST_SLOT 3 and CAST_MANA_COST 7.0 are both DISTINCT from every other number this fixture
## carries, so a selector bug that read the wrong field lands on a different value and MOVES the
## hash rather than silently coinciding with one.
const CAST_TICK := 22
const CAST_SLOT := 3
const CAST_MANA_COST := 7.0

## Story 3-5b (AC 1): the DRAW-REPLACEMENT DELAY's fixture coverage value — coverage, NOT feel,
## like every number here, and 11 ticks is NOT the authored 1.0 s / 60 ticks. Chosen DISTINCT from
## every other count this fixture carries ({2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 16, 17, 20, 22, 24,
## 40, 60, 75, 90, 120, 180}) so a selector bug that read the wrong tick field lands on a different
## number and MOVES the hash rather than silently coinciding with one.
##
## LOAD-BEARING THAT IT IS NONZERO, per the standing lesson that a fixture which does not author
## its own content measures a false non-move: the cast lands at t22 and the run hashes at t24, so
## 11 ticks leaves the replacement STILL IN FLIGHT on the hashed record — hand one LOWER, deck one
## HIGHER, and a running window plus a debt of 1 inside the hash. Priced at 0.0 the mechanism
## degrades to 3-5a's instant refill and measures nothing, which is exactly what makes it the
## separable second half of golden cause C3.
const DRAW_DELAY_TICKS := 11

## Story 4-2 (AC 7, `4-2/R5`): the RETARGET CADENCE's fixture coverage value — coverage, NOT feel,
## like every number here, and 23 ticks is NOT the authored 0.2 s / 12 ticks. Chosen DISTINCT from
## every other count this fixture carries ({2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 15, 16, 17, 20, 22, 24,
## 40, 60, 75, 90, 120, 180}) so a selector bug that read the wrong tick field lands on a different
## number and MOVES the hash rather than silently coinciding with one.
##
## 23 IS CHOSEN SO EXACTLY ONE BOUNDARY FALLS INSIDE THE UNIT'S LIFETIME. The recorded cast lands at
## t22 and the run hashes at t24, so with 23 the only boundary in range is t23 (`23 % 23 == 0`;
## the next is t46, past the run) — the spawned unit acquires its target on t23 and STILL HOLDS IT
## at the hashed t24. That is what makes this story's behavioural cause real rather than nominal:
## the acquired `[slot, index]` pair is live in the hashed record, and it is also the ONE tick of
## PERSISTENCE the golden can see (t24 is not a boundary, and the target survives it).
##
## AUTHORING IT IS A TASK, NOT A HOPE (`4-2/R5`) — BUT THE MEASURED REASON IS NOT THE PREDICTED ONE,
## AND THE DIFFERENCE IS RECORDED HERE RATHER THAN SMOOTHED OVER. The Golden Prediction expected an
## unauthored cadence to measure a FALSE NON-MOVE. It does not, for a reason the prediction did not
## account for: BalanceTicks clamps the derived interval to >= 1 (`4-2/R5`(d)), so an unauthored 0.0
## means EVERY TICK and the target is acquired anyway. Measured, both ways: unauthored and authored
## at 23 hash IDENTICALLY (73a86005 either way).
##
## SO THE CADENCE VALUE IS HASH-NEUTRAL FOR THIS FIXTURE, and it cannot be otherwise: the hash sees
## only the FINAL snapshot, the acquired pair is `[1, -1]` whichever boundary produced it, and this
## fixture's candidate set never changes, so no two boundaries can disagree. An interval with NO
## boundary between the t22 cast and the hashed t24 (7, say) WOULD move the hash — by leaving the
## unit with no target at all, which would forfeit this story's behavioural golden cause. The two
## properties are not simultaneously reachable without a second summon or a hero death inside the
## recorded sequence, neither of which this story adds.
##
## WHAT THIS LINE THEREFORE BUYS is that the golden sits on the THROTTLED path rather than the
## every-tick one — per-frame-per-unit retargeting is exactly what the project-context Performance
## Rule forbids, and without this line the golden would cover that path while looking healthy. The
## throttle's TIMING is proven where it can be: AC 7's behavioural-negative pair in
## test_targeting_service.gd, which changes the candidate set mid-interval and asserts the target is
## unchanged until the boundary tick and changed AT it. Named here so no later reader mistakes this
## fixture for coverage of the cadence itself.
const RETARGET_INTERVAL_TICKS := 23

## Movement pairs [p1, p2], cycled over the run (tick t uses MOVES[(t - 1) % 6]).
const MOVES := [
	[Vector2(1, 0), Vector2(-1, 0)],
	[Vector2(0, 1), Vector2(0, -1)],
	[Vector2(1, 1), Vector2(1, 0)],
	[Vector2(-1, 0), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(-1, -1)],
	[Vector2(0.5, 0.5), Vector2(1, 0)],
]

## Recorded action overlay, keyed by tick (windows per _golden_config: windup 3, active 4,
## recovery 6, chain 5, deflect 4, roll iframe 2, roll duration 5). P1: attack t1 (swing
## 0: windup 1-3, active 4-7, recovery 8-13, chain window 8-12), chain t9 (swing 1:
## windup 9-11, active 12-15, recovery from 16), roll-cancel t17 (roll 17-21, iframe
## covers arrivals 17-18 with grace t19, IDLE t22; t17's move pair is (0,0), so the roll
## direction comes from the FACING FALLBACK — facing (-1,0) from t16). P2 (story 1-8):
## TWO block spans — press t1 held through t5 (deflect window runs t1-4, grace t5),
## released t6; press t7 held through t14 (window t7-10, grace t11), released t15.
## P2 (story 1-9): attack t15 — the release tick; the block exit and the attack entry
## fire the same tick (windup 15-17, active 18-21), putting P2's active window over P1's
## roll iframes.
const TICKS := 24
const P1_PRESS := {1: [&"attack"], 9: [&"attack"], 17: [&"roll"]}
const P2_PRESS := {1: [&"block"], 7: [&"block"], 15: [&"attack"]}
const P2_BLOCK_HELD: Array = [[1, 5], [7, 14]]
## Story 1-5: synthetic contact facts fed through the push_contact seam, keyed by the
## tick they are pushed on (BEFORE that tick's advance — the runner's step-2 position).
## Payload [attacker_slot, target_slot, attack_index, target_to_attacker] — the
## FOUR-field plain recordable fact (X5; story 1-8 R-B3 widened the original three-int
## shape with the world-space direction the runner reports from positions). The t5 fact
## models a contact gathered on t4, P1's first active tick of swing 0 (windup 1-3,
## active 4-7), arriving with the F1 one-tick lag — it lands on the deflect window's +1
## GRACE tick (R-N2) against a front-facing blocker (P2 faces (-1,-1)-ward at t5) and
## DEFLECTS by design. The t13 fact (swing 1, active 12-15, gathered t12) arrives past
## the second span's grace (t11) against a front-facing blocker (P2 faces (-1,0) at
## t13) and resolves as an ordinary BLOCK by design. Story 1-9: the t19/t20 pair targets
## the ROLLING P1 from P2's t15 swing (active 18-21) — the t19 arrival (gathered t18,
## P2's first active tick) lands on P1's iframe GRACE tick (iframe covers 17-18, 1-9/R2)
## and is DROPPED; the t20 arrival (gathered t19) is one past the grace and lands FULL
## damage on the still-rolling P1 (iframes over, roll not) — the sequence exercises both
## sides of the iframe boundary from the SAME swing by design.
const CONTACTS := {
	5: [[0, 1, 0, Vector2(-1, -1)]],
	13: [[0, 1, 1, Vector2(-1, 0)]],
	19: [[1, 0, 0, Vector2(1, 0)]],
	20: [[1, 0, 0, Vector2(1, 0)]],
}


## The golden's balance — constructed IN-TEST on purpose, never loaded from
## data/balance/*.tres: the golden guards determinism, not tuning, so playtest edits to
## the authored .tres must never move this hash. Tick counts (authored as ticks/60.0 so
## they are explicit): windup 3, active 4, recovery 6, chain window 5, deflect 4,
## roll iframe 2, roll duration 5, chain length 3 — test_action_state.gd's shape.
##
## Stamina values (story 1-4) are chosen for COVERAGE, not feel: the t17 roll spends 15
## (38 -> 23 — the two attack spends precede it since E3-RG/R2), the 3-tick delay suppresses
## exactly t17-t19 (the window advances in step 2, step 5 reads the result), regen (60/s =
## 1.0/tick) runs t20-t24 -> 28.0 at t24 — below max and above the post-spend value, so the
## hashed final snapshot encodes BOTH the spend and the regen (a rate fast enough to refill
## by t24 would hash identically to a run that never spent).
##
## Combat-economy values (story 1-5), same coverage-not-feel principle: damage 10% of the
## TARGET's 120 max HP = 12.0 per hit (t5 hit -> P2 at 108, non-full at t24 — no HP
## regen exists), melee_hit_mana 12.0 (t5 hit -> P1 at 12 of 90, non-zero at t24 — no
## mana sink exists in E1).
##
## Story 3-0b (AC5) replaced the flat attack_move_speed_multiplier — authored 0.0 here, the
## live full-root shape, and empirically hash-neutral for THIS sequence — with three
## per-phase fields, authored here as THREE DISTINCT COVERAGE VALUES (0.25/0.5/0.75), NOT
## the live 0.0/0.0/0.0. Only RECOVERY is visible in the hash: at the hashed t24 P1 is IDLE
## and P2 is in its t15 swing's recovery (windup 15-17, active 18-21, recovery from 22) with
## move pair MOVES[23 % 6] = (1,0), so P2's final velocity is 6.0 * 0.75 = 4.5 on +X. The
## windup/active values are path coverage only — attack velocities on earlier ticks are
## per-tick transients overwritten before t24 (the 1-5 cause-(c) lesson). They are authored
## DISTINCT anyway so a selector bug that read the wrong field for recovery would land on a
## different value and move the hash rather than silently coinciding.
func _golden_config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = MOVE_SPEED
	c.max_stamina = MAX_STAMINA
	c.stamina_regen_per_second = 60.0          # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 15.0
	# Stamina-cost corrective pass (E3-RG/R2), coverage-not-feel like every value here — 6.0
	# is NOT the authored 12.0. Chosen so BOTH attack spends stay legible on the record and
	# neither is erased by a clamp at the 40.0 maximum: P1 t1 40 -> 34, regen t4-t8 -> 39
	# (still below max); t9 chain 39 -> 33, regen t12-t16 -> 38 (still below max); t17 roll
	# 38 -> 23, regen t20-t24 -> 28 at the hashed final tick. P2 pays it once at its t15
	# attack (20 -> 14, regen t18-t24 -> 21).
	c.attack_stamina_cost = 6.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.attack_windup_move_speed_multiplier = 0.25
	c.attack_active_move_speed_multiplier = 0.5
	c.attack_recovery_move_speed_multiplier = 0.75
	# Story 3-0b (AC6): authored for PATH COVERAGE, not the hash — the roll_distance
	# precedent exactly (1-9 cause 2, predicted mover / measured non-mover). The lunge is
	# scoped to windup/active, both players are past those phases at the hashed t24, and
	# attack velocities on earlier ticks are per-tick transients overwritten before it. 2.0
	# is NOT the authored 0.5: like every value here it is chosen to be loud enough that a
	# scope bug (a lunge leaking into recovery) would move the hash rather than round away.
	c.attack_lunge_distance = 2.0
	# Story 3-1 (AC 6, 3-1/R5): a fixture SIGNATURE move, NOT a value change. 90.0 is exactly
	# what the MAX_MANA constant fed through MatchState's constructor before AC1 removed the
	# positional floats; ManaPool.to_snapshot() emits {current, maximum}, so any other value
	# here would move the golden. The GOLDEN PREDICTION IS NONE and this line is why.
	c.max_mana = MAX_MANA
	c.melee_hit_mana = 12.0
	# Story 3-4 (AC 7) — THE named cause of this story's re-baseline, and the one line that
	# makes the passive rung visible to the hash at all. Coverage-not-feel like every value
	# here: 75.0/s = 1.25 per tick is NOT the authored 0.25/s, and it is deliberately
	# DISTINCT from this fixture's stamina rate (60.0/s = 1.0 per tick) so a selector bug
	# that read stamina_regen_per_tick for the passive rule would land on a different value
	# and move the hash rather than silently coinciding. Chosen to stay clear of the 90.0
	# cap over 24 ticks (30.0 accrued, plus one 12.0 hit = 42.0 at t24 — accumulating and
	# UNCLAMPED on the record, so the hash encodes the accumulation itself), and exactly
	# representable in binary so every expected value below is an exact equality.
	# Without this line the rung is hash-NEUTRAL: _golden_config builds its fixture in-test
	# and never loads data/balance/balance_config.tres, so the field would default to 0.0
	# and the passive tick would add nothing (measured — see the re-baseline record above).
	c.mana_regen_per_second = 75.0
	c.deflect_window_seconds = 4.0 / 60.0
	# Defense values (story 1-8), coverage-not-feel: multiplier 0.25 makes the t13
	# blocked hit chip exactly 3.0 (117 non-full at t24); deflect cost 20 leaves P2
	# MID-REGEN at t24 (40 - 20 at t5, regen only after the second span releases:
	# t15-t24 -> 30.0 — below max, above post-spend, so the hashed final state encodes
	# the deflect spend AND the regen); arc 180 = the authored front half-plane.
	c.block_damage_multiplier = 0.25
	c.deflect_stamina_cost = 20.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	# Story 1-9 (gate finding 1-9/N1): authored so the t17 roll exercises the REAL
	# displacement override (2-tick iframe / 5-tick duration -> 36.0 u/s while rolling).
	# Roll velocities are per-tick transients overwritten before t24, so this value
	# cannot reach the hashed final snapshot — authored for path coverage, not the hash
	# (the 1-5 cause-(c) lesson, re-confirmed empirically in the 1-9 record).
	c.roll_distance = 3.0
	# Story 3-3 (AC 12) — the TWO lines that make this story's causes visible to the hash at all,
	# and the only two that changed between measurements M2, M3 and M4. Without deck_size the
	# fixture injects nothing, the Fisher-Yates draws ZERO times and the RNG state never moves
	# (a MEASURED non-mover); without hand_size the deal fills nothing and the snapshotted counts
	# stay at deck_size / 0. Neither is loaded from data/balance/balance_config.tres — the
	# standing property that authored TUNING cannot move this hash is untouched.
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	# Story 3-5b (AC 1) — the ONE line that makes this story's cause C3 visible to the hash, and
	# the reason C3 splits into a seat half and a content half. Priced at 0.0 the pending-draw
	# mechanism is structurally incapable of moving this hash (the replacement arrives inside the
	# cast tick, exactly as 3-5a drew it); priced NONZERO the t22 cast is still owed a card at the
	# hashed t24. Not loaded from data/balance/balance_config.tres — the standing property that
	# authored TUNING cannot move this hash is untouched.
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / 60.0
	# Story 4-2 (AC 7, `4-2/R5`) — the ONE line that puts the THROTTLE, and not merely the target,
	# inside determinism coverage. Unauthored it derives to 1 tick (the clamp) and every tick
	# retargets; authored at 23 exactly one boundary (t23) falls between the t22 cast and the hashed
	# t24. Not loaded from data/balance/balance_config.tres — the standing property that authored
	# TUNING cannot move this hash is untouched. See RETARGET_INTERVAL_TICKS for both measurements.
	c.minion_retarget_interval_seconds = float(RETARGET_INTERVAL_TICKS) / 60.0
	# Story 4-4 (AC 6/AC 12) — THE PER-KIND CONVERSION, and the line that carries this story's
	# SECOND named re-baseline cause. Before this story the fixture authored NO unit fields at all,
	# so `unit_max_hp` defaulted to 0.0 and the t22 summon put a record on the board that was DEAD on
	# arrival (hp 0.0, the value `unit_hp` has carried in this hash since 4-3a). The four globals are
	# gone; a kind must be authored or the cast resolves successfully and puts NOTHING on the board,
	# which would silently delete `unit_count`/`unit_hp` coverage rather than re-baseline it.
	#
	# THE TWO CAUSES ARE MEASURED SEPARATELY BY STAGING THIS ONE VALUE (see the re-baseline record
	# at the top of this file): authored at 0.0 the record still enters DEAD and the ONLY delta from
	# the inherited hash is the two new snapshot keys (cause 1, the shape); authored at
	# GOLDEN_UNIT_MAX_HP the record enters ALIVE and `unit_hp` moves (cause 2, the conversion's
	# content). Coverage-not-feel like every value here — 7.0 is NOT the authored 9.0.
	#
	# `standard` is named deliberately: it is the priority the REMOVED hardcoded
	# `TargetingService.PRIORITY_STANDARD` lookup used to select, so the acquired-target verdict this
	# hash has encoded since 4-2 is unmoved by AC 7's per-kind priority read. The durations are 0 —
	# the fixture's unit never swings, and authoring a rhythm for a path this sequence does not take
	# would be coverage of nothing (the `reshuffle_vulnerable_window_seconds` reasoning verbatim).
	c.unit_kinds = UnitKindFixture.minion_only(GOLDEN_UNIT_MAX_HP, GOLDEN_UNIT_DAMAGE, 0, 0, 0, 2.0)
	# The HERO-attacker half of the old `unit_damage_per_hit`. Authored for completeness; the
	# fixture's hero never swings at a unit, so it is hash-neutral by construction.
	c.hero_damage_to_unit = GOLDEN_UNIT_DAMAGE
	# reshuffle_vulnerable_window_seconds is deliberately NOT authored here. _golden_config leaves
	# EIGHT cards in each pile against a single recorded cast, so the fixture cannot reach a
	# reshuffle and the window can never open — authoring a duration for a path this sequence does
	# not take would be coverage of nothing. The reshuffle's proof is its own headless test.
	return c


## Story 3-3 (AC 12): the golden's deck CONTENT, built in-test with OPAQUE identities — the
## _golden_config principle applied to the other injected resource. data/cards/ is unreachable
## from the state harness (no autoloads) and these ids are nothing the card library contains, so
## ADDING A CARD MUST NEVER RE-BASELINE THIS HASH. That is not incidental: card identity cannot
## reach the hash at all, because the snapshot carries COUNTS only (AC 5) and the Fisher-Yates
## draw count depends on the pile's SIZE alone.
##
## The fixture plays the RUNNER's role here — deriving a composition of the authored deck_size
## and injecting it — because the state layer never reads deck_size itself. Ids are DISTINCT so
## the permutation and fill-from-the-top proofs in test_deck_and_hand.gd have something to see.
func _golden_deck() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("golden_card_%02d" % i))
	return out


## Story 3-5a (AC 12): the golden's CAST-COST content, built in-test over _golden_deck's opaque
## ids — the _golden_config / _golden_deck principle applied to the third injected resource. Every
## id is priced identically, so which card the shuffle happened to put in CAST_SLOT cannot change
## the arithmetic and the measurement stays a function of the PRICE alone.
##
## The fixture plays the RUNNER's role here, deriving the map and injecting it, exactly as it
## already does for the deck composition.
func _golden_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _golden_deck():
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA_COST
		out[id] = c
	return out


## Golden-path flags — constructed IN-TEST with melee_mana_generation ON, never read
## from the authored .tres (the same tuning-cannot-move-the-hash principle as
## _golden_config).
## Story 4-1 (AC 2, `4-1/R6`): the golden's CARD-EFFECT content — the _golden_config /
## _golden_deck / _golden_costs principle applied to the FOURTH injected resource, built in-test
## over the same opaque ids. data/cards/ is unreachable from the state harness and these ids are
## nothing the card library contains, so RE-AUTHORING A REAL CARD'S effect_id MUST NEVER
## RE-BASELINE THIS HASH.
##
## EVERY id is a `summon_`, deliberately: the fixture plays the RUNNER's role here as it already
## does for the composition and the costs, and a uniform map keeps the measurement a function of
## the RESOLVER rather than of which card the shuffle happened to put in CAST_SLOT — the identical
## argument _golden_costs makes for pricing every id the same.
##
## THIS IS CAUSE 2 OF THIS STORY'S RE-BASELINE, and it is a BEHAVIOURAL cause rather than a shape
## one: the t22 cast resolves to OUTCOME_SUMMON, `unit_count` moves 0 -> 1, and the hash is taken
## at t24 — so the moved value is live at hash time and the resolver sits inside determinism
## coverage BY CONSTRUCTION rather than by luck (`4-1/R6`, confirmed at the gate).
func _golden_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _golden_deck():
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


func _golden_flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	# Story 4-1: the MINION LAYER ON, chosen for COVERAGE and not for feel — the _golden_config
	# principle applied to a flag. With it off, CardEffectResolver would answer
	# REASON_MINIONS_FLAG_CLOSED for the t22 cast, `unit_count` would stay 0 for the whole run,
	# and the resolver would sit OUTSIDE determinism coverage while the golden still looked
	# healthy. This line is what makes cause 2 of this story's re-baseline real.
	f.minions = true
	return f


func test_same_seed_and_intents_hash_identically() -> void:
	assert_eq(_run(), _run(), "same seed + intents must produce identical state")


func test_state_matches_golden() -> void:
	assert_eq(_run(), GOLDEN, "state hash drifted from golden — determinism or snapshot shape changed")


## Guards the recorded sequence itself: the golden only guards transition determinism if
## the sequence actually fires the claimed transitions (attack, chain, roll-cancel, block).
## A silently-inert sequence would leave the golden guarding movement only.
func test_recorded_sequence_exercises_all_transitions() -> void:
	var ms := _make_match()
	var p1_log: Array = []
	var p2_log: Array = []
	ms.p1.hero.action_state_changed.connect(
		func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
			p1_log.append([int(prev), int(cur)]))
	ms.p2.hero.action_state_changed.connect(
		func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
			p2_log.append([int(prev), int(cur)]))
	_play_sequence(ms)
	var idle := int(HeroState.ActionState.IDLE)
	var atk := int(HeroState.ActionState.ATTACKING)
	var roll := int(HeroState.ActionState.ROLLING)
	var blk := int(HeroState.ActionState.BLOCKING)
	assert_eq(p1_log, [[idle, atk], [atk, atk], [atk, roll], [roll, idle]],
		"p1: attack, chain (self-transition), recovery roll-cancel, roll end")
	assert_eq(p2_log, [[idle, blk], [blk, idle], [idle, blk], [blk, idle], [idle, atk]],
		"p2: two block spans (story 1-8) then the t15 attack (story 1-9) — release and press fire the same tick")


## Story 1-4 (AC 6): the stamina analogue of the transition guard above — the golden only
## guards the economy if the sequence actually exercises it. Pins: stamina dips below max
## after the t17 roll spend, rises again before the final tick, and is left MID-REGEN at
## t24 (below maximum, above the immediate post-spend value) so the hashed final snapshot
## encodes both the spend and the regen.
func test_golden_sequence_exercises_stamina_spend_and_regen() -> void:
	var ms := _make_match()
	var readings: Array[float] = []
	_play_sequence(ms, func(_t: int) -> void: readings.append(ms.p1.stamina.get_current()))
	var maximum := ms.p1.stamina.get_maximum()
	var post_spend := readings[17 - 1]
	var final := readings[TICKS - 1]
	assert_eq(post_spend, 23.0,
		"t17 roll spend: 38 - 15 (the two attack spends preceded it — E3-RG/R2)")
	assert_true(post_spend < maximum, "stamina dipped below maximum after the t17 roll")
	assert_true(final > post_spend, "regen visibly ran before the run ended")
	assert_true(final < maximum, "pool left MID-REGEN at t24 — below maximum")
	assert_eq(final, 28.0, "23 + 5 regen ticks (delay covers t17-t19, 1.0/tick t20-t24)")


## Story 1-8 (supersedes the 1-5 hit/mana pin — the combat analogue of the stamina pin
## above): the golden only guards the block/deflect layer if the sequence actually
## exercises BOTH outcomes. Pins the exact arithmetic at named ticks so the sequence
## can never silently degrade to a hitless (or deflectless) run: t4 both untouched;
## t5 the GRACE-tick DEFLECT — P2 stays at 120 HP (fully negated), P1 mana stays 0
## (denied), P2 stamina drops 40 -> 20 (cost paid AT LANDING, R-D1); t13 the ordinary
## BLOCK — P2 drops 120 -> 117 (10% of 120 = 12.0, x 0.25), P1 mana 0 -> 12 (a blocked
## hit is CONFIRMED and pays full flat mana, R-D4); t24 (final, hashed) 117 HP / 12
## mana / P2 stamina 30.0 MID-REGEN (regen resumes only after the second block span
## releases at t15) — non-full HP, non-zero mana, and a stamina value that encodes the
## deflect spend AND the regen.
func test_golden_sequence_exercises_block_and_deflect() -> void:
	var ms := _make_match()
	var hp_readings: Array[float] = []
	var mana_readings: Array[float] = []
	var p2_stamina_readings: Array[float] = []
	_play_sequence(ms, func(_t: int) -> void:
		hp_readings.append(ms.p2.hero.get_hp())
		mana_readings.append(ms.p1.mana.get_current())
		p2_stamina_readings.append(ms.p2.stamina.get_current()))
	assert_eq(hp_readings[4 - 1], 120.0, "t4: fact not yet fed — P2 at full HP")
	assert_eq(mana_readings[4 - 1], 4 * PASSIVE_PER_TICK,
		"t4: P1 has earned the PASSIVE faucet and nothing else — no hit has been confirmed")
	assert_eq(hp_readings[5 - 1], 120.0, "t5: DEFLECT on the grace tick — fully negated, no damage")
	assert_eq(mana_readings[5 - 1], 5 * PASSIVE_PER_TICK,
		"t5: a deflected contact generates NO MELEE mana (R-D4) — the passive faucet is untouched by it")
	assert_eq(p2_stamina_readings[5 - 1], 20.0, "t5: deflect cost 20 paid AT LANDING (40 -> 20)")
	assert_eq(hp_readings[13 - 1], 117.0, "t13: ordinary BLOCK — 12.0 chip x 0.25 = 3.0")
	assert_eq(mana_readings[13 - 1], 12.0 + 13 * PASSIVE_PER_TICK,
		"t13: a blocked hit is CONFIRMED — full flat mana ON TOP of 13 passive ticks")
	assert_eq(hp_readings[TICKS - 1], 117.0, "t24: NON-FULL HP on record (no HP regen exists)")
	# Story 3-5a: the t22 cast is the FIRST mana SINK this fixture has ever had, so the final
	# reading is the accumulation MINUS the price. The t4/t5/t13 readings above are untouched —
	# they all precede CAST_TICK, which is what keeps this pin's block/deflect subject intact.
	assert_eq(mana_readings[TICKS - 1], 12.0 + TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"t24: one hit plus the passive accumulation, LESS the t22 cast's price")
	assert_eq(p2_stamina_readings[TICKS - 1], 21.0,
		"t24: P2 MID-REGEN — 20, then its t15 attack spends 6 (E3-RG/R2) and restarts the "
		+ "delay (t15-t17), regen t18-t24 -> 21; the hash encodes both spends and the regen")


## Story 1-9 (the block/deflect pin's iframe analogue): the golden only guards the iframe
## layer if the sequence actually exercises BOTH sides of the boundary. Pins the exact
## arithmetic at named ticks so the sequence can never silently degrade to a dropless (or
## landless) run: t19 the GRACE-tick DROP — P1 stays at 120 HP (fact dropped pre-dedupe),
## P2 mana stays 0 (a dropped fact is not a resolution); t20 the SAME swing's next fact
## lands FULL damage on the still-rolling P1 — 120 -> 108 (iframes over, roll not; and
## the drop never registered, or this fact would be a same-swing duplicate), P2 mana
## 0 -> 12; t24 (final, hashed) P1 at 108 HP / P2 at 12 mana — the hash encodes the
## landed hit, and P1's roll_direction is (-1, 0, 0), pinning the t17 neutral-stick
## FACING FALLBACK on the record.
func test_golden_sequence_exercises_iframe_negation() -> void:
	var ms := _make_match()
	var p1_hp: Array[float] = []
	var p2_mana: Array[float] = []
	_play_sequence(ms, func(_t: int) -> void:
		p1_hp.append(ms.p1.hero.get_hp())
		p2_mana.append(ms.p2.mana.get_current()))
	assert_eq(p1_hp[19 - 1], 120.0, "t19: iframe grace-tick DROP — no damage")
	assert_eq(p2_mana[19 - 1], 19 * PASSIVE_PER_TICK,
		"t19: a dropped fact generates NO MELEE mana (1-9/R1) — only the passive faucet has paid")
	assert_eq(p1_hp[20 - 1], 108.0, "t20: the SAME swing lands FULL damage one past the grace")
	assert_eq(p2_mana[20 - 1], 12.0 + 20 * PASSIVE_PER_TICK,
		"t20: the landed hit pays full flat mana on top of 20 passive ticks")
	assert_eq(p1_hp[TICKS - 1], 108.0, "t24: P1 non-full HP on the hashed record")
	assert_eq(p2_mana[TICKS - 1], 12.0 + TICKS * PASSIVE_PER_TICK,
		"t24: P2 non-zero mana on the hashed record")
	assert_eq(ms.p1.hero.roll_direction, Vector3(-1, 0, 0),
		"t17 roll captured via the facing fallback — on the hashed record")


## Story 3-0b (AC5/AC6), the per-phase-movement analogue of the pins above: the golden only
## guards the new movement seat if the sequence actually EXERCISES it, and AC6's "authored
## for path coverage" claim is vacuous unless the lunge is shown to have run. Both are pinned
## on ticks where the arithmetic is unambiguous because the move intent is ZERO, so the
## steered term drops out and the velocity is the new term alone:
##   t5 — P1 is in swing 0's ACTIVE window (windup 1-3, active 4-7) and MOVES[4] gives P1
##        (0,0), so world_dir is zero and P1's velocity IS the lunge: facing (-1,0) carried
##        from t4 (a zero intent does not update facing), 2.0 units / (7/60 s) on -X. This is
##        the evidence that AC6 ran at all — and, paired with the t24 pin below, the evidence
##        for WHY it is a measured non-mover.
##   t24 — the hashed tick. P2 is in its t15 swing's RECOVERY with move (1,0): velocity is
##        6.0 * the recovery multiplier 0.75 = 4.5 on +X, with NO lunge component, which is
##        exactly the AC5-moves / AC6-does-not split the re-baseline record names.
func test_golden_sequence_exercises_per_phase_movement_and_lunge() -> void:
	var ms := _make_match()
	var p1_vel: Array[Vector3] = []
	var p2_vel: Array[Vector3] = []
	_play_sequence(ms, func(_t: int) -> void:
		p1_vel.append(ms.p1.hero.velocity)
		p2_vel.append(ms.p2.hero.velocity))
	var lunge_speed := 2.0 / (7.0 / 60.0)
	assert_eq(ms.p1.hero.attack_phase(), &"attack_done", "sanity: P1's swings are long over by t24")
	assert_true(p1_vel[5 - 1].is_equal_approx(Vector3(-lunge_speed, 0.0, 0.0)),
		"t5: P1's ACTIVE-phase velocity is the lunge ALONE (zero move intent) — AC6 genuinely ran")
	assert_true(p2_vel[TICKS - 1].is_equal_approx(Vector3(4.5, 0.0, 0.0)),
		"t24 (hashed): P2 in RECOVERY at 6.0 * 0.75, NO lunge term — the AC5-moves/AC6-non-mover split")


## Story 3-4 (AC 4/AC 7), the passive-faucet analogue of the pins above: this re-baseline's
## ONE named cause is _golden_config()'s nonzero mana_regen_per_second, and naming it is
## vacuous unless the rung it activates actually ran across the recorded sequence. Pinned at
## t1 (the first tick, before any contact — the reading is the passive faucet ALONE, which is
## also the proof that there is no delay window) and at the hashed t24, on BOTH heroes: the
## passive rule is ungated and per-player, unlike the attacker-only melee rule, so a
## regression that seated it on the attacker path would show as an asymmetry here.
func test_golden_sequence_exercises_passive_mana_regen() -> void:
	var ms := _make_match()
	var p1_mana: Array[float] = []
	_play_sequence(ms, func(_t: int) -> void: p1_mana.append(ms.p1.mana.get_current()))
	assert_eq(p1_mana[1 - 1], PASSIVE_PER_TICK,
		"t1: the passive rung ran on the very FIRST tick — no delay window (sealed, AC 4)")
	assert_eq(p1_mana[TICKS - 1], 12.0 + TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"t24 (hashed): P1's hit (12.0) plus 24 passive ticks at 1.25, LESS the t22 cast price")
	# Story 3-5a: P2 never casts, so its reading is the UNSPENT accumulation. The asymmetry is now
	# doing double duty — it still catches a faucet wrongly seated on the attacker path, and it
	# additionally catches a cast that debited the wrong player.
	assert_eq(ms.p2.mana.get_current(), 12.0 + TICKS * PASSIVE_PER_TICK,
		"t24: P2 carries the FULL passive accumulation — per-player faucet, and P2 cast nothing")
	assert_true(ms.p1.mana.get_current() < ms.p1.mana.get_maximum(),
		"left UNCLAMPED at t24, so the hash encodes the accumulated value and not the cap")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.DEAD,
		"sanity: nobody dies on this sequence, so DEAD suppression never fires inside the hash")


## Story 3-3 (AC 12), the deck analogue of the pins above: this re-baseline's causes 2 and 3 are
## named as "the shuffle consumed RNG" and "the fill moved cards", and naming them is VACUOUS
## unless the recorded run genuinely did both. A fixture that injected a deck but never dealt it
## would still move the hash (the snapshot key alone did that at M2) and would leave the golden
## guarding nothing about either mechanism.
##
## Pinned on the hashed final state, all four claims separately:
##   - the FILL ran: hand_size 9 on BOTH players, deck 17 - 9 = 8 left (AC 9's exact counts);
##   - the SHUFFLE ran: P1's pile is NOT in injected order (the identity permutation is the
##     failure mode a no-op shuffle produces, and it is what an `Array.shuffle()` regression
##     would look like on a per-instance generator too);
##   - the shuffle used the MATCH's generator: P1 and P2 got DIFFERENT orders from one seed,
##     which only happens because the two deals draw from the same generator in turn;
##   - nothing was invented or lost: deck + hand is a PERMUTATION of the injected multiset.
func test_golden_sequence_exercises_deck_shuffle_and_hand_fill() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	# Story 3-5b: P2 is the untouched player and is the one that still pins the DEAL's exact
	# counts; P1's hand is one short at t24 because its t22 cast is still owed a replacement
	# (DRAW_DELAY_TICKS outlives the two ticks between the cast and the hash). Asserting the two
	# players separately is what keeps this pin about the DEAL — a regression in the deal shows on
	# BOTH players, a cast-or-delay bug on only one.
	assert_eq(ms.p2.hand.occupied_count(), HAND_SIZE,
		"the fill ran: P2 holds hand_size cards at t24")
	assert_eq(ms.p2.deck.size(), DECK_SIZE - HAND_SIZE,
		"P2 cast nothing: deck remaining is deck_size - hand_size (AC 9) — no reshuffle")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE - 1,
		"P1's t22 replacement is STILL IN FLIGHT at t24 — the hand is one short")
	# Story 4-0, and this is CAUSE 3 of the re-baseline made visible (`4-0/R7`). A hole is LIVE at
	# hash time on this very fixture, so the hashed `hand_size` key reads one of these two numbers
	# and they differ. Bound to WIDTH it would read HAND_SIZE and the golden would move for a
	# reason that has nothing to do with this story; bound to occupancy per AC 2 it reads
	# HAND_SIZE - 1, unchanged, which is why cause 3 measures as a NON-MOVER.
	assert_eq(ms.p1.hand.size(), HAND_SIZE,
		"...as a HOLE against an unchanged WIDTH — the two readings differ here, which is exactly "
		+ "why `4-0/R1` had to split them and why the snapshot binds to occupied_count()")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE,
		"...so P1's pile has not paid for it yet either")
	var injected := _golden_deck()
	var p1_pile := ms.p1.deck.to_array()
	var p2_pile := ms.p2.deck.to_array()
	assert_ne(p1_pile, injected.slice(0, DECK_SIZE - HAND_SIZE),
		"the SHUFFLE ran: the pile is not the injected order (a no-op shuffle is the failure mode)")
	assert_ne(p1_pile, p2_pile,
		"P1 and P2 drew DIFFERENT orders from the one seeded generator (the ONE-SEAT ordering)")
	var p1_all := p1_pile.duplicate()
	p1_all.append_array(ms.p1.hand.occupied_ids())
	# Story 3-5a: the discard joins the conservation sum — the cast card left the hand and is
	# neither in the pile nor the hand, so without this the multiset would be one short.
	p1_all.append_array(ms.p1.discard.to_array())
	p1_all.sort()
	var expected := injected.duplicate()
	expected.sort()
	assert_eq(p1_all, expected,
		"deck + hand is a PERMUTATION of the injected multiset — nothing invented, nothing lost")


## Story 3-5a (AC 12), the cast analogue of the pins above: this re-baseline's causes 2 and 3 are
## named as "the deck and discard counts moved" and "the price was paid", and naming them is
## VACUOUS unless the recorded run genuinely cast a card. A fixture that injected cast costs but
## never committed one would still move the hash (the snapshot key alone did that at M1) and would
## leave the golden guarding nothing about the cast path at all.
##
## Pinned on the hashed final state, each claim separately:
##   - the cast LANDED: one card in P1's discard, and P2 (who never casts) has none;
##   - the REPLACEMENT was instant: P1's hand is still HAND_SIZE, which is why hand_size is a
##     measured NON-mover even though the card left the hand — the refill restores it inside the
##     same tick;
##   - the DECK paid for the refill: one fewer than the no-cast count, which is cause 2's whole
##     visible content alongside the discard;
##   - the PRICE was paid: P1 ends CAST_MANA_COST below the accumulation it would otherwise
##     carry, which is cause 3;
##   - nothing was invented or lost: deck + hand + discard is a permutation of the composition.
func test_golden_sequence_exercises_the_recorded_cast() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	assert_eq(ms.p1.discard.size(), 1, "the cast LANDED — exactly one card in P1's discard")
	assert_eq(ms.p2.discard.size(), 0, "P2 never casts on this sequence — its discard is empty")
	# Story 3-5b (AC 1/AC 3) REWRITES the two count assertions that used to pin the INSTANT refill
	# by name, and the rewrite is this story's expected work rather than a regression: the fixture
	# now prices the delay at DRAW_DELAY_TICKS, the cast lands at t22 and the run hashes at t24, so
	# the replacement is STILL IN FLIGHT on the hashed record. The hand is one LOWER and the deck
	# one HIGHER than 3-5a recorded — which is the whole visible content of golden cause C3(b).
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE - 1,
		"the replacement is STILL OWED at t24 — the hand is one short (C3(b)'s first half)")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE,
		"...and the deck has NOT yet paid for it — one higher than 3-5a's count (C3(b)'s second)")
	assert_eq(ms.p1.pending_draw_owed, [CAST_SLOT] as Array[int],
		"exactly one draw in flight on the hashed record, ADDRESSED to the slot that was cast — "
		+ "this is cause 1 of the 4-0 re-baseline, in the key it moves")
	assert_true(ms.p1.hand.is_slot_empty(CAST_SLOT),
		"...and that slot is the hole, so the delivery has somewhere of its own to land (AC 4)")
	assert_true(ms.p1.pending_draw.is_running,
		"...with its window still running, so both new snapshot keys are non-idle in the hash")
	assert_eq(ms.p1.mana.get_current(), 12.0 + TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"the PRICE was paid out of the accumulation (cause 3)")
	var all: Array[StringName] = []
	all.append_array(ms.p1.deck.to_array())
	all.append_array(ms.p1.hand.occupied_ids())
	all.append_array(ms.p1.discard.to_array())
	all.sort()
	var expected := _golden_deck()
	expected.sort()
	assert_eq(all, expected,
		"deck + hand + discard is a PERMUTATION of the injected composition — nothing invented")
	# Story 3-5b (AC 11): the FOURTH term. The three containers above are still a whole permutation
	# — the card is drawn at delivery, so an owed draw holds nothing in limbo — and the in-flight
	# COUNT is what accounts for the hand being one short.
	assert_eq(ms.p1.hand.occupied_count() + ms.p1.pending_draw_owed.size(), HAND_SIZE,
		"the IN-FLIGHT term closes the hand: occupied + owed == hand_size")


## Story 3-5a: rng_state is a PREDICTED and MEASURED NON-MOVER, and this is the measurement,
## kept permanently rather than taken once and written into a comment.
##
## REASON: Deck.draw_top() reads _cards[size - 1] and remove_at()s it. It takes no rng argument
## and consumes nothing — the ONLY RNG consumer in Deck is shuffle_with_rng (3-3), and this story
## adds no reshuffle (that is 3-5b). So the replacement draw cannot advance the generator.
##
## Measured by running the recorded sequence WITH and WITHOUT the cast and comparing rng_state
## directly. The prior version of the story's Golden Prediction claimed the opposite — that a
## refill draw consumes the seeded RNG — so this is pinned rather than asserted from reading.
func test_the_recorded_cast_consumes_no_rng() -> void:
	var with_cast := _make_match()
	_play_sequence(with_cast)
	var without_cast := _make_match()
	_play_sequence(without_cast, Callable(), false)
	assert_eq(with_cast.p1.discard.size(), 1, "sanity: the cast ran in the first match")
	assert_eq(without_cast.p1.discard.size(), 0, "sanity: and did not in the second")
	assert_eq(with_cast.to_snapshot()["rng_state"], without_cast.to_snapshot()["rng_state"],
		"the cast and its replacement draw consumed NO rng — draw_top takes no generator")


## Story 4-1: THE PREDICTED NON-MOVER, CONFIRMED RATHER THAN ASSUMED (the 3-5b / 4-0 precedent of
## explicitly testing a predicted non-mover). The Golden Prediction names `rng_state` as a third
## possible cause and predicts it does NOT move: nothing about WHICH unit appears is random in
## this story, so appending a unit record must consume no RNG.
##
## Measured against the tightest possible pair — the SAME fixture, the SAME cast, differing only
## in whether effects were injected, so the only difference between the two runs is whether the
## resolver appended a record. `unit_count` must differ (or the comparison is vacuous) while
## `rng_state` must not.
func test_the_summon_consumes_no_rng() -> void:
	var summoning := _make_match()
	_play_sequence(summoning)
	var not_summoning := _make_match_without_effects()
	_play_sequence(not_summoning)
	assert_eq(summoning.p1.to_snapshot()["unit_count"], 1,
		"sanity: the t22 cast really did summon (`4-1/R6`)")
	assert_eq(not_summoning.p1.to_snapshot()["unit_count"], 0,
		"...and the effects-less run really did not — so this comparison is not vacuous")
	assert_eq(summoning.to_snapshot()["rng_state"], not_summoning.to_snapshot()["rng_state"],
		"appending a unit record consumed NO rng — the predicted non-mover, confirmed")


## Story 4-2 (AC 7/AC 8/AC 11): the BEHAVIOURAL golden cause, pinned on the hashed record itself
## rather than described in the re-baseline comment — the
## test_golden_sequence_exercises_the_recorded_cast precedent. Without this, cause 2 of the
## re-baseline would be a claim about a hash nobody can read.
##
## Every assertion here is a fact the hash actually carries at t24:
##   - the unit EXISTS (cause 2 of the 4-1 re-baseline, unchanged) and holds exactly ONE target;
##   - the target is the OPPOSING HERO — slot 1, index -1. P2's board is empty, so `standard`'s
##     units-first ordering falls through to the hero (AC 8's fall-through, not `prefer_hero`);
##   - it was acquired at the t23 BOUNDARY and PERSISTS through the non-boundary t24, which is the
##     only slice of throttle BEHAVIOUR this fixture can see (the timing itself is proven in
##     test_targeting_service.gd — see RETARGET_INTERVAL_TICKS);
##   - P2 has no units at all, so its `unit_targets` is empty — a target list that grew on the side
##     with no board would be a real defect this catches.
func test_golden_sequence_exercises_throttled_targeting() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	assert_eq(ms.p1.units.size(), 1, "sanity: the t22 cast summoned exactly one unit (`4-1/R6`)")
	var targets: Array = ms.p1.to_snapshot()["unit_targets"]
	assert_eq(targets.size(), 1, "one record, one target pair — the list is index-aligned with the board")
	assert_eq(targets[0], [1, TargetingService.HERO_INDEX],
		"the acquired target is the OPPOSING HERO: slot 1, index -1 (AC 11's pair, AC 8's "
		+ "units-first fall-through against an empty opposing board)")
	assert_eq(ms.p2.to_snapshot()["unit_targets"], [],
		"P2 owns no units, so nothing was written on its side")
	assert_true(TICKS % RETARGET_INTERVAL_TICKS != 0,
		"the hashed tick is NOT a boundary — so the pair above is a PERSISTED target, not one "
		+ "recomputed on the hashed tick itself")


## Story 4-2: THE PREDICTED NON-MOVER, CONFIRMED RATHER THAN ASSUMED (the 3-5b / 4-0 / 4-1
## precedent). The Golden Prediction names `rng_state` as a predicted non-mover: nothing about
## tie-break selection consumes RNG, because `4-2/R3` fixes a total order rather than drawing one.
##
## Measured against the tightest available pair — the SAME fixture, the SAME cast, the SAME summon,
## differing ONLY in whether the retarget cadence ever reaches a boundary while the unit exists. The
## acquired target must DIFFER across the pair (or the comparison is vacuous, the
## test_the_summon_consumes_no_rng shape verbatim) while `rng_state` must not.
##
## 7 is the never-reaching interval: its boundaries are t7, t14, t21 and t28, and the unit exists
## only from t22 to the run's end at t24.
const NO_BOUNDARY_INTERVAL_TICKS := 7


func test_the_throttled_targeting_consumes_no_rng() -> void:
	var retargeting := _make_match()
	_play_sequence(retargeting)
	var never_retargeting := _make_match_with_retarget_interval(NO_BOUNDARY_INTERVAL_TICKS)
	_play_sequence(never_retargeting)
	assert_eq(retargeting.p1.units.size(), never_retargeting.p1.units.size(),
		"sanity: both runs summoned the same unit — the ONLY difference is the cadence")
	assert_eq(retargeting.p1.to_snapshot()["unit_targets"], [[1, TargetingService.HERO_INDEX]],
		"sanity: the first run's unit ACQUIRED a target at the t23 boundary")
	assert_eq(never_retargeting.p1.to_snapshot()["unit_targets"],
		[[TargetingService.NO_TARGET_SLOT, TargetingService.NO_TARGET_SLOT]],
		"...and the second run's never did (boundaries t7/t14/t21 all precede the t22 summon) — "
		+ "so this comparison is not vacuous")
	assert_eq(retargeting.to_snapshot()["rng_state"],
		never_retargeting.to_snapshot()["rng_state"],
		"acquiring a target consumed NO rng — the predicted non-mover, confirmed")


## The golden match with ONE authored value changed, the `_make_match_without_effects` idiom applied
## to a value instead of a seam. Exists only for the non-mover measurement directly above; every
## hashed path uses `_make_match`.
func _make_match_with_retarget_interval(interval_ticks: int) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	var config := _golden_config()
	config.minion_retarget_interval_seconds = float(interval_ticks) / 60.0
	ms.apply_balance(config)
	ms.inject_feature_flags(_golden_flags())
	if config.deck_size > 0:
		ms.inject_deck(_golden_deck())
		ms.inject_card_costs(_golden_costs())
		ms.inject_card_effects(_golden_effects())
	ms.drain_signals()
	return ms


## Story 3-3 (AC 5): two INDEPENDENTLY CONSTRUCTED matches, same seed, POPULATED deck, must hash
## identically. Distinct from test_same_seed_and_intents_hash_identically above only in what it
## is FOR: that one predates the deck and would still pass with an empty one, so it cannot speak
## to the thing this story most easily breaks. The failure this catches is a CardData reference
## (or any object) reaching the snapshot — the canonical hash has no object branch and falls
## through to a string conversion yielding a PER-ALLOCATION instance id, so two matches built
## from identical data would hash differently and only a populated deck would show it.
func test_two_matches_with_a_populated_deck_hash_identically() -> void:
	var a := _make_match()
	var b := _make_match()
	_play_sequence(a)
	_play_sequence(b)
	assert_eq(a.p1.deck.size(), DECK_SIZE - HAND_SIZE,
		"sanity: the deck really is populated (P1's t22 replacement is still owed, not yet drawn)")
	assert_eq(CanonicalHash.of(a.to_snapshot()), CanonicalHash.of(b.to_snapshot()),
		"independently constructed matches with the same seed and a populated deck hash identically")


func test_canonical_hash_ignores_key_insertion_order() -> void:
	var d1 := {"a": 1, "b": {"x": 1, "y": 2}, "v": Vector3(1, 2, 3)}
	var d2 := {"v": Vector3(1, 2, 3), "b": {"y": 2, "x": 1}, "a": 1}
	assert_eq(CanonicalHash.of(d1), CanonicalHash.of(d2), "sorted-key canonicalization is order-independent")


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	var config := _golden_config()
	ms.apply_balance(config)
	ms.inject_feature_flags(_golden_flags())
	# Story 3-3 (AC 12): the deck-content injection, in the runner's own match-start order. Gated
	# on the authored size for a deliberate reason — AC 10 makes an EMPTY injected deck a loud
	# failure, so a zero deck_size means "this fixture has no deck at all", which is exactly the
	# M2 state. That gate is what makes both reverse measurements a genuine ONE-LINE toggle of a
	# single authored value rather than a hand-edited call site.
	if config.deck_size > 0:
		ms.inject_deck(_golden_deck())
		# Story 3-5a (AC 12): cast costs, injected in the runner's own match-start order (after
		# the composition — the seam validates that the map is TOTAL over it). Gated on the same
		# authored size for the same reason: a zero deck_size means "this fixture has no cards at
		# all", which keeps the reverse measurements a genuine one-value toggle.
		ms.inject_card_costs(_golden_costs())
		# Story 4-1 (AC 2, `4-1/R8`): card effects, injected LAST in the runner's own match-start
		# order (deck -> costs -> effects — the seam validates that the map is TOTAL over the
		# composition, so the composition must already be in). Gated on the same authored size for
		# the same reason as its two siblings: a zero deck_size means "this fixture has no cards at
		# all", which keeps the reverse measurements a genuine one-value toggle.
		ms.inject_card_effects(_golden_effects())
	ms.drain_signals()
	return ms


## `cast` exists ONLY so test_the_recorded_cast_consumes_no_rng can run the identical sequence
## with the cast suppressed. Every hashed path uses the default.
## The SAME golden match with the effects seam never called — the fixture behind the predicted
## non-mover measurement above, and the state of every MatchState fixture predating story 4-1.
func _make_match_without_effects() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	var config := _golden_config()
	ms.apply_balance(config)
	ms.inject_feature_flags(_golden_flags())
	if config.deck_size > 0:
		ms.inject_deck(_golden_deck())
		ms.inject_card_costs(_golden_costs())
	ms.drain_signals()
	return ms


func _play_sequence(ms: MatchState, after_tick := Callable(), cast := true) -> void:
	for t in range(1, TICKS + 1):
		var pair: Array = MOVES[(t - 1) % 6]
		var i1 := _intent(pair[0], P1_PRESS.get(t, []), [])
		# Story 3-5a (AC 12): P1's ONE recorded cast. Card fields are plain intent values, not
		# named actions, so they ride alongside the press overlay rather than inside it.
		if cast and t == CAST_TICK:
			i1.card_slot = CAST_SLOT
			i1.card_mode = Enums.ModeKind.BASIC
			i1.card_commit = true
		var held2: Array = [&"block"] if _block_held(t) else []
		var i2 := _intent(pair[1], P2_PRESS.get(t, []), held2)
		for fact: Array in CONTACTS.get(t, []):
			ms.push_contact([fact[0], -1], [fact[1], -1], fact[2], fact[3], MatchState.CONTACT_STRIKE)
		var intents: Array[InputIntent] = [i1, i2]
		ms.advance(intents)
		ms.drain_signals()
		if after_tick.is_valid():
			after_tick.call(t)


static func _block_held(t: int) -> bool:
	for r: Array in P2_BLOCK_HELD:
		if t >= int(r[0]) and t <= int(r[1]):
			return true
	return false


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(move: Vector2, pressed: Array, held: Array) -> InputIntent:
	var i := InputIntent.new()
	i.move_dir = move
	for k in pressed:
		i.pressed[k] = true
		i.held[k] = true
	for k in held:
		i.held[k] = true
	return i


func _run() -> String:
	var ms := _make_match()
	_play_sequence(ms)
	return CanonicalHash.of(ms.to_snapshot())


## Story 4-3b: THE FALSIFIED CAUSE, PINNED AS AN ASSERTION rather than left as a claim in the block
## above -- the discipline `4-3a`'s gate paid for when a recorded-but-unmeasured prediction was
## reversed.
##
## The golden's accounting says the unit dedupe records CANNOT contribute, because the fixture's one
## unit never swings. That is only true while the unit stays IDLE to the hash tick. If a future
## story gives this fixture a reach fact, a hitbox, or a runner, the unit WILL swing, the dedupe key
## WILL carry a record, and the golden will move for a reason the block above says is impossible --
## and this fails first, naming it.
func test_the_fixtures_unit_reaches_the_hash_tick_idle_with_no_dedupe_record() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	var summoner := ms.p1 if ms.p1.units.size() > 0 else ms.p2
	assert_eq(summoner.units.size(), 1,
		"sanity: the fixture really does summon exactly one unit (the t22 cast) — with none, every "
		+ "assertion below would be vacuously true")
	assert_eq(summoner.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE,
		"the fixture's unit is IDLE at the hash tick — it has no hitbox to overlap, nothing to "
		+ "overlap with and no reach fact, so it cannot wind up")
	assert_eq(summoner.units.attack_count_at(0), 0, "...has never swung...")
	assert_false(summoner.units.is_in_reach_at(0),
		"...and was never reported in reach: this fixture pushes no probe, and a probe is the only "
		+ "thing that sets the flag")
	assert_eq(summoner.unit_dedupe.snapshot(), [],
		"...so its dedupe records CANNOT EXIST at the hash tick. This is the golden block's "
		+ "'falsified cause' made executable: the `unit_swing_dedupe` key is present but EMPTY, so "
		+ "the widened dedupe shape contributes nothing here (a stronger reason than `4-3a/R27`'s, "
		+ "which relied on records having merely EXPIRED)")
