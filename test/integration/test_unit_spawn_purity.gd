extends SceneTree

## Story 4-3e (AC 9): THE PLACEMENT HELPER IS A PURE FUNCTION OF ITS ARGUMENTS -- two assertions,
## BOTH EFFECTS (two measured position lists compared), neither an identifier read.
##
##   (i) REPEATABILITY. Called twice with identical arguments, `_compute_spawn_positions` returns
##       exactly the same positions -- exact equality, not equality within an epsilon.
##
##  (ii) ORDER INDEPENDENCE. Called with the SAME OCCUPANCY SET IN A DIFFERENT ORDER, it returns
##       the same positions.
##
## (ii) IS A CHEAP REGRESSION PIN, NOT A STRONG PROPERTY TEST, and saying so is the point of this
## paragraph. The natural implementation -- and the shipped one -- tests each candidate against
## EVERY entry of the occupancy list and accepts the first that clears them all. That is a
## CONJUNCTION over the whole list, and a conjunction is order-independent BY CONSTRUCTION, so this
## pin normally passes on the first try and proves nothing about today's code. It exists to bite
## LATER: if someone reads `occupied[0]`, breaks out of the occupancy loop early and uses the
## survivor, or otherwise lets array position matter, this is what notices.
##
## WHAT THIS PAIR DOES NOT COVER, stated rather than implied. The machine check for
## `randf`/`randi`/`Time`/`OS`/`Engine` reads is D3(b)/A2, and it scans `src/state/` ONLY --
## `match_runner.gd` lives in `src/main/` and is NOT scanned by it. A `randf()` added to the
## placement code trips NO guard; assertion (i) would catch it only probabilistically, and a
## `Time`/frame-counter read would very likely slip past it entirely, since both calls here sit in
## one frame. The rest of AC 9's purity list is held by CODE REVIEW, not by this file.
##
## `null` HOLES ARE NOT TESTED HERE AND CANNOT BE: the caller inside `_spawn_missing_unit_actors`
## filters them with `is_instance_valid()` while building the list, so a hole never reaches the
## helper. Arrival ORDER is the only thing left that could vary between two runs, which is why (ii)
## replaced the hole-rearrangement assertion this story's earlier drafts carried.
##
## NO TREE, NO FRAME, NO `_ready`. That is only possible BECAUSE the helper is pure: it reads no
## scene tree and holds no node reference, so a bare `MatchRunner` instance is enough to call it.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_spawn_purity.gd

const RUNNER_PATH := "res://src/main/match_runner.gd"

## main.tscn's authored hero pair (`main.tscn:30,34`), P1 summoning.
const HERO := Vector3(-3.0, 1.0, 0.0)
const OPPONENT := Vector3(3.0, 1.0, 0.0)
const SLOT := 0
## More than one, so the in-batch clearing path is exercised too. Unreachable through play at
## `d3854ff` (AC 4) -- this is not a claim that a card can produce it, only the helper's own N loop.
const BATCH := 3

var _failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _describe(positions: Array) -> String:
	var parts: Array[String] = []
	for p: Vector3 in positions:
		parts.append("(%.6f, %.6f, %.6f)" % [p.x, p.y, p.z])
	return "[" + ", ".join(parts) + "]"


## Exact, element-by-element. Deliberately NOT `is_equal_approx`: the claim is that the same inputs
## produce the SAME BITS, and a tolerance would let a drifting computation pass.
func _identical(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if (a[i] as Vector3) != (b[i] as Vector3):
			return false
	return true


func _initialize() -> void:
	var runner: Node3D = load(RUNNER_PATH).new() as Node3D
	if runner == null:
		print("could not instantiate %s" % RUNNER_PATH)
		print("RESULT: FAIL")
		quit(1)
		return

	# A CROWDED REAR, so the search genuinely WALKS instead of accepting ring 0 on every call. Both
	# heroes are occupants (AC 3), and the base spot plus its first ring are stuffed with bodies --
	# an occupancy list a repeat call could only match by being deterministic all the way through
	# the walk, not merely in its first branch.
	var base_spot := Vector3(HERO.x - runner.SPAWN_BEHIND_DISTANCE, 0.0, HERO.z)
	var occupied: Array[Vector3] = [
		HERO,
		OPPONENT,
		base_spot,
		base_spot + Vector3(-runner.SPAWN_RING_STEP, 0.0, 0.0),
		base_spot + Vector3(0.0, 0.0, runner.SPAWN_RING_STEP),
		base_spot + Vector3(0.0, 0.0, -runner.SPAWN_RING_STEP),
	]

	var first: Array = runner._compute_spawn_positions(occupied, HERO, OPPONENT, SLOT, BATCH)
	var second: Array = runner._compute_spawn_positions(occupied, HERO, OPPONENT, SLOT, BATCH)

	# The same SET in a different ORDER -- reversed, so no entry keeps its index.
	var reordered_input: Array[Vector3] = []
	for i: int in occupied.size():
		reordered_input.append(occupied[occupied.size() - 1 - i])
	var reordered: Array = runner._compute_spawn_positions(
			reordered_input, HERO, OPPONENT, SLOT, BATCH)

	runner.free()

	# --- NON-VACUITY, before either purity claim. ---
	# Three things, each of which would make the comparisons below trivially true: the helper must
	# return the batch it was asked for; the members must be DISTINCT (three copies of one spot
	# would compare equal in every direction and prove nothing); and the walk must have LEFT the
	# base spot, or the whole ring machinery is untested and only its first branch is repeatable.
	_check(first.size() == BATCH,
		"helper returned %d positions for a batch of %d" % [first.size(), BATCH])
	if first.size() == BATCH:
		var distinct := true
		for i: int in BATCH:
			for j: int in range(i + 1, BATCH):
				if (first[i] as Vector3) == (first[j] as Vector3):
					distinct = false
		_check(distinct, "batch members are not distinct positions: %s" % _describe(first))
		var walked: bool = (first[0] as Vector3).distance_to(base_spot) > 0.001
		_check(walked, ("the search accepted the OCCUPIED base spot %s - the crowding setup did "
				+ "not force a walk, so this file's repeatability claim is near-vacuous")
				% str(base_spot))

	# --- (i) REPEATABILITY: identical arguments, identical positions. ---
	_check(_identical(first, second),
		"two calls with identical arguments returned different positions:\n    %s\n    %s"
			% [_describe(first), _describe(second)])

	# --- (ii) ORDER-INDEPENDENCE PIN: same occupancy SET, different order. ---
	_check(_identical(first, reordered),
		("reversing the occupancy list changed the result - something reads the list "
			+ "POSITIONALLY:\n    %s\n    %s") % [_describe(first), _describe(reordered)])

	print("unit_spawn_purity: batch=%d occupied=%d spots=%s"
		% [BATCH, occupied.size(), _describe(first)])
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
