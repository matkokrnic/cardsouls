---
baseline_commit: ce10b96f01a2e55e153b3b0ae7a1b6a8f6330785
---

# Story 5.7: Pad Modes ②③

Status: done

## What this story inherits and supersedes

Measured against the code at HEAD (`ce10b96`), not assumed from the task brief:

1. **The held-L3 pad card scheme (`5-0b`) is unchanged in shape.** `GamepadController.sample()`
   reads raw device state and hands it to the pure `resolve_card_tick()`
   (`src/controllers/gamepad_controller.gd:271-316`); `cast_button` (L3) held enters cast mode,
   `L2/L1/R1/R2` (via `trigger_axis_left`, `block_button`, `attack_button`, `trigger_axis_right`)
   arm hand slots 0-3, and `cast_basic_button` (A, `JOY_BUTTON_A`) commits BASIC in one press. B
   and X are read NOWHERE in `gamepad_controller.gd` today — `resolve_card_tick`'s signature has no
   parameter for either (`:271-280`), a no-op by omission, not a checked branch
   (`5-0b/R4`, decision-log `:8312-8314`).
2. **`Enums.ModeKind` is `{ BASIC, UNBLOCKABLE, DEFENSE, PITCH }`, ordinals 0-3**
   (`src/state/enums.gd:27`). `_resolve_card_action`'s dispatch
   (`src/state/match_state.gd:2347-2372`) already has REAL arms for `UNBLOCKABLE`
   (`_resolve_unblockable_cast`, `:2364`, shipped `5-2`) and `DEFENSE` (`_resolve_defense_cast`,
   `:2370`, shipped `5-5`). The `_` catch-all's `Invariant.check(false, ...)` (`:2372`) guards
   exactly ONE unreached mode: `PITCH` — a deliberate crash-on-reach, not a graceful refusal,
   because `PITCH`'s orb-spend path is E6's. **A commit that ever set `card_mode = PITCH` would
   crash the match.** This story's face-button mapping (AC 1) must leave `PITCH` structurally
   unreachable from the pad, the same way `5-0b` left `UNBLOCKABLE`/`DEFENSE` unreachable before
   their own stories wired them.
3. **The `unblockable` layer flag is already `true` in authored data**
   (`data/feature_flags.tres:7`, flipped by `5-2/R14` on the reasoning "nothing can currently
   produce a mode ② intent at all, so the layer being open changes no live behaviour" — decision-log
   `:8690-8698`). No flag flip is owed by this story; `_resolve_defense_cast` reads the SAME flag
   (`5-5` AC 3). **This story is the layer's first live producer** — see AC 6.
4. **Two temporary keyboard bindings exist, named for THIS story to delete, both confirmed by
   grep and by their own story files:**
   - `p1_cast_unblockable` (`5-3` AC 16/19): Input Map action `project.godot:147-151` (physical
     keycode 70, `F`), read at `src/controllers/keyboard_controller.gd:163-166`
     (`elif InputMap.has_action(_cast_unblockable) and Input.is_action_just_pressed(_cast_unblockable):`),
     backed by the field `_cast_unblockable` (`:67`) and the action-string line
     `_cast_unblockable = _action(prefix, "cast_unblockable")` (`:92`). `5-3-telegraph-
     presentation.md:244-251` names its own removal as "the deletion of one Input Map action and
     one branch in `_sample_card_scheme()`" — that plus its backing field and action-string line is
     the four-part inventory this story owes.
   - `p2_cast_defense` (`5-5` AC 15, moved to physical keycode 59 `;` at AC 15.1 after an `L`/
     `p1_roll` collision): Input Map action `project.godot:182-186`, read at
     `keyboard_controller.gd:160-162`
     (`if InputMap.has_action(_cast_defense) and Input.is_action_just_pressed(_cast_defense):`),
     backed by the field `_cast_defense` (`:77`) and the action-string line
     `_cast_defense = _action(prefix, "cast_defense")` (`:93`). `5-5-unblockable-defense.md:270-273`
     names the SAME four-part inventory explicitly for this action, "alongside `p1_cast_unblockable`
     when the pad scheme lands."
   - Both branches, both fields, both action-string lines, and both Input Map actions are DELETED
     by this story (AC 7). The arm-then-confirm sequence itself (`_sample_card_scheme`'s HOLD/PRESS/
     RELEASE shape) is untouched — only the two now-redundant confirm keys leave.
5. **The `5-0b` X/Y source-scan test is retired, not merely made to still pass.**
   `test/state/test_gamepad_controller.gd:336-349`,
   `test_gamepad_controller_never_reads_x_or_y_face_buttons`, asserts `gamepad_controller.gd`'s
   source text never contains the literal strings `"JOY_BUTTON_X"` or `"JOY_BUTTON_Y"`. Once this
   story wires X to a real mode (AC 1), that literal string may never appear in
   `gamepad_controller.gd` anyway — the raw index lives on `GamepadProfile`, read as
   `_profile.<field>`, the same discipline `cast_basic_button` already established (AC 3's own
   header: "the raw joypad index lives EXACTLY ONCE — as authored data"). So the test could pass by
   accident while asserting something no longer true. Accepted as a known review finding at `5-0b`'s
   own close-out (decision-log `:8316-8318`: "the X/Y source-scan guard catches only the inline-
   literal regression form ... accepted — `5-7` wires those buttons and its tests take over"). This
   story DELETES `test_gamepad_controller_never_reads_x_or_y_face_buttons` and replaces its
   guarantee with real behavioural tests for B and X (AC 1, AC 8) plus a narrower one for the
   remaining no-op face button (AC 2).

## Story

As a player using a gamepad,
I want the two face buttons that already exist for the held-L3 card scheme to confirm an
UNBLOCKABLE cast and a DEFENSE cast, in place of the two temporary keyboard-only keys that stood in
for them,
so that both halves of the RGB read-and-answer exchange (`5-2` chargeup, `5-5` negation) are
playable at all from a pad — the same closure `5-0b` gave Basic-mode casting — before `5-6`'s
three-tier ladder gets its first pad-native exercise.

## Acceptance Criteria

**Face-button assignment (`GamepadProfile`, `GamepadController.resolve_card_tick`)**

1. **While cast mode is held, B commits the armed slot as `UNBLOCKABLE` and X commits it as
   `DEFENSE`, mirroring `cast_basic_button`'s "one press both selects and confirms" shape (`5-0b`
   AC 3) exactly** — there is no separate confirm step, and both are PRESS-edge, not hold. Each is
   an authored `GamepadProfile` field (named on the `cast_basic_button` precedent — the raw joypad
   index lives exactly once, as authored data, never a literal in the controller), defaulted to the
   named engine constants `JOY_BUTTON_B` and `JOY_BUTTON_X`. **This mapping is PROVISIONAL, exactly
   like L3/A were at `5-0b`** (`5-0b/R3`, decision-log `:8308-8310`): the card-mode-select UX
   remains the open, high-P4 GDD question `3-5a` flagged and no story has settled; this story ships
   one more working scheme, not a final one. **Pressing B or X while cast mode is held with no slot
   armed still raises the commit** (`card_slot` carries the unarmed value, `-1`), reaching the
   existing state-side empty-slot refusal rather than being swallowed in the controller — the
   `5-0b` review-fix precedent for Basic (`REASON_EMPTY_SLOT` via `Hand.is_slot_empty`), applied
   identically to both new confirm buttons.
2. **The fourth face button (Y) remains an explicit no-op**, on the same "no-op by omission, not a
   checked branch" discipline `5-0b` used for all three (`5-0b/R4`). `PITCH` (ordinal 3) is E6's
   orb-spend mode and its state path is a deliberate crash-on-reach (see Inherits item 2) — Y
   carries no `GamepadProfile` field and no parameter in `resolve_card_tick`, so it is
   STRUCTURALLY incapable of ever setting `card_mode = PITCH`, the same guarantee that protected
   B/X before this story. State this explicitly as a test, not an absence: a source-scan (or
   equivalent) proves `gamepad_controller.gd` never reads `JOY_BUTTON_Y`, replacing (not merely
   narrowing) the retired test named in Inherits item 5.
3. **Whether B/X's read is a NEW dedicated `GamepadProfile` field or a reuse of an existing one is
   dev's call, with a named constraint either way: it must be an authored field, never a raw
   literal in `gamepad_controller.gd`.** Two precedents already coexist in this file:
   `cast_basic_button` (A) is a field dedicated to the cast-mode meaning, distinct from any
   live-play field, because A carried no prior meaning; `attack_button`/`block_button` (R1/L1) are
   REUSED for slot-arming (`5-0b` AC 2) because those buttons already had an authored field for
   their live-play meaning. B already has a live-play field (`roll_button`, `5-0b` AC 5 suppresses
   it while cast mode is held) with the SAME default physical index (`JOY_BUTTON_B`) either
   approach would use for the new UNBLOCKABLE confirm; X has no existing field. Whichever is
   chosen, `data/gamepad_profile.tres` is updated to match and the inspector shows a name, not a
   magic number (2-2 review D1, restated at `5-0b` AC 1/3).

**Collision, stated explicitly, on the `5-0b` AC 4/AC 5 precedent**

4. **B stops being ONLY a suppressed roll while cast mode is held — it is now the live UNBLOCKABLE
   confirm.** `5-0b` AC 5 already suppresses `roll` while `cast_held`; this story adds a REAL
   consequence to that same button in that same state (previously it suppressed to nothing). The
   roll-escape sequence itself (`5-0b` AC 5: release L3, then press B, fires roll on the very next
   tick) is UNCHANGED — B's new meaning exists only while cast mode is HELD, and the release-then-
   press ordering that protects the roll escape does not read or need to know that B now does
   something during cast mode.
5. **X is newly live, not colliding with anything** — `X` has never been read by
   `GamepadController` before this story (Inherits item 1), so there is no prior live-play meaning
   to suppress or preserve.

**Inherited input contracts (`5-0b` AC 1, AC 4, AC 5, AC 9 — restated as this story's own
obligations, not re-derived)**

6. **The exit-edge rule applies to B and X exactly as it already does to every arming/confirm
   input**: a button already physically held at the moment `cast_button` (L3) releases produces no
   press edge that tick — it must be released and freshly pressed again before it can confirm a
   mode. Held-through-exit for B and X must be covered by the SAME test shape `5-0b` built for the
   existing four inputs (`test_resolve_card_tick_exit_edge_sequences`, extended or sibling), not a
   new, differently-shaped guarantee.
7. **Replug protection covers B and X**: the neutral/no-device path (`gamepad_controller.gd:118-
   127`) primes every card-scheme `_prev_*` entry HELD, not cleared, so a reconnect cannot arm-and-
   commit with no new press (`5-0b`'s review-fix finding, decision-log `:8305-8306`). Whatever
   `_prev_*` tracking B/X's edges use joins that same priming set — a replug must not be able to
   spend a card via UNBLOCKABLE or DEFENSE any more than it can via BASIC today.
8. **Attack/block/roll suppression while `cast_held` is untouched by this story** — B's new
   UNBLOCKABLE meaning exists ONLY inside the already-suppressed cast-mode branch of
   `resolve_card_tick`; it adds no new suppression rule and does not touch A's existing BASIC path.
9. **A same-tick chord across the three confirm buttons (A/B/X) must resolve to AT MOST ONE
   commit, deterministically.** Real hardware cannot press three face buttons in one tick, but
   `5-0b`'s own precedent (`test_resolve_card_tick_same_tick_chord_resolves_rightmost`) pins
   determinism for the unreachable-on-hardware case anyway, because the golden/replay contract
   requires it regardless of reachability. State and test the chosen order explicitly (dev's call
   which of the three wins a triple-press) — do not leave it as whatever the `if`/`elif` order
   happens to produce with no assertion.
10. **The existing four-slot arming chord (L2/L1/R1/R2) and its "resolves rightmost" pin
    (`5-0b` AC 9) are untouched — this story adds no new arming input**, only new CONFIRM inputs
    on the existing arm-then-confirm shape.

**Deletion (`project.godot`, `keyboard_controller.gd`, `test_deck_and_hand.gd`)**

11. **`project.godot` ends this story with EXACTLY two diffs: the `p1_cast_unblockable` and
    `p2_cast_defense` Input Map actions removed, nothing else moved.** Both action blocks
    (`:147-151`, `:182-186`) are deleted whole.
12. **`keyboard_controller.gd` loses both branches, both backing fields, and both action-string
    lines** (Inherits item 4's four-part inventory, times two): the `elif`/`if` arms at `:160-166`
    that read `_cast_defense`/`_cast_unblockable`, the fields `_cast_unblockable` (`:67`) and
    `_cast_defense` (`:77`), and the `_action(prefix, "cast_unblockable"/"cast_defense")` lines
    (`:92-93`). The arm-then-confirm sequence's HOLD/PRESS/RELEASE shape and the surviving
    `_cast_confirm` (BASIC) branch are UNCHANGED.
13. **`test/state/test_deck_and_hand.gd`'s `SHIPPED_INPUT_ACTIONS` (`:478-496`) loses
    `p1_cast_unblockable` and `p2_cast_defense`**, on the file's own stated discipline
    ("an added action fails as loudly as a removed one... the story that ships the consumer is the
    story that moves the list," `:492-493`) applied in reverse — the story that RETIRES the
    consumer moves the list back. The explanatory comments naming these as `5-3`/`5-5` TEMPORARY
    entries for `5-7` to delete (`:449-451`, `:484-494`) are removed along with the entries, not
    left as stale prose. `test_shipped_input_map_action_set_is_exactly_pinned` (`:499-512`) and
    `test_card_scheme_input_actions_ship_for_both_players` (`:452-462`, which never referenced
    either temporary action) both stay green unedited otherwise.
14. **`test_no_physical_key_backs_two_project_actions` (`:529-543`, the permanent guard from `5-5`
    AC 15.1) stays green.** This story adds NO new Input Map action (AC 1's B/X reads are raw
    device buttons via `GamepadProfile`, D3(a) — no `Input.*` named action involved), so it can
    introduce no new physical-key collision; removing two Input Map actions can only shrink the
    action set this guard scans, never create a new collision.

**Intent stream (no new field, `card_mode` no longer hardcoded)**

15. **`GamepadController.sample()`'s hardcoded `intent.card_mode = Enums.ModeKind.BASIC`
    (`gamepad_controller.gd:172`, the site `5-2/R15` named as this story's to fix — decision-log
    `:8711-8714`) is replaced with the mode the fired confirm button actually selected** (BASIC via
    A, UNBLOCKABLE via B, DEFENSE via X) — `card_commit` stays true only when one of the three
    fired. No new `InputIntent` field: `card_slot`/`card_mode`/`card_commit` already exist and
    already carry everything modes ①-③ need (`enums.gd`'s four-member `ModeKind` was sized for
    this at `3-5a`, confirmed unchanged in shipped form by both `5-2` and `5-5`'s own Golden
    Prediction reasoning).
16. **No `src/state/` change, no new `BalanceConfig` field, no new `FeatureFlags` field, no new
    snapshot key.** Scope is `src/controllers/gamepad_controller.gd`,
    `src/controllers/gamepad_profile.gd`, `data/gamepad_profile.tres`, `project.godot`, and
    `src/controllers/keyboard_controller.gd` only (plus the test files named above).

**Golden Prediction — the machine contract**

17. **THE GOLDEN IS UNMOVED, in both directions, measured not assumed.** `test_determinism.gd`
    never instantiates a `Controller` (`5-0b`'s own Golden Prediction argument, restated here
    verbatim because the same fact makes it true again): every touched file in this story lives
    under `src/controllers/` or is `project.godot`/a `.tres`, none of which that fixture reaches.
    `InputIntent`'s card fields are already excluded from `to_snapshot()`
    (`input_intent.gd`'s own header). **`FORMAT_VERSION` STAYS AT 7** — this story adds no new
    `MatchState` injection seam, no new contact kind, and no new `InputIntent` field; it is a
    controller-layer producer of values `UNBLOCKABLE`/`DEFENSE` already accept, the identical shape
    `5-0b` used for BASIC. Measure the hash before and after at the dev pass (the standing Tier B
    discipline, `E4-P/R9`/`E5-P/R5`: "every Tier B prediction is a PREDICTION its own gate confirms
    by measurement, never a lowering") — do not skip the reverse measurement because the reasoning
    looks airtight; `5-0b` ran it anyway.

## Non-Goals (explicit)

- **Module ④ PITCH and any orb-spend path** — E6's, per Inherits item 2; Y stays a structural
  no-op (AC 2).
- **Hold-to-charge Sekiro parity.** This story ships mode ② as a press-edge confirm on the armed
  slot, the same one-press-selects-and-confirms shape every other pad confirm button already has.
  See Deferred below.
- **Card colouring in hand** — open `5-4` smoke finding, no owner yet; unrelated to input.
- **Cast-vs-deflect audio distinguishability** — an audio pass's, not this story's.
- **Any `game-architecture.md` edit** — this story adds no seam; the ARCH AMENDMENT QUEUE flushes
  at E5 close-out, unaffected here.
- **Retuning any authored value** — `defense_window_seconds`, `unblockable_chargeup_seconds`,
  stamina costs, `trigger_threshold`, all untouched.
- **Any new Input Map action.** This story only DELETES two; it introduces none, on D3(a) — B/X
  are raw device reads via `GamepadProfile`, the `5-0b` precedent for the other four card-scheme
  buttons.
- **Retuning or re-deciding the L2/L1/R1/R2 slot-arming order, or the L3/A choices** — all
  untouched, all still provisional exactly as `5-0b` left them.
- **`p1_cast_defense` or `p2_cast_unblockable`** — the keyboard scheme's per-player asymmetry
  (P1 attacks, P2 defends) is a `5-5`-Deferred question about the KEYBOARD scheme specifically,
  moot here since both keyboard confirm keys are deleted, not extended.

## Deferred

- **Hold-to-charge Sekiro parity (`5-3/R6`, homed on this story).** Holding a cast through the
  chargeup rather than a single press-edge confirm would need a cancel path in `HeroState`
  (a `CHARGING` teardown on early release) — a `src/state/` change, outside Tier B scope by the
  golden clause. Disposition: judged on THIS story's live smoke. If the press-edge confirm feels
  wrong, hold-to-charge becomes its own Tier A story after this one closes. **Operator veto open**
  — do not silently decide this either way.
- **Whether B/X reuse an existing `GamepadProfile` field or get dedicated ones (AC 3)** — left to
  the dev pass, both precedents shown, no functional difference either choice makes.

## Live Smoke

**Core (single pad, flip `[0, 3]`, mirroring `5-0b`'s own smoke flip):**

1. **Held-L3, press B**: an UNBLOCKABLE cast fires on an armed slot. **Correction to the task
   brief, measured, not assumed**: this is NOT the first-ever live mode ② chargeup — `5-2/R15`
   ("mode ② has no live producer... the first real playtest of mode ② is at `5-7`," decision-log
   `:8708-8724`) was already discharged two stories early, by `5-3`'s own temporary `p1_cast_unblockable`
   key: `5-3-telegraph-presentation.md:312-314`'s own Live Smoke header states outright, "This
   story's keyboard edge (AC 16) makes THIS the first real playtest of the chargeup and its
   telegraph." What THIS item actually proves, correctly stated, is the first **pad-triggered**
   live mode ② cast — record it as that, not as a first playtest of the mechanic itself.
2. **Held-L3, press X**: a DEFENSE cast fires on an armed slot — card consumed, stamina spent, the
   cast cue plays. (The negation MECHANIC itself was already live-proven at `5-5`'s own smoke; this
   item proves only the new INPUT EDGE reaches it.)
3. **Held-L3, press Y**: nothing happens — no crash, no cast, no state change of any kind.
4. **Suppression regression**: while L3 is held, R1/L1/B do not throw an attack/block/roll; on
   release, all three read live again the very next tick (`5-0b`'s own smoke items, re-run here
   because this story touches the same file).
5. **Both deletions are dead**: pressing `F` produces no effect of any kind (no `p1_cast_unblockable`
   action exists to fire); pressing `;` produces no effect of any kind (no `p2_cast_defense` action
   exists to fire).
6. **FPS** stable throughout.

**Optional, named separately (two pads, flip `[3, 3]`; the `2-2/R4` rule: the i-th GAMEPAD slot
takes the i-th connected joypad):**

7. **The full ③-answers-② exchange, pad-native on both sides**: pad 1 charges UNBLOCKABLE in a
   colour (B), pad 2 casts DEFENSE in the matching colour (X) before it lands — no damage, the
   spark/sting cue fires, visible from both split-screen viewports. This is the first time BOTH
   halves of the exchange have been driven by a pad in the same live pass; run it only if two
   physical pads are available, and record its absence rather than skip it silently if not.

## Live Smoke Results

Transcribed from the operator's `docs/playtest-log.md` entry, 2026-09-07 ("5-7 pad modovi 2/3,
živi smoke, pad, flip [0,3]"):

**Core (single pad) — all six items PASS:**

1. Held-L3, press B — the first PAD-TRIGGERED mode ② UNBLOCKABLE chargeup. PASS.
2. Held-L3, press X — the DEFENSE cast's new input edge. PASS.
3. Held-L3, press Y — no-op, nothing happens. PASS.
4. Suppression regression (attack/block/roll suppressed under L3, live again on release). PASS.
5. Both retired keyboard confirms are dead (`F` and `;` produce no effect). PASS.
6. FPS stable throughout. PASS.

**Optional (two pads, item 7): NOT RUN — no second physical pad was available.** Recorded as an
absence per the smoke plan's own instruction, not silently omitted.

## Open Questions (left to the gate / dev pass)

- **Test file placement**: extend `test/state/test_gamepad_controller.gd` in place (the file
  `5-0b` already built this exact coverage shape in) versus a new sibling file. `5-0b`'s own
  precedent (extend in place) is the likely call; dev's to confirm.
- **AC 9's exact tie-break order** for a same-tick A/B/X triple-press — dev's call, must be pinned
  by an explicit chord test on the `5-0b` `test_resolve_card_tick_same_tick_chord_resolves_rightmost`
  precedent.
- **AC 3's field question** (dedicated vs. reused `GamepadProfile` field for B) — see Deferred.

## Dev Notes

- **This story inherits `5-0b` by name, not by rediscovery**: the entire pure `resolve_card_tick()`
  decision function, its `_prev_held`/`_prev_l2`/`_prev_r2` edge-tracking discipline, the neutral/
  replug-priming path, and the "raw joypad index lives exactly once, as authored data" rule this
  story's new field(s) must also follow.
- **Golden Prediction reasoning is a repeat of `5-0b`'s, not a new argument** — cite it, do not
  re-derive it from scratch in Completion Notes; the underlying facts (no `Controller` in
  `test_determinism.gd`, card fields excluded from `to_snapshot()`) have not changed since `5-0b`
  measured them.
- **Why B/X and not some other face-button assignment**: the task brief's expected mapping
  (B = ②/UNBLOCKABLE, X = ③/DEFENSE, Y stays a no-op) is what this story specs, on the operator's
  stated intent; it is PROVISIONAL exactly as L3/A were (AC 1), not a settled UX decision.
- **Why this story waits for `5-5`, not `5-2`**: `5-7-pad-modes-2-3` is item 12 of 12 in the E5
  story list, ratified as "waits for `5-5`; a mode button for an unresolvable mode is a no-op the
  operator cannot smoke" (decision-log `:8202-8203`). Both `UNBLOCKABLE` and `DEFENSE` needed real
  state arms before either button could do anything observable.

### Project Structure Notes

- `src/controllers/gamepad_profile.gd` — new authored field(s) for the B/X confirm reads (AC 1, 3).
- `data/gamepad_profile.tres` — matching new resource properties.
- `src/controllers/gamepad_controller.gd` — `resolve_card_tick()` gains B/X parameters and their
  edge tracking; `sample()`'s hardcoded `Enums.ModeKind.BASIC` (`:172`) is replaced (AC 15).
- `src/controllers/keyboard_controller.gd` — two branches, two fields, two action-string lines
  deleted (AC 12).
- `project.godot` — two Input Map actions deleted (AC 11).
- `test/state/test_gamepad_controller.gd` — `test_gamepad_controller_never_reads_x_or_y_face_buttons`
  deleted and replaced (AC 2, AC 5); new coverage for AC 6-10.
- `test/state/test_deck_and_hand.gd` — `SHIPPED_INPUT_ACTIONS` loses two entries and their
  explanatory comments (AC 13).
- `src/state/` — UNTOUCHED (AC 16, AC 17).

### Project Context Rules

- **D3(a) — `Input.*` only under `src/controllers/`.** This story's entire diff (two more raw
  device button reads) lands in the one file already authorized for it. [Source:
  docs/project-context.md:55; CLAUDE.md]
- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** Not implicated; no new
  `_physics_process`.
- **D3(b)/A2 — no global RNG/Time/OS/Engine in `src/state/`.** Not implicated; `src/state/` is
  untouched.
- **Data as Resources — no hardcoded gameplay numbers.** The new `GamepadProfile` field(s) are
  authored input-feel data, the same class of field `cast_basic_button` already is — not a
  `BalanceConfig` entry. [Source: docs/project-context.md:62-64]
- Story tier: **Tier B** — HUD/presentation/input-controller only, golden and snapshot key set
  predicted UNMOVED and measured both directions at the gate (the golden clause, `E4-P/R9`/
  `E5-P/R5`). No separate gate pass; lighter skill chain.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8176-8209] —
  `E5-P/R5`, the twelve-story E5 list; item 12 (`:8202-8203`) is this story.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8305-8329] —
  `5-0b/R2-R5`, the replug-priming, slot-mapping, B/X/Y-no-op, and live-smoke rulings this story
  inherits verbatim.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8690-8725] —
  `5-2/R14`/`R15`, the authored `unblockable` flag flip and "mode ② has no live producer... the
  first real playtest of mode ② is at `5-7`" ruling this story's AC 6/Live-Smoke-item-1 discharges.
- [Source: docs/implementation-artifacts/5-0b-pad-card-input.md] — the full held-L3 scheme, its
  ACs, Dev Notes, mutation table, and live smoke record this story extends rather than rebuilds.
- [Source: docs/implementation-artifacts/5-3-telegraph-presentation.md:211-254] — AC 15-20, the
  `p1_cast_unblockable` TEMPORARY key and its own named deletion inventory.
- [Source: docs/implementation-artifacts/5-5-unblockable-defense.md:253-294] — AC 15/15.1, the
  `p2_cast_defense` TEMPORARY key, its keycode-collision fix, and its own four-part deletion
  inventory naming this story by number.
- [Source: src/state/enums.gd:9-27] — `Enums.ModeKind`, the four-member, zero-indexed enum this
  story's mapping must respect.
- [Source: src/state/match_state.gd:2347-2372] — `_resolve_card_action`'s dispatch: `UNBLOCKABLE`
  and `DEFENSE` both real arms, `PITCH` the one remaining guarded stub.
- [Source: src/controllers/gamepad_controller.gd:1-353] — `sample()`, `resolve_card_tick()`, the
  neutral/replug path, and every existing edge-tracking discipline this story extends.
- [Source: src/controllers/gamepad_profile.gd:1-95] — `cast_button`/`cast_basic_button`/
  `trigger_threshold`'s authored-field precedent, AC 1/3's naming discipline.
- [Source: src/controllers/keyboard_controller.gd:1-180] — the arm-then-confirm scheme in full, and
  the two TEMPORARY branches/fields/action-strings this story deletes.
- [Source: project.godot:147-186] — the two Input Map action blocks this story deletes.
- [Source: test/state/test_gamepad_controller.gd:336-349] — the retired X/Y source-scan test.
- [Source: test/state/test_deck_and_hand.gd:444-543] — `SHIPPED_INPUT_ACTIONS`, the pinned-set test,
  and the permanent key-collision guard, all three touched or confirmed green by this story.
- [Source: data/feature_flags.tres:7] — `unblockable = true`, already flipped, no edit owed here.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (repo commit-trailer constant; see project-context.md "Commit trailer").

### Debug Log References

- Suite at OPEN (before any edit), full `test/run_all.sh`: `712 tests, 0 failed, 5291 assertions`
  + 55 integration tests, `ALL TESTS PASSED`.
- Suite at CLOSE, full `test/run_all.sh`: `720 tests, 0 failed, 5363 assertions` + 55 integration
  tests, `ALL TESTS PASSED`. (+8 state tests = 9 added, 1 retired; `PROC/R1` cadence honoured — the
  full suite ran exactly twice, and the four mutation proofs below ran the state harness only.)
- Golden measured explicitly at both ends with an out-of-repo scratchpad script that instantiates
  the shipped `test_determinism.gd` fixture and prints its own `_run()`; see Golden Prediction below.
- Suite re-run after the close-out review fix (LOW-3, comment-only rewrite of the stale
  `p2_cast_defense` prose at `test_deck_and_hand.gd:511-517`): `720 tests, 0 failed, 5363
  assertions` + 55 integration tests, `ALL TESTS PASSED` — identical counts, as expected for a
  comment-only change.

### Completion Notes List

**AC-by-AC coverage**

- **AC 1** — `GamepadProfile.cast_unblockable_button` (`JOY_BUTTON_B`) and `cast_defense_button`
  (`JOY_BUTTON_X`) are read device-filtered in `sample()` and resolved in `resolve_card_tick()` on
  `basic_pressed`'s exact press-edge shape (no hold, no separate confirm). The EXPLICIT NEGATIVE is
  covered: a fresh B or X press with `armed_slot == -1` still raises `card_commit` carrying
  `card_slot == -1`, so the state-side `REASON_EMPTY_SLOT` refusal is reached rather than swallowed
  (`test_resolve_card_tick_mode_confirms_commit_empty_slot_rather_than_swallow`). Behaviour proven
  by `test_resolve_card_tick_b_commits_unblockable_and_x_commits_defense`.
- **AC 2** — Y remains a no-op BY OMISSION: no `GamepadProfile` field, no `resolve_card_tick`
  parameter, no read in `gamepad_controller.gd`. The retired 5-0b source-scan is REPLACED, not
  narrowed, by `test_no_authored_button_maps_to_y_so_pitch_is_structurally_unreachable`, which
  proves the property BY CONSTRUCTION (`3-0d/R20`): the controller reads buttons through exactly
  one route, `_profile.<x>_button`, so if no authored button field on either the defaults or the
  shipped `.tres` equals `JOY_BUTTON_Y`, a read of Y is not expressible and `card_mode` can never
  become `PITCH`. The old inline-literal scan is kept as a cheap second net, narrowed to Y. A
  vacuity guard asserts the field scan really found >= 8 button fields.
- **AC 3** — DEDICATED fields (dev call, recorded below).
- **AC 4** — B's new meaning lives only inside the `cast_held` branch;
  `test_mode_confirms_do_nothing_outside_cast_mode` pins that with B physically down the tick after
  release: no commit, and `roll_pressed` fires — the 5-0b roll escape unchanged.
- **AC 5** — X had no prior field or read (verified by grep before the edit); nothing to suppress
  or preserve. Covered incidentally by the same tests as AC 1.
- **AC 6** — `test_mode_confirm_exit_edge_sequences`, the SAME shape as
  `test_resolve_card_tick_exit_edge_sequences`: held-through-entry, held-through-exit-and-re-entry,
  and release-then-fresh-press, run over both buttons.
- **AC 7** — both new `_prev_held` keys join the neutral/no-device priming set (primed HELD, not
  cleared). `test_replug_priming_covers_the_new_commit_edges` drives the real `sample()` neutral
  path (reachable headless — the harness has no joypad), reads the primed values back, and feeds
  them into the decision to show a replug with L3 + every confirm button down commits nothing.
- **AC 8** — no suppression rule added or changed;
  `test_mode_confirms_add_no_suppression_rule` asserts attack/block/roll are still all suppressed
  on the very tick a B press commits mode ②, and A's BASIC path is asserted unchanged in AC 1's test.
- **AC 9** — tie-break chosen and pinned (dev call, recorded below).
- **AC 10** — no arming input added; `test_arming_chord_is_untouched_by_the_new_confirm_buttons`
  re-runs 5-0b's four-input chord with B and X ALSO down and still gets slot 3.
- **AC 11** — `project.godot` diff is exactly two deletions, both action blocks whole, nothing else
  moved (verified on the diff).
- **AC 12** — `keyboard_controller.gd` lost both branches, both fields (`_cast_unblockable`,
  `_cast_defense`), and both `_action(prefix, ...)` lines, plus the now-stale prose that named them.
  The HOLD/PRESS/RELEASE sequence and the surviving `_cast_confirm` BASIC branch are unchanged.
- **AC 13** — `SHIPPED_INPUT_ACTIONS` lost both entries and their explanatory comments; the two
  neighbouring tests stay green unedited.
- **AC 14** — `test_no_physical_key_backs_two_project_actions` green; this story adds no Input Map
  action, and the set only shrank.
- **AC 15** — `sample()`'s hardcoded `Enums.ModeKind.BASIC` is gone; `card_mode` is now returned by
  `resolve_card_tick()` and written from `result["card_mode"]`. No new `InputIntent` field.
- **AC 16** — `src/state/` untouched; no new `BalanceConfig`/`FeatureFlags` field, no snapshot key.
  Touched files are exactly the seven named in Project Structure Notes.
- **AC 17** — see Golden Prediction below.

**THE THREE OPEN DEV CALLS**

1. **AC 3 — DEDICATED `GamepadProfile` fields for B and X**, not a reuse of `roll_button`.
   Reasoning: `cast_basic_button` is the precedent that fits — a field carrying the CAST-MODE
   meaning, distinct from any live-play field. `roll_button` and `cast_unblockable_button` happen to
   default to the same physical `JOY_BUTTON_B` today, but the two meanings are independent:
   re-authoring the dodge button must move the dodge and NOT silently move the UNBLOCKABLE confirm
   with it, which a reused field cannot express. It also keeps B and X symmetrical — X has no
   live-play field to reuse at all, so one dedicated field each is the only shape that reads the
   same on both. Cost: one extra `.tres` property whose default duplicates `roll_button`'s index.
   The `attack_button`/`block_button` reuse precedent was rejected because those buttons are reused
   for ARMING (a different question), whereas this is a second, independent MEANING for the same
   button in a different mode.
2. **AC 9 — the confirm chord resolves to the PHYSICAL RIGHTMOST face button: B / UNBLOCKABLE.**
   The three confirms are checked in face-cluster left-to-right order (X, A, B) with last-write-
   wins, which is the SAME rule AC 2's four-slot arming chord already resolves by — one rule stated
   once and applied to both chords, rather than a second differently-shaped tie-break someone must
   remember separately. At most one commit can leave BY CONSTRUCTION (`card_commit` is one bool,
   `card_mode` one value), so the branch order decides WHICH, never HOW MANY. Pinned by
   `test_resolve_card_tick_same_tick_confirm_chord_resolves_rightmost` on the 5-0b chord-test
   precedent, at the triple AND at all three pairs so the order is fixed at every edge.
3. **Test placement — extended `test/state/test_gamepad_controller.gd` IN PLACE.** 5-0b's own
   precedent, and AC 6 explicitly asks for the SAME test shape as the existing exit-edge coverage
   rather than a new, differently-shaped guarantee — which a sibling file would quietly become
   (the pure `resolve_card_tick()` contract and its `_profile()` fixture both already live here).
   The 9 new tests sit under their own banner comment beneath the 5-0b block.

**MUTATION PROOFS** (state harness only, per `PROC/R1`; each file backed up to the out-of-repo
scratchpad with a SHA256 taken BEFORE the mutation and restored by copying back, never
`git checkout` — decision-log:799):

| # | Mutation | Result |
|---|---|---|
| M1 | `cast_defense_button` default flipped to `JOY_BUTTON_Y` | RED — `..._pitch_is_structurally_unreachable` (defaults arm) |
| M1b | authored `.tres` `cast_defense_button = 3` (Y) | RED — same test (`.tres` arm; the two arms bite independently) |
| M2 | the three confirm blocks reordered so X is the last write | RED — `..._same_tick_confirm_chord_resolves_rightmost` |
| M3 | the two new `_prev_held` primes dropped from the neutral path | RED — `test_replug_priming_covers_the_new_commit_edges` |
| M4 | both new modes collapsed back to `BASIC` (the AC 15 regression) | RED — 5 tests |

All four restored and re-verified by SHA256 before the closing suite run.

**GOLDEN PREDICTION — MEASURED, BOTH DIRECTIONS (AC 17)**

- BEFORE (clean tree at `805a392`): `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d`, `RecordFile.FORMAT_VERSION == 7`.
- AFTER (all changes in the working tree): `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d`, `RecordFile.FORMAT_VERSION == 7`.
- UNMOVED, as predicted. The reasoning is `5-0b`'s, cited not re-derived: `test_determinism.gd`
  never instantiates a `Controller`, and `InputIntent`'s card fields are excluded from
  `to_snapshot()`. Both measurements were taken with a scratchpad script OUTSIDE the repo that
  instantiates the shipped fixture and prints its own `_run()` — an explicit number, not "the test
  was green".

**Deviations from the skill / operator instruction**

- `python3` is not on PATH on this machine, so `resolve_customization.py` could not run; the
  `workflow` block was resolved by hand from `customize.toml` + `_bmad/custom/gds-dev-story.toml`
  per the documented merge rules (the only non-default value is `on_complete`).
- The story file carries NO Tasks/Subtasks section, so the skill's Step 5/8 checkbox loop had no
  checkboxes to drive; the ACs were used as the task list instead.
- Per the operator's explicit instruction, Step 9's Status write was NOT performed: **Status stays
  `ready-for-dev`** (the review flips it), `sprint-status.yaml` is untouched, and nothing was
  committed — every change is in the working tree. The `on_complete` override is therefore moot
  this run (there is no `review` write to undo).
- No code review was run or spawned; that happens in a fresh session.

**Live Smoke — NOT RUN.** All six core items and the optional two-pad item 7 need a physical pad
and are the operator's. Item 1's correction stands as the story states it: this proves the first
PAD-TRIGGERED mode ② cast, not the first playtest of the mechanic.

### File List

- `src/controllers/gamepad_profile.gd` — modified (two new authored fields; `cast_basic_button`'s
  stale B/X/Y note corrected).
- `data/gamepad_profile.tres` — modified (`cast_unblockable_button = 1`, `cast_defense_button = 2`).
- `src/controllers/gamepad_controller.gd` — modified (two `_prev_held` key constants, two raw reads,
  two `resolve_card_tick` parameter pairs, the confirm tie-break, the returned `card_mode`, replug
  priming).
- `src/controllers/keyboard_controller.gd` — modified (two branches, two fields, two action-string
  lines and their prose deleted).
- `project.godot` — modified (exactly two Input Map actions deleted).
- `test/state/test_gamepad_controller.gd` — modified (1 test retired, 9 added, existing
  `resolve_card_tick` call sites widened by the two new parameter pairs).
- `test/state/test_deck_and_hand.gd` — modified (`SHIPPED_INPUT_ACTIONS` loses two entries and their
  explanatory comments).
