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
## POOLED BY NOBODY THIS STORY (4-5). Units are plain instantiated and `queue_free()`d nodes here;
## 4-5's tier is assigned at this story's close-out.
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


## Story 4-3d (AC 3): the CORPSE LINGER, in TICKS. 10 s at the 60 Hz `project.godot` pin
## (`common/physics_ticks_per_second=60`), which is the only clock this project counts in.
##
## NOT AUTHORED AND NOT A `BalanceConfig` FIELD, by the story's own Non-Goals: this is a
## lifecycle mechanism, not a tuning pass -- the same posture `4-3c` took for the idle/walk
## epsilon directly above.
const LINGER_TICKS := 600

## Ticks elapsed since this actor was first observed dead. `-1` means "not a corpse", which is
## also what makes `begin_corpse_linger()` idempotent -- the runner observes death on EVERY tick
## after it happens, not once.
##
## THE TIMER LIVES HERE, ON THE ACTOR, AND THAT IS THE RULING (AC 3), not a convenience. Two
## measured reasons. A runner-local parallel array would survive the debug reset that clears
## `_unit_actors` -- leaking stale entries, or needing its own reset-relay wiring that a
## per-actor field does not, because the field is freed WITH the node it lives on. And counting
## TICKS rather than wall-clock seconds is what makes the linger honour `3-0b`'s deterministic
## step/pause: the runner only calls `advance_corpse_linger()` from inside its `ticking` gate, so
## a corpse held under the debug pause does not age out mid-inspection.
var _linger_ticks := -1


## True once this actor has been told it is a corpse. Read by the runner to tell the FIRST
## observation of death from every later one.
func is_lingering() -> bool:
	return _linger_ticks >= 0


## Story 4-3d (AC 2/3/4): begin the linger. Called by `MatchRunner._free_dead_unit_actors` on the
## tick a live actor is first observed dead, and a no-op on every tick after that.
##
## The collision disable is DEFERRED, and that half is AC 4's -- see `disable_all_collision()`.
func begin_corpse_linger() -> void:
	if _linger_ticks >= 0:
		return
	_linger_ticks = 0
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


## Story 4-3d (AC 3): advance the linger by one tick and report whether it has expired. Called by
## the runner from a seat inside its `ticking` gate, so paused ticks do not age a corpse.
##
## NO `_physics_process` HERE (INVARIANT F1 -- the runner owns the only one). A timer that ticked
## itself would be a second one, and would also age through the debug pause.
func advance_corpse_linger() -> bool:
	_linger_ticks += 1
	return _linger_ticks >= LINGER_TICKS


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
		return
	velocity = Vector3(to_x / distance * speed, 0.0, to_z / distance * speed)
	move_and_slide()
