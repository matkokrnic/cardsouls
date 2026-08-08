---
baseline_commit: dd61f9c69e052b2012668d6ef3a08ded46c8d7c4
---

# Story 4.1: Basic summon resolution

Status: authored

> **Scope note.** Position 3 of the E4 order (`E4-P/R1`, decision-log Session 2026-08-07 -- E4
> ratification). Tier A (`E4-P/R9`: touches `src/state/`, the golden, and determinism) -- full
> ritual applies: readiness gate with numbered rulings -> dev pass -> code review -> live smoke
> where `R-D6` attaches -> close-out. This authoring pass does NOT run that gate. `Status:` and
> the sprint-status entry come out of this run as `authored`, not `ready-for-dev`, per
> `_bmad/custom/gds-create-story.toml`'s `on_complete` -- awaiting operator review before
> promotion.
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
> **This story does not decide where a unit's position lives.** `E4-P/R7` places an explicit
> obligation on this story's gate: ask the question, with the 1-8/1-9 hero-position precedent in
> hand, rather than default to whichever seems convenient. See the Open Question below and Dev
> Notes -- the readiness gate rules on it, this authoring pass does not.

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
3. **The injected effect map joins golden discipline, treated as code (`E4-P/R6`).** The same
   narrowing of `BC/R3` that `3-4/R6` applied to `data/economy/` and this story's own AC 2 applies
   to `data/cards/`'s cost half: a change to any card's `effect_id` is now a determinism-relevant
   edit, same as a change to its `mana_cost` already is.
4. **A `summon_*` effect id creates ONE unit record on the casting player's board/units
   collection.** `PlayerState` gains the collection D9 reserves (name: `units`, the architecture
   doc's own term) -- a pure, `RefCounted`-only structure on the `Deck`/`Hand`/`DiscardPile`
   precedent, holding no scene reference, no position, and no per-unit behaviour (AI/targeting/
   combat are 4-2/4-3, explicitly out of scope below). One record per resolved `summon_*` cast,
   appended in cast order.
5. **A `spell_*` effect id is a NAMED no-op, never a rejection, per `E4-P/R10`.** The cast has
   already passed `CastEvaluator`; mana is spent and the card discarded exactly as it is today.
   The resolver's spell branch performs no board mutation and reports an explicit, stated reason
   (a `StringName` in the `CastEvaluator` refusal-vocabulary style, e.g. `&"spell_not_yet_resolved"`)
   rather than silently returning. `bramble_snare`, `frost_dart`, and `ember_lash` (the three
   `spell_*` fixture cards) exercise this path; none of E4's committed obligations (minions,
   pooling, targeting, totems) is spells, and excluding spell cards from the deal is refused by
   the same ruling -- it would move the golden for no feature reason and drop three of nine cards
   from every test.
6. **Any effect id that is neither `summon_*` nor `spell_*` is explicitly refused, never silently
   swallowed.** No fixture card produces this case today (the nine authored ids are exactly six
   `summon_*` and three `spell_*` -- confirmed by reading every `data/cards/*.tres`), so this
   branch needs its own synthetic non-vacuity proof, the `CastEvaluator.refusal_reason`'s
   null-condition branch precedent (`cast_evaluator.gd:49-52`, "kept as a total function's honest
   default... declared NOT mutation-proven for that reason").
7. **A visible grey-box unit actor appears for each resolved `summon_*` cast, owned by the
   runner.** `src/actors/minions/` (named `(4-1)` in the architecture Directory Tree,
   `game-architecture.md:615`) gains a grey-box scene -- a placeholder mesh sufficient for
   legibility only (GDD-authority visual fidelity is explicitly out of scope everywhere in this
   project; grey-box is the standing bar). The runner spawns one actor per unit record it learns
   about, on the `HeroActor`/telegraph-controller precedent: `src/state/` never holds the scene
   reference, `src/actors/` never holds gameplay logic beyond what the state layer feeds it.
8. **Units clear at round end.** Both the real round-end path (`MatchState._end_round`,
   `match_state.gd:1244`) and the debug reset path (`_apply_debug_reset`, `match_state.gd:1257`)
   leave a player's `units` collection empty afterward, and the runner frees the matching actors
   in response -- no board carries stale units into a fresh round, on the existing per-round
   lifecycle (`round_ended`/`round_started`) rather than a new one.
9. **Snapshot integration stays counts-only, the `deck_size`/`hand_size`/`discard_size` precedent
   verbatim.** Whatever key(s) `to_snapshot()` gains for the board (e.g. a `unit_count`) carries
   no unit identity, no effect id, and no position -- consistent with the existing rule that a
   `StringName` or object reference reaching the hash is the failure mode every card-container key
   in this codebase exists to avoid (3-3 AC 5, 3-5a AC 6, 3-0c AC 11).

## Deferred / Out of scope

- **Minion AI and targeting** (4-2) -- a spawned unit does nothing after it appears; no
  `TargetingService`, no movement, no `MinionPriority` `.tres` consumption.
- **Minion combat** (4-3) -- no HP, no damage, no death for a unit this story; "unit record" here
  means only "exists and is counted," nothing more.
- **Totems** (4-4) -- three of the six `summon_*` fixture ids are actually totem effects
  (`summon_combat_totem`, `summon_mana_accelerator`, `summon_stamina_accelerator`, all on the
  wardstone cards). This story treats every `summon_*` id identically -- one generic grey-box unit
  record, no totem-specific behaviour, no totem/minion type distinction. 4-4 differentiates
  totems from minions; this story does not pre-decide that shape.
- **Object pooling / performance** (4-5) -- units are plain instantiated/freed nodes this story;
  no pool. `4-5`'s tier is assigned at this story's close-out (`E4-P/R8`), genuinely undecided
  until the unit-ownership ruling below exists.
- **Real spell resolution** -- acquires an owner at the E4 close-out at the latest (`E4-P/R10`).
  This story's spell branch is a named no-op, not a partial implementation of any spell's actual
  effect.

## Open Question for the readiness gate (NOT decided here)

**Where does a unit's position live?** The measured hero precedent: `hero_state.gd:5` states
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
not exist until 4-2. **This authoring pass presents the question with the precedent in hand and
does not answer it.**

## Tasks / Subtasks

- [ ] Add `MatchState.inject_card_effects()`, the `inject_card_costs` seam shape verbatim,
      `Invariant.check`-guarded for totality over the injected deck composition (AC: 2, 3)
- [ ] `_derive_card_effects()` in the runner, the `_derive_card_costs()` precedent verbatim
      (`match_runner.gd:362-378`) -- walk `CardDatabase.sorted_ids()`, map id -> `basic_effect`,
      skip a card with no authored effect (AC: 2)
- [ ] Add `capture_inject_card_effects()` to `IntentRecorder`; update
      `EXPECTED_INTAKE_SURFACE` (`test/state/test_intent_recorder.gd:33`) and
      `SHIPPED_CAPTURE_CHANNELS` (`test/state/test_live_reload.gd:36`) as a NAMED, deliberate
      pin update -- both guards are machine-checked source scans and are meant to fail loudly
      here (AC: 2)
- [ ] Write the resolver: `summon_*` -> append a unit record; `spell_*` -> named no-op with a
      stated reason; anything else -> explicit refusal, proven by a synthetic fixture id (AC: 1,
      4, 5, 6)
- [ ] Add `PlayerState.units`, the pure-`RefCounted`-collection precedent (`Deck`/`Hand`/
      `DiscardPile`); resolve the Open Question's shape as part of this task, per the gate's
      ruling (AC: 4)
- [ ] `src/actors/minions/`: author the grey-box unit scene; wire the runner to spawn one actor
      per new unit record and free actors whose unit record is gone (AC: 7, 8)
- [ ] Clear `units` in both `_end_round` and `_apply_debug_reset`; confirm the runner's actor
      cleanup fires from the existing `round_ended`/`round_started` relay, no new EventBus event
      (AC: 8)
- [ ] Extend `to_snapshot()` with a counts-only board key; extend the snapshot key-set pin in
      `test_card_observation.gd` (AC: 9)
- [ ] Golden re-baseline: measure and separate every cause exactly as every prior multi-cause
      re-baseline in this project has (snapshot-shape cause vs. behavioural cause), per the
      Golden Prediction below

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
  around it.
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
  the resolver dispatch; `_end_round` and `_apply_debug_reset` gain the units-clear step;
  `to_snapshot()` gains a counts-only board key.
- `src/state/player_state.gd`: new `units` collection field, constructed empty in `_init`.
- `src/state/resources/`: no new schema file expected -- `CardEffect` (3-2) already carries the
  one field this story consumes (`effect_id`); a per-unit RECORD type, if the gate decides one is
  needed beyond "an entry exists," is new content here (state-layer, `RefCounted`, no scene ref).
- `src/main/match_runner.gd`: `_derive_card_effects()` (the `_derive_card_costs()` twin), the
  `inject_card_effects` call site beside the existing `inject_card_costs` call
  (`match_runner.gd:203-204`), and the actor spawn/despawn wiring for AC 7/8.
- `src/actors/minions/`: first real content -- the grey-box unit scene (`.tscn` + `.gd`), on the
  `src/actors/hero/` precedent (scene-bound node, no gameplay logic beyond what state feeds it).
- `src/systems/intent_recorder.gd`: `capture_inject_card_effects()`, the `capture_inject_card_costs`
  precedent (`intent_recorder.gd:124`) verbatim.
- `test/state/test_intent_recorder.gd`, `test/state/test_live_reload.gd`,
  `test/state/test_architecture_invariants.gd`, `test/state/test_card_observation.gd`,
  `test/state/test_determinism.gd`: all touched by this story's guards; the primary suites the
  dev pass extends.

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
2. **Behavioural cause.** Any golden fixture that casts a `summon_*` card now appends a unit
   record where none was appended before, changing the board key's value from that tick forward.
   If no golden fixture currently drives a summon cast, this cause is a non-mover in practice and
   the dev pass reports that measured result rather than assuming it -- exactly the discipline
   4-0's Golden Prediction applied to its own behavioural cause.

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
the board clears. `R-D6`'s re-invocation status at the time this story reaches a dev pass is
whatever the decision-log records then -- not restated here to avoid going stale.

## Dev Agent Record

### Agent Model Used

(filled by the dev pass)

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

### File List
