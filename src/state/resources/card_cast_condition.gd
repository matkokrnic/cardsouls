class_name CardCastCondition
extends Resource

## What playing a card COSTS (story 3-2, AC 2). Pure schema — no logic here, and NO
## EVALUATOR ships beside it: src/state/economy/ is untouched by this story. The first
## consumer is the card-play story (3-5), which designs the evaluator against the WORKING
## EconomyEvaluator 3-4 delivered rather than a hypothetical one — the reason this type was
## stripped out of 3-4's scope back to here (3-4 gate finding B1).
##
## BINDING ON 3-5 (inherited contract, not re-litigated there): whatever evaluates a
## CardCastCondition is pure and static, and it COMPUTES rather than APPLIES — pools apply
## the spend. ManaPool.spend() already returns a bool and changes nothing when unaffordable,
## the same shape EconomyEvaluator.amount_for() uses on the generation side.

## The Mode ① (Basic) price, a LITERAL float.
##
## This is the ONE deliberate break from the ResourceGenerationRule.amount_field mirror, and
## it is deliberate in both directions. A rule names a BalanceConfig field because every
## gameplay number SHARED across the game lives in balance, hot-reloadable through the X3
## seam. A card's price is not shared: it is per-card CONTENT, the thing that distinguishes a
## 2-mana spell from a 5-mana totem. Routing it through balance would mean a BalanceConfig
## field per card. Recorded so a later reader does not "fix" this into a field name.
@export var mana_cost: float = 0.0

## Orbs required, keyed by Enums.CardColor -> count. The SAME enum OrbPool.get_count/add
## switch on, so a cost's colour and an orb's colour are one vocabulary, never two kept in
## sync by hand.
##
## EMPTY on every card this story authors, and that is per the GDD, not an omission: orbs are
## spent "exclusively to pay a Pitch Effect (Mode ④) cost. No other use" (GDD §D), and Mode ①
## is mana-only. The field exists because the pitch mode (E6) is what fills it.
##
## Iteration order over this dictionary is NEVER a contract — if a later story needs an
## ordered read, it sorts explicitly (3-2 gate ruling on card identity and iteration order).
@export var orb_costs: Dictionary[Enums.CardColor, int] = {}

## OPTIONAL FeatureFlags property name gating this cast. Empty = always open. Same shape and
## same reading as ResourceGenerationRule.required_flag — a flag name that cannot be verified
## open reads as CLOSED, the graceful-degradation direction.
@export var required_flag: StringName = &""

## Story 7-4 (AC 1, `7-4/R14`): the PITCH SPEED, meaningful ONLY on a card's `pitch_condition`. The
## Mode ① `cast_condition` shares this schema and the field means nothing there: no reader looks at it
## off a basic condition. Unauthored reads `INSTANT` (the enum's zero value), so a card's speed is one
## edit to its own `.tres` and never a source edit.
##
## CONTENT, NEVER HASHED (ruling 8): it reaches the state layer through the existing `pitch_costs`
## injection (recorded by value) and is READ at read time off `MatchState._pitch_costs[card_id]`,
## never copied into the zone -- the staged card's hashed `card_id` is what selects it.
@export var pitch_speed: Enums.PitchSpeed = Enums.PitchSpeed.INSTANT
