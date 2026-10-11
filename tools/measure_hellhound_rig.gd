extends SceneTree

## Story 7-3 (T1, ACs 9, 15, 17): measures the imported Hellhound model BEFORE anything is built on
## it. HEADLESS, NOT THE EDITOR (`3-0a/R3`). Prints four tables:
##
##   1. the node tree and the skeleton's bones (names, parents), so nothing downstream guesses a
##      bone name;
##   2. every take the importer yields: length, loop mode, track count, and the ROOT MOTION of the
##      take -- the planar displacement of every parentless bone, start to end and at its furthest
##      excursion. A take whose root travels is not "in place" and would fight the runner, which
##      owns position (DECISION A, the `3-0a`/`4-3c` posture);
##   3. the model's size: the skinned mesh's rest AABB in model space, and the height of the
##      probe bones in the `idle` pose (the lock-mark lift derivation);
##   4. per attack take, the head, jaw, pelvis and spine bones at every frame, in model space --
##      the strike-frame measurement, `tools/measure_strike_frame.gd`'s method on this rig.
##
## FORWARD KINEMATICS, NOT `get_bone_global_pose()`, for `measure_strike_frame.gd`'s measured
## reason: a `SceneTree` script processes no frames, so the global pose cache serves one stale
## transform. `get_bone_pose()` is never cached.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_hellhound_rig.gd

const MODEL_PATH := "res://assets/characters/hellhound/Meshes/SK_Hellhound.fbx"

## The takes sampled frame by frame in table 4. Every other take gets the summary row only.
const STRIKE_TAKES: Array[String] = ["attack", "Attack01", "JumpStart", "JumpLoop", "JumpEnd", "hit", "Death"]

## Table 5: the locomotion takes whose natural ground speed is measured, and the four paws.
const GROUND_TAKES: Array[String] = ["walk", "run", "Walk_Backwards", "Walk_Left", "Walk_Right",
		"Run_Left", "Run_Right"]
const PAW_BONES: Array[String] = ["Hand_L", "Hand_R", "Foot_L", "Foot_R"]
## A paw this close to its own lowest point (model units) is on the ground.
const STANCE_HEIGHT := 0.04

## Table 6: the standing takes compared for the stalk.
const POSTURE_TAKES: Array[String] = ["idle", "Idle01"]

## Table 7: the takes whose head yaw is measured (the standing take, then the locomotion ones).
const HEAD_TAKES: Array[String] = ["idle", "walk", "run", "Walk_Backwards", "Walk_Left", "Walk_Right",
		"Run_Left", "Run_Right"]

## Table 8: the built library and the clips of it whose head yaw is measured.
const BUILT_LIBRARY_PATH := "res://assets/characters/hellhound/hellhound_anims.res"
const BUILT_HEAD_CLIPS: Array[String] = ["walk", "walk_backwards", "walk_left", "walk_right", "run_left",
		"run_right"]

var _skel: Skeleton3D


func _bone_fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


## The transform from `node`'s local space to the MODEL root's, composed by hand. A `SceneTree`
## script's `_initialize` runs before the tree is live, so `global_transform` answers identity with
## an engine error; the parent chain is walked instead.
func _to_model(node: Node3D, model: Node) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p != null and p != model:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _print_tree(node: Node, depth: int) -> void:
	var extra := ""
	if node is Node3D:
		var n3 := node as Node3D
		extra = " pos=%s rot_deg=%s scale=%s" % [n3.position, n3.rotation_degrees, n3.scale]
	print("%s%s (%s)%s" % ["  ".repeat(depth), node.name, node.get_class(), extra])
	for child in node.get_children():
		_print_tree(child, depth + 1)


func _initialize() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("model did not load: %s" % MODEL_PATH)
		quit(1)
		return
	var model := scene.instantiate()
	root.add_child(model)

	print("=== 1. NODE TREE ===")
	_print_tree(model, 0)

	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.size() != 1:
		push_error("expected exactly 1 Skeleton3D, found %d" % skels.size())
		quit(1)
		return
	_skel = skels[0] as Skeleton3D
	print("=== 1b. BONES (%d) ===" % _skel.get_bone_count())
	var root_bones: Array[int] = []
	for b in _skel.get_bone_count():
		var parent := _skel.get_bone_parent(b)
		if parent < 0:
			root_bones.append(b)
		print("%d\t%s\tparent=%d\trest_origin=%s" % [b, _skel.get_bone_name(b), parent,
				_skel.get_bone_global_rest(b).origin])

	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		push_error("expected exactly 1 AnimationPlayer, found %d" % players.size())
		quit(1)
		return
	var player := players[0] as AnimationPlayer
	print("player root_node=%s path=%s" % [player.root_node, model.get_path_to(player)])

	print("=== 2. TAKES (planar = XZ in skeleton space) ===")
	print("take\tlength\tframes@30\tloop\ttracks\troot_bone\tend_minus_start\tmax_excursion\ty_min\ty_max")
	var takes := player.get_animation_list()
	for take in takes:
		var anim := player.get_animation(take)
		player.play(take)
		var steps := maxi(1, int(round(anim.length * 30.0)))
		for rb in root_bones:
			var start := Vector3.ZERO
			var last := Vector3.ZERO
			var max_exc := 0.0
			var y_min := INF
			var y_max := -INF
			for i in steps + 1:
				var t: float = minf(float(i) / 30.0, anim.length)
				player.seek(t, true)
				var p := _skel.get_bone_pose(rb).origin
				if i == 0:
					start = p
				last = p
				max_exc = maxf(max_exc, Vector2(p.x - start.x, p.z - start.z).length())
				y_min = minf(y_min, p.y)
				y_max = maxf(y_max, p.y)
			print("%s\t%.4f\t%d\t%d\t%d\t%s\t(%.3f, %.3f)\t%.3f\t%.3f\t%.3f" % [take, anim.length, steps,
					anim.loop_mode, anim.get_track_count(), _skel.get_bone_name(rb),
					last.x - start.x, last.z - start.z, max_exc, y_min, y_max])

	print("=== 3. SIZE ===")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		var mesh_xform := _to_model(mi, model)
		var world := mesh_xform * aabb
		print("mesh %s rest_aabb (model space) pos=%s size=%s end=%s scale=%s"
				% [mi.name, world.position, world.size, world.end, mesh_xform.basis.get_scale()])
	var skel_xform := _to_model(_skel, model)
	print("skeleton (model space) origin=%s scale=%s" % [skel_xform.origin, skel_xform.basis.get_scale()])
	if player.has_animation(&"idle"):
		player.play(&"idle")
		player.seek(0.0, true)
		print("bone positions in `idle` at t=0 (model space):")
		for b in _skel.get_bone_count():
			var w := skel_xform * _bone_fk(b).origin
			print("  %s\t%s" % [_skel.get_bone_name(b), w])

	print("=== 4. PER-FRAME, attack / jump / hit / death takes: head, jaw, pelvis, spine (model space) ===")
	var probes: Array[int] = []
	for b in _skel.get_bone_count():
		var lower := _skel.get_bone_name(b).to_lower()
		for key: String in ["head", "jaw", "pelvis", "spine"]:
			if lower.contains(key):
				probes.append(b)
				break
	for take: String in STRIKE_TAKES:
		if not player.has_animation(take):
			print("-- take '%s' absent" % take)
			continue
		var anim := player.get_animation(take)
		player.play(take)
		var steps := maxi(1, int(round(anim.length * 30.0)))
		var header := "-- %s\nframe\tt" % take
		for b in probes:
			header += "\t%s.x\t.y\t.z" % _skel.get_bone_name(b)
		print(header)
		for i in steps + 1:
			var t: float = minf(float(i) / 30.0, anim.length)
			player.seek(t, true)
			var line := "%d\t%.4f" % [i, t]
			for b in probes:
				var w := skel_xform * _bone_fk(b).origin
				line += "\t%.3f\t%.3f\t%.3f" % [w.x, w.y, w.z]
			print(line)

	print("=== 5. NATURAL GROUND SPEED of the locomotion takes (model units per second) ===")
	print("take\tpaw\tstance_frames\tspeed\tdir.x\tdir.z")
	for take: String in GROUND_TAKES:
		if not player.has_animation(take):
			print("-- take '%s' absent" % take)
			continue
		_print_ground_speed(player, take, skel_xform)

	print("=== 6. POSTURE of the idle takes (model space): min / mean / max over the take ===")
	print("take\tbone.axis\tmin\tmean\tmax")
	for take: String in POSTURE_TAKES:
		if player.has_animation(take):
			_print_posture(player, take, skel_xform)

	print("=== 7. HEAD YAW of the locomotion takes, in degrees off the body's own axis: min / mean / max ===")
	print("take\twhat\tmin\tmean\tmax")
	for take: String in HEAD_TAKES:
		if player.has_animation(take):
			_print_head_yaw(player, take, skel_xform)

	# Table 8 (feel pass 3): the same measurement on the BUILT library's clips, which is what the scene
	# plays -- `walk_backwards` after `tools/build_hellhound_anims.gd` has straightened its head, and
	# the strafes, which that tool must leave as they are.
	print("=== 8. HEAD YAW of the BUILT library's clips (%s), same columns ===" % BUILT_LIBRARY_PATH)
	var built := load(BUILT_LIBRARY_PATH) as AnimationLibrary
	if built == null:
		print("-- no built library")
	else:
		player.add_animation_library(&"built", built)
		for clip: String in BUILT_HEAD_CLIPS:
			if player.has_animation("built/%s" % clip):
				_print_head_yaw(player, "built/%s" % clip, skel_xform)

	quit(0)


## Table 7 (feel pass 2, the operator's "going backwards the head always turns 90 degrees"). Which way
## the HEAD points relative to the BODY over a take, seen from above. The body's axis is pelvis to
## Spine03; the head's facing is square to the line through its two ear roots (at rest that line lies
## along X and the head faces +Z, the model's forward); the neck's is neck to head. Positive is to the
## hound's LEFT (+X in model space). A take that turns the head does so in the clip, whatever plays it.
func _print_head_yaw(player: AnimationPlayer, take: String, skel_xform: Transform3D) -> void:
	var anim := player.get_animation(take)
	player.play(take)
	var steps := maxi(1, int(round(anim.length * 30.0)))
	var bones := {}
	for name: String in ["Pelvis", "Spine03", "Neck", "Head", "Ear_01_L", "Ear_01_R"]:
		bones[name] = _skel.find_bone(name)
		if int(bones[name]) < 0:
			print("%s\t-- bone '%s' absent" % [take, name])
			return
	# `body`: the body's own axis off the MODEL's forward (+Z) -- a take that turns the whole body
	# under a root that stays put shows here, and its head rows are then the head looking back.
	var stats := {"body": [INF, 0.0, -INF], "head": [INF, 0.0, -INF], "neck": [INF, 0.0, -INF]}
	for i in steps + 1:
		player.seek(minf(float(i) / 30.0, anim.length), true)
		var at := {}
		for name: String in bones:
			at[name] = skel_xform * _bone_fk(int(bones[name])).origin
		var body := Vector2(at["Spine03"].x - at["Pelvis"].x, at["Spine03"].z - at["Pelvis"].z)
		var ears := Vector2(at["Ear_01_L"].x - at["Ear_01_R"].x, at["Ear_01_L"].z - at["Ear_01_R"].z)
		var facing := Vector2(-ears.y, ears.x)   # square to the ear line, pointing forward at rest
		var neck := Vector2(at["Head"].x - at["Neck"].x, at["Head"].z - at["Neck"].z)
		# The angle from the body's axis to each, turning toward +X (the hound's left) positive.
		var values := {"body": rad_to_deg(body.angle_to(Vector2(0.0, 1.0))),
				"head": rad_to_deg(facing.angle_to(body)), "neck": rad_to_deg(neck.angle_to(body))}
		for what: String in values:
			var row: Array = stats[what]
			row[0] = minf(row[0], values[what])
			row[1] += values[what]
			row[2] = maxf(row[2], values[what])
	for what: String in stats:
		var row: Array = stats[what]
		print("%s\t%s\t%.1f\t%.1f\t%.1f" % [take, what, row[0], row[1] / float(steps + 1), row[2]])


## Table 5. Every take is in place, so its ground speed is not in the root: it is the speed at which a
## PLANTED paw is carried under the body. A paw is in stance on the frames where it is within
## `STANCE_HEIGHT` of its own lowest point; its planar velocity there (central difference, wrapping
## round the loop) is the ground moving past, and the take's natural speed is the mean over the four
## paws. The direction printed is the paw's, so the body's travel is the opposite one.
func _print_ground_speed(player: AnimationPlayer, take: String, skel_xform: Transform3D) -> void:
	var anim := player.get_animation(take)
	player.play(take)
	var steps := maxi(1, int(round(anim.length * 30.0)))
	var total := 0.0
	var paws := 0
	for paw: String in PAW_BONES:
		var bone := _skel.find_bone(paw)
		if bone < 0:
			continue
		var points: Array[Vector3] = []
		for i in steps:
			player.seek(float(i) / 30.0, true)
			points.append(skel_xform * _bone_fk(bone).origin)
		var low := INF
		for p in points:
			low = minf(low, p.y)
		var speed_sum := 0.0
		var direction := Vector2.ZERO
		var stance := 0
		for i in steps:
			if points[i].y > low + STANCE_HEIGHT:
				continue
			var before := points[(i + steps - 1) % steps]
			var after := points[(i + 1) % steps]
			var velocity := Vector2(after.x - before.x, after.z - before.z) * 15.0
			speed_sum += velocity.length()
			direction += velocity
			stance += 1
		if stance == 0:
			continue
		var speed := speed_sum / stance
		var mean_dir := direction.normalized()
		print("%s\t%s\t%d\t%.3f\t%.3f\t%.3f" % [take, paw, stance, speed, mean_dir.x, mean_dir.y])
		total += speed
		paws += 1
	if paws > 0:
		print("%s\tMEAN\t\t%.3f" % [take, total / paws])


## Table 6. How a take STANDS: the pelvis and head heights, and how far the head swings side to side.
func _print_posture(player: AnimationPlayer, take: String, skel_xform: Transform3D) -> void:
	var anim := player.get_animation(take)
	player.play(take)
	var steps := maxi(1, int(round(anim.length * 30.0)))
	for probe: Array in [["Pelvis", 1], ["Spine03", 1], ["Head", 1], ["Head", 0], ["Head", 2]]:
		var bone := _skel.find_bone(probe[0])
		if bone < 0:
			continue
		var low := INF
		var high := -INF
		var sum := 0.0
		for i in steps + 1:
			player.seek(minf(float(i) / 30.0, anim.length), true)
			var value: float = (skel_xform * _bone_fk(bone).origin)[probe[1]]
			low = minf(low, value)
			high = maxf(high, value)
			sum += value
		print("%s\t%s.%s\t%.3f\t%.3f\t%.3f" % [take, probe[0], "xyz"[probe[1]], low, sum / (steps + 1), high])
