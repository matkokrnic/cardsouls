---
baseline_commit: dd61f9c69e052b2012668d6ef3a08ded46c8d7c4
---

# Story 4.1: Basic summon resolution

Status: done

> **Scope note.** Position 3 of the E4 order (`E4-P/R1`, decision-log Session 2026-08-07 -- E4
> ratification). Tier A (`E4-P/R9`: touches `src/state/`, the golden, and determinism) -- full
> ritual applies: readiness gate with numbered rulings -> dev pass -> code review -> live smoke
> where `R-D6` attaches -> close-out. **The readiness gate ran 2026-08-08 and returned NOT READY,
> 7 blocking findings (`R1`/`R2`/`R3` counted as one work package, below the `E4-P/R2` break line
> of 8, no split) -- the rulings below (`4-1/R1`-`4-1/R12` + the totem clause, decision-log Session
> 2026-08-08 -- 4-1 readiness gate) are applied in place through this story. `Status:` and the
> sprint-status entry now read `ready-for-dev`, operator-promoted (`CFG/R4`) after this pass.**
>
> **`E4-P/R2` -- the board collection ships INSIDE this story, not a separate one.**
> `docs/game-architecture.md` D9 already reserves it: "`PlayerState` will gain a `units`/board
> collection with its first consumer, story 4-1 (`E4-P/R2`) -- it carries no such reference
> today." The precedent to avoid repeating without cause is `card_effect.gd` itself: reserved
> vocabulary authored ahead of its consumer, carried unconsumed since 3-2. **NAMED BREAK LINE**
> (`E4-P/R2`): if this story's readiness gate returns more than 8 blocking findings, it splits
> into a state/board half and an actor/spawn half via `gds-correct-course` -- named now so a
> split is planned, not a rescue.
>
> **Where a unit's position lives is now RULED (`4-1/R12`).** `E4-P/R7` placed the obligation on
> this story's gate to ask the question, with the 1-8/1-9 hero-position precedent in hand, rather
> than default to whichever seems convenient; the gate ruled position stays actor-owned, hero
> precedent unchanged, this story ships positionless. See the Open Question section and Dev Notes
> below for the ruling text and the two named futures it hands to 4-2's gate.

## Story

As a player,
I want a Basic-mode summon cast to put a visible grey-box unit on the board,
so that a card I play has a persistent, on-screen consequence instead of vanishing into the
discard pile the way every card does today.

## Acceptance Criteria

1. **`CardEffect` gets its first consumer.** `basic_effect.effect_id` (authored on all nine
   fixture cards since 3-2, read by nothing until now) reaches a resolver at Basic-mode cast
   resolution (`MatchState._resolve_basic_cast`, `match_state.gd:856`, or its immediate
   successor). The resolver is the ONE place `effect_id` strings are matched against gameplay
   meaning -- exactly the `EconomyEvaluator`/`CastEvaluator` D6 sibling shape (pure evaluator,
   `MatchState`'s ordered dispatch applies the result).
2. **`CardEffect` reaches the state layer by one-shot injection, on the `inject_card_costs`
   precedent verbatim (`E4-P/R4`).** A new `MatchState.inject_card_effects(effects:
   Dictionary[StringName, CardEffect])` seat, called once at match start from the runner (the
   ONE place allowed to read `CardDatabase`, 3-3 AC 2/AC 8), total over the injected deck
   composition, `Invariant.check`-guarded the same way `inject_card_costs` is
   (`match_state.gd:339-344`). `src/state/` never names `CARDS_DIR` or `data/cards`;
   `test_state_layer_never_names_card_data` stays green UNEDITED (`E4-P/R4` -- this story's gate
   does not relitigate the seam shape).
3. **`effect_id` joins golden discipline BY RULING, not by a measurable move (`4-1/R4`,
   `E4-P/R6`).** The gate measured the golden deck as synthetic with in-test costs, so AC 3 does
   NOT claim a golden move from a `.tres` edit -- standing `BC/R3` isolation holds. The narrowing
   is a ruling only: an `effect_id` edit is a determinism-relevant class of change carrying review
   burden, same as a change to a card's `mana_cost` already carries. The machine half: an
   authoring test asserts every authored `basic_effect.effect_id` on every fixture card carries a
   recognized prefix (`summon_` or `spell_`).
4. **A `summon_*` effect id creates ONE unit record on the casting player's board/units
   collection.** `PlayerState` gains the collection D9 reserves (name: `units`, the architecture
   doc's own term) -- a pure, `RefCounted`-only structure on the `Deck`/`Hand`/`DiscardPile`
   precedent, holding no scene reference, no position, and no per-unit behaviour (AI/targeting/
   combat are 4-2/4-3, explicitly out of scope below). One record per resolved `summon_*` cast,
   appended in cast order. **Ruled positionless this story (`4-1/R12`)**: position stays
   actor-owned, the hero precedent unchanged; the real position-ownership decision is deferred to
   `4-2`'s gate where a consumer (`TargetingService`) exists. **The record carries no type/kind
   field (totem clause, ratified)** -- every `summon_*` id is treated identically, so this story's
   uniform treatment does not pre-commit `4-4`'s totem/minion differentiation.
5. **A `spell_*` effect id is a NAMED no-op, never a rejection, per `E4-P/R10`.** The cast has
   already passed `CastEvaluator`; mana is spent and the card discarded exactly as it is today.
   The resolver's spell branch performs no board mutation and reports an explicit, stated reason
   (a `StringName` in the `CastEvaluator` refusal-vocabulary style, e.g. `&"spell_not_yet_resolved"`)
   rather than silently returning. `bramble_snare`, `frost_dart`, and `ember_lash` (the three
   `spell_*` fixture cards) exercise this path; none of E4's committed obligations (minions,
   pooling, targeting, totems) is spells, and excluding spell cards from the deal is refused by
   the same ruling -- it would move the golden for no feature reason and drop three of nine cards
   from every test. **Ruled (`4-1/R10`): the stated reason is a RETURNED VALUE only, asserted in
   unit tests, explicitly OFF the `reject_action` seam** -- a spell no-op is a SUCCESSFUL cast and
   must not render a refusal to the player.
6. **Refusal is by RETURNED NAMED VALUES, never an `Invariant.check` crash and never
   `reject_action` (`4-1/R3`, ruled option (a)).** Two distinct named reasons, both proven:
   - **(i) missing-entry honest default** -- no injected effect entry for the cast id, the
     `cast_evaluator.gd` null-branch precedent, reachable via an effects-less fixture, proven with
     a DIRECTED test.
   - **(ii) unknown-prefix refusal** -- an entry exists but `effect_id` is neither `summon_*` nor
     `spell_*`. No fixture card produces this case today (the nine authored ids are exactly six
     `summon_*` and three `spell_*` -- confirmed by reading every `data/cards/*.tres`), so this
     branch is proven with a synthetic map entry in a unit test, never a claim of natural
     reachability.

   Injection is state-side OPTIONAL: the existing `MatchState`-building fixtures stay untouched
   and their casts land on reason (i). Record-side it is MANDATORY for v2 records --
   `missing_match_start_channels()` treats a missing effects channel as malformed. The LIVE
   runner path always injects: a guard proves the derive+inject pair is present in the
   non-replay branch.
7. **A visible grey-box unit actor appears for each resolved `summon_*` cast, owned by the
   runner.** `src/actors/minions/` (named `(4-1)` in the architecture Directory Tree,
   `game-architecture.md:615`) gains a grey-box scene -- a placeholder mesh sufficient for
   legibility only (GDD-authority visual fidelity is explicitly out of scope everywhere in this
   project; grey-box is the standing bar). The runner spawns one actor per unit record it learns
   about, on the `HeroActor`/telegraph-controller precedent: `src/state/` never holds the scene
   reference, `src/actors/` never holds gameplay logic beyond what the state layer feeds it.
8. **Units clear ONLY on the reset path, ruled (`4-1/R5`).** `_apply_debug_reset`
   (`match_state.gd:1257`) leaves a player's `units` collection empty afterward, and the runner
   frees the matching actors in response. `_end_round` (`match_state.gd:1244`) stays UNTOUCHED --
   the board persists through the round-over freeze and does not blink out at the instant of
   death. `_apply_debug_reset`'s "NOTHING else" contract comment gains a NAMED exception for
   units; the parked mana-survives-reset finding stays parked. "No stale units into a fresh round"
   is delivered by the reset path alone, on the existing `round_started` relay for the runner's
   actor cleanup, no new `EventBus` event.
9. **Snapshot integration stays counts-only, the `deck_size`/`hand_size`/`discard_size` precedent
   verbatim.** Whatever key(s) `to_snapshot()` gains for the board (e.g. a `unit_count`) carries
   no unit identity, no effect id, and no position -- consistent with the existing rule that a
   `StringName` or object reference reaching the hash is the failure mode every card-container key
   in this codebase exists to avoid (3-3 AC 5, 3-5a AC 6, 3-0c AC 11). **Attribution corrected
   (`4-1/R7`):** the per-player snapshot and its pinned key set live in `player_state.gd` /
   `test_card_observation.gd`, not `match_state.gd`'s match-level dict. **Scope note (`4-1/R12`):**
   this AC's wording is SCOPED to this story's own snapshot key -- "the key(s) added by this story
   carry no unit identity, no effect id, no position" -- and is explicitly NOT a standing bound; it
   must not foreclose the state-owned-position option at `4-2`'s gate.

10. **Replay parity (`4-1/R2`, new).** In replay mode, card effects arrive via
    `_replay_record.replay_inject_content()` from the record, never re-derived from
    `CardDatabase`; the replay identity coverage (`test_replay_identity.gd`) extends to the
    effects channel; unit spawn behaviour is identical live vs. replay.

## Deferred / Out of scope

- **Minion AI and targeting** (4-2) -- a spawned unit does nothing after it appears; no
  `TargetingService`, no movement, no `MinionPriority` `.tres` consumption.
- **Minion combat** (4-3) -- no HP, no damage, no death for a unit this story; "unit record" here
  means only "exists and is counted," nothing more.
- **Totems** (4-4) -- three of the six `summon_*` fixture ids are actually totem effects
  (`summon_combat_totem`, `summon_mana_accelerator`, `summon_stamina_accelerator`, all on the
  wardstone cards). This story treats every `summon_*` id identically -- one generic grey-box unit
  record, no totem-specific behaviour, no totem/minion type distinction. 4-4 differentiates
  totems from minions; this story does not pre-decide that shape. **Totem clause (ratified,
  measured pass):** the unit record carries NO type/kind field, stated explicitly -- uniform
  `summon_*` treatment therefore does not pre-commit `4-4`'s totem/minion differentiation. `4-4`'s
  second golden move is already ratified as its own Tier A reason (`E4-P/R9`), independent of this
  story.
- **Object pooling / performance** (4-5) -- units are plain instantiated/freed nodes this story;
  no pool. `4-5`'s tier is assigned at this story's close-out (`E4-P/R8`), genuinely undecided
  until the unit-ownership ruling below exists.
- **Real spell resolution** -- acquires an owner at the E4 close-out at the latest (`E4-P/R10`).
  This story's spell branch is a named no-op, not a partial implementation of any spell's actual
  effect.

## Open Question -- RULED at the readiness gate (`4-1/R12`)

**Where does a unit's position live?** RULED: the units record ships POSITIONLESS this story --
position stays actor-owned, hero precedent unchanged. The real position-ownership decision is
deferred to `4-2`'s gate, where a consumer (`TargetingService`) actually exists. AC 9's wording is
explicitly SCOPED to this story's own snapshot key and is NOT a standing bound -- it must not
foreclose the state-owned-position option at `4-2`. Both named futures (an inward position channel
derived by the runner, on the hero precedent, vs. state-owned floats reaching the hash directly)
are recorded in Dev Notes below as `4-2` gate input. The reasoning that led here, preserved:

The measured hero precedent: `hero_state.gd:5` states
"Pure RefCounted -- no scene, no Input, no position (position is actor-owned, F1)." `HeroState`
owns `velocity`, `facing`, `roll_direction` -- intent/derived quantities -- never a position.
`match_runner.gd:_gather_contact_facts` (line 643) reads `actor.global_position` directly off the
scene node and pushes only a DERIVED fact into state via `push_contact` (the 1-8 contact-fact
channel); position itself never crosses into `src/state/`.

Putting a unit's position directly into `PlayerState.units` (rather than on the unit's actor node,
with the runner deriving whatever fact state actually needs, same as the hero) would be a NEW
architectural asymmetry against that precedent -- not a forced choice. `E4-P/R7` places this
obligation explicitly on this story's gate rather than on `4-2`'s (where `TargetingService` will
actually need to query position), because AC 4's board collection ships here and the gate must not
let the collection's shape default to whatever is momentarily convenient for a consumer that does
not exist until 4-2. **This authoring pass presented the question with the precedent in hand; the
gate has now answered it, above.**

## Tasks / Subtasks

- [x] Add `MatchState.inject_card_effects()`, the `inject_card_costs` seam shape verbatim,
      `Invariant.check`-guarded for totality over the injected deck composition (AC: 2, 3). State
      the injection order explicitly (`4-1/R8`): deck -> costs -> effects.
- [x] `_derive_card_effects()` in the runner, the `_derive_card_costs()` precedent verbatim
      (`match_runner.gd:362-378`) -- walk `CardDatabase.sorted_ids()`, map id -> `basic_effect`,
      skip a card with no authored effect (AC: 2). The LIVE runner path always calls the
      derive+inject pair together, in the non-replay branch (`4-1/R3`).
- [x] **`4-1/R1` -- the full IntentRecorder content-channel package** (replaces the "one capture
      method + two pins" task; scope was incomplete as originally authored):
  - `intent_recorder.gd`: `CHANNEL_EFFECTS` constant; `SOUND_CONTENT_ORDER` becomes a 3-element
    ordered contract (`4-1/R8`: `CHANNEL_EFFECTS` sits at the END); `_effect_values` storage; a
    branch in `missing_match_start_channels()` (`4-1/R3`: a missing effects channel is malformed
    for a v2 record); `replay_card_effects()`; a branch in `replay_inject_content()` (AC: 10).
  - `record_file.gd`: `REQUIRED_KEYS`, `_to_dictionary`, `_from_dictionary`'s content-order match,
    `FORMAT_VERSION` 1 -> 2. Ruled: v1 records are REFUSED with a reason per that file's own
    contract -- NO migration shim, records are debug artifacts and a shim would be speculative
    machinery.
  - Tests that MOVE, named as deliberate pin updates (`4-1/R9` folded in here): `test_record_file.gd`
    round-trip-carries-every-channel + its derived key-set test; `test_intent_recorder.gd`
    `EXPECTED_INTAKE_SURFACE` + content-order tests; `test_live_reload.gd` THREE edits
    (`SHIPPED_CAPTURE_CHANNELS` 8 -> 9, the literal eight-name array inside the exactly-eight test,
    and that test's name); `test_replay_identity.gd`; `test_record_save_control.gd`;
    `test/replay_drive.gd`; `test/tools/replay_file.gd`. (AC: 2, 10)
- [x] Write the resolver: `summon_*` -> append a unit record; `spell_*` -> named no-op with a
      RETURNED-VALUE-only reason, off the `reject_action` seam (`4-1/R10`); anything else ->
      explicit refusal by RETURNED NAMED VALUE, TWO distinct reasons -- missing-entry honest
      default (directed test) and unknown-prefix refusal (synthetic-fixture test) -- never an
      `Invariant.check` crash, never `reject_action` (`4-1/R3`) (AC: 1, 5, 6)
- [x] Add `PlayerState.units`, the pure-`RefCounted`-collection precedent (`Deck`/`Hand`/
      `DiscardPile`); positionless and type/kind-less per the gate's ruling (`4-1/R12`, totem
      clause) (AC: 4)
- [x] `src/actors/minions/`: author the grey-box unit scene; wire the runner to spawn one actor
      per new unit record and free actors whose unit record is gone (AC: 7, 8)
- [x] Clear `units` in `_apply_debug_reset` ONLY -- `_end_round` stays untouched (`4-1/R5`); add
      the named exception for units to `_apply_debug_reset`'s "NOTHING else" contract comment;
      confirm the runner's actor cleanup fires from the existing `round_started` relay, no new
      EventBus event (AC: 8)
- [x] Extend `player_state.gd`'s `to_snapshot()` with a counts-only board key (attribution
      corrected, `4-1/R7`: NOT `match_state.gd`'s dict); extend the snapshot key-set pin in
      `test_card_observation.gd` (AC: 9)
- [x] Golden re-baseline: measure and separate every cause exactly as every prior multi-cause
      re-baseline in this project has (snapshot-shape cause vs. behavioural cause -- the
      behavioural cause is the golden fixture's `t22` `summon_*` cast, `4-1/R6`), per the Golden
      Prediction below

## Dev Notes

- **Read before touching, `MatchState._resolve_basic_cast`** (`match_state.gd:856-916`): today
  this function spends mana, removes the card from `hand`, appends it to `discard`, arms
  `pending_draw`/`pending_draw_owed`, calls `notify_cards_changed()`, and emits
  `card_cast_resolved(slot, played)` -- `played` is the `StringName` id, nothing else. It NEVER
  reads `CardData.basic_effect` today; the id it emits is opaque to everything downstream. This
  story's resolver call is a new step inside (or immediately after) this function, using the
  SAME `played` id to look up the injected `CardEffect`.
- **Read before touching, `PlayerState`** (`player_state.gd`): three existing pure containers
  (`Deck`, `Hand`, `DiscardPile`) establish the shape a fourth (`units`) should match --
  `RefCounted`, no `SignalQueue` unless a real consumer needs one (none of the three siblings
  carries one; `PlayerState` itself owns the one card-observation signal, `cards_changed`,
  because it spans all three). Do not add a `units_changed` signal speculatively; nothing in this
  story's scope needs the HUD or presentation to observe unit COUNT beyond what a spawn/despawn
  from the runner already implies structurally.
- **Read before touching, `CastEvaluator`** (`cast_evaluator.gd`): the refusal-vocabulary pattern
  (named `const` `StringName`s, `ALLOWED := &""`) is the shape for the spell no-op's stated
  reason and the unknown-effect-id refusal in AC 5/6 -- do not invent a second vocabulary style.
  This resolver is a SIBLING evaluator, not a branch bolted onto `CastEvaluator` or
  `EconomyEvaluator` -- each existing evaluator's own header states it is "THE one place" its
  kind of data is read, and a card-effect read would contradict either if folded in.
- **Runner precedent for the injected map**: `_derive_card_costs()` (`match_runner.gd:362-378`)
  maps the WHOLE card library, not just the ids the current deck composition uses -- "a narrower
  map would have to be re-derived the moment deckbuilding lets a composition change." Mirror this
  for `_derive_card_effects()`.
- **The `EXPECTED_INTAKE_SURFACE`/`SHIPPED_CAPTURE_CHANNELS` guards are DESIGNED to fail on this
  story.** `test_intent_recorder.gd:52` (`test_every_match_state_intake_has_a_capture_channel`)
  scans `MatchState`'s public surface for any method taking a parameter and requires a matching
  `capture_*` method on `IntentRecorder`; `inject_card_effects` will be found and the test will
  fail until `capture_inject_card_effects` exists and both pins (`test_intent_recorder.gd:33`,
  `test_live_reload.gd:36`) are updated DELIBERATELY. This is the guard-mechanism-over-pattern
  discipline (project-context.md) -- update the pin with intent, do not widen a regex to route
  around it. **`4-1/R1` (BLOCKING, accepted at the gate): this capture-method view was incomplete.**
  The full content-channel package is required, not one method plus two pins -- see Tasks/Subtasks
  for the itemized `intent_recorder.gd`/`record_file.gd` surface and the full list of tests that
  MOVE as deliberate pin updates. `record_file.gd` bumps `FORMAT_VERSION` 1 -> 2 and REFUSES v1
  records with a reason; no migration shim is built (records are debug artifacts).
- **`4-1/R3` (BLOCKING, ruled option (a)): the refusal mechanism is returned named values, not a
  crash.** Two distinct reasons, never folded into one: missing-entry (no injected effect for the
  cast id -- honest default, natural fixtures land here) and unknown-prefix (an entry exists but
  its `effect_id` matches neither `summon_` nor `spell_` -- synthetic-only, no natural fixture
  produces it). Injection itself is state-side OPTIONAL (existing `MatchState` fixtures are
  untouched) but record-side MANDATORY for v2 (`missing_match_start_channels()` flags a missing
  effects channel as malformed) -- these are two different obligations on the same channel, do not
  conflate them.
- **`4-1/R5` (BLOCKING, ruled): units clear on reset only, not round-end.** The board persisting
  through the round-over freeze (rather than blinking out the instant a match ends) is the design
  intent, matching how the board already behaves for every other piece of round-crossing state.
  `_apply_debug_reset`'s doc comment needs the named exception added, not silently violated.
- **`4-1/R6` (BLOCKING, ruled): the Golden Prediction's behavioural cause is real, not
  hypothetical.** The gate confirmed the golden fixture injects effects and the card cast at tick
  22 carries a `summon_*` effect id -- `unit_count` measurably moves `0 -> 1` in the hashed
  snapshot from that tick forward, and the resolver therefore sits inside determinism coverage by
  construction, not by luck.
- **`4-1/R11` (non-blocking): Live Smoke's `R-D6` is RE-INVOKED on this gate** -- measured SPENT
  since 3-6, so this is the next player-facing story carrying a live smoke and `R-D6` reattaches.
  The smoke script (below) includes a kill and the `R-D6` acceptance ride-along.
- **`4-1/R12` (BLOCKING, ruled): two named futures for `4-2`'s gate**, recorded here as that gate's
  input rather than decided now -- (a) an INWARD position channel, the runner deriving a fact from
  the unit actor's `global_position` and pushing it into state, on the hero
  `push_contact`/`_gather_contact_facts` precedent; vs. (b) STATE-OWNED floats reaching the hash
  directly on the unit record, a new asymmetry against that precedent. `4-2`'s gate rules between
  them once `TargetingService` exists as a real consumer.
- **The runner's observation-seam count is currently pinned at eight**
  (`test_architecture_invariants.gd`, `test_runner_observation_seams_are_exactly_eight`,
  amended 3-6/R2). If AC 7/8's actor spawn/despawn needs a NEW `connect_*` seam (as opposed to
  deriving spawn/despawn from `card_cast_resolved`'s existing payload plus the injected effect
  map, which the runner already has), that guard needs the same kind of named, reviewed
  amendment 3-6/R2 set as precedent -- not a default assumption either way.
- **FeatureFlags already reserves `minions`/`totems`** (`feature_flags.gd:19-20`, `@export var
  minions: bool = false # E4`), both `false` by default, unconsumed until now. Whether this
  story's summon resolution gates on `flags.minions` (graceful degradation: flag off -> summon
  casts behave like this story doesn't exist) is an implementation choice against the
  project-context HARD RULE on feature flags, not decided here.
- **`data/minions/` and `src/actors/minions/` are currently `.gitkeep`-only** (confirmed by
  listing; matches the D9 pre-write re-verification at the E4 ratification session). This story
  is the first to put real content in `src/actors/minions/`. The Directory Tree also tags
  `data/minions/` `(4-1, PLANNED)`, but nothing in this story's scope needs a data-driven minion
  resource -- there is no AI, priority, or per-type stat to author yet (that is `MinionPriority`,
  4-2's `.tres`, `E4-P/R5`). Read the tag as reserving the DIRECTORY for 4-1's era, not as a
  requirement to put content in it; if the gate finds a genuine need (e.g. a shared grey-box
  visual resource), that is a small addition, not a scope change.

### Project Structure Notes

- `src/state/match_state.gd`: `inject_card_effects()` seat added (the `inject_deck`/
  `inject_card_costs` precedent); `_resolve_basic_cast` (or a new private helper it calls) gains
  the resolver dispatch; `_apply_debug_reset` gains the units-clear step (`4-1/R5`: `_end_round`
  stays untouched).
- `src/state/player_state.gd`: new `units` collection field, constructed empty in `_init`;
  `to_snapshot()` gains the counts-only board key -- attribution corrected (`4-1/R7`): this lives
  on `player_state.gd`'s snapshot, not `match_state.gd`'s match-level dict.
- `src/state/resources/`: no new schema file expected -- `CardEffect` (3-2) already carries the
  one field this story consumes (`effect_id`); a per-unit RECORD type, if the gate decides one is
  needed beyond "an entry exists," is new content here (state-layer, `RefCounted`, no scene ref).
- `src/main/match_runner.gd`: `_derive_card_effects()` (the `_derive_card_costs()` twin), the
  `inject_card_effects` call site beside the existing `inject_card_costs` call
  (`match_runner.gd:203-204`), and the actor spawn/despawn wiring for AC 7/8.
- `src/actors/minions/`: first real content -- the grey-box unit scene (`.tscn` + `.gd`), on the
  `src/actors/hero/` precedent (scene-bound node, no gameplay logic beyond what state feeds it).
- `src/systems/intent_recorder.gd`: `capture_inject_card_effects()`, the `capture_inject_card_costs`
  precedent (`intent_recorder.gd:124`) verbatim, PLUS the full content-channel package ruled at the
  gate (`4-1/R1`): `CHANNEL_EFFECTS` constant, the 3-element `SOUND_CONTENT_ORDER` (effects at the
  END, `4-1/R8`), `_effect_values` storage, a `missing_match_start_channels()` branch,
  `replay_card_effects()`, a `replay_inject_content()` branch (AC 10).
- `src/systems/record_file.gd`: `REQUIRED_KEYS`, `_to_dictionary`, `_from_dictionary`'s
  content-order match, `FORMAT_VERSION` 1 -> 2 with v1 records refused (a reason, not a shim)
  (`4-1/R1`).
- `test/state/test_intent_recorder.gd`, `test/state/test_live_reload.gd`,
  `test/state/test_architecture_invariants.gd`, `test/state/test_card_observation.gd`,
  `test/state/test_determinism.gd`, `test/state/test_record_file.gd`,
  `test/state/test_replay_identity.gd`, `test/state/test_record_save_control.gd`,
  `test/replay_drive.gd`, `test/tools/replay_file.gd`: all touched by this story's guards (the
  `4-1/R1` package widens this list from the pre-gate two-pin view); the primary suites the dev
  pass extends.

### Project Context Rules

- **Card effects reach the state layer by one-shot injection, never a direct load.**
  `src/state/` never names `CARDS_DIR`/`data/cards`; the runner is the only reader of
  `CardDatabase`. [Source: decision-log.md `E4-P/R4`; test_state_layer_never_names_card_data]
- **Any `.tres` injected into the state layer joins golden discipline, treated as code.**
  [Source: decision-log.md `E4-P/R6`; `3-4/R6`]
- **The evaluator COMPUTES, the caller APPLIES (D6).** The resolver returns a verdict/record; any
  mutation (appending to `units`, spending mana, discarding) happens inside `MatchState.advance()`'s
  ordered dispatch, not inside the resolver itself. [Source: docs/game-architecture.md D6;
  economy_evaluator.gd, cast_evaluator.gd headers]
- **CONSTRAINT C: read `balance`/injected values inline, never cache.**
  [Source: project-context.md]
- **Guard mechanism over guard pattern**: when a machine-checked scan (the intake-surface guard,
  the observation-seam count) is deliberately amended by this story, do so as a named, reviewed
  exception, matching the `3-6/R2` precedent, never a widened regex.
  [Source: project-context.md "Guard mechanism over guard pattern"]
- **Signals over polling; direct subscription is the default.**
  [Source: project-context.md]

### References

- [Source: decision-log.md Session 2026-08-08 -- 4-1 readiness gate, `4-1/R1`-`4-1/R12` + the
  totem clause]
- [Source: decision-log.md Session 2026-08-07 -- E4 ratification, `E4-P/R1`, `E4-P/R2`,
  `E4-P/R4`, `E4-P/R6`, `E4-P/R7`, `E4-P/R9`, `E4-P/R10`, `E4-P/R11`]
- [Source: docs/game-architecture.md D9 ("E4-E6 Seams"); Directory Tree
  (`src/actors/minions/ (4-1)`, `data/minions/(4-1, PLANNED)`); Schema vs Loader]
- [Source: src/state/resources/card_effect.gd; src/state/player_state.gd;
  src/state/match_state.gd:319-344, 856-916, 1225-1274; src/state/hero_state.gd:1-9]
- [Source: src/state/economy/cast_evaluator.gd; src/state/economy/economy_evaluator.gd]
- [Source: src/main/match_runner.gd:334-382, 643-682]
- [Source: src/systems/intent_recorder.gd:112-138]
- [Source: data/cards/*.tres -- nine fixture cards, exactly six `summon_*` and three `spell_*`
  effect ids, confirmed by direct read]
- [Source: test/state/test_intent_recorder.gd:33-52; test/state/test_live_reload.gd:36,95-108;
  test/state/test_architecture_invariants.gd (`test_runner_observation_seams_are_exactly_eight`);
  test/state/test_card_observation.gd:221-227; test/state/test_determinism.gd:304]

## Golden Prediction

**MOVES.** At minimum two separately measured causes, each to be isolated the way every prior
multi-cause re-baseline in this project has been (1-5, 1-8, 1-9, 3-3, 3-4, 3-5a, 3-5b, 4-0):

1. **Snapshot-shape cause.** The new counts-only board key (AC 9) enters `to_snapshot()` -- this
   alone moves the golden at an early tick, before any summon is cast, the same way 3-5a's
   `discard_size` and 4-0's `pending_draw_owed` reshape each moved it by themselves at an
   all-zero/no-op value.
2. **Behavioural cause -- CONFIRMED at the gate (`4-1/R6`), not merely predicted.** The golden
   fixture DOES inject effects, and the card cast at tick 22 carries a `summon_*` effect id: the
   board key's value measurably moves `unit_count` `0 -> 1` in the hashed snapshot from that tick
   forward. This is a real, measured cause, and the resolver sits inside determinism coverage by
   construction as a result.

A third possible cause -- `rng_state`, if the resolver's unit-record creation consumes no RNG (it
should not; nothing about which unit appears is random in this story) -- is a predicted non-mover,
to be confirmed rather than assumed, on the `3-5b`/`4-0` precedent of explicitly testing predicted
non-movers.

No baseline hash is recorded here as a target, per the standing rule (3-3 gate) that a Golden
Prediction baseline is re-derived from `test_determinism.gd`'s `GOLDEN` constant at gate time,
never copied forward. The BEFORE value for this authoring pass is recorded in the Dev Agent Record
below, exactly as `4-B1`'s authoring pass recorded its own BEFORE value.

## Live Smoke

**REQUIRED**, on the Tier A default and this story's own player-facing claim: a card cast now puts
something visible and persistent on the board, which is exactly the kind of claim this project
judges live rather than headless (the `3-0a`/`3-6`/`4-0` precedent). At minimum: cast a `summon_*`
card and confirm a grey-box unit appears and remains after the cast resolves; cast a `spell_*`
card and confirm nothing appears on the board and the card still resolves (mana spent, discarded,
replacement owed) exactly as it does today; end a round (or trigger the debug reset) and confirm
the board clears. **`R-D6` is RE-INVOKED on this gate (`4-1/R11`)** -- measured SPENT since 3-6, so
this is the next player-facing story carrying a live smoke and the two-human kill-acceptance
ritual reattaches here. The smoke script includes a kill and the `R-D6` acceptance ride-along
alongside the summon/spell/clear checks above.

**Result (OPERATOR-REPORTED): PASS, 2026-08-09**, shipped default config, zero `.tscn` edits.
Summons appear on `summon_*` casts and persist; nothing appears on non-summon casts and the card
still resolves normally; units SURVIVE the kill and the round-over freeze (`4-1/R5` confirmed
live); a reset clears both boards; fps stable. `R-D6` was re-invoked at this gate (`4-1/R11`) and is
now CONSUMED again -- the kill was confirmed live against a killable human slot.

## Review Findings

**(OPERATOR-REPORTED)** `gds-code-review`, closed. Verdict **PASS**, zero patches.

- **Blind Hunter**: completed. 12 findings raised, 11 refuted on verification, 1 surviving LOW
  non-blocking finding -- the v1-refusal test rewrites the record version to `FORMAT_VERSION + 41`
  rather than literally `1`; it exercises the same code path (`version != FORMAT_VERSION`) and was
  deliberately NOT patched, since verification is not recursive. Recorded as a review note, not a
  defect.
- **Edge Case Hunter**: STALLED (600s watchdog, no layer-completion line). Operator ruled: accepted
  without retry. This is `PROC/R6`'s stall counter's FOURTH consecutive review run carrying one
  failed layer -- counter now at 1, flagged as input to the next process retrospective.
- **Inline acceptance-auditor checklist**: 10/10 PASS, including the evidence audit of the Dev
  Agent Record.
- **Targeted check 1 (feature-flag gating)**: the review verified `data/feature_flags.tres`
  shipping `minions = true` and the resolver gating on it live; operator ruling: ACCEPTED.

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context) -- dev pass, 2026-08-09.

### Debug Log References

**Golden Prediction BEFORE values, captured at authoring time (this run), for the dev pass to
compare against AFTER:**
- Golden hash: `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`
  (`test/state/test_determinism.gd:304`)
- Snapshot key set: `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
  "pending_draw", "pending_draw_owed", "stamina"]` (`test/state/test_card_observation.gd:226-227`)
- Recorder intake surface (`test/state/test_intent_recorder.gd:33-35`): `["_init", "advance",
  "apply_balance", "inject_card_costs", "inject_deck", "inject_feature_flags", "push_contact",
  "set_camera_basis"]`, 8 capture channels (`test/state/test_live_reload.gd:36`)

### Completion Notes List

#### Golden re-baseline -- ONE re-baseline, TWO causes, MEASURED and named separately

| Step | What was in place | Hash | Cause |
|------|-------------------|------|-------|
| BEFORE | pre-story (the authoring-time record above) | `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c` | -- |
| Cause 1 | `unit_count` key present, fixture injects NO effects | `542a05c042501e5ba45dfd94415f7fe38fabe7779e2db0bfeb0c70af427dcbda` | **SNAPSHOT SHAPE** (AC 9). Isolated BY CONSTRUCTION, not by a staged mutation: the key shipped before `_golden_effects()` existed, so the board was structurally pinned at 0 and the key entered the hash at an all-zero, no-op value -- the 3-5a `discard_size` / 4-0 `pending_draw_owed` pattern. |
| Cause 2 | `+ _golden_effects()` and `_golden_flags().minions = true` | `78bd2b97a68d1d56def6f851ce867219f383b811715f7aa5a9bcd639c6b0b5e5` | **BEHAVIOUR -- the t22 summon** (`4-1/R6`, CONFIRMED at the gate). ONE cause, not two: either half alone leaves the resolver on a non-summoning outcome and `unit_count` at 0 for the whole run. Cast at `CAST_TICK` 22, hash taken at t24, so the moved value is LIVE at hash time. **This is the new `GOLDEN`.** |
| Cause 3 | -- | non-mover | **`rng_state`** -- predicted a non-mover, CONFIRMED rather than assumed (`test_the_summon_consumes_no_rng`), measured against the tightest available pair: same fixture, same cast, effects injected vs. not, with `unit_count` asserted to DIFFER across the pair so the rng comparison cannot be vacuous. |

**Not a cause, and provably so:** `_golden_effects()` builds its map in-test over `_golden_deck`'s
opaque ids and `_golden_flags()` constructs its own `FeatureFlags`, so re-authoring a real card's
`effect_id` -- or flipping the authored `minions` flag -- cannot re-baseline this hash. Standing
`BC/R3` isolation is intact. AC 3's narrowing is a RULING about review burden, not a measured
coupling (`4-1/R4`), and this pass claims no measurable golden move from a `.tres` edit.

#### Mutation table -- provenance MEASURED (11 mutations, each run against the affected file only)

Every mutation was applied by python byte-replace, run, then RESTORED from an out-of-repo scratchpad
copy taken BEFORE any mutation (never `git checkout --`). Post-restore `sha256sum -c` verified all
seven mutated sources bit-identical to their pre-mutation state.

| # | File | Mutation | Result | Caught by (first-named) |
|---|------|----------|--------|--------------------------|
| M1 | `card_effect_resolver.gd` | summon branch always returns `REASON_MINIONS_FLAG_CLOSED` | **11 failed** | `test_a_summon_cast_appends_exactly_one_unit_record_to_the_caster`, `test_state_matches_golden`, `test_dropping_any_single_channel_diverges_the_replay` |
| M2 | `card_effect_resolver.gd` | spell branch folded into unknown-prefix | **1 failed** | `test_a_spell_effect_id_returns_the_named_no_op_reason` |
| M3 | `card_effect_resolver.gd` | missing-entry folded into unknown-prefix (the two `4-1/R3` reasons collapsed) | **1 failed** | `test_a_cast_with_no_injected_effect_entry_returns_the_missing_entry_reason` |
| M4 | `card_effect_resolver.gd` | flag gate removed (`minions` hardcoded ON) | **2 failed** | `test_the_minion_layer_off_degrades_to_a_cast_with_no_board_effect`, `test_no_injected_flags_reads_as_closed` |
| M5 | `match_state.gd` | reset no longer clears the board | **1 failed** | `test_the_debug_reset_clears_the_board` |
| M6 | `match_state.gd` | board clear migrated INTO `_end_round` (`4-1/R5` violated) | **1 failed** | `test_end_round_never_touches_the_board` |
| M7 | `player_state.gd` | snapshot key hardcoded to 0 | **4 failed** | `test_the_board_snapshot_key_is_a_plain_count`, `test_state_matches_golden`, `test_the_summon_consumes_no_rng` |
| M8 | `intent_recorder.gd` | `replay_card_effects()` returns an empty map (channel silently dropped) | **6 failed** | `test_content_channels_carry_..._and_their_order`, `test_a_driven_run_replays_from_the_record_alone_to_a_bit_identical_hash` |
| M9 | `record_file.gd` | v2 writer omits the `effects` key | **7 failed** | `test_the_required_key_set_is_exactly_what_a_saved_record_carries`, `test_the_round_trip_carries_every_channel_verbatim` |
| M10 | `match_runner.gd` | runner never spawns an actor | **integration FAIL** | `test_summon_actor_live` (`board=1 actors=0`) |
| M11 | `match_runner.gd` | runner never frees actors on reset | **integration FAIL** | `test_summon_actor_live` (`cleared_board=0/0 cleared_actors=1`) |

**Declared NOT mutation-proven, honestly:** the two `inject_card_effects` seam guards in the FIRING
sense. `Invariant.check` routes through `assert()`, which PRINTS AND CONTINUES at exit 0
(`3-0c/R15`), and `run_all.sh` greps for `INVARIANT VIOLATED` -- so a deliberately triggered one
would fail the suite for the wrong reason. Their PRESENCE at the seam is proven instead
(`test_effect_injection_seam_keeps_both_guards`), the `test_cost_injection_seam_keeps_both_guards`
mechanism and rationale verbatim.

**Declared NOT naturally reachable, honestly:** AC 6(ii)'s unknown-prefix branch. The nine authored
ids are exactly six `summon_*` and three `spell_*` -- re-confirmed BY MACHINE this pass
(`test_every_authored_effect_id_carries_a_prefix_the_resolver_recognises` asserts the 6/3 split) --
so this branch is proven with SYNTHETIC map entries only and is never claimed to be live-reachable.

#### Implementation decisions the story left to the dev pass

1. **Summon resolution IS gated on `FeatureFlags.minions`, and the authored
   `data/feature_flags.tres` turns that flag ON.** Dev Notes left this "an implementation choice
   against the project-context HARD RULE, not decided here" -- and the HARD RULE decides it:
   "NEVER hardcode a gameplay layer on. Any of {..., minions, totems, ...} must check the injected
   FeatureFlags resource and degrade gracefully when off." `minions` is one of the seven named
   layers. Degrading gracefully means the cast resolves exactly as it does today (mana spent, card
   discarded, replacement owed) with no unit on the board, under its OWN named reason
   (`REASON_MINIONS_FLAG_CLOSED`) rather than reusing the spell one -- "the layer is switched off"
   and "this effect has no owner yet" are different facts about the match. Both matrix directions
   are tested. Flipping the authored flag is the checkbox the rule exists to provide, and it is a
   `.tres` edit, not a code edit. **This is the one dev-pass decision with player-facing
   consequence and is flagged here for operator review.**
2. **`UnitBoard` holds a COUNT.** Three ruled clauses empty the record -- positionless
   (`4-1/R12`), type/kind-less (the ratified totem clause), and no AI/HP/targeting (Deferred) --
   so what remains of "a unit record" is EXISTENCE, in cast order, and the honest representation of
   N contentless records appended in order is N. An array of per-unit ids or structs would be
   reserved vocabulary authored ahead of its consumer, which is precisely the `card_effect.gd`
   anti-precedent `E4-P/R2` names as the one "to avoid repeating without cause". `4-2`'s gate adds
   content against `TargetingService`, a consumer that will actually read it.
3. **No new observation seam; the family stays at EIGHT.** The runner reads the board COUNT off
   state right after `advance()` (the step-3b `debug_window_ticks_remaining()` poll's seat and
   shape -- no signal, no state handle, no `connect_*`), so
   `test_runner_observation_seams_are_exactly_eight` needed no `3-6/R2`-style amendment. Despawn
   rides the EXISTING `round_started` relay with no new EventBus event, which is AC 8's own
   instruction. Reading the BOARD rather than the cast is also what makes spawn identical live vs.
   replay BY CONSTRUCTION (AC 10) -- there is no second spawn path to keep in agreement with the
   first.
4. **Actor placement is runner-chosen** (`UNIT_ROW_X` / `UNIT_ROW_SPACING` / `UNIT_ROW_Z_START`): a
   row behind each hero's spawn, legibility only, and nothing reads it. Position stays actor-owned
   per `4-1/R12`; 4-2 replaces this with real placement.

#### Guards that MOVED, each as a deliberate, named pin update

- `test_intent_recorder.gd`: `EXPECTED_INTAKE_SURFACE` gains `inject_card_effects` (MatchState's
  ninth intake); the malformed-channel map goes five -> six; the content-order test RENAMED to
  `test_content_channels_carry_the_composition_the_costs_the_effects_and_their_order`, old name
  recorded in place.
- `test_live_reload.gd` (`4-1/R9`, all three edits): `SHIPPED_CAPTURE_CHANNELS` 8 -> 9, the literal
  eight-name channel array, and the test RENAMED to
  `test_the_recorder_still_ships_exactly_nine_capture_channels`, old name recorded in place.
- `test_card_observation.gd`, `test_draw_delay_and_reshuffle.gd`: the per-player snapshot key set
  gains `unit_count` (nine keys -> ten).
- `test_replay_identity.gd`: `_card_effects` classified INJECTED; `player_state.units` and
  `unit_board._count` classified HASHED -- **not** a fourth unhashed cross-tick exclusion, because
  unlike its three container siblings a `UnitBoard` has no contents to exclude, so
  `UNHASHED_CROSS_TICK_MEMBERS` stays at THREE; `"effects"` joins the drop-channel falling proof.
- `test_deck_and_hand.gd`: the `CardEffect` fence NARROWED to `pitch_effect` and renamed
  `test_no_pitch_effect_consumer_ships`. This story is the "first story to resolve effect CONTENT"
  that the fence's own docstring named as its retirer. Narrowed rather than deleted, on the 3-5a
  precedent in that same file: `pitch_effect` is still Mode (4), E6's, authored null on all nine
  cards and read by nothing, so the fence keeps a real subject.

#### Deviations from the skill's procedure and standing rules -- reported, not silently adapted

1. **The full suite ran FOUR times, not the two `PROC/R1` allows.** Run 1 (open) PASS. Run 2
   (close) **RED**: three integration tests build `IntentRecorder` records by hand and were NOT in
   the story's enumerated `4-1/R1` moving-tests list (`test_replay_contacts.gd`,
   `test_replay_entry_is_inert.gd`, `test_replay_verifier_tool.gd`); all three tripped the new
   malformed-record guard. Run 3, after fixing them, PASS -- a green close cannot be claimed
   without re-running. Run 4 was **avoidable waste**: I re-ran `run_all.sh` to recover the
   state-harness count line, which the state harness alone would have given me.
2. **Run 1's assertion count was lost** to a `tail -40` that clipped the state-harness summary
   line, so this record carries no open/close assertion-count delta -- only the close figures and
   a mid-pass pre-story baseline.
3. **Mutation proofs ran the whole state harness, not a single file.** `run_state_tests.gd` has no
   single-file mode and none was added (new tooling was not in scope); the affected file's result
   lines were read out of a harness run. No mutation consumed a `run_all.sh` full-suite run.
4. **One Edit-tool miss** (`match_state.gd`, a wrapped-comment anchor). Switched to python
   byte-replace immediately and used it for every subsequent source edit, per `PROC/R3`.

#### Suite, before and after

- **Open (run 1):** ALL TESTS PASSED, exit 0.
- **Close (run 3):** ALL TESTS PASSED -- **399 state tests / 0 failed / 2517 assertions**, plus
  **24 integration tests**, all PASS. (Pre-story baseline, measured mid-pass: 375 state tests /
  2028 assertions. This story adds 24 state tests and 1 integration test.)

#### New `class_name` editor scan (`3-0c/R15` family, ruled `3-0c/R13`)

Three new `class_name`s ship: `UnitBoard`, `CardEffectResolver`, `UnitActor`. Editor scan RUN THIS
PASS (`godot --headless --editor --quit --path .`); all three registered.
**Collateral check clean:** `project.godot` SHA256
`8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, **before == after**, and the
per-diff shows the only collateral is the three expected `.uid` files.

#### Not done in this pass, by instruction

- **NO COMMITS.** The close-out chain owns commits; the working tree is left dirty by design.
- **The `on_complete` board write is uncommitted working-tree state** (`CFG/R5`).
- **The Live Smoke is NOT discharged** -- it is the operator's, and `R-D6` is RE-INVOKED on this
  story (`4-1/R11`). The smoke script in the story stands as written: cast a `summon_*` and confirm
  a grey box appears and REMAINS; cast a `spell_*` and confirm nothing appears while the card still
  resolves (mana spent, discarded, replacement owed); reset and confirm the board clears; plus the
  kill and the `R-D6` two-human acceptance ride-along.

### File List

**New**
- `src/state/unit_board.gd` (+ `.uid`) -- `UnitBoard`, the per-player board container
- `src/state/economy/card_effect_resolver.gd` (+ `.uid`) -- `CardEffectResolver`, the D6 sibling evaluator
- `src/actors/minions/unit_actor.gd` (+ `.uid`) -- `UnitActor`, the grey-box unit
- `src/actors/minions/unit_actor.tscn` -- the grey-box scene
- `test/state/test_card_effect_resolution.gd` -- AC 1/2/4/5/6/8/9 + the feature-flag matrix
- `test/integration/test_summon_actor_live.gd` -- AC 7/8 driven through the real runner

**Modified**
- `src/state/match_state.gd` -- `_card_effects`, `inject_card_effects()`, the resolver dispatch in `_resolve_basic_cast`, the reset clear in `_reset_player`, the named exception on `_apply_debug_reset`'s contract comment
- `src/state/player_state.gd` -- the `units` collection, constructed empty; the `unit_count` snapshot key
- `src/main/match_runner.gd` -- `_derive_card_effects()`, the capture+inject call site, the spawn step (3c), `_spawn_missing_unit_actors()`, `_free_unit_actors()` off `_relay_round_started`
- `src/systems/intent_recorder.gd` -- `CHANNEL_EFFECTS`, the 3-element `SOUND_CONTENT_ORDER`, `_effect_values`, `capture_inject_card_effects()`, the `missing_match_start_channels()` branch, `replay_card_effects()`, the `replay_inject_content()` branch
- `src/systems/record_file.gd` -- `FORMAT_VERSION` 1 -> 2 (v1 refused with a reason, no shim), the `effects` required key, `_to_dictionary`/`_from_dictionary`, `_card_effects()`
- `data/feature_flags.tres` -- `minions = true`
- `test/state/test_determinism.gd` -- `_golden_effects()`, `_golden_flags().minions`, `_make_match_without_effects()`, `test_the_summon_consumes_no_rng`, the re-baseline record, the new `GOLDEN`
- `test/state/test_card_authoring.gd` -- the AC 3 authored-prefix test
- `test/state/test_card_observation.gd`, `test/state/test_draw_delay_and_reshuffle.gd` -- the snapshot key-set pins
- `test/state/test_intent_recorder.gd`, `test/state/test_live_reload.gd` -- the channel/intake pins and renames
- `test/state/test_record_file.gd`, `test/state/test_replay_identity.gd` -- fixtures, round-trip channel assertions, member classification, the effects drop-channel proof
- `test/state/test_deck_and_hand.gd` -- the `CardEffect` fence narrowed to `pitch_effect` and renamed
- `test/integration/test_replay_contacts.gd`, `test/integration/test_replay_entry_is_inert.gd`, `test/integration/test_replay_verifier_tool.gd` -- hand-built records capture the third content channel
- `test/replay_drive.gd` -- the unsound-order message names both totality checks
- `test/tools/replay_file.gd` -- `effects=` joins the operator summary line

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-08 | 0.1 | Story authored against the E4 ratification (`E4-P/R1`-`E4-P/R11`). Nine ACs covering the resolver, the injected-effects seam, golden discipline, `PlayerState.units`, the `summon_*`/`spell_*`/unknown-id branches, the grey-box actor, round-lifecycle clearing, and counts-only snapshotting. Position ownership left as an Open Question for the gate (`E4-P/R7`). Status `authored`, awaiting operator review. | Claude Sonnet 5 |
| 2026-08-08 | 0.2 | Readiness-gate ruling pass (NOT READY on first read, 7 blocking findings with `R1`/`R2`/`R3` counted as one work package, below the `E4-P/R2` break line of 8, no split). AC 3 restated to claim golden discipline BY RULING only, not a measurable move, plus an authoring prefix-recognition test (`4-1/R4`). AC 4 amended positionless + type/kind-less (`4-1/R12` + totem clause). AC 5 amended: the spell no-op's reason is a returned value only, off `reject_action` (`4-1/R10`). AC 6 replaced: refusal by two named returned values, never a crash, never `reject_action` (`4-1/R3`). AC 8 replaced: units clear on `_apply_debug_reset` only, `_end_round` untouched (`4-1/R5`). AC 9 amended: snapshot attribution corrected to `player_state.gd` (`4-1/R7`), wording scoped to this story's own key, not a standing bound (`4-1/R12`). New AC 10 added: replay parity via `replay_inject_content()` (`4-1/R2`). Open Question section resolved with the `4-1/R12` ruling and its two named futures for `4-2`. Tasks/Subtasks rewritten: the IntentRecorder task replaced with the full content-channel package (`4-1/R1`, folding in `4-1/R9`'s `test_live_reload.gd` naming discipline); the resolver task carries the two-reason refusal shape; the units-clear task narrowed to the reset path; the snapshot task's file attribution corrected; the golden-re-baseline task names the `t22` behavioural cause. Dev Notes appended with `4-1/R1`, `R3`, `R5`, `R6`, `R11`, `R12` detail. Project Structure Notes corrected (`to_snapshot()` on `player_state.gd`, not `match_state.gd`; `record_file.gd` added). Golden Prediction's behavioural cause upgraded from predicted to CONFIRMED, naming the `t22` fixture cast (`4-1/R6`). Live Smoke amended: `R-D6` RE-INVOKED, measured SPENT since 3-6 (`4-1/R11`). Decision-log gains Session 2026-08-08 -- 4-1 readiness gate, recording `4-1/R1`-`4-1/R12` and the totem clause. Status flipped `authored` -> `ready-for-dev`; `sprint-status.yaml` promoted alongside (`CFG/R4`). | Claude Sonnet 5 |
| 2026-08-09 | 1.0 | Dev pass (Claude Opus 5, 1M context). All nine tasks delivered; AC 1-10 implemented and covered. NEW: `UnitBoard` (a COUNT -- positionless, type/kind-less, no content to hold), `CardEffectResolver` (D6 sibling, four named outcomes), `UnitActor` grey-box scene, plus `test_card_effect_resolution.gd` and `test_summon_actor_live.gd`. `inject_card_effects()` seat on the `inject_card_costs` shape; runner `_derive_card_effects()`; the full `4-1/R1` content-channel package (`CHANNEL_EFFECTS`, 3-element `SOUND_CONTENT_ORDER`, `_effect_values`, `capture_inject_card_effects`, malformed-channel branch, `replay_card_effects`, `replay_inject_content` branch) with `FORMAT_VERSION` 1 -> 2 and v1 REFUSED, no shim. Golden re-baselined ONCE, `312522d8` -> `78bd2b97`, with both causes measured separately (snapshot-shape `542a05c0`; the t22 summon) and `rng_state` confirmed a non-mover. 11 mutation proofs, all restored from an out-of-repo copy and SHA-verified. IMPLEMENTATION DECISION flagged for review: summon resolution is gated on `FeatureFlags.minions` per the project-context HARD RULE, and `data/feature_flags.tres` turns the flag ON. Suite green: 399 state / 2517 assertions + 24 integration. Editor scan run for the three new `class_name`s, `project.godot` unchanged. NO COMMITS (close-out chain owns them); live smoke + `R-D6` remain the operator's. Status `ready-for-dev` -> `review`. | Claude Opus 5 |
| 2026-08-09 | 1.1 | Code review (`gds-code-review`, OPERATOR-REPORTED). Verdict PASS, zero patches. Blind Hunter: 12 findings raised, 11 refuted, 1 surviving LOW non-blocking (v1-refusal test uses `FORMAT_VERSION + 41` rather than literal `1`, same code path, not patched). Edge Case Hunter STALLED (600s watchdog); operator accepted without retry (`PROC/R6` stall counter now 1, fourth consecutive run with a failed layer). Inline acceptance-auditor checklist 10/10 PASS. Feature-flag gating on `FeatureFlags.minions` with the flag ON reviewed and ACCEPTED. | Claude Opus 4.8 |
| 2026-08-09 | 1.2 | Live smoke (operator, OPERATOR-REPORTED). PASS on the shipped default config, zero `.tscn` edits: summons appear and persist on `summon_*` casts; nothing appears on `spell_*` casts and the card still resolves normally; units survive the kill and the round-over freeze (`4-1/R5` confirmed live); reset clears both boards; fps stable. `R-D6` re-invoked (`4-1/R11`) and CONSUMED again on a live kill against a killable human slot. | Claude Opus 4.8 |
