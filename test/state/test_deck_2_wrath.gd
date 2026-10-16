extends TestCase

## Story 7-5b (AC 16-22): WRATH OF GOD, headless. The windup, the frozen radius, the one pulse, the hero's
## damage / stun / knockback, the defences, the units, and the Counterspell. Ring membership arrives only as
## recorded `CONTACT_PULSE` facts (the runner's gather), so every test here pushes them itself. Test literals
## only (`BC/R3`).

const Fx := preload("res://test/deck_2_bodies_fixture.gd")
const F := preload("res://test/deck_2_fixture.gd")


## Run P1's windup to the strike, pushing `ring` ([target_index, dir] pairs) every tick and handing P2
## `p2_at.call(k)` on windup tick k (1-based; the last call is the strike tick).
func _windup(ms: MatchState, ring: Array, p2_at: Callable = Callable()) -> void:
	var k := 0
	while ms.p1.is_casting() and k < Fx.WINDUP_TICKS + 2:
		k += 1
		for fact: Array in ring:
			Fx.push_ring(ms, 0, int(fact[0]), fact[1] as Vector2)
		var p2_intent: InputIntent = p2_at.call(k) if p2_at.is_valid() else InputIntent.new()
		F.advance(ms, InputIntent.new(), p2_intent)


## The bearing from P2's hero to the caster that P2's own facing points along (the block arc's "facing").
func _facing_dir(ms: MatchState) -> Vector2:
	return ms.p2.hero.facing


# ---------------------------------------------------------------- AC 16: windup, radius, one pulse

## AC 16: activation starts a windup of the authored length; the radius is FROZEN at activation as base plus
## one step per orb still held after the blue orb is paid.
func test_the_windup_is_a_cast_and_the_radius_is_frozen_at_activation() -> void:
	var ms := Fx.make()
	# Three blue held (the fixture's per-colour cap): one pays the price, two remain.
	assert_true(Fx.cast_wrath(ms, 0, 2), "the activation starts the windup")
	assert_eq(ms.p1.cast_window.remaining_ticks(), Fx.WINDUP_TICKS, "...of the authored length")
	assert_eq(ms.p1.cast_radius, Fx.BASE_RADIUS + 2.0 * Fx.RADIUS_PER_ORB, "base + 1 m per orb held after the price")
	ms.p1.orbs.add(Enums.CardColor.RED, 2)
	ms.drain_signals()
	F.idle(ms, 1)
	assert_eq(ms.p1.cast_radius, Fx.BASE_RADIUS + 2.0, "orbs gained after the activation do not move it")
	assert_eq(ms.p1.to_snapshot()["cast"][6], Fx.BASE_RADIUS + 2.0, "the radius rides the hashed `cast` key")


## AC 16: ONE pulse, on the windup's LAST tick -- a body reported inside the ring before then is untouched,
## and one reported after it is untouched too (no lingering zone).
func test_one_pulse_on_the_last_tick_and_no_lingering_zone() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	for _t in Fx.WINDUP_TICKS - 1:
		Fx.push_ring(ms, 0, TargetingService.HERO_INDEX)
		F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "ring facts during the windup do nothing")
	F.idle(ms, 1)
	assert_false(ms.p1.is_casting(), "the windup struck (with nobody in the ring this tick)")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "...and a body absent from THIS tick's ring is untouched")
	Fx.push_ring(ms, 0, TargetingService.HERO_INDEX)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "a body entering after the pulse is untouched (not a zone)")


## AC 1: the spell layer OFF resolves the activation and starts no windup.
func test_with_the_spell_layer_off_wrath_resolves_and_starts_nothing() -> void:
	var ms := Fx.make(Fx.flags_with(true, false))
	assert_false(Fx.cast_wrath(ms, 0), "no windup starts")
	assert_false(ms.pitch.is_staged(0), "...though the activation resolved")


# ---------------------------------------------------------------- AC 18: the hero

## AC 18: unguarded, the opposing hero takes the damage, is stunned for the authored length (not a bolt
## stun, no root) and slides directly away from the caster.
func test_the_pulse_damages_stuns_and_knocks_the_hero_directly_away() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	var to_caster := Vector2(0.6, 0.8)
	_windup(ms, [[TargetingService.HERO_INDEX, to_caster]])
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE, "the authored damage")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "stunned")
	assert_eq(ms.p2.hero.stun.duration_ticks(), Fx.WRATH_STUN_TICKS, "...for the authored length")
	assert_false(ms.p2.hero.stun_is_bolt, "...not a bolt stun")
	assert_false(ms.p2.root_window.is_running, "...and no root")
	assert_true(ms.p2.knockback_window.is_running, "the hero is sliding")
	assert_eq(ms.p2.knockback_dir, -to_caster, "...directly AWAY from the caster")
	var speed := Fx.KNOCKBACK_DISTANCE / (float(Fx.KNOCKBACK_TICKS) / TimingWindow.TICK_HZ)
	assert_almost_eq(ms.p2.knockback_speed, speed, 0.0001, "...at the authored distance over the authored time")
	assert_almost_eq(ms.p2.hero.velocity.x, -to_caster.x * speed, 0.0001, "the slide's velocity starts this tick")
	F.idle(ms, 1)
	assert_almost_eq(ms.p2.hero.velocity.z, -to_caster.y * speed, 0.0001,
		"...and holds on the next tick although the hero is STUNNED")
	F.idle(ms, Fx.KNOCKBACK_TICKS)
	assert_false(ms.p2.knockback_window.is_running, "the slide ends after its authored time")


## AC 18 (`7-5b/R18`): the stun interrupts a SWING, a CHARGEUP (the CHARGING teardown: the card's windows,
## colour, hit-once memory and Setup carry all rest) and a BLOCK.
func test_the_stun_interrupts_a_swing_a_chargeup_and_a_block() -> void:
	var swing := Fx.make()
	Fx.cast_wrath(swing, 0)
	_windup(swing, [[TargetingService.HERO_INDEX, Vector2.LEFT]],
			func(k: int) -> InputIntent: return F.press(&"attack") if k == Fx.WINDUP_TICKS - 1 else InputIntent.new())
	assert_eq(swing.p2.hero.action_state, HeroState.ActionState.STUNNED, "a swing is interrupted")
	var charge := Fx.make()
	Fx.cast_wrath(charge, 0)
	assert_true(F.press_unblockable(charge, 1), "sanity: P2 starts a chargeup")
	charge.p2.charge_setup_multiplier = 2.0
	_windup(charge, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_eq(charge.p2.hero.action_state, HeroState.ActionState.STUNNED, "the chargeup is interrupted")
	assert_false(charge.p2.charge_window.is_running, "...its chargeup window stopped")
	assert_false(charge.p2.landing_window.is_running, "...and its landing window")
	assert_eq(charge.p2.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...its colour rests")
	assert_eq(charge.p2.charge_setup_multiplier, 0.0, "...and its Setup carry rests (interrupted)")
	var block := Fx.make()
	Fx.cast_wrath(block, 0)
	# A block NOT facing the caster is no defence: the stun ends it.
	_windup(block, [[TargetingService.HERO_INDEX, -block.p2.hero.facing]],
			func(k: int) -> InputIntent: return F.press(&"block") if k == 1 else F.held(&"block"))
	assert_eq(block.p2.hero.action_state, HeroState.ActionState.STUNNED, "a block from behind is interrupted")


## AC 18 / AC 22: the stun CANCELS a cast in progress (the cast rule's interrupt), the card and mana spent.
func test_the_stun_cancels_a_cast_in_progress() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	# P2 presses a bolt on the windup's second-to-last tick, so its cast is still running at the pulse.
	F.put(ms.p2, 0, F.BOLT)
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]],
			func(k: int) -> InputIntent: return F.card_intent(0, Enums.ModeKind.BASIC) \
					if k == Fx.WINDUP_TICKS - 1 else InputIntent.new())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "sanity: the pulse stunned the caster-to-be")
	F.idle(ms, 1)
	assert_false(ms.p2.is_casting(), "the stunned caster's cast is cancelled")
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP, "...and its bolt never struck")


## AC 18: a hero already in a KNOCKDOWN takes the damage only -- no new stun, no slide.
func test_a_hero_in_a_knockdown_takes_the_damage_only() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	ms.p2.hero.start_stun(F.KNOCKDOWN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE, "the damage lands")
	assert_eq(ms.p2.hero.stun.duration_ticks(), F.KNOCKDOWN_TICKS, "the knockdown is not replaced")
	assert_false(ms.p2.knockback_window.is_running, "...and there is no slide")


## Story 7-5b review fix (D1, operator ruling S19): A STUN ALREADY RUNNING (non-knockdown) IS NEVER SHORTENED --
## the pulse leaves the hero with the longer of its running remainder and its own length, and the bolt flag the
## running stun carries survives. Seeded as a BOLT stun, which the knockdown floor does not cover.
func test_a_running_shorter_stun_is_lengthened_to_the_pulses_and_keeps_its_bolt_flag() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	ms.p2.hero.start_stun(Fx.WRATH_STUN_TICKS + 3, true)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE, "the damage lands")
	assert_eq(ms.p2.hero.stun.remaining_ticks(), Fx.WRATH_STUN_TICKS,
		"the running remainder (shorter by now) is raised to the pulse's own length")
	assert_true(ms.p2.hero.stun_is_bolt, "...and the running stun's bolt flag is NOT cleared")


func test_a_running_longer_stun_is_not_cut_to_the_pulses_length() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	var longer := F.KNOCKDOWN_TICKS - 1
	ms.p2.hero.start_stun(longer, true)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_true(ms.p2.hero.stun.remaining_ticks() > Fx.WRATH_STUN_TICKS,
		"a stun longer than the pulse's is never shortened to it (remaining %d)" % ms.p2.hero.stun.remaining_ticks())
	assert_true(ms.p2.hero.stun.remaining_ticks() <= longer, "...and is never lengthened past what it had")
	assert_true(ms.p2.hero.stun_is_bolt, "...and keeps its bolt flag")


# ---------------------------------------------------------------- AC 21: defences

## AC 21: i-frames open at the pulse (a roll) avoid it entirely; a body outside the ring is never reported
## and is untouched.
func test_iframes_or_being_outside_the_ring_avoid_the_pulse() -> void:
	var rolled := Fx.make()
	Fx.cast_wrath(rolled, 0)
	_windup(rolled, [[TargetingService.HERO_INDEX, Vector2.LEFT]],
			func(k: int) -> InputIntent: return F.press(&"roll") if k == Fx.WINDUP_TICKS - 2 else InputIntent.new())
	assert_eq(rolled.p2.hero.get_hp(), F.MAX_HP, "a rolling hero takes nothing")
	assert_false(rolled.p2.knockback_window.is_running, "...and does not slide")
	var outside := Fx.make()
	Fx.cast_wrath(outside, 0)
	_windup(outside, [])
	assert_eq(outside.p2.hero.get_hp(), F.MAX_HP, "a hero outside the ring takes nothing")
	assert_ne(outside.p2.hero.action_state, HeroState.ActionState.STUNNED, "...and is not stunned")


## AC 21 (`7-5b/R10`): a held block FACING the caster takes the effect's blocked share, with no knockback and
## no stun.
func test_a_block_facing_the_caster_takes_half_with_no_knockback_or_stun() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)   # no stamina to deflect
	# Block pressed on the first windup tick and held. Its deflect window's grace tick is still open at the
	# strike, so with NO stamina the deflect degrades to a plain block -- the melee ladder's own rule.
	_windup(ms, [[TargetingService.HERO_INDEX, _facing_dir(ms)]],
			func(k: int) -> InputIntent: return F.press(&"block") if k == 1 else F.held(&"block"))
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE * Fx.BLOCKED_MULT, "the blocked share")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "no stun -- still blocking")
	assert_false(ms.p2.knockback_window.is_running, "no knockback")


## AC 21 (`7-5b/R10`): a timed DEFLECT takes nothing, costs the normal deflect cost, and does nothing to the
## caster.
func test_a_timed_deflect_takes_nothing_and_costs_the_normal_deflect_cost() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	var stamina := ms.p2.stamina.get_current()
	_windup(ms, [[TargetingService.HERO_INDEX, _facing_dir(ms)]],
			func(k: int) -> InputIntent: return F.press(&"block") if k == Fx.WINDUP_TICKS else InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the deflected pulse deals nothing")
	assert_eq(ms.p2.stamina.get_current(), stamina - ms.balance.deflect_stamina_cost, "...for the normal cost")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "...and does nothing to the caster")
	assert_false(ms.p2.knockback_window.is_running, "no knockback")


## AC 21 (`7-5b/R11`): Stoneskin absorbs the damage while the knockback and stun still apply; Lifechain
## splits the hero's damage.
func test_stoneskin_absorbs_the_damage_but_not_the_knockback_or_stun() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	ms.p2.add_stoneskin_charge()
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the damage is absorbed")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "...the stun still applies")
	assert_true(ms.p2.knockback_window.is_running, "...and so does the knockback")
	var split := Fx.make()
	var minion := Fx.add_unit(split, 1, CardEffectResolver.KIND_MINION)
	Fx.cast_wrath(split, 0)
	split.p2.open_lifechain(600)
	_windup(split, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	assert_eq(split.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE / 2.0, "Lifechain splits the hero's damage")
	assert_eq(split.p2.units.hp_at(minion), F.MINION_HP - Fx.WRATH_DAMAGE / 2.0, "...with its minion")


# ---------------------------------------------------------------- AC 17/AC 20: units

## AC 20 (`7-5b/R9`): every walking unit in the ring takes the damage and slides away; one whose kind
## reacts to damage has its attack interrupted; a TOTEM takes the damage only and never moves.
func test_walking_units_slide_reactive_ones_react_and_totems_take_damage_only() -> void:
	var ms := Fx.make()
	var walker := Fx.add_unit(ms, 1, Fx.KIND_WALKER)
	var zombie := Fx.add_unit(ms, 1, CardEffectResolver.KIND_MINION)
	var totem := Fx.add_unit(ms, 1, CardEffectResolver.KIND_COMBAT_TOTEM)
	ms.balance.kind_at(ms.balance.kind_index_of(CardEffectResolver.KIND_COMBAT_TOTEM)).move_speed = 0.0
	Fx.cast_wrath(ms, 0)
	_windup(ms, [[walker, Vector2.LEFT], [zombie, Vector2.UP], [totem, Vector2.RIGHT]])
	assert_eq(ms.p2.units.hp_at(walker), F.MINION_HP - Fx.WRATH_DAMAGE, "the walker takes the damage")
	assert_eq(ms.p2.units.knockback_velocity_at(walker).normalized(), -Vector2.LEFT, "...and slides away")
	assert_eq(ms.p2.units.behavior_phase_at(walker), UnitBoard.BehaviorPhase.REACT,
		"...and, reacting to damage, its attack is interrupted")
	assert_true(ms.p2.units.knockback_ticks_at(zombie) > 0, "the zombie slides too")
	assert_ne(ms.p2.units.behavior_phase_at(zombie), UnitBoard.BehaviorPhase.REACT, "...but does not react")
	assert_eq(ms.p2.units.hp_at(totem), F.MINION_HP - Fx.WRATH_DAMAGE, "the totem takes the damage")
	assert_eq(ms.p2.units.knockback_ticks_at(totem), 0, "...and never moves")


## AC 20: a kill leaves a corpse; the caster's OWN units are untouched (a ring fact can only name the
## opposing slot -- the intake refuses a same-slot fact).
func test_a_pulse_kill_leaves_a_corpse_and_the_casters_own_units_are_untouched() -> void:
	var ms := Fx.make()
	var victim := Fx.add_unit(ms, 1, CardEffectResolver.KIND_MINION)
	ms.p2.units.apply_damage_at(victim, F.MINION_HP - 1.0, 0)
	var own := Fx.add_unit(ms, 0, CardEffectResolver.KIND_MINION)
	Fx.cast_wrath(ms, 0)
	_windup(ms, [[victim, Vector2.LEFT]])
	assert_false(ms.p2.units.is_alive_at(victim), "the pulse kills it")
	assert_true(ms.p2.units.has_corpse_at(victim), "...leaving a corpse")
	assert_eq(ms.p1.units.hp_at(own), F.MINION_HP, "the caster's own unit is untouched")


# ---------------------------------------------------------------- AC 22: Counterspell and interrupts

## AC 22: a Counterspell DURING the windup cancels it -- no pulse.
func test_a_counterspell_during_the_windup_means_no_pulse() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	assert_true(F.counter(ms, 1), "the windup is a counter target")
	assert_false(ms.p1.is_casting(), "the windup is cancelled")
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	F.idle(ms, Fx.WINDUP_TICKS)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "...and no pulse ever lands")


## AC 22: a Counterspell AFTER the pulse reverses the damage actually applied, to the hero and to each unit
## by its own amount; positions are not moved back (the slide is left alone).
func test_a_counterspell_after_the_pulse_reverses_the_damage_per_body() -> void:
	var ms := Fx.make()
	var walker := Fx.add_unit(ms, 1, Fx.KIND_WALKER)
	var totem := Fx.add_unit(ms, 1, CardEffectResolver.KIND_COMBAT_TOTEM)
	ms.p2.units.apply_damage_at(totem, F.MINION_HP - 2.0, 0)   # the pulse can only remove 2 from it
	Fx.cast_wrath(ms, 0)
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT], [walker, Vector2.LEFT], [totem, Vector2.UP]])
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.WRATH_DAMAGE, "sanity: the hero was hit")
	assert_false(ms.p2.units.is_alive_at(totem), "sanity: the 2-hp totem died (2 removed, not 6)")
	# The struck hero is stunned; it can press its Counterspell once the stun has run out.
	F.idle(ms, Fx.WRATH_STUN_TICKS + 1)
	assert_true(F.counter(ms, 1), "the resolved Wrath is a counter target")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the hero's damage is refunded")
	assert_eq(ms.p2.units.hp_at(walker), F.MINION_HP, "the walker gets back exactly what it lost")
	assert_false(ms.p2.units.is_alive_at(totem), "the totem it killed stays dead (no corpse to restore from)")


## AC 22: a caster STUNNED during the windup loses the pulse; card, mana and orb stay spent.
func test_a_caster_stunned_during_the_windup_loses_the_pulse() -> void:
	var ms := Fx.make()
	Fx.cast_wrath(ms, 0)
	var mana := ms.p1.mana.get_current()
	ms.p1.hero.start_stun(4, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_windup(ms, [[TargetingService.HERO_INDEX, Vector2.LEFT]])
	F.idle(ms, Fx.WINDUP_TICKS)
	assert_false(ms.p1.is_casting(), "the windup is lost")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "...no pulse lands")
	assert_eq(ms.p1.mana.get_current(), mana, "...and nothing is refunded")
