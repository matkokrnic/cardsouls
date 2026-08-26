class_name UnitAnimationController
extends Node

## Rig presentation layer (story 4-3c, AC 4): per-unit READ-ONLY controller that selects which
## of the minion's four skinned clips plays. The `AnimationController` counterpart 3-0a built
## for the hero, and it holds the identical posture: a presentation consumer with no identity,
## no state handle, no mutator call, and no decision (dependency direction: visuals -> state).
##
## NO _physics_process here (INVARIANT F1 -- the runner owns the only one) and no `Input`
## (D3(a)). Clip switching is PUSH-driven from a seat that already runs once per physics
## frame, never polled on a clock of its own.
##
## PUSHED, NOT EVENTED -- THE ONE STRUCTURAL DIFFERENCE FROM THE HERO'S CONTROLLER. The hero
## listens on `action_state_changed`, a signal fired on state TRANSITION. The minion has no
## such signal: 4-3b's attack rhythm lives as a plain scalar per board index
## (`UnitBoard.attack_phase_at`), units carry no per-record signal at all, and the runner
## already reads that scalar every frame in `MatchRunner._aim_unit_actors`. So that existing
## per-tick call carries the payload -- no new seam, no new loop, no second `_physics_process`,
## on the identical reasoning 3-0a/R2 used for the hero's `run` clip.
##
## SELECTION (4-3c AC 4), and the ORDER of these three checks is a machine contract, not a
## style choice:
##   1. NOT ALIVE            -> `death`   (checked FIRST, before phase -- see below)
##   2. phase != IDLE        -> `attack`  (WINDUP, ACTIVE and RECOVERY all select the SAME
##                                        clip; there is one attack clip, not three), RE-TRIGGERED
##                                        from frame 0 on every ENTRY INTO WINDUP -- see below
##   3. IDLE                 -> `walk` if moving, `idle` if not
##
## WHY LIVENESS IS CHECKED BEFORE PHASE, measured (not an optimization -- the only correct
## read). `MatchState._advance_unit_attacks` is the sole writer of a unit's phase and its own
## guard skips dead units, so a unit killed mid-windup/active/recovery has its phase FROZEN at
## whatever value it held on the kill tick, forever; nothing ever resets it to IDLE on death.
## A controller that checked phase first would show a corpse still winding up or swinging.
## Pinned by test/integration/test_unit_clip_selection.gd, whose named mutation is exactly
## this swap.
##
## RE-TRIGGER ON ENTRY INTO WINDUP (defect B1 fix pass, MEASURED). Selection alone is not enough
## for a CHAINED attacker. Measured live: the phase cycle runs WINDUP 54 ticks -> ACTIVE 12 ->
## RECOVERY 48 -> WINDUP with ZERO IDLE ticks in between, so seven consecutive swings were one
## unbroken 743-tick non-IDLE stretch. `phase != IDLE` therefore selected `attack` ONCE for all
## seven, `_select`'s dedup swallowed every re-trigger, the clip ran to its end and then HELD its
## final near-neutral pose for ~9.7s while real swings and real damage continued underneath --
## the "frozen in idle while attacking" defect. The fix is one more piece of remembered state, the
## same shape as `_selected`: the PREVIOUS tick's phase, so a WINDUP that follows a non-WINDUP
## tick (IDLE *or* RECOVERY) restarts the clip from frame 0.
##
## CONSEQUENCE, accepted here and owned elsewhere: the swing cycle is 1.9s and the clip is
## 2.6667s, so each chained swing now truncates the final ~0.767s (28.7%) of the clip. That is
## expected, and it is strictly better than the held-pose defect it replaces. Aligning the visible
## strike to the authored ACTIVE window is 4-3d AC 5's, not this pass's (4-3c/R2).
##
## STORY 4-3d (AC 1) DISCHARGES THAT: the `attack` clip now plays at a CUSTOM PLAYBACK RATE so the
## visible claw-strike pose lands at the instant the authored ACTIVE window opens. See
## `ATTACK_PLAYBACK_RATE` below for the measurement and the derivation. The 4-3c consequence
## recorded above is superseded by it: at the shipped rate the clip's effective duration is
## 1.8462s against a 1.9s cycle, so a chained swing no longer truncates -- it finishes and HOLDS
## its final pose for the remaining ~0.054s, which is the artefact 4-3d's Live Smoke rates.
##
## CLIP-END / MID-CLIP (adoption level, the 3-0a policy applied verbatim). A non-looping clip
## (`attack`/`death`) that ends while its selection persists HOLDS its final pose; a change of
## selection mid-clip wins immediately, with NO blending. Alignment of the visible strike to
## the authored ACTIVE window is NOT this story's -- it is 4-3d's (4-3c/R2).

## Path to the model's AnimationPlayer (under the model instance, so its Skeleton3D track
## paths resolve). Set in unit_actor.tscn; presentation-local, never handed a state object.
## Resolved in _ready (not @onready) so it reads the exported path after instantiation has
## applied it -- the hero controller's own precedent.
@export var animation_player_path: NodePath
var animation_player: AnimationPlayer

## Velocity magnitude above which an idle-phase unit reads as walking rather than standing.
## NOT tuned in this story and NOT a BalanceConfig field -- a presentation-only constant on
## the hero controller's `RUN_SPEED_EPS` precedent (adoption needs only a working split
## between "still" and "moving"). The authored `unit_move_speed` is 3.0, an order and a half
## above this, so the split is unambiguous in both directions.
const WALK_SPEED_EPS := 0.1

## Story 4-3d (AC 1): the MEASURED STRIKE FRAME of the `attack` clip -- the timestamp within the
## clip's own 2.6667 s at which the visible claw-strike pose lands.
##
## MEASURED, NOT ASSUMED (`4-3d/R13`), by `tools/measure_strike_frame.gd`, which samples all 81
## frame boundaries of the clip and reports each hand bone's position RELATIVE TO THE HIPS -- the
## arm's own extension, with the body's lunge divided out. The LEFT hand is the striking limb
## (it reaches 0.8337 forward of the hips against the right hand's 0.7303, and 1.58 forward in
## actor space against the right's 0.80) and its forward extension peaks at FRAME 39 of 80,
## t = 1.3000 s, where its speed also collapses from 20.5 to 14.1 to 10.3 -- an arrival, not a
## pass-through.
##
## THE HIPS-DISPLACEMENT PEAK IS NOT THIS NUMBER and is explicitly not a proxy for it
## (`4-3d/R13`): the same tool measures that peak at t = 1.4333 s, 0.1333 s LATER, because the
## root keeps translating after the claw has arrived.
const ATTACK_STRIKE_FRAME_SECONDS := 1.3

## The authored `minion_attack_windup_seconds` this rate aligns the strike to
## (`data/balance/balance_config.tres`). NOT read from `BalanceConfigService` -- this is a
## presentation node on `WALK_SPEED_EPS`'s own precedent, and CONSTRAINT C keeps authored balance
## out of actors entirely. It is named rather than folded into the literal below so the coupling
## is visible: re-tuning the authored windup without re-deriving this constant would put the
## visible strike back out of alignment. `test/integration/test_unit_strike_alignment_live.gd`
## reads the AUTHORED value at run time and fails if the two ever disagree, so the coupling is
## guarded rather than merely commented.
const ATTACK_ALIGNED_WINDUP_SECONDS := 0.9

## Story 4-3d (AC 1), THE MECHANISM, ruled by the operator (`4-3d/R11`): a CUSTOM PLAYBACK RATE.
## Playing the clip at `r` puts its strike frame at `ATTACK_STRIKE_FRAME_SECONDS / r` of real
## time, so aligning it to the START of the ACTIVE window -- one authored windup after the swing
## begins -- is `r = T / windup = 1.3000 / 0.9 = 1.4444`.
##
## THE WHOLE CLIP PLAYS, COMPLETE AND UNCUT, FROM FRAME 0, merely faster. That is the accepted
## consequence in the operator's own words, and it is why the two rejected alternatives are not
## used: a partial clip range (b) and a start-offset play call (c) both remove the front of the
## windup -- the anticipation a player reads to time a parry (`4-3d/R11`).
##
## DERIVED ARTEFACT, recorded because the Live Smoke rates it (`4-3d/R15`): the clip's effective
## duration becomes 2.6667 / 1.4444 = 1.8462 s against the 1.9 s authored cycle. `T > 1.263 s`,
## so this is the HELD-FINAL-POSE branch -- 0.0538 s (3.2 ticks) of held final pose per chained
## swing, and NO truncation. The ~0.767 s truncation `4-3c` shipped is closed as a side effect;
## `4-3d/R15` ruled that closure subordinate to the alignment, not a goal of its own.
const ATTACK_PLAYBACK_RATE := ATTACK_STRIKE_FRAME_SECONDS / ATTACK_ALIGNED_WINDUP_SECONDS

## The last clip THIS CONTROLLER SELECTED, which is deliberately not the same question as
## "what is the AnimationPlayer playing right now".
##
## LOAD-BEARING, AND THE REASON THE HERO'S IDEMPOTENT `_play` COULD NOT BE COPIED. The hero
## compares against `animation_player.current_animation`; that is safe there because its only
## POLLED path chooses between `idle` and `run`, which both LOOP, so `current_animation` never
## clears underneath it. This controller is polled for ALL FOUR clips, and two of them
## (`attack`, `death`) do not loop -- a finished non-looping clip leaves `current_animation`
## EMPTY while the final pose stays on screen. Comparing against it would therefore re-`play()`
## `death` on the very next tick after the clip ended, looping a corpse's death forever
## instead of holding its final pose. Tracking the SELECTION rather than the playback state is
## what makes the 3-0a clip-end policy ("holds its final pose") true here.
var _selected: StringName = &""

## The PREVIOUS tick's attack phase, remembered for exactly one reason: to see the EDGE into
## WINDUP. A chained attacker never passes through IDLE (measured: RECOVERY -> WINDUP directly),
## so the level signal `phase != IDLE` cannot tell swing #2 from swing #1 -- only the edge can.
## See the RE-TRIGGER note in the file header.
var _prev_phase: int = UnitBoard.AttackPhase.IDLE


func _ready() -> void:
	animation_player = get_node(animation_player_path)
	# Start on the resting pose so a unit that never moves and never swings still animates.
	_select(&"idle")


## The per-tick push from `MatchRunner._aim_unit_actors` (4-3c AC 4). Everything it takes is
## already read at that seat: `alive` from `UnitBoard.is_alive_at`, `phase` from
## `UnitBoard.attack_phase_at`, and `speed` from the actor's own `CharacterBody3D.velocity`.
##
## THIS CALL IS MADE UNCONDITIONALLY FOR EVERY ACTOR THE LOOP REACHES, ahead of the liveness
## check that gates the runner's AIM decision (the operator's ordering ruling, 4-3c/R15). A
## liveness check placed ahead of the push would skip the push too, and 4-3d's lingering
## corpse would then never be told it died -- freezing on a half-raised claw instead of
## playing `death`. Pinned by test/integration/test_unit_clip_selection.gd's source-order
## assertion, which is the ONLY guard in this story that can see the runner-side ordering.
func on_unit_tick(alive: bool, phase: int, speed: float) -> void:
	# The EDGE, computed before anything can return -- `_prev_phase` advances on every tick,
	# including the dead ones. No code path resurrects a dead unit, so this is a harmless no-op
	# on those ticks (L7 FIX PASS, correcting the earlier "resurrected index" justification,
	# which named a case nothing in this codebase can produce) -- kept unconditional simply
	# because gating it on `alive` would buy nothing and cost a branch.
	var entered_windup := phase == UnitBoard.AttackPhase.WINDUP \
		and _prev_phase != UnitBoard.AttackPhase.WINDUP
	_prev_phase = phase
	if not alive:
		_select(&"death")
		return
	if phase != UnitBoard.AttackPhase.IDLE:
		# `force` is what makes swing #2 of a chain visible: same clip, same selection, new swing.
		_select(&"attack", entered_windup)
		return
	_select(&"walk" if speed > WALK_SPEED_EPS else &"idle")


## Switch only on an actual change of SELECTION -- see `_selected` for why the comparison is
## against that and not against the AnimationPlayer's current animation. Without this the
## polled push would restart the chosen clip from frame 0 on every single tick and nothing
## would ever visibly animate.
##
## `force` overrides the dedup for the ONE case where re-playing an already-selected clip is the
## correct answer: a new swing beginning while the previous swing's selection is still current.
## It is passed only on the WINDUP edge, never per-tick -- see the file header.
func _select(clip: StringName, force: bool = false) -> void:
	if _selected == clip and not force:
		return
	_selected = clip
	# Story 4-3d (AC 1): the custom playback rate rides on the SAME `play()` call that already
	# selects the clip -- `AnimationPlayer.play(name, custom_blend, custom_speed)`. Deliberately
	# NOT `speed_scale`, which is a property of the whole player: that would speed up `idle`,
	# `walk` and `death` too, and a corpse toppling at 1.44x is not what AC 1 asks for. The rate
	# is per-clip and every clip but `attack` gets 1.0.
	animation_player.play(clip, -1.0, _playback_rate(clip))
	if force:
		# Explicit, engine-version-independent restart: `play()` on the currently-playing clip is
		# not contractually a rewind, and a re-trigger that did not rewind would be a silent no-op.
		animation_player.seek(0.0, true)


## Story 4-3d (AC 1): the playback rate for `clip`. ONE clip is aligned and the rest run at
## authored speed -- there is exactly one authored rhythm to align against (the attack windup),
## and `idle`/`walk`/`death` have no window to land on.
func _playback_rate(clip: StringName) -> float:
	return ATTACK_PLAYBACK_RATE if clip == &"attack" else 1.0
