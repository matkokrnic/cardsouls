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


## Story 7-8: through `charge_playhead_for`, the one place a colour's knobs (GREEN's crouch-lead knee
## included) are applied -- the call the controller itself seeks with.
func _playhead(clip: String, progress: float) -> float:
	return AnimationController.charge_playhead_for(int(_CLIPS[clip]["color"]), progress)


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
## `hold_end` -- i.e. the swing starts when the chargeup window closes and the attack launches,
## instead of being part spent by then. Asserted per clip against its own knob, never against a
## pinned number.
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


# --- Story 7-8 (AC 13/AC 14/AC 15): the Genichiro re-tempo -------------------------------------------

const CONFIG_PATH := "res://data/balance/balance_config.tres"
## AC 14's bound, FIXED BEFORE THE KNOBS WERE MEASURED (recorded in the story's Dev Agent Record): GREEN
## covers at least this share of its launch travel before the mapped apex. Below the ~2/3 target
## (`7-8/R5`) so the knob keeps tuning room.
const GREEN_TRAVEL_BEFORE_APEX_MIN := 0.60


## AC 13 [M]: WITH THE SWING-AT-COMMIT REMAP, THE DANGEROUS SWEEP STARTS AT OR AFTER THE COMMIT. For every
## colour and a spread of commit fractions: on every progress at or before the commit the mapped playhead
## is at most the held pose (wind-up and hold only -- nothing has swung yet), and after it the playhead
## climbs past the held pose to the strike frame. Pure mapping, no authored value read.
func test_with_swing_at_commit_the_sweep_starts_at_or_after_the_commit() -> void:
	for clip: String in _CLIPS:
		var color: int = _CLIPS[clip]["color"]
		var knobs: Dictionary = AnimationController._CHARGE_HOLD_KNOBS[color]
		var hold_playhead: float = float(_CLIPS[clip]["strike_frame"]) * float(knobs["hold_fraction"])
		var hold_end := AnimationController.charge_hold_end_for(color)
		for commit_fraction: float in [0.5, 0.69, 0.77, 0.9]:
			var steps := 60
			var after_commit_max := 0.0
			for i in steps + 1:
				var p := float(i) / float(steps)
				var playhead := AnimationController.charge_playhead_for(color,
					AnimationController.charge_commit_anchored_progress(p, commit_fraction, hold_end))
				if p <= commit_fraction:
					assert_true(playhead <= hold_playhead + 0.0001,
						"%s, commit %.2f: at progress %.3f (before the commit) the playhead %.4f is past "
							% [clip, commit_fraction, p, playhead]
							+ "the held pose %.4f -- the sweep started before the commit (AC 13)" % hold_playhead)
				else:
					after_commit_max = maxf(after_commit_max, playhead)
			assert_true(after_commit_max > hold_playhead,
				"%s, commit %.2f: the sweep never left the held pose after the commit" % [clip, commit_fraction])


## AC 14 [M]: GREEN RISES THROUGH MOST OF ITS TRAVEL. Over the SHIPPED spans and knobs (the authored
## chargeup and GREEN launch, composed exactly as `match_runner._push_charge_progress` composes them,
## remap included when the authored knob is on), the launch travel delivered on the ticks whose mapped
## playhead has not yet passed the clip's apex is at least `GREEN_TRAVEL_BEFORE_APEX_MIN` of the total.
## The per-tick shares are `MatchState._charge_launch_velocity`'s ramp, transcribed (the
## `test_unblockable_tracking_and_reach.gd` `_launch_velocity` precedent): share(i) = 2 - (2i + 1) / L.
##
## Reads the authored spans because the claim is about the SHIPPED GREEN profile; it pins a BOUND, never
## a knob value, so a retune inside the bound needs no suite edit (BC/R3, `7-8/R7`).
func test_green_covers_most_of_its_launch_travel_before_the_apex() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads")
	if config == null:
		return
	var ticks := BalanceTicks.from_config(config)
	var c := ticks.unblockable_chargeup_ticks
	var l := ticks.unblockable_launch_ticks_for(Enums.CardColor.GREEN)
	assert_true(c > 0 and l > 1, "sanity: an authored chargeup and a multi-tick GREEN launch (%d, %d)" % [c, l])
	var hold_end := AnimationController.charge_hold_end_for(Enums.CardColor.GREEN)
	var before_apex := 0.0
	var total := 0.0
	for i in l:
		var share := 2.0 - float(2 * i + 1) / float(l)
		total += share
		# Launch index i is pushed with L - i ticks left on the landing window (index 0 is the commit).
		var progress := AnimationController.charge_attack_progress(l - i, c, l)
		if config.unblockable_swing_at_commit:
			progress = AnimationController.charge_commit_anchored_progress(progress,
					float(c) / float(c + l), hold_end)
		var playhead := AnimationController.charge_playhead_for(Enums.CardColor.GREEN, progress)
		if playhead <= AnimationController.JUMP_ATTACK_APEX_SECONDS + 0.0001:
			before_apex += share
	var fraction := before_apex / total
	print("  GREEN launch travel before the mapped apex: %.4f (bound %.2f, C=%d L=%d)"
		% [fraction, GREEN_TRAVEL_BEFORE_APEX_MIN, c, l])
	assert_true(fraction >= GREEN_TRAVEL_BEFORE_APEX_MIN,
		"GREEN covers only %.3f of its launch travel before the apex, bound %.2f (AC 14, `7-8/R5`)"
			% [fraction, GREEN_TRAVEL_BEFORE_APEX_MIN])


## AC 14, the crouch half's structural pre-condition: GREEN's HELD pose is BEFORE take-off (at or before
## the measured crouch), never airborne -- the 6-1b hold sat on the apex. A direction, not a value.
func test_greens_held_pose_is_grounded_before_take_off() -> void:
	var knobs: Dictionary = AnimationController._CHARGE_HOLD_KNOBS[Enums.CardColor.GREEN]
	var held := AnimationController.JUMP_ATTACK_STRIKE_FRAME_SECONDS * float(knobs["hold_fraction"])
	assert_true(held <= AnimationController.JUMP_ATTACK_CROUCH_SECONDS + 0.01,
		"GREEN holds at %.4f s, after the measured crouch %.4f s -- it would hold mid-air (`7-8/R5`)"
			% [held, AnimationController.JUMP_ATTACK_CROUCH_SECONDS])


## AC 15 (the optional structural half): the two cross-faded edges blend for MORE THAN 0 s.
func test_the_two_cross_faded_charge_edges_blend() -> void:
	assert_true(AnimationController.CHARGE_ENTRY_BLEND_SECONDS > 0.0,
		"the charge-up's entry edge must cross-fade (`7-8/R6`)")
	assert_true(AnimationController.CHARGE_EXIT_BLEND_SECONDS > 0.0,
		"the attack's recovery edge must cross-fade (`7-8/R6`)")
