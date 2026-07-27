# Story 2.2: Gamepad controller and P1/P2 input profiles

Status: ready-for-dev

## Story

As a player,
I want a gamepad controller that emits the identical `InputIntent` shape as the keyboard, with named P1/P2 action sets,
so that a gamepad drives either slot indistinguishably downstream — the equivalence that makes E7's bot a config swap.

## Acceptance Criteria

1. The gamepad binding for every E1 action — move, attack, block, roll — is authored in the profile resource (2-2/R2), one entry per action. No `project.godot` edit is in scope for 2-2: the gamepad controller does not read named Input Map actions, so no Input Map action set is authored for it. One controller class total, never a second class per player or per slot.
2. `gamepad_controller.gd` is the second `Controller` implementation. It reads DEVICE-FILTERED joypad state directly — `Input.get_joy_axis(device, axis)`, `Input.is_joy_button_pressed(device, button)` — inside `src/controllers/` only (D3(a) holds). Button/axis mapping and the deadzone are AUTHORED DATA in a single load-once, controller-owned profile resource (named in Dev Notes / File List) — no raw joypad constants scattered inline, no `BalanceConfig` entry. Above the deadzone, the stick vector is NORMALIZED to unit length before being assigned to `move_dir` (2-2/R5) — a partial stick deflection does not produce fractional-speed movement. It emits the identical `InputIntent` shape — the runner cannot tell it apart from keyboard.
3. Device assignment and disconnect behaviour:
   - (a) The single dev-machine pad drives whichever slot it is assigned to. Proven live by running BOTH smoke flips (pad on slot 0, pad on slot 1 — see Live Smoke).
   - (b) With no pad connected, the controller emits a neutral intent and the match does not crash and does not pause. The NEVER-CONNECTED case (no pad present at construction) IS headless-testable: `Input.get_connected_joypads()` is already empty in the harness. The RUNTIME-DISCONNECT case (a pad vanishing mid-match after its device index was already assigned) is a different path and is NOT headless-testable — it is proven live (see Live Smoke).
   - (c) Simultaneous two-device isolation (two pads driving two slots at once) is DEFERRED VERIFICATION — unverifiable on the dev machine, which has exactly one physical pad. Recorded explicitly here, not silently dropped.
   This logic lives in the controller, never in the runner or state. Device index is derived from `Input.get_connected_joypads()` at construction.
4. The D3 invariant holds after adding the implementation: `grep -rn "Input\." src/` matches only under `src/controllers/`, and the architecture invariant test still passes unmodified.
5. An integration test proves an analog-shaped intent and the equivalent keyboard intent produce byte-identical `HeroState` snapshots over N ticks — the source-agnostic `advance()` contract. The hardware-to-intent mapping itself (joypad axes → `move_dir`, buttons → actions) is verified in the Live Smoke, not headlessly — joypad axes are not headless-samplable.
6. A guard test pins `match_runner.gd`'s `ControllerKind` ordinals: `KEYBOARD_P1==0`, `KEYBOARD_P2==1`, `NULL==2`, `GAMEPAD==3` — `GAMEPAD` is appended so `NULL` stays ordinal 2. Reason: int-literal callers depend on these ordinals (`test_camera_relative.gd` uses `[0, 1]`; every smoke flip writes int literals), and that dependency is currently unwritten — a future reorder would silently change the default that ships.

## Tasks / Subtasks

- [ ] Author the gamepad binding profile resource — one entry per E1 action (move, attack, block, roll) plus the deadzone — as a single load-once, controller-owned resource; no `project.godot` edit (AC: 1, 2)
- [ ] Implement `gamepad_controller.gd`: device-filtered joypad reads (`Input.get_joy_axis`, `Input.is_joy_button_pressed`), profile-driven mapping, deadzone + unit-length stick normalization; emits the identical `InputIntent` shape (AC: 2)
- [ ] Derive device index from `Input.get_connected_joypads()` at construction; neutral intent through the same path as disconnect when no pad is present (AC: 3b)
- [ ] Append `GAMEPAD` to `match_runner.gd`'s `ControllerKind` enum (after `NULL`) and extend `_make_controller()` with the `GAMEPAD` arm — the sanctioned single config-point edit outside `src/controllers/` (AC: 6)
- [ ] Add the `ControllerKind` ordinal guard test (AC: 6)
- [ ] Confirm the D3 grep + invariant test unchanged (AC: 4)
- [ ] Integration test: analog-shaped intent vs. equivalent keyboard intent → byte-identical `HeroState` over N ticks (AC: 5)
- [ ] Live smoke: pad on slot 0, then pad on slot 1 (AC: 3a) — pending operator live smoke
- [ ] Live smoke: unplug the pad mid-match and confirm the slot goes neutral with no crash/pause, then replug and confirm control returns (AC: 3b) — pending operator live smoke
- [ ] Record simultaneous two-device isolation as deferred verification in the Dev Agent Record (AC: 3c)

## Golden Prediction

**NONE** — 2-2 is controller-layer plus one runner config-point edit (the `GAMEPAD` `ControllerKind` arm, 2-2/R4); no `HeroState` snapshot field is added and `advance()` ordering is unchanged. Analog `move_dir` already traverses `_resolve_movement` (magnitude clamp `if dir.length() > 1.0`, `match_state.gd`), pinned by `test_analog_input_clamped_to_move_speed` (`test/state/test_match_state.gd`). Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` is MEASURED in BOTH directions at dev pass — run the determinism test BEFORE the first edit and AFTER the last. A NO-MOVE prediction is confirmed only by an equal hash from an actual run, never by absence of failure (the cause-(c) lesson, paid twice). Any movement is stop-and-report, never a re-baseline. Precedents: 1-6, 1-7b, 1-10, 2-1.

## Live Smoke

`Input.*` joypad reads (`Input.get_joy_axis`, `Input.is_joy_button_pressed`) are headless-blind — `Input.get_connected_joypads()` is empty in the harness regardless of hardware — so the hardware-to-intent mapping and 360-degree stick-to-facing behavior can only be confirmed live, never by the state harness or an integration test.

- **Hardware precondition.** Logitech F310, **X (XInput) mode — the switch on the back of the pad must be set to X**, verified before the smoke begins and recorded in the smoke result. The profile resource is authored against the SDL/Godot standard `JOY_BUTTON_*` / `JOY_AXIS_*` mapping, which holds only in X mode; in D (DirectInput) mode the same physical button reports a different index and the profile is silently wrong — a mapping failure that looks like a profile bug. `Input.get_joy_name(device)` is logged at controller construction so the smoke record names the device it actually bound to.
- **R-D6 NOT re-invoked.** Both smoke flips below run the gamepad against a NULL dummy — no killable human slot is involved. R-D6 remains SPENT (consumed at 2-1) and available to story 2-3, which genuinely needs it (permanent `KEYBOARD_P2` flip plus the DEAD-slot residuals fix).
- **Flip 1 — pad on slot 0.** `slot_controller_kinds = Array[int]([3, 2])` — gamepad slot 0 vs. NULL dummy slot 1. Confirms the dev-machine pad drives P1: stick `move_dir` tracks the physical stick through 360 degrees, buttons map to attack/block/roll per the profile resource.
- **Flip 2 — pad on slot 1.** `slot_controller_kinds = Array[int]([2, 3])` — NULL dummy slot 0, gamepad slot 1. Confirms the same pad drives P2 when assigned there — the live proof for AC3(a) that the device index comes from `Input.get_connected_joypads()`, NOT from the slot index.
- **Forbidden flip.** `Array[int]([0, 3])` (keyboard P1 vs. gamepad P2) is FORBIDDEN in 2-2 — it would put a live killable human on both slots and thereby re-invoke R-D6, which the line above declines.
- **Procedure, both flips.** TEXTUAL edit adding/editing the `slot_controller_kinds` line directly under the `Main` node's `script =` line in `src/main/main.tscn`, Godot editor CLOSED throughout; `git diff -- src/main/main.tscn` after every edit; never committed.
- **No-pad check (never-connected).** AC3(b)'s never-connected half — neutral intent, no crash/pause with zero joypads connected at construction — is proven by the state/integration harness (`Input.get_connected_joypads()` is already empty there); no live step needed for this half.
- **Live disconnect/reconnect.** AC3(b)'s runtime half is NOT covered by the headless case above — unplug the pad mid-match: the slot goes neutral, the match neither crashes nor pauses; replug and confirm control returns.
- **Revert.** Text edit back per flip, or per-diff sorting; a blanket `git checkout -- src/main/main.tscn` is FORBIDDEN once the file carries this story's intentional changes. 2-2 makes no committed `main.tscn` change, so that clause does not apply here — the standing per-diff rule governs regardless. `git status` + the collateral diff are re-verified immediately before any commit chain begins; no lingering Godot editor session (`Get-Process *godot*` check before Step 0).
- **Deferred (AC3c).** Simultaneous two-pad isolation is NOT verifiable on the dev machine (exactly one physical pad) — recorded here as an explicit gap, not silently dropped. Revisit if/when a second pad is available.

## Dev Notes

- One controller class per input *kind* — never a class per player or per slot. The gamepad controller is parameterized by device index (assigned at construction from `Input.get_connected_joypads()`), not by a player-facing text prefix like the keyboard's `p1_`/`p2_` — it has no Input Map actions to prefix (2-2/R2). [Source: docs/project-context.md#Platform & Build Rules]
- Input-source equivalence downstream is exactly what makes E7's scripted bot a config swap. [Source: stories-manual-e2.md#E2.S2 item 5; docs/game-architecture.md#D3]
- Disconnect handling stays in the controller (D3): the runner and state never learn about hardware. [Source: docs/game-architecture.md#D3]
- **Why not per-device Input Map actions (2-2/R2).** Godot CAN filter a joypad event by device index in the Input Map — that path is rejected here, not because it is impossible, but because: (1) joypad device indices are runtime-assigned and shift on replug; (2) with exactly one pad on the dev machine there is no way to route it to slot 1 through the Input Map; (3) it would hardcode a device index into `project.godot`, the most collateral-prone file in the repo; (4) it would be asymmetric with the keyboard actions, which are authored device-agnostic (`device=-1`). The controller instead reads `Input.get_joy_axis(device, ...)` / `Input.is_joy_button_pressed(device, ...)` directly, device-filtered in code, never through the Input Map.
- **Gamepad profile resource (2-2/R2); script path RATIFIED, not provisional (2-2/A7).** Button/axis mapping and the deadzone are authored data in `data/gamepad_profile.tres`, backed by `src/controllers/gamepad_profile.gd` — the `camera_config.tres` pattern (presentation/feel, load-once, deliberately outside `BalanceConfig` and the X3 hot-reload path), but controller-owned rather than actor-owned, since this is input-hardware mapping, not camera framing. The script path is ratified: `camera_config.tres`'s script lives at `src/actors/hero/camera_config.gd` (actor-owned) and `feature_flags.gd` lives at `src/state/resources/` (state-owned) — the precedent is "a resource script lives in its owner's domain folder", which makes `src/controllers/gamepad_profile.gd` consistent, not deviant. This is a narrow, recorded exception to "named actions, never raw" (project-context.md): the raw joypad axis/button constants live exactly once, inside this resource, never scattered inline in the controller.
- **Runner wiring (2-2/R4).** `match_runner.gd`'s `ControllerKind` enum gains one appended member: `{ KEYBOARD_P1, KEYBOARD_P2, NULL, GAMEPAD }` — appended so `NULL` stays ordinal 2. `_make_controller()` gains the `GAMEPAD` arm. This runner edit IS the A3 single config point and is the sanctioned exception to "no file outside src/controllers/"; no state, hero, or actor edit. A new guard test pins the four ordinals (`KEYBOARD_P1==0`, `KEYBOARD_P2==1`, `NULL==2`, `GAMEPAD==3`) — int-literal callers (`test_camera_relative.gd`'s `[0, 1]`, every smoke flip) depend on them, and a future reorder would otherwise silently change the shipped default. Same principle as the F1 invariant test: a dependency that exists must bite when broken.
- **Analog magnitude — NORMALIZED, not merely clamped (2-2/R5).** `_resolve_movement` (`match_state.gd`) clamps `move_dir` only above length 1.0 (`if dir.length() > 1.0`); a partial stick deflection would otherwise pass through as a fraction of `move_speed`. 2-2's gamepad controller normalizes the stick vector to unit length above the deadzone before it ever reaches state, so gamepad movement is binary-speed, matching keyboard parity. Variable-magnitude movement (walking at partial stick deflection) is an unauthored gameplay lever arriving through hardware — no authored walk speed, no stamina coupling, no walk animation to render it — recorded as an open decision in `decision-log.md`, forcing point story 2-6; if ever adopted it inherits the DEBT E animation gate.
- **E3 out of scope (2-2/R3).** The original draft's E3 action set (play-card, stage-card, mode-select) is struck. Those actions have no consumer in 2-2, and E3 is under a HOLD gate pending the first E1/E2 playtest — pre-authoring its bindings now would violate the project's own revisit rule.

### Project Structure Notes

- `src/controllers/gamepad_controller.gd`; gamepad binding profile at `data/gamepad_profile.tres` (script `src/controllers/gamepad_profile.gd` — path RATIFIED, 2-2/A7, not to be re-opened at dev pass); no `project.godot` edit. The sanctioned `ControllerKind` / `_make_controller()` edit lives in `src/main/match_runner.gd`. The ordinal guard test's natural home is `test/state/test_architecture_invariants.gd`, alongside the F1/D3 guards (dev-pass detail).

### Project Context Rules

- **D3(a):** `Input.*` only under `src/controllers/`. [Source: docs/project-context.md#Controllers & state-layer determinism]
- **Named actions, physical keycodes; no raw keycodes inline** — with a narrow, recorded exception (2-2/R2): the gamepad controller reads device-filtered joypad state directly, not named Input Map actions, and its button/axis/deadzone data lives in the controller-owned profile resource named above, never scattered inline. [Source: docs/project-context.md#Platform & Build Rules]

### References

- [Source: stories-manual-e2.md#E2.S2]
- [Source: docs/game-architecture.md#D3; #Novel Pattern 3]
- [Source: decision-log.md#Session 2026-07-28 — Story 2-2 readiness gate (operator decisions)]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
