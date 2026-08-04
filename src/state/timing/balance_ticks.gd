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


static func from_config(config: BalanceConfig) -> BalanceTicks:
	var t := BalanceTicks.new()
	t.stamina_regen_delay_ticks = TimingWindow.seconds_to_ticks(config.stamina_regen_delay_seconds)
	t.stamina_regen_per_tick = config.stamina_regen_per_second / TimingWindow.TICK_HZ
	t.mana_regen_per_tick = config.mana_regen_per_second / TimingWindow.TICK_HZ
	t.draw_replacement_delay_ticks = TimingWindow.seconds_to_ticks(
			config.draw_replacement_delay_seconds)
	t.reshuffle_vulnerable_window_ticks = TimingWindow.seconds_to_ticks(
			config.reshuffle_vulnerable_window_seconds)
	t.attack_windup_ticks = TimingWindow.seconds_to_ticks(config.attack_windup_seconds)
	t.attack_active_ticks = TimingWindow.seconds_to_ticks(config.attack_active_seconds)
	t.attack_recovery_ticks = TimingWindow.seconds_to_ticks(config.attack_recovery_seconds)
	t.attack_chain_window_ticks = TimingWindow.seconds_to_ticks(config.attack_chain_window_seconds)
	t.deflect_window_ticks = TimingWindow.seconds_to_ticks(config.deflect_window_seconds)
	t.roll_iframe_ticks = TimingWindow.seconds_to_ticks(config.roll_iframe_seconds)
	t.roll_duration_ticks = TimingWindow.seconds_to_ticks(config.roll_duration_seconds)
	t.stun_ticks = TimingWindow.seconds_to_ticks(config.stun_seconds)
	return t
