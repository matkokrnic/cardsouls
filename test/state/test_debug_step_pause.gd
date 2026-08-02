extends TestCase

## Story 3-0b (AC 1): the DEBUG step/pause input — its Input Map actions, its reader's
## sanctioned shape, and the rule that it is NOT an intent.
##
## The tick-gate behaviour itself (freeze / one-tick-per-press / N steps == N ticks) needs the
## live runner and is covered by test/integration/test_step_pause.gd. What is decidable here,
## headless and without a frame, is the SHAPE — and the shape is the part the readiness gate
## ruled on, so it is pinned:
##   - The two actions exist and are match-global (no p1_/p2_ prefix, unlike debug_reset).
##   - Their keys collide with no other project binding.
##   - DebugInputReader is a NON-Controller: no sample(), no InputIntent. Every other member of
##     src/controllers/ is a Controller; this one is the sanctioned exception, and a future
##     "tidy-up" that makes it a Controller must fail here.
##   - Step/pause never enters InputIntent — the deliberate divergence from debug_reset, which
##     IS intent-carried. An InputIntent field for it would make pause die with ticking.
##
## Input.* in a TEST is fine — INVARIANT D3(a) scopes to src/ (test_controller.gd precedent).

const PAUSE := &"debug_pause"
const STEP := &"debug_step"


func test_debug_pause_and_step_actions_exist_and_are_match_global() -> void:
	assert_true(InputMap.has_action(PAUSE), "project.godot defines debug_pause")
	assert_true(InputMap.has_action(STEP), "project.godot defines debug_step")
	for action: StringName in [PAUSE, STEP]:
		assert_false(String(action).begins_with("p1_"), "%s is match-global, not per-slot" % action)
		assert_false(String(action).begins_with("p2_"), "%s is match-global, not per-slot" % action)
		assert_false(InputMap.action_get_events(action).is_empty(), "%s has a key bound" % action)


func test_debug_keys_collide_with_no_other_project_binding() -> void:
	# Scoped to the PROJECT's own actions: Godot's built-in ui_* navigation deliberately shares
	# keys with gameplay actions already (p2_move_* are the arrow keys, which are also ui_*), so
	# a scan including them would assert a rule this project does not hold.
	var debug_keys: Dictionary = {}
	for action: StringName in [PAUSE, STEP]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				debug_keys[(event as InputEventKey).physical_keycode] = action
	assert_eq(debug_keys.size(), 2, "one distinct key each for pause and step")
	var collisions: Array[String] = []
	for action: StringName in InputMap.get_actions():
		if action == PAUSE or action == STEP or String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and debug_keys.has((event as InputEventKey).physical_keycode):
				collisions.append("%s vs %s" % [action, debug_keys[(event as InputEventKey).physical_keycode]])
	assert_eq(collisions.size(), 0, "debug key already bound: %s" % ", ".join(collisions))


func test_reader_is_a_non_controller_that_returns_plain_booleans() -> void:
	var reader := DebugInputReader.new()
	# Asserted through the SCRIPT chain, not `is Controller`: the two types are statically
	# incompatible, so GDScript rejects that expression at parse time — which is itself the
	# strongest possible form of this guarantee, and this assertion is what makes a future
	# "tidy-up" into a Controller fail loudly here rather than silently compile.
	assert_null(reader.get_script().get_base_script(),
		"the step/pause reader extends RefCounted directly — deliberately NOT a Controller "
		+ "(3-0b readiness-gate ruling)")
	assert_false(reader.has_method("sample"),
		"it must not implement sample() — step/pause is not an intent")
	assert_eq(typeof(reader.pause_pressed()), TYPE_BOOL, "pause_pressed returns a plain bool")
	assert_eq(typeof(reader.step_pressed()), TYPE_BOOL, "step_pressed returns a plain bool")


func test_reader_lives_under_src_controllers() -> void:
	# D3(a) confines Input.* to src/controllers/ and is machine-checked by
	# test_architecture_invariants.gd — but only for files that are THERE. Moving this reader out
	# would move an Input.* reader out of the guarded folder, so its home is pinned.
	var script: Script = DebugInputReader.new().get_script()
	assert_true(script.resource_path.begins_with("res://src/controllers/"),
		"the step/pause reader must stay under src/controllers/, got %s" % script.resource_path)


## ROUTING only. The reader reports EDGES (is_action_just_pressed), and an edge is defined
## against the frame counter — which never moves in this harness (state tests run inside
## _initialize() with no frame, by design). So "the press decays after one frame", the property
## that makes one press advance exactly one tick, is asserted where frames exist:
## test/integration/test_step_pause.gd. What IS decidable here is that each action reaches its
## own accessor and neither is cross-wired to the other — the mistake that would silently make
## the step key toggle pause.
func test_reader_routes_each_action_to_its_own_accessor() -> void:
	var reader := DebugInputReader.new()
	assert_false(reader.pause_pressed(), "neutral")
	assert_false(reader.step_pressed(), "neutral")

	Input.action_press(PAUSE)
	assert_true(reader.pause_pressed(), "the pause press reaches pause_pressed()")
	assert_false(reader.step_pressed(), "the pause key is NOT the step key")
	Input.action_release(PAUSE)

	Input.action_press(STEP)
	assert_true(reader.step_pressed(), "the step press reaches step_pressed()")
	Input.action_release(STEP)


func test_step_pause_never_enters_the_input_intent() -> void:
	# The divergence from debug_reset, asserted from both sides.
	var fields: Array[String] = []
	for property: Dictionary in InputIntent.new().get_property_list():
		fields.append(String(property["name"]))
	assert_true(fields.has("debug_reset"), "debug_reset IS intent-carried (story 1-7, D-2)")
	for banned in ["debug_pause", "debug_step", "paused", "step"]:
		assert_false(fields.has(banned),
			"InputIntent must carry no %s field — pause must survive the absence of ticking, "
			% banned + "which an intent consumed inside advance() cannot")

	Input.action_press(PAUSE)
	Input.action_press(STEP)
	var intent := KeyboardController.new(&"p1").sample()
	Input.action_release(PAUSE)
	Input.action_release(STEP)
	assert_false(intent.debug_reset, "the debug keys are not the reset key")
	for key: StringName in [PAUSE, STEP, &"pause", &"step"]:
		assert_false(intent.pressed.has(key), "%s must not reach the intent's pressed map" % key)
		assert_false(intent.held.has(key), "%s must not reach the intent's held map" % key)
