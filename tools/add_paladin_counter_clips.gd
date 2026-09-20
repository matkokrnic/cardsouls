extends SceneTree

## Story 6-6b (AC 13, asset prerequisite): adds the hero's FOUR colour-counter clips --
## `counter_jump`, `counter_backflip`, `counter_slide`, `counter_throw` -- into the existing paladin
## AnimationLibrary `assets/characters/paladin/paladin_anims.res`, taking it from twenty-three named
## animations to TWENTY-SEVEN.
##
## THE `tools/add_paladin_defense_reactions.gd` ROUTE, EXTENDED AND NEVER REBUILT (AC 13 says so in
## as many words). `paladin_anims.res` carries retimed and track-edited clips a rebuild from FBX
## would silently revert, so this tool loads the library, asserts every one of the twenty-three
## already there, adds four, and saves. HEADLESS, NOT THE EDITOR: the editor was used only for the
## one `--headless --editor --quit` import scan that generated the four `.fbx.import` sidecars, and
## `project.godot` was SHA-256'd before and diffed after it (unchanged).
##
## THE CLIPS ARE ADDED RAW AND UNCUT, and that is AC 13's ruling rather than an omission: "usable
## ranges are NOT trimmed in the files". Each colour's cut range, playback speed and (for RED) the
## two-clip join are PRESENTATION constants on `AnimationController` (`_COUNTER_PRESENTATION`), so a
## smoke-time retune is a one-line edit there and never a library rebuild.
##
## ONE TRACK EDIT, MEASURED FIRST (the 6-6a header's discipline, applied to the one clip that needs
## it). Measured raw Hips `Lcl Translation`, first->last key, metres (story Measured Fact 11):
##   counter_jump      0.0000 net / 0.0714 peak planar -- in place, jump arc only. NO PIN.
##   counter_backflip  0.0000 net / 0.1719 peak planar -- in place. NO PIN.
##   counter_throw     0.3774 net / 0.6476 peak planar raw; 0.059 / 0.108 inside the played cut.
##                     Both inside the `3-0b/R27` ceiling (`ROLL_HIPS_PLANAR_MAX = 0.25`). NO PIN.
##   counter_slide     4.3135 net planar -- a run-up plus a slide, seventeen times the ceiling.
##                     PINNED: BLUE's body is carried by STATE (AC 9, the authored travel distance
##                     over BLUE's busy span), so the clip must contribute no second displacement or
##                     the hero would travel twice. Its Hips X/Z keys are pinned to the rest origin
##                     and Y is preserved, exactly as `knockdown` is.
## Yaw is NOT neutralised on any of the four: none is a continuous turn that would stack on
## `HeroActor.drive()`'s single yaw write (DECISION A). `counter_backflip`'s Hips pitch winds -360
## degrees over the clip, which is a full revolution about the LOCAL X axis inside a one-shot, not a
## heading change -- the measured check that it ends where it starts is printed below rather than
## assumed (the story requires it verified on the IMPORTED quaternion track).
##
## IDEMPOTENT: a clip already present is replaced.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_counter_clips.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this run adds. test/integration/test_rig_clips.gd asserts the
## SAME matrix (for every clip) against the assembled scene, independently. ALL FOUR ARE ONE-SHOTS:
## a counter is a single reaction played once inside its colour's busy span (AC 10), never looped.
const NEW_CLIPS := {
	"counter_jump": false,
	"counter_backflip": false,
	"counter_slide": false,
	"counter_throw": false,
}

## The twenty-three clips already assembled (3-0a's six, 5-0a's three, 5-3's three, 6-7b's six,
## 6-6a's five), asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
	&"swipe", &"jump_attack", &"thrust",
	&"walk", &"walk_strafe_left", &"walk_strafe_right", &"walk_backpedal",
	&"turn_left", &"turn_right",
	&"hit_react", &"stunned", &"knockdown", &"get_up", &"block_impact",
]

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"

## The clips whose Hips POSITION track has its planar (X/Z) travel pinned -- see the header.
const PLANAR_PINNED_CLIPS: Array[String] = ["counter_slide"]

const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"


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
		if PLANAR_PINNED_CLIPS.has(clip) and not _pin_hips_planar(anim, clip):
			root_node.free()
			quit(1)
			return
		_report_hips_rotation(anim, clip)
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


## `3-0b/R27`'s roll route, applied to a third clip (`knockdown` was the second): every Hips POSITION
## key's X and Z are set to the rest origin (0, 0) and Y is kept, so the slide's vertical crouch is
## preserved while its 4.31 m of planar travel is removed -- that travel is BLUE's authored STATE
## displacement (AC 9), and leaving it in the clip too would move the hero twice. The source FBX is
## never touched; only the duplicated take. Returns false (with the reason pushed) if the clip has no
## Hips position track -- the caller then refuses to write the library.
func _pin_hips_planar(anim: Animation, clip: String) -> bool:
	var track := -1
	for t in anim.get_track_count():
		if anim.track_get_path(t) == NodePath(HIPS_TRACK) \
				and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			track = t
			break
	if track == -1 or anim.track_get_key_count(track) == 0:
		push_error("%s: no %s position track to pin -- refusing to write" % [clip, HIPS_TRACK])
		return false
	var keys := anim.track_get_key_count(track)
	for k in keys:
		var v: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(0.0, v.y, 0.0))
	print("pinned Hips planar on '%s' (%d position keys)" % [clip, keys])
	return true


## Story 6-6b (Measured Fact 11's standing obligation): PRINTS, never assumes, whether the imported
## Hips ROTATION track ends where it starts. The raw FBX Euler channel on `counter_backflip` winds
## -360 degrees across the clip; a quaternion track cannot represent a full winding, so what matters
## is only the first-to-last KEY delta after import. A non-zero residual here would mean the clip
## leaves the body yawed and would stack on `HeroActor.drive()`'s single yaw write (DECISION A).
## Reported for every clip so the four numbers sit side by side in the dev record.
func _report_hips_rotation(anim: Animation, clip: String) -> void:
	for t in anim.get_track_count():
		if anim.track_get_path(t) != NodePath(HIPS_TRACK) \
				or anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var keys := anim.track_get_key_count(t)
		if keys == 0:
			return
		var first: Quaternion = anim.track_get_key_value(t, 0)
		var last: Quaternion = anim.track_get_key_value(t, keys - 1)
		print("  '%s' hips rotation keys=%d first->last angle=%.4f deg"
			% [clip, keys, rad_to_deg(first.angle_to(last))])
		return
