extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

## Re-baselined in story 1-8 (block and deflect), ONE re-baseline with TWO deliberate
## causes, named separately (the 1-4/1-5 pattern), each sufficient on its own to move
## the hash:
##   1. EXERCISED-PATH RESOLUTION CHANGE: step 4 now implements the block/deflect
##      outcome ladder, and the pre-existing t5 fact sits on the deflect window's +1
##      grace tick (R-N2) against a front-facing blocker — it resolves as a DEFLECT
##      (P2 keeps 120 HP, P1 keeps 0 mana, P2 pays the cost at landing) where it used
##      to land as a full 12.0 hit. EMPIRICAL step-2 measurement (recorded in the Dev
##      Agent Record): with mechanics implemented and the OLD sequence otherwise
##      unchanged, the hash moved to ca3dc15e...76ff5 exactly this way — the gate's
##      corrected grace arithmetic held.
##   2. DELIBERATE SEQUENCE + AUTHORED-VALUE RESTRUCTURE: _golden_config now AUTHORS
##      the defense values (block_damage_multiplier 0.25, deflect_stamina_cost 20,
##      block_facing_arc_degrees 180), P2 gained a SECOND block span (t7-14), and a
##      second fact at t13 resolves as an ordinary BLOCK — the sequence exercises BOTH
##      outcomes by design (guarded by test_golden_sequence_exercises_block_and_deflect
##      below), and the facts widened to the four-field R-B3 shape.
## VERIFIED: SNAPSHOT SHAPE IS NOT A CAUSE — no to_snapshot() changed in 1-8; the R-N2
## grace marker is a per-tick transient (write-before-read inside advance(), see
## HeroState._deflect_closed_this_tick) and deflect-consumed state is DERIVED (dedupe
## registration + window state), exactly as the gate predicted.
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
const GOLDEN := "298c40f65d5f3191d2d7c2eacdccdd443c49fe24b0492d66e088318ed840f23f"

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
## recovery 6, chain 5, deflect 4). P1: attack t1 (swing 0: windup 1-3, active 4-7,
## recovery 8-13, chain window 8-12), chain t9 (swing 1: windup 9-11, active 12-15,
## recovery from 16), roll-cancel t17 (roll 17-21, IDLE t22). P2 (story 1-8): TWO block
## spans — press t1 held through t5 (deflect window runs t1-4, grace t5), released t6;
## press t7 held through t14 (window t7-10, grace t11), released t15.
const TICKS := 24
const P1_PRESS := {1: [&"attack"], 9: [&"attack"], 17: [&"roll"]}
const P2_PRESS := {1: [&"block"], 7: [&"block"]}
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
## t13) and resolves as an ordinary BLOCK by design.
const CONTACTS := {
	5: [[0, 1, 0, Vector2(-1, -1)]],
	13: [[0, 1, 1, Vector2(-1, 0)]],
}


## The golden's balance — constructed IN-TEST on purpose, never loaded from
## data/balance/*.tres: the golden guards determinism, not tuning, so playtest edits to
## the authored .tres must never move this hash. Tick counts (authored as ticks/60.0 so
## they are explicit): windup 3, active 4, recovery 6, chain window 5, deflect 4,
## roll iframe 2, roll duration 5, chain length 3 — test_action_state.gd's shape.
##
## Stamina values (story 1-4) are chosen for COVERAGE, not feel: the t17 roll spends 15
## (40 -> 25), the 3-tick delay suppresses exactly t17-t19 (the window advances in step 2,
## step 5 reads the result), regen (60/s = 1.0/tick) runs t20-t24 -> 30.0 at t24 — below
## max and above the post-spend value, so the hashed final snapshot encodes BOTH the spend
## and the regen (a rate fast enough to refill by t24 would hash identically to a run that
## never spent).
##
## Combat-economy values (story 1-5), same coverage-not-feel principle: damage 10% of the
## TARGET's 120 max HP = 12.0 per hit (t5 hit -> P2 at 108, non-full at t24 — no HP
## regen exists), melee_hit_mana 12.0 (t5 hit -> P1 at 12 of 90, non-zero at t24 — no
## mana sink exists in E1). attack_move_speed_multiplier is authored 0.0 (the live full-
## root shape) — empirically hash-neutral for THIS sequence, see the GOLDEN header.
func _golden_config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = MOVE_SPEED
	c.max_stamina = MAX_STAMINA
	c.stamina_regen_per_second = 60.0          # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 15.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.attack_move_speed_multiplier = 0.0
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
	assert_eq(p2_log, [[idle, blk], [blk, idle], [idle, blk], [blk, idle]],
		"p2: two block spans (story 1-8) — press t1/release t6, press t7/release t15")


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
	assert_eq(post_spend, 25.0, "t17 roll spend: 40 - 15 (delay suppresses regen that tick)")
	assert_true(post_spend < maximum, "stamina dipped below maximum after the t17 roll")
	assert_true(final > post_spend, "regen visibly ran before the run ended")
	assert_true(final < maximum, "pool left MID-REGEN at t24 — below maximum")
	assert_eq(final, 30.0, "25 + 5 regen ticks (delay covers t17-t19, 1.0/tick t20-t24)")


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
	assert_eq(p2_stamina_readings[TICKS - 1], 30.0,
		"t24: P2 MID-REGEN (20 + regen t15-t24) — the hash encodes the spend and the regen")


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
