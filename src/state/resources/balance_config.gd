class_name BalanceConfig
extends Resource

## E1 melee balance schema (story 1-1). Authored as data/balance/balance_config.tres and
## loaded by BalanceConfigService (X3 hot-reloadable). State receives this resource by
## INJECTION via MatchState.apply_balance() and never reads the service.
##
## Defaults are all zero ON PURPOSE: gameplay numbers are never hardcoded in code — the
## authored .tres carries the real values (first-guess placeholders, TBD-in-playtest).
##
## `*_seconds` fields are AUTHORING units only. They are converted to integer ticks exactly
## once per load / X3 reload by BalanceTicks (A1); no `*_seconds` float reaches advance().

@export_group("Hero")
@export var max_hp: float = 0.0
@export var move_speed: float = 0.0

@export_group("Stamina")
@export var max_stamina: float = 0.0
@export var stamina_regen_per_second: float = 0.0
@export var stamina_regen_delay_seconds: float = 0.0
@export var roll_stamina_cost: float = 0.0
@export var deflect_stamina_cost: float = 0.0

@export_group("Attack")
@export var attack_windup_seconds: float = 0.0
@export var attack_active_seconds: float = 0.0
@export var attack_recovery_seconds: float = 0.0
@export var attack_chain_window_seconds: float = 0.0
@export var attack_chain_length: int = 0
@export var attack_damage_percent_of_max_hp: float = 0.0
## Story 1-5 (B6): scales the hero's resolved velocity while ATTACKING, uniform across
## windup/active/recovery (per-phase multipliers wait for animations). Scalar, NOT
## tick-domain — never on BalanceTicks. Authored 0.0 = full root (a design value, not a
## missing one — exempt from the >0 authoring audit with that reason).
@export var attack_move_speed_multiplier: float = 0.0

@export_group("Mana")
## Story 1-5 (DEBT D resolved): mana per CONFIRMED melee hit, read inline at the moment
## the hit is confirmed (CONSTRAINT C), gated on the injected
## FeatureFlags.melee_mana_generation. Per-event amount, NOT tick-domain — never on
## BalanceTicks. The flag is the off-switch; a zero amount is a dead flywheel (audited >0).
## NO max_mana here — the mana cap stays the runner's constructor value until story 3-1.
@export var melee_hit_mana: float = 0.0

@export_group("Defense")
@export var block_damage_multiplier: float = 0.0
@export var deflect_window_seconds: float = 0.0
## Story 1-8 (R-D2): full width of the front arc within which a BLOCKING target counts as
## facing the attacker — the gate for BOTH block mitigation and deflect (R-D3). State
## compares the fact's target-to-attacker direction against HeroState.facing within
## +/- half this arc. Scalar degrees, NOT tick-domain — never on BalanceTicks.
@export var block_facing_arc_degrees: float = 0.0

@export_group("Roll")
@export var roll_iframe_seconds: float = 0.0
@export var roll_duration_seconds: float = 0.0
@export var roll_distance: float = 0.0

@export_group("Stun")
## DATA FIELD ONLY. No E1 code path enters STUNNED — attacker-stun-on-deflect is OPEN
## decision (a) in the GDD decision log, and authoring this duration does NOT resolve it.
@export var stun_seconds: float = 0.0
