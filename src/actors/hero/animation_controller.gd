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
## DEFLECT is not an ActionState (the block pose covers it). STUNNED stayed unmapped until 6-6a
## (see below), leaving the pose untouched. The LOCOMOTION clips have NO
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
##
## STORY 6-7b ADDS THE PRESENTATION HALF OF 6-7's TWO GAITS, still on that one push:
##   * WALK vs RUN FAMILY (AC 4/AC 5), keyed on the PUSHED PLANAR SPEED against the MIDPOINT of the
##     authored walk/run pair (`gait_threshold`), which the push now carries as two plain floats.
##     The controller receives no gait fact; the direction split above then picks the member.
##   * TURN IN PLACE (AC 6): an IDLE hero standing still whose pushed facing keeps changing plays
##     `turn_left`/`turn_right`, chosen by the SIGN of a cross term of consecutive facings -- still
##     no angle, no atan2 (`_track_facing`).
##   * PER-CLIP PLAYBACK RATE (AC 8) through play()'s own custom speed, never the player-wide
##     `speed_scale`, scoped to the ten locomotion/turn clips.
## STORY 6-6a ADDS THE DEFENSE REACTIONS, on the SAME two paths and with no new seam:
##   * STUNNED gets a pose (AC 10/AC 11): `stunned` for the two ordinary flavors (colour counter,
##     deflect), `knockdown` for the knockdown -- told apart by a RUNNER-COMPUTED `stun_flavor` forwarded
##     beside `charge_color` (the stun window's own duration through `BalanceTicks.is_knockdown_stun`),
##     never by a flavor this controller remembers. Both are one-shots HELD on their final frame for the
##     rest of the window (`_play_stun`), never looped.
##   * `get_up` plays on the timer-driven `STUNNED -> IDLE` exit from a knockdown ONLY (AC 8/AC 9) --
##     keyed on the forwarded `get_up_armed`, i.e. on the state layer having just opened the get-up
##     iframes, which the debug reset never does.
##   * `hit_react` / `block_impact` (AC 1/AC 2/AC 12) on the EXISTING `hit_landed` seam, this controller
##     its second consumer: selected by the MIRRORED `_state` at consumption time, never a live read --
##     and `block_impact` only for a hit the runner forwards as actually `blocked` (6-6a review D2).
##   * the knockdown ESCALATION (AC 5): an ordinary stun overwritten by a knockdown is a same-state write
##     that emits no transition, so `on_hit_landed` re-checks the forwarded flavor on the drain that
##     carries the knockdown's own `hit_landed`.
##   * ONE-SHOT LOCOMOTION YIELD (AC 2): `hit_react`/`get_up` are not stolen by the per-tick `_play()`.
##   * BLOCK EXIT BLENDS (AC 13, `3-0b/R24`): `BLOCKING -> IDLE` crossfades through `_play()`; block
##     ENTRY and `block -> attack/roll` stay instant `_restart()` cuts (`3-0b/R23`).
##
## LEFT/RIGHT NAMING (6-7b finding, operator ruling: recorded, not renamed): "right" throughout this
## file is local +X, and ANATOMICALLY local +X is the paladin's LEFT (rig `mixamorig_LeftHand` rests
## at x +0.657, toes at +Z). Clip FILES follow this file's convention, not anatomy -- 5-0a's strafe
## swap and 6-7b's walk-strafe and turn swaps all line clip content up with local +X = "right".

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
const LOCOMOTION_BLEND_SECONDS := 0.25

## Story 6-7b (AC 8): each locomotion FAMILY's NATIVE ground speed -- the hero speed at which that
## family's clips play at rate 1.0 with no foot slide. The eight family clips play at
## `pushed_speed / native_speed`, so their rate follows any future tempo retune on its own.
##   RUN: 5.0, the pre-6-7b authored `move_speed` the run family already played correctly at
##        (story-stated, not re-measured); at the retuned 6.0 the family plays at 1.2x.
##   WALK: a STARTING VALUE MEASURED FROM THE CLIP, for the live smoke to tune. Scratch probe (6-7b
##        dev pass) of the planted toe's slide speed in model space: `walk` 1.4097, `run` 3.8648 on
##        the same method, so walk = 5.0 * 1.4097 / 3.8648 = 1.82 when calibrated to RUN's 5.0.
## Presentation knobs beside RUN_SPEED_EPS / STRAFE_BAND_RATIO -- never BalanceConfig fields.
const RUN_FAMILY_NATIVE_SPEED := 5.0
const WALK_FAMILY_NATIVE_SPEED := 1.82

## Fix pass (2026-09-16, operator live smoke item 4): TURN PLAYBACK RATE, proportional to the actual
## rotation rate instead of the retired fixed `TURN_CLIP_SPEED := 1.0`. The defect this replaces: a
## far, slow-circling lock target has a low angular rate, but `TURN_MIN_FACING_CROSS` (below) used to
## sit at ~30 deg/s, so anything selected as a turn ALREADY exceeded a fixed 1.0x-native rotation
## speed by a wide margin and the played clip visibly outran the body's actual rotation -- reading as
## a slide in the idle pose rather than a step. Playing the clip at `rotation_rate / native_rate`
## instead ties the two together at every rate, clamped to a feel range.
##
## NATIVE RATE, MEASURED (`tools/measure_hips_displacement.gd`'s rotation table, both directions):
## `turn_right` source Hips yaw 99.318 deg over 0.9333 s = 106.4159 deg/s; `turn_left` 99.319 deg over
## the same 0.9333 s = 106.4170 deg/s. The two agree to 0.001 deg/s (same source rig, opposite sign),
## so ONE constant serves both clips; the value below is their average.
const TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC := 106.4165

## Live-smoke knobs (final values, not pinned by tests): the clamp on `rotation_rate /
## TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC` so a very slow turn still reads as stepping (floor) and a
## very fast snap-turn does not play the clip absurdly fast (ceiling). TURN_MIN_PLAYBACK_RATE was
## 0.25 at the dev pass; operator re-smoke (6-7b live smoke item 4, round 2) raised it to 0.6 because
## 0.25 looked worse than the pre-fix behaviour even though it was continuous.
const TURN_MIN_PLAYBACK_RATE := 0.6
const TURN_MAX_PLAYBACK_RATE := 2.0

## Story 6-7b (AC 6): THE TURN FLICKER GUARD, two named UNTUNED knobs. A turn clip is selected only
## once the per-tick facing change -- the cross term `prev.x*cur.y - prev.y*cur.x`, the SINE of the
## per-tick yaw change for unit facings -- has been at least TURN_MIN_FACING_CROSS in magnitude, with
## the SAME sign, for TURN_MIN_HOLD_TICKS consecutive pushes. The hold is 3 ticks (50 ms), so a
## slow-circling lock target that hovers at the threshold does not alternate turn/idle tick by tick.
## BY CONSTRUCTION a one-tick facing SNAP (an instant re-lock) never reaches the hold and plays no
## turn clip.
##
## Fix pass (2026-09-16, operator live smoke item 4, ruling option (a)): this was 0.0087 ~ sin(0.5
## deg) per tick (~30 deg/s at 60 Hz) and doubled as the de-facto MINIMUM SELECTABLE ROTATION RATE --
## a far, low-angular-rate lock target never cleared it, so the body rotated in the idle pose instead
## of stepping (the reported defect). The floor is now a true NOISE floor, far below any realistic
## lock rotation rate, and rate-proportional playback (above) covers the low end instead. FINAL value
## (operator re-smoke, round 2): 0.00087 ~ sin(0.05 deg) per tick, ~3 deg/s at 60 Hz -- rotations
## below this floor stay in the idle pose by operator choice, not by measurement.
const TURN_MIN_FACING_CROSS := 0.00087
const TURN_MIN_HOLD_TICKS := 3

## Replays the current locomotion clip only when its wanted rate moved by more than this -- float
## residue in the pushed speed must not re-issue play() every tick.
const _PLAYBACK_SPEED_EPS := 0.01

## Story 6-7b (AC 4): the run-family clip the direction split picks -> its walk-family counterpart.
const _WALK_FAMILY := {
	&"run": &"walk",
	&"strafe_left": &"walk_strafe_left",
	&"strafe_right": &"walk_strafe_right",
	&"backpedal": &"walk_backpedal",
}

## Story 6-6a (AC 11): the runner-computed stun flavor forwarded with a transition or a hit -- NONE when
## the hero is not STUNNED. Presentation constants, never state: the state layer holds no flavor field.
const STUN_FLAVOR_NONE := 0
const STUN_FLAVOR_ORDINARY := 1
const STUN_FLAVOR_KNOCKDOWN := 2
## Story 6-5c (AC 27, `6-5c/R10`/`R16`): THE THIRD FLAVOR -- the bolt stun, which plays `dizzy`.
##
## IT EXISTS BECAUSE DURATION CANNOT TELL IT FROM AN ORDINARY STUN. The deflect stun and the bolt
## stun are BOTH authored 0.4 s, so `BalanceTicks.is_knockdown_stun` classifies both ORDINARY and no
## timing test could separate them (`6-5c/R10` says so by name). The runner computes this flavor from
## `HeroState.stun_is_bolt` -- a fact only the bolt's own stun write sets -- through the EXISTING
## `_stun_flavor_for_slot` read, so no new signal, no new seam and no new `MatchState` intake ships
## (`6-5c/R16`).
const STUN_FLAVOR_BOLT := 3

## Story 6-5c (AC 27, Open Question 8): where the `dizzy` sub-range starts, in seconds.
##
## MEASURED, NOT GUESSED (`tools/measure_cast_clip_frames.gd`): the clip is 4.2667 s long and the
## bolt stun is authored 0.4 s. 1.0 s is far enough in to be past the entry settle and leaves 3.27 s
## of clip, so any plausible retune of `stun_seconds` still fits without clamping. See `_play_dizzy`.
const DIZZY_CUT_START := 1.0

## Story 6-5c (AC 25): THE `cast` CLIP'S MEASURED NUMBERS -- its own length and the timestamp of the
## RAISE, the frame at which the sword reaches its peak above the hips and the bolt leaves it.
## MEASURED, NOT GUESSED, by `tools/measure_cast_clip_frames.gd` (the `measure_*_strike_frames.gd`
## sword-joint probe): the clip is 2.9667 s and the sword peaks 1.0423 m above the hips at t=1.4092,
## which is fraction 0.4750 of the clip.
const CAST_CLIP_SECONDS := 2.9667
const CAST_RAISE_SECONDS := 1.4092

## Story 6-5c (AC 25): A SUB-RANGE AT NATIVE RATE, NOT A SPEED-UP -- the SAME choice `_play_dizzy`
## makes one flavor above, made again here from this clip's own measured numbers.
##
## THE MEASUREMENT DECIDED IT. Against the authored 0.8 s cast the hold rule would run this clip at
## 2.9667 / 0.8 = 3.7083x: a sword raise at nearly four times speed is a twitch, and the whole point
## of AC 25 is that the opponent READS the raise and times a roll against it. Played instead as a
## 0.8 s window at 1.0x, the raise is real motion. The window is placed so the raise beat sits at the
## clip's OWN proportion of it (0.4750, `cast_cut_start` below), which puts the launch at 0.38 s into
## an 0.8 s cast and leaves 0.42 s of sky-to-target fall -- both legible, and both derived from the
## AUTHORED duration, so a `cast_seconds` retune retimes the whole show with no edit here (AC 25's
## "no code edit" clause). Every tuning up to the clip's full 2.9667 s fits without clamping.
##
## LEGIBILITY ITSELF IS THE OPERATOR'S AT SMOKE (`PROC/R8`): this pins the mechanism and the timing,
## never how it looks.
const CAST_RAISE_FRACTION := CAST_RAISE_SECONDS / CAST_CLIP_SECONDS

## The walk-family members as a const list, so the per-tick rate lookup allocates nothing.
const _WALK_FAMILY_MEMBERS: Array[StringName] = [
	&"walk", &"walk_strafe_left", &"walk_strafe_right", &"walk_backpedal",
]

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
## Story 6-6b (AC 2/AC 10/AC 13): THE COLOUR COUNTER'S PRESENTATION, one entry per colour -- the
## ordered list of clips a counter plays and the CUT RANGE of each, in the clip's own native seconds.
##
## THE PRESENTATION IS MAPPED INTO THE BUSY SPAN, NEVER THE REVERSE (AC 2, the `6-1b` precedent).
## Nothing here names a duration: the playback RATE is derived at the press from the total cut length
## against the colour's authored busy span (`counter_clip_speed`), so retuning `counter_busy_seconds_*`
## in the `.tres` re-fits the clip with no edit here, and retuning a cut here re-fits the rate with no
## edit there. That is what makes these FEEL KNOBS rather than a second source of truth for timing,
## and it is why NO TEST PINS THE VALUES BELOW -- only the direction bounds on the authored spans are
## pinned (test_balance_authoring.gd).
##
## THE CUTS ARE MEASURED, NOT GUESSED (`tools/measure_counter_strike_frames.gd`, this pass; the `6-1b`
## impact criterion -- the last big reach maximum that follows the swing's own peak speed, never the
## global max reach). Raw clip lengths and the measured beats:
##   RED   `counter_jump` 0.8333 s, a complete in-place jump (Hips apex 1.531 at t=0.406); then
##         `counter_backflip` 2.1667 s, whose flip completes at t~1.90 and whose last 0.27 s is a
##         static hold -- so the backflip is cut at 1.90 and the pair spans 2.7333 s of clip.
##   BLUE  `counter_slide` 1.7667 s. The Hips drop from standing (0.892) to the slide floor (0.218)
##         between t=0.265 and t=0.574; before that the body is still running. The cut starts at
##         0.3533, where the drop is committed (Hips 0.500) and no run stride is left, and runs to the
##         clip's end so the stand-up completes the counter. The clip's 4.31 m of planar travel is
##         PINNED OUT at assembly (`tools/add_paladin_counter_clips.gd`) because BLUE's body is carried
##         by STATE (AC 9) and the clip must not move it a second time.
##   GREEN `counter_throw` 1.8333 s. The hand's reach peaks at 0.9679 at t=0.6646 (36.25 % of the
##         clip) and then retracts at the clip's own peak speed -- that peak IS the RELEASE, and it
##         confirms the operator's ~36 % starting point by measurement. The cut runs from there to
##         0.7333 of the clip (1.3444 s), the operator's ~74 %.
const _COUNTER_PRESENTATION := {
	Enums.CardColor.RED: [
		{"clip": &"counter_jump", "from": 0.0, "to": 0.8333},
		{"clip": &"counter_backflip", "from": 0.0, "to": 1.9000},
	],
	Enums.CardColor.BLUE: [
		{"clip": &"counter_slide", "from": 0.3533, "to": 1.7667},
	],
	Enums.CardColor.GREEN: [
		{"clip": &"counter_throw", "from": 0.6646, "to": 1.3444},
	],
}

## Story 6-6b (AC 11): how far into GREEN's BUSY SPAN the dagger leaves the hand, as a fraction of it.
## ZERO because the measured release frame IS the cut's first frame (see above): the throw reads as
## instant, which is what a 0.7 s counter needs. A feel knob like the cuts, read by the RUNNER (which
## owns the prop) through `counter_release_fraction` below, so the measurement lives in one file.
const COUNTER_DAGGER_RELEASE_FRACTION := 0.0


## Story 6-6b (AC 2/AC 10): the playback rate for a counter whose cut ranges total `clip_seconds`
## against a busy span of `busy_seconds` -- the rule `_COUNTER_PRESENTATION` documents, as a pure
## function a test can pin directly.
##
## NEVER SLOWER THAN NATIVE, `held_clip_speed`'s own rule (6-6a) applied to a second held
## presentation and for its reason: a stretched counter reads as slow motion. A cut SHORTER than the
## busy span therefore plays at 1.0 and holds its last cut frame for the remainder -- which is what
## GREEN does at the shipped authoring (0.6798 s of clip against a 0.7 s span).
static func counter_clip_speed(clip_seconds: float, busy_seconds: float) -> float:
	if busy_seconds <= 0.0 or clip_seconds <= busy_seconds:
		return 1.0
	return clip_seconds / busy_seconds


## Story 6-6b (AC 11): the dagger's release offset in SECONDS into GREEN's busy span, exposed so the
## runner can schedule the prop without learning the cut table. Zero for every colour but GREEN,
## which is the only one that throws anything.
static func counter_release_seconds(color: int, busy_seconds: float) -> float:
	if color != Enums.CardColor.GREEN:
		return 0.0
	return busy_seconds * COUNTER_DAGGER_RELEASE_FRACTION


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
##   * the chargeup maps to [0, C / (C + L)] of the playhead curve and the launch maps to
##     [C / (C + L), 1.0], but this is NOT a clean wind-up/strike-swing partition: the swing itself
##     begins at the `hold_end` knob (a fraction of the WHOLE curve, unchanged by this story), which
##     falls INSIDE the chargeup span for every authored colour -- measured on the commit frame, RED
##     ~64%, BLUE ~49%, GREEN ~31% of the swing (hold -> strike) has already played before the
##     commit. AC 11's verifiable claim (the strike frame never arrives before the landing tick; no
##     frozen glide) still holds regardless. Code review `6-1c/D1`, ruled `6-1c/R8`: accepted as-is
##     for this story; anchoring the swing start to the commit (chargeup -> [0, hold_end], launch ->
##     [hold_end, 1]) is offered as a smoke-time option to the successor story `6-1d`;
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


## Story 6-1d (AC 8, `6-1d/R6`): THE SWING-AT-COMMIT REMAP -- `6-1c/R8`'s offered option, built.
##
## The linear progress directly above is bent so the two PHASES land on the two halves of the curve
## the clip itself is already divided into: the chargeup fills `[0, hold_end]` (the wind-up and the
## held beat) and the launch fills `[hold_end, 1]` (the fast close to the strike frame). The swing
## then BEGINS at the commit instead of being ~a third to two thirds spent by it.
##
## IT IS A REPARAMETRISATION AND NOTHING ELSE. Both endpoints are fixed -- 0 maps to 0, 1 maps to 1
## -- and it is monotonic, so every claim `6-1c` AC 11 pins about the playhead still holds under it:
## the strike frame still arrives on the landing tick and never before, and the playhead never runs
## backwards. `charge_playhead_seconds` is untouched and the `_CHARGE_HOLD_KNOBS` keep their
## meaning; this only changes WHICH progress value a given tick reports.
##
## DEGENERATE SPANS RETURN THE INPUT, CLAMPED TO `[0, 1]` (a commit fraction at or outside `[0, 1]`, or a
## `hold_end` at or outside it): there is no second phase to stretch into, and inventing one would
## divide by zero. The OFF path never calls this at all -- the caller branches -- so "OFF reproduces
## today exactly" is a property of the call site, not of a zero-valued argument here.
static func charge_commit_anchored_progress(progress: float, commit_fraction: float,
		hold_end_progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if commit_fraction <= 0.0 or commit_fraction >= 1.0 \
			or hold_end_progress <= 0.0 or hold_end_progress >= 1.0:
		return p
	if p <= commit_fraction:
		return hold_end_progress * (p / commit_fraction)
	return hold_end_progress \
			+ (1.0 - hold_end_progress) * ((p - commit_fraction) / (1.0 - commit_fraction))


## Story 6-1d (AC 8): the colour's `hold_end` knob, exposed so the RUNNER can compose the remap above
## with the spans only it knows (the chargeup and launch tick counts). Returns 0.0 for a colour with
## no authored knobs, which the remap reads as "no second phase" and passes the progress through.
static func charge_hold_end_for(color: int) -> float:
	var knobs: Dictionary = _CHARGE_HOLD_KNOBS.get(color, {})
	return float(knobs.get("hold_end", 0.0))

var _state: HeroState.ActionState = HeroState.ActionState.IDLE

## Story 6-6a (AC 2): the yielding one-shot currently owed its play-out (`hit_react`/`get_up`), or empty.
## Cleared by every transition and by `on_locomotion` once the clip has stopped playing.
var _one_shot: StringName = &""

## Story 6-6b (AC 10): the counter presentation currently running -- the colour's step list from
## `_COUNTER_PRESENTATION`, which step of it is playing, and the one derived rate every step shares.
## `_counter_index < 0` means no counter is playing. Presentation-local, never a state field: the
## state layer owns the window and this owns the clips.
##
## ONE RATE FOR THE WHOLE SEQUENCE is what makes RED's two-clip join read as one move rather than two
## clips at two tempos: the rate is derived once, from the TOTAL cut length against the busy span.
##
## POST-REVIEW FIX PASS (findings P1/P3, operator ruling R-P1/P3): THE COUNTER OWNS THE PRESENTATION
## FOR THE WHOLE BUSY SPAN, so the span is remembered ACROSS transitions rather than destroyed by the
## first one. `_counter_running` is the span (armed on the press, cleared only on the falling edge the
## runner pushes) and `_counter_index` is only whether a counter clip is playing RIGHT NOW: an action
## that owns the body (ROLLING/ATTACKING/BLOCKING) clears the second and leaves the first, and the
## transition back INTO IDLE resumes the sequence at the point the span has already reached.
## `_counter_elapsed` is what positions that resume -- seconds into the busy span, pushed every tick by
## the runner (`on_counter_progress`), never counted here.
var _counter_steps: Array = []
var _counter_index := -1
var _counter_speed := 1.0
var _counter_running := false
var _counter_elapsed := 0.0

## Story 6-5c (AC 25): the cast pose currently running and where its sub-range ENDS, in the clip's
## own native seconds. Presentation-local, never a `HeroState` field -- the cast owns no
## `ActionState` (`6-5c/R18`), so the body is claimed the same way the counter claims it: through
## the per-tick locomotion push, which a casting (and therefore IDLE, and therefore rooted) hero
## receives on every tick of the window.
##
## THE CAST AND THE COUNTER CANNOT BOTH BE RUNNING, so the two claims never race: a casting hero is
## refused every card press including the colour counter (AC 8, `6-5c/R6`/`R15`), and a countering
## hero's card presses are refused by the counter's own busy lock (`REASON_COUNTERING`).
var _cast_running := false
var _cast_cut_end := 0.0

## Story 6-7b (AC 6): the turn detector's memory -- presentation-local, never a HeroState field.
## `_prev_facing` advances on EVERY push, IDLE or not (AC 6(b)).
var _has_prev_facing := false
var _prev_facing := Vector2.ZERO
var _turn_sign := 0
var _turn_ticks := 0

## Fix pass (2026-09-16): the RAW per-tick cross term from the most recent `_track_facing` call,
## signed -- kept separately from the HELD `_turn_sign` because the playback-rate calculation needs
## the actual current-tick magnitude, not just whether a turn is selected.
var _last_cross := 0.0


## Story 6-7b (AC 4): the walk/run family boundary -- the MIDPOINT of the authored pair. In IDLE the
## pushed speed is discrete (zero, walk, or run), so the midpoint sits as far from each as it can;
## a bare `walk_speed` threshold would flip a walking hero to the run family on the float residue of
## a velocity length landing a hair above it. Pure and static so it can be asserted directly.
static func gait_threshold(walk_speed: float, run_speed: float) -> float:
	return (walk_speed + run_speed) * 0.5


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
##
## STORY 6-6a widens the forwarded tail by three runner-computed values, on `charge_color`'s shape:
##   `stun_flavor` / `stun_seconds` -- the STUNNED clip and how long to hold it (AC 10/AC 11);
##   `get_up_armed` -- true when the state layer has just opened the get-up iframes, which only the
##   knockdown's TIMER exit does (AC 8), so the debug reset's identical `STUNNED -> IDLE` plays no get-up.
## And `BLOCKING -> IDLE` is the one transition that BLENDS (AC 13): through `_play()`, not `_restart()`.
func on_action_state_changed(previous: HeroState.ActionState, current: HeroState.ActionState,
		charge_color: int = PlayerState.NO_TELEGRAPH_COLOR, stun_flavor: int = STUN_FLAVOR_NONE,
		stun_seconds: float = 0.0, get_up_armed: bool = false) -> void:
	_state = current
	_one_shot = &""
	# Story 6-6b (AC 10): a real transition takes the body from a counter clip in flight, the
	# `_one_shot` line directly above's own rule -- a knockdown or a death must not wait for a cut.
	#
	# POST-REVIEW FIX PASS (R-P1/P3): IT NO LONGER ENDS THE SPAN, only the clip. `_counter_running`
	# survives, so STUNNED/DEAD still win outright (nothing below returns the body while they hold the
	# state) while ROLLING/ATTACKING/BLOCKING merely borrow it -- and the IDLE branch below RESUMES the
	# sequence at the span's elapsed point when the window is still running. Before this pass the first
	# transition of any kind set this to -1 with nothing left to re-arm it: the runner's rising edge had
	# already passed, so the rest of the span played no counter at all.
	_counter_index = -1
	if current == HeroState.ActionState.STUNNED:
		_play_stun(stun_flavor, stun_seconds)
		return
	if current == HeroState.ActionState.IDLE:
		if previous == HeroState.ActionState.STUNNED and get_up_armed:
			# The get-up is the TAIL of a knockdown, which ruling (c) already let win outright, so it
			# keeps the body ahead of a resume. With the authored numbers this cannot even be reached:
			# the knockdown stun (2.5 s) outlasts the longest busy span (RED, 1.5 s), so the falling
			# edge has ended the counter before this line runs.
			_restart(&"get_up")
			_one_shot = &"get_up"
			return
		# R-P1/P3 (b): a transition INTO IDLE while the window still runs STARTS or RESUMES the
		# counter. Both interrupted shapes land here -- the block dropped by the cast in the same frame
		# as the press (the poll ran before this drain, so the span is already armed), and a swing or
		# roll that finished inside the span.
		if _counter_running and _resume_counter():
			return
		if previous == HeroState.ActionState.BLOCKING:
			# `3-0b/R24`'s pre-cleared shape: EXIT only, and only to IDLE. Entry and block -> attack/roll
			# never reach this line (they are not IDLE entries), so they keep the instant cut.
			_play(&"idle")
			return
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


## Story 6-6a (AC 1/AC 2/AC 5/AC 12): the SECOND consumer of the existing `hit_landed` seam, gated on
## this hero's own slot exactly as `TelegraphController.on_hit_landed` is. The payload is the seam's
## unchanged four plus the bound slot; `stun_flavor`/`stun_seconds` are runner-computed and forwarded by
## the wiring closure, the `charge_color` shape -- the signal itself is never widened.
##
## SELECTION READS THE MIRRORED `_state`, NEVER A LIVE `action_state`: the queued transitions and this
## hit drain FIFO from one queue, so `_state` is what the hero was when the hit was pushed.
##   IDLE     -> `hit_react` (a yielding one-shot). No other state is interrupted: mid-action flinch is
##               the deferred hitstun system's (AC 2).
##   BLOCKING -> `block_impact` (AC 12), but ONLY when the runner forwards `blocked` -- the hit really took
##               the block branch. A full-damage hit from OUTSIDE the block arc plays NOTHING (6-6a
##               review D2): the hero is BLOCKING, not IDLE-family, so AC 2 gives it no `hit_react`
##               either, exactly like a hit landing mid-attack. A knockdown's own write precedes its hit
##               on the queue, so an unanswered unblockable on a blocker reads STUNNED here and never
##               reaches this branch.
##   STUNNED  -> no hurt clip; but a forwarded KNOCKDOWN over a clip that is not already `knockdown` is
##               the AC 5 ESCALATION and switches to it. A knockdown already playing is left alone --
##               a second landing never restarts the hold (AC 7/AC 11).
func on_hit_landed(_attacker_slot: int, target_slot: int, _damage: float, _target_hp: float,
		my_slot: int, stun_flavor: int = STUN_FLAVOR_NONE, stun_seconds: float = 0.0,
		blocked: bool = false) -> void:
	if target_slot != my_slot:
		return
	match _state:
		HeroState.ActionState.IDLE:
			# POST-REVIEW FIX PASS (R-P1(a)): a COUNTERING hero keeps its counter clip. The 6-6a AC 2
			# register applied to the one state that has no `ActionState` of its own -- `hit_react`
			# interrupts nobody mid-action, and a hero inside its busy span is acting. Before this pass
			# the flinch restarted over the counter WITHOUT clearing `_counter_index`, so the next cut
			# check read the changed clip as "the cut ended" and either froze on a `hit_react` frame or
			# jumped RED straight to its backflip.
			if _counter_running:
				return
			_restart(&"hit_react")
			_one_shot = &"hit_react"
		HeroState.ActionState.BLOCKING:
			if blocked:
				_restart(&"block_impact")
		HeroState.ActionState.STUNNED:
			if stun_flavor == STUN_FLAVOR_KNOCKDOWN \
					and animation_player.assigned_animation != &"knockdown":
				_play_stun(stun_flavor, stun_seconds)


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
##
## STORY 6-7b: `walk_speed`/`run_speed` are the authored gait pair (AC 4). The facing memory for turn
## detection advances BEFORE the IDLE gate, on every push (AC 6(b)): otherwise a facing change made
## during a roll or attack would still be pending when IDLE resumed and fire a spurious turn. Only
## the turn-clip SELECTION is IDLE-gated, and it is also gated on standing still, so a moving hero
## never turns in place by construction (Non-Goal).
func on_locomotion(velocity: Vector3, facing: Vector2, walk_speed: float, run_speed: float) -> void:
	var turn := _track_facing(facing)
	if _state != HeroState.ActionState.IDLE:
		return
	# Story 6-6b (AC 10): THE COUNTER OWNS THE BODY for its whole busy span, and it rides THIS per-tick
	# push rather than a clock of its own -- F1 is untouched and no new seam is added (AC 14). The push
	# is what advances the cut: `AnimationPlayer` has no "play this sub-range" primitive, so the END of
	# a cut is enforced by checking the playhead each tick, which is exactly the tick rate this
	# controller already runs at. A countering hero is IDLE (the counter owns no `ActionState`, AC 2),
	# so this line is reached on every tick of the span.
	# Story 6-5c (AC 25): THE CAST OWNS THE BODY for its whole window, and it rides THIS per-tick push
	# for the counter's reason directly below -- `AnimationPlayer` has no "play this sub-range"
	# primitive, so the END of the cut is enforced by checking the playhead each tick. A casting hero
	# is IDLE (the cast owns no `ActionState`, `6-5c/R18`) and hard-rooted, so this line is reached on
	# every tick of the cast and the locomotion choice below would otherwise cut straight back to
	# `idle` on the tick after the pose started.
	if _cast_running:
		_advance_cast()
		return
	if _counter_index >= 0:
		_advance_counter()
		return
	# Story 6-6a (AC 2): THE LOCOMOTION YIELD. A `hit_react`/`get_up` still playing keeps the body; the
	# idempotent `_play()` below would otherwise crossfade it away on the very next tick.
	if _one_shot != &"":
		if animation_player.current_animation == _one_shot and animation_player.is_playing():
			return
		_one_shot = &""
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed <= RUN_SPEED_EPS and turn != 0:
		# Negative cross = facing rotating toward local +X, this file's "right" (header).
		_play(&"turn_right" if turn < 0 else &"turn_left", _turn_playback_rate())
		return
	var clip := _locomotion_clip(velocity, facing, walk_speed, run_speed)
	_play(clip, _playback_speed(clip, planar_speed))


## Story 6-6b (AC 10): THE COUNTER STARTS ON THE PRESS, not on the resolution -- pushed by the runner
## on the RISING EDGE of the `defense` snapshot key (`match_runner._push_counter_presentation`), the
## `on_charge_progress` call site's precedent exactly: a plain per-tick read of an EXISTING public
## fact, no signal, no state handle, no new `connect_*` (AC 14).
##
## SO A COUNTER THAT ANSWERS NOTHING STILL PLAYS IN FULL, which is the whole point of keying on
## the press: nothing here waits to learn whether the counter landed, and nothing here is ever told.
## `6-9` superseded the paid feint this paragraph used to name as the bait; a counter pressed against
## no attack at all, or against one a knockdown abandons, is the case that remains.
##
## `busy_seconds` IS THE COLOUR'S AUTHORED SPAN, converted from ticks by the runner (the
## `_stun_seconds_for_slot` shape). It is used for ONE thing -- deriving the shared playback rate --
## so this controller still reads no balance and holds no window handle (CONSTRAINT C).
##
## AN UNKNOWN COLOUR PLAYS NOTHING and leaves the pose alone, `_play_stun`'s degrade verbatim. The
## sentinel reaches here only from a degraded cast, which the state layer already gives no window and
## therefore no rising edge at all.
func on_counter_started(color: int, busy_seconds: float) -> void:
	var steps: Array = _COUNTER_PRESENTATION.get(color, [])
	if steps.is_empty():
		return
	var total := 0.0
	for step: Dictionary in steps:
		total += float(step["to"]) - float(step["from"])
	_counter_steps = steps
	_counter_speed = counter_clip_speed(total, busy_seconds)
	_counter_elapsed = 0.0
	_counter_running = true
	_counter_index = -1
	# POST-REVIEW FIX PASS (R-P1/P3 (d)): while an ACTION owns the body its own clip plays and the
	# counter only arms -- the span keeps ticking from the press regardless, off the runner's push, and
	# the transition back into IDLE resumes it wherever the span has got to.
	if _state == HeroState.ActionState.IDLE:
		_resume_counter()


## Story 6-6b (AC 10), POST-REVIEW FIX PASS (R-P1/P3): pushed every tick the window runs, right beside
## the edges above and from the same poll -- `elapsed` seconds into the busy span, computed runner-side
## from the window the `defense` key is built from. It moves no clip: it is the position a RESUME needs,
## so that a counter which spent part of its span inside a swing rejoins its sequence where the span
## actually is rather than restarting it. `on_charge_progress`'s shape (a plain float, no window handle,
## no balance read -- CONSTRAINT C), and like it, not a seam (AC 14: the `connect_*` family stays TEN).
func on_counter_progress(elapsed_seconds: float) -> void:
	_counter_elapsed = elapsed_seconds


## Story 6-6b (AC 10): pushed on the FALLING edge of the same key -- the busy span is over, so the
## body goes back to the locomotion push. Without it the last cut frame would be held forever, since
## a cut END is a pause rather than a finished clip and `on_locomotion`'s `_one_shot` yield reads
## "still playing".
##
## POST-REVIEW FIX PASS: this is now the ONLY thing that ends the span (`_counter_running`), which is
## what makes a transition borrow the body rather than destroy the presentation. The runner also pushes
## it ahead of a RE-CAST's new start (R-P2), so the old counter ends -- and its dagger is freed --
## before the new one begins.
func on_counter_ended() -> void:
	_counter_running = false
	_counter_steps = []
	_counter_index = -1
	_counter_elapsed = 0.0
	_one_shot = &""


## POST-REVIEW FIX PASS (R-P1/P3 (b)): START or RESUME the sequence at the span's ELAPSED point. The
## elapsed seconds buy `elapsed * _counter_speed` seconds of CUT at the sequence's one shared rate, and
## that budget is spent across the steps in order -- so RED's join still lands where it belongs instead
## of the backflip restarting from the top after a swing. Past the last cut end it clamps to that frame,
## which is the hold `_advance_counter` would already be sitting on. Returns false for an armed span
## with no steps, so the caller can fall through to its own clip choice.
func _resume_counter() -> bool:
	if _counter_steps.is_empty():
		return false
	var consumed := maxf(_counter_elapsed, 0.0) * _counter_speed
	for i: int in _counter_steps.size():
		var step: Dictionary = _counter_steps[i]
		var from := float(step["from"])
		var to := float(step["to"])
		if consumed < to - from or i == _counter_steps.size() - 1:
			_counter_index = i
			_restart(step["clip"], _counter_speed)
			animation_player.seek(minf(from + consumed, to), true)
			_one_shot = step["clip"]
			return true
		consumed -= to - from
	return false


## Plays the current step from its cut START at the sequence's shared rate. `_restart` seeks to 0
## first (its own documented reason), so the seek to the cut start has to follow it.
func _play_counter_step() -> void:
	var step: Dictionary = _counter_steps[_counter_index]
	_restart(step["clip"], _counter_speed)
	animation_player.seek(float(step["from"]), true)
	_one_shot = step["clip"]


## Story 6-6b (AC 10): the per-tick cut enforcement. Past the current step's cut END, move to the next
## step; past the LAST one, PAUSE on that frame and hold it for whatever is left of the busy span
## (`counter_clip_speed` never slows a clip below native, so a short cut genuinely has time left to
## hold -- the `_play_stun` hold rule, applied to a second held presentation).
func _advance_counter() -> void:
	var step: Dictionary = _counter_steps[_counter_index]
	# A cut END is reached EITHER by the playhead passing it OR by the clip running out on its own --
	# and the second case has to be handled explicitly, because a LOOP_NONE animation that finishes
	# clears `current_animation` (it survives only on `assigned_animation`). A step whose cut END is
	# the clip's own length, which RED's `counter_jump` is, reaches the join that way and no other.
	var ended: bool = animation_player.current_animation != step["clip"] \
			or animation_player.current_animation_position >= float(step["to"])
	if not ended:
		return
	if _counter_index + 1 < _counter_steps.size():
		_counter_index += 1
		_play_counter_step()
		return
	animation_player.pause()


## Story 6-7b (AC 6): advances the facing memory and returns the HELD turn sign -- +1 / -1 once the
## same-signed cross term has cleared TURN_MIN_FACING_CROSS for TURN_MIN_HOLD_TICKS pushes in a row,
## else 0. The first push ever has nothing to compare against and reads as no change.
func _track_facing(facing: Vector2) -> int:
	var cross := 0.0
	if _has_prev_facing:
		cross = _prev_facing.x * facing.y - _prev_facing.y * facing.x
	_last_cross = cross
	_prev_facing = facing
	_has_prev_facing = true
	var turn_sign := 0
	if absf(cross) >= TURN_MIN_FACING_CROSS:
		turn_sign = 1 if cross > 0.0 else -1
	if turn_sign == 0 or turn_sign != _turn_sign:
		_turn_ticks = 0
	_turn_sign = turn_sign
	if turn_sign != 0:
		_turn_ticks += 1
	return _turn_sign if _turn_ticks >= TURN_MIN_HOLD_TICKS else 0


## Fix pass (2026-09-16, operator live smoke item 4): the turn clips' rate, `rotation_rate /
## TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC` clamped to the feel range -- see the knobs' header comment.
## `_last_cross` is the SIGNED per-tick sine-of-yaw term from `_track_facing`'s most recent call, i.e.
## this same tick's (small-angle approximation, no atan2, `DECISION A` precedent above); only its
## MAGNITUDE feeds the rate (direction already picked the clip). `Engine.physics_ticks_per_second`
## converts the per-tick angle to a per-second rate -- legal here (this file is not `src/state/`,
## D3(b)/A2 scopes that ban to the state layer only).
func _turn_playback_rate() -> float:
	var rate_deg_per_sec := rad_to_deg(absf(_last_cross)) * Engine.physics_ticks_per_second
	var ratio := rate_deg_per_sec / TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC
	return clampf(ratio, TURN_MIN_PLAYBACK_RATE, TURN_MAX_PLAYBACK_RATE)


## Story 6-7b (AC 8): `pushed_speed / family native speed` for the eight family clips, 1.0 for
## everything else (`idle` plays native, as before).
func _playback_speed(clip: StringName, planar_speed: float) -> float:
	if _WALK_FAMILY.has(clip):
		return planar_speed / RUN_FAMILY_NATIVE_SPEED
	if _WALK_FAMILY_MEMBERS.has(clip):
		return planar_speed / WALK_FAMILY_NATIVE_SPEED
	return 1.0


## The five-way split, as a pure function of the two pushed values so it can be asserted
## directly (test/integration/test_hero_clip_selection.gd drives the four cardinals).
##
## Facing is expected normalized (state writes it that way), but a zero or degenerate facing is
## survivable rather than fatal: with no direction to be relative TO, the projections collapse
## to zero and this falls through to `run` — the pre-5-0a behaviour for a moving hero, which is
## the right thing to degrade to.
##
## STORY 6-7b (AC 4): the split below picks the RUN-family name as it always has; a pushed planar
## speed under `gait_threshold` of the authored pair then swaps it for its walk-family counterpart.
func _locomotion_clip(velocity: Vector3, facing: Vector2, walk_speed: float,
		run_speed: float) -> StringName:
	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() <= RUN_SPEED_EPS:
		return &"idle"
	# Local +Z lies along facing; local +X lies along (facing.y, -facing.x). See the header:
	# two dot products, never an angle, so no second atan2 enters the codebase.
	var forward := planar.x * facing.x + planar.y * facing.y
	var right := planar.x * facing.y - planar.y * facing.x
	var clip: StringName
	if absf(right) > absf(forward) * STRAFE_BAND_RATIO:
		clip = &"strafe_right" if right > 0.0 else &"strafe_left"
	else:
		clip = &"run" if forward >= 0.0 else &"backpedal"
	if planar.length() < gait_threshold(walk_speed, run_speed):
		return _WALK_FAMILY[clip]
	return clip


## Idempotent selection for the polled locomotion path: switch only on an actual change, and
## when it IS a change, crossfade rather than cut (5-0a AC 2). The guard is what makes the
## blend meaningful as well as what makes the path idempotent — an unguarded play() every tick
## would restart the blend every tick and never finish it.
##
## STORY 6-7b (AC 8): `speed` is play()'s own per-playback custom speed, NEVER the player-wide
## `AnimationPlayer.speed_scale` (which would also retime attack/roll and desync 6-1b's seek-driven
## charge playhead). A rate change on the clip already playing re-issues play() with the new speed:
## measured on Godot 4.6.3, that updates the rate without restarting or moving the playhead.
func _play(clip: StringName, speed: float = 1.0) -> void:
	if animation_player.current_animation != clip \
			or absf(animation_player.get_playing_speed() - speed) > _PLAYBACK_SPEED_EPS:
		animation_player.play(clip, LOCOMOTION_BLEND_SECONDS, speed)


## Story 6-6a (AC 10/AC 11): the STUNNED pose -- `knockdown` for the knockdown flavor, `stunned` for the
## two ordinary ones -- played ONCE and HELD, never looped (both clips are LOOP_NONE, so the player stops
## on the final frame and the pose stays). An unknown flavor leaves the current pose, as before 6-6a.
##
## HOLD, WITH A FLOOR ON TEMPO (Open Question 2, dev-pass call): a clip LONGER than the stun is sped up
## just enough to finish on the exit tick (so a 0.4 s deflect still shows the whole 0.7 s reaction rather
## than being cut mid-motion); a clip SHORTER than the stun plays at its native rate and holds its last
## frame for the remainder. Never slowed below native -- a stretched fall reads as slow motion.
func _play_stun(stun_flavor: int, stun_seconds: float) -> void:
	var clip: StringName
	match stun_flavor:
		STUN_FLAVOR_KNOCKDOWN:
			clip = &"knockdown"
		STUN_FLAVOR_ORDINARY:
			clip = &"stunned"
		# Story 6-5c (AC 27): the BOLT stun takes its own pose, so `stunned` stays bit-identical for
		# the deflect stun it has always meant (the story's Non-Goals say so explicitly).
		STUN_FLAVOR_BOLT:
			clip = &"dizzy"
		_:
			return
	# Story 6-5c (Open Question 8, MEASURED and answered here). `dizzy` is 4.2667 s against a 0.4 s
	# bolt stun, so the ordinary hold rule would run it at 10.67x -- which reads as a blur, not a
	# stagger. The question was left OPEN to the dev pass with cutting named as the alternative, and
	# cutting is what this takes: `dizzy` plays a SUB-RANGE at its NATIVE rate instead of the whole
	# clip sped up. Every other flavor keeps the unchanged hold rule, so `stunned` and `knockdown`
	# are bit-identical.
	#
	# THE OFFSET IS A PRESENTATION CONSTANT, not a measurement baked into the library (the clips are
	# added raw and uncut, `add_paladin_cast_clips.gd`'s own ruling), so a smoke-time retune is one
	# line here. The range is clamped to the clip, so a stun longer than the remaining clip falls
	# back to holding the final frame exactly as the other flavors do.
	if clip == &"dizzy":
		_play_dizzy(stun_seconds)
		return
	_restart(clip, held_clip_speed(animation_player.get_animation(clip).length, stun_seconds))


## Story 6-5c (AC 27, Open Question 8): the bolt stun's pose -- a sub-range of `dizzy` at native
## rate, seeked to `DIZZY_CUT_START` and left to run for the stun window.
##
## NATIVE RATE IS THE POINT. `held_clip_speed` exists to fit a LONGER clip into a SHORTER hold by
## speeding it up, and at 10.67x that stops being a stagger and becomes a flicker. Seeking into the
## clip and playing it forward at 1.0 shows 0.4 s of real dizzy motion instead.
##
## LEGIBILITY IS THE OPERATOR'S CALL AT SMOKE (`PROC/R8`): this pins the MECHANISM and the timing,
## never how it looks, and smoke step 16 is where `dizzy` and `stunned` are judged side by side at
## the same 0.4 s.
func _play_dizzy(stun_seconds: float) -> void:
	var length := animation_player.get_animation(&"dizzy").length
	var start := minf(DIZZY_CUT_START, maxf(0.0, length - stun_seconds))
	animation_player.play(&"dizzy", -1.0, 1.0)
	animation_player.seek(start, true)


## Story 6-5c (AC 25): WHERE THE `cast` SUB-RANGE STARTS, in the clip's own native seconds, for a
## cast of `cast_seconds`. A pure function a test can pin directly, `held_clip_speed`'s shape.
##
## The window is placed so the measured RAISE sits at the clip's own proportion of it
## (`CAST_RAISE_FRACTION`), and then clamped into the clip: a cast LONGER than the clip starts at 0
## and holds the final frame for the remainder (`_play_stun`'s own degrade), and a cast so long that
## the raise would fall outside the window still gets a start of 0 rather than a negative seek.
static func cast_cut_start(cast_seconds: float) -> float:
	var want := CAST_RAISE_SECONDS - CAST_RAISE_FRACTION * cast_seconds
	return clampf(want, 0.0, maxf(CAST_CLIP_SECONDS - cast_seconds, 0.0))


## Story 6-5c (AC 25): HOW FAR INTO THE CAST THE BOLT LEAVES THE SWORD, in seconds -- the distance
## from the sub-range's start to the measured raise frame. Exposed so the RUNNER, which owns the
## prop, can schedule the launch without learning the clip's numbers (`counter_release_seconds`'s
## role for the dagger). Clamped into the window, so a degenerate tuning launches at the press or at
## the strike rather than outside the cast.
static func cast_launch_seconds(cast_seconds: float) -> float:
	return clampf(CAST_RAISE_SECONDS - cast_cut_start(cast_seconds), 0.0, maxf(cast_seconds, 0.0))


## Story 6-5c (AC 25): THE CAST POSE STARTS ON THE PRESS -- pushed by the runner on the RISING EDGE
## of the `cast` snapshot key (`match_runner._push_cast_presentation`), `on_counter_started`'s call
## site and shape exactly: a plain per-tick read of an EXISTING public fact, no signal, no state
## handle, no new `connect_*` (`6-5c/R16`).
##
## `cast_seconds` is the AUTHORED duration the state layer armed the window with, converted from
## ticks by the runner (the `_stun_seconds_for_slot` shape), so this controller still reads no
## balance, no effect and no window handle (CONSTRAINT C).
func on_cast_started(cast_seconds: float) -> void:
	var start := cast_cut_start(cast_seconds)
	_cast_cut_end = minf(start + maxf(cast_seconds, 0.0), CAST_CLIP_SECONDS)
	_cast_running = true
	animation_player.play(&"cast", -1.0, 1.0)
	animation_player.seek(start, true)
	# The locomotion yield (`_one_shot`) keeps a real transition -- a stun interrupting the cast, or
	# death -- winning the body outright, exactly as it does for `hit_react`.
	_one_shot = &"cast"


## Story 6-5c (AC 25): pushed on the FALLING edge of the same key -- the strike or an interrupt has
## ended the cast, so the body goes back to the locomotion push. Without it the last cut frame would
## be held forever, since a cut END is a pause rather than a finished clip.
func on_cast_ended() -> void:
	_cast_running = false
	_cast_cut_end = 0.0
	_one_shot = &""


## Story 6-5c (AC 25): the per-tick cut enforcement -- past the sub-range's END, PAUSE on that frame
## and hold it for whatever is left of the cast. `_advance_counter`'s rule with one step instead of a
## list, and for its reason: the range is placed by `cast_cut_start` to run out exactly at the strike
## at the authored tuning, so the hold only covers rounding and a tuning longer than the clip.
func _advance_cast() -> void:
	if animation_player.current_animation != &"cast" \
			or animation_player.current_animation_position >= _cast_cut_end:
		animation_player.pause()


## Story 6-6a (Open Question 2): the playback rate for a clip held over a `hold_seconds` window -- the
## rule `_play_stun` documents, as a pure function a test can pin directly.
static func held_clip_speed(clip_seconds: float, hold_seconds: float) -> float:
	if hold_seconds <= 0.0 or clip_seconds <= hold_seconds:
		return 1.0
	return clip_seconds / hold_seconds


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
