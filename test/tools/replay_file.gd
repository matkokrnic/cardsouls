extends SceneTree

## Story 3-0d (AC 8, `3-0d/R3`): THE HEADLESS RECORD VERIFIER — load a record from `user://`,
## replay it to completion, print its CanonicalHash.
##
## Run:
##   godot --headless --path . --script res://test/tools/replay_file.gd -- <path>
##
## where <path> is a `user://...` path (or an absolute one) — typically a file the SAVE control
## wrote while you were playing. Run it TWICE on the same file: the hash must be identical, which
## is the payoff step of this story's Live Smoke.
##
## WHY IT LIVES UNDER `test/` RATHER THAN `src/`. CanonicalHash is `test/canonical_hash.gd`, a
## test-harness class; NOTHING under src/ computes or displays a canonical hash and this story
## does not change that (`3-0d/R4` — the only two `CanonicalHash` occurrences in src/ are prose in
## comments). Living in test space is what legitimately gives this tool the hash, and it is why
## the smoke's payoff is performed OUTSIDE the game.
##
## WHY IT IS NOT AUTO-RUN. `test/run_all.sh` globs `test/integration/test_*.gd`; this file is
## neither in that directory nor named `test_*`, deliberately: its INPUT is a file an operator
## produced by playing, which no unattended suite can conjure. Its regression cover is AC 4's
## in-suite round-trip test (test/state/test_record_file.gd), which proves the same save/load path
## on a fixture the suite can build for itself.
##
## THE FORM is the repo's own working pattern for a standalone script: `extends SceneTree` with an
## `_initialize()` entry point, the shape every file under test/integration/ uses and the shape
## run_all.sh invokes them in.
##
## Exit codes: 0 replayed, 1 refused or malformed, 2 no path given.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: godot --headless --path . --script res://test/tools/replay_file.gd -- <record path>")
		quit(2)
		return
	var path := args[0]
	print("record: %s" % path)

	var result := RecordFile.load_record(path)
	if result["record"] == null:
		print("REFUSED: %s" % result["error"])
		print("RESULT: FAIL")
		quit(1)
		return
	var record: IntentRecorder = result["record"]

	# STRUCTURAL COMPLETENESS, reported before anything is replayed: a record missing a match-start
	# channel is a recording defect, and saying which channel is missing is more use than a stack
	# trace from the first tick that needed it.
	if not record.has_complete_match_start():
		print("MALFORMED: missing %s" % ", ".join(record.missing_match_start_channels()))
		print("RESULT: FAIL")
		quit(1)
		return
	print("format version %d accepted" % RecordFile.FORMAT_VERSION)
	print("ticks=%d  reload_events=%d  seed=%d  deck=%d cards  costs=%d  order=%s" % [
		record.tick_count(), record.reload_event_count(), record.replay_seed(),
		record.replay_deck_contents().size(), record.replay_card_costs().size(),
		str(record.content_order())])
	print("camera_pushes=%d  contact_facts=%d" % [_camera_pushes(record), _contact_facts(record)])
	if record.tick_count() == 0:
		print("MALFORMED: the record carries no ticks — there is nothing to replay")
		print("RESULT: FAIL")
		quit(1)
		return

	var replayed := _replay(record)
	print("replayed %d ticks to completion" % record.tick_count())
	print("CanonicalHash: %s" % CanonicalHash.of(replayed.to_snapshot()))
	print("RESULT: PASS")
	quit(0)


## THE REPLAY, in the runner's own order (match_runner.gd:536-568): recorded reload events, then
## the recorded camera bases, then the recorded contact facts, then advance() on the recorded
## intents read through the shipped ReplayController — one instance per slot, exactly as the
## runner builds them. No live service, no CardDatabase, no hardware: everything comes from the
## record, which is the whole claim a replay makes.
func _replay(record: IntentRecorder) -> MatchState:
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	Invariant.check(record.replay_inject_content(ms),
		"recorded content order is unsound — the cast-cost totality check would be vacuous")
	var p1_controller := ReplayController.new(record, 0)
	var p2_controller := ReplayController.new(record, 1)
	for tick in range(1, record.tick_count() + 1):
		record.replay_apply_reloads_before(ms, tick)
		record.replay_push_camera_bases(ms, tick)
		record.replay_push_contacts(ms, tick)
		var intents: Array[InputIntent] = [p1_controller.sample(), p2_controller.sample()]
		ms.advance(intents)
		ms.drain_signals()
	return ms


func _camera_pushes(record: IntentRecorder) -> int:
	var total := 0
	for tick in range(1, record.tick_count() + 1):
		total += record.camera_pushes_at(tick).size()
	return total


func _contact_facts(record: IntentRecorder) -> int:
	var total := 0
	for tick in range(1, record.tick_count() + 1):
		total += record.contacts_at(tick).size()
	return total
