---
baseline_commit: b73eea9eb04bb2063e84997424ef28b2a6832ca5
---

# Story 4.B1: Card HUD debt discharge

Status: ready-for-dev

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

- [ ] Implement AC 1's hole-vs-in-flight visual distinction in `HudRoot`, reading this player's own
      `pending_draw_owed` alongside the already-received `hand_ids` (AC: 1)
- [ ] Extend `test/integration/test_card_hud.gd` (the existing `_vacated_slot_cleared` /
      `_refill_rewrote_the_slot` machinery) to assert the new distinct rendering for the two cases
      (AC: 1)
- [ ] Surface the two toggle-placement options and their costs to the operator; record the ruling
      in the Dev Agent Record or decision-log once made (AC: 2)
- [ ] If ruled before/during the dev pass: implement the toggle on the ruled surface only, with a
      test proving it never activates in the shipped default configuration (AC: 2, 3)
- [ ] If not ruled: record the re-deferral explicitly, with today's date and this story as the
      prior owner, so the next future story inherits a two-hop chain rather than a dead end (AC: 2)
- [ ] Record BEFORE golden hash + snapshot key set (values already captured in this file); re-run
      after the diff; record AFTER values; escalate per the Golden Prediction clause if either
      moved (AC: Golden Prediction)
- [ ] Live Smoke: hole-vs-in-flight distinction, both cases, in `docs/playtest-log.md`

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

(filled by the dev pass)

### Debug Log References

**Golden Prediction BEFORE values, captured at authoring time (this run), for the dev pass to
compare against AFTER:**
- Golden hash: `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`
  (`test/state/test_determinism.gd:304`)
- Snapshot key set: `["deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
  "pending_draw", "pending_draw_owed", "stamina"]` (`test/state/test_card_observation.gd:161-164`)

### Completion Notes List

### File List
