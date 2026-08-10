class_name UnitActor
extends Node3D

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
## no AI. It is placed by the runner and it stands there. Movement and AI are 4-3's; HP, damage and
## death are 4-3's; totem-vs-minion differentiation is 4-4's.
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
## answer. Movement is still 4-3's; a rotation is not a move.
##
## IT EXISTS BECAUSE THE SMOKE NEEDED A VISIBLE SIGNAL. With movement out of scope (`4-2/R4`), "the
## unit does not sit permanently inert" is unfalsifiable by observation -- a unit that never moves
## gives a human nothing to watch for. `4-2/R13` rewrote the live smoke around this rotation instead.
##
## ROTATING THIS ROOT IS SAFE, unlike the hero's (DECISION A). The hero root must never rotate
## because the camera rig is its child, so a rotated root would fold hero rotation into the pushed
## camera basis; this scene's only child is a mesh, it carries no camera and nothing reads its basis.
## test_root_rotation_isolation.gd guards the HERO root and is untouched by this.


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
