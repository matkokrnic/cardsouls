extends SceneTree

## Story 4-3d (AC 1): measures WHICH FRAME of the minion's `attack` clip carries the visible
## claw-strike pose -- the STRIKE FRAME `T` the alignment rate `r = T / 0.9` derives from.
##
## HEADLESS, NOT THE EDITOR (`3-0a/R3` hazard; six recorded incidents in this project). The
## story's task words the measurement as "by eye, scrubbing the imported clip"; the editor is
## the one tool this project will not open, so the scrub is done numerically here and printed
## as a per-frame table.
##
## WHAT IS MEASURED, and what is explicitly NOT. `4-3d/R13` rules the HIPS-DISPLACEMENT
## EXCURSION PEAK out as a proxy: that is where the ROOT translates furthest (the lunge/step).
## The strike frame is where the CLAW ARRIVES. So the quantity here is the hand bone's position
## RELATIVE TO THE HIPS -- the arm's own extension, with the body's lunge divided out. The hips
## column is printed alongside PRECISELY so the two can be seen to be different measurements
## rather than assumed to coincide.
##
## WHY FORWARD KINEMATICS AND NOT `get_bone_global_pose()`, measured. `seek(t, true)` does write
## the animated LOCAL bone poses immediately, but `Skeleton3D`'s GLOBAL pose cache refreshes at
## most once per frame -- and a `SceneTree` script processes no frames. `force_update_all_bone_
## transforms()` therefore serves the FIRST sample and silently returns the same stale transform
## for every sample after it (observed: an 81-row table of one constant). Composing the chain
## from `get_bone_pose()`, which is never cached, is the only reading that varies with `t`.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_strike_frame.gd

const MODEL_PATH := "res://assets/characters/skeletonzombie/skeletonzombie.fbx"
const LIBRARY_PATH := "res://assets/characters/skeletonzombie/skeletonzombie_anims.res"
const CLIP := &"attack"
const HIPS := "mixamorig_Hips"

## Both hands and both forearms: the strike frame is read off the arm that actually swings
## rather than assumed to be one particular side.
const PROBES: Array[String] = [
	"mixamorig_RightHand", "mixamorig_LeftHand",
	"mixamorig_RightForeArm", "mixamorig_LeftForeArm",
]

var _skel: Skeleton3D


## Composes bone-local poses up the parent chain. `get_bone_pose()` is the animated transform
## relative to the parent bone and is read straight off the pose array -- no cache, so it
## reflects the most recent `seek()` on every call.
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

	var anim := library.get_animation(CLIP)
	print("clip=%s length=%.4f tracks=%d loop_mode=%d"
		% [CLIP, anim.length, anim.get_track_count(), anim.loop_mode])
	# The key count on the Hips position track -- the figure `4-3d/R18` asks be re-confirmed
	# from the imported clip before any rate is applied (2.6667 s, 80 keys).
	for tr in anim.get_track_count():
		if anim.track_get_path(tr) == NodePath("Skeleton3D:" + HIPS) \
				and anim.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			print("hips position track keys=%d" % anim.track_get_key_count(tr))

	var hips_idx := _skel.find_bone(HIPS)
	if hips_idx < 0:
		push_error("no bone named %s" % HIPS)
		quit(1)
		return
	var probe_idx := {}
	for name: String in PROBES:
		var i := _skel.find_bone(name)
		if i < 0:
			push_error("no bone named %s" % name)
			quit(1)
			return
		probe_idx[name] = i

	player.play(CLIP)
	var steps := 80
	var dt := anim.length / float(steps)
	var header := "t\tframe\thipsFwd"
	for name: String in PROBES:
		var short := name.replace("mixamorig_", "")
		header += "\t%s.fwd\t%s.reach\t%s.spd" % [short, short, short]
	print(header)

	var prev := {}
	for i in steps + 1:
		var t: float = minf(float(i) * dt, anim.length)
		player.seek(t, true)
		var hips := _bone_fk(hips_idx).origin
		var line := "%.4f\t%d\t%.4f" % [t, i, hips.z]
		for name: String in PROBES:
			var p := _bone_fk(probe_idx[name]).origin - hips
			var spd := 0.0
			if prev.has(name):
				spd = (p - (prev[name] as Vector3)).length() / dt
			prev[name] = p
			line += "\t%.4f\t%.4f\t%.4f" % [p.z, p.length(), spd]
		print(line)

	quit(0)
