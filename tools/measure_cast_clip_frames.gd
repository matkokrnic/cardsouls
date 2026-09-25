extends SceneTree

## Story 6-5c (AC 25, Dev Notes mechanism 3): measures the `cast` clip's RAISE FRAME -- the moment
## the hero's sword reaches its highest point, which is the beat the bolt must visibly leave the
## sword on -- and the `dizzy` clip's LENGTH against the authored bolt-stun window (Open Question 8,
## left OPEN to the dev pass by design).
##
## `tools/measure_counter_strike_frames.gd`'s OWN METHOD, re-pointed rather than duplicated by hand:
## HEADLESS (`3-0a/R3` -- the editor is the one tool this project will not open), forward-kinematics
## bone composition (`get_bone_pose()`, never `get_bone_global_pose()` -- see
## `measure_strike_frame.gd`'s header for the measured reason it is not cached), and a printed table
## a human reads the criterion off rather than a single number the tool asserts.
##
## THE PROBE IS THE SWORD JOINT, not the hand, and that differs from the counter tool on purpose.
## The counter clips carry no weapon beat (a jump, a backflip, a slide, a throw), so the hand was the
## honest probe there. "Sword And Shield Casting" is a SWORD RAISE, and `mixamorig_Sword_joint` is
## the joint whose height IS the beat -- the same probe `measure_charge_strike_frames.gd` uses for
## the three blade swings. The hand is printed beside it so a raise driven by the arm rather than the
## wrist can be told apart rather than assumed.
##
## THE CRITERION IS THE PEAK SWORD HEIGHT ABOVE THE HIPS, and it is stated here BEFORE the numbers
## are read (the adversarial-review rule: a pass states what counts as success before it starts).
## Height is taken relative to the Hips rather than in model space so a clip that bobs vertically
## cannot masquerade as a raise.
##
## WHAT THE NUMBERS ARE FOR. The raise fraction feeds presentation as a CONSTANT -- the cast clip is
## time-scaled from the runner-fed authored duration, so the bolt's launch beat lands at
## `raise_fraction * cast_seconds` whatever the `.tres` says, with no code edit on a retune (the
## `4-3d` strike-alignment principle). Nothing here is baked into the library.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/measure_cast_clip_frames.gd

const MODEL_PATH := "res://assets/characters/paladin/paladin.fbx"
const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const CLIPS: Array[StringName] = [&"cast", &"dizzy"]
const HIPS := "mixamorig_Hips"
const SWORD_BONE := "mixamorig_Sword_joint"
const HAND_BONE := "mixamorig_RightHand"

## The authored windows these two clips are played over, for the fit report. Read from the authored
## effect rather than hard-coded, so a retune re-reports rather than silently lying.
const EFFECT_PATH := "res://data/effects/honed_bolt.tres"

var _skel: Skeleton3D


## Composes bone-local poses up the parent chain -- `get_bone_pose()` is the animated transform
## relative to the parent bone, read straight off the pose array with no cache, so it reflects the
## most recent `seek()` on every call (measure_strike_frame.gd's own finding, verbatim).
func _bone_fk(idx: int) -> Transform3D:
	var t := _skel.get_bone_pose(idx)
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		t = _skel.get_bone_pose(p) * t
		p = _skel.get_bone_parent(p)
	return t


func _initialize() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	var model := scene.instantiate()
	root.add_child(model)

	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.size() != 1:
		push_error("expected exactly 1 Skeleton3D, found %d" % skels.size())
		quit(1)
		return
	_skel = skels[0] as Skeleton3D

	var library: AnimationLibrary = load(LIBRARY_PATH)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library)

	var hips_idx := _skel.find_bone(HIPS)
	var sword_idx := _skel.find_bone(SWORD_BONE)
	var hand_idx := _skel.find_bone(HAND_BONE)
	if hips_idx < 0 or sword_idx < 0 or hand_idx < 0:
		push_error("rig missing %s, %s or %s" % [HIPS, SWORD_BONE, HAND_BONE])
		quit(1)
		return

	var effect: CardEffect = load(EFFECT_PATH)
	var cast_seconds := effect.cast_seconds if effect != null else 0.0
	var stun_seconds := effect.stun_seconds if effect != null else 0.0

	for clip: StringName in CLIPS:
		var anim: Animation = library.get_animation(clip)
		if anim == null:
			push_error("library has no clip %s" % clip)
			continue
		print("---- clip=%s length=%.4f tracks=%d" % [clip, anim.length, anim.get_track_count()])
		player.play(clip)
		var steps := 80
		var dt := anim.length / float(steps)
		print("t\tfrac\thipsY\tswordY_rel\thandY_rel")
		var max_sword := -INF
		var max_sword_t := 0.0
		for i in steps + 1:
			var t: float = minf(float(i) * dt, anim.length)
			player.seek(t, true)
			var hips := _bone_fk(hips_idx).origin
			var sword := _bone_fk(sword_idx).origin
			var hand := _bone_fk(hand_idx).origin
			var sword_rel := sword.y - hips.y
			if sword_rel > max_sword:
				max_sword = sword_rel
				max_sword_t = t
			print("%.4f\t%.4f\t%.4f\t%.4f\t%.4f"
				% [t, t / anim.length, hips.y, sword_rel, hand.y - hips.y])
		print("clip=%s RAISE (peak sword above hips) = %.4f m at t=%.4f (fraction %.4f)"
			% [clip, max_sword, max_sword_t, max_sword_t / anim.length])

	print("---- fit against the authored windows ----")
	var cast_anim: Animation = library.get_animation(&"cast")
	var dizzy_anim: Animation = library.get_animation(&"dizzy")
	if cast_anim != null and cast_seconds > 0.0:
		print("cast: clip %.4f s over authored %.4f s -> hold speed %.4f x"
			% [cast_anim.length, cast_seconds, cast_anim.length / cast_seconds])
	if dizzy_anim != null and stun_seconds > 0.0:
		print("dizzy: clip %.4f s over authored %.4f s -> hold speed %.4f x"
			% [dizzy_anim.length, stun_seconds, dizzy_anim.length / stun_seconds])
		print("  (Open Question 8: a speed-up this large reads badly; a SUB-RANGE cut at native "
			+ "rate is presentation's alternative, and the table above is what a cut is chosen from)")
	quit(0)
