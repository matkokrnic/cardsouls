class_name ProjectileActor
extends Node3D

## Story 4-4 (AC 14/AC 15): the LIVE PROJECTILE in the world — "a distinct entity in the world (not
## an instant hit) that travels from the totem toward its target rather than resolving contact
## immediately".
##
## NO GAMEPLAY LOGIC LIVES HERE, on the `UnitActor` / `HeroActor` precedent and the project-context
## HARD RULE that puts it there: no `_physics_process` (INVARIANT F1 — the runner owns the only one),
## no `Input`, no state handle, no signal into state, no damage, no targeting, no AI, and no decision
## about its own life. It is spawned by the runner, steered by the runner, and freed by the runner
## when the state layer says its flight is over.
##
## IT OWNS EXACTLY ONE THING: ITS HEADING. That is the same split every actor in this project has —
## `4-3/R2` keeps position actor-owned, and a heading is the derivative of a position. What the STATE
## layer owns is whether the heading may still be UPDATED (`ProjectileBoard._homing`, AC 16), how
## far the shot moves this tick (`MatchState.projectile_step_distance_at`, derived from the authored
## profile) and when the flight ends (the 60 m odometer, AC 19). The runner reads all three and
## drives this node.
##
## WHY THE HEADING IS HERE AND NOT IN STATE. Steering toward "the target's current position" (AC 15)
## needs a position, and no position may travel inward (`4-3/R2`: `push_contact` is the only inward
## intake, and it carries a RELATION, never a location). So the runner — which already owns every
## actor's transform and already resolves a `[slot, index]` pair to a world position for the unit
## approach — does the steering, and the state layer decides only whether steering is still allowed.
## The heading needs no snapshot key of its own: it is a pure function of the positions the runner
## already has plus the homing flag that IS snapshotted, so a replay reproduces it exactly.
##
## A HITBOX AND NOTHING ELSE. Unlike a unit this carries no body collision and no hurtbox: a
## projectile is not blocked by anything, cannot be walked into, and cannot itself be hit. It is
## detected by nothing and detects hurtboxes, which is precisely what layer 3 / mask 2 already means
## in this project — the SAME convention `hero.tscn` and `unit_actor.tscn` already declare, reused
## rather than extended, so `project.godot` and both existing scenes stay byte-identical.

## The world-space PLANAR heading this shot is travelling along, as a unit vector in the XZ plane.
##
## PLANAR FOR THE REASON `UnitActor.approach()` IS PLANAR: the arena is flat, everything spawns on
## the ground, and nothing here climbs — so a target at a different height never drags the shot off
## the floor and a hurtbox is never missed by flying over it.
##
## IT PERSISTS ACROSS TICKS AND THAT IS THE WHOLE MECHANISM OF AC 16. When the state layer ends
## homing, the runner simply STOPS CALLING `steer_toward()`; this value is the last one steering
## produced, and `advance_flight_by()` keeps using it. "The projectile keeps its last heading and
## travels in a straight line" is therefore the ABSENCE of an update rather than a special mode, and
## there is no straight-line branch anywhere to fall out of step with the homing one.
var heading := Vector3.FORWARD


## Point this shot along `planar_dir` with no turn-rate limit — the LAUNCH orientation, called once
## by the runner on the tick the state layer created the record.
##
## UNLIMITED HERE, RATE-LIMITED IN `steer_toward()`, and the asymmetry is deliberate: a turn rate
## describes how a shot CHANGES course in flight, and a shot that has not yet flown has no course to
## change. Rate-limiting the launch would fire every projectile along whatever `Vector3.FORWARD`
## happened to be and let it curve toward the target over the first second, which reads as a bug.
##
## A ZERO DIRECTION KEEPS the current heading, the `UnitActor.aim_at()` precedent verbatim: a totem
## exactly coincident with its target has no direction to fire along, and snapping to an arbitrary
## one would read as a glitch.
func launch_toward(planar_dir: Vector3) -> void:
	var planar := Vector3(planar_dir.x, 0.0, planar_dir.z)
	if planar.is_zero_approx():
		return
	heading = planar.normalized()
	_face_heading()


## AC 15: turn the heading toward `target_position` by at most `turn_rate_degrees` this tick — the
## HOMING profile, authored (`4-4/R3`) and applied by the one implementation there is.
##
## A RATE LIMIT IS WHAT MAKES HOMING AVOIDABLE, which is the whole design intent behind `4-4/R9`'s
## "projectile avoidance is designed for a target that can roll": a shot that snapped to the target
## every tick could never be dodged by moving, only by i-frames. Turning at a bounded rate means a
## target moving laterally can out-turn the arc.
##
## CALLED ONLY WHILE THE STATE LAYER SAYS HOMING IS LIVE. The runner checks
## `ProjectileBoard.is_homing_at()` before calling; this node never asks and never decides.
##
## A ZERO OR COINCIDENT DIRECTION KEEPS the current heading, `launch_toward`'s precedent.
func steer_toward(target_position: Vector3, turn_rate_degrees: float) -> void:
	var to_target := Vector3(target_position.x - global_position.x, 0.0,
			target_position.z - global_position.z)
	if to_target.is_zero_approx():
		return
	var desired := to_target.normalized()
	var max_turn := deg_to_rad(maxf(turn_rate_degrees, 0.0)) / TimingWindow.TICK_HZ
	var angle := heading.signed_angle_to(desired, Vector3.UP)
	# CLAMPED, NOT SNAPPED: the shot turns the smaller of "all the way to the target" and "this
	# tick's authored allowance", which is what makes a zero authored turn rate degrade to flying
	# dead straight rather than to a special case.
	heading = heading.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn)).normalized()
	_face_heading()


## Move along the current heading by `distance` world units — one tick's worth.
##
## THE DISTANCE IS THE ONE THE STATE LAYER ALREADY SPENT FROM THE BUDGET, and it is now that number
## rather than a speed this function re-integrates. The runner passes
## `MatchState.projectile_step_distance_at()`, which returns what `_advance_projectiles` charged the
## odometer on the tick that just completed — so the distance flown here and the distance charged
## against the 60 m budget (AC 19) are ONE arithmetic rather than two that could drift apart over a
## long flight. It took a speed until review finding H2, and re-deriving the speed here read the
## flight clock one tick after the odometer had been charged.
##
## A PLAIN TRANSLATION, NOT `move_and_slide()`: this is a `Node3D`, not a body. A projectile is not
## blocked by terrain or by other bodies — it is stopped by a CONTACT, which the state layer decides
## from the hitbox overlap this node reports, and by its travel budget. Sliding along a wall would be
## a physics behaviour nothing in this story asks for.
func advance_flight_by(distance: float) -> void:
	global_position += heading * distance


## Yaw the node to match its heading. PRESENTATIONAL ONLY — nothing reads this rotation, including
## the hitbox, whose shape is a sphere centred on the node and therefore rotation-independent. It
## exists so a shot in the live smoke visibly points the way it is going.
##
## The same `atan2(x, z) + PI` convention `UnitActor.aim_at()` uses: Godot's -Z-forward yaw.
func _face_heading() -> void:
	if heading.is_zero_approx():
		return
	global_rotation.y = atan2(heading.x, heading.z) + PI
