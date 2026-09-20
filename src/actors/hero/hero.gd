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

## Story 5-0a (AC 3): the melee shape, MOVED every tick onto the paladin's sword bone by
## _track_weapon_bone(). Its authored transform in hero.tscn is the sword joint's REST position
## and is overwritten on the first drive() call — see that node's editor_description.
@onready var hitbox_shape: CollisionShape3D = $Hitbox/HitboxShape

## Story 5-0a (AC 3): the paladin's skeleton, read ONLY to locate the sword bone. A presentation
## node reading a presentation node; no state is written from it and it is never handed to the
## state layer.
@onready var skeleton: Skeleton3D = $Mesh/Paladin/Skeleton3D

## Story 1-7b: the visible body. Yawed from the SAME computed value as the Hitbox so the
## display can never diverge from where the hitbox aims.
@onready var mesh: MeshInstance3D = $Mesh

## Story 1-10: the per-hero D7 cues layer. Exposed so the RUNNER can wire its
## subscriptions through the connect seams at match start; nothing else touches it.
@onready var telegraph_controller: TelegraphController = $TelegraphController

## Story 3-0a: the per-hero rig animation layer. Exposed so the RUNNER wires it to the
## action-state seam at match start (the five ActionState-driven clips); drive() pushes the
## per-tick velocity AND facing to it for the locomotion clips (3-0a/R2, widened by 5-0a AC 2
## from speed-only to direction-aware), the ONE selection the transition-fired seam cannot
## carry. Presentation-only — never handed a state object.
@onready var animation_controller: AnimationController = $AnimationController

## Story 5-0a (AC 3): the Mixamo rig's WEAPON bone — a real joint on this skeleton
## (`mixamorig_Sword_joint`, a child of `mixamorig_RightHand`), not a hand-bone stand-in.
const SWORD_BONE := &"mixamorig_Sword_joint"

## Resolved once in _ready. -1 means the rig changed under us; _track_weapon_bone() then leaves
## the shape where the scene authored it rather than moving it somewhere wrong.
var _sword_bone: int = -1


## Story 6-6b POST-SMOKE (R-S1): PASS THROUGH ANOTHER HERO'S BODY, or stop doing so. Set for the
## length of RED's counter and cleared at its end, both by the runner off the same edge that starts
## and ends the counter presentation.
##
## WHY IT IS HERE AND NOT IN STATE: the state layer knows nothing about position, bodies or
## colliders (`4-3/R2`) -- it writes a velocity and `move_and_slide()` decides what that runs into.
## RED's counter travels the attacker's whole reach FORWARD and back again, so without this the
## slide stops dead on the attacker's collision box a metre short and the jump lands beside it
## rather than on it: the body would contradict what the state layer actually did, which is the rule
## this fix exists to restore. BLUE keeps its collision, ruled: its slide is SUPPOSED to arrive and
## stop (R-S2).
##
## A COLLISION EXCEPTION AND NOT A MASK EDIT, a dev-pass choice with a measured reason: the root
## body masks layer 1, which also carries the arena floor and the `5-0d` edge, so clearing the bit
## would let a countering hero leave the arena. `add_collision_exception_with` names the ONE body to
## ignore and nothing else, which is exactly what the ruling asks for and is reversible by name.
## Idempotent on both sides -- Godot's exception list is a set, and removing an absent entry is a
## no-op -- so the runner can push the same state on any tick without bookkeeping.
func set_body_pass_through(other: PhysicsBody3D, enabled: bool) -> void:
	if not is_instance_valid(other):
		return
	if enabled:
		add_collision_exception_with(other)
	else:
		remove_collision_exception_with(other)


func _ready() -> void:
	_sword_bone = skeleton.find_bone(SWORD_BONE)
	if _sword_bone < 0:
		push_error("HeroActor: rig has no bone '%s' — the melee hitbox " % SWORD_BONE
			+ "cannot follow the weapon and stays at its authored offset")


## `walk_speed`/`run_speed` (story 6-7b, AC 4): the AUTHORED gait pair, read inline off the applied
## config by the runner every tick and forwarded untouched to the animation controller -- plain
## floats, never a config reference (CONSTRAINT C). drive() itself does not use them.
func drive(hero_state: HeroState, _delta: float, walk_speed: float, run_speed: float) -> void:
	velocity = hero_state.velocity  # world velocity decided by advance(); never the raw intent
	# Story 1-7 (N6) / 1-7b: facing tracks state by rotating CHILD nodes — the hero ROOT
	# never rotates (DECISION A: the camera rig is a child of the root, so a root rotation
	# would fold into the pushed camera basis). Facing (x, y) maps to world (x, 0, y); yaw
	# atan2(x, y) points local +Z along it. ONE yaw, computed once, assigned to BOTH the
	# Hitbox (reach) and the Mesh (display) — a second independent mapping could drift and
	# let the visible body lie about hitbox aim (1-7b single-yaw-source contract).
	# Presentation reading state is the allowed dependency direction.
	var yaw := atan2(hero_state.facing.x, hero_state.facing.y)
	hitbox.rotation.y = yaw
	mesh.rotation.y = yaw
	# Story 5-0a (AC 3): and the SHAPE inside that Hitbox is moved onto the sword bone, so the
	# swept reach is where the blade actually is. POSITION ONLY — the shape's rotation is never
	# written, so `yaw` above remains the single rotation source for both the Hitbox and the
	# Mesh (1-7b contract). Sequenced after the yaw assignment because it reads the Hitbox's
	# global transform, which that assignment has just settled.
	_track_weapon_bone()
	# Story 3-0a (3-0a/R2), WIDENED BY 5-0a (AC 2): PUSH the per-tick locomotion payload to the
	# rig's animation controller on this same call. 3-0a pushed a scalar SPEED, which can only
	# split `run` from `idle`; since 4-6 pinned facing to the locked target, a hero strafing or
	# backing away is moving one way while facing another, and a scalar cannot tell those apart
	# — it played `run` for all of them, which is the skating the E4 close-out named. The
	# payload is now the velocity VECTOR plus the facing, and the controller resolves direction
	# from them by dot product. SAME call, SAME per-tick cadence: no new seam, no state handle,
	# no second _physics_process (F1 intact), and NO second atan2 (the yaw above is still the
	# only one) — the controller needs direction as DATA, never as a rotation.
	# Story 6-7b (AC 4/AC 6): widened again by the authored gait pair, for the walk/run family split.
	# Still the same call and cadence; the turn-in-place check rides it too, and reads facing only.
	animation_controller.on_locomotion(velocity, hero_state.facing, walk_speed, run_speed)
	move_and_slide()


## Moves the melee shape onto the sword bone's live animated position (AC 3). Before 5-0a the
## shape sat at a FIXED local z 0.9 and never moved relative to the root no matter what the arms
## were doing, so the visible swing and the damage volume were only loosely related.
##
## FORWARD KINEMATICS, NOT get_bone_global_pose(), and the reason is already measured in this
## repo (tools/measure_strike_frame.gd): Skeleton3D's GLOBAL pose cache refreshes at most once
## per frame, so it can serve a stale transform — and returns one constant outright in a
## frameless headless fixture. get_bone_pose() is the animated local transform read straight off
## the pose array with no cache, so composing the parent chain always reflects the most recent
## animation update. Nine multiplies for this rig's chain, once per hero per tick.
##
## The Hitbox NODE is untouched here: only its child shape's ORIGIN moves, expressed in the
## Hitbox's own local frame via to_local(). Nothing about the hero's rotation is derived,
## re-derived, or written — the shape inherits the one yaw drive() computed.
##
## SUB-FRAME LAG, stated rather than hidden: AnimationPlayer's default callback is IDLE, so it
## writes bone poses in _process, after this _physics_process-driven call. The pose read here is
## therefore the one the last rendered frame produced — the same class of bounded lag as the F1
## one-tick gather lag the contact pipeline already documents and asserts.
func _track_weapon_bone() -> void:
	if _sword_bone < 0:
		return
	var bone_world: Vector3 = skeleton.global_transform * _bone_pose_global(_sword_bone).origin
	hitbox_shape.position = hitbox.to_local(bone_world)


## Composes bone-local poses up the parent chain, skeleton-relative. get_bone_pose() is the
## animated transform relative to the PARENT bone (skeleton-relative for the root bone).
func _bone_pose_global(idx: int) -> Transform3D:
	var t := skeleton.get_bone_pose(idx)
	var parent := skeleton.get_bone_parent(idx)
	while parent >= 0:
		t = skeleton.get_bone_pose(parent) * t
		parent = skeleton.get_bone_parent(parent)
	return t
