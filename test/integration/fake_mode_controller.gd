extends Controller

## Story 6-10 test double: a controller whose card mode / armed slot the test sets, and which counts
## the runner's force_card_mode_off() pushes. Used only by test_card_mode_lift.gd.

var mode_on := false
var armed := -1
var force_calls := 0
func force_card_mode_off() -> void:
	force_calls += 1
func card_mode_on() -> bool:
	return mode_on
func armed_slot() -> int:
	return armed
