extends SceneTree

## Story 5-0a (AC 1): adds the hero's THREE new locomotion clips -- `strafe_left`,
## `strafe_right`, `backpedal` -- into the existing paladin AnimationLibrary
## `assets/characters/paladin/paladin_anims.res`, taking it from six named animations to
## nine.
##
## EXTENDS, NEVER REBUILDS. This is the one structural difference from
## `tools/build_zombie_anims.gd`, which builds the minion library from its clip FBXs in
## full. `paladin_anims.res` is NOT a pure function of the six paladin clip FBXs any more:
## `tools/retime_clips.gd` has since time-scaled `attack` and `roll` to their authored tick
## windows (3-0b AC3, pinned by test/integration/test_clip_timing.gd), and 3-0b's roll
## Hips-track planar fix edited key VALUES. A rebuild-from-FBX would silently revert both.
## So this loads the library that exists, adds three animations to it, and saves it back.
##
## HEADLESS, NOT THE EDITOR. `3-0a/R3` authorizes the editor for library assembly; it does
## not mandate it, and every editor session in this repo is a measured hazard (six recorded
## incidents of `project.godot`'s `physics_ticks_per_second` pin being deleted). The editor
## is needed in this pass only to IMPORT the three .fbx files; the assembly does not need it.
##
## Each source clip FBX imports as a scene holding one AnimationPlayer with one take under
## the Mixamo default name `mixamo_com` (measured; Godot sanitizes the dot). This lifts that
## take out, RENAMES it to the clip name the presentation controller selects by, and sets the
## loop flag AC 1 pins: all three are repeating movement loops, so loop ENABLED. The model's
## own bundled `mixamo_com` never reaches this library -- it is removed at import time by
## `assets/characters/paladin/strip_model_anim.gd`, which is wired on the MODEL fbx only
## (`paladin.fbx.import`); the six existing clip FBXs carry no import script either, and the
## three new sidecars match them byte-for-byte in `[params]`.
##
## Track paths are left exactly as imported (`Skeleton3D:mixamorig_Hips`, ...), which is why
## hero.tscn's AnimationPlayer sets `root_node = NodePath("..")` -- pointing at the Paladin
## model instance whose child is that `Skeleton3D`.
##
## IDEMPOTENT: a clip already present is replaced, so re-running reproduces the same result
## rather than erroring on a duplicate name.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_locomotion.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this story adds. test/integration/test_rig_clips.gd
## asserts the SAME matrix (for all nine clips) against the assembled scene, independently --
## the test never imports this file.
const NEW_CLIPS := {
	"strafe_left": true,
	"strafe_right": true,
	"backpedal": true,
}

## The six clips 3-0a assembled, asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
]

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"


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
		# Duplicated, not referenced: the source scene is freed below, and a library holding
		# animations owned by a freed import scene is not a safe artifact to serialize.
		var anim: Animation = player.get_animation(SOURCE_TAKE).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if NEW_CLIPS[clip] else Animation.LOOP_NONE
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
