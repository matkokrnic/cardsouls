extends TestCase

## Story 1-2 coverage: the per-slot camera basis as a pushed spatial fact. Known basis ->
## expected world velocity with pitch ignored (AC 3/5), identity default = exact
## world-space pass-through (AC 4), per-slot isolation (AC 2), and exclusion from the
## snapshot/determinism contract. Headless — bases are pushed directly, never via a scene.

const SPEED := 5.0


## Story 3-1 (AC 3): move_speed reaches the hero ONLY through apply_balance() now that the
## constructor carries no tunables, so this fixture injects the SPEED every assertion below
## reads. Nothing else about the file changes — the bases are still pushed directly.
func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = SPEED
	c.max_stamina = 50.0
	ms.apply_balance(c)
	ms.drain_signals()
	return ms


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
## STORY 4-6 (AC 2) REPLACES `test_facing_is_world_space_under_yaw_and_raw_under_identity`, whose
## claim -- facing is the camera-rotated `world_dir` the velocity uses -- this story deliberately
## FALSIFIES. The old name is recorded here verbatim so the Fence Inventory stays greppable.
##
## WHAT REPLACES IT IS THE SPLIT ITSELF, which is the stronger assertion of the two: velocity keeps
## deriving from camera-relative input through `_camera_bases`, while facing derives from the
## PUSHED LOCK DIRECTION and is independent of the basis entirely. Both halves are driven in ONE
## run so a change that re-coupled them fails here rather than passing two tests that never meet.
##
## MUTATION PROOF: point the facing write back at `world_dir` and P1's facing reads (-1, 0) -- the
## basis-rotated value -- instead of the pushed (0.6, 0.8), and this fails on the first assertion.
func test_facing_follows_the_pushed_lock_direction_not_the_camera_rotated_move() -> void:
	var ms := _make_match()
	ms.set_camera_basis(0, Basis(Vector3.UP, PI / 2.0))
	# A lock direction that is on NEITHER the raw intent's axis nor the basis-rotated one, so a
	# regression to either source lands on a different value rather than coinciding with this.
	ms.set_lock_direction(0, Vector2(0.6, 0.8))
	ms.set_lock_direction(1, Vector2(-0.6, -0.8))
	_step(ms, Vector2(0, -1), Vector2(1, 0))  # p1 camera-forward intent; p2 identity basis
	# The VELOCITY half is unchanged: camera yawed +90 deg, camera forward (-Z cam) = world -X.
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(-SPEED, 0, 0)),
		"velocity still follows the camera basis -- AC 2 splits facing off, it does not move movement")
	assert_true(ms.p2.hero.velocity.is_equal_approx(Vector3(SPEED, 0, 0)),
		"identity basis: the raw intent passes through as world space, unchanged")
	# The FACING half is target-derived and basis-blind.
	assert_true(ms.p1.hero.facing.is_equal_approx(Vector2(0.6, 0.8)),
		"facing is the pushed LOCK direction, not the basis-rotated world_dir the velocity used")
	assert_true(ms.p2.hero.facing.is_equal_approx(Vector2(-0.6, -0.8)),
		"...and the same under an identity basis: facing never consults the basis at all")


## Story 4-6 (AC 2): the zero-guard MOVED from the movement input to the pushed FACT, and both
## halves of that move are pinned here.
##   (a) NO MOVEMENT, LOCK PUSHED -> facing still tracks the target. This is the whole point of
##       AC 2: a hero strafing or standing still keeps facing what it is locked to, which the old
##       `if not dir.is_zero_approx()` guard made impossible.
##   (b) MOVEMENT, NO LOCK PUSHED -> facing is LEFT ALONE at its construction default. Every
##       headless test that drives movement without a lock direction depends on this, and it is
##       the direct analogue of the identity-basis short-circuit above.
func test_facing_tracks_the_lock_with_no_movement_and_freezes_with_no_lock_fact() -> void:
	var ms := _make_match()
	ms.set_lock_direction(0, Vector2(1, 0))
	_step(ms, Vector2.ZERO, Vector2.ZERO)   # (a) not a single unit of movement input
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO), "sanity: P1 really is standing still")
	assert_true(ms.p1.hero.facing.is_equal_approx(Vector2(1, 0)),
		"facing tracks the locked target with ZERO movement input -- the old zero-guard is gone")
	assert_eq(ms.p2.hero.facing, Vector2.DOWN,
		"(b) P2 had no lock direction pushed, so facing is left at its default -- no fact, no write")
	_step(ms, Vector2.ZERO, Vector2(1, 0))  # (b) P2 now MOVES, still with no lock fact
	assert_eq(ms.p2.hero.facing, Vector2.DOWN,
		"...and movement alone still does not turn it: facing is no longer input-derived at all")


func test_basis_is_excluded_from_snapshot() -> void:
	var ms := _make_match()
	var before := ms.to_snapshot()
	ms.set_camera_basis(0, Basis(Vector3.UP, 1.0))
	ms.set_camera_basis(1, Basis(Vector3.UP, -1.0))
	assert_eq(ms.to_snapshot(), before,
		"pushed bases never enter to_snapshot() (input-like fact, X5 contract)")
