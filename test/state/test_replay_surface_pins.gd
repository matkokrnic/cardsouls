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
##
## ---------------------------------------------------------------------------------------------
## `3-0d/R14` — HOW THESE TWO SCANS WERE EVADED, AND THE RULE THAT CAME OUT OF IT.
##
## The review of this story broke BOTH pins without either going red. The `replay_record` scan
## matched `\breplay_record\s*=[^=]`, so `set("replay_record", rec)`,
## `set_deferred("replay_record", rec)` and `runner[&"replay_record"] = rec` all sailed through and
## were counted as READS. The panel scan matched `^var\s+\w+\s*:\s*Callable`, so
## `var load_record := Callable()` — the IDIOMATIC inferred form, the one a developer is most
## likely to type — did not match at all. A load control written in those shapes passed both pins.
##
## THE PERMANENT LESSON (`3-0d/R14`, decision log): **a pattern guard's non-vacuity check must be
## proven against THE FORMS AN ADVERSARY WOULD USE, not only the form the author happened to
## write.** The original mutation proofs for these two scans were performed in the author's own
## syntax — an annotated Callable, a bare `replay_record = ...` — so they proved that syntax and
## nothing else. A guard that enumerates the ways it can be broken is only ever as good as the
## imagination of whoever wrote the enumeration.
##
## WHAT CHANGED HERE, structurally, so this cannot recur by omission:
##   * The `replay_record` scan is INVERTED INTO A WHITELIST. Every occurrence of the token in
##     src/ must classify as one of an explicitly enumerated set of ALLOWED READ FORMS. Anything
##     else — including a form nobody has thought of yet — is an offender BY DEFAULT rather than
##     by enumeration.
##   * The panel scan matches a member declaration CARRYING `Callable` IN ANY FORM, plus any
##     member the file invokes as a Callable, rather than two hand-written patterns.
##   * Both self-checks now assert the EVASION FORMS ARE CAUGHT alongside the legitimate forms
##     being spared, and both were re-proven by mutation IN THE EVASION FORMS.

const PANEL := "res://src/ui/debug/debug_instrument_panel.gd"
const RUNNER := "res://src/main/match_runner.gd"

## AC 7 (amended `3-0d/R13`): the EXACT SET of runner-reaching members this panel may declare, and
## the EXACT SET of control handlers that may invoke them. Sorted — the scan below sorts its own
## findings before comparing, so member/handler ORDER carries no meaning, only membership.
const RUNNER_REACHING_MEMBERS: Array[String] = ["reload_balance", "save_record"]
const RUNNER_REACHING_HANDLERS: Array[String] = ["_on_reload_pressed", "_on_save_pressed"]

## AC 11 (b) / `3-0d/R14`: the token the whitelist scan below classifies, and the EXACT SET of
## READ FORMS that scan allows. Anything else — an assignment, a `set()`/`set_deferred()` call, an
## indexed property write, or a form nobody has thought of yet — is an offender BY DEFAULT. That
## inversion is the point: the old scan enumerated what was FORBIDDEN and was walked around by
## three shapes its author had not enumerated.
const REPLAY_RECORD := "replay_record"
const ALLOWED_FORMS: Array[String] = [
	"declaration", "null comparison", "member read", "argument read",
]


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

	# NON-VACUITY (`3-0d/R14`), PROVEN AGAINST THE FORMS AN ADVERSARY WOULD USE. The pattern this
	# replaces was `^var\s+\w+\s*:\s*Callable` — it matched the annotated form its author had
	# written and nothing else, so the review declared a load control's Callable as
	# `var load_record := Callable()` and walked straight past the pin. Each declaration form below
	# must now be CAUGHT.
	for evasion: Array in [
		["var load_record: Callable", "annotated, no initialiser"],
		["var load_record: Callable = Callable()", "annotated with an initialiser"],
		["var load_record := Callable()", "INFERRED — the form the review used to evade this pin"],
		["var load_record = Callable()", "untyped, initialised with a Callable"],
	]:
		var source: Array[String] = ["var save_record: Callable = Callable()", evasion[0]]
		var both: Array[String] = ["load_record", "save_record"]
		assert_eq(_runner_reaching_members(source), both,
			"a Callable member declared as `%s` is CAUGHT (%s)" % [evasion[0], evasion[1]])
	# ...including one whose DECLARATION carries no type at all and whose only tell is that the
	# file goes on to invoke it as a Callable — the form left over once the four above are closed.
	var late: Array[String] = [
		"var save_record: Callable = Callable()",
		"var load_record",
		"func _on_load_pressed() -> void:",
		"\tif load_record.is_valid():",
		"\t\tload_record.call()",
	]
	var late_want: Array[String] = ["load_record", "save_record"]
	assert_eq(_runner_reaching_members(late), late_want,
		"...and one declared untyped and INVOKED as a Callable later, which carries the word "
		+ "`Callable` on no line at all")
	# ...and the panel's own non-reaching members are SPARED: each is an object it was HANDED and
	# acts on directly, not a way to ask the runner for anything.
	var spared: Array[String] = [
		"var gamepad_profile: GamepadProfile",
		"var huds: Array[HudRoot] = []",
		"var _countdown_values: Array[Label] = []",
	]
	var none: Array[String] = []
	assert_eq(_runner_reaching_members(spared), none,
		"a held resource or node reference is NOT a runner-reaching control and must be spared")
	assert_eq(_declared_signals(["signal save_requested"]), ["save_requested"] as Array[String],
		"the signal pattern matches a signal declaration — the OTHER shape a control could use")

	var callables := _runner_reaching_members(lines)
	var signals := _declared_signals(lines)
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
## A WHITELIST, NOT A BLACKLIST (`3-0d/R14`). This scan used to look for the ONE shape an
## assignment takes — `replay_record` followed by a bare `=` — and the review reached the member
## three ways it had not enumerated: `set("replay_record", rec)`,
## `set_deferred("replay_record", rec)` and `runner[&"replay_record"] = rec`, ALL of which the old
## pattern counted as harmless READS. The scan is therefore inverted: EVERY occurrence of the token
## in src/ must classify as one of the four ALLOWED READ FORMS enumerated in `ALLOWED_FORMS`, and
## anything else — including a form nobody has thought of yet — is an offender, reported with its
## file, line and text. The allowed set is DERIVED from the shipped tree (every form in it is
## asserted to occur below), never a transcription of today's line count.
func test_replay_record_is_assigned_nowhere_in_src() -> void:
	# NON-VACUITY (`3-0d/R14`), PROVEN AGAINST THE FORMS AN ADVERSARY WOULD USE. The first is the
	# shape the original proof used; the next three are the review's evasions, every one of which
	# the OLD pattern let through as a read. All must be CAUGHT.
	for caught: Array in [
		["\t\treplay_record = RecordFile.load_record(path)[\"record\"]", "a bare in-file assignment"],
		["\tscene.replay_record = record", "an assignment through a held reference"],
		["\tself.replay_record = record", "...or through self"],
		["\trunner.set(\"replay_record\", rec)", "EVASION 1: set() by property NAME"],
		["\trunner.set_deferred(\"replay_record\", rec)", "EVASION 2: set_deferred()"],
		["\trunner[&\"replay_record\"] = rec", "EVASION 3: an indexed property write"],
		["\trunner[\"replay_record\"] = rec", "...and its plain-String twin"],
	]:
		assert_true(_occurrence_forms(caught[0]).has(""),
			"`%s` is CAUGHT (%s)" % [caught[0].strip_edges(), caught[1]])
	# ...and every form the SHIPPED runner actually uses is SPARED, and classified as what it is —
	# a mislabelled read is a whitelist entry nobody checked.
	var spared := {
		"var replay_record: IntentRecorder = null": "declaration",
		"\tvar replaying := replay_record != null": "null comparison",
		"\t\t\tif replay_record == null:": "null comparison",
		"\tvar seed_value := replay_record.replay_seed() if replaying else _SEED": "member read",
		"\t_p1_controller = ReplayController.new(replay_record, 0) if replaying \\": "argument read",
	}
	for line: String in spared:
		var want: Array[String] = [spared[line]]
		assert_eq(_occurrence_forms(line), want,
			"`%s` is SPARED, as a %s" % [line.strip_edges(), spared[line]])

	var declarations: Array[String] = []
	var offenders: Array[String] = []
	var seen_forms: Dictionary = {}
	var reads := 0
	var scanned := 0
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			for form in _occurrence_forms(line):
				if form == "":
					offenders.append("%s:%d  %s" % [path, n, line.strip_edges()])
					continue
				seen_forms[form] = true
				if form == "declaration":
					declarations.append("%s:%d" % [path, n])
				else:
					reads += 1
	assert_true(scanned > 10, "the src/ scan visited the tree (got %d files)" % scanned)
	assert_eq(offenders.size(), 0,
		"replay_record is REACHED in src/ by something that is not one of the allowed READ forms "
		+ "%s — a mid-session assignment, however it is spelled, injects recorded reloads, bases "
				% str(ALLOWED_FORMS)
		+ "and contacts into a live match and silently stops recording, because capture_advance "
		+ "sits in the branch the replay fork skips (`3-0d/R2`): %s" % "; ".join(offenders))
	assert_eq(declarations.size(), 1,
		"...and it is DECLARED exactly once, in the runner: %s" % ", ".join(declarations))
	assert_true(reads > 0,
		"the token must still be READ somewhere in src/, or this guard is scanning a name that no "
		+ "longer exists")
	# The whitelist is DERIVED from the tree it guards: every allowed form occurs in src/, so no
	# entry in it is an untested guess about code that does not exist.
	for form in ALLOWED_FORMS:
		assert_true(seen_forms.has(form),
			"the allowed form '%s' still occurs in src/ — an allowed form nothing uses is an "
					% form + "unchecked hole in the whitelist, not a spare")


# ---------------------------------------------------------------- scanning helpers

## AC 7 / `3-0d/R14`: THE PANEL'S RUNNER-REACHING MEMBERS, matched on the DECLARATION CARRYING
## `Callable` AT ALL rather than on a hand-written list of spellings. A member counts if either:
##   * its top-level `var` declaration mentions `Callable` anywhere — which covers the annotated
##     form (`: Callable`), the inferred form (`:= Callable(`), the untyped-but-initialised form
##     (`= Callable()`), and any combination of them; or
##   * the file INVOKES it as a Callable somewhere — which covers a member declared with no type
##     and assigned later, the one shape carrying the word `Callable` on no line at all.
## Local variables are excluded by construction: the declaration must sit at column 0.
func _runner_reaching_members(lines: Array[String]) -> Array[String]:
	var declaration_re := RegEx.create_from_string("^var\\s+([A-Za-z_][A-Za-z0-9_]*)\\b(.*)$")
	var carries_re := RegEx.create_from_string("\\bCallable\\b")
	var body := "\n".join(lines)
	var out: Array[String] = []
	for line in lines:
		var m := declaration_re.search(line)
		if m == null:
			continue
		var member := m.get_string(1)
		var invoked_re := RegEx.create_from_string(
			"\\b%s\\s*\\.\\s*(call|callv|bind|is_valid|call_deferred)\\s*\\(" % member)
		if carries_re.search(m.get_string(2)) != null or invoked_re.search(body) != null:
			out.append(member)
	out.sort()
	return out


## The OTHER shape a control could use to ask the runner for something (`3-0d/R2`): a signal the
## runner connects to. Banned outright, so the pin has one enumerable surface, not two.
func _declared_signals(lines: Array[String]) -> Array[String]:
	var re := RegEx.create_from_string("^signal\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var out: Array[String] = []
	for line in lines:
		var m := re.search(line)
		if m != null:
			out.append(m.get_string(1))
	return out


## AC 11 (b) / `3-0d/R14`: classify EVERY occurrence of `replay_record` in one code line. Returns
## one entry per occurrence — the name of the allowed READ form it matched, or "" for an
## occurrence that matched none, i.e. an OFFENDER. Occurrence-level rather than line-level, so a
## line that both reads and writes the member cannot hide the write behind the read.
func _occurrence_forms(line: String) -> Array[String]:
	var out: Array[String] = []
	var from := 0
	while true:
		var index := line.find(REPLAY_RECORD, from)
		if index == -1:
			return out
		out.append(_classify_occurrence(line, index))
		from = index + REPLAY_RECORD.length()
	return out


## The whitelist itself. `index` is where `replay_record` starts in `line`; the classification is
## made from the characters either side of it, so the FORMS are what is enumerated and everything
## else falls through to the offender return at the bottom BY DEFAULT.
func _classify_occurrence(line: String, index: int) -> String:
	var before := line.substr(0, index)
	var after := line.substr(index + REPLAY_RECORD.length())
	# INSIDE A STRING LITERAL: `set("replay_record", rec)`, `runner[&"replay_record"] = rec`. Not a
	# read of the member at all — it is the member's NAME handed to the property system, which is
	# exactly how the review reached it three times without ever writing an assignment to it.
	if before.ends_with("\"") or before.ends_with("'"):
		return ""
	# Part of a LONGER identifier. A different member, whose behaviour this pin knows nothing
	# about — so it is not silently skipped either.
	if before.length() > 0 and _is_word_char(before.substr(before.length() - 1)):
		return ""
	if after.length() > 0 and _is_word_char(after.substr(0, 1)):
		return ""
	if _matches("^\\s*(@export\\s+)?var\\s*$", before) and _matches("^\\s*[:=]", after):
		return "declaration"
	if _matches("^\\s*(==|!=)\\s*null\\b", after):
		return "null comparison"
	if _matches("^\\s*\\.\\s*[A-Za-z_]", after):
		return "member read"
	if _matches("^\\s*[,)]", after):
		return "argument read"
	return ""


func _matches(pattern: String, text: String) -> bool:
	return RegEx.create_from_string(pattern).search(text) != null


func _is_word_char(c: String) -> bool:
	return _matches("^[A-Za-z0-9_]$", c)


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
