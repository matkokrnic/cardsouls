class_name ReplayController
extends Controller

## Story 3-0c (X5): a D3 Controller that emits InputIntent from a RECORDED stream instead of
## from hardware — structurally indistinguishable from a keyboard or a pad to the runner, which
## is the whole point of the D3 seam ("state consumes it and never knows the source").
##
## ONE INSTANCE PER SLOT, exactly like KeyboardController: the record carries both slots' intents
## per tick and each controller reads its own column. The runner's slot wiring is unchanged.
##
## NO Input.* — deliberately, even though this file sits in the one folder where D3(a) would
## allow it. A replay that consulted live hardware would not be a replay.
##
## THE INTENT STREAM IS ALL THIS CARRIES. Contact facts do not originate in any controller
## (`3-0c/R1`): the runner computes them from Area3D overlaps and raw positions and InputIntent
## has no contact field, so a swapped-in controller CANNOT deliver them. Replay mode therefore
## also suppresses the runner's own gathering and drains recorded facts into push_contact — see
## match_runner.gd. This class is one half of replay, never the whole of it.

var _record: IntentRecorder
var _slot: int
## Ticks sampled so far. Private to this controller and advanced by sample() alone, so the two
## slots stay independent and neither reads the other's cursor.
var _cursor := 0


func _init(record: IntentRecorder, slot: int) -> void:
	Invariant.check(record != null, "a ReplayController needs a record to replay")
	Invariant.check(slot == 0 or slot == 1, "replay slot must be 0 or 1, got %d" % slot)
	_record = record
	_slot = slot


## A FRESH InputIntent per sample(), never the recorded instance (the E0 LIFETIME decision holds
## for a replay exactly as it does for hardware — see input_intent.gd). Past the end of the
## record the intent is a resting one, so a runner that outlives its record coasts to a halt
## rather than crashing.
func sample() -> InputIntent:
	_cursor += 1
	return _record.replay_intent(_cursor, _slot)


## Ticks this controller has sampled. The runner drives the recorded facts and bases from its own
## tick cursor; this is the controller-local mirror of it, exposed so a caller can tell a replay
## that has run out of record from one that has not.
func sampled_ticks() -> int:
	return _cursor
