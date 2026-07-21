extends TestCase

## Determinism regression (the executable guard for A1, A2, F2 + the snapshot contract).
## Runs a fixed intent sequence from a fixed seed and asserts the canonical sorted-key hash
## of the resulting state against a golden value. A surprise change means determinism or the
## snapshot shape drifted. Regenerate GOLDEN only for a DELIBERATE state/snapshot change.

const GOLDEN := "253ab157993a57520409e09378822f62814a2bb9c668bb79fe08fd327ec2c832"

const SEED := 1337
const MAX_HP := 120.0
const MOVE_SPEED := 6.0
const MAX_STAMINA := 40.0
const MAX_MANA := 90.0
const SEQ := [
	[Vector2(1, 0), Vector2(-1, 0)],
	[Vector2(0, 1), Vector2(0, -1)],
	[Vector2(1, 1), Vector2(1, 0)],
	[Vector2(-1, 0), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(-1, -1)],
	[Vector2(0.5, 0.5), Vector2(1, 0)],
]


func test_same_seed_and_intents_hash_identically() -> void:
	assert_eq(_run(), _run(), "same seed + intents must produce identical state")


func test_state_matches_golden() -> void:
	assert_eq(_run(), GOLDEN, "state hash drifted from golden — determinism or snapshot shape changed")


func test_canonical_hash_ignores_key_insertion_order() -> void:
	var d1 := {"a": 1, "b": {"x": 1, "y": 2}, "v": Vector3(1, 2, 3)}
	var d2 := {"v": Vector3(1, 2, 3), "b": {"y": 2, "x": 1}, "a": 1}
	assert_eq(CanonicalHash.of(d1), CanonicalHash.of(d2), "sorted-key canonicalization is order-independent")


func _run() -> String:
	var ms := MatchState.new(SEED, MAX_HP, MOVE_SPEED, MAX_STAMINA, MAX_MANA)
	for pair in SEQ:
		var i1 := InputIntent.new()
		i1.move_dir = pair[0]
		var i2 := InputIntent.new()
		i2.move_dir = pair[1]
		var intents: Array[InputIntent] = [i1, i2]
		ms.advance(intents)
		ms.drain_signals()
	return CanonicalHash.of(ms.to_snapshot())
