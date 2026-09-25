extends TestCase

## Story 1-3 coverage: the hero action-state machine. Exact-tick entry/exit per action,
## chain window + cap + reset pins, drop-not-buffer, queued signal sequence, the DEBT A
## null guard, CONSTRAINT C inline duration reads, and the STUNNED/CHARGING inbound-edge
## guard over the transition table.
##
## Test balance (authored as ticks/60.0 so the intended tick counts are explicit):
## windup 3, active 4, recovery 6, chain window 5, deflect 4, roll iframe 2,
## roll duration 5, chain length 3 swings. One attack swing = ticks 1-13
## (windup 1-3, active 4-7, recovery 8-13), IDLE on tick 14; chain window runs
## with recovery and last accepts a press on tick 12.


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	# Story 6-7 (`6-7/R11`): authored EQUAL TO move_speed -- no call site here presses `&"run"`,
	# so an IDLE hero still moves on a plain intent (the STUNNED-vs-IDLE control this file needs).
	c.walk_speed = 5.0
	c.max_stamina = 50.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


## AC 5: apply_balance in setup — the machine is fully exercised headless even though
## live play defers balance injection (DEBT A option b).
func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config())
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed_keys: Array = [], held_keys: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _advance_to_recovery(ms: MatchState) -> void:
	for i in range(60):
		if ms.p1.hero.attack_phase() == &"recovery":
			return
		_advance(ms)
	assert_true(false, "recovery not reached within 60 ticks")


func _advance_until_idle(ms: MatchState) -> void:
	for i in range(60):
		if ms.p1.hero.action_state == HeroState.ActionState.IDLE:
			return
		_advance(ms)
	assert_true(false, "IDLE not reached within 60 ticks")


## ---- STUNNED / CHARGING / DEAD guard (bite-verified both ways) --------------------------

## Enumerates the transition table: there must be ZERO inbound STUNNED edges and zero inbound
## CHARGING edges (reserved E5). The STUNNED row itself must exist as data (accepts nothing);
## CHARGING must have no row at all (absent, not stubbed). Story 1-7 (D-3) extends the guard to
## DEAD: row present, accepts nothing, and ZERO inbound table edges — DEAD is entered
## only by the step-8 resolution (a non-table path) and exited only by the debug reset.
##
## STORY 5-6 (AC 6) CORRECTS THIS DOC-COMMENT AND NOTHING ELSE HERE — the function body is
## FUNCTIONALLY UNEDITED (a comment-only touch, stated rather than claimed byte-identical). The
## stale line said entering STUNNED "would resolve OPEN decision (a) by accident". That decision is
## now resolved deliberately, by `E5-P/R1`, and `STUNNED` has TWO inbound edges — but neither is a
## TABLE edge, so every assertion below still holds unchanged, exactly as they hold for DEAD. The
## POSITIVE half of the guard (that the two non-table entry points are exactly two, and where they
## are) is the separate test directly beneath this one; this negative scan is joined by it, not
## replaced.
func test_table_has_no_inbound_stunned_charging_or_dead_edges() -> void:
	var rows: Dictionary = HeroState.TRANSITION_TABLE
	assert_true(rows.has(&"stunned"), "STUNNED row present (table data)")
	assert_eq((rows[&"stunned"] as Dictionary).size(), 0, "STUNNED accepts no input")
	assert_false(rows.has(&"charging"), "CHARGING row absent, not stubbed (E5)")
	assert_true(rows.has(&"dead"), "DEAD row present (story 1-7, D-3)")
	assert_eq((rows[&"dead"] as Dictionary).size(), 0, "DEAD accepts no input")
	for row_key: StringName in rows:
		var edges: Dictionary = rows[row_key]
		for action: StringName in edges:
			assert_ne(int(edges[action]), int(HeroState.ActionState.STUNNED),
				"inbound STUNNED edge forbidden in E1 (row %s, action %s)" % [row_key, action])
			assert_ne(int(edges[action]), int(HeroState.ActionState.CHARGING),
				"inbound CHARGING edge forbidden until E5 (row %s, action %s)" % [row_key, action])
			assert_ne(int(edges[action]), int(HeroState.ActionState.DEAD),
				"inbound DEAD edge forbidden — death is a step-8 resolution outcome (row %s, action %s)" % [row_key, action])


## STORY 5-6 (AC 6): THE POSITIVE HALF — the guard that REPLACES the old negative-only framing rather
## than deleting it. The scan above proves `STUNNED` has no TABLE edge; on its own that is now a
## MISLEADING guard, because `STUNNED` IS reachable and the table simply is not how. This test names
## the exactly-two (three since 6-6a) AUTHORED non-table entry points and pins the count, the same "positive enumeration
## of a locked set, not merely an absence" shape `OBSERVATION_SEAMS` and `SHIPPED_INPUT_ACTIONS`
## already use elsewhere in this suite.
##
## IT SCANS ALL OF `src/`, NOT JUST `match_state.gd`. The claim AC 6 makes is about THE WHOLE PROJECT,
## and a future story could open a third entry point from anywhere under `src/` — a scan narrowed to
## one file would not see it.
##
## COMMENTS ARE STRIPPED (the `_code_lines` idiom, test_replay_identity.gd's): `match_state.gd`'s own
## negation-branch comment block MENTIONS this token in prose, and a scan that counted prose would
## report three sites for two.
##
## BOTH CALL SITES ARE WRITTEN ON ONE LINE EACH TODAY, and that is worth stating because it is what
## this line-based count relies on. A future formatter that split either call across lines would make
## this test FAIL SAFE (undercounting) rather than silently pass — a loud, fixable failure that
## should not surprise the reader who hits it.
##
## STORY 6-6a (AC 3) AMENDS THE PIN 2 -> 3, AND THE THIRD SITE IS ARGUED HERE, AS THE FAILURE MESSAGE
## BELOW HAS ALWAYS DEMANDED. The third site is the KNOCKDOWN, `MatchState._apply_landing_packages`: an
## UNANSWERED unblockable (the `5-6` ladder's third tier -- neither colour-countered nor dodged) knocks
## its VICTIM down. The argument for a third entry rather than a reuse of either existing one:
##   * it stuns a DIFFERENT PARTY. Both `5-6` edges punish the ATTACKER for being answered; this one
##     punishes the DEFENDER for failing to answer, so neither existing write's subject can carry it.
##   * it is still a direct `set_action_state` call and never a `TRANSITION_TABLE` edge -- the
##     `DEAD`/`5-6` precedent (the table scan above stays unedited and still green), because no PRESS
##     maps to it: the card layer's landing drives it.
##   * it is ONE site, not one per prior state. The prior state's consequences (a CHARGING victim's
##     abandoned chargeup, an ordinary stun escalated, the knockdown floor) are branches AROUND the one
##     write, not further writes.
## MUTATION (6-6a dev pass): the new write deleted -> this pin reads `x2` and goes RED; restored -> green.
##
## STORY 6-6b MOVES THE FIRST SITE AND DOES NOT ADD A FOURTH -- a MEASURED correction to that story's
## own prediction (its AC 16 expected 3 -> 4). The colour answer left `_resolve_charge_landing`
## entirely: the `5-5`/`5-6` landing-tick negation rung is RETIRED (6-6b AC 5) and its
## `set_action_state(STUNNED)` went with it, while the counter's own write arrived at a NEW seat in
## the same pass. One site out, one site in, so the COUNT is unchanged and only the enumeration below
## moves. The argument the failure message demands is therefore about a MOVE, and it is the shape
## `6-6a` used for its third:
##   * a DIFFERENT SUBJECT from the knockdown site: this one punishes the ATTACKER for being answered,
##     that one punishes the VICTIM for failing to answer.
##   * a DIFFERENT SEAT from the one it replaced: the attacker's own step-3 CHARGING arm, judged at
##     the COMMIT and on every pre-contact launch tick, not step 3(a)'s landing and not step 6b's
##     deferred package.
##   * NO DAMAGE, unlike `_apply_landing_packages`, which applies it unconditionally.
##   * still a direct `set_action_state` call and never a `TRANSITION_TABLE` edge -- the table scan
##     above stays unedited and still green, because no PRESS maps to it.
## MUTATION (6-6b dev pass): delete the counter's write -> this pin reads `x2` and goes RED.
func test_stunned_has_exactly_three_authored_non_table_entry_points() -> void:
	var re := RegEx.new()
	re.compile(r"set_action_state\(\s*HeroState\.ActionState\.STUNNED\s*\)")
	var sites: Array[String] = []
	for path in _gd_files("res://src/"):
		var n := 0
		for line in _code_lines(path):
			if re.search(line) != null:
				n += 1
		if n > 0:
			sites.append("%s x%d" % [path, n])
	sites.sort()
	assert_eq(sites, ["res://src/state/match_state.gd x4"],
		"STORY 6-5c (`6-5c/R11`): THREE -> FOUR. The FOURTH is the HONED BOLT LANDING in "
		+ "`_apply_bolt_landing`, and it is ARGUED rather than merely added, on the footing 6-6a and "
		+ "6-6b each used for the third and the counter: a DIFFERENT SUBJECT (the bolt's target -- not "
		+ "the deflected attacker, not the unanswered victim, not the countered attacker), a DIFFERENT "
		+ "SEAT (step 6c's cast strike -- not step 4's deflect ladder, not step 6b's deferred package, "
		+ "not the attacker's own step 3) and a DIFFERENT CAUSE (a spell, not a melee exchange). It "
		+ "cannot reuse any of the three: each writes a different hero with different collateral. The "
		+ "TABLE-edge scan above stays UNEDITED and green, because no PRESS maps to a bolt stun. "
		+ "MUTATION (6-5c dev pass): delete the bolt's write -> this pin reads `x3` and goes RED. "
		+ "The other three, unchanged: the "
		+ "COLOUR COUNTER in `_resolve_color_counter` (6-6b AC 4, which MOVED here from the retired "
		+ "landing rung in `_resolve_charge_landing`), the melee deflect in `_resolve_contacts` "
		+ "(5-6 AC 9), and the knockdown in `_apply_landing_packages` (6-6a AC 3). "
		+ "A fourth site anywhere under src/ fails here and must be argued, not merely added -- got %s"
		% [sites])


## ---- STUNNED's own lifecycle (story 5-6, AC 12 / AC 14 / AC 15) --------------------------
##
## THE STATE IS FORCED HERE rather than produced by a deflect, and that is the shipped idiom for a
## non-table entry point, not a shortcut: `test_contact_resolution.gd` forces DEAD the same way and
## for the same reason — these tests are about what STUNNED DOES once entered, and building a whole
## deflect to reach it would make them tests of `_resolve_contacts` instead. The two REAL entry paths
## are proven where they live (test_block_deflect.gd for AC 9, test_unblockable_defense.gd for AC 5),
## including that they read their tick counts inline from `balance_ticks` (CONSTRAINT C).

const STUN_TICKS := 9


func _stun(ms: MatchState, ticks := STUN_TICKS) -> void:
	ms.p1.hero.stun.start(ticks)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()


## AC 12: the timer arm is the exit, and it fires on the EXACT tick the window empties — one tick
## per advance() (A1), never one early and never one late. Without this arm a stunned hero would sit
## in STUNNED forever, because nothing else in `_resolve_actions` reads `stun` and its `match` has no
## default arm.
func test_a_stunned_hero_exits_to_idle_on_the_exact_tick_the_window_empties() -> void:
	var ms := _make_match()
	_stun(ms)
	for i in STUN_TICKS:
		assert_eq(ms.p1.hero.stun.remaining_ticks(), STUN_TICKS - i,
			"one integer tick per advance() — never a float accumulator (A1)")
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
			"still STUNNED with %d ticks left" % [STUN_TICKS - i])
		_advance(ms)
	assert_false(ms.p1.hero.stun.is_running, "the window has emptied...")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...and the SAME tick's step-3 arm returned the hero to IDLE (AC 12)")


## AC 12's other half, stated as a NEGATIVE: NATURAL EXPIRY ONLY. Nothing this story adds cuts a
## running stun short — not a press, not a contact, not another stun's arrival. Asserted by driving
## every input this hero has at a stunned hero and measuring the countdown against an untouched
## control: an absolute assertion ("still STUNNED") would pass against an implementation that
## shortened the window without ending it.
func test_nothing_cuts_a_running_stun_short() -> void:
	var pressed := _make_match()
	_stun(pressed)
	var control := _make_match()
	_stun(control)
	for action: StringName in [&"attack", &"roll", &"block"]:
		_advance(pressed, _intent([action], [action]))
		_advance(control)
	assert_eq(pressed.p1.hero.stun.remaining_ticks(), control.p1.hero.stun.remaining_ticks(),
		"a stunned hero's countdown is exactly where an unpressed one leaves it — no early-stop "
		+ "path exists (AC 12, the `1-9` precedent Ruling 3 reasserts)")
	assert_eq(pressed.p1.hero.action_state, HeroState.ActionState.STUNNED, "and still STUNNED")


## AC 15: STUNNED forbids attack, roll and block BY CONSTRUCTION — `transition_row()` maps it to the
## `stunned` row, which is the empty dictionary, and a press with no entry in the row is DROPPED,
## NEVER BUFFERED. The drop half is what needs asserting: a buffered press would fire on the exit
## tick, which is exactly the failure this pins.
func test_a_stunned_hero_refuses_every_table_action_and_buffers_none() -> void:
	var ms := _make_match()
	# FIVE ticks, not three, and the margin is load-bearing: step 3(a) runs the timer exit BEFORE
	# step 3(b) reads the table row, so a press made on the EXIT tick lands on the `idle` row and is
	# accepted — correctly, and exactly as `ROLLING`'s and `CHARGING`'s exits already behave. Keeping
	# all three presses strictly INSIDE the window is what makes the drop claim below about buffering
	# rather than about that boundary.
	_stun(ms, 5)
	assert_eq(ms.p1.hero.transition_row(), &"stunned", "the row is `stunned`...")
	assert_eq((HeroState.TRANSITION_TABLE[&"stunned"] as Dictionary).size(), 0, "...and it is empty")
	for action: StringName in [&"attack", &"roll", &"block"]:
		_advance(ms, _intent([action], [action]))
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
			"`%s` pressed while STUNNED changes nothing" % [action])
	_advance(ms)
	_advance(ms)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"the window emptied with no press on the exit tick, so the hero is IDLE...")
	_advance(ms)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...and STAYS idle on the next tick: none of the three presses was buffered")


## AC 14: HARD-ROOTED. A literal zero, not a multiplier — so a full-magnitude move intent produces
## exactly no velocity, and the proof is the CONTROL: the same intent on an IDLE hero moves it.
func test_a_stunned_hero_is_hard_rooted() -> void:
	var ms := _make_match()
	var moving := _intent()
	moving.move_dir = Vector2(1, 0)
	_advance(ms, moving)
	assert_true(ms.p1.hero.velocity.length() > 0.0, "control: an IDLE hero moves on this intent")
	_stun(ms)
	_advance(ms, moving)
	assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
		"a STUNNED hero's velocity is a LITERAL zero on the same intent (AC 14) — not a scaled "
		+ "value a retune could quietly soften")


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


## Code portion of each line (everything before the first '#'), so comments cannot false-positive.
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


## ---- Exact-tick entry/exit --------------------------------------------------------------

func test_attack_phases_and_exit_on_exact_ticks() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1: press takes effect on tick 1
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "ATTACKING on the press tick")
	assert_eq(h.attack_phase(), &"windup")
	_advance(ms)
	_advance(ms)                        # ticks 2-3: windup
	assert_eq(h.attack_phase(), &"windup", "windup through tick 3")
	_advance(ms)                        # tick 4: windup done -> active
	assert_eq(h.attack_phase(), &"active", "active starts on tick 4")
	for i in range(3):
		_advance(ms)                    # ticks 5-7: active
	assert_eq(h.attack_phase(), &"active", "active through tick 7")
	_advance(ms)                        # tick 8: active done -> recovery + chain window
	assert_eq(h.attack_phase(), &"recovery", "recovery starts on tick 8")
	assert_true(h.chain.is_running, "chain window opens with recovery")
	for i in range(5):
		_advance(ms)                    # ticks 9-13: recovery
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "still ATTACKING on tick 13")
	_advance(ms)                        # tick 14: recovery done -> IDLE
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE exactly on tick 14 (3+4+6 swing)")
	assert_eq(h.chain_index, 0, "sequence end resets chain_index")


func test_roll_exact_ticks_and_iframe_window() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"roll"]))    # tick 1
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "ROLLING on the press tick")
	assert_true(h.roll_iframe.is_running, "iframe open on tick 1")
	_advance(ms)                        # tick 2
	assert_true(h.roll_iframe.is_running, "iframe covers tick 2")
	_advance(ms)                        # tick 3
	assert_false(h.roll_iframe.is_running, "iframe ends after exactly 2 ticks")
	_advance(ms)
	_advance(ms)                        # ticks 4-5
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "rolling through tick 5")
	_advance(ms)                        # tick 6: roll_duration done -> IDLE
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE exactly on tick 6 (5-tick roll)")


func test_block_hold_and_release_exact_ticks() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"block"]))   # tick 1
	assert_eq(h.action_state, HeroState.ActionState.BLOCKING, "BLOCKING on the press tick")
	assert_true(h.deflect.is_running, "deflect window opens at block entry")
	for i in range(4):
		_advance(ms, _intent([], [&"block"]))  # ticks 2-5: held
	assert_false(h.deflect.is_running, "deflect window (4 ticks) closed while block held")
	assert_eq(h.action_state, HeroState.ActionState.BLOCKING, "block persists past the deflect window")
	_advance(ms)                        # tick 6: released
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE on the release tick")


## ---- Cancellability / drop-not-buffer ---------------------------------------------------

func test_non_cancellable_inputs_dropped_not_buffered() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	_advance(ms, _intent([&"roll"]))    # tick 2: windup is non-cancellable
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "roll dropped during windup")
	_advance(ms)
	_advance(ms)                        # ticks 3-4
	_advance(ms, _intent([&"attack"]))  # tick 5: active is non-cancellable
	assert_eq(h.attack_phase(), &"active", "attack dropped during active")
	for i in range(8):
		_advance(ms)                    # ticks 6-13
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "tick 13: still the first swing")
	assert_eq(h.chain_index, 0, "a buffered attack would have chained — it did not")
	_advance(ms)                        # tick 14
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "swing ended: neither press was buffered")


## ---- Chain window, cap, and reset pins --------------------------------------------------

func test_chain_accepts_on_last_window_tick() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	for i in range(10):
		_advance(ms)                    # ticks 2-11
	_advance(ms, _intent([&"attack"]))  # tick 12: chain window still running (4 of 5)
	assert_eq(h.chain_index, 1, "chain accepted on the window's final running tick")
	assert_eq(h.attack_phase(), &"windup", "chained swing restarts windup")


func test_chain_dropped_after_window_closes() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	for i in range(11):
		_advance(ms)                    # ticks 2-12
	_advance(ms, _intent([&"attack"]))  # tick 13: chain window closed in step 2
	assert_eq(h.chain_index, 0, "press after the chain window closes is dropped")
	_advance(ms)                        # tick 14
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "no chain occurred; swing ended")


func test_chain_caps_at_attack_chain_length() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1
	assert_eq(h.chain_index, 1)
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 2 (cap: 3 swings)
	assert_eq(h.chain_index, 2)
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # rejected at the cap
	assert_eq(h.chain_index, 2, "cap reached — press dropped")
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "swing 2 continues uninterrupted")
	_advance_until_idle(ms)
	assert_eq(h.chain_index, 0, "sequence end resets chain_index")


## PIN (user decision, story 1-3): chain into attack 2, roll-cancel during recovery,
## attack again -> the new attack starts a FRESH sequence. A cancelled chain never resumes.
func test_pin_roll_cancel_resets_chain_sequence() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1 ("attack 2")
	assert_eq(h.chain_index, 1, "chained into attack 2")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"roll"]))    # roll-cancel during recovery
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "recovery is roll-cancellable")
	assert_eq(h.chain_index, 0, "exit from ATTACKING resets the sequence")
	_advance_until_idle(ms)
	_advance(ms, _intent([&"attack"]))  # attack again
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING)
	assert_eq(h.chain_index, 0, "new attack starts a fresh sequence")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))
	assert_eq(h.chain_index, 1, "fresh sequence can chain the full length again")


## Same-tick tiebreak pin: INPUT_PRIORITY is (attack, roll, block) — three simultaneous
## presses from IDLE fire exactly ONE transition (attack) and exactly one signal.
func test_same_tick_presses_resolve_by_input_priority() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	var log: Array = []
	h.action_state_changed.connect(func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
		log.append([int(prev), int(cur)]))
	_advance(ms, _intent([&"attack", &"roll", &"block"]))
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "attack wins the same-tick tiebreak")
	assert_eq(log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.ATTACKING)]],
		"exactly one transition, one signal")


## Gated-reject fallthrough pin: at the chain cap, the attack edge REJECTS (returns
## false) and a lower-priority same-tick roll press still fires on that same tick.
func test_capped_chain_rejection_falls_through_to_roll_same_tick() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 2 (cap: 3 swings)
	assert_eq(h.chain_index, 2, "at the cap")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack", &"roll"]))  # capped chain rejects; roll must fire NOW
	assert_eq(h.action_state, HeroState.ActionState.ROLLING,
		"rejected chain falls through to roll on the same tick")
	assert_eq(h.chain_index, 0, "exit from ATTACKING resets the sequence")


## ---- Signal discipline ------------------------------------------------------------------

func test_signal_sequence_queued_and_matches_expected_list() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	var log: Array = []
	h.action_state_changed.connect(func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
		log.append([int(prev), int(cur)]))
	# D5 queue discipline observed directly: advance without draining first.
	var intents: Array[InputIntent] = [_intent([&"attack"]), InputIntent.new()]
	ms.advance(intents)
	assert_eq(log.size(), 0, "enqueued during advance(), never emitted mid-tick")
	ms.drain_signals()
	assert_eq(log.size(), 1, "emitted on drain")
	for i in range(7):
		_advance(ms)                    # ticks 2-8: reach recovery
	_advance(ms, _intent([&"attack"]))  # tick 9: chain (self-transition still emits, AC 4)
	_advance_until_idle(ms)
	_advance(ms, _intent([&"roll"]))
	_advance_until_idle(ms)
	var idle := int(HeroState.ActionState.IDLE)
	var atk := int(HeroState.ActionState.ATTACKING)
	var roll := int(HeroState.ActionState.ROLLING)
	assert_eq(log, [[idle, atk], [atk, atk], [atk, idle], [idle, roll], [roll, idle]],
		"emitted (previous, current) sequence matches the expected list exactly")


## ---- DEBT A guard / CONSTRAINT C --------------------------------------------------------

## DEBT A option (b) pin: without apply_balance (live play today), transition evaluation
## is skipped entirely — actions inert, no signals, no crash.
##
## Story 3-1 (AC 5, 3-1/R3) RE-ANCHORED: a pre-injection MatchState is now stat-less as well
## as inert, so the old fixed-value anchors (100.0 hp / 30.0 stamina) were constructor
## artefacts that no longer exist. The anchor is UNCHANGED FROM CONSTRUCTION, taken over the
## WHOLE per-player snapshot rather than one field — a stronger claim than the two constants
## it replaces, and one that cannot rot the next time a field is added.
##
## MUTATION (the round-end half, AC 5's new guard): delete `if balance_ticks == null: return`
## from _check_resolution and this FAILS on both the round_over assertion and the p1 snapshot
## — a stat-less hero sits at 0 hp, so the very first tick resolves a round end and sets the
## loser DEAD against a hero that was never given any hp to lose.
func test_null_balance_ticks_guard_actions_inert() -> void:
	var ms := MatchState.new(MatchParams.new(7))  # deliberately NO apply_balance
	var h := ms.p1.hero
	var fired := {"n": 0}
	h.action_state_changed.connect(func(_p: HeroState.ActionState, _c: HeroState.ActionState) -> void:
		fired.n += 1)
	var before: Dictionary = ms.to_snapshot()
	assert_eq(ms.p1.hero.get_max_hp(), 0.0, "stat-less at construction: no hp bound (AC 1)")
	assert_eq(ms.p1.stamina.get_maximum(), 0.0, "stat-less at construction: no stamina bound")
	assert_eq(ms.p1.mana.get_maximum(), 0.0, "stat-less at construction: no mana bound")
	for i in range(3):
		_advance(ms, _intent([&"attack"], [&"block"]))
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "actions inert without injected balance")
	assert_eq(fired.n, 0, "no transitions, no signals")
	var after: Dictionary = ms.to_snapshot()
	assert_false(bool(after["round_over"]),
		"NO ROUND END: _check_resolution is gated too, or a 0-hp stat-less hero would lose on tick 1")
	assert_eq(after["p1"], before["p1"], "p1 UNCHANGED FROM CONSTRUCTION across three pressed ticks")
	assert_eq(after["p2"], before["p2"], "p2 UNCHANGED FROM CONSTRUCTION across three pressed ticks")


## CONSTRAINT C pin: an in-flight window keeps its duration across a mid-swing reload;
## the NEXT start() reads the swapped balance_ticks inline (nothing cached anywhere).
func test_mid_swing_reload_new_duration_at_next_start() -> void:
	var ms := _make_match()                 # windup = 3 ticks
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))      # tick 1: windup(3) in flight
	var cfg := _config()
	cfg.attack_windup_seconds = 6.0 / 60.0  # mid-swing reload: windup becomes 6
	ms.apply_balance(cfg)
	ms.drain_signals()
	_advance(ms)
	_advance(ms)                            # ticks 2-3: original 3-tick windup completes
	_advance(ms)                            # tick 4: active starts — original schedule held
	assert_eq(h.attack_phase(), &"active", "in-flight windup kept its pre-reload duration")
	_advance_until_idle(ms)
	_advance(ms, _intent([&"attack"]))      # fresh swing: start() reads swapped balance_ticks
	assert_eq(h.windup.remaining_ticks(), 6, "next start() picked up the reloaded duration")
