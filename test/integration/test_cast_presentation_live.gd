extends SceneTree

## Story 6-5c (AC 25, AC 26, AC 28): THE CAST PRESENTATION, IN THE LIVE SCENE.
##
## WHAT THIS FILE OWNS, and it is precisely the half `test/state/test_hero_cast.gd` cannot reach.
## That file proves the cast WINDOW -- the press seat, the strike tick, the commitment locks, the
## stun and the root -- with no scene at all. Everything below needs a running scene:
##   * AC 25: THE ARRIVAL PIN. The bolt is a distinct node that TRAVELS and must LAND ON THE STATE'S
##     STRIKE TICK. Headlessly there is no prop and "arrives with the strike" is unfalsifiable.
##   * AC 25: the caster plays the `cast` pose for the window, from the measured sub-range.
##   * AC 26: the TARGET -- not the caster -- shows a warning marker AND plays a warning sound for
##     the whole cast, and both end at the strike.
##   * AC 28: the root marker is up while the root is in force, down during the stun that precedes
##     it, and down when no root is running at all.
##
## THE ARRIVAL PIN IS ORDERING-FREE, and that is the one thing about this file worth reading twice.
## Comparing "the frame my poll saw the bolt land" with "the frame my poll saw the hit" would depend
## on whether `SceneTree._physics_process` runs before or after the runner's, and would be off by one
## either way. Instead the bolt is INSPECTED FROM INSIDE THE `hit_landed` CALLBACK: that signal is
## drained at the END of the runner's own tick (`match_runner` step 5), after the step-3a-quater push
## that advances the bolt -- so "the bolt has arrived at the instant the state layer's strike is
## announced" is a single-instant fact, and `_bolt_arrived_at_hit` is exactly AC 25's claim.
## Non-vacuity is asserted with it: the bolt must have been seen IN FLIGHT and NOT arrived on earlier
## ticks, and must have climbed into the sky, or "arrived" would be true for a prop that never moved.
##
## THE CAST IS POKED ONTO THE PLAYER, not pressed from a hand -- `test_cast_success_cue_live.gd`'s
## right-sized-poke precedent verbatim. `PlayerState.start_cast` is the same public arm the press
## seat calls, and the strike seat downstream is untouched by how the window got armed; driving a
## real press would make every assertion here depend on which card the shuffle dealt. THE DURATION
## IS THE AUTHORED ONE, read live from `data/effects/honed_bolt.tres`, so a `cast_seconds` retune
## re-times this test with it and AC 25's "no code edit" clause is proven rather than asserted.
##
## Run: godot --headless --path . --script res://test/integration/test_cast_presentation_live.gd

const EFFECT_PATH := "res://data/effects/honed_bolt.tres"
const BALANCE_PATH := "res://data/balance/balance_config.tres"
## Late enough that the runner has finished `_ready()` and the first physics frames have settled.
const PLACE_FRAME := 3
const CAST_FRAME := 6
## How far apart the two heroes stand, so the bolt has a real gap to cross.
const GAP := 3.0
## The bolt must climb well clear of the caster before it comes down -- half the prop's authored sky
## height, so the assertion survives a retune of `BoltActor.SKY_HEIGHT` in either direction.
const MIN_SKY_CLIMB := BoltActor.SKY_HEIGHT * 0.5

var _frames := 0
var _runner: Node = null
var _state: MatchState = null
var _failures: Array[String] = []

var _cast_ticks := 0
var _cast_seconds := 0.0
var _last_frame := 0

## AC 25 -- the arrival pin and its non-vacuity.
var _hit_seen := false
var _bolt_arrived_at_hit := false
var _bolt_present_at_hit := false
var _bolt_inflight_ticks := 0
var _bolt_peak_y := -1000.0
var _bolt_landing_gap := -1.0

## AC 25 -- the pose.
var _cast_pose_ticks := 0
var _cast_pose_wrong_clip := ""

## AC 26 -- the target-side warning.
var _warn_marker_ticks := 0
var _warn_sound_ticks := 0
var _cast_ticks_observed := 0
var _caster_warned := false
var _warning_left_up := false

## AC 28 -- the root marker.
var _root_marker_ticks := 0
var _stun_marker_violations := 0
var _root_marker_mismatch_run := 0
var _root_marker_mismatches := 0
var _marker_up_without_root := false


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
		_state.hit_landed.connect(_on_hit_landed)
		return false

	if _frames == 2:
		# NON-VACUITY, up front, the `test_projectile_flight_live.gd` idiom: a closed spells flag or
		# an unauthored cast duration would make every assertion below pass for the wrong reason.
		if _state.flags == null or not _state.flags.spells:
			return _fail("the authored FeatureFlags has spells OFF -- no cast can start")
		var effect: CardEffect = load(EFFECT_PATH)
		if effect == null or effect.cast_seconds <= 0.0:
			return _fail("%s authors no positive cast_seconds" % EFFECT_PATH)
		_cast_ticks = TimingWindow.seconds_to_ticks(effect.cast_seconds)
		_cast_seconds = float(_cast_ticks) / TimingWindow.TICK_HZ
		var balance: BalanceConfig = load(BALANCE_PATH)
		var ticks := BalanceTicks.from_config(balance)
		# Long enough for the cast, the stun and the whole root, plus a tail to watch it clear.
		_last_frame = CAST_FRAME + _cast_ticks \
				+ TimingWindow.seconds_to_ticks(effect.stun_seconds) \
				+ TimingWindow.seconds_to_ticks(effect.root_seconds) + 20
		if ticks == null:
			return _fail("the authored balance yielded no BalanceTicks")

		# AC 25, the SUB-RANGE arithmetic, pinned directly on the pure functions so a retune that
		# pushed the window off the end of the clip fails here rather than looking merely odd on
		# screen. At the authored 0.8 s the whole window fits inside the 2.9667 s clip and the
		# measured raise sits inside it.
		var start := AnimationController.cast_cut_start(_cast_seconds)
		var launch := AnimationController.cast_launch_seconds(_cast_seconds)
		_check(start >= 0.0 and start + _cast_seconds <= AnimationController.CAST_CLIP_SECONDS + 0.0001,
			"the cast sub-range [%.4f, %.4f] does not fit inside the %.4f s clip"
				% [start, start + _cast_seconds, AnimationController.CAST_CLIP_SECONDS])
		_check(absf((start + launch) - AnimationController.CAST_RAISE_SECONDS) < 0.0001,
			"the launch offset must land ON the measured raise frame %.4f, got %.4f"
				% [AnimationController.CAST_RAISE_SECONDS, start + launch])
		_check(launch > 0.0 and launch < _cast_seconds,
			"the bolt must leave the sword INSIDE the cast, got %.4f of %.4f" % [launch, _cast_seconds])

		# Baseline: nothing is showing before anything has been cast.
		_check(not _warning_visible(1) and not _warning_sounding(1),
			"a cast warning is already up on P2 before any cast")
		_check(not _root_marker_visible(0) and not _root_marker_visible(1),
			"a root marker is already up before any bolt (AC 28: never without a root)")
		_check(_bolt(0) == null, "a bolt prop exists before any cast")
		return false

	if _frames == PLACE_FRAME:
		_p1_hero().global_position = Vector3(-GAP, 1.0, 0.0)
		_p2_hero().global_position = Vector3(GAP, 1.0, 0.0)
		return false

	if _frames == CAST_FRAME:
		# THE POKE (see header). The same public arm the press seat calls, with the AUTHORED count.
		_state.p1.start_cast(&"honed_bolt", _cast_ticks)
		return false

	if _frames > CAST_FRAME:
		_sample()

	if _frames >= _last_frame:
		return _finish()
	return false


## One tick of observation. Everything here is a read: no state is written and no presentation call
## is made, so what is measured is what the runner's own push produced.
func _sample() -> void:
	var casting: bool = _state.p1.is_casting()
	if casting:
		_cast_ticks_observed += 1
		# AC 25: the caster holds the `cast` pose for the window. READ OFF `assigned_animation`, not
		# `current_animation`, for `_advance_counter`'s stated reason: the cut's end is a PAUSE (and
		# `AnimationPlayer` advances on the idle frame, not the physics tick, so headlessly the hold
		# is reached early), and a paused player reports an empty `current_animation` while
		# `assigned_animation` still names the clip whose frame is being held.
		var clip := String(_p1_hero().animation_controller.animation_player.assigned_animation)
		if clip == "cast":
			_cast_pose_ticks += 1
		elif _cast_pose_wrong_clip == "":
			_cast_pose_wrong_clip = clip
		# AC 26: the warning is on the TARGET, and only on the target.
		if _warning_visible(1):
			_warn_marker_ticks += 1
		if _warning_sounding(1):
			_warn_sound_ticks += 1
		if _warning_visible(0) or _warning_sounding(0):
			_caster_warned = true
	elif _cast_ticks_observed > 0 and (_warning_visible(1) or _warning_sounding(1)):
		# AC 26: both end at the strike tick. Sampled on every tick after it, so a cue left running
		# is caught however late it would have stopped.
		_warning_left_up = true

	var bolt := _bolt(0)
	if bolt != null:
		_bolt_peak_y = maxf(_bolt_peak_y, bolt.global_position.y)
		if not bolt.has_arrived():
			_bolt_inflight_ticks += 1

	# AC 28: the root marker follows the root, and the STUN that precedes it shows nothing.
	var rooted: bool = _state.p2.root_window.is_running
	var stunned: bool = _state.p2.hero.action_state == HeroState.ActionState.STUNNED
	var marker := _root_marker_visible(1)
	if marker:
		_root_marker_ticks += 1
		if not rooted:
			_marker_up_without_root = true
	if stunned and marker:
		_stun_marker_violations += 1
	# A ONE-TICK ALLOWANCE, and only one: this poll and the runner's push are both per-frame and
	# their order within the frame is the engine's business, so a single frame of lag on the level
	# read is expected. Two in a row is a marker that is genuinely out of step.
	var want := rooted and not stunned
	if want != marker:
		_root_marker_mismatch_run += 1
		if _root_marker_mismatch_run >= 2:
			_root_marker_mismatches += 1
	else:
		_root_marker_mismatch_run = 0


## AC 25's whole claim, measured at the ONE instant that makes it ordering-free (see header).
func _on_hit_landed(_attacker_slot: int, _target_slot: int, _damage: float, _target_hp: float) -> void:
	if _hit_seen:
		return
	_hit_seen = true
	var bolt := _bolt(0)
	_bolt_present_at_hit = bolt != null
	_bolt_arrived_at_hit = bolt != null and bolt.has_arrived()
	if bolt != null:
		_bolt_landing_gap = bolt.global_position.distance_to(_p2_hero().global_position)


func _finish() -> bool:
	# AC 25 -- the pin and its non-vacuity.
	_check(_hit_seen, "the poked cast never struck: no hit_landed arrived")
	_check(_bolt_present_at_hit, "no bolt prop existed when the strike was announced")
	_check(_bolt_arrived_at_hit,
		"AC 25: the bolt had NOT arrived on the state's strike tick (in-flight ticks seen: %d)"
			% _bolt_inflight_ticks)
	_check(_bolt_inflight_ticks >= 2,
		"the bolt was never observed in flight (%d ticks) -- an 'arrival' with no flight proves nothing"
			% _bolt_inflight_ticks)
	_check(_bolt_peak_y >= MIN_SKY_CLIMB,
		"AC 25: the bolt never climbed into the sky (peak y %.2f, wanted >= %.2f)"
			% [_bolt_peak_y, MIN_SKY_CLIMB])
	_check(_bolt_landing_gap >= 0.0 and _bolt_landing_gap < 1.0,
		"AC 25: the bolt did not land ON the target (gap %.3f m)" % _bolt_landing_gap)

	# AC 25 -- the pose, for the whole window.
	_check(_cast_ticks_observed > 0, "the cast was never observed running at all")
	_check(_cast_pose_ticks == _cast_ticks_observed,
		"AC 25: the caster played '%s' instead of 'cast' (%d of %d cast ticks on the pose)"
			% [_cast_pose_wrong_clip, _cast_pose_ticks, _cast_ticks_observed])

	# AC 26 -- the target-side warning, marker AND sound, for the whole cast and no longer.
	_check(_warn_marker_ticks == _cast_ticks_observed,
		"AC 26: the target's warning MARKER was up for %d of %d cast ticks"
			% [_warn_marker_ticks, _cast_ticks_observed])
	_check(_warn_sound_ticks == _cast_ticks_observed,
		"AC 26: the target's warning SOUND played for %d of %d cast ticks"
			% [_warn_sound_ticks, _cast_ticks_observed])
	_check(not _caster_warned, "AC 26: the CASTER showed its own warning -- the cue is target-anchored")
	_check(not _warning_left_up, "AC 26: the warning outlived the strike tick")

	# AC 28 -- the root marker.
	_check(_root_marker_ticks > 0, "AC 28: the root marker was never up, though a root ran")
	_check(_stun_marker_violations == 0,
		"AC 28: the root marker was up during the bolt STUN on %d ticks (the root is not in force yet)"
			% _stun_marker_violations)
	_check(not _marker_up_without_root, "AC 28: the root marker was up with no root running")
	_check(_root_marker_mismatches == 0,
		"AC 28: the root marker disagreed with the root state on %d ticks" % _root_marker_mismatches)
	_check(not _root_marker_visible(1),
		"AC 28: the root marker is still up after the root expired")

	print("cast_presentation_live: cast_ticks=%d observed=%d pose=%d warn_marker=%d warn_sound=%d "
			% [_cast_ticks, _cast_ticks_observed, _cast_pose_ticks, _warn_marker_ticks,
				_warn_sound_ticks]
			+ "bolt_inflight=%d peak_y=%.2f landing_gap=%.3f arrived_at_hit=%s root_marker=%d"
			% [_bolt_inflight_ticks, _bolt_peak_y, _bolt_landing_gap, _bolt_arrived_at_hit,
				_root_marker_ticks])
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


## Slot `slot`'s bolt prop, read off the runner's own array so the test and the runner agree about
## which node is which rather than searching the tree by type. Null once it has been freed.
func _bolt(slot: int) -> BoltActor:
	var node: Node = _runner._bolts[slot]
	return node as BoltActor if is_instance_valid(node) else null


func _telegraph(slot: int) -> TelegraphController:
	var hero: HeroActor = _p1_hero() if slot == 0 else _p2_hero()
	return hero.telegraph_controller


func _warning_visible(slot: int) -> bool:
	var mesh: MeshInstance3D = _telegraph(slot).get_node_or_null("CastWarning")
	return mesh != null and mesh.visible


func _warning_sounding(slot: int) -> bool:
	var cue: AudioStreamPlayer = _telegraph(slot).get_node_or_null("CueCastWarning")
	return cue != null and cue.playing


func _root_marker_visible(slot: int) -> bool:
	var mesh: MeshInstance3D = _telegraph(slot).get_node_or_null("RootMark")
	return mesh != null and mesh.visible
