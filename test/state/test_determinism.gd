extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

## RE-BASELINED BY STORY 4-6 (camera lock-on), a96b123e -> aa3566d7, THREE CAUSES MEASURED
## SEPARATELY AND IN ORDER, plus a FOURTH candidate predicted and confirmed a NON-MOVER.
##
## AC 4 requires this story's causes to be "each confirmed and re-baselined in isolation per the
## `4-3a/R17`/`4-4` AC 12 multi-cause precedent (`4-6/R2`)", and operator ruling `4-6/R7` adds a
## third that AC 4 did not know about when it was written. Each was measured by STAGING ONE THING
## OFF the fully-shipped tree and re-running this file -- the 4-3b reverse-direction method -- with
## both staged files backed up out of repo and SHA256-verified byte-identical after restoration.
##
##   0. THE INHERITED VALUE, for reference: a96b123e (story 4-4's review fix pass).
##
##   1. FACING OWNERSHIP, THE BEHAVIOUR HALF (AC 2, AC 4 cause (a)). `HeroState.facing` stops being
##      written from the camera-rotated movement input and starts being written from the pushed
##      LOCK DIRECTION, unconditionally, with the movement zero-guard gone. Staged by holding the
##      `lock_target` snapshot key OFF `PlayerState.to_snapshot()` and the `4-6/R7` sign OFF
##      `_roll_world_direction`, so this measurement is the facing write and nothing else.
##      MEASURED: a96b123e ->
##      cd21eac5a93f6772275d1ebc18603807fc0a83db385ffbf691270900bd4a3a76.
##
##      IT IS A REAL BEHAVIOURAL CAUSE IN THIS FIXTURE, not a nominal one, and `LOCK_DIRS` is what
##      makes it so -- see that constant for the three-sided constraint its values satisfy. Facing
##      reaches the hash directly (`hero.facing`) and indirectly through the attack LUNGE, which
##      runs along it: at t5 P1's whole velocity IS the lunge.
##
##   2. FACING OWNERSHIP, THE SHAPE HALF (AC 2, AC 4 cause (a)). `PlayerState.to_snapshot()` gains
##      ONE key, `lock_target`, the `[slot, index]` address this player's hero is locked onto.
##      Restored on top of cause 1. MEASURED: cd21eac5 ->
##      9a71e68abc4d8697b6c6ce0c8d44c9410628f6e6b0e8f7ee25a0f342af66d122.
##      The key set moves TWENTY-SEVEN -> TWENTY-EIGHT here, pinned by test_card_observation.gd
##      and test_draw_delay_and_reshuffle.gd.
##
##      SPLIT FROM CAUSE 1 RATHER THAN FUSED WITH IT even though AC 4 names them as one cause,
##      because this file's standing discipline separates a snapshot SHAPE mover from a BEHAVIOUR
##      mover (4-1, 4-2 and 4-4 all did) and fusing them would have made the pair unattributable.
##      Its value is NOT static across the run: both players start locked on the opposing hero and
##      the fixture never retargets, so `[1, -1]` / `[0, -1]` is what reaches the hash -- the
##      resting value, which is exactly what AC 10's "there is no unlocked state" means.
##
##   3. THE `4-6/R7` NEUTRAL-STICK BACKSTEP (operator ruling, this dev pass). With the stick
##      neutral at roll entry the roll now goes AWAY from the locked target instead of along
##      facing. Restored on top of causes 1 and 2. MEASURED: 9a71e68a ->
##      aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f, the value below.
##
##      THE RULING REQUIRED THIS TO BE MEASURED EITHER WAY -- "if any golden-fixture tick rolls
##      with a neutral stick, this inversion is a THIRD separately measured golden cause; if none
##      does, measure and record the non-move." ONE DOES: t17's move pair is MOVES[16 % 6] =
##      (0, 0), so P1's roll-cancel takes the fallback, and `roll_direction` is SNAPSHOTTED and
##      still holds its entry-locked value at the hashed t24. It moves
##      Vector3(-0.6, 0, -0.8) from what causes 1-2 alone would have left at (0.6, 0, 0.8) --
##      pinned by name in test_golden_sequence_exercises_iframe_negation.
##
##   4. THE LIVE CAMERA BASIS (AC 4 cause (b)) -- PREDICTED A NON-MOVER FOR THIS HASH, CONFIRMED,
##      AND STRUCTURALLY SO. AC 4 names the rig's new per-tick yaw making the pushed basis
##      non-identity in live play, which changes `world_dir` and therefore the hashed
##      `HeroState.velocity` -- the `3-0c/R2` divergence. IT CANNOT REACH THIS FILE: the state
##      harness instantiates no scene, so there is no rig to yaw, and this fixture calls
##      `set_camera_basis` ZERO times (grepped), so every tick resolves through the identity
##      short-circuit exactly as it always has. Confirmed by causes 1-3 fully explaining the final
##      value.
##
##      SO CAUSE (b) IS GUARDED ELSEWHERE, and naming where is the point of recording it here
##      rather than omitting it: test/integration/test_camera_relative.gd drives the live yaw
##      end-to-end through the real runner, and test_replay_identity.gd drives a NON-IDENTITY
##      basis through the record. A green golden is not coverage of it.
##
## NOT a cause: `data/gamepad_profile.tres`'s new right-stick fields (this fixture builds its
## intents in-test and loads no controller resource), and the `RecordFile.FORMAT_VERSION` bump
## (this file never touches a record).
## ---------------------------------------------------------------------------------------------
##
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
## `stamina_accelerator_regen_step` (carried its multiplicative predecessor's name when this entry
## was written; RENAMED by story 5-1, `5-1/R2` — the claim below held under that name and holds
## under this one) are unauthored in `_golden_config` and default to 0.0 —
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
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 5-2 (unblockable initiation), aa3566d7 -> dc2c9ffa, ONE CAUSE MEASURED IN
## BOTH DIRECTIONS. The story PREDICTED the golden would move, with the pinned per-player key set
## growing by one key per new fact actually added (`5-2/R9`, its AC 22), and predicted that a move
## for any OTHER reason would be a FINDING rather than a pass. Measured: it moved for exactly that
## reason and no other.
##
##   THE ONE CAUSE: the SNAPSHOT KEY SET, TWENTY-EIGHT -> TWENTY-NINE. `PlayerState.to_snapshot()`
##     gains ONE key, `telegraph`, carrying the active mode (2) chargeup as
##     `[colour, remaining_ticks]`. AC 22 left the count open between 29 (colour and remaining time
##     fused into one key) and 30 (two separate keys); MEASURED AS 29 -- they are fused, on the
##     `lock_target` precedent, because a telegraph is ONE fact in two halves and splitting it would
##     let the halves disagree about whether a telegraph is running at all. Pinned by
##     test_card_observation.gd and test_draw_delay_and_reshuffle.gd.
##
##   ITS PRESENCE IS THE MOVER; ITS VALUE NEVER LEAVES THE RESTING ONE. The story's Dev Notes asked
##     which of two shapes actually held -- a fixture that CASTS mode (2) (in which case the value
##     moves too) or one that does not (the `5-1a` shape: new code the fixture never reaches, with
##     the KEY still appearing). MEASURED: THE SECOND. This fixture's recorded sequence contains no
##     mode (2) cast, so `charge_color` is never written, no hero ever enters CHARGING, and the key
##     hashes at `[-1, 0]` -- `NO_TELEGRAPH_COLOR` and a stopped window -- on every tick of the run.
##     The 3-5a `discard_size` pattern exactly: a new key moving the hash by itself, at its resting
##     value, before any of the behaviour it describes has run.
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with the `telegraph`
##     key held OFF `PlayerState.to_snapshot()` and EVERYTHING ELSE this story ships left in place
##     -- the UNBLOCKABLE dispatch arm and its S6 gate, the fourth injection seam, the two new
##     contact kinds and the latch they write, the CHARGING movement root and auto-aim, the regen
##     suppression, the chargeup window ticking at step 2, and the step-3(a) landing arm -- this
##     file hashed aa3566d7 EXACTLY: the pre-story golden, unchanged. Measured at the dev pass by
##     deleting those three lines, running the harness, and restoring from a SHA256-verified
##     out-of-repo copy (c47154fd...).
##
##   NON-MOVER 1, THE TWO NEW CONTACT KINDS (AC 17), MEASURED not asserted: it falls out of the
##     reverse-direction run above. The fixture pushes no charge-reach fact, so both latch arrays
##     stay at `REACH_UNKNOWN` / `Vector2.ZERO` -- and they are UNHASHED anyway, classified with
##     `_camera_bases` and `_lock_directions` as pushed per-tick spatial facts
##     (test_replay_identity.gd's exclusion (c), whose MEMBER count stays at THREE).
##
##   NON-MOVER 2, THE FOURTH INJECTION SEAM (AC 4): `_card_colors` is injected CONTENT, classified
##     alongside `_card_costs` and `_card_effects` and never hashed -- the same reason its two
##     siblings are non-movers. The colour that CAN reach the hash is the single int copied onto
##     `charge_color` at a cast, and this fixture never casts mode (2).
##
##   NON-MOVER 3, THE `FORMAT_VERSION` BUMP 6 -> 7: a record-file concern with no path into
##     `MatchState.to_snapshot()` at all. Recorded here only because the story asked for the two
##     questions (AC 22 and AC 23) to be answered separately rather than conflated.
##
##   CAUSES UNREACHABLE HERE, named so nobody reads a green golden as coverage of them: the entire
##     mode (2) chain -- dispatch, the S6 gate, the spend, CHARGING entry, rooting, auto-aim, regen
##     suppression, the death branches and the landing check -- because the fixture never casts
##     mode (2) and there is no runner here to push a reach fact. They are proven in
##     test_unblockable_initiation.gd.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 6-1c (unblockable tracking and reach), d5bcb7e6 -> 9679fa80, ONE CAUSE,
## MEASURED IN BOTH DIRECTIONS. The story's Golden Prediction was NO MOVE in the inverse form --
## UNLESS the chosen phase shape added a NEW HASHED FIELD, which would then be the single named cause.
## The dev pass's phase shape (a second window, `PlayerState.landing_window`, running from the cast to
## the landing beside `charge_window`) added exactly one such field, and the golden moved for exactly
## that reason and no other.
##
##   THE ONE CAUSE: the SNAPSHOT KEY SET, THIRTY -> THIRTY-ONE. `PlayerState.to_snapshot()` gains ONE
##     key, `landing`, the landing window's remaining ticks -- hashed because the window crosses ticks
##     and decides when the attack commits and lands. Pinned by test_card_observation.gd (size 30 ->
##     31) and test_draw_delay_and_reshuffle.gd, both ORDER-SENSITIVE literals: the key's sorted
##     position is between `hero` and `lock_target`.
##
##   ITS PRESENCE IS THE MOVER; ITS VALUE NEVER LEAVES THE RESTING ONE -- the `5-2`/`5-5` shape. This
##     fixture never casts mode (2), so the landing window is never started and the key hashes 0 on
##     every tick. PINNED as an assertion rather than left as a claim here, by
##     test_the_fixture_never_starts_a_landing_window below.
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with ONLY the
##     `"landing"` line held off `PlayerState.to_snapshot()` and EVERYTHING ELSE this story ships left
##     in place -- the landing window and its step-2 tick, the reshaped CHARGING arm, the commit
##     freeze in the facing branch, the launch velocity, the per-colour arc gate at the landing seat,
##     the reset and abandonment clears, the twelve per-colour BalanceConfig fields and their three BalanceTicks
##     twins -- this file hashed d5bcb7e6 EXACTLY and the thirty-key pins passed. Measured at the dev
##     pass by deleting that one line, running this file and test_card_observation.gd (both green),
##     and restoring from a SHA256-verified out-of-repo copy (822ec841...).
##
##   NON-MOVER, `FORMAT_VERSION` STAYS AT 8: no new input channel, no new intake seam, no new
##     contact kind -- the committed direction is DERIVED state (the frozen `facing`), never a
##     recorded input, and the per-colour radius rides the existing CHARGE-REACH kinds unchanged.
##
##   NON-MOVER, THE TWELVE AUTHORED FEEL KNOBS (per-colour reach / arc / launch distance / launch
##     span): authored `.tres` tuning, isolated from this golden by standing `BC/R3` --
##     `_golden_config()` never loads the authored file, and their unauthored in-test defaults (360
##     arc, 0 launch) reproduce the pre-story shape exactly.
##
##   CAUSES UNREACHABLE HERE, named so nobody reads a green golden as coverage of them: tracking,
##     the commit, the launch and the per-colour geometry -- the fixture never enters CHARGING. They
##     are proven in test_unblockable_tracking_and_reach.gd.
## Previous golden d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d
## (story 5-6, three-tier ladder -- the record below).
##
## RE-BASELINED BY STORY 5-6 (three-tier ladder), d9725092 -> d5bcb7e6, TWO CAUSES, BOTH BEHAVIOURAL,
## BOTH MEASURED SEPARATELY AND IN BOTH DIRECTIONS -- and NO new snapshot key, which is the shape
## this story's AC 17 predicted and measurement confirmed.
##
## THE KEY SET STAYS AT THIRTY. `hero_state.stun` has been a `to_snapshot()` key since E1 and HASHED
## in test_replay_identity.gd since then; `stamina` likewise. This is therefore the `5-4` ORBS shape
## ("the key already existed, a path behind it moved a resting value"), NOT the `5-2`/`5-5` shape
## (a genuinely new key whose mere presence moves the hash). No `HASHED`/`UNHASHED` classification
## obligation, and no key-set literal anywhere in the suite moves.
##
## WHY THE FIXTURE REACHES THIS STORY AT ALL, and it is not something the story added: `CONTACTS[5]`
## has been P1's swing landing on a front-facing, deflect-window-open P2 since 1-8, and it DEFLECTS by
## design. P1 is the attacker and a HERO, so AC 9's `HERO_INDEX` gate fires on coverage that was
## already there. `_resolve_charge_contact` (5-2's landing seat, renamed at 7-8) is NEVER reached (the fixture's one recorded cast is
## `ModeKind.BASIC`), so AC 5 / AC 7 / AC 8 contribute nothing here BY CONSTRUCTION -- proven below,
## not assumed -- and are covered by test_unblockable_defense.gd instead.
##
##   0. THE INHERITED VALUE, for reference: d9725092 (story 5-5).
##
##   0b. THE DEGENERATE-VALUE MEASUREMENT, taken FIRST and worth recording because it is the reason
##      the two `_golden_config()` lines exist at all. With BOTH new write sets fully SHIPPED but
##      `deflect_stun_seconds` and `deflect_stamina_penalty` left UNAUTHORED in the fixture, the hash
##      reproduced d9725092 BIT FOR BIT. `seconds_to_ticks` maps `<= 0.0` to 0, `TimingWindow.start(0)`
##      never runs, the step-3 timer arm returns the hero to IDLE on the very tick it was stunned, and
##      `add(-0.0)` changes nothing -- so an unauthored fixture would have measured a FALSE NON-MOVER
##      and shipped both new paths outside determinism coverage while the golden looked healthy. This
##      is the standing lesson of every value in `_golden_config()`, hit again.
##
##   1. THE DEFLECT STUN AND ITS STATE TRANSITION (AC 9's `stun.start` + `set_action_state` pair).
##      Staged by holding those TWO lines off the shipped tree with the stamina drain LEFT IN.
##      MEASURED: the drain alone reaches
##      57d3b5a9f96845bb2ed42f7374376218a5e3a32c8c07479ef8fb00dc826d8888 -- so restoring the pair on
##      top of it is what completes the move to d5bcb7e6, and the pair is a mover in its own right.
##
##      IT IS A REAL BEHAVIOURAL CAUSE, NOT MERELY A WINDOW VALUE, and the knock-on chain is the whole
##      of it: P1 leaves ATTACKING for STUNNED at t5, so `active_done` never fires, `recovery` and
##      `chain` are never started, the t9 chain press is DROPPED by the empty `stunned` row, and P1 is
##      hard-rooted (AC 14) from t6 to t11. `hero_state.stun` itself hashes at
##      `[duration 7, elapsed 7, running false]` instead of the all-zero resting value it has carried
##      since E1. All of it is pinned by name in test_recorded_sequence_exercises_all_transitions.
##
##   2. THE DEFLECT STAMINA PENALTY (AC 9's `attacker.stamina.add(-...)`). Staged by holding that ONE
##      line off with the stun pair LEFT IN. MEASURED: the pair alone reaches
##      e3a26c4a571cd12ed012726e334776dfd7186254c25453e73115fd995d3ea2df -- so the drain, too, is a
##      mover in its own right, and the two causes are genuinely separable rather than one fact
##      counted twice. `stamina_pool._current` is HASHED, and the drain moves P1's final reading to
##      19.0. Its own mechanism (AC 10: `add(-x)`, NOT `spend()`, so the regen delay is NOT restarted
##      and regen runs on t6) is pinned as arithmetic in
##      test_golden_sequence_exercises_stamina_spend_and_regen -- a `spend()` implementation lands on
##      a different final value, which is what makes AC 10 a golden-level fact here.
##
##   3. THE COLOUR-COUNTER PATH (AC 5) -- PREDICTED A NON-CONTRIBUTOR, MEASURED A NON-CONTRIBUTOR.
##      With AC 9's complete write set IN and AC 5's complete write set (`stun.start`,
##      `set_action_state(STUNNED)` and its early `return`) staged OUT, the hash was d5bcb7e6:
##      UNCHANGED from the fully-shipped tree. The colour-counter path contributes EXACTLY ZERO,
##      measured rather than argued from "the fixture never casts UNBLOCKABLE".
##
##   THE FULL REVERSE, which is what makes the pair attributable as a whole: with BOTH write sets
##     staged out -- AC 5's pair-plus-return and AC 9's triple -- and EVERYTHING ELSE this story ships
##     left in place (the renamed/added balance fields and their tick conversions, the widened
##     `is_hitbox_active()` (AC 11), the step-3 STUNNED timer arm (AC 12), the fifth reset exception
##     (AC 13), the STUNNED movement root (AC 14), both cast refusals (AC 15/AC 16), the per-tick
##     `_iframe_open_at_step3` capture and the dodge rung itself (AC 7/AC 8)) -- the hash reproduced
##     the INHERITED d9725092 EXACTLY. Every other member of this story is therefore a measured
##     non-mover on this fixture, and the move belongs to AC 9's two causes alone.
##
##   THE COVERAGE ACCOUNTING (AC 17's option (a), coverage shift ACCEPTED). Named rather than
##     absorbed, and the SECOND item is a correction to AC 17's own accounting block, proven by
##     measurement rather than reasoned:
##       LOST (1), named by AC 17: the t9 CHAINED-SWING coverage. `STUNNED` replaces `ATTACKING`
##         immediately, so the chain window never opens and the t9 press is dropped. Equivalent
##         coverage already exists and is unaffected by this story: test_action_state.gd's chain
##         block (last-tick accept, post-close drop, cap, roll-cancel reset).
##       LOST (2), NOT named by AC 17 -- REPORTED, not smoothed over: the t13 ORDINARY-BLOCK coverage,
##         which is a CONSEQUENCE of loss (1) rather than an independent one. `CONTACTS[13]` carries
##         `attack_index` 1, an index that only ever existed as P1's CHAINED swing; with the t9 press
##         dropped, P1's `attack_index` never leaves 0, no dedupe record for swing 1 is opened, and the
##         fact drops at `register_swing_hit`. Equivalent coverage: the entire ordinary-block ladder in
##         test_block_deflect.gd, unaffected by this story. The loss is now ASSERTED as a loss (P2 at
##         120.0 at t13 and t24) rather than left implicit.
##       PRESERVED, as AC 17 predicted and measurement confirms: the t17 roll-cancel press (P1 is back
##         to IDLE at t12, well clear of it), the t19/t20 iframe grace-tick boundary (P1 is ROLLING,
##         not STUNNED, at both), and `roll_direction`'s `4-6/R7` fallback coverage.
##       GAINED: `STUNNED` appears in the hashed record at all, on a fixture that had never exercised
##         the state; a positive golden-level proof that a press against the empty `stunned` row is
##         DROPPED, never buffered; the orphaned-window shape (`attack_phase()` resting at
##         `active_done`); and AC 10's `add()`-not-`spend()` regen contract, visible as arithmetic.
##
##   NOT a cause: any snapshot SHAPE change (there is none -- no new key, no widened key); the two
##     `.tres` authored values AC 1/AC 2 ship (`_golden_config` is built in-test, so `BC/R3` survives
##     intact -- which is exactly why those values needed their own bespoke audit); the dodge rung,
##     whose multiplier this fixture deliberately does not author because the path is unreachable here;
##     `color_counter_stun_seconds`, for the same reason; and `_iframe_open_at_step3`, which is a
##     per-tick transient excluded from `to_snapshot()` by the `_deflect_closed_this_tick` argument.
## Previous golden d9725092fb420c855bf7ff1efef2510f1d285785729bbfa4feb3bf6ffa2fa014
## (story 5-5, unblockable defense -- the record below).
##
## RE-BASELINED BY STORY 5-5 (unblockable defense), dc2c9ffa -> d9725092, ONE CAUSE MEASURED IN BOTH
## DIRECTIONS. The story PREDICTED the golden would move exactly once, for exactly one reason -- the
## new `defense` per-player snapshot key (its AC 16) -- and predicted that a move for any OTHER
## reason would be a FINDING rather than a pass. Measured: it moved for exactly that reason and no
## other.
##
##   THE ONE CAUSE: the SNAPSHOT KEY SET, TWENTY-NINE -> THIRTY. `PlayerState.to_snapshot()` gains
##     ONE key, `defense`, carrying the armed mode ③ reaction window as `[colour, remaining_ticks]`.
##     FUSED into one key, not split into two, on the `telegraph`/`lock_target` precedent and for
##     their reason: a defense is ONE fact in two halves, and splitting it would let the halves
##     disagree about whether a defense is armed at all. Pinned by test_card_observation.gd (whose
##     size assertion moves 29 -> 30) and test_draw_delay_and_reshuffle.gd, both ORDER-SENSITIVE
##     literals -- the key's sorted position is between `deck_size` and `discard_size`, NOT beside
##     `telegraph`.
##
##   ITS PRESENCE IS THE MOVER; ITS VALUE NEVER LEAVES THE RESTING ONE. This is the `5-2` shape and
##     explicitly NOT the `5-4` one: `5-4`'s `orbs` key ALREADY EXISTED, so hanging a grant path
##     behind it moved nothing, while THIS key is genuinely new and its resting value changes the
##     snapshot dictionary's SHAPE on every tick of every match, reached or not. MEASURED, not
##     argued: the fixture builds its intents from a fixed MOVES table plus ONE named cast at
##     CAST_TICK, which is mode ①/② content and never DEFENSE -- so no defense window is ever armed
##     and the key hashes at `[-1, 0]` throughout. That measurement is PINNED as an assertion rather
##     than left as a claim here, by
##     test_the_fixture_reaches_the_hash_tick_with_no_defense_window_armed below (the `4-3b`
##     falsified-cause discipline applied again).
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with the `defense`
##     key held OFF `PlayerState.to_snapshot()` and EVERYTHING ELSE this story ships left in place --
##     the DEFENSE dispatch arm and `_resolve_defense_cast` with its flag gate, CHARGING refusal,
##     empty-slot guard and fifth stamina seat; the two new `defense_window.tick()` lines at step 2;
##     the landing intercept inside `_resolve_charge_contact`; the `_reset_player` fourth exception;
##     the widened `deflect_landed` signal and its second emit site; and the two new BalanceConfig
##     fields with their `BalanceTicks` conversion -- this file hashed dc2c9ffa EXACTLY: the
##     pre-story golden, unchanged. Measured at the dev pass by deleting those three lines, running
##     the harness (the two key-set pins failed and test_state_matches_golden PASSED, which is the
##     result), and restoring from a SHA256-verified out-of-repo copy (3ef08797...).
##
##   NON-MOVER 1, `FORMAT_VERSION` STAYS AT 7 -- a CLOSED, gate-verified answer restated here as
##     MEASURED rather than re-opened. Unlike `5-2`'s 6 -> 7 bump (forced by `inject_card_colors`, a
##     genuinely new MatchState injection seam the recorder had to learn), mode ③ reads the SAME
##     `_card_colors` map mode ② already injects: no new intake surface, no new injection seam, no
##     new contact kind, and no new `InputIntent` field (`card_slot`/`card_mode`/`card_commit`
##     already carry everything it needs). This is the `5-4` shape -- a new resolution arm and new
##     balance fields over an EXISTING capture channel, not a new channel.
##
##   NON-MOVER 2, THE NEW BALANCE FIELDS: `defense_stamina_cost` and the defense window's own
##     duration (`defense_window_seconds` at 5-5; the per-colour `counter_busy_seconds_*` since
##     6-6b) are authored `.tres` tuning, isolated from this golden by standing `BC/R3` -- `_golden_config()`
##     builds its own in-test values and never loads the authored file. Re-tuning either cannot
##     re-baseline this hash.
##
##   NON-MOVER 3, THE WIDENED `deflect_landed` PAYLOAD: a SIGNAL, with no path into
##     `MatchState.to_snapshot()` at all. Named here only so a reader does not go looking for it
##     among the causes.
##
##   CAUSES UNREACHABLE HERE, named so nobody reads a green golden as coverage of them: the entire
##     mode ③ chain -- dispatch, the layer gate, the CHARGING refusal, the spend, the window, the
##     colour copy, the landing intercept and the reset clear -- because the fixture never casts
##     mode ③ and pushes no charge-reach fact. They are proven in test_unblockable_defense.gd.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 6-2 (pitch staging), 9679fa80 -> 72d3cc6e, ONE CAUSE, MEASURED IN BOTH
## DIRECTIONS. The story's Golden Prediction was MOVED, certain by construction, single named cause.
##
##   THE ONE CAUSE: `PitchState.to_snapshot()`'s NESTED SHAPE. The `"pitch"` key already sat in the
##     hashed run carrying a constant `{"fizzle": <stopped window>}`; it now carries both players' zone
##     records, `{"p1": {card_id, hand_slot, orb_costs, fizzle}, "p2": {...}}`. The TOP-LEVEL key set is
##     unchanged (`"pitch"` existed), pinned by test_debug_window_countdown.gd's top-level assertion.
##
##   ITS SHAPE IS THE MOVER; ITS VALUES NEVER LEAVE THE EMPTY RECORD. This fixture never commits
##     `card_mode == PITCH`, so both zones hash empty on every tick.
##
##   THE REVERSE DIRECTION, which is what makes the single cause attributable: with ONLY
##     `PitchState.to_snapshot()` returning its pre-story shape (`{"fizzle": _fizzle[0].to_snapshot()}`)
##     and EVERYTHING ELSE this story ships left in place -- the per-slot zone members, the step-2
##     `pitch.tick()`, the PITCH dispatch arm and staging seat, the step-6 fizzle seat, the reset clear,
##     the fifth injection seam, the two BalanceConfig fields and their BalanceTicks twin -- this file
##     hashed 9679fa80 EXACTLY (test_state_matches_golden PASSED). Measured at the dev pass and restored
##     from a SHA256-verified out-of-repo copy.
##
##   NON-MOVER 1, `data/feature_flags.tres`'s `pitch_zone = true` (AC 2a): MEASURED, not assumed. With the
##     authored line removed and every code change in place this file hashed 72d3cc6e, identical to the
##     flag-open run -- `_golden_flags()` builds its own FeatureFlags and never reads the authored file.
##
##   NON-MOVER 2, `FORMAT_VERSION` 8 -> 9 and the new `capture_inject_pitch_costs` channel: the recorder
##     has no path into `MatchState.to_snapshot()`, and this fixture injects no pitch-cost map at all
##     (the seam is optional state-side, AC 2).
##
##   NON-MOVER 3, the nine authored card pitch costs and the two new balance fields: `.tres` content
##     isolated by `BC/R3` -- the golden builds its own config, composition and costs in-test.
##
##   CAUSES UNREACHABLE HERE, named so nobody reads a green golden as coverage of them: the whole
##     staging chain -- layer gate, refusals, spend, hole, optional orb clear, countdown, READY, fizzle
##     and its owed replacement, reset clear -- because the fixture never stages. They are proven in
##     test_pitch_staging.gd and, through a recorded run that stages, in test_replay_identity.gd.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED A SECOND TIME BY STORY 6-2's REVIEW FIX PASS (finding H1), 72d3cc6e -> 9ed4c903,
## ONE CAUSE, MEASURED IN BOTH DIRECTIONS. A SEPARATE cause from the first re-baseline above.
##
##   THE ONE CAUSE: `PitchState.to_snapshot()`'s per-zone dict SHRINKS. Review finding H1 found the
##     staged card's orb PRICE hashed alongside its identity -- card `.tres` CONTENT, which `3-2`'s
##     close-out rules must never enter the hashed run (a reprice must never re-baseline the golden).
##     The `"orb_costs"` key is removed from `_zone_snapshot()`; each zone now carries three keys
##     (`card_id`, `hand_slot`, `fizzle`), not four. `_orb_costs` stays a `PitchState` member (an
##     unhashed cache `is_ready()` reads live), so nothing about READY or staging behaviour changed --
##     only the snapshot's SHAPE.
##
##   ITS SHAPE IS THE MOVER AGAIN; ITS VALUES NEVER LEFT THE EMPTY RECORD EITHER TIME. This fixture
##     still never commits `card_mode == PITCH` (the first re-baseline's note above, unchanged), so
##     both zones hash empty on every tick before and after this fix.
##
##   THE REVERSE DIRECTION: with ONLY `_zone_snapshot()` returning the FOUR-key shape again
##     (`orb_costs` restored) and every other review fix in place, this file hashed `72d3cc6e…`
##     EXACTLY (`test_state_matches_golden` PASSED) -- the pre-fix-pass golden, reproduced. Measured
##     at the fix pass and restored from a SHA-256-verified out-of-repo copy
##     (`5cf13c9514029570b3a452ed1c3e8c7fab6498d5b4e252fde9fa1fdc596ef3fc`, before == after).
##
##   NOTHING ELSE MOVED: `UNHASHED_CROSS_TICK_MEMBERS` moving 3 -> 4 (`_orb_costs` reclassified,
##     `test_replay_identity.gd`) is a CLASSIFICATION change, not a snapshot-shape change, and carries
##     no hash consequence by construction -- confirmed by this being the ONLY named cause above.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 6-7 (locomotion gaits), 9ed4c903 -> 71a7b45f, ONE re-baseline, ONE named
## cause, PREDICTED in the story's Golden Prediction section (Fact M6 Direction B) and CONFIRMED
## the sole cause by measurement in both directions, exactly as AC 15 requires.
##
##   THE ONE CAUSE: `HeroState.to_snapshot()` gains `"run_locked_out"` -- the R6 gait-lockout
##     hysteresis latch (AC 5), a genuinely new hashed member reaching the snapshot through the
##     existing `player_state.hero` chain. It CROSSES TICKS (persists until stamina crosses the
##     authored resume threshold) and DECIDES AN OUTCOME (whether RUN may resume), the
##     `lock_target_slot`/`charge_window` precedent's exact test -- HASHED, no
##     `UNHASHED_CROSS_TICK_MEMBERS` bump (stays at 4).
##
##   NOT A CAUSE, MEASURED: `walk_speed`/`run_stamina_drain_per_second`/`run_resume_stamina_percent`
##     are authored balance VALUES, not new state members. `_golden_config()` authors `walk_speed`
##     EQUAL TO `MOVE_SPEED` (Task 6(c)) specifically so gait is a no-op in the golden fixture (no
##     golden intent builder presses `&"run"`) -- per the standing `BC/R3` isolation, these three
##     fields alone move nothing.
##
##   ISOLATED BOTH DIRECTIONS: with `"run_locked_out"` temporarily removed from `to_snapshot()`
##     and nothing else changed, `test_state_matches_golden` hashed `9ed4c903…` EXACTLY (the
##     pre-story golden, reproduced) -- confirming the latch field is the one and only cause. The
##     removal was reverted immediately after measuring; no other line moved.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 6-6a (defense reactions), 71a7b45f -> d437432f, ONE re-baseline, ONE named
## cause -- the story's Golden Prediction cause 4 -- CONFIRMED the sole cause by measurement in both
## directions. Snapshot key-path set 198 -> 206; `RecordFile.FORMAT_VERSION` measured 11 before and 11
## after (no recorded input channel changed).
##
##   THE ONE CAUSE: `HeroState.to_snapshot()` gains `"get_up_iframe"` -- the get-up iframe TimingWindow
##     (AC 8), HASHED on `roll_iframe`'s test. The fixture never knocks anyone down, so the key reaches
##     the hash tick AT REST on both heroes (`{duration 0, elapsed 0, running false}`) -- its mere
##     PRESENCE is the move, the `5-5` `defense` key's shape (pinned below by
##     test_the_fixture_reaches_the_hash_tick_with_no_get_up_iframe_armed).
##
##   NOT A CAUSE, MEASURED (causes 1-3): the knockdown write, the deferred landing package and its
##     per-tick latch (`_landing_package_pending`, PER_TICK -- never snapshotted), the CHARGING
##     abandonment and the floor rule all sit on the unanswered-unblockable path this fixture never
##     reaches (it never enters CHARGING, see the 5-2 block above); `knockdown_stun_seconds` /
##     `get_up_iframe_seconds` are authored balance (`BC/R3`); the presentation changes touch nothing
##     under src/state/.
##
##   ISOLATED BOTH DIRECTIONS: with the two heroes' `get_up_iframe` keys erased from the finished
##     fixture snapshot (a scratch probe, no source edit) the hash is `71a7b45f…` EXACTLY -- the
##     pre-story golden reproduced with every other 6-6a change in place.
## ---------------------------------------------------------------------------------------------
## ---------------------------------------------------------------------------------------------
## RE-BASELINED BY STORY 6-5a (spell framework and buffs), d437432f -> 59e9a42c, ONE re-baseline,
## THREE named causes, each MEASURED on its own by a scratch probe that erased or rest-valued keys on
## the FINISHED fixture snapshot (no source edit -- the 6-6a method). Snapshot key-path set 206 -> 210
## (two new per-player keys x two players; neither is hero-nested). `RecordFile.FORMAT_VERSION`
## measured 12 before and 13 after (the pitch-effect channel) -- a record concern with no path into
## the hash, so not a golden cause.
##
##   CAUSE 1, PRESENCE: `PlayerState.to_snapshot()` gains `"timed_rules"` (AC 8), the timed-rule seat.
##     The fixture casts no buff, so all six rule slots hash AT REST (`[0, 0.0, 0.0]`) on both players
##     -- the `5-5` `defense` shape. Measured: d437432f -> a7985a17 with only this key added.
##   CAUSE 2, PRESENCE: `"last_resolved_card"` (AC 10), at its resting value `["", -1]`. Measured:
##     a7985a17 -> 113d8834 with the key present on both players at rest.
##   CAUSE 3, VALUE: the t22 Mode ① cast is a RESOLUTION, so P1's record carries
##     `["golden_card_10", 0]` (BASIC) at the hash tick; P2 cast nothing and stays at rest. Measured:
##     113d8834 -> 59e9a42c, the full snapshot.
##
##   ISOLATED BOTH DIRECTIONS: with both new keys erased from the finished fixture snapshot the hash is
##   `d437432f...` EXACTLY -- the pre-story golden reproduced with every other 6-5a change in place (the
##   funnel at rest, the new step-2 tick, the pitch-effect seam, the shared apply seat).
##
##   NOT A CAUSE, MEASURED: the damage funnel is bit-identical at rest (no Bloodlust in the fixture, so
##   neither multiply branch runs); the summon path moved into `_apply_card_effect` unchanged; the
##   fixture injects no pitch-effect map (the seam is optional state-side).
## ---------------------------------------------------------------------------------------------
## STORY 6-5b RE-BASELINE: `59e9a42c...` -> `962514b1...`, ONE MEASURED CAUSE, FIVE PREDICTED.
##
##   THE CAUSE (cause 1 of the story's Golden Prediction): THREE NEW SNAPSHOT KEYS, all on the board
##   (`6-5b/R17`) -- `unit_corpse_ticks`, `unit_corpse_extended` and `unit_raised_from`. Their mere
##   PRESENCE at resting values, the 3-5a `discard_size` / 4-1 `unit_count` shape. The per-player key
##   set moves THIRTY-THREE -> THIRTY-SIX (pinned by test_card_observation.gd).
##
##   ISOLATED BOTH DIRECTIONS: with exactly those three keys erased from `PlayerState.to_snapshot()`
##   and EVERY OTHER 6-5b change still in place -- the death seat, the corpse countdown at step 2, the
##   four new resolver outcomes and their apply seats, both pre-spend refusal gates, Drain's pushed
##   intake, the authored effect numbers, the FORMAT_VERSION bump -- the hash is `59e9a42c...` EXACTLY,
##   the pre-story golden reproduced. So the three keys are the whole of the move, and the other four
##   predicted causes are MEASURED NON-MOVERS rather than assumed ones.
##
##   THE PREDICTION'S OWN CONTENT CLAIM MEASURED FALSE, and is corrected rather than quietly dropped.
##   Cause 1 predicted "the corpse container enters the snapshot EMPTY -- measure key count `+N` and
##   contents `[]`". The EMPTY half is wrong: `6-5b/R17` closed the story's Open Question 1 on putting
##   corpse data at the DEAD UNIT'S OWN BOARD INDEX rather than in a separate container, so the three
##   keys are PARALLEL ARRAYS over every record (the `unit_hp` shape) and the fixture's ONE summoned
##   unit gives each of them ONE resting entry. `[]` would have been right only for the container shape
##   the gate ruled out. Measured and pinned by
##   `test_the_golden_fixture_reaches_the_hash_tick_with_one_resting_corpse_entry` below.
##
##   NOT CAUSES, EACH MEASURED BY THE ISOLATION RUN ABOVE:
##     * cause 2, THE REFUSAL PATH (AC 9/13/15/21, `6-5b/R14`). Predicted to move the golden under the
##       standing `SC/R6` boundary ("a change that adds a new refusable outcome to an existing seat
##       moves BOTH the golden and the unit suite"). It moved the UNIT SUITE and NOT the golden, and
##       the reason is specific rather than a loophole: the golden fixture's one cast is a `summon_*`,
##       which has no board precondition, so `_board_refusal_reason` returns `&""` and no gate is ever
##       taken on the recorded path. `SC/R6` is not contradicted -- it describes a change that makes a
##       pressed action refusable IN THE RECORDED SEQUENCE, and this fixture never presses one of the
##       four cards.
##     * cause 3, DRAIN'S INTAKE. `_drain_targets` is a runner-pushed fact classified
##       UNHASHED_CROSS_TICK (test_replay_identity.gd, argument (c), the `_lock_directions` family), so
##       it reaches no snapshot by construction. It needed a CAPTURE CHANNEL, which it has, not a key.
##     * cause 4, THE FOUR AUTHORED EFFECT NUMBERS plus Culling's `kill_cap`. The golden fixture builds
##       its own effects in-test (`_golden_config` / the fixture's effect map) and never loads
##       `data/effects/`, so authoring those five numbers is outside the golden's path entirely -- the
##       `BC/R3` isolation the story doubted, holding here for the EFFECT injection set as well.
##     * cause 5, `RecordFile.FORMAT_VERSION` 13 -> 14. A record carries INPUTS and CONTENT, never a
##       hash and never a snapshot, so a version bump cannot move this value. It IS a real change (AC
##       26) with its own refusal test; it is simply not a golden cause.
## ---------------------------------------------------------------------------------------------
## STORY 6-5c RE-BASELINE: `962514b1...` -> `97d52922...`, THREE MEASURED CAUSES, SEVEN PREDICTED.
##
##   ALL THREE ARE NEW SNAPSHOT KEYS AT THEIR RESTING VALUES -- the 3-5a `discard_size` /
##   6-5b corpse-key shape a fourth time. The fixture never casts Honed Bolt (its one cast is a
##   `summon_*`), so not one of the three has a BEHAVIOURAL cause to measure beside its presence.
##   Each was isolated by ADDING IT BACK to the erased-key build, one at a time, in this order:
##
##     cause 1  `cast`         (per-player, `[card id, remaining_ticks]`, resting `["", 0]`)
##              962514b1... -> c4f42153b36869d4905e5a322dce8b35352c841175a7ff444fd2f14ed32ce3fa
##     cause 2  `root`         (per-player, `[remaining, blocks_run, blocks_roll]`, resting
##              `[0, false, false]`)
##              c4f42153... -> 8736d846b6fb2432c319028e256945d8cf18b712f72ddc5798b5f0061a6c64ed
##     cause 3  `stun_is_bolt` (HERO, resting `false`; `6-5c/R16`'s discriminator)
##              8736d846... -> 97d52922e4e6282b37582e8c3a9c424a02337162881c37a7f6a3394277efdc92
##
##   THE PER-PLAYER KEY SET MOVES THIRTY-SIX -> THIRTY-EIGHT (pinned by test_card_observation.gd) and
##   the HERO key set gains one (pinned by test_debug_window_countdown.gd). The story's Golden
##   Prediction deliberately refused to say WHICH of the two pins the root would move; MEASURED, it is
##   the PER-PLAYER one, because the root is a CARD-LAYER duration and sits beside `charge_window` /
##   `defense_window` on `PlayerState` (see `player_state.gd`'s own seating argument). The
##   discriminator moved the HERO pin instead, because it belongs to the BODY's stun.
##
##   ISOLATED BOTH DIRECTIONS: with exactly those three keys erased and EVERY OTHER 6-5c change still
##   in place -- the cast window and its identity, the cast fork at the press seat, the three
##   commitment locks, the step-6c strike seat, the bolt's damage/stun/root, the root's two refusals,
##   the resolver's cast table, the authored `honed_bolt.tres` numbers and the FORMAT_VERSION bump --
##   the hash is `962514b1...` EXACTLY, the pre-story golden reproduced. So the three keys are the
##   whole of the move, and the other four predicted causes are MEASURED NON-MOVERS, not assumed ones.
##
##   NOT CAUSES, EACH MEASURED BY THAT SAME ISOLATION RUN:
##     * cause 3 of the prediction, THE STUN WINDOW'S KEY. Confirmed: `stun` already existed, so the
##       bolt's new write site adds no key. (The DISCRIMINATOR beside it is a separate, real cause --
##       cause 3 above -- and the prediction said so.)
##     * cause 4, THE NEW REFUSABLE OUTCOMES (a card press refused while casting, `6-5c/R6`; a roll
##       press refused while rooted, `6-5c/R14`). Predicted a NON-cause and MEASURED one, for 6-5b's
##       identical reason: `SC/R6` describes a change that makes a pressed action refusable IN THE
##       RECORDED SEQUENCE, and this fixture never casts and is never rooted, so neither refusal is
##       ever taken on the recorded path. The UNIT SUITE moved regardless, exactly as predicted.
##     * cause 5, THE AUTHORED `honed_bolt.tres` NUMBERS AND THE SEVEN NEW `CardEffect` DEFAULTS --
##       including the LIVE 0.8 `cast_seconds` default, which is the one most likely to leak. The
##       golden builds its effects in-test and never loads `data/effects/`, so `BC/R3`'s isolation
##       holds for the EFFECT INJECTION SET as well, a second time after 6-5b measured it. Stated
##       separately from causes 1-2 as the prediction required: the injection set's SHAPE moved
##       nothing.
##     * cause 6, `RecordFile.FORMAT_VERSION` 14 -> 15. A record carries INPUTS and CONTENT, never a
##       hash and never a snapshot, so a version bump cannot move this value. It IS a real change
##       (AC 23) with its own refusal test; it is simply not a golden cause.
##     * cause 7, INTAKE. No new runner-pushed fact exists -- the bolt's target is always the enemy
##       hero, so there is nothing like Drain's pushed selection -- and no new parametered public
##       `MatchState` method ships, so `test_intent_recorder.gd` stayed green unedited.
##
## ---------------------------------------------------------------------------------------------
## STORY 6-5d (AC 30, Golden Prediction): ONE RE-BASELINE, 97d52922... -> de3589ff..., FOR THREE
## SNAPSHOT-SHAPE CAUSES, EACH MEASURED IN ISOLATION AND NONE OF THEM BEHAVIOURAL.
## ---------------------------------------------------------------------------------------------
##   ISOLATION, BOTH DIRECTIONS, RUN FIRST (the 6-5a/6-5b/6-5c method verbatim): with exactly the new
##   keys erased from `to_snapshot()` and EVERY OTHER 6-5d change still in place -- the variable-cost
##   staging, the pitch cast fork, the mode-aware strike lookup, the targeted bolt, `_apply_fireball`,
##   the target-only contact rung, the block exemption, the funnel/lifesteal widening, the per-shot
##   damage, the dead-target homing end, the M6 reload refusal, the authored `fireball.tres`, the
##   pairing swap and the FORMAT_VERSION bump -- the hash is `97d52922...` EXACTLY, the pre-story
##   golden reproduced. So the three key groups are the WHOLE of the move, and every other predicted
##   cause is a MEASURED non-mover rather than an assumed one.
##
##   THEN EACH GROUP ALONE, from that same erased base:
##     cause 1  the PITCH ZONE's two frozen facts (`mana_spent`, `locked_damage`, per zone, resting
##              0.0 -- and the fixture's t22 staging makes `mana_spent` a LIVE 3.0 at hash time, not
##              merely a shape change)
##              97d52922... -> ea53044adf20d7e9185b62056fddd8044da54e7050cb5fe2bb613de58990c4e7
##     cause 2  the `cast` KEY EXTENDED two elements -> six (mode, captured target slot, captured
##              target index, locked damage), resting
##              `["", 0, -1, -1, -1, 0.0]`
##              97d52922... -> 057f9da61517536372c8636baacaa39b3b195c401f2869d9440f91bb234851ca
##     cause 3  the PROJECTILE BOARD's two new keys (`projectile_effect`, `projectile_damage`, both
##              empty arrays at rest -- the fixture launches no shot)
##              97d52922... -> 892fe0257fb79a8f0d05833216632174827d8d2fb702d60c16cabd2b7d662f95
##   All three together are this constant. Each moves the hash ON ITS OWN, which is what makes them
##   three causes rather than one event reported three times.
##
##   THE PER-PLAYER KEY SET MOVES THIRTY-EIGHT -> FORTY, and cause 2 is deliberately NOT part of that
##   move: the four facts a cast carries EXTEND one existing key instead of adding four, so the shape
##   cause and the key-set cause stayed separately measurable. The story's prediction allowed either
##   shape and asked the dev pass to record which; this is the record.
##
##   NOT CAUSES, EACH MEASURED BY THE ISOLATION RUN ABOVE:
##     * prediction cause 5, THE NEW REFUSABLE OUTCOMES. Predicted a NON-cause and MEASURED one. No new
##       refusal token ships at all: the below-minimum staging reuses `REASON_INSUFFICIENT_MANA` and the
##       cast lock reuses `REASON_CASTING`. `SC/R6`'s boundary is about a pressed action made refusable
##       IN THE RECORDED SEQUENCE, and this fixture's t22 staging is affordable on both sides.
##     * prediction cause 6, THE AUTHORED `fireball.tres` NUMBERS, THE PAIRING SWAP AND THE EIGHT NEW
##       `CardEffect` DEFAULTS. `BC/R3`'s isolation holds for the EFFECT INJECTION SET a third time:
##       the golden builds its effects in-test and never loads `data/effects/`, so neither the new
##       fields' presence nor the swap reaches this hash. Measured apart from causes 1-3 as the
##       prediction required -- the injection set's SHAPE moved nothing.
##     * prediction cause 7, THE HONED BOLT TARGET CAPTURE. Predicted unmoved and MEASURED unmoved:
##       the resting lock IS the opposing hero (`_reset_lock`), so a captured address of `[1, -1]` is
##       arithmetically the `1 - slot` it replaces, and the fixture never locks a unit.
##     * prediction cause 8, `RecordFile.FORMAT_VERSION` 15 -> 16. A record carries INPUTS and CONTENT,
##       never a hash and never a snapshot. A real change (AC 31) with its own refusal test; not a
##       golden cause.
##     * prediction cause 9, INTAKE. No new runner-pushed fact and no new parametered public
##       `MatchState` intake: `projectile_profile_at` became public as a PURE QUERY and is exempt, and
##       `apply_balance`'s new return value is not an intake widening.
## ---------------------------------------------------------------------------------------------
## =============================================================================================
## STORY 6-5e RE-BASELINES ONCE: `de3589ff...` -> `98eaee53...`. THREE CAUSES, each the mere PRESENCE of a
## new per-player snapshot key at its RESTING value, each isolated and measured IN BOTH DIRECTIONS by
## erasing it from `PlayerState.to_snapshot()` with every other change in place.
##
## THE DECISIVE MEASUREMENT IS THE FIRST ONE: with ALL THREE keys erased and nothing else reverted, the hash
## returned to `de3589ff...` EXACTLY. That is what makes every other change in this story a MEASURED
## non-mover rather than an assumed one -- and it covers, in one run, the whole of the story's own predicted
## non-cause list plus several the prediction did not raise:
##   * cause 3, A BURST OF SEVERAL HERO-SOURCED RECORDS FROM ONE CAST. Predicted a non-cause of the
##     snapshot SHAPE and measured one: the per-record fields are 6-5d's, and this fixture fires no
##     Rocksling, so its RESTING content is unmoved too.
##   * cause 5, THE TWO NEW REFUSAL REASONS (`REASON_COVERED_SLOT`, `REASON_NO_OPPOSING_BOULDER`).
##     Predicted CAUSES under `SC/R6` and MEASURED non-causes: that boundary is about a pressed action made
##     refusable IN THE RECORDED SEQUENCE, and this fixture presses neither a covered slot (it never plants
##     a Boulder) nor a Boom activation. The prediction was right to demand the measurement and wrong about
##     its outcome, which is recorded here rather than quietly dropped.
##   * cause 5a, `_rng`'s SECOND CONSUMER. Predicted a cause and MEASURED a non-cause FOR THIS FIXTURE:
##     `_place_boulder` is the only new draw and it is reached only by a landed Rocksling stone, which this
##     sequence never fires -- so `rng_state` is untouched and no later reshuffle order moves. The mechanism
##     is real and is proven by its own test; it simply is not on this fixture's path.
##   * cause 5b, `hand_size` SEMANTICS (M2). Measured unmoved: the key binds to the CARD layer, and this
##     fixture covers nothing.
##   * cause 5c, THE BOULDER SLOW (S1). Measured a non-cause twice over: it needs no hashed field of its
##     own (it is a pure fold over `hand_covered`, argued at that key), and the fixture holds no Boulder.
##   * cause 6, THE AUTHORED `.tres` NUMBERS. `BC/R3`'s isolation holds a fourth time: the golden builds
##     its effects in-test and never loads `data/effects/`, so the two new `CardEffect` fields' presence and
##     the new `BalanceConfig` field reach nothing here.
##   * NOT PREDICTED AND ALSO MEASURED UNMOVED: the widened flight-profile mirror (AC 1a), the new
##     `add_minion_shot` seat, the `Hand` cover layer itself, the `visible_id_at` guard swap in
##     `_resolve_basic_cast`, and `cards_changed` carrying the visible layer. Each is live code on this
##     fixture's path or adjacent to it, and none of them moves the hash.
##   * `RecordFile.FORMAT_VERSION` 16 -> 17 is a real change with its own refusal test (AC 39) and is not a
##     golden cause: a record carries INPUTS and CONTENT, never a hash.
##   * INTAKE: none. No new runner-pushed fact and no new public `MatchState` intake.
##
## THE THREE CAUSES, EACH MEASURED ALONE (every other new key erased):
##   1.  `hand_covered` ALONE -> `5545f4f973c8ad434f244887b1398a8c909085665a5d8bf346e0bea986f47b49`.
##       The per-slot Boulder cover mask. At rest it is `[false, false, false, false]` -- a NEW key whose
##       resting value changes the snapshot dictionary's SHAPE on every tick of every match (the `5-2`
##       `defense` shape, not the `5-4` `orbs` one).
##   1a. `burst` ALONE -> `1da2773cdd9f0bfa930192ab976769cc868ae870c5992da6622f43dda44e37ea`.
##       The pending Rocksling schedule (`6-5e/R21`/G2). At rest `["", 0, 0, -1, -1, 0.0]`.
##   2.  `corpse_bomb` ALONE -> `427bbe6fbcbdeef045b7a9f4ba86aa41efd2f941ed27d6f2cb8d38210233dcec`.
##       Corpse Bomb's per-activation conversion record (ruling 14). At rest `[-1, []]`. Stored rather than
##       derived, and the reason is measured rather than asserted: a Corpse Bomb corpse and a melee-kill
##       corpse made on the same tick are bit-identical in `UnitBoard`, so the corpse container carries
##       nothing to derive the partition from.
##
## ALL FOUR HASHES ARE DISTINCT -- from the baseline, from each other and from the final value -- which is
## what makes the three keys three independent causes rather than one event with three symptoms.
## =============================================================================================
## ---------------------------------------------------------------------------------------------
## STORY 6-5f RE-BASELINE (Counterspell): `98eaee53...` -> `941958c5...`, ONE re-baseline, THREE
## MEASURED CAUSES out of EIGHT PREDICTED. Per-player snapshot key set 43 -> 45. `FORMAT_VERSION`
## measured 17 before and 18 after (AC 29) -- a record concern with no path into the hash, so not a
## golden cause, the standing reading since 6-5a.
##
## Each cause was measured by ERASING its key (or its array member) from `PlayerState.to_snapshot()`
## with EVERY other change in place, restoring the file from an out-of-repo copy between measurements
## and verifying SHA256 both ways (`3-0d`'s mutation-restore discipline; never `git checkout --`).
##
##   CAUSE 1, SHAPE+VALUE: `"last_resolved_card"` gains a THIRD member, the RESOLUTION TICK (AC 5,
##     `6-5f/R31`). The per-player KEY COUNT does NOT move on this cause -- the array's arity does,
##     which is `cast`'s own 2 -> 6 extension precedent (6-5d). P1's t22 Mode ① cast is a resolution,
##     so P1 carries a real tick at the hash tick and P2 stays at the resting `-1`.
##     Measured ALONE (reversal and `unit_hp_at_death` erased): `b9ffa1da...`.
##   CAUSE 2, PRESENCE+VALUE: `"reversal"` (AC 2, Open Question 1), the per-resolution undo packet.
##     Measured ALONE (tick member and `unit_hp_at_death` erased): `a5c321f1...`.
##   CAUSE 3, PRESENCE: `"unit_hp_at_death"` (AC 23, `6-5f/R32`), one float per record. The fixture's
##     t22 summon never dies, so every entry hashes at its resting `0.0` -- the `unit_corpse_ticks`
##     shape verbatim. Measured ALONE (tick member and reversal erased): `f3c4e4d6...`.
##
##   FOUR DISTINCT HASHES, so the three causes are INDEPENDENT and none masks another.
##
##   ISOLATED BOTH DIRECTIONS: with all three erased from `PlayerState.to_snapshot()` the hash is
##   `98eaee53...` EXACTLY -- the pre-story golden reproduced with every other 6-5f change in place
##   (the moved-and-gated resolved-card write, the six apply-arm recorders, the new board gate, the
##   whole reversal path, `restore_corpse_at`, the new `CardEffect` export).
##
##   NOT CAUSES, MEASURED RATHER THAN ASSUMED -- and all three were PREDICTED as movers or possible
##   movers, so the reverse measurement above is what settles them:
##     * `_resolve_basic_cast`'s `record_resolved_card` write gated on `not clears_cover` (AC 8,
##       predicted cause 3): a BEHAVIOUR change, live during the reverse measurement, which still
##       returned to `98eaee53` -- the fixture's recorded sequence contains no Boulder clear.
##     * Counterspell's new no-target board-gate refusal and the AC 13 interim refusal (predicted
##       cause 5, the standing `SC/R6` boundary): the fixture never stages or activates Counterspell,
##       so no pressed action in the recorded sequence became refusable.
##     * `counter_window_seconds`'s authored value and its injection SHAPE (predicted cause 6,
##       `BC/R3`): the golden builds its effects in-test and never loads `data/effects/`.
##     * No RNG cause (AC 24): Counterspell's resolution consumes none, and the fixture never runs it.
## ---------------------------------------------------------------------------------------------
## STORY 7-8 RE-BASELINE (unblockable honest contact): `941958c5...` -> `1b1478ac...`, ONE re-baseline,
## ONE MEASURED CAUSE, exactly the one predicted (`7-8/R15`): the new per-player `charge_contact` key
## (the hit-once memory), key set 45 -> 46. The fixture never casts mode (2), so the key hashes at its
## resting 0 on every tick and its PRESENCE alone is the cause. `FORMAT_VERSION` 19 -> 20 is a record
## concern with no path into the hash.
##
##   ISOLATED BOTH DIRECTIONS (measured, restored from an out-of-repo copy with SHA256 verified both
##   ways): (a) with the key erased from `PlayerState.to_snapshot()` and every other 7-8 change in place
##   -- the per-tick contact fact, the touch-tick seat, the retired arc and dodge multiplier -- the hash
##   is `941958c5...` EXACTLY; (b) with it restored, `1b1478ac...` on two separate runs.
## ---------------------------------------------------------------------------------------------
## STORY 7-9 RE-BASELINE (unblockable tempo): `1b1478ac...` -> `9d5d4fad...`, ONE re-baseline, ONE
## MEASURED CAUSE, exactly the one predicted: the new HERO snapshot key `unblockable_immunity` (the
## knockdown breather, AC 11). The fixture never knocks a hero down, so the key hashes at rest on every
## tick and its PRESENCE alone is the cause (pinned: `test_the_fixture_reaches_the_hash_tick_with_no_
## unblockable_immunity_armed`). The per-player key set stays 46 -- the key is seated on the hero.
## `FORMAT_VERSION` 20 -> 21 is a record concern with no path into the hash.
##
##   ISOLATED BOTH DIRECTIONS (measured, restored from an out-of-repo copy with SHA256 verified both
##   ways): (a) with the key erased from `HeroState.to_snapshot()` and every other 7-9 change in place --
##   the mana seat and its refusal, the defence-legality capture and refusal, the counter lead and the
##   reward, the steering seat, the immunity window's arming and its contact-seat branch -- the hash is
##   `1b1478ac...` EXACTLY; (b) with it restored, `9d5d4fad...` on two separate runs.
##
##   NOT CAUSES, MEASURED BY (a) RATHER THAN ASSUMED: the unauthored mana cost (the fixture never casts
##   mode 2), the R5 refusal (the fixture never presses DEFENSE, so no recorded action became refusable,
##   the `SC/R6` boundary), the steering / reward / lead (nothing charges, nothing counters), the authored
##   damage 6 and run 4.6 (`BC/R3`: `_golden_config` authors its own), and no RNG draw anywhere.
## ---------------------------------------------------------------------------------------------
## STORY 7-4 RE-BASELINE (pitch speeds): `9d5d4fad...` -> `43449bd9...`, ONE re-baseline, ONE MEASURED
## CAUSE, exactly the one predicted: the new `fresh_orbs` sub-dictionary under EACH pitch zone of the
## existing top-level `"pitch"` key (`{"red", "blue", "green"}`, plain ints) -- 8 new nested key paths, 4 per
## zone. The fixture never stages a pitch card, so both zones hash the resting zeros on every tick and the
## keys' PRESENCE alone is the cause. Neither pinned key set moves: the top-level set (`"pitch"` existed) and
## the per-player set (the keys are not on a player). `FORMAT_VERSION` 21 -> 22 is a record concern with no
## path into the hash.
##
##   ISOLATED BOTH DIRECTIONS (measured, restored from an out-of-repo copy with SHA256 verified both ways):
##   (a) with the `fresh_orbs` block erased from `PitchState._zone_snapshot` and every other 7-4 change in
##   place -- the speed field, the fresh-orb member and its credit at the faucet, the sorcery READY rule, the
##   widened `pitch_changed` payload, the runner's launch seed -- the hash is `9d5d4fad...` EXACTLY; (b) with it
##   restored, `43449bd9...`.
##
##   NOT CAUSES, MEASURED BY (a) RATHER THAN ASSUMED: the speed (content, never hashed, and the fixture's
##   in-test pitch costs author none, so every card reads instant), the sorcery READY rule and the credit (the
##   fixture never stages), and the launch seed (the golden builds `MatchParams.new(SEED)` itself and never
##   boots the runner).
## ---------------------------------------------------------------------------------------------
const GOLDEN := "43449bd9e513e90066cfabac77a93f0d7dfced60025f00e5e6b467002a0ca814"

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
## Story 4-6 (AC 2/AC 4): the PER-SLOT LOCK DIRECTION this fixture pushes, every tick, through
## `set_lock_direction` -- the seat the runner uses, modelled here the way `CONTACTS` models the
## contact channel. WITHOUT THIS LINE THE FIXTURE MEASURES A FALSE NON-MOVE ON HALF THE STORY,
## which is the standing lesson every value in this file is chosen against: with nothing pushed,
## facing simply freezes at its `Vector2.DOWN` construction default for all 24 ticks, P2 stops
## facing the incoming swings, and the t5 DEFLECT and t13 BLOCK -- coverage this fixture has
## carried since 1-8 -- would silently vanish rather than being preserved.
##
## CONSTANT, NOT CYCLED, and that is what a lock IS: the direction to a target changes only as the
## two move, and modelling it as a per-tick cycle would model a target teleporting around the
## board. Constant also keeps this fixture's ONE facing-derived transient -- the t17 roll's
## neutral-stick fallback -- attributable to the ruling that inverted it rather than to which
## entry of a cycle t17 happened to land on.
##
## THE VALUES ARE COVERAGE, NOT FEEL, like every number in this file, and are constrained on three
## sides simultaneously:
##   * OFF THE AXES and off every `MOVES` entry, so a facing write that regressed to the movement
##     source lands on a different value and MOVES the hash rather than coinciding with this one.
##   * UNIT LENGTH, because the runner pushes a normalised direction and a fixture that pushed an
##     unnormalised one would hash a state the production path cannot produce.
##   * P2's DIRECTION KEEPS THE 1-8 DEFENCE COVERAGE ALIVE, measured against the authored 180 deg
##     arc: the t5 fact arrives from (-1, -1), 8.1 deg off P2's (-0.8, -0.6) facing, and the t13
##     fact from (-1, 0), 36.9 deg off it -- both inside the front half-plane, so the DEFLECT and
##     the BLOCK both still resolve exactly as they have since 1-8.
## P1's (0.6, 0.8) additionally makes the `4-6/R7` backstep VISIBLE: the t17 neutral roll now locks
## (-0.6, 0, -0.8), which is neither the old (-1, 0, 0) nor its own inverse.
const LOCK_DIRS := [Vector2(0.6, 0.8), Vector2(-0.8, -0.6)]

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
	# Story 6-7 (Fact M6 Direction B guard, Task 6(c)): authored EQUAL TO MOVE_SPEED so the golden
	# moves for exactly the ONE named cause (the new gait-lockout latch field) and not a second,
	# unrelated one (every walk-gait velocity in the golden run going to 0.0) -- no golden intent
	# builder presses `&"run"`, so gait is a no-op here exactly like every other fixture in Task 6.
	c.walk_speed = MOVE_SPEED
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
	# Story 5-6 (AC 17) — THE TWO LINES THAT CARRY THIS STORY'S RE-BASELINE, and without them BOTH new
	# paths are hash-neutral degenerates rather than measured non-movers: `seconds_to_ticks` maps
	# `<= 0.0` to 0, `TimingWindow.start(0)` never runs, and `add(-0.0)` changes nothing. MEASURED
	# EXACTLY THAT WAY FIRST (see the re-baseline record above) — with the code in and these two lines
	# absent, the hash reproduced the inherited `d9725092...` bit for bit.
	#
	# WHY THE FIXTURE REACHES AC 9 AT ALL: `CONTACTS[5]` is P1's swing landing on a front-facing,
	# deflect-window-open P2 at t5, and it DEFLECTS by design (it has since 1-8). P1 is the attacker
	# and a HERO, so AC 9's `HERO_INDEX` gate fires. Nothing was added to the tables to make this
	# happen; the coverage was already there and this story gave it a consequence.
	#
	# 7 TICKS, coverage-not-feel like every value here and NOT the authored 0.4 s / 24 ticks. Chosen
	# DISTINCT from every other count this fixture carries ({2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 15, 16,
	# 17, 20, 22, 23, 24, 40, 60, 75, 90, 120, 180}) so a selector bug that read the wrong tick field
	# lands on a different number and MOVES the hash rather than silently coinciding. It is also
	# chosen SHORT on purpose: the stun starts at t5 and ends at t12, which leaves the t17 roll-cancel
	# press, the t19/t20 iframe grace boundary and `roll_direction` coverage all intact.
	c.deflect_stun_seconds = 7.0 / 60.0
	# 18.0, and every constraint on it is a stamina-legibility one (the `attack_stamina_cost` comment
	# above's discipline). P1: t1 attack 40 -> 34, regen t4 -> 35; t5 the deflect penalty and that
	# tick's regen both land (step 4 then step 5) -> 35 - 18 + 1 = 18; regen t6-t16 -> 29; t17 roll
	# spends 15 -> 14, delay t17-t19, regen t20-t24 -> 19 at the hashed final tick. NEVER CLAMPED at
	# the 40.0 maximum on any tick (which would erase the penalty from the record entirely — the
	# reason a smaller value was rejected) and never negative, and the t17 roll stays AFFORDABLE (29
	# >= 15) so the roll coverage survives. 18.0 is distinct from every other stamina magnitude here
	# (40 / 20 / 15 / 6 / 1.0).
	#
	# IT ALSO MAKES AC 10's `add()`-NOT-`spend()` CONTRACT VISIBLE TO THE HASH: `add()` does not
	# restart `_regen_delay`, so regen continues uninterrupted from t6. A `spend()` implementation
	# would suppress t5-t7 and land on a different final value — this line is what makes that
	# distinction a golden-level fact rather than a unit-test-only one.
	c.deflect_stamina_penalty = 18.0
	# The dodged-damage multiplier (retired at story 7-8, `7-8/R11`) was deliberately NOT authored here, for
	# `reshuffle_vulnerable_window_seconds`'s stated reason: this fixture's ONE recorded cast is
	# `ModeKind.BASIC` (`_play_sequence`), never `UNBLOCKABLE`, so `_resolve_charge_contact` is never
	# reached and the value cannot decide anything. Authoring it for a path this sequence does not
	# take would be coverage of nothing. (Its companion `color_counter_stun_seconds` was named here
	# on the same footing until 6-6b post-smoke retired the field, R-S6.) AC 5 / AC 7 / AC 8
	# are proven by test_unblockable_defense.gd instead, exactly as `5-5`'s `defense` key was.
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


## Story 6-5b: THE MEASURED CONTENT OF THIS STORY'S ONE GOLDEN CAUSE, pinned as an assertion on the
## `4-3b`/`5-5` precedent below rather than left as a claim in the accounting block.
##
## THE STORY'S OWN PREDICTION SAID `[]` AND THAT MEASURED FALSE, which is why this assertion exists in
## this exact shape. The Golden Prediction's cause 1 read: "the determinism fixture's summoned unit
## never dies, so the corpse container enters the snapshot EMPTY -- measure key count `+N` and contents
## `[]`". The first half holds (the unit never dies, so no corpse is ever created); the second does
## not, because `6-5b/R17` put the corpse data at the DEAD UNIT'S OWN BOARD INDEX rather than in a
## separate container. The three keys are therefore PARALLEL ARRAYS over every record, exactly like
## `unit_hp` -- so the fixture's ONE summoned unit gives each of them ONE entry, at its RESTING value.
## `[]` would only have been right for the container shape the gate ruled out.
##
## WHAT THE CAUSE ACTUALLY IS, then: the three keys' mere PRESENCE at resting values (the 3-5a
## `discard_size` / 4-1 `unit_count` shape), and nothing behavioural. This asserts that -- so a future
## story that lets this fixture KILL its unit moves the golden for a reason this accounting calls
## impossible, and fails HERE first, naming it.
func test_the_golden_fixture_reaches_the_hash_tick_with_one_resting_corpse_entry() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	for slot: String in ["p1", "p2"]:
		var player: PlayerState = ms.p1 if slot == "p1" else ms.p2
		var snapshot := player.to_snapshot()
		var records: int = int(snapshot["unit_count"])
		var resting_ticks: Array = []
		var resting_marks: Array = []
		var resting_sources: Array = []
		for _record in records:
			resting_ticks.append(0)
			resting_marks.append(false)
			resting_sources.append(UnitBoard.NO_RAISE_SOURCE)
		assert_eq(snapshot["unit_corpse_ticks"], resting_ticks,
			("%s: every corpse countdown is at REST -- one entry per record (NOT `[]`: `6-5b/R17` put "
			+ "the corpse at the dead unit's own board index, so these are parallel arrays over the "
			+ "records exactly like `unit_hp`), and no unit in this fixture ever dies") % slot)
		assert_eq(snapshot["unit_corpse_extended"], resting_marks,
			"%s: and no corpse is Grave-Ward-extended, because there is no corpse" % slot)
		assert_eq(snapshot["unit_raised_from"], resting_sources,
			"%s: and nothing was raised, so every record's raise source is the resting sentinel" % slot)
	assert_eq(int(ms.p1.to_snapshot()["unit_count"]), 1,
		"NON-VACUITY: P1's board really does hold the t22 summon, so the three assertions above are "
		+ "made against a ONE-ENTRY array rather than passing trivially on an empty one")


## Story 6-5f: THE MEASURED CONTENT OF THIS STORY'S THREE GOLDEN CAUSES, pinned as assertions on the
## `6-5b` precedent directly above rather than left as claims in the accounting block -- so a later story
## that changes WHAT the fixture carries at the hash tick fails here by name instead of only moving the
## hash and being re-baselined past.
##
## THE RESTING/VALUED SPLIT IS THE POINT. P1 resolved a card at t22 and P2 resolved nothing, so the two
## players exercise BOTH sides of every new fact in one fixture: a written record and a resting one.
func test_the_golden_fixture_carries_the_measured_content_of_this_storys_three_causes() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	var p1 := ms.p1.to_snapshot()
	var p2 := ms.p2.to_snapshot()
	# CAUSE 1 (AC 5, `6-5f/R31`): the resolution tick, the THIRD member -- and the key is still THREE
	# elements, never four, which is the half that keeps the key count unmoved on this cause.
	var record: Array = p1["last_resolved_card"]
	assert_eq(record.size(), 3,
		"P1's `last_resolved_card` is `[id, mode, tick]` -- THREE members, the key count unmoved (AC 5)")
	assert_true(int(record[2]) > 0,
		"...and the tick is a REAL tick, because the t22 Mode ① cast really resolved (got %s)" % record[2])
	assert_eq(p2["last_resolved_card"],
		["", PlayerState.NO_RESOLVED_MODE, PlayerState.NO_RESOLVED_TICK],
		"P2 resolved nothing, so all three members sit at their own resting values")
	# CAUSE 2 (AC 2): the reversal packet. The t22 cast is a SUMMON, so P1 carries a real Vanguard-class
	# record naming the board index it appended; P2 carries the masked resting packet.
	assert_eq(p1["reversal"],
		[PlayerState.REVERSAL_VANGUARD, [0] as Array[int], [] as Array[int], [] as Array[int],
			[] as Array[bool], 0.0],
		"P1's reversal packet records the t22 SUMMON at board index 0 -- the fixture exercises a "
		+ "WRITTEN packet, not only the resting one (AC 2/AC 17)")
	assert_eq(p2["reversal"], [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0],
		"P2 resolved nothing, so its packet is the masked resting value -- the RESTING-EMPTY sub-case "
		+ "of Golden Prediction cause 2, measured here rather than argued")
	# CAUSE 3 (AC 23, `6-5f/R32`): one float per record, all resting, because nothing in this fixture
	# ever dies -- the `unit_corpse_ticks` shape verbatim, asserted against a ONE-ENTRY array for P1.
	assert_eq(p1["unit_hp_at_death"], [0.0],
		"P1's single record never died, so its pre-death hp is the resting 0.0 -- one entry per record, "
		+ "NOT `[]` (it is a parallel array over the board exactly like `unit_hp`)")
	assert_eq(p2["unit_hp_at_death"], [],
		"P2 has no records at all, so the array is genuinely empty -- the other side of the same shape")


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
	# STORY 5-6 (AC 17): P1's LOG IS RE-DERIVED, NOT PATCHED TO MATCH. The t5 contact has DEFLECTED by
	# design since 1-8; this story gives that deflect a consequence (AC 9), so P1 leaves ATTACKING for
	# STUNNED at t5 instead of running its swing out. Two knock-on facts follow and both are visible
	# here rather than absorbed silently:
	#   * THE t9 CHAINED-SWING COVERAGE IS LOST. `STUNNED` replaces `ATTACKING` immediately, so
	#     `active_done` never fires, the chain window never opens, and the t9 press is DROPPED by the
	#     empty `stunned` table row. AC 17 names this as the one unconditionally lost item and accepts
	#     it (option (a)); the equivalent coverage lives in test_action_state.gd's chain-window block
	#     (last-tick accept, post-close drop, cap, roll-cancel reset), unaffected by this story.
	#   * THE t9 DROP IS ITSELF NEW COVERAGE, and it is the GAIN AC 17 names: this fixture now proves
	#     at golden level that a press against the empty `stunned` row is dropped, never buffered.
	# The t17 roll-cancel is PRESERVED (P1 is back to IDLE at t12, well before it) — note it is now a
	# roll from IDLE rather than from recovery, which the `idle -> rolling` pair below records.
	var stunned := int(HeroState.ActionState.STUNNED)
	assert_eq(p1_log, [[idle, atk], [atk, stunned], [stunned, idle], [idle, roll], [roll, idle]],
		"p1: attack, DEFLECTED into STUNNED at t5 (5-6 AC 9), timer exit to IDLE at t12 (AC 12), "
		+ "the t17 roll, roll end — and NO t9 chain, because the `stunned` row accepts nothing")
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
	# STORY 5-6 (AC 17): RE-DERIVED, and the arithmetic now encodes THREE things instead of two — the
	# spend, the regen, and the deflect PENALTY. Full derivation: t1 attack 40 -> 34, delay t1-t3,
	# regen t4 -> 35; t5 the penalty (step 4) and that tick's regen (step 5) both land, 35 - 18 + 1 =
	# 18; regen t6-t16 (11 ticks) -> 29 — UNCLAMPED throughout, which is what keeps the penalty on the
	# record; t17 roll spends 15 -> 14, delay t17-t19; regen t20-t24 -> 19.
	#
	# THE SECOND ATTACK SPEND IS GONE and that is not an omission: the t9 press is dropped by the
	# `stunned` row (see the transition pin above), so there is exactly ONE attack spend on P1's record
	# now, not two.
	#
	# THE PENALTY'S OWN MECHANISM IS PINNED BY THE t6 REGEN, not merely by the magnitude: `add(-x)`
	# does NOT restart `_regen_delay` (AC 10), so regen runs on t6. A `spend()` implementation would
	# suppress t5-t7 and land the final reading three points lower — this arithmetic is what makes
	# that a golden-level distinction.
	assert_eq(readings[5 - 1], 18.0,
		"t5: the deflect penalty (18) and that tick's regen (+1) both land — 35 -> 18 (5-6 AC 9/AC 10)")
	assert_eq(readings[6 - 1], 19.0,
		"t6: regen runs the very next tick — `add(-x)` does not restart the regen delay (AC 10); "
		+ "a `spend()` implementation would suppress t5-t7 here")
	assert_eq(post_spend, 14.0,
		"t17 roll spend: 29 - 15 (ONE attack spend preceded it — the t9 press was dropped by the "
		+ "`stunned` row, and the t5 penalty is in this number too)")
	assert_true(post_spend < maximum, "stamina dipped below maximum after the t17 roll")
	assert_true(final > post_spend, "regen visibly ran before the run ended")
	assert_true(final < maximum, "pool left MID-REGEN at t24 — below maximum")
	assert_eq(final, 19.0, "14 + 5 regen ticks (delay covers t17-t19, 1.0/tick t20-t24)")


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
	# STORY 5-6 (AC 17): THE t13 BLOCK COVERAGE IS LOST, and it is asserted as a LOSS here rather than
	# quietly deleted. This is a SECOND unconditionally lost item that AC 17's own accounting block
	# does not name (it names only the t9 chain) — reported, not smoothed over, and MEASURED rather
	# than reasoned: the t13 fact carries `attack_index` 1, which only ever existed as P1's CHAINED
	# swing. With the t9 press dropped by the `stunned` row, P1's `attack_index` never leaves 0, no
	# dedupe record for swing 1 is ever opened, and `register_swing_hit(1, ...)` returns false — so the
	# fact drops at the dedupe rung, before damage, before `hit_landed` and before the mana
	# confirmation. It is a consequence of the t9 loss, not an independent one.
	#
	# THE COVERAGE IT CARRIED IS NOT A HOLE: the ordinary-BLOCK path (facing arc, multiplier, the
	# blocked hit still confirming for mana) is covered directly and unaffected by this story in
	# test_block_deflect.gd, which owns that ladder. What this fixture still guards at golden level is
	# the DEFLECT half (t5) — asserted above — plus, now, the dedupe rung's own refusal below.
	assert_eq(hp_readings[13 - 1], 120.0,
		"t13: the fact is DROPPED at dedupe — its `attack_index` 1 names a chained swing that the t5 "
		+ "stun prevented from ever happening (5-6 AC 17, the second lost item)")
	assert_eq(mana_readings[13 - 1], 13 * PASSIVE_PER_TICK,
		"t13: a dropped fact is not a resolution — no melee mana, only the passive faucet")
	assert_eq(hp_readings[TICKS - 1], 120.0,
		"t24: P2 is UNTOUCHED on the hashed record — the deflect negated t5 and t13 never resolved")
	# Story 3-5a: the t22 cast is the FIRST mana SINK this fixture has ever had, so the final
	# reading is the accumulation MINUS the price. Story 5-6: with no melee confirmation left on P1's
	# record, that accumulation is now the passive faucet ALONE.
	assert_eq(mana_readings[TICKS - 1], TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"t24: the passive accumulation alone, LESS the t22 cast's price")
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
	# STORY 4-6, OPERATOR RULING `4-6/R7`: the neutral-stick fallback INVERTS, and this is the one
	# assertion in this file that sees it -- t17's move pair is (0, 0), so the roll takes the
	# fallback. Facing at t17 is the pushed `LOCK_DIRS[0]` = (0.6, 0.8), and the backstep is its
	# INVERSE. It was Vector3(-1, 0, 0) through 4-4, when facing was the input-derived (-1, 0)
	# carried from t16 and the fallback ran ALONG it. Both halves of the change are visible in
	# this one value, which is why it is the cause-attribution anchor in the re-baseline record
	# above rather than a line quietly edited to match.
	assert_eq(ms.p1.hero.roll_direction, Vector3(-0.6, 0, -0.8),
		"t17 roll captured via the INVERTED facing fallback (`4-6/R7`) — on the hashed record")


## Story 3-0b (AC5/AC6), the per-phase-movement analogue of the pins above: the golden only
## guards the new movement seat if the sequence actually EXERCISES it, and AC6's "authored
## for path coverage" claim is vacuous unless the lunge is shown to have run. Both are pinned
## on ticks where the arithmetic is unambiguous because the move intent is ZERO, so the
## steered term drops out and the velocity is the new term alone:
##   t5 — P1 is in swing 0's ACTIVE window (windup 1-3, active 4-7) and MOVES[4] gives P1
##        (0,0), so world_dir is zero and P1's velocity IS the lunge, along facing, at 2.0 units
##        / (7/60 s). This is the evidence that AC6 ran at all — and, paired with the t24 pin
##        below, the evidence for WHY it is a measured non-mover.
##        STORY 4-6 (AC 2): facing at t5 is the pushed `LOCK_DIRS[0]` = (0.6, 0.8), so the lunge
##        runs along THAT. It used to read (-1, 0) — the input-derived heading carried from t4,
##        because a zero intent did not update facing. The claim is unchanged and is if anything
##        sharper: the lunge tracks facing, and facing now has one owner instead of a
##        carried-over transient.
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
	# Story 5-6 (AC 17): `active_done`, not `attack_done`, and the difference is the ORPHANED SWING
	# made visible. `STUNNED` replaced `ATTACKING` at t5 while `active` was still running, so step 3's
	# ATTACKING arm never ran again and `recovery` was never started -- `attack_phase()` therefore
	# falls to `_has_run(active)` instead of `_has_run(recovery)`. The claim this line makes is
	# unchanged (P1 is carrying no live attack window at t24); the derived label for "no live window"
	# is what moved.
	assert_eq(ms.p1.hero.attack_phase(), &"active_done",
		"sanity: P1 carries no live attack window at t24 -- the t5 stun orphaned `active` and "
		+ "`recovery` was never started (5-6 AC 9)")
	var lunge_dir := Vector3(LOCK_DIRS[0].x, 0.0, LOCK_DIRS[0].y)
	assert_true(p1_vel[5 - 1].is_equal_approx(lunge_dir * lunge_speed),
		"t5: P1's ACTIVE-phase velocity is the lunge ALONE (zero move intent), along the LOCKED "
		+ "facing — AC6 genuinely ran")
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
	# Story 5-6 (AC 17): P1's melee hit is gone from this record (see the block/deflect pin), so the
	# reading is 24 passive ticks LESS the cast price. The ASYMMETRY against P2 below is what this
	# assertion is actually for and it is UNWEAKENED -- P2 still carries its own melee confirmation
	# from t20, so a faucet wrongly seated on the attacker path still shows here.
	assert_eq(p1_mana[TICKS - 1], TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"t24 (hashed): 24 passive ticks at 1.25, LESS the t22 cast price -- no melee hit survives "
		+ "on P1's record once the t9 chain is stunned away")
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
	# Story 5-6 (AC 17): the accumulation is now the PASSIVE FAUCET ALONE -- P1's one melee
	# confirmation was the t13 blocked hit, whose fact is dropped at the dedupe rung once the t5 stun
	# prevents the chained swing that fact names. The claim this line makes is unchanged (the price
	# came out of the accumulation); only the accumulation is smaller.
	assert_eq(ms.p1.mana.get_current(), TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
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
		# Story 4-6 (AC 2): the LOCK-DIRECTION channel, pushed BEFORE that tick's advance() -- the
		# runner's step-2 position, the same seat the contact facts directly above are pushed at.
		# Pushed EVERY tick rather than once at construction even though the value is constant and
		# the array persists: the fixture models the runner's behaviour, not the shortest way to
		# reach the same state.
		for slot: int in 2:
			ms.set_lock_direction(slot, LOCK_DIRS[slot])
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
## Story 5-5 (AC 16): THE SECOND MEASURED HALF OF THIS STORY'S RE-BASELINE, pinned as an assertion on
## the precedent directly below rather than left as a claim in the accounting block.
##
## The block says this story's ONE cause is the `defense` key's mere PRESENCE at its RESTING value.
## That is only true while the fixture never casts mode ③ — and the fixture builds its intents from a
## fixed MOVES table plus ONE named cast at CAST_TICK, which is mode ①/② content. If a future story
## gives this fixture a DEFENSE commit, the window WILL run, the key WILL carry a live
## `[colour, remaining_ticks]`, and the golden will move for a reason the block calls impossible —
## and this fails first, naming it.
##
## ASSERTED FOR BOTH PLAYERS, because the key is per-player and a resting claim about one of them is
## not a claim about the set the hash actually takes.
func test_the_fixture_reaches_the_hash_tick_with_no_defense_window_armed() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_false(player.defense_window.is_running,
			"the fixture never casts mode ③, so no defense window is armed at the hash tick")
		assert_eq(player.to_snapshot()["defense"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
			"...so the `defense` key hashes at its RESTING value — which is why this story's ONE "
			+ "golden cause is the key's mere PRESENCE and not a behavioural second cause")


## Story 6-1c (AC 10): THE MEASURED CLAIM BEHIND THE RE-BASELINE, PINNED -- the fixture never casts
## mode (2), so the landing window is never STARTED anywhere in the run (a start would record a
## non-zero duration; only a mode (2) cast starts one with a duration), and the new `landing` key
## hashes at its resting 0. Which is why this story's ONE golden cause is the key's mere PRESENCE.
func test_the_fixture_never_starts_a_landing_window() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_eq(int(player.landing_window.to_snapshot()["duration_ticks"]), 0,
			"the fixture never casts mode (2), so no landing window was ever started")
		assert_eq(int(player.to_snapshot()["landing"]), 0,
			"...so the `landing` key hashes at its RESTING value on the hash tick")


## Story 6-6a (AC 8): THE MEASURED CLAIM BEHIND THE RE-BASELINE, PINNED on the landing-window pin
## directly above's shape -- no hero in the fixture is ever knocked down, so the get-up iframe window is
## never STARTED (a start at the knockdown's timer exit would record a non-zero duration), and the new
## `get_up_iframe` key hashes at rest. Which is why this story's ONE golden cause is the key's PRESENCE.
func test_the_fixture_reaches_the_hash_tick_with_no_get_up_iframe_armed() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_eq(player.hero.to_snapshot()["get_up_iframe"],
			{"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false},
			"the fixture never knocks a hero down, so the `get_up_iframe` key hashes at its RESTING value")


## Story 7-9 (AC 13): THE MEASURED CLAIM BEHIND THIS STORY'S RE-BASELINE, PINNED on the get-up pin
## directly above's shape -- no hero in the fixture is ever knocked down, so the get-up iframes never close
## and the knockdown breather is never STARTED (a start on the get-up close would record a non-zero
## duration). The new `unblockable_immunity` key therefore hashes at rest, which is why this story's ONE
## golden cause is the key's PRESENCE.
func test_the_fixture_reaches_the_hash_tick_with_no_unblockable_immunity_armed() -> void:
	var ms := _make_match()
	_play_sequence(ms)
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_eq(player.hero.to_snapshot()["unblockable_immunity"],
			{"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false},
			"the fixture never knocks a hero down, so the `unblockable_immunity` key hashes at its RESTING value")


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
