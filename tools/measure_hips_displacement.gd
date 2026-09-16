extends SceneTree

## Story 5-0a (AC 1): measures per-clip `mixamorig_Hips` NET DISPLACEMENT off the assembled
## paladin AnimationLibrary -- the 3-0a AC6/R9 method made a reusable instrument instead of a
## one-off script that has to be rewritten every time a clip is added.
##
## WHAT NET-ZERO MEANS AND WHY IT MATTERS (3-0a/R9). A looping clip whose Hips position track
## does not return to its start value accumulates that translation on every repeat, competing
## with the state-owned `HeroState.velocity` that actually moves the body. The fix for a clip
## that is not net-zero is an In Place RE-DOWNLOAD of that clip (operator-owned), never a
## code-side or track-side workaround -- zeroing the track is feel-tuning-class work, ruled
## out of scope by 5-0a's Non-Goals.
##
## PEAK EXCURSION is reported alongside, and is a DIFFERENT quantity: the furthest the Hips
## travel from their clip-start position at any key. A clip can be perfectly net-zero and
## still swing far mid-clip (`roll` does, ~1.09 planar) -- that is a LEGIBILITY question
## (3-0b), not a correctness one, and is printed here so a future feel pass has the data
## rather than having to re-derive it.
##
## Reads `Animation.track_get_key_value` directly off the library -- no scene, no skeleton,
## no frame. Position tracks only; rotation/scale are irrelevant to translation drift.
##
## STORY 6-7b (AC 7, Fact M8) ADDED A SECOND TABLE: the Hips ROTATION track's YAW -- rotation
## about skeleton +Y, which is the model's up (the paladin Skeleton3D sits at an identity transform
## inside the model and Hips is its root bone, measured). Two turn-in-place clips entered the
## library that story, and a turn clip's accumulated body yaw would stack on top of
## `HeroActor.drive()`'s single yaw write (DECISION A). Yaw is taken by SWING-TWIST (the same
## decomposition `add_paladin_locomotion.gd` neutralises with), never by Euler angles. For every
## library clip that has a same-named source FBX in the paladin folder, the SOURCE take is measured
## beside it, so one run shows the pre-fix (source) and post-fix (library) figures together, plus
## the largest per-key difference between them in SWING (sway/tilt, degrees) and in Hips POSITION
## -- both must read ~0 for a yaw-only fix. Rows are only compared key-for-key when the key times
## match (a retimed clip, `attack`/`roll`, reports `retimed`).
##
## YAW SIGN: positive = the body turns from model +Z (forward) toward model +X -- the side
## `AnimationController` calls "right" (`strafe_right` travels +X, measured), so a positive source
## yaw is labelled `+X(right)`. ANATOMICALLY that is the rig's `mixamorig_LeftHand` side (rest x
## +0.657; RightHand -0.656; toes at +Z): the controller's left/right naming is the anatomical
## inverse, a 6-7b finding recorded and deliberately NOT renamed (operator ruling, 6-7b dev pass) --
## clip files follow the CONTROLLER's convention, which is what this label reports.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_hips_displacement.gd

const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

## Below this magnitude a net displacement is float noise, not travel. Matches the order of
## the residuals 3-0a measured on the five clips it called net-zero.
const NET_ZERO_EPS := 0.001


func _initialize() -> void:
	var lib: AnimationLibrary = load(LIBRARY_PATH)
	if lib == null:
		push_error("%s did not load" % LIBRARY_PATH)
		quit(1)
		return

	var names := lib.get_animation_list()
	names.sort()
	print("library: %s (%d clips)" % [LIBRARY_PATH, names.size()])
	print("clip\tlen\tkeys\tfirst(x,y,z)\tlast(x,y,z)\tnet(x,y,z)\t|net|\t|net|planar\tpeak\tpeakPlanar\tnet_zero")

	var any_drift := false
	for clip: StringName in names:
		var anim: Animation = lib.get_animation(clip)
		var track := -1
		for t in anim.get_track_count():
			if anim.track_get_path(t) == NodePath(HIPS_TRACK) \
					and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				track = t
				break
		if track == -1:
			print("%s\t%.4f\t-\t(no %s position track)" % [clip, anim.length, HIPS_TRACK])
			continue

		var keys := anim.track_get_key_count(track)
		if keys == 0:
			print("%s\t%.4f\t0\t(empty track)" % [clip, anim.length])
			continue

		var first: Vector3 = anim.track_get_key_value(track, 0)
		var last: Vector3 = anim.track_get_key_value(track, keys - 1)
		var net := last - first
		var net_planar := Vector2(net.x, net.z).length()
		var peak := 0.0
		var peak_planar := 0.0
		for k in keys:
			var d: Vector3 = (anim.track_get_key_value(track, k) as Vector3) - first
			peak = maxf(peak, d.length())
			peak_planar = maxf(peak_planar, Vector2(d.x, d.z).length())

		var is_net_zero := net.length() <= NET_ZERO_EPS
		if not is_net_zero:
			any_drift = true
		print("%s\t%.4f\t%d\t(%.4f, %.4f, %.4f)\t(%.4f, %.4f, %.4f)\t(%.4f, %.4f, %.4f)\t%.4f\t%.4f\t%.4f\t%.4f\t%s" % [
			clip, anim.length, keys,
			first.x, first.y, first.z,
			last.x, last.y, last.z,
			net.x, net.y, net.z,
			net.length(), net_planar, peak, peak_planar,
			"YES" if is_net_zero else "NO"])

	# Reported, never enforced: `death`'s net topple is ACCEPTED (3-0a AC6/R9 -- the round-over
	# freeze zeroes velocity for the whole span it plays), so a nonzero result here is data for
	# the reader, not a failure exit. The machine contract on clip identity lives in
	# test/integration/test_rig_clips.gd.
	print("net-zero eps=%.4f; at least one clip carries net displacement: %s" % [
		NET_ZERO_EPS, "yes" if any_drift else "no"])

	print("")
	print("HIPS ROTATION -- yaw about skeleton +Y, degrees; + = toward model +X = AnimationController's 'right'")
	print("clip	rotKeys	lib firstYaw	lib lastYaw	lib netYaw	lib peakYaw	src netYaw	src turns	src peakYaw	maxSwingDiff	maxPosDiff")
	for clip: StringName in names:
		var anim: Animation = lib.get_animation(clip)
		var rot := _track(anim, Animation.TYPE_ROTATION_3D)
		if rot == -1 or anim.track_get_key_count(rot) == 0:
			print("%s	-	(no %s rotation track)" % [clip, HIPS_TRACK])
			continue
		var lib_yaw := _yaw_profile(anim, rot)
		var src_cols := "-	-	-	-	-"
		var src_anim := _source_take(String(clip))
		if src_anim != null:
			var src_rot := _track(src_anim, Animation.TYPE_ROTATION_3D)
			if src_rot != -1 and src_anim.track_get_key_count(src_rot) > 0:
				var src_yaw := _yaw_profile(src_anim, src_rot)
				var turns := "none"
				if absf(src_yaw["net"]) > YAW_ZERO_EPS_DEG:
					turns = "+X(right)" if src_yaw["net"] > 0.0 else "-X(left)"
				src_cols = "%.3f	%s	%.3f	%s	%s" % [src_yaw["net"], turns, src_yaw["peak"],
					_max_swing_diff(anim, rot, src_anim, src_rot),
					_max_pos_diff(anim, src_anim)]
		print("%s	%d	%.3f	%.3f	%.3f	%.3f	%s" % [clip, anim.track_get_key_count(rot),
			lib_yaw["first"], lib_yaw["last"], lib_yaw["net"], lib_yaw["peak"], src_cols])
	print("yaw zero eps=%.3f deg" % YAW_ZERO_EPS_DEG)
	quit(0)


## Below this many degrees a net yaw is float noise, not a turn.
const YAW_ZERO_EPS_DEG := 0.01


func _track(anim: Animation, type: Animation.TrackType) -> int:
	for t in anim.get_track_count():
		if anim.track_get_path(t) == NodePath(HIPS_TRACK) and anim.track_get_type(t) == type:
			return t
	return -1


## The Mixamo take out of `<clip>.fbx` beside the library, or null if there is no such file.
func _source_take(clip: String) -> Animation:
	var path := LIBRARY_PATH.get_base_dir() + "/" + clip + ".fbx"
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var root_node := scene.instantiate()
	var players := root_node.find_children("*", "AnimationPlayer", true, false)
	var out: Animation = null
	if players.size() == 1 and (players[0] as AnimationPlayer).has_animation(&"mixamo_com"):
		out = (players[0] as AnimationPlayer).get_animation(&"mixamo_com").duplicate(true)
	root_node.free()
	return out


static func _twist(q: Quaternion) -> Quaternion:
	var t := Quaternion(0.0, q.y, 0.0, q.w)
	return Quaternion.IDENTITY if t.length_squared() < 1e-12 else t.normalized()


## Signed angle, degrees, of a pure twist about +Y, wrapped to (-180, 180].
static func _twist_deg(t: Quaternion) -> float:
	return rad_to_deg(wrapf(2.0 * atan2(t.y, t.w), -PI, PI))


## first/last absolute yaw, net yaw (last relative to first) and the peak |yaw| reached relative
## to the first key, all from the twist about +Y.
func _yaw_profile(anim: Animation, track: int) -> Dictionary:
	var keys := anim.track_get_key_count(track)
	var t0 := _twist(anim.track_get_key_value(track, 0))
	var peak := 0.0
	var net := 0.0
	for k in keys:
		var rel := _twist_deg(t0.inverse() * _twist(anim.track_get_key_value(track, k)))
		peak = maxf(peak, absf(rel))
		if k == keys - 1:
			net = rel
	return {
		"first": _twist_deg(t0),
		"last": _twist_deg(_twist(anim.track_get_key_value(track, keys - 1))),
		"net": net,
		"peak": peak,
	}


## Largest per-key angle between the two tracks' SWINGS (q with its +Y twist removed), degrees.
func _max_swing_diff(a: Animation, at: int, b: Animation, bt: int) -> String:
	if not _same_times(a, at, b, bt):
		return "retimed"
	var worst := 0.0
	for k in a.track_get_key_count(at):
		var qa: Quaternion = a.track_get_key_value(at, k)
		var qb: Quaternion = b.track_get_key_value(bt, k)
		var sa := _twist(qa).inverse() * qa
		var sb := _twist(qb).inverse() * qb
		# 2*asin(|vector part of the relative rotation|), NOT angle_to(): angle_to is an acos of a
		# dot product near 1, where float32 keys alone read ~0.05-0.09 degrees on IDENTICAL data
		# (measured on untouched clips). asin is well-conditioned at zero.
		var rel := sa.inverse() * sb
		var vec_len := minf(Vector3(rel.x, rel.y, rel.z).length(), 1.0)
		worst = maxf(worst, rad_to_deg(2.0 * asin(vec_len)))
	return "%.5f" % worst


## Largest per-key distance between the two clips' Hips POSITION tracks.
func _max_pos_diff(a: Animation, b: Animation) -> String:
	var at := _track(a, Animation.TYPE_POSITION_3D)
	var bt := _track(b, Animation.TYPE_POSITION_3D)
	if at == -1 or bt == -1:
		return "-"
	if not _same_times(a, at, b, bt):
		return "retimed"
	var worst := 0.0
	for k in a.track_get_key_count(at):
		worst = maxf(worst, ((a.track_get_key_value(at, k) as Vector3)
			- (b.track_get_key_value(bt, k) as Vector3)).length())
	return "%.6f" % worst


func _same_times(a: Animation, at: int, b: Animation, bt: int) -> bool:
	if a.track_get_key_count(at) != b.track_get_key_count(bt):
		return false
	for k in a.track_get_key_count(at):
		if not is_equal_approx(a.track_get_key_time(at, k), b.track_get_key_time(bt, k)):
			return false
	return true
