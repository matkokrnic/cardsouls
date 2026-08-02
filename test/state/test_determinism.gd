extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

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
const GOLDEN := "96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b"

const SEED := 1337
const MAX_HP := 120.0
const MOVE_SPEED := 6.0
const MAX_STAMINA := 40.0
const MAX_MANA := 90.0

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
	c.melee_hit_mana = 12.0
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
	return c


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
	assert_eq(mana_readings[4 - 1], 0.0, "t4: P1 mana still empty (flywheel starts empty)")
	assert_eq(hp_readings[5 - 1], 120.0, "t5: DEFLECT on the grace tick — fully negated, no damage")
	assert_eq(mana_readings[5 - 1], 0.0, "t5: a deflected contact generates NO mana (R-D4)")
	assert_eq(p2_stamina_readings[5 - 1], 20.0, "t5: deflect cost 20 paid AT LANDING (40 -> 20)")
	assert_eq(hp_readings[13 - 1], 117.0, "t13: ordinary BLOCK — 12.0 chip x 0.25 = 3.0")
	assert_eq(mana_readings[13 - 1], 12.0, "t13: a blocked hit is CONFIRMED — full flat mana")
	assert_eq(hp_readings[TICKS - 1], 117.0, "t24: NON-FULL HP on record (no HP regen exists)")
	assert_eq(mana_readings[TICKS - 1], 12.0, "t24: NON-ZERO mana on record (no E1 mana sink)")
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
	assert_eq(p2_mana[19 - 1], 0.0, "t19: a dropped fact generates NO mana (1-9/R1)")
	assert_eq(p1_hp[20 - 1], 108.0, "t20: the SAME swing lands FULL damage one past the grace")
	assert_eq(p2_mana[20 - 1], 12.0, "t20: the landed hit pays full flat mana")
	assert_eq(p1_hp[TICKS - 1], 108.0, "t24: P1 non-full HP on the hashed record")
	assert_eq(p2_mana[TICKS - 1], 12.0, "t24: P2 non-zero mana on the hashed record")
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


func test_canonical_hash_ignores_key_insertion_order() -> void:
	var d1 := {"a": 1, "b": {"x": 1, "y": 2}, "v": Vector3(1, 2, 3)}
	var d2 := {"v": Vector3(1, 2, 3), "b": {"y": 2, "x": 1}, "a": 1}
	assert_eq(CanonicalHash.of(d1), CanonicalHash.of(d2), "sorted-key canonicalization is order-independent")


func _make_match() -> MatchState:
	var ms := MatchState.new(SEED, MAX_HP, MOVE_SPEED, MAX_STAMINA, MAX_MANA)
	ms.apply_balance(_golden_config())
	ms.inject_feature_flags(_golden_flags())
	ms.drain_signals()
	return ms


func _play_sequence(ms: MatchState, after_tick := Callable()) -> void:
	for t in range(1, TICKS + 1):
		var pair: Array = MOVES[(t - 1) % 6]
		var i1 := _intent(pair[0], P1_PRESS.get(t, []), [])
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
