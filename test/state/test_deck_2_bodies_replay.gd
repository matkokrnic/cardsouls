extends TestCase

## Story 7-5b (AC 24, on the `6-5e` AC 41 / `7-5a` AC 53 precedent): A RECORDED MATCH EXERCISING THE THREE
## BODIES, WITH THE TWO SEATS ON DIFFERENT DECKS, SAVED AND RELOADED, REPLAYS TO THE IDENTICAL FINAL HASH AND
## RECORD.
##
## THE RUN, in order (P1 on the "bodies" list, P2 on the "answers" list):
##   1. P2 wounds P1; P1 plays the HEALER; one heal tick IN range (the range fact pushed), then one OUT of range.
##   2. P1 earns ONLY a blue orb and stages ELEMENTAL FURY: the activation is REFUSED.
##   3. P1 presses an unblockable: the Healer FIRES, and its shot lands on P2.
##   4. P1 earns two more orbs and the staged Fury activates: red, blue and green leave, the red one is
##      DEFLECTED, blue and green land.
##   5. P2 summons a HOUND and a TOTEM; P1's WRATH pulse takes P2's hero, the hound and the totem.
##   6. A second WRATH meets P2's BLOCK facing the caster.
##   7. P1 plays a second Healer and P2's COUNTERSPELL removes it.
##   8. P1 starts a third Wrath and P2's COUNTERSPELL cancels the WINDUP.
##
## THIS FILE PLAYS THE RUNNER'S ROLE, capturing on every channel beside the call it taps -- the heal-range
## channel included. Nothing writes state directly: orbs are EARNED by landings, mana by the authored regen.

const Fx := preload("res://test/deck_2_bodies_fixture.gd")
const F := preload("res://test/deck_2_fixture.gd")
const SEED := 75054
const RECORD_PATH := "user://test_deck_2_bodies_replay.rec"
const RESAVED_PATH := "user://test_deck_2_bodies_replay_resaved.rec"
const HAND := 14
const MANA_REGEN_PER_TICK := 0.2
const POOL_CAP := 1000.0
const WAIT_LIMIT := 900

const HOUND := &"fx_hound"
const TOTEM := &"fx_totem"

## Every card is dealt (hand = deck) and none returns inside the run (the fixture's draw delay outlasts it),
## so the list is a BUDGET: two Healers, one staged Fury plus two Fury and two Bolt cards spent as BLUE orb
## earners, three Wraths, and Plain / Stone as the red and green earners.
const P1_DECK: Array[StringName] = [
	Fx.HEALER, Fx.HEALER, Fx.FURY, Fx.FURY, Fx.FURY, F.BOLT, F.BOLT, Fx.WRATH, Fx.WRATH, Fx.WRATH,
	F.PLAIN, F.PLAIN, F.STONE, F.STONE,
]
const P2_DECK: Array[StringName] = [
	HOUND, TOTEM, F.COUNTER, F.COUNTER, F.COUNTER, F.COUNTER, F.PLAIN, F.PLAIN, F.PLAIN,
	F.PLAIN, F.PLAIN, F.PLAIN, F.PLAIN, F.PLAIN,
]

var _ms: MatchState
var _record: IntentRecorder
## When true, every recorded tick pushes the heal-range fact for each of P1's living Healers.
var _in_range := false


## AC 24, the primary: saved and reloaded, the record replays from that file alone to the identical hash,
## and saved again it is the identical file. Dropping a channel -- the new heal-range one included --
## diverges it.
func test_a_saved_and_reloaded_bodies_run_replays_to_the_identical_hash_and_record() -> void:
	var evidence := _record_the_run()
	var live_hash := CanonicalHash.of(_ms.to_snapshot())
	assert_true(bool(evidence["ran"]), "the run reached its end")
	assert_eq(RecordFile.save_record(_record, RECORD_PATH), "", "the record was written to disk")
	var result := RecordFile.load_record(RECORD_PATH)
	assert_not_null(result["record"], "...and it loads back: %s" % str(result["error"]))
	var loaded: IntentRecorder = result["record"]
	if loaded == null:
		return
	assert_eq(loaded.replay_seat_deck_contents(0), P1_DECK, "seat 1's own composition")
	assert_eq(loaded.replay_seat_deck_contents(1), P2_DECK, "...and seat 2's different one")
	assert_eq(CanonicalHash.of(_replay(loaded).to_snapshot()), live_hash,
		"AC 24: a replay driven from the SAVED AND RELOADED record alone is bit-identical")
	assert_eq(RecordFile.save_record(loaded, RESAVED_PATH), "", "the reloaded record was written again")
	assert_eq(FileAccess.get_file_as_bytes(RESAVED_PATH), FileAccess.get_file_as_bytes(RECORD_PATH),
		"AC 24: the record survives save -> load -> save unchanged")
	for channel: String in ["heal_range", "contacts", "intents"]:
		assert_ne(CanonicalHash.of(_replay(loaded, channel).to_snapshot()), live_hash,
			"dropping `%s` must DIVERGE this replay" % channel)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESAVED_PATH))


## AC 24's other half: the run must actually DO each thing.
func test_the_bodies_run_really_exercises_every_body() -> void:
	var e := _record_the_run()
	assert_eq(float(e["heal_in_range"]), Fx.HEAL_AMOUNT, "a heal tick IN range healed")
	assert_eq(float(e["heal_out_of_range"]), 0.0, "...and one OUT of range healed nothing")
	assert_eq(float(e["healer_shot"]), Fx.SHOT_DAMAGE, "a Healer shot landed for its damage")
	assert_eq(e["fury_refusal"], [[&"card_cast", MatchState.REASON_NO_ORB_AFTER_PRICE]], "Fury was refused once")
	assert_eq(e["fury_colors"], [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN],
		"...then fired red, blue and green")
	assert_eq(float(e["fury_red_deflected_damage"]), 0.0, "the red one was deflected")
	assert_true(bool(e["fury_blue_slowed"]), "the blue one slowed")
	assert_eq(float(e["fury_green_heal"]), Fx.GREEN_HEAL, "the green one healed the caster")
	assert_eq(float(e["wrath_hero"]), Fx.WRATH_DAMAGE, "Wrath hit the hero")
	assert_true(float(e["wrath_hound"]) > 0.0, "...and the hound")
	assert_true(float(e["wrath_totem"]) > 0.0, "...and the totem in the ring")
	assert_eq(float(e["wrath_blocked"]), Fx.WRATH_DAMAGE * Fx.BLOCKED_MULT, "a blocked pulse took the blocked share")
	assert_true(bool(e["healer_countered"]), "a Counterspell removed a Healer")
	assert_true(bool(e["windup_countered"]), "a Counterspell cancelled a Wrath windup")


# ---------------------------------------------------------------- the run

func _config() -> BalanceConfig:
	var config := Fx.config()
	config.hand_size = HAND
	config.deck_size = HAND
	config.mana_regen_per_second = MANA_REGEN_PER_TICK * TimingWindow.TICK_HZ
	config.max_mana = POOL_CAP
	var kinds: Array[UnitKindProfile] = []
	kinds.append_array(config.unit_kinds)
	kinds.append(UnitKindFixture.hound(&"hellhound", 9.0, 2.0, 3.0, 3, 3, 4, 1.4, 4.5, 6, 0, 3, 6, 6, 12))
	config.unit_kinds = kinds
	return config


func _cards() -> Dictionary:
	var out: Dictionary = Fx.all_cards()
	out[HOUND] = [Enums.CardColor.RED, &"summon_hellhound", &"", 2.0, 0.0]
	out[TOTEM] = [Enums.CardColor.RED, &"summon_combat_totem", &"", 2.0, 0.0]
	return out


func _effect(effect_id: StringName) -> CardEffect:
	var e := Fx.effect(effect_id)
	if effect_id == &"summon_hellhound":
		e.summon_kind = &"hellhound"
	return e


func _record_the_run() -> Dictionary:
	_record = IntentRecorder.new()
	_in_range = false
	var params := MatchParams.new(SEED)
	_record.capture_seed(params.seed_value)
	_ms = MatchState.new(params)
	var config := _config()
	_record.capture_apply_balance(config)
	_ms.apply_balance(config)
	var flags := F.flags()
	_record.capture_inject_feature_flags(flags)
	_ms.inject_feature_flags(flags)
	var cards := _cards()
	var costs: Dictionary[StringName, CardCastCondition] = {}
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {}
	var basic: Dictionary[StringName, CardEffect] = {}
	var pitch: Dictionary[StringName, CardEffect] = {}
	var colors: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in cards:
		var row: Array = cards[id]
		var cost := CardCastCondition.new()
		cost.mana_cost = float(row[3])
		costs[id] = cost
		basic[id] = _effect(row[1])
		colors[id] = int(row[0]) as Enums.CardColor
		if StringName(row[2]) != &"":
			var pitch_cost := CardCastCondition.new()
			pitch_cost.mana_cost = float(row[4])
			pitch_cost.orb_costs[int(row[0]) as Enums.CardColor] = 1
			pitch_costs[id] = pitch_cost
			pitch[id] = _effect(row[2])
	_record.capture_inject_seat_decks(P1_DECK, P2_DECK, ["bodies", "answers"] as Array[String])
	_ms.inject_seat_decks(P1_DECK, P2_DECK)
	_record.capture_inject_card_costs(costs)
	_ms.inject_card_costs(costs)
	_record.capture_inject_card_effects(basic)
	_ms.inject_card_effects(basic)
	_record.capture_inject_card_colors(colors)
	_ms.inject_card_colors(colors)
	_record.capture_inject_pitch_costs(pitch_costs)
	_ms.inject_pitch_costs(pitch_costs)
	_record.capture_inject_pitch_effects(pitch)
	_ms.inject_pitch_effects(pitch)
	var e: Dictionary = {"ran": false}
	_tick()   # the deal
	# 1. P2 wounds P1 (three hits, so the later green heal is not clamped at the maximum); the Healer heals
	#    once in range and skips once out of range.
	_settle()
	_melee(1)
	_melee(1)
	_melee(1)
	_settle()
	_card(0, Fx.HEALER, Enums.ModeKind.BASIC)
	var healer := _ms.p1.units.size() - 1
	_in_range = true
	while _ms.p1.units.heal_ticks_at(healer) < Fx.HEAL_INTERVAL_TICKS - 1:
		_tick()
	var hp := _ms.p1.hero.get_hp()
	_tick()
	e["heal_in_range"] = _ms.p1.hero.get_hp() - hp
	_in_range = false
	for _t in Fx.HEAL_INTERVAL_TICKS - 1:
		_tick()
	hp = _ms.p1.hero.get_hp()
	_tick()
	e["heal_out_of_range"] = _ms.p1.hero.get_hp() - hp
	# 2. Elemental Fury REFUSED: P1's first landing is with a BLUE card, so it holds ONLY the blue orb; it
	#    stages Fury and the activation is refused. The card stays staged for step 4.
	assert_eq(F.total_orbs(_ms.p1), 0, "the run: P1 has earned no orb yet")
	_settle()
	_unblockable(0, Fx.FURY)
	_settle()
	_card(0, Fx.FURY, Enums.ModeKind.PITCH)
	var refusals: Array = []
	var on_reject := func(action: StringName, reason: StringName) -> void: refusals.append([action, reason])
	_ms.p1.hero.action_rejected.connect(on_reject)
	_act(0, F.activate_intent())
	_ms.p1.hero.action_rejected.disconnect(on_reject)
	e["fury_refusal"] = refusals
	# 3. An unblockable (earning a red orb): the Healer fires and its shot lands on P2's hero.
	_settle()
	var shots := _ms.p1.projectiles.size()
	_unblockable(0, F.PLAIN)
	while _ms.p1.projectiles.size() == shots:
		_tick()
	hp = _ms.p2.hero.get_hp()
	_tick([[0, MatchState.projectile_attacker_index(shots), 1, -1, MatchState.CONTACT_STRIKE,
			_ms.p2.hero.facing]])
	e["healer_shot"] = hp - _ms.p2.hero.get_hp()
	# 4. Two more orbs (green, blue): the staged Fury activates and fires red, blue and green.
	_settle()
	_unblockable(0, F.STONE)
	_settle()
	_unblockable(0, Fx.FURY)
	_settle()
	var first := _ms.p1.projectiles.size()
	_act(0, F.activate_intent())
	for _t in 2 * Fx.VOLLEY_TICKS:
		_tick()
	var colors_fired: Array = []
	for shot in range(first, _ms.p1.projectiles.size()):
		colors_fired.append(_ms.p1.projectiles.color_at(shot))
	e["fury_colors"] = colors_fired
	hp = _ms.p2.hero.get_hp()
	_tick([[0, MatchState.projectile_attacker_index(first), 1, -1, MatchState.CONTACT_STRIKE,
			_ms.p2.hero.facing]], null, F.press(&"block"))
	e["fury_red_deflected_damage"] = hp - _ms.p2.hero.get_hp()
	_settle()
	_tick([[0, MatchState.projectile_attacker_index(first + 1), 1, -1, MatchState.CONTACT_STRIKE,
			_ms.p2.hero.facing]])
	e["fury_blue_slowed"] = _ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW)
	hp = _ms.p1.hero.get_hp()
	_tick([[0, MatchState.projectile_attacker_index(first + 2), 1, -1, MatchState.CONTACT_STRIKE,
			_ms.p2.hero.facing]])
	e["fury_green_heal"] = _ms.p1.hero.get_hp() - hp
	# 5. P2 summons a hound and a totem; P1's Wrath (paid with the blue orb Fury left held) takes the hero,
	#    the hound and the totem.
	_settle()
	_card(1, HOUND, Enums.ModeKind.BASIC)
	var hound := _ms.p2.units.size() - 1
	_settle()
	_card(1, TOTEM, Enums.ModeKind.BASIC)
	var totem := _ms.p2.units.size() - 1
	_settle()
	assert_true(_ms.p1.orbs.get_count(Enums.CardColor.BLUE) >= 1, "the run: Fury left P1 its blue orb")
	var hero_hp := _ms.p2.hero.get_hp()
	var hound_hp := _ms.p2.units.hp_at(hound)
	var totem_hp := _ms.p2.units.hp_at(totem)
	_wrath([[-1, Vector2.LEFT], [hound, Vector2.UP], [totem, Vector2.RIGHT]])
	e["wrath_hero"] = hero_hp - _ms.p2.hero.get_hp()
	e["wrath_hound"] = hound_hp - _ms.p2.units.hp_at(hound)
	e["wrath_totem"] = totem_hp - _ms.p2.units.hp_at(totem)
	# 6. A second Wrath meets P2's block, facing the caster.
	_earn_blue_for(0)
	hero_hp = _ms.p2.hero.get_hp()
	_wrath([[-1, _ms.p2.hero.facing]], true)
	e["wrath_blocked"] = hero_hp - _ms.p2.hero.get_hp()
	# 7. A second Healer, countered.
	_earn_blue_for(1)
	_card(1, F.COUNTER, Enums.ModeKind.PITCH)
	_settle()
	_card(0, Fx.HEALER, Enums.ModeKind.BASIC)
	var second := _ms.p1.units.size() - 1
	_act(1, F.activate_intent())
	e["healer_countered"] = not _ms.p1.units.is_alive_at(second) and not _ms.p1.units.has_corpse_at(second)
	# 8. A third Wrath, its windup countered. P1 banks its blue first, so nothing knocks P2 down after it has
	#    staged its Counterspell.
	_earn_blue_for(0)
	_earn_blue_for(1)
	_card(1, F.COUNTER, Enums.ModeKind.PITCH)
	_settle()
	_card(0, Fx.WRATH, Enums.ModeKind.PITCH)
	_act(0, F.activate_intent())
	var casting := _ms.p1.is_casting()
	hero_hp = _ms.p2.hero.get_hp()
	_act(1, F.activate_intent())
	for _t in Fx.WINDUP_TICKS + 2:
		_tick([[0, -1, 1, -1, MatchState.CONTACT_PULSE, Vector2.LEFT]])
	e["windup_countered"] = casting and not _ms.p1.is_casting() and _ms.p2.hero.get_hp() == hero_hp
	for _t in 5:
		_tick()
	e["ran"] = true
	return e


# ---------------------------------------------------------------- the runner's role

## One recorded tick. `contacts` rows are [attacker slot, attacker index, target slot, target index, kind,
## dir]; the heal-range facts for P1's living Healers ride first while `_in_range` is set.
func _tick(contacts: Array = [], p1: InputIntent = null, p2: InputIntent = null) -> void:
	if _in_range:
		var healer_kind := _ms.balance.kind_index_of(&"healer")
		for index in _ms.p1.units.size():
			if _ms.p1.units.is_alive_at(index) and _ms.p1.units.kind_index_at(index) == healer_kind:
				_record.capture_push_heal_range(0, index)
				_ms.push_heal_range(0, index)
	for fact: Array in contacts:
		var attacker: Array[int] = [int(fact[0]), int(fact[1])]
		var target: Array[int] = [int(fact[2]), int(fact[3])]
		var attack_index := _seat(int(fact[0])).hero.attack_index
		_record.capture_push_contact(attacker, target, attack_index, fact[5] as Vector2, int(fact[4]))
		_ms.push_contact(attacker, target, attack_index, fact[5] as Vector2, int(fact[4]))
	var intents: Array[InputIntent] = [p1 if p1 != null else InputIntent.new(),
			p2 if p2 != null else InputIntent.new()]
	_record.capture_advance(intents)
	_ms.advance(intents)
	_ms.drain_signals()


func _seat(index: int) -> PlayerState:
	return _ms.p1 if index == 0 else _ms.p2


func _act(index: int, intent: InputIntent, contacts: Array = []) -> void:
	if index == 0:
		_tick(contacts, intent, null)
	else:
		_tick(contacts, null, intent)


func _settle() -> void:
	for _t in WAIT_LIMIT:
		var free := true
		for player: PlayerState in [_ms.p1, _ms.p2]:
			if player.hero.action_state != HeroState.ActionState.IDLE or player.hero.is_getting_up() \
					or player.hero.unblockable_immunity.is_running or player.is_casting() \
					or player.knockback_window.is_running or player.mana.get_current() < 7.0:
				free = false
		if free:
			return
		_tick()
	assert_true(false, "the run settled within %d ticks" % WAIT_LIMIT)


func _card(index: int, id: StringName, mode: Enums.ModeKind) -> void:
	var slot := _seat(index).hand.to_array().find(id)
	assert_true(slot >= 0, "the run: seat %d still holds '%s'" % [index + 1, id])
	_act(index, F.card_intent(maxi(slot, 0), mode))


## Seat `index` initiates an unblockable with `id` and carries it to its end, pushing an INSIDE reach fact
## every tick -- recorded, like every other fact. A landing grants one orb of the card's colour.
func _unblockable(index: int, id: StringName) -> void:
	_card(index, id, Enums.ModeKind.UNBLOCKABLE)
	var player := _seat(index)
	assert_eq(player.hero.action_state, HeroState.ActionState.CHARGING,
		"the run: seat %d's unblockable press with '%s' was accepted" % [index + 1, id])
	for _t in F.CHARGEUP_TICKS + F.LAUNCH_TICKS + 4:
		if player.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_tick([[index, -1, 1 - index, -1, MatchState.CONTACT_CHARGE_REACH_INSIDE, F.FACT_DIR]])


func _melee(index: int) -> void:
	_settle()
	_act(index, F.press(&"attack"))
	_tick()
	_tick()
	_tick([[index, -1, 1 - index, -1, MatchState.CONTACT_STRIKE, F.FACT_DIR]])


## Seat `index` lands an unblockable with a BLUE card to bank one blue orb (P1 spends a Bolt card, P2 a
## Counterspell card).
func _earn_blue_for(index: int) -> void:
	_settle()
	_unblockable(index, F.COUNTER if index == 1 else F.BOLT)
	_settle()


## P1 stages and activates Wrath, then pushes `ring` ([target index, dir]) every windup tick. With `block`,
## P2 presses block on the ACTIVATION tick and holds it -- early enough that its deflect window (and that
## window's one grace tick) has closed by the strike, so the pulse meets a plain block.
func _wrath(ring: Array, block := false) -> void:
	_card(0, Fx.WRATH, Enums.ModeKind.PITCH)
	_tick([], F.activate_intent(), F.press(&"block") if block else null)
	assert_true(_ms.p1.is_casting(), "the run: the Wrath windup started")
	var k := 0
	while _ms.p1.is_casting() and k < Fx.WINDUP_TICKS + 2:
		k += 1
		var facts: Array = []
		for fact: Array in ring:
			facts.append([0, -1, 1, int(fact[0]), MatchState.CONTACT_PULSE, fact[1] as Vector2])
		_tick(facts, null, F.held(&"block") if block else null)


## The SECOND, independent MatchState -- driven only by the record. `drop` withholds one channel.
func _replay(record: IntentRecorder, drop := "") -> MatchState:
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	assert_true(record.replay_inject_content(ms), "the recorded content order replays")
	for tick in range(1, record.tick_count() + 1):
		if drop != "heal_range":
			record.replay_push_heal_ranges(ms, tick)
		if drop != "contacts":
			record.replay_push_contacts(ms, tick)
		var intents: Array[InputIntent] = [record.replay_intent(tick, 0), record.replay_intent(tick, 1)]
		if drop == "intents":
			intents = [InputIntent.new(), InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()
	return ms
