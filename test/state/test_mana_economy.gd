extends TestCase

## Story 3-4 coverage: the mana economy and the melee->mana flywheel, now rule-driven.
## The D6 vocabulary (ResourceGenerationRule) and the pure EconomyEvaluator that reads it,
## the AC3 flag matrix through the ONE evaluator path, the AC4 passive-tick rung at step 5
## (no delay window; DEAD suppressed, BLOCKING deliberately not), the AC5 behaviour set
## (per-hit amount, clamp, attacker-source filtering, DEAD suppression) and the AC6
## CONSTRAINT C reload proof.
##
## Test balance: the test_action_state.gd action shape (windup 3, active 4, recovery 6,
## chain window 5, chain length 3 — one swing = windup t1-3, active t4-7, recovery t8-13),
## plus max_hp 100 / damage 6% (= 6.0 per hit), melee_hit_mana 8.0, max_mana 80.0 and
## mana_regen_per_second 30.0 = 0.5 PER TICK. The passive rate is chosen so every expected
## value below is an exact binary fraction — no tolerance, no drift.
##
## WHY so many assertions read as a DIFFERENCE between the two players: the passive faucet
## pays BOTH heroes every live tick, so "the attacker earned the melee amount" is only
## provable as p1 - p2 once the passive rung exists. That difference doubles as the
## attacker-source-filtering proof (AC5) — a melee grant leaking to the target would collapse
## it to zero.

const PASSIVE_PER_TICK := 0.5
const MELEE_HIT_MANA := 8.0


func _config(passive_per_second := 30.0, max_mana := 80.0) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0           # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.block_damage_multiplier = 0.25
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.max_mana = max_mana
	c.melee_hit_mana = MELEE_HIT_MANA
	c.mana_regen_per_second = passive_per_second
	return c


func _flags(mana_on := true) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = mana_on
	return f


## inject_flags=false leaves MatchState.flags null (the pre-injection headless default).
func _make_match(mana_on := true, inject_flags := true, passive_per_second := 30.0,
		max_mana := 80.0) -> MatchState:
	var ms := MatchState.new(MatchParams.new(11))
	ms.apply_balance(_config(passive_per_second, max_mana))
	if inject_flags:
		ms.inject_feature_flags(_flags(mana_on))
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed_keys: Array = [], held_keys: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _attack_and_advance_through(ms: MatchState, through_tick: int) -> void:
	_advance(ms, _intent([&"attack"]))  # tick 1
	for t in range(2, through_tick + 1):
		_advance(ms)


## ---- AC 1: the authored rule set and the evaluator that reads it ------------------------

## The shipped vocabulary, asserted field by field. This is the story's "exactly TWO rule
## instances" as an executable fact, and it pins the INDIRECTION that makes CONSTRAINT C
## possible: neither rule carries a gameplay number — each names a FIELD on a live balance
## object, and the two rules deliberately name DIFFERENT objects (per-event amounts live on
## BalanceConfig, per-tick rates on BalanceTicks, the A1 split).
func test_authored_rule_set_is_the_two_mana_faucets() -> void:
	var rules := EconomyEvaluator.authored_rules()
	assert_eq(rules.size(), 2, "exactly two authored rules ship (melee_hit + passive_tick)")
	if rules.size() != 2:
		return
	var melee: ResourceGenerationRule = rules[0]   # sorted filename order: melee_hit.tres first
	var passive: ResourceGenerationRule = rules[1]
	assert_eq(melee.source, EconomyEvaluator.SOURCE_MELEE_HIT)
	assert_eq(melee.resource, EconomyEvaluator.MANA)
	assert_eq(melee.amount_domain, ResourceGenerationRule.AmountDomain.BALANCE,
		"a per-EVENT amount reads from BalanceConfig")
	assert_eq(melee.amount_field, &"melee_hit_mana",
		"the melee rule names the SAME authored field the direct 1-5 grant used")
	assert_eq(melee.required_flag, &"melee_mana_generation",
		"AC3's flag scope is DATA on the rule, not a code branch at the call site")
	assert_eq(passive.source, EconomyEvaluator.SOURCE_PASSIVE_TICK)
	assert_eq(passive.resource, EconomyEvaluator.MANA)
	assert_eq(passive.amount_domain, ResourceGenerationRule.AmountDomain.BALANCE_TICKS,
		"a per-TICK rate reads from BalanceTicks (derived once per load, A1)")
	assert_eq(passive.amount_field, &"mana_regen_per_tick")
	assert_eq(passive.required_flag, &"", "the passive faucet is ungated — always open while alive")


## D6's promise ("a new mana source = a new .tres, no code") is only real if the rule set is
## DISCOVERED rather than listed in code. Proven by pointing the loader at a DIFFERENT
## directory and getting a different answer: data/balance/ holds a .tres, but not a rule, so
## the scan finds nothing there — which also pins the type filter (a stray .tres beside the
## rules cannot poison the set).
func test_rule_set_is_a_directory_scan_not_a_hardcoded_list() -> void:
	assert_eq(EconomyEvaluator.load_rules(EconomyEvaluator.RULES_DIR).size(), 2,
		"the authored directory yields its two rules")
	assert_eq(EconomyEvaluator.load_rules("res://data/balance/").size(), 0,
		"a directory of NON-rule .tres yields nothing — the set is the directory's content")
	assert_eq(EconomyEvaluator.load_rules("res://data/no_such_directory/").size(), 0,
		"a missing directory degrades to an empty rule set, never a crash")


func test_evaluator_sums_only_rules_matching_source_and_resource() -> void:
	var config := _config()
	var ticks := BalanceTicks.from_config(config)
	var rules := EconomyEvaluator.authored_rules()
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
		EconomyEvaluator.MANA, config, ticks, _flags()), MELEE_HIT_MANA,
		"the melee source resolves to the authored per-hit amount")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_PASSIVE_TICK,
		EconomyEvaluator.MANA, config, ticks, _flags()), PASSIVE_PER_TICK,
		"the passive source resolves to the DERIVED per-tick rate, not the per-second value")
	assert_eq(EconomyEvaluator.amount_for(rules, &"mana_accelerator",
		EconomyEvaluator.MANA, config, ticks, _flags()), 0.0,
		"an unauthored source generates nothing (the E4 totem's seat, empty until its .tres lands)")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
		&"stamina", config, ticks, _flags()), 0.0,
		"the resource must match too — the mana rules never pay another pool")


## AC 3 at the unit level: the same rules, the same call, three flag configurations.
func test_evaluator_flag_gate_opens_and_closes_the_melee_rule() -> void:
	var config := _config()
	var ticks := BalanceTicks.from_config(config)
	var rules := EconomyEvaluator.authored_rules()
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
		EconomyEvaluator.MANA, config, ticks, _flags(false)), 0.0,
		"flag OFF closes the gated rule")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
		EconomyEvaluator.MANA, config, ticks, null), 0.0,
		"no flags injected reads as CLOSED (graceful degradation, the 1-5 null behaviour)")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_PASSIVE_TICK,
		EconomyEvaluator.MANA, config, ticks, null), PASSIVE_PER_TICK,
		"an UNGATED rule is unaffected by the flags being absent")


## ---- AC 5: the flag matrix through advance() --------------------------------------------

## Flag ON, N = 2 confirmed hits (swing 0 at t5, the chained swing 1 at t13). The melee
## earning is read as p1 - p2 because the passive faucet pays both heroes identically —
## which is exactly why this assertion ALSO proves attacker-source filtering.
func test_flag_on_each_confirmed_hit_generates_the_authored_amount() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)              # active t4-7
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t5: swing 0 confirmed
	for t in range(6, 9):
		_advance(ms)                                # t6-t8
	_advance(ms, _intent([&"attack"]))              # t9: chain -> swing 1 (active t12-15)
	for t in range(10, 13):
		_advance(ms)                                # t10-t12
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t13: swing 1 confirmed
	var passive := 13 * PASSIVE_PER_TICK
	assert_eq(ms.p2.mana.get_current(), passive,
		"the TARGET earned the passive faucet and nothing else — 13 live ticks")
	assert_eq(ms.p1.mana.get_current(), 2 * MELEE_HIT_MANA + passive,
		"flag ON: 2 confirmed hits paid the authored melee_hit_mana each, on top of the passive")
	assert_eq(ms.p1.mana.get_current() - ms.p2.mana.get_current(), 2 * MELEE_HIT_MANA,
		"ONLY the attacker was paid for the hits (source filtering)")
	assert_eq(ms.p2.hero.get_hp(), 88.0, "both hits landed — the sequence is not vacuous")


## Flag OFF: the melee rule drops out and the PASSIVE rule alone produces mana — through the
## same evaluator call, not a second code path. The hit still lands and damages (graceful
## degradation), and the two heroes end EQUAL because only the passive faucet ran.
func test_flag_off_leaves_only_the_passive_rule() -> void:
	var ms := _make_match(false)
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t5: hit confirmed, melee faucet closed
	assert_eq(ms.p2.hero.get_hp(), 94.0, "flag OFF closes ONLY the faucet — the hit still damages")
	assert_eq(ms.p1.mana.get_current(), 5 * PASSIVE_PER_TICK,
		"flag OFF: the attacker earned the PASSIVE faucet only")
	assert_eq(ms.p1.mana.get_current(), ms.p2.mana.get_current(),
		"with the melee rule closed the two heroes' economies are identical")


## No flags injected reads exactly like flag OFF for the gated rule, and leaves the UNGATED
## passive rule running — the split the pre-evaluator null guard could not express.
func test_no_flags_injected_still_runs_the_ungated_passive_rule() -> void:
	var ms := _make_match(true, false)
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t5
	assert_eq(ms.p2.hero.get_hp(), 94.0, "no flags: damage still applies")
	assert_eq(ms.p1.mana.get_current(), 5 * PASSIVE_PER_TICK,
		"no flags: the gated melee rule stays closed, the ungated passive rule runs")


func test_passive_regen_clamps_at_max_mana() -> void:
	var ms := _make_match(true, true, 30.0, 2.0)    # 0.5/tick into a 2.0 cap
	for t in range(10):
		_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 2.0, "passive regen CLAMPS at max_mana, never overshoots")
	assert_eq(ms.p1.mana.get_maximum(), 2.0)
	assert_eq(ms.p2.mana.get_current(), 2.0, "both pools clamp")


## AC 4's sealed BLOCKING semantics, the deliberate asymmetry with stamina: a turtling hero
## keeps charging mana (that buildup IS the flywheel's point) while its stamina regen is
## suppressed. Both halves asserted on the same ticks so the asymmetry cannot silently
## become symmetry in either direction.
func test_blocking_hero_still_gains_passive_mana_while_stamina_is_suppressed() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(10.0, 0)                    # 50 -> 40, no delay window
	ms.drain_signals()
	for t in range(3):
		_advance(ms, _intent([&"block"], [&"block"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING, "sanity: P1 is blocking")
	assert_eq(ms.p1.mana.get_current(), 3 * PASSIVE_PER_TICK,
		"BLOCKING is NOT suppressed for mana — the flywheel charges behind the shield")
	assert_eq(ms.p1.stamina.get_current(), 40.0,
		"…while stamina regen IS suppressed by the same block (D6, story 1-4)")


## AC 5's DEAD-suppression proof, value-provable and seated on the ONE tick where a corpse
## can still reach step 5. P2 is held DEAD with 0 hp: step 5 runs with it DEAD, and step 8
## ends the round only AFTERWARDS — so this is exactly "DEAD for one tick, then the freeze".
## The living hero's gain on that same tick is the control: it proves the tick ran at all.
func test_dead_hero_gains_no_passive_mana_on_its_one_dead_tick() -> void:
	var ms := _make_match()
	_advance(ms)
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 1.0, "two live ticks of passive for both")
	assert_eq(ms.p2.mana.get_current(), 1.0)
	ms.p2.hero.take_damage(999.0)
	ms.p2.hero.set_action_state(HeroState.ActionState.DEAD)
	ms.drain_signals()
	_advance(ms)                                    # t3: P2 DEAD at step 5, round ends at step 8
	assert_eq(ms.p2.mana.get_current(), 1.0,
		"a corpse runs no economy — no passive mana on the DEAD tick (2-3/R5 doctrine)")
	assert_eq(ms.p1.mana.get_current(), 1.5,
		"the LIVING hero regenerated on that same tick — the suppression is per-hero, not global")
	_advance(ms)                                    # t4: round-over freeze
	assert_eq(ms.p1.mana.get_current(), 1.5,
		"round-over freeze halts passive regen with NO step-5 guard — step 1b returns first")


## The sealed "no delay window" decision, stated as behaviour: ManaPool.spend has no
## regen-delay counterpart, so a spend does not pause the faucet the way a stamina spend does.
func test_a_mana_spend_does_not_delay_the_next_passive_tick() -> void:
	var ms := _make_match()
	ms.p1.mana.add(5.0)
	assert_true(ms.p1.mana.spend(2.0), "spend succeeds")
	ms.drain_signals()
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 3.0 + PASSIVE_PER_TICK,
		"the very next tick regenerates — mana has NO post-spend delay window (sealed)")


## The no-refill contract as a SHAPE guard, complementing the behavioural pin in
## test_balance_config.gd. advance_regen() is a per-tick trickle and must never become a
## back door to the thing ManaPool deliberately lacks: adding refill() here — even unused —
## would put a "hand back a full bar" primitive one call site away from apply_balance().
func test_mana_pool_has_regen_but_still_no_refill() -> void:
	var pool := ManaPool.new(SignalQueue.new(), 10.0, 0.0)
	assert_true(pool.has_method("advance_regen"), "the passive mechanism exists (AC 4)")
	assert_false(pool.has_method("refill"),
		"ManaPool must NEVER gain refill() — mana starts empty and is built by the flywheel")


## ---- AC 6: CONSTRAINT C ------------------------------------------------------------------

## apply_balance() swaps the WHOLE BalanceTicks object, so anything that cached a reference
## to it keeps regenerating at the old rate forever. Value-provable: the rate changes on the
## VERY NEXT tick. The same reload also exercises the per-pool mana contract (set_maximum +
## clamp, never a refill), which is why the caps move underneath it.
##
## MUTATION PROOF: give EconomyEvaluator a static cache for the BalanceTicks it was handed
## (or have MatchState hold one) and this FAILS — the post-reload tick still pays 0.5.
func test_mid_match_reload_changes_the_very_next_tick_regen_rate() -> void:
	var ms := _make_match()
	_advance(ms)
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 1.0, "two ticks at the original 0.5/tick")
	ms.apply_balance(_config(120.0))                # 120/s -> 2.0 per tick
	ms.drain_signals()
	assert_eq(ms.p1.mana.get_current(), 1.0,
		"the reload itself pays nothing — mana is set_maximum ONLY, never refilled")
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 3.0,
		"the VERY NEXT tick regenerates at the NEW rate (nothing cached the BalanceTicks object)")
	# Same reload seam, the shrinking-cap half: current mana is re-clamped, not handed back full.
	ms.apply_balance(_config(120.0, 2.5))
	ms.drain_signals()
	assert_eq(ms.p1.mana.get_maximum(), 2.5, "the new cap is injected")
	assert_eq(ms.p1.mana.get_current(), 2.5, "current CLAMPED into the smaller bound, not refilled")


## The melee half of the same constraint: the per-hit amount is re-read from the live
## BalanceConfig, so a mid-match reload changes what the NEXT confirmed hit pays.
func test_mid_match_reload_changes_the_next_hit_mana() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t5: paid at the original 8.0
	var after_first := ms.p1.mana.get_current()
	assert_eq(after_first - ms.p2.mana.get_current(), MELEE_HIT_MANA, "first hit paid 8.0")
	var reloaded := _config()
	reloaded.melee_hit_mana = 20.0
	ms.apply_balance(reloaded)
	ms.drain_signals()
	for t in range(6, 9):
		_advance(ms)
	_advance(ms, _intent([&"attack"]))              # t9: chain
	for t in range(10, 13):
		_advance(ms)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                    # t13: swing 1 confirmed at the NEW amount
	assert_eq(ms.p1.mana.get_current() - ms.p2.mana.get_current(), MELEE_HIT_MANA + 20.0,
		"the second hit paid the RELOADED amount — the rule dereferences balance inline")


## ================================================================================================
## STORY 4-3b (AC 7, `4-3b/R4`): A CONFIRMED HIT SOURCED FROM A UNIT GENERATES NO MANA.
## ================================================================================================
##
## The `4-3a/R3` unit-TARGET precedent applied to the unit-ATTACKER side, and the mechanism is the
## same one: a unit-sourced confirmation stays OUT of the `confirmed_hits` list `_resolve_contacts`
## returns, which is the list `_generate_mana` awards per entry. There is deliberately no second
## gate inside `_generate_mana` to keep in agreement with this one.
##
## Reason it matters: otherwise SUMMONING BECOMES A MANA ENGINE -- a player who summons and walks
## away farms the flywheel with no risk -- and a BLOCKED hit still confirms, so blocking would not
## even slow it down.

func _config_4_3b() -> BalanceConfig:
	# PASSIVE regen OFF (the argument), so every mana equality below measures the MELEE faucet
	# alone -- with the file's default 30.0/s passive rate a pool drifts every tick and "no mana
	# was generated" would be unassertable.
	var c := _config(0.0)
	# A NONZERO deflect cost, which this file's own `_config` never authored (it has no deflect
	# test). Left at the 0.0 default, `can_deflect` reads `0.0 >= 0.0` -> TRUE for a hero with an
	# EMPTY stamina pool, so the blocked-hit fixture below would silently deflect instead and
	# measure nothing.
	c.deflect_stamina_cost = 8.0
	c.unit_max_hp = 9.0
	c.unit_damage_per_hit = 3.0
	c.minion_attack_windup_seconds = 2.0 / 60.0
	c.minion_attack_active_seconds = 3.0 / 60.0
	c.minion_attack_recovery_seconds = 4.0 / 60.0
	c.minion_attack_reach_distance = 2.0
	c.minion_retarget_interval_seconds = 1000.0
	return c


func _match_4_3b() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config_4_3b())
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	ms.inject_feature_flags(f)
	ms.drain_signals()
	return ms


## P1 gets one unit driven into its ACTIVE window through the real reach trigger and phase ladder.
func _p1_unit_into_active_4_3b(ms: MatchState) -> void:
	ms.p1.units.add(9.0)
	ms.p1.units.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	_advance(ms)
	for _t in 2:
		_advance(ms)


## AC 7, BOTH ATTACKER KINDS IN ONE TEST, which is the only form that discriminates: the identical
## hit from a HERO attacker still pays, and from a UNIT attacker pays nothing. A test that only
## measured the unit case would also pass against a build where mana generation was broken outright.
func test_a_unit_sourced_hit_pays_no_mana_while_the_same_hero_hit_still_does() -> void:
	# (i) the HERO control: mana moves.
	var hero_run := _make_match()
	var hero_mana_before := hero_run.p1.mana.get_current()
	_attack_and_advance_through(hero_run, 4)
	hero_run.push_contact([0, -1], [1, -1], hero_run.p1.hero.attack_index, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(hero_run)
	var hero_gain := hero_run.p1.mana.get_current() - hero_mana_before
	assert_true(hero_gain > 0.0,
		"sanity: a HERO-sourced confirmed hit still pays its owner (the melee faucet is intact)")

	# (ii) the UNIT case: the same landed damage, no mana on either side.
	var ms := _match_4_3b()
	_p1_unit_into_active_4_3b(ms)
	var p1_mana := ms.p1.mana.get_current()
	var p2_mana := ms.p2.mana.get_current()
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p2.hero.get_hp() < hp_before,
		"sanity: the unit-sourced hit really did LAND, so the two equalities below are about a "
		+ "CONFIRMED hit and not about a fact that was dropped")
	assert_eq(ms.p1.mana.get_current(), p1_mana,
		"a unit-sourced confirmation generates NO mana for its owner (AC 7) — otherwise summoning "
		+ "becomes a mana engine")
	assert_eq(ms.p2.mana.get_current(), p2_mana, "...and none for the target either")


## AC 7 against a BLOCKED hit, named because it is the case the gate reasoning calls out: a blocked
## hit STILL CONFIRMS (it is reduced, not negated), so a unit-sourced blocked hit is the one that
## would leak mana if the gate lived anywhere other than the confirmed-hits list.
func test_a_blocked_unit_sourced_hit_pays_no_mana_either() -> void:
	var ms := _match_4_3b()
	_p1_unit_into_active_4_3b(ms)
	var p1_mana := ms.p1.mana.get_current()
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	# P2 blocks WITHOUT the stamina to deflect, so the fact degrades to a blocked (still CONFIRMED)
	# hit rather than being fully negated.
	ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)
	var blocking := InputIntent.new()
	blocking.pressed[&"block"] = true
	blocking.held[&"block"] = true
	var intents: Array[InputIntent] = [InputIntent.new(), blocking]
	ms.advance(intents)
	ms.drain_signals()
	var damage := hp_before - ms.p2.hero.get_hp()
	assert_true(damage > 0.0, "sanity: a BLOCKED hit still lands reduced damage, so it CONFIRMED")
	assert_eq(ms.p1.mana.get_current(), p1_mana,
		"a BLOCKED unit-sourced hit pays no mana either — the gate is the confirmed-hits list, not "
		+ "a damage test, so 'blocked but confirmed' cannot slip through it")
