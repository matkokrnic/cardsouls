---
title: Sprint Change Proposal -- Camera/Lock-On Adoption into Epic 4
date: 2026-08-30
status: approved
scope: moderate
---

# Sprint Change Proposal -- Camera/Lock-On Adoption into Epic 4

## 1. Issue Summary

Camera/lock-on was explicitly named OUT of epic 4 at the E4 ratification session
(`E4-P/R11`, decision-log Session 2026-08-07): "camera always-lock-on/retarget (no owner --
NOTE: a board full of minions may hand this a forcing point during E4; if so, that is a
`gds-correct-course`, not silent adoption)." The underlying open decision, `DP/R1` (decision-log
Session 2026-07-31), left two sub-questions unresolved: (i) whether facing follows the locked
target, and (ii) how off-frame targets (minions/totems pulling the enemy hero out of view) are
handled.

4-4-totems is now DONE (board `done`, 2026-08-30) -- the board has minions and totems, i.e. more
than one possible lock-on target exists. `E4-P/R11`'s own named forcing-point condition ("a board
full of minions may hand this a forcing point") is met. The operator ruled, in the browser
(2026-08-30), to adopt camera/lock-on into epic 4 now, via this `gds-correct-course` run, exactly
the mechanism `E4-P/R11` reserved for this. This is the anticipated procedural path, not scope
creep.

**Evidence:** `E4-P/R11` and `DP/R1`, both in `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md`; board state in `docs/implementation-artifacts/sprint-status.yaml` (`4-4-totems: done`).

## 2. Impact Analysis

**Epic impact.** Epic 4's story sequence (`E4-P/R1`: 4-0 -> 4-0a -> 4-B1 -> 4-1 -> 4-2 -> 4-3(+letters) -> 4-4 -> 4-5-pooling) gains one new backlog story, `4-6-camera-lock-on`, ordered by the operator BEFORE `4-5-pooling-60fps-exit` despite the numeral (numbering stays historical/sequential-by-creation-date, not board order -- consistent with existing precedent, e.g. `4-3a`..`4-3e` interleaving). No epic is removed, redefined, or reordered; only epic 4's own internal story queue gains a member.

**Story impact.** No existing story file is edited. `4-5-pooling-60fps-exit` (currently `backlog`) is unaffected in content; its board position now sits behind `4-6-camera-lock-on` per the operator's explicit ordering instruction, recorded in `4-6`'s own `story_notes` (not by renumbering `4-5`).

**Artifact conflicts.**
- **GDD / decision-log:** `DP/R1`'s two open sub-questions are now answered (see Section 4). This is recorded as a NEW forward-pointing decision-log entry -- `DP/R1` itself is left intact per the log's own "corrected forward, never rewritten" rule (`2-2 addendum A4`); the sole logged exception (`DP/R2`, an explicit one-off under direct operator instruction) is not repeated here.
- **Architecture (`docs/game-architecture.md`):** not read/edited by this pass -- no invariant (F1, D3(a), D3(b)/A2) is touched by adopting the decision at the planning level. The eventual story's dev pass will need to confirm `HeroState.facing`'s move from input-derived to target-derived does not violate D3(b)/A2 (target-derived facing must still be computed from injected facts, not from a live camera/scene query inside `src/state/`) -- flagged for the story's own readiness gate, not resolved here.
- **`epics.md`:** E4's "Committed obligations" gains one bullet recording the adoption and the ordering note (Section 4 below).
- **UI/UX:** none exists as a separate artifact for this project; controls are specified inline in the GDD/decision-log, covered in Section 4.
- **`project-context.md`:** not touched -- CLAUDE.md's own rule is that this file is derived from the GDD/architecture, corrected on a later pass once real code exists, not edited speculatively ahead of implementation.

**Technical impact.** None yet -- this proposal adopts the DECISION and creates the BACKLOG entry only. No code changes, no golden re-baseline, no test changes. The eventual story is pre-declared hard Tier A (facing ownership change touches the golden and snapshot by the operator's own accepted-consequence ruling), so it will carry the full ritual (readiness gate -> dev pass -> code review -> live smoke) per `E4-P/R9`.

## 3. Recommended Approach

**Selected: Option 1 -- Direct Adjustment (backlog addition), Moderate scope.**

- Rollback (Option 2) is not applicable -- nothing is being undone.
- MVP/PRD review (Option 3) is not needed -- this is an IN-scope epic-4 addition the GDD's own decision-log already anticipated as a live possibility (`E4-P/R11`'s forcing-point note), not a pivot.
- Direct Adjustment fits: add one backlog story to epic 4's queue, resolve the open decision's content in the log, note the ordering. Effort: Low (this pass). Risk: Low (no code touched; the eventual story carries its own full Tier A gate where the real risk -- facing-ownership migration, block-arc/orientation-as-defense consequences -- gets adjudicated).

## 4. Detailed Change Proposals

### 4.1 Decision-log -- new entry resolving `DP/R1`

**Appended as a new session entry** (not an edit to `DP/R1` itself), recording:

1. **FULL variant adopted.** The hero always faces the locked target regardless of movement direction. `HeroState.facing` ownership moves from input-derived to target-derived. Golden WILL move; snapshot is touched. Accepted consequence: against the locked target, the 180-degree block arc never misses, so block becomes pure timing (Sekiro-style); orientation-as-defense migrates into target selection, since minions/totems can attack from outside the locked frame.
2. **Always lock-on, never a free camera** (confirms `DP/R1`'s decision as originally recorded). Default and fallback target: the opposing hero. The `InputIntent.aim` free-rotation route named at the 1-2 gate is SUPERSEDED, not supplemented -- consistent with `DP/R1`'s own original wording ("This SUPERSEDES the free-rotation route... rather than adding to it").
3. **Controls (DS/ER/Sekiro model).** Right-stick CLICK instantly re-locks onto the opposing hero. Right-stick FLICK switches lock to the best on-screen candidate in that screen-space direction (minions, totems, hero). No unlock state. Off-screen opposing hero is resolved by the click; the telegraph SOUND remains the only off-screen attack signal for now -- recorded as a NAMED PLAYTEST QUESTION, not story scope: *does sound alone give adequate warning of an off-screen unblockable telegraph, given the Legibility Principle's <0.5s visual-read requirement was written assuming the target is on-screen?*
4. **Live smokes run primarily on controller from now on**, per the operator (game targets controller feel; the 2-2 pad-plugged-in-before-launch constraint stands).
5. **Delegated implementation direction** (named, not decided, here -- the dev pass's terrain): retarget resolution follows the contact-fact precedent (`1-8`/`4-1` R7 lineage) -- positions/screen space live outside `src/state/`; the presentation side resolves a flick into a chosen target and pushes the RESULT (`[slot, index]` or hero) as an input fact into the intent stream; replay records the outcome, not the stick. Keyboard mapping is proposed in the story; controller is primary.

### 4.2 `epics.md` -- E4 Committed obligations

Add one bullet under E4's "Committed obligations":

> Camera/lock-on (`DP/R1`, `E4-P/R11`) is ADOPTED into E4 via `gds-correct-course`, 2026-08-30 --
> the board-full-of-minions forcing point `E4-P/R11` named has been met (4-4-totems done). Story
> `4-6-camera-lock-on` enters the backlog, board-ordered BEFORE `4-5-pooling-60fps-exit` per
> operator instruction; the numeral is historical/creation-order, not board order (existing
> precedent: `4-3a`..`4-3e` interleaving). Hard Tier A by the golden clause (`HeroState.facing`
> ownership migrates from input- to target-derived).

### 4.3 `sprint-status.yaml` -- backlog addition only

Add exactly one new entry under `development_status`, directly after `4-5-pooling-60fps-exit`:

```yaml
  4-6-camera-lock-on: backlog        # Tier A (adopted 2026-08-30 via gds-correct-course, DP/R1 + E4-P/R11; board-ordered before 4-5-pooling per operator, numbering historical)
```

And a `story_notes` entry:

```yaml
  4-6-camera-lock-on: "BACKLOG, adopted 2026-08-30 via gds-correct-course -- camera/lock-on (DP/R1, E4-P/R11) brought into epic 4 now that the board carries minions and totems (4-4-totems done), the forcing point E4-P/R11 itself named. FULL variant: HeroState.facing ownership moves from input- to target-derived (hard Tier A, golden and snapshot WILL move -- accepted consequence). Always locked, never free camera; default/fallback target the opposing hero; InputIntent.aim free-rotation route SUPERSEDED. Controls: right-stick CLICK re-locks opposing hero, right-stick FLICK retargets to best on-screen candidate by screen-space direction (minions/totems/hero), no unlock state. Retarget resolution follows the contact-fact precedent -- presentation resolves the flick, pushes the chosen target as an input fact; replay records the outcome, not the stick. Off-screen opposing-hero telegraph relies on sound only for now -- named playtest question, not story scope. Live smokes run primarily on controller from here forward. BOARD ORDER: before 4-5-pooling-60fps-exit per operator instruction; numbering is historical/creation-order only. Story spec authoring is a separate gds-create-story run, not done by this pass."
```

No other board state is touched: `epic-4` stays `backlog` at the root (unchanged), no story is promoted, no other story's status changes.

## 5. PRD / MVP Impact and Action Plan

MVP is unaffected -- camera/lock-on was already an anticipated epic-4-or-later item (`E4-P/R11`'s own note), not new scope invented here. Action items, in order:
1. This proposal + decision-log entry + `epics.md` note + `sprint-status.yaml` backlog entry (this pass, docs-only commit).
2. A separate `gds-create-story` run authors the `4-6-camera-lock-on` story file, including the readiness-gate questions the delegated implementation direction (Section 4.1.5) leaves open, and any keyboard-binding proposal.
3. `4-6-camera-lock-on` runs its full Tier A ritual once promoted to `ready-for-dev` per the normal per-story promotion check (`CFG/R2` -- no workflow promotes it automatically).

## 6. Implementation Handoff

**Scope classification: Moderate** -- backlog reorganization + decision-log resolution, no code. Routed to:
- **Operator (Matko):** reviews and pushes this docs commit; decides when to invoke `gds-create-story` for `4-6-camera-lock-on`.
- **Product Owner / Developer (future pass):** `gds-create-story` authors the story file when picked up; the story's own readiness gate settles the delegated-but-undecided implementation details (Section 4.1.5) and confirms the D3(b)/A2 boundary question flagged in Section 2.

**Success criteria:** decision-log carries a resolving entry for `DP/R1`; `epics.md` records the adoption and ordering; `sprint-status.yaml` carries exactly one new `backlog` entry (`4-6-camera-lock-on`) and no other board-state change; one docs-only commit, not pushed.
