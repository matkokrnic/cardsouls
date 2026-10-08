extends TestCase

## Story 7-9: UNBLOCKABLE TEMPO -- the headless half of the new rules.
##
## WHAT THIS FILE PINS, AC by AC:
##   AC 1      -- the price: mana AND stamina at the click; short of mana (or of both) refused with
##                `insufficient_mana`, nothing spent; a zero cost is free (`7-9/R16`).
##   AC 2      -- no refund on a counter, a miss or an i-frame dodge (the immunity half is under AC 11).
##   AC 4      -- the steering: at most the colour's per-tick angle toward this tick's pushed bearing, the
##                launch travel along the result; no push keeps the facing; exactly-behind turns one fixed
##                way; the colour order comes from the config; a rate of 0 turns nothing; the first touch,
##                even a dropped one, ends the steering (`7-9/R3`, ruled at the code review).
##   AC 5      -- the launch's path length is still the authored distance when the path bends.
##   AC 6      -- the counter window anchored at the commit: a press no older than the colour's lead before
##                the commit counters ON the commit tick; one tick older is too early (card spent, the hit
##                lands); a press in flight counters; a wrong colour never does; lead 0 opens at the commit.
##   AC 7      -- a press on a dropped-touch tick is accepted but never judged.
##   AC 8/AC 9 -- defence legality: refused with `nothing_to_answer` and NOTHING spent outside the span; the
##                click tick refused on both seats; the hit and landing ticks refused; a charging presser
##                hears `unblockable_committed`; a dropped touch keeps the span open; the reset ends it.
##   AC 10     -- the reward: +reward to the counter's defender, clamped at max; nothing else pays it.
##   AC 11     -- the knockdown breather: after any knockdown's get-up, an unblockable touch does nothing and
##                is not spent, a later touch in the same flight hits, melee hits normally, the countered
##                attacker gets it too, no get-up means no breather, the reset clears it, the key rests.
##
## FIXTURE SHAPE: `test_unblockable_honest_contact.gd`'s (24-tick chargeup, distinct per-colour launch
## spans, the reach fact pushed BY HAND through the real `push_contact` seam before each `advance()`), plus
## the four new knobs authored in-test with DISTINCT per-colour values so a lookup that read the wrong
## colour fails. In-test literals only (BC/R3): no authored feel knob is read.

const SEED := 7909
const DECK_SIZE := 8
const HAND_SIZE := 4
const MAX_HP := 100.0
const MAX_STAMINA := 60.0
const MAX_MANA := 10.0
const UNBLOCKABLE_COST := 20.0
const DEFENSE_COST := 10.0
const MANA_COST := 1.0
const COUNTER_REWARD := 1.0
const CHARGEUP_TICKS := 24
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const MELEE_DAMAGE := 6.0          # 6 % of 100.0 max hp
const REACH := 8.0
const ORB_GRANT := 2
const MAX_ORBS := 9
const COUNTER_BUSY_TICKS := 20
const KNOCKDOWN_TICKS := 40
const GET_UP_TICKS := 12
const IMMUNITY_TICKS := 10
const ROLL_IFRAME_TICKS := 12
const ROLL_TICKS := 30

const LAUNCH_TICKS := {
	Enums.CardColor.RED: 6,
	Enums.CardColor.BLUE: 9,
	Enums.CardColor.GREEN: 16,
}
const LAUNCH_DISTANCE := {
	Enums.CardColor.RED: 1.2,
	Enums.CardColor.BLUE: 1.8,
	Enums.CardColor.GREEN: 3.0,
}
## Distinct per colour, every one shorter than the busy span (the `7-9/R9` audit's order).
const LEAD_TICKS := {
	Enums.CardColor.RED: 8,
	Enums.CardColor.BLUE: 6,
	Enums.CardColor.GREEN: 10,
}
## Degrees per second: 2, 1 and 4 degrees per tick at 60 Hz -- GREEN most, BLUE least.
const TURN_RATE := {
	Enums.CardColor.RED: 120.0,
	Enums.CardColor.BLUE: 60.0,
	Enums.CardColor.GREEN: 240.0,
}

## The planar TARGET -> ATTACKER direction for a defender straight ahead of the attacker.
const DIR_AHEAD := Vector2(0.0, 1.0)
## A defender displaced a quarter turn: the pushed bearing swings 90 degrees off the committed heading.
const DIR_SIDE := Vector2(1.0, 0.0)


# --- AC 1: the price ---------------------------------------------------------------------------

## AC 1: with the cost in the pool, the click spends EXACTLY the mana cost and the unchanged stamina cost
## on that tick, and the card leaves the hand as today.
func test_the_click_spends_the_mana_and_the_stamina() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.RED)
		var attacker := _attacker(ms, slot)
		attacker.mana.add(1.5)
		_cast(ms, slot)
		assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING, "slot %d: the click committed" % slot)
		assert_almost_eq(attacker.mana.get_current(), 0.5, 0.0001,
			"slot %d: exactly the mana cost was spent at the click" % slot)
		assert_almost_eq(attacker.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST, 0.0001,
			"slot %d: ...and the unchanged stamina cost" % slot)
		assert_true(attacker.hand.is_slot_empty(0), "slot %d: ...and the card left the hand" % slot)
		assert_eq(attacker.discard.size(), 1, "slot %d: ...into the discard" % slot)


## AC 1: short of the mana cost the click is refused through the existing feedback, reason
## `insufficient_mana`, and the card, the hand, the stamina and the mana are all untouched.
##
## MUTATION (mana test): delete the `unblockable_mana_cost > get_current()` refusal and this goes RED --
## the click commits with half the cost in the pool.
func test_short_of_mana_the_click_is_refused_and_nothing_is_spent() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.RED)
		var attacker := _attacker(ms, slot)
		attacker.mana.add(0.5)
		var rejections := _collect_rejections(attacker)
		var card := attacker.hand.to_array()[0]
		_cast(ms, slot)
		assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
			"slot %d: refused with `insufficient_mana` on the existing channel" % slot)
		assert_ne(attacker.hero.action_state, HeroState.ActionState.CHARGING, "slot %d: nothing committed" % slot)
		assert_eq(attacker.hand.to_array()[0], card, "slot %d: the card is still in its slot" % slot)
		assert_eq(attacker.discard.size(), 0, "slot %d: ...nothing went to the discard" % slot)
		assert_almost_eq(attacker.mana.get_current(), 0.5, 0.0001, "slot %d: ...the mana is untouched" % slot)
		assert_almost_eq(attacker.stamina.get_current(), MAX_STAMINA, 0.0001,
			"slot %d: ...and so is the stamina" % slot)


## AC 1 (`7-9/R13`): short of BOTH pools, the reason is `insufficient_mana` -- mana is asked first -- and
## neither pool moves.
func test_short_of_both_pools_the_reason_is_mana() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	ms.p1.stamina.add(-(MAX_STAMINA - 5.0))
	var rejections := _collect_rejections(ms.p1)
	_cast(ms, 0)
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
		"short of mana AND stamina: the reason is `insufficient_mana`")
	assert_almost_eq(ms.p1.stamina.get_current(), 5.0, 0.0001, "...and the stamina is untouched")
	assert_eq(ms.p1.mana.get_current(), 0.0, "...and the mana too")


## AC 1, the stamina half under the new order: with the mana in hand but the stamina short, the refusal is
## the existing `insufficient_stamina`, and the MANA is not spent (the test precedes both spends).
func test_short_of_stamina_with_mana_in_hand_spends_no_mana() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	ms.p1.mana.add(MANA_COST)
	ms.p1.stamina.add(-(MAX_STAMINA - 5.0))
	var rejections := _collect_rejections(ms.p1)
	_cast(ms, 0)
	assert_eq(rejections, [[&"card_cast", &"insufficient_stamina"]], "refused on the stamina, as today")
	assert_almost_eq(ms.p1.mana.get_current(), MANA_COST, 0.0001,
		"...and the mana stays in the pool: nothing is spent on a refusal")


## `7-9/R16`: an unauthored mana cost (0) is free -- the click commits from an empty pool.
func test_a_zero_mana_cost_is_free() -> void:
	var c := _config()
	c.unblockable_mana_cost = 0.0
	var ms := _make_match(Enums.CardColor.RED, c)
	_cast(ms, 0)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "a zero cost commits from an empty pool")
	assert_eq(ms.p1.mana.get_current(), 0.0, "...and spends nothing")


# --- AC 2: no refund ---------------------------------------------------------------------------

## AC 2: the mana spent at the click stays spent whatever the attack's outcome -- countered, missed, or
## dodged through i-frames. (The immunity pass-through is pinned under AC 11.)
func test_the_mana_is_never_refunded() -> void:
	# Countered.
	var countered := _make_match(Enums.CardColor.RED)
	countered.p1.mana.add(MANA_COST)
	_cast_and_press(countered, 0, CHARGEUP_TICKS - 1)
	assert_eq(countered.p1.hero.action_state, HeroState.ActionState.STUNNED, "sanity: the attack was countered")
	assert_eq(countered.p1.mana.get_current(), 0.0, "countered: no refund")
	# Missed: nothing touches through the landing.
	var missed := _make_match(Enums.CardColor.RED)
	missed.p1.mana.add(MANA_COST)
	_cast(missed, 0)
	_fly_out(missed, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(missed.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: landed")
	assert_eq(missed.p2.hero.get_hp(), MAX_HP, "sanity: a miss")
	assert_eq(missed.p1.mana.get_current(), 0.0, "missed: no refund")
	# Dodged: the only touch falls inside the defender's roll i-frames.
	var dodged := _make_match(Enums.CardColor.GREEN)
	dodged.p1.mana.add(MANA_COST)
	_roll_into_the_commit(dodged, 0)
	_push(dodged, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(dodged, InputIntent.new(), InputIntent.new())
	assert_eq(dodged.p1.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED, "sanity: the touch was dropped")
	_fly_out(dodged, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(dodged.p2.hero.get_hp(), MAX_HP, "sanity: dodged")
	assert_eq(dodged.p1.mana.get_current(), 0.0, "dodged: no refund")


# --- AC 4: steering ----------------------------------------------------------------------------

## AC 4: the bearing swings a quarter turn at the commit and stays there. On every flight tick the facing
## turns toward it by EXACTLY the colour's per-tick angle until it is within one step, then sits on it; the
## launch velocity of every flight tick points along that tick's facing.
##
## MUTATION (steering seat): remove the `_steer_charge_facing` call and this goes RED -- the facing never
## leaves the committed heading.
func test_the_facing_turns_by_at_most_the_rate_and_the_travel_follows_it() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var attacker := _attacker(ms, slot)
		_cast_and_charge_dir(ms, slot, _ahead(slot))
		var step := _step_of(Enums.CardColor.GREEN)
		var bearing := -_side(slot)
		var turned_ticks := 0
		var reached := false
		var prev := attacker.hero.facing
		for _t in _launch(Enums.CardColor.GREEN):
			if attacker.hero.action_state != HeroState.ActionState.CHARGING:
				break
			_push_dir(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, _side(slot))
			_advance(ms, InputIntent.new(), InputIntent.new())
			if attacker.hero.action_state != HeroState.ActionState.CHARGING:
				break
			var now := attacker.hero.facing
			var turn := absf(prev.angle_to(now))
			assert_true(turn <= step + 0.000001,
				"slot %d: one flight tick turns at most the rate (%f > %f)" % [slot, turn, step])
			if not reached:
				assert_true(absf(now.angle_to(bearing)) < absf(prev.angle_to(bearing)),
					"slot %d: ...and toward the pushed bearing" % slot)
				if now.is_equal_approx(bearing):
					reached = true
				else:
					assert_almost_eq(turn, step, 0.000001, "slot %d: ...by exactly the rate while short of it" % slot)
					turned_ticks += 1
			var v := attacker.hero.velocity
			assert_true(Vector2(v.x, v.z).normalized().is_equal_approx(now.normalized()),
				"slot %d: the launch travel follows the steered facing" % slot)
			prev = now
		assert_true(turned_ticks >= 10, "slot %d: sanity -- the turn took many ticks (%d)" % [slot, turned_ticks])


## AC 4: a flight tick with NO pushed bearing keeps the facing -- the steering does not turn toward the
## stale bearing `_charge_reach_dirs` still holds.
##
## MUTATION (push flag): drop the `_charge_reach_pushed` early return and this goes RED -- the silent tick
## turns toward the previous tick's bearing.
func test_a_tick_with_no_pushed_bearing_keeps_the_facing() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_dir(ms, 0, DIR_AHEAD)
	_push_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	var turned := ms.p1.hero.facing
	assert_false(turned.is_equal_approx(-DIR_AHEAD), "sanity: a pushed tick turned the facing")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.hero.facing.is_equal_approx(turned), "a tick with no push keeps the facing")
	var v := ms.p1.hero.velocity
	assert_true(Vector2(v.x, v.z).normalized().is_equal_approx(turned.normalized()),
		"...and the launch still travels along it")


## AC 4: a bearing EXACTLY BEHIND turns in one fixed direction -- the positive rotation sense -- on both
## seats, whatever the sign of the zero the cross product comes out as.
##
## THE PAIRS ARE EXPLICIT SIGNED ZEROS, and that is the measured correction to the first draft (mutation
## M8 at the dev pass): a facing and a bearing that are each other's plain negation always cross to +0 in
## IEEE arithmetic, so a bare `atan2` answered +PI too and the draft passed against the mutant. The facing
## is set directly on the commit tick (the chargeup aim no longer writes it there) and the pushed bearing
## chosen so that pairs A and D cross to -0.0 -- where `atan2` alone answers -PI and would turn the other way.
##
## MUTATION (fixed sign): replace the `PI if cross == 0.0 and dot < 0.0` pin with a bare `atan2(cross, dot)`
## and pairs A and D go RED.
##
## THE NEGATIVE ZEROS ARE BUILT AT RUNTIME (`_negated`), a second measured correction: GDScript constant-
## folds a literal `-0.0` to +0.0, so a `Vector2(-0.0, ...)` written in source carries no sign at all and
## the pairs silently collapsed back to the +0 case. Each pair's cross sign is asserted as fixture, so the
## test cannot lose its negative zeros again without saying so.
func test_a_bearing_exactly_behind_turns_one_fixed_way() -> void:
	var nz := _negated(0.0)
	var pairs := [
		[Vector2(nz, -1.0), Vector2(0.0, -1.0), "A", true],
		[Vector2(0.0, -1.0), Vector2(0.0, -1.0), "B", false],
		[Vector2(1.0, 0.0), Vector2(1.0, 0.0), "C", false],
		[Vector2(1.0, nz), Vector2(1.0, 0.0), "D", true],
	]
	for slot: int in 2:
		for pair: Array in pairs:
			var ms := _make_match(Enums.CardColor.RED)
			var attacker := _attacker(ms, slot)
			_cast_and_charge_dir(ms, slot, _ahead(slot))
			var facing: Vector2 = pair[0]
			var pushed: Vector2 = pair[1]
			attacker.hero.facing = facing
			assert_true((-pushed).is_equal_approx(-facing), "fixture %s: the bearing is exactly behind" % pair[2])
			var cross := facing.cross(-pushed)
			assert_eq(1.0 / cross < 0.0, bool(pair[3]),
				"fixture %s: the cross product's zero carries the intended sign" % pair[2])
			_push_dir(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, pushed)
			_advance(ms, InputIntent.new(), InputIntent.new())
			assert_true(attacker.hero.facing.is_equal_approx(facing.rotated(_step_of(Enums.CardColor.RED))),
				"slot %d pair %s: a bearing exactly behind turns by +rate, never by a coin" % [slot, pair[2]])


## AC 4: GREEN > RED > BLUE comes from the CONFIG. Each colour's first flight tick turns by its own authored
## per-tick angle; with the config's numbers swapped round, the order swaps with them.
func test_the_colour_order_comes_from_the_config() -> void:
	var turns := {}
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		turns[color] = _first_flight_turn(_make_match(color))
		assert_almost_eq(float(turns[color]), _step_of(color), 0.000001,
			"colour %d turns by its own authored per-tick angle" % color)
	assert_true(float(turns[Enums.CardColor.GREEN]) > float(turns[Enums.CardColor.RED])
			and float(turns[Enums.CardColor.RED]) > float(turns[Enums.CardColor.BLUE]),
		"authored GREEN > RED > BLUE turns GREEN most and BLUE least")
	var inverted := _config()
	inverted.unblockable_turn_rate_degrees_per_second_blue = 240.0
	inverted.unblockable_turn_rate_degrees_per_second_green = 60.0
	var blue := _first_flight_turn(_make_match(Enums.CardColor.BLUE, inverted))
	var green := _first_flight_turn(_make_match(Enums.CardColor.GREEN, inverted))
	assert_true(blue > green, "with the numbers swapped, BLUE turns more than GREEN: the order is data")


## AC 4 / `7-9/R16`: a turn rate of 0 turns nothing -- the pre-7-9 frozen line, with the bearing a quarter
## turn off on every flight tick.
func test_a_zero_turn_rate_turns_nothing() -> void:
	var c := _config()
	c.unblockable_turn_rate_degrees_per_second_green = 0.0
	var ms := _make_match(Enums.CardColor.GREEN, c)
	_cast_and_charge_dir(ms, 0, DIR_AHEAD)
	var committed := ms.p1.hero.facing
	for _t in _launch(Enums.CardColor.GREEN) - 1:
		_push_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_true(ms.p1.hero.facing.is_equal_approx(committed), "a rate of 0 keeps the committed heading")


## `7-9/R3` (operator ruling at the code review, overriding AC 4's "to the landing"): THE STEERING ENDS AT
## THE FIRST TOUCH. The defender rolls so its i-frames cover the commit-tick touch, which is DROPPED (the
## attack keeps flying); on every later flight tick the pushed bearing swings a quarter turn, and the facing
## and the travel stay on the heading the touch left them -- a roll whose iframes cover the contact saves.
## Both seats. The control half is the same flight with NO touch: the same swing turns the facing, so the
## frozen heading above is the touch's doing, not the fixture's.
##
## MUTATION (first-touch stop): delete the `charge_contact != CHARGE_CONTACT_NONE` return in
## `_steer_charge_facing` and this goes RED -- the dropped-touch flight turns toward the swung bearing.
func test_a_touch_dropped_by_iframes_ends_the_steering() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var attacker := _attacker(ms, slot)
		_roll_into_the_commit(ms, slot)
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(attacker.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED,
			"slot %d: sanity: the commit-tick touch was dropped by the i-frames" % slot)
		var held := attacker.hero.facing
		var flown := 0
		for _t in _launch(Enums.CardColor.GREEN) - 2:
			_push_dir(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, _side(slot))
			_advance(ms, InputIntent.new(), InputIntent.new())
			if attacker.hero.action_state != HeroState.ActionState.CHARGING:
				break
			flown += 1
			assert_true(attacker.hero.facing.is_equal_approx(held),
				"slot %d: after the first touch the facing stays put despite the swung bearing" % slot)
			var v := attacker.hero.velocity
			assert_true(Vector2(v.x, v.z).normalized().is_equal_approx(held.normalized()),
				"slot %d: ...and the travel stays on that heading" % slot)
		assert_true(flown >= 10, "slot %d: sanity -- the flight kept going after the touch (%d ticks)" % [slot, flown])
		# Control: the same swing with no touch turns the facing on the first flight tick after the commit.
		var control := _make_match(Enums.CardColor.GREEN)
		var control_attacker := _attacker(control, slot)
		_roll_into_the_commit(control, slot)
		_push(control, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(control, InputIntent.new(), InputIntent.new())
		assert_eq(control_attacker.charge_contact, PlayerState.CHARGE_CONTACT_NONE, "slot %d: control: no touch" % slot)
		var before := control_attacker.hero.facing
		_push_dir(control, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, _side(slot))
		_advance(control, InputIntent.new(), InputIntent.new())
		assert_false(control_attacker.hero.facing.is_equal_approx(before),
			"slot %d: control: without a touch the same swung bearing DOES turn the facing" % slot)


# --- AC 5: reach and distance unchanged --------------------------------------------------------

## AC 5: with the path bending under the steering, the sum of the launch's per-tick travel is still the
## authored distance -- while the straight-line displacement is now SHORTER than it.
func test_the_path_length_is_the_authored_distance_when_the_path_bends() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_dir(ms, 0, DIR_AHEAD)
	var path := 0.0
	var displacement := Vector2.ZERO
	var flight_ticks := 0
	for _t in _launch(Enums.CardColor.GREEN) + 1:
		_push_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
		var step := Vector2(ms.p1.hero.velocity.x, ms.p1.hero.velocity.z) / TimingWindow.TICK_HZ
		path += step.length()
		displacement += step
		flight_ticks += 1
	assert_eq(flight_ticks, _launch(Enums.CardColor.GREEN), "sanity: every launch tick was summed")
	assert_almost_eq(path, float(LAUNCH_DISTANCE[Enums.CardColor.GREEN]), 0.0001,
		"the path length is the authored distance, bent or not")
	assert_true(displacement.length() < path - 0.01,
		"sanity: the path DID bend -- the displacement (%f) is shorter than the path" % displacement.length())


# --- AC 6: the counter window --------------------------------------------------------------------

## AC 6: a matching press exactly the colour's lead before the commit counters, and lands ON the commit
## tick; one tick earlier is too early -- the card and the stamina are spent and the commit-tick touch hits
## as if undefended. Per colour (distinct leads), both seats.
##
## MUTATION (press age): delete the lead comparison in `_resolve_color_counter` and the too-early half goes
## RED -- the older press counters.
func test_the_window_opens_the_lead_before_the_commit() -> void:
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		for slot: int in 2:
			var lead := int(LEAD_TICKS[color])
			# In time: pressed `lead` ticks before the commit.
			var ok := _make_match(color)
			var ok_attacker := _attacker(ok, slot)
			var counter_tick := _cast_and_press(ok, slot, CHARGEUP_TICKS - lead)
			assert_eq(ok_attacker.hero.action_state, HeroState.ActionState.STUNNED,
				"colour %d slot %d: pressed %d ticks before the commit -- countered" % [color, slot, lead])
			assert_eq(counter_tick, CHARGEUP_TICKS,
				"colour %d slot %d: ...and the counter landed ON the commit tick" % [color, slot])
			assert_eq(ok_attacker.hero.stun.duration_ticks(), KNOCKDOWN_TICKS,
				"colour %d slot %d: ...knocking the attacker down, as today" % [color, slot])
			assert_eq(_defender(ok, slot).hero.get_hp(), MAX_HP, "colour %d slot %d: ...defender undamaged" % [color, slot])
			assert_eq(ok_attacker.orbs.get_count(color), 0, "colour %d slot %d: ...no orb to the attacker" % [color, slot])
			# Too early: one tick older.
			var early := _make_match(color)
			var early_defender := _defender(early, slot)
			var early_tick := _cast_and_press(early, slot, CHARGEUP_TICKS - lead - 1,
					MatchState.CONTACT_CHARGE_REACH_INSIDE)
			assert_eq(early_tick, -1, "colour %d slot %d: one tick older is TOO EARLY -- no counter" % [color, slot])
			assert_true(early_defender.defense_window.duration_ticks() > 0,
				"colour %d slot %d: sanity -- the press was accepted (inside the R5 span)" % [color, slot])
			assert_eq(early_defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
				"colour %d slot %d: ...the touch hits as if undefended" % [color, slot])
			assert_true(early_defender.hand.is_slot_empty(0), "colour %d slot %d: ...the card is spent" % [color, slot])
			assert_almost_eq(early_defender.stamina.get_current(), MAX_STAMINA - DEFENSE_COST, 0.0001,
				"colour %d slot %d: ...and so is the stamina" % [color, slot])


## AC 6 / `7-9/R9`: "busy still running" stays the judgement's PRECONDITION. With a lead authored LONGER
## than the busy span, the busy span binds: a press `busy - 1` ticks before the commit (its window on its
## last running tick at the commit) counters on the commit tick, and a press `busy` ticks before (its
## window emptied at the commit's step 2) counters nothing -- though both are inside the lead. Both slots.
## The replacement for `test_unblockable_defense.gd`'s retired R-S6 boundary test.
func test_the_busy_span_stays_the_precondition() -> void:
	var c := _config()
	c.counter_lead_seconds_red = float(COUNTER_BUSY_TICKS + 4) / TimingWindow.TICK_HZ
	for slot: int in 2:
		var last := _make_match(Enums.CardColor.RED, c)
		assert_eq(_cast_and_press(last, slot, CHARGEUP_TICKS - (COUNTER_BUSY_TICKS - 1)), CHARGEUP_TICKS,
			"slot %d: the busy span's LAST running tick still counters, on the commit tick" % slot)
		var gone := _make_match(Enums.CardColor.RED, c)
		var gone_defender := _defender(gone, slot)
		assert_eq(_cast_and_press(gone, slot, CHARGEUP_TICKS - COUNTER_BUSY_TICKS,
				MatchState.CONTACT_CHARGE_REACH_INSIDE), -1,
			"slot %d: one tick older the busy span has emptied -- no counter, inside the lead or not" % slot)
		assert_eq(gone_defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
			"slot %d: ...so the commit-tick touch hits in full" % slot)


## AC 6: a matching press made AFTER the commit, before the first touch, still counters -- on the next
## tick, the first one its window is running for.
func test_a_press_in_flight_counters_before_the_first_touch() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var attacker := _attacker(ms, slot)
		_cast_and_charge(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance_with_defender(ms, slot, _defense_intent(0))
		assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING, "slot %d: sanity: pressed in flight" % slot)
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(attacker.hero.action_state, HeroState.ActionState.STUNNED,
			"slot %d: a press in flight counters on the next tick" % slot)


## AC 6: a press in ANOTHER colour, inside the window, never counters: the card is spent and the hit lands.
func test_a_wrong_colour_press_spends_the_card_and_the_hit_lands() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	ms.p1.mana.add(MANA_COST)
	_cast(ms, 0)
	ms.inject_card_colors(_colors(Enums.CardColor.BLUE))
	for t in CHARGEUP_TICKS:
		var p2_intent := _defense_intent(0) if t == CHARGEUP_TICKS - 3 else InputIntent.new()
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if t == CHARGEUP_TICKS - 1 \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		_push(ms, 0, kind)
		_advance(ms, InputIntent.new(), p2_intent)
	assert_eq(ms.p2.defense_color, Enums.CardColor.BLUE, "sanity: the defence was BLUE against a RED attack")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "a wrong colour never counters")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...the hit lands")
	assert_true(ms.p2.hand.is_slot_empty(0), "...and the card is spent")


## AC 6 / `7-9/R16`: a lead of 0 opens the window AT the commit -- a press one tick before it is too
## early, a press on the commit tick itself counters (judged on the next tick).
func test_a_zero_lead_opens_the_window_at_the_commit() -> void:
	var c := _config()
	c.counter_lead_seconds_red = 0.0
	var before := _make_match(Enums.CardColor.RED, c)
	assert_eq(_cast_and_press(before, 0, CHARGEUP_TICKS - 1), -1, "lead 0: a press before the commit is too early")
	var at := _make_match(Enums.CardColor.RED, c)
	var counter_tick := _cast_and_press(at, 0, CHARGEUP_TICKS)
	assert_eq(at.p1.hero.action_state, HeroState.ActionState.STUNNED, "lead 0: a press ON the commit tick counters")
	assert_eq(counter_tick, CHARGEUP_TICKS + 1, "...judged on the next tick")


# --- AC 7: the counter span ----------------------------------------------------------------------

## AC 7: a press on the tick of a DROPPED touch is legal (the attack is still flying, AC 9) and spends the
## card -- but it is never judged: the span closed at that first touch.
func test_a_press_on_a_dropped_touch_tick_is_spent_but_never_judged() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var attacker := _attacker(ms, slot)
		var defender := _defender(ms, slot)
		_roll_into_the_commit(ms, slot)
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance_with_defender(ms, slot, _defense_intent(1))
		assert_eq(attacker.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED, "slot %d: sanity: dropped touch" % slot)
		assert_true(defender.hand.is_slot_empty(1), "slot %d: the press was accepted and the card spent" % slot)
		for _t in 3:
			_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING,
			"slot %d: ...but it is never judged after the first touch" % slot)


# --- AC 8 / AC 9: defence legality -------------------------------------------------------------

## AC 8: a colour defence pressed with no opposing unblockable in flight is refused with the new token, and
## spends NOTHING: the card stays, the stamina and the mana are unchanged, and the hero is not busy.
##
## MUTATION (R5 gate): delete the `_defense_answerable_at_step6` refusal and this goes RED -- the press
## spends the card and the stamina and locks the hero busy.
func test_a_defence_with_nothing_to_answer_is_refused_and_spends_nothing() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.RED)
		var presser := _attacker(ms, slot)
		presser.mana.add(2.0)
		var rejections := _collect_rejections(presser)
		var card := presser.hand.to_array()[0]
		if slot == 0:
			_advance(ms, _defense_intent(0), InputIntent.new())
		else:
			_advance(ms, InputIntent.new(), _defense_intent(0))
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_NOTHING_TO_ANSWER]],
			"slot %d: refused with `nothing_to_answer`" % slot)
		assert_eq(presser.hand.to_array()[0], card, "slot %d: the card stays in hand" % slot)
		assert_eq(presser.discard.size(), 0, "slot %d: ...nothing discarded" % slot)
		assert_almost_eq(presser.stamina.get_current(), MAX_STAMINA, 0.0001, "slot %d: ...no stamina spent" % slot)
		assert_almost_eq(presser.mana.get_current(), 2.0, 0.0001, "slot %d: ...no mana spent" % slot)
		assert_false(presser.defense_window.is_running, "slot %d: ...and the hero is not locked busy" % slot)


## AC 8: a press on the very tick of the opponent's click is refused -- for BOTH seats alike.
func test_a_press_on_the_click_tick_is_refused_on_both_seats() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.RED)
		var attacker := _attacker(ms, slot)
		var defender := _defender(ms, slot)
		attacker.mana.add(MANA_COST)
		var rejections := _collect_rejections(defender)
		if slot == 0:
			_advance(ms, _unblockable_intent(0), _defense_intent(0))
		else:
			_advance(ms, _defense_intent(0), _unblockable_intent(0))
		assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING, "slot %d: sanity: the click committed" % slot)
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_NOTHING_TO_ANSWER]],
			"slot %d attacking: the same-tick press is refused" % slot)
		assert_false(defender.defense_window.is_running, "slot %d: ...and nothing armed" % slot)


## AC 8: a press on the tick the attack HITS is refused (the post-step-3 capture already sees the hit), and
## so is a press on the LANDING tick of a miss.
func test_a_press_on_the_hit_tick_or_the_landing_tick_is_refused() -> void:
	for slot: int in 2:
		# The hit tick: the commit-tick touch counts.
		var hit := _make_match(Enums.CardColor.RED)
		var hit_defender := _defender(hit, slot)
		_attacker(hit, slot).mana.add(MANA_COST)
		_cast(hit, slot)
		for _t in CHARGEUP_TICKS - 1:
			_push(hit, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			_advance(hit, InputIntent.new(), InputIntent.new())
		var hit_rejections := _collect_rejections(hit_defender)
		_push(hit, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance_with_defender(hit, slot, _defense_intent(0))
		assert_eq(hit_defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "slot %d: sanity: the touch hit" % slot)
		assert_eq(hit_rejections, [[&"card_cast", MatchState.REASON_NOTHING_TO_ANSWER]],
			"slot %d: a press on the hit tick is refused" % slot)
		# The landing tick of a miss.
		var land := _make_match(Enums.CardColor.RED)
		var land_attacker := _attacker(land, slot)
		var land_defender := _defender(land, slot)
		_cast_and_charge(land, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		for _t in _launch(Enums.CardColor.RED) - 1:
			_push(land, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			_advance(land, InputIntent.new(), InputIntent.new())
		assert_eq(land_attacker.hero.action_state, HeroState.ActionState.CHARGING, "slot %d: sanity: one flight tick left" % slot)
		var land_rejections := _collect_rejections(land_defender)
		_push(land, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance_with_defender(land, slot, _defense_intent(0))
		assert_eq(land_attacker.hero.action_state, HeroState.ActionState.IDLE, "slot %d: sanity: this was the landing tick" % slot)
		assert_eq(land_rejections, [[&"card_cast", MatchState.REASON_NOTHING_TO_ANSWER]],
			"slot %d: a press on the landing tick is refused" % slot)


## AC 8: a presser CHARGING its own unblockable is refused with `unblockable_committed`, as today -- the
## `CHARGING` gate answers before the new one, even with an opposing attack in flight.
func test_a_charging_presser_hears_unblockable_committed() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	ms.p1.mana.add(MANA_COST)
	ms.p2.mana.add(MANA_COST)
	_advance(ms, _unblockable_intent(0), _unblockable_intent(0))
	var rejections := _collect_rejections(ms.p2)
	_advance(ms, InputIntent.new(), _defense_intent(1))
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"a charging presser is refused with `unblockable_committed`")


## AC 9: the span is open from the tick after the click, stays open through a touch DROPPED by i-frames
## (the attack is still flying), and ends on a counted hit, on the landing, and on the debug reset.
func test_the_span_ends_on_hit_landing_and_reset_but_not_on_a_dropped_touch() -> void:
	# Open after the click, open through a dropped touch, closed by the later counted hit.
	var ms := _make_match(Enums.CardColor.GREEN)
	_roll_into_the_commit(ms, 0)
	assert_true(ms._defense_answerable_at_step6[1], "the span is open during the chargeup")
	_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED, "sanity: dropped touch")
	assert_true(ms._defense_answerable_at_step6[1], "a DROPPED touch does not end the span")
	for _t in _launch(Enums.CardColor.GREEN):
		if ms.p1.charge_contact == PlayerState.CHARGE_CONTACT_HIT:
			break
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_HIT, "sanity: a later touch hit")
	assert_false(ms._defense_answerable_at_step6[1], "the counted hit ends the span from its own tick")
	# The landing of a miss.
	var miss := _make_match(Enums.CardColor.RED)
	miss.p1.mana.add(MANA_COST)
	_cast(miss, 0)
	assert_eq(miss.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: committed")
	_fly_out(miss, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(miss.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: landed")
	assert_false(miss._defense_answerable_at_step6[1], "the landing ends the span")
	# The debug reset, mid-chargeup.
	var reset_ms := _make_match(Enums.CardColor.RED)
	reset_ms.p1.mana.add(MANA_COST)
	_cast(reset_ms, 0)
	_advance(reset_ms, InputIntent.new(), InputIntent.new())
	assert_true(reset_ms._defense_answerable_at_step6[1], "sanity: open")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(reset_ms, reset, InputIntent.new())
	assert_false(reset_ms._defense_answerable_at_step6[1], "the reset ends the span on its own tick")


## AC 9, the interruption ends. A COUNTER ends the span on its own tick: it lands at step 3, before the
## capture. A KNOCKDOWN of the charging attacker lands at step 6b, AFTER the capture (`7-9/R10`), so the span
## still reads open on the knockdown tick -- a same-tick press resolves first, the R-PRESS order -- and is
## closed from the next tick on. (The bolt stun at 6c and death at step 8 sit after the capture the same way;
## death also freezes the round, so no press follows it at all. The reset at step 1 is pinned above.)
func test_the_span_ends_on_a_counter_at_once_and_on_a_knockdown_from_the_next_tick() -> void:
	# The counter: P2 answers P1's attack.
	var countered := _make_match(Enums.CardColor.BLUE)
	_cast_and_press(countered, 0, CHARGEUP_TICKS - 2)
	assert_eq(countered.p1.hero.action_state, HeroState.ActionState.STUNNED, "sanity: countered on the last advance")
	assert_false(countered._defense_answerable_at_step6[1], "a counter ends the span on its own tick")
	# The knockdown: both commit on the same tick; only P2's touch counts, and its package knocks the
	# still-charging P1 down at step 6b.
	var ms := _make_match(Enums.CardColor.GREEN)
	ms.p1.mana.add(MANA_COST)
	ms.p2.mana.add(MANA_COST)
	_advance(ms, _unblockable_intent(0), _unblockable_intent(0))
	for _t in CHARGEUP_TICKS - 1:
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_push(ms, 1, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	_push(ms, 1, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "sanity: P1 was knocked down this tick")
	assert_eq(ms.p1.hero.stun.duration_ticks(), KNOCKDOWN_TICKS, "sanity: ...by the knockdown package")
	assert_true(ms._defense_answerable_at_step6[1],
		"on the knockdown tick the span still read open: the capture precedes the step-6b package")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms._defense_answerable_at_step6[1], "...and it is closed from the next tick on")


# --- AC 10: the reward -------------------------------------------------------------------------

## AC 10: a successful counter gives its defender the authored reward, clamped at the maximum (nothing when
## full); the attacker gets nothing back.
##
## MUTATION (reward): delete the `mana.add(counter_mana_reward)` line and this goes RED.
func test_a_successful_counter_pays_its_defender() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.BLUE)
		var defender := _defender(ms, slot)
		defender.mana.add(3.0)
		_cast_and_press(ms, slot, CHARGEUP_TICKS - 2)
		assert_eq(_attacker(ms, slot).hero.action_state, HeroState.ActionState.STUNNED, "slot %d: sanity: countered" % slot)
		assert_almost_eq(defender.mana.get_current(), 3.0 + COUNTER_REWARD, 0.0001,
			"slot %d: the defender gains the reward" % slot)
		assert_eq(_attacker(ms, slot).mana.get_current(), 0.0, "slot %d: ...the attacker nothing" % slot)
	var full := _make_match(Enums.CardColor.BLUE)
	full.p2.mana.add(MAX_MANA)
	_cast_and_press(full, 0, CHARGEUP_TICKS - 2)
	assert_eq(full.p1.hero.action_state, HeroState.ActionState.STUNNED, "sanity: countered at full mana")
	assert_eq(full.p2.mana.get_current(), MAX_MANA, "a full pool stays at its maximum")


## AC 10: nothing else pays it -- a roll through the attack and a plain miss leave the defender's mana where
## it was.
func test_a_roll_through_or_a_miss_pays_nothing() -> void:
	var rolled := _make_match(Enums.CardColor.GREEN)
	rolled.p2.mana.add(3.0)
	_roll_into_the_commit(rolled, 0)
	_fly_out(rolled, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(rolled.p2.hero.get_hp(), MAX_HP, "sanity: rolled through")
	assert_almost_eq(rolled.p2.mana.get_current(), 3.0, 0.0001, "a roll through pays nothing")
	var missed := _make_match(Enums.CardColor.RED)
	missed.p2.mana.add(3.0)
	missed.p1.mana.add(MANA_COST)
	_cast(missed, 0)
	assert_eq(missed.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: committed")
	_fly_out(missed, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_almost_eq(missed.p2.mana.get_current(), 3.0, 0.0001, "a miss pays nothing")


# --- AC 11: the knockdown breather ---------------------------------------------------------------

## AC 11: the victim of a hit gets up; the breather starts on the get-up close and lasts the authored
## length. A second unblockable timed so its whole flight overlaps the breather's end: every touch inside
## the breather does nothing (no damage, no knockdown, no orb) and does NOT spend the attack, and the first
## touch after the breather -- in the SAME flight -- hits in full. The mana of the dropped attack stays spent.
##
## MUTATION (contact seat): delete the `unblockable_immunity.is_running` branch in `_resolve_charge_contact`
## and this goes RED -- the first touch inside the breather hits.
func test_the_breather_drops_the_touch_and_a_later_touch_in_the_flight_hits() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var attacker := _attacker(ms, slot)
		var defender := _defender(ms, slot)
		attacker.mana.add(2.0 * MANA_COST)
		_cast_and_charge(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		assert_eq(defender.hero.stun.duration_ticks(), KNOCKDOWN_TICKS, "slot %d: sanity: the first hit knocked down" % slot)
		var hits := _collect_hits(ms)
		var r := _second_attack_into_the_breather(ms, slot)
		assert_true(int(r["dropped"]) >= 2, "slot %d: at least two flight touches fell inside the breather (%d)"
			% [slot, int(r["dropped"])])
		assert_eq(int(r["hp_before_hit"]), int(MAX_HP - UNBLOCKABLE_DAMAGE),
			"slot %d: every touch inside the breather did nothing" % slot)
		assert_false(bool(r["immune_on_hit_tick"]), "slot %d: the hit fell on the first tick after the breather" % slot)
		assert_eq(defender.hero.get_hp(), MAX_HP - 2.0 * UNBLOCKABLE_DAMAGE,
			"slot %d: ...and the later touch in the same flight hit in full" % slot)
		assert_eq(hits.size(), 1, "slot %d: one `hit_landed` for the second attack" % slot)
		assert_eq(attacker.orbs.get_count(Enums.CardColor.GREEN), 2 * ORB_GRANT,
			"slot %d: the dropped touches paid no orb; the hit paid one grant" % slot)
		assert_eq(attacker.mana.get_current(), 0.0, "slot %d: no refund for the dropped touches" % slot)


## AC 11: the breather's span. It starts on the tick the get-up iframes close and runs exactly the authored
## number of ticks; it is not an i-frame (`is_iframe_open()` stays false), so the melee drop and Honed Bolt
## never see it.
func test_the_breather_spans_the_authored_length_from_the_get_up_close() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	ms.p1.mana.add(MANA_COST)
	_cast_and_charge(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	var close_tick := -1
	var immune_ticks := 0
	for t in KNOCKDOWN_TICKS + GET_UP_TICKS + IMMUNITY_TICKS + 10:
		var was_getting_up := ms.p2.hero.is_getting_up()
		_advance(ms, InputIntent.new(), InputIntent.new())
		if was_getting_up and not ms.p2.hero.is_getting_up():
			close_tick = t
		if ms.p2.hero.unblockable_immunity.is_running:
			immune_ticks += 1
			assert_true(close_tick >= 0, "the breather never runs before the get-up close")
			if t > close_tick:
				assert_false(ms.p2.hero.is_iframe_open(), "the breather is not an i-frame")
	assert_true(close_tick >= 0, "sanity: the hero got up")
	assert_eq(immune_ticks, IMMUNITY_TICKS, "the breather runs exactly the authored length")
	assert_eq(int(ms.to_snapshot()["p2"]["hero"]["unblockable_immunity"]["elapsed_ticks"]), IMMUNITY_TICKS,
		"...and the hashed key reports the window that ran")


## AC 11: melee hits a hero inside the breather normally -- full damage, the ordinary hit.
func test_melee_hits_normally_inside_the_breather() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	ms.p1.mana.add(MANA_COST)
	_cast_and_charge(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_run_until(ms, func() -> bool: return ms.p2.hero.unblockable_immunity.is_running, 200)
	assert_true(ms.p2.hero.unblockable_immunity.is_running, "sanity: inside the breather")
	_advance(ms, _press(&"attack"), InputIntent.new())
	var hp := ms.p2.hero.get_hp()
	ms.push_contact([0, TargetingService.HERO_INDEX], [1, TargetingService.HERO_INDEX],
		ms.p1.hero.attack_index, -DIR_AHEAD, MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p2.hero.unblockable_immunity.is_running, "sanity: still inside the breather")
	assert_almost_eq(ms.p2.hero.get_hp(), hp - MELEE_DAMAGE, 0.0001, "a melee strike hits in full inside the breather")


## AC 11 (`7-9/R11`): ANY knockdown -- the attacker a counter knocked down gets the breather too, and an
## unblockable touching it there does nothing.
func test_the_countered_attacker_gets_the_breather_too() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_press(ms, 0, CHARGEUP_TICKS - 2)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "sanity: P1 was countered down")
	assert_eq(ms.p1.hero.stun.duration_ticks(), KNOCKDOWN_TICKS, "sanity: ...by a knockdown")
	# P2 now attacks the downed P1, timed so its commit falls inside P1's breather.
	ms.p2.mana.add(MANA_COST)
	var r := _second_attack_into_the_breather(ms, 1)
	assert_true(int(r["dropped"]) >= 2, "the countered attacker's breather dropped the touches (%d)" % int(r["dropped"]))
	assert_eq(int(r["hp_before_hit"]), int(MAX_HP), "...no damage to it while the breather ran")
	assert_false(bool(r["immune_on_hit_tick"]), "...and the hit fell after the breather")


## AC 11 / `7-9/R16`: with no get-up iframes authored there is no close tick, so no breather -- and an
## unauthored breather length (0) opens none either.
func test_no_get_up_or_a_zero_length_means_no_breather() -> void:
	for which: int in 2:
		var c := _config()
		if which == 0:
			c.get_up_iframe_seconds = 0.0
		else:
			c.unblockable_immunity_seconds = 0.0
		var ms := _make_match(Enums.CardColor.RED, c)
		ms.p1.mana.add(MANA_COST)
		_cast_and_charge(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		for _t in KNOCKDOWN_TICKS + GET_UP_TICKS + IMMUNITY_TICKS + 5:
			_advance(ms, InputIntent.new(), InputIntent.new())
			assert_false(ms.p2.hero.unblockable_immunity.is_running,
				"case %d: no breather ever runs" % which)


## AC 11: the debug reset stops a running breather (the eighth named exception), and the key rests at 0 on
## every hero before anything has happened.
func test_the_reset_clears_the_breather_and_the_key_rests() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	for p: String in ["p1", "p2"]:
		assert_eq(ms.to_snapshot()[p]["hero"]["unblockable_immunity"],
			{"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false} as Dictionary,
			"%s: the key rests at 0" % p)
	ms.p1.mana.add(MANA_COST)
	_cast_and_charge(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_run_until(ms, func() -> bool: return ms.p2.hero.unblockable_immunity.is_running, 200)
	assert_true(ms.p2.hero.unblockable_immunity.is_running, "sanity: inside the breather")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_false(ms.p2.hero.unblockable_immunity.is_running, "the reset stops the breather")


# --- helpers ----------------------------------------------------------------------------------

## After the first hit knocked the defender down, the attacker casts a second GREEN attack timed so its
## commit falls two ticks after the get-up close (inside the breather) and pushes INSIDE on every flight
## tick. Returns: dropped (touches processed while the breather ran), hp_before_hit, immune_on_hit_tick.
func _second_attack_into_the_breather(ms: MatchState, slot: int) -> Dictionary:
	var attacker := _attacker(ms, slot)
	var defender := _defender(ms, slot)
	# Let the first flight finish.
	_fly_out(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	attacker.stamina.refill()
	# Cast when the knockdown has 10 ticks left after the cast tick's step 2: it ends 10 ticks later, the
	# get-up runs GET_UP_TICKS more, so the breather opens at cast + 10 + GET_UP_TICKS = cast + 22 and the
	# commit (cast + CHARGEUP_TICKS = cast + 24) falls two ticks inside it.
	_run_until(ms, func() -> bool: return defender.hero.stun.remaining_ticks() == 11, 200)
	assert_eq(defender.hero.stun.remaining_ticks(), 11, "fixture: the cast tick is reachable")
	if slot == 0:
		_advance(ms, _unblockable_intent(1), InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), _unblockable_intent(1))
	assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING, "fixture: the second attack committed")
	for _t in CHARGEUP_TICKS - 1:
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	var out := {"dropped": 0, "hp_before_hit": defender.hero.get_hp(), "immune_on_hit_tick": true}
	for _t in _launch(Enums.CardColor.GREEN) + 1:
		if attacker.hero.action_state != HeroState.ActionState.CHARGING:
			break
		var hp := defender.hero.get_hp()
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if defender.hero.get_hp() < hp:
			out["hp_before_hit"] = hp
			out["immune_on_hit_tick"] = defender.hero.unblockable_immunity.is_running
			break
		if defender.hero.unblockable_immunity.is_running and not defender.hero.is_iframe_open():
			assert_eq(attacker.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED,
				"fixture: a touch inside the breather is dropped, the attack not spent")
			out["dropped"] = int(out["dropped"]) + 1
	return out


## `slot` casts; the defender presses a matching defence (hand slot 0) on post-cast tick `press_at`
## (1..CHARGEUP_TICKS, CHARGEUP_TICKS being the commit tick itself). The chargeup is pushed OUTSIDE; the
## commit tick pushes `commit_kind`. The flight then runs out OUTSIDE. Returns the post-cast tick on which
## the attacker was knocked down by the counter, or -1.
func _cast_and_press(ms: MatchState, slot: int, press_at: int,
		commit_kind: int = MatchState.CONTACT_CHARGE_REACH_OUTSIDE) -> int:
	var attacker := _attacker(ms, slot)
	if attacker.mana.get_current() < MANA_COST:
		attacker.mana.add(MANA_COST)
	_cast(ms, slot)
	var counter_tick := -1
	for t in range(1, CHARGEUP_TICKS + _launch(attacker.charge_color) + 1):
		if attacker.hero.action_state != HeroState.ActionState.CHARGING:
			break
		var kind := commit_kind if t == CHARGEUP_TICKS else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		_push(ms, slot, kind)
		_advance_with_defender(ms, slot, _defense_intent(0) if t == press_at else InputIntent.new())
		if counter_tick < 0 and attacker.hero.action_state == HeroState.ActionState.STUNNED:
			counter_tick = t
	return counter_tick


## The defender presses roll three ticks before the commit so its i-frames read open on the commit tick.
## The attacker is cast and charged to one tick short of the commit.
func _roll_into_the_commit(ms: MatchState, slot: int) -> void:
	var attacker := _attacker(ms, slot)
	if attacker.mana.get_current() < MANA_COST:
		attacker.mana.add(MANA_COST)
	_cast(ms, slot)
	for t in CHARGEUP_TICKS - 1:
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance_with_defender(ms, slot, _press(&"roll") if t == CHARGEUP_TICKS - 4 else InputIntent.new())
	assert_true(attacker.charge_window.is_running, "fixture: the commit is the next tick")


## Cast on `slot` (seeding the mana) and run the chargeup through the commit tick, pushing `kind`.
func _cast_and_charge(ms: MatchState, slot: int, kind: int) -> void:
	var attacker := _attacker(ms, slot)
	if attacker.mana.get_current() < MANA_COST:
		attacker.mana.add(MANA_COST)
	_cast(ms, slot)
	for _t in CHARGEUP_TICKS:
		_push(ms, slot, kind)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(attacker.charge_window.is_running, "fixture: committed")


## Cast on `slot` and run the chargeup to one tick BEFORE the commit with the bearing `dir`, so the facing
## is set by the chargeup aim and the NEXT advance is the commit tick (the first flight tick).
func _cast_and_charge_dir(ms: MatchState, slot: int, dir: Vector2) -> void:
	var attacker := _attacker(ms, slot)
	if attacker.mana.get_current() < MANA_COST:
		attacker.mana.add(MANA_COST)
	_cast(ms, slot)
	for _t in CHARGEUP_TICKS - 1:
		_push_dir(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, dir)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(attacker.charge_window.is_running, "fixture: the commit is the next tick")
	assert_true(attacker.hero.facing.is_equal_approx(-dir), "fixture: the chargeup aimed along the bearing")


## The first flight tick's turn, from a bearing ahead to one a quarter turn off.
func _first_flight_turn(ms: MatchState) -> float:
	_cast_and_charge_dir(ms, 0, DIR_AHEAD)
	var before := ms.p1.hero.facing
	_push_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	return absf(before.angle_to(ms.p1.hero.facing))


func _fly_out(ms: MatchState, slot: int, kind: int) -> void:
	var attacker := _attacker(ms, slot)
	for _t in CHARGEUP_TICKS + 20:
		if attacker.hero.action_state != HeroState.ActionState.CHARGING:
			return
		_push(ms, slot, kind)
		_advance(ms, InputIntent.new(), InputIntent.new())


func _run_until(ms: MatchState, done: Callable, max_ticks: int) -> void:
	for _t in max_ticks:
		if done.call():
			return
		_advance(ms, InputIntent.new(), InputIntent.new())


func _cast(ms: MatchState, slot: int) -> void:
	if slot == 0:
		_advance(ms, _unblockable_intent(0), InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), _unblockable_intent(0))


func _advance_with_defender(ms: MatchState, charging_slot: int, defender_intent: InputIntent) -> void:
	if charging_slot == 0:
		_advance(ms, InputIntent.new(), defender_intent)
	else:
		_advance(ms, defender_intent, InputIntent.new())


func _attacker(ms: MatchState, slot: int) -> PlayerState:
	return ms.p1 if slot == 0 else ms.p2


func _defender(ms: MatchState, slot: int) -> PlayerState:
	return ms.p2 if slot == 0 else ms.p1


func _ahead(slot: int) -> Vector2:
	return DIR_AHEAD if slot == 0 else -DIR_AHEAD


func _side(slot: int) -> Vector2:
	return DIR_SIDE if slot == 0 else -DIR_SIDE


## A runtime negation, so a negative zero survives (a source literal `-0.0` is folded to +0.0).
func _negated(v: float) -> float:
	return -v


func _step_of(color: int) -> float:
	return deg_to_rad(float(TURN_RATE[color])) / TimingWindow.TICK_HZ


func _launch(color: int) -> int:
	return int(LAUNCH_TICKS[color])


func _push(ms: MatchState, slot: int, kind: int) -> void:
	_push_dir(ms, slot, kind, _ahead(slot))


func _push_dir(ms: MatchState, slot: int, kind: int, dir: Vector2) -> void:
	var player := _attacker(ms, slot)
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, dir, kind)


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void: out.append([a, t, d, hp]))
	return out


func _collect_rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		out.append([action, reason]))
	return out


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


func _unblockable_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


func _defense_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.DEFENSE
	i.card_commit = true
	return i


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("tempo_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 3.0
		out[id] = c
	return out


func _colors(color: int) -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in _deck_contents():
		out[id] = color as Enums.CardColor
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = MAX_MANA
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 0.2
	c.roll_stamina_cost = 5.0
	c.attack_stamina_cost = 5.0
	c.deflect_stamina_cost = 5.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.1
	c.attack_recovery_seconds = 0.2
	c.attack_damage_percent_of_max_hp = MELEE_DAMAGE
	c.roll_duration_seconds = float(ROLL_TICKS) / TimingWindow.TICK_HZ
	c.roll_iframe_seconds = float(ROLL_IFRAME_TICKS) / TimingWindow.TICK_HZ
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.defense_stamina_cost = DEFENSE_COST
	c.counter_busy_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_red = float(LEAD_TICKS[Enums.CardColor.RED]) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_blue = float(LEAD_TICKS[Enums.CardColor.BLUE]) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_green = float(LEAD_TICKS[Enums.CardColor.GREEN]) / TimingWindow.TICK_HZ
	c.counter_mana_reward = COUNTER_REWARD
	c.knockdown_stun_seconds = float(KNOCKDOWN_TICKS) / TimingWindow.TICK_HZ
	c.get_up_iframe_seconds = float(GET_UP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_immunity_seconds = float(IMMUNITY_TICKS) / TimingWindow.TICK_HZ
	c.draw_replacement_delay_seconds = 0.5
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_mana_cost = MANA_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	c.unblockable_turn_rate_degrees_per_second_red = float(TURN_RATE[Enums.CardColor.RED])
	c.unblockable_turn_rate_degrees_per_second_blue = float(TURN_RATE[Enums.CardColor.BLUE])
	c.unblockable_turn_rate_degrees_per_second_green = float(TURN_RATE[Enums.CardColor.GREEN])
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		var span := float(_launch(color)) / TimingWindow.TICK_HZ
		var dist := float(LAUNCH_DISTANCE[color])
		match color:
			Enums.CardColor.RED:
				c.unblockable_launch_seconds_red = span
				c.unblockable_launch_distance_red = dist
			Enums.CardColor.BLUE:
				c.unblockable_launch_seconds_blue = span
				c.unblockable_launch_distance_blue = dist
			_:
				c.unblockable_launch_seconds_green = span
				c.unblockable_launch_distance_green = dist
	return c


func _make_match(color: int, config: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(config if config != null else _config())
	var f := FeatureFlags.new()
	f.unblockable = true
	f.orbs = true
	ms.inject_feature_flags(f)
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors(color))
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	return ms


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
