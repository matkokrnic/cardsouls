extends SceneTree

## Story 7-3 (ACs 7, 9, 12, 16, 17, 18, and the post-smoke feel pass): WHAT THE HOUND'S RIG PLAYS FOR
## WHAT STATE SAYS AND FOR HOW ITS BODY MOVES, driven the way the runner drives it --
## `on_unit_behavior(...)`, `on_unit_motion(...)`, then `on_unit_tick(...)` -- on the shipped
## hound_actor.tscn. `test_unit_clip_selection.gd` / `test_unit_attack_retrigger.gd`'s counterpart.
##
## EVERY ASSERTION IS AN EFFECT READ OFF THE AnimationPlayer (or the skeleton it poses): which clip
## is current, WHERE its playhead is, and how fast and which way it is running. None reads a
## controller constant.
##
##   LOCOMOTION   BY THE BODY'S ACTUAL DIRECTION, whatever the behaviour phase: standing `idle`;
##                forward `walk` or `run`; sideways `walk_left` / `walk_right`, or `run_left` /
##                `run_right` past the fastest walk; backward `walk_backwards`. NEVER a strafe for a body moving forward. A direction near a
##                sector edge does not flicker between two clips.
##   GROUND SPEED each locomotion clip plays at the body's speed over the clip's measured natural
##                speed at the scene's mount scale, inside the row's rate bounds.
##   STALK        standing while state says STALK: `idle`, at the row's slower rate.
##   CROSSFADE    a change of clip BLENDS the outgoing pose out over the row's blend time and has
##                finished after it; the incoming playhead is exactly where it is without a blend.
##   THE BITE     `attack`: frame 0 at windup start; the playhead is AT THE STRIKE MARK when the
##                ACTIVE window opens, for the authored windup AND for a retuned one (the alignment
##                is by construction, not by a constant copied from balance); the release mark when
##                RECOVERY opens; a held phase is not re-sought.
##   THE LEAP     `leap`, the same three marks, its own numbers.
##   HIT (AC 7)   `hit` from frame 0 on a reaction, fitted to the reaction's length; NOT restarted
##                while the countdown runs down; restarted when a new reaction re-arms it.
##   GET-UP (16)  `death` running BACKWARDS from its last frame, fitted to the lockout, reaching
##                frame 0 as the lockout ends; a hound killed mid-rise plays `death` FORWARDS again.
##   DEATH        liveness first, whatever the behaviour phase says.
##   BARK (18)    RARELY: only on entering BACK_OFF, never sooner than the kind's interval after the
##                last one, and then with the kind's chance; never on a timer; never for a kind with
##                no interval or no chance; two sibling hounds do not bark on the same back-offs.
##   THE ZOMBIE   pushed the same facts, selects exactly as before and never barks.
##
## THE MARKS AND THE TWO GROUND SPEEDS BELOW ARE THE MEASUREMENT (tools/measure_hellhound_rig.gd),
## restated so this file fails if the controller's numbers move without the measurement being redone.
##
## Run: godot --headless --path . --script res://test/integration/test_hound_clip_selection.gd

const TICK_HZ := 60.0
const BITE_STRIKE := 18.0 / 30.0
const BITE_RELEASE := 22.0 / 30.0
const LEAP_STRIKE := 4.0 / 30.0
const LEAP_RELEASE := 14.0 / 30.0
## Model units per second (table 5 of the measurement).
const WALK_UNITS := 1.742
const RUN_UNITS := 10.61
const EPS := 0.002

## The row knobs this test pushes: in-test literals, not the authored row's.
const BLEND := 0.15
const RATE_MIN := 0.5
const RATE_MAX := 3.0
const STALK_RATE := 0.5
## Forward is within 50 degrees of the body's facing, backward within 50 of its rear; a heading is
## held 12 degrees past its edge.
const FORWARD_SECTOR := 50.0
const SECTOR_HOLD := 12.0

const IDLE := UnitBoard.AttackPhase.IDLE
const WINDUP := UnitBoard.AttackPhase.WINDUP
const ACTIVE := UnitBoard.AttackPhase.ACTIVE
const RECOVERY := UnitBoard.AttackPhase.RECOVERY
const ENGAGE := UnitBoard.BehaviorPhase.ENGAGE
const BACK_OFF := UnitBoard.BehaviorPhase.BACK_OFF
const CIRCLE := UnitBoard.BehaviorPhase.CIRCLE
const REACT := UnitBoard.BehaviorPhase.REACT
const GET_UP := UnitBoard.BehaviorPhase.GET_UP
const STALK := UnitBoard.BehaviorPhase.STALK
const FEINT_IN := UnitBoard.BehaviorPhase.FEINT_IN
const FEINT_OUT := UnitBoard.BehaviorPhase.FEINT_OUT
const CIRCLE_TURN := UnitBoard.BehaviorPhase.CIRCLE_TURN

const HOUNDS := 34
const RETREAT := UnitBoard.BehaviorPhase.RETREAT
const REPOSITION := UnitBoard.BehaviorPhase.REPOSITION
const RUN_ON := UnitBoard.BehaviorPhase.RUN_ON

## Feel pass 2: the growl knobs the next `_tick` pushes. Zero, a hound never growls.
var _growl_seconds := 0.0
var _growl_chance := 0.0

var _failures: Array[String] = []
var _hounds: Array[Node] = []
var _next_hound := 0
var _zombie: Node
var _rig: UnitAnimationController
var _player: AnimationPlayer
## The blend time the next `_tick` pushes; a test that wants a snap sets 0.0.
var _blend := BLEND
## The scale hound_actor.tscn mounts its model at, read off the scene.
var _mount_scale := 1.0


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= EPS


## One runner tick's worth of pushes onto the rig under test. `forward` and `side` are the body's own
## velocity (ahead, to its right).
func _tick(alive: bool, attack_phase: int, forward: float, behavior: int = ENGAGE, behavior_ticks: int = 0,
		circle_dir: int = UnitBoard.CIRCLE_NONE, choice: int = 0, attack_ticks: int = 0,
		bark_interval: int = 0, bark_chance: float = 0.0, side: float = 0.0) -> void:
	_rig.on_unit_behavior(behavior, behavior_ticks, circle_dir, choice, attack_ticks, bark_interval, bark_chance)
	_rig.on_unit_motion(forward, side, _knobs())
	_rig.on_unit_tick(alive, attack_phase, Vector2(forward, side).length())


## The presentation row this test pushes: built here from the literals above, never the authored one.
func _knobs() -> EffectPresentationRow:
	var row := EffectPresentationRow.new()
	row.extra = {
		&"blend_seconds": _blend,
		&"locomotion_rate_min": RATE_MIN,
		&"locomotion_rate_max": RATE_MAX,
		&"stalk_rate": STALK_RATE,
		&"heading_forward_degrees": FORWARD_SECTOR,
		&"heading_hold_degrees": SECTOR_HOLD,
		&"growl_interval_seconds": _growl_seconds,
		&"growl_chance": _growl_chance,
	}
	return row


## A body moving at `speed`, `degrees` off its own forward (positive to its right), in `behavior`.
func _move(speed: float, degrees: float, behavior: int = ENGAGE, circle_dir: int = UnitBoard.CIRCLE_NONE) -> void:
	var angle := deg_to_rad(degrees)
	_tick(true, IDLE, cos(angle) * speed, behavior, 30, circle_dir, 0, 0, 0, 0.0, sin(angle) * speed)


func _use(actor: Node) -> void:
	_rig = actor.get_node(^"AnimationController") as UnitAnimationController
	_player = _rig.animation_player


## A hound no earlier test has touched.
func _fresh() -> Node:
	var hound := _hounds[_next_hound]
	_next_hound += 1
	_use(hound)
	return hound


func _expect(clip: StringName, position: float, rate: float, what: String) -> void:
	_check(_player.current_animation == clip,
			"%s: expected clip '%s', got '%s'" % [what, clip, _player.current_animation])
	_check(_near(_player.current_animation_position, position),
			"%s: expected the playhead at %.4f, got %.4f" % [what, position, _player.current_animation_position])
	_check(_near(_player.get_playing_speed(), rate),
			"%s: expected rate %.4f, got %.4f" % [what, rate, _player.get_playing_speed()])


func _expect_moving(clip: StringName, rate: float, what: String) -> void:
	_check(_player.current_animation == clip,
			"%s: expected clip '%s', got '%s'" % [what, clip, _player.current_animation])
	_check(_near(_player.get_playing_speed(), rate),
			"%s: expected '%s' at rate %.4f, got %.4f" % [what, clip, rate, _player.get_playing_speed()])


func _run() -> void:
	var model := _hounds[0].get_node_or_null("Hellhound") as Node3D
	_check(model != null, "hound_actor.tscn has no `Hellhound` model node")
	if model != null:
		_mount_scale = model.transform.basis.get_scale().y
	_locomotion()
	_never_a_strafe_going_forward()
	_sector_hold()
	_stalk()
	_crossfade()
	_attack(0, &"attack", BITE_STRIKE, BITE_RELEASE, 21, 9, 27)
	_attack(1, &"leap", LEAP_STRIKE, LEAP_RELEASE, 27, 18, 30)
	_retuned_windup()
	_hit_reaction()
	_get_up()
	_bark()
	_voices()
	_zombie_is_unchanged()


## The clip follows the DIRECTION the body moves in, and plays at the body's ground speed.
func _locomotion() -> void:
	_fresh()
	_check(_rig is HoundAnimationController, "hound_actor.tscn's controller is not a HoundAnimationController")
	var walk := WALK_UNITS * _mount_scale
	var run := RUN_UNITS * _mount_scale
	_tick(true, IDLE, 0.0)
	_expect_moving(&"idle", 1.0, "standing still")
	_tick(true, IDLE, 4.0)
	_expect_moving(&"run", 4.0 / run, "running forward at 4.0 m/s")
	_tick(true, IDLE, 1.0)
	_expect_moving(&"walk", 1.0 / walk, "walking forward at 1.0 m/s")
	# The walk is played as fast as the row allows before the run takes over, and the run no slower
	# than the row allows.
	_tick(true, IDLE, walk * RATE_MAX - 0.02)
	_expect_moving(&"walk", (walk * RATE_MAX - 0.02) / walk, "just under the fastest walk")
	_tick(true, IDLE, walk * RATE_MAX + 0.02)
	_expect_moving(&"run", maxf(RATE_MIN, (walk * RATE_MAX + 0.02) / run), "just over the fastest walk")
	_tick(true, IDLE, 0.2)
	_expect_moving(&"walk", RATE_MIN, "a crawl: the walk at the row's slowest rate")
	# Sideways too: past the fastest walk a strafing body RUNS sideways (a hound turning round as it
	# sets off), at its ground speed over the run's. Backward there is only the walk.
	_move(4.0, 90.0)
	_expect_moving(&"run_right", 4.0 / run, "moving to its right at 4.0 m/s")
	_move(4.0, -90.0)
	_expect_moving(&"run_left", 4.0 / run, "moving to its left at 4.0 m/s")
	_move(walk * RATE_MAX - 0.02, -90.0)
	_expect_moving(&"walk_left", (walk * RATE_MAX - 0.02) / walk, "moving to its left just under the fastest walk")
	_move(4.0, 180.0)
	_expect_moving(&"walk_backwards", RATE_MAX, "moving backward at 4.0 m/s: the walk at the row's fastest rate")
	# Every direction, in every phase that moves: the phase does not pick the clip.
	for behavior: int in [ENGAGE, BACK_OFF, CIRCLE, CIRCLE_TURN, FEINT_IN, FEINT_OUT]:
		for dir: int in [UnitBoard.CIRCLE_CLOCKWISE, UnitBoard.CIRCLE_COUNTER_CLOCKWISE]:
			var what := "behaviour %d, circle_dir %d" % [behavior, dir]
			_move(1.4, 180.0, behavior, dir)
			_expect_moving(&"walk_backwards", 1.4 / walk, what + ", moving backward")
			_move(1.4, 90.0, behavior, dir)
			_expect_moving(&"walk_right", 1.4 / walk, what + ", moving to its right")
			_move(1.4, -90.0, behavior, dir)
			_expect_moving(&"walk_left", 1.4 / walk, what + ", moving to its left")
			_move(1.4, 0.0, behavior, dir)
			_expect_moving(&"walk", 1.4 / walk, what + ", moving forward")
			_move(0.0, 0.0, behavior, dir)
			_expect_moving(&"idle", 1.0, what + ", not moving")
	_tick(false, IDLE, 3.2, CIRCLE, 57, UnitBoard.CIRCLE_CLOCKWISE)
	_expect(&"death", 0.0, 1.0, "a hound that died while circling")


## The live smoke: "use strafe when going forward". A body moving forward plays a forward clip in
## every phase and for either circle direction, from any previous clip.
func _never_a_strafe_going_forward() -> void:
	_fresh()
	for behavior: int in [ENGAGE, BACK_OFF, CIRCLE, CIRCLE_TURN, FEINT_IN, FEINT_OUT, STALK]:
		for dir: int in [UnitBoard.CIRCLE_CLOCKWISE, UnitBoard.CIRCLE_COUNTER_CLOCKWISE]:
			for from_degrees: float in [90.0, -90.0, 180.0]:
				for speed: float in [1.0, 4.0]:
					for degrees: float in [0.0, 20.0, -20.0]:
						_move(1.4, from_degrees, behavior, dir)
						_move(speed, degrees, behavior, dir)
						var clip := _player.current_animation
						_check(clip == &"walk" or clip == &"run",
								"moving %.0f deg off forward at %.1f m/s in behaviour %d (circle_dir %d, after %.0f deg): plays '%s'"
										% [degrees, speed, behavior, dir, from_degrees, clip])


## A direction near a sector edge keeps the clip it has; well past the edge it changes.
func _sector_hold() -> void:
	_fresh()
	_move(1.4, 0.0)
	_move(1.4, 57.0)
	_check(_player.current_animation == &"walk", "57 deg off forward after moving forward: plays '%s', want 'walk' held"
			% _player.current_animation)
	_move(1.4, 70.0)
	_check(_player.current_animation == &"walk_right", "70 deg off forward: plays '%s', want 'walk_right'"
			% _player.current_animation)
	_move(1.4, 43.0)
	_check(_player.current_animation == &"walk_right", "43 deg off forward after strafing: plays '%s', want 'walk_right' held"
			% _player.current_animation)
	_move(1.4, 30.0)
	_check(_player.current_animation == &"walk", "30 deg off forward: plays '%s', want 'walk'" % _player.current_animation)
	_move(1.4, 180.0)
	_move(1.4, -125.0)
	_check(_player.current_animation == &"walk_backwards",
			"125 deg off forward after backing: plays '%s', want 'walk_backwards' held" % _player.current_animation)
	_move(1.4, -100.0)
	_check(_player.current_animation == &"walk_left", "100 deg off forward to the left: plays '%s', want 'walk_left'"
			% _player.current_animation)
	# A rig pushed NO row (a kind with none) splits the headings at quarter-turns and holds nothing.
	_fresh()
	_rig.on_unit_motion(1.0, 0.0, null)
	_rig.on_unit_tick(true, IDLE, 1.0)
	_rig.on_unit_motion(cos(deg_to_rad(48.0)) * 1.0, sin(deg_to_rad(48.0)) * 1.0, null)
	_rig.on_unit_tick(true, IDLE, 1.0)
	_check(_player.current_animation == &"walk_right" or _player.current_animation == &"run_right",
			"with no row, 48 deg off forward: plays '%s', want a right strafe (45-degree sectors, no hold)"
					% _player.current_animation)


## Standing while state says STALK is `idle` at the row's slower rate; leaving the stalk restores it.
func _stalk() -> void:
	_fresh()
	_tick(true, IDLE, 0.0)
	_tick(true, IDLE, 0.0, STALK, 40)
	_expect_moving(&"idle", STALK_RATE, "a stalking hound")
	_tick(true, IDLE, 0.0, ENGAGE, 0)
	_expect_moving(&"idle", 1.0, "a hound that has stopped stalking")
	_tick(true, IDLE, 0.0, STALK, 40)
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 21)
	_expect(&"attack", 0.0, BITE_STRIKE / (21 / TICK_HZ), "a bite straight out of a stalk (the stalk's rate must not leak into it)")


## A change of clip blends. Two hounds are driven through the same pushes, one with the row's blend
## time and one with none: mid-blend their skeletons differ, after it they agree, and the incoming
## clip's playhead is the same in both throughout.
func _crossfade() -> void:
	var blended := _fresh()
	var blended_player := _player
	_blend = BLEND
	_tick(true, IDLE, 0.0)
	_tick(true, IDLE, 4.0)
	_player.advance(0.4)
	_tick(true, IDLE, 0.0, REACT, 30)
	var snapped := _fresh()
	var snapped_player := _player
	_blend = 0.0
	_tick(true, IDLE, 0.0)
	_tick(true, IDLE, 4.0)
	_player.advance(0.4)
	_tick(true, IDLE, 0.0, REACT, 30)
	_blend = BLEND
	_check(blended_player.current_animation == &"hit" and snapped_player.current_animation == &"hit",
			"crossfade fixture: both hounds are reacting")
	blended_player.advance(BLEND * 0.4)
	snapped_player.advance(BLEND * 0.4)
	_check(_near(blended_player.current_animation_position, snapped_player.current_animation_position),
			"a blend moved the incoming clip's playhead: %.4f with it, %.4f without"
					% [blended_player.current_animation_position, snapped_player.current_animation_position])
	var mid := _pose_gap(blended, snapped)
	_check(mid > 0.02, "mid-blend the blended hound's pose equals the snapped one's (gap %.5f): nothing is blending" % mid)
	blended_player.advance(BLEND * 0.8)
	snapped_player.advance(BLEND * 0.8)
	var after := _pose_gap(blended, snapped)
	_check(after < 0.002, "after the blend time the two poses still differ (gap %.5f): the blend did not finish" % after)
	_check(_near(blended_player.current_animation_position, snapped_player.current_animation_position),
			"after the blend the two playheads differ")


## The largest difference between two hounds' bone rotations (as quaternion distance), over all bones.
func _pose_gap(a: Node, b: Node) -> float:
	var skel_a := a.get_node("Hellhound/Skeleton3D") as Skeleton3D
	var skel_b := b.get_node("Hellhound/Skeleton3D") as Skeleton3D
	var gap := 0.0
	for bone in skel_a.get_bone_count():
		var qa := skel_a.get_bone_pose_rotation(bone)
		var qb := skel_b.get_bone_pose_rotation(bone)
		gap = maxf(gap, 1.0 - absf(qa.dot(qb)))
	return gap


## One full swing of attack entry `choice`, with phase lengths in ticks.
func _attack(choice: int, clip: StringName, strike: float, release: float, windup: int, active: int,
		recovery: int) -> void:
	_fresh()
	var length := _player.get_animation(clip).length
	var what := "'%s'" % clip
	_tick(true, IDLE, 0.0)
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, windup)
	_expect(clip, 0.0, strike / (windup / TICK_HZ), what + " at windup start")
	# The windup runs out in real time; the clip must have reached the strike mark by itself.
	_player.advance(windup / TICK_HZ)
	_check(_near(_player.current_animation_position, strike),
			"%s: after one windup of playback the playhead is at %.4f, not at the strike mark %.4f"
					% [what, _player.current_animation_position, strike])
	_tick(true, ACTIVE, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, active)
	_expect(clip, strike, (release - strike) / (active / TICK_HZ), what + " when ACTIVE opens")
	_player.advance(active / TICK_HZ)
	_tick(true, RECOVERY, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, recovery)
	_expect(clip, release, (length - release) / (recovery / TICK_HZ), what + " when RECOVERY opens")
	# A HELD phase is not re-sought: the segment has to play, not sit on its first frame.
	_player.advance(0.1)
	var held := _player.current_animation_position
	_tick(true, RECOVERY, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, recovery - 6)
	_check(_player.current_animation_position >= held,
			"%s: a held RECOVERY rewound the clip (%.4f -> %.4f)" % [what, held, _player.current_animation_position])
	# The NEXT swing starts from frame 0 again, straight out of recovery.
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, windup)
	_check(_near(_player.current_animation_position, 0.0),
			"%s: the next swing did not restart from frame 0 (%.4f)" % [what, _player.current_animation_position])
	# And a swing begun out of a RUN (a blend in progress, a playback rate that was not 1.0) still
	# opens ACTIVE on its strike mark.
	_fresh()
	_tick(true, IDLE, 4.0)
	_player.advance(0.2)
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, windup)
	_expect(clip, 0.0, strike / (windup / TICK_HZ), what + " at windup start, out of a run")
	_player.advance(windup / TICK_HZ)
	_check(_near(_player.current_animation_position, strike),
			"%s: out of a run, one windup of playback leaves the playhead at %.4f, not at the strike mark %.4f"
					% [what, _player.current_animation_position, strike])


## AC 17: the strike lands on the ACTIVE edge for a windup NOBODY AUTHORED -- a full second.
func _retuned_windup() -> void:
	_fresh()
	_tick(true, IDLE, 0.0)
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 60)
	_player.advance(1.0)
	_check(_near(_player.current_animation_position, BITE_STRIKE),
			"a 1.0 s windup leaves the bite at %.4f, not at its strike mark %.4f"
					% [_player.current_animation_position, BITE_STRIKE])


func _hit_reaction() -> void:
	_fresh()
	var length := _player.get_animation(&"hit").length
	# Mid-bite, then the reaction: state has already put the attack phase back to IDLE.
	_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 21)
	_tick(true, IDLE, 0.0, REACT, 30)
	_expect(&"hit", 0.0, length / 0.5, "a reaction")
	_player.advance(0.1)
	var running := _player.current_animation_position
	_tick(true, IDLE, 0.0, REACT, 29)
	_check(_player.current_animation == &"hit" and _player.current_animation_position >= running,
			"a reaction counting down restarted the Hit clip (%.4f -> %.4f)"
					% [running, _player.current_animation_position])
	# Hit again while reacting: the countdown jumps back up, and the clip starts over.
	_tick(true, IDLE, 0.0, REACT, 30)
	_expect(&"hit", 0.0, length / 0.5, "a reaction re-armed mid-reaction")
	# A hit that KILLS plays Death, not Hit.
	_tick(false, IDLE, 0.0, REACT, 30)
	_expect(&"death", 0.0, 1.0, "a hound killed while reacting")


func _get_up() -> void:
	_fresh()
	var length := _player.get_animation(&"death").length
	_tick(true, IDLE, 0.0, GET_UP, 72)
	_expect(&"death", length, -length / 1.2, "a hound getting up")
	_player.advance(0.6)
	_check(_near(_player.current_animation_position, length * 0.5),
			"halfway through the get-up the Death clip is at %.4f, not at its middle %.4f"
					% [_player.current_animation_position, length * 0.5])
	_tick(true, IDLE, 0.0, GET_UP, 36)
	_check(_player.get_playing_speed() < 0.0 and _player.current_animation_position < length * 0.5 + EPS,
			"a get-up counting down restarted the reversed clip")
	# Killed mid-rise: Death again, FORWARDS, from its first frame.
	_tick(false, IDLE, 0.0, GET_UP, 35)
	_expect(&"death", 0.0, 1.0, "a hound killed while getting up")

	_fresh()
	_tick(true, IDLE, 0.0, GET_UP, 72)
	_player.advance(1.2)
	_check(_player.current_animation_position <= EPS,
			"at the end of the lockout the reversed Death clip is at %.4f, not at frame 0"
					% _player.current_animation_position)
	_tick(true, IDLE, 0.0, ENGAGE, 0)
	_check(_player.current_animation == &"idle",
			"a hound that has got up: expected 'idle', got '%s'" % _player.current_animation)


## `count` back-offs by the rig under test, `gap` ticks apart, with the given interval and chance.
## Answers which of them barked (by back-off number, from 1).
func _back_offs(count: int, gap: int, interval: int, chance: float) -> Array[int]:
	var barked: Array[int] = []
	for n in count:
		_tick(true, IDLE, -1.4, BACK_OFF, 30, UnitBoard.CIRCLE_NONE, 0, 0, interval, chance)
		if _rig.take_bark():
			barked.append(n + 1)
		for tick in gap - 1:
			_tick(true, IDLE, 4.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 0, interval, chance)
			_check(not _rig.take_bark(), "a hound barked with no back-off beginning (back-off %d, tick %d)" % [n + 1, tick])
	return barked


func _bark() -> void:
	var interval := 360
	# Chance 1.0: the first back-off barks; one inside the interval does not; one after it does.
	_fresh()
	_tick(true, IDLE, 4.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 0, interval, 1.0)
	_check(not _rig.take_bark(), "a hound barked before it ever backed off")
	_check(_back_offs(1, 100, interval, 1.0) == [1], "at chance 1.0 the first back-off did not bark")
	_check(not _rig.take_bark(), "a bark was reported twice")
	_check(_back_offs(2, 100, interval, 1.0).is_empty(),
			"a back-off 100 and 200 ticks after a bark barked again, inside the %d-tick interval" % interval)
	_check(_back_offs(1, 100, interval, 1.0).is_empty(), "a back-off 300 ticks after a bark barked, inside the interval")
	_check(_back_offs(1, 10, interval, 1.0) == [1], "a back-off 400 ticks after a bark did not bark, the interval having passed")
	# Never on a timer: two whole intervals on its feet with no back-off, and through a swing.
	_fresh()
	for tick in interval * 2:
		_tick(true, IDLE, 4.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 0, interval, 1.0)
		_check(not _rig.take_bark(), "a hound that never backed off barked at tick %d" % tick)
	for tick in 60:
		_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 21, interval, 1.0)
		_check(not _rig.take_bark(), "a hound barked mid-swing")
	# Chance 0.0: never. No interval: never, whatever the chance.
	_fresh()
	_check(_back_offs(40, 12, 10, 0.0).is_empty(), "at chance 0.0 a hound barked")
	_fresh()
	_check(_back_offs(40, 12, 0, 1.0).is_empty(), "a kind with no bark interval barked")
	# Chance 0.3, the interval always passed: about three back-offs in ten, and not the same ones
	# for two siblings.
	_fresh()
	var first := _back_offs(200, 12, 10, 0.3)
	_check(first.size() >= 50 and first.size() <= 70,
			"at chance 0.3 a hound barked on %d of 200 back-offs, want about 60" % first.size())
	_fresh()
	var second := _back_offs(200, 12, 10, 0.3)
	_check(second.size() >= 50 and second.size() <= 70,
			"at chance 0.3 its sibling barked on %d of 200 back-offs, want about 60" % second.size())
	_check(first != second, "two sibling hounds bark on exactly the same back-offs")
	# The interval holds at chance 0.3 too: no two barks closer than it.
	_fresh()
	var spaced := _back_offs(200, 12, 100, 0.3)
	for i in range(1, spaced.size()):
		_check((spaced[i] - spaced[i - 1]) * 12 >= 100,
				"two barks %d ticks apart, under the 100-tick interval" % ((spaced[i] - spaced[i - 1]) * 12))
	_check(spaced.size() > 0 and spaced.size() < first.size(), "the interval did not thin the barks (%d)" % spaced.size())


## The zombie's controller is pushed the same facts and must not hear them.
func _zombie_is_unchanged() -> void:
	_use(_zombie)
	_check(not (_rig is HoundAnimationController), "unit_actor.tscn carries the hound's controller")
	_tick(true, IDLE, 0.0, REACT, 30, UnitBoard.CIRCLE_CLOCKWISE, 1, 0, 150, 1.0)
	_check(_player.current_animation == &"idle",
			"a zombie pushed a reaction: expected 'idle', got '%s'" % _player.current_animation)
	_tick(true, IDLE, 3.0, GET_UP, 72, UnitBoard.CIRCLE_NONE, 0, 0, 150, 1.0)
	_check(_player.current_animation == &"walk",
			"a zombie pushed a get-up while moving: expected 'walk', got '%s'" % _player.current_animation)
	_tick(true, IDLE, 0.0, STALK, 30, UnitBoard.CIRCLE_NONE, 0, 0, 150, 1.0, 3.0)
	_check(_player.current_animation == &"walk" and _near(_player.get_playing_speed(), 1.0),
			"a zombie moving sideways: expected its one 'walk' at rate 1.0, got '%s' at %.4f"
					% [_player.current_animation, _player.get_playing_speed()])
	_tick(true, WINDUP, 0.0, BACK_OFF, 30, UnitBoard.CIRCLE_NONE, 1, 54, 150, 1.0)
	_check(_player.current_animation == &"attack" and _near(_player.get_playing_speed(), 1.3 / 0.9),
			"a zombie's swing: expected 'attack' at its 4-3d rate, got '%s' at %.4f"
					% [_player.current_animation, _player.get_playing_speed()])
	_check(not _rig.take_bark(), "a zombie barked")
	_tick(false, IDLE, 0.0)
	_check(_rig.take_voices().is_empty(), "a zombie has a voice due")


## Feel pass 2: WHEN EACH OF THE HOUND'S VOICES COMES DUE (the controller says when; the runner plays).
##   bite / leap   once, on the tick the attack's ACTIVE window opens -- never in windup or recovery.
##   yelp          once per hit reaction, and again for a reaction re-armed while one plays.
##   death         once, on the tick it dies.
##   bark          as a back-off OR a retreat begins (by the kind's interval and chance).
##   growl         as a stalk or a circle begins, by the row's interval and chance; never otherwise.
##   and a taken voice is not reported twice.
func _voices() -> void:
	_fresh()
	_tick(true, IDLE, 4.0)
	_check(_rig.take_voices().is_empty(), "a hound running in has a voice due")
	for choice in 2:
		var want: StringName = &"leap" if choice == 1 else &"bite"
		for tick in 5:
			_tick(true, WINDUP, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, 21 - tick)
			_check(_rig.take_voices().is_empty(), "attack %d: a voice came due in the windup" % choice)
		_tick(true, ACTIVE, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, 9)
		_check(_rig.take_voices() == ([want] as Array[StringName]),
				"attack %d: the tick ACTIVE opens did not give exactly '%s'" % [choice, want])
		_check(_rig.take_voices().is_empty(), "attack %d: its voice was reported twice" % choice)
		for tick in 5:
			_tick(true, ACTIVE, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, 8 - tick)
			_check(_rig.take_voices().is_empty(), "attack %d: a voice came due later in the ACTIVE window" % choice)
		_tick(true, RECOVERY, 0.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, choice, 27)
		_tick(true, IDLE, 0.0)
		_check(_rig.take_voices().is_empty(), "attack %d: a voice came due in recovery" % choice)
	# The yelp: once per reaction, and once more for one re-armed while it plays.
	_tick(true, IDLE, 0.0, REACT, 30)
	_check(_rig.take_voices() == ([&"yelp"] as Array[StringName]), "a hit reaction did not give exactly the yelp")
	_tick(true, IDLE, 0.0, REACT, 29)
	_check(_rig.take_voices().is_empty(), "the yelp came due again on the reaction's second tick")
	_tick(true, IDLE, 0.0, REACT, 30)
	_check(_rig.take_voices() == ([&"yelp"] as Array[StringName]), "a reaction re-armed while one plays did not yelp again")
	# Death: once.
	_tick(false, IDLE, 0.0)
	_check(_rig.take_voices() == ([&"death"] as Array[StringName]), "dying did not give exactly the death voice")
	_tick(false, IDLE, 0.0)
	_check(_rig.take_voices().is_empty(), "a corpse has a voice due on its second tick")
	# The bark is one of the voices, and a RETREAT's start barks as a back-off's does.
	_fresh()
	_tick(true, IDLE, 4.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 0, 360, 1.0)
	_tick(true, IDLE, -1.4, BACK_OFF, 30, UnitBoard.CIRCLE_NONE, 0, 0, 360, 1.0)
	_check(_rig.take_voices() == ([&"bark"] as Array[StringName]), "a back-off's bark is not among the voices")
	_check(not _rig.take_bark(), "a bark taken as a voice was reported again")
	_fresh()
	_tick(true, IDLE, 4.0, ENGAGE, 0, UnitBoard.CIRCLE_NONE, 0, 0, 360, 1.0)
	_tick(true, IDLE, 2.4, RETREAT, 30, UnitBoard.CIRCLE_NONE, 0, 0, 360, 1.0)
	_check(_rig.take_voices() == ([&"bark"] as Array[StringName]), "a retreat's start did not bark")
	# BACK_OFF -> RETREAT is one backing away, not two.
	_fresh()
	_tick(true, IDLE, -1.4, BACK_OFF, 30, UnitBoard.CIRCLE_NONE, 0, 0, 10, 1.0)
	_rig.take_voices()
	for tick in 20:
		_tick(true, IDLE, -1.4, BACK_OFF, 29 - tick, UnitBoard.CIRCLE_NONE, 0, 0, 10, 1.0)
	_tick(true, IDLE, 2.4, RETREAT, 30, UnitBoard.CIRCLE_NONE, 0, 0, 10, 1.0)
	_check(_rig.take_voices().is_empty(), "a retreat that follows its own back-off barked a second time")
	# The growl. Chance 1.0: the first stalk growls; a circle inside the interval does not; one after it does.
	_growl_seconds = 2.0   # 120 ticks
	_growl_chance = 1.0
	_fresh()
	_check(_watch(STALK, 1, 50) == [1], "at chance 1.0 the first stalk did not growl")
	_check(_watch(CIRCLE, 1, 80).is_empty(), "a circle 50 ticks after a growl growled, inside the 120-tick interval")
	_check(_watch(CIRCLE_TURN, 1, 10) == [1], "a circle 130 ticks after a growl did not growl, the interval having passed")
	# Only a stalk or a circle: never as it repositions, runs on, feints, backs off or runs in.
	_fresh()
	for behavior: int in [REPOSITION, RUN_ON, FEINT_IN, FEINT_OUT, BACK_OFF, RETREAT, ENGAGE]:
		_tick(true, IDLE, 2.0, behavior, 30)
		_check(not _rig.take_voices().has(&"growl"), "a hound growled entering behaviour %d" % behavior)
		_tick(true, IDLE, 4.0, ENGAGE, 0)
	# A circle that reverses is one circle.
	_fresh()
	_tick(true, IDLE, 1.4, CIRCLE_TURN, 60)
	_check(_rig.take_voices() == ([&"growl"] as Array[StringName]), "a reversing circle's start did not growl")
	_growl_seconds = 0.01
	_tick(true, IDLE, 1.4, CIRCLE, 20)
	_check(_rig.take_voices().is_empty(), "a circle growled again as it reversed")
	# Chance 0.0 and no interval: never.
	_growl_seconds = 2.0
	_growl_chance = 0.0
	_fresh()
	_check(_watch(STALK, 40, 12).is_empty(), "at chance 0.0 a hound growled")
	_growl_seconds = 0.0
	_growl_chance = 1.0
	_fresh()
	_check(_watch(STALK, 40, 12).is_empty(), "a row with no growl interval growled")
	# Chance 0.5, the interval always passed: about half, and not the same ones for two siblings.
	_growl_seconds = 0.1
	_growl_chance = 0.5
	_fresh()
	var first := _watch(STALK, 200, 12)
	_check(first.size() >= 85 and first.size() <= 115, "at chance 0.5 a hound growled on %d of 200 stalks, want about 100" % first.size())
	_fresh()
	var second := _watch(STALK, 200, 12)
	_check(first != second, "two sibling hounds growl on exactly the same stalks")
	_growl_seconds = 0.0
	_growl_chance = 0.0


## `count` entries into `behavior` by the rig under test, `gap` ticks apart. Answers which of them
## growled (from 1).
func _watch(behavior: int, count: int, gap: int) -> Array[int]:
	var growled: Array[int] = []
	for n in count:
		_tick(true, IDLE, 0.0, behavior, 30)
		if _rig.take_voices().has(&"growl"):
			growled.append(n + 1)
		for tick in gap - 1:
			_tick(true, IDLE, 4.0, ENGAGE, 0)
			_check(_rig.take_voices().is_empty(), "a voice came due with nothing beginning (entry %d, tick %d)" % [n + 1, tick])
	return growled


## One frame, for test_unit_attack_retrigger.gd's measured reason: `_ready()` has not run on a node
## added from inside `_initialize()`.
func _initialize() -> void:
	var hound_scene: PackedScene = load("res://src/actors/minions/hound_actor.tscn")
	for i in HOUNDS:
		var hound := hound_scene.instantiate()
		root.add_child(hound)
		_hounds.append(hound)
	_zombie = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	root.add_child(_zombie)


func _process(_delta: float) -> bool:
	_run()
	_check(_next_hound <= HOUNDS, "the test used %d hounds and instantiated %d" % [_next_hound, HOUNDS])
	for hound: Node in _hounds:
		if is_instance_valid(hound):
			hound.queue_free()
	if is_instance_valid(_zombie):
		_zombie.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
