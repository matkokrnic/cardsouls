---
baseline_commit: 0c56196e7b39c994f1dc7f8ae2cc865f10da4cf2
---

# Story 5.3: Telegraph presentation

Status: ready-for-dev

## What this story inherits

`E5-P/R5` (`decision-log.md:8195-8196`) slots this as the EIGHTH of twelve E5 stories, **Tier B**:
"consumes the state-owned telegraph fact `5-2` produces; carries S5's unhomed audio half and the
S8 attack/block-sting discrimination finding." `sprint-status.yaml:104` carries the same key,
`5-3-telegraph-presentation`, status `backlog`.

`5-2-unblockable-initiation` (done, `dc2c9ffa`) published the fact this story consumes.
`PlayerState.to_snapshot()` (`src/state/player_state.gd:478-480`) carries:

```gdscript
"telegraph": [charge_color, charge_window.remaining_ticks()] \
        if hero.action_state == HeroState.ActionState.CHARGING \
        else [NO_TELEGRAPH_COLOR, 0],
```

Verified by content, not by this story's own paraphrase: the key is named `telegraph`, it is a
two-element `Array` (`[colour, remaining_ticks]`, ticks not seconds), it is gated on
`action_state == CHARGING` (so a stale telegraph is unrepresentable — no flag to forget to clear),
and its resting value is `[-1, 0]` (`NO_TELEGRAPH_COLOR`, `player_state.gd:190`). `charge_color` is
a plain `Enums.CardColor` int (`RED, BLUE, GREEN`, `src/state/enums.gd:9`), never a name and never
a `TelegraphProfile` (`player_state.gd:183-184`, `1-10/R1` intact). **Correction against this
story's own drafting brief:** the "28 → 29" key-set figure is *narrative* documentation in
`5-2-unblockable-initiation.md` (its own measured Golden Prediction, AC 22), not an executable
key-count assertion — no test anywhere asserts `to_snapshot().keys().size() == 29`. The set is
protected by the golden HASH (`test/state/test_determinism.gd`), and this story's own Golden
Prediction below is measured the same way, not against a key-count check that does not exist.

Nothing today reads the `telegraph` key. This story is its first presentation-side consumer.

## Operator rulings (the contract)

1. **The `ActionState -> TelegraphProfile` mapping stays controller-owned (`1-10/R1`, locked,
   `decision-log.md:466`).** `src/state/` gains no edit in this story. The existing
   `TelegraphController` (`src/actors/hero/telegraph_controller.gd`) already keys its
   `_profiles` dictionary by `HeroState.ActionState`; `CHARGING` is not in it today
   (`animation_controller.gd:18` names `CHARGING` an "E5 reservation," currently unmapped by
   design). This story adds a `CHARGING`-aware seat, keyed additionally by `charge_color`, without
   ever letting a state object learn the word `TelegraphProfile`.
2. **Colour selects the clip and cue; it does not touch damage, reach, or timing.** `5-2` Ruling 2
   already fixed this for state; this story is the presentation half of the same rule.
3. **The 1.0 s chargeup is authored, not clip-dictated.** `unblockable_chargeup_seconds` (currently
   `1.0`, `data/balance/balance_config.tres`) is the gameplay timing 5-2 ships; the three new clips
   are scaled to fit it (`AnimationPlayer.play(name, ..., custom_speed)` or an authored
   `speed_scale`, dev's call), never the other way around. A clip is not permitted to make the
   charge window feel longer or shorter than the state-owned duration it is presenting.
4. **Net Hips travel during `CHARGING` is a defect class, not a style note.** The hero is
   hard-rooted for the whole window (`5-2` Ruling 3 / AC 11); a clip with nonzero net XZ Hips
   displacement would walk the model off its own collision box while the box itself does not move
   — the same class of fault `roll`'s pre-fix planar excursion was (`3-0b/R27`, below).
5. **The assembly tool for these three clips is NEW, not a reuse of `add_paladin_locomotion.gd`.**
   See Dev Notes — the existing tool's `NEW_CLIPS`/`EXISTING_CLIPS` constants are hardcoded to
   5-0a's three locomotion clips; this story authors its own script against the identical EXTEND
   pattern.

## Story

As the operator implementing the RGB read exchange's telegraph half,
I want the state-owned `telegraph` fact from `5-2` to drive a colour-specific attack pose and an
audible cue during `CHARGING`, and a temporary keyboard key to actually trigger mode ② so the
telegraph can be seen and judged at all,
so that `5-3` closes the presentation gap `5-2` deliberately left open, the RGB read exchange has a
real shape+sound cue to react to, and this story's own live smoke can be a genuine playtest rather
than another regression smoke.

## Acceptance Criteria

**Clip assembly (new tool, extends `paladin_anims.res`)**

1. A new headless tool script (naming is dev's call — `tools/add_paladin_attacks.gd` follows the
   `add_paladin_locomotion.gd` naming precedent) loads the EXISTING
   `assets/characters/paladin/paladin_anims.res`, asserts all NINE current clips are present
   (`idle, run, attack, block, roll, death, strafe_left, strafe_right, backpedal` —
   `test/integration/test_rig_clips.gd`'s own list), adds `swipe`, `jump_attack`, `thrust` from
   their already-on-disk `.fbx` sources, and saves the library back. It never rebuilds the resource
   from the six/nine source FBXs (that would silently revert `3-0b`'s retimes and the `roll` planar
   fix — `add_paladin_locomotion.gd:8-14`'s own stated reason, inherited verbatim).
2. All three new clips are non-looping (`Animation.LOOP_NONE`) — they are one-shot attack poses,
   matching `attack`'s existing loop flag, not a locomotion loop.
3. `test/integration/test_rig_clips.gd` is extended from nine to twelve clips (`EXPECTED_LOOP`
   gains the three new entries, loop `false` each), following the exact six-to-nine precedent
   `5-0a` already set on this same file.
4. **Editor/asset discipline (this story's dev pass, not this create pass):** the three `.fbx`
   files import through the editor first (`3-0a/R3` — editor authorized for import, not mandated
   for assembly); the headless tool then runs against the imported clips. This create pass does
   not open the editor and does not import anything.

**Measurement (owed by this story, not judgment-free)**

5. `tools/measure_hips_displacement.gd` (unmodified — it iterates whatever is in the library, no
   clip list to edit) is run before AND after clip assembly; the `swipe` / `jump_attack` / `thrust`
   rows are recorded verbatim in Dev Notes (net XZ, net Y, peak, peak-planar, `net_zero` YES/NO).
6. **Conditional ruling, already made:** for any of the three clips whose net XZ displacement
   exceeds the tool's own `NET_ZERO_EPS` (`0.001`), the assembly tool zeroes the Hips position
   track's X and Z key values while KEEPING every Y value untouched (the jump arc must survive;
   `Y` was never part of `HeroState.velocity` — planar-only, `_resolve_movement`). This is the SAME
   principle as the `roll` fix, correctly cited: `3-0b/R27` (`decision-log.md:1739-1748`) zeroed
   `roll`'s Hips X/Z keys while keeping Y, reducing its planar excursion from `1.0895` to
   `0.0000`; `3-0a/R14` (`decision-log.md:1001`) is where that option was first named. **Correction
   against this story's drafting brief: this precedent is `roll`'s, under `3-0b/R27`, not `run`'s.**
   `run`'s near-zero net displacement (~0.00005, per `measure_hips_displacement.gd` data) was cited
   there only as an analogy ("the legs cycle in place"), not as a clip anyone edited a track on.
   Mid-clip excursion (peak / peak-planar) is explicitly NOT a defect per the tool's own doctrine
   (`measure_hips_displacement.gd:14-18`) — only NET travel triggers AC 6.
7. `jump_attack` is the one clip flagged at risk in this story's brief (Mixamo "Standing Melee Run
   Jump Attack" offered no In Place option) — measure it first and do not assume; if it net-zeros
   on its own, AC 6 does not fire for it and that must be stated as a measured finding, not
   silently skipped.

**Clip/cue selection (controller-owned, `1-10/R1`)**

8. `AnimationController` (`src/actors/hero/animation_controller.gd`) gains a `CHARGING` seat.
   Unlike its existing `_CLIP` dictionary (one `ActionState` -> one clip name), `CHARGING` maps to
   ONE OF THREE clips depending on `charge_color` — this needs a second, colour-keyed lookup (dev's
   call on shape: a `Dictionary[int, StringName]` beside `_CLIP`, or widen `_CLIP`'s value type;
   either satisfies `1-10/R1` as long as no state object is consulted for the mapping). The
   colour -> clip assignment itself (which of RED/BLUE/GREEN gets swipe/jump_attack/thrust) is a
   presentation choice, not a design one — name it in Completion Notes.
9. The clip is read where the controller already reads state-derived facts today: this needs a new
   read path, since `AnimationController` is currently driven ONLY by the
   `connect_hero_action_state_changed` seam (an edge, fired once per transition) and by
   `on_locomotion()` (a per-tick push, but IDLE-only). `CHARGING`'s clip choice needs the COLOUR,
   which is not on the `ActionState` transition signal's payload — dev's call whether the seam
   callback additionally reads `to_snapshot()`'s `telegraph` key at the transition instant (colour
   is fixed for the whole window, so a one-time read at entry suffices; no per-tick poll is
   required for clip selection). Name the chosen read path explicitly in Completion Notes.
10. `TelegraphController` (`src/actors/hero/telegraph_controller.gd`) gains an analogous
    colour-keyed telegraph-shape/sting entry for `CHARGING`, following its existing
    `_profiles` / `_shapes` / `_stings` pattern (new `TelegraphProfile` `.tres` instances per
    colour, new `Shapes/<shape_id>` mesh children, new `AudioStreamPlayer` sting children on the
    existing `CombatCues` bus — `hero.tscn`'s `StingAttack`/`StingBlock`/`StingRoll` are the
    exact precedent for the new stings). `TelegraphController.on_action_state_changed` is the
    natural seat, extended the same way as AC 9 to also resolve colour.
11. The `remaining_ticks` half of the fact is NOT required to drive anything visual in this story —
    a colour-locked shape+sound cue for the whole window satisfies GDD's "shape + sound, <0.5 s"
    requirement (`epics.md:148`) without a countdown readout. If a dev pass finds a cheap use for
    the tick count (e.g. a shrinking ring), that is a bonus, not an AC.

**Runtime dispatch pin (the suite's own blind spot)**

21. **A headless integration test pins the colour -> clip / colour -> cue dispatch AC 8/AC 10 add,
    analogous to `test_totem_tint_live.gd` (`5-0c`).** `3-0b/R34` (`decision-log.md:1834-1851`,
    confirmed by content) names the blind spot verbatim: "the suite asserts authored data AT REST
    and never runtime COMPOSITION… any future presentation seam with a runtime SELECTION or
    PLACEMENT decision needs its own test asking 'what actually happened at runtime.'"
    `test_totem_tint_live.gd` is the fresh, close precedent: it injects three kinds directly onto
    the board (`UnitBoard.add`) and measures that dispatch produced three distinct tint results,
    built specifically because that dispatch layer was otherwise smoke-only. This story's
    dispatch is the same shape: driving all three `charge_color` values through the real
    `CHARGING` dispatch must resolve to THREE DISTINCT clip names (AC 8) and THREE DISTINCT
    telegraph shape/sting resolutions (AC 10) — two colours collapsing to the same clip, or the
    same shape/sting, is a failure, not a pass, and so is a run where the dispatch path is never
    actually invoked (a vacuous "did nothing" pass is not acceptable). Non-vacuous per this
    story's own discipline: the dev pass owes a mutation (collapse two colours, or disconnect the
    seam) that turns this test RED before it is accepted GREEN. File name and injection mechanism
    (direct `PlayerState`/`HeroState` field pokes vs. driving a real chargeup through
    `MatchState`) are the dev pass's call, not specified here.

**S5 — the audio obligation (verify before writing SFX assets)**

12. **S5, verbatim, is a general "no cast feedback" finding, NOT a telegraph-specific one.**
    Original source, `docs/playtest-log.md:139-141` (2026-08-04, `3-5a` smoke, mode ① only):
    "there is no feedback on a cast at all. No sound, nothing on screen, for either a successful
    cast or a rejection. I noticed the silence before I noticed anything else." Restated in
    `decision-log.md:3196-3199`. `E4-P/R11` (`decision-log.md:5784-5785`) records that `4-1`
    partially discharges it "by construction" (a summon puts a visible unit on the board) while
    "the audio half stays unhomed." `E5-P/R5` (`decision-log.md:8195-8196`) explicitly homes that
    unhomed audio half at THIS story.
13. **Resolved (was the first Open Question below — operator ruling, taken as decided, not
    deferred): a successful cast gets an audible cue in BOTH modes, BASIC and UNBLOCKABLE, not
    the mode ② cast alone.** The draft's original narrow reading — discharging S5's success-audio
    half only for mode ②, the one cast type this story delivers — is wrong: AC 12 already
    establishes S5 (`playtest-log.md:139-141`) as a general "no cast feedback" finding, observed
    against mode ①, the only mode that existed when it was filed. Wiring sound to mode ② alone
    would mark the debt discharged while the exact silence the operator reported — a mode ①
    cast — still stood. This cue is distinct from the ongoing `CHARGING` sting AC 10 already adds:
    it is a one-shot cue at CAST RESOLUTION, fired from both `_resolve_basic_cast`'s and
    `_resolve_unblockable_cast`'s success paths (`match_state.gd:2264-2369`, `:2452-2508`), not a
    per-tick charging cue.
    **The rejection half of S5 ("nothing for a rejection either") needs no new work in this story
    — measured, not assumed.** A card-cast refusal (`CastEvaluator.REASON_EMPTY_SLOT` and its
    siblings, `5-0b/R1` lineage) already rides `HeroState.reject_action(&"card_cast", ...)` on
    BOTH cast paths (`match_state.gd:2282`, `:2462`, `:2466`, `:2469`, `:2478`) — the same queued
    `action_rejected` signal the stamina-gated roll/attack rejections already use
    (`match_state.gd:2254-2258`'s own `3-5a` AC 7 note: "REJECTIONS RIDE THE SHIPPED SEAM"). That
    signal is already connected, for every hero, to `TelegraphController.on_action_rejected`
    (`match_runner.gd:451`), which already plays `_cue_reject` unconditionally on ANY rejected
    action (`telegraph_controller.gd:83-87`) — wiring that predates this story (`1-10`, reused by
    `3-5a`). A card-cast rejection in either mode is therefore ALREADY audible today, by
    construction, with zero code this story needs to add. This is not the "signal exists, no
    listener" case — the listener already exists and already fires; there is no new observation
    seam to add and no residue to carry forward. With the widened success cue above, **S5 (AC 12,
    both halves) is FULLY discharged by this story** — not partially, and not by this story's
    audio code alone for the rejection half, which was already live before this story began.
14. **S8 is not reopened; it is extended.** The ORIGINAL S8 (`2-6/R19`, `decision-log.md:859`:
    attack and block stings read too similar by ear) was already closed by `3-0b` AC 9/AC 11
    (`3-0b-feel-and-timing-tuning.md:21,23` — attack/block stings made audibly distinct, verified
    by a naive-observer audio-discrimination pass). `E5-P/R5`'s citation of S8 for `5-3` means: run
    the SAME discipline (a sound alone must identify which of the three new colours is charging)
    against the THREE NEW telegraph stings this story adds — that is Live Smoke watch item (c)
    below, not a re-litigation of attack-vs-block.

**Keyboard input edge for mode ② (TEMPORARY, provisional)**

15. **`5-2/R15` is the reason this AC exists** (`decision-log.md:8708-8719`, confirmed by content
    scan, not memory): every write to `InputIntent.card_mode` anywhere in `src/` hardcodes
    `Enums.ModeKind.BASIC` — exactly two sites, `src/controllers/gamepad_controller.gd:172` (`5-7`'s,
    untouched here) and `src/controllers/keyboard_controller.gd:113` (unowned until now). Without a
    producer, `CHARGING` is unreachable and this story's own telegraph cannot be smoke-tested.
16. **Resolved (was the third Open Question below — operator ruling): the new key is an ALTERNATE
    CONFIRM on the EXISTING arm-then-confirm sequence, not a separate one-key cast path.**
    `_sample_card_scheme()` (`keyboard_controller.gd:104-117`) already runs: HOLD `p1_cast_mode` to
    enter cast mode, PRESS a `p1_card_N` to arm that hand slot, PRESS `p1_cast_confirm` to commit
    the armed slot, RELEASE `p1_cast_mode` to exit instantly and disarm. A key that "just cast a
    card" in mode ② would still have to pick a slot implicitly, since the telegraph colour comes
    from the CARD being played (`charge_color` is the spent card's colour — Dev Notes below) and a
    slot must be armed before any mode can be chosen, regardless of which key confirms it. So the
    new action is a SECOND confirm key, read in `_sample_card_scheme()` alongside the existing
    `_cast_confirm` read, sitting on the same armed slot. Mechanism: a new Input Map action
    (naming follows the `pX_...` convention already established — `p1_cast_unblockable` or
    similar, dev's call). Exact key binding is dev's call; `project.godot`'s current p1 bindings
    occupy W/A/S/D (move), J/K/L (attack/block/roll), Q (`cast_mode` modifier), 1-4 (card slots), E
    (`cast_confirm`), R (`debug_reset`) — the new key must not collide with any of these.
17. **No new `InputIntent` field.** `card_slot`, `card_mode`, `card_commit` already exist
    (`src/state/input/input_intent.gd:60-64`, delivered `5-0b`) and `Enums.ModeKind.UNBLOCKABLE`
    is already a live, dispatched value (`match_state.gd:2238-2239`, since `5-2`).
    **Resolved (was the third Open Question below): the new key does not require a separate hold
    and does not skip arming — pressing it, with a slot already armed via a `p1_card_N` press
    exactly as today, sets `intent.card_mode = Enums.ModeKind.UNBLOCKABLE` and
    `intent.card_commit = true` on that same press, IN PLACE OF pressing `p1_cast_confirm`** (which
    still commits the armed slot as BASIC, unchanged). The existing arm-then-confirm sequence's
    shape is unchanged; only which of the two confirm keys was pressed decides the mode. Name this
    shape in Completion Notes.
18. **Gamepad is untouched.** `gamepad_controller.gd:172`'s hardcoded `BASIC` stays exactly as is —
    the full held-L3 scheme is `5-7`'s.
19. **State the provisional nature in plain text, here:** this keyboard key is TEMPORARY. `5-7`
    replaces it with the full held-L3 gamepad-and-keyboard scheme design already sketched in
    `3-5a` Dev Notes / `E5-P/R5` item 2 (`5-0b-pad-card-input`). This story's key exists only so a
    human eye can judge the telegraph; it is not the shipped input scheme and carries no such
    claim. **Consequence of AC 16/17's resolved shape:** because the new key is an alternate
    confirm on the existing sequence rather than a second cast path, `5-7`'s replacement is the
    deletion of one Input Map action and one branch in `_sample_card_scheme()`, not the removal of
    a parallel input path — the arm-then-confirm sequence itself survives into `5-7` unchanged.
20. **`DEFENSE` and `PITCH` stay untouched, verified stubs.** `match_state.gd:2231-2243`'s `_` arm
    still calls `Invariant.check(false, ...)` for both — confirmed this crashes/asserts by design
    (`Invariant.check` is `push_error` + `assert`). Nothing in this story writes either mode.

## Non-Goals

- **Per-colour damage, three-tier ladder** (`5-6`) — this story adds no damage variance by colour.
- **Mode ③, defensive response** (`5-5`) — DEFENSE stays an unreachable stub (AC 20).
- **Gamepad mode buttons, the full held-L3 scheme** (`5-7`) — AC 18 keeps the pad untouched; AC 16's
  keyboard key is explicitly provisional (AC 19).
- **Retuning chargeup duration, reach, or the 8 m landing** — Ruling 3 pins the window as authored;
  no `balance_config.tres` field this story touches is a gameplay-tuning number.
- **`src/state/` changes beyond the keyboard edge's own controller-side write.** No new field is
  added to `InputIntent` (AC 17); the only touched file outside `src/actors/`/`src/controllers/`/
  `tools/`/`test/` is `project.godot` (one new Input Map action) — named explicitly so its diff is
  reviewed as intentional per `CLAUDE.md`'s "keep `project.godot` edits intentional" rule.
- **Adding a NEW rejection cue or a new observation seam for S5's rejection half.** AC 13 measures
  that a card-cast refusal in either mode is already audible today via the existing, pre-dating
  `action_rejected` -> `TelegraphController.on_action_rejected` -> `_cue_reject` wiring (`1-10`,
  `3-5a`) — this story adds no code for that half and widens no seam to get it.
- **A countdown/tick-based visual for `remaining_ticks`** (AC 11) — a static colour-locked cue for
  the window's duration is sufficient.

## Golden Prediction (measured, not asserted)

**Prediction: the golden and the snapshot key set stay UNMOVED.** This story is presentation
(`src/actors/`, `src/controllers/`) plus one Input Map action and one tool script; it reads the
`telegraph` key `5-2` already published and writes nothing new to `to_snapshot()`. The one
`src/state/`-adjacent touch is `KeyboardController` writing an existing `InputIntent` field
(`card_mode`) with an existing enum value (`UNBLOCKABLE`) it did not write before — `InputIntent`
is explicitly excluded from the determinism contract (`input_intent.gd:12-13`: "captured separately
in the X5 intent stream and is deliberately excluded from the `to_snapshot()` contract"), so this
cannot move the hash by construction, only by CONSEQUENCE (a mode ② cast now actually reachable by
a human at the keyboard, landing in the recorded intent stream, not the snapshot schema).

**What would falsify this:** if the golden's own fixture-driven session (headless, replayed
programmatically, never touching the new keyboard key) begins casting mode ② where it did not
before — it cannot, since the fixture drives `InputIntent` directly rather than through
`KeyboardController.sample()`, and this story adds no new state-layer branch for `_resolve_card_action`
to take. If it DOES move for any other reason, that is a finding, not a pass — measure
`bash test/run_all.sh` before and after per the project's own discipline (`E4-P/R9`).

## Live Smoke

This is this story's OWN gate — `5-2`'s live smoke was, by `5-2/R15`'s own admission, a regression
smoke that could not exercise mode ② at all (no producer existed). This story's keyboard edge
(AC 16) makes THIS the first real playtest of the chargeup and its telegraph. Named watch items:

(a) **Does `swipe` read as visually DIFFERENT from the existing `attack` clip?** Both are
    sword-and-shield swings on the same rig — if they look alike at a glance, the telegraph fails
    at its own job (the GDD's own "shape + sound" requirement, `epics.md:148`, needs a shape
    distinct enough to register as "not the ordinary swing").
(b) **Is `thrust` visually acceptable?** The operator is already lukewarm on this clip going in.
    Record this as a FINDING, not a blocker — a clip swap later is a source-file content swap plus
    a re-run of the AC 1 tool, exactly the `5-0a/R1` strafe precedent (`decision-log.md:8257-8265`:
    the mismatched strafe clips were fixed by swapping the FBX content on disk and re-running
    `add_paladin_locomotion.gd`, never a code change). No code change would be needed to replace
    `thrust` later.
(c) **Are the three poses distinguishable in under 0.5 s, at distance, with sound?** This is where
    AC 14's S8 discipline actually gets exercised — a naive-observer pass, sound alone, one colour
    at a time, following the `docs/legibility-protocol.md` shape `3-0b` already used for
    attack-vs-block.
(d) **Does the model stay inside its collision box through the chargeup and the strike?** This is
    the live check on AC 5/AC 6/AC 7's measured numbers — a clip that net-zeros on paper but still
    reads as walking (e.g. because the box itself is smaller than the visible mid-clip excursion)
    is a finding for the box-vs-model DEBT E lineage (`3-0b` Pass 3b precedent), not silently
    accepted because the number says zero.

## Open Questions (left to the gate / dev pass)

- **Where the colour -> clip / colour -> profile lookup is best seated** (AC 8/AC 10): a second
  dictionary beside `AnimationController._CLIP`, a widened value type on `_CLIP` itself, or a
  small dedicated struct — implementation detail, not design, left to the dev pass.

## Dev Notes

- **The new assembly tool, exact shape (AC 1).** `tools/add_paladin_locomotion.gd` is the pattern
  to copy, not the file to edit: its `NEW_CLIPS`/`EXISTING_CLIPS` constants are hardcoded to
  5-0a's three locomotion clips and its header explicitly frames itself as "the one structural
  difference from `build_zombie_anims.gd`" for locomotion — a 5-3 tool naturally becomes the SAME
  precedent's next instance (`EXISTING_CLIPS` grows to all nine current names, `NEW_CLIPS` becomes
  `{swipe: false, jump_attack: false, thrust: false}`, loop `false` for all three since these are
  one-shot attacks). `ResourceSaver.save` / `AnimationLibrary.add_animation` / the idempotent
  replace-if-present behavior all carry over unchanged.
- **`measure_hips_displacement.gd` needs no edit** — it iterates `lib.get_animation_list()`, so the
  three new clips appear in its output the moment AC 1's tool has run, with zero changes to the
  measurement tool itself.
- **AC 21's dispatch pin follows `test_totem_tint_live.gd` (5-0c)** — a headless
  `extends SceneTree` integration test, not a state-suite test: it loads `main.tscn`, drives the
  real presentation-layer dispatch (there: `UnitBoard.add` per kind; here: `CHARGING` per colour),
  and measures the runtime result rather than authored data at rest. See
  `test/integration/test_totem_tint_live.gd` for the exact shape to mirror (frame-gated
  `_physics_process`, tree-walk collection, `RESULT: PASS`/`FAIL` print + `quit()` code).
- **Existing presentation architecture this story extends, read in full before touching either
  file:**
  - `src/actors/hero/animation_controller.gd` — `_CLIP` (ActionState -> clip name, five entries),
    `on_action_state_changed` (the transition seam), `_restart()` (unconditional restart, no
    blend, the 3-0a/R5 policy this story's CHARGING entry must also honor — a charge that starts
    mid another animation wins immediately). `CHARGING`/`STUNNED` are named UNMAPPED BY DESIGN at
    `:18` ("CHARGING is an E5 reservation") — this story is that reservation's claim.
  - `src/actors/hero/telegraph_controller.gd` — `_profiles` / `_shapes` / `_stings`, all built in
    `_ready()` off `@export`ed `TelegraphProfile` resources; `on_action_state_changed` is the seam
    that would need the colour-aware extension (AC 10). `hero.tscn`'s `TelegraphController` node
    already carries `StingAttack`/`StingBlock`/`StingRoll` AudioStreamPlayers on the `CombatCues`
    bus (`hero.tscn:104-130`) — the precedent for whatever new sting nodes this story adds.
  - `src/state/resources/telegraph_profile.gd` — the existing `.tres` schema (`shape_id`,
    `sting_id`, `color`), reusable as-is for the three new colour profiles; authored under
    `data/telegraphs/*.tres` per its own header.
- **Card colour is already flowing to state** (`5-2` AC 4's `inject_card_colors` seam,
  `match_state.gd`) — this story needs no new colour source; `charge_color` on the snapshot is
  already the spent card's `Enums.CardColor`.
- **`KeyboardController._sample_card_scheme` is the one function to edit for AC 16-17**
  (`keyboard_controller.gd:104-117`). It currently hardcodes `intent.card_mode =
  Enums.ModeKind.BASIC` at line 113 with the comment "Mode ① is the only mode E3 resolves; no key
  selects it and none needs to" — that comment is now stale for P1 and must be corrected or
  removed as part of this story's diff, not left to silently mislead the next reader.
- **project.godot discipline** — CLAUDE.md requires project.godot edits be intentional and
  reviewed; this story's one new Input Map action is the only such edit, and it must not touch any
  of the six recorded incidents' `physics_ticks_per_second` pin (unrelated field, but the review
  should confirm the diff is scoped to exactly the new action).

### Project Structure Notes

- New: one tool script under `tools/` (AC 1, naming dev's call); one headless integration test
  under `test/integration/` (AC 21, naming dev's call).
- Touched: `src/actors/hero/animation_controller.gd` (AC 8-9), `src/actors/hero/telegraph_controller.gd`
  (AC 10), `src/actors/hero/hero.tscn` (new `TelegraphProfile` `.tres` exports wired, new sting
  AudioStreamPlayer children, AC 10), `src/controllers/keyboard_controller.gd` (AC 16-17),
  `project.godot` (one new Input Map action, AC 16), `test/integration/test_rig_clips.gd` (AC 3).
- New authored data: three `TelegraphProfile` `.tres` instances under `data/telegraphs/` (colour ->
  shape_id/sting_id/color), following the existing attack/block/roll profiles' shape.
- No new top-level folder. No `src/state/` file is touched.

### Project Context Rules

- **F1** — not implicated: no new `_physics_process` anywhere touched by this story.
- **D3(a)** — implicated narrowly and correctly: the one new `Input.*` read (AC 16) lands inside
  `src/controllers/keyboard_controller.gd`, the only place it is permitted.
- **D3(b)/A2** — not implicated: no RNG/Time/OS/Engine call enters `src/state/`; this story adds no
  `src/state/` edit at all.
- Feature-flag HARD RULE — not implicated: `unblockable`'s flag gate is `5-2`'s (already flipped
  `true`, `5-2/R14`); this story adds no new gameplay layer to flag.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside
  the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: **Tier B** (`E5-P/R5`). Per `CLAUDE.md`'s tier clause, a measured before/after
  showing the golden and snapshot key set unmoved is the gate this story's own dev pass owes — see
  Golden Prediction above; no separate Tier A gate pass is required unless that measurement
  contradicts the prediction, which would force a tier raise (never a lower one).

### References

- [Source: docs/implementation-artifacts/5-2-unblockable-initiation.md] — the story that published
  the `telegraph` fact this one consumes; AC 21/22/23 and Completion Notes for the fact's exact
  shape and the golden-measurement discipline this story's own prediction follows.
- [Source: src/state/player_state.gd:163-190,445-480] — `charge_window`, `charge_color`,
  `NO_TELEGRAPH_COLOR`, and the `telegraph` key construction itself.
- [Source: src/state/match_state.gd:2231-2243] — the mode dispatch `match`, `UNBLOCKABLE`'s live
  arm, and the `DEFENSE`/`PITCH` guarded-stub `_` arm (AC 20).
- [Source: src/state/input/input_intent.gd:60-64] — `card_slot`/`card_mode`/`card_commit`, already
  present, no new field needed (AC 17).
- [Source: src/controllers/keyboard_controller.gd:104-117] — `_sample_card_scheme`, the hardcoded
  `BASIC` write at `:113` this story's AC 16-17 changes for P1.
- [Source: src/controllers/gamepad_controller.gd:172] — the pad's own hardcoded `BASIC` write,
  confirmed untouched (AC 18, `5-7`'s).
- [Source: src/actors/hero/animation_controller.gd] — `_CLIP`, the `CHARGING`/`STUNNED`
  unmapped-by-design note at `:18`, `_restart()`'s no-blend policy (AC 8-9).
- [Source: src/actors/hero/telegraph_controller.gd] — `_profiles`/`_shapes`/`_stings`, the
  `on_action_state_changed` seam (AC 10).
- [Source: src/state/resources/telegraph_profile.gd] — the reusable `TelegraphProfile` schema.
- [Source: tools/add_paladin_locomotion.gd] — the EXTEND-not-rebuild pattern (AC 1's precedent,
  header lines 8-14), and its `NEW_CLIPS`/`EXISTING_CLIPS` shape to mirror, not edit.
- [Source: tools/measure_hips_displacement.gd] — the reusable, unmodified measurement tool (AC 5),
  and its own doctrine that mid-clip excursion is not a defect (`:14-18`).
- [Source: test/integration/test_rig_clips.gd] — the nine-clip machine contract this story extends
  to twelve (AC 3), and the six-to-nine precedent (`5-0a`) it repeats.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:1834-1851] —
  `3-0b/R34`, verbatim, the suite-blind-spot ruling AC 21 exists to close for this story's own
  dispatch.
- [Source: test/integration/test_totem_tint_live.gd] — `5-0c`'s runtime-dispatch pin, the exact
  precedent AC 21 mirrors (direct board injection, tree-walk measurement, no card/input plumbing
  re-driven).
- [Source: src/state/match_state.gd:2254-2508] — the `reject_action`/`action_rejected` reuse for
  BOTH `_resolve_basic_cast` and `_resolve_unblockable_cast`'s refusal paths (AC 13's rejection
  finding) and their success paths' `card_cast_resolved` emission sites (AC 13's success cue).
- [Source: src/actors/hero/telegraph_controller.gd:83-87] — `on_action_rejected`'s existing,
  unconditional `_cue_reject.play()`, already connected (`src/main/match_runner.gd:451`) — the
  wiring AC 13 measures as already discharging S5's rejection half.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:466] — `1-10/R1`,
  verbatim, controller-owned mapping (Ruling 1).
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:859] — the
  ORIGINAL S8 finding (`2-6/R19`), closed by `3-0b`, extended (not reopened) by this story (AC 14).
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md:21,23] — AC 9/AC 11, S8's
  closure: attack/block stings made audibly distinct, naive-observer-verified.
- [Source: docs/playtest-log.md:139-141] — S5, VERBATIM, primary source (AC 12).
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:3196-3199] — S5
  restated in the `3-5a` smoke record.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:5784-5785] —
  `E4-P/R11`, S5's audio half left unhomed through E4.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8195-8196] —
  `E5-P/R5` item 8, homing S5's audio half and the S8 discrimination finding at THIS story.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8708-8719] —
  `5-2/R15`, verbatim: no live producer for mode ②, both controllers' hardcoded `BASIC` sites named
  by file:line, the regression-smoke consequence for `5-2`'s own gate.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8257-8265] —
  `5-0a/R1`, the strafe clip-swap precedent (file swap + reassembly, no code change), cited
  correctly here as `5-0a`'s ruling, not `3-0a`'s.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:1739-1748] —
  `3-0b/R27`, the ROLL clip's Hips X/Z-zero-keep-Y fix — the correct precedent for AC 6, not `run`.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:1001] — `3-0a/R14`,
  where the zero-XZ-keep-Y option was first named.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:148] — the GDD's own
  "chargeup + color telegraph (shape + sound, <0.5 s)" requirement this story exists to satisfy.
- [Source: src/actors/hero/hero.tscn:59-65,104-130] — the single `AnimationPlayer`/`AnimationLibrary`
  wiring (now NINE clips, corrected from the stale "six-clip" figure) and the existing
  `TelegraphController` sting-node precedent.
- [Source: CLAUDE.md — Story tiers, Git discipline] — Tier B's lighter gate, the project.godot
  review requirement, and the git-discipline rules this story's dev pass must follow.

## Dev Agent Record

### Agent Model Used

_Not yet run — story authored, not dev-passed._

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Note | Agent |
|------|------|-------|
| 2026-09-05 | Story authored via `gds-create-story`, baseline `0c56196`. Status `authored` (project override — see `_bmad/custom/gds-create-story.toml`), NOT promoted to `ready-for-dev`. Board entry stays `backlog` pending operator review. | Claude Sonnet 5 |
| 2026-09-05 | Review fixes: AC 13 widened to both modes' success cue + measured that the rejection cue is already live (no new code, `1-10`/`3-5a` wiring); AC 21 added (runtime dispatch pin, `test_totem_tint_live.gd` precedent, `3-0b/R34`); AC 16/17/19 resolved to "alternate confirm on the existing arm-then-confirm sequence"; all three Open Questions resolved but one (colour-lookup seat). Promoted `authored` -> `ready-for-dev`. | Claude Sonnet 5 |
