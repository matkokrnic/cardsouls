class_name AnimationController
extends Node3D

## Rig presentation layer (story 3-0a): per-hero READ-ONLY controller that selects which of
## the six skinned clips the paladin plays. Like TelegraphController it is a presentation
## consumer with no identity and no state handle — the runner wires it through the
## action-state seam (connect_hero_action_state_changed) at match start; it never calls a
## state mutator and never decides an outcome (dependency direction: visuals -> state).
##
## NO _physics_process here (INVARIANT F1 — the scan covers all of src/); clip switching is
## event- and push-driven, never polled on its own clock.
##
## SELECTION (3-0a AC4). Five of the six clips map 1:1 from an ActionState and are chosen on
## the seam (fires only on a transition):
##   ATTACKING -> attack, BLOCKING -> block, ROLLING -> roll, DEAD -> death, IDLE -> idle.
## DEFLECT is not an ActionState (the block pose covers it); STUNNED/CHARGING are unmapped
## (STUNNED has zero inbound edges, CHARGING is an E5 reservation) — they leave the current
## pose untouched. The sixth clip, `run`, has NO ActionState of its own: a running hero is
## IDLE with non-zero velocity, and velocity crosses the run threshold with no state
## transition, so the seam can never carry it (gate ruling 3-0a/R2). Instead HeroActor.drive()
## PUSHES the velocity magnitude every tick via on_locomotion(); while IDLE this picks run vs
## idle. No _process, no second _physics_process, no new seam, no state handle.
##
## CLIP-END / MID-CLIP (adoption level, 3-0a AC4). A non-looping clip (attack/roll/death) that
## ends while its state persists HOLDS its final pose — AnimationPlayer stops at the last frame
## and on_locomotion only re-selects while IDLE, so a dead hero stays down. A transition
## arriving mid-clip wins immediately with NO blending (play() at the zero default blend).
## Blending, cancel windows, and feel are 3-0b's.

## Path to the paladin's AnimationPlayer (under Mesh/Paladin so its Skeleton3D track paths
## resolve). Set in hero.tscn; presentation-local, never handed a state object. Resolved in
## _ready (not @onready) so it reads the exported path after instantiation has applied it.
@export var animation_player_path: NodePath
var animation_player: AnimationPlayer

## Velocity magnitude above which a stationary-state (IDLE) hero reads as running rather than
## standing. NOT tuned in this story (3-0b owns the feel/threshold); adoption needs only a
## working split between "still" and "moving", and the hero's move speed is orders above this.
const RUN_SPEED_EPS := 0.1

const _CLIP := {
	HeroState.ActionState.IDLE: &"idle",
	HeroState.ActionState.ATTACKING: &"attack",
	HeroState.ActionState.BLOCKING: &"block",
	HeroState.ActionState.ROLLING: &"roll",
	HeroState.ActionState.DEAD: &"death",
}

var _state: HeroState.ActionState = HeroState.ActionState.IDLE


func _ready() -> void:
	animation_player = get_node(animation_player_path)
	# Start on the resting pose so a hero that never moves still animates.
	_play(&"idle")


## Seam callback (connect_hero_action_state_changed): the entered state selects its clip.
## IDLE defers run/idle to the per-tick locomotion push; ATTACKING/BLOCKING/ROLLING/DEAD play
## at once (winning any in-flight clip); unmapped states (STUNNED/CHARGING) hold the pose.
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
func on_action_state_changed(_previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
	_state = current
	var clip: StringName = _CLIP.get(current, &"")
	if clip != &"":
		_restart(clip)


## Pushed every tick from HeroActor.drive() (gate ruling 3-0a/R2): while the hero is IDLE, the
## velocity magnitude picks run vs idle. Ignored in every other state — attack/block/roll/death
## own the body while they persist, so residual velocity never overrides them.
##
## This path is POLLED, not evented, so it uses the idempotent _play(): re-selecting the clip
## already playing must be a no-op or `run` would restart from frame 0 on every single tick
## and never visibly animate. The two paths are deliberately NOT the same call.
func on_locomotion(speed: float) -> void:
	if _state != HeroState.ActionState.IDLE:
		return
	_play(&"run" if speed > RUN_SPEED_EPS else &"idle")


## Idempotent selection for the polled locomotion push: switch only on an actual change.
func _play(clip: StringName) -> void:
	if animation_player.current_animation != clip:
		animation_player.play(clip)


## Unconditional restart for the evented transition path. The seek() is LOAD-BEARING and not
## belt-and-braces: AnimationPlayer.play(name) is a no-op on playback position when `name` is
## already the current, still-playing animation (measured on Godot 4.6.3 — play, advance to
## 0.30, play again, position is still 0.30). Dropping the seek would silently reinstate the
## chained-swing defect for every chain pressed before the previous clip ends.
func _restart(clip: StringName) -> void:
	animation_player.play(clip)
	animation_player.seek(0.0, true)
