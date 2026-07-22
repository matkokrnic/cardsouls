class_name BalanceTicks
extends RefCounted

## THE single seconds->ticks conversion boundary (A1/D4, story 1-1). Built exactly once per
## balance load / X3 reload from the injected BalanceConfig: every `*_seconds` field is
## converted here via TimingWindow.seconds_to_ticks() (round(), clamped >= 1 tick for any
## non-zero duration) and only integer tick counts exist past this point. Never convert per
## tick, and never let a `*_seconds` float reach advance().
##
## (stamina_regen_per_second is a RATE, not a `*_seconds` duration — it is not a window and
## is not converted here.)

var stamina_regen_delay_ticks: int
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
	t.attack_windup_ticks = TimingWindow.seconds_to_ticks(config.attack_windup_seconds)
	t.attack_active_ticks = TimingWindow.seconds_to_ticks(config.attack_active_seconds)
	t.attack_recovery_ticks = TimingWindow.seconds_to_ticks(config.attack_recovery_seconds)
	t.attack_chain_window_ticks = TimingWindow.seconds_to_ticks(config.attack_chain_window_seconds)
	t.deflect_window_ticks = TimingWindow.seconds_to_ticks(config.deflect_window_seconds)
	t.roll_iframe_ticks = TimingWindow.seconds_to_ticks(config.roll_iframe_seconds)
	t.roll_duration_ticks = TimingWindow.seconds_to_ticks(config.roll_duration_seconds)
	t.stun_ticks = TimingWindow.seconds_to_ticks(config.stun_seconds)
	return t
