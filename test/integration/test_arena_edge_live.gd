extends SceneTree

## Story 5-0d (AC 1/AC 3/AC 4/AC 10): THE ARENA'S NEW RING WALL, proven against a REAL
## `CharacterBody3D` (a standalone `hero.tscn` instance) driven by repeated `move_and_slide()`
## ticks against the REAL `main.tscn` collision geometry -- the same body/shape the shipped hero
## uses, in the same world coordinates the wall is authored in.
##
## WHY A STANDALONE ACTOR RATHER THAN P1/P2's OWN HERO: driving movement through the real
## Input Map -> KeyboardController -> MatchState chain (`test_unit_approach_live.gd`'s pattern)
## turned out to run this story's actors into EACH OTHER's body collision (P1's hero starts only
## 6 units from P2's, well short of the 20-unit wall) before either could reach the ring, and
## separately, camera-relative movement continuously RE-YAWS toward the live lock target
## (`camera_rig.gd`'s `face_lock_direction`), which curves any held direction into a moving-target
## arc rather than a stable line or diagonal -- neither is what this test needs. This file
## sidesteps both by instantiating a THIRD `hero.tscn` body that answers to nobody's input and
## nobody's lock-on: its `velocity` is set directly, `move_and_slide()` is called on it directly
## (the exact same builtin `CharacterBody3D` method `hero.gd:85` calls), and the real
## `P1Hero`/`P2Hero` are left alone, motionless, out of its path. The WALL COLLISION measured is
## identical either way -- it is static scene geometry with no opinion about which body approaches
## it.
##
## PHASE 1 (west face): driven at constant velocity in -X, straight at the West wall's inner face
## (`x = -20`), offset in Z (start `z = 8`) so it never nears either hero's body.
## PHASE 2 (NW corner): -X held, +Z ADDED, driving the already wall-parked body diagonally along
## the West wall toward the North-West corner (`x = -20, z = 20`).
## PHASE 3 (east face): +X only, driving the body along the North wall (already pinned from Phase
## 2) all the way across the arena to the East wall's inner face (`x = 20`).
## PHASE 4 (SE corner): +X held, -Z ADDED, driving the already wall-parked body diagonally along
## the East wall toward the South-East corner (`x = 20, z = -20`).
##
## Run: godot --headless --path . --script res://test/integration/test_arena_edge_live.gd

const START_POS := Vector3(0.0, 1.0, 8.0)
const SPEED := 10.0
## West face: 20 units of -X travel (x: 0 -> -20) at 10/s is 2s = 120 ticks; ample margin.
const PHASE1_TICKS := 300
## NW corner: 12 units of +Z travel (z: 8 -> 20) at 10/s is 1.2s = 72 ticks; ample margin.
const PHASE2_TICKS := 300
## East face: 40 units of +X travel (x: -20 -> 20) at 10/s is 4s = 400 ticks; ample margin.
const PHASE3_TICKS := 500
## SE corner: 40 units of -Z travel (z: 20 -> -20) at 10/s is 4s = 400 ticks; ample margin.
const PHASE4_TICKS := 500

## Phase boundaries derived from the named tick budgets above, not restated as separate literals --
## editing a PHASE*_TICKS constant shifts every boundary after it with no off-by-one to maintain
## by hand.
const PHASE1_END := PHASE1_TICKS
const PHASE2_END := PHASE1_END + PHASE2_TICKS
const PHASE3_END := PHASE2_END + PHASE3_TICKS
const PHASE4_END := PHASE3_END + PHASE4_TICKS
const END_FRAME := PHASE4_END

## The measured world bounds this story's AC 1 authors the ring at (Dev Notes: `main.tscn`'s
## `Ground` `BoxShape3D`, `size = Vector3(40, 1, 40)`, centred on the origin).
const RING_BOUND := 20.0
## The probe's own collision half-extent (`hero.tscn`, `BoxShape3D_qp0e8`, `size = Vector3(1, 2,
## 1)`, half-extent 0.5 on x/z) means its CENTER can physically never reach the true wall face
## (`RING_BOUND`) -- against a correct wall it can reach at most `RING_BOUND - 0.5 = 19.5`. The
## per-frame assertion below is on the CENTER, so it is bounded at that physical limit, not at
## `RING_BOUND` itself; a small epsilon over it tolerates float/slide noise without weakening the
## claim.
const CENTER_BOUND := RING_BOUND - 0.5
const BOUND_EPSILON := 0.05
## The probe's center must get at least this close to a given axis bound for the run to count as
## having actually EXERCISED that face/corner -- otherwise "never left the ring" would be
## vacuously true of a body that never got near it.
const NEAR_BOUND := 18.5

var _frames := 0
var _probe: CharacterBody3D

var _min_x := 0.0
var _max_x := 0.0
var _max_z := 0.0
var _min_z := 0.0
var _out_of_ring := false
var _out_of_ring_detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_probe = load("res://src/actors/hero/hero.tscn").instantiate()
	root.add_child(_probe)
	# `position`, not `global_position` -- the probe's parent is `root` itself (identity
	# transform, so the two are numerically identical here), and querying the global transform
	# the same frame a node is added throws "not inside tree" before the tree has settled it in.
	_probe.position = START_POS
	_min_x = START_POS.x
	_max_x = START_POS.x
	_max_z = START_POS.z
	_min_z = START_POS.z


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames <= PHASE1_END:
		_probe.velocity = Vector3(-SPEED, 0.0, 0.0)
	elif _frames <= PHASE2_END:
		_probe.velocity = Vector3(-SPEED, 0.0, SPEED)
	elif _frames <= PHASE3_END:
		_probe.velocity = Vector3(SPEED, 0.0, 0.0)
	else:
		_probe.velocity = Vector3(SPEED, 0.0, -SPEED)
	_probe.move_and_slide()

	var pos: Vector3 = _probe.global_position
	_min_x = minf(_min_x, pos.x)
	_max_x = maxf(_max_x, pos.x)
	_max_z = maxf(_max_z, pos.z)
	_min_z = minf(_min_z, pos.z)
	if absf(pos.x) > CENTER_BOUND + BOUND_EPSILON or absf(pos.z) > CENTER_BOUND + BOUND_EPSILON:
		_out_of_ring = true
		_out_of_ring_detail = " OUT_OF_RING at frame %d: pos=(%.4f, %.4f, %.4f)" % [
			_frames, pos.x, pos.y, pos.z]
		# Fail fast rather than spamming the same violation for the remaining ticks.
		print("arena_edge_live: min_x=%.4f max_x=%.4f max_z=%.4f min_z=%.4f%s" % [
			_min_x, _max_x, _max_z, _min_z, _out_of_ring_detail])
		print("RESULT: FAIL")
		quit(1)
		return false

	if _frames == END_FRAME:
		var reached_west := _min_x <= -NEAR_BOUND
		var reached_east := _max_x >= NEAR_BOUND
		var reached_north := _max_z >= NEAR_BOUND
		var reached_south := _min_z <= -NEAR_BOUND
		var ok := (not _out_of_ring and reached_west and reached_east
				and reached_north and reached_south)
		var detail := ""
		if not reached_west:
			detail += " never_reached_west_face(min_x=%.3f);" % _min_x
		if not reached_east:
			detail += " never_reached_east_face(max_x=%.3f);" % _max_x
		if not reached_north:
			detail += " never_reached_nw_corner(max_z=%.3f);" % _max_z
		if not reached_south:
			detail += " never_reached_se_corner(min_z=%.3f);" % _min_z
		print("arena_edge_live: min_x=%.4f max_x=%.4f max_z=%.4f min_z=%.4f out_of_ring=%s%s" % [
			_min_x, _max_x, _max_z, _min_z, _out_of_ring, detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
