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

## Story 7-8 (AC 11, `7-8/R9`): the HERO HIT SHAPE -- the `Hurtbox` area and its own shape, MOVED every
## tick onto the paladin's trunk bone by `_track_trunk_bone()`. Every hit consumer (melee, the unblockable
## blade, minion swings, projectiles) reads this area, so the volume a hit has to reach is the visible
## trunk rather than the 1 x 2 x 1 body box, which stays the BODY collision only (AC 12).
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurtbox_shape: CollisionShape3D = $Hurtbox/HurtboxShape

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

## Story 7-8 (AC 11, `7-8/R9`): the TRUNK bone the hit shape follows. `mixamorig_Spine2` (the chest) was
## chosen from the measured skinned-vertex envelope (`tools/measure_torso_envelope.gd`): of the four trunk
## candidates it has the smallest radial trunk excursion in block, attack, roll and jump_attack, and it
## travels WITH the trunk through the roll's sideways excursion while the hips joint stays put.
const TRUNK_BONE := &"mixamorig_Spine2"

## Story 7-8 (AC 11/AC 16): how far BELOW the trunk bone the hit shape's centre sits -- a presentation
## constant, measured with the shape's dimensions in `hero.tscn` (`CylinderShape3D_hurt`). The shape spans
## 0.45 above the bone (the head top, measured at most 0.443 above Spine2 in any clip) to 1.20 below it
## (the feet, 1.18 below in idle), so its 1.65 height is centred 0.375 below the bone.
const HURTBOX_DROP := 0.375

## Resolved once in _ready, `_sword_bone`'s shape. -1 leaves the hit shape where the scene authored it.
var _trunk_bone: int = -1

## Story 7-10 (AC 9): the head's top joint, read for RED's landing height (the attacker's head) at the press.
const HEAD_TOP_BONE := &"mixamorig_HeadTop_End"
var _head_top_bone: int = -1
## The head top above the root when the rig has no such bone: the measured idle HeadTop_End (1.554 above the
## feet, `tools/measure_head_visor.gd`) less the Mesh's 1.0 grounding offset, rounded.
const HEAD_TOP_FALLBACK_Y := 0.55

## Story 7-10 (S1/S4): the two presentation children the runner pushes per tick -- the unblockable EYES on the
## head bone and the post-knockdown IMMUNITY shimmer on the body. Built in `_ready`, no collision, no signal.
var eyes: UnblockableEyes
var immunity_shimmer: ImmunityShimmer

## Story 7-10 (Open Question 1, operator ruling): THE DISTANCE-AWARE RED LANDING -- the factor `drive()` scales
## the state's velocity by while a LANDED RED counter's travel runs, set by the runner every tick (1.0 otherwise,
## and for a counter the state has not landed). The runner locks a forward- and a back-leg factor at the landing
## from the actor-side gap, so the net stays zero. The state's velocity itself is untouched: this is what the
## BODY does with it, the `set_body_pass_through` footing (`4-3/R2`: no position crosses into state).
var counter_travel_scale := 1.0

## Story 7-10 (AC 9): how far the mesh is lifted, metres, this tick -- RED's landing arc, so the feet reach the
## attacker's head at contact. Set by the runner every tick; 0 at rest.
var counter_lift := 0.0

## Story 7-10 (AC 10/AC 13, M6): the presentation HITSTOP -- the rig's AnimationPlayer frozen and the mesh held
## where it stood while the root keeps moving, then eased back onto the root (`HITSTOP_CATCHUP_SECONDS`, Open
## Question 4). Counted in `drive()` calls, i.e. in the runner's ticks (F1); never read by state.
var _mesh_base := Vector3.ZERO
var _hitstop_ticks_left := 0
var _hitstop_anchor := Vector3.ZERO
var _hitstop_offset := Vector3.ZERO
var _catchup_ticks_left := 0
var _catchup_total := 0
var _catchup_from := Vector3.ZERO


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
	_trunk_bone = skeleton.find_bone(TRUNK_BONE)
	if _trunk_bone < 0:
		push_error("HeroActor: rig has no bone '%s' — the hit shape " % TRUNK_BONE
			+ "cannot follow the trunk and stays at its authored offset")
	_head_top_bone = skeleton.find_bone(HEAD_TOP_BONE)
	_mesh_base = mesh.position
	# Story 7-10: the eyes follow the head bone; a rig without one degrades to the root, where they stay dark
	# unless lit (`EffectFx.bone_follower`'s own degrade).
	eyes = UnblockableEyes.new()
	eyes.name = "UnblockableEyes"
	eyes.colors = {
		Enums.CardColor.RED: telegraph_controller.charge_red_profile.color,
		Enums.CardColor.BLUE: telegraph_controller.charge_blue_profile.color,
		Enums.CardColor.GREEN: telegraph_controller.charge_green_profile.color,
	}
	var head := EffectFx.bone_follower(self, self, UnblockableEyes.HEAD_BONE)
	(head if head != null else self as Node).add_child(eyes)
	immunity_shimmer = ImmunityShimmer.new()
	immunity_shimmer.name = "ImmunityShimmer"
	add_child(immunity_shimmer)


## `walk_speed`/`run_speed` (story 6-7b, AC 4): the AUTHORED gait pair, read inline off the applied
## config by the runner every tick and forwarded untouched to the animation controller -- plain
## floats, never a config reference (CONSTRAINT C). drive() itself does not use them.
func drive(hero_state: HeroState, _delta: float, walk_speed: float, run_speed: float) -> void:
	# World velocity decided by advance(); never the raw intent. Story 7-10 (OQ1): scaled by the RED counter's
	# landing factor, which is 1.0 at every other time.
	velocity = hero_state.velocity * counter_travel_scale
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
	# Story 7-8 (AC 11): the HIT SHAPE follows the trunk the same way, POSITION ONLY. The `Hurtbox` node is
	# never rotated and its cylinder is yaw-invariant, so `yaw` above stays the single rotation source.
	_track_trunk_bone()
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
	# Story 7-10: the mesh's presentation offsets, after the move so the hitstop hold measures this tick's root.
	_advance_hitstop()
	mesh.position = _mesh_base + Vector3(0.0, counter_lift, 0.0) + _hitstop_offset


## Story 7-10 (AC 10/AC 13): start a presentation hitstop of `seconds` -- the rig freezes and the mesh is held at
## the root's current position. A hitstop already running restarts from here.
func begin_hitstop(seconds: float) -> void:
	var t := UnblockablePresentation.ticks(seconds)
	if t <= 0:
		return
	_hitstop_ticks_left = t
	_hitstop_anchor = global_position - _hitstop_offset
	_catchup_ticks_left = 0
	animation_controller.set_frozen(true)


func is_in_hitstop() -> bool:
	return _hitstop_ticks_left > 0


## One tick of the hitstop: hold the mesh at the anchor while frozen, then ease the offset to zero.
func _advance_hitstop() -> void:
	if _hitstop_ticks_left > 0:
		_hitstop_offset = _hitstop_anchor - global_position
		_hitstop_ticks_left -= 1
		if _hitstop_ticks_left == 0:
			animation_controller.set_frozen(false)
			_catchup_total = UnblockablePresentation.ticks(UnblockablePresentation.HITSTOP_CATCHUP_SECONDS)
			_catchup_ticks_left = _catchup_total
			_catchup_from = _hitstop_offset
			if _catchup_total <= 0:
				_hitstop_offset = Vector3.ZERO
		return
	if _catchup_ticks_left > 0:
		_catchup_ticks_left -= 1
		_hitstop_offset = _catchup_from * (float(_catchup_ticks_left) / float(_catchup_total))
		return
	_hitstop_offset = Vector3.ZERO


## Story 7-10: every end path (debug reset, round start): the hitstop, its hold, the lift, the travel factor,
## the eyes and the shimmer all go back to rest, the `_free_counter_dagger` discipline.
func clear_presentation() -> void:
	if _hitstop_ticks_left > 0:
		animation_controller.set_frozen(false)
	_hitstop_ticks_left = 0
	_catchup_ticks_left = 0
	_hitstop_offset = Vector3.ZERO
	counter_lift = 0.0
	counter_travel_scale = 1.0
	mesh.position = _mesh_base
	eyes.clear()
	immunity_shimmer.set_fraction(0.0)


## Story 7-10 (AC 9): the head top's world position, by forward kinematics (the `_track_weapon_bone` read).
## The root plus the authored head height when the rig has no such bone.
func head_top_world() -> Vector3:
	if _head_top_bone < 0:
		return global_position + Vector3(0.0, HEAD_TOP_FALLBACK_Y, 0.0)
	return skeleton.global_transform * _bone_pose_global(_head_top_bone).origin


## Story 7-10 (AC 12): the trunk bone's world position -- where GREEN's dagger is aimed.
func trunk_world() -> Vector3:
	if _trunk_bone < 0:
		return global_position
	return skeleton.global_transform * _bone_pose_global(_trunk_bone).origin


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


## Story 7-8 (AC 11, `7-8/R9`): moves the hero HIT SHAPE onto the trunk bone's live animated position,
## the `_track_weapon_bone` precedent verbatim -- forward kinematics (never the cached global pose), the
## shape's ORIGIN only, expressed in the `Hurtbox` node's own frame, with the same sub-frame lag stated
## there. The shape is a CYLINDER, so it needs no rotation to fit a hero facing any way: nothing about the
## hero's rotation is derived or written here (1-7b single-yaw-source contract).
func _track_trunk_bone() -> void:
	if _trunk_bone < 0:
		return
	var bone_world: Vector3 = skeleton.global_transform * _bone_pose_global(_trunk_bone).origin
	hurtbox_shape.position = hurtbox.to_local(bone_world) + Vector3(0.0, -HURTBOX_DROP, 0.0)


## Composes bone-local poses up the parent chain, skeleton-relative. get_bone_pose() is the
## animated transform relative to the PARENT bone (skeleton-relative for the root bone).
func _bone_pose_global(idx: int) -> Transform3D:
	var t := skeleton.get_bone_pose(idx)
	var parent := skeleton.get_bone_parent(idx)
	while parent >= 0:
		t = skeleton.get_bone_pose(parent) * t
		parent = skeleton.get_bone_parent(parent)
	return t
