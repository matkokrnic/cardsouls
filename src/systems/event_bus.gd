extends Node

## Autoload. Global, OWNERLESS event bus (D5).
##
## Reserved for the small fixed typed set of genuinely global, ownerless events only:
## match_started / round_started / round_ended. Per-entity state changes (hp, stamina,
## mana, orbs) use the OWNING state object's own signals — never this bus.
##
## Signals are declared here when their epic first needs one.

## Story 1-7 (AC 4.3) — the first EventBus signal. MatchState owns the SOURCE signal
## (state never touches an autoload); the RUNNER relays it here after the queued drain,
## so bus consumers observe it post-advance like every D5 signal. loser_index: 0 = P1,
## 1 = P2. Fires once per DEATH (the debug reset re-arms the round latch, story 1-7 D-1).
signal round_ended(loser_index: int)
