---
baseline_commit: 8eaa8b85389a05b0c2adb7638e508f135f7a19f3
---

# Story 5.1a: Intent hardening

Status: done

## What this story inherits

`E5-P/R5` (`decision-log.md:8175-8189`) ratifies this as the SIXTH of twelve E5 stories: Tier A,
bundling `4-6`'s M3/L7/L8 findings, with its own before/after golden measurement not shared with
`5-1`. `E5-P/R6` (`decision-log.md:8211,8215`) disposes the content; `epics.md:177-179` and
`5-1-accelerator-stacking.md:242-243` confirm the same bundle and split.

The three findings, verbatim from `deferred-work.md`'s 4-6 residue table (source review
`_46-review.md`; NOT `_46a-review.md`, which reuses the labels M3/L7/L8 for unrelated findings --
AC7 tie-break, the `>= 1.0` fast path, stale guards -- out of scope here):

> | M3 | `_46-review.md:236` | A malformed retarget address is logged and then acted on, and lands
> in a HASHED key | `5-1a-intent-hardening` (`E5-P/R6`) |
> | L7 | `_46-review.md:320` | A v6 record with a sparse or truncated `lock_pushes` channel replays
> wrong | `5-1a-intent-hardening` (`E5-P/R6`) |
> | L8 | `_46-review.md:326` | A v6 intent dict missing `retarget_slot` / `retarget_index` crashes |
> `5-1a-intent-hardening` (`E5-P/R6`) |

## Operator rulings (the contract)

- **R1 -- one job.** A record that is not well-formed must be refused at LOAD, with a reason naming
  the offending field, in the same shape as the existing `format_version` and `REQUIRED_KEYS`
  refusals (`record_file.gd:250-294`). Nothing malformed reaches `advance()`.
- **R2 -- refusal is whole-record.** Never skip a bad entry and replay the rest -- a partial replay
  is worse than none.
- **R3 -- the live path (M3).** A malformed retarget address is NOT applied; the lock target keeps
  its previous value and nothing is written to the hashed `lock_target` key. This must hold in a
  build where `assert` is stripped, so the guard cannot be an `assert`.
- **R4 -- `FORMAT_VERSION` is NOT bumped.** The format is unchanged; only the reading is stricter.
  Records that used to load and then crash are now refused with a reason -- that IS the intended
  behaviour change, and it applies to malformed files only.
- **R5 -- Golden Prediction, inverse form.** Golden `aa3566d7...` and the current snapshot key set
  do NOT move, because the new branches are never executed by the hashed run (the fixture's
  recorded intents and record file are already well-formed). Non-vacuity is therefore NOT proven by
  golden movement -- every new refusal branch carries its own falsifiable test plus a mutation
  proof that it goes RED when the branch is removed. State this explicitly in the Dev Notes' Golden
  Prediction subsection so the dev pass cannot substitute an unmoved golden for evidence.
- **R6 -- scope is locked** to the three findings above plus one doctrine line: per-field
  validation for fields that feed a hashed key or the rebuild loop. No general "validate everything"
  sweep of `record_file.gd` or `match_state.gd`.
- **R7 -- `Invariant.check` being non-load-bearing in exported builds is a GENERAL condition**, not
  just M3's (`Invariant.check` is `push_error` + `assert`, and `assert` is stripped in exported
  builds -- `src/systems/invariant.gd:1-15`). This story fixes it ONLY at the `_resolve_lock` seat
  (M3). The general finding is a Non-Goal here and is recorded as a named unowned item at close-out
  -- do not read the narrow fix as a repo-wide verdict.
- **R8 -- live smoke is a short REGRESSION check** (lock, flick, retarget still behave as before),
  not a feel smoke. Nothing player-visible ships.

## Story

As the operator relying on recorded matches for determinism proof and debugging,
I want a malformed retarget address rejected at the moment it would be applied -- live or on
replay load -- instead of silently logged-and-applied or crashing the rebuild,
so that a corrupted or hand-edited input can never poison a hashed snapshot key or take down a
replay, and every refusal names the field that failed.

## Acceptance Criteria

**Live path (M3, `match_state.gd:_resolve_lock`)**

1. When `intent.retarget_slot != InputIntent.NO_RETARGET`, a malformed retarget address (slot not
   0 or 1, or index `< TargetingService.HERO_INDEX`) is REJECTED, not merely logged: `_resolve_lock`
   must not proceed to assign `player.lock_target_slot` / `player.lock_target_index` from a rejected
   address. The lock target keeps whatever value it already held (R3) -- no write to the hashed
   `lock_target` key (`player_state.gd:267`) occurs for a rejected tick.
2. The guard controlling AC 1 is a plain runtime branch, and the malformed address does not reach
   `player.lock_target_slot` / `player.lock_target_index` through any path that depends on
   `assert()`. Proven in two halves, both machine-checkable (`5-1a/R9`):
   (a) BEHAVIOURAL -- a state-layer test drives a malformed retarget address through `advance()`
   and asserts the pre-call lock target is unchanged at end of tick and the run continues. Because
   `assert()` cannot skip an assignment in any build, a passing observation attributes the
   rejection to the branch and to nothing else; the test therefore passes identically with
   assertions compiled in or stripped. MUTATION: remove the new branch and this test goes RED
   because the lock target moved to the malformed address.
   (b) SOURCE SCAN, the `test_targeting_service.gd:161-167` idiom -- the `_resolve_lock` seat
   contains no `Invariant.check`, and the assignment to `lock_target_slot`/`lock_target_index` is
   reachable only under the new conditional. MUTATION: restore an unconditional assignment and this
   fails.
   (c) The `_resolve_lock` seat therefore carries NO `Invariant.check` after this story (`5-1a/R9`):
   keeping one is not an option, since `run_all.sh:19-22,32-35` fails the whole suite on
   `INVARIANT VIOLATED`, so half (a)'s test and a retained `Invariant.check` cannot coexist in a
   green run.
   The claim that this also survives export is INSPECTION-BACKED, not machine-verified -- no export
   build exists in this repo (`deferred-work.md:181-183`) -- and (b) is the pin that makes the
   inspection re-checkable by a machine on every future run.
3. `_validate_lock`'s existing liveness rule (`match_state.gd:1732-1739`, unit dies / board cleared
   -> snap to opposing hero) is unchanged and still runs every tick regardless of AC 1 -- a rejected
   retarget address and a dead-unit reset are two different code paths and this story does not
   merge them.

**Replay path (L7/L8, `record_file.gd`)**

4. `load_record` refuses a v6 record whose `lock_pushes` channel contains a malformed entry (an
   element that is not a two-item `[slot, direction]`-shaped array, or whose slot/direction values
   are not the expected types) with a reason naming the tick and what was wrong, in the same
   `{"record": null, "error": <reason>}` shape `load_record`'s existing refusals already use
   (`record_file.gd:250-294`). The malformed entry must be caught before `_from_dictionary`'s rebuild
   loop dereferences it (R1) -- not after a script error or a wrong-shape replay has already
   happened. A tick ABSENT from `lock_pushes` is NOT malformed: the writer
   (`record_file.gd:362-366`) omits every empty tick by design, so sparseness is the only shape
   this class ever produces, golden fixture included, and `.get(tick, [])` already handles it (R11).
   This AC governs the shape of entries that ARE present, never the presence of tick keys.
5. `load_record` refuses a v6 record whose per-tick intent dict is missing `retarget_slot` or
   `retarget_index` (or carries the wrong type for either), with a reason naming the tick and the
   missing/malformed field, using the same refusal shape. `_intent_from_values` must not reach a
   direct dict access on either key without that access having already been validated by the load
   path (L8).
6. Both AC 4 and AC 5 are WHOLE-RECORD refusals (R2): finding one malformed `lock_pushes` entry or
   one malformed intent dict anywhere in the record refuses the entire load, not just the tick or
   entry where the problem was found. No partial replay is produced.
7. `FORMAT_VERSION` is NOT bumped (R4) and `REQUIRED_KEYS` (`record_file.gd:177-196`) is not
   widened. `REQUIRED_KEYS` already checks the PRESENCE and TYPE of `lock_pushes` and `intents` as
   top-level keys; `retarget_slot`/`retarget_index` are per-intent fields written inside each
   `intents` array element (`record_file.gd:399-400`), not top-level keys, and were never
   presence/type checked anywhere (R12). This story adds validation of CONTENTS -- the shape of
   `lock_pushes` entries and of the two named intent fields -- not new top-level keys or a new
   version gate. A record that was well-formed under today's rules still loads identically.

**Doctrine and evidence**

8. **Golden Prediction (R5).** Golden `aa3566d7...` and the 28-key snapshot set are unmoved,
   measured before and after `bash test/run_all.sh`. Each of AC 1/AC 4/AC 5's guards carries a
   recorded mutation that turns its test RED (see Dev Notes for the non-vacuity reasoning this
   restates).
9. **`4-6` M3's own gap (R7) is fixed ONLY at the `_resolve_lock` seat.** The general condition --
   `Invariant.check` being stripped in exported builds anywhere else it is called in `src/` -- is a
   Non-Goal here (see below) and must be recorded at this story's close-out as a named, owned item
   (owner: the FIRST story that adds an exported/distributable build, same owner class already named
   for the sibling `DebugInstrumentPanel` gate finding in `deferred-work.md:176-185`) rather than
   silently dropped or implied fixed everywhere.
10. **Live smoke (R8) is a short regression check**, not a feel smoke: lock-on, flick, and retarget
    still behave exactly as before this story's changes, driven by hand for a few ticks each. Record
    PASS/FAIL per item in the Live Smoke Results section; nothing player-visible ships, so there is
    no new behaviour to smoke beyond "nothing broke."

## Non-Goals

- No `FORMAT_VERSION` bump (R4, AC 7). The v6 shape is unchanged; only its validation at load is
  stricter.
- No repo-wide `Invariant.check` audit (R7, AC 9). Every other call site that logs-then-proceeds
  under a stripped assert stays exactly as it is; this story touches `_resolve_lock` only.
- No new snapshot keys. `lock_target` (`player_state.gd:267`) is the one hashed key this story
  protects; nothing is added to or removed from the snapshot.
- No presentation or replay-surface changes (no HUD, no debug panel, no new operator-facing message
  beyond the refusal reason string itself).
- No change to what the LIVE capture path writes. `IntentRecorder.capture_advance` /
  `capture_set_lock_direction` and their callers are untouched -- this story validates what is READ
  back (live retarget assignment, replay load), not what is captured.
- No general sweep of `record_file.gd`'s other channels (`camera_pushes`, `contacts`, the rest of
  the per-intent fields such as `move_dir`/`pressed`/`held`) for the same class of unguarded access.
  L7 is scoped to `lock_pushes` specifically and L8 to `retarget_slot`/`retarget_index` specifically
  (R6) -- both findings as filed, not the pattern generalised to every sibling field.
- `camera_pushes` carries the identical unguarded dereference pattern
  (`record_file.gd:513-514`, `for push: Array in camera_pushes.get(tick, [])` then `int(push[0])`,
  `push[1] as Basis`) and is deliberately NOT hardened here -- one structural twin left open, its
  own close-out line so the asymmetry is on the record rather than accidental.

## Open Questions (left to the gate / dev pass, `E4-R/R4`)

- **The exact seat of per-entry `lock_pushes` validation (AC 4).** Whether it lives as a separate
  pre-pass over `data["lock_pushes"]` in `load_record` before `_from_dictionary` is called, or as a
  small helper shared with the intent-field validation (AC 5) and called from that pre-pass, is a
  dev-pass implementation choice, not a design one, as long as R1/R2 hold (whole-record refusal,
  before any mutation of the record under construction; `_from_dictionary` has no refusal channel
  and its rebuild loop is already partway through construction by the time it reaches
  `lock_pushes` -- R10).
- **Whether the live guard (AC 1) is a REJECTION or a CLAMP.** The story requires the malformed
  address not be applied (R3); whether the rejected call additionally clamps the value to something
  sane for logging purposes, or simply declines to write, is left to the dev pass -- either satisfies
  R3 as long as `player.lock_target_slot`/`player.lock_target_index` end the tick unchanged from
  their pre-call value.

## Dev Notes

- **Golden Prediction (full reasoning for AC 8).** `test_determinism.gd`'s golden fixture
  (`GOLDEN := "aa3566d7..."`, `test_determinism.gd:680`) is the output of a real recording session,
  already well-formed, so this story's new refusal/rejection branches are never reached by it -- the
  prediction is that the golden and snapshot key set are UNMOVED. Per R5, that unmoved observation
  proves nothing about whether the new branches are correct, only that they don't over-trigger on
  good data; the actual proof obligation is the mutation table (AC 8).
- **Where M3 lives today.** `match_state.gd:1710-1718` (`_resolve_lock`) calls `Invariant.check`
  twice (slot in {0,1}; index `>= TargetingService.HERO_INDEX`) and then assigns
  `player.lock_target_slot`/`player.lock_target_index` UNCONDITIONALLY on the next two lines --
  the assignment does not currently depend on whether the check passed. `Invariant.check`
  (`src/systems/invariant.gd:11-14`) is `push_error` + `assert`; `assert` is stripped by Godot in
  exported builds, so an exported build logs the violation and then executes the unconditional
  assignment anyway. `lock_target_slot`/`lock_target_index` feed `player_state.gd`'s `lock_target`
  hashed snapshot key (`player_state.gd:267`).
- **Where L7/L8 live today.** `record_file.gd:_from_dictionary` (around line 510-518) reads
  `lock_pushes` per tick and does `int(push[0])` / `push[1] as Vector2` on each entry with no shape
  or type guard -- a PRESENT entry that is truncated or wrong-typed either errors or coerces
  silently, and replays wrong either way (a tick MISSING from the dict is not this defect -- R11).
  `_intent_from_values` (`record_file.gd:544-557`) reads
  `values["retarget_slot"]`/`values["retarget_index"]` by direct dict access with no presence or
  type check, unlike `load_record`'s top-level `REQUIRED_KEYS` loop (`record_file.gd:274-293`),
  which checks both presence and type for every top-level key before the rebuild runs at all -- the
  same discipline this story extends one level deeper, to the CONTENTS of `lock_pushes` and to the
  two named fields inside each intent dict.
- **L7's filed word "sparse" is a misreading (R11).** The writer (`record_file.gd:362-366`) omits
  every empty tick by design; sparseness is the write path's normal output, not a defect. This
  story implements the TRUNCATED/malformed-entry half of L7 only.
- **Existing refusal test pattern to extend.** `test/state/test_record_file.gd` already has five
  refusal tests following one shape (`test_a_record_whose_required_keys_carry_the_wrong_types_is_refused_with_a_reason`,
  line 538, is the closest sibling to AC 4/AC 5): construct a well-formed record, dictionary, or
  round-trip it through `_to_dictionary`/`load_record`'s save/load pair, corrupt exactly one field,
  and assert the refusal's error string names it. New tests for AC 4/AC 5 should sit beside these
  and follow the same construction discipline rather than inventing a new fixture style.

### Project Structure Notes

- No new `src/` file is required by this story's fixed decisions. Touched files (dev pass to
  confirm exhaustively): `src/state/match_state.gd` (`_resolve_lock`, AC 1-3), `src/systems/record_file.gd`
  (`_from_dictionary`'s `lock_pushes` loop, `_intent_from_values`, AND `load_record` -- necessarily
  touched, not "possibly", since AC 4/AC 5 validation must run as a pre-pass there per R10), `test/state/test_record_file.gd`
  (new refusal tests, AC 4/AC 5), and a new or extended state-layer test file for the live-path guard
  (AC 1/AC 2) -- dev's call whether that lives in `test/state/test_targeting_service.gd` (existing
  lock-on coverage) or a new file; name the choice in Completion Notes rather than leaving it
  implicit. No new top-level folder; no scene file is touched.
- **Must-stay-green regression set (F7).** Four suites LOAD records without being edited by this
  story and must be verified deliberately, not by luck of `run_all.sh`: `test/integration/test_record_save_control.gd`,
  `test/integration/test_replay_verifier_tool.gd`, `test/tools/replay_file.gd`,
  `test/state/test_replay_identity.gd`. None is newly refused by this story's stricter validation
  (consumer sweep, gate point 6): every existing fixture's `lock_pushes` entries and intent dicts
  are well-formed by construction.

### Project Context Rules

- F1, D3(a), D3(b)/A2 -- not implicated: no new per-frame loop, no input surface, and both new
  guards read only arguments already passed in (`intent`/`player`, the record `Dictionary`).
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside
  the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier A, small, per `E5-P/R5`'s own text -- full gate + review + live smoke ritual,
  own before/after golden measurement, not shared with `5-1`.

### References

- [Source: decision-log.md:8175-8215] -- `E5-P/R5` (ratification) and `E5-P/R6` (disposition).
- [Source: epics.md:177-179] -- the epic summary line for this story.
- [Source: deferred-work.md:176-185,259-282] -- the `4-6` residue table (M3/L7/L8) and the sibling
  "unowned, named, next-export-build-story" pattern AC 9 follows.
- [Source: 5-1-accelerator-stacking.md:242-243] -- the sibling story's Non-Goals confirming the
  M3/L7/L8 split.
- [Source: src/state/match_state.gd:1702-1747] -- `_resolve_lock`, `_validate_lock`, `_reset_lock`.
- [Source: src/systems/invariant.gd:1-15] -- `Invariant.check`'s export-strip problem (R7).
- [Source: src/state/player_state.gd:158-267] -- `lock_target_slot`/`lock_target_index` and the
  `lock_target` hashed snapshot key.
- [Source: src/systems/record_file.gd:160-299,490-558] -- `REQUIRED_KEYS` doctrine, `load_record`'s
  refusal shape, `_from_dictionary`'s `lock_pushes` loop, `_intent_from_values`.
- [Source: test/state/test_record_file.gd:538-568] -- the closest existing refusal-test sibling.
- [Source: test/state/test_determinism.gd:680] -- `GOLDEN`, AC 8's prediction target.

## Dev Agent Record

### Agent Model Used

Opus 5 (operator-stated).

### Debug Log References

**Preconditions, verified before any edit.** `HEAD` == `origin/main` == `093f8e95` (the promotion
commit `docs(5-1a): gate findings F1-F13 + promote to ready-for-dev`); working tree clean; no
`godot` process running. The frontmatter `baseline_commit: 8eaa8b85` is PRESERVED as authored (the
board-promotion baseline), not overwritten with `HEAD`.

**Suite discipline (`PROC/R1`): EXACTLY TWO full `bash test/run_all.sh` runs**, each one blocking
foreground call, output written OUTSIDE the repo. Every count below is read from the FILE.

| Run | File | Timestamp (local) | State harness | Integration | Verdict |
| --- | --- | --- | --- | --- | --- |
| BEFORE (baseline, pre-edit) | `C:\dev\_51a-suite-before.txt` | 2026-09-04 01:53:22.052 +0200 | 590 tests, 0 failed, 4469 assertions | 52 files, all PASS | `ALL TESTS PASSED` |
| FINAL | `C:\dev\_51a-suite-final.txt` | 2026-09-04 02:16:04.137 +0200 | 595 tests, 0 failed, 4644 assertions | 52 files, all PASS | `ALL TESTS PASSED` |

Machine-time delta between the two file timestamps: **22 min 42 s**.

The two files `diff` IDENTICAL apart from the single counts line -- so the +5 tests / +175
assertions are the only movement in the whole suite, and no integration file changed verdict.

Iteration and the mutation table ran the STATE HARNESS ALONE
(`godot --headless --path . --script res://test/run_state_tests.gd`), never `run_all.sh`, per
`PROC/R1`'s "mutation proofs run ONLY the affected test file".

**Mutation table -- AC 1, AC 2 (both halves), AC 4, AC 5. Every row MEASURED, never reported.**
Both mutated files were copied to
`…\scratchpad\51a-backup\` with a SHA-256 taken BEFORE the first mutation, and each restore was a
COPY-BACK (`git checkout --` never used -- decision-log:799):
`match_state.gd` = `503667906463F13DBEFAF8B845978EEA616FF453C934656F2C265E42C5C78B8B`,
`record_file.gd` = `2CE1482AAE554CBFF23A3FAA384740351CF47812C90323F815848ACFC8E6BE78`. Both files
were re-hashed after the last restore and match those values exactly.

| # | AC | Mutation | Predicted | MEASURED |
| --- | --- | --- | --- | --- |
| M1 | AC 1 | `_is_applicable_retarget` weakened to `return true` (guard structurally intact) | AC 2(a) RED, AC 2(b) green | **595 tests, 1 failed** -- `test_lock_on.gd::test_a_malformed_retarget_address_is_rejected_and_the_standing_lock_is_untouched`. AC 2(b)'s scan stayed GREEN, which is the point: a source scan cannot see a weakened predicate, and a behavioural test cannot see a missing structural guard. Neither half subsumes the other. |
| M2 | AC 2(a) + AC 2(b) | the story's own named mutation -- branch removed, both assignments restored to UNCONDITIONAL at the seat's indent (the shipped 4-6 shape) | both halves RED | **595 tests, 11 failed** -- AC 2(a) RED (the lock moved to the malformed address) AND AC 2(b) RED (the indent assertion). The other nine are collateral: dropping the branch also drops the `NO_RETARGET` no-op, so `test_determinism.gd::test_state_matches_golden` and five sibling lock tests fall too. |
| M3 | AC 2(b) / `5-1a/R9` | an `Invariant.check` re-added at the seat, guard left intact (behaviour unchanged) | AC 2(b) RED alone, and `INVARIANT VIOLATED` printed | **595 tests, 1 failed** -- `test_lock_on.gd::test_the_lock_seat_carries_no_invariant_check_and_guards_both_assignments`, AC 2(a) GREEN. **5 `INVARIANT VIOLATED` lines** in the harness output -- `run_all.sh:19-22,32-35` greps for exactly that string and fails the WHOLE suite on a hit. `5-1a/R9` is therefore MEASURED, not merely asserted: the check and AC 2(a)'s test cannot both be green. |
| M4 | AC 4 (L7) | `_lock_pushes_refusal` call deleted from `_contents_refusal` | AC 4 RED | **595 tests, 1 failed** -- `test_record_file.gd::test_a_record_whose_lock_pushes_carry_a_malformed_entry_is_refused_with_a_reason`, plus **6 `SCRIPT ERROR` lines** from the now-unguarded `int(push[0])` dereference (also a `run_all.sh` grep target). |
| M5 | AC 5 (L8) | `_intents_refusal` call deleted from `_contents_refusal` (lock check left in place) | AC 5 RED | **595 tests, 1 failed** -- `test_record_file.gd::test_a_record_whose_intent_dict_lacks_the_retarget_fields_is_refused_with_a_reason`, plus **4 `SCRIPT ERROR` lines** from the unguarded `values["retarget_slot"]` access. AC 4's test stayed GREEN, so the two guards are independently non-vacuous. |

**Must-stay-green regression set (F7), each verified DELIBERATELY -- `run_all.sh`'s aggregate was
not allowed to stand in for any of them:**

| Suite | How verified | Result |
| --- | --- | --- |
| `test/integration/test_record_save_control.gd` | run standalone, on its own | `RESULT: PASS`, exit 0 |
| `test/integration/test_replay_verifier_tool.gd` | run standalone, on its own | `RESULT: PASS`, exit 0 |
| `test/state/test_replay_identity.gd` | all EIGHT of its tests read by name out of the state-harness output file | 8/8 `[ok]`, including `test_the_lock_direction_channel_is_driven_non_zero_and_is_load_bearing` -- so a NON-EMPTY `lock_pushes` channel really does run through the new validator on a real record |
| `test/tools/replay_file.gd` | not globbed by `run_all.sh` by design, so checked BOTH ways: (a) `test_replay_verifier_tool.gd` spawns it twice on a real v6 record and asserts `RESULT: PASS` + hash identity (`:79-91`) -- PASS above; (b) invoked by hand on the operator's real `user://cardsouls_record_4.rec` | (a) PASS. (b) `REFUSED: record format version 1 does not match this build's 6` -- the SAME refusal as before this story: that file is v1 and the version gate stops it long before the new pre-pass, which runs only after the version and `REQUIRED_KEYS` loops |

**Live smoke (AC 10) is NOT run and is owed to the operator** -- it is a by-hand check of lock,
flick and retarget and there is no headless substitute. See the Live Smoke Results section.

### Completion Notes List

**AC 1-3, the live seat (`src/state/match_state.gd`).** `_resolve_lock`'s two `Invariant.check`s
are GONE and the two address assignments now sit under a plain runtime branch,
`if _is_applicable_retarget(intent):`. Open Question 2 (REJECT or CLAMP) is answered by
**REJECTION**: the seat simply declines to write, so `lock_target_slot`/`lock_target_index` end the
tick at their pre-call values and nothing reaches the hashed `lock_target` key on a rejected tick.
A clamp would invent an address nobody asked for. `_validate_lock` is untouched and still runs on
EVERY tick regardless of the branch (AC 3) -- the rejected-address path and the dead-unit liveness
snap remain two separate mechanisms, as the AC requires.

`InputIntent.NO_RETARGET` (-1) is named explicitly in the predicate rather than left to fall out of
the `slot == 0 or slot == 1` test. It would fall out correctly, but "no click and no flick this
tick" is a DIFFERENT fact from "malformed", and a reader who has to re-derive it from `-1` will
eventually derive it wrong.

**AC 4-7, the replay load (`src/systems/record_file.gd`).** Open Question 1 is answered by a
**shared pre-pass**: `load_record` calls one new `_contents_refusal(data)` immediately after the
existing `REQUIRED_KEYS` presence and type loops and immediately BEFORE `_from_dictionary` --
`5-1a/R10`'s seat exactly. `_from_dictionary` itself is UNCHANGED; it has no refusal channel and
its rebuild loop is already partway through construction by the time it reaches a tick, so
refusing there would be the partial replay `5-1a/R2` forbids. Refusal is whole-record: the first
malformed thing found anywhere returns a reason and no record is built (AC 6).

`_contents_refusal` fans out to `_lock_pushes_refusal` (AC 4) and `_intents_refusal` (AC 5), and
every reason names the tick -- plus the slot and field for intents, plus the entry index for lock
pushes. All refusals use the existing `_refused()` shape, so `{"record": null, "error": <reason>}`
is unchanged for callers.

`5-1a/R11` is implemented as written: `_lock_pushes_refusal` iterates only the tick keys that are
PRESENT and asserts nothing about which ticks appear. A tick absent from the dictionary is never
looked at, and the test carries an explicit `lock_pushes == {}` case that must LOAD -- the writer's
own normal output.

**One scope judgment, flagged rather than taken silently.** `_intents_refusal` checks that each
`intents` element is an Array and each of its members a Dictionary before checking the two named
fields. That is not a widening of `5-1a/R6`: `has()` cannot be asked of something that is not a
Dictionary, so the container check is what makes AC 5's field check well-defined at all. The other
seven per-intent fields (`move_dir`, `pressed`, `held`, `debug_reset`, `card_slot`, `card_mode`,
`card_commit`) carry the identical unguarded access and are deliberately NOT validated, and
`camera_pushes` -- the structural twin named in the Non-Goals -- is deliberately left open. Both
exclusions are stated in the shipped source comments so the asymmetry is on the record.

**AC 7 is pinned by a test, not only by the diff.** `test_the_contents_validation_bumped_no_version_and_widened_no_required_key`
asserts `FORMAT_VERSION == 6`, that neither `retarget_slot` nor `retarget_index` is in
`REQUIRED_KEYS`, and that `REQUIRED_KEYS` still has exactly TWELVE entries -- the count
`5-1a/R12` took at the readiness gate.

**AC 8, Golden Prediction: HELD, and it proves nothing on its own (`5-1a/R5`).** Golden
`aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`
(`test_determinism.gd:680`) is UNMOVED -- the constant was not edited (the file is not in the File
List) and `test_state_matches_golden` passed in both suite runs. The 28-key per-player snapshot set
is likewise unmoved, pinned by `test_card_observation.gd:298` which passed in both runs. Per
`5-1a/R5` this observation shows only that the new branches do not OVER-trigger on good data; the
proof obligation is the mutation table above, and it is discharged there.

**Test placement (named here rather than left implicit, per Project Structure Notes).** AC 1/AC 2
went into the EXISTING `test/state/test_lock_on.gd` rather than a new file -- that file already
owns the state-layer half of the lock and carries `_retarget_intent`/`_lock`/`_advance`. Its only
new fixture is the source-scan trio `_code_lines` / `_function_body` / `_indent_width`;
`_code_lines` is the `test_targeting_service.gd:695-706` helper verbatim, which is the idiom AC 2
half (b) names. `_function_body` scopes the `Invariant.` scan to the ONE seat: a whole-file scan of
`match_state.gd` would fail on the many legitimate checks elsewhere, which `5-1a/R7` explicitly
leaves alone.

**AC 9 is OWED TO CLOSE-OUT and is not discharged by this dev pass.** The general condition --
`Invariant.check` being non-load-bearing wherever else it is called in `src/` under a stripped
`assert` -- is fixed ONLY at the `_resolve_lock` seat here. It must be recorded at close-out as a
named item owned by the FIRST story that adds an exported/distributable build, the same owner class
`deferred-work.md:176-185` already names for the sibling `DebugInstrumentPanel` gate finding. The
`camera_pushes` twin (`record_file.gd`, `for push: Array in camera_pushes.get(tick, [])`) owes its
own close-out line for the same reason.

**NO COMMITS.** Everything above is in the working tree only, per the operator's instruction. Six
files are modified; nothing is staged and nothing is committed.

### File List

| File | Change |
| --- | --- |
| `src/state/match_state.gd` | MODIFIED -- `_resolve_lock` gated, its two `Invariant.check`s removed; new `_is_applicable_retarget` static predicate (AC 1-3) |
| `src/systems/record_file.gd` | MODIFIED -- `load_record` calls the new pre-pass; new `LOCK_PUSH_TYPES` / `REQUIRED_INTENT_FIELDS` constants and `_contents_refusal` / `_lock_pushes_refusal` / `_lock_push_entry_refusal` / `_intents_refusal` / `_intent_fields_refusal` (AC 4-7). `_from_dictionary` and `_intent_from_values` UNCHANGED |
| `test/state/test_lock_on.gd` | MODIFIED -- two new tests (AC 2 halves (a) and (b)) plus the `_code_lines` / `_function_body` / `_indent_width` scan fixture |
| `test/state/test_record_file.gd` | MODIFIED -- three new tests (AC 4, AC 5, AC 7), three new tick/slot constants, and the `_rewrite_intent_field` corruption helper |
| `docs/implementation-artifacts/5-1a-intent-hardening.md` | MODIFIED -- Status `ready-for-dev` -> `review`; Dev Agent Record filled |
| `docs/implementation-artifacts/sprint-status.yaml` | MODIFIED -- `story_notes` only. `development_status` stays `ready-for-dev` per `CFG/R2`/`CFG/R5` -- `review` is a story-file-only value and board promotion is the operator's chain commit |

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-04 | Story authored via `gds-create-story`. |
| 2026-09-04 | Readiness gate fix pass: AC 2/AC 4/AC 7/AC 8 corrected, OQ 1/OQ 3 resolved, must-stay-green suite set and camera_pushes asymmetry recorded, length trimmed where free; promoted to `ready-for-dev` (`5-1a/R9-R12`). |
| 2026-09-04 | Dev pass via `gds-dev-story`. AC 1-8 implemented and measured; 5 new tests (590 -> 595, 4469 -> 4644 assertions), golden `aa3566d7` and the 28-key snapshot set UNMOVED, 5-row mutation table all MEASURED RED, four must-stay-green suites verified individually. AC 9 owed to close-out; AC 10 (live smoke) owed to the operator. Status -> `review`. NO COMMITS -- working tree only. |
| 2026-09-04 | Code review (Sonnet 5): PASS-with-findings, 0 HIGH / 0 MED / 2 LOW. Both LOW findings accepted without change and recorded at close-out. |
| 2026-09-04 | Live smoke, 5/5 PASS, no findings. Status -> `done`. |

### Live Smoke Results

Operator smoke pass, 2026-09-04, 5/5 PASS, recorded verbatim in `docs/playtest-log.md`'s 5-1a entry.
No findings.

1. `R3` click relocks to the opposing hero.
2. Flick retargets in all four directions.
3. Killing the locked unit snaps the lock to the hero on the same tick.
4. The marker sits on the body, disappears on round-over, and returns on reset.
5. FPS stable throughout, with a clean console.

Nothing in this story changes what any of these DOES on a well-formed address -- the machine
evidence for that is AC 2(a)'s well-formed pair (applied before and after five rejections) and the
unmoved golden. The smoke exists to catch a break the suite cannot see.
