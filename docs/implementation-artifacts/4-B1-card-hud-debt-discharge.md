---
baseline_commit: b73eea9eb04bb2063e84997424ef28b2a6832ca5
---

# Story 4.B1: Card HUD debt discharge

Status: done

> **Scope note.** Position 2 of the E4 order (`E4-P/R1`, decision-log Session 2026-08-07 -- E4
> ratification), placed here deliberately: Tier B, discharges an escaped E3 obligation, exercises
> the Tier B lane before feature work leans on it. Tier B per `E4-P/R9` (CLAUDE.md's Story tiers
> section points here rather than restating it): no separate readiness-gate pass, but the
> `gds-create-story` checklist plus operator review before `ready-for-dev` promotion still applies
> (Amendment 1) -- discharged by `_bmad/custom/gds-create-story.toml`'s `on_complete`, which is why
> this file's `Status:` line comes out of this run as `authored`, not `ready-for-dev`, pending that
> review (the board entry stays `backlog` throughout, per `CFG/R3`).

## Scope, verbatim from the source that discharges it

Two items, ratified at the E4 planning pass (`E4-P/R1`). Nothing else. Peripheral mana/deck
legibility is explicitly named OUT at the same session (`E4-P/R11`: "peripheral mana/deck
legibility (operator-deferred until the full loop exists at E6; not folded into 4-B1)") --
depends on the full gameplay loop, which does not exist until E4/E6 land minions and consequences.
Do not pull it in.

### Item 1 -- the 4-0 deferred finding, quoted verbatim

`docs/implementation-artifacts/deferred-work.md`, "Deferred from: code review of
4-0-hand-slot-stability (2026-08-07)":

> **AC 8's permanent hole is visually indistinguishable from a slot mid-flight awaiting
> delivery.** Both render the same blank caption (`Hand.EMPTY` -> empty string), and nothing in
> the 4-0 diff or its tests distinguishes "temporarily empty, refilling soon" from "dead for the
> round" to the player [src/ui/hud/hud_root.gd]. Deferred because the story's own AC 7 forward
> constraint already scopes HUD affordability/greying rendering out of this pass ("no cost,
> affordability or greying rendering in src/ui/ today... this AC binds that future work; it
> requires no HUD code now"), and AC 9's outstanding live smoke is where this would first become
> player-visible in practice.

The ACs below are built from these exact words -- "visually indistinguishable," "temporarily
empty, refilling soon" versus "dead for the round" -- not from a paraphrase.

### Item 2 -- the reveal-opponent-hand toggle, an undischarged E3 obligation

`E3-RG/R5` (decision-log:1154) first assumed the toggle was a cheap flip of
`HudRoot._make_card_face_style(is_own)`, the single seat the face-down rule was required to live
in as the condition of 2-5's own deferral (2-5/R4, decision-log:767, "landed there" per the 2-5
close-out, decision-log:785). That assumption did not survive `E3-RG/R4`'s literal application:
`3-6/R1` (decision-log:5026) records the contradiction and the actual disposition:

> **`3-6/R1` -- the reveal-opponent-hand toggle leaves this story.** `E3-RG/R4` stands. The toggle is
> removed as an AC and recorded as a named deferral, not a cancellation: it is cheap once `3-6/R2`'s
> seam ships (hand ids are already in hand at that point), owned by the first future story that touches
> `src/ui/hud/` card rendering -- no story number assigned, not an E3 exit criterion.

This story is that first future story touching `src/ui/hud/` card rendering. `3-6/R2` shipped:
own-hand ids reach `HudRoot` via `connect_cards_changed`, the runner's eighth `connect_*` seam
(`test/state/test_architecture_invariants.gd:284-291`,
`test_runner_observation_seams_are_exactly_eight`). The opponent's hand ids do **not** reach
either `HudRoot` today -- see M4 below for what that costs a toggle.

## Four measurements (verified by file content, not by this prompt's paraphrase)

### M1 -- the two deferred-work.md entries (quoted above, verbatim)

Both quoted in full under "Scope" above. No third entry in the file applies (the other entry,
"Deferred from: code review of 3-6," is CLOSED by `3-6/R8` and out of scope here).

### M2 -- `pending_draw_owed`: Tier B rests on this

`src/state/player_state.gd:82`: `var pending_draw_owed: Array[int] = []` -- **slot-addressed**
(a FIFO of owed hand-slot indices, not a plain count; shaped this way by 4-0 AC 4/`4-0/R6`).
`src/state/player_state.gd:185`: `"pending_draw_owed": pending_draw_owed.duplicate()` -- **present
in `to_snapshot()`**, and hashed (it is one of the two 3-5b/R8 keys, and 4-0's Golden Prediction
named its shape change as Cause 1, the mover that re-baselined the golden from `40eb5554...a322`
to the current `312522d8...fb3c`).

**Both premises hold.** The Tier B classification's structural half is confirmed: this story reads
an already-shipped, already-slot-addressed, already-hashed field -- it needs no new snapshot key,
no new seam, and no state-layer write. (Tier B's OTHER half -- golden and snapshot-key-set unmoved
-- is not a structural fact to verify in advance; it is the measured escalation clause below.) No
escalation grounds found for M2 alone.

### M3 -- the reveal-toggle deferral condition and the privacy lock

The recorded condition, quoted in full under "Item 2" above (`3-6/R1`, decision-log:5026): the
toggle is "owned by the first future story that touches `src/ui/hud/` card rendering." This
story is that story, by content (Item 1 alone touches `src/ui/hud/hud_root.gd`).

**"The rule must live in ONE seat"** -- confirmed locked, twice over:
- 2-5/R4 (decision-log:767) made single-seat ownership the condition of deferring the toggle in
  the first place; the 2-5 close-out (decision-log:785) confirms it landed at exactly one seat,
  `HudRoot._make_card_face_style(is_own)`.
- `E3-RG/R5` (decision-log:1154) verifies the seat is STILL exactly one, by content, at the E3
  gate: "the single ownership seat is already `HudRoot._make_card_face_style(is_own)`... so the
  toggle is a flip of that one parameter, not a second rule."

**"Hands are private; the pitched card is the only public information"** -- confirmed locked.
`E3-RG/R4` (decision-log:1148-1150), citing `2-5/R9` (decision-log:777) and `epics.md:181-182`:
"the GDD makes the pitched card the only public information... the only lock: the pitched card is
the sole public information, hands stay private otherwise." This is a GDD-level design lock, not a
per-story convention -- an operator-authored gameplay reveal toggle would need a fresh ruling
against it; a debug-only toggle does not (see Open Questions).

### M4 -- the 3-0d operator/debug surface: what it hosts today, and what it would cost to extend

`src/ui/debug/debug_instrument_panel.gd` (`DebugInstrumentPanel`, story 2-6, extended by 3-0b and
3-0d) is the ONE global debug-instrument panel, built in code with no `.tscn`, driven by no
`_process`/`_physics_process`. Its **exact, pinned control set** is four names --
`{NormalizeMagnitude, PitchZoneLeftOfBars, SaveRecord, ReloadBalance}` -- machine-checked by
`test/integration/test_record_save_control.gd`, which enumerates the real controls in a built
panel at runtime. Adding a fifth control means extending that pin, not evading it.

**Geometry constraint, recorded at the E3 gate (decision-log:5016):** "`DebugInstrumentPanel`'s
box is fixed-height with no stated slack for a fifth control." The panel's rect is derived from a
measured empty band (`y[356,450]`, 94px) between the round-over label and the vitals bars, with
zero slack budgeted in either existing column (Switches: two rows; RecordControls: two stacked
buttons, sized to match). A fifth control needs either a new column at the same height budget or a
resize of the empty-band rect, both geometry decisions this file's comments show were made
carefully (`test_debug_instruments.gd`'s layout assertion is the machine check).

**Reaching the runner.** The panel's only two runner-reaching controls (`SaveRecord`,
`ReloadBalance`) are wired via `Callable`s the runner hands in before `add_child` (the
`gamepad_profile`/`huds` precedent, generalised at 3-0d AC 7) -- the panel never holds a state
handle. A debug-only reveal toggle that needs the OPPONENT's hand ids would need a new way to
reach that data, since neither `HudRoot` receives them today (M2/Item 2 above) -- report only, no
decision made here per this story's own Open Questions.

## Story

As the operator running a live smoke or a two-human match,
I want the HUD to tell a permanently exhausted hand slot apart from one whose replacement is still
in flight, and to have a debug-only way to see an opponent's hand contents when I need to verify
card-HUD behaviour,
so that neither a stale 4-0 finding nor an unbuilt E3 toggle keeps riding as HUD debt into E4
feature work.

## Acceptance Criteria

1. **A permanently exhausted slot (4-0 AC 8's "hole") renders visually distinct from a slot with
   a delivery in flight (a cast whose `pending_draw_owed` entry has not yet resolved).** Both
   currently render the same blank caption (`Hand.EMPTY` -> `""`, deferred-work.md's exact words).
   The distinction is presentation-local: `HudRoot` already receives `hand_ids` via
   `connect_cards_changed` (own hand only, per-slot, already private) and needs no new seam to
   determine which of a player's OWN blank slots has an owed delivery pending -- `pending_draw_owed`
   is this player's own field, read the same way `on_cards_changed` already reads this player's own
   `hand_ids`. **Design choice you are free to make (implementation, not design):** the exact visual
   treatment (a distinct placeholder caption, a border/style difference, a countdown) -- pick
   whichever is legible at the half-width viewport scale and cheapest given the existing
   `_own_card_labels`/`_card_base_style` machinery. **Not free:** it must not read or render the
   OPPONENT's hand (that is Item 2, gated separately by AC 2/AC 3), and it must not touch
   `to_snapshot()` or add a `connect_*` seam (M2 already proved neither is needed).
2. **The reveal-opponent-hand toggle exists as a debug-only control, gated behind an explicit
   operator ruling on where it lives** (see Open Question 1 below). Do not build the toggle's UI
   control until that ruling is made -- this AC is satisfied by surfacing the two options with
   their concrete costs (this story's M4 above already does the analysis) and stopping for the
   ruling, not by picking one and building it. If the operator rules before or during the dev pass,
   the dev pass builds the ruled option; if not, this AC is discharged by the ruling being recorded
   and the toggle deferred again, explicitly, with an owner (whichever future story is named).
3. **If AC 2 builds the toggle, it never becomes a public gameplay-affecting reveal.** It is
   debug-only, reachable only through whichever debug surface AC 2's ruling selects, and does not
   change `FeatureFlags` (load-once, runtime-immutable -- 2-6/R4) or any state-layer read/write. It
   must not contradict the GDD lock confirmed at M3 ("hands are private... the pitched card is the
   only public information") for the SHIPPED default configuration -- the toggle is an operator
   instrument, not an authored gameplay option, unless a future story explicitly re-opens that lock.

## Golden Prediction (inverse form -- this is the Tier B escalation clause)

**Prediction: the golden hash and the snapshot key set do NOT move.** Both are measured, not
assumed, per Tier B's "golden clause is decisive" rule (`E4-P/R9`).

- **Golden hash, authoritative source:** `test/state/test_determinism.gd:304`,
  `const GOLDEN := "312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c"`. Recorded
  today, before this story's dev pass, as the BEFORE value.
- **Snapshot key set, authoritative source:** `test/state/test_card_observation.gd:157-167`,
  `test_the_observation_channel_adds_no_snapshot_key`, which pins the sorted key list to exactly
  `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs", "pending_draw",
  "pending_draw_owed", "stamina"]`. Recorded today, before this story's dev pass, as the BEFORE
  set.

**The escalation clause itself, as an AC:** the dev pass runs the full suite (or at minimum
`test_state_matches_golden` and `test_the_observation_channel_adds_no_snapshot_key`) BEFORE
touching any file and AFTER the diff is complete, and records both hash values and both key sets
in the Dev Agent Record. **If either value differs from the BEFORE value recorded here, STOP and
escalate** -- do not re-baseline, do not proceed as Tier B. Per `E4-P/R9`: "Tier is assigned at
authoring and may be RAISED, never lowered, mid-story; a Tier B story found to move the golden
stops and is re-gated as Tier A." This is not a hypothetical for this story: both ACs are scoped
specifically to avoid a state-layer touch (AC 1 reads an already-hashed field presentation-side
only; AC 2/AC 3 are debug-only and either build nothing or build a presentation/debug-surface
control) -- if the measurement disagrees with that design intent, the disagreement itself is the
signal to stop.

## Live Smoke

**One operator check, exercising the hole-vs-in-flight distinction.** Cast a card so its
replacement is delayed (nonzero `draw_replacement_delay_seconds`, the shipped default), observe
the slot mid-flight with AC 1's new treatment; separately, drive a hand to the both-empty
exhaustion degrade (3-5b AC 10 / 4-0 AC 8's permanent hole) and confirm the SAME slot renders
visibly differently from the in-flight case. Record in `docs/playtest-log.md` by the operator's
own hand. If AC 2 built a toggle, exercise it once in the same session (confirm it reveals the
opponent's hand contents on the operator's own debug surface and does not appear or activate for
either player's own gameplay view).

## Open Questions for the operator

1. **Where does the reveal toggle live?** In `HudRoot` (would require exposing the opponent's
   hand ids through a NEW observation channel -- `HudRoot` currently only ever receives its OWN
   slot's `hand_ids`, per-viewport, per M4/Item 2 above -- and would require amending
   `test_runner_observation_seams_are_exactly_eight`'s pinned list and name, the same kind of
   operator-approved amendment `3-6/R2` was), or on the `DebugInstrumentPanel` surface (would
   require the panel to reach into a HudRoot or MatchState it does not currently hold a reference
   to for opponent data, plus the geometry cost at M4 -- but requires NO amendment to the
   `connect_*` seam guard, since the panel's Callable-handoff pattern doesn't need a new signal if
   the runner can hand it a read accessor instead of a push seam).
   RULED 2026-08-08: option A, DebugInstrumentPanel -- see `4-B1/R1`.
2. **Is it debug-only or an authored gameplay option?** M3 found "hands are private, the pitched
   card is the only public information" locked at the GDD level (2-5/R9, epics.md). An authored
   gameplay reveal option would need to either respect that lock (reveal something other than
   contents) or explicitly re-open it -- a design decision, not an implementation one, per
   CLAUDE.md's Agent autonomy test. Default assumption pending the ruling: debug-only, gated behind
   whatever surface (1) selects, never reachable in the shipped default configuration.
   RULED 2026-08-08: debug-only -- see `4-B1/R2`.

## Tasks / Subtasks

- [x] Implement AC 1's hole-vs-in-flight visual distinction in `HudRoot`, reading this player's own
      `pending_draw_owed` alongside the already-received `hand_ids` (AC: 1)
- [x] Extend `test/integration/test_card_hud.gd` (the existing `_vacated_slot_cleared` /
      `_refill_rewrote_the_slot` machinery) to assert the new distinct rendering for the two cases
      (AC: 1)
- [x] Surface the two toggle-placement options and their costs to the operator; record the ruling
      in the Dev Agent Record or decision-log once made (AC: 2)
- [x] If ruled before/during the dev pass: implement the toggle on the ruled surface only, with a
      test proving it never activates in the shipped default configuration (AC: 2, 3)
- [ ] If not ruled: record the re-deferral explicitly, with today's date and this story as the
      prior owner, so the next future story inherits a two-hop chain rather than a dead end (AC: 2)
      — N/A: both Open Questions were RULED before this dev pass (`4-B1/R1`, `4-B1/R2`), so this
      branch is not taken.
- [x] Record BEFORE golden hash + snapshot key set (values already captured in this file); re-run
      after the diff; record AFTER values; escalate per the Golden Prediction clause if either
      moved (AC: Golden Prediction)
- [x] Live Smoke: hole-vs-in-flight distinction, both cases, in `docs/playtest-log.md` — the
      in-flight half and the reveal toggle were smoked live by the operator on 2026-08-08. The
      both-empty half is unreachable by play (measured, see `4-B1/R3`'s correction above) and is
      discharged instead by `test_hole_vs_in_flight_live.gd`, per operator ruling `4-B1/R5`.

### Review Findings

Code review 2026-08-08 (`gds-code-review`, reviewer **Opus 5 (1M context)** / `claude-opus-5[1m]` —
different-LLM pass; implementer was Claude Sonnet 5). Reviewer attribution taken from the PICKER,
not from self-identification, per the operator's standing caution: `~/.claude/settings.json` carries
`"model": "opus[1m]"` and this session's `/model` set "Opus 5 (1M context)". Full suite re-run by the reviewer BEFORE writing this section: `373 tests, 0
failed, 2397 assertions` + all 23 integration files PASS, `ALL TESTS PASSED`. **Golden Prediction
holds** — `test_state_matches_golden` and `test_the_observation_channel_adds_no_snapshot_key` both
green with `test_determinism.gd` and `test_card_observation.gd` untouched, so the golden
(`312522d8...fb3c`) and the snapshot key set are UNMOVED. No Tier A escalation on the golden clause.

**Layer completion:** Blind Hunter COMPLETED, Edge Case Hunter COMPLETED, **Acceptance Auditor
STALLED at the 600 s timeout** — the third consecutive run of this skill with exactly one stalled
layer (3-6: Acceptance Auditor; 4-0: Edge Case Hunter; 4-B1: Acceptance Auditor). Its ground was
covered by hand by the reviewer: seams-still-eight, the GDD privacy lock's reachability, CONSTRAINT
C at the wrapper, the defaulted-4th-parameter back-compat at both 3-arg sites, the widened box's
machine check in both viewports, and the Dev Agent Record evidence audit. Findings from that manual
pass are marked `[manual-auditor]`.

- [x] [Review][Decision] **RULED + FIXED 2026-08-08 (`4-B1/R3`). AC 1 inverts in the exhaustion
      case it exists for: the permanent hole renders as `IN_FLIGHT_CAPTION` forever.** `_deliver_pending_draw` pops the owed slot
      (`match_state.gd:944`) and then `_draw_one_replacement` returns early when deck AND discard
      are both empty (`match_state.gd:973-975`) WITHOUT calling `notify_cards_changed()` — by
      design, "the both-empty degrade returns above without announcing, because it moved no card"
      (`match_state.gd:981`). So `pending_draw_owed` shrinks with no announcement, the HUD is never
      re-run, and the slot keeps the `"..."` caption painted by the cast's own payload. The
      permanent hole and the in-flight slot render IDENTICALLY again — deferred-work.md's exact
      finding, in exactly the scenario this story's own Live Smoke script drives ("drive a hand to
      the both-empty exhaustion degrade... confirm the SAME slot renders visibly differently from
      the in-flight case"). The DEAD path has the same shape (`match_state.gd:945-946`: pop, skip
      the draw, no announce). **Why this is a DECISION and not a patch:** every clean fix announces
      from `src/state/` (add a `notify_cards_changed()` to the both-empty degrade), which is a
      state-layer touch this story's Project Structure Notes name as escalation grounds — "No
      `src/state/` file is expected to change. If the dev pass finds one must, that is itself
      escalation grounds under the Golden Prediction clause." The announce pushes a signal only and
      moves no snapshot key, so the golden would very likely stay put, but the tier call is the
      operator's. The presentation-only alternative (HudRoot inferring exhaustion) needs data
      HudRoot does not have. [src/state/match_state.gd:944-946, 972-982;
      src/ui/hud/hud_root.gd:176] — severity HIGH
- [x] [Review][Decision] **RULED CLOSED 2026-08-08 (`4-B1/R4`): default-off is sufficient today;
      the build gate is deferred with a named owner. "Debug-only by construction" is default-off,
      not gated.**
      `debug_instrument_panel.gd:322` claims "Debug-only by construction (`4-B1/R2`): the only path
      into this method is a manual mouse click", and AC 3 requires it be "never reachable in the
      shipped default configuration". The panel is added UNCONDITIONALLY
      (`match_runner.gd:283, 298`) with no `OS.is_debug_build()` gate, no FeatureFlags gate and no
      export-build branch, so the toggle is mouse-reachable in any build that ships the panel. The
      SaveRecord/ReloadBalance precedent ships the same way — but those are operator ACTIONS, while
      this one leaks the information the GDD lock protects ("hands are private; the pitched card is
      the only public information", M3). Whether that lock demands a build gate, or whether "the
      panel itself is the gate" is sufficient, is a design call, not an implementation one.
      [src/main/match_runner.gd:283-298; src/ui/debug/debug_instrument_panel.gd:322]
      — severity MEDIUM
- [x] [Review][Patch] **The reveal test does not test the reveal: it passes with the opponent's
      half empty.** `_reveal_shows_real_hands` requires only non-blank, `!= "P1  | P2 "`, contains
      "P1"/"P2", and contains a comma. `Hand.to_array()` is the WIDTH view including `EMPTY`
      markers (`hand.gd:104-109`), so the commas come from the JOINER, not from real ids: an
      all-`EMPTY` pair renders `P1 , , ,  | P2 , , , ` and passes every clause. Stronger still,
      gutting `debug_hand_contents` to `[p1.hand.to_array(), []]` — deleting the entire
      opponent-read AC 2/AC 3 exist to deliver — still passes, because P1's commas satisfy the one
      substantive clause. Mutation row M3 only ever proved the assertion against `[[], []]`, the
      weakest adversary, which is why the gap survived. Fix: assert both halves contain at least
      one non-empty id, and assert P2's rendered ids equal the real p2 hand.
      [test/integration/test_debug_instruments.gd:180-186] — severity MEDIUM-HIGH
- [x] [Review][Patch] **The wrapper lambda captures a `RefCounted` `PlayerState` and is stored on
      that same `PlayerState`'s connection list — a reference cycle.** `player_for_slot` is
      captured by strong reference and the lambda is connected to `player.cards_changed`
      (`match_runner.gd:620`): PlayerState -> its connection list -> lambda -> PlayerState. The
      previous bare `hud.on_cards_changed` referenced only a Node, which is not ref-counted, so no
      cycle existed. Expect leaked ObjectDB instances at exit. Fix also makes CONSTRAINT C literally
      true rather than merely asserted — capture nothing and read
      `(_match_state.p1 if slot == 0 else _match_state.p2).pending_draw_owed` inside the lambda
      body (`self` is a Node, so no cycle). NOTE: the reviewer verified the captured reference
      cannot go STALE today — `p1`/`p2` are assigned only in `MatchState._init`
      (`match_state.gd:159-160`) and `_match_state` only at `match_runner.gd:148`, with no
      rebinding path through reset, `apply_balance` or replay. The cycle, not staleness, is the
      defect. [src/main/match_runner.gd:253-255] — severity MEDIUM
- [x] [Review][Patch] **A surviving 3-0b comment now describes a rect the code no longer
      produces.** The retained comment states "New rect: x[276,876], y[356,450] — 2px clear of the
      band edges on both sides"; the shipped rect after `offset_left/right` 300 -> 400 is
      x[176,976]. The new 4-B1 comment directly below compounds it — "no geometry 3-0b's re-fit
      made is disturbed" sits two lines above the code overwriting 3-0b's offsets. The vertical
      claim survives (height untouched); the x claim is now false.
      [src/ui/debug/debug_instrument_panel.gd:117-131] — severity MEDIUM
- [x] [Review][Patch] **The reveal output is a one-shot snapshot with no invalidation.**
      `_reveal_output.text` is written ONLY inside the `toggled` handler; nothing clears or
      refreshes it — not a cast, not a round end, not the debug reset. The operator's realistic use
      (toggle on, keep playing, watch) shows a hand that stopped being true at the first cast, with
      nothing on screen saying so. Cheapest honest fixes: clear on `EventBus.round_started`, or
      label the text as a point-in-time snapshot.
      [src/ui/debug/debug_instrument_panel.gd:324-335] — severity MEDIUM
- [x] [Review][Patch] **The reveal output cannot show holes.** `Hand.EMPTY` maps through `str()` to
      the empty string, so a hand holed at slot 1 prints `P1 fireball, , bramble_snare, ember_ward`
      and a fully holed hand prints `P1 , , , `. The one surface in the build whose stated purpose
      is showing hand CONTENTS reproduces, untreated, the same hole-legibility problem AC 1 fixes on
      the HUD side. Render an explicit marker for `EMPTY`.
      [src/ui/debug/debug_instrument_panel.gd:333-335; src/main/match_runner.gd:459]
      — severity LOW-MEDIUM
- [x] [Review][Patch] **`_panel` is unguarded at `REVEAL_FRAME`.** `_panel` is assigned from
      `get_node_or_null` and the surrounding code already treats it as nullable
      (`_inspectors_exist = ... and panel != null`), but `_check_reveal_toggle` dereferences it with
      no guard — a missing panel crashes the harness instead of printing the FAIL line this file is
      built to print. The guard immediately below covers the wrong nullable.
      [test/integration/test_debug_instruments.gd:173] — severity LOW
- [x] [Review][Patch] **The live `pending_draw_owed` array is handed to the UI by reference, not
      copied.** The sibling accessor in the same diff is explicit about copying
      (`hand.to_array()` -> `_cards.duplicate()`), and 4-0's own code review patched precisely this
      aliasing class ("snapshot `pending_draw_owed` key aliased the live array instead of
      copying"). Consumption is read-only today (`pending_draw_owed.has(i)`), so this is latent —
      but it hands a UI layer a mutable handle into state against this repo's own precedent.
      [src/main/match_runner.gd:255] — severity LOW
- [x] [Review][Patch] `[manual-auditor]` **An unevidenced claim in the Dev Agent Record: "Full
      suite re-run green after every restore."** The mutation table's four rows each name a single
      test run, and nothing in the record evidences four full-suite runs. The RESTORES themselves
      ARE evidenced and were independently verified by this review: all four working-tree files
      SHA256-match their pre-mutation backups in the dev pass's scratchpad
      (`debug_instrument_panel.gd` d79d4638..., `hud_root.gd` 49d62360...,
      `match_runner.gd` 980e1e4d..., `test_record_save_control.gd` 587ba5d3...). Correct the claim
      to what the table can carry. [4-B1-card-hud-debt-discharge.md, Dev Agent Record]
      — severity LOW
- [x] [Review][Patch] `[manual-auditor]` **File List is incomplete and one back-compat claim is
      inaccurate.** `docs/implementation-artifacts/sprint-status.yaml` was modified by the dev pass
      but is absent from the File List. Separately, "the two pre-existing 3-arg call sites (the
      seam's own priming call in `connect_cards_changed`, and one of the two calls in
      `test_card_hud.gd`)" is wrong on both halves: BOTH pre-existing `test_card_hud.gd` calls
      (`:122`, `:140`) are 3-arg, and the priming call now runs through the 4-arg wrapper, not
      `on_cards_changed` directly. The back-compat property itself holds — verified, both sites
      green. [4-B1-card-hud-debt-discharge.md, Dev Agent Record / File List] — severity LOW
- [x] [Review][Defer] **The 800-wide box leaves the window at any width below 800px.**
      `project.godot` has no `[display]` block, so the window is the resizable 1152x648 default with
      no stretch mode, and the layout guard only ever runs at that size. Widths between 600 and 800
      were previously fine and now are not. [src/ui/debug/debug_instrument_panel.gd:130-131]
      — deferred, pre-existing class (the 600-wide box had the same unguarded shape); at the tested
      1152x648 the widening is genuinely clear — x[176,976], y[356,450] vs RoundOverLabel bottom
      y354 and Vitals top y452, machine-checked in BOTH viewports and green.
- [x] [Review][Defer] **`hand_ids` is bound at push time; `pending_draw_owed` is read at drain
      time.** The hand copy is bound into the queued emit (`player_state.gd:137-138`) while the
      wrapper reads the owed list when the queue drains, after the whole tick resolved — so every
      payload is matched against the END-OF-TICK owed set. The intermediate mismatches are
      overwritten within the same drain and are not visible; the one visible instance is the
      Decision item above. [src/state/player_state.gd:137-138; src/main/match_runner.gd:255]
      — deferred, pre-existing shape of the D5 queued-signal channel, not introduced here.

**Dismissed as false positives (3), recorded so the next review does not re-raise them:**
`Hand.EMPTY` might not stringify to `""` — it is `const EMPTY := &""` (`hand.gd:37`), so the
rewritten branch is byte-identical to the old `str(hand_ids[i])` for a sentinel slot. The captured
`player_for_slot` might go stale — no rebinding path exists (see the cycle patch above). Losing
Godot's auto-disconnect-on-free by swapping a bound method for a lambda — no `queue_free`/`free`
path for any HudRoot exists anywhere in the runner, so it is latent only.

**Verified clean by the manual auditor pass:** observation seams still EXACTLY eight (the accessor
is deliberately NOT named `connect_*`, the `recorded_stream()` precedent;
`test_runner_observation_seams_are_exactly_eight` green and untouched); reveal reachable ONLY via
the manual CheckButton (no Input Map action — `project.godot` has no `reveal` entry; no
`FeatureFlags` read anywhere in the reveal path, only comments naming it; no state-layer write;
`HudRoot` never references the accessor); `pending_draw_owed` read INLINE at fire time (CONSTRAINT
C on the value, satisfied); the defaulted 4th parameter back-compatible at both pre-existing 3-arg
sites; the widened box machine-checked inside the band in BOTH viewports; no `src/state/` file in
the diff; `to_snapshot()` untouched.

### Review Fix Pass (2026-08-08, reviewer Opus 5 (1M context), operator-ruled)

Appended, not rewritten: everything above is the review as it stood when the rulings were made.

**`4-B1/R3` — D1 RULED: fix it state-side, inside this story.** Operator's reasoning, recorded
verbatim in substance: `pending_draw_owed` became part of the cards-observable payload in this
story, so a shrink of that debt IS an observable change even when no card moved; the "moved no
card, so no announce" rationale predates this story's contract. A named, measured exception to
"no `src/state/` change", handled under Tier A discipline for this fix alone.

- **The fix.** `player.notify_cards_changed()` added on BOTH silent-pop paths:
  `_deliver_pending_draw`'s DEAD branch (`match_state.gd`, new `else:`) and
  `_draw_one_replacement`'s both-empty degrade (before its early `return`). The superseded comment
  at the third announcement seat was corrected in place rather than left to contradict the code.
- **Golden hash BEFORE:** `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`.
  **AFTER: identical — UNMOVED.** Snapshot key set BEFORE and AFTER identical:
  `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs", "pending_draw",
  "pending_draw_owed", "stamina"]`. Expected, and now measured rather than assumed: the fix pushes
  a SIGNAL and writes no field, so nothing reaches the canonical hash. No re-baseline, no
  escalation.
- **State-level proof, both paths.** `test_card_observation.gd` gains
  `test_the_both_empty_degrade_announces_the_consumed_debt` and
  `test_the_dead_pop_announces_the_consumed_debt` (forced-DEAD idiom, `_round_over` left FALSE).
- **Integration-level proof, crossing the state boundary.** New file
  `test/integration/test_hole_vs_in_flight_live.gd`: real Input Map presses -> KeyboardController
  -> the runner's single `_physics_process` -> `advance()` -> the queued drain -> the eighth seam
  -> the real `HudRoot` caption. Asserts the slot reads `IN_FLIGHT_CAPTION` while the delivery is
  owed and truly blank once the debt is consumed with nothing to draw. This is the test whose
  absence let the bug ship: `test_card_hud.gd` calls `on_cards_changed` directly with a hand-built
  payload, so it could never see a payload that was never sent.
- **Mutation proof (FALLING).** `src/state/match_state.gd` backed up to the scratchpad with
  SHA256 `efc231f14b9756d4...` BEFORE mutating; both announces removed; result: both new state
  tests `[XX]` (`375 tests, 2 failed`) and the integration test `RESULT: FAIL` with
  `hole_after_degrade=false final_caption=... owed=[] hole=true` — the original defect reproduced
  exactly, on the real render path. Restored from the checksummed backup (never `git checkout`);
  restored file SHA256 re-verified identical to the pre-mutation value.

**MEASURED CORRECTION TO THE REVIEW'S OWN SEVERITY CLAIM, reported rather than quietly kept.** The
review called D1 HIGH on the premise that the exhaustion case is player-reachable. It is NOT. Card
count is conserved (deck + discard + occupied hand), and an outstanding debt always has its own
cast card sitting in the discard for the lazy reshuffle to hand straight back — so both piles
cannot be empty while a debt is outstanding. A throwaway probe drove the REAL state machine for
400 ticks across seven deck sizes (1,2,3,4,5,6,8) and three delays (0.0, 0.25, 1.0s), casting
whenever a card was castable, and hit the degrade's precondition **zero times in all 21 runs**. The
DEAD pop beside it is likewise documented unreachable in natural play (`3-5/R6`). So:

- The bug was real as a code property and is now fixed, but **no reachable play sequence rendered
  it**, and AC 1 was already correct for every reachable case (the short-deal permanent hole never
  enters `pending_draw_owed`, so it always rendered truly blank).
- Honest severity is therefore **defense-in-depth for a rendering contract**, not HIGH.
- **This directly affects the Live Smoke script.** Its second half — "drive a hand to the
  both-empty exhaustion degrade (3-5b AC 10 / 4-0 AC 8's permanent hole)" — **cannot be performed**:
  that degrade is unreachable by playing. The reachable permanent hole is the SHORT DEAL
  (`deck_size < hand_size`), which is not the authored configuration either. Recommend the
  operator smoke the IN-FLIGHT half (which is fully reachable on the authored 1.0s delay) and treat
  the permanent-hole half as discharged by `test_hole_vs_in_flight_live.gd` instead. Flagged for
  the operator's call, not resolved here.
- The forced step in the integration test (emptying both piles between cast and delivery, through
  the deliberate `_match_state` exception `test_deck_injection.gd:31` established) exists precisely
  because of this unreachability, and says so in its own header.

**`4-B1/R4` — D2 RULED CLOSED: default-off is sufficient today.** No export build exists for this
same-screen local prototype, so a build gate could not be exercised by any test, and a vacuous
guard is worse than none here (`3-0d/R20`). Recorded in `deferred-work.md` as a named deferral with
an owner: the first story that produces a distributable build — which must gate the WHOLE panel,
since SaveRecord and ReloadBalance ship the same way. The panel comment now states default-off
plainly instead of claiming "by construction".

**All nine patches applied.** Two are worth naming because they changed shape under the operator's
instruction: the reveal test now asserts both halves carry a real id AND that the P2 half equals
the P2 HudRoot's own captions (an independent path — an accessor returning p1 twice or an empty p2
now falls); the lambda captures nothing and resolves `p1`/`p2` inside its body, so CONSTRAINT C
holds of the OBJECT as well as the field and the RefCounted cycle is gone. The staleness patch also
gained a machine check (`round_started` clears the snapshot while the toggle stays pressed) and the
reveal output now prints `SNAP` and a `-` hole marker.

**Corrections to the Dev Agent Record above (patches 8 and 9), stated here rather than by editing
it:** "Full suite re-run green after every restore" is not evidenced by the mutation table and
should read as four single-test runs plus verified restores; the two pre-existing 3-arg call sites
are BOTH in `test_card_hud.gd` (`:122`, `:140`), the priming call having moved to the 4-arg
wrapper; and the dev pass's File List omitted `docs/implementation-artifacts/sprint-status.yaml`.

**Smoke finding (operator, live run, 2026-08-08) — reveal output illegible, patched.** The label
clipped at the box edge: only `SNAP P1 storm_kite, imp_sun...` was visible and the P2 half never
appeared, so one line demonstrably could not carry two hands. Patched in place, no state touched:
the output is now TWO LINES (`SNAP P1: <ids>` / `P2: <ids>`, the ` | ` separator dropped) at an
11px font override so ~55 characters fit the column; the box goes 800 -> 1000 (x[76,1076], still
76px clear on both sides at 1152 wide) with HEIGHT UNTOUCHED for the third time — the band has zero
vertical slack, so the second line is paid for inside the label, not by a taller box; and each
press also `print()`s the same two lines once, giving the operator a copy-pasteable record in the
console that is open during playtests (press-only, never per-frame). The strengthened reveal test
was re-pointed to the new shape (split on the newline, prefixes `SNAP P1: ` / `P2: `) with its
substance unchanged — both halves must carry a real id and the P2 half must equal the P2 HudRoot's
own captions. `test_debug_instruments.gd` re-run alone and PASSES, `panel_layout=true` confirming
the new rect is still clear of every HUD child and StateInspector in BOTH viewports. Full suite not
re-run: nothing here reaches `src/state/`, and the suite ran green at the end of the fix pass.

**Second smoke finding (operator, live run, 2026-08-08) — `4-B1/R7`: the output label is deleted;
the console IS the reveal.** The two-line 11px label clipped the SAME way as the one-line version
(`SNAP P1: storm_kite, imp_summoner, stor` / `P2: hellforge_totem, hellforge_totem, thor`), and the
width it kept demanding had made the mid-screen panel bulky. Two label passes failed identically,
so the ruling changed the MEDIUM rather than the font a third time:

- **The `RevealOutput` Label is gone.** Rationale recorded: it duplicated what both HudRoots
  already render for their own halves, and a label locked inside the 94px band cannot legibly
  carry two hands at any font size that is also readable. Each press already printed the two SNAP
  lines; those are copy-pasteable, and being a LOG rather than a live view they cannot go stale.
- **The toggle stays** as the panel's fifth control — the pinned five-name set in
  `test_record_save_control.gd` is UNCHANGED, so no pin amendment and no new ruling was needed.
  The two lines each press produces are kept in `_last_reveal_lines` (read back via
  `last_reveal_lines()`), so the strengthened test still drives the REAL CheckButton with its full
  substance intact: both halves carry a real id, and the P2 half equals the P2 HudRoot's own
  captions through the independent seam path.
- **The round_started clear machinery is gone** — `clear_reveal_output`, its bus connect in the
  runner, and the staleness check in the test. It existed only because an on-screen label could
  rot into a silent lie across a reset; a console log cannot.
- **The box SHRANK, on a measurement rather than an estimate.** With the label gone the reveal
  column is a bare CheckButton, and the four columns report a combined minimum of **658px** at
  runtime — so the box is 680 (that plus a small margin against font-metric drift), giving
  x[236,916]: narrower than the pre-smoke 800 and the smallest this panel has been since 3-0b.
  Height untouched for the fourth time. Machine-checked in both viewports by the existing layout
  guard, which passes (`panel_layout=true`).
- Panel ergonomics as a whole (size, placement, collapsibility) recorded in `deferred-work.md`,
  owner = the next story that touches the panel.
- `test_debug_instruments.gd` re-run alone: **PASS**. Full suite not re-run — nothing here reaches
  `src/state/`.

**Files added or modified by this fix pass** (beyond the dev pass's own File List):
- `src/state/match_state.gd` — the two announces (the D1 fix, `4-B1/R3`)
- `src/main/match_runner.gd` — lambda-cycle fix + `.duplicate()` + the `round_started` clear wiring
- `src/ui/debug/debug_instrument_panel.gd` — SNAP prefix, hole marker, `clear_reveal_output`,
  corrected geometry and default-off comments
- `test/state/test_card_observation.gd` — the two silent-pop tests
- `test/integration/test_hole_vs_in_flight_live.gd` — NEW, the state-crossing proof
- `test/integration/test_debug_instruments.gd` — strengthened reveal assertions, staleness check,
  `_panel` guard
- `docs/implementation-artifacts/deferred-work.md` — three named deferrals (two from triage, plus
  D2's build gate)

## Dev Notes

- **Read `src/ui/hud/hud_root.gd` before touching it.** `on_cards_changed` (`hud_root.gd:157-160`)
  currently writes every one of the four `_own_card_labels` on every call, unconditionally, from
  `hand_ids` alone -- it has no knowledge of `pending_draw_owed` today. `_make_card_face_style`
  (`hud_root.gd:453`) is the single face-up/face-down seat referenced throughout M3; its `is_own`
  parameter and its face-down branch (currently unreached, since the opponent row was deleted at
  3-6/R1's parent ruling `E3-RG/R4`) both survive untouched by this story unless AC 2 is ruled onto
  `HudRoot`.
- **`PlayerState.pending_draw_owed` is read-only from this story's perspective.** Do not add a new
  seam, do not touch `to_snapshot()`, do not add a `connect_*` method for this data --
  `on_cards_changed`'s existing per-slot `hand_ids` payload already fires every tick a hand changes,
  which is a sufficient trigger to also read `ms.p1.pending_draw_owed` / `ms.p2.pending_draw_owed`
  if the runner hands it over the same way, OR (simpler, and probably preferred) if `HudRoot`
  already has a reference it can poll on the same signal-driven cadence without a new state read
  path. Resolve this as an implementation choice against CONSTRAINT C (read inline, never cache) and
  the "signals over polling" HARD RULE in project-context.md -- whichever shape avoids adding a
  seam.
- **Do not build AC 2/AC 3 speculatively.** If the operator has not ruled on Open Question 1 by
  the time the dev pass reaches this AC, stop and ask -- do not guess a surface. This is exactly the
  DESIGN-vs-implementation line CLAUDE.md's Agent autonomy section draws: which surface hosts a new
  cross-viewport data path is "how the codebase is shaped for future stories," not a HOW-to-satisfy
  question.
- **AC 1 must not accidentally read or leak opponent data.** Keep the two ACs cleanly separable in
  the diff -- AC 1 touches only a player's own already-received fields; AC 2/AC 3 are the only place
  opponent data enters the picture at all.

### Project Structure Notes

- `src/ui/hud/hud_root.gd`: AC 1 change lands here, reading `pending_draw_owed` for the owning
  slot's own hand alongside the existing `hand_ids` read. AC 2/AC 3, if ruled onto `HudRoot`, also
  land here plus a new observation seam in `src/main/match_runner.gd` (would need the
  `test_runner_observation_seams_are_exactly_eight` amendment named in Open Question 1).
- `src/ui/debug/debug_instrument_panel.gd`: AC 2/AC 3, if ruled onto the debug surface instead,
  land here plus a geometry change to the panel's fixed-height box (see M4).
- No `src/state/` file is expected to change. If the dev pass finds one must, that is itself
  escalation grounds under the Golden Prediction clause -- stop and report before proceeding.

### Project Context Rules

- **Signals over polling; direct subscription is the default** -- any new data reaching `HudRoot`
  must ride the existing signal-driven seam shape, never a per-frame poll.
  [Source: project-context.md, "Signals over polling"]
- **CONSTRAINT C: read `ms.balance`/authored values inline, never cache.** Applies by extension to
  reading `pending_draw_owed` -- read fresh each call, never hold a stale reference.
  [Source: project-context.md, "Autoloads (singletons)"]
- **State-layer code never reads `FeatureFlagsService`; only actors/ui/systems may.** Relevant if
  AC 2/AC 3 end up gating on a flag-like switch -- it must be presentation-local or
  controller-local, per 2-6/R4, never a `FeatureFlags` member.
  [Source: project-context.md, "HARD RULE -- Feature flags"; decision-log 2-6/R4]
- **Guard mechanism over guard pattern** -- if AC 2 amends
  `test_runner_observation_seams_are_exactly_eight`, do so as a reviewed, named exception exactly
  like `3-6/R2`'s precedent, not a widened regex.
  [Source: project-context.md, "Guard mechanism over guard pattern"]

### References

- [Source: docs/implementation-artifacts/deferred-work.md -- both quoted entries]
- [Source: decision-log.md Session 2026-08-07 -- E4 ratification, `E4-P/R1`, `E4-P/R9`, `E4-P/R11`]
- [Source: decision-log.md `E3-RG/R4`, `E3-RG/R5`, `3-6/R1`, `3-6/R2` (decision-log:1148-1164,
  5020-5040)]
- [Source: decision-log.md `2-5/R4`, `2-5/R9` (decision-log:767, 777, 785)]
- [Source: src/state/player_state.gd:82, 185; src/ui/hud/hud_root.gd:93-160, 453;
  src/ui/debug/debug_instrument_panel.gd]
- [Source: test/state/test_determinism.gd:304; test/state/test_card_observation.gd:157-167;
  test/state/test_architecture_invariants.gd:284-291; test/integration/test_record_save_control.gd;
  test/integration/test_card_hud.gd]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (dev pass, 2026-08-08).

### Debug Log References

**Golden Prediction BEFORE values, captured at authoring time, for the dev pass to compare
against AFTER:**
- Golden hash: `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`
  (`test/state/test_determinism.gd:304`)
- Snapshot key set: `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
  "pending_draw", "pending_draw_owed", "stamina"]` (`test/state/test_card_observation.gd:161-164`)

**AFTER values, measured post-diff (`bash test/run_all.sh`, full suite):**
- Golden hash: `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c` — **UNMOVED**
  (`test/state/test_determinism.gd:304`, byte-identical to BEFORE — this file was not touched).
- Snapshot key set: `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
  "pending_draw", "pending_draw_owed", "stamina"]` — **UNMOVED** (`test/state/test_card_observation.gd`
  was not touched either).
- State harness: `373 tests, 0 failed, 2397 assertions` both before and after this dev pass's
  diff — the same count as 4-0's close-out, confirming zero net change to `src/state/` (`git status
  --short` shows no `src/state/` file touched by this dev pass).
- **No escalation triggered.** Per the Golden Prediction clause, Tier B stands.

**Mutation/verification table** (each row: back up the target to the scratchpad with a SHA256
checksum, apply the mutation, run the relevant test, confirm FALLING, restore from the checksummed
backup, confirm the restored file's SHA256 matches the original — never `git checkout`, per repo
practice):

| # | Target | Mutation | Test run | Result |
|---|--------|----------|----------|--------|
| M1 | `src/ui/hud/hud_root.gd::on_cards_changed` | disabled the in-flight branch (`elif false and pending_draw_owed.has(i)`) | `test/integration/test_card_hud.gd` | FALLING — `in_flight_distinct=false` (in-flight slot rendered blank, indistinguishable from the permanent hole, reproducing 4-0 AC 8's exact finding) |
| M2 | `src/ui/hud/hud_root.gd::on_cards_changed` | broke the real-id branch (blanked `_own_card_labels[i].text` instead of `str(hand_ids[i])`) | `test/integration/test_card_hud.gd` | FALLING — `captions=false hands_differ=false` (proves the pre-existing 3-6 caption-population assertion still exercises this line) |
| M3 | `src/main/match_runner.gd::debug_hand_contents` | returned `[[], []]` instead of the live hands | `test/integration/test_debug_instruments.gd` | FALLING — `reveal_shows_hands=false` (proves the reveal-toggle assertion is non-vacuous against the read accessor, not just the format string) |
| M4 | `test/integration/test_record_save_control.gd::_check_control_set` | reverted the pinned control-set list to the pre-4-B1 four names | `test/integration/test_record_save_control.gd` | FALLING — got `[..., "RevealOpponentHand", ...]` against the old 4-name expectation (proves `RevealOpponentHand` is a real, correctly-named, instantiated `BaseButton`, not a name typo the pin would have missed) |

All four restores verified by SHA256 match against the pre-mutation backup
(`C:\Users\matko\AppData\Local\Temp\claude\...\scratchpad\mutation_backup\`). Full suite re-run
green after every restore; final full-suite state: `373/2397` state assertions, all 22 integration
files PASS.

### Completion Notes List

**AC 1 (hole-vs-in-flight distinction) — IMPLEMENTED.** `HudRoot.on_cards_changed` gained a fourth,
defaulted parameter `pending_draw_owed: Array = []`; a blank slot whose index appears in it renders
`HudRoot.IN_FLIGHT_CAPTION` ("..."), a blank slot that does not renders truly blank (the permanent
hole, unchanged). The value is read INLINE at `match_runner.gd`'s existing eighth-seam wiring site
(`connect_cards_changed`'s callback is now a thin wrapper reading `player_for_slot.pending_draw_owed`
fresh each call, CONSTRAINT C) — no new signal, no new seam, no `src/state/` change, matching the
Dev Notes' "read the same way `on_cards_changed` already reads `hand_ids`" instruction. The default
parameter value keeps the two pre-existing 3-arg call sites (the seam's own priming call in
`connect_cards_changed`, and one of the two calls in `test_card_hud.gd`) exercising the
permanent-hole branch unchanged.

`src/ui/hud/hud_root.gd:157-256` (the Dev Notes' Read-First target) was read before touching it, per
the operator constraint: `on_cards_changed` had no knowledge of `pending_draw_owed` and HudRoot
holds no state handle (2-4/R7, confirmed by re-reading the class header), so the Dev Notes'
"simpler, probably preferred" option premised on "if `HudRoot` already has a reference" does NOT
apply — its premise is false. The implementation taken is the OTHER Dev Notes option: the runner
hands the value over the same way, alongside the seam's existing three values.

**AC 2/AC 3 (reveal toggle) — BOTH OPEN QUESTIONS WERE ALREADY RULED** (`4-B1/R1`: DebugInstrumentPanel,
a read-accessor Callable, no new observation seam; `4-B1/R2`: debug-only) before this dev pass began,
so the toggle was BUILT, not deferred again. `DebugInstrumentPanel` gained its FIFTH control,
`RevealOpponentHand` (a `CheckButton`, unpressed by default) plus a read-only output `Label`, in a
new fourth column (`RevealColumn`) — a geometry decision made per the story's "implementation choice
for the dev pass" clause: the band has zero VERTICAL slack (2px clear on both edges since 3-0b's
re-fit), so a fifth control can only grow the box WIDER (600 -> 800, still fully inside the
1152-wide window), never taller. The runner hands the panel a THIRD runner-reaching Callable,
`reveal_opponent_hand = debug_hand_contents` (on the `save_record`/`reload_balance` precedent,
generalised from an action to a read); `debug_hand_contents()` returns `[p1.hand.to_array(),
p2.hand.to_array()]`, read fresh at call time. The toggle's own `toggled` handler calls the accessor
ON PRESS ONLY (never per-frame, F1 intact) and blanks the output on release. `FeatureFlagsService`
is never read by this control; no state-layer write anywhere in the diff; the toggle is unreachable
except by a manual mouse click, matching `4-B1/R2`.

The four-control pin in `test/integration/test_record_save_control.gd` was amended to five names, a
reviewed named exception per `4-B1/R1`'s own citation of the `3-6/R2` precedent —
`test_runner_observation_seams_are_exactly_eight` was NOT touched (confirmed: still exactly 8
`connect_*` functions in `match_runner.gd`, grep-verified).

**Golden Prediction — CONFIRMED UNMOVED**, both values, measured (see Debug Log References above).
Zero `src/state/` files in this dev pass's diff. Tier B stands; no escalation.

**Live Smoke — NOT PERFORMED by this dev pass.** `docs/playtest-log.md`'s own file header
(line 4, verbatim) reads "Ne daj nijednom agentu da ovo pise umjesto tebe" — do not let any agent
write this instead of you. This is a hard, repo-level rule that overrides the generic
`gds-dev-story` skill's Step 9 gate ("HALT — Complete remaining tasks before marking ready for
review" on any incomplete task): writing a fabricated Live Smoke entry to satisfy that gate would
violate a more specific, explicit repo rule. The Live Smoke task/subtask is therefore left
unchecked, and this is a DEVIATION from the skill's literal flow, reported rather than silently
reconciled, per this run's operator constraint. Precedent for this exact split (dev pass reaches
"review" with Live Smoke outstanding, performed by the operator afterward) exists in nearly every
prior close-out note in `sprint-status.yaml`'s `story_notes` (3-6, 4-0, 3-0a, 3-4, all record Live
Smoke as a separate operator-performed step, sometimes on a later date). Status is set to `review`
("implemented, awaiting review" per `CFG/R5`) rather than left at `ready-for-dev`, since every AC's
code and its own test coverage ARE complete — only the operator's own hands-on smoke session and
its log entry remain, both explicitly reserved to Matko by this repo's own file.

### File List

- `src/ui/hud/hud_root.gd` — modified (AC 1: `on_cards_changed` gains the `pending_draw_owed`
  parameter and the in-flight/permanent-hole branch; `IN_FLIGHT_CAPTION` constant added)
- `src/main/match_runner.gd` — modified (AC 1: the eighth-seam wiring wraps `hud.on_cards_changed`
  to forward `pending_draw_owed` inline; AC 2/AC 3: `debug_hand_contents()` accessor added and
  handed to the panel as `reveal_opponent_hand`)
- `src/ui/debug/debug_instrument_panel.gd` — modified (AC 2/AC 3: `reveal_opponent_hand` Callable
  member, `_reveal_output` Label, `_build_reveal_control`, `_on_reveal_toggled`; box widened
  600 -> 800 for the fourth column)
- `test/integration/test_card_hud.gd` — modified (AC 1: new in-flight-vs-permanent-hole assertion
  alongside the existing vacated-slot assertion)
- `test/integration/test_debug_instruments.gd` — modified (AC 2/AC 3: reveal-toggle default-off,
  real-hands-on-press, blank-on-release assertions)
- `test/integration/test_record_save_control.gd` — modified (AC 2: the pinned control-set list
  amended to five names, per `4-B1/R1`)

## Change Log

- 2026-08-08 — Dev pass (Claude Sonnet 5): AC 1 and AC 2/AC 3 implemented per rulings `4-B1/R1` and
  `4-B1/R2`; golden and snapshot key set measured UNMOVED (Tier B confirmed, no escalation); Live
  Smoke left to the operator's own hand per `docs/playtest-log.md`'s own file rule; Status ->
  `review`.
