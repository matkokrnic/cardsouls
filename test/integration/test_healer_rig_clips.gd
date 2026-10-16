extends SceneTree

## Story 7-5b (ACs 9, 11) machine contract: healer_actor.tscn carries the Healer's ONE AnimationPlayer with
## EXACTLY the six named clips and their loop flags, the model's Mixamo take reaches neither the scene nor the
## imported model, and the actor is a unit the runner can drive -- with a hurtbox, NO hitbox, a body at least
## the hero's height on the ground, the model mounted facing the scene's forward with its feet on the floor,
## and the two owner skins. `test_hound_rig_clips.gd`'s counterpart for the Healer.
##
## Asserted:
##   (a) scene-wide, exactly one AnimationPlayer and exactly ten animations (smoke fix 1, S6: `hurt` is sixth;
##       smoke fix 2, S15: the two turns and the two strafes);
##   (b) the ten expected names, each with its loop flag (idle, walk, the strafes loop; cast, shoot, death, hurt
##       and the turns one-shot),
##       and `hurt` in place (its Hips' net planar travel under 1 cm: it never moves the body);
##   (c) no `mixamo_com` clip in the scene OR on the imported model (the model check keeps
##       assets/characters/healer/strip_model_anim.gd honest: unregister the hook and the take comes back);
##   (d) `death` stands where its actor stands: every Hips key's X and Z is 0.0 and the fall (Y) is kept --
##       tools/build_healer_anims.gd's net-gated zeroing of the clip's 1.58 m topple;
##   (e) a UnitActor with `Collision`, `Hurtbox` (layer 2, mask 0, monitoring off) and a
##       `HealerAnimationController`, and NO `Hitbox` and NO `Mesh/Totem` child;
##   (f) the body is a cylinder at least as tall as the hero's body box, standing on the ground (7-3/R38);
##   (g) `apply_owner_skin(0)` dresses the skinned mesh in the P1 skin and `(1)` in the P2 skin, both keeping
##       the Healer's own albedo texture, the two tints differ, and a slot with no skin applies nothing;
##   (h) the model is mounted facing -Z (toes ahead of the ankles), its feet on the root's plane, DRAWN 1.60 to
##       1.72 m tall (smoke fix 1, S7: the 0.8 mount, about 1.66 m, the paladin's height -- the native 2.07 m and
##       a mount applied twice, 1.32 m, both fail), and the HURTBOX fits that drawn body: its bottom on the
##       ground and its top within 5 cm of the drawn top, while the body cylinder of (f) stays the hero's height;
##   (i) (smoke fix 2, S15: SIX -> TEN) the two TURNS and the two STRAFES: every Hips key's X and Z is 0.0 (the
##       strafes travel 1.75 / 1.86 model units and the turns drift 3 cm as downloaded -- zeroed, the body turns
##       and strafes where its actor stands), the turns' Hips YAW is neutralised (net and peak under half a degree
##       about the up axis, where the downloads turn +90 / -90: the runner's yaw turns the actor, the clip must
##       not turn it twice), and each STANDS ON THE MODEL'S RIG: its first Hips height within 0.1 model units of
##       `idle`'s (a clip exported on another Mixamo character -- the paladin's, measured -- stands 0.2 lower,
##       its feet in the floor).
##
## Structure only -- read from the packed scene at instantiation, no frame needed.
##
## Run: godot --headless --path . --script res://test/integration/test_healer_rig_clips.gd

const SCENE_PATH := "res://src/actors/minions/healer_actor.tscn"
const MODEL_PATH := "res://assets/characters/healer/healer.fbx"
const ALBEDO_FILE := "healer_0.png"

const EXPECTED_LOOP := {
	&"idle": true, &"walk": true, &"cast": false, &"shoot": false, &"death": false, &"hurt": false,
	&"turn_left": false, &"turn_right": false, &"strafe_left": true, &"strafe_right": true,
}

## (i) the smoke-fix-2 clips, the turns among them whose Hips yaw is neutralised, and the two bounds.
const IN_PLACE_CLIPS: Array[StringName] = [&"turn_left", &"turn_right", &"strafe_left", &"strafe_right"]
const YAW_NEUTRAL_CLIPS: Array[StringName] = [&"turn_left", &"turn_right"]
const YAW_EPS_DEGREES := 0.5
const RIG_HEIGHT_EPS := 0.1

## (h) the drawn height band at the 0.8 mount, and how near the drawn top the hurtbox's top must sit.
const DRAWN_MIN := 1.60
const DRAWN_MAX := 1.72
const HURTBOX_FIT := 0.05

const FORBIDDEN_TAKE := &"mixamo_com"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

var _failures: Array[String] = []


func _initialize() -> void:
	var ps: PackedScene = load(SCENE_PATH)
	if ps == null:
		print("RESULT: FAIL")
		print("  FAILED: healer_actor.tscn did not load")
		quit(1)
		return
	var healer := ps.instantiate()

	var players := healer.find_children("*", "AnimationPlayer", true, false)
	_check(players.size() == 1, "expected exactly 1 AnimationPlayer in the scene, found %d" % players.size())
	var names: Array[StringName] = []
	for p in players:
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			names.append(n)
			_check(n != FORBIDDEN_TAKE, "forbidden clip in the scene: '%s' (the model's take leaked in)" % n)
			if EXPECTED_LOOP.has(n):
				var loops := ap.get_animation(n).loop_mode != Animation.LOOP_NONE
				_check(loops == EXPECTED_LOOP[n], "clip '%s' loop=%s, expected %s" % [n, loops, EXPECTED_LOOP[n]])
	_check(names.size() == EXPECTED_LOOP.size(),
			"expected exactly %d clips, found %d: %s" % [EXPECTED_LOOP.size(), names.size(), names])
	for want: StringName in EXPECTED_LOOP:
		_check(names.has(want), "missing expected clip '%s'" % want)
	if players.size() == 1 and (players[0] as AnimationPlayer).has_animation(&"death"):
		_check_death_in_place((players[0] as AnimationPlayer).get_animation(&"death"))
	if players.size() == 1 and (players[0] as AnimationPlayer).has_animation(&"hurt"):
		_check_hurt_in_place((players[0] as AnimationPlayer).get_animation(&"hurt"))
	if players.size() == 1:
		_check_new_clips(players[0] as AnimationPlayer)

	_check(healer is UnitActor, "the scene root is not a UnitActor")
	for child: String in ["Collision", "Hurtbox", "AnimationController"]:
		_check(healer.get_node_or_null(child) != null, "the scene has no `%s` node" % child)
	_check(healer.get_node_or_null("Hitbox") == null, "the scene carries a `Hitbox` (the Healer never attacks)")
	_check(healer.get_node_or_null("AnimationController") is HealerAnimationController,
			"the scene's AnimationController is not a HealerAnimationController")
	_check(healer.get_node_or_null("Mesh/Totem") == null, "the scene carries a `Mesh/Totem` child (the totem test)")
	var hurtbox := healer.get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		_check(hurtbox.collision_layer == 2 and hurtbox.collision_mask == 0 and not hurtbox.monitoring,
				"the hurtbox is off the convention: layer %d mask %d monitoring %s"
						% [hurtbox.collision_layer, hurtbox.collision_mask, hurtbox.monitoring])
		_check(hurtbox.get_node_or_null("HurtboxShape") is CollisionShape3D, "the hurtbox has no HurtboxShape")

	_check_body(healer)
	if healer is UnitActor:
		_check_skins(healer as UnitActor)
	_check_mount(healer)

	var model_scene: PackedScene = load(MODEL_PATH)
	_check(model_scene != null, "healer.fbx did not load")
	if model_scene != null:
		var model := model_scene.instantiate()
		var model_players := model.find_children("*", "AnimationPlayer", true, false)
		_check(model_players.is_empty(),
				"the imported model still carries %d AnimationPlayer(s) (strip_model_anim.gd did not run)" % model_players.size())
		for p in model_players:
			_check(not (p as AnimationPlayer).has_animation(FORBIDDEN_TAKE),
					"the imported model still carries '%s'" % FORBIDDEN_TAKE)
		model.free()

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("clips found: %s" % [names])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	healer.free()
	quit(0 if ok else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## (d) `death` keeps its fall but not its travel.
func _check_death_in_place(anim: Animation) -> void:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	_check(track >= 0 and anim.track_get_key_count(track) > 0, "the `death` clip has no Hips position keys")
	if track < 0:
		return
	var low := INF
	var high := -INF
	for key in anim.track_get_key_count(track):
		var v: Vector3 = anim.track_get_key_value(track, key)
		if v.x != 0.0 or v.z != 0.0:
			_check(false, "the `death` clip's Hips key %d travels (%.4f, %.4f): its topple is not zeroed" % [key, v.x, v.z])
			return
		low = minf(low, v.y)
		high = maxf(high, v.y)
	_check(high - low > 0.5, "the `death` clip lost its fall (the Hips drop only %.3f)" % (high - low))


## (b) `hurt` is a reaction in place: its Hips end where they began, planar.
func _check_hurt_in_place(anim: Animation) -> void:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	_check(track >= 0 and anim.track_get_key_count(track) > 0, "the `hurt` clip has no Hips position keys")
	if track < 0 or anim.track_get_key_count(track) == 0:
		return
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var last: Vector3 = anim.track_get_key_value(track, anim.track_get_key_count(track) - 1)
	var net := Vector2(last.x - first.x, last.z - first.z).length()
	_check(net < 0.01, "the `hurt` clip's Hips travel %.4f planar: it is not in place" % net)


## (i) the turns and the strafes: in place, the turns' yaw neutralised, every one on the model's own rig.
func _check_new_clips(ap: AnimationPlayer) -> void:
	var idle_y := _first_hips_y(ap.get_animation(&"idle")) if ap.has_animation(&"idle") else INF
	for clip: StringName in IN_PLACE_CLIPS:
		if not ap.has_animation(clip):
			continue
		var anim := ap.get_animation(clip)
		var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
		_check(track >= 0 and anim.track_get_key_count(track) > 0, "the `%s` clip has no Hips position keys" % clip)
		if track < 0:
			continue
		for key in anim.track_get_key_count(track):
			var v: Vector3 = anim.track_get_key_value(track, key)
			if v.x != 0.0 or v.z != 0.0:
				_check(false, "the `%s` clip's Hips key %d travels (%.4f, %.4f): it is not zeroed in place"
						% [clip, key, v.x, v.z])
				break
		var height := _first_hips_y(anim)
		_check(absf(height - idle_y) < RIG_HEIGHT_EPS,
				"the `%s` clip's Hips start at %.4f, `idle`'s at %.4f: it was exported on another rig (feet in the floor)"
						% [clip, height, idle_y])
		if YAW_NEUTRAL_CLIPS.has(clip):
			_check_yaw_neutral(anim, clip)


func _first_hips_y(anim: Animation) -> float:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	if track < 0 or anim.track_get_key_count(track) == 0:
		return INF
	return (anim.track_get_key_value(track, 0) as Vector3).y


## Every Hips rotation key's twist about the up axis against the first key's: net and peak under the bound.
func _check_yaw_neutral(anim: Animation, clip: StringName) -> void:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_ROTATION_3D)
	_check(track >= 0 and anim.track_get_key_count(track) > 0, "the `%s` clip has no Hips rotation keys" % clip)
	if track < 0 or anim.track_get_key_count(track) == 0:
		return
	var first := _yaw_of(anim.track_get_key_value(track, 0))
	var peak := 0.0
	for key in anim.track_get_key_count(track):
		peak = maxf(peak, absf(rad_to_deg(angle_difference(first, _yaw_of(anim.track_get_key_value(track, key))))))
	_check(peak < YAW_EPS_DEGREES, "the `%s` clip turns the Hips %.2f degrees by itself: its yaw is not neutralised"
			% [clip, peak])


## The yaw (radians) of `q`'s twist about +Y, the Hips' up in skeleton space.
static func _yaw_of(q: Quaternion) -> float:
	var twist := Quaternion(0.0, q.y, 0.0, q.w)
	if twist.length_squared() < 1e-12:
		return 0.0
	twist = twist.normalized()
	return 2.0 * atan2(twist.y, twist.w)


## (f) the body cylinder, against the hero's own body box, read off both scenes.
func _check_body(healer: Node) -> void:
	var body := healer.get_node_or_null("Collision") as CollisionShape3D
	var cylinder := (body.shape if body != null else null) as CylinderShape3D
	_check(cylinder != null, "the Healer's body shape is not a cylinder")
	if cylinder == null:
		return
	_check(absf(body.position.y - cylinder.height * 0.5) < 0.02,
			"the body cylinder does not stand on the ground (centre %.3f, half height %.3f)"
					% [body.position.y, cylinder.height * 0.5])
	var reference := (load("res://src/actors/hero/hero.tscn") as PackedScene).instantiate()
	var reference_body := reference.get_node_or_null("Collision") as CollisionShape3D
	var reference_box := (reference_body.shape if reference_body != null else null) as BoxShape3D
	_check(reference_box != null and cylinder.height >= reference_box.size.y,
			"the body cylinder (%.2f m) is shorter than the hero's body box (%s)"
					% [cylinder.height, reference_box.size.y if reference_box != null else "missing"])
	reference.free()


## (g) the two owner skins on the one tinted mesh.
func _check_skins(actor: UnitActor) -> void:
	var mesh := actor.get_node_or_null(actor.skin_mesh_path) as MeshInstance3D
	_check(mesh != null, "skin_mesh_path does not name a MeshInstance3D")
	if mesh == null:
		return
	_check(mesh.material_override == null, "the mesh wears a skin before any owner is known")
	_check(not actor.apply_owner_skin(2), "a slot with no authored skin applied one")
	_check(mesh.material_override == null, "a slot with no authored skin changed the mesh")
	_check(actor.apply_owner_skin(0), "P1's skin was not applied")
	var p1 := mesh.material_override as BaseMaterial3D
	_check(actor.apply_owner_skin(1), "P2's skin was not applied")
	var p2 := mesh.material_override as BaseMaterial3D
	_check(p1 != null and p2 != null, "an owner skin is not a BaseMaterial3D")
	if p1 == null or p2 == null:
		return
	_check(p1.resource_name == "healer_p1_purple", "P1's Healer does not wear the purple skin (got '%s')" % p1.resource_name)
	_check(p2.resource_name == "healer_p2_red", "P2's Healer does not wear the red skin (got '%s')" % p2.resource_name)
	for skin: BaseMaterial3D in [p1, p2]:
		_check(skin.albedo_texture != null and skin.albedo_texture.resource_path.get_file() == ALBEDO_FILE,
				"skin '%s' does not keep the Healer's own texture" % skin.resource_name)
	_check(not p1.albedo_color.is_equal_approx(p2.albedo_color), "the two owner tints are the same colour")


## (h) HOW THE MODEL IS MOUNTED, read off bones and the mesh bounds in the ACTOR's space -- never off the
## mount node's yaw. The scene's forward is -Z (`aim_at`): the toes must be on that side of the ankles.
func _check_mount(healer: Node) -> void:
	var model := healer.get_node_or_null("Healer") as Node3D
	var skeleton := healer.get_node_or_null("Healer/Skeleton3D") as Skeleton3D
	_check(model != null and skeleton != null, "the scene has no Healer model and skeleton")
	if model == null or skeleton == null:
		return
	var to_actor := model.transform * skeleton.transform
	for side: String in ["Left", "Right"]:
		var toe := to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_%sToeBase" % side)).origin
		var ankle := to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_%sFoot" % side)).origin
		_check(toe.z < ankle.z - 0.05,
				"the Healer is mounted backwards: %s toe at z %.3f, ankle at z %.3f (forward is -Z)" % [side, toe.z, ankle.z])
	var bottom := INF
	var top := -INF
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := (to_actor * mesh.transform) * mesh.get_aabb()
		bottom = minf(bottom, bounds.position.y)
		top = maxf(top, bounds.end.y)
	_check(absf(bottom) < 0.05, "the Healer's feet are %.3f m off the ground plane" % bottom)
	_check(top > DRAWN_MIN and top < DRAWN_MAX,
			"the Healer is drawn %.3f m tall, outside the %.2f to %.2f m of its 0.8 mount" % [top, DRAWN_MIN, DRAWN_MAX])
	var hurt_shape := healer.get_node_or_null("Hurtbox/HurtboxShape") as CollisionShape3D
	var hurt_box := (hurt_shape.shape if hurt_shape != null else null) as BoxShape3D
	_check(hurt_box != null, "the hurtbox shape is not a box")
	if hurt_box == null:
		return
	var hurt_bottom := hurt_shape.position.y - hurt_box.size.y * 0.5
	var hurt_top := hurt_shape.position.y + hurt_box.size.y * 0.5
	_check(absf(hurt_bottom) < 0.02, "the hurtbox's bottom is %.3f m off the ground" % hurt_bottom)
	_check(absf(hurt_top - top) < HURTBOX_FIT,
			"the hurtbox's top (%.3f m) does not fit the drawn top (%.3f m)" % [hurt_top, top])
