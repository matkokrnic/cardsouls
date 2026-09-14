class_name InputIntent
extends RefCounted

## D3 pure per-tick value object. A Controller produces one of these each tick; the
## state layer consumes it and never knows the source (keyboard / gamepad / AI / replay).
##
## LIFETIME (decided E0 item 3): a Controller returns a FRESH InputIntent per sample() —
## an immutable-per-tick value. It is never a reused mutable instance, so the X5 recorder
## (which retains a reference each tick) can never hold N aliases of one ever-changing
## object. Do NOT mutate-and-return a cached instance.
##
## This is INPUT, not persistent state — it is captured separately in the X5 intent
## stream and is deliberately excluded from the to_snapshot() determinism contract.

## Story 4-6 (AC 11): the resting `retarget_slot` -- NO retarget requested this tick. Named
## rather than a bare -1 at four call sites, because -1 also means "the hero" in the INDEX half
## directly beside it and the two must not read as the same sentinel.
const NO_RETARGET := -1

## KEY CONTRACT (story 1-3): pressed/held keys are PREFIX-FREE action names — &"attack",
## &"block", &"roll". The p1_/p2_ Input Map prefix is the producing controller's private
## business and must never leak into the intent; the state layer's transition table reads
## these keys slot-agnostically.
var move_dir := Vector2.ZERO                    # normalized-ish planar move, this tick
## Story 4-6 (AC 8): `aim` IS GONE, not left present-but-unused. It existed for exactly one
## route -- the free camera rotation `DP/R1` sketched -- and `CC/R2` SUPERSEDES that route
## rather than supplementing it: the camera is always locked, so there is nothing to aim. A
## field kept alive for a purpose that no longer exists is rot, and `DP/R1`'s own "repurposed,
## still flowing through aim" lean was read against and rejected on a MEASURED fact, not taste:
## `aim`'s resting `Vector2.ZERO` is a VALID `[slot, index]` address (slot 0's unit 0), so the
## field has no "no retarget" sentinel inside its own value space -- and moving its resting
## value would make every existing v5 record decode a resting `aim` as a live retarget. That is
## the silently-diverging replay `RecordFile.FORMAT_VERSION` exists to refuse, so the retarget
## rides its own honestly-named pair below and the format bumps 5 -> 6 (AC 14).
var pressed: Dictionary[StringName, bool] = {}  # action -> just-pressed this tick
var held: Dictionary[StringName, bool] = {}     # action -> currently held
## Story 1-7 (D-2, operator decision): intent-carried debug affordance — a round-scoped
## reset request applied by advance() step 1. Deliberately NOT gated on a FeatureFlags
## flag (operator affordance, not a gameplay path; exception recorded in the decision
## log). Because it rides the intent, the X5 stream records it for free once the
## recorder lands — no separate event class.
var debug_reset: bool = false

## Story 3-5a (AC 1): the CARD half of the intent — exactly three fields, because the state
## layer receives exactly three things about a cast: which hand slot is armed, which mode is
## armed, and whether a commit fired this tick. The mode-select SCHEME (which keys arm what,
## whether a modifier is held, how the selection is cleared) lives entirely in
## src/controllers/ and is invisible here, so swapping it touches no state file — pinned by
## test_architecture_invariants.gd::test_card_scheme_only_in_controllers.
##
## NO ACTION NAME REACHES THIS OBJECT. The existing key contract above makes `pressed`/`held`
## keys PREFIX-FREE; the card half goes one step further and carries no action name at all —
## the controller resolves `p1_card_2` to the plain index 1 privately. That is strictly
## stronger than the prefix-free rule and is why AC 11's "prefix-free by the time it reaches
## the intent" is satisfied by construction rather than by a strip step that could rot.
##
## -1 is NO SLOT ARMED, and it is the resting value: a commit with no armed slot is a rejection
## at step 6, never a silent cast of slot 0 (test_card_play.gd pins it). The mode defaults to
## BASIC because BASIC is the enum's zero value — see Enums.ModeKind.
var card_slot: int = -1
var card_mode: Enums.ModeKind = Enums.ModeKind.BASIC
## The COMMIT EDGE for this tick — just-pressed semantics, like debug_reset. Held commits do
## not re-cast: one press, one cast attempt.
var card_commit: bool = false
## Story 6-3a (AC 4): the FOURTH card field, and the one exception to "exactly three" above. Meaningful
## only under `card_mode == PITCH`: `false` (the resting value, and every pre-6-3a recorded commit) is
## a STAGE of `card_slot`; `true` is an ACTIVATION of the committing player's own staged card, and
## `card_slot` is then irrelevant. A separate field rather than a reinterpretation of `card_slot == -1`,
## because a PITCH commit with no slot armed already means "refused as an empty slot" and must keep
## meaning that -- two commits the state layer has to tell apart cannot share one encoding.
## `Enums.ModeKind` gains no fifth value for this: the GDD has four modes, and activation is mode ④'s.
var card_activate: bool = false

## Story 4-6 (AC 11, `CC/R5`): the LOCK/RETARGET half of the intent -- the RESULT of a
## right-stick click or flick, never the deflection that produced it. Screen-space candidate
## resolution is PRESENTATION work (it needs a camera and world positions, neither of which may
## enter src/state/ -- D3(b)/A2), so the runner resolves the request against the live scene and
## stamps the ANSWER here, before the X5 tap and before advance(). Replay therefore re-applies
## the outcome of a flick and never re-derives it from a stick reading whose camera no longer
## exists -- the contact-fact precedent (`1-8`/`4-1` R7 lineage) applied to input.
##
## THE ADDRESS IS THE `4-3a/R16` CONVENTION, whose home is `TargetingService.HERO_INDEX`:
## `[slot, index]`, and `index == -1` is that slot's HERO.
##
## -1 IS NO REQUEST, and it is the resting value -- the `card_slot` shape verbatim. A tick with
## no click and no flick leaves the standing lock untouched; there is no "unlock" value, because
## `CC/R2` says there is no unlocked state (AC 10).
var retarget_slot: int = NO_RETARGET
var retarget_index: int = TargetingService.HERO_INDEX


func is_pressed(action: StringName) -> bool:
	return pressed.get(action, false)


func is_held(action: StringName) -> bool:
	return held.get(action, false)
