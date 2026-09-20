extends SceneTree

## Story 6-6b (AC 13): measures the IMPACT FRAME of each of the four colour-counter clips -- the
## timestamps the per-colour cut ranges in `AnimationController._COUNTER_PRESENTATION` are placed
## against, and, for GREEN, the `counter_throw` RELEASE frame the dagger leaves the hand on.
##
## `tools/measure_charge_strike_frames.gd`'s OWN METHOD, re-pointed rather than duplicated by hand
## (that tool is itself `measure_strike_frame.gd` generalized from one zombie clip to three paladin
## ones; this is the same generalization to a fourth set): HEADLESS (`3-0a/R3` -- the editor is the
## one tool this project will not open), forward-kinematics bone composition (`get_bone_pose()`,
## never cached, unlike `get_bone_global_pose()` -- see `measure_strike_frame.gd`'s header for the
## measured reason), and the `6-1b` IMPACT CRITERION read off the printed table: the LAST major
## reach maximum that FOLLOWS the swing's own peak speed, never the global max reach.
##
## THE PROBE IS THE RIGHT HAND, not the sword joint. `measure_charge_strike_frames.gd` probes
## `mixamorig_Sword_joint` because its three clips are blade swings; none of these four is. Three of
## them carry no weapon beat at all (a jump, a backflip, a slide) and the fourth -- `counter_throw`
## -- is a THROW, whose impact beat is the hand opening at full extension. The hand is therefore the
## honest probe for all four, and the Hips height is printed beside it so an airborne beat (the
## jump's apex) can be told from a grounded one rather than assumed.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_counter_strike_frames.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [
	&"counter_jump", &"counter_backflip", &"counter_slide", &"counter_throw",
]
const HIPS := "mixamorig_Hips"
const HAND_BONE := "mixamorig_RightHand"

var _skel: Skeleton3D


## Composes bone-local poses up the parent chain -- `get_bone_pose()` is the animated transform
## relative to the parent bone, read straight off the pose array with no cache, so it reflects the
## most recent `seek()` on every call (measure_strike_frame.gd's own finding, verbatim).
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
	var hand_idx := _skel.find_bone(HAND_BONE)
	if hips_idx < 0 or hand_idx < 0:
		push_error("rig missing %s or %s" % [HIPS, HAND_BONE])
		quit(1)
		return

	for clip: StringName in CLIPS:
		var anim: Animation = library.get_animation(clip)
		if anim == null:
			push_error("library has no clip %s" % clip)
			continue
		print("---- clip=%s length=%.4f tracks=%d" % [clip, anim.length, anim.get_track_count()])
		player.play(clip)
		var steps := 80
		var dt := anim.length / float(steps)
		print("t\tfrac\thipsY\treach\tspeed")
		var prev_reach := 0.0
		var have_prev := false
		var max_reach := 0.0
		var max_reach_t := 0.0
		var peak_speed := 0.0
		var peak_speed_t := 0.0
		for i in steps + 1:
			var t: float = minf(float(i) * dt, anim.length)
			player.seek(t, true)
			var hips := _bone_fk(hips_idx).origin
			var hand := _bone_fk(hand_idx).origin
			var reach := (hand - hips).length()
			var speed := 0.0
			if have_prev:
				speed = (reach - prev_reach) / dt
			prev_reach = reach
			have_prev = true
			if reach > max_reach:
				max_reach = reach
				max_reach_t = t
			if absf(speed) > peak_speed:
				peak_speed = absf(speed)
				peak_speed_t = t
			print("%.4f\t%.4f\t%.4f\t%.4f\t%.4f" % [t, t / anim.length, hips.y, reach, speed])
		print("clip=%s max_reach=%.4f at t=%.4f (%.4f); peak_speed=%.4f at t=%.4f (%.4f)"
			% [clip, max_reach, max_reach_t, max_reach_t / anim.length,
				peak_speed, peak_speed_t, peak_speed_t / anim.length])

	quit(0)
