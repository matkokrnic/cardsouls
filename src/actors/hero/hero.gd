class_name HeroActor
extends CharacterBody3D

## Presentation actor for the hero. Has NO _physics_process (INVARIANT F1) — the runner drives
## it exactly once per tick via drive(). It reads HeroState.velocity (the D3 seam) and never the
## InputIntent; the actor is not even handed the intent, so the shortcut is structurally
## impossible. Position is actor-owned (F1); the state layer holds no world coordinates.
##
## Story 1-7: carries the Hitbox/Hurtbox Area3D pair (see their editor descriptions for the
## layer/mask convention). Neither holds gameplay logic; the runner queries the Hitbox for
## overlap FACTS and advance() decides (actors REPORT, state DECIDES).

## Read by the runner's step-2 fact gathering (get_overlapping_areas on the active swing).
@onready var hitbox: Area3D = $Hitbox


func drive(hero_state: HeroState, _delta: float) -> void:
	velocity = hero_state.velocity  # world velocity decided by advance(); never the raw intent
	# Story 1-7 (N6): the melee hitbox tracks state facing by rotating this CHILD node —
	# the hero ROOT never rotates (DECISION A: the camera rig is a child of the root, so a
	# root rotation would fold into the pushed camera basis). Facing (x, y) maps to world
	# (x, 0, y); yaw atan2(x, y) points the hitbox's local +Z reach along it. Presentation
	# reading state is the allowed dependency direction.
	hitbox.rotation.y = atan2(hero_state.facing.x, hero_state.facing.y)
	move_and_slide()
