class_name CardData
extends Resource

## The card schema (story 3-2, AC 1). Pure data vocabulary — src/state/resources/ holds no
## logic, and nothing in src/state/ reads a CardData yet. Instances are authored as
## data/cards/*.tres and loaded by the CardDatabase autoload (src/systems/card_database.gd);
## the state layer never reaches that autoload, and card data would arrive by INJECTION if a
## later story ever needs it inside the tick loop (AC 5, machine-checked in
## test/state/test_architecture_invariants.gd).
##
## NO DAMAGE FIELD, AND NO UNBLOCKABLE FIELD, EVER (AC 7). Unblockable damage is PER-COLOUR,
## a fixed value in balance — "Full (per-COLOR value, not per-card)", GDD §C — and Modes ②/③
## derive entirely from `color`, carrying no per-card data at all (Novel Pattern 6). A
## per-card damage number would silently create a second, per-card source of truth for a
## value the design says is per-colour. test/state/test_card_authoring.gd fails if any
## property whose name mentions damage or unblockable appears here.
##
## SIX exports where the architecture doc's Novel Pattern 6 sketch lists four (`id` and
## `max_copies` added) — recorded as the SIXTH architecture-amendment-queue member at this
## story's readiness gate; no edit to that doc here.

## Card identity. A FIELD, never the filename — it survives a rename, and it becomes a replay
## contract once the deck story (3-3) makes deck order hash-visible. The filename mirroring it
## is convention only. CardDatabase indexes on THIS.
@export var id: StringName = &""

## First-class colour: which unblockable this card initiates (Mode ②) and which it defends
## (Mode ③). The EXISTING Enums.CardColor, shared with OrbPool — never a second colour enum,
## so a card's colour and its orb/unblockable colour can never drift apart.
@export var color: Enums.CardColor = Enums.CardColor.RED

## Mode ① (Basic): what this card does when cast for mana.
@export var basic_effect: CardEffect

## Mode ④ (Pitch): reserved for E6. Left UNAUTHORED (null) on every card this story ships —
## the pitch mode is not designed yet and its cost side (mana + orbs) is not authored here.
## (Story 6-2 authors the COST side as `pitch_condition` below; this EFFECT field stays null.)
@export var pitch_effect: CardEffect

## What Mode ① costs. Literal per-card content — see CardCastCondition.
@export var cast_condition: CardCastCondition

## Story 6-2 (AC 1, discharging `E6-P/R9`): what Mode ④ COSTS to stage -- the SAME CardCastCondition
## schema `cast_condition` uses, reused verbatim rather than a new Resource type, because the cost
## genuinely differs per mode (GDD's Hellburst: 5 mana + 2 orbs against a 3-mana basic cast) and a
## single shared field could not say so. Its `mana_cost` is paid at staging, its `orb_costs` are the
## READY requirement read afterwards, and its `required_flag` is the flag half of the staging check.
##
## AUTHORED on all nine starter cards, PROVISIONALLY (AC 1a) -- a `.tres` edit retunes it. NULLABLE by
## contract all the same: a card without one is ordinary unauthored pitch content that refuses to
## stage with its own reason, never a load-time crash (AC 2). The EFFECT side, `pitch_effect` above,
## stays unauthored.
@export var pitch_condition: CardCastCondition

## Deck-building cap: how many copies of this card one 20-card deck may hold. PER-CARD DATA,
## not a BalanceConfig field — discharging the obligation 3-1's gate assigned here (its Q1
## rider). The GDD bound is 2-3, "configurable per card in data" (GDD §A, Deck & hand).
@export var max_copies: int = 2
