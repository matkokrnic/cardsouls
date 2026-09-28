extends SceneTree

## Review fix N2 (story 6-5c, AC 5 / `6-5c/R3` / `6-5c/R7`): AN INTERRUPT ON THE EXACT STRIKE TICK TAKES
## THE BOLT PROP WITH IT.
##
## THE DEFECT THIS PINS. The runner ticks the prop once per push, so on the tick a cast would have
## struck the prop is already ARRIVED by the time the runner reads the falling edge. Freeing only a bolt
## that `not has_arrived()` therefore let an interrupted cast's bolt crash onto the target and live for
## one more push -- a visible landing with no damage, no stun, no root and no `hit_landed`, because the
## state layer struck nothing. The exact case is `6-5c/R7`'s: an unanswered unblockable's knockdown
## landing on the caster at step 6b of the strike tick.
##
## HOW THE STRIKE TICK IS FOUND, ordering-free. `cast_window.remaining_ticks() == 1` means THE NEXT
## `advance()` IS THE STRIKE TICK, whichever side of the runner's own `_physics_process` this poll sits on
## (before the advance: it is the one about to run; after: it is the next frame's). The stun is written
## the first time that is observed, so it is in force at step 3 of the strike tick either way.
##
## THE CAST IS POKED (`test_cast_presentation_live.gd`'s precedent): the arm is the public one the press
## seat calls, and what is measured is the runner's push, not how the window got armed.
##
## Run: godot --headless --path . --script res://test/integration/test_cast_interrupt_live.gd

const EFFECT_PATH := "res://data/effects/honed_bolt.tres"
const PLACE_FRAME := 3
const CAST_FRAME := 6
const GAP := 3.0
## Frames watched after the interrupt, so a bolt freed late is still caught.
const TAIL_FRAMES := 12

var _frames := 0
var _runner: Node = null
var _state: MatchState = null
var _failures: Array[String] = []
var _cast_ticks := 0
var _poked_frame := -1
var _bolt_seen_in_flight := false
var _hits := 0
var _bolt_after_cast_ended := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		_state.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: _hits += 1)
		return false
	if _frames == 2:
		if _state.flags == null or not _state.flags.spells:
			return _fail("the authored FeatureFlags has spells OFF -- no cast can start")
		var effect: CardEffect = load(EFFECT_PATH)
		if effect == null or effect.cast_seconds <= 0.0:
			return _fail("%s authors no positive cast_seconds" % EFFECT_PATH)
		_cast_ticks = TimingWindow.seconds_to_ticks(effect.cast_seconds)
		return false
	if _frames == PLACE_FRAME:
		_p1_hero().global_position = Vector3(-GAP, 1.0, 0.0)
		_p2_hero().global_position = Vector3(GAP, 1.0, 0.0)
		return false
	if _frames == CAST_FRAME:
		# Story 6-5d (AC 24/AC 28): `start_cast` now also captures the MODE and the TARGET. The poke passes
		# BASIC (Honed Bolt is a Mode 1 cast) and the OPPOSING HERO -- which is what an unlocked or
		# hero-locked caster captures (`6-5d/R7`), i.e. exactly the target this test always assumed. The
		# damage is 0.0: a bolt's damage is authored on its effect, not frozen at a staging.
		_state.p1.start_cast(&"honed_bolt", _cast_ticks, Enums.ModeKind.BASIC,
				1, TargetingService.HERO_INDEX, 0.0)
		return false
	if _frames > CAST_FRAME:
		_sample()
	if _poked_frame > 0 and _frames >= _poked_frame + TAIL_FRAMES:
		return _finish()
	if _frames > CAST_FRAME + _cast_ticks + 60:
		return _fail("the strike tick was never reached (poked frame %d)" % _poked_frame)
	return false


func _sample() -> void:
	var bolt := _bolt(0)
	if _state.p1.is_casting():
		if bolt != null and not bolt.has_arrived():
			_bolt_seen_in_flight = true
		if _poked_frame < 0 and _state.p1.cast_window.remaining_ticks() == 1:
			# The next advance is the strike tick: stun the caster so step 3 reads it STUNNED.
			_state.p1.hero.start_stun(24, false)
			_state.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
			_poked_frame = _frames
	elif _poked_frame > 0 and bolt != null:
		# The state layer has ended the cast and struck nothing, so no bolt may still be standing.
		_bolt_after_cast_ended += 1


func _finish() -> bool:
	_check(_bolt_seen_in_flight, "non-vacuity: the bolt was never seen in flight before the interrupt")
	_check(not _state.p1.is_casting(), "the interrupt ended the cast")
	_check(_hits == 0, "nothing struck, so no hit_landed may arrive (got %d)" % _hits)
	_check(_state.p2.hero.get_hp() == _state.p2.hero.get_max_hp(), "...and the target took no damage")
	_check(_bolt_after_cast_ended == 0,
		"N2: the interrupted cast's bolt was still standing on %d sample(s) after the cast ended -- "
		% _bolt_after_cast_ended + "an arrived bolt must not land visibly when nothing struck")
	print("cast_interrupt_live: poked_frame=%d in_flight=%s hits=%d bolt_after_end=%d"
			% [_poked_frame, _bolt_seen_in_flight, _hits, _bolt_after_cast_ended])
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


func _p1_hero() -> HeroActor:
	return _runner._p1_hero as HeroActor


func _p2_hero() -> HeroActor:
	return _runner._p2_hero as HeroActor


func _bolt(slot: int) -> BoltActor:
	var node: Node = _runner._bolts[slot]
	return node as BoltActor if is_instance_valid(node) else null
