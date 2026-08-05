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
   (AC 2) is a second CALL to the existing `capture_apply_balance`, not a new method. ~~A structural
   test counts `func capture_` occurrences in `intent_recorder.gd` and asserts exactly eight,
   proving a ninth would be a scope violation this test catches.~~
   **MECHANISM SENTENCE CORRECTED TO THE SHIPPED ONE (`3-0d/R27`), and the shipped mechanism is the
   STRONGER of the two.** The test never grepped anything: `test_live_reload.gd::
   test_the_recorder_still_ships_exactly_eight_capture_channels` loads the script and reads
   `script.get_script_method_list()`, filtering names that begin with `capture_`, and asserts the
   sorted result equals the named eight — its own docstring says so explicitly ("Counted from the
   SCRIPT's own method list rather than by grepping `func capture_`, so a channel added by any
   means (including one inherited or defined out of the obvious form) is caught"). **The OUTCOME
   claim was always true and is unchanged — exactly eight, and a ninth fails here.** Only the
   sentence describing HOW was wrong, and it was wrong in the direction this story has spent three
   rounds learning to distrust: it described a TEXT SCAN where the code does REFLECTION over the
   engine's own method list, which is not evadable by declaration form (`3-0d/R20`'s lesson,
   already correctly applied here before the AC caught up with it).
4. **A record saved to `user://` and loaded back replays to the same `CanonicalHash` as replaying the
   original in-memory record.** This is the AC 10 / `3-0c` identity shape, driven twice — once from
   the in-memory `IntentRecorder` and once from an `IntentRecorder` reconstructed by loading the saved
   file — and asserting the two replays hash identically. Breaking the save/load round-trip is what
   makes this AC falsifiable.
   **POST-REVIEW AMENDMENT (`3-0d/R17`): THIS AC NOW ALSO COVERS AC 8's VERIFIER ORDERING, WHICH IT
   DID NOT BEFORE.** Both replays here are driven through `ReplayDrive.drive()`
   (`test/replay_drive.gd`), the single extracted copy of the replay drive order, SHARED with AC 8's
   headless verifier. Before the extraction the verifier's ordering was a third independent
   transcription that nothing guarded — see the AC 8 amendment and the corrected Dev Note.
5. **The on-disk record carries a FORMAT VERSION int, and a record whose version does not match is
   REFUSED with a clear reason rather than replayed (`3-0d/R7`).** A test writes a record, rewrites
   only its version field to an unknown value, and asserts the load path refuses it and says why; the
   same test asserts a matching version loads. This is the ONE element of the on-disk shape this
   story pins — everything else about byte layout, key naming and file extension stays deliberately
   unpinned (rationale in Dev Notes).
   **POST-REVIEW AMENDMENT (`3-0d/R15`, `3-0d/R16`): ~~"REFUSED WITH A CLEAR REASON" NOW HOLDS ON
   EVERY PATH~~, AND `save_record` CARRIES THE `user://` CLAIM ITSELF.** The review found ONE path
   where the refusal had no reason: a file carrying a MATCHING version but a TRUNCATED body reached
   `_from_dictionary()`, failed inside it, and came back as `{"record": null, "error": ""}` — which
   a caller testing `error != ""` reads as SUCCESS, contradicting the class's own documented
   contract. `RecordFile.REQUIRED_KEYS` is now validated BEFORE anything is rebuilt and the refusal
   NAMES the missing keys; the previously untested no-version-key branch gains its own test; and a
   derivation guard asserts `REQUIRED_KEYS` equals the key set an actual saved file carries, so the
   two cannot drift. Separately (`3-0d/R16`), `save_record` accepted ANY path and was proven at the
   review to write a record into the repo root — it now REFUSES a path that does not begin with
   `user://`, with a reason, so this class's assertion about where records go is true of the API and
   not only of `path_for()`.

   **THE STRUCK CLAIM WAS FALSE AND IS REDUCED TO WHAT THE CODE CARRIES (`3-0d/R25`). THIS
   PARAGRAPH IS THE OPERATIVE FORM OF AC 5's REFUSAL CLAIM.** Twice this AC has asserted TOTALITY
   over refusal reasons — at `3-0d/R15` and again after `3-0d/R21` corrected the Dev Notes and the
   class docstring but left this sentence standing — and both times a narrower set of files
   falsified it. It stops asserting totality. What it claims, exactly:

   > **Each required key's TOP-LEVEL TYPE is validated before the rebuild** (`RecordFile.
   > REQUIRED_KEYS`, a key -> type map), and a file failing that is REFUSED with a reason naming
   > the key and what was found in it — alongside the version mismatch, the missing version key,
   > the non-Dictionary file, the absent file and the missing required key, each of which also
   > refuses with a reason.

   **THE RESIDUE, STATED PLAINLY (`3-0d/R25`).** NESTED and CROSS-KEY consistency is NOT validated:
   element types INSIDE the required containers, and array lengths measured AGAINST `tick_count`,
   reach `_from_dictionary()`, die inside it, and come back as `{"record": null, "error": ""}` — an
   empty reason, which a caller testing `error != ""` reads as SUCCESS. **FIVE MEASURED at this
   ruling before the sentence was rewritten**, every one returning an empty reason: `intents` as an
   Array of DICTIONARIES; `intents` SHORTER than `tick_count`; `camera_pushes` values that are
   INTS; `contacts` values that are ARRAYS OF INTS; `tick_count` INFLATED past the intents array.
   **NESTED VALIDATION IS DELIBERATELY NOT BUILT** — that is the ruling, not an omission: it is a
   third round of the same widening for marginal benefit on a format with exactly one writer, and
   the point is that the boundary gets WRITTEN DOWN instead of chased. The residue is closed for
   CALLERS instead: test `result["record"] == null`, never `error != ""`. Measured at this ruling,
   all three shipped callers already do.
6. **Recording is ALWAYS-ON from tick 0: the record covers the match from its first tick and is never
   restarted mid-match (`3-0d/R1`).** Verified by content, `match_runner.gd:566` already calls
   `_recorder.capture_advance(intents)` on every ticking frame in the non-replay (`else`) branch, and
   `_recorder` is never reassigned — so this AC ships NO start control and NO reset of the recorder.
   A test drives a live-shaped runner-equivalent pair for N ticks, saves, drives M more, saves again,
   and asserts the second file's tick count is `N + M` and its first tick is tick 1 — proving the
   record is cumulative from tick 0 rather than restarted by the SAVE. **A mid-match start is not
   merely out of scope, it is meaningless, and a naive one is unshippable** — see Dev Notes.
7. **The `DebugInstrumentPanel` (`src/ui/debug/debug_instrument_panel.gd`) gains EXACTLY the SET of
   TWO new controls: SAVE and RELOAD (`3-0d/R2`, amended `3-0d/R13`).**
   **AMENDMENT RECORD (`3-0d/R13`): this AC originally pinned the panel at EXACTLY ONE new control
   (SAVE), and the dev pass that first implemented this story (`f5da20c`) built to that pin,
   correctly, and raised a CONTRACT CONFLICT it deliberately did not resolve: the Live Smoke section
   below asks the operator to "trigger a live mid-match balance reload from the panel", which needs a
   SECOND runner-reaching control that the one-control pin forbids. The operator ruled (`3-0d/R13`,
   decision-log Session 2026-08-05 — Story 3-0d, `3-0d/R13` panel reload control): the original
   "exactly one" was never protecting a COUNT — it was protecting against a LOAD control (`3-0d/R2`).
   What must stay impossible is ENTERING REPLAY mid-session, and that is carried STRUCTURALLY by AC
   11's `replay_record` source scan (assigned nowhere in `src/`), which holds regardless of how many
   buttons the panel carries. This AC is therefore reformulated from a COUNT into an EXACT SET, the
   shape this repo already uses for the Input Map pin: the panel's runner-reaching controls are
   EXACTLY `{SaveRecord, ReloadBalance}` and nothing else. A third — a load control in particular —
   still fails it, proven by mutation at this pass.**
   SAVE writes the record so far to `user://`, and RECORDING CONTINUES AFTERWARDS — SAVE is a
   snapshot of an always-on stream, not a stop. RELOAD calls the already-shipped
   `match_runner.gd::trigger_live_balance_reload()` (AC 2) — the panel gains no new runner-side
   trigger logic, only its first operator-reachable seat. Both follow the panel's own in-code
   `CheckButton`/`Button` pattern (verified by content: two `CheckButton`s built directly in
   `_ready()`, no `.tscn`) — no new top-level `Control`, no new `.tscn`, and NO Input Map action.
   **There is no start control and no load control.** ~~A structural test asserts the panel's
   runner-reaching Callables and their wired handlers sort to the EXACT expected two-member sets, so
   a third (a "load" in particular) fails here — and the test's own docstring says in its own text
   that AC 11, not this pin's control count, is what actually keeps a load control out.~~
   **RETIRED AT `3-0d/R20` — see this AC's re-wording at the bottom. That structural test was a
   SOURCE SCAN over the panel file, and it is DELETED.**
   **POST-REVIEW AMENDMENT (`3-0d/R14`): THAT STRUCTURAL TEST WAS EVADABLE AND IS NOW FIXED.** As
   shipped it matched `^var\s+\w+\s*:\s*Callable` — the ANNOTATED form its author had written — so
   the review declared a load control's Callable as `var load_record := Callable()`, the idiomatic
   INFERRED form, and walked straight past this pin. ~~The scan now matches a member declaration
   CARRYING `Callable` IN ANY FORM (annotated, inferred, untyped-but-initialised) plus any member
   the file INVOKES as a Callable, which also covers a member declared with no type at all. Its
   self-check asserts all five of those forms are CAUGHT alongside the panel's own non-reaching
   members being SPARED, and the pin was re-proven by mutation IN THE EVASION FORM.~~
   **FALSIFIED BY THE NEXT REVIEW AND SUPERSEDED (`3-0d/R20`): the widened scan was ALSO evaded, by
   six declaration forms it did not anticipate — `static var`, `@onready`, an inner-class member, a
   Callable in an untyped `Dictionary`, one in an untyped `Array`, and an untyped member invoked
   through a local copy. The scan is now DELETED rather than widened a third time.**
   `test_shipped_input_map_action_set_is_exactly_pinned` (`test/state/test_deck_and_hand.gd:439`)
   stays green UNMOVED — the project's **30**-action set (MEASURED at this gate from
   `SHIPPED_INPUT_ACTIONS`, `test_deck_and_hand.gd:428-436`: 2 `debug_*` + 14 `p1_*` + 14 `p2_*`;
   the "28" this file previously carried was wrong) gains nothing, proving both controls are
   mouse-only exactly as the panel's existing two switches are. A test invokes each control's signal
   handler programmatically (the existing panel's own test pattern) and asserts: SAVE, a file appears
   at the expected `user://` path; RELOAD, the runner's recorded stream gains a reload event and live
   state (P1's stamina, spent below max by a real live roll) is observed refilling to the new
   maximum through the StateInspector's own primed label.

   **RE-WORDED TO WHAT THE MECHANISM ACTUALLY CARRIES (`3-0d/R20` part 5). THIS PARAGRAPH IS THE
   OPERATIVE FORM OF AC 7's STRUCTURAL CLAIM; everything struck through above is history.** This AC
   no longer claims, in any form, that a source scan makes a load control impossible. What it
   claims, exactly:

   > **The `DebugInstrumentPanel`'s INSTANTIATED CONTROL SET is exactly the four names
   > `{NormalizeMagnitude, PitchZoneLeftOfBars, SaveRecord, ReloadBalance}`.** Asserted in
   > `test/integration/test_record_save_control.gd` by enumerating the controls a BUILT panel
   > actually created, in the live scene, after `_ready()` has run — never by reading source. It is
   > therefore not evadable by how a member is declared, which is what defeated the deleted scan
   > twice. The query is `BaseButton`, not `Button`: that hole was real and is closed at this
   > ruling, since `LinkButton` extends `BaseButton` and NOT `Button`, so a load control built on a
   > `LinkButton` was invisible to the old query. **Proven by mutation both ways at this pass:** a
   > wired `LinkButton` load control fails the `BaseButton` query, and PASSES the `Button` query it
   > replaced.

   **THE RESIDUE, STATED PLAINLY (`3-0d/R20` part 5).** This pin is about the panel's control set
   and nothing more. It does NOT prove that no control anywhere could enter replay, and it is not
   asked to: that property is carried by the runner CONSUMING `replay_record` once at `_ready()`
   (see the re-worded AC 11), which holds no matter what this panel grows. A control this pin does
   not know about — one built into a `.tscn`, or added by a future story — is caught by this pin
   only if it is instantiated under the panel; if it is not, it is still structurally unable to
   enter replay, and that is the guarantee that matters.
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
   **POST-REVIEW AMENDMENT (`3-0d/R17`): THE VERIFIER NO LONGER TRANSCRIBES THE REPLAY DRIVE ORDER.**
   As shipped it carried its own copy of the ordering — a THIRD independent transcription after the
   runner's live fork and AC 4's test — and NOTHING guarded it: AC 4 covered the save/load path only,
   so a divergence here would have printed a stable but wrong hash indefinitely. The order is
   extracted to `test/replay_drive.gd` (`ReplayDrive.drive()`), used by BOTH this verifier and AC 4's
   in-suite round-trip test, which is what puts it under regression cover. The runner's own fork
   stays where it is — it is `src/` code inside `_physics_process` and cannot call into `test/` —
   and remains the ORIGINAL the helper is transcribed from, named in the helper's own docstring.
   **This AC's own claim is unchanged and still holds:** run twice on the same file, the verifier
   prints the same hash.
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
    **RE-WORDED TO WHAT THE MECHANISMS ACTUALLY CARRY (`3-0d/R20` part 5). THIS PARAGRAPH IS THE
    OPERATIVE FORM OF AC 11; everything below it is history, kept because the history is the
    lesson.** AC 11's half (b) — *"a source scan asserts `replay_record` is assigned nowhere in
    `src/`"* — **IS RETIRED. That scan is DELETED (`3-0d/R20` part 3).** It was evaded THREE TIMES
    over three review rounds and each round hardened the pattern rather than the mechanism; keeping
    it would produce false confidence about a property now carried by construction. What replaces
    it, exactly:

    > **(b1) STRUCTURAL CONSUMPTION.** `MatchRunner` reads the public `replay_record` EXACTLY ONCE,
    > in `_ready()`, into a private `_replay_record`; the per-tick fork in `_physics_process`, the
    > live-reload refusal, and every other consumer read ONLY the private field. A mid-session
    > assignment to the public member therefore HAS NO EFFECT — not because it is caught, but
    > because nothing reads what it changed. The external PRE-TREE assignment
    > (`test/integration/test_replay_contacts.gd`) is unaffected and still enters replay, which is
    > what makes this a consumption point rather than a removal.
    >
    > **(b2) A BEHAVIOURAL PROOF, which is the mechanism now.**
    > `test/integration/test_replay_entry_is_inert.gd` assigns `replay_record` mid-match on a LIVE
    > runner — the plainest possible bare assignment, the exact line the deleted scan hunted — and
    > asserts the per-tick fork does NOT flip (live `max_hp` is still the authored value, not the
    > poisoned one a replayed tick 1 applies), recording CONTINUES (the recorder gains one tick per
    > ticking frame across the assignment), and the live reload trigger still fires. Its falsifying
    > change is obvious and real: restore the per-tick read of the public member and it goes red —
    > **proven by mutation at this pass, both assertions firing.**

    **THE RESIDUE, STATED PLAINLY (`3-0d/R20` part 5).** (b1)+(b2) prove that a mid-session
    assignment to `replay_record` does nothing on the shipped runner. They do not prove that no
    code anywhere could ever enter replay by some other route — nothing can prove that, which is
    the whole finding. They make the route that mattered STRUCTURALLY INERT instead of DETECTABLE,
    which is a stronger position than a scan that has been walked around three times.

    **AND HERE IS WHAT THAT RESIDUE COSTS, CONCRETELY (`3-0d/R25`) — because a residue nobody can
    picture is not really stated.** The guarantee is *"assigning `replay_record` does nothing to
    the shipped runner"*. It is NOT *"nothing can read it"*. A NEW PER-TICK CONSUMER OF THE PUBLIC
    MEMBER STILL SLIPS THROUGH, and the concrete one was built and run at this ruling: four lines
    at the top of `_physics_process`, above the sample step, that swap BOTH live keyboard
    controllers for `ReplayController`s the moment the public member is non-null —

    ```gdscript
    if replay_record != null and not (_p1_controller is ReplayController):
        _p1_controller = ReplayController.new(replay_record, 0)
        _p2_controller = ReplayController.new(replay_record, 1)
    ```

    — which hands the whole match over to a recorded intent stream mid-play. **MEASURED, not
    argued: with that installed, the ENTIRE SUITE IS GREEN — 348 / 2264 / 22, ALL PASSED.** (b2)
    does not see it, and cannot: it watches `max_hp`, the recorder's tick count and the reload
    trigger, and a controller swap moves none of the three. **THE DELETED SCAN WOULD HAVE FLAGGED
    IT** — a bare `replay_record` occurrence outside its four allowed read forms is exactly what it
    hunted. That is the honest shape of the trade `3-0d/R20` made: it did not strictly dominate the
    scan, it traded a guard that was *believed* to hold and did not, for a guarantee that is
    *narrower and true*. The consumption point is the mechanism; this paragraph is its edge.

    Half (a), the
    tap seat, is UNCHANGED and still a source scan — deliberately: it asserts where two statements
    sit relative to each other inside one known function of one known file, which is a question
    source text is genuinely evidence of, unlike "is this reachable from anywhere in the tree". Its
    own limits (the line reader is not string-aware) are now stated in the test's docstring rather
    than left implied.

    **POST-REVIEW AMENDMENT (`3-0d/R14`): HALF (b) WAS EVADABLE AND IS NOW A WHITELIST.** As shipped
    it looked for the ONE shape an assignment takes — `\breplay_record\s*=[^=]` — and the review
    reached the member three ways that pattern had not enumerated: `set("replay_record", rec)`,
    `set_deferred("replay_record", rec)` and `runner[&"replay_record"] = rec`. ALL THREE PASSED, and
    worse, all three were counted as harmless READS. The scan is INVERTED: every occurrence of the
    token in `src/` must classify as one of four explicitly enumerated ALLOWED READ FORMS — the
    declaration, a null comparison, a member read, or a read passed as an argument — and anything
    else, INCLUDING A FORM NOBODY HAS THOUGHT OF YET, is an offender BY DEFAULT, reported with its
    file, line and text. The allowed set is DERIVED from the shipped tree (each form is asserted to
    occur in `src/`); no line count is hard-coded. The self-check asserts every evasion form above is
    CAUGHT and every shipped form is SPARED **and classified as what it is**, and the pin was
    re-proven by mutation in ALL THREE evasion forms. Half (a), the tap seat, was not evadable and is
    UNCHANGED.
    **FALSIFIED BY THE NEXT REVIEW AND SUPERSEDED (`3-0d/R20`): THE WHITELIST WAS EVADED TOO, AND BY
    ITS OWN CLASSIFIER.** `(replay_record) = null` — a literal assignment — was classified as an
    "argument read", because the character after the token is `)`, which the whitelist's
    `^\s*[,)]` rule certified as a read. The shared line reader also truncated at the first `#` with
    NO string awareness, so a `#` inside a string literal deleted the rest of the line from the
    scan; and both scans read `.gd` only, while GDScript embedded in a `.tscn` under `src/` is
    shipped, compiled, executing code. A complete, wired LOAD control shipped past both with the
    whole suite green. **Inverting the enumeration was the right move and was not enough: the
    classifier and its reader each kept having holes. See the operative re-wording at the top of
    this AC.**

## Tasks / Subtasks

- [ ] `ResourceLoader.load(..., CACHE_MODE_IGNORE)` in `BalanceConfigService.reload()`; the
      object-identity test in the STATE harness, no file mutation (AC: 1)
- [ ] Live reload trigger calling `reload()` -> `apply_balance()`, routed through
      `capture_apply_balance()` (AC: 2, 3, 11)
- [ ] `user://` save/load round-trip for an `IntentRecorder` record; identity test against the AC 10
      shape (AC: 4)
- [ ] Format version int in the written record + refusal on mismatch, both directions (AC: 5)
- [ ] Always-on recording proof: SAVE does not reset the record; cumulative from tick 0 (AC: 6)
- [ ] TWO new `DebugInstrumentPanel` controls — SAVE and RELOAD (`3-0d/R13`). No start, no load,
      no new Input Map action; exact-equality pin unmoved at 30 actions; the exact-SET structural
      test (AC: 7)
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
  here. ~~That "exactly one runner-reaching control" is itself the shape AC 7's structural test
  counts, which is what keeps a load control from being added back quietly.~~ **CORRECTED AT THE
  POST-REVIEW PASS (`3-0d/R19`): FALSE ON BOTH HALVES, AND THE SECOND HALF WAS ALREADY THE ERROR
  `3-0d/R13` RULED ON.** (1) AC 7's structural test no longer COUNTS anything — it asserts an EXACT
  SET, `{SaveRecord, ReloadBalance}` / `{_on_save_pressed, _on_reload_pressed}` (`3-0d/R13`), and the
  panel carries TWO runner-reaching controls, not one. (2) A control count was never what keeps a
  load control out. ~~**AC 11's `replay_record` source scan is** — a load control's defining, catchable
  property is that it ASSIGNS `replay_record`, which that scan forbids regardless of how many buttons
  the panel carries.~~ Both the ruling (`3-0d/R13`) and the test's own docstring say so; this bullet
  contradicted them and now says what they say.
  **CORRECTED AGAIN (`3-0d/R20`), and the correction is the whole finding: THAT SCAN IS DELETED, so
  it is not what keeps a load control out either.** The struck clause was right that a control COUNT
  is not the protection, and wrong about what is. A load control's defining property is not that it
  is *catchable* — three rounds proved it is not reliably catchable — it is that it must make the
  runner ENTER REPLAY. The runner now consumes `replay_record` once at `_ready()` and never reads it
  again, so a load control may assign whatever it likes and nothing downstream reads it. **The
  protection moved from "we can detect the thing" to "the thing does nothing."**
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
  verifier (AC 8), and ~~the fact that nothing in `src/` assigns `replay_record` becomes a pinned source
  scan (AC 11) rather than an observation.~~ **CORRECTED (`3-0d/R20`): that scan was shipped, evaded
  three times, and is now DELETED. The observation it tried to pin — "nothing assigns
  `replay_record`" — was the wrong property to guard, because it is a claim about the whole tree and
  source text cannot settle those. The right property is that assigning it ACHIEVES NOTHING, which is
  carried by the runner consuming it once at `_ready()` and proven behaviourally
  (test/integration/test_replay_entry_is_inert.gd). Everything else in this bullet — the two read
  sites, the tick-1 injection, the silent stop of recording — was correct and is exactly what that
  test now measures the absence of.**
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
- **THE PERMANENT LESSON THIS STORY'S REVIEW PRODUCED (`3-0d/R14`), which outlives this story: A
  PATTERN GUARD'S NON-VACUITY CHECK MUST BE PROVEN AGAINST THE FORMS AN ADVERSARY WOULD USE, NOT ONLY
  THE FORM THE AUTHOR HAPPENED TO WRITE.** Both of this story's new source scans shipped with
  self-checks and with mutation proofs, and BOTH were evaded at the review without either going red.
  The reason is the same in both cases and it is not carelessness: **a mutation proof performed in
  the author's own syntax proves only that syntax.** The `replay_record` scan was proven by breaking
  it with `replay_record = ...`, the shape its author had in mind, so it never learned that
  `set("replay_record", rec)`, `set_deferred("replay_record", rec)` and `runner[&"replay_record"] =
  rec` reach the same member — and were being counted as READS. The panel scan was proven by
  declaring an annotated `Callable`, so it never learned that `var load_record := Callable()`, the
  form a developer is MOST likely to type, did not match it at all. The structural remedy, applied to
  both: **enumerate what is ALLOWED and refuse everything else BY DEFAULT**, rather than enumerating
  what is forbidden and being only as good as the author's imagination. ~~The `replay_record` scan is
  now a whitelist of four read forms; the panel scan matches `Callable` in any declaration form plus
  invocation.~~ **CORRECTED (`3-0d/R20`): BOTH SCANS ARE DELETED. The whitelist was evaded by its own
  classifier (`(replay_record) = null` certified as an "argument read") and the panel scan by six
  further declaration forms; the line reader both shared truncated at a `#` inside a string literal,
  and neither read `.tscn`-embedded GDScript at all. The remedy in this bullet — invert the
  enumeration — was RIGHT AND INSUFFICIENT, and the deeper lesson is `3-0d/R20`'s, recorded in its
  own bullet below: prefer making a property IMPOSSIBLE BY CONSTRUCTION over making it DETECTABLE BY
  INSPECTION, and when a guard has been evaded twice, replace the MECHANISM rather than the
  PATTERN.** Both self-checks now assert the EVASION FORMS ARE CAUGHT beside the legitimate forms
  being SPARED, and both were re-proven by mutation IN THE EVASION FORMS. This lesson is recorded in
  the decision log and binds every future pattern guard in this repo, not just these two.
- **Two claims this story's own class made about itself that were not true of its API, both now
  carried by code (`3-0d/R15`, `3-0d/R16`).** (1) `RecordFile`'s docstring says a refusal always
  travels with its reason; on a versioned-but-truncated file it returned `{"record": null,
  "error": ""}`, which a caller testing `error != ""` reads as SUCCESS. Required keys are validated
  BEFORE the rebuild now. (2) The class and AC 7 both assert records go under `user://`; that was
  true of `path_for()` and of nothing else, and `save_record` would write anywhere — proven at the
  review by writing into the repo root. Both are the same shape of defect: **a property asserted in
  prose and carried by a convention rather than by the API**, which holds exactly until the first
  caller that does not follow the convention. Neither changes the on-disk format, so `FORMAT_VERSION`
  stays at 1 (`3-0d/R7` — the format is unpinned; these are refusal paths, not shape changes).
- **Why the AC 8 verifier's ordering needed extracting, and what the extraction cost (`3-0d/R17`).**
  The replay drive order existed in THREE places — the runner's live fork (`match_runner.gd:601-608`,
  the original), AC 4's test, and the verifier — and only the first two were guarded. AC 4 proved the
  SAVE/LOAD path; it never touched the verifier's ordering, so the verifier could have drifted and
  printed a stable, wrong hash forever. The two TEST-SIDE copies are now one (`ReplayDrive.drive()`).
  **The runner's fork is deliberately NOT folded in and could not be:** it is `src/` code inside
  `_physics_process` and `src/` cannot depend on `test/`. It stays the ORIGINAL, named in the
  helper's docstring so a change there has somewhere to point. **Neither caller was weakened:** the
  one thing that can legitimately go wrong (an unsound recorded content order, `3-0c/R11`) travels
  back as a reason in a result Dictionary — the test asserts on it, the operator tool prints it and
  exits nonzero. The verifier's `Invariant.check` crash became a printed `REFUSED:` line and exit 1,
  which is strictly better for an operator tool and still loud. **Running the extracted verifier for
  real immediately earned its keep:** it caught a parse error (a shadowed `result` local) that the
  suite structurally cannot see, because `test/tools/replay_file.gd` is deliberately not globbed by
  `run_all.sh`. A tool outside the suite must be RUN as part of any pass that edits it. **CLOSED AT
  `3-0d/R24`: "must be run by a human" is a process promise, which this story has already learned is
  not a mechanism. The suite runs it now — see the `3-0d/R24` bullet below.**
- **THE LESSON THIS STORY EXISTS TO TEACH, AND IT OUTLIVES EVERY MECHANISM IN IT (`3-0d/R20`):
  PREFER MAKING A PROPERTY IMPOSSIBLE BY CONSTRUCTION OVER MAKING IT DETECTABLE BY INSPECTION; AND
  WHEN A GUARD HAS BEEN EVADED TWICE, REPLACE THE MECHANISM RATHER THAN THE PATTERN.** Three review
  rounds, three defeats, and the shape was identical each time: a scan shipped, an adversary found a
  form outside it, the pattern was widened, and the next adversary found a form outside the wider
  one. `3-0d/R14` had already drawn the correct narrower lesson (enumerate what is ALLOWED, not what
  is FORBIDDEN) and the whitelist built on it was evaded BY ITS OWN CLASSIFIER — `(replay_record) =
  null`, a literal assignment, certified as an "argument read" because the next character was `)`.
  That is the moment the pattern-level remedy is exhausted: **the guard's failures had stopped being
  about the pattern and started being about the fact that it was reading text at all.** Two further
  holes made it unarguable — the line reader truncated at a `#` inside a STRING LITERAL, blanking
  the rest of the line for both scans, and both read `.gd` only while `.tscn`-embedded GDScript
  under `src/` is shipped, compiled, executing code. The genuinely undecidable residue (a property
  name built at runtime, reflection over the property list) was always narrow; the PRACTICAL residue
  kept being wide, and **a guard believed to hold that does not is worse than no guard**, because
  the belief is what stops anyone looking. The remedy is not a better classifier. It is to make the
  thing being hunted INERT: `replay_record` is consumed once, so nothing a load control could do has
  an effect, and the claim that used to need proving no longer needs to be true of the source at all.
- **HOW TO TELL WHICH KIND OF CLAIM A SCAN IS MAKING (`3-0d/R20`), because half (a) of AC 11 SURVIVES
  and that is not an inconsistency.** A source scan is sound evidence for a question about CODE
  LAYOUT — where two statements sit relative to each other inside one known function of one known
  file, which is what AC 11 (a)'s tap-seat pin asserts and what a human editing that function would
  change. It is not sound evidence for a question about REACHABILITY — whether some behaviour can be
  provoked from anywhere in a tree, which is what half (b) asserted, and which admits an unbounded
  set of spellings, files and embedding formats. The two look alike (both are a scan over `src/`)
  and are not alike at all. The tap-seat scan additionally now STATES ITS OWN LIMIT in its docstring
  — the line reader is not string-aware — rather than leaving it implied, per `3-0d/R20` part 5's
  rule that no mechanism may be described as proving more than it proves.
- **`Dictionary.has()` IS TRUE FOR `null`, WHICH IS WHY `3-0d/R15` WAS INCOMPLETE (`3-0d/R21`).** R15
  validated that `RecordFile.REQUIRED_KEYS` are PRESENT before the rebuild, which closed the
  truncated-file path and left three inputs still reaching `_from_dictionary()`, still dying inside
  it, and still returning `{"record": null, "error": ""}` — the SAME empty-reason refusal, read as
  SUCCESS by any caller testing `error != ""`. The three: required keys present carrying WRONG
  TYPES, `null` under `reload_events`, `null` under `intents`. `REQUIRED_KEYS` is now a key -> TYPE
  map and each key's type is validated before the rebuild, with the refusal naming the key and what
  was found in it. **Proven by mutation:** with the type check disabled, the wrong-types file
  crashes inside the rebuild (`Invalid call. Nonexistent 'int' constructor`, `record_file.gd:292`)
  and comes back with an EMPTY error — the exact defect, reproduced.
- **A PREFIX TEST ON A STRING THAT CAN CONTAIN `..` IS NOT A CONTAINMENT TEST (`3-0d/R22`).**
  `3-0d/R16` shipped `path.begins_with("user://")`, which `user://../../x.rec` satisfies while
  landing two directories above the app's user data — MEASURED on this engine, not theorised:
  `user://../../escape.rec` globalises to `…/Roaming/Godot/escape.rec`. The path is now RESOLVED
  (globalised, then `simplify_path()`, which is what collapses `..`) and required to sit under the
  equally-resolved user root. **The trailing `/` in that comparison is load-bearing and is its own
  measured trap:** `user://../CardSoulsEvil/x.rec` resolves to `…/app_userdata/CardSoulsEvil/x.rec`,
  which HAS `…/app_userdata/CardSouls` as a STRING PREFIX and is a different directory — so the
  comparison is against the root PLUS its separator. **Proven by mutation:** reverted to the bare
  prefix test, the traversal cases genuinely WRITE files (`…/Roaming/Godot/test_3_0d_traversal.rec`
  and `…/app_userdata/test_3_0d_traversal.rec` both appeared, and were removed by hand); the test
  asserts non-existence at the RESOLVED native path, so it is a claim about the filesystem rather
  than about the string that was refused.
- **`ReplayDrive` REALLY IS THE RUNNER'S ORDER NOW, WHICH ITS DOCSTRING ALREADY CLAIMED (`3-0d/R23`).**
  It had drifted in two places, both INERT — which is precisely why they sat unnoticed. (1) The
  controllers were constructed LAST, after content injection; the runner builds them FIRST, before it
  has a MatchState. (2) The intents were sampled AFTER the recorded pushes; the runner samples at the
  TOP of `_physics_process`, above the `ticking` gate and so before the fork pushes anything. Both
  are inert only because `ReplayController.sample()` reads the record and never MatchState.
  **DECISION: MATCH THE RUNNER, statement for statement — not drop the docstring's claim.** The claim
  is the value: the entire reason this helper exists (`3-0d/R17`) is that a silent drift from the
  runner prints a stable, WRONG hash forever, and a transcription whose docstring admits it is only
  "a" replay order guards nothing. Matching cost two moved statements and no behaviour change — every
  hash in the suite is unmoved, which is itself the evidence that both divergences were inert.
- **A TOOL OUTSIDE THE SUITE IS NOW RUN BY THE SUITE (`3-0d/R24`), and the obvious guard would have
  been VACUOUS.** `test/tools/replay_file.gd` is deliberately not globbed by `run_all.sh`, so nothing
  ever loaded it and a parse error shipped. The tempting guard — `load()` the script and assert
  non-null — is worthless: **`load()` returns a non-null `GDScript` for a file that does not
  compile.** `can_instantiate()` IS the working discriminator and would have caught that parse
  error, but it proves only that the file COMPILES, which is strictly weaker than AC 8's claim. So
  the guard built is the real one: `test/integration/test_replay_verifier_tool.gd` writes a fixture
  record through `RecordFile`, launches the verifier as a SUBPROCESS in a fresh headless Godot
  (`OS.execute` on `OS.get_executable_path()`, so the same engine build), and asserts exit 0,
  `RESULT: PASS`, a completed replay, and **the same `CanonicalHash` across two invocations** — AC
  8's claim stated exactly, compared run-to-run and never against a literal (`3-0d/R18`). It also
  asserts a corrupted file is REFUSED with a nonzero exit, so the PASS is a verdict the tool can
  withhold. **The subprocess launch worked; no fallback was needed. Proven by mutation:** the
  `3-0d/R17` parse error reintroduced verbatim makes it RED with the engine's own message. AC 8 is
  self-verifying now rather than operator-only.

## Project Structure Notes

- `src/systems/balance_config_service.gd` — `reload()`'s `load()` call becomes a `ResourceLoader.load
  (..., CACHE_MODE_IGNORE)` call (AC 1). No new file.
- `src/systems/intent_recorder.gd` — gains NO new `capture_*` method (AC 3); the save/load round-trip
  (AC 4) needs a to-dict/from-dict shape somewhere — whether that lives as new methods on
  `IntentRecorder` itself or a sibling file under `src/systems/` is a HOW decision for the dev pass,
  constrained only by the existing `src/state/` exclusion (unaffected, this story touches no
  `src/state/` file) and by AC 4's round-trip requirement, not by a filename pinned here.
- `src/ui/debug/debug_instrument_panel.gd` — ~~gains EXACTLY ONE new control, SAVE, in-code,
  following the existing two-`CheckButton` pattern (AC 7).~~ **CORRECTED AT THE POST-REVIEW PASS
  (`3-0d/R19`): FALSIFIED BY THE `3-0d/R13` AMENDMENT AND LEFT UNCORRECTED HERE.** AC 7 was
  reformulated from a COUNT into an EXACT SET at `3-0d/R13` and the panel ships TWO new controls,
  SAVE and RELOAD — this line still said "exactly one" afterwards, which is simply false about
  shipped code. Correct text: **gains EXACTLY the SET of two new controls, `SaveRecord` and
  `ReloadBalance`, in-code, following the existing two-`CheckButton` pattern (AC 7, amended
  `3-0d/R13`).** No start control, no load control, no new `.tscn`, no new top-level `Control`.
- `test/tools/replay_file.gd` — NEW: the standalone headless verifier (AC 8), `extends SceneTree` on
  the `test/integration/` pattern, taking a `user://` record path as a command-line argument. Under
  `test/` deliberately — that is what gives it `CanonicalHash`. Not globbed by `run_all.sh`.
- `test/replay_drive.gd` — **NEW AT THE POST-REVIEW PASS (`3-0d/R17`)**: `class_name ReplayDrive`,
  the ONE copy of the replay drive order, called by BOTH `test/state/test_record_file.gd` (AC 4) and
  `test/tools/replay_file.gd` (AC 8). A library beside `test/canonical_hash.gd`, for the same
  reason — its callers are a state test and a test-space operator tool, and nothing in the shipped
  game replays a record from a file. Globbed by neither harness (`test/state/test_*.gd`,
  `test/integration/test_*.gd`); reached by `class_name`.
- `src/main/match_runner.gd` — gains the live-reload trigger's call site (AC 2) and whatever plumbing
  connects the panel's SAVE control to the recorder; does NOT touch the intent-tap seat, the `ticking`
  gate, the seven `connect_*` seams, ~~or `replay_record` (AC 10, AC 11).~~
  **AMENDED (`3-0d/R20`): `replay_record` IS touched, and deliberately — it is now CONSUMED ONCE in
  `_ready()` into a private `_replay_record` that every other consumer reads, which is what makes a
  mid-session assignment inert by construction. The public member's declaration, its assignability
  before tree entry, and AC 10's guarantees are all unchanged.**
- `test/integration/test_replay_entry_is_inert.gd` — **NEW AT THE STRUCTURAL FIX PASS
  (`3-0d/R20` part 2)**: the behavioural proof that a mid-session `replay_record` assignment does
  nothing. It is the mechanism that replaces the deleted source scan, so it belongs in `test/
  integration/` (the claim is about a live wired runner) and is globbed by `run_all.sh`.
- `test/integration/test_replay_verifier_tool.gd` — **NEW AT THE STRUCTURAL FIX PASS (`3-0d/R24`)**:
  runs `test/tools/replay_file.gd` as a subprocess and asserts its behaviour. Globbed by
  `run_all.sh`, which is the point — the tool it exercises deliberately is not.
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

**Follow-up pass, `3-0d/R13` (2026-08-05): Claude Sonnet 5** — the panel reload control, the amended
AC 7 pins, and this decision-log entry. The `Claude Opus 4.8` commit trailer stays the repo-wide
invariant, unaffected by which model actually did the work.

**POST-REVIEW FIX PASS, `3-0d/R14`-`3-0d/R19` (2026-08-05): Claude Opus 5 (`claude-opus-5`)** — the
hardened source scans, the `RecordFile` refusal paths, the `ReplayDrive` extraction, and the story
and decision-log corrections. Same invariant: the commit trailer reads `Claude Opus 4.8` on all three
commits regardless.

**STRUCTURAL FIX PASS, `3-0d/R20`-`3-0d/R24` (2026-08-05): Claude Opus 5 (`claude-opus-5`)** — the
THIRD and final round on the replay-entry guards. Both source scans DELETED and replaced by
structural consumption plus a behavioural test; the `RecordFile` type and path-normalisation
refusals; the `ReplayDrive` ordering matched to the runner; the AC 8 verifier brought under the
suite as a subprocess test. Same invariant: the commit trailer reads `Claude Opus 4.8` on all three
commits regardless of which model did the work.

**CLOSING FIX PASS, `3-0d/R25`-`3-0d/R29` (2026-08-05): Claude Sonnet 5** — the final verification
pass's outcome applied. Three FALSE sentences corrected (AC 5's totality claim, the decision log's
and the pins file's description of the mechanism test, AC 3's mechanism sentence), one VACUOUS
assertion deleted from the mechanism test, the verifier's wrong-object hole closed with a second
fixture, two load-bearing line citations re-anchored, and AC 11's residue made concrete. Same
invariant: the commit trailer reads `Claude Opus 4.8` on all three commits.

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
| 7 (`3-0d/R13` follow-up pass) | added a THIRD runner-reaching control — `load_record: Callable`, a `LoadRecord` button, `_on_load_pressed()` (the rejected LOAD control) | `test_replay_surface_pins.gd::test_the_panel_has_exactly_the_two_runner_reaching_controls` AND `test_record_save_control.gd`'s control-set check — BOTH went RED; restored from an out-of-repo copy, SHA-256 `0f92fb59fc24c97d3152665134e6b671196bfcaf0aecc1c3f180d5af7153b49a` verified identical before and after |

**`3-0d/R13` follow-up pass — layout MEASURED, not assumed** (throwaway script, deleted after run):
box `global_rect=[P: (276, 356), S: (600, 94)]` (unchanged), box `size=(600, 94)` vs
`combined_minimum_size=(423, 89)` (size exceeds minimum — nothing overflowed), `RecordControls`
(now two stacked buttons) `min_size=(126, 64)`, `Switches` (unchanged, two `CheckButton`s)
`min_size=(272, 64)` — both columns land on the same 64px minimum, well inside the 94px band;
`window.encloses(box)=true`.

**`3-0d/R13` follow-up pass — the RELOAD control run for real in the live scene**
(`test/integration/test_record_save_control.gd`): a live roll spends P1's stamina 50 -> 38
(`roll_stamina_cost` 12), RELOAD is pressed via the panel's own real-signal test pattern, and the
result is `reload control: stamina=38/50->50/50 reload_events=1->2`, `RESULT: PASS`.

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

**CORRECTION OF RECORD ON THAT HASH (`3-0d/R18`), and it is an EXPLANATION, not a defect.** The
review could not reproduce `5f465e7a…9d13`: it measured `d2f77f3e…92d0` from byte-identical record
files across two sessions. **AC 8's actual claim — the same file replays to the same hash, twice —
HOLDS, and was re-measured holding at this pass.** The hash above is **a function of the RUN that
produced the record, not a constant of this repo**, and the two runs differed: the dev pass's
throwaway producer PRESSED inputs (`p1_move_up`, `p1_attack`); the review's pressed none. Different
intents, different final `MatchState`, different `CanonicalHash` — correctly. **Why the two runs
looked identical and so the difference was invisible:** the verifier's summary line prints
`ticks / reload_events / seed / deck / costs / order / camera_pushes / contact_facts` and **NOTHING
ABOUT THE INTENTS THEMSELVES**, so two records that differ ONLY in what was pressed print the same
summary and different hashes. Anyone comparing a hash to this record must reproduce the PRODUCING RUN
first; quoting the number without its producer is what made it look like a broken claim.

**POST-REVIEW FIX PASS — FOUR MUTATION PROOFS, EVERY ONE IN AN EVASION FORM (`3-0d/R14` part 4).**
The prior pass's proofs were performed in the author's own syntax and are therefore superseded for
these two pins: an annotated `Callable` and a bare `replay_record = ...` prove only those spellings.
Each break below was applied, observed RED, then restored FROM A COPY TAKEN OUTSIDE THE REPO (the
scratchpad, never `git checkout --`), with SHA-256 verified identical before and after —
`match_runner.gd` `cdc452aaf802529587d6449d7a64cccfad917f55a2e5a8f7f09e88f77e61cc5d`,
`debug_instrument_panel.gd` `0f92fb59fc24c97d3152665134e6b671196bfcaf0aecc1c3f180d5af7153b49a`.
`git status` after all four confirms neither file is modified.

| # | Evasion form applied | Observed |
|---|----------------------|----------|
| 1 | `set("replay_record", rec)` in `match_runner.gd` | `test_replay_surface_pins.gd::test_replay_record_is_assigned_nowhere_in_src` RED — `got 1, expected 0 ... res://src/main/match_runner.gd:661  set("replay_record", rec)` |
| 2 | `set_deferred("replay_record", rec)` | same test RED — `... match_runner.gd:660  set_deferred("replay_record", rec)` |
| 3 | `runner[&"replay_record"] = rec` (indexed property write) | same test RED — `... match_runner.gd:661  runner[&"replay_record"] = rec` |
| 4 | `var load_record := Callable()` + a `LoadRecord` button + `_on_load_pressed()` — the rejected LOAD control declared in the INFERRED form | `test_replay_surface_pins.gd::test_the_panel_has_exactly_the_two_runner_reaching_controls` RED — `got ["load_record", "reload_balance", "save_record"], expected ["reload_balance", "save_record"]` AND `test_record_save_control.gd` RED — `got ["LoadRecord", "NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"]` |

**ALL THREE OF 1-3 PASSED THE OLD SCAN, COUNTED AS READS; 4 PASSED THE OLD PANEL SCAN UNSEEN.** That
is the whole content of `3-0d/R14`.

**THE VERIFIER RUN FOR REAL AFTER THE `3-0d/R17` EXTRACTION** (throwaway producer under
`test/tools/`, run headlessly then deleted; both `user://` files deleted afterwards). **The first
attempt did not run at all** — `Parse Error: There is already a variable named "result" declared in
this scope` at `replay_file.gd:80`, a shadowed local introduced by the extraction that the suite
structurally cannot catch, because this file is deliberately not globbed by `run_all.sh`. Fixed, then
two consecutive runs on the same file, identical output both times:
`ticks=30  reload_events=2  seed=4242  deck=4 cards  costs=4  order=[&"deck", &"costs"]`,
`camera_pushes=30  contact_facts=0`, `replayed 30 ticks to completion`, `CanonicalHash:
74cbe99bb216886e81c35b0ab9522f7bd0d6a8f316ddb87dd1281df89589931f`, `RESULT: PASS`, exit 0. **That
hash is this producer's, per `3-0d/R18` — it is not comparable to the dev pass's and is not a repo
constant.** Refusal paths re-exercised on the same tool: no argument -> `usage: ...`; a TRUNCATED
file (`intents` removed, version left intact) -> `REFUSED: user://post_review_probe_truncated.rec
carries format version 1 but is missing intents — it is truncated or was not written by this class`,
`RESULT: FAIL` — the `3-0d/R15` path, which before this pass returned an EMPTY error. `3-0d/R16`
proven in the same run: `RecordFile.save_record(record, "post_review.rec")` returned `refusing to
write post_review.rec — records go under user://, never into the project tree (`3-0d/R16`); use
RecordFile.path_for()` and the repo root was confirmed to contain no such file afterwards.

**STRUCTURAL FIX PASS (`3-0d/R20`-`3-0d/R24`) — ENGINE SEMANTICS MEASURED BEFORE ANY CODE WAS
WRITTEN** (throwaway probe under `test/tools/`, run headlessly then deleted; Godot 4.6.3). Path
resolution, for `3-0d/R22`: `globalize_path("user://")` -> `C:/Users/…/app_userdata/CardSouls/`, and
`.simplify_path()` STRIPS the trailing slash; `user://../../escape.rec` ->
`C:/Users/…/Roaming/Godot/escape.rec` (two directories ABOVE the user data — the escape);
`user://sub/../ok.rec` and `user://./ok.rec` both -> `…/CardSouls/ok.rec` (resolve back inside, so
the guard must be containment and not a ban on `..`); **`user://../CardSoulsEvil/escape.rec` ->
`…/app_userdata/CardSoulsEvil/escape.rec`, which has `…/app_userdata/CardSouls` as a STRING PREFIX
— the trap that makes the trailing `/` in the comparison load-bearing**; `res://escape.rec` ->
`C:/dev/cardsouls/escape.rec`; a bare `escape.rec` -> unchanged. Subprocess viability, for
`3-0d/R24`: `OS.get_executable_path()` -> `C:/Godot/godot.exe`, and `OS.execute(...)` with
`--headless --path <globalized res://> --script res://test/tools/replay_file.gd` returned exit 2
with the tool's own usage line captured in `output` — so the subprocess form works on this platform
and no fallback to `can_instantiate()` was needed.

**STRUCTURAL FIX PASS — FIVE MUTATION PROOFS, BEHAVIOURAL WHERE THE GUARD IS BEHAVIOURAL
(`3-0d/R20` DISCIPLINE).** Each break applied, observed RED, then restored FROM A COPY TAKEN OUTSIDE
THE REPO (the scratchpad — never `git checkout --`), SHA-256 verified identical before and after:
`match_runner.gd` `c2f58ccf4d8df29fb0cfc42fe855c868fafa6957b95add3343fb755bbd478f66`,
`debug_instrument_panel.gd` `2425e4d9fdfd86a912b187e1b975c032f4be4407ac3f698e8ecdf0137b1fc59a`,
`record_file.gd` `39465a0e8c297d32c324f9bc734c2a92e6c500919dbe600174636728532d218c`,
`replay_file.gd` `8d7501856f927467936eec9ee64ea0cc200c32a2f06ab0e8ea90e117e46e0637`.

| # | Break | Observed |
|---|-------|----------|
| 1 | the per-tick fork restored to the PUBLIC member — `if replay_record != null:` and its three `replay_record.replay_*` calls (`3-0d/R20` part 2's named falsifying change) | `test_replay_entry_is_inert.gd` RED, BOTH assertions firing: `poisoned-check=1234.000000` (the recorded reload really did land in live state) and `ticks 7->7 over frames 8->24` — `0 ticks over 16 frames`, recording silently frozen |
| 2 | a wired `LinkButton` LOAD control on the panel (`load_record` declared `@onready`, a `LoadRecord` LinkButton, `_on_load_pressed()`) | `test_record_save_control.gd` RED — `got ["LoadRecord", "NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"]` |
| 2b | **the same LinkButton control, with the query reverted to the OLD `"Button"`** — the hole `3-0d/R20` part 4 names | **`RESULT: PASS`, exit 0.** The old query is genuinely blind to a `LinkButton`; the hole was real, not theoretical |
| 3 | the `3-0d/R21` type check disabled (`for key in []`) | `test_record_file.gd::test_a_record_whose_required_keys_carry_the_wrong_types_is_refused_with_a_reason` RED — `SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor` at `record_file.gd:292`, then `assert_ne: both ""` — the empty-reason refusal, reproduced exactly |
| 4 | the `3-0d/R22` normalisation reverted to `path.begins_with("user://")` | `test_record_file.gd::test_a_save_path_that_escapes_the_user_directory_is_refused_and_writes_nothing` RED — three traversals accepted AND WRITTEN: `C:/Users/…/Roaming/Godot/test_3_0d_traversal.rec` and `C:/Users/…/app_userdata/test_3_0d_traversal.rec` both existed afterwards and were removed by hand |
| 5 | the `3-0d/R17` parse error reintroduced verbatim in `test/tools/replay_file.gd` (a shadowed `result` local) | `test_replay_verifier_tool.gd` RED — `Parse Error: There is already a variable named "result" declared in this scope`, `the verifier exited 0 (got 1)`, no `RESULT: PASS` line and an empty hash. **The blind spot that shipped a parse error last pass is closed** |

**A DEFECT IN THIS PASS'S OWN NEW TEST, FOUND BY ITS OWN MUTATION PROOF AND FIXED BEFORE IT
SHIPPED.** The first version of `test_replay_entry_is_inert.gd` took its only `max_hp` reading AFTER
the live reload trigger step — and the trigger re-applies the AUTHORED balance, which scrubs the
poisoned value a flipped fork had already written. Under mutation 1 that assertion stayed SILENT
while the fork was genuinely flipped (only the recording-frozen assertion fired). A reading was
added BEFORE the trigger (`POISON_CHECK_FRAME`), the mutation re-run, and both assertions then
fired. **This is `3-0d/R14`'s lesson applied to a behavioural guard: the mutation proof is what
found it, and a proof that had only checked "does the test go red at all" would have passed it.**

**CLOSING FIX PASS (`3-0d/R25`-`3-0d/R29`) — THE FIVE `3-0d/R25` INPUTS, MEASURED BEFORE THE
SENTENCE THEY FALSIFY WAS REWRITTEN** (throwaway probe under `test/tools/`, run headlessly then
deleted; Godot 4.6.3). A valid 4-tick record was written through `RecordFile`, read back as a raw
Dictionary, mutated one axis at a time and re-loaded. **All five returned `record=null error=''`:**

| Input | Engine error inside the rebuild | `load_record` returned |
|-------|--------------------------------|------------------------|
| `intents` as an Array of Dictionaries | `Invalid type in function '_intent_pair' ... Cannot convert argument 1 from Dictionary to Array` (`record_file.gd:311`) | `record=null error=''` |
| `intents` shorter than `tick_count` | `Out of bounds get index '1' (on base: 'Array')` (`record_file.gd:311`) | `record=null error=''` |
| `camera_pushes` values are ints | `Trying to assign value of type 'int' to a variable of type 'Array'` (`record_file.gd:307`) | `record=null error=''` |
| `contacts` values are Arrays of ints | `Trying to assign value of type 'int' to a variable of type 'Array'` (`record_file.gd:309`) | `record=null error=''` |
| `tick_count` inflated past intents | `Out of bounds get index '4' (on base: 'Array')` (`record_file.gd:311`) | `record=null error=''` |

Every one is the empty-reason refusal `3-0d/R15` was raised to close and `3-0d/R21` narrowed —
still open on nested and cross-key shapes, which is what AC 5 now says instead of claiming totality.

**CLOSING FIX PASS — THE `3-0d/R28` VACUITY, PROVEN RATHER THAN ASSERTED.** The deletion needed no
mutation proof, but the claim that the assertion was VACUOUS is itself a claim, so it was measured:
`match_runner.gd`'s per-tick fork was restored to the PUBLIC member (the `3-0d/R20` falsifying
change) and `test_replay_entry_is_inert.gd` run. Output:
`max_hp authored=100.000000 before=100.000000 poisoned-check=1234.000000 after=100.000000`,
`recording: ticks 7->7 over frames 8->24`. **TWO assertions fired — the poisoned-check reading and
the frozen tick count. `_after_max_hp` did NOT**, because `TRIGGER_FRAME` (12) sits between
`POISON_CHECK_FRAME` (10) and `MEASURE_FRAME` (24) and the trigger re-applies the AUTHORED balance,
scrubbing the poison. It could not fail for the reason it named. Restored from an out-of-repo copy,
SHA-256 `c2f58ccf4d8df29fb0cfc42fe855c868fafa6957b95add3343fb755bbd478f66` verified identical.

**CLOSING FIX PASS — THE `3-0d/R25` N2 RESIDUE, MEASURED RATHER THAN RECORDED ON TRUST.** The
four-line per-tick consumer of the PUBLIC member quoted in AC 11's residue paragraph — swapping both
live keyboard controllers for `ReplayController`s mid-match — was installed in `match_runner.gd` and
the FULL SUITE run: **348 tests / 0 failed / 2264 assertions, ALL TESTS PASSED.** The residue is
therefore stated as a fact of this tree, not as a worry. Restored from the same out-of-repo copy,
SHA-256 identical, `git status` clean.

**CLOSING FIX PASS — THE `3-0d/R29` MUTATION PROOF, AND IT LANDED EXACTLY ON THE NEW ASSERTION.**
`test/tools/replay_file.gd` was made to hash the WRONG OBJECT: a fresh `MatchState` built from the
record's own injected channels (seed, balance, flags, content) but NEVER ADVANCED — deterministic,
so run-to-run equality still holds. Green beforehand, the test printed two different hashes
(`60a9fe78…cb0e` and `cf037927…7de2`). Under the mutation **both fixtures printed the SAME hash,
`ec631c0d9707ac9d1b6a3118f2654962302c23f44e8cbca3de59622d30eac137`**, the run-to-run equality
assertion still PASSED, and the ONLY failure was the new one:
`FAILED: TWO RECORDS THAT DIFFER ONLY IN THEIR RECORDED INTENTS PRINT DIFFERENT HASHES ... RESULT:
FAIL`. That is `3-0d/R20`'s part (c) satisfied — the RIGHT assertion fired, not merely some
assertion. Restored from an out-of-repo copy, SHA-256
`7541d1a2f2bfb84e8597a289253d2e060df53c24af091234c4f2b100a95eec2a` verified identical before and
after.

### Completion Notes List

- **CLOSING FIX PASS SUITE (`3-0d/R25`-`3-0d/R29`). Before, verified BY THIS PASS at `HEAD`
  `2fe3eca` with a clean tree before any edit: 348 state tests / 2264 assertions / 22 integration
  files, ALL PASSED — the stated baseline, confirmed rather than taken on trust. After: 348 / 2264 /
  22 — ZERO movement in all three, ALL PASSED.** That flatness is real and is explained rather than
  left to look like nothing happened: **every assertion this pass touched lives in an INTEGRATION
  file, and the state harness's 2264 cannot see them.** The integration delta, counted directly:
  `test_replay_entry_is_inert.gd` 10 assertions -> 9 (`3-0d/R28`'s vacuous `_after_max_hp` reading,
  DELETED — the value is still measured and printed, it is simply no longer pretending to guard),
  and `test_replay_verifier_tool.gd` 12 -> 16 (`3-0d/R29`'s second fixture: written, verified, hash
  non-empty, hash DIFFERENT). **Net +3 integration assertions, -1 state-visible anything.** No new
  file, no new `class_name`, no editor scan needed. `project.godot` untouched and BYTE-IDENTICAL,
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`. Golden unmoved,
  `test_determinism.gd` absent from `git status`, `GOLDEN` still
  `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four inherited `3-0c` pins
  required ZERO edits. `src/main/match_runner.gd` is UNMODIFIED — a mutation target twice this pass,
  restored and SHA-256 verified both times, absent from `git status`.
- **THE HEADLINE OF THIS PASS: THE `3-0d/R20` MECHANISM HELD; THE PROSE AROUND IT DID NOT.** The
  final verification attacked the structural mechanism against a criterion declared in advance —
  eight attacks at six different moments, no mid-session assignment to the public `replay_record`
  did anything. It failed only on the second criterion, that the story and the log be TRUE of the
  shipped tree: **three sentences were false.** AC 5 claimed refusals-with-reasons hold on EVERY
  path (five inputs say otherwise, all five measured here); the `3-0d/R20` decision-log entry and
  `test_replay_surface_pins.gd`'s header both said the mechanism test asserts "no recorded fact
  reaches live state" (it asserts the LIVE RELOAD TRIGGER STILL FIRES); and AC 3 said its test
  counts `func capture_` occurrences (it reads `get_script_method_list()`). Each is corrected IN
  PLACE with the correction visible. **This is the story's own lesson turned on its own documents:**
  `3-0d/R20` ruled that no mechanism may be described as proving more than it proves, and three
  descriptions were doing exactly that within one pass of the ruling.
- **`3-0d/R28`: A VACUOUS ASSERTION DELETED FROM THE FILE THAT IS THE MECHANISM**, which is the
  worst place to keep one. `_after_max_hp` was the UN-FIXED TWIN of the defect the previous pass
  found and fixed for the earlier reading — the trigger scrubs the poison before that frame, so it
  held while the fork was genuinely flipped. Measured, then deleted, with the docstring saying WHY
  it was removed rather than kept. Same ruling: the poisoned record's tripwire is **ONE CHANNEL
  WIDE** — only the reload event is observable; the contact fact is dropped at resolution because
  the attacker is idle and `register_swing_hit` refuses (`hero_state.gd:228-230`), and the camera
  basis cannot move a `move_dir` that is zero. Stated in the docstring instead of implying three
  live channels; making the other two observable was weighed and rejected.
- **`3-0d/R29`: THE VERIFIER TEST NO LONGER PASSES A VERIFIER THAT HASHES THE WRONG OBJECT.** Run-to-
  run equality is satisfied by any deterministic function of nothing in particular. A SECOND fixture
  — identical in seed, balance, flags, deck, costs, bases, contact and tick count, differing ONLY in
  the recorded intents — must now hash DIFFERENTLY. Proven by mutation, and the mutation landed on
  exactly that assertion while the equality assertion stayed green. Same ruling: the two
  deliberately load-bearing line citations (`ReplayDrive`'s docstring, `replay_file.gd`'s comment,
  both pointing at the runner's fork "so a change there has somewhere to point") are RE-ANCHORED by
  locating the content — `match_runner.gd:601-608` -> **629-633**; the file grew 115 lines and the
  old citation lands on the HUD card-selection push. Not swept: the standing carve-out holds.
- **ONE FURTHER STALE CITATION VERIFIED AND DELIBERATELY LEFT** (`3-0d/R29`, "report but do not
  sweep"): this file's own `3-0d/R17` Dev Note carries the same `match_runner.gd:601-608` pointer
  and it is equally stale. It is NOT one of the two the ruling made load-bearing, so it stands with
  the rest of the un-anchored citations under the standing carve-out.
- **LIVE SMOKE NOT RUN** — unchanged: it is the operator's and carries the required R-D6 kill
  (`3-0d/R11`). This pass was explicitly instructed not to run it.
- **STRUCTURAL FIX PASS SUITE (`3-0d/R20`-`3-0d/R24`). Before, verified BY THIS PASS at `HEAD`
  `a6582e8` with a clean tree before any edit: 348 state tests / 2244 assertions / 20 integration
  files, ALL PASSED — the stated baseline, confirmed rather than taken on trust. After: 348 / 2264 /
  22 — 0 net state tests, +20 assertions, +2 integration files. ALL PASSED both ends**, and green a
  third time after all five mutations were restored. **THE FLAT STATE-TEST COUNT IS A COINCIDENCE OF
  TWO OPPOSITE MOVEMENTS AND IS STATED RATHER THAN LEFT TO LOOK LIKE "NOTHING CHANGED":**
  `test_replay_surface_pins.gd` went 4 tests -> 2 (the two deleted source scans, `3-0d/R20` parts 3
  and 4 — this is the DROP the ruling predicted), and `test_record_file.gd` went 9 -> 11 (`3-0d/R21`'s
  wrong-types refusal, `3-0d/R22`'s traversal refusal). The assertion delta is the same story: the
  two deleted scans carried large evasion-form self-check loops, and what replaced them is two
  integration files the state count cannot see. **The +2 integration files are the mechanisms this
  ruling installs** — `test_replay_entry_is_inert.gd` (`3-0d/R20` part 2) and
  `test_replay_verifier_tool.gd` (`3-0d/R24`). `project.godot` BYTE-IDENTICAL,
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, both ends. Golden unmoved,
  `test_determinism.gd` absent from `git status`, `GOLDEN` still
  `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four inherited `3-0c` pins
  required ZERO edits. `test/tools/replay_file.gd` is UNMODIFIED (mutation target only, restored and
  hash-verified — absent from `git status`).
- **THE HEADLINE OF THIS PASS: THE PROPERTY MOVED FROM DETECTABLE TO IMPOSSIBLE (`3-0d/R20`).**
  `MatchRunner` consumes `replay_record` once in `_ready()` into `_replay_record`; the per-tick fork,
  the live-reload refusal and every other consumer read only the private field. Both source scans
  are DELETED — not kept as lints, per the ruling, because keeping an evaded guard produces false
  confidence about a property now carried by construction. The external pre-tree assignment
  (`test_replay_contacts.gd`) is unaffected and still enters replay: VERIFIED, that test passes
  unmodified in the suite, which is what makes this a consumption point rather than a removal.
- **AC 7 and AC 11 RE-WORDED TO WHAT THE MECHANISMS CARRY (`3-0d/R20` part 5), with the residue
  stated in both.** AC 11's retired claim — a source scan asserting `replay_record` is assigned
  nowhere in `src/` — is replaced by structural consumption plus its behavioural test. AC 7 no
  longer claims a source scan makes a load control impossible; it claims the panel's INSTANTIATED
  control set is exactly the expected four names, queried as `BaseButton` rather than `Button` so a
  `LinkButton` cannot slip past. Falsified passages elsewhere in this file are corrected IN PLACE
  with the correction visible (struck through, never deleted), including two that `3-0d/R19` had
  already corrected once and that this ruling falsifies again.
- **`3-0d/R21`, `3-0d/R22`, `3-0d/R23`, `3-0d/R24` all closed**, each with a mutation proof: the
  `RecordFile` type validation (three inputs: wrong types, `null` under `reload_events`, `null`
  under `intents`); the save-path NORMALISATION replacing the bare prefix test, with the traversal
  forms tested and **nothing landing in the repo — verified by running it** (a tree-wide search for
  `*.rec` outside `.godot/` returns nothing); the `ReplayDrive` ordering MATCHED to the runner
  statement for statement (the decision taken, over dropping the docstring's claim); and the AC 8
  verifier run BY THE SUITE as a subprocess, which landed as the real subprocess test with NO
  fallback.
- **LIVE SMOKE NOT RUN** — unchanged: it is the operator's and carries the required R-D6 kill
  (`3-0d/R11`). This pass was explicitly instructed not to run it.
- **POST-REVIEW FIX PASS SUITE (`3-0d/R14`-`3-0d/R19`). Before, verified at `HEAD` `d433b41` with a
  clean tree before any edit: 344 state tests / 2198 assertions / 20 integration files, ALL PASSED.
  After: 348 / 2244 / 20 — +4 state tests, +46 assertions, 0 new integration files. ALL PASSED both
  ends**, and re-run green a third time after all four mutations were restored. The +4 are `3-0d/R15`
  and `3-0d/R16`'s new refusal tests in `test_record_file.gd` (truncated file; no-version-key branch;
  save outside `user://`; the `REQUIRED_KEYS` derivation guard); the +46 assertions are those plus
  the two hardened scans' evasion-form self-checks. `project.godot` BYTE-IDENTICAL,
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, both ends. Golden unchanged,
  `test_determinism.gd` absent from `git status`, `GOLDEN` still
  `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four inherited `3-0c` pins
  required ZERO edits, confirmed by `git status`. `src/main/match_runner.gd` and
  `src/ui/debug/debug_instrument_panel.gd` are UNMODIFIED by this pass — they were mutation targets
  only, restored and hash-verified.
- **POST-REVIEW: THE BLOCKING FINDING (B1) AND WHAT IT COST TO CLOSE.** Both of this story's new
  source scans were evadable and their non-vacuity checks proved only the author's own syntax. Fixed
  structurally, not by adding two more patterns: the `replay_record` scan is now a WHITELIST of four
  allowed read forms with everything else an offender by default (`3-0d/R14` part 1), and the panel
  scan matches `Callable` in ANY declaration form plus invocation (`3-0d/R14` part 2). The permanent
  lesson is in the Dev Notes and in the decision log (`3-0d/R14` part 3). Re-proven by four mutations
  in the evasion forms (`3-0d/R14` part 4) — see Debug Log References.
- **POST-REVIEW, non-blocking, all five closed:** `3-0d/R15` (the empty-reason refusal on a truncated
  record, plus the untested no-version-key branch, plus a `REQUIRED_KEYS` derivation guard);
  `3-0d/R16` (`save_record` refuses a path outside `user://`); `3-0d/R17` (the verifier's ordering
  extracted to `ReplayDrive` and thereby brought under AC 4's cover — and the Dev Notes claim that
  AC 4 already covered it corrected, it covered the save/load path only); `3-0d/R18` (the AC 8 hash
  is a function of its producing run, not a constant — corrected in Debug Log References with WHY two
  runs can print identical summaries and different hashes); `3-0d/R19` (the two passages left
  contradicting the amended AC 7, corrected in place with the correction visible).
- **`3-0d/R13` FOLLOW-UP PASS SUITE. Before (re-verified by stashing this pass's edits and running
  clean at `HEAD` `dfebbb0`): 344 state tests / 2197 assertions / 20 integration files, ALL PASSED.
  After: 344 / 2198 / 20 — +1 assertion (the amended AC 7 pin's two-handler membership loop), 0 new
  tests, 0 new integration files (an existing integration file extended, not added). ALL PASSED both
  ends.** `project.godot` re-verified BYTE-IDENTICAL,
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, both ends. Golden unchanged,
  `test_determinism.gd` absent from `git status`. The four inherited `3-0c` pins required ZERO
  edits, confirmed by `git status`.
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
- **AC 7 (amended `3-0d/R13`)** — TWO new controls: `SaveRecord` and `ReloadBalance`, both `Button`s
  stacked in a THIRD COLUMN of the existing box (a third ROW would have pushed the panel out of the
  empty y[356,450] band and over the vitals bars — `test_debug_instruments.gd`'s S1/S2 layout
  assertion still passes UNMOVED, so the re-fit is verified, not assumed; MEASURED this pass with a
  throwaway script: box `global_rect` unchanged at x[276,876] y[356,450], `RecordControls`'s two-button
  minimum height (64px) matches the `Switches` column's own two-row minimum, both well inside the 94px
  band). Each wired by its own runner-owned `Callable` set before `add_child` — `save_record` and
  `reload_balance`, the latter set to the already-shipped `trigger_live_balance_reload()`. Pinned at
  EXACTLY the two-member SET of Callables and handlers by a scan that also forbids a signal and any
  third member — the pin amended from a count to a set at `3-0d/R13` because AC 11's `replay_record`
  scan, not this pin's control count, is what actually keeps a load control out (mutation proof this
  pass: a third `load_record` Callable + `LoadRecord` button fails BOTH the structural pin and the
  scene-level control-set check).
- **AC 8** — `test/tools/replay_file.gd`, `extends SceneTree` + `_initialize()`, deliberately not
  globbed by `run_all.sh`. Run twice on a real runner-produced record for the same hash; see Debug
  Log References for both outputs.
- **AC 9** — the per-pool contract is exercised UNCHANGED by the live trigger: stamina refills to
  the new maximum (ratified correct, `3-0d/R10`), mana keeps its earned value under the new bound,
  hp is preserved and never re-healed, on both players.
- **AC 11** — both halves shipped as one source scan each, with their patterns proven against the
  exact strings they exist to catch (an assignment matches, a `!=`/`==` comparison does not), and
  both proven RED by mutation (proofs 1 and 2).
- **CONTRACT CONFLICT FOUND AT THE PRIOR PASS (`f5da20c`), NOW RESOLVED (`3-0d/R13`) — AC 7 vs the
  Live Smoke.** The prior pass found: AC 7 pinned the panel at EXACTLY ONE new control (SAVE) with a
  structural test counting runner-reaching controls at one, so a RELOAD button was a second and was
  refused, while the Live Smoke's third bullet asks the operator to "trigger a live mid-match balance
  reload from the panel" — requiring exactly that second control. That pass built to the AC, not to
  the smoke, correctly, and left the conflict recorded rather than picking a side. **Operator ruling
  (`3-0d/R13`, decision-log Session 2026-08-05 — Story 3-0d, `3-0d/R13` panel reload control):** AC
  7's "exactly one" was never protecting a COUNT, it was protecting against a LOAD control
  (`3-0d/R2`) — a property AC 11's `replay_record` source scan already carries structurally,
  independent of button count. AC 7 is reformulated from a count into an exact SET, `{SaveRecord,
  ReloadBalance}`, and the panel gains RELOAD, wired to the already-shipped
  `trigger_live_balance_reload()`. The smoke's reload step and stamina-refill observation are now
  performable.
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
- `src/main/match_runner.gd` — `_save_index`; `panel.save_record = save_recorded_stream` and
  (`3-0d/R13`) `panel.reload_balance = trigger_live_balance_reload` wiring; `save_recorded_stream()`
  (AC 7); `trigger_live_balance_reload()` (AC 2, its own trigger logic unchanged this pass — only its
  doc comment updated to record the resolved conflict). The intent-tap seat, the `ticking` gate,
  `_physics_process`'s structure, the seven `connect_*` seams and `replay_record` are ALL untouched
  (AC 10/AC 11).
- `src/ui/debug/debug_instrument_panel.gd` — the `save_record` Callable and, this pass (`3-0d/R13`),
  a second Callable `reload_balance`; `_build_save_control()` renamed `_build_record_controls()` and
  extended with the `ReloadBalance` button; `_on_save_pressed()` and, this pass, `_on_reload_pressed()`
  (AC 7).

**New — tests**
- `test/state/test_live_reload.gd` (+ `.uid`) — AC 2, AC 3, AC 9, and the runner's call-site scan.
- `test/state/test_record_file.gd` (+ `.uid`) — AC 4, AC 5, AC 6.
- `test/state/test_replay_surface_pins.gd` (+ `.uid`) — AC 7 structural, AC 11 (both halves). This
  pass (`3-0d/R13`) amends the AC 7 test from a one-member count to a two-member exact SET; AC 11 is
  UNTOUCHED.
- `test/integration/test_record_save_control.gd` (+ `.uid`) — AC 7 in the live scene. This pass
  (`3-0d/R13`) amends the control-set assertion to the four-name set and adds the live RELOAD proof
  (reload event count + stamina refill through the StateInspector's own label).
- `test/tools/replay_file.gd` (+ `.uid`) — AC 8, the headless verifier. NOT globbed by `run_all.sh`.
  POST-REVIEW (`3-0d/R17`): its replay drive order is now `ReplayDrive.drive()`, not its own copy.
- `test/replay_drive.gd` (+ `.uid`) — **NEW AT THE POST-REVIEW PASS (`3-0d/R17`)**: `class_name
  ReplayDrive`, the ONE copy of the replay drive order, shared by AC 4's test and AC 8's verifier.
  The one new `class_name` this pass ships; editor scan run and `.uid` committed.

**Modified — tests**
- `test/state/test_balance_config.gd` — gains AC 1's object-identity test; nothing removed.
- `test/state/test_record_file.gd` — POST-REVIEW: gains `3-0d/R15`'s truncated-record and
  no-version-key tests, `3-0d/R16`'s outside-`user://` refusal test, and the `REQUIRED_KEYS`
  derivation guard; its `_replay()` now calls `ReplayDrive.drive()` (`3-0d/R17`). Nothing removed.
- `test/state/test_replay_surface_pins.gd` — POST-REVIEW: BOTH scans hardened (`3-0d/R14`) — the
  `replay_record` scan inverted into a whitelist, the panel Callable scan widened to any declaration
  form plus invocation, and both self-checks extended with the evasion forms. AC 11 (a), the tap
  seat, is UNTOUCHED.

**Modified — source, post-review**
- `src/systems/record_file.gd` — `REQUIRED_KEYS` validated before the rebuild (`3-0d/R15`) and
  `REQUIRED_PATH_PREFIX` refusing a save outside `user://` (`3-0d/R16`). `FORMAT_VERSION` stays 1:
  neither is a change to the on-disk shape.

**New — tests, at the STRUCTURAL FIX PASS (`3-0d/R20`-`3-0d/R24`)**
- `test/integration/test_replay_entry_is_inert.gd` (+ `.uid`) — **`3-0d/R20` part 2, THE MECHANISM
  that replaces the deleted `replay_record` source scan.** Assigns `replay_record` mid-match on a
  live runner and asserts the fork does not flip, recording continues, and the live reload trigger
  still fires. Editor scan run, `.uid` committed. No new `class_name`.
- `test/integration/test_replay_verifier_tool.gd` (+ `.uid`) — **`3-0d/R24`**, the AC 8 verifier run
  as a SUBPROCESS by the suite: fixture record written through `RecordFile`, two invocations, same
  `CanonicalHash`, plus a refusal path. Editor scan run, `.uid` committed. No new `class_name`.

**Modified — source, at the STRUCTURAL FIX PASS**
- `src/main/match_runner.gd` — **`3-0d/R20` part 1**: the new private `_replay_record`, the ONE read
  of the public `replay_record` in `_ready()`, and every consumer (the per-tick fork,
  `trigger_live_balance_reload`) moved onto the private field. Its docstring claim that AC 11's
  source scan carries the protection is corrected in place. The intent-tap seat, the `ticking` gate,
  `_physics_process`'s structure and the seven `connect_*` seams are untouched.
- `src/systems/record_file.gd` — **`3-0d/R21`** (`REQUIRED_KEYS` becomes a key -> TYPE map, validated
  before the rebuild) and **`3-0d/R22`** (`_outside_user_directory`, path normalisation replacing the
  bare prefix test). `FORMAT_VERSION` stays 1: neither is a change to the on-disk shape.
- `src/ui/debug/debug_instrument_panel.gd` — comments only: three passages naming the two deleted
  scans corrected to what actually carries the property. No behaviour change.

**Modified — tests, at the STRUCTURAL FIX PASS**
- `test/state/test_replay_surface_pins.gd` — **BOTH SOURCE SCANS DELETED** (`3-0d/R20` parts 3 and 4),
  4 tests -> 2. What remains is AC 11 (a)'s tap seat and AC 7's path predictability; the header now
  records all three evasion rounds and the ruling, and the tap-seat test states its own reader limit.
- `test/integration/test_record_save_control.gd` — **`3-0d/R20` part 4**: the control query is
  `BaseButton`, not `Button`, with a non-vacuity check that the query SEES a `LinkButton`; docstrings
  updated to record that this is now the whole panel pin rather than half of one.
- `test/state/test_record_file.gd` — gains `3-0d/R21`'s wrong-types test and `3-0d/R22`'s traversal
  test; the `REQUIRED_KEYS` derivation guard now derives the TYPES as well as the key set. Nothing
  removed.
- `test/replay_drive.gd` — **`3-0d/R23`**: controller construction and intent sampling moved to match
  the runner's order statement for statement. No behaviour change; every hash in the suite unmoved.

**Modified — at the CLOSING FIX PASS (`3-0d/R25`-`3-0d/R29`)**
- `src/systems/record_file.gd` — **`3-0d/R25`**, COMMENTS ONLY, no behaviour change: the header's
  "true of EVERY path" clause struck, and a RESIDUE block added naming the five measured inputs that
  still refuse with an empty reason, the deliberate decision not to build nested validation, and the
  consequence for callers (test the record, never the reason).
- `test/integration/test_replay_entry_is_inert.gd` — **`3-0d/R28`**: the vacuous `_after_max_hp`
  assertion DELETED (struck in place, with the reason in the docstring), and the docstring corrected
  to say the tripwire is ONE CHANNEL WIDE. `_after_max_hp` is still measured and printed.
- `test/integration/test_replay_verifier_tool.gd` — **`3-0d/R29`**: a SECOND fixture record
  differing only in its recorded intents, asserted to hash DIFFERENTLY. The existing run-to-run
  equality assertion is kept; this is an addition. +4 assertions.
- `test/replay_drive.gd`, `test/tools/replay_file.gd` — **`3-0d/R29`**, COMMENTS ONLY: the two
  load-bearing runner-fork citations re-anchored `601-608` -> `629-633`.
- `test/state/test_replay_surface_pins.gd` — **`3-0d/R26`**, HEADER COMMENT ONLY: the mechanism
  test's third assertion described correctly ("the live reload trigger still fires", not "no
  recorded fact reaches live state").

**Deliberately untouched at the CLOSING FIX PASS:** `src/main/match_runner.gd` (mutation target
twice, restored and SHA-256 verified both times — absent from `git status`), `project.godot`, the
golden, the four inherited `3-0c` pins, everything under `src/state/`, and the board.

**Deliberately untouched at the STRUCTURAL FIX PASS:** `test/tools/replay_file.gd` (mutation target
only, restored and SHA-256 verified — absent from `git status`), `project.godot`, the golden, the
four inherited `3-0c` pins, and everything under `src/state/`.

**Deliberately untouched at the post-review pass:** `src/main/match_runner.gd` and
`src/ui/debug/debug_instrument_panel.gd` (mutation targets only, restored and SHA-256 verified),
`test/state/test_live_reload.gd`, `test/integration/test_record_save_control.gd`,
`test/state/test_balance_config.gd`, and everything below.

**Deliberately untouched:** `project.godot` (hash identical), `docs/game-architecture.md` (the
ELEVENTH amendment-queue member stands, `3-0d/R12`), `src/systems/intent_recorder.gd`,
`src/controllers/replay_controller.gd`, everything under `src/state/`, `test_determinism.gd`, and
the four inherited `3-0c` pins.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-05 | 0.7 | **CLOSING FIX PASS (`3-0d/R25`-`3-0d/R29`) — THE `3-0d/R20` MECHANISM HELD; THREE SENTENCES ABOUT IT DID NOT.** A final verification pass attacked the structural mechanism against a criterion declared in advance: **eight attacks at six different moments, and no mid-session assignment to the public `replay_record` did anything.** Criterion (a) HOLDS. It failed only on criterion (b) — that the story and the log be TRUE of the shipped tree — where three sentences were FALSE, plus five non-blocking findings. All close here. **`R25` (the substantive one):** AC 5's amendment header asserted "REFUSED WITH A CLEAR REASON NOW HOLDS ON EVERY PATH". It does not — **FIVE inputs still return `{"record": null, "error": ""}`**, measured before the sentence was rewritten: `intents` as an Array of Dictionaries; `intents` shorter than `tick_count`; `camera_pushes` values that are ints; `contacts` values that are Arrays of ints; `tick_count` inflated past the intents array. `3-0d/R21` had corrected the Dev Notes and the class docstring and left the AC standing. **RULED: the claim is REDUCED to what the code carries — each required key's TOP-LEVEL type is validated before the rebuild — and the residue is STATED: nested and cross-key consistency is NOT validated and such a file still refuses with an empty reason. Nested validation is DELIBERATELY NOT BUILT**; the point of the ruling is that the boundary gets written down instead of pretended away, and the residue is closed for callers instead (test the record, never the reason — all three shipped callers already do). Corrected in AC 5 and in the identical sentence in `record_file.gd`. **`R26`:** the `3-0d/R20` decision-log entry and `test_replay_surface_pins.gd`'s header both said the mechanism test asserts "no recorded fact reaches live state". It asserts no such thing — its third assertion is that the LIVE RELOAD TRIGGER STILL FIRES. The pins header is corrected in place; the decision log is APPEND-ONLY for entries, so that correction is recorded in the new `R25`-`R29` entry, naming the sentence it corrects. **`R27`:** AC 3 said its test "counts `func capture_` occurrences" — the shipped test reads `script.get_script_method_list()` and its own docstring says so. The outcome claim (exactly eight) was always true; only the mechanism sentence was wrong, and wrong in the direction this story has spent three rounds learning to distrust. **`R28`:** the mechanism test's `_after_max_hp` assertion was VACUOUS — the un-fixed twin of the defect the previous pass found and fixed for the earlier reading, since `TRIGGER_FRAME` sits between the two readings and the trigger re-applies the authored balance. **MEASURED under the falsifying mutation: `after=100.000000` while the fork was genuinely flipped, and only the OTHER two assertions fired.** DELETED, with the docstring saying why it was removed rather than kept — a vacuous assertion in the file that IS the mechanism is worse than one anywhere else. Same ruling: the poisoned record's tripwire is **ONE CHANNEL WIDE** (only the reload event is observable; the contact fact is dropped at resolution because the attacker is idle, and the camera basis cannot move a zero `move_dir`), now stated instead of implied. **`R29`:** the verifier subprocess test did not catch a verifier that hashes the WRONG OBJECT — run-to-run equality is satisfied by any deterministic function of nothing in particular. Closed cheaply by a SECOND fixture differing ONLY in its recorded intents, asserted to hash DIFFERENTLY; the equality assertion is kept. **Proven by mutation, and it landed on exactly the new assertion:** with the tool hashing a fresh `MatchState`, both fixtures printed `ec631c0d…c137`, equality still PASSED, and only the new check failed. Also `R29`: the two deliberately load-bearing runner-fork citations (`ReplayDrive`'s docstring, `replay_file.gd`'s comment) RE-ANCHORED `match_runner.gd:601-608` -> **629-633** by locating the content; not swept, and one further stale citation in this file's own Dev Notes is REPORTED and left. **AC 11's residue made CONCRETE (`N2`), because a residue nobody can picture is not really stated:** a four-line per-tick consumer of the public member that swaps both live keyboard controllers for `ReplayController`s mid-match was built, installed and run — **the ENTIRE SUITE STAYED GREEN, 348/2264/22.** The deleted scan would have flagged it. The guarantee is "assigning it does nothing to the shipped runner", NOT "nothing can read it", and `3-0d/R20`'s trade is recorded honestly: not strict dominance, but a guard believed-and-false swapped for a guarantee narrower-and-true. **Suite: baseline 348/2264/22 CONFIRMED BY THIS PASS at `HEAD` `2fe3eca`, after 348/2264/22, ALL PASSED both ends.** Zero movement in all three, explained rather than left ambiguous: every assertion touched lives in an INTEGRATION file the state count cannot see — inert test 10 -> 9, verifier test 12 -> 16, **net +3 integration assertions**. `project.godot` byte-identical; golden unmoved; the four inherited `3-0c` pins zero edits; `match_runner.gd` unmodified (mutation target twice, restored and hash-verified both times). Live smoke NOT run. Three commits, none pushed. | Claude Sonnet 5 |
| 2026-08-05 | 0.6 | **STRUCTURAL FIX PASS (`3-0d/R20`-`3-0d/R24`) — THE THIRD AND FINAL ROUND ON THE REPLAY-ENTRY GUARDS, and the ruling is that there will not be a fourth.** Both of this story's source scans had now been defeated THREE times. Round 3 found: `(replay_record) = null` classified BY THE WHITELIST as an "argument read" — a literal assignment certified as a read, by the very inversion `3-0d/R14` installed to prevent exactly that; six further panel declaration forms evading the Callable scan (`static var`, `@onready`, an inner-class member, a Callable in an untyped `Dictionary`, one in an untyped `Array`, an untyped member invoked through a local copy); a shared line reader truncating at the first `#` with NO string awareness, so a `#` inside a string literal deleted the rest of the line from BOTH scans; and both scans reading `.gd` only while `.tscn`-embedded GDScript under `src/` is shipped, compiled, executing code. A complete, wired LOAD control shipped past both with the entire suite green. **OPERATOR RULING `3-0d/R20`: A TEXT SCAN OVER SOURCE CANNOT CARRY A DESIGN INVARIANT, AND THIS PROJECT WILL STOP TRYING TO MAKE IT.** The property is made STRUCTURALLY IMPOSSIBLE instead of DETECTABLE: `MatchRunner` CONSUMES `replay_record` exactly once, in `_ready()`, into a private `_replay_record`, and the per-tick fork plus every other consumer read only the private field — so a mid-session assignment has no effect not because it is caught but because nothing reads what it changed (part 1). It is proven BEHAVIOURALLY by `test/integration/test_replay_entry_is_inert.gd`, which makes the forbidden assignment on a live runner and asserts the fork does not flip, recording continues, and the live reload trigger still fires (part 2). **BOTH SCANS DELETED** — the `replay_record` one outright (part 3), the panel one replaced by the SCENE-LEVEL control-set check alone, whose own `Button`-vs-`BaseButton` hole is closed in the same ruling since `LinkButton` extends `BaseButton` and was invisible to the old query (part 4). **AC 7 and AC 11 RE-WORDED to what the mechanisms actually carry, with the residue stated plainly in both** (part 5); every falsified passage corrected in place with the correction visible, including two that `3-0d/R19` had already corrected once. **`R21`:** `load_record` still returned `{"record": null, "error": ""}` for three inputs — required keys present with WRONG TYPES, `null` under `reload_events`, `null` under `intents` — because `has()` is true for `null` and says nothing about type; `REQUIRED_KEYS` is now a key -> TYPE map validated before the rebuild, refusing with a reason naming the key and what was found. **`R22`:** `save_record`'s bare `begins_with("user://")` was replaced by NORMALISATION — resolve the path, require it inside the `user://` directory — with the sibling-prefix trap (`user://../CardSoulsEvil/…`) measured and closed by comparing against the root plus its separator; traversal forms tested and nothing lands in the repo, verified by running it. **`R23`:** `ReplayDrive`'s two inert divergences from the runner (controllers constructed later, intents sampled after the pushes) are MATCHED to the runner statement for statement rather than documented away — the docstring's claim is the value. **`R24`:** the AC 8 verifier is now run BY THE SUITE as a subprocess, asserting `RESULT: PASS` and the same hash across two invocations; the obvious `load()`-non-null guard is vacuous (`load()` returns non-null on a parse error) and the subprocess form worked, so NO fallback to `can_instantiate()` was needed. **FIVE MUTATION PROOFS, behavioural where the guard is behavioural**, each restored from an out-of-repo copy with SHA-256 verified — including one that proves the OLD `Button` query PASSES with a fully wired `LinkButton` load control installed, and one that found a real defect in this pass's own new test (its only `max_hp` reading sat after the reload trigger, which scrubs the poisoned value; a reading was added before the trigger and both assertions then fired). **Suite: baseline 348/2244/20 CONFIRMED BY THIS PASS at `HEAD` `a6582e8`, after 348/2264/22, ALL PASSED both ends** and green again after every restore. The flat state-test count is two opposite movements — `test_replay_surface_pins.gd` 4 tests -> 2 (the deleted scans, the predicted DROP), `test_record_file.gd` 9 -> 11 — with the replacements living in the +2 integration files. `project.godot` byte-identical (`8879de49…07970004`); golden unmoved; the four inherited `3-0c` pins zero edits; `test/tools/replay_file.gd` unmodified. Live smoke NOT run. Three commits, none pushed. | Claude Opus 5 |
| 2026-08-05 | 0.1 | File authored at this story's own creation pass, per the `3-0a`/`3-0b`/`3-0c` precedent and `3-0c/R5`'s split ruling. Nine ACs recorded, each mapping to one of the six inherited scope items (CACHE_MODE_IGNORE; the live reload trigger reusing the existing reload channel; `user://` persistence with the format deliberately unpinned; recording start/stop lifecycle; the panel controls with no new Input Map action; the live smoke) or explicitly declared discharged by a non-AC section with a reason (the live smoke itself, discharged by the required Live Smoke section rather than a numbered AC, matching this repo's own convention for every prior story). Every quoted string re-verified against shipped code or the decision log at write time; the commissioning brief's R-D6 claim ("spent on 3-4") is corrected — the more recent spend was `3-5a`. A structural gap not previously named anywhere is surfaced: `replay_record` is read once in `_ready()`, before the scene ticks, and no scene-reload mechanism exists in `src/`, so a mid-session "load" control has no runtime path into replay under the shipped architecture (Open Question (f)). Six Open Questions left open, none resolved. Golden Prediction NONE, argued on the same two premises `3-0c` used (no snapshot key; no seeded-RNG consumer). Live Smoke REQUIRED, described on the shipped two-keyboard default, no `.tscn` edit needed. Status `backlog`; promotion to `ready-for-dev` deferred to this story's own readiness gate. Nothing under `src/` or `test/` is touched by this pass — docs only. | Claude Sonnet 5 |
| 2026-08-05 | 0.3 | **DEV PASS — all ELEVEN ACs implemented; suite 329/1715/19 -> 344/2197/20, all green both ends.** DEBT B is closed on both halves: `reload()` is `ResourceLoader.load(..., CACHE_MODE_IGNORE)` (AC 1, proven by OBJECT IDENTITY in the state harness with zero file mutation, engine semantics MEASURED first), and `match_runner.gd::trigger_live_balance_reload()` re-reads the service then captures BEFORE it applies on the existing reload channel (AC 2/AC 3, no ninth `capture_*`). `user://` persistence ships as `src/systems/record_file.gd` (`class_name RecordFile`, the ONE new class_name; editor scan run and `.uid` committed for all six new `.gd` files) — a sibling rather than a recorder method, so the recorder stays clock-free and content-blind and its own scan stays green. Round trip proven by bit-identical `CanonicalHash` across live run / in-memory replay / loaded-file replay AND channel-by-channel equality including all eight `InputIntent` fields (AC 4); `FORMAT_VERSION` refusal proven in both directions (AC 5); always-on cumulative recording proven in the harness and on the LIVE runner (AC 6). The panel gains EXACTLY ONE control, `SaveRecord`, in a third COLUMN (a third row would leave the empty band and trip `test_debug_instruments.gd`'s S1/S2 layout guard, which still passes), wired by a runner-owned `Callable` and pinned at one runner-reaching control by a scan that also forbids a second `Callable` and any `signal` (AC 7). `test/tools/replay_file.gd` ships and was RUN FOR REAL, twice, on a record produced headlessly by the live runner — same hash `5f465e7a...9d13` both times (AC 8). Per-pool contract exercised unchanged, stamina refill ratified (AC 9). The four inherited `3-0c` pins required ZERO edits and `project.godot` is byte-identical (`8879DE49...0004`); the golden did not move (`40eb5554...a322`). SIX mutation proofs, each broken then restored from an out-of-repo copy with SHA-256 verified. **ONE CONTRACT CONFLICT RAISED, NOT RESOLVED: AC 7 pins the panel at one control while the Live Smoke asks for a panel-triggered live reload — a second runner-reaching control. Built to the AC; the trigger has no operator surface and the smoke's reload step cannot be performed until the operator rules.** Live smoke NOT run (operator's, carries the required R-D6 kill). Code and docs in two separate commits; neither pushed. | Claude Opus 5 |
| 2026-08-05 | 0.2 | **Readiness gate fix pass — NOT READY on first reading, five blocking findings, all ruled and applied (`3-0d/R1`-`R12`).** AC count 9 -> 11. **B1/`R1`:** ACs 5/6 contracted a mid-match START control that cannot ship — `capture_advance()` asserts `has_complete_match_start()` on its first captured tick and all five match-start channels are captured only inside `_ready()` behind `if not replaying`, so a mid-match start trips the invariant on the next tick; and even a working one would be meaningless, since a replay builds from `MatchState.new()` forward and no state-restore snapshot exists. Recording is ALWAYS-ON from tick 0 (already true in shipped code, `match_runner.gd:566`); new AC 6 pins it. **B2/`R2`:** the "load" control had no correct runtime path AND the story's stated reason was FALSE — `replay_record` is not read only in `_ready()`, it is also read every tick in `_physics_process` (lines 536-540), so a mid-session assignment injects tick-1 recorded reloads/bases/contacts into a live match while both controllers are still live keyboards and silently stops recording. LOAD IS NOT A LIVE CONTROL; a scene-reload mechanism was considered and REJECTED (new architecture; collides with the ratified "record + replay only" scope line). The panel gains EXACTLY ONE control, SAVE, with recording continuing afterwards (AC 7). **B3/`R3`/`R4`:** the smoke's payoff step was unperformable — `CanonicalHash` is `test/canonical_hash.gd` and nothing in `src/` computes or displays a hash (verified: the only two `src/` occurrences are comments). The payoff moves to a HEADLESS VERIFIER under `test/tools/` (AC 8), which is what legitimately gives it `CanonicalHash`; consequence recorded — the Input Map pin's "replay reachable only from a test, never from a key" message stays TRUE, so that non-blocking finding is DISSOLVED, not deferred. The smoke is reformulated to what it alone can prove: a REAL PLAYED ROUND's record exists, is structurally complete, and replays headlessly twice to the same hash. **B4/`R5`:** old AC 1 forced a permanent test to mutate the tracked authored `.tres` (`CONFIG_PATH` is a hardcoded const with no seam; `test_contact_pipeline.gd` and `test_balance_authoring.gd` read it too), colliding with the PERMANENT RULE at decision-log:799 and worse than the one-off case that rule was written for. AC 1 now proves the cache bypass BY OBJECT IDENTITY — two `reload()` calls yielding DIFFERENT references with EQUAL values, plain `load()` yielding the same one — **measured on Godot 4.6.3 before the AC was written**; zero file mutation, zero new autoload API, and it lands in the STATE harness (`test_balance_config.gd:88-89` already instantiates the service as a plain Node). **B5/`R6`:** old AC 9 was a process promise with no falsifying mechanism (all `capture_advance` hits in `test/` drive a recorder directly). AC 11 now ships a source scan over `match_runner.gd` pinning the tap seat AND that `replay_record` is assigned nowhere in `src/`. **`R7`:** on-disk format stays unpinned except for a mandatory format-version int with refusal on mismatch (new AC 5). **`R8`:** the old-record/changed-`CardDatabase` question is CLOSED BY CONSTRUCTION — replay drives injected deck + costs and never reads the autoload (verified). **`R9`:** debug reset is round-scoped and rides the record as an ordinary captured `InputIntent` field; a record spans it intact. **`R10`:** the visible stamina refill on a live reload is RATIFIED AS CORRECT (the per-pool `apply_balance` contract, live for the first time), observed by the smoke as EXPECTED. **`R11`:** R-D6 RE-INVOKED AND SPENT on this story's smoke; the kill is a REQUIRED observation. **`R12`:** the architecture's "record/replay start-stop-load" annotation (lines 578-579) genuinely diverges from SAVE-only and becomes the **ELEVENTH** amendment-queue member (queue counted by content: ten, per `3-0c/R10` and `3-0c/R14`); `game-architecture.md` NOT edited, queue flushes at E3 close-out. **Non-blocking corrections applied:** the Input Map action count re-measured 28 -> **30** (2 `debug_*` + 14 `p1_*` + 14 `p2_*`); "`reload()` has exactly ONE caller" corrected to TWO (its `_ready()` plus `test_balance_config.gd:89`), with the inheritance of that wrong claim from the CLOSED `3-0c` story file recorded here rather than by editing that file; three "not decided here" carve-outs moved out of ACs into Dev Notes; two drifted citations re-anchored by content (`3-0c/R5` 3685 -> **3682**-3699; the architecture X5 toggle line 579 -> **578**-579). Line numbers are NOT re-anchored wholesale — non-blocking on the repo's own precedent. **Open Questions section DELETED** (the `3-0c` precedent), all six ruled, each ruling's substance carried into the AC or Dev Note that now owns it. **Every pre-existing Dev Notes bullet survives**; the three falsified ones (the `reload()` caller count, the 28-action count, the `replay_record`-read-once structural gap) are CORRECTED IN PLACE with the correction visible, none deleted. Golden Prediction unchanged (NONE), premise 1 widened to name `test/tools/`. Status `backlog` -> **`ready-for-dev`**. Docs only; nothing under `src/` or `test/` touched. | Claude Sonnet 5 |
| 2026-08-05 | 0.5 | **POST-REVIEW FIX PASS (`3-0d/R14`-`3-0d/R19`) — a code review returned CHANGES REQUIRED with ONE BLOCKING finding and five non-blocking; all six are closed here.** **B1/`R14`, blocking:** BOTH of this story's new source scans could be evaded, and the mutation proofs that "proved" them used the author's own syntax so they caught nothing. The `replay_record` scan matched `\breplay_record\s*=[^=]`, so `set("replay_record", rec)`, `set_deferred("replay_record", rec)` and `runner[&"replay_record"] = rec` ALL PASSED — counted as READS; the panel Callable scan matched `^var\s+\w+\s*:\s*Callable`, so the idiomatic `var load_record := Callable()` did not match at all. Fixed STRUCTURALLY, not by adding patterns: the `replay_record` scan is INVERTED INTO A WHITELIST of four enumerated allowed read forms (declaration, null comparison, member read, argument read) with everything else — including forms nobody has thought of yet — an offender BY DEFAULT, reported with file, line and text, the allowed set derived from the shipped tree and no line count hard-coded; the panel scan matches a declaration carrying `Callable` in ANY form plus any member the file invokes as a Callable. Both self-checks now assert the EVASION FORMS ARE CAUGHT beside the legitimate forms being SPARED. **REDONE MUTATION PROOFS, ALL FOUR IN EVASION FORMS** (`set()`, `set_deferred()`, indexed property write, inferred-form `Callable`), each observed RED, each restored from an out-of-repo copy with SHA-256 verified identical — a proof in the annotated/bare form no longer counts. **The PERMANENT LESSON (`R14` part 3), recorded in the decision log and in Dev Notes, binding every future pattern guard in this repo: a pattern guard's non-vacuity check must be proven against THE FORMS AN ADVERSARY WOULD USE, not only the form the author happened to write; enumerate what is ALLOWED and refuse the rest by default.** **`R15`:** `RecordFile.load_record` returned `{"record": null, "error": ""}` on a versioned-but-truncated file — a refusal with NO reason, which a caller testing `error != ""` reads as SUCCESS, contradicting the class's own contract. `REQUIRED_KEYS` are validated BEFORE the rebuild and the refusal names what is missing; tests added for the truncated file AND the previously untested no-version-key branch, plus a derivation guard asserting `REQUIRED_KEYS` is the key set the writer actually emits. **`R16`:** `save_record` accepted any path and was proven at the review to write into the repo root; a path not beginning with `user://` is now REFUSED with a reason, tested, so the class's assertion about where records go is true of the API and not only of `path_for()`. **`R17`:** the AC 8 verifier's replay ordering was a THIRD independent transcription that NOTHING guarded — AC 4 covered the save/load path only. Extracted to `test/replay_drive.gd` (`ReplayDrive.drive()`), used by BOTH `test/state/test_record_file.gd` and `test/tools/replay_file.gd`, so AC 4's round-trip hashes now genuinely cover the verifier's ordering; the falsified Dev Notes claim is corrected in place. The runner's own `src/` fork is deliberately NOT folded in (it cannot depend on `test/`) and stays the named original. Neither caller weakened: the unsound-content refusal travels as a reason in a result Dictionary. **Running the extracted verifier for real caught a parse error the suite structurally cannot see** — it is not globbed by `run_all.sh` — which is itself worth recording. **`R18`:** the Dev Agent Record's AC 8 hash `5f465e7a…9d13` was not reproducible at the review, which measured `d2f77f3e…92d0` from byte-identical files; **this is EXPLAINED, not a defect** — the dev pass's producer PRESSED inputs and the review's pressed none, so different intents gave a different final state and a different hash, while the verifier's summary line shows NO intents, which is why the two runs looked identical. AC 8's actual claim (same file -> same hash, twice) holds and was re-measured holding. The record now says the hash is a function of its producing run, not a constant. **`R19`:** the two passages left contradicting the `3-0d/R13` AC 7 amendment — Project Structure Notes still saying the panel "gains EXACTLY ONE new control, SAVE", and a Dev Note still saying the structural test COUNTS runner-reaching controls and that this is what keeps a load control out — are CORRECTED IN PLACE with the correction visible; the 0.3 Change Log row is HISTORICAL and untouched. **Suite 344/2198/20 -> 348/2244/20, ALL PASSED both ends** and green again after every mutation was restored; `project.godot` byte-identical (`8879DE49…07970004`); golden unmoved; the four inherited `3-0c` pins zero edits; `match_runner.gd` and `debug_instrument_panel.gd` unmodified. Three commits, none pushed. | Claude Opus 5 |
| 2026-08-05 | 0.4 | **FOLLOW-UP DEV PASS (`3-0d/R13`) — the contract conflict the prior pass raised and deliberately did not resolve (AC 7 vs the Live Smoke's live-reload step) is RESOLVED, not deleted.** Operator ruling: AC 7's "exactly one new control" was never protecting a COUNT, it was protecting against a LOAD control (`3-0d/R2`) — a property AC 11's `replay_record` source scan already carries structurally, independent of button count. AC 7 is reformulated from a count into an EXACT SET, `{SaveRecord, ReloadBalance}`, the same shape this repo already uses for the Input Map pin. The `DebugInstrumentPanel` gains a second runner-owned `Callable`, `reload_balance`, and a second `Button`, `ReloadBalance`, stacked in the existing third column and wired to the already-shipped `trigger_live_balance_reload()` — no new runner-side trigger logic. **Layout MEASURED, not assumed:** a throwaway script confirmed the box's global rect is unchanged (x[276,876] y[356,450]) and both columns land on the same 64px minimum height, well inside the 94px band; `test_debug_instruments.gd`'s S1/S2 layout guard passed UNMOVED. `test/state/test_replay_surface_pins.gd`'s AC 7 pin is amended to assert the exact two-member Callable/handler sets (AC 11 untouched, zero edits); `test/integration/test_record_save_control.gd`'s control-set assertion is amended to the four-name set and extended to press RELOAD via the panel's own real-signal pattern, proving live: the runner's `reload_event_count()` goes 1 -> 2 and P1's stamina (spent to 38/50 by a real roll) refills to 50/50 through the StateInspector's own primed label. **MUTATION PROOF:** a third runner-reaching control (`load_record`, the rejected LOAD control) was added and BOTH the structural pin and the scene-level control-set check went RED; restored from an out-of-repo copy, SHA-256 verified identical. Suite 344/2197/20 -> 344/2198/20 (+1 assertion, 0 new tests/integration files), ALL PASSED both ends; `project.godot` re-verified byte-identical; golden unchanged; the four inherited `3-0c` pins required zero edits. Code and docs in separate commits; neither pushed. | Claude Sonnet 5 |
