class_name PlayerState
extends RefCounted

## D1 per-player composite: hero + economy pools + hand. Pure RefCounted. All pools share
## the match SignalQueue so their signals drain together after advance() (D5).

var hero: HeroState
var stamina: StaminaPool
var mana: ManaPool
var orbs: OrbPool          # reserved / flag-off until E5

## Hand of up to 4 cards. RESERVED — populated by the card system in E3.
var hand: Array = []


## Story 3-1 (AC 1/AC 3): constructed STAT-LESS. Every bound below now arrives by injection
## (MatchState._apply_balance_to_player, from the single-source-of-truth BalanceConfig), so
## this constructor carries no tunable and there is no second seeding path that could
## disagree with the injected one. The leaf objects keep their own explicit-bounds
## constructors — they are containers, and their unit tests build them with real bounds —
## but the one production caller hands them zeros and lets injection do the rest.
func _init(queue: SignalQueue) -> void:
	hero = HeroState.new(queue, 0.0, 0.0)
	stamina = StaminaPool.new(queue, 0.0, 0.0)  # filled by the D9 refill at first injection
	mana = ManaPool.new(queue, 0.0, 0.0)        # stays empty — the flywheel builds it
	orbs = OrbPool.new(queue)


func to_snapshot() -> Dictionary:
	return {
		"hero": hero.to_snapshot(),
		"stamina": stamina.to_snapshot(),
		"mana": mana.to_snapshot(),
		"orbs": orbs.to_snapshot(),
		"hand_size": hand.size(),
	}
