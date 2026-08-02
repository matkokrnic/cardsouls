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
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _make_match() -> MatchState:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
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


func test_variable_magnitude_passes_partial_deflection_through() -> void:  # Story 2-6 (AC 4, 2-6/R8)
	# normalize_magnitude == false: above the deadzone the stick's ACTUAL magnitude passes through
	# (clamped to length 1.0), so a partial deflection is a partial move_dir magnitude instead of
	# binary speed. Below the deadzone still ZERO (the toggle changes only the above-deadzone rule).
	var dz := 0.2
	assert_eq(GamepadController.resolve_move_dir(Vector2(0.1, 0.0), dz, false), Vector2.ZERO,
		"deadzone still applies with the toggle off")
	var half := GamepadController.resolve_move_dir(Vector2(0.6, 0.0), dz, false)
	assert_almost_eq(half.length(), 0.6, 1e-5,
		"toggle OFF: 0.6 deflection passes through as magnitude 0.6, NOT normalized to 1.0")
	assert_almost_eq(half.x, 0.6, 1e-5, "direction and magnitude both preserved on +X")
	# Clamp: an over-unit raw vector (a diagonal past length 1) is still capped to 1.0 (analog safety).
	var over := GamepadController.resolve_move_dir(Vector2(1.0, 1.0), dz, false)
	assert_almost_eq(over.length(), 1.0, 1e-5, "toggle OFF: over-unit magnitude clamped to 1.0")
	# Contrast the SAME input under the default (true): normalized to unit length. This is the bite —
	# if the branch were ignored, `half` above would read 1.0 and match this.
	assert_almost_eq(GamepadController.resolve_move_dir(Vector2(0.6, 0.0), dz, true).length(), 1.0,
		1e-5, "toggle ON (default): the same 0.6 deflection normalizes to unit length")


func test_panel_and_controller_share_the_same_profile_instance() -> void:  # Story 2-6 (N1, DEBT B adjacency)
	# The instrument panel flips normalize_move_magnitude on the instance it holds via
	# load("res://data/gamepad_profile.tres"); a GamepadController reads the field every tick on the
	# instance the runner passed it (also via load() of the same path). This must not stay an
	# ASSUMPTION: Godot's resource cache returns the SAME object for repeated load() of one path, so
	# the panel and the controller share one instance and the flip is seen. Verified BY CONTENT here
	# (== on Object is reference identity). If this ever fails, the AC-4 toggle silently no-ops.
	const PATH := "res://data/gamepad_profile.tres"
	var a: GamepadProfile = load(PATH)
	var b: GamepadProfile = load(PATH)
	assert_true(a == b, "load() of the same path returns the SAME cached resource instance (reference identity)")
	# A controller built the way the runner builds it holds that exact instance — so the panel's
	# load() and the controller's _profile are one object, and a panel flip reaches sample().
	var controller := GamepadController.new(0, load(PATH))
	assert_true(controller._profile == a,
		"a GamepadController built via load() holds the shared instance the panel mutates")
	# A flip on the panel's handle is visible on the controller's handle (same object).
	var before := a.normalize_move_magnitude
	a.normalize_move_magnitude = not before
	assert_eq(controller._profile.normalize_move_magnitude, not before,
		"flipping the field on one handle is seen on the other — they are the same instance")
	a.normalize_move_magnitude = before  # leave the cached resource as authored (no persistence anyway)


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
