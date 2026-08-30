extends TestCase

## Story 4-4 coverage: THE TWO ACCELERATOR TOTEMS (AC 20, AC 21, `4-4/R11`, `4-4/R13`).
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
const STAMINA_FACTOR := 2.5             # deliberately NOT 2.0: a doubling could coincide with a
                                        # double-application bug and read as correct

const KIND_MINION := 0
const KIND_MANA := 1
const KIND_STAMINA := 2


func _config() -> BalanceConfig:
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
	c.stamina_accelerator_regen_multiplier = STAMINA_FACTOR
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


func _make_match(totems_open := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(17))
	ms.apply_balance(_config())
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
	ms.p1.units.apply_damage_at(0, 12.0)
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
	assert_eq(ms.p1.stamina.get_current(), p1_before + 1.0 * STAMINA_FACTOR * 10.0,
		"AC 21: the OWNER's regen is the non-accelerated rate times the authored factor")
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
	ms.p1.units.apply_damage_at(0, 12.0)
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
	ms.p1.units.apply_damage_at(0, 12.0)
	assert_false(ms.has_live_kind(ms.p1, CardEffectResolver.KIND_MANA_ACCELERATOR),
		"a dead totem is not live — liveness is the board's own predicate, never a re-derived hp>0")
	assert_false(ms.has_live_kind(ms.p1, &"no_such_kind"),
		"an unauthored kind name answers FALSE rather than tripping a guard — the faucet is simply "
		+ "shut, which is the graceful-degradation direction")
