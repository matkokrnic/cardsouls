extends SceneTree

## Story 7-5b (T1, ACs 9-11): measures the imported Healer (Mixamo "Knight D Pelegrini") BEFORE anything is
## built on it. HEADLESS, NOT THE EDITOR (`3-0a/R3`). `tools/measure_hellhound_rig.gd`'s shape on the
## zombie's multi-file layout (one model FBX, one FBX per clip). Prints five tables:
##
##   1. the model's node tree, its skeleton (bone count, root bones) and every AnimationPlayer it still
##      carries (none, once `strip_model_anim.gd` has run);
##   2. per clip FBX: every AnimationPlayer and take the importer yields (the Mixamo take name), length,
##      key count on the Hips position track, and the Hips displacement -- NET (last key minus first) and
##      PEAK planar excursion from the first key. A clip whose Hips travels is not in place and would
##      fight the runner, which owns position (DECISION A, the `3-0a`/`4-3c` posture);
##   3. the model's size: each skinned mesh's rest AABB in model space (height, foot offset = its lowest
##      point) and the head and chest bones' heights at rest (the lock-mark lift derivation);
##   4. per frame of `shoot` and `cast`: each hand's position RELATIVE TO THE HIPS (forward, reach, speed),
##      `tools/measure_strike_frame.gd`'s method -- the release frame is where the casting hand ARRIVES
##      (its forward extension peaks and its speed collapses), not where the Hips moves furthest;
##   5. each mesh's surface materials and their albedo textures (the owner-tint mechanism keeps them);
##   6. (smoke fix 1, S3) `walk`'s NATURAL GROUND SPEED: every take is in place, so it is the speed at which a
##      PLANTED foot is carried back under the body (`tools/measure_hellhound_rig.gd` table 5's method), in
##      model units per second -- the speed at which the clip plays at rate 1.0 without sliding;
##   7. (smoke fix 1, S7) the model AS MOUNTED in healer_actor.tscn, in the ACTOR's space: drawn height, foot
##      offset and the chest (`mixamorig_Spine2` in `idle` at t=0, the lock-mark lift) at the scene's mount;
##   8. (smoke fix 2, S15) every clip's Hips YAW -- the twist of the Hips rotation track about the model's up,
##      net (last key against the first) and peak, in degrees: how far a turn clip turns the body by itself
##      (the runner's yaw already turns it, the paladin `6-7b` reason), and that no other clip turns at all.
##   9. (smoke fix 2, S15) feet on the floor: each clip's lowest toe and its Hips height.
##   Table 6 also reads (smoke fix 2, S15) the two strafes' natural ground speed, the walk's method; and tables 6,
##   8 and 9 run twice, on the raw takes and AS BUILT (`healer_anims.res`, what the scene plays).
##
## FORWARD KINEMATICS, NOT `get_bone_global_pose()`, for `measure_strike_frame.gd`'s measured reason: a
## `SceneTree` script processes no frames, so the global pose cache serves one stale transform.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_healer_rig.gd

const SOURCE_DIR := "res://assets/characters/healer/"
const MODEL_PATH := SOURCE_DIR + "healer.fbx"
const CLIP_FILES: Array[String] = ["idle", "walk", "cast", "shoot", "death", "hurt",
		"turn_left", "turn_right", "strafe_left", "strafe_right"]
## Table 6: the locomotion clips whose natural ground speed is read (smoke fix 2, S15: the strafes join).
const GROUND_SPEED_CLIPS: Array[String] = ["walk", "strafe_left", "strafe_right"]
const SCENE_PATH := "res://src/actors/minions/healer_actor.tscn"
## Table 6: the feet read for the walk's ground speed, and how near its lowest point (model units) a foot
## counts as planted.
const FEET: Array[String] = ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
const PLANTED_EPS := 0.03
const HIPS := "mixamorig_Hips"
## The Mixamo take every clip FBX carries (table 2).
const SOURCE_TAKE := &"mixamo_com"
## Table 4: the clips sampled frame by frame, and the bones read relative to the hips.
const STRIKE_CLIPS: Array[String] = ["shoot", "cast"]
const PROBES: Array[String] = ["mixamorig_RightHand", "mixamorig_LeftHand"]
## Table 3: the bones whose rest height is printed.
const HEIGHT_BONES: Array[String] = ["mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_Spine2",
		"mixamorig_Neck", "mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase"]
const FPS := 30.0

var _skel: Skeleton3D


func _bone_fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


## The transform from `node`'s local space to the MODEL root's, composed by hand (see the hellhound tool).
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

	print("=== 1. MODEL NODE TREE ===")
	_print_tree(model, 0)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.size() != 1:
		push_error("expected exactly 1 Skeleton3D, found %d" % skels.size())
		quit(1)
		return
	_skel = skels[0] as Skeleton3D
	var root_bones: Array[String] = []
	for b in _skel.get_bone_count():
		if _skel.get_bone_parent(b) < 0:
			root_bones.append(_skel.get_bone_name(b))
	print("skeleton path=%s bones=%d root_bones=%s" % [model.get_path_to(_skel), _skel.get_bone_count(), root_bones])
	var model_players := model.find_children("*", "AnimationPlayer", true, false)
	print("model AnimationPlayers=%d" % model_players.size())
	for node in model_players:
		print("  player %s takes=%s" % [model.get_path_to(node), (node as AnimationPlayer).get_animation_list()])

	print("=== 2. CLIP FBXs (Hips position track, model units; planar = XZ) ===")
	print("file\tplayers\ttake\tlength\tframes@30\ttracks\thips_keys\tnet(x,y,z)\tnet_planar\tpeak_planar\ty_min\ty_max")
	var library := AnimationLibrary.new()
	for clip: String in CLIP_FILES:
		var clip_scene: PackedScene = load(SOURCE_DIR + clip + ".fbx")
		if clip_scene == null:
			print("%s\t-- did not load" % clip)
			continue
		var clip_root := clip_scene.instantiate()
		var players := clip_root.find_children("*", "AnimationPlayer", true, false)
		for node in players:
			var player := node as AnimationPlayer
			for take: StringName in player.get_animation_list():
				var anim := player.get_animation(take)
				var hips_track := anim.find_track(NodePath("Skeleton3D:" + HIPS), Animation.TYPE_POSITION_3D)
				var keys := anim.track_get_key_count(hips_track) if hips_track >= 0 else 0
				var first := Vector3.ZERO
				var last := Vector3.ZERO
				var peak := 0.0
				var y_min := INF
				var y_max := -INF
				for k in keys:
					var v: Vector3 = anim.track_get_key_value(hips_track, k)
					if k == 0:
						first = v
					last = v
					peak = maxf(peak, Vector2(v.x - first.x, v.z - first.z).length())
					y_min = minf(y_min, v.y)
					y_max = maxf(y_max, v.y)
				var net := last - first
				print("%s\t%d\t%s\t%.4f\t%d\t%d\t%d\t(%.4f, %.4f, %.4f)\t%.4f\t%.4f\t%.4f\t%.4f" % [clip, players.size(),
						take, anim.length, int(round(anim.length * FPS)), anim.get_track_count(), keys,
						net.x, net.y, net.z, Vector2(net.x, net.z).length(), peak, y_min, y_max])
				if not library.has_animation(StringName(clip)):
					library.add_animation(StringName(clip), anim.duplicate(true))
		# Smoke fix 2 (S15): the clip FBX's OWN skeleton -- its Hips rest height and its scale -- so a clip that
		# stands lower than the model can be told apart as a different rig scale or a different offset.
		for node in clip_root.find_children("*", "Skeleton3D", true, false):
			var clip_skel := node as Skeleton3D
			var hips_bone := clip_skel.find_bone(HIPS)
			print("  %s skeleton scale=%s hips_rest=%s bones=%d" % [clip, clip_skel.transform.basis.get_scale(),
					clip_skel.get_bone_rest(hips_bone).origin if hips_bone >= 0 else Vector3.INF,
					clip_skel.get_bone_count()])
			var extra: Array[String] = []
			for b in clip_skel.get_bone_count():
				if _skel.find_bone(clip_skel.get_bone_name(b)) < 0:
					extra.append(clip_skel.get_bone_name(b))
			var foreign: Array[String] = []
			for node_p in players:
				var take_anim := (node_p as AnimationPlayer).get_animation(SOURCE_TAKE)
				for t in take_anim.get_track_count():
					var bone := String(take_anim.track_get_path(t).get_concatenated_subnames())
					if _skel.find_bone(bone) < 0:
						foreign.append("%s(%d)" % [bone, take_anim.track_get_type(t)])
			print("  %s bones absent from the model=%s tracks on them=%s" % [clip, extra, foreign])
		clip_root.free()

	print("=== 3. SIZE (model space, import scale) ===")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xform := _to_model(mi, model)
		var aabb := xform * mi.get_aabb()
		print("mesh %s path=%s rest_aabb pos=%s size=%s end=%s height=%.4f foot_offset(lowest y)=%.4f"
				% [mi.name, model.get_path_to(mi), aabb.position, aabb.size, aabb.end, aabb.size.y, aabb.position.y])
	var skel_xform := _to_model(_skel, model)
	print("skeleton (model space) origin=%s scale=%s" % [skel_xform.origin, skel_xform.basis.get_scale()])
	for name: String in HEIGHT_BONES:
		var b := _skel.find_bone(name)
		if b >= 0:
			print("  rest %s\t%s" % [name, skel_xform * _skel.get_bone_global_rest(b).origin])

	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library)
	if library.has_animation(&"idle"):
		player.play(&"idle")
		player.seek(0.0, true)
		print("bone heights in `idle` at t=0 (model space):")
		for name: String in HEIGHT_BONES:
			var b := _skel.find_bone(name)
			if b >= 0:
				print("  idle %s\t%s" % [name, skel_xform * _bone_fk(b).origin])

	print("=== 4. PER-FRAME hands relative to hips (forward = +Z, the model's front) ===")
	var hips_idx := _skel.find_bone(HIPS)
	for clip: String in STRIKE_CLIPS:
		if not library.has_animation(StringName(clip)) or hips_idx < 0:
			print("-- %s absent" % clip)
			continue
		var anim := library.get_animation(StringName(clip))
		player.play(StringName(clip))
		var steps := maxi(1, int(round(anim.length * FPS)))
		var dt := anim.length / float(steps)
		var header := "-- %s length=%.4f\nframe\tt\thips.y\thips.z" % [clip, anim.length]
		for name: String in PROBES:
			var short := name.replace("mixamorig_", "")
			header += "\t%s.fwd\t%s.up\t%s.reach\t%s.spd" % [short, short, short, short]
		print(header)
		var prev := {}
		for i in steps + 1:
			var t: float = minf(float(i) * dt, anim.length)
			player.seek(t, true)
			var hips := _bone_fk(hips_idx).origin
			var line := "%d\t%.4f\t%.4f\t%.4f" % [i, t, hips.y, hips.z]
			for name: String in PROBES:
				var b := _skel.find_bone(name)
				var p := _bone_fk(b).origin - hips
				var spd := 0.0
				if prev.has(name):
					spd = (p - (prev[name] as Vector3)).length() / dt
				prev[name] = p
				line += "\t%.4f\t%.4f\t%.4f\t%.4f" % [p.z, p.y, p.length(), spd]
			print(line)

	print("=== 5. MATERIALS ===")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			print("%s surface %d material=%s" % [mi.name, s, mat])
			if mat is BaseMaterial3D:
				var base := mat as BaseMaterial3D
				print("  albedo_color=%s albedo=%s normal(%s)=%s roughness=%s metallic=%s/%s emission(%s)=%s"
						% [base.albedo_color, _path_of(base.albedo_texture), base.normal_enabled,
						_path_of(base.normal_texture), _path_of(base.roughness_texture), base.metallic,
						_path_of(base.metallic_texture), base.emission_enabled, _path_of(base.emission_texture)])

	_locomotion_tables(player, library, skel_xform, hips_idx, "the raw takes")
	# Smoke fix 2 (S15): THE SAME THREE TABLES ON THE BUILT LIBRARY (`tools/build_healer_anims.gd`'s output) --
	# what the scene actually plays: the strafes' natural ground speed only exists once their Hips X/Z is zeroed,
	# and a neutralised turn must read zero yaw here.
	var built: AnimationLibrary = load(SOURCE_DIR + "healer_anims.res")
	if built != null:
		player.remove_animation_library(&"")
		player.add_animation_library(&"", built)
		_locomotion_tables(player, built, skel_xform, hips_idx, "AS BUILT (healer_anims.res)")
		player.remove_animation_library(&"")
		player.add_animation_library(&"", library)

	print("=== 7. AS MOUNTED (%s, actor space) ===" % SCENE_PATH)
	var actor := (load(SCENE_PATH) as PackedScene).instantiate()
	_mounted_table(actor, library, player, skel_xform)
	quit(0)


## Tables 6, 8 and 9 over `library` (played through `player`), headed with `tag`.
func _locomotion_tables(player: AnimationPlayer, library: AnimationLibrary, skel_xform: Transform3D, hips_idx: int,
		tag: String) -> void:
	print("=== 6. GROUND SPEED, %s (model space; planted = within %.3f of the foot's lowest point) ==="
			% [tag, PLANTED_EPS])
	for clip: String in GROUND_SPEED_CLIPS:
		if not library.has_animation(StringName(clip)):
			print("-- %s absent" % clip)
			continue
		var walk := library.get_animation(StringName(clip))
		player.play(StringName(clip))
		var steps := maxi(1, int(round(walk.length * FPS)))
		var dt := walk.length / float(steps)
		var tracks := {}
		for name: String in FEET:
			tracks[name] = []
		for i in steps + 1:
			player.seek(minf(float(i) * dt, walk.length), true)
			for name: String in FEET:
				(tracks[name] as Array).append(skel_xform * _bone_fk(_skel.find_bone(name)).origin)
		var total := 0.0
		var samples := 0
		for name: String in FEET:
			var path: Array = tracks[name]
			var low := INF
			for p: Vector3 in path:
				low = minf(low, p.y)
			var sum := 0.0
			var count := 0
			var along := Vector2.ZERO
			for i in range(1, path.size()):
				var a: Vector3 = path[i - 1]
				var b: Vector3 = path[i]
				if a.y <= low + PLANTED_EPS and b.y <= low + PLANTED_EPS:
					sum += Vector2(b.x - a.x, b.z - a.z).length() / dt
					along += Vector2(b.x - a.x, b.z - a.z)
					count += 1
			print("%s %s lowest_y=%.4f planted_steps=%d mean_planted_speed=%.4f planted_travel(x,z)=%s" % [clip,
					name, low, count, sum / float(count) if count > 0 else 0.0, along])
			total += sum
			samples += count
		print("%s GROUND SPEED (model units/s): %.4f over %d planted steps" % [clip, total / float(maxi(samples, 1)),
				samples])

	print("=== 8. HIPS YAW, %s (degrees about the model's up; twist of the Hips rotation track) ===" % tag)
	print("clip\tkeys\tnet_yaw\tpeak_yaw\tlength")
	for clip: String in CLIP_FILES:
		if not library.has_animation(StringName(clip)):
			print("%s\t-- absent" % clip)
			continue
		var anim := library.get_animation(StringName(clip))
		var rot := anim.find_track(NodePath("Skeleton3D:" + HIPS), Animation.TYPE_ROTATION_3D)
		if rot < 0 or anim.track_get_key_count(rot) == 0:
			print("%s\t0\t-- no Hips rotation track" % clip)
			continue
		var keys := anim.track_get_key_count(rot)
		var first_yaw := _yaw_of(anim.track_get_key_value(rot, 0))
		var peak_yaw := 0.0
		var net_yaw := 0.0
		for k in keys:
			var d := rad_to_deg(angle_difference(first_yaw, _yaw_of(anim.track_get_key_value(rot, k))))
			if absf(d) > absf(peak_yaw):
				peak_yaw = d
			net_yaw = d
		print("%s\t%d\t%.2f\t%.2f\t%.4f" % [clip, keys, net_yaw, peak_yaw, anim.length])

	print("=== 9. FEET ON THE FLOOR, %s (model space): lowest toe y, and the Hips y at its first key ===" % tag)
	print("clip\tlowest_toe_y\thips_y_first\thips_y_mean")
	for clip: String in CLIP_FILES:
		if not library.has_animation(StringName(clip)):
			continue
		var anim := library.get_animation(StringName(clip))
		player.play(StringName(clip))
		var steps := maxi(1, int(round(anim.length * FPS)))
		var dt := anim.length / float(steps)
		var lowest := INF
		var hips_first := 0.0
		var hips_sum := 0.0
		for i in steps + 1:
			player.seek(minf(float(i) * dt, anim.length), true)
			for name: String in FEET:
				lowest = minf(lowest, (skel_xform * _bone_fk(_skel.find_bone(name)).origin).y)
			var hips_y := (skel_xform * _bone_fk(hips_idx).origin).y
			if i == 0:
				hips_first = hips_y
			hips_sum += hips_y
		print("%s\t%.4f\t%.4f\t%.4f" % [clip, lowest, hips_first, hips_sum / float(steps + 1)])


## Table 7: the model as mounted in the actor scene.
func _mounted_table(actor: Node, library: AnimationLibrary, player: AnimationPlayer, skel_xform: Transform3D) -> void:
	root.add_child(actor)
	var mount := actor.get_node_or_null("Healer") as Node3D
	var mounted := actor.get_node_or_null("Healer/Skeleton3D") as Skeleton3D
	if mount == null or mounted == null:
		print("-- the scene has no Healer mount or skeleton")
	else:
		var to_actor := mount.transform * mounted.transform
		var bottom := INF
		var top := -INF
		for node in mounted.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var bounds := (to_actor * mesh.transform) * mesh.get_aabb()
			bottom = minf(bottom, bounds.position.y)
			top = maxf(top, bounds.end.y)
		print("mount scale=%s drawn top=%.4f foot offset=%.4f height=%.4f" % [mount.transform.basis.get_scale(), top,
				bottom, top - bottom])
		var spine := _skel.find_bone("mixamorig_Spine2")
		if spine >= 0 and library.has_animation(&"idle"):
			player.play(&"idle")
			player.seek(0.0, true)
			print("lock-mark lift (Spine2 in idle at t=0, actor y)=%.4f"
					% (mount.transform * (skel_xform * _bone_fk(spine).origin)).y)
	actor.free()


## The yaw (radians, about +Y) of `q`'s twist about the up axis -- `tools/add_paladin_locomotion.gd`'s
## swing-twist split, read as an angle. The FBX Hips is a root bone, so its rotation is in skeleton space.
static func _yaw_of(q: Quaternion) -> float:
	var twist := Quaternion(0.0, q.y, 0.0, q.w)
	if twist.length_squared() < 1e-12:
		return 0.0
	twist = twist.normalized()
	return 2.0 * atan2(twist.y, twist.w)


func _path_of(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else "<none>"
