extends SceneTree

## Story 7-5b (AC 23, PROC/R8 -- GEOMETRY AND FACTS ONLY, never text fit): the Deck 2 bodies' placeholder
## presentation in the real `main.tscn`, both seats on Deck 2.
##
##   ROWS        each of the three effects (`healer`, `elemental_fury`, `wrath_of_god`) has its own presentation row.
##   TINT        an Elemental Fury shot's drawn core is the vocabulary colour of ITS colour fact
##               (`ProjectileBoard.color_at`), for red, blue and green, and the three differ.
##   STONE       a Healer shot is dressed (its default mesh hidden) with no Fury core, and it does NOT flash its
##               Healer the Corpse Bomb glow (the skull's source look is that row's alone).
##   MARKERS     a green landing pops `+GREEN` over its caster; a blue landing shows `SLOW` over the target; a heal
##               tick pops `+HEAL` over the owner; a Wrath stun (a stun that starts with a knockback) shows `STUN`,
##               an ordinary stun does not.
##   HEAL LOOK   (smoke fix 1, S5) the same heal tick draws ONE new thread whose ends are at the Healer and at its
##               owner, flashes a light at the Healer's hands, bursts particles at the owner and lays a rim flash
##               (a material overlay) on the owner's body.
##   RING        while a pulse cast is in its windup, the caster wears a ground ring whose drawn OUTER RADIUS equals
##               the state's `cast_radius`, following it if it changes; the ring is gone when the cast ends; an
##               unbroken windup shows the pulse (the Boom sound is played), a stunned one does not.
##   NO WRITES   the presentation reads and draws only: a snapshot taken before and after running its seats is
##               identical.
## SMOKE FIX 2 (S13, the Wrath of Gold look), geometry and facts:
##   WINDUP      the caster wears a golden COLUMN (centred on it) and a HAND LIGHT, and between an early and a late
##               windup tick the column grows taller, the hand light larger and the ring brighter (its alpha).
##   WAVE        the unbroken pulse draws a SHOCKWAVE centred on the caster that starts SMALLER than the frozen radius
##               and, once its `wave_seconds` have passed, is drawn AT that radius (the state's); the pulse shakes
##               BOTH viewports and plays the row's boom and chime. The stunned windup draws no wave, no shake.
##   HITS        a pulse with the opposing hero and one opposing totem inside the ring and a second totem outside it:
##               an impact flash on the hero and the inner totem, and none on the outer totem, on the caster or on
##               the caster's own Healer.
## The icon audit (`test_card_face.gd`) covers the three icons; it is not repeated here.
##
## Run: godot --headless --path . --script res://test/integration/test_deck_2_bodies_presentation_live.gd

const FURY_COLORS: Array[int] = [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]
## The presenter's node names and the markers' tokens, RESTATED: a static reference to `EffectPresenter` or
## `BuffMarkers` from this file keeps that script alive past `quit()`, and the engine reports a resource in use
## at exit (measured here; `test_unit_strike_alignment_live.gd` records the same finding).
const DRESS_NODE := "EffectDress"
const FURY_CORE_NODE := "FuryCore"
const RING_NODE := "PulseRing"
const GREEN_POP := "+GREEN"
const HEAL_POP := "+HEAL"
const SLOW_MARK := "SLOW"
const STUN_MARK := "STUN"
const COLUMN_NODE := "WrathColumn"
const GLOW_NODE := "WrathHandGlow"
const WAVE_NODE := "WrathWave"
const HIT_NODE := "WrathHit"
const RING_RADIUS := 5.5
const RING_RADIUS_MOVED := 7.0
const WINDUP_TICKS := 40
## S13: the early and late windup ticks the gathering is compared at.
const EARLY_TICK := 3
const LATE_TICK := 30
## HITS: where the opposing hero and the two totems stand from the caster (m), and the hits phase's ring.
const HIT_HERO_OFFSET := Vector3(2.0, 0.0, 0.0)
const HIT_INNER_OFFSET := Vector3(0.0, 0.0, -3.0)
const HIT_OUTER_OFFSET := Vector3(0.0, 0.0, 9.0)

var _frames := 0
var _runner: Node
var _state: MatchState
var _healer_index := -1
var _fury_shots: Array[int] = []
var _healer_shot := -1
var _seen_green := false
var _seen_slow := false
var _seen_heal := false
var _phase := 0
var _phase_frame := 0
var _booms_before := 0
var _chimes_before := 0
var _threads_before := 0
var _early := []
var _pulse_frame := -1
var _wave_ticks := 0
var _inner := -1
var _outer := -1
var _stopping := -1
var _failures: Array[String] = []


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var deck_2 := load("res://data/decks/deck_2.tres") as DeckList
	var seats: Array[DeckList] = [deck_2, deck_2]
	main.seat_deck_list_overrides = seats
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _stopping >= 0:
		_stopping += 1
		if _stopping >= 3:
			_finish()
		return false
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _state == null or _runner._effects == null:
			return _end("missing runner, state or presenter")
		for id: StringName in [&"healer", &"elemental_fury", &"wrath_of_god"]:
			var r: EffectPresentationRow = _runner._effects.row_for_effect(id)
			_check(r != null and r.row_id == id, "effect '%s' has no presentation row of its own" % id)
		var kind_index: int = _state.balance.kind_index_of(&"healer")
		_state.p1.units.add(_state.balance.kind_at(kind_index).max_hp, kind_index)
		_healer_index = _state.p1.units.size() - 1
		return false
	match _phase:
		0:
			if _healer() != null:
				# Three Fury shots and one Healer shot at P2's hero, put straight on P1's board.
				for color: int in FURY_COLORS:
					_state.p1.projectiles.add_hero_shot(1, TargetingService.HERO_INDEX, &"elemental_fury", 0.0, color)
					_fury_shots.append(_state.p1.projectiles.size() - 1)
				_state.p1.projectiles.add_minion_shot(1, TargetingService.HERO_INDEX, &"healer", 3.0, _healer_index)
				_healer_shot = _state.p1.projectiles.size() - 1
				_next_phase()
			elif _frames > 10:
				return _end("the Healer's actor never spawned")
		1:
			if _phase_frame == 1:
				_check_dresses()
			_seen_green = _seen_green or Array(_runner._p1_hero.buff_markers.pop_texts()).has(GREEN_POP)
			_seen_slow = _seen_slow or _runner._p2_hero.buff_markers.conditions_text().contains(SLOW_MARK)
			if _seen_green and _seen_slow:
				_next_phase()
			elif _phase_frame > 300:
				return _end("the Fury shots' markers never showed: +GREEN %s, SLOW %s" % [_seen_green, _seen_slow])
		2:
			if _phase_frame == 1:
				_threads_before = _threads().size()
				_state.p1.units.close_heal_tick_at(_healer_index, true)
			if _phase_frame == 3:
				_check_heal_look()
			_seen_heal = _seen_heal or Array(_runner._p1_hero.buff_markers.pop_texts()).has(HEAL_POP)
			if _phase_frame == 4:
				_check(_seen_heal, "a heal tick on P1's Healer popped no +HEAL over P1")
				# The Wrath stun on P2 (a stun that starts with a knockback); an ordinary one on P1.
				_state.p2.hero.start_stun(30, false)
				_state.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
				_state.p2.start_knockback(20, Vector2.RIGHT, 0.0)
				_state.p1.hero.start_stun(30, false)
				_state.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
			if _phase_frame == 7:
				_check(_runner._p2_hero.buff_markers.conditions_text().contains(STUN_MARK),
						"P2's Wrath stun shows no STUN (conditions '%s')" % _runner._p2_hero.buff_markers.conditions_text())
				_check(not _runner._p1_hero.buff_markers.conditions_text().contains(STUN_MARK),
						"P1's ordinary stun shows STUN")
			if _phase_frame > 40 and _state.p1.hero.action_state != HeroState.ActionState.STUNNED:
				_next_phase()
		3:
			if _phase_frame == 1:
				_check_no_writes()
				_booms_before = _boom_count()
				_chimes_before = _chime_count()
				_wave_ticks = int(ceil(_runner._effects.row(&"wrath_of_god").knob(&"wave_seconds", -1.0)
						* TimingWindow.TICK_HZ))
				_check(_wave_ticks > 0, "the `wrath_of_god` row authors no `wave_seconds`")
				_state.p1.start_cast(&"manapulation", WINDUP_TICKS, Enums.ModeKind.PITCH, 1,
						TargetingService.HERO_INDEX, 0.0, RING_RADIUS)
			if _phase_frame == 3:
				_check_ring(RING_RADIUS)
				_state.p1.cast_radius = RING_RADIUS_MOVED
			if _phase_frame == 5:
				_check_ring(RING_RADIUS_MOVED)
			if _phase_frame == EARLY_TICK:
				_early = _gathering()
			if _phase_frame == LATE_TICK:
				_check_gathered(_early, _gathering())
			if _pulse_frame < 0 and _phase_frame > 5 and not _state.p1.is_casting():
				_pulse_frame = _phase_frame
				_check(_runner._effects.pulse_ring_radius(0) == 0.0, "the ring outlived the windup")
				_check(_runner._p1_hero.get_node_or_null(NodePath(RING_NODE)) == null,
						"the ring node outlived the windup")
				_check(_runner._p1_hero.get_node_or_null(NodePath(COLUMN_NODE)) == null,
						"the column outlived the windup")
				_check(_boom_count() == _booms_before + 1, "an unbroken windup showed no pulse (no boom)")
				_check(_chime_count() == _chimes_before + 1, "an unbroken windup rang no chime")
				_check(_runner._shake_elapsed[0] >= 0 and _runner._shake_elapsed[1] >= 0,
						"the pulse did not shake both viewports (%d, %d)" % [_runner._shake_elapsed[0], _runner._shake_elapsed[1]])
				_check_wave(false)
			elif _pulse_frame > 0 and _phase_frame == _pulse_frame + _wave_ticks + 3:
				_check_wave(true)
				_next_phase()
			elif _pulse_frame < 0 and _phase_frame > WINDUP_TICKS + 20:
				return _end("the Wrath windup never ended")
		4:
			# The last pulse's wave fades first, so a wave seen below can only be this windup's.
			if _phase_frame == 1 and _runner._effects.get_node_or_null(NodePath(WAVE_NODE)) != null:
				_phase_frame -= 1
			elif _phase_frame == 1:
				_booms_before = _boom_count()
				_state.p1.start_cast(&"manapulation", WINDUP_TICKS, Enums.ModeKind.PITCH, 1,
						TargetingService.HERO_INDEX, 0.0, RING_RADIUS)
			if _phase_frame == 5:
				_state.p1.hero.start_stun(30, false)
				_state.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
				_runner._shake_elapsed[0] = -1
				_runner._shake_elapsed[1] = -1
			if _phase_frame > 5 and not _state.p1.is_casting():
				_check(_boom_count() == _booms_before, "a windup cut by a stun showed the pulse")
				_check(_runner._effects.get_node_or_null(NodePath(WAVE_NODE)) == null, "a windup cut by a stun drew a wave")
				_check(_runner._shake_elapsed[0] < 0 and _runner._shake_elapsed[1] < 0, "a windup cut by a stun shook a viewport")
				_next_phase()
			elif _phase_frame > WINDUP_TICKS + 20:
				return _end("the stunned windup never ended")
		5:
			if _phase_frame == 1:
				if _state.p1.hero.action_state == HeroState.ActionState.STUNNED:
					_phase_frame -= 1
				else:
					_start_hits_windup()
			if _phase_frame > 1 and _phase_frame < WINDUP_TICKS:
				_hold_hits_bodies()
			if _phase_frame > 5 and not _state.p1.is_casting():
				_check_hits()
				return _end("")
			elif _phase_frame > WINDUP_TICKS + 40:
				return _end("the hits windup never ended")
	_phase_frame += 1
	return false


func _next_phase() -> void:
	_phase += 1
	_phase_frame = 0


func _check_dresses() -> void:
	var actors: Array = _runner._projectile_actors[0]
	var drawn: Array[Color] = []
	for i in FURY_COLORS.size():
		var shot := actors[_fury_shots[i]] as Node3D if _fury_shots[i] < actors.size() else null
		var core := shot.get_node_or_null("%s/%s" % [DRESS_NODE, FURY_CORE_NODE]) \
				as MeshInstance3D if shot != null else null
		_check(core != null, "Fury shot %d (colour %d) has no core" % [i, FURY_COLORS[i]])
		if core == null:
			continue
		var color := (core.material_override as StandardMaterial3D).albedo_color
		var profile: TelegraphProfile = _runner._effects._vocabulary.get(FURY_COLORS[i])
		_check(profile != null and color.is_equal_approx(profile.color),
				"Fury shot %d draws %s, its colour fact's vocabulary colour is %s" % [i, color, profile.color if profile else "missing"])
		drawn.append(color)
	_check(drawn.size() == 3 and not drawn[0].is_equal_approx(drawn[1]) and not drawn[1].is_equal_approx(drawn[2]) \
			and not drawn[0].is_equal_approx(drawn[2]), "the three Fury shots are not three colours: %s" % [drawn])
	var stone := actors[_healer_shot] as Node3D if _healer_shot < actors.size() else null
	_check(stone != null and stone.get_node_or_null(NodePath(DRESS_NODE)) != null,
			"the Healer shot is not dressed")
	if stone != null:
		_check(stone.get_node_or_null("%s/%s" % [DRESS_NODE, FURY_CORE_NODE]) == null,
				"the Healer shot wears a Fury core")
		var mesh := stone.get_node_or_null("Mesh") as Node3D
		_check(mesh == null or not mesh.visible, "the Healer shot still shows its default mesh")
	var healer := _healer()
	if healer != null:
		for node in healer.find_children("*", "MeshInstance3D", true, false):
			_check((node as MeshInstance3D).material_overlay == null,
					"the Healer's mesh %s flashed the Corpse Bomb glow when it shot" % node.name)


## S5: the heal look, a couple of frames after the heal tick -- inside the thread's ~0.3 s.
func _check_heal_look() -> void:
	var healer := _healer()
	var owner: Node3D = _runner._p1_hero
	var threads := _threads()
	_check(threads.size() == _threads_before + 1,
			"the heal drew %d new thread(s), want 1" % (threads.size() - _threads_before))
	if healer == null or threads.size() <= _threads_before:
		return
	var bounds := (threads[threads.size() - 1] as MeshInstance3D).get_aabb()
	for end: Node3D in [healer, owner]:
		var at := end.global_position
		_check(at.x > bounds.position.x - 0.5 and at.x < bounds.end.x + 0.5 and at.z > bounds.position.z - 0.5 \
				and at.z < bounds.end.z + 0.5, "the heal thread %s does not reach %s at %s" % [bounds, end.name, at])
	var lit := false
	var sparkled := false
	for node: Node in _runner._effects.get_children():
		if node is OmniLight3D and _planar((node as Node3D).global_position - healer.global_position) < 1.0:
			lit = true
		if node is GPUParticles3D and _planar((node as Node3D).global_position - owner.global_position) < 0.5:
			sparkled = true
	_check(lit, "no flash light at the Healer's hands")
	_check(sparkled, "no particles rising at the owner")
	var flashed := false
	for node in owner.get_node("Mesh").find_children("*", "MeshInstance3D", true, false):
		flashed = flashed or (node as MeshInstance3D).material_overlay != null
	_check(flashed, "no rim flash on the owner's body")


## The presenter's thread meshes (Drain's and the Healer's: an `ImmediateMesh` on a direct child).
func _threads() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in _runner._effects.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is ImmediateMesh:
			out.append(node)
	return out


func _planar(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _check_ring(radius: float) -> void:
	var ring := _runner._p1_hero.get_node_or_null(NodePath(RING_NODE)) as MeshInstance3D
	_check(ring != null, "no ground ring under the casting hero (want radius %.2f)" % radius)
	if ring == null:
		return
	var torus := ring.mesh as TorusMesh
	_check(torus != null and is_equal_approx(torus.outer_radius, _state.p1.cast_radius),
			"the ring's drawn radius %.3f is not the state's %.3f" % [torus.outer_radius if torus else -1.0, _state.p1.cast_radius])
	_check(is_equal_approx(_runner._effects.pulse_ring_radius(0), radius), "the presenter reports a %.3f m ring, want %.3f"
			% [_runner._effects.pulse_ring_radius(0), radius])
	_check(ring.global_position.y < 0.2, "the ring is %.3f m above the ground" % ring.global_position.y)
	var caster: Node3D = _runner._p1_hero
	_check(Vector2(ring.global_position.x - caster.global_position.x, ring.global_position.z - caster.global_position.z).length() < 0.01,
			"the ring is not centred on the caster")


## Run every Deck 2 presentation seat once more, between ticks, and every look by hand: the snapshot must not move.
func _check_no_writes() -> void:
	var before := var_to_str(_state.to_snapshot()).sha256_text()
	_runner._push_deck_2_presentation()
	_runner._push_effect_presentation()
	_runner._effects.set_pulse_ring(0, _runner._p1_hero, 3.0)
	_runner._effects.show_pulse(_runner._p1_hero.global_position, 3.0)
	_runner._effects.set_pulse_ring(0, _runner._p1_hero, 0.0)
	_runner._p1_hero.buff_markers.pop(HEAL_POP)
	_runner._p1_hero.buff_markers.show_conditions(true, true)
	_check(var_to_str(_state.to_snapshot()).sha256_text() == before, "running the presentation moved the state snapshot")


func _boom_count() -> int:
	return _runner._effects.played.count(&"wrath_of_god/pulse_boom")


func _chime_count() -> int:
	return _runner._effects.played.count(&"wrath_of_god/pulse_chime")


## S13: [column height, hand-light size, ring alpha] now -- each must grow over the windup.
func _gathering() -> Array:
	var column := _runner._p1_hero.get_node_or_null(NodePath(COLUMN_NODE)) as MeshInstance3D
	var ring := _runner._p1_hero.get_node_or_null(NodePath(RING_NODE)) as MeshInstance3D
	_check(column != null, "no golden column on the casting hero")
	_check(_runner._p1_hero.get_node_or_null(NodePath(GLOW_NODE)) != null, "no light gathering at the caster's hands")
	if column != null:
		var caster: Node3D = _runner._p1_hero
		_check(_planar(column.global_position - caster.global_position) < 0.01, "the column is not centred on the caster")
	return [(column.mesh as CylinderMesh).height if column != null else -1.0, _runner._effects.wrath_glow_size(0),
			(ring.material_override as StandardMaterial3D).albedo_color.a if ring != null else -1.0]


func _check_gathered(early: Array, late: Array) -> void:
	_check(early.size() == 3 and late.size() == 3, "the windup was not sampled")
	if early.size() != 3 or late.size() != 3:
		return
	_check(late[0] > early[0], "the column did not grow (%.3f -> %.3f)" % [early[0], late[0]])
	_check(late[1] > early[1], "the hand light did not grow (%.3f -> %.3f)" % [early[1], late[1]])
	_check(late[2] > early[2], "the ring did not brighten (alpha %.3f -> %.3f)" % [early[2], late[2]])


## S13: the shockwave, centred on the caster; `done` = its `wave_seconds` have passed, so it is AT the frozen radius.
func _check_wave(done: bool) -> void:
	var wave := _runner._effects.get_node_or_null(NodePath(WAVE_NODE)) as Node3D
	_check(wave != null, "the unbroken pulse drew no shockwave")
	if wave == null:
		return
	var caster: Node3D = _runner._p1_hero
	_check(_planar(wave.global_position - caster.global_position) < 0.01, "the shockwave is not centred on the caster")
	var drawn: float = _runner._effects.pulse_wave_radius()
	var rim := (wave.get_node("Rim") as MeshInstance3D).mesh as TorusMesh
	_check(is_equal_approx(rim.outer_radius, drawn), "the wave's rim (%.3f) is not its reported radius (%.3f)"
			% [rim.outer_radius, drawn])
	if done:
		_check(is_equal_approx(drawn, RING_RADIUS_MOVED),
				"%d ticks after the pulse the wave is drawn at %.3f m, the frozen radius is %.3f m"
						% [_wave_ticks + 3, drawn, RING_RADIUS_MOVED])
	else:
		_check(drawn < RING_RADIUS_MOVED * 0.5, "on the pulse tick the wave is already %.3f m -- it does not expand" % drawn)


## HITS: a recorded Wrath on P1 (so its pulse writes its parts), P2's hero inside the ring, one P2 totem inside and
## one outside, P1's own Healer beside the caster.
func _start_hits_windup() -> void:
	var accelerator: int = _state.balance.kind_index_of(&"mana_accelerator")
	_check(accelerator >= 0, "the authored balance has no mana accelerator kind")
	_state.p2.units.add(_state.balance.kind_at(accelerator).max_hp, accelerator)
	_inner = _state.p2.units.size() - 1
	_state.p2.units.add(_state.balance.kind_at(accelerator).max_hp, accelerator)
	_outer = _state.p2.units.size() - 1
	_state.p1.record_reversal(PlayerState.REVERSAL_WRATH_OF_GOD, [] as Array[int], [] as Array[int],
			[] as Array[int], [] as Array[bool], 0.0)
	_state.p1.start_cast(&"manapulation", WINDUP_TICKS, Enums.ModeKind.PITCH, 1, TargetingService.HERO_INDEX, 0.0,
			RING_RADIUS)


## Keep every body where the HITS case needs it while the windup runs (a body may walk; the totems never do).
func _hold_hits_bodies() -> void:
	var caster: Node3D = _runner._p1_hero
	var at := caster.global_position
	(_runner._p2_hero as Node3D).global_position = Vector3(at.x + HIT_HERO_OFFSET.x,
			(_runner._p2_hero as Node3D).global_position.y, at.z + HIT_HERO_OFFSET.z)
	for pair: Array in [[_inner, HIT_INNER_OFFSET], [_outer, HIT_OUTER_OFFSET]]:
		var actors: Array = _runner._unit_actors[1]
		if int(pair[0]) >= 0 and int(pair[0]) < actors.size() and is_instance_valid(actors[int(pair[0])]):
			var offset: Vector3 = pair[1]
			(actors[int(pair[0])] as Node3D).global_position = Vector3(at.x + offset.x, 0.0, at.z + offset.z)


func _check_hits() -> void:
	var actors: Array = _runner._unit_actors[1]
	var inner := actors[_inner] as Node3D if _inner >= 0 and _inner < actors.size() else null
	var outer := actors[_outer] as Node3D if _outer >= 0 and _outer < actors.size() else null
	_check(_state.p2.units.hp_at(_inner) < _state.balance.kind_at(_state.p2.units.kind_index_at(_inner)).max_hp,
			"sanity: the inner totem took no pulse damage (the case was not exercised)")
	_check(_runner._p2_hero.get_node_or_null(NodePath(HIT_NODE)) != null, "the opposing hero inside the ring has no impact flash")
	_check(inner != null and inner.get_node_or_null(NodePath(HIT_NODE)) != null, "the totem inside the ring has no impact flash")
	_check(outer != null and outer.get_node_or_null(NodePath(HIT_NODE)) == null, "the totem outside the ring flashed")
	_check(_runner._p1_hero.get_node_or_null(NodePath(HIT_NODE)) == null, "the caster flashed")
	var healer := _healer()
	_check(healer == null or healer.get_node_or_null(NodePath(HIT_NODE)) == null, "the caster's own Healer flashed")


func _healer() -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if _healer_index < 0 or _healer_index >= actors.size() or not is_instance_valid(actors[_healer_index]):
		return null
	return actors[_healer_index] as UnitActor


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Stop every effect sound, then free the scene a few frames later: a sound still playing when the nodes go is
## stopped too late for the audio cleanup, and the engine reports resources in use at exit (`stop_all_sounds`).
func _end(message: String) -> bool:
	if message != "":
		_failures.append(message)
	if _runner != null and _runner._effects != null:
		_runner._effects.stop_all_sounds()
	# Smoke fix 2: the HITS pulse lands on P2 right before the end, so the hit CUE (the telegraph's, not the
	# presenter's) is still playing -- measured leaking `cue_hit.wav` at exit. Every player is stopped, the strike
	# test's own remedy.
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for node in root.find_children("*", type, true, false):
			node.call(&"stop")
	_stopping = 0
	return false


func _finish() -> void:
	for f in _failures:
		print("  FAILED: " + f)
	var ok := _failures.is_empty()
	print("deck_2_bodies_presentation_live: frames=%d phase=%d green=%s slow=%s heal=%s"
			% [_frames, _phase, _seen_green, _seen_slow, _seen_heal])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	quit(0 if ok else 1)
