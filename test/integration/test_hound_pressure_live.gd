extends SceneTree

## Story 7-3, feel pass 2 (the operator's re-smoke, A and B): TWO HOUNDS AGAINST A HERO THAT MOVES, on
## the real runner, the shipped hound scene and the AUTHORED numbers. The operator's words: "too easy
## to avoid: just walking continuously, without running, and their attacks never touch the player";
## "always attack, back off, short circle, attack again".
##
## PART ONE, THE ACCEPTANCE (A5): four hero patterns, thirty seconds each, no defence. The hero is
## driven through the real P2 input actions. For every pattern the share of hound attacks that land
## is measured and held to a PROVISIONAL bar:
##     standing            at least 90%
##     walking, straight   at least 60%   (legs along X at walk speed, turning round at the wall)
##     walking, a circle   at least 50%   (a 7 m circle about the arena centre)
##     running             no bar: its rate is printed beside walking's (F3 ruling, see below)
## An attack counts for the pattern it BEGAN in; the pattern carries on for a second and a half after
## its thirty seconds so the last attacks can land or miss.
##
## THE SAME RUN measures the three things that changed (A1 to A3), as effects on the bodies:
##     THE LEAD        the heading state locks at windup start points AHEAD of a walking hero, along
##                     its velocity, by about its walk times the time to the strike -- never past the
##                     attack's authored cap -- and AT a standing one.
##     THE LUNGE       during the bite's ACTIVE window, and only then, the body goes forward along the
##                     locked heading, never further than the authored lunge, and that far when nothing
##                     is in its way.
##     LEAP THROUGH    the leap carries the body the distance to the point it aimed at plus the authored
##                     overshoot, inside the authored band: against a standing hero it LANDS PAST HIM.
##                     A leap begun close still travels its authored minimum.
##
## PART TWO, THE NEW BEHAVIOUR (B), each told to the live kind in this process so it is certain to be
## seen (which is drawn, and how often, is pinned in test/state/test_hellhound.gd):
##     REPOSITION      the hound goes round its target the way state drew, a real part of a lap, near its
##                     own radius, facing the way it runs.
##     RETREAT         it turns its back and goes away, never past the authored distance, and it is
##                     further out when the retreat ends than when it began.
##     RUN ON          after a leap it keeps the heading it landed on and covers ground along it.
##     PRESS           it attacks again with no back-off between: chains of two and three, never four.
##
## Run: godot --headless --path . --script res://test/integration/test_hound_pressure_live.gd

const HOUND_KIND := &"hellhound"
const SEED := 12345
const PATTERN_FRAMES := 1800
## 7-3 review fix (F3): walking and running run twice as long, so their printed rates rest on about twice
## the attacks (at least 30 each). The running-below-walking comparison was dropped by operator ruling.
const COMPARED_PATTERN_FACTOR := 2
const COMPARED_PATTERNS: Array[String] = ["walk", "run"]
const SETTLE_FRAMES := 90
const FORCED_FRAMES := 600
const PATTERNS: Array[String] = ["stand", "walk", "circle", "run"]
## Ticks a hound facing its target needs to turn onto its arc at the authored turn rate, with room.
const TURN_IN_TICKS := 25
## How many game seconds pass per wall second (see `_initialize`).
const SPEED_UP := 3

const A_IDLE := UnitBoard.AttackPhase.IDLE
const A_WINDUP := UnitBoard.AttackPhase.WINDUP
const A_ACTIVE := UnitBoard.AttackPhase.ACTIVE
const A_RECOVERY := UnitBoard.AttackPhase.RECOVERY
const B := UnitBoard.BehaviorPhase

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _kind: UnitKindProfile
var _kind_index := -1
var _failures: Array[String] = []

var _stage := -1            # index into PATTERNS, then the forced stages
var _stage_start := 0
var _leg := 1.0

## Per pattern: attacks begun, hits credited to them, by attack entry.
var _begun: Array = []
var _landed: Array = []
## Per hound: the pattern its current swing counts for (-1: none), whether a hit was credited to it.
var _swing_stage: Array[int] = [-1, -1]
var _swing_credited: Array[bool] = [true, true]
var _pending_hits: Array[float] = []

var _prev_attack: Array[int] = [A_IDLE, A_IDLE]
var _prev_behavior: Array[int] = [B.ENGAGE, B.ENGAGE]
var _prev_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _prev_yaw: Array[float] = [0.0, 0.0]
var _prev_hero := Vector3.ZERO
var _sampled := false

## The swing in progress, per hound.
var _swing_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_locked: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _swing_hero: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_reach: Array[float] = [0.0, 0.0]
var _active_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

## What was measured.
var _lead_walking: Array[float] = []   # per windup: sideways lead seen / sideways lead owed
var _lead_windups := 0
var _lead_over := 0
var _lead_standing: Array[float] = []
var _lunges: Array[float] = []
var _leaps_standing := 0
var _leaps_past := 0
var _close_leaps := 0
## Per leap at a standing hero that went its distance: the hero's place along the flight (reach /
## travel); and the same for the leaps whose overshoot the fraction set (not the floor).
var _landing_fractions: Array[float] = []
var _long_fractions: Array[float] = []
var _hero_speed: Array[float] = [0.0, 0.0, 0.0, 0.0]

## The forced stages.
var _phase_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _phase_angle: Array[float] = [0.0, 0.0]
var _phase_swept: Array[float] = [0.0, 0.0]
var _phase_distance: Array[float] = [0.0, 0.0]
var _phase_ticks: Array[int] = [0, 0]
var _phase_yaw: Array[float] = [0.0, 0.0]
var _phase_facing_motion: Array[int] = [0, 0]
var _phase_fast: Array[int] = [0, 0]
var _repositions := 0
var _retreats := 0
var _run_ons := 0
var _chain: Array[int] = [0, 0]
var _chains := {}

## The voices heard on the two hounds over the run.
var _heard_players := {}
var _heard := {}
var _heard_files := {}
var _heard_pitch: Array = [[], []]
var _most_sounding := 0
var _fastest_windup_turn := 0.0

## The orbit, in the always-orbit part: ticks per clip, ticks facing the hero, the longest seen.
var _orbit_clips := {}
var _orbit_run: Array[int] = [0, 0]
var _orbit_ticks := 0
var _orbit_facing := 0
var _longest_orbit := 0


func _initialize() -> void:
	# THE CLOCK RUNS THREE TIMES AS FAST AS THE WALL'S, AND THE GAME DOES NOT KNOW. Three times the
	# physics ticks a second at three times the time scale is the same sixtieth of a game second per
	# tick (the engine multiplies the step by the scale), so every tick is the tick it always was; two
	# and a half game minutes then take under a minute. Only the wall clock is traded: this file's
	# thirty seconds a pattern would otherwise outlast the suite's own time budget. Nothing here reads
	# the rig's playhead, which a faster wall clock advances in coarser steps.
	Engine.physics_ticks_per_second = 60 * SPEED_UP
	Engine.time_scale = float(SPEED_UP)
	Engine.max_physics_steps_per_frame = 8 * SPEED_UP
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.seed_override = SEED
	root.add_child(main)
	for pattern in PATTERNS:
		_begun.append([0, 0])
		_landed.append([0, 0])


func _on_hit(attacker_slot: int, target_slot: int, damage: float, _hp: float) -> void:
	if attacker_slot == 0 and target_slot == 1:
		_pending_hits.append(damage)


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
		if _kind == null or _kind.attacks.size() != 2:
			return _finish("authored balance carries no two-attack `hellhound` kind")
		_runner.connect_hit_landed(_on_hit)
		_check_lead_function()
		_check_actor_moves()
		_check_voice_playback()
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
		# Their summoner is put in a corner, out of every pattern's way.
		var corner: Vector3 = _runner._p1_hero.global_position
		_runner._p1_hero.global_position = Vector3(17.0, corner.y, 17.0)
		_prev_hero = _runner._p2_hero.global_position
		_enter(0)
		return false
	# The hero takes every hit and must not die: a round that ends freezes the hounds.
	if _state.p2.hero.get_hp() < 60.0:
		_state.p2.hero.heal(40.0)
	_steer()
	var hero: Vector3 = _runner._p2_hero.global_position
	if _stage < PATTERNS.size() and _frames - _stage_start <= _pattern_frames():
		_hero_speed[_stage] += _planar(hero, _prev_hero)
	_measure(0, first, hero)
	_measure(1, second, hero)
	_hear([first, second])
	_credit_hits()
	_sampled = true
	_prev_hero = hero
	var limit := _pattern_frames() + SETTLE_FRAMES if _stage < PATTERNS.size() else FORCED_FRAMES
	if _frames - _stage_start >= limit:
		if _stage + 1 >= PATTERNS.size() + 5:
			return _finish("")
		_enter(_stage + 1)
	return false


## Begin stage `stage`: a hero pattern, or one of the four forced behaviours.
func _enter(stage: int) -> void:
	_stage = stage
	_stage_start = _frames
	_release()
	if stage < PATTERNS.size():
		return
	# The forced stages: the hero stands; the live kind is told what to draw (this process only).
	for field: StringName in [&"circle_weight", &"stalk_weight", &"feint_weight", &"re_engage_weight",
			&"reposition_weight", &"retreat_weight", &"back_off_weight", &"press_weight", &"run_on_weight",
			&"orbit_weight"]:
		_kind.set(field, 0.0)
	match stage - PATTERNS.size():
		0:
			_kind.reposition_weight = 1.0
			_kind.back_off_weight = 1.0
		1:
			_kind.retreat_weight = 1.0
			_kind.back_off_weight = 1.0
			# At the authored numbers a retreat's own length brings the hound just up to the authored
			# distance; told a nearer one, it must STOP there with time to spare.
			_kind.retreat_distance = 5.0
		2:
			# Every attack a leap from range, every leap followed by a run-on.
			_kind.run_on_weight = 1.0
			_kind.re_engage_weight = 1.0
			_kind.leap_chance = 1.0
		3:
			_kind.press_weight = 1.0
			_kind.re_engage_weight = 1.0
			_kind.leap_chance = 0.5
		4:
			# Feel pass 3: every back-off ends in the long ORBIT.
			_kind.orbit_weight = 1.0
			_kind.back_off_weight = 1.0


## Press the P2 movement actions for this tick's pattern. The wanted direction is a WORLD direction,
## turned into the camera-space stick the state layer turns back.
func _steer() -> void:
	if _stage >= PATTERNS.size():
		return
	var world := Vector2.ZERO
	var here: Vector3 = _runner._p2_hero.global_position
	match PATTERNS[_stage]:
		"stand":
			return
		"walk", "run":
			if here.x > 13.0:
				_leg = -1.0
			elif here.x < -13.0:
				_leg = 1.0
			world = Vector2(_leg, 0.0)
		"circle":
			var from_centre := Vector2(here.x, here.z)
			var radius := from_centre.length()
			if radius < 0.01:
				world = Vector2(1.0, 0.0)
			else:
				var out := from_centre / radius
				world = (Vector2(-out.y, out.x) + out * clampf(7.0 - radius, -1.0, 1.0)).normalized()
	var basis: Basis = _state._camera_bases[1]
	var right := Vector3(1.0, 0.0, 0.0)
	var down := Vector3(0.0, 0.0, 1.0)
	if basis != Basis.IDENTITY:
		right = _state._camera_relative_dir(Vector2(1.0, 0.0), basis)
		down = _state._camera_relative_dir(Vector2(0.0, 1.0), basis)
	var stick := Vector2(world.x * right.x + world.y * right.z, world.x * down.x + world.y * down.z)
	_press(&"p2_move_right", maxf(stick.x, 0.0))
	_press(&"p2_move_left", maxf(-stick.x, 0.0))
	_press(&"p2_move_down", maxf(stick.y, 0.0))
	_press(&"p2_move_up", maxf(-stick.y, 0.0))
	if PATTERNS[_stage] == "run":
		Input.action_press(&"p2_run")


## How many frames the current hero pattern is counted for (see `COMPARED_PATTERN_FACTOR`).
func _pattern_frames() -> int:
	if _stage < PATTERNS.size() and COMPARED_PATTERNS.has(PATTERNS[_stage]):
		return PATTERN_FRAMES * COMPARED_PATTERN_FACTOR
	return PATTERN_FRAMES


func _press(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release() -> void:
	for action: StringName in [&"p2_move_right", &"p2_move_left", &"p2_move_down", &"p2_move_up", &"p2_run"]:
		Input.action_release(action)


## One tick of one hound. The test's callback runs BEFORE the runner's in a frame, so everything read
## here is the frame that just ended.
func _measure(i: int, hound: UnitActor, hero: Vector3) -> void:
	var units := _state.p1.units
	var here := hound.global_position
	var yaw := hound.global_rotation.y
	var attack := units.attack_phase_at(i)
	var behavior := units.behavior_phase_at(i)
	if not _sampled:
		_prev_pos[i] = here
		_prev_yaw[i] = yaw
		_prev_attack[i] = attack
		_prev_behavior[i] = behavior
		return
	var before := _prev_pos[i]
	var choice := units.attack_choice_at(i)
	var swing := _kind.attack_at(choice)
	var hero_velocity := Vector2(hero.x - _prev_hero.x, hero.z - _prev_hero.z) * 60.0
	var pattern := PATTERNS[_stage] if _stage < PATTERNS.size() else "forced"
	var counting := _stage < PATTERNS.size() and _frames - _stage_start <= _pattern_frames()

	if attack != _prev_attack[i]:
		match attack:
			A_WINDUP:
				_swing_stage[i] = _stage if counting else -1
				_swing_credited[i] = false
				if counting:
					_begun[_stage][choice] += 1
				_chain[i] += 1
				_swing_from[i] = here
				_swing_locked[i] = units.attack_dir_at(i)
				_swing_hero[i] = _prev_hero
				_swing_reach[i] = _planar(here, _prev_hero)
				# THE LEAD. The locked heading is carried out to the hero's distance; how far that
				# point lies to the hero's side is compared with how far he will have gone SIDEWAYS
				# (across the hound's line to him) when the strike lands. Sideways only: a lead along
				# the line itself does not turn the heading and cannot be seen in it.
				if _swing_locked[i].length() > 0.5 and _swing_reach[i] > 0.3:
					var to_hero := Vector2(_prev_hero.x - here.x, _prev_hero.z - here.z).normalized()
					var across := Vector2(-to_hero.y, to_hero.x)
					var aim := Vector2(here.x, here.z) + _swing_locked[i].normalized() * _swing_reach[i]
					var off := aim - Vector2(_prev_hero.x, _prev_hero.z)
					if pattern == "stand" or pattern == "forced":
						_lead_standing.append(off.length())
					elif pattern != "run" and hero_velocity.length() > 1.8 \
							and absf(hero_velocity.dot(across)) > 1.2:
						var lead := minf(hero_velocity.length() * (swing.windup_seconds + 0.5 * swing.active_seconds),
								swing.lead_max_distance)
						var sideways := lead * hero_velocity.dot(across) / hero_velocity.length()
						_lead_walking.append(off.dot(across) / sideways)
						_lead_windups += 1
						if off.length() > swing.lead_max_distance + 0.45:
							_lead_over += 1
			A_ACTIVE:
				_check(_planar(before, _swing_from[i]) < 0.05,
						"hound %d moved %.3f m during the windup of attack %d (rooted)" % [i, _planar(before, _swing_from[i]), choice])
				_active_from[i] = before
			A_RECOVERY:
				_on_swing_landed(i, here, choice, swing, pattern)
				_swing_from[i] = here
			A_IDLE:
				if _prev_attack[i] == A_RECOVERY:
					_check(_planar(before, _swing_from[i]) < 0.05,
							"hound %d moved %.3f m during the recovery of attack %d (rooted)"
									% [i, _planar(before, _swing_from[i]), choice])

	# TURNING ONTO THE LOCKED HEADING: through its windup the body turns at the kind's authored rate,
	# never faster (it does not flip round on the windup's first tick); in its recovery it does not
	# turn at all (it keeps the heading it struck along).
	var turned := rad_to_deg(absf(angle_difference(_prev_yaw[i], yaw))) * 60.0
	if attack == A_WINDUP:
		_fastest_windup_turn = maxf(_fastest_windup_turn, turned)
		_check(turned <= _kind.turn_rate_degrees_per_second + 1.0,
				"hound %d turned at %.0f deg/s in its windup, over the authored %.0f (frame %d)"
						% [i, turned, _kind.turn_rate_degrees_per_second, _frames])
	elif attack == A_RECOVERY and _prev_attack[i] == A_RECOVERY:
		_check(turned < 1.0, "hound %d turned at %.0f deg/s in its recovery (frame %d)" % [i, turned, _frames])

	if behavior != _prev_behavior[i]:
		_on_phase_change(i, hound, _prev_behavior[i], behavior, before, hero)
	_track_phase(i, hound, behavior, here, hero)

	_prev_pos[i] = here
	_prev_yaw[i] = yaw
	_prev_attack[i] = attack
	_prev_behavior[i] = behavior


## The ACTIVE window of hound `i`'s swing has just closed: how far, and which way, it carried the body.
func _on_swing_landed(i: int, here: Vector3, choice: int, swing: UnitAttackProfile, pattern: String) -> void:
	var moved := Vector2(here.x - _active_from[i].x, here.z - _active_from[i].z)
	var locked := _swing_locked[i].normalized()
	if choice == 0:
		# THE LUNGE.
		_lunges.append(moved.length())
		_check(moved.length() <= swing.travel_max_distance + 0.03,
				"a bite lunged %.3f m, past the authored %.2f (frame %d)" % [moved.length(), swing.travel_max_distance, _frames])
		# A lunge its target's body stopped short slid along that body; a full one went straight.
		if moved.length() > swing.travel_max_distance - 0.05:
			_check(moved.normalized().dot(locked) > 0.98,
					"a full lunge did not go along its locked heading (cos %.3f, frame %d)" % [moved.normalized().dot(locked), _frames])
		return
	# LEAP THROUGH.
	_check(moved.length() <= swing.travel_max_distance + 0.05,
			"a leap carried the hound %.3f m, past the authored maximum %.2f (frame %d)" % [moved.length(), swing.travel_max_distance, _frames])
	if moved.length() > 0.5:
		_check(moved.normalized().dot(locked) > 0.9,
				"a leap did not follow its locked heading (cos %.3f, frame %d)" % [moved.normalized().dot(locked), _frames])
	if pattern != "stand" and pattern != "forced":
		return
	# Against a standing hero the point aimed at is the hero. The travel is the distance to him as the
	# windup began plus the overshoot, inside the band -- unless a wall or the other hound stopped it.
	# Feel pass 3: the overshoot is a share of the distance, never under its authored floor.
	var reach := _swing_reach[i]
	var overshoot := swing.travel_overshoot
	if swing.travel_overshoot_fraction > 0.0:
		overshoot = maxf(overshoot, reach * swing.travel_overshoot_fraction)
	var want := clampf(reach + overshoot, swing.travel_min_distance, swing.travel_max_distance)
	_leaps_standing += 1
	if absf(moved.length() - want) < 0.2:
		var past := Vector2(here.x - _swing_hero[i].x, here.z - _swing_hero[i].z).dot(locked)
		# WHERE THE STANDING HERO SITS ALONG THE FLIGHT: 0 at take-off, 1 at the landing.
		var fraction := reach / moved.length()
		_landing_fractions.append(fraction)
		if reach + overshoot <= swing.travel_max_distance:
			_check(past > swing.travel_overshoot - 0.2,
					"a leap begun %.2f m from a standing hero landed %.2f m past him, want at least the authored %.2f (frame %d)"
							% [reach, past, swing.travel_overshoot, _frames])
			if past > 0.5:
				_leaps_past += 1
		# THE OPERATOR'S BAND: the hero sits at 0.72 to 0.82 of the flight -- for every leap begun far
		# enough out that the floor (the overshoot that lands the hound clear of his body) allows it:
		# from `floor / (1 / 0.72 - 1)` metres. A leap begun closer lands the floor past him.
		if swing.travel_overshoot_fraction > 0.0 and reach >= swing.travel_overshoot / (1.0 / 0.72 - 1.0):
			_long_fractions.append(fraction)
			_check(fraction >= 0.72 and fraction <= 0.82,
					"a leap begun %.2f m from a standing hero has him at %.2f of its flight, want 0.72 to 0.82 (frame %d)"
							% [reach, fraction, _frames])
		else:
			_close_leaps += 1


## Give each hit the drain announced to the swing that made it: a hound whose current swing has not
## been credited and whose attack deals that damage.
func _credit_hits() -> void:
	var units := _state.p1.units
	for damage: float in _pending_hits:
		for i in 2:
			if _swing_credited[i] or units.attack_phase_at(i) == A_IDLE and _prev_attack[i] == A_IDLE:
				continue
			var choice := units.attack_choice_at(i)
			if absf(_kind.attack_at(choice).damage - damage) > 0.01:
				continue
			_swing_credited[i] = true
			if _swing_stage[i] >= 0:
				_landed[_swing_stage[i]][choice] += 1
			break
	_pending_hits.clear()


## A hound left `from` for `to`: close the measurement of the phase that ended, open the next.
func _on_phase_change(i: int, hound: UnitActor, from: int, to: int, at: Vector3, hero: Vector3) -> void:
	var forced := _stage - PATTERNS.size()
	var distance := _planar(at, hero)
	match from:
		B.REPOSITION:
			if forced == 0 and _phase_ticks[i] >= 60:
				_repositions += 1
				var swept := _phase_swept[i] * float(_state.p1.units.circle_dir_at(i))
				var radius: float = _runner._circle_radius(_kind, 0, i, 0, 0)
				var pace := _kind.move_speed * _kind.reposition_move_speed_multiplier
				# It turns onto its arc before it runs along it: the first ticks are a turn.
				var expected := pace * float(_phase_ticks[i] - TURN_IN_TICKS) / 60.0 / radius
				_check(swept > 0.5 * expected,
						"a reposition of %d ticks swept %.2f rad round the target the drawn way, want most of %.2f"
								% [_phase_ticks[i], swept, expected])
				_check(absf(distance - radius) < 1.2,
						"a reposition ended %.2f m from its target, its radius is %.2f" % [distance, radius])
				_check(_phase_facing_motion[i] * 10 >= _phase_fast[i] * 8,
						"a repositioning hound faced the way it ran on %d of %d fast ticks: it ran sideways"
								% [_phase_facing_motion[i], _phase_fast[i]])
		B.RETREAT:
			if forced == 1:
				_retreats += 1
				_check(distance > _phase_distance[i] + 0.8 or _phase_distance[i] > _kind.retreat_distance - 1.2,
						"a retreat of %d ticks took the hound from %.2f m to %.2f m: it did not go away"
								% [_phase_ticks[i], _phase_distance[i], distance])
				_check(distance <= _kind.retreat_distance + 0.25,
						"a retreating hound ended %.2f m out, past the authored %.2f" % [distance, _kind.retreat_distance])
				_check(_phase_facing_motion[i] * 10 >= _phase_fast[i] * 8,
						"a retreating hound faced the way it went on %d of %d fast ticks: it went backwards"
								% [_phase_facing_motion[i], _phase_fast[i]])
		B.RUN_ON:
			if forced == 2:
				_run_ons += 1
				var ran := _planar(at, _phase_from[i])
				var want := _kind.move_speed * _kind.run_on_move_speed_multiplier * float(_phase_ticks[i]) / 60.0
				_check(ran > 0.5 * want or _near_wall(at),
						"a run-on of %d ticks covered %.2f m, want most of %.2f" % [_phase_ticks[i], ran, want])
				_check(absf(angle_difference(_phase_yaw[i], _prev_yaw[i])) < 0.02 or _near_wall(at),
						"a hound running on turned %.3f rad: it must keep the heading it landed on"
								% absf(angle_difference(_phase_yaw[i], _prev_yaw[i])))
	if to == B.BACK_OFF or to == B.REACT or to == B.RUN_ON:
		if _chain[i] > 0 and forced == 3:
			_chains[_chain[i]] = int(_chains.get(_chain[i], 0)) + 1
		_chain[i] = 0
	_phase_from[i] = at
	_phase_angle[i] = _angle(at, hero)
	_phase_swept[i] = 0.0
	_phase_distance[i] = distance
	_phase_ticks[i] = 0
	_phase_yaw[i] = _prev_yaw[i]
	_phase_facing_motion[i] = 0
	_phase_fast[i] = 0


## Every tick of a phase: how long it has lasted, and whether a fast-moving body faces its motion.
func _track_phase(i: int, hound: UnitActor, behavior: int, here: Vector3, hero: Vector3) -> void:
	_phase_ticks[i] += 1
	# THE ORBIT (feel pass 3), in the always-orbit part: which clip the rig plays, tick by tick, once
	# the hound has had a quarter of a second to turn onto its circle; how long the longest one lasted;
	# and that it faces its target, as a circle does.
	if _stage - PATTERNS.size() == 4 and (behavior == B.ORBIT or behavior == B.ORBIT_TURN) \
			and _state.p1.units.attack_phase_at(i) == A_IDLE:
		_orbit_run[i] += 1
		_longest_orbit = maxi(_longest_orbit, _orbit_run[i])
		if _orbit_run[i] > 15:
			var clip := String(hound.animation.animation_player.current_animation)
			_orbit_clips[clip] = int(_orbit_clips.get(clip, 0)) + 1
			var ahead := -hound.global_transform.basis.z
			var to_hero := Vector2(hero.x - here.x, hero.z - here.z).normalized()
			_orbit_ticks += 1
			if Vector2(ahead.x, ahead.z).normalized().dot(to_hero) > 0.9:
				_orbit_facing += 1
	else:
		_orbit_run[i] = 0
	# The bearing swept round the target, summed tick by tick (a lap is more than a half-turn).
	var bearing := _angle(here, hero)
	_phase_swept[i] += angle_difference(_phase_angle[i], bearing)
	_phase_angle[i] = bearing
	var moved := Vector2(here.x - _prev_pos[i].x, here.z - _prev_pos[i].z) * 60.0
	if behavior == B.REPOSITION or behavior == B.RETREAT:
		_check(_state.p1.units.attack_phase_at(i) == A_IDLE,
				"a hound in behaviour %d is in attack phase %d (frame %d)" % [behavior, _state.p1.units.attack_phase_at(i), _frames])
		var forward := -hound.global_transform.basis.z
		var facing := Vector2(forward.x, forward.z).normalized()
		if moved.length() > 1.5:
			_phase_fast[i] += 1
			if facing.dot(moved.normalized()) > 0.7:
				_phase_facing_motion[i] += 1
		# IT TURNS, THEN GOES: it is never much faster than its pace for this phase times how far it
		# faces the way it moves. (With room: the two are a tick apart, and a hound spiralling onto its
		# radius at part speed moves more outward than the full-speed heading it is turning onto --
		# seen, 1.4 m/s square to its facing for a few ticks. Away from the other hound, whose
		# nearness steers it.)
		var other := _actor(1 - i)
		if _phase_ticks[i] > 2 and moved.length() > 0.5 and other != null \
				and _planar(here, other.global_position) > _kind.separation_distance + 0.3:
			var pace := _kind.move_speed * UnitTemperament.factor(0, i, UnitTemperament.CHANNEL_SPEED,
					_kind.temperament_speed_spread) * (_kind.reposition_move_speed_multiplier
					if behavior == B.REPOSITION else _kind.retreat_move_speed_multiplier)
			var allowed := pace * maxf(facing.dot(moved.normalized()), 0.0) + 1.8
			_check(moved.length() <= allowed,
					"a hound in behaviour %d moved at %.2f m/s while facing only %.2f of the way it went: it must turn first (frame %d)"
							% [behavior, moved.length(), facing.dot(moved.normalized()), _frames])
	# (Against the standing hero of the forced part: a hero walking away widens the gap himself.)
	if behavior == B.RETREAT and _stage >= PATTERNS.size():
		_check(_planar(here, hero) <= _kind.retreat_distance + 0.25 or _phase_distance[i] > _kind.retreat_distance,
				"a retreating hound is %.2f m out, past the authored %.2f (frame %d)" % [_planar(here, hero), _kind.retreat_distance, _frames])


## THE LEAD, on the runner's own function, with the two heroes' velocities set by hand: the led point
## is the target's position plus its velocity times the time to the middle of the ACTIVE window, the
## lead never longer than the attack's cap; a standing target and an attack that leads nothing give
## the position itself.
func _check_lead_function() -> void:
	var hero: CharacterBody3D = _runner._p2_hero
	var at := hero.global_position
	var zombie := _state.balance.kind_at(_state.balance.kind_index_of(&"minion")).attack_at(0)
	var kept := hero.velocity
	for choice in 2:
		var attack := _kind.attack_at(choice)
		var to_strike := attack.windup_seconds + 0.5 * attack.active_seconds
		hero.velocity = Vector3.ZERO
		_check(_runner._led_target_position(1, -1, at, attack).is_equal_approx(at),
				"attack %d leads a standing target" % choice)
		hero.velocity = Vector3(1.0, 0.0, 0.0)
		var slow: Vector3 = _runner._led_target_position(1, -1, at, attack)
		_check(slow.is_equal_approx(at + Vector3(to_strike, 0.0, 0.0)),
				"attack %d leads a target moving at 1 m/s by %s, want %.3f m along its velocity" % [choice, slow - at, to_strike])
		hero.velocity = Vector3(0.0, 3.0, -40.0)
		var fast: Vector3 = _runner._led_target_position(1, -1, at, attack)
		_check((fast - at).is_equal_approx(Vector3(0.0, 0.0, -attack.lead_max_distance)),
				"attack %d leads a target moving at 40 m/s by %s, want its cap %.2f m, planar"
						% [choice, fast - at, attack.lead_max_distance])
		_check(attack.lead_max_distance > 0.0, "the hound's attack %d authors no lead" % choice)
	hero.velocity = Vector3(3.0, 0.0, 0.0)
	_check(_runner._led_target_position(1, -1, at, zombie).is_equal_approx(at),
			"an attack that authors no lead (the zombie's) was led")
	hero.velocity = kept


## THE ACTOR'S NEW MOVES, on one hound scene standing alone far from the arena.
func _check_actor_moves() -> void:
	var hound := (load("res://src/actors/minions/hound_actor.tscn") as PackedScene).instantiate() as UnitActor
	var other := (load("res://src/actors/minions/hound_actor.tscn") as PackedScene).instantiate() as UnitActor
	root.add_child(hound)
	root.add_child(other)
	var home := Vector3(70.0, 0.0, 70.0)
	hound.global_position = home
	other.global_position = home + Vector3(30.0, 0.0, 0.0)
	# The swing's travel is held for the swing it was fixed for, and for no other.
	_check(not hound.swing_travel_is_for(1) and hound.swing_travel(1) == 0.0, "a fresh actor holds a swing's travel")
	hound.set_swing_travel(4, 3.25)
	_check(hound.swing_travel_is_for(4) and hound.swing_travel(4) == 3.25, "the travel fixed for swing 4 reads %.2f" % hound.swing_travel(4))
	_check(hound.swing_travel(5) == 0.0, "swing 5 reads swing 4's travel")
	hound.set_swing_travel(5, -1.0)
	_check(hound.swing_travel(5) == 0.0, "a negative travel was kept")
	# Facing and turning onto a heading.
	hound.global_rotation.y = 0.0   # facing -Z
	_check(absf(hound.alignment_with(Vector2(0.0, -1.0)) - 1.0) < 0.001, "facing its heading, alignment is not 1")
	_check(hound.alignment_with(Vector2(1.0, 0.0)) < 0.001, "square to its heading, alignment is not 0")
	_check(hound.alignment_with(Vector2(0.0, 1.0)) == 0.0, "turned away from its heading, alignment is not 0")
	_check(hound.alignment_with(Vector2.ZERO) == 1.0, "with no heading, alignment is not 1")
	var step := deg_to_rad(8.0)
	hound.turn_along(Vector2(1.0, 0.0), step)
	_check(absf(absf(hound.global_rotation.y) - step) < 0.0001, "one turn step of 8 deg onto a heading turned the hound %.3f deg"
			% rad_to_deg(hound.global_rotation.y))
	for n in 40:
		hound.turn_along(Vector2(1.0, 0.0), step)
	_check(hound.alignment_with(Vector2(1.0, 0.0)) > 0.9999, "forty turn steps did not bring the hound onto its heading")
	var yaw := hound.global_rotation.y
	hound.turn_along(Vector2.ZERO, step)
	_check(hound.global_rotation.y == yaw, "a zero heading turned the hound")
	# Running ahead: along its own facing (now +X), at the speed given; nothing at speed zero.
	hound.global_position = home
	hound.run_ahead(4.0)
	_check(hound.velocity.is_equal_approx(Vector3(4.0, 0.0, 0.0)), "run_ahead(4) facing +X is %s" % hound.velocity)
	hound.run_ahead(0.0)
	_check(hound.velocity == Vector3.ZERO, "run_ahead(0) moves")
	# Passing: each body is the other's exception while it lasts, and neither afterwards.
	var bodies: Array[PhysicsBody3D] = [other]
	_check(not hound.is_passing(), "a fresh actor is passing")
	hound.start_passing(bodies)
	_check(hound.is_passing(), "start_passing did not start")
	_check(hound.get_collision_exceptions().has(other) and other.get_collision_exceptions().has(hound),
			"a passing hound and the body it passes are not each other's collision exception")
	hound.stop_passing()
	_check(not hound.is_passing() and hound.get_collision_exceptions().is_empty()
			and other.get_collision_exceptions().is_empty(), "stop_passing left an exception behind")
	hound.queue_free()
	other.queue_free()


## THE HOUNDS' VOICES, LIVE (finding D): every positional player on either hound, the first time it is
## seen -- which voice it is (by its file), on which hound, at what pitch -- and, every tick, how many
## voices that count toward the row's cap are sounding at once.
func _hear(hounds: Array) -> void:
	var sounding := 0
	for i in hounds.size():
		for child: Node in (hounds[i] as Node).get_children():
			var player := child as AudioStreamPlayer3D
			if player == null or player.stream == null:
				continue
			var voice := player.stream.resource_path.get_file().trim_prefix("hound_").get_slice("_", 0)
			if player.playing and not EffectPresentationSet.UNCAPPED_VOICES.has(StringName(voice)):
				sounding += 1
			if _heard_players.has(player.get_instance_id()):
				continue
			_heard_players[player.get_instance_id()] = true
			_heard[voice] = int(_heard.get(voice, 0)) + 1
			(_heard_pitch[i] as Array).append(player.pitch_scale)
			_heard_files[player.stream.resource_path.get_file()] = true
	_most_sounding = maxi(_most_sounding, sounding)


## THE PRESENTER'S VOICE PLAYBACK, on two hound scenes standing alone: the variant asked for (wrapping),
## the pitch given, the row's volume and distance; a voice with no variant plays nothing; and the cap --
## at most `voice_cap` capped voices at once, which an uncapped voice neither counts toward nor obeys.
func _check_voice_playback() -> void:
	var row := _effects.row(HOUND_KIND)
	if row == null:
		_check(false, "the presenter has no `hellhound` row")
		return
	var at := (load("res://src/actors/minions/hound_actor.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(at)
	at.global_position = Vector3(-70.0, 0.0, -70.0)
	_check(_effects.voice_variants(HOUND_KIND, &"growl").size() == 3, "the growl has %d variants"
			% _effects.voice_variants(HOUND_KIND, &"growl").size())
	_check(_effects.voice_variants(HOUND_KIND, &"yelp").is_empty(), "the yelp has a variant: no file was supplied for it")
	var streams := {}
	for variant in 6:
		var player := _effects.play_voice_at(HOUND_KIND, &"growl", at, variant, 0.9 + 0.01 * variant, false)
		_check(player != null, "an uncapped growl was not played")
		if player == null:
			continue
		streams[player.stream.resource_path] = int(streams.get(player.stream.resource_path, 0)) + 1
		_check(player.get_parent() == at, "a voice is not parented to the creature that makes it")
		_check(absf(player.pitch_scale - (0.9 + 0.01 * variant)) < 0.0001, "a voice plays at pitch %.3f, was given %.3f"
				% [player.pitch_scale, 0.9 + 0.01 * variant])
		_check(player.volume_db == float(row.volume_db[&"growl"]), "the growl plays at %.1f dB, the row says %.1f"
				% [player.volume_db, float(row.volume_db[&"growl"])])
		_check(player.max_distance == row.knob(&"voice_distance", -1.0), "a voice fades at %.1f m, the row says %.1f"
				% [player.max_distance, row.knob(&"voice_distance", -1.0)])
	_check(streams.size() == 3 and streams.values().min() == 2,
			"six plays, variants 0 to 5, used the files %s: want each of the three twice" % [streams])
	_effects.stop_all_sounds()
	# The cap. (A stopped voice no longer counts.)
	var cap := int(row.knob(&"voice_cap", 0.0))
	var capped: Array = []
	for n in cap:
		capped.append(_effects.play_voice_at(HOUND_KIND, &"growl" if n % 2 == 0 else &"bark", at, n, 1.0, true))
		_check(capped[n] != null, "capped voice %d of %d was refused" % [n + 1, cap])
	_check(_effects.play_voice_at(HOUND_KIND, &"leap", at, 0, 1.0, true) == null,
			"a capped voice played while %d were already sounding" % cap)
	_check(_effects.play_voice_at(HOUND_KIND, &"death", at, 0, 1.0, true) == null,
			"a second capped voice played over the cap")
	_check(_effects.play_voice_at(HOUND_KIND, &"bite", at, 0, 1.0, false) != null,
			"the bite's snap (uncapped) was refused while the cap was full")
	_check(_effects.play_voice_at(HOUND_KIND, &"leap", at, 0, 1.0, true) == null,
			"an uncapped voice made room under the cap")
	if not capped.is_empty() and capped[0] != null:
		(capped[0] as AudioStreamPlayer3D).stop()
		_check(_effects.play_voice_at(HOUND_KIND, &"leap", at, 0, 1.0, true) != null,
				"a capped voice was refused after one of the sounding ones had stopped")
	# No variant, no sound; and an unknown voice is not played.
	var before := _effects.played.size()
	_check(_effects.play_voice_at(HOUND_KIND, &"yelp", at, 0, 1.0, false) == null, "the yelp, which has no file, played something")
	_check(_effects.play_voice_at(HOUND_KIND, &"howl", at, 0, 1.0, false) == null, "a voice the row does not have was played")
	_check(_effects.played.size() == before, "a voice that played nothing was recorded as played")
	_effects.stop_all_sounds()
	at.queue_free()


func _near_wall(at: Vector3) -> bool:
	return absf(at.x) > 17.5 or absf(at.z) > 17.5


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


## The hound's bearing from its target, the angle a clockwise circle (seen from above) increases.
func _angle(hound_position: Vector3, target: Vector3) -> float:
	return atan2(hound_position.z - target.z, hound_position.x - target.x)


func _rate(stage: int) -> float:
	var begun: int = _begun[stage][0] + _begun[stage][1]
	return 100.0 * float(_landed[stage][0] + _landed[stage][1]) / float(maxi(begun, 1))


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _check(ok: bool, message: String) -> void:
	if not ok and _failures.size() < 40:
		_failures.append(message)


func _finish(error: String) -> bool:
	_release()
	if error != "":
		_failures.append(error)
	else:
		for stage in PATTERNS.size():
			_check(_begun[stage][0] + _begun[stage][1] >= 8,
					"pattern '%s': only %d attacks began in thirty seconds" % [PATTERNS[stage], _begun[stage][0] + _begun[stage][1]])
		# THE ACCEPTANCE BARS (provisional).
		_check(_rate(0) >= 90.0, "standing: %.1f%% of hound attacks hit, want at least 90%%" % _rate(0))
		_check(_rate(1) >= 60.0, "walking in a straight line: %.1f%% of hound attacks hit, want at least 60%%" % _rate(1))
		_check(_rate(2) >= 50.0, "walking in a circle: %.1f%% of hound attacks hit, want at least 50%%" % _rate(2))
		# F3: the comparison is only worth making on a sample worth comparing (about 40 each at the authored
		# doubling); a thin pair would pass or fail on noise.
		for compared in [1, 3]:
			_check(_begun[compared][0] + _begun[compared][1] >= 30,
					"pattern '%s': only %d attacks began; the printed walking/running rates need at least 30 each"
							% [PATTERNS[compared], _begun[compared][0] + _begun[compared][1]])
		# F3 RULING (operator, 7-3 review fix): with the larger sample running is not an escape from hounds
		# (85% against 88%); by design the answers are block, deflect and roll. So there is NO
		# running-below-walking comparison; both rates are printed instead.
		print("hound_pressure_live: hit rate walking %.1f%% (%d attacks), running %.1f%% (%d attacks)"
				% [_rate(1), _begun[1][0] + _begun[1][1], _rate(3), _begun[3][0] + _begun[3][1]])
		# THE LEAD.
		_check(_lead_walking.size() >= 4, "only %d windups against a hero walking across the hound's line were measured" % _lead_walking.size())
		_check(_mean(_lead_walking) > 0.6 and _mean(_lead_walking) < 1.4,
				"against a walking hero the locked heading leads him sideways by a mean %.2f of what he will cover by the strike, want about 1 (0.6 to 1.4)"
						% _mean(_lead_walking))
		_check(_lead_over * 10 <= _lead_windups,
				"%d of %d windups against a walking hero were aimed further from him than the attack's lead cap allows"
						% [_lead_over, _lead_windups])
		# AND THE HEADING IS FRESH. A hound that leads probes on every tick it could begin a windup, so
		# the direction it locks is a tick or two old; on the reach-probe throttle alone it is up to a
		# fifth of a second old, and a hound still running in has by then moved off the line it locked
		# (measured: a mean 0.06 m off a standing hero, against 0.01).
		_check(_lead_standing.size() >= 10 and _mean(_lead_standing) < 0.03,
				"against a standing hero the locked heading is a mean %.3f m off him (%d windups), want under 0.03: it is stale"
						% [_mean(_lead_standing), _lead_standing.size()])
		# THE LUNGE.
		var lunge := _kind.attack_at(0).travel_max_distance
		_check(_lunges.size() >= 10 and (_lunges.max() as float) > lunge - 0.05,
				"over %d bites the longest lunge was %.3f m, want the authored %.2f when nothing is in the way"
						% [_lunges.size(), (_lunges.max() as float) if not _lunges.is_empty() else 0.0, lunge])
		_check(_mean(_lunges) > 0.15, "the bites lunged a mean %.3f m: they barely move" % _mean(_lunges))
		# LEAP THROUGH.
		_check(_leaps_standing >= 5 and _leaps_past >= 3,
				"of %d leaps at a standing hero only %d were seen landing past him" % [_leaps_standing, _leaps_past])
		# THE NEW BEHAVIOUR.
		_check(_repositions >= 2, "the always-reposition part measured %d repositions" % _repositions)
		_check(_retreats >= 2, "the always-retreat part measured %d retreats" % _retreats)
		_check(_run_ons >= 2, "the always-run-on part measured %d run-ons" % _run_ons)
		var longest := 0
		for length: int in _chains:
			longest = maxi(longest, length)
		# THE ORBIT: longer than any circle, facing the hero, and on the strafes.
		var strafes := 0
		for clip: String in ["walk_left", "walk_right", "run_left", "run_right"]:
			strafes += int(_orbit_clips.get(clip, 0))
		var circle_max: int = _state.balance_ticks.kind_ticks_at(_kind_index).circle_max_ticks
		_check(_longest_orbit > circle_max + 30,
				"the always-orbit part's longest orbit was %d ticks: no longer than a circle (%d)" % [_longest_orbit, circle_max])
		_check(_orbit_ticks >= 200 and strafes * 10 >= _orbit_ticks * 7,
				"an orbiting hound played a strafe on %d of %d ticks: the strafes must dominate (%s)" % [strafes, _orbit_ticks, _orbit_clips])
		_check(_orbit_facing * 10 >= _orbit_ticks * 9,
				"an orbiting hound faced its target on %d of %d ticks" % [_orbit_facing, _orbit_ticks])
		_check(int(_chains.get(3, 0)) >= 1 and longest == 3,
				"the always-press part saw attack chains %s: want chains of three and none longer" % [_chains])
		_check(_fastest_windup_turn > 100.0,
				"no hound was ever seen turning onto its heading in a windup (fastest %.0f deg/s)" % _fastest_windup_turn)
		# THE VOICES (D): each heard, each hound in its own; never more than the cap at once.
		var row := _effects.row(HOUND_KIND)
		for voice: String in ["growl", "bark", "bite", "leap"]:
			_check(int(_heard.get(voice, 0)) > 0, "over the whole run no hound was heard to %s: %s" % [voice, _heard])
		_check(not _heard.has("yelp"), "a yelp was heard: there is no file for it")
		_check(_heard_files.size() >= 8, "only %d different voice files were heard: the variants are not used" % _heard_files.size())
		_check(_most_sounding <= int(row.knob(&"voice_cap", 0.0)),
				"%d capped hound voices sounded at once, over the row's cap of %d" % [_most_sounding, int(row.knob(&"voice_cap", 0.0))])
		var spread := row.knob(&"voice_pitch_spread", 0.0)
		var variation := row.knob(&"voice_pitch_variation", 0.0)
		var means: Array[float] = []
		for i in 2:
			var pitches: Array[float] = []
			pitches.assign(_heard_pitch[i])
			means.append(_mean(pitches))
			var own := UnitTemperament.factor(0, i, UnitTemperament.CHANNEL_VOICE, spread)
			for pitch: float in pitches:
				_check(absf(pitch / own - 1.0) <= variation + 0.0001,
						"hound %d voiced at pitch %.3f, more than %.2f off its own %.3f" % [i, pitch, variation, own])
			_check(pitches.size() >= 10 and (pitches.max() as float) - (pitches.min() as float) > 0.3 * variation,
					"hound %d's %d voices do not vary in pitch from play to play" % [i, pitches.size()])
		_check(absf(means[0] - means[1]) > 0.03,
				"the two hounds voice at the same pitch (means %.3f and %.3f): each has its own" % [means[0], means[1]])
	if _effects != null:
		_effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	for stage in PATTERNS.size():
		print("hound_pressure_live: %-6s  hero %.2f m/s  attacks %2d (bites %d, leaps %d)  hits %2d (bites %d, leaps %d)  HIT RATE %.1f%%"
				% [PATTERNS[stage], _hero_speed[stage] / 30.0, _begun[stage][0] + _begun[stage][1], _begun[stage][0], _begun[stage][1],
				_landed[stage][0] + _landed[stage][1], _landed[stage][0], _landed[stage][1], _rate(stage)])
	print("hound_pressure_live: a standing hero sits at %.2f to %.2f (mean %.2f) of the leap's flight over %d leaps; of those the fraction set, %.2f to %.2f over %d"
			% [(_landing_fractions.min() as float) if not _landing_fractions.is_empty() else 0.0,
			(_landing_fractions.max() as float) if not _landing_fractions.is_empty() else 0.0,
			_mean(_landing_fractions), _landing_fractions.size(),
			(_long_fractions.min() as float) if not _long_fractions.is_empty() else 0.0,
			(_long_fractions.max() as float) if not _long_fractions.is_empty() else 0.0, _long_fractions.size()])
	print("hound_pressure_live: sideways lead on a walking hero a mean %.2f of what is owed over %d windups; off a standing hero mean %.2f m over %d; lunges %d, mean %.3f m, longest %.3f m; leaps at a standing hero %d, landed past him %d, begun close %d; repositions %d, retreats %d, run-ons %d, press chains %s"
			% [_mean(_lead_walking), _lead_walking.size(), _mean(_lead_standing), _lead_standing.size(), _lunges.size(), _mean(_lunges),
			(_lunges.max() as float) if not _lunges.is_empty() else 0.0, _leaps_standing, _leaps_past, _close_leaps,
			_repositions, _retreats, _run_ons, _chains])
	print("hound_pressure_live: ORBIT clip ticks %s over %d ticks, %d facing the hero; longest orbit %d ticks"
			% [_orbit_clips, _orbit_ticks, _orbit_facing, _longest_orbit])
	print("hound_pressure_live: voices heard %s over %d files; most capped voices at once %d; mean pitch %.3f / %.3f"
			% [_heard, _heard_files.size(), _most_sounding,
			_mean(Array(_heard_pitch[0], TYPE_FLOAT, &"", null)), _mean(Array(_heard_pitch[1], TYPE_FLOAT, &"", null))])
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
