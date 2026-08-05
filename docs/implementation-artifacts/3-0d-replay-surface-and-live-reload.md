# Story 3.0d: Replay surface and live reload — the operator half of X5 + DEBT B's cache half

Status: backlog

> **Scope note.** This file is authored at the story's own CREATION pass (2026-08-05), per the
> `3-0a`/`3-0b`/`3-0c` precedent: the board slot was created ahead of the story file
> (`sprint-status.yaml`, `story_notes.3-0d-replay-surface-and-live-reload`), and the file itself is
> written just-in-time, the same discipline `E3-P/R3` set and `3-0c/R5` continued.
>
> **Origin of the split.** `3-0c-intent-recorder.md` split at its own readiness gate (`3-0c/R5`,
> decision-log Session 2026-08-04 — Story 3-0c readiness gate): `3-0c` kept the stream contract and
> shipped **entirely headless** — every capture channel, `ReplayController`, replay-side fact
> injection, and the record-then-replay identity test, with **no file I/O, no operator UI, no Input
> Map action and no live reload trigger**. Everything a human can actually observe about
> record/replay moved here. This divides DEBT B along its own stated seam (decision-log:130-133):
> its **stream half** closed in `3-0c` (decision-log:3952: "The reload channel (AC 4) captures every
> `apply_balance()` call by value and replay never reads `BalanceConfigService`, closing the half of
> DEBT B this story owed."); its **cache half** — `ResourceLoader` `CACHE_MODE_IGNORE` — is this
> story's.
>
> **Sequencing.** `epics.md`'s locked order (§E3 "Committed obligations") reads "the locked order is
> 3-5a → 3-5b → `3-0c` (`IntentRecorder`) → 3-6" and does not mention `3-0d` at all — verified by
> content; the epics doc predates the split and was never amended for it. The authority for `3-0d`'s
> position is the decision log and the sprint board, not `epics.md`. **Operator ruling, 2026-08-05:**
> `3-0d` is sequenced BEFORE `3-6`, i.e. 3-5a → 3-5b → 3-0c → **3-0d** → 3-6. The prior board note
> (`story_notes.3-0d…`, added at `3-0c`'s gate) left this open ("its place relative to 3-6 is fixed
> at its own creation pass, not here") — this pass closes it, recorded in `sprint-status.yaml`
> alongside this file.

## Story

As a solo developer building CardSouls,
I want the `IntentRecorder` stream `3-0c` built headless to become something I can actually operate —
a live mid-match balance reload that lands on the SAME reload channel `3-0c` already shipped, a
recording I can start, stop and save to `user://`, a saved recording I can load back, and the
`BalanceConfigService` cache bug fixed so a reload actually re-reads the `.tres` —
so that I can tune balance without restarting the game and trust that a played-and-saved round
replays to a bit-identical `CanonicalHash`, closing DEBT B entirely and giving X5's stream contract
its first live, human-operable surface.

## Acceptance Criteria

1. **`BalanceConfigService.reload()` bypasses the resource cache — DEBT B's cache half.** Verified by
   content, the shipped body (`src/systems/balance_config_service.gd:27`) is `_config = load
   (CONFIG_PATH) as BalanceConfig` — a plain `load()`, which returns the cached resource on every
   call after the first, so a mid-session edit to the on-disk `.tres` is silently ignored
   (decision-log:130: "on-disk hot-reload is a no-op without `CACHE_MODE_IGNORE`"). `reload()` is
   changed to `ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as
   BalanceConfig`. A test edits a value in the on-disk `.tres` between two `reload()` calls in the
   same process and asserts `get_config()` differs on the second call — proving the cache is
   actually bypassed, not merely re-requested. This is an integration test: `BalanceConfigService` is
   an autoload, and the state harness runs with no autoloads at all (per the E0 harness constraint).
2. **A live mid-match reload calls `apply_balance()` a second time and enters the SAME reload
   channel `3-0c` already shipped — no second injection path.** The trigger calls
   `BalanceConfigService.reload()` then `MatchState.apply_balance(BalanceConfigService.get_config())`
   exactly as the match-start call does (`match_runner.gd:128-133`), and — whenever a recording is
   active — the SAME call also reaches `IntentRecorder.capture_apply_balance()` first, so the live
   reload becomes reload event N on the existing channel, in the existing `{"tick": int, "values":
   Dictionary}` shape (`intent_recorder.gd:97-99`). A test drives a live-shaped `MatchState` +
   `IntentRecorder` pair through match start plus one live trigger and asserts
   `reload_event_count() == 2`, with event index 1's captured tick matching the trigger point.
3. **`IntentRecorder` gains NO new channel.** It ships exactly eight `capture_*` methods today —
   measured by content (`capture_seed`, `capture_apply_balance`, `capture_inject_feature_flags`,
   `capture_inject_deck`, `capture_inject_card_costs`, `capture_set_camera_basis`,
   `capture_push_contact`, `capture_advance`) — and this story adds none: the live reload trigger
   (AC 2) is a second CALL to the existing `capture_apply_balance`, not a new method. A structural
   test counts `func capture_` occurrences in `intent_recorder.gd` and asserts exactly eight,
   proving a ninth would be a scope violation this test catches.
4. **A completed recording can be saved to `user://` and a freshly-loaded record replays to the same
   `CanonicalHash` as replaying the original in-memory record.** This is the AC 10 / `3-0c` identity
   shape, driven twice — once from the in-memory `IntentRecorder` and once from an
   `IntentRecorder` reconstructed by loading the saved file — and asserting the two replays hash
   identically. **The on-disk FORMAT itself is not pinned by this AC** (Open Question (b)): breaking
   the save/load round-trip is what makes this AC falsifiable, not any particular byte layout, key
   naming, or file extension.
5. **A recording has an explicit start and stop, and starting discards any prior record rather than
   appending to it.** A test starts a capture, drives N ticks, stops, starts a SECOND capture, drives
   M ticks, stops, and asserts the second record's `tick_count() == M` (not `N + M`) — proving start
   begins a fresh record. **What a mid-recording debug reset does to a live recording is explicitly
   OUT OF SCOPE for this AC** — see Open Question (a).
6. **Start, stop and load are three controls added to the EXISTING `DebugInstrumentPanel`
   (`src/ui/debug/debug_instrument_panel.gd`), following its own in-code `CheckButton`/`Button`
   pattern (verified by content: two `CheckButton`s built directly in `_ready()`, no `.tscn`) — no
   new top-level `Control`, no new `.tscn`, and NO Input Map action.**
   `test_shipped_input_map_action_set_is_exactly_pinned` (`test/state/test_deck_and_hand.gd:439`)
   stays green UNMOVED — the project's 28-action set (verified by content,
   `SHIPPED_INPUT_ACTIONS`, `test_deck_and_hand.gd:428-436`) gains nothing, proving the controls are
   mouse-only exactly as the panel's existing two switches are. A test invokes each control's signal
   handler programmatically (the existing panel's own test pattern) and asserts the runner's
   recording/replay-staging state changes accordingly.
7. **This story does not add pool-specific gating to a live reload — the shipped per-pool contract
   (`MatchState._apply_balance_to_player`, `match_state.gd:1116-1130`) is exercised UNCHANGED by the
   live trigger.** Verified by content: stamina receives `set_maximum` **and** `refill()` on every
   `apply_balance()` call, including reloads (D9, `test_mid_match_reload_refills_stamina_to_max`);
   mana receives `set_maximum` only, never refilled; hp is `set_max_hp` plus a `heal()` gated to
   `first_injection` only. A test applies a live reload mid-match with stamina below max and asserts
   it refills to the new maximum exactly as the existing 1-4 reload test proves for `apply_balance()`
   generally — proving the live trigger is a genuine call to the same seam, not a special-cased
   partial reload. **Whether a visible stamina refill on a live reload is acceptable is explicitly
   NOT decided here** — see Open Question (e).
8. **Every pin `3-0c` shipped stays green, UNCHANGED, and none is edited by this story:**
   `test_runner_observation_seams_are_exactly_seven` (`test_architecture_invariants.gd:284`, the
   seven-`connect_*` count), `test_unhashed_cross_tick_state_is_exactly_three_members`
   (`test_replay_identity.gd:265`, the three-member exclusion pin), `test_every_match_state_intake_
   has_a_capture_channel` (`test_intent_recorder.gd:52`, the channel-derivation guard), and
   `test_state_layer_never_names_the_recorder_or_the_replay_controller`
   (`test_architecture_invariants.gd:231`, the `src/state/` token scan). This story's persistence and
   trigger code lives in `src/systems/` and/or `src/ui/debug/`, never `src/state/`, and adds no
   `connect_*` seam and no unhashed cross-tick member — proven by these four tests requiring zero
   edits.
9. **The passive-tap seat `3-0c` shipped is not relocated.** `IntentRecorder.capture_advance(intents)`
   stays seated immediately before `_match_state.advance(intents)`, inside the `ticking` gate
   (`match_runner.gd:566-568`) — this story adds a second `apply_balance()` call site (AC 2) but does
   not touch the intent-tap seat, the `ticking` gate, or `_physics_process`'s structure (F1 untouched).

## Tasks / Subtasks

- [ ] `ResourceLoader.load(..., CACHE_MODE_IGNORE)` in `BalanceConfigService.reload()`; the on-disk-edit
      integration test (AC: 1)
- [ ] Live reload trigger calling `reload()` -> `apply_balance()`, routed through
      `capture_apply_balance()` when a recording is active (AC: 2, 3, 9)
- [ ] `user://` save/load round-trip for a completed `IntentRecorder` capture; identity test against
      the AC 10 shape (AC: 4)
- [ ] Start/stop lifecycle on the recorder: start discards, stop finalizes (AC: 5)
- [ ] Start/stop/load controls added to `DebugInstrumentPanel`, no new Input Map action, exact-equality
      pin unmoved (AC: 6)
- [ ] Per-pool live-reload proof against the unchanged `_apply_balance_to_player` contract (AC: 7)
- [ ] Confirm the four inherited `3-0c` pins require zero edits (AC: 8)
- [ ] Live smoke on the shipped two-keyboard default (see Live Smoke)

## Dev Notes

- **`BalanceConfigService`'s full current body**, verified by content
  (`src/systems/balance_config_service.gd`): an autoload; `_ready()` calls `reload()`; `reload()` is
  `_config = load(CONFIG_PATH) as BalanceConfig` guarded by `ResourceLoader.exists`. `reload()` has
  exactly ONE caller in the whole tree today (its own `_ready()`) — confirmed by `3-0c`'s own Dev
  Notes and unchanged since. This story gives it a second caller (AC 2).
- **DEBT B, original text**, quoted exactly (decision-log:130-133): "`reload()` returns a cached
  resource; on-disk hot-reload is a no-op without `CACHE_MODE_IGNORE`. ... The FIRST story that
  introduces a live mid-match reload trigger MUST land BOTH halves together: 1. `ResourceLoader.load
  (..., CACHE_MODE_IGNORE)` in `reload()` ...; 2. record the reload event into the intent stream." At
  the time this was written there was no `IntentRecorder` yet; `3-0c` landed half 2 without a live
  trigger to exercise it (decision-log:3952: "DEBT B's STREAM HALF IS NOW CLOSED... The CACHE half...
  remains open and belongs to `3-0d`"). This story is where both halves finally have a real caller.
- **The reload channel's existing shape**, verified by content (`intent_recorder.gd:49-53,95-99`):
  `_reload_events: Array[Dictionary]`, each `{"tick": int, "values": Dictionary}`, appended by
  `capture_apply_balance(config)` — `Invariant.check(config != null, ...)` then
  `_reload_events.append({"tick": _tick, "values": _resource_values(config)})`. Event #0 is the
  match-start call (`match_runner.gd:132`, `if not replaying: _recorder.capture_apply_balance
  (balance_config)`). Replay-side: `replay_balance_config(index)` rebuilds a fresh `BalanceConfig`
  from stored values (never a retained handle); `replay_apply_reloads_before(ms, tick)` walks events
  1.. and applies any whose tick matches `tick - 1`, deliberately skipping index 0 (applied once by
  the caller at match start). **This machinery already supports N reload events — nothing about it
  assumes exactly one.** The live trigger (AC 2) needs no new field or method here, only a second
  caller.
- **Match-start injection order, unaffected**, verified by content (`match_runner.gd:90-181`): seed
  capture -> `apply_balance` (reload event #0) -> flags injection -> deck injection -> cost
  injection, in that exact order, each gated `if not replaying: _recorder.capture_...`. This story's
  live trigger runs strictly AFTER match start (mid-tick, from a UI control), so it cannot land
  before event #0 and cannot reorder the match-start sequence.
- **The passive-tap seat, verified by content** (`match_runner.gd:498-568`): `_physics_process`
  reads the debug pause edge, samples both controllers every frame, then — only `if ticking` — forks
  on `replay_record != null`. In the LIVE (non-replay) branch: camera-basis capture+push, contact-fact
  gather+capture, then `_recorder.capture_advance(intents)` immediately before
  `_match_state.advance(intents)` (lines 560-568, "Seated HERE, immediately before advance(), and NOT
  at the sample step"). This story's live reload trigger is a UI-driven event, not a per-tick seam,
  and does not touch this block.
- **`DebugInstrumentPanel`'s actual, current API**, verified by content
  (`src/ui/debug/debug_instrument_panel.gd`): a `Control` built entirely in code (`_ready()`, no
  `.tscn`), holding a `PanelContainer` -> `VBoxContainer` -> (title, `HBoxContainer` of `switches`
  column + `WindowCountdown` column). Two `CheckButton`s exist today (`NormalizeMagnitude`,
  `PitchZoneLeftOfBars`), each wired `toggled.connect(...)` to a private handler that mutates a
  held reference directly (`gamepad_profile`, `huds`) — never a signal back out to the runner, and
  never `ResourceSaver`/disk writes. The countdown column is READ-ONLY, pushed plain integers by the
  runner post-`advance()` (`set_window_countdown`). **There is no existing pattern in this file for a
  control that asks the RUNNER to do something** (both existing switches self-contain their effect);
  start/stop/load is the first control here that must reach back to the runner's recorder/replay
  state, which needs either a runner-owned `Callable`/reference handed to the panel at construction
  (the `gamepad_profile`/`huds` precedent, generalized) or a signal the runner connects to — a HOW
  decision left to the dev pass, not fixed here.
- **The Input Map pin, verified by content** (`test/state/test_deck_and_hand.gd:428-452`): 28 actions
  (`debug_pause`, `debug_step`, 13 `p1_*`, 13 `p2_*`), asserted by exact set equality against
  `InputMap.get_actions()` filtered of Godot's `ui_*` built-ins. The assertion message names `3-0c`
  by name ("3-0c ships none") — this story ships the panel's start/stop/load controls with the SAME
  guarantee the message describes for `3-0c`: mouse-only, `project.godot` untouched, this test
  unmoved.
- **The per-pool reload contract, verified by content** (`match_state.gd:1116-1130`,
  `_apply_balance_to_player`): `player.hero.set_max_hp(config.max_hp)`; `if first_injection:
  player.hero.heal(config.max_hp)`; `player.hero.move_speed = config.move_speed`;
  `player.stamina.set_maximum(config.max_stamina)` then **unconditionally** `player.stamina.refill()`
  with a comment naming this exact fact ("every `apply_balance`, reload included
  (`test_mid_match_reload_refills_stamina_to_max`)"); `player.mana.set_maximum(config.max_mana)` with
  no refill call at all. **Consequence, stated plainly:** a live reload mid-match will visibly top up
  stamina to whatever the new maximum is, even if the operator only meant to retune, say, attack
  timing. This story does not change that behavior (AC 7) — it only gives it its first live
  exercise, since every prior reload was either match-start (stamina already full) or a headless
  test.
- **CONSTRAINT C, the standing rule this story is the first to exercise live**, quoted exactly
  (decision-log:135): "Downstream E1 stories must read `ms.balance_ticks` at `start()` time; never
  cache the `BalanceTicks` object. `apply_balance()` swaps the whole `BalanceTicks` object on every
  reload." Every in-flight `TimingWindow` (windup, deflect, roll i-frame, etc.) keeps its ALREADY-
  STARTED duration across a reload (the reload changes what the NEXT `start()` picks up, not a
  window already running) — this is existing, unaffected behavior, verified across a dozen sites in
  `match_state.gd`/`hero_state.gd`/the pools, none of which this story touches.
- **R-D6 live-smoke acceptance — current status, corrected by content search.** `R-D6` was spent at
  `3-4` (decision-log:2343/2346, "R-D6 re-invoked and SPENT"), then **re-invoked and spent AGAIN at
  `3-5a`** (decision-log:3191, "Smoke Record... R-D6 re-invoked and SPENT") — this is the most recent
  spend, one story later than the commissioning brief's premise. `3-5b` did not re-invoke it
  (decision-log:3338/3604, "stays `3-6`'s"), and neither did `3-0c` (decision-log:3796/3960, "stays
  AVAILABLE"). **Current state: AVAILABLE, last spent `3-5a`.** Whether THIS story's live smoke
  re-invokes it is Open Question (c) — left open rather than assumed either way.
- **`epics.md` does not mention `3-0d`**, verified by content search of the whole file: the only
  locked-order text naming this pair of stories is "3-5a → 3-5b → `3-0c` (`IntentRecorder`) → 3-6"
  (`epics.md:95`), predating the split. `decision-log.md` and `sprint-status.yaml` are the sequencing
  authority for `3-0d`, not `epics.md` — consistent with `3-0c/R10`'s ruling that pre-code planning
  text is candidate design, never authority once the split it didn't anticipate has happened.
- **`stories-manual-e3.md` contains no mention of `3-0d`, the intent recorder, X5, replay, or DEBT B
  by content search** — the same finding `3-0c`'s Dev Notes recorded for itself. This story, like its
  sibling, is entirely decision-log/architecture-doc-born, not a line item in the original E3 manual.
- **`docs/game-architecture.md`'s X5 text, re-checked for this story** — the two lines most directly
  relevant: `src/ui/debug/` is annotated "X5 toggles + overlays ONLY (no state mutation): flags ·
  inspector · step/pause · reveal-hand · record/replay start-stop-load" (line 579); the
  "Determinism & Replay" section states "Balance hot-reload is recorded, not ignored (X3/X5
  reconciliation)... `IntentRecorder` therefore records each balance-reload event in the stream
  (tick index + values applied); `ReplayController` re-applies them at the same tick" (lines 920-925).
  **This doc's standing is unchanged from `3-0c/R10`: PRE-CODE TEXT, candidate design, not
  authority** — its scope line ("record + replay only — no rewind, no scrubbing UI") was already
  ratified as a decision by that ruling and binds this story too. `docs/game-architecture.md` is not
  edited by this pass.
- **A structural gap this story's own reading surfaces, not previously named anywhere**: `3-0c`'s
  `replay_record` is read exactly once, in `_ready()` (`match_runner.gd:105-109`), BEFORE the runner
  node ever enters the tree or ticks — `_ready()` is where slot controllers are constructed, and
  `ReplayController.new(replay_record, slot)` is one of the two branches chosen there. There is no
  code anywhere in `src/` that changes `replay_record` after that point, and no scene-reload or
  restart mechanism exists in `src/` at all (verified: `reload_current_scene`/`change_scene` appear
  nowhere in `src/`). **A "load" control clicked mid-session, today, has no runtime path to actually
  ENTER replay mode** — see Open Question (f).

## Project Structure Notes

- `src/systems/balance_config_service.gd` — `reload()`'s `load()` call becomes a `ResourceLoader.load
  (..., CACHE_MODE_IGNORE)` call (AC 1). No new file.
- `src/systems/intent_recorder.gd` — gains NO new `capture_*` method (AC 3); the save/load round-trip
  (AC 4) needs a to-dict/from-dict shape somewhere — whether that lives as new methods on
  `IntentRecorder` itself or a sibling file under `src/systems/` is a HOW decision for the dev pass,
  constrained only by the existing `src/state/` exclusion (unaffected, this story touches no
  `src/state/` file) and by AC 4's round-trip requirement, not by a filename pinned here.
- `src/ui/debug/debug_instrument_panel.gd` — gains the three start/stop/load controls, in-code,
  following the existing two-`CheckButton` pattern (AC 6). No new `.tscn`, no new top-level `Control`.
- `src/main/match_runner.gd` — gains the live-reload trigger's call site (AC 2) and whatever plumbing
  connects the panel's new controls to the recorder/replay-staging state; does NOT touch the
  intent-tap seat, the `ticking` gate, or the seven `connect_*` seams (AC 8, AC 9).
- `src/state/` — touched by NOTHING in this story, same guarantee `3-0c` shipped (AC 8, the token-scan
  pin).
- `project.godot` — untouched (AC 6; no Input Map action added).

## Project Context Rules

- **Seeded RNG consumed only inside `advance()`; no bare global RNG in `src/state/`.** [Source:
  docs/project-context.md#Critical Implementation Rules, line 54] — unaffected; this story adds no
  RNG consumer.
- **Replay is sound only if every non-input source of variation is captured; the seed is recorded
  with the intent stream; balance-reload events are recorded, not ignored.** [Source:
  docs/game-architecture.md#Determinism & Replay (validation F2 + X3/X5 reconciliation)] — this
  story is what finally lets a HUMAN trigger the reload event this rule already requires be captured.
- **`Input.*` may appear only under `src/controllers/`.** [Source: docs/project-context.md#Critical
  Implementation Rules; D3(a)] — this story adds no controller code and no Input Map action.

## References

- [Source: decision-log.md — DEBT B, original definition and both-halves-together rule, lines 130-133]
- [Source: decision-log.md — Session 2026-08-04, Story 3-0c readiness gate, `3-0c/R5` (the split;
  what `3-0d` inherits, lines 3685-3699)]
- [Source: decision-log.md — 3-0c close-out, "DEBT B's STREAM HALF IS NOW CLOSED" (lines 3952-3955)]
- [Source: decision-log.md — R-D6 history: `3-4` spend (2343/2346), `3-5a` re-invocation/spend (3191),
  `3-5b` non-re-invocation (3338/3604), `3-0c` non-re-invocation (3796/3960)]
- [Source: docs/implementation-artifacts/3-0c-intent-recorder.md — the model for this file's shape;
  AC 1/2/4/9's channel and seat definitions this story reuses without modification]
- [Source: docs/implementation-artifacts/sprint-status.yaml — `story_notes.3-0d-replay-surface-and-
  live-reload` (the board-slot note this file's contract is drawn from)]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md — line 95, the locked order
  that does not mention this story]
- Note: `stories-manual-e3.md` contains no mention of this story, X5, replay, or DEBT B by content
  search.
- [Source: docs/game-architecture.md — line 579 (`src/ui/debug/` record/replay start-stop-load
  annotation), lines 920-925 (X3/X5 reconciliation) — PRE-CODE TEXT per `3-0c/R10`, candidate design
  rather than authority]

## Golden Prediction

**Baseline, re-derived at write time from the `GOLDEN` constant in `test/state/test_determinism.gd`
(HEAD `bb2a58c`):** `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`.

**Prediction: NONE.** Both premises argued:

1. **No snapshot key.** This story's surface is `src/systems/` (the `BalanceConfigService` cache fix,
   whatever save/load helper lands), `src/ui/debug/` (the panel controls), and `src/main/
   match_runner.gd` (the trigger call site and control wiring) — none of it is `src/state/`, so
   nothing here is reachable from `MatchState.to_snapshot()`. `DebugInstrumentPanel`'s existing
   pattern (a Control fed plain values, never holding a state handle) is the precedent the new
   controls follow.
2. **No seeded-RNG consumer.** Neither the cache fix, the trigger, nor the save/load round-trip draws
   randomness. F2's two-site guard (`shuffle_with_rng(` in `deck.gd` plus its one `MatchState`
   caller) must still read exactly two after this story.

**If the save/load format (AC 4) needs a helper method added to `IntentRecorder` that also happens to
change what `_resource_values`/`_apply_values` touch, or if the dev pass finds itself needing a new
snapshot-adjacent field to make the live trigger observable in the UI, this prediction is INVALID and
must be rewritten before the work continues** — the same discipline `3-0c`'s Golden Prediction states
for itself.

## Live Smoke

**REQUIRED — this is the part of the X5 work that has a live surface; `3-0c` correctly owed none.**
On the shipped default (`slot_controller_kinds = [KEYBOARD_P1, KEYBOARD_P2]`, verified by content at
`match_runner.gd:31-34` — two live, keyboard-driven, killable human slots, no `.tscn` edit needed):

- Start a recording from the `DebugInstrumentPanel`'s new control; play a short live round (movement,
  at least one attack/contact, at least one card cast) on both slots.
- Trigger a live mid-match balance reload from the panel; observe (and name, not silently accept) the
  visible stamina refill described in AC 7 / Open Question (e).
- Stop the recording; save it to `user://` from the panel; confirm the file exists on disk.
- Load the saved recording back (however AC 4's round-trip is wired at runtime — see Open Question
  (f) on whether "load" can re-enter replay mid-session at all) and confirm the replay reaches the
  same `CanonicalHash` as the live run — the "play a round, save the file, replay it to a bit-
  identical hash" payoff this story exists to deliver.
- `R-D6`'s re-invocation is Open Question (c) — not assumed here either way.

## Open Questions

Left open for the readiness gate; none resolved by this pass.

a) **Recording lifetime across a debug reset.** AC 5 pins that `start()` discards a prior record, but
   says nothing about what a mid-recording `debug_reset` (`p1_debug_reset`/`p2_debug_reset`,
   `match_state.gd:175-176`, `_apply_debug_reset`) does to an ACTIVE recording — does the reset ride
   inside the same record as an ordinary tick (since it travels through `InputIntent.debug_reset`,
   already an existing captured field), or does starting a new round imply a new recording boundary?
b) **The `user://` path and record format** — whether the on-disk shape should be pinned by an AC at
   all (AC 4 deliberately does not), or left free until it has a second consumer beyond this story's
   own load control.
c) **Does this story's live smoke re-invoke the `R-D6` smoke acceptance?** Corrected finding (Dev
   Notes above): it was last spent at `3-5a`, not `3-4` as an earlier framing of this question assumed;
   `3-5b` explicitly left the re-invocation question to `3-6`. Whether `3-0d`'s own live-observable
   surface re-invokes it, or whether it stays reserved for `3-6`, is for this story's own gate to rule.
d) **Loading an OLD recording against a CHANGED `CardDatabase`.** `3-0c`'s AC 5/AC 6 already capture
   deck composition and cast costs BY VALUE, so a replay does not read `CardDatabase` at all — but
   nothing detects, refuses, or versions a recording made against a card set that no longer exists.
   Detect, refuse, version, or ignore is undecided.
e) **The visible stamina refill on a live reload** (AC 7, Dev Notes). Whether this is acceptable
   player-facing behavior, or whether a future story should give reload a "preserve current pool
   fraction" option, is not decided here.
f) **Whether "load" can re-enter replay mode at all without new runner machinery.** `replay_record`
   is consulted exactly once, in `_ready()`, before the scene ever ticks (`match_runner.gd:105-109`),
   and no scene-reload mechanism exists anywhere in `src/` (verified by content search). A "load"
   control clicked mid-session cannot swap the live match into replay under the architecture as
   shipped — the gate must decide whether AC 4's round-trip is proven by a HEADLESS load-then-replay
   test only (sidestepping this gap), or whether "load" additionally needs a scene-restart/new-runner
   path that does not exist today and would be new scope.

## Dev Agent Record

### Agent Model Used

(not yet dev-passed — story is `backlog`)

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-05 | 0.1 | File authored at this story's own creation pass, per the `3-0a`/`3-0b`/`3-0c` precedent and `3-0c/R5`'s split ruling. Nine ACs recorded, each mapping to one of the six inherited scope items (CACHE_MODE_IGNORE; the live reload trigger reusing the existing reload channel; `user://` persistence with the format deliberately unpinned; recording start/stop lifecycle; the panel controls with no new Input Map action; the live smoke) or explicitly declared discharged by a non-AC section with a reason (the live smoke itself, discharged by the required Live Smoke section rather than a numbered AC, matching this repo's own convention for every prior story). Every quoted string re-verified against shipped code or the decision log at write time; the commissioning brief's R-D6 claim ("spent on 3-4") is corrected — the more recent spend was `3-5a`. A structural gap not previously named anywhere is surfaced: `replay_record` is read once in `_ready()`, before the scene ticks, and no scene-reload mechanism exists in `src/`, so a mid-session "load" control has no runtime path into replay under the shipped architecture (Open Question (f)). Six Open Questions left open, none resolved. Golden Prediction NONE, argued on the same two premises `3-0c` used (no snapshot key; no seeded-RNG consumer). Live Smoke REQUIRED, described on the shipped two-keyboard default, no `.tscn` edit needed. Status `backlog`; promotion to `ready-for-dev` deferred to this story's own readiness gate. Nothing under `src/` or `test/` is touched by this pass — docs only. | Claude Sonnet 5 |
