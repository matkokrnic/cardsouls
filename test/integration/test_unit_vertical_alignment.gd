extends SceneTree

## Story 4-3c (AC 2, ruling 4-3c/R3) machine contract: the MINION does not float. The
## counterpart of test_vertical_alignment.gd, which pins the same relationship for the hero.
##
## THE DEFECT THIS PINS, and why it is not hypothetical. The hero's floating defect shipped
## for a WHOLE STORY (3-0a) before anyone noticed, because nothing asserted an absolute
## spatial relationship -- test_clip_timing.gd measured the roll clip's Hips EXCURSION, and a
## relative measure inside the clip's own track data is mathematically BLIND to a constant
## offset between the model and the ground. 3-0b closed that hole for the hero. This file is
## the same assertion for the minion, and the minion's geometry is the hero's MIRRORED:
##   - hero.tscn's root is the body CENTRE, so its Mesh node needed a COMPENSATING -1.0 to
##     ground a feet-origin Mixamo model.
##   - unit_actor.tscn's root is the body's FEET, so its old Mesh node carried +0.6 (like
##     Collision, HurtboxShape and HitboxShape, all for that same stated reason). Parenting a
##     feet-origin model under THAT would add the offset a second time and hover the minion
##     0.6 above the ground -- the hero's own defect reintroduced by following a precedent
##     that does not apply to this actor. The model therefore parents DIRECTLY UNDER THE ROOT.
##
## NAMED MUTATION (4-3c/R11): re-parenting SkeletonZombie under a node carrying the old +0.6
## offset -- or restoring that offset onto the model's own parent -- must turn this test RED.
## That is the exact defect it exists to catch, and it is the mutation the dev pass ran.
##
## Structural only: the packed scenes are read at instantiation and local transforms are
## accumulated up the parent chain by hand, so no tree, no frame and no _ready are needed
## (test_vertical_alignment.gd's / test_rig_clips.gd's pattern). That also means it cannot be
## fooled by runtime motion.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_vertical_alignment.gd

## Exactly-authored relationships (box floor vs ground top) are integer-clean in the scene
## files and in the runner's own spawn constant, so drift beyond this is a real edit.
const EXACT_EPS := 0.001

## How far the model's lowest vertex may sit from the body box's floor and still read as
## standing ON it. DERIVED, NOT TUNED, and it is deliberately NOT the hero's EXACT_EPS: the
## imported skeleton-zombie mesh's own bind-pose AABB dips 0.0162 BELOW its origin (measured
## by the dev pass off the imported scene), so an exactly-zero assertion is not available for
## this model the way it was for the paladin. 0.05 admits that measured slop with roughly 3x
## headroom while still rejecting the 0.6 double-offset defect this file exists to catch by
## more than an order of magnitude -- a regression ceiling with large headroom, the same
## posture the hero test's own DISC_FEET_AGREEMENT takes.
const MODEL_FEET_AGREEMENT := 0.05

## The runner file the spawn-Y constant is PARSED from, not transcribed (M3 FIX PASS). A
## transcribed literal here would defeat its own stated purpose -- it claims to notice a
## runner change, but a hand-copied number never actually re-reads the runner and would stay
## `0.0` even if `_spawn_missing_unit_actors` moved. So this reads the value straight off
## `MatchRunner._spawn_missing_unit_actors`'s own literal (`unit.global_position =
## Vector3(UNIT_ROW_X[slot], 0.0, ...)`) every run.
const RUNNER_PATH := "res://src/main/match_runner.gd"

## Parse the spawn-Y literal out of `_spawn_missing_unit_actors`. Returns NAN, and the caller
## fails LOUDLY, if the source no longer matches -- a silent fallback to a hardcoded number
## would restore the exact transcription defect this fix pass exists to remove.
func _parse_spawn_ground_y() -> float:
	var src := FileAccess.get_file_as_string(RUNNER_PATH)
	if src.is_empty():
		_failures.append("could not read %s to parse the spawn-Y literal" % RUNNER_PATH)
		return NAN
	var lines := src.split("\n")
	for i: int in lines.size() - 1:
		if not lines[i].contains("unit.global_position = Vector3(UNIT_ROW_X[slot],"):
			continue
		var next_line := lines[i + 1].strip_edges()
		var comma := next_line.find(",")
		if comma < 0:
			break
		var token := next_line.substr(0, comma).strip_edges()
		if token.is_valid_float():
			return token.to_float()
		break
	_failures.append(("could not parse the spawn-Y literal out of %s's "
			+ "_spawn_missing_unit_actors - the source no longer matches the expected shape, "
			+ "and a silent fallback would lie the same way the old hardcoded constant did")
			% RUNNER_PATH)
	return NAN

## The world-space Y the runner spawns every unit actor onto -- CROSS-CHECKED, NOT TRUSTED:
## minions have no spawn scene node the way main.tscn gives the heroes one (4-3c/R13), so the
## ground assertion below checks the parsed value against main.tscn's actual ground surface
## rather than assuming the two agree. If the runner ever spawns units at a different height,
## that check is what notices.
var SPAWN_GROUND_Y: float = NAN

var _unit: Node3D
var _failures: Array[String] = []


func _rel(node: Node3D, base: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != base:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Vertical [min, max] of a node's box shape, in `base`-local space.
func _box_span(path: String, base: Node3D) -> Vector2:
	var node: Node3D = base.get_node_or_null(NodePath(path)) as Node3D
	if node == null:
		_failures.append("node missing: %s" % path)
		return Vector2.ZERO
	var y: float = _rel(node, base).origin.y
	if node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D:
		var sz: Vector3 = ((node as CollisionShape3D).shape as BoxShape3D).size
		return Vector2(y - sz.y * 0.5, y + sz.y * 0.5)
	_failures.append("node carries no measurable box shape: %s" % path)
	return Vector2.ZERO


## Merged vertical extent of every MeshInstance3D under the model, in unit-root space.
func _model_span() -> Vector2:
	var model: Node3D = _unit.get_node_or_null(^"SkeletonZombie") as Node3D
	if model == null:
		_failures.append("SkeletonZombie missing from unit_actor.tscn")
		return Vector2.ZERO
	var lo := INF
	var hi := -INF
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = _rel(mi, _unit) * mi.mesh.get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.position.y + a.size.y)
	if lo == INF:
		_failures.append("SkeletonZombie carries no MeshInstance3D with a mesh")
		return Vector2.ZERO
	return Vector2(lo, hi)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _initialize() -> void:
	SPAWN_GROUND_Y = _parse_spawn_ground_y()
	if is_nan(SPAWN_GROUND_Y):
		for f in _failures:
			print("  FAILED: " + f)
		print("RESULT: FAIL")
		quit(1)
		return

	_unit = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	var main: Node3D = load("res://src/main/main.tscn").instantiate()

	var model := _model_span()
	var box := _box_span("Collision", _unit)
	var hurt := _box_span("Hurtbox/HurtboxShape", _unit)

	# --- (1) THE GROUNDING PIN. The model's lowest vertex sits on the body box's floor. ---
	# This is the assertion whose absence let the HERO float through all of 3-0a and Pass 3.
	_check(absf(model.x - box.x) <= MODEL_FEET_AGREEMENT,
		"model's lowest vertex (%.4f) is not on the body box floor (%.4f) - delta %.4f, tolerance %.4f; the minion floats"
			% [model.x, box.x, model.x - box.x, MODEL_FEET_AGREEMENT])

	# --- (2) The same relationship in WORLD space, against the actual ground. ---
	# The unit-local check above would still pass if the runner's spawn height or the ground
	# moved, so the runner's own spawn constant and main.tscn's ground are cross-checked here
	# rather than assumed consistent (4-3c/R13 -- there is no minion spawn NODE to read).
	var ground_top: float = _box_span("Ground/GroundCollision", main).y
	_check(absf(SPAWN_GROUND_Y - ground_top) <= EXACT_EPS,
		"the runner spawns units at world y %.4f but main.tscn's ground top is %.4f - delta %.4f"
			% [SPAWN_GROUND_Y, ground_top, SPAWN_GROUND_Y - ground_top])
	var feet: float = SPAWN_GROUND_Y + model.x
	_check(absf(feet - ground_top) <= MODEL_FEET_AGREEMENT,
		"a spawned unit's model feet land at world y %.4f, ground top is %.4f - delta %.4f"
			% [feet, ground_top, feet - ground_top])

	# --- (3) The body box itself is where the scene says it is. ---
	# The pin in (1) is a RELATIONSHIP, so it would also be satisfiable by moving the BOX down
	# onto a hovering model. This is what makes that reading unavailable: the box floor sits at
	# the root (the unit ROOT is the box's FEET, the +0.6 offset on a 1.2-tall shape).
	_check(absf(box.x - 0.0) <= EXACT_EPS and absf(box.y - 1.2) <= EXACT_EPS,
		"body box span [%.4f, %.4f] moved off the authored [0, 1.2]" % [box.x, box.y])

	# --- (4) Detection volumes UNMOVED (this story adds no collision geometry at all). ---
	_check(absf(hurt.x - box.x) <= EXACT_EPS and absf(hurt.y - box.y) <= EXACT_EPS,
		"HurtboxShape [%.4f, %.4f] no longer mirrors the body box [%.4f, %.4f]"
			% [hurt.x, hurt.y, box.x, box.y])

	print("model y=[%.4f, %.4f] height=%.4f | box y=[%.4f, %.4f] | ground top=%.4f | spawn y=%.4f"
		% [model.x, model.y, model.y - model.x, box.x, box.y, ground_top, SPAWN_GROUND_Y])
	# Neither scene was added to the tree, so free them explicitly - both carry physics bodies
	# whose RIDs would otherwise be reported leaked at exit.
	_unit.free()
	main.free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
