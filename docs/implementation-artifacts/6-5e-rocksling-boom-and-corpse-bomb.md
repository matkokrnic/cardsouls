---
baseline_commit: 101035536cad640cbf403346b6d5eb89dbf9add1
---

# Story 6.5e: Rocksling, Boom and Corpse Bomb

Status: ready-for-dev

<!-- Tier A; fifth of six 6-5 sub-stories, depends on 6-5d-fireball-and-spell-targeting (done). Scope is
the operator's ruling set of 2026-09-28, carried verbatim as behaviour below. This pass writes the story
file only -- no code, no suite run. Repo values cited were read at authoring: golden
de3589ffa5012ed8ba368ae3f51e52e992ca1bd0f36ad430d509b43646eaf289, RecordFile.FORMAT_VERSION 16, the
per-player snapshot key set 40 (test_draw_delay_and_reshuffle.gd's EXPECTED_PLAYER_SNAPSHOT_KEYS). -->

## Story

As the operator (and later the friends playtest),
I want Rocksling to throw a burst of homing stones that plant Boulder cards face-up in the opponent's
hand, Boom to detonate every Boulder sitting there, and Corpse Bomb to turn every one of my own living
minions into a corpse and a homing skull,
so that the Red and Blue halves of Deck 1 finish their pitch pairs on the hero-projectile machinery
6-5d built, and the Boulder mechanic exists for 6-5f's Counterspell to undo.

## Board note

`sprint-status.yaml` key `6-5e-rocksling-boom-and-corpse-bomb`, board status `backlog` at authoring, then
`ready-for-dev` after this fix-and-promote pass (readiness gate `C:\dev\_65e-gate.md`: NOT READY, 12
blockers, all fixed in this pass and logged as `6-5e/R17`..`R28` in the decision-log's "6-5e scope +
readiness gate" session; S1, the Boulder slow, ruled and carried the same pass). Depends on
`6-5d-fireball-and-spell-targeting` (`done`, golden `de3589ff...`, `FORMAT_VERSION 16`). `6-5f-counterspell`
(backlog, last of the six, the E6 close-out story) depends on this one: it records what Counterspell must
undo for every effect 6-5a..6-5e ships, including the three this story adds (AC 40).

## Repo-verified facts this story is authored against

Content citations (grep the quoted string / path).

- **Rocksling and Frostbite are already-authored cards, correctly deferred.** `data/cards/rocksling.tres`:
  `color = 0` (RED), `cast_condition.mana_cost = 4.0`, `basic_effect` -> `data/effects/rocksling.tres`
  (`effect_id = &"rocksling"`, no other field authored), `pitch_effect` -> `data/effects/boom.tres`
  (`effect_id = &"boom"`), `pitch_condition.mana_cost = 3.0`, `pitch_condition.orb_costs = {0: 1}` (1 RED
  orb). **Matches the operator's Boom ruling exactly -- no discrepancy.** `data/cards/frostbite.tres`:
  `color = 1` (BLUE), `pitch_effect` -> `data/effects/corpse_bomb.tres`, `pitch_condition.mana_cost =
  5.0`, `pitch_condition.orb_costs = {1: 1}` (1 BLUE orb, `Enums.CardColor.BLUE == 1`). **Matches the
  operator's "spec starting value 5 mana" exactly -- no discrepancy.** All three effect `.tres` files
  (`rocksling.tres`, `boom.tres`, `corpse_bomb.tres`) author only `effect_id` today -- every number this
  story needs is unauthored.
- **All three ids are still in `CardEffectResolver.DEFERRED_EFFECT_OWNERS`**, already pointed at THIS
  story's board key (`&"rocksling"`, `&"boom"`, `&"corpse_bomb"` all `-> &"6-5e-rocksling-boom-and-corpse-bomb"`,
  `card_effect_resolver.gd`). Removing the rows for the three ids this story builds (Task 4) is this
  story's own version of 6-5d's Discrepancy 4 -- the same mechanism, third time.
- **`CardEffect` is a flat, no-subclass, no-nested-resource schema** (`src/state/resources/card_effect.gd`),
  extended once per story on the same discipline: 6-5a's five buff/trigger fields, 6-5b's four
  corpse/own-minion fields, 6-5c's seven cast fields, 6-5d's eight variable-cost/flight fields. This
  story's new numbers (`boulders_per_cast`, the stone interval, stone/skull/Boom damage) are the FIFTH
  such family, on the same discipline: neutral-zero defaults where the field is read on a path an
  unrelated effect can reach, live defaults only where 6-5c's `cast_seconds` precedent applies (a field
  read only once an effect is already classified as this family).
- **The hero-projectile machinery 6-5d built is what Rocksling's stones reuse for record shape and flight
  reading -- CORRECTED at the gate (`6-5e/R22`, G3): it does NOT already cover a Mode 1 (basic) effect.**
  `ProjectileBoard.add_hero_shot()` (6-5d's addition): `_effect_ids` (String, the profile handle),
  `_damage` (float, the locked per-shot damage), `_kind_index = NO_KIND_INDEX`, `_source_index =
  HERO_INDEX`. `is_hero_sourced_at(i)` is the discriminator. The flight profile (`launch_speed`,
  `homing_turn_rate_degrees_per_second`, `acceleration_delay_seconds`, `acceleration_per_second_squared`,
  `max_speed`, `travel_budget`) is read off the effect via `_projectile_profile_at` / the runner twin
  `_projectile_profile` -- but the MIRROR those readers consult (`_effect_projectiles`,
  `_effect_projectile_delay_ticks`) is built by `inject_pitch_effects()` (`match_state.gd:1161-1178`)
  iterating `_pitch_effects` ONLY. Rocksling's `rocksling` id lives in `_card_effects` (Mode 1, a basic
  effect), never in `_pitch_effects`, so a Rocksling stone resolves a NULL profile and zero acceleration
  delay as the code stands today -- no launch speed, no homing, no budget. Rocksling is the FIRST Mode 1
  effect to fire a hero projectile; the mirror must be widened to also cover basic effects (Task 4), with
  a load-time refusal if an effect id ever appears in BOTH maps (AC 1a). A BURST of several shots from one
  cast (Rocksling's stones, Corpse Bomb's one-skull-per-minion) is new: 6-5d fires exactly one shot per
  cast strike; this story is the first to place more than one `ProjectileBoard` record from a single
  resolution.
- **Corpse Bomb's skulls do NOT reuse `add_hero_shot` unchanged -- CORRECTED at the gate (`6-5e/R23`,
  G4).** `add_hero_shot` (`projectile_board.gd:171-186`) writes `_source_index = HERO_INDEX` INSIDE the
  seat, by design ("`_source_index` must land on the runner's existing owner-hero fallback in
  `_projectile_launch_position` so the shot leaves the caster") -- every shot through this seat launches
  from the CASTER's feet, not from a dying minion's position. AC 31 requires each skull to launch from ITS
  OWN converted minion's position at the moment of death, and corpses carry no position in state
  (`test_corpses.gd` header, AC 1: "owner, dead index, remaining lifetime, no position"). A NEW explicit
  seat is added alongside `add_hero_shot` for minion-sourced launches (Task 4): the skull record names the
  minion it came from; the launch position stays presentation (F1) -- the runner resolves it from that
  unit's actor (the corpse actor still exists at the moment of death), falling back to the caster's feet
  only if the actor is gone. `add_hero_shot`'s own invariant ("impossible to create with a kind index by
  accident") stays true and tested for the new seat too.
- **Target-only contact and defence are state rungs in `_resolve_contacts`, not gather filters** (6-5d
  fact, unchanged): non-target minions/totems do not absorb a Fireball; `is_iframe_open()` (roll incl. its
  one-tick grace, and the get-up window) drops a contact, ends homing, and does NOT consume the shot; a
  deflect (blocking, facing, window open, stamina paid) negates and consumes; the block multiplier applies
  UNLESS the effect is authored to skip it (Fireball skips it wholesale -- AC 16 of 6-5d, "block does not
  help"). Stones and skulls need the SAME "block does not help" rung Fireball already proved out; this
  story's mechanism decision is whether that is a per-effect flag or a property already implied by an
  existing field, not a new rung.
- **Bloodlust / Vampiric Aura already reach a hero-sourced shot** (6-5d AC 14, `_funnel_damage`,
  `_apply_lifesteal`'s hero-index gate widened for `is_hero_sourced_at`) -- this story's stones, Boom hits
  and skulls are the SAME funnel seat, not a new one (AC 34).
- **Corpses and their lifecycle are 6-5b's** (`src/state/` corpse container, `Corpse.gd` or equivalent,
  the linger timer, Grave Ward's per-corpse extension, Raise Dead's consumption). "Leaves a normal corpse"
  for Corpse Bomb (ruling 11) means the SAME corpse creation seat every other minion death already uses --
  not a bespoke one. Read `match_state.gd`'s existing minion-death seat (`4-3a`) before adding a second.
- **Hand is a fixed-width, hole-aware container** (`src/state/hand.gd`, story 4-0): one `StringName` id or
  the `EMPTY` marker per slot, `fill_at` REFUSES to write into an occupied slot, `remove_at` REFUSES to
  read an empty one. **The Boulder mechanism (ruling 6/7) does not fit this shape as it stands**: "sits ON
  TOP of the slot's card; the card stays underneath, unplayable, and reappears... when the Boulder is
  removed" is a second, ordered layer over a slot the existing container has no field for. This is the
  central mechanism question of the dev pass (Open Question 1) -- the story below fixes the BEHAVIOUR
  (rulings 6-8) and leaves the data shape to the dev pass, per the hard rule "write behaviour, not
  mechanism, except where a ruling fixes it."
- **Pending-draw delay (3-5b) and slot stability (4-0) are both about a slot recovering its OWN identity
  after a cast** (`test_card_play.gd:47` `"slot 1 was refilled in place"`; `test_draw_delay_and_reshuffle.gd`
  section "STORY 4-0: slot stability"). The Boulder-removal refill ("no draw delay") and the underlying
  card's reappearance are both SLOT-LOCAL events on the same precedent -- neither is a new deal, neither
  touches `pending_draw`.
- **Golden and key set (verified at authoring):** `test_determinism.gd` `const GOLDEN :=
  "de3589ffa5012ed8ba368ae3f51e52e992ca1bd0f36ad430d509b43646eaf289"`; `src/systems/record_file.gd`
  `const FORMAT_VERSION := 16`; `EXPECTED_PLAYER_SNAPSHOT_KEYS` in `test_draw_delay_and_reshuffle.gd` has
  **40** keys (alphabetical, `cast` through `unit_targets`, includes the two 6-5d projectile keys
  `projectile_damage` / `projectile_effect`).
- **`unit_kinds` reload refusal (M6, `6-5d/R12`) already covers "stones and skulls"** by construction: it
  refuses a same-length REORDER of the running config while any unit or projectile record is live,
  regardless of what fired the projectile. This story adds no new reload seat; it only needs to stay true
  once stones and skulls exist as hero-sourced projectile records (ruling 15).

## Discrepancies found against the prompt (repo wins) -- none blocking

Both cost figures named in the operator's prompt as "confirm against repo, repo wins on mismatch" were
CHECKED and MATCH exactly: Boom stages for 3 mana + 1 red orb (`rocksling.tres` `pitch_condition`); Corpse
Bomb stages for 5 mana + 1 blue orb (`frostbite.tres` `pitch_condition`). No amendment to either number is
needed; the deck-1-spec amendment below (ruling-required) restates the mechanic changes only.

## Operator rulings of 2026-09-28, carried as behaviour

### Rocksling (normal cast, mode 1, RED, 4 mana -- unchanged, already authored)

1. The cast uses the same visible hero cast frame 6-5c built and Fireball reuses: a stun interrupts the
   cast (the card and its mana are lost, no stones fire); an ordinary hit landing on the caster during the
   cast does not interrupt it. Everything else about the cast lock (the caster stands, cannot act, a held
   block drops at cast start, card presses are refused, round end and debug reset clear an in-flight cast,
   a caster who dies mid-cast never fires) is the unchanged 6-5c/6-5d cast contract.
2. At cast end, Rocksling fires a BURST of homing stones, one after another, launched from the caster's
   feet on the same hero-projectile source 6-5d built (Fireball's launch point). The stone COUNT is
   authored in the effect `.tres` as a new field named `boulders_per_cast` (default 3); the INTERVAL
   between consecutive stone launches is authored as a new duration field (default 0.3 s, converted to
   ticks once per A1); each stone deals exactly 3 damage (authored, not derived from mana or anything
   else). Every stone shares one effect id and one damage figure -- unlike Fireball, no staged variable
   cost is involved (Rocksling is a Mode 1 cast, not a pitch).
3. Targeting is IDENTICAL to 6-5d's spell-targeting rule: the target (opposing hero, minion or totem) is
   the caster's lock-on target captured once, at cast START (the press tick), fixed for the whole burst; an
   unlocked caster's burst targets the opposing hero. Every stone in the burst shares that one captured
   address -- a re-lock or unlock mid-burst changes nothing already in flight or still to launch. Stones
   pass through any minion that is not the captured target, exactly as Fireball does not stop on a
   non-target body (6-5d AC 20). If the captured target is already dead when a LATER stone in the burst
   launches (the target died between the cast strike and that stone's own scheduled launch tick), that
   stone behaves exactly as Fireball behaves for a target already dead at the launch tick (6-5d AC 22): it
   is still placed and launched, flies straight from the hero on its launch heading, homes on nothing,
   damages nothing, and expires at its travel budget.
4. Defence is DIFFERENT from every projectile shipped so far and is the headline new rule this story adds:
   **a BLOCKING target takes full, unmitigated stone damage -- block grants no mitigation at all against a
   stone, and a Boulder is still placed on a successful hero hit even though the target was blocking.** A
   DEFLECT (blocking, facing, the deflect window open, stamina paid, exactly as today) fully CANCELS the
   stone: no damage, no `hit_landed`, and no Boulder is placed. Roll i-frames and get-up i-frames strip a
   stone's homing exactly as they do for Fireball (6-5d AC 17): the contact drops, the stone is NOT
   consumed, its homing ends on that tick and it flies straight until it hits something else or expires.
5. A stone that hits a minion or a totem (i.e. the captured target IS a minion or totem) deals its 3 damage
   through the normal funnel and does nothing else -- no Boulder is ever placed from a stone landing on a
   unit. Boulders exist only in a hero's hand.
6. **Every stone that lands on the OPPOSING HERO places exactly one Boulder card in that player's hand,**
   chosen at the moment the stone lands (not at cast start): a RANDOM slot, drawn from the caster's seeded
   gameplay RNG (deterministic, replay-safe, the same single seeded stream every other seeded pick in
   `advance()` uses -- never a second RNG source), among the slots of the STRUCK player's hand that (a)
   currently hold no Boulder and (b) are not the originating hand slot of a card of the STRUCK player's OWN
   that is currently staged in the STRUCK player's own Pitch Zone (`6-5e/R20`, G1 -- CORRECTED at the gate,
   B1/B2: the original wording named the CASTER's pitch zone, the wrong party, and "occupied by a card
   currently staged" as a predicate is repo-impossible, since a staged card's slot is empty in `Hand`; the
   correct test is `slot_index == pitch.staged_hand_slot(slot)` for any of the struck player's own staged
   pitch cards). A card in the struck player's own CAST FRAME or CHARGING under a Mode 2 commit is NOT a
   separate protected case: both remove the card from `Hand` and append `pending_draw_owed` for that slot
   in the same tick as the press/commit (`match_state.gd` `_resolve_basic_cast`, `_resolve_unblockable_cast`),
   so by the time either is visibly playing the slot is already an ordinary mid-draw-delay hole, which
   clause (b) below already makes eligible. The Boulder sits ON TOP of whatever card already
   occupies the chosen slot: the underlying card stays in place, becomes UNPLAYABLE while covered, and
   reappears in that same slot, immediately playable, the instant the Boulder covering it is removed (by
   being played, by round end, or by debug reset -- ruling 7). If the RNG's chosen slot happens to be
   empty at that instant (a slot mid-draw-delay, 3-5b), the Boulder occupies the empty slot directly, and
   when the pending replacement lands it lands UNDERNEATH the Boulder (the Boulder still covers it, exactly
   as it would cover any other card). If NO slot is eligible (every slot already carries a Boulder, or
   every uncovered slot is staged), that stone's landing deals damage only -- no Boulder, no refusal, no
   other consequence.
6a. **(`6-5e/R18`, C2) Once the cast COMPLETES, the burst is COMMITTED**, distinct from the cast lock ruling
    1 describes: a stun landing on the caster between stone 1 and the last stone does NOT stop the
    remaining stones; the caster moves and acts freely for the rest of the burst (no lock, no root); each
    stone still launches from the caster's feet at its own scheduled tick. Caster death, round end and a
    debug reset each cancel every stone not yet launched (no further stones, no partial launch). This is
    the ONLY window in the whole cast/burst where the caster is free while Rocksling's effect is still
    resolving -- ruling 1's lock covers only the CAST, up to and including the strike tick.

### Boulder card

7. Boulder is a COLOURLESS card (not RED, BLUE or GREEN) with exactly one action: playing it (Mode 1) for
   2 mana (authored). Playing it removes the Boulder from its hand slot, and the card it was sitting on top
   of becomes available in that same slot IMMEDIATELY -- no draw delay, no replacement-owed bookkeeping, the
   underlying card is simply uncovered. Boulder has no Mode 4 (no pitch effect, cannot be staged) and no
   Mode 2 / Mode 3 (no unblockable attack, no colour defence) -- every non-Mode-1 press on a Boulder is
   refused exactly as an off-colour or effect-less action already is. Boulder is never a member of any
   deck, is never drawn, is never discarded, and is never dealt at match start or on a reshuffle -- it can
   ONLY ever enter a hand as the direct consequence of a landed Rocksling stone (ruling 6). A Boulder is
   removed (with the card beneath it restored to normal, playable status in the same slot) on round end and
   on a debug reset, exactly like every other per-round hand/board state.
7a. **(`6-5e/R19`, C3) Playing (clearing) a Boulder takes NO cast frame** -- it resolves instantly, on the
    press tick, exactly like every other Mode 1 basic effect with no `cast_seconds` (Boulder authors none).
    Pressed without the 2 mana, it is REFUSED exactly like any other unaffordable card
    (`CastEvaluator.REASON_INSUFFICIENT_MANA`), nothing spent, the Boulder and the covered card both
    unchanged.
7b. **(`6-5e/R26`, G7 -- operator ruling on Boulder's colour representation) Colourless is a NEW
    `Enums.CardColor` member, APPENDED after `GREEN`** (existing ordinals `RED=0`/`BLUE=1`/`GREEN=2`
    unchanged); it is never an orb colour, so `orb_costs`, `ORB_COLORS` and `ORB_INITIALS` stay three long
    and are never indexed by it (Boulder authors no orb cost anywhere, ruling 7's "no Mode 4"). Boulder's
    hand-row swatch renders a neutral GREY, not a positional read of the 3-element `ORB_COLORS` array (the
    new ordinal would index out of range there -- `hud_root.gd:487`). Boulder is authored data under
    `data/cards/` like any other card, so `_derive_card_colors()` (`match_runner.gd:822`) maps it like every
    other card ("nothing is skipped here") -- its colour is the real colourless ordinal, not a silent
    default. Boulder's own price block shows the Mode 1 line only (2 mana, no orb tag); no Mode 4 line, per
    ruling 7's "no pitch effect". Colour counters (any assertion iterating `Enums.CardColor.values()`
    against an authored orb price) never match the colourless ordinal, since Boulder never authors one.
8. Hands stay private, unchanged from the standing `P3` rule: nothing about a Boulder's presence, its
   count, or which slot it occupies is new PUBLIC information. The opposing player's face-down hand
   rendering (2-5) is unaffected; the owning player sees their own Boulder(s) as any other own-hand card is
   already seen.

### Boom (pitch of Rocksling, Mode 4, staging 3 mana, activation 1 RED orb -- both confirmed matching the repo, no change)

9. **(`6-5e/R17`, C1) Boom has NO cast frame: it resolves entirely on the activation tick.** On activation,
   Boom counts the Boulders sitting in the OPPOSING player's hand at that exact instant
   (the activation tick, not the staging tick -- Boulders can be placed or played between staging and
   activation since Boom waits in the pitch zone like any staged pitch card). Each Boulder counted deals 6
   damage (authored) directly to the opposing hero, INSTANTLY -- no projectile is created, and this damage
   is not avoidable by roll, block or deflect (it is not a contact at all, so none of the projectile
   contact rungs apply). Every Boulder counted this way is removed as part of the same resolution, and each
   one's underlying card reappears in its slot exactly as if that Boulder had been played (ruling 7),
   immediately and without a draw delay.
10. If the opposing hand holds ZERO Boulders at the activation instant, activation is REFUSED through a
    NEW board-gate requirement and its own named refusal reason (`6-5e/R27`, G8 -- CORRECTED at the gate,
    B12: `board_requirement_for` gains a new arm reading the OPPOSING player's hand, since the existing
    three arms -- `NEEDS_OWN_LIVING_MINION`, `NEEDS_OWN_CORPSE`, `NEEDS_ENEMY_HERO` -- each read only THIS
    player's board or the captured lock target, and none fits "the opposing hand's Boulder count";
    `NEEDS_ENEMY_HERO` is explicitly NOT reused, since it reads the CAPTURED LOCK target and would
    silently route Boom through lock-on), BEFORE the orb spend: the card stays in the pitch zone, READY,
    and continues counting down toward its own fizzle exactly as any other staged-but-unactivatable card
    does; the staging mana (3) that was already spent at staging time is NOT refunded by this refusal
    (staging spend and activation refusal are the same two separately-priced events 6-2/6-3a already
    established for every other pitch card). Pressing a COVERED card (any mode) is refused through a
    SECOND, separate new named reason (ruling 17/AC 17), nothing spent, no signal beyond the existing
    refusal channel.

### Corpse Bomb (pitch of Frostbite, Mode 4, staging cost and BLUE orb activation per repo data -- 5 mana + 1 blue orb, confirmed matching the repo, no change)

11. **(`6-5e/R17`, C1) Corpse Bomb has NO cast frame: it resolves entirely on the activation tick.** On
    activation, EVERY LIVING minion the caster currently owns dies -- totems are explicitly NOT minions
    for this effect (and for Deck 1 effects generally, the same reading `6-5b/R5`'s Culling and `6-5b/R6`'s
    Drain already use: a totem is never swept by an own-minion effect unless the effect names totems
    explicitly). Every minion killed this way LEAVES A NORMAL CORPSE, through the exact same corpse-creation
    seat every other minion death in the game already uses (standard corpse duration, subject to Grave
    Ward's per-corpse lifetime extension and consumable by Raise Dead exactly like any other corpse) -- the
    Culling-into-Raise-Dead loop this enables for Corpse Bomb is INTENDED, and the only brake on it is
    Corpse Bomb's own cost (5 mana + 1 blue orb per activation), the same design already accepted for
    Culling/Raise Dead in `deck-1-spec.md`'s own "Balance risks to watch first" list. From EACH minion's
    position at the moment of death, a homing skull launches, addressed at the CASTER's lock-on target
    captured at the activation instant (not at staging) -- an unlocked caster's skulls target the opposing
    hero, exactly as Rocksling's captured-target rule (ruling 3) reads for a cast. Each skull deals 5
    damage (authored). Skulls share Rocksling's stone defence exactly: block grants no mitigation, deflect
    fully cancels a skull, roll and get-up i-frames strip homing without consuming the skull, and a skull
    passes through any minion body that is not its captured target. A skull never places a Boulder --
    Boulders come only from Rocksling stones landing on the opposing hero (ruling 6 is Rocksling-only).
12. If the caster has NO living own minions at the activation instant, activation is refused through the
    same 6-5b no-target rule Culling and Drain already use (the board-gate seat, before the orb spend): the
    card stays in the pitch zone, READY, counting toward fizzle; the staging mana already spent is not
    refunded.

### Shared rules

13. Bloodlust's dealt multiplier (on the caster) and taken multiplier (on whichever hero a stone, Boom hit
    or skull damages), and Vampiric Aura's lifesteal on the caster, all apply to stone damage, Boom's
    instant per-Boulder damage and skull damage -- the same standing rule 6-5c fixed for Honed Bolt and
    6-5d confirmed for Fireball ("melee buffs apply to spell damage" is now the general spell-damage rule,
    not a Fireball-specific one). Boom's damage is not a projectile contact, so it reaches the funnel
    through the same instant-damage seat Drain and Culling already use for their own non-projectile
    damage/healing, not through `_resolve_contacts`.
14. Every new effect this story ships must record, in its own state, everything `6-5f-counterspell` will
    need to undo it later: for a landed Rocksling stone that placed a Boulder, WHICH hand slot received it
    and WHAT card was underneath (so Counterspell can remove the Boulder and know what was covered); for
    Corpse Bomb, WHICH of the caster's minions were converted to corpses and skulls by that activation (so
    Counterspell can identify what it would need to reverse). This story does NOT implement any undo
    logic and does NOT decide Counterspell's semantics -- those are `6-5f`'s. It only ensures the facts
    Counterspell will need are present in hashed, cross-tick state and are not silently discarded once the
    Boulder is placed or the corpse created.
14a. **(`6-5e/R21`, G2) The pending-burst schedule (stones remaining, next launch tick) is ITSELF a new
    hashed cross-tick fact**, added to AC 38 as its own named cause: it decides outcomes across ticks
    (ruling 6a/C2's mid-burst stun/death/round-end/debug-reset cases all read it), the same standard
    `4-3a/R17` applies to any other cross-tick decider. It joins the Golden Prediction as cause 1a and the
    `FORMAT_VERSION` argument.
15. Every number this story introduces is authored `.tres` data, never a literal in `src/` (the
    project-wide rule, unbroken by this story): stone count, stone interval, stone damage, Boom's
    per-Boulder damage, Boulder's own play cost, skull count-derivation (implicit, one per dying minion),
    skull damage. The 6-5d reload rule (`6-5d/R12`, M6: a same-length reorder of `unit_kinds` is REFUSED
    with a named reason while any unit or live projectile record exists) covers stones and skulls exactly
    as it covers Fireball -- no new reload seat, the existing guard's scope already includes any
    hero-sourced projectile record.
16. Visuals for every new thing this story adds (the stone, the skull, the Boulder card face) are
    PLACEHOLDERS only, each visually distinct from the others and from Fireball's existing placeholder --
    no new art assets are authored in this dev pass. Real presentation for the whole 6-5 spell family lands
    in the Tier B presentation story scheduled after `6-5f-counterspell` closes out E6.

### Boulder slow (S1, `6-5e/R28`, operator ruling added 2026-09-28 after the gate)

16a. While a player holds one or more Boulders, that player's walk and run speed (including walk-in-block)
    are slowed by `boulder_slow_per_boulder` (authored `.tres`, default `0.15`) PER Boulder held, stacking
    ADDITIVELY; `0.0` disables the slow entirely. It does not touch roll, attack, stamina or any other
    action. It combines with Frostbite's slow (`RULE_FROSTBITE_SLOW`) MULTIPLICATIVELY. The slow tracks
    the LIVE Boulder count and updates on the SAME tick as every add/remove path: placing (ruling 6),
    clearing/playing (ruling 7), Boom detonation (ruling 9), round end and debug reset (ruling 7's
    teardown). The slow is observable to the opponent by design -- this is ACCEPTED and is NOT a `P3`
    breach (no hand CONTENT is revealed, only a speed effect on the struck-side hero). Dev-pass note: the
    existing Frostbite slow (`RULE_FROSTBITE_SLOW`, `player_state.gd:465`/`:471`, applied in
    `match_state.gd:5994-5998`) is a TIMED rule -- a fixed scalar over a decaying duration window
    (`start_rule`). The Boulder slow CANNOT reuse that seat: it has no duration at all and its multiplier
    is a function of a live, changing COUNT (1, 2, 3+ Boulders), not a single value fixed at start. It is
    its own multiplier, read alongside `RULE_FROSTBITE_SLOW` at the same gait seat (the same
    `state != ATTACKING` gate) and combined by multiplication.

## Acceptance Criteria

### Data

1. `data/effects/rocksling.tres` authors, as flat `CardEffect` fields, `boulders_per_cast = 3`, a stone
   interval duration field (name chosen by the dev pass, default `0.3` s, converted to ticks once at
   application per A1), a per-stone damage field (default `3.0`), and the flight-profile mirror fields
   Fireball already established (`launch_speed`, `homing_turn_rate_degrees_per_second`,
   `acceleration_delay_seconds`, `acceleration_per_second_squared`, `max_speed`, `travel_budget`) -- values
   start from the totem/Fireball profile per 6-5d's own precedent unless the dev pass has a reason to
   diverge (recorded if so).
1a. **(`6-5e/R22`, G3)** `inject_pitch_effects()`'s mirror (`_effect_projectiles`,
   `_effect_projectile_delay_ticks`) is widened to also cover BASIC (Mode 1) effects, not only pitch
   effects -- Rocksling's `rocksling` id is a `_card_effects` entry and needs a resolved flight profile at
   its own launch seat. An effect id present in BOTH the basic and pitch effect maps is refused loudly at
   load (a new `Invariant.check` or equivalent, tested). `projectile_profile_at` /
   `_projectile_acceleration_delay_ticks_at` keep reading the SAME mirror -- one reader, built from two
   sources.
2. `data/effects/boom.tres` authors a per-Boulder damage field (default `6.0`).
3. `data/effects/corpse_bomb.tres` authors a per-skull damage field (default `5.0`) and the same
   flight-profile fields as Rocksling for the skull's homing (mirrored per AC 1a, since Corpse Bomb's
   `corpse_bomb` id is also a basic/pitch-family effect resolving through the same widened mirror --
   the exact field-for-field shape, not merely "reuses or mirrors" left open).
3a. **(`6-5e/R23`, G4)** A skull's launch position is NOT the caster's feet: it is the dying minion's own
   position, resolved by the runner from that unit's actor at the moment of death (the corpse actor still
   exists then), falling back to the caster's feet only if the actor is gone. A NEW explicit
   `ProjectileBoard` seat is added alongside `add_hero_shot` for this (the skull record names the minion it
   came from); `add_hero_shot`'s own invariant ("impossible to create with a kind index by accident") is
   proven to still hold for the new seat too.
4. A new Boulder `CardData` resource is authored under `data/cards/` (colourless: `color` is the NEW
   `Enums.CardColor` member appended after `GREEN`, per `6-5e/R26`/G7 -- not an open choice); its
   `basic_effect` names a new `boulder_discard` (or similarly named) effect authored at 2.0 mana, no
   `pitch_effect`, and it is excluded from every deck composition and every `sorted_ids()` /
   `CardDatabase` iteration that feeds deck-building via the `FIXTURE_IDS`-style exclusion precedent
   (`3-2/AC4` era) -- a const list consulted by deck-building/dealing, NOT a new `CardData` export
   (`CARD_DATA_FIELDS`, `test_card_authoring.gd:83-88`, stays unchanged, per `6-5e/R25`/G6).
4a. **(`6-5e/R26`, G7)** Every exhaustive colour reader in the repo handles the new ordinal named:
   `ORB_COLORS`/`ORB_INITIALS` (`hud_root.gd:87`/`:187`) stay 3-element and are read only by orb-COST
   colour, never card colour, so they are unaffected; `_set_swatch_color` (`hud_root.gd:487`,
   `ORB_COLORS[color as int]`) gets a guard rendering neutral grey for the colourless ordinal instead of
   indexing out of range; `_derive_card_colors()` (`match_runner.gd:822`) maps Boulder like every other
   card (its own "nothing is skipped here" header); every colour-counter assertion (`Enums.CardColor.
   values()`-driven, over authored orb prices) is proven to never match the colourless ordinal, since
   Boulder authors no orb cost.
5. Every new `CardEffect` field's default leaves every other authored effect's behaviour bit-identical (an
   unused number cannot change an outcome) -- the standing rule every prior 6-5 sub-story has upheld.
6. No number introduced by this story is a literal in `src/` (the authoring audit, `test_card_authoring.gd`
   precedent, extended to cover the new fields and the new Boulder card).
6a. **(`6-5e/R25`, G6)** `test_card_authoring.gd`'s every-card-authors-a-priced-pitch census
   (`:392-417`) names Boulder as a NAMED exemption (no Mode 4 at all, ruling 7) rather than authoring a
   fake priced pitch condition; `LIBRARY_COUNT` (`:26`) moves 16 -> 17; the effect-file count (`:430`)
   moves 15 -> 16 for `boulder_discard`'s own effect file.

### Rocksling: cast and burst

7. Casting Rocksling (Mode 1, 4 mana, the existing authored cost, unchanged) uses the 6-5c/6-5d cast frame
   exactly: a stun interrupts (card and mana lost, no stones fire), an ordinary hit does not interrupt, the
   caster stands, cannot act, drops a held block at cast start, refuses card presses, and a caster who
   dies mid-cast or is frozen by round end/debug reset never fires any stone.
8. At cast end, exactly `boulders_per_cast` stones launch from the caster's feet, one after another, each
   authored interval apart, each doing exactly the authored per-stone damage on a landed hit; every stone
   is its own `ProjectileBoard` hero-sourced record (`add_hero_shot`), sharing the burst's one captured
   target address.
9. The target is captured once, at the press tick, per 6-5d's spell-targeting rule (lock-on target;
   unlocked -> opposing hero); every stone in the burst uses that one address; a re-lock or unlock mid-cast
   or mid-burst changes nothing already scheduled.
10. A stone whose captured target has died before that stone's own scheduled launch behaves exactly as a
    Fireball whose target is already dead at launch (6-5d AC 22): placed, launched straight from the hero
    on the launch heading, homes on nothing, damages nothing, expires at its travel budget.
11. Stones pass through any minion or totem body that is not the captured target -- identical to Fireball's
    non-target pass-through (6-5d AC 20).
11a. **(`6-5e/R18`, C2)** Once the cast completes and the burst begins, it is COMMITTED: a stun landing on
    the caster between stones does not stop any stone still queued; the caster is free to move and act for
    the rest of the burst. Caster death, round end and a debug reset each cancel every stone not yet
    launched, and no further stone fires after any of those three. The pending-burst schedule (stones
    remaining, next launch tick) is a hashed cross-tick fact (AC 38, `6-5e/R21`/G2).

### Rocksling: defence and Boulder placement

12. A stone landing on a BLOCKING hero deals its FULL, unmitigated damage -- no block multiplier is applied,
    whether or not the blocking hero faces the stone.
13. A stone landing while a DEFLECT window is open (blocking, facing, stamina paid, exactly as today) is
    fully CANCELLED: no damage, no `hit_landed`, no Boulder placed, `deflect_landed` announced, the caster
    is not stunned by the deflect.
14. A stone dropped by an open `is_iframe_open()` window (roll incl. its grace tick, or get-up) is NOT
    consumed, deals no damage, places no Boulder, and its homing ends on that tick (flies straight
    thereafter) -- identical to Fireball's i-frame rule (6-5d AC 17).
15. A stone landing on a minion or totem target deals damage only through the normal funnel; it never
    places a Boulder.
16. A stone landing on the OPPOSING HERO (a full-damage hit, whether or not the hero was blocking) places
    exactly one Boulder in that hero's hand, in a slot chosen by the match's one seeded gameplay RNG,
    restricted to slots that currently hold no Boulder and are not the originating hand slot
    (`slot_index == pitch.staged_hand_slot(slot)`) of a card the STRUCK player has currently staged in
    their OWN pitch zone (`6-5e/R20`, G1 -- fixes gate B1/B2: the struck player's, not the caster's; the
    predicate is slot-index equality against the pitch record, not "occupied by a staged card", since a
    staged card's `Hand` slot is empty); that determinism is proven by two runs of the same seed producing
    the same slot choice, and two different seeds producing (with overwhelming probability, or provably,
    over the fixture's slot count) different choices.
17. The Boulder sits on top of whatever card already occupied the chosen slot: that underlying card is
    unplayable (every mode of it refused) while covered, and remains in the SAME slot, unmoved, for as long
    as the Boulder covers it.
17a. **(`6-5e/R27`, G8 -- fixes gate B12)** Pressing a covered card, in any mode, is refused through its
    own new named refusal reason -- distinct from every existing refusal token and from Boom's own new
    zero-Boulders reason (AC 28) -- nothing spent, no signal beyond the existing refusal channel, on the
    four hand-slot read paths (`match_state.gd:3588`/`:4176`/`:4497`/`:4620`).
18. If the chosen slot is empty at the instant of placement (a slot mid-draw-delay), the Boulder occupies
    the slot directly; the slot's owed replacement, when it lands, lands underneath the Boulder (covered,
    unplayable) rather than being blocked or redirected elsewhere. Whether a covered slot's underlying card
    counts toward `PlayerState.hand.occupied_count()` (the `hand_size` hashed snapshot key,
    `player_state.gd:684`) is a dev-pass semantic call (M2), measured and recorded, not assumed either way.
19. If no eligible slot exists when a stone lands on the opposing hero (every slot already covered by a
    Boulder, or every uncovered slot is the originating hand slot of a card the struck player has currently
    staged in their own pitch zone, per AC 16's corrected predicate), the stone's landing deals its
    damage only -- no Boulder, no other consequence, no refusal cue (this is not a refused action, it is a
    successful hit that happens to have nowhere to place its Boulder).

### Boulder card

20. Boulder is colourless, has exactly one legal action (Mode 1, play, costing 2 mana authored), and every
    other mode press on it (Mode 2, 3, or 4) is refused through the existing "this card/effect has no such
    action" refusal family, not a new refusal reason.
21. Playing a Boulder removes it from its slot, spends 2 mana, and makes the card underneath immediately
    playable in that same slot -- with NO draw delay and no replacement-owed bookkeeping engaged (the
    underlying card was never removed from the hand; it only becomes visible/playable again).
21a. **(`6-5e/R19`, C3)** Playing a Boulder takes NO cast frame (resolves on the press tick); pressed
    without 2 mana it is refused through `CastEvaluator.REASON_INSUFFICIENT_MANA` like any other
    unaffordable card, nothing spent.
22. Boulder never appears in any deck composition, is never drawn, discarded, or dealt at match start or a
    reshuffle; the only way a Boulder enters a hand is a Rocksling stone landing on that hero (AC 16).
23. Round end and a debug reset both remove every Boulder from every hand, restoring every covered card to
    normal playable status in its own slot, unmoved.
24. No new public information about Boulder presence, count, or slot leaks through any observation surface
    that did not already carry the owning player's own hand contents (the standing `P3` hands-stay-private
    rule, unbroken); the only channel is `PlayerState.cards_changed(hand_ids, ...)`, per-player, rendered
    only in the owning viewport's own hand row.
24a. **(M3, HUD -- derived from rulings 6/7/17, no new design)** `_render_hand_row()`'s branch ladder
    (`hud_root.gd:382-408`) gains a COVERED-SLOT branch: a slot covered by a Boulder renders the Boulder
    (id, colourless grey swatch per AC 4a, Mode-1-only price text), never the card beneath it, and takes
    precedence over the `pending_draw_owed` branch (ruling 6's own "the Boulder occupies the empty slot
    directly, the owed replacement lands underneath it" -- the visible layer is always the Boulder while one
    covers the slot). A covered slot's underlying card is refused on every input path that would act on
    it -- 6-9 click-to-commit and 6-10 mode-toggle included -- the same "every mode of it refused" AC 17
    already requires, extended to the presentation/selection seats that read a slot's playability.
    Boulder's own row cycles no mode (its one legal mode has nothing to toggle to).

### Boom

25. Activating a staged Boom (1 red orb, the existing spend/discard/clear/replacement-owed sequence
    6-2/6-3a already establish for every pitch card) counts the Boulders present in the OPPOSING hand at
    that exact instant.
26. Each Boulder counted deals exactly the authored per-Boulder damage to the opposing hero, applied
    directly (not as a projectile, not through `_resolve_contacts`, not through any hitbox/hurtbox seat) --
    and this damage cannot be avoided by a roll, a block, or a deflect (none of those seats are consulted
    at all).
27. Every Boulder counted this way is removed as part of the same resolution, and each one's underlying
    card reappears, immediately playable, in its own slot -- the same "uncover" behaviour as AC 21, applied
    to every counted Boulder in one resolution.
28. If the opposing hand holds zero Boulders when Boom activates, activation is refused through a NEW
    board-gate requirement and its own named refusal reason (`6-5e/R27`, G8 -- fixes gate B12, NOT
    `NEEDS_ENEMY_HERO`/`REASON_NO_TARGET`, which reads the captured lock target): before the orb spend, the
    card stays READY in the pitch zone and continues its fizzle countdown; the mana already spent at
    staging is not refunded by this refusal.
28a. **(M4)** `CardEffectResolver` gains a resolver outcome row (`OUTCOME_*`) and an apply arm for
    Boulder's own `boulder_discard`-style basic effect, dispatched by id exactly as every other Deck-1
    effect is (`card_effect_resolver.gd:157-177`/`:206`/`:232-234`), pinned by
    `test_spell_framework.gd`/`test_card_effect_resolution.gd`.

### Corpse Bomb

29. Activating a staged Corpse Bomb (1 blue orb, the existing sequence) kills every LIVING minion the
    caster currently owns; totems owned by the caster are unaffected (they are not minions for this
    effect).
30. Every minion killed this way leaves a normal corpse through the SAME corpse-creation seat every other
    minion death uses -- standard corpse duration, extendable by Grave Ward, consumable by Raise Dead, no
    bespoke corpse variant.
31. From each converted minion's position at the moment of death, one homing skull launches, addressed at
    the caster's lock-on target captured at the ACTIVATION instant (unlocked -> opposing hero); every
    skull from one activation shares that one captured address.
32. Each skull deals the authored per-skull damage on a landed hit, through the same funnel seat as
    Rocksling's stones, and shares stone's exact defence profile: block grants no mitigation, deflect fully
    cancels (no damage, no skull consumed further), roll/get-up i-frames strip homing without consuming the
    skull, and a skull passes through any minion that is not its captured target. A skull never places a
    Boulder.
33. If the caster owns no living minions when Corpse Bomb activates, activation is refused through the same
    no-target path (`6-5b`): before the orb spend, the card stays READY, fizzle countdown continues, staged
    mana is not refunded.

### Shared

34. Bloodlust's dealt multiplier (caster) and taken multiplier (struck hero), and Vampiric Aura's lifesteal
    on the caster, apply to stone damage, Boom's per-Boulder instant damage, and skull damage -- the same
    standing rule already proven for Honed Bolt and Fireball, extended to a non-projectile instant-damage
    seat for Boom specifically (Boom is not a contact).
35. Nothing in this story adds a second `_physics_process`, reads `Input.*` outside `src/controllers/`, or
    introduces a nondeterministic source inside `src/state/` (`test_architecture_invariants.gd` stays
    green).
36. The 6-5d reload refusal (M6: a same-length `unit_kinds` reorder is refused while any unit or live
    projectile record exists) is proven to still cover a live stone and a live skull record, not only a
    Fireball record.
37. Every stone, skull and the Boulder card face renders a visually DISTINCT placeholder (from each other
    and from Fireball's existing placeholder) -- no new art assets are added.
37a. **(S1, `6-5e/R28`)** While a player holds exactly 1, 2 and 3 Boulders (three separate measured cases),
    that player's walk and run speed (block-walking included) are slowed by `boulder_slow_per_boulder`
    additively per Boulder, gating on the same `state != ATTACKING` carve-out `RULE_FROSTBITE_SLOW` uses;
    roll, attack and stamina are untouched. `boulder_slow_per_boulder = 0.0` disables the slow entirely
    (proven with an explicit case). Under simultaneous Frostbite, the two slows COMBINE MULTIPLICATIVELY
    (proven with an explicit case). The slow updates on the same tick as every Boulder count change:
    placing (a stone lands), clearing (a Boulder is played), Boom detonation, round end and debug reset
    (each proven as its own case).
37b. **(M1)** Every Boulder placement is the SECOND consumer of `_rng` (`_shuffle_deck()`,
    `match_state.gd:5591-5592`, is the only consumer today) -- proven with a test that a Boulder placement
    advances `_rng`'s own state, that `rng_state` (the hashed snapshot key, `:1432`) moves on any
    placement, and that every subsequent `_reshuffle_discard_into_deck` call (`:5567-5569`) produces a deck
    order the pre-story code would not have (recorded as its own Golden Prediction cause, not assumed a
    non-cause).

### Determinism, replay, format

38. Every new cross-tick fact this story creates is snapshotted and hashed, or is a pure function of hashed
    facts (argued in Dev Notes if so): the Boulder-covers-card relationship per hand slot (which slot, and
    what id is underneath) for every player; the pending-burst schedule (stones remaining, next launch
    tick, `6-5e/R21`/G2, AC 11a); and Corpse Bomb's per-activation record of which minions were converted,
    named as OWNER, the list of DEAD MINION INDICES, and the ACTIVATION TICK -- or, if the dev pass proves
    it a pure function of the corpse container's own already-hashed fields, that derivation is written down
    rather than merely asserted (M6: AC 38's prior "to the extent 6-5f will need it" wording was not a
    checkable bound; this is). The per-player snapshot key set (currently 40) and every existing pinned test
    that enumerates it move deliberately, once, with the cause named.
39. `RecordFile.FORMAT_VERSION` PREDICTED to move 16 -> 17 with a HARD refusal of a v16 file (the recorded
    shape gains fields whose absence or default would replay a Boulder or a Corpse Bomb activation as a
    no-op); measured, not assumed, and recorded if the prediction is wrong.
40. Every new fact required for `6-5f-counterspell` to later undo a Boulder placement or a Corpse Bomb
    conversion (ruling 14) is present in hashed state at the moment this story closes -- proven by a test
    that reads the fact back, not merely by its presence compiling.
41. A recorded match containing a Rocksling burst that places at least one Boulder, a Boom activation that
    detonates at least one Boulder, and a Corpse Bomb activation that converts at least one minion, replays
    to the identical final hash and the identical record (`test_replay_identity.gd`'s standing discipline).

### Regression

42. Every 6-5a/6-5b/6-5c/6-5d behaviour not named above is unchanged: Fireball, Honed Bolt, the four
    own-minion/corpse effects, every buff, the totem's own projectile shot (still unaffected by Bloodlust
    DEALT/Vampiric Aura per 6-5d AC 36), and Counterspell's continued deferred no-op status (owned by
    `6-5f`, untouched here).
43. `DEFERRED_EFFECT_OWNERS` no longer names `rocksling`, `boom`, or `corpse_bomb`; the pin in
    `test_spell_framework.gd` moves with it, and only `counterspell` remains deferred (owned by `6-5f`).

## Non-Goals

- Counterspell and any actual undo mechanism for a Boulder or a Corpse Bomb conversion -- `6-5f` implements
  the undo; this story only ensures the facts it will need exist in hashed state (ruling 14, AC 40).
- Real VFX, clips, audio for the stone, the skull, the Boulder card, or Corpse Bomb's conversion --
  placeholders only, owed to the Tier B presentation story after `6-5f`.
- Any change to melee, unblockables, the colour counter, roll, stamina, or any 6-5a/6-5b/6-5c/6-5d number
  beyond what the two confirmed-matching costs above already are.
- Deck 2, any new hand-size or deck-size number, any change to `max_mana`.
- A new colourless-card mechanism reused by anything beyond Boulder -- if the dev pass's Boulder
  representation turns out to want a new public API or a new `src/` folder, that is a design decision: stop
  and ask, per the project's Agent Autonomy rule.

## Golden Prediction (predictions to MEASURE, not claims)

Baseline to measure and save outside the repo BEFORE any edit: golden
`de3589ffa5012ed8ba368ae3f51e52e992ca1bd0f36ad430d509b43646eaf289`, `RecordFile.FORMAT_VERSION` 16,
per-player snapshot keys 40, the pitch snapshot shape, hand snapshot shape, suite (state + integration
counts) -- re-measure at the dev pass; do not trust any figure in this file.

**PREDICTED to MOVE.** Causes to be separated and measured each in isolation (the 6-5a/6-5b/6-5c/6-5d
method: erase the new keys/fields from `to_snapshot()` with every other change in place; the hash must
return to the baseline exactly):

1. **Hand snapshot: the Boulder-covers-card relationship per slot.** Whatever shape the dev pass picks (a
   parallel per-slot array, a wrapper object, a second container) is a new hashed fact per player. At rest
   (no Boulder ever placed in the fixture) it must read as the CURRENT hand snapshot shape unchanged --
   measure the resting-empty case as its own sub-cause.
1a. **(`6-5e/R21`, G2) The pending-burst schedule** (stones remaining, next launch tick) is a NEW hashed
   cross-tick fact absent from the story's original Prediction -- fixes gate B5. At rest (no cast in
   flight) it must read as no burst pending; measure the mid-burst case (a cast whose stones are still
   queued at the snapshot tick) as its own sub-cause.
2. **Corpse Bomb's per-activation conversion record**, if the dev pass stores it as cross-tick state rather
   than deriving it purely from the corpse container's own existing fields (argued as a non-cause if so,
   per ruling 14 / AC 40's "or is a pure function of hashed facts" allowance).
3. **`ProjectileBoard`: a burst of several hero-sourced records from one cast/activation**, distinct from
   6-5d's one-shot-per-cast shape only in COUNT, not in per-record shape -- predicted a NON-cause of the
   snapshot SHAPE (the same `_effect_ids`/`_damage`/kind/source fields, just more array entries), but the
   RESTING content of a fixture that fires a burst is a behavioural mover, not a shape mover -- measure
   both readings separately.
4. **Which pins move** (predicted, not claimed): `EXPECTED_PLAYER_SNAPSHOT_KEYS` (40) in
   `test_draw_delay_and_reshuffle.gd` and `test_card_observation.gd`'s copy, if the hand fact is a NEW KEY
   rather than an EXTENSION of an existing one (the dev pass records which and why, on the 6-5d "extend a
   key vs add a key" precedent -- cause 2 of that story's own Golden Prediction); `test_pitch_staging.gd` /
   `test_pitch_changed.gd` if Boom or Corpse Bomb's activation record gains a per-slot detail beyond what
   every other pitch activation already carries.
5. **New refusable outcomes -- CORRECTED at the gate (`6-5e/R27`, G8, fixes gate B12).** TWO new refusal
   reasons ARE predicted: Boom's zero-Boulders board-gate requirement (a NEW arm, not a reuse of
   `NEEDS_ENEMY_HERO`, AC 28) and the covered-card refusal (AC 17a). Corpse Bomb's zero-minions refusal
   DOES reuse the existing `NEEDS_OWN_LIVING_MINION` pattern and stays a non-cause. Under the standing
   `SC/R6` boundary (a pressed action made refusable moves the golden if the recorded sequence presses it)
   Boom's new gate and the covered-card refusal are both PREDICTED causes, measured, not assumed non-causes
   as the story originally claimed.
5a. **(M1) `_rng`'s second consumer.** Every Boulder placement advances `_rng` and moves `rng_state`
   (`match_state.gd:1432`) -- measured as its own cause, distinct from every prior story's golden movers,
   since `_rng` has had exactly one consumer (`_shuffle_deck`) through every prior 6-5 sub-story.
5b. **(M2) `hand_size` semantics.** Whether a covered slot's underlying card counts toward
   `hand.occupied_count()` (the existing `hand_size` hashed key, `player_state.gd:684`) is measured, not
   assumed: an EXISTING key's VALUE may move on a Boulder placement even where cause 1's NEW key reads
   unchanged.
5c. **(S1, `6-5e/R28`) The Boulder slow.** Measured as its own cause: whether the live Boulder count needs
   its own new hashed field, or is a pure function of the already-hashed Boulder-covers-card relationship
   (cause 1) -- the dev pass argues and records which, per ruling 14's allowance.
6. **Non-causes to confirm (`BC/R3`):** the authored `.tres` numbers for stone count/interval/damage,
   Boom's per-Boulder damage, Corpse Bomb's per-skull damage, and Boulder's own play cost -- the golden
   builds its effects in-test and never loads `data/effects/`; confirm the injection SHAPE (new
   `CardEffect` fields) does or does not move the hash apart from causes 1-3.
7. **`FORMAT_VERSION` PREDICTED 16 -> 17** (AC 39). A record carries inputs and content, never a hash; the
   dev pass measures and records if the prediction is wrong (as 6-5d's own prediction for cause 4 was
   correct but the mechanism differed from the Open Question's guess).
8. **Intake:** none predicted -- no new controller-read input channel; Boulder placement and Corpse Bomb's
   skull targets are both derived state, not a new intent field.

**Measure, do not assume:** full suite before any edit and after, golden hash / key counts /
`FORMAT_VERSION` in both runs, files saved outside the repo. The number of re-baselines is NOT predicted in
advance (unlike 6-5d's "exactly one") because this story ships three effects at once with at least one new
hand-shape cause; report the actual count and separate every cause exactly as done above.

## Live Smoke (operator, two pads, flip config `[3,3]`)

Flip `slot_controller_kinds = Array[int]([3, 3])` (two gamepads: two killable, human-driven slots).
**Rocksling, Boom's instant damage and Corpse Bomb's skulls can all kill, so R-D6 is RE-INVOKED for this
story** (its acceptance is spent on use and is re-invoked per story against a killable human-driven slot:
decision-log `R-D6` entries, `2-1/R2`, `6-1c/R4`). The binding editor-collateral procedure (`6-1c/R4`),
restated verbatim as `6-5b`, `6-5c` and `6-5d` did:

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins -- not earlier in
  the session.

1. **Rocksling cast and burst.** Casting Rocksling shows the shared cast pose, the caster is locked in
   place for the cast duration, and at cast end the authored number of stones leave the caster's feet, one
   after another, at the authored interval, each visually distinct from a Fireball.
2. **Stone defence.** Blocking a stone: full damage lands regardless. A perfect deflect: the stone vanishes,
   no damage, no Boulder. A rolled/got-up dodge: the stone flies past and expires, no Boulder.
3. **Boulder appears.** A stone that lands on your own hero (as the target) visibly places a Boulder card
   somewhere in your own hand (your own hand is not face-down to you); it covers whatever card was there.
4. **Boulder play.** Playing the Boulder for its authored cost removes it, and the covered card underneath
   is immediately available with no delay.
5. **Boom.** Stage and activate Boom with at least one Boulder present in the opponent's hand: each Boulder
   deals its damage instantly (no projectile visible), and each covered card underneath reappears in the
   opponent's hand at the same instant (the opponent sees their own hand recover).
6. **Boom no-target.** Activate Boom with zero Boulders present: the activation is refused, the card stays
   in the pitch zone and its countdown continues (no crash, a cue if one is authored).
7. **Corpse Bomb.** Activate Corpse Bomb with at least one living own minion: every living own minion dies,
   leaves a corpse, and a skull launches from its position toward the caster's locked target (or the
   opposing hero if unlocked); the skull(s) home and land or are defeated exactly as a stone does.
8. **Corpse Bomb no-target.** Activate Corpse Bomb with no living own minions: activation is refused, the
   card stays staged.
9. **Buffs.** Under Bloodlust, stone/Boom/skull damage is doubled and the caster takes double when struck by
   one; under Vampiric Aura, the caster is healed from stone, Boom and skull damage they deal.
10. **Regression.** Fireball, Honed Bolt, every 6-5a/6-5b buff and own-minion effect, and a Combat totem's
    own shot all behave as before; no crash, no assert; fps stable with a Rocksling burst and a multi-skull
    Corpse Bomb activation both in flight at once.
11. **Lethal.** A Rocksling stone, a Boom activation, and a Corpse Bomb skull each independently kill a low
    target cleanly (R-D6): the round ends normally, no leftover stun/root state.
12. **Legibility.** The stone, skull and Boulder placeholders are each visually distinguishable from one
    another and from Fireball at a glance (`PROC/R8`; judged live, not by character count).
13. **Boulder slow (S1).** Holding a Boulder visibly slows walk and run (and walk-in-block); holding a
    second and third Boulder slows further; playing/losing Boulders speeds the holder back up on the same
    instant; a Boulder held together with an active Frostbite slow is visibly slower than either alone.

## Tasks / Subtasks

- [ ] **Task 1: Baseline (before any edit).** Save outside the repo: suite counts, golden,
  `FORMAT_VERSION`, per-player key count (40), hand snapshot shape, pitch snapshot shape,
  `git rev-parse HEAD`. (AC 38-41)
- [ ] **Task 2: Data.** Author `boulders_per_cast`, the stone interval, per-stone/skull/Boom damage fields
  and the flight-profile mirror on `rocksling.tres` / `boom.tres` / `corpse_bomb.tres`; author the new
  colourless Boulder `CardData` (the new `CardColor` member) + its `boulder_discard`-style basic effect
  (2 mana) + its resolver outcome row (M4); exclude Boulder from every deck-composition/deal path via the
  `FIXTURE_IDS`-style const list, no new `CardData` field; author `boulder_slow_per_boulder` (S1, default
  0.15) in `balance_config.tres`. (AC 1-6a, 20-22, 28a, 37a)
- [ ] **Task 3: Boulder mechanism.** Design and implement the per-slot "Boulder covers a card" data shape
  on `Hand` (or a sibling container) -- fill/remove/uncover, the covered-card-unplayable rule (incl. its
  own new refusal reason, AC 17a), the RNG-seeded eligible-slot pick restricted to uncovered slots that are
  not the struck player's own staged pitch-zone slot (AC 16, `6-5e/R20`), the mid-draw-delay case (Boulder
  occupies the hole, the owed refill lands underneath it), round-end and debug-reset teardown; measure and
  record `hand_size`/`occupied_count()` semantics (M2) and the `_rng` second-consumer consequence on
  `rng_state` and later reshuffle order (M1). Resolve Open Question 1. (AC 16-19, 21-24, 37b)
- [ ] **Task 4: Rocksling burst + mirror widening + skull launch seat.** Widen `inject_pitch_effects()`'s
  mirror to cover basic (Mode 1) effects, with the id-collision load refusal (AC 1a, `6-5e/R22`/G3); add the
  new minion-sourced launch seat alongside `add_hero_shot` for skulls (AC 3a, `6-5e/R23`/G4, with the
  minion-actor-then-caster-feet fallback); multiple `ProjectileBoard` records from one cast strike/
  activation, scheduled at the authored interval, each carrying the captured target and the per-shot
  damage; the launch-tick-dead-target degrade reused from Fireball; the pending-burst schedule as hashed
  cross-tick state (AC 11a, `6-5e/R21`/G2) with its cancellation on caster death/round end/debug reset
  (`6-5e/R18`, C2). Remove `rocksling`/`boom`/`corpse_bomb` from `DEFERRED_EFFECT_OWNERS`. (AC 7-11a, 43)
- [ ] **Task 5: Stone/skull defence rung.** The new "block does not help" contact rule (a per-effect switch
  or an implied property -- mechanism choice, recorded); the on-hero-hit Boulder-placement side effect
  wired to the existing contact resolution seat; the on-unit-hit damage-only path; deflect-cancels and
  i-frame-drops reused from Fireball's existing rungs. (AC 12-15)
- [ ] **Task 6: Boom.** No cast frame (`6-5e/R17`, C1); a new board-gate requirement + refusal reason
  reading the OPPOSING hand's Boulder count, NOT `NEEDS_ENEMY_HERO` (AC 28, `6-5e/R27`/G8); activation
  counts opposing Boulders at that instant, applies per-Boulder instant damage through the Bloodlust/
  Vampiric Aura funnel (the non-projectile instant-damage seat Drain/Culling already use), removes each
  counted Boulder and uncovers its card. (AC 25-28, 34)
- [ ] **Task 7: Corpse Bomb.** No cast frame (`6-5e/R17`, C1); activation kills every living own minion
  (totems excluded), routes each through the existing corpse-creation seat, launches one skull per
  converted minion at the captured activation-instant target via the new minion-sourced seat (Task 4);
  zero-minion refusal on the 6-5b no-target pattern (`NEEDS_OWN_LIVING_MINION`, unchanged). (AC 29-33, 34)
- [ ] **Task 7a: Boulder slow (S1).** `boulder_slow_per_boulder` read alongside `RULE_FROSTBITE_SLOW` at
  the gait seat (`match_state.gd:5994-5998`), combined by multiplication, updated on every Boulder
  add/remove path (placing, clearing, Boom detonation, round end, debug reset); NOT built on `start_rule`
  (no reuse, `6-5e/R28`/S1's own Dev Notes argument). (AC 37a)
- [ ] **Task 7b: HUD covered/Boulder rendering (M3).** `_render_hand_row()`'s new covered-slot branch,
  precedence over the owed-refill branch, Boulder's own grey-swatch/Mode-1-only price row, and the
  click-to-commit/mode-toggle refusal on a covered slot. (AC 24a)
- [ ] **Task 8: Counterspell facts (ruling 14).** Ensure the Boulder-slot/covered-card fact, the
  pending-burst schedule and a per-activation Corpse Bomb conversion record (owner, dead indices,
  activation tick, or its pure-function argument, M6) are present in hashed state, readable by a test,
  ahead of `6-5f`. (AC 38, 40)
- [ ] **Task 9: M6 coverage.** Confirm the existing 6-5d reload refusal still covers a live stone and a live
  skull record; add a test if the existing one does not already generalize. (AC 36)
- [ ] **Task 10: Presentation minimum.** Three new placeholders (stone, skull, Boulder card face), each
  visually distinct; poll-shaped, no new observation seam beyond what Fireball already established. (AC 37)
- [ ] **Task 11: Tests.** New: `test_rocksling.gd` or equivalent (AC 7-19), `test_boulder.gd` or equivalent
  (AC 20-24), `test_boom.gd` (AC 25-28a), `test_corpse_bomb.gd` (AC 29-33), the shared-buff assertions (AC
  34) extended into whichever of the above fits, the M6-generalization test (AC 36), the Boulder-slow tests
  (AC 37a, S1), replay identity (AC 41), the authoring audit extension (AC 6, 6a), `test_corpses.gd`'s
  caller-count pin update (G5), `test_own_minion_spells.gd`/`test_deck_reshuffle.gd`/the six HUD test files/
  `test_replay_surface_pins.gd`/`test_architecture_invariants.gd`/`test_card_effect_resolution.gd` (M1-M5).
  Update the table below with actual filenames used. Mutation proofs restore from a copy outside the repo,
  SHA256-verified first.
- [ ] **Task 12: Golden.** Isolate causes 1, 1a, 2, 3, 5, 5a, 5b, 5c (and any the dev pass finds) by erasing
  new keys/fields with every other change in place; confirm non-causes; record the actual re-baseline
  count; `FORMAT_VERSION` 17 predicted, confirm or correct.
- [ ] **Task 13: Close.** Second full suite run, invariants green, `git diff --stat`, Dev Agent Record. The
  deck-1-spec amendment (below) is written at authoring, in THIS pass, as required. The decision-log
  close-out and the board promotion to `done` are the operator's gate, after a separate readiness-gate
  pass promotes this story to `ready-for-dev`.

## Tests expected to break or need updating

Found by reading the named files at authoring; the dev pass confirms and updates this table with actual
outcomes.

| Test | Why it is expected to move |
|---|---|
| `test_card_play.gd` (`test_basic_cast_spends_discards_and_refills_in_one_tick`, the "slot 1 was refilled in place" assertion and its neighbours) | the Boulder-covers-card mechanism changes what "a slot holds a card" can mean; every hand-mutation assertion that assumes exactly one id or EMPTY per slot needs re-reading against the new shape |
| `test_deck_and_hand.gd` (`test_hand_fills_to_hand_size_from_the_top_of_the_shuffled_deck`, `test_hand_and_deck_expose_no_play_or_discard_path`, `test_hand_never_names_hand_size_or_the_balance_config`) | Boulder is authored data that never enters a deck; if `Hand` gains any new method for the cover mechanism these negative guards must still pass unbroken, or be narrowed deliberately with the cause named |
| `test_draw_delay_and_reshuffle.gd` (STORY 4-0 slot-stability section; `EXPECTED_PLAYER_SNAPSHOT_KEYS`) | the mid-draw-delay Boulder case (ruling 6/AC 18) interacts directly with the pending-draw seat this file owns; the 40-key set is predicted to move (Golden Prediction cause 1/4) |
| `test_card_observation.gd` | its own copy of the player snapshot key set moves in lockstep with `test_draw_delay_and_reshuffle.gd`'s, per the standing "both were red before this edit" mechanism used eight times already |
| `test_card_authoring.gd` (`LIBRARY_COUNT` `:26` 16->17; `:392-417` every-card-priced-pitch census, named Boulder exemption; `:430` effect-file count 15->16; `CARD_DATA_FIELDS` `:83-88` confirmed UNCHANGED) | a new colourless card and new effect fields; four distinct pins move or are confirmed unmoved, named individually per `6-5e/R25`/G6 (fixes gate B10) |
| `test_corpses.gd:240` `test_the_death_seat_has_exactly_three_callers_and_no_rival_corpse_writer()` | a SOURCE SCAN counting `kill_at(` in `unit_board.gd`+`match_state.gd`; Corpse Bomb is the FOURTH caller, an intended 3->4 update, not the `test_unit_damage_and_death.gd` hedge the story originally named (`6-5e/R24`/G5, fixes gate B9) |
| `test_own_minion_spells.gd` | Culling/Drain regression against a fourth death-seat caller now existing (M5) |
| `test_deck_reshuffle.gd` | reshuffle order changes once any Boulder placement has consumed `_rng` (M1) |
| `test_card_hud.gd`, `test_card_tint_live.gd`, `test_card_mode_lift.gd`, `test_card_selection_indicator.gd`, `test_card_mode_toggle.gd`, `test_click_to_commit.gd` | the covered-slot HUD branch and the covered/Boulder click-to-commit/mode-toggle refusal (M3, AC 24a) |
| `test_replay_surface_pins.gd`, `test_architecture_invariants.gd` | source-scan guards, including the `shuffle_with_rng(` call-site count (M1) |
| `test_card_effect_resolution.gd` | Boulder's new resolver outcome row and apply arm (M4, AC 28a) |
| `test_spell_framework.gd` (`DEFERRED_EFFECT_OWNERS`, the deferred-id list) | `rocksling`, `boom`, `corpse_bomb` leave the deferred table; only `counterspell` remains |
| `test_pitch_staging.gd`, `test_pitch_changed.gd`, `test_deck_and_hand.gd` (pitch-effect-map-read-once pin) | Boom and Corpse Bomb activation now do real work (counting Boulders, killing minions) instead of the shared deferred no-op; any new per-activation record shape needs the same "read once" discipline checked |
| `test_determinism.gd` | golden re-baseline (count not predicted in advance, unlike 6-5d) |
| `test_record_file.gd`, `test_replay_identity.gd` | `FORMAT_VERSION` 16 -> 17 predicted; new content round-trip (Boulder placement, Corpse Bomb conversion) |
| `test_intent_recorder.gd` | only if a new intake channel is added (predicted: none) |
| `test/integration/test_card_database.gd`, `test_deck_injection.gd` | a new card (Boulder) exists in `data/cards/`; must be confirmed excluded from any full-scan assumption these files make |
| `test_fireball.gd`, `test_spell_targeting.gd` | regression-only: confirm the shared spell-targeting and hero-sourced-projectile machinery is unaffected by the burst extension |
| `test_unit_damage_and_death.gd` (or wherever the 4-3a corpse-creation seat is pinned) | Corpse Bomb routes through the same seat; a new caller is a fact worth a regression assertion there |
| `test_discard_pile.gd` | Boulder never reaches the discard pile; a negative guard may need extending |
| `test_spell_framework.gd` (Frostbite slow test names) | the Boulder slow reads the SAME gait seat as `RULE_FROSTBITE_SLOW`; the combination test is new but the seat's existing pins are re-read against a second multiplier (S1) |

## Dev Notes

- **Why the Boulder mechanism is Open Question 1, not a locked design:** the operator's ruling fixes the
  BEHAVIOUR completely (rulings 6-8) but `Hand` as shipped (4-0) has no concept of "two things in one
  slot." The dev pass owns whether this is a parallel array on `Hand`, a small wrapper value type
  replacing the bare `StringName` per slot, or a sibling per-player container keyed by slot index. Whatever
  is chosen must keep `Hand`'s own invariants (`fill_at` refuses an occupied slot, `remove_at` refuses an
  empty one) meaningful for the UNDERLYING card, which never actually leaves its slot while covered -- the
  covering/uncovering is additive state, not a second hand mutation.
- **Boulder's colour -- RESOLVED at the gate (`6-5e/R26`, G7), not an open choice.** `Enums.CardColor` has
  exactly `{RED, BLUE, GREEN}` today; the operator ruling appends a FOURTH member rather than leaving
  `color` unread, because "unread" turned out to be false on inspection: `_derive_card_colors()`
  (`match_runner.gd:822`) maps the whole library including Boulder, and `hud_root.gd`'s `_set_swatch_color`
  indexes `ORB_COLORS` directly by card colour ordinal (`:487`) -- an unread-field plan would have shipped
  Boulder as a silent RED swatch. AC 4a lists every exhaustive colour reader and how each handles the new
  ordinal.
- **The eligible-slot originating-record (G1) is narrower than the story first assumed.** Only the STRUCK
  player's own PITCH-ZONE staging has a distinct in-flight record (`pitch.staged_hand_slot(slot)`) that
  leaves a slot silently empty with no `pending_draw_owed` entry. A card mid-CAST-FRAME or mid-CHARGING
  (Mode 2 commit) is NOT a second protected case: both `_resolve_basic_cast` and `_resolve_unblockable_cast`
  remove the card AND append `pending_draw_owed` for that slot in the same tick as the press/commit, so
  those slots are already ordinary mid-draw-delay holes by the time either state is visibly playing --
  exactly the case ruling 6/AC 18 already makes eligible. No new tracking is added for those two cases;
  inventing one would contradict the repo's own timing.
- **The Boulder slow (S1) does not reuse `RULE_FROSTBITE_SLOW`.** That seat is a TIMED rule (a duration
  window plus one fixed scalar, `start_rule`); the Boulder slow is PERSISTENT and its multiplier is a
  function of a live, changing Boulder count, which has no duration to start or expire. It is read as its
  own multiplier at the same gait seat and combined with Frostbite's by multiplication.
- **Why Boom's damage is NOT a projectile contact:** ruling 9 is explicit -- "no projectile, not avoidable
  by roll, block or deflect." This is the same shape as Drain's self-heal and Culling's per-minion mana
  grant: an INSTANT effect applied directly at the activation seat, through `_funnel_damage` for the
  Bloodlust/Vampiric Aura reach (ruling 13/AC 34) but never through `_resolve_contacts`.
- **Why stones and skulls share one defence rung:** ruling 11 says skulls have "Same defence as stones" --
  do not implement two copies of "block does not help / deflect cancels / i-frames strip homing." One rung,
  parameterised by nothing effect-specific beyond the damage figure already on the record.
- **Order at activation** stays the 6-2/6-3a/6-5d precedent: gates -> board gate (the no-target refusal, for
  both Boom and Corpse Bomb) -> orb spend -> discard -> `pitch.clear` -> apply -> resolved-card record ->
  replacement owed at activation.
- **Boulder's mana cost (2) and Rocksling/Boom/Corpse Bomb's confirmed-matching costs** are all `.tres`
  fields, never literals (AC 6, ruling 15).
- **Read first** (UPDATE files): `match_state.gd` (`_resolve_pitch_activate`, `_resolve_cast_strikes`, the
  minion-death/corpse-creation seat from 4-3a, `_funnel_damage`, `_resolve_contacts`, `_advance_projectiles`,
  the own-minion no-target refusal seat from 6-5b, the snapshot), `hand.gd`, `player_state.gd`,
  `projectile_board.gd`, `card_effect.gd`, `card_effect_resolver.gd`, `src/systems/record_file.gd`,
  `match_runner.gd` (`_spawn_missing_projectile_actors`, `_gather_projectile_facts`, `_projectile_profile`,
  the burst-scheduling seat this story adds).
- **Suite:** `bash test/run_all.sh` with `GODOT=/c/Godot/godot.exe` via the Bash tool (WSL is broken).

### Project Structure Notes

- New card data under `data/cards/boulder.tres` (or the dev pass's chosen name); new/extended effect data
  under `data/effects/`. Tests under `test/state/` and `test/integration/`, filenames per Task 11. A new
  public API or `src/` folder for the Boulder-cover mechanism is a design decision: stop and ask, per the
  project's Agent Autonomy rule, if the natural shape reaches beyond `hand.gd`/`player_state.gd`.

### Project Context Rules (extracted from `docs/project-context.md`)

- State / visual separation; integer-tick timing (A1: every new duration converted once at application);
  every number a `.tres` field; feature flags injected into `src/state/`, never read from the service.
- Golden isolation (`BC/R3`): `data/balance/*.tres` is isolated from the golden; a NEW seat or a pressed
  action made refusable is not covered by that isolation and must be measured (Golden Prediction cause 5).
- Mutation proofs restore from a copy taken outside the repo (SHA256 first), never `git checkout --`; full
  suite at open and close, mutation proofs run only the affected file.
- Edit tool only (line-index splice as fallback, never PowerShell `-join`); the Python resolver being
  unavailable does not change this -- it only affects the create-story pass's own tooling, not the dev
  pass's.
- Docs and code never share a commit; ASCII messages via `git commit -F`; never push before the operator
  confirms the log.
- Single rolling backlog, no sprint timeboxes; per-story holds live in `story_notes`, never as an extra
  board status (`STATUS DEFINITIONS` stays locked to `backlog -> ready-for-dev -> done`).

### References

- `docs/planning-artifacts/deck-1-spec.md` (this pass's own amendment, below).
- `docs/implementation-artifacts/6-5d-fireball-and-spell-targeting.md` (the hero-projectile machinery,
  spell-targeting rule, cast frame, `ProjectileBoard.add_hero_shot`), `6-5c-hero-cast-honed-bolt.md` (the
  cast lock itself), `6-5b-corpses-and-own-minions.md` (corpse creation, the own-minion no-target refusal
  pattern, Culling/Raise Dead loop precedent), `6-5a-spell-framework-and-buffs.md` (the funnel, injection
  channels), `4-0-hand-slot-stability.md` (the fixed-width hole-aware `Hand` shape this story must extend
  without breaking).
- `docs/game-architecture.md` (D3, A1, A2, F1, D5); `docs/project-context.md`.
- GDD decision-log `R-D6`, `6-1c/R4`, `SC/R6`, `BC/R3`, `6-5b/R5`/`R6` (own-minion/totem-exclusion
  precedent), `6-5d/R1..R23` (variable-cost cast, hero-sourced projectile, spell targeting).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
