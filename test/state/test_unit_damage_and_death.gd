extends TestCase

## Story 4-3a coverage: a hero's landed attack DAMAGES and eventually KILLS a summoned minion, and
## the corpse leaves the board as a HOLE at a stable index.
##
## WHAT THIS FILE OWNS, per AC: `hp` on the unit record and its authored entry value (AC 1); the
## DEDICATED FLAT damage-to-unit field and the fact that it is NOT the percent-of-max hero formula
## (AC 2, `4-3a/R8`); the widened `[slot, index]` contact-fact target and the widened
## `[attack_index, slot, index]` dedupe key, including the CLEAVE it enables and the hero-vs-hero
## REGRESSION PIN it must not disturb (AC 3, `4-3a/R16`/`R19`); no mana on a unit kill (AC 5); the
## hole discipline and the never-reused ruling (AC 7, `4-3a/R2`/`R9`); the targeting liveness seat
## and the `Array[int]` evaluator contract (AC 8, `4-3a/R15`); and the MEASURED round-over-freeze
## claim `4-3a/R21a` narrowed the Open Question to.
##
## WHAT IT DELIBERATELY DOES NOT OWN: AC 4 (the unit hurtbox reaching the pipeline), AC 6 (the
## GATHER-time friendly-fire filter) and AC 11 (the corpse's actor being freed) are all properties of
## the RUNNER and the SCENE, structurally invisible to a headless state test — they live in
## test/integration/test_unit_combat_live.gd. AC 10 is body collision, in
## test/integration/test_two_units_converge_live.gd.
##
## Test balance is constructed IN-TEST and never loaded from `data/balance/*.tres` (the BC/R3
## isolation): windup 3 / active 4 / recovery 6 on the test_contact_resolution.gd shape, plus a unit
## maximum of 9.0 and a flat unit damage of 3.0 — three swings to kill.
##
## THE PERCENT FIELD IS AUTHORED TO A VALUE THAT WOULD DISAGREE (50.0), on purpose: 50% of the unit's
## own 9.0 maximum is 4.5, so every hp assertion below distinguishes the flat field from the formula
## `4-3a/R8` rejected. A dev pass that wired the percentage in would fail here, not merely elsewhere.

const UNIT_MAX_HP := 9.0
const UNIT_DAMAGE := 3.0
## Deliberately unlike UNIT_MAX_HP and unlike any script default, so AC 1's "enters at the AUTHORED
## maximum" cannot pass against a hardcoded 9.0 or a coincidental zero.
const DISTINCTIVE_MAX_HP := 17.0

const CAST_SEED := 4321
const CAST_DECK_SIZE := 8
const CAST_HAND_SIZE := 4
const CAST_START_MANA := 90.0
const CAST_CARD_COST := 1.0


func _config(unit_max_hp := UNIT_MAX_HP) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 3.0 / 60.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	# 50% of a 9.0 unit maximum would be 4.5 — a DIFFERENT number from the flat 3.0, which is what
	# makes every hp assertion below discriminate between the two implementations (`4-3a/R8`).
	c.attack_damage_percent_of_max_hp = 50.0
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.block_damage_multiplier = 0.5
	c.block_facing_arc_degrees = 180.0
	c.deflect_window_seconds = 4.0 / 60.0
	# Story 4-4 (AC 6/AC 9): per-kind now, same in-test literals. The phase durations are 0 here —
	# this base fixture never advances a unit swing (the 4-3b fixture below sets real ones) — and a
	# zero-length phase is legal in-test exactly as a zero draw delay is.
	c.unit_kinds = UnitKindFixture.minion_only(unit_max_hp, UNIT_DAMAGE, 0, 0, 0, 2.0)
	c.hero_damage_to_unit = UNIT_DAMAGE
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	return f


func _make_match(unit_max_hp := UNIT_MAX_HP) -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config(unit_max_hp))
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


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


## P1 presses attack on tick 1 and the match advances to tick 4 — the first ACTIVE tick (windup
## t1-3, active t4-7). A fact pushed now resolves in the next advance().
func _swing_to_active(ms: MatchState) -> void:
	_advance(ms, _intent([&"attack"]))
	for _t in 3:
		_advance(ms)


## Put `count` units on P2's board at full health, the `test_targeting_service.gd::_summon` idiom:
## straight onto the board rather than through a cast, because these tests are about what happens to
## a unit AFTER it exists. The real step-6 cast seat has its own test below.
func _summon_p2(ms: MatchState, count: int) -> void:
	for _i in count:
		ms.p2.units.add(UNIT_MAX_HP, 0)


## ---- AC 1: hp joins the record, at the AUTHORED maximum ----------------------------------

## AC 1 through the REAL step-6 cast seat, which is the only place that proves `balance.unit_max_hp`
## is READ AT THE POINT OF USE (CONSTRAINT C) rather than defaulted. `_summon_p2` above hands the
## value in directly and so could never catch a cast seat that passed 0.0.
##
## The maximum is DISTINCTIVE (17.0), so a hardcoded 9.0, a script default of 0.0 and a value copied
## from `max_hp` all fail rather than coincide.
func test_a_summoned_unit_enters_at_the_authored_maximum() -> void:
	var ms := _match_for_cast(DISTINCTIVE_MAX_HP)
	_advance_with(ms, _cast_intent(0))
	assert_eq(ms.p1.units.size(), 1,
		"sanity: the cast really did summon through the real step-6 seat")
	assert_eq(ms.p1.units.hp_at(0), DISTINCTIVE_MAX_HP,
		"a freshly summoned unit enters at the AUTHORED maximum, read inline at the cast seat "
		+ "(AC 1) — not at 0.0, not at the hero's max_hp, not at a literal in the board")
	assert_true(ms.p1.units.is_alive_at(0),
		"...and it is therefore ALIVE — a unit that entered at 0.0 would be born a corpse")


## The bound in the other direction: a maximum of 0.0 summons something already dead. Not a shipped
## configuration (test_balance_authoring.gd audits the AUTHORED value > 0), but the reason that audit
## exists — and proof that liveness really is derived from hp rather than from "a record exists".
func test_a_zero_maximum_summons_a_record_that_is_already_dead() -> void:
	var ms := _make_match()
	ms.p2.units.add(0.0, 0)
	assert_eq(ms.p2.units.size(), 1, "the record exists")
	assert_false(ms.p2.units.is_alive_at(0),
		"...and is NOT alive: liveness is hp > 0, derived, never 'a record is present'")


## ---- AC 2: the DEDICATED FLAT damage field --------------------------------------------------

## AC 2 (`4-3a/R8`, decided by Matko). Each of the three assertions is a different number from what
## `attack_damage_percent_of_max_hp` (50%) would produce against either maximum:
##   flat 3.0        -> 9.0, 6.0, 3.0, 0.0
##   50% of unit max -> 4.5 per hit (two hits to kill)
##   50% of hero max -> 50.0 per hit (one hit to kill)
## so this test discriminates the shipped implementation from BOTH rejected ones.
func test_a_hero_swing_takes_the_dedicated_flat_damage_off_a_unit() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	assert_eq(ms.p2.units.hp_at(0), UNIT_MAX_HP, "sanity: full health before the swing")
	_swing_to_active(ms)
	ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 6.0,
		"one confirmed swing takes the FLAT authored 3.0 — not 4.5 (50%% of the unit's own 9.0 "
		+ "maximum) and not 50.0 (50%% of the hero's 100.0), the two formulas `4-3a/R8` rejected")
	assert_true(ms.p2.units.is_alive_at(0), "one hit does not kill at three-swings-to-kill")


## AC 2's whole point, stated as the thing a player experiences: THREE swings kill. Each swing is a
## separate attack_index, so this also exercises the dedupe across swings rather than within one.
func test_three_swings_kill_a_unit_and_the_third_is_the_one_that_does_it() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	var expected: Array[float] = [6.0, 3.0, 0.0]
	for swing in 3:
		_swing_to_active(ms)
		ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
		_advance(ms)
		assert_eq(ms.p2.units.hp_at(0), expected[swing],
			"after swing %d the unit is at %.1f" % [swing + 1, expected[swing]])
		assert_eq(ms.p2.units.is_alive_at(0), swing < 2,
			"the unit is alive after swings 1 and 2 and DEAD after swing 3 — the kill is the THIRD "
			+ "swing, not the first and not the fourth")
		# Let the swing (and its dedupe record) fully expire before the next one.
		for _t in 12:
			_advance(ms)


## Overkill is CLAMPED, not carried negative — the `HeroState._set_hp` mirror. Two units killed by
## differently-sized hits must hash identically: both are simply dead.
func test_damage_is_clamped_at_zero_so_overkill_does_not_go_negative() -> void:
	var ms := _make_match()
	ms.p2.units.add(1.0, 0)  # less health than one hit's damage
	_swing_to_active(ms)
	ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 0.0,
		"hp floors at 0.0 rather than -2.0 — overkill leaves no trace in the hash")
	assert_false(ms.p2.units.is_alive_at(0), "...and the unit is dead")


## ---- AC 5: a unit kill generates NO mana ----------------------------------------------------

## AC 5 (`4-3a/R3`, decided by Matko). The MECHANISM is that a unit-target confirmation never enters
## the confirmed-hits list step 5 reads, so this asserts across the WHOLE kill (three swings) rather
## than one hit — a gate that leaked on the killing blow alone would still pass a one-hit check.
##
## THE PAIR THAT MAKES IT NON-VACUOUS is the second half: the SAME fixture, the SAME swing, against
## the HERO instead, DOES generate mana. Without it this test would pass against a match in which
## mana generation was broken outright.
func test_hitting_and_killing_a_unit_generates_no_mana_but_hitting_a_hero_does() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	for _swing in 3:
		_swing_to_active(ms)
		ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
		_advance(ms)
		for _t in 12:
			_advance(ms)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the unit is dead — three swings landed")
	assert_eq(ms.p1.mana.get_current(), 0.0,
		"killing a minion is worth NO mana (AC 5): a unit-target confirmation never enters the "
		+ "confirmed-hits list that step 5's melee rung reads")
	# The PAIR: an identical swing against the HERO in the same match DOES pay.
	_swing_to_active(ms)
	ms.push_contact([0, -1], [1, TargetingService.HERO_INDEX], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p1.mana.get_current(), 8.0,
		"...and the melee faucet is NOT simply broken: the same swing against the HERO pays the "
		+ "authored melee_hit_mana, so the zero above is attributable to the unit target alone")


## ---- AC 3: the widened target address and the widened dedupe key ----------------------------

## AC 3 / `4-3a/R16`: ONE SWING CLEAVES. Three facts in one active window, one attack_index, three
## DIFFERENT target addresses — two units and the enemy hero — resolve as three separate
## confirmations. Under the pre-4-3a slot-only key the second and third would have read as duplicates
## of a target the swing never touched, and only the first would have resolved.
func test_one_swing_cleaves_through_two_units_and_the_hero() -> void:
	var ms := _make_match()
	_summon_p2(ms, 2)
	_swing_to_active(ms)
	var swing := ms.p1.hero.attack_index
	ms.push_contact([0, -1], [1, 0], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	ms.push_contact([0, -1], [1, 1], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	ms.push_contact([0, -1], [1, TargetingService.HERO_INDEX], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 6.0, "unit 0 took the swing")
	assert_eq(ms.p2.units.hp_at(1), 6.0,
		"unit 1 took the SAME swing — the widened key made it a different address, not a duplicate")
	assert_eq(ms.p2.hero.get_hp(), 50.0,
		"and so did the HERO, at its own percent-of-max formula — one swing, three targets")


## `4-3a/R22`: the hit list this key populates is CANONICALLY ORDERED by target address, not left in
## arrival order. The cleave test above proves the widened key resolves several addresses in one
## swing; this test proves the ORDER those addresses land in the hit list — and therefore the
## snapshot, and therefore the hash — does not depend on the order the underlying facts were fed in.
## That order is the runner's overlap query, which pins nothing: two MatchStates fed the SAME set of
## contact facts in DIFFERENT orders must produce identical snapshots and identical hashes.
func test_the_hit_list_is_canonically_ordered_regardless_of_fact_arrival_order() -> void:
	var forward := _make_match()
	_summon_p2(forward, 2)
	_swing_to_active(forward)
	var forward_swing := forward.p1.hero.attack_index
	forward.push_contact([0, -1], [1, 0], forward_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	forward.push_contact([0, -1], [1, 1], forward_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	forward.push_contact([0, -1], [1, TargetingService.HERO_INDEX], forward_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(forward)

	var reverse := _make_match()
	_summon_p2(reverse, 2)
	_swing_to_active(reverse)
	var reverse_swing := reverse.p1.hero.attack_index
	reverse.push_contact([0, -1], [1, TargetingService.HERO_INDEX], reverse_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	reverse.push_contact([0, -1], [1, 1], reverse_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	reverse.push_contact([0, -1], [1, 0], reverse_swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(reverse)

	assert_eq(forward_swing, reverse_swing, "sanity: same seed, same fixture, same attack_index")
	var forward_hit: Array = forward.p1.hero.to_snapshot()["swing_dedupe"]["records"][forward_swing]["hit"]
	var reverse_hit: Array = reverse.p1.hero.to_snapshot()["swing_dedupe"]["records"][reverse_swing]["hit"]
	assert_eq(forward_hit, reverse_hit,
		"the hit list is IDENTICAL regardless of the order the three facts were pushed in — canonical "
		+ "order by target address, not arrival order (`4-3a/R22`)")
	assert_eq(forward_hit, [[1, -1], [1, 0], [1, 1]] as Array,
		"...specifically ascending by [slot, index]: the hero (-1) sorts before unit 0, which sorts "
		+ "before unit 1")
	assert_eq(CanonicalHash.of(forward.to_snapshot()), CanonicalHash.of(reverse.to_snapshot()),
		"and therefore the two matches hash IDENTICALLY — a cleave's hash must not depend on the "
		+ "runner's unpinned overlap-query ordering")


## The OTHER direction of the same key, and without it the cleave test above would be satisfied by
## deleting the dedupe entirely: the SAME address twice in one swing still resolves ONCE.
func test_the_same_address_twice_in_one_swing_still_resolves_only_once() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	_swing_to_active(ms)
	var swing := ms.p1.hero.attack_index
	ms.push_contact([0, -1], [1, 0], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	ms.push_contact([0, -1], [1, 0], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 6.0,
		"ONE hit's worth of damage, not two — the widened key still refuses the same address twice "
		+ "within one swing (AC 3's dedupe half)")


## AC 3's REGRESSION PIN (`4-3a/R19`), stated as one test over all four named properties: a HERO
## target under the widened `[slot, -1]` address must resolve IDENTICALLY to the bare-slot behaviour
## it replaces. The shipped contact suite (test_contact_resolution, test_block_deflect,
## test_roll_iframes, test_mana_economy, test_contact_pipeline, the replay pair) is the broad half of
## this pin — every one of those files passes its facts through the widened seam unchanged. This test
## is the NARROW half, asserting the four properties `4-3a/R19` names in one place so the claim has a
## named home rather than only an emergent one.
func test_a_hero_target_resolves_identically_under_the_widened_address() -> void:
	var ms := _make_match()
	var landed: Array = []
	ms.hit_landed.connect(func(attacker: int, target: int, damage: float, hp: float) -> void:
		landed.append([attacker, target, damage, hp]))
	_swing_to_active(ms)
	var swing := ms.p1.hero.attack_index
	ms.push_contact([0, -1], [1, TargetingService.HERO_INDEX], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	# (1) SAME DAMAGE VALUE — the percent-of-max hero formula, untouched by this story.
	assert_eq(ms.p2.hero.get_hp(), 50.0, "same damage: 50% of the target hero's 100.0 maximum")
	# (2) SAME hit_landed PAYLOAD — four fields, the target's SLOT (never an address) and its hp.
	assert_eq(landed.size(), 1, "exactly one hit_landed, as before")
	assert_eq(landed[0], [0, 1, 50.0, 50.0],
		"same payload: [attacker slot, target slot, damage, target hp] — the signal did NOT widen "
		+ "(`4-3a/R12`), so its shipped consumer is untouched")
	# (3) SAME CONFIRMED-HIT MEMBERSHIP — observed through the mana it pays at step 5.
	assert_eq(ms.p1.mana.get_current(), 8.0,
		"same confirmed-list membership: the hero hit still pays melee_hit_mana")
	# (4) SAME DEDUPE OUTCOME — a second fact from the same swing at the same address is refused.
	ms.push_contact([0, -1], [1, TargetingService.HERO_INDEX], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), 50.0, "same dedupe outcome: the repeat is still refused")
	assert_eq(landed.size(), 1, "...and emits no second signal")


## ---- AC 7: the hole, at a stable index, never reused ----------------------------------------

## AC 7 / `4-3a/R2`: death leaves a HOLE. The killed unit's record stays AT ITS INDEX, no later
## record shifts down, and no other record's hp is touched. Killing the FIRST of three is the case
## that matters — compaction would be invisible if the corpse were last.
func test_death_leaves_a_hole_at_a_stable_index_and_shifts_nothing() -> void:
	var ms := _make_match()
	_summon_p2(ms, 3)
	# Give the three units DISTINGUISHABLE health, so a shift is visible as a value moving between
	# indices rather than having to be inferred from the length alone.
	ms.p2.units.apply_damage_at(1, 1.0)   # 8.0
	ms.p2.units.apply_damage_at(2, 2.0)   # 7.0
	for _swing in 3:
		_swing_to_active(ms)
		ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
		_advance(ms)
		for _t in 12:
			_advance(ms)
	assert_eq(ms.p2.units.size(), 3,
		"the board is still THREE records — a corpse is not removed, it is a hole (`4-3a/R2`)")
	assert_false(ms.p2.units.is_alive_at(0), "index 0 is the hole")
	assert_eq(ms.p2.units.hp_at(0), 0.0, "...carrying 0.0, which IS the hole representation")
	assert_eq(ms.p2.units.hp_at(1), 8.0,
		"index 1 still holds ITS OWN health — nothing compacted down into the hole")
	assert_eq(ms.p2.units.hp_at(2), 7.0, "...and so does index 2")
	assert_true(ms.p2.units.is_alive_at(1) and ms.p2.units.is_alive_at(2),
		"both survivors are still alive at their ORIGINAL indices")


## AC 7 / `4-3a/R9`: A HOLE IS NEVER REUSED. A summon following a death lands at a NEW index. Driven
## through the REAL step-6 cast seat, because `add()` being an unconditional append is exactly the
## property under test and a direct `add()` call would be assuming it rather than measuring it.
##
## WHY THE RULING EXISTS, restated so a later pooling story (`4-5`) has to reverse it deliberately:
## reuse would silently re-point a stale throttled `unit_targets` reference at a DIFFERENT live unit.
func test_a_summon_following_a_death_lands_at_a_new_index_never_in_the_hole() -> void:
	var ms := _match_for_cast(UNIT_MAX_HP)
	_advance_with(ms, _cast_intent(0))
	assert_eq(ms.p1.units.size(), 1, "sanity: one unit, at index 0")
	# Kill it outright, at the board seam — how it died is not what this test is about.
	ms.p1.units.apply_damage_at(0, UNIT_MAX_HP)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: index 0 is now a hole")
	_advance_with(ms, _cast_intent(1))
	assert_eq(ms.p1.units.size(), 2,
		"the board GREW — the new unit appended rather than filling the hole (`4-3a/R9`)")
	assert_false(ms.p1.units.is_alive_at(0),
		"index 0 is STILL the hole: the summon did not resurrect or overwrite the corpse")
	assert_true(ms.p1.units.is_alive_at(1), "the new unit is alive at the NEW index 1")
	assert_eq(ms.p1.units.hp_at(1), UNIT_MAX_HP, "...at the authored maximum")


## ---- AC 8: liveness at the targeting seat ---------------------------------------------------

## AC 8 / `4-3a/R15` at the EVALUATOR, where the contract changed. This is the case a COUNT
## structurally could not express: index 0 is a hole, so a count of 2 would hand back the corpse.
func test_the_evaluator_skips_a_hole_and_takes_the_ascending_first_LIVING_index() -> void:
	var priority := TargetingService.priority_named(
		TargetingService.authored_priorities(), TargetingService.PRIORITY_STANDARD)
	assert_not_null(priority, "sanity: the shipped `standard` priority loads")
	var living: Array[int] = [1, 2]      # index 0 is DEAD — the board still holds three records
	assert_eq(TargetingService.target_for(priority, 1, false, living, _flags()),
		[1, 1] as Array[int],
		"the verdict is index 1, the ascending-first LIVING index — NOT index 0, which a bare "
		+ "count of the board's length would have handed back (`4-3a/R15`)")
	# The PAIR: with index 0 alive, the same board size yields index 0 — so the answer above is
	# attributable to the hole and not to an off-by-one.
	var all_living: Array[int] = [0, 1, 2]
	assert_eq(TargetingService.target_for(priority, 1, false, all_living, _flags()),
		[1, 0] as Array[int],
		"...and with NOTHING dead the same board yields index 0, exactly as it did through 4-2")


## AC 8's reason half: a board that is ALL HOLES is indistinguishable from an EMPTY one, which is a
## count's other structural failure — a hole keeps a count non-zero forever.
func test_a_board_of_nothing_but_holes_reaches_no_living_candidate() -> void:
	var priority := TargetingService.priority_named(
		TargetingService.authored_priorities(), TargetingService.PRIORITY_STANDARD)
	var none: Array[int] = []
	assert_eq(TargetingService.reason_for(priority, false, none, _flags()),
		TargetingService.REASON_NO_LIVING_CANDIDATE,
		"a dead opposing hero and a board with no LIVING unit is an honest named no-target outcome "
		+ "— the docstring claiming 'a unit is always a living candidate' is falsified by this story")
	assert_true(TargetingService.is_no_target(
		TargetingService.target_for(priority, 1, false, none, _flags())),
		"...and the verdict is the no-target pair")


## AC 8 END TO END, through the REAL step-7 throttled seat rather than at the evaluator: P1's unit
## must not acquire a DEAD P2 unit. This is what `4-3a/R14` calls the targeting liveness seat, and it
## is the half the evaluator test above cannot reach — a seat that still passed `units.size()` would
## pass every evaluator test in this file and fail here.
func test_the_step_7_seat_never_acquires_a_dead_unit() -> void:
	var ms := _make_match()
	ms.p1.units.add(UNIT_MAX_HP, 0)          # the acquirer
	_summon_p2(ms, 2)                     # the candidates
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())   # hero dead, so units are the only candidates
	ms.p2.units.apply_damage_at(0, UNIT_MAX_HP)       # ...and candidate 0 is a hole
	assert_false(ms.p2.units.is_alive_at(0), "sanity: P2's index 0 is dead")
	assert_true(ms.p2.units.is_alive_at(1), "sanity: P2's index 1 is alive")
	# Run a full retarget interval so a boundary tick is certainly crossed.
	for _t in 70:
		_advance(ms)
	assert_eq(ms.p1.units.target_at(0), [1, 1] as Array[int],
		"the seat acquired the LIVING unit at index 1, never the corpse at index 0 — the candidate "
		+ "scan is handed living indices, not a count (AC 8, `4-3a/R14`)")


## AC 8's second clause: a dead unit "stops being addressable as an attack target by a later swing".
## The dead-target rung of the unit ladder, and the same rung the hero ladder has always had.
func test_a_dead_unit_is_not_addressable_by_a_later_swing() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	ms.p2.units.apply_damage_at(0, UNIT_MAX_HP)
	assert_eq(ms.p2.units.hp_at(0), 0.0, "sanity: dead")
	_swing_to_active(ms)
	var swing := ms.p1.hero.attack_index
	ms.push_contact([0, -1], [1, 0], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 0.0,
		"a fact against a corpse resolves to NOTHING — dropped at the dead-target rung, exactly as "
		+ "a fact against a dead hero is (AC 8)")
	# THE HP ASSERTION ABOVE CANNOT CARRY THIS TEST ALONE, and mutation proved it: `apply_damage_at`
	# CLAMPS AT ZERO, so a corpse that wrongly RESOLVED the fact would also read 0.0 afterwards.
	# Swapping the liveness rung for a bare bounds check killed no assertion until this one existed.
	# The discriminator is the DEDUPE RECORD: the drop is PRE-dedupe (the hero ladder's own ordering,
	# 2-3/R6's DEAD-drop family), so a dropped fact must NOT have consumed the swing's one resolution
	# against this address. A fact that resolved would have registered [1, 0] here.
	var records: Dictionary = ms.p1.hero.to_snapshot()["swing_dedupe"]["records"]
	assert_true(records.has(swing), "sanity: the swing's dedupe record is still live to be read")
	assert_false([1, 0] in records[swing]["hit"],
		"the fact was dropped BEFORE dedupe registration — the corpse's address never entered the "
		+ "swing's hit list, so it never consumed this swing's resolution against that address")
	assert_eq(ms.p1.mana.get_current(), 0.0,
		"...and pays no mana either, since it never reached a confirmation")


## The bound rung: a fact naming an index the board does not hold drops on the same rung rather than
## tripping a bound. The runner's actor array can legitimately be a frame out of step with the board,
## so this is a reachable input, not a hypothetical.
func test_a_fact_naming_a_nonexistent_index_is_dropped_not_a_crash() -> void:
	var ms := _make_match()
	_summon_p2(ms, 1)
	_swing_to_active(ms)
	ms.push_contact([0, -1], [1, 7], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), UNIT_MAX_HP,
		"the real unit at index 0 is untouched by a fact addressed to index 7")
	assert_eq(ms.p2.units.size(), 1, "...and no record was created by addressing one")


## ---- `4-3a/R21a`: the round-over freeze claim, MEASURED ---------------------------------------

## THE OPEN QUESTION `4-3a/R21a` LEFT OPEN IN MEASURED FORM. The story CLAIMS that death is resolved
## in the contact step immediately after damage is applied, and that the step-1b round-over freeze
## precedes that step and therefore needs no special case. That is a claim about ORDER inside
## advance(), and this is the measurement rather than the assertion.
##
## THE MECHANISM: step 1b returns from advance() before step 4 is ever reached, so a frozen tick
## drains no contact queue, applies no damage and kills no unit. A unit one hit from death survives
## the freeze indefinitely.
##
## THE PAIR that makes it non-vacuous: the SAME fact, the SAME unit, on an UNFROZEN match, DOES kill.
## Without it this test would pass against a build in which unit damage never worked at all.
func test_the_round_over_freeze_precedes_the_contact_step_so_no_unit_dies_during_it() -> void:
	# --- frozen half ---
	var frozen := _make_match()
	_summon_p2(frozen, 1)
	frozen.p2.units.apply_damage_at(0, UNIT_MAX_HP - UNIT_DAMAGE)  # one hit from death
	_swing_to_active(frozen)
	var swing := frozen.p1.hero.attack_index
	# End the round: P2's hero dies, and step 8 sets the freeze.
	frozen.p2.hero.take_damage(frozen.p2.hero.get_max_hp())
	_advance(frozen)
	assert_true(frozen.to_snapshot()["round_over"], "sanity: the round is over and the freeze is on")
	frozen.push_contact([0, -1], [1, 0], swing, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	for _t in 5:
		_advance(frozen)
	assert_eq(frozen.p2.units.hp_at(0), UNIT_DAMAGE,
		"the unit did NOT take the hit during the freeze: step 1b returns before step 4, so no "
		+ "contact resolves and nothing dies — `4-3a/R21a`'s claim, measured")
	assert_true(frozen.p2.units.is_alive_at(0), "...and it is still alive")
	# --- the unfrozen pair ---
	var live := _make_match()
	_summon_p2(live, 1)
	live.p2.units.apply_damage_at(0, UNIT_MAX_HP - UNIT_DAMAGE)
	_swing_to_active(live)
	live.push_contact([0, -1], [1, 0], live.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(live)
	assert_eq(live.p2.units.hp_at(0), 0.0,
		"the IDENTICAL fact on an unfrozen match DOES land and DOES kill — so the survival above is "
		+ "attributable to the freeze and not to a broken damage path")


## ---- Fixture: a real cast that summons ---------------------------------------------------------
##
## `test_targeting_service.gd::_match_for_cast`'s shape, narrowed to what these tests need. It exists
## because two ACs (1 and 7) are specifically about what the REAL step-6 cast dispatch does, and the
## `_summon_p2` shortcut structurally cannot see that seat.

func _match_for_cast(unit_max_hp: float) -> MatchState:
	var ms := MatchState.new(MatchParams.new(CAST_SEED))
	var c := _config(unit_max_hp)
	c.deck_size = CAST_DECK_SIZE
	c.hand_size = CAST_HAND_SIZE
	c.minion_retarget_interval_seconds = 1.0
	ms.apply_balance(c)
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_cast_deck_contents())
	ms.inject_card_costs(_cast_costs())
	ms.inject_card_effects(_cast_summon_effects())
	_advance_with(ms, InputIntent.new())   # step 6 of tick 1 deals the hand
	ms.p1.mana.add(CAST_START_MANA)
	ms.drain_signals()
	return ms


func _advance_with(ms: MatchState, p1_intent: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1_intent, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _cast_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _cast_deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in CAST_DECK_SIZE:
		out.append(StringName("unit_damage_card_%02d" % i))
	return out


func _cast_costs() -> Dictionary[StringName, CardCastCondition] :
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _cast_deck_contents():
		var cost := CardCastCondition.new()
		cost.mana_cost = CAST_CARD_COST
		out[id] = cost
	return out


## EVERY card summons, so whichever slot the deal happens to fill is castable — the hand's contents
## are seed-dependent and this file does not want to depend on that.
func _cast_summon_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _cast_deck_contents():
		var effect := CardEffect.new()
		effect.effect_id = &"summon_test_unit"
		out[id] = effect
	return out


## ================================================================================================
## STORY 4-3b (AC 15 / AC 17): the killed-mid-swing drop, and unit-versus-unit damage.
## ================================================================================================

const UNIT_WINDUP_4_3B := 2
const UNIT_ACTIVE_4_3B := 5
const UNIT_RECOVERY_4_3B := 4


func _config_4_3b() -> BalanceConfig:
	var c := _config()
	# Story 4-4 (AC 6/AC 9): the 4-3b rhythm re-authored on the kind rather than as four flat
	# globals. `_config()` above already built a minion kind with zero-length phases; this replaces
	# it wholesale rather than mutating the record in place, so the two fixtures cannot half-merge.
	c.unit_kinds = UnitKindFixture.minion_only(UNIT_MAX_HP, UNIT_DAMAGE, UNIT_WINDUP_4_3B,
			UNIT_ACTIVE_4_3B, UNIT_RECOVERY_4_3B, 2.0)
	c.minion_retarget_interval_seconds = 1000.0
	return c


func _match_4_3b() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config_4_3b())
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


## One unit on P1 acquired on `target`, driven into its ACTIVE window through the real reach trigger
## and the real phase ladder -- never by writing the phase directly.
func _p1_unit_into_active(ms: MatchState, target: Array[int]) -> void:
	ms.p1.units.add(UNIT_MAX_HP, 0)
	ms.p1.units.set_target_at(0, target[0], target[1])
	ms.push_contact([0, 0], target, 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	_advance(ms)
	for _t in UNIT_WINDUP_4_3B:
		_advance(ms)


## AC 15: A UNIT KILLED MID-SWING LANDS NOTHING. Contact facts carry the F1 one-tick lag, so a fact
## gathered while the attacker was alive can ARRIVE after it died; AC 14(a)'s liveness rung is what
## drops it, and this is what proves the rung does its job.
##
## A POSITIVE PIN, NOT A NEGATIVE CLAIM, which is AC 15's own requirement: the PAIRED run shows the
## fact WOULD have landed. Without it, "lands nothing" would also pass against a unit that never
## attacked at all -- exactly the vacuity the AC names.
func test_a_unit_killed_between_gather_and_resolution_lands_nothing() -> void:
	# (i) THE SURVIVING RUN: the identical fact applies damage.
	var survives := _match_4_3b()
	survives.p2.units.add(UNIT_MAX_HP, 0)
	_p1_unit_into_active(survives, [1, 0])
	var control_before := survives.p2.units.hp_at(0)
	survives.push_contact([0, 0], [1, 0], survives.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(survives)
	assert_eq(survives.p2.units.hp_at(0), control_before - UNIT_DAMAGE,
		"the control run LANDS: this exact fact, from this exact attacker, applies damage")

	# (ii) THE KILLED RUN: the same fact, gathered, then the attacker dies before resolution.
	var ms := _match_4_3b()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_p1_unit_into_active(ms, [1, 0])
	var before := ms.p2.units.hp_at(0)
	ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	# The kill lands BETWEEN gather and resolution -- the F1 window the drop exists for.
	ms.p1.units.apply_damage_at(0, UNIT_MAX_HP)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the ATTACKER is dead before step 4 runs")
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), before,
		"a unit killed between gather and resolution lands NOTHING — its in-flight fact is dropped "
		+ "at the attacker-liveness rung (AC 15), the 2-3/R6 drop reached from a unit attacker")


## AC 17: UNIT-VERSUS-UNIT DAMAGE FALLS OUT OF THE SAME OPENING, with no separate resolution path.
## Measured as HITS-TO-KILL EQUALITY between the two attacker kinds against the identical target, at
## the identical authored values -- which is the form that would catch a second ladder with its own
## damage number, and which a "a unit can damage a unit" test would not.
func test_a_minion_dies_to_a_minion_in_the_same_number_of_hits_it_takes_from_a_hero() -> void:
	var by_hero := _hits_to_kill_from_hero()
	var by_unit := _hits_to_kill_from_unit()
	assert_true(by_hero > 1,
		"sanity: the authored values need more than one hit, or the equality below is trivial")
	assert_eq(by_unit, by_hero,
		("a minion dies to another minion in the SAME number of hits it takes from a hero (%d) — "
		+ "both attacker kinds read the same `unit_damage_per_hit` against the same `unit_max_hp` "
		+ "through the same ladder, with no separate resolution path (AC 17)") % by_hero)
	assert_eq(by_hero, ceili(UNIT_MAX_HP / UNIT_DAMAGE),
		"...and that number is the one the AUTHORED values imply, so the equality is not two "
		+ "implementations agreeing on a wrong answer")


## Hits a HERO attacker needs to kill one unit. A fresh swing per hit: the dedupe refuses a second
## fact against the same address within one swing, which is the mechanism, not an obstacle.
func _hits_to_kill_from_hero() -> int:
	var ms := _match_4_3b()
	_summon_p2(ms, 1)
	var hits := 0
	while ms.p2.units.is_alive_at(0) and hits < 20:
		_swing_to_active(ms)
		ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN,
				MatchState.CONTACT_STRIKE)
		_advance(ms)
		hits += 1
		# Let the hero's swing finish so the next press starts a fresh one.
		for _t in 12:
			_advance(ms)
	return hits


## Hits a UNIT attacker needs to kill one unit, driven through the real rhythm: the unit is kept in
## reach so it cycles, and each landed strike is counted.
func _hits_to_kill_from_unit() -> int:
	var ms := _match_4_3b()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_p1_unit_into_active(ms, [1, 0])
	var hits := 0
	var cycles := 0
	while ms.p2.units.is_alive_at(0) and cycles < 20:
		if ms.p1.units.is_hitbox_active_at(0):
			var before := ms.p2.units.hp_at(0)
			ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), Vector2.DOWN,
					MatchState.CONTACT_STRIKE)
			_advance(ms)
			if ms.p2.units.hp_at(0) < before:
				hits += 1
			continue
		# Not in its window: keep it in reach so the rhythm cycles, and advance.
		# Story 4-4 (`4-4/R14`): TWO ticks of freshness, not one — the mark happens outside
		# `advance()`, and `tick_attack_timers` ages it once at step 2 before the step-3b gate reads
		# it, so a one-tick window would be stale by the time the gate looks.
		ms.p1.units.mark_in_reach_at(0, 2)
		_advance(ms)
		cycles += 1
	return hits
