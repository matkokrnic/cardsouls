extends TestCase

## Story 3-5a (AC 3): the pure cast evaluator, tested as a pure function — no MatchState, no
## pools beyond the readings it is handed, no tick. The EconomyEvaluator unit-test shape.
##
## The property that matters most here is the one the whole D6 split rests on: it COMPUTES and
## does not APPLY. Every test below reads the pool AFTER the call and asserts it is untouched.


func test_affordable_cast_is_allowed() -> void:
	var c := _condition(3.0)
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, null, null), CastEvaluator.ALLOWED,
		"10.0 mana against a 3.0 price is allowed, and ALLOWED is the empty StringName")


func test_exact_price_is_affordable() -> void:
	var c := _condition(3.0)
	assert_eq(CastEvaluator.refusal_reason(c, 3.0, null, null), CastEvaluator.ALLOWED,
		"paying EXACTLY the price is allowed — the boundary is >, not >=")


func test_one_short_is_refused() -> void:
	var c := _condition(3.0)
	assert_eq(CastEvaluator.refusal_reason(c, 2.99, null, null),
		CastEvaluator.REASON_INSUFFICIENT_MANA, "a hair under the price is refused")


func test_free_card_is_allowed_at_zero_mana() -> void:
	assert_eq(CastEvaluator.refusal_reason(_condition(0.0), 0.0, null, null),
		CastEvaluator.ALLOWED, "a zero-priced card is castable on an empty pool")


## THE PURITY PROPERTY (AC 3). The evaluator must not spend: the pool it is handed is read and
## left alone, and the spend happens later, in advance()'s ordered dispatch, through
## ManaPool.spend(). A regression that applied here would show as a moved pool.
func test_evaluator_never_applies_the_spend() -> void:
	var queue := SignalQueue.new()
	var pool := ManaPool.new(queue, 90.0, 10.0)
	var c := _condition(3.0)
	assert_eq(CastEvaluator.refusal_reason(c, pool.get_current(), null, null),
		CastEvaluator.ALLOWED, "sanity: the verdict is ALLOWED")
	assert_eq(pool.get_current(), 10.0, "the pool is UNTOUCHED — the evaluator computes only")


## A null condition is the unknown-card default. UNREACHABLE in shipped play (the injection seam
## is total over the composition), kept as a total function's honest answer and declared NOT
## mutation-proven — this test pins the return value, not a live path.
func test_null_condition_reads_as_unknown_card() -> void:
	assert_eq(CastEvaluator.refusal_reason(null, 100.0, null, null),
		CastEvaluator.REASON_UNKNOWN_CARD, "a missing cost entry refuses rather than crashing")


# --- flag gating (the EconomyEvaluator._flag_open twin) --------------------------------------

func test_ungated_condition_is_open_without_flags() -> void:
	assert_eq(CastEvaluator.refusal_reason(_condition(1.0), 10.0, null, null),
		CastEvaluator.ALLOWED, "an empty required_flag is always open")


## Graceful degradation runs in the SHUT direction for gating: a flag that cannot be verified
## open reads as CLOSED. Matches EconomyEvaluator exactly.
func test_gated_condition_is_closed_without_flags() -> void:
	var c := _condition(1.0)
	c.required_flag = &"pitch_zone"
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, null, null),
		CastEvaluator.REASON_FLAG_CLOSED, "no injected flags -> the gate reads CLOSED")


func test_gated_condition_opens_when_its_flag_is_true() -> void:
	var c := _condition(1.0)
	c.required_flag = &"pitch_zone"
	var f := FeatureFlags.new()
	f.pitch_zone = true
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, null, f), CastEvaluator.ALLOWED,
		"the named flag being true opens the gate")


func test_unknown_flag_name_reads_as_closed() -> void:
	var c := _condition(1.0)
	c.required_flag = &"no_such_flag"
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, null, FeatureFlags.new()),
		CastEvaluator.REASON_FLAG_CLOSED, "a flag name that does not exist reads CLOSED")


## The gate is checked BEFORE the price: a closed card refuses for the reason a player can act
## on (the layer is off), not for a mana shortfall that is beside the point.
func test_flag_gate_outranks_the_price() -> void:
	var c := _condition(999.0)
	c.required_flag = &"pitch_zone"
	assert_eq(CastEvaluator.refusal_reason(c, 0.0, null, null),
		CastEvaluator.REASON_FLAG_CLOSED, "an unaffordable AND closed card reports CLOSED")


# --- orbs off -> mana-only (the project-context HARD RULE) -----------------------------------

## GRACEFUL DEGRADATION, the direction the rule names: with the orbs layer OFF an authored orb
## cost is IGNORED and the card is castable for its mana price alone. The opposite reading would
## make such a card permanently dead instead of degrading.
func test_orb_cost_is_ignored_while_the_orbs_layer_is_off() -> void:
	var c := _condition(1.0)
	c.orb_costs = {Enums.CardColor.RED: 3}
	var f := FeatureFlags.new()  # orbs defaults OFF
	assert_false(f.orbs, "sanity: the orbs layer ships OFF")
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, null, f), CastEvaluator.ALLOWED,
		"orbs off -> mana-only cast (graceful degradation)")


func test_orb_cost_bites_once_the_layer_is_on() -> void:
	var queue := SignalQueue.new()
	var orbs := OrbPool.new(queue)
	var c := _condition(1.0)
	c.orb_costs = {Enums.CardColor.RED: 3}
	var f := FeatureFlags.new()
	f.orbs = true
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, orbs, f),
		CastEvaluator.REASON_INSUFFICIENT_ORBS, "orbs on and the pool empty -> refused")
	orbs.add(Enums.CardColor.RED, 3)
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, orbs, f), CastEvaluator.ALLOWED,
		"...and allowed once the orbs are there")


## The refusal reason must be a deterministic function of the cost, not of dictionary iteration
## order — CardCastCondition's header states its orb_costs order is NEVER a contract, and a
## reason that depended on which short colour was visited first would quietly make it one.
func test_multi_colour_shortfall_refuses_deterministically() -> void:
	var queue := SignalQueue.new()
	var f := FeatureFlags.new()
	f.orbs = true
	var c := _condition(1.0)
	c.orb_costs = {Enums.CardColor.GREEN: 2, Enums.CardColor.RED: 2, Enums.CardColor.BLUE: 2}
	for _repeat in 8:
		assert_eq(CastEvaluator.refusal_reason(c, 10.0, OrbPool.new(queue), f),
			CastEvaluator.REASON_INSUFFICIENT_ORBS,
			"the same cost yields the same reason every time")


# --- story 6-2: the flag + mana entry point and the bare orb-price reading --------------------

## Story 6-2 (AC 4): `flag_and_mana_refusal_reason` answers the flag and the mana half and NOTHING about
## orbs -- an orb price the pool cannot pay, with the orbs layer ON, is still ALLOWED here, while the
## full `refusal_reason` refuses the same condition. That pair is what makes staging not orb-gated.
func test_the_flag_and_mana_entry_point_never_refuses_for_orbs() -> void:
	var orbs := OrbPool.new(SignalQueue.new())
	var c := _condition(2.0)
	c.orb_costs = {Enums.CardColor.RED: 3}
	var f := FeatureFlags.new()
	f.orbs = true
	assert_eq(CastEvaluator.refusal_reason(c, 10.0, orbs, f), CastEvaluator.REASON_INSUFFICIENT_ORBS,
		"sanity: the full evaluator refuses this condition for orbs")
	assert_eq(CastEvaluator.flag_and_mana_refusal_reason(c, 10.0, f), CastEvaluator.ALLOWED,
		"...and the flag + mana entry point allows it: orbs are not its question")


## Story 6-2 (AC 4): the entry point keeps `refusal_reason`'s FIXED ORDER for its two checks -- flag
## before price -- and both reasons in both directions.
func test_the_flag_and_mana_entry_point_refuses_flag_then_mana() -> void:
	var c := _condition(5.0)
	c.required_flag = &"pitch_zone"
	var closed := FeatureFlags.new()
	assert_eq(CastEvaluator.flag_and_mana_refusal_reason(c, 1.0, closed),
		CastEvaluator.REASON_FLAG_CLOSED, "a closed gate outranks an unaffordable price")
	var open := FeatureFlags.new()
	open.pitch_zone = true
	assert_eq(CastEvaluator.flag_and_mana_refusal_reason(c, 1.0, open),
		CastEvaluator.REASON_INSUFFICIENT_MANA, "gate open, price unaffordable: insufficient mana")
	assert_eq(CastEvaluator.flag_and_mana_refusal_reason(c, 5.0, open), CastEvaluator.ALLOWED,
		"gate open, exact price: allowed")


## Story 6-2 (AC 10): `orb_costs_affordable` is the READY reading over a bare price -- the same answers
## `_orbs_affordable` gives for a whole condition, including both graceful-degrade reads.
func test_orb_costs_affordable_reads_a_bare_price() -> void:
	var orbs := OrbPool.new(SignalQueue.new())
	var on := FeatureFlags.new()
	on.orbs = true
	var price: Dictionary = {Enums.CardColor.BLUE: 2, Enums.CardColor.GREEN: 1}
	assert_true(CastEvaluator.orb_costs_affordable({}, orbs, on), "an empty price is satisfied")
	assert_true(CastEvaluator.orb_costs_affordable(price, orbs, FeatureFlags.new()),
		"orbs layer off: any price is satisfied")
	assert_false(CastEvaluator.orb_costs_affordable(price, orbs, on), "empty pool, layer on: not")
	orbs.add(Enums.CardColor.BLUE, 2)
	assert_false(CastEvaluator.orb_costs_affordable(price, orbs, on), "one colour short: not")
	orbs.add(Enums.CardColor.GREEN, 1)
	assert_true(CastEvaluator.orb_costs_affordable(price, orbs, on), "every colour covered: satisfied")


func _condition(cost: float) -> CardCastCondition:
	var c := CardCastCondition.new()
	c.mana_cost = cost
	return c
