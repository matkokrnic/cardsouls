extends TestCase

## Story 4-4 coverage: THE TWO ACCELERATOR TOTEMS (AC 20, AC 21, `4-4/R11`, `4-4/R13`), EXTENDED BY
## STORY 5-1 to the STACKED case (`R-M9`, `E5-P/R3`, `5-1/R1`).
##
## WHAT STORY 5-1 ADDS. That a player's accelerator count `N` is per-owner and per-kind at N>1 and
## not merely at N=1; that the mana seat pays N times the authored amount on ONE cadence tick; that
## the stamina seat applies `1 + N x step` and never `mult^N`; that N=1 is byte-identical to what
## 4-4 shipped, so the first totem moves no balance; and that killing one of two totems returns the
## effect to its N=1 value rather than to zero — the case a return-to-zero test cannot catch.
##
## WHAT THIS FILE OWNS. That a live Mana Accelerator is a resource-generation source recognised by
## the existing `ResourceGenerationRule` / `EconomyEvaluator` seam and pays out on its authored
## cadence (AC 20); that a live Stamina Accelerator raises its OWNER's hero regen by the authored
## factor and ONLY its owner's (AC 21, `4-4/R11`); and that both effects begin when the totem is
## summoned and END when it dies, with nothing left behind.
##
## THE OWNER-ONLY CLAIM IS TESTED IN BOTH DIRECTIONS, which is the whole of `4-4/R11`: it is not
## enough that the owner is accelerated — the opponent must be measured NOT to be, in the same run,
## from the same tick. A single-player assertion would pass against an implementation that
## accelerated everyone.
##
## BOTH EFFECTS ARE TESTED AS "WHILE ALIVE", NOT "ONCE SUMMONED". The ACs say "while a ... totem is
## alive", so each test kills the totem and measures the return to the non-accelerated value. An
## implementation that derived the effect once at summon time — or once at `apply_balance()`, which
## is the mechanism `4-4/R11` left open and this pass rejected — passes the first half and fails
## the second.
##
## Test balance is constructed IN-TEST (`BC/R3`), but the RULE SET is not and cannot be: authored
## `data/economy/*.tres` content is load-bearing for the mana path by `3-4/R6`'s narrowing, and the
## evaluator scans that directory. So the accelerator amount is exercised through the SHIPPED rule
## against an in-test BalanceConfig field, which is exactly the indirection the rule schema exists
## to provide.

const HERO_MAX_HP := 100.0
const MAX_MANA := 100.0
const MAX_STAMINA := 100.0

## Chosen so every expected value below is an exact binary fraction and no two quantities coincide:
## a 4-tick cadence paying 5.0, against a passive faucet paying 0.5 per tick.
const ACCELERATOR_MANA := 5.0
const ACCELERATOR_INTERVAL_TICKS := 4
const PASSIVE_PER_SECOND := 30.0        # 0.5 per tick at 60 Hz
const STAMINA_PER_SECOND := 60.0        # 1.0 per tick at 60 Hz
## Story 5-1 (AC 7, `5-1/R1`): the stamina seat is `1 + N x step` now, so the fixture authors a STEP
## rather than a factor and every expectation below is re-derived through `_stamina_factor()` rather
## than carried over. 1.5 is chosen so the N=1 factor is 2.5 — the same number the old multiplicative
## fixture used, which keeps the N=1 assertions numerically identical and makes the "one totem does
## not move balance" claim visible right here — while every stacked value stays distinguishable from
## the readings a broken implementation would produce:
##   N=1 -> 2.5   N=2 -> 4.0   N=3 -> 5.5
## against `mult^N`'s 6.25 / 15.625 at N=2/N=3 and against a double-application's 5.0 at N=2. No two
## of those coincide, so an assertion here cannot pass for the wrong reason.
const STAMINA_STEP := 1.5

const KIND_MINION := 0
const KIND_MANA := 1
const KIND_STAMINA := 2


## Story 5-1 (AC 7): the stamina factor as the seat derives it, expressed ONCE here so no assertion
## below re-types the arithmetic it is supposed to be checking.
func _stamina_factor(accelerators: int) -> float:
	return 1.0 + float(accelerators) * STAMINA_STEP


## `author_step == false` leaves `stamina_accelerator_regen_step` UNASSIGNED at its class default —
## the `4-4` M2 shape (story 5-1, AC 9): a config that never sets the field at all.
func _config(author_step := true) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = HERO_MAX_HP
	c.move_speed = 5.0
	c.max_stamina = MAX_STAMINA
	c.stamina_regen_per_second = STAMINA_PER_SECOND
	c.stamina_regen_delay_seconds = 0.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.max_mana = MAX_MANA
	c.melee_hit_mana = 1.0
	c.mana_regen_per_second = PASSIVE_PER_SECOND
	c.block_damage_multiplier = 0.5
	c.block_facing_arc_degrees = 180.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 1.0
	c.minion_retarget_interval_seconds = 1000.0
	c.hero_damage_to_unit = 3.0
	c.mana_accelerator_mana = ACCELERATOR_MANA
	c.mana_accelerator_interval_seconds = float(ACCELERATOR_INTERVAL_TICKS) / 60.0
	if author_step:
		c.stamina_accelerator_regen_step = STAMINA_STEP
	# THE KIND NAMES ARE THE RESOLVER'S OWN CONSTANTS, never string literals: the accelerator seats
	# look kinds up BY NAME, so a fixture that spelled one differently would silently test a totem
	# no seat can find and every assertion here would pass for the wrong reason.
	c.unit_kinds = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, 9.0, 3.0, 2, 3, 4, 2.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_MANA_ACCELERATOR, 12.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_STAMINA_ACCELERATOR, 12.0),
	]
	return c


func _flags(totems_open := true) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	f.totems = totems_open
	return f


func _make_match(totems_open := true, author_step := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(17))
	ms.apply_balance(_config(author_step))
	ms.inject_feature_flags(_flags(totems_open))
	ms.drain_signals()
	return ms


func _advance(ms: MatchState, ticks := 1) -> void:
	for _t in ticks:
		var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()


## Advance to the tick BEFORE the next accelerator cadence boundary, so a test can measure one
## payout in isolation rather than however many the run happened to cross. Returns the mana each
## player holds at that point.
func _drain_to_boundary_eve(ms: MatchState) -> void:
	while (ms.to_snapshot()["tick"] + 1) % ACCELERATOR_INTERVAL_TICKS != 0:
		_advance(ms)


# ---- AC 20: the Mana Accelerator ---------------------------------------------------------------

func test_the_authored_rule_is_reachable_only_through_the_third_call_site() -> void:
	# The B8 correction as an executable fact: the rule has been LOADABLE since 3-4, and what this
	# story adds is the asking. With no accelerator on the board the evaluator still resolves the
	# rule to a real amount — so the rule is not the gate, the call site's liveness test is.
	var ms := _make_match()
	var amount := EconomyEvaluator.amount_for(EconomyEvaluator.authored_rules(),
			EconomyEvaluator.SOURCE_MANA_ACCELERATOR, EconomyEvaluator.MANA, ms.balance,
			ms.balance_ticks, ms.flags)
	assert_eq(amount, ACCELERATOR_MANA,
		"the authored rule dereferences `mana_accelerator_mana` off the LIVE balance object — the "
		+ "rule carries no number of its own")
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 3)
	assert_eq(ms.p1.mana.get_current(), 0.5 * ACCELERATOR_INTERVAL_TICKS * 3,
		"...but with NO accelerator on the board only the PASSIVE faucet has paid: the rule being "
		+ "resolvable is not the same as it being applied")


func test_a_live_accelerator_pays_its_authored_amount_on_its_authored_cadence() -> void:
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	_drain_to_boundary_eve(ms)
	var before := ms.p1.mana.get_current()
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), before + ACCELERATOR_MANA + 0.5,
		"on a cadence boundary the owner gains the authored accelerator amount ON TOP of the "
		+ "passive tick — two faucets, both open, neither replacing the other")
	var after_boundary := ms.p1.mana.get_current()
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), after_boundary + 0.5,
		"the very next tick is NOT a boundary, so only the passive faucet pays — which is what "
		+ "makes this a CADENCE rather than a per-tick rate")


func test_the_accelerator_is_owner_only() -> void:
	# AC 20 does not say "owner-only" in as many words, but the faucet is per-player by construction
	# and the opposing half must be measured or an implementation that paid BOTH players would pass
	# every other test in this file.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 2)
	assert_true(ms.p1.mana.get_current() > ms.p2.mana.get_current(),
		"the OWNER is ahead of the opponent")
	assert_eq(ms.p2.mana.get_current(), 0.5 * ACCELERATOR_INTERVAL_TICKS * 2,
		"...and the opponent has earned the PASSIVE faucet alone — the accelerator is read off the "
		+ "board of the player being paid, so there is no cross-player path to get wrong")


func test_the_faucet_closes_when_the_accelerator_dies() -> void:
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	_advance(ms, ACCELERATOR_INTERVAL_TICKS)
	var while_alive := ms.p1.mana.get_current()
	assert_true(while_alive > 0.5 * ACCELERATOR_INTERVAL_TICKS,
		"sanity: the accelerator paid while it was alive")
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the totem is dead")
	var before := ms.p1.mana.get_current()
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 2)
	assert_eq(ms.p1.mana.get_current(), before + 0.5 * ACCELERATOR_INTERVAL_TICKS * 2,
		"AC 20's 'WHILE a totem is alive': a dead accelerator pays nothing, and the passive faucet "
		+ "alone accounts for every point earned after it died")


func test_a_minion_is_not_an_accelerator() -> void:
	# The kind lookup is what gates the faucet, so a unit of a DIFFERENT kind must not open it —
	# otherwise "totem" would mean "any unit" and the whole per-kind conversion would decide nothing
	# here.
	var ms := _make_match()
	ms.p1.units.add(9.0, KIND_MINION)
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 2)
	assert_eq(ms.p1.mana.get_current(), 0.5 * ACCELERATOR_INTERVAL_TICKS * 2,
		"a MINION on the board opens no accelerator faucet")


func test_a_closed_totems_flag_shuts_the_faucet() -> void:
	# The project-context HARD RULE, and it is satisfied as DATA on the rule (`required_flag`)
	# rather than as a check at the call site — so both flag configurations run the same evaluator
	# call and a closed flag simply resolves to 0.0.
	var ms := _make_match(false)
	ms.p1.units.add(12.0, KIND_MANA)
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 2)
	assert_eq(ms.p1.mana.get_current(), 0.5 * ACCELERATOR_INTERVAL_TICKS * 2,
		"with `totems` closed the accelerator rule resolves to 0.0 and only the passive faucet pays")


func test_a_dead_owner_earns_nothing_from_its_accelerator() -> void:
	# The standing `2-3/R5` doctrine — a corpse runs no economy — inherited rather than re-stated,
	# because the rung routes through `_regen_mana` instead of calling `mana.add()` directly.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	var before := ms.p1.mana.get_current()
	_advance(ms, ACCELERATOR_INTERVAL_TICKS * 2)
	assert_eq(ms.p1.mana.get_current(), before,
		"a DEAD owner earns nothing from its own accelerator — the rung routes through the same "
		+ "suppression the passive faucet uses, so there is no second doctrine to keep in agreement")


# ---- AC 21 / `4-4/R11`: the Stamina Accelerator -------------------------------------------------

func test_a_live_stamina_accelerator_raises_only_its_owners_regen() -> void:
	var ms := _make_match()
	# Both heroes spend the same stamina, so the two regen rates are compared from one starting
	# point and the difference cannot come from anywhere else.
	ms.p1.stamina.spend(50.0, 0)
	ms.p2.stamina.spend(50.0, 0)
	ms.drain_signals()
	var p1_before := ms.p1.stamina.get_current()
	var p2_before := ms.p2.stamina.get_current()
	assert_eq(p1_before, p2_before, "sanity: both heroes start this measurement level")
	ms.p1.units.add(12.0, KIND_STAMINA)
	_advance(ms, 10)
	assert_eq(ms.p1.stamina.get_current(), p1_before + 1.0 * _stamina_factor(1) * 10.0,
		"AC 21 / story 5-1 AC 7: the OWNER's regen is the non-accelerated rate times `1 + N x step` "
		+ "at N=1 — RE-DERIVED through the new formula, not carried over from the multiplicative "
		+ "fixture; that it lands on the same number is `5-1/R1`'s point (one totem must not move "
		+ "balance), not a coincidence left unchecked")
	assert_eq(ms.p2.stamina.get_current(), p2_before + 1.0 * 10.0,
		"`4-4/R11`: the OPPONENT's regen is UNTOUCHED — owner-only, and this is the half a "
		+ "single-player assertion would miss")


func test_the_owners_regen_returns_to_normal_when_the_accelerator_dies() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(60.0, 0)
	ms.drain_signals()
	ms.p1.units.add(12.0, KIND_STAMINA)
	_advance(ms, 5)
	var accelerated := ms.p1.stamina.get_current()
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the totem is dead")
	_advance(ms, 5)
	assert_eq(ms.p1.stamina.get_current(), accelerated + 1.0 * 5.0,
		"AC 21's 'RETURNS to the non-accelerated value once that totem is no longer alive' — and "
		+ "measuring the RETURN is what rejects deriving the factor once at summon or reload time")


func test_the_accelerator_does_not_reopen_a_suppressed_regen() -> void:
	# The factor scales the AMOUNT; it must not become a second way past the D6 suppression. A
	# BLOCKING hero regenerates nothing, accelerated or not — otherwise holding block beside a totem
	# would be free, and P2 ("aggression is economy") would be unenforced for exactly one build.
	var ms := _make_match()
	ms.p1.stamina.spend(50.0, 0)
	ms.drain_signals()
	ms.p1.units.add(12.0, KIND_STAMINA)
	var before := ms.p1.stamina.get_current()
	for _t in 5:
		var block := InputIntent.new()
		block.pressed[&"block"] = true
		block.held[&"block"] = true
		var intents: Array[InputIntent] = [block, InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING, "sanity: still blocking")
	assert_eq(ms.p1.stamina.get_current(), before,
		"a BLOCKING owner regenerates NOTHING even beside a live accelerator — the factor scales "
		+ "the amount, it does not bypass the suppression")


func test_a_dead_accelerator_owner_regenerates_nothing() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(50.0, 0)
	ms.drain_signals()
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	var before := ms.p1.stamina.get_current()
	_advance(ms, 5)
	assert_eq(ms.p1.stamina.get_current(), before,
		"a corpse runs no economy, accelerated or not (`2-3/R5`, inherited)")


# ---- The shared liveness predicate --------------------------------------------------------------

func test_has_live_kind_answers_both_directions_and_degrades_on_an_unknown_name() -> void:
	# The one expression of "this totem is currently doing its job", tested in BOTH directions so
	# neither accelerator test above can be passing against a predicate that always answers true.
	var ms := _make_match()
	assert_false(ms.has_live_kind(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR),
		"an empty board carries no live accelerator")
	ms.p1.units.add(12.0, KIND_MANA)
	assert_true(ms.has_live_kind(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR),
		"...and a summoned one is found")
	assert_false(ms.has_live_kind(ms.p2, CardEffectResolver.KIND_MANA_ACCELERATOR),
		"...on its OWNER's board only")
	assert_false(ms.has_live_kind(ms.p1, CardEffectResolver.KIND_STAMINA_ACCELERATOR),
		"...and it is not mistaken for a DIFFERENT kind")
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.has_live_kind(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR),
		"a dead totem is not live — liveness is the board's own predicate, never a re-derived hp>0")
	assert_false(ms.has_live_kind(ms.p1, &"no_such_kind"),
		"an unauthored kind name answers FALSE rather than tripping a guard — the faucet is simply "
		+ "shut, which is the graceful-degradation direction")


# ---- Story 5-1 (AC 1-AC 3): the count the two seats now multiply by ------------------------------

func test_live_kind_count_counts_per_owner_and_per_kind_and_degrades_on_an_unknown_name() -> void:
	# `has_live_kind`'s test above, widened to the answer this story actually consumes. Everything it
	# pins is pinned here at N>1, because a count is where "is there one" stops being enough.
	var ms := _make_match()
	assert_eq(ms.live_kind_count(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR), 0,
		"an empty board counts zero")
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(9.0, KIND_MINION)
	ms.p2.units.add(12.0, KIND_MANA)
	assert_eq(ms.live_kind_count(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR), 2,
		"AC 1: two live mana accelerators on the owner's own board count TWO")
	assert_eq(ms.live_kind_count(ms.p1, CardEffectResolver.KIND_STAMINA_ACCELERATOR), 1,
		"AC 3: PER-KIND — the stamina totem beside them enters the mana count not at all, and its "
		+ "own count is its own")
	assert_eq(ms.live_kind_count(ms.p2, CardEffectResolver.KIND_MANA_ACCELERATOR), 1,
		"AC 2: PER-OWNER — the opponent counts only their OWN board, never the owner's two")
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: one of the two is dead")
	assert_eq(ms.live_kind_count(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR), 1,
		"a dead totem leaves the count — and the count drops to ONE, not to zero: liveness is the "
		+ "board's own predicate applied per index, never a whole-board bool")
	assert_eq(ms.live_kind_count(ms.p1, &"no_such_kind"), 0,
		"AC 1 (`5-1/R5`): an unauthored kind name counts ZERO at the kind lookup, before the board "
		+ "is scanned — `has_live_kind`'s degradation, widened rather than replaced")
	assert_false(ms.has_live_kind(ms.p1, &"no_such_kind"),
		"...and the bool still agrees with it, because it IS it: one scan, two spellings")


# ---- Story 5-1 (AC 5): the mana seat stacks linearly --------------------------------------------

## The accelerator's share of one cadence-boundary tick, with the passive faucet's 0.5 removed — so
## every stacking assertion below is about the accelerator alone rather than about a sum.
func _accelerator_payout_on_next_boundary(ms: MatchState) -> float:
	_drain_to_boundary_eve(ms)
	var before := ms.p1.mana.get_current()
	_advance(ms)
	return ms.p1.mana.get_current() - before - 0.5


func test_two_mana_accelerators_pay_twice_on_the_same_cadence_tick() -> void:
	# `R-M9` Reading A (`E5-P/R3`): each totem pays its OWN grant per cadence tick. The measurement
	# is one tick, not a window, because Reading B (a compounding CADENCE) would also make the owner
	# richer over time — only a single-tick payout tells the two readings apart.
	var one := _make_match()
	one.p1.units.add(12.0, KIND_MANA)
	assert_eq(_accelerator_payout_on_next_boundary(one), ACCELERATOR_MANA,
		"N=1 pays the authored amount exactly ONCE — byte-identical to what 4-4 shipped, which is "
		+ "the case this story promised not to move")
	var two := _make_match()
	two.p1.units.add(12.0, KIND_MANA)
	two.p1.units.add(12.0, KIND_MANA)
	assert_eq(_accelerator_payout_on_next_boundary(two), 2.0 * ACCELERATOR_MANA,
		"AC 5: N=2 pays exactly TWICE the one-totem amount on the SAME cadence tick — the second "
		+ "copy no longer does nothing (`4-4` M9), and it pays linearly rather than compounding")


func test_three_mana_accelerators_pay_three_times() -> void:
	# N=3 is not N=2 restated: a doubling could be produced by a bug that applies the payout twice
	# regardless of count, and that bug pays 2x at N=3 as well.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_MANA)
	assert_eq(_accelerator_payout_on_next_boundary(ms), 3.0 * ACCELERATOR_MANA,
		"AC 5: N=3 pays exactly THREE times, with no upper bound coded anywhere (AC 4's non-goal)")


func test_the_stacked_mana_faucet_is_owner_only() -> void:
	# AC 2's both-directions discipline at N>1: it is not enough that the owner's two totems pay
	# twice — the opponent's ONE must still pay once, from the same tick of the same run.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p2.units.add(12.0, KIND_MANA)
	_drain_to_boundary_eve(ms)
	var p1_before := ms.p1.mana.get_current()
	var p2_before := ms.p2.mana.get_current()
	_advance(ms)
	assert_eq(ms.p1.mana.get_current() - p1_before, 2.0 * ACCELERATOR_MANA + 0.5,
		"the owner's TWO pay twice")
	assert_eq(ms.p2.mana.get_current() - p2_before, ACCELERATOR_MANA + 0.5,
		"AC 2: the opponent's own count is ONE and pays once — the owner summoning a second totem "
		+ "did not raise the opponent's payout, which is the half a one-sided assertion would miss")


func test_killing_one_of_two_mana_accelerators_returns_the_payout_to_the_n1_amount() -> void:
	# The stacking analogue of `test_the_faucet_closes_when_the_accelerator_dies`, and the case that
	# test cannot reach: an implementation that dropped to ZERO the moment ANY totem died would pass
	# every "the faucet closes" assertion in this file.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_MANA)
	assert_eq(_accelerator_payout_on_next_boundary(ms), 2.0 * ACCELERATOR_MANA,
		"sanity: both are alive and paying")
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: one of the two is dead")
	assert_eq(_accelerator_payout_on_next_boundary(ms), ACCELERATOR_MANA,
		"AC 12: the payout returns to the N=1 amount — NOT to zero, and not stuck at the N=2 amount "
		+ "the count had when the pair was summoned")


func test_a_second_totem_of_another_kind_does_not_raise_the_mana_payout() -> void:
	# AC 3 at the seat rather than at the predicate: the count the mana rung multiplies by must be
	# the MANA count, so a stamina accelerator and a minion beside it change nothing here.
	var ms := _make_match()
	ms.p1.units.add(12.0, KIND_MANA)
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(9.0, KIND_MINION)
	assert_eq(_accelerator_payout_on_next_boundary(ms), ACCELERATOR_MANA,
		"a stamina accelerator and a minion enter the MANA count not at all — N is per-kind")


# ---- Story 5-1 (AC 7, `5-1/R1`): the stamina seat is linear, not `mult^N` -----------------------

## Stamina gained over `ticks` ticks by a player carrying `accelerators` live stamina totems, from a
## common spend-down point. Returned rather than asserted so each test states its own expectation.
func _stamina_gain_with(accelerators: int, ticks: int) -> float:
	var ms := _make_match()
	ms.p1.stamina.spend(60.0, 0)
	ms.drain_signals()
	for _i in accelerators:
		ms.p1.units.add(12.0, KIND_STAMINA)
	var before := ms.p1.stamina.get_current()
	_advance(ms, ticks)
	return ms.p1.stamina.get_current() - before


func test_two_stamina_accelerators_apply_the_linear_factor_not_the_square() -> void:
	# `5-1/R1` in one assertion: the number this seat must NOT produce is named in the message,
	# because "greater than one totem" is satisfied by the exponential reading too.
	var gain := _stamina_gain_with(2, 10)
	assert_eq(gain, 1.0 * _stamina_factor(2) * 10.0,
		("AC 7: N=2 gives `1 + 2 x step` = %.2f, LINEAR. Not `mult^2` = %.2f (the explosive reading "
		+ "`5-1/R1` rejects) and not a doubling of the N=1 factor = %.2f")
				% [_stamina_factor(2), _stamina_factor(1) * _stamina_factor(1),
						2.0 * _stamina_factor(1)])
	assert_eq(_stamina_gain_with(3, 10), 1.0 * _stamina_factor(3) * 10.0,
		"AC 7: N=3 gives `1 + 3 x step`, still linear and still uncapped (AC 4)")


func test_one_stamina_accelerator_is_byte_identical_to_the_unaccelerated_baseline_times_the_shipped_factor() -> void:
	# `5-1/R1`'s load-bearing promise: the FIRST totem must not change balance. Measured against the
	# N=0 baseline from the same fixture, so the claim is a ratio this run produced rather than a
	# constant copied out of story 4-4.
	var baseline := _stamina_gain_with(0, 10)
	assert_eq(baseline, 1.0 * 10.0, "sanity: the non-accelerated rate is 1.0 per tick")
	assert_eq(_stamina_gain_with(1, 10), baseline * _stamina_factor(1),
		"N=1 is exactly the baseline times the shipped single-totem factor — unchanged from 4-4")


func test_killing_one_of_two_stamina_accelerators_returns_the_factor_to_its_n1_value() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(80.0, 0)
	ms.drain_signals()
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(12.0, KIND_STAMINA)
	var before := ms.p1.stamina.get_current()
	_advance(ms, 5)
	assert_eq(ms.p1.stamina.get_current() - before, 1.0 * _stamina_factor(2) * 5.0,
		"sanity: both are alive and the factor is the N=2 one")
	ms.p1.units.apply_damage_at(0, 12.0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: one of the two is dead")
	var after_death := ms.p1.stamina.get_current()
	_advance(ms, 5)
	assert_eq(ms.p1.stamina.get_current() - after_death, 1.0 * _stamina_factor(1) * 5.0,
		"AC 12: the factor returns to its N=1 value — NOT to the unaccelerated 1.0, which is what a "
		+ "seat that treated any death as 'the accelerator died' would give")


func test_the_stacked_stamina_factor_is_owner_only() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(60.0, 0)
	ms.p2.stamina.spend(60.0, 0)
	ms.drain_signals()
	var p1_before := ms.p1.stamina.get_current()
	var p2_before := ms.p2.stamina.get_current()
	assert_eq(p1_before, p2_before, "sanity: both heroes start this measurement level")
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p2.units.add(12.0, KIND_STAMINA)
	_advance(ms, 10)
	assert_eq(ms.p1.stamina.get_current(), p1_before + 1.0 * _stamina_factor(2) * 10.0,
		"the owner's TWO give the N=2 factor")
	assert_eq(ms.p2.stamina.get_current(), p2_before + 1.0 * _stamina_factor(1) * 10.0,
		"AC 2: the opponent's own ONE still gives the N=1 factor — the owner's second totem did not "
		+ "reach across the board")


func test_a_minion_beside_a_stamina_accelerator_does_not_raise_the_factor() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(60.0, 0)
	ms.drain_signals()
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(9.0, KIND_MINION)
	ms.p1.units.add(12.0, KIND_MANA)
	var before := ms.p1.stamina.get_current()
	_advance(ms, 10)
	assert_eq(ms.p1.stamina.get_current(), before + 1.0 * _stamina_factor(1) * 10.0,
		"AC 3: a minion and a MANA accelerator enter the stamina count not at all — N is per-kind at "
		+ "the seat, not merely in the predicate")


# ---- Story 5-1 (AC 9): `4-4` M2, discharged by the additive default -----------------------------

## `4-4` M2 (`_44-review.md:330`) named a real defect in the OLD mechanism: `stamina_accelerator_
## regen_multiplier` defaulted to 0.0, and an unauthored config therefore MULTIPLIED the regen of the
## one player who had actually summoned a totem BY ZERO — inverting AC 21, which asks the totem to
## help and at worst do nothing. The new mechanism makes that impossible by construction rather than
## by audit: under `1 + N x step` the same 0.0 default is the IDENTITY at every N.
##
## THIS TESTS THE CLASS DEFAULT, NOT THE AUTHORED VALUE. `test_balance_authoring.gd` already audits
## what the shipped `.tres` carries; M2 is about the config that never sets the field at all, which
## is why the fixture below deliberately leaves it unassigned.
func test_an_unauthored_step_leaves_the_regen_alone_rather_than_zeroing_it() -> void:
	assert_eq(BalanceConfig.new().stamina_accelerator_regen_step, 0.0,
		"the CLASS DEFAULT is 0.0 — identity-safe for an ADDITIVE step, where the identical literal "
		+ "was the dangerous value for the MULTIPLICATIVE field it replaces")
	var ms := _make_match(true, false)
	assert_eq(ms.balance.stamina_accelerator_regen_step, 0.0,
		"sanity: this fixture never authored the step, so the seat reads the class default")
	ms.p1.stamina.spend(50.0, 0)
	ms.p2.stamina.spend(50.0, 0)
	ms.drain_signals()
	var accelerated_before := ms.p1.stamina.get_current()
	var plain_before := ms.p2.stamina.get_current()
	ms.p1.units.add(12.0, KIND_STAMINA)
	ms.p1.units.add(12.0, KIND_STAMINA)
	_advance(ms, 10)
	assert_eq(ms.p1.stamina.get_current(), accelerated_before + 1.0 * 10.0,
		"`4-4` M2: with the step unauthored, an owner carrying TWO live accelerators regenerates at "
		+ "exactly the non-accelerated rate — no boost, and CRUCIALLY no penalty. Under the old "
		+ "multiplicative field this owner regenerated NOTHING")
	assert_eq(ms.p1.stamina.get_current() - accelerated_before,
			ms.p2.stamina.get_current() - plain_before,
		"...and the accelerated owner and the bare opponent gained the SAME amount, which is what "
		+ "'the factor is the identity' means measured rather than asserted")
