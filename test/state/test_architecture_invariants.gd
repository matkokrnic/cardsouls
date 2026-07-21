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
