class_name Deck2Fixture
extends RefCounted

## Story 7-5a: THE SHARED HEADLESS FIXTURE for Deck 2's eight implemented halves and Lifechain -- one
## in-test `MatchState` builder and its drive helpers, used by the `test_deck_2_*.gd` files (the
## `UnitKindFixture` / `LiveSummonDeck` precedent: a fixture several files share lives beside them in
## `test/`, never in `src/`).
##
## EVERY NUMBER HERE IS A TEST LITERAL (`BC/R3`): the config, the card prices and the effect magnitudes are
## authored in this file, so the tests that use it are isolated from `data/` tuning. Only the EFFECT IDS
## are the shipped vocabulary, because the resolver keys on them.
##
## CARDS ARE PLACED, NOT DRAWN. `put()` writes a named card into a hand slot directly, so a test states the
## hand it needs instead of depending on what a seed happened to deal.

const SEED := 7505
const MAX_HP := 100.0
const MAX_MANA := 10.0
const MAX_STAMINA := 100.0
const HAND_SIZE := 4
## AC 33's test literals: base 3 (3 % of 100), block 0.3.
const HIT_DAMAGE := 3.0
const BLOCK_MULT := 0.3
const HERO_TO_UNIT := 3.0
const UNBLOCKABLE_DAMAGE := 10.0
const UNBLOCKABLE_MANA := 1.0
const UNBLOCKABLE_STAMINA := 2.0
const ORB_GRANT := 1
const MAX_ORBS := 3
const MINION_HP := 9.0
const CHARGEUP_TICKS := 3
const LAUNCH_TICKS := 2
const KNOCKDOWN_TICKS := 20
const GET_UP_TICKS := 6
const IMMUNITY_TICKS := 30
const COUNTER_BUSY_TICKS := 12
const COUNTER_LEAD_TICKS := 12
const ROLL_IFRAME_TICKS := 12
const ROLL_TICKS := 14

const SETUP_MULTIPLIER := 2.0
const EXECUTE_MULTIPLIER := 3.0
const BLOOD_HP := 10.0
const BLOOD_MANA := 4.0
const ENRAGE_BONUS := 2.0
const ENRAGE_TICKS := 60
const ENRAGE_TICKS_PER_ORB := 12
const BLOSSOM_DISCOUNT := 1.0
const BLOSSOM_ORB_THRESHOLD := 3
const BLOSSOM_BIG_DISCOUNT := 2.0
const PULATION_MANA := 1.0
const LIFECHAIN_TICKS := 60
const BOLT_DAMAGE := 6.0
const BOLT_STUN_TICKS := 8
const FIRE_MIN_MANA := 3.0
const FIRE_DAMAGE_PER_MANA := 1.5
const FIRE_MANA_CAP := 10.0
const PLAIN_MANA := 3.0

const SETUP := &"fx_setup"
const STONE := &"fx_stone"
const BLOOD := &"fx_blood"
const BLOSSOM := &"fx_blossom"
const PULATION := &"fx_pulation"
const CHAIN := &"fx_chain"
const COUNTER := &"fx_counter"
const FIRE := &"fx_fire"
const PLAIN := &"fx_plain"
const BOLT := &"fx_bolt"
const BOOM := &"fx_boom"
const BOULDER := &"fx_boulder"
const BOOM_DAMAGE := 5.0
const BOULDER_MANA := 2.0

## id -> [colour, basic effect id, pitch effect id, basic mana, pitch mana].
const CARDS: Dictionary = {
	SETUP: [Enums.CardColor.RED, &"setup", &"execute", 2.0, 4.0],
	STONE: [Enums.CardColor.GREEN, &"spell_plain", &"stoneskin", 3.0, 2.0],
	BLOOD: [Enums.CardColor.GREEN, &"bloodmagic", &"enrage", 0.0, 2.0],
	BLOSSOM: [Enums.CardColor.BLUE, &"manablossom", &"spell_plain", 1.0, 5.0],
	PULATION: [Enums.CardColor.BLUE, &"manapulation", &"spell_plain", 1.0, 6.0],
	CHAIN: [Enums.CardColor.GREEN, &"summon_minion", &"lifechain", 3.0, 3.0],
	COUNTER: [Enums.CardColor.BLUE, &"spell_plain", &"counterspell", 4.0, 4.0],
	FIRE: [Enums.CardColor.RED, &"spell_plain", &"fireball", 2.0, FIRE_MIN_MANA],
	PLAIN: [Enums.CardColor.RED, &"spell_plain", &"spell_plain", PLAIN_MANA, PLAIN_MANA],
	BOLT: [Enums.CardColor.BLUE, &"honed_bolt", &"spell_plain", 1.0, 1.0],
	BOOM: [Enums.CardColor.RED, &"spell_plain", &"boom", 1.0, 1.0],
	BOULDER: [Enums.CardColor.RED, &"boulder_discard", &"", BOULDER_MANA, 0.0],
}

const FACT_DIR := Vector2.DOWN


static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / TimingWindow.TICK_HZ


static func config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = MAX_MANA
	c.max_stamina = MAX_STAMINA
	c.hand_size = HAND_SIZE
	c.deck_size = CARDS.size() - 1
	c.draw_replacement_delay_seconds = ticks_to_seconds(6000)
	c.pitch_stage_timer_seconds = ticks_to_seconds(6000)
	c.pitch_countdown_push_interval_seconds = ticks_to_seconds(6000)
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 1.0
	c.attack_windup_seconds = ticks_to_seconds(3)
	c.attack_active_seconds = ticks_to_seconds(4)
	c.attack_recovery_seconds = ticks_to_seconds(2)
	c.attack_chain_window_seconds = ticks_to_seconds(1)
	c.attack_chain_length = 1
	c.attack_damage_percent_of_max_hp = HIT_DAMAGE
	c.block_damage_multiplier = BLOCK_MULT
	c.block_facing_arc_degrees = 180.0
	c.deflect_stamina_cost = 8.0
	c.deflect_window_seconds = ticks_to_seconds(4)
	c.deflect_stun_seconds = ticks_to_seconds(5)
	c.roll_stamina_cost = 1.0
	c.roll_iframe_seconds = ticks_to_seconds(ROLL_IFRAME_TICKS)
	c.roll_duration_seconds = ticks_to_seconds(ROLL_TICKS)
	c.roll_distance = 1.0
	c.hero_damage_to_unit = HERO_TO_UNIT
	c.corpse_lifetime_seconds = ticks_to_seconds(600)
	c.minion_retarget_interval_seconds = 1000.0
	c.knockdown_stun_seconds = ticks_to_seconds(KNOCKDOWN_TICKS)
	c.get_up_iframe_seconds = ticks_to_seconds(GET_UP_TICKS)
	c.unblockable_immunity_seconds = ticks_to_seconds(IMMUNITY_TICKS)
	c.unblockable_stamina_cost = UNBLOCKABLE_STAMINA
	c.unblockable_mana_cost = UNBLOCKABLE_MANA
	c.unblockable_chargeup_seconds = ticks_to_seconds(CHARGEUP_TICKS)
	c.unblockable_launch_seconds_red = ticks_to_seconds(LAUNCH_TICKS)
	c.unblockable_launch_seconds_blue = ticks_to_seconds(LAUNCH_TICKS)
	c.unblockable_launch_seconds_green = ticks_to_seconds(LAUNCH_TICKS)
	c.unblockable_reach_red = 2.0
	c.unblockable_reach_blue = 2.0
	c.unblockable_reach_green = 2.0
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	c.defense_stamina_cost = 1.0
	c.counter_busy_seconds_red = ticks_to_seconds(COUNTER_BUSY_TICKS)
	c.counter_busy_seconds_blue = ticks_to_seconds(COUNTER_BUSY_TICKS)
	c.counter_busy_seconds_green = ticks_to_seconds(COUNTER_BUSY_TICKS)
	c.counter_lead_seconds_red = ticks_to_seconds(COUNTER_LEAD_TICKS)
	c.counter_lead_seconds_blue = ticks_to_seconds(COUNTER_LEAD_TICKS)
	c.counter_lead_seconds_green = ticks_to_seconds(COUNTER_LEAD_TICKS)
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, 4.0, 2, 3, 4, 2.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, MINION_HP),
	]
	c.unit_kinds = kinds
	return c


static func flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = false
	f.pitch_zone = true
	f.unblockable = true
	f.orbs = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


static func effect(effect_id: StringName) -> CardEffect:
	var e := CardEffect.new()
	e.effect_id = effect_id
	match effect_id:
		&"setup":
			e.orb_grant_multiplier = SETUP_MULTIPLIER
		&"execute":
			e.damage_dealt_multiplier = EXECUTE_MULTIPLIER
		&"bloodmagic":
			e.hp_cost = BLOOD_HP
			e.mana_gain = BLOOD_MANA
		&"enrage":
			e.duration_seconds = ticks_to_seconds(ENRAGE_TICKS)
			e.bonus_damage = ENRAGE_BONUS
			e.duration_per_orb_seconds = ticks_to_seconds(ENRAGE_TICKS_PER_ORB)
		&"manablossom":
			e.mana_discount = BLOSSOM_DISCOUNT
			e.orb_threshold = BLOSSOM_ORB_THRESHOLD
			e.mana_discount_at_threshold = BLOSSOM_BIG_DISCOUNT
		&"manapulation":
			e.mana_per_staging = PULATION_MANA
		&"lifechain":
			e.duration_seconds = ticks_to_seconds(LIFECHAIN_TICKS)
		&"honed_bolt":
			e.cast_seconds = ticks_to_seconds(2)
			e.damage_amount = BOLT_DAMAGE
			# Shorter than the knockdown, so the duration classifier reads it as an ordinary stun.
			e.stun_seconds = ticks_to_seconds(BOLT_STUN_TICKS)
		&"boom":
			e.damage_amount = BOOM_DAMAGE
		&"fireball":
			e.mana_cap = FIRE_MANA_CAP
			e.damage_per_mana = FIRE_DAMAGE_PER_MANA
			e.cast_seconds = ticks_to_seconds(2)
			# A flight profile, so a hero-sourced shot authored by this effect stays in the air.
			e.launch_speed = 5.0
			e.max_speed = 5.0
			e.travel_budget = 500.0
	return e


## The DECK composition: every fixture card but the Boulder, which belongs to no deck (it only ever
## enters a hand as a cover). The six content maps below still cover it.
static func card_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CARDS:
		if id != BOULDER:
			out.append(id)
	return out


static func costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in CARDS:
		var c := CardCastCondition.new()
		c.mana_cost = float((CARDS[id] as Array)[3])
		out[id] = c
	return out


static func pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in CARDS:
		var row: Array = CARDS[id]
		if StringName(row[2]) == &"":
			continue
		var c := CardCastCondition.new()
		c.mana_cost = float(row[4])
		c.orb_costs[int(row[0]) as Enums.CardColor] = 1
		out[id] = c
	return out


static func basic_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in CARDS:
		out[id] = effect((CARDS[id] as Array)[1])
	return out


static func pitch_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in CARDS:
		var pitch_id := StringName((CARDS[id] as Array)[2])
		if pitch_id != &"":
			out[id] = effect(pitch_id)
	return out


static func colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in CARDS:
		out[id] = int((CARDS[id] as Array)[0]) as Enums.CardColor
	return out


static func color_of(id: StringName) -> Enums.CardColor:
	return int((CARDS[id] as Array)[0]) as Enums.CardColor


## A dealt match with BOTH heroes at full hp, full stamina and FULL mana, every layer open.
static func make(balance: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(balance if balance != null else config())
	inject_content(ms)
	idle(ms, 1)   # the step-6 deal
	ms.p1.mana.add(MAX_MANA)
	ms.p2.mana.add(MAX_MANA)
	ms.drain_signals()
	return ms


## Flags and the six content channels, in the runner's own order.
static func inject_content(ms: MatchState) -> void:
	ms.inject_feature_flags(flags())
	ms.inject_deck(card_ids())
	ms.inject_card_costs(costs())
	ms.inject_card_effects(basic_effects())
	ms.inject_card_colors(colors())
	ms.inject_pitch_costs(pitch_costs())
	ms.inject_pitch_effects(pitch_effects())


static func seat(ms: MatchState, index: int) -> PlayerState:
	return ms.p1 if index == 0 else ms.p2


## PLACE card `id` in `player`'s hand slot `slot`, replacing whatever is there.
static func put(player: PlayerState, slot: int, id: StringName) -> void:
	if not player.hand.is_slot_empty(slot):
		player.hand.remove_at(slot)
	player.hand.fill_at(slot, id)


static func set_mana(ms: MatchState, player: PlayerState, value: float) -> void:
	player.mana.add(value - player.mana.get_current())
	ms.drain_signals()


static func set_hp(ms: MatchState, player: PlayerState, value: float) -> void:
	var hp := player.hero.get_hp()
	if value < hp:
		player.hero.take_damage(hp - value)
	else:
		player.hero.heal(value - hp)
	ms.drain_signals()


static func set_orbs(ms: MatchState, player: PlayerState, red: int, blue: int, green: int) -> void:
	player.orbs.reset_all()
	player.orbs.add(Enums.CardColor.RED, red)
	player.orbs.add(Enums.CardColor.BLUE, blue)
	player.orbs.add(Enums.CardColor.GREEN, green)
	ms.drain_signals()


static func total_orbs(player: PlayerState) -> int:
	return player.orbs.get_count(Enums.CardColor.RED) + player.orbs.get_count(Enums.CardColor.BLUE) \
			+ player.orbs.get_count(Enums.CardColor.GREEN)


# ---------------------------------------------------------------- intents

static func card_intent(slot: int, mode: Enums.ModeKind) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = mode
	i.card_commit = true
	return i


static func activate_intent() -> InputIntent:
	var i := InputIntent.new()
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = true
	return i


static func press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


static func held(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.held[action] = true
	return i


static func advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()


## One tick with `intent` on seat `index` and nothing on the other.
static func act(ms: MatchState, index: int, intent: InputIntent) -> void:
	if index == 0:
		advance(ms, intent, InputIntent.new())
	else:
		advance(ms, InputIntent.new(), intent)


static func idle(ms: MatchState, n: int) -> void:
	for _t in n:
		advance(ms, InputIntent.new(), InputIntent.new())


# ---------------------------------------------------------------- card drives

## Seat `index` PLAYS `id`'s NORMAL half from hand slot `slot` (the card is placed there first).
static func play(ms: MatchState, index: int, id: StringName, slot: int = 0) -> void:
	put(seat(ms, index), slot, id)
	act(ms, index, card_intent(slot, Enums.ModeKind.BASIC))


## Seat `index` STAGES `id` from hand slot `slot` (placed there first). No orb is granted.
static func stage(ms: MatchState, index: int, id: StringName, slot: int = 0) -> void:
	put(seat(ms, index), slot, id)
	act(ms, index, card_intent(slot, Enums.ModeKind.PITCH))


## Seat `index` ACTIVATES its staged card. No orb is granted.
static func activate(ms: MatchState, index: int) -> void:
	act(ms, index, activate_intent())


## Seat `index` PITCHES `id`: staged from `slot`, then one orb of the card's own colour is ADDED to
## whatever the seat already holds, and the card is activated.
static func pitch(ms: MatchState, index: int, id: StringName, slot: int = 0) -> void:
	stage(ms, index, id, slot)
	seat(ms, index).orbs.add(color_of(id), 1)
	ms.drain_signals()
	activate(ms, index)


## Seat `index` pitches the COUNTERSPELL card at the other seat's last resolved card. True when the
## counter RESOLVED (the `counterspell_resolved` signal fired), false when it was refused.
static func counter(ms: MatchState, index: int) -> bool:
	var fired: Array = [false]
	var on_resolved := func(_caster: int, _countered: int) -> void: fired[0] = true
	ms.counterspell_resolved.connect(on_resolved)
	var player := seat(ms, index)
	set_mana(ms, player, MAX_MANA)
	pitch(ms, index, COUNTER, HAND_SIZE - 1)
	ms.counterspell_resolved.disconnect(on_resolved)
	if not fired[0] and ms.pitch.is_staged(index):
		# A refused activation leaves the card staged; empty the zone so the next call can stage again.
		ms.pitch.clear(index)
	return fired[0]


# ---------------------------------------------------------------- hits

## Seat `attacker`'s hero lands ONE melee hit on the other hero; returns the hp that hero lost.
## `blocked`: the defender holds block with no stamina to deflect. `deflected`: the defender presses
## block on the swing's own tick with the stamina to deflect.
static func melee_hit(ms: MatchState, attacker: int, blocked := false, deflected := false) -> float:
	var defender := seat(ms, 1 - attacker)
	var block_now := InputIntent.new()
	var block_hold := InputIntent.new()
	if blocked or deflected:
		if blocked:
			defender.stamina.spend(defender.stamina.get_current(), 0)
		block_now = press(&"block")
		block_hold = held(&"block")
	_both(ms, attacker, press(&"attack"), block_now)
	for _t in 2:
		_both(ms, attacker, InputIntent.new(), block_hold)
	var before := defender.hero.get_hp()
	ms.push_contact([attacker, -1], [1 - attacker, -1], seat(ms, attacker).hero.attack_index, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_both(ms, attacker, InputIntent.new(), block_hold)
	var lost := before - defender.hero.get_hp()
	# Let the swing finish, so the next call starts from IDLE.
	for _t in 12:
		if seat(ms, attacker).hero.action_state == HeroState.ActionState.IDLE:
			break
		idle(ms, 1)
	return lost


## Seat `attacker`'s hero lands ONE melee hit on the other seat's board unit `unit_index`; returns the
## hp the unit lost.
static func melee_hit_unit(ms: MatchState, attacker: int, unit_index: int) -> float:
	var owner := seat(ms, 1 - attacker)
	act(ms, attacker, press(&"attack"))
	idle(ms, 2)
	var before := owner.units.hp_at(unit_index)
	ms.push_contact([attacker, -1], [1 - attacker, unit_index], seat(ms, attacker).hero.attack_index,
			FACT_DIR, MatchState.CONTACT_STRIKE)
	idle(ms, 1)
	var lost := before - owner.units.hp_at(unit_index)
	for _t in 12:
		if seat(ms, attacker).hero.action_state == HeroState.ActionState.IDLE:
			break
		idle(ms, 1)
	return lost


## `intent` on the attacker's seat, `other` on the defender's.
static func _both(ms: MatchState, attacker: int, intent: InputIntent, other: InputIntent) -> void:
	if attacker == 0:
		advance(ms, intent, other)
	else:
		advance(ms, other, intent)


## Seat `attacker` PRESSES an unblockable with `id` from hand slot `slot` (placed there first). Returns
## whether the press was accepted (the hero is CHARGING afterwards).
static func press_unblockable(ms: MatchState, attacker: int, id: StringName = PLAIN, slot: int = 1) -> bool:
	put(seat(ms, attacker), slot, id)
	act(ms, attacker, card_intent(slot, Enums.ModeKind.UNBLOCKABLE))
	return seat(ms, attacker).hero.action_state == HeroState.ActionState.CHARGING


## Carry seat `attacker`'s unblockable from its press to its end, pushing an INSIDE reach fact every
## tick. `defender_intent` is given to the defender on every tick. Returns the number of `hit_landed`
## signals the attack produced (0 = it did not land).
static func fly_unblockable(ms: MatchState, attacker: int, defender_intent: InputIntent = null) -> int:
	var hits: Array = [0]
	var on_hit := func(by: int, _target: int, _damage: float, _hp: float) -> void:
		if by == attacker:
			hits[0] += 1
	ms.hit_landed.connect(on_hit)
	var player := seat(ms, attacker)
	for _t in CHARGEUP_TICKS + LAUNCH_TICKS + 4:
		if player.hero.action_state != HeroState.ActionState.CHARGING:
			break
		ms.push_contact([attacker, -1], [1 - attacker, -1], player.hero.attack_index, FACT_DIR,
				MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_both(ms, attacker, InputIntent.new(), defender_intent if defender_intent != null else InputIntent.new())
	ms.hit_landed.disconnect(on_hit)
	return hits[0]


## Press and fly in one call; returns the `hit_landed` count.
static func land_unblockable(ms: MatchState, attacker: int, id: StringName = PLAIN, slot: int = 1) -> int:
	if not press_unblockable(ms, attacker, id, slot):
		return 0
	return fly_unblockable(ms, attacker)


static func rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out
