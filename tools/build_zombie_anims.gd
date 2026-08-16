extends SceneTree

## Story 4-3c (AC 3): assembles the minion's FOUR clips into the single AnimationLibrary
## `assets/characters/skeletonzombie/skeletonzombie_anims.res` that unit_actor.tscn's
## AnimationPlayer references -- the counterpart of the paladin's `paladin_anims.res`.
##
## HEADLESS, NOT THE EDITOR -- a deliberate deviation from 3-0a's route, recorded in the
## story's Dev Agent Record. 3-0a/R3 AUTHORIZES the editor for library assembly; it does not
## MANDATE it. Every editor session in this repo is a measured hazard (this story's own
## precondition check caught the SIXTH instance of the editor deleting `project.godot`'s
## `physics_ticks_per_second` pin), so the assembly that can be done without one is done
## without one. The reimport that installs `strip_model_anim.gd` still needs the editor;
## this does not.
##
## The second reason is reproducibility: `paladin_anims.res` is an editor artifact nobody
## can rebuild from source without repeating a manual GUI session. This library is a
## FUNCTION of the four clip FBXs, and re-running this tool reproduces it byte-for-byte
## from them -- the same posture `tools/retime_clips.gd` already takes toward the paladin
## library's timing.
##
## Each source clip FBX imports as a scene holding one AnimationPlayer with one take, the
## Mixamo default name `mixamo_com` (measured). This lifts that take out, RENAMES it to the
## clip name the presentation controller selects by, and sets the loop flag AC 3 pins:
## loop ENABLED on idle/walk, DISABLED on attack/death. The model's own bundled `mixamo_com`
## never reaches this library at all -- it is removed at import time by
## `assets/characters/skeletonzombie/strip_model_anim.gd`, and the two mechanisms are
## independent (this tool reads the CLIP fbxs; the hook strips the MODEL fbx).
##
## Track paths are left exactly as imported (`Skeleton3D:mixamorig_Hips`, ...), which is why
## unit_actor.tscn's AnimationPlayer sets `root_node = NodePath("..")` -- pointing at the
## model instance whose child is that `Skeleton3D`. The paladin's AnimationPlayer resolves
## its own tracks the identical way.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/build_zombie_anims.gd

const SOURCE_DIR := "res://assets/characters/skeletonzombie/"
const LIBRARY_PATH := SOURCE_DIR + "skeletonzombie_anims.res"

## The clip name -> loop flag matrix AC 3 pins, and the single source of truth this tool
## builds from. test/integration/test_unit_rig_clips.gd asserts the SAME matrix against the
## assembled scene, independently -- the test never imports this file.
const CLIPS := {
	"idle": true,
	"walk": true,
	"attack": false,
	"death": false,
}

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"


func _initialize() -> void:
	var library := AnimationLibrary.new()
	for clip: String in CLIPS:
		var scene: PackedScene = load(SOURCE_DIR + clip + ".fbx")
		if scene == null:
			push_error("clip FBX did not load: %s" % clip)
			quit(1)
			return
		var root := scene.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		if players.size() != 1:
			push_error("%s.fbx: expected exactly 1 AnimationPlayer, found %d"
				% [clip, players.size()])
			root.free()
			quit(1)
			return
		var player := players[0] as AnimationPlayer
		if not player.has_animation(SOURCE_TAKE):
			push_error("%s.fbx: no '%s' take (found %s)"
				% [clip, SOURCE_TAKE, player.get_animation_list()])
			root.free()
			quit(1)
			return
		# Duplicated, not referenced: the source scene is freed below, and a library holding
		# animations owned by a freed import scene is not a safe artifact to serialize.
		var anim: Animation = player.get_animation(SOURCE_TAKE).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip] else Animation.LOOP_NONE
		library.add_animation(StringName(clip), anim)
		print("added '%s' len=%.4f loop=%s tracks=%d"
			% [clip, anim.length, anim.loop_mode != Animation.LOOP_NONE, anim.get_track_count()])
		root.free()

	var err := ResourceSaver.save(library, LIBRARY_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [LIBRARY_PATH, err])
		quit(1)
		return
	print("saved %s with %d clips" % [LIBRARY_PATH, library.get_animation_list().size()])
	quit(0)
