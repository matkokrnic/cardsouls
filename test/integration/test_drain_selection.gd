extends SceneTree

## Story 6-5b (AC 18/AC 22, `6-5b/R6`): DRAIN'S FACING RULE AND ITS TIE-BREAKS -- the runner's
## `_select_drain_target`, driven directly against hand-placed positions.
##
## IT LIVES HERE RATHER THAN IN THE STATE HARNESS because the rule is the RUNNER's: it reads a hero
## facing and world positions, which `src/state/` owns none of and may not query (D3(b)/A2). State
## receives the already-resolved INDEX through `push_drain_target` and never recomputes it, which is
## exactly why the choice has to be tested where it is made.
##
## NO TREE, NO FRAME, NO `_ready`. That is only possible BECAUSE the helper is pure -- it reads no
## scene tree, holds no node reference and mutates no runner field -- so a bare `MatchRunner` instance
## is enough to call it. The `test_unit_spawn_purity.gd` precedent verbatim, including why that file
## can do the same for `_compute_spawn_positions`.
##
## EVERY CASE BELOW IS A POSITION LAYOUT AND AN EXPECTED INDEX, and the positions are chosen so the
## ANSWER IS OBVIOUS BY GEOMETRY rather than by reproducing the implementation's arithmetic: a minion
## dead ahead, one off to the side, two at equal angle and different distance, and two at identical
## angle AND distance.
##
## AC 22's TWO NAMED CASES ARE THE LAST TWO: "equal angle, different distance" and
## "same angle and distance, lower index wins". Both are exact ties by construction -- mirrored or
## collinear placements, not values that happen to land close -- which is what makes them test the
## TIE-BREAK rather than the ordinary comparison.
##
## Run: godot --headless --path . --script res://test/integration/test_drain_selection.gd

const RUNNER_PATH := "res://src/main/match_runner.gd"

## The hero's own spot and the direction it faces. `facing` is WORLD-SPACE PLANAR (`R1`, locked), so
## it is compared directly against a world-space planar direction with no basis in between.
const HERO := Vector2(0.0, 0.0)
const FACING := Vector2(0.0, -1.0)      # -Z, straight "up" the XZ plane

var _failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## One candidate list, `[[board_index, xz], ...]`, ASCENDING BY INDEX exactly as
## `_gather_drain_target` builds it from the actor array.
func _candidates(entries: Array) -> Array:
	var out: Array = []
	for entry: Array in entries:
		out.append([int(entry[0]), entry[1] as Vector2])
	return out


func _initialize() -> void:
	var runner: Node3D = load(RUNNER_PATH).new() as Node3D
	if runner == null:
		print("could not instantiate %s" % RUNNER_PATH)
		print("RESULT: FAIL")
		quit(1)
		return

	# --- NON-VACUITY FIRST: the helper must actually discriminate. A function that returned the first
	# candidate every time would satisfy several cases below by accident, so the first assertion is
	# that a NON-ZERO index can win at all.
	var behind_first := _candidates([
		[0, Vector2(0.0, 5.0)],      # directly BEHIND the hero: the worst possible angle
		[1, Vector2(0.0, -5.0)],     # directly AHEAD
	])
	_check(runner._select_drain_target(FACING, HERO, behind_first) == 1,
		"NON-VACUITY: the minion AHEAD wins over the one BEHIND even though it is listed second -- "
		+ "the helper discriminates rather than returning the first candidate")

	# --- AC 18: the smallest ANGLE wins, and distance does not override it.
	var ahead_far := _candidates([
		[0, Vector2(4.0, -4.0)],     # 45 degrees off the facing, and CLOSE-ish
		[1, Vector2(0.0, -12.0)],    # dead ahead, three times further away
	])
	_check(runner._select_drain_target(FACING, HERO, ahead_far) == 1,
		"the SMALLEST ANGLE wins even when it is the FURTHEST candidate -- distance is a tie-break, "
		+ "never the primary key (AC 18)")

	var slightly_off := _candidates([
		[0, Vector2(3.0, -1.0)],     # far off to the side
		[1, Vector2(0.2, -5.0)],     # nearly dead ahead
		[2, Vector2(-3.0, -1.0)],    # far off the other side
	])
	_check(runner._select_drain_target(FACING, HERO, slightly_off) == 1,
		"the most directly-faced minion wins from the middle of the list too")

	# --- AC 22, CASE ONE: EQUAL ANGLE, DIFFERENT DISTANCE -> the CLOSER one wins.
	# Both candidates sit on the same ray from the hero, so their angles are identical by
	# construction rather than approximately equal.
	var collinear := _candidates([
		[0, Vector2(3.0, -3.0)],     # on the 45-degree ray, FURTHER
		[1, Vector2(1.0, -1.0)],     # on the SAME ray, CLOSER
	])
	_check(runner._select_drain_target(FACING, HERO, collinear) == 1,
		"AC 22 (equal angle, different distance): the CLOSER minion wins, and it wins from the "
		+ "SECOND position in the list -- so the answer is the tie-break rather than the loop order")
	# ...and the same pair in the opposite listing order still picks the closer one, which is what
	# proves the distance tie-break is a real comparison and not the list order in disguise.
	var collinear_swapped := _candidates([
		[0, Vector2(1.0, -1.0)],     # CLOSER, listed first this time
		[1, Vector2(3.0, -3.0)],
	])
	_check(runner._select_drain_target(FACING, HERO, collinear_swapped) == 0,
		"...and the closer one still wins when it is listed FIRST")

	# --- AC 22, CASE TWO: SAME ANGLE AND SAME DISTANCE -> the LOWER BOARD INDEX wins.
	# A MIRRORED pair: equal and opposite lateral offsets at the same forward distance have exactly
	# equal angles to the facing and exactly equal lengths, so nothing but the index can decide.
	var mirrored := _candidates([
		[0, Vector2(-2.0, -2.0)],
		[1, Vector2(2.0, -2.0)],
	])
	_check(runner._select_drain_target(FACING, HERO, mirrored) == 0,
		"AC 22 (same angle and distance): the LOWER BOARD INDEX wins")
	# ...and swapping which SIDE each index sits on must not change the answer, or the rule would be
	# picking by geometry where it claims to be picking by index.
	var mirrored_swapped := _candidates([
		[0, Vector2(2.0, -2.0)],
		[1, Vector2(-2.0, -2.0)],
	])
	_check(runner._select_drain_target(FACING, HERO, mirrored_swapped) == 0,
		"...whichever side each index happens to be on")

	# --- The defined answers for the degenerate inputs, so each is a decision rather than a crash.
	_check(runner._select_drain_target(FACING, HERO, _candidates([])) == MatchState.NO_DRAIN_TARGET,
		"NO CANDIDATES answers NO_DRAIN_TARGET -- the state side's gate is what refuses the cast")
	_check(runner._select_drain_target(Vector2.ZERO, HERO, mirrored) == MatchState.NO_DRAIN_TARGET,
		"A ZERO FACING has no direction and selects nothing (the `push_contact` zero-direction rule)")
	var co_located := _candidates([
		[0, HERO],                   # standing exactly on the hero: no direction to measure
		[1, Vector2(0.0, -4.0)],
	])
	_check(runner._select_drain_target(FACING, HERO, co_located) == 1,
		"A CO-LOCATED minion has no direction and is SKIPPED, never chosen on a zero vector")

	# --- The rule is a PURE FUNCTION: the same inputs give the same answer, exactly.
	var repeat_a: int = runner._select_drain_target(FACING, HERO, slightly_off)
	var repeat_b: int = runner._select_drain_target(FACING, HERO, slightly_off)
	_check(repeat_a == repeat_b,
		"the helper is REPEATABLE -- a replay re-running the same gather gets the same sacrifice")

	runner.free()

	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		print("  [XX] %s" % failure)
	print("RESULT: FAIL")
	quit(1)
