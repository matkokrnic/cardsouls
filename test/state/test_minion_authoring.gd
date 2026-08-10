extends TestCase

## Story 4-2 (AC 1/AC 3/AC 4): the AUTHORING AUDIT over the REAL `data/minions/` content — the
## test_card_authoring.gd / test_balance_authoring.gd family, deliberately not a mock, because this
## guards what SHIPS.
##
## AC 4's MACHINE HALF (`4-2/R1`, the `4-1/R4` template applied verbatim). AC 4 has two halves, and
## only one of them is executable: (a) the RULING that `.tres` content under `data/minions/` joins
## golden discipline as a determinism-relevant class of change carrying review burden — a statement
## about review, not a measurement, and not asserted here; (b) THIS FILE — every `.tres` in the
## directory loads as a MinionPriority and carries recognized parameters.
##
## AC 3's NON-EMPTY CLAUSE IS THE POINT OF THE FIRST TEST (`4-2/R11`). The loader degrades a MISSING
## directory to an EMPTY set on purpose, which means a silent load failure — an export remap, a
## renamed directory, a `.tres` whose script reference broke — would look EXACTLY like a passing
## test everywhere else in the suite. So the shipped set is asserted non-empty and asserted to
## contain the specific rule the shipped path resolves by name.

const RULES_DIR := "res://data/minions/"


## AC 3 (`4-2/R11`): the authored set LOADS, NON-EMPTY, under the headless harness — no autoload, no
## scene, no editor. This is the loud failure a degraded export remap would otherwise not produce.
func test_the_authored_priority_set_loads_non_empty() -> void:
	var rules := TargetingService.load_priorities(RULES_DIR)
	assert_true(rules.size() > 0,
		"data/minions/ must load at least one MinionPriority under the headless harness — an empty "
		+ "set is what a failed export remap or a broken script reference looks like, and AC 3's "
		+ "graceful degradation would otherwise hide it (`4-2/R11`)")
	assert_eq(rules.size(), 2,
		"EXACTLY TWO priorities are authored this story (AC 1): `standard` and `hero_seeker`. Tank "
		+ "(needs HP) and Bomber/AoE (needs position) are named DEFERRED to 4-3/4-4, not authored — "
		+ "a third file arriving here must come with the story that consumes it")


## AC 1/AC 4(b): every authored file loads as a MinionPriority and carries RECOGNIZED parameters.
## Run through the evaluator's own predicate rather than a re-implementation of it, so the audit and
## the runtime cannot disagree about what "recognized" means.
func test_every_authored_priority_carries_recognized_parameters() -> void:
	var rules := TargetingService.load_priorities(RULES_DIR)
	assert_true(rules.size() > 0, "sanity: there is authored content to audit")
	for rule in rules:
		assert_not_null(rule, "every entry loaded as a MinionPriority")
		assert_true(rule.priority_name != &"",
			"every authored priority carries a name — an unnamed rule is resolvable by no named "
			+ "lookup and would be dead content (`4-2/R17`)")
		# The evaluator's own predicate, reached through its public surface: a rule that is
		# recognized cannot be refused for missing data, and vice versa. Flags are handed in OPEN so
		# this measures the PARAMETERS and not the flag gate.
		assert_eq(TargetingService.reason_for(rule, true, _living(0), _open_flags()),
			TargetingService.REASON_ACQUIRED,
			("authored priority `%s` carries recognized parameters — TargetingService accepts it "
			+ "against a live candidate rather than reporting missing/unrecognized data (AC 6)")
					% rule.priority_name)


## `4-2/R17`: the name the SHIPPED PATH resolves is present in the authored set. This is the audit
## that makes the ruling's first condition machine-checked — selection is an explicit named constant
## resolved BY NAME, never "whatever sorts first", so the constant must actually name something.
##
## THE FILENAME ORDER IS ASSERTED TO DISAGREE WITH THE SELECTION, deliberately, and this is the whole
## non-vacuity of the ruling: `hero_seeker.tres` sorts BEFORE `standard.tres`, so an implementation
## that took the sorted-first rule would select Hero-Seeker and this test would catch it. Without a
## disagreeing pair, "resolved by name" and "whatever sorts first" would be indistinguishable.
func test_the_shipped_priority_is_resolved_by_name_not_by_filename_order() -> void:
	var rules := TargetingService.load_priorities(RULES_DIR)
	var selected := TargetingService.priority_named(rules, TargetingService.PRIORITY_STANDARD)
	assert_not_null(selected,
		("the name the shipped path selects (`%s`) must exist in the authored set — a missing name "
		+ "degrades to a named no-target outcome for every unit in the game (`4-2/R17`)")
				% TargetingService.PRIORITY_STANDARD)
	if selected == null:
		return
	assert_eq(selected.priority_name, TargetingService.PRIORITY_STANDARD, "and it is the one named")
	assert_false(selected.prefer_hero,
		"`standard` is the units-first rule — it is `hero_seeker` that prefers the hero")
	assert_ne(rules[0].priority_name, TargetingService.PRIORITY_STANDARD,
		"THE NON-VACUITY OF `4-2/R17`: the sorted-FIRST authored rule is NOT the one selected "
		+ "(hero_seeker.tres sorts before standard.tres), so an implementation that took the "
		+ "sorted-first rule would fail here instead of passing by coincidence")


## `4-2/R17`, condition 2, made executable: `hero_seeker` is AUTHORED BUT TEST-ONLY. Nothing in the
## shipped path selects it — `PRIORITY_STANDARD` is the one named constant, and `src/` may name no
## other priority name. Scanned rather than trusted, because the failure mode is a future story
## quietly adding a second selection site and leaving both live.
##
## It is NOT speculative machinery, and that is the ruling's own reasoning: without a differing pair
## there is no way to prove the evaluator is GENERIC rather than a hardcoded branch — the same
## non-vacuity argument this project's golden pairs rest on. It is proven behaviourally in
## test_targeting_service.gd, which is where a test-only rule belongs.
func test_hero_seeker_is_authored_but_selected_by_nothing_under_src() -> void:
	var rules := TargetingService.load_priorities(RULES_DIR)
	var seeker := TargetingService.priority_named(rules, &"hero_seeker")
	assert_not_null(seeker, "hero_seeker IS authored — it is the differing half of the proving pair")
	if seeker == null:
		return
	assert_true(seeker.prefer_hero, "...and it differs in exactly the parameter under test")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		for line in _code_lines(path):
			if line.contains("hero_seeker"):
				offenders.append(path.get_file())
				break
	assert_eq(offenders, [] as Array[String],
		"`hero_seeker` is TEST-ONLY (`4-2/R17`, condition 2): nothing under src/ may name it, so no "
		+ "shipped path can select it. Offenders: %s" % ", ".join(offenders))


## A stray non-MinionPriority `.tres` in the directory must be SKIPPED, not loaded and not fatal (AC
## 3's "non-rule resources are skipped, so a stray `.tres` cannot poison the rule set"). Proven
## against a REAL foreign resource from elsewhere in the tree rather than a synthetic one, so the
## skip is tested against the shape an author would actually drop in by mistake.
func test_a_foreign_tres_in_the_directory_would_be_skipped() -> void:
	var foreign := load("res://data/economy/melee_hit.tres")
	assert_not_null(foreign, "sanity: the foreign resource used for this proof exists")
	assert_null(foreign as MinionPriority,
		"a ResourceGenerationRule is NOT a MinionPriority, so the loader's cast yields null and the "
		+ "entry is skipped — which is the mechanism AC 3's stray-`.tres` clause relies on")


func _open_flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.minions = true
	return f


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


# Code portion of each line (everything before the first '#'), so a comment cannot false-positive.
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


## Story 4-3a (AC 8, `4-3a/R15`): the candidate set the evaluator now takes — an ARRAY OF LIVING
## BOARD INDICES, where 4-2 passed a bare COUNT. `_living(n)` is the ALL-ALIVE board of size `n`,
## which is what every pre-4-3a assertion in this file meant by its count, so those assertions keep
## asserting exactly what they asserted before the signature moved.
##
## A board with a HOLE is deliberately NOT expressible through this helper — a hole is the NEW
## behaviour, and the tests that exercise it build their arrays literally so the hole is visible at
## the assertion rather than hidden in a helper.
static func _living(count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(i)
	return out
