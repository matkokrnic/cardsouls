---
baseline_commit: 8eaa8b85389a05b0c2adb7638e508f135f7a19f3
---

# Story 5.1a: Intent hardening

Status: ready-for-dev

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

_Not yet run._

### Debug Log References

_Not yet run._

### Completion Notes List

_Not yet run._

### File List

_Not yet run._

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-04 | Story authored via `gds-create-story`. |
| 2026-09-04 | Readiness gate fix pass: AC 2/AC 4/AC 7/AC 8 corrected, OQ 1/OQ 3 resolved, must-stay-green suite set and camera_pushes asymmetry recorded, length trimmed where free; promoted to `ready-for-dev` (`5-1a/R9-R12`). |

### Live Smoke Results

_Not yet run._
