extends TestCase

## Story 1-2 coverage: the per-slot camera basis as a pushed spatial fact. Known basis ->
## expected world velocity with pitch ignored (AC 3/5), identity default = exact
## world-space pass-through (AC 4), per-slot isolation (AC 2), and exclusion from the
## snapshot/determinism contract. Headless — bases are pushed directly, never via a scene.

const SPEED := 5.0


func _make_match() -> MatchState:
	return MatchState.new(7, 100.0, SPEED, 50.0, 80.0)


func _step(ms: MatchState, d1: Vector2, d2: Vector2 = Vector2.ZERO) -> void:
	var i1 := InputIntent.new()
	i1.move_dir = d1
	var i2 := InputIntent.new()
	i2.move_dir = d2
	var intents: Array[InputIntent] = [i1, i2]
	ms.advance(intents)
	ms.drain_signals()


func test_no_basis_pushed_is_world_space() -> void:
	var ms := _make_match()
	_step(ms, Vector2(1, 0))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(SPEED, 0, 0)),
		"identity default: move_dir passes through as world-space (AC 4)")


func test_known_yaw_basis_rotates_move_dir() -> void:
	var ms := _make_match()
	ms.set_camera_basis(0, Basis(Vector3.UP, PI / 2.0))
	_step(ms, Vector2(0, -1))  # camera-forward intent
	# camera yawed +90 deg: camera forward (-Z cam) = world -X
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(-SPEED, 0, 0)),
		"forward intent follows the camera yaw")


func test_pitch_is_ignored() -> void:
	var ms := _make_match()
	var pitched := Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, deg_to_rad(-40.0))
	ms.set_camera_basis(0, pitched)
	_step(ms, Vector2(0, -1))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(-SPEED, 0, 0)),
		"pitch must neither tilt nor shrink movement (yaw-only)")
	assert_eq(ms.p1.hero.velocity.y, 0.0, "never a vertical velocity component")


func test_basis_is_per_slot_not_global() -> void:
	var ms := _make_match()
	ms.set_camera_basis(0, Basis(Vector3.UP, PI / 2.0))  # slot 0 only
	_step(ms, Vector2(0, -1), Vector2(0, -1))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(-SPEED, 0, 0)),
		"p1 resolves through the slot-0 basis")
	assert_true(ms.p2.hero.velocity.is_equal_approx(Vector3(0, 0, -SPEED)),
		"p2 slot untouched -> still world-space (never one global basis, AC 2)")


func test_straight_down_pitch_falls_back_to_world_space() -> void:
	var ms := _make_match()
	# Looking straight down: the back column flattens to zero on XZ (degenerate).
	ms.set_camera_basis(0, Basis(Vector3.RIGHT, -PI / 2.0))
	_step(ms, Vector2(0, -1))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(0, 0, -SPEED)),
		"degenerate basis falls back to world-space, no NaNs")


## Story 1-7 (review R1): facing is WORLD-SPACE planar — it stores the camera-ROTATED
## direction (what the hitbox yaw consumes), never the raw camera-space intent; under an
## identity basis the two coincide and the raw value passes through unchanged.
func test_facing_is_world_space_under_yaw_and_raw_under_identity() -> void:
	var ms := _make_match()
	ms.set_camera_basis(0, Basis(Vector3.UP, PI / 2.0))
	_step(ms, Vector2(0, -1), Vector2(1, 0))  # p1 camera-forward intent; p2 identity basis
	# camera yawed +90 deg: camera forward (-Z cam) = world -X -> facing (-1, 0), NOT (0, -1)
	assert_true(ms.p1.hero.facing.is_equal_approx(Vector2(-1, 0)),
		"facing stores the ROTATED world direction under a yawed basis, not the raw intent")
	assert_true(ms.p2.hero.facing.is_equal_approx(Vector2(1, 0)),
		"identity basis: facing still equals the raw intent direction unchanged")


func test_basis_is_excluded_from_snapshot() -> void:
	var ms := _make_match()
	var before := ms.to_snapshot()
	ms.set_camera_basis(0, Basis(Vector3.UP, 1.0))
	ms.set_camera_basis(1, Basis(Vector3.UP, -1.0))
	assert_eq(ms.to_snapshot(), before,
		"pushed bases never enter to_snapshot() (input-like fact, X5 contract)")
