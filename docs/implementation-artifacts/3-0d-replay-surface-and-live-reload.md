# Story 3.0d: Replay surface and live reload — the operator half of X5 + DEBT B's cache half

Status: ready-for-dev

> **Readiness gate, 2026-08-05 — outcome applied to this file.** The gate returned NOT READY with
> five blocking findings (an unshippable mid-match "start recording" control; a "load" control with
> no correct runtime path and a wrong stated reason; a Live Smoke payoff step no operator can
> perform; an AC forcing a permanent test to mutate a tracked authored `.tres`; and a process-only
> AC with no falsifying mechanism). All five are ruled and applied here as `3-0d/R1`-`3-0d/R12`
> (decision-log, Session 2026-08-05 — Story 3-0d readiness gate). **All six Open Questions are now
> ruled**, and that section is DELETED — the `3-0c` precedent — with each ruling's substance carried
> into the AC or Dev Note that now owns it. AC count 9 -> 11. Status promoted to `ready-for-dev`.
>
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
one-button SAVE that writes the always-on record of the round I am playing out to `user://`, a
headless verifier that replays a saved file back to a bit-identical `CanonicalHash`, and the
`BalanceConfigService` cache bug fixed so a reload actually re-reads the `.tres` —
so that I can tune balance without restarting the game and trust that a played-and-saved round
replays deterministically, closing DEBT B entirely and giving X5's stream contract its first live,
human-operable surface.

**What this story deliberately does NOT ship, and why (`3-0d/R1`, `3-0d/R2`).** There is no START
control: recording is implicit and always-on from tick 0, because a record begun at tick 500 has
nothing to replay — a replay is built from `MatchState.new()` forward and no state-restore snapshot
exists, so a mid-match start is not forbidden, it is *meaningless*. There is no LOAD control either:
entering replay requires assigning `replay_record` before the runner enters the tree, and a scene-
reload mechanism was CONSIDERED AND REJECTED (new architecture, and it collides with the ratified
scope line "record + replay only — no rewind, no scrubbing UI", `3-0c/R10`). The payoff moves to a
headless verifier under `test/`, which is also what legitimately gives it `CanonicalHash`.

## Acceptance Criteria

1. **`BalanceConfigService.reload()` bypasses the resource cache — DEBT B's cache half, proven BY
   OBJECT IDENTITY (`3-0d/R5`).** Verified by content, the shipped body
   (`src/systems/balance_config_service.gd:27`) is `_config = load(CONFIG_PATH) as BalanceConfig` — a
   plain `load()`, which returns the cached resource on every call after the first, so a mid-session
   edit to the on-disk `.tres` is silently ignored (decision-log:130: "on-disk hot-reload is a no-op
   without `CACHE_MODE_IGNORE`"). `reload()` is changed to `ResourceLoader.load(CONFIG_PATH, "",
   ResourceLoader.CACHE_MODE_IGNORE) as BalanceConfig`. **The proof is reference identity, not a file
   edit:** a test calls `reload()` twice and asserts the two `get_config()` results are DIFFERENT
   object references carrying EQUAL values, and that a plain `load(CONFIG_PATH)` returns the SAME
   reference twice — so the assertion falls the moment the call reverts to `load()`. **Measured on
   this engine before this AC was written** (Godot 4.6.3, the shipped `data/balance/
   balance_config.tres`): plain `load()` twice -> same instance; `CACHE_MODE_IGNORE` twice ->
   different instances, equal values; `CACHE_MODE_IGNORE` vs the cached instance -> different. **Zero
   file mutation, zero new API on the autoload.** The test goes in the **STATE harness**, not
   integration: `test/state/test_balance_config.gd:88-89` already instantiates the service SCRIPT as a
   plain `Node` and calls `reload()` on it, so no autoload is required and the E0 harness constraint
   is honoured, not worked around.
2. **A live mid-match reload calls `apply_balance()` a second time and enters the SAME reload
   channel `3-0c` already shipped — no second injection path.** The trigger calls
   `BalanceConfigService.reload()` then `MatchState.apply_balance(BalanceConfigService.get_config())`
   exactly as the match-start call does (`match_runner.gd:128-133`), and — **unconditionally when not
   replaying, since recording is always-on (AC 6) and there is no "is a recording active" state to
   branch on** — the SAME call also reaches `IntentRecorder.capture_apply_balance()` first, so the
   live reload becomes reload event N on the existing channel, in the existing `{"tick": int,
   "values": Dictionary}` shape (`intent_recorder.gd:97-99`). A test drives a live-shaped `MatchState` +
   `IntentRecorder` pair through match start plus one live trigger and asserts
   `reload_event_count() == 2`, with event index 1's captured tick matching the trigger point.
3. **`IntentRecorder` gains NO new channel.** It ships exactly eight `capture_*` methods today —
   measured by content (`capture_seed`, `capture_apply_balance`, `capture_inject_feature_flags`,
   `capture_inject_deck`, `capture_inject_card_costs`, `capture_set_camera_basis`,
   `capture_push_contact`, `capture_advance`) — and this story adds none: the live reload trigger
   (AC 2) is a second CALL to the existing `capture_apply_balance`, not a new method. A structural
   test counts `func capture_` occurrences in `intent_recorder.gd` and asserts exactly eight,
   proving a ninth would be a scope violation this test catches.
4. **A record saved to `user://` and loaded back replays to the same `CanonicalHash` as replaying the
   original in-memory record.** This is the AC 10 / `3-0c` identity shape, driven twice — once from
   the in-memory `IntentRecorder` and once from an `IntentRecorder` reconstructed by loading the saved
   file — and asserting the two replays hash identically. Breaking the save/load round-trip is what
   makes this AC falsifiable.
5. **The on-disk record carries a FORMAT VERSION int, and a record whose version does not match is
   REFUSED with a clear reason rather than replayed (`3-0d/R7`).** A test writes a record, rewrites
   only its version field to an unknown value, and asserts the load path refuses it and says why; the
   same test asserts a matching version loads. This is the ONE element of the on-disk shape this
   story pins — everything else about byte layout, key naming and file extension stays deliberately
   unpinned (rationale in Dev Notes).
6. **Recording is ALWAYS-ON from tick 0: the record covers the match from its first tick and is never
   restarted mid-match (`3-0d/R1`).** Verified by content, `match_runner.gd:566` already calls
   `_recorder.capture_advance(intents)` on every ticking frame in the non-replay (`else`) branch, and
   `_recorder` is never reassigned — so this AC ships NO start control and NO reset of the recorder.
   A test drives a live-shaped runner-equivalent pair for N ticks, saves, drives M more, saves again,
   and asserts the second file's tick count is `N + M` and its first tick is tick 1 — proving the
   record is cumulative from tick 0 rather than restarted by the SAVE. **A mid-match start is not
   merely out of scope, it is meaningless, and a naive one is unshippable** — see Dev Notes.
7. **The `DebugInstrumentPanel` (`src/ui/debug/debug_instrument_panel.gd`) gains EXACTLY ONE new
   control: SAVE (`3-0d/R2`).** It writes the record so far to `user://`, and RECORDING CONTINUES
   AFTERWARDS — SAVE is a snapshot of an always-on stream, not a stop. It follows the panel's own
   in-code `CheckButton`/`Button` pattern (verified by content: two `CheckButton`s built directly in
   `_ready()`, no `.tscn`) — no new top-level `Control`, no new `.tscn`, and NO Input Map action.
   **There is no start control and no load control.** A structural test counts the panel's
   runner-reaching controls and asserts exactly one, so a second (a "load" in particular) fails here.
   `test_shipped_input_map_action_set_is_exactly_pinned` (`test/state/test_deck_and_hand.gd:439`)
   stays green UNMOVED — the project's **30**-action set (MEASURED at this gate from
   `SHIPPED_INPUT_ACTIONS`, `test_deck_and_hand.gd:428-436`: 2 `debug_*` + 14 `p1_*` + 14 `p2_*`;
   the "28" this file previously carried was wrong) gains nothing, proving the control is mouse-only
   exactly as the panel's existing two switches are. A test invokes the control's signal handler
   programmatically (the existing panel's own test pattern) and asserts a file appears at the
   expected `user://` path.
8. **A HEADLESS VERIFIER under `test/` loads a record from `user://` and replays it, standalone
   (`3-0d/R3`).** A script runnable as `godot --headless --path . --script res://test/tools/
   replay_file.gd -- <path>` — the `extends SceneTree` + `_initialize()` form every script under
   `test/integration/` already uses (verified by content, e.g. `test_replay_contacts.gd:1,65`, run by
   `test/run_all.sh:27` in exactly this shape). It replays the loaded record to completion and prints
   its `CanonicalHash`; run twice on the same file it prints the same hash. **Living in test space is
   what legitimately gives it `CanonicalHash`** (`test/canonical_hash.gd` is a test-harness class;
   nothing under `src/` computes or displays a canonical hash — verified by content, the only
   `CanonicalHash` occurrences in `src/` are two comments, `discard_pile.gd:9` and
   `match_state.gd:137`). **CONSEQUENCE:** the Input Map pin's assertion message — "replay reachable
   only from a test, never from a key" (`test_deck_and_hand.gd:451-452`) — stays TRUE after this
   story, so it needs no edit.
9. **This story does not add pool-specific gating to a live reload — the shipped per-pool contract
   (`MatchState._apply_balance_to_player`, `match_state.gd:1116-1130`) is exercised UNCHANGED by the
   live trigger.** Verified by content: stamina receives `set_maximum` **and** `refill()` on every
   `apply_balance()` call, including reloads (D9, `test_mid_match_reload_refills_stamina_to_max`);
   mana receives `set_maximum` only, never refilled; hp is `set_max_hp` plus a `heal()` gated to
   `first_injection` only. A test applies a live reload mid-match with stamina below max and asserts
   it refills to the new maximum exactly as the existing 1-4 reload test proves for `apply_balance()`
   generally — proving the live trigger is a genuine call to the same seam, not a special-cased
   partial reload. The visible stamina refill this produces is RATIFIED AS CORRECT (`3-0d/R10`), not
   tolerated — rationale in Dev Notes.
10. **Every pin `3-0c` shipped stays green, UNCHANGED, and none is edited by this story:**
    `test_runner_observation_seams_are_exactly_seven` (`test_architecture_invariants.gd:284`, the
    seven-`connect_*` count), `test_unhashed_cross_tick_state_is_exactly_three_members`
    (`test_replay_identity.gd:265`, the three-member exclusion pin), `test_every_match_state_intake_
    has_a_capture_channel` (`test_intent_recorder.gd:52`, the channel-derivation guard), and
    `test_state_layer_never_names_the_recorder_or_the_replay_controller`
    (`test_architecture_invariants.gd:231`, the `src/state/` token scan). This story's persistence and
    trigger code lives in `src/systems/` and/or `src/ui/debug/`, never `src/state/`, and adds no
    `connect_*` seam and no unhashed cross-tick member — proven by these four tests requiring zero
    edits.
11. **The passive-tap seat `3-0c` shipped is not relocated, and `replay_record` is never assigned
    mid-session — BOTH PINNED BY A SOURCE SCAN (`3-0d/R6`).** `IntentRecorder.capture_advance(intents)`
    stays seated immediately before `_match_state.advance(intents)`, inside the `ticking` gate
    (`match_runner.gd:566-568`); this story adds a second `apply_balance()` call site (AC 2) but does
    not touch the intent-tap seat, the `ticking` gate, or `_physics_process`'s structure (F1
    untouched). **A process promise is not an AC**, so this ships a real falsifying mechanism: a new
    source scan over `match_runner.gd` asserting (a) `capture_advance` appears exactly once and the
    next non-comment statement after it is `_match_state.advance(`, and (b) **`replay_record` is
    assigned NOWHERE in `src/`** — MEASURED at this gate: the token appears in `src/` only as the
    declaration (`match_runner.gd:69`) and as READS (105-108, 113, 128, 140, 161, 536-540), and its
    one assignment in the whole tree is external and pre-tree
    (`test/integration/test_replay_contacts.gd:80`). That second half is the single structural trace
    the rejected "load" control leaves in the code: a mid-session `replay_record = ...` would fail
    this scan. **Correction of record:** the gate's phrasing for (b) was "assigned only in
    `_ready()`"; the tree carries no assignment in `_ready()` at all — `_ready()` READS it — so the
    scan lands in its stricter, accurate form above. Today no `capture_advance` call in `test/`
    touches the runner's seat (all hits drive a recorder directly: `test_intent_recorder.gd:117`,
    `test_replay_identity.gd:359`, `test_replay_contacts.gd:118`), which is exactly why moving the
    seat currently breaks nothing.

## Tasks / Subtasks

- [ ] `ResourceLoader.load(..., CACHE_MODE_IGNORE)` in `BalanceConfigService.reload()`; the
      object-identity test in the STATE harness, no file mutation (AC: 1)
- [ ] Live reload trigger calling `reload()` -> `apply_balance()`, routed through
      `capture_apply_balance()` (AC: 2, 3, 11)
- [ ] `user://` save/load round-trip for an `IntentRecorder` record; identity test against the AC 10
      shape (AC: 4)
- [ ] Format version int in the written record + refusal on mismatch, both directions (AC: 5)
- [ ] Always-on recording proof: SAVE does not reset the record; cumulative from tick 0 (AC: 6)
- [ ] ONE new `DebugInstrumentPanel` control — SAVE. No start, no load, no new Input Map action;
      exact-equality pin unmoved at 30 actions; the one-control structural test (AC: 7)
- [ ] `test/tools/replay_file.gd` — the standalone headless verifier, `extends SceneTree`, prints the
      replayed record's `CanonicalHash` (AC: 8)
- [ ] Per-pool live-reload proof against the unchanged `_apply_balance_to_player` contract (AC: 9)
- [ ] Confirm the four inherited `3-0c` pins require zero edits (AC: 10)
- [ ] The `match_runner.gd` source scan: tap seat + `replay_record` never assigned in `src/` (AC: 11)
- [ ] Live smoke on the shipped two-keyboard default, including the R-D6 kill (see Live Smoke)

## Dev Notes

- **`BalanceConfigService`'s full current body**, verified by content
  (`src/systems/balance_config_service.gd`): an autoload; `_ready()` calls `reload()`; `reload()` is
  `_config = load(CONFIG_PATH) as BalanceConfig` guarded by `ResourceLoader.exists`.
  ~~`reload()` has exactly ONE caller in the whole tree today (its own `_ready()`).~~ **CORRECTED AT
  THE READINESS GATE, measured by content: `reload()` has TWO callers — its own `_ready()`
  (`balance_config_service.gd:19`) and `test/state/test_balance_config.gd:89`, which instantiates the
  service SCRIPT as a plain `Node` and calls `reload()` on it.** This story gives it a THIRD caller,
  the live trigger (AC 2). **Provenance of the error, recorded rather than hidden:** the "exactly ONE
  caller" claim was INHERITED VERBATIM from the closed story file
  `docs/implementation-artifacts/3-0c-intent-recorder.md:174`, where it is equally wrong. That file is
  CLOSED and is NOT edited by this pass; the correction lives here and in the decision log
  (`3-0d/R5`). The error was load-bearing: it is what made the old AC 1 reach for an on-disk `.tres`
  mutation, on the false premise that the state harness could not reach the service.
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
  ~~start/stop/load is~~ **SAVE (the ONE control this story ships, `3-0d/R2`) is** the first control
  here that must reach back to the runner's recorder state, which needs either a runner-owned
  `Callable`/reference handed to the panel at construction (the `gamepad_profile`/`huds` precedent,
  generalized) or a signal the runner connects to — a HOW decision left to the dev pass, not fixed
  here. That "exactly one runner-reaching control" is itself the shape AC 7's structural test counts,
  which is what keeps a load control from being added back quietly.
- **The Input Map pin, verified by content** (`test/state/test_deck_and_hand.gd:428-452`):
  ~~28 actions (`debug_pause`, `debug_step`, 13 `p1_*`, 13 `p2_*`)~~ **CORRECTED — RE-MEASURED AT THE
  READINESS GATE from `SHIPPED_INPUT_ACTIONS` itself: 30 actions = 2 `debug_*` (`debug_pause`,
  `debug_step`) + 14 `p1_*` + 14 `p2_*`.** Each player's fourteen are: `attack`, `block`, `card_1`,
  `card_2`, `card_3`, `card_4`, `cast_confirm`, `cast_mode`, `debug_reset`, `move_down`, `move_left`,
  `move_right`, `move_up`, `roll` (`test_deck_and_hand.gd:430-435`). Asserted by exact set equality
  against `InputMap.get_actions()` filtered of Godot's `ui_*` built-ins. The assertion message names
  `3-0c` by name and says its "replay mode is reachable only from a test, never from a key"
  (`test_deck_and_hand.gd:451-452`) — **that message STAYS TRUE after this story and needs no edit**,
  because `3-0d`'s replay path is the headless verifier under `test/` (AC 8), not a key and not a
  panel control. This story ships the panel's SAVE control with the same guarantee: mouse-only,
  `project.godot` untouched, this test unmoved.
- **The per-pool reload contract, verified by content** (`match_state.gd:1116-1130`,
  `_apply_balance_to_player`): `player.hero.set_max_hp(config.max_hp)`; `if first_injection:
  player.hero.heal(config.max_hp)`; `player.hero.move_speed = config.move_speed`;
  `player.stamina.set_maximum(config.max_stamina)` then **unconditionally** `player.stamina.refill()`
  with a comment naming this exact fact ("every `apply_balance`, reload included
  (`test_mid_match_reload_refills_stamina_to_max`)"); `player.mana.set_maximum(config.max_mana)` with
  no refill call at all. **Consequence, stated plainly:** a live reload mid-match will visibly top up
  stamina to whatever the new maximum is, even if the operator only meant to retune, say, attack
  timing. This story does not change that behavior (AC 9) — it only gives it its first live
  exercise, since every prior reload was either match-start (stamina already full) or a headless
  test. **Ruled at the gate (`3-0d/R10`): that refill is CORRECT, not a defect** — see the ratifying
  bullet below.
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
  AVAILABLE"). **State at this gate: AVAILABLE, last spent `3-5a`.** ~~Whether THIS story's live
  smoke re-invokes it is left open.~~ **RULED (`3-0d/R11`): R-D6 IS RE-INVOKED AND IS SPENT ON THIS
  STORY'S SMOKE.** The smoke is live against the shipped two killable human slots
  (`slot_controller_kinds = [KEYBOARD_P1, KEYBOARD_P2]`, verified by content at
  `match_runner.gd:31-34`) and already involves combat, so the kill is nearly free. It is recorded in
  the Live Smoke section as a REQUIRED observation, not an optional one. After this story R-D6 is
  SPENT again and any later story wanting a live smoke against a killable human-driven slot must
  re-invoke it at its own gate (the standing rule, decision-log:456/530).
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
- **A structural gap this story's own reading surfaces, CORRECTED AT THE READINESS GATE (`3-0d/R2`).**
  ~~`3-0c`'s `replay_record` is read exactly once, in `_ready()` (`match_runner.gd:105-109`), BEFORE
  the runner node ever enters the tree or ticks.~~ **That claim is FALSE and was the story's stated
  reason for believing a mid-session "load" would be harmlessly inert. Measured by content,
  `replay_record` is read in TWO places: `_ready()` (lines 105-108, 113, 128, 140, 161 — where the
  slot controllers are constructed and the whole match is built from the record) AND EVERY TICK in
  `_physics_process`, at the `if replay_record != null` fork (lines 536-540), which drives
  `replay_apply_reloads_before` / `replay_push_camera_bases` / `replay_push_contacts`.** The
  consequence is the opposite of inert: assigning `replay_record` mid-session **injects tick-1
  recorded reloads, camera bases and contacts into a live mid-match state while both controllers are
  still live keyboards**, and it **silently stops recording**, because `capture_advance` lives in the
  `else` branch (line 566) that the fork now skips. The naive implementation looks harmless and
  corrupts the running match. **What remains true from the original bullet:** no code in `src/`
  assigns `replay_record` (its one assignment is external and pre-tree,
  `test/integration/test_replay_contacts.gd:80`), and no scene-reload or restart mechanism exists in
  `src/` at all (`reload_current_scene`/`change_scene` appear nowhere in `src/`). **Ruling: LOAD IS
  NOT A LIVE CONTROL** — the panel gains SAVE only (AC 7), the round-trip payoff moves to the headless
  verifier (AC 8), and the fact that nothing in `src/` assigns `replay_record` becomes a pinned source
  scan (AC 11) rather than an observation.
- **Why there is no START control either (`3-0d/R1`) — the deeper reason, which is not scope
  discipline but meaninglessness.** A naive mid-match start is first of all UNSHIPPABLE:
  `capture_advance()` asserts `has_complete_match_start()` on its first captured tick
  (`intent_recorder.gd:161-166`), and the five required channels — seed, reload event #0, feature
  flags, deck composition, cast costs — are captured ONLY inside the runner's `_ready()`, each behind
  `if not replaying` (`match_runner.gd:115, 132, 144, 165, 171`). A start that discarded the record
  mid-match would leave all five empty and trip the invariant on the very next tick. But even a
  version that somehow re-captured them would be pointless: **a replay is built from
  `MatchState.new()` forward and no state-restore snapshot exists anywhere**, so a record beginning at
  tick 500 has nothing to replay. A mid-match start is not forbidden — it is meaningless. Recording is
  therefore implicit and always-on from tick 0, which the shipped code ALREADY does: the runner calls
  `_recorder.capture_advance(intents)` on every ticking frame in the non-replay branch
  (`match_runner.gd:566`), and `_recorder` is never reassigned (verified by content). AC 6 pins that
  property; SAVE (AC 7) snapshots the stream without interrupting it.
- **The headless verifier's form, taken from the repo's own working pattern (`3-0d/R3`).** Every
  standalone script in `test/integration/` is `extends SceneTree` with an `_initialize()` entry point,
  run as `godot --headless --path . --script res://test/integration/test_X.gd` — the exact invocation
  `test/run_all.sh:27` uses and `test_replay_contacts.gd:33` documents in its own header. `test/tools/
  replay_file.gd` follows it and takes the record path as a command-line argument. **Note on suite
  membership:** `run_all.sh:24` globs `test/integration/test_*.gd`, so a file under `test/tools/` with
  a non-`test_` name is deliberately NOT auto-run by the suite — correct for an operator tool whose
  input is a file the operator produced by playing, and the reason AC 8's own regression coverage is
  the AC 4 round-trip test (which lives in the suite) rather than the verifier itself.
- **Why the round-trip payoff cannot be observed at the game, and where it moved (`3-0d/R4`).**
  `CanonicalHash` is `test/canonical_hash.gd` — a test-harness class. **Nothing under `src/` computes
  or displays a canonical hash**: verified by content, the only two `CanonicalHash` occurrences in
  `src/` are prose in comments (`discard_pile.gd:9`, `match_state.gd:137`). So the old Live Smoke step
  "confirm the replay reaches the same `CanonicalHash` as the live run" asked an operator at the game
  to confirm something the game does not and will not display. The smoke payoff is reformulated to
  what is actually provable there and what AC 4 does not cover — **a record produced by a REAL PLAYED
  ROUND, not a synthetic fixture, exists on disk, is structurally complete, and replays headlessly to
  completion and TWICE to the same hash.** AC 4 proves round-trip FIDELITY on a fixture; the smoke
  proves the LIVE RUNNER emits a well-formed file. They are different claims and neither subsumes the
  other.
- **Why AC 1 no longer mutates the authored `.tres` (`3-0d/R5`), and the rule that forbade it.** The
  original AC 1 required a permanent test to edit `data/balance/balance_config.tres` between two
  `reload()` calls. `CONFIG_PATH` is a hardcoded `const` with no path seam
  (`balance_config_service.gd:13`), the file is tracked, and other tests read it too — including
  `test/integration/test_contact_pipeline.gd:73` and `test/state/test_balance_authoring.gd:37`. That
  collides head-on with the repo's **PERMANENT RULE (decision-log:799)**: "During an uncommitted dev
  pass, a mutation made to prove a guard non-vacuous is restored from a copy taken OUTSIDE the repo,
  NEVER with `git checkout -- <file>`." A permanently re-running test that mutates a tracked authored
  file is strictly worse than the one-off dev-pass mutation that rule was written for — there is no
  "restore" step in a test that runs on every suite invocation. The object-identity form (AC 1) proves
  the same thing with zero file mutation and zero new API on the autoload.
- **The on-disk format stays UNPINNED except for the version int (`3-0d/R7`).** This closes the
  question of whether the format should be pinned by an AC at all. Pinning byte layout, key naming or
  extension would freeze a shape that has exactly one consumer today; the falsifiable claim worth
  having is the ROUND TRIP (AC 4). The one mandatory element is a **format version int with a clear
  refusal on mismatch** (AC 5), which is what makes schema evolution safe without pinning the schema.
- **Loading an OLD record against a CHANGED `CardDatabase` is CLOSED BY CONSTRUCTION (`3-0d/R8`),
  verified against the code.** A replay drives the INJECTED deck composition and the INJECTED cost
  map and never reads `CardDatabase`: the two `_derive_*` helpers that touch the autoload
  (`match_runner.gd:296-303` and its deck counterpart) sit inside the `else` (non-replaying) branch of
  `_ready()` (lines 163-172), and `intent_recorder.gd`'s own header states the recorder is
  "CONTENT-BLIND BY CONSTRUCTION: ... no `CardDatabase`". A card re-priced or deleted after a
  recording therefore cannot change what the replay pays or draws. The version field (AC 5) covers
  schema evolution; there is nothing further to detect or refuse.
- **A debug reset does NOT bound a recording (`3-0d/R9`).** Reset is ROUND-scoped, not match-scoped:
  `_apply_debug_reset()` (`match_state.gd:1166-1169`) clears `_round_over` and resets both players,
  and it is reached from inside `advance()` (`match_state.gd:175-176`) off the `debug_reset` field of
  an ordinary `InputIntent`. That field is one of the eight captured verbatim per tick
  (`intent_recorder.gd:336`, `copy_intent`). So a reset rides inside the record as an ordinary tick
  and a record spans it intact — no recording boundary, no special case, nothing for AC 6 to carve out.
- **The visible stamina refill on a live reload is RATIFIED AS CORRECT (`3-0d/R10`), not tolerated.**
  It is the per-pool `apply_balance` contract — stamina `set_maximum` **and** unconditional `refill()`
  on every apply (`match_state.gd:1116-1130`) — becoming live-observable for the first time, because
  every prior reload was either match-start (stamina already full) or headless. It is not a bug and
  the smoke observes it as EXPECTED. Changing it would be a change to `apply_balance` SEMANTICS and
  needs its own story; this one does not open that question.
- **Architecture divergence, queued not edited (`3-0d/R12`).** `docs/game-architecture.md:578-579`
  annotates `src/ui/debug/` with "record/replay start-stop-load" while this story ships SAVE-only,
  with no load control and no start control. That is a genuine divergence between the doc and shipped
  code, and it becomes a member of the architecture-amendment queue. **Queue size counted by content
  at this gate, not taken on trust:** the queue held TEN — five at `3-4/R4`, a sixth at the 3-2 gate,
  a seventh at the 3-3 gate close-out, an eighth at `3-5/R9`, a ninth at `3-0c/R10`, a tenth at
  `3-0c/R14` (decision-log:3767-3769 and 3910-3913) — so this story's divergence is the **ELEVENTH**.
  `docs/game-architecture.md` is NOT edited by this pass; the queue flushes at the E3 close-out,
  forcing point unchanged.

## Project Structure Notes

- `src/systems/balance_config_service.gd` — `reload()`'s `load()` call becomes a `ResourceLoader.load
  (..., CACHE_MODE_IGNORE)` call (AC 1). No new file.
- `src/systems/intent_recorder.gd` — gains NO new `capture_*` method (AC 3); the save/load round-trip
  (AC 4) needs a to-dict/from-dict shape somewhere — whether that lives as new methods on
  `IntentRecorder` itself or a sibling file under `src/systems/` is a HOW decision for the dev pass,
  constrained only by the existing `src/state/` exclusion (unaffected, this story touches no
  `src/state/` file) and by AC 4's round-trip requirement, not by a filename pinned here.
- `src/ui/debug/debug_instrument_panel.gd` — gains EXACTLY ONE new control, SAVE, in-code, following
  the existing two-`CheckButton` pattern (AC 7). No start control, no load control, no new `.tscn`, no
  new top-level `Control`.
- `test/tools/replay_file.gd` — NEW: the standalone headless verifier (AC 8), `extends SceneTree` on
  the `test/integration/` pattern, taking a `user://` record path as a command-line argument. Under
  `test/` deliberately — that is what gives it `CanonicalHash`. Not globbed by `run_all.sh`.
- `src/main/match_runner.gd` — gains the live-reload trigger's call site (AC 2) and whatever plumbing
  connects the panel's SAVE control to the recorder; does NOT touch the intent-tap seat, the `ticking`
  gate, the seven `connect_*` seams, or `replay_record` (AC 10, AC 11).
- `src/state/` — touched by NOTHING in this story, same guarantee `3-0c` shipped (AC 10, the
  token-scan pin).
- `project.godot` — untouched (AC 7; no Input Map action added).

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
  what `3-0d` inherits, **lines 3682-3699** — re-anchored at this gate by locating the ruling's
  heading text; the previously cited 3685 pointed into the middle of the paragraph)]
- [Source: decision-log.md — the PERMANENT RULE on restoring a mutation from an out-of-repo copy,
  line 799 — the rule the old AC 1 collided with (`3-0d/R5`)]
- [Source: decision-log.md — architecture-amendment queue size, lines 3767-3769 (`3-0c/R10`, NINTH)
  and 3910-3913 (`3-0c/R14`, TENTH) — the count this story's ELEVENTH member is measured against]
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
- [Source: docs/game-architecture.md — **lines 578-579** (the `src/ui/debug/` annotation; the
  "record/replay start-stop-load" phrase sits on 579 but the annotation it belongs to opens on 578 —
  re-anchored at this gate by locating the content), lines 920-925 (X3/X5 reconciliation) — PRE-CODE
  TEXT per `3-0c/R10`, candidate design rather than authority. The 578-579 line is the ELEVENTH
  architecture-amendment queue member (`3-0d/R12`); the doc is NOT edited by this story.]

## Golden Prediction

**Baseline, re-derived at write time from the `GOLDEN` constant in `test/state/test_determinism.gd`
(HEAD `bb2a58c`):** `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`.

**Prediction: NONE.** Both premises argued:

1. **No snapshot key.** This story's surface is `src/systems/` (the `BalanceConfigService` cache fix,
   whatever save/load helper lands), `src/ui/debug/` (the SAVE control), `src/main/match_runner.gd`
   (the trigger call site and control wiring), and `test/tools/` (the headless verifier, AC 8) — none
   of it is `src/state/`, so nothing here is reachable from `MatchState.to_snapshot()`.
   `DebugInstrumentPanel`'s existing pattern (a Control fed plain values, never holding a state
   handle) is the precedent the new control follows.
2. **No seeded-RNG consumer.** Neither the cache fix, the trigger, the save/load round-trip nor the
   verifier draws randomness. F2's two-site guard (`shuffle_with_rng(` in `deck.gd` plus its one
   `MatchState` caller) must still read exactly two after this story.

**If the save/load format (AC 4) needs a helper method added to `IntentRecorder` that also happens to
change what `_resource_values`/`_apply_values` touch, or if the dev pass finds itself needing a new
snapshot-adjacent field to make the live trigger observable in the UI, this prediction is INVALID and
must be rewritten before the work continues** — the same discipline `3-0c`'s Golden Prediction states
for itself.

## Live Smoke

**REQUIRED — this is the part of the X5 work that has a live surface; `3-0c` correctly owed none.**
On the shipped default (`slot_controller_kinds = [KEYBOARD_P1, KEYBOARD_P2]`, verified by content at
`match_runner.gd:31-34` — two live, keyboard-driven, killable human slots, no `.tscn` edit needed):

**What this smoke proves that AC 4 does not (`3-0d/R4`):** AC 4 proves round-trip FIDELITY on a
fixture record. This smoke proves the LIVE RUNNER emits a well-formed file from a REAL PLAYED ROUND.
Neither subsumes the other, and only the second requires a human.

- Play a short live round on both slots — movement, at least one attack/contact, at least one card
  cast. **No start step: recording is always-on from tick 0 (AC 6), so the round IS the record.**
- **`R-D6` IS RE-INVOKED AND SPENT HERE (`3-0d/R11`) — a REQUIRED observation, not optional:** carry
  one slot to a KILL. Both shipped slots are live, keyboard-driven and killable
  (`slot_controller_kinds = [KEYBOARD_P1, KEYBOARD_P2]`, `match_runner.gd:31-34`) and the round
  already involves combat, so this costs the smoke almost nothing.
- Trigger a live mid-match balance reload from the panel. **Observe the visible stamina refill and
  record it as EXPECTED** — it is the per-pool `apply_balance` contract becoming live-observable for
  the first time (AC 9, `3-0d/R10`), not a defect to be named and tolerated.
- Press SAVE on the `DebugInstrumentPanel`; confirm the file exists on disk at the `user://` path.
  **Then keep playing and press SAVE a second time** — confirm the second file is LARGER / longer,
  which is the operator-visible half of "SAVE does not stop or restart the recording" (AC 6/AC 7).
- **The payoff, performed OUTSIDE the game** (`3-0d/R3`/`R4` — the game does not and will not display
  a canonical hash): run the headless verifier on the saved file,
  `godot --headless --path . --script res://test/tools/replay_file.gd -- <path>`. Confirm it (a)
  accepts the file as structurally complete, (b) replays it to completion, and (c) **run it TWICE and
  confirm the same hash both times.**
- No load step and no stop step exist to perform — both were ruled out (`3-0d/R1`, `3-0d/R2`).

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (`claude-opus-5`) — the dev pass, 2026-08-05. The readiness gate's fix pass the day
this file was promoted was Claude Sonnet 5, docs only. The commit trailer's
`Claude Opus 4.8 <noreply@anthropic.com>` is a repo-wide INVARIANT (operator ruling), not the model
that did this work.

### Debug Log References

**Engine semantics MEASURED before any code was written** (throwaway script, deleted; Godot 4.6.3):
plain `load()` twice -> `true` (same instance); `CACHE_MODE_IGNORE` twice -> `false` (different);
`CACHE_MODE_IGNORE` vs the cached instance -> `false`; values equal -> `true`. Same script measured
the persistence format's premises: `store_var`/`get_var` round-trips `Basis` and `Vector2` equal,
keeps StringName keys `TYPE_STRING_NAME` (21) and keeps ints ints.

**SIX MUTATION PROOFS — every new guard was broken and observed RED, then restored from a copy
taken OUTSIDE the repo** (never `git checkout --`; SHA-256 verified identical after each restore):

| # | Break | Test that went RED |
|---|-------|--------------------|
| 1 | tap moved to the sample step | `test_replay_surface_pins.gd::test_the_intent_tap_stays_seated_immediately_before_advance` — both halves (next statement, and inside the ticking gate) |
| 2 | added `replay_record = RecordFile.load_record(path)["record"]` (the rejected LOAD control) | `test_replay_surface_pins.gd::test_replay_record_is_assigned_nowhere_in_src` |
| 3 | added a second `Callable` + a `LoadRecord` button to the panel | `test_replay_surface_pins.gd::test_the_panel_has_exactly_one_runner_reaching_control` AND `test_record_save_control.gd` (scene-level half) |
| 4 | `reload()` reverted to a plain `load()` | `test_balance_config.gd::test_reload_bypasses_the_resource_cache_and_hands_back_a_fresh_instance` |
| 5 | camera-basis channel dropped on the way to disk | `test_record_file.gd::test_a_saved_and_reloaded_record_replays_to_the_same_canonical_hash` AND `::test_the_round_trip_carries_every_channel_verbatim` |
| 6 | live trigger applies balance without capturing it | `test_live_reload.gd::test_the_runner_trigger_re_reads_the_service_and_captures_before_it_applies` |

**AC 8's verifier, run for real** on a record produced HEADLESSLY BY THE LIVE RUNNER (throwaway
script drove `main.tscn` for 90 frames and called the runner's own `save_recorded_stream()` — the
same Callable the SAVE control invokes; script deleted, `user://` file deleted afterwards). Two
consecutive runs on the same file, identical output both times:
`ticks=89 reload_events=1 seed=12345 deck=20 cards costs=9 order=[&"deck", &"costs"]`,
`camera_pushes=178 contact_facts=0`, `CanonicalHash:
5f465e7a7ff0826c3a6977b64e16b784c58bb31a3d91b909585cbc0f6acf9d13`, `RESULT: PASS`, exit 0. Its
refusal paths were exercised on that same real file: no argument -> usage, exit 2; missing path ->
`REFUSED: no record file at ...`; `format_version` rewritten to 99 -> `REFUSED: record format
version 99 does not match this build's 1 ...`; version restored -> the SAME hash again.

### Completion Notes List

- **SUITE. Before: 329 state tests / 1715 assertions / 19 integration. After: 344 / 2197 / 20 —
  +15 state tests, +482 assertions, +1 integration file. ALL PASSED both times.** No pre-existing
  test was edited except `test_balance_config.gd`, which GAINED AC 1's test (the AC's own
  instruction) and lost nothing.
- **GOLDEN DID NOT MOVE.** `test_determinism.gd` is untouched (`git status` clean for it) and its
  `GOLDEN` constant still reads `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`
  — the Golden Prediction of NONE held, on both premises it was argued on. `test_determinism.gd::
  test_state_hash_matches_golden` passes inside the 344.
- **`project.godot` IS BYTE-IDENTICAL.** SHA-256 before and after:
  `8879DE490EDDA78051595F189FB9BB6F2E75384FEBAFF142C8958EC107970004`. No Input Map action was
  added; SAVE is mouse-only and `test_shipped_input_map_action_set_is_exactly_pinned` stays green
  UNMOVED at 30 actions.
- **THE FOUR INHERITED `3-0c` PINS REQUIRED ZERO EDITS (AC 10)**, verified by `git status`:
  `test_architecture_invariants.gd`, `test_replay_identity.gd`, `test_intent_recorder.gd` and
  `test_deck_and_hand.gd` are all unmodified, and all pass. This story touches no file under
  `src/state/`, adds no `connect_*` seam and no unhashed cross-tick member.
- **AC 1** — `reload()` is now `ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)`.
  Proved BY OBJECT IDENTITY in the STATE harness, zero file mutation, zero new autoload API
  (mutation proof 4).
- **AC 2** — `match_runner.gd::trigger_live_balance_reload()`: `BalanceConfigService.reload()` ->
  `_recorder.capture_apply_balance(config)` -> `_match_state.apply_balance(config)`, refused
  outright in replay mode. Proven by a live-shaped pair reaching `reload_event_count() == 2` with
  event 1's tick == the trigger point, by the replay side consuming that event with no new code,
  and by a source scan over the runner's real call site (mutation proof 6).
- **AC 3** — no ninth channel: the recorder's `capture_*` set is counted off the SCRIPT's own
  method list and asserted to be exactly the eight `3-0c` shipped.
- **AC 4** — `RecordFile.save_record` / `load_record`, a sibling under `src/systems/` (the
  recorder gains no file I/O and keeps its clock-free, content-blind scan green). Round trip proven
  twice over: bit-identical `CanonicalHash` across live run / in-memory replay / loaded-file replay,
  AND channel-by-channel equality including all EIGHT `InputIntent` fields on every tick for both
  slots (288 field comparisons). Mutation proof 5 shows a dropped channel fails it.
- **AC 5** — `FORMAT_VERSION := 1` rides the file; a record whose version is rewritten is REFUSED
  with a reason naming BOTH versions, and the SAME file loads again once the version is restored.
  A non-record file and a record with no match start are refused the same way — reasons, never
  crashes, and the malformed one is refused AT THE WRITE so it cannot exist to be loaded.
- **AC 6** — always-on and cumulative, proven twice: in the state harness (save at 6 ticks, save
  again at 13; second file carries 13 and still begins at TICK 1 with the value tick 1 drove) and on
  the LIVE runner (`test_record_save_control.gd`: 19 ticks / 19,996 bytes then 59 ticks / 54,876
  bytes, the runner's own tick count matching each file).
- **AC 7** — ONE new control: `SaveRecord`, a `Button` in a THIRD COLUMN of the existing box (a
  third ROW would have pushed the panel out of the empty y[356,450] band and over the vitals bars —
  `test_debug_instruments.gd`'s S1/S2 layout assertion still passes, so the re-fit is verified, not
  assumed). Wired by a runner-owned `Callable` set before `add_child`. Pinned at exactly one
  runner-reaching control by a scan that also forbids a second `Callable` and any `signal` — the
  only two shapes the Dev Notes name for reaching the runner (mutation proof 3, which fails BOTH the
  structural pin and the scene-level control-set check).
- **AC 8** — `test/tools/replay_file.gd`, `extends SceneTree` + `_initialize()`, deliberately not
  globbed by `run_all.sh`. Run twice on a real runner-produced record for the same hash; see Debug
  Log References for both outputs.
- **AC 9** — the per-pool contract is exercised UNCHANGED by the live trigger: stamina refills to
  the new maximum (ratified correct, `3-0d/R10`), mana keeps its earned value under the new bound,
  hp is preserved and never re-healed, on both players.
- **AC 11** — both halves shipped as one source scan each, with their patterns proven against the
  exact strings they exist to catch (an assignment matches, a `!=`/`==` comparison does not), and
  both proven RED by mutation (proofs 1 and 2).
- **CONTRACT CONFLICT FOUND AND NOT RESOLVED BY THIS PASS — AC 7 vs the Live Smoke. AC 7 pins the
  panel at EXACTLY ONE new control (SAVE) and ships a structural test counting runner-reaching
  controls at one, so a RELOAD button is a second and is refused; the Live Smoke's third bullet asks
  the operator to "trigger a live mid-match balance reload from the panel", which requires exactly
  that second control.** Built to the AC, not to the smoke: `trigger_live_balance_reload()` ships as
  a runner call site with tests and a source scan, and has NO operator surface. **As shipped, the
  smoke's reload step cannot be performed and the smoke's stamina-refill observation with it.** This
  needs an operator ruling before the smoke runs; the conflict is recorded in the trigger's own doc
  comment so it cannot be lost.
- **LIVE SMOKE NOT RUN** — it is the operator's, and it carries the required R-D6 kill observation
  (`3-0d/R11`). This pass ends before it.
- **Editor scan run in THIS pass** (`godot --headless --editor --quit --path .`): the one new
  `class_name`, `RecordFile`, registers, and a `.uid` exists and is committed for every one of the
  six new `.gd` files.

### File List

**New — source**
- `src/systems/record_file.gd` (+ `.uid`) — `class_name RecordFile`, the `user://` save/load pair
  (AC 4/AC 5). The ONE new `class_name` this story ships.

**Modified — source**
- `src/systems/balance_config_service.gd` — `reload()` -> `CACHE_MODE_IGNORE` (AC 1).
- `src/main/match_runner.gd` — `_save_index`; `panel.save_record = save_recorded_stream` wiring;
  `save_recorded_stream()` (AC 7); `trigger_live_balance_reload()` (AC 2). The intent-tap seat, the
  `ticking` gate, `_physics_process`'s structure, the seven `connect_*` seams and `replay_record`
  are ALL untouched (AC 10/AC 11).
- `src/ui/debug/debug_instrument_panel.gd` — the `save_record` Callable, `_build_save_control()`,
  `_on_save_pressed()` (AC 7).

**New — tests**
- `test/state/test_live_reload.gd` (+ `.uid`) — AC 2, AC 3, AC 9, and the runner's call-site scan.
- `test/state/test_record_file.gd` (+ `.uid`) — AC 4, AC 5, AC 6.
- `test/state/test_replay_surface_pins.gd` (+ `.uid`) — AC 7 structural, AC 11 (both halves).
- `test/integration/test_record_save_control.gd` (+ `.uid`) — AC 7 in the live scene.
- `test/tools/replay_file.gd` (+ `.uid`) — AC 8, the headless verifier. NOT globbed by `run_all.sh`.

**Modified — tests**
- `test/state/test_balance_config.gd` — gains AC 1's object-identity test; nothing removed.

**Deliberately untouched:** `project.godot` (hash identical), `docs/game-architecture.md` (the
ELEVENTH amendment-queue member stands, `3-0d/R12`), `src/systems/intent_recorder.gd`,
`src/controllers/replay_controller.gd`, everything under `src/state/`, `test_determinism.gd`, and
the four inherited `3-0c` pins.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-05 | 0.1 | File authored at this story's own creation pass, per the `3-0a`/`3-0b`/`3-0c` precedent and `3-0c/R5`'s split ruling. Nine ACs recorded, each mapping to one of the six inherited scope items (CACHE_MODE_IGNORE; the live reload trigger reusing the existing reload channel; `user://` persistence with the format deliberately unpinned; recording start/stop lifecycle; the panel controls with no new Input Map action; the live smoke) or explicitly declared discharged by a non-AC section with a reason (the live smoke itself, discharged by the required Live Smoke section rather than a numbered AC, matching this repo's own convention for every prior story). Every quoted string re-verified against shipped code or the decision log at write time; the commissioning brief's R-D6 claim ("spent on 3-4") is corrected — the more recent spend was `3-5a`. A structural gap not previously named anywhere is surfaced: `replay_record` is read once in `_ready()`, before the scene ticks, and no scene-reload mechanism exists in `src/`, so a mid-session "load" control has no runtime path into replay under the shipped architecture (Open Question (f)). Six Open Questions left open, none resolved. Golden Prediction NONE, argued on the same two premises `3-0c` used (no snapshot key; no seeded-RNG consumer). Live Smoke REQUIRED, described on the shipped two-keyboard default, no `.tscn` edit needed. Status `backlog`; promotion to `ready-for-dev` deferred to this story's own readiness gate. Nothing under `src/` or `test/` is touched by this pass — docs only. | Claude Sonnet 5 |
| 2026-08-05 | 0.3 | **DEV PASS — all ELEVEN ACs implemented; suite 329/1715/19 -> 344/2197/20, all green both ends.** DEBT B is closed on both halves: `reload()` is `ResourceLoader.load(..., CACHE_MODE_IGNORE)` (AC 1, proven by OBJECT IDENTITY in the state harness with zero file mutation, engine semantics MEASURED first), and `match_runner.gd::trigger_live_balance_reload()` re-reads the service then captures BEFORE it applies on the existing reload channel (AC 2/AC 3, no ninth `capture_*`). `user://` persistence ships as `src/systems/record_file.gd` (`class_name RecordFile`, the ONE new class_name; editor scan run and `.uid` committed for all six new `.gd` files) — a sibling rather than a recorder method, so the recorder stays clock-free and content-blind and its own scan stays green. Round trip proven by bit-identical `CanonicalHash` across live run / in-memory replay / loaded-file replay AND channel-by-channel equality including all eight `InputIntent` fields (AC 4); `FORMAT_VERSION` refusal proven in both directions (AC 5); always-on cumulative recording proven in the harness and on the LIVE runner (AC 6). The panel gains EXACTLY ONE control, `SaveRecord`, in a third COLUMN (a third row would leave the empty band and trip `test_debug_instruments.gd`'s S1/S2 layout guard, which still passes), wired by a runner-owned `Callable` and pinned at one runner-reaching control by a scan that also forbids a second `Callable` and any `signal` (AC 7). `test/tools/replay_file.gd` ships and was RUN FOR REAL, twice, on a record produced headlessly by the live runner — same hash `5f465e7a...9d13` both times (AC 8). Per-pool contract exercised unchanged, stamina refill ratified (AC 9). The four inherited `3-0c` pins required ZERO edits and `project.godot` is byte-identical (`8879DE49...0004`); the golden did not move (`40eb5554...a322`). SIX mutation proofs, each broken then restored from an out-of-repo copy with SHA-256 verified. **ONE CONTRACT CONFLICT RAISED, NOT RESOLVED: AC 7 pins the panel at one control while the Live Smoke asks for a panel-triggered live reload — a second runner-reaching control. Built to the AC; the trigger has no operator surface and the smoke's reload step cannot be performed until the operator rules.** Live smoke NOT run (operator's, carries the required R-D6 kill). Code and docs in two separate commits; neither pushed. | Claude Opus 5 |
| 2026-08-05 | 0.2 | **Readiness gate fix pass — NOT READY on first reading, five blocking findings, all ruled and applied (`3-0d/R1`-`R12`).** AC count 9 -> 11. **B1/`R1`:** ACs 5/6 contracted a mid-match START control that cannot ship — `capture_advance()` asserts `has_complete_match_start()` on its first captured tick and all five match-start channels are captured only inside `_ready()` behind `if not replaying`, so a mid-match start trips the invariant on the next tick; and even a working one would be meaningless, since a replay builds from `MatchState.new()` forward and no state-restore snapshot exists. Recording is ALWAYS-ON from tick 0 (already true in shipped code, `match_runner.gd:566`); new AC 6 pins it. **B2/`R2`:** the "load" control had no correct runtime path AND the story's stated reason was FALSE — `replay_record` is not read only in `_ready()`, it is also read every tick in `_physics_process` (lines 536-540), so a mid-session assignment injects tick-1 recorded reloads/bases/contacts into a live match while both controllers are still live keyboards and silently stops recording. LOAD IS NOT A LIVE CONTROL; a scene-reload mechanism was considered and REJECTED (new architecture; collides with the ratified "record + replay only" scope line). The panel gains EXACTLY ONE control, SAVE, with recording continuing afterwards (AC 7). **B3/`R3`/`R4`:** the smoke's payoff step was unperformable — `CanonicalHash` is `test/canonical_hash.gd` and nothing in `src/` computes or displays a hash (verified: the only two `src/` occurrences are comments). The payoff moves to a HEADLESS VERIFIER under `test/tools/` (AC 8), which is what legitimately gives it `CanonicalHash`; consequence recorded — the Input Map pin's "replay reachable only from a test, never from a key" message stays TRUE, so that non-blocking finding is DISSOLVED, not deferred. The smoke is reformulated to what it alone can prove: a REAL PLAYED ROUND's record exists, is structurally complete, and replays headlessly twice to the same hash. **B4/`R5`:** old AC 1 forced a permanent test to mutate the tracked authored `.tres` (`CONFIG_PATH` is a hardcoded const with no seam; `test_contact_pipeline.gd` and `test_balance_authoring.gd` read it too), colliding with the PERMANENT RULE at decision-log:799 and worse than the one-off case that rule was written for. AC 1 now proves the cache bypass BY OBJECT IDENTITY — two `reload()` calls yielding DIFFERENT references with EQUAL values, plain `load()` yielding the same one — **measured on Godot 4.6.3 before the AC was written**; zero file mutation, zero new autoload API, and it lands in the STATE harness (`test_balance_config.gd:88-89` already instantiates the service as a plain Node). **B5/`R6`:** old AC 9 was a process promise with no falsifying mechanism (all `capture_advance` hits in `test/` drive a recorder directly). AC 11 now ships a source scan over `match_runner.gd` pinning the tap seat AND that `replay_record` is assigned nowhere in `src/`. **`R7`:** on-disk format stays unpinned except for a mandatory format-version int with refusal on mismatch (new AC 5). **`R8`:** the old-record/changed-`CardDatabase` question is CLOSED BY CONSTRUCTION — replay drives injected deck + costs and never reads the autoload (verified). **`R9`:** debug reset is round-scoped and rides the record as an ordinary captured `InputIntent` field; a record spans it intact. **`R10`:** the visible stamina refill on a live reload is RATIFIED AS CORRECT (the per-pool `apply_balance` contract, live for the first time), observed by the smoke as EXPECTED. **`R11`:** R-D6 RE-INVOKED AND SPENT on this story's smoke; the kill is a REQUIRED observation. **`R12`:** the architecture's "record/replay start-stop-load" annotation (lines 578-579) genuinely diverges from SAVE-only and becomes the **ELEVENTH** amendment-queue member (queue counted by content: ten, per `3-0c/R10` and `3-0c/R14`); `game-architecture.md` NOT edited, queue flushes at E3 close-out. **Non-blocking corrections applied:** the Input Map action count re-measured 28 -> **30** (2 `debug_*` + 14 `p1_*` + 14 `p2_*`); "`reload()` has exactly ONE caller" corrected to TWO (its `_ready()` plus `test_balance_config.gd:89`), with the inheritance of that wrong claim from the CLOSED `3-0c` story file recorded here rather than by editing that file; three "not decided here" carve-outs moved out of ACs into Dev Notes; two drifted citations re-anchored by content (`3-0c/R5` 3685 -> **3682**-3699; the architecture X5 toggle line 579 -> **578**-579). Line numbers are NOT re-anchored wholesale — non-blocking on the repo's own precedent. **Open Questions section DELETED** (the `3-0c` precedent), all six ruled, each ruling's substance carried into the AC or Dev Note that now owns it. **Every pre-existing Dev Notes bullet survives**; the three falsified ones (the `reload()` caller count, the 28-action count, the `replay_record`-read-once structural gap) are CORRECTED IN PLACE with the correction visible, none deleted. Golden Prediction unchanged (NONE), premise 1 widened to name `test/tools/`. Status `backlog` -> **`ready-for-dev`**. Docs only; nothing under `src/` or `test/` touched. | Claude Sonnet 5 |
