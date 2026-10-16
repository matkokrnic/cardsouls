extends SceneTree

## Story 7-1 (AC 23/AC 24): measures the three spell-cast clips' RELEASE FRAMES -- the beat the Fireball or
## the first Rocksling stone must visibly leave the hands on -- `tools/measure_cast_clip_frames.gd`'s method
## re-pointed: HEADLESS, forward-kinematics bone composition (`get_bone_pose()` up the parent chain, never the
## cached global pose), and a printed table a human reads the criterion off.
##
## THE CRITERION, STATED BEFORE THE NUMBERS ARE READ (the adversarial-review rule):
##   RELEASE = the timestamp at which the MIDPOINT OF THE TWO HANDS reaches its peak FORWARD reach (model +Z,
##   the Mixamo rig's facing) relative to the Hips. Both clips are two-handed, so the midpoint is the honest
##   probe; relative to the Hips so a clip whose body sways cannot masquerade as a throw.
##   For `cast_rocksling_lift` the beat is the PEAK HEIGHT of the hand midpoint above the Hips (the rock held
##   up), printed for the lift's cut, not a release.
##
## WHAT THE NUMBERS ARE FOR: presentation constants on `AnimationController` (`FIREBALL_RELEASE_SECONDS`,
## `ROCKSLING_THROW_RELEASE_SECONDS`, `ROCKSLING_LIFT_PEAK_SECONDS`). Nothing is baked into the library.
##
## 7-1 POLISH ROUND (2026-10-04): THE TWO GESTURE CLIPS, criteria STATED HERE BEFORE THE NUMBERS ARE READ.
##   `cast_buff` (a buff gesture): BEAT = the timestamp at which the MIDPOINT OF THE TWO HANDS reaches its PEAK
##     HEIGHT above the Hips -- the gesture's peak is the arms at their highest; midpoint because the gesture is
##     two-armed, relative to the Hips so a crouch-and-rise cannot masquerade as a raise.
##   `cast_counterspell` (a sword strike into the air): BEAT = the timestamp at which the SWORD (the
##     `mixamorig_Sword_joint` bone the hero's Hitbox follows, `5-0a`) reaches its PEAK HEIGHT above the Hips --
##     the swing's highest point. Its Hips-relative model-space position at that beat is printed too, as the
##     rune burst's origin should the live bone read ever be unavailable.
##   Earliest maximum wins a tie. For these two the RELEASE/PEAK-HEIGHT pair below is not used.
##
## STORY 7-5b SMOKE FIX 2 (S12): `cast_wrath` (Mixamo "Standing 2H Magic Area Attack 02"), read straight off
## `cast_wrath.fbx` BEFORE it joins the library (measure first), criteria STATED HERE BEFORE THE NUMBERS ARE READ:
##   TAKE    the importer's take name (the route expects `mixamo_com`), the clip's length and frame count.
##   HIPS    the Hips position track's NET (last key against the first) and PEAK planar travel -- the
##           `add_paladin_spell_clips.gd` measurement, against the same 0.25 m ceiling.
##   RAISE   the timestamp at which the MIDPOINT OF THE TWO HANDS reaches its PEAK HEIGHT above the Hips (the arms at
##           their highest), earliest maximum on a tie.
##   SLAM    AFTER the raise, the timestamp at which that midpoint reaches its LOWEST height above the Hips -- both
##           hands at their lowest point after the raise, the instant they strike down. Earliest minimum on a tie;
##           each hand's own lowest point after the raise is printed beside it, so a slam with one hand trailing
##           shows. The pulse lands on this frame (rate-fitted, `AnimationController.spell_cast_pose`).
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_spell_clip_frames.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [&"cast_fireball", &"cast_rocksling_lift", &"cast_rocksling_throw"]
const HIPS := "mixamorig_Hips"
const RIGHT_HAND := "mixamorig_RightHand"
const LEFT_HAND := "mixamorig_LeftHand"
const SWORD := "mixamorig_Sword_joint"
## Smoke fix 2 (S12): the Wrath clip, read off its FBX (header).
const WRATH_FBX := "res://assets/characters/paladin/cast_wrath.fbx"
## The 7-1 polish round's gesture clips -> the probe whose PEAK HEIGHT above the Hips is the beat (header).
const GESTURES := {
	&"cast_buff": "hands",
	&"cast_counterspell": "sword",
}

var _skel: Skeleton3D


func _bone_fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


func _initialize() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	var model := scene.instantiate()
	root.add_child(model)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.size() != 1:
		push_error("expected exactly 1 Skeleton3D, found %d" % skels.size())
		quit(1)
		return
	_skel = skels[0] as Skeleton3D
	var library: AnimationLibrary = load(LIBRARY_PATH)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library)
	var hips_idx := _skel.find_bone(HIPS)
	var rh_idx := _skel.find_bone(RIGHT_HAND)
	var lh_idx := _skel.find_bone(LEFT_HAND)
	if hips_idx < 0 or rh_idx < 0 or lh_idx < 0:
		push_error("rig missing %s, %s or %s" % [HIPS, RIGHT_HAND, LEFT_HAND])
		quit(1)
		return
	for clip: StringName in CLIPS:
		var anim: Animation = library.get_animation(clip)
		if anim == null:
			push_error("library has no clip %s" % clip)
			continue
		print("---- clip=%s length=%.4f" % [clip, anim.length])
		player.play(clip)
		var steps := 120
		var dt := anim.length / float(steps)
		print("t\tfrac\tmid_fwd\tmid_up\tspeed")
		var best_fwd := -INF
		var best_fwd_t := 0.0
		var best_up := -INF
		var best_up_t := 0.0
		var prev := Vector3.ZERO
		for i in steps + 1:
			var t: float = minf(float(i) * dt, anim.length)
			player.seek(t, true)
			var hips := _bone_fk(hips_idx).origin
			var mid := (_bone_fk(rh_idx).origin + _bone_fk(lh_idx).origin) * 0.5 - hips
			var speed := 0.0 if i == 0 else (mid - prev).length() / dt
			prev = mid
			if mid.z > best_fwd:
				best_fwd = mid.z
				best_fwd_t = t
			if mid.y > best_up:
				best_up = mid.y
				best_up_t = t
			print("%.4f\t%.4f\t%.4f\t%.4f\t%.4f" % [t, t / anim.length, mid.z, mid.y, speed])
		print("clip=%s RELEASE (peak forward reach) = %.4f m at t=%.4f (fraction %.4f)"
			% [clip, best_fwd, best_fwd_t, best_fwd_t / anim.length])
		print("clip=%s PEAK HEIGHT = %.4f m at t=%.4f (fraction %.4f)"
			% [clip, best_up, best_up_t, best_up_t / anim.length])
	var sword_idx := _skel.find_bone(SWORD)
	if sword_idx < 0:
		push_error("rig missing %s" % SWORD)
		quit(1)
		return
	print("sword bone parent = %s" % _skel.get_bone_name(_skel.get_bone_parent(sword_idx)))
	for clip: StringName in GESTURES:
		var anim: Animation = library.get_animation(clip)
		if anim == null:
			push_error("library has no clip %s" % clip)
			continue
		var probe: String = GESTURES[clip]
		print("---- gesture=%s probe=%s length=%.4f" % [clip, probe, anim.length])
		player.play(clip)
		var steps := 120
		var dt := anim.length / float(steps)
		print("t\tfrac\tprobe_up\tprobe_x\tprobe_z")
		var best_up := -INF
		var best_t := 0.0
		var best_at := Vector3.ZERO
		for i in steps + 1:
			var t: float = minf(float(i) * dt, anim.length)
			player.seek(t, true)
			var hips := _bone_fk(hips_idx).origin
			var at := _bone_fk(sword_idx).origin if probe == "sword" \
					else (_bone_fk(rh_idx).origin + _bone_fk(lh_idx).origin) * 0.5
			at -= hips
			if at.y > best_up:
				best_up = at.y
				best_t = t
				best_at = at
			print("%.4f\t%.4f\t%.4f\t%.4f\t%.4f" % [t, t / anim.length, at.y, at.x, at.z])
		print("gesture=%s BEAT (probe peak height) = %.4f m at t=%.4f (fraction %.4f), hips-relative %s"
			% [clip, best_up, best_t, best_t / anim.length, best_at])
	_measure_wrath(player, hips_idx, rh_idx, lh_idx)
	quit(0)


## Smoke fix 2 (S12): `cast_wrath.fbx`'s take, hips and slam frame, by the criteria in the header.
func _measure_wrath(player: AnimationPlayer, hips_idx: int, rh_idx: int, lh_idx: int) -> void:
	var scene: PackedScene = load(WRATH_FBX)
	if scene == null:
		push_error("%s did not load" % WRATH_FBX)
		return
	var clip_root := scene.instantiate()
	var players := clip_root.find_children("*", "AnimationPlayer", true, false)
	print("---- wrath: %s players=%d" % [WRATH_FBX, players.size()])
	var anim: Animation = null
	for node in players:
		var takes := (node as AnimationPlayer).get_animation_list()
		print("  takes=%s" % [takes])
		if takes.size() > 0:
			anim = (node as AnimationPlayer).get_animation(takes[0]).duplicate(true)
	clip_root.free()
	if anim == null:
		push_error("cast_wrath.fbx carries no take")
		return
	print("  length=%.4f frames@30=%d tracks=%d" % [anim.length, int(round(anim.length * 30.0)), anim.get_track_count()])
	var hips_track := anim.find_track(NodePath("Skeleton3D:" + HIPS), Animation.TYPE_POSITION_3D)
	if hips_track >= 0 and anim.track_get_key_count(hips_track) > 0:
		var keys := anim.track_get_key_count(hips_track)
		var first: Vector3 = anim.track_get_key_value(hips_track, 0)
		var last: Vector3 = anim.track_get_key_value(hips_track, keys - 1)
		var peak := 0.0
		for k in keys:
			var v: Vector3 = anim.track_get_key_value(hips_track, k)
			peak = maxf(peak, Vector2(v.x - first.x, v.z - first.z).length())
		print("  hips keys=%d net=%s net_planar=%.4f peak_planar=%.4f" % [keys, last - first,
				Vector2(last.x - first.x, last.z - first.z).length(), peak])
	var temp := AnimationLibrary.new()
	temp.add_animation(&"cast_wrath", anim)
	player.add_animation_library(&"wrath_probe", temp)
	player.play(&"wrath_probe/cast_wrath")
	var steps := int(round(anim.length * 30.0))
	var dt := anim.length / float(steps)
	var heights: Array[float] = []
	var right: Array[float] = []
	var left: Array[float] = []
	var abs_mid: Array[float] = []
	var abs_right: Array[float] = []
	var abs_left: Array[float] = []
	print("frame\tt\tmid_up\tR_up\tL_up\tmid_fwd\thips_y\tabs_mid_y\tabs_R_y\tabs_L_y")
	for i in steps + 1:
		var t: float = minf(float(i) * dt, anim.length)
		player.seek(t, true)
		var hips := _bone_fk(hips_idx).origin
		var r_abs := _bone_fk(rh_idx).origin
		var l_abs := _bone_fk(lh_idx).origin
		var r := r_abs - hips
		var l := l_abs - hips
		var mid := (r + l) * 0.5
		heights.append(mid.y)
		right.append(r.y)
		left.append(l.y)
		abs_mid.append((r_abs.y + l_abs.y) * 0.5)
		abs_right.append(r_abs.y)
		abs_left.append(l_abs.y)
		print("%d\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f" % [i, t, mid.y, r.y, l.y, mid.z, hips.y,
				abs_mid[i], r_abs.y, l_abs.y])
	var raise := 0
	for i in heights.size():
		if heights[i] > heights[raise]:
			raise = i
	var slam := raise
	var r_low := raise
	var l_low := raise
	for i in range(raise, heights.size()):
		if heights[i] < heights[slam]:
			slam = i
		if right[i] < right[r_low]:
			r_low = i
		if left[i] < left[l_low]:
			l_low = i
	print("wrath RAISE (hands' midpoint peak height) = %.4f m at frame %d, t=%.4f" % [heights[raise], raise, raise * dt])
	print("wrath SLAM (midpoint lowest after the raise) = %.4f m at frame %d, t=%.4f (fraction %.4f)"
			% [heights[slam], slam, slam * dt, slam * dt / anim.length])
	print("wrath right hand lowest after the raise: frame %d (%.4f m); left hand: frame %d (%.4f m)"
			% [r_low, right[r_low], l_low, left[l_low]])
	var abs_slam := raise
	for i in range(raise, abs_mid.size()):
		if abs_mid[i] < abs_mid[abs_slam]:
			abs_slam = i
	print("wrath SLAM, ABSOLUTE (midpoint's model-space height lowest after the raise) = %.4f at frame %d, t=%.4f"
			% [abs_mid[abs_slam], abs_slam, abs_slam * dt])
	player.remove_animation_library(&"wrath_probe")
