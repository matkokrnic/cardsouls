class_name AnimationController
extends Node3D

## Rig presentation layer (story 3-0a): per-hero READ-ONLY controller that selects which of
## the paladin's skinned clips plays — six at 3-0a, NINE since 5-0a. Like TelegraphController
## it is a presentation consumer with no identity and no state handle — the runner wires it
## through the action-state seam (connect_hero_action_state_changed) at match start; it never
## calls a state mutator and never decides an outcome (dependency direction: visuals -> state).
##
## NO _physics_process here (INVARIANT F1 — the scan covers all of src/); clip switching is
## event- and push-driven, never polled on its own clock.
##
## SELECTION (3-0a AC4, CHARGING claimed by 5-3 AC8-9). Five clips map 1:1 from an
## ActionState and are chosen on the seam (fires only on a transition):
##   ATTACKING -> attack, BLOCKING -> block, ROLLING -> roll, DEAD -> death, IDLE -> idle.
## CHARGING maps to ONE OF THREE clips (swipe/thrust/jump_attack) keyed by `charge_color`, a
## third seam argument this story adds (see on_action_state_changed below) — the reservation
## `3-0a` left for it is claimed here, not by widening the one-clip-per-state table above.
## DEFLECT is not an ActionState (the block pose covers it); STUNNED alone stays unmapped
## (zero inbound edges) and leaves the current pose untouched. The LOCOMOTION clips have NO
## ActionState of their own: a moving hero is IDLE
## with non-zero velocity, and velocity crosses the move threshold with no state transition, so
## the seam can never carry them (gate ruling 3-0a/R2). Instead HeroActor.drive() PUSHES the
## velocity and facing every tick via on_locomotion(); while IDLE that picks between them.
## No _process, no second _physics_process, no new seam, no state handle.
##
## STORY 5-0a (AC 2) WIDENED THAT PUSH FROM SPEED TO DIRECTION. 3-0a's push was a single scalar
## `speed`, which can only answer "moving or not" — so the split was `run` vs `idle`, and every
## direction of travel played `run`. That was correct while facing FOLLOWED movement. Story 4-6
## pinned facing to the locked target instead, and from that point a hero moving sideways or
## backwards was moving one way while facing another, with the forward-run clip playing over the
## top: the "floating / skating" defect the E4 close-out named (decision-log:7856-7860). The push
## now carries the velocity VECTOR and the facing, and the split is five-way:
##   idle / run / strafe_left / strafe_right / backpedal.
##
## HOW DIRECTION IS RESOLVED, AND WHY THERE IS NO SECOND atan2. The 1-7b single-yaw-source
## contract says drive() computes exactly ONE yaw and a second atan2 anywhere is a defect. This
## controller needs direction as DATA, not as a rotation, so it takes two dot products instead
## of an angle. Facing (x, y) maps to world (x, 0, y) and drive()'s yaw points local +Z along
## it, which puts local +X along world (facing.y, 0, -facing.x). So:
##   forward = v.x * facing.x + v.z * facing.y
##   right   = v.x * facing.y - v.z * facing.x
## Two projections of the same two values drive() already has. No angle is ever formed, nothing
## here is written to a transform, and the Hitbox/Mesh yaw is untouched.

## Path to the paladin's AnimationPlayer (under Mesh/Paladin so its Skeleton3D track paths
## resolve). Set in hero.tscn; presentation-local, never handed a state object. Resolved in
## _ready (not @onready) so it reads the exported path after instantiation has applied it.
@export var animation_player_path: NodePath
var animation_player: AnimationPlayer

## Velocity magnitude above which a stationary-state (IDLE) hero reads as moving rather than
## standing. NOT tuned in this story (3-0b owns the feel/threshold); adoption needs only a
## working split between "still" and "moving", and the hero's move speed is orders above this.
const RUN_SPEED_EPS := 0.1

## Where the forward/back cones end and the strafe cones begin, as the ratio |right| / |forward|
## at which the choice flips. 1.0 puts the boundary on the 45-degree diagonals — four equal
## quadrants around the hero. UNTUNED, on the RUN_SPEED_EPS / 4-3c adoption-only precedent
## (5-0a Non-Goals: this story needs a working four-way split, not a tuned one). Named rather
## than inlined so the retune pass that owns the feel has one place to move it, and so a
## deliberately asymmetric split (a wider forward cone, say) is a one-line change.
const STRAFE_BAND_RATIO := 1.0

## Crossfade seconds for switches BETWEEN the locomotion clips, via play()'s custom_blend. Small
## and fixed and UNTUNED, exactly like the band above; a full 2D blend space (blending several
## clips by the movement vector) is explicitly deferred to a future retune pass (Non-Goals).
## This applies ONLY to the polled locomotion path: action-state transitions keep the 3-0a/R5
## immediate-win, no-blend policy, and _restart() below is deliberately not given a blend.
const LOCOMOTION_BLEND_SECONDS := 0.12

const _CLIP := {
	HeroState.ActionState.IDLE: &"idle",
	HeroState.ActionState.ATTACKING: &"attack",
	HeroState.ActionState.BLOCKING: &"block",
	HeroState.ActionState.ROLLING: &"roll",
	HeroState.ActionState.DEAD: &"death",
}

## Story 5-3 (AC 8): CHARGING's colour-keyed clip. Kept as a SECOND dictionary rather than
## widening `_CLIP`'s value type, because `_CLIP` is a one ActionState -> one clip map and
## every other entry in it stays that shape; CHARGING alone needs a second key (colour), so it
## gets its own map instead of making every other entry's value type lie about being able to
## vary. Keyed by the plain `Enums.CardColor` int the `telegraph` snapshot fact already
## carries (1-10/R1 intact: no state object ever names a clip or a TelegraphProfile).
const _CHARGE_CLIP := {
	Enums.CardColor.RED: &"swipe",
	Enums.CardColor.BLUE: &"thrust",
	Enums.CardColor.GREEN: &"jump_attack",
}

## Story 5-3 (Ruling 3): THE THREE CHARGE CLIPS' MEASURED NATIVE LENGTHS. These are properties of
## the `.fbx` SOURCES, not balance — they change only when a clip is reimported or retimed — so they
## are named here, presentation-side, exactly like `UnitAnimationController`'s
## `ATTACK_STRIKE_FRAME_SECONDS`. MEASURED, not assumed (dev pass,
## `tools/measure_hips_displacement.gd`'s own `len` column).
const SWIPE_NATIVE_SECONDS := 1.7333
const THRUST_NATIVE_SECONDS := 2.1333
const JUMP_ATTACK_NATIVE_SECONDS := 3.6667

## The authored `unblockable_chargeup_seconds` (`data/balance/balance_config.tres`) these three
## clips are scaled to fit. NOT read from `BalanceConfigService`, and that is CONSTRAINT C plus the
## replay rule rather than a convenience: this controller holds no state handle and no balance
## reference by design (see the file header), the action-state seam carries `charge_color` and
## nothing else, and a controller reading the SERVICE would present the AUTHORED duration during a
## replay that recorded a different one (`4-3/R11`, `match_runner.gd:264-267`). Widening the seam to
## carry the duration is an API change to the presentation seam and is NOT taken unasked --
## `4-3d/R9`'s ruling on the identical shape, one story earlier.
##
## SO THE COUPLING IS GUARDED BY TEST RATHER THAN BY COMMENT, on that same precedent:
## `test/state/test_balance_authoring.gd::test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
## reads the AUTHORED value and re-derives all three speeds from it, so retuning
## `unblockable_chargeup_seconds` without re-deriving this constant turns the suite RED and names
## the re-derivation needed. Re-tuning this ONE field is therefore no longer a pure one-line `.tres`
## edit -- the `4-3d/R9` consequence, accepted here for the same reason and recorded in the story.
const CHARGE_ALIGNED_CHARGEUP_SECONDS := 1.0

## Story 5-3 (Ruling 3): the 1.0s chargeup is AUTHORED, not clip-dictated — these three clips are
## scaled to fit it, never the other way around. `AnimationPlayer`'s `custom_speed` COMPRESSES
## (speed > 1.0 plays faster/shorter), so a longer native clip gets a bigger factor. DERIVED from
## the two constant blocks above rather than written as three literals, so the arithmetic cannot
## drift from the numbers it claims to be: `UnitAnimationController.ATTACK_PLAYBACK_RATE`'s own
## shape (`rate = measured_clip_seconds / authored_seconds`), three times instead of once.
const CHARGE_CLIP_SPEED := {
	Enums.CardColor.RED: SWIPE_NATIVE_SECONDS / CHARGE_ALIGNED_CHARGEUP_SECONDS,
	Enums.CardColor.BLUE: THRUST_NATIVE_SECONDS / CHARGE_ALIGNED_CHARGEUP_SECONDS,
	Enums.CardColor.GREEN: JUMP_ATTACK_NATIVE_SECONDS / CHARGE_ALIGNED_CHARGEUP_SECONDS,
}

var _state: HeroState.ActionState = HeroState.ActionState.IDLE


func _ready() -> void:
	animation_player = get_node(animation_player_path)
	# Start on the resting pose so a hero that never moves still animates.
	_play(&"idle")


## Seam callback (connect_hero_action_state_changed): the entered state selects its clip.
## IDLE defers the locomotion choice to the per-tick push; ATTACKING/BLOCKING/ROLLING/DEAD/
## CHARGING play at once (winning any in-flight clip); STUNNED (still unmapped) holds the pose.
##
## A TRANSITION ALWAYS RESTARTS ITS CLIP (3-0b Pass 3b). The seam fires once per transition,
## and a chained swing is a SELF-transition: HeroState.chain_attack() explicitly re-emits
## ATTACKING -> ATTACKING for exactly this reason (state-side, pinned by
## test_action_state.gd's queued-signal sequence). Selecting by name alone therefore loses
## every chained swing — the name is already `attack`, so the second and third swings of a
## three-swing chain would inherit whatever is left of the first swing's clip instead of
## playing their own. That is why this path calls _restart(), never _play(): restarting is
## what the 3-0a clip policy already says a transition does ("a transition arriving mid-clip
## wins immediately with NO blending"), and a same-state transition is still a transition.
##
## `charge_color` (story 5-3, AC 8/9): the ONLY state fed to this seam beyond what
## `action_state_changed` itself carries — read by the caller (match_runner, AC 9) at the
## transition instant and forwarded here, never stored. A default of
## `PlayerState.NO_TELEGRAPH_COLOR` keeps every other transition unaffected; CHARGING is the
## only branch that ever consults it.
func on_action_state_changed(_previous: HeroState.ActionState, current: HeroState.ActionState,
		charge_color: int = PlayerState.NO_TELEGRAPH_COLOR) -> void:
	_state = current
	if current == HeroState.ActionState.CHARGING:
		var charge_clip: StringName = _CHARGE_CLIP.get(charge_color, &"")
		if charge_clip != &"":
			_restart(charge_clip, CHARGE_CLIP_SPEED.get(charge_color, 1.0))
		return
	var clip: StringName = _CLIP.get(current, &"")
	if clip != &"":
		_restart(clip)


## Pushed every tick from HeroActor.drive() (gate ruling 3-0a/R2, widened by 5-0a AC 2): while
## the hero is IDLE, the velocity vector RELATIVE TO FACING picks one of the five locomotion
## clips. Ignored in every other state — attack/block/roll/death own the body while they
## persist, so residual velocity never overrides them.
##
## `velocity` is the world velocity drive() took from HeroState; `facing` is the same
## HeroState.facing drive() yawed the body with. Speed is measured PLANAR (x/z): the state layer
## only ever writes planar movement (_resolve_movement), and a direction split that counted a
## vertical component would be answering a different question from the one it then classifies.
##
## This path is POLLED, not evented, so it uses the idempotent _play(): re-selecting the clip
## already playing must be a no-op or the selected clip would restart from frame 0 on every
## single tick and never visibly animate. The two paths are deliberately NOT the same call.
func on_locomotion(velocity: Vector3, facing: Vector2) -> void:
	if _state != HeroState.ActionState.IDLE:
		return
	_play(_locomotion_clip(velocity, facing))


## The five-way split, as a pure function of the two pushed values so it can be asserted
## directly (test/integration/test_hero_clip_selection.gd drives the four cardinals).
##
## Facing is expected normalized (state writes it that way), but a zero or degenerate facing is
## survivable rather than fatal: with no direction to be relative TO, the projections collapse
## to zero and this falls through to `run` — the pre-5-0a behaviour for a moving hero, which is
## the right thing to degrade to.
func _locomotion_clip(velocity: Vector3, facing: Vector2) -> StringName:
	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() <= RUN_SPEED_EPS:
		return &"idle"
	# Local +Z lies along facing; local +X lies along (facing.y, -facing.x). See the header:
	# two dot products, never an angle, so no second atan2 enters the codebase.
	var forward := planar.x * facing.x + planar.y * facing.y
	var right := planar.x * facing.y - planar.y * facing.x
	if absf(right) > absf(forward) * STRAFE_BAND_RATIO:
		return &"strafe_right" if right > 0.0 else &"strafe_left"
	return &"run" if forward >= 0.0 else &"backpedal"


## Idempotent selection for the polled locomotion path: switch only on an actual change, and
## when it IS a change, crossfade rather than cut (5-0a AC 2). The guard is what makes the
## blend meaningful as well as what makes the path idempotent — an unguarded play() every tick
## would restart the blend every tick and never finish it.
func _play(clip: StringName) -> void:
	if animation_player.current_animation != clip:
		animation_player.play(clip, LOCOMOTION_BLEND_SECONDS)


## Unconditional restart for the evented transition path. NO custom_blend here on purpose: the
## 3-0a/R5 policy is that a transition wins immediately, and 5-0a's crossfade is scoped to the
## locomotion clips only (AC 2). The seek() is LOAD-BEARING and not belt-and-braces:
## AnimationPlayer.play(name) is a no-op on playback position when `name` is already the
## current, still-playing animation (measured on Godot 4.6.3 — play, advance to 0.30, play
## again, position is still 0.30). Dropping the seek would silently reinstate the chained-swing
## defect for every chain pressed before the previous clip ends.
func _restart(clip: StringName, speed: float = 1.0) -> void:
	animation_player.play(clip, -1.0, speed)
	animation_player.seek(0.0, true)
