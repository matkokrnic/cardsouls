extends TestCase

## Story 6-3b (AC 1/AC 5): `MatchState.pitch_changed` -- the presentation-facing signal the pitch HUD
## observes through the runner's tenth seam. Every emission site AC 1 enumerates is driven here through
## the real ordered dispatch and its DRAINED payload asserted: (a) stage, (b) activate, (c) expiry,
## (d) debug reset, (e) an orb grant landing inside a staged window, (f) the authored countdown throttle.
## The negative half is asserted as hard as the positive one: a staged zone on a NON-boundary tick with
## no event emits NOTHING, an empty zone never throttles, a grant with no staged zone emits nothing, and
## a round-over freeze emits nothing.
##
## Fixture shape: the `test_pitch_staging.gd` pitch fixture merged with the `test_orbs_economy.gd` mode ②
## landing fixture, because site (e) needs a real unblockable landing inside a staged window. Every card
## is RED, so whichever card the landing casts pays RED and meets the RED pitch price -- no test depends
## on what the seeded shuffle dealt. Quantities are distinct (timer 40 ticks, interval 7 ticks, chargeup
## 4, delay 3, grant 2, price 1, cap 3) so an off-by-one lands on a wrong number rather than a right one.
## Every config, flag set and cost map is built IN-TEST -- the authored .tres files never reach here.

const SEED := 6363
const DECK_SIZE := 8
const HAND_SIZE := 4
const START_MANA := 10.0
const PITCH_MANA := 2.0
const PITCH_ORBS := 1
const PITCH_COLOR := Enums.CardColor.RED
const TIMER_TICKS := 40
const INTERVAL_TICKS := 7
const DELAY_TICKS := 3
const CHARGEUP_TICKS := 4
const ORB_GRANT := 2
const MAX_ORBS := 3
const STAGE_SLOT := 2
const CAST_SLOT := 0
const REACH := 8.0
const FACT_DIR := Vector2(0.0, 1.0)

## The payloads drained by the most recent `_advance`, each [slot, card_id, hand_slot, ready,
## remaining_ticks, duration_ticks].
var _drained: Array = []
## Story 7-4 (AC 13/AC 15): the payload's seventh argument, `fresh_orbs` (a sorcery's sockets), index-aligned
## with `_drained` -- kept apart so every 6-6b assertion above reads the same six values it always did.
var _drained_sockets: Array = []


# --- (a) STAGE -----------------------------------------------------------------------------------

func test_staging_emits_the_owner_card_slot_not_ready_and_a_full_countdown() -> void:
	var ms := _make_match()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_assert_not_boundary(ms, "the staging tick")
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(_drained, [[0, id, STAGE_SLOT, false, TIMER_TICKS, TIMER_TICKS]],
		"ONE payload at staging: owner 0, the card, its hand slot, NOT READY, full countdown")


func test_staging_a_card_already_affordable_emits_ready() -> void:
	var ms := _make_match()
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(_drained, [[0, id, STAGE_SLOT, true, TIMER_TICKS, TIMER_TICKS]],
		"READY is read at the emission instant, against the live pool")


func test_a_refused_stage_emits_nothing() -> void:
	var ms := _make_match(0.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "sanity: no mana, so the stage was refused")
	assert_eq(_drained, [], "a refusal changes no zone and emits nothing")


func test_p2_staging_carries_owner_one() -> void:
	var ms := _make_match()
	var id: StringName = ms.p2.hand.to_array()[1]
	_advance(ms, InputIntent.new(), _stage_intent(1))
	assert_eq(_drained, [[1, id, 1, false, TIMER_TICKS, TIMER_TICKS]],
		"the OWNER slot rides the payload -- P2's zone reads owner 1")


# --- (f) THE COUNTDOWN THROTTLE ------------------------------------------------------------------

func test_the_throttle_emits_only_on_boundary_ticks_while_staged() -> void:
	var ms := _make_match()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var boundaries := 0
	var quiet := 0
	for _t in 3 * INTERVAL_TICKS:
		_tick(ms)
		var tick := int(ms.to_snapshot()["tick"])
		var fizzle: Dictionary = ms.to_snapshot()["pitch"]["p1"]["fizzle"]
		var remaining := int(fizzle["duration_ticks"]) - int(fizzle["elapsed_ticks"])
		if tick % INTERVAL_TICKS == 0:
			boundaries += 1
			assert_eq(_drained, [[0, id, STAGE_SLOT, false, remaining, TIMER_TICKS]],
				"a boundary tick (%d) re-pushes the live countdown" % tick)
			assert_true(remaining < TIMER_TICKS, "...which has moved since staging (tick %d)" % tick)
		else:
			quiet += 1
			assert_eq(_drained, [], "a NON-boundary tick (%d) with a staged zone emits NOTHING" % tick)
	assert_eq(boundaries, 3, "three boundaries crossed (non-vacuity)")
	assert_true(quiet > 0, "...and non-boundary ticks were checked too")


func test_an_empty_zone_never_throttles() -> void:
	var ms := _make_match()
	for _t in 3 * INTERVAL_TICKS:
		_tick(ms)
		assert_eq(_drained, [], "no staged zone: no boundary emits (tick %d)" % int(ms.to_snapshot()["tick"]))


func test_the_throttle_reads_the_authored_interval() -> void:
	var ms := _make_match(START_MANA, 11)
	assert_eq(ms.balance_ticks.pitch_countdown_push_interval_ticks, 11, "sanity: the in-test interval")
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var emitting_ticks: Array[int] = []
	for _t in 22:
		_tick(ms)
		if not _drained.is_empty():
			emitting_ticks.append(int(ms.to_snapshot()["tick"]))
	for tick in emitting_ticks:
		assert_eq(tick % 11, 0, "every throttle emission lands on a multiple of the interval")
	assert_eq(emitting_ticks.size(), 2, "22 ticks at interval 11 cross exactly two boundaries")


func test_nothing_emits_while_the_round_is_frozen() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_tick(ms)
	assert_true(ms.to_snapshot()["round_over"], "sanity: the round is over")
	for _t in 3 * INTERVAL_TICKS:
		_tick(ms)
		assert_eq(_drained, [], "a frozen tick returns before step 6: no throttle emission")
		assert_true(ms.pitch.is_staged(0), "...because the zone itself is still staged, not cleared")


# --- (b) ACTIVATE / (c) EXPIRY / (d) DEBUG RESET -------------------------------------------------

func test_activation_emits_an_empty_zone() -> void:
	var ms := _make_match()
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_skip_to_non_boundary(ms)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "sanity: activated")
	assert_eq(_drained, [[0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0]],
		"activation emits the EMPTY zone: no card, no slot, not READY, both tick counts 0")


func test_a_refused_activation_emits_nothing() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_skip_to_non_boundary(ms)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "sanity: NOT READY, so refused")
	assert_eq(_drained, [], "a refused activation emits nothing")


func test_expiry_emits_an_empty_zone_on_the_fizzle_tick() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var expired_on := -1
	for _t in TIMER_TICKS + 1:
		_tick(ms)
		if not ms.pitch.is_staged(0):
			expired_on = int(ms.to_snapshot()["tick"])
			assert_eq(_drained, [[0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0]],
				"the fizzle tick emits exactly the empty zone")
			break
	assert_true(expired_on > 0, "the card fizzled inside the loop (non-vacuity)")


func test_the_debug_reset_emits_an_empty_zone_for_both_slots() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), _stage_intent(1))
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	var empty := [PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0]
	assert_eq(_drained.filter(func(p: Array) -> bool: return p[0] == 0), [[0] + empty],
		"the reset emits P1's empty zone once")
	assert_eq(_drained.filter(func(p: Array) -> bool: return p[0] == 1), [[1] + empty],
		"...and P2's once")


# --- (e) ORB GRANT -------------------------------------------------------------------------------

func test_an_orb_grant_inside_a_staged_window_flips_ready_on_the_landing_tick() -> void:
	var ms := _make_match(START_MANA, 1000)
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_advance(ms, _unblockable_intent(CAST_SLOT), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: P1 is charging")
	assert_eq(_drained, [], "the cast itself grants nothing and emits nothing")
	var landed := false
	for _t in CHARGEUP_TICKS:
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.orbs.get_count(PITCH_COLOR) > 0:
			landed = true
			var fizzle: Dictionary = ms.to_snapshot()["pitch"]["p1"]["fizzle"]
			var remaining := int(fizzle["duration_ticks"]) - int(fizzle["elapsed_ticks"])
			assert_eq(_drained, [[0, id, STAGE_SLOT, true, remaining, TIMER_TICKS]],
				"the landing tick emits READY at once -- not up to one throttle interval late")
			break
		assert_eq(_drained, [], "no pitch emission during the chargeup before the landing")
	assert_true(landed, "the unblockable landed and paid orbs (non-vacuity)")


func test_an_orb_grant_with_no_staged_zone_emits_nothing() -> void:
	var ms := _make_match(START_MANA, 1000)
	_advance(ms, _unblockable_intent(CAST_SLOT), InputIntent.new())
	var landed := false
	for _t in CHARGEUP_TICKS:
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
		landed = landed or ms.p1.orbs.get_count(PITCH_COLOR) > 0
		assert_eq(_drained, [], "no staged zone: the grant emits no pitch payload")
	assert_true(landed, "the unblockable landed and paid orbs (non-vacuity)")


# --- Story 7-4: THE SOCKETS (AC 13/AC 15) ---------------------------------------------------------

func test_an_instant_carries_no_sockets() -> void:
	var ms := _make_match()
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(_drained.size(), 1, "sanity: one staging payload")
	assert_eq(_drained_sockets, [{}], "an instant's payload carries NO sockets -- it needs no new visual")


func test_a_sorcery_stages_with_empty_sockets_even_when_the_bank_holds_its_price() -> void:
	var ms := _make_match(START_MANA, INTERVAL_TICKS, Enums.PitchSpeed.SORCERY)
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(_drained, [[0, id, STAGE_SLOT, false, TIMER_TICKS, TIMER_TICKS]],
		"a SORCERY staged against a bank that already holds its price is NOT READY")
	assert_eq(_drained_sockets, [{PITCH_COLOR: 0}],
		"...and its one socket is EMPTY: banked orbs never fill a socket")


func test_a_sorcery_socket_fills_and_ready_flips_on_the_landing_tick_capped_at_the_price() -> void:
	var ms := _make_match(START_MANA, 1000, Enums.PitchSpeed.SORCERY)
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_advance(ms, _unblockable_intent(CAST_SLOT), InputIntent.new())
	var landed := false
	for _t in CHARGEUP_TICKS:
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.orbs.get_count(PITCH_COLOR) > 0:
			landed = true
			var fizzle: Dictionary = ms.to_snapshot()["pitch"]["p1"]["fizzle"]
			var remaining := int(fizzle["duration_ticks"]) - int(fizzle["elapsed_ticks"])
			assert_eq(_drained, [[0, id, STAGE_SLOT, true, remaining, TIMER_TICKS]],
				"the landing tick emits READY for the sorcery -- an EARNED orb counts")
			assert_eq(_drained_sockets, [{PITCH_COLOR: PITCH_ORBS}],
				"...and its socket count is the grant (%d) CAPPED at the price (%d)" % [ORB_GRANT, PITCH_ORBS])
			break
	assert_true(landed, "the unblockable landed and paid orbs (non-vacuity)")


func test_both_huds_get_the_same_sockets_because_the_payload_is_match_level() -> void:
	var ms := _make_match(START_MANA, INTERVAL_TICKS, Enums.PitchSpeed.SORCERY)
	_advance(ms, InputIntent.new(), _stage_intent(1))
	assert_eq(_drained.size(), 1, "one payload for P2's staging")
	assert_eq(int(_drained[0][0]), 1, "...owned by slot 1")
	assert_eq(_drained_sockets, [{PITCH_COLOR: 0}],
		"...carrying P2's sockets on the ONE match-level signal both HUDs subscribe to")


# --- helpers -------------------------------------------------------------------------------------

func _assert_not_boundary(ms: MatchState, occasion: String) -> void:
	assert_true((int(ms.to_snapshot()["tick"]) + 1) % INTERVAL_TICKS != 0,
		"fixture: %s is not a throttle boundary" % occasion)


## Tick until the NEXT tick is not a throttle boundary, so a single-event assertion is not polluted.
func _skip_to_non_boundary(ms: MatchState) -> void:
	while (int(ms.to_snapshot()["tick"]) + 1) % INTERVAL_TICKS == 0:
		_tick(ms)


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("hud_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 0.0
		out[id] = c
	return out


func _pitch_costs(speed := Enums.PitchSpeed.INSTANT) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MANA
		c.orb_costs[PITCH_COLOR] = PITCH_ORBS
		c.pitch_speed = speed
		out[id] = c
	return out


func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in _deck_contents():
		out[id] = PITCH_COLOR
	return out


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = true
	f.unblockable = true
	return f


func _config(interval_ticks: int) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 1.0 / TimingWindow.TICK_HZ
	c.draw_replacement_delay_seconds = float(DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = 2.0
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = 10.0
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	c.pitch_stage_timer_seconds = float(TIMER_TICKS) / TimingWindow.TICK_HZ
	c.pitch_countdown_push_interval_seconds = float(interval_ticks) / TimingWindow.TICK_HZ
	return c


## A match with a dealt hand, mana on the board, and a listener on `pitch_changed` that fills
## `_drained` (cleared by every `_advance`).
func _make_match(mana := START_MANA, interval_ticks := INTERVAL_TICKS,
		speed := Enums.PitchSpeed.INSTANT) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(interval_ticks))
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	ms.inject_pitch_costs(_pitch_costs(speed))
	ms.pitch_changed.connect(
		func(slot: int, card_id: StringName, hand_slot: int, ready: bool, remaining: int,
				duration: int, fresh_orbs: Dictionary) -> void:
			_drained.append([slot, card_id, hand_slot, ready, remaining, duration])
			_drained_sockets.append(fresh_orbs))
	_tick(ms)
	ms.p1.mana.add(mana)
	ms.p2.mana.add(mana)
	ms.drain_signals()
	_drained = []
	_drained_sockets = []
	return ms


func _stage_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	return i


func _activate_intent() -> InputIntent:
	var i := InputIntent.new()
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = true
	return i


func _unblockable_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


## The runner's every-tick charge-reach push for P1, by hand and through the real seam.
func _push_reach(ms: MatchState) -> void:
	ms.push_contact([0, TargetingService.HERO_INDEX], [1, TargetingService.HERO_INDEX],
		ms.p1.hero.attack_index, FACT_DIR, MatchState.CONTACT_CHARGE_REACH_INSIDE)


func _tick(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	_drained = []
	_drained_sockets = []
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
