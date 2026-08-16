extends SceneTree

## Story 4-3c post-smoke fix pass: the model SHOWS what the unit AIMS at.
##
## THE DEFECT THIS PINS. Live smoke found a minion whose swing hit correctly (the ROOT/hitbox
## yaw was always right - see unit_actor.tscn's HitboxShape note) while its Mixamo BODY faced
## the opposite way, walking and swinging backwards. test_visible_facing.gd's hero counterpart
## cannot catch this class of defect: it pins mesh yaw == hitbox yaw, a relationship that stays
## TRUE even when the model glued under that yaw is mounted 180 degrees off, because a yaw
## field says nothing about which way the mesh geometry itself points. This test therefore
## never reads a yaw field -- it reads the model's own world-space forward vector and compares
## it directly against the direction the actor is aiming, which is the only assertion a
## backwards mount can fail.
##
## THE MODEL'S OWN FRONT AXIS is a fact about the asset, not about this scene: Mixamo exports
## face local +Z (recorded on unit_actor.tscn's SkeletonZombie node, 4-3c fix pass). Whatever
## rotation SkeletonZombie's own node transform carries is applied to that fixed +Z, then the
## unit root's rotation is applied on top, giving the model's TRUE world-space front -- exactly
## the computation a human eye performs when judging "which way is this thing facing".
##
## One PHYSICS FRAME of waiting after add_child, test_visible_facing.gd's own precedent:
## global_transform errors (Node3D::get_global_transform) if read before the node has actually
## entered the tree, and inside SceneTree._initialize() add_child has not taken effect yet
## (measured -- is_inside_tree() reads false there). aim_at() itself needs nothing but
## global_position, which is safe once the frame has ticked once.
##
## NAMED MUTATION: removing the SkeletonZombie node's compensating yaw (or zeroing it) must
## turn this RED with the message below. That is the exact defect this file exists to catch,
## and the mutation the dev pass ran and measured (see the story's mutation table).
##
## LIMITATION: MODEL_LOCAL_FRONT = (0,0,1) is an ASSERTION about the asset, not a measurement --
## this file reads no mesh geometry and cannot verify the Mixamo export's true front axis. If
## that assertion is wrong, the model stays mounted backwards and this test still passes GREEN.
## Live smoke is the only check that closes this gap.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_model_facing.gd

const YAW_EPS := 0.001

## Mixamo's documented native front axis for this asset (unit_actor.tscn, SkeletonZombie node).
const MODEL_LOCAL_FRONT := Vector3(0, 0, 1)

var _unit: Node3D
var _failures: Array[String] = []
var _frames := 0


func _model_world_front() -> Vector3:
	var model: Node3D = _unit.get_node(^"SkeletonZombie") as Node3D
	var basis: Basis = _unit.global_transform.basis * model.transform.basis
	return (basis * MODEL_LOCAL_FRONT).normalized()


func _check_aim(target: Vector3, label: String) -> void:
	_unit.aim_at(target)
	var expected: Vector3 = Vector3(target.x - _unit.global_position.x, 0.0,
			target.z - _unit.global_position.z).normalized()
	var actual: Vector3 = _model_world_front()
	var dot: float = expected.dot(actual)
	if dot < 1.0 - YAW_EPS:
		_failures.append(("%s: model world-forward %s does not agree with aim direction %s "
				+ "(dot %.4f) - the model is mounted off-axis from where the unit aims")
				% [label, actual, expected, dot])
	print("%s: aim=%s model_front=%s dot=%.4f" % [label, expected, actual, dot])


func _initialize() -> void:
	_unit = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	root.add_child(_unit)
	# Deliberately no position assignment here: global_position errors before the node has
	# entered the tree (same is_inside_tree gap the header note explains), and the scene's own
	# authored root position is already (0, 0, 0), so there is nothing to correct.


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	# Two different aim directions -- a single agreement could be a lucky coincidence at one
	# angle; two independent directions rule that out.
	_check_aim(Vector3(0, 0, -5), "aim toward -Z")
	_check_aim(Vector3(5, 0, 0), "aim toward +X")

	_unit.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
