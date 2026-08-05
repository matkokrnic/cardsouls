extends TestCase

## Story 3-0d: WHAT IS LEFT OF THIS FILE AFTER `3-0d/R20`, AND WHY THE REST IS GONE.
##
## This file shipped TWO SOURCE SCANS meant to make a mid-session "load into replay" control
## impossible: one asserting `replay_record` was assigned nowhere in `src/`, one enumerating the
## DebugInstrumentPanel's runner-reaching `Callable` members. BOTH ARE DELETED. Three successive
## reviews defeated them:
##
##   ROUND 1 — `set()`, `set_deferred()` and an indexed property write all reached `replay_record`
##     and were tallied as harmless READS; `var load_record := Callable()`, the idiomatic inferred
##     form, did not match the panel pattern at all.
##   ROUND 2 (after both were rewritten — a per-occurrence whitelist, a declaration-carrying-
##     Callable match) — `(replay_record) = null` was classified BY THE WHITELIST as an "argument
##     read": a literal assignment certified as a read. Six further panel declaration forms evaded
##     the Callable scan (`static var`, `@onready`, an inner-class member, a Callable in an untyped
##     Dictionary, one in an untyped Array, an untyped member invoked through a local copy). The
##     shared line reader truncated at the first `#` with NO string awareness, so a `#` inside a
##     string literal deleted the rest of the line from BOTH scans. And both read `.gd` only, while
##     GDScript embedded in a `.tscn` under `src/` is shipped, compiled, executing code.
##   A complete, working, wired LOAD control shipped past both, with the whole suite green.
##
## **THE RULING (`3-0d/R20`): A TEXT SCAN OVER SOURCE CANNOT CARRY A DESIGN INVARIANT.** Each round
## hardened the pattern and each round a form outside the pattern was found. The residue that is
## genuinely undecidable from source text is narrow — a name built at runtime, reflection over the
## property list — but the PRACTICAL residue kept being wide, because the classifier and its reader
## each kept having holes, and a guard that is believed to hold and does not is worse than no
## guard.
##
## THE PROPERTY IS MADE STRUCTURALLY IMPOSSIBLE INSTEAD OF DETECTABLE. `MatchRunner` now CONSUMES
## `replay_record` once, in `_ready()`, into a private `_replay_record`; the per-tick fork and every
## other consumer read only the private field. A mid-session assignment to the public member has NO
## EFFECT — not because it is caught, but because nothing reads what it changed. Its replacements,
## which are the mechanisms now:
##
##   * `test/integration/test_replay_entry_is_inert.gd` — assigns `replay_record` mid-match on a
##     LIVE runner and asserts the fork does not flip, recording continues, and ~~no recorded fact
##     reaches live state~~ **THE LIVE RELOAD TRIGGER STILL FIRES**. Its falsifying change is
##     obvious and real: restore the per-tick read of the public member and it goes red.
##     **THE STRUCK CLAUSE WAS FALSE OF THE SHIPPED TEST AND IS CORRECTED AT `3-0d/R25`.** That
##     test asserts nothing of the kind — its third assertion is that `reload_event_count()` goes
##     1 -> 2 after the assignment, i.e. that `trigger_live_balance_reload()` still fires, which
##     is how the OTHER consumer of the consumed record is reached. Verified by reading the
##     shipped assertions. `3-0d/R20`'s decision-log entry carries the same wrong sentence; it is
##     append-only, so the correction is recorded in the `3-0d/R25` entry rather than by editing
##     it. Related, same ruling: that test's fourth reading was VACUOUS and is DELETED — the
##     tripwire is ONE CHANNEL WIDE (the reload event), which its own docstring now states.
##   * `test/integration/test_record_save_control.gd` — the panel's control set, enumerated from
##     ACTUAL INSTANTIATED CONTROLS at runtime, so no declaration syntax can evade it.
##
## WHAT STAYS HERE, and why it is not the same kind of claim. AC 11 (a) pins the intent tap's SEAT
## — a statement's position relative to its neighbour inside one known function of one known file.
## That is a question about code layout, which is what source text is actually evidence of; it is
## not a claim that some behaviour is unreachable from anywhere in the tree. The residue is stated
## in the test's own docstring rather than left implied.

const RUNNER := "res://src/main/match_runner.gd"


# ---------------------------------------------------------------- AC 7

## AC 7: the SAVE control writes to a path the operator (and the AC 8 verifier) can NAME. The
## naming lives on RecordFile as a pure function of the save index, so the integration test and
## the smoke can both predict it rather than hunting the user:// directory.
func test_the_record_path_is_predictable_and_per_save() -> void:
	assert_true(RecordFile.path_for(1).begins_with("user://"),
		"records are written under user://, never into the project tree")
	assert_ne(RecordFile.path_for(1), RecordFile.path_for(2),
		"each save gets its own path, so a second SAVE does not overwrite the first")
	assert_true(RecordFile.path_for(2).contains("2"), "the index is visible in the path")


# ---------------------------------------------------------------- AC 11 (a)

## AC 11 (a): THE PASSIVE-TAP SEAT IS NOT RELOCATED. `capture_advance` is called exactly once in
## the runner and the very next statement is `_match_state.advance(` — one capture, one advance,
## always in that order.
##
## WHY A SCAN AND NOT A BEHAVIOURAL TEST: no test in the suite drives the runner's own tap (every
## capture_advance hit under test/ drives a recorder directly), so moving the runner's call to the
## SAMPLE step would break nothing while silently recording intents that no tick consumed — the
## desync `3-0c/R10` describes. This is the mechanism that makes that break loud.
##
## WHAT THIS SCAN DOES NOT CLAIM (`3-0d/R20`). It reads ONE file, takes the code portion of each
## line as everything before the first `#` — WITH NO STRING AWARENESS, so a `#` inside a string
## literal blanks the rest of that line — and matches on substrings. That is enough for what it
## asserts, which is where two statements sit relative to each other in a file a human is editing
## on purpose. It is NOT evidence about what the whole tree can or cannot reach, and it is not
## relied on for anything of that kind any more: `3-0d/R20` deleted the two scans that were.
func test_the_intent_tap_stays_seated_immediately_before_advance() -> void:
	var lines := _code_lines(RUNNER)
	assert_true(lines.size() > 50, "the runner source was actually read (got %d lines)" % lines.size())
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


# ---------------------------------------------------------------- scanning helpers

## The first non-blank code line after `index`.
func _next_statement(lines: Array[String], index: int) -> String:
	for i in range(index + 1, lines.size()):
		var stripped := lines[i].strip_edges()
		if stripped != "":
			return stripped
	return ""


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
# NOT string-aware — see the caller's docstring, which states that limit rather than hiding it.
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
