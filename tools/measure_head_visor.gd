extends SceneTree

## Story 7-10 (Task 1, AC 1/AC 4/AC 7, M2): measures WHERE THE UNBLOCKABLE EYES GO on the paladin's head
## and whether the helmet hides them, plus the two RED counter clips' body heights the re-cut (AC 8) and
## the landing arc (AC 9) are placed against. One headless launch answers all of it.
##
## METHOD, `measure_torso_envelope.gd`'s verbatim: forward kinematics over `get_bone_pose()` (never the
## cached global pose) and CPU skinning of every vertex by its binds, so the numbers are the SURFACE the
## renderer draws rather than joint origins. Two frames are reported:
##   * MODEL space -- feet at y 0, +z the way the hero faces (the frame `hero.tscn`'s Mesh is in, offset
##     by its -1.0 grounding);
##   * HEAD-BONE space -- `mixamorig_Head`'s own frame, which is the frame a `BoneAttachment3D` on that
##     bone gives its children. The eye quads' local offsets are read straight off this.
##
## THE VISOR is the front surface of the head set (the helmet plus body vertices near the head joint, see
## `_initialize`): for each height band in head space, the
## largest extent along the head's FORWARD axis (the head-space axis that maps to model +z). A point placed
## a margin beyond that surface is in front of every helmet vertex at that height, so the depth test can
## never hide it from a camera in front of the hero -- the opponent's view.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_head_visor.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const HEAD := "mixamorig_Head"
const HEAD_TOP := "mixamorig_HeadTop_End"
## A body vertex counts as HEAD when it is within this many metres of the head joint (and not below it).
const HEAD_RADIUS := 0.28
const POSE_CLIPS: Array[StringName] = [&"idle", &"swipe", &"thrust", &"jump_attack"]
const POSE_PHASES := 8
const COUNTER_CLIPS: Array[StringName] = [&"counter_jump", &"counter_backflip"]
const COUNTER_STEP := 1.0 / 30.0
const BANDS := 12

var _skel: Skeleton3D


func _fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


func _rel(node: Node, base: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != null and n != base:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _skin(vv: Array, pose: Dictionary) -> Vector3:
	var skin: Skin = vv[4]
	var bind_bone: PackedInt32Array = vv[5]
	var bi: PackedInt32Array = vv[1]
	var wi: PackedFloat32Array = vv[2]
	var p := Vector3.ZERO
	for k in bi.size():
		p += ((pose[bind_bone[bi[k]]] as Transform3D) * skin.get_bind_pose(bi[k]) * (vv[0] as Vector3)) * wi[k]
	return p


func _initialize() -> void:
	var model: Node3D = (load(MODEL_PATH) as PackedScene).instantiate()
	root.add_child(model)
	_skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library: AnimationLibrary = load(LIBRARY_PATH)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library)
	var skel_to_model := _rel(_skel, model)
	print("skeleton->model origin %s basis-x %s scale %s" % [skel_to_model.origin, skel_to_model.basis.x,
		skel_to_model.basis.get_scale()])
	var head := _skel.find_bone(HEAD)
	var head_top := _skel.find_bone(HEAD_TOP)
	print("bones: %s=%d %s=%d" % [HEAD, head, HEAD_TOP, head_top])

	# Every skinned vertex, tagged with its mesh name and whether its dominant bone is a head bone.
	var verts: Array = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		print("mesh '%s' skinned=%s" % [mi.name, mi.skin != null])
		if mi.skin == null or mi.mesh == null:
			continue
		var bind_bone := PackedInt32Array()
		for b in mi.skin.get_bind_count():
			var bb := mi.skin.get_bind_bone(b)
			if bb < 0:
				bb = _skel.find_bone(mi.skin.get_bind_name(b))
			bind_bone.append(bb)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / pos.size()
			for v in pos.size():
				var bi := PackedInt32Array()
				var wi := PackedFloat32Array()
				var best := -1.0
				var best_bone := -1
				for k in per:
					var w := weights[v * per + k]
					if w <= 0.0:
						continue
					bi.append(bones[v * per + k])
					wi.append(w)
					if w > best:
						best = w
						best_bone = bind_bone[bones[v * per + k]]
				verts.append([pos[v], bi, wi, _skel.get_bone_name(best_bone), mi.skin, bind_bone,
					String(mi.name)])

	# 1. THE VISOR, in the idle rest frame (t = 0): head-space bands of the head-dominated vertices.
	player.play(&"idle")
	player.seek(0.0, true)
	var pose := {}
	for b in _skel.get_bone_count():
		pose[b] = _fk(b)
	var head_xf: Transform3D = pose[head]
	var head_inv := head_xf.affine_inverse()
	var head_model := skel_to_model * head_xf
	print("head joint MODEL origin %s" % head_model.origin)
	print("head basis in MODEL: x %s y %s z %s" % [head_model.basis.x, head_model.basis.y, head_model.basis.z])
	print("head top MODEL origin %s" % (skel_to_model * (pose[head_top] as Transform3D)).origin)
	# Head-space forward = the head-space direction that maps to model +z; up likewise model +y.
	var model_to_head := head_model.affine_inverse()
	var fwd := (model_to_head.basis * Vector3(0, 0, 1)).normalized()
	var up := (model_to_head.basis * Vector3(0, 1, 0)).normalized()
	var side := up.cross(fwd).normalized()
	print("head-space forward %s up %s side %s" % [fwd, up, side])
	# THE HEAD SET, chosen by GEOMETRY and not by the dominant bind (a first launch of this tool tagged
	# by the dominant bone's name and got shield and sword vertices, never the helmet -- the binds do not
	# name bones the way that filter assumed): every vertex of the `Helmet` mesh, plus every vertex of any
	# other mesh that sits within HEAD_RADIUS of the head joint and above it. The dominant-bone names of
	# the helmet's vertices are printed so the bind layout is on record.
	var lo := INF
	var hi := -INF
	var head_pts: Array[Vector3] = []
	var per_mesh := {}
	var helmet_bones := {}
	for vv in verts:
		var p_skel := _skin(vv, pose)
		var p_head: Vector3 = head_inv * p_skel
		var mesh_name: String = vv[6]
		var is_helmet := mesh_name.contains("Helmet")
		if is_helmet:
			helmet_bones[vv[3]] = int(helmet_bones.get(vv[3], 0)) + 1
		elif p_head.length() > HEAD_RADIUS or p_head.dot(up) < -0.05:
			continue
		head_pts.append(p_head)
		var u := p_head.dot(up)
		lo = minf(lo, u)
		hi = maxf(hi, u)
		per_mesh[mesh_name] = int(per_mesh.get(mesh_name, 0)) + 1
	print("helmet dominant bones %s" % helmet_bones)
	print("head-set vertices %d by mesh %s; up-range [%.4f, %.4f]" % [head_pts.size(), per_mesh, lo, hi])
	for band in BANDS:
		var b_lo := lo + (hi - lo) * float(band) / BANDS
		var b_hi := lo + (hi - lo) * float(band + 1) / BANDS
		var front := -INF
		var side_lo := INF
		var side_hi := -INF
		for p in head_pts:
			var u := p.dot(up)
			if u < b_lo or u > b_hi:
				continue
			front = maxf(front, p.dot(fwd))
			side_lo = minf(side_lo, p.dot(side))
			side_hi = maxf(side_hi, p.dot(side))
		print("  band up[%.4f,%.4f] front %.4f side[%.4f,%.4f]" % [b_lo, b_hi, front, side_lo, side_hi])

	# 2. HOW FAR THE HEAD MOVES in the charge poses: head origin (model) and forward axis per phase.
	for clip: StringName in POSE_CLIPS:
		var anim: Animation = library.get_animation(clip)
		player.play(clip)
		for i in POSE_PHASES + 1:
			var t := anim.length * float(i) / POSE_PHASES
			player.seek(t, true)
			var hm := skel_to_model * _fk(head)
			var top := skel_to_model * _fk(head_top).origin
			print("  pose %s t=%.3f head %s top %s head-fwd(model) %s" % [clip, t, hm.origin, top,
				(hm.basis * fwd).normalized()])

	# 3. THE RED COUNTER CLIPS: hips height and lowest foot per 1/30 s (model space).
	var hips := _skel.find_bone("mixamorig_Hips")
	var feet: Array[int] = [_skel.find_bone("mixamorig_LeftToeBase"), _skel.find_bone("mixamorig_RightToeBase"),
		_skel.find_bone("mixamorig_LeftFoot"), _skel.find_bone("mixamorig_RightFoot")]
	for clip: StringName in COUNTER_CLIPS:
		var anim: Animation = library.get_animation(clip)
		player.play(clip)
		print("==== %s length %.4f" % [clip, anim.length])
		var t := 0.0
		while t <= anim.length + 0.0001:
			player.seek(t, true)
			var low := INF
			for f in feet:
				if f >= 0:
					low = minf(low, (skel_to_model * _fk(f).origin).y)
			var hp := skel_to_model * _fk(hips).origin
			print("  t=%.4f hips_y %.4f hips_z %.4f feet_y %.4f" % [t, hp.y, hp.z, low])
			t += COUNTER_STEP
	quit(0)
