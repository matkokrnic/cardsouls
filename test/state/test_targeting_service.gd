extends TestCase

## Story 4-3a (AC 1): `UnitBoard.add()` takes the authored maximum HP now. An IN-TEST value, never
## read from `data/balance/*.tres` (the BC/R3 isolation) — these tests are about targeting, and any
## positive value makes the record LIVING, which is all they need.
const LIVING_HP := 10.0


## Story 4-2: TargetingService (AC 2, 3, 6, 8), the UnitBoard identity extension (AC 9), the
## step-7 throttled tick (AC 7, 11) and the feature-flag matrix (AC 5).
##
## EVERY GUARD IN THIS FILE IS A NAMED PAIR, not a single direction (`4-2/R6`). A guard that cannot
## fall is this project's repeat failure (`2-4/D1`, `2-6/D1`), so every "no target" assertion has a
## POSITIVE twin against a populated candidate set, and the throttle's negative is BEHAVIOURAL — the
## candidate set changes mid-interval and the applied target is checked at the boundary — never
## instrumentation that counts calls.


# ---------------------------------------------------------------- AC 3, the loader

## AC 3: SORTED filename order, the EconomyEvaluator.load_rules contract verbatim. Determinism, not
## tidiness: an unsorted set would depend on filesystem enumeration order, which differs between a
## working tree and an exported build.
##
## Asserted against the AUTHORED directory, whose two files sort `hero_seeker` before `standard` —
## which is also the disagreement `4-2/R17`'s by-name selection rests on (see
## test_minion_authoring.gd).
func test_the_loader_returns_the_authored_set_in_sorted_filename_order() -> void:
	var rules := TargetingService.load_priorities(TargetingService.RULES_DIR)
	var names: Array[StringName] = []
	for rule in rules:
		names.append(rule.priority_name)
	# Story 4-4 (AC 8, `4-4/R9`): `hero_preferring.tres` is the THIRD authored profile, and its
	# position in this list is the whole point of the assertion — sorted by FILENAME, so it lands
	# between `hero_seeker` and `standard` rather than at the end where an append would put it.
	assert_eq(names, [&"hero_preferring", &"hero_seeker", &"standard"] as Array[StringName],
		"the scan is SORTED by filename (hero_preferring.tres, hero_seeker.tres, standard.tres) — "
		+ "never filesystem order")


## AC 3: a MISSING directory degrades to an EMPTY set rather than failing — the FeatureFlags
## graceful-degradation precedent. The PAIR: the real directory yields content, so "empty" is a
## statement about the missing path and not about the loader always returning nothing.
func test_a_missing_directory_degrades_to_an_empty_set() -> void:
	assert_eq(TargetingService.load_priorities("res://data/does_not_exist/"), [] as Array[MinionPriority],
		"a missing rules directory yields an EMPTY set, never a failure (AC 3)")
	assert_true(TargetingService.load_priorities(TargetingService.RULES_DIR).size() > 0,
		"...and the real directory yields content, so the empty result above is not the loader "
		+ "simply never returning anything")


## AC 3: rules are loaded ONCE and kept — content, not live state, with NO reload path and NO cache
## mode (`4-2/R9`: DEBT B is fully discharged and this loader inherits nothing from it). Proven by
## identity: the same call returns the same object instances, so nothing re-reads the disk per tick.
func test_the_authored_set_is_loaded_once_and_kept() -> void:
	var first := TargetingService.authored_priorities()
	var second := TargetingService.authored_priorities()
	assert_true(first.size() > 0, "sanity: there is content to cache")
	assert_true(first[0] == second[0],
		"the authored set is loaded ONCE and kept — the same instances come back, so the step-7 seat "
		+ "does not re-scan the directory every boundary tick")


## `4-2/R9`, the machine half: no reload path and no cache mode was added to this loader by analogy
## with BalanceConfigService. Scanned, because the failure mode is a future pass adding one because
## balance has one.
func test_the_loader_has_no_reload_path_and_no_cache_mode() -> void:
	var lines := _code_lines("res://src/state/targeting/targeting_service.gd")
	assert_true(lines.size() > 0, "the source was read (a guard over nothing is vacuous)")
	for line in lines:
		assert_false(line.contains("CACHE_MODE"),
			"`4-2/R9`: no cache mode belongs here — CACHE_MODE_IGNORE exists only on "
			+ "BalanceConfigService.reload(), and only because balance has a LIVE reload trigger")
		assert_false(line.contains("func reload"),
			"`4-2/R9`: MinionPriority content is directory-scanned, always-loaded structure with no "
			+ "reload path — the EconomyEvaluator precedent, not the balance one")


## `4-2/R17`, condition 1, as its OWN guard: an ABSENT name resolves to NULL, and NEVER to another
## rule. Added because the first mutation run exposed the gap — a `priority_named` that fell back to
## the sorted-first rule PASSED every other test in this file and in test_minion_authoring.gd, since
## every one of those asks for a name that exists. A silent substitution would change which priority
## governs the entire game with nothing failing, which is exactly the class of defect the ruling names.
##
## Both directions in one test: the absent name yields null, the present names yield themselves.
func test_an_absent_priority_name_resolves_to_null_never_to_another_rule() -> void:
	var rules := TargetingService.load_priorities(TargetingService.RULES_DIR)
	assert_true(rules.size() >= 2, "sanity: there are OTHER rules available to be substituted in")
	assert_null(TargetingService.priority_named(rules, &"tank"),
		"a name no authored rule carries resolves to NULL — never to whichever rule happens to be "
		+ "first, which would silently change the priority governing every unit (`4-2/R17`)")
	assert_null(TargetingService.priority_named(rules, &""),
		"...and neither does the EMPTY name, the value an unnamed `.tres` carries")
	assert_eq(TargetingService.priority_named(rules, TargetingService.PRIORITY_STANDARD).priority_name,
		TargetingService.PRIORITY_STANDARD, "a name that IS carried resolves to its own rule")
	assert_eq(TargetingService.priority_named(rules, &"hero_seeker").priority_name, &"hero_seeker",
		"...and so does the other one, so the null results above are not the lookup always failing")
	# AND THE CONSEQUENCE, end to end: a null priority is what the step-7 seat gets when the named
	# rule is missing, and it turns into a NAMED no-target outcome rather than a crash or a
	# substituted rule (AC 6's second reason).
	assert_eq(TargetingService.reason_for(TargetingService.priority_named(rules, &"tank"),
			true, _living(3), _open_flags()), TargetingService.REASON_NO_PRIORITY_DATA,
		"an absent name reaches the evaluator as missing DATA, against a live candidate set")


# ---------------------------------------------------------------- AC 6, the named outcomes

## AC 6, THE POSITIVE HALF, and it comes first deliberately: a file that only ever asserted "no
## target" would pass vacuously. A recognized priority against a live opposing hero ACQUIRES.
func test_a_recognized_priority_against_a_live_candidate_acquires() -> void:
	assert_eq(TargetingService.reason_for(_standard(), true, _living(0), _open_flags()),
		TargetingService.REASON_ACQUIRED, "a live opposing hero IS a candidate")
	assert_eq(TargetingService.reason_for(_standard(), false, _living(3), _open_flags()),
		TargetingService.REASON_ACQUIRED, "so are three opposing units with the hero dead")
	assert_false(TargetingService.is_no_target(
		TargetingService.target_for(_standard(), 1, true, _living(0), _open_flags())),
		"...and the pair that comes back is a REAL target, not the no-target sentinel")


## AC 6, reason ONE: no living candidate. Hero dead AND board empty — the only way the ordered
## candidate set is empty. Paired against both single-candidate cases above.
func test_no_living_candidate_is_a_named_reason_not_a_crash() -> void:
	assert_eq(TargetingService.reason_for(_standard(), false, _living(0), _open_flags()),
		TargetingService.REASON_NO_LIVING_CANDIDATE,
		"a dead opposing hero and an empty opposing board is an honest NAMED no-target outcome")
	assert_true(TargetingService.is_no_target(
		TargetingService.target_for(_standard(), 1, false, _living(0), _open_flags())),
		"...and the verdict is the no-target pair, distinguishable from an acquired target")


## AC 6, reason TWO, all THREE authored-data routes to it. Each is reachable from a `.tres` an author
## could really write — a missing name, an out-of-vocabulary side, an out-of-vocabulary ordering —
## which is what makes this reason non-vacuous rather than a branch nothing can take.
##
## The out-of-range enum values model exactly what a hand-edited or stale `.tres` carries: the editor
## offers members only, a text edit does not.
func test_missing_or_unrecognized_priority_data_is_a_named_reason() -> void:
	assert_eq(TargetingService.reason_for(null, true, _living(5), _open_flags()),
		TargetingService.REASON_NO_PRIORITY_DATA,
		"NO RULE CARRIED THE SELECTED NAME (an empty data/minions/, or a failed export remap): the "
		+ "verdict is named missing-data, and NEVER a silent substitution of another rule (`4-2/R17`)")
	var bad_side := _standard()
	bad_side.target_side = 99
	assert_eq(TargetingService.reason_for(bad_side, true, _living(5), _open_flags()),
		TargetingService.REASON_NO_PRIORITY_DATA,
		"an unrecognized authored `target_side` falls to the named reason (AC 1's last clause)")
	var bad_order := _standard()
	bad_order.ordering_mode = 99
	assert_eq(TargetingService.reason_for(bad_order, true, _living(5), _open_flags()),
		TargetingService.REASON_NO_PRIORITY_DATA,
		"an unrecognized authored `ordering_mode` falls to the same named reason")
	# The PAIR that makes all three non-vacuous: the SAME candidate facts with a RECOGNIZED rule
	# acquire. So each refusal above is attributable to the parameter alone.
	assert_eq(TargetingService.reason_for(_standard(), true, _living(5), _open_flags()),
		TargetingService.REASON_ACQUIRED,
		"identical candidate facts with recognized parameters ACQUIRE — so the three refusals above "
		+ "are caused by the parameter and by nothing else")


## AC 6's MECHANISM, scanned rather than trusted: every outcome is a RETURNED VALUE, so this file
## must contain no `Invariant.check` at all. That is the whole content of "never an Invariant.check
## crash" — and a scan is the right guard here precisely because firing an Invariant.check proves
## nothing headless (`3-0c/R15`).
func test_the_evaluator_names_no_invariant_check() -> void:
	var lines := _code_lines("res://src/state/targeting/targeting_service.gd")
	assert_true(lines.size() > 0, "the source was read (a guard over nothing is vacuous)")
	for line in lines:
		assert_false(line.contains("Invariant."),
			"AC 6: every targeting outcome is a NAMED RETURNED VALUE, never a crash guard — an "
			+ "empty board, no candidates and unrecognized data are all honest verdicts")


# ---------------------------------------------------------------- AC 8, the candidate set and order

## AC 8 / `4-2/R3`: the candidate set is the OPPOSING side ONLY, and own-side units are never
## candidates. Structural rather than filtered — the only slot the evaluator can name is the one it
## is handed — so this asserts the property at the seam that enforces it.
func test_the_verdict_only_ever_names_the_opposing_slot() -> void:
	for opposing_slot in [0, 1]:
		var pair := TargetingService.target_for(_standard(), opposing_slot, true, _living(4), _open_flags())
		assert_eq(pair[0], opposing_slot,
			"the acquired slot is the OPPOSING slot handed in — own-side units are not filtered out, "
			+ "they are unreachable (`4-2/R3`)")


## AC 8 / `4-2/R3`: THE tie-break — board index ASCENDING among units, so index 0 wins. Asserted
## across several board sizes so the answer is the ORDER and not a coincidence at one size.
##
## The SLOT half of the total order is satisfied by construction: the opposing side of a 1v1 is
## exactly one slot, and a one-element set is trivially sorted. Named here so a later multi-slot
## story knows the half it has to make real.
##
## NO Dictionary AND NO StringName PARTICIPATES in this decision, which is the hazard `4-2/R10`
## corrects the citation for: `Array[StringName].sort()` orders by internal POINTER on this engine
## (player_state.gd:77, 206-207; test_determinism.gd:170). The order here is over plain ints.
func test_the_tie_break_is_board_index_ascending() -> void:
	for count in [1, 2, 5, 17]:
		var pair := TargetingService.target_for(_standard(), 1, false, _living(count), _open_flags())
		assert_eq(pair, [1, 0] as Array[int],
			"index ASCENDING: the unit at board index 0 is the target on a board of %d" % count)


## AC 8 / AC 1: the evaluator is GENERIC, not a hardcoded branch — the whole reason a DIFFERING pair
## of `.tres` files is authored (`4-2/R17`, condition 2). Same candidate facts, two rules differing
## in exactly one parameter, two different verdicts.
##
## `hero_seeker` is TEST-ONLY: nothing under `src/` selects it (scanned in
## test_minion_authoring.gd). This is where it earns its authoring.
func test_prefer_hero_changes_the_verdict_against_identical_candidates() -> void:
	var standard := TargetingService.target_for(_standard(), 1, true, _living(3), _open_flags())
	var seeker := TargetingService.target_for(_hero_seeker(), 1, true, _living(3), _open_flags())
	assert_eq(standard, [1, 0] as Array[int],
		"`standard` takes the units first — board index 0 (AC 8's ascending order)")
	assert_eq(seeker, [1, TargetingService.HERO_INDEX] as Array[int],
		"`hero_seeker` takes the HERO — index -1 (AC 11's hero encoding)")
	assert_ne(standard, seeker,
		"ONE parameter, TWO verdicts, identical candidates: the evaluator applies the rule's "
		+ "PARAMETERS rather than branching on a type name (`4-2/R16`)")


## `prefer_hero` is a PREFERENCE, not a restriction, in BOTH directions — the fall-through the golden
## fixture actually exercises (P2's board is empty there, so `standard` targets the hero).
func test_each_preference_falls_through_when_its_first_choice_is_absent() -> void:
	assert_eq(TargetingService.target_for(_standard(), 1, true, _living(0), _open_flags()),
		[1, TargetingService.HERO_INDEX] as Array[int],
		"`standard` with an EMPTY opposing board falls through to the hero, rather than reporting no "
		+ "target — this is the case the golden fixture hashes")
	assert_eq(TargetingService.target_for(_hero_seeker(), 1, false, _living(2), _open_flags()),
		[1, 0] as Array[int],
		"`hero_seeker` with a DEAD opposing hero falls through to the units, in ascending order")


## AC 8: determinism under a FIXED candidate set — the same facts yield the same verdict, every time.
## Cheap to assert and it is the property the whole story rests on.
func test_the_verdict_is_deterministic_under_a_fixed_candidate_set() -> void:
	var first := TargetingService.target_for(_standard(), 1, true, _living(4), _open_flags())
	for _i in 25:
		assert_eq(TargetingService.target_for(_standard(), 1, true, _living(4), _open_flags()), first,
			"a fixed candidate set and a fixed tie-break yield one fixed verdict")


# ---------------------------------------------------------------- AC 5, the flag matrix

## AC 5: the project-context HARD RULE, both directions at the evaluator. Flag OFF and NO FLAGS AT
## ALL both read as CLOSED (a layer that cannot be verified open stays shut — CastEvaluator's own
## direction); flag ON acquires.
func test_the_minions_flag_gates_targeting_in_both_directions() -> void:
	assert_eq(TargetingService.reason_for(_standard(), true, _living(3), _open_flags()),
		TargetingService.REASON_ACQUIRED, "flag ON: a target is acquired")
	assert_eq(TargetingService.reason_for(_standard(), true, _living(3), _closed_flags()),
		TargetingService.REASON_MINIONS_FLAG_CLOSED,
		"flag OFF: a named reason, and NOT one of the two data reasons — 'the layer is switched off' "
		+ "is a different fact about the match")
	assert_eq(TargetingService.reason_for(_standard(), true, _living(3), null),
		TargetingService.REASON_MINIONS_FLAG_CLOSED,
		"NO FLAGS INJECTED reads as CLOSED — a layer that cannot be verified open stays shut")
	assert_true(TargetingService.is_no_target(
		TargetingService.target_for(_standard(), 1, true, _living(3), _closed_flags())),
		"...and a flag-off unit acquires NOTHING (AC 5's own wording)")


## AC 5's ORDERING, which is load-bearing: the flag is consulted BEFORE the data. With the layer off,
## nothing about targeting runs, so reporting an authoring error the switched-off layer would never
## have reached would be a false statement about the match.
func test_a_closed_flag_reports_the_flag_even_with_unrecognized_data() -> void:
	assert_eq(TargetingService.reason_for(null, true, _living(3), _closed_flags()),
		TargetingService.REASON_MINIONS_FLAG_CLOSED,
		"flag first: a closed layer reports the FLAG, not the missing data it never consulted")


# ---------------------------------------------------------------- AC 9, the identity extension

## AC 9: a stable per-unit identity TargetingService can address. The identity is the BOARD INDEX,
## and "stable" means an existing record's index is not disturbed by a later append.
func test_a_unit_identity_is_stable_and_addressable_across_appends() -> void:
	var board := UnitBoard.new()
	board.add(LIVING_HP, 0)
	board.set_target_at(0, 1, TargetingService.HERO_INDEX)
	board.add(LIVING_HP, 0)
	board.add(LIVING_HP, 0)
	assert_eq(board.size(), 3, "three records")
	assert_eq(board.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"record 0 still holds ITS target after two later appends — the index is stable identity")
	assert_true(TargetingService.is_no_target(board.target_at(1)), "record 1 has acquired nothing")
	assert_true(TargetingService.is_no_target(board.target_at(2)), "record 2 likewise")


## AC 9's measured non-mover, at the level a unit test can see it: `size()` returns what the 4-1
## count returned, so `unit_count` cannot move because the collection reshaped (`4-2/R8`). The golden
## measurement is the real proof (78bd2b97 unmoved); this is the local statement of the same claim.
func test_the_board_length_is_unchanged_by_the_identity_extension() -> void:
	var board := UnitBoard.new()
	assert_eq(board.size(), 0, "an empty board is length 0, as the count was")
	assert_true(board.is_empty(), "...and reports empty")
	for i in 4:
		board.add(LIVING_HP, 0)
		assert_eq(board.size(), i + 1, "each append adds exactly one to the length")
	board.clear()
	assert_eq(board.size(), 0, "the debug reset empties it WHOLE (`4-1/R5`) — both arrays together")


## A freshly summoned unit holds the NO-TARGET pair, not a plausible-looking zero. `[0, 0]` would
## read as "the unit at index 0 of player 1" — an acquired target nobody acquired.
func test_a_new_record_holds_the_no_target_pair_not_a_plausible_zero() -> void:
	var board := UnitBoard.new()
	board.add(LIVING_HP, 0)
	assert_eq(board.target_at(0),
		[TargetingService.NO_TARGET_SLOT, TargetingService.NO_TARGET_SLOT] as Array[int],
		"a fresh record's pair is the no-target sentinel")
	assert_ne(board.target_at(0), [0, 0] as Array[int],
		"...and NOT [0, 0], which would read as an acquired target on P1's board index 0")


## AC 11: `targets_snapshot()` emits pairs of PLAIN INTS in board-index order, and hands out no
## handle into the container. The mutation-after-read check is what makes "no handle" a measurement.
func test_the_snapshot_payload_is_plain_int_pairs_in_board_order() -> void:
	var board := UnitBoard.new()
	board.add(LIVING_HP, 0)
	board.add(LIVING_HP, 0)
	board.set_target_at(0, 1, TargetingService.HERO_INDEX)
	board.set_target_at(1, 1, 2)
	var snap := board.targets_snapshot()
	assert_eq(snap, [[1, -1], [1, 2]], "pairs, in board-index order")
	for pair: Array in snap:
		for half: Variant in pair:
			assert_true(half is int, "every half of every pair is a plain int — never a StringName, "
				+ "never an object (CanonicalHash has no object branch)")
	snap[0][0] = 999
	assert_eq(board.target_slot_at(0), 1,
		"mutating the returned payload does NOT reach the container — no handle escapes")


## `3-0c/R15`: the bound guards on UnitBoard's four index accessors are `Invariant.check`s, which
## CANNOT be proven by firing them (headless, an Invariant prints and continues with exit 0). They are
## proven the working way instead: a PUBLIC PREDICATE tested in BOTH directions, plus the scan below
## that every guard is actually wired to it.
func test_the_board_bound_predicate_answers_both_ways() -> void:
	var board := UnitBoard.new()
	assert_false(board.has_index(0), "an empty board holds no index 0")
	assert_false(board.has_index(-1), "...nor a negative index")
	board.add(LIVING_HP, 0)
	board.add(LIVING_HP, 0)
	assert_true(board.has_index(0), "a two-record board holds index 0")
	assert_true(board.has_index(1), "...and index 1")
	assert_false(board.has_index(2), "...and not index 2 (the off-by-one direction)")
	assert_false(board.has_index(-1), "...and still not a negative index")


## The other half of `3-0c/R15`'s shape: every `Invariant.check` in unit_board.gd consults
## `has_index(`, so the predicate tested above is the one the seam actually uses. A guard that
## re-derived `index >= 0 and index < size()` inline would pass every test above while being a
## SECOND copy of the bound — which is the thing this scan exists to prevent.
func test_every_board_bound_guard_is_wired_to_that_predicate() -> void:
	var lines := _code_lines("res://src/state/unit_board.gd")
	assert_true(lines.size() > 0, "the source was read (a guard over nothing is vacuous)")
	var checks := 0
	for line in lines:
		if not line.contains("Invariant.check("):
			continue
		checks += 1
		assert_true(line.contains("has_index("),
			"every bound guard consults the public predicate rather than re-deriving the bound: %s"
					% line.strip_edges())
	assert_eq(checks, 17,
		"SEVENTEEN bound guards ship as of story 4-4 — fifteen through 4-3b plus this story's two "
		+ "per-record accessors (kind_index_at, attack_cooldown_at). `is_attack_ready_at` carries "
		+ "NO Invariant.check and is deliberately absent for `is_hitbox_active_at`'s reason "
		+ "verbatim: it is a lenient PREDICATE, so an index the board has not caught up to reads "
		+ "'not ready' rather than tripping a guard at a caller behaving correctly. Original 4-3b "
		+ "text follows: FIFTEEN bound guards ship as of story 4-3b — the six of 4-3a (target_at, target_slot_at, "
		+ "target_index_at, set_target_at, hp_at, apply_damage_at) plus NINE attack-rhythm seats "
		+ "(attack_phase_at, attack_ticks_at, attack_dir_at, attack_count_at, is_in_reach_at, "
		+ "mark_in_reach_at, set_attack_dir_at, begin_windup_at, set_phase_at). A new accessor "
		+ "without one, or one whose guard was dropped, moves this count. `is_hitbox_active_at` "
		+ "and `tick_attack_timers` carry NO Invariant.check and are deliberately absent: the "
		+ "first is a lenient predicate on the `is_alive_at` precedent (a runner poll may ask "
		+ "about an index the board has not caught up to), the second iterates the array itself "
		+ "and has no index to bound")


# ---------------------------------------------------------------- AC 7 / AC 11, the throttled tick

## AC 7, THE POSITIVE HALF OF THE NAMED PAIR (`4-2/R6`): a target IS acquired, through the real
## step-7 seat, against a populated opposing candidate set. A file that only ever asserted "no
## target" would satisfy nothing here.
##
## Driven through `MatchState.advance()`, not by calling the evaluator — the seat, the throttle, the
## flag read and the storage are all under test together, which is what AC 7 is about.
func test_a_unit_acquires_a_target_through_the_step_seven_seat() -> void:
	var ms := _match_with_interval(4)
	_summon(ms.p1)
	assert_true(TargetingService.is_no_target(ms.p1.units.target_at(0)),
		"before any boundary tick the unit has acquired nothing")
	_advance_to_next_boundary(ms, 4)
	assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"at the boundary the unit acquires the opposing HERO — P2's board is empty, so `standard`'s "
		+ "units-first ordering falls through (AC 8)")


## AC 7, THE BEHAVIOURAL NEGATIVE (`4-2/R6`), and it is behavioural rather than instrumentation on
## purpose: the story forbids proving the throttle by COUNTING CALLS. The candidate set is CHANGED
## MID-INTERVAL and the applied target is read on every tick — it must be UNCHANGED until the
## boundary and CHANGED AT it.
##
## The change is a real one: P2 gains a unit, which flips `standard`'s verdict from the fall-through
## hero (index -1) to the unit at board index 0. Both values are real targets, so this cannot pass by
## a no-target sentinel sitting in for "unchanged".
func test_a_mid_interval_candidate_change_is_not_seen_until_the_boundary_tick() -> void:
	var interval := 6
	var ms := _match_with_interval(interval)
	_summon(ms.p1)
	_advance_to_next_boundary(ms, interval)
	assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"baseline: the unit holds the fall-through hero target")
	# The candidate set changes HERE, one tick after a boundary, so the whole rest of the interval
	# runs with a stale-but-correct target.
	_advance(ms)
	_summon(ms.p2)
	var ticks_to_boundary := interval - (_tick_of(ms) % interval)
	assert_true(ticks_to_boundary > 1,
		"sanity: the change lands with more than one tick left in the interval, or 'until the "
		+ "boundary' would be a single tick and the guard could not fall")
	for i in ticks_to_boundary - 1:
		_advance(ms)
		assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
			("tick %d after the change is INSIDE the interval: the applied target is UNCHANGED even "
			+ "though the candidate set already changed (this is the throttle)") % (i + 1))
	_advance(ms)
	assert_eq(_tick_of(ms) % interval, 0, "sanity: this tick IS the boundary")
	assert_eq(ms.p1.units.target_at(0), [1, 0] as Array[int],
		"AND AT THE BOUNDARY IT CHANGES — to P2's unit at board index 0, which `standard` prefers "
		+ "over the hero. Both halves of the pair are real targets, so neither direction is vacuous")


## AC 7 / `4-2/R5`(c): the counter is `_tick % interval` — NO new state and NO new hash key for the
## cadence itself. Asserted by the shape of the boundary set rather than by reading a private field:
## with an interval of 1 EVERY tick is a boundary, which is the clamp's defined meaning (`4-2/R5`(d))
## and the direct pair for the throttled case above.
func test_an_interval_of_one_tick_retargets_every_tick() -> void:
	var ms := _match_with_interval(1)
	_summon(ms.p1)
	_advance(ms)
	assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"with the interval clamped to 1 the very next tick is a boundary — the degenerate authored "
		+ "value has a DEFINED meaning rather than a crash or a disabled tick")
	_summon(ms.p2)
	_advance(ms)
	assert_eq(ms.p1.units.target_at(0), [1, 0] as Array[int],
		"...and the next tick sees the changed candidate set immediately, which is exactly the "
		+ "per-frame behaviour the authored cadence exists to avoid")


## AC 5 through the REAL SEAT, not just the evaluator: a unit whose match has the minions flag closed
## never acquires a target, however many boundaries pass. The pair is the flag-open match above.
func test_a_flag_off_unit_never_acquires_a_target_through_the_seat() -> void:
	var ms := _match_with_interval(2, false)
	_summon(ms.p1)
	for _i in 12:
		_advance(ms)
		assert_true(TargetingService.is_no_target(ms.p1.units.target_at(0)),
			"with `minions` closed, no boundary ever gives this unit a target (AC 5)")


## AC 7: targeting NEVER changes the board's LENGTH, on any path. `set_target_at` is content-only and
## `add()` owns existence, so a boundary tick against any candidate set leaves the count alone. This
## is what keeps `unit_count` a 4-1 fact rather than something this story can perturb.
func test_the_throttled_tick_never_changes_the_board_length() -> void:
	var ms := _match_with_interval(1)
	_summon(ms.p1)
	_summon(ms.p1)
	_summon(ms.p2)
	for _i in 8:
		_advance(ms)
		assert_eq(ms.p1.units.size(), 2, "P1's board length is untouched by retargeting")
		assert_eq(ms.p2.units.size(), 1, "...and so is P2's")


## AC 7's SPAWN-TICK CASE (`4-2/R18`): a unit summoned by a REAL step-6 cast, on a tick that IS
## itself a throttle boundary, acquires its first target inside that SAME advance() call — the
## step-7 seat sits between step 6 and step 8, so a same-tick summon is already on the board when
## step 7 runs. Driven through a real cast rather than `_summon()`: `_summon()` appends straight to
## `player.units` and never touches step 6, which is exactly why this case went untested before this
## ruling (see the Dev Note in match_state.gd).
func test_a_same_tick_summon_acquires_a_target_when_its_cast_tick_is_a_boundary() -> void:
	var interval := 2
	var ms := _match_for_cast(interval)
	assert_eq(_tick_of(ms), 1, "sanity: the deal advance left the match at tick 1")
	_advance_with(ms, _cast_intent(0), InputIntent.new())
	assert_eq(_tick_of(ms), 2, "sanity: the cast landed on tick 2")
	assert_eq(_tick_of(ms) % interval, 0, "sanity: tick 2 IS a throttle boundary at this interval")
	assert_eq(ms.p1.units.size(), 1, "sanity: the cast really did summon (real step 6, not `_summon()`)")
	assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"the unit acquired its first target in the SAME advance() call that summoned it — step 7 "
		+ "sees it already on the board, and this tick is a boundary (`4-2/R18`)")


## AC 7's PAIR (`4-2/R18`): the SAME real cast, on a tick that is NOT a boundary, leaves the unit at
## no-target until the next boundary tick, where it then acquires. Without this half the case above
## would be unfalsifiable — a seat that always acquired on summon regardless of the boundary check
## would also pass it.
func test_a_same_tick_summon_waits_for_the_next_boundary_when_its_cast_tick_is_not_one() -> void:
	var interval := 5
	var ms := _match_for_cast(interval)
	_advance_with(ms, _cast_intent(0), InputIntent.new())
	assert_eq(_tick_of(ms), 2, "sanity: the cast landed on tick 2")
	assert_true(_tick_of(ms) % interval != 0,
		"sanity: tick 2 is NOT a throttle boundary at this interval")
	assert_eq(ms.p1.units.size(), 1, "sanity: the cast really did summon")
	assert_true(TargetingService.is_no_target(ms.p1.units.target_at(0)),
		"no target yet: the cast tick was not a boundary")
	for _i in interval - _tick_of(ms):
		_advance_with(ms, InputIntent.new(), InputIntent.new())
	assert_eq(_tick_of(ms) % interval, 0, "sanity: this tick IS the boundary")
	assert_eq(ms.p1.units.target_at(0), [1, TargetingService.HERO_INDEX] as Array[int],
		"...and at the boundary the unit acquires — the `_summon()`-based tests above already cover "
		+ "this transition generically; this confirms it also holds for a unit that arrived via a "
		+ "real cast")


## The pre-injection guard, the step-3/5/6 family: a MatchState that never received balance is INERT
## rather than crashing on a modulo against a zeroed BalanceTicks. The PAIR is every test above,
## which runs the seat on an injected match.
func test_a_pre_injection_match_never_reaches_the_throttle() -> void:
	var ms := MatchState.new(MatchParams.new(7))
	ms.inject_feature_flags(_open_flags())
	_summon(ms.p1)
	for _i in 5:
		_advance(ms)
	assert_true(TargetingService.is_no_target(ms.p1.units.target_at(0)),
		"no balance injected: the step-7 seat returns before reading the interval, so the unit is "
		+ "inert rather than the tick dividing by zero (the step-3/5/6 guard family)")


# ---------------------------------------------------------------- Fixture

func _standard() -> MinionPriority:
	var p := MinionPriority.new()
	p.priority_name = TargetingService.PRIORITY_STANDARD
	p.prefer_hero = false
	return p


func _hero_seeker() -> MinionPriority:
	var p := MinionPriority.new()
	p.priority_name = &"hero_seeker"
	p.prefer_hero = true
	return p


func _open_flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.minions = true
	return f


func _closed_flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.minions = false
	return f


## A minimal injected match: real bounds so the heroes are alive, the retarget interval under test,
## and NO deck — nothing here casts, so units are placed on the board directly (see `_summon`).
func _match_with_interval(interval_ticks: int, minions_open := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(11))
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_stamina = 50.0
	c.max_mana = 50.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 3.0 / 60.0
	c.attack_recovery_seconds = 3.0 / 60.0
	c.minion_retarget_interval_seconds = float(interval_ticks) / 60.0
	# Story 4-4 (AC 7, `4-4/R8`): a unit resolves its priority through its OWN KIND now, so a
	# fixture authoring no kind would leave every unit with no priority name, no priority and
	# therefore no target — which would make every case in this file pass or fail for the wrong
	# reason. One minion kind at index 0, naming the same `standard` priority the removed hardcoded
	# `PRIORITY_STANDARD` lookup used to select, so these tests assert exactly what they did before.
	c.unit_kinds = UnitKindFixture.minion_only(LIVING_HP, 3.0, 0, 0, 0, 2.0)
	ms.apply_balance(c)
	ms.inject_feature_flags(_open_flags() if minions_open else _closed_flags())
	ms.drain_signals()
	return ms


## Units are put on the board through `UnitBoard.add(LIVING_HP)` directly rather than by casting a summon. The
## cast path is 4-1's and is covered by test_card_effect_resolution.gd / test_determinism.gd; using it
## here would drag a deck, a cost map, an effect map and a mana budget into every case above without
## making a single assertion stronger.
func _summon(player: PlayerState) -> void:
	player.units.add(LIVING_HP, 0)


func _advance(ms: MatchState) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


## `4-2/R18`'s fixture: a REAL step-6 cast path, the `test_card_effect_resolution.gd` shape
## (deck -> costs -> effects, `4-1/R8`) rather than `_summon()`. Every dealt id carries a summon
## effect, so whichever card the deal puts in a hand slot is castable as a summon without the test
## having to predict the shuffle. Sizes and cost match that file's fixture (proven combination).
const CAST_SEED := 4242
const CAST_DECK_SIZE := 8
const CAST_HAND_SIZE := 4
const CAST_CARD_COST := 3.0
const CAST_START_MANA := 30.0


func _match_for_cast(interval_ticks: int) -> MatchState:
	var ms := MatchState.new(MatchParams.new(CAST_SEED))
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_stamina = 40.0
	c.max_mana = 90.0
	c.deck_size = CAST_DECK_SIZE
	c.hand_size = CAST_HAND_SIZE
	c.minion_retarget_interval_seconds = float(interval_ticks) / 60.0
	# Story 4-4 (AC 7, `4-4/R8`): a unit resolves its priority through its OWN KIND now, so a
	# fixture authoring no kind would leave every unit with no priority name, no priority and
	# therefore no target — which would make every case in this file pass or fail for the wrong
	# reason. One minion kind at index 0, naming the same `standard` priority the removed hardcoded
	# `PRIORITY_STANDARD` lookup used to select, so these tests assert exactly what they did before.
	c.unit_kinds = UnitKindFixture.minion_only(LIVING_HP, 3.0, 0, 0, 0, 2.0)
	ms.apply_balance(c)
	ms.inject_feature_flags(_open_flags())
	ms.inject_deck(_cast_deck_contents())
	ms.inject_card_costs(_cast_costs())
	ms.inject_card_effects(_cast_summon_effects())
	# The deal happens at step 6 of the FIRST advance() — one tick runs here, mana is granted
	# out of band after it, the `_deal_and_fund` idiom.
	_advance_with(ms, InputIntent.new(), InputIntent.new())
	ms.p1.mana.add(CAST_START_MANA)
	ms.p2.mana.add(CAST_START_MANA)
	ms.drain_signals()
	return ms


func _cast_deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in CAST_DECK_SIZE:
		out.append(StringName("targeting_card_%02d" % i))
	return out


func _cast_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _cast_deck_contents():
		var cond := CardCastCondition.new()
		cond.mana_cost = CAST_CARD_COST
		out[id] = cond
	return out


func _cast_summon_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _cast_deck_contents():
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _advance_with(ms: MatchState, p1_intent: InputIntent, p2_intent: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1_intent, p2_intent]
	ms.advance(intents)
	ms.drain_signals()


## Advances until the tick counter lands on a boundary of `interval`, so a test can start from a known
## phase without reaching into `_tick` to set it.
func _advance_to_next_boundary(ms: MatchState, interval: int) -> void:
	for _i in interval * 2:
		_advance(ms)
		if _tick_of(ms) % interval == 0:
			return


## The tick counter, read through the SNAPSHOT rather than the private field — the snapshot is public
## contract and already carries it, so these tests do not reach into MatchState internals.
func _tick_of(ms: MatchState) -> int:
	return int(ms.to_snapshot()["tick"])


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
