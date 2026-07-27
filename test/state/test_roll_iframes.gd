extends TestCase

## Story 1-9 coverage: the step-4 iframe FACT DROP (1-9/R1 — pre-dedupe, the DEAD-drop
## family), the +1 resolution grace tick on the roll_iframe window (1-9/R2), window-alone
## judgment (1-9/R3), and the entry-locked roll displacement (1-9/R6).
##
## Test balance: the test_block_deflect.gd shape (windup 3, active 4 — one swing = windup
## t1-3, active t4-7), damage 6% of 100 = 6.0 per hit, melee_hit_mana 8.0, roll iframe 2
## ticks / duration 5 ticks, roll_distance 1.5 -> roll speed 1.5 / (5/60) = 18.0 u/s.
##
## Window timeline convention (the deflect precedent): an N-tick window started by a press
## on t1 covers resolutions t1..tN, closes in t(N+1)'s step 2 — so t(N+1) is the +1 GRACE
## tick (the transient) and t(N+2) is the first full-damage arrival. For the 2-tick iframe
## pressed t1: covered arrivals t1-t2, grace t3, full damage from t4. In FACT-ARRIVAL
## terms per 1-9/R2's shifted span: the t3 arrival models the physically-last iframe tick;
## t4 models the first post-iframe tick.

const ROLL_SPEED := 1.5 / (5.0 / 60.0)  # 18.0


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0           # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.attack_move_speed_multiplier = 0.0
	c.melee_hit_mana = 8.0
	c.block_damage_multiplier = 0.25
	c.deflect_stamina_cost = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 1.5
	return c


func _make_match(config: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
	ms.apply_balance(config if config != null else _config())
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	ms.inject_feature_flags(f)
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed: Array = [], move := Vector2.ZERO) -> InputIntent:
	var i := InputIntent.new()
	i.move_dir = move
	for k in pressed:
		i.pressed[k] = true
		i.held[k] = true
	return i


func _step(ms: MatchState, i1: InputIntent = null, i2: InputIntent = null) -> void:
	var intents: Array[InputIntent] = [
		i1 if i1 != null else InputIntent.new(),
		i2 if i2 != null else InputIntent.new(),
	]
	ms.advance(intents)
	ms.drain_signals()


func _collect_hits(ms: MatchState, into: Array) -> void:
	ms.hit_landed.connect(func(attacker: int, target: int, damage: float, hp: float) -> void:
		into.append([attacker, target, damage, hp]))


## ---- The iframe drop: negation while the window runs (1-9/R1) ---------------------------

func test_contact_during_running_iframe_is_dropped() -> void:
	var ms := _make_match()
	var hits: Array = []
	_collect_hits(ms, hits)
	# t1: P1 rolls (iframe covers t1-t2), P2 starts a swing (record 0 opens at the press).
	_step(ms, _intent([&"roll"]), _intent([&"attack"]))
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t2: iframe still running -> FACT DROP
	assert_eq(ms.p1.hero.get_hp(), 100.0, "contact during running iframe is dropped — no damage")
	assert_eq(hits.size(), 0, "no hit_landed on a dropped fact")
	assert_eq(ms.p2.mana.get_current(), 0.0, "no mana on a dropped fact")


## ---- The negation boundary pair, SAME swing (1-9/R2 + the drop-not-register pin) --------
## A fact arriving on close+1 (t3 — the grace transient; physically the last iframe tick)
## NEGATES; a fact arriving on close+2 (t4) from the SAME swing deals FULL damage. The t4
## landing is simultaneously the iframe-drop-precedes-dedupe pin: had the t3 fact
## registered the swing-hit (resolution semantics), the t4 fact would be a same-swing
## duplicate and could never land.

func test_negation_boundary_grace_then_full_same_swing() -> void:
	var ms := _make_match()
	var hits: Array = []
	_collect_hits(ms, hits)
	_step(ms, _intent([&"roll"]), _intent([&"attack"]))  # t1
	_step(ms)                                            # t2
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t3: window closed in THIS tick's step 2 -> +1 grace -> negated
	assert_eq(ms.p1.hero.get_hp(), 100.0, "close+1 arrival negates via the grace transient")
	assert_eq(ms.p2.mana.get_current(), 0.0, "negated: no mana")
	assert_eq(hits.size(), 0, "negated: no hit_landed")
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t4: past the grace -> the SAME swing lands at full damage
	assert_eq(ms.p1.hero.get_hp(), 94.0,
		"close+2 arrival from the SAME swing lands FULL damage — the drop never registered")
	assert_eq(hits, [[1, 0, 6.0, 94.0]], "the landed hit is an ordinary confirmed hit")
	assert_eq(ms.p2.mana.get_current(), 8.0, "and pays full flat mana")


## ---- Window-alone judgment (1-9/R3): grace can outlive ROLLING itself -------------------
## With iframe == duration (5 ticks, the audit-bound equality edge), both windows close in
## t6's step 2; step 3 exits ROLLING -> IDLE that same tick, and the t6 fact arrival must
## STILL negate via the transient — negation is judged on the window alone, never on
## state == ROLLING (a state-AND-window check would clip exactly this contact).

func test_grace_negates_after_rolling_ended_window_alone() -> void:
	var c := _config()
	c.roll_iframe_seconds = 5.0 / 60.0  # == roll_duration: the equality edge
	var ms := _make_match(c)
	_step(ms, _intent([&"roll"]))                 # t1: windows cover t1-t5
	_step(ms, null, _intent([&"attack"]))         # t2: P2 swing (windup t2-4, active t5-8)
	for t in range(3, 6):
		_step(ms)                                 # t3-t5
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t6: duration closed -> IDLE; iframe grace transient still negates
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "ROLLING already exited on t6")
	assert_eq(ms.p1.hero.get_hp(), 100.0, "grace-tick negation while IDLE — window-alone judgment")
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t7: past the grace -> lands
	assert_eq(ms.p1.hero.get_hp(), 94.0, "first post-grace arrival lands full damage")


## ---- Entry-locked displacement (1-9/R6) -------------------------------------------------

func test_roll_direction_from_move_dir_normalized_and_locked() -> void:
	var ms := _make_match()
	# Diagonal press: the (1, 1) intent is clamped then normalized — the stored direction
	# is UNIT so the roll speed is exactly roll_distance / roll_duration_seconds.
	_step(ms, _intent([&"roll"], Vector2(1, 1)))  # t1
	var expected_dir := Vector3(1, 0, 1).normalized()
	assert_true(ms.p1.hero.roll_direction.is_equal_approx(expected_dir),
		"roll_direction is the normalized world move_dir captured at entry")
	assert_true(ms.p1.hero.velocity.is_equal_approx(expected_dir * ROLL_SPEED),
		"ROLLING velocity = locked direction x (roll_distance / roll_duration_seconds)")
	_step(ms, _intent([], Vector2(0, -1)))        # t2: mid-roll input must steer NOTHING
	assert_true(ms.p1.hero.velocity.is_equal_approx(expected_dir * ROLL_SPEED),
		"mid-roll input changes neither direction nor speed — direction locked")
	for t in range(3, 6):
		_step(ms, _intent([], Vector2(0, -1)))    # t3-t5: rolling through
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "rolling through t5")
	_step(ms, _intent([], Vector2(0, -1)))        # t6: duration done -> IDLE
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "IDLE on t6 (5-tick roll)")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(0, 0, -5.0)),
		"after the roll, velocity is input-driven again at move_speed")


func test_roll_direction_facing_fallback_when_neutral() -> void:
	var ms := _make_match()
	_step(ms, _intent([], Vector2(1, 0)))   # t1: establish facing (1, 0)
	_step(ms, _intent([&"roll"]))           # t2: neutral-stick roll
	assert_true(ms.p1.hero.roll_direction.is_equal_approx(Vector3(1, 0, 0)),
		"neutral stick falls back to the hero's world-space facing")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(ROLL_SPEED, 0, 0)),
		"fallback direction drives the roll velocity")


func test_roll_direction_uses_camera_basis() -> void:
	var ms := _make_match()
	ms.set_camera_basis(0, Basis(Vector3.UP, PI / 2.0))
	_step(ms, _intent([&"roll"], Vector2(0, -1)))  # camera-forward press
	# camera yawed +90 deg: camera forward (-Z cam) = world -X (the 1-2 mapping).
	assert_true(ms.p1.hero.roll_direction.is_equal_approx(Vector3(-1, 0, 0)),
		"roll direction is captured CAMERA-ROTATED, like the velocity mapping")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(-ROLL_SPEED, 0, 0)),
		"and the roll velocity follows the rotated direction")


## ---- CONSTRAINT C under a mid-roll reload -----------------------------------------------
## In-flight WINDOWS keep their duration (the 1-1 reload principle) while the SPEED reads
## inline at the moment of use — a mid-roll reload changes the velocity on the next tick
## but neither the iframe boundary nor the roll length.

func test_mid_roll_reload_windows_keep_duration_speed_reads_inline() -> void:
	var ms := _make_match()
	_step(ms, _intent([&"roll"], Vector2(1, 0)), _intent([&"attack"]))  # t1
	var reloaded := _config()
	reloaded.roll_distance = 3.0            # speed 18 -> 36, inline
	reloaded.roll_iframe_seconds = 4.0 / 60.0   # in-flight window must KEEP its 2 ticks
	ms.apply_balance(reloaded)
	ms.drain_signals()
	_step(ms)  # t2
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(3.0 / (5.0 / 60.0), 0, 0)),
		"mid-roll velocity reads the NEW roll_distance inline (CONSTRAINT C)")
	_step(ms)  # t3 (old iframe's grace tick — not tested here; boundary is t4)
	ms.push_contact(1, 0, 0, Vector2.DOWN)
	_step(ms)  # t4: under the reloaded 4-tick iframe this would be covered — it must LAND
	assert_eq(ms.p1.hero.get_hp(), 94.0,
		"in-flight iframe kept its 2 ticks across the reload — the t4 arrival lands")
	_step(ms)  # t5: duration also kept its 5 ticks
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "still rolling through t5")
	_step(ms)  # t6
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "roll length unchanged by the reload")


## ---- Substrate re-verification pins (AC 1 / AC 7) ---------------------------------------

func test_roll_during_active_frames_dropped() -> void:
	var ms := _make_match()
	_step(ms, _intent([&"attack"]))  # t1: windup t1-3, active t4-7
	for t in range(2, 5):
		_step(ms)                    # t2-t4
	_step(ms, _intent([&"roll"]))    # t5: active is non-cancellable
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING,
		"roll dropped during active frames (1-3 table, re-verified)")
	assert_eq(ms.p1.hero.attack_phase(), &"active", "still mid-active — nothing buffered")


func test_snapshot_gains_roll_direction_and_excludes_the_transient() -> void:
	var ms := _make_match()
	_step(ms, _intent([&"roll"], Vector2(1, 0)))
	var snap := ms.p1.hero.to_snapshot()
	assert_true(snap.has("roll_direction"), "roll_direction is the one 1-9 snapshot delta")
	assert_eq(snap["roll_direction"], Vector3(1, 0, 0), "snapshot carries the locked value")
	assert_false(snap.has("_roll_iframe_closed_this_tick"),
		"the grace transient stays OUT of the snapshot (per-tick, write-before-read)")
