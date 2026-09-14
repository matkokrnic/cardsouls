extends TestCase

## Story 6-2: Mode ④ STAGING -- the Pitch Zone's buildup half. A card leaves the hand into its owner's
## zone, its mana is paid, its public countdown runs, READY is derived live from the owner's orbs, and a
## card whose countdown closes FIZZLES to the discard, owing its replacement only then.
##
## Fixture shape: every card carries the SAME Mode ① price and the SAME pitch price, so no test has to
## predict which id the shuffle put in which slot. Counts are distinct from each other (deck 8, hand 4,
## pitch mana 2.0, cast mana 3.0, start mana 10.0, timer 6 ticks, delay 3 ticks, orb price 2) so an
## off-by-one that read the wrong quantity lands on a different number instead of coinciding with one.
## Every config, flag set and cost map is built IN-TEST -- the authored .tres files never reach here.

const SEED := 6262
const DECK_SIZE := 8
const HAND_SIZE := 4
const CAST_COST := 3.0
const PITCH_MANA := 2.0
const START_MANA := 10.0
const PITCH_ORBS := 2
const PITCH_COLOR := Enums.CardColor.RED
const TIMER_TICKS := 6
const DELAY_TICKS := 3
const MAX_ORBS := 5
const STAGE_SLOT := 2


# --- AC 3 / AC 4: staging -------------------------------------------------------------------

## AC 3, every mutation asserted separately: the mana is paid, the slot is VACATED through the same
## hole a cast makes, NO draw is owed at the staging tick, nothing reaches the discard, and the zone
## records the card id, the price and the slot it came from.
func test_staging_pays_the_mana_vacates_the_slot_and_owes_no_draw() -> void:
	var ms := _make_match()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.p1.mana.get_current(), START_MANA - PITCH_MANA, 0.0001,
		"the pitch mana price was paid at staging")
	assert_true(ms.p1.hand.is_slot_empty(STAGE_SLOT), "the staged card's hand slot is a HOLE")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE - 1, "...and only that slot")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int],
		"NO replacement is owed at the staging tick -- the slot is reserved, not in flight")
	assert_false(ms.p1.pending_draw.is_running, "...and no delivery window started")
	assert_eq(ms.p1.discard.size(), 0, "a staged card is not discarded")
	assert_true(ms.pitch.is_staged(0), "P1's zone holds a card")
	assert_eq(ms.pitch.staged_card_id(0), id, "...the card that was in the staged slot")
	assert_eq(ms.pitch.staged_hand_slot(0), STAGE_SLOT, "...recording the slot it was staged from")
	var zone: Dictionary = ms.to_snapshot()["pitch"]["p1"]
	assert_eq(zone["card_id"], String(id), "the HASHED zone carries the staged card id (AC 14b)")
	assert_eq(zone["hand_slot"], STAGE_SLOT, "...and the staged hand slot (AC 14b)")
	assert_false(zone.has("orb_costs"),
		"the orb price is NOT in the hashed zone -- it is card `.tres` content, out of the hashed "
		+ "run per 3-2, and cannot re-baseline the golden on a reprice")
	assert_false(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "zero orbs banked: not READY yet")


## AC 4: staging is NOT gated on orbs. A player holding NONE of the required orbs stages anyway --
## the orb price is READY's business afterwards, never a precondition.
func test_staging_is_not_gated_on_orb_affordability() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.orbs.get_count(PITCH_COLOR), 0, "sanity: not one required orb is banked")
	var rejections := _rejections(ms.p1)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(rejections, [], "no refusal -- in particular never insufficient_orbs")
	assert_true(ms.pitch.is_staged(0), "the card staged with zero orbs")


# --- AC 5 / AC 6: refusals ------------------------------------------------------------------

## AC 5: every refusal rides the shipped `action_rejected` seam with `card_cast`, and NOTHING moves --
## no card removed, no mana spent, no orb touched, nothing staged. One fixture per reason.
func test_a_closed_pitch_zone_layer_refuses_with_flag_closed() -> void:
	var flags := _flags()
	flags.pitch_zone = false
	_assert_refused_unchanged(_make_match(START_MANA, _pitch_costs(), flags),
			_stage_intent(STAGE_SLOT), CastEvaluator.REASON_FLAG_CLOSED, "pitch_zone layer off")


func test_a_closed_required_flag_on_the_pitch_cost_refuses_with_flag_closed() -> void:
	# The condition-side flag half of the flag + mana check, with the LAYER itself open.
	var costs := _pitch_costs()
	for id: StringName in costs:
		costs[id].required_flag = &"totems"
	_assert_refused_unchanged(_make_match(START_MANA, costs), _stage_intent(STAGE_SLOT),
			CastEvaluator.REASON_FLAG_CLOSED, "the pitch cost's required_flag is closed")


func test_insufficient_mana_refuses() -> void:
	_assert_refused_unchanged(_make_match(PITCH_MANA - 0.5), _stage_intent(STAGE_SLOT),
			CastEvaluator.REASON_INSUFFICIENT_MANA, "1.5 mana against a 2.0 pitch price")


func test_an_unarmed_or_out_of_range_slot_refuses_as_an_empty_slot() -> void:
	_assert_refused_unchanged(_make_match(), _stage_intent(-1), CastEvaluator.REASON_EMPTY_SLOT,
			"no slot armed")
	_assert_refused_unchanged(_make_match(), _stage_intent(HAND_SIZE),
			CastEvaluator.REASON_EMPTY_SLOT, "a slot past the hand's width")


## AC 5: a card with NO injected pitch entry refuses with the NEW reason, never with
## `CastEvaluator.REASON_UNKNOWN_CARD` (whose own header declares it unreachable).
func test_a_card_with_no_pitch_cost_refuses_with_its_own_reason() -> void:
	var empty: Dictionary[StringName, CardCastCondition] = {}
	var ms := _make_match(START_MANA, empty)
	_assert_refused_unchanged(ms, _stage_intent(STAGE_SLOT), MatchState.REASON_NO_PITCH_COST,
			"an empty pitch-cost map is legal injection (AC 2) and refuses at staging")
	assert_ne(MatchState.REASON_NO_PITCH_COST, CastEvaluator.REASON_UNKNOWN_CARD,
		"the reason is its own token, not the evaluator's unreachable default")


func test_a_charging_or_stunned_hero_cannot_stage() -> void:
	var charging := _make_match()
	# A real chargeup's parts, not a bare state write: both windows running (or step 3 lands it) and
	# the commit tick still HOLDING the cast (or 6-1's early-release arm feints the hero to IDLE first).
	charging.p1.hero.set_action_state(HeroState.ActionState.CHARGING)
	charging.p1.charge_window.start(60)
	charging.p1.landing_window.start(90)
	charging.p1.charge_color = Enums.CardColor.RED
	charging.drain_signals()
	var held := _stage_intent(STAGE_SLOT)
	held.held[&"card_cast"] = true
	_assert_refused_unchanged(charging, held,
			MatchState.REASON_UNBLOCKABLE_COMMITTED, "mid-chargeup")
	var stunned := _make_match()
	stunned.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	stunned.p1.hero.stun.start(60)
	stunned.drain_signals()
	_assert_refused_unchanged(stunned, _stage_intent(STAGE_SLOT), MatchState.REASON_STUNNED,
			"stunned")


## AC 6: ONE staged card per player. A second stage -- while waiting, and again while READY -- refuses
## with the occupancy reason and never overwrites the card already in the zone.
func test_a_second_stage_while_a_card_is_staged_refuses_and_overwrites_nothing() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var first := ms.pitch.staged_card_id(0)
	var rejections := _rejections(ms.p1)
	_advance(ms, _stage_intent(0), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_ZONE_OCCUPIED]],
		"a stage against an occupied zone refuses with the occupancy reason")
	assert_eq(ms.pitch.staged_card_id(0), first, "the waiting card was not overwritten")
	assert_false(ms.p1.hand.is_slot_empty(0), "the second card stayed in the hand")
	assert_almost_eq(ms.p1.mana.get_current(), START_MANA - PITCH_MANA, 0.0001,
		"no second price was paid")
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "sanity: the staged card is now READY")
	rejections.clear()
	_advance(ms, _stage_intent(1), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_ZONE_OCCUPIED]],
		"...and a READY zone refuses the same way")
	assert_eq(ms.pitch.staged_card_id(0), first, "the READY card was not overwritten either")


# --- AC 7: independence ---------------------------------------------------------------------

## AC 7: both players hold a staged card at once, and neither zone reads, blocks or mutates the other --
## P2's orbs never make P1 READY, and P1's fizzle leaves P2's card where it is.
func test_the_two_zones_are_independent() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	for _t in 2:
		_tick(ms)
	_advance(ms, InputIntent.new(), _stage_intent(1))
	assert_true(ms.pitch.is_staged(0) and ms.pitch.is_staged(1), "both players hold a staged card")
	assert_eq(ms.pitch.staged_hand_slot(1), 1, "P2's zone records P2's own slot")
	ms.p2.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	assert_true(ms.pitch.is_ready(1, ms.p2.orbs, ms.flags), "P2 is READY on P2's orbs")
	assert_false(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and P1 is NOT, on P1's own")
	# P1 staged three ticks before P2, so P1 fizzles first and P2's countdown must be untouched.
	for _t in TIMER_TICKS - 3:
		_tick(ms)
	assert_false(ms.pitch.is_staged(0), "P1's card fizzled at its own deadline")
	assert_true(ms.pitch.is_staged(1), "P2's card is still waiting")
	assert_eq(ms.to_snapshot()["pitch"]["p2"]["fizzle"]["elapsed_ticks"], TIMER_TICKS - 3,
		"...with P2's countdown at exactly its own elapsed count")
	assert_eq(ms.p2.discard.size(), 0, "P1's fizzle discarded nothing of P2's")


# --- AC 8 / AC 8a: the hand, the debt and the announcements ---------------------------------

## AC 8: THE FIVE-TERM IDENTITY -- `occupied + owed + staged == hand_size`, together with the multiset
## (deck + hand + discard + the staged card is a permutation of the composition) -- checked at the
## staging tick, through the wait, at the fizzle tick, through the delivery delay, and after the refill.
func test_the_five_term_conservation_identity_holds_across_stage_wait_and_fizzle() -> void:
	var ms := _make_match()
	_assert_conserved(ms, "before staging")
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_assert_conserved(ms, "on the staging tick")
	assert_eq(_staged_term(ms), 1, "sanity: the staged term really is 1 here, not a vacuous 0")
	for t in TIMER_TICKS - 1:
		_tick(ms)
		_assert_conserved(ms, "waiting, tick %d" % (t + 1))
	_tick(ms)
	assert_false(ms.pitch.is_staged(0), "sanity: the card fizzled on this tick")
	assert_eq(ms.p1.pending_draw_owed, [STAGE_SLOT] as Array[int], "sanity: the debt is owed now")
	_assert_conserved(ms, "on the fizzle tick")
	for t in DELAY_TICKS:
		_tick(ms)
		_assert_conserved(ms, "delivery delay, tick %d" % (t + 1))
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "the reserved slot was refilled after the delay")


## AC 8a: `cards_changed` is announced at STAGING and again at EXPIRY -- two separate seats -- and a
## waiting tick in between announces nothing.
func test_cards_changed_is_announced_at_staging_and_at_expiry_and_not_while_waiting() -> void:
	var ms := _make_match()
	var announced: Array = []
	ms.p1.cards_changed.connect(
		func(hand: Array[StringName], _deck: int, discard: int) -> void:
			announced.append([hand.duplicate(), discard]))
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(announced.size(), 1, "ONE announcement on the staging tick")
	if announced.size() >= 1:
		assert_eq((announced[0][0] as Array)[STAGE_SLOT], Hand.EMPTY, "...carrying the vacated slot")
		assert_eq(announced[0][1], 0, "...with nothing discarded")
	for _t in TIMER_TICKS - 1:
		_tick(ms)
	assert_eq(announced.size(), 1, "a waiting tick announces nothing")
	_tick(ms)
	assert_eq(announced.size(), 2, "ONE announcement on the fizzle tick")
	if announced.size() >= 2:
		assert_eq(announced[1][1], 1, "...carrying the discard the fizzled card landed in")


## AC 7/AC 8's structural reservation: the staged slot is not a second in-flight hole. A Mode ① cast
## into it refuses as an empty slot, and a DIFFERENT slot's delivery never lands in it.
func test_the_reserved_slot_is_never_dealt_into_while_the_card_is_staged() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var rejections := _rejections(ms.p1)
	_advance(ms, _cast_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_EMPTY_SLOT]],
		"a Mode ① cast against the reserved slot refuses as empty")
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(ms.p1.pending_draw_owed, [0] as Array[int], "the cast owes ITS slot only")
	for _t in DELAY_TICKS:
		_tick(ms)
	assert_false(ms.p1.hand.is_slot_empty(0), "the cast's replacement landed in the cast's slot")
	assert_true(ms.p1.hand.is_slot_empty(STAGE_SLOT), "...and the reserved slot is still empty")


# --- AC 9 / AC 11: the countdown and the fizzle ---------------------------------------------

## AC 9: the countdown starts at the tick count DERIVED from `pitch_stage_timer_seconds` through the
## single BalanceTicks boundary -- asserted against the derived value, which the fixture authors
## distinct from every other count here.
func test_staging_starts_the_countdown_at_the_derived_tick_count() -> void:
	var ms := _make_match()
	assert_eq(ms.balance_ticks.pitch_stage_timer_ticks, TIMER_TICKS,
		"sanity: the authored seconds derive %d ticks" % TIMER_TICKS)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(ms.to_snapshot()["pitch"]["p1"]["fizzle"],
		{"duration_ticks": TIMER_TICKS, "elapsed_ticks": 0, "is_running": true},
		"the staging tick starts P1's fizzle window at the derived duration")
	assert_eq(ms.to_snapshot()["pitch"]["p2"]["fizzle"]["is_running"], false,
		"...and P2's stays stopped")


## AC 11: the fizzle lands on the deadline tick and not one earlier; the card goes to the DISCARD (not
## back to the hand), the replacement is owed AT THIS TICK to the reserved slot and delivered after the
## normal delay, and the staging mana is NOT refunded.
func test_the_card_fizzles_to_the_discard_at_the_deadline_and_owes_its_replacement_then() -> void:
	var ms := _make_match()
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	for _t in TIMER_TICKS - 1:
		_tick(ms)
	assert_true(ms.pitch.is_staged(0), "one tick before the deadline the card is still staged")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "...and still owes nothing")
	_tick(ms)
	assert_false(ms.pitch.is_staged(0), "the card left the zone on the deadline tick")
	assert_eq(ms.p1.discard.to_array(), [id] as Array[StringName], "...into the discard")
	assert_false(ms.p1.hand.occupied_ids().has(id), "...not back into the hand")
	assert_eq(ms.p1.pending_draw_owed, [STAGE_SLOT] as Array[int],
		"the replacement is owed NOW, to the reserved slot")
	assert_almost_eq(ms.p1.mana.get_current(), START_MANA - PITCH_MANA, 0.0001,
		"the staging mana is not refunded")
	assert_eq(ms.to_snapshot()["pitch"]["p1"],
		{"card_id": "", "hand_slot": PitchState.NO_HAND_SLOT,
			"fizzle": {"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false}},
		"the hashed zone is back to the empty record")
	for _t in DELAY_TICKS - 1:
		_tick(ms)
	assert_true(ms.p1.hand.is_slot_empty(STAGE_SLOT), "not delivered one tick early")
	_tick(ms)
	assert_false(ms.p1.hand.is_slot_empty(STAGE_SLOT),
		"ONE replacement delivered into the reserved slot after the normal delay")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "...and no second draw is owed")


## AC 11: a card that reads READY still fizzles when its countdown closes -- READY is a state, not an
## activation, and nothing in this story consumes it.
func test_a_ready_card_still_fizzles_and_consumes_no_orbs() -> void:
	var ms := _make_match()
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "sanity: READY on the staging tick")
	for _t in TIMER_TICKS:
		_tick(ms)
	assert_false(ms.pitch.is_staged(0), "the READY card fizzled all the same")
	assert_eq(ms.p1.discard.size(), 1, "...into the discard")
	assert_eq(ms.p1.orbs.get_count(PITCH_COLOR), PITCH_ORBS, "READY consumed no orbs")


# --- AC 10: READY is derived ----------------------------------------------------------------

## AC 10: READY is a live reading of the pool, never a latch. It turns on the moment the orbs arrive
## with no intent at all, it writes nothing hashed, and it degrades to satisfied for an orb-free price
## or with the orbs layer off.
func test_ready_is_derived_live_from_the_orb_pool_and_never_stored() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var before := CanonicalHash.of(ms.to_snapshot()["pitch"])
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS - 1)
	ms.drain_signals()
	assert_false(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "one orb short: not READY")
	ms.p1.orbs.add(Enums.CardColor.BLUE, MAX_ORBS)
	ms.drain_signals()
	assert_false(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "orbs of the WRONG colour do not count")
	ms.p1.orbs.add(PITCH_COLOR, 1)
	ms.drain_signals()
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "the exact price banked: READY")
	assert_eq(CanonicalHash.of(ms.to_snapshot()["pitch"]), before,
		"becoming READY wrote NOTHING into the hashed zone -- there is no READY member to latch")
	assert_false(ms.pitch.is_ready(1, ms.p2.orbs, ms.flags), "an EMPTY zone is never READY")

	var orbs_off := _flags()
	orbs_off.orbs = false
	var degraded := _make_match(START_MANA, _pitch_costs(), orbs_off)
	_advance(degraded, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(degraded.pitch.is_ready(0, degraded.p1.orbs, degraded.flags),
		"orbs layer OFF: an orb price reads satisfied (graceful degrade)")

	var free := _make_match(START_MANA, _pitch_costs(0))
	_advance(free, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(free.pitch.is_ready(0, free.p1.orbs, free.flags),
		"an EMPTY orb price is READY on the staging tick with zero orbs")


# --- AC 12 / AC 13: the optional orb-clear rule ---------------------------------------------

## AC 13, OFF (the default): orbs banked BEFORE staging count immediately -- a player who pre-banked the
## exact price is READY on the very tick they stage, and keeps the orbs.
func test_orb_clear_off_prebanked_orbs_make_the_card_ready_on_the_staging_tick() -> void:
	var ms := _make_match()
	assert_false(ms.balance.pitch_stage_clears_orbs, "sanity: the fixture runs the OFF branch")
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.p1.orbs.add(Enums.CardColor.GREEN, 1)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "READY on the staging tick")
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": PITCH_ORBS, "blue": 0, "green": 1},
		"...and every banked orb is still there")


## AC 13, ON: staging empties ALL THREE colours first, so the same pre-banked player is NOT READY on the
## staging tick and must refill from zero. MUTATION-PROVEN: delete the ON branch in
## `_resolve_pitch_stage` and this fails (the story's mutation table, M1).
func test_orb_clear_on_staging_empties_every_colour_before_ready_is_read() -> void:
	var ms := _make_match(START_MANA, _pitch_costs(), _flags(), true)
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.p1.orbs.add(Enums.CardColor.GREEN, 1)
	ms.p2.orbs.add(PITCH_COLOR, 1)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "sanity: the card staged")
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0},
		"ALL THREE of the staging player's colours were cleared, not just the price's colour")
	assert_false(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags),
		"...so the exact pre-banked price does NOT make the card READY on the staging tick")
	assert_eq(ms.p2.orbs.get_count(PITCH_COLOR), 1, "the OPPONENT's orbs are untouched")
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "refilled from zero: READY")


## AC 12/AC 13, ON, the "pitching clears, not the price clears" half: a ZERO-orb-price card still clears
## the pool when the switch is ON -- and is still READY, because it never needed an orb.
func test_orb_clear_on_a_zero_orb_card_still_clears_the_pool_and_is_still_ready() -> void:
	var ms := _make_match(START_MANA, _pitch_costs(0), _flags(), true)
	ms.p1.orbs.add(Enums.CardColor.BLUE, 3)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(ms.p1.orbs.to_snapshot(), {"red": 0, "blue": 0, "green": 0},
		"staging cleared the pool even though this card's price needs no orb")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and the card is READY regardless")


## AC 12: a REFUSED stage clears nothing, even with the switch ON -- the clear is keyed to the act of
## staging, and a refusal is not one.
func test_orb_clear_on_a_refused_stage_clears_nothing() -> void:
	var ms := _make_match(PITCH_MANA - 0.5, _pitch_costs(), _flags(), true)
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "sanity: the stage was refused for mana")
	assert_eq(ms.p1.orbs.get_count(PITCH_COLOR), PITCH_ORBS, "the refused stage cleared no orbs")


# --- AC 14d / AC 14e: reset, tick ladder, freeze --------------------------------------------

## AC 14d: the debug reset empties BOTH zones and stops both countdowns; the redeal lays the whole
## composition back down, so the staged card exists exactly once afterwards -- in the deck or hand, never
## also in a zone -- and no fizzle ever fires into the new round.
func test_the_debug_reset_clears_both_zones() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), _stage_intent(1))
	assert_true(ms.pitch.is_staged(0) and ms.pitch.is_staged(1), "sanity: both zones hold a card")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "P1's zone is empty after the reset")
	assert_false(ms.pitch.is_staged(1), "P2's zone is empty after the reset")
	assert_eq(ms.to_snapshot()["pitch"]["p1"]["fizzle"]["is_running"], false, "P1's countdown stopped")
	assert_eq(ms.to_snapshot()["pitch"]["p2"]["fizzle"]["is_running"], false, "P2's countdown stopped")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "the redeal filled the whole hand")
	_assert_conserved(ms, "after the reset")
	for _t in TIMER_TICKS + DELAY_TICKS:
		_tick(ms)
	assert_eq(ms.p1.discard.size(), 0, "no stale fizzle landed in the new round")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "...and no stale debt was owed")


## AC 14e: the fizzle expiry is seated BEFORE the pending-draw delivery, so a ZERO-tick countdown with a
## ZERO delay stages, fizzles and refills the slot all on the SAME tick.
func test_a_zero_tick_countdown_fizzles_and_refills_on_the_staging_tick() -> void:
	var ms := _make_match(START_MANA, _pitch_costs(), _flags(), false, 0, 0)
	assert_eq(ms.balance_ticks.pitch_stage_timer_ticks, 0, "sanity: a zero countdown")
	var id: StringName = ms.p1.hand.to_array()[STAGE_SLOT]
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_false(ms.pitch.is_staged(0), "the card fizzled on its own staging tick")
	assert_eq(ms.p1.discard.to_array(), [id] as Array[StringName], "...into the discard")
	assert_false(ms.p1.hand.is_slot_empty(STAGE_SLOT), "...and its replacement landed the same tick")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "...with nothing left owed")
	_assert_conserved(ms, "after a same-tick stage, fizzle and refill")


## AC 14e: the countdown FREEZES with the round -- it ticks at step 2, which a round-over tick never
## reaches -- so a card staged when the round ends neither counts down nor fizzles during the freeze.
func test_the_countdown_freezes_on_round_over_ticks() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_tick(ms)
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_tick(ms)
	assert_true(ms.to_snapshot()["round_over"], "sanity: the round is over")
	var frozen: Dictionary = (ms.to_snapshot()["pitch"]["p1"]["fizzle"] as Dictionary).duplicate()
	for _t in TIMER_TICKS * 2:
		_tick(ms)
	assert_eq(ms.to_snapshot()["pitch"]["p1"]["fizzle"], frozen, "the countdown did not advance")
	assert_true(ms.pitch.is_staged(0), "...and the card did not fizzle during the freeze")


# --- helpers ---------------------------------------------------------------------------------

func _assert_refused_unchanged(ms: MatchState, intent: InputIntent, reason: StringName,
		occasion: String) -> void:
	var hand_before := ms.p1.hand.to_array()
	var mana_before := ms.p1.mana.get_current()
	var orbs_before := ms.p1.orbs.to_snapshot()
	var rejections := _rejections(ms.p1)
	_advance(ms, intent, InputIntent.new())
	assert_eq(rejections, [[&"card_cast", reason]], "refused with %s (%s)" % [reason, occasion])
	assert_eq(ms.p1.hand.to_array(), hand_before, "no card left the hand (%s)" % occasion)
	assert_eq(ms.p1.mana.get_current(), mana_before, "no mana was spent (%s)" % occasion)
	assert_eq(ms.p1.orbs.to_snapshot(), orbs_before, "no orb moved (%s)" % occasion)
	assert_false(ms.pitch.is_staged(0), "nothing was staged (%s)" % occasion)
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "nothing was owed (%s)" % occasion)


## The two halves of AC 8's identity for P1: the multiset and the five-term count.
func _assert_conserved(ms: MatchState, occasion: String) -> void:
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.occupied_ids())
	all.append_array(ms.p1.discard.to_array())
	if ms.pitch.is_staged(0):
		all.append(ms.pitch.staged_card_id(0))
	all.sort()
	var expected := _deck_contents()
	expected.sort()
	assert_eq(all, expected,
		"deck + hand + discard + staged is a PERMUTATION of the composition %s" % occasion)
	assert_eq(ms.p1.hand.occupied_count() + ms.p1.pending_draw_owed.size() + _staged_term(ms),
		HAND_SIZE, "occupied + owed + staged == hand_size %s" % occasion)


func _staged_term(ms: MatchState) -> int:
	return 1 if ms.pitch.is_staged(0) else 0


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("pitch_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CAST_COST
		out[id] = c
	return out


func _pitch_costs(orbs := PITCH_ORBS) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MANA
		if orbs > 0:
			c.orb_costs[PITCH_COLOR] = orbs
		out[id] = c
	return out


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = true
	return f


func _config(clears_orbs: bool, timer_ticks: int, delay_ticks: int) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.max_orbs_per_color = MAX_ORBS
	c.pitch_stage_timer_seconds = timer_ticks / 60.0
	c.draw_replacement_delay_seconds = delay_ticks / 60.0
	c.pitch_stage_clears_orbs = clears_orbs
	return c


## A match with a dealt hand and mana on the board (the deal happens at step 6 of the FIRST advance).
## `pitch_costs` defaults to null and is then built here, so a caller can pass an EMPTY map on purpose.
func _make_match(mana := START_MANA, pitch_costs: Variant = null, flags: FeatureFlags = null,
		clears_orbs := false, timer_ticks := TIMER_TICKS, delay_ticks := DELAY_TICKS) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(clears_orbs, timer_ticks, delay_ticks))
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	var costs: Dictionary[StringName, CardCastCondition] = _pitch_costs()
	if pitch_costs != null:
		costs = pitch_costs
	ms.inject_pitch_costs(costs)
	_tick(ms)
	ms.p1.mana.add(mana)
	ms.p2.mana.add(mana)
	ms.drain_signals()
	return ms


func _stage_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	return i


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _tick(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
