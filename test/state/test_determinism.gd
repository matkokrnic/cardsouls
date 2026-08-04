extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

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
const GOLDEN := "c4b9f897138a2b36dbce11f939b2892379919909c17df1696cde24a75c070e2e"

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
func _golden_flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
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
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "the fill ran: P1 holds hand_size cards at t24")
	assert_eq(ms.p2.hand.size(), HAND_SIZE, "...and so does P2 — the deal is per-player")
	# Story 3-5a: P2 is now the untouched player and keeps the original AC 9 counts; P1 has drawn
	# ONE replacement for its t22 cast. Asserting them separately is what keeps this pin about the
	# DEAL — a regression in the deal shows on both players, a cast bug on only one.
	assert_eq(ms.p2.deck.size(), DECK_SIZE - HAND_SIZE,
		"P2 cast nothing: deck remaining is deck_size - hand_size (AC 9) — no reshuffle")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE - 1,
		"P1 drew ONE replacement for its t22 cast")
	var injected := _golden_deck()
	var p1_pile := ms.p1.deck.to_array()
	var p2_pile := ms.p2.deck.to_array()
	assert_ne(p1_pile, injected.slice(0, DECK_SIZE - HAND_SIZE),
		"the SHUFFLE ran: the pile is not the injected order (a no-op shuffle is the failure mode)")
	assert_ne(p1_pile, p2_pile,
		"P1 and P2 drew DIFFERENT orders from the one seeded generator (the ONE-SEAT ordering)")
	var p1_all := p1_pile.duplicate()
	p1_all.append_array(ms.p1.hand.to_array())
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
	assert_eq(ms.p1.hand.size(), HAND_SIZE,
		"INSTANT refill: the hand is back to full, which is why hand_size does not move the hash")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE - 1,
		"the replacement came off the deck — one below the no-cast count (cause 2)")
	assert_eq(ms.p1.mana.get_current(), 12.0 + TICKS * PASSIVE_PER_TICK - CAST_MANA_COST,
		"the PRICE was paid out of the accumulation (cause 3)")
	var all: Array[StringName] = []
	all.append_array(ms.p1.deck.to_array())
	all.append_array(ms.p1.hand.to_array())
	all.append_array(ms.p1.discard.to_array())
	all.sort()
	var expected := _golden_deck()
	expected.sort()
	assert_eq(all, expected,
		"deck + hand + discard is a PERMUTATION of the injected composition — nothing invented")


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
	assert_eq(a.p1.deck.size(), DECK_SIZE - HAND_SIZE - 1,
		"sanity: the deck really is populated (less P1's one t22 cast replacement)")
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
	ms.drain_signals()
	return ms


## `cast` exists ONLY so test_the_recorded_cast_consumes_no_rng can run the identical sequence
## with the cast suppressed. Every hashed path uses the default.
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
			ms.push_contact(fact[0], fact[1], fact[2], fact[3])
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
