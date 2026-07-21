class_name TestCase
extends RefCounted

## Minimal headless test base (X6 bootstrap — GUT not yet installed). Pure RefCounted so
## tests instantiate state objects directly and assert synchronously; a state test that
## needs a frame or an autoload is a design leak, not a harness limitation (see the E0
## test-harness constraint). Assert names mirror GUT so migration to GutTest is near-free.

var _failures: Array[String] = []
var _assert_count := 0


func failure_count() -> int:
	return _failures.size()


func get_failures() -> Array[String]:
	return _failures


func assert_count() -> int:
	return _assert_count


func assert_true(cond: bool, text := "") -> void:
	_assert_count += 1
	if not cond:
		_fail("assert_true failed" + _suffix(text))


func assert_false(cond: bool, text := "") -> void:
	_assert_count += 1
	if cond:
		_fail("assert_false failed" + _suffix(text))


func assert_eq(got: Variant, expected: Variant, text := "") -> void:
	_assert_count += 1
	if not _deep_eq(got, expected):
		_fail("assert_eq: got %s, expected %s%s" % [got, expected, _suffix(text)])


func assert_ne(got: Variant, other: Variant, text := "") -> void:
	_assert_count += 1
	if _deep_eq(got, other):
		_fail("assert_ne: both %s%s" % [got, _suffix(text)])


func assert_almost_eq(got: float, expected: float, tolerance: float, text := "") -> void:
	_assert_count += 1
	if absf(got - expected) > tolerance:
		_fail("assert_almost_eq: got %s, expected %s +/- %s%s" % [got, expected, tolerance, _suffix(text)])


func assert_null(value: Variant, text := "") -> void:
	_assert_count += 1
	if value != null:
		_fail("assert_null: got %s%s" % [value, _suffix(text)])


func assert_not_null(value: Variant, text := "") -> void:
	_assert_count += 1
	if value == null:
		_fail("assert_not_null failed" + _suffix(text))


func _fail(msg: String) -> void:
	_failures.append(msg)


func _suffix(text: String) -> String:
	return "" if text == "" else " (" + text + ")"


# Godot's == is deep value equality for Dictionary/Array/Vector, reference equality for objects.
static func _deep_eq(a: Variant, b: Variant) -> bool:
	return a == b
