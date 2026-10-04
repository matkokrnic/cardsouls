extends SceneTree

## Story 7-1 (AC 23-26): adds the hero's THREE spell-cast clips -- `cast_fireball` (the operator's Fireball
## clip, hash-confirmed distinct from `cast.fbx`), `cast_rocksling_lift` (Mixamo "Standing 2H Cast Spell 01")
## and `cast_rocksling_throw` (Mixamo "Standing 2H Magic Attack 01") -- into the existing paladin
## AnimationLibrary `assets/characters/paladin/paladin_anims.res`, taking it from twenty-nine named animations
## to THIRTY-TWO.
##
## `tools/add_paladin_cast_clips.gd`'s ROUTE, EXTENDED AND NEVER REBUILT, for that tool's own inherited reason:
## `paladin_anims.res` carries retimed and track-edited clips that a rebuild from FBX would silently revert, so
## this tool LOADS the library, asserts every one of the twenty-nine already there, adds three, and saves.
## HEADLESS: the `.fbx.import` sidecars come from the one `--headless --editor --quit` import scan.
##
## ALL THREE ARE ONE-SHOTS (AC 26): each is played once inside the authored cast window, its playhead driven
## by `AnimationController.spell_cast_pose`, never looped.
##
## THE CLIPS ARE ADDED RAW AND UNCUT, `add_paladin_cast_clips.gd`'s ruling: the RELEASE FRAMES are MEASURED
## separately by `tools/measure_spell_clip_frames.gd` and consumed as presentation constants.
##
## HIPS DISPLACEMENT IS MEASURED AND PRINTED, NEVER ASSUMED (AC 25): the net and peak planar travel of each
## clip's Hips track are reported and checked against the `3-0b/R27` ceiling (0.25 m). A cast is stood through
## (the hero is hard-rooted, `6-5c`), and none of these clips has state-side displacement to double -- so a
## number over the ceiling means the clip is not the in-place animation the story assumes, and this tool
## REFUSES to write rather than silently flattening a track.
##
## IDEMPOTENT: a clip already present is replaced.
##
## 7-1 POLISH ROUND (operator smoke, 2026-10-04): THIRTY-TWO -> THIRTY-FOUR. `NEW_CLIPS` now names the two gesture
## clips -- `cast_buff` (Vampiric Aura / Frostbite, a buff gesture) and `cast_counterspell` (a sword strike into the
## air) -- and the three spell-cast clips this tool first added join `EXISTING_CLIPS`, asserted and left untouched.
## The same Hips ceiling applies: a gesture is played only while the hero stands still and is cut by any movement
## (`AnimationController.play_gesture`), so a clip that travels would slide just the same.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_spell_clips.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this run adds. test/integration/test_rig_clips.gd asserts the SAME matrix
## (for every clip) against the assembled scene, independently.
const NEW_CLIPS := {
	"cast_buff": false,
	"cast_counterspell": false,
}

## The thirty-two clips already assembled, asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
	&"swipe", &"jump_attack", &"thrust",
	&"walk", &"walk_strafe_left", &"walk_strafe_right", &"walk_backpedal",
	&"turn_left", &"turn_right",
	&"hit_react", &"stunned", &"knockdown", &"get_up", &"block_impact",
	&"counter_jump", &"counter_backflip", &"counter_slide", &"counter_throw",
	&"cast", &"dizzy",
	&"cast_fireball", &"cast_rocksling_lift", &"cast_rocksling_throw",
]

const SOURCE_TAKE := &"mixamo_com"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
const ROLL_HIPS_PLANAR_MAX := 0.25


func _initialize() -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH)
	if library == null:
		push_error("%s did not load" % LIBRARY_PATH)
		quit(1)
		return
	for existing: StringName in EXISTING_CLIPS:
		if not library.has_animation(existing):
			push_error("%s is missing pre-existing clip '%s' -- refusing to write" % [LIBRARY_PATH, existing])
			quit(1)
			return

	for clip: String in NEW_CLIPS:
		var scene: PackedScene = load(SOURCE_DIR + clip + ".fbx")
		if scene == null:
			push_error("clip FBX did not load: %s" % clip)
			quit(1)
			return
		var root_node := scene.instantiate()
		var players := root_node.find_children("*", "AnimationPlayer", true, false)
		if players.size() != 1:
			push_error("%s.fbx: expected exactly 1 AnimationPlayer, found %d" % [clip, players.size()])
			root_node.free()
			quit(1)
			return
		var player := players[0] as AnimationPlayer
		if not player.has_animation(SOURCE_TAKE):
			push_error("%s.fbx: no '%s' take (found %s)" % [clip, SOURCE_TAKE, player.get_animation_list()])
			root_node.free()
			quit(1)
			return
		var anim: Animation = player.get_animation(SOURCE_TAKE).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if NEW_CLIPS[clip] else Animation.LOOP_NONE
		if not _report_hips_planar(anim, clip):
			root_node.free()
			quit(1)
			return
		if library.has_animation(StringName(clip)):
			library.remove_animation(StringName(clip))
		library.add_animation(StringName(clip), anim)
		print("added '%s' len=%.4f loop=%s tracks=%d"
			% [clip, anim.length, anim.loop_mode != Animation.LOOP_NONE, anim.get_track_count()])
		root_node.free()

	var err := ResourceSaver.save(library, LIBRARY_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [LIBRARY_PATH, err])
		quit(1)
		return
	print("saved %s with %d clips: %s" % [
		LIBRARY_PATH, library.get_animation_list().size(), library.get_animation_list()])
	quit(0)


## `add_paladin_cast_clips.gd`'s measurement verbatim: net first-to-last and peak-from-origin planar travel
## of the Hips position track, refused over the ceiling.
func _report_hips_planar(anim: Animation, clip: String) -> bool:
	for t in anim.get_track_count():
		if anim.track_get_path(t) != NodePath(HIPS_TRACK) \
				or anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var keys := anim.track_get_key_count(t)
		if keys == 0:
			print("  '%s' hips position track has no keys" % clip)
			return true
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, keys - 1)
		var net := Vector2(last.x - first.x, last.z - first.z).length()
		var peak := 0.0
		for k in keys:
			var v: Vector3 = anim.track_get_key_value(t, k)
			peak = maxf(peak, Vector2(v.x - first.x, v.z - first.z).length())
		print("  '%s' hips keys=%d net_planar=%.4f peak_planar=%.4f (ceiling %.4f)"
			% [clip, keys, net, peak, ROLL_HIPS_PLANAR_MAX])
		if net > ROLL_HIPS_PLANAR_MAX or peak > ROLL_HIPS_PLANAR_MAX:
			push_error(("%s: hips planar travel net=%.4f peak=%.4f exceeds the %.4f ceiling -- refusing "
				+ "to write. A cast is stood through, so this clip is not the in-place animation the story "
				+ "assumes.") % [clip, net, peak, ROLL_HIPS_PLANAR_MAX])
			return false
		return true
	print("  '%s' has no %s position track" % [clip, HIPS_TRACK])
	return true
