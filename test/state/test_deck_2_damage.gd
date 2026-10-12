extends TestCase

## Story 7-5a, PART B (AC 30-33, AC 39-42): ENRAGE AND LIFECHAIN -- the two stacking windows and the
## damage order they sit in -- headless, on the shared `Deck2Fixture`.
##
## THE ORDER IS PINNED WITH NUMBERS (AC 33, `7-5a/R12`/`R20`): (base + 2 x Enrages) x block x Execute x
## Bloodlust, at the test literals base 3 and block 0.3. This is the first non-commuting step in the damage
## funnel, and these are the tests `6-5a` review N1 said must land in the same breath.

const F := preload("res://test/deck_2_fixture.gd")
const LONG := 100000


# ================================================================ ENRAGE (AC 30-33)

## AC 30: Enrage costs its mana at staging and one green orb at activation, and opens a window.
func test_enrage_costs_mana_at_staging_and_an_orb_at_activation_and_opens_a_window() -> void:
	var ms := F.make()
	F.stage(ms, 0, F.BLOOD)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 2.0, "the staging pays Enrage's 2 mana")
	assert_eq(ms.p1.active_enrage_count(), 0, "staging alone opens nothing")
	F.set_orbs(ms, ms.p1, 0, 0, 1)
	F.activate(ms, 0)
	assert_eq(F.total_orbs(ms.p1), 0, "the activation spends the one green orb")
	assert_eq(ms.p1.active_enrage_count(), 1, "one window is running")
	assert_eq(ms.p1.to_snapshot()["enrage"],
		[[F.ENRAGE_TICKS + F.ENRAGE_TICKS_PER_ORB, F.ENRAGE_BONUS]], "one entry: its ticks and its +2")


## AC 30: while it runs, the caster's weapon hits deal +2 -- melee on the hero, melee on a unit, and the
## unblockable -- and a spell does not.
func test_enrage_adds_two_to_weapon_hits_on_heroes_and_units_and_not_to_spells() -> void:
	var melee := _enraged(1)
	assert_eq(F.melee_hit(melee, 0), F.HIT_DAMAGE + F.ENRAGE_BONUS, "melee on the hero: 3 + 2")
	var unit := _enraged(1)
	unit.p2.units.add(F.MINION_HP, 0)
	assert_eq(F.melee_hit_unit(unit, 0, 0), F.HERO_TO_UNIT + F.ENRAGE_BONUS, "melee on a unit: 3 + 2")
	var unblockable := _enraged(1)
	assert_eq(F.land_unblockable(unblockable, 0), 1, "the unblockable landed")
	assert_eq(unblockable.p2.hero.get_hp(), F.MAX_HP - (F.UNBLOCKABLE_DAMAGE + F.ENRAGE_BONUS),
		"the unblockable: 10 + 2")
	var spell := _enraged(1)
	F.play(spell, 0, F.BOLT)
	F.idle(spell, 3)
	assert_eq(spell.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE, "a spell is not a weapon hit: no bonus")
	# ...and the OTHER seat's hits are untouched by P1's Enrage.
	var other := _enraged(1)
	assert_eq(F.melee_hit(other, 1), F.HIT_DAMAGE, "the opponent's swing gains nothing from P1's Enrage")


## AC 31 (`7-5a/R18`): the window is the authored base plus the per-orb extension times the orbs held at
## activation BEFORE the activation orb is paid, all colours.
func test_the_window_grows_with_the_orbs_held_before_the_activation_orb_is_paid() -> void:
	for extra: Array in [[0, 0], [2, 0], [1, 1]]:
		var ms := F.make()
		F.stage(ms, 0, F.BLOOD)
		F.set_orbs(ms, ms.p1, int(extra[0]), int(extra[1]), 1)
		var held := F.total_orbs(ms.p1)
		F.activate(ms, 0)
		assert_eq(ms.p1.enrage_ticks, [F.ENRAGE_TICKS + F.ENRAGE_TICKS_PER_ORB * held] as Array[int],
			"holding %d orbs (the activation orb included, all colours): base + per-orb x %d" % [held, held])
		assert_eq(F.total_orbs(ms.p1), held - 1, "exactly the one green orb was then paid")


## AC 32 (`7-5a/R9`/`R22`): Enrages STACK -- each adds +2 for its own INDEPENDENT window; a second one is
## neither refused nor a refresh of the first.
func test_enrages_stack_as_independent_windows() -> void:
	var ms := F.make()
	var rejections := F.rejections(ms.p1)
	F.pitch(ms, 0, F.BLOOD)
	F.idle(ms, 20)
	var first_remaining: int = ms.p1.enrage_ticks[0]
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.BLOOD)
	assert_true(rejections.is_empty(), "a second Enrage is never refused")
	assert_eq(ms.p1.active_enrage_count(), 2, "two windows run side by side")
	assert_true(ms.p1.enrage_ticks[0] < first_remaining and ms.p1.enrage_ticks[0] > 0,
		"the FIRST window kept counting down -- the second did not refresh it")
	assert_eq(ms.p1.enrage_damage_bonus(), 2.0 * F.ENRAGE_BONUS, "two Enrages are +2 each: +4")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE + 2.0 * F.ENRAGE_BONUS, "a hit under both deals 3 + 4")
	# The first window expires on its own schedule; the second runs on, alone.
	F.idle(ms, ms.p1.enrage_ticks[0])
	assert_eq(ms.p1.active_enrage_count(), 1, "the first window has expired; the second is still running")
	assert_eq(ms.p1.enrage_damage_bonus(), F.ENRAGE_BONUS, "one window left: +2")


## AC 32: the timed-rule seat is UNCHANGED -- still six fixed slots, and an Enrage occupies none of them.
func test_enrage_does_not_use_the_timed_rule_seat() -> void:
	var ms := _enraged(2)
	assert_eq(PlayerState.RULE_COUNT, 6, "the timed-rule seat still has exactly six slots (N10)")
	for kind in PlayerState.RULE_COUNT:
		assert_false(ms.p1.is_rule_active(kind), "rule slot %d is not running under two Enrages" % kind)
	assert_eq((ms.p1.to_snapshot()["timed_rules"] as Array).size(), 6, "...and the `timed_rules` key is unmoved")


## AC 33: one Enrage, BLOCKED: (3 + 2) x 0.3 = 1.5 -- NOT 3 x 0.3 + 2 = 2.9. The block reduces the bonus too.
func test_order_one_enrage_blocked_is_one_point_five() -> void:
	var ms := _enraged(1)
	assert_almost_eq(F.melee_hit(ms, 0, true), 1.5, 0.0001, "(3 + 2) x 0.3 = 1.5")


## AC 33: two Enrages, BLOCKED: (3 + 4) x 0.3 = 2.1.
func test_order_two_enrages_blocked_is_two_point_one() -> void:
	var ms := _enraged(2)
	assert_almost_eq(F.melee_hit(ms, 0, true), 2.1, 0.0001, "(3 + 4) x 0.3 = 2.1")


## AC 33: one Enrage, CLEAN, one Execute: (3 + 2) x 3 = 15 -- the bonus is tripled with the base.
func test_order_one_enrage_clean_with_execute_is_fifteen() -> void:
	var ms := _enraged(1)
	ms.p1.add_execute_charge(F.EXECUTE_MULTIPLIER)
	assert_almost_eq(F.melee_hit(ms, 0), 15.0, 0.0001, "(3 + 2) x 3 = 15")
	assert_eq(ms.p1.execute_charges, 0, "the Execute charge was consumed")


## AC 33: with a test-literal Bloodlust 1.5 as well: (3 + 2) x 1.5 x 3 = 22.5.
func test_order_one_enrage_clean_with_execute_and_bloodlust_is_twenty_two_point_five() -> void:
	var ms := _enraged(1)
	ms.p1.add_execute_charge(F.EXECUTE_MULTIPLIER)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 1.5, 1.0)
	assert_almost_eq(F.melee_hit(ms, 0), 22.5, 0.0001, "(3 + 2) x 1.5 x 3 = 22.5")


## AC 33, the order's last pair: a BLOCKED hit under Enrage, Execute and Bloodlust is NOT tripled (Execute
## is kept) but Bloodlust still multiplies: (3 + 2) x 0.3 x 1.5 = 2.25.
func test_order_blocked_keeps_execute_and_still_takes_bloodlust() -> void:
	var ms := _enraged(1)
	ms.p1.add_execute_charge(F.EXECUTE_MULTIPLIER)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 1.5, 1.0)
	assert_almost_eq(F.melee_hit(ms, 0, true), 2.25, 0.0001, "(3 + 2) x 0.3 x 1.5 = 2.25")
	assert_eq(ms.p1.execute_charges, 1, "a blocked hit keeps the Execute charge")


# ================================================================ LIFECHAIN (AC 39-42)

## AC 39: Lifechain costs its mana at staging and one green orb at activation, and opens its window.
func test_lifechain_costs_mana_at_staging_and_an_orb_at_activation_and_opens_a_window() -> void:
	var ms := F.make()
	F.stage(ms, 0, F.CHAIN)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 3.0, "the staging pays Lifechain's 3 mana")
	assert_false(ms.p1.is_lifechain_covered(), "staging alone covers nothing")
	F.set_orbs(ms, ms.p1, 0, 0, 1)
	F.activate(ms, 0)
	assert_eq(F.total_orbs(ms.p1), 0, "the activation spends the one green orb")
	assert_true(ms.p1.is_lifechain_covered(), "the hero is covered")
	assert_eq(ms.p1.to_snapshot()["lifechain"], [F.LIFECHAIN_TICKS], "one window at its authored length")


## AC 39 (`7-5a/R9`): several Lifechains never deepen the split, and cover lasts until the LATEST ends.
func test_overlapping_lifechains_extend_cover_and_never_deepen_the_split() -> void:
	var ms := F.make()
	var rejections := F.rejections(ms.p2)
	F.pitch(ms, 1, F.CHAIN)
	F.idle(ms, 30)
	F.set_mana(ms, ms.p2, F.MAX_MANA)
	F.pitch(ms, 1, F.CHAIN)
	assert_true(rejections.is_empty(), "a second Lifechain is never refused for being active")
	assert_eq(ms.p2.lifechain_ticks.size(), 2, "two windows are held")
	ms.p2.units.add(F.MINION_HP, 0)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE / 2.0,
		"under TWO Lifechains the split is still hero + minions: 6 / 2 = 3 to the hero")
	# Run the FIRST window out: cover holds until the latest window ends.
	F.idle(ms, ms.p2.lifechain_ticks[0])
	assert_eq(ms.p2.lifechain_ticks[0], 0, "the first window has ended")
	assert_true(ms.p2.is_lifechain_covered(), "cover lasts until the LATEST window ends")
	F.idle(ms, ms.p2.lifechain_ticks[1])
	assert_false(ms.p2.is_lifechain_covered(), "...and ends with it")


## AC 40's own example: 6 damage, two minions, one with 1 hp left -- shares of 2; the 1-hp minion takes 1
## and dies leaving a normal corpse, its 1 overflow goes to the hero, who takes 3.
func test_the_split_is_equal_and_a_dying_minions_overflow_goes_to_the_hero() -> void:
	var ms := _lifechained()
	ms.p2.units.add(F.MINION_HP, 0)
	ms.p2.units.add(F.MINION_HP, 0)
	ms.p2.units.apply_damage_at(0, F.MINION_HP - 1.0, 0)
	assert_eq(ms.p2.units.hp_at(0), 1.0, "fixture: minion 0 is at 1 hp")
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - 3.0, "the hero takes its share 2 plus the 1 overflow: 3")
	assert_false(ms.p2.units.is_alive_at(0), "the 1-hp minion took 1 and died")
	assert_true(ms.p2.units.has_corpse_at(0), "...leaving a normal corpse")
	assert_eq(ms.p2.units.hp_at(1), F.MINION_HP - 2.0, "the healthy minion took its full share of 2")


## AC 40: with NO living minion the hero takes the whole instance; TOTEMS are not minions and take nothing.
func test_no_living_minion_means_the_hero_takes_it_all_and_totems_are_excluded() -> void:
	var alone := _lifechained()
	F.play(alone, 0, F.BOLT)
	F.idle(alone, 3)
	assert_eq(alone.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE, "no minion: the hero takes all 6")
	var totem := _lifechained()
	totem.p2.units.add(F.MINION_HP, 1)
	F.play(totem, 0, F.BOLT)
	F.idle(totem, 3)
	assert_eq(totem.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE, "a totem is not a minion: the hero takes all 6")
	assert_eq(totem.p2.units.hp_at(0), F.MINION_HP, "the totem is untouched")
	var dead := _lifechained()
	dead.p2.units.add(F.MINION_HP, 0)
	dead.p2.units.kill_at(0, 100)
	F.play(dead, 0, F.BOLT)
	F.idle(dead, 3)
	assert_eq(dead.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE, "a DEAD minion is not counted: the hero takes all 6")


## AC 40: every damage SOURCE is split -- a melee hit and an unblockable, as well as the spell above.
func test_melee_and_unblockable_instances_are_split_too() -> void:
	var melee := _lifechained()
	melee.p2.units.add(F.MINION_HP, 0)
	melee.p2.units.add(F.MINION_HP, 0)
	assert_eq(F.melee_hit(melee, 0), F.HIT_DAMAGE / 3.0, "a 3-damage melee hit: 1 to the hero")
	assert_eq(melee.p2.units.hp_at(0), F.MINION_HP - 1.0, "...1 to the first minion")
	assert_eq(melee.p2.units.hp_at(1), F.MINION_HP - 1.0, "...1 to the second")
	var unblockable := _lifechained()
	unblockable.p2.units.add(F.MINION_HP, 0)
	assert_eq(F.land_unblockable(unblockable, 0), 1, "the unblockable landed")
	assert_eq(unblockable.p2.hero.get_hp(), F.MAX_HP - F.UNBLOCKABLE_DAMAGE / 2.0, "10 split two ways: 5 to the hero")
	assert_eq(unblockable.p2.units.hp_at(0), F.MINION_HP - F.UNBLOCKABLE_DAMAGE / 2.0, "...5 to the minion")
	assert_eq(unblockable.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"AC 41: the hero's own rules are unchanged -- an unblockable still knocks it down")


## AC 41 (`7-5a/R8`): STONESKIN RESOLVES FIRST -- it absorbs the whole instance, nothing is split, and no
## minion is touched.
func test_stoneskin_absorbs_the_whole_instance_before_lifechain_splits_it() -> void:
	var ms := _lifechained()
	ms.p2.add_stoneskin_charge()
	ms.p2.units.add(F.MINION_HP, 0)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "Stoneskin absorbed the instance")
	assert_eq(ms.p2.units.hp_at(0), F.MINION_HP, "nothing was split: the minion is untouched")
	assert_eq(ms.p2.stoneskin_charges, 0, "the charge is consumed")


## AC 41 (`7-5a/R28`): Vampiric Aura heals off the hero's hp delta only -- the hero's SHARE.
func test_vampiric_aura_heals_off_the_heros_share_only() -> void:
	var ms := _lifechained()
	ms.p2.units.add(F.MINION_HP, 0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, 0.5, 0.0)
	F.set_hp(ms, ms.p1, 50.0)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - 3.0, "the hero's share of the 6 is 3")
	assert_eq(ms.p1.hero.get_hp(), 50.0 + 1.5, "the aura heals half of the hero's SHARE (1.5), not of the 6")


## AC 29 (`7-5a/R17`) / AC 40: HP PAID BY BLOODMAGIC IS NOT A DAMAGE INSTANCE -- it is not split.
func test_hp_paid_by_bloodmagic_is_not_split_by_lifechain() -> void:
	var ms := F.make()
	ms.p1.open_lifechain(F.LIFECHAIN_TICKS)
	ms.p1.units.add(F.MINION_HP, 0)
	F.play(ms, 0, F.BLOOD)
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP - F.BLOOD_HP, "the caster paid the whole HP price itself")
	assert_eq(ms.p1.units.hp_at(0), F.MINION_HP, "the minion took none of it")


## AC 42 (`7-5a/R13`): a Counterspell on a card that hit a Lifechained hero refunds ONLY THE HERO'S SHARE;
## minion shares and minion deaths stay.
func test_a_counter_on_a_card_that_hit_a_lifechained_hero_refunds_only_the_heros_share() -> void:
	var ms := _lifechained()
	ms.p2.units.add(F.MINION_HP, 0)
	ms.p2.units.add(F.MINION_HP, 0)
	ms.p2.units.apply_damage_at(0, F.MINION_HP - 1.0, 0)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - 3.0, "fixture: the hero took 3 of the 6")
	assert_eq(float((ms.p1.to_snapshot()["reversal"] as Array)[5]), 3.0,
		"the bolt's record holds the HERO's share only -- the hp actually removed from the hero")
	# Wait out the bolt's stun so P2 can pitch its Counterspell.
	F.idle(ms, F.BOLT_STUN_TICKS + 2)
	assert_true(F.counter(ms, 1), "P2 counters the bolt")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the hero's 3 is refunded")
	assert_false(ms.p2.units.is_alive_at(0), "the minion its share killed STAYS dead")
	assert_eq(ms.p2.units.hp_at(1), F.MINION_HP - 2.0, "the surviving minion's share is NOT refunded")


# ---------------------------------------------------------------- fixtures

## A match in which P1 has `windows` Enrage windows running for the whole test.
func _enraged(windows: int) -> MatchState:
	var ms := F.make()
	for _w in windows:
		ms.p1.open_enrage(LONG, F.ENRAGE_BONUS)
	return ms


## A match in which P2 (the defender) is covered by one long Lifechain window.
func _lifechained() -> MatchState:
	var ms := F.make()
	ms.p2.open_lifechain(LONG)
	return ms
