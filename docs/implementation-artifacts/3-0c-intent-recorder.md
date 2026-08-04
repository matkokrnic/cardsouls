# Story 3.0c: Intent recorder — the X5 record/replay stream contract

Status: ready-for-dev

> **Scope note.** This file was authored at the story's own CREATION pass (2026-08-04, commit
> `290e4c9`) per `decision-log.md` `E3-P/R3`, and REWRITTEN the same day at its own READINESS GATE,
> which returned **NOT READY** with ten blocking findings and was resolved the same session by eleven
> operator rulings (`decision-log.md`, Session 2026-08-04 — Story 3-0c readiness gate). Status is now
> `ready-for-dev`; `sprint-status.yaml` is updated alongside.
>
> **The story SPLIT at that gate** (`3-0c/R5`). `3-0c` keeps the stream contract and its proof and is
> **entirely headless**: every capture channel, the `ReplayController`, replay-side fact injection, and
> the record-then-replay identity test. It ships **no file I/O, no operator UI, no Input Map action and
> no live reload trigger**. Those move to a new sibling slot,
> `3-0d-replay-surface-and-live-reload` (board slot only, story file authored just-in-time at its own
> creation pass, following the `3-0a`/`3-0b`/`3-0c` precedent). This divides DEBT B along its own
> stated seam: **its stream half closes here, its cache half (`CACHE_MODE_IGNORE`) closes in the
> sibling.**
>
> **Locked order.** `epics.md` E3 "Committed obligations": "the locked order is 3-5a → 3-5b → `3-0c`
> (`IntentRecorder`) → 3-6." Both predecessors are `done` (verified: `sprint-status.yaml`
> `development_status`). This story is next in the E3 sequence.

## Story

As a solo developer building CardSouls,
I want every external input to `MatchState` — the seed, the per-tick `InputIntent` stream, the
four-field contact facts, the pushed camera bases, the match-start injected content (deck composition,
cast-cost map, feature flags) and balance-reload events — captured into ONE recordable stream
contract, and a `ReplayController` that reconstructs a round **from that record alone**,
so that a played round replays to a bit-identical `CanonicalHash` without consulting anything that can
change out from under a recording (the live `CardDatabase`, a re-tuned `.tres`, a re-priced card, a
different flags resource), closing the X5 obligation this story has carried since `2-3/R2` and DEBT B's
stream half, carried since `1-3b`.

## Acceptance Criteria

1. **The capture channel set is DERIVED from `MatchState`'s external intake surface by a source scan,
   not enumerated by hand.** A structural test scans `src/state/match_state.gd` for every public way
   data enters the object from outside and asserts each has a corresponding capture channel on
   `IntentRecorder`; a new intake seam shipping without a channel FAILS the test. The intake surface,
   verified by content this pass, is eight members: `advance(intents)`, `apply_balance(config)`,
   `inject_feature_flags(value)`, `inject_deck(contents)`, `inject_card_costs(costs)`,
   `push_contact(...)`, `set_camera_basis(slot, basis)`, and the seed reaching `_init` via
   `MatchParams`. `drain_signals()` is exempt and the test names it exempt IN THE ASSERTION, with the
   reason: it carries no data inward. `to_snapshot()` and `debug_window_ticks_remaining()` are egress,
   not intake.
2. **Every `InputIntent` field is captured verbatim, per tick, per slot.** All eight fields —
   `move_dir`, `aim`, `pressed`, `held`, `debug_reset`, `card_slot`, `card_mode`, `card_commit` — ride
   the stream unmodified; none is dropped, summarized, or re-derived. A test constructs a synthetic
   `InputIntent` with a non-default value in every field and asserts the captured record round-trips
   all eight.
3. **The seed is captured exactly once, at match start**, sourced from the SAME value that reaches
   `MatchParams` — never a second, independently-read seed. The test fixture is PARAMETERISED over at
   least two distinct seeds and asserts the captured value equals the constructed one in each run, so
   the assertion cannot pass against a hardcoded constant.
4. **Balance-reload events are captured as `(tick index, the BalanceConfig values applied)`, and the
   match-start `apply_balance()` call is RELOAD EVENT #0** — recorded at match start, before the first
   tick, from the runner's single existing call site (`match_runner.gd:95`). No second injection path
   ships. On replay, balance values come from the record and `BalanceConfigService` is never read; a
   test asserts a replay reproduces its recorded run with the on-disk `.tres` values differing from the
   recorded ones.
5. **The injected deck composition is captured at match start, before the first tick, together with its
   INJECTION ORDER relative to the cost map.** Replay re-injects in the recorded order. A test asserts
   the recorded composition is the exact `Array[StringName]` passed to `inject_deck`, non-empty, and
   that a record whose order is inverted fails to replay.
6. **The injected cast-cost map is captured at match start, before the first tick, and is
   NON-OPTIONAL.** A record carrying a composition but no cost map is malformed and is rejected at the
   capture seam by `Invariant.check`, on the `inject_deck`/`push_contact` precedent. Because
   `inject_card_costs`'s totality check reads `_deck_contents`, replay MUST apply the cost map second —
   the ordering of AC 5 is what makes this check mean anything on replay, exactly as it does live.
7. **Injected `FeatureFlags` are a capture channel**, recorded once at match start before the first
   tick, with the same three properties that made the composition and the cost map mandatory:
   match-start, content-only, absent from `to_snapshot()`. Replay injects the recorded flags and never
   reads `FeatureFlagsService`. **This is capture, not runtime mutation:** `FeatureFlagsService` still
   has no `reload()` method and no reload path, no recorder behaviour is gated behind a flag mutation,
   and a source scan asserts both.
8. **The pushed camera basis is a per-tick, per-slot capture channel.** The value reaching
   `set_camera_basis` is recorded for both slots each tick and re-pushed by replay before `advance()`.
   A test drives a run with a non-identity basis on at least one slot, replays it, and asserts the
   hashes match; the same test with the basis channel dropped from the record diverges.
9. **Replay suppresses the runner's own contact-fact gathering and drains RECORDED facts into
   `push_contact`, keyed by tick index.** In replay mode the runner does not call
   `_gather_contact_facts` and does not push live camera bases; it pushes the recorded facts and bases
   for the current tick instead. `MatchState.push_contact`'s signature and its four `Invariant.check`
   guards are UNCHANGED — the seam already accepts facts from whoever pushes them. A test asserts that
   a replaying runner performs zero `Area3D` overlap queries and that the facts reaching `push_contact`
   are exactly the recorded ones, in recorded tick order.
10. **PRIMARY ACCEPTANCE — a driven run is recorded and replayed FROM THE RECORD ALONE to a
    bit-identical `CanonicalHash`.** The test records a run driven through EVERY channel — including a
    mid-run `apply_balance()` and pushed contact facts — then constructs a second, independent
    `MatchState` driven only by the record (a `ReplayController` for intents, recorded facts, bases,
    seed, content and reload events for everything else) and asserts the two canonical hashes are
    bit-identical. It lives in its **OWN fixture** and is never added to the golden determinism
    sequence, which gains neither a mid-run `apply_balance` nor pushed contact facts. Dropping any one
    channel from the record makes this test diverge, which is what makes ACs 1–9 falsifiable together.
11. **Replay equality is `CanonicalHash`-only, and the cross-tick state the hash does NOT cover is
    pinned to exactly three members with its soundness argument attached.** A structural test asserts
    the exclusion set is exactly: (a) `PlayerState.vulnerable_window` — unhashed because nothing reads
    it, the read decision handed to `3-6` by `3-5b/R20`; (b) the card containers' CONTENTS and ORDER in
    `Deck`/`Hand`/`DiscardPile` — sizes only in the snapshot, sound because order "stays derivable from
    seed plus injected composition" (`player_state.gd:84-87`), which ACs 1, 3 and 5 are what make true
    across a replay; (c) `MatchState._camera_bases` — captured by AC 8 rather than hashed. A fourth
    exclusion appearing later fails this test.
12. **The recorder is `src/systems/intent_recorder.gd`, runner-owned; the replay controller is
    `src/controllers/replay_controller.gd`.** No file under `src/state/` names either class, and
    `src/state/` gains no file — a token scan asserts it, joining the four whole-directory `src/state/`
    scans already in `test_architecture_invariants.gd`.
13. **`match_runner.gd` stays at exactly seven `connect_*` methods, and THIS STORY CREATES THAT
    GUARD.** The seven-seam count (`2-6/R7`'s frozen family) has never been machine-checked; it has
    been review-enforced for eleven stories. A source scan pinning the count ships here, and it must be
    proven FALLING (an eighth `connect_*` under `src/main/` makes it fail). The recorder is wired as a
    plain runner-owned object called directly at the sample step, not through a seam.
14. **The shipped Input Map action set is UNCHANGED, pinned by exact equality.** The negative
    "no record/replay-named action" scan does not ship as a standalone claim — the repo's own labelled
    precedent says so (`test_deck_and_hand.gd:399-401`: "The negative guard above cannot tell
    'correctly added' from 'never added', so the pair is what makes the Input Map edit checkable in
    both directions"). Instead the project's action set (excluding Godot's `ui_*`) is pinned by exact
    set equality in the existing Input-Map pin family, so an ADDED action fails as loudly as a removed
    one, and this story adds none.

## Tasks / Subtasks

- [ ] Land `IntentRecorder` in `src/systems/`, runner-owned, and the intake-surface scan that derives
      its channel set (AC: 1, 12)
- [ ] Per-tick `InputIntent` capture with the eight-field round-trip test (AC: 2)
- [ ] Seed capture at match start; parameterise the fixture over two seeds (AC: 3)
- [ ] Reload-event channel with the match-start `apply_balance()` as event #0; replay applies from the
      record and never reads `BalanceConfigService` (AC: 4)
- [ ] Deck-composition and cost-map channels carrying their injection ORDER; cost map non-optional and
      `Invariant.check`-enforced at the capture seam (AC: 5, 6)
- [ ] Feature-flags channel; assert `FeatureFlagsService` still has no reload path (AC: 7)
- [ ] Camera-basis channel, per tick per slot (AC: 8)
- [ ] Contact-fact channel; runner replay mode suppresses gathering and drains recorded facts into
      `push_contact` by tick index (AC: 9)
- [ ] `ReplayController` in `src/controllers/` — a `sample()` override emitting recorded intents (AC: 9,
      10)
- [ ] The record-then-replay identity test, in its own fixture, driving every channel (AC: 10)
- [ ] The unhashed-cross-tick exclusion pin, three members with reasons (AC: 11)
- [ ] The seven-`connect_*` source scan, proven falling (AC: 13)
- [ ] The exact-equality Input Map action-set pin (AC: 14)

## Dev Notes

- **`InputIntent`'s full field inventory** (`src/state/input/input_intent.gd`), verified by content:
  `move_dir: Vector2`, `aim: Vector2`, `pressed: Dictionary[StringName, bool]`,
  `held: Dictionary[StringName, bool]`, `debug_reset: bool`, `card_slot: int` (rest `-1`),
  `card_mode: Enums.ModeKind` (rest `BASIC`), `card_commit: bool`. The file's own header names this
  story directly: "the X5 recorder (which retains a reference each tick) can never hold N aliases of
  one ever-changing object" — a guarantee that rests on the E0 LIFETIME decision (a `Controller` returns
  a FRESH instance per `sample()`, never a mutated cached one).
- **`push_contact` signature** (`match_state.gd:360`): `(attacker_slot: int, target_slot: int,
  attack_index: int, target_to_attacker: Vector2)`. Four `Invariant.check` guards at the seam (slot
  range, no self-contact, non-zero direction). Computed by the runner's `_gather_contact_facts` FROM
  POSITIONS ONLY, queued, drained inside `advance()` step 4.
- **Injection seam signatures and ordering** (`match_state.gd:313,339`): `inject_deck(contents:
  Array[StringName])` then `inject_card_costs(costs: Dictionary[StringName, CardCastCondition])`.
  ORDER IS LOAD-BEARING — the cost seam's totality check reads `_deck_contents`, so it must run second.
  The runner calls both once in `_ready()` (`match_runner.gd:109,113`), in that order. Both are
  content-only, no reload path, both confirmed absent from `to_snapshot()`.
- **Seed path**, traced end to end: `match_runner.gd`'s `_SEED := 12345` constant ->
  `MatchParams.new(_SEED)` -> `MatchState._init(params)` sets `_rng.seed = params.seed_value` and does
  NOT retain `params` — "never re-seeded" is structural (no stored seed field), not conventional
  (`match_params.gd`'s own header, `E3-RG/R9`).
- **DEBT B, current state verified by content, not assumed.** `BalanceConfigService.reload()`
  (`src/systems/balance_config_service.gd:23`) does `_config = load(CONFIG_PATH)` — a cache hit on an
  already-loaded resource, so a mid-session on-disk `.tres` edit is silently ignored (no
  `CACHE_MODE_IGNORE`). `reload()` has exactly ONE caller in the whole tree: its own `_ready()`. No
  runner code path calls it a second time — **no live mid-match reload trigger exists in shipped code
  today.** That half of DEBT B is now `3-0d`'s, per `3-0c/R5`; this story closes the stream half only.
- **`FeatureFlagsService`** (`src/systems/feature_flags_service.gd`) has no `reload()` method at all —
  load-once is structural (there is nothing to call), not merely a convention nobody has broken yet.
- **Snapshot key inventory, traced fully** (`to_snapshot()` chain: `MatchState` ->
  `PlayerState`/`PitchState` -> `HeroState`/pools/`TimingWindow`):
  `MatchState`: `tick`, `rng_state`, `round_over`, `p1`, `p2`, `pitch`.
  `PlayerState`: `hero`, `stamina`, `mana`, `orbs`, `deck_size`, `hand_size`, `discard_size`,
  `pending_draw`, `pending_draw_owed`.
  `HeroState`: `hp`, `max_hp`, `action_state`, `chain_index`, `swing_dedupe` (`attack_index` +
  `records`), `velocity`, `facing`, `roll_direction`, `move_speed`, plus seven `TimingWindow`
  sub-dictionaries (`windup`/`active`/`recovery`/`chain`/`deflect`/`roll_iframe`/`roll_duration`/
  `stun`). `StaminaPool`: `current`, `maximum`, `regen_delay`. `ManaPool`/`OrbPool`: counts only.
  `PitchState`: `fizzle`. `TimingWindow`: `duration_ticks`, `elapsed_ticks`, `is_running`.
- **Correction to a premise in this story's own commissioning brief.** The brief assumed dedupe records
  and `attack_index` were unhashed per-tick transients. Verified by content: they are NOT — both ride
  inside `HeroState.to_snapshot()`'s `swing_dedupe` key, hashed since story 1-5 (D8). `rng_state` is
  also hashed (top-level `MatchState` key). Genuinely per-tick, drop-before-snapshot transients
  confirmed separately: `MatchState._contact_queue` (drained fully inside `advance()` step 4),
  `_deck_deal_pending` (consumed inside the same `advance()` that sets it), and
  `HeroState._roll_iframe_closed_this_tick` / `_deflect_closed_this_tick` (grace markers, named
  unhashed in the 1-9 golden record). The CROSS-TICK unhashed set is corrected below by `3-0c/R8`.
- **RNG single-seat guard (F2), machine-checked.** `shuffle_with_rng(` appears exactly twice in `src/`
  — its definition in `deck.gd` and its one caller, `MatchState._shuffle_deck` — pinned by
  `test_architecture_invariants.gd` (landed as `3-5b` AC16). Nothing in this story's design should add
  a second seeded-RNG consumer; replay correctness depends on the seat count staying exactly two.
- **Why `test_determinism.gd` never loads the authored `.tres` or any autoload**, verified by content:
  `_make_match()` builds `MatchState` and calls `apply_balance(_golden_config())`,
  `inject_feature_flags(_golden_flags())`, `inject_deck(_golden_deck())`, `inject_card_costs
  (_golden_costs())` — all four built IN-TEST. The state harness has no autoloads at all, so this
  isn't a discipline that could be broken by accident; it's structural. This is the reason authored
  tuning/content can never move the golden (`BC/R3`), and it is the reason a recorder living in
  `src/state/` would be a structural break from every precedent in this codebase, not merely an
  awkward choice — see AC 12 and the guard citation below.
- **`docs/game-architecture.md` already contains a fully-specified X5 design**, not merely a
  decision-log pointer. Directory tree (§Project Structure): `src/systems/intent_recorder.gd` — "X5:
  captures InputIntent stream at the runner's sample step" — sits beside `log.gd`/`invariant.gd`
  rather than beside the THREE entries in the same folder explicitly labeled `# autoload:`
  (`feature_flags_service.gd`, `balance_config_service.gd`, `card_database.gd`, tree lines 560-562);
  `src/controllers/replay_controller.gd` — "X5: emits InputIntent from a recorded stream
  (indistinguishable from hardware to the runner)"; `src/ui/debug/` — "record/replay start-stop-load"
  toggles, "no state mutation there." Runner tick pseudocode (§Match Runner sketch) inserts capture as
  ONE line between fact-gathering and `advance()`: `_intent_recorder.capture(intents)  # X5 passive tap
  — never affects the tick`. Scope is stated explicitly: **"Scope: record + replay only — no rewind, no
  scrubbing UI."** **Two corrections to this bullet's earlier form, both verified by content:**
  `log.gd` does NOT exist in `src/systems/` (its contents are `pool/`, `balance_config_service.gd`,
  `card_database.gd`, `event_bus.gd`, `feature_flags_service.gd`, `invariant.gd`) — the tree lists a
  file that was never built; and the folder's autoload-labelled entries number THREE, not four
  (`event_bus.gd` at tree line 559 carries a D5 caption, not an `# autoload:` label). The doc's
  standing as a source is ruled by `3-0c/R10` below.
- **Observation seam count.** `match_runner.gd` has exactly seven `connect_*` methods
  (`connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`,
  `connect_deflect_landed`, `connect_hero_hp_changed`, `connect_stamina_changed`,
  `connect_mana_changed`) — the frozen family per `2-6/R7`. `EventBus` carries exactly three signals as
  of `3-5b` AC6 (`round_ended`, `round_started`, `reshuffle_vulnerable_window_opened`) — deliberately
  updated from two, and the story that did it renamed its own pin test to record the change. Neither
  count should move as a side effect of this story. **The seven-count has NO test pinning it today** —
  verified by content: `connect_` appears in `test/` only as usage (`test_contact_pipeline.gd`,
  `test_live_attack.gd`, `test_telegraph_profiles.gd`), never as a count assertion. AC 13 creates that
  guard.

### Rulings applied at this story's readiness gate

- **`3-0c/R1` — replay is NOT a controller swap alone, and the architecture doc's mechanism is
  insufficient.** Contact facts do not originate in any controller: `_gather_contact_facts`
  (`match_runner.gd:388-410`) reads `actor.hitbox.get_overlapping_areas()` and raw
  `global_position` deltas, and `InputIntent` has no contact field. A swapped-in `ReplayController`
  therefore CANNOT deliver them, and regenerating them through physics on replay was rejected at 1-7's
  gate (D-4) because it "would hang replay soundness on Jolt bit-determinism." Hence AC 9: replay mode
  also SUPPRESSES the runner's gathering and drains recorded facts into `push_contact` by tick index.
  `MatchState`'s seam is unchanged — `push_contact` already accepts facts from whoever pushes them, and
  headless tests have fed synthetic facts through it since 1-5.
- **Replay guarantees STATE identity, not VISUAL identity.** Actor positions come from
  `move_and_slide` in `HeroActor.drive()` and may drift between a recording and its replay; nothing in
  this story promises otherwise. That is tolerable precisely because the ONLY physics-to-state channel
  is the contact fact — and the contact fact is recorded. Anything a divergent position could do to the
  tick has to travel through `push_contact`, which replay supplies from the record rather than from
  the scene.
- **`3-0c/R2` — "exactly five channels" is DEAD; the channel list is DERIVED (AC 1).** No ruling
  anywhere enumerates five, and the earlier AC list contradicted the number by naming seven things.
  The list is now produced by scanning `MatchState`'s public intake surface, which makes the guard fail
  when a new seam appears without a channel. **The intake list supplied at the gate was incomplete and
  is corrected here:** `set_camera_basis(slot, camera_basis)` (`match_state.gd:389`) is a public intake
  the runner pushes every ticking frame (`match_runner.gd:460-461`), and its value is READ during
  movement resolution (`match_state.gd:567,975`) — it reaches `HeroState.velocity`, which is hashed.
  A replay that does not restore it can diverge. Today the pushed basis is always identity in live play
  (`CameraRig` has no look input, and the rig's LOCAL basis is unaffected by a hero-root rotation that
  DECISION A forbids anyway), and `_resolve_movement` short-circuits on identity — so the channel is
  cheap now and load-bearing the moment a look action ships. Hence AC 8.
- **`3-0c/R3` — injected feature flags ARE a channel (AC 7).** They have the identical three properties
  that made deck composition and the cost map mandatory: injected at match start, content-only, absent
  from `to_snapshot()`. A replay against a different flags resource diverges silently — the same
  failure `2-6/R4` names from the other direction: "flags appear in neither `MatchState.to_snapshot()`
  nor the recorded intent stream, so mutating one at runtime would be a silent replay hole." **Capture
  is not runtime mutation.** The load-once, runtime-immutable ruling for `FeatureFlags` stands
  untouched, and AC 7 carries both clauses in one breath so this cannot be read as reopening it.
- **`3-0c/R4` — the initial `apply_balance()` is reload event #0 (AC 4).** The earlier AC pointed at a
  call site it had itself declared out of scope; the single existing call site (`match_runner.gd:95`)
  is exactly the right source. Capturing it as the first event on the reload channel avoids inventing a
  sixth channel for a shape the reload channel already has. On replay, balance values come from the
  record and are never re-read from disk — which is what makes a recording survive a tuning pass, the
  failure mode the whole channel exists to prevent.
- **`3-0c/R5` — the story splits; `3-0d-replay-surface-and-live-reload` takes the operator surface.**
  See the Scope note. `3-0c` is headless: channels, `ReplayController`, replay-side fact injection,
  identity test. `3-0d` takes `ResourceLoader` `CACHE_MODE_IGNORE`, a live mid-match reload trigger,
  `user://` persistence and the serialisation format, the start/stop/load control folded into the
  existing `DebugInstrumentPanel`, and the live smoke. The board slot is added now; the story file is
  authored just-in-time at its own creation pass, per the `E3-P/R3` precedent. `E3-P/R3` — which
  assigned BOTH DEBT B halves plus record/replay to a single story — is AMENDED BY APPEND in the
  decision log: original text untouched, a scope note added above it, exactly as `E3-P/R2` was amended.
- **`3-0c/R6` — the identity test is the primary acceptance (AC 10).** The two earlier
  hash-comparison ACs (run the golden sequence with and without a recorder; assert no captured channel
  moves the hash) are unfalsifiable by construction: both pass with `capture()` bodied as `pass`. They
  are REPLACED by one test that records a driven run and replays it from the record alone to a
  bit-identical hash. It lives in its own fixture and never in the golden sequence — which must not
  gain a mid-run `apply_balance` or pushed contact facts — and dropping any channel makes it diverge,
  which is what makes every capture AC falsifiable at once.
- **`3-0c/R7` — a fabricated quotation is DELETED.** The earlier AC 2 attributed this sentence to
  `input_intent.gd`'s header: "3-5 -> 3-0c ordering existed precisely so the contract is not written
  against a moving shape." **That sentence does not exist anywhere in the repo.** The AC's substance is
  kept and re-sourced to two things that do exist. `input_intent.gd`'s real header, quoted exactly:
  "This is INPUT, not persistent state — it is captured separately in the X5 intent stream and is
  deliberately excluded from the to_snapshot() determinism contract." And the E3 ordering ruling
  (`decision-log.md`, Session 2026-07-31 — E3 revisit gate (outcome), "ORDER, recorded as part of the
  outcome"), quoted exactly: "3-0c follows 3-5 so the intent shape (the new card fields on
  `InputIntent`) is final before the stream contract is written." Together those are the real basis for
  locking the eight-field shape; the invented quotation was not.
- **`3-0c/R8` — replay equality is hash-only, and the unhashed cross-tick set is THREE members, not
  one (AC 11).** The gate's set — `{PlayerState.vulnerable_window}` — was verified by content and found
  incomplete. (a) The vulnerable window is unhashed, per `3-5b/R19` quoted exactly: "the vulnerable
  window is CROSS-TICK STATE THAT IS NOT HASHED. That is safe only because nothing reads it -- state no
  code consults cannot change an outcome or desync a replay -- and AC 2's guard is what keeps that
  premise true. **The first story that gives the window a mechanical cost MUST bring it into the
  snapshot in the same pass.**" The window's read decision is `3-6`'s, per `3-5b/R20`: "`3-6` must
  decide EXPLICITLY whether it renders from the `EventBus` event with its own presentation-local timer
  (the window stays unread and AC 2's guard stays green) or starts reading state." (b) The card
  containers' CONTENTS and ORDER are also unhashed — `PlayerState.to_snapshot()` ships `deck_size`,
  `hand_size` and `discard_size` only, and says why in its own comment: "Deck ORDER is deliberately not
  hash-visible — it stays derivable from seed plus injected composition." That derivability is a REPLAY
  argument, and it holds only if the seed (AC 3), the composition (AC 5), the injection order (AC 5/6)
  and F2's single seeded seat all hold — which is precisely what this story delivers. (c)
  `_camera_bases` is unhashed cross-tick state, addressed by AC 8's channel rather than by a key. Hash
  equality plus this three-member pin is therefore an honest equality claim; a fourth exclusion
  appearing later must fail the pin rather than quietly weakening it. **Why this story is where the
  question is forced,** carried forward from this file's creation pass: `3-5b/R19`'s "safe because
  nothing reads it" is scoped to a SINGLE live run, and this story is the first for which that stops
  being a sufficient safety argument — a replay's correctness claim is no longer just "the live match
  never observed a difference" but "two independently-driven runs never observed a difference." The
  pin is what keeps that stronger claim honest without inventing machinery this codebase has no
  pattern for.
- **`3-0c/R9` — placement is CLOSED: `src/systems/`, runner-owned (AC 12).** Not because the
  architecture tree says so — `3-0c/R10` strips the tree of that authority — but because three live
  guards in `test_architecture_invariants.gd`, each scanning EVERY `.gd` file under `src/state/`,
  independently forbid the natural implementation of a state-resident recorder:
  `test_state_layer_has_no_nondeterministic_source` (D3(b)/A2) bans `Time.`/`OS.`/`Engine.`, so a
  recording header, a timestamp, or any user-path lookup is illegal there;
  `test_state_layer_never_names_card_data` bans `CARDS_DIR`/`data/cards`, so a recorder that resolves
  or validates its captured composition against the card library by path is illegal there; and
  `test_state_layer_never_uses_implicit_global_rng_or_card_database` bans the `CardDatabase` autoload
  — the same reach through the other door — plus a bare `seed(`, which is how a replay-side reseed
  would naturally be written. **Stated precisely so the argument is not overclaimed:** a deliberately
  clock-free, content-blind, in-memory recorder placed under `src/state/` would trip none of the four
  scans. What closes the question is those three guards plus AC 12's own token scan, which is why
  AC 12 ships a scan rather than resting on the tree.
- **`3-0c/R10` — the architecture doc's X5 section is PRE-CODE TEXT.** Verified by content: the X5
  directory-tree entries and the record/replay wiring trace to `6ac94bc` (2026-07-21), revised once by
  `11fdd23` the same day; both precede `57038dc`, the first commit that adds anything under `src/`
  (rev-counts 8 and 9 against 11). The gate stated a single commit; it is two, both pre-code, so the
  load-bearing property holds. It is therefore a source of CANDIDATE DESIGN, not authority — the same
  class as the section that once claimed E0 had landed the economy evaluator. Two consequences: (1) its
  scope line — "record + replay only — no rewind, no scrubbing UI" — is RATIFIED NOW as a decision, so
  it stops being aspirational; (2) its controller-swap replay mechanism is DEMONSTRATED INSUFFICIENT by
  `3-0c/R1` and becomes a new architecture-amendment queue member (the NINTH; the queue held eight per
  `3-5/R9`). `docs/game-architecture.md` is NOT edited this pass — the queue flushes at the E3
  close-out, forcing point unchanged.
- **`3-0c/R11` — guard and wording corrections.** The seven-`connect_*` count had no test (AC 13
  creates it). The negative Input-Map scan dies as a standalone AC and binds instead to an
  exact-equality action-set pin (AC 14) — the repo's own labelled precedent for why a negative alone is
  vacuous is quoted in that AC. The fixture seed is parameterised (AC 3); note the gate named `12345`,
  which is `match_runner.gd:20`'s `_SEED` — the state fixture's constant is `test_determinism.gd:271`,
  `SEED := 1337`, and either way a hardcoded assertion is what parameterisation removes. "At the same
  tick it is injected" is corrected to "at match start, before the first tick" throughout: both
  injections happen in `_ready()`, where the tick is 0. The record carries the deck/cost injection
  ORDER and replay applies it (AC 5, 6), because the cost seam's totality check reads `_deck_contents`
  and passes vacuously against an empty one.

## Project Structure Notes

- `src/systems/intent_recorder.gd` (new) — the capture surface, runner-owned, never `src/state/`
  (AC 12).
- `src/controllers/replay_controller.gd` (new) — a `Controller` subclass emitting recorded intents;
  structurally indistinguishable from hardware to the runner (D3).
- `src/main/match_runner.gd` — the capture call at the sample step, plus a headless replay mode that
  suppresses fact-gathering and the live camera-basis push and drives both from the record (AC 9). No
  change to the seven `connect_*` seams and no change to the `_physics_process` structure (F1
  untouched).
- `src/ui/debug/` — **untouched by this story.** The start/stop/load control is `3-0d`'s.
- `src/state/` — touched by NOTHING in this story (AC 12).
- `project.godot` — untouched (AC 14).

## Project Context Rules

- **Seeded RNG consumed only inside `advance()`; no bare global RNG in `src/state/`.** [Source:
  docs/project-context.md#Critical Implementation Rules, line 54]
- **Replay is sound only if every non-input source of variation is captured; the seed is recorded with
  the intent stream; balance-reload events are recorded, not ignored.** [Source:
  docs/game-architecture.md#Determinism & Replay (validation F2 + X3/X5 reconciliation)]
- **`InputIntent` is excluded from the snapshot contract because it is input, captured separately in
  the X5 stream.** [Source: docs/game-architecture.md#Snapshot contract, line ~932]
- **A `Controller` returns a fresh `InputIntent` per `sample()` — never a reused mutable instance —
  which is what makes recorder aliasing structurally impossible.** [Source:
  docs/game-architecture.md#InputIntent lifetime, line ~938]
- **`Input.*` may appear only under `src/controllers/`.** [Source: docs/project-context.md#Critical
  Implementation Rules; D3(a)]

## References

- [Source: decision-log.md — `2-3/R2` (X5 rerouted to this story, one stream contract)]
- [Source: decision-log.md — `E3-P/R3` (file deliberately unauthored until this pass; AMENDED BY
  APPEND at this gate, `3-0c/R5`, to scope across the `3-0c`/`3-0d` pair)]
- [Source: decision-log.md — `D-4` and its 1-8 supersession (four-field contact fact; replay
  regenerating facts through physics REJECTED)]
- [Source: decision-log.md — DEBT B, entries at lines 130, 171, 214, 411, 458]
- [Source: decision-log.md — `2-6/R4` (FeatureFlags load-once/runtime-immutable, replay-hole reasoning)]
- [Source: decision-log.md — Session 2026-07-31, E3 revisit gate (outcome), "ORDER" (3-0c follows 3-5
  so the intent shape is final)]
- [Source: decision-log.md — Session 2026-08-03, Story 3-3 readiness gate close-out (deck composition
  obligation)]
- [Source: decision-log.md — Session 2026-08-04, 3-5a close-out (cost-map obligation, `3-5b/R14`
  extension)]
- [Source: decision-log.md — Session 2026-08-04, 3-5b close-out, `3-5b/R19` and `3-5b/R20` (vulnerable
  window unhashed; the read decision handed to 3-6)]
- [Source: decision-log.md — Session 2026-08-04, Story 3-0c readiness gate (`3-0c/R1`..`3-0c/R11`)]
- [Source: docs/game-architecture.md — §Project Structure (directory tree), §Match Runner sketch,
  §Determinism & Replay, §Snapshot contract, §InputIntent lifetime, §Instrumentation wiring (X5
  record/replay) — PRE-CODE TEXT per `3-0c/R10`, candidate design rather than authority]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md — E3 "Committed obligations"]
- [Source: sprint-status.yaml — `story_notes.3-0c-intent-recorder`, `story_notes.3-0d-replay-surface-
  and-live-reload`]
- Note: `stories-manual-e3.md` contains no mention of the intent recorder, X5, or DEBT B by content
  search — this story is entirely decision-log/architecture-doc-born, not a line item in the original
  E3 manual.

## Golden Prediction

**Baseline, re-derived at write time from the `GOLDEN` constant in `test/state/test_determinism.gd`
(HEAD `290e4c9`):** `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`.

**Prediction: NONE.** Both premises are argued, not assumed:

1. **No snapshot key.** Nothing this story ships is reachable from `MatchState.to_snapshot()`. The
   recorder lives in `src/systems/` and the replay controller in `src/controllers/` (AC 12, guarded by
   a token scan plus the three `src/state/` scans cited in `3-0c/R9`); `src/state/` gains no file and
   no field, so there is no path by which a captured channel could enter the hashed chain. This is the
   same structural argument that makes `InputIntent` itself snapshot-exempt.
2. **No seeded-RNG consumer.** The recorder and the replay controller draw no randomness. F2's
   two-site guard (`shuffle_with_rng(` — its definition in `deck.gd` plus the one `MatchState` helper,
   `test_architecture_invariants.gd`, landed as `3-5b` AC 16) must still read exactly two after this
   story. A recorder that consumed the gameplay generator would both break replay and fail that guard.

**The identity test's fixture is SEPARATE and the golden sequence is NOT widened.** AC 10's fixture
drives a mid-run `apply_balance()` and pushes contact facts; the golden fixture gains neither. That
separation is what makes the NONE prediction structural rather than hopeful — there is no edit to
`test_determinism.gd`'s driven sequence in this story's scope. If the dev pass finds itself needing
one, the prediction is INVALID and must be rewritten before the work continues, not discovered by a
surprised measurement.

## Live Smoke

**NOT REQUIRED — and the reason is this story's own, not a borrowed one.** `3-0c` ships nothing
live-observable: no operator control, no Input Map action, no HUD or debug-panel surface, no visual or
audible change, and no altered live-play behaviour (the recorder is a passive tap; replay mode is
reachable only from a test). There is nothing a human at the keyboard could see that the headless
identity test does not already prove more strictly. The smoke belongs to `3-0d`, which ships the
start/stop/load control, `user://` persistence and the live reload trigger — every part of this feature
that a human can actually observe. `R-D6` is not re-invoked here and stays AVAILABLE.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-04 | 0.1 | File authored at this story's own creation pass (`E3-P/R3`), not at a readiness gate. Twelve ACs recorded, each already locked by a decision-log ruling, an architecture-doc commitment, or a structural fact verified by content against shipped code (HEAD `ce30569`) — the one-stream-contract shape (seed + intents + reload events + injected deck composition + injected cast-cost map), the four-field contact fact's inheritance, `InputIntent`'s full eight-field capture, the passive-tap guarantee, the no-eighth-seam and no-new-Input-Map-action constraints, `FeatureFlags` staying load-once, and captured content staying outside `to_snapshot()`/`CanonicalHash`. Seven items deliberately NOT decided — scope (record vs record+replay), whether the initial `apply_balance()` belongs in the stream, DEBT B's live-trigger question, replay-equality strength against the one confirmed unhashed field (`PlayerState.vulnerable_window`), recording storage/format, the recording trigger/lifetime, and runner-vs-state placement — each recorded as an Open Question with a recommendation and its trade-off, to be ruled at this story's own readiness gate. Dev Notes correct a premise in this story's commissioning brief: swing-dedupe records and `attack_index` are hashed (not unhashed transients as assumed); the only confirmed unhashed cross-tick state is the vulnerable window, per `3-5b/R19`. Golden Prediction NONE (conditional on the runner/systems-placement recommendation); Live Smoke TBD (conditional on scope/trigger rulings). Status `backlog`; promotion to `ready-for-dev` deferred to the readiness-gate fix pass. Nothing under `src/` or `test/` is touched by this pass — docs only. | Claude Sonnet 5 |
| 2026-08-04 | 0.2 | Readiness-gate fix pass (NOT READY on first read with ten blocking findings -> fixed and promoted, same session; TWENTIETH logged readiness-gate session, all twenty NOT READY on first reading and all twenty resolved the same session). Eleven rulings applied, `3-0c/R1`..`3-0c/R11`. **The story SPLIT** (`3-0c/R5`): `3-0c` keeps the contract and its proof and is entirely headless; a new sibling slot, `3-0d-replay-surface-and-live-reload`, takes the operator surface, `user://` persistence and format, `CACHE_MODE_IGNORE`, the live reload trigger and the live smoke — dividing DEBT B along its own stated seam. AC set replaced with FOURTEEN machine-checkable claims about shipped software. "Exactly five channels" is dead: the channel set is DERIVED from `MatchState`'s intake surface by a source scan (`3-0c/R2`), and the gate's intake list was corrected by content — `set_camera_basis` is an eighth intake whose value reaches hashed `velocity`, so it becomes a channel (AC 8). Replay is not a controller swap alone: contact facts originate in the runner from `Area3D` overlaps and raw positions and cannot ride `InputIntent`, so replay suppresses gathering and drains recorded facts into `push_contact` by tick index (`3-0c/R1`, AC 9), with replay's guarantee stated as STATE identity, not visual identity. Injected feature flags become a channel without reopening load-once immutability (`3-0c/R3`, AC 7); the match-start `apply_balance()` becomes reload event #0 (`3-0c/R4`, AC 4). The two unfalsifiable hash-comparison ACs — both pass with `capture()` bodied as `pass` — are REPLACED by one record-then-replay identity test in its own fixture, driving every channel including a mid-run `apply_balance` and pushed contact facts (`3-0c/R6`, AC 10). A FABRICATED QUOTATION attributed to `input_intent.gd`'s header is deleted and the AC re-sourced to the file's real text plus the E3 ordering ruling, both quoted exactly (`3-0c/R7`). The unhashed cross-tick set is corrected from one member to THREE — the vulnerable window, the card containers' contents/order, and `_camera_bases` — each with its soundness argument, pinned so a fourth fails (`3-0c/R8`, AC 11). Placement closed to `src/systems/`, runner-owned, cited to three live `src/state/` guards rather than to the architecture tree, with the argument's limit stated (`3-0c/R9`, AC 12). The architecture doc's X5 section is ruled PRE-CODE TEXT — candidate design, not authority; its scope line is ratified, its controller-swap mechanism becomes the architecture-amendment queue's NINTH member, flushing at the E3 close-out (`3-0c/R10`). Guard corrections (`3-0c/R11`): the seven-`connect_*` count gains its first test (AC 13); the vacuous negative Input-Map scan is replaced by an exact-equality action-set pin (AC 14); the fixture seed is parameterised; "at the same tick it is injected" corrected to "at match start, before the first tick"; the record carries the deck/cost injection ORDER. Dev Notes APPENDED to (all twelve original bullets retained) with the eleven rulings and three content corrections: `log.gd` does not exist in `src/systems/`, the architecture tree's autoload-labelled entries number three not four, and the paraphrased `3-5b/R19` quotation is now quoted exactly. Golden Prediction NONE, now ARGUING both premises (no snapshot key; no seeded-RNG consumer) and stating that the identity fixture is separate so the golden cannot move. Live Smoke NOT REQUIRED with this story's own reason: nothing in it is live-observable. Open Questions section REMOVED — all seven are ruled or re-homed to `3-0d`. Status `backlog` -> `ready-for-dev`; `sprint-status.yaml` updated alongside with the new `3-0d` board slot. Docs only — no `src/`, no `test/`, no `project.godot`; suite not run. | Claude Opus 5 |
