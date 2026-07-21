extends SceneTree

## Headless state-test harness (X6 bootstrap). Discovers test/state/test_*.gd, instantiates
## each (a TestCase), runs every test_* method synchronously in _initialize() — no autoload,
## no frame — and exits nonzero if any assertion failed.
##
## Run:  godot --headless --path . --script res://test/run_state_tests.gd
## In a pipe, read ${PIPESTATUS[0]} (or set -o pipefail) — grep/head must not mask the code.
## Fresh-clone setup (class cache) is in README.md; the harness also prints the remedy if a
## test fails to load.

const TEST_DIR := "res://test/state/"


func _initialize() -> void:
	var files := _list_test_files()
	var total := 0
	var failed := 0
	var asserts := 0
	var load_error := false

	print("=== state tests ===")
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			load_error = true
			print("  [XX] %s — FAILED TO LOAD (parse or class-resolution error)" % path.get_file())
			continue
		var inst: TestCase = script.new()
		for method in _test_methods(inst):
			var before := inst.failure_count()
			inst.call(method)
			total += 1
			if inst.failure_count() > before:
				failed += 1
				print("  [XX] %s::%s" % [path.get_file(), method])
				for f in inst.get_failures().slice(before, inst.failure_count()):
					print("         - " + f)
			else:
				print("  [ok] %s::%s" % [path.get_file(), method])
		asserts += inst.assert_count()

	if load_error:
		_print_cache_remedy()
	print("=== %d tests, %d failed, %d assertions ===" % [total, failed, asserts])
	var ok := failed == 0 and not load_error
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _print_cache_remedy() -> void:
	print("")
	print("!! A test failed to LOAD. If the log above says \"Could not find type ...\", the global")
	print("!! class cache is missing (.godot/global_script_class_cache.cfg is git-ignored and absent")
	print("!! on a fresh clone). Build it once, then re-run the tests:")
	print("!!     godot --headless --editor --quit --path .")


func _list_test_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("run_state_tests: cannot open %s" % TEST_DIR)
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(TEST_DIR + f)
	out.sort()
	return out


func _test_methods(inst: Object) -> Array[String]:
	var seen := {}
	var out: Array[String] = []
	for m in inst.get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and not seen.has(n):
			seen[n] = true
			out.append(n)
	out.sort()
	return out
