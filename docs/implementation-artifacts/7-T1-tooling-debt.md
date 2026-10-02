---
baseline_commit: 0de344081e2fc51e3e3be496017839fc4e66de20
---

# Story 7-T1: Tooling Debt

Status: ready-for-dev

Tier B. Docs-/test-tooling debt carried from the E6 close-out (`E6-C/R6`, `E6-C/R9`, decision-log
session "Epic 6 close-out"). No player-visible change. Runs alongside the operator's `7-1` asset
gathering (`E6-C/R11`, `sprint-status.yaml` story_notes).

## Story

As the project's test harness,
I want the `_replay` channel-drop coverage gap closed, the `6-5b/R24` "resources still in use at
exit" flake resolved at its cause, and the stale direct-connect comment corrected,
so that a future recorder channel can't be dropped silently, the suite's per-file pass/fail is
trustworthy, and the architecture amendment queue doesn't carry a resolved item as open.

## Acceptance Criteria

**m5 — `_replay` unknown-channel drop coverage (`6-5f/R45`, `E6-C/R6`)**

1. `_replay` (`test/state/test_replay_identity.gd:1618-1659`) checks its `drop` parameter against
   `KNOWN_DROPS`, the set of channel names for which `_replay` has a WORKING drop branch (one that
   actually withholds that channel). `drop` is accepted only when it is empty or a member of
   `KNOWN_DROPS`; any other value fails the test loudly — including the name of a channel that sits
   on the NOT-COVERED list instead (AC 4). Membership in NOT-COVERED never makes a value an
   accepted `drop`. Today an unrecognized `drop` string (e.g. `drop == "colors"`, which has no drop
   branch) silently replays every channel and the test passes vacuously; after this story the same
   call fails loudly.
2. `_replay` gains explicit drop handling for the `colors` channel (omits injecting
   `record.replay_card_colors()`) and the `pitch_effects` channel (omits injecting
   `record.replay_pitch_effects()`). Today neither has a drop branch: both channels always inject
   regardless of `drop`'s value, so a divergence test for either is currently impossible to write
   truthfully.
3. `test_dropping_any_single_channel_diverges_the_replay` (or an equivalent) proves dropping
   `colors` and dropping `pitch_effects` each diverge the replay hash from the live-driven hash,
   on the same footing as the channels already in that test's list (`test/state/test_replay_identity.gd:624-641`).
4. A new test enumerates every channel the record can inject into a replay: the content channels
   in `IntentRecorder.SOUND_CONTENT_ORDER` (`src/systems/intent_recorder.gd:63-64`) — the ordered
   list `replay_inject_content` actually matches against (`intent_recorder.gd:571-586`) — union the
   remaining per-tick/setup channels `IntentRecorder` captures and replays outside content
   injection (seed, balance, feature flags, camera basis, lock direction, contacts, drain target,
   intents). For every channel in that union, the test asserts it is on EXACTLY ONE of: `KNOWN_DROPS`
   (AC 1 — a working drop branch, proven to diverge) or a separate NOT-COVERED list carrying one
   line per entry stating why no drop branch exists (e.g. `drain_target`: `_replay` never calls
   `replay_push_drain_targets` at all). A channel on neither list, or on both, fails the test. The
   surface is DERIVED from `SOUND_CONTENT_ORDER` plus the live set of capture_*/replay_* pairs — not
   a second hand-maintained list that can drift from either — so a future channel added to either
   surface with no corresponding `_replay` handling fails this test instead of passing silently.
   Mutation proof: with the `colors` drop branch removed and `colors` left on neither `KNOWN_DROPS`
   nor NOT-COVERED, this test fails (restored per the project's mutation-proof discipline — a copy
   taken outside the repo, SHA-256-verified on restore).

**`6-5b/R24` flake — "resources still in use at exit"**

5. In a full-suite run (`test/run_all.sh`), none of `test/integration/test_unit_combat_live.gd`,
   `test/integration/test_charge_telegraph_dispatch_live.gd`,
   `test/integration/test_card_mode_lift.gd` emits "resources still in use at exit" caused by
   something this codebase — not the engine — leaves unfreed before quit: the leaked resource(s)
   are identified and freed. (Measured at `6-5b/R24`: 0 of 10 isolated runs leaked, 2 of 4
   full-suite runs did; `run_all.sh`'s per-file branch currently fails the suite on this message.)
6. ONLY if the cause is proven to originate in the Godot engine rather than this codebase,
   `run_all.sh` may instead classify that exact message as a warning rather than a FAILED outcome
   for the affected test file, and that classification is itself covered by a test (e.g. a
   synthetic run that emits the message and asserts `run_all.sh` does not mark it FAILED, while
   any other message still does).
7. At a 2-of-4 full-suite incidence rate, a single clean full-suite run after the fix proves
   nothing. "Fixed" (or "proven engine-caused") is demonstrated by exactly one of: (i) the specific
   unfreed resource is identified, and a reproduction shows the leak occurring deterministically
   before the fix and never occurring after — the reproduction must actually trigger the leak
   condition every time, not merely re-run the full suite and hope; or (ii) proof that the cause
   originates in the Godot engine, not this codebase (AC 6). No blanket count of full-suite reruns
   substitutes for either (i) or (ii); name the evidence actually produced in the close-out.

**Stale comment — `match_runner.gd:2460`**

8. The comment block at `src/main/match_runner.gd:2460` no longer calls the 5-3 direct connect
   (`card_cast_resolved` → `TelegraphController`) "standing but UNRESOLVED in the architecture
   amendment queue." It instead reflects that `E5-C/R2` and `E6-C/R2` resolved the question: the
   direct-connect exception is now an enumerated list of exactly two members,
   `card_cast_resolved` and `counterspell_resolved` (decision-log `E6-C/R2`). Comment-only change —
   no other line in that block, and nothing outside it, changes.

**Non-movers**

9. Golden `941958c52605abbcd1edf972e002543601325e5a9f98dfce569628c12f75871f`
   (`test/state/test_determinism.gd:1307`) and `RecordFile.FORMAT_VERSION` 19
   (`src/systems/record_file.gd:330`) are unmoved by this story. `test_determinism` and the full
   suite (state harness + integration) run before and after and show no golden or snapshot-key-set
   movement.

## Out of Scope

- The `6-5g` AC 14 stun half (separate deferred item, not owned by `7-T1` — `E6-C/R9`).
- Anything that moves the golden or `FORMAT_VERSION` (AC 9).
- Any channel gap other than `colors` and `pitch_effects` that the AC 4 coverage test surfaces
  incidentally (see Dev Notes) — listing such a channel on the NOT-COVERED list (AC 4) with its
  one-line reason satisfies AC 4 for that channel; a new drop branch for it, and therefore
  `KNOWN_DROPS` membership, is not required by this story.

## Tasks / Subtasks

- [ ] `KNOWN_DROPS` guard + loud failure on an unrecognized `drop` value (AC 1)
- [ ] `colors` and `pitch_effects` drop branches in `_replay` (AC 2)
- [ ] Extend the falling-proof test to cover `colors` and `pitch_effects` (AC 3)
- [ ] Derived coverage test over `IntentRecorder`'s channel surface (AC 4)
- [ ] Diagnose and fix (or prove engine-caused) the `6-5b/R24` leak in the three named tests (AC 5-6)
- [ ] Close-out evidence for AC 5-7 (named runs, before/after)
- [ ] Fix the stale comment at `match_runner.gd:2460` (AC 8)
- [ ] Before/after full suite + `test_determinism`, confirm golden and `FORMAT_VERSION` unmoved (AC 9)

## Dev Notes

- **`_replay`'s current drop-handling shape** (`test/state/test_replay_identity.gd:1618-1659`): an
  `if`/`elif` chain keyed on the `drop` string, with explicit branches today for `balance_from_disk`,
  `balance`, `flags`, `costs`, `effects`, `pitch_costs`, `deck` (content channels) and `reload`,
  `bases`, `lock`, `contacts`, `intents`, `seed` (per-tick/setup channels). Anything else — including
  today's `colors` and `pitch_effects` — falls through to the catch-all branch
  (`elif drop != "deck": assert_true(record.replay_inject_content(ms), ...)`), which always injects
  every content channel regardless of `drop`'s value. That catch-all is why `colors` and
  `pitch_effects` are unfalsified today: passing `drop == "colors"` currently replays colors anyway.
- **The existing enumeration test** `test_dropping_any_single_channel_diverges_the_replay`
  (`test/state/test_replay_identity.gd:624-641`) lists `["seed", "balance", "flags", "deck", "costs",
  "effects", "pitch_costs", "reload", "bases", "contacts", "intents"]` — `colors` and `pitch_effects`
  are simply absent from this hand-maintained list, which is exactly how the gap went unnoticed.
- **Incidental finding, not in scope:** `IntentRecorder` also has `capture_push_drain_target` /
  `replay_push_drain_targets` (`src/systems/intent_recorder.gd`), but `_replay`'s per-tick loop never
  calls `replay_push_drain_targets` at all — there is no drop branch and no replay of that channel
  during replay. The AC 4 coverage test will surface this as a gap; per Out of Scope, it belongs on
  the NOT-COVERED list (e.g. "`drain_target`: `_replay` never calls `replay_push_drain_targets`")
  rather than `KNOWN_DROPS` — giving it an actual drop branch is not required by this story. Also
  recorded as its own line in `deferred-work.md` next to the `7-T1` entry, owner unassigned.
- **`6-5b/R24` investigation to date** (decision-log, session "`6-5b` close-out"): the flake is
  NOT attributable to the `6-5b` story itself — identical `6-5b` code produced both clean and
  leaking full-suite runs, the file's `6-5b` diff is comments-only, the `6-5b` price derivation
  reads only already-loaded resources, and the affected test never reaches the Grave Ward tint. No
  `--verbose` leak output could be obtained because no *isolated* run ever leaked (0 of 10). The
  leak reproduces only in full-suite context (2 of 4), and predates `6-5b` by 18 days
  (`E6-C/R6`). This means isolated-run debugging alone will not reproduce the symptom.
- **`run_all.sh`'s actual process shape** (`test/run_all.sh:27-36`): EACH integration test file
  already runs as its own separate foreground `godot --headless` process, both when run in
  isolation and when run as part of the full-suite loop — the per-file loop never shares one
  process across files. So the full-suite-only incidence cannot be explained by in-process state
  carried between tests; it must come from some OTHER cross-process factor. Candidates, NOT a
  conclusion: timing/system load at quit (heavier load from preceding processes affecting
  shutdown), or on-disk state left behind by an earlier file's process (cached imports, written
  `user://` files, lock files). `t_exit` (the process exit code) or a matching stderr pattern marks
  a file FAILED (`test/run_all.sh:30-35`); the "resources still in use at exit" message is Godot's
  own shutdown diagnostic, printed to stderr — whether it affects `$t_exit` or only appears in text
  is worth confirming empirically rather than assumed.
- **Comment fix target**: `src/main/match_runner.gd:2457-2461` is the exact paragraph (the sentence
  spans lines 2459-2461 in the current file). Read the full comment block before editing — it
  explains the direct-connect exception's rationale and should still read sensibly after the
  "UNRESOLVED" clause is corrected to reflect `E6-C/R2`'s two-member enumerated list.

### Project Structure Notes

- All three items stay within already-established folders: `test/state/` (item 1),
  `test/integration/` + `test/run_all.sh` (item 2), `src/main/match_runner.gd` (item 3, comment
  only). No new files, no new folders.
- Item 2's fix, if it touches `src/` production code (e.g. freeing a resource at the right point),
  stays wherever the leak is actually found — do not relocate unrelated code while fixing this.

### Project Context Rules

(Extracted from `docs/project-context.md`; rules load-bearing for this story only.)

- **Edit fallback chain**: Edit tool first; on the first failed match, switch to a Python
  byte-replace or a line-index splice — no Edit retries, and never reconstruct a file with
  PowerShell `-join` (`PROC/R3`). Invoke `python`, never `python3`, in this bash.
- **Mutation-proof discipline**: any mutation made to prove a guard (e.g. the `KNOWN_DROPS` guard,
  AC 1) non-vacuous is restored from a copy taken OUTSIDE the repo, verified by SHA-256, never
  `git checkout --`.
- **Guard mechanism over guard pattern**: the `KNOWN_DROPS` guard (AC 1) and the derived coverage
  test (AC 4) are exactly this — make the gap IMPOSSIBLE BY CONSTRUCTION (a new undropped channel
  fails a test) rather than DETECTABLE BY INSPECTION.
- **Suite cadence**: full suite runs twice by default (open, close); mutation proofs run only the
  affected test file. A further run needs a stated reason and is always reported (`PROC/R1`).
- **One foreground engine launch per tool call**; the full suite is two foreground calls with an
  explicit timeout; no `run_in_background`, `ScheduleWakeup`, or `timeout` wrapper around an engine
  launch (`E6-R/R4`, `E6-R/R5`).
- **Machine-time instrumentation**: timestamp the before/after suite-output files, recorded as
  start/end/delta in the close-out entry — the operator sets the budget at the scope conversation,
  a story never states its own; any overrun is reported, never hidden (`E5-R/R3`, `E6-R/R2`,
  `PROC/R7`).
- **Golden re-baseline needs a reverse probe** — not expected to apply here since AC 9 requires the
  golden to NOT move, but if a dev pass unexpectedly moves it, the reverse-probe discipline
  (`E6-R/R8`) applies before accepting any new hash.
- **A golden re-baseline (if one somehow happened) needs a close-out session naming it** before
  promotion (`E4-R/R7`) — not expected to apply here; flagged because AC 9 is the guard against it.
- **Text fit / legibility**: not applicable — no UI in this story.
- **Commit discipline**: docs and code never share a commit; this story's own authoring commit (if
  any) follows the usual separation; `git add`/`git commit` stay separate explicit-path commands.

### References

- [Source: docs/implementation-artifacts/deferred-work.md#Tooling,-to-7-T1-tooling-debt] (lines 573-583)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#E6-C/R6] (line 12058)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#E6-C/R9] (line 12072)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#E6-C/R10] (line 12079, golden/FORMAT_VERSION numbers of record)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#E6-C/R2] (line 12035, direct-connect exception enumerated to two)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#E5-C/R2] (line 9062, original direct-connect ruling)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md#6-5b/R24] (line 11311, the flake's original measurement)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md] (line 337)
- [Source: docs/implementation-artifacts/sprint-status.yaml] (lines 140-151)
- [Source: test/state/test_replay_identity.gd] (lines 624-641, 1618-1659)
- [Source: src/systems/intent_recorder.gd] (lines 63-64 SOUND_CONTENT_ORDER, 571-586 replay_inject_content, capture_*/replay_* method pairs)
- [Source: src/systems/record_file.gd] (line 330, FORMAT_VERSION)
- [Source: test/state/test_determinism.gd] (line 1307, GOLDEN)
- [Source: test/run_all.sh] (lines 27-36, per-file integration loop)
- [Source: src/main/match_runner.gd] (lines 2457-2461)
- [Source: docs/project-context.md] (Testing Rules section)

## Live Smoke

None — no player-visible change.

## Open Questions

None.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
