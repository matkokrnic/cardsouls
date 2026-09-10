extends SceneTree

## Story 6-1b (Task 3): measures WHICH FRAME of each of the three charge clips
## (swipe/thrust/jump_attack) carries the visible "blade arrives" strike pose -- the STRIKE FRAME
## the progress-to-playhead mapping (AC 2/AC 11) must land on at progress == 1.0.
##
## `tools/measure_strike_frame.gd`'s OWN METHOD, generalized from one zombie clip to the three
## paladin charge clips instead of duplicated by hand: HEADLESS (`3-0a/R3` — the editor is the one
## tool this project will not open), forward-kinematics bone composition (`get_bone_pose()`,
## never cached, unlike `get_bone_global_pose()` — see that tool's own header for the measured
## reason), and the SWORD BONE as the probe -- `mixamorig_Sword_joint`, the exact joint
## `HeroActor._track_weapon_bone()` already follows for the melee hitbox (5-0a AC 3), so "the
## blade arrives" is measured on the same bone the game already treats as the weapon.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_charge_strike_frames.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [&"swipe", &"thrust", &"jump_attack"]
const HIPS := "mixamorig_Hips"
const SWORD_BONE := "mixamorig_Sword_joint"

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
	var sword_idx := _skel.find_bone(SWORD_BONE)
	if hips_idx < 0 or sword_idx < 0:
		push_error("rig missing %s or %s" % [HIPS, SWORD_BONE])
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
		print("t\tframe\treach\tspeed")
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
			var sword := _bone_fk(sword_idx).origin
			var reach := (sword - hips).length()
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
			print("%.4f\t%d\t%.4f\t%.4f" % [t, i, reach, speed])
		print("clip=%s max_reach=%.4f at t=%.4f; peak_speed=%.4f at t=%.4f"
			% [clip, max_reach, max_reach_t, peak_speed, peak_speed_t])

	quit(0)
