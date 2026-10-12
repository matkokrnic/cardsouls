extends TestCase

## Story 7-5a, PART B (AC 27-29, AC 34-38): THE THREE ECONOMY HALVES -- Bloodmagic, Manablossom and
## Manapulation -- headless, on the shared `Deck2Fixture` (max mana 10; Bloodmagic pays 10 hp for 4 mana;
## Manablossom gives 1, or 2 at three orbs; Manapulation gives 1 per staging).

const F := preload("res://test/deck_2_fixture.gd")
const LONG := 100000


# ================================================================ BLOODMAGIC (AC 27-29)

## AC 27: Bloodmagic costs 0 mana -- the caster loses its authored HP and gains its authored mana.
func test_bloodmagic_pays_hp_and_gains_mana() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 2.0)
	F.play(ms, 0, F.BLOOD)
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP - F.BLOOD_HP, "the caster pays 10 HP")
	assert_eq(ms.p1.mana.get_current(), 2.0 + F.BLOOD_MANA, "...and gains 4 mana, the card itself costing 0")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the opponent is untouched")


## AC 27/AC 47: the mana cap is respected, and the CLAMPED amount is what is recorded for a reversal.
func test_bloodmagic_respects_the_mana_cap_and_records_the_clamped_gain() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 8.0)
	F.play(ms, 0, F.BLOOD)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA, "cast at 8 of 10: the pool fills to 10")
	var packet: Array = ms.p1.to_snapshot()["reversal"]
	assert_eq(int(packet[0]), PlayerState.REVERSAL_BLOODMAGIC, "the resolution recorded a Bloodmagic packet")
	assert_eq(float(packet[5]), 2.0, "...holding the mana ACTUALLY gained (2, not 4)")
	assert_eq(float(packet[6]), F.BLOOD_HP, "...and the HP actually paid")


## AC 28 (`7-5a/R17`): refused with HP at or below the price, nothing spent, card kept. HP EQUAL to the price
## is refused; price + 1 is allowed.
func test_bloodmagic_is_refused_at_or_below_its_hp_price_and_allowed_one_above() -> void:
	for hp: float in [F.BLOOD_HP, F.BLOOD_HP - 3.0]:
		var ms := F.make()
		F.set_hp(ms, ms.p1, hp)
		F.set_mana(ms, ms.p1, 2.0)
		var rejections := F.rejections(ms.p1)
		F.play(ms, 0, F.BLOOD)
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_INSUFFICIENT_HP]],
			"hp %s: refused with the named reason" % hp)
		assert_eq(ms.p1.hero.get_hp(), hp, "hp %s: no HP is paid" % hp)
		assert_eq(ms.p1.mana.get_current(), 2.0, "hp %s: no mana is gained" % hp)
		assert_eq(ms.p1.hand.to_array()[0], F.BLOOD, "hp %s: the card is kept" % hp)
		assert_eq(ms.p1.discard.size(), 0, "hp %s: nothing is discarded" % hp)
	var allowed := F.make()
	F.set_hp(allowed, allowed.p1, F.BLOOD_HP + 1.0)
	var none := F.rejections(allowed.p1)
	F.play(allowed, 0, F.BLOOD)
	assert_true(none.is_empty(), "price + 1: the cast is allowed")
	assert_eq(allowed.p1.hero.get_hp(), 1.0, "...and leaves the hero at 1 hp, alive")
	assert_true(allowed.p1.hero.is_alive(), "an HP price never kills")


## AC 29 (`7-5a/R17`): the HP paid is NOT DAMAGE -- it does not trigger Stoneskin, Lifechain or Bloodlust,
## heals no Vampiric Aura, and is not a hit.
func test_the_hp_paid_is_not_damage() -> void:
	var ms := F.make()
	ms.p1.add_stoneskin_charge()
	ms.p1.open_lifechain(LONG)
	ms.p1.units.add(F.MINION_HP, 0)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	ms.p2.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, 0.5, 0.0)
	F.set_hp(ms, ms.p2, 50.0)
	var hits: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void: hits.append([a, t, d, hp]))
	F.play(ms, 0, F.BLOOD)
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP - F.BLOOD_HP,
		"exactly the price is paid: Stoneskin did not absorb it and Bloodlust did not double it")
	assert_eq(ms.p1.stoneskin_charges, 1, "the Stoneskin charge is NOT consumed")
	assert_eq(ms.p1.units.hp_at(0), F.MINION_HP, "Lifechain did not split it onto the minion")
	assert_eq(ms.p2.hero.get_hp(), 50.0, "no lifesteal: the opponent's Vampiric Aura healed nothing")
	assert_true(hits.is_empty(), "it is not a hit: no `hit_landed`")


# ================================================================ MANABLOSSOM (AC 34-37)

## AC 34: Manablossom costs its mana and gives every card in hand 1 less mana to play AND to stage; orb
## costs are unchanged.
func test_manablossom_discounts_every_card_in_hand_for_play_and_for_staging() -> void:
	var ms := _blossomed()
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 1.0, "Manablossom itself cost its 1 mana")
	assert_eq(ms.p1.hand.discounts(), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"the three cards in hand are discounted by 1; the slot Manablossom left is not a card")
	# NORMAL side: PLAIN costs 3, now 2.
	var mana := ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.mana.get_current(), mana - (F.PLAIN_MANA - 1.0), "a discounted card plays for 1 less")
	# PITCH side: PLAIN stages for 3, now 2 -- and its orb price is the same one red orb.
	mana = ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(2, Enums.ModeKind.PITCH))
	assert_eq(ms.p1.mana.get_current(), mana - (F.PLAIN_MANA - 1.0), "a discounted card stages for 1 less")
	assert_eq(ms.pitch.staged_orb_costs(0), {Enums.CardColor.RED: 1}, "the orb cost is unchanged")


## AC 34: with 3 or more orbs (all colours) held as it resolves, the discount is 2.
func test_manablossom_discounts_by_two_at_three_orbs() -> void:
	var two := F.make()
	F.set_orbs(two, two.p1, 1, 1, 0)
	_fill_plain(two.p1)
	F.play(two, 0, F.BLOSSOM)
	assert_eq(two.p1.hand.discount_at(1), F.BLOSSOM_DISCOUNT, "two orbs held: the plain discount")
	var three := F.make()
	F.set_orbs(three, three.p1, 1, 1, 1)
	_fill_plain(three.p1)
	F.play(three, 0, F.BLOSSOM)
	assert_eq(three.p1.hand.discount_at(1), F.BLOSSOM_BIG_DISCOUNT, "three orbs held, any colours: 2 less")
	assert_eq(F.total_orbs(three.p1), 3, "Manablossom spends no orb")


## AC 34: the cost FLOORS AT ZERO, and (`7-5a/R10`) the RAW sum is stored.
func test_the_discounted_cost_floors_at_zero_and_the_raw_sum_is_stored() -> void:
	var ms := F.make()
	F.put(ms.p1, 1, F.BLOSSOM)   # a 1-mana card to discount twice
	F.play(ms, 0, F.BLOSSOM)
	F.play(ms, 0, F.BLOSSOM)
	assert_eq(ms.p1.to_snapshot()["hand_discount"][1], 2.0, "two Manablossoms stack ADDITIVELY: the raw sum is 2")
	var mana := ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.mana.get_current(), mana, "a 1-mana card under a 2 discount costs 0, never negative")


## AC 34: NOT discounted -- the unblockable's mana, and Boulder clearing.
func test_the_unblockable_and_boulder_clearing_are_never_discounted() -> void:
	var ms := _blossomed()
	var mana := ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.UNBLOCKABLE))
	assert_eq(ms.p1.mana.get_current(), mana - F.UNBLOCKABLE_MANA,
		"an unblockable from a discounted card still costs the unblockable's own mana")
	var covered := _blossomed()
	covered.p1.hand.cover_at(1, F.BOULDER)
	mana = covered.p1.mana.get_current()
	F.act(covered, 0, F.card_intent(1, Enums.ModeKind.BASIC))
	assert_eq(covered.p1.mana.get_current(), mana - F.BOULDER_MANA,
		"clearing a Boulder costs the Boulder's full price -- the discount is the card's, not the cover's")
	assert_false(covered.p1.hand.is_covered(1), "fixture: the Boulder was cleared")


## AC 35: a card UNDER A BOULDER takes the discount and has it when uncovered.
func test_a_card_under_a_boulder_takes_the_discount_and_keeps_it_when_uncovered() -> void:
	var ms := F.make()
	_fill_plain(ms.p1)
	ms.p1.hand.cover_at(2, F.BOULDER)
	F.play(ms, 0, F.BLOSSOM)
	assert_eq(ms.p1.hand.discount_at(2), F.BLOSSOM_DISCOUNT, "the covered card took the discount")
	F.act(ms, 0, F.card_intent(2, Enums.ModeKind.BASIC))   # clear the Boulder
	assert_false(ms.p1.hand.is_covered(2), "fixture: the Boulder was cleared")
	var mana := ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(2, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.mana.get_current(), mana - (F.PLAIN_MANA - 1.0), "the uncovered card plays for 1 less")


## AC 35: the discount belongs to the card UNTIL IT LEAVES THE HAND (played, staged, spent on an
## unblockable); a card that then arrives in that slot is NOT discounted.
func test_the_discount_leaves_with_the_card_and_a_later_card_is_not_discounted() -> void:
	for mode: Enums.ModeKind in [Enums.ModeKind.BASIC, Enums.ModeKind.PITCH, Enums.ModeKind.UNBLOCKABLE]:
		var ms := _blossomed()
		F.act(ms, 0, F.card_intent(1, mode))
		assert_true(ms.p1.hand.is_slot_empty(1), "mode %d: the card left the hand" % mode)
		assert_eq(ms.p1.to_snapshot()["hand_discount"][1], 0.0, "mode %d: its discount left with it" % mode)
		ms.p1.hand.fill_at(1, F.PLAIN)   # the replacement arrives
		assert_eq(ms.p1.hand.discount_at(1), 0.0, "mode %d: a card drawn afterwards is not discounted" % mode)


## AC 35: a card REFUSED for any reason keeps its discount.
func test_a_refused_card_keeps_its_discount() -> void:
	var ms := _blossomed()
	F.set_mana(ms, ms.p1, 0.0)
	var rejections := F.rejections(ms.p1)
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.BASIC))
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_eq(rejections.size(), 2, "both presses were refused (no mana)")
	assert_eq(ms.p1.hand.discount_at(1), F.BLOSSOM_DISCOUNT, "the refused card keeps its discount")


## AC 36 (`7-5a/R14`): Fireball's staging MINIMUM drops by the discount (3 becomes 2); its damage stays per
## mana actually spent.
func test_the_discount_lowers_fireballs_staging_minimum_and_not_its_damage() -> void:
	var refused := F.make()
	F.put(refused.p1, 1, F.FIRE)
	F.set_mana(refused, refused.p1, 2.0)
	var rejections := F.rejections(refused.p1)
	F.act(refused, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
		"undiscounted, 2 mana is below Fireball's minimum of 3")
	var ms := F.make()
	F.put(ms.p1, 1, F.FIRE)
	F.play(ms, 0, F.BLOSSOM)
	F.set_mana(ms, ms.p1, 2.0)
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_true(ms.pitch.is_staged(0), "discounted, Fireball stages at 2 mana: the minimum is 2")
	assert_eq(ms.p1.mana.get_current(), 0.0, "it spent the whole pool, as a Fireball does")
	assert_eq(ms.pitch.staged_locked_damage(0), F.FIRE_DAMAGE_PER_MANA * 2.0,
		"its damage is per mana ACTUALLY SPENT (2), not per the undiscounted 3")
	# With a full pool the discount changes nothing about what a Fireball spends.
	var full := F.make()
	F.put(full.p1, 1, F.FIRE)
	F.play(full, 0, F.BLOSSOM)
	var pool := full.p1.mana.get_current()
	F.act(full, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_eq(full.pitch.staged_locked_damage(0), F.FIRE_DAMAGE_PER_MANA * pool,
		"a full-pool Fireball still spends and scales on the whole pool")


## AC 37: the cost the HUD is handed is the discounted one's ingredients -- the clamped per-slot discount,
## read off the hand beside the hand ids, and announced through `cards_changed` when Manablossom resolves.
func test_the_discount_reaches_the_hud_read_and_cards_changed_announces_it() -> void:
	var ms := F.make()
	_fill_plain(ms.p1)
	var announcements: Array = [0]
	ms.p1.cards_changed.connect(
		func(_hand: Array, _deck: int, _discard: int) -> void: announcements[0] += 1)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))   # slot 0 holds Manablossom after _fill_plain
	assert_true(announcements[0] >= 1, "the play that discounted the hand announced `cards_changed`")
	assert_eq(ms.p1.hand.discounts(), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"the HUD-side read gives each slot's discount, clamped, in slot order")
	assert_eq(ms.p2.hand.discounts(), [0.0, 0.0, 0.0, 0.0] as Array[float], "the other seat's hand is untouched")


# ================================================================ MANAPULATION (AC 38)

## AC 38: Manapulation costs its mana and grants mana equal to the successful stagings this round.
func test_manapulation_grants_mana_per_successful_staging_this_round() -> void:
	var ms := F.make()
	for _n in 3:
		F.stage(ms, 0, F.PLAIN)
		ms.pitch.clear(0)   # make room for the next staging; the count is of stagings, not of the zone
	assert_eq(ms.p1.to_snapshot()["stagings"], 3, "three successful stagings are counted")
	F.set_mana(ms, ms.p1, 4.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), 4.0 - 1.0 + 3.0 * F.PULATION_MANA,
		"Manapulation costs 1 and grants 1 per staging: 4 - 1 + 3")


## AC 38: ZERO stagings grants zero; Manapulation itself is a normal play, not a staging.
func test_zero_stagings_grants_zero_and_manapulation_is_not_a_staging() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 5.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), 4.0, "no stagings: only the card's own cost moved")
	assert_eq(ms.p1.to_snapshot()["stagings"], 0, "playing Manapulation is not a staging")
	assert_eq(int((ms.p1.to_snapshot()["reversal"] as Array)[0]), PlayerState.REVERSAL_NONE,
		"a Manapulation that granted nothing records nothing to counter")


## AC 38: the mana cap is respected.
func test_manapulation_respects_the_mana_cap() -> void:
	var ms := F.make()
	for _n in 5:
		F.stage(ms, 0, F.BOLT)
		ms.pitch.clear(0)
	F.set_mana(ms, ms.p1, 8.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA, "8 - 1 + 5 is clamped at the pool's 10")
	assert_eq(float((ms.p1.to_snapshot()["reversal"] as Array)[5]), 3.0,
		"the record holds the mana ACTUALLY gained (3), for the reversal (AC 47)")


## AC 38: REFUSED stagings and BOULDER CLEARS do not count.
func test_refused_stagings_and_boulder_clears_do_not_count() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 0.0)
	F.stage(ms, 0, F.PLAIN)
	assert_false(ms.pitch.is_staged(0), "fixture: the staging was refused (no mana)")
	assert_eq(ms.p1.stagings_this_round, 0, "a refused staging does not count")
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.stage(ms, 0, F.PLAIN)
	F.stage(ms, 0, F.PLAIN, 1)
	assert_eq(ms.p1.stagings_this_round, 1, "a staging refused for an occupied zone does not count either")
	ms.p1.hand.cover_at(2, F.BOULDER)
	F.act(ms, 0, F.card_intent(2, Enums.ModeKind.BASIC))
	assert_false(ms.p1.hand.is_covered(2), "fixture: the Boulder was cleared")
	assert_eq(ms.p1.stagings_this_round, 1, "a Boulder clear is not a staging")


## AC 38: a staged card that later ACTIVATES or FIZZLES still counts; COUNTERING it does not remove the count.
func test_activation_fizzle_and_a_counter_do_not_take_the_count_back() -> void:
	var balance := F.config()
	balance.pitch_stage_timer_seconds = F.ticks_to_seconds(5)
	var fizzled := F.make(balance)
	F.stage(fizzled, 0, F.PLAIN)
	F.idle(fizzled, 8)
	assert_false(fizzled.pitch.is_staged(0), "fixture: the staged card fizzled")
	assert_eq(fizzled.p1.stagings_this_round, 1, "a card that fizzled still counts")
	var activated := F.make()
	F.pitch(activated, 0, F.SETUP)
	assert_eq(activated.p1.execute_charges, 1, "fixture: the staged card activated (Execute)")
	assert_eq(activated.p1.stagings_this_round, 1, "a card that activated still counts")
	assert_true(F.counter(activated, 1), "P2 counters the Execute")
	assert_eq(activated.p1.execute_charges, 0, "fixture: the counter took the charge")
	assert_eq(activated.p1.stagings_this_round, 1, "countering the staged card does not remove the count")


## AC 38 (`7-5a/R19`): the OPPOSING seat's pitching never counts -- the count is per player.
func test_the_opposing_seats_stagings_do_not_count() -> void:
	var ms := F.make()
	F.stage(ms, 1, F.PLAIN)
	F.stage(ms, 1, F.PLAIN, 1)
	assert_eq(ms.p2.stagings_this_round, 1, "P2 staged once")
	assert_eq(ms.p1.stagings_this_round, 0, "P1's count is its OWN zone's only")
	F.set_mana(ms, ms.p1, 5.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), 4.0, "P1's Manapulation grants nothing for P2's staging")


# ---------------------------------------------------------------- fixtures

## Fill P1's four slots: Manablossom in slot 0, PLAIN (3 mana to play, 3 to stage) in slots 1-3.
func _fill_plain(player: PlayerState) -> void:
	F.put(player, 0, F.BLOSSOM)
	for slot in range(1, F.HAND_SIZE):
		F.put(player, slot, F.PLAIN)


## A match in which P1 has just played Manablossom over three PLAIN cards (slots 1-3 discounted by 1).
func _blossomed() -> MatchState:
	var ms := F.make()
	_fill_plain(ms.p1)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))
	return ms
