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
@onready var hitbox: Area3D = $Hitbox


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
