extends TestCase

## Executable guards for the load-bearing architectural invariants (F1, D3a, D3b). These
## carry the same weight as the decisions themselves — scanning src/ here regression-tests
## them in CI, not just by hand. Comments are stripped (cut at first '#') so explanatory
## prose mentioning a banned token never false-positives. (This file lives under test/, not
## src/, so it is never itself scanned.)

func test_single_physics_process_owner() -> void:  # INVARIANT F1
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if line.contains("func _physics_process"):
				if not path.ends_with("src/main/match_runner.gd"):
					offenders.append("%s:%d" % [path, n])
	assert_eq(offenders.size(), 0,
		"func _physics_process only allowed in match_runner: %s" % ", ".join(offenders))


func test_input_only_in_controllers() -> void:  # INVARIANT D3(a)
	var re := RegEx.create_from_string("(^|[^.\\w])Input\\s*\\.")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		if path.contains("/controllers/"):
			continue
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0, "Input.* outside src/controllers/: %s" % ", ".join(offenders))


func test_state_layer_has_no_nondeterministic_source() -> void:  # INVARIANT D3(b) / A2
	var rng := RegEx.create_from_string("(^|[^.\\w])(randf|randi|randf_range|randi_range|randfn|randomize)\\s*\\(")
	var svc := RegEx.create_from_string("(^|[^.\\w])(Time|OS|Engine)\\.")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if rng.search(line) != null or svc.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"nondeterministic source in src/state/ (global RNG / Time / OS / Engine): %s" % ", ".join(offenders))


func test_controller_kind_ordinals_pinned() -> void:  # Story 2-2 (2-2/R4)
	# int-literal callers depend on these ordinals: test_camera_relative.gd writes [0, 1] and
	# every 2-2 smoke flip writes int literals like [3, 2] / [2, 3]. A future reorder would
	# silently change the default that ships — the same "a dependency that exists must bite when
	# broken" principle as the F1/D3 scans above. GAMEPAD is APPENDED so NULL stays ordinal 2.
	# Read the enum off the runner script (it has no class_name to statically type against).
	var runner: GDScript = load("res://src/main/match_runner.gd")
	var consts := runner.get_script_constant_map()
	assert_true(consts.has("ControllerKind"), "match_runner.gd defines the ControllerKind enum")
	var k: Dictionary = consts.get("ControllerKind", {})
	assert_eq(k.get("KEYBOARD_P1"), 0, "KEYBOARD_P1 == 0")
	assert_eq(k.get("KEYBOARD_P2"), 1, "KEYBOARD_P2 == 1")
	assert_eq(k.get("NULL"), 2, "NULL stays ordinal 2 (GAMEPAD appended, not inserted)")
	assert_eq(k.get("GAMEPAD"), 3, "GAMEPAD appended == 3")


## Story 1-10 (AC 6): the cues/ui layer is READ-ONLY (D5 — presentation subscribes,
## never writes). Banned tokens = the state layer's public MUTATOR surface (MatchState,
## HeroState, pool mutators) plus the handle tokens that would make any of it reachable
## (`_match_state`, `MatchState.new`). Read accessors (get_hp, is_deflect_window_open,
## to_snapshot, ...) and the ActionState enum stay legal — the guard is on WRITES, not on
## reads. Generic-looking tokens (spend(, add(, heal(, ...) are kept deliberately: a
## false positive fails loudly at review time and costs a rename; a missed mutator costs
## the D5 direction. Same contains-on-code-lines mechanism as the F1 scan above.
const CUES_LAYER_BANNED_TOKENS: Array[String] = [
	# MatchState mutators + the handles that reach them
	"advance(", "drain_signals(", "push_contact(", "apply_balance(",
	"inject_feature_flags(", "set_camera_basis(", "MatchState.new", "_match_state",
	# HeroState mutators / entry actions
	"take_damage(", "heal(", "set_max_hp(", "set_action_state(", "reject_action(",
	"enter_attack(", "chain_attack(", "enter_roll(", "enter_block(",
	"register_swing_hit(", "tick_timers(",
	# Pool mutators (stamina/mana/orb)
	"spend(", "add(", "refill(", "set_maximum(", "advance_regen(", "reset_all(",
]


func test_cues_layer_never_calls_state_mutators() -> void:  # Story 1-10 (AC 6) / D5
	var targets := _gd_files("res://src/ui/")
	var controller_found := false
	for path in _gd_files("res://src/actors/"):
		if path.ends_with("/telegraph_controller.gd"):
			targets.append(path)
			controller_found = true
	# The named file must exist — a rename would otherwise silently un-guard the layer.
	assert_true(controller_found, "telegraph_controller.gd not found under src/actors/")
	var offenders: Array[String] = []
	for path in targets:
		var n := 0
		for line in _code_lines(path):
			n += 1
			for token in CUES_LAYER_BANNED_TOKENS:
				if line.contains(token):
					offenders.append("%s:%d [%s] %s" % [path, n, token, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"state mutator token in the read-only cues/ui layer: %s" % ", ".join(offenders))


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root + d + "/"))
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out
