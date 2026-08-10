extends TestCase

## Story 4-2 (AC 1): the MinionPriority SCHEMA — the D6 data-vocabulary tier, tested the way
## ResourceGenerationRule and CardCastCondition are: the resource exists, exposes the parameters a
## generic evaluator applies, and defaults to something safe rather than to something accidental.
##
## SCHEMA ONLY. What the parameters MEAN to selection is TargetingService's, tested in
## test_targeting_service.gd; what the AUTHORED files carry is test_minion_authoring.gd's. Keeping
## the three apart is what makes each failure name its own cause.


## AC 1: the parameters exist and are readable — the machine half of "the schema is PARAMETRIC, not
## type-name-keyed" (`4-2/R16`). Asserted by NAME through `get()`, the
## test_data_resources.gd idiom, so a renamed field fails here rather than silently reading null at
## the evaluator.
func test_the_schema_exposes_the_documented_parameters() -> void:
	var p := MinionPriority.new()
	for field in [&"priority_name", &"target_side", &"prefer_hero", &"ordering_mode"]:
		assert_true(field in p, "MinionPriority must expose `%s` (AC 1's parametric schema)" % field)


## The defaults are the SAFE ones, and this is not a cosmetic assertion: a `.tres` that omits a field
## gets the script default, so the default IS authored content for every field an author forgets.
##
## `priority_name` defaults EMPTY deliberately — an unnamed rule is resolvable by no named lookup, so
## a forgotten name degrades to AC 6's named missing-data reason rather than silently becoming the
## priority that governs the game (`4-2/R17`).
##
## `prefer_hero` defaults FALSE, the units-first reading, matching the `standard` rule the shipped
## path selects. A rule that omitted the field therefore behaves like Standard rather than like the
## test-only Hero-Seeker.
func test_the_schema_defaults_are_the_safe_ones() -> void:
	var p := MinionPriority.new()
	assert_eq(p.priority_name, &"",
		"an unnamed priority is resolvable by no named lookup — a forgotten name degrades to the "
		+ "missing-data reason, never to 'this rule now governs the game' (`4-2/R17`)")
	assert_eq(p.target_side, MinionPriority.TargetSide.OPPOSING,
		"the only recognized side is OPPOSING (`4-2/R3`), so it is also the default")
	assert_false(p.prefer_hero, "units-first is the default — the `standard` reading")
	assert_eq(p.ordering_mode, MinionPriority.OrderingMode.SLOT_THEN_INDEX_ASCENDING,
		"the only recognized ordering is the fixed total order (`4-2/R3`), so it is also the default")


## AC 1 / AC 6: the enum VOCABULARIES are exactly one member each today, and that is a pinned fact
## rather than an accident of authoring. Both deferred sets are named at the schema (NEAREST needs
## position, LOWEST_HP needs HP — 4-3; SELF/ALLY need a friendly-targeting mechanic no story owns),
## and adding a member has to be a deliberate act that fails here first.
##
## This is what keeps `TargetingService._is_recognized` honest: it accepts exactly these two values
## and refuses everything else, so if a member were added without extending the evaluator, the new
## member would silently read as unrecognized. This pin makes that impossible to do quietly.
func test_the_recognized_vocabularies_are_exactly_one_member_each() -> void:
	assert_eq(MinionPriority.TargetSide.keys().size(), 1,
		"TargetSide is exactly {OPPOSING} today (`4-2/R3`) — a new member must extend "
		+ "TargetingService._is_recognized in the same pass, and fails here until it does")
	assert_eq(MinionPriority.OrderingMode.keys().size(), 1,
		"OrderingMode is exactly {SLOT_THEN_INDEX_ASCENDING} today (`4-2/R3` fixes the total order) "
		+ "— NEAREST and LOWEST_HP are deferred to 4-3 with the facts they order by")
	assert_eq(int(MinionPriority.TargetSide.OPPOSING), 0, "the authored `.tres` ordinal is pinned")
	assert_eq(int(MinionPriority.OrderingMode.SLOT_THEN_INDEX_ASCENDING), 0,
		"the authored `.tres` ordinal is pinned — a reordered enum would re-mean every authored file")


## NO LOGIC LIVES ON THE SCHEMA (the src/state/resources/ tier contract, ResourceGenerationRule's
## own header). A method here would be a second place priority rules are interpreted, contradicting
## TargetingService's "THE one place" declaration. Scanned rather than trusted: the file must declare
## no `func` at all.
func test_the_schema_declares_no_logic() -> void:
	var lines := _code_lines("res://src/state/resources/minion_priority.gd")
	assert_true(lines.size() > 0, "the schema source was read (a guard over nothing is vacuous)")
	var funcs: Array[String] = []
	for line in lines:
		if line.begins_with("func ") or line.begins_with("static func "):
			funcs.append(line.strip_edges())
	assert_eq(funcs, [] as Array[String],
		"MinionPriority is pure schema — logic belongs in TargetingService, which declares itself "
		+ "THE one place these rules are read: %s" % ", ".join(funcs))


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
