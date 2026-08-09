class_name ReplayDrive
extends RefCounted

## Story 3-0d (`3-0d/R17`): THE REPLAY DRIVE ORDER, IN ONE PLACE.
##
## WHY THIS FILE EXISTS. Driving a record back through a fresh MatchState is an ORDERED sequence —
## seed, balance, flags, content, then per tick: recorded reload events, recorded camera bases,
## recorded contact facts, then advance() on the recorded intents. Get the order wrong and the
## replay diverges silently. Before this extraction that order was transcribed THREE times: the
## runner's own live fork (~~`match_runner.gd:601-608`~~ **RE-ANCHORED AT `3-0d/R25` BY LOCATING
## THE CONTENT: `match_runner.gd:629-633`** — the file grew 115 lines and the old citation now
## lands on the HUD card-selection push. This pointer is deliberately load-bearing, per `3-0d/R17`
## and `3-0d/R23` — it is the "somewhere to point" a change in the runner's order has — so it is
## re-anchored even though the standing carve-out does not require a wholesale sweep), AC 4's
## in-suite round-trip
## test (`test/state/test_record_file.gd`), and AC 8's headless verifier
## (`test/tools/replay_file.gd`). The review found the third guarded by NOTHING: AC 4's test proved
## the SAVE/LOAD path, never the verifier's ordering, so the verifier could have drifted from the
## runner and printed a stable-but-wrong hash forever.
##
## The two TEST-SIDE transcriptions are now ONE, used by both callers, so AC 4's round-trip test
## genuinely exercises the ordering the verifier runs. The runner's own fork stays where it is —
## it is `src/` code inside `_physics_process` and cannot call into `test/` (the state layer's own
## token scan and F1 both bear on it); it remains the ORIGINAL this file is transcribed from, and
## the comment above names it so a change there has somewhere to point.
##
## `3-0d/R23`: THE TRANSCRIPTION IS NOW ACTUALLY FAITHFUL. It had drifted in two places — both
## inert, both fixed rather than documented away. See `drive()`.
##
## WHY UNDER `test/` AND NOT `src/`. Its callers are a state test and a test-space operator tool,
## and it is the same reason `test/canonical_hash.gd` lives here: nothing in the shipped game
## replays a record from a file. It is not globbed by `run_all.sh` (which takes
## `test/integration/test_*.gd`) nor by the state harness (`test/state/test_*.gd`); it is a
## library, reached by `class_name`.

## Drives `record` through a fresh MatchState to completion.
##
## Returns `{"state": MatchState, "error": String}` — the same RESULT-DICTIONARY shape
## RecordFile.load_record uses, and for the same reason: the ONE thing that can legitimately go
## wrong here is a record whose content ORDER is unsound (`3-0c/R11` — a record must survive a
## round trip AS UNSOUND so replay can still refuse it), and each caller has a different right
## answer to that. A test asserts on the reason; the operator tool prints it and exits nonzero.
## Neither is weakened by sharing this: the refusal still stops the drive dead, it just travels as
## a value instead of as an Invariant.check the caller cannot phrase for itself.
##
## `3-0d/R23`: THE ORDER BELOW NOW MATCHES THE RUNNER'S STATEMENT FOR STATEMENT, which is what the
## docstring above always claimed. It did not, in two places, and both were inert — which is
## exactly why they could sit here unnoticed:
##   * THE CONTROLLERS were constructed LAST, after content injection; the runner builds them
##     FIRST, before it even has a MatchState (`match_runner.gd`, `_ready()`). A ReplayController
##     reads only the record, so where it is built could not matter — today.
##   * THE INTENTS were sampled AFTER the recorded pushes; the runner samples at the TOP of
##     `_physics_process`, before the `ticking` gate and so before the replay fork pushes anything.
##     `sample()` reads the record and not MatchState, so the two orders agree — today.
## Both were one behavioural change away from mattering, and "inert today" is not a property a
## transcription can rely on: the whole reason this helper exists (`3-0d/R17`) is that a drift from
## the runner prints a stable, wrong hash forever. The alternative — dropping the docstring's claim
## to be the runner's order and saying it is merely A replay order — was weighed and REJECTED:
## the claim is the value. Matching costs two moved statements and keeps it true.
static func drive(record: IntentRecorder) -> Dictionary:
	# The runner's `_ready()` order: controllers, then the seed, then the state, then balance
	# (reload event #0), then flags, then content.
	var p1_controller := ReplayController.new(record, 0)
	var p2_controller := ReplayController.new(record, 1)
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	if not record.replay_inject_content(ms):
		return {"state": null, "error": ("the recorded content order is unsound — the cast-cost "
				+ "and card-effect totality checks would be vacuous (`3-0c/R11`, `4-1/R8`)")}
	# The runner's `_physics_process` order: SAMPLE (step 1, above the `ticking` gate), then — in
	# the replay fork — recorded reloads, recorded bases, recorded facts, then advance, then drain.
	for tick in range(1, record.tick_count() + 1):
		var intents: Array[InputIntent] = [p1_controller.sample(), p2_controller.sample()]
		record.replay_apply_reloads_before(ms, tick)
		record.replay_push_camera_bases(ms, tick)
		record.replay_push_contacts(ms, tick)
		ms.advance(intents)
		ms.drain_signals()
	return {"state": ms, "error": ""}
