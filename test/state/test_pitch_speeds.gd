extends TestCase

## Story 7-4 (AC 1/AC 3-11): PITCH SPEEDS -- instant and sorcery -- through the real ordered dispatch.
##
## An INSTANT is READY as soon as the bank holds its orb price (the 6-2/6-3a rule, unchanged). A SORCERY
## counts only orbs EARNED while it sits in the zone (`PitchState._fresh_orbs`, credited at the one orb faucet,
## `MatchState._grant_landing_orbs`), and is READY when those cover the price AND the bank still does.
##
## Fixture shape: the `test_pitch_changed.gd` landing fixture (a real unblockable landing through
## `push_contact`), with the numbers moved to the story's own examples -- grant 1, cap 5, price red 1 -- so
## AC 7's "bank 3 -> 4 -> 3" and "bank 5 -> 5 -> 4" are asserted literally. Deck colours ALTERNATE red/blue
## so a landing of either colour can be cast from the dealt hand (`_hand_slot_of` finds it, and fails the
## fixture loudly if the seeded deal ever stops holding it). Every config, flag set and cost map is built
## IN-TEST -- the authored .tres files never reach here (`BC/R3`).

const SEED := 7474
const DECK_SIZE := 8
const HAND_SIZE := 4
const START_MANA := 20.0
const PITCH_MANA := 2.0
const TIMER_TICKS := 40
const DELAY_TICKS := 3
const CHARGEUP_TICKS := 4
const ORB_GRANT := 1
const MAX_ORBS := 5
const REACH := 8.0
const FACT_DIR := Vector2(0.0, 1.0)
## Ticks a cast gets to land before the helper gives up: the chargeup plus a margin for the flight.
const LAND_BUDGET_TICKS := CHARGEUP_TICKS + 8

var _hits: Array = []


# --- S2 INSTANT (AC 4) ---------------------------------------------------------------------------

func test_an_instant_staged_while_the_bank_holds_its_price_is_ready_and_spends_exactly_the_price() -> void:
	var ms := _make_match(Enums.PitchSpeed.INSTANT)
	ms.p1.orbs.add(Enums.CardColor.RED, 3)
	ms.drain_signals()
	var slot := _first_card_slot(ms)
	var id: StringName = ms.p1.hand.to_array()[slot]
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "sanity: staged")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags, false), "an instant is READY on its staging tick")
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [], "the activation is not refused")
	assert_false(ms.pitch.is_staged(0), "...it resolved and left the zone")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2, "...spending EXACTLY the price: 3 - 1 = 2")
	assert_true(ms.p1.discard.to_array().has(id), "...into the discard")


func test_an_instant_never_counts_fresh_orbs_even_when_one_is_earned_while_it_waits() -> void:
	var ms := _make_match(Enums.PitchSpeed.INSTANT, {Enums.CardColor.RED: 3})
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.RED), "a red unblockable landed while the instant waited")
	assert_eq(ms.pitch.fresh_orbs(0), {}, "the fresh count is credited ONLY for a sorcery")
	assert_eq(ms.to_snapshot()["pitch"]["p1"]["fresh_orbs"], {"red": 0, "blue": 0, "green": 0},
		"...so an instant's hashed zone carries resting zeros")


# --- S3 SORCERY (AC 5-7) -------------------------------------------------------------------------

func test_a_sorcery_staged_while_the_bank_already_holds_its_price_is_not_ready_and_refused() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	ms.p1.orbs.add(Enums.CardColor.RED, 3)
	ms.drain_signals()
	var slot := _first_card_slot(ms)
	var id: StringName = ms.p1.hand.to_array()[slot]
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "sanity: staged")
	var mana_before := ms.p1.mana.get_current()
	var hand_before: Array = ms.p1.hand.to_array()
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_NOT_READY]],
		"banked orbs do not count: the EXISTING not-ready refusal (AC 5)")
	assert_true(ms.pitch.is_staged(0), "...the card is still staged")
	assert_eq(ms.pitch.staged_card_id(0), id, "...the same card")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 3, "...no orb spent")
	assert_almost_eq(ms.p1.mana.get_current(), mana_before, 0.0001, "...no mana moved")
	assert_eq(ms.p1.hand.to_array(), hand_before, "...nothing else staged from the hand")
	assert_false(ms.p1.discard.to_array().has(id), "...and nothing discarded")


func test_an_earned_orb_of_the_priced_colour_makes_a_sorcery_ready_on_the_landing_tick() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_false(_sorcery_ready(ms), "staged with nothing earned: not READY")
	var cast_slot := _hand_slot_of(ms, Enums.CardColor.RED)
	_advance(ms, _unblockable_intent(cast_slot), InputIntent.new())
	var ready_on := -1
	for _t in LAND_BUDGET_TICKS:
		assert_false(_sorcery_ready(ms), "not READY before the landing (tick %d)" % _tick_of(ms))
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if not _hits.is_empty():
			ready_on = _tick_of(ms)
			break
	assert_true(ready_on > 0, "the unblockable landed (non-vacuity)")
	assert_true(_sorcery_ready(ms), "READY on the tick the earned orb covered the price (AC 6)")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.RED: 1}, "...one red earned since staging")


func test_an_orb_of_a_colour_the_price_does_not_name_never_counts() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	var slot := _spare(ms, Enums.CardColor.BLUE)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.BLUE), "a BLUE unblockable landed while a red-priced sorcery waits")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.BLUE), 1, "sanity: the blue orb was banked")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.BLUE: 1}, "...and counted as earned blue")
	assert_false(_sorcery_ready(ms), "...but blue never covers a red price: NOT READY")
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_NOT_READY]], "...activation refused")


## AC 6's same-tick clause: within ONE tick the hit resolves at step 3 (banking the orb) before step 6 stages
## the card, so an orb granted on the staging tick was banked FIRST and never counts. Reachable only when the
## first counted touch falls on the attacker's LANDING tick -- staging is refused while CHARGING, and the
## attacker stays CHARGING until the landing exit (`7-8`'s OQ2). Built in two deterministic runs: a probe
## finds the landing tick with no touch pushed, then the real run pushes the ONE touch on exactly that tick
## together with the staging press.
func test_an_orb_granted_on_the_staging_tick_does_not_count() -> void:
	var probe := _make_match(Enums.PitchSpeed.SORCERY)
	var cast_slot := _hand_slot_of(probe, Enums.CardColor.RED)
	_advance(probe, _unblockable_intent(cast_slot), InputIntent.new())
	var landing_after := -1
	for t in LAND_BUDGET_TICKS:
		_advance(probe, InputIntent.new(), InputIntent.new())
		if probe.p1.hero.action_state != HeroState.ActionState.CHARGING:
			landing_after = t
			break
	assert_true(landing_after >= 0, "probe: the flight ended inside the budget")
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	assert_eq(_hand_slot_of(ms, Enums.CardColor.RED), cast_slot, "sanity: the same deterministic deal")
	_advance(ms, _unblockable_intent(cast_slot), InputIntent.new())
	for _t in landing_after:
		_advance(ms, InputIntent.new(), InputIntent.new())
	var stage_slot := _first_card_slot(ms, -1, cast_slot)
	_push_reach(ms)
	_advance(ms, _stage_intent(stage_slot), InputIntent.new())
	assert_eq(_hits.size(), 1, "the ONE touch landed on the landing tick")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 1, "...and banked its red orb at step 3")
	assert_true(ms.pitch.is_staged(0), "...and the card was staged at step 6 of the SAME tick")
	assert_eq(ms.pitch.fresh_orbs(0), {}, "the same-tick orb was banked before staging: NOT counted")
	assert_false(_sorcery_ready(ms), "...so the sorcery is NOT READY though the bank holds its price")


func test_activation_below_the_cap_keeps_the_pre_staging_orbs_bank_3_to_4_to_3() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	ms.p1.orbs.add(Enums.CardColor.RED, 3)
	ms.drain_signals()
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.RED), "one red earned")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 4, "bank red 3 + one earned = 4")
	assert_true(_sorcery_ready(ms), "...READY")
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "activated")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 3,
		"activation spends the price from the bank: 4 - 1 = 3, the pre-staging orbs remain (AC 7)")


func test_at_the_cap_an_earned_orb_still_counts_and_the_bank_drops_by_the_price_5_5_4() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	ms.p1.orbs.add(Enums.CardColor.RED, MAX_ORBS)
	ms.drain_signals()
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.RED), "one red earned into a FULL red bank")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), MAX_ORBS, "the bank never exceeds the cap (AC 10)")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.RED: 1}, "...but the earned orb still COUNTS (`7-4/R11`)")
	assert_true(_sorcery_ready(ms), "...so the sorcery is READY")
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "activated")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), MAX_ORBS - 1, "the bank drops by the price: 5 -> 4")


# --- S3 THE ZONE'S EXITS (AC 8/AC 9) -------------------------------------------------------------

func test_the_fresh_count_clears_on_activation() -> void:
	var ms := _staged_sorcery_with_one_earned()
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "activated")
	_assert_fresh_empty(ms, "activation")


func test_a_ready_sorcery_that_fizzles_is_lost_and_its_fresh_orbs_stay_banked() -> void:
	var ms := _staged_sorcery_with_one_earned()
	var id := ms.pitch.staged_card_id(0)
	var bank := ms.p1.orbs.get_count(Enums.CardColor.RED)
	assert_true(_sorcery_ready(ms), "sanity: READY before the fizzle")
	for _t in TIMER_TICKS + 1:
		if not ms.pitch.is_staged(0):
			break
		_tick(ms)
	assert_false(ms.pitch.is_staged(0), "the countdown ran out (AC 9)")
	assert_true(ms.p1.discard.to_array().has(id), "...the card is lost to the discard")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), bank, "...and the earned orb stays in the bank")
	_assert_fresh_empty(ms, "fizzle")


func test_the_fresh_count_clears_on_the_debug_reset() -> void:
	var ms := _staged_sorcery_with_one_earned()
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "the reset emptied the zone")
	_assert_fresh_empty(ms, "debug reset")


func test_every_staging_starts_with_an_empty_fresh_count() -> void:
	var ms := _staged_sorcery_with_one_earned()
	_advance(ms, _activate_intent(), InputIntent.new())
	for _t in DELAY_TICKS + 1:
		_tick(ms)
	ms.p1.orbs.add(Enums.CardColor.RED, 3)
	ms.drain_signals()
	var slot := _first_card_slot(ms)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "a second card staged")
	assert_eq(ms.pitch.fresh_orbs(0), {}, "...with nothing earned yet -- the last card's count did not carry")
	assert_false(_sorcery_ready(ms), "...so it is not READY on the bank the first card left behind")


func test_the_fresh_count_does_not_advance_while_the_round_is_frozen() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_tick(ms)
	assert_true(ms.to_snapshot()["round_over"], "sanity: the round is over")
	var frozen: Dictionary = ms.to_snapshot()["pitch"]["p1"]
	for _t in 10:
		_push_reach(ms)
		_tick(ms)
	assert_eq(ms.to_snapshot()["pitch"]["p1"], frozen, "the whole zone, fresh count included, is frozen")


func test_a_sorcery_with_no_orb_price_is_ready_at_once() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY, {})
	var slot := _first_card_slot(ms)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_sorcery_ready(ms), "nothing to earn: READY on the staging tick (AC 9)")


func test_with_the_orbs_layer_off_every_staged_card_is_ready_regardless_of_speed() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY, {Enums.CardColor.RED: 1}, false)
	var slot := _first_card_slot(ms)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_sorcery_ready(ms), "orbs layer off: a sorcery is READY at once (the graceful degrade, AC 9)")


# --- THE READY RULE ITSELF, ON THE CONTAINER (AC 6) ----------------------------------------------

func test_a_two_colour_price_is_ready_only_once_the_last_required_colour_is_earned() -> void:
	var pitch := PitchState.new()
	var orbs := OrbPool.new(SignalQueue.new())
	orbs.add(Enums.CardColor.RED, 3)
	orbs.add(Enums.CardColor.BLUE, 3)
	pitch.stage(0, &"two_colour", 0, {Enums.CardColor.RED: 1, Enums.CardColor.BLUE: 1}, TIMER_TICKS, 0.0, 0.0)
	var flags := _flags(true)
	assert_false(pitch.is_ready(0, orbs, flags, true), "nothing earned: not READY")
	assert_true(pitch.is_ready(0, orbs, flags, false), "...though the same zone read as an INSTANT is READY")
	pitch.credit_fresh_orbs(0, Enums.CardColor.GREEN, 5)
	assert_false(pitch.is_ready(0, orbs, flags, true), "an unpriced colour never counts")
	pitch.credit_fresh_orbs(0, Enums.CardColor.RED, 1)
	assert_false(pitch.is_ready(0, orbs, flags, true), "red covered, blue not: still not READY")
	pitch.credit_fresh_orbs(0, Enums.CardColor.BLUE, 1)
	assert_true(pitch.is_ready(0, orbs, flags, true), "the LAST required colour covered: READY")


func test_after_a_reload_lowers_the_cap_a_sorcery_also_needs_the_bank_to_cover_the_price() -> void:
	var pitch := PitchState.new()
	var orbs := OrbPool.new(SignalQueue.new())
	orbs.set_maximum(MAX_ORBS)
	orbs.add(Enums.CardColor.RED, 2)
	pitch.stage(0, &"pricey", 0, {Enums.CardColor.RED: 2}, TIMER_TICKS, 0.0, 0.0)
	pitch.credit_fresh_orbs(0, Enums.CardColor.RED, 2)
	var flags := _flags(true)
	assert_true(pitch.is_ready(0, orbs, flags, true), "two earned, two banked: READY")
	orbs.set_maximum(1)
	assert_eq(orbs.get_count(Enums.CardColor.RED), 1, "sanity: the lowered cap clamped the bank")
	assert_false(pitch.is_ready(0, orbs, flags, true),
		"earned covers the price but the BANK no longer does: not READY (AC 6)")
	orbs.set_maximum(MAX_ORBS)
	orbs.add(Enums.CardColor.RED, 1)
	assert_true(pitch.is_ready(0, orbs, flags, true), "the bank covers it again: READY")


## Review fix MINOR-2 (AC 6's hot-reload clause) THROUGH THE REAL RELOAD SEAT: the container case directly above
## hand-builds the pool, so this one drives `MatchState.apply_balance` itself while a sorcery is staged -- bank 2,
## price 2, fresh 2, then a reload to `max_orbs_per_color = 1` clamps the bank under the price. The fresh count
## still covers it, the bank does not: NOT READY, and activation takes the existing not-ready refusal.
func test_a_balance_reload_that_lowers_the_cap_under_the_price_un_readies_a_staged_sorcery() -> void:
	var ms := _make_match(Enums.PitchSpeed.SORCERY, {Enums.CardColor.RED: 2})
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.RED), "fixture: the first red earned while the sorcery waits")
	assert_true(_land(ms, Enums.CardColor.RED), "fixture: the second red earned while the sorcery waits")
	assert_true(ms.pitch.is_staged(0), "fixture: still staged after both landings")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2, "fixture: bank red 2")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.RED: 2}, "fixture: fresh red 2")
	assert_true(_sorcery_ready(ms), "fixture: READY before the reload")
	var lowered := _config()
	lowered.max_orbs_per_color = 1
	assert_eq(ms.apply_balance(lowered), "", "the reload is applied, not refused")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 1, "the lowered cap clamped the bank under the price")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.RED: 2}, "...while the fresh count is untouched")
	assert_false(_sorcery_ready(ms), "fresh covers the price, the BANK no longer does: NOT READY (AC 6)")
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_NOT_READY]],
		"activation takes the existing not-ready refusal")
	assert_true(ms.pitch.is_staged(0), "...the card stays staged")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 1, "...and no orb is spent")


# --- S1 CONTENT, NOT STATE (AC 3/AC 11) ----------------------------------------------------------

func test_speed_never_changes_the_snapshot_key_set() -> void:
	var instant := _make_match(Enums.PitchSpeed.INSTANT)
	var sorcery := _make_match(Enums.PitchSpeed.SORCERY)
	for ms: MatchState in [instant, sorcery]:
		var slot := _spare(ms, Enums.CardColor.RED)
		_advance(ms, _stage_intent(slot), InputIntent.new())
		assert_true(_land(ms, Enums.CardColor.RED), "a landing inside the window")
	assert_eq(_key_paths(sorcery.to_snapshot()), _key_paths(instant.to_snapshot()),
		"the same driven run, instant vs sorcery: IDENTICAL snapshot key sets -- speed adds no key")
	assert_ne(sorcery.to_snapshot()["pitch"]["p1"]["fresh_orbs"], instant.to_snapshot()["pitch"]["p1"]["fresh_orbs"],
		"...while the hashed fresh count DOES differ (non-vacuity: the two runs really diverged)")


func test_re_authoring_a_speed_after_recording_cannot_change_the_recording() -> void:
	var costs := _pitch_costs(Enums.PitchSpeed.SORCERY, {Enums.CardColor.RED: 1})
	var record := IntentRecorder.new()
	record.capture_inject_pitch_costs(costs)
	var id: StringName = costs.keys()[0]
	costs[id].pitch_speed = Enums.PitchSpeed.INSTANT
	assert_eq(record.replay_pitch_costs()[id].pitch_speed, Enums.PitchSpeed.SORCERY,
		"the record holds the speed BY VALUE: a later edit to the live condition does not reach it (AC 3)")


func test_a_sorcery_run_replays_its_ready_tick_identically() -> void:
	var first := _driven_ready_trace()
	var second := _driven_ready_trace()
	assert_true(int(first["ready_tick"]) > 0, "the driven run reached READY (non-vacuity)")
	assert_eq(second["ready_tick"], first["ready_tick"], "the same inputs reach READY on the SAME tick (AC 11)")
	assert_eq(second["snapshots"], first["snapshots"], "...through identical per-tick snapshots")


# --- helpers -------------------------------------------------------------------------------------

func _staged_sorcery_with_one_earned() -> MatchState:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	assert_true(_land(ms, Enums.CardColor.RED), "fixture: one red earned while the sorcery waits")
	assert_eq(ms.pitch.fresh_orbs(0), {Enums.CardColor.RED: 1}, "fixture: the fresh count is non-empty")
	return ms


func _assert_fresh_empty(ms: MatchState, exit: String) -> void:
	assert_eq(ms.pitch.fresh_orbs(0), {}, "the fresh count is EMPTY after the %s (AC 8)" % exit)
	assert_eq(ms.to_snapshot()["pitch"]["p1"]["fresh_orbs"], {"red": 0, "blue": 0, "green": 0},
		"...and the hashed zone reads resting zeros after the %s" % exit)


func _driven_ready_trace() -> Dictionary:
	var ms := _make_match(Enums.PitchSpeed.SORCERY)
	var slot := _spare(ms, Enums.CardColor.RED)
	_advance(ms, _stage_intent(slot), InputIntent.new())
	_advance(ms, _unblockable_intent(_hand_slot_of(ms, Enums.CardColor.RED)), InputIntent.new())
	var snapshots: Array = []
	var ready_tick := -1
	for _t in LAND_BUDGET_TICKS:
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
		snapshots.append(ms.to_snapshot())
		if ready_tick < 0 and _sorcery_ready(ms):
			ready_tick = _tick_of(ms)
	return {"ready_tick": ready_tick, "snapshots": snapshots}


func _key_paths(value: Variant, prefix := "") -> Array:
	var out: Array = []
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			var path := "%s/%s" % [prefix, key]
			out.append(path)
			out.append_array(_key_paths((value as Dictionary)[key], path))
	out.sort()
	return out


func _sorcery_ready(ms: MatchState) -> bool:
	return ms.pitch.is_ready(0, ms.p1.orbs, ms.flags, true)


func _tick_of(ms: MatchState) -> int:
	return int(ms.to_snapshot()["tick"])


## P1's first non-empty hand slot, optionally of `color` and never `exclude`.
func _first_card_slot(ms: MatchState, color: int = -1, exclude: int = -1) -> int:
	var hand: Array = ms.p1.hand.to_array()
	for i in hand.size():
		if i == exclude or StringName(hand[i]) == Hand.EMPTY:
			continue
		if color < 0 or _colors()[StringName(hand[i])] == color:
			return i
	assert_true(false, "fixture: P1's dealt hand holds a card (colour %d) -- hand %s" % [color, hand])
	return 0


func _hand_slot_of(ms: MatchState, color: Enums.CardColor) -> int:
	return _first_card_slot(ms, color)


## A hand slot to STAGE from that keeps a `color` card in hand for the landing the test casts next.
func _spare(ms: MatchState, color: Enums.CardColor) -> int:
	return _first_card_slot(ms, -1, _hand_slot_of(ms, color))


## Cast a P1 unblockable of `color` from the hand and push the reach until it LANDS (a `hit_landed`), then
## tick out the flight so the hero is free again. True when it landed.
func _land(ms: MatchState, color: Enums.CardColor) -> bool:
	_hits = []
	_advance(ms, _unblockable_intent(_hand_slot_of(ms, color)), InputIntent.new())
	for _t in LAND_BUDGET_TICKS:
		if not _hits.is_empty():
			break
		_push_reach(ms)
		_advance(ms, InputIntent.new(), InputIntent.new())
	for _t in LAND_BUDGET_TICKS:
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_tick(ms)
	return not _hits.is_empty()


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("speed_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 0.0
		out[id] = c
	return out


func _pitch_costs(speed: Enums.PitchSpeed, price: Dictionary) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MANA
		for color: Variant in price:
			c.orb_costs[color as Enums.CardColor] = int(price[color])
		c.pitch_speed = speed
		out[id] = c
	return out


## Alternating red / blue, so a landing of either colour can be cast from the dealt hand.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	var ids := _deck_contents()
	for i in ids.size():
		out[ids[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out


func _flags(orbs := true) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = orbs
	f.unblockable = true
	return f


func _config() -> BalanceConfig:
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
	c.pitch_countdown_push_interval_seconds = 1000.0 / TimingWindow.TICK_HZ
	return c


func _make_match(speed: Enums.PitchSpeed, price: Dictionary = {Enums.CardColor.RED: 1},
		orbs := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags(orbs))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	ms.inject_pitch_costs(_pitch_costs(speed, price))
	ms.hit_landed.connect(
		func(attacker: int, _target: int, _damage: float, _hp: float) -> void: _hits.append(attacker))
	_tick(ms)
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	_hits = []
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
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
