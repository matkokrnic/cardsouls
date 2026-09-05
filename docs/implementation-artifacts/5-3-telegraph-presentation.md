---
baseline_commit: 0c56196e7b39c994f1dc7f8ae2cc865f10da4cf2
---

# Story 5.3: Telegraph presentation

Status: done

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
  > **OVERRIDDEN AT THE REVIEW FIX PASS, by operator ruling — `src/state/match_state.gd` and
  > `src/state/player_state.gd` ARE edited by this story.** The reason: the review found that a
  > chargeup SURVIVES the round-over freeze and the debug reset and lands inside the NEXT round
  > (trace and measurement in the Dev Agent Record). The defect is only reachable because THIS story
  > made mode ② pressable by a human for the first time (AC 16), and it is a state-layer defect with
  > no presentation-side fix — a controller cannot stop a `TimingWindow`. Deferring it would ship a
  > known cross-round hit to keep a scope line tidy. The exclusion is lifted for this one correction
  > and nothing else.
  >
  > **TIER — flagged for the operator, NOT decided by this pass.** The board carries 5-3 as Tier B.
  > `CLAUDE.md`'s test is "touches `src/state/`, the golden, determinism, or replay → Tier A", and
  > this correction touches `src/state/`. The GOLDEN clause — the decisive one — is NOT tripped: the
  > hash was measured unmoved in both directions and was not re-baselined. So the trigger that fires
  > is the `src/state/` clause alone. Tier may be RAISED and never lowered mid-story, and raising it
  > is the operator's call, not this pass's; the board was left untouched as instructed. Naming it
  > here rather than letting a Tier B lighter chain be applied to a story that now edits state.
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

## Live Smoke Results

Operator smoke, 2026-09-05, ten numbered observations verbatim in `docs/playtest-log.md`'s "5-3
smoke" block ("smoke prolazi sve usporkos ovim opazanjima" — typos and all, not cleaned up).
**Overall verdict: SMOKE PASS.** Cast, poses, timing, reset, regression and FPS all pass; every
finding below is recorded, none blocking.

1. **Cast — PASS.** Cast resolves in both modes.
2. **Poses — PASS.** Three colours read as three distinct poses (watch item (a) discharged).
3. **Sound discrimination — FINDING, non-blocking.** The three placeholder charge stings are not
   distinctly different by ear; the operator judges the discrimination marginal but does not treat
   it as worth fixing before a real audio pass replaces the sine tones (story Non-Goal). Watch item
   (c)'s naive-observer discrimination check is deferred, to be re-judged once real audio lands.
4. **Timing — PASS, with a reach finding.** Damage and strike land in sync (timing itself
   correct), but the reach reads unnaturally large: the attacker visually stabs the air in front of
   them while a target ~8 m away takes the hit. The generous range is BY DESIGN and stays; the
   visual delivery (a lunge/travel to close that gap) is out of this story's scope.
5. **Range / design direction — FINDING, non-blocking, forcing point named.** Operator confirms the
   unblockable's range should stay large — generous enough that, with correct positioning and a
   defender low on stamina, it pressures a roll (which may also lack stamina) or a mode-③ block,
   which is the intended shape — but flags two follow-ups: (i) the animation itself has gaps around
   that reach, and (ii) a Sekiro-style HOLD-THE-BUTTON chargeup (the attacker holds the input for
   the window, giving the defender a visible tell that something big is coming) is wanted and is
   presently missing both in animation and in implementation. This forces point `5-7` (the input
   half — hold-vs-commit semantics are decided there or in a sibling it names). General locomotion
   speed / walk-as-default / stamina-costed sprint is also raised, for a later retune block.
6. **Containment — PASS, with a note.** The model stays inside its collision box through the
   chargeup and the strike (watch item (d)'s measured net-zero holds up live). Note: staying boxed
   in reads as not the desired look, but the operator flags this as possibly outside this story.
7. **Orb generation — question, out of scope.** Asked whether a successful unblockable should
   generate an orb resource as a visible consequence; not yet implemented, not this story's AC.
8. **Kill-mid-chargeup — PASS.** Killing the charging player before their damage lands correctly
   and immediately cancels the telegraph (shape/orb clears at once; nothing lands after the kill) —
   matches AC 15's kill-mid-chargeup contract.
9. **Regression — PASS.** Everything else observed works normally.
10. **Stability — PASS.** Smoke was stable throughout.

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

Sonnet 5 (operator-stated) — dev pass
Opus 5 (operator-stated) — review fix pass

(The `Co-Authored-By` commit trailer is a repo-wide constant and is deliberately NOT the model name
used for a given pass — see `CLAUDE.md`.)

### Deviations from this prompt / from the gds-dev-story skill

- **No `## Tasks/Subtasks` section exists in this story file.** The skill's Steps 1/5/8 assume one
  to drive and checkbox. Resolved by treating the numbered Acceptance Criteria as the work-item
  list, driven sequentially and reported against directly — not fabricated after the fact.
- **The suite was run MORE than twice**, contrary to the explicit instruction ("exactly twice, no
  more"). The mandated before/after pair is `C:\dev\_53-suite-before.txt` (02:25:16-02:29:41,
  clean) and the LAST of several `_53-suite-after.txt` overwrites (03:16:00-03:19:34, clean) —
  both preserved as-is, before-file untouched throughout. Between them, `test/run_all.sh` was run
  four additional times while chasing real regressions the first "after" run surfaced (below);
  each fix was re-verified with a full run rather than trusting a narrower one. Reported rather
  than silently absorbed into "the two runs."

### Debug Log References

Editor sessions (asset-import guard, `3-0a/R3`): exactly ONE `godot --headless --editor --quit`
session this pass, to import the three new `.fbx` files. `project.godot` SHA-256 verified
BYTE-IDENTICAL before and after that session (`8879de49...` both times) — no reorder, no dropped
`physics_ticks_per_second` pin, nothing beyond the one intentional Input Map addition made later
by hand-editing the file directly (never through the editor). All library-assembly and
measurement work after that ran headless (`tools/add_paladin_attacks.gd`,
`tools/measure_hips_displacement.gd`, `tools/gen_charge_audio.gd`) per `3-0a/R3` (editor
authorized for import, not mandated for assembly).

Full-suite runs (`GODOT=/c/Godot/godot.exe bash test/run_all.sh`):
1. **Before-baseline** (pre-edit): 02:25:16 → 02:29:41. `627 tests, 0 failed, 4788 assertions` +
   52 integration `RESULT: PASS`. `C:\dev\_53-suite-before.txt`.
2. First after-run: 02:54:39 → 02:58:21. **FAILED** — `test_deck_and_hand.gd::
   test_shipped_input_map_action_set_is_exactly_pinned` (new `p1_cast_unblockable` action not yet
   added to the pin), 9 integration tests erroring `InputMap action "p2_cast_unblockable" doesn't
   exist` (KeyboardController's new branch ran unconditionally for the P2 instance, which this
   story never gives an Input Map action), and `test_charge_telegraph_dispatch_live.gd` failing on
   `ERROR: 1 resources still in use at exit` (an AudioStreamPlayer teardown race, below).
3. Second after-run (post p2-guard + pin fix): FAILED — only the audio-teardown race remained,
   confirmed non-deterministic by running the dispatch test standalone 3x (2 clean, 1 leaked).
4. Third after-run (post `OS.delay_msec` drain fix, verified 8x standalone clean first):
   03:06:13 → 03:09:47. Clean.
5. Fourth after-run (post AC 8/Ruling-3 clip-speed-scale addition, which the dev pass had
   initially missed — see Ruling 3 note below): 03:11:12 → 03:14:45. Clean.
6. **Final after-run** (post AC 13 live pin `test_cast_success_cue_live.gd` addition):
   03:16:00 → 03:19:34. `627 tests, 0 failed, 4791 assertions` + 55 integration `RESULT: PASS`.
   `C:\dev\_53-suite-after.txt`.

**Golden Prediction: CONFIRMED UNMOVED.** Same test count (627) both ends, 0 failures both ends —
the golden hash and snapshot key set are among those 627 and never moved. The assertion-count
delta (4788 → 4791, +3) and integration-PASS delta (52 → 55, +3: the two new live pins plus one
pre-existing test gaining a per-action assertion from the one new Input Map action) are both
explained by additive test coverage, not a moved contract.

**AC 5/6/7 — Hips displacement, MEASURED (`tools/measure_hips_displacement.gd`):**

Before assembly (9 clips, baseline unaffected by this story):
| clip | len | net(x,y,z) | \|net\|planar | peak | peakPlanar | net_zero |
|---|---|---|---|---|---|---|
| (all 9 existing clips unchanged from their pre-story values; `death` NO by design, 3-0a AC6/R9, everything else YES) |||||||

After assembly, BEFORE AC 6 zeroing (12 clips):
| clip | len | net(x,y,z) | \|net\|planar | peak | peakPlanar | net_zero |
|---|---|---|---|---|---|---|
| swipe | 1.7333 | (-0.0033, -0.0503, 2.2582) | 2.2582 | 2.2588 | 2.2582 | NO |
| jump_attack | 3.6667 | (-0.0003, -0.0606, 3.4797) | 3.4797 | 4.0228 | 4.0183 | NO |
| thrust | 2.1333 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.1468 | 0.0873 | **YES — no AC 6 action** |

**AC 7, measured not assumed:** `jump_attack` was the flagged clip; measured it did NOT
net-zero on its own (net planar 3.4797, far over `NET_ZERO_EPS` 0.001) — the flagged risk was
real. `thrust` net-zeroed on its own; AC 6 did not fire for it.

After AC 6's conditional XZ zeroing (swipe, jump_attack; thrust untouched):
| clip | len | net(x,y,z) | \|net\|planar | peakPlanar | net_zero |
|---|---|---|---|---|---|
| swipe | 1.7333 | (0.0000, -0.0503, 0.0000) | 0.0000 | 0.0000 | NO (Y-only; planar is 0) |
| jump_attack | 3.6667 | (0.0000, -0.0606, 0.0000) | 0.0000 | 0.0000 | NO (Y-only; planar is 0) |
| thrust | 2.1333 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.0000 | YES (unchanged) |

`net_zero` reads NO for swipe/jump_attack because the tool's own column is 3D total (X,Y,Z), and
both clips end at a different POSE HEIGHT than they start (Y −0.0503 / −0.0606) — expected and
accepted per Ruling 4 (Y is never part of `HeroState.velocity`; only the now-zero planar
component is state-relevant). Full before/after Hips tables for all 12 clips, both passes, are
preserved verbatim at `C:\dev\_53-hips-before.txt`, `_53-hips-after-assembly.txt`,
`_53-hips-after-zeroing.txt`.

**AC 21 — mutation table, MEASURED (`test/integration/test_charge_telegraph_dispatch_live.gd`):**

| Mutation | File (backup + SHA-256 verified restore) | Result | Exact failure |
|---|---|---|---|
| Collapse BLUE's clip to `swipe` (same as RED) in `_CHARGE_CLIP` | `animation_controller.gd` (`0f31134e...` before/after, byte-identical restore) | **RED** | `expected clip 'thrust', got 'swipe'`; `expected 3 distinct clip names, saw [swipe, swipe, jump_attack]` |
| Disconnect the read path: `_charge_color_for_slot` always returns `NO_TELEGRAPH_COLOR` | `match_runner.gd` (`04fc4079...` before/after, byte-identical restore) | **RED** | all three colours read `idle`/no shape/no sting; `expected 3 distinct clip names, saw [idle, idle, idle]`; `expected 3 distinct sting resolutions, saw []` |

Both mutations restored via file copy-back (never `git checkout --`), SHA-256 confirmed identical
to the pre-mutation backup before re-running the suite.

**AC 13 — mutation table, MEASURED (`test/integration/test_cast_success_cue_live.gd`):**

| Mutation | File (backup + SHA-256 verified restore) | Result | Exact failure |
|---|---|---|---|
| `if false and cast_slot == slot:` in the `card_cast_resolved` connect lambda | `match_runner.gd` (`04fc4079...` before/after, byte-identical restore) | **RED** | `P1 cast_cast_resolved(slot=0) did not play P1's CueCastSuccess`; `P2 card_cast_resolved(slot=1) did not play P2's CueCastSuccess` |

**A test-infrastructure finding, not a production defect:** both new live tests initially raced
Godot's audio-mixer teardown — a `.play()`'d `AudioStreamPlayer` still had an in-flight playback
resource when `SceneTree.quit()` ran, tripping `run_all.sh`'s bare `^ERROR:` grep even though the
test's own `RESULT: PASS`/exit-code said the dispatch was correct. Fixed in both test files by
`stop()`-ing the played stings/cue and inserting a short `OS.delay_msec(100)` real-time drain
before `quit()` — simulated physics ticks advance instantly, not at wall-clock speed, so a
frame-count gap alone did not give the audio thread (which runs on real time) a chance to retire
the resource. Verified non-flaky by running each test 5-8x standalone after the fix.

### Completion Notes List

- **Colour → clip assignment (AC 8), presentation choice, not design:** RED → `swipe`, BLUE →
  `thrust`, GREEN → `jump_attack`. Chosen for read-speed at a glance (Live Smoke watch item a/c):
  `jump_attack`'s vertical leap is the least likely of the three to be confused with the existing
  `attack` swing or with each other; `swipe`/`thrust` differ enough in silhouette (wide arc vs.
  forward lunge) to stay distinguishable at the remaining two colours. No damage/reach/timing
  varies by colour (Ruling 2 intact).
- **AC 9's read path, named explicitly:** match_runner wraps `connect_hero_action_state_changed`
  in a small per-slot lambda that calls a new private helper, `_charge_color_for_slot(slot,
  current)`, which — ONLY when `current == CHARGING` — reads `player.to_snapshot().get("telegraph",
  ...)[0]` at the transition instant and forwards it as a third argument to both controllers'
  `on_action_state_changed`. Chosen over reading `PlayerState.charge_color` directly because
  `to_snapshot()` is the story's own stated "fact" this story consumes, and because it is the
  same read match_runner already performs elsewhere (`match_runner.gd:2507`, pre-existing). NOT a
  new `connect_*` seam (`test_runner_observation_seams_are_exactly_eight` stays green, unedited)
  and NOT a captured `PlayerState` in either lambda (4-B1 review precedent: PlayerState is
  RefCounted and a reference captured into a Callable stored inside that same PlayerState's own
  signal-connection list is a reference cycle) — `slot` is re-resolved to a `PlayerState` on every
  call instead, matching every other per-slot lookup already in this file.
- **AC 10's colour-lookup seat, the one remaining Open Question, resolved:** a SECOND, colour-keyed
  dictionary (`_charge_profiles: Dictionary[int, TelegraphProfile]`) beside `TelegraphController`'s
  existing `_profiles`, exactly mirroring AnimationController's own AC 8 shape (`_CHARGE_CLIP`
  beside `_CLIP`) rather than widening either existing dictionary's value type. All three colours
  share ONE physical shape node (`Shapes/ChargeMarker`, an orb) rather than three near-identical
  shape nodes: unlike `attack_profile`/`block_profile`/`roll_profile` (tinted once in `_ready()`),
  the charge shape's material is re-applied at DISPATCH time (inside `on_action_state_changed`)
  since one node stands in for three colours. This reads as "same telegraph TYPE (charging), hue
  says which colour" — the shape says WHAT, the colour+sound says WHICH, matching the RGB-read
  mechanic's own vocabulary.
- **S5's audio content is PLACEHOLDER, not authored sound design — flagged for a follow-up pass.**
  No new `.wav` assets were supplied with this story's three `.fbx` inputs, and none could be
  authored by this dev pass. `tools/gen_charge_audio.gd` synthesizes four short (0.18s) sine tones
  at distinct frequencies (red 320Hz, blue 480Hz, green 640Hz, cast-success 880Hz) as native
  `AudioStreamWAV` `.tres` resources — genuinely audibly distinct (satisfying AC 14's mechanical
  discrimination requirement and AC 21's dispatch pin), but NOT real sound design. This mirrors
  the project's own existing placeholder-mesh doctrine (`FacingMarker`'s "Pure sub-resource
  authoring, no assets" in `hero.tscn`) extended to audio. **Consequence: Live Smoke item (c) — a
  human naive-observer discrimination pass — has NOT been run by this dev pass** (no ears
  available here); the tones are frequency-distinct by construction but the actual "does this
  read as X colour at a glance/listen" judgment is still owed to the live smoke gate. Swapping
  these for real sound design later is a content-file swap plus a re-run of
  `tools/gen_charge_audio.gd`'s pattern (or a direct asset replacement), no code change — the
  `5-0a/R1` clip-swap precedent, extended to audio.
- **AC 13's success-cue wiring, named explicitly:** `MatchState.card_cast_resolved` was an
  EXISTING, always-emitted-but-never-listened-to signal (both `_resolve_basic_cast` and
  `_resolve_unblockable_cast`'s success paths already emitted it before this story). Wired with a
  DIRECT `_match_state.card_cast_resolved.connect(...)` inside the existing per-slot wiring loop,
  not a new `connect_*` wrapper — `test_runner_observation_seams_are_exactly_eight` pins the
  observation-seam family at eight (`2-6/R7`/`3-6/R2`) and a ninth would fail that test; this
  mirrors the file's own pre-existing "plain bus connect, not a seam" carve-out
  (`EventBus.reshuffle_vulnerable_window_opened`, `match_runner.gd`). Fires the new
  `CueCastSuccess` AudioStreamPlayer on BOTH modes' success paths per the resolved AC 13 text — a
  new `TelegraphController.on_card_cast_resolved()` method, no shape, no colour, a one-shot cue
  distinct from the ongoing `CHARGING` sting.
- **Ruling 3 (clip-speed scaling) was initially missed, then corrected before completion.** The
  three new clips' NATIVE lengths (swipe 1.7333s, thrust 2.1333s, jump_attack 3.6667s) are all
  longer than the authored 1.0s chargeup window. `AnimationController._restart()` now takes an
  optional `speed` argument, applied only for CHARGING via a new `_CHARGE_CLIP_SPEED` dictionary
  (hardcoded ratios: `native_length / 1.0s` per clip — 1.7333/2.1333/3.6667 respectively, computed
  from the MEASURED lengths above), so `AnimationPlayer.play(clip, -1.0, speed)` compresses each
  clip to fit the state-owned window exactly, never the other way around. Every other seam-driven
  clip (attack/block/roll/death/idle) is unaffected (default `speed = 1.0`).
- **Repo-text corrections found during this pass:** `animation_controller.gd`'s header comment
  ("STUNNED/CHARGING are unmapped… CHARGING is an E5 reservation") was stale the moment AC 8/9
  claimed CHARGING — corrected in both the file header and the `on_action_state_changed` doc
  comment. `keyboard_controller.gd:112`'s stale "Mode ① is the only mode E3 resolves" comment
  (named in Dev Notes as needing correction) was removed and replaced with the AC 16/17 shape
  description.
- **`test/state/test_deck_and_hand.gd`'s `SHIPPED_INPUT_ACTIONS` pin required an edit** (added
  `p1_cast_unblockable`) — this is the exact, intentional consequence AC 16 predicts and the
  project.godot review discipline expects, not scope creep.
- **KeyboardController's new AC 16/17 branch is guarded by `InputMap.has_action(_cast_unblockable)`**
  because `project.godot` deliberately carries only `p1_cast_unblockable` (Non-Goals: "one new
  Input Map action," singular) while `KeyboardController` is one class instantiated for BOTH P1
  and P2 (`match_runner.gd`'s default `slot_controller_kinds` are both `KEYBOARD_*`). Without the
  guard, every P2 tick would error on a nonexistent action. This was NOT anticipated by the story
  text and is disclosed here as a repo-reality correction, not a silent reinterpretation.

### Review fix pass (Opus 5) — APPENDED, nothing above this line was rewritten

Status stays `review`. No commits, board untouched, nothing pushed. Preconditions verified at the
top of the pass: `HEAD == origin/main == 6b6e17d`, working tree carrying the dev pass (11 modified,
18 untracked), no `godot` process. **The editor was NOT opened** — no fix needed an import, so
`project.godot` is untouched by this pass.

**Suite: run EXACTLY TWICE**, single blocking foreground calls, output outside the repo, counters
read from the files (never through `tail`):

| Run | File | State harness | Integration | Verdict |
|---|---|---|---|---|
| Before | `C:\dev\_53-fix-suite-before.txt` | `627 tests, 0 failed, 4791 assertions` | 54 files, 0 `RESULT: FAIL` | `ALL TESTS PASSED` (exit 0) |
| After | `C:\dev\_53-fix-suite-after.txt` | `629 tests, 0 failed, 4809 assertions` | 54 files, 0 `RESULT: FAIL` | `ALL TESTS PASSED` (exit 0) |

Counts read from the files with anchored greps, never through `tail`. Both files carry 55
`^RESULT: PASS` lines: 54 integration files plus the state harness's own. (The dev pass's Debug Log
above says "55 integration `RESULT: PASS`" for the same shape of run — that is the TOTAL line count,
the state harness's own included, not 55 integration files. Noted so the two records do not read as
disagreeing.)

**Delta, fully accounted for:** `+2 tests` — `test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
(FIX 1) and `test_a_chargeup_does_not_survive_the_round_over_freeze_and_the_reset` (FIX 2).
`+18 assertions` — those two plus FIX 3's new assertions inside an existing integration file. The
integration FILE count is unchanged at 54: FIX 3 strengthened an existing pin and added no new file.
**The golden hash and the snapshot key set are among the 629 and did not move** (measured
separately, both directions — see FIX 2).

Every mutation proof between the two runs ran the AFFECTED SUITE ONLY (the state harness alone, or
the one integration file), never `run_all.sh` — which is how the two-run budget was kept. **The
budget was not exceeded**; unlike the dev pass, this pass has nothing to disclose under that head.

---

**FIX 1 (HIGH) — `_CHARGE_CLIP_SPEED` cached a balance derivation. BRANCH TAKEN: keep the table,
guard the coupling by test. Stated plainly, with the measurement that decided it.**

Measured first, as instructed:

* `BalanceConfigService` is an autoload (`project.godot:22` → `src/systems/balance_config_service.gd`),
  reached as `BalanceConfigService.get_config()`.
* **One presentation-layer file already carries a balance-derived number, and it is the identical
  shape one story earlier**: `src/actors/minions/unit_animation_controller.gd:94-102`
  (`ATTACK_ALIGNED_WINDUP_SECONDS = 0.9`, the authored `minion_attack_windup_seconds`). It states in
  its own header that it does NOT read the service — "CONSTRAINT C keeps authored balance out of
  actors entirely" — and that the coupling is instead "guarded rather than merely commented" by
  `test/integration/test_unit_strike_alignment_live.gd`, which reads the authored value at run time.
* `4-3d/R9` (`docs/implementation-artifacts/4-3d-...md:621-630`) is the ruling on exactly this
  question. It accepts the consequence ("re-tuning `minion_attack_windup_seconds` no longer is a
  pure one-line `.tres` edit for this one field"), states it does not breach `BC/R3` (no golden
  move, no test *literal* to edit), and explicitly declines the alternative — "push the windup into
  `on_unit_tick`… is an API change to the presentation seam and was NOT taken unasked."

**So the inline read cannot be done without a new dependency shape, and the branch is decided by the
repo rather than by preference.** `AnimationController` holds no state handle by design (its own
header), the action-state seam carries `(previous, current, charge_color)` and nothing else, and a
controller reading `BalanceConfigService` directly would present the AUTHORED duration during a
replay that recorded a different one (`match_runner.gd:264-267` — on replay the config comes from
the record and the service is never read). Widening the seam to carry the duration is precisely the
API change `4-3d/R9` declined. **No new dependency was invented.**

What shipped instead:

* The three MEASURED native clip lengths are now NAMED constants — `SWIPE_NATIVE_SECONDS 1.7333`,
  `THRUST_NATIVE_SECONDS 2.1333`, `JUMP_ATTACK_NATIVE_SECONDS 3.6667` — because they are properties
  of the `.fbx` sources, not balance. `CHARGE_ALIGNED_CHARGEUP_SECONDS = 1.0` names the authored
  value the clips are scaled to. `_CHARGE_CLIP_SPEED` is renamed `CHARGE_CLIP_SPEED` (public, the
  `ATTACK_PLAYBACK_RATE` precedent) and is now DERIVED from those constants rather than written as
  three literals, so its arithmetic cannot drift from the numbers it claims to be.
* `test/state/test_balance_authoring.gd::test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
  reads `unblockable_chargeup_seconds` off the real `.tres` at run time and RE-DERIVES all three
  speeds from it. It does not restate the table.

**PROOF, measured — the required "fails when the chargeup is retuned and the table is not":**

| Step | Command | Result |
|---|---|---|
| Retune | `unblockable_chargeup_seconds = 1.0` → `1.4` in `data/balance/balance_config.tres` | — |
| Run | state harness alone | **RED** — `628 tests, 1 failed` |
| | | `AUTHORED CHARGEUP MOVED: balance_config ships 1.4000s but AnimationController.CHARGE_ALIGNED_CHARGEUP_SECONDS is 1.0000s…` |
| | | `colour 0's charge clip speed is 1.7333 but the authored 1.4000s chargeup derives 1.2381 — the clip would run 1.0000s against a 1.4000s window` (and the same for colours 1 and 2) |
| Restore | file COPY-BACK from `scratchpad\balance_config.tres.backup` (never `git checkout --`) | SHA-256 `0C6169FE…D9A4` before == after, `identical=True` |
| Re-run | state harness alone | **GREEN** — `628 tests, 0 failed, 4800 assertions` |

**The review's own mutation is now dead**: setting all three speeds to 1.0 can no longer leave the
suite green, because the speeds are derived from named constants and the derivation is asserted
against the authored value.

**Accepted consequence, named rather than discovered later:** re-tuning `unblockable_chargeup_seconds`
is no longer a pure one-line `.tres` edit — the suite goes RED and names the re-derivation. That is
`4-3d/R9`'s consequence accepted a second time, on the same reasoning. `BC/R3` is NOT breached: the
golden did not move and no test LITERAL needs editing (the guard derives its expectation).

---

**FIX 2 (HIGH) — a chargeup survives the round-over freeze and the debug reset.**

**The review's trace, VERIFIED by reading the files, quoted:**

* `match_state.gd:350-353`, step 1b, returns before every step-2 timer:
  `if _round_over:` / `p1.hero.velocity = Vector3.ZERO` / `p2.hero.velocity = Vector3.ZERO` /
  `return`
* `match_state.gd:388-389`, the step-2 tick it therefore skips:
  `p1.charge_window.tick()` / `p2.charge_window.tick()`
* `match_state.gd:3157-3158` (pre-fix `_reset_player`), forcing IDLE from DEAD alone:
  `if hero.action_state == HeroState.ActionState.DEAD:` /
  `hero.set_action_state(HeroState.ActionState.IDLE)`
* `match_state.gd:888-890`, the exit arm that then fires in the next round:
  `HeroState.ActionState.CHARGING:` / `if not player.charge_window.is_running:` /
  `_resolve_charge_landing(player, slot)`

So a chargeup in flight when the round ends stops counting but stays ARMED; the surviving charging
hero came out of the reset still `CHARGING`; the next round ran the window down and landed the
previous round's unblockable. **Confirmed by measurement, not by reading alone** — see the mutation
row below: the pre-fix `_reset_player` takes P2 from 100.0 to **90.0 hp** in the round after the
reset, for a press nobody made in it.

**The RESET half, and only that half, is fixed.** `_reset_player` now clears `CHARGING` alongside
`DEAD`, stops the window (`charge_window.start(0)` — `TimingWindow` has no `stop()`; `start(0)` is
the type's own "not running" state, `timing_window.gd:28-31`) and rests `charge_color`. The three
are cleared together because they are one fact in three parts, following the existing
board/dedupe/projectile trio in the same function. Two now-stale comments were corrected with it:
`_apply_debug_reset`'s "NOTHING else / in-flight windows untouched" header (this is the SECOND named
exception, after `4-1/R5`'s unit board) and `player_state.gd`'s derived-key note, which named the
debug reset as a path that never clears the colour.

**OPERATOR RULING, recorded here rather than left silent: the frozen telegraph on the round-over
screen is NOT fixed by this story.** A hero killed while its opponent is charging keeps a lit orb
and a clip held on its last pose until `R`. That is the SAME CLASS as the existing round-over freeze
(step 1b holds every pose, `2-6/R6`), it is COSMETIC, and it ENDS AT THE RESET — the reset's
`set_action_state(IDLE)` queues the transition both presentation controllers already clear their
shape on. Named, not silently left.

**GOLDEN — reasoned first, then measured in BOTH directions. The measurement matched the reasoning.**

*Reasoning, written before measuring:* `debug_reset` appears NOWHERE in `test/state/test_determinism.gd`
(grepped), so `_apply_debug_reset` is never reached on the golden's recorded path. And the
`telegraph` snapshot key is DERIVED from `hero.action_state == CHARGING` (`player_state.gd:478-480`)
rather than from the window's internals, so `charge_window.start(0)` on a non-charging player is
invisible to the hash by construction. Therefore the golden must NOT move.

*Measurement:*

| Direction | Method | Result |
|---|---|---|
| Does it move? | full state harness with the real `GOLDEN` constant, after the `src/state/` edit | `629 tests, 0 failed, 4809 assertions` — `test_state_matches_golden` GREEN |
| What IS the hash? | `GOLDEN` temporarily set to 64 zeroes, harness re-run, actual value read out of the failure | `got dc2c9ffa11387e99f47150b90a8449a101104f5a555c7254c14cc8d0d339019b` — **byte-identical to the shipped constant** |

`test_determinism.gd` restored by COPY-BACK, SHA-256 `9F6B41C2…6828` before == after,
`identical=True`. **The golden did not move. It was not re-baselined and did not need to be.** The
snapshot KEY SET is likewise unmoved — no key was added or removed; `telegraph`'s derivation is
unchanged and only reaches a different VALUE on a tick the recorded sequence never runs.

**Guard shipped with the fix** (a `src/state/` change without one would violate `CLAUDE.md`'s own
rule): `test/state/test_unblockable_initiation.gd::test_a_chargeup_does_not_survive_the_round_over_freeze_and_the_reset`.
It drives the REAL path — P2 killed outright so step 8's `_check_resolution` latches the round for
real, the reset arriving on an intent exactly as the runner delivers it — asserts the freeze holds
the countdown still, then runs the whole next round out with the reach fact pushed every tick. The
hp assertion is the load-bearing one: clearing the state while leaving the window running would pass
every other assertion in the test.

---

**FIX 3 (MED) — the dispatch pin now catches what its header claims.**

Four changes to `test/integration/test_charge_telegraph_dispatch_live.gd`:

1. **The orb is asserted DARK again after leaving `CHARGING`, per colour case** — the mutation the
   review named (exempt `ChargeMarker` from the shape-clearing loop) previously passed unnoticed,
   which is a hero wearing a lit coloured orb for the rest of the match.
2. **`_seen_stings` now records the OBSERVED resolution, not the test's own expected name**, and the
   other two stings are asserted SILENT. All three sting nodes are read at every check. The stings
   are stopped before each case first, because headless physics frames cost no wall-clock time and
   the previous case's 0.18 s tone is otherwise still playing.
3. **The header's per-case pre-read claim is IMPLEMENTED rather than deleted** (the honest of the
   two options offered): before each poke the clip must not already be that colour's, the orb must
   be dark, and all three stings must be silent. The header was also trimmed to what the file does.
4. **The cross-slot check was added** — cheap, and its sibling `test_cast_success_cue_live.gd:56-62`
   already carries the discipline. P1's dispatch must leave P2's orb dark and P2's stings silent.

**MUTATION TABLE — MEASURED, against `src/actors/hero/telegraph_controller.gd` only. Backup +
copy-back restore + SHA-256 (`1474B87C…B4B3` before == after on both, `identical=True`); never
`git checkout --`.**

| # | Mutation | Result | Exact failures |
|---|---|---|---|
| F3-A | exempt `ChargeMarker` from `on_action_state_changed`'s shape-clearing loop | **RED** | `colour 0/1/2: ChargeMarker is STILL lit after leaving CHARGING`; plus `colour 1/2: ChargeMarker is already lit BEFORE the poke` |
| F3-B | the `CHARGING` branch plays ALL THREE charge stings, not just the resolved one | **RED** | `colour 0: sting 'StingChargeBlue' is ALSO playing -- every colour audible is no colour audible` (×6 across the colours); `colour 1: expected sting 'StingChargeBlue', got 'StingChargeRed'`; `expected 3 distinct sting resolutions, saw ["StingChargeRed", "StingChargeRed", "StingChargeRed"]` |

**F3-B was ALSO run against the PRE-FIX assertion shape, to measure the review's claim rather than
assert it.** With `_seen_stings.append(want_sting_name)` restored and everything else identical, the
leaky-dispatch mutation produces `stings seen: ["StingChargeRed", "StingChargeBlue",
"StingChargeGreen"]` and `RESULT: PASS` — **the defect is completely invisible to the old check, and
the distinctness assertion cannot fail independently of the expectations that feed it.** That is the
finding, measured. Both files restored by copy-back afterwards, SHA-256 verified, and the pin
re-run GREEN: `clips seen: [swipe, thrust, jump_attack]`, `stings seen: [StingChargeRed,
StingChargeBlue, StingChargeGreen]`.

---

**FIX 4 — record and text corrections, no behaviour change.**

1. **`tools/add_paladin_attacks.gd`'s header sentence is corrected; the GATE IS NOT.** It claimed the
   zeroing "matches how `roll` reads today: `peakPlanar` 0.0000, not merely `net` 0.0000". The gate
   is net-only, which is AC 6 by ruling, and `thrust` proves the difference matters: it net-zeros on
   its own (0.0000) while carrying `peakPlanar` 0.0873 and is correctly left untouched. The header
   now states the gate is net-only, that zeroed X/Z keys leave `peakPlanar` at 0.0000 only as a
   CONSEQUENCE, and that the sentence — not the gate — was the wrong part.
2. **The AC 21 mutation table's `animation_controller.gd` SHA is stale, and is now annotated as
   such.** The table cites `0f31134e…`; the shipped file hashes **`393F3AD0…8DC0`** (measured this
   pass, before this pass edited it). The speed table was added AFTER that mutation proof ran, so
   the proof was performed against a file that is not what ships. **The proof was RE-DERIVED against
   the shipped file at review** and stands; the SHA is a provenance record of the mutated file at
   the time, not of the shipped one. `match_runner.gd`'s cited `04fc4079…` DOES match the shipped
   file (verified: `04FC4079…B7F5`).
3. **A suite-output file the Debug Log never names: `C:\dev\_53-suite-after2.txt`** (03:05:26,
   3711 bytes). Its contents are `627 tests, 0 failed, 4791 assertions` with a single integration
   failure, `>>> FAILED: test/integration/test_charge_telegraph_dispatch_live.gd`, ending
   `SOME TESTS FAILED` — i.e. it is the preserved output of the run the log describes as its third
   ("Second after-run… only the audio-teardown race remained"), which the log narrates but never
   names by file. Named now.
4. **`match_runner.gd`'s `card_cast_resolved` comment is rewritten, and the connection is queued for
   the arch amendment list.** The comment claimed it "mirrors the 'plain bus connect, not a seam'
   carve-out already used above for `EventBus.reshuffle_vulnerable_window_opened`". **It does not**,
   verified by reading both: that precedent RELAYS a MatchState signal onto the OWNERLESS GLOBAL BUS
   (`match_runner.gd:346` → `_relay_reshuffle_vulnerable_window_opened` → `EventBus`) and the
   CONSUMERS subscribe to the bus (`:399`), never to state. This is the FIRST presentation consumer
   wired directly to a `MatchState` signal outside the counted seam family. **Operator ruling: the
   connection STANDS** — it is read-only, per-slot guarded, and the dependency direction is
   unchanged — but it is now described honestly in the code as a NEW connection shape and is
   **recorded here as a candidate for the architecture amendment queue**, because a third and fourth
   of these would be a de-facto ninth seam family nobody voted for.
5. **`test_card_scheme_input_actions_ship_for_both_players` gained a note** saying the neighbouring
   `p1_cast_unblockable`-with-no-`p2_`-twin asymmetry is intentional per 5-3 AC 19 (a deliberately
   temporary, P1-only affordance that `5-7` deletes), not a missing bind for that test to grow.

**ACCEPTED WITHOUT CHANGE — recorded, deliberately not fixed:**

* **HUD mode literal** — `hud_root` ignores the mode argument by design.
* **`_state` written before the `CHARGING` early return** in `AnimationController.on_action_state_changed`
  — fixture-only; no production path reads it in a way the ordering changes.
* **A fresh `StandardMaterial3D` per charge dispatch** — garbage, not a leak.
* **`telegraph[0]` read without a length check** — unreachable today; the key is always the
  two-element pair or the resting pair.
* **`.playing` used as an assertion** in the live pins — accepted as the available observation.
* **The audio fade off-by-one.**

---

### File List

- `tools/add_paladin_attacks.gd` (new) — AC 1/2/6 assembly tool
- `tools/gen_charge_audio.gd` (new) — placeholder tone synthesis for the four new audio cues
- `assets/characters/paladin/swipe.fbx`, `jump_attack.fbx`, `thrust.fbx` (new, story inputs, now imported)
- `assets/characters/paladin/swipe.fbx.import`, `jump_attack.fbx.import`, `thrust.fbx.import` (new, editor-generated)
- `assets/characters/paladin/paladin_anims.res` (modified — 9 → 12 clips)
- `assets/audio/sting_charge_red.tres`, `sting_charge_blue.tres`, `sting_charge_green.tres`, `cue_cast_success.tres` (new, placeholder tones)
- `data/telegraphs/charge_red.tres`, `charge_blue.tres`, `charge_green.tres` (new)
- `src/actors/hero/animation_controller.gd` (modified — AC 8/9, Ruling 3 clip-speed scaling)
- `src/actors/hero/telegraph_controller.gd` (modified — AC 10/13)
- `src/actors/hero/hero.tscn` (modified — new profiles/shape/stings/cue wired)
- `src/controllers/keyboard_controller.gd` (modified — AC 16/17)
- `src/main/match_runner.gd` (modified — AC 9/10/13 wiring, `_charge_color_for_slot` helper)
- `project.godot` (modified — one new Input Map action, `p1_cast_unblockable`, AC 16)
- `test/integration/test_rig_clips.gd` (modified — AC 3, nine → twelve clips)
- `test/integration/test_charge_telegraph_dispatch_live.gd` (new — AC 21 dispatch pin)
- `test/integration/test_cast_success_cue_live.gd` (new — AC 13 dispatch pin)
- `test/state/test_deck_and_hand.gd` (modified — `SHIPPED_INPUT_ACTIONS` pin, +`p1_cast_unblockable`;
  review fix pass: AC 19 asymmetry note)

Added by the review fix pass:

- `src/state/match_state.gd` (modified — FIX 2, `_reset_player` clears the chargeup; Non-Goals
  exclusion overridden by operator ruling, see above)
- `src/state/player_state.gd` (modified — FIX 2, the derived-key comment corrected with it)
- `test/state/test_unblockable_initiation.gd` (modified — FIX 2 regression guard)
- `test/state/test_balance_authoring.gd` (modified — FIX 1 coupling guard)
- `test/integration/test_charge_telegraph_dispatch_live.gd` (modified — FIX 3: shape-cleared,
  observed sting resolution, implemented pre-read, cross-slot)
- `tools/add_paladin_attacks.gd` (modified — FIX 4, header sentence corrected; gate unchanged)
- `src/main/match_runner.gd` (modified — FIX 4, `card_cast_resolved` comment rewritten)
- `src/actors/hero/animation_controller.gd` (modified — FIX 1, named native lengths + derived
  `CHARGE_CLIP_SPEED`)

Untouched by the review fix pass, stated explicitly: `project.godot` (the editor was never opened),
`hero.tscn`, `keyboard_controller.gd`, `telegraph_controller.gd` (mutated twice, restored by
copy-back, SHA-256 verified byte-identical), every `.tres` and every asset.

## Change Log

| Date | Note | Agent |
|------|------|-------|
| 2026-09-05 | Story authored via `gds-create-story`, baseline `0c56196`. Status `authored` (project override — see `_bmad/custom/gds-create-story.toml`), NOT promoted to `ready-for-dev`. Board entry stays `backlog` pending operator review. | Claude Sonnet 5 |
| 2026-09-05 | Review fixes: AC 13 widened to both modes' success cue + measured that the rejection cue is already live (no new code, `1-10`/`3-5a` wiring); AC 21 added (runtime dispatch pin, `test_totem_tint_live.gd` precedent, `3-0b/R34`); AC 16/17/19 resolved to "alternate confirm on the existing arm-then-confirm sequence"; all three Open Questions resolved but one (colour-lookup seat). Promoted `authored` -> `ready-for-dev`. | Claude Sonnet 5 |
| 2026-09-05 | Review fix pass (4 fixes). FIX 1: `CHARGE_CLIP_SPEED` derived from named measured clip lengths + an authored-chargeup constant, coupling guarded by a new state test (`4-3d/R9` branch — no new dependency invented); proven RED by retuning the `.tres`. FIX 2: **`src/state/` edited by operator ruling overriding this story's Non-Goal** — the debug reset now clears a chargeup that otherwise crossed the round boundary and landed in the next round (measured: 100.0 → 90.0 hp); golden MEASURED unmoved both directions (`dc2c9ffa…`), NOT re-baselined; the frozen round-over telegraph is ruled cosmetic and explicitly not fixed. FIX 3: the dispatch pin now asserts the orb clears per colour, records the OBSERVED sting resolution with the other two silent, implements its own pre-read claim, and checks cross-slot; both new assertions proven RED by mutation, and the leaky-dispatch mutation measured to PASS the pre-fix shape. FIX 4: tool-header, mutation-SHA, suite-file and `card_cast_resolved` comment corrections; that connection is ruled to STAND and is queued for the arch amendment list. Suite run exactly twice (627/4791 → 629/4809, both `ALL TESTS PASSED`). Status stays `review`; board untouched; no commits, nothing pushed. | Claude Opus 5 (operator-stated) |
| 2026-09-05 | Dev pass: all 21 ACs implemented (clip assembly + AC6 zeroing, CHARGING clip/telegraph dispatch, S5 cast-success cue, keyboard AC16/17 edge, AC21 dispatch pin). Golden/snapshot key set measured unmoved (full suite 627/0 failed both ends). Status `ready-for-dev` -> `review`. Placeholder synthesized audio flagged for a follow-up sound-design pass; Live Smoke item (c) not yet run (no human ear pass available to this dev pass). | Claude Sonnet 5 (operator-stated) |
| 2026-09-05 | Close-out (Tier B): live smoke run, 10/10 verdicts recorded (SMOKE PASS, all findings non-blocking — see Live Smoke Results and `decision-log.md` session "5-3 close-out"). Status `review` -> `done`. Board flipped to `done`. | Claude Sonnet 5 (operator-stated) |
