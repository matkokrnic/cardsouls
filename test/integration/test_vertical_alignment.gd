extends SceneTree

## Story 3-0b (AC 4, Pass 3b) machine contract: the hero does NOT float, and every
## presentation anchor sits at the right height ON the body.
##
## THE DEFECT THIS PINS. Pass 3 fixed the LATERAL half of AC4 (the roll clip's Hips XZ
## excursion, pinned by test_clip_timing.gd) and the disc still did not read as under the
## character, because the VERTICAL half was never addressed: hero.tscn's root is the body
## CENTRE (Collision spans root y [-1,+1], main.tscn spawns both heroes at
## y 1.0, so the box floor rests exactly on the ground's top surface at y 0), but the
## paladin FBX has its origin at the model's FEET and 3-0a instanced it with no transform.
## The model therefore sat a full 1.0 above the box floor — a body-height of daylight, with
## the RollDisc correctly under the BOX and nowhere near the visible feet.
##
## WHY test_clip_timing.gd could not catch it: that test measures the roll clip's Hips
## EXCURSION — a relative displacement within the clip's own track data. A constant offset
## between the model and the ground is invisible to any relative measure, and no test in the
## suite compared a presentation node against the ground or against the model. This file is
## that missing absolute-placement assertion.
##
## Structural only: both packed scenes are read at instantiation and local transforms are
## accumulated up the parent chain by hand, so no tree, no frame and no _ready are needed
## (test_rig_clips.gd's pattern). That also means it cannot be fooled by runtime motion.
##
## Run: godot --headless --path . --script res://test/integration/test_vertical_alignment.gd

## Exactly-authored relationships (model feet vs box floor vs ground top) are integer-clean
## in the scene files, so drift beyond this is a real edit, not float slack.
const EXACT_EPS := 0.001

## How far the RollDisc's plane may sit from the model's lowest vertex, in EITHER direction,
## and still read as "under the character". Two-sided on purpose: a disc floating above the
## feet and a disc abandoned a body-height below them are both AC4 failures, and the defect
## this pins was the latter. Derived, not tuned: the disc is a 0.05-tall cylinder authored
## 0.05 above the box floor, so its top face sits 0.075 above the feet by construction. 0.15
## leaves room for that plus a repaint of the disc's own thickness while staying an order of
## magnitude below the 1.0 detachment — a regression ceiling with large headroom.
const DISC_FEET_AGREEMENT := 0.15

var _hero: Node3D
var _failures: Array[String] = []


func _rel(node: Node3D, base: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != base:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Vertical [min, max] of a node's mesh or box shape, in `base`-local space.
func _span(path: String, base: Node3D) -> Vector2:
	var node: Node3D = base.get_node_or_null(NodePath(path)) as Node3D
	if node == null:
		_failures.append("node missing from hero.tscn: %s" % path)
		return Vector2.ZERO
	var y: float = _rel(node, base).origin.y
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var b: AABB = (node as MeshInstance3D).mesh.get_aabb()
		return Vector2(y + b.position.y, y + b.position.y + b.size.y)
	if node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D:
		var sz: Vector3 = ((node as CollisionShape3D).shape as BoxShape3D).size
		return Vector2(y - sz.y * 0.5, y + sz.y * 0.5)
	# Story 7-8: the hero hit shape is a CYLINDER (yaw-invariant, `7-8/R9`).
	if node is CollisionShape3D and (node as CollisionShape3D).shape is CylinderShape3D:
		var h: float = ((node as CollisionShape3D).shape as CylinderShape3D).height
		return Vector2(y - h * 0.5, y + h * 0.5)
	_failures.append("node carries no measurable mesh/box shape: %s" % path)
	return Vector2.ZERO


## Merged vertical extent of every MeshInstance3D under `path`, in hero-root space.
func _model_span() -> Vector2:
	var pal: Node3D = _hero.get_node_or_null(^"Mesh/Paladin") as Node3D
	if pal == null:
		_failures.append("Mesh/Paladin missing from hero.tscn")
		return Vector2.ZERO
	var lo := INF
	var hi := -INF
	for m in pal.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = _rel(mi, _hero) * mi.mesh.get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.position.y + a.size.y)
	if lo == INF:
		_failures.append("Mesh/Paladin carries no MeshInstance3D with a mesh")
		return Vector2.ZERO
	return Vector2(lo, hi)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate()
	var main: Node3D = load("res://src/main/main.tscn").instantiate()

	var model := _model_span()
	var box := _span("Collision", _hero)
	var hurt := _span("Hurtbox/HurtboxShape", _hero)
	var disc := _span("TelegraphController/Shapes/RollDisc", _hero)
	var cone := _span("TelegraphController/Shapes/AttackCone", _hero)
	var shield := _span("TelegraphController/Shapes/BlockShield", _hero)
	var flash := _span("TelegraphController/HitFlash", _hero)

	# --- (1) THE GROUNDING PIN. The model's lowest vertex sits on the body box's floor. ---
	# This is the assertion whose absence let the hero float through all of Pass 3.
	_check(absf(model.x - box.x) <= EXACT_EPS,
		"model's lowest vertex (%.4f) is not on the body box floor (%.4f) — delta %.4f; the hero floats"
			% [model.x, box.x, model.x - box.x])

	# --- (2) The same relationship in WORLD space, against the actual ground. ---
	# The hero-local check above would still pass if main.tscn's spawn height or the ground
	# moved, so the two scenes are cross-checked here rather than assumed consistent.
	var ground_top: float = _span("Ground/GroundCollision", main).y
	for slot: String in ["P1Hero", "P2Hero"]:
		var spawn: Node3D = main.get_node_or_null(NodePath(slot)) as Node3D
		if spawn == null:
			_failures.append("main.tscn is missing %s" % slot)
			continue
		var feet: float = spawn.transform.origin.y + model.x
		_check(absf(feet - ground_top) <= EXACT_EPS,
			"%s's model feet land at world y %.4f, ground top is %.4f — delta %.4f"
				% [slot, feet, ground_top, feet - ground_top])

	# --- (3) The roll disc reads UNDER the feet (AC4's criterion, vertical half). ---
	# The disc's PLANE and the model's lowest vertex must agree — the disc is underfoot only
	# if it is at the foot, not merely somewhere below it.
	_check(absf(disc.y - model.x) <= DISC_FEET_AGREEMENT,
		"RollDisc plane (%.4f) and the model's feet (%.4f) disagree by %.4f, tolerance is %.4f"
			% [disc.y, model.x, disc.y - model.x, DISC_FEET_AGREEMENT])
	_check(disc.y >= box.x - EXACT_EPS,
		"RollDisc top (%.4f) is below the body box floor (%.4f) — it would be buried in the ground"
			% [disc.y, box.x])

	# --- (4) Attack cone and block shield read at BODY HEIGHT on the model. ---
	# Operator ruling, Pass 3b: these drop with the model rather than staying overhead, and
	# the resulting intersection with the head/shoulders is an ACCEPTED cost. What is pinned
	# is that their span lies within the model's own vertical extent — the failure mode this
	# guards is them drifting back to the box-relative heights they were authored at in 1-10,
	# which would leave them floating in empty air above a correctly-grounded model.
	for pair: Array in [["AttackCone", cone], ["BlockShield", shield]]:
		var name: String = pair[0]
		var s: Vector2 = pair[1]
		_check(s.x >= model.x and s.y <= model.y,
			"%s spans [%.4f, %.4f], outside the model's extent [%.4f, %.4f] — not at body height"
				% [name, s.x, s.y, model.x, model.y])

	# --- (5) The hit flash encloses the body it flashes. ---
	_check(flash.x <= model.x + EXACT_EPS and flash.y >= model.y - EXACT_EPS,
		"HitFlash spans [%.4f, %.4f] and does not enclose the model [%.4f, %.4f]"
			% [flash.x, flash.y, model.x, model.y])

	# --- (6) The BODY box is UNMOVED (3-0b; since story 7-8 also AC 12's structural proof). ---
	_check(absf(box.x - (-1.0)) <= EXACT_EPS and absf(box.y - 1.0) <= EXACT_EPS,
		"body box span [%.4f, %.4f] moved off the authored [-1, +1]" % [box.x, box.y])
	# STORY 7-8 SUPERSEDES THIS PIN'S SECOND HALF ("HurtboxShape mirrors the body box", 1-7's convention,
	# 3-0b pin (6)): the hit shape is now its OWN sub-resource that follows the trunk (AC 11), and the body
	# keeps its box (AC 12). What is pinned instead: the two never share a shape again. (The hit shape's
	# placement is live -- it follows a bone -- so its geometry is proved in test_hero_hit_shape_live.gd.)
	var collision := _hero.get_node_or_null(^"Collision") as CollisionShape3D
	var hurt_node := _hero.get_node_or_null(^"Hurtbox/HurtboxShape") as CollisionShape3D
	_check(collision != null and hurt_node != null and collision.shape != hurt_node.shape,
		"the hit shape SHARES the body collision's shape resource again -- AC 12 keeps them separate")
	_check(hurt.y > hurt.x, "sanity: the hit shape has a measurable vertical span [%.4f, %.4f]"
		% [hurt.x, hurt.y])

	print("model y=[%.4f, %.4f] height=%.4f | box y=[%.4f, %.4f] | ground top=%.4f"
		% [model.x, model.y, model.y - model.x, box.x, box.y, ground_top])
	print("disc y=[%.4f, %.4f] | cone y=[%.4f, %.4f] | shield y=[%.4f, %.4f] | flash y=[%.4f, %.4f]"
		% [disc.x, disc.y, cone.x, cone.y, shield.x, shield.y, flash.x, flash.y])
	# Neither scene was added to the tree, so free them explicitly — main.tscn carries
	# viewports, cameras and physics bodies whose RIDs would otherwise be reported leaked.
	_hero.free()
	main.free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
