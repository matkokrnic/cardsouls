---
baseline_commit: 01daf8526088a8c6a232927b997f82ce9c12511d
---

# Story 5.0b: Pad card input

Status: ready-for-dev

## What this story inherits

`E5-P/R5` (decision-log Session 2026-09-01 "E5 planning", `:8176-8209`) ratifies this as the
SECOND of twelve E5 stories, Tier B: "the held-L3 scheme, `3-5a` Dev Notes; the two button
collisions — shoulders already attack/block, face buttons vs roll=B — enter its acceptance
criteria explicitly." `epics.md:173-176` locks the board order: `5-0a` and `5-0b` must both land
before the playtest block.

**Motivating gap**, named at `3-5a`'s own authoring (`3-5a-card-mode-select-basic-resolution.md`,
Dev Notes "Gamepad half deferred" and "Gamepad card input is keyboard-unreachable's mirror, and
the asymmetry is standing"): `InputIntent` already carries the three card fields
(`card_slot`, `card_mode`, `card_commit`, `src/state/input/input_intent.gd:44-56`) and
`KeyboardController` already implements one provisional mode-select scheme
(`src/controllers/keyboard_controller.gd:29-113`), but `GamepadController` has never read a card
action of any kind — it reads only `attack`/`block`/`roll` plus the `4-6` lock-on right-stick
controls (`src/controllers/gamepad_controller.gd`). A pad player today cannot cast a card at all.
This story closes that gap for Basic mode, on the operator's stated pad layout intent
(`3-5a` Dev Notes, "Input shape the operator intends (INTENT, not a binding contract)").

## Story

As a player using a gamepad,
I want to hold a modifier button to enter card-select mode, pick one of my four hand cards with
the shoulder buttons, and confirm a cast with a face button,
so that I can play Basic-mode cards from a pad without needing a keyboard, using the same
InputIntent contract the keyboard scheme already produces.

## Acceptance Criteria

1. **Held-L3 modality, mirroring the keyboard scheme's shape.** `GamepadProfile` gains a new
   authored `cast_button: JoyButton` field, defaulted to `JOY_BUTTON_LEFT_STICK` (L3), on the
   same "typed with the engine enum, named-constant default" discipline every existing profile
   field already follows (`src/controllers/gamepad_profile.gd`, 2-2 review D1). While `cast_button`
   is held, `GamepadController` is in cast mode: L1/L2/R1/R2 select a hand slot and A/B/X/Y choose
   a cast mode (AC 3). **Releasing `cast_button` exits cast mode immediately** — the same tick,
   with no released-edge delay — and clears any armed slot, on the `KeyboardController`
   `_sample_card_scheme` precedent (`if not Input.is_action_pressed(_cast_mode): _armed_slot = -1;
   return`). This is the operator's stated reason: "the escape into a roll costs no extra press"
   (`3-5a` Dev Notes).
2. **Card slot selection: L2/L1/R1/R2, ordered left-to-right (physical) to the four hand slots.**
   While cast mode is held, pressing L2, L1, R1, or R2 arms hand slot 0, 1, 2, or 3 respectively —
   this is the physical left-to-right order of the four buttons, matching the HUD card row (L2 and
   R2 are analog triggers, not digital `JoyButton`s in Godot's mapping — `GamepadProfile` gains a
   `trigger_threshold: float` field, defaulted `0.5`, the same "must be CROSSED, not merely held
   past" edge discipline `flick_threshold` already uses for the right stick, so a held trigger
   arms its slot once, not once per tick). The armed slot is exposed through `armed_slot()`
   (`GamepadController` overrides the `Controller` base's `-1` default, on the
   `KeyboardController` precedent) for the existing 3-5a HUD selection indicator — no new seam.
   **This ordering (L2/L1/R1/R2 left-to-right) is a PROVISIONAL scheme, not a settled one** — the
   card-mode-select UX remains the open, high-P4 GDD question `3-5a` already flagged; this story
   ships one working scheme so a pad can be smoke-tested at all.
3. **Cast mode selection and confirm: A/B/X/Y, one press.** Per the operator's fixed pad-input
   ruling (`3-5a` Dev Notes, reconciled with `4-6` lock-on), A/B/X/Y choose the cast mode, and
   that same press is simultaneously the confirmation — there is no separate confirm button on
   the pad (unlike the keyboard's distinct `cast_confirm` key). **Only Basic mode is live this
   story.** `GamepadProfile` gains a `cast_basic_button: JoyButton` field, defaulted
   `JOY_BUTTON_A`, naming which face button carries Basic. Pressing it while cast mode is held and
   a slot is armed sets `intent.card_mode = Enums.ModeKind.BASIC` and `intent.card_commit = true`
   for that tick (a commit with no armed slot still reaches state and is refused there —
   `empty_slot`, unchanged from `3-5a`, never swallowed in the controller). **B, X, and Y are
   explicit no-ops this story** — pressing them arms nothing and commits nothing. This is not an
   oversight: `MatchState._resolve_card_action`'s branches for `UNBLOCKABLE`/`DEFENSE`/`PITCH` are
   `Invariant.check` FAILURES (a deliberate crash guarding unreachable code, `3-5a` AC 2/AC 9),
   not a graceful rejection, so a controller that ever emitted one of those modes with
   `card_commit = true` would crash the match. B/X/Y's eventual mode assignment
   (`UNBLOCKABLE`/`DEFENSE` at `5-7-pad-modes-2-3`, `PITCH` at the E6 close-out story per
   `epics.md:143-186`) is each future story's own wiring to add, exactly as the keyboard scheme
   binds no mode key today (`keyboard_controller.gd`: "NO MODE KEY IS BOUND, deliberately...
   arrives with the modes themselves in E5" — read now as "arrives with each mode's own story").
4. **Collision (1), stated explicitly: L1/R1 stop being attack/block while cast mode is held.**
   `attack_button` (R1) and `block_button` (L1) are unchanged as the live-play bindings — but
   while `cast_button` is held, those same two physical buttons are reassigned to card-slot
   selection (AC 2) and `GamepadController.sample()` MUST NOT also emit `attack`/`block`
   press/held edges for them that tick: holding L3 and tapping R1 arms a card slot, it does not
   also throw an attack. **On `cast_button` release, attack/block read normally again the very
   next tick** — no residual suppression, no missed edge carried over (verify: releasing L3 and
   immediately pressing R1 the next tick registers as a fresh attack press, not a no-op left over
   from the suppressed state). **A button already physically held at the moment `cast_button`
   releases produces no press edge on exit** — it must be released and freshly pressed before it
   reads live-play again: holding L3+R1 to arm a slot, then releasing L3 while R1 stays held, MUST
   NOT fire an attack from the still-held R1 (same rule for a still-held B and roll, AC 5).
5. **Collision (2), stated explicitly: B stops being roll while cast mode is held.** `roll_button`
   (B) is unchanged as the live-play binding — but while `cast_button` is held, B is the (inert,
   per AC 3) mode-select button, and `GamepadController.sample()` MUST NOT emit a `roll` press
   while cast mode is active. Because AC 1 requires `cast_button` release to exit cast mode on
   the SAME tick, releasing L3 and pressing B (even in the same input frame, release-then-press)
   is what preserves the player's roll escape — the release edge must be honoured before B is
   read as a mode button that tick, never after.
6. **R3 lock-on is untouched.** Entering or leaving cast mode does not read, clear, or otherwise
   disturb `_lock_pressed`, `_flick`, or `_prev_flick_magnitude` (the `4-6` right-stick state);
   `relock_pressed()` and `retarget_flick()` behave identically whether cast mode is held or not.
   The two features are orthogonal: `4-6`'s lock-on lives on the right stick and R3; this story's
   scheme lives on the left-stick click, shoulders, triggers, and face buttons, and neither
   sampling path reads the other's state.
7. **No `src/state/` change, no new snapshot field.** `InputIntent.card_slot` /
   `card_mode` / `card_commit` already exist (`3-5a` AC 1) and are excluded from
   `to_snapshot()`; this story adds no field to any state file and no new `BalanceConfig` entry.
   Scope is `src/controllers/gamepad_controller.gd`, `src/controllers/gamepad_profile.gd`, and
   `data/gamepad_profile.tres` only.
8. **Golden unmoved, measured both directions.** `test/state/test_determinism.gd` drives
   `MatchState` directly with in-test intents and never instantiates a `Controller` — this
   story's entire diff is unreachable from that fixture. Predicted UNMOVED, to be MEASURED before
   and after at the dev pass, not asserted from this reasoning alone (the standing Tier B
   discipline, `E4-P/R9`, restated at `E5-P/R5`: "every Tier B [prediction] is a PREDICTION its
   own gate confirms by measurement, never a lowering").
9. **Headless test coverage for every collision and edge named above**, on the
   `test_gamepad_controller.gd` precedent (pure functions where possible, an injected/fake device
   index where not): cast-mode entry/exit on the `cast_button` held/released edge; slot arming
   for all four shoulder/trigger inputs including the trigger-crossing-not-holding edge case;
   Basic-button commit only when a slot is armed, and its refusal (via `action_rejected`, unchanged
   downstream) when none is; B/X/Y proven to be true no-ops (no `card_mode` change, no
   `card_commit`) while cast mode is held; attack/block/roll suppressed while cast mode is held
   and restored the tick after release; a button already held through `cast_button`'s release
   produces no press edge that tick (held-through-exit case), while a fresh press the tick after
   release does register normally; lock-on state proven untouched by cast-mode entry/exit.

## Non-Goals (explicit)

- **Modes ②/③/④.** `UNBLOCKABLE` and `DEFENSE` are `5-7-pad-modes-2-3`'s; `PITCH` is the E6
  close-out story's. This story wires no state-reaching path for any of the three.
- **Any change to card resolution, economy, or `src/state/`.** `InputIntent`'s card fields
  already exist (`3-5a`); this story is a controller-side producer of values that field already
  accepts, nothing more.
- **Keyboard card input.** Already shipped (`3-5a`); untouched here.
- **Retuning any existing balance value.** No `BalanceConfig` field is authored or edited.
- **Minions, scenes, or any presentation/HUD change.** `armed_slot()`'s existing consumer (the
  3-5a card-row selection indicator) already reads any `Controller`, including `GamepadController`
  once it overrides the base's `-1` — no HUD-side edit is needed or made.
- **Exact angle/threshold tuning feel.** `trigger_threshold`'s default (0.5) and the L2/L1/R1/R2
  slot ordering are untuned, provisional authored values, on the same "adoption needs a working
  scheme, not a tuned one" precedent `5-0a` used for its angle bands — a future retune pass may
  revisit either.

## Tasks / Subtasks

- [ ] Add `cast_button`, `cast_basic_button`, and `trigger_threshold` fields to `GamepadProfile`
      with named-constant defaults (`JOY_BUTTON_LEFT_STICK`, `JOY_BUTTON_A`, `0.5`); update
      `data/gamepad_profile.tres` to match (AC: 1, 2, 3)
- [ ] Implement cast-mode detection in `GamepadController.sample()` (held edge on `cast_button`,
      mirroring the `_prev_held` dictionary discipline already used for attack/block/roll) (AC: 1)
- [ ] Implement card-slot arming for L1/L2/R1/R2, including the trigger-crossing edge for L2/R2
      analogous to `resolve_flick`'s threshold-crossing policy as a pure, testable function
      (AC: 2)
- [ ] Implement the A/B/X/Y read: A commits Basic when a slot is armed; B/X/Y read as no-ops
      (AC: 3)
- [ ] Suppress attack/block emission while cast mode is held (L1/R1 reassigned); restore on
      release with no stale edge (AC: 4)
- [ ] Suppress roll emission while cast mode is held (B reassigned); confirm release-then-press
      ordering honours the roll escape (AC: 5)
- [ ] Override `GamepadController.armed_slot()` to return the live-armed slot (base default `-1`
      otherwise) (AC: 2)
- [ ] Confirm by reading (no code change expected) that `_sample_lock_controls()` and cast-mode
      sampling touch disjoint fields; add the negative-interaction test (AC: 6)
- [ ] Extend `test_gamepad_controller.gd` with the full AC 9 coverage list (AC: 9)
- [ ] Measure the golden before/after; confirm the hash unmoved (AC: 8)
- [ ] Run `bash test/run_all.sh`; confirm the D3(a) `Input.*`-only-in-controllers invariant and
      the `test_card_scheme_only_in_controllers` guard both still pass unmodified (AC: 7)

## Dev Notes

- **This story inherits two prior stories by name, not by rediscovery**: `3-5a-card-mode-select-
  basic-resolution` (the `InputIntent` card fields, the arm-then-confirm scheme shape, the
  `armed_slot()` seam, and the explicit "gamepad half deferred" gap this story closes) and
  `4-6-camera-lock-on` (the right-stick R3/flick scheme this story must not disturb, and the
  `_prev_held`-style edge-tracking pattern this story's cast-button and trigger edges reuse).
- **Golden Prediction reasoning, stated rather than assumed.** This story touches only
  `src/controllers/` and `data/gamepad_profile.tres`; `InputIntent`'s card fields are already
  excluded from `to_snapshot()` (`input_intent.gd`'s own header: "deliberately excluded from the
  to_snapshot() determinism contract"), and `test_determinism.gd` never instantiates a
  `Controller` at all. Predicted UNMOVED, to be MEASURED in both directions at the dev pass, not
  asserted from this reasoning alone — the standing Tier B discipline (`E4-P/R9`; `E5-P/R5`).
- **Why B/X/Y are no-ops rather than "select the mode but never commit."** An earlier reading
  considered letting B/X/Y arm a visible (but uncommittable) mode selection, so the scheme's full
  shape would already be visually present. Rejected: there is no mode-selection HUD element today
  (3-5a AC 10 covers only the armed SLOT indicator), so a locally-armed-but-invisible mode would
  be a piece of controller state with no player-facing meaning yet — complexity with no payoff
  before `5-7`/E6 actually need it. True no-ops keep the diff to exactly what AC 3 requires.
- **Why the commit button is named `cast_basic_button` rather than hardcoding `JOY_BUTTON_A`
  inline.** Same reasoning `GamepadProfile`'s header already states for every other field: the
  raw joypad index lives exactly once, as authored data, and the inspector shows a name instead
  of a magic number (2-2 review D1). `5-7` will add three siblings the same way, not touch this
  field.
- **The L2/R2-as-buttons subtlety.** Godot's `JoyButton` enum has no dedicated trigger entries;
  L2/R2 are read as axes (`JOY_AXIS_TRIGGER_LEFT`/`JOY_AXIS_TRIGGER_RIGHT`) the same family as
  the right-stick axes `GamepadController` already reads for lock-on. `trigger_threshold`
  reuses `resolve_flick`'s "must be CROSSED this tick, having been below it last tick" edge
  policy so a held trigger arms its slot once, not every tick it stays pulled.
- **Exact button-to-slot / button-to-mode assignment is PROVISIONAL, restated from AC 2/3.** The
  card-mode-select UX is still the open, high-P4 GDD question `3-5a` flagged and did not resolve;
  this story's job is a working, smoke-testable scheme, not a final one.

### Project Structure Notes

- `src/controllers/gamepad_profile.gd` — three new `@export` fields (`cast_button`,
  `cast_basic_button`, `trigger_threshold`), same authored-data discipline as every existing
  field on this resource.
- `data/gamepad_profile.tres` — three new resource properties matching the fields above.
- `src/controllers/gamepad_controller.gd` — `sample()` gains cast-mode detection and the
  attack/block/roll suppression it forces; a new private helper (mirroring
  `_sample_lock_controls()`'s extraction) samples the card scheme; `armed_slot()` is overridden
  (base returns `-1`).
- `src/state/` — UNTOUCHED, byte-identical (Golden Prediction, Non-Goals). `InputIntent` itself
  is not edited; its card fields already exist.
- `test/state/test_gamepad_controller.gd` — extended with the AC 9 coverage list.

### Project Context Rules

- **D3(a) — `Input.*` only under `src/controllers/`.** This story's entire diff (device button
  and axis reads for the cast modifier, four card-select inputs, and four face buttons) lands in
  `gamepad_controller.gd`, the file already authorized for this. [Source:
  docs/project-context.md:55; CLAUDE.md]
- **`test_card_scheme_only_in_controllers` (3-5a AC 1).** The guard scans for keyboard-scheme
  Input Map action-name tokens (`cast_mode`, `cast_confirm`, `card_1`..`card_4`) outside
  `src/controllers/`. `GamepadController` reads raw device buttons/axes, never named Input Map
  actions, so it introduces none of those tokens and needs no guard update — confirm the suite
  still passes rather than editing the guard. [Source: test/state/test_architecture_invariants.gd:496-513]
- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** This story adds none; it changes
  only what `GamepadController.sample()` returns, called from the runner's existing per-tick
  controller-sampling step. [Source: docs/project-context.md:39; CLAUDE.md]
- **Data as Resources — no hardcoded gameplay numbers.** The three new profile fields are
  authored data on the existing load-once `GamepadProfile`, the same field the deadzone and
  `flick_threshold` already live on — not a `BalanceConfig` entry (input feel, not gameplay
  balance, per `GamepadProfile`'s own header). [Source: docs/project-context.md:62-64;
  src/controllers/gamepad_profile.gd]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8176-8209 —
  `E5-P/R5`, the E5 story list ratifying `5-0b` as story 2 of 12, Tier B, naming the two
  collisions]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:173-176 — E5 Committed
  obligations, the four Tier B opening stories and the "must land before the playtest block" order]
- [Source: docs/implementation-artifacts/3-5a-card-mode-select-basic-resolution.md — the
  `InputIntent` card fields (AC 1), the keyboard mode-select scheme precedent, the "gamepad half
  deferred" Dev Notes item this story closes]
- [Source: src/state/input/input_intent.gd:44-56 — the existing `card_slot`/`card_mode`/
  `card_commit` fields, unmodified by this story]
- [Source: src/controllers/gamepad_controller.gd — the existing attack/block/roll and `4-6`
  lock-on sampling this story extends without disturbing]
- [Source: src/controllers/gamepad_profile.gd; data/gamepad_profile.tres — the existing
  authored-mapping resource this story adds three fields to]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
