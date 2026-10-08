extends TestCase

## Story 7-8: UNBLOCKABLE HONEST CONTACT -- the headless half of the new resolution rules.
##
## WHAT THIS FILE PINS, AC by AC:
##   AC 1/AC 4 -- the hit lands on the tick the touch is processed, mid-flight: damage, the victim's
##                knockdown, `hit_landed` and the attacker's one-orb grant all on that tick, never later.
##   AC 3      -- at most one hit per unblockable: every later flight tick touching changes nothing, the
##                attacker finishes its flight in `CHARGING` and returns to IDLE on the landing tick.
##   AC 7      -- a touch while the defender's i-frames are open does nothing, does not spend the
##                attack, and neither consumes nor shortens the i-frame window.
##   AC 8      -- a blade still touching on the first tick the i-frames read closed hits there, in full;
##                an i-frame touch followed by no counted touch is a MISS (the latch is not absorbing).
##   AC 9      -- the dodge rule is identical on both seats.
##   AC 10     -- the colour counter's span ends at the FIRST touch, counted or dropped.
##   `7-8/R15` -- the hashed hit-once key (`charge_contact`): its values and its rest.
##   `7-8/R16` -- a lethal mid-flight hit leaves the attacker CHARGING under the round-over freeze until
##                the reset.
##
## FIXTURE SHAPE: `test_unblockable_tracking_and_reach.gd`'s (24-tick chargeup, distinct per-colour
## launch spans) plus an authored roll and an open orb layer. The reach fact is pushed BY HAND through
## the real `push_contact` seam before each `advance()`, exactly as the runner does in frame step 2 --
## this file drives no runner, so the touch on each tick is the fixture's choice. In-test literals only
## (BC/R3): no authored feel knob is read.

const SEED := 7808
const DECK_SIZE := 8
const HAND_SIZE := 4
const MAX_HP := 100.0
const MAX_STAMINA := 40.0
const UNBLOCKABLE_COST := 20.0
const CHARGEUP_TICKS := 24
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0
const ORB_GRANT := 2
const MAX_ORBS := 9
const COUNTER_BUSY_TICKS := 20
const KNOCKDOWN_TICKS := 40
## A roll whose i-frames (12 ticks) are shorter than GREEN's 16-tick launch, so a roll pressed just
## before the commit opens over the first touches of the flight and closes with flight still to run.
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

## The planar TARGET -> ATTACKER direction for a defender straight ahead of the attacker.
const DIR_AHEAD := Vector2(0.0, 1.0)


# --- AC 1 / AC 4: the hit lands on the touch tick -----------------------------------------------

## AC 1/AC 4: the ONLY touch of the attack falls on launch tick 5 of GREEN's 16. On every tick before it
## nothing has happened; ON it the damage, the knockdown, the one `hit_landed` and the orb grant all
## land -- with ten flight ticks still to run, so "at the landing" cannot be what decided it.
func test_the_hit_lands_on_the_touch_tick_mid_flight() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	var hits := _collect_hits(ms)
	_cast_and_charge_kind(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for t in 4:
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(ms.p2.hero.get_hp(), MAX_HP, "launch tick %d: no touch yet, nothing landed" % (t + 1))
	assert_eq(hits.size(), 0, "sanity: nothing emitted before the touch")
	_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.landing_window.remaining_ticks() >= 10,
		"sanity: the touch falls mid-flight, %d launch ticks still to run"
			% ms.p1.landing_window.remaining_ticks())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "the damage lands ON the touch tick")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "...the victim is knocked down...")
	assert_eq(ms.p2.hero.stun.duration_ticks(), KNOCKDOWN_TICKS, "...with the knockdown package...")
	assert_eq(hits.size(), 1, "...one `hit_landed`...")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), ORB_GRANT, "...and the attacker's orb grant")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"the attacker is still in its flight -- the hit writes no attacker state (OQ2)")


# --- AC 3: at most one hit ----------------------------------------------------------------------

## AC 3: the blade touches on EVERY tick from the commit through the landing. Exactly one damage
## instalment, one `hit_landed`, one orb grant; the attacker stays CHARGING to the authored landing
## tick and leaves it there to IDLE; the hit-once key reads HIT for the rest of the flight.
##
## MUTATION (hit-once key): drop the `charge_contact != HIT` conjunct in the CHARGING arm and this goes
## RED -- the second touch hits again (a second damage instalment and a second grant).
func test_an_unblockable_hits_at_most_once() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	var hits := _collect_hits(ms)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var landing_tick := -1
	for t in range(1, CHARGEUP_TICKS + _launch(Enums.CardColor.BLUE) + 3):
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if t > CHARGEUP_TICKS and ms.p1.hero.action_state == HeroState.ActionState.CHARGING:
			assert_eq(ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_HIT,
				"tick %d: the hit-once memory holds for the rest of the flight" % t)
		if landing_tick < 0 and ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			landing_tick = t
	assert_eq(landing_tick, CHARGEUP_TICKS + _launch(Enums.CardColor.BLUE),
		"the attacker finishes its motion and leaves CHARGING on the authored landing tick")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "...to IDLE, as today")
	assert_eq(hits.size(), 1, "%d touching ticks, exactly ONE `hit_landed`"
		% (_launch(Enums.CardColor.BLUE) + 1))
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...ONE damage instalment...")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.BLUE), ORB_GRANT, "...and ONE orb grant")
	assert_eq(ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_NONE, "the key rests after the landing")


# --- AC 7 / AC 8 / AC 9: the dodge is judged on the touch tick ---------------------------------

## AC 7 + AC 8 (the hit half): the defender rolls just before the commit and the blade touches on EVERY
## flight tick. Each touch while `_iframe_open_at_step3` reads open is dropped -- nothing lands, the
## attack is not spent (the key reads TOUCHED, not HIT) -- and the hit lands IN FULL on exactly the first
## tick the predicate reads closed, with flight still to run.
##
## MUTATION (i-frame drop): delete the `_iframe_open_at_step3` early return in `_resolve_charge_contact`
## and this goes RED -- the commit-tick touch, inside the open i-frames, hits.
func test_a_touch_during_iframes_is_dropped_and_the_first_closed_tick_hits() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var hits := _collect_hits(ms)
		var r := _drop_then_touch(ms, slot, true)
		var defender: PlayerState = ms.p2 if slot == 0 else ms.p1
		var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
		assert_true(int(r["dropped"]) >= 2,
			"slot %d: sanity -- at least two flight touches fell inside the open i-frames (%d)"
				% [slot, int(r["dropped"])])
		assert_true(int(r["hit_tick"]) > 0, "slot %d: a hit landed once the i-frames closed" % slot)
		assert_true(int(r["hit_tick"]) < CHARGEUP_TICKS + _launch(Enums.CardColor.GREEN),
			"slot %d: sanity -- the closing tick fell inside the flight, not on the landing" % slot)
		assert_false(bool(r["open_on_hit_tick"]),
			"slot %d: the hit tick is the FIRST tick the predicate read CLOSED" % slot)
		assert_eq(int(r["hp_before_hit"]), int(MAX_HP),
			"slot %d: every touch inside the open i-frames did nothing (AC 7)" % slot)
		assert_eq(defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
			"slot %d: ...and the first closed-tick touch lands IN FULL (AC 8)" % slot)
		assert_eq(hits.size(), 1, "slot %d: ...one `hit_landed`" % slot)
		assert_eq(attacker.orbs.get_count(Enums.CardColor.GREEN), ORB_GRANT,
			"slot %d: ...and the orb grant the dropped touches never paid" % slot)


## AC 7: the dropped touches neither consume nor shorten the roll's i-frame window. Compared against a
## control that rolls the same way and is never touched: the predicate reads open for EXACTLY as many
## ticks in both, because the touch only READS it.
func test_dropped_touches_neither_consume_nor_shorten_the_iframes() -> void:
	var touched := _make_match(Enums.CardColor.GREEN)
	var t := _drop_then_touch(touched, 0, true)
	var control := _make_match(Enums.CardColor.GREEN)
	var c := _drop_then_touch(control, 0, false)
	assert_true(int(t["open_ticks"]) > 0, "sanity: the i-frames were open during the flight")
	assert_eq(int(t["open_ticks"]), int(c["open_ticks"]),
		"the i-frame predicate read open for the same %d ticks touched or untouched (AC 7)"
			% int(c["open_ticks"]))
	assert_eq(control.p2.hero.get_hp(), MAX_HP, "sanity: the control was never touched")


## AC 8 (the miss half, R10): the blade touches the rolling defender ONLY while the i-frames are open and
## is clear on every later tick through the landing -- no later counted touch follows. A MISS: the
## earlier open-frame touch is not remembered as a touch.
##
## MUTATION (absorbing latch): make `push_contact` keep `INSIDE` once written within the window (the 6-1d
## latch) and this goes RED -- the stale `INSIDE` is read on the first closed tick and hits.
func test_an_iframe_touch_then_clear_is_a_miss() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		var hits := _collect_hits(ms)
		var defender: PlayerState = ms.p2 if slot == 0 else ms.p1
		var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
		_roll_into_the_commit(ms, slot)
		# The commit tick: touched, inside the open i-frames.
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance_slot(ms, slot, InputIntent.new())
		assert_true(ms._iframe_open_at_step3[1 - slot], "slot %d: sanity -- the touch fell inside the i-frames" % slot)
		assert_eq(attacker.charge_contact, PlayerState.CHARGE_CONTACT_TOUCHED,
			"slot %d: sanity -- the touch registered and was dropped" % slot)
		for _t in _launch(Enums.CardColor.GREEN):
			_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			_advance_slot(ms, slot, InputIntent.new())
		assert_eq(attacker.hero.action_state, HeroState.ActionState.IDLE, "slot %d: sanity -- landed" % slot)
		assert_eq(defender.hero.get_hp(), MAX_HP,
			"slot %d: an i-frame touch then clear is a MISS -- not remembered (AC 8)" % slot)
		assert_eq(hits.size(), 0, "slot %d: ...no `hit_landed`" % slot)
		assert_eq(attacker.orbs.get_count(Enums.CardColor.GREEN), 0, "slot %d: ...no orb" % slot)


## AC 9: SEAT SYMMETRY. The drop-then-hit case resolves on the SAME tick relative to the cast whichever
## slot charges -- the predicate is the step-3 capture, read once per tick for both seats.
func test_the_touch_tick_dodge_is_identical_on_both_seats() -> void:
	var results: Array = []
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.GREEN)
		results.append(_drop_then_touch(ms, slot, true))
	assert_eq(int(results[0]["hit_tick"]), int(results[1]["hit_tick"]),
		"slot 0 and slot 1 land the hit on the same tick after the cast (AC 9)")
	assert_eq(int(results[0]["dropped"]), int(results[1]["dropped"]),
		"...after dropping the same number of touches")


# --- AC 10: the counter span ends at the FIRST touch ---------------------------------------------

## AC 10 / `7-8/R13`: a touch DROPPED by i-frames closes the colour counter's span exactly as a counted
## one does. A matching counter window armed AFTER the dropped touch does not answer -- while the same
## window, in a paired control whose flight had no touch at that tick, does.
##
## MUTATION (span): make the dropped touch leave `charge_contact` at NONE and this goes RED -- the counter
## lands after the attack's first touch.
func test_a_dropped_touch_closes_the_counter_span() -> void:
	for slot: int in 2:
		for touched: bool in [true, false]:
			var ms := _make_match(Enums.CardColor.BLUE)
			var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
			var defender: PlayerState = ms.p2 if slot == 0 else ms.p1
			_roll_into_the_commit(ms, slot)
			var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if touched \
					else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
			_push(ms, slot, kind)
			_advance(ms, InputIntent.new(), InputIntent.new())
			assert_eq(defender.hero.get_hp(), MAX_HP, "slot %d: sanity: nothing landed at the commit" % slot)
			# A matching counter armed now, judged on the next tick with no touch on it.
			defender.defense_window.start(COUNTER_BUSY_TICKS)
			defender.defense_color = Enums.CardColor.BLUE
			_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			_advance(ms, InputIntent.new(), InputIntent.new())
			if touched:
				assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING,
					"slot %d: after a DROPPED touch the counter is never judged again for this attack (AC 10)" % slot)
			else:
				assert_eq(attacker.hero.action_state, HeroState.ActionState.STUNNED,
					"slot %d: control: with no touch yet the same window counters and knocks the attacker down" % slot)


## AC 10, the counted half: after the hit lands the counter is never judged again for that attack.
func test_no_counter_after_the_hit_landed() -> void:
	for slot: int in 2:
		var ms := _make_match(Enums.CardColor.RED)
		var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
		var defender: PlayerState = ms.p2 if slot == 0 else ms.p1
		_cast_and_charge_kind(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		assert_eq(defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
			"slot %d: sanity: the commit-tick touch hit" % slot)
		defender.defense_window.start(COUNTER_BUSY_TICKS)
		defender.defense_color = Enums.CardColor.RED
		defender.hero.stun.start(0)
		defender.hero.set_action_state(HeroState.ActionState.IDLE)
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(attacker.hero.action_state, HeroState.ActionState.CHARGING,
			"slot %d: a matching window after the hit answers nothing -- the span closed at the first touch" % slot)


# --- `7-8/R15`: the hashed hit-once key ------------------------------------------------------------

## The `charge_contact` per-player key: rests at 0, reads TOUCHED after a dropped touch and HIT after a
## counted one, and rests again at the landing exit and at the debug reset. (The knockdown-abandonment
## rest is pinned in `test_unblockable_defense.gd`'s `test_knockdown_from_charging_abandons_the_chargeup_
## and_keeps_the_spend`.)
func test_the_charge_contact_key_reports_and_rests() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	assert_eq(int(ms.to_snapshot()["p1"]["charge_contact"]), 0, "rest value before any cast")
	_roll_into_the_commit(ms, 0)
	_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["charge_contact"]), PlayerState.CHARGE_CONTACT_TOUCHED,
		"a dropped touch reads TOUCHED")
	for _t in 40:
		if ms.p1.charge_contact == PlayerState.CHARGE_CONTACT_HIT \
				or ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["charge_contact"]), PlayerState.CHARGE_CONTACT_HIT,
		"a later counted touch moves it from TOUCHED to HIT")
	for _t in 40:
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["charge_contact"]), 0, "the landing exit rests it")
	# The debug reset, mid-flight after a hit.
	var reset_ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(reset_ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(reset_ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_HIT, "sanity: hit at the commit")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(reset_ms, reset, InputIntent.new())
	assert_eq(int(reset_ms.to_snapshot()["p1"]["charge_contact"]), 0, "the debug reset rests it")


# --- `7-8/R16`: a lethal mid-flight hit --------------------------------------------------------------

## `7-8/R16`: a lethal touch mid-flight ends the round; the attacker is left CHARGING, held mid-motion
## by the round-over freeze, until the debug reset ends the attack.
func test_a_lethal_mid_flight_hit_leaves_the_attacker_frozen_in_its_flight() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	ms.p2.hero.take_damage(MAX_HP - UNBLOCKABLE_DAMAGE * 0.5)
	_push(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "the touch was lethal")
	assert_true(bool(ms.to_snapshot()["round_over"]), "...and ended the round")
	for _t in _launch(Enums.CardColor.GREEN) + 4:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"the attacker is held in CHARGING by the round-over freeze (R16, accepted)")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the reset ends the frozen attack")
	assert_eq(ms.p1.charge_contact, PlayerState.CHARGE_CONTACT_NONE, "...and rests its key")


# --- helpers ----------------------------------------------------------------------------------

## Defender presses roll so its i-frames open over the commit, then the attacker's flight is driven out
## with `touch` (INSIDE every tick, or OUTSIDE every tick as a control). Returns:
##   dropped          -- touches processed while `_iframe_open_at_step3` read open
##   hit_tick         -- ticks after the cast on which the hit landed (-1 if none)
##   open_on_hit_tick -- the predicate's value on the hit tick
##   hp_before_hit    -- the defender's hp on the tick before the hit
##   open_ticks       -- flight ticks on which the predicate read open
func _drop_then_touch(ms: MatchState, slot: int, touch: bool) -> Dictionary:
	var defender: PlayerState = ms.p2 if slot == 0 else ms.p1
	var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
	var since_cast := _roll_into_the_commit(ms, slot)
	var out := {"dropped": 0, "hit_tick": -1, "open_on_hit_tick": true, "hp_before_hit": MAX_HP,
			"open_ticks": 0}
	for _t in _launch(Enums.CardColor.GREEN) + 1:
		if attacker.hero.action_state != HeroState.ActionState.CHARGING:
			break
		var hp := defender.hero.get_hp()
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_INSIDE if touch \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance_slot(ms, slot, InputIntent.new())
		since_cast += 1
		var open: bool = ms._iframe_open_at_step3[1 - slot]
		if open:
			out["open_ticks"] = int(out["open_ticks"]) + 1
		if defender.hero.get_hp() < hp and int(out["hit_tick"]) < 0:
			out["hit_tick"] = since_cast
			out["open_on_hit_tick"] = open
			out["hp_before_hit"] = hp
		elif touch and open and int(out["hit_tick"]) < 0:
			out["dropped"] = int(out["dropped"]) + 1
	return out


## `slot` casts and runs its chargeup with NO touch to one tick short of the commit; the defender presses
## roll three ticks before the commit, so its i-frames read open on the commit tick. Returns the ticks
## elapsed since the cast tick.
func _roll_into_the_commit(ms: MatchState, slot: int) -> int:
	if slot == 0:
		_advance(ms, _unblockable_intent(0), InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), _unblockable_intent(0))
	var ticks := 0
	for t in CHARGEUP_TICKS - 1:
		_push(ms, slot, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		var defender_intent := _press(&"roll") if t == CHARGEUP_TICKS - 4 else InputIntent.new()
		_advance_slot(ms, slot, defender_intent)
		ticks += 1
	var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
	assert_true(attacker.charge_window.is_running, "fixture: the commit is the next tick")
	return ticks


## Cast on `slot` and run the chargeup out to (and including) the commit tick, pushing `kind` on every tick.
func _cast_and_charge_kind(ms: MatchState, slot: int, kind: int) -> void:
	if slot == 0:
		_advance(ms, _unblockable_intent(0), InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), _unblockable_intent(0))
	for _t in CHARGEUP_TICKS:
		_push(ms, slot, kind)
		_advance(ms, InputIntent.new(), InputIntent.new())
	var attacker: PlayerState = ms.p1 if slot == 0 else ms.p2
	assert_false(attacker.charge_window.is_running, "fixture: committed")


## Advance with the DEFENDER of a `charging_slot` attack sending `defender_intent`; the attacker is bare.
func _advance_slot(ms: MatchState, charging_slot: int, defender_intent: InputIntent) -> void:
	if charging_slot == 0:
		_advance(ms, InputIntent.new(), defender_intent)
	else:
		_advance(ms, defender_intent, InputIntent.new())


func _launch(color: int) -> int:
	return int(LAUNCH_TICKS[color])


func _push(ms: MatchState, slot: int, kind: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	var dir := DIR_AHEAD if slot == 0 else -DIR_AHEAD
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, dir, kind)


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void: out.append([a, t, d, hp]))
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


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("hc_card_%02d" % i))
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
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 6.0
	c.stamina_regen_delay_seconds = 0.2
	c.roll_stamina_cost = 5.0
	c.attack_stamina_cost = 5.0
	c.deflect_stamina_cost = 5.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.1
	c.attack_recovery_seconds = 0.2
	c.roll_duration_seconds = float(ROLL_TICKS) / TimingWindow.TICK_HZ
	c.roll_iframe_seconds = float(ROLL_IFRAME_TICKS) / TimingWindow.TICK_HZ
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.counter_busy_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.knockdown_stun_seconds = float(KNOCKDOWN_TICKS) / TimingWindow.TICK_HZ
	c.get_up_iframe_seconds = 0.2
	c.draw_replacement_delay_seconds = 0.5
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
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


func _make_match(color: int) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
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
