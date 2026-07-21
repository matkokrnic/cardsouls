extends SceneTree

## Headless state-test harness (X6 bootstrap). Discovers test/state/test_*.gd, instantiates
## each (a TestCase), runs every test_* method synchronously in _initialize() — no autoload,
## no frame — and exits nonzero if any assertion failed.
##
## Run:  godot --headless --path . --script res://test/run_state_tests.gd
## In a pipe, read ${PIPESTATUS[0]} (or set -o pipefail) — grep/head must not mask the code.
##
## Requires the global class cache to exist (class_name resolution). If a fresh clone reports
## "Could not find type ...", build it once:  godot --headless --editor --quit --path .

const TEST_DIR := "res://test/state/"


func _initialize() -> void:
	var files := _list_test_files()
	var total := 0
	var failed := 0
	var asserts := 0

	print("=== state tests ===")
	for path in files:
		var script: GDScript = load(path)
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

	print("=== %d tests, %d failed, %d assertions ===" % [total, failed, asserts])
	print("RESULT: %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)


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
