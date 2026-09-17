extends SceneTree

## Story 6-6a (asset prerequisite): adds the hero's FIVE defense/reaction clips -- `hit_react`,
## `stunned`, `knockdown`, `get_up`, `block_impact` -- into the existing paladin AnimationLibrary
## `assets/characters/paladin/paladin_anims.res`, taking it from eighteen named animations to
## twenty-three.
##
## THE `tools/add_paladin_locomotion.gd` PATTERN, NOT A NEW MECHANISM. EXTENDS, NEVER REBUILDS
## (`paladin_anims.res` carries retimed and track-edited clips a rebuild from FBX would silently
## revert -- see that tool's header); HEADLESS, NOT THE EDITOR (the editor was used only to IMPORT the
## five .fbx files, and `project.godot` was diffed after that session); each source FBX's single
## Mixamo `mixamo_com` take is duplicated, renamed to the clip name `AnimationController` selects by,
## and given the loop flag below. The five sidecars match the existing clip sidecars in `[params]`
## (no import script -- that wiring is the MODEL fbx's only).
##
## ONE TRACK EDIT, MEASURED FIRST. The 6-6a dev pass measured every source take's Hips position and
## yaw (`tools/measure_hips_displacement.gd`, table recorded in the story's Dev Agent Record).
## `hit_react`, `stunned` and `block_impact` are net-zero in position and yaw. `get_up` travels 0.16
## planar at peak -- inside the `3-0b/R27` ceiling (`ROLL_HIPS_PLANAR_MAX = 0.25`) -- and is left as
## authored. `knockdown` is NOT: the body falls BACKWARD 0.55 planar net (0.61 peak) and ends 0.63
## away from where `get_up` starts, so the mesh would slide out from over its rooted capsule while
## down and then POP on the get-up cut -- the root-slide artifact `3-0b`'s roll fix existed to
## remove. `knockdown` therefore takes that fix's route (`_pin_hips_planar`, below): its Hips X/Z
## keys are pinned to the rest origin and Y is preserved, so the fall still reads as a fall.
## Yaw is NOT neutralised on any of the five: none is a continuous turn that would stack on
## `HeroActor.drive()`'s single yaw write (DECISION A) -- `knockdown`/`get_up` swing the body a
## bounded amount inside a one-shot and end in a held or cut-away pose (table in the story).
##
## IDEMPOTENT: a clip already present is replaced.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_defense_reactions.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this run adds. test/integration/test_rig_clips.gd asserts the
## SAME matrix (for every clip) against the assembled scene, independently. ALL FIVE ARE ONE-SHOTS:
## `hit_react`/`block_impact`/`get_up` are single reactions, and `stunned`/`knockdown` are HELD on
## their final frame for the rest of the stun window rather than looped (story AC 10).
const NEW_CLIPS := {
	"hit_react": false,
	"stunned": false,
	"knockdown": false,
	"get_up": false,
	"block_impact": false,
}

## The eighteen clips already assembled (3-0a's six, 5-0a's three, 5-3's three, 6-7b's six),
## asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
	&"swipe", &"jump_attack", &"thrust",
	&"walk", &"walk_strafe_left", &"walk_strafe_right", &"walk_backpedal",
	&"turn_left", &"turn_right",
]

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"

## The clips whose Hips POSITION track has its planar (X/Z) travel pinned -- see the header.
const PLANAR_PINNED_CLIPS: Array[String] = ["knockdown"]

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


## `3-0b/R27`'s roll route, applied to a second clip: every Hips POSITION key's X and Z are set to the
## rest origin (0, 0) and Y is kept, so the body falls straight down over its capsule. The source FBX
## is never touched; only the duplicated take. Returns false (with the reason pushed) if the clip has
## no Hips position track -- the caller then refuses to write the library.
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
