class_name KeyboardController
extends Controller

## D3 keyboard controller. Takes a prefix ("p1" / "p2") so split-screen (E2) needs no remap
## and no second class — one class, two instances reading p1_* / p2_* Input Map actions.
##
## INVARIANT D3(a): this is one of the ONLY sites where Input.* may appear. State and actor
## code never touch the Input singleton (grep-checkable — matches only under src/controllers/).

## Intent keys are PREFIX-FREE (story 1-3): the state layer reads &"attack" / &"block" /
## &"roll" and never knows which player slot or Input Map action produced them. The
## p1_/p2_ prefix is this controller's PRIVATE mapping to the Input Map.
const INTENT_ACTIONS: Array[StringName] = [&"attack", &"block", &"roll", &"run"]

## Story 3-5a (AC 1): the hand size this scheme binds keys for. PRESENTATION-LOCAL CONSTANT, the
## HudRoot card-row precedent (2-5/R1) — the hand is four at all times per the GDD, and reading
## the authored hand_size here would make the controller depend on balance data it has no other
## reason to see. If hand size ever varies (OPEN decision (e), carried by 3-3), this constant and
## the Input Map entries move together.
const CARD_SLOTS := 4

var _up: StringName
var _down: StringName
var _left: StringName
var _right: StringName
var _debug_reset: StringName
var _action_map: Dictionary[StringName, StringName] = {}  # intent key -> Input Map action

## Story 3-5a (AC 1): THE MODE-SELECT SCHEME, and it lives entirely here. The state layer
## receives three plain values (slot, mode, commit) and knows nothing about how they were
## produced — so replacing this scheme wholesale touches no file outside src/controllers/,
## which is the property test_architecture_invariants.gd::test_card_scheme_only_in_controllers
## exists to keep true.
##
## THE SCHEME, keyboard only this story:
##   HOLD  pX_cast_mode        enter cast mode
##   PRESS pX_card_1 .. _4     arm that hand slot (the selection indicator lights)
##   PRESS pX_cast_confirm     commit the armed slot, mode BASIC
##   RELEASE pX_cast_mode      exit instantly and disarm
##
## Story 5-7 (AC 12): the two TEMPORARY confirm keys `5-3` and `5-5` added here (`pX_cast_unblockable`
## for UNBLOCKABLE, `pX_cast_defense` for DEFENSE) are GONE -- branch, field, action-string line and
## Input Map action each, exactly the four-part inventory both stories named for this one. The pad
## scheme's B and X confirm those two modes now, so the keyboard stand-ins have no job left. The
## arm-then-confirm sequence itself is untouched: only the two redundant confirm keys left.
##
## PROVISIONAL, NOT SETTLED. The card-mode-select UX is an open high-P4 question (GDD §Controls);
## this is ONE scheme implemented so the layer can be played at all, and the live smoke exists to
## judge its feel. Note what the smoke CANNOT judge: exactly one mode is reachable in E3, so
## whether MODE selection survives real-time pressure is not answered here — its forcing point
## moves to E5, when the other modes land.
##
## WHY ARM-THEN-CONFIRM rather than press-a-card-to-cast: AC 1 requires slot, mode and commit to
## reach state as three separate things, and AC 10's selection indicator has nothing to show
## unless an ARMED state exists between the two presses. The two-step is the thing being
## smoke-tested, not an accident of the binding.
##
## NO MODE KEY IS BOUND, deliberately. Only Mode ① resolves in E3; binding keys for the other
## three would author input for guarded stubs, so `card_mode` is always BASIC here and the mode
## half of the scheme arrives with the modes themselves in E5.
##
## _armed_slot is CONTROLLER-LOCAL state carried between ticks. That does not weaken the D3
## value-object contract above: sample() still returns a FRESH InputIntent every tick and never
## a reused mutable instance — what persists is this controller's private selection, not the
## intent.
var _cast_mode: StringName
var _cast_confirm: StringName
var _card_actions: Array[StringName] = []
var _armed_slot: int = -1


func _init(prefix: StringName) -> void:
	_up = _action(prefix, "move_up")
	_down = _action(prefix, "move_down")
	_left = _action(prefix, "move_left")
	_right = _action(prefix, "move_right")
	_debug_reset = _action(prefix, "debug_reset")
	for key in INTENT_ACTIONS:
		_action_map[key] = _action(prefix, key)
	_cast_mode = _action(prefix, "cast_mode")
	_cast_confirm = _action(prefix, "cast_confirm")
	for i in CARD_SLOTS:
		_card_actions.append(_action(prefix, "card_%d" % (i + 1)))


func sample() -> InputIntent:
	var intent := InputIntent.new()  # fresh per tick (never a reused mutable instance)
	intent.move_dir = Input.get_vector(_left, _right, _up, _down)
	for key in INTENT_ACTIONS:
		var mapped := _action_map[key]
		intent.pressed[key] = Input.is_action_just_pressed(mapped)
		intent.held[key] = Input.is_action_pressed(mapped)
	# Story 1-7 (D-2): the debug reset is an edge (just-pressed), prefix-mapped like every
	# action, carried on the intent rather than any out-of-band channel.
	intent.debug_reset = Input.is_action_just_pressed(_debug_reset)
	_sample_card_scheme(intent)
	return intent


## The card half of sample(), kept in its own function so the scheme is one readable block and
## swapping it is one edit. Writes only InputIntent's three card fields.
##
## RELEASING THE MODIFIER EXITS INSTANTLY — the selection is dropped the same tick, so the escape
## out of a cast into a roll costs no extra press. That is the operator's stated intent for the
## pad layout and it is honoured here on the keyboard.
##
## NO ACTION NAME CROSSES THE BOUNDARY: the Input Map action `pX_card_2` is resolved to the plain
## index 1 inside this loop, so the per-player prefix cannot leak into the intent (AC 11) — not
## by a strip step that could rot, but because no name is carried at all.
func _sample_card_scheme(intent: InputIntent) -> void:
	if not Input.is_action_pressed(_cast_mode):
		_armed_slot = -1
		return
	for i in _card_actions.size():
		if Input.is_action_just_pressed(_card_actions[i]):
			_armed_slot = i
	intent.card_slot = _armed_slot
	# Story 5-7 (AC 12): the keyboard scheme is back to ONE confirm key and ONE mode. `5-3`'s
	# `pX_cast_unblockable` and `5-5`'s `pX_cast_defense` branches are deleted -- both were declared
	# TEMPORARY by their own stories, both existed only so a human could reach modes ② and ③ before
	# a pad button could, and the pad's B and X now do that (`5-7` AC 1). BASIC is once again the
	# only mode this controller produces.
	intent.card_mode = Enums.ModeKind.BASIC
	# A commit with nothing armed still reaches state and is REFUSED there (empty_slot),
	# rather than being swallowed here: the refusal is player-facing feedback and belongs
	# on the shipped action_rejected seam, not in the controller.
	intent.card_commit = Input.is_action_just_pressed(_cast_confirm)


## Story 3-5a (AC 10): the armed slot, for the PRESENTATION-side selection indicator — read by
## the runner after sample() and pushed into the HUD. -1 = nothing armed. This is controller
## state, not match state: it never enters InputIntent's snapshot-excluded contract differently
## from the fields above, and the HUD receives a plain int, never this object.
func armed_slot() -> int:
	return _armed_slot


static func _action(prefix: StringName, name: String) -> StringName:
	return StringName("%s_%s" % [prefix, name])
