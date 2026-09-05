extends SceneTree

## Story 5-3 (AC 1): adds the hero's THREE new attack clips -- `swipe`, `jump_attack`,
## `thrust` -- into the existing paladin AnimationLibrary
## `assets/characters/paladin/paladin_anims.res`, taking it from nine named animations to
## twelve.
##
## EXTENDS, NEVER REBUILDS -- the same discipline `add_paladin_locomotion.gd` established
## (5-0a): `paladin_anims.res` carries retimes and Hips-track fixes no longer derivable from
## the source FBXs alone (`3-0b` AC3/R27). A rebuild-from-FBX would silently revert them. So
## this loads the library that exists, adds three animations to it, and saves it back. This
## is a NEW tool, not an edit to `add_paladin_locomotion.gd` -- that file's `NEW_CLIPS`/
## `EXISTING_CLIPS` constants are hardcoded to 5-0a's three locomotion clips (5-3 Ruling 5).
##
## HEADLESS, NOT THE EDITOR (`3-0a/R3`). The editor is needed only to IMPORT the three .fbx
## files; assembly does not need it.
##
## Each source clip FBX imports as a scene holding one AnimationPlayer with one take under
## the Mixamo default name `mixamo_com` (measured; Godot sanitizes the dot). This lifts that
## take out, renames it to the clip name the presentation controller selects by, and sets the
## loop flag AC 2 pins: all three are one-shot attack poses, so loop DISABLED (matching
## `attack`'s existing flag, not a locomotion loop).
##
## IDEMPOTENT: a clip already present is replaced, so re-running reproduces the same result
## rather than erroring on a duplicate name.
##
## CONDITIONAL PLANAR ZEROING (5-3 AC 6, `3-0b/R27`'s roll fix as precedent). The hero is
## hard-rooted for the whole `CHARGING` window (`5-2` Ruling 3); a clip whose Hips position
## track carries nonzero net XZ displacement would walk the model off its own stationary
## collision box. Any of the three new clips whose net XZ exceeds `NET_ZERO_EPS` has its Hips
## position track's X and Z key VALUES set to exactly 0.0 at every key -- Y is left untouched so a
## jump arc survives (`Y` was never part of `HeroState.velocity`, planar-only resolution).
## A clip that already net-zeros on its own (measured, not assumed) is left alone.
##
## THE GATE IS NET-ONLY, BY RULING (AC 6), NOT BY OVERSIGHT -- corrected at the 5-3 review, which
## found this header claiming the gate "matches how `roll` reads today: `peakPlanar` 0.0000, not
## merely `net` 0.0000". It does not, and it is the SENTENCE that was wrong, not the gate. Mid-clip
## excursion (peak / peakPlanar) is explicitly NOT a defect per `measure_hips_displacement.gd`'s own
## doctrine (`:14-18`); only NET travel admits or rejects a clip. Zeroing every X/Z key does
## incidentally leave `peakPlanar` at 0.0000 on the clips this DOES fire on -- which is how `roll`
## reads after `3-0b/R27` -- but that is a consequence, never the test. `thrust` is the case that
## makes the difference visible: net 0.0000 with `peakPlanar` 0.0873, correctly left untouched.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/add_paladin_attacks.gd

const SOURCE_DIR := "res://assets/characters/paladin/"
const LIBRARY_PATH := SOURCE_DIR + "paladin_anims.res"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

## Matches tools/measure_hips_displacement.gd's own constant -- the same measurement, the same
## threshold, so "exceeds NET_ZERO_EPS" means the identical thing in both places.
const NET_ZERO_EPS := 0.001

## The clip name -> loop flag matrix this story adds. test/integration/test_rig_clips.gd
## asserts the SAME matrix (for all twelve clips) against the assembled scene, independently --
## the test never imports this file.
const NEW_CLIPS := {
	"swipe": false,
	"jump_attack": false,
	"thrust": false,
}

## The nine clips assembled by 3-0a/5-0a, asserted present and untouched by this run.
const EXISTING_CLIPS: Array[StringName] = [
	&"idle", &"run", &"attack", &"block", &"roll", &"death",
	&"strafe_left", &"strafe_right", &"backpedal",
]

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"


## AC 6: zeroes the Hips position track's X and Z key values in place if the clip's net XZ
## displacement exceeds NET_ZERO_EPS. Y is never touched. No-op (with a stated reason) for a
## clip that already net-zeros on its own, or that carries no Hips position track.
func _zero_hips_planar_if_needed(anim: Animation, clip: String) -> void:
	var track := -1
	for t in anim.get_track_count():
		if anim.track_get_path(t) == NodePath(HIPS_TRACK) \
				and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			track = t
			break
	if track == -1:
		print("  '%s': no %s position track, nothing to zero" % [clip, HIPS_TRACK])
		return

	var keys := anim.track_get_key_count(track)
	if keys == 0:
		print("  '%s': empty Hips track, nothing to zero" % clip)
		return

	var first: Vector3 = anim.track_get_key_value(track, 0)
	var last: Vector3 = anim.track_get_key_value(track, keys - 1)
	var net_planar := Vector2(last.x - first.x, last.z - first.z).length()
	if net_planar <= NET_ZERO_EPS:
		print("  '%s': net XZ %.4f <= eps %.4f, left alone" % [clip, net_planar, NET_ZERO_EPS])
		return

	for k in keys:
		var v: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(0.0, v.y, 0.0))
	print("  '%s': net XZ %.4f > eps %.4f, Hips X/Z zeroed (Y kept)"
		% [clip, net_planar, NET_ZERO_EPS])


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
		_zero_hips_planar_if_needed(anim, clip)
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
