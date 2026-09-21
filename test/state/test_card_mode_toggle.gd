extends TestCase

## Story 6-10: the pad's card-mode TOGGLE scheme (`GamepadProfile.card_mode_toggle`). NON-GOLDEN: nothing
## here touches src/state/ or the determinism sequence. Joypad reads are not headless-samplable, so the
## decision is proven through the pure `resolve_cast_mode` / `resolve_armed_after_commit` and through the
## controller's memory step `_advance_cast_mode` / `force_card_mode_off` / the neutral path of `sample()`
## on a controller with no device bound. The existing `resolve_card_tick` is called, never changed.
##
## Every loop here is bounded by a literal.

const _CONFIRM_BASIC := 0
const _CONFIRM_UNBLOCKABLE := 1
const _CONFIRM_DEFENSE := 2
const _CONFIRM_PITCH := 3


func _profile(toggle: bool) -> GamepadProfile:
	var p := GamepadProfile.new()
	p.card_mode_toggle = toggle
	return p


## `resolve_card_tick` with `confirm` (-1 = none) FRESHLY pressed and every other input at rest.
func _tick(cast_held: bool, confirm: int, armed: int) -> Dictionary:
	return GamepadController.resolve_card_tick(cast_held,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		confirm == _CONFIRM_BASIC, false,
		confirm == _CONFIRM_UNBLOCKABLE, false,
		confirm == _CONFIRM_DEFENSE, false,
		confirm == _CONFIRM_PITCH, false,
		0.5, armed)


# ---- AC 1 / AC 2: the profile field ----

func test_card_mode_toggle_defaults_false_and_is_a_bool_not_a_button() -> void:  # AC 1, AC 2
	var p := GamepadProfile.new()
	assert_false(p.card_mode_toggle, "the script default is HOLD")
	assert_eq(typeof(p.card_mode_toggle), TYPE_BOOL, "a plain bool, not a JoyButton index")


func test_shipped_profile_tres_holds_by_default_with_no_authored_line() -> void:  # AC 1
	var profile: GamepadProfile = load("res://data/gamepad_profile.tres")
	assert_false(profile.card_mode_toggle, "the shipped profile loads as HOLD")
	var text := FileAccess.get_file_as_string("res://data/gamepad_profile.tres")
	assert_false(text.contains("card_mode_toggle"),
		"the shipped .tres carries NO card_mode_toggle line: the default holds from the script (the "
		+ "operator's one-line flip is the smoke step)")


func test_one_authored_line_flips_the_switch() -> void:  # AC 1 (the .tres flip)
	var path := "user://_610_flip.tres"
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "temp .tres opens")
	f.store_string("[gd_resource type=\"Resource\" script_class=\"GamepadProfile\" load_steps=2 format=3]\n\n"
		+ "[ext_resource type=\"Script\" path=\"res://src/controllers/gamepad_profile.gd\" id=\"1\"]\n\n"
		+ "[resource]\nscript = ExtResource(\"1\")\ncard_mode_toggle = true\n")
	f.close()
	var flipped: GamepadProfile = load(path)
	assert_not_null(flipped, "the flipped profile loads")
	assert_true(flipped.card_mode_toggle, "one `card_mode_toggle = true` line under [resource] flips it")
	DirAccess.remove_absolute(path)


# ---- AC 5 / AC 6 / AC 7 / AC 8: the toggle edges ----

func test_resolve_cast_mode_toggle_flips_on_the_press_edge_only() -> void:  # AC 5, AC 6
	assert_true(GamepadController.resolve_cast_mode(true, true, false, false), "press edge, off -> on")
	assert_false(GamepadController.resolve_cast_mode(true, true, false, true), "press edge, on -> off")
	assert_true(GamepadController.resolve_cast_mode(true, true, true, true), "held: stays on")
	assert_false(GamepadController.resolve_cast_mode(true, true, true, false), "held: stays off")
	assert_true(GamepadController.resolve_cast_mode(true, false, true, true), "release does nothing (on)")
	assert_false(GamepadController.resolve_cast_mode(true, false, true, false), "release does nothing (off)")
	assert_true(GamepadController.resolve_cast_mode(true, false, false, true), "idle stays on")


func test_resolve_cast_mode_hold_is_the_raw_level() -> void:  # AC 3
	for raw: bool in [false, true]:
		for prev: bool in [false, true]:
			for on: bool in [false, true]:
				assert_eq(GamepadController.resolve_cast_mode(false, raw, prev, on), raw,
					"HOLD ignores the edge memory and the stored mode")


func test_toggle_sequence_on_click_off_click_same_tick() -> void:  # AC 5, AC 6
	var c := GamepadController.new(0, _profile(true))
	var raw: Array[bool] = [false, true, true, false, false, true, true, false]
	var want: Array[bool] = [false, true, true, true, true, false, false, false]
	for i in 8:
		assert_eq(c._advance_cast_mode(raw[i]), want[i], "step %d: mode after raw L3 = %s" % [i, raw[i]])
		assert_eq(c.card_mode_on(), want[i], "step %d: the accessor agrees" % i)


func test_toggle_off_click_clears_the_armed_slot_that_tick() -> void:  # AC 6
	var c := GamepadController.new(0, _profile(true))
	c._advance_cast_mode(true)
	c._advance_cast_mode(false)
	var armed := int(_tick(c._advance_cast_mode(false), -1, 2)["armed_slot"])
	assert_eq(armed, 2, "still on: the armed slot is kept")
	var off := _tick(c._advance_cast_mode(true), -1, 2)  # second click
	assert_eq(off["armed_slot"], -1, "the second click exits and clears the arm the same tick")


func test_entering_card_mode_arms_nothing() -> void:  # AC 8
	var c := GamepadController.new(0, _profile(true))
	var r := _tick(c._advance_cast_mode(true), -1, -1)
	assert_true(c.card_mode_on(), "on")
	assert_eq(r["armed_slot"], -1, "entry arms nothing")
	assert_eq(c.armed_slot(), -1, "and the accessor says so")


func test_nothing_else_turns_card_mode_off() -> void:  # AC 7
	# attack, block, roll, run(A), a confirm, either trigger, R3 are all inputs to resolve_card_tick or the
	# lock sampling and NONE reaches the mode memory: with raw L3 released, the mode must survive each.
	var c := GamepadController.new(0, _profile(true))
	c._advance_cast_mode(true)
	c._advance_cast_mode(false)
	assert_true(c.card_mode_on(), "on and L3 released")
	var probes: Array[Dictionary] = []
	# attack, block, roll pressed; each in isolation
	probes.append(GamepadController.resolve_card_tick(c._advance_cast_mode(false),
		true, false, false, false, false, false, 0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1))
	probes.append(GamepadController.resolve_card_tick(c._advance_cast_mode(false),
		false, false, true, false, false, false, 0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1))
	probes.append(GamepadController.resolve_card_tick(c._advance_cast_mode(false),
		false, false, false, false, true, false, 0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1))
	# both triggers pulled through the threshold
	probes.append(GamepadController.resolve_card_tick(c._advance_cast_mode(false),
		false, false, false, false, false, false, 1.0, 0.0, 1.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1))
	# each confirm (A is also the run button)
	for confirm in 4:
		probes.append(_tick(c._advance_cast_mode(false), confirm, 1))
	assert_eq(probes.size(), 8, "eight probe ticks ran")
	assert_true(c.card_mode_on(), "attack/block/roll/triggers/four confirms left the mode on")
	for r: Dictionary in probes:
		assert_false(r["attack_held"] or r["block_held"] or r["roll_held"] or r["run_held"],
			"and the suppression set held on every probe tick")


# ---- AC 9 / AC 10: forced off, replug ----

func test_force_off_clears_mode_and_arm_and_a_held_l3_does_not_reenter() -> void:  # AC 9, AC 9 held-L3
	var c := GamepadController.new(0, _profile(true))
	c._advance_cast_mode(true)
	c._advance_cast_mode(true)
	c._armed_slot = 2
	c.force_card_mode_off()
	assert_false(c.card_mode_on(), "mode off after the forced off")
	assert_eq(c.armed_slot(), -1, "armed slot cleared")
	for i in 5:
		assert_false(c._advance_cast_mode(true), "L3 still held through the forced off: no re-entry (%d)" % i)
	c._advance_cast_mode(false)
	assert_true(c._advance_cast_mode(true), "a FRESH release-then-press turns it back on")


func test_force_off_is_a_no_op_under_hold() -> void:  # AC 3 (R3 is TOGGLE-only)
	var c := GamepadController.new(0, _profile(false))
	c._advance_cast_mode(true)
	c._armed_slot = 3
	c.force_card_mode_off()
	assert_true(c.card_mode_on(), "HOLD's mode is the live L3 level: unchanged")
	assert_eq(c.armed_slot(), 3, "and its armed slot is kept")


func test_base_controller_defaults_are_inert() -> void:  # AC 20 / Open Question 1
	var base := Controller.new()
	assert_false(base.card_mode_on(), "base: no card mode")
	base.force_card_mode_off()
	assert_false(base.card_mode_on(), "base force-off is a no-op")


func test_disconnect_neutral_path_clears_mode_and_primes_l3_held() -> void:  # AC 9d, AC 10
	var c := GamepadController.new(0, _profile(true))  # no device bound in the harness
	c._advance_cast_mode(true)
	c._advance_cast_mode(false)
	c._armed_slot = 1
	assert_true(c.card_mode_on(), "on before the disconnect")
	c.sample()  # the neutral path
	assert_false(c.card_mode_on(), "card mode is off after a disconnect")
	assert_eq(c.armed_slot(), -1, "armed slot cleared")
	assert_true(c._prev_held.get(GamepadController._CAST_TOGGLE_KEY, false),
		"L3 is primed HELD on the neutral path, like the four confirm edges")
	# replug with L3 already held: no toggle
	assert_false(c._advance_cast_mode(true), "replug with L3 held toggles nothing")
	assert_false(c._advance_cast_mode(true), "...still nothing while it stays held")
	c._advance_cast_mode(false)
	assert_true(c._advance_cast_mode(true), "release-then-press works after replug")


# ---- AC 11 / AC 4 / AC 12 / AC 13 / AC 14 ----

func test_commit_clears_armed_and_keeps_mode_for_all_four_confirms() -> void:  # AC 11
	for confirm in 4:
		var c := GamepadController.new(0, _profile(true))
		c._advance_cast_mode(true)
		var r := _tick(c._advance_cast_mode(false), confirm, 2)
		assert_true(r["card_commit"], "confirm %d raises a commit" % confirm)
		assert_eq(r["card_slot"], 2, "confirm %d commits the armed slot" % confirm)
		var armed := GamepadController.resolve_armed_after_commit(true, r["card_commit"], r["armed_slot"])
		assert_eq(armed, -1, "confirm %d disarms under TOGGLE" % confirm)
		assert_true(c.card_mode_on(), "confirm %d leaves the mode ON" % confirm)


func test_nothing_armed_commit_is_still_emitted_with_slot_minus_one() -> void:  # AC 11
	for confirm in 4:
		var r := _tick(true, confirm, -1)
		assert_true(r["card_commit"], "confirm %d with nothing armed is still emitted" % confirm)
		assert_eq(r["card_slot"], -1, "...with card_slot -1, so state's empty_slot refusal is reached")
		assert_eq(GamepadController.resolve_armed_after_commit(true, r["card_commit"], r["armed_slot"]), -1,
			"and it stays disarmed")


func test_hold_commit_does_not_clear_the_armed_slot() -> void:  # AC 4
	for confirm in 4:
		var r := _tick(true, confirm, 2)
		assert_eq(GamepadController.resolve_armed_after_commit(false, r["card_commit"], r["armed_slot"]), 2,
			"HOLD: confirm %d leaves the slot armed (unchanged, Fact 3)" % confirm)


func test_y_both_sides_under_toggle() -> void:  # AC 12
	var c := GamepadController.new(0, _profile(true))
	var off := _tick(c._advance_cast_mode(false), _CONFIRM_PITCH, -1)
	assert_true(off["card_activate"], "mode off: Y activates the staged card")
	c._advance_cast_mode(true)
	var on := _tick(c._advance_cast_mode(false), _CONFIRM_PITCH, 1)
	assert_true(on["card_commit"], "mode on: Y commits")
	assert_false(on["card_activate"], "...as a STAGE, not an activation")
	assert_eq(on["card_mode"], Enums.ModeKind.PITCH, "in PITCH mode")


func test_inside_toggle_card_mode_is_exactly_hold_card_mode() -> void:  # AC 13
	var c := GamepadController.new(0, _profile(true))
	c._advance_cast_mode(true)
	var on := c._advance_cast_mode(false)
	var expected := GamepadController.resolve_card_tick(true,
		true, false, true, false, true, false, 1.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1)
	var actual := GamepadController.resolve_card_tick(on,
		true, false, true, false, true, false, 1.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, false, false, 0.5, -1)
	assert_eq(actual, expected, "TOGGLE-on feeds resolve_card_tick the same cast_held HOLD's held L3 does")
	assert_false(actual["attack_held"] or actual["block_held"] or actual["roll_held"],
		"attack/block/roll suppressed")
	assert_eq(actual["armed_slot"], 2, "R1 (slot 2) is the rightmost of the same-tick chord, as under HOLD")


func test_leaving_toggle_card_mode_gives_no_edge_from_a_button_held_through_exit() -> void:  # AC 14
	var c := GamepadController.new(0, _profile(true))
	c._advance_cast_mode(true)
	c._advance_cast_mode(false)
	# A held since inside card mode (prev true), then the second click exits
	var r := GamepadController.resolve_card_tick(c._advance_cast_mode(true),
		false, false, false, false, false, false, 0.0, 0.0, 0.0, 0.0,
		true, true, false, false, false, false, false, false, 0.5, 2)
	assert_false(c.card_mode_on(), "exited")
	assert_false(r["card_commit"], "no commit from the button still held through the exit")
	assert_eq(r["armed_slot"], -1, "the arm is cleared")


# ---- AC 3 / AC 15: switch false equals today ----

func test_switch_false_pipeline_equals_todays_direct_call_on_a_bounded_sequence() -> void:  # AC 3
	var c := GamepadController.new(0, _profile(false))
	var armed_today := -1
	var armed_now := -1
	var lcg := 12345
	for i in 96:
		lcg = (lcg * 1103515245 + 12345) & 0x7fffffff
		var l3 := (lcg >> 4) % 3 != 0
		var confirm := ((lcg >> 8) % 6) - 2  # -2/-1 = none, 0..3 = a confirm
		var l2 := 1.0 if ((lcg >> 12) % 5 == 0) else 0.0
		var cast_now := c._advance_cast_mode(l3)
		assert_eq(cast_now, l3, "step %d: HOLD's mode is the raw level" % i)
		var today := GamepadController.resolve_card_tick(l3,
			false, false, false, false, false, false, l2, 0.0, 0.0, 0.0,
			confirm == 0, false, confirm == 1, false, confirm == 2, false, confirm == 3, false,
			0.5, armed_today)
		var now := GamepadController.resolve_card_tick(cast_now,
			false, false, false, false, false, false, l2, 0.0, 0.0, 0.0,
			confirm == 0, false, confirm == 1, false, confirm == 2, false, confirm == 3, false,
			0.5, armed_now)
		armed_today = today["armed_slot"]
		armed_now = GamepadController.resolve_armed_after_commit(false, now["card_commit"], now["armed_slot"])
		assert_eq(now, today, "step %d: identical resolve_card_tick output" % i)
		assert_eq(armed_now, armed_today, "step %d: identical armed slot (a commit never clears under HOLD)" % i)
