extends TestCase

## Story 2-2: the GamepadController + the source-agnostic advance() contract. NON-GOLDEN — this
## file never touches the determinism sequence. Joypad axes/buttons are not headless-samplable
## (Input.get_connected_joypads() is empty in the harness regardless of hardware), so the
## hardware-to-intent MAPPING is proven in the Live Smoke, not here. What IS headless-provable,
## and proven below:
##  (1) no pad at construction -> a neutral intent every tick, no crash (AC3b never-connected);
##  (2) the deadzone + unit-normalization contract (2-2/R5), via the PURE resolve_move_dir();
##  (3) AC5: a gamepad-produced (normalized) move_dir and the equivalent keyboard move_dir drive
##      byte-identical HeroState snapshots over N ticks — advance() cannot tell the source.
##
## Input.* in a TEST is fine — INVARIANT D3(a) scopes to src/ (see test_controller.gd).
##
## Story 5-0b: the card/cast scheme is covered the SAME way — the hardware-dependent bits
## (whether a real trigger crossing 0.5 actually reads as `true`) are Live-Smoke-only, exactly
## like the move-axis mapping above. What IS headless-provable is the DECISION built on top of a
## raw read, which is why the whole scheme lives in the pure `resolve_card_tick()` (and
## `resolve_trigger_edge()`) rather than inline in `sample()` — every AC 9 case below drives those
## pure functions directly with synthetic raw values, never a real device.


## In-code profile with explicit values, deliberately NOT loaded from data/gamepad_profile.tres:
## a re-tuning of the authored mapping must never break these behavioural guards (the same
## "constructed in-test, never loaded" principle as _golden_config / _config elsewhere).
func _profile() -> GamepadProfile:
	var p := GamepadProfile.new()
	p.move_axis_x = JOY_AXIS_LEFT_X
	p.move_axis_y = JOY_AXIS_LEFT_Y
	p.attack_button = JOY_BUTTON_RIGHT_SHOULDER  # R1 (2-2 review D1 scheme)
	p.block_button = JOY_BUTTON_LEFT_SHOULDER    # L1
	p.roll_button = JOY_BUTTON_B                  # B
	p.deadzone = 0.2
	return p


## A fully-live E1 config (same shape as the other state tests), so the source-agnostic
## comparison runs in a normally-started match, not a pre-injection one.
func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 3.0 / 60.0
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.attack_windup_move_speed_multiplier = 0.0
	c.attack_active_move_speed_multiplier = 0.0
	c.attack_recovery_move_speed_multiplier = 0.0
	# Story 3-1 (AC 1/AC 3): the mana CAP is authored data now that the constructor carries none.
	# 80.0 is what this fixture's MatchState.new used to supply, so behaviour is unchanged.
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config())
	ms.drain_signals()
	return ms


## Drive a fresh match N ticks feeding BOTH slots the given move_dir every tick, and return the
## canonical hash of the final snapshot. Deterministic: identical inputs -> identical hash, so
## two calls with EQUAL move_dir must agree byte-for-byte (that is the AC5 contract).
func _hash_driven_by(dir: Vector2) -> String:
	var ms := _make_match()
	for _t in range(20):
		var i1 := InputIntent.new()
		i1.move_dir = dir
		var i2 := InputIntent.new()
		i2.move_dir = dir
		var intents: Array[InputIntent] = [i1, i2]
		ms.advance(intents)
		ms.drain_signals()
	return CanonicalHash.of(ms.to_snapshot())


func test_no_pad_connected_yields_neutral_intent() -> void:
	# The harness has zero joypads connected, so the controller binds NO device at construction
	# (AC3b never-connected). It must yield a neutral intent every tick and never throw.
	var c := GamepadController.new(0, _profile())
	var a := c.sample()
	var b := c.sample()
	assert_true(a is InputIntent, "sample() returns an InputIntent even with no pad")
	assert_true(a.move_dir.is_zero_approx(), "neutral move with no pad")
	assert_eq(a.pressed.size(), 0, "no presses with no pad")
	assert_eq(a.held.size(), 0, "no holds with no pad")
	assert_eq(a.debug_reset, false, "no debug reset with no pad")
	assert_ne(a, b, "a FRESH InputIntent per sample, never a reused mutable one")
	var last := c.sample()
	for _i in range(30):
		last = c.sample()  # the shared neutral path must survive many ticks without error
	assert_true(last.move_dir.is_zero_approx(), "still neutral after 30 samples, no crash")


func test_below_deadzone_resolves_to_zero_vector() -> void:  # 2-2/R5
	var dz := 0.2
	assert_eq(GamepadController.resolve_move_dir(Vector2.ZERO, dz), Vector2.ZERO,
		"no deflection -> zero")
	assert_eq(GamepadController.resolve_move_dir(Vector2(0.1, 0.0), dz), Vector2.ZERO,
		"axis deflection below deadzone -> zero")
	assert_eq(GamepadController.resolve_move_dir(Vector2(0.1, 0.1), dz), Vector2.ZERO,
		"diagonal below deadzone (length ~0.14 < 0.2) -> zero")
	assert_eq(GamepadController.resolve_move_dir(Vector2(0.19, 0.0), dz), Vector2.ZERO,
		"just below the deadzone -> zero")


func test_above_deadzone_normalized_to_unit_length() -> void:  # 2-2/R5
	var dz := 0.2
	assert_almost_eq(GamepadController.resolve_move_dir(Vector2(0.6, 0.0), dz).length(), 1.0,
		1e-5, "partial axis deflection -> UNIT length, not 0.6 (no fractional-speed movement)")
	assert_almost_eq(GamepadController.resolve_move_dir(Vector2(0.5, 0.5), dz).length(), 1.0,
		1e-5, "partial diagonal deflection -> unit length")
	assert_almost_eq(GamepadController.resolve_move_dir(Vector2(1.0, 1.0), dz).length(), 1.0,
		1e-5, "full diagonal -> unit length, not sqrt(2)")
	var d := GamepadController.resolve_move_dir(Vector2(0.6, 0.0), dz)
	assert_almost_eq(d.x, 1.0, 1e-5, "direction preserved on +X")
	assert_almost_eq(d.y, 0.0, 1e-5, "no spurious Y component")


func test_gamepad_stick_up_matches_keyboard_up() -> void:  # Story 2-2 (review D2)
	# Y-sign pin: a raw stick vector meaning "pushed up" must resolve to the SAME move_dir the
	# keyboard produces for move_up — compared against the keyboard's ACTUAL output, not a chosen
	# literal. JOY_AXIS_LEFT_Y is positive-DOWN so stick-up is NEGATIVE raw Y; keyboard's
	# get_vector(_left,_right,_up,_down) puts _up on the negative-Y arg, so keyboard-up is -Y too.
	# The conventions coincide: raw Y is read directly, no inversion (an inversion would MISMATCH).
	var kc := KeyboardController.new(&"p1")
	Input.action_press(&"p1_move_up")
	var keyboard_up := kc.sample().move_dir
	Input.action_release(&"p1_move_up")
	assert_true(keyboard_up.y < 0.0, "keyboard 'up' is NEGATIVE Y (get_vector _up = negative-y arg)")
	var gamepad_up := GamepadController.resolve_move_dir(Vector2(0.0, -0.6), _profile().deadzone)
	assert_eq(gamepad_up, keyboard_up, "gamepad stick-up (negative raw Y) equals keyboard move_up")


func test_analog_intent_and_keyboard_intent_produce_identical_snapshots() -> void:  # AC5 + review D2
	# The source-agnostic advance() contract: a gamepad-produced move_dir and the equivalent
	# keyboard move_dir drive HeroState byte-identically — state never learns the source. Covered
	# on BOTH axes (review D2 extends the X-only original): a partial deflection (0.6) normalizes
	# to unit and is BIT-EXACT against the keyboard's single-axis magnitude, so the snapshot
	# comparison stays byte-identical without a diagonal's last-ULP risk.
	var dz := _profile().deadzone
	var kc := KeyboardController.new(&"p1")

	# X axis: gamepad right (0.6,0)->(1,0) vs the REAL keyboard's move_right (1,0).
	var analog_right := GamepadController.resolve_move_dir(Vector2(0.6, 0.0), dz)
	Input.action_press(&"p1_move_right")
	var keyboard_right := kc.sample().move_dir
	Input.action_release(&"p1_move_right")
	assert_eq(analog_right, keyboard_right,
		"gamepad right (0.6,0)->(1,0) equals keyboard move_right (1,0), bit-identical")
	assert_eq(_hash_driven_by(analog_right), _hash_driven_by(keyboard_right),
		"X: byte-identical HeroState snapshots over 20 ticks — advance() is source-agnostic (AC5)")

	# Y axis (review D2): stick pushed UP is negative raw Y; keyboard move_up is -Y too (no
	# inversion). (0,-0.6)->(0,-1) is bit-exact against the keyboard's single-axis (0,-1).
	var analog_up := GamepadController.resolve_move_dir(Vector2(0.0, -0.6), dz)
	Input.action_press(&"p1_move_up")
	var keyboard_up := kc.sample().move_dir
	Input.action_release(&"p1_move_up")
	assert_eq(analog_up, keyboard_up,
		"gamepad up (0,-0.6)->(0,-1) equals keyboard move_up (0,-1), bit-identical")
	assert_eq(_hash_driven_by(analog_up), _hash_driven_by(keyboard_up),
		"Y: byte-identical HeroState snapshots over 20 ticks — source-agnostic on the Y axis too")


func test_gamepad_ordinal_is_pure_function_of_config() -> void:  # Story 2-2 (review D3)
	# The gamepad ordinal is derived from the config, NOT a mutable counter: the i-th GAMEPAD slot
	# binds the i-th connected joypad. Instantiate the runner script off-tree (the derivation
	# touches no @onready node) and drive _gamepad_ordinal_for_slot directly.
	var runner: Variant = load("res://src/main/match_runner.gd").new()
	runner.slot_controller_kinds.assign([3, 3])  # [GAMEPAD, GAMEPAD]
	assert_eq(runner._gamepad_ordinal_for_slot(0), 0, "first GAMEPAD -> ordinal 0")
	assert_eq(runner._gamepad_ordinal_for_slot(1), 1, "second GAMEPAD -> ordinal 1")
	runner.slot_controller_kinds.assign([0, 3])  # [KEYBOARD_P1, GAMEPAD]
	assert_eq(runner._gamepad_ordinal_for_slot(1), 0,
		"lone GAMEPAD on slot 1 takes ordinal 0, NOT the slot index")
	runner.free()


## ============================================================================================
## STORY 5-0b: the pad card/cast scheme (AC 1-6, AC 9). Every case below drives the PURE
## resolve_card_tick() / resolve_trigger_edge() directly with synthetic raw values -- the same
## reason resolve_move_dir()/resolve_flick() are tested this way above: real joypad reads are not
## headless-samplable, so the DECISION built on top of a raw read is what stays testable.
## ============================================================================================


## Story 6-8 (AC 7, Open Question 6): the unlocked camera axis from the right stick's raw X -- an
## axial dead zone on the profile's `deadzone`, then linear to +/-1, sign preserved (right is +).
func test_resolve_camera_rotate_dead_zone_linear_and_signed() -> void:
	var dz := 0.2
	assert_eq(GamepadController.resolve_camera_rotate(0.0, dz), 0.0, "at rest")
	assert_eq(GamepadController.resolve_camera_rotate(0.2, dz), 0.0, "exactly at the dead zone: still 0")
	assert_eq(GamepadController.resolve_camera_rotate(-0.15, dz), 0.0, "inside the dead zone, left")
	assert_almost_eq(GamepadController.resolve_camera_rotate(0.6, dz), 0.5, 1e-6,
		"halfway through the live range reads half rate")
	assert_almost_eq(GamepadController.resolve_camera_rotate(-0.6, dz), -0.5, 1e-6, "and signed left")
	assert_eq(GamepadController.resolve_camera_rotate(1.0, dz), 1.0, "full right is full rate")
	assert_eq(GamepadController.resolve_camera_rotate(-1.2, dz), -1.0, "clamped past full deflection")


func test_resolve_trigger_edge_requires_crossing_not_holding() -> void:  # AC 2
	var t := 0.5
	assert_true(GamepadController.resolve_trigger_edge(0.6, 0.0, t),
		"crossing the threshold this tick, below it last tick -> edge")
	assert_false(GamepadController.resolve_trigger_edge(0.6, 0.5, t),
		"already at/above threshold last tick -> no repeat edge, a held trigger arms once")
	assert_false(GamepadController.resolve_trigger_edge(0.6, 0.6, t),
		"still held past threshold -> no repeat edge")
	assert_false(GamepadController.resolve_trigger_edge(0.4, 0.0, t),
		"below threshold -> no edge")
	assert_true(GamepadController.resolve_trigger_edge(0.5, 0.0, t),
		"exactly at threshold counts as crossed")


## ============================================================================================
## STORY 7-11: CONTROL SCHEME v2 (R1-R4, G1, G3, AC 1-9). A D-pad tap ARMS a slot (sticky); X / Y / L2 /
## R2 PLAY it; there is no modifier. Every case drives the PURE `resolve_arm()` / `resolve_card_tick()`
## with synthetic raw reads -- real joypad reads are not headless-samplable (the 5-0b reasoning above).
## The 5-0b/5-7/6-3a/6-10 card-mode tests are RETIRED with the scheme (M2); the ones whose NAME is still
## true were rewritten in place below.
## ============================================================================================


const _REST: Array[bool] = [false, false, false, false]
const _DEFAULT_SLOTS: Array[int] = [0, 1, 2, 3]   # left, up, down, right -> hand slot index


## The four direction reads, in the profile's direction order (left, up, down, right).
func _dirs(left := false, up := false, down := false, right := false) -> Array[bool]:
	return [left, up, down, right]


## One sample of the pure resolver. Every raw read is at rest unless named in `o`; the D-pad reads default
## to nothing down now or last sample, and the map to the shipped default. Positional through the REAL
## signature, so a re-seated parameter fails every test that names it.
func _tick(o: Dictionary = {}) -> Dictionary:
	var dpad: Array[bool] = []
	dpad.assign(o.get("dpad", _REST))
	var prev_dpad: Array[bool] = []
	prev_dpad.assign(o.get("prev_dpad", _REST))
	var slots: Array[int] = []
	slots.assign(o.get("slots", _DEFAULT_SLOTS))
	return GamepadController.resolve_card_tick(
		o.get("attack", false), o.get("prev_attack", false),
		o.get("block", false), o.get("prev_block", false),
		o.get("roll", false), o.get("prev_roll", false),
		o.get("run", false),
		dpad, prev_dpad, slots,
		o.get("l2", 0.0), o.get("prev_l2", 0.0),
		o.get("r2", 0.0), o.get("prev_r2", 0.0),
		o.get("x", false), o.get("prev_x", false),
		o.get("y", false), o.get("prev_y", false),
		o.get("ready", false),
		0.5,
		o.get("armed", -1))


## AC 1: a D-pad press EDGE arms the slot the default map gives that direction (left/up/down/right ->
## the player's slots 1/2/3/4, code indexes 0..3), and arming emits no commit.
func test_dpad_press_edge_arms_the_mapped_slot() -> void:  # 7-11 AC 1
	for d in 4:
		var dpad := _REST.duplicate()
		dpad[d] = true
		var r := _tick({"dpad": dpad})
		assert_eq(r["armed_slot"], d, "direction %d arms slot index %d" % [d, d])
		assert_false(r["card_commit"], "arming emits no commit (direction %d)" % d)
	assert_eq(_tick({"dpad": _dirs(true), "prev_dpad": _dirs(true)})["armed_slot"], -1,
		"a direction already down last sample arms nothing -- holding a direction arms ONCE")
	assert_eq(_tick({"dpad": _dirs(false, true), "armed": 1})["armed_slot"], 1,
		"re-tapping the armed direction keeps it armed")
	assert_eq(_tick({"dpad": _dirs(false, false, false, true), "armed": 1})["armed_slot"], 3,
		"tapping another direction moves the arm")
	assert_eq(_tick({"armed": 2})["armed_slot"], 2, "with no D-pad press the arm is kept (sticky)")


## AC 1/AC 10: the direction -> slot map is profile DATA, and the shipped default is left/up/down/right ->
## 0/1/2/3 on the four D-pad buttons.
func test_the_direction_map_is_profile_data() -> void:  # 7-11 AC 1/AC 10
	var swapped := [3, 1, 2, 0]   # left <-> right
	assert_eq(_tick({"dpad": _dirs(true), "slots": swapped})["armed_slot"], 3,
		"left arms slot 3 under a left/right swap")
	assert_eq(_tick({"dpad": _dirs(false, false, false, true), "slots": swapped})["armed_slot"], 0,
		"...and right arms slot 0")
	for profile: GamepadProfile in [GamepadProfile.new(), load("res://data/gamepad_profile.tres")]:
		assert_eq(str(profile.dpad_slots()), str([0, 1, 2, 3]),
			"the default map is left/up/down/right -> 0/1/2/3 (%s)" % profile.resource_path)
		assert_eq(str(profile.dpad_buttons()), str([JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]),
			"the arming buttons are the four D-pad directions, in direction order (%s)" % profile.resource_path)


## AC 2: two directions on ONE sample resolve to exactly one armed slot -- slots evaluated in ascending
## index order, last write wins, so the HIGHER slot index wins, independent of the direction map.
func test_two_directions_on_one_sample_arm_the_higher_slot() -> void:  # 7-11 AC 2
	assert_eq(_tick({"dpad": _dirs(true, false, false, true)})["armed_slot"], 3, "left + right -> slot 3")
	assert_eq(_tick({"dpad": _dirs(false, true, true)})["armed_slot"], 2, "up + down -> slot 2")
	assert_eq(_tick({"dpad": _dirs(true, true)})["armed_slot"], 1, "left + up (a diagonal) -> slot 1")
	assert_eq(_tick({"dpad": _dirs(true, true, true, true)})["armed_slot"], 3, "all four -> slot 3")
	var reversed := [3, 2, 1, 0]
	assert_eq(_tick({"dpad": _dirs(true, false, false, true), "slots": reversed})["armed_slot"], 3,
		"left + right under a REVERSED map -> slot 3, now the LEFT direction's: the slot index decides")
	assert_eq(_tick({"dpad": _dirs(true, true), "slots": reversed})["armed_slot"], 3,
		"left + up under a reversed map -> slot 3 (left's), not slot 2 (up's)")
	assert_eq(_tick({"dpad": _dirs(true, false, false, true), "prev_dpad": _dirs(false, false, false, true)})["armed_slot"],
		0, "right HELD + left fresh -> slot 0: a held direction is not a press and does not compete")
	var dirs := _dirs(true, false, false, true)
	var slots: Array[int] = [0, 1, 2, 3]
	assert_eq(GamepadController.resolve_arm(dirs, _REST, slots, -1), 3,
		"the same rule through resolve_arm() directly")


## STORY 7-11 REWRITE (G3): X is the BASIC play, no modifier. A fresh X ALWAYS commits, carrying the armed
## slot -- or -1 with nothing armed, which state refuses (empty_slot); the controller never swallows it.
func test_resolve_card_tick_basic_always_commits_on_fresh_press() -> void:  # 7-11 AC 5/AC 7
	var r := _tick({"x": true})
	assert_true(r["card_commit"], "a fresh X ALWAYS raises a commit, even with nothing armed")
	assert_eq(r["card_slot"], -1, "the commit carries slot -1, unarmed -- state refuses it, not the controller")
	assert_eq(r["card_mode"], Enums.ModeKind.BASIC, "...as mode ① BASIC")
	assert_eq(r["armed_slot"], -1, "still nothing armed")
	r = _tick({"x": true, "armed": 2})
	assert_true(r["card_commit"], "X commits the armed slot")
	assert_eq(r["card_slot"], 2, "...slot 2")
	r = _tick({"x": true, "dpad": _dirs(false, true), "armed": 3})
	assert_eq(r["armed_slot"], 1, "up arms slot 1 on the same sample as X")
	assert_eq(r["card_slot"], 1, "...and X plays the newly armed slot (arming resolves first)")
	assert_false(_tick({"x": true, "prev_x": true, "armed": 1})["card_commit"],
		"X merely held (not freshly pressed) does not commit")


## STORY 6-3a (AC 3): REPLACES 5-7's `test_no_authored_button_maps_to_y_so_pitch_is_structurally_
## unreachable`, RETIRED rather than narrowed (Fact 8). That guard existed for exactly one fact -- no
## button maps to Y -- and `cast_pitch_button` makes it false by construction; there is no other button
## left to assert unmapped. Its two open items (the untested evasion forms, the blanket ban on a Y
## binding) were reasons to keep it alive and retire with it.
##
## What replaces it is the pin every other confirm button already has: the field reads Y on BOTH the
## script default and the shipped `.tres`. The retired guard's field-count floor is carried forward, so
## the scan still cannot pass on an emptied property list; with Y authored it is NINE button fields.
func test_cast_pitch_button_reads_y_on_the_default_and_the_shipped_profile() -> void:  # 6-3a AC 1/AC 3
	for profile: GamepadProfile in [GamepadProfile.new(), load("res://data/gamepad_profile.tres")]:
		var button_fields: Array[String] = []
		for p in profile.get_property_list():
			var name := String(p["name"])
			if name.ends_with("_button"):
				button_fields.append(name)
		assert_true(button_fields.size() >= 8,
			"sanity: the scan really found the button fields, so an emptied list cannot pass "
			+ "vacuously (found %d: %s)" % [button_fields.size(), ", ".join(button_fields)])
		assert_true(button_fields.has("cast_pitch_button"),
			"...and `cast_pitch_button` is one of them (found: %s)" % ", ".join(button_fields))
		assert_eq(profile.get("cast_pitch_button"), JOY_BUTTON_Y,
			"cast_pitch_button reads JOY_BUTTON_Y (%s)" % profile.resource_path)
	var shipped: GamepadProfile = load("res://data/gamepad_profile.tres")
	var text := FileAccess.get_file_as_string("res://data/gamepad_profile.tres")
	assert_true(text.contains("cast_pitch_button = %d" % JOY_BUTTON_Y),
		"the shipped .tres AUTHORS the value explicitly rather than inheriting the script default "
		+ "(%s)" % shipped.resource_path)


## STORY 7-11 REWRITE (G3): the other plays, nothing armed -- R2, L2 and a Y with no READY zone still RAISE
## the commit carrying slot -1, so state's empty-slot refusal answers it (`5-0b/R1`, `5-7/R5` kept).
func test_resolve_card_tick_mode_confirms_commit_empty_slot_rather_than_swallow() -> void:  # 7-11 AC 7
	for c: Array in [[{"r2": 0.6}, Enums.ModeKind.UNBLOCKABLE, "R2"], [{"l2": 0.6}, Enums.ModeKind.DEFENSE, "L2"],
			[{"y": true}, Enums.ModeKind.PITCH, "Y"]]:
		var r := _tick(c[0])
		assert_true(r["card_commit"], "a fresh %s ALWAYS raises a commit, even with nothing armed" % c[2])
		assert_eq(r["card_slot"], -1, "...carrying slot -1 -- state refuses it, not the controller (%s)" % c[2])
		assert_eq(r["card_mode"], c[1], "...still carrying %s's mode" % c[2])
		assert_false(r["card_activate"], "...and never an activation (%s, zone not READY)" % c[2])


## AC 5: X / Y (zone not READY) / R2 / L2 with a slot armed commit THAT slot, in modes ① / ④ / ② / ③, as
## plays (never activations). The triggers use the existing crossing edge: a pull plays once.
func test_the_four_plays_commit_the_armed_slot_with_their_modes() -> void:  # 7-11 AC 5
	for c: Array in [[{"x": true}, Enums.ModeKind.BASIC, "X"], [{"y": true}, Enums.ModeKind.PITCH, "Y"],
			[{"r2": 0.6}, Enums.ModeKind.UNBLOCKABLE, "R2"], [{"l2": 0.6}, Enums.ModeKind.DEFENSE, "L2"]]:
		var o: Dictionary = (c[0] as Dictionary).duplicate()
		o["armed"] = 2
		var r := _tick(o)
		assert_true(r["card_commit"], "%s commits" % c[2])
		assert_eq(r["card_slot"], 2, "...the armed slot (%s)" % c[2])
		assert_eq(r["card_mode"], c[1], "...in its own mode (%s)" % c[2])
		assert_false(r["card_activate"], "...as a play, never an activation (%s)" % c[2])
	assert_false(_tick({"r2": 0.9, "prev_r2": 0.9, "armed": 2})["card_commit"], "R2 held past the threshold plays nothing new")
	assert_false(_tick({"l2": 0.9, "prev_l2": 0.6, "armed": 2})["card_commit"], "L2 held past the threshold plays nothing new")
	assert_false(_tick({"r2": 0.4, "armed": 2})["card_commit"], "R2 short of the threshold plays nothing")
	assert_false(_tick({"y": true, "prev_y": true, "armed": 2})["card_commit"], "Y held (not freshly pressed) plays nothing")


## AC 5: a same-sample chord of play buttons resolves to AT MOST ONE commit, in the fixed order X, Y, L2, R2
## with the last write winning -- R2 wins any chord it is in (the answer B gave every chord under 5-7).
func test_play_chord_resolves_in_the_order_x_y_l2_r2() -> void:  # 7-11 AC 5
	var all := _tick({"x": true, "y": true, "l2": 0.6, "r2": 0.6, "armed": 1})
	assert_true(all["card_commit"], "the four-play chord commits")
	assert_eq(all["card_mode"], Enums.ModeKind.UNBLOCKABLE, "all four -> R2, UNBLOCKABLE")
	assert_eq(all["card_slot"], 1, "...once, on the armed slot")
	assert_eq(_tick({"x": true, "y": true, "armed": 1})["card_mode"], Enums.ModeKind.PITCH, "X + Y -> Y")
	assert_eq(_tick({"x": true, "l2": 0.6, "armed": 1})["card_mode"], Enums.ModeKind.DEFENSE, "X + L2 -> L2")
	assert_eq(_tick({"y": true, "l2": 0.6, "armed": 1})["card_mode"], Enums.ModeKind.DEFENSE, "Y + L2 -> L2")
	assert_eq(_tick({"l2": 0.6, "r2": 0.6, "armed": 1})["card_mode"], Enums.ModeKind.UNBLOCKABLE, "L2 + R2 -> R2")
	assert_eq(_tick({"x": true, "r2": 0.6, "armed": 1})["card_mode"], Enums.ModeKind.UNBLOCKABLE, "X + R2 -> R2")
	var over := _tick({"y": true, "r2": 0.6, "ready": true, "armed": 1})
	assert_eq(over["card_mode"], Enums.ModeKind.UNBLOCKABLE, "Y (zone READY) + R2 -> R2")
	assert_false(over["card_activate"], "...and the overwritten activation does not leak onto the R2 commit")
	assert_eq(over["card_slot"], 1, "...which carries the armed slot")


## AC 6 (R3): with the own Pitch Zone READY, Y ACTIVATES -- PITCH, `card_activate` true, `card_slot` -1,
## whatever is armed, and the arm is untouched. Otherwise Y stages the armed card.
func test_y_with_a_ready_zone_activates_whatever_is_armed() -> void:  # 7-11 AC 6
	for armed: int in [-1, 0, 3]:
		var r := _tick({"y": true, "ready": true, "armed": armed})
		assert_true(r["card_commit"], "READY + Y commits (armed %d)" % armed)
		assert_eq(r["card_mode"], Enums.ModeKind.PITCH, "...as PITCH (armed %d)" % armed)
		assert_true(r["card_activate"], "...as an ACTIVATION (armed %d)" % armed)
		assert_eq(r["card_slot"], -1, "...addressing no hand slot (armed %d)" % armed)
		assert_eq(r["armed_slot"], armed, "...and the arm is untouched (armed %d)" % armed)
	var stage := _tick({"y": true, "ready": false, "armed": 3})
	assert_false(stage["card_activate"], "zone not READY: Y is a STAGE")
	assert_eq(stage["card_slot"], 3, "...of the armed card")
	assert_false(_tick({"ready": true, "armed": 3})["card_commit"], "a READY zone with no Y press commits nothing")
	assert_false(_tick({"x": true, "ready": true, "armed": 3})["card_activate"], "READY never turns X into an activation")


## G1 (AC 3): a play press never clears the arm -- only the armed card LEAVING its slot does
## (`observe_hand_ids`, `test_control_scheme_v2.gd`). The resolver hands the arm back on every play.
func test_no_play_press_clears_the_arm() -> void:  # 7-11 AC 3
	for o: Dictionary in [{"x": true}, {"y": true}, {"y": true, "ready": true}, {"l2": 0.6}, {"r2": 0.6}]:
		var with_arm := o.duplicate()
		with_arm["armed"] = 1
		var r := _tick(with_arm)
		assert_true(r["card_commit"], "sanity: %s commits" % str(o))
		assert_eq(r["armed_slot"], 1, "%s leaves the arm on slot 1" % str(o))


## AC 8: R1 / L1 / B / A are their raw reads at ALL times -- no suppression with a slot armed, a direction
## tapped or a play pressed on the same sample. A held is RUN, always.
func test_attack_block_roll_run_are_never_suppressed() -> void:  # 7-11 AC 8
	var r := _tick({"attack": true, "block": true, "roll": true, "run": true,
		"x": true, "r2": 0.6, "dpad": _dirs(true), "armed": 2})
	for k: String in ["attack_held", "attack_pressed", "block_held", "block_pressed", "roll_held", "roll_pressed",
			"run_held"]:
		assert_true(r[k], "%s is the raw read, unsuppressed" % k)
	var held := _tick({"attack": true, "prev_attack": true, "roll": true, "prev_roll": true, "armed": 1})
	assert_true(held["attack_held"] and held["roll_held"], "held reads stay held")
	assert_false(held["attack_pressed"] or held["roll_pressed"], "...and a held button is not a fresh press")
	assert_false(_tick({"armed": 1})["run_held"], "A released -> not running")


## AC 9 (R2: one scheme): the card-mode surface is DELETED, not dormant -- no profile field, no controller
## method, no runner call. Checked by reflection on the live types (a renamed body cannot hide a property or
## a method) and on the runner's source for the retired call shapes.
func test_the_card_mode_surface_is_deleted() -> void:  # 7-11 AC 9
	var props: Array[String] = []
	for p in GamepadProfile.new().get_property_list():
		props.append(String(p["name"]))
	for field: String in ["cast_button", "card_mode_alt_button", "card_mode_toggle", "cast_basic_button",
			"cast_unblockable_button", "cast_defense_button"]:
		assert_false(field in props, "GamepadProfile has no `%s`" % field)
	assert_true("hand_layout" in props and "dpad_left_slot" in props, "sanity: the scan sees the v2 fields")
	var objects: Array = [GamepadController.new(0, _profile()), KeyboardController.new(&"p1"), Controller.new()]
	for m: String in ["card_mode_on", "force_card_mode_off", "resolve_cast_mode", "resolve_armed_after_commit",
			"_advance_cast_mode"]:
		for o: Object in objects:
			assert_false(o.has_method(m), "%s has no `%s`" % [o.get_script().resource_path.get_file(), m])
	assert_true(objects[0].has_method("clear_armed_slot") and objects[0].has_method("observe_hand_ids"),
		"sanity: the v2 methods resolve, so has_method is not vacuously false")
	var runner_text := FileAccess.get_file_as_string("res://src/main/match_runner.gd")
	for token: String in ["force_card_mode_off", "card_mode_on", "set_card_mode", "_was_knocked_down"]:
		assert_false(runner_text.contains(token), "match_runner.gd no longer names `%s`" % token)


## STORY 7-11 REWRITE (AC 4): the neutral/no-device path drops the arm and primes EVERY v2 card edge HELD --
## X, Y, the four D-pad directions and both triggers -- so a replug with any of them already down arms
## nothing and plays nothing. NON-VACUOUS: every memory is set RELEASED and a slot armed first, so the
## assertions can only pass if the neutral path itself wrote them.
func test_replug_priming_covers_the_new_commit_edges() -> void:  # 7-11 AC 4
	var c := GamepadController.new(0, _profile())
	c._armed_slot = 2
	c._prev_l2 = 0.0
	c._prev_r2 = 0.0
	var keys: Array[StringName] = [GamepadController._PLAY_BASIC_KEY, GamepadController._CAST_PITCH_KEY]
	keys.append_array(GamepadController._DPAD_KEYS)
	for key in keys:
		c._prev_held[key] = false
	c.sample()  # the neutral path (no device bound in the harness) -- the reconnect's first tick
	for key in keys:
		assert_true(c._prev_held.get(key, false), "`%s` is primed HELD by the neutral path" % key)
	assert_eq(c._prev_l2, 1.0, "the L2 prev is primed HELD")
	assert_eq(c._prev_r2, 1.0, "...and the R2 prev")
	assert_eq(c.armed_slot(), -1, "a disconnect drops the arm (AC 4)")
	var primed_dpad: Array[bool] = []
	for key in GamepadController._DPAD_KEYS:
		primed_dpad.append(c._prev_held[key])
	var r := _tick({"dpad": _dirs(true, true, true, true), "prev_dpad": primed_dpad,
		"x": true, "prev_x": c._prev_held[GamepadController._PLAY_BASIC_KEY],
		"y": true, "prev_y": c._prev_held[GamepadController._CAST_PITCH_KEY],
		"l2": 1.0, "prev_l2": c._prev_l2, "r2": 1.0, "prev_r2": c._prev_r2})
	assert_false(r["card_commit"], "a replug with every card input already down plays nothing")
	assert_eq(r["armed_slot"], -1, "...and arms nothing")
	var control := _tick({"dpad": _dirs(true), "x": true})
	assert_true(control["card_commit"] and control["armed_slot"] == 0,
		"control: the same presses against UN-primed memories arm and play, so the prime is the cause")


## STORY 6-9 post-review fix (N2), rewritten for 7-11: the RUNTIME guard on a deleted held key's absence. An
## ALLOW-LIST: the held products the pure resolver returns are exactly the four live ones, whatever is
## armed and whichever play is down. (`sample()`'s own `intent.held` writes are not headless-reachable, but
## every one of them reads a `*_held` product of this dict, so the product is the seam.)
func test_resolve_card_tick_produces_exactly_the_live_held_keys() -> void:
	var live: Array = ["attack_held", "block_held", "roll_held", "run_held"]
	for o: Dictionary in [{}, {"x": true, "armed": 1}, {"r2": 0.6, "l2": 0.6}, {"y": true, "ready": true},
			{"dpad": _dirs(true, true)}]:
		var r := _tick(o)
		var produced: Array = []
		for k: String in r.keys():
			if k.ends_with("_held"):
				produced.append(k)
		produced.sort()
		assert_eq(produced, live, "%s: the resolver returns exactly the live held products and no other" % str(o))


## Falsifiable source-scan disjointness, markers moved for 7-11: the card-scheme code (resolve_arm() /
## resolve_card_tick() and the card block inside sample()) never references lock-on state, and
## _sample_lock_controls() never references card-scheme state. COMMENT LINES ARE STRIPPED before the scan:
## the resolver's doc cites `resolve_flick` as its precedent, which is prose, not a reference.
func test_card_scheme_and_lock_on_paths_are_disjoint() -> void:  # AC 6 (review fix: was tautological)
	var f := FileAccess.open("res://src/controllers/gamepad_controller.gd", FileAccess.READ)
	assert_true(f != null,
		"gamepad_controller.gd must be openable for the source scan (FileAccess error %d)"
				% FileAccess.get_open_error())
	if f == null:
		return
	var text := f.get_as_text()

	var resolve_start := text.find("static func resolve_arm(")
	var resolve_end := text.find("func armed_slot() -> int:")
	assert_true(resolve_start != -1 and resolve_end != -1 and resolve_end > resolve_start,
		"resolve_arm/resolve_card_tick's source region must be found by both markers")
	var resolve_src := _code_only(text.substr(resolve_start, resolve_end - resolve_start))

	var card_block_start := text.find("var attack_raw := Input.is_joy_button_pressed")
	var card_block_end := text.find("_sample_lock_controls()", card_block_start)
	assert_true(card_block_start != -1 and card_block_end != -1 and card_block_end > card_block_start,
		"sample()'s card block region must be found by both markers")
	var card_block_src := _code_only(text.substr(card_block_start, card_block_end - card_block_start))
	assert_true(resolve_src.contains("resolve_trigger_edge") and card_block_src.contains("resolve_card_tick("),
		"sanity: both stripped regions still hold code")

	for token in ["_lock_pressed", "_flick", "_prev_flick_magnitude"]:
		assert_false(resolve_src.contains(token),
			"resolve_arm/resolve_card_tick must never reference lock-on state (%s)" % token)
		assert_false(card_block_src.contains(token),
			"sample()'s card block must never reference lock-on state (%s)" % token)

	var lock_start := text.find("func _sample_lock_controls() -> void:")
	var lock_end := text.find("static func resolve_flick(")
	assert_true(lock_start != -1 and lock_end != -1 and lock_end > lock_start,
		"_sample_lock_controls's source region must be found by both markers")
	var lock_src := _code_only(text.substr(lock_start, lock_end - lock_start))
	for token in ["_armed_slot", "_prev_l2", "_prev_r2", "_PLAY_BASIC_KEY", "_CAST_PITCH_KEY", "_DPAD_KEYS",
			"_dpad_", "_pitch_ready", "_hand_ids"]:
		assert_false(lock_src.contains(token),
			"_sample_lock_controls must never reference card-scheme state (%s)" % token)


## `src` with every whole-line `#` comment removed.
func _code_only(src: String) -> String:
	var out: PackedStringArray = []
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			out.append(line)
	return "\n".join(out)


## 6-3a AC 2's caller path, re-pointed for 7-11: `sample()` is not headless-drivable past the neutral path,
## so its wiring is pinned by CONTENT -- each line whose absence would silently drop Y between the device and
## the intent. Positional seat included: the Y pair must sit directly before the READY bool, where the
## signature declares it, or a bool lands in a parameter of the same type with no error.
func test_sample_carries_y_and_card_activate_into_the_intent() -> void:  # 6-3a AC 2 / 7-11 R3
	var body := _sample_body()
	for needle: String in [
		"var pitch_raw := Input.is_joy_button_pressed(_device, _profile.cast_pitch_button)",
		"pitch_raw, _prev_held.get(_CAST_PITCH_KEY, false),\n\t\t_pitch_ready,",
		"_prev_held[_CAST_PITCH_KEY] = pitch_raw",
		"_prev_held[_CAST_PITCH_KEY] = true",
	]:
		assert_true(body.contains(needle), "sample() carries: %s" % needle)
	var commit_block := body.substr(body.find("if result[\"card_commit\"]:"))
	commit_block = commit_block.substr(0, commit_block.find("\n\n"))
	assert_true(commit_block.contains("intent.card_activate = result[\"card_activate\"]"),
		"sample() writes card_activate onto the intent INSIDE the commit block")


## 7-11 AC 1/AC 4: the same content pin for the D-pad half of sample(): each direction is read through the
## profile's arming buttons, handed to the resolver with its memory, remembered after, and the arm is
## written back from the resolver -- and never on the commit branch alone (G1: a play never clears it).
func test_sample_carries_the_dpad_into_the_resolver_and_back() -> void:  # 7-11 AC 1/AC 4
	var body := _sample_body()
	for needle: String in [
		"_dpad_raw[i] = Input.is_joy_button_pressed(_device, _dpad_buttons[i])",
		"_dpad_prev[i] = _prev_held.get(_DPAD_KEYS[i], false)",
		"run_raw,\n\t\t_dpad_raw, _dpad_prev, _dpad_slots,",
		"_prev_held[_DPAD_KEYS[i]] = _dpad_raw[i]",
		"_armed_slot = result[\"armed_slot\"]",
		"var run_raw := Input.is_joy_button_pressed(_device, _profile.run_button)",
		"var basic_raw := Input.is_joy_button_pressed(_device, _profile.play_basic_button)",
	]:
		assert_true(body.contains(needle), "sample() carries: %s" % needle)


func _sample_body() -> String:
	var text := FileAccess.get_file_as_string("res://src/controllers/gamepad_controller.gd")
	var start := text.find("func sample() -> InputIntent:")
	var end := text.find("func _sample_lock_controls() -> void:")
	assert_true(start != -1 and end > start, "sample()'s source region must be found by both markers")
	return text.substr(start, end - start)
