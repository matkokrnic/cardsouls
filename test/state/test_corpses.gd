extends TestCase

## Story 6-5b (AC 1-7): THE CORPSE AS GAME STATE, and the DEATH SEAT that creates it.
##
## Covers AC 1 (a corpse is a fact in state: owner, dead index, remaining lifetime, no position),
## AC 2 (the lifetime is authored and the actor's constant is gone), AC 3 (ONE death seat on
## `UnitBoard` beside `apply_damage_at`, three callers, idempotent), AC 4 (the per-tick countdown and
## removal at zero), AC 5 (cleared at the debug reset only, never round end), AC 6 (the three causes
## are indistinguishable in their aftermath) and AC 7 (Culling and Drain KILL without DAMAGING, so
## the 6-5a funnel never sees them).
##
## THE OWN-MINION SPELLS' OWN BEHAVIOUR IS test_own_minion_spells.gd's. What lives here is the corpse
## and the seat -- the things every one of those four effects is built on.
##
## GOLDEN ISOLATION (`BC/R3`): every config, effect and card below is built IN-TEST with opaque `cp_*`
## ids and in-test numbers; nothing reads `data/`, so a Deck 1 retune moves nothing here.

const SEED := 6520
const MAX_HP := 100.0
const HERO_TO_UNIT := 3.0
const MINION_HP := 9.0
const MINION_DAMAGE := 4.0
const MAX_STAMINA := 50.0
const START_MANA := 50.0

## The in-test corpse lifetime. DELIBERATELY SHORT AND NOT 1200: a test that had to advance the real
## authored 20 s would spend 1200 `advance()` calls to observe one expiry, and the number under test is
## the SEAT (a countdown that reaches zero and removes the corpse), never the tuning. `BC/R3` is what
## makes choosing it here legitimate.
const CORPSE_TICKS := 8
const CORPSE_SECONDS := float(CORPSE_TICKS) / TimingWindow.TICK_HZ

## The kind indices `_config()` authors, in the authored order. Index 0 must be the minion: every
## fixture below that summons straight onto the board passes `add(hp, MINION_KIND)`.
const MINION_KIND := 0
const TOTEM_KIND := 1

const ID_DRAIN := &"cp_drain"
const ID_CULLING := &"cp_culling"
const DRAIN_HEAL := 10.0
const CULLING_MANA_PER_KILL := 2.0
const DECK: Array[StringName] = [ID_DRAIN, ID_CULLING, ID_DRAIN, ID_CULLING]


# ------------------------------------------------------------------ AC 1, AC 2: the corpse fact

## AC 1: a killed minion leaves a corpse, and the corpse is exactly three facts -- whose board it is
## on, which dead index it is tied to, and how long it has left. Read through the board's own public
## surface, which is the whole of what state knows about it.
func test_a_killed_minion_leaves_a_corpse_at_its_own_dead_index() -> void:
	var ms := _match_with_units(1)
	assert_false(ms.p1.units.has_corpse_at(0), "a LIVING unit is not a corpse")
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	assert_false(ms.p1.units.is_alive_at(0), "the record is dead")
	assert_true(ms.p1.units.has_corpse_at(0), "...and it left a corpse at its own index")
	assert_eq(ms.p1.units.corpse_ticks_at(0), CORPSE_TICKS, "...carrying its full lifetime")
	assert_false(ms.p1.units.is_corpse_extended_at(0), "...unextended")
	assert_eq(ms.p1.units.size(), 1, "...and the record is NOT removed: a corpse is a hole, not a gap")
	# THE OWNER IS WHICH BOARD HOLDS IT, and that is the whole of AC 1's ownership clause: there is no
	# owner FIELD to get wrong, so a corpse cannot belong to the wrong player by construction.
	assert_false(ms.p2.units.has_corpse_at(0),
		"the opponent's board has no corpse -- ownership is which board holds it, never a field")


## AC 1: a corpse carries NO POSITION, and this is the machine half of `6-5b/R1`. Asserted by SCANNING
## the board's own source for a positional type rather than by reading a field that does not exist --
## which is the only form that fails when a later story adds one.
##
## CODE LINES ONLY, and that is not a convenience: `unit_board.gd`'s comments say "no `Vector3` here"
## and "position is actor-owned" in as many words, so a raw-text scan would fail on the very prose
## that documents the rule. Scanning the code is also the stricter reading -- it is the code that
## could carry a position.
func test_the_corpse_carries_no_position() -> void:
	var lines := _code_lines("res://src/state/unit_board.gd")
	assert_true(lines.size() > 0, "the source was read (a guard over nothing is vacuous)")
	for line: String in lines:
		for banned: String in ["Vector3", "global_position"]:
			assert_false(line.contains(banned),
				("`UnitBoard` code names no `%s`: a corpse knows WHOSE board and WHICH index, never "
				+ "WHERE (`6-5b/R1`, F1). Raise Dead's placement reads the location off the ACTOR, "
				+ "runner-side. Offending line: %s") % [banned, line.strip_edges()])


## AC 2: the lifetime is AUTHORED, converted once at load, and the actor's constant is GONE. The
## deletion is asserted by SOURCE SCAN, because a removed member cannot be asserted about by reading
## it -- the reference would not compile.
func test_the_corpse_lifetime_is_authored_and_the_actor_constant_is_gone() -> void:
	var config := BalanceConfig.new()
	config.corpse_lifetime_seconds = CORPSE_SECONDS
	assert_eq(BalanceTicks.from_config(config).corpse_lifetime_ticks, CORPSE_TICKS,
		"the authored seconds convert to ticks at the one conversion boundary (A1)")
	# CODE LINES ONLY, for the position scan's stated reason: `unit_actor.gd`'s own comments NAME the
	# deleted members to record that they are gone, so a raw-text scan would fail on that prose.
	var actor_lines := _code_lines("res://src/actors/minions/unit_actor.gd")
	assert_true(actor_lines.size() > 0, "the actor source was read")
	for line: String in actor_lines:
		assert_false(line.contains("LINGER_TICKS"),
			"`UnitActor.LINGER_TICKS` is DELETED, not kept alongside the authored field (AC 2): %s"
					% line.strip_edges())
		assert_false(line.contains("_linger_ticks"),
			"...and so is the actor's own countdown -- the corpse's clock is state's alone: %s"
					% line.strip_edges())
		assert_false(line.contains("advance_corpse_linger"),
			"...and the function that advanced it, so nothing on the actor re-counts a lifetime: %s"
					% line.strip_edges())


# ------------------------------------------------------------------ AC 4: the countdown

## AC 4: the countdown runs one tick per `advance()` and the corpse is REMOVED at zero -- after which
## it can no longer be extended, raised or observed as existing.
func test_the_corpse_counts_down_one_tick_per_advance_and_is_removed_at_zero() -> void:
	var ms := _match_with_units(1)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	for elapsed in CORPSE_TICKS - 1:
		_idle(ms, 1)
		assert_eq(ms.p1.units.corpse_ticks_at(0), CORPSE_TICKS - elapsed - 1,
			"one tick per advance(), never more (A1)")
		assert_true(ms.p1.units.has_corpse_at(0), "...and the corpse is still there")
	_idle(ms, 1)
	assert_eq(ms.p1.units.corpse_ticks_at(0), 0, "the last tick empties the countdown")
	assert_false(ms.p1.units.has_corpse_at(0), "...and the corpse is REMOVED from state")
	assert_eq(ms.p1.units.corpse_indices(), [] as Array[int], "...so it can no longer be raised")
	ms.p1.units.extend_corpse_at(0, 999)
	assert_false(ms.p1.units.has_corpse_at(0), "...nor extended: an expired corpse absorbs nothing")
	_idle(ms, 5)
	assert_eq(ms.p1.units.corpse_ticks_at(0), 0, "...and the countdown never runs negative")


## AC 4 / `2-6/R14`: a corpse does NOT age during the round-over freeze, and it gets that for free from
## the seat -- step 1b returns before step 2, so a frozen tick never reaches `tick_corpses()`.
func test_a_corpse_does_not_age_during_the_round_over_freeze() -> void:
	var ms := _match_with_units(1)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	ms.p2.hero.take_damage(MAX_HP)      # P2 dies -> the round is over
	_idle(ms, 1)
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: the round is frozen")
	var frozen_at := ms.p1.units.corpse_ticks_at(0)
	_idle(ms, 20)
	assert_eq(ms.p1.units.corpse_ticks_at(0), frozen_at,
		"the corpse FREEZES with the round, exactly as every other countdown at step 2 does")
	assert_true(ms.p1.units.has_corpse_at(0), "...and is still a corpse when the freeze ends")


# ------------------------------------------------------------------ AC 5: clearing

## AC 5: corpses clear at the DEBUG RESET and nowhere else -- never at round end. The two halves are
## asserted in one fixture so "persists through round-over" and "cleared by the reset" cannot be
## satisfied by two different states.
func test_corpses_clear_at_the_debug_reset_only_and_never_at_round_end() -> void:
	var ms := _match_with_units(1)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	ms.p2.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: the round ended")
	assert_true(ms.p1.units.has_corpse_at(0),
		"ROUND END clears NO corpse -- `4-1/R5`'s standing rule that the board persists through the "
		+ "round-over freeze rather than blinking out, inherited rather than restated")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "the DEBUG RESET empties the board...")
	assert_false(ms.p1.units.has_corpse_at(0), "...and the corpses with it, in the same clear()")
	# ...AND THE THREE CORPSE ARRAYS ARE CLEARED IN SYNC WITH THEIR TEN SIBLINGS, which the assertion
	# directly above STRUCTURALLY CANNOT SEE. MEASURED, not supposed: dropping the three corpse
	# `clear()` lines from `UnitBoard.clear()` left this whole file GREEN, because `clear()` empties
	# `_hp` too -- so `has_corpse_at` reads false for a MISSING RECORD whether or not the corpse arrays
	# were cleared. The guard was vacuous for the thing it was written to protect.
	#
	# WHAT AN UNSYNCED CLEAR ACTUALLY BREAKS IS INDEX ALIGNMENT, which is the failure this file's own
	# source comment warns about ("one collection expressed as thirteen"): the next summon appends to
	# thirteen arrays of which three are already longer, and from then on every corpse read is off by
	# the number of stale entries. So the falsifying observation is the snapshot's own LENGTHS after a
	# reset followed by a fresh summon -- which is RED under that mutation.
	ms.p1.units.add(MINION_HP, MINION_KIND)
	var after: Dictionary = ms.p1.to_snapshot()
	var records: int = int(after["unit_count"])
	assert_eq(records, 1, "one record after the reset and one fresh summon")
	for key: String in ["unit_hp", "unit_corpse_ticks", "unit_corpse_extended", "unit_raised_from"]:
		assert_eq((after[key] as Array).size(), records,
			("`%s` stays INDEX-ALIGNED with the board across the reset -- a stale entry here silently "
			+ "re-points every later corpse read at the wrong record") % key)


# ------------------------------------------------------------------ AC 1, AC 3: the death seat

## AC 3: the seat is IDEMPOTENT for an already-dead unit -- a second hit on a corpse never creates a
## second corpse, and cannot restart a countdown that has already been extended.
func test_the_death_seat_is_idempotent_on_an_already_dead_unit() -> void:
	var ms := _match_with_units(1)
	assert_true(ms.p1.units.kill_at(0, CORPSE_TICKS), "the first kill IS the death")
	ms.p1.units.extend_corpse_at(0, 50)
	var extended := ms.p1.units.corpse_ticks_at(0)
	assert_false(ms.p1.units.kill_at(0, CORPSE_TICKS), "a second kill is NOT a death and says so")
	assert_eq(ms.p1.units.corpse_ticks_at(0), extended,
		"...and writes nothing: the extended countdown is not reset to a fresh lifetime")
	assert_true(ms.p1.units.is_corpse_extended_at(0), "...nor is the extended mark cleared")


## AC 1 / `6-5b/R10`: a TOTEM leaves no corpse, ever. The exclusion is the `kind_index_at` lookup at
## the seat's caller, handed down as a ZERO lifetime -- so the seat itself holds no policy about kinds.
func test_a_totem_leaves_no_corpse() -> void:
	var ms := _match_with_units(0)
	ms.p1.units.add(MINION_HP, TOTEM_KIND)
	ms.p1.units.add(MINION_HP, MINION_KIND)
	# Killed through the REAL contact path by the OPPOSING hero (a hero cannot hit its own minion --
	# see `_hero_hits_unit`), so the lifetime each one gets is the one production computes rather than
	# a number this test chose.
	#
	# EACH CORPSE IS CHECKED ON THE KILL THAT MADE IT, and that ordering is MEASURED rather than
	# stylistic. An earlier revision killed both units and asserted both corpses at the end; it passed
	# against a mutant that gave TOTEMS corpses, because this fixture's corpse lifetime is deliberately
	# short (8 ticks) and driving the second kill through the real contact path costs more ticks than
	# that -- the totem's corpse had simply AGED OUT before the assertion read it. A vacuous guard, for
	# a reason no amount of re-reading the assertion would have shown.
	_hero_kills_unit(ms, 1, 0, 1)
	assert_false(ms.p1.units.is_alive_at(1), "sanity: the minion died")
	assert_true(ms.p1.units.has_corpse_at(1), "the MINION left a corpse")
	_hero_kills_unit(ms, 1, 0, 0)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the totem died")
	assert_false(ms.p1.units.has_corpse_at(0),
		"...and the TOTEM left NONE (`6-5b/R10`), asserted on the tick its own kill landed")


## AC 1: a HERO death leaves no corpse, and it needs no clause -- a hero is not a board record, so no
## hero death can reach the seat at all. Asserted against the board being untouched by a hero kill.
func test_a_hero_death_leaves_no_corpse() -> void:
	var ms := _match_with_units(0)
	ms.p2.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_false(ms.p2.hero.is_alive(), "sanity: the hero is dead")
	assert_eq(ms.p2.units.corpse_indices(), [] as Array[int],
		"a hero leaves no corpse -- it is not a `UnitBoard` record, so the seat is unreachable for it")


## AC 3: EXACTLY THREE CALLERS of the death seat, and no cause-specific corpse-creation code anywhere
## else. A SOURCE SCAN, because the claim is about the shape of the code rather than about one run:
## a fourth caller, or a corpse written outside the seat, passes every behavioural test in this file
## while being exactly the divergence AC 3 forbids.
## STORY 6-5e (AC 30, `6-5e/R24`/G5): THREE -> FOUR, AND THE NAME MOVES WITH THE COUNT. Corpse Bomb is the
## FOURTH caller: it kills every living own minion through this same seat (ruling 11's "leaves a NORMAL
## corpse ... through the exact same corpse-creation seat every other minion death already uses"), so the
## 3 -> 4 update is the intended consequence of the AC rather than a guard going slack. What the scan still
## forbids is unchanged: a corpse written ANYWHERE but the seat.
## STORY 6-5f (AC 17/AC 20): FOUR -> SIX, AND THE NAME MOVES WITH THE COUNT AGAIN. The two new callers are
## both inside Counterspell's reversal and both REUSE the seat rather than writing a corpse of their own,
## which is exactly the outcome the 6-5f story table predicted ("if a reversal-restore path reaches a NEW
## caller of the corpse-creation seats rather than reusing an existing one, the caller count moves again"):
##   5. `_reverse_summon` -- a countered summon VANISHES, expressed as `kill_at(index, 0)`, i.e. "dead, and
##      this kind leaves no corpse", the seat's own documented zero-lifetime meaning.
##   6. `_reverse_raise_dead` -- each raised minion vanishes the same way.
## Neither is a new corpse-creation mechanism; both are the seat used with a zero lifetime, which is why
## the rival-writer half of this guard below is UNMOVED and still the thing that actually matters.
func test_the_death_seat_has_exactly_six_callers_and_no_rival_corpse_writer() -> void:
	var board := FileAccess.get_file_as_string("res://src/state/unit_board.gd")
	var state := FileAccess.get_file_as_string("res://src/state/match_state.gd")
	assert_true(board.length() > 0 and state.length() > 0, "both sources were read")
	# ONE caller inside the board: `apply_damage_at`, on behalf of the step-4 contact path.
	assert_eq(_occurrences(board, "kill_at("), 2,
		"`UnitBoard` names `kill_at(` TWICE -- its own declaration, plus the ONE call from "
		+ "`apply_damage_at` on behalf of the step-4 contact path (AC 3's first caller)")
	# FIVE callers inside MatchState: Culling, Drain, (6-5e) Corpse Bomb, and (6-5f) the two reversal
	# vanish paths, which reuse the seat with a ZERO lifetime rather than writing a corpse of their own.
	assert_eq(_occurrences(state, "units.kill_at("), 5,
		"`MatchState` calls the death seat exactly FIVE times -- the Culling apply seat, the Drain "
		+ "apply seat, 6-5e's Corpse Bomb apply seat, and 6-5f's two Counterspell vanish paths "
		+ "(`_reverse_summon` and `_reverse_raise_dead`, each `kill_at(index, 0)`: dead, no corpse). "
		+ "A SIXTH call here is a seventh caller and needs its own AC.")
	# Story 6-5f (AC 17/AC 20): the vanish paths pass a ZERO lifetime and NOTHING ELSE does. That is what
	# keeps "no cause gets its own corpse number" true while two callers deliberately ask for no corpse --
	# a zero here is the seat's own documented "this kind leaves no corpse" value, not a second mechanism.
	assert_eq(_occurrences(state, "units.kill_at(index, 0)")
			+ _occurrences(state, "units.kill_at(raised, 0)"), 2,
		"exactly TWO of the five pass a zero corpse lifetime -- the two reversal vanish paths. Every "
		+ "other caller passes `_corpse_ticks_for(...)`, the one authored lifetime read.")
	# ...and nothing else writes a corpse. `_corpse_ticks` is assigned only inside the board, and only
	# by the seat, the extension and the consume -- never from MatchState, an actor or the runner.
	for path: String in ["res://src/state/match_state.gd", "res://src/main/match_runner.gd",
			"res://src/actors/minions/unit_actor.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("_corpse_ticks["),
			"%s never writes the corpse array directly -- it goes through the board's seats" % path)


# ------------------------------------------------------------------ AC 6: one aftermath, three causes

## AC 6: a combat-hit death, a Culling kill and a Drain sacrifice are INDISTINGUISHABLE in their
## aftermath. Asserted as a comparison of the three resulting board states rather than three separate
## "leaves a corpse" assertions -- which is the only form that catches one cause differing.
func test_the_three_death_causes_leave_identical_aftermaths() -> void:
	var by_combat := _match_with_units(1)
	_hero_kills_unit(by_combat, 1, 0, 0)   # P2's hero kills P1's minion: the combat cause
	var by_culling := _match_with_units(1)
	_cast(by_culling, ID_CULLING)
	var by_drain := _match_with_units(1)
	_cast(by_drain, ID_DRAIN)
	for label: String in ["combat", "culling", "drain"]:
		var ms: MatchState = {"combat": by_combat, "culling": by_culling, "drain": by_drain}[label]
		assert_false(ms.p1.units.is_alive_at(0), "%s: the record is dead" % label)
		assert_eq(ms.p1.units.hp_at(0), 0.0, "%s: at exactly 0 hp, its existing hole discipline" % label)
		assert_true(ms.p1.units.has_corpse_at(0), "%s: and it left a corpse" % label)
		assert_eq(ms.p1.units.corpse_ticks_at(0), CORPSE_TICKS,
			"%s: with the SAME authored lifetime -- no cause gets its own number" % label)
		assert_false(ms.p1.units.is_corpse_extended_at(0), "%s: unextended" % label)
		assert_eq(ms.p1.units.raised_from_at(0), UnitBoard.NO_RAISE_SOURCE,
			"%s: and it was nobody's raise" % label)
	# ...and the CORPSE HALF of the snapshot is bit-identical across all three, which is the strongest
	# form of "indistinguishable in their aftermath": any per-cause difference in a hashed corpse field
	# fails here even if every assertion above still passed.
	var combat_keys := _corpse_snapshot(by_combat)
	assert_eq(_corpse_snapshot(by_culling), combat_keys,
		"a Culling kill's hashed corpse state equals a combat kill's, field for field (AC 6)")
	assert_eq(_corpse_snapshot(by_drain), combat_keys,
		"...and so does a Drain sacrifice's")


# ------------------------------------------------------------------ AC 7: kill, not damage

## AC 7: with VAMPIRIC AURA running, a combat kill HEALS the caster and a Culling or Drain kill does
## NOT. The contrast is the test: an assertion that Culling does not heal would pass against a broken
## Aura, so the same fixture proves the funnel is live before proving these two bypass it.
func test_culling_and_drain_never_heal_through_vampiric_aura() -> void:
	# THE CONTROL: P1's hero lands a combat hit on P2's minion under Aura, and heals. The attacker must
	# be the RULE'S OWNER for the control to mean anything, and a hero cannot hit its own minion, so
	# the control's target is the OPPONENT's board -- which is also AC 7's "the equivalent combat-hit
	# kill under the same active rules".
	var control := _match_with_units(0)
	control.p2.units.add(MINION_HP, MINION_KIND)
	control.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 100000, 1.0, 0.0)
	control.p1.hero.take_damage(50.0)
	var control_hp := control.p1.hero.get_hp()
	_hero_kills_unit(control, 0, 1, 0)
	assert_true(control.p1.hero.get_hp() > control_hp,
		"CONTROL: a combat hit under Vampiric Aura heals the caster -- the funnel is live in this "
		+ "fixture, which is what makes the two bypass assertions below mean anything")
	for id: StringName in [ID_CULLING, ID_DRAIN]:
		var ms := _match_with_units(1)
		ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 100000, 1.0, 0.0)
		ms.p1.hero.take_damage(50.0)
		var before := ms.p1.hero.get_hp()
		var expected := before + (DRAIN_HEAL if id == ID_DRAIN else 0.0)
		_cast(ms, id)
		assert_false(ms.p1.units.is_alive_at(0), "%s killed its own minion" % id)
		assert_eq(ms.p1.hero.get_hp(), expected,
			("%s heals ONLY its own authored amount and NOTHING through lifesteal (`6-5b/R4`): it "
			+ "reaches `kill_at` directly, so `_apply_lifesteal` is not on its path at all") % id)


## AC 7: with BLOODLUST running, a Culling or Drain kill is not doubled -- and cannot be, because
## neither passes an amount through `_funnel_damage` at all. Proven by the hp the minion was left at:
## a funnelled kill would still read 0 (the clamp), so the observable is that the minion dies in ONE
## Culling regardless of the multiplier, while the CONTROL shows the funnel really is multiplying.
func test_culling_and_drain_bypass_the_bloodlust_funnel() -> void:
	# THE CONTROL: Bloodlust really does double P1's hero's hit on a minion in this fixture. The target
	# is P2's board for the Aura control's stated reason -- the rule's owner has to be the attacker.
	var control := _match_with_units(0)
	control.p2.units.add(MINION_HP, MINION_KIND)
	control.p1.start_rule(PlayerState.RULE_BLOODLUST, 100000, 2.0, 1.0)
	_hero_hits_unit(control, 0, 1, 0)
	assert_eq(control.p2.units.hp_at(0), MINION_HP - HERO_TO_UNIT * 2.0,
		"CONTROL: Bloodlust doubles a hero's hit on a minion -- the funnel is live in this fixture")
	# A tough minion: one Culling kills it outright no matter what any multiplier would have made of
	# a damage number, because there is no damage number.
	for id: StringName in [ID_CULLING, ID_DRAIN]:
		var ms := _match_with_units(0)
		ms.p1.units.add(MINION_HP * 1000.0, MINION_KIND)
		ms.p1.start_rule(PlayerState.RULE_BLOODLUST, 100000, 2.0, 1.0)
		_cast(ms, id)
		assert_eq(ms.p1.units.hp_at(0), 0.0,
			("%s KILLS rather than damages (`6-5b/R4`): a minion at 1000x the authored maximum dies "
			+ "outright, so no multiplier on any damage number could have been involved") % id)
		assert_true(ms.p1.units.has_corpse_at(0), "...and it still leaves an ordinary corpse")


# ------------------------------------------------------------------ AC 1: the snapshot

## AC 1 / the Golden Prediction's cause 1: the corpse reaches the HASH, as three keys carrying one
## value per board record. Measured here so the golden's own move has a named, separately-asserted
## cause rather than a hash that changed for reasons a reader has to reconstruct.
func test_the_corpse_reaches_the_snapshot_as_three_per_record_keys() -> void:
	var ms := _match_with_units(2)
	var fresh: Dictionary = ms.p1.to_snapshot()
	assert_eq(fresh["unit_corpse_ticks"], [0, 0],
		"a living board hashes a ZERO countdown per record -- one entry per record, not a sparse list")
	assert_eq(fresh["unit_corpse_extended"], [false, false], "...an unextended mark per record")
	assert_eq(fresh["unit_raised_from"], [UnitBoard.NO_RAISE_SOURCE, UnitBoard.NO_RAISE_SOURCE],
		"...and no raise source per record")
	ms.p1.units.kill_at(1, CORPSE_TICKS)
	var dead: Dictionary = ms.p1.to_snapshot()
	assert_eq(dead["unit_corpse_ticks"], [0, CORPSE_TICKS],
		"the corpse's lifetime hashes AT ITS OWN INDEX -- the order is meaningful, so a corpse held by "
		+ "the wrong record is a real divergence the hash sees")
	assert_eq(dead["unit_hp"], [MINION_HP, 0.0], "...beside the hole it belongs to")


# ------------------------------------------------------------------ helpers

## One player-1 board snapshot reduced to its corpse fields -- what AC 6 compares across causes.
func _corpse_snapshot(ms: MatchState) -> Array:
	var snapshot: Dictionary = ms.p1.to_snapshot()
	return [snapshot["unit_hp"], snapshot["unit_corpse_ticks"], snapshot["unit_corpse_extended"],
			snapshot["unit_raised_from"]]


func _occurrences(text: String, needle: String) -> int:
	return text.split(needle).size() - 1


## A source file's CODE lines -- every line whose stripped form is neither empty nor a comment. The
## `test_targeting_service.gd` source-scan shape, local here because this file is the only other one
## that needs it, and because both of its callers exist precisely because this repo's comments QUOTE
## the identifiers the scan forbids in order to record that they are forbidden.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		out.append(raw)
	return out


## A match with `count` living MINIONS on P1's board, added straight to the board (the
## `test_spell_framework.gd` shape): the CAST path is exercised by the tests that are about casting.
func _match_with_units(count: int) -> MatchState:
	var ms := _make_match()
	for _i in count:
		ms.p1.units.add(MINION_HP, MINION_KIND)
	return ms


## ONE confirmed hero hit on a unit, through the real step-4 contact path -- so the corpse it leaves is
## the one production computes rather than one this fixture wrote.
##
## `attacker_slot` IS A PARAMETER BECAUSE A HERO CANNOT HIT ITS OWN MINION. `MatchState.push_contact`
## refuses a fact whose attacker and target slots match ("self-contact fact is malformed in 1v1"), so
## a COMBAT death of P1's own minion is dealt by P2's hero -- which is also the only way it happens in
## play. The funnel controls need the opposite arrangement (P1's hero hitting P2's minion, so the rule
## on P1 is the one being applied), and both read through this one helper.
func _hero_hits_unit(ms: MatchState, attacker_slot: int, target_slot: int, index: int) -> void:
	var attacker: PlayerState = ms.p1 if attacker_slot == 0 else ms.p2
	var press := _press(&"attack")
	if attacker_slot == 0:
		_advance(ms, press, InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), press)
	_idle(ms, 2)
	ms.push_contact([attacker_slot, -1], [target_slot, index], attacker.hero.attack_index,
			Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_idle(ms, 1)


## ...and repeat until it is dead. The budget is derived from `MINION_HP / HERO_TO_UNIT`, so the
## fixture encodes no hits-to-kill number of its own.
func _hero_kills_unit(ms: MatchState, attacker_slot: int, target_slot: int, index: int) -> void:
	var board: UnitBoard = ms.p1.units if target_slot == 0 else ms.p2.units
	for _swing in ceili(MINION_HP / HERO_TO_UNIT) + 2:
		if not board.is_alive_at(index):
			return
		_hero_hits_unit(ms, attacker_slot, target_slot, index)
	assert_false(board.is_alive_at(index), "fixture: the unit died within its hits-to-kill budget")


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_effects())
	ms.inject_pitch_costs(_costs())
	ms.inject_pitch_effects(_effects())
	_idle(ms, 1)   # the step-6 deal
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = 5.0
	c.walk_speed = 2.5
	c.max_stamina = MAX_STAMINA
	c.max_mana = 999.0
	c.deck_size = DECK.size()
	c.hand_size = DECK.size()
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 3.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.block_facing_arc_degrees = 180.0
	c.hero_damage_to_unit = HERO_TO_UNIT
	c.minion_retarget_interval_seconds = 1000.0
	c.corpse_lifetime_seconds = CORPSE_SECONDS
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, MINION_DAMAGE, 2, 3, 4, 2.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, MINION_HP),
	]
	c.unit_kinds = kinds
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK:
		var c := CardCastCondition.new()
		c.mana_cost = 1.0
		out[id] = c
	return out


func _effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK:
		var e := CardEffect.new()
		if id == ID_DRAIN:
			e.effect_id = &"drain"
			e.heal_amount = DRAIN_HEAL
		else:
			e.effect_id = &"culling"
			e.mana_per_kill = CULLING_MANA_PER_KILL
			e.kill_cap = 99
		out[id] = e
	return out


func _cast(ms: MatchState, id: StringName) -> void:
	_advance(ms, _cast_intent(_slot_of(ms.p1, id)), InputIntent.new())


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _slot_of(player: PlayerState, id: StringName) -> int:
	var hand := player.hand.to_array()
	for index in hand.size():
		if not player.hand.is_slot_empty(index) and hand[index] == id:
			return index
	assert_true(false, "fixture: %s is in the dealt hand" % id)
	return -1


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
