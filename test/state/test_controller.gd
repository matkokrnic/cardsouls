extends TestCase

## Item 3(d) coverage: Controller + prefix KeyboardController. Simulates hardware via
## Input.action_press/release (Input.* in a TEST is fine — INVARIANT D3(a) scopes to src/).

func test_base_controller_returns_fresh_intent() -> void:
	var base := Controller.new()
	var intent := base.sample()
	assert_not_null(intent)
	assert_true(intent is InputIntent)
	assert_eq(intent.move_dir, Vector2.ZERO)
	assert_ne(base.sample(), base.sample(), "fresh instance per sample")


func test_keyboard_maps_input_and_isolates_prefix() -> void:
	var kc := KeyboardController.new(&"p1")
	assert_true(kc.sample().move_dir.is_zero_approx(), "neutral")

	Input.action_press(&"p1_move_right")
	assert_true(kc.sample().move_dir.x > 0.5, "right press -> +x")
	Input.action_release(&"p1_move_right")

	Input.action_press(&"p1_attack")
	var s := kc.sample()
	assert_true(s.is_held(&"attack"), "attack held under the prefix-free intent key")
	assert_false(s.held.has(&"p1_attack"), "prefixed keys never enter the intent")
	Input.action_release(&"p1_attack")

	# Prefix isolation: p1 controller must not read p2 input.
	Input.action_press(&"p2_move_right")
	assert_true(kc.sample().move_dir.is_zero_approx(), "p1 ignores p2 input")
	Input.action_release(&"p2_move_right")


## Story 6-8 (AC 7/AC 23): the base Controller's three lock accessors are neutral, so NullController
## and ReplayController inherit "no click, no flick, no rotation" -- a replayed rig never turns.
func test_base_controller_lock_accessors_are_neutral() -> void:
	var base := Controller.new()
	assert_false(base.relock_pressed(), "no click")
	assert_eq(base.retarget_flick(), Vector2.ZERO, "no flick")
	assert_eq(base.camera_rotate(), 0.0, "no rotation")


## Story 6-8 (AC 23): the cycle keys as a flick -- one fresh press is a unit horizontal flick that way,
## both at once are a no-op, and the lock key wins its tick (the pad's R3 suppression, at parity).
func test_keyboard_cycle_keys_resolve_to_a_horizontal_flick() -> void:
	assert_eq(KeyboardController.resolve_cycle_keys(false, true, false), Vector2(1.0, 0.0), "right")
	assert_eq(KeyboardController.resolve_cycle_keys(true, false, false), Vector2(-1.0, 0.0), "left")
	assert_eq(KeyboardController.resolve_cycle_keys(true, true, false), Vector2.ZERO, "both: no direction")
	assert_eq(KeyboardController.resolve_cycle_keys(false, false, false), Vector2.ZERO, "neither")
	assert_eq(KeyboardController.resolve_cycle_keys(false, true, true), Vector2.ZERO,
		"the lock key suppresses a same-tick cycle")


## Story 6-8 (AC 7/AC 23): the rotate keys as the camera axis -- right +1, left -1, both or neither 0.
func test_keyboard_rotate_keys_resolve_to_a_signed_axis() -> void:
	assert_eq(KeyboardController.resolve_rotate_keys(false, true), 1.0, "right turns the view right")
	assert_eq(KeyboardController.resolve_rotate_keys(true, false), -1.0, "left turns it left")
	assert_eq(KeyboardController.resolve_rotate_keys(true, true), 0.0, "both cancel")
	assert_eq(KeyboardController.resolve_rotate_keys(false, false), 0.0, "neither")


## Story 6-8 (AC 23): the lock controls through the REAL Input Map actions, prefix-isolated -- the
## `test_keyboard_maps_input_and_isolates_prefix` shape above. Held rotation is a level; the lock
## and cycle keys are edges, read once per sample.
func test_keyboard_lock_controls_read_their_prefixed_actions() -> void:
	var kc := KeyboardController.new(&"p1")
	kc.sample()
	assert_eq(kc.camera_rotate(), 0.0, "neutral")
	Input.action_press(&"p1_camera_right")
	kc.sample()
	assert_eq(kc.camera_rotate(), 1.0, "p1_camera_right held -> +1")
	Input.action_release(&"p1_camera_right")
	Input.action_press(&"p1_camera_left")
	kc.sample()
	assert_eq(kc.camera_rotate(), -1.0, "p1_camera_left held -> -1")
	Input.action_release(&"p1_camera_left")
	Input.action_press(&"p2_camera_right")
	kc.sample()
	assert_eq(kc.camera_rotate(), 0.0, "p1 ignores p2's rotate key")
	Input.action_release(&"p2_camera_right")
	# THE EDGES, in the one order a headless run can observe. `is_action_just_pressed` is FRAME-scoped
	# and this harness never advances a frame, so a key pressed here stays "just pressed" for the rest
	# of the test even after release -- the cycle edge is therefore read BEFORE the lock key is
	# touched, and the lock key's suppression of it is read after. Release-clears-the-edge is a
	# frame property, covered live in test/integration/test_camera_freedom_live.gd.
	Input.action_press(&"p1_cycle_right")
	kc.sample()
	assert_eq(kc.retarget_flick(), Vector2(1.0, 0.0), "p1_cycle_right pressed -> a right flick")
	assert_false(kc.relock_pressed(), "...and no click")
	Input.action_press(&"p1_lock")
	kc.sample()
	assert_true(kc.relock_pressed(), "p1_lock pressed -> the click edge")
	assert_eq(kc.retarget_flick(), Vector2.ZERO, "...which suppresses the same-tick cycle")
	Input.action_release(&"p1_lock")
	Input.action_release(&"p1_cycle_right")


## Story 6-8 (AC 23/AC 24): THE RATIFIED KEY TABLE, pinned by physical keycode. The action-name pin
## (`SHIPPED_INPUT_ACTIONS`) cannot see a binding moved to a different key, and the collision guard
## cannot see one moved to a free but wrong key; this can. Every event must also be location-generic
## (`"location":0`, AC 24) and carry no modifier.
const RATIFIED_LOCK_KEYS := {
	&"p1_lock": KEY_T, &"p1_camera_left": KEY_F, &"p1_camera_right": KEY_G,
	&"p1_cycle_left": KEY_Z, &"p1_cycle_right": KEY_C,
	&"p2_lock": KEY_KP_5, &"p2_camera_left": KEY_KP_4, &"p2_camera_right": KEY_KP_6,
	&"p2_cycle_left": KEY_KP_1, &"p2_cycle_right": KEY_KP_3,
}


func test_keyboard_lock_controls_ship_on_the_ratified_keys() -> void:
	for action: StringName in RATIFIED_LOCK_KEYS:
		assert_true(InputMap.has_action(action), "%s exists" % action)
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		assert_eq(events.size(), 1, "%s has exactly one binding" % action)
		for e: InputEvent in events:
			var key := e as InputEventKey
			assert_not_null(key, "%s is a key binding" % action)
			if key == null:
				continue
			assert_eq(key.physical_keycode, RATIFIED_LOCK_KEYS[action],
				"%s is on its ratified physical key" % action)
			assert_eq(key.location, KEY_LOCATION_UNSPECIFIED, "%s is location-generic" % action)
			assert_false(key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed,
				"%s needs no modifier" % action)


func test_keyboard_fresh_intent_per_sample() -> void:
	var kc := KeyboardController.new(&"p1")
	assert_ne(kc.sample(), kc.sample(), "fresh instance per sample")
