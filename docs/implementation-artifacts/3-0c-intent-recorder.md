# Story 3.0c: Intent recorder — the X5 record/replay stream contract

Status: backlog

> **Scope note.** This file is authored at the story's own CREATION pass (2026-08-04), per
> `decision-log.md` `E3-P/R3`: "the story file is deliberately not authored yet ... written
> just-in-time at its own creation pass." `sprint-status.yaml`'s `story_notes` for this key, quoted
> verbatim: "Board slot only, story file deliberately not authored yet (E3-P/R3, Set B staleness
> lesson). Carries the X5 four-field contact-fact contract and both halves of DEBT B." This pass
> writes the ACs that are ALREADY LOCKED by decision-log obligations and `docs/game-architecture.md`'s
> existing X5 design; it deliberately does NOT size or fully specify the mechanism — that happens at
> this story's own readiness gate, the same two-pass shape `3-5b` used (`docs/implementation-artifacts/
> 3-5b-draw-delay-exhaustion-reshuffle.md`, Change Log 0.1 -> 0.2). Seven items that would otherwise be
> ACs are instead recorded in **Open Questions for the Readiness Gate** below, per instruction: this
> pass does not decide them. **Status stays `backlog`** — promotion to `ready-for-dev` happens at the
> fix pass that resolves those questions, not here.
>
> **Locked order.** `epics.md` E3 "Committed obligations": "the locked order is 3-5a -> 3-5b -> `3-0c`
> (`IntentRecorder`) -> 3-6." Both predecessors are `done` (verified: `sprint-status.yaml`
> `development_status`). This story is next in the E3 sequence.

## Story

As a solo developer building CardSouls,
I want the per-tick `InputIntent` stream, the four-field contact fact, the match-start injected
content (deck composition and cast-cost map), and balance-reload events captured into ONE recordable
stream contract,
so that a played round can be reconstructed exactly later from **seed + intents + reload events +
injected content** — never from anything that can change out from under a recording (the live
`CardDatabase`, a re-tuned `.tres`, a re-priced card) — closing the X5 obligation this story has
carried since `2-3/R2` and the DEBT B obligation carried since `1-3b`.

## Acceptance Criteria

Every item below is already locked by a decision-log ruling, an architecture-doc commitment, or a
structural fact verified against shipped code in this pass's own research — never invented here. Items
that are NOT yet locked are listed in Open Questions, not here.

1. **The recorder emits ONE stream contract with exactly five capture channels** — the gameplay RNG
   seed, the per-tick `InputIntent` for both slots, balance-reload events, the injected deck
   composition, and the injected cast-cost map — never a partial subset and never an ungoverned sixth
   channel. [`2-3/R2`; `3-3` close-out; `3-5a` close-out extended by `3-5b/R14`; `docs/game-architecture.md`
   §Instrumentation wiring] A structural test over the recorder's public capture surface enumerates
   exactly these five channels.
2. **Every `InputIntent` field is captured verbatim, per tick, per slot.** All eight fields —
   `move_dir`, `aim`, `pressed`, `held`, `debug_reset`, `card_slot`, `card_mode`, `card_commit` — ride
   the stream unmodified; none is dropped, summarized, or re-derived. This is safe to lock because the
   shape is FINAL as of 3-5a (`input_intent.gd`'s own header: "3-5 -> 3-0c ordering existed precisely
   so the contract is not written against a moving shape"). A test constructs a synthetic `InputIntent`
   with a non-default value in every field and asserts the captured record round-trips all eight.
3. **The seed is captured exactly once, at match start**, sourced from the SAME value the runner feeds
   `MatchParams` — never a second, independently-read seed. [`docs/game-architecture.md` §Determinism &
   Replay: "The seed is recorded with the intent stream."]
4. **Balance-reload events are captured as (tick index, the `BalanceConfig` values applied)**, sourced
   from the runner's EXISTING `apply_balance()` call site — no second injection path invented for this
   story. [DEBT B's second half, `decision-log.md:130,133`; `docs/game-architecture.md` §Determinism &
   Replay: "`IntentRecorder` therefore records each balance-reload event in the stream (tick index +
   values applied)"] Whether a LIVE mid-match trigger exists this story is Open Question 3, not this AC
   — this AC is about the event's shape and source, not about who fires it.
5. **The injected deck composition (the `Array[StringName]` argument to `inject_deck`) is captured at
   the same tick it is injected.** [`3-3` close-out: "the injected deck COMPOSITION must enter the
   replay record alongside seed, intents, and reload events, or a replay silently depends on the live
   `CardDatabase`."]
6. **The injected cast-cost map (the `Dictionary[StringName, CardCastCondition]` argument to
   `inject_card_costs`) is captured at the same tick it is injected, and is NON-OPTIONAL.** A recording
   that captured a composition but no cost map is malformed, enforced at the capture seam on the
   `inject_deck`/`push_contact` `Invariant.check` precedent. [`3-5b/R14`, extending the `3-0c`
   obligation explicitly: "The injected COST MAP ... is in the identical position ... without it a
   replay against re-priced cards diverges silently."]
7. **The four-field contact fact is captured exactly as pushed to `push_contact`** —
   `attacker_slot`, `target_slot`, `attack_index`, `target_to_attacker` — inherited into this same
   stream contract per `1-8 R-B3` / `2-3/R2`, never a narrower or re-derived shape.
8. **Capture is a PASSIVE TAP**: it never mutates `InputIntent`, `MatchState`, or the tick order, and
   its absence changes no behavior. [`docs/game-architecture.md`: "Recording is a passive tap — it
   never affects the tick."] Proven by running the golden determinism sequence with and without an
   attached recorder and asserting the `to_snapshot()` hashes are bit-identical.
9. **The recorder introduces no eighth observation seam.** It is not wired through any
   `connect_hero_*` / `connect_hit_landed` / `connect_deflect_landed` seam; it is a plain object the
   runner owns and calls directly at the sample step (`_intent_recorder.capture(intents)` per the
   architecture doc's own pseudocode), the same shape as the 3-0b debug-window-countdown and 3-5a
   card-selection-push precedents. `match_runner.gd` stays at exactly seven `connect_*` methods.
10. **No new Input Map action ships.** Any operator-facing start/stop/load control is a `Control`-level
    UI affordance under `src/ui/debug/` — the architecture doc's own placement ("X5 toggles ... :
    record/replay start-stop-load") — never a new `project.godot` action. A negative guard scans
    `project.godot` for a new record/replay-named action.
11. **`FeatureFlags` stays load-once and runtime-immutable.** This story adds no reload path to
    `FeatureFlagsService` and gates no recorder behavior behind a flag mutation. [`2-6/R4`: "flags
    appear in neither `MatchState.to_snapshot()` nor the recorded intent stream, so mutating one at
    runtime would be a silent replay hole" — the injection itself is captured once, per AC1's seed/
    reload-event precedent, not treated as a reloadable channel.]
12. **Recorded content stays OUTSIDE `MatchState.to_snapshot()`.** No captured channel (intents,
    contact facts, deck composition, cost map, reload events) is ever written into any
    `to_snapshot()`-reachable field, and no `StringName`-keyed structure this story introduces ever
    reaches `CanonicalHash`. [The 3-5a close-out's named hazard: `Array[StringName].sort()` orders by
    internal pointer, so such a key would hash green in-process while replay is already broken.] A
    test runs a recording across a sequence that exercises every capture channel and asserts the golden
    hash is unaffected by the recorder's mere presence (see Golden Prediction).

## Tasks / Subtasks

Deliberately coarse — this story's own readiness gate turns these into concrete implementation tasks
once the Open Questions below are ruled, the same two-pass shape `3-5b` used.

- [ ] Land the five-channel capture surface and its structural enumeration test (AC: 1)
- [ ] Land per-tick `InputIntent` capture with the eight-field round-trip test (AC: 2)
- [ ] Capture the seed once at match start from the runner's existing `MatchParams` value (AC: 3)
- [ ] Define the reload-event shape (tick, applied values) sourced from the existing `apply_balance()`
      call site (AC: 4) — trigger existence is Open Question 3, not this task
- [ ] Capture injected deck composition and cast-cost map at their injection ticks, cost map
      non-optional and Invariant-enforced (AC: 5, 6)
- [ ] Capture the four-field contact fact inherited from `push_contact` (AC: 7)
- [ ] Prove capture is a passive tap via the with/without-recorder golden-hash comparison (AC: 8)
- [ ] Wire capture as a runner-owned plain object call, not a `connect_*` seam; verify the seven-seam
      count is unchanged (AC: 9)
- [ ] Verify no new Input Map action; negative guard over `project.godot` (AC: 10)
- [ ] Verify `FeatureFlags` gains no reload path (AC: 11)
- [ ] Verify no captured channel reaches `to_snapshot()`/`CanonicalHash` (AC: 12)

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
  today.** This is Open Question 3's premise, verified rather than inherited from the log.
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
  also hashed (top-level `MatchState` key). The ONLY confirmed unhashed cross-tick state is
  `PlayerState.vulnerable_window` — declared and constructed on `PlayerState` but never appears in
  `to_snapshot()`. This is DELIBERATE, per `decision-log.md` `3-5b/R19`: "the vulnerable window is
  cross-tick state that is NOT hashed. That is safe only because nothing reads it ... AC 2's guard is
  precisely what keeps that premise true. If a later story prices the window, it must enter the
  snapshot at the same time." That "later story" language is why Open Question 4 below is not
  rhetorical — this story is arguably the first one for which "nothing reads it" stops being a
  sufficient safety argument, because a replay's correctness claim is no longer just "the live match
  never observed a difference" but "two independently-driven runs never observed a difference."
  Genuinely per-tick, drop-before-snapshot transients confirmed separately: `MatchState._contact_queue`
  (drained fully inside `advance()` step 4), `_camera_bases` (runner-pushed, presentation-only),
  `_deck_deal_pending` (consumed inside the same `advance()` that sets it), and
  `HeroState._roll_iframe_closed_this_tick` / `_deflect_closed_this_tick` (grace markers, named
  unhashed in the 1-9 golden record).
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
  awkward choice — see AC12 and Open Question 7.
- **`docs/game-architecture.md` already contains a fully-specified X5 design**, not merely a
  decision-log pointer. Directory tree (§Project Structure): `src/systems/intent_recorder.gd` — "X5:
  captures InputIntent stream at the runner's sample step" — sits beside `log.gd`/`invariant.gd`
  (plain classes, confirmed NOT autoloads elsewhere in this codebase) rather than beside the four
  labeled `# autoload` entries in the same folder; `src/controllers/replay_controller.gd` — "X5: emits
  InputIntent from a recorded stream (indistinguishable from hardware to the runner)"; `src/ui/debug/`
  — "record/replay start-stop-load" toggles, "no state mutation there." Runner tick pseudocode
  (§Match Runner sketch) inserts capture as ONE line between fact-gathering and `advance()`:
  `_intent_recorder.capture(intents)  # X5 passive tap — never affects the tick`. Scope is stated
  explicitly and already closed at the design-intent level: **"Scope: record + replay only — no
  rewind, no scrubbing UI."** This pass treats that scope statement as strong evidence, not as a
  ruling ON THIS STORY's sizing — see Open Question 1.
- **Observation seam count.** `match_runner.gd` has exactly seven `connect_*` methods
  (`connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`,
  `connect_deflect_landed`, `connect_hero_hp_changed`, `connect_stamina_changed`,
  `connect_mana_changed`) — the frozen family per `2-6/R7`. `EventBus` carries exactly three signals as
  of `3-5b` AC6 (`round_ended`, `round_started`, `reshuffle_vulnerable_window_opened`) — deliberately
  updated from two, and the story that did it renamed its own pin test to record the change. Neither
  count should move as a side effect of this story.

## Open Questions for the Readiness Gate

Per instruction, these are NOT decided in this pass. Each carries a recommendation and its trade-off,
one short paragraph.

1. **Scope: record only, or record + replay verification in the same story?**
   `docs/game-architecture.md` already closes this at the design-intent level ("record + replay only —
   no rewind, no scrubbing UI"), and no decision-log entry has ever proposed splitting record from
   replay the way `3-5` split into `3-5a`/`3-5b`. Recommendation: build both in one story, following
   the architecture doc's already-locked scope — replay's only real cost beyond record is a
   `ReplayController` (a `sample()` override, structurally trivial per D3) and an equality-check
   mechanism (Open Question 4). Trade-off: if the equality-check question turns out to need new
   machinery (not just a hash compare), the combined story could grow the way `3-5` did, and splitting
   at the gate — record now, replay next — is the fallback, not a redesign.
2. **Does the INITIAL balance configuration belong in the stream, not just reload events?**
   Neither the decision-log's ratified channel list nor `docs/game-architecture.md`'s capture
   description mentions the match-start `apply_balance()` call — only "reload events" are named. If
   replay re-reads the on-disk `.tres` for the STARTING config and only reload EVENTS are captured, a
   replay diverges the moment anyone tunes a value between recording and replaying, even with zero
   in-match reloads. Recommendation: capture the initial `apply_balance()` call as reload-event #0 (tick
   0, before the first real tick) rather than inventing a sixth channel — it is literally the same
   shape AC4 already locks, just at the earliest possible tick. Trade-off: this reads as "no channel six"
   only if the readiness gate agrees tick-0 counts as a reload event; if not, it is a genuine sixth
   channel and AC1's "exactly five" would need to become "exactly six."
3. **DEBT B has no live mid-match reload trigger today. Does 3-0c define the event slot without a
   trigger, or does it carry both halves and become the first live-reload story?**
   Verified this pass: `BalanceConfigService.reload()` has exactly one caller (its own `_ready()`); no
   runtime path re-triggers it. Every prior story that touched DEBT B (`1-3b` through `3-5b`) deferred
   BOTH halves (`CACHE_MODE_IGNORE` + the stream event) "together with the first story that introduces
   a live reload trigger." Recommendation: 3-0c defines the event SLOT and its shape (AC4) without
   building a trigger — a live reload UI is a separate, player/operator-facing feature with its own
   design question (what triggers it? a debug hotkey? a file-watch?) that this story's scope shouldn't
   silently absorb. Trade-off: this leaves DEBT B's reload-event half UNEXERCISED by any real trigger,
   so it can only be proven by a synthetic test that calls `apply_balance()` mid-sequence directly —
   acceptable, but worth stating plainly rather than claiming DEBT B is "closed."
4. **Unhashed cross-tick state: does replay equality check the canonical hash only, or does it need
   something stronger? Does `3-5b/R19`'s "safe because nothing reads it" still hold once a replay
   exists?**
   `3-5b/R19` grounds the vulnerable window's exclusion from `to_snapshot()` in "nothing reads it," a
   claim scoped to a SINGLE live run. A replay's correctness claim is stronger: it says two
   independently-driven runs (live, then replayed) never diverge in anything that matters. If the
   vulnerable window's value can differ between the two runs (e.g. a bug that starts it with the wrong
   duration) and the hash still matches because the field is excluded, replay would report success on
   a genuinely wrong reconstruction — silently. Recommendation: replay equality checks the canonical
   hash at minimum (cheap, already exists) and this story should decide explicitly whether to ALSO diff
   any unhashed-but-live-relevant fields (currently just the vulnerable window) as a second, stricter
   check — the `3-5b/R19` text ("must enter the snapshot at the same time") reads as anticipating this
   exact question. Trade-off: hash-only is cheap and reuses existing machinery but inherits the gap
   named above; a stronger check is more correct but has no established pattern in this codebase to
   follow, so it would be new machinery, not a reuse.
5. **Where recordings live and in what format (`user://` vs `res://`, text vs binary), and whether the
   format is part of the AC set.**
   Genuinely unaddressed by both the decision-log and `docs/game-architecture.md` — neither names a
   path or a serialization. Recommendation: `user://` (recordings are session artifacts, not shipped
   content) in a format the state harness can also construct in-test for headless replay tests (a plain
   `Dictionary`/`Array` structure serialized with Godot's built-in `var_to_bytes`/`str_to_var`,
   mirroring `CanonicalHash`'s own reliance on plain-value snapshots rather than typed Resources).
   Trade-off: a custom binary format would be more compact but harder to hand-inspect while debugging a
   replay divergence, which is this feature's entire purpose (per `docs/project-context.md`'s own
   rationale: "the only actionable playtest report here is 'I didn't see that happen'").
6. **Recording trigger and lifetime, given that no new Input Map actions are allowed.**
   `docs/game-architecture.md` already answers "how it's triggered" at the design-intent level — a
   `Control`-level "start-stop-load" toggle in `src/ui/debug/`, not a keybind — which is consistent with
   AC10's constraint and the `DebugInstrumentPanel` precedent (a window-global `Control`, not tied to
   either player's Input Map). Recommendation: add a small control to the existing
   `DebugInstrumentPanel` rather than a new top-level UI, on the "no eighth observation seam / no new
   window-global surface" discipline this codebase has kept since `E2-CO/R6`. Lifetime (per-round?
   spans a debug reset? survives a round-over freeze?) is still genuinely open and worth a explicit
   ruling — recommend per-round, ended by `round_started`, since that is the existing reset boundary
   every other per-round debug affordance (the HUD's round-clear, the label reset) already uses.
7. **Does the recorder sit in the runner or in state? State would put it in the hash.**
   `docs/game-architecture.md`'s directory tree places `intent_recorder.gd` under `src/systems/`
   (beside `log.gd`/`invariant.gd`, plain classes confirmed NOT autoloads elsewhere in this codebase,
   not beside the four entries in that same folder explicitly labeled `# autoload`), and its own
   pseudocode shows the runner calling `_intent_recorder.capture(intents)` directly — a runner-owned
   instance, the same shape as `_debug_input := DebugInputReader.new()`. This effectively answers the
   question at the design-intent level: `src/systems/`, runner-owned, never `src/state/`. Recommendation:
   ratify this placement as locked rather than reopening it — a `src/state/`-resident recorder would be
   the first thing in this codebase's history to deliberately put replay-support machinery inside the
   hashed boundary, breaking the same discipline that keeps `InputIntent` itself out of
   `to_snapshot()`. Trade-off: none identified — this is the one open question where the recommendation
   carries no real cost, which is why it's listed as still-open rather than folded into the ACs: it
   rests on reading the architecture doc's directory-tree comments as intent rather than on an explicit
   decision-log ruling naming this story.

### Project Structure Notes

Per `docs/game-architecture.md`'s existing (not newly proposed) placement, to be confirmed or amended
at the readiness gate once Open Questions 1 and 7 are ruled:
- `src/systems/intent_recorder.gd` (new) — the capture surface, runner-owned, never `src/state/`.
- `src/controllers/replay_controller.gd` (new, only if Open Question 1 resolves to record+replay in
  this story) — a `Controller` subclass emitting recorded intents; structurally indistinguishable from
  hardware to the runner (D3).
- `src/main/match_runner.gd` — one new line at the sample step (`_intent_recorder.capture(intents)`),
  no change to the seven `connect_*` seams or the `_physics_process` structure (F1 untouched).
- `src/ui/debug/` — a start-stop-load control, most likely folded into the existing
  `DebugInstrumentPanel` (Open Question 6) rather than a new top-level `Control`.
- `src/state/` — touched by NOTHING in this story (AC12; Open Question 7's recommendation).

### Project Context Rules

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

### References

- [Source: decision-log.md — `2-3/R2` (X5 rerouted to this story, one stream contract)]
- [Source: decision-log.md — `E3-P/R3` (file deliberately unauthored until this pass)]
- [Source: decision-log.md — DEBT B, entries at lines 130, 133, 171, 214, 411, 458]
- [Source: decision-log.md — `2-6/R4` (FeatureFlags load-once/runtime-immutable, replay-hole reasoning)]
- [Source: decision-log.md — Session 2026-08-03, Story 3-3 readiness gate close-out (deck composition
  obligation)]
- [Source: decision-log.md — Session 2026-08-04, 3-5a close-out (cost-map obligation, `3-5b/R14`
  extension)]
- [Source: decision-log.md — Session 2026-08-04, 3-5b close-out, `3-5b/R19` (vulnerable window unhashed,
  future obligation)]
- [Source: docs/game-architecture.md — §Project Structure (directory tree), §Match Runner sketch,
  §Determinism & Replay, §Snapshot contract, §InputIntent lifetime, §Instrumentation wiring (X5
  record/replay)]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md — E3 "Committed obligations"]
- [Source: sprint-status.yaml — `story_notes.3-0c-intent-recorder`]
- Note: `stories-manual-e3.md` contains no mention of the intent recorder, X5, or DEBT B by content
  search — this story is entirely decision-log/architecture-doc-born, not a line item in the original
  E3 manual.

## Golden Prediction

**Baseline, re-derived at write time from the `GOLDEN` constant in `test/state/test_determinism.gd`
(HEAD `ce30569`):** `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`.

**Prediction: NONE, conditional on Open Question 7 resolving as recommended.** The recorder is
runner/`src/systems/`-owned per the architecture doc's existing placement, never `src/state/`-resident,
so it cannot write a field `to_snapshot()` reaches and cannot move `CanonicalHash` by construction — the
same structural argument that makes `InputIntent` itself snapshot-exempt (AC12). If the readiness gate
instead rules the recorder (or any replay-equality bookkeeping from Open Question 4) into `src/state/`,
this prediction is INVALID and must be rewritten before the dev pass starts, not discovered by a
surprised measurement. **AC8's with/without-recorder hash-identity test is what makes NONE a checked
claim rather than an assumption**, and must be run in both directions (recorder present, recorder
absent) exactly like every other NONE prediction in this project's history.

## Live Smoke

**TBD at this story's own readiness gate — conditional on Open Questions 1 and 6.** If the story ships
record-only with no operator-facing control (a headless capture proven entirely by tests), the
`3-1`/`3-5b` precedent applies directly: NOT REQUIRED, no player-facing surface. If a start-stop-load
`Control` ships in `DebugInstrumentPanel` (the Open Question 6 recommendation), it is new,
operator-visible instrumentation in the same family the `2-2`/`2-6` debug-panel geometry smokes already
cover — a brief smoke confirming the control is reachable and does not collide with the panel's existing
countdown display becomes the minimum bar, short of a full `R-D6` two-human re-invocation (which this
story's mechanism gives no independent reason to spend). This section must be rewritten with a concrete
verdict once Open Questions 1 and 6 are ruled — it is not filled in on a guess here.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-04 | 0.1 | File authored at this story's own creation pass (`E3-P/R3`), not at a readiness gate. Twelve ACs recorded, each already locked by a decision-log ruling, an architecture-doc commitment, or a structural fact verified by content against shipped code (HEAD `ce30569`) — the one-stream-contract shape (seed + intents + reload events + injected deck composition + injected cast-cost map), the four-field contact fact's inheritance, `InputIntent`'s full eight-field capture, the passive-tap guarantee, the no-eighth-seam and no-new-Input-Map-action constraints, `FeatureFlags` staying load-once, and captured content staying outside `to_snapshot()`/`CanonicalHash`. Seven items deliberately NOT decided — scope (record vs record+replay), whether the initial `apply_balance()` belongs in the stream, DEBT B's live-trigger question, replay-equality strength against the one confirmed unhashed field (`PlayerState.vulnerable_window`), recording storage/format, the recording trigger/lifetime, and runner-vs-state placement — each recorded as an Open Question with a recommendation and its trade-off, to be ruled at this story's own readiness gate. Dev Notes correct a premise in this story's commissioning brief: swing-dedupe records and `attack_index` are hashed (not unhashed transients as assumed); the only confirmed unhashed cross-tick state is the vulnerable window, per `3-5b/R19`. Golden Prediction NONE (conditional on the runner/systems-placement recommendation); Live Smoke TBD (conditional on scope/trigger rulings). Status `backlog`; promotion to `ready-for-dev` deferred to the readiness-gate fix pass. Nothing under `src/` or `test/` is touched by this pass — docs only. | Claude Sonnet 5 |
