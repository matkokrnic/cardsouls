extends TestCase

## Story 6-1b (AC 11): THE PLAYHEAD-COMPOSITION PIN, pure-function half. `6-1/R15` shipped
## because nothing checked the LATE end of the chargeup window against the clip's own state — the
## `3-0b/R34` blindness class: the suite is blind to the RUNTIME composition of a clip and its
## governing window unless a test reads BOTH together. `AnimationController.charge_playhead_seconds`
## is a pure function of progress (no scene, no `AnimationPlayer`), so both endpoints are asserted
## directly here for all three charge clips — the live half (a real `AnimationPlayer` tracking it
## through a real `CHARGING` session) lives in `test/integration/test_charge_playhead_live.gd`.
##
## FIX PASS: the mapping's hold knobs are now per-clip operator feel knobs (tuned at live smoke),
## so this file reads them from `AnimationController._CHARGE_HOLD_KNOBS` rather than pinning any
## value of its own — the two-endpoint + monotonicity shape is pinned per clip, never a knob
## value, so operator tuning never requires a suite run.

const _CLIPS := {
	"swipe": {"color": Enums.CardColor.RED, "strike_frame": AnimationController.SWIPE_STRIKE_FRAME_SECONDS},
	"thrust": {"color": Enums.CardColor.BLUE, "strike_frame": AnimationController.THRUST_STRIKE_FRAME_SECONDS},
	"jump_attack": {"color": Enums.CardColor.GREEN, "strike_frame": AnimationController.JUMP_ATTACK_STRIKE_FRAME_SECONDS},
}


func _playhead(clip: String, progress: float) -> float:
	var entry: Dictionary = _CLIPS[clip]
	var strike_frame: float = entry["strike_frame"]
	var knobs: Dictionary = AnimationController._CHARGE_HOLD_KNOBS[entry["color"]]
	return AnimationController.charge_playhead_seconds(
		progress, strike_frame, knobs["hold_start"], knobs["hold_end"], knobs["hold_fraction"])


func test_progress_zero_maps_to_the_clip_start_for_every_charge_clip() -> void:
	for clip: String in _CLIPS:
		var got := _playhead(clip, 0.0)
		assert_true(absf(got) < 0.0001,
			"%s: progress 0.0 must map to playhead ~0.0, got %.4f" % [clip, got])


func test_progress_one_maps_to_the_measured_strike_frame_for_every_charge_clip() -> void:
	for clip: String in _CLIPS:
		var strike_frame: float = _CLIPS[clip]["strike_frame"]
		var got := _playhead(clip, 1.0)
		assert_true(is_equal_approx(got, strike_frame),
			("%s: progress 1.0 must map to the measured strike frame %.4f, got %.4f — the "
			+ "follow-through is not scheduled inside the window (AC 2)") % [clip, strike_frame, got])


## The mapping must never overshoot the strike frame (AC 2: the follow-through is NOT scheduled
## inside the window) and never move backwards as progress advances — either would read as a
## glitch rather than a held beat.
func test_the_mapping_is_monotonic_and_never_overshoots_the_strike_frame() -> void:
	for clip: String in _CLIPS:
		var strike_frame: float = _CLIPS[clip]["strike_frame"]
		var previous := -1.0
		var steps := 20
		for i in steps + 1:
			var progress := float(i) / float(steps)
			var playhead := _playhead(clip, progress)
			assert_true(playhead >= previous - 0.0001,
				"%s: playhead moved backwards at progress %.2f (%.4f -> %.4f)"
					% [clip, progress, previous, playhead])
			assert_true(playhead <= strike_frame + 0.0001,
				"%s: playhead %.4f overshot the strike frame %.4f at progress %.2f"
					% [clip, playhead, strike_frame, progress])
			previous = playhead
