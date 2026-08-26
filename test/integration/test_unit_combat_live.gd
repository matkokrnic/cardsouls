extends SceneTree

## Story 4-3a (AC 4 / AC 6 / AC 11): A HERO'S REAL SWING KILLS A REAL MINION THROUGH THE REAL
## CONTACT PIPELINE -- the unit's `Area3D` hurtbox, the runner's `get_overlapping_areas()` query, the
## widened `[slot, index]` target address, `push_contact`, and step 4 -- and the corpse's ACTOR
## ENTERS THE CORPSE LIFECYCLE (story 4-3d inverted this line: it used to read "LEAVES THE SCENE").
##
## WHY THIS EXISTS AS A MACHINE TEST AT ALL: the headless state suite structurally cannot see any of
## it (`3-0b/R34`'s blind spot). test_unit_damage_and_death.gd proves the STATE contract -- a fact
## addressed to `[slot, index]` takes the flat damage and a corpse is a hole -- and every word of
## that stays true of a build in which the unit carries NO HURTBOX AT ALL and no fact is ever
## gathered. AC 4's whole claim is that the `_slot_of == -1` DROP IS OPENED, and the only place that
## is observable is a live overlap query against a real scene.
##
## THE THREE CLAIMS, each with the pair that makes it non-vacuous:
##   AC 4  the ENEMY unit's hp falls and reaches zero under real swings. Pair: it starts at the
##         authored maximum and is measured ALIVE first, so "it died" is not "it was never there".
##   AC 6  the hero's OWN unit, standing in the SAME hitbox volume at the SAME time, takes NOTHING.
##         Pair: the enemy unit beside it dies, so the zero is attributable to the FRIENDLY-FIRE
##         FILTER and not to a swing that missed everything. Both units are asserted to be inside
##         the hitbox reach when the swing lands, so neither half can pass by being out of range.
##   AC 11 the dead unit's ACTOR reaches the corpse lifecycle -- CORRECTED BY STORY 4-3d, which
##         inverted the timing: the actor is no longer freed on the death tick, it LINGERS, so
##         what this file asserts is that the corpse is still at its own index and has been TOLD
##         it died. The 600-tick expiry and the hole that follows belong to
##         test_unit_corpse_linger_live.gd. Pair: the friendly unit's actor is still in the tree
##         and NOT lingering, so neither half is "the whole scene was torn down".
##
## POSITIONS ARE SET DIRECTLY rather than walked into place, and that is deliberate. Position is
## actor-owned (`4-1/R12`), the APPROACH is already owned end-to-end by test_unit_approach_live.gd,
## and this file is about the CONTACT pipeline. Placing both units inside the hitbox volume by
## construction is what makes AC 6's negative half non-vacuous -- a friendly unit that merely
## happened to be out of reach would "pass" it for the wrong reason.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_combat_live.gd

const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const P2_ARM_FRAME := 18
const P2_CONFIRM_FRAME := 24
const P2_CONFIRM_RELEASE_FRAME := 28
const SPAWN_CHECK_FRAME := 32
const PLACE_FRAME := 36

## One swing is windup + active + recovery at the AUTHORED durations; the cadence is DERIVED at
## runtime from them rather than pinned to literals, so the `4-3b` melee retune cannot silently
## desynchronise this file (the `4-3/R22` discipline).
const SWING_MARGIN_TICKS := 6
const MAX_SWINGS := 12

## Where the two units are parked, along the hero's own facing: the HitboxShape is a 1 x 1 x 1 box at
## local z 0.9, so it spans 0.4 .. 1.4 ahead of the hero centre. 0.95 sits solidly inside that, and
## the units are offset sideways so two 0.6-wide bodies do not fight for the same space.
const REACH_DISTANCE := 0.95
const SIDE_OFFSET := 0.35
## The hitbox's own planar half-extent plus the unit hurtbox's, used only to ASSERT both units really
## were inside the swept volume -- the non-vacuity guard, not a placement input.
const IN_REACH_MAX := 1.4
const IN_REACH_MIN := 0.4

var _frames := 0
var _runner: Node
var _state: MatchState

var _p1_slot_chosen := false
var _p2_slot_chosen := false
var _p1_action := &""
var _p2_action := &""
var _spawned := false

var _swing_period := 0
var _next_swing_frame := 0
var _swings := 0

var _unit_max_hp := 0.0
var _enemy_started_alive := false
var _enemy_ever_in_reach := false
var _friendly_ever_in_reach := false
var _enemy_died := false
var _enemy_corpse_lingering := false
var _enemy_still_at_same_index := false
var _friendly_untouched := false
var _friendly_actor_alive := false
var _mana_after_kill := -1.0
var _last_mana := -1.0
var _max_mana_jump := 0.0
var _detail := ""
var _done := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		_unit_max_hp = _state.balance.unit_max_hp
		if _unit_max_hp <= 0.0 or _state.balance.unit_damage_per_hit <= 0.0:
			return _fail("authored balance ships the mechanic invisible: unit_max_hp=%f damage=%f"
					% [_unit_max_hp, _state.balance.unit_damage_per_hit])
		# The swing cadence, derived from the AUTHORED action durations (`4-3/R22` discipline).
		var ticks := _state.balance_ticks
		_swing_period = ticks.attack_windup_ticks + ticks.attack_active_ticks \
				+ ticks.attack_recovery_ticks + SWING_MARGIN_TICKS
	if _frames == 2:
		# P1 IS FUNDED TO HALF THE CAP, NOT TO IT, and that is load-bearing for AC 5's live half:
		# `ManaPool.add()` no-ops at the cap, so a melee grant that DID fire against a unit would be
		# invisible in a full pool. Half leaves headroom for the whole run. P2 only has to afford one
		# cast, so its funding is not measured and may be anything.
		_state.p1.mana.add(_state.p1.mana.get_maximum() * 0.5)
		_state.p2.mana.add(_state.p2.mana.get_maximum())
		if not _state.flags.minions:
			return _fail("the authored FeatureFlags has minions OFF -- this test cannot summon")
	if _frames == 3:
		_p1_slot_chosen = _choose_summon_slot(_state.p1, "p1")
		_p2_slot_chosen = _choose_summon_slot(_state.p2, "p2")
		if not _p1_slot_chosen or not _p2_slot_chosen:
			return _fail("no summoning card dealt: p1=%s p2=%s"
					% [_p1_slot_chosen, _p2_slot_chosen])
	# --- P1 summons its OWN unit (the friendly-fire subject, AC 6) ---
	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(_p1_action)
	if _frames == ARM_FRAME + 2:
		Input.action_release(_p1_action)
	if _frames == CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
	# --- P2 summons the ENEMY unit (the kill subject, AC 4 / AC 11) ---
	if _frames == P2_ARM_FRAME:
		Input.action_press(&"p2_cast_mode")
	if _frames == P2_ARM_FRAME + 1:
		Input.action_press(_p2_action)
	if _frames == P2_ARM_FRAME + 2:
		Input.action_release(_p2_action)
	if _frames == P2_CONFIRM_FRAME:
		Input.action_press(&"p2_cast_confirm")
	if _frames == P2_CONFIRM_FRAME + 2:
		Input.action_release(&"p2_cast_confirm")
	if _frames == P2_CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p2_cast_mode")
	if _frames == SPAWN_CHECK_FRAME:
		_spawned = _state.p1.units.size() == 1 and _state.p2.units.size() == 1 \
				and _unit_actor(0, 0) != null and _unit_actor(1, 0) != null
		if not _spawned:
			return _fail("spawn failed: p1_board=%d p2_board=%d p1_actor=%s p2_actor=%s"
					% [_state.p1.units.size(), _state.p2.units.size(),
						_unit_actor(0, 0), _unit_actor(1, 0)])
		_enemy_started_alive = _state.p2.units.is_alive_at(0) \
				and is_equal_approx(_state.p2.units.hp_at(0), _unit_max_hp)
		if not _enemy_started_alive:
			_detail += " enemy_not_at_full(hp=%.2f);" % _state.p2.units.hp_at(0)
		_next_swing_frame = PLACE_FRAME + 1

	# --- Park both units inside the hero's hitbox volume, every frame from here on. ---
	if _frames >= PLACE_FRAME and not _done:
		_park_units()

	# --- AC 5, live: watch for a MELEE GRANT that never should fire. Sampled every frame across the
	#     whole kill, as the largest single-tick mana INCREASE. The passive faucet runs continuously
	#     at `mana_regen_per_second / 60` per tick, which is orders of magnitude below the per-hit
	#     grant, so the two are trivially separable -- a unit confirmation leaking into step 5's
	#     confirmed-hits list would show up here as a jump of a whole `melee_hit_mana`.
	if _frames >= PLACE_FRAME:
		var mana := _state.p1.mana.get_current()
		if _last_mana >= 0.0:
			_max_mana_jump = maxf(_max_mana_jump, mana - _last_mana)
		_last_mana = mana

	# --- Swing until the enemy unit dies (or the attempt budget runs out). ---
	if _next_swing_frame > 0 and _frames == _next_swing_frame and not _done:
		Input.action_press(&"p1_attack")
		_swings += 1
	if _next_swing_frame > 0 and _frames == _next_swing_frame + 2 and not _done:
		Input.action_release(&"p1_attack")
		if _state.p2.units.is_alive_at(0) and _swings < MAX_SWINGS:
			_next_swing_frame = _frames + _swing_period
		else:
			_next_swing_frame = 0
			# Give the runner one more frame to run its post-advance free poll.
			_done = true
			_finish_frame = _frames + 3
	if _done and _frames == _finish_frame:
		return _report()
	return false


var _finish_frame := 0


## Both units placed along the hero's OWN facing, inside the HitboxShape's swept volume, offset
## sideways from each other. Re-applied every frame: the approach step drives units toward their
## acquired targets, so a one-shot placement would drift out of reach before the swing lands.
##
## The friendly unit is placed just as deliberately as the enemy one -- AC 6's claim is that a
## friendly unit INSIDE the hitbox takes nothing, and a friendly unit that wandered off would make
## the claim vacuous. `_friendly_ever_in_reach` is what turns that placement into an assertion.
func _park_units() -> void:
	var hero: Node3D = _runner._p1_hero
	if hero == null:
		return
	var facing: Vector2 = _state.p1.hero.facing
	if facing.is_zero_approx():
		facing = Vector2(0.0, 1.0)
	facing = facing.normalized()
	var forward := Vector3(facing.x, 0.0, facing.y)
	var side := Vector3(facing.y, 0.0, -facing.x)
	var base := hero.global_position + forward * REACH_DISTANCE
	base.y = 0.0
	var enemy := _unit_actor(1, 0)
	var friendly := _unit_actor(0, 0)
	if enemy != null:
		enemy.global_position = base + side * SIDE_OFFSET
		var d := _planar_distance(enemy.global_position, hero.global_position)
		if d >= IN_REACH_MIN and d <= IN_REACH_MAX:
			_enemy_ever_in_reach = true
	if friendly != null:
		friendly.global_position = base - side * SIDE_OFFSET
		var d2 := _planar_distance(friendly.global_position, hero.global_position)
		if d2 >= IN_REACH_MIN and d2 <= IN_REACH_MAX:
			_friendly_ever_in_reach = true


func _report() -> bool:
	# AC 4: the enemy unit took real damage through the real pipeline and died.
	_enemy_died = not _state.p2.units.is_alive_at(0) \
			and is_equal_approx(_state.p2.units.hp_at(0), 0.0)
	if not _enemy_died:
		_detail += " enemy_alive(hp=%.2f swings=%d);" % [_state.p2.units.hp_at(0), _swings]
	# AC 6: the hero's OWN unit, in the same volume, was never the TARGET OF A FACT this hero
	# sourced -- measured at the FACT level rather than by hp.
	#
	# CORRECTED BY STORY 4-3b, AND THE OLD INSTRUMENT WAS INVALIDATED RATHER THAN WEAKENED. This
	# read `p1.units.hp_at(0) == unit_max_hp` -- correct when it was written, because in `4-3a` a
	# unit was a TARGET and nothing else, so the only thing that could move that hp was the
	# friendly-fire filter leaking. `4-3b` makes a unit an ATTACKER: P2's enemy unit, parked in
	# this same cluster, now legitimately attacks P1's hero and cleaves P1's unit standing beside
	# it. That is the system WORKING, and it moves the hp for a reason that has nothing to do with
	# this file's claim. MEASURED at 4-3b's dev pass: the friendly unit ends at 6.00 of 9.00,
	# every other assertion in this file still passing.
	#
	# THE FACT IS THE THING THE FILTER ACTUALLY CONTROLS, and the new form is STRICTER, not looser:
	# the recorder tap runs immediately BEFORE `push_contact`, so a same-slot fact that slipped the
	# gather filter would be RECORDED here and only then trip the seam's Invariant -- which
	# headless PRINTS and continues. So this count falls exactly where an `Invariant.check` cannot
	# be proven by firing it. It is PAIRED against opposing-slot facts from this same hero, so it
	# cannot pass by nothing ever being gathered.
	var same_slot := 0
	var opposing := 0
	var recorder: IntentRecorder = _runner._recorder
	for tick in range(PLACE_FRAME, recorder.tick_count() + 1):
		for row: Array in recorder.contacts_at(tick):
			if int(row[0]) == int(row[2]):
				same_slot += 1
			elif int(row[0]) == 0 and int(row[1]) == TargetingService.HERO_INDEX:
				opposing += 1
	_friendly_untouched = same_slot == 0 and opposing > 0
	if same_slot > 0:
		_detail += " same_slot_facts=%d(the friendly-fire filter leaked);" % same_slot
	if opposing == 0:
		_detail += " hero_sourced_no_facts_at_all(AC 6 would be vacuous);"
	var note := " [4-3b: friendly unit hp %.2f of %.2f -- moved by P2's OWN minion attacking it," 			% [_state.p1.units.hp_at(0), _unit_max_hp]
	_detail += note + " never by friendly fire]"
	# AC 11: the corpse's actor lifecycle.
	#
	# INVERTED BY STORY 4-3d (AC 2/3), AND THE OLD INSTRUMENT WAS INVALIDATED RATHER THAN
	# WEAKENED -- the same correction 4-3b made to AC 6's instrument directly above, for the same
	# kind of reason. This read "the actor is gone and its array slot is a HOLE" three frames
	# after the kill, which was correct when it was written because `_free_dead_unit_actors` freed
	# a dead unit's actor on the tick death was observed. 4-3d changed that seat: the corpse now
	# LINGERS for 600 ticks and is freed at the end of it. Asserting it is gone at +3 frames now
	# asserts the DEFECT.
	#
	# WHAT THIS FILE STILL OWNS is that the kill reached the actor layer at all: the corpse must
	# be a LINGERING corpse -- still in the tree, still at its own index, and TOLD IT DIED (its
	# linger has begun) -- rather than an untouched live actor. The 600-tick expiry and the hole
	# that follows it belong to test_unit_corpse_linger_live.gd, which counts them; duplicating
	# that here would make this file wait 10 seconds for a claim it is not about.
	var corpse := _unit_actor(1, 0)
	_enemy_corpse_lingering = corpse != null and corpse.is_lingering()
	if corpse == null:
		_detail += " enemy_actor_already_freed(4-3d's linger is not in effect);"
	elif not corpse.is_lingering():
		_detail += " enemy_actor_present_but_linger_never_started;"
	var enemy_actors: Array = _runner._unit_actors[1]
	_enemy_still_at_same_index = enemy_actors.size() == 1 and enemy_actors[0] == corpse
	if not _enemy_still_at_same_index:
		_detail += " corpse_not_at_index_0(actors=%d);" % enemy_actors.size()
	_friendly_actor_alive = _unit_actor(0, 0) != null
	if not _friendly_actor_alive:
		_detail += " friendly_actor_also_gone(scene_torn_down?);"
	# AC 5, live: no MELEE GRANT ever fired while a minion was being killed. The discriminator is the
	# largest single-tick mana increase across the whole kill: the passive faucet contributes
	# `mana_regen_per_second / 60` per tick, the melee grant a whole `melee_hit_mana` at once, and
	# half the grant separates them with enormous margin at any sane authoring.
	_mana_after_kill = _state.p1.mana.get_current()
	var melee_grant := _state.balance.melee_hit_mana
	var headroom := _mana_after_kill < _state.p1.mana.get_maximum()
	var no_melee_mana := melee_grant > 0.0 and _max_mana_jump < melee_grant * 0.5
	if not headroom:
		_detail += " pool_capped(no headroom -- AC 5's live check would be vacuous);"
	if not no_melee_mana:
		_detail += " melee_grant_fired(max_jump=%.4f grant=%.3f);" % [_max_mana_jump, melee_grant]
	no_melee_mana = no_melee_mana and headroom

	var ok := _p1_slot_chosen and _p2_slot_chosen and _spawned and _enemy_started_alive \
			and _enemy_ever_in_reach and _friendly_ever_in_reach \
			and _enemy_died and _friendly_untouched \
			and _enemy_corpse_lingering and _enemy_still_at_same_index and _friendly_actor_alive \
			and no_melee_mana
	print("unit_combat_live: swings=%d enemy_started_alive=%s enemy_in_reach=%s friendly_in_reach=%s "
			% [_swings, _enemy_started_alive, _enemy_ever_in_reach, _friendly_ever_in_reach]
			+ "enemy_died=%s friendly_untouched=%s(hp=%.2f) corpse_lingering=%s at_index=%s friendly_actor=%s "
			% [_enemy_died, _friendly_untouched, _state.p1.units.hp_at(0), _enemy_corpse_lingering,
				_enemy_still_at_same_index, _friendly_actor_alive]
			+ "mana=%.3f max_jump=%.4f%s" % [_mana_after_kill, _max_mana_jump, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


## The live actor for `[slot, index]`, read out of the runner's per-slot array and validated -- so a
## `null` HOLE and a freed instance both read as "no actor", which is exactly what AC 11 asserts.
func _unit_actor(slot: int, index: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[slot]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The first dealt slot whose authored card carries a `summon_*` effect -- test_unit_approach_live
## .gd's chooser, parameterised by player so both slots can cast.
func _choose_summon_slot(player: PlayerState, prefix: String) -> bool:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return false
	var hand := player.hand.to_array()
	for index in hand.size():
		if player.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if String(card.basic_effect.effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			var action := StringName("%s_card_%d" % [prefix, index + 1])
			if not InputMap.has_action(action):
				return false
			if prefix == "p1":
				_p1_action = action
			else:
				_p2_action = action
			return true
	return false
