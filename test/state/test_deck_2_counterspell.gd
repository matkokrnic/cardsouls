extends TestCase

## Story 7-5a, PART B (AC 43-49, `7-5a/R11`/`R30`): COUNTERSPELL AGAINST EVERY NEW HALF -- headless, on the
## shared `Deck2Fixture`. P1 resolves the half under test; P2 pitches the Counterspell.
##
## THE RULE: a Counterspell removes exactly what that ONE cast added. PENDING and TIMED products (a charge,
## a window, a discount) are removed and what they already did stays; INSTANT products (Bloodmagic,
## Manapulation) are reversed by the amount actually applied. Nothing left to remove is NO TARGET, refused
## through the existing path BEFORE the orb spend.
##
## EACH HALF IS TESTED PLAIN, and the charge / window / discount halves also STACKED (two held, one counter
## leaves exactly one) and ALREADY USED (consumed, absorbed, expired, gone from hand -- no target).

const F := preload("res://test/deck_2_fixture.gd")


# ================================================================ SETUP (AC 44)

func test_counter_removes_the_setup_charge() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	var mana_after_cast := ms.p1.mana.get_current()
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Setup")
	assert_eq(ms.p1.to_snapshot()["setup"], [0, 0.0], "the charge is removed")
	assert_eq(ms.p1.mana.get_current(), mana_after_cast, "the countered player gets nothing back: mana stays spent")
	assert_false(F.counter(ms, 1), "an already-countered Setup is no longer a target (AC 10 of 6-5f)")


func test_counter_on_a_stacked_setup_leaves_exactly_one() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	F.play(ms, 0, F.SETUP)
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.setup_charges, 1, "two held, one counter: exactly one is left")
	assert_eq(ms.p1.setup_orb_multiplier, F.SETUP_MULTIPLIER, "...still carrying its multiplier")


## AC 44 (`7-5a/R30`): a Setup ALREADY SPENT on an attack in flight is gone -- no target, and the in-flight
## doubling stays.
func test_a_setup_spent_on_an_attack_in_flight_is_no_target_and_the_doubling_stays() -> void:
	var balance := F.config()
	balance.unblockable_chargeup_seconds = F.ticks_to_seconds(10)
	var ms := F.make(balance)
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 0), "P1 presses: the charge is spent, the attack carries Setup")
	assert_false(F.counter(ms, 1), "no charge is left to take: no target")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], F.SETUP_MULTIPLIER, "the attack in flight still carries Setup")
	assert_eq(F.fly_unblockable(ms, 0), 1, "the attack lands")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2 * F.ORB_GRANT, "...and still grants double")


# ================================================================ EXECUTE (AC 44)

func test_counter_removes_the_execute_charge() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.SETUP)
	assert_eq(ms.p1.execute_charges, 1, "fixture: P1 holds an Execute charge")
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Execute")
	assert_eq(ms.p1.to_snapshot()["execute"], [0, 0.0], "the charge is removed")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE, "the next hit is a plain one")


func test_counter_on_a_stacked_execute_leaves_exactly_one() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.SETUP)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.SETUP)
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.execute_charges, 1, "two held, one counter: exactly one is left")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, "...and it still triples a hit")


func test_a_consumed_execute_is_no_target() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.SETUP)
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, "the charge is consumed by a hit")
	var hp_after_hit := ms.p2.hero.get_hp()
	assert_false(F.counter(ms, 1), "a consumed Execute leaves nothing to remove: no target")
	assert_eq(ms.p2.hero.get_hp(), hp_after_hit, "the tripled damage already dealt stays dealt")


# ================================================================ STONESKIN (AC 44)

func test_counter_removes_the_stoneskin_charge() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.STONE)
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Stoneskin")
	assert_eq(ms.p1.stoneskin_charges, 0, "the charge is removed")
	assert_eq(F.melee_hit(ms, 1), F.HIT_DAMAGE, "the next hit on P1 lands in full")


func test_counter_on_a_stacked_stoneskin_leaves_exactly_one() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.STONE)
	F.pitch(ms, 0, F.STONE)
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.stoneskin_charges, 1, "two held, one counter: exactly one is left")


func test_an_absorbed_stoneskin_is_no_target() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.STONE)
	assert_eq(F.melee_hit(ms, 1), 0.0, "the charge absorbs a hit")
	assert_false(F.counter(ms, 1), "an absorbed Stoneskin leaves nothing to remove: no target")
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP, "the absorption already done stays done")


# ================================================================ ENRAGE (AC 45)

func test_counter_ends_the_enrage_window_and_damage_already_dealt_keeps_its_bonus() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.BLOOD)
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE + F.ENRAGE_BONUS, "a hit under Enrage deals 3 + 2")
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Enrage")
	assert_eq(ms.p1.active_enrage_count(), 0, "that cast's window is ended")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - (F.HIT_DAMAGE + F.ENRAGE_BONUS),
		"damage already dealt keeps the bonus -- nothing is refunded")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE, "the next hit is a plain one")


## AC 45: STACKED -- the counter ends THAT cast's own window only; the other runs on.
func test_counter_on_a_stacked_enrage_ends_only_its_own_window() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.BLOOD)
	F.idle(ms, 10)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.BLOOD)
	var first_remaining: int = ms.p1.enrage_ticks[0]
	assert_true(F.counter(ms, 1), "the Counterspell resolves against the SECOND Enrage")
	assert_eq(ms.p1.active_enrage_count(), 1, "exactly one window is left")
	assert_eq(ms.p1.enrage_ticks[1], 0, "the countered (second) cast's own window is the one that ended")
	assert_true(ms.p1.enrage_ticks[0] > 0 and ms.p1.enrage_ticks[0] <= first_remaining,
		"the first window runs on, untouched")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE + F.ENRAGE_BONUS, "one Enrage left: +2")


func test_an_expired_enrage_is_no_target() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.BLOOD)
	F.idle(ms, ms.p1.enrage_ticks[0])
	assert_eq(ms.p1.active_enrage_count(), 0, "fixture: the window ran out")
	assert_false(F.counter(ms, 1), "an expired Enrage leaves nothing to end: no target")


# ================================================================ LIFECHAIN (AC 45)

func test_counter_ends_the_lifechain_window_and_damage_already_redirected_stays() -> void:
	var ms := F.make()
	ms.p1.units.add(F.MINION_HP, 0)
	F.pitch(ms, 0, F.CHAIN)
	assert_eq(F.melee_hit(ms, 1), F.HIT_DAMAGE / 2.0, "a hit on the covered hero is split with its minion")
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Lifechain")
	assert_false(ms.p1.is_lifechain_covered(), "that cast's window is ended")
	assert_eq(ms.p1.units.hp_at(0), F.MINION_HP - F.HIT_DAMAGE / 2.0, "damage already redirected stays redirected")
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP - F.HIT_DAMAGE / 2.0, "...and the hero is not handed it back")
	assert_eq(F.melee_hit(ms, 1), F.HIT_DAMAGE, "the next hit lands on the hero in full")


## AC 45: STACKED -- cover lasts until the latest window LEFT.
func test_counter_on_a_stacked_lifechain_leaves_the_other_window_covering() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.CHAIN)
	F.idle(ms, 10)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.CHAIN)
	assert_true(F.counter(ms, 1), "the Counterspell resolves against the SECOND Lifechain")
	assert_eq(ms.p1.lifechain_ticks[1], 0, "the countered cast's own window ended")
	assert_true(ms.p1.lifechain_ticks[0] > 0, "the first window runs on")
	assert_true(ms.p1.is_lifechain_covered(), "cover lasts until the latest window left")


func test_an_expired_lifechain_is_no_target() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.CHAIN)
	F.idle(ms, ms.p1.lifechain_ticks[0])
	assert_false(ms.p1.is_lifechain_covered(), "fixture: the window ran out")
	assert_false(F.counter(ms, 1), "an expired Lifechain leaves nothing to end: no target")


# ================================================================ MANABLOSSOM (AC 46)

func test_counter_removes_the_discount_from_the_cards_still_in_hand() -> void:
	var ms := _blossomed()
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Manablossom")
	assert_eq(ms.p1.hand.discounts(), [0.0, 0.0, 0.0, 0.0] as Array[float], "every touched card is back to full price")
	assert_eq(ms.p1.to_snapshot()["hand_discount"], [0.0, 0.0, 0.0, 0.0], "...and the raw sums are back to zero")


## AC 46: cards already gone from the hand KEEP WHAT THEY SAVED; only the cards still in hand are touched.
func test_cards_already_staged_keep_what_they_saved() -> void:
	var ms := _blossomed()
	var mana := ms.p1.mana.get_current()
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_eq(ms.p1.mana.get_current(), mana - (F.PLAIN_MANA - 1.0), "fixture: slot 1 staged for 1 less")
	var mana_after_stage := ms.p1.mana.get_current()
	ms.p1.hand.fill_at(1, F.BOLT)   # a card drawn into the vacated slot
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.mana.get_current(), mana_after_stage, "the mana already saved is not clawed back")
	assert_eq(ms.p1.to_snapshot()["hand_discount"], [0.0, 0.0, 0.0, 0.0],
		"the two cards still in hand lost the discount, and the card drawn into slot 1 was never touched "
		+ "(its raw sum is 0, not -1)")


## AC 46: STACKED -- two Manablossoms, one counter: exactly the second cast's amount comes back out.
func test_counter_on_a_stacked_manablossom_removes_only_its_own_amount() -> void:
	var ms := _blossomed()
	F.put(ms.p1, 0, F.BLOSSOM)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.to_snapshot()["hand_discount"], [0.0, 2.0, 2.0, 2.0], "fixture: two Manablossoms, raw sum 2")
	assert_true(F.counter(ms, 1), "the Counterspell resolves against the SECOND Manablossom")
	assert_eq(ms.p1.to_snapshot()["hand_discount"], [0.0, 1.0, 1.0, 1.0], "the first cast's 1 is still there")


## AC 46: with NONE of its cards left in hand there is no target.
func test_a_manablossom_with_no_touched_card_left_in_hand_is_no_target() -> void:
	var ms := F.make()
	F.put(ms.p1, 0, F.BLOSSOM)
	F.put(ms.p1, 1, F.PLAIN)
	ms.p1.hand.remove_at(2)
	ms.p1.hand.remove_at(3)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.hand.discount_at(1), F.BLOSSOM_DISCOUNT, "fixture: the one card in hand is discounted")
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.PITCH))
	assert_true(ms.pitch.is_staged(0), "fixture: that card was staged -- it left the hand")
	assert_false(F.counter(ms, 1), "nothing it touched is still in hand: no target")


## AC 46, review F1: a card that left the hand BY AN UNBLOCKABLE PRESS keeps what it saved too. The record drops
## its slot at that hand-leave site, so a replacement drawn into the vacated slot is never touched by the counter
## (its raw sum stays 0, not -1) and the cards still in hand lose the discount.
func test_cards_that_left_by_an_unblockable_press_keep_what_they_saved() -> void:
	var ms := _blossomed()
	assert_true(F.press_unblockable(ms, 0, F.PLAIN, 1), "fixture: slot 1's discounted card leaves by an unblockable press")
	ms.p1.hand.fill_at(1, F.BOLT)   # the replacement, drawn into the vacated slot
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Manablossom")
	assert_eq(ms.p1.to_snapshot()["hand_discount"], [0.0, 0.0, 0.0, 0.0],
		"the two cards still in hand lost the discount; the replacement in slot 1 was never touched (0, not -1)")


## AC 46, review F1: the same for a card that left by a DEFENCE press. P2 casts Manablossom, P1 presses an
## unblockable (green, so P2's red answer does not colour-counter it), P2 answers from a discounted slot.
func test_cards_that_left_by_a_defence_press_keep_what_they_saved() -> void:
	var ms := F.make()
	F.put(ms.p2, 0, F.BLOSSOM)
	for slot in range(1, F.HAND_SIZE):
		F.put(ms.p2, slot, F.PLAIN)
	F.act(ms, 1, F.card_intent(0, Enums.ModeKind.BASIC))
	assert_eq(ms.p2.to_snapshot()["hand_discount"], [0.0, 1.0, 1.0, 1.0], "fixture: P2's Manablossom resolved")
	assert_true(F.press_unblockable(ms, 0, F.STONE, 1), "fixture: P1 attacks with an unblockable")
	F.act(ms, 1, F.card_intent(2, Enums.ModeKind.DEFENSE))
	assert_true(ms.p2.hand.is_slot_empty(2), "fixture: slot 2's card left the hand by the defence press")
	ms.p2.hand.fill_at(2, F.BOLT)   # the replacement, drawn into the vacated slot
	F.fly_unblockable(ms, 0)
	assert_true(F.counter(ms, 0), "P1's Counterspell resolves against Manablossom")
	assert_eq(ms.p2.to_snapshot()["hand_discount"], [0.0, 0.0, 0.0, 0.0],
		"slots 1 and 3 lost the discount; the replacement in slot 2 was never touched (0, not -1)")


## AC 46/AC 48, review F1: when the ONLY touched card left by an unblockable press there is no target.
func test_a_manablossom_whose_only_card_left_by_an_unblockable_press_is_no_target() -> void:
	var ms := F.make()
	F.put(ms.p1, 0, F.BLOSSOM)
	F.put(ms.p1, 1, F.PLAIN)
	ms.p1.hand.remove_at(2)
	ms.p1.hand.remove_at(3)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))
	assert_eq(ms.p1.hand.discount_at(1), F.BLOSSOM_DISCOUNT, "fixture: the one card in hand is discounted")
	F.act(ms, 0, F.card_intent(1, Enums.ModeKind.UNBLOCKABLE))
	assert_true(ms.p1.hero.action_state == HeroState.ActionState.CHARGING and ms.p1.hand.is_slot_empty(1),
		"fixture: that card left by an unblockable press")
	assert_false(F.counter(ms, 1), "nothing it touched is still in hand: no target")


## ...and likewise when the only touched card left by a DEFENCE press.
func test_a_manablossom_whose_only_card_left_by_a_defence_press_is_no_target() -> void:
	var ms := F.make()
	F.put(ms.p2, 0, F.BLOSSOM)
	F.put(ms.p2, 1, F.PLAIN)
	ms.p2.hand.remove_at(2)
	ms.p2.hand.remove_at(3)
	F.act(ms, 1, F.card_intent(0, Enums.ModeKind.BASIC))
	assert_eq(ms.p2.hand.discount_at(1), F.BLOSSOM_DISCOUNT, "fixture: the one card in hand is discounted")
	assert_true(F.press_unblockable(ms, 0, F.STONE, 1), "fixture: P1 attacks with an unblockable")
	F.act(ms, 1, F.card_intent(1, Enums.ModeKind.DEFENSE))
	assert_true(ms.p2.hand.is_slot_empty(1), "fixture: that card left by the defence press")
	F.fly_unblockable(ms, 0)
	assert_false(F.counter(ms, 0), "nothing it touched is still in hand: no target")


# ================================================================ BLOODMAGIC / MANAPULATION (AC 47)

func test_counter_refunds_bloodmagics_hp_and_claws_back_its_mana() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 2.0)
	F.play(ms, 0, F.BLOOD)
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Bloodmagic")
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP, "the HP paid is refunded")
	assert_eq(ms.p1.mana.get_current(), 2.0, "the mana gained is clawed back")


## AC 47's own example: cast at 8 of 10 mana gaining 2 -- the counter claws back 2, not 4.
func test_counter_claws_back_only_the_mana_bloodmagic_actually_gave() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 8.0)
	F.play(ms, 0, F.BLOOD)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA, "fixture: the cast gained 2 (clamped at 10)")
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.mana.get_current(), 8.0, "the counter claws back 2 -- the amount actually applied")


## AC 47: the HP refund stops at the maximum, and the mana claw-back stops at the floor 0.
func test_bloodmagics_reversal_clamps_hp_at_max_and_mana_at_zero() -> void:
	var ms := F.make()
	F.set_mana(ms, ms.p1, 2.0)
	F.play(ms, 0, F.BLOOD)
	F.set_hp(ms, ms.p1, F.MAX_HP - 4.0)   # healed most of the way back by something else
	F.set_mana(ms, ms.p1, 1.0)            # and most of the mana already spent
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP, "the refund is clamped at max hp -- never an overheal")
	assert_eq(ms.p1.mana.get_current(), 0.0, "the claw-back is floored at 0")


func test_counter_claws_back_manapulations_mana() -> void:
	var ms := F.make()
	for _n in 3:
		F.stage(ms, 0, F.BOLT)
		ms.pitch.clear(0)
	F.set_mana(ms, ms.p1, 4.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), 6.0, "fixture: 4 - 1 + 3")
	assert_true(F.counter(ms, 1), "the Counterspell resolves against Manapulation")
	assert_eq(ms.p1.mana.get_current(), 3.0, "the 3 it gave are clawed back (the card's own 1 stays spent)")
	assert_eq(ms.p1.stagings_this_round, 3, "the staging count is not touched")


## AC 47: Manapulation's claw-back is the amount ACTUALLY applied, floored at 0.
func test_manapulations_claw_back_is_the_applied_amount_floored_at_zero() -> void:
	var ms := F.make()
	for _n in 5:
		F.stage(ms, 0, F.BOLT)
		ms.pitch.clear(0)
	F.set_mana(ms, ms.p1, 8.0)
	F.play(ms, 0, F.PULATION)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA, "fixture: 8 - 1 + 5 clamped at 10, so 3 were gained")
	F.set_mana(ms, ms.p1, 2.0)
	assert_true(F.counter(ms, 1), "the Counterspell resolves")
	assert_eq(ms.p1.mana.get_current(), 0.0, "3 clawed back from 2: floored at 0")


# ================================================================ NO TARGET (AC 48)

## AC 48: NO TARGET IS REFUSED THROUGH THE EXISTING PATH, BEFORE THE ORB SPEND -- the named reason, the orb
## still held, the Counterspell still staged, its staging mana spent.
func test_no_target_is_refused_before_the_orb_spend_through_the_existing_path() -> void:
	var ms := F.make()
	F.pitch(ms, 0, F.SETUP)
	F.melee_hit(ms, 0)   # the Execute charge is consumed
	F.stage(ms, 1, F.COUNTER, 3)
	ms.p2.orbs.add(Enums.CardColor.BLUE, 1)
	ms.drain_signals()
	var rejections := F.rejections(ms.p2)
	var mana_before := ms.p2.mana.get_current()
	F.activate(ms, 1)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"refused with the EXISTING no-target reason -- no new token")
	assert_eq(ms.p2.orbs.get_count(Enums.CardColor.BLUE), 1, "the orb is NOT spent")
	assert_true(ms.pitch.is_staged(1), "the Counterspell stays staged")
	assert_eq(ms.p2.mana.get_current(), mana_before, "no further mana moved (the staging mana stays spent)")


# ---------------------------------------------------------------- fixtures

## A match in which P1 has just played Manablossom over three PLAIN cards (slots 1-3 discounted by 1).
func _blossomed() -> MatchState:
	var ms := F.make()
	F.put(ms.p1, 0, F.BLOSSOM)
	for slot in range(1, F.HAND_SIZE):
		F.put(ms.p1, slot, F.PLAIN)
	F.act(ms, 0, F.card_intent(0, Enums.ModeKind.BASIC))
	return ms
