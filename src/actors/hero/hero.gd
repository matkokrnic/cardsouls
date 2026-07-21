class_name HeroActor
extends CharacterBody3D

## Presentation actor for the hero. Has NO _physics_process (INVARIANT F1) — the runner drives
## it exactly once per tick via drive(). It reads HeroState.velocity (the D3 seam) and never the
## InputIntent; the actor is not even handed the intent, so the shortcut is structurally
## impossible. Position is actor-owned (F1); the state layer holds no world coordinates.

func drive(hero_state: HeroState, _delta: float) -> void:
	velocity = hero_state.velocity  # world velocity decided by advance(); never the raw intent
	move_and_slide()
