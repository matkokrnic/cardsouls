---
baseline_commit: ff203d5b43f02eee0f155fc76781aade7cb57506
---

# Story 6.5f: Counterspell

Status: ready-for-dev

<!-- Tier A. Originally authored as the last of six 6-5 sub-stories and E6's close-out story; the
2026-09-29 readiness gate (`C:\dev\_65f-gate.md`, NOT READY -- 2 blockers / 3 major / 6 minor) found the
story too large for one dev pass and the operator's same-day scope talk applied THE CUT: this file (6-5f)
now ships the framework plus six INSTANT-reversal cards (Vanguard, Culling, Grave Ward, Raise Dead, Drain,
Boom); the seven TIMED/in-flight cards (Vampiric Aura, Bloodhound Step, Rocksling, Fireball, Honed Bolt,
Frostbite, Corpse Bomb) move to a new follow-on, `6-5g-counterspell-timed-and-in-flight` (Tier A, backlog,
last on the board), which now closes E6's R-SPELL forcing point in this story's place. This pass applies
every gate finding (adjusted for the cut), restructures the story around the split, and promotes it to
`ready-for-dev`. No code, no suite run. Repo values cited were read at the original authoring pass: golden
98eaee53c065b1c22e5602f5d8c436ea6619c9852752b7f1debaa4695c14a9ff, RecordFile.FORMAT_VERSION 17, the
per-player snapshot key set 43 (test_draw_delay_and_reshuffle.gd's EXPECTED_PLAYER_SNAPSHOT_KEYS). Operator
rulings and gate resolutions are logged as `6-5f/R1`-`R43` in the decision-log session this fix pass adds. -->

## Story

As the operator (and later the friends playtest),
I want Counterspell to reach back and undo the opponent's last resolved card -- reversing what it actually
did rather than merely stopping it -- so that a well-timed Honed Bolt pitch punishes a big spell the moment
it lands. **This story's scope is the framework plus six instant-effect reversals** (Vanguard, Culling,
Grave Ward, Raise Dead, Drain, Boom); the seven timed/in-flight reversals (Vampiric Aura, Bloodhound Step,
Rocksling, Fireball, Honed Bolt, Frostbite, Corpse Bomb) are cut to `6-5g-counterspell-timed-and-in-flight`,
which closes out the whole Deck 1 spell family (6-5a..6-5e) in this story's place.

## Board note

`sprint-status.yaml` key `6-5f-counterspell` moves `backlog -> ready-for-dev` by this pass, after the
gate's blockers and majors were closed below. Depends on `6-5d-fireball-and-spell-targeting` and
`6-5e-rocksling-boom-and-corpse-bomb` (both `done`); those stories' hero-projectile machinery, cast-interrupt
seat and burst-cancellation seat are `6-5g`'s to reverse now, not this story's -- 6-5f only reads the
already-hashed `last_resolved_card` / corpse / mana / hp facts 6-5a/6-5b already ship, plus the Boulder-cover
and Corpse Bomb facts 6-5e's ruling 14/AC 40 recorded. `6-5g-counterspell-timed-and-in-flight` (backlog,
added by this pass, board-ordered immediately after this story, last on the board) is now the LAST of the
6-5 sub-stories and closes E6's R-SPELL forcing point; the playtest / retune block sits after IT.

## Repo-verified facts this story is authored against

Content citations (grep the quoted string / path).

- **Honed Bolt's Counterspell pitch cost matches the prompt exactly -- no discrepancy.**
  `data/cards/honed_bolt.tres`: `color = 1` (BLUE), `pitch_effect` -> `data/effects/counterspell.tres`
  (`effect_id = &"counterspell"`, no other field authored today), `pitch_condition.mana_cost = 4.0`,
  `pitch_condition.orb_costs = {1: 1}` (1 BLUE orb). `data/decks/deck_1.tres`: `copies = [3, 3, 3, 3, 3, 2,
  3]` against `card_ids = [ruin_vanguard, grave_ward, drain, rocksling, bloodhound_step, honed_bolt,
  frostbite]` -- Honed Bolt is the SIXTH entry, copies `2`, confirming "Deck 1 carries this card x2"
  exactly. `docs/planning-artifacts/deck-1-spec.md:36`: `"PITCH Counterspell -- T[4] mana + T[1] blue orb.
  RETROACTIVE: undo the opponent's most recent card (normal or pitch). Exact undo semantics are decided in
  its own story."` -- this story is that story (jointly with 6-5g).
- **`counterspell` is the LAST entry in `DEFERRED_EFFECT_OWNERS`, and this story is its named owner.**
  `src/state/economy/card_effect_resolver.gd:211-213`: `const DEFERRED_EFFECT_OWNERS:
  Dictionary[StringName, StringName] = { &"counterspell": &"6-5f-counterspell" }` -- the comment directly
  above it (`:210`) reads `"ONLY 'counterspell' REMAINS DEFERRED, owned by '6-5f', which is the last of the
  six 6-5 sub-stories."` Removing this row (this story's version of 6-5d's Discrepancy 4 / 6-5e's Task 4,
  the third time the same mechanism runs) is Task 1.
- **`last_resolved_card` is per-player, hashed, and already written at exactly the two APPLY seats a Deck 1
  effect can resolve through.** `src/state/player_state.gd:624-625`: `var last_resolved_card_id: String =
  ""` / `var last_resolved_card_mode: int = NO_RESOLVED_MODE`, written by the one seat
  `record_resolved_card(card_id, mode)` (`:717-720`) and cleared by `clear_resolved_card()` (`:723-729`).
  `record_resolved_card` is called UNCONDITIONALLY at the tail of BOTH `_resolve_basic_cast`
  (`match_state.gd:3972`, `player.record_resolved_card(played, Enums.ModeKind.BASIC)`) and
  `_resolve_pitch_activate` (`match_state.gd:4880`, `player.record_resolved_card(card_id,
  Enums.ModeKind.PITCH)`) -- run for EVERY resolved cast/activation regardless of which arm of the
  cast-vs-apply fork it took. **This is a DISCREPANCY the dev pass must fix, not a fact this story can
  build on unchanged:** `_resolve_basic_cast`'s record-write at `:3972` sits AFTER the cover fork
  (`:3872-3991`) and is NOT gated on `clears_cover` -- so, as the repo stands today, playing (clearing) a
  Boulder DOES overwrite `last_resolved_card` exactly like any other Mode ① press. `6-5f/R7`'s "Boulder
  clear is NOT a played card for Counterspell purposes: never a target, and it does not
  overwrite/shield the previous card" is a required BEHAVIOUR CHANGE to this existing unconditional write,
  not an already-true fact -- named here as AC 8.
- **`clear_resolved_card()` is called at both of the repo's two per-round-scope teardown seats, alongside
  every other 6-5-family reversible fact, on the same tick.** `match_state.gd:7037-7076` (`_end_round`):
  `p1.clear_rules(); p2.clear_rules(); p1.clear_resolved_card(); p2.clear_resolved_card(); ... p1.clear_burst();
  p2.clear_burst(); p1.hand.clear_covers(); p2.hand.clear_covers(); p1.clear_corpse_bomb();
  p2.clear_corpse_bomb();`. The per-player debug-reset seat `_reset_player` (`match_state.gd:7174`) clears
  the identical set at `:7320` `clear_resolved_card()`, `:7333` `hand.clear_covers()`, `:7334`
  `clear_corpse_bomb()`. Whatever new reversal record this story adds joins this SAME teardown list at
  BOTH seats -- not a new seat, the tenth-ish instance of the standing "every per-round reversible fact is
  cleared at exactly these two places" mechanism.
- **The pending-burst schedule (Rocksling) and the Corpse Bomb conversion record are already hashed, exactly
  the shape 6-5e's ruling 14/AC 40 promised.** They are 6-5g's own concern now (Rocksling/Corpse Bomb both
  moved by the cut) -- 6-5f reads neither. **No new hashed field is needed by 6-5f for either fact.**
- **The Boulder-cover mask (`hand_covered`) is already hashed and its writer/reader seats are named.**
  `player_state.gd`'s `hand.gd` cover layer: `cover_at` (`match_state.gd:4370`, called from the Rocksling
  stone landing seat, 6-5g's) and `uncover_at` (`match_state.gd:4298`/`:4318`, called from Boom's per-Boulder
  detonation, 6-5f's, and from a Mode ① Boulder clear). The per-slot mask rides the `hand_covered` snapshot
  key; the covered card's IDENTITY is deliberately NOT hashed. **This story's undo of Boom's own detonation
  needs the covering RECORD -- which slot, and that the cover came from A SPECIFIC LANDED STONE OF A
  SPECIFIC RESOLUTION** -- the existing mask alone answers "is slot N covered right now", not "did THIS
  resolution's Boom detonate a cover at slot N" once other stones have landed since. This is the central
  mechanism question the dev pass owns (Open Question 1): whatever per-resolution undo record it designs
  must be additive to `hand_covered`, `burst`, or `corpse_bomb`, never a redefinition of any of them (AC 2).
- **Cast interruption and burst cancellation are both existing, named seats -- 6-5g's concern, not 6-5f's.**
  `_cast_is_interrupted(player)` and `_advance_bursts` are read only by Rocksling's/Honed Bolt's own
  in-progress-cast reversal, both cut to 6-5g. 6-5f never touches either seat.
- **A one-shot effect's actually-applied amount is ALREADY the returned-value convention this story's
  reversal generalises, not a new one.** `_apply_lifesteal` (`match_state.gd:3161-3165`)'s own docstring:
  `"RETURNS THE HEAL IT ACTUALLY APPLIED (R6: a one-shot effect's delta, clamped by the caster's max hp), SO
  A LATER UNDO HAS SOMETHING TO REVERSE."` -- 6-5a's own review ruling (R6) foresaw exactly this story's
  need. `_funnel_damage` (`match_state.gd:3096-3103`) returns the multiplier-adjusted damage number BEFORE
  it is applied to hp, not the hp delta actually removed -- at 6-5f's own single damage seat (Boom), the dev
  pass reads back the ACTUALLY-REMOVED hp delta, never `_funnel_damage`'s own return (AC 14 binds this at
  Boom's damage refund plus Drain's heal claw-back and Culling's mana claw-back, its only three live seats
  in this story).
- **`_apply_culling` / `_apply_drain` kill WITHOUT damaging** (`6-5b/R4`, restated at
  `match_state.gd:4086-4089`/`:4170-4173`): `UnitBoard.kill_at` is reached directly, with no damage number
  anywhere on that path -- so Culling's kills and Drain's sacrifice are each reversed by RE-ADDING a minion
  record at its pre-kill hp, never by "refunding damage that was never dealt." Their mana/heal side effects
  (Culling's `mana.add`, Drain's `hero.heal`) are the separate, ordinary one-shot reversals AC 15's clamps
  already cover.
- **`SNAPSHOT_ID_PATHS`, `player_state.gd`'s declared-id-path mechanism (6-5e review MAJOR 1), is the
  existing guard any new id-carrying reversal record must extend, not bypass.** A reversal record naming a
  card id (if the dev pass's chosen shape carries one, e.g. for the raised Vanguard's kind) is a NEW
  id-carrying path and must be declared there.
- **Golden and key set (verified at authoring):** `test_determinism.gd` `const GOLDEN :=
  "98eaee53c065b1c22e5602f5d8c436ea6619c9852752b7f1debaa4695c14a9ff"`; `src/systems/record_file.gd`
  `const FORMAT_VERSION := 17`; `EXPECTED_PLAYER_SNAPSHOT_KEYS` in `test_draw_delay_and_reshuffle.gd` has
  **43** keys (alphabetical, includes `burst`, `corpse_bomb`, `hand_covered` added by 6-5e).

## Discrepancies found against the prompt (repo wins) -- one, named above, not blocking

The one discrepancy is the `last_resolved_card` unconditional-write-on-Boulder-clear fact above: the
prompt's ruling ("Boulder clear is not a played card for Counterspell purposes") requires a code change to
`_resolve_basic_cast`'s existing unconditional call, which the story states as AC 8 rather than assuming
already true. No other repo fact contradicts the prompt; every cost figure named ("expected 4 mana + 1 blue
orb") matches exactly.

## Operator rulings of 2026-09-29, carried as behaviour (`6-5f/R1`-`R38`)

Rulings marked **[6-5g]** describe behaviour this story does NOT implement -- carried here as the complete
scope-talk record, implemented by `6-5g-counterspell-timed-and-in-flight` instead. Every unmarked ruling is
binding on 6-5f.

### What Counterspell is

`6-5f/R1` Counterspell is the PITCH effect of Honed Bolt (blue, 4 mana + 1 blue orb activation, matching the
repo exactly). It resolves INSTANTLY on pitch activation, no cast frame -- the same class as Boom and Corpse
Bomb (`6-5e/R17`, C1).
`6-5f/R2` It is RETROACTIVE: it reaches back and cancels the opponent's LAST RESOLVED card, once, at
activation. It is NOT a ward.

### Target selection

`6-5f/R3` The target is the opponent's `last_resolved_card` record at the activation instant: the card id
and mode the standing fields already hold. A REFUSED card never resolved and was never written there.
`6-5f/R4` A `.tres` field `counter_window_seconds` (default `0.0` = no limit) is added, converted to ticks
once at application (A1). Measured FROM the tick the target card RESOLVED. When nonzero and the target is
older than the window, it counts as "no target".
`6-5f/R5` A countered card stops being a target: resolving Counterspell CLEARS the target's reversal record
the instant it reverses it.
`6-5f/R6` Resolving ANY card overwrites that player's `last_resolved_card` -- already true by construction,
letting a player "shield" a big card with a cheap one after it. Intentional, unchanged.
`6-5f/R7` **Boulder clear is NOT a played card for Counterspell purposes:** never itself a target, and does
not overwrite/shield whatever card was `last_resolved_card` before it. Requires
`_resolve_basic_cast`'s `record_resolved_card` write gated on `not clears_cover`.
`6-5f/R8` Counterspell itself is NOT a valid target: after a player resolves it, THEIR OWN
`last_resolved_card` names Counterspell, refused as a target under the ordinary overwrite rule (`6-5f/R6`)
-- no special-case code.
`6-5f/R9` The countered player gets nothing back: their card, mana and orb stay spent. Only the effects the
countered card itself produced are reversed.

### No-target -> refusal

`6-5f/R10` Activation is refused BEFORE the orb is spent, through the same board-gate seat every other
no-target Deck 1 effect uses; staging mana already spent is NOT refunded.
`6-5f/R11` "No target" covers: no card resolved yet this round; the last resolved card is Counterspell
itself; the last card is older than a nonzero `counter_window_seconds`; everything the last card did has
already fully expired or is gone (e.g. a summoned Vanguard already dead with its corpse expired, or a
Grave Ward whose every touched corpse has already naturally expired -- see also `6-5f/R37`'s interim rule
for the seven 6-5g cards).

### Reversal rule -- two classes

`6-5f/R12` INSTANT events (damage, heal, mana gain, summon, corpse changes, Boulder placement/detonation)
are REVERSED by the amount ACTUALLY APPLIED as recorded at the moment it happened, never the nominal
authored number.
`6-5f/R13` **[6-5g]** TIMED buffs are ENDED NOW through `cancel_rule`; what they already yielded STAYS.
`6-5f/R14` Clamps: HP claw-back never below 1 (a counter never kills); mana claw-back stops at 0; HP refund
stops at the caster's own current max.
`6-5f/R15` Reverse what is LEFT, not what was nominal: a part already gone has nothing left to reverse and
is skipped silently, not refused.

### Per-card reversal

`6-5f/R16` **Vanguard:** the summoned minion vanishes without a corpse either way.
`6-5f/R17` **Culling:** the minions it killed rise again from their own corpses, restored to their kind's
normal live-record shape (AC 23); the mana gained is taken back, clamped at 0.
`6-5f/R18` **Grave Ward:** the lifetime extension it added is removed from every corpse it touched; a corpse
whose remaining time is then `<= 0` disappears immediately.
`6-5f/R19` **Raise Dead:** the minions it raised vanish, with no corpse; their ORIGINAL corpses return, each
with the remaining lifetime it would have had, EXCEPT one that would already have naturally expired.
`6-5f/R20` **Drain:** the sacrificed minion rises again from its own corpse; the hp it healed is taken back,
clamped at 1.
`6-5f/R21` **[6-5g] Vampiric Aura:** ends now; already-healed hp stays.
`6-5f/R22` **[6-5g] Rocksling:** cast-in-progress interrupted and caster freed; unfired stones cancelled; an
in-flight stone vanishes; landed-stone damage refunded; still-covering Boulders removed.
`6-5f/R23` **Boom:** the damage it dealt is refunded; the Boulders IT detonated return to the victim's hand,
in the SAME slots they occupied, covering the same underlying cards again.
`6-5f/R24` **[6-5g] Bloodhound Step:** ends now.
`6-5f/R25` **[6-5g] Fireball:** in-flight vanishes; landed damage refunded; staged mana NOT refunded.
`6-5f/R26` **[6-5g] Honed Bolt:** cast-in-progress interrupted and caster freed (third trigger at
`_cast_is_interrupted`); landed damage refunded; any running stun/root ends immediately.
`6-5f/R27` **[6-5g] Frostbite:** unconsumed armed trigger removed; a consumed trigger's resulting slow ends
now.
`6-5f/R28` **[6-5g] Corpse Bomb:** in-flight skulls vanish; landed damage refunded; converted minions rise
per the general restore rule (AC 23).
`6-5f/R29` **Restored minion, general rule (Culling / Drain, and 6-5g's Corpse Bomb):** rises from its own
corpse at the hp it had immediately before death; the corpse is consumed; a corpse already gone means the
minion is NOT restored.

### Cancel-path mechanics

`6-5f/R30` **[6-5g]** Interrupted cast / cancelled burst is a NEW cancel path beside the existing ones, a
third trigger at `_cast_is_interrupted` and `_advance_bursts`, reached from Counterspell's own resolution.

### Browser decisions (2026-09-29, closing gate B1/B2)

`6-5f/R31` The resolution tick is recorded at both apply seats alongside `last_resolved_card_id`/`_mode`,
hashed as the THIRD member of the existing `last_resolved_card` snapshot array (key count unchanged),
cleared by `clear_resolved_card()` at both teardown seats; its own isolable golden cause. Closes gate B1.
(AC 5)
`6-5f/R32` A restored minion's pre-death hp is a NEW hashed field, its own golden cause. (AC 23)
`6-5f/R33` A test asserts the interrupted caster does not enter STUNNED -- lands in 6-5g; 6-5f's break table
carries `test_action_state.gd`'s STUNNED entry-point census as regression-only.
`6-5f/R34` Live smoke runs at the authored default window `0.0`; `counter_window_seconds > 0` is unit-test-
only.
`6-5f/R35` No refusal cue of any kind, beyond the existing refusal channel. (AC 26)

### The cut

`6-5f/R36` THE CUT (operator's standing fallback, triggered by the gate's size verdict, cut BY CARD): 6-5f
keeps the framework and the SIX instant cards named above; `6-5g-counterspell-timed-and-in-flight` (Tier A,
backlog, last on the board) takes the SEVEN timed/in-flight cards (`6-5f/R21`, `R22`, `R24`-`R28`, `R30`)
plus the not-stunned test and its smoke points.
`6-5f/R37` INTERIM RULE in 6-5f, removed by 6-5g: a Counterspell targeting a resolution one of the seven
6-5g cards produced is refused as "no target" through the existing refusal path -- no new refusal reason.
(AC 13)
`6-5f/R38` Bloodlust is removed from every timed-buff list in this story and in `deck-1-spec.md` -- it is
unreachable in Deck 1 (Fireball replaced it as Bloodhound Step's pitch, `deck-1-spec.md`'s 2026-09-22
amendment); its reversal is covered by construction, not by a test case.

## Acceptance Criteria

### Data

1. Counterspell's effect data (`data/effects/counterspell.tres`) authors, as a flat `CardEffect` field,
   `counter_window_seconds` (default `0.0`), converted to ticks once at application (A1). No other new
   `CardEffect` field is predicted for Counterspell itself; the reversal RECORDS it reads live on the
   opponent's already-hashed 6-5a/6-5b/6-5e state.
2. Every reversal record this story needs beyond what 6-5a/6-5b/6-5e already hash (the per-resolution "what
   did this card actually do, in enough detail to undo it" fact, for the six kept cards) is authored as new
   hashed cross-tick state, in a shape the dev pass designs (Open Question 1). It must be ADDITIVE to
   `hand_covered`, `burst`, and `corpse_bomb`, never a redefinition of any of them. No number this story
   introduces (`counter_window_seconds`) is a literal in `src/`.
3. Every new `CardEffect` field's default leaves every other authored effect's behaviour bit-identical.

### Target selection and window

4. Counterspell targets the opponent's `last_resolved_card_id` / `last_resolved_card_mode` at the activation
   instant; a card that was REFUSED (never wrote `last_resolved_card`) is never a target.
5. A resolution tick is recorded at both apply seats (`_resolve_basic_cast`, `_resolve_pitch_activate`)
   alongside `last_resolved_card_id`/`last_resolved_card_mode`, hashed as the THIRD member of the existing
   `last_resolved_card` snapshot array (`[id, mode, tick]`) -- the per-player snapshot KEY COUNT stays 43.
   Cleared by `clear_resolved_card()` at both existing teardown seats, the same tick as the id/mode it rides
   alongside. (`6-5f/R31`)
6. With `counter_window_seconds == 0.0` (default), any resolved card is a valid target regardless of how
   long ago it resolved, as long as it has not since been overwritten (`6-5f/R6`) or already countered
   (`6-5f/R5`).
7. With `counter_window_seconds > 0.0`, a target whose resolution tick (AC 5) is older than the window
   (measured to Counterspell's own activation tick) counts as "no target" and refusal (AC 11-12) applies --
   proven with a case just inside the window (still valid) and just outside it (refused).
8. **Boulder clear (a Mode ① press on a Boulder card) does NOT write `last_resolved_card`** --
   `_resolve_basic_cast`'s unconditional write is gated on `not clears_cover`, matching the existing gate on
   the owed-replacement write two lines below it. Proven: a Boulder clear immediately after a real resolved
   card leaves `last_resolved_card` unchanged; Counterspell fired right after a Boulder clear still reaches
   the real card. (`6-5f/R7`)
9. Resolving Counterspell writes the CASTER's own `last_resolved_card` to name Counterspell, on the ordinary
   unconditional write (`6-5f/R6`/`R8`) -- no special-case code. The proven refusal case: Counterspell fired
   at a player whose OWN last resolved card is Counterspell (i.e., that player just countered) is refused as
   "no target" for the SECOND player's Counterspell.
10. A card already countered once cannot be targeted again by a second Counterspell copy: the reversal
    record that made it a target is cleared the instant the first Counterspell reverses it (`6-5f/R5`), so
    the second copy reads "no target" and is refused.

### No-target refusal

11. Activation with a "no target" opponent state (AC 7 outside window, AC 9/10's cases, AC 13's interim
    case, or an opponent who has resolved no card yet this round) is refused through the SAME board-gate
    no-target pattern 6-5b/6-5e already use (a named reason distinct from every existing one), BEFORE the
    orb spend: the card stays READY in the pitch zone, its fizzle countdown continues, and the staging mana
    already spent is not refunded.
12. "Everything the last card did has already expired or is gone" (`6-5f/R11`'s fourth clause) is its own
    refusal case, proven for at least: a summoned Vanguard that is dead with its corpse already expired, and
    a Grave Ward whose every touched corpse has already naturally expired by the activation instant.
13. **INTERIM RULE, removed when `6-5g-counterspell-timed-and-in-flight` ships:** if the opponent's
    `last_resolved_card` names one of the seven cards deferred to 6-5g (Vampiric Aura, Bloodhound Step,
    Rocksling, Fireball, Honed Bolt, Frostbite, Corpse Bomb), activation is refused as "no target" through
    the SAME refusal path as AC 11-12 -- no new refusal reason. Proven with at least a resolved Honed Bolt
    as the target. (`6-5f/R37`)

### Reversal -- instant vs timed, clamps

14. An INSTANT effect (damage, heal, mana gain, summon, corpse change, Boulder placement/detonation) is
    reversed by the AMOUNT ACTUALLY APPLIED as recorded at the moment it happened, never the nominal
    authored number -- proven with at least one case where the applied amount was CLAMPED below nominal (a
    mana grant that hit the pool cap) and the reversal claws back only the clamped amount. This binds every
    refund/claw-back seat 6-5f ships: Boom's damage refund, Drain's heal claw-back, and Culling's mana
    claw-back each reverse their own recorded POST-APPLICATION delta, never `_funnel_damage`'s pre-
    application return.
15. HP claw-back is clamped at a floor of 1 (a counter never kills); mana claw-back is clamped at a floor of
    0; HP refund is clamped at the caster's current max hp (never overheals) -- each clamp proven with an
    explicit case that would otherwise cross the floor/ceiling (Drain for the HP floor, Culling for the mana
    floor, Boom for the HP-refund ceiling).
16. A partial product still present at the moment Counterspell resolves is reversed only for the part still
    present -- proven with Raise Dead's own case (AC 19): one raised minion's original corpse would already
    have naturally expired by now and does not return, while another minion's still does.

### Per-card reversal

17. Countering a resolved Vanguard summon: the minion vanishes with NO corpse, whether it is still alive or
    has already died and left one.
18. Countering a resolved Culling: every minion it killed rises from its own corpse restored to its kind's
    normal live shape (AC 23's general restore rule); the mana it granted is taken back, clamped at 0.
19. Countering a resolved Grave Ward: its extension is removed from every corpse it touched; any corpse
    whose remaining time is then `<= 0` disappears on this same tick.
20. Countering a resolved Raise Dead: every minion it raised vanishes with no corpse; each one's ORIGINAL
    corpse returns with the remaining lifetime it would have had, EXCEPT one that would already have
    naturally expired by now, which does not return.
21. Countering a resolved Drain: the sacrificed minion rises from its own corpse; the hp it healed is taken
    back, clamped at floor 1.
22. Countering a resolved Boom: the damage it dealt is refunded; every Boulder it detonated returns to the
    victim's hand IN THE SAME SLOTS it occupied before detonation, covering the same underlying cards again.
23. **General restoration rule, proven once and reused by AC 18/21 (and by 6-5g's Corpse Bomb):** a minion
    restored by a Counterspell reversal enters at the hp it had immediately before its death (a NEW hashed
    fact, `6-5f/R32`), its original corpse is consumed by the restoration, and a corpse already gone
    (naturally expired) means that minion is NOT restored.

### Shared / regression

24. Nothing in this story adds a second `_physics_process`, reads `Input.*` outside `src/controllers/`, or
    introduces a nondeterministic source inside `src/state/` (`test_architecture_invariants.gd` stays
    green); Counterspell's own resolution consumes NO RNG.
25. Every 6-5a/6-5b/6-5c/6-5d/6-5e behaviour not named above is unchanged when Counterspell is not in play:
    every card still resolves, every buff still applies, Rocksling/Boom/Corpse Bomb still work exactly as
    6-5e shipped them (their own Counterspell-reversal is 6-5g's, but their ORDINARY behaviour is 6-5f's
    regression surface).
26. A placeholder cue (a sign + a sound stub) plays on both heroes when Counterspell resolves against a real
    target, on the same standard as the 6-5c/6-5d/6-5e placeholders; a refusal (including the AC 13 interim
    refusal) plays NO cue of any kind beyond the existing refusal channel. HUD is otherwise unchanged; real
    visuals are owed to the Tier B presentation story scheduled after 6-5g closes E6. (`6-5f/R35`)
27. `DEFERRED_EFFECT_OWNERS` no longer names `counterspell`; the table is EMPTY (the pin in
    `test_spell_framework.gd` moves from 1 to 0).

### Determinism, replay, format

28. Every new cross-tick fact this story creates (the resolution tick, the per-resolution reversal record,
    the restored-minion pre-death hp) is snapshotted and hashed, or is a pure function of hashed facts
    (argued in Dev Notes if so). The reversal record for whatever card is currently the target is CLEARED at
    both existing teardown seats (`_end_round`, `_reset_player`) and per-resolution the instant Counterspell
    reverses it (`6-5f/R5`), not only at round end.
29. `RecordFile.FORMAT_VERSION` PREDICTED to move 17 -> 18 with a HARD refusal of a v17 file; measured, not
    assumed, and recorded if the prediction is wrong.
30. A recorded match containing a Counterspell that reverses a Boom (HP and Boulders restored) AND a
    Counterspell that reverses a Culling (minions and mana restored) replays to the identical final hash and
    the identical record (`test_replay_identity.gd`'s standing discipline).

## Deferred to 6-5g (`6-5g-counterspell-timed-and-in-flight`)

Each line is its own per-card reversal case, moved whole by THE CUT (`6-5f/R36`). 6-5f neither implements
nor tests any of these; the interim rule (AC 13) refuses Counterspell against any of them until 6-5g ships.

- Vampiric Aura -- ends now, already-healed hp stays (`6-5f/R21`).
- Bloodhound Step -- ends now (`6-5f/R24`).
- Rocksling -- cast-interrupt, burst-cancel, in-flight vanish, landed-damage refund, still-covering-Boulder
  removal, and the partial-burst proof case (`6-5f/R22`).
- Fireball -- in-flight vanish / landed-damage refund, staged mana never refunded (`6-5f/R25`).
- Honed Bolt -- cast-interrupt third trigger, landed-damage refund, running stun/root ends now (`6-5f/R26`).
- Frostbite -- unconsumed-trigger removal, consumed-trigger slow ends now (`6-5f/R27`).
- Corpse Bomb -- in-flight skull vanish, landed-damage refund, restore via 6-5f's general rule (AC 23,
  `6-5f/R28`).
- The general TIMED-buff end-now-keep-yielded rule (`6-5f/R13`), shared by Vampiric Aura, Bloodhound Step,
  Frostbite and Honed Bolt's stun/root.
- The cast-interrupt/burst-cancel third-trigger mechanics at `_cast_is_interrupted`/`_advance_bursts`
  (`6-5f/R30`), needed only by Rocksling and Honed Bolt.
- A test asserting the interrupted caster does not enter STUNNED (`6-5f/R33`).
- Live smoke points: counter a Honed Bolt mid-root, counter a Rocksling mid-burst, counter an in-flight
  Fireball, counter a Corpse Bomb with skulls in flight.

## Non-Goals

- Any redo mechanism, counter-on-counter, or a second layer of Counterspell resolving against a
  Counterspell (`6-5f/R8`, AC 9/10).
- Any change to Honed Bolt's normal mode, or to any card's prices, beyond Counterspell's own confirmed-
  matching cost.
- Any new orb rule.
- Real art, VFX, clips or audio for Counterspell's cue -- placeholder only, owed to the Tier B presentation
  story after 6-5g closes E6.
- Any change to melee, unblockables, the colour counter, roll, stamina, Deck 2, hand size, deck size, or
  `max_mana`.
- The seven 6-5g cards' Counterspell reversal (see Deferred to 6-5g above) -- not built here.

## Golden Prediction (predictions to MEASURE, not claims)

Baseline to measure and save outside the repo BEFORE any edit: golden
`98eaee53c065b1c22e5602f5d8c436ea6619c9852752b7f1debaa4695c14a9ff`, `RecordFile.FORMAT_VERSION` 17,
per-player snapshot keys 43, the hand/pitch/burst/corpse_bomb snapshot shapes, suite (state + integration
counts) -- re-measure at the dev pass; do not trust any figure in this file.

**PREDICTED to MOVE.** Causes to be separated and measured each in isolation (the 6-5a..6-5e method: erase
the new keys/fields from `to_snapshot()` with every other change in place; the hash must return to the
baseline exactly):

1. **The resolution tick** (AC 5, `6-5f/R31`): a third array member on the existing `last_resolved_card`
   key -- the per-player KEY COUNT stays 43; only the array's own shape changes. Measure this cause
   separately from cause 2 below (a key-count mover would be a different, wrong shape).
2. **Whatever per-resolution reversal record the dev pass's mechanism needs** for the six kept cards, plus
   the restored-minion pre-death hp (AC 23, `6-5f/R32`) if it is not folded into the same record. At rest
   (nothing yet resolved) it must read as the current snapshot unchanged -- measure the resting-empty case
   as its own sub-cause.
3. **`_resolve_basic_cast`'s `record_resolved_card` write gated on `not clears_cover`** (AC 8): a BEHAVIOUR
   mover, not a shape mover -- the fixture's resting hash should be unaffected (no Boulder clear in the
   golden's own recorded sequence, argued as a non-cause and measured) but the CODE change itself is worth
   its own isolation pass to confirm.
4. **Which pins move** (predicted, not claimed): `EXPECTED_PLAYER_SNAPSHOT_KEYS` (43) in
   `test_draw_delay_and_reshuffle.gd` and `test_card_observation.gd`'s copy, IF the reversal record (cause 2)
   is a NEW KEY rather than an extension of an existing one -- the resolution tick (cause 1) is NOT this
   cause, since it never adds a key.
5. **New refusable outcomes.** Counterspell's own no-target board-gate refusal AND the AC 13 interim refusal
   are both NEW predicted causes under the standing `SC/R6` boundary (a pressed action made refusable moves
   the golden if the recorded sequence presses it) -- measured, not assumed a non-cause.
6. **Non-causes to confirm (`BC/R3`):** `counter_window_seconds`'s own authored value -- the golden builds
   its effects in-test and never loads `data/effects/`; confirm the injection SHAPE (the one new `CardEffect`
   field) does or does not move the hash apart from cause 1.
7. **`FORMAT_VERSION` PREDICTED 17 -> 18** (AC 29). Measured, not assumed.
8. **Intake:** none predicted -- Counterspell's target is derived state (the opponent's already-hashed
   `last_resolved_card`), not a new intent field; no new controller-read channel.

**Measure, do not assume:** full suite before any edit and after, golden hash / key counts / FORMAT_VERSION
in both runs, files saved outside the repo. The number of re-baselines is NOT predicted in advance; report
the actual count and separate every cause exactly as done above.

## Live Smoke (operator, two pads, flip config `[3,3]`)

Flip `slot_controller_kinds = Array[int]([3, 3])` (two gamepads: two killable, human-driven slots). A
countered Boom refund and a countered Culling restore both change live-observable state (hp, minion count,
mana), and a live Boom activation itself can kill, so **R-D6 is RE-INVOKED for this story** (its acceptance
is spent on use and re-invoked per story against a killable human-driven slot: decision-log `R-D6` entries,
`2-1/R2`, `6-1c/R4`). The binding editor-collateral procedure (`6-1c/R4`), restated verbatim as
`6-5b`/`6-5c`/`6-5d`/`6-5e` did:

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins -- not earlier in
  the session.

1. **Counter a Boom.** Let a Boom detonate at least one Boulder against you, then pitch and activate
   Counterspell before the opponent plays another card: your HP and the detonated Boulder(s) are restored
   (HP back up, Boulder(s) back in your hand, covering the same cards).
2. **Counter a Vanguard.** Counterspell a resolved Ruin Vanguard: the summoned minion is gone, no corpse.
3. **Counter a Culling.** Counterspell a resolved Culling: every minion it killed rises again, and the mana
   it granted is clawed back.
4. **Refusal with no target.** Pitch and try to activate Counterspell when the opponent has resolved no
   card this round: activation is refused, the card stays staged and its countdown continues.
5. **Second copy vs an already-countered card.** With Honed Bolt's two copies, counter the same opposing
   card twice in a row: the second activation is refused as no-target.
6. **Interim refusal on a Honed Bolt.** With the opponent's last resolved card a Honed Bolt (a 6-5g card),
   pitch and activate Counterspell against it: refused as no-target (AC 13), no new refusal cue.
7. **R-D6 re-invocation.** A round ends normally after a Counterspell resolves (whether the countered player
   or someone else takes the killing blow): no leftover reversal-record state carries into the next round.
8. **Placeholder cue.** Counterspell resolving against a real target shows its sign-and-sound placeholder on
   both heroes, visually/audibly distinct from every other 6-5 placeholder cue; no cue of any kind on either
   refusal case (4, 6).
9. **Regression.** Every other 6-5a..6-5e behaviour (Vanguard, Culling, Grave Ward, Raise Dead, Drain,
   Vampiric Aura, Bloodhound Step, Fireball, Rocksling, Boom, Corpse Bomb, the Boulder mechanic and slow) is
   unaffected when Counterspell is never played; no crash, no assert.

**Target: report actual PASS/FAIL counts on two pads, flip config `[3, 3]`, R-D6 result -- not run by this
create pass.**

## Tasks / Subtasks

- [ ] **Task 1: Baseline (before any edit).** Save outside the repo: suite counts, golden, FORMAT_VERSION,
  per-player key count (43), hand/pitch/burst/corpse_bomb snapshot shapes, `git rev-parse HEAD`. (AC 28-30)
- [ ] **Task 2: Data.** Author `counter_window_seconds` (default `0.0`) on `data/effects/counterspell.tres`.
  Add Counterspell's outcome row to `CardEffectResolver` (a new `OUTCOME_COUNTERSPELL`, on the
  Boom/Corpse-Bomb "no cast frame" precedent, `6-5e/R17`/C1) and remove its row from
  `DEFERRED_EFFECT_OWNERS`, which then goes EMPTY. (AC 1, 27)
- [ ] **Task 3: `last_resolved_card` fix (AC 8).** Gate `_resolve_basic_cast`'s
  `record_resolved_card(played, Enums.ModeKind.BASIC)` write on `not clears_cover`, mirroring the existing
  `if not clears_cover:` gate two lines below it; confirm `_resolve_pitch_activate` needs no equivalent gate
  (no pitch effect takes the cover arm, per 6-5e ruling 7). (AC 8)
- [ ] **Task 4: Target resolution.** Read the opponent's `last_resolved_card_id`/`_mode`/tick at Counterspell
  activation; add the resolution tick to the `last_resolved_card` array (AC 5); apply
  `counter_window_seconds` as a maximum-age test; treat Counterspell-as-target and an
  exhausted/reversed/nonexistent target as "no target"; wire the no-target case (including the AC 13
  interim case) into the existing pre-spend board-gate seat with its own named refusal reason. Resolve Open
  Question 1 (the reversal record's shape) here. (AC 4-13)
- [ ] **Task 5: Per-effect reversal (six kept cards only).** Implement the per-card reversal table
  (`6-5f/R16`-`R20`, `R23`, `R29` / AC 17-23): instant-effect amount-actually-applied claw-back with the
  three clamps (AC 14-15); the general minion-restore rule shared by Culling/Drain (AC 23); Grave Ward's
  extension removal with the now-expired-disappears-immediately clause (AC 19); Raise Dead's
  corpse-return-with-remaining-lifetime rule (AC 20); Boom's damage refund + same-slot Boulder restoration
  (AC 22); Vanguard's no-corpse vanish (AC 17). No `_cast_is_interrupted`/`_advance_bursts` code is touched
  by this task -- that is 6-5g's.
- [ ] **Task 6: Interim refusal.** Wire the AC 13 interim rule: if the opponent's `last_resolved_card` names
  a resolution one of the seven 6-5g cards produced, refuse as "no target" through the same path Task 4
  built, no new refusal reason. (AC 13, `6-5f/R37`)
- [ ] **Task 7: Reversal-record teardown.** Whatever new hashed reversal record Task 4 introduces is cleared
  at BOTH existing per-round teardown seats (`_end_round`, `_reset_player`), alongside `clear_resolved_card`/
  `clear_burst`/`hand.clear_covers`/`clear_corpse_bomb`, AND is cleared per-resolution the instant
  Counterspell reverses that resolution. (AC 28)
- [ ] **Task 8: Presentation minimum.** Placeholder sign-and-sound cue on both heroes on a real Counterspell
  resolution, visually/audibly distinct from every other 6-5 placeholder; no cue on either refusal case. (AC
  26)
- [ ] **Task 9: Tests.** New: `test_counterspell.gd` or equivalent covering AC 4-23; the placeholder cue
  test; the `last_resolved_card`/Boulder-clear fix test (AC 8); replay identity (AC 30) on the real record
  path; the authoring audit extension (AC 2); `test_spell_framework.gd`'s `DEFERRED_EFFECT_OWNERS` pin moving
  to empty (AC 27). Update the table below with actual filenames used. Mutation proofs restore from a copy
  outside the repo, SHA256-verified first.
- [ ] **Task 10: Golden.** Isolate causes 1-5 (and any the dev pass finds) by erasing new keys/fields with
  every other change in place; confirm non-causes; record the actual re-baseline count; `FORMAT_VERSION` 18
  predicted, confirm or correct.
- [ ] **Task 11: Close.** Second full suite run, invariants green, `git diff --stat`, Dev Agent Record. The
  decision-log close-out (session name: this story's own) and the board promotion to `done` are the
  operator's gate, after live smoke.

## Tests expected to break or need updating

Found by reading the named files at authoring; the dev pass confirms and updates this table with actual
outcomes.

| Test | Why it is expected to move |
|---|---|
| `test_spell_framework.gd` (`DEFERRED_EFFECT_OWNERS`, size pin) | `counterspell` leaves the deferred table, which goes EMPTY -- confirmed at authoring `test_spell_framework.gd:130` asserts size 1; moves to 0 |
| `test_card_effect_resolution.gd` | Counterspell's new resolver outcome row and apply arm; `SNAPSHOT_ID_PATHS`'s declared-id-path scan if the reversal record carries any id |
| `test_spell_framework.gd:311` (`test_the_last_resolved_card_is_recorded_at_the_basic_seat`), `test_hero_cast.gd:135`, `test_fireball.gd:196` | the real pins on the `record_resolved_card` basic seat -- the `not clears_cover` gate (AC 8) is a behaviour change to this existing, tested seat |
| `test_draw_delay_and_reshuffle.gd` (`EXPECTED_PLAYER_SNAPSHOT_KEYS`) and `test_card_observation.gd`'s copy | predicted to move 43 -> 44+ only if the reversal record (Golden Prediction cause 2) is a new key; the resolution tick (cause 1) does not move this pin |
| `test_own_minion_spells.gd` | Culling/Drain/Raise Dead/Grave Ward regression against their own new reversal paths (AC 18-20) |
| `test_rocksling_and_boulder.gd` | Boom's own reversal only (AC 22): damage refund + same-slot Boulder restoration. Rocksling's and Corpse Bomb's own reversal in this file is 6-5g's |
| `test_spell_targeting.gd` | regression-only: confirm Counterspell's own target read does not disturb the shared spell-targeting machinery |
| `test_corpses.gd` (the death-seat caller-count pin) | if a reversal-restore path reaches a NEW caller of the corpse-creation/consumption seats rather than reusing an existing one, the caller count moves again |
| `test_action_state.gd` (the STUNNED entry-point census) | regression-only: the count must NOT move -- 6-5f adds no third trigger at any STUNNED entry point; the not-stunned test itself is 6-5g's (`6-5f/R33`) |
| `test_determinism.gd` | golden re-baseline (count not predicted in advance) |
| `test_record_file.gd`, `test_replay_identity.gd` | `FORMAT_VERSION` 17 -> 18 predicted; new content round-trip (a countered resolution's reversal record) |
| `test_intent_recorder.gd` | only if a new intake channel is added (predicted: none) |
| `test_architecture_invariants.gd` | regression-only: confirm F1/D3/A2 still hold |
| `test_pitch_staging.gd`, `test_pitch_changed.gd` | Counterspell activation now does real work instead of the shared deferred no-op; the new no-target refusal reason (and the AC 13 interim case) needs coverage alongside Boom's/Corpse Bomb's own (6-5e precedent) |

## Dev Notes

- **Open Question 1 (the reversal record's shape) is the central mechanism decision of this story,
  deliberately left to the dev pass** on the same "write behaviour, not mechanism" discipline 6-5e's Boulder
  cover mechanism was left to its own dev pass. The behaviour is fully fixed by `6-5f/R1`-`R20`, `R23`, `R29`
  / AC 4-23; what is NOT fixed is HOW "the amount actually applied, per landed effect, per resolution" is
  recorded for the six kept cards so that it (a) survives to the moment Counterspell activates, (b) is
  per-resolution rather than per-effect-type, and (c) is cleared exactly when `6-5f/R5` requires. It must
  also carry the restored-minion pre-death hp (AC 23, `6-5f/R32`) and the resolution tick (AC 5, `6-5f/R31`
  -- though the tick may equally ride directly on `last_resolved_card` rather than the undo-packet, per its
  own AC's wording). Whatever is chosen must NOT redefine `hand_covered`, `burst`, or `corpse_bomb` (AC 2).
  - **Deliberate leaning, argued but not locked:** wiring the undo packet at the SAME write site as
    `record_resolved_card` keeps `6-5f/R6` ("resolving overwrites") and `6-5f/R5` ("countering clears it") as
    ONE overwrite semantic rather than two things that could drift -- worth trying first, correct if a case
    argues otherwise.
- **Why `_apply_lifesteal`'s R6 return-value precedent matters:** it is 6-5a's own foreshadowing of this
  exact story ("so a later undo has something to reverse"), which is why AC 14's "amount actually applied,
  never nominal" is not a new idea -- it is the ALREADY-ESTABLISHED discipline for a one-shot effect,
  generalised from lifesteal to Boom's damage seat, the only damage seat 6-5f itself reverses.
  `_funnel_damage`'s own return is the PRE-application multiplier-adjusted number, not the post-application
  delta -- the dev pass reads the hp pool's own before/after delta at Boom's seat, the same measurement
  `_apply_lifesteal`'s caller already performs for its `removed` argument.
- **Why a restored minion enters at its pre-death hp, not its kind's max hp or a nominal heal:** `6-5f/R29`
  mirrors Raise Dead's own existing seat (`_apply_raise_dead`, which restores at `kind.max_hp *
  raise_hp_percent / 100.0` -- a DIFFERENT number, because Raise Dead revives a CORPSE from scratch, not
  undoing a kill this story just watched happen). Counterspell's restore is narrower and more honest: it
  puts back exactly what was there a moment ago, which is why it needs its own hp-at-death fact.
- **Why Boulder restoration from a countered Boom is "same slots, as if never played" rather than "stays
  destroyed":** the operator's explicit choice, matching 6-5e's own precedent for Boom's own "as if that
  Boulder had been played" uncover wording -- Counterspell's reversal of Boom is symmetric with Boom's own
  resolution, just run backward.
- **Why the seven timed/in-flight cards are 6-5g, not 6-5f (gate size verdict + `6-5f/R36`):** they are
  exactly the set that touches `cancel_rule`, `_cast_is_interrupted`, `_advance_bursts`, in-flight
  projectiles and burst schedules -- three seats 6-5f never has to open. The interim refusal (AC 13,
  `6-5f/R37`) keeps Counterspell's own behaviour correct (never silently does nothing without a signal) in
  the gap between the two stories.
- **AC 14's binding of "actually applied" to specific seats (gate M3):** Boom's damage refund, Drain's heal
  claw-back, and Culling's mana claw-back are 6-5f's only three refund/claw-back seats; each must reverse
  its own recorded post-application delta, never `_funnel_damage`'s pre-application return.
- **Order at activation** stays the 6-2/6-3a/6-5d/6-5e precedent: gates -> board gate (the no-target refusal,
  including the AC 13 interim case) -> orb spend -> discard -> `pitch.clear` -> apply (the reversal) ->
  resolved-card record (which now names Counterspell itself, `6-5f/R8`) -> replacement owed at activation.
- **Counterspell's own mana cost (4) and orb cost (1 blue) are `.tres` fields already authored** on
  `honed_bolt.tres`'s `pitch_condition` -- confirmed matching the repo, no change.
- **Read first** (UPDATE files): `match_state.gd` (`_resolve_pitch_activate`, `_resolve_basic_cast`,
  `_apply_card_effect` and its per-effect helpers `_apply_culling`/`_apply_grave_ward`/`_apply_raise_dead`/
  `_apply_drain`/`_apply_boom`, `_funnel_damage`, `_apply_lifesteal`, `_end_round`, `_reset_player`, the
  snapshot), `player_state.gd` (`record_resolved_card`, `clear_resolved_card`, the burst/corpse_bomb fields
  read-only), `hand.gd` (`uncover_at`, `clear_covers`), `card_effect.gd`, `card_effect_resolver.gd`
  (`DEFERRED_EFFECT_OWNERS`, `CAST_OUTCOMES`, `clears_cover`, `outcome`), `src/systems/record_file.gd`,
  `unit_board.gd` (`kill_at`, `corpse_indices`, `extend_corpse_at`, `consume_corpse_at`, the death seat's
  caller count). 6-5f does NOT need to open `_cast_is_interrupted` or `_advance_bursts` -- those are 6-5g's.
- **Suite:** `bash test/run_all.sh` with `GODOT=/c/Godot/godot.exe` via the Bash tool (WSL is broken).

### Project Structure Notes

- New/extended effect data at `data/effects/counterspell.tres`. Tests under `test/state/` and
  `test/integration/`, filenames per Task 9. A new public API or `src/` folder for the reversal-record
  mechanism is a design decision: stop and ask, per the project's Agent Autonomy rule, if the natural shape
  reaches beyond `player_state.gd`/`match_state.gd`/`hand.gd`.

### Project Context Rules (extracted from `docs/project-context.md`)

- State / visual separation; integer-tick timing (A1: every new duration converted once at application);
  every number a `.tres` field; feature flags injected into `src/state/`, never read from the service.
- Golden isolation (`BC/R3`): `data/balance/*.tres` is isolated from the golden; a NEW seat or a pressed
  action made refusable is not covered by that isolation and must be measured (Golden Prediction cause 5).
- Mutation proofs restore from a copy taken outside the repo (SHA256 first), never `git checkout --`; full
  suite at open and close, mutation proofs run only the affected file.
- Edit tool only (line-index splice as fallback, never PowerShell `-join`); Python unavailable.
- Docs and code never share a commit; ASCII messages via `git commit -F`; never push before the operator
  confirms the log.
- Single rolling backlog, no sprint timeboxes; per-story holds live in `story_notes`, never as an extra
  board status (`STATUS DEFINITIONS` stays locked to `backlog -> ready-for-dev -> done`).

### References

- `docs/planning-artifacts/deck-1-spec.md` (this pass's own amendment; section 6's Counterspell placeholder
  line this amendment supersedes).
- `docs/implementation-artifacts/6-5e-rocksling-boom-and-corpse-bomb.md` (Boulder cover mechanism, burst
  schedule, Corpse Bomb conversion record), `6-5d-fireball-and-spell-targeting.md` (hero-projectile
  machinery, cast-interrupt precedent -- 6-5g's), `6-5c-hero-cast-honed-bolt.md` (the cast lock itself,
  `6-5c/R3`'s "lost, not refunded" -- 6-5g's), `6-5b-corpses-and-own-minions.md` (corpse creation,
  Culling/Drain/Grave Ward/Raise Dead), `6-5a-spell-framework-and-buffs.md` (`last_resolved_card`, the
  timed-rule seat, `_apply_lifesteal`'s R6 foreshadowing).
- `docs/game-architecture.md` (D3, A1, A2, F1, D5); `docs/project-context.md`.
- GDD decision-log `R-D6`, `6-1c/R4`, `SC/R6`, `BC/R3`, `6-5b/R4`-`R8` (kill-without-damaging, corpse
  precedents), `6-5c/R3`/`R4`, `6-5e/R17`-`R28` (no-cast-frame activation, Boulder mechanism, S1 slow), and
  the decision-log session `6-5f scope + readiness gate` recording `6-5f/R1`-`R43`, this story's whole
  behaviour section transcribed from.

## Open Questions

1. **The reversal record's shape (Dev Notes above).** Fully behaviour-fixed, mechanism-open: a per-player
   "undo packet" overwritten in lockstep with `last_resolved_card`, versus a family of per-effect-id parallel
   fields. The dev pass owns this, argues its choice, and records it (the same discipline 6-5e's Open
   Question 1, the Boulder cover mechanism, followed). Every other Open Question from this story's original
   authoring (the pre-death hp field, the not-stunned test, the smoke case for `counter_window_seconds`, the
   refusal-cue distinction) was resolved by the 2026-09-29 browser decisions into AC 5/13/23/26 and `6-5f/R31`
   -`R35` -- none remain open.

## Dev Agent Record

### Agent Model Used

_To be filled by the dev pass._

### Debug Log References

_To be filled by the dev pass._

### Completion Notes List

_To be filled by the dev pass._

### File List

_To be filled by the dev pass._

### Change Log

_To be filled by the dev pass._
