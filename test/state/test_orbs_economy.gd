extends TestCase

## Story 5-4: ORBS — the GRANT half of the RGB read exchange. The authored `unblockable_landing`
## rule and the pure evaluator that reads it (AC 1/AC 2), the landing seat that applies it (AC 4-7),
## the per-colour clamp and its sentinel-defaulted maximum (AC 8-11), and the round-boundary clear
## (AC 13).
##
## WHY A NEW FILE, on the `test_mana_economy.gd` sibling precedent (the story's own Open Question
## asks the dev pass to name the choice): this is an ECONOMY faucet — a rule, a flag gate, a pool
## clamp and a reset — and `test_mana_economy.gd` is the file that shape already lives in for mana.
## `test_unblockable_initiation.gd` is organised around 5-2's INITIATION chain (dispatch, spend,
## rooting, reach) and is deliberately NOT EDITED by this story: its `_flags()` helper opens
## `unblockable` alone, so every one of its landings runs with the orbs layer CLOSED and its
## assertions stay true, unmoved, as a free regression that the grant changed nothing about 5-2.
## The cost of the split is one duplicated mode-(2) fixture, which is the cheaper of the two.
##
## FIXTURE SHAPE. Every quantity is distinct from every other so an off-by-one lands on a wrong
## number rather than coinciding with a right one: grant 2 orbs per landing against a cap of 3 (so
## the FIRST landing is unclamped at 2 and the SECOND clamps 4 -> 3, and a third moves nothing),
## chargeup 4 ticks, damage 10 % of 100 hp so six landings cannot kill, stamina cost 2 out of 40 so
## the sequence never runs dry, draw delay 1 tick so the hand refills between casts.
##
## THE COLOURS ALTERNATE BY DECK INDEX, the 5-2 fixture's own device, and the cast helper SELECTS a
## hand slot by reading what was actually dealt rather than assuming the seeded shuffle's answer.
## That is what makes "RED saturated, BLUE still climbs" a claim about the per-colour clamp and not
## about which card happened to be in slot 0.

const SEED := 5454
const DECK_SIZE := 8
const HAND_SIZE := 4
const MAX_HP := 100.0
const MAX_STAMINA := 40.0
const UNBLOCKABLE_COST := 2.0
const CHARGEUP_TICKS := 4
const DRAW_DELAY_TICKS := 1
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0

const ORB_GRANT := 2
const MAX_ORBS := 3

## The planar TARGET -> ATTACKER direction the runner would compute (the 1-8 convention).
const FACT_DIR := Vector2(0.0, 1.0)


# --- AC 2: the authored rule ------------------------------------------------------------------

## The shipped orb faucet, field by field. The load-bearing half is `required_flag = &"orbs"` — the
## SAME flag `CastEvaluator._orbs_affordable` already reads on the SPEND side, which is what closes
## the `4-5` D1 flag-matrix split symmetrically instead of leaving it half-real.
##
## And the rule carries NO NUMBER, only the NAME of one: `ResourceGenerationRule` forbids a rule
## carrying its own amount (a second source of truth for tuning, immune to `apply_balance`), so the
## grant lives on BalanceConfig and the rule names its home. The per-EVENT domain is the
## `melee_hit.tres` shape, not the passive rule's per-TICK one — a landing is an event.
func test_the_authored_orb_rule_is_the_landing_grant_faucet() -> void:
	var rules := EconomyEvaluator.authored_rules()
	var found: ResourceGenerationRule = null
	for rule in rules:
		if rule.source == EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING:
			found = rule
	assert_not_null(found, "data/economy/unblockable_landing.tres is picked up by the directory scan")
	if found == null:
		return
	assert_eq(found.resource, EconomyEvaluator.ORBS,
		"the FIRST non-mana rule — `resource` finally discriminates rather than being decorative")
	assert_eq(found.amount_domain, ResourceGenerationRule.AmountDomain.BALANCE,
		"a per-EVENT amount reads from BalanceConfig, the melee rule's domain")
	assert_eq(found.amount_field, &"unblockable_orb_grant",
		"the rule NAMES its amount's home rather than carrying the number")
	assert_eq(found.required_flag, &"orbs",
		"the grant's flag gate is DATA on the rule and it is the SAME flag the spend side reads — "
		+ "the `4-5` D1 matrix closed symmetrically, not a second gate at the call site")


## D6's promise held for a SECOND time: the loader took a new rule with no code change at
## `load_rules`. Measured as the directory's own content, not as a hardcoded expectation.
func test_the_new_rule_needed_no_loader_change() -> void:
	assert_eq(EconomyEvaluator.load_rules(EconomyEvaluator.RULES_DIR).size(), 4,
		"four authored rules ship; the fourth arrived as a .tres and nothing else")


# --- AC 1 / AC 6: the evaluator answers, and the flag closes it -------------------------------

func test_the_evaluator_resolves_the_grant_and_the_flag_closes_it() -> void:
	var config := _config()
	var ticks := BalanceTicks.from_config(config)
	var rules := EconomyEvaluator.authored_rules()
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING,
		EconomyEvaluator.ORBS, config, ticks, _flags(true)), float(ORB_GRANT),
		"flag OPEN: the landing source resolves to the authored per-event grant")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING,
		EconomyEvaluator.ORBS, config, ticks, _flags(false)), 0.0,
		"flag CLOSED sums to 0.0 through the same call — no second code path")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING,
		EconomyEvaluator.ORBS, config, ticks, null), 0.0,
		"no flags injected reads as CLOSED (a faucet that cannot be verified open stays shut)")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_UNBLOCKABLE_LANDING,
		EconomyEvaluator.MANA, config, ticks, _flags(true)), 0.0,
		"the RESOURCE must match too — the orb rule never pays the mana pool")
	assert_eq(EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
		EconomyEvaluator.ORBS, config, ticks, _flags(true)), 0.0,
		"...and the melee rule never pays the orb pool: source and resource are BOTH filters")


# --- AC 4 / AC 5: the landing seat ------------------------------------------------------------

## The grant is credited to the ATTACKER, in the SPENT CARD'S OWN COLOUR, at the landing.
func test_a_landed_unblockable_grants_orbs_of_the_spent_colour() -> void:
	var ms := _make_match()
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"sanity: the hit really landed, so the grant below is about a LANDING")
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"the attacker earned the authored grant in the spent card's own colour")
	for other in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		if other != color:
			assert_eq(ms.p1.orbs.get_count(other), 0, "...and NOTHING in any other colour")
	assert_eq(ms.p2.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0},
		"the TARGET earned nothing — the payout is the attacker's alone")


## AC 4's other half, and `5-2/R2`'s cast-time exclusion getting its FIRST real consumer to be
## exclusive OF: no orb evaluation runs at the cast, so the count is still zero through the whole
## chargeup and moves on exactly the tick the window expires.
func test_no_orbs_are_granted_at_the_cast_or_during_the_chargeup() -> void:
	var ms := _make_match()
	var color := _cast_any(ms)
	assert_eq(ms.p1.orbs.get_count(color), 0, "the CAST tick grants nothing")
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(ms.p1.orbs.get_count(color), 0, "...and nor does any tick of the chargeup")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"the grant lands on the EXPIRY tick and nowhere earlier")


## A miss pays nothing — and the card and the stamina stay spent, so the boundary is real. Nothing
## in the miss path had to be written for this: the grant sits INSIDE the landed branch.
func test_a_missed_unblockable_grants_nothing() -> void:
	var ms := _make_match()
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "sanity: the hit missed")
	assert_eq(ms.p1.orbs.get_count(color), 0, "a miss is a miss — no orb")
	assert_eq(ms.p1.discard.size(), 1, "...while the card stays spent")


## AC 5's sentinel guard, driven on the only reachable route to it: a fixture that injects NO colour
## map leaves `charge_color` at `NO_TELEGRAPH_COLOR`, and a landing then grants NOTHING rather than
## crediting an invented RED. Non-vacuous because the identical sequence WITH colours injected
## grants (the test above) — the difference is the one injected fact.
func test_a_landing_with_no_telegraph_colour_grants_nothing() -> void:
	var ms := _make_match(true, false)
	assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "precondition: no colour is resident")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR,
		"a cast with no colour map leaves the sentinel in place (the 5-2 degradation direction)")
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"sanity: the hit LANDED, so this is about the colour and not about a dropped landing")
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0},
		"an unreadable colour grants NOTHING rather than crediting an invented one")


# --- AC 6 / AC 7: the closed flag -------------------------------------------------------------

## Measured BEHAVIOURALLY, not by code inspection: full damage, zero orbs, and — AC 7 — no
## `orbs_changed` event AT ALL, because a zero grant calls neither `add` nor the signal.
func test_a_closed_orbs_flag_lands_full_damage_and_grants_no_observable_event() -> void:
	var ms := _make_match(false)
	var events: Array = []
	ms.p1.orbs.orbs_changed.connect(
		func(r: int, b: int, g: int) -> void: events.append([r, b, g]))
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a closed ORBS layer closes ONLY the faucet — the hit still deals full damage")
	assert_eq(ms.p1.orbs.get_count(color), 0, "and credits zero orbs")
	assert_eq(events, [], "AC 7: a zero grant produces NO orbs_changed event at all")


## The AC 1 regression, stated as behaviour rather than as an absence: the grant path does not
## consult `CastEvaluator._orbs_affordable`. A mode-(2) cast of a card carrying an orb cost the
## player cannot possibly pay STILL casts, lands and pays out — because mode (2) never asks the
## spend-side gate anything (`5-2/R2`), and this story did not make it start.
func test_the_grant_path_never_consults_the_spend_side_orb_gate() -> void:
	var ms := _make_match(true, true, true)
	var color := _cast_any(ms)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"an unaffordable orb COST did not refuse a mode (2) cast — the spend gate is not on this path")
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"...and the landing paid out normally, with the pool still short of that authored cost")


# --- AC 8 / AC 9 / AC 10: the clamp and its sentinel -------------------------------------------

## The pre-injection pool is UNBOUNDED, not inert — `_max` rests at the `NO_MAXIMUM` sentinel and -1
## means "no bound", never "bounded at zero". This is the real behaviour
## `test_economy_and_hero.gd` and `test_cast_evaluator.gd` already depend on and which this story
## therefore had to preserve rather than repair; both are left UNEDITED.
func test_a_pre_injection_orb_pool_is_unbounded_not_inert() -> void:
	var pool := OrbPool.new(SignalQueue.new())
	assert_eq(pool.get_maximum(), OrbPool.NO_MAXIMUM, "no bound has been injected")
	pool.add(Enums.CardColor.RED, 99)
	assert_eq(pool.get_count(Enums.CardColor.RED), 99,
		"a pool with no injected bound accumulates freely — the sentinel is not a zero cap")


## AC 8: the clamp is PER COLOUR and INDEPENDENT, the floor stays at zero, and `add` SHORT-CIRCUITS
## when the clamped value equals the current one — no state write, no signal.
func test_add_clamps_each_colour_independently_and_short_circuits_on_no_change() -> void:
	var queue := SignalQueue.new()
	var pool := OrbPool.new(queue)
	var events: Array = []
	pool.orbs_changed.connect(func(r: int, b: int, g: int) -> void: events.append([r, b, g]))
	pool.set_maximum(MAX_ORBS)
	queue.drain()
	assert_eq(events, [], "injecting a bound into an EMPTY pool moves nothing and signals nothing")

	pool.add(Enums.CardColor.RED, 99)
	queue.drain()
	assert_eq(pool.get_count(Enums.CardColor.RED), MAX_ORBS, "RED clamps at the injected maximum")
	assert_eq(events.size(), 1, "...and signalled once")

	pool.add(Enums.CardColor.RED, 5)
	queue.drain()
	assert_eq(pool.get_count(Enums.CardColor.RED), MAX_ORBS, "a colour already AT the cap does not move")
	assert_eq(events.size(), 1, "...and the no-op-on-no-change short circuit emitted nothing")

	pool.add(Enums.CardColor.BLUE, 1)
	queue.drain()
	assert_eq(pool.get_count(Enums.CardColor.BLUE), 1,
		"a DIFFERENT colour is unaffected by RED's ceiling — the clamp is per colour")
	assert_eq(pool.get_count(Enums.CardColor.RED), MAX_ORBS, "...and RED did not move with it")

	pool.add(Enums.CardColor.BLUE, -99)
	queue.drain()
	assert_eq(pool.get_count(Enums.CardColor.BLUE), 0, "the floor is still 0 — a pool cannot go negative")


## AC 8: `set_maximum` re-clamps every colour's CURRENT count into a new bound and signals ONLY for
## the colours that actually moved — the `ManaPool.set_maximum -> add(0.0)` re-clamp idiom. Without
## the short circuit this would emit three events per injection into the AC 15 HUD channel.
func test_set_maximum_reclamps_current_counts_and_signals_only_what_moved() -> void:
	var queue := SignalQueue.new()
	var pool := OrbPool.new(queue)
	pool.set_maximum(10)
	pool.add(Enums.CardColor.RED, 8)
	pool.add(Enums.CardColor.BLUE, 1)
	queue.drain()
	var events: Array = []
	pool.orbs_changed.connect(func(r: int, b: int, g: int) -> void: events.append([r, b, g]))
	pool.set_maximum(2)
	queue.drain()
	assert_eq(pool.get_count(Enums.CardColor.RED), 2, "RED is re-clamped DOWN into the new bound")
	assert_eq(pool.get_count(Enums.CardColor.BLUE), 1, "BLUE was already inside it and is untouched")
	assert_eq(pool.get_count(Enums.CardColor.GREEN), 0, "GREEN was empty and stays empty")
	assert_eq(events.size(), 1,
		"exactly ONE event — the two colours that did not move emitted nothing (AC 8's whole point)")


## AC 10: injection is `set_maximum` ONLY, on every apply_balance including the first, and NEVER a
## refill. Orbs earned before a reload survive it, re-clamped; a match start is empty because the
## pool is CONSTRUCTED empty, not because injection zeroed it.
func test_balance_injection_bounds_orbs_but_never_refills_them() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.orbs.get_maximum(), MAX_ORBS, "the authored cap is injected at match start")
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0},
		"...and a match start yields EMPTY orbs, never a fresh maximum")
	ms.p1.orbs.add(Enums.CardColor.GREEN, 2)
	ms.drain_signals()
	ms.apply_balance(_config())
	ms.drain_signals()
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), 2,
		"a mid-match reload PRESERVES earned orbs — set_maximum only, never a refill and never a wipe")


# --- AC 11: the clamp under repeated real landings --------------------------------------------

## The clamp holds through the whole live path, not just at the pool: landing after landing in ONE
## colour stops at the authored maximum (grant 2 into a cap of 3: 2, then 3, then nothing), while a
## landing in ANOTHER colour still climbs from zero.
func test_repeated_landings_saturate_one_colour_while_another_still_climbs() -> void:
	var ms := _make_match()
	var first := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(first), ORB_GRANT, "landing 1: unclamped")
	_cast_color(ms, first)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(first), MAX_ORBS,
		"landing 2: 2 + 2 CLAMPS to the authored 3 rather than overshooting")
	var events: Array = []
	ms.p1.orbs.orbs_changed.connect(
		func(r: int, b: int, g: int) -> void: events.append([r, b, g]))
	_cast_color(ms, first)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(first), MAX_ORBS, "landing 3 against a saturated colour adds nothing")
	assert_eq(events, [],
		"...and signals nothing either — `add` computed the same value and short-circuited (AC 8)")
	var other := _other_color(first)
	_cast_color(ms, other)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(other), ORB_GRANT,
		"a DIFFERENT colour below its own maximum is unaffected by the first colour's ceiling")
	assert_eq(ms.p1.orbs.get_count(first), MAX_ORBS, "...and the saturated colour did not move with it")
	assert_true(ms.p2.hero.is_alive(),
		"sanity: four landings of 10 %% did not kill the target, so every landing above really ran")


# --- the kill case: a landing that both kills and grants -----------------------------------------

## No prior orb test drove a landing whose OWN damage kills the target: the freeze test below earns
## orbs from one landing and then kills P2 with a SEPARATE `take_damage` call, so "a killing landing
## still pays" was true by inspection and unproven by the suite. Reached through the fixture, not by
## poking hp directly: `_make_lethal_match` authors 100 %% damage instead of the shared 10 %%, so the
## SAME `_resolve_charge_landing` call that ends P2 is the one that pays P1's grant.
func test_a_landing_that_kills_its_target_still_pays_the_grant() -> void:
	var ms := _make_lethal_match()
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_false(ms.p2.hero.is_alive(), "the landing's own damage killed the target")
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"...and the SAME landing paid the attacker's grant in the spent card's colour")
	assert_true(ms.to_snapshot()["round_over"], "sanity: step 8 closed the round on this same tick")
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"the winner's orbs survive the round-over freeze -- `_end_round` clears nothing")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.orbs.get_count(color), 0, "...and only the debug reset ends them")


# --- AC 13: the round boundary ----------------------------------------------------------------

## The debug reset — this codebase's ONE round-boundary transition — clears orbs to zero on BOTH
## players, joining the units board / unit dedupe / projectile board / mode-(2) chargeup as a named
## exception to the reset's "NOTHING else" contract.
func test_the_debug_reset_clears_orbs_on_both_players() -> void:
	var ms := _make_match()
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	ms.p2.orbs.add(Enums.CardColor.GREEN, 1)
	ms.drain_signals()
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT, "precondition: P1 has earned orbs")
	assert_eq(ms.p2.orbs.get_count(Enums.CardColor.GREEN), 1, "precondition: P2 has orbs too")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0}, "the reset clears P1")
	assert_eq(ms.p2.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0}, "...and P2, in one seat")


## The `_end_round` NON-clear, asserted rather than left as prose. It is a SEPARATE finding from the
## reset clear above and reasons differently: clearing at the moment of death would delete the
## WINNER's freshly-earned orbs before the round-over freeze even displays them, against the
## freeze-survives-until-reset behaviour every other piece of round-crossing state already has. The
## scope's "nothing carries into the next round" is satisfied by the reset ALONE, because the reset
## IS this codebase's round boundary.
func test_orbs_survive_the_round_over_freeze_and_are_cleared_only_at_the_reset() -> void:
	var ms := _make_match()
	var color := _cast_any(ms)
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT, "precondition: the winner has earned orbs")
	ms.p2.hero.take_damage(MAX_HP)
	_advance(ms, InputIntent.new(), InputIntent.new())   # step 8 ends the round
	assert_eq(ms.p1.orbs.get_count(color), ORB_GRANT,
		"_end_round clears NOTHING — the winner's orbs are still there to be seen during the freeze")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.orbs.get_count(color), 0, "...and it is the RESET that ends them")


# --- AC 12: the negative snapshot AC ----------------------------------------------------------

## `OrbPool.to_snapshot()` is EXACTLY the three counts. The maximum is authored CONFIG, not state,
## and never enters the determinism hash — a deliberate DIVERGENCE from `ManaPool.to_snapshot()`,
## which does carry `"maximum"` because mana's bound is itself reloadable content a replay must
## reproduce. Asserted as an exact dictionary so an ADDED key fails here, not only in the golden.
func test_the_orb_snapshot_is_exactly_the_three_counts() -> void:
	var pool := OrbPool.new(SignalQueue.new())
	pool.set_maximum(MAX_ORBS)
	pool.add(Enums.CardColor.BLUE, 1)
	assert_eq(pool.to_snapshot(), {"red": 0, "blue": 1, "green": 0},
		"exactly {red, blue, green} — the authored maximum is CONFIG and stays out of the hash")


# --- helpers ----------------------------------------------------------------------------------

func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("orb_card_%02d" % i))
	return out


## `unaffordable_orbs` authors an orb cost NO player can pay, for the AC 1 spend-side regression.
## Mode (2) never consults `CastEvaluator`, so it must be inert on this path — which is the claim.
func _costs(unaffordable_orbs := false) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 0.0
		if unaffordable_orbs:
			c.orb_costs = {Enums.CardColor.RED: 99, Enums.CardColor.BLUE: 99}
		out[id] = c
	return out


## Colours ALTERNATE by deck index (the 5-2 fixture's device), so a four-card hand dealt off an
## eight-card deck spans both and `_cast_color` can pick a real card of a named colour instead of
## the test depending on what the seeded shuffle happened to do.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	var ids := _deck_contents()
	for i in ids.size():
		out[ids[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 1.0 / TimingWindow.TICK_HZ
	c.roll_stamina_cost = 5.0
	c.attack_stamina_cost = 5.0
	c.deflect_stamina_cost = 5.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.1
	c.attack_recovery_seconds = 0.2
	c.roll_duration_seconds = 0.5
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = 10.0
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	return c


## Only the two bits under test are parameterised; everything else stays at the resource's own
## defaults, so this fixture never silently turns another layer on.
func _flags(orbs_open: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = true
	f.orbs = orbs_open
	return f


## `inject_colors=false` reproduces the fixture 5-2 named as the ONLY route to the
## `NO_TELEGRAPH_COLOR` sentinel — no colour map injected at all.
func _make_match(orbs_open := true, inject_colors := true,
		unaffordable_orbs := false) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags(orbs_open))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs(unaffordable_orbs))
	if inject_colors:
		ms.inject_card_colors(_colors())
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	return ms


## The kill-case fixture: `_config()` verbatim except the damage percent, so ONE landing finishes a
## target already at full HP instead of needing ten landings to exhaust it -- a duplicated fixture
## rather than a `_make_match` parameter, the same cost the story's own Dev Notes already accepted
## for the mode-(2) fixture split.
func _lethal_config() -> BalanceConfig:
	var c := _config()
	c.unblockable_damage_percent_of_max_hp = 100.0
	return c


func _make_lethal_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_lethal_config())
	ms.inject_feature_flags(_flags(true))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	return ms


func _unblockable_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


## The runner's every-tick charge-reach push, by hand and through the real seam.
func _push_reach(ms: MatchState, slot: int, kind: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, FACT_DIR, kind)


## Run P1's armed chargeup out, pushing `kind` on every tick of it.
func _run_chargeup(ms: MatchState, kind: int) -> void:
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0, kind)
		_advance(ms, InputIntent.new(), InputIntent.new())


## Cast P1's hand slot 0 in mode (2) and return the colour that became resident — READ off the
## state rather than assumed, so no assertion depends on the seeded shuffle's answer.
func _cast_any(ms: MatchState) -> Enums.CardColor:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	return ms.p1.charge_color as Enums.CardColor


## Cast whichever hand slot currently holds a card of `color`, and fail loudly if the hand holds
## none — a helper that silently cast the wrong colour would make the clamp claims vacuous.
func _cast_color(ms: MatchState, color: Enums.CardColor) -> void:
	var map := _colors()
	var hand := ms.p1.hand.to_array()
	for i in hand.size():
		if hand[i] != Hand.EMPTY and map.get(hand[i], -1) == color:
			_advance(ms, _unblockable_intent(i), InputIntent.new())
			assert_eq(ms.p1.charge_color, int(color),
				"the cast card's colour became resident (the fixture cast what it meant to)")
			return
	assert_true(false, "no card of colour %s is in hand — the fixture cannot make its claim" % color)


func _other_color(color: Enums.CardColor) -> Enums.CardColor:
	return Enums.CardColor.BLUE if color == Enums.CardColor.RED else Enums.CardColor.RED


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
