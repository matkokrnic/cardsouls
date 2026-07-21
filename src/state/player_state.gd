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


func _init(
	queue: SignalQueue,
	max_hp: float,
	move_speed: float,
	max_stamina: float,
	max_mana: float,
) -> void:
	hero = HeroState.new(queue, max_hp, move_speed)
	stamina = StaminaPool.new(queue, max_stamina, max_stamina)  # starts full
	mana = ManaPool.new(queue, max_mana, 0.0)                   # starts empty (flywheel)
	orbs = OrbPool.new(queue)


func to_snapshot() -> Dictionary:
	return {
		"hero": hero.to_snapshot(),
		"stamina": stamina.to_snapshot(),
		"mana": mana.to_snapshot(),
		"orbs": orbs.to_snapshot(),
		"hand_size": hand.size(),
	}
