extends SceneTree

## Story 4-3b (AC 2 / AC 6 / AC 8 / AC 13 / AC 17, live): A REAL MINION SWINGS AT A REAL HERO
## THROUGH THE REAL CONTACT PIPELINE -- the unit's own `Area3D` hitbox, the runner's
## `get_overlapping_areas()` query, the widened `[slot, index]` ATTACKER address, `push_contact`,
## and step 4.
##
## WHY THIS EXISTS AS A MACHINE TEST AT ALL: the headless state suite structurally cannot see any of
## it. test_unit_attack_rhythm.gd proves the STATE contract -- a fact whose attacker address names a
## unit resolves, the rhythm counts the authored ticks, the flag gates the windup -- and every word
## of that stays true of a build in which the unit carries NO HITBOX AT ALL, in which no probe is
## ever gathered, and in which the whole attack is an abstract cadence that damages the acquired
## target with no overlap test. Those are exactly the failures this file exists to catch.
##
## THE CLAIMS, each with the pair that makes it non-vacuous:
##
##   AC 2   PHASE A, THE ANTI-ABSTRACT PIN: the unit is IN REACH by the probe's own planar measure
##          and runs its full rhythm -- windup, active window, recovery, twice over -- while its
##          hitbox physically cannot overlap the target, because the unit is LIFTED clear of it.
##          Reach is planar (XZ), overlap is volumetric, so this arrangement separates the two
##          exactly. An ABSTRACT implementation (damage the acquired target when the window opens)
##          passes a "damage lands" test and FAILS HERE. Pair: Phase B, where the same unit put back
##          on the ground with everything else unchanged DOES land damage -- so the zero is
##          attributable to the missing OVERLAP and not to a rhythm that never ran.
##
##   AC 6   the attacker's OWN SUMMONER and its OWN SIBLING stand INSIDE its hitbox volume for the
##          whole of Phase B and take NOTHING. Pair: the enemy hero beyond them is damaged through
##          that same volume in the same frames, so the zero is attributable to the GATHER-TIME
##          friendly-fire filter and not to a swing that missed. Both are asserted to have been
##          inside the swept volume, so neither half can pass by being out of range. AND NO HALT:
##          `push_contact` asserts `attacker_slot != target_slot`, so a same-slot fact reaching the
##          seam would trip an Invariant -- the run completing at all is half the claim.
##
##   AC 8   `hit_landed` IS emitted when a unit damages a HERO, with a BARE INT attacker slot
##          (`4-3b/R15`). Pair: its payload's target slot is asserted, so "a signal fired" is not
##          "some signal fired".
##
##   AC 13  THE PROBE IS THROTTLED, not gathered every tick. Counted off the RECORDER's own contact
##          rows, which is the stream the throttle exists to bound. Pair: the count is asserted to
##          be BOTH well below one-per-tick (an unthrottled build fails) AND nonzero (a build that
##          never probes fails, and would also make every other claim here vacuous).
##
##   AC 17  a unit-versus-unit hit lands through the same opening: the SIBLING is P1's, so this is
##          measured against a THIRD unit summoned by P2 and parked beside its hero.
##
## POSITIONS ARE SET DIRECTLY rather than walked into place, and that is deliberate: position is
## actor-owned (`4-1/R12`), the approach is owned end to end by test_unit_approach_live.gd, and this
## file is about the ATTACK pipeline. Placing every body by construction is what makes AC 6's
## negative half non-vacuous -- a friendly that merely happened to be out of reach would "pass" it
## for the wrong reason.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_attack_live.gd

const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const RELEASE_FRAME := 14
const SECOND_ARM_FRAME := 18
const SECOND_CONFIRM_FRAME := 24
const SECOND_RELEASE_FRAME := 28
const P2_ARM_FRAME := 32
const P2_CONFIRM_FRAME := 38
const P2_RELEASE_FRAME := 42
const SPAWN_CHECK_FRAME := 46

## How far the attacker is parked from its target, planar. Inside the authored reach (so the probe
## reports in-reach) and inside the hitbox's own forward span (so a grounded overlap really happens).
const PARK_DISTANCE := 1.4
## Phase A lifts the attacker straight up. Planar distance -- and therefore REACH -- is untouched;
## the volumes cannot meet. This is the whole mechanism of the anti-abstract pin.
const LIFT_HEIGHT := 6.0
## Where the summoner and the sibling stand: between the attacker and its target, inside the swept
## hitbox volume, offset sideways from each other so two bodies do not fight for one space.
const SHIELD_DISTANCE := 0.7
const SHIELD_SIDE := 0.34

## Pinned-to-composition was the defect, found when deck_size 20 -> 24 at the 4-4 live smoke: a
## fixed seed no longer guarantees a summoning card lands in the frame-3 hand. Reshuffle through
## the same debug-reset input path a player uses instead of pinning the deal; the RNG advances
## deterministically each reshuffle, so the retry sequence is identical on every run.
const RESHUFFLE_MAX_ATTEMPTS := 12
const RESHUFFLE_SETTLE_TICKS := 10

var _reshuffling := false
var _reshuffle_tick := 0
var _reshuffle_attempts := 0

var _frames := 0
var _runner: Node
var _state: MatchState
var _cycle_ticks := 0
var _phase_a_end := 0
var _phase_b_end := 0

var _p1_action := &""
var _p1_action_2 := &""
var _p2_action := &""
var _slots_chosen := false
var _spawned := false

var _phase_a_active_ticks := 0
var _phase_a_damage := 0.0
var _phase_a_hp := 0.0
var _phase_b_start_hp := 0.0
var _phase_b_damage := 0.0
var _enemy_unit_start_hp := 0.0
var _enemy_unit_damage := 0.0
var _summoner_start_hp := 0.0
var _summoner_damage := 0.0
var _sibling_start_hp := 0.0
var _sibling_damage := 0.0
var _summoner_in_reach := false
var _sibling_in_reach := false
var _hits: Array = []
var _detail := ""
var _done := false
var _quit_at := -1


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	if _reshuffling:
		return _drive_reshuffle()
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		# Story 4-4 (AC 6/AC 9): the reach and the damage are on the MINION kind's attack RECORD now.
		# Resolved BY NAME so a reordered `unit_kinds` fails loudly rather than measuring a totem.
		var b := _state.balance
		var kind_index := b.kind_index_of(&"minion")
		var kind: UnitKindProfile = b.kind_at(kind_index)
		var attack: UnitAttackProfile = kind.attack_at(0) if kind != null else null
		if attack == null:
			return _fail("authored balance carries no `minion` kind with an attack record")
		if attack.range <= 0.0 or attack.damage <= 0.0:
			return _fail("authored balance ships the mechanic invisible: reach=%f damage=%f"
					% [attack.range, attack.damage])
		# The cycle length is DERIVED from the AUTHORED durations, never pinned to literals, so the
		# `4-3b` melee retune cannot silently desynchronise this file (the `4-3/R22` discipline).
		# Story 4-4: derived from the same kind's tick record rather than the removed flat triplet.
		var t: UnitAttackTicks = _state.balance_ticks.kind_ticks_at(kind_index).attack_at(0)
		_cycle_ticks = t.windup_ticks + t.active_ticks + t.recovery_ticks
		_state.hit_landed.connect(func(a: int, target: int, d: float, hp: float) -> void:
			_hits.append([a, target, d, hp]))
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		_state.p2.mana.add(_state.p2.mana.get_maximum())
		if not _state.flags.minions:
			return _fail("the authored FeatureFlags has minions OFF -- this test cannot summon")
	if _frames == 3:
		_slots_chosen = _choose_two_summon_slots(_state.p1) and _choose_summon_slot(_state.p2, "p2")
		if not _slots_chosen:
			_reshuffling = true
			_reshuffle_tick = 0
			return false
	_cast(ARM_FRAME, CONFIRM_FRAME, RELEASE_FRAME, &"p1_cast_mode", &"p1_cast_confirm", _p1_action)
	_cast(SECOND_ARM_FRAME, SECOND_CONFIRM_FRAME, SECOND_RELEASE_FRAME, &"p1_cast_mode",
			&"p1_cast_confirm", _p1_action_2)
	_cast(P2_ARM_FRAME, P2_CONFIRM_FRAME, P2_RELEASE_FRAME, &"p2_cast_mode", &"p2_cast_confirm",
			_p2_action)

	if _frames == SPAWN_CHECK_FRAME:
		_spawned = _state.p1.units.size() == 2 and _state.p2.units.size() == 1 \
				and _unit_actor(0, 0) != null and _unit_actor(0, 1) != null \
				and _unit_actor(1, 0) != null
		if not _spawned:
			return _fail("spawn failed: p1_board=%d p2_board=%d actors=%s/%s/%s"
					% [_state.p1.units.size(), _state.p2.units.size(), _unit_actor(0, 0),
						_unit_actor(0, 1), _unit_actor(1, 0)])
		_phase_a_hp = _state.p2.hero.get_hp()
		# TWO full cycles with the attacker LIFTED: long enough that a rhythm which runs at all must
		# open its window, and an abstract implementation must land something.
		_phase_a_end = _frames + _cycle_ticks * 2 + 20
		_phase_b_end = _phase_a_end + _cycle_ticks * 3 + 20

	if _frames > SPAWN_CHECK_FRAME and not _done:
		var lifted := _frames <= _phase_a_end
		_park(lifted)
		if lifted:
			if _state.p1.units.is_hitbox_active_at(0):
				_phase_a_active_ticks += 1
			_phase_a_damage = _phase_a_hp - _state.p2.hero.get_hp()
		if _frames == _phase_a_end:
			_phase_b_start_hp = _state.p2.hero.get_hp()
			_enemy_unit_start_hp = _state.p2.units.hp_at(0)
			_summoner_start_hp = _state.p1.hero.get_hp()
			_sibling_start_hp = _state.p1.units.hp_at(1)
		if _frames == _phase_b_end:
			_phase_b_damage = _phase_b_start_hp - _state.p2.hero.get_hp()
			_enemy_unit_damage = _enemy_unit_start_hp - _state.p2.units.hp_at(0)
			_summoner_damage = _summoner_start_hp - _state.p1.hero.get_hp()
			_sibling_damage = _sibling_start_hp - _state.p1.units.hp_at(1)
			_done = true
			# Review fix pass (4-3b, C1): quitting the instant the last measurement lands leaks a
			# "resources still in use at exit" in roughly half of repeated runs -- the same cause
			# measured in test_live_attack.gd (4-3b, F4): engine teardown races whatever this
			# frame's contact/signal activity still has in flight. A settle delay after the last
			# assertion-relevant read removes the leak with no change to what is measured.
			_quit_at = _frames + 30
	if _quit_at != -1 and _frames >= _quit_at:
		return _report()
	return false


## Every body placed by construction, every frame -- the approach step drives units toward their
## targets, so a one-shot placement would drift.
##
## GEOMETRY: the attacker sits `PARK_DISTANCE` from P2's hero. Between them, inside the attacker's
## swept hitbox volume, stand P1's OWN HERO and P1's OTHER UNIT -- the two things AC 6 says must take
## nothing. P2's own unit stands beside P2's hero, inside the same volume, and is the AC 17 subject.
func _park(lift: bool) -> void:
	var target: Node3D = _runner._p2_hero
	var attacker := _unit_actor(0, 0)
	var sibling := _unit_actor(0, 1)
	var summoner: Node3D = _runner._p1_hero
	var enemy_unit := _unit_actor(1, 0)
	if target == null or attacker == null:
		return
	var base := target.global_position
	base.y = 0.0
	# A fixed world direction: nothing here depends on where the heroes happen to have walked.
	var forward := Vector3(0.0, 0.0, 1.0)
	var side := Vector3(1.0, 0.0, 0.0)
	var attacker_position := base + forward * PARK_DISTANCE
	attacker_position.y = LIFT_HEIGHT if lift else 0.0
	attacker.global_position = attacker_position
	# The two friendlies, between the attacker and its target -- i.e. inside the hitbox.
	var shield := base + forward * SHIELD_DISTANCE
	shield.y = attacker_position.y
	if sibling != null:
		sibling.global_position = shield + side * SHIELD_SIDE
		if _planar(sibling.global_position, attacker_position) <= 1.6:
			_sibling_in_reach = true
	if summoner != null:
		# The hero root is its body CENTRE, so it is raised half its own height off the floor.
		var hero_position := shield - side * SHIELD_SIDE
		hero_position.y = attacker_position.y + 1.0
		summoner.global_position = hero_position
		if _planar(hero_position, attacker_position) <= 1.6:
			_summoner_in_reach = true
	if enemy_unit != null:
		# Inside the hitbox's LATERAL half-extent (the box is 1.0 wide, so +/-0.5 either side of
		# the attacker's forward axis) and slightly forward of the hero, so it sits in the swept
		# volume rather than beside it. This is AC 17's live subject.
		var enemy_position := base + side * 0.4 + forward * 0.4
		# GROUNDED IN BOTH PHASES, deliberately unlike the two friendlies: during Phase A the
		# attacker is lifted clear, so a grounded enemy unit is out of its volume and enters the
		# measurement untouched at full health. Lifting it WITH the attacker would let Phase A kill
		# it and leave Phase B nothing to measure.
		enemy_position.y = 0.0
		enemy_unit.global_position = enemy_position


func _report() -> bool:
	var probes := _probe_tick_span()
	var interval := _state.balance_ticks.minion_retarget_interval_ticks
	var span := int(probes["span"])
	var probe_ticks := int(probes["ticks"])
	# --- AC 2, phase A: the rhythm RAN and landed NOTHING.
	var rhythm_ran := _phase_a_active_ticks > 0
	if not rhythm_ran:
		_detail += " phase_a_never_opened_a_window(the anti-abstract pin would be vacuous);"
	var no_abstract_damage := is_equal_approx(_phase_a_damage, 0.0)
	if not no_abstract_damage:
		_detail += " phase_a_dealt_damage(%.3f -- an ABSTRACT resolution, not a hitbox overlap);" \
				% _phase_a_damage
	# --- AC 2, phase B: the same unit, grounded, DOES land.
	var landed := _phase_b_damage > 0.0
	if not landed:
		_detail += " phase_b_landed_nothing(so phase A's zero proves nothing);"
	# --- AC 6: NO SAME-SLOT FACT WAS EVER PRODUCED, measured at the FACT level rather than by hp.
	#
	# THE FACT IS THE RIGHT MEASUREMENT AND HP IS THE WRONG ONE, measured at this pass: P2's own
	# minion is parked in the same cluster and legitimately attacks P1's hero and P1's sibling
	# unit -- that is the system WORKING, and it moves their hp for a reason that has nothing to
	# do with the friendly-fire filter. AC 6's own words are 'produces NO FACT, no damage, and no
	# halt', and the FACT is the thing the filter actually controls.
	#
	# IT IS ALSO THE STRICTER CLAIM. The recorder tap runs immediately BEFORE `push_contact`, so a
	# same-slot fact that slipped past the gather filter would be RECORDED here and only then trip
	# the seam's Invariant -- which headless PRINTS and continues. So this count falls exactly
	# where an `Invariant.check` cannot be proven by firing it, and the absence of an INVARIANT
	# VIOLATED line from the run is the 'no halt' half on top of it.
	#
	# PAIRED, so it cannot pass by nothing ever being gathered: unit-SOURCED facts against the
	# OPPOSING slot must exist in the same span.
	var same_slot := 0
	var opposing := 0
	var recorder: IntentRecorder = _runner._recorder
	for tick in range(SPAWN_CHECK_FRAME, recorder.tick_count() + 1):
		for row: Array in recorder.contacts_at(tick):
			if int(row[0]) == int(row[2]):
				same_slot += 1
			elif int(row[1]) >= 0:
				opposing += 1
	var friendly_safe := same_slot == 0 and opposing > 0
	if same_slot > 0:
		_detail += " same_slot_facts=%d(the gather-time friendly-fire filter leaked);" % same_slot
	if opposing == 0:
		_detail += " no_unit_sourced_facts_at_all(AC 6 would be vacuous);"
	var informational := " [informational: summoner_hp_delta=%.2f sibling_hp_delta=%.2f -- both " 			% [_summoner_damage, _sibling_damage]
	_detail += informational + "from P2's OWN minion attacking them, never friendly fire]"
	var friendlies_were_in_reach := _summoner_in_reach and _sibling_in_reach
	if not friendlies_were_in_reach:
		_detail += " friendlies_out_of_reach(summoner=%s sibling=%s -- AC 6 would be vacuous);" \
				% [_summoner_in_reach, _sibling_in_reach]
	# --- AC 8: hit_landed fired, on the hero, with a BARE INT attacker.
	var hero_hits := 0
	var bare_int_attacker := true
	for hit: Array in _hits:
		if int(hit[1]) == 1:
			hero_hits += 1
		if typeof(hit[0]) != TYPE_INT:
			bare_int_attacker = false
	if hero_hits == 0:
		_detail += " no_hit_landed_for_the_damaged_hero;"
	if not bare_int_attacker:
		_detail += " hit_landed_attacker_is_not_a_bare_int(`4-3b/R15`);"
	# --- AC 13: throttled, not per-tick. Both bounds, so neither direction passes vacuously.
	var throttled := span > 0 and probe_ticks > 0 and probe_ticks <= (span / interval) + 2
	if not throttled:
		_detail += " probe_cadence(ticks_with_a_probe=%d over span=%d, interval=%d);" \
				% [probe_ticks, span, interval]
	# --- AC 5, THE LIVE GATHER SEAT: within every single tick, the facts the runner produced are
	#     in the CANONICAL cross-attacker order -- slot ascending, then board index ascending,
	#     with a hero's `-1` sorting ahead of every unit on its own board.
	#
	#     MEASURED OFF THE RECORDED STREAM, not scanned out of the source, so it is the ORDER the
	#     runner actually produced under a real physics query rather than the order its call
	#     sites are written in. `test_unit_attack_rhythm.gd` owns the other half -- that state
	#     RESOLVES canonically whatever order it is fed -- and the two together are why AC 5's
	#     property does not rest on this seat alone.
	#
	#     PAIRED against the fact that several DISTINCT attackers really did appear in one tick;
	#     a stream in which no tick ever carried two attackers would satisfy any ordering.
	var out_of_order := 0
	var ticks_with_two_attackers := 0
	for tick in range(SPAWN_CHECK_FRAME, recorder.tick_count() + 1):
		var previous := [-99, -99]
		var attackers: Array = []
		for row: Array in recorder.contacts_at(tick):
			var key := [int(row[0]), int(row[1])]
			if key[0] < previous[0] or (key[0] == previous[0] and key[1] < previous[1]):
				out_of_order += 1
			previous = key
			if not attackers.has(key):
				attackers.append(key)
		if attackers.size() >= 2:
			ticks_with_two_attackers += 1
	var canonical_gather := out_of_order == 0 and ticks_with_two_attackers > 0
	if out_of_order > 0:
		_detail += " gather_order_not_canonical(%d inversions);" % out_of_order
	if ticks_with_two_attackers == 0:
		_detail += " no_tick_carried_two_attackers(AC 5's live half would be vacuous);"
	# --- AC 17: the enemy UNIT beside the hero was hit by the same swings.
	var unit_vs_unit := _enemy_unit_damage > 0.0
	if not unit_vs_unit:
		_detail += " enemy_unit_untouched(AC 17's live half; started at %.2f);" % _enemy_unit_start_hp

	var ok := _slots_chosen and _spawned and rhythm_ran and no_abstract_damage and landed \
			and friendly_safe and friendlies_were_in_reach and hero_hits > 0 \
			and bare_int_attacker and throttled and unit_vs_unit and canonical_gather
	print("unit_attack_live: phase_a_active_ticks=%d phase_a_damage=%.3f phase_b_damage=%.3f "
			% [_phase_a_active_ticks, _phase_a_damage, _phase_b_damage]
			+ "summoner_dmg=%.3f sibling_dmg=%.3f in_reach=%s/%s enemy_unit_dmg=%.3f "
			% [_summoner_damage, _sibling_damage, _summoner_in_reach, _sibling_in_reach,
				_enemy_unit_damage]
			+ "hero_hits=%d probe_ticks=%d/span=%d interval=%d same_slot_facts=%d "
			% [hero_hits, probe_ticks, span, interval, same_slot]
			+ "opposing_facts=%d gather_inversions=%d multi_attacker_ticks=%d%s"
			% [opposing, out_of_order, ticks_with_two_attackers, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


## How many DISTINCT TICKS carried a REACH PROBE from the attacking unit, and over how many ticks --
## read off the RECORDER's own rows, which is the stream the throttle exists to bound. Counted only
## from the tick the attacker was first parked, so the pre-spawn ticks do not dilute the ratio.
func _probe_tick_span() -> Dictionary:
	var recorder: IntentRecorder = _runner._recorder
	var total := recorder.tick_count()
	var first := SPAWN_CHECK_FRAME
	var ticks := 0
	for tick in range(first, total + 1):
		for row: Array in recorder.contacts_at(tick):
			if row.size() >= 7 and int(row[6]) == MatchState.CONTACT_REACH_PROBE \
					and int(row[0]) == 0 and int(row[1]) == 0:
				ticks += 1
				break
	return {"ticks": ticks, "span": maxi(0, total - first)}


func _cast(arm: int, confirm: int, release: int, mode: StringName, confirm_action: StringName,
		card: StringName) -> void:
	if _frames == arm:
		Input.action_press(mode)
	if _frames == arm + 1:
		Input.action_press(card)
	if _frames == arm + 2:
		Input.action_release(card)
	if _frames == confirm:
		Input.action_press(confirm_action)
	if _frames == confirm + 2:
		Input.action_release(confirm_action)
	if _frames == release:
		Input.action_release(mode)


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


## Drives one press/release/settle cycle of the debug reset, then re-checks the dealt hand.
## Bounded so a build that never deals a summoning card still fails, rather than hanging.
func _drive_reshuffle() -> bool:
	_reshuffle_tick += 1
	if _reshuffle_tick == 1:
		Input.action_press(&"p1_debug_reset")
	if _reshuffle_tick == 3:
		Input.action_release(&"p1_debug_reset")
	if _reshuffle_tick == RESHUFFLE_SETTLE_TICKS:
		_slots_chosen = _choose_two_summon_slots(_state.p1) and _choose_summon_slot(_state.p2, "p2")
		if _slots_chosen:
			_reshuffling = false
			return false
		_reshuffle_attempts += 1
		if _reshuffle_attempts >= RESHUFFLE_MAX_ATTEMPTS:
			return _fail("no summoning card dealt: p1=[%s,%s] p2=%s (after %d reshuffle attempts)"
					% [_p1_action, _p1_action_2, _p2_action, _reshuffle_attempts])
		_reshuffle_tick = 0
	return false


func _unit_actor(slot: int, index: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[slot]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## TWO distinct dealt slots whose authored cards carry a `summon_*` effect, so P1 can summon twice.
func _choose_two_summon_slots(player: PlayerState) -> bool:
	var found: Array[StringName] = []
	for index in _summon_slots(player):
		var action := StringName("p1_card_%d" % (index + 1))
		if InputMap.has_action(action):
			found.append(action)
		if found.size() == 2:
			break
	if found.size() < 2:
		return false
	_p1_action = found[0]
	_p1_action_2 = found[1]
	return true


func _choose_summon_slot(player: PlayerState, prefix: String) -> bool:
	for index in _summon_slots(player):
		var action := StringName("%s_card_%d" % [prefix, index + 1])
		if InputMap.has_action(action):
			_p2_action = action
			return true
	return false


## Every dealt hand slot whose authored card carries a `summon_*` effect, in hand order.
func _summon_slots(player: PlayerState) -> Array[int]:
	var out: Array[int] = []
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return out
	var hand := player.hand.to_array()
	for index in hand.size():
		if player.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		# Story 4-4 (AC 1): MINION-summoning cards ONLY. Before this story every `summon_*` id
		# resolved to one uniform unit, so any of them served. Three of them now summon TOTEMS --
		# which stand still (`4-4/R12`), carry no animation rig, and in the Combat totem's case fire
		# a projectile instead of swinging -- so a test that measures MINION behaviour must not have
		# its subject chosen by the shuffle. The exclusion reads the resolver's OWN table rather than
		# a second list of totem ids, so the two can never disagree.
		var effect_id: StringName = card.basic_effect.effect_id
		var is_summon := String(effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON)
		var is_totem := CardEffectResolver.SUMMON_KINDS.has(effect_id)
		if is_summon and not is_totem:
			out.append(index)
	return out
