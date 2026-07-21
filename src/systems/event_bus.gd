extends Node

## Autoload. Global, OWNERLESS event bus (D5).
##
## Reserved for the small fixed typed set of genuinely global, ownerless events only:
## match_started / round_started / round_ended. Per-entity state changes (hp, stamina,
## mana, orbs) use the OWNING state object's own signals — never this bus.
##
## Signals are declared here when their epic first needs one. None exist yet in E0.
