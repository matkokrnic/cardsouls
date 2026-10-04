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
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_spell_clip_frames.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [&"cast_fireball", &"cast_rocksling_lift", &"cast_rocksling_throw"]
const HIPS := "mixamorig_Hips"
const RIGHT_HAND := "mixamorig_RightHand"
const LEFT_HAND := "mixamorig_LeftHand"
const SWORD := "mixamorig_Sword_joint"
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
	quit(0)
