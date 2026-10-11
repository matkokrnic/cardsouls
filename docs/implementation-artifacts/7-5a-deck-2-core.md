---
baseline_commit: 80b95406d3d875891b8e5c9e237acb496315e685
---

# Story 7.5a: Deck 2 core, Deck 1's eighth card, per-seat decks

Status: ready-for-dev

Tier **A** (new hashed per-player facts, new damage-funnel steps, a changed injection seam, a record-format bump, new
refusable outcomes). Authored 2026-10-11 against HEAD == origin/main == `80b9540`; readiness gate and operator rulings
2026-10-11 applied (decision-log session "7-5 design, 7-5a gate and rulings", labels `7-5a/R1..`). Board key `7-5-deck-2`
split: `7-5a-deck-2-core` (this story) and `7-5b-deck-2-bodies` (Healer, Elemental Fury, Wrath of God; NOT authored here).
Card text is in `docs/planning-artifacts/deck-2-spec.md` and the 2026-10-11 amendment in `deck-1-spec.md`; this story states
behaviour and acceptance (E4-R/R4). Every number is TEMP (7-7 retunes) and lives in `.tres`: pairings, colours, pitch
speeds, copy counts, costs, durations, multipliers. Numbers in ACs below are test-literal BalanceConfig values.

## Story

As a player, I want a second, "tall" deck (one hero loaded with buffs) and a richer Deck 1, so that the two decks play
differently and I can feel it.
As the operator, I want each seat to play the deck I choose through a data setting, so that a smoke can pit Deck 2
against Deck 1 without a menu.

## Scope

- Both decks are 8 unique cards: 4 at x3 + 4 at x2 = 20. Deck 1 gains Vanguard / Lifechain; Deck 2 is new.
- Implemented halves: Setup, Execute, Stoneskin, Bloodmagic, Enrage, Manablossom, Manapulation (Deck 2), Lifechain (Deck 1).
- Until 7-5b: Healer, Elemental Fury and Wrath of God are refused as "not available yet" (a new refusable outcome, AC 13).
  The other half of each of those cards works normally.
- Each seat plays its own deck list, chosen by an operator data setting (no menu). Shipped default: both seats Deck 1.
- Minimal placeholder markers so every active buff is readable on the hero, stacked buffs as a count; placeholder icons.
- Vanguard is a future shield knight (own story, timing open). Healer is a walking humanoid character, not a totem (7-5b).
- **One story, built in two ordered parts** (rule `7-5a/R23`, Tasks): Part A decks and seats, Part B the eight halves. One review.

## Acceptance Criteria

`[M]` machine-checkable, `[S]` live smoke. "Seat" = player 1 or 2. "Hero" = the seat's hero body.

**S1 The two decks**

1. **[M]** Deck 1 is 8 unique cards. x3: Hellhound/Culling, Grave Ward/Raise Dead, Drain/Vampiric Aura, Rocksling/Boom.
   x2: Honed Bolt/Counterspell, Bloodhound Step/Fireball, Frostbite/Corpse Bomb, Vanguard/Lifechain. Total 20. A test pins
   ids and counts.
2. **[M]** Deck 2 is 8 unique cards. x3: Honed Bolt/Counterspell, Rocksling/Boom, Setup/Execute, Healer/Stoneskin.
   x2: Bloodhound Step/Fireball, Bloodmagic/Enrage, Manablossom/Elemental Fury, Manapulation/Wrath of God. Total 20. A test
   pins ids and counts.
3. **[M]** The shared cards (Honed Bolt, Bloodhound Step, Rocksling) keep their pairings, costs, colours and speeds in both
   decks; Deck 1's behaviour for them is unchanged. Existing pairings never change.
4. **[M]** Colours: Setup/Execute red; Healer/Stoneskin green; Bloodmagic/Enrage green; Manablossom/Elemental Fury blue;
   Manapulation/Wrath of God blue; Vanguard/Lifechain green. Pitch speeds: instant = Execute, Stoneskin, Enrage, Lifechain;
   sorcery = Elemental Fury, Wrath of God. Costs per the spec files. All authored data; a test pins the table, and
   re-pairing or re-colouring a card is a data edit with no source edit. Two Deck 2 normal halves (Manablossom,
   Manapulation) are sorcery-class cards outside Deck 1; the "every card outside Deck 1 is instant" census moves.
5. **[M]** Vanguard/Lifechain is a NEW card file with a NEW card id (ruling `7-5a/R15`). Its normal half references the
   existing Vanguard summon effect by id, unchanged: it summons exactly what it summons today. `ruin_vanguard.tres`, its
   Culling pairing and every test that loads it stay untouched. Hellhound, Culling and every 7-3 behaviour are unchanged.
   The 7-3 pin that no Deck 1 card has the Vanguard summon as its normal half (`test_card_authoring.gd:523-525`) is
   reversed: it now asserts that exactly the new card does, and that `ruin_vanguard` is not in either deck. The summon
   census (`test_card_authoring.gd:436`, one summon in Deck 1) becomes two.
6. **[M]** The authoring audit (per-entry copies <= the card's max copies, index-aligned arrays, deck size equals the
   copy sum, every pitch cost within the bank cap) covers both lists. The deferred MAX_PIPS test
   (`deferred-work.md:668`) is adopted here: every card's summed orb price is <= `HudRoot.MAX_PIPS`.

**S2 Per-seat decks**

7. **[M]** Each seat draws from its own deck list. Both piles are shuffled from the SAME seeded generator in the existing
   fixed order (player 1, then player 2); no second RNG. Two seats on different lists receive different 20-card
   compositions. A machine check pins that two seats on the SAME list deal bit-identically to the deal before this story.
8. **[M]** The existing one-list forms stay valid: one composition for both seats, one `deck_list_override` for both seats
   (the roughly 75 `inject_deck(` calls and 14 override sites in `test/` keep working unchanged); per-seat forms are
   additive. Each HUD's slot reel reads its own seat's list. The cost, effect, colour and pitch-speed maps keep covering
   the whole library (match-wide), so they are not per seat.
9. **[M]** Which list each seat uses is a load-once operator data setting in the `seed_pin.tres` mould: not in the
   hot-reloadable balance config, not in `main.tscn`, read once at match start. Precedence: replay record, then test
   override, then the setting, then the default. A missing setting file means the default (both seats Deck 1); a value
   naming an unknown deck refuses to start the match with a named error, never a silent default (`7-5a/R26`).
10. **[M]** `FORMAT_VERSION` 23 -> 24. A v23 record is refused with a named reason; there is no shim (`7-5a/R16`).
    Pins that move: the version assertion (`test_record_file.gd:245`) and a NEW v23-refusal test (precedent
    `test_record_file.gd:1042`); versions read from file at `test_replay_identity.gd:1345,2147,2500`; the member pin
    `match_state._deck_contents` (`:550`); the channel map `deck` (`:1754,1768`); `test_intent_recorder.gd:129`;
    `test_live_reload.gd:141`; the schema row `record_file.gd:461`.
11. **[M]** The seat/deck assignment reaches a recording: a replay reproduces each seat's deal with the setting file changed
    or absent.
12. **[M]** The F3 text names the deck each seat is on (a machine check on the text builder). **[S]** smoke point 1.

**S3 Temporary refusal (until 7-5b)**

13. **[M]** Playing Healer (normal), or staging Elemental Fury or Wrath of God (pitch), is refused with a named "not
    available yet" reason before any mana, orb, card or stamina is spent. A refused pitch half is refused AT STAGING: the
    card stays in hand, no mana is lost, nothing enters the pitch zone. These are NEW refusable outcomes at two seats (the
    Mode 1 pre-spend gate and the staging ladder); the `7-7` Tier clause (a refusable action) is satisfied by this story
    being Tier A. Modes 2 and 3 of those three cards still work.
14. **[M]** The other half of each card works normally (Stoneskin, Manablossom, Manapulation). The refusal is replay-stable,
    adds NO record channel, and is removed by 7-5b in one edit (data or a single table, dev pass picks). No resolver-known
    id for the refused halves exists until 7-5b: a `summon_healer` id would summon a zombie through the prefix path
    (`card_effect_resolver.gd:602-605`) if the refusal were ever skipped, so the refused halves are not given one.
15. **[M]** A refused card is never a Counterspell target and never overwrites the last-resolved record.

**S4 Setup**

16. **[M]** Setup costs its authored mana and adds one Setup charge for the caster. Several Setups stack as charges. Setup
    is never refused for being active (`7-5a/R9`).
17. **[M]** A charge is spent at the ACCEPTED unblockable press: that press costs no mana (stamina and everything else
    unchanged). A press refused for mana, stamina or state spends nothing and keeps the charge. One charge per unblockable.
    The attack "carries Setup" from the press (`7-5a/R6`, `7-5a/R22`).
18. **[M]** The carrying attack, if it LANDS, grants double the orbs it would have: 1 becomes 2 (bank cap respected). If it
    does not land the charge is still spent and no extra orb is granted. Named non-landing cases, one test each: blocked or
    deflected by the defender, colour-counter, roll, post-get-up immunity, defender knocked down during the chargeup.
19. **[M]** "This attack carries Setup" is a hashed per-attack fact, cleared on every path that ends an attack (landed,
    defended, interrupted, round end, reset), on the `charge_contact` precedent (`player_state.gd:250-255`); a test per path.

**S5 Execute**

20. **[M]** Execute (pitch) costs its authored mana at staging and one red orb at activation, and adds one Execute charge for
    the caster. Several Executes stack as charges; never refused for being active.
21. **[M]** An Execute charge is consumed only by a weapon hit (melee or unblockable) that would damage the opposing hero,
    and that hit deals triple damage. Hits on units (minions, totems) never consume it and are not tripled. Spells and
    projectiles are not weapon hits.
22. **[M]** A BLOCKED hit does not consume Execute and is not tripled, but deals its reduced damage. A deflected hit, a rolled
    (avoided) hit and a missed hit do not consume it. A hit absorbed by Stoneskin DOES consume it (AC 25).
23. **[M]** Execute grants NO orbs, on any consumer. Several charges: each hit consumes exactly one and is tripled once,
    never multiplied together (two charges, two clean hits: x3 each, none left).

**S6 Stoneskin**

24. **[M]** Stoneskin (pitch) costs its authored mana at staging and one green orb at activation, and adds one Stoneskin
    charge. A charge makes the next damage INSTANCE the caster takes, from any source (melee, unblockable, spell,
    projectile, minion, totem), deal zero. Several stack as charges, one instance each. No timer. An instance is one
    hit event on the hero: one melee hit, one unblockable, one projectile hit, one Rocksling stone, one Boulder's Boom
    (`7-5a/R27`).
25. **[M]** An absorbed unblockable still knocks the defender down and still grants the attacker its orbs and every other
    on-land effect; only the damage is absorbed, and the charge is consumed. A hit the hero avoids (missed, deflected,
    rolled) does not consume a charge.
26. **[M]** Charges persist across the round they were gained in, until used, and are cleared at `_end_round` and
    `_reset_player` (AC 54).

**S7 Bloodmagic**

27. **[M]** Bloodmagic costs 0 mana: the caster loses its authored HP and gains its authored mana (mana cap respected; the
    clamped amount is what counts for reversal, AC 47).
28. **[M]** Bloodmagic is refused, nothing spent, card kept, if the caster's HP is <= its HP price (HP equal to the price is
    refused; price + 1 is allowed). HP paid is not damage (`7-5a/R17`).
29. **[M]** The HP paid does not trigger Stoneskin, Lifechain, Bloodlust or lifesteal and is not a hit.

**S8 Enrage**

30. **[M]** Enrage (pitch) costs its authored mana at staging and one green orb at activation, and starts a window. While it
    runs, the caster's weapon hits (melee and unblockable, not spells or projectiles) deal +2 damage, on units as well as
    the hero.
31. **[M]** Window length is the authored base plus the authored per-orb extension times the orbs the caster held at
    activation BEFORE paying the activation orb (all colours; `7-5a/R18`).
32. **[M]** Enrages stack: each adds +2 for its own independent window; a second Enrage is never refused or refreshed. The
    windows live in their own variable-length hashed store; the timed-rule seat (six fixed slots, refresh-only, operator
    ruling N10) is unchanged for every other rule (`7-5a/R9`, `7-5a/R22`).
33. **[M]** Damage order: (base + 2 x active Enrages) x block x Execute x Bloodlust (`7-5a/R12`, `7-5a/R20`). Pinned with numbers
    (test-literal base 3, block 0.3): one Enrage, blocked: (3 + 2) x 0.3 = 1.5, NOT 3 x 0.3 + 2; two Enrages, blocked:
    (3 + 4) x 0.3 = 2.1; one Enrage, clean, one Execute: (3 + 2) x 3 = 15; with a test-literal Bloodlust 1.5 also:
    (3 + 2) x 1.5 x 3 = 22.5. The first non-commuting step in the funnel (`match_state.gd:3020-3027`) lands with these tests.

**S9 Manablossom**

34. **[M]** Manablossom costs its authored mana. Each card in the caster's hand when it resolves gets a discount: 1 less mana
    to play (normal side) and to stage (pitch side), or 2 less if the caster holds 3 or more orbs (all colours) at that
    moment. Cost floors at 0; orb costs are unchanged. Not discounted: Boulder clearing, the unblockable's mana, the Mode 2
    balance value.
35. **[M]** The discount belongs to the card until it leaves the hand (played, staged, discarded). A card drawn afterwards is
    not discounted. A card under a Boulder takes the discount and shows it when uncovered. Manablossoms stack additively;
    the RAW sum is stored and clamped to 0 only at read, so a counter restores correctly (`7-5a/R10`, `7-5a/R14`). A card refused for any
    reason keeps its discount.
36. **[M]** Fireball: the discount lowers its staging minimum (3 becomes 2); its damage stays per mana actually spent.
37. **[M]** The cost shown on a card in hand is the discounted one. Prices reach the HUD as load-once static data that never
    enters game state (`match_runner.gd:598-608`); the per-slot discount therefore needs a channel, proposed as the
    `cards_changed` payload (implementation choice). The runner seam count (AC 51) does not grow.

**S10 Manapulation**

38. **[M]** Manapulation costs its authored mana and grants mana equal to the successful stagings into the caster's OWN pitch
    zone this round (mana cap respected). Refused stagings and Boulder clears do not count; a card that later fizzles or
    activates still counts; countering the staged card does not remove the count. Manapulation itself is a normal play, not
    a staging. Zero stagings grants zero. The count is cleared wherever per-player buffs clear (`_end_round`,
    `_reset_player`; AC 54). The opposing seat's pitching never counts (`7-5a/R19`).

**S11 Lifechain (Deck 1)**

39. **[M]** Lifechain (pitch) costs its authored mana at staging and one green orb at activation, and opens a window of its
    authored duration. Several Lifechains never deepen the split: coverage lasts until the LATEST window ends. Never
    refused for being active.
40. **[M]** While covered, each damage instance the hero would take is split EQUALLY among the hero and the hero's living
    minions (counted when that instance lands; totems excluded). A minion's share beyond its remaining HP goes to the hero.
    Example (test-literal): 6 damage, two minions, one with 1 HP left: shares of 2 each; the 1-HP minion takes 1 and dies
    (normal corpse), the 1 overflow goes to the hero, who takes 3. With no living minion the hero takes the whole instance.
41. **[M]** Stoneskin resolves first: a charge absorbs the WHOLE instance, so nothing is split and no minion is touched.
    The hero's own rules for the instance are otherwise unchanged (an unblockable still knocks it down). Vampiric Aura heals
    off the hero's hp delta only, i.e. the hero's share (`7-5a/R8`, `7-5a/R28`).
42. **[M]** A Counterspell on a card that hit a Lifechained hero refunds only the hero's share; minion shares and minion
    deaths stay (`7-5a/R13`).

**S12 Counterspell on every new half**

43. **[M]** A Counterspell removes exactly what that one cast added (`7-5a/R11`), by the existing two-layer rule. PENDING and
    TIMED products are removed and what they already did stays; INSTANT products are reversed by the amount actually applied.
44. **[M]** Charges (Setup, Execute, Stoneskin): one charge of that kind is removed if the caster still holds one; otherwise
    there is no target. A Setup already spent on an attack in flight is gone: that counter has no target and the in-flight
    doubling stays.
45. **[M]** Windows: Enrage and Lifechain end that cast's own window only; other windows run on and Lifechain coverage lasts
    until the latest one left. Damage already dealt keeps the bonus; damage already redirected stays redirected.
46. **[M]** Manablossom: that cast's own amount is removed from the cards it touched that are STILL IN HAND; cards already
    played keep what they saved; if none is left in hand there is no target.
47. **[M]** Bloodmagic (HP refunded up to max; mana clawed back down to the floor 0) and Manapulation (mana clawed back,
    floor 0) reverse the amount actually applied: cast at 8 of 10 mana gaining 2, the counter claws back 2.
48. **[M]** No target is refused through the existing path, before the orb spend (6-5f/R11, fourth clause). Tests: one per new
    half; each charge and window half also in a STACKED variant (two held, one counter leaves exactly one); each half also in
    its already-used variant (consumed, absorbed, expired, gone from hand).
49. **[M]** Counterspell against the refused-for-now halves is not reachable (AC 15). Reversal of a PITCH half needs both
    seats to pitch: it is machine-only in solo `[0,3]` (the keyboard has no pitch path).

**S13 Placeholder markers and icons**

50. **[S]** On both viewports, each is readable on the hero by a minimal placeholder marker, distinct from the others: Setup,
    Execute, Stoneskin, Enrage, Lifechain. Setup, Execute, Stoneskin and Enrage markers read as a COUNT of charges or
    windows (two Setups show 2); the Lifechain marker shows while covered. Discounted cards in hand are marked and show
    the discounted cost. A marker, or a count step, disappears when its state ends or is countered. **[M]** the HUD-side
    state read gives the right count after each gain, spend and counter.
51. **[M]** Marker state reaches the HUD and hero views through the existing post-advance reads and seams
    (`match_runner.gd:1760,1863`); the runner seam count stays as pinned.
52. **[M]** Deck 2 joins the icon audit (`test_card_face.gd:756-784` reads `deck_1.tres` and pins 15 effects today): it reads
    both lists and the count pin moves to the new total. Every new half gets an icon keyed by effect id in
    `effect_icons.tres`; a "placeholder" must still satisfy the audit: a game-icons.net file with its author credit in
    `assets/CREDITS.txt` (`7-5a/R25`).

**S14 Determinism and replay**

53. **[M]** A recorded match exercising the new mechanics replays to the identical final hash and record (6-5e AC 41
    precedent), with the two seats on different decks: Setup then an unblockable that lands, Execute consumed by a melee hit
    and by an unblockable, a Stoneskin absorbing an unblockable, Bloodmagic, Enrage, Manablossom with a played discounted
    card, Manapulation, Lifechain with two minions taking a hit, and at least one Counterspell reversing a new half.
54. **[M]** Every new per-player fact is hashed, listed in Dev Notes; card content (costs, pairings, speeds, copies) is not.
    EACH fact is cleared at both `_end_round` and `_reset_player`, with a test in both directions per fact (the 6-5a B1
    lesson, `match_state.gd:8617-8623`).
55. **[M]** F1, D3(a), D3(b)/A2 stay green; no RNG, `Time`, `OS` or `Engine` in `src/state/`.
56. **[M]** The golden and snapshot key set move only by named, separately measured causes, measured after Part A and again
    after Part B, both directions each (Dev Notes, Golden Prediction).

**S15 Non-goals and gate**

57. **[M]** Nothing of Healer's body, Elemental Fury's projectiles or Wrath of God's wave is built. Shelved cards stay
    loadable. Balance values outside this story's cards are untouched.
58. **[M]** The full gate (state harness plus integration) is green. **[S]** The Live Smoke passes and fps is stable.

## Tasks / Subtasks

The dev pass builds in two ORDERED parts (`7-5a/R23`); each ends with its own golden and key-set measurement before the next
starts. One review, after Part B.

**Part A - decks and seats (AC 1-15, 52, 56)**
- [ ] T1 Deck data: Deck 1 amendment, new Vanguard/Lifechain card, Deck 2 list, new card and effect `.tres`, icons (AC 1-6, 52).
- [ ] T2 Per-seat selection: injection, per-seat deal, HUD reel, the setting and its precedence (AC 7-9, 12).
- [ ] T3 Format bump: 24, v23 refusal, every pin of AC 10, replay of the deal (AC 10-11).
- [ ] T4 Temporary refusal list for the three 7-5b halves (AC 13-15).
- [ ] T5 Part A measurement: golden and key set, expected UNMOVED except named shape causes; record before/after.

**Part B - the eight halves, markers, reversals (AC 16-58)**
- [ ] T6 Setup, Execute, Stoneskin charges and the damage funnel (AC 16-26).
- [ ] T7 Bloodmagic, Enrage store, Manablossom, Manapulation (AC 27-38).
- [ ] T8 Lifechain split (AC 39-42).
- [ ] T9 Counterspell reversals for every new half (AC 43-49).
- [ ] T10 Markers, counts, discount channel (AC 50-51).
- [ ] T11 Replay identity, hashed-fact clear tests, key set, Part B measurement, gate (AC 53-58).
- [ ] T12 Live Smoke (three launches) and close-out docs, including the E7 docs debt (X1).

## Dev Notes

### Measured facts at authoring (HEAD `80b9540`)

- `data/decks/deck_1.tres` lists seven cards, copies `[3,3,3,3,3,2,3]` (hellhound, grave_ward, drain, rocksling,
  bloodhound_step, honed_bolt, frostbite). Target: Bloodhound Step and Frostbite go 3 -> 2, Vanguard/Lifechain x2 is added.
- ONE deck for both seats today: `match_runner.gd:920` `DECK_LIST_PATH`, `:925` one `deck_list_override`, `:965-972`
  `_active_deck_list()`, `:507-515` one derive/inject/capture, `:618` each HUD reel reads the one list; `match_state.gd:547`
  and `:1128-1131` one non-hashed `_deck_contents` and one `inject_deck`; `:1157,1215,1250` cost/effect/colour totality checks
  walk the one composition; `:4043-4056,4073` both piles laid from it; `:8644` the reset re-arms the deal from it;
  `intent_recorder.gd:87,193,411,504,576` captures one composition; `record_file.gd:461,826,960` one `"deck"` array;
  `test/tools/replay_file.gd:64` prints one deck size. Every site is covered by AC 7-11; the comment at `match_state.gd:556-560`
  needs updating. `match_state.gd:4043-4045` rules out a second RNG (AC 7).
- `data/cards/ruin_vanguard.tres` is Vanguard / **Culling**; `hellhound.tres` is Hellhound / Culling. Both stay (AC 5).
- `pitch_speed` lives on the pitch `CardCastCondition` (`card_cast_condition.gd:50`), default instant.
- `data/seed_pin.tres` / `src/main/seed_pin.gd` is the load-once precedent (7-4/R13); its comment forbids balance-config
  homing for anything the runner reads once.
- `unblockable_mana_cost = 1.0` (`balance_config.tres:230`) so Setup's saving is real. `block_damage_multiplier = 0.3`
  (`:218`), applied at `match_state.gd:3016`; the funnel is `:3032`.
- Mana is tested and spent at the PRESS (`match_state.gd:6403-6410`). "Launch" in this codebase is the later phase when the
  chargeup window closes (`player_state.gd:213-221`); the doubled grant happens ticks after the press
  (`match_state.gd:6665-6667,7440-7451`), hence the per-attack carry fact (AC 19).
- Timed rules: six fixed slots (`player_state.gd:635`), re-applying REFRESHES, never stacks (`:612-614`, N10). Enrage and
  nothing else needs a stacking store (AC 32).
- Reversal record: one packet overwritten at each resolution (`player_state.gd:772-784,927-931`); every damaging kind
  "damages exactly one address" (`:852-856`), which Lifechain breaks (AC 42). Prices reach the HUD as static data
  (`match_runner.gd:598-608`). The staging ladder refuses before the mana spend at `match_state.gd:6029-6060,6090`;
  Fireball's pitch price is a minimum and spends the pool (`:6061-6089`). The Mode 1 pre-spend gate is `:5671`.
- No per-round "times pitched" counter exists; Manapulation needs a new hashed fact.

### New hashed per-player facts (AC 54)

1. successful stagings this round; 2. Setup charges; 3. the in-flight "this unblockable carries Setup" fact (per attack);
4. Execute charges; 5. Stoneskin charges; 6. the Enrage window list; 7. the Lifechain windows (a list, for AC 45);
8. per-slot Manablossom discount on cards in hand (raw sum); 9. per-cast reversal data for the above (which slots and how
much, which window, which charge kind). Each is a shape cause for the snapshot key set.

### Mechanism the repo forces (everything else is the dev pass's choice)

- Enrage uses its own variable-length hashed list, not the timed-rule seat (AC 32); N10 stays true elsewhere.
- Setup's carry fact clears on every attack-ending path (AC 19); `charge_contact` is the precedent.
- The Lifechain split runs after the block multiplier and Stoneskin, before the funnel's per-body hp read, so Vampiric Aura
  sees the hero's share (AC 41). Overflow to the hero is not redistributed.
- The reversal record is extended per cast (AC 43-47); a Counterspell on a Lifechain-hit card reads the hero's share only.
- The discount travels with `cards_changed` (AC 37); no new runner seam.
- The temporary refusal is one removable table or data row; where it lives is the dev pass's call (AC 14), and it must not
  reach `src/state/` by reading a data file.

### Tests that move (named so the dev pass does not discover them)

Under any reading: `test_card_authoring.gd:523-525` (AC 5), `:436` (summon census), `:32,126,203` (library count and id lists:
a new card file), `:25,64-69,329,338-358` (Deck 1 ids, copies, count), `:73-102,265-273` (prices, effects, speeds tables),
`:213-223` (colour census 3/2/2 becomes 4/2/2), `:401-479` (effect-family census, Deck 1 only), `:290-304` (every card
outside Deck 1 is instant: the sorcery Manablossom and Manapulation cards), `:553-562` (non-Deck-1 cards author no pitch
effect), `:605` (effect file count 17); `test/integration/test_card_database.gd:33-49` (library count 18),
`test_deck_injection.gd:51-59,64-69` (id lists and copies), `:212-217` (which cards author a pitch effect);
`test_card_face.gd:766` (icon audit count 15); AC 10's list; key-set pins `test_draw_delay_and_reshuffle.gd:62` and
`test_card_observation.gd:302`. Live tests on seed 12345 with no deck override get a different Deck 1 deal and must be
re-checked (candidates: `test_card_hud.gd:61`, `test_card_mode_lift.gd:50`, `test_card_selection_indicator.gd:53`,
`test_card_tint_live.gd:70`, `test_cast_success_cue_live.gd:32`, `test_debug_instruments.gd:89`,
`test_effect_presentation_live.gd:54`, `test_hole_vs_in_flight_live.gd:62`, `test_pitch_ghost.gd:38`,
`test_record_save_control.gd:81`, four `test_hound_*_live.gd`); the reshuffle helper in `test_unit_combat_live.gd:388-398` and
four siblings is safe only because one override still means both seats (AC 8).
Do NOT move (they load the effect file by id and never read the pairing): `test_counterspell.gd:1550`,
`test_hellhound.gd:193,1911`, `test_spell_framework.gd:82-97`, and the 14 `live_summon_deck.gd` tests (they use
`ruin_vanguard`, which this story leaves alone). The golden fixture injects its own in-test deck
(`test_determinism.gd:2381`), so authored decks cannot move it.

### Doc contradictions (flagged, not reinterpreted)

- **X1.** `gdd.md:147` says Unblockable Initiation "costs stamina only (no mana)"; the balance config charges 1 mana. The
  repo wins; Setup's saving is real. The GDD line is stale: E7 close-out docs debt (`7-5a/R21`).
- **X2.** Lifechain makes the sleeping Vanguard zombie a damage sponge that never fights back. Accepted (AC 5, AC 40); the
  smoke will show how it plays; a shield knight replaces it in its own story.
- **X3.** `deck-1-spec.md` section 1 still reads "Vanguard / Culling"; the 7-3 amendment moved Culling to Hellhound and the
  2026-10-11 amendment adds Vanguard/Lifechain as a new card. The base text is superseded.

### Golden Prediction (prediction only; the dev pass measures both directions)

- **Part A (decks, seats, format):** the per-seat seam is a predicted NON-MOVER for the golden (the golden fixture injects its
  own deck; two seats on one list deal bit-identically, AC 7). The snapshot key set is predicted unmoved by Part A; if
  `_deck_contents` becomes per seat it is non-hashed. Measure; any move is named and reproduced both ways.
- **Part B (the halves):** the golden moves only by SHAPE, once, if the nine facts of the list above add keys; the
  golden fixture exercises none of the new mechanics, so no behaviour moves (measure with the keys removed: the hash is
  the Part A hash exactly, the 7-3/R45 method). Key-set pins to update: `test_draw_delay_and_reshuffle.gd:62`,
  `test_card_observation.gd:302`. A Part B behaviour move is a defect to explain, not a re-baseline to accept.
- `FORMAT_VERSION` 24 is certain (AC 10). Deck 1's copy change cannot move the golden.

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md)

- Never hardcode balance or content; every number here is `.tres`. State layer is headless-tested, no scene.
- F1, D3(a), D3(b)/A2 are suite-enforced. Docs and code never share a commit. Commit trailer is the repo constant.
- Tier A: full gate, review and live smoke. R-D6 applies to the smoke.
- Edit via the Edit tool only; non-vacuity proofs back up out of repo and restore by copy-back.
- Design decisions (what the game IS) are Matko's: a dev-pass choice that changes a player-facing rule or adds a public API
  or folder STOPS and asks.

### References

- `docs/planning-artifacts/deck-2-spec.md`; `docs/planning-artifacts/deck-1-spec.md` (2026-10-11 amendment, 7-3, 7-4, 6-5f)
- `docs/implementation-artifacts/6-5f-counterspell.md` AC 11-13 (interim refusal, no-target pattern); `6-5e` AC 41 (replay identity)
- `docs/implementation-artifacts/7-4-pitch-speeds.md` (pitch speed, `seed_pin` knob, smoke shape); `7-6` R2 (per-effect icons)
- Decision-log session "7-5 design, 7-5a gate and rulings" (`7-5a/R1..`); readiness gate `C:\dev\_75a-gate.md` (outside the repo)

## Live Smoke

Solo `[0,3]` (the 7-4 setup: add `slot_controller_kinds = Array[int]([0, 3])` to the Main node of `main.tscn`, delete before any
suite run). The deck setting is edited and the game RELAUNCHED between configurations. Pin the seed where a point needs a
known hand. Pitch-half reversals are machine-only (AC 49); the keyboard seat has no pitch path, so it plays NORMAL halves only.

**Launch 1 - pad seat Deck 2, keyboard seat Deck 1 (keyboard is the target and attacker)**
1. **Per-seat decks.** F3 names both decks; hands come from their own lists.
2. **Setup.** Play two Setups: marker reads 2. The next unblockable costs no mana and a landing grants 2 orbs (1 becomes 2);
   count drops to 1. A second unblockable the keyboard seat blocks wastes the last charge (no extra orb).
3. **Execute.** Stage and activate Execute; a hit on a minion leaves the marker; a blocked hit is not tripled and keeps it;
   the next clean hero hit triples; no orb bonus. Two Executes read 2.
4. **Stoneskin.** Activate; the next hit (try an unblockable) deals 0, knocks down, grants the attacker orbs; marker drops.
5. **Bloodmagic.** HP down, mana up; refused with HP equal to its price.
6. **Enrage.** +2 on melee and unblockable hits (not a spell) for the window; two Enrages read 2 and stack; more orbs held
   gives a longer window.
7. **Manablossom.** Discounted cards marked and cheaper; 2 less with 3+ orbs; Fireball stages at 2; a drawn card is not
   discounted.
8. **Manapulation.** Mana equals this round's successful stagings.
9. **Temporary refusal.** Healer, Elemental Fury, Wrath of God refused with no loss; their other halves work.

**Launch 2 - pad seat Deck 1, keyboard seat Deck 2**
10. **Lifechain.** Pad pitches Lifechain with two minions alive: a keyboard hit splits onto the hero AND both minions; with no
    minions the hero takes it all.
11. **Counterspell.** Keyboard plays a normal Deck 2 half (Bloodmagic, then Setup); the pad seat counters each. Bloodmagic's HP
    and mana are restored; the Setup marker drops.
12. **R-D6.** A round ends normally (a kill ends it, the reset starts the next); every marker, charge and window clears.
13. **fps stable** throughout.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
