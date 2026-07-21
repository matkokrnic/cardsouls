class_name KeyboardController
extends Controller

## D3 keyboard controller. Takes a prefix ("p1" / "p2") so split-screen (E2) needs no remap
## and no second class — one class, two instances reading p1_* / p2_* Input Map actions.
##
## INVARIANT D3(a): this is one of the ONLY sites where Input.* may appear. State and actor
## code never touch the Input singleton (grep-checkable — matches only under src/controllers/).

var _up: StringName
var _down: StringName
var _left: StringName
var _right: StringName
var _actions: Array[StringName]  # discrete actions reported as pressed / held


func _init(prefix: StringName) -> void:
	_up = _action(prefix, "move_up")
	_down = _action(prefix, "move_down")
	_left = _action(prefix, "move_left")
	_right = _action(prefix, "move_right")
	_actions = [
		_action(prefix, "attack"),
		_action(prefix, "block"),
		_action(prefix, "roll"),
	]


func sample() -> InputIntent:
	var intent := InputIntent.new()  # fresh per tick (never a reused mutable instance)
	intent.move_dir = Input.get_vector(_left, _right, _up, _down)
	for action in _actions:
		intent.pressed[action] = Input.is_action_just_pressed(action)
		intent.held[action] = Input.is_action_pressed(action)
	return intent


static func _action(prefix: StringName, name: String) -> StringName:
	return StringName("%s_%s" % [prefix, name])
