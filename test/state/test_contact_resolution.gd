extends TestCase

## Story 1-5 coverage: the basic-attack contact layer. Derived is_hitbox_active over the
## active window, the contact intake seam (push_contact -> step-4 drain), per-swing dedupe
## + the stale-contact boundary BOTH ways (last-active-tick fact accepted one tick late;
## expired record drops), the ONE step-5 mana-generation path behind the injected
## melee_mana_generation flag (matrix ON/OFF + the no-injection null path), the B6
## movement root (velocity scaled uniformly across all three phases, restored on exit,
## facing untouched), the D8 dedupe snapshot, and the flags-are-config snapshot exclusion.
##
## Test balance: the test_action_state.gd shape (windup 3, active 4, recovery 6, chain
## window 5, chain length 3 — one swing = windup t1-3, active t4-7, recovery t8-13, IDLE
## t14), plus max_hp 100 / damage 6% (= 6.0 per hit) and melee_hit_mana 8.0. Flags are
## constructed IN-TEST, never loaded from the authored .tres.


func _config(windup_mult := 0.0, active_mult := 0.0, recovery_mult := 0.0,
		lunge_distance := 0.0) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0          # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.attack_windup_move_speed_multiplier = windup_mult
	c.attack_active_move_speed_multiplier = active_mult
	c.attack_recovery_move_speed_multiplier = recovery_mult
	c.attack_lunge_distance = lunge_distance
	# Story 3-1 (AC 1/AC 3): the mana CAP is authored data now that the constructor carries none.
	# 80.0 is what this fixture's MatchState.new used to supply, so behaviour is unchanged.
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _flags(mana_on: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = mana_on
	return f


## inject_flags=false leaves MatchState.flags null (the pre-injection headless default).
func _make_match(inject_flags := true, mana_on := true, windup_mult := 0.0,
		active_mult := 0.0, recovery_mult := 0.0, lunge_distance := 0.0) -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config(windup_mult, active_mult, recovery_mult, lunge_distance))
	if inject_flags:
		ms.inject_feature_flags(_flags(mana_on))
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed_keys: Array = [], held_keys: Array = [], move := Vector2.ZERO) -> InputIntent:
	var i := InputIntent.new()
	i.move_dir = move
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


## Press attack on tick 1, then advance through tick `through_tick` (inclusive).
func _attack_and_advance_through(ms: MatchState, through_tick: int) -> void:
	_advance(ms, _intent([&"attack"]))  # tick 1
	for t in range(2, through_tick + 1):
		_advance(ms)


## ---- Derived hitbox accessor (AC 2, AC 10) ----------------------------------------------

func test_is_hitbox_active_exactly_on_active_window_ticks() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	assert_false(h.is_hitbox_active(), "no swing -> no hitbox")
	_advance(ms, _intent([&"attack"]))  # tick 1
	for t in range(1, 15):
		if t > 1:
			_advance(ms)
		if t >= 4 and t <= 7:
			assert_true(h.is_hitbox_active(), "hitbox active on active-window tick %d" % t)
		else:
			assert_false(h.is_hitbox_active(), "hitbox NOT active on tick %d" % t)


## ---- Contact -> damage -> mana (AC 3, 5, 6, 10) -----------------------------------------

func test_confirmed_hit_damages_target_and_generates_attacker_mana() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)          # active t4-7
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 5 drains the fact in step 4
	assert_eq(ms.p2.hero.get_hp(), 94.0, "damage = 6% of the TARGET's 100 max HP")
	assert_eq(ms.p1.mana.get_current(), 8.0, "melee_hit_mana accrues to the ATTACKER (flag ON)")
	assert_eq(ms.p1.hero.get_hp(), 100.0, "attacker takes no damage")
	assert_eq(ms.p2.mana.get_current(), 0.0, "target gains no mana")


func test_second_contact_same_swing_same_target_damages_once() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 5: confirmed
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 6: same swing, same target -> dropped
	assert_eq(ms.p2.hero.get_hp(), 94.0, "one swing damages a given target at most once")
	assert_eq(ms.p1.mana.get_current(), 8.0, "mana accrues once per CONFIRMED hit — dupe generates nothing")


func test_chained_swing_is_a_new_record_and_hits_again() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 5: swing 0 confirmed
	for t in range(6, 9):
		_advance(ms)                            # ticks 6-8: through active close, into recovery
	_advance(ms, _intent([&"attack"]))          # tick 9: chain -> swing 1 (active t12-15)
	for t in range(10, 13):
		_advance(ms)                            # ticks 10-12: swing 1 windup, active starts t12
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 13: swing 1 confirmed
	assert_eq(ms.p1.hero.attack_index, 1, "chain claimed a new monotonic attack index")
	assert_eq(ms.p2.hero.get_hp(), 88.0, "a chained swing is a NEW record — same target hit again")
	assert_eq(ms.p1.mana.get_current(), 16.0, "each confirmed hit generated once")


## ---- Stale-contact boundary, both directions (AC 7, 10) ---------------------------------

func test_fact_from_last_active_tick_accepted_one_tick_after_close() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 7)          # t7 = LAST active tick (window closes in t8 step 2)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 8: F1 lag — record in its grace tick
	assert_eq(ms.p2.hero.get_hp(), 94.0, "last-active-tick fact, arriving one tick later, is ACCEPTED")
	assert_eq(ms.p1.mana.get_current(), 8.0, "grace-tick confirmation still generates mana")


func test_fact_after_dedupe_record_expired_is_dropped() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 8)          # t8 consumed the grace tick
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 9: record erased in step 2 -> dropped in step 4
	assert_eq(ms.p2.hero.get_hp(), 100.0, "fact older than the 1-tick grace is DROPPED — no damage")
	assert_eq(ms.p1.mana.get_current(), 0.0, "dropped fact generates nothing")


func test_contact_with_no_swing_ever_started_is_dropped() -> void:
	var ms := _make_match()
	ms.push_contact([0, -1], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)      # no swing exists — no record for index 0
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), 100.0, "unknown attack index -> dropped, no crash")


## ---- Flag matrix (AC 3, 4, 10) ----------------------------------------------------------

func test_flag_off_hit_lands_and_damages_but_mana_stays_zero() -> void:
	var ms := _make_match(true, false)          # melee_mana_generation OFF
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), 94.0, "flag OFF: the hit still lands and damages (graceful degradation)")
	assert_eq(ms.p1.mana.get_current(), 0.0, "flag OFF closes ONLY the faucet")


func test_no_flags_injected_behaves_like_flag_off() -> void:
	var ms := _make_match(false)                # flags never injected (null)
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), 94.0, "no flags: damage still applies")
	assert_eq(ms.p1.mana.get_current(), 0.0, "no flags: the flag-gated faucet stays closed (inert, like the balance null guards)")


func test_flags_object_is_excluded_from_snapshot() -> void:
	var with_flags := _make_match(true)
	var without_flags := _make_match(false)
	for ms: MatchState in [with_flags, without_flags]:
		_advance(ms, _intent([&"attack"], [], Vector2(1, 0)))
		for t in range(2, 6):
			_advance(ms, _intent([], [], Vector2(1, 0)))
	assert_eq(CanonicalHash.of(with_flags.to_snapshot()), CanonicalHash.of(without_flags.to_snapshot()),
		"flags are CONFIG, not state — injection alone must not move the hash (1-2 camera-basis analog)")


## ---- Movement root (AC 8, 10) -----------------------------------------------------------

## Story 3-0b (AC5, DEBT E member 2): the successor to 1-5's
## test_attack_velocity_scaled_uniformly_across_phases_and_restored_on_exit. That test
## pinned the OPPOSITE property — one flat multiplier applied identically in all three
## phases — so it is REPLACED, not kept: the uniformity it guarded is exactly what AC5
## removes. THREE DISTINCT authored values produce THREE DISTINCT velocities, so a
## selector that returned the wrong field (or the same field three times) cannot pass.
## MUTATION PROOF: make _attack_phase_multiplier() return any single field for every
## phase and this FAILS on whichever phases that field does not belong to.
func test_attack_velocity_uses_per_phase_multipliers_and_restores_on_exit() -> void:
	var ms := _make_match(true, true, 0.5, 0.25, 0.75)  # windup / active / recovery
	var h := ms.p1.hero
	var move := _intent([], [], Vector2(1, 0))
	_advance(ms, _intent([&"attack"], [], Vector2(1, 0)))  # tick 1: windup
	assert_eq(h.attack_phase(), &"windup")
	assert_eq(h.velocity, Vector3(2.5, 0.0, 0.0), "windup: 5.0 * its OWN 0.5")
	for t in range(2, 5):
		_advance(ms, move)                      # ticks 2-4: into active
	assert_eq(h.attack_phase(), &"active")
	assert_eq(h.velocity, Vector3(1.25, 0.0, 0.0), "active: 5.0 * its OWN 0.25 — not windup's")
	for t in range(5, 9):
		_advance(ms, move)                      # ticks 5-8: into recovery
	assert_eq(h.attack_phase(), &"recovery")
	assert_eq(h.velocity, Vector3(3.75, 0.0, 0.0), "recovery: 5.0 * its OWN 0.75 — not active's")
	for t in range(9, 15):
		_advance(ms, move)                      # ticks 9-14: recovery done -> IDLE on t14
	assert_eq(h.action_state, HeroState.ActionState.IDLE)
	assert_eq(h.velocity, Vector3(5.0, 0.0, 0.0), "full speed restored on exit from ATTACKING")


## Story 3-0b (AC5): the three phases are INDEPENDENTLY addressable — a non-zero windup
## beside a rooted active/recovery moves the hero for the windup ticks ALONE. Complements
## the three-distinct-values test above by pinning the ZERO direction too: a selector that
## leaked windup's value into the later phases passes that test's shape but fails here.
func test_per_phase_multipliers_are_independent() -> void:
	var ms := _make_match(true, true, 1.0, 0.0, 0.0)    # windup free, active/recovery rooted
	var h := ms.p1.hero
	var move := _intent([], [], Vector2(1, 0))
	_advance(ms, _intent([&"attack"], [], Vector2(1, 0)))
	assert_eq(h.velocity, Vector3(5.0, 0.0, 0.0), "windup 1.0: full speed while ATTACKING")
	for t in range(2, 5):
		_advance(ms, move)
	assert_eq(h.attack_phase(), &"active")
	assert_eq(h.velocity, Vector3.ZERO, "active 0.0: rooted, though windup was free")
	for t in range(5, 9):
		_advance(ms, move)
	assert_eq(h.attack_phase(), &"recovery")
	assert_eq(h.velocity, Vector3.ZERO, "recovery 0.0: rooted, though windup was free")


func test_authored_zero_multiplier_is_full_root_but_facing_untouched() -> void:
	var ms := _make_match()                     # all three multipliers 0.0 — the authored design
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"], [], Vector2(1, 0)))
	assert_eq(h.velocity, Vector3.ZERO, "0.0 = full root: velocity zeroed while ATTACKING")
	_advance(ms, _intent([], [], Vector2(0, 1)))
	assert_eq(h.velocity, Vector3.ZERO, "still rooted mid-windup")
	assert_eq(h.facing, Vector2(0, 1), "facing updates from the camera-rotated world_dir (1-7 R1) — identity basis here so it coincides with raw intent; the multiplier scales VELOCITY only")


## ---- Attack lunge (story 3-0b, AC6) -----------------------------------------------------
## Authored 0.35 over a 7-tick swing span (windup 3 + active 4 = 7/60 s) = 3.0 u/s, chosen so
## the expected speed is a round number. All three phase multipliers stay 0.0 and the move
## intent stays ZERO throughout, so world_dir is zero and the observed velocity IS the lunge
## term alone — nothing to disentangle. A zero move intent also freezes facing at its
## Vector2.DOWN initial value, so the lunge direction is +Z for the whole swing.

const LUNGE_SPEED := 3.0     # 0.35 units / (7/60 s)


func test_attack_lunge_is_live_in_windup_and_active_only() -> void:
	var ms := _make_match(true, true, 0.0, 0.0, 0.0, 0.35)
	var h := ms.p1.hero
	var lunge := Vector3(0.0, 0.0, LUNGE_SPEED)      # facing DOWN -> world +Z
	_advance(ms, _intent([&"attack"], [], Vector2.ZERO))
	assert_eq(h.attack_phase(), &"windup")
	assert_true(h.velocity.is_equal_approx(lunge),
		"windup: the swing carries the hero forward though the move intent is ZERO and the multiplier roots it")
	for t in range(2, 5):
		_advance(ms)                                 # ticks 2-4: into active
	assert_eq(h.attack_phase(), &"active")
	assert_true(h.velocity.is_equal_approx(lunge), "active: still committed forward")
	for t in range(5, 9):
		_advance(ms)                                 # ticks 5-8: into recovery
	assert_eq(h.attack_phase(), &"recovery")
	assert_true(h.velocity.is_equal_approx(Vector3.ZERO),
		"recovery: NO lunge — the ruled phase scope (commitment into the swing, not drift out of it)")
	for t in range(9, 15):
		_advance(ms)                                 # ticks 9-14: recovery done -> IDLE on t14
	assert_eq(h.action_state, HeroState.ActionState.IDLE)
	assert_true(h.velocity.is_equal_approx(Vector3.ZERO), "IDLE: no residual lunge after the swing")


## The lunge follows HeroState.facing (world-space planar since 1-7/R1), not a fixed axis —
## a term hardcoded to +Z would pass the test above and fail here. Also pins that the lunge
## ADDS to the steered velocity rather than replacing it: multiplier 1.0 with a live move
## intent must show BOTH terms.
func test_attack_lunge_follows_facing_and_adds_to_steered_velocity() -> void:
	var ms := _make_match(true, true, 1.0, 0.0, 0.0, 0.35)
	var h := ms.p1.hero
	# Story 4-6 (AC 2): what TURNS the hero east is now the pushed lock direction, not the move
	# input. The claim under test is unchanged -- the lunge tracks `facing`, whatever writes it --
	# and the tick-order property it rests on is unchanged too: facing is still written AFTER
	# velocity inside the same `_resolve_movement`, so tick 1 still lunges along the pre-tick
	# DOWN facing while the steered term already reads (1, 0).
	ms.set_lock_direction(0, Vector2(1, 0))
	_advance(ms, _intent([&"attack"], [], Vector2(1, 0)))
	assert_true(h.velocity.is_equal_approx(Vector3(5.0, 0.0, LUNGE_SPEED)),
		"windup mult 1.0: steered 5.0 on +X PLUS the lunge on the pre-tick facing — additive, not a replacement")
	assert_eq(h.facing, Vector2(1, 0), "facing turned east on that same tick -- from the LOCK")
	# Tick 2 holds the same intent: the lunge has picked the new facing up.
	_advance(ms, _intent([], [], Vector2(1, 0)))
	assert_true(h.velocity.is_equal_approx(Vector3(5.0 + LUNGE_SPEED, 0.0, 0.0)),
		"lunge now runs along the NEW facing (+X) — it tracks facing, never a fixed axis")


## AC6's headline constraint: the lunge is a STATE-SIDE velocity term, never root motion.
## This is the executable half of that claim — the state harness runs with NO scene, NO
## AnimationPlayer and NO actor (test/run_state_tests.gd drives MatchState in _initialize(),
## the E0 no-frame rule), so a lunge observed HERE cannot have come from an animation sample
## by construction. The static half (src/state/ never names a root-motion API) is
## test_architecture_invariants.gd::test_state_layer_never_extracts_root_motion.
## MUTATION PROOF: delete the lunge term from _resolve_movement and this FAILS — velocity
## stays ZERO, with no animation anywhere to supply displacement in its place.
func test_attack_lunge_is_state_side_with_no_animation_present() -> void:
	var ms := _make_match(true, true, 0.0, 0.0, 0.0, 0.35)
	# No lock direction is pushed, so facing stays at its DOWN default -- which is what the
	# expected +Z lunge below reads. Stated rather than left implicit now that facing has a
	# second possible source (story 4-6, AC 2).
	_advance(ms, _intent([&"attack"], [], Vector2.ZERO))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(0.0, 0.0, LUNGE_SPEED)),
		"displacement is computed by MatchState from authored balance data alone — no rig, no clip, no sampling")


## ---- Dedupe snapshot (AC 7, D8) ---------------------------------------------------------

func test_swing_dedupe_tracking_is_snapshotted_mid_swing() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms)                                # tick 5: hit on the books, swing mid-flight
	var snap: Dictionary = ms.p1.hero.to_snapshot()
	assert_true(snap.has("swing_dedupe"), "mid-swing dedupe state is snapshotted (D8)")
	assert_eq(int(snap["swing_dedupe"]["attack_index"]), 0, "monotonic counter snapshotted")
	var records: Dictionary = snap["swing_dedupe"]["records"]
	assert_true(records.has(0), "live record for swing 0 present")
	# STORY 4-3a (AC 3, `4-3a/R16`): the hit list holds TARGET ADDRESSES, not bare slots -- the
	# dedupe key widened from `[attack_index, slot]` to `[attack_index, slot, index]`, and `-1` is
	# the hero's index half. This pin moves because the STORY moved it, and it is one of this
	# story's two PREDICTED golden causes -- and the one that measured a NON-MOVER. The record is
	# deep-copied into the snapshot, but every record in the golden's fixture has expired and been
	# erased by its hash tick, so the widened key has nothing to hash THERE. THIS test is where the
	# shape change is actually observable, because this fixture hashes MID-SWING.
	assert_eq(records[0]["hit"], [[1, -1]],
		"the confirmed target ADDRESS is on the record -- slot 1, index -1 (that slot's hero)")


## ---- Dead attacker (story 2-3, AC3/AC4, 2-3/R6) -----------------------------------------

## A DEAD attacker delivers nothing: the step-4 attacker-liveness drop sits at the same
## PRE-DEDUPE rung as the target DEAD drop, ahead of the iframe drop and register_swing_hit.
## The in-flight window is NOT stopped or shortened (1-9/R3 intact) — killed during the active
## window, its record stays live — but the corpse's fact resolves to nothing: no damage, no
## hit_landed, no mana, no deflect signal, and attack_index / the swing's one resolution are
## untouched (register_swing_hit is never reached).
##
## SUPERSESSION de-vacuization (E2-CO/R4, executes E3-P/R4): the 2-6 step-1b freeze makes this
## branch unreachable through advance() (a DEAD attacker implies _round_over, and step 1b returns
## before step 4 drains the queue). So this pins the _resolve_contacts CONTRACT directly. Setup
## drives a REAL in-flight active window via advance(); the attacker is then forced DEAD DIRECTLY
## (not via a kill, so _round_over stays FALSE — a state advance() cannot produce), and the fact
## is resolved by calling _resolve_contacts() directly, feeding its result to the step-5 mana
## seat. MUTATION: delete the `if attacker ... DEAD: continue` drop and this FAILS — the corpse's
## fact resolves into damage, a hit_landed, and a confirmed hit (step-5 mana).
func test_dead_attacker_in_flight_window_delivers_nothing() -> void:
	var ms := _make_match()
	_attack_and_advance_through(ms, 4)          # P1 ATTACKING, active window open (t4-7), live swing
	assert_true(ms.p1.hero.is_hitbox_active(), "attacker's active window is open before death")
	var atk := ms.p1.hero.attack_index
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD directly; _round_over stays FALSE
	assert_false(bool(ms.to_snapshot()["round_over"]),
		"hand-constructed: DEAD attacker with _round_over FALSE")
	# STORY 5-6 (AC 11): THE SUBJECT MOVES FROM THE DERIVED PREDICATE TO THE WINDOW ITSELF, and the
	# claim is unchanged. What this line has always asserted is that death does NOT early-stop an
	# in-flight window (1-9/R3) — `active.is_running` says exactly that, and says it about the window
	# rather than about a predicate that has since gained a second conjunct.
	# `is_hitbox_active()` now ALSO requires `ATTACKING`, so a corpse (or a stunned attacker, AC 9)
	# reports no hitbox even while its window runs. That is the ORPHANED-SWING hole closing, asserted
	# positively on the line below rather than silently inverting this one.
	assert_true(ms.p1.hero.active.is_running,
		"the in-flight active window keeps ticking after death (1-9/R3 intact)")
	assert_false(ms.p1.hero.is_hitbox_active(),
		"...but it no longer reports a live hitbox, because the hero is not ATTACKING (5-6 AC 11) — "
		+ "the runner stops querying the instant `action_state` leaves ATTACKING, whatever the reason")
	assert_eq(ms.p1.hero.attack_index, atk, "swing index unchanged by death")
	var hits := {"n": 0}
	ms.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: hits.n += 1)
	var deflects := {"n": 0}
	ms.deflect_landed.connect(func(_a: int, _t: int, _c: int) -> void: deflects.n += 1)
	var p2_hp_before := ms.p2.hero.get_hp()
	var p1_mana_before := ms.p1.mana.get_current()
	ms.push_contact([0, -1], [1, -1], atk, Vector2.DOWN, MatchState.CONTACT_STRIKE)    # a fact SOURCED from the DEAD attacker
	var confirmed := ms._resolve_contacts()     # DIRECT step call — no advance(), no step 1b
	ms._generate_mana(confirmed)                # the step-5 seat, fed the step-4 result
	ms.drain_signals()
	assert_eq(confirmed.size(), 0, "DEAD-attacker fact is not a confirmed hit — nothing for step 5")
	assert_eq(ms.p2.hero.get_hp(), p2_hp_before, "no damage — a dead attacker's fact delivers nothing")
	assert_eq(ms.p1.mana.get_current(), p1_mana_before, "no mana for a dead attacker (flag was ON)")
	assert_eq(hits.n, 0, "no hit_landed emitted for a dead attacker")
	assert_eq(deflects.n, 0, "no deflect_landed emitted for a dead attacker")
	assert_eq(ms.p1.hero.attack_index, atk, "attack_index untouched (register_swing_hit never reached)")
	var snap: Dictionary = ms.p1.hero.to_snapshot()
	assert_true(bool(snap["swing_dedupe"]["records"].has(atk)),
		"the swing's dedupe record is intact — the corpse's fact never consumed the swing's resolution")


## ---- Pre-injection guard ----------------------------------------------------------------

## Story 3-1 (AC 5, 3-1/R3) RE-ANCHORED: the old anchor was the constructor-supplied 100.0
## hp, which no longer exists — a pre-injection hero is stat-less. The anchor is UNCHANGED
## FROM CONSTRUCTION over the whole per-player snapshot, which additionally pins that the
## dropped fact left no dedupe record and cost no stamina.
##
## MUTATION (the round-end half, AC 5's new guard): delete `if balance_ticks == null: return`
## from _check_resolution and this FAILS — a 0-hp stat-less hero ends the round on this very
## tick, flipping round_over and setting the loser DEAD in the snapshot.
func test_contacts_inert_without_apply_balance() -> void:
	var ms := MatchState.new(MatchParams.new(7))  # deliberately NO apply_balance
	var before: Dictionary = ms.to_snapshot()
	ms.push_contact([0, -1], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	var after: Dictionary = ms.to_snapshot()
	assert_false(bool(after["round_over"]), "pre-injection: no round end (AC 5)")
	assert_eq(after["p2"], before["p2"],
		"pre-injection MatchState: step-4 contacts inert — p2 UNCHANGED FROM CONSTRUCTION, no crash")
	assert_eq(after["p1"], before["p1"], "the attacker is likewise untouched (no dedupe record, no spend)")


## ================================================================================================
## STORY 4-3b: the ATTACKER side of the fact — the widened address, the kind dispatch, the signal.
## ================================================================================================

## Board balance for the 4-3b block below. The unit fields the existing `_config()` never authored,
## plus a minion rhythm of 2 / 3 / 4 ticks, all different from the hero's 3 / 4 / 6 in the same
## fixture so a phase read off the wrong field cannot coincide.
func _config_4_3b() -> BalanceConfig:
	var c := _config()
	# Story 4-4 (AC 6/AC 9): per-kind now. Same in-test literals, new shape (see UnitKindFixture).
	c.unit_kinds = UnitKindFixture.minion_only(9.0, 3.0, 2, 3, 4, 2.0)
	c.hero_damage_to_unit = 3.0
	c.minion_retarget_interval_seconds = 1000.0
	return c


func _match_4_3b() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config_4_3b())
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	ms.inject_feature_flags(f)
	ms.drain_signals()
	return ms


## P1 gets one unit, acquired on `target`, driven into its ACTIVE window through the real reach
## trigger and the real phase ladder — never by writing the phase directly, so what these tests
## exercise is the shipped mechanism.
func _p1_unit_into_active(ms: MatchState, target: Array[int]) -> void:
	ms.p1.units.add(9.0, 0)
	ms.p1.units.set_target_at(0, target[0], target[1])
	ms.push_contact([0, 0], target, 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	_advance(ms)                       # the windup begins
	for _t in 2:                       # minion windup is 2 ticks
		_advance(ms)


## ---- AC 3: the hero-attacker REGRESSION PIN, and it is the non-vacuous one -----------------

## AC 3's core claim is that the widened attacker address is KIND-AGNOSTIC and that every existing
## hero-attacker call site "keeps resolving identically under `[slot, -1]`". The rest of this file
## is already that pin — every one of its hero facts now goes through the widened form — but a
## re-expression that is merely GREEN proves only that it compiles.
##
## THIS TEST MAKES IT NON-VACUOUS by measuring the ONE thing a broken widening would move and a
## compile could not catch: the resolved ATTACKER. A `[0, -1]` fact must reach P1's hero — its
## dedupe, its liveness, and P1's mana — and NOT be treated as a unit at board index -1 or as a
## unit at index 0. Both wrong readings are silent: the first drops every hero hit (no record under
## that index), the second would credit a unit's dedupe.
func test_a_hero_attacker_address_still_resolves_to_that_slots_hero() -> void:
	var ms := _match_4_3b()
	# A unit ALSO exists on P1's board, so "resolved to the hero" is a real discrimination rather
	# than the only possibility. It is never given a swing, so its dedupe stays empty.
	ms.p1.units.add(9.0, 0)
	_attack_and_advance_through(ms, 4)
	var mana_before := ms.p1.mana.get_current()
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), 94.0,
		"a `[slot, -1]` attacker resolves to that slot's HERO and lands the hero's own damage")
	assert_true(ms.p1.mana.get_current() > mana_before,
		"...and generates the hero's mana, so it went down the hero path and not the unit one")
	assert_eq(ms.p1.unit_dedupe.size(), 0,
		"...and registered in the HERO's dedupe, never the unit board's — `index == -1` is the hero, "
		+ "not board index -1 and not board index 0")
	assert_eq(ms.p1.hero.to_snapshot()["swing_dedupe"]["records"].size(), 1,
		"...which is where the record actually is")


## ---- AC 14: BOTH attacker-side rungs, PINNED TO FAIL LOUDLY --------------------------------

## AC 14 rung (a). THE DEFECT THIS PINS IS SILENT: the dead-attacker drop read
## `attacker.hero.action_state == DEAD`, which for a UNIT attacker asks whether its OWNER HERO is
## dead — so a LIVE minion owned by a DEAD hero had every one of its facts dropped, with no damage,
## no signal and no error.
##
## PINNED BY ASSERTING THE POSITIVE OUTCOME IN EXACTLY THE CONFIGURATION THAT SWALLOWS IT, which is
## AC 14's own instruction: the owner hero is DEAD and its minion is ALIVE, and the minion's hit
## MUST land. Against the shipped-before-this-story code this test fails.
func test_a_live_minion_under_a_dead_owner_hero_still_lands_its_hit() -> void:
	var ms := _match_4_3b()
	_p1_unit_into_active(ms, [1, -1])
	# Kill the OWNER hero, not the unit. `_check_resolution` ends the round on a dead hero and the
	# step-1b freeze would then skip step 4 entirely, so the round latch is cleared for this
	# measurement -- what is under test is the ATTACKER-KIND dispatch, not the round lifecycle.
	ms.p1.hero.take_damage(ms.p1.hero.get_max_hp())
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	ms.drain_signals()
	assert_true(ms.p1.units.is_alive_at(0), "sanity: the MINION is alive...")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "...and its OWNER is dead")
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p2.hero.get_hp() < hp_before,
		"a LIVE minion's hit lands even though its OWNER HERO is dead — the liveness rung resolves "
		+ "the ATTACKER'S OWN identity from the widened address (AC 14a). Reading the owner's "
		+ "action_state drops this fact with no damage, no signal and no error")


## AC 14 rung (a), THE OTHER DIRECTION, so the rung above is not simply "never drops anything":
## a DEAD MINION's fact IS dropped, even under a perfectly healthy owner hero.
func test_a_dead_minions_fact_is_dropped_even_under_a_living_owner() -> void:
	var ms := _match_4_3b()
	_p1_unit_into_active(ms, [1, -1])
	ms.p1.units.apply_damage_at(0, 9.0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the minion is dead")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "...and its owner is not")
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before,
		"a DEAD minion's fact delivers nothing — its liveness is its OWN board record's, so the "
		+ "rung falls in both directions rather than being permanently open")


## AC 14 rung (b), and the more damaging of the two silent failures: dedupe registration called the
## OWNER HERO's registrar, which returns false for a unit's `attack_index` because a unit never
## starts a hero swing and so never opens a record under that key — so EVERY UNIT HIT VANISHED, with
## no damage, no signal and no error.
##
## PINNED BY THE POSITIVE OUTCOME in exactly that configuration: a unit's FIRST registered hit lands.
func test_a_units_first_registered_hit_lands_rather_than_vanishing() -> void:
	var ms := _match_4_3b()
	_p1_unit_into_active(ms, [1, -1])
	assert_eq(ms.p1.unit_dedupe.size(), 1,
		"sanity: the unit opened its OWN record when its window opened")
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p2.hero.get_hp() < hp_before,
		"a unit's first hit LANDS — dedupe registration dispatches on ATTACKER KIND and consults "
		+ "the unit's OWN records (AC 14b). Against the owner hero's registrar it returns false and "
		+ "the hit vanishes with no damage, no signal and no error")
	# ...and the dedupe still does its job: the SAME address cannot be hit twice by the same swing.
	var hp_after := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_after,
		"...and a SECOND fact from the same swing against the same address is refused, so the "
		+ "registrar is really deduping rather than always returning true")


## AC 14 rung (b), the isolation half: a unit's registration must not touch the OWNER HERO's dedupe,
## and a hero's must not touch the unit's. Two registrars, no shared state (`4-3b/R12`).
func test_the_two_registrars_are_separate_state() -> void:
	var ms := _match_4_3b()
	var hero_counter_before := ms.p1.hero.attack_index
	_p1_unit_into_active(ms, [1, -1])
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p1.unit_dedupe.size(), 1, "the unit's record exists")
	assert_eq(ms.p1.hero.to_snapshot()["swing_dedupe"]["records"].size(), 0,
		"...and the OWNER HERO opened none — a unit swing does not create hero dedupe state")
	assert_eq(ms.p1.hero.attack_index, hero_counter_before,
		"...and did not advance the hero's monotonic counter either, which is snapshotted and would "
		+ "be an unnamed golden cause (`4-3b/R12`)")


## ---- AC 8: the signal asymmetry ---------------------------------------------------------------

## AC 8 (`4-3b/R5`): `hit_landed` IS emitted when a unit damages a HERO — the hero is really hurt, so
## the telegraph flash and sting on that hero are correct — and is still SUPPRESSED for a unit
## TARGET (`4-3a/R12`). A DELIBERATE ASYMMETRY, pinned in both directions in one test so a later
## pass cannot "fix" it into consistency without this failing.
func test_hit_landed_fires_for_a_unit_attacker_on_a_hero_and_not_on_a_unit() -> void:
	var ms := _match_4_3b()
	ms.p2.units.add(9.0, 0)
	var seen: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, h: float) -> void:
		seen.append([a, t, d, h]))
	# (i) unit attacker -> HERO target: EMITTED.
	_p1_unit_into_active(ms, [1, -1])
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(seen.size(), 1,
		"`hit_landed` IS emitted when a unit damages a HERO (AC 8) — the hero is really hurt")
	assert_eq(seen[0][0], 0,
		"...and its attacker payload is the BARE SLOT, unwidened (`4-3b/R15`): the shipped consumers "
		+ "underscore it and gate on the TARGET, so widening it would break two typed callbacks for "
		+ "zero behavioural gain")
	assert_eq(seen[0][1], 1, "...and the target slot is the hero that was hit")
	# (ii) the SAME unit attacker -> UNIT target: SUPPRESSED.
	var before := seen.size()
	var unit_hp_before := ms.p2.units.hp_at(0)
	ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p2.units.hp_at(0) < unit_hp_before,
		"sanity: the unit-target hit really did land, so the suppression below is about the SIGNAL")
	assert_eq(seen.size(), before,
		"...and NO `hit_landed` was emitted for it (`4-3a/R12`) — its payload carries a slot only, "
		+ "and the shipped consumer would flash an untouched HERO whose hp did not change. The two "
		+ "rules are not the same rule; this asymmetry is deliberate (AC 8)")
