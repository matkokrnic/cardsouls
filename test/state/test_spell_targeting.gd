extends TestCase

## Story 6-5d (AC 24-27, `6-5d/R6`/`R7`/`R8`/`R15`): SPELL TARGETING -- where an offensive spell goes, for
## BOTH cast ids. The capture rule (AC 24), Honed Bolt's two arms (AC 25), a dead captured target
## (AC 26) and the pre-spend requirement (AC 27).
##
## THE BOLT IS THE SUBJECT HERE, NOT THE FIREBALL, and the split from `test_fireball.gd` is deliberate:
## the Fireball's own file covers its cost, flight and contact rules, while this file covers the rule the
## two spells SHARE. `6-5d/R6` supersedes `6-5c/R1` for both at once, so the shared rule gets one file
## and a regression in it fails here rather than twice over.
##
## Fixture shape, on `test_pitch_staging.gd`'s discipline: every config, flag set, cost map and effect is
## built IN-TEST; the authored `.tres` files never reach here (`BC/R3`). The BASIC effect of every card is
## a Honed Bolt and the PITCH effect is a Fireball, which is the real Deck 1 shape after this story.

const SEED := 2424
const DECK_SIZE := 8
const HAND_SIZE := 4
const CAST_COST := 2.0
const PITCH_MINIMUM := 3.0
const CAST_TICKS := 6
const MAX_HP := 100.0
const UNIT_HP := 40.0
const BOLT_DAMAGE := 4.0
const BOLT_STUN_TICKS := 12
const BOLT_ROOT_TICKS := 30
const MINION_KIND := &"minion"
const TOTEM_KIND := &"combat_totem"
const CAST_SLOT := 0


# --- AC 24: the capture rule ------------------------------------------------------------------

## AC 24 (`6-5d/R6`/`R7`): THE TARGET IS THE LOCK AT THE PRESS TICK, and an UNLOCKED caster targets the
## opposing hero. Both clauses of the rule, read off the CAPTURED members rather than off an outcome, so
## the capture itself is pinned and not merely its consequence.
func test_the_cast_captures_the_lock_at_the_press_and_the_hero_when_unlocked() -> void:
	var locked := _make_match()
	locked.p2.units.add(UNIT_HP, _kind_index(locked, MINION_KIND))
	locked.p1.lock_target_slot = 1
	locked.p1.lock_target_index = 0
	_advance(locked, _cast_intent(CAST_SLOT), InputIntent.new())
	assert_eq([locked.p1.cast_target_slot, locked.p1.cast_target_index], [1, 0],
		"a LOCKED caster captured its lock address (AC 24)")
	var unlocked := _make_match()
	unlocked.p2.units.add(UNIT_HP, _kind_index(unlocked, MINION_KIND))
	unlocked.p1.lock_target_slot = PlayerState.UNLOCKED_SLOT
	unlocked.p1.lock_target_index = TargetingService.HERO_INDEX
	_advance(unlocked, _cast_intent(CAST_SLOT), InputIntent.new())
	assert_eq([unlocked.p1.cast_target_slot, unlocked.p1.cast_target_index],
		[1, TargetingService.HERO_INDEX],
		"an UNLOCKED caster captured the OPPOSING HERO (AC 24, `6-5d/R7`)")


## AC 24 (`6-5d/R15`): THE CAPTURE IS FIXED FOR THE WHOLE CAST -- a re-lock or an unlock after the press
## changes NOTHING. This is the test that makes the frozen COPY meaningful: the live `lock_target` is moved
## mid-cast to a different body, and the bolt still lands on the one captured at the press.
func test_a_re_lock_after_cast_start_changes_nothing() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	# THE RE-LOCK, mid-cast: the live lock now names the enemy HERO instead.
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = TargetingService.HERO_INDEX
	_idle(ms, CAST_TICKS)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP - BOLT_DAMAGE, 0.0001,
		"the bolt landed on the target captured at the PRESS (AC 24, `6-5d/R15`)")
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
		"...and NOT on the body the lock moved to during the cast")


## AC 24: the captured address is HASHED STATE, not re-derived from an actor. Read out of the snapshot,
## which is what a replay reproduces -- and the reason the four carried facts ride the `cast` key.
func test_the_captured_target_is_hashed_state() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	var cast: Array = ms.to_snapshot()["p1"]["cast"]
	assert_eq(cast.size(), 6,
		"the `cast` key carries six elements: id, remaining, mode, target slot, target index, damage")
	assert_eq(cast[2], int(Enums.ModeKind.BASIC), "...the MODE the strike resolves in (AC 12)")
	assert_eq([cast[3], cast[4]], [1, 0], "...and the CAPTURED target address (AC 24/AC 30)")
	# At rest the key is the neutral row, so a stale target is unrepresentable in the hash.
	var resting: Array = ms.to_snapshot()["p2"]["cast"]
	assert_eq(resting, ["", 0, PlayerState.NO_CAST_EFFECT_MODE,
			TargetingService.NO_TARGET_SLOT, TargetingService.HERO_INDEX, 0.0],
		"a player with no cast in flight carries the resting row (AC 30)")


# --- AC 25: Honed Bolt's two arms -------------------------------------------------------------

## AC 25 (`6-5d/R8`): ON A MINION, 4 DAMAGE ONLY -- no stun, no root, no dodge test -- and the damage goes
## through the funnel, so Bloodlust and Vampiric Aura both reach it and a lethal hit leaves a corpse.
func test_a_bolt_on_a_minion_is_damage_only_through_the_funnel() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_bolt_at(ms)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP - BOLT_DAMAGE, 0.0001,
		"4 damage on the minion (AC 25)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "no stun on anything (AC 25)")
	assert_false(ms.p2.root_window.is_running, "no root (AC 25)")
	# THE FUNNEL: both Bloodlust halves reach a minion target, which is `6-5a`'s standing rule.
	var buffed := _make_match()
	buffed.p2.units.add(UNIT_HP, _kind_index(buffed, MINION_KIND))
	buffed.p1.lock_target_slot = 1
	buffed.p1.lock_target_index = 0
	buffed.p1.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	buffed.p2.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	_bolt_at(buffed)
	assert_almost_eq(buffed.p2.units.hp_at(0), UNIT_HP - BOLT_DAMAGE * 4.0, 0.0001,
		"...and the funnel's both halves reach a minion target (AC 25)")


## AC 25: VAMPIRIC AURA HEALS OFF A BOLT ON A MINION, and a LETHAL bolt leaves a CORPSE through the same
## death seat as every other combat kill (6-5b).
func test_a_lethal_bolt_on_a_minion_heals_the_caster_and_leaves_a_corpse() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p2.units.apply_damage_at(0, UNIT_HP - BOLT_DAMAGE, 0)
	ms.p1.hero.take_damage(50.0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_bolt_at(ms)
	assert_false(ms.p2.units.is_alive_at(0), "the bolt killed the minion (AC 25)")
	assert_eq(ms.p2.units.corpse_indices(), [0] as Array[int],
		"...and left a CORPSE through the shared death seat (AC 25)")
	assert_almost_eq(ms.p1.hero.get_hp(), 50.0 + BOLT_DAMAGE * 0.5, 0.0001,
		"...and Vampiric Aura healed the caster off it (AC 25)")


## AC 25: A TOTEM TARGET IS THE SAME ARM -- damage only, no stun, no root. Named separately because a
## totem is a unit with a different KIND, and the arm must not have become minion-specific by way of the
## corpse rule (a totem leaves no corpse, and that exclusion is `_corpse_ticks_for`'s, not this arm's).
func test_a_bolt_on_a_totem_is_damage_only_and_leaves_no_corpse() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, TOTEM_KIND))
	ms.p2.units.apply_damage_at(0, UNIT_HP - BOLT_DAMAGE, 0)
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_bolt_at(ms)
	assert_false(ms.p2.units.is_alive_at(0), "the bolt killed the totem (AC 25)")
	assert_eq(ms.p2.units.corpse_indices(), [] as Array[int],
		"...and a TOTEM leaves no corpse -- `_corpse_ticks_for`'s standing exclusion, not this arm's")


## AC 25's second half: ON A HERO, EXACTLY THE 6-5c BEHAVIOUR. Asserted here as well as by every unedited
## 6-5c test, because this file's fixture reaches the hero arm through the NEW captured address rather
## than through the old `1 - slot` arithmetic -- so this is the assertion that the rewrite did not change
## the hero outcome while changing how the target is found.
func test_a_bolt_on_a_hero_still_damages_stuns_and_roots() -> void:
	var ms := _make_match()
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = TargetingService.HERO_INDEX
	_bolt_at(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, 0.0001,
		"the hero arm still damages (AC 25)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "...still stuns (AC 25)")
	assert_true(ms.p2.hero.stun_is_bolt, "...with a BOLT stun, not a knockdown")
	assert_true(ms.p2.root_window.is_running, "...and still roots (AC 25)")


## AC 25: THE STEP-3 LATCH DODGE IS STILL THE ONE AVOIDANCE ON A HERO, and it is deliberately NOT the
## live `is_iframe_open()` predicate the projectile rung reads. Recorded so the two seats' different tick
## semantics are not "fixed" into each other.
func test_the_hero_arm_still_dodges_on_the_step_3_latch() -> void:
	var ms := _make_match()
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = TargetingService.HERO_INDEX
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	ms.p2.hero.roll_iframe.start(10)
	_tick(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
		"a hero inside its roll i-frames dodged the bolt entirely (AC 25)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "...no stun")
	assert_false(ms.p2.root_window.is_running, "...and no root")


## AC 25: A UNIT TARGET GETS NO DODGE TEST, which is the other side of the latch rule: a unit has no roll
## and no i-frames, so an i-frame window open on the enemy HERO cannot save a locked MINION.
func test_a_unit_target_gets_no_dodge_test() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	ms.p2.hero.roll_iframe.start(10)
	_tick(ms)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP - BOLT_DAMAGE, 0.0001,
		"the hero's i-frames did not protect the locked MINION (AC 25)")


# --- AC 26: a dead captured target -------------------------------------------------------------

## AC 26 (`6-5d/R15`): A CAPTURED TARGET THAT DIED MID-CAST IS HIT BY NOTHING -- no damage, no
## `hit_landed`, no stun -- and the card and the mana are LOST, never refunded.
##
## AND THE SNAP-BACK IS NOT FOLLOWED, which is the clause that needs the frozen copy: the minion's death
## snaps the LIVE lock back to the opposing hero, and the bolt still hits nothing rather than falling on
## the hero the snap-back chose. That is the whole reason `cast_target_*` is a copy and not a read.
func test_a_bolt_whose_captured_target_died_mid_cast_hits_nothing() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	var mana_before := ms.p1.mana.get_current()
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	var spent := mana_before - ms.p1.mana.get_current()
	assert_almost_eq(spent, CAST_COST, 0.0001, "fixture: the cast cost was paid at the press")
	var hits := _hits(ms)
	ms.p2.units.apply_damage_at(0, UNIT_HP, 0)
	_idle(ms, CAST_TICKS)
	assert_eq(hits.size(), 0, "the bolt hit NOTHING: no `hit_landed` (AC 26)")
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
		"...and it did NOT fall on the lock's snap-back hero (AC 26)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "...and stunned nobody")
	assert_eq(ms.p1.lock_target_index, TargetingService.HERO_INDEX,
		"...even though the LIVE lock really did snap back to the hero (the premise of AC 26)")
	assert_almost_eq(ms.p1.mana.get_current(), mana_before - CAST_COST, 0.0001,
		"...and the mana is never refunded (AC 26)")
	assert_eq(ms.p1.discard.size(), 1, "...and the card stays spent")


# --- AC 27: the pre-spend target requirement --------------------------------------------------

## AC 27: THE PRE-SPEND REQUIREMENT STILL WORKS AND NOW READS THE CAPTURED-TARGET RULE -- a card whose
## target cannot exist is refused BEFORE ANY SPEND.
##
## SYNTHETIC, AND SAID SO (the `REASON_UNKNOWN_EFFECT_PREFIX` posture AC 27 cites). The fixture puts the
## enemy hero at zero hp WITHOUT letting a tick write `_round_over`, which is the only way to reach a
## press whose captured target is dead: in live play `_resolve_lock`'s step-2 validation normalises any
## invalid lock before step 6, and a dead hero ends the round so step 1b returns before the card seat.
## Never claimed live-reachable -- what it proves is that the gate is wired and would refuse.
func test_a_cast_whose_captured_target_cannot_exist_is_refused_before_any_spend() -> void:
	var ms := _make_match()
	var mana_before := ms.p1.mana.get_current()
	var hand_before := ms.p1.hand.occupied_count()
	# The captured target will be the opposing HERO (the resting lock), and it is dead -- but no tick has
	# run since, so `_round_over` is false and step 1b does not freeze this press out.
	ms.p2.hero.take_damage(MAX_HP)
	assert_false(ms.p2.hero.is_alive(), "fixture: the captured target is dead")
	var rejections := _rejections(ms.p1)
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_TARGET]],
		"the cast is REFUSED with the no-target reason (AC 27)")
	assert_almost_eq(ms.p1.mana.get_current(), mana_before, 0.0001,
		"...and NOTHING was spent -- the gate is before the spend (AC 27)")
	assert_eq(ms.p1.hand.occupied_count(), hand_before, "...the card stayed in hand")
	assert_false(ms.p1.is_casting(), "...and no cast started")
	assert_eq(ms.p1.discard.size(), 0, "...and nothing was discarded")


## AC 27: the SAME gate on the MODE ④ path, before the ORB spend -- the half that matters for Fireball,
## whose pre-spend currency is orbs rather than mana.
func test_a_fireball_activation_whose_captured_target_cannot_exist_is_refused_before_the_orb_spend() -> void:
	var ms := _make_match()
	_advance(ms, _stage_intent(CAST_SLOT), InputIntent.new())
	ms.p1.orbs.add(Enums.CardColor.RED, 1)
	ms.drain_signals()
	ms.p2.hero.take_damage(MAX_HP)
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_TARGET]],
		"the activation is REFUSED with the no-target reason (AC 27)")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 1,
		"...and the ORB was not spent -- the gate is before the orb spend (AC 27)")
	assert_true(ms.pitch.is_staged(0), "...the card is still staged")
	assert_false(ms.p1.is_casting(), "...and no cast started")


# --- helpers ---------------------------------------------------------------------------------

## Press a BASIC cast and run the cast out, so the bolt strikes.
func _bolt_at(ms: MatchState) -> void:
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS)


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_bolt_effects())
	ms.inject_pitch_costs(_pitch_costs())
	ms.inject_pitch_effects(_fireball_effects())
	_tick(ms)
	ms.p1.mana.add(20.0)
	ms.p2.mana.add(20.0)
	ms.p1.stamina.refill()
	ms.p2.stamina.refill()
	ms.drain_signals()
	return ms


func _bolt_effects() -> Dictionary[StringName, CardEffect]:
	var bolt := CardEffect.new()
	bolt.effect_id = &"honed_bolt"
	bolt.cast_seconds = float(CAST_TICKS) / TimingWindow.TICK_HZ
	bolt.damage_amount = BOLT_DAMAGE
	bolt.stun_seconds = float(BOLT_STUN_TICKS) / TimingWindow.TICK_HZ
	bolt.root_seconds = float(BOLT_ROOT_TICKS) / TimingWindow.TICK_HZ
	bolt.root_blocks_run = true
	bolt.root_blocks_roll = true
	bolt.repeat_landing_restuns = true
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = bolt
	return out


func _fireball_effects() -> Dictionary[StringName, CardEffect]:
	var fb := CardEffect.new()
	fb.effect_id = &"fireball"
	fb.cast_seconds = float(CAST_TICKS) / TimingWindow.TICK_HZ
	fb.mana_cap = 10.0
	fb.damage_per_mana = 1.5
	fb.launch_speed = 8.0
	fb.max_speed = 8.0
	fb.travel_budget = 60.0
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = fb
	return out


func _kind_index(ms: MatchState, kind_name: StringName) -> int:
	return ms.balance.kind_index_of(kind_name)


func _kind(kind_name: StringName) -> UnitKindProfile:
	var k := UnitKindProfile.new()
	k.kind_name = kind_name
	k.max_hp = UNIT_HP
	k.move_speed = 1.0
	k.stop_distance = 1.0
	k.priority_name = &"nearest"
	return k


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 30.0
	c.max_stamina = 50.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.max_orbs_per_color = 5
	c.pitch_stage_timer_seconds = 60.0 / TimingWindow.TICK_HZ
	c.draw_replacement_delay_seconds = 3.0 / TimingWindow.TICK_HZ
	# The bolt stun must stay strictly BELOW the knockdown stun, or the duration classifier misreads it
	# as a knockdown (`6-5c` AC 15's authoring invariant, honoured by this fixture).
	c.knockdown_stun_seconds = float(BOLT_STUN_TICKS + 20) / TimingWindow.TICK_HZ
	c.corpse_lifetime_seconds = 10.0
	c.hero_damage_to_unit = 3.0
	c.unit_kinds.append(_kind(MINION_KIND))
	c.unit_kinds.append(_kind(TOTEM_KIND))
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = true
	f.spells = true
	f.minions = true
	f.totems = true
	return f


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("tgt_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CAST_COST
		out[id] = c
	return out


func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MINIMUM
		c.orb_costs[Enums.CardColor.RED] = 1
		out[id] = c
	return out


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(
		func(attacker: int, target: int, damage: float, _hp: float) -> void:
			out.append([attacker, target, damage]))
	return out


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


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


func _idle(ms: MatchState, ticks: int) -> void:
	for _t in ticks:
		_tick(ms)


func _tick(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
