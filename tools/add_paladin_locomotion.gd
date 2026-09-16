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
## STORY 6-7b (AC 3/AC 7) EXTENDED THE MATRIX, NOT THE MECHANISM: the six walk-family and
## turn-in-place clips are this run's NEW_CLIPS, the twelve already in the library are its
## EXISTING_CLIPS, and the two turn clips additionally have their Hips rotation track's
## accumulated yaw neutralised before they are added (`_neutralise_hips_yaw`, below). Their six
## sidecars match the existing clip sidecars byte-for-byte in `[params]` (no import script).
##
## IDEMPOTENT: a clip already present is replaced, so re-running reproduces the same result
## rather than erroring on a duplicate name.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_locomotion.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"

## The clip name -> loop flag matrix this run adds. test/integration/test_rig_clips.gd
## asserts the SAME matrix (for every clip) against the assembled scene, independently --
## the test never imports this file.
##
## STORY 6-7b (AC 3) moved 5-0a's three (`strafe_left`/`strafe_right`/`backpedal`) into
## EXISTING_CLIPS below -- they are in the library now and a re-lift from FBX is no longer this
## tool's job -- and made the matrix the SIX walk/turn clips, taking the library from twelve to
## eighteen. ALL SIX LOOP: the walk family on the run family's own precedent, and the two turn
## clips RULED `true` (the story's Dev Notes) because lock-driven rotation is continuous and a
## one-shot would freeze on its end pose mid-turn.
const NEW_CLIPS := {
	"walk": true,
	"walk_strafe_left": true,
	"walk_strafe_right": true,
	"walk_backpedal": true,
	"turn_left": true,
	"turn_right": true,
}

## The twelve clips already assembled (3-0a's six, 5-0a's three, 5-3's three via
## `add_paladin_attacks.gd`), asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
	&"swipe", &"jump_attack", &"thrust",
]

## STORY 6-7b (AC 7): the clips whose Hips ROTATION track has its accumulated YAW neutralised
## in this tool (see `_neutralise_hips_yaw`). The turn clips alone: they are the only clips whose
## whole point is rotating the body, and that rotation is already delivered by
## `HeroActor.drive()`'s single yaw write (DECISION A) -- left in, the body would turn twice.
const YAW_NEUTRALISED_CLIPS: Array[String] = ["turn_left", "turn_right"]

const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

## The vertical axis in the Hips track's own space. `mixamorig_Hips` is the skeleton's ROOT bone
## (no parent), so its pose rotation is expressed in Skeleton3D space, and the paladin's Skeleton3D
## carries an IDENTITY transform inside the model (measured, 6-7b dev pass) -- so skeleton +Y is
## the model's up, and yaw is rotation about it.
const YAW_AXIS := Vector3.UP

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
		if YAW_NEUTRALISED_CLIPS.has(clip) and not _neutralise_hips_yaw(anim, clip):
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


## STORY 6-7b (AC 7): removes the accumulated YAW from a turn clip's Hips ROTATION track, and
## nothing else -- the `3-0b` roll-Hips precedent (a position track's X/Z zeroed) extended to a
## rotation track's yaw component. The source FBX is never touched; only the duplicated take.
##
## SWING-TWIST, NOT EULER. Each key q is split as q = twist * swing, where `twist` is the rotation
## about YAW_AXIS and `swing` is the remainder (the sway/tilt, expressed in the body's own yawed
## frame). The key is rewritten as twist_0 * swing: the swing is kept BIT-FOR-BIT the same
## quaternion and every key's twist is replaced by the FIRST key's. So:
##   * the clip's net yaw (last vs first) becomes zero, and so does every mid-clip yaw excursion
##     -- the body holds the start orientation, which is the idle stance's own authored yaw
##     (both turn clips start on it, measured), so an idle <-> turn crossfade does not swing;
##   * sway/tilt are untouched by construction: no angle is extracted and re-composed, so there
##     is no Euler order or wrap-around to get wrong;
##   * the position track is not read or written.
## Returns false (with the reason pushed) if the clip carries no Hips rotation track -- the
## caller then refuses to write the library rather than ship a double-rotating turn (AC 7 STOP).
func _neutralise_hips_yaw(anim: Animation, clip: String) -> bool:
	var track := -1
	for t in anim.get_track_count():
		if anim.track_get_path(t) == NodePath(HIPS_TRACK) 				and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			track = t
			break
	if track == -1 or anim.track_get_key_count(track) == 0:
		push_error("%s: no %s rotation track to neutralise -- refusing to write" % [clip, HIPS_TRACK])
		return false
	var keys := anim.track_get_key_count(track)
	var twist_0 := twist_about(anim.track_get_key_value(track, 0), YAW_AXIS)
	for k in keys:
		var q: Quaternion = anim.track_get_key_value(track, k)
		var swing := twist_about(q, YAW_AXIS).inverse() * q
		anim.track_set_key_value(track, k, (twist_0 * swing).normalized())
	print("neutralised Hips yaw on '%s' (%d rotation keys)" % [clip, keys])
	return true


## The twist of `q` about the unit `axis`: its vector part projected onto the axis, renormalised.
## Identity when `q` has no component about the axis at all (a pure 180-degree swing).
static func twist_about(q: Quaternion, axis: Vector3) -> Quaternion:
	var projected := axis * Vector3(q.x, q.y, q.z).dot(axis)
	var twist := Quaternion(projected.x, projected.y, projected.z, q.w)
	if twist.length_squared() < 1e-12:
		return Quaternion.IDENTITY
	return twist.normalized()
