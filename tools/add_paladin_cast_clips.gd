extends SceneTree

## Story 6-5c (AC 29, asset prerequisite): adds the hero's TWO hero-cast clips -- `cast` (Mixamo
## "Sword And Shield Casting": the hero raises the sword) and `dizzy` (Mixamo "Dizzy Idle") -- into
## the existing paladin AnimationLibrary `assets/characters/paladin/paladin_anims.res`, taking it
## from twenty-seven named animations to TWENTY-NINE.
##
## THE `tools/add_paladin_counter_clips.gd` ROUTE, EXTENDED AND NEVER REBUILT, which is that tool's
## own inherited discipline and the reason it exists in this shape: `paladin_anims.res` carries
## retimed and track-edited clips that a rebuild from FBX would silently revert, so this tool LOADS
## the library, asserts every one of the twenty-seven already there, adds two, and saves. HEADLESS,
## NOT THE EDITOR (`3-0a/R3`): the editor was used only for the one `--headless --editor --quit`
## import scan that generated the two `.fbx.import` sidecars, with `project.godot` and
## `src/main/main.tscn` SHA-256'd before and diffed after it (both unchanged).
##
## BOTH ARE ONE-SHOTS, and for `dizzy` that is a decision rather than a default. The source is a
## Mixamo IDLE and would naturally loop, but `AnimationController._play_stun` HOLDS a stun pose on
## its final frame for the stun window (`6-6a` AC 10) -- which only works on a `LOOP_NONE` clip --
## and `stunned` / `knockdown` are already baked that way for exactly that reason. A looping `dizzy`
## would restart mid-stun instead of holding.
##
## THE CLIPS ARE ADDED RAW AND UNCUT, the counter tool's ruling applied again: any cut range or
## playback rate is a PRESENTATION constant on `AnimationController`, so a smoke-time retune is a
## one-line edit there and never a library rebuild. The cast's RAISE FRAME is MEASURED separately by
## `tools/measure_cast_clip_frames.gd` and consumed as a presentation constant, not baked in here.
##
## HIPS DISPLACEMENT IS MEASURED AND PRINTED, NEVER ASSUMED (the `6-6b` header's standing
## obligation). Neither clip is expected to travel -- a stationary cast and a stagger-in-place --
## but "expected" is not a measurement, so the net and peak planar travel are reported below and the
## `3-0b/R27` ceiling (`ROLL_HIPS_PLANAR_MAX = 0.25 m`) is checked against them. Nothing is pinned
## unless the printed numbers say it must be, and if they do this tool refuses to write rather than
## silently shipping a clip that would move the hero a second time.
##
## IDEMPOTENT: a clip already present is replaced.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_cast_clips.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this run adds. test/integration/test_rig_clips.gd asserts the
## SAME matrix (for every clip) against the assembled scene, independently.
const NEW_CLIPS := {
	"cast": false,
	"dizzy": false,
}

## The twenty-seven clips already assembled (3-0a's six, 5-0a's three, 5-3's three, 6-7b's six,
## 6-6a's five, 6-6b's four), asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
	&"swipe", &"jump_attack", &"thrust",
	&"walk", &"walk_strafe_left", &"walk_strafe_right", &"walk_backpedal",
	&"turn_left", &"turn_right",
	&"hit_react", &"stunned", &"knockdown", &"get_up", &"block_impact",
	&"counter_jump", &"counter_backflip", &"counter_slide", &"counter_throw",
]

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"

const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

## `3-0b/R27`'s planar ceiling, reused as the refusal threshold rather than re-derived.
const ROLL_HIPS_PLANAR_MAX := 0.25


func _initialize() -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH)
	if library == null:
		push_error("%s did not load" % LIBRARY_PATH)
		quit(1)
		return
	for existing: StringName in EXISTING_CLIPS:
		if not library.has_animation(existing):
			push_error("%s is missing pre-existing clip '%s' -- refusing to write"
				% [LIBRARY_PATH, existing])
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
			push_error("%s.fbx: expected exactly 1 AnimationPlayer, found %d"
				% [clip, players.size()])
			root_node.free()
			quit(1)
			return
		var player := players[0] as AnimationPlayer
		if not player.has_animation(SOURCE_TAKE):
			push_error("%s.fbx: no '%s' take (found %s)"
				% [clip, SOURCE_TAKE, player.get_animation_list()])
			root_node.free()
			quit(1)
			return
		# Duplicated, not referenced: the source scene is freed below.
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


## MEASURES and PRINTS the Hips planar (X/Z) travel of the imported take -- net first-to-last and
## peak-from-origin, in metres -- and REFUSES the write if either exceeds the `3-0b/R27` ceiling.
##
## A REFUSAL RATHER THAN AN AUTOMATIC PIN, deliberately. `counter_slide` was pinned because STATE
## carried its body (`6-6b` AC 9) and the clip would have moved the hero twice; neither of these two
## clips has any state-side displacement to double, so a large number here would mean the clip is
## not the one the story thinks it is, and the honest response is to stop and let a human look --
## not to silently flatten a track. Returns false with the reason pushed.
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
			push_error(("%s: hips planar travel net=%.4f peak=%.4f exceeds the %.4f ceiling -- "
				+ "refusing to write. Neither cast clip has state-side displacement to double, so "
				+ "this means the clip is not the in-place animation the story assumes.")
				% [clip, net, peak, ROLL_HIPS_PLANAR_MAX])
			return false
		return true
	print("  '%s' has no %s position track" % [clip, HIPS_TRACK])
	return true
