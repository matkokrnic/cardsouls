extends SceneTree

## Rescales the paladin's governed non-looping clips (`attack`, `roll`) so each clip's
## length matches its authored tick window. Windows are computed via
## BalanceTicks.from_config() from data/balance/balance_config.tres — the same
## seconds->ticks boundary test/integration/test_clip_timing.gd asserts against
## (story 3-0b, AC3): animation serves gameplay timing, never the reverse.
##
## REQUIRED COMPANION: any retune of attack_windup_seconds, attack_active_seconds,
## attack_recovery_seconds, or roll_duration_seconds must re-run this tool in the same
## pass, then re-run test_clip_timing.gd to confirm the clip and the window agree again.
## That coupling is the AC3 direction lock made executable, not an accident of this tool.
##
## Transform: every key on every track of a governed clip is time-scaled by the same
## factor (target_seconds / current_seconds), and the Animation's `length` is set to the
## target duration. This is a UNIFORM rescale — it preserves the clip's internal
## proportions but does not reshape individual phases. A piecewise per-phase retime is a
## different, finer instrument (named as an open Pass 4 input for the attack clip's
## impact-alignment question in docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md).
##
## Deliberately excluded: `death` (DEAD is terminal, no window governs it) and the
## looping clips `idle`/`run`/`block` (no end to reconcile). The roll clip's Hips-track
## planar fix (AC4) is a separate, one-time edit and is NOT part of this transform — this
## tool only retimes, it never touches position/rotation VALUES.
##
## No-op by construction when a governed clip is already within TICK_EPS of its authored
## window (matching test_clip_timing.gd's own epsilon) — running it against an already-
## reconciled library changes nothing and does not touch the file on disk.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/retime_clips.gd

const LIBRARY_PATH := "res://assets/characters/paladin/paladin_anims.res"
const GOVERNED_CLIPS: Array[StringName] = [&"attack", &"roll"]

## Matches test_clip_timing.gd's TICK_EPS: drift detection, not float slack.
const TICK_EPS := 0.05


func _initialize() -> void:
	var cfg: BalanceConfig = load("res://data/balance/balance_config.tres")
	if cfg == null:
		push_error("balance_config.tres did not load")
		quit(1)
		return
	var ticks := BalanceTicks.from_config(cfg)
	var want_ticks := {
		&"attack": ticks.attack_windup_ticks + ticks.attack_active_ticks
				+ ticks.attack_recovery_ticks,
		&"roll": ticks.roll_duration_ticks,
	}

	var lib: AnimationLibrary = load(LIBRARY_PATH)
	if lib == null:
		push_error("%s did not load" % LIBRARY_PATH)
		quit(1)
		return

	var changed := false
	for clip_name: StringName in GOVERNED_CLIPS:
		if not lib.has_animation(clip_name):
			push_error("clip '%s' missing from %s" % [clip_name, LIBRARY_PATH])
			quit(1)
			return
		var anim: Animation = lib.get_animation(clip_name)
		var target_ticks: int = want_ticks[clip_name]
		var target_seconds: float = float(target_ticks) / TimingWindow.TICK_HZ
		var current_ticks: float = anim.length * TimingWindow.TICK_HZ

		if absf(current_ticks - float(target_ticks)) <= TICK_EPS:
			print("clip '%s': already %d ticks (authored window) — no-op" % [
				clip_name, target_ticks])
			continue

		var factor: float = target_seconds / anim.length
		for t in anim.get_track_count():
			_rescale_track(anim, t, factor)
		anim.length = target_seconds
		changed = true
		print("clip '%s': %.4f -> %.4f ticks (factor %.6f)" % [
			clip_name, current_ticks, float(target_ticks), factor])

	if not changed:
		print("no clips changed — library already reconciled, file not touched")
		quit(0)
		return

	var err := ResourceSaver.save(lib, LIBRARY_PATH)
	if err != OK:
		push_error("failed to save %s: error %d" % [LIBRARY_PATH, err])
		quit(1)
		return
	print("saved %s" % LIBRARY_PATH)
	quit(0)


## Scales every key's time on one track by `factor`, in an order that never leaves the
## key array transiently out of time-order (Animation keeps keys time-sorted): expanding
## (factor >= 1) must proceed from the last key backward, contracting (factor < 1) from
## the first key forward. Either direction alone would risk a mid-loop key reorder
## corrupting later indices in this same pass.
func _rescale_track(anim: Animation, track: int, factor: float) -> void:
	var key_count := anim.track_get_key_count(track)
	var indices := range(key_count)
	if factor >= 1.0:
		indices.reverse()
	for k in indices:
		var time: float = anim.track_get_key_time(track, k)
		anim.track_set_key_time(track, k, time * factor)
