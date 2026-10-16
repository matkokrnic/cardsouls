extends SceneTree

## Story 7-5b (AC 9; SIX since smoke fix 1, S6; TEN since smoke fix 2, S15): assembles the Healer's clips into the single AnimationLibrary
## `assets/characters/healer/healer_anims.res` that healer_actor.tscn's AnimationPlayer plays --
## `tools/build_zombie_anims.gd`'s counterpart on the same multi-file Mixamo layout, HEADLESS for its
## recorded reason (every editor session is a measured hazard; the library is a FUNCTION of the five clip
## FBXs and re-running this reproduces it).
##
## Each clip FBX imports as a scene holding one AnimationPlayer with one take, the Mixamo default
## `mixamo_com` (measured, `tools/measure_healer_rig.gd` table 2). This lifts that take out, RENAMES it to the
## clip name `HealerAnimationController` selects by, and sets the loop flag: idle and walk loop, cast, shoot
## and death are one-shot. The model's own bundled take never reaches this library: it is stripped at import
## by `assets/characters/healer/strip_model_anim.gd`.
##
## CONDITIONAL PLANAR ZEROING (`3-0b/R27`, `tools/add_paladin_attacks.gd`'s net-gated route): a clip whose
## Hips position track carries a NET X/Z displacement above `NET_ZERO_EPS` has every Hips key's X and Z set to
## 0.0, Y kept. MEASURED (story 7-5b T1): only `death` qualifies, a 1.576 m forward topple that holds -- zeroed,
## the body falls where its actor stands, so the corpse lies over its root. The other four net-zero and are
## left exactly as imported.
##
## Track paths are left exactly as imported (`Skeleton3D:mixamorig_Hips`, ...), which is why the scene's
## AnimationPlayer sets `root_node = NodePath("..")`, the model instance.
##
## SMOKE FIX 2 (S15): SIX -> TEN. `turn_left` / `turn_right` (Mixamo "Standing Turn Left 90" / "Standing Turn
## Right 90") and `strafe_left` / `strafe_right` ("Standing Walk Left" / "Standing Walk Right"), all on the Knight D
## Pelegrini rig (measured: 66 bones, Hips rest 1.1872, the model's own). MEASURED (`tools/measure_healer_rig.gd`
## tables 2, 8, 9): the strafes are NOT in place -- Hips net X +1.7496 / -1.8613 -- and the turns drift 0.0304 /
## 0.0305, so the net-gated route above zeroes all four's X/Z. The TURNS also have their Hips YAW NEUTRALISED
## (`tools/add_paladin_locomotion.gd`'s `6-7b` route, ported below): each turns the body 90 degrees by itself
## (net +90.00 / -90.15), and the runner's own yaw already turns the actor -- left in, the body would turn twice
## and snap back at the clip's end.
const YAW_NEUTRALISED_CLIPS: Array[String] = ["turn_left", "turn_right"]
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/build_healer_anims.gd

const SOURCE_DIR := "res://assets/characters/healer/"
const LIBRARY_PATH := SOURCE_DIR + "healer_anims.res"

## The clip name -> loop flag matrix and the single source of truth this tool builds from.
## test/integration/test_healer_rig_clips.gd asserts the same names and flags against the assembled scene,
## independently -- the test never imports this file.
const CLIPS := {
	"idle": true,
	"walk": true,
	"cast": false,
	"shoot": false,
	"death": false,
	# Smoke fix 1 (S6): the sixth clip, Mixamo "Standing React Small From Left", one-shot. MEASURED in place
	# (`tools/measure_healer_rig.gd` table 2: Hips net 0.0000, peak planar 0.0793), so it is left as imported.
	"hurt": false,
	# Smoke fix 2 (S15): a turn plays ONCE per re-aim, rate-fitted to it; a strafe loops like `walk`.
	"turn_left": false,
	"turn_right": false,
	"strafe_left": true,
	"strafe_right": true,
}

## The take name Mixamo bakes into every downloaded FBX (Godot sanitizes the dot).
const SOURCE_TAKE := &"mixamo_com"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
## `tools/measure_hips_displacement.gd`'s threshold, so "net-zero" means the same thing everywhere.
const NET_ZERO_EPS := 0.001


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
			push_error("%s.fbx: expected exactly 1 AnimationPlayer, found %d" % [clip, players.size()])
			root.free()
			quit(1)
			return
		var player := players[0] as AnimationPlayer
		if not player.has_animation(SOURCE_TAKE):
			push_error("%s.fbx: no '%s' take (found %s)" % [clip, SOURCE_TAKE, player.get_animation_list()])
			root.free()
			quit(1)
			return
		# Duplicated, not referenced: the source scene is freed below.
		var anim: Animation = player.get_animation(SOURCE_TAKE).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip] else Animation.LOOP_NONE
		_zero_hips_planar_if_needed(anim, clip)
		if YAW_NEUTRALISED_CLIPS.has(clip) and not _neutralise_hips_yaw(anim, clip):
			root.free()
			quit(1)
			return
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


## Zero the Hips position track's X and Z at every key when the clip's NET planar displacement exceeds
## `NET_ZERO_EPS`; Y is never touched. A clip that already net-zeros is left alone, with the reason printed.
func _zero_hips_planar_if_needed(anim: Animation, clip: String) -> void:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	if track < 0 or anim.track_get_key_count(track) == 0:
		print("  '%s': no %s position keys, nothing to zero" % [clip, HIPS_TRACK])
		return
	var keys := anim.track_get_key_count(track)
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var last: Vector3 = anim.track_get_key_value(track, keys - 1)
	var net_planar := Vector2(last.x - first.x, last.z - first.z).length()
	if net_planar <= NET_ZERO_EPS:
		print("  '%s': net XZ %.4f <= eps %.4f, left alone" % [clip, net_planar, NET_ZERO_EPS])
		return
	for k in keys:
		var v: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(0.0, v.y, 0.0))
	print("  '%s': net XZ %.4f > eps %.4f, Hips X/Z zeroed (Y kept)" % [clip, net_planar, NET_ZERO_EPS])


## Smoke fix 2 (S15): `tools/add_paladin_locomotion.gd`'s `_neutralise_hips_yaw`, verbatim in method -- every Hips
## rotation key keeps its SWING (sway, tilt) bit for bit and takes the FIRST key's TWIST about the up axis, so the
## clip's net and mid-clip yaw are zero and the body holds the idle stance's own orientation. Refuses (false) a
## clip with no Hips rotation track rather than ship a double-rotating turn.
func _neutralise_hips_yaw(anim: Animation, clip: String) -> bool:
	var track := anim.find_track(NodePath(HIPS_TRACK), Animation.TYPE_ROTATION_3D)
	if track < 0 or anim.track_get_key_count(track) == 0:
		push_error("%s: no %s rotation track to neutralise -- refusing to write" % [clip, HIPS_TRACK])
		return false
	var keys := anim.track_get_key_count(track)
	var twist_0 := _twist_about_up(anim.track_get_key_value(track, 0))
	for k in keys:
		var q: Quaternion = anim.track_get_key_value(track, k)
		var swing := _twist_about_up(q).inverse() * q
		anim.track_set_key_value(track, k, (twist_0 * swing).normalized())
	print("  '%s': Hips yaw neutralised (%d rotation keys)" % [clip, keys])
	return true


## The twist of `q` about +Y (the FBX Hips is a root bone, so its rotation is in skeleton space, whose up is +Y).
static func _twist_about_up(q: Quaternion) -> Quaternion:
	var twist := Quaternion(0.0, q.y, 0.0, q.w)
	if twist.length_squared() < 1e-12:
		return Quaternion.IDENTITY
	return twist.normalized()
