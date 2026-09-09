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


## ============================================================================================
## STORY 5-0b: the pad card/cast scheme (AC 1-6, AC 9). Every case below drives the PURE
## resolve_card_tick() / resolve_trigger_edge() directly with synthetic raw values -- the same
## reason resolve_move_dir()/resolve_flick() are tested this way above: real joypad reads are not
## headless-samplable, so the DECISION built on top of a raw read is what stays testable.
## ============================================================================================


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


func test_resolve_card_tick_arms_slots_left_to_right() -> void:  # AC 2
	# L2 -> slot 0.
	var r := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.6, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 0, "L2 (trigger crossing) arms slot 0")
	# L1 (block_button) -> slot 1.
	r = GamepadController.resolve_card_tick(true,
		false, false, true, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 1, "L1 (block) arms slot 1")
	# R1 (attack_button) -> slot 2.
	r = GamepadController.resolve_card_tick(true,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 2, "R1 (attack) arms slot 2")
	# R2 -> slot 3.
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.6, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 3, "R2 (trigger crossing) arms slot 3")


func test_resolve_card_tick_same_tick_chord_resolves_rightmost() -> void:  # AC 2 (review fix: docblock-only claim)
	# All four arming inputs pressed the SAME tick (unreachable on real hardware, reachable here) --
	# the docblock claims "last write wins" resolves to the RIGHTMOST button: L2, block(L1),
	# attack(R1), R2 checked in that order, so R2 (rightmost) wins.
	var r := GamepadController.resolve_card_tick(true,
		true, false, true, false, false, false,
		0.6, 0.0, 0.6, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 3, "a same-tick chord of all four arming inputs resolves to slot 3 (rightmost)")


func test_resolve_card_tick_trigger_already_held_does_not_rearm() -> void:  # AC 2 (trigger edge case)
	# L2 already past the threshold BOTH this tick and last -> no crossing -> no arm. A trigger
	# pulled before cast mode began must not fire the instant cast mode starts.
	var r := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.9, 0.9, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], -1,
		"trigger already held past threshold does not arm without a fresh crossing")


func test_resolve_card_tick_basic_always_commits_on_fresh_press() -> void:  # AC 3 (review fix: was swallowed)
	# Nothing armed yet; a FRESH Basic press still raises a commit, carrying card_slot -1 -- the
	# keyboard's exact parity: the controller never swallows the commit, it reaches state (which
	# refuses it via the empty_slot path, Hand.is_slot_empty(-1) == true).
	var r := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, false, false, false, false, 0.5, -1)
	assert_true(r["card_commit"], "a fresh Basic press ALWAYS raises a commit, even with nothing armed")
	assert_eq(r["card_slot"], -1, "the commit carries slot -1, unarmed -- state refuses it, not the controller")
	assert_eq(r["armed_slot"], -1, "still nothing armed")

	# Arm slot 2 (R1) and commit with Basic in the SAME tick (no separate confirm on the pad).
	r = GamepadController.resolve_card_tick(true,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, false, false, false, false, 0.5, -1)
	assert_eq(r["armed_slot"], 2, "R1 arms slot 2")
	assert_true(r["card_commit"], "Basic commits the newly-armed slot in the same tick")
	assert_eq(r["card_slot"], 2, "commit carries the armed slot")

	# Basic merely held (not a fresh press) -> no commit at all.
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, true, false, false, false, false, 0.5, 1)
	assert_false(r["card_commit"], "Basic held (not freshly pressed) does not commit")


## ============================================================================================
## STORY 5-7: B and X confirm modes ② and ③ (AC 1-2, AC 6-9, AC 15). Extended IN PLACE rather than
## split into a sibling file: this is the same pure `resolve_card_tick()` contract 5-0b built the
## coverage shape for directly above, and AC 6 asks for the SAME test shape rather than a new,
## differently-shaped guarantee -- which a second file would quietly become.
## ============================================================================================


## AC 2, REPLACING 5-0b's retired `test_gamepad_controller_never_reads_x_or_y_face_buttons`. That
## test asserted the source text of `gamepad_controller.gd` contains neither `JOY_BUTTON_X` nor
## `JOY_BUTTON_Y` -- and 5-0b's own close-out accepted (decision-log :8316-8318) that it catches
## only the INLINE-LITERAL regression form. It would now pass BY ACCIDENT: X is wired live this
## story and still never appears as a literal here, because the raw index lives on `GamepadProfile`
## and is read as `_profile.<field>`. A guard that a shipped feature satisfies while asserting
## something no longer true is worse than none.
##
## So the MECHANISM is replaced, not the pattern widened (`3-0d/R20`): Y is unreadable BY
## CONSTRUCTION because NO `GamepadProfile` field carries its index. `GamepadController` reads
## joypad buttons through exactly one route -- `_profile.<some>_button` -- so if no authored button
## field equals `JOY_BUTTON_Y`, no read of Y is expressible at all, and `card_mode` can never become
## PITCH (ordinal 3), whose state arm is a deliberate crash-on-reach. The source scan is kept
## alongside as the cheap second net, narrowed to Y alone.
func test_no_authored_button_maps_to_y_so_pitch_is_structurally_unreachable() -> void:  # AC 2
	# (a) BY CONSTRUCTION: every authored button field, on BOTH the defaults and the shipped .tres.
	for profile: GamepadProfile in [GamepadProfile.new(), load("res://data/gamepad_profile.tres")]:
		var button_fields: Array[String] = []
		for p in profile.get_property_list():
			var name := String(p["name"])
			if name.ends_with("_button"):
				button_fields.append(name)
		assert_true(button_fields.size() >= 8,
			"sanity: the scan really found the button fields, so an emptied list cannot pass "
			+ "vacuously (found %d: %s)" % [button_fields.size(), ", ".join(button_fields)])
		for name in button_fields:
			assert_ne(profile.get(name), JOY_BUTTON_Y,
				"no GamepadProfile button field may carry JOY_BUTTON_Y -- Y is the ONE face button "
				+ "left unwired, and that is what keeps mode ④ PITCH (a crash-on-reach stub) "
				+ "structurally unreachable from the pad (%s)" % name)
	# (b) THE CHEAP SECOND NET: no inline literal either.
	var f := FileAccess.open("res://src/controllers/gamepad_controller.gd", FileAccess.READ)
	assert_true(f != null,
		"gamepad_controller.gd must be openable for the source scan (FileAccess error %d)"
				% FileAccess.get_open_error())
	if f == null:
		return
	assert_false(f.get_as_text().contains("JOY_BUTTON_Y"),
		"gamepad_controller.gd must never read JOY_BUTTON_Y as an inline literal either")


## AC 1: B commits UNBLOCKABLE and X commits DEFENSE on the armed slot, in ONE press-edge press --
## `cast_basic_button`'s shape exactly, no separate confirm step. AC 15's other half is here too:
## the returned `card_mode` is what `sample()` writes onto the intent, so BASIC is no longer
## hardcoded.
func test_resolve_card_tick_b_commits_unblockable_and_x_commits_defense() -> void:  # AC 1/AC 15
	# B, with slot 2 armed by R1 in the same tick (no separate confirm on the pad).
	var r := GamepadController.resolve_card_tick(true,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, false, false, false, 0.5, -1)
	assert_true(r["card_commit"], "a fresh B press commits")
	assert_eq(r["card_slot"], 2, "...the slot R1 armed this same tick")
	assert_eq(r["card_mode"], Enums.ModeKind.UNBLOCKABLE, "B selects mode ② UNBLOCKABLE")

	# X, with slot 0 armed by an L2 crossing in the same tick.
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.6, 0.0, 0.0, 0.0,
		false, false, false, false, true, false, 0.5, -1)
	assert_true(r["card_commit"], "a fresh X press commits")
	assert_eq(r["card_slot"], 0, "...the slot L2 armed this same tick")
	assert_eq(r["card_mode"], Enums.ModeKind.DEFENSE, "X selects mode ③ DEFENSE")

	# A still commits BASIC, unchanged by this story (AC 8's "does not touch A's existing path").
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, false, false, false, false, 0.5, 3)
	assert_true(r["card_commit"], "A still commits")
	assert_eq(r["card_mode"], Enums.ModeKind.BASIC, "...and still as BASIC")

	# HELD, not freshly pressed -> no commit from either new button (PRESS-edge, not hold).
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, true, true, true, 0.5, 1)
	assert_false(r["card_commit"],
		"B and X merely HELD (not freshly pressed) commit nothing -- both are press-edge")

	# Nothing pressed at all while cast is held -> no commit, and `card_mode` is never read.
	r = GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, 1)
	assert_false(r["card_commit"], "no confirm pressed -> no commit")


## AC 1's negative half, on the Basic review-fix precedent verbatim: a confirm press with NOTHING
## armed still RAISES the commit carrying slot -1, so it reaches the state-side `empty_slot`
## refusal instead of being swallowed in the controller. Both new buttons, identically.
func test_resolve_card_tick_mode_confirms_commit_empty_slot_rather_than_swallow() -> void:  # AC 1
	var b := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, false, false, false, 0.5, -1)
	assert_true(b["card_commit"], "a fresh B press ALWAYS raises a commit, even with nothing armed")
	assert_eq(b["card_slot"], -1, "the commit carries slot -1 -- state refuses it, not the controller")
	assert_eq(b["card_mode"], Enums.ModeKind.UNBLOCKABLE, "...still carrying B's mode")

	var x := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, true, false, 0.5, -1)
	assert_true(x["card_commit"], "a fresh X press ALWAYS raises a commit, even with nothing armed")
	assert_eq(x["card_slot"], -1, "the commit carries slot -1 -- state refuses it, not the controller")
	assert_eq(x["card_mode"], Enums.ModeKind.DEFENSE, "...still carrying X's mode")


## AC 1/AC 2: B and X commit NOTHING outside cast mode -- their new meaning exists ONLY while
## `cast_held`. This is what keeps AC 4's roll escape (release L3, then press B) intact: on the
## tick after release, B is a roll and nothing else.
func test_mode_confirms_do_nothing_outside_cast_mode() -> void:  # AC 1/AC 4
	var r := GamepadController.resolve_card_tick(false,
		false, false, false, false, true, false,   # B is physically down: roll_raw fresh too
		0.0, 0.0, 0.0, 0.0,
		true, false, true, false, true, false, 0.5, 2)
	assert_false(r["card_commit"], "no confirm commits while cast mode is not held")
	assert_eq(r["armed_slot"], -1, "and the armed slot clears the same tick cast mode is inactive")
	assert_true(r["roll_pressed"],
		"B outside cast mode is a ROLL, unchanged by this story -- the 5-0b escape sequence "
		+ "does not need to know B now does something during cast mode (AC 4)")


## AC 9: a same-tick A/B/X chord resolves to AT MOST ONE commit, deterministically. The chosen
## order is the face cluster's physical left-to-right (X, A, B) with last-write-wins -- the SAME
## rule AC 2's four-slot arming chord already resolves by -- so the RIGHTMOST button, B, wins.
## Unreachable on real hardware; pinned anyway because the golden/replay contract needs an answer.
func test_resolve_card_tick_same_tick_confirm_chord_resolves_rightmost() -> void:  # AC 9
	var triple := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, true, false, true, false, 0.5, 1)
	assert_true(triple["card_commit"], "the chord commits")
	assert_eq(triple["card_mode"], Enums.ModeKind.UNBLOCKABLE,
		"A+B+X the same tick resolves to B (rightmost) -- UNBLOCKABLE")
	assert_eq(triple["card_slot"], 1, "...on the already-armed slot, once")

	# The two PAIRS, so the order is pinned at every edge and not just at the triple.
	var ax := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, false, false, true, false, 0.5, 1)
	assert_eq(ax["card_mode"], Enums.ModeKind.BASIC, "A+X resolves to A (right of X) -- BASIC")
	var bx := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, false, true, false, 0.5, 1)
	assert_eq(bx["card_mode"], Enums.ModeKind.UNBLOCKABLE, "B+X resolves to B -- UNBLOCKABLE")
	var ab := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false, true, false, false, false, 0.5, 1)
	assert_eq(ab["card_mode"], Enums.ModeKind.UNBLOCKABLE, "A+B resolves to B -- UNBLOCKABLE")


## AC 6: the exit-edge rule, in the SAME shape `test_resolve_card_tick_exit_edge_sequences` gives
## the existing four inputs -- a button already physically held when the edge that matters arrives
## produces no press edge; it must be released and freshly pressed again before it can confirm.
func test_mode_confirm_exit_edge_sequences() -> void:  # AC 6
	for is_defense in [false, true]:
		var label := "X/DEFENSE" if is_defense else "B/UNBLOCKABLE"
		var mode: int = Enums.ModeKind.DEFENSE if is_defense else Enums.ModeKind.UNBLOCKABLE
		# (a) HELD THROUGH CAST-MODE ENTRY: the button was already down before L3 went down, so it
		# is held-not-pressed on the first cast tick -> no commit.
		var entry := GamepadController.resolve_card_tick(true,
			false, false, false, false, false, false,
			0.0, 0.0, 0.0, 0.0,
			false, false,
			not is_defense, not is_defense, is_defense, is_defense, 0.5, 2)
		assert_false(entry["card_commit"],
			"%s already held as cast mode is entered fires no commit" % label)

		# (b) HELD THROUGH CAST-MODE EXIT AND RE-ENTRY: still held across the release and across the
		# next entry -> still no commit, exactly as (a).
		var exited := GamepadController.resolve_card_tick(false,
			false, false, false, false, false, false,
			0.0, 0.0, 0.0, 0.0,
			false, false,
			not is_defense, not is_defense, is_defense, is_defense, 0.5, entry["armed_slot"])
		assert_false(exited["card_commit"], "%s cannot commit outside cast mode at all" % label)
		var reentered := GamepadController.resolve_card_tick(true,
			false, false, false, false, false, false,
			0.0, 0.0, 0.0, 0.0,
			false, false,
			not is_defense, not is_defense, is_defense, is_defense, 0.5, 2)
		assert_false(reentered["card_commit"],
			"%s held through the exit and the next entry STILL fires no commit" % label)

		# (c) RELEASED, THEN FRESHLY PRESSED: registers normally, one commit.
		var released := GamepadController.resolve_card_tick(true,
			false, false, false, false, false, false,
			0.0, 0.0, 0.0, 0.0,
			false, false,
			false, not is_defense, false, is_defense, 0.5, 2)
		assert_false(released["card_commit"], "%s released this tick -> no commit" % label)
		var fresh := GamepadController.resolve_card_tick(true,
			false, false, false, false, false, false,
			0.0, 0.0, 0.0, 0.0,
			false, false,
			not is_defense, false, is_defense, false, 0.5, 2)
		assert_true(fresh["card_commit"],
			"a fresh %s press the tick after release commits normally" % label)
		assert_eq(fresh["card_mode"], mode, "...carrying its own mode")


## AC 7: the neutral/no-device path primes EVERY card-scheme `_prev_*` entry HELD, not cleared, so a
## replug cannot arm-and-commit with no new press. The two new commit edges join that same set --
## a reconnect must not be able to spend a card via UNBLOCKABLE or DEFENSE any more than via BASIC.
## Reachable headless precisely because the harness has no joypad, so `sample()` takes this path.
func test_replug_priming_covers_the_new_commit_edges() -> void:  # AC 7
	var c := GamepadController.new(0, _profile())
	c.sample()  # the neutral path (no device bound in the harness)
	for key: StringName in [GamepadController._CAST_BASIC_KEY,
			GamepadController._CAST_UNBLOCKABLE_KEY, GamepadController._CAST_DEFENSE_KEY]:
		assert_true(c._prev_held.get(key, false),
			("`%s` is primed HELD by the neutral path, so a replug with that button already down "
			+ "reads no fresh press and commits nothing") % key)
	assert_eq(c._prev_l2, 1.0, "the trigger prevs are primed HELD too (5-0b, unchanged)")
	assert_eq(c._prev_r2, 1.0, "...both of them")
	assert_eq(c.armed_slot(), -1, "and nothing stays armed across the neutral path")
	# The prime is what a commit needs to be refused: fed straight back into the decision with the
	# button still down, no commit comes out.
	var r := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, c._prev_l2, 0.0, c._prev_r2,
		true, c._prev_held.get(GamepadController._CAST_BASIC_KEY, false),
		true, c._prev_held.get(GamepadController._CAST_UNBLOCKABLE_KEY, false),
		true, c._prev_held.get(GamepadController._CAST_DEFENSE_KEY, false),
		0.5, -1)
	assert_false(r["card_commit"],
		"a replug with L3 + every confirm button already held commits nothing")
	assert_eq(r["armed_slot"], -1, "...and arms nothing either")


## AC 8: this story adds NO suppression rule. B's UNBLOCKABLE meaning lives INSIDE the branch that
## was already suppressing attack/block/roll, so a cast-mode B press commits mode ② and throws no
## roll -- and the suppression of all three is bit-for-bit what 5-0b shipped.
func test_mode_confirms_add_no_suppression_rule() -> void:  # AC 8
	var r := GamepadController.resolve_card_tick(true,
		true, false, true, false, true, false,   # attack/block/roll all freshly pressed
		0.0, 0.0, 0.0, 0.0,
		false, false, true, false, false, false, 0.5, -1)
	assert_false(r["roll_held"], "roll still suppressed while cast is held (5-0b, untouched)")
	assert_false(r["roll_pressed"], "roll press still suppressed while cast is held")
	assert_false(r["attack_held"], "attack still suppressed")
	assert_false(r["attack_pressed"], "attack press still suppressed")
	assert_false(r["block_held"], "block still suppressed")
	assert_false(r["block_pressed"], "block press still suppressed")
	assert_true(r["card_commit"], "...and the SAME physical B press commits mode ② instead")
	assert_eq(r["card_mode"], Enums.ModeKind.UNBLOCKABLE, "B's cast-mode meaning, not a roll")
	assert_eq(r["armed_slot"], 2, "R1's arming edge is untouched by any of it")


## AC 10: the four-slot arming chord and its "resolves rightmost" pin are UNTOUCHED -- this story
## adds no arming input. Re-asserted against the SAME chord 5-0b pinned, now with the two new
## confirm buttons also down, which must change the arming answer not at all.
func test_arming_chord_is_untouched_by_the_new_confirm_buttons() -> void:  # AC 10
	var r := GamepadController.resolve_card_tick(true,
		true, false, true, false, false, false,
		0.6, 0.0, 0.6, 0.0,
		false, false, true, false, true, false, 0.5, -1)
	assert_eq(r["armed_slot"], 3,
		"the arming chord still resolves to slot 3 (rightmost) with B and X also pressed")


## STORY 6-1 (AC 1/2/5): THE HOLD FACT mode ②'s chargeup reads, and THE L3-CHORD FORK, pinned.
##
## The story named the fork and required the dev pass to pick one and add a direct test for exactly
## this case: L3 (`cast_button`) released while B (`cast_unblockable_button`) stays held partway
## through a chargeup. THE PICK IS B ALONE — `card_cast_held` is `unblockable_raw` and is NOT
## conjoined with `cast_held`, so letting go of the ARMING modifier cannot destroy an already-paid
## attack. Row 3 below is that decision; without it, `card_cast_held` would read false there and a
## thumb slipping off L3 would feint.
##
## The other two rows are what make row 3 a decision rather than a tautology: the key follows B's
## raw state in both directions, and neither of the OTHER two confirms can stand in for it.
func test_resolve_card_tick_reports_the_unblockable_confirm_as_held() -> void:  # Story 6-1
	# B held, inside cast mode: the ordinary mid-chargeup tick.
	var held := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, true, false, false, 0.5, 2)
	assert_true(held["card_cast_held"], "B still down -> the chargeup's confirm reads HELD")

	# B released: the fact goes false the same tick, no edge and no latch (CONSTRAINT C).
	var released := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, true, false, false, 0.5, 2)
	assert_false(released["card_cast_held"],
		"B up -> released on that very tick, read live rather than derived from an edge")

	# THE FORK: L3 released, B still down. The confirm still reads HELD.
	var l3_gone := GamepadController.resolve_card_tick(false,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, true, true, false, false, 0.5, 2)
	assert_true(l3_gone["card_cast_held"],
		"releasing L3 while B stays held does NOT feint — the hold belongs to the confirm that "
		+ "committed the attack, not to the arming modifier whose job ended at the commit")
	assert_eq(l3_gone["armed_slot"], -1,
		"...while L3's OWN product still clears the same tick it releases (AC 1 of 5-0b, "
		+ "unchanged) — which is precisely why the two facts must not be conjoined")

	# The other two confirms are not substitutes: A and X held, B up, still released.
	var wrong_buttons := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, true, false, false, true, true, 0.5, 2)
	assert_false(wrong_buttons["card_cast_held"],
		"a held BASIC or DEFENSE confirm cannot keep a mode ② chargeup alive — only B can")


func test_resolve_card_tick_suppresses_attack_block_roll_while_cast_held() -> void:  # AC 4/AC 5
	var r := GamepadController.resolve_card_tick(true,
		true, false, true, false, true, false,  # attack/block/roll all freshly pressed
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_false(r["attack_held"], "attack suppressed on the intent while cast is held")
	assert_false(r["attack_pressed"], "attack press suppressed while cast is held")
	assert_false(r["block_held"], "block suppressed on the intent while cast is held")
	assert_false(r["block_pressed"], "block press suppressed while cast is held")
	assert_false(r["roll_held"], "roll suppressed on the intent while cast is held")
	assert_false(r["roll_pressed"], "roll press suppressed while cast is held")
	# Suppression is on the emitted intent fields ONLY -- the same L1/R1 edges still arm slots
	# (AC 2). R1 (attack) is the rightmost of {block, attack} pressed here, so it wins.
	assert_eq(r["armed_slot"], 2,
		"attack(R1)'s edge still arms slot 2 even though its own intent action is suppressed")


func test_resolve_card_tick_restores_attack_block_roll_the_tick_after_release() -> void:  # AC 4
	# Tick N: cast held, R1 pressed -> arms slot 2, attack suppressed on the intent.
	var t1 := GamepadController.resolve_card_tick(true,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_false(t1["attack_held"], "attack suppressed while cast is held")

	# Tick N+1: cast_button released, but R1 is STILL physically held through the release -> no
	# press edge fires (AC 4's held-through-exit rule), while `held` reads live-play truth.
	var t2 := GamepadController.resolve_card_tick(false,
		true, true, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, t1["armed_slot"])
	assert_false(t2["attack_pressed"], "R1 held through cast_button's release fires no press edge")
	assert_true(t2["attack_held"], "R1 still reads held (live-play truth) once cast mode is inactive")
	assert_eq(t2["armed_slot"], -1, "armed slot clears the same tick cast mode exits")

	# Tick N+2: R1 is released...
	var t3 := GamepadController.resolve_card_tick(false,
		false, true, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, t2["armed_slot"])
	# ...then Tick N+3: R1 is freshly pressed again -> registers as a normal attack press.
	var t4 := GamepadController.resolve_card_tick(false,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, t3["armed_slot"])
	assert_true(t4["attack_pressed"], "a fresh press the tick after release registers normally")


func test_resolve_card_tick_clears_armed_slot_the_same_tick_cast_releases() -> void:  # AC 1
	var t1 := GamepadController.resolve_card_tick(true,
		true, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_eq(t1["armed_slot"], 2, "R1 arms slot 2 while cast is held")
	var t2 := GamepadController.resolve_card_tick(false,
		true, true, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, t1["armed_slot"])
	assert_eq(t2["armed_slot"], -1,
		"armed slot clears the SAME tick cast_button releases, no released-edge delay")


func test_resolve_card_tick_exit_edge_sequences() -> void:  # AC 5 (review fix: trivial-only coverage)
	# (a) HELD-THROUGH-EXIT: the tick cast_held goes false, roll_raw true AND prev_roll_raw true
	# (the button was already down before AND through the release) -> no press edge, roll does not
	# fire on release of a button that was merely held through it. Same case for attack.
	var roll_exit := GamepadController.resolve_card_tick(false,
		false, false, false, false, true, true,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_false(roll_exit["roll_pressed"], "roll held through cast_button's release fires no press edge")
	assert_true(roll_exit["roll_held"], "roll still reads held (live-play truth) once cast mode is inactive")

	var attack_exit := GamepadController.resolve_card_tick(false,
		true, true, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_false(attack_exit["attack_pressed"], "attack held through cast_button's release fires no press edge")
	assert_true(attack_exit["attack_held"], "attack still reads held once cast mode is inactive")

	# (b) SAME-TICK ESCAPE: cast_held false, roll_raw true and prev_roll_raw false -- B is pressed
	# the SAME tick L3 releases, so the release edge is honoured before B is read as a mode button,
	# and roll fires (the roll-escape idiom this test originally pinned).
	var same_tick := GamepadController.resolve_card_tick(false,
		false, false, false, false, true, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_true(same_tick["roll_pressed"], "release-then-press B on the same tick registers a real roll")

	# (c) FRESH PRESS THE TICK AFTER RELEASE: B released one tick, then freshly pressed the next
	# -> registers as a normal roll press.
	var released := GamepadController.resolve_card_tick(false,
		false, false, false, false, false, true,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_false(released["roll_pressed"], "B released this tick -> no press edge")
	var fresh_press := GamepadController.resolve_card_tick(false,
		false, false, false, false, true, false,
		0.0, 0.0, 0.0, 0.0,
		false, false, false, false, false, false, 0.5, -1)
	assert_true(fresh_press["roll_pressed"], "a fresh B press the tick after release registers normally")


func test_card_scheme_and_lock_on_paths_are_disjoint() -> void:  # AC 6 (review fix: was tautological)
	# Falsifiable source-scan disjointness: the card-scheme code paths (resolve_card_tick() and the
	# card block inside sample()) never reference lock-on state, and _sample_lock_controls() never
	# references card-scheme state. Proven to fall by mutation (a cross-reference added to either
	# side must turn this RED), not by construction like the removed version of this test.
	var f := FileAccess.open("res://src/controllers/gamepad_controller.gd", FileAccess.READ)
	assert_true(f != null,
		"gamepad_controller.gd must be openable for the source scan (FileAccess error %d)"
				% FileAccess.get_open_error())
	if f == null:
		return
	var text := f.get_as_text()

	var resolve_start := text.find("static func resolve_card_tick(")
	var resolve_end := text.find("func armed_slot() -> int:")
	assert_true(resolve_start != -1 and resolve_end != -1 and resolve_end > resolve_start,
		"resolve_card_tick's source region must be found by both markers")
	var resolve_card_tick_src := text.substr(resolve_start, resolve_end - resolve_start)

	var card_block_start := text.find("var cast_held := Input.is_joy_button_pressed")
	var card_block_end := text.find("_sample_lock_controls()")
	assert_true(card_block_start != -1 and card_block_end != -1 and card_block_end > card_block_start,
		"sample()'s card block region must be found by both markers")
	var card_block_src := text.substr(card_block_start, card_block_end - card_block_start)

	for token in ["_lock_pressed", "_flick", "_prev_flick_magnitude"]:
		assert_false(resolve_card_tick_src.contains(token),
			"resolve_card_tick must never reference lock-on state (%s)" % token)
		assert_false(card_block_src.contains(token),
			"sample()'s card block must never reference lock-on state (%s)" % token)

	var lock_start := text.find("func _sample_lock_controls() -> void:")
	var lock_end := text.find("static func resolve_flick(")
	assert_true(lock_start != -1 and lock_end != -1 and lock_end > lock_start,
		"_sample_lock_controls's source region must be found by both markers")
	var lock_src := text.substr(lock_start, lock_end - lock_start)
	for token in ["_armed_slot", "_prev_l2", "_prev_r2", "_CAST_BASIC_KEY"]:
		assert_false(lock_src.contains(token),
			"_sample_lock_controls must never reference card-scheme state (%s)" % token)
