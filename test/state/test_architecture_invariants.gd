extends TestCase

## Executable guards for the load-bearing architectural invariants (F1, D3a, D3b). These
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
