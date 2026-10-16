extends TestCase

## Story 7-5b (AC 12-15): ELEMENTAL FURY, headless. The activation gate, the volley, the colour payloads,
## the flight's target, the defences and the Counterspell reversal. Test literals only (`BC/R3`).

const Fx := preload("res://test/deck_2_bodies_fixture.gd")
const F := preload("res://test/deck_2_fixture.gd")


## Stage Fury on P1 and set P1's orbs to (red, blue, green) BEFORE the activation press.
func _staged(ms: MatchState, red: int, blue: int, green: int) -> void:
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.stage(ms, 0, Fx.FURY, 2)
	F.set_orbs(ms, ms.p1, red, blue, green)


func _colors(ms: MatchState) -> Array:
	var out: Array = []
	for shot in ms.p1.projectiles.size():
		out.append(ms.p1.projectiles.color_at(shot))
	return out


# ---------------------------------------------------------------- AC 12: the gate

## AC 12 (`7-5b/R5`): with ONLY the blue orb held, the activation is refused with a named reason; no orb is
## spent, the card stays staged with its countdown running, and the staging mana stays spent.
func test_with_no_orb_left_after_the_price_the_activation_is_refused() -> void:
	var ms := Fx.make()
	_staged(ms, 0, 1, 0)
	var mana_after_staging := ms.p1.mana.get_current()
	var fizzle_before := int(ms.pitch.to_snapshot()["p1"]["fizzle"]["elapsed_ticks"])
	var rejections := F.rejections(ms.p1)
	F.activate(ms, 0)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_ORB_AFTER_PRICE]], "refused with the named reason")
	assert_eq(MatchState.REASON_NO_ORB_AFTER_PRICE, &"no_orb_after_price", "...which reads as it says")
	assert_eq(F.total_orbs(ms.p1), 1, "no orb is spent")
	assert_true(ms.pitch.is_staged(0), "the card stays staged")
	assert_true(int(ms.pitch.to_snapshot()["p1"]["fizzle"]["elapsed_ticks"]) > fizzle_before,
		"...its countdown still running")
	assert_eq(ms.p1.mana.get_current(), mana_after_staging, "the staging mana stays spent (no refund)")
	assert_eq(ms.p1.projectiles.size(), 0, "nothing fires")


## AC 12: the press is repeatable -- once another orb is held, the SAME staged card activates.
func test_the_refused_card_activates_once_another_orb_is_held() -> void:
	var ms := Fx.make()
	_staged(ms, 0, 1, 0)
	F.activate(ms, 0)
	assert_true(ms.pitch.is_staged(0), "sanity: refused and still staged")
	ms.p1.orbs.add(Enums.CardColor.GREEN, 1)
	ms.drain_signals()
	F.activate(ms, 0)
	assert_false(ms.pitch.is_staged(0), "the same card activates")
	assert_eq(_colors(ms), [Enums.CardColor.GREEN], "...firing one projectile for the one orb left")


# ---------------------------------------------------------------- AC 13: the volley

## AC 13 (`7-5b/R7`): one projectile per orb still held after the blue orb is paid, in the fixed order red,
## blue, green, `volley_interval` apart, the first at the activation; the held orbs are NOT consumed.
func test_the_volley_fires_one_per_orb_in_colour_order_and_spends_only_the_price() -> void:
	var ms := Fx.make()
	_staged(ms, 2, 2, 1)
	F.activate(ms, 0)
	assert_eq(_colors(ms), [Enums.CardColor.RED], "the first projectile leaves at the activation")
	assert_eq([ms.p1.orbs.get_count(Enums.CardColor.RED), ms.p1.orbs.get_count(Enums.CardColor.BLUE),
			ms.p1.orbs.get_count(Enums.CardColor.GREEN)], [2, 1, 1],
		"the pool after = the pool before minus ONE blue orb")
	F.idle(ms, Fx.VOLLEY_TICKS - 1)
	assert_eq(ms.p1.projectiles.size(), 1, "nothing until the interval has passed")
	F.idle(ms, 1)
	assert_eq(ms.p1.projectiles.size(), 2, "the second on the interval tick")
	F.idle(ms, 2 * Fx.VOLLEY_TICKS)
	assert_eq(_colors(ms), [Enums.CardColor.RED, Enums.CardColor.RED, Enums.CardColor.BLUE,
			Enums.CardColor.GREEN], "four projectiles, red, red, blue, green")
	assert_false(ms.p1.has_pending_volley(), "...and nothing more is owed")
	F.idle(ms, 3 * Fx.VOLLEY_TICKS)
	assert_eq(ms.p1.projectiles.size(), 4, "exactly one per orb")


## AC 13/AC 14 (`7-5b/R6`): every projectile targets the OPPOSING HERO, even with the caster locked on a
## unit -- no lock-target routing. Red carries the authored damage; blue and green carry none.
func test_every_projectile_targets_the_opposing_hero_whatever_the_lock() -> void:
	var ms := Fx.make()
	var unit := Fx.add_unit(ms, 1, CardEffectResolver.KIND_MINION)
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = unit
	_staged(ms, 1, 2, 1)   # one blue pays the price: red, blue, green remain
	F.activate(ms, 0)
	F.idle(ms, 3 * Fx.VOLLEY_TICKS)
	assert_eq(ms.p1.projectiles.size(), 3, "three projectiles")
	for shot in 3:
		assert_eq([ms.p1.projectiles.target_slot_at(shot), ms.p1.projectiles.target_index_at(shot)],
			[1, TargetingService.HERO_INDEX], "projectile %d aims at the opposing HERO, not the lock" % shot)
	assert_eq([ms.p1.projectiles.damage_at(0), ms.p1.projectiles.damage_at(1), ms.p1.projectiles.damage_at(2)],
			[Fx.RED_DAMAGE, 0.0, 0.0], "red carries the damage; blue and green none")


## AC 1: the spell layer OFF resolves the activation (the orb is spent) and fires nothing.
func test_with_the_spell_layer_off_fury_resolves_and_fires_nothing() -> void:
	var ms := Fx.make(Fx.flags_with(true, false))
	_staged(ms, 1, 1, 0)
	F.activate(ms, 0)
	assert_false(ms.pitch.is_staged(0), "the activation resolved")
	assert_eq(ms.p1.projectiles.size(), 0, "...and nothing fired")


# ---------------------------------------------------------------- AC 15: the colours

func _land(ms: MatchState, shot: int, facing := true) -> void:
	var dir := ms.p2.hero.facing if facing else -ms.p2.hero.facing
	ms.push_contact([0, MatchState.projectile_attacker_index(shot)], [1, TargetingService.HERO_INDEX],
			ms.p1.projectiles.flight_ticks_at(shot), dir, MatchState.CONTACT_STRIKE)


## AC 15: RED deals its damage; BLUE slows the struck hero with its own multiplier and duration and deals
## nothing; GREEN heals the CASTER and deals nothing.
func test_red_damages_blue_slows_and_green_heals_the_caster() -> void:
	var ms := Fx.make()
	F.set_hp(ms, ms.p1, 80.0)
	_staged(ms, 1, 2, 1)   # one blue pays the price: red, blue, green remain
	F.activate(ms, 0)
	F.idle(ms, 2 * Fx.VOLLEY_TICKS)
	_land(ms, 0)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.RED_DAMAGE, "red: the authored damage")
	_land(ms, 1)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.RED_DAMAGE, "blue: no damage")
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "blue: the struck hero is slowed")
	assert_eq(ms.p2.rule_a[PlayerState.RULE_FROSTBITE_SLOW], Fx.SLOW_MULT, "...by its own multiplier")
	_land(ms, 2)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.RED_DAMAGE, "green: no damage")
	assert_eq(ms.p1.hero.get_hp(), 80.0 + Fx.GREEN_HEAL, "green: the CASTER heals the authored amount")


## AC 15: the slow REFRESHES, never stacks -- a second blue landing restarts the window at the same
## multiplier.
func test_a_second_blue_landing_refreshes_the_slow_and_never_stacks() -> void:
	var ms := Fx.make()
	_staged(ms, 0, 3, 0)
	F.activate(ms, 0)
	F.idle(ms, Fx.VOLLEY_TICKS)
	_land(ms, 0)
	F.idle(ms, 10)
	var remaining := ms.p2.rule_windows[PlayerState.RULE_FROSTBITE_SLOW].remaining_ticks()
	_land(ms, 1)
	F.idle(ms, 1)
	assert_true(ms.p2.rule_windows[PlayerState.RULE_FROSTBITE_SLOW].remaining_ticks() > remaining,
		"the second landing RESTARTED the window")
	assert_eq(ms.p2.rule_a[PlayerState.RULE_FROSTBITE_SLOW], Fx.SLOW_MULT, "...at the same multiplier (no stack)")


## AC 15: a projectile that does not LAND does nothing -- a deflected green heals nobody, an i-frame-dropped
## blue slows nobody.
func test_a_projectile_that_does_not_land_has_no_effect() -> void:
	var ms := Fx.make()
	F.set_hp(ms, ms.p1, 80.0)
	_staged(ms, 0, 0, 1)
	ms.p1.orbs.add(Enums.CardColor.BLUE, 1)
	ms.drain_signals()
	_staged_activate_green(ms)
	_land(ms, 0)
	F.act(ms, 1, F.press(&"block"))
	assert_false(ms.p1.projectiles.is_alive_at(0), "the green projectile was deflected and consumed")
	assert_eq(ms.p1.hero.get_hp(), 80.0, "...and healed nobody")
	var dodge := Fx.make()
	_staged(dodge, 0, 2, 0)
	F.activate(dodge, 0)
	F.act(dodge, 1, F.press(&"roll"))
	dodge.push_contact([0, MatchState.projectile_attacker_index(0)], [1, TargetingService.HERO_INDEX], 0,
			dodge.p2.hero.facing, MatchState.CONTACT_STRIKE)
	F.idle(dodge, 1)
	assert_false(dodge.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "an i-frame-dropped blue slows nobody")


func _staged_activate_green(ms: MatchState) -> void:
	F.activate(ms, 0)
	assert_eq(_colors(ms), [Enums.CardColor.GREEN], "fixture: one green projectile in the air")


## AC 15: a zero-damage landing spends no Stoneskin charge (the 7-5a rule), and the slow still applies.
func test_a_zero_damage_landing_spends_no_stoneskin() -> void:
	var ms := Fx.make()
	ms.p2.add_stoneskin_charge()
	_staged(ms, 0, 2, 0)
	F.activate(ms, 0)
	_land(ms, 0)
	F.idle(ms, 1)
	assert_eq(ms.p2.stoneskin_charges, 1, "a blue landing deals nothing and spends no Stoneskin")
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "...and the slow still applies")


# ---------------------------------------------------------------- AC 14: Counterspell

## AC 14: a Counterspell removes the projectiles still in flight AND the ones still owed, and reverses the
## landed ones -- red refunded, the slow ended, the green heal clawed back.
func test_a_counterspell_removes_shots_cancels_the_volley_and_reverses_landings() -> void:
	var ms := Fx.make()
	F.set_hp(ms, ms.p1, 80.0)
	# Five owed after the price (red, blue, green x3): the counter's own two ticks launch the fourth, and
	# the fifth is still owed when it resolves.
	_staged(ms, 1, 2, 3)
	F.activate(ms, 0)
	F.idle(ms, 2 * Fx.VOLLEY_TICKS)
	assert_eq(ms.p1.projectiles.size(), 3, "sanity: three of five launched")
	assert_true(ms.p1.has_pending_volley(), "...and two still owed")
	_land(ms, 0)
	F.idle(ms, 1)
	_land(ms, 1)
	F.idle(ms, 1)
	_land(ms, 2)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.RED_DAMAGE, "sanity: red landed")
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "sanity: blue landed")
	assert_eq(ms.p1.hero.get_hp(), 80.0 + Fx.GREEN_HEAL, "sanity: green landed")
	assert_true(ms.p1.has_pending_volley(), "sanity: projectiles are still owed")
	assert_true(F.counter(ms, 1), "the Fury activation is a counter target")
	assert_false(ms.p1.has_pending_volley(), "the owed projectile is cancelled")
	var launched := ms.p1.projectiles.size()
	assert_false(ms.p1.projectiles.is_alive_at(launched - 1), "the one launched during the counter's staging is removed")
	F.idle(ms, 3 * Fx.VOLLEY_TICKS)
	assert_eq(ms.p1.projectiles.size(), launched, "...and the owed one never launches")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "red's damage is refunded")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "blue's slow is ended")
	assert_eq(ms.p1.hero.get_hp(), 80.0, "green's heal is clawed back")


## Story 7-5b review fix (P1, the `6-5g/R22` shape): a Counterspell on the Fury ends the slow ITS OWN blue shot
## placed -- and ONLY that one. One rule slot per player: a later refresh (Frostbite's trigger, anything) is the same
## slot, so the Fury's packet records the expiry tick it placed and claims only a slow still ending there.
func _fury_blue_landed(ms: MatchState) -> void:
	_staged(ms, 0, 2, 0)   # one blue pays the price; ONE blue remains: one projectile
	F.activate(ms, 0)
	F.idle(ms, 1)
	_land(ms, 0)
	F.idle(ms, 1)
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "sanity: the Fury's blue slowed the hero")


func test_a_counterspell_ends_the_fury_slow_when_nothing_refreshed_it() -> void:
	var ms := Fx.make()
	_fury_blue_landed(ms)
	assert_true(ms._reversal_has_anything_left(ms.p1), "its own running slow is something left to undo")
	assert_true(F.counter(ms, 1), "the Fury activation is a counter target")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "its own slow is ended")


func test_a_counterspell_leaves_a_slow_a_later_refresh_placed_and_does_not_count_it() -> void:
	var ms := Fx.make()
	_fury_blue_landed(ms)
	# An armed Frostbite trigger consumed by a melee hit starts the slow on the same rule slot, ending later.
	ms.p2.start_rule(PlayerState.RULE_FROSTBITE_SLOW, Fx.SLOW_TICKS + 40, 0.4, 0.0)
	assert_false(ms._reversal_has_anything_left(ms.p1),
		"a slow the Fury did not place is not something its packet has left to undo")
	assert_false(F.counter(ms, 1), "so the Counterspell has nothing to answer")
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "the other source's slow still runs")
	assert_eq(ms.p2.rule_a[PlayerState.RULE_FROSTBITE_SLOW], 0.4, "...at its own multiplier")


## The REVERSAL ARM's own half of the same rule: the Counterspell is ANSWERABLE (a projectile is still owed, so the
## gate passes for another reason), and the walk of the packet must still leave a slow the Fury did not place.
func test_a_counterspell_that_does_proceed_still_leaves_a_slow_a_refresh_placed() -> void:
	var ms := Fx.make()
	_staged(ms, 0, 2, 1)   # one blue pays the price: blue, then green (still owed when the counter lands)
	F.activate(ms, 0)
	F.idle(ms, 1)
	_land(ms, 0)
	F.idle(ms, 1)
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "sanity: the Fury's blue slowed the hero")
	ms.p2.start_rule(PlayerState.RULE_FROSTBITE_SLOW, Fx.SLOW_TICKS + 40, 0.4, 0.0)
	assert_true(ms.p1.has_pending_volley(), "sanity: a projectile is still owed, so the packet has something left")
	assert_true(F.counter(ms, 1), "the Counterspell proceeds")
	assert_false(ms.p1.has_pending_volley(), "...and cancels the owed projectile")
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "but the slow the Fury did not place still runs")
	assert_eq(ms.p2.rule_a[PlayerState.RULE_FROSTBITE_SLOW], 0.4, "...at its own multiplier")


## AC 14: a projectile still IN FLIGHT vanishes under the counter.
func test_a_counterspell_removes_a_projectile_in_flight() -> void:
	var ms := Fx.make()
	_staged(ms, 1, 1, 0)
	F.activate(ms, 0)
	assert_true(ms.p1.projectiles.is_alive_at(0), "sanity: in flight")
	assert_true(F.counter(ms, 1), "countered")
	assert_false(ms.p1.projectiles.is_alive_at(0), "the projectile in flight is removed")
