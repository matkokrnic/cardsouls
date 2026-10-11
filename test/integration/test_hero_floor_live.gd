extends SceneTree

## Story 7-3 REVIEW, targeted check 8 (operator live smoke): THE HERO'S FEET STAY ON THE ARENA FLOOR.
##
## Once, a hero walked about 1 m above the ground for the rest of a match. The hero is a CharacterBody3D
## with a 1 x 2 x 1 box centred on its root (floor contact at root y = 1.0) and it is driven with a
## velocity whose y is always zero, so nothing ever brings it back down once the physics server has
## moved it up. A hound's body is a short cylinder (0.66 m): when a hero's box overlaps it, the
## shallowest way out is UP, and the hero ends standing on the hound.
##
## THREE WAYS INTO THAT OVERLAP, each a scenario below on the real runner and the shipped hound scene:
##   1. LEAP END INSIDE THE HERO   a REAL leap (the hound's own hero stands behind the victim as the
##      thing that stops it short). The overshoot normally clears the box (the leap is authored to end
##      0.08 m past it), so in the review run this one PASSED: it ended outside the box. It is kept as
##      the guard for the natural path; the overlap itself is forced in 2 and 3.
##   2. HOUND APPEARS INSIDE A HERO  a hound that rises (Raise Dead, Counterspell restore) or is
##      summoned where a hero stands: corpses are walk-through, so a hero can stand on one.
##   3. THE HERO IS PLACED ONTO A HOUND  the same overlap from the other side (a hero walking into a
##      hound's landing point). NOTE: the runner cancels a hand-made `start_passing` on its next
##      drive (the hound is not in an overshooting swing), so 3 is 2 from the other side.
##
## MEASURED, review run: a hero whose centre is within about 0.1 m of the hound's centre is moved UP by
## exactly the hound's height (0.66 m) and stays there; farther off it is moved sideways.
##
## EVERY ASSERTION IS AN EFFECT: the hero's global y, measured in the settled state.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_floor_live.gd

const MAX_FRAMES := 1200
## The hero root rests at y = 1.0 (box floor on the ground top, `hero.tscn` GROUNDING OFFSET).
const HERO_FLOOR_Y := 1.0
const TOLERANCE := 0.02
const SETTLE_FRAMES := 20

var _frames := 0
var _runner: Node
var _state: MatchState
var _failures: Array[String] = []
var _stage := "summon"
var _stage_frames := 0
var _index := 0
var _kind_index := -1
var _kind: UnitKindProfile
var _victim: Node3D
var _report: Array[String] = []
var _saw_active := false
var _samples: Array[Vector3] = []


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.seed_override = 12345
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _finish("missing runner/state")
		_kind_index = _state.balance.kind_index_of(&"hellhound")
		_kind = _state.balance.kind_at(_kind_index)
		if _kind == null:
			return _finish("authored balance carries no `hellhound` kind")
		# The hound must not wander off or attack while a scenario is measured: its behaviour is not
		# under test, the overlap is.
		_kind.move_speed = 0.0
		return false
	_stage_frames += 1
	if _step():
		return _finish("")
	if _frames >= MAX_FRAMES:
		return _finish("stuck in stage '%s' at frame %d" % [_stage, _frames])
	return false


func _enter(stage: String) -> void:
	_stage = stage
	_stage_frames = 0
	_samples.clear()


## Review fix (F1): after a forced overlap the hero must end OUTSIDE the hound (separated sideways, by at
## least the box half-width plus the body radius less a hand's breadth), and its position must not move over
## the last ten settled frames -- no lasting overlap, no jitter, y constant.
const JITTER := 0.002
const OUTSIDE := 0.70

func _check_separated(label: String, hound: Node3D, victim: Node3D) -> void:
	var planar := Vector2(victim.global_position.x - hound.global_position.x,
			victim.global_position.z - hound.global_position.z).length()
	_check(planar >= OUTSIDE, "%s: the hero ended %.3f m from the hound's centre, still inside it (want >= %.2f)"
			% [label, planar, OUTSIDE])
	var tail := _samples.slice(maxi(0, _samples.size() - 10))
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for sample: Vector3 in tail:
		low = Vector3(minf(low.x, sample.x), minf(low.y, sample.y), minf(low.z, sample.z))
		high = Vector3(maxf(high.x, sample.x), maxf(high.y, sample.y), maxf(high.z, sample.z))
	_check(tail.size() >= 10, "%s: only %d settle samples" % [label, tail.size()])
	_check((high - low).length() <= JITTER, "%s: the hero kept moving over the settled window (%s)"
			% [label, high - low])
	_check(absf(low.y - HERO_FLOOR_Y) < TOLERANCE and absf(high.y - HERO_FLOOR_Y) < TOLERANCE,
			"%s: the hero's y moved off the floor in the settled window (%.3f to %.3f)" % [label, low.y, high.y])


func _hound() -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if _index >= actors.size():
		return null
	var node: Node = actors[_index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


## Put the victim hero back on the floor, well away from anything, between scenarios.
func _reset_victim() -> void:
	_victim.global_position = Vector3(_victim.global_position.x, HERO_FLOOR_Y, _victim.global_position.z)


func _step() -> bool:
	if _stage == "summon":
		_state.p1.units.add(_kind.max_hp, _kind_index)
		_enter("wait_actor")
		return false
	var hound := _hound()
	if hound == null:
		return false
	_victim = _runner._p2_hero
	var victim := _victim
	_samples.append(victim.global_position)
	match _stage:
		"wait_actor":
			# The hound's own hero is out of the way; the P2 hero stands still (no input) as the victim.
			_runner._p1_hero.global_position += Vector3(0.0, 0.0, 25.0)
			# Layer (a): the hound's BODY is at least as tall as the hero's, so a hero can never be
			# depenetrated up onto it. Layer (b) alone would hide a short body here: the hero would be
			# lifted and put back every tick, which no position sample shows.
			var hound_body := (hound.get_node_or_null("Collision") as CollisionShape3D)
			var hound_shape := (hound_body.shape if hound_body != null else null) as CylinderShape3D
			var hero_body := (victim.get_node_or_null("Collision") as CollisionShape3D)
			var hero_shape := (hero_body.shape if hero_body != null else null) as BoxShape3D
			_check(hound_shape != null and hero_shape != null and hound_shape.height >= hero_shape.size.y
					and absf(hound_body.position.y - hound_shape.height * 0.5) < 0.001,
					"a: the hound's body (%s) is not at least as tall as the hero's (%s) standing on the ground"
							% [hound_shape.height if hound_shape != null else "missing",
							hero_shape.size.y if hero_shape != null else "missing"])
			_enter("s1_setup")
		"s1_setup":
			# 1. A REAL LEAP THAT ENDS INSIDE THE HERO. The hound stands 3 m from the victim, in the leap
			# band. Its own hero (a box on the default layer, so it stops the hound exactly as a wall or
			# a sibling would) stands 0.85 m behind the victim: the leap passes the victim's body, is
			# stopped short by that box, and ends with the hound's centre about 0.08 m off the victim's.
			_reset_victim()
			hound.global_position = Vector3(victim.global_position.x - 3.0, 0.0, victim.global_position.z)
			_runner._p1_hero.global_position = Vector3(victim.global_position.x + 0.85, HERO_FLOOR_Y,
					victim.global_position.z)
			_saw_active = false
			_enter("s1_leap")
		"s1_leap":
			var phase := _state.p1.units.attack_phase_at(_index)
			if phase == UnitBoard.AttackPhase.ACTIVE:
				_saw_active = true
			if _saw_active and phase == UnitBoard.AttackPhase.IDLE:
				_enter("s1_after")
			elif _stage_frames > 600:
				return _finish("s1: the hound never completed a leap (phase %d)" % phase)
		"s1_after":
			if _stage_frames == SETTLE_FRAMES:
				var y := victim.global_position.y
				_report.append("s1 leap ends inside hero: hero %s hound %s" % [victim.global_position, hound.global_position])
				_check(absf(y - HERO_FLOOR_Y) < TOLERANCE,
						"s1: LEAP END INSIDE THE HERO left the hero %.3f m above the floor (y %.3f, floor %.3f)"
								% [y - HERO_FLOOR_Y, y, HERO_FLOOR_Y])
				_enter("s1_gone")
				hound.global_position = Vector3(victim.global_position.x + 12.0, 0.0, victim.global_position.z)
		"s1_gone":
			if _stage_frames == SETTLE_FRAMES:
				var y := victim.global_position.y
				_report.append("s1 after the hound left: hero y %.3f" % y)
				_check(absf(y - HERO_FLOOR_Y) < TOLERANCE,
						"s1: the hero is still %.3f m above the floor after the hound is gone" % (y - HERO_FLOOR_Y))
				_enter("s2_setup")
		"s2_setup":
			# 2. HOUND APPEARS INSIDE A HERO (raise / restore / summon onto a standing hero).
			_reset_victim()
			hound.global_position = Vector3(victim.global_position.x + 0.1, 0.0, victim.global_position.z + 0.1)
			_enter("s2_after")
		"s2_after":
			if _stage_frames == SETTLE_FRAMES:
				var y := victim.global_position.y
				_report.append("s2 hound placed inside hero (no exception): hero %s hound %s" % [victim.global_position, hound.global_position])
				_check(absf(y - HERO_FLOOR_Y) < TOLERANCE,
						"s2: A HOUND PLACED INSIDE THE HERO left it %.3f m above the floor (y %.3f)"
								% [y - HERO_FLOOR_Y, y])
				_check_separated("s2", hound, victim)
				hound.global_position = Vector3(victim.global_position.x + 12.0, 0.0, victim.global_position.z)
				_enter("s2_gone")
		"s2_gone":
			if _stage_frames == 60:
				var y := victim.global_position.y
				_report.append("s2 one second after the hound is gone: hero y %.3f" % y)
				_check(absf(y - HERO_FLOOR_Y) < TOLERANCE,
						"s2: the hero is STILL %.3f m above the floor one second after the hound is gone"
								% (y - HERO_FLOOR_Y))
				_enter("s3_setup")
		"s3_setup":
			if _stage_frames == 1:
				# 3. THE HERO IS PLACED ONTO A PASSING HOUND, then the exception ends.
				_reset_victim()
				hound.global_position = Vector3(victim.global_position.x + 3.0, 0.0, victim.global_position.z)
				hound.start_passing([victim as PhysicsBody3D] as Array[PhysicsBody3D])
				_enter("s3_walk")
		"s3_walk":
			if _stage_frames == 3:
				# The hero walks into the landing point: moved onto the hound's centre.
				victim.global_position = Vector3(hound.global_position.x - 0.05, HERO_FLOOR_Y, hound.global_position.z)
			if _stage_frames == 8:
				hound.stop_passing()
				_enter("s3_after")
		"s3_after":
			if _stage_frames == 90:
				var y := victim.global_position.y
				_report.append("s3 hero walks into landing, exception ends: hero y %.3f" % y)
				_check(absf(y - HERO_FLOOR_Y) < TOLERANCE,
						"s3: A HERO IN THE LANDING POINT left it %.3f m above the floor (y %.3f)"
								% [y - HERO_FLOOR_Y, y])
				_check_separated("s3", hound, victim)
				hound.global_position = Vector3(victim.global_position.x + 12.0, 0.0, victim.global_position.z)
				_enter("s4_lift")
		"s4_lift":
			# 4. THE INVARIANT ITSELF (layer b): whatever moved the hero up -- here a plain 0.66 m shove, the
			# lift a short body used to cause -- its root is back at the rest height after its next move.
			if _stage_frames == 1:
				victim.global_position = Vector3(victim.global_position.x, HERO_FLOOR_Y + 0.66, victim.global_position.z)
			elif _stage_frames == 6:
				_report.append("s4 hero shoved 0.66 m up: hero y %.3f five frames later" % victim.global_position.y)
				_check(absf(victim.global_position.y - HERO_FLOOR_Y) < TOLERANCE,
						"s4: a hero moved up stayed %.3f m above the floor" % (victim.global_position.y - HERO_FLOOR_Y))
				return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	# A hound's voice still playing at exit is a resource in use.
	if _runner != null and _runner._effects != null:
		_runner._effects.stop_all_sounds()
	OS.delay_msec(100)
	for line in _report:
		print("  " + line)
	for f in _failures:
		print("  FAILED: " + f)
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
