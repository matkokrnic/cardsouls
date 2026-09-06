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
const INTENT_ACTIONS: Array[StringName] = [&"attack", &"block", &"roll"]

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
##   PRESS pX_cast_unblockable commit the armed slot, mode UNBLOCKABLE (5-3, TEMPORARY: AC 19)
##   PRESS pX_cast_defense     commit the armed slot, mode DEFENSE (5-5, TEMPORARY: AC 15)
##   RELEASE pX_cast_mode      exit instantly and disarm
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
## Story 5-3 (AC 16): the SECOND confirm key, TEMPORARY per AC 19 -- `5-7` removes this field
## and its Input Map action along with the branch in `_sample_card_scheme` that reads it. The
## arm-then-confirm sequence itself is not this story's to touch and survives that removal.
var _cast_unblockable: StringName
## Story 5-5 (AC 15): the THIRD confirm key, TEMPORARY -- `5-7` deletes this field, its Input Map
## action (`p2_cast_defense`), its action-string line in `_init` and its branch in
## `_sample_card_scheme`: the exact four-part deletion inventory `5-3` named for
## `p1_cast_unblockable`, alongside which it goes. The arm-then-confirm sequence survives unchanged.
##
## P2-ONLY, and the mirror image of `_cast_unblockable`'s P1-only scoping rather than an
## inconsistency with it. `project.godot` gives P2 no `cast_unblockable`, so P2 can never INITIATE
## mode ②; P1 is therefore structurally the ATTACKER and P2 the DEFENDER for any smoke of this
## mechanic, whatever order `slot_controller_kinds` is in -- so only the DEFENDER side needs a key.
var _cast_defense: StringName
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
	_cast_unblockable = _action(prefix, "cast_unblockable")
	_cast_defense = _action(prefix, "cast_defense")
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
	# Story 5-3 (AC 16/17, `5-2/R15`): a SECOND confirm key on the SAME armed slot, sitting
	# BESIDE `_cast_confirm` rather than replacing it or skipping arming -- pressing it, with a
	# slot already armed exactly as today, commits that slot as UNBLOCKABLE IN PLACE OF
	# pressing `_cast_confirm` (which still commits as BASIC, unchanged). Without this arm, no
	# write anywhere in src/ ever set `card_mode` to anything but BASIC (`5-2/R15`), so
	# CHARGING was unreachable by a human at the keyboard. TEMPORARY (AC 19): `5-7` deletes
	# this branch and its Input Map action; the arm-then-confirm sequence survives unchanged.
	#
	# `InputMap.has_action` GUARDS THIS, because the Non-Goals scope this story's one new
	# Input Map action to P1 ONLY (the live-smoke human eye sits at P1) -- `p2_cast_unblockable`
	# is deliberately never authored, so a `p2`-prefixed instance of this same class (both
	# slots default to KEYBOARD_* in match_runner.gd) must silently skip the branch rather than
	# erroring on an action that does not exist, exactly the way `Input.is_action_just_pressed`
	# would otherwise throw for every P2 tick.
	# Story 5-5 (AC 15): a THIRD confirm key on the SAME armed slot, TEMPORARY, and checked ABOVE
	# `_cast_confirm` -- the three are MUTUALLY EXCLUSIVE, so a tick that presses `pX_cast_defense`
	# commits DEFENSE and never falls through to evaluate `cast_confirm`'s BASIC commit on the same
	# press. That is the one-commit-per-tick shape every other arm-then-confirm branch already has.
	#
	# `InputMap.has_action` GUARDS THIS for the P1-only mirror of `5-3/R17`'s own reason: only
	# `p2_cast_defense` is authored (AC 15's Non-Goals scoping), so a `p1`-prefixed instance of this
	# same class must silently SKIP the branch rather than erroring on an action that does not exist,
	# exactly as `Input.is_action_just_pressed` would otherwise throw on every P1 tick.
	# REVIEW FIX (LOW): this branch order puts DEFENSE above UNBLOCKABLE, but that precedence is
	# UNOBSERVABLE today -- no prefix carries both actions (P1 has `cast_unblockable`, P2 has
	# `cast_defense`, per AC 15's scoping), so a tick can never press both `_cast_defense` and
	# `_cast_unblockable` at once and this `if`/`elif` order is never actually exercised as a
	# choice. If `5-7`'s pad scoping ever gives ONE prefix both actions, a simultaneous press would
	# silently prefer DEFENSE, and that ordering becomes a real decision someone must make
	# deliberately rather than inherit from this incidental branch order.
	if InputMap.has_action(_cast_defense) and Input.is_action_just_pressed(_cast_defense):
		intent.card_mode = Enums.ModeKind.DEFENSE
		intent.card_commit = true
	elif InputMap.has_action(_cast_unblockable) \
			and Input.is_action_just_pressed(_cast_unblockable):
		intent.card_mode = Enums.ModeKind.UNBLOCKABLE
		intent.card_commit = true
	else:
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
