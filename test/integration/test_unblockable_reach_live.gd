extends SceneTree

## Story 6-1c (AC 3/AC 4/AC 5/AC 9/AC 11): THE LIVE HALF -- mode (2)'s commit, launch and honest
## reach through the REAL runner: `_push_charge_reach_facts` measuring the per-colour radius KIND from
## real actor positions, `advance()` carrying the launch, `move_and_slide()` moving the real body, and
## `_push_charge_progress` driving the real AnimationPlayer across the launch.
##
## THE LAYOUT IS DERIVED FROM THE AUTHORED `.tres`, NEVER PINNED (the `test_contact_pipeline.gd`
## precedent): every distance below is computed from the live per-colour reach / launch distance
## (the arc retired at story 7-8, `7-8/R8`), so a feel retune reschedules this test instead of breaking it -- operator tuning never needs a
## suite edit (the story's Live Smoke note).
##
## STORY 6-1d REWRITES WHAT THE THREE CASES ASSERT, AND THAT REWRITE IS THE STORY. Through `6-1c` a
## defender anywhere inside the authored radius was hit, gap or no gap; the authored radius is now an
## UPPER BOUND on an honest blade-vs-body overlap (`6-1d` AC 1/AC 2), so ALL THREE layouts below --
## every one of which leaves visible daylight between the models -- are MISSES with a latched OUTSIDE.
## The positive half, a blade that actually touches, has its own file
## (`test_honest_hit_geometry_live.gd`): this one keeps the LAUNCH, PLAYHEAD and upper-bound claims.
##
## THREE CASES PER COLOUR, each a full chargeup -> commit -> launch -> landing:
##   far  -- the defender stands dead ahead at (travel + reach + MARGIN): after the launch it is just
##           OUTSIDE the colour's radius. MISS, the runner's latched kind is OUTSIDE, and the attacker
##           travelled the colour's authored distance along the frozen line (AC 4, fixed not adaptive
##           -- and, since `6-1d` AC 7, redistributed across the launch without changing that total).
##   near -- the same, at (travel + reach - MARGIN): just INSIDE the authored radius after the launch,
##           and metres from the blade. A HIT here through `6-1c`; a MISS since `6-1d` AC 1. This is
##           the exact layout the operator saw land across a gap at `6-1c`'s smoke.
##   side -- RETIRED BY STORY 7-9 (`7-9/R3`, M15, D7). It teleported the defender 90 degrees off the line
##           at the commit and asserted a WHIFF for every colour, because the launch flew along the frozen
##           commit line. The attack now STEERS after the commit, so the claim itself is superseded; GREEN
##           measurably follows that sidestep and hits. The AC 4b cases below replace it.
##
## STORY 7-9 (AC 4b, `7-9/R3`/`R12`): THE STEERING, LIVE -- GREEN only (the longest flight and the fastest
## turn, so the three outcomes sit furthest apart; RED and BLUE show the same shape at their own lower caps,
## measured at the dev pass, and the per-colour ORDER is proven headless off the config). Every case starts
## the defender at the TOUCH spot (travel + one body width dead ahead -- the honest-geometry file's `touch`
## layout) and, on one flight tick, moves it SIDEWAYS by `STEP` perpendicular to the attacker's current
## facing, at the same along-facing distance:
##   straight     -- never moved. HIT: the baseline every whiff below is measured against.
##   early        -- moved on the COMMIT tick, the attacker still far. FOLLOWED AND HIT.
##   early_rigid  -- the same, with every turn rate set to 0 in a `duplicate()` of the authored config. WHIFF:
##                   what makes `early`'s hit the STEERING's rather than the geometry's.
##   late_far     -- moved a few ticks into the flight, the attacker still far: the cap cannot be beaten. HIT.
##   late_far_rigid -- the same at rate 0. WHIFF.
##   late_close   -- moved later in the flight, the attacker close and not yet touching: the turn needed
##                   exceeds what the cap allows in the ticks left. WHIFF -- the late sidestep beats it.
##   late_close_uncapped -- the same move against a `duplicate()` whose turn rates are effectively unbounded.
##                   HIT: what makes `late_close`'s whiff the CAP's rather than geometry's (a sidestep too
##                   wide for the blade at all would whiff here too). Measured at the dev pass: GREEN's
##                   cap-attributable window for this step is flight ticks 12-13 of 27; tick 14 and later
##                   whiff even uncapped, which is why the share sits where it does.
## "Far" and "close" are the attacker's planar distance to the defender at the move, MEASURED and asserted
## (`FAR_AT_LEAST` / `CLOSE_AT_MOST`), so a retune that collapses the gradient fails loudly rather than
## re-labelling the cases.
##
## ON EVERY CHARGING FRAME (AC 9/AC 11): the charge clip's playhead is strictly BELOW the colour's
## measured strike frame, never moves backwards, and keeps MOVING through the launch (no frozen pose
## while the body travels); on the first frame after the landing the clip is no longer the charge
## clip -- no stale progress push re-seeks it.
##
## AND ON THE REAL RUNNER PATH, THE TWO ANCHORS OF THE MAPPING (code review 6-1c): on the commit frame
## the playhead is exactly the curve at C / (C + L), and on the last charging frame exactly the curve
## at (C + L - 1) / (C + L) -- the value `_push_charge_progress` must push one tick before the landing.
## The bounds above alone ("below the strike frame, never backwards, moving") pass a runner that feeds
## the helper wrong spans; these two equalities are what tie the live push to the mapping the headless
## AC 9 test proves, so "arrives at the strike frame on the landing tick" is measured here, not assumed.
##
## THE CHARGEUP IS POKED, NOT CAST (the `test_charge_telegraph_dispatch_live.gd` precedent): colour,
## the two windows the cast seat starts, and CHARGING -- with P1's controller replaced by a stand-in
## that sends a bare intent every tick (story 6-9: a press commits, nothing is held). The cast seat itself is covered
## headless (test_unblockable_tracking_and_reach.gd).
##
## Run: godot --headless --path . --script res://test/integration/test_unblockable_reach_live.gd

class BareController extends Controller:
	func sample() -> InputIntent:
		return InputIntent.new()


const CONFIG_PATH := "res://data/balance/balance_config.tres"
const MARGIN := 0.75
const TRAVEL_EPS := 0.1
const SETTLE := 3
const AFTER := 2
const DEADLINE := 4000
const PLAYHEAD_EPS := 1e-3
const P1_START := Vector3(-6.0, 0.0, 0.0)
## Story 7-9 (AC 4b): one body width (the honest-geometry file's `BODY`): the steering cases' defender
## stands this far beyond where the launch ends -- where the straight launch's blade lands on it.
const BODY := 1.0
## The sideways move, in metres. Measured at the dev pass: GREEN follows it from the commit and from 3.5 m,
## and from about 2.2 m the cap is beaten.
const STEP := 1.5
## When each steering case moves the defender, as a share of the GREEN launch's ticks.
const EARLY_SHARE := 0.0
const LATE_FAR_SHARE := 0.22
const LATE_CLOSE_SHARE := 0.46
## An effectively unbounded turn rate, for the `late_close_uncapped` control: one tick turns any angle.
const UNCAPPED_DEG_PER_SECOND := 100000.0
## The honesty bounds on the labels: the attacker's planar distance to the defender at the move.
const FAR_AT_LEAST := 3.0
const CLOSE_AT_MOST := 2.5

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1_actor: HeroActor
var _p2_actor: HeroActor
var _config: BalanceConfig
## Story 7-9 (AC 4b): the authored config with every turn rate 0, for the rigid controls. In memory only.
var _rigid: BalanceConfig
## Story 7-9 (AC 4b): the authored config with effectively unbounded turn rates, for the cap control.
var _uncapped: BalanceConfig
var _ticks: BalanceTicks
var _failures: Array[String] = []

var _cases: Array = []   # [colour, kind] with kind in {"far", "near", "side"}
var _case_index := 0
var _phase := "setup"
var _phase_frame := 0
var _hp_before := 0.0
var _cast_pos := Vector3.ZERO
var _committed := false
var _commit_playhead := -1.0
var _last_playhead := -1.0
var _y := 0.0
## Story 7-9 (AC 4b): the flight tick count, the move's bookkeeping and the first touch, per case.
var _flight := -1
var _moved_at_distance := -1.0
var _touched_before_move := false


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())
	_config = load(CONFIG_PATH)
	_ticks = BalanceTicks.from_config(_config)
	_rigid = _config.duplicate()
	_rigid.unblockable_turn_rate_degrees_per_second_red = 0.0
	_rigid.unblockable_turn_rate_degrees_per_second_blue = 0.0
	_rigid.unblockable_turn_rate_degrees_per_second_green = 0.0
	_uncapped = _config.duplicate()
	_uncapped.unblockable_turn_rate_degrees_per_second_red = UNCAPPED_DEG_PER_SECOND
	_uncapped.unblockable_turn_rate_degrees_per_second_blue = UNCAPPED_DEG_PER_SECOND
	_uncapped.unblockable_turn_rate_degrees_per_second_green = UNCAPPED_DEG_PER_SECOND
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		for kind in ["far", "near"]:
			_cases.append([color, kind])
	for kind in ["straight", "early", "early_rigid", "late_far", "late_far_rigid", "late_close",
			"late_close_uncapped"]:
		_cases.append([Enums.CardColor.GREEN, kind])


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_p1_actor = _runner._p1_hero if _runner != null else null
		_p2_actor = _runner._p2_hero if _runner != null else null
		if _state == null or _p1_actor == null or _p2_actor == null:
			_failures.append("main scene did not yield a runner, a MatchState and two heroes")
			_report()
			return true
		_runner._p1_controller = BareController.new()
		_y = _p1_actor.position.y
		return false
	if _phase == "draining":
		if _frames - _phase_frame >= SETTLE:
			_report()
			return true
		return false
	if _frames > DEADLINE:
		_failures.append("deadline: stuck in case %d phase %s" % [_case_index, _phase])
		_finish()
		return false
	if _case_index >= _cases.size():
		_finish()
		return false
	var color: int = _cases[_case_index][0]
	var kind: String = _cases[_case_index][1]
	var label := "colour %d %s" % [color, kind]
	var travel := _config.unblockable_launch_distance_for(color)
	var reach := _config.unblockable_reach_for(color)
	var player := _state.p1

	if _phase == "setup":
		# Story 7-9 (AC 4b): the rigid controls run on the zero-rate duplicate, every other case on the
		# authored config; and since the steering cases LAND, every case starts P2 up, unprotected and at
		# full hp -- the honest-geometry file's reset, plus the new knockdown breather (AC 11), which would
		# otherwise drop a later case's touch.
		_state.apply_balance(_rigid if kind.ends_with("_rigid") \
				else (_uncapped if kind.ends_with("_uncapped") else _config))
		_state.p2.hero.heal(_state.p2.hero.get_max_hp())
		if _state.p2.hero.action_state == HeroState.ActionState.STUNNED:
			_state.p2.hero.set_action_state(HeroState.ActionState.IDLE)
		_state.p2.hero.stun.start(0)
		_state.p2.hero.get_up_iframe.start(0)
		_state.p2.hero.unblockable_immunity.start(0)
		var d := travel + reach + MARGIN if kind == "far" \
				else (travel + reach - MARGIN if kind == "near" else travel + BODY)
		_p1_actor.position = P1_START + Vector3(0.0, _y, 0.0)
		_p2_actor.position = P1_START + Vector3(d, _y, 0.0)
		_phase = "settle"
		_phase_frame = _frames
		return false

	if _phase == "settle" and _frames - _phase_frame >= SETTLE:
		_hp_before = _state.p2.hero.get_hp()
		_cast_pos = _p1_actor.position
		_committed = false
		_flight = -1
		_moved_at_distance = -1.0
		_touched_before_move = false
		_commit_playhead = -1.0
		_last_playhead = -1.0
		# The cast seat's three writes, in its order: colour first (the runner reads it at the
		# CHARGING transition), then the two windows, then the state.
		player.charge_color = color
		player.charge_window.start(_ticks.unblockable_chargeup_ticks)
		player.landing_window.start(_ticks.unblockable_chargeup_ticks
				+ _ticks.unblockable_launch_ticks_for(color))
		player.hero.set_action_state(HeroState.ActionState.CHARGING)
		_phase = "charging"
		_phase_frame = _frames
		return false

	if _phase == "charging":
		if _frames - _phase_frame < 2:
			return false  # let the seam drain the CHARGING transition into the controller
		var anim := _p1_actor.animation_controller.animation_player
		var strike: float = AnimationController._CHARGE_STRIKE_FRAME_SECONDS[color]
		if player.hero.action_state == HeroState.ActionState.CHARGING:
			var playhead := anim.current_animation_position
			_check(playhead < strike - 1e-4,
				"%s: playhead %.4f reached the strike frame %.4f before the landing (AC 11)"
					% [label, playhead, strike])
			_check(playhead >= _last_playhead - 1e-4,
				"%s: playhead moved backwards %.4f -> %.4f" % [label, _last_playhead, playhead])
			_last_playhead = playhead
			if not player.charge_window.is_running and not _committed:
				_committed = true
				_commit_playhead = playhead
				var want_commit := _expected_playhead(color, _ticks.unblockable_launch_ticks_for(color))
				_check(absf(playhead - want_commit) < PLAYHEAD_EPS,
					"%s: commit-frame playhead %.4f, want the curve at C/(C+L) = %.4f"
						% [label, playhead, want_commit])
			if not player.charge_window.is_running:
				_flight += 1
				_step_steering_case(kind, color, player)
			return false
		# First frame after the landing.
		_check(_committed, "%s: never observed a committed (launch) frame" % label)
		var want_last := _expected_playhead(color, 1)
		_check(absf(_last_playhead - want_last) < PLAYHEAD_EPS,
			"%s: last charging-frame playhead %.4f, want the curve at (C+L-1)/(C+L) = %.4f"
				% [label, _last_playhead, want_last])
		_check(_last_playhead > _commit_playhead + 1e-4,
			"%s: the playhead did not move during the launch (%.4f -> %.4f) -- a frozen pose while "
				% [label, _commit_playhead, _last_playhead] + "the body travels (AC 11)")
		_check(anim.current_animation != AnimationController._CHARGE_CLIP[color],
			"%s: still on the charge clip after the landing" % label)
		var hit := _state.p2.hero.get_hp() < _hp_before
		var latched: int = _state._charge_reach[0]
		match kind:
			"far":
				_check(not hit, "%s: a defender just OUTSIDE the radius after the launch was hit" % label)
				_check(latched == MatchState.CONTACT_CHARGE_REACH_OUTSIDE,
					"%s: the runner latched kind %d, want OUTSIDE" % [label, latched])
				var moved := _p1_actor.position - _cast_pos
				_check(absf(moved.x - travel) <= TRAVEL_EPS and absf(moved.z) <= TRAVEL_EPS,
					"%s: the launch carried the attacker %s, want %.3f along +x (AC 4)"
						% [label, moved, travel])
			"near":
				# STORY 6-1d (AC 1): the named defect. Inside the authored radius is no longer a
				# hit -- the blade is metres from the model here, and damage across that gap is
				# what this story exists to stop.
				_check(not hit, "%s: a defender INSIDE the authored radius but nowhere near the "
					% label + "blade was hit -- damage across a visible gap (AC 1)")
				_check(latched == MatchState.CONTACT_CHARGE_REACH_OUTSIDE,
					"%s: the runner latched kind %d, want OUTSIDE (no overlap, no contact)"
						% [label, latched])
			"straight":
				_check(hit, "%s: the undisplaced defender at the touch spot was not hit -- every whiff "
					% label + "below would be vacuous")
			"early", "late_far":
				_check(_moved_at_distance >= FAR_AT_LEAST, "%s: moved at %.2f m, want >= %.2f (far)"
					% [label, _moved_at_distance, FAR_AT_LEAST])
				_check(not _touched_before_move, "%s: touched before the move -- not a sidestep test" % label)
				_check(hit, "%s: a sidestep from far was not FOLLOWED -- the steering must hit it (AC 4b)"
					% label)
			"early_rigid", "late_far_rigid":
				_check(_moved_at_distance >= FAR_AT_LEAST, "%s: moved at %.2f m, want >= %.2f (far)"
					% [label, _moved_at_distance, FAR_AT_LEAST])
				_check(not hit, "%s: with every turn rate 0 the same sidestep still landed -- the twin's "
					% label + "hit would be geometry's, not the steering's")
			"late_close":
				_check(_moved_at_distance > 0.0 and _moved_at_distance <= CLOSE_AT_MOST,
					"%s: moved at %.2f m, want <= %.2f (close)" % [label, _moved_at_distance, CLOSE_AT_MOST])
				_check(not _touched_before_move, "%s: touched before the move -- not a sidestep test" % label)
				_check(not hit, "%s: a late sidestep up close must BEAT the cap and whiff (AC 4b)" % label)
			"late_close_uncapped":
				_check(_moved_at_distance > 0.0 and _moved_at_distance <= CLOSE_AT_MOST,
					"%s: moved at %.2f m, want <= %.2f (close)" % [label, _moved_at_distance, CLOSE_AT_MOST])
				_check(not _touched_before_move, "%s: touched before the move -- not a sidestep test" % label)
				_check(hit, "%s: with the cap lifted the same late sidestep was NOT hit -- so `late_close`'s "
					% label + "whiff would be geometry's, not the cap's")
		_phase = "after"
		_phase_frame = _frames
		return false

	if _phase == "after":
		var anim2 := _p1_actor.animation_controller.animation_player
		_check(anim2.current_animation != AnimationController._CHARGE_CLIP[color],
			"%s: a stale progress push re-seeked the charge clip after the landing" % label)
		if _frames - _phase_frame >= AFTER:
			_case_index += 1
			_phase = "setup"
		return false
	return false


## Story 7-9 (AC 4b): the steering cases' one sideways move, on the flight tick their share names --
## perpendicular to the attacker's CURRENT facing, at the defender's same along-facing distance, by `STEP`.
## Records the attacker's planar distance at the move and whether the blade had already touched.
func _step_steering_case(kind: String, color: int, player: PlayerState) -> void:
	var share := -1.0
	match kind:
		"early", "early_rigid":
			share = EARLY_SHARE
		"late_far", "late_far_rigid":
			share = LATE_FAR_SHARE
		"late_close", "late_close_uncapped":
			share = LATE_CLOSE_SHARE
	if share < 0.0 or _moved_at_distance >= 0.0:
		return
	if _state._charge_reach[0] == MatchState.CONTACT_CHARGE_REACH_INSIDE:
		_touched_before_move = true
	if _flight != int(float(_ticks.unblockable_launch_ticks_for(color)) * share):
		return
	var f := player.hero.facing.normalized()
	var forward := Vector3(f.x, 0.0, f.y)
	var side := Vector3(-f.y, 0.0, f.x)
	var rel := _p2_actor.position - _p1_actor.position
	_moved_at_distance = Vector2(rel.x, rel.z).length()
	_p2_actor.position = _p1_actor.position + forward * rel.dot(forward) + side * STEP \
			+ Vector3(0.0, rel.y, 0.0)


## The playhead the runner's progress push must produce with `landing_remaining` ticks left, through
## the SAME two pure statics the runner and the controller call -- read off the authored spans.
func _expected_playhead(color: int, landing_remaining: int) -> float:
	var c := _ticks.unblockable_chargeup_ticks
	var l := _ticks.unblockable_launch_ticks_for(color)
	var progress := AnimationController.charge_attack_progress(landing_remaining, c, l)
	# Story 7-8: the authored swing-at-commit knob ships ON (AC 13), so the runner composes the remap;
	# this mirrors `_push_charge_progress` exactly, whichever way the knob is authored.
	if _config.unblockable_swing_at_commit:
		progress = AnimationController.charge_commit_anchored_progress(progress,
				float(c) / float(c + l), AnimationController.charge_hold_end_for(color))
	return AnimationController.charge_playhead_for(color, progress)


## The `test_charge_telegraph_dispatch_live.gd` teardown, for its measured reason: every CHARGING
## transition here starts a charge sting, and a still-playing AudioStreamPlayer torn down on the
## frame it stops leaks its mixer playback resource across quit() (an `ERROR:` line run_all.sh fails
## on). Every player on both heroes is stopped, a real delay lets the audio thread retire them, and a
## few frames drain before the report.
func _finish() -> void:
	# Story 7-9: leave the live state on the AUTHORED config, never on either steering duplicate.
	if _state != null and _config != null:
		_state.apply_balance(_config)
	for actor: Node in [_p1_actor, _p2_actor]:
		if is_instance_valid(actor):
			for node in actor.find_children("*", "AudioStreamPlayer", true, false):
				(node as AudioStreamPlayer).stop()
	OS.delay_msec(100)
	_phase = "draining"
	_phase_frame = _frames


func _report() -> void:
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
