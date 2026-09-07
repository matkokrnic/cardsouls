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

## Story 2-6 (AC 1, 2-6/R5) — the reset counterpart anticipated in this file's header since
## E1. MatchState owns the SOURCE signal (state never touches an autoload); the RUNNER relays
## it here after the queued drain (D5), exactly like round_ended. No-argument and ownerless: a
## debug reset is a whole-match event, not a per-player one. Fires once per debug reset. NO
## prime-on-connect — a consumer must observe an actual reset, never a value synthesized at
## connect time (2-6/R6).
signal round_started()

## Story 3-5b (AC 6) — the THIRD bus signal, and the first one that is not round lifecycle.
## MatchState owns the SOURCE signal (state never touches an autoload); the RUNNER relays it here
## after the queued drain (D5), exactly like the two above. `slot`: 0 = P1, 1 = P2 — the player
## whose discard was just folded back into their deck and who is vulnerable for the authored
## window. Fires once per reshuffle.
##
## OWNER-ONLY FACT ON AN OWNERLESS BUS, and that pairing is deliberate (E3-RG/R3): "P1's deck ran
## out" is a match-wide public event both viewports react to, not a per-entity state change, so
## it belongs here rather than on a per-slot connect_ seam. The runner's connect_* seams (seven
## then, nine as of 5-4/R4) are UNCHANGED by this story — this is not a new one.
signal reshuffle_vulnerable_window_opened(slot: int)
