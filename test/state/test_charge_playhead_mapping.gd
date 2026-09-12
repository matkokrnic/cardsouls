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


# --- Story 6-1d (AC 8): the SWING-AT-COMMIT remap -----------------------------------------------

## AC 8's shape claim: the remap is a REPARAMETRISATION, so both endpoints are fixed. If either
## moved, the clip would start part-played or stop short of the strike frame, and every `6-1c` AC 11
## guarantee riding on `charge_playhead_seconds` would have to be re-proven rather than inherited.
func test_the_commit_anchored_remap_fixes_both_endpoints() -> void:
	for clip: String in _CLIPS:
		var color: int = _CLIPS[clip]["color"]
		var hold_end := AnimationController.charge_hold_end_for(color)
		assert_true(hold_end > 0.0 and hold_end < 1.0,
			"%s: sanity -- the clip has an authored hold_end inside (0, 1), got %.3f"
				% [clip, hold_end])
		assert_eq(AnimationController.charge_commit_anchored_progress(0.0, 0.6, hold_end), 0.0,
			"%s: progress 0 still maps to 0" % clip)
		assert_eq(AnimationController.charge_commit_anchored_progress(1.0, 0.6, hold_end), 1.0,
			"%s: progress 1 still maps to 1" % clip)


## AC 8's behavioural claim, and the reason the knob exists: the COMMIT lands exactly on the clip's
## `hold_end` -- i.e. the swing starts when the attack becomes unfeintable, instead of being part
## spent by then. Asserted per clip against its own knob, never against a pinned number.
##
## MUTATION: return the input unchanged (an identity remap) and this goes RED for every clip whose
## commit fraction differs from its hold_end, which is all three.
func test_the_commit_fraction_maps_onto_the_clips_hold_end() -> void:
	for clip: String in _CLIPS:
		var color: int = _CLIPS[clip]["color"]
		var hold_end := AnimationController.charge_hold_end_for(color)
		for commit_fraction: float in [0.25, 0.5, 0.8]:
			var got := AnimationController.charge_commit_anchored_progress(
				commit_fraction, commit_fraction, hold_end)
			assert_true(absf(got - hold_end) < 0.0001,
				"%s: the commit (linear progress %.2f) must map to hold_end %.3f, got %.4f"
					% [clip, commit_fraction, hold_end, got])
			assert_true(absf(commit_fraction - hold_end) < 0.0001
					or absf(got - commit_fraction) > 0.0001,
				"%s: at commit fraction %.2f the remap must BEND the progress, not pass it through"
					% [clip, commit_fraction])


## The remap must be monotonic for the same reason the mapping it feeds is: a playhead that moved
## backwards would read as a glitch. Swept across the whole domain, per clip.
func test_the_commit_anchored_remap_is_monotonic() -> void:
	for clip: String in _CLIPS:
		var hold_end := AnimationController.charge_hold_end_for(_CLIPS[clip]["color"])
		var previous := -1.0
		var steps := 40
		for i in steps + 1:
			var out := AnimationController.charge_commit_anchored_progress(
				float(i) / float(steps), 0.65, hold_end)
			assert_true(out >= previous - 0.0001,
				"%s: the remap moved backwards at %.3f (%.4f -> %.4f)"
					% [clip, float(i) / float(steps), previous, out])
			previous = out


## A degenerate commit fraction or hold_end has no second phase to stretch into -- the input passes
## through rather than dividing by zero. This is what makes an unauthored colour safe under the knob.
func test_a_degenerate_span_passes_the_progress_through() -> void:
	for bad: Array in [[0.0, 0.5], [1.0, 0.5], [0.6, 0.0], [0.6, 1.0], [-0.2, 0.5], [0.6, 1.4]]:
		for p: float in [0.0, 0.3, 0.75, 1.0]:
			assert_eq(AnimationController.charge_commit_anchored_progress(p, bad[0], bad[1]), p,
				"commit fraction %.2f / hold_end %.2f: progress %.2f passes through" % [bad[0], bad[1], p])
