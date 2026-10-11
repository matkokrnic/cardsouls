class_name UnitActor
extends CharacterBody3D

## Story 4-1 (AC 7): the GREY-BOX UNIT -- the first real content in `src/actors/minions/`, the
## directory `docs/game-architecture.md`'s Directory Tree tags `(4-1)` and which held nothing but
## a `.gitkeep` until this story.
##
## A PLACEHOLDER MESH AND NOTHING ELSE. Visual fidelity is explicitly out of scope everywhere in
## this project and grey-box is the standing bar; this exists so a resolved `summon_*` cast has a
## visible, persistent consequence a human can see in the live smoke, which is the story's whole
## player-facing claim.
##
## NO GAMEPLAY LOGIC LIVES HERE, on the HeroActor / TelegraphController precedent and the
## project-context HARD RULE that puts it there: no `_physics_process` (INVARIANT F1 -- the runner
## owns the only one), no `Input`, no state handle, no signal into state, no damage, no targeting,
## no AI. It is placed by the runner and it stands there. Movement lands in 4-3 (below); HP, damage
## and death are `4-3a`'s under `4-3/R1`, which split the boarded `4-3-minion-combat` in two;
## totem-vs-minion differentiation is 4-4's.
##
## POSITION IS ACTOR-OWNED, WHICH IS THE RULING (`4-1/R12`), NOT A CONVENIENCE. UnitBoard holds no
## position and the hero precedent is unchanged (hero_state.gd:5 -- "no position (position is
## actor-owned, F1)"). The runner chooses where a unit stands, exactly as it reads
## `actor.global_position` off the hero and pushes only a DERIVED fact inward. `4-2`'s gate rules
## on real position ownership once TargetingService exists as a consumer.
##
## POOLED BY NOBODY, AND 4-5 MEASURED THAT THIS IS CORRECT RATHER THAN LEAVING IT OPEN. Units are
## plain instantiated and `queue_free()`d nodes, here and after 4-5. That story built the 20-unit
## measurement `E4-P/R8` made the precondition for any pooling code
## (`test/perf/perf_20_units_live.gd`) and applied `4-5/R1`'s criterion to the result: at ~20
## concurrent units with combat totems firing and both split-screen viewports live, sustained frame
## time was 4.14 ms average and 7.52 ms p95 against a 16.67 ms budget, and the worst single frame at
## a spawn or death event was 15.46 ms against a ~33 ms ceiling (re-measured after the review's event
## attribution fix, `4-5/R2`; the earlier 10.39 ms figure is VOID) -- no frame in the authoritative
## measured round exceeded 25.42 ms (a review re-run saw 48.6 ms on a non-event tail frame). PASS on
## both halves, with roughly 4x headroom, so AC 8 fired: no pooling
## ships, `src/systems/pool/` stays empty, and instantiate/`queue_free()` per unit is the MEASURED
## answer rather than the deferred one. Re-measure before treating that as permanent -- the number
## belongs to this content at this population on the recorded machine, not to the design.
##
## STORY 4-2 ADDS ONE PURELY PRESENTATIONAL METHOD AND NO GAMEPLAY (`4-2/R13`). `aim_at()` yaws the
## box toward whatever the runner tells it to look at. Everything above still holds: no
## `_physics_process`, no `Input`, no state handle, no signal into state, no damage, and no targeting
## DECISION -- the decision is TargetingService's, inside `advance()`, and this node is told the
## answer. A rotation is not a move; the move itself arrives in 4-3, directly below.
##
## STORY 4-3 MAKES THIS A BODY AND GIVES IT THE MOVE (`4-3/R17`, `4-3/R8`). The root becomes a
## `CharacterBody3D` with ONE `CollisionShape3D` child on the DEFAULT layer/mask -- the same layer 1
## "bodies" the hero root sits on (`hero.tscn:49`, no layer/mask lines) -- so a unit blocks a hero,
## without a new collision layer and without touching `project.godot`. Unit-vs-unit blocking falls
## out of the same default layer but is NOT measured by this story (`4-3/R21`; filed
## `deferred-work.md`, owner `4-3a`). NO HURTBOX AND NO `Area3D` SHIPS HERE: the hero Hitbox is
## layer 4 / mask 2 (hurtboxes only) and `_gather_contact_facts` drops any actor whose `_slot_of`
## is -1, so a unit body cannot enter the
## contact pipeline. Damage intake is `4-3a`'s.
##
## EVERYTHING ABOVE STILL HOLDS ACROSS THAT CHANGE. `approach()` is the `aim_at()` shape with a
## translation instead of a yaw: no `_physics_process` (the RUNNER calls it from its drive phase,
## the hero `drive()` seat -- F1 stays exactly one hit), no `Input`, no state handle, no signal into
## state, no damage, and NO DECISION -- the runner resolves the acquired `[slot, index]` pair to a
## `Vector3` and hands it over, and the speed and stop distance are authored balance passed in by
## the caller. This node holds NO copy of either value (CONSTRAINT C / `4-3/R11`) and never reads
## `BalanceConfigService`: during replay that would walk the unit at the AUTHORED speed instead of
## the RECORDED one.
##
## IT EXISTS BECAUSE THE SMOKE NEEDED A VISIBLE SIGNAL. With movement out of scope (`4-2/R4`), "the
## unit does not sit permanently inert" is unfalsifiable by observation -- a unit that never moves
## gives a human nothing to watch for. `4-2/R13` rewrote the live smoke around this rotation instead.
##
## ROTATING THIS ROOT IS SAFE, unlike the hero's (DECISION A). The hero root must never rotate
## because the camera rig is its child, so a rotated root would fold hero rotation into the pushed
## camera basis; this scene's only child is a mesh, it carries no camera and nothing reads its basis.
## test_root_rotation_isolation.gd guards the HERO root and is untouched by this.


## Story 4-3b (AC 2): the unit HITBOX, exposed exactly as `HeroActor` exposes its own
## (`hero.gd`) and for the same one consumer -- the runner's gather pass, which queries
## `get_overlapping_areas()` directly and never `area_entered` (signal firing order is not
## guaranteed and would make replay order-dependent). NOTHING ELSE READS IT, this node never touches
## it, and it holds no gameplay logic: it reports contact and `advance()` step 4 decides.
##
## STORY 4-4 (AC 3): IT IS `get_node_or_null` NOW, because a TOTEM SCENE AUTHORS NO HITBOX. AC 3 is
## explicit — "No totem kind authors a `Hitbox`: the Combat totem attacks only via its projectile
## (AC 14); the accelerators never attack" — and `totem_actor.tscn` is this same script mounted on a
## scene that carries Collision and Hurtbox and nothing else. `$Hitbox` would push a runtime error
## on every totem instantiation; a null here is the honest answer, and the runner's gather pass
## already has to skip a kind with no melee attack for its own reasons.
@onready var hitbox: Area3D = get_node_or_null("Hitbox")


## Story 4-3c (AC 4): this unit's RIG PRESENTATION controller, exposed exactly as `hitbox`
## above is exposed and for the same shape of reason -- one consumer, the runner, which pushes
## it the liveness/phase/velocity payload from `_aim_unit_actors`'s existing per-tick call.
##
## THE ACTOR RESOLVES ITS OWN CHILD; THE RUNNER DRIVES IT. There is no separate spawn-seat
## wiring call because there is nothing to wire: the controller is scene-authored in
## unit_actor.tscn with its AnimationPlayer path exported (the hero's own AnimationController
## precedent), so `$AnimationController` is already correct the moment the scene instantiates.
## This node NEVER calls into it -- no gameplay logic gained a seat here (see the header).
##
## STORY 4-4 (AC 3/AC 5): `get_node_or_null` for `hitbox`'s reason applied to the rig. A totem is a
## static structure (`4-4/R12`) with no walk, no swing and no death animation to select between, so
## `totem_actor.tscn` carries no `AnimationController` and this reads null there. The runner's push
## site guards it rather than every kind carrying a controller with nothing to control.
@onready var animation: UnitAnimationController = get_node_or_null("AnimationController")


## ------------------------------------------------------------------------------------------
## STORY 6-5b (AC 2, `6-5b/R1`/`6-5b/R2`): THE CORPSE TIMER IS GONE FROM THIS FILE.
## ------------------------------------------------------------------------------------------
## `const LINGER_TICKS := 600` and `var _linger_ticks := -1` STOOD HERE and are DELETED, not kept
## alongside -- the `attack_move_speed_multiplier` half-migration precedent: two countdowns for one
## corpse would be two sources of truth, and the first thing they would need is a rule for what
## happens when they disagree.
##
## 4-3d's OWN RULING PUT THEM HERE and 6-5b supersedes it, because the corpse became GAME STATE: Grave
## Ward EXTENDS its lifetime and Raise Dead CONSUMES it, and neither can reach a field on a
## presentation node. The authoritative countdown is now `UnitBoard._corpse_ticks`, converted from the
## authored `BalanceConfig.corpse_lifetime_seconds` (default 20 s, replacing the hardcoded 10 s).
##
## WHAT REMAINS HERE IS PURE REACTION, which is the HARD RULE on state/visual separation working as
## intended: this node is HANDED its remaining lifetime and its extended mark by the runner and drives
## its own visual/collision lifecycle from those values alone. It never re-derives them, never counts
## and never decides when it dies -- `MatchRunner._free_dead_unit_actors` frees it when STATE says the
## corpse is gone (AC 25).

## True once this actor has been told it is a corpse. Read by the runner to tell the FIRST observation
## of death from every later one, which is what keeps `begin_corpse_linger()` idempotent.
##
## A PLAIN BOOL NOW, WHERE IT USED TO BE `_linger_ticks >= 0`. The predicate is unchanged for every
## caller (`test_unit_combat_live.gd` reads it); what changed is that it no longer doubles as the read
## of a countdown this file does not own.
var _is_corpse := false

## The remaining corpse lifetime in ticks, AS STATE LAST REPORTED IT (AC 2). WRITE-ONLY from this
## node's perspective: it is assigned by `on_corpse_state()` and read by nothing here and nothing in
## `src/state/`. It exists so the value is inspectable from an integration test without reaching into
## the board, and so a future clip/fade can react to "nearly gone" without inventing a second clock.
##
## NEVER DECREMENTED HERE. A `-= 1` on this line would resurrect exactly the second countdown AC 2
## deletes, and it would drift the moment Grave Ward extended the real one.
var _corpse_ticks_remaining := 0

## True once state has reported this corpse as Grave-Ward-extended. LATCHED rather than mirrored,
## because the tint is applied once and `6-5b/R7` scopes the mark to the corpse's whole remaining life
## -- and because re-applying a material override every tick for 20 s is work with no effect.
##
## THE LATCH LIVES ON THE ACTOR AND THE TINT IS APPLIED BY THE RUNNER, and the split is deliberate:
## the runner already owns this project's ONE mesh-tint mechanism (`_tint_mesh_recursive`, which
## duplicates each `MeshInstance3D`'s material so one unit's tint cannot bleed into another's shared
## resource), and a second copy of that walk in this file is exactly the drift the totem tint's own
## comment warns about. What belongs HERE is the per-corpse memory of whether it has happened yet,
## because that memory is freed with the node it describes.
var _extended_tint_applied := false


func is_lingering() -> bool:
	return _is_corpse


## Story 6-5b (AC 2/AC 24): the actor's ONE read of state-owned corpse data, pushed by
## `MatchRunner._free_dead_unit_actors` on every tick this actor is observed dead.
##
## IT RECEIVES VALUES, NEVER A HANDLE. No `UnitBoard`, no `PlayerState` and no `MatchState` reference
## crosses into this node -- two plain scalars, the `UnitAnimationController.on_unit_tick` push shape
## verbatim, so the state/visual dependency still points one way only.
##
## IT RECORDS THE MARK BUT DOES NOT DRAW IT (see `_extended_tint_applied`): it returns whether THIS
## call is the rising edge, and the runner does the tinting with the mechanism it already owns.
##
## THE MARK IS AC 24 and it is never removed once set. `6-5b/R7`: it lasts "until that corpse is
## removed (expired or raised), not for a fixed window" -- and removal frees this whole node, so there
## is no un-tint path to write and no state in which a tinted actor outlives the corpse it marks.
func on_corpse_state(remaining_ticks: int, extended: bool) -> bool:
	_corpse_ticks_remaining = remaining_ticks
	if not extended or _extended_tint_applied:
		return false
	_extended_tint_applied = true
	return true


## Story 6-5b (AC 2): the remaining lifetime this actor was last handed. Read by the integration
## tests, which is the whole reason it is exposed -- a test asserting the corpse lifecycle should read
## what the ACTOR was told, so a runner that stopped pushing fails the test rather than passing it by
## reading the board directly.
func corpse_ticks_remaining() -> int:
	return _corpse_ticks_remaining


## Story 7-1 (AC 8) DELETED `EXTENDED_CORPSE_TINT` (6-5b's cold blue-white placeholder), whose runner-side tint
## looked for a child named `Mesh` the shipped rigged minion does not have, so nothing showed at the `6-5b`
## smoke. The Grave Ward look -- a green glow on the body and ghosts circling above -- is
## `EffectPresenter.set_grave_ward`'s, level-triggered by the runner from the board's own mark every tick. The
## latch above still records the mark for this actor's own life; it no longer gates any drawing.


## Story 4-3d (AC 2/3/4): begin the linger. Called by `MatchRunner._free_dead_unit_actors` on the
## tick a live actor is first observed dead, and a no-op on every tick after that.
##
## The collision disable is DEFERRED, and that half is AC 4's -- see `disable_all_collision()`.
## STORY 6-5b (AC 2): it no longer SEEDS a countdown -- there is none here to seed. It marks this actor
## a corpse and disables its collision, and that is all it ever did besides the timer.
func begin_corpse_linger() -> void:
	if _is_corpse:
		return
	_is_corpse = true
	# Story 4-3d (AC 4): OUT OF THE PHYSICS CALLBACK. The only caller reaches this from inside
	# `MatchRunner._physics_process`, so the write is deferred to the end of the frame.
	#
	# THE AC'S STATED RATIONALE WAS MEASURED FALSE AND IS CORRECTED HERE, not carried. AC 4
	# assumed -- and explicitly flagged as an assumption for this dev pass to confirm live -- that
	# setting `CollisionShape3D.disabled` / `Area3D.monitorable` / `Area3D.monitoring` from inside
	# a physics callback makes the engine emit an `^ERROR:` line, which `test/run_all.sh`
	# (`:18-19`, `:32-33`) greps for and fails the suite on. MEASURED on this build (4.6.3) by
	# running exactly this call INLINE and driving a real kill through test_unit_combat_live.gd:
	# stderr carried NO `ERROR:` line and no `SCRIPT ERROR`, and all three writes took effect.
	# Godot's "function blocked" guard fires while the physics server is FLUSHING SIGNALS, and
	# `_physics_process` is not inside that flush.
	#
	# THE DEFERRAL STAYS ANYWAY, because AC 4 requires the SEAT, not the rationale -- and the seat
	# is independently the right one: it is the only version that stays correct if this disable is
	# ever reached from an `area_entered`/`body_entered` handler, which IS inside the flush. It
	# costs one frame of live collision on the death tick, and the runner's next gather has not
	# run within that frame.
	disable_all_collision.call_deferred()


## Story 6-5b (AC 2): `advance_corpse_linger()` STOOD HERE and is DELETED with the countdown it
## advanced. Nothing replaces it: the corpse's clock is `UnitBoard._corpse_ticks`, advanced inside
## `MatchState.advance()` step 2 like every other D4 timer, and this node is handed the result through
## `on_corpse_state()` above. The F1 property the deleted function's own comment defended is
## unchanged and now stronger -- there is no timer on this node at all to tick itself.


## Story 4-3d (AC 4): make the corpse INERT to physics -- ALL THREE collision nodes, not a subset,
## and each by the property that actually carries its live capability (measured against
## `unit_actor.tscn`, where the three ship with different flags already set):
##
##   `Collision`  CollisionShape3D -- `disabled`. This is the BODY shape; disabling it is what
##                lets a hero walk THROUGH the corpse instead of being stopped by it (AC 4's
##                walk-through observable).
##   `Hurtbox`    Area3D on layer 2, `monitoring` already false -- so what makes it DETECTABLE is
##                `monitorable` (default true), not `monitoring`. Left live, a corpse would keep
##                answering the hero hitbox's `get_overlapping_areas()` query and write facts into
##                the intent recorder's contact channel. Gameplay is not at risk
##                (`match_state.gd`'s dead-target drop discards a fact landing on a dead record
##                before dedupe and `register_swing_hit`) -- this is a recording/replay-stream
##                CLEANLINESS requirement, which is exactly why it needs its own guard.
##   `Hitbox`     Area3D, `monitorable` already false -- so its live property is `monitoring`,
##                the thing that makes its own `get_overlapping_areas()` return anything.
##
## NEVER CALLED DIRECTLY FROM A PHYSICS CALLBACK -- see `begin_corpse_linger()`.
##
## STORY 4-4 (AC 3): EACH NODE IS RESOLVED DEFENSIVELY, because `totem_actor.tscn` carries no
## `Hitbox`. The three reasons above are unchanged for the nodes that exist; a node a scene does not
## author cannot be live, so skipping it disables exactly as much as there is to disable.
func disable_all_collision() -> void:
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.monitorable = false
	var hit := get_node_or_null("Hitbox") as Area3D
	if hit != null:
		hit.monitoring = false


## Story 4-3b (AC 12): yaw this box along an ALREADY-DECIDED planar heading, rather than at a
## position it must derive one from. The `aim_at()` twin below, and the ONE difference is who owns
## the direction: `aim_at()` is told WHERE the target is and looks at it, this is told WHICH WAY to
## face and obeys.
##
## IT EXISTS BECAUSE THE ATTACK DIRECTION LOCKS AT WINDUP START AND THE HITBOX IS A CHILD OF THIS
## ROOT. While a unit is swinging, its heading is the LOCKED one the state layer captured (a value
## that must NOT be recomputed -- that is the whole point of the lock), so the runner stops aiming
## the box at the live target and drives it from that stored direction instead. Aiming at the live
## target through a windup would swing the hitbox with a target that stepped aside, which is exactly
## the late-locking tracking `4-3b/R9` defers to per-kind movesets.
##
## STILL NO DECISION HERE. The direction was decided inside `advance()`; this is the same
## told-the-answer relationship `aim_at()` already has with `TargetingService`.
##
## A ZERO HEADING HAS NO DIRECTION and KEEPS the current rotation, on `aim_at()`'s own precedent: a
## unit that has never had a fact against its target has no locked direction yet, and snapping it to
## an arbitrary one would read as a glitch.
func aim_along(planar_dir: Vector2) -> void:
	if planar_dir.is_zero_approx():
		return
	# The same -Z-forward convention `aim_at()` uses; see its note.
	global_rotation.y = atan2(planar_dir.x, planar_dir.y) + PI


## Yaw this box toward `target_position`, PLANAR (XZ) only -- the runner's own facing derivation for
## the hero mesh, applied to a whole node instead of a child. A target directly overhead or exactly
## coincident has no planar direction, so the current rotation is KEPT rather than snapped to an
## arbitrary one: a unit whose target vanished stays pointing where it last looked, which reads as
## "still aiming at where it was" rather than as a glitch.
func aim_at(target_position: Vector3) -> void:
	var planar := Vector2(target_position.x - global_position.x,
			target_position.z - global_position.z)
	if planar.is_zero_approx():
		return
	# atan2(x, z) is Godot's -Z-forward yaw convention: a Node3D looks down its own -Z.
	global_rotation.y = atan2(planar.x, planar.y) + PI


## Story 4-3 (AC 1/AC 3, `4-3/R8`): WALK toward `target_position` at `speed`, stopping once within
## `stop_distance` of it. PLANAR (XZ) exactly like `aim_at()` above -- the arena is flat, units
## spawn on the ground, and nothing here climbs -- so the y component of the velocity stays zero
## and a target at a different height never drags the box off the floor.
##
## THE ACTOR OWNS THE MOVE, THE RUNNER OWNS THE LOOKUP. Everything decided is decided elsewhere:
## WHICH target is TargetingService's answer inside `advance()`, WHERE that target is is
## `_target_world_position`'s translation of the `[slot, index]` pair, and HOW FAST and HOW CLOSE
## are authored balance the caller reads inline at point of use. What is left here is arithmetic
## and `move_and_slide()`.
##
## HOLDS STILL RATHER THAN DRIFTING, on `aim_at()`'s no-planar-direction precedent: a target
## already inside `stop_distance` -- or coincident, which has no direction to move along -- zeroes
## the velocity and returns. A unit with no acquired target never reaches this method at all (the
## caller skips it), which is the same "stays where it is" answer arrived at one level up.
##
## `_delta` IS UNUSED AND THAT IS THE HERO PRECEDENT, not an oversight: `HeroActor.drive()` takes
## the same parameter and ignores it for the same reason -- `move_and_slide()` reads the physics
## delta from the engine itself. It is in the signature because the caller is the drive phase and
## both drive calls look alike.
func approach(target_position: Vector3, speed: float, stop_distance: float, _delta: float) -> void:
	var to_x := target_position.x - global_position.x
	var to_z := target_position.z - global_position.z
	var distance := sqrt(to_x * to_x + to_z * to_z)
	if distance <= stop_distance or distance <= 0.0:
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	velocity = _steered(Vector3(to_x / distance * speed, 0.0, to_z / distance * speed))
	move_and_slide()


## ------------------------------------------------------------------------------------------
## STORY 7-3, FEEL PASS: SEPARATION, A TURN RATE AND THE MOTION ACTUALLY MADE. Same posture as
## everything above: told the answer, planar, no decision, no state handle, no balance copy.
## ------------------------------------------------------------------------------------------

## The steering the runner handed this unit for its NEXT move, and nothing after it: the summed
## away-from-neighbour push (each neighbour weighted 0 at the kind's separation distance, 1 when
## touching), the most speed it may add, and which way round this unit goes when a neighbour is
## dead ahead.
var _separation_push := Vector2.ZERO
var _separation_speed := 0.0
var _separation_side := 1.0

## Where this unit stood when `take_motion()` last asked, and whether it has asked yet.
var _motion_from := Vector3.ZERO
var _motion_sampled := false


## Hand this unit its separation steering for the next `approach()` / `back_away()` / `circle()`.
## The runner computes `push` from where the other units stand; the unit only bends its own move by
## it. A rooted unit and a leaping one (`travel()`) ignore it and drop it: nothing is ever shoved,
## and steering handed for one tick never bends a later one.
func set_separation(push: Vector2, max_speed: float, side: float) -> void:
	_separation_push = push
	_separation_speed = max_speed
	_separation_side = side


## `wanted` bent by the pending separation steering, which is spent. The part of `wanted` that heads
## INTO the neighbours is taken out and turned sideways, so a unit whose way is blocked goes round
## instead of pressing on (two bodies pressing is the "stuck" the live smoke saw); on top of that it
## drifts away from them. Never faster than `wanted` plus the authored extra.
func _steered(wanted: Vector3) -> Vector3:
	var push := _separation_push
	_separation_push = Vector2.ZERO
	# A unit that is not moving is not steered: a hound rooted in its bite (driven at speed zero)
	# stays exactly where it stands, whoever is beside it.
	if push.is_zero_approx() or wanted.is_zero_approx():
		return wanted
	var away := push.normalized()
	var weight := minf(push.length(), 1.0)
	var planar := Vector2(wanted.x, wanted.z)
	var into := -planar.dot(away)
	if into > 0.0:
		var cross := planar.x * away.y - planar.y * away.x
		var side := _separation_side if absf(cross) < 0.1 * planar.length() else signf(cross)
		planar += away * into * weight
		planar += Vector2(away.y, -away.x) * side * into * weight
	planar += away * _separation_speed * weight
	var limit := Vector2(wanted.x, wanted.z).length() + _separation_speed
	if planar.length() > limit:
		planar = planar.normalized() * limit
	return Vector3(planar.x, 0.0, planar.y)


## Yaw toward `target_position` by at most `max_step` radians -- `aim_at()` with a turn rate. The
## runner passes the kind's authored rate times the tick; `aim_at()`'s no-planar-direction answer.
func turn_toward(target_position: Vector3, max_step: float) -> void:
	var planar := Vector2(target_position.x - global_position.x,
			target_position.z - global_position.z)
	if planar.is_zero_approx():
		return
	var wanted := atan2(planar.x, planar.y) + PI
	global_rotation.y += clampf(angle_difference(global_rotation.y, wanted), -maxf(0.0, max_step),
			maxf(0.0, max_step))


## Feel pass 2: `turn_toward()` for an ALREADY-DECIDED planar heading -- `aim_along()` with a turn
## rate. A zero heading keeps the current rotation, `aim_along()`'s own answer.
func turn_along(planar_dir: Vector2, max_step: float) -> void:
	if planar_dir.is_zero_approx():
		return
	var wanted := atan2(planar_dir.x, planar_dir.y) + PI
	global_rotation.y += clampf(angle_difference(global_rotation.y, wanted), -maxf(0.0, max_step),
			maxf(0.0, max_step))


## ------------------------------------------------------------------------------------------
## STORY 7-3, FEEL PASS 2: THE SWING'S TRAVEL AND PASSING. Told the answer, as everything here is.
## ------------------------------------------------------------------------------------------

## How far the swing numbered `_swing_travel_swing` (the unit's own swing counter, as state counts
## it) travels during its ACTIVE window. Handed over by the runner when the swing begins and spent by
## its drive phase; -1 until a first swing has been seen.
var _swing_travel_swing := -1
var _swing_travel_distance := 0.0

## The bodies this unit is passing (see `start_passing()`); empty when it passes none.
var _passed: Array[PhysicsBody3D] = []
var _is_passing := false


func set_swing_travel(swing: int, distance: float) -> void:
	_swing_travel_swing = swing
	_swing_travel_distance = maxf(0.0, distance)


func swing_travel_is_for(swing: int) -> bool:
	return _swing_travel_swing == swing


## The travel fixed for swing `swing`, or 0.0 when what this unit holds is some other swing's.
func swing_travel(swing: int) -> float:
	return _swing_travel_distance if _swing_travel_swing == swing else 0.0


func is_passing() -> bool:
	return _is_passing


## Stop colliding with `bodies`, and they with this unit, until `stop_passing()`: it goes through them
## and they are neither stopped nor shoved by it. BODIES ONLY -- this unit's hitbox and hurtbox are
## areas and overlap what they always overlapped. Nothing else is excepted, so a wall still stops it.
func start_passing(bodies: Array[PhysicsBody3D]) -> void:
	stop_passing()
	_is_passing = true
	for body: PhysicsBody3D in bodies:
		if not is_instance_valid(body) or body == self:
			continue
		add_collision_exception_with(body)
		body.add_collision_exception_with(self)
		_passed.append(body)


func stop_passing() -> void:
	for body: PhysicsBody3D in _passed:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
			body.remove_collision_exception_with(self)
	_passed.clear()
	_is_passing = false


## How far this body already FACES the planar heading `planar_dir`: 1.0 facing it, 0.0 square to it or
## turned away (the cosine between its own -Z and the heading, never below zero). The runner scales a
## reposition's or a retreat's speed by it, so the body turns and then goes. A zero heading is 1.0:
## nothing to face, nothing held back.
func alignment_with(planar_dir: Vector2) -> float:
	if planar_dir.is_zero_approx():
		return 1.0
	var forward := -global_transform.basis.z
	var facing := Vector2(forward.x, forward.z)
	if facing.is_zero_approx():
		return 1.0
	return clampf(facing.normalized().dot(planar_dir.normalized()), 0.0, 1.0)


## Run straight AHEAD (this body's own -Z) at `speed`: the run-on after a leap. `travel()`'s shape,
## along the heading the body already has, and steered round its neighbours like any ordinary move.
func run_ahead(speed: float) -> void:
	if speed <= 0.0:
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	var forward := -global_transform.basis.z
	var planar := Vector2(forward.x, forward.z)
	if planar.is_zero_approx():
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	planar = planar.normalized() * speed
	velocity = _steered(Vector3(planar.x, 0.0, planar.y))
	move_and_slide()


## The planar velocity this unit ACTUALLY had since the last call, in its OWN frame: x is to its
## right, y is forward (its -Z). Measured from where it stood then and where it stands now, not read
## off `velocity` -- a body the physics server moves has no velocity to read, and a blocked one has
## one it is not making. Zero on the first call. Called once per tick by the runner, for the rig.
func take_motion(delta: float) -> Vector2:
	var here := global_position
	if not _motion_sampled or delta <= 0.0:
		_motion_sampled = true
		_motion_from = here
		return Vector2.ZERO
	var moved := (here - _motion_from) / delta
	_motion_from = here
	var right := global_transform.basis.x
	var forward := -global_transform.basis.z
	return Vector2(moved.x * right.x + moved.z * right.z, moved.x * forward.x + moved.z * forward.z)


## ------------------------------------------------------------------------------------------
## STORY 7-3 (ACs 9, 12, 14): THREE MORE MOVES AND THE OWNER SKIN. Every one is `approach()`'s shape:
## told the answer, PLANAR, no decision, no state handle, no balance copy.
## ------------------------------------------------------------------------------------------
## WHICH move a unit makes on a tick is the RUNNER's read of the unit's board record (its attack
## phase and its behaviour phase); how long it keeps making it is a STATE tick timer (`7-3/R20`).
## Nothing below ends a phase, reports an arrival or asks where anything else is.

## Story 7-3 (AC 9, `7-3/R21`): move along an ALREADY-LOCKED planar heading at `speed` -- the leap.
## The heading is the one state froze at windup start, so this does NOT home: a target that steps
## aside is leapt past. `aim_along()`'s twin with a translation, and it keeps that method's
## zero-heading answer: no direction means no move.
func travel(planar_dir: Vector2, speed: float) -> void:
	# A leap is never steered, and the steering handed for this tick is not kept for a later move.
	_separation_push = Vector2.ZERO
	if planar_dir.is_zero_approx() or speed <= 0.0:
		velocity = Vector3.ZERO
		return
	var heading := planar_dir.normalized()
	velocity = Vector3(heading.x * speed, 0.0, heading.y * speed)
	move_and_slide()


## Story 7-3 (AC 12): step straight AWAY from `target_position` at `speed`, until `hold_distance`
## separates the two; then hold still. The distance is where the motion stops being useful, not a
## transition -- the back-off ends when its state timer says so, wherever the unit stands.
func back_away(target_position: Vector3, speed: float, hold_distance: float) -> void:
	var from_x := global_position.x - target_position.x
	var from_z := global_position.z - target_position.z
	var distance := sqrt(from_x * from_x + from_z * from_z)
	if distance >= hold_distance or distance <= 0.0 or speed <= 0.0:
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	velocity = _steered(Vector3(from_x / distance * speed, 0.0, from_z / distance * speed))
	move_and_slide()


## Story 7-3 (AC 12): CIRCLE `target_position` at `radius`, at `speed`, in `direction`
## (`UnitBoard.CIRCLE_CLOCKWISE` is clockwise seen from above; anything else is the other way).
## Each tick it steers at the point one step further round the circle, so a unit that starts inside
## or outside the radius spirals onto it and never needs to "arrive" first.
func circle(target_position: Vector3, speed: float, radius: float, direction: int, delta: float) -> void:
	var move := circle_move(target_position, speed, radius, direction, delta)
	if move.is_zero_approx():
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	velocity = _steered(Vector3(move.x, 0.0, move.y))
	move_and_slide()


## The planar velocity `circle()` gives this body for the same arguments, before any steering: toward
## the point one step further round the circle, never faster than `speed`. Zero when there is no such
## move. Exposed (feel pass 2) so the runner can turn a repositioning body the way it is about to go,
## which while it spirals onto its radius is not the tangent.
func circle_move(target_position: Vector3, speed: float, radius: float, direction: int, delta: float) -> Vector2:
	var from_x := global_position.x - target_position.x
	var from_z := global_position.z - target_position.z
	var distance := sqrt(from_x * from_x + from_z * from_z)
	if distance <= 0.0 or speed <= 0.0 or radius <= 0.0 or delta <= 0.0:
		return Vector2.ZERO
	var step := speed * delta / radius
	if direction != UnitBoard.CIRCLE_CLOCKWISE:
		step = -step
	var cos_step := cos(step)
	var sin_step := sin(step)
	var next_x := target_position.x + (from_x * cos_step - from_z * sin_step) / distance * radius
	var next_z := target_position.z + (from_x * sin_step + from_z * cos_step) / distance * radius
	var move := Vector2(next_x - global_position.x, next_z - global_position.z) / delta
	if move.length() > speed:
		move = move.normalized() * speed
	return move


## Story 7-3, feel pass 3: ORBIT `target_position` -- `circle()`'s arguments and its way round, moved
## as a STRAFE. The body goes ROUND at `speed`, and only up to `approach_share` of that speed goes into
## getting onto (or staying on) `radius`; the rest is along the tangent. So a unit that begins its
## orbit inside or outside the ring spirals onto it sideways instead of walking straight out to it.
func orbit(target_position: Vector3, speed: float, radius: float, direction: int, approach_share: float,
		delta: float) -> void:
	var from := Vector2(global_position.x - target_position.x, global_position.z - target_position.z)
	var distance := from.length()
	if distance <= 0.0 or speed <= 0.0 or radius <= 0.0 or delta <= 0.0:
		velocity = Vector3.ZERO
		_separation_push = Vector2.ZERO
		return
	var out := from / distance
	# The tangent of `circle()`'s own rotation, the same way round.
	var tangent := Vector2(-out.y, out.x)
	if direction != UnitBoard.CIRCLE_CLOCKWISE:
		tangent = -tangent
	var limit := speed * clampf(approach_share, 0.0, 1.0)
	var radial := clampf((radius - distance) / delta, -limit, limit)
	var move := out * radial + tangent * sqrt(maxf(speed * speed - radial * radial, 0.0))
	velocity = _steered(Vector3(move.x, 0.0, move.y))
	move_and_slide()


## Story 7-3 (AC 14, `7-3/R7`): the materials this scene shows per OWNER SLOT, index 0 for P1 and 1
## for P2, and the mesh that wears them. Authored on the scene; EMPTY on `unit_actor.tscn` and
## `totem_actor.tscn`, which have no owner colour and are left exactly as they were.
@export var owner_skins: Array[Material] = []
@export var skin_mesh_path: NodePath


## Story 7-3 (AC 14): wear the skin of the slot that OWNS this unit's record. Called once by the
## runner at spawn. The colour follows the record's owner and nothing else: a corpse keeps it
## because it is the same actor, and a raised unit gets it again because it is spawned for the same
## slot. Returns whether a skin was applied.
func apply_owner_skin(slot: int) -> bool:
	if slot < 0 or slot >= owner_skins.size() or owner_skins[slot] == null:
		return false
	var mesh := get_node_or_null(skin_mesh_path) as MeshInstance3D
	if mesh == null:
		return false
	mesh.material_override = owner_skins[slot]
	return true
