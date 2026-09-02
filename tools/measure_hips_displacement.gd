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
	quit(0)
