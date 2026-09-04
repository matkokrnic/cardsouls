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
var attack_windup_ticks: int
var attack_active_ticks: int
var attack_recovery_ticks: int
var attack_chain_window_ticks: int
var deflect_window_ticks: int
var roll_iframe_ticks: int
var roll_duration_ticks: int
## Converted like every duration, but DATA ONLY in E1 — nothing starts a stun window until
## OPEN decision (a) resolves (see decision-log.md).
var stun_ticks: int
## Story 5-2 (AC 10): the mode ② chargeup, in TICKS. The `draw_replacement_delay_ticks` precedent
## exactly — derived ONCE here, read INLINE at the one seat that starts the window (CONSTRAINT C),
## and the authored `*_seconds` float never reaches `advance()`. A chargeup measured against a raw
## seconds value inside the tick ladder is the A1 violation this whole file exists to prevent.
var unblockable_chargeup_ticks: int


static func from_config(config: BalanceConfig) -> BalanceTicks:
	var t := BalanceTicks.new()
	t.stamina_regen_delay_ticks = TimingWindow.seconds_to_ticks(config.stamina_regen_delay_seconds)
	t.stamina_regen_per_tick = config.stamina_regen_per_second / TimingWindow.TICK_HZ
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
	t.attack_windup_ticks = TimingWindow.seconds_to_ticks(config.attack_windup_seconds)
	t.attack_active_ticks = TimingWindow.seconds_to_ticks(config.attack_active_seconds)
	t.attack_recovery_ticks = TimingWindow.seconds_to_ticks(config.attack_recovery_seconds)
	t.attack_chain_window_ticks = TimingWindow.seconds_to_ticks(config.attack_chain_window_seconds)
	t.deflect_window_ticks = TimingWindow.seconds_to_ticks(config.deflect_window_seconds)
	t.roll_iframe_ticks = TimingWindow.seconds_to_ticks(config.roll_iframe_seconds)
	t.roll_duration_ticks = TimingWindow.seconds_to_ticks(config.roll_duration_seconds)
	t.stun_ticks = TimingWindow.seconds_to_ticks(config.stun_seconds)
	# Story 5-2 (AC 10): a PLAIN conversion, deliberately NOT one of the two clamped modulo
	# divisors above — the chargeup is a WINDOW DURATION, and `seconds_to_ticks` already clamps any
	# non-zero authored duration to a minimum of 1 tick. An authored 0.0 therefore derives 0 ticks,
	# which `TimingWindow.start(0)` renders as a window that never runs: mode ② would land on the
	# very tick it was cast. That degrade is defined rather than crashing, and the authoring audit
	# is what keeps it out of the shipped `.tres`.
	t.unblockable_chargeup_ticks = TimingWindow.seconds_to_ticks(config.unblockable_chargeup_seconds)
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
