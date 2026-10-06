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

## Story 7-6 (D1, AC 23/AC 25/AC 26) — the FOURTH bus signal: a card EFFECT resolved, as a public fact.
## MatchState owns the SOURCE (`card_cast_resolved`); the RUNNER relays it here after the queued drain, the
## three relays above verbatim. Played effects are public (R6), so both viewports' play-history strips read
## it. Only a NORMAL (mode 1) or PITCH (mode 4) resolution is relayed — the strip's whole admission rule.
##
## THE PAYLOAD IS THE PUBLIC FACT AND NOTHING ELSE (AC 25): which player (`slot`), which effect
## (`effect_id`, the `CardEffect` that ran — never the card id, so no card identity crosses) and whether it
## was the pitch half. No hand content, no mode-2/3 resolution, no orb count.
signal card_effect_resolved(slot: int, effect_id: StringName, is_pitch: bool)

## Story 7-6 (D1, AC 23/AC 25/AC 26) — the FIFTH bus signal: `slot`'s last resolved effect was COUNTERED.
## Relayed from `MatchState.counterspell_resolved(caster_slot, countered_slot)`, carrying the countered
## player only — the Counterspell itself reaches the strip as its own `card_effect_resolved`.
signal card_effect_countered(slot: int)
