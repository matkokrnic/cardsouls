---
baseline_commit: 92f0dd950e0795f28e70ac6eee5d7ade14ae063e
---

# Story 6.5a: Spell Framework and Buffs

Status: done

<!-- Tier A. Split from 6-5-spell-resolution by operator ruling (2026-09-22) into six sub-stories
(6-5a..6-5f); this is the first. Golden PREDICTED to move (new hashed per-player state), key set
grows, FORMAT_VERSION 12 -> 13 with hard refusal of v12. Authored 2026-09-22 by gds-create-story,
main session only, no subagents, nothing committed. Readiness gate round 1: NOT READY, 11 blocking /
17 non-blocking; fixed in the same session, no second round (6-9 precedent). Promoted to
ready-for-dev 2026-09-22. -->

## Story

As the operator (and later the friends playtest),
I want a named, data-driven card-effect framework plus five working Deck 1 effects (Ruin Vanguard,
Bloodlust, Vampiric Aura, Bloodhound Step, Frostbite) and Deck 1 selected as both players' deck,
so that the seven-card Deck 1 is playable end-to-end now, with the remaining nine Deck 1 effects
inert but harmless, and the later 6-5b..6-5f stories build on a shape that does not have to be
reworked.

## Board note

`sprint-status.yaml`: this session split `6-5-spell-resolution: backlog # Tier A` into six keys, all
`backlog`, per operator ruling (2026-09-22): `6-5a-spell-framework-and-buffs`,
`6-5b-corpses-and-own-minions`, `6-5c-hero-cast-honed-bolt`, `6-5d-hero-and-corpse-projectiles`,
`6-5e-boulder-injection`, `6-5f-counterspell`. `6-5f` inherits `6-5-spell-resolution`'s status of
E6 CLOSE-OUT story and R-SPELL's forcing point (`epics.md` obligation, decision-log `R-SPELL`).
Origin inputs for the split: `C:\dev\_65-inventory.md` (report-only inventory at `92f0dd9`) and
`docs/planning-artifacts/deck-1-spec.md` (operator's Deck 1 spec). This story authors ONLY `6-5a`.
The board value for `6-5a` stayed `backlog` on authoring, per this project's `on_complete` override
(a freshly authored story is NOT auto-promoted to `ready-for-dev`); the separate operator review pass
that promotion needs is the readiness gate recorded below and in the decision-log — `6-5a` is now
`ready-for-dev`.

## Operator Rulings (locked)

- **R1** R-SPELL is discharged by Deck 1 across `6-5a..6-5f`; the three `spell_*` fixture cards
  (`ember_lash`, `frost_dart`, `bramble_snare`) stay dormant — not in the deck list. This is recorded
  as an AMENDMENT of `epics.md:238-240` ("the three `spell_*` fixture cards stop taking the named
  no-op path") — keeping the fixtures dormant changes that line, it does not merely restate
  `R-SPELL`'s letter (`decision-log.md:7829-7843`, `:8070`, `:8234`). The `epics.md` edit itself is
  owed at the `6-5` series close-out (`6-5f`), not in this story.
- **R2** Bloodhound Step: the next roll taken within 5 s of casting travels 3x the normal distance
  in the SAME duration (3x speed, not 3x time); i-frames are 2x but CLAMPED to the roll's duration,
  so the entire roll is invulnerable start to finish. Authored as a distance multiplier 3.0 (operator
  ruling, supersedes the spec's `T[1.5]` at `deck-1-spec.md:31`) and an i-frame multiplier 2.0 clamped
  to the roll's duration; roll duration unchanged. This keeps the `1-9/R3` audit (i-frames <=
  roll duration, `test_balance_authoring.gd`) true rather than violated — a literal 2x i-frame
  window (0.6 s, `data/balance/balance_config.tres:124` `roll_iframe_seconds`, against a 0.5 s roll,
  `:125` `roll_duration_seconds`) would exceed the roll and fail that audit. In ticks:
  `min(2 x 18, 30) = 30`. A roll refused for stamina (`match_state.gd:1440-1443`) does NOT consume
  the armed flag — it persists for the next attempt and is hashed.
- **R3** Bloodlust: for 10 s the caster's hero AND owned minions deal 2x damage and take 2x damage.
  Totems are explicitly NOT minions for any Deck 1 effect (applies to Bloodlust and to every other
  Deck 1 effect that says "minions" — Culling, Drain, Raise Dead in later stories).
- **R4** Vampiric Aura: for 15 s, 50% of damage dealt by the caster's HERO specifically (melee,
  unblockable, and projectile sources) heals the caster. Minion damage and totem damage do NOT
  heal, even though Bloodlust affects minions.
- **R5** Frostbite: the caster's next hero melee hit that lands on the enemy hero, within 6 s of
  casting, slows the enemy hero to 50% movement speed for 4 s. Triggers on the next CONFIRMED hero
  melee hit on the enemy hero, INCLUDING a blocked hit (blocked = confirmed per `1-8`), NOT a
  deflected one. Seat: `_resolve_contacts` after the block branch (`match_state.gd:1969-1971`) with
  `attacker_index == TargetingService.HERO_INDEX`; the deflect path `continue`s at `:1968` before it,
  the i-frame drop earlier. Unblockable landings (`:3692`, `:3755`) and hits on units do not trigger
  or consume it. The slow scales walk (`:4468-4469`), run (`:4466-4467`) and block-walk (`:4461-4465`)
  only — roll, CHARGING, counter travel, and the attack lunge (`:4479`) are NOT slowed. **Spec
  deviation, named:** `docs/planning-artifacts/deck-1-spec.md` §7 text says "walk and run" only; this
  ruling explicitly widens the slow to block-walk too (`match_state.gd:4460-4472`'s `BLOCKING` forces
  `balance.walk_speed` — a slow must scale that seat as well, or a slowed defender could still
  block-walk at full "walk" speed which is not actually slowed).
- **R6** Counterspell's undo mechanism is explicitly NOT built in 6-5a; its semantics are ruled in
  6-5f. 6-5a's effects must be SHAPED for later undo: every timed effect has exactly one stop point
  (a future undo just cancels it), and every one-shot effect returns the delta it actually applied
  (a future undo has something to reverse), even though no undo consumer exists yet.
- **R7** The pitch cost seat is the SHIPPED one from 6-2/6-3a: mana paid at staging
  (`match_state.gd:3158-3164`), orbs spent at activation (`pitch_state.gd:100-101`,
  `match_state.gd:3225-3230`). Do NOT add a mana-at-activation seat — that is out of scope.
- **R8** Buff visuals for 6-5a are grey placeholders; no operator-authored animation clips are
  needed for this story (attack-cast clips like Honed Bolt/Rocksling are owed at 6-5c/6-5d).

## Acceptance Criteria

### Framework

1. An effect is a named, reusable definition authored as a standalone `CardEffect` `.tres` under a
   new `data/effects/` folder; cards reference it by `ext_resource`, the same way `basic_effect` /
   `pitch_effect` already hold a `CardEffect` sub-resource today (`card_data.gd:33,38`) — the only
   change is that the resource lives in its own file and is shared, not inlined per-card.
2. Every effect number (duration, multiplier, cap, heal amount, distance/speed multiplier, slow
   percent) is a FLAT `@export` directly on `CardEffect`, added beside the existing `effect_id`
   field (`card_effect.gd:24`). NO effect subclasses, NO new nested resource `class_name` referenced
   from a `CardEffect` field. `RecordFile._card_effects` rebuilds every injected effect as
   `CardEffect.new()` and repopulates it generically (`record_file.gd:818-822`); its separate
   nested-class whitelist (`_fresh_nested`, `record_file.gd:666-674`) lists exactly three unrelated
   classes (`UnitKindProfile`, `UnitAttackProfile`, `ProjectileProfile`) and would silently drop any
   field on an unlisted nested class on replay. A flat export set on `CardEffect` itself needs no
   entry there and round-trips by the same generic `_resource_values`/`_rebuilt` mechanism every
   other flat-schema resource already uses.
3. `CardEffect` gains an optional `visual_id: StringName` export, default empty, that no file under
   `src/state/` ever reads (mirrors `card_effect.gd`'s own header discipline: state carries
   vocabulary, presentation interprets it).
4. `CardEffectResolver` dispatches on the WHOLE `effect_id`, not a prefix, for every id this story
   defines (Ruin Vanguard's `summon_*` id keeps using the existing `SUMMON_KINDS` prefix-then-table
   shape unchanged, since it is a summon, not a new effect family — `card_effect_resolver.gd:85-89`).
   New non-summon ids that reach this file resolve through a whole-id match to one of: a named
   buff-application outcome (for Bloodlust/Vampiric Aura/Bloodhound Step/Frostbite), or a named
   no-op naming its owning future story (every other Deck 1 id, AC 15 below).
5. The resolver COMPUTES; MatchState APPLIES. Every seat this story adds inside `advance()`'s
   ordered dispatch (the `_resolve_basic_cast`/`_resolve_pitch_activate` shape,
   `match_state.gd:2911-3040`, `:3215-3240`) — starting a timed rule, writing the hashed
   last-resolved-card record, applying a damage-funnel multiplier — is the APPLY half; the resolver
   returns a verdict/outcome and touches no board, pool, or per-player record directly, the same
   discipline `card_effect_resolver.gd`'s header already states for `OUTCOME_SUMMON`.
6. `pitch_effect` gains its own injection channel, mirroring `_derive_card_effects()`
   (`match_runner.gd:662-669`): a sibling `_derive_pitch_effects()` walked by `CardDatabase.sorted_ids()`
   collecting each card's `pitch_effect` (skipping cards with none authored), injected into
   `MatchState` as a second map. `_resolve_pitch_activate` (`match_state.gd:3215-3240`) resolves the
   card's PITCH effect at ACTIVATION — never at staging (`_resolve_pitch_stage`,
   `match_state.gd:3135-3172`, stays cost-only, no effect lookup added there). `inject_pitch_effects`
   ships with `IntentRecorder.capture_inject_pitch_effects`, a new `CHANNEL_*` appended to
   `SOUND_CONTENT_ORDER` (`intent_recorder.gd:58-60`), a `replay_inject_content` arm (`:492-506`), a
   `pitch_effects` key in `RecordFile.REQUIRED_KEYS` plus write (`record_file.gd:590-606`) and
   rebuild (`:725-738`, via `_card_effects`), and the `EXPECTED_INTAKE_SURFACE` pin
   (`test_intent_recorder.gd:109-127`) updated with intent.
   `test_every_match_state_intake_has_a_capture_channel` (`:153`) fails if the channel is missing.
7. `card_cast_resolved(slot, card_id)` (`match_state.gd:94`) gains a third argument carrying the mode
   the card resolved in. It is emitted at all four resolution sites: `:3036` (basic cast), `:3240`
   (pitch activation), `:3425` (unblockable), `:3568` (defense) — UNBLOCKABLE and DEFENSE pass their
   own mode; only BASIC and PITCH activation can carry a `spell_*`/buff id. This is the minimum
   change that lets `TelegraphController.on_card_cast_resolved` (`match_runner.gd:565-567`) tell a
   normal cast of a card from a pitch activation of the SAME card, which today's two-argument signal
   cannot do. Every existing connect/emit site of this signal is updated to the new arity: the inline
   lambda at `match_runner.gd:565`, `test_card_play.gd:64,223`, `test_unblockable_defense.gd:357`,
   `test_pitch_staging.gd:857`, and the direct 2-argument emits in
   `test_cast_success_cue_live.gd:58,65`. No new observation seam is added (the seam family stays at
   TEN, `test_architecture_invariants.gd:319`; `test_architecture_invariants.gd:383` is regex text
   and does not depend on arity).

### Timed rule seat and damage funnel

8. A per-player timed-rule seat: one rule shape, `PlayerState`-owned, with a single stop point per
   active timed effect — generalising the ad-hoc one-`TimingWindow`-per-rule precedent
   (`src/state/timing/timing_window.gd`, the `defense` window shape at `player_state.gd:235-252`). It
   must support at least: Bloodlust (10 s, hero + owned minions, 2x out/2x in), Vampiric Aura (15 s,
   50% hero-damage lifesteal), Bloodhound Step (armed for 5 s, consumed by the next roll, not itself
   a duration-timer on the roll; a roll refused for stamina does NOT consume it, R2), Frostbite
   (armed for 6 s, consumed by the next landed hero melee hit, then a 4 s slow on the TARGET, not the
   caster). One shot vs. duration-window shapes may differ internally, but each is ONE stop point
   (R6) — a testable form, for example one cancel method per rule kind.
9. A damage funnel: outgoing/incoming multipliers apply at every damage seat the inventory's S3 table
   names for Bloodlust — three hero-damage seats (`match_state.gd:1971`, `:3692` (dodged-unblockable
   seat, value computed at `:3689-3690`), `:3755` (landing seat)) and one unit-damage seat (`:2292`),
   plus the existing block/dodge multiplier precedent (`:1969`, `:3689-3690`). The funnel is a single
   function (compute effective damage given attacker/defender + active timed rules), called at each
   seat rather than multiplier logic duplicated per seat. At resting multipliers (no active timed
   rule, `x * 1.0`) the funnel must be bit-identical to today's output — no reordering of the existing
   `damage *= block_damage_multiplier`.
10. A hashed per-player record of the last resolved card (id + mode: BASIC or PITCH activation),
    written at the same two APPLY seats card_cast_resolved fires from. Public-id hashing follows the
    `src/state/pitch/pitch_state.gd` precedent (`:18-19`: a staged card's id/hand-slot are hashed
    because the staged card is PUBLIC by GDD design, unlike hand contents — a resolved card is
    equally public, it has already left the hand). The card id is hashed as a String VALUE (never a
    key — the StringName-sort hazard, `pitch_state.gd:112-122`); the mode is hashed as an int
    ordinal. Not consumed by anything in 6-5a; 6-5f reads it for Counterspell.

### Deck selection

11. An authored deck list (card id + copies) — new authored content, NOT a new BalanceConfig field
    (per-deck composition is content, the `max_copies` per-card-not-per-balance precedent,
    `card_data.gd:55-58`) — replaces `_derive_deck_contents`'s "walk the whole library alphabetically,
    each card up to its own `max_copies`" (`match_runner.gd:613-623`; `:610` is a stale "deck_size of
    20" comment). Both players get Deck 1 until a
    second deck exists (both call sites of `_derive_deck_contents`/`inject_deck` stay ONE injected
    deck, `match_state.gd:836-839`, unchanged in shape).
12. The nine existing fixture cards (`imp_summoner`, `storm_kite`, `thornback_guardian`,
    `hellforge_totem`, `tidal_wardstone`, `verdant_wardstone`, `ember_lash`, `frost_dart`,
    `bramble_snare`) stay authored in `data/cards/` but are NOT in Deck 1's list — dormant per R1.
13. Every existing authoring test pinning the OLD truth is rewritten, each rewrite NAMED as a
    rewrite in its own comment (not silently dropped):
    - `test_card_authoring.gd:93` `EXPECTED_COUNT := 9` -> Deck 1's 7 (the nine fixtures still load
      and still pass `test_data_resources.gd`'s generic load sweep; this file's CONTENT assertions
      move to describe Deck 1, filtered by the deck list — `_load_cards()` (`:226-239`) sweeps the
      whole directory, 16 cards after this story — and a SEPARATE, explicitly named assertion keeps
      proving the nine fixtures still exist, are still loadable, and are still excluded from the deck
      list — R1 made machine-checked, not just documented);
    - `test_card_authoring.gd:154-180`: count 9, every `effect_id` must start `summon_`/`spell_`,
      summons == 6, spells == 3 -> rewritten to Deck 1's 7 and the WHOLE-ID vocabulary this story
      introduces (new buff/no-op ids do not take the `summon_`/`spell_` prefix);
    - `test_card_authoring.gd:187-207`: `assert_null(card.pitch_effect)` on every card -> rewritten,
      since Deck 1 authors all seven pitch effects;
    - `test_deck_1_colours_are_card_color_values_green_3_red_2_blue_2` (`:96-104`, renamed by review
      N12 from `test_colours_are_card_color_enum_values_three_per_colour`; the claim is unchanged) ->
      Deck 1's GREEN 3 / RED 2 / BLUE 2 (`deck-1-spec.md` §1-7: Vanguard/Culling and Grave Ward/Raise
      Dead and Drain/Vampiric Aura are GREEN; Rocksling/Boom and Bloodhound/Bloodlust are RED; Honed
      Bolt/Counterspell and Frostbite/Corpse Bomb are BLUE — 3 green, 2 red, 2 blue);
    - `test_each_deck_1_card_is_priced_at_its_authored_mode_1_and_mode_4_prices` (`:107-124`, renamed
      by review N12 from `test_each_colour_prices_one_card_at_each_tier`; the claim is unchanged), the
      sealed 2/3/5-per-colour tiering -> Deck 1 prices 2-4 mana per the spec's authored `T[...]`
      brackets, so this test's SHAPE (one price per colour tier) no longer holds and the assertion is
      rewritten to whatever Deck 1's authored prices actually are, named as a DELIBERATE departure
      from the "sealed
      nine-card decision" comment at `:14`;
    - Deck size is the sum of the deck list's copies (Deck 1 = 20, provisional data). The authored
      `BalanceConfig.deck_size` is KEPT (changed `24` -> `20` in `data/balance/balance_config.tres:110`
      by this story) and must not disagree with the list sum: a new authoring test asserts
      `deck_size ==` the deck list's copy sum. `test_copies_cap_is_in_bounds_and_a_twenty_card_deck_is_constructible`
      (`:126-133`) is rewritten to read the live `deck_size` rather than a local `20`/`24` literal, so
      it cannot silently drift from balance again;
    - `CARD_DATA_FIELDS` (`:27-32`, seven fields) is UNCHANGED — this story adds no new CardData
      field, only new CardEffect fields, so this pin stays as-is (named here so a rewrite pass does
      not touch it by mistake);
    - `test/integration/test_card_database.gd:29-33,52`: nine literal ids, count == 9 -> 16 (seven
      Deck 1 cards plus the nine dormant fixtures, the whole library);
    - `test/integration/test_deck_injection.gd:40-43` (nine sorted ids) -> Deck 1's seven; `:201-212`
      (the sorted-prefix fill rule, which the deck list abolishes) -> rewritten to the deck list's own
      order; `:128,181` (deck = deck_size - hand_size; composition == deck_size) -> the new 20-card
      sum; `:193-199` (max_copies / at-cap) -> re-derived from the deck list's per-entry copies;
    - `test_intent_recorder.gd:109-127` (`EXPECTED_INTAKE_SURFACE`) -> updated with the new
      `inject_pitch_effects` intent (AC 6);
    - `test_card_observation.gd:~280-303` (expected key LIST) and `:310` (key COUNT) -> both updated
      for the new hashed keys this story adds (AC 8, AC 10);
    - **Live tests that need a summoning card dealt.** Deck 1 has 3 summons (Ruin Vanguard) in 20;
      P(>=1 in a 4-card opening hand) is about 0.51 and each test's seed is fixed, so pass/fail is
      unknown until run. Each of the following is run on Deck 1, and any that cannot deal a summon is
      re-pointed (for example, injecting a summon-bearing TEST deck list through the runner's
      deck-list seat — no reliance on fixed-seed luck — or a board injection as
      `test_totem_tint_live.gd:8` does), each named as a rewrite: opening-hand-only tests
      `test_summon_actor_live.gd:83`, `test_unit_approach_live.gd:174`, `test_unit_aim_live.gd:91`,
      `test_unit_spawn_placement_live.gd:130`, `test_two_units_converge_live.gd:163`,
      `test_summon_spawn_containment_live.gd:63`, `test_unit_strike_alignment_live.gd:111`; and, with
      12 deterministic reshuffles, `test_unit_combat_live.gd:66`, `test_unit_attack_live.gd:80` (needs
      TWO summons in P1's hand plus one in P2's, about 0.04 per attempt),
      `test_unit_corpse_linger_live.gd`, `test_unit_corpse_walkthrough_live.gd`,
      `test_unit_swing_root_live.gd`.
14. A NEW authoring test (or a rewritten `test_nine_cards_load_as_card_data`-shaped test) asserts the
    actual composition of the DECK LIST: exactly Deck 1's seven card ids AND their copy counts (the
    full 20-card multiset, not just the set of ids), and that the deck built from it
    (`_derive_deck_contents`'s successor) contains no fixture id.

### Deck 1 content and no-ops

15. All seven Deck 1 cards are authored as `CardData` `.tres` files with all 14 effects (7 cards x
    normal + pitch) defined as shared `data/effects/*.tres` resources, using the exact numbers from
    `docs/planning-artifacts/deck-1-spec.md` EXCEPT Bloodhound Step's distance/i-frame multipliers
    (R2 supersedes the spec's `T[1.5]`). Costs (mana + orb, per `deck-1-spec.md` and the operator's
    decision-log amendments): Ruin Vanguard 3 mana / Culling 3 mana + 1 green orb; Grave Ward 2 mana /
    Raise Dead 6 mana + 2 red orbs; Drain 2 mana / Vampiric Aura 5 mana + 1 green orb + 1 red orb;
    Rocksling 4 mana / Boom 3 mana + 1 red orb; Bloodhound Step 2 mana / Bloodlust 4 mana + 1 red orb;
    Honed Bolt 4 mana / Counterspell 4 mana + 1 blue orb; Frostbite 4 mana / Corpse Bomb 5 mana + 1
    blue orb. All have orbs on the pitch side, so `test_card_authoring.gd:202` holds. Only FIVE of
    the fourteen effects are actually implemented this story: Ruin Vanguard (via the existing
    `summon_*` seam, AC 4), Bloodlust, Vampiric Aura, Bloodhound Step, Frostbite. The other nine
    (Culling, Grave Ward, Raise Dead, Drain, Rocksling, Boom, Honed Bolt, Counterspell, Corpse Bomb)
    resolve through a named no-op — its own `effect_id` prefix or table entry, e.g.
    `REASON_DECK1_NOT_YET_RESOLVED` (mirroring `REASON_SPELL_NOT_YET_RESOLVED`'s shape,
    `card_effect_resolver.gd:112`). Each deferred id maps to its owning future story in a
    resolver-side constant (for example `Dictionary[StringName, StringName]`, only ever `get()`-ed —
    a comment is not machine-checkable): Culling/Grave Ward/Raise Dead/Drain -> 6-5b; Rocksling/Boom
    -> 6-5d/6-5e; Honed Bolt -> 6-5c; Counterspell -> 6-5f; Corpse Bomb -> 6-5d. A unit test asserts
    all nine entries. (Token names for the no-op ids stay the dev's naming choice, OQ3.) Every no-op
    card is a SUCCESSFUL cast exactly as `4-1/R3`/`4-1/R10` already establish for `spell_*`:
    mana/orbs spent, card discarded, replacement owed, no `reject_action` on any path.
16. `FeatureFlags` gains a new `spells: bool = false` export, following the existing per-layer
    pattern (`feature_flags.gd:15-21`); every layer stays individually toggleable (existing hard
    rule). The four buff effects (Bloodlust, Vampiric Aura, Bloodhound Step, Frostbite) gate on
    `spells`, degrading gracefully the same way `minions`/`totems` do
    (`REASON_MINIONS_FLAG_CLOSED`/`REASON_TOTEMS_FLAG_CLOSED` shape, `card_effect_resolver.gd:129-155`):
    cast still resolves, effect just does not apply. Ruin Vanguard KEEPS gating on `minions`
    (`card_effect_resolver.gd:180`) — it is the unchanged summon path, not a new effect family (AC 4).
    `data/feature_flags.tres` turns `spells` ON with this story (the working pattern: the flag exists
    off-by-default in code, the authored `.tres` is where a story actually ships the layer), and an
    authored-`.tres` test on the `test_data_resources.gd:449-462` precedent asserts it.

## Non-Goals

- Corpses, kill-own-units, Drain's position fact — owned by `6-5b`.
- Cast window, stun, root, Honed Bolt — owned by `6-5c`.
- Hero and corpse projectile sources, Rocksling, Corpse Bomb, M5 (homing angle monotonicity test),
  M6 (`unit_kinds` reorder validation) — owned by `6-5d`.
- Boulder foreign-card injection, Boom — owned by `6-5e`.
- Counterspell, undo of anything 6-5a..6-5e ships — owned by `6-5f`.
- Real VFX/animation clips (R8): grey placeholders only.
- A mana-at-activation pitch cost seat (R7): out of scope, not needed by any Deck 1 card.

## Golden Prediction

**PREDICTED to MOVE, in both the golden hash and the per-player snapshot key set** (today 31 keys,
`test_card_observation.gd:310`). Named predicted causes, each to be MEASURED (not assumed) by the
dev pass:

1. The hashed per-player last-resolved-card record (AC 10) is new hashed per-player state -> at
   least one new snapshot key (e.g. `"last_resolved_card"` as `[id, mode]`, the `defense`-key
   two-element-array shape, `player_state.gd:375`).
2. The timed-rule seat (AC 8) is new hashed per-player state for whichever of Bloodlust/Vampiric
   Aura/Bloodhound Step/Frostbite need to SURVIVE a tick boundary (a duration or an armed-window
   remaining-ticks value) -> at least one more new key, possibly more if timed rules are not
   collapsed into one array-shaped key. Note: a hero-nested key (for example a roll-boost flag inside
   `hero_state.gd:539-540`'s own snapshot) would move the golden without moving the per-player
   top-level key count of 31 — the two measurements are independent.
3. `FORMAT_VERSION` goes 12 -> 13 with a hard refusal of v12 records (the 6-9/6-7 bump+refusal
   precedent, `record_file.gd:365-368`). The cause is a new REQUIRED record key (the `pitch_effects`
   channel, AC 6) plus changed resolution semantics (buff ids now apply) — not the
   `card_cast_resolved` arity (a signal is not recorded) and not "the new hashed fields" generically
   (a record carries no hash, `record_file.gd:245-271` `REQUIRED_KEYS`).
4. The golden itself (`test_determinism.gd`) casts only `summon_*` ids built in-test (`:1459-1465`,
   BASIC only, never PITCH, `:945`) — so Ruin Vanguard's summon path alone would likely leave the
   golden HASH unmoved by its own action, but the KEY SET still grows from causes 1-2 above, which
   changes what the golden hashes even if the golden's own script never casts a buff card. The
   golden must be re-baselined once causes 1-2 land, following the `defense`-key precedent
   (`5-5-unblockable-defense`'s golden move, `player_state.gd:371-377`).

**Measure, do not assume** (Tier A still commits to measuring before/after): full suite before any
edit, full suite after, `git diff --stat` under `src/state/`, golden hash / key count /
`FORMAT_VERSION` in both runs, saved outside the repo.

## Live Smoke (operator, two pads, flip config [3,3])

1. **Ruin Vanguard.** Cast it (mode 1): a minion appears on the caster's board, mana spent, card
   discarded, replacement owed.
2. **Bloodlust.** Pitch and activate it: for 10 s the caster's hero and any owned minion deal/take
   visibly doubled damage (grey placeholder cue); totems on the board are unaffected.
3. **Vampiric Aura.** Pitch and activate it: for 15 s, hero melee/unblockable/projectile damage
   visibly heals the caster; a minion's own damage does not.
4. **Bloodhound Step.** Cast it, then roll within 5 s: the roll covers roughly 3x distance in the
   same time and the whole roll is invulnerable; a roll taken after 5 s is unaffected.
5. **Frostbite.** Cast it, then land a hero melee hit on the enemy hero within 6 s: the enemy hero's
   walk, run, and block-walk are visibly slowed for 4 s; a hit past 6 s does not slow.
6. **Every unimplemented Deck 1 effect casts without error.** Cast/pitch-activate Culling, Grave
   Ward, Raise Dead, Drain, Rocksling, Boom, Honed Bolt, Counterspell, Corpse Bomb in turn: each
   resolves as a clean no-op (mana/orbs spent, card discarded, replacement owed, no crash, no
   assert, no visible effect).
7. **Deck check.** Both hands draw only from the seven Deck 1 cards across a full deck exhaustion;
   none of the nine old fixture cards ever appears.

## Tasks / Subtasks

- [x] Task 1 (AC 1-3) `CardEffect` flat-export vocabulary + `visual_id`; `data/effects/` folder;
      round-trip through `RecordFile` proven by a test (save/load a synthetic record carrying a new
      field, assert it survives).
- [x] Task 2 (AC 4-5, 15) Whole-id dispatch in `CardEffectResolver` for the five implemented buff
      effects plus the named Deck1-not-yet-resolved no-op for the other nine; the summon path (Ruin
      Vanguard) reuses the existing table unchanged.
- [x] Task 3 (AC 6) `_derive_pitch_effects()` injection channel in `match_runner.gd`; pitch
      activation resolves the pitch effect at `_resolve_pitch_activate` (`match_state.gd:3215-3240`).
- [x] Task 4 (AC 7) `card_cast_resolved` gains a mode argument; every connect site updated (source
      seam count stays TEN).
- [x] Task 5 (AC 8-9) Timed-rule seat on `PlayerState`; damage funnel wired at every seat AC 9 names.
- [x] Task 6 (AC 10) Hashed last-resolved-card record, written at both APPLY seats.
- [x] Task 7 (AC 11-14) Deck list authoring + `_derive_deck_contents` successor; authoring-test
      rewrites, each named; new deck-composition test.
- [x] Task 8 (AC 15) Seven Deck 1 `CardData` `.tres` files, 14 effect `.tres` files, numbers from
      `docs/planning-artifacts/deck-1-spec.md`.
- [x] Task 9 (AC 16) `FeatureFlags.spells`; five implemented effects gated; `data/feature_flags.tres`
      turns it on.
- [x] Task 10 (Golden Prediction) Baseline full suite before any edit (save outside the repo); after
      the pass, full suite again; golden re-baseline if and only if the measured key set moved;
      `FORMAT_VERSION` 12 -> 13 with v12 refusal test.
- [x] Task 11 Tests for every AC above, each mutation-proven per this repo's standing protocol (copy
      to scratchpad + SHA256 before mutating; restore by copying back, never `git checkout`).
- [x] Task 12 (OPERATOR-OWNED) Live Smoke above, then Dev Agent Record. **PASS 7/7** (operator, two
      pads, flip config [3,3]): Ruin Vanguard summons; Bloodhound Step's roll travels further with the
      same duration and is invulnerable throughout; Frostbite visibly slows walk and run, including on
      a blocked hit; Bloodlust doubles damage both ways; Vampiric Aura heals while attacking; all nine
      deferred effects cast cleanly with no error or crash; regression and fps fine.

## Open Questions (for the readiness gate; none blocks authoring, none is a STOP)

1. **CLOSED (operator, 2026-09-22): timed-rule seat shape is the dev pass's choice.** Recommendation
   (non-binding): one small `Array` of rule records (kind id, remaining ticks, armed/active flag), one
   hashed key, rather than four separate named fields — cheaper to extend in `6-5b` (Grave Ward is
   also a timed per-player rule) without a new key each time. The dev may pick differently if a
   simpler shape covers all four 6-5a rules and the key-growth prediction stays accurate.
2. **Whether Bloodhound Step's "3x distance in the same duration" is authored as a `roll_distance`
   multiplier applied for one roll, or a `roll_speed` multiplier** — `match_state.gd:4301-4303`
   computes velocity as `roll_distance / roll_duration_seconds`, so multiplying `roll_distance` by 3
   for the one flagged roll is the direct reading of R2; recommended, not re-litigated here.
3. **CLOSED (operator, 2026-09-22): no-op token naming for the nine deferred Deck 1 effects is the
   dev pass's choice.** (AC 15) — any consistent naming is fine, as long as each no-op is
   distinguishable per card. The MECHANISM that names each no-op's owning story is now locked (B11,
   AC 15): a resolver-side `Dictionary[StringName, StringName]` constant, only ever `get()`-ed, with a
   unit test asserting all nine entries — a comment map is no longer an option, since a comment is not
   machine-checkable.
4. **CLOSED (operator, 2026-09-22): APPROVED.** The deck-list resource is a new `Resource` schema
   (`class_name DeckList`) under `src/state/resources/`, authored at `data/decks/deck_1.tres`, read
   only by the runner (AC 8 of 3-3: no `src/state/` file may name `CardDatabase`). It is an ORDERED
   `Array` of entries (card id + copies) — never a `Dictionary` (Dictionary iteration order decides
   nothing, `card_effect_resolver.gd:61-65`, and the composition's pre-shuffle order feeds the seeded
   shuffle). Each entry's `copies` must be <= that card's `max_copies`, asserted in a test.

## Dev Notes

- **Where the change goes.** Effect vocabulary + flat exports: `src/state/resources/card_effect.gd`.
  New effect data: `data/effects/*.tres`. Deck 1 cards: `data/cards/deck1_*.tres` (naming the dev's
  choice; keep alongside the existing fixture cards). New deck list: `data/decks/deck_1.tres`
  (`DeckList` schema, `src/state/resources/`, OQ4). Resolver dispatch:
  `src/state/economy/card_effect_resolver.gd`. Apply seats: `src/state/match_state.gd`
  (`_resolve_basic_cast` `:2911-3040`, `_resolve_pitch_activate` `:3215-3240`, plus every damage seat
  the funnel touches). Record round-trip: `src/systems/record_file.gd`. Injection:
  `src/main/match_runner.gd` (`_derive_deck_contents` `:613-623`, `_derive_card_effects`
  `:662-669`, new `_derive_pitch_effects` sibling). Flags: `src/state/resources/feature_flags.gd`,
  `data/feature_flags.tres`. Authoring tests: `test/state/test_card_authoring.gd`. Snapshot key
  count: `test/state/test_card_observation.gd:310`.
- **Pure-function / D6 discipline** (project rule, this repo's standing pattern): the resolver
  COMPUTES, `advance()`'s ordered dispatch APPLIES. Do not let `CardEffectResolver` touch a board,
  pool, or per-player record directly.
- **Replay trap** (the reason for AC 2): keep every new number a flat `@export` on `CardEffect`
  itself. If a future card effect genuinely needs a sub-resource, that sub-resource's class MUST be
  added to `RecordFile._fresh_nested`'s whitelist (`record_file.gd:666-674`) in the SAME story that
  introduces it, or its fields silently vanish on replay.
- **One `_physics_process`** stays in `match_runner.gd` (F1, `test_architecture_invariants.gd`).
  `Input.*` only under `src/controllers/` (D3(a)) — untouched by this story, no controller work here.
  No global RNG / `Time` / `OS` / `Engine` in `src/state/` (D3(b)/A2) — the timed-rule seat must use
  tick counts (`TimingWindow`/`remaining_ticks()`), never wall-clock time.
- **Test harness constraint**: state tests run in `_initialize()` with no frame — a frame-dependent
  assertion is a leak tripwire (this project's standing E0 constraint).
- **Non-vacuity**: back up each file to the scratchpad with SHA256 BEFORE mutating; restore by
  copying back, never `git checkout` (wipes the whole uncommitted pass).
- **Intake surface**: any new public `MatchState` method taking a parameter counts as an intake under
  `test_intent_recorder.gd:141-152`'s derivation rule — it needs a capture channel or a named
  exemption. This applies to `_derive_pitch_effects`'s injection (AC 6) and to any new deck-list
  injection call this story adds.
- Windows: run the suite via the Bash tool with `GODOT=/c/Godot/godot.exe bash test/run_all.sh`
  (WSL is broken); shell is PowerShell 5.1 for git (no `&&`); commit messages pure ASCII via
  `git commit -F <tempfile outside the repo>`; docs and code in separate commits; trailer per the
  session's commit attribution rule; validation worth proving is committed as a test, never
  written-then-deleted.

- **Operator rulings issued with the dev-pass instruction (2026-09-22), recorded as rulings:**
  - **N10** Re-casting a timed buff while it is active REFRESHES its duration (no stacking; two
    Bloodlusts are still 2x). Round end and debug reset clear every active timed rule and armed trigger.
    Vampiric Aura heals 50% of the damage ACTUALLY removed from the target (after block and all
    multipliers, capped by the target's remaining HP).
  - **N11** All seven Deck 1 cards and all 14 effect resources are authored with ids and costs; numeric
    effect exports exist only for the five effects implemented here. Deferred effects get their numbers
    in their own stories.
  - **N12** (asked mid-pass, operator answered) The Deck 1 2-copy card is Honed Bolt / Counterspell; the
    other six cards are 3 copies each (`deck-1-spec.md:12` left it unspecified).

### Project Structure Notes

- New folder: `data/effects/` (design-shape call, locked by this story's own scope, R-item 1 of the
  Acceptance Criteria — not left open).
- New folder: `data/decks/`, holding `deck_1.tres` (OQ4, CLOSED).
- New `.tres` files under `data/cards/` for the seven Deck 1 cards, beside the nine existing
  fixtures (which are untouched and stay in the repo, R1).
- New schema class `DeckList` under `src/state/resources/`, an ordered `Array` of entries (card id +
  copies), read only by the runner (OQ4, CLOSED).

### Project Context Rules

- Determinism: any per-player value that must survive a tick boundary and can affect play (a timed
  rule's remaining duration, the last-resolved-card record) MUST be hashed into the snapshot; nothing
  new may ride `UNHASHED_CROSS_TICK_MEMBERS` without an explicit ruling extending that list.
- Authored data in `.tres` with a named default; every gameplay layer independently toggleable via
  `FeatureFlags`, degrading gracefully when off (never hardcoded on).
- D6: evaluators compute, `MatchState.advance()`'s ordered dispatch applies.
- F1 / D3(a) / D3(b) / A2 as in Dev Notes above — machine-checked by
  `test/state/test_architecture_invariants.gd`.
- Commit conventions: docs and code never share a commit; validation worth proving is committed as a
  test; ASCII messages via `-F`; show the full diff before staging; `git add`/`git commit` separate,
  explicit paths only; never push until the log is confirmed in chat.
- Tier A: full gate + review + live smoke ritual (golden clause: this story is Tier A because it
  moves the golden, regardless of how small the change otherwise feels).

### References

- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md`: `R-SPELL`
  (`:7829-7843`, `:8070`, `:8234`).
- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md`: the E6 `6-5-spell-resolution`
  entry (E6 story list) and the "`6-5` (close-out) carries `R-SPELL` plus M5/M6" committed
  obligation (pitch-zone section); `deferred-work.md:302-303` for M5/M6's current line numbers
  (the epics citation to `:232-233` is stale per the inventory's S0-7).
- `C:\dev\_65-inventory.md` (report-only inventory at `92f0dd9`, this session) — S0 corrections, S1
  card model, S3 per-effect seam table, S4 framework recommendation and story cut.
- `docs/planning-artifacts/deck-1-spec.md` (operator's Deck 1 spec, copied into the repo this
  session, byte-identical to `C:\dev\_deck1-spec.md`) — all seven cards' numbers.
- `docs/implementation-artifacts/6-10-card-mode-toggle.md` — the most recent Tier-story template
  followed for this file's shape (mutation-proof protocol, live-smoke format, rulings-as-ACs).
- `docs/game-architecture.md`, `docs/project-context.md` — rules cited above;
  `test/state/test_architecture_invariants.gd` — the machine-checked invariants.

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context), gds-dev-story, 2026-09-22 (one HALT for a memory reap, resumed the same day).

### Debug Log References

- Before-baseline (pre-edit): `C:\dev\_65a-suite-before.txt` -- 936 / 0 / 8454 state, 67/67 integration.
- After (final, the second counted full run): `C:\dev\_65a-suite-after.txt` -- 972 / 0 / 9137 state, 67/67
  integration. State 19:30:37-19:30:49, integration 19:30:50-19:35:14.
- Full record: `C:\dev\_65a-dev.md`. Golden probe output and mutation logs: `C:\dev\_65a-mut\`.
- Review: `C:\dev\_65a-review.md`. Review FIX pass: record `C:\dev\_65a-fix.md`, suite
  `C:\dev\_65a-fix-suite.txt` -- 980 / 0 / 9183 state, 67/67 integration. Its mutation logs
  (`M16`, `M17a`, `M17b`, `M18`, `M19`, `G1`) and `FIX.*.orig` backups are in the same `C:\dev\_65a-mut\`.

### Completion Notes List

- **Suite:** before 936 / 0 / 8454 + 67/67 integration; after 972 / 0 / 9137 + 67/67 integration (+36 tests,
  +683 assertions). Dev-iteration SUBSET runs between the two counted runs are disclosed in `C:\dev\_65a-dev.md`.
- **Golden** `d437432f` -> `59e9a42c`, re-baselined once, three causes measured separately (`timed_rules`
  presence; `last_resolved_card` presence at rest; its t22 value). Key paths 206 -> 210; per-player keys
  31 -> 33 (no hero-nested key). `RecordFile.FORMAT_VERSION` 12 -> 13, v12 refused hard.
- **Mutations:** M1-M15 all KILLED, none GREEN (table below).
- **HALT and resume (2026-09-22):** the first mutation batch ran in the background and was reaped for low
  memory with M5 applied; `match_state.gd` was restored from its SHA-verified backup. Root cause found on
  resume: the M5 snippet was malformed (a comment after a `\` continuation), so the test file failed to
  parse and the scratch runner hung. Resumed with every mutation in the foreground, a fail-fast runner
  and a hard kill timeout.
- Task 12 (live smoke) is OPERATOR-OWNED and left unchecked.

#### Review fix pass (2026-09-22, `C:\dev\_65a-fix.md`) -- EXTENDS the notes above, replaces none of them

- Contract `C:\dev\_65a-review.md`: 1 blocking + 13 non-blocking. **B1 and N1-N12 applied; N13 is
  operator-confirmation only and needed no code.** ACs and Operator Rulings untouched -- no fix required
  one, so the pass never had to STOP.
- **Suite (a THIRD counted full run, `C:\dev\_65a-fix-suite.txt`):** 980 / 0 / 9183 state + 67/67
  integration, against the dev pass's 972 / 0 / 9137. +8 tests, +46 assertions, all in
  `test_spell_framework.gd` (24 -> 32). Reason for the run: a full-suite check that the review fixes --
  which touch the movement seat, the contact ladder, `PlayerState` and the runner's deck seam -- moved
  nothing else. State 22:12:53-22:13:05, integration 22:13:12-22:18:14.
- **Golden NEPOMAKNUT at `59e9a42c`, measured in BOTH directions:** green against the unchanged constant
  in the counted run, and mutation G1 (one hex digit flipped) printed the live fixture hash back as
  `59e9a42c...ad86b1bd`. No re-baseline; the constant was never edited outside that restored mutation.
- **Two AC texts now name a test by its OLD name** (`:195`, `:199`, quoting
  `test_colours_are_card_color_enum_values_three_per_colour` and
  `test_each_colour_prices_one_card_at_each_tier`). N12 renamed both, and each new docstring records its
  old name verbatim so the AC stays greppable. The ACs themselves are UNCHANGED and still satisfied --
  they require the tests to be repointed at Deck 1, not to keep a particular name.
- **A new public method on `PlayerState`:** `clear_resolved_card()`, named by the B1 ruling.
- Nothing committed. `project.godot` untouched; no new file added to the repo by this pass.
#### Mutation table (provenance: `C:\dev\_65a-mut\<label>.txt`, backups `<label>.*.orig`, SHA-256 verified on restore)

| # | Mutation | File | Test run | Result |
|---|---|---|---|---|
| M1 | melee-seat funnel removed | match_state.gd | test_spell_framework.gd | KILLED (3 tests) |
| M2 | unit-seat funnel removed | match_state.gd | test_spell_framework.gd | KILLED (1 test) |
| M3 | dodged-unblockable-seat funnel removed | match_state.gd | test_unblockable_defense.gd | KILLED (1 test) |
| M4 | landing-package-seat funnel removed | match_state.gd | test_unblockable_defense.gd | KILLED (1 test) |
| M5 (void x2) | Vampiric lifesteal from a minion hit | match_state.gd | test_spell_framework.gd | VOID: the mutant snippet put a comment after a `\` continuation -> Parse error -> the scratch runner hung (the likely cause of the first reap). Resume attempt: hung Godot killed, file restored, SHA `D21086E7...` verified. Snippet fixed, runner made fail-fast on load errors, helper given a 240 s hard kill. |
| M5 | Vampiric lifesteal from a minion hit (hero-index gate dropped) | match_state.gd | test_spell_framework.gd | KILLED (1 test: caster healed 82.0 vs 80.0). Mutated SHA `FA8ED4F3...`, restored `D21086E7...` verified. `M5.txt` |
| M6 | Bloodhound consumed by a stamina-refused roll | match_state.gd | test_spell_framework.gd | KILLED (1 test). Mutated `BC673EF1...`, restored `D21086E7...` verified. `M6.txt` |
| M7 | Frostbite consumed on a deflected hit | match_state.gd | test_spell_framework.gd | KILLED (1 test). Mutated `9DB261C0...`, restored `D21086E7...` verified. `M7.txt` |
| M8 | last-card record not written on pitch activation | match_state.gd | test_spell_framework.gd | KILLED (1 test). Mutated `F21C277B...`, restored `D21086E7...` verified. `M8.txt` |
| M9 | pitch effect resolved at staging | match_state.gd | test_spell_framework.gd | KILLED (1 test). Mutated `ABA82E10...`, restored `D21086E7...` verified. `M9.txt` |
| M10 | deck list ignores copies (runner `_derive_deck_contents`) | match_runner.gd | integration test_deck_injection | KILLED (counts + composition). Orig/restored `BE5E21A9...` verified, mutated `B05A7C18...`. `M10.txt` |
| M11 | spell flag ignored by the resolver | card_effect_resolver.gd | test_spell_framework.gd | KILLED (2 tests). Orig/restored `8F0BCF13...` verified, mutated `AACCEEC7...`. `M11.txt` |
| M12 | Bloodhound i-frame clamp removed | match_state.gd | test_spell_framework.gd | KILLED (36 vs 30 ticks). Mutated `E3B6F755...`, restored `D21086E7...` verified. `M12.txt` |
| M13 | Frostbite slow skips block-walk | match_state.gd | test_spell_framework.gd | KILLED (4.0 vs 2.0). Mutated `92778925...`, restored `D21086E7...` verified. `M13.txt` |
| M14 | re-cast STACKS the magnitude (N10 refresh broken) | player_state.gd | test_spell_framework.gd | KILLED (a 4.0 vs 2.0; hit 24 vs 12). Orig/restored `1B81CE01...` verified, mutated `8196122A...`. `M14.txt` |
| M15 | round end clears no timed rule (N10) | match_state.gd | test_spell_framework.gd | KILLED (1 test). Mutated `627925F9...`, restored `D21086E7...` verified. `M15.txt` |
| M16 | totem counted as a Bloodlust body (`_is_bloodlust_body` returns true for a non-minion) | match_state.gd | test_spell_framework.gd | KILLED (1 test: totem took 6.0 vs 3.0). Mutated `940E8418...`, restored `9B6D7A4A...` verified. `M16.txt` |
| M17 (two states) | the stale-boost guard `else: cancel_rule(RULE_ROLL_BOOST)` deleted | match_state.gd | test_spell_framework.gd | **GREEN first** (`M17a.txt`, 31/0/211 -- the guard had no test, exactly as review N10 predicted). Test STRENGTHENED, not weakened: new `test_an_unboosted_roll_cancels_a_stale_roll_boost_instead_of_riding_it` seats a stale boost directly. Re-run with the SAME mutant: **KILLED** (`M17b.txt`, stale boost still active, roll 18.0 vs 6.0). Mutated `7B39D051...`, restored `9B6D7A4A...` verified. |
| M18 | the BASIC-seat last-resolved write removed | match_state.gd | test_spell_framework.gd | KILLED (1 test, 2 assertions: `["", -1]` vs `["sf_hound", 0]`). Mutated `11BA3405...`, restored `9B6D7A4A...` verified. `M18.txt` |
| M19 | the new B1 last-resolved CLEAR removed from BOTH paths (round end and `_reset_player`) | match_state.gd | test_spell_framework.gd | KILLED (1 test, 4 assertions -- both seats on both paths). Mutated `5816ABBE...`, restored `9B6D7A4A...` verified. `M19.txt` |
| G1 | one hex digit flipped in the `GOLDEN` constant (the golden's SECOND direction) | test_determinism.gd | test_determinism.gd | KILLED (`G1.txt`) -- and its failure message PRINTS the live fixture hash as `59e9a42c...ad86b1bd`, which is the measured proof the golden did not move. Mutated file restored, `D7F903F8...` verified. |

**M1-M15: no mutation came back GREEN.** Every KILLED verdict was checked for real `[XX]` assertion
failures (no `FAILED TO LOAD` / Parse Error in its output).

**M16-M19 + G1 are the REVIEW FIX PASS's mutations** (2026-09-22, `C:\dev\_65a-fix.md`), added under the
same protocol. M17 is the one that came back GREEN, and it is recorded in BOTH states rather than
retried until it looked good: the guard was real but unproven, so the TEST gained an assertion until
the same mutant died.

An earlier M1-M5 attempt was VOID (PowerShell `&` did not wait for the GUI Godot binary; empty outputs,
files restored, SHA verified); rerun with `Start-Process -Wait`.

### File List

All uncommitted in the working tree.

- Modified src: `src/state/match_state.gd`, `src/state/player_state.gd`,
  `src/state/economy/card_effect_resolver.gd`, `src/state/resources/card_effect.gd`,
  `src/state/resources/feature_flags.gd`, `src/main/match_runner.gd`, `src/systems/intent_recorder.gd`,
  `src/systems/record_file.gd`
- New src: `src/state/resources/deck_list.gd`, `src/state/resources/deck_list.gd.uid`
- Modified data: `data/balance/balance_config.tres` (deck_size 24 -> 20), `data/feature_flags.tres` (spells)
- New data: `data/cards/{ruin_vanguard,grave_ward,drain,rocksling,bloodhound_step,honed_bolt,frostbite}.tres`;
  `data/effects/{summon_ruin_vanguard,culling,grave_ward,raise_dead,drain,vampiric_aura,rocksling,boom,
  bloodhound_step,bloodlust,honed_bolt,counterspell,frostbite,corpse_bomb}.tres`; `data/decks/deck_1.tres`
- New tests: `test/state/test_spell_framework.gd` (+ `.uid`), `test/live_summon_deck.gd` (+ `.uid`)
- Modified state tests: `test_card_authoring.gd`, `test_card_effect_resolution.gd`,
  `test_card_observation.gd`, `test_card_play.gd`, `test_data_resources.gd`, `test_deck_and_hand.gd`,
  `test_determinism.gd`, `test_draw_delay_and_reshuffle.gd`, `test_intent_recorder.gd`,
  `test_live_reload.gd`, `test_pitch_staging.gd`, `test_record_file.gd`, `test_replay_identity.gd`,
  `test_unblockable_defense.gd`
- Modified integration tests: `test_card_database.gd`, `test_deck_injection.gd`,
  `test_cast_success_cue_live.gd`, `test_pitch_hud_live.gd`, `test_replay_contacts.gd`,
  `test_replay_entry_is_inert.gd`, `test_replay_verifier_tool.gd`, `test_summon_actor_live.gd`,
  `test_summon_spawn_containment_live.gd`, `test_two_units_converge_live.gd`, `test_unit_aim_live.gd`,
  `test_unit_approach_live.gd`, `test_unit_attack_live.gd`, `test_unit_spawn_placement_live.gd`,
  `test_unit_strike_alignment_live.gd`
- Docs: this story file; `docs/implementation-artifacts/sprint-status.yaml` (story_notes / last_updated only)

## Change Log

- 2026-09-22: story authored (Status `authored`), baseline `92f0dd9`. `6-5-spell-resolution` split
  into six board keys (`6-5a..6-5f`) by operator ruling; this story covers `6-5a` only. Not cleared
  for a dev pass.
- 2026-09-22: readiness gate round 1 (report-only, `C:\dev\_65a-gate.md`) -- NOT READY, 11 blocking /
  17 non-blocking. All 11 blocking items (B1-B11) and every non-blocking item that was a pure
  text/citation correction fixed in this same session, no second gate round (`6-9` precedent). Status
  -> `ready-for-dev`. Rulings recorded in the decision-log, session "6-5 scope + 6-5a readiness gate",
  `6-5a/R1..Rn`. `docs/planning-artifacts/deck-1-spec.md` added (byte-identical copy of the operator's
  spec); every story reference to it repointed to the repo path.
- 2026-09-22: dev pass (gds-dev-story). Tasks 1-11 implemented and tested; golden re-baselined
  `d437432f` -> `59e9a42c`; FORMAT_VERSION 12 -> 13; mutation proofs M1-M15 all killed; suite
  972/0/9137 + 67/67. One HALT (memory reap during mutations) and a same-day resume. Status -> `review`.
  Task 12 (live smoke) awaits the operator. Nothing committed.
- 2026-09-22: code review (report-only, `C:\dev\_65a-review.md`) -- CHANGES REQUESTED, 1 blocking /
  13 non-blocking.
- 2026-09-22: review FIX pass (`C:\dev\_65a-fix.md`). B1 and N1-N12 applied under operator rulings;
  N13 needed no code. Four new mutations M16-M19 plus the golden probe G1; M17 came back GREEN and the
  test was strengthened until the same mutant died, both states recorded. Golden UNMOVED at `59e9a42c`,
  measured both directions. Suite 980/0/9183 + 67/67. ACs and Operator Rulings untouched. Status stays
  `review`; Task 12 still awaits the operator. Nothing committed.
- 2026-09-22: close-out chain (commits `C1`-`C5`). Live smoke PASS 7/7 (operator, two pads, flip
  [3,3]); Status -> `done`. Two AC 13 test citations updated for the N12 rename (claims unchanged).
  Before the chain's Step 0 suite run, a malformed format string in a new test's assertion message
  (`test_spell_framework.gd:439`, a literal `50%` colliding with GDScript's `%` format operator) threw
  a Godot engine `ERROR:` on every run without failing the assertion; fixed (`50%%`) and the full suite
  re-run clean, because `test/run_all.sh` fails the harness gate on any `^ERROR:` line regardless of
  test outcome, and this one would have broken a later run for no real defect.
