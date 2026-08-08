# Process Retrospective — Tier B pilot (`4-B1`) and workflow cost

Date: 2026-08-08
Subject: the Tier B pilot story `4-B1-card-hud-debt-discharge` and the machine cost of the workflow
around it. **This is NOT the epic-4 retrospective** — `E4-P/R11` forbids one until E4 closes, and
`4-1`..`4-5` are still `backlog`.

**Filename is deliberately not `epic-*-retro-*.md`** — a future epic-4 retrospective discovers
previous retros by that glob (`gds-retrospective` Step 3, `previous_retrospective`), and this
document must not be picked up as the prior-epic record.

State at retro: `HEAD == origin/main` at `b04b9e2`, working tree clean, suite green
(`373 tests / 2397 assertions / 0 failed` + 23 integration files), golden
`312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c` unmoved since `4-0`.

Ratified by the operator 2026-08-08. Rulings recorded as `PROC/R1`..`PROC/R9` in `decision-log.md`,
Session 2026-08-08 — process retrospective; the operational half also lands in
`project-context.md`'s Testing Rules. This document carries the evidence and the reasoning, and does
not restate the rules.

**The board is deliberately not touched by this document**, for the reason the E3 retro gave:
`sprint-status.yaml` carries no `epic-N-retrospective` key for any epic, and its header locks the
lifecycle to exactly `backlog -> ready-for-dev -> done` ("No other states").

---

## 1. Deviations from the `gds-retrospective` skill, reported not skipped

1. **Steps 1, 4, 7 (epic discovery / next-epic preview / next-epic prep) do not apply** — epic 4 is
   open. Ran as a process retro on one story instead.
2. **Steps 11-12 skipped** (save-document, board write-back): the report pass was REPORT-ONLY, and
   the write-back has no target, verified against `sprint-status.yaml`.
3. **Party-mode dialogue format dropped** in favour of an evidence report. **Step 3
   `previous_retrospective`**: the E3 retro read as *format precedent*, not as follow-through.
4. **The skill's "NEVER mention time" rule overridden** by the operator's agenda, which asks for a
   machine-time budget. All figures here are measurements, never predictions.

## 2. Two material corrections to the operator's own briefing

### 2.1 D1's provenance — the manual auditor coverage did NOT produce it

The briefing stated the manual coverage of the stalled Acceptance Auditor produced finding D1
(HIGH). `4-B1-card-hud-debt-discharge.md` (Review Findings) records otherwise: exactly **two**
findings carry the `[manual-auditor]` tag — the unevidenced "full suite re-run green after every
restore" claim, and the incomplete File List — and **both are severity LOW**. D1 is untagged, so it
came from the main review session or from a layer that COMPLETED.

Second half: the fix pass **measured D1 down from HIGH**. A probe drove the real state machine for
400 ticks across seven deck sizes and three delays, casting whenever a card was castable, and hit
the both-empty degrade's precondition **zero times in 21 runs**; recorded honest severity is
"defense-in-depth for a rendering contract".

**Why it matters:** this strengthens `PROC/R2`. The flaky infrastructure's manual replacement cost
two LOW documentation patches, not a HIGH defect — so moving the auditor's checks inline gives up
little, and the 10-minute watchdog stall buys nothing.

### 2.2 The measured suite cost demotes the surplus-runs finding

`bash test/run_all.sh` measured at **1m35s wall clock** (full state harness + all 23 integration
files, green), so the dev pass's four surplus runs cost **~6-7 min** — about 6% of the story's
~113 min, and the SMALLEST of the four sinks. The real sinks were the two pixel-fit label passes and
the watchdog stall. `PROC/R1` is still worth having — nearly free, and it removes an unevidenced
claim class — but it is not the fix for the cost problem. `PROC/R8` is.

## 3. Per-item evidence

### 3.1 Suite cadence -> `PROC/R1`

- **Runs 3-6 left no trace of catching anything.** The review's provenance audit found the Dev Agent
  Record's "Full suite re-run green after every restore" unevidenced — the mutation table's four
  rows each name a single test run. The RESTORES were evidenced and independently re-verified: all
  four files SHA256-matched their pre-mutation scratchpad backups.
- **The mutation half is codification, not change** — M1-M4 each already named a single test file.
  And the fix pass twice recorded "Full suite not re-run — nothing here reaches `src/state/`",
  correct both times; `PROC/R1` turns a repeated ad-hoc call into a rule.
- **Cost accepted:** a late cross-file regression could go unseen until close. The golden and
  snapshot-key pins ride in both mandated runs by construction — that is the mitigation.

### 3.2 Review shape -> `PROC/R2`, and the stall history

| Run | Stalled layer | Cost | What the manual coverage produced |
|---|---|---|---|
| `3-6` | Acceptance Auditor | not timed | 2 patches (freed-timer, label overflow) + closed a deferred bound (`3-6/R8`) |
| `4-0` | Edge Case Hunter (600s) | not timed | three targeted non-vacuous checks; 0 decision items, 2 patches |
| `4-B1` | Acceptance Auditor (600s) | 10 min (operator) | 2 LOW patches, both `[manual-auditor]` |

Three stalls, a different layer each time, and in **no case did the absent layer cost a HIGH
finding** — `4-B1`'s substantive findings (D1, the vacuous reveal test, the RefCounted lambda cycle)
all came from layers that completed or from the main session.

**The checklist `PROC/R2` mandates already exists verbatim** as the review's "Verified clean by the
manual auditor pass" paragraph: seams-still-eight; the GDD privacy lock's reachability; CONSTRAINT C
at the point of use; back-compat at every pre-existing call site; the machine check in both
viewports; no `src/state/` file in the diff; `to_snapshot()` untouched; and the Dev Agent Record
evidence audit. That last is non-negotiable — the only check that audits the RECORD, not the code,
and the one that caught §2.1.

**In-place annotation, ruled.** `4-B1`'s corrections live only in the fix-pass section below the Dev
Agent Record, so a reader hitting the record first reads the wrong thing.

### 3.3 Edit fallback -> `PROC/R3`

The hazard class is verifiably pervasive: the decision-log, every story artifact and
`deferred-work.md` are dense with em-dashes (mixing `--` with the character inconsistently), while
every `.gd` source is tab-indented — any docs+code story meets both. **Provenance caveat:** the
thrashing itself is operator-observed and **not recorded in the repo** (the Dev Agent Record's Debug
Log References carries only the golden measurements and the mutation table), so the rule rests on
the hazard's ubiquity, not on a repo-side count.

### 3.4 Tier B bookends -> `PROC/R4`

- **KEEP, story open:** `4-B1/R1` (panel surface, Callable handoff, named pin exception) and
  `4-B1/R2` (debug-only, GDD privacy lock stands). The Dev Agent Record credits exactly this: "BOTH
  OPEN QUESTIONS WERE ALREADY RULED ... so the toggle was BUILT, not deferred again."
- **KEEP, cross-story:** `4-B1/R6`, the Tier B suspension. **KEEP, close-out:** `4-B1/R3` (a
  tier-boundary crossing), `4-B1/R4` (build-gate deferral), `4-B1/R5` (smoke scope).
- **REMOVES:** the round trips behind the two failed reveal-label passes. The precedent is in the
  file — the review put D1's tier question to the operator directly and got `4-B1/R3` back
  in-session.

### 3.5 Home split -> `PROC/R5`

`E4-P/R9`'s HOME clause reads "`project-context.md` is not touched, since ... a process policy is
derived from neither [GDD nor architecture]." That holds for TIER POLICY. It does not describe what
`project-context.md` already contains: its Testing Rules already carry three pure process rulings —
mutation-proof discipline (`3-0d/R14`), guard-mechanism-over-pattern (`3-0d/R20`), and the
adversarial-review failure criterion (3-0d close-out). `PROC/R1`/`R2`/`R3`/`R7`/`R8` are the same
species and go to the same home; `PROC/R5` narrows `E4-P/R9`'s reasoning to tier policy so the two
stop reading as contradictory.

### 3.6 Un-suspension -> `PROC/R6`

`E4-P/R9` AMENDMENT 2's stated predicate is the PARALLEL-LAYER INFRASTRUCTURE ("Tier B leans on that
infrastructure harder than Tier A does"), not review quality and not Tier B's economics. `PROC/R2`
deletes the stalling layer from the chain and re-homes its checks in a session that has never
stalled, making the clause's failure mode unreachable by construction — the repo's own preferred
remedy shape (`3-0d/R20`). The counter therefore **resets to 0 at ratification** rather than waiting
for a clean run to earn it: the mechanism that was counted no longer exists, so the count has no
subject. Under the new shape three consecutive stalls re-suspend, and the layer-completion line
`4-B1`'s review already emits is the evidence format — a review missing it counts as a stall, so
silence cannot be mistaken for success.

### 3.7 Budget -> `PROC/R7`, and the case study

`4-B1` was chosen as the pilot because it was cheap: two ACs, HUD-only, golden and snapshot key set
predicted unmoved and **measured unmoved throughout** both passes. It cost ~113 min agent-side
(77 dev + 36 review) for what the operator judges ~60 min of real work. Where the surplus went:

| Sink | Measured / estimated | Basis |
|---|---|---|
| 4 surplus full-suite runs | ~6-7 min | 1m35s x 4, measured 2026-08-08 |
| Acceptance Auditor watchdog stall | 10 min | operator; 28% of the whole review |
| Two pixel-fit reveal-label passes | ~16-24 min (est.) | each a diff + targeted re-run + a browser round trip; both failed the SAME way |
| Edit thrashing on em-dash/tab files | not separately timed | operator; residual |

**What Tier B actually bought:** the separate readiness-gate PASS and nothing else — `E4-P/R9`
AMENDMENT 1 already priced this honestly ("removes the separate gate PASS, not the gate"; 22/22
gates in project history returned NOT READY on first reading). The checklist plus operator promotion
still ran, and worked: `4-B1/R1`/`R2` were ruled before the dev pass, so the toggle was built rather
than deferred a third time.

**Estimated saving from `PROC/R1`-`R4`: ~25-35 min**, landing `4-B1` at ~80-90 min — **still over
the ~1 h budget.** That is the load-bearing conclusion: the four workflow rulings are worth adopting
and do not, by themselves, meet the budget. The remaining gap is the pixel-fit class, which is why
`PROC/R8` exists.

### 3.8 Text fit -> `PROC/R8`

Two label passes each verified the RECT machine-side (`panel_layout=true`, both viewports) and never
the text fit; both were rejected by the operator at first sight for the same reason, and only the
third pass changed the MEDIUM (`4-B1/R7`, the console) instead of the font. A guard that cannot fail
for the reason the operator will reject the work is a vacuous guard by this repo's own doctrine
(`3-0d/R20`) — the machine check was not wrong, it was measuring the wrong property.

### 3.9 Board writes -> `PROC/R9`

The `4-B1` dev pass modified `sprint-status.yaml`, a docs file, inside a code pass; the review caught
the resulting File List omission but not the convention question. `fceed8b` confirms the premise:
`gds-dev-story`'s Step 9 writes the board and `_bmad/custom/gds-dev-story.toml`'s `on_complete`
reverts it — the write is an expected working-tree effect of running the skill, not an authoring
choice, so `PROC/R9` puts the separation duty on the close-out chain, where it can be discharged.

## 4. Non-blocking

- The `4-B1` Dev Agent Record still carries the two claims the review falsified; `PROC/R2`'s
  in-place annotation rule applies to future stories and is not applied retroactively.
- `sprint-status.yaml`'s stale header comment is corrected in this same commit chain.
