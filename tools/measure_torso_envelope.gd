extends SceneTree

## Story 7-8 (T3a, D2, 7-8/R9): measures the paladin's SKINNED-VERTEX trunk envelope -- the
## surface, not the joint origins the authoring pass could read -- in the five clips the hero hit
## shape must cover (idle, block, attack, roll, jump_attack), and where the trunk sits relative to
## the root during the roll excursion. The hero hit shape's dimensions in `hero.tscn` are chosen
## from this tool's output.
##
## METHOD. Each vertex is skinned on the CPU as the renderer does it: per bind, the skeleton-space
## bone pose (forward kinematics over `get_bone_pose()`, the uncached read
## `measure_charge_strike_frames.gd` documents) times the Skin's bind pose, blended by the vertex
## weights. A vertex belongs to the TRUNK when its dominant bone is the hips, a spine, the neck or
## the head; LEG and ARM vertices (arm = everything else: shoulders, arms, hands, sword, shield) are
## reported separately and never widen the trunk numbers. Coordinates are the MODEL frame (feet at
## y 0, +z the way the hero faces), and every extent is ALSO given relative to each candidate
## tracking bone, because the hit shape follows a bone by position only (5-0a precedent) and has to
## cover the trunk around wherever that bone is. RADIAL is the planar distance from the bone's
## planar position -- the number a yaw-invariant (cylinder) shape is sized from.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_torso_envelope.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [&"idle", &"block", &"attack", &"roll", &"jump_attack"]
const PHASES := 24
const TRUNK_BONES: Array[String] = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1",
	"mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head", "mixamorig_HeadTop_End"]
const LEG_MARKERS: Array[String] = ["UpLeg", "Leg", "Foot", "Toe"]
const CANDIDATES: Array[String] = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1",
	"mixamorig_Spine2"]

var _skel: Skeleton3D


func _fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


func _region(bone_name: String) -> String:
	if bone_name in TRUNK_BONES:
		return "trunk"
	for m in LEG_MARKERS:
		if bone_name.contains(m):
			return "leg"
	return "arm"


## Local transforms accumulated by hand up to `base` -- no tree needed (test_vertical_alignment.gd).
func _rel(node: Node, base: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != null and n != base:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


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
	print("skeleton->model origin %s basis-x %s" % [skel_to_model.origin, skel_to_model.basis.x])

	# Flatten every skinned vertex once: [rest pos, bind indices, weights, region, skin, bind->bone].
	var verts: Array = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
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
				verts.append([pos[v], bi, wi, _region(_skel.get_bone_name(best_bone)), mi.skin, bind_bone])
	print("skinned vertices: %d" % verts.size())

	for clip: StringName in CLIPS:
		var anim: Animation = library.get_animation(clip)
		player.play(clip)
		print("==== clip=%s length=%.4f" % [clip, anim.length])
		# Per candidate, union over phases: trunk radial max, trunk y range rel, leg y-min rel, arm radial max.
		var stats := {}
		for c in CANDIDATES:
			stats[c] = {"rad": 0.0, "ylo": INF, "yhi": -INF, "feet": INF, "arm_rad": 0.0}
		for i in PHASES + 1:
			var t: float = anim.length * float(i) / float(PHASES)
			player.seek(t, true)
			var pose := {}
			for b in _skel.get_bone_count():
				pose[b] = _fk(b)
			var origins := {}
			for c in CANDIDATES:
				origins[c] = skel_to_model * (pose[_skel.find_bone(c)] as Transform3D).origin
			var cen := Vector3.ZERO
			var n := 0
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			var feet := INF
			for vv in verts:
				var skin: Skin = vv[4]
				var bind_bone: PackedInt32Array = vv[5]
				var bi: PackedInt32Array = vv[1]
				var wi: PackedFloat32Array = vv[2]
				var p := Vector3.ZERO
				for k in bi.size():
					p += ((pose[bind_bone[bi[k]]] as Transform3D) * skin.get_bind_pose(bi[k]) * (vv[0] as Vector3)) * wi[k]
				p = skel_to_model * p
				var region: String = vv[3]
				if region == "leg":
					feet = minf(feet, p.y)
				for c in CANDIDATES:
					var o: Vector3 = origins[c]
					var st: Dictionary = stats[c]
					var r := Vector2(p.x - o.x, p.z - o.z).length()
					if region == "trunk":
						st["rad"] = maxf(st["rad"], r)
						st["ylo"] = minf(st["ylo"], p.y - o.y)
						st["yhi"] = maxf(st["yhi"], p.y - o.y)
					elif region == "leg":
						st["feet"] = minf(st["feet"], p.y - o.y)
					else:
						st["arm_rad"] = maxf(st["arm_rad"], r)
				if region == "trunk":
					cen += p
					n += 1
					lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
					hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
			cen /= float(n)
			var line := "  t=%.3f trunk centroid(%.3f,%.3f,%.3f) x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f] feet_y %.3f |" \
				% [t, cen.x, cen.y, cen.z, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, feet]
			for c in CANDIDATES:
				var o: Vector3 = origins[c]
				line += " %s(%.3f,%.3f,%.3f)" % [c.trim_prefix("mixamorig_"), o.x, o.y, o.z]
			print(line)
		for c in CANDIDATES:
			var st: Dictionary = stats[c]
			print("  REL %s: trunk radial max %.3f | trunk y [%.3f, %.3f] | feet y %.3f | arm radial max %.3f"
				% [c, st["rad"], st["ylo"], st["yhi"], st["feet"], st["arm_rad"]])
	quit(0)
