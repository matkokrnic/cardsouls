extends TestCase

## Executable guards for the load-bearing architectural invariants (F1, D3a, D3b, F2). These
## carry the same weight as the decisions themselves — scanning src/ here regression-tests
## them in CI, not just by hand. Comments are stripped (cut at first '#') so explanatory
## prose mentioning a banned token never false-positives. (This file lives under test/, not
## src/, so it is never itself scanned.)

func test_single_physics_process_owner() -> void:  # INVARIANT F1
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if line.contains("func _physics_process"):
				if not path.ends_with("src/main/match_runner.gd"):
					offenders.append("%s:%d" % [path, n])
	assert_eq(offenders.size(), 0,
		"func _physics_process only allowed in match_runner: %s" % ", ".join(offenders))


func test_input_only_in_controllers() -> void:  # INVARIANT D3(a)
	var re := RegEx.create_from_string("(^|[^.\\w])Input\\s*\\.")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		if path.contains("/controllers/"):
			continue
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0, "Input.* outside src/controllers/: %s" % ", ".join(offenders))


func test_state_layer_has_no_nondeterministic_source() -> void:  # INVARIANT D3(b) / A2
	var rng := RegEx.create_from_string("(^|[^.\\w])(randf|randi|randf_range|randi_range|randfn|randomize)\\s*\\(")
	var svc := RegEx.create_from_string("(^|[^.\\w])(Time|OS|Engine)\\.")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if rng.search(line) != null or svc.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"nondeterministic source in src/state/ (global RNG / Time / OS / Engine): %s" % ", ".join(offenders))


## Story 3-0b (AC6) / DECISION A + the in-place rule. The attack lunge is a state-side
## velocity term; the explicitly REJECTED alternative is root-motion extraction, which would
## make replay depend on animation sampling and put presentation in charge of position. That
## rejection is now machine-checked rather than trusted: src/state/ may never name a
## root-motion API. Scanning src/state/ (not all of src/) is the load-bearing scope — it is
## the layer whose determinism the ban protects. Comments are stripped by _code_lines, so the
## prose above and the AC6 rationale in match_state.gd never false-positive.
func test_state_layer_never_extracts_root_motion() -> void:
	var re := RegEx.create_from_string("(root_motion|RootMotion|AnimationPlayer|AnimationMixer)")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"root-motion extraction in src/state/ (AC6: the lunge is a state velocity term): %s"
				% ", ".join(offenders))


## Story 3-2 (AC 5): CARD DATA NEVER REACHES THE STATE LAYER. Cards are a growing content
## library loaded by the CardDatabase autoload from data/cards/; the hashed determinism run
## must stay independent of them, or adding a card would re-baseline the golden and defeat the
## "new card = a .tres, no code" promise this epic exists to deliver. (Deliberate ASYMMETRY
## with data/economy/, whose rule content IS load-bearing for the hash — 3-4/R6.) If a later
## story needs card data inside the tick loop it arrives by INJECTION, exactly as BalanceConfig
## and FeatureFlags do. Scanning src/state/ (not all of src/) is the load-bearing scope, and
## comments are stripped by _code_lines so the prose above never false-positives.
func test_state_layer_never_names_card_data() -> void:
	var re := RegEx.create_from_string("(CARDS_DIR|data/cards)")
	# NON-VACUITY, two ways. (a) The banned tokens must be REAL: card_database.gd names both,
	# so a rename there that silently empties this guard fails HERE instead of passing quietly
	# — the same "a rename must not un-guard the layer" mechanism as the hud_root_found and
	# controller_found assertions above. (b) The scan must actually visit files.
	var db_hits := 0
	for line in _code_lines("res://src/systems/card_database.gd"):
		if re.search(line) != null:
			db_hits += 1
	assert_true(db_hits > 0,
		"card_database.gd must still name CARDS_DIR / data/cards — otherwise this guard is vacuous")
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/state/ scan found no .gd files (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"card data named in src/state/ (AC5: cards reach state by injection only, never by path): %s"
				% ", ".join(offenders))


## Story 3-3 (AC 8): TWO bans in one scan, both about reaches the pure state layer must never
## make. Scanning src/state/ (not all of src/) is the load-bearing scope, as in the two guards
## above, and comments are stripped by _code_lines so this prose never false-positives.
##
## (1) IMPLICIT-GLOBAL-RNG COLLECTION APIs. Array.shuffle() was MEASURED on this engine (4.6.3)
## drawing from the GLOBAL RNG and leaving a per-instance RandomNumberGenerator untouched — and
## test_state_layer_has_no_nondeterministic_source above does NOT catch it, because that guard
## bans the bare randf/randi family BY NAME and these are method calls on a collection. So a
## `deck.shuffle()` under src/state/ passes the entire suite today while silently destroying
## replay. That measurement is why AC 7 specifies an explicit Fisher-Yates against the injected
## generator instead of the one-liner, and why this guard exists at all. `pick_random(` is the
## same hole with a different name; bare `seed(` is it from the other end — reseeding the
## global generator from state. Instance calls (`rng.randi_range(...)`) are the SANCTIONED
## form and are deliberately NOT matched.
##
## (2) THE CardDatabase TOKEN. Card content reaches src/state/ ONLY by injection (AC 2). The
## sibling guard below bans the PATH (CARDS_DIR / data/cards); this bans the AUTOLOAD, which is
## the other way the layer could reach the card library — and the way that became reachable the
## moment this story gave the runner a real reason to read it.
func test_state_layer_never_uses_implicit_global_rng_or_card_database() -> void:
	var re := RegEx.create_from_string(
		"(\\.shuffle\\s*\\(|\\.pick_random\\s*\\(|(^|[^.\\w])seed\\s*\\(|CardDatabase)")
	# NON-VACUITY (a), first way — the banned token must be REAL somewhere: match_runner.gd is
	# the ONLY production reader of the autoload (AC 2), so a rename there that silently empties
	# half this guard fails HERE, the same mechanism as the CARDS_DIR assertion below.
	var runner_hits := 0
	for line in _code_lines("res://src/main/match_runner.gd"):
		if line.contains("CardDatabase"):
			runner_hits += 1
	assert_true(runner_hits > 0,
		"match_runner.gd must still name CardDatabase — otherwise half this guard is vacuous")
	# The RNG half has no legitimate use anywhere in src/ to point at, so the PATTERN itself is
	# proven against the exact strings it exists to catch — a regex typo that silently disarms
	# the ban fails here instead of passing quietly — and against the form it must NOT catch.
	for banned in ["\tdeck.shuffle()", "\tvar c = _cards.pick_random()", "\tseed(1337)"]:
		assert_true(re.search(banned) != null, "the AC8 pattern must match `%s`" % banned.strip_edges())
	assert_null(re.search("\tvar j := rng.randi_range(0, i)"),
		"an INSTANCE-generator draw is the sanctioned form and must not trip this guard")
	# NON-VACUITY (b), second way: the scan must actually visit files.
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/state/ scan found no .gd files (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"implicit-global-RNG API or CardDatabase named in src/state/ (AC8: the seeded generator "
		+ "is passed IN, card content arrives by injection): %s" % ", ".join(offenders))


## Story 3-5b (AC 16, `3-5b/R17` corrected by `3-5b/R18`): INVARIANT F2, MACHINE-CHECKED FOR THE
## FIRST TIME. F2 — "the seeded RNG is consumed only inside advance()" — has been cited as a
## contract by 3-3, 3-5a and 3-5b and was REVIEW-ENFORCED ONLY: the D3(b)/A2 guard above bans the
## bare randf/randi family inside src/state/, and the sibling below bans the implicit-global-RNG
## collection APIs, but NEITHER covers a SECOND SEEDED SEAT. Nothing in the suite would have
## failed if `_rng` had grown a second consumer, which is exactly the mistake a lazy reshuffle
## makes easy to reach for. 3-5b is the first story that could introduce one, so it is F2's
## forcing point.
##
## THE COUNT IS THE POST-LANDING COUNT, AND THAT IS THE AC. Measured at 3-5b's gate, src/ already
## held exactly two `shuffle_with_rng(` occurrences — but for a DIFFERENT reason (one shuffle
## occasion, one call site), so a green run before the work started proved nothing. What this pins
## is that the count is STILL two once a SECOND shuffle occasion exists, which is only achievable
## through the shared MatchState helper both occasions route through: the match-start/debug-reset
## deal and the lazy reshuffle. Pinning two WITHOUT that helper would have failed on this story's
## own landing — the self-contradiction `3-5b/R18` corrects.
##
## THE PROOF RUNS FALLING: a second call site anywhere under src/ must make this FAIL. A guard
## that only confirms today's count is one refactor away from being vacuous.
const SEEDED_SHUFFLE_DEFINITION := "res://src/state/deck.gd"
const SEEDED_SHUFFLE_CALLER := "res://src/state/match_state.gd"


func test_exactly_one_seeded_shuffle_call_site() -> void:  # INVARIANT F2
	var re := RegEx.create_from_string("shuffle_with_rng\\s*\\(")
	# The pattern must match both forms it counts — a regex typo must not silently disarm this.
	assert_true(re.search("func shuffle_with_rng(rng: RandomNumberGenerator) -> void:") != null,
		"the pattern must match the DEFINITION")
	assert_true(re.search("\tdeck.shuffle_with_rng(_rng)") != null,
		"the pattern must match a CALL")
	var scanned := 0
	var sites: Array[String] = []
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				sites.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/ scan found no .gd files (guard would be vacuous)")
	assert_eq(sites.size(), 2,
		"F2: `shuffle_with_rng(` must appear in EXACTLY TWO places in src/ — its definition in "
		+ "deck.gd and the ONE private MatchState helper both shuffle occasions route through. "
		+ "A third occurrence is a SECOND SEEDED SEAT, which is a design change and the "
		+ "operator's call, not a refactor: %s" % ", ".join(sites))
	# Naming the two files is what makes the COUNT mean "definition plus one caller" rather than
	# "any two lines anywhere" — two calls and a moved definition would otherwise still pass.
	var definitions := 0
	var callers := 0
	for site in sites:
		if site.begins_with(SEEDED_SHUFFLE_DEFINITION):
			definitions += 1
		elif site.begins_with(SEEDED_SHUFFLE_CALLER):
			callers += 1
	assert_eq(definitions, 1, "one of the two is deck.gd's definition")
	assert_eq(callers, 1, "...and the other is match_state.gd's single private helper")


## Story 3-0c (AC 12, `3-0c/R9`): THE X5 RECORDER AND ITS REPLAY CONTROLLER LIVE OUTSIDE
## src/state/, and the state layer may not so much as NAME them. This joins the whole-directory
## src/state/ scans above as the fifth, and it is a scan rather than a citation of the
## architecture doc's directory tree deliberately — `3-0c/R10` rules that tree PRE-CODE TEXT.
##
## THE ARGUMENT'S LIMIT, stated so it is not overclaimed: a deliberately clock-free,
## content-blind, in-memory recorder placed under src/state/ would trip NONE of the four scans
## above (it names no Time/OS/Engine, no CARDS_DIR, no CardDatabase, no bare seed()). That is
## precisely why this scan ships instead of resting on those.
const RECORDER_PATH := "res://src/systems/intent_recorder.gd"
const REPLAY_CONTROLLER_PATH := "res://src/controllers/replay_controller.gd"


func test_state_layer_never_names_the_recorder_or_the_replay_controller() -> void:
	# NON-VACUITY (a): both files must be REAL and must live where AC 12 places them — a MOVE into
	# src/state/ (or a rename) would otherwise silently empty this guard instead of failing it.
	assert_true(FileAccess.file_exists(RECORDER_PATH),
		"the recorder must live at %s (runner-owned, src/systems/)" % RECORDER_PATH)
	assert_true(FileAccess.file_exists(REPLAY_CONTROLLER_PATH),
		"the replay controller must live at %s (a Controller, src/controllers/)" % REPLAY_CONTROLLER_PATH)
	for path in _gd_files("res://src/state/"):
		assert_false(path.ends_with("/intent_recorder.gd"),
			"the recorder must not live under src/state/: %s" % path)
		assert_false(path.ends_with("/replay_controller.gd"),
			"the replay controller must not live under src/state/: %s" % path)
	# NON-VACUITY (b): the banned tokens must be real somewhere, so a class rename that empties
	# this ban fails HERE — the CARDS_DIR / CardDatabase mechanism above.
	var runner_hits := 0
	for line in _code_lines("res://src/main/match_runner.gd"):
		if line.contains("IntentRecorder") or line.contains("ReplayController"):
			runner_hits += 1
	assert_true(runner_hits > 0,
		"match_runner.gd must still name both classes — otherwise this guard is vacuous")
	var re := RegEx.create_from_string("(IntentRecorder|ReplayController)")
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/state/ scan found no .gd files (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"the recorder / replay controller named in src/state/ (AC 12: the record is the RUNNER's; "
		+ "the state layer is recorded, it does not record): %s" % ", ".join(offenders))


## Story 3-0c (AC 13): THE SEVEN-SEAM FAMILY, MACHINE-CHECKED FOR THE FIRST TIME. `2-6/R7` froze
## the runner's per-slot observation seams at SEVEN and eleven stories have honoured it BY REVIEW
## ONLY — verified by content at this story's gate: `connect_` appears in test/ solely as USAGE
## (test_contact_pipeline.gd, test_live_attack.gd, test_telegraph_profiles.gd), never as a count
## assertion. Nothing in the suite would have failed if an eighth seam had shipped.
##
## THE PROOF RUNS FALLING: a NINTH `connect_*` anywhere under src/main/ must make this FAIL.
## 3-0c added none — its recorder is a plain runner-owned object called directly at the capture
## points, and `recorded_stream()` is a read accessor, not a seam (no signal, no callback, no
## state handle), which is why it is deliberately NOT named `connect_*`.
##
## STORY 3-6 (AC 2) MOVES THE COUNT TO EIGHT, AND THAT IS THE ONE SANCTIONED EXCEPTION. The HUD
## cannot learn a hand by reading state — contents and pile order are excluded from to_snapshot()
## by three separate rulings — so rendering the card layer at all requires a genuinely new
## observation channel (PlayerState.cards_changed). This is the operator-approved amendment
## `3-6/R2`, not a refactor: the count moved because a DESIGN decision moved it, the guard's name
## and list moved WITH it in the same commit, and a ninth is the operator's call all over again.
##
## STORY 5-4 (AC 15) MOVES IT TO NINE, THE SECOND SUCH EXCEPTION — `connect_orbs_changed`. See the
## entry beside that name in the list below for why it had to be a new seam and which two
## alternative shapes were refused. NOTE THE DELIBERATE ASYMMETRY: this TEST moves in 5-4's own
## commit because it is load-bearing and must stay accurate, while
## `docs/game-architecture.md:371-372`'s "there are now eight" prose does NOT — it is queued for the
## E5 close-out flush so several E5 amendments land together (`5-3/R4` is the queue's other member).
const OBSERVATION_SEAMS: Array[String] = [
	"connect_hero_action_state_changed", "connect_hero_action_rejected", "connect_hit_landed",
	"connect_deflect_landed", "connect_hero_hp_changed", "connect_stamina_changed",
	"connect_mana_changed", "connect_cards_changed",
	# Story 5-4 (AC 15) MOVES THE COUNT TO NINE -- THE SECOND SANCTIONED AMENDMENT, and it is the
	# same shape as 3-6's: a DESIGN decision moved the count, and the guard's name and list moved
	# WITH it in the same commit. The HUD cannot learn an orb count any other way (`orbs` is in
	# to_snapshot(), but hud_root.gd holds no MatchState handle and never polls -- `2-4/R7`), and
	# the earn cue needs the same per-slot channel; both consume THIS one seam rather than a second
	# one. The refused alternatives are recorded at connect_orbs_changed itself: a
	# `MatchState.orb_granted` signal (not built) and a second direct presentation-to-MatchState
	# connect (explicitly refused, because `5-3/R4` left that form unresolved in the architecture
	# amendment queue and it must not be settled by accident here). A TENTH is the operator's call
	# all over again.
	"connect_orbs_changed",
]


func test_runner_observation_seams_are_exactly_nine() -> void:  # 2-6/R7, amended 3-6/R2, 5-4 AC 15
	var re := RegEx.create_from_string("^func\\s+(connect_[A-Za-z0-9_]*)\\s*\\(")
	# The pattern must match the form it counts — a regex typo must not silently disarm this.
	assert_true(re.search("func connect_hit_landed(callback: Callable) -> void:") != null,
		"the pattern must match a seam DECLARATION")
	assert_null(re.search("\tconnect_mana_changed(slot, hud.on_mana_changed)"),
		"a CALL is not a declaration and must not be counted")
	var scanned := 0
	var found: Array[String] = []
	for path in _gd_files("res://src/main/"):
		scanned += 1
		for line in _code_lines(path):
			var m := re.search(line)
			if m != null:
				found.append(m.get_string(1))
	assert_true(scanned > 0, "src/main/ scan found no .gd files (guard would be vacuous)")
	found.sort()
	var expected := OBSERVATION_SEAMS.duplicate()
	expected.sort()
	assert_eq(found, expected,
		"the runner's observation-seam family is FROZEN AT NINE (2-6/R7, amended by 3-6/R2 to eight "
		+ "and by 5-4 AC 15 to nine). "
		+ "A TENTH seam is a design change and the operator's call, not a refactor — and a removed "
		+ "one is as loud as an added one: %s" % ", ".join(found))


## Story 4-3 (AC 5, `4-3/R13`): "NO STATE DECISION READS PHYSICS" IS MEASURED, NOT ASSERTED. AC 4
## claims a unit physically blocks a hero while the state layer stays ignorant of collision, and
## `4-2/R15`/`4-3/R7` bound that claim precisely: no code under `src/state/` reads a physics API and
## no state decision branches on a collision result. What is NOT claimed is that collision has no
## effect on state — it does, through the shipped indirection: blocking changes hero NODE positions,
## those positions are the sole geometric input to the runner's `_gather_contact_facts`, and the
## DERIVED facts enter through `push_contact`, the one intake (1-8). This guard measures the half
## that is claimable.
##
## THE TOKEN SET IS CLOSED, BUT THE MATCH IS A SUBSTRING SEARCH WITH NO WORD-BOUNDARY ANCHORING
## (`4-3/R25`): `get_overlapping_areas`, `move_and_slide`, `CollisionShape3D`,
## `PhysicsDirectSpaceState3D`. No "or equivalent" — a guard whose membership is a judgement call is
## not machine-checkable, and widening it is a ruling, not a dev-pass edit. The lack of anchoring
## means it also matches any of the four strings embedded in a longer identifier (a hypothetical
## `my_move_and_slide_helper` would still trip it) — that is a safety property, not a gap: the guard
## FAILS CLOSED, catching a superset of the exact four forms rather than a subset.
##
## THIS GUARD IS GREEN TODAY AGAINST A `src/state/` THAT CONTAINS NO PHYSICS TOKEN AT ALL, which is
## exactly why both halves below are load-bearing rather than ceremonial: it would stay just as
## green at ZERO files scanned (hence the vacuity assert, precedent `:306`/`:348`) and just as green
## with a regex that matches nothing (hence the self-test pair, precedent `:333-338`). Comments are
## stripped by `_code_lines`, so this prose never false-positives.
func test_state_layer_never_reads_physics() -> void:  # Story 4-3 (AC 5), 4-2/R15 promoted
	var re := RegEx.create_from_string(
		"(get_overlapping_areas|move_and_slide|CollisionShape3D|PhysicsDirectSpaceState3D)")
	# The pattern must match every banned form it counts, and must NOT match a named near-miss —
	# a regex typo that silently disarms this fails HERE instead of passing quietly.
	assert_true(re.search("\tmove_and_slide()") != null,
		"the pattern must match the body-move call the runner's drive phase owns")
	assert_true(re.search("var shape := CollisionShape3D.new()") != null,
		"the pattern must match a physics NODE TYPE named in code")
	assert_null(re.search("\tvar areas := hitbox.get_overlapping_bodies()"),
		"a different physics query is NOT in this story's exact token set (4-3/R13: no 'or "
		+ "equivalent' — widening the set is a ruling, not a dev-pass edit)")
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/state/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/state/ scan found no .gd files (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"physics query in src/state/ (AC 5: actors report, state decides — collision reaches state "
		+ "only as a DERIVED fact through push_contact): %s" % ", ".join(offenders))


## Story 3-6 (AC 5): THE HUD IS SIGNAL-DRIVEN, MACHINE-CHECKED FOR THE FIRST TIME. `2-4/R9` chose
## to keep "no _process in the HUD" REVIEW-CHECKED rather than enforced, and it survived five HUD
## stories that way. This story is where that stops paying: it hands the HUD its first genuinely
## time-varying element (the reshuffle flag, which must turn itself OFF), and the obvious way to
## build one is a per-frame countdown in `_process`. So the discipline is enforced now, at the
## moment it first has something to resist.
##
## `_physics_process` is already banned everywhere outside the runner by F1 above; this is the
## `_process` half, scoped to `src/ui/` — the layer whose whole contract is "react to drained
## signals". The shipped alternative is a one-shot SceneTreeTimer, which runs no per-frame code at
## all (hud_root.gd's reshuffle flag).
##
## THE PROOF RUNS FALLING: a `func _process` anywhere under src/ui/ must make this FAIL.
func test_ui_layer_never_polls_per_frame() -> void:  # Story 3-6 (AC 5), 2-4/R9 promoted
	var re := RegEx.create_from_string("^func\\s+_process\\s*\\(")
	# The pattern must match the form it bans, and must NOT match the names that merely contain it
	# — a regex typo that silently disarms this fails here instead of passing quietly.
	assert_true(re.search("func _process(delta: float) -> void:") != null,
		"the pattern must match a _process DECLARATION")
	assert_null(re.search("func _process_payload(x: int) -> void:"),
		"a longer method name that merely starts with _process is not the banned override")
	assert_null(re.search("\tset_process(false)"),
		"a CALL is not a declaration and must not be counted")
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/ui/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d" % [path, n])
	assert_true(scanned > 0, "src/ui/ scan found no .gd files (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"per-frame _process in src/ui/ (AC 5: the HUD updates from drained signals — a countdown "
		+ "is a one-shot timer, never a frame loop): %s" % ", ".join(offenders))


func test_controller_kind_ordinals_pinned() -> void:  # Story 2-2 (2-2/R4)
	# int-literal callers depend on these ordinals: test_camera_relative.gd writes [0, 1] and
	# every 2-2 smoke flip writes int literals like [3, 2] / [2, 3]. A future reorder would
	# silently change the default that ships — the same "a dependency that exists must bite when
	# broken" principle as the F1/D3 scans above. GAMEPAD is APPENDED so NULL stays ordinal 2.
	# Read the enum off the runner script (it has no class_name to statically type against).
	var runner: GDScript = load("res://src/main/match_runner.gd")
	var consts := runner.get_script_constant_map()
	assert_true(consts.has("ControllerKind"), "match_runner.gd defines the ControllerKind enum")
	var k: Dictionary = consts.get("ControllerKind", {})
	assert_eq(k.get("KEYBOARD_P1"), 0, "KEYBOARD_P1 == 0")
	assert_eq(k.get("KEYBOARD_P2"), 1, "KEYBOARD_P2 == 1")
	assert_eq(k.get("NULL"), 2, "NULL stays ordinal 2 (GAMEPAD appended, not inserted)")
	assert_eq(k.get("GAMEPAD"), 3, "GAMEPAD appended == 3")


func test_slot_controller_kinds_default_is_p1_p2() -> void:  # Story 2-3 (2-3/R7, AC1)
	# DISTINCT from test_controller_kind_ordinals_pinned above: that pins the enum VALUES;
	# this pins the SHIPPED default ARRAY. The 2-3 A3 flip moved slot 1 from the 1-6 NULL
	# training dummy ([0, 2]) to a second live keyboard ([0, 1]). The live two-human smoke
	# (2-3/R7) exercises THIS committed default with zero .tscn edits, so a regression that
	# reverts the flip must bite here. Read the export default off a bare instance — @onready
	# vars and _ready() do not run under .new() (no tree), so this is just the export default.
	var runner: GDScript = load("res://src/main/match_runner.gd")
	var inst: Node = runner.new()
	var kinds: Array = inst.slot_controller_kinds
	assert_eq(kinds.size(), 2, "exactly two slots ship (P1, P2)")
	assert_eq(int(kinds[0]), 0, "slot 0 ships KEYBOARD_P1 (ordinal 0)")
	assert_eq(int(kinds[1]), 1, "slot 1 ships KEYBOARD_P2 (ordinal 1) — the 2-3 flip from NULL")
	inst.free()


## Story 1-10 (AC 6): the cues/ui layer is READ-ONLY (D5 — presentation subscribes,
## never writes). Banned tokens = the state layer's public MUTATOR surface (MatchState,
## HeroState, pool mutators) plus the handle tokens that would make any of it reachable
## (`_match_state`, `MatchState.new`). Read accessors (get_hp, is_deflect_window_open,
## to_snapshot, ...) and the ActionState enum stay legal — the guard is on WRITES, not on
## reads. Generic-looking tokens (spend(, add(, heal(, ...) are kept deliberately: a
## false positive fails loudly at review time and costs a rename; a missed mutator costs
## the D5 direction. Same contains-on-code-lines mechanism as the F1 scan above.
const CUES_LAYER_BANNED_TOKENS: Array[String] = [
	# MatchState mutators + the handles that reach them
	"advance(", "drain_signals(", "push_contact(", "apply_balance(",
	"inject_feature_flags(", "set_camera_basis(", "MatchState.new", "_match_state",
	# HeroState mutators / entry actions
	"take_damage(", "heal(", "set_max_hp(", "set_action_state(", "reject_action(",
	"enter_attack(", "chain_attack(", "enter_roll(", "enter_block(",
	"register_swing_hit(", "tick_timers(",
	# Pool mutators (stamina/mana/orb)
	"spend(", "add(", "refill(", "set_maximum(", "advance_regen(", "reset_all(",
]


func test_cues_layer_never_calls_state_mutators() -> void:  # Story 1-10 (AC 6) / D5
	var targets := _gd_files("res://src/ui/")
	# Story 2-4 (2-4/R8): the HUD root must exist under src/ui/hud/. The banned-token scan
	# already covers new src/ui/ files recursively; this existence assertion guards against a
	# MOVE OUT of src/ui/ specifically, which would silently narrow scan coverage — mirroring
	# the telegraph_controller.gd controller_found guard below.
	var hud_root_found := false
	for path in targets:
		if path.ends_with("/hud/hud_root.gd"):
			hud_root_found = true
	assert_true(hud_root_found, "hud_root.gd not found under src/ui/hud/ (2-4/R8)")
	var controller_found := false
	for path in _gd_files("res://src/actors/"):
		if path.ends_with("/telegraph_controller.gd"):
			targets.append(path)
			controller_found = true
	# The named file must exist — a rename would otherwise silently un-guard the layer.
	assert_true(controller_found, "telegraph_controller.gd not found under src/actors/")
	var offenders: Array[String] = []
	for path in targets:
		var n := 0
		for line in _code_lines(path):
			n += 1
			for token in CUES_LAYER_BANNED_TOKENS:
				if line.contains(token):
					offenders.append("%s:%d [%s] %s" % [path, n, token, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"state mutator token in the read-only cues/ui layer: %s" % ", ".join(offenders))


## Story 3-5a (AC 1): THE MODE-SELECT SCHEME IS THE CONTROLLER'S, AND ONLY THE CONTROLLER'S.
## The state layer receives three plain values — armed slot, mode, commit — and nothing about how
## a player produced them. So the scheme's own vocabulary (the cast modifier, the per-slot card
## binds, the confirm) may appear ONLY under src/controllers/, which is what makes "swapping the
## scheme touches one folder" a checkable property rather than an intention.
##
## Scanning all of src/ MINUS src/controllers/ is the load-bearing scope here — the inverse of
## the D3(a) Input scan directly above, and for the same reason: this is about what must stay
## OUT of every other layer.
##
## `card_mode` is deliberately NOT banned: it is the INTENT FIELD the state layer legitimately
## reads, and it is a different token from the `cast_mode` binding that arms it.
const CARD_SCHEME_BANNED_TOKENS: Array[String] = [
	"cast_mode", "cast_confirm", "card_1", "card_2", "card_3", "card_4",
]


func test_card_scheme_only_in_controllers() -> void:  # Story 3-5a (AC 1)
	# NON-VACUITY: the tokens must be REAL somewhere. keyboard_controller.gd is the one producer
	# of the scheme, so a rename there that silently empties this guard fails HERE instead of
	# passing quietly — the same mechanism as the CARDS_DIR and CardDatabase assertions above.
	var scheme_hits := 0
	for line in _code_lines("res://src/controllers/keyboard_controller.gd"):
		for token in CARD_SCHEME_BANNED_TOKENS:
			if line.contains(token):
				scheme_hits += 1
	assert_true(scheme_hits > 0,
		"keyboard_controller.gd must still name the card-scheme bindings — otherwise this guard is vacuous")
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		if path.contains("/controllers/"):
			continue
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			for token in CARD_SCHEME_BANNED_TOKENS:
				if line.contains(token):
					offenders.append("%s:%d [%s] %s" % [path, n, token, line.strip_edges()])
	assert_true(scanned > 0, "the scan must actually visit files")
	assert_eq(offenders.size(), 0,
		"card-scheme symbol outside src/controllers/ (AC 1 — the scheme is the controller's): %s"
				% ", ".join(offenders))


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


## ================================================================================================
## STORY 4-3b (AC 3, `4-3b/R15`): THE SIGNALS DO NOT WIDEN WITH THE FACT.
## ================================================================================================
##
## AC 3 widens the contact FACT's attacker from a bare slot to a `[slot, index]` address, and scopes
## that widening to the fact DICTIONARY alone. `hit_landed` and `deflect_landed` keep a typed BARE
## INT attacker, because both shipped consumers UNDERSCORE it and gate solely on the TARGET slot --
## so a minion damaging a hero already flashes and stings the correct hero with NO change at all,
## and widening the payload would break two typed callbacks for zero behavioural gain.
##
## SCANNED RATHER THAN CALLED, because the failure this guards is a SIGNATURE change, and a
## signature is not observable from an emission: a `hit_landed(attacker: Array, ...)` would still
## emit, still reach a consumer, and still pass every behavioural test in the suite while breaking
## `telegraph_controller.gd`'s typed callback at runtime in the live build only.
##
## THE PROOF RUNS FALLING, on this file's own standing discipline: the patterns are asserted against
## the exact strings they exist to catch AND against the widened forms they exist to reject, so a
## regex that matched everything (or nothing) fails here rather than passing silently.
func test_the_contact_signals_keep_a_bare_int_attacker() -> void:
	var lines := _code_lines("res://src/state/match_state.gd")
	assert_true(lines.size() > 0, "the source was read (a guard over nothing is vacuous)")
	var expected := {
		"hit_landed":
			"signal hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)",
		# STORY 5-5 (AC 13) MOVES THIS ONE LITERAL, and the CLAIM the pin guards is unchanged. AC 13
		# widens `deflect_landed` with a THIRD argument, the answered `defense_color`; the ATTACKER
		# stays a typed BARE INT, which is the whole of `4-3b/R15`'s rule. A parameter LIST that
		# grows is not an attacker that widened -- the falling assertions below still reject
		# `attacker: Array[int]` in both signals, so the guard discriminates exactly what it always
		# did. Note what did NOT move: `OBSERVATION_SEAMS` above stays at NINE, because its regex
		# counts `connect_*` WRAPPER DECLARATIONS in `match_runner.gd`, not signal arity.
		"deflect_landed":
			"signal deflect_landed(attacker_slot: int, target_slot: int, defense_color: int)",
	}
	var found: Dictionary = {}
	for line in lines:
		var stripped := line.strip_edges()
		for name: String in expected:
			if stripped.begins_with("signal %s(" % name):
				found[name] = stripped
	for name: String in expected:
		assert_true(found.has(name), "the `%s` declaration was found at all" % name)
		if found.has(name):
			assert_eq(found[name], expected[name],
				("`%s` still takes a typed BARE INT attacker (`4-3b/R15`) — AC 3's widening is "
				+ "scoped to the FACT DICTIONARY. Its two shipped consumers underscore the "
				+ "attacker and gate on the target, so a minion damaging a hero already flashes "
				+ "the right hero; widening this payload breaks two typed callbacks for zero "
				+ "behavioural gain, and a dev pass reading AC 3 literally must not do it") % name)
	# ...and the guard FALLS: the widened forms it exists to reject do not match the pins above.
	assert_ne(expected["hit_landed"],
		"signal hit_landed(attacker: Array[int], target_slot: int, damage: float, target_hp: float)",
		"sanity: the widened attacker form is a DIFFERENT string, so the equality above discriminates")
	assert_ne(expected["deflect_landed"],
		"signal deflect_landed(attacker: Array[int], target_slot: int, defense_color: int)",
		"sanity: and so is the deflect one, widened third argument and all")
