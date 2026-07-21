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
	assert_true(kc.sample().is_held(&"p1_attack"), "attack held")
	Input.action_release(&"p1_attack")

	# Prefix isolation: p1 controller must not read p2 input.
	Input.action_press(&"p2_move_right")
	assert_true(kc.sample().move_dir.is_zero_approx(), "p1 ignores p2 input")
	Input.action_release(&"p2_move_right")


func test_keyboard_fresh_intent_per_sample() -> void:
	var kc := KeyboardController.new(&"p1")
	assert_ne(kc.sample(), kc.sample(), "fresh instance per sample")
