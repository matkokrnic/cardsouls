---
baseline_commit: da157e6419982342e91e4c22b5c8fe462bc2f103
---

# Story 7.4: Pitch speeds (instant and sorcery) and a per-launch shuffle seed

Status: ready-for-dev

Tier **A** (touches `src/state/`: a new per-zone hashed fact and a changed READY rule). Authored 2026-10-09 against
HEAD == origin/main == `da157e6`, tree clean. Scope is the operator's ruling set of 2026-10-09 (below, all accepted); the
decision-log session "7-4 scope + readiness gate" assigns `7-4/R1..R20`. Numbers marked TEMP are placeholders for 7-7.

## Story

As a player, I want every card's pitch side to be either an instant (fires as soon as I can pay) or a sorcery (only orbs I
earn while it waits count), so that pitching a sorcery is a commitment to land the right unblockable, not a bank withdrawal.
As the operator, I want every game launch to shuffle differently and a way to pin the shuffle, so that playtests vary and a
bug seen in a smoke can be reproduced.

## Scope rulings (operator, 2026-10-09, all accepted)

1. Every card's pitch side carries a speed: instant or sorcery. Speed is card data, authored per card, changeable with one
   file edit.
2. Instant is today's behaviour: the staged card is READY as soon as the bank holds its priced orbs.
3. Sorcery: orbs already banked when the card is staged do not count. The card becomes READY only once orbs of the required
   colour(s), earned while the card sits in the zone, cover its orb price (`7-4/R2`). Activation spends the priced orbs from
   the bank. When every fresh orb was actually banked, the orbs banked before staging and any fresh surplus remain (usable by a
   later instant card): bank red 3, price red 1, one red earned -> bank 4, activation -> bank 3. At the cap the bank simply drops
   by the price: bank red 5, price red 1, one red earned at the cap -> bank 5, READY, activation -> bank 4 (`7-4/R11`).
4. One fizzle timer for both speeds (the existing value). Card prices unchanged; any sorcery discount is 7-7 tuning.
5. Everything else about the zone is unchanged: mana paid at staging, activation by button, expiry = card lost. The zone's exits
   are activation, fizzle and the debug reset; there is no pitch-cancel exit (`7-4/R4`).
6. The orb-clear-on-pitch bool is not touched (stays default off; its removal remains the post-playtest decision from 6-2).
7. Deck 1 assignment (by pitch effect): instant = Counterspell, Culling, Vampiric Aura; sorcery = Fireball, Raise Dead,
   Corpse Bomb, Boom. A test pins this assignment. Cards outside Deck 1 (fixtures, totems) default to instant.
8. Card speed is card content. Like orb prices (6-2 H1), it never enters the hashed snapshot; it is derived from the hashed
   card identity through injected data. Only per-zone state that changes across ticks (fresh orbs earned so far) may be hashed.
9. Visibility: only sorcery cards carry a marker on the card face (hourglass), in hand and in the pitch zone. A sorcery in the
   zone shows its required orbs as empty sockets that fill only with orbs earned after staging, visible to both players. Instant
   needs no new visual. Builds on the 7-6 card faces and the 6-3a pitch zone HUD; a placeholder marker is acceptable.
10. Shuffle: every game launch gets a new random seed; each player gets their own deck order. The seed is shown on the F3 debug
    layer. A data knob pins the seed (0 = random each launch). Replay stays identical because the seed is already in the replay
    record. Tests and golden keep their fixed seed (through the runner's `seed_override`, `7-4/R15`). The random draw lives
    outside `src/state/`.
11. "+1 mana for a defended unblockable" (the board note and `epics.md`) was delivered by 7-9 (`7-9/R6`, 7-9 AC 10: a successful
    colour counter grants +1 mana; `7-8/R20` moved it off this story). This story records it as delivered elsewhere and does
    not re-implement it.
12. One story, Tier A.

## Acceptance Criteria

Behaviour and acceptance only; mechanism is in Dev Notes. `[M]` machine-checkable, `[S]` live smoke. Every
new number is a named knob or authored datum.

**S1 Speed as card data**

1. **[M]** Every card's pitch side has a speed, instant or sorcery. A card that authors none reads instant. Changing a card's
   speed is one edit to that card's data file, with no source edit.
2. **[M]** Deck 1 is pinned by a test: Ruin Vanguard (Culling), Drain (Vampiric Aura) and Honed Bolt (Counterspell) are instant;
   Grave Ward (Raise Dead), Rocksling (Boom), Bloodhound Step (Fireball) and Frostbite (Corpse Bomb) are sorcery. Every card
   outside Deck 1 reads instant.
3. **[M]** A card's speed is never in the hashed snapshot and never changes the snapshot key set. Re-authoring a speed after a
   recording was made cannot change what that recording replays.

**S2 Instant**

4. **[M]** An instant is READY exactly when the bank holds its priced orbs: staged while the bank already holds them, it is
   READY on the staging tick, and activation spends exactly the priced orbs. Every refusal and count of an instant is the
   existing one.

**S3 Sorcery**

5. **[M]** A sorcery staged while the bank already holds at least its priced orbs is NOT READY. Pressing activation is refused
   through the existing not-ready refusal and nothing is spent, staged, or discarded.
6. **[M]** Each orb earned while the sorcery sits in the zone counts toward the price for its own colour. The card becomes READY
   on the tick the last required colour is covered, not before, and only while the bank also holds the price (after a hot reload
   that lowers the orb cap the card is not READY until the bank covers the price). Orbs of a colour the price does not name never
   count. An orb granted on the tick the card is staged does not count: within a tick the hit resolves before the card is staged,
   so it was banked first. The same-tick case is reachable only when the first touch falls on the staging tick, since staging is
   refused while the staging player's own unblockable is CHARGING.
7. **[M]** Activation of a READY sorcery spends the priced orbs from the bank. When every fresh orb was actually banked, the orbs
   banked before staging and any fresh surplus remain. Example below the cap: bank red 3, price red 1, one red earned -> bank 4,
   activation -> bank 3. At the cap the bank simply drops by the price. Example: bank red 5, price red 1, one red earned at the
   cap -> bank 5 and READY, activation -> bank 4.
8. **[M]** The fresh-orb count is empty whenever the zone is empty, and starts empty on every staging. It clears wherever the zone
   clears: activation, fizzle, debug reset. It does not advance during the round-over freeze.
9. **[M]** The fizzle timer, card prices, mana-at-staging, activation by button and "expiry = card lost" are unchanged for both
   speeds. A READY sorcery that fizzles is lost like any staged card; the fresh orbs stay in the bank. Two degenerate prices read as
   today: a sorcery with no orb price is READY at once (nothing to earn), and with the orbs layer off every staged card is READY
   regardless of speed.
10. **[M]** An orb earned while that colour's bank is already at its cap still counts toward a sorcery's price; the bank itself
    never exceeds the cap.
11. **[M]** A sorcery's progress is a pure function of the hashed state and the injected data: a replay of a recording reproduces
    which tick the card became READY, and the golden and key-set prediction in this file holds.

**S4 Visibility**

12. **[S]** Only sorcery cards carry the hourglass marker, on the card face in hand and in the pitch zone, visible to both players.
    Instants carry no new visual.
13. **[S]** A sorcery in the zone shows one socket per required orb. A socket is empty at staging even when the bank holds that
    colour, fills only with an orb earned after staging, and both players see the same sockets. Reaching READY looks like today's
    READY.
14. **[M]** A sorcery card's orb pips in hand always draw as hollow rings, never lit from the bank, even when the bank holds the
    colour; an instant's pips light from the bank as they do today. The pips and the hourglass read the card's speed through the
    static card derive, so the opponent's zone card shows the same marker.
15. **[M]** The sockets' state reaches both HUDs without a new seam; the number of runner seams stays as pinned.

**S5 Shuffle seed**

16. **[M]** With the knob at 0, two boots draw different seeds (read from the recorder's `replay_seed()`) and the same seed gives
    the same deal; each player's deck order is their own. Different first hands across two launches is a smoke check. The draw
    is outside `src/state/`; the architecture invariants (F1, D3(a), D3(b)/A2) and the AC 8 shuffle/seed ban stay green.
17. **[M]** The pin knob is `data/seed_pin.tres`, a load-once resource whose script is `src/main/seed_pin.gd` (outside
    `src/state/`), read only by the runner; it is not in the hot-reloadable balance config and not in `main.tscn`. 0 means a new
    random seed each launch; a non-zero value deals the same hands on every launch.
18. **[S]** The F3 debug layer shows the seed in use. Hidden with the layer.
19. **[M]** The seed in use is the one in the replay record; a replay of a random-seed game is identical. The runner var
    `seed_override`, set before the runner enters the tree, fixes the seed for headless tests (precedence: replay record >
    `seed_override` > knob file > random draw); every live test that depends on the dealt hand sets it to 12345. The golden
    is unaffected by the launch draw.

**S6 Non-goals held**

20. **[M]** The orb-clear-on-pitch bool is untouched. The +1 mana for a defended unblockable is not re-implemented (delivered by
    7-9). Prices, the fizzle timer and the orb cap are unchanged.
21. **[M]** The full gate (state harness plus integration) is green; the Live Smoke passes; fps is stable.

## Tasks / Subtasks

- [ ] T1 Speed data and Deck 1 assignment (AC 1-3)
  - [ ] Author the speed on the Deck 1 cards' pitch sides per ruling 7; unauthored defaults to instant.
  - [ ] Test pinning the seven assignments and the default (AC 2).
  - [ ] Carry the speed to state through the existing injection path; confirm it rides the record (AC 3, 11).
- [ ] T2 Sorcery READY and spend (AC 4-11)
  - [ ] Per-zone fresh-orb count, hashed, cleared where the zone clears (AC 8).
  - [ ] Credit it at the orb faucet (`_grant_landing_orbs`) including the full-bank case (AC 10).
  - [ ] READY and activation read it for sorcery, unchanged for instant (AC 4-7).
- [ ] T3 Presentation (AC 12-15)
  - [ ] Hourglass on hand and zone card faces; neutral pips on sorcery cards in hand; sockets in the zone; extend the existing pitch payload.
- [ ] T4 Seed (AC 16-19)
  - [ ] Runner draws the launch seed; `data/seed_pin.tres` + `src/main/seed_pin.gd`; `seed_override`; F3 label; recorder already captures the seed.
  - [ ] Set `seed_override = 12345` in every live test that depends on the deal (candidates in the table below).
- [ ] T5 Golden, format, tests (AC 3, 11, 21): measure, re-baseline once, fix the tests in the table below.
- [ ] T6 Live smoke (below), then close-out records.

## Measured Facts

Measured 2026-10-09 at `da157e6`, by content (path + quoted text).

**M1. Where READY is computed.** `src/state/pitch/pitch_state.gd`, `func is_ready(slot: int, orbs: OrbPool, flags: FeatureFlags)`:
`return is_staged(slot) and CastEvaluator.orb_costs_affordable(staged_orb_costs(slot), orbs, flags)`. Its doc: "THERE IS NO READY
FLAG ... 'is this staged card ready' is DERIVED from the live pool every time it is asked". The loop is
`CastEvaluator.orb_costs_affordable` (`src/state/economy/cast_evaluator.gd`) over `sorted_orb_colors`, comparing
`orbs.get_count(color) < int(orb_costs[color])`. READY is read at activation (`REASON_PITCH_NOT_READY`) and for the HUD payload
(`MatchState._queue_pitch_changed` binds `pitch.is_ready(slot, owner.orbs, flags)`).

**M2. How activation spends.** `MatchState._resolve_pitch_activate`: guard order layer flag, STUNNED, empty zone, not READY,
then the board gate, then
`for color: Enums.CardColor in CastEvaluator.sorted_orb_colors(orb_costs): player.orbs.add(color, -int(orb_costs[color]))`
off `pitch.staged_orb_costs(slot)`. Its doc: "Surplus and unpriced colours are untouched" (`6-3-split/R-SPEND`). Mana is paid at
staging, not here.

**M3. How orbs are earned and banked.** There is exactly one faucet: `MatchState._grant_landing_orbs`, called from the
unblockable landing branch after `player.charge_contact = PlayerState.CHARGE_CONTACT_HIT`; it does
`player.orbs.add(player.charge_color, grant)` with `grant = roundi(EconomyEvaluator.amount_for(...SOURCE_UNBLOCKABLE_LANDING...))`.
`data/balance/balance_config.tres`: `unblockable_orb_grant = 1`. A TOUCHED contact (`charge_contact = CHARGE_CONTACT_TOUCHED`),
a counter and a drop grant nothing. Orbs spend only at pitch activation (M2) and clear on `reset_all` (debug reset, and the
optional staging clear). The 7-9 colour counter grants mana, not orbs. The bank is per colour in `OrbPool` (`_red/_blue/_green`).
After a landing, if the zone is staged, `_queue_pitch_changed` re-emits so READY reaches the HUD that tick.

**M4. The bank HAS a cap.** `data/balance/balance_config.tres`: `max_orbs_per_color = 5`. `OrbPool.add`:
`updated = clampi(updated, 0, _max) if _max >= 0 else maxi(0, updated)` and `if updated == current: return` (no signal on no
change), applied to each colour independently. So a grant into a full colour changes nothing; the ruling that such an orb still counts toward a sorcery is `7-4/R11`.

**M5. What clears or resets zone state today.** `PitchState.clear` is the single seat that empties a zone; its doc names three
callers and `match_state.gd` confirms exactly three: `_resolve_pitch_activate` (`pitch.clear(slot)` after the orb spend),
`_resolve_pitch_expiry` (fizzle: card to discard, replacement owed) and `_reset_player` (debug reset, the "SIXTH NAMED EXCEPTION":
"this player's PITCH ZONE, emptied with its countdown stopped"). Death does not clear it; the zone freezes with the round
(`pitch.tick()` sits after step 1b: "a round-over tick never reaches this line and a staged card's countdown FREEZES with the
round") and the reset clears it. `_end_round` clears no orbs. **There is no cancel exit in `src/`:** a search for a pitch cancel
finds nothing, and `PitchState.clear`'s doc lists fizzle, activation and debug reset only (`_resolve_pitch_expiry`'s doc: "cancel
has no owning story"). The story therefore names those three exits only (`7-4/R4`). Whatever clears the zone through `clear`
clears the fresh count.

**M6. Where the seed comes from.** `src/main/match_runner.gd`: `const _SEED := 12345`; `var seed_value := _replay_record.replay_seed() if replaying else _SEED`;
`_recorder.capture_seed(seed_value)` when not replaying; `MatchState.new(MatchParams.new(seed_value))`; `MatchState`:
`_rng.seed = params.seed_value`. The runner comment pins the home: "It stays a constant here until a story needs a per-match seed
source (a menu, a replay file)", and the same runner comment (`match_runner.gd:15-18`): the seed "does NOT belong in the hot-reloadable BalanceConfig, where a reload
would re-seed the RNG mid-match" (`E3-RG/R9`); `match_params.gd` says something related in different words.

**M7. Deck order per player and across reset.** Already per player: `_deal_pending_decks` calls `_deal_player(p1)` then
`_deal_player(p2)`, each doing `set_contents` then `_shuffle_deck`, "shuffled against the SAME generator in turn — which is how the
two players get different orders out of one seed without a second RNG ever existing". The reset re-arms the deal
(`_deck_deal_pending = true`) and `_deal_player` shuffles again from the same running `_rng` (not re-seeded), so R gives a new,
deterministic order. One shuffle seat: `_shuffle_deck`.

**M8. The F3 layer.** `MatchRunner.set_debug_layer_visible(shown)` ("the one seat the F3 edge (step 0) calls"): sets
`_instrument_panel.visible`, every `StateInspector`, each `HudRoot.set_debug_layer_visible`, and the telegraph cues. The panel is
`src/ui/debug/debug_instrument_panel.gd` (title label `"-- DEBUG INSTRUMENTS --"`, hidden by default, the runner pushes values to
it, e.g. `_instrument_panel.set_window_countdown(...)`). The seed is a one-time fact, so the natural seat is a label on that panel.

**M9. How pitch prices are injected and recorded (6-2 pattern).** Runner `_derive_pitch_costs()` walks `CardDatabase.sorted_ids()`
and maps id to `card.pitch_condition` (a `CardCastCondition`); non-replay branch only: `_recorder.capture_inject_pitch_costs(pitch_costs)`
then `_match_state.inject_pitch_costs(pitch_costs)`; `MatchState._pitch_costs: Dictionary[StringName, CardCastCondition]`; the
price is copied by value at staging (`PitchState._orb_costs`, unhashed) and "THE ORB PRICE IS NOT HASHED". The recorder
captures every script-declared property generically (`IntentRecorder._resource_values`, `PROPERTY_USAGE_SCRIPT_VARIABLE`), so a
new field on `CardCastCondition` rides the existing `pitch_costs` channel with no new channel. `RecordFile._resource_values`
(`record_file.gd:820-826`) captures every script variable too, so the field also widens the rows of BOTH the card-cost and
pitch-cost channels (a SHAPE change, `7-4/R19`); a v21 record is refused hard, so default-on-missing never matters. The HUD reads static prices through
`_derive_card_prices()` (never injected, never recorded); a marker needs the same kind of static derive.

**M10. Visibility today.** `pitch_changed(slot, card_id, hand_slot, ready, remaining, duration)` is the runner's tenth seam; its
doc: "NO ORB COST, NO SHORTFALL AND NO PER-COLOUR ORB NUMBER RIDES THE PAYLOAD (`6-3-split/R-INFO`)". `7-6/R7` supersedes the
reasoning ("orb counts are now deliberately PUBLIC") by showing world orbs around each hero. 7-10 states "the family stays at ten".
The hand pips are lit from the held bank (`hud_root.gd`: "each pip lights when an orb of its colour is held", count-fill).

**M11. Tick order of the hit versus staging.** `advance()` step 3 ("Resolve actions") reaches the CHARGING arm and `_resolve_charge_contact`, which calls `_grant_landing_orbs` (`match_state.gd:6225`); under 7-8/R1 the hit lands on the touch, not at the landing (`match_state.gd:1816`, "THE HIT LANDS ON THE TOUCH, NOT AT THE LANDING"); step 6 ("Card / economy") runs `_resolve_card_action(p1, ...)` then `p2`, which is
where `_resolve_pitch_stage` stages. So in one tick the orb is banked before the card is staged. Staging is refused while the stager's own unblockable is CHARGING (`REASON_UNBLOCKABLE_COMMITTED`, `:5593-5595`), so the same-tick case is reachable only when the first touch falls on the staging tick; the test that pins AC 6's same-tick clause must be built that way. `pitch_stage_clears_orbs`
(`balance_config.tres`, false) would empty the bank at staging; it does not touch a sorcery's fresh count, which starts at zero.

**M12. Golden and format pins.** `test/state/test_determinism.gd:1336` `const GOLDEN := "9d5d4fad..."`; `test/state/test_record_file.gd:239` and `:1435`
`assert_eq(RecordFile.FORMAT_VERSION, 21 ...)`, "a BEHAVIOUR change" bumped it at 7-9 with no new channel. Authored deck:
`data/decks/deck_1.tres` lists ruin_vanguard, grave_ward, drain, rocksling, bloodhound_step, honed_bolt, frostbite; the pitch
effects are `data/effects/{culling,raise_dead,vampiric_aura,boom,fireball,counterspell,corpse_bomb}.tres`, referenced from `data/cards/*.tres` through `[ext_resource ... id="4_pitch"]`; every pitch condition is an inline `SubResource("Resource_pitch")`, so one speed edit touches one card.

### Contradictions between the prompt and the repo (flagged, not reinterpreted)

- **C1. Cancel. CLOSED (`7-4/R4`).** The operator's first wording listed "cancel" as an existing zone exit; the repo has none
  (M5). Ruling 5 now names activation, fizzle and the debug reset, and AC 8 clears at those exits.
- **C2. Ruling 7 names effects; ruling 1 puts speed on the card.** The seven names are pitch effects; the speed is authored on the
  card holding that effect (mapping in AC 2, measured from the `.tres` files). Moving an effect to another card later leaves its
  speed on the old card, because the speed belongs to the card's pitch side.
- **C3. "Each player gets their own deck order"** already holds (M7). The story pins it, it does not build it.

## Dev Notes

### Mechanism (rulings `7-4/R13`, `R14`, `R15`)

- **Speed seat (`7-4/R14`).** A new enum (`Enums.PitchSpeed`: INSTANT, SORCERY) and one export on the *pitch* `CardCastCondition`.
  It rides `pitch_costs` through `_derive_pitch_costs` and the recorder with no new channel (M9). The speed is READ at read time
  from the already-injected `MatchState._pitch_costs[card_id]` (or passed as an argument), never cached per zone (the `_orb_costs`
  copy-at-staging shape would be a new unhashed cross-tick member and move `UNHASHED_CROSS_TICK_MEMBERS`; it stays 4). The
  Mode-① `cast_condition` shares the schema, where the field is meaningless: say so in the field's doc.
- **Fresh orbs.** A per-zone, per-colour count in `PitchState` (index-aligned, two slots), hashed under the existing `"pitch"` key
  as plain ints (ASCII string keys, never StringName keys), cleared inside `clear()`, copied at `stage()`'s time as zero. Credited
  from `_grant_landing_orbs` beside the existing `_queue_pitch_changed` call, only for a staged sorcery. A sorcery is READY when
  the fresh orbs cover the price AND the bank covers the price (the second is always true in normal play; it matters after a hot
  reload lowers the cap, where `OrbPool.set_maximum` clamps the counts and `match_state.gd:909-910` names that reload path).
  `CastEvaluator.orb_costs_affordable` takes an `OrbPool` (`cast_evaluator.gd:124`), not a count dict: the sorcery path reuses
  `sorted_orb_colors` through a dict variant of that function (or a direct loop over it), so the iteration order stays in one place.
  The new per-zone member is classified HASHED in `test_replay_identity.gd`'s member list.
- **Spend.** Unchanged `add(color, -price)` off `staged_orb_costs`. Because a zone holds one card at a time and only activation
  spends orbs, fresh credit and bank cannot disagree, except through the cap (`7-4/R11`: the fresh count still counts, the bank clamps).
- **Payload.** Extend `pitch_changed` rather than add a seam: the runner-seam count is pinned and 7-10 states it stays at ten.
  The public socket state (per-colour fresh counts, capped at the price) is a small addition; the 7-6/R7 supersession (M10) covers
  the information question. Extend `signal pitch_changed` (`match_state.gd:50-51`), `_queue_pitch_changed` (`:7016-7021`) and
  `HudRoot.on_pitch_changed` (`hud_root.gd:528`); the binding at `match_runner.gd:645` stays. Rewrite the `6-3-split/R-INFO` doc at
  `match_state.gd:42-44` ("NO PER-COLOUR ORB NUMBER RIDES THE PAYLOAD"); `7-4/R20` records the supersession.
- **Seed (`7-4/R13`, `R15`).** The draw lives in the runner (outside `src/state/`). The pin knob is `data/seed_pin.tres` with its
  Resource script `src/main/seed_pin.gd` (class `SeedPin`, the runner's folder), load-once, read only by the runner; not
  `BalanceConfig` (M6), not `main.tscn`. Precedence at `match_runner.gd:413`: replay record > `seed_override` > knob file > random
  draw. `seed_override: int` is a runner var set BEFORE the runner enters the tree, on the `deck_list_override` precedent
  (`match_runner.gd:891-894`: "Set BEFORE the runner enters the tree ... read nowhere else"); 0 = unset. Display on the debug
  panel (M8). The AC 8 / D3(b) scans cover `src/state/` only, so a draw in the runner stays green.
- **Hand pips and marker (`7-4/R8`, `R12`).** `_derive_card_prices()` (`match_runner.gd:1059-1071`) covers the whole library, including
  the opponent's zone card: add a 5th row element (speed); a missing element reads instant, so the 4-element fixtures in
  `test_card_face.gd:42-43` keep working. Readers: `hud_root.gd` `_apply_affordability` (pips at `:748-753`; "held = a filled
  circle, missing = a hollow ring") draws a sorcery's pips as hollow rings always; `_render_pitch_zone` (`:871`) draws the
  hourglass and sockets; zones are built at `:411-412`.
- **Live tests and the deal.** Under `seed_override = 12345` the deal is today's. Candidates that read or act on the dealt hand (the
  dev pass confirms): `test_hole_vs_in_flight_live.gd` (line 84 casts hand slot 1), `test_card_selection_indicator.gd`,
  `test_card_mode_lift.gd`, `test_cast_success_cue_live.gd`, `test_card_hud.gd`, `test_card_tint_live.gd` (`hand.to_array()`),
  `test_deck_injection.gd` (lines 142-148, 230, 275), `test_debug_instruments.gd`, `test_record_save_control.gd`,
  `test_effect_presentation_live.gd`, `test/perf/*_live.gd`. The 8 tests on `deck_list_override`/`LiveSummonDeck` are safe (one
  card type). Dev-pass step: one extra integration run with `data/seed_pin.tres` forced to a non-default seed (backed up with
  SHA-256, restored by copy-back, disclosed as an extra run) to catch unlisted dependents.

### Files expected to change

`src/state/pitch/pitch_state.gd` (fresh count, READY, snapshot), `src/state/match_state.gd` (`_grant_landing_orbs` credit,
`_resolve_pitch_stage`/`_resolve_pitch_activate` reads, `_queue_pitch_changed` payload, `_reset_player` via `clear`),
`src/state/resources/card_cast_condition.gd` and `src/state/enums.gd` (speed), `data/cards/{grave_ward,rocksling,bloodhound_step,frostbite}.tres`
(sorcery), `src/main/match_runner.gd` (seed draw, `seed_override`, knob read, panel label, HUD derive), `src/ui/debug/debug_instrument_panel.gd`,
`src/ui/hud/hud_root.gd` (marker, neutral pips, sockets), `src/main/seed_pin.gd` + `data/seed_pin.tres` (knob), the live tests that set `seed_override`,
`docs/planning-artifacts/deck-1-spec.md`. Preserve: the instant path byte-for-byte in behaviour, the single `_shuffle_deck` seat,
`PitchState` as a pure container (no RNG, no balance, no card library), `orb_costs_affordable` as the one sorted-colour loop.

### Golden Prediction (prediction only; the dev pass measures, both directions)

- **Golden: MOVES, one re-baseline.** Cause 1, SNAPSHOT SHAPE: the new per-zone fresh-orb keys under `"pitch"` for both zones
  (resting zeros). Cause 2: none from speed itself (content, unhashed; the golden never stages a pitch card, `test_determinism.gd:945`: `card_mode == PITCH`, so both zones hash empty on every tick). If the dev implements the fresh count without any new hashed key, the golden does not move, and then Tier A still
  stands on the state-layer change; measure rather than assume. Snapshot key-path set grows by the new keys (count it).
- **FORMAT_VERSION: 21 -> 22, predicted (`7-4/R19`).** Cause: BEHAVIOUR + SHAPE (the 7-9 precedent was "a BEHAVIOUR change ... plus a
  SHAPE change", `test_record_file.gd:239-244`): a recording made before this story replays Deck 1 sorceries as instants, and the pitch
  and card condition rows gain the speed key through `RecordFile._resource_values`. No new channel; `SOUND_CONTENT_ORDER` is untouched.
  Speed adds no snapshot key.
- **Seed:** no hash effect (the draw is runner-side; the record already holds the seed). `FORMAT_VERSION` is untouched by it.

### Tests expected to break

| File | Test / pin | Why |
|---|---|---|
| `test/state/test_determinism.gd:1336` | `GOLDEN` and the snapshot key-path count | New hashed per-zone keys (cause 1). Re-baseline once, measured both directions. |
| `test/state/test_record_file.gd:239` and `:1435` | both `assert_eq(RecordFile.FORMAT_VERSION, 21, ...)` | Predicted bump to 22 (behaviour + shape). |
| `test/state/test_replay_identity.gd` | `UNHASHED_CROSS_TICK` list (ends `"pitch_state._orb_costs"`, line 176), `UNHASHED_CROSS_TICK_MEMBERS := 4` (line 178), `test_unhashed_cross_tick_state_is_exactly_four_members` (line 834) | The new fresh-orb member is classified HASHED; the count stays 4 because speed is read from `_pitch_costs`, not cached. |
| `test/state/test_pitch_staging.gd` (`:282-288`, `:490-496`) | exact empty-zone dicts `{"card_id": "", "hand_slot": ..., "fizzle": {...}, "mana_spent": 0.0, "locked_damage": 0.0}` | Break on any new key under `"pitch"`. READY tests that bank orbs first stay instant by default. |
| `test/state/test_pitch_changed.gd` | payload shape | Payload gains the socket state. |
| `test/state/test_card_authoring.gd:100` | `CARD_DATA_FIELDS` exact pin; the pitch price/census loops | Not affected while the field is on the pitch condition; a Deck 1 speed table is added (AC 2). |
| `test/integration/test_pitch_ghost.gd` (10 direct `_hud.on_pitch_changed(...)` calls), `test_card_face.gd` (8 such calls, lines 545-643) | `HudRoot.on_pitch_changed` (`hud_root.gd:528`) | Payload arity changes. |
| `test/integration/test_pitch_hud_live.gd`, `test_hud_viewports.gd` | pitch zone HUD and card face layout | Marker, neutral pips, sockets. |
| Integration staging tests | none | Measured: no test stages a Deck 1 sorcery from shipped data. `test_fireball_live.gd` pokes `start_cast(... PITCH ...)` directly, `test_boulder_and_skull_live.gd` presses BASIC only, `test_history_and_orbs_live.gd` calls the relay and never stages. |
| `test/integration/*_live.gd` that read the dealt hand (62 files build the runner; only 8 use `deck_list_override`/`LiveSummonDeck`) | any test relying on the fixed 12345 hand | The per-launch seed changes the hand. Candidates listed in Dev Notes "Live tests and the deal"; each sets `seed_override = 12345` (`7-4/R15`). |
| `test/state/test_fireball.gd` (12), `test_counterspell.gd`, `test_own_minion_spells.gd`, `test_rocksling_and_boulder.gd`, `test_corpses.gd`, `test_spell_framework.gd`, `test_spell_targeting.gd`, `test_hero_cast.gd` | state tests that stage and bank | Expected UNAFFECTED: they inject in-test cost literals (default instant, `BC/R3`; `_costs()`/`_pitch_costs()` helpers). Listed because the dev must confirm, not assume. |
| `test/state/test_architecture_invariants.gd` | AC 8 shuffle/seed ban, F1, D3 | Expected to stay green; the draw is in `src/main/`. Confirm the scan scope. |

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md, applicable here)

- F1: one `_physics_process`, in `match_runner.gd`. D3(a): `Input.*` only under `src/controllers/`. D3(b)/A2: no global RNG, `Time`,
  `OS` or `Engine` in `src/state/`. The shuffle stays at the single `_shuffle_deck` seat.
- Content (card speed, prices) is injected once at match start, recorded by value, never hashed. Hashed per-tick facts are
  state. Hash keys are ASCII strings, never StringName keys.
- Tier A: full gate, review, live smoke. Docs and code never share a commit. Validation worth proving is committed as a test.
  Commit messages pure ASCII via `git commit -F <tempfile outside the repo>`; trailer per the session reminder.
- Authored balance is isolated from the golden and the unit suite (`BC/R3`), but that protection is for VALUES; a new seat or a
  newly refusable action moves tests and the golden (`SC/R6`). This story adds a seat.

### Docs debt for close-out

- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md`, Epic 7 key stories, item 5 (`7-4-pitch-speeds`) still reads
  "...; plus +1 mana for a defended unblockable." That clause was delivered by `7-9/R6` (7-9 AC 10) and moved off this story by `7-8/R20`
  (`epics.md:345-346` verified). Not edited here; fix at close-out. Also add the amendment in `deck-1-spec.md` (done at authoring, 2026-10-09).
- The R-labels are assigned: decision-log session "7-4 scope + readiness gate", `7-4/R1..R20`.

### References

- `docs/planning-artifacts/deck-1-spec.md` (amendment 2026-10-09), `docs/implementation-artifacts/7-9-unblockable-tempo.md` (R-D6, +1 mana, `7-9/R6`), decision-log `7-4/R1..R20`,
  `docs/implementation-artifacts/7-10-unblockable-presentation.md` (seam family, 7-6 debug layer), decision-log `6-3-split/R-INFO`,
  `6-3-split/R-SPEND`, `7-6/R7`, `E3-RG/R9`, `SC/R6`.

## Live Smoke

Solo `[0,3]`: the operator on the pad (P2) stages, lands the unblockables and activates; P1 on the keyboard is the target, because
the keyboard has no pitch path (`7-4/R16`). Add `slot_controller_kinds = Array[int]([0, 3])` under `script =` in the Main node of
`src/main/main.tscn` (the committed file has no such line); **delete it before any suite or chain run**. Seed pinned or not as each
step says.

1. **Instant READY from the bank.** P2 lands an unblockable so the bank holds the colour, then stages an instant (Counterspell, Culling
   or Vampiric Aura, whichever the hand holds): READY on the staging tick, activation spends exactly the price.
2. **Banked orbs do not count for a sorcery.** With the bank already holding the sorcery's colour(s), P2 stages a sorcery (Fireball,
   Boom, Corpse Bomb or Raise Dead): the zone shows empty sockets, not READY; pressing activation is refused.
3. **Right colour fills, READY, spend.** P2 lands an unblockable of the required colour: one socket fills, the card reaches READY,
   activate. Only the priced orbs are spent; the earlier banked orbs remain (check the world orbs).
4. **Wrong colour does not fill.** P2 lands an unblockable of another colour while a sorcery waits: no socket fills.
5. **Fizzle loses the card.** P2 lets a staged sorcery run out its timer: the card is lost, the fresh orbs stay banked.
6. **Hourglass marker and pips.** The hourglass is visible on sorcery cards in hand and in the zone, from both sides (both viewports),
   and absent on instants. On a sorcery card in hand the pips stay hollow even when the bank holds the colour; an instant's pips still
   light.
7. **Two launches, different hands.** Launch twice with the knob at 0: different first hands. Debug-reset (R) gives a new order.
8. **F3 shows the seed.** The seed appears on the debug layer and is hidden with it.
9. **Pinned seed repeats.** Set `data/seed_pin.tres`, launch twice: the same hand both times. Reset the knob to 0 afterward.
10. **R-D6.** A round ends normally (a kill ends it, the reset starts the next); the zone is empty after the reset.
11. **fps stable** during all of the above (no hitch on socket fill or seed display).

## Rulings (2026-10-09)

Operator scope rulings S1-S12 and the browser rulings are recorded in the decision-log session "7-4 scope + readiness gate":
`7-4/R1..R10` scope (speeds, sorcery rule, one timer, no cancel, Deck 1 assignment, hourglass, seed, one Tier A story);
`7-4/R11` full bank (a fresh orb at the cap still counts); `7-4/R12` neutral pips on sorcery cards in hand; `7-4/R13` the seed-pin
knob file and script; `7-4/R14` speed read at read time, not cached; `7-4/R15` `seed_override` and the live-test sweep;
`7-4/R16` smoke roles; `7-4/R17` Raise Dead's price is a 7-7 input; `7-4/R18` break-table corrections; `7-4/R19` FORMAT_VERSION
21 -> 22, BEHAVIOUR + SHAPE; `7-4/R20` payload doc supersession.

## Change Log

- 2026-10-09: authored (scope talk, `da157e6`).
- 2026-10-09: readiness gate NOT READY (2 blocker, 4 major, 14 minor, all textual; `C:\dev\_74-gate.md`). Fixed without re-gate:
  rulings carried in (`7-4/R1..R20`), AC 7 and 10 reworded for the cap, new AC 14 (neutral pips), seed seat `seed_override` and
  `data/seed_pin.tres` named, Live Smoke roles swapped to the pad player, break table corrected, FORMAT_VERSION cause widened,
  Status ready-for-dev.
