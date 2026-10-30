---
baseline_commit: 40d36715e797135bbf8d1814dcc64a120408fa4d
---

# Story 7-12: Match Menu

Status: ready-for-dev

> **Scope note.** `epic-7` story, **Tier B** (`E4-P/R9`): no `src/state/` edit, golden and snapshot key set
> predicted UNMOVED and MEASURED before and after; if either moves, the tier is raised and the story stops
> (raised, never lowered). Source: the operator's 2026-10-30 story brief, carried below as C1-C4 plus the
> constraint list; 7-11 deferred the controls-editing UI here (`7-11-control-scheme-v2.md`, R5 and Non-Goals).
> The GDD, `epics.md` and `decision-log.md` lock nothing about a menu (grepped: no "pause menu", "rematch",
> "main menu" or "7-12"). All citations measured at `40d3671`. Labels in this file are local; they are
> numbered at close-out (`E6-R/R10`).

## Story

As a player in a local match,
I want to pause, rematch, change my hand layout and quit from a menu, and get a rematch offer when a round ends,
so that a session of several matches runs without restarting the game or editing files.

## Operator brief (2026-10-30) — carried as given

- **C1 Pause.** Start on any pad (keyboard: Esc or equivalent) pauses. Nothing advances or moves; any player
  resumes, immediately, no countdown. Pause lives outside the tick loop: no state field, no snapshot change,
  replay-neutral (a paused stretch produces no intents). The 3-0b debug pause is the first candidate — dev decides.
- **C2 Pause menu**, over the whole window, navigable from any connected pad and the keyboard: Resume / Rematch /
  Controls per player / Quit. Rematch from pause needs a second confirming press; from the end screen it does not.
  Rematch = a fresh match (new `MatchState`, new seed, same decks from `data/deck_select.tres`, same
  `slot_controller_kinds`, pads keep their slots, HUD rebuilt, nothing left over), never the debug reset path.
  Rebuilding the match the way the game starts is the cheapest route — dev decides. Quit exits; no main menu.
- **C3 Controls per player:** pick slot 1 or 2, then ONE setting — hand layout, cycling ROW / ROW+GLYPH / DIAMOND
  (0 / 1 / 2). No remapping. Written to `user://controls/slot_N.cfg` in the 7-11 format: only the `hand_layout`
  line changes, every other line stays; a written file is always accepted by the 7-11 parser. Applies on Resume.
  Keyboard slots show no settings.
- **C4 End-of-match screen** on the existing round-over (`EventBus.round_ended`), ~1.5 s after the death, offers
  Rematch and Quit. The per-half WIN/LOSE labels stay. One round to death; no best-of.

## Measured for this story (create pass, 2026-10-30, at `40d3671`)

### M1 — Today's debug pause and what it does not freeze

- Gate: `match_runner.gd:118-119` (`_debug_input`, `_paused`), toggled by `debug_pause` (F1, `project.godot:136-138`)
  at `:5630-5631`; `ticking := not _paused or step_pressed()` (`:5636`). Inside the gate: lock gather, basis /
  fact pushes, the intent tap `_recorder.capture_advance` (`:5831`), `advance` (`:5833`), every post-advance poll,
  spawn / free and actor drive (`:5662-5952`).
- **Outside the gate (sampled while paused):** both controllers' `sample()` every frame (`:5640`), the armed-slot
  push (`:5651-5652`), camera follow and shake (`:5953-5966`). So under today's pause a D-pad tap still ARMS a card
  (`gamepad_controller.gd:322-329`) and every edge memory (`_prev_held`, `:63`) keeps moving.
- **Not stopped by the gate at all (by reading — no code in it touches them):** `AnimationPlayer` playback
  (engine-processed; the hitstop is the one `speed_scale` write, `animation_controller.gd:1182-1187`), the effect
  presenter's physics-process tweens (`effect_presenter.gd:1201`), HUD tweens and one-shot timers. C1's "nothing
  moves" is therefore NOT met by `_paused` alone. The dev pass verifies live which visuals keep running.
- `DebugInputReader` (`debug_input_reader.gd:23-43`) is the sanctioned non-`Controller` reader under
  `src/controllers/` returning plain bools; it reads match-global Input Map actions, not a pad.

### M2 — How a match starts (the rematch route)

`_ready` (`match_runner.gd:456-`) resolves the seat decks first and refuses to start on a bad name (`:480-488`),
builds both controllers through `_make_controller` (`:489-492`, `:2711`), resolves the seed (`:497-501`), constructs
`MatchState.new(MatchParams.new(seed))` (`:501`), applies balance, builds both `HudRoot`s inside the SubViewports
(`:684-703`) and pushes each pad slot's layout (`:700-702`). Seed precedence (`_resolve_seed`, `:1099-1110`):
`seed_override` (tests, `:1075`) > `data/seed_pin.tres` (`pinned_seed = 0`, unset) > a fresh random draw.
`slot_controller_kinds` is an `@export` on the scene node (`:30-33`; `main.tscn` carries no override line).
Pad device = the i-th entry of `Input.get_connected_joypads()` at controller construction
(`gamepad_controller.gd:111-125`). Test seats `seed_override`, `controls_override_root` (`:1080`) and the deck
overrides are set before the runner enters the tree — a route that re-instances `main.tscn` from file drops them.
The debug reset (`_relay_round_started`, `:2893-`) is NOT a rematch (C2): it re-arms the round and clears units,
not the seed, hand or history.

### M3 — The 7-11 override format (the writer's contract)

`GamepadProfile` (`gamepad_profile.gd`): `OVERRIDE_ROOT = "user://controls"` (`:132`), `override_path` →
`<root>/slot_<N>.cfg`, N = player slot 1/2 (`:193-194`), `load_for_slot` read once at controller build
(`:172-189`), containment by `RecordFile.is_inside_root` (`:176`). Parser `apply_override_text` (`:203-243`): one
`key = integer` per line, blank and `#` lines ignored, CRLF and a UTF-8 BOM accepted (7-11 L1 pins); refuses the
WHOLE file on a malformed line, unknown key, non-integer, over-long literal, out-of-range value, repeated key or a
binding collision. `hand_layout` (`:144`) range is `HandLayout.size()` = 3 (`:106-107`). The HUD push
`HudRoot.set_hand_layout(layout, direction_slots)` is callable again after build (`hud_root.gd:1927`); the runner keeps
each pad slot's profile in `_slot_profiles` (`match_runner.gd:1084`, `:2729`). `JOY_BUTTON_START` is a refused system
button for every role (`gamepad_profile.gd:147`, `:253-254`) — Start can never collide with a binding.

### M4 — Round over today

`EventBus.round_ended(loser_index)` (`event_bus.gd:15`) is relayed after the drain (`match_runner.gd:2881-2887`), wired
to each HUD's `on_round_ended` (`:753`) → "YOU WIN" / "YOU LOSE" (`hud_root.gd:1313-1315`), hidden by `on_round_started`
(`:1321`). The match then freezes in round-over until a debug reset.

### M5 — UI and test constraints that bind the menu

- No `func _process` anywhere under `src/ui/` (`test_architecture_invariants.gd:585-607`); timed UI uses a one-shot
  `SceneTreeTimer` (the reshuffle-flag precedent). `src/ui/` code may not name state mutators or `_match_state`
  (`:686-720`). `Input.*` only under `src/controllers/` (D3(a)).
- `hud_root.gd` existence guard (`:705-709`) is the pattern for the new menu file's guard.
- Window-level overlay precedent: the start-refusal label on its own `CanvasLayer` (`match_runner.gd:1060-1061`);
  the HUDs live inside the two SubViewports and cover one half each.
- 7-11 L3 guard: a test that builds a GAMEPAD slot must set `controls_override_root` (`:649-675`).
- Keyboard: Escape is bound to no project action. Godot's built-in `ui_cancel` includes Escape but also a joypad
  button on ALL devices — reading it as "pause" would make a pad's face button pause the game, device-unfiltered.

### Baselines of record (`40d3671`)

Golden `97c9a1de7047d28ffa41e9b55dca905b6ccb542942677a096d2735c11b29da96`, 66 per-player keys; `FORMAT_VERSION` 25;
suite 1590 / 0 / 26430 + 104 integration (`sprint-status.yaml` 7-11 note).

## Acceptance Criteria

Marks: **[M]** machine-tested (state harness or integration), **[S]** operator smoke only.

**Pause (C1)**
1. [M] Start on the pad bound to slot 1 or slot 2 opens the pause menu; the press is read from that slot's own device
   (2-2). On the keyboard, Esc opens it. No pad button bound to a gameplay role pauses (incl. the face buttons).
2. [M] While paused the match tick does not advance: the state's tick, both snapshots and the recorded intent stream
   are identical before and after any number of paused frames; resuming continues from the same tick. A held debug
   step key does not advance while the menu pause is up.
3. [M] While paused neither controller produces an intent and no press reaches the match: a D-pad tap does not arm or
   move the arm, and any button held across Resume fires no press edge on the first tick after it (the 7-11 replug
   discipline). The armed slot before the pause is the armed slot after it.
4. [M] While paused no hero, unit, totem, projectile or orb actor moves and no gameplay animation advances (positions
   and animation playheads unchanged across paused frames). [S] nothing visibly moves, incl. effects and hitstop.
5. [M] Resume takes effect on the activating press: no countdown; the next frame ticks.
6. [M] `git diff -- src/state/` is empty; no `InputIntent` field is added; `FORMAT_VERSION` stays 25; a paused stretch
   adds no row to the recorded stream (replay-neutral by construction).

**Pause menu (C2)**
7. [M] The menu covers the whole window (both halves) and lists, in order: Resume, Rematch, Controls, Quit.
8. [M] It is navigable and activatable from each slot's pad and from the keyboard. Opening the menu focuses Resume.
9. [M] Rematch from the pause menu needs a second, confirming press of the same item; any other navigation cancels
   the confirmation. Quit requests application exit exactly once. [S] the game window closes.

**Rematch (C2, from either screen)**
10. [M] A rematch yields a fresh match: a new `MatchState`; on the shipped (unpinned) config a seed different from the
    previous match's (a nonzero `pinned_seed` in `data/seed_pin.tres` deals the rematch from that seed, exactly as
    it deals a launch; the shipped file is unpinned, so play always draws a new seed); both seats' decks per `data/deck_select.tres`; a freshly dealt hand; full hp on both heroes; zero
    units, corpses, projectiles and orbs; tick 0. The debug reset path (`round_started`) is not used to produce it.
11. [M] After a rematch the scene is clean: no actor, effect, history-strip entry, round label, pitch ghost or armed
    slot survives from the previous match; both HUDs are rebuilt with each pad slot's current hand layout.
12. [M] A rematch keeps `slot_controller_kinds` and binds each pad slot to the same device it had; no pad changes slot.
13. [M] The new match records and replays like any match: its recorded seed is the seed it was dealt from.

**Controls (C3)**
14. [M] Controls asks for slot 1 or slot 2 — any slot's pad or the keyboard may pick either slot — then shows exactly one setting for a GAMEPAD slot: hand layout, cycling
    ROW → ROW+GLYPH → DIAMOND → ROW (0 / 1 / 2). A keyboard (or null) slot shows that it has no settings and writes
    nothing. No button, direction or axis can be changed from the menu.
15. [M] A layout change writes `<override root>/slot_N.cfg` for that player slot (N = 1 / 2). With no file present
    it creates one the 7-11 parser accepts, giving that layout and every other field its shipped default. With a
    file present that the parser accepts, it changes only the `hand_layout` line (or appends one) and every other
    line stays byte-identical. With a file present that the parser refuses, it overwrites it with a fresh file of
    the first kind (chosen layout, shipped defaults elsewhere); no message is shown.
16. [M] Round trip: for each of 0 / 1 / 2, write then parse through `GamepadProfile.load_for_slot` yields that value
    and an otherwise unchanged profile (shipped defaults, when the file was absent or refused). The writer never
    produces a file the parser refuses.
17. [M] The override path is contained under the resolved root (`RecordFile.is_inside_root`, `3-0d/R22`); every test
    of the writer or of a GAMEPAD controller uses a test root outside both `user://` and the repo (7-11 L3).
18. [M] The new layout is on screen on the first frame after Resume, on that slot's own HUD only; the other slot's HUD
    and both controllers' arm state are unchanged. [S] the layout persists across a game restart.

**End-of-match screen (C4)**
19. [M] On `EventBus.round_ended` the end screen appears 1.5 s (± one frame) after the death, not before; the per-half
    WIN / LOSE labels show as today from the death on. It offers Rematch and Quit, navigable as AC 8.
20. [M] Rematch on the end screen needs no confirmation (AC 10-13 apply). A debug reset before the screen appears
    cancels it; one after hides it. Start does not open the pause menu while the end screen is pending or shown
    (Resolved 2).

**Structure, invariants, measurement**
21. [M] Menu and end screen are Controls built in code under `src/ui/`; no `.tscn` is edited (`main.tscn` diff
    empty). `test_architecture_invariants.gd` gains an existence guard for the new file(s) on the `hud_root_found`
    pattern; the `_process`, banned-token, F1, D3(a) and D3(b)/A2 guards stay green unedited.
22. [M] `project.godot` diff is empty unless an Input Map action is the right tool for the keyboard pause, in which case
    it is exactly that one action, named and reasoned in Completion Notes.
23. [M] Golden `97c9a1de…29da96` and the 66-key snapshot set measured before AND after, byte-identical `measure`
    output (Tier B's decisive clause). Suite before and after; every new guard mutation-proven.

## Golden Prediction

**PREDICTED UNMOVED.** Everything in scope is runner, controllers-layer and UI code; the golden is driven by
synthesized intents and never builds a runner, menu or file. A move means a state touch — stop and report.

## Non-Goals / Deferred (no scope here)

Full button remapping UI; a main menu; deck manager and game modes as menu items; best-of rounds; keyboard settings
(7-11 G4 deferral stays open); an unpause countdown; any balance or card change.

## Tasks / Subtasks

- [ ] Before-measurement outside the repo: suite (state + integration per the harness), golden + key count, `git diff
      --stat -- src/state/ project.godot src/main/main.tscn` (AC 6, 22, 23)
- [ ] Read every UPDATE file in full first (`match_runner.gd` `_ready` / `_physics_process` / relays, the controllers,
      `gamepad_profile.gd`, `hud_root.gd` build + `set_hand_layout`); record what must be preserved
- [ ] Pause gate per AC 1-6: Start per slot device, keyboard pause, no sampling while paused, edge priming on resume,
      actors and animation frozen (mechanism: dev call, Dev Notes)
- [ ] Menu Control under `src/ui/` over the whole window; navigation from every pad and the keyboard (AC 7-9)
- [ ] Rematch route (AC 10-13) carrying the test seats; Quit (AC 9)
- [ ] Controls screen + cfg writer + live layout push on Resume (AC 14-18)
- [ ] End screen with the 1.5 s one-shot timer, cancel on reset (AC 19-20)
- [ ] Tests per Testing below; existence guard (AC 21); mutation proofs
- [ ] After-measurement, diffs, Completion Notes; Live Smoke handed to the operator

## Testing

Headless where reachable (pure decision functions, the cfg writer, menu item order/confirm logic on a bare
Control); one live integration test on the runner for **pause → resume → rematch**: tick and snapshot unchanged
across paused frames, a D-pad tap while paused arms nothing, resume from the same tick, rematch gives a new seed
(no `seed_override` on the rematch, or the test states how the seat is carried), zero units, full hp, a new hand,
no leftover actor / history entry. Also: writer round trip for 0/1/2 and byte-preservation of unrelated lines
(comments, CRLF, BOM, other keys, a missing trailing newline); an already-refused file is overwritten by a fresh,
accepted one (Resolved 1); layout applied on Resume on the own HUD only;
end-screen timing (not shown at 1.4 s, shown by 1.5 s + one frame, cancelled by a reset); existence guards.
Every test touching GAMEPAD or the writer injects a test root (AC 17).

## Live Smoke

Shipped defaults unless named; verdict per item, headline = worst item (`E6-R/R9`). Two pads, `main.tscn`
`slot_controller_kinds = [3, 3]` flip (remove it again before any suite run — the 7-11 smoke-config lesson).
1. P1 Start pauses; everything freezes (heroes, minions, projectiles, orbs, effects, animations). P2 resumes. Repeat
   from P2's pad. Keyboard Esc pauses / resumes with `[0, 1]`.
2. While paused, D-pad taps move menu focus and arm nothing; after Resume no attack / play fires from the held button.
3. Controls → slot 1 → cycle the layout through all three; Resume — P1's half shows it at once, P2's half unchanged.
   Same for slot 2. Restart the game — both choices persist; `user://controls/slot_N.cfg` other lines intact.
4. Rematch from pause: first press asks, second confirms; new deal, full hp, no units / corpses / history; pads keep
   their slots.
5. Kill a hero: WIN / LOSE shows at once; ~1.5 s later the end screen; Rematch starts a fresh match with no confirm.
6. Quit from the pause menu and from the end screen closes the game.

## Dev Notes

- **Tier B, but measured.** Suite twice (open, close), mutation proofs per file only (`PROC/R1`); one engine launch
  per tool call, no `run_in_background` / `ScheduleWakeup` / `timeout` wrapper (`E6-R/R4-R5`); Edit tool first,
  python byte-replace on the first miss (`PROC/R3`). STOP if `src/state/` must change.
- **Pause mechanism (dev call, M1).** `_paused` alone leaves sampling, arming and engine-processed visuals running.
  Options: gate `sample()` and the arm push too and freeze visuals per node; or `SceneTree.paused` with the
  runner / menu set to process while paused and the actors pausable. Either way the runner stays the ONE
  `_physics_process` (F1) and must still read the resume press. Keep the F1 debug pause independent of the menu
  pause; the hitstop's `speed_scale = 0` must survive a pause/resume pair.
- **Edges across the pause** (AC 3): on resume, prime every controller edge HELD as the 7-11 neutral path does
  (`gamepad_controller.gd:143-155`), so the button that chose Resume fires nothing. The arm itself is kept.
- **Start / Esc reads** live under `src/controllers/` (D3(a)), device-filtered per slot. Per 2-2/R2 a raw joypad
  index lives once, as profile data — a new `GamepadProfile` field kept OUT of `OVERRIDE_BUTTON_KEYS` (Start is a
  refused role binding, M3, so it can never collide and is not remappable in 7-12); field name is a dev call. Do not read `ui_cancel` for pause (M5). A raw key read avoids an Input Map
  edit; if an action is chosen instead, say why in Completion Notes (AC 22).
- **Menu input from "any pad"** may use the GUI focus system (built-in `ui_*` actions, all devices) for navigation;
  if so, set the HUD / debug-panel buttons `FOCUS_NONE` (the 6-7 focus-refire lesson) so the menu is the only
  focus owner, and make sure gameplay never reads `ui_*`.
- **Rematch route (dev call, M2).** Re-instancing `main.tscn` (e.g. `reload_current_scene`) is cheapest for the shipped
  game but drops seats set before `_ready` — the integration test needs those carried, or an in-place rebuild.
  Unpinned seed → a fresh draw; a pin applies to a rematch as to a launch (Resolved 3). The rematch resolves its
  seed through the same `_resolve_seed` precedence as a launch, so a pin needs no second rule. Signal connections to
  `EventBus` from freed HUDs / cues must not leak or double-fire into the new match.
- **Writer.** Edit the file's text, not a re-serialised profile: replace exactly the `hand_layout = <int>` line, append
  one if absent, keep line endings and a BOM as found; create `<root>` if missing. Validate the result with
  `apply_override_text` on a duplicate BEFORE writing; write nothing if it would be refused. Home it beside the parser
  (`GamepadProfile`, static) so format and writer cannot drift — dev call.
  Resolved 1 supplements this: when the EXISTING file is already refused by the parser, the line edit is skipped and
  the file is overwritten with a fresh `hand_layout = <n>` file (that file was not in effect anyway — the slot ran on
  the shipped default). The validate-before-write check still guards the writer's own output in every branch.
- **Text fit is smoke-only** (`PROC/R8`): machine checks assert geometry (menu covers the window, items present, order).
- **Commits** (operator's step): docs and code separate; ASCII via `git commit -F`; trailer
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` (`6-1c/R7`).

### Files expected to change (illustrative)

New under `src/ui/` (menu + end screen) and possibly a reader under `src/controllers/`; `src/main/match_runner.gd`
(pause gate, menu wiring, rematch, end-screen timer, layout push on Resume); `src/controllers/gamepad_profile.gd`
(writer) and possibly `gamepad_controller.gd` / `keyboard_controller.gd` / `controller.gd` (Start read, resume
priming); `test/state/test_architecture_invariants.gd` (existence guard); new tests. **Not:** `src/state/**`,
`src/main/main.tscn`, `data/*.tres` defaults.

### Project Context Rules (extracted)

D3(a) `Input.*` only in `src/controllers/`; F1 one `_physics_process`; D3(b)/A2 no `Time`/`OS`/`Engine` in
`src/state/`; HUD is a read-only consumer, signal- or push-driven, never `_process` in `src/ui/`; `user://` containment
by normalisation, never `begins_with` (`project-context.md:173`); a user-writable file is never loaded as a
resource, data text only (7-11 M4); `Dictionary.has` on a null value is true (`3-0d/R21`); `docs/playtest-log.md` is the
operator's alone (`E6-R/R7`).

### References

- `docs/implementation-artifacts/7-11-control-scheme-v2.md` — R5/R6, M4 (override file), Dev calls (format, fallback,
  `_slot_profiles`, `set_hand_layout`), review fix L1-L3.
- `docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md` — the debug step/pause gate (AC 1).
- `docs/project-context.md` — testing rules (:126-149), `user://` (:173).
- `docs/game-architecture.md` — D3 (:300) and the `_physics_process` boundary F1 (:997) sections only.

## Resolved questions (operator rulings, 2026-10-30)

1. **A cfg file that is already refused** — the menu OVERWRITES it with a fresh file: the chosen layout, shipped
   defaults for every other field (the refused file was not in effect anyway). No session-only mode, no "invalid
   file" message. Folded into AC 15/16, which now hold without an exception.
2. **Start after a hero dies** — does nothing; the end-of-match screen is the only menu from the death on. AC 20 as
   written.
3. **Rematch with a pinned seed** — a pin in `data/seed_pin.tres` applies to a rematch exactly as to a launch; shipped
   unpinned, so play always draws a new seed. Folded into AC 10.
4. **Who may change which slot** — any pad or the keyboard may change either slot's layout. Folded into AC 14.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
