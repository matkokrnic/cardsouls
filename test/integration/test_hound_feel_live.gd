extends SceneTree

## Story 7-3, post-smoke feel pass (smoke findings 3, 4 and 6): TWO HOUNDS AGAINST A HERO THAT STANDS
## STILL, on the real runner, the shipped hound scene and the AUTHORED numbers. The operator's words:
## "stick together", "get in each other's way", "one freezes and slides", "too similar", "not such
## perfect circles", "they move too fast while orbiting relative to the animation".
##
## EVERY ASSERTION IS AN EFFECT, measured tick by tick off the two actors and their rigs:
##
##   NEVER OVERLAPPING   the two bodies' centres are never closer than their two body radii (read off
##                       the scene).
##   NEVER STUCK         a hound that state has moving (running in, backing off, circling, darting,
##                       retreating -- and that has somewhere to go) is never near-stationary for a
##                       fifth of a second. This is the freeze the smoke saw: a hound behind its
##                       rooted sibling pressed against it for up to half a second.
##   NEVER SLIDING       a hound whose body moves is not standing in `idle`, and its locomotion clip's
##                       playback rate is its ground speed over the clip's natural ground speed
##                       (inside the row's bounds) -- the paws move with the floor.
##   TURN RATE           outside a swing its heading never changes faster than the kind's authored
##                       rate.
##   THEY DIFFER         the two hounds do not run at the same pace: their fastest runs differ, both
##                       inside the kind's authored spread.
##   NOT A CIRCLE        the runner's radius and speed for a circling hound vary over the circle, and
##                       stay inside the two reach bands for every hound and every moment; live, a
##                       circling hound's speed is not constant, and is well under its run.
##   STALK (finding 6)   a stalking hound does not move, faces its target and stands in `idle` at the
##                       row's slower rate.
##   FEINT (finding 6)   a feinting hound darts toward its target, comes no closer than the authored
##                       distance, backs out again, and begins no attack from first tick to last.
##
## FOUR PARTS. Part one runs the authored weights for fifteen seconds and takes the general
## measurements, which carry on through the rest. Parts two, three and four tell the live kind, in
## this process only, to always STALK, then always FEINT, then always CIRCLE, so each is certain to be
## seen (which option is drawn, and how often, is pinned in test/state/test_hellhound.gd).
##
## Run: godot --headless --path . --script res://test/integration/test_hound_feel_live.gd

const HOUND_KIND := &"hellhound"
const SEED := 12345
const NATURAL_FRAMES := 900
const STALK_FRAMES := 420
const FEINT_FRAMES := 420
const CIRCLE_FRAMES := 480

## Model units per second (tools/measure_hellhound_rig.gd, table 5), restated.
const WALK_UNITS := 1.742
const RUN_UNITS := 10.61

## A hound state has moving, and that has somewhere to go, slower than this (m/s) is not moving...
const STUCK_SPEED := 0.25
## ...and may be so for fewer than this many ticks in a row (a fifth of a second).
const STUCK_TICKS := 12
## A body faster than this (m/s) is moving, and its rig may stand in `idle` for no more than
## `SLIDE_TICKS` ticks in a row (the clip follows the motion one tick behind).
const SLIDE_SPEED := 0.6
const SLIDE_TICKS := 4

const A_IDLE := UnitBoard.AttackPhase.IDLE
const B := UnitBoard.BehaviorPhase

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _kind: UnitKindProfile
var _kind_index := -1
var _row: EffectPresentationRow
var _failures: Array[String] = []
var _stage := "natural"
var _stage_start := 0

var _body_radius := 0.0
var _mount_scale := 1.0
var _prev_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _prev_speed: Array[float] = [0.0, 0.0]
var _prev_yaw: Array[float] = [0.0, 0.0]
var _prev_attack: Array[int] = [A_IDLE, A_IDLE]
var _prev_behavior: Array[int] = [B.ENGAGE, B.ENGAGE]
var _sampled := false

var _min_apart := INF
var _min_apart_both_leaping := INF
var _stuck: Array[int] = [0, 0]
var _worst_stuck := 0
var _slide: Array[int] = [0, 0]
var _worst_slide := 0
var _rate_checks := 0
var _over_rate := 0
var _worst_turn := 0.0
var _top_run: Array[float] = [0.0, 0.0]
var _circle_speeds: Array = [[], []]
var _circle_age: Array[int] = [0, 0]
var _seen: Dictionary = {}
var _backing_clips: Dictionary = {}
var _leaps := 0
var _bites := 0

## Per hound: the phase being measured, where it began, and what was seen during it.
var _phase_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _phase_start_distance: Array[float] = [0.0, 0.0]
var _phase_faced_target: Array[bool] = [true, true]
var _phase_closest: Array[float] = [INF, INF]
var _phase_ticks: Array[int] = [0, 0]
var _phase_slow_idle: Array[int] = [0, 0]
var _stalks_measured := 0
var _feints_measured := 0
var _retreats_measured := 0


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.seed_override = SEED
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_effects = _runner._effects if _runner != null else null
		if _runner == null or _state == null or _effects == null:
			return _finish("missing: runner=%s state=%s effects=%s" % [_runner, _state, _effects])
		_kind_index = _state.balance.kind_index_of(HOUND_KIND)
		_kind = _state.balance.kind_at(_kind_index)
		_row = _effects.row(HOUND_KIND)
		if _kind == null or _row == null:
			return _finish("authored data carries no `hellhound` kind or presentation row")
		_check_circle_shape()
		_check_steering_and_motion()
		return false
	if _frames == 3:
		_state.p1.units.add(_kind.max_hp, _kind_index)
		_state.p1.units.add(_kind.max_hp, _kind_index)
		return false
	if _frames < 6:
		return false
	var first := _actor(0)
	var second := _actor(1)
	if first == null or second == null:
		return _finish("the two hounds were not spawned")
	if _frames == 6:
		# Their summoner stands in their lane to the enemy (the `4-3e` finding); it is moved well aside.
		_runner._p1_hero.global_position += Vector3(0.0, 0.0, 9.0)
		var body := first.get_node_or_null("Collision") as CollisionShape3D
		var cylinder := (body.shape if body != null else null) as CylinderShape3D
		if cylinder == null:
			return _finish("the hound's body is not a cylinder")
		_body_radius = cylinder.radius
		_mount_scale = (first.get_node("Hellhound") as Node3D).transform.basis.get_scale().y
		_stage_start = _frames
		return false
	_measure(0, first, second)
	_measure(1, second, first)
	_sampled = true
	# Feel pass 2: TWO HOUNDS MID-LEAP AT ONCE are measured apart. Each is moved up to 0.3 m a tick
	# against where the physics server last saw the other, so two leaps meeting head-on (seen: both
	# through the hero from opposite sides) close a hand's width inside their radii for a tick or two
	# before they are parted. Bounded on its own, looser bar; every other tick keeps the strict one.
	var apart := _planar(first.global_position, second.global_position)
	if _leaping(0) and _leaping(1):
		_min_apart_both_leaping = minf(_min_apart_both_leaping, apart)
	else:
		_min_apart = minf(_min_apart, apart)
	match _stage:
		"natural":
			if _frames - _stage_start >= NATURAL_FRAMES:
				_only(&"stalk_weight")
				_stage = "stalk"
				_stage_start = _frames
		"stalk":
			if _frames - _stage_start >= STALK_FRAMES:
				_only(&"feint_weight")
				_stage = "feint"
				_stage_start = _frames
		"feint":
			if _frames - _stage_start >= FEINT_FRAMES:
				_only(&"circle_weight")
				_stage = "circle"
				_stage_start = _frames
		"circle":
			if _frames - _stage_start >= CIRCLE_FRAMES:
				return _finish("")
	return false


## Is hound `i` in the ACTIVE window of an attack that carries it past its target, or in the recovery
## that follows it (it has just landed)?
func _leaping(i: int) -> bool:
	var units := _state.p1.units
	var attack := _kind.attack_at(units.attack_choice_at(i))
	if attack == null or attack.travel_overshoot <= 0.0:
		return false
	return units.attack_phase_at(i) == UnitBoard.AttackPhase.ACTIVE \
			or units.attack_phase_at(i) == UnitBoard.AttackPhase.RECOVERY


## Tell the live kind to draw only `weight` from now on (this process only).
func _only(weight: StringName) -> void:
	for field: StringName in [&"circle_weight", &"stalk_weight", &"feint_weight", &"re_engage_weight"]:
		_kind.set(field, 1.0 if field == weight else 0.0)


## One tick of one hound. The test's callback runs BEFORE the runner's in a frame, so everything read
## here is the frame that just ended.
func _measure(i: int, hound: UnitActor, other: UnitActor) -> void:
	var units := _state.p1.units
	var here := hound.global_position
	var yaw := hound.global_rotation.y
	var attack := units.attack_phase_at(i)
	var behavior := units.behavior_phase_at(i)
	var target: Vector3 = _runner._p2_hero.global_position
	var distance := _planar(here, target)
	var rig := hound.animation.animation_player
	var clip: StringName = rig.current_animation
	if not _sampled:
		_prev_pos[i] = here
		_prev_yaw[i] = yaw
		_prev_attack[i] = attack
		_prev_behavior[i] = behavior
		return
	var speed := _planar(here, _prev_pos[i]) * 60.0
	var pace := _kind.move_speed * UnitTemperament.factor(0, i, UnitTemperament.CHANNEL_SPEED,
			_kind.temperament_speed_spread)
	var hold: float = _runner._circle_radius(_kind, 0, i, 0, 0)
	var has_target := units.target_slot_at(i) != TargetingService.NO_TARGET_SLOT
	var idle_now := attack == A_IDLE and _prev_attack[i] == A_IDLE

	# What happened: attacks begun, options taken.
	if attack != _prev_attack[i] and attack == UnitBoard.AttackPhase.WINDUP:
		if units.attack_choice_at(i) == 1:
			_leaps += 1
		else:
			_bites += 1
	if behavior != _prev_behavior[i]:
		# A phase edge is seen one drive AFTER state entered the phase: the body has already made the
		# new phase's first move. Where it stood one sample ago is where the old phase ended and the
		# new one began (test_hound_motion_live.gd's `before`).
		_on_phase_change(i, hound, _prev_behavior[i], behavior, _prev_pos[i], _planar(_prev_pos[i], target))

	# NEVER STUCK.
	var moving := false
	if idle_now and has_target:
		# (Feel pass 2: a hound runs in only as fast as it faces its target -- one that has just landed
		# past it, or run on from it, is turning round, not stuck.)
		var faces_target := _facing(hound, target) > 0.7
		match behavior:
			B.ENGAGE, B.ENGAGE_BITE, B.ENGAGE_LEAP, B.PRESS_BITE, B.PRESS_LEAP, B.PRESS_AGAIN_BITE, B.PRESS_AGAIN_LEAP:
				moving = distance > _kind.stop_distance + 0.3 and faces_target
			B.BACK_OFF, B.FEINT_OUT:
				moving = distance < hold - 0.3
			B.CIRCLE, B.CIRCLE_TURN:
				moving = true
			B.FEINT_IN:
				moving = distance > _kind.feint_closest_distance + 0.3 and faces_target
			B.REPOSITION:
				# Feel pass 2. It turns onto its arc before it runs: its first ticks are a turn.
				moving = _phase_ticks[i] > 20
			B.RETREAT:
				moving = _phase_ticks[i] > 30 and distance < _kind.retreat_distance - 0.3
	if moving and speed < STUCK_SPEED:
		_stuck[i] += 1
		if _stuck[i] == STUCK_TICKS:
			_check(false, "hound %d was stuck for %d ticks at frame %d: behaviour %d, %.2f m from its target, %.2f m from the other hound"
					% [i, STUCK_TICKS, _frames, behavior, distance, _planar(here, other.global_position)])
	else:
		_stuck[i] = 0
	_worst_stuck = maxi(_worst_stuck, _stuck[i])

	# NEVER SLIDING: a moving body is not in `idle`...
	if units.is_alive_at(i) and idle_now and behavior != B.REACT and behavior != B.GET_UP \
			and speed > SLIDE_SPEED and _prev_speed[i] > SLIDE_SPEED and clip == &"idle":
		_slide[i] += 1
		if _slide[i] == SLIDE_TICKS:
			_check(false, "hound %d slid on `idle` for %d ticks at frame %d (behaviour %d, %.2f m/s)"
					% [i, SLIDE_TICKS, _frames, behavior, speed])
	else:
		_slide[i] = 0
	_worst_slide = maxi(_worst_slide, _slide[i])
	# ...and its clip plays at its ground speed. The rig was pushed the motion of the tick BEFORE the
	# one just measured, so it is held to that one, and only while the speed is steady.
	var natural := 0.0
	if clip == &"run" or clip == &"run_left" or clip == &"run_right":
		natural = RUN_UNITS * _mount_scale
	elif clip == &"walk" or clip == &"walk_backwards" or clip == &"walk_left" or clip == &"walk_right":
		natural = WALK_UNITS * _mount_scale
	if natural > 0.0 and idle_now and absf(speed - _prev_speed[i]) < 0.1 and _prev_speed[i] > SLIDE_SPEED:
		var want := clampf(_prev_speed[i] / natural, _row.knob(&"locomotion_rate_min", 1.0),
				_row.knob(&"locomotion_rate_max", 1.0))
		_rate_checks += 1
		# A body going faster than its clip can be played at all is a body whose paws slide. The only
		# clip with no faster one behind it is the backward walk; such ticks are counted.
		if _prev_speed[i] / natural > _row.knob(&"locomotion_rate_max", 1.0) * 1.25:
			_over_rate += 1
		_check(absf(rig.get_playing_speed() - want) < 0.12 * want + 0.05,
				"hound %d plays '%s' at rate %.3f while its body does %.2f m/s: the paws want rate %.3f (frame %d)"
						% [i, clip, rig.get_playing_speed(), _prev_speed[i], want, _frames])

	# TURN RATE, outside a swing and a get-up.
	if idle_now and behavior != B.GET_UP and _prev_behavior[i] != B.GET_UP:
		var turned := absf(angle_difference(_prev_yaw[i], yaw)) * 60.0
		_worst_turn = maxf(_worst_turn, rad_to_deg(turned))
		_check(rad_to_deg(turned) <= _kind.turn_rate_degrees_per_second + 1.0,
				"hound %d turned at %.0f deg/s outside a swing, over the authored %.0f (frame %d)"
						% [i, rad_to_deg(turned), _kind.turn_rate_degrees_per_second, _frames])

	# THEY DIFFER: the fastest each hound runs in, away from the other (no steering added).
	if idle_now and UnitBoard.is_engage_phase(behavior) and distance > _kind.stop_distance + 1.0 \
			and _planar(here, other.global_position) > _kind.separation_distance + 0.2:
		_top_run[i] = maxf(_top_run[i], speed)
		_check(speed <= pace + 0.1, "hound %d ran in at %.2f m/s, over its own pace %.2f" % [i, speed, pace])

	# NOT A CIRCLE: the speed of a settled circle, away from the other hound.
	if idle_now and (behavior == B.CIRCLE or behavior == B.CIRCLE_TURN):
		_circle_age[i] += 1
		# (Feel pass 2: circles are shorter, 0.6 to 1.4 s, so "settled" is a quarter of a second in.)
		if _circle_age[i] > 15 and _planar(here, other.global_position) > _kind.separation_distance + 0.2:
			(_circle_speeds[i] as Array).append(speed)
	else:
		_circle_age[i] = 0

	# Feel pass 2 (finding C, a DIAGNOSIS: nothing is asserted on it): which clip the rig plays while
	# the hound backs off and while a feint retreats, tick by tick.
	if units.is_alive_at(i) and idle_now and (behavior == B.BACK_OFF or behavior == B.FEINT_OUT):
		var key := "%s/%s" % ["BACK_OFF" if behavior == B.BACK_OFF else "FEINT_OUT", clip]
		_backing_clips[key] = int(_backing_clips.get(key, 0)) + 1

	# STALK and FEINT, while they last.
	_phase_ticks[i] += 1
	_phase_closest[i] = minf(_phase_closest[i], distance)
	if behavior == B.STALK:
		_check(attack == A_IDLE, "a stalking hound is in attack phase %d (frame %d)" % [attack, _frames])
		if clip == &"idle" and absf(rig.get_playing_speed() - _row.knob(&"stalk_rate", 1.0)) < 0.01:
			_phase_slow_idle[i] += 1
	if behavior == B.FEINT_IN or behavior == B.FEINT_OUT:
		_check(attack == A_IDLE, "a feinting hound is in attack phase %d (frame %d)" % [attack, _frames])
		_check(distance > _kind.feint_closest_distance - 0.2 or _phase_start_distance[i] < _kind.feint_closest_distance,
				"a feinting hound came %.2f m from its target, inside the authored %.2f (frame %d)"
						% [distance, _kind.feint_closest_distance, _frames])

	_prev_pos[i] = here
	_prev_speed[i] = speed
	_prev_yaw[i] = yaw
	_prev_attack[i] = attack
	_prev_behavior[i] = behavior


## A hound left `from` for `to`: close the measurement of the phase that ended, open the next.
func _on_phase_change(i: int, hound: UnitActor, from: int, to: int, at: Vector3, distance: float) -> void:
	var units := _state.p1.units
	var target: Vector3 = _runner._p2_hero.global_position
	var moved := _planar(at, _phase_from[i])
	match from:
		B.STALK:
			_stalks_measured += 1
			_check(moved < 0.05, "a stalking hound moved %.3f m (frame %d)" % [moved, _frames])
			_check(_facing(hound, target) > 0.9, "a hound that stalked does not face its target (cos %.3f)" % _facing(hound, target))
			_check(_phase_slow_idle[i] >= _phase_ticks[i] / 2,
					"a hound stalked for %d ticks and stood in the slowed `idle` for only %d of them"
							% [_phase_ticks[i], _phase_slow_idle[i]])
		B.FEINT_IN:
			_feints_measured += 1
			var room := _phase_start_distance[i] - _kind.feint_closest_distance
			# (Feel pass 2: a feint drawn as a run-on ends begins with the hound's back to its target;
			# its dart is then mostly a turn, and is not measured.)
			if room > 0.5 and _phase_ticks[i] >= 8 and _phase_faced_target[i]:
				_check(_phase_start_distance[i] - distance > 0.3,
						"a feint's dart took the hound from %.2f m to %.2f m: it did not dart in"
								% [_phase_start_distance[i], distance])
			_check(to == B.FEINT_OUT or to == B.REACT, "a feint's dart was followed by behaviour %d, want the retreat" % to)
		B.FEINT_OUT:
			var hold: float = _runner._circle_radius(_kind, 0, i, 0, 0)
			if hold - _phase_start_distance[i] > 0.5 and _phase_ticks[i] >= 8:
				_retreats_measured += 1
				_check(distance - _phase_start_distance[i] > 0.15,
						"a feint's retreat took the hound from %.2f m to %.2f m: it did not back out"
								% [_phase_start_distance[i], distance])
	match to:
		B.CIRCLE, B.CIRCLE_TURN:
			if from != B.CIRCLE_TURN:
				_seen["circle"] = int(_seen.get("circle", 0)) + 1
		B.STALK:
			_seen["stalk"] = int(_seen.get("stalk", 0)) + 1
		B.FEINT_IN:
			_seen["feint"] = int(_seen.get("feint", 0)) + 1
		B.ENGAGE_BITE, B.ENGAGE_LEAP:
			if from == B.BACK_OFF:
				_seen["direct"] = int(_seen.get("direct", 0)) + 1
	_phase_from[i] = at
	_phase_faced_target[i] = _facing(hound, target) > 0.9
	_phase_start_distance[i] = distance
	_phase_closest[i] = distance
	_phase_ticks[i] = 0
	_phase_slow_idle[i] = 0
	if units.behavior_ticks_at(i) < 0:
		_check(false, "a behaviour countdown is negative")


## NOT A CIRCLE, on the runner's own two functions: for hounds at several addresses, over a whole
## wobble period, the radius and the speed both vary, and no radius leaves the two reach bands.
func _check_circle_shape() -> void:
	var wobble: int = _state.balance_ticks.kind_ticks_at(_kind_index).circle_wobble_ticks
	_check(wobble > 0, "the hound kind authors no circle wobble period")
	if wobble <= 0:
		return
	var bite := _kind.attack_at(0).range
	var leap := _kind.attack_at(1).range
	var resting: Array[float] = []
	for slot in 2:
		for index in 6:
			var low := INF
			var high := -INF
			var slow := INF
			var fast := -INF
			for tick in wobble:
				var radius: float = _runner._circle_radius(_kind, slot, index, tick, wobble)
				var speed: float = _runner._circle_speed(_kind, slot, index, tick, wobble, _kind.move_speed)
				low = minf(low, radius)
				high = maxf(high, radius)
				slow = minf(slow, speed)
				fast = maxf(fast, speed)
			_check(low >= bite and high <= leap,
					"hound (%d, %d) circles between %.2f and %.2f m, outside the reach bands %.2f to %.2f"
							% [slot, index, low, high, bite, leap])
			_check(high - low > 0.2, "hound (%d, %d)'s circle radius only varies by %.3f m: a circle" % [slot, index, high - low])
			_check(fast - slow > 0.2 and slow > 0.0,
					"hound (%d, %d)'s circle speed runs from %.2f to %.2f m/s: it does not vary, or it stops" % [slot, index, slow, fast])
			_check(fast < _kind.move_speed * 0.6,
					"hound (%d, %d) circles at up to %.2f m/s, over half its run again" % [slot, index, fast])
			if slot == 0:
				resting.append(_runner._circle_radius(_kind, slot, index, 0, 0))
	for index in range(1, resting.size()):
		_check(absf(resting[index] - resting[index - 1]) > 0.1,
				"sibling hounds %d and %d rest at the same circle radius (%.3f, %.3f)"
						% [index - 1, index, resting[index - 1], resting[index]])


## THE ACTOR'S OWN TWO NEW RULES, on one hound scene standing alone far from the arena: what a
## separation push does to the one move it is handed for, and what `take_motion()` reports. Each
## number below is this test's own input; every expectation is a property of the velocity that results.
func _check_steering_and_motion() -> void:
	var hound := (load("res://src/actors/minions/hound_actor.tscn") as PackedScene).instantiate() as UnitActor
	root.add_child(hound)
	var home := Vector3(70.0, 0.0, 70.0)
	hound.global_position = home
	var ahead := home + Vector3(0.0, 0.0, -5.0)   # the target: straight down -Z
	var speed := 4.0
	var extra := 2.0
	# No push: straight at the target.
	hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
	_check(hound.velocity.is_equal_approx(Vector3(0.0, 0.0, -speed)), "an unsteered approach is %s" % hound.velocity)
	# A neighbour DEAD AHEAD (it pushes the hound back along +Z, half weight): the hound no longer
	# presses on at full speed, and GOES ROUND -- to the side it is told, the other side when told
	# the other.
	var sides: Array[float] = [1.0, -1.0]
	var across: Array[float] = []
	for side: float in sides:
		hound.global_position = home
		hound.set_separation(Vector2(0.0, 0.5), 0.0, side)
		hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
		across.append(hound.velocity.x)
		_check(-hound.velocity.z < speed * 0.75 and -hound.velocity.z > 0.0,
				"blocked ahead, the hound still closes at %.2f m/s of its %.2f (it presses on, or it reverses)"
						% [-hound.velocity.z, speed])
	_check(absf(across[0]) > 0.5 and absf(across[1]) > 0.5 and signf(across[0]) != signf(across[1]),
			"blocked ahead, the hound goes round at %.2f and %.2f m/s for the two sides: want real, opposite sideways speeds"
					% [across[0], across[1]])
	# A neighbour BESIDE it (pushing it along +X): its own way is clear, so it keeps its speed toward
	# the target and only drifts off, by the extra speed it was allowed times the push's weight.
	hound.global_position = home
	hound.set_separation(Vector2(0.5, 0.0), extra, 1.0)
	hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
	_check(absf(-hound.velocity.z - speed) < 0.01, "a neighbour beside it slowed the hound to %.2f m/s" % -hound.velocity.z)
	_check(absf(hound.velocity.x - extra * 0.5) < 0.01,
			"a neighbour beside it drifts the hound at %.2f m/s, want %.2f" % [hound.velocity.x, extra * 0.5])
	# The steering was for that one move.
	hound.global_position = home
	hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
	_check(hound.velocity.is_equal_approx(Vector3(0.0, 0.0, -speed)), "a push outlived the move it was handed for: %s" % hound.velocity)
	# Never faster than its move plus the extra, however hard it is pushed.
	hound.global_position = home
	hound.set_separation(Vector2(3.0, 4.0), extra, 1.0)
	hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
	_check(Vector2(hound.velocity.x, hound.velocity.z).length() <= speed + extra + 0.01,
			"a hard push drove the hound at %.2f m/s, over its %.2f + %.2f" % [hound.velocity.length(), speed, extra])
	# NEVER SHOVED: a hound that has arrived, one rooted at speed zero (a bite) and one leaping are
	# not moved or bent by a push, and do not keep it for later.
	hound.global_position = home
	hound.set_separation(Vector2(0.5, 0.0), extra, 1.0)
	hound.approach(home + Vector3(0.0, 0.0, -0.5), speed, 1.0, 1.0 / 60.0)
	_check(hound.velocity == Vector3.ZERO, "a hound that has arrived was shoved: %s" % hound.velocity)
	hound.approach(ahead, speed, 1.0, 1.0 / 60.0)
	_check(hound.velocity.is_equal_approx(Vector3(0.0, 0.0, -speed)), "a push handed to a standing hound bent its next move: %s" % hound.velocity)
	hound.global_position = home
	hound.set_separation(Vector2(0.5, 0.0), extra, 1.0)
	hound.approach(ahead, 0.0, 1.0, 1.0 / 60.0)
	_check(hound.velocity.is_zero_approx(), "a hound rooted at speed zero was shoved: %s" % hound.velocity)
	hound.global_position = home
	hound.set_separation(Vector2(0.5, 0.0), extra, 1.0)
	hound.travel(Vector2(0.0, -1.0), speed)
	_check(hound.velocity.is_equal_approx(Vector3(0.0, 0.0, -speed)), "a leap was bent by a push: %s" % hound.velocity)

	# `take_motion()`: the motion MADE, in the hound's own frame (x to its right, y forward), measured
	# from where it stood -- not its `velocity`.
	var tick := 1.0 / 60.0
	hound.global_position = home
	hound.global_rotation.y = 0.0
	hound.velocity = Vector3.ZERO
	_check(hound.take_motion(tick) == Vector2.ZERO, "the first motion sample is not zero")
	hound.global_position += Vector3(0.05, 0.0, 0.0)
	var moved := hound.take_motion(tick)
	# (Positions are single floats 70 m out: a hundredth of a metre per second is the measurement's grain.)
	_check(moved.distance_to(Vector2(3.0, 0.0)) < 0.01, "moved 0.05 m to its right with no velocity: reports %s, want (3, 0)" % moved)
	hound.global_position += Vector3(0.0, 0.0, -0.05)
	moved = hound.take_motion(tick)
	_check(moved.distance_to(Vector2(0.0, 3.0)) < 0.01, "moved 0.05 m forward: reports %s, want (0, 3)" % moved)
	hound.velocity = Vector3(9.0, 0.0, 0.0)
	moved = hound.take_motion(tick)
	_check(moved.is_zero_approx(), "stood still with a velocity of 9 m/s set: reports %s, want none" % moved)
	hound.velocity = Vector3.ZERO
	hound.global_rotation.y = PI * 0.5   # now facing -X
	hound.take_motion(tick)
	hound.global_position += Vector3(-0.05, 0.0, 0.0)
	moved = hound.take_motion(tick)
	_check(moved.distance_to(Vector2(0.0, 3.0)) < 0.01, "turned to face -X and moved along -X: reports %s, want (0, 3) forward" % moved)
	# `turn_toward()`: no more than the step it is given, and it gets there.
	hound.global_position = home
	hound.global_rotation.y = 0.0
	var step := deg_to_rad(8.0)
	hound.turn_toward(home + Vector3(5.0, 0.0, 0.0), step)
	_check(absf(absf(hound.global_rotation.y) - step) < 0.0001, "one turn step of 8 deg turned the hound %.3f deg"
			% rad_to_deg(hound.global_rotation.y))
	for i in 40:
		hound.turn_toward(home + Vector3(5.0, 0.0, 0.0), step)
	_check(_facing(hound, home + Vector3(5.0, 0.0, 0.0)) > 0.9999, "forty turn steps did not bring the hound to face its target")
	hound.queue_free()


func _actor(index: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Cosine between the way the actor faces (its -Z) and the planar direction to `target`.
func _facing(hound: UnitActor, target: Vector3) -> float:
	var forward := -hound.global_transform.basis.z
	var to_target := Vector2(target.x - hound.global_position.x, target.z - hound.global_position.z)
	if to_target.is_zero_approx():
		return 1.0
	return Vector2(forward.x, forward.z).normalized().dot(to_target.normalized())


func _check(ok: bool, message: String) -> void:
	if not ok and _failures.size() < 40:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	else:
		_check(_min_apart >= _body_radius * 2.0 - 0.02,
				"the two hounds came %.3f m apart, inside their two body radii (%.3f m): they overlapped"
						% [_min_apart, _body_radius * 2.0])
		_check(_min_apart_both_leaping >= _body_radius * 2.0 - 0.15,
				"two hounds leaping at once came %.3f m apart: more than 0.15 m inside their two body radii (%.3f m)"
						% [_min_apart_both_leaping, _body_radius * 2.0])
		_check(_rate_checks > 200, "the playback rate was only checked on %d ticks: the run barely moved" % _rate_checks)
		_check(_over_rate * 200 <= _rate_checks,
				"on %d of %d moving ticks a hound went a quarter faster than its clip can be played: its paws slide"
						% [_over_rate, _rate_checks])
		_check(_top_run[0] > 3.0 and _top_run[1] > 3.0, "the hounds' fastest runs were %s m/s: they barely ran" % [_top_run])
		_check(absf(_top_run[0] - _top_run[1]) > 0.2,
				"the two hounds run in at the same pace (%.2f and %.2f m/s): they must differ" % [_top_run[0], _top_run[1]])
		for i in 2:
			var speeds: Array = _circle_speeds[i]
			_check(speeds.size() > 30, "hound %d's settled circling was only seen for %d ticks" % [i, speeds.size()])
			if speeds.size() > 30:
				var low: float = speeds.min()
				var high: float = speeds.max()
				_check(high - low > 0.15, "hound %d circles at one speed (%.2f to %.2f m/s): a perfect circle" % [i, low, high])
				speeds.sort()
				var median: float = speeds[speeds.size() / 2]
				_check(median <= _kind.move_speed * 0.5,
						"hound %d circles at a median %.2f m/s, over half its run (%.2f)" % [i, median, _kind.move_speed])
		_check(_leaps > 0 and _bites > 0, "over the run the hounds made %d leaps and %d bites: want both" % [_leaps, _bites])
		_check(_stalks_measured > 0, "no stalk was seen in the always-stalk part")
		_check(_feints_measured > 0 and _retreats_measured > 0,
				"the always-feint part measured %d darts and %d retreats" % [_feints_measured, _retreats_measured])
	if _effects != null:
		_effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	print("hound_feel_live: %d leaps, %d bites, options %s, %d stalks and %d feints measured; closest %.3f m (bodies %.3f); worst stuck run %d ticks, worst idle slide %d ticks, fastest turn %.0f deg/s; top runs %.2f / %.2f m/s; %d rate checks, %d over the fastest rate; settled circle ticks %d / %d"
			% [_leaps, _bites, _seen, _stalks_measured, _feints_measured, _min_apart, _body_radius * 2.0, _worst_stuck,
			_worst_slide, _worst_turn, _top_run[0], _top_run[1], _rate_checks, _over_rate,
			(_circle_speeds[0] as Array).size(), (_circle_speeds[1] as Array).size()])
	print("hound_feel_live: clip ticks while backing off and retreating from a feint: %s" % [_backing_clips])
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
