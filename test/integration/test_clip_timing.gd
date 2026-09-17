extends SceneTree

## Story 3-0b (AC 3 + AC 4) machine contract: the paladin's non-looping clips are reconciled
## to the AUTHORED tick windows, and the roll no longer slides the body out from under the
## root. Instantiates hero.tscn (not the library file directly) so what is measured is the
## clip set the hero actually PLAYS — swapping hero.tscn's AnimationLibrary reference for an
## unreconciled one has to fail here, not pass on a library nobody loads.
##
## AC3 — direction is LOCKED: animation serves gameplay timing, never the reverse. Clips are
## retimed to the window; the window is never widened to fit a clip (the sole exception is a
## separately logged playtest verdict that the WINDOW itself is wrong). This test therefore
## reads the authored windows through BalanceTicks.from_config(), the same A1 seconds->ticks
## boundary advance() uses, and is fully parametric on data/balance/balance_config.tres:
##   * attack -> attack_windup_ticks + attack_active_ticks + attack_recovery_ticks (the whole
##     span the ATTACKING state occupies; at the authored values, 15 + 9 + 21 = 45 ticks).
##   * roll   -> roll_duration_ticks (30 ticks at the authored values).
## CONSEQUENCE, stated so it is never a surprise: retuning any of those four `*_seconds`
## fields now REQUIRES retiming the matching clip in the same pass. That is the direction
## lock made executable, not an accident of this test.
##
## `death` is deliberately NOT reconciled and NOT asserted here: DEAD is terminal, no state
## window truncates it, and under the 3-0a clip-end policy it plays to its end and holds the
## final pose. There is no authored window to reconcile it against. `idle`/`run`/`block` loop,
## so they have no end to reconcile either.
##
## AC4 — the roll telegraph disc must read as UNDER the character for the whole roll. The
## measured cause was the `roll` clip's Hips PLANAR excursion (~1.09 units, 3-0a/R9 evidence
## table): the ring never moved, the mesh did. The fix zeroes the Hips X/Z while keeping Y,
## so the dive's vertical dip survives and the lateral slide does not. This pins the planar
## excursion below a threshold so a future clip swap cannot silently reintroduce the detach.
##
## Run: godot --headless --path . --script res://test/integration/test_clip_timing.gd

## Maximum peak PLANAR (XZ) Hips excursion the `roll` clip may carry, in world units.
## Rationale: the RollDisc telegraph (hero.tscn, CylinderMesh_tgdisc) has radius 0.8 and the
## hero's body box is 1x2x1, so half-width 0.5. At 0.25 the hips stay inside less than a THIRD
## of the disc's radius and less than HALF the body's own half-width — the body cannot leave
## its own footprint, let alone the disc. Delivered value is 0.0 (the track is pinned), so the
## threshold is a regression ceiling with large headroom, not a value anyone tuned up to.
const ROLL_HIPS_PLANAR_MAX := 0.25

## Clip length must land on the authored window to well under a tenth of a tick. Both targets
## (45 and 30 ticks) are exactly representable, so this is drift detection, not float slack.
const TICK_EPS := 0.05

var _failures: Array[String] = []


func _initialize() -> void:
	var cfg: BalanceConfig = load("res://data/balance/balance_config.tres")
	if cfg == null:
		_fail_out("balance_config.tres did not load")
		return
	var ticks := BalanceTicks.from_config(cfg)
	var want := {
		&"attack": ticks.attack_windup_ticks + ticks.attack_active_ticks
				+ ticks.attack_recovery_ticks,
		&"roll": ticks.roll_duration_ticks,
	}

	var ps: PackedScene = load("res://src/actors/hero/hero.tscn")
	if ps == null:
		_fail_out("hero.tscn did not load")
		return
	var hero := ps.instantiate()
	var clips := {}
	for p in hero.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			clips[n] = ap.get_animation(n)

	# AC3: every reconciled clip's length equals its authored tick window.
	for name: StringName in want:
		var a: Animation = clips.get(name)
		if a == null:
			_failures.append("clip '%s' missing from hero.tscn" % name)
			continue
		var got: float = a.length * TimingWindow.TICK_HZ
		var target: int = want[name]
		if absf(got - float(target)) > TICK_EPS:
			_failures.append(
				"clip '%s' is %.4f ticks (%.4f s) but its authored window is %d ticks (%.4f s)"
				% [name, got, a.length, target, float(target) / TimingWindow.TICK_HZ])
		print("clip %s: %.4f ticks vs authored window %d ticks" % [name, got, target])

	# AC4: the roll's Hips track carries no lateral slide.
	var roll: Animation = clips.get(&"roll")
	if roll == null:
		_failures.append("clip 'roll' missing from hero.tscn")
	else:
		var track := -1
		for t in roll.get_track_count():
			if roll.track_get_type(t) == Animation.TYPE_POSITION_3D \
					and String(roll.track_get_path(t)).ends_with("mixamorig_Hips"):
				track = t
		if track < 0:
			_failures.append("clip 'roll' has no mixamorig_Hips position track to measure")
		else:
			var first: Vector3 = roll.track_get_key_value(track, 0)
			var peak_xz := 0.0
			var peak_y := 0.0
			for k in roll.track_get_key_count(track):
				var d: Vector3 = roll.track_get_key_value(track, k) - first
				peak_xz = maxf(peak_xz, Vector2(d.x, d.z).length())
				peak_y = maxf(peak_y, absf(d.y))
			if peak_xz > ROLL_HIPS_PLANAR_MAX:
				_failures.append(
					"roll Hips planar excursion %.4f exceeds %.4f — the body slides out from"
					% [peak_xz, ROLL_HIPS_PLANAR_MAX]
					+ " under the RollDisc telegraph")
			# The vertical dip is what MAKES it read as a roll; a fix that flattened Y too
			# would leave a hero sliding upright, so guard against over-correction.
			if peak_y <= 0.0:
				_failures.append("roll Hips vertical dip was flattened (peakY %.4f)" % peak_y)
			print("roll Hips excursion: planar %.4f (max %.4f), vertical %.4f" % [
				peak_xz, ROLL_HIPS_PLANAR_MAX, peak_y])

	# Story 6-6a (asset prerequisite): the `knockdown` clip takes the roll's fix (Hips X/Z pinned, Y kept
	# -- `tools/add_paladin_defense_reactions.gd`), because its source fell 0.55 planar backward and
	# ended 0.63 from where `get_up` starts: the body would slide out from over the rooted capsule while
	# down and POP on the get-up cut. Pinned under the SAME ceiling for the same geometric reason, and
	# the fall's vertical drop is guarded against over-correction exactly as the roll's dip is.
	var knockdown: Animation = clips.get(&"knockdown")
	if knockdown == null:
		_failures.append("clip 'knockdown' missing from hero.tscn")
	else:
		var kd_track := -1
		for t in knockdown.get_track_count():
			if knockdown.track_get_type(t) == Animation.TYPE_POSITION_3D \
					and String(knockdown.track_get_path(t)).ends_with("mixamorig_Hips"):
				kd_track = t
		if kd_track < 0:
			_failures.append("clip 'knockdown' has no mixamorig_Hips position track to measure")
		else:
			var kd_first: Vector3 = knockdown.track_get_key_value(kd_track, 0)
			var kd_peak_xz := 0.0
			var kd_peak_y := 0.0
			for k in knockdown.track_get_key_count(kd_track):
				var d: Vector3 = knockdown.track_get_key_value(kd_track, k) - kd_first
				kd_peak_xz = maxf(kd_peak_xz, Vector2(d.x, d.z).length())
				kd_peak_y = maxf(kd_peak_y, absf(d.y))
			if kd_peak_xz > ROLL_HIPS_PLANAR_MAX:
				_failures.append(
					"knockdown Hips planar excursion %.4f exceeds %.4f -- the downed body slides off its capsule"
					% [kd_peak_xz, ROLL_HIPS_PLANAR_MAX])
			if kd_peak_y <= 0.0:
				_failures.append("knockdown Hips vertical drop was flattened (peakY %.4f)" % kd_peak_y)
			print("knockdown Hips excursion: planar %.4f (max %.4f), vertical %.4f" % [
				kd_peak_xz, ROLL_HIPS_PLANAR_MAX, kd_peak_y])

	# The Animation resources stay alive in `clips` (RefCounted), so the scene can go.
	hero.free()

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _fail_out(msg: String) -> void:
	print("  FAILED: " + msg)
	print("RESULT: FAIL")
	quit(1)
