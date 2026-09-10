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

## Story 6-1b (AC 1/AC 2/AC 11, finding 2/6): THE THREE CHARGE CLIPS' MEASURED STRIKE FRAMES --
## the native-clip-time timestamp at which the blade completes its STRIKE swing ("the blade
## arrives"), measured by `tools/measure_charge_strike_frames.gd` (dev pass, MEASURED not
## assumed) and picked from its per-frame reach/speed tables using an IMPACT criterion, not
## global max reach: the last major reach maximum that follows the swing's own peak speed.
##
## FIX PASS (round-1 live smoke, criterion corrected): the first pass took the tool's printed
## `max_reach` verbatim for all three clips. That is equivalent to the impact criterion for
## RED and BLUE, whose tables have exactly one swing phase, so their values are UNCHANGED. It is
## WRONG for GREEN: `jump_attack`'s global max reach (1.0870 @ t=1.2375, 34% of the clip) is the
## sword extended at the AIRBORNE APEX of the jump, not the ground-impact swing -- a measurement
## artifact the operator's round-1 finding named ("holds mid-air then never lands"). The corrected
## GREEN value is the reach peak at t=2.1542 (0.7038m), the first clear local reach maximum after
## the post-apex descent (character landing, blade completing its downward arc) -- i.e. AFTER the
## apex, per the sanity check that a jump attack's impact cannot sit at 34% of its clip.
##
## THIS RETIRES 5-3's `CHARGE_ALIGNED_CHARGEUP_SECONDS` / `CHARGE_CLIP_SPEED` pair (a uniform
## `custom_speed` compression to the authored window) -- the `6-1/R15` finding was that a UNIFORM
## speed cannot place "about to strike" at a fixed point in the AUTHORED WINDOW independent of
## where the swing's own strike beat happens to fall in the clip's native timeline; only a
## re-tempo keyed to the strike frame itself can. `charge_playhead_seconds` below drives the
## playhead from window PROGRESS every tick instead, landing on exactly this timestamp at
## progress 1.0 regardless of native clip length -- so the coupling to the AUTHORED chargeup
## duration no longer lives here at all (it lives in `match_runner._push_charge_progress`, which
## computes progress from `MatchState.balance_ticks.unblockable_chargeup_ticks`); this file needs
## no balance reference for it, same as before (CONSTRAINT C, `4-3d/R9`).
const SWIPE_STRIKE_FRAME_SECONDS := 0.8450
const THRUST_STRIKE_FRAME_SECONDS := 0.9067
const JUMP_ATTACK_STRIKE_FRAME_SECONDS := 2.1542

const _CHARGE_STRIKE_FRAME_SECONDS := {
	Enums.CardColor.RED: SWIPE_STRIKE_FRAME_SECONDS,
	Enums.CardColor.BLUE: THRUST_STRIKE_FRAME_SECONDS,
	Enums.CardColor.GREEN: JUMP_ATTACK_STRIKE_FRAME_SECONDS,
}

## Story 6-1b (AC 2/AC 3, Sekiro-grammar ruling): the re-tempo's three progress breakpoints --
## ONE mechanism (AC 3: "same mechanism, no per-clip special case"), but PER-CLIP PARAMETER
## VALUES rather than three shared constants. FIX PASS (round-1 live smoke): RED froze near the
## END of its spin (a late coil pose reads as "the swing already happened"), BLUE's thrust
## wind-up was visually subtle at the shared hold point, and GREEN's hold sat at 85% of the way
## to a strike frame that (pre-fix) was itself the airborne apex -- each clip needed its OWN
## commitment point, not a shared curve applied uniformly. `charge_playhead_seconds` stays a
## single pure function; only its knob VALUES vary per colour, which is why this is still "the
## same mechanism" for AC 3 (operator ruling to record at close-out) rather than a per-clip
## special case. Each triple: `hold_start`/`hold_end` place the held beat as a fraction of WINDOW
## progress (so it lands at the same relative moment in the commitment regardless of a clip's
## native length), and `hold_fraction` places the held POSE as a fraction of the clip's own
## strike frame. The held beat HOLDS ON A SINGLE FRAME -- a fixed seek, not a slow crawl (the
## simpler of the two Open-Questions options, chosen so it reads unambiguously as "paused" rather
## than risking a crawl rate that reads as a glitch).
##
## OPERATOR FEEL KNOBS -- starting points for round-2 tuning, not final, hand-editable literals:
##   RED   (swipe):       early-rotation coil, held well before the old late-spin freeze.
##   BLUE  (thrust):      deepest pre-thrust pull-back, made visually legible vs the shared value.
##   GREEN (jump_attack): held ON the airborne apex -- `hold_fraction` is the corrected apex
##                        timestamp (1.2375s) as a fraction of the corrected strike frame
##                        (2.1542s): 1.2375 / 2.1542 = 0.5744.
const _CHARGE_HOLD_KNOBS := {
	Enums.CardColor.RED: {"hold_start": 0.3, "hold_end": 0.45, "hold_fraction": 0.15},
	Enums.CardColor.BLUE: {"hold_start": 0.40, "hold_end": 0.55, "hold_fraction": 0.17},
	Enums.CardColor.GREEN: {"hold_start": 0.40, "hold_end": 0.55, "hold_fraction": 0.5744},
}


## THE RE-TEMPO MAPPING (AC 1/AC 2/AC 11): window PROGRESS (0..1, computed runner-side per
## finding 5) -> this clip's native playhead seconds. A PURE function -- no scene, no
## `AnimationPlayer` -- so AC 11's two-endpoint pin can call it directly from a headless unit
## test: progress 0.0 maps to 0.0 (the clip's own rest pose) and progress 1.0 maps to
## `strike_frame_seconds` (never the clip's end -- the follow-through is not scheduled inside the
## window, AC 2). Between them: a SLOWED wind-up to the held pose, a HELD BEAT (flat), then a FAST
## close from the held pose to the strike frame. `hold_start_progress`/`hold_end_progress`/
## `hold_playhead_fraction` are the per-clip knobs from `_CHARGE_HOLD_KNOBS` -- passed explicitly
## so the function stays pure and testable per clip without reading the dictionary itself.
static func charge_playhead_seconds(progress: float, strike_frame_seconds: float,
		hold_start_progress: float, hold_end_progress: float,
		hold_playhead_fraction: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	var hold_playhead := strike_frame_seconds * hold_playhead_fraction
	if p <= hold_start_progress:
		return lerpf(0.0, hold_playhead, p / hold_start_progress)
	if p <= hold_end_progress:
		return hold_playhead
	var span := 1.0 - hold_end_progress
	return lerpf(hold_playhead, strike_frame_seconds, (p - hold_end_progress) / span)

## Story 6-1c (AC 11, `6-1c/R2`/`R6`): THE LAUNCH PROGRESS CHANNEL -- the progress fed to
## `charge_playhead_seconds` above, composed over the WHOLE ATTACK rather than the chargeup alone.
##
## WHY THE DOMAIN WIDENS. Before 6-1c the chargeup window's close WAS the landing, so chargeup
## progress 1.0 was the resolution tick. 6-1c inserts a launch between the two (the chargeup's close
## is now the COMMIT), and a progress still measured over the chargeup alone would reach 1.0 -- the
## STRIKE FRAME -- at the commit and then hold it for the whole launch: the frozen strike-pose glide
## AC 11 forbids, with the blade arriving before the damage. So the progress runs over the chargeup
## PLUS the colour's launch span, off the ONE window that spans both (`PlayerState.landing_window`,
## which closes on exactly the tick `_resolve_charge_landing` fires):
##   * the chargeup maps to [0, C / (C + L)] of the playhead curve -- the PRE-STRIKE portion, the
##     wind-up and the held beat;
##   * the launch maps to [C / (C + L), 1.0] -- the strike swing itself, played DURING the travel;
##   * 1.0 falls exactly on the landing tick, never before (AC 11). The runner stops pushing the
##     instant the hero leaves `CHARGING`, which happens synchronously on that same tick (the
##     `6-1b/R6` contract, keyed to the SAME edge -- the landing -- see
##     `match_runner._push_charge_progress`), so the last value it pushes is (C + L - 1) / (C + L).
## With no authored launch (L = 0) this is exactly 6-1b's chargeup progress.
##
## THE `_CHARGE_HOLD_KNOBS` ARE UNCHANGED and remain fractions of this progress, i.e. of the whole
## commitment from cast to landing; their felt timing shifts with the launch span, which is the retune
## the story's Dev Note anticipates (`6-1b/R9`), not a change owed here.
##
## PURE AND STATIC, `charge_playhead_seconds`' own shape: plain ints in, a clamped float out, no
## balance handle and no window handle (CONSTRAINT C), so a headless test can call it with the SAME
## inputs the runner passes and prove the landing-tick claim against a real state tick.
static func charge_attack_progress(landing_remaining_ticks: int, chargeup_ticks: int,
		launch_ticks: int) -> float:
	var total := chargeup_ticks + launch_ticks
	if total <= 0:
		return 1.0
	return clampf(1.0 - float(landing_remaining_ticks) / float(total), 0.0, 1.0)

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
			# Story 6-1b: speed 0.0 PINS the playhead -- on_charge_progress below is now the ONLY
			# thing that ever moves it, never AnimationPlayer's own idle-process advance. _restart
			# still seeks to 0.0 so a fresh CHARGING entry always starts from the clip's rest pose.
			_restart(charge_clip, 0.0)
		return
	var clip: StringName = _CLIP.get(current, &"")
	if clip != &"":
		_restart(clip)


## Story 6-1b (AC 1/AC 4, finding 5): pushed every tick the hero is CHARGING -- a NEW call site
## (`match_runner._push_charge_progress`), never a `connect_*` seam (AC 7). `progress` arrives
## already computed runner-side from EXISTING public state -- since 6-1c through
## `charge_attack_progress` above, over the chargeup PLUS the launch
## (`PlayerState.landing_window.remaining_ticks()` / `MatchState.balance_ticks`' chargeup and
## per-colour launch ticks) -- and this controller still reads no balance and holds no window handle
## (CONSTRAINT C).
##
## THE `_state != CHARGING` GUARD is belt-and-braces on the `on_locomotion` precedent above (which
## guards `_state != IDLE` the same way), not the sole defence against the finding-4 ordering
## hazard: the caller already stops calling the instant `action_state` flips off CHARGING, because
## it reads the same state-side field `set_action_state` updates SYNCHRONOUSLY, ahead of the
## QUEUED seam signal that later fires this controller's own cut to `idle`. So a stale push cannot
## reach here AT ALL on the tick a chargeup ends, and this guard only covers a caller that someday
## stops honouring that contract.
func on_charge_progress(charge_color: int, progress: float) -> void:
	if _state != HeroState.ActionState.CHARGING:
		return
	var strike_frame: float = _CHARGE_STRIKE_FRAME_SECONDS.get(charge_color, 0.0)
	if strike_frame <= 0.0:
		return
	var knobs: Dictionary = _CHARGE_HOLD_KNOBS.get(charge_color, {})
	if knobs.is_empty():
		return
	animation_player.seek(charge_playhead_seconds(progress, strike_frame,
		knobs["hold_start"], knobs["hold_end"], knobs["hold_fraction"]), true)


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
