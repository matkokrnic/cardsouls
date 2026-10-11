extends SceneTree

## Story 7-3 (AC 17): assembles the Hellhound's TWELVE clips (ten until the feel pass added the two
## run strafes) into the single AnimationLibrary
## `assets/characters/hellhound/hellhound_anims.res` that hound_actor.tscn's AnimationPlayer
## plays -- `tools/build_zombie_anims.gd`'s counterpart, HEADLESS for its recorded reason.
##
## ONE SOURCE FILE, NOT FOUR. `SK_Hellhound.fbx` holds the mesh, the skeleton and all 21 takes
## the importer yields (22 in the file; `T_Pose` is removed at import by
## `assets/characters/hellhound/Meshes/strip_t_pose.gd`). This lifts the takes the hound's
## behaviour uses out of the imported scene's AnimationPlayer, RENAMES them to the clip names the
## presentation controller selects by, and sets each loop flag. The nine takes left behind
## (the swim set, the jump set, two idle variants) never reach the scene: it replaces the model
## player's library with this one.
##
## WHICH TAKE IS WHICH, MEASURED by `tools/measure_hellhound_rig.gd` (story 7-3, T1): `attack`
## keeps the hound's feet under it and snaps the jaw forward and down -- the BITE. `Attack01`
## throws the pelvis 2.2 model units forward and 0.26 up and lands jaw-first -- the LEAP. No
## composition from the Jump takes is needed.
##
## Track paths are left exactly as imported (`Skeleton3D:Pelvis`, ...): the model's own
## AnimationPlayer has `root_node = ".."`, the model root, and that is the player the scene keeps.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/build_hellhound_anims.gd

const MODEL_PATH := "res://assets/characters/hellhound/Meshes/SK_Hellhound.fbx"
const LIBRARY_PATH := "res://assets/characters/hellhound/hellhound_anims.res"

## clip name -> [source take, loops]. The single source of truth this tool builds from;
## test/integration/test_hound_rig_clips.gd asserts the same names and flags against the
## assembled scene, independently -- the test never imports this file.
const CLIPS := {
	"idle": ["idle", true],
	"walk": ["walk", true],
	"run": ["run", true],
	"walk_backwards": ["Walk_Backwards", true],
	"walk_left": ["Walk_Left", true],
	"walk_right": ["Walk_Right", true],
	# Feel pass: the two RUN strafes, for a body moving sideways faster than a walk can be played
	# (a hound that has to turn round as it sets off; the fast side of a circle).
	"run_left": ["Run_Left", true],
	"run_right": ["Run_Right", true],
	"attack": ["attack", false],
	"leap": ["Attack01", false],
	"hit": ["hit", false],
	"death": ["Death", false],
}

## The clips whose pelvis is kept from travelling forward (`_hold_pelvis_back`), and the track it is on.
const GROUNDED_CLIPS: Array[String] = ["leap"]
const PELVIS_TRACK := "Skeleton3D:Pelvis"

## Story 7-3, feel pass 3: STRAIGHTEN THE HEAD OF THE BACKWARD WALK. ONE FLAG: set it false and
## rebuild, and `walk_backwards` is the pack's take again, untouched.
##
## MEASURED (`measure_hellhound_rig.gd`, table 7): the pack's `Walk_Backwards` keeps the body facing
## forward and turns the head 107 to 119 degrees over the left shoulder (the neck 68 to 76) for the
## whole take. A hound backing away from its target while looking over its shoulder reads as a strafe
## (the live smoke). With the flag on, the clips named in `HEAD_STRAIGHTENED_CLIPS` take the rotation
## of their `HEAD_TRACKS` bones from the `HEAD_DONOR_TAKE` (the forward walk: the same body axis, the
## same length, the head looking along the body) key for key. Legs, spine, pelvis, tail, ears and jaw
## are left exactly as authored. The strafe clips are not touched: there the BODY is turned under the
## root and the head looks back toward the root's forward, which is what a circling hound should do.
const STRAIGHTEN_BACKWARD_HEAD := true
const HEAD_STRAIGHTENED_CLIPS: Array[String] = ["walk_backwards"]
const HEAD_TRACKS: Array[String] = ["Skeleton3D:Neck", "Skeleton3D:Head"]
const HEAD_DONOR_TAKE := "walk"


func _initialize() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("model did not load: %s" % MODEL_PATH)
		quit(1)
		return
	var model := scene.instantiate()
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		push_error("expected exactly 1 AnimationPlayer, found %d" % players.size())
		model.free()
		quit(1)
		return
	var player := players[0] as AnimationPlayer
	var library := AnimationLibrary.new()
	for clip: String in CLIPS:
		var take := StringName(CLIPS[clip][0])
		if not player.has_animation(take):
			push_error("no '%s' take for clip '%s' (found %s)" % [take, clip, player.get_animation_list()])
			model.free()
			quit(1)
			return
		# Duplicated, not referenced: the source scene is freed below.
		var anim: Animation = player.get_animation(take).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip][1] else Animation.LOOP_NONE
		if GROUNDED_CLIPS.has(clip) and not _hold_pelvis_back(anim, clip):
			model.free()
			quit(1)
			return
		if STRAIGHTEN_BACKWARD_HEAD and HEAD_STRAIGHTENED_CLIPS.has(clip) \
				and not _straighten_head(anim, player.get_animation(StringName(HEAD_DONOR_TAKE)), clip):
			model.free()
			quit(1)
			return
		library.add_animation(StringName(clip), anim)
		print("added '%s' <- '%s' len=%.4f loop=%s tracks=%d"
				% [clip, take, anim.length, anim.loop_mode != Animation.LOOP_NONE, anim.get_track_count()])
	model.free()

	var err := ResourceSaver.save(library, LIBRARY_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [LIBRARY_PATH, err])
		quit(1)
		return
	print("saved %s with %d clips" % [LIBRARY_PATH, library.get_animation_list().size()])
	quit(0)


## Story 7-3, feel pass 3: give `anim`'s `HEAD_TRACKS` the rotation keys of `donor`'s, key for key
## (see `STRAIGHTEN_BACKWARD_HEAD`). Every other track is left alone. Returns false, with an error,
## if either clip lacks one of the tracks or the two clips are not the same length.
func _straighten_head(anim: Animation, donor: Animation, clip: String) -> bool:
	if donor == null or not is_equal_approx(anim.length, donor.length):
		push_error("clip '%s' cannot take its head from '%s': missing, or a different length" % [clip, HEAD_DONOR_TAKE])
		return false
	for path: String in HEAD_TRACKS:
		var track := anim.find_track(NodePath(path), Animation.TYPE_ROTATION_3D)
		var donor_track := donor.find_track(NodePath(path), Animation.TYPE_ROTATION_3D)
		if track < 0 or donor_track < 0 or donor.track_get_key_count(donor_track) == 0:
			push_error("clip '%s' or its donor '%s' has no rotation track '%s'" % [clip, HEAD_DONOR_TAKE, path])
			return false
		for key in range(anim.track_get_key_count(track) - 1, -1, -1):
			anim.track_remove_key(track, key)
		for key in donor.track_get_key_count(donor_track):
			anim.rotation_track_insert_key(track, donor.track_get_key_time(donor_track, key),
					donor.track_get_key_value(donor_track, key))
		print("straightened '%s' %s: %d rotation keys from '%s'"
				% [clip, path, donor.track_get_key_count(donor_track), HEAD_DONOR_TAKE])
	return true


## Story 7-3, feel pass: take the FORWARD TRAVEL out of a clip's pelvis. MEASURED
## (`measure_hellhound_rig.gd`, table 4): `Attack01` throws the pelvis from z -1.152 to +1.070 model
## units and brings it back over the rest of the take -- 0.73 m at the 0.33 mount. The runner already
## carries the leaping body its authored distance, so the clip's own throw landed the mesh that much
## PAST the actor and then slid it back during recovery, while state held it rooted ("slide in the
## animations", the live smoke). Every pelvis key that is forward of where the take STARTS is put
## back on that line; the crouch before take-off (which goes the other way) and the height of the
## jump are left as authored. Returns false, with an error, if the track cannot be edited.
func _hold_pelvis_back(anim: Animation, clip: String) -> bool:
	var track := anim.find_track(NodePath(PELVIS_TRACK), Animation.TYPE_POSITION_3D)
	if track < 0 or anim.track_get_key_count(track) == 0:
		push_error("clip '%s' has no editable position track '%s'" % [clip, PELVIS_TRACK])
		return false
	var start: Vector3 = anim.track_get_key_value(track, 0)
	var furthest := start.z
	var moved := 0
	for key in anim.track_get_key_count(track):
		var value: Vector3 = anim.track_get_key_value(track, key)
		furthest = maxf(furthest, value.z)
		if value.z > start.z:
			value.z = start.z
			anim.track_set_key_value(track, key, value)
			moved += 1
	print("held '%s' pelvis back: %d of %d keys, forward travel %.3f -> 0.000 model units"
			% [clip, moved, anim.track_get_key_count(track), furthest - start.z])
	return true
