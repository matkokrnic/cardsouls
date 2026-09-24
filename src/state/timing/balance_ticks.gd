class_name BalanceTicks
extends RefCounted

## THE single seconds->ticks conversion boundary (A1/D4, story 1-1). Built exactly once per
## balance load / X3 reload from the injected BalanceConfig: every `*_seconds` field is
## converted here via TimingWindow.seconds_to_ticks() (round(), clamped >= 1 tick for any
## non-zero duration) and only integer tick counts exist past this point. Never convert per
## tick, and never let a `*_seconds` float reach advance().
##
## Story 1-4 widening (D3, decision-log Session 2026-07-24/25): BalanceTicks is the home
## for LOAD-TIME DERIVED TICK-DOMAIN VALUES, not only duration->tick conversions. First
## instance: stamina_regen_per_tick, a per-tick RATE derived from stamina_regen_per_second.
## CONSTRAINT C forbids caching a reference to this object, not storing derived values
## inside it — consumers still read ms.balance_ticks.<field> inline at the moment of use.

var stamina_regen_delay_ticks: int
## Fixed per-tick regen amount: stamina_regen_per_second / TICK_HZ, derived once per load.
## advance() takes no delta (A1), so the per-second authoring value is never consumed
## directly — this field is the only regen amount the state layer reads.
var stamina_regen_per_tick: float
## Story 6-7 (AC 2): the RUN gait's fixed per-tick stamina cost -- run_stamina_drain_per_second /
## TICK_HZ, derived once per load on the stamina_regen_per_tick precedent directly above and for
## the same reason (advance() takes no delta, A1: never rate x delta).
var run_stamina_drain_per_tick: float
## Story 3-4 (AC 4): the PASSIVE mana faucet's fixed per-tick amount —
## mana_regen_per_second / TICK_HZ, derived once per load on the stamina_regen_per_tick
## precedent above and for the same reason (advance() takes no delta, A1: never rate x delta).
## The authored `passive_tick` rule names THIS field, not the per-second authoring value, so
## nothing per-second ever reaches the tick ladder.
var mana_regen_per_tick: float
## Story 3-5b (AC 1): the delay between a card being played and its replacement arriving,
## derived ONCE at load like every other duration (the stamina_regen_delay_ticks precedent).
## Read INLINE at the cast seat and at the delivery restart (CONSTRAINT C) — never cached.
var draw_replacement_delay_ticks: int
## Story 3-5b (AC 2): the vulnerable window a reshuffle opens. Derived here for the same reason
## as every sibling; the ONLY thing that reads it is the reshuffle that starts the window
## (AC 2's negative guard is what keeps that true, and OPEN decision (b) open with it).
var reshuffle_vulnerable_window_ticks: int
## Story 4-2 (AC 7, `4-2/R5`(a)/(d)): the throttled retarget cadence in TICKS, derived once at load
## like every sibling. Read INLINE at the step-7 seat (CONSTRAINT C).
##
## THE ONE FIELD IN THIS FILE THAT IS NOT A BARE `seconds_to_ticks()` CALL, and the difference is
## `4-2/R5`(d)'s ruling rather than a local choice. `seconds_to_ticks()` returns 0 for a
## zero-or-negative duration; this field is a MODULO DIVISOR, so a 0 would be a divide-by-zero on
## the tick ladder. It is clamped to a minimum of 1, which gives the degenerate authored value a
## DEFINED meaning — an authored 0 retargets EVERY tick — instead of a crash or a silently disabled
## tick. Zero is therefore a legal in-test value; the AUTHORED value is audited > 0 for the reason
## balance_config.gd states at the field.
var minion_retarget_interval_ticks: int
## Story 4-4 (AC 11): the PER-KIND tick domain — one `UnitKindTicks` per entry of
## `BalanceConfig.unit_kinds`, INDEX-ALIGNED with it, each holding the derived tick counts of that
## kind's attack records.
##
## THIS REPLACES THE FLAT `minion_attack_windup/active/recovery_ticks` TRIPLET story 4-3b shipped
## here. Those three are REMOVED rather than kept alongside, the `attack_move_speed_multiplier`
## precedent `balance_config.gd` set at 3-0b: a half-migration leaves two sources of truth for one
## scalar, and here it would leave every minion's rhythm readable from two places that a retune
## could silently diverge.
##
## IT IS WHY AC 11's BOUNDARY CLAUSE HOLDS. The per-kind durations are `*_seconds` floats on
## `UnitAttackProfile`, and they cross into the tick domain HERE — inside the one
## `BalanceTicks.from_config()` call — exactly as every flat duration in this file does. No second
## boundary is authored, and no `*_seconds` float reaches `advance()`.
##
## Read through `kind_ticks_at()` INLINE at the point of use (CONSTRAINT C), never cached.
var unit_kind_ticks: Array[UnitKindTicks] = []
## Story 4-4 (AC 20): the Mana Accelerator faucet's cadence in ticks. A MODULO DIVISOR, so it takes
## `minion_retarget_interval_ticks`'s clamp above rather than the plain conversion — an authored 0
## means "every tick" instead of a divide-by-zero on the tick ladder.
var mana_accelerator_interval_ticks: int
## Story 6-5b (AC 2, `6-5b/R2`): how long a corpse lasts, in TICKS -- the successor to
## `UnitActor.LINGER_TICKS = 600`. Derived ONCE here like every sibling and read INLINE at the death
## seat's three callers (CONSTRAINT C), never cached on a record and never on an actor.
##
## A PLAIN CONVERSION, not one of the clamped modulo divisors above: it is a COUNTDOWN, so
## `seconds_to_ticks` already clamps any non-zero authored value to a minimum of 1 tick. An authored
## 0.0 derives 0 ticks and every death then leaves no corpse at all -- defined rather than crashing;
## the authoring audit keeps it out of the shipped `.tres`.
var corpse_lifetime_ticks: int
var attack_windup_ticks: int
var attack_active_ticks: int
var attack_recovery_ticks: int
var attack_chain_window_ticks: int
var deflect_window_ticks: int
var roll_iframe_ticks: int
var roll_duration_ticks: int
## Story 6-6b POST-SMOKE (R-S6): `color_counter_stun_ticks` stood here and is RETIRED with its
## authored `color_counter_stun_seconds` -- the colour counter has KNOCKED THE ATTACKER DOWN since
## `6-6b` AC 4 replaced the `5-5`/`5-6` landing rung, so nothing has started a window with it since.
## Story 5-6 (AC 1/AC 9): the melee-deflect stun in TICKS — the line directly above's precedent
## verbatim, derived ONCE here and read INLINE at the one seat that starts the window (CONSTRAINT C).
## This is also what test_data_resources.gd's reflective `*_seconds` -> `*_ticks` probe demands of
## any new `*_seconds` field: a stem-matched twin on this object.
var deflect_stun_ticks: int
## Story 6-6a (AC 3/AC 4): the knockdown stun in TICKS -- the two lines above's precedent verbatim,
## derived ONCE here and read INLINE at the one seat that starts the window (CONSTRAINT C).
var knockdown_stun_ticks: int
## Story 6-6a (AC 8): the get-up iframe window in TICKS, on the `roll_iframe_ticks` precedent.
var get_up_iframe_ticks: int
## Story 5-2 (AC 10): the mode ② chargeup, in TICKS. The `draw_replacement_delay_ticks` precedent
## exactly — derived ONCE here, read INLINE at the one seat that starts the window (CONSTRAINT C),
## and the authored `*_seconds` float never reaches `advance()`. A chargeup measured against a raw
## seconds value inside the tick ladder is the A1 violation this whole file exists to prevent.
var unblockable_chargeup_ticks: int
## Story 6-6b POST-SMOKE (R-S6): `defense_window_ticks` and `counter_eligibility_ticks` stood here
## and are RETIRED with the two authored fields they converted. The one reused defense window is
## started at the COLOUR'S BUSY span below, and THE WHOLE OF THAT SPAN IS THE COUNTER WINDOW -- there
## is no head to measure elapsed ticks against any more, so the judgement reads `is_running` alone.
## Story 6-6b (AC 2): each colour's BUSY span in TICKS -- the length the one reused defense window is
## started at. Three stem-matched twins of the three authored `counter_busy_seconds_*` fields, the
## `unblockable_launch_ticks_*` triplet's shape exactly, read through `counter_busy_ticks_for` below.
##
## PLAIN CONVERSIONS, never the clamped modulo-divisor kind: these are WINDOW DURATIONS, so
## `seconds_to_ticks` already clamps any non-zero authored value to a minimum of 1 tick. An authored
## 0.0 derives 0 ticks and `TimingWindow.start(0)` renders a window that never runs -- the press
## spends its card and stamina, the hero is never busy and no counter can ever land. Defined rather
## than crashing; the authoring audit keeps it out of the shipped `.tres`.
var counter_busy_ticks_red: int
var counter_busy_ticks_blue: int
var counter_busy_ticks_green: int
## Story 6-1c (AC 2/AC 4/AC 11): each colour's LAUNCH SPAN in TICKS -- the chargeup line above's
## precedent verbatim, derived ONCE here and read INLINE at the one seat that starts the landing
## window (the cast, CONSTRAINT C). Three stem-matched twins, one per authored
## `unblockable_launch_seconds_*`, which is exactly what test_data_resources.gd's reflective
## `*_seconds` -> `*_ticks` probe demands. Read through `unblockable_launch_ticks_for` below.
var unblockable_launch_ticks_red: int
var unblockable_launch_ticks_blue: int
var unblockable_launch_ticks_green: int
## Story 6-2 (AC 9): the Pitch Zone countdown, in TICKS -- the `unblockable_chargeup_ticks` precedent,
## derived ONCE here and read INLINE at the one seat that starts the fizzle window (the staging tick,
## CONSTRAINT C). The authored `pitch_stage_timer_seconds` float never reaches `advance()`.
var pitch_stage_timer_ticks: int
## Story 6-3b (AC 5): the pitch HUD's countdown push cadence in ticks. A MODULO DIVISOR, so it takes
## `minion_retarget_interval_ticks`'s clamp rather than the plain conversion -- an authored 0 means
## "every tick" instead of a divide-by-zero at the `_tick % interval` throttle in `MatchState`.
var pitch_countdown_push_interval_ticks: int


## Story 6-1c: the colour lookup over the three launch twins above -- `BalanceConfig`'s
## `unblockable_*_for` shape, and the same answer for a colour with no authored shape (0 ticks: the
## landing resolves on the chargeup-close tick, the pre-6-1c shape).
func unblockable_launch_ticks_for(color: int) -> int:
	match color:
		Enums.CardColor.RED:
			return unblockable_launch_ticks_red
		Enums.CardColor.BLUE:
			return unblockable_launch_ticks_blue
		Enums.CardColor.GREEN:
			return unblockable_launch_ticks_green
	return 0


## Story 6-6b (AC 2): the colour lookup over the three busy twins above --
## `unblockable_launch_ticks_for`'s shape verbatim, including what it answers for a colour with no
## authored shape.
##
## THE SENTINEL ANSWERS ZERO, and that is a RULED degrade rather than a gap. A degraded defense cast
## (`PlayerState.NO_TELEGRAPH_COLOR`, the missing-map-entry path `inject_card_colors`' totality check
## keeps out of live play) can never counter anything -- AC 3's explicit sentinel exclusion refuses
## it against a degraded chargeup too -- so there is no counter and no counter PRESENTATION for it to
## be busy for. A zero busy span therefore opens no window: the card and the stamina are still spent,
## the hero is never rooted, and the `defense` snapshot key reports its resting `[-1, 0]`, which is
## exactly the truth about a colourless defense. Never a substitute colour (the `kind_at` refusal
## rule), and never a one-size fallback: the superseded `defense_window_seconds` is retired outright
## (R-S6), so there is nothing left to resurrect on any path.
func counter_busy_ticks_for(color: int) -> int:
	match color:
		Enums.CardColor.RED:
			return counter_busy_ticks_red
		Enums.CardColor.BLUE:
			return counter_busy_ticks_blue
		Enums.CardColor.GREEN:
			return counter_busy_ticks_green
	return 0


## Story 6-6a (AC 7/AC 8/AC 11): THE STUN-FLAVOR CLASSIFIER -- is a stun window of this duration a
## KNOCKDOWN rather than an ordinary (colour-counter or deflect) stun? `TimingWindow` carries no reason
## field by design (D4), and no stored flavor is added to the snapshot, so the flavor is DERIVED from
## the window's own snapshotted duration against this object's knockdown count. ONE classifier, read by
## the state layer (the floor rule and the get-up arming) and by presentation (clip selection) alike,
## so the two can never disagree about which stun is which.
##
## SOUND ONLY WHILE THE THREE DURATIONS ARE DISTINCT, and AC 4's authoring audit pins that order in
## ticks (`knockdown > color_counter > deflect`). Named fragility, not solved here: a retune that
## authored two of them equal (or inverted) would make this comparison silently wrong. A running window
## also keeps its duration across a balance reload (D4), and the three-way order is audited on the
## authored `.tres` only, never at `apply_balance` -- so a live reload can reclassify an IN-FLIGHT stun,
## on the state side (and so in the recorded replay), not just in presentation:
##   * RAISING the knockdown count (or zeroing it) mid-knockdown reads that window as ordinary: a second
##     landing escalates it into a FRESH knockdown instead of being floored (AC 7), and its exit arms no
##     get-up iframes (AC 8) and so plays no `get_up`.
##   * LOWERING the knockdown count to at or below an in-flight ORDINARY stun's duration reads that
##     window as a knockdown: a landing on it is floored instead of escalating (AC 5), and its exit arms
##     the get-up iframes.
## Presentation couples to the same arming: with `get_up_iframe_ticks == 0` the timer exit arms nothing,
## so the runner forwards no get-up and the `get_up` clip is skipped (the authored audit pins `> 0`).
##
## A ZERO knockdown count classifies NOTHING as a knockdown (every in-test config that never authors the
## field): a 0-tick knockdown never runs, and "every stun is a knockdown" would be the wrong degrade.
func is_knockdown_stun(duration_ticks: int) -> bool:
	return knockdown_stun_ticks > 0 and duration_ticks >= knockdown_stun_ticks


static func from_config(config: BalanceConfig) -> BalanceTicks:
	var t := BalanceTicks.new()
	t.stamina_regen_delay_ticks = TimingWindow.seconds_to_ticks(config.stamina_regen_delay_seconds)
	t.stamina_regen_per_tick = config.stamina_regen_per_second / TimingWindow.TICK_HZ
	t.run_stamina_drain_per_tick = config.run_stamina_drain_per_second / TimingWindow.TICK_HZ
	t.mana_regen_per_tick = config.mana_regen_per_second / TimingWindow.TICK_HZ
	t.draw_replacement_delay_ticks = TimingWindow.seconds_to_ticks(
			config.draw_replacement_delay_seconds)
	t.reshuffle_vulnerable_window_ticks = TimingWindow.seconds_to_ticks(
			config.reshuffle_vulnerable_window_seconds)
	# The clamp is HERE, at the single conversion boundary, so no consumer can read an unclamped 0.
	t.minion_retarget_interval_ticks = maxi(1,
			TimingWindow.seconds_to_ticks(config.minion_retarget_interval_seconds))
	# Story 4-4 (AC 20): the accelerator cadence takes the modulo-divisor clamp, for
	# `minion_retarget_interval_ticks`'s reason directly above and not by analogy — it is read as
	# `_tick % interval` at the third `_generate_mana` call site.
	t.mana_accelerator_interval_ticks = maxi(1,
			TimingWindow.seconds_to_ticks(config.mana_accelerator_interval_seconds))
	# Story 4-4 (AC 11): THE PER-KIND CONVERSION, seated INSIDE this one function so the
	# seconds-to-ticks boundary stays single. A null entry in the authored list derives an empty
	# `UnitKindTicks` rather than being skipped, because the derived array must stay INDEX-ALIGNED
	# with `config.unit_kinds` — skipping would shift every later kind's index by one and silently
	# repoint every board record written under the old alignment.
	t.unit_kind_ticks = []
	for kind in config.unit_kinds:
		t.unit_kind_ticks.append(_kind_ticks(kind))
	# Story 6-5b (AC 2): the corpse lifetime, a PLAIN conversion on the `deflect_stun_ticks` idiom --
	# a countdown, clamped to >= 1 tick for any non-zero authored value, never the divisor clamp.
	t.corpse_lifetime_ticks = TimingWindow.seconds_to_ticks(config.corpse_lifetime_seconds)
	t.attack_windup_ticks = TimingWindow.seconds_to_ticks(config.attack_windup_seconds)
	t.attack_active_ticks = TimingWindow.seconds_to_ticks(config.attack_active_seconds)
	t.attack_recovery_ticks = TimingWindow.seconds_to_ticks(config.attack_recovery_seconds)
	t.attack_chain_window_ticks = TimingWindow.seconds_to_ticks(config.attack_chain_window_seconds)
	t.deflect_window_ticks = TimingWindow.seconds_to_ticks(config.deflect_window_seconds)
	t.roll_iframe_ticks = TimingWindow.seconds_to_ticks(config.roll_iframe_seconds)
	t.roll_duration_ticks = TimingWindow.seconds_to_ticks(config.roll_duration_seconds)
	# Story 5-6 (AC 1): a plain conversion on the `unblockable_*` family's exact idiom. It is a WINDOW
	# DURATION, so `seconds_to_ticks` already clamps any non-zero authored value to a minimum of 1
	# tick; an authored 0.0 derives 0 ticks and `TimingWindow.start(0)` renders a window that never
	# runs — a stun that ends on the tick it began. That degrade is defined rather than crashing, and
	# the authoring audit is what keeps it out of the shipped `.tres`. (Its colour-counter sibling was
	# retired with the field it converted, 6-6b post-smoke R-S6.)
	t.deflect_stun_ticks = TimingWindow.seconds_to_ticks(config.deflect_stun_seconds)
	# Story 6-6a (AC 4/AC 8): the knockdown stun and the get-up iframes, PLAIN conversions on the two
	# stun lines' exact shape -- window durations, clamped to >= 1 tick for any non-zero authored value.
	t.knockdown_stun_ticks = TimingWindow.seconds_to_ticks(config.knockdown_stun_seconds)
	t.get_up_iframe_ticks = TimingWindow.seconds_to_ticks(config.get_up_iframe_seconds)
	# Story 5-2 (AC 10): a PLAIN conversion, deliberately NOT one of the two clamped modulo
	# divisors above — the chargeup is a WINDOW DURATION, and `seconds_to_ticks` already clamps any
	# non-zero authored duration to a minimum of 1 tick. An authored 0.0 therefore derives 0 ticks,
	# which `TimingWindow.start(0)` renders as a window that never runs: mode ② would land on the
	# very tick it was cast. That degrade is defined rather than crashing, and the authoring audit
	# is what keeps it out of the shipped `.tres`.
	t.unblockable_chargeup_ticks = TimingWindow.seconds_to_ticks(config.unblockable_chargeup_seconds)
	# Story 6-6b (AC 1/AC 2): the three per-colour busy spans, PLAIN conversions on the chargeup's
	# exact shape directly above and for its stated reasons -- window durations, already clamped to a
	# minimum of 1 tick for any non-zero authored value. An authored 0.0 derives 0 ticks, which
	# `TimingWindow.start(0)` renders as a window that never runs: that colour's defense cast would
	# spend the card and the stamina and counter nothing, ever. Defined rather than crashing, and the
	# authoring audit is what keeps it out of the shipped `.tres`. (The superseded one-size defense
	# window and the eligibility span were retired here, 6-6b post-smoke R-S6.)
	t.counter_busy_ticks_red = TimingWindow.seconds_to_ticks(config.counter_busy_seconds_red)
	t.counter_busy_ticks_blue = TimingWindow.seconds_to_ticks(config.counter_busy_seconds_blue)
	t.counter_busy_ticks_green = TimingWindow.seconds_to_ticks(config.counter_busy_seconds_green)
	# Story 6-1c (AC 4/AC 11): the three launch spans, PLAIN conversions on the chargeup's exact shape
	# -- window durations, clamped to a minimum of 1 tick for any non-zero authored value. An authored
	# 0.0 derives 0 ticks, and the landing window then closes WITH the chargeup: no launch at all, the
	# pre-6-1c landing tick. That degrade is the defined unauthored shape, not an error.
	t.unblockable_launch_ticks_red = TimingWindow.seconds_to_ticks(
			config.unblockable_launch_seconds_red)
	t.unblockable_launch_ticks_blue = TimingWindow.seconds_to_ticks(
			config.unblockable_launch_seconds_blue)
	t.unblockable_launch_ticks_green = TimingWindow.seconds_to_ticks(
			config.unblockable_launch_seconds_green)
	# Story 6-2 (AC 9): the pitch countdown, a PLAIN conversion on the defense window's exact shape -- a
	# window duration, clamped to a minimum of 1 tick for any non-zero authored value. An authored 0.0
	# derives 0 ticks, and a staged card then fizzles on the tick it was staged (its replacement owed
	# that same tick). That degrade is defined rather than crashing; the authoring audit keeps it out
	# of the shipped `.tres`.
	t.pitch_stage_timer_ticks = TimingWindow.seconds_to_ticks(config.pitch_stage_timer_seconds)
	# Story 6-3b (AC 5): the pitch HUD push cadence takes the modulo-divisor clamp, for
	# `minion_retarget_interval_ticks`'s reason and not by analogy -- it is read as `_tick % interval`.
	t.pitch_countdown_push_interval_ticks = maxi(1,
			TimingWindow.seconds_to_ticks(config.pitch_countdown_push_interval_seconds))
	return t


## Story 4-4 (AC 11): one authored kind's attack durations, converted. Static and private — the
## conversion lives inside this file because this file IS the boundary; putting it on
## `UnitKindProfile` would make a pure schema resource depend on `TimingWindow`, and putting it on
## `UnitKindTicks` would make the derived object know how to derive itself. `from_config()` above is
## the only caller.
##
## A NULL KIND DERIVES AN EMPTY RECORD SET rather than a null entry, so `kind_ticks_at()` below can
## return a real object for every authored index and no seat has to guard twice (once for the index
## and once for the entry). A null ATTACK inside a non-null kind is skipped the same way — it
## derives a zeroed record, keeping the per-record alignment `UnitKindTicks` documents.
static func _kind_ticks(kind: UnitKindProfile) -> UnitKindTicks:
	var out := UnitKindTicks.new()
	if kind == null:
		return out
	for attack in kind.attacks:
		var a := UnitAttackTicks.new()
		if attack != null:
			a.windup_ticks = TimingWindow.seconds_to_ticks(attack.windup_seconds)
			a.active_ticks = TimingWindow.seconds_to_ticks(attack.active_seconds)
			a.recovery_ticks = TimingWindow.seconds_to_ticks(attack.recovery_seconds)
			a.cadence_ticks = TimingWindow.seconds_to_ticks(attack.cadence_seconds)
			if attack.projectile != null:
				a.projectile_acceleration_delay_ticks = TimingWindow.seconds_to_ticks(
						attack.projectile.acceleration_delay_seconds)
		out.attacks.append(a)
	return out


## The derived tick record set for the kind at `index`, or NULL for an out-of-range index —
## `BalanceConfig.kind_at()`'s twin, index-aligned with it and answering out-of-range the same way,
## so a seat that holds a kind index reads both objects through one guard shape.
func kind_ticks_at(index: int) -> UnitKindTicks:
	if index < 0 or index >= unit_kind_ticks.size():
		return null
	return unit_kind_ticks[index]
