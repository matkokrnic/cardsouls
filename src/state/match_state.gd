class_name MatchState
extends RefCounted

## D1/D2 root of the pure state layer. Owns the two PlayerStates, the reserved PitchState,
## the shared SignalQueue, and the single seeded gameplay RNG (F2). Pure RefCounted — no
## scene, no Input, no autoload, no wall-clock. The runner owns THIS object (no autoload
## for live state) and is the only thing that calls advance()/drain_signals().
##
## D2: advance(intents) is the ONE ordered call site that advances gameplay time. It only
## ENQUEUES signals; the runner drains them after it returns (D5).

## Owned by MatchState, relayed to the EventBus autoload by the runner (state never touches
## an autoload). loser_index: 0 = P1, 1 = P2. Re-arms when the debug reset clears the
## round latch (story 1-7, D-1): fires once per DEATH, not once per match.
signal round_ended(loser_index: int)

## Story 2-6 (AC 1, 2-6/R5/R6): the RESET counterpart to round_ended — a no-argument, ownerless
## round-lifecycle event (a debug reset is a whole-match event, not per-player, the round_ended
## analogy inverted). Pushed QUEUED and UNCONDITIONALLY by _apply_debug_reset() on EVERY debug
## reset (D5), relayed by the runner to EventBus.round_started exactly the way round_ended is.
## The single CLEAR trigger for the round-over label (HudRoot.on_round_started); round_ended
## stays the single SET. No prime-on-connect: a HUD consumer must receive an actual reset event.
signal round_started()

## Story 1-7 (N1): MatchState-owned two-player event (the round_ended analogy — a hit has
## an attacker AND a target, so it is not per-hero). Queued in step 4 when a contact is
## CONFIRMED, drained by the runner after advance() (D5). target_hp is the target's
## REMAINING HP after the damage. Consumers subscribe through the runner seam
## (match_runner.connect_hit_landed) and never hold a MatchState handle.
signal hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)

## Story 1-8 (R-D4): MatchState-owned two-player event (the hit_landed precedent — a
## deflect has an attacker AND a target). Queued in step 4 when a contact resolves as a
## DEFLECT (fully negated: no damage, no hit_landed, no mana), drained by the runner
## after advance() (D5). NO runner connect seam in 1-8 — the FIRST consumer (1-10
## CombatCues) inherits the seam obligation, the action_rejected precedent.
signal deflect_landed(attacker_slot: int, target_slot: int)

var p1: PlayerState
var p2: PlayerState
var pitch: PitchState        # reserved fizzle-deadline owner (D8), machinery in E6

## Injected via apply_balance() (story 1-1). `balance` holds the non-duration authored
## values; `balance_ticks` holds every `*_seconds` field pre-converted to integer ticks —
## the ONLY form in which those durations may be read inside advance() (A1).
var balance: BalanceConfig
var balance_ticks: BalanceTicks

## Story 1-5 (B3): the injected FeatureFlags — the first flag consumer in state. The
## runner reads FeatureFlagsService ONCE at match start and injects here; state NEVER
## reads the service (HARD RULE). Load-once, no reload path — deliberately unlike
## balance. EXCLUDED from to_snapshot(): flags are CONFIG, not state (the 1-2
## camera-basis analog), so the golden hash never depends on the flag object. Null
## (pre-injection, most headless tests) closes every flag-gated path — inert, like the
## balance null guards.
var flags: FeatureFlags

var _queue: SignalQueue
var _rng: RandomNumberGenerator  # the ONLY randomness source in the state layer (F2/A2)
var _tick := 0
var _round_over := false

## Per-slot camera basis (story 1-2) — an input-like PUSHED spatial fact, same category as
## InputIntent: the runner reads each rig and pushes it here in step 2. Fixed two-slot
## array, one per player — NEVER a single global basis (SEAM CHOICE 2: split-screen stays a
## config change). EXCLUDED from to_snapshot() like the intent stream; while the camera is
## fixed (all of E1) the basis is deterministic, so X5 replay is unaffected. Defaults to
## identity: with no basis pushed (tick 0, headless tests) move_dir is world-space (AC 4).
var _camera_bases: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]

## Story 1-5 (B7): queued contact facts, drained deterministically in advance() step 4.
## Input-like PUSHED facts, same category as InputIntent and the camera basis: plain
## recordable data (three ints per fact — X5 replay records them alongside intents; the
## actual recording is RE-HOMED to the story that lands IntentRecorder, 1-7 gate D-4;
## this seam's only obligation is staying recordable), EXCLUDED from to_snapshot()
## like the intent stream. In live play the runner pushes facts in frame step 2, so they
## reflect tick N-1's post-movement physics flush (F1 one-tick lag — absorbed by the
## dedupe grace tick, see HeroState._swing_dedupe).
var _contact_queue: Array[Dictionary] = []


## E0 constructs both players symmetrically (mirror match). When BalanceConfig lands (E3)
## these values arrive from the injected config; they are never hardcoded in-place here.
func _init(
	seed_value: int,
	max_hp: float,
	move_speed: float,
	max_stamina: float,
	max_mana: float,
) -> void:
	_queue = SignalQueue.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	p1 = PlayerState.new(_queue, max_hp, move_speed, max_stamina, max_mana)
	p2 = PlayerState.new(_queue, max_hp, move_speed, max_stamina, max_mana)
	pitch = PitchState.new()


## The single ordered dispatch (D2). intents = [p1_intent, p2_intent]. Enqueues signals
## only — never emits. Player order is fixed P1 -> P2 for determinism.
func advance(intents: Array[InputIntent]) -> void:
	var p1_intent := intents[0]
	var p2_intent := intents[1]
	_tick += 1

	# 1. Ingest intents        debug reset only (story 1-7, D-2): intent-carried so the
	#    mutation stays inside the ordered dispatch (D2) and rides the recorded intent
	#    stream for free once the X5 recorder lands. Attack/block/roll presses are still
	#    read directly by the step-3 transition evaluation.
	if p1_intent.debug_reset or p2_intent.debug_reset:
		_apply_debug_reset()
	# 1b. Round-over freeze (story 2-6, AC 1, 2-6/R6 — the 2-3/R10 named gap's owner): once the
	#    round is over, HALT both heroes and return, skipping steps 2 through 8 for this tick, so
	#    the surviving hero stops moving instead of gliding on. Seated AFTER step 1 (reset
	#    ingestion), NEVER hoisted ahead of it (the R6 ordering): a debug reset landing on the SAME
	#    tick the round is frozen cleared _round_over just above, so movement resolution resumes
	#    THAT tick, not one tick later. _tick already incremented at the top, so frozen ticks still
	#    advance the counter — a reset landing on tick N stays deterministic.
	#    Velocity is zeroed on EVERY frozen tick (2-6 operator ruling, close-out micro-decision):
	#    the runner reads HeroState.velocity into move_and_slide() every physics frame regardless
	#    of this early return, so a skipped write would leave the corpse (or any hero moving at the
	#    kill instant) sliding at its last live speed forever — exactly the 2-3/R14 residual, now
	#    honoured HERE instead of the step-3 DEAD branch. This is the standing 2-3 asymmetry rule
	#    applied unchanged: a field read downstream must be WRITTEN, a display-only field may be
	#    SKIPPED, so facing is left untouched and its last value persists (2-3/R14). The 2-3/R13
	#    one-tick carry is intact: on the KILL tick movement resolves at step 3 and DEAD is set at
	#    step 8, so the freeze only begins the NEXT tick — the corpse still carries its final
	#    velocity for exactly that one tick before step 1b zeroes it. Golden CANNOT prove this: the
	#    recorded sequence never reaches a round-over (story Dev Notes / test_determinism).
	if _round_over:
		p1.hero.velocity = Vector3.ZERO
		p2.hero.velocity = Vector3.ZERO
		return
	# 2. Advance D4 timers   (hero windows + each pool's regen-delay window — every window
	#    advances here, step 5 reads the result; unguarded like the hero timers, since a
	#    pre-injection MatchState never started a delay window)
	p1.hero.tick_timers()
	p2.hero.tick_timers()
	p1.stamina.tick_timers()
	p2.stamina.tick_timers()
	# 3. Resolve actions       per slot P1 -> P2: action transitions FIRST (a press on
	#    tick N takes effect on tick N), then intended velocity from move_dir. Transitions
	#    never write velocity — both halves of the 1-3 coupling deferral now live in
	#    _resolve_movement (1-5 attack commitment; 1-9 roll override reading the
	#    entry-locked roll_direction, captured here in step 3 at the ROLLING transition).
	_resolve_actions(p1, p1_intent, 0)
	_resolve_movement(p1, p1_intent, 0)
	_resolve_actions(p2, p2_intent, 1)
	_resolve_movement(p2, p2_intent, 1)
	# 4. Resolve contacts      (story 1-5) drain the queued facts in push order: dedupe/
	#    liveness acceptance -> damage -> record confirmed hits for step 5. Damage and
	#    dedupe ONLY here — mana is step 5's seat, keeping the documented D2 order
	#    truthful (N4).
	var confirmed_hits := _resolve_contacts()
	# 5. Resource generation   stamina regen (story 1-4) then melee-hit mana (story 1-5),
	#    P1 -> P2. Both implemented DIRECTLY — the D6 evaluator/rule schema is DEBT D
	#    (RESOLVED at the 1-5 trigger: stays direct; evaluator extraction re-triggers at
	#    E3). Same single null guard rationale as step 3: a pre-injection MatchState stays
	#    inert, no scattered checks below.
	if balance_ticks != null:
		_regen_stamina(p1)
		_regen_stamina(p2)
		_generate_mana(confirmed_hits)
	# 6. Card / economy        [E3 card play/draw; E6 pitch resolution]
	# 7. Board update          [E4 minion/totem throttled-tick seam]
	# 8. Resolution check
	_check_resolution()


## X3 hot-reload seam (story 1-1): the runner passes the (re)loaded BalanceConfig here.
## Re-injects bounds set_maximum-style (re-clamp + re-signal, queued per D5) and
## re-converts every `*_seconds` duration ONCE via BalanceTicks. A TimingWindow already
## in flight keeps its original duration; the new tick counts take effect at its next
## start() (D4/A1). Player order fixed P1 -> P2 for determinism.
func apply_balance(config: BalanceConfig) -> void:
	balance = config
	balance_ticks = BalanceTicks.from_config(config)
	_apply_balance_to_player(p1, config)
	_apply_balance_to_player(p2, config)


## Story 1-5 (B3): one-time flag injection at match start. Runner-only, exactly once —
## flags have NO reload path (deliberately unlike apply_balance); state never reads
## FeatureFlagsService.
func inject_feature_flags(value: FeatureFlags) -> void:
	flags = value


## Story 1-5 (B7): the contact intake seam — 1-7's real runner-gathered facts MUST enter
## through this same call, never a second path. Plain recordable data (X5): attacker
## slot, target slot, the attacker's HeroState.attack_index at gather time, and (story
## 1-8, R-B3 — the FOUR-field fact, superseding the original three-int shape) the
## world-space planar direction from the TARGET to the ATTACKER, computed by the runner
## FROM POSITIONS ONLY. The runner reports the spatial fact; state alone compares it
## against the target's facing (the arc gate is step-4 policy). Queued here, drained in
## advance() step 4. Headless tests feed synthetic facts through this API. A malformed
## fact is a programming error, ENFORCED at the seam (review R1 — Invariant.check, a
## plain static class, no autoload): slots must be 0 or 1, a self-contact is malformed
## in 1v1 (operator decision; 1-7's gate revisits if real gathering ever needs
## otherwise), and a zero direction is directionless — no spatial fact.
func push_contact(attacker_slot: int, target_slot: int, attack_index: int,
		target_to_attacker: Vector2) -> void:
	Invariant.check(attacker_slot == 0 or attacker_slot == 1,
		"contact attacker_slot must be 0 or 1, got %d" % attacker_slot)
	Invariant.check(target_slot == 0 or target_slot == 1,
		"contact target_slot must be 0 or 1, got %d" % target_slot)
	Invariant.check(attacker_slot != target_slot,
		"self-contact fact is malformed in 1v1 (attacker == target == %d)" % attacker_slot)
	Invariant.check(not target_to_attacker.is_zero_approx(),
		"contact target_to_attacker direction must be non-zero (no spatial fact)")
	_contact_queue.append({
		"attacker": attacker_slot,
		"target": target_slot,
		"attack_index": attack_index,
		"dir": target_to_attacker,
	})


## Runner step-2 push (story 1-2). slot: 0 = P1, 1 = P2 — out-of-range is a programming
## error (fixed-size fact; the array index asserts). State never reads the camera; it only
## receives this pushed value.
##
## LOAD-BEARING (DECISION A): while the camera is fixed (all of E1) the hero ROOT must
## never be rotated — body/facing rotation belongs on a child mesh node. The rig is a
## child of the hero root, so a rotated root would fold hero rotation into this pushed
## basis and break camera-relative "forward" (and the identity short-circuit in
## _resolve_movement). The runner therefore pushes the rig's LOCAL basis, guarded by
## test_root_rotation_isolation.gd; a story that needs a rotating root must decouple the
## rig from hero rotation deliberately (deferred DECISION B).
func set_camera_basis(slot: int, camera_basis: Basis) -> void:
	_camera_bases[slot] = camera_basis


## Emit all queued signals. Called by the runner AFTER advance() returns (D5).
func drain_signals() -> void:
	_queue.drain()


func to_snapshot() -> Dictionary:
	return {
		"tick": _tick,
		"rng_state": _rng.state,   # captured so the determinism hash catches RNG desync
		"round_over": _round_over,
		"p1": p1.to_snapshot(),
		"p2": p2.to_snapshot(),
		"pitch": pitch.to_snapshot(),
	}


## Story 3-0b (AC 2): READ-ONLY DEBUG accessor — per slot, the remaining ticks of the action
## windows that are currently RUNNING, as COMPUTED PLAIN INTEGERS derived from
## TimingWindow.remaining_ticks(). Slot order is fixed [P1, P2]; window order within a slot is
## HeroState's declaration order. A window that is not running is ABSENT (the AC's "active
## windows"), so the payload is small — at most two or three entries per slot in practice.
##
## This is DEBUG INSTRUMENTATION, NOT an eighth observation seam: the runner POLLS it after
## advance() and pushes the plain payload into DebugInstrumentPanel. No signal, no state handle,
## no mutator — presentation receives VALUES, never internals, the same discipline the seven
## seams already follow (the standing "hands the state layer's internals to presentation"
## objection is answered by the return type: ints keyed by name). to_snapshot() is deliberately
## NOT extended, so the replay contract never learns this instrument exists.
func debug_window_ticks_remaining() -> Array[Dictionary]:
	return [_running_window_ticks(p1.hero), _running_window_ticks(p2.hero)]


## The per-hero half of debug_window_ticks_remaining(). The TimingWindow objects are read and
## discarded INSIDE this function — only ints leave it.
static func _running_window_ticks(hero: HeroState) -> Dictionary:
	var out: Dictionary = {}
	var windows: Array = [
		[&"windup", hero.windup],
		[&"active", hero.active],
		[&"recovery", hero.recovery],
		[&"chain", hero.chain],
		[&"deflect", hero.deflect],
		[&"iframe", hero.roll_iframe],
		[&"roll", hero.roll_duration],
		[&"stun", hero.stun],
	]
	for entry: Array in windows:
		var window: TimingWindow = entry[1]
		if window.is_running:
			out[entry[0]] = window.remaining_ticks()
	return out


## Step-3 transition evaluation (story 1-3). EVALUATES HeroState.TRANSITION_TABLE — the
## table data lives on HeroState next to the enum; this is only the evaluator. Durations
## are read from balance_ticks.<field> inline at the moment a transition fires and passed
## into the window's start() (CONSTRAINT C: never cache the BalanceTicks object — a
## running window keeps its old duration across a reload; the next start() picks up the
## new one, guarded by test_balance_config.gd).
func _resolve_actions(player: PlayerState, intent: InputIntent, slot: int) -> void:
	# DEBT A deferral (story 1-3, deliberate): the runner never calls apply_balance() yet,
	# so in live play balance_ticks is null and actions are INERT until the follow-up
	# story wires apply_balance at match start + re-baselines the golden (both DEBT A
	# halves together). This is THE one guard — no scattered null checks below it.
	if balance_ticks == null:
		return
	var hero := player.hero
	# (a) Timer-driven progression/exits — windows were advanced in step 2; read results.
	match hero.action_state:
		HeroState.ActionState.ATTACKING:
			match hero.attack_phase():
				&"windup_done":
					hero.active.start(balance_ticks.attack_active_ticks)
				&"active_done":
					hero.recovery.start(balance_ticks.attack_recovery_ticks)
					hero.chain.start(balance_ticks.attack_chain_window_ticks)
				&"attack_done":
					hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.ROLLING:
			if not hero.roll_duration.is_running:
				hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.BLOCKING:
			if not intent.is_held(&"block"):
				hero.set_action_state(HeroState.ActionState.IDLE)
	# (b) Input-driven edges from the current table row. A press with no entry in the row
	# is dropped, never buffered (AC 5). Fixed INPUT_PRIORITY order = deterministic
	# same-tick tiebreak; at most one transition fires per tick.
	var row := hero.transition_row()
	if not HeroState.TRANSITION_TABLE.has(row):
		return
	var edges: Dictionary = HeroState.TRANSITION_TABLE[row]
	for action: StringName in HeroState.INPUT_PRIORITY:
		if intent.is_pressed(action) and edges.has(action) \
				and _try_transition(player, edges[action], intent, slot):
			return


## Fire one table edge. Returns false when a gated edge rejects — the chain cap (silent,
## story 1-3) or the roll stamina precondition (emits action_rejected, story 1-4) — so a
## lower-priority same-tick press may still be considered.
## intent/slot ride along for the ROLLING edge only (story 1-9): the entry-time roll
## direction is captured from the SAME press that fires the transition.
func _try_transition(player: PlayerState, target: HeroState.ActionState, intent: InputIntent,
		slot: int) -> bool:
	var hero := player.hero
	match target:
		HeroState.ActionState.ATTACKING:
			var chaining := hero.action_state == HeroState.ActionState.ATTACKING
			if chaining:
				# Chain edge: only inside the chain window and below the authored cap.
				# attack_chain_length is a COUNT, not a duration — it lives on balance,
				# not balance_ticks; read inline under the same no-caching rule.
				# FIRST, before the stamina seat below: a capped press is not an attempt
				# to attack, so it must not be charged (and stays SILENT, story 1-3).
				if not hero.chain.is_running or hero.chain_index + 1 >= balance.attack_chain_length:
					return false
			# The THIRD step-3 policy seat of the deduction MECHANISM (stamina-cost
			# corrective pass, E3-RG/R2; decision (d) RESOLVED at DP/R2 — the basic attack
			# costs stamina as an ANTI-SPAM lever, the 1-5 mana faucet is untouched).
			# Follows the ROLL precedent exactly, not deflect's: charged AT ENTRY per swing
			# (chain included), and unaffordable = the 1-4 FALLTHROUGH, never deflect's
			# degrade — there is no degraded attack to fall back to. Cost and delay read
			# inline (CONSTRAINT C). Nothing above this line mutated hero state, so a
			# rejected attack costs nothing, enters no state, and leaves chain_index alone.
			if not player.stamina.spend(
					balance.attack_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"attack", &"insufficient_stamina")
				return false
			if chaining:
				hero.chain_attack(balance_ticks.attack_windup_ticks)
			else:
				hero.enter_attack(balance_ticks.attack_windup_ticks)
		HeroState.ActionState.ROLLING:
			# A step-3 policy seat of the single deduction MECHANISM (StaminaPool.spend,
			# D4/story 1-4; R-D1 reconciliation). No longer the ONLY one: the basic attack
			# gained a cost in the E3-RG/R2 corrective pass and shares this seat's shape
			# (see the ATTACKING case above). BLOCKING entry stays free (block costs TIME
			# via the D6 regen suppression).
			# Deflect's policy seat is step 4 — spend at deflect LANDING, never at entry
			# (story 1-8, R-D1). Cost and delay are read inline at the moment of the
			# transition (CONSTRAINT C). Insufficient stamina is a PRECONDITION (D5): the
			# edge rejects and falls through per INPUT_PRIORITY, and the queued
			# action_rejected keeps the loss legible even if a lower-priority press fires.
			if not player.stamina.spend(
					balance.roll_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"roll", &"insufficient_stamina")
				return false
			hero.enter_roll(balance_ticks.roll_duration_ticks, balance_ticks.roll_iframe_ticks,
					_roll_world_direction(hero, intent.move_dir, slot))
		HeroState.ActionState.BLOCKING:
			# Story 1-8 (R-D1): affordability PRECONDITION only — no spend, no regen-delay
			# restart at entry; the spend happens at deflect LANDING (step 4). Unaffordable
			# = DEGRADE, not the 1-4 fallthrough: the block edge still fires as a plain
			# block, only the window is denied, and the queued rejection names "deflect"
			# because that is the thing denied. Cost read inline (CONSTRAINT C).
			var can_deflect := player.stamina.get_current() >= balance.deflect_stamina_cost
			hero.enter_block(balance_ticks.deflect_window_ticks, can_deflect)
			if not can_deflect:
				hero.reject_action(&"deflect", &"insufficient_stamina")
	return true


## Story 1-9 (1-9/R6): the entry-time roll direction — the same camera-rotated world
## mapping _resolve_movement uses (clamp, identity short-circuit, yaw-only rotation),
## NORMALIZED (constant roll speed needs a unit direction), with the hero's world-space
## facing as the fallback when the stick is neutral. Computed ONCE at the transition;
## the stored value is locked for the whole roll.
func _roll_world_direction(hero: HeroState, move_dir: Vector2, slot: int) -> Vector3:
	if move_dir.is_zero_approx():
		return Vector3(hero.facing.x, 0.0, hero.facing.y).normalized()
	var dir := move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	return world_dir.normalized()


## Step-4 contact resolution (story 1-5). Drains the queue in push order; for each fact,
## a DEAD target drops the fact outright (story 1-7, D-3 — dropped BEFORE resolution: no
## damage, no dedupe registration, no confirmed hit, so no step-5 mana; closes the
## corpse-mana-farming defect found at the 1-7 gate), then an open target iframe drops
## it the same way (story 1-9, 1-9/R1 — the second target-state drop; see the inline
## comment for the ladder position), then the attacker's dedupe decides
## acceptance (live record for the fact's attack_index + target not already hit this
## swing — stale, unknown, and duplicate facts are DROPPED). Story 1-8 (R-D4): dedupe
## registration happens for EVERY outcome — one resolution per swing per target, whether
## it lands full, blocked, or deflected; a resolved swing's later facts cannot
## re-resolve. Outcome ladder for an accepted fact (all balance reads inline,
## CONSTRAINT C): a BLOCKING target facing the attacker (the arc gate, R-D2/R-D3)
## either DEFLECTS — window open per the +1 grace read (R-N2) AND the deflect cost
## spends at LANDING (R-D1; a failed spend, the R-N7 multi-deflect edge, degrades this
## contact to a block) — fully negated: no damage, no hit_landed, NO step-5 mana, only
## the queued deflect_landed; or BLOCKS — damage x block_damage_multiplier, still a
## CONFIRMED hit (reduced hit_landed + full step-5 mana — block deliberately does not
## touch the attacker's economy in E1). Not facing (or not blocking) = full damage
## regardless of the window — no parry from behind. Returns the attacker slots of
## confirmed hits, in confirmation order, for step 5's mana seat. Pre-injection guard
## mirrors _resolve_actions: without balance the queue still drains (facts are
## per-tick, never carried) but nothing resolves.
func _resolve_contacts() -> Array[int]:
	var confirmed: Array[int] = []
	if _contact_queue.is_empty():
		return confirmed
	if balance == null:
		_contact_queue.clear()
		return confirmed
	for fact in _contact_queue:
		var attacker := p1 if int(fact["attacker"]) == 0 else p2
		var target := p1 if int(fact["target"]) == 0 else p2
		if target.hero.action_state == HeroState.ActionState.DEAD:
			continue
		# Story 2-3 (AC3, 2-3/R6): attacker-side DEAD FACT DROP — the same rung and the same
		# DEAD-drop family as the target drop above: PRE-DEDUPE, ahead of the iframe drop and
		# register_swing_hit. A dead attacker's fact delivers NOTHING (no damage, no
		# hit_landed, no mana, no deflect signal). Placed before register_swing_hit so the
		# corpse's fact never consumes the swing's one resolution; attack_index stays
		# untouched. The in-flight window is NOT stopped or shortened here — it keeps ticking
		# to expiry by design (1-9/R3 intact); it simply resolves to nothing.
		if attacker.hero.action_state == HeroState.ActionState.DEAD:
			continue
		# Story 1-9 (1-9/R1): iframe FACT DROP — not a resolution. Judged on the window
		# (+grace) ALONE, never on state == ROLLING (1-9/R3), and BEFORE dedupe
		# registration (the DEAD-drop family): a dropped fact never consumes the swing,
		# so if the i-frames expire inside the swing's active window the next gathered
		# fact resolves normally. No damage, no hit_landed, no mana, no signal (1-9/R5).
		if target.hero.is_iframe_open():
			continue
		if not attacker.hero.register_swing_hit(int(fact["attack_index"]), int(fact["target"])):
			continue
		var damage := balance.attack_damage_percent_of_max_hp / 100.0 * target.hero.get_max_hp()
		if target.hero.action_state == HeroState.ActionState.BLOCKING \
				and _is_facing(target.hero, fact["dir"]):
			if target.hero.is_deflect_window_open() and target.stamina.spend(
					balance.deflect_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				_queue.push(deflect_landed.emit.bind(int(fact["attacker"]), int(fact["target"])))
				continue
			damage *= balance.block_damage_multiplier
		target.hero.take_damage(damage)
		_queue.push(hit_landed.emit.bind(
			int(fact["attacker"]), int(fact["target"]), damage, target.hero.get_hp()))
		confirmed.append(int(fact["attacker"]))
	_contact_queue.clear()
	return confirmed


## Story 1-8 (R-D2/R-D3): the facing gate — pure state policy over the runner-reported
## direction fact. True iff the target-to-attacker direction lies within +/- half the
## authored arc of the target's world-space facing (angle_to is magnitude-independent,
## so neither vector needs normalizing; the arc is read inline, CONSTRAINT C). Exact
## float comparison, deliberately no epsilon: a direction at EXACTLY arc/2 lands on
## float rounding, which is fine — real directions are continuous, and the guarded
## behavior is both sides OF the arc, not the measure-zero boundary ray.
func _is_facing(hero: HeroState, target_to_attacker: Vector2) -> bool:
	return absf(hero.facing.angle_to(target_to_attacker)) \
			<= deg_to_rad(balance.block_facing_arc_degrees * 0.5)


## Step-5 melee-hit mana (story 1-5) — THE one mana-generation path (DEBT D resolved:
## direct, no evaluator; the 1-4 single-deduction-path analog). Gated on the INJECTED
## melee_mana_generation flag — flag OFF (or no flags injected) closes the faucet and
## nothing else: the hit still landed and damaged in step 4 (graceful degradation). The
## per-hit amount is read inline at the moment of use (CONSTRAINT C).
func _generate_mana(confirmed_hits: Array[int]) -> void:
	if flags == null or not flags.melee_mana_generation:
		return
	for slot in confirmed_hits:
		var attacker := p1 if slot == 0 else p2
		attacker.mana.add(balance.melee_hit_mana)


## Step-5 stamina regen (story 1-4). The per-tick amount is read inline from balance_ticks
## (CONSTRAINT C); the pool owns the mechanism (fixed add + post-spend delay window), THIS
## is the policy seat (D6): regen is suppressed while the hero is BLOCKING — block entry is
## free, so block must cost time or holding it would be free and P2 ("aggression is
## economy") unenforced; suppressed likewise while DEAD, since a corpse runs no economy
## (story 2-3). Every other action state regenerates.
func _regen_stamina(player: PlayerState) -> void:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero is skipped the SAME way a BLOCKING one already is
	# (the D6 suppression) — a corpse runs no economy. This extends the existing suppression
	# flag; it is a DIFFERENT function and step from the P2 movement gate (do not merge them).
	var state := player.hero.action_state
	var suppressed := state == HeroState.ActionState.BLOCKING \
			or state == HeroState.ActionState.DEAD
	player.stamina.advance_regen(balance_ticks.stamina_regen_per_tick, suppressed)


func _resolve_movement(player: PlayerState, intent: InputIntent, slot: int) -> void:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero exhibits no live movement. ASYMMETRIC by
	# downstream consumption (see story Dev Notes): velocity is EXPLICITLY written to zero
	# EVERY tick — HeroActor.drive() reads hero_state.velocity straight into move_and_slide()
	# (hero.gd:26), so a SKIPPED write would leave the last live velocity in place and the
	# corpse would slide forever; facing is SKIPPED (this early return never reaches the
	# facing write below), so its last value persists unchanged — that persistence IS the
	# freeze, storing nothing new (hero.gd:34 only reads facing to derive a display yaw).
	# No new snapshot field: only velocity's VALUE on the DEAD branch changes.
	if player.hero.action_state == HeroState.ActionState.DEAD:
		player.hero.velocity = Vector3.ZERO
		return
	var dir := intent.move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()  # analog safety; never speed up past move_speed
	# move_dir is CAMERA-space (story 1-2): rotated to world by the slot's pushed basis,
	# yaw only. Identity (nothing pushed — AC 4) short-circuits to the exact E0 planar
	# mapping (intent XY -> world XZ), a true no-op so headless tests and the determinism
	# golden are untouched. velocity stays the REAL world velocity the runner reads (D3);
	# the runner never rotates it afterwards (AC 6).
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	# Story 1-5 (B6, operator decision): attack commitment — while ATTACKING the resolved
	# VELOCITY is scaled by an attack-phase multiplier (authored 0.0 = full root), read
	# inline at the moment of use (CONSTRAINT C). Velocity ONLY — the facing update below
	# is never scaled by the multiplier. ATTACKING is unreachable pre-injection (the step-3
	# balance_ticks guard), so `balance` is non-null on this branch.
	# Story 3-0b (AC5, DEBT E member 2): the multiplier is now PER PHASE — the single flat
	# field is gone and _attack_phase_multiplier() selects windup/active/recovery from
	# HeroState.attack_phase(). No new state: the phase is already derived from which
	# window is running.
	# Story 1-9 (1-9/R6): the ROLL half of the same coupling deferral — while ROLLING the
	# velocity is the entry-locked roll_direction at roll_distance / roll_duration_seconds
	# (the ruling's exact quotient; a SPEED derivation, not window timing — timing stays
	# balance_ticks), both read inline at the moment of use (CONSTRAINT C: a mid-roll
	# reload changes the speed next tick while in-flight windows keep their duration).
	# Live input steers nothing until the roll ends; the facing update below still runs
	# (the ATTACKING-commitment precedent: velocity-only, facing tracks input). ROLLING is
	# unreachable pre-injection too, and the authoring audit guarantees
	# roll_duration_seconds > 0.
	if player.hero.action_state == HeroState.ActionState.ROLLING:
		player.hero.velocity = player.hero.roll_direction \
				* (balance.roll_distance / balance.roll_duration_seconds)
	else:
		# Story 3-0b (AC6): the attack LUNGE, ADDED to the input-driven velocity rather than
		# replacing it — the phase multiplier keeps scaling what the player steers, and the
		# lunge is the separate committed push the swing itself carries. At the authored
		# multipliers (0.0 = full root) the lunge is therefore the whole of the attack's
		# velocity, which is the intended shape: input steers nothing mid-swing, the swing
		# still carries the hero forward.
		var speed := player.hero.move_speed
		var lunge := Vector3.ZERO
		if player.hero.action_state == HeroState.ActionState.ATTACKING:
			speed *= _attack_phase_multiplier(player.hero.attack_phase())
			lunge = _attack_lunge_velocity(player.hero)
		player.hero.velocity = world_dir * speed + lunge
	# Story 1-7 (review R1, operator decision): facing is WORLD-SPACE planar — the same
	# rotated direction the velocity uses, so actor-side consumers (the hitbox yaw) need
	# no basis knowledge. Under an identity basis world_dir == (dir.x, 0, dir.y), so
	# facing equals the raw intent direction bit-for-bit (golden-neutral). The zero-guard
	# is unchanged: facing freezes while there is no movement input.
	if not dir.is_zero_approx():
		player.hero.facing = Vector2(world_dir.x, world_dir.z)


## Story 3-0b (AC5): per-phase attack movement multiplier. Selects one of the three
## BalanceConfig fields from HeroState.attack_phase(), read inline at the moment of use
## (CONSTRAINT C).
##
## BOUNDARY VALUES: attack_phase() also returns windup_done/active_done/attack_done on a
## phase-boundary tick (step 2 stopped a window, step 3 has not yet started the next). Step
## 3(a) normally starts the successor BEFORE _resolve_movement runs, so an ATTACKING hero
## is on a running window here — but a degenerate 0-tick authored phase can leave a *_done
## value visible, so the mapping is TOTAL rather than relying on that. It groups the
## boundary values exactly the way HeroState.transition_row() already does (windup +
## windup_done together, active + active_done together), so the two phase consumers agree
## on where a boundary tick belongs instead of inventing a second grouping; attack_done
## falls to recovery as the last phase that ran.
func _attack_phase_multiplier(phase: StringName) -> float:
	match phase:
		&"windup", &"windup_done":
			return balance.attack_windup_move_speed_multiplier
		&"active", &"active_done":
			return balance.attack_active_move_speed_multiplier
		_:
			return balance.attack_recovery_move_speed_multiplier


## Story 3-0b (AC6): the attack lunge as a STATE-SIDE velocity term — the sanctioned form
## from the 1-7 close-out ("an authored lunge displacement in balance data, applied by the
## STATE layer as a velocity curve during the swing"). NEVER root motion: no AnimationPlayer
## sample reaches this function, so replay never depends on animation and DECISION A / the
## in-place rule stand untouched.
##
## Speed derivation follows the ROLL precedent verbatim (roll_distance /
## roll_duration_seconds, the neighbouring branch): the authored DISPLACEMENT divided by the
## span it is spent over. A *_seconds float is read here for the same reason the roll reads
## one — this is a SPEED derivation, not window timing; all timing stays on balance_ticks
## (CONSTRAINT C: both operands are read inline at the moment of use, so a mid-swing reload
## changes the speed next tick while in-flight windows keep their duration).
##
## PHASE SCOPE (ruled, story AC6): live during WINDUP and ACTIVE only. The lunge is the
## commitment forward INTO the swing; drifting through recovery is a different feel decision
## and is not this term's. Boundary values are grouped exactly as _attack_phase_multiplier()
## groups them, so the two consumers never disagree about which phase a boundary tick is in.
##
## Direction is HeroState.facing — world-space planar since 1-7/R1, so no basis knowledge is
## needed here and none of the camera mapping above applies to it. Facing is read LIVE
## rather than entry-locked (the roll's stored roll_direction shape), which keeps the lunge
## out of the snapshot entirely: no new state field, no snapshot-shape change. A hero that
## turns mid-swing therefore lunges along its new facing — the "velocity-only commitment,
## facing tracks input" rule this function already follows for the multiplier.
##
## Guards: a zero-or-negative span would divide to INF and poison the snapshot, and a
## zero facing has no direction to lunge along. Both yield no lunge. The authoring audit
## already keeps the shipped windup/active durations > 0; this guard covers in-test and
## pre-authoring configs, which the roll branch can skip only because ROLLING is
## unreachable before its own authored duration exists.
func _attack_lunge_velocity(hero: HeroState) -> Vector3:
	var phase := hero.attack_phase()
	var committed := phase == &"windup" or phase == &"windup_done" \
			or phase == &"active" or phase == &"active_done"
	if not committed:
		return Vector3.ZERO
	var span := balance.attack_windup_seconds + balance.attack_active_seconds
	if span <= 0.0 or hero.facing.is_zero_approx():
		return Vector3.ZERO
	var dir := hero.facing.normalized()
	return Vector3(dir.x, 0.0, dir.y) * (balance.attack_lunge_distance / span)


## Yaw-only camera-space -> world mapping (AC 3): the basis' right/back columns are
## flattened onto XZ and renormalized, so camera pitch mathematically cannot tilt or
## shrink movement. Degenerate columns (camera looking straight up/down) fall back to the
## world-space mapping rather than producing NaNs.
static func _camera_relative_dir(dir: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var back := Vector3(camera_basis.z.x, 0.0, camera_basis.z.z)
	if right.is_zero_approx() or back.is_zero_approx():
		return Vector3(dir.x, 0.0, dir.y)
	return right.normalized() * dir.x + back.normalized() * dir.y


func _apply_balance_to_player(player: PlayerState, config: BalanceConfig) -> void:
	player.hero.set_max_hp(config.max_hp)
	player.hero.move_speed = config.move_speed
	player.stamina.set_maximum(config.max_stamina)
	# D9 (story 1-4): start FULL at the authored maximum. Scope limit: this does NOT touch
	# the constructor/apply_balance double-injection quirk — that remains story 3-1.
	player.stamina.refill()


func _check_resolution() -> void:
	if _round_over:
		return
	if not p1.hero.is_alive():
		_end_round(p1, 0)
	elif not p2.hero.is_alive():
		_end_round(p2, 1)


## Story 1-7 (D-3): the ONLY entry into ActionState.DEAD — a step-8 resolution outcome,
## never a table edge (the table's dead row accepts nothing; exit is only the D-1 debug
## reset). Presentation learns of death through the same queued action_state_changed
## channel as every transition (the locked observation seam).
func _end_round(loser: PlayerState, loser_index: int) -> void:
	_round_over = true
	loser.hero.set_action_state(HeroState.ActionState.DEAD)
	_queue.push(round_ended.emit.bind(loser_index))


## Story 1-7 (D-1, operator decision): ROUND-SCOPED debug reset — every slot's HP back to
## max and the round latch cleared; NOTHING else (pools, dedupe records, in-flight
## windows, and actor-owned positions untouched — a live hero mid-swing swings on). A
## DEAD hero returns to IDLE (a "clear action state" entry), which NEVER touches
## attack_index (monotonic dedupe contract, pinned at the 1-6 gate). Deliberately NOT
## flag-gated: operator affordance, not a gameplay path (exception recorded in the
## decision log). Fixed P1 -> P2 order for determinism.
func _apply_debug_reset() -> void:
	_round_over = false
	_reset_player(p1)
	_reset_player(p2)
	# Story 2-6 (AC 1, 2-6/R5): announce the reset UNCONDITIONALLY on every debug reset — the
	# round lifecycle previously emitted only on END (round_ended), never on reset, which is the
	# 2-4 close-out MICRO-DECISION 1 gap (the round-over label survived a reset because nothing
	# signalled it). Queued (D5) like every state signal; the runner relays it post-drain.
	_queue.push(round_started.emit)


func _reset_player(player: PlayerState) -> void:
	var hero := player.hero
	if hero.action_state == HeroState.ActionState.DEAD:
		hero.set_action_state(HeroState.ActionState.IDLE)
	hero.heal(hero.get_max_hp())
