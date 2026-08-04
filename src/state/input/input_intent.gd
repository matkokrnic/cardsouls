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

## KEY CONTRACT (story 1-3): pressed/held keys are PREFIX-FREE action names — &"attack",
## &"block", &"roll". The p1_/p2_ Input Map prefix is the producing controller's private
## business and must never leak into the intent; the state layer's transition table reads
## these keys slot-agnostically.
var move_dir := Vector2.ZERO                    # normalized-ish planar move, this tick
var aim := Vector2.ZERO                         # facing/aim, this tick
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


func is_pressed(action: StringName) -> bool:
	return pressed.get(action, false)


func is_held(action: StringName) -> bool:
	return held.get(action, false)
