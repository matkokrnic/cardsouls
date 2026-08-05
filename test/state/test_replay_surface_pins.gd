extends TestCase

## Story 3-0d (AC 7 structural / AC 11): THE TWO STRUCTURAL PINS THIS STORY'S SCOPE RESTS ON.
##
## Both exist because "the dev pass promised not to" is not a mechanism (`3-0d/R6`). Each ruling
## this story leaves in the CODE rather than in prose gets a scan that goes RED when the property
## breaks:
##
##   AC 7 (AMENDED `3-0d/R13`) — the DebugInstrumentPanel has EXACTLY the SET of two
##     runner-reaching controls {SAVE, RELOAD}, no more and no fewer. The readiness gate's original
##     "exactly one" pin was never protecting a COUNT — it was protecting against a LOAD control
##     (`3-0d/R2`): assigning `replay_record` mid-session injects tick-1 recorded reloads, bases and
##     facts into a live match and silently stops recording, because capture_advance lives in the
##     `else` branch the replay fork then skips. A live reload trigger needs an operator surface for
##     the story to land at all (`3-0d/R13`), so the pin is reformulated from a COUNT into an EXACT
##     SET — the same shape this repo already uses for the Input Map pin. A third control — a load
##     control in particular — still fails here.
##   AC 11 — the passive-tap SEAT is not relocated (capture_advance sits immediately before
##     advance(), inside the ticking gate), and `replay_record` is ASSIGNED NOWHERE in src/. THIS,
##     NOT AC 7's control count, IS WHAT ACTUALLY KEEPS A LOAD CONTROL OUT (`3-0d/R13`): AC 7 pins
##     the panel's SHAPE, but a load control's defining property is that it assigns `replay_record`,
##     and that is what AC 11's second scan forbids, structurally, regardless of how many buttons
##     the panel carries. That is the single structural trace the rejected load control leaves in
##     the code.
##
## Both scans read the code portion of each line only, so a comment naming a banned form can
## neither trip nor satisfy them, and both carry their own non-vacuity checks: the patterns are
## proven against the exact strings they exist to catch.

const PANEL := "res://src/ui/debug/debug_instrument_panel.gd"
const RUNNER := "res://src/main/match_runner.gd"

## AC 7 (amended `3-0d/R13`): the EXACT SET of runner-reaching members this panel may declare, and
## the EXACT SET of control handlers that may invoke them. Sorted — the scan below sorts its own
## findings before comparing, so member/handler ORDER carries no meaning, only membership.
const RUNNER_REACHING_MEMBERS: Array[String] = ["reload_balance", "save_record"]
const RUNNER_REACHING_HANDLERS: Array[String] = ["_on_reload_pressed", "_on_save_pressed"]


# ---------------------------------------------------------------- AC 7

## AC 7 (amended `3-0d/R13`): THE EXACT SET OF TWO RUNNER-REACHING CONTROLS. "Runner-reaching" is
## pinned by construction rather than by intent: the Dev Notes name the only two shapes this file
## could use to ask the runner for anything — a runner-owned Callable handed over at construction,
## or a signal the runner connects to — so this asserts the panel declares EXACTLY the two expected
## Callable members, NO signal at all, and that EXACTLY the two expected control handlers invoke
## them.
##
## A LOAD CONTROL FAILS HERE just as it did under the old count: it needs its own Callable (a
## THIRD member, breaking the exact-set equality), or a signal (banned outright), or it must reuse
## `save_record`/`reload_balance` — in which case it saves or re-triggers a reload rather than
## loading. The two existing switches stay uncounted because they self-contain their effect: they
## mutate the resource / HudRoots they were handed and reach nothing.
func test_the_panel_has_exactly_the_two_runner_reaching_controls() -> void:
	var lines := _code_lines(PANEL)
	assert_true(lines.size() > 50, "the panel source was actually read (got %d lines)" % lines.size())
	var callables: Array[String] = []
	var signals: Array[String] = []
	var callable_re := RegEx.create_from_string("^var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*Callable")
	var signal_re := RegEx.create_from_string("^signal\\s+([A-Za-z_][A-Za-z0-9_]*)")
	# NON-VACUITY: both patterns must match the exact forms they exist to catch.
	assert_true(callable_re.search("var save_record: Callable = Callable()") != null,
		"the Callable pattern matches a Callable member declaration")
	assert_true(signal_re.search("signal save_requested") != null,
		"the signal pattern matches a signal declaration")
	for line in lines:
		var c := callable_re.search(line)
		if c != null:
			callables.append(c.get_string(1))
		var s := signal_re.search(line)
		if s != null:
			signals.append(s.get_string(1))
	callables.sort()
	assert_eq(callables, RUNNER_REACHING_MEMBERS,
		"the panel declares EXACTLY the two runner-reaching Callables — SAVE and RELOAD — and "
		+ "nothing else; a third (a load control in particular) is what AC 7 refuses: %s"
				% ", ".join(callables))
	assert_eq(signals, [],
		"...and no signal either: the other shape a control could use to ask the runner for "
		+ "something (`3-0d/R2`): %s" % ", ".join(signals))

	var handlers := _wired_control_handlers(lines)
	assert_true(handlers.size() >= 4,
		"the scan must find the panel's wired controls — two switches plus SAVE plus RELOAD "
		+ "(got %d)" % handlers.size())
	var reaching: Array[String] = []
	for name: String in handlers:
		var body := _function_body(lines, name)
		if body.contains(RUNNER_REACHING_MEMBERS[0]) or body.contains(RUNNER_REACHING_MEMBERS[1]):
			reaching.append(name)
	reaching.sort()
	assert_eq(reaching, RUNNER_REACHING_HANDLERS,
		"EXACTLY the two control handlers reach the runner — SAVE and RELOAD. A start control or a "
		+ "third runner-reaching control lands here as a third: %s" % ", ".join(reaching))
	# ...and both handlers really are wired to a control, not merely declared.
	for handler_name in RUNNER_REACHING_HANDLERS:
		assert_true(handlers.has(handler_name),
			"%s is CONNECTED to a control's signal — a handler nothing invokes is not a control"
					% handler_name)


## AC 7: the SAVE control writes to a path the operator (and the AC 8 verifier) can NAME. The
## naming lives on RecordFile as a pure function of the save index, so the integration test and
## the smoke can both predict it rather than hunting the user:// directory.
func test_the_record_path_is_predictable_and_per_save() -> void:
	assert_true(RecordFile.path_for(1).begins_with("user://"),
		"records are written under user://, never into the project tree")
	assert_ne(RecordFile.path_for(1), RecordFile.path_for(2),
		"each save gets its own path, so a second SAVE does not overwrite the first")
	assert_true(RecordFile.path_for(2).contains("2"), "the index is visible in the path")


# ---------------------------------------------------------------- AC 11

## AC 11 (a): THE PASSIVE-TAP SEAT IS NOT RELOCATED. `capture_advance` is called exactly once in
## the runner and the very next statement is `_match_state.advance(` — one capture, one advance,
## always in that order.
##
## WHY A SCAN AND NOT A BEHAVIOURAL TEST: no test in the suite drives the runner's own tap (every
## capture_advance hit under test/ drives a recorder directly), so moving the runner's call to the
## SAMPLE step would break nothing while silently recording intents that no tick consumed — the
## desync `3-0c/R10` describes. This is the mechanism that makes that break loud.
func test_the_intent_tap_stays_seated_immediately_before_advance() -> void:
	var lines := _code_lines(RUNNER)
	var tap := -1
	var taps := 0
	for i in lines.size():
		if lines[i].contains("capture_advance("):
			tap = i
			taps += 1
	assert_eq(taps, 1,
		"the runner taps the intent stream in EXACTLY ONE place — a second tap would record ticks "
		+ "twice, and none would record nothing")
	var next := _next_statement(lines, tap)
	assert_true(next.contains("_match_state.advance("),
		"the statement immediately after capture_advance must be _match_state.advance( — the tap "
		+ "is seated at the ADVANCE, not at the sample step (`3-0c/R10`). Found: %s" % next)
	# ...and the seat is inside the ticking gate, not above it: a tap outside the gate would record
	# frames the debug pause never advanced.
	var gate := -1
	for i in lines.size():
		if lines[i].strip_edges() == "if ticking:":
			gate = i
	assert_true(gate != -1, "the ticking gate is still a plain `if ticking:` in the runner")
	assert_true(tap > gate,
		"the tap sits INSIDE the ticking gate (line %d > %d) — 3-0b's pause samples every frame "
				% [tap, gate] + "but advances only on ticking ones")


## AC 11 (b): `replay_record` IS ASSIGNED NOWHERE IN src/. Its one assignment in the whole tree is
## external and pre-tree (test/integration/test_replay_contacts.gd:80), which is what makes replay
## a mode chosen BEFORE the node enters the tree rather than a switch flipped mid-match.
##
## THE MEASUREMENT THIS PINS (taken at the readiness gate and re-taken here): the token appears in
## src/ only as its declaration and as READS. A mid-session `replay_record = ...` — the naive
## "load" control — fails here, which is the single structural trace of the control `3-0d/R2`
## rejected.
func test_replay_record_is_assigned_nowhere_in_src() -> void:
	var declaration_re := RegEx.create_from_string("^\\s*(@export\\s+)?var\\s+replay_record\\b")
	# An assignment is `replay_record` followed by a bare `=` — never `==`, `!=`, `>=`, `<=`.
	var assignment_re := RegEx.create_from_string("\\breplay_record\\s*=[^=]")
	# NON-VACUITY: the patterns must catch what they exist to catch and spare what they must spare.
	assert_true(assignment_re.search("\tscene.replay_record = record") != null,
		"the assignment pattern catches the form the rejected load control would use")
	assert_true(assignment_re.search("\t\treplay_record = load_from_disk()") != null,
		"...including a bare in-file assignment")
	assert_null(assignment_re.search("\tvar replaying := replay_record != null"),
		"a COMPARISON is not an assignment and must not be counted")
	assert_null(assignment_re.search("\t\t\tif replay_record == null:"), "...nor an equality test")
	assert_true(declaration_re.search("var replay_record: IntentRecorder = null") != null,
		"the declaration pattern matches the shipped declaration")

	var declarations: Array[String] = []
	var offenders: Array[String] = []
	var reads := 0
	var scanned := 0
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if not line.contains("replay_record"):
				continue
			if declaration_re.search(line) != null:
				declarations.append("%s:%d" % [path, n])
				continue
			if assignment_re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
			else:
				reads += 1
	assert_true(scanned > 10, "the src/ scan visited the tree (got %d files)" % scanned)
	assert_eq(offenders.size(), 0,
		"replay_record is ASSIGNED in src/ — a mid-session assignment injects recorded reloads, "
		+ "bases and contacts into a live match and silently stops recording, because "
		+ "capture_advance sits in the branch the replay fork skips (`3-0d/R2`): %s"
				% ", ".join(offenders))
	assert_eq(declarations.size(), 1,
		"...and it is DECLARED exactly once, in the runner: %s" % ", ".join(declarations))
	assert_true(reads > 0,
		"the token must still be READ somewhere in src/, or this guard is scanning a name that no "
		+ "longer exists")


# ---------------------------------------------------------------- scanning helpers

## Handler names wired to a control's signal in this file — `x.pressed.connect(_on_y)` /
## `x.toggled.connect(_on_y)`. Returns a name -> true set.
func _wired_control_handlers(lines: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.create_from_string("\\.(pressed|toggled)\\.connect\\(([A-Za-z_][A-Za-z0-9_]*)\\)")
	# NON-VACUITY: the pattern must match both wiring forms this file uses.
	assert_true(re.search("\tsave.pressed.connect(_on_save_pressed)") != null,
		"the wiring pattern matches a Button press connection")
	assert_true(re.search("\tpitch.toggled.connect(_on_pitch_placement_toggled)") != null,
		"...and a CheckButton toggle connection")
	for line in lines:
		var m := re.search(line)
		if m != null:
			out[m.get_string(2)] = true
	return out


## The code body of `func <name>`, up to the next top-level function.
func _function_body(lines: Array[String], name: String) -> String:
	var body: Array[String] = []
	var inside := false
	var re := RegEx.create_from_string("^(static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")
	for line in lines:
		var m := re.search(line)
		if m != null:
			if inside:
				break
			inside = m.get_string(2) == name
			continue
		if inside:
			body.append(line)
	return "\n".join(body)


## The first non-blank code line after `index`.
func _next_statement(lines: Array[String], index: int) -> String:
	for i in range(index + 1, lines.size()):
		var stripped := lines[i].strip_edges()
		if stripped != "":
			return stripped
	return ""


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root + d + "/"))
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out
