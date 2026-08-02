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
## Stamina-cost corrective pass (E3-RG/R2; OPEN decision (d) RESOLVED at DP/R2): the basic
## attack's per-swing cost — an ANTI-SPAM lever, not an economy constraint (melee stays the
## 1-5 mana faucet). Charged per SWING, so a chain of N costs N x this. Spent at the step-3
## transition on the roll precedent (entry-time spend, reject-and-fall-through), never at
## landing like deflect. Zero default like every other field: an unauthored cost is a free
## attack, which the authoring audit forbids for the shipped .tres.
@export var attack_stamina_cost: float = 0.0

@export_group("Attack")
@export var attack_windup_seconds: float = 0.0
@export var attack_active_seconds: float = 0.0
@export var attack_recovery_seconds: float = 0.0
@export var attack_chain_window_seconds: float = 0.0
@export var attack_chain_length: int = 0
@export var attack_damage_percent_of_max_hp: float = 0.0
## Story 3-0b (AC5, DEBT E member 2): the per-phase successors to the single flat
## attack_move_speed_multiplier that story 1-5 (B6) shipped "uniform across windup/active/
## recovery (per-phase multipliers wait for animations)". The rig landed in 3-0a, so the
## deferral is paid: each field scales the hero's resolved velocity while ATTACKING during
## ITS OWN phase, selected by HeroState.attack_phase() in _resolve_movement and read inline
## at the moment of use (CONSTRAINT C). The flat field is REMOVED, not kept alongside — a
## half-migration would leave two sources of truth for the same scalar.
## Scalars, NOT tick-domain — never on BalanceTicks. Authored 0.0 = full root (a design
## value, not a missing one — exempt from the >0 authoring audit with that reason); the
## Pass 2 migration authored all three at the flat field's 0.0 so live feel is unchanged
## by the seat itself, leaving the per-phase VALUES to this story's AC8 tuning verdict.
@export var attack_windup_move_speed_multiplier: float = 0.0
@export var attack_active_move_speed_multiplier: float = 0.0
@export var attack_recovery_move_speed_multiplier: float = 0.0
## Story 3-0b (AC6): authored forward lunge DISPLACEMENT for one swing — the sanctioned
## form from the 1-7 close-out ("an authored lunge displacement in balance data, applied by
## the STATE layer as a velocity curve during the swing"), NEVER AnimationPlayer root
## motion (DECISION A / the in-place rule). The state layer derives a speed from it exactly
## the way the roll does (roll_distance / roll_duration_seconds): this distance divided by
## the swing's committed span (windup + active seconds), applied along HeroState.facing
## during WINDUP and ACTIVE only — recovery drift is a separate feel decision and is not
## this field's. Units, NOT tick-domain — never on BalanceTicks.
@export var attack_lunge_distance: float = 0.0

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
