extends SceneTree

## Story 7-3 (ACs 14, 17, 19) machine contract: hound_actor.tscn carries the Hellhound's ONE
## AnimationPlayer with EXACTLY the twelve named clips and their loop flags, `T_Pose` reaches neither
## the scene nor the imported model, and the two owner skins are the purple and the red one.
## `test_unit_rig_clips.gd`'s counterpart for the hound.
##
## Asserted:
##   (a) scene-wide, exactly one AnimationPlayer and exactly twelve animations (none of the model's
##       other nine takes rides in);
##   (b) the twelve expected names, each with its loop flag;
##   (c) no clip whose name is a T-pose, in the scene OR on the imported model itself -- the model
##       check is what keeps `assets/characters/hellhound/Meshes/strip_t_pose.gd` honest: unregister
##       the hook and the take comes back on the model's player;
##   (d) the scene is a unit the runner can drive: the UnitActor script, a `Hitbox`, a `Hurtbox`, a
##       body `Collision`, a `HoundAnimationController`, and NO `Mesh/Totem` child (the runner's
##       totem test);
##   (e) AC 14: `apply_owner_skin(0)` puts the PURPLE diffuse on the mesh and `apply_owner_skin(1)`
##       the RED one, and a slot with no skin applies nothing;
##   (f) AC 14/AC 19: the cyan skin is not in the tree;
##   (g) the model is mounted facing the scene's forward, feet on the ground, at hound size
##       (`_check_mount`; `test_unit_model_facing.gd` / `test_unit_vertical_alignment.gd`'s counterpart).
##
## Structure only -- read from the packed scene at instantiation, no frame needed.
##
## Run: godot --headless --path . --script res://test/integration/test_hound_rig_clips.gd

const SCENE_PATH := "res://src/actors/minions/hound_actor.tscn"
const MODEL_PATH := "res://assets/characters/hellhound/Meshes/SK_Hellhound.fbx"
const TEXTURE_DIR := "res://assets/characters/hellhound/Textures/"

const EXPECTED_LOOP := {
	&"idle": true, &"walk": true, &"run": true,
	&"walk_backwards": true, &"walk_left": true, &"walk_right": true,
	&"run_left": true, &"run_right": true,
	&"attack": false, &"leap": false, &"hit": false, &"death": false,
}

## The takes the importer yields from the model once `T_Pose` is stripped (22 in the file).
const MODEL_TAKES := 21

var _failures: Array[String] = []


func _initialize() -> void:
	var ps: PackedScene = load(SCENE_PATH)
	if ps == null:
		print("RESULT: FAIL")
		print("  FAILED: hound_actor.tscn did not load")
		quit(1)
		return
	var hound := ps.instantiate()

	var players := hound.find_children("*", "AnimationPlayer", true, false)
	_check(players.size() == 1, "expected exactly 1 AnimationPlayer in the scene, found %d" % players.size())
	var names: Array[StringName] = []
	for p in players:
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			names.append(n)
			_check(not _is_t_pose(n), "forbidden clip in the scene: '%s'" % n)
			if EXPECTED_LOOP.has(n):
				var loops := ap.get_animation(n).loop_mode != Animation.LOOP_NONE
				_check(loops == EXPECTED_LOOP[n], "clip '%s' loop=%s, expected %s" % [n, loops, EXPECTED_LOOP[n]])
	_check(names.size() == EXPECTED_LOOP.size(),
			"expected exactly %d clips, found %d: %s" % [EXPECTED_LOOP.size(), names.size(), names])
	# Feel pass ("slide in the animations"): THE LEAP CLIP DOES NOT CARRY THE BODY FORWARD ITSELF. The
	# runner moves a leaping hound its authored distance; the pack's take also throws the pelvis 2.2
	# model units forward and brings it back in recovery, which landed the mesh past the actor and slid
	# it back while state held it rooted. tools/build_hellhound_anims.gd holds the pelvis on the line
	# it starts from. Read off the clip the scene plays: no key forward of the first, the crouch before
	# take-off and the height of the jump still there.
	if players.size() == 1 and (players[0] as AnimationPlayer).has_animation(&"leap"):
		var travel := _pelvis_travel((players[0] as AnimationPlayer).get_animation(&"leap"))
		_check(travel["found"], "the `leap` clip has no pelvis position track")
		if travel["found"]:
			_check(travel["forward"] < 0.01,
					"the `leap` clip throws the pelvis %.3f model units forward of where it starts" % travel["forward"])
			_check(travel["back"] > 0.1, "the `leap` clip lost its crouch (the pelvis goes back only %.3f)" % travel["back"])
			_check(travel["height"] > 0.3, "the `leap` clip lost its jump (the pelvis rises and falls only %.3f)" % travel["height"])
	# Feel pass 3 ("backing off looks like a strafe"): THE BACKWARD WALK LOOKS WHERE ITS BODY POINTS.
	# The pack's take turns the head 107 to 119 degrees over the shoulder; the build tool gives
	# `walk_backwards` the forward walk's neck and head rotations. Read off the clips the scene plays:
	# those two tracks are the walk's, key for key; a leg and the pelvis are NOT (the rest of the take
	# is as authored); and the strafes' heads, which are meant to look back, are not the walk's either.
	if players.size() == 1:
		var library := players[0] as AnimationPlayer
		for bone: String in ["Neck", "Head"]:
			_check(_same_rotation(library, &"walk_backwards", &"walk", bone),
					"`walk_backwards` does not carry the forward walk's %s rotation: its head is not straightened" % bone)
			for strafe: StringName in [&"walk_left", &"walk_right", &"run_left", &"run_right"]:
				_check(not _same_rotation(library, strafe, &"walk", bone),
						"`%s` carries the forward walk's %s rotation: the strafes must stay as authored" % [strafe, bone])
		for bone: String in ["Pelvis", "Hip_L", "Spine02"]:
			_check(not _same_rotation(library, &"walk_backwards", &"walk", bone),
					"`walk_backwards` carries the forward walk's %s rotation: only the neck and head are changed" % bone)
	for want: StringName in EXPECTED_LOOP:
		_check(names.has(want), "missing expected clip '%s'" % want)

	_check(hound is UnitActor, "the scene root is not a UnitActor")
	for child: String in ["Collision", "Hurtbox", "Hitbox", "AnimationController"]:
		_check(hound.get_node_or_null(child) != null, "the scene has no `%s` node" % child)
	_check(hound.get_node_or_null("AnimationController") is HoundAnimationController,
			"the scene's AnimationController is not a HoundAnimationController")
	_check(hound.get_node_or_null("Mesh/Totem") == null, "the scene carries a `Mesh/Totem` child (the totem test)")

	if hound is UnitActor:
		var actor := hound as UnitActor
		var mesh := actor.get_node_or_null(actor.skin_mesh_path) as MeshInstance3D
		_check(mesh != null, "skin_mesh_path does not name a MeshInstance3D")
		if mesh != null:
			_check(mesh.material_override == null, "the mesh wears a skin before any owner is known")
			_check(not actor.apply_owner_skin(2), "a slot with no authored skin applied one")
			_check(mesh.material_override == null, "a slot with no authored skin changed the mesh")
			_check(actor.apply_owner_skin(0) and _albedo_file(mesh) == "T_HellHound_Pe_D.tga",
					"P1's hound does not wear the purple skin (got '%s')" % _albedo_file(mesh))
			_check(actor.apply_owner_skin(1) and _albedo_file(mesh) == "T_HellHound_Rd_D.tga",
					"P2's hound does not wear the red skin (got '%s')" % _albedo_file(mesh))

	_check_mount(hound)

	var model_scene: PackedScene = load(MODEL_PATH)
	_check(model_scene != null, "SK_Hellhound.fbx did not load")
	if model_scene != null:
		var model := model_scene.instantiate()
		var takes: Array[StringName] = []
		for p in model.find_children("*", "AnimationPlayer", true, false):
			for n in (p as AnimationPlayer).get_animation_list():
				takes.append(n)
				_check(not _is_t_pose(n), "the imported model still carries '%s' (strip_t_pose.gd did not run)" % n)
		_check(takes.size() == MODEL_TAKES,
				"the imported model yields %d takes, expected %d: %s" % [takes.size(), MODEL_TAKES, takes])
		# The fixture for the leap check above: the pack's own take DOES throw the pelvis forward.
		for p in model.find_children("*", "AnimationPlayer", true, false):
			if (p as AnimationPlayer).has_animation(&"Attack01"):
				var source := _pelvis_travel((p as AnimationPlayer).get_animation(&"Attack01"))
				_check(source["found"] and source["forward"] > 1.5,
						"fixture: the pack's `Attack01` no longer throws its pelvis forward (%s)" % [source])
		model.free()

	_check(not FileAccess.file_exists(TEXTURE_DIR + "T_HellHound_Cn_D.tga"),
			"the cyan skin is in the tree (7-3/R7: it does not enter the repo)")

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("clips found: %s" % [names])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	# Never added to the tree, so never freed by one (test_unit_rig_clips.gd's 4-3b/F4 note).
	hound.free()
	quit(0 if ok else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## (g) HOW THE MODEL IS MOUNTED, read off BONES and the mesh's own bounds in the ACTOR's space -- never
## off the mount node's yaw, which is the identifier a backwards model would still satisfy
## (`test_unit_model_facing.gd`'s finding for the zombie). The scene's forward is -Z (`aim_at`,
## the `Hitbox` offset): the hound's HEAD must be on that side of its PELVIS. Its feet must rest on
## the root's plane (units spawn at y 0), and it must be dog-sized, not the 2.9 m the file imports at.
func _check_mount(hound: Node) -> void:
	var model := hound.get_node_or_null("Hellhound") as Node3D
	var skeleton := hound.get_node_or_null("Hellhound/Skeleton3D") as Skeleton3D
	var mesh := hound.get_node_or_null("Hellhound/Skeleton3D/HellHound") as MeshInstance3D
	_check(model != null and skeleton != null and mesh != null, "the scene has no Hellhound model, skeleton and mesh")
	if model == null or skeleton == null or mesh == null:
		return
	var to_actor := model.transform * skeleton.transform
	var head := to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin
	var pelvis := to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("Pelvis")).origin
	_check(head.z < pelvis.z - 0.3,
			"the hound is mounted backwards: head at z %.3f, pelvis at z %.3f (forward is -Z)" % [head.z, pelvis.z])
	_check(absf(head.x) < 0.05 and absf(pelvis.x) < 0.05, "the hound's spine is off the actor's centre line")
	var bounds := (to_actor * mesh.transform) * mesh.get_aabb()
	_check(absf(bounds.position.y) < 0.05, "the hound's feet are %.3f m off the ground plane" % bounds.position.y)
	# Feel pass: "a bit smaller". The model is 2.946 units tall; at the 0.33 mount it stands 0.97 m. The
	# band excludes the 0.4 mount it had (1.18 m) and anything under a third of a metre smaller still.
	_check(bounds.end.y > 0.85 and bounds.end.y < 1.1,
			"the hound stands %.3f m tall, outside the 0.85 to 1.10 m a hound is mounted at" % bounds.end.y)
	var hitbox := hound.get_node_or_null("Hitbox/HitboxShape") as CollisionShape3D
	_check(hitbox != null and hitbox.position.z < 0.0, "the hound's hitbox is not ahead of it (-Z)")
	_check_scaled_boxes(hound, bounds, hitbox)


## Feel pass: THE COLLISION FOLLOWS THE MODEL, AND THE BITE IS HONEST (`6-1d`). Read off the scene and
## the authored balance, never off a constant here:
##   - the BODY is a cylinder (the same shape at every yaw: the hound's root turns every tick), no
##     wider than the drawn body and standing on the ground;
##   - the HURTBOX covers the drawn body nose to rump, within a tenth of a metre each way;
##   - the HITBOX starts in front of the body's own centre and its front edge is at least as far out as
##     the authored bite band: a hound may not bite from where its hitbox cannot reach;
##   - the authored stop distance is inside the bite band, so a hound that has arrived can bite.
func _check_scaled_boxes(hound: Node, bounds: AABB, hitbox: CollisionShape3D) -> void:
	var body := hound.get_node_or_null("Collision") as CollisionShape3D
	var cylinder := (body.shape if body != null else null) as CylinderShape3D
	_check(cylinder != null, "the hound's body shape is not a cylinder")
	if cylinder != null:
		_check(cylinder.radius * 2.0 <= bounds.size.x + 0.05,
				"the body cylinder (%.2f m across) is wider than the drawn body (%.2f m)" % [cylinder.radius * 2.0, bounds.size.x])
		_check(absf(body.position.y - cylinder.height * 0.5) < 0.02,
				"the body cylinder does not stand on the ground (centre %.3f, half height %.3f)"
						% [body.position.y, cylinder.height * 0.5])
		# 7-3 review fix (F1): NOT shorter than the hero's body box. A shorter body is one a hero can be
		# depenetrated UP onto (test_hero_floor_live.gd), and the hero has no gravity to come back down.
		var reference := (load("res://src/actors/hero/hero.tscn") as PackedScene).instantiate()
		var reference_body := reference.get_node_or_null("Collision") as CollisionShape3D
		var reference_box := (reference_body.shape if reference_body != null else null) as BoxShape3D
		_check(reference_box != null and cylinder.height >= reference_box.size.y,
				"the body cylinder (%.2f m) is shorter than the hero's body box (%s)"
						% [cylinder.height, reference_box.size.y if reference_box != null else "missing"])
		reference.free()
	var hurt := hound.get_node_or_null("Hurtbox/HurtboxShape") as CollisionShape3D
	var hurt_box := (hurt.shape if hurt != null else null) as BoxShape3D
	_check(hurt_box != null, "the hound's hurtbox is not a box")
	if hurt_box != null:
		_check(absf(hurt_box.size.z - bounds.size.z) < 0.2,
				"the hurtbox is %.2f m long, the drawn body %.2f m" % [hurt_box.size.z, bounds.size.z])
		_check(hurt_box.size.x <= bounds.size.x + 0.1 and hurt_box.size.y <= bounds.end.y,
				"the hurtbox (%s) is larger than the drawn body (%s)" % [hurt_box.size, bounds.size])
	var hit_box := (hitbox.shape if hitbox != null else null) as BoxShape3D
	_check(hit_box != null, "the hound's hitbox is not a box")
	var config := load("res://data/balance/balance_config.tres") as BalanceConfig
	var kind := config.kind_at(config.kind_index_of(&"hellhound")) if config != null else null
	_check(kind != null and kind.attack_at(0) != null, "the authored balance carries no hellhound bite")
	if hit_box == null or kind == null or kind.attack_at(0) == null:
		return
	var near_edge := -hitbox.position.z - hit_box.size.z * 0.5
	var front_edge := -hitbox.position.z + hit_box.size.z * 0.5
	var bite_range := kind.attack_at(0).range
	_check(near_edge > 0.0 and near_edge < 0.5, "the hitbox begins %.3f m ahead of the hound's centre" % near_edge)
	# Feel pass 2: the bite LUNGES. The band may reach as far as the hitbox's front edge carried forward
	# by the lunge the bite ALWAYS makes (its authored minimum travel), and no further. And the bite
	# stops short of the point it aimed at by a distance the hitbox covers, so a bite that goes its
	# distance has that point inside the box.
	var bite := kind.attack_at(0)
	_check(bite_range <= front_edge + bite.travel_min_distance + 0.001,
			"the authored bite band (%.2f m) reaches past the hitbox's front edge (%.3f m) plus the lunge (%.2f m): not honest geometry"
					% [bite_range, front_edge, bite.travel_min_distance])
	_check(-bite.travel_overshoot >= near_edge and -bite.travel_overshoot <= front_edge,
			"the bite stops %.2f m short of the point it aimed at, which its hitbox (%.3f to %.3f m ahead) does not cover"
					% [-bite.travel_overshoot, near_edge, front_edge])
	# Feel pass 3: THE LEAP LANDS CLEAR OF A HERO'S BODY. Its overshoot floor is at least the hero's
	# body half-width plus the hound's body radius plus a small margin, both read off the scenes.
	var leap := kind.attack_at(1)
	var hero := (load("res://src/actors/hero/hero.tscn") as PackedScene).instantiate()
	var hero_body := hero.get_node_or_null("Collision") as CollisionShape3D
	var hero_box := (hero_body.shape if hero_body != null else null) as BoxShape3D
	_check(hero_box != null and leap != null and cylinder != null, "no hero body box, hound leap or hound body to measure the landing against")
	if hero_box != null and leap != null and cylinder != null:
		var clear := maxf(hero_box.size.x, hero_box.size.z) * 0.5 + cylinder.radius
		_check(leap.travel_overshoot >= clear + 0.05 and leap.travel_overshoot <= clear + 0.3,
				"the leap lands at least %.2f m past its target: want just clear of the two bodies (%.2f m), by 0.05 to 0.3 m"
						% [leap.travel_overshoot, clear])
		_check(leap.travel_min_distance >= leap.travel_overshoot,
				"the shortest leap (%.2f m) does not carry the hound its own overshoot (%.2f m)"
						% [leap.travel_min_distance, leap.travel_overshoot])
	hero.free()
	_check(front_edge <= bounds.size.z,
			"the hitbox reaches %.3f m ahead, further than the whole hound is long (%.3f m)" % [front_edge, bounds.size.z])
	_check(kind.stop_distance < bite_range,
			"the hound halts %.2f m from its target, outside its own bite band (%.2f m)" % [kind.stop_distance, bite_range])


## How far a clip's pelvis goes, in model units, relative to its first key: `forward` (+Z, the way
## the model faces), `back`, and the `height` it rises and falls through.
## Do clips `a` and `b` of `player` carry the same rotation keys (times and values) for `bone`? False
## when either has no such track.
func _same_rotation(player: AnimationPlayer, a: StringName, b: StringName, bone: String) -> bool:
	if not player.has_animation(a) or not player.has_animation(b):
		return false
	var first := player.get_animation(a)
	var second := player.get_animation(b)
	var path := NodePath("Skeleton3D:%s" % bone)
	var track_a := first.find_track(path, Animation.TYPE_ROTATION_3D)
	var track_b := second.find_track(path, Animation.TYPE_ROTATION_3D)
	if track_a < 0 or track_b < 0 or first.track_get_key_count(track_a) != second.track_get_key_count(track_b):
		return false
	for key in first.track_get_key_count(track_a):
		if not is_equal_approx(first.track_get_key_time(track_a, key), second.track_get_key_time(track_b, key)):
			return false
		var qa: Quaternion = first.track_get_key_value(track_a, key)
		var qb: Quaternion = second.track_get_key_value(track_b, key)
		if not qa.is_equal_approx(qb):
			return false
	return true


func _pelvis_travel(anim: Animation) -> Dictionary:
	var track := anim.find_track(NodePath("Skeleton3D:Pelvis"), Animation.TYPE_POSITION_3D)
	if track < 0 or anim.track_get_key_count(track) == 0:
		return {"found": false, "forward": 0.0, "back": 0.0, "height": 0.0}
	var start: Vector3 = anim.track_get_key_value(track, 0)
	var forward := 0.0
	var back := 0.0
	var low := start.y
	var high := start.y
	for key in anim.track_get_key_count(track):
		var value: Vector3 = anim.track_get_key_value(track, key)
		forward = maxf(forward, value.z - start.z)
		back = maxf(back, start.z - value.z)
		low = minf(low, value.y)
		high = maxf(high, value.y)
	return {"found": true, "forward": forward, "back": back, "height": high - low}


## The file name of the diffuse texture the mesh's override material shows, or "".
func _albedo_file(mesh: MeshInstance3D) -> String:
	var material := mesh.material_override as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		return ""
	return material.albedo_texture.resource_path.get_file()


## `strip_t_pose.gd`'s own normalisation, restated here on purpose: the test never imports the hook.
func _is_t_pose(clip: StringName) -> bool:
	var plain := String(clip).to_lower().replace("_", "").replace(" ", "").replace("-", "")
	return plain.ends_with("tpose")
