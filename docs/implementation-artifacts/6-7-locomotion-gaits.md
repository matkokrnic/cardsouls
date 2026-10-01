---
baseline_commit: df28167ce95eedea1a92c8fb5480f045914c6c5c
---

# Story 6.7: Locomotion Gaits

Status: done

> **Scope note.** Board order item 7 of eleven (decision-log Session 2026-09-08, `E6-P/R2`). Tier
> A by the golden clause AND by content (`E6-P/R3`): "today's build has ONE `move_speed`
> (`src/state/resources/balance_config.gd:16`), so this is a genuinely new system and Tier A by the
> golden clause, not a retune." SUPERSEDES the `5-3/R6(d)` retune entry (locomotion speed /
> walk-as-default / sprint-costs-stamina) and CLOSES open decision (c) (variable analog magnitude,
> `2-2/R5`, forcing point `2-6`, never adopted — DEBT E moot per `epic-3-retro-2026-08-06.md:276`).
> Presentation (walk/turn clips) is `6-7b`, gated on its own asset prerequisite (`E6-P/R10`) and
> explicitly NOT this story's concern (`E6-P/R8` amendment (ii)).

## Measured Facts

1. **M1 — where `move_speed` is consumed.** `_resolve_movement(player, intent, slot)`
   (`src/state/match_state.gd:3749`) is the ONE seat. It short-circuits on DEAD (`:3758`, velocity
   zeroed), then computes `world_dir` from `intent.move_dir` (camera-rotated), then branches on
   `action_state`: ROLLING uses the entry-locked `roll_direction * (roll_distance /
   roll_duration_seconds)` (`:3792-3794`), CHARGING is hard-rooted to `Vector3.ZERO`
   (`:3795-3809`), **STUNNED is hard-rooted to `Vector3.ZERO` (`:3816-3826`, the `5-6` AC 14
   precedent, a third sibling of the ROLLING/CHARGING root reasoning — corrected: the story's
   original branch list omitted this one, per readiness gate 1 finding B4)**, and the ordinary
   (`else`) case reads `var speed := player.hero.move_speed` (`:3838`) then applies the per-phase
   attack multiplier via the `_attack_phase_multiplier` helper (`:3841`, the helper's own body
   at `:3910` — corrected: the helper's definition is cited at `:838`, below) using the three
   per-phase fields authored 0.0 (Fact in R7 below).
   `player.hero.move_speed` itself is set ONLY at `_apply_balance_to_player`
   (`match_state.gd:4118`, `player.hero.move_speed = config.move_speed`) — there is no second
   writer. Gait selection must land BEFORE line `3838`'s read, as a new branch alongside (not
   inside) the ROLLING/CHARGING/STUNNED carve-outs — those three already override speed
   unconditionally and must keep doing so (a rolling, charging or stunned hero is not "walking" or
   "running", it is executing a committed action or a hard-rooted punish; gait does not apply to
   any of the three, and running never drains stamina on any of their ticks — `6-7/R9`).
   **BLOCKING is NOT one of the four named branches — it falls through to the ordinary `else` and
   reads full `move_speed` today, unmodified by anything block-specific.** This story's `6-7/R10`
   ruling (AC 16 below) changes that: BLOCKING becomes a fifth gait-relevant case, forced to
   `balance.walk_speed` regardless of the run key, because BLOCKING already suppresses regen
   (`match_state.gd:2382-2384`) and letting it also run at full speed would put two different
   stamina policies on one action state.

2. **M2 — the keyboard held-key precedent.** `KeyboardController.INTENT_ACTIONS`
   (`src/controllers/keyboard_controller.gd:13`, corrected — readiness gate 2 note 12) is
   `[&"attack", &"block", &"roll"]`; `sample()`
   (`:86-97`, corrected — readiness gate 2 note 12) loops it, writing BOTH `intent.pressed[key]`
   (`is_action_just_pressed`) and
   `intent.held[key]` (`is_action_pressed`) for every entry, each key resolved through
   `_action(prefix, name)` to `p1_<name>` / `p2_<name>`. This is the precedent R2 follows: `&"run"`
   joins `INTENT_ACTIONS`, and `_init` needs no new line beyond what the loop already does — the
   loop itself is the whole mechanism. `p1_cast_mode` (`:117-146` block) is a DIFFERENT, unrelated
   shape — a controller-LOCAL modifier that gates a private multi-step card-arming scheme and is
   read directly off `Input.is_action_pressed(_cast_mode)` (`:111`, corrected — readiness gate 2 note
   12) rather than exposed on the
   intent at all. It is not a "held action" precedent in the relevant sense (a prefix-free key the
   state layer reads); `INTENT_ACTIONS` is.

3. **M3 — the `suppressed` seat.** `StaminaPool.advance_regen(amount_per_tick, suppressed)`
   (`src/state/pools/stamina_pool.gd:63-64`, `if _regen_delay.is_running or suppressed: return`) has
   exactly one caller, `MatchState._regen_stamina(player)` (`match_state.gd:2382-2425`), which
   builds the boolean as `state == BLOCKING or state == DEAD or state == CHARGING` (`:2382-2384`,
   the D6 policy seat). Running joins this OR-chain as a fourth disjunct — a POLICY change at the
   existing seat, no new pool method, exactly as `5-2/R4` added CHARGING beside BLOCKING and DEAD
   before it. The disjunct must read a per-tick "is the hero actually running THIS tick" fact (the
   `6-7/R13` predicate, Dev Notes below), not the raw held-input alone, or a run-held-but-forced-to-walk
   tick (the M6 Direction B latch, the post-empty lockout) would wrongly suppress regen exactly when
   the design needs it running so the bar can cross the resume threshold. **Corrected (readiness
   gate 2, Blocker 2): the predicate must also exclude ATTACKING (`6-7/R17`) — an attacking hero with
   run held and non-zero `move_dir` reads as "actually running" under clause (3)'s original
   ROLLING/CHARGING/STUNNED/BLOCKING-only exclusion list, which contradicts AC 11(i)/(ii)'s
   requirement that drain stop and running-suppression lift on attack entry.**

4. **M4 — the `normalize_move_magnitude` retirement surface, exhaustive.** Every named site:
   - `src/controllers/gamepad_profile.gd:66` — `@export var normalize_move_magnitude: bool = true`
     (plus its doc block, `:49-56`).
   - `src/controllers/gamepad_controller.gd:166` — the call site,
     `resolve_move_dir(raw, _profile.deadzone, _profile.normalize_move_magnitude)`.
   - `src/controllers/gamepad_controller.gd:477-489` — `resolve_move_dir`'s doc block and its
     `normalize_magnitude := true` third parameter plus the `if normalize_magnitude or raw.length()
     > 1.0: return raw.normalized()` branch. The function's 2-arg callers (every headless test)
     are unaffected by removing the parameter entirely and hard-coding the true branch.
   - `src/ui/debug/debug_instrument_panel.gd` — the whole "Switch 1" surface: the class doc block
     naming it (`:16-23`, corrected from `:11-19` — measured by content, gate finding B6), the
     `CheckButton` construction (`:171-176`, name `"NormalizeMagnitude"`), and
     `_on_normalize_toggled` (`:293-296`). The panel's `gamepad_profile` member itself (declared for
     no other switch) becomes dead with it.
   - `src/main/match_runner.gd:462` — `panel.gamepad_profile = load("res://data/gamepad_profile.tres")`,
     the member's ONLY writer (corrected: named separately per gate finding B6; the story's original
     text said the member "becomes dead" but never named the runner line that assigns it — this line
     is not deleted, since SAVE/RELOAD and the reveal control still live on the same panel, but the
     assignment becomes dead weight once nothing on the panel reads `gamepad_profile` any more,
     worth a one-line note in the dev pass's Completion Notes rather than silent).
   - `data/gamepad_profile.tres:13` — `normalize_move_magnitude = true`.
   - `test/state/test_gamepad_controller.gd:132-149` —
     `test_variable_magnitude_passes_partial_deflection_through` (asserts the false-branch).
   - `test/state/test_gamepad_controller.gd:151-175` —
     `test_panel_and_controller_share_the_same_profile_instance` (DEBT B adjacency, N1) — asserts
     the shared-instance flip specifically ON this field; retiring the field retires this test.
   - `test/integration/test_debug_instruments.gd` — the AC-4 doc block (`:14-15`), the `_magnitude_ok`
     variable, declared at `:64` (corrected from an unstated location, gate finding B6), its
     four-line check (`:184-192`: `mag_switch`/`default_on`/`flipped_off`/`flipped_back`), and its
     membership in the composite `ok` expression at `:139-144` (corrected from `:118-120` — the
     composite assignment is at `:139`, the `print(...)` that reports it at `:143-144`, gate
     finding B6).
   - `test/integration/test_record_save_control.gd:177-181` — the EXACT control-name list
     `["NormalizeMagnitude", "ReloadBalance", "RevealOpponentHand", "SaveRecord"]` (currently four,
     post-`6-3b`'s own retirement of the pitch-placement switch) must drop to three:
     `["ReloadBalance", "RevealOpponentHand", "SaveRecord"]`, AND the check's message text at the
     same lines ("the panel's controls are the one switch plus SAVE, RELOAD and REVEAL...") must
     drop "the one switch plus" — corrected: the story's original text named only the array, not the
     message, per gate finding B6.

   Nothing else names the field or `NormalizeMagnitude` by content (grep-verified). No
   `test_architecture_invariants.gd` guard touches it.

5. **M5 — existing tests asserting a single hero speed, CONTRADICTING the "gait is additive" hope,
   REWRITTEN per readiness gate 1 finding B2 (the story's original file list and fix were both
   wrong).**
   **(a) The correct file list, measured by grep for `move_dir = ` / `Vector2(1, 0)` / `MOVES[` across
   `test/state/*.gd`: 13 files drive a non-zero `move_dir` at all; of those, 8 have assertions that
   depend on input-driven speed and so break the moment an unauthored `walk_speed` defaults to 0.0:**
   `test_match_state.gd:50,53,59,254` (literal `5.0` magnitudes, incl.
   `test_analog_input_clamped_to_move_speed`, the OPERATOR'S NAMED EXCEPTION below),
   `test_camera_basis.gd:38-105` (`SPEED := 5.0`), `test_contact_resolution.gd:220-232,312,317`
   (`5.0` x multipliers, steered + lunge), `test_roll_iframes.gd:170` (`(0,0,-5.0)` after the roll —
   ROLLING's own speed, unaffected by gait, but the pre-roll approach that reaches it is walk-gated),
   `test_action_state.gd:235` ("an IDLE hero moves", `> 0`), `test_unblockable_hold.gd:294`
   (`assert_ne(velocity, ZERO)` on release, `move_speed = 4.0` at `:461`),
   `test_replay_identity.gd:487` (`assert_ne` on velocity — both sides would be zero, **FAILS, not
   merely weakens (corrected, readiness gate 2 note 3): `assert_ne` on two equal zero vectors fails
   outright, and the hash `assert_ne` immediately above it fails the same way**), and
   `test_determinism.gd` (the golden itself, `MOVE_SPEED := 6.0` at
   `:1010`, consumed by `_golden_config()` at `:1200-1203`). Five more move but are unaffected because
   their runs are self-consistent or already rooted: `test_intent_recorder.gd`, `test_record_file.gd`,
   `test_unblockable_initiation.gd`, `test_unblockable_tracking_and_reach.gd`,
   `test_gamepad_controller.gd` (its source-agnostic identity check at `:192-208` would still pass at
   walk-default but become weaker — both sides zero — unless walk speed is authored there too).
   **The story's original file list was wrong and is struck:** `test_lock_on.gd` and
   `test_totem_accelerators.gd` contain no `move_dir` and no `velocity` by content — they drive no
   movement at all; `test_visible_facing.gd` and `test_lock_on_live.gd` live in `test/integration/`,
   not `test/state/` — **corrected (readiness gate 2 note 11): they are OUT OF SCOPE for Task 6
   outright, not "covered by item (c)" — (c) is a local-config-substitution rule that cannot reach an
   integration test at all (only M5(f)'s two named integration files need a fix, by a different
   mechanism), and Task 6's own exclusion list already names both files as not in scope.**
   `test_block_deflect.gd` drives
   no movement either (17 stamina assertions, zero movement ones).
   **(b) Helpers are unshared, confirmed by content:** 13 `func _intent(` definitions exist across the
   13 files that drive `move_dir` at all — **corrected (readiness gate 2 note 4): only 5 of those 13
   files are movers in the (a) sense (drive a movement-dependent assertion); the story's original
   framing implied all 13 needed a per-file `_intent` fix, which overstates Task 6's reach.** The
   conclusion still holds regardless: the only shared test scripts in the repo, `test/replay_drive.gd`
   and `test/unit_kind_fixture.gd`, build no hero intent, so no shared helper exists to fix once. Task 6
   is therefore genuinely file-by-file, scoped to the 8 files in (a).
   **(c) The fix is NOT a literal `&"run": true`.** That would also drain
   `run_stamina_drain_per_second` (10.0/s authored) in every file that shares its intent helper with
   a stamina assertion — measured by `assert.*stamina` count: `test_determinism.gd` (3),
   `test_unblockable_hold.gd` (6), `test_action_state.gd` (1) — silently breaking tests that have
   nothing to do with gait. **The ratified rule (`6-7/R11`): each affected file authors
   `walk_speed` EQUAL TO THAT FILE'S OWN `move_speed`, making gait a no-op so the existing velocity
   assertions hold unchanged without ever pressing `&"run"`.** NOT a shared literal `5.0` — measured
   per-file values differ: `test_determinism.gd` 6.0, `test_unblockable_hold.gd` 4.0,
   `test_replay_identity.gd` 7.0/11.0 (`:54,57`), `test_record_file.gd` 7.0/11.0 (`:90-91`, unaffected
   by (a) but still needs the value for consistency with its own mid-run retune, item (d) below),
   `test_live_reload.gd` 6.5/13.25 (`:25,28`).
   **(d) Mid-run retune configs must retune `walk_speed` too, named individually:**
   `test_replay_identity.gd:780`, `test_record_file.gd:1216`, `test_live_reload.gd:327` — each
   reloads `move_speed` mid-run to a second value; leaving `walk_speed` at the first value would let
   the reload land but silently stop reaching velocity, passing the assertion while proving nothing
   about the reload it claims to test.
   **(e) `_golden_config()` (`test_determinism.gd:1200-1203`) must author `walk_speed` too** — see
   Fact M6 Direction B's guard below (**corrected, readiness gate 2 note 11: M6 follows M5, not
   "above"**) — or the golden moves for a SECOND, unrelated cause.
   **(f) Two integration files cannot use the local-config substitution at all, because they read the
   AUTHORED `.tres` directly:** `test/integration/test_hero_movement.gd:25` (`MOVE_SPEED := 5.0`) and
   `:52` (`is_equal_approx(actor_velocity.length(), MOVE_SPEED)`) — at the authored `walk_speed = 2.5`
   with no run key held this fails; the test must instead press `p1_run` (matching the delivered
   default two-keyboard config) or assert against `walk_speed`. `test_unit_approach_live.gd` sizes its
   walk-phase window (`_derive_walk_frames`, `:369-374`) from `_hero_speed`, which is set at `:147` to
   `_state.balance.move_speed` — the RUN speed, never `walk_speed`. **Corrected (readiness gate 2 note
   6, was UNMEASURED): this is LIKELY TO FAIL at the authored 2.5 walk speed, not merely an unmeasured
   risk.** `WALK_MARGIN_FACTOR` (1.3) and the `WALK_FLOOR_TICKS` (40) floor were sized against the full
   5.0 `move_speed`; a hero walking at half that speed covers roughly half the expected distance per
   tick, so the window can under-run unless the 40-tick floor happens to dominate for the specific
   approach distances this test drives. Named as a fix obligation, not a risk to merely watch: the dev
   pass must re-derive `_hero_speed` from the walk-gated speed the hero actually uses during the
   approach phase (or size the window from `walk_speed` directly), then confirm the test passes at the
   authored value.
   **(g) The operator's one exception, `test_match_state.gd`'s `test_analog_input_clamped_to_move_speed`
   (`:56-59`), needs its OWN config and a run-held path, NOT the blanket `walk_speed = move_speed` fix.**
   It shares `_stats_match` (`:13`, `move_speed = 5.0`) with `:43-53` in the same file, which asserts
   `5.0` with NO run key held; `:43-53` is fixed by (c) (`_stats_match` authors `walk_speed = 5.0`).
   But the analog-clamp test's own name and purpose is to prove input clamping against `move_speed`
   SPECIFICALLY — and under this story `move_speed` means the RUN speed (AC 1's "unrenamed" ruling).
   If the fix in (c) happens to make `walk_speed` equal `move_speed` too, the test would still pass
   but would no longer prove clamping-while-running at all — it would pass identically at either
   gait, which is not what its own name claims. It therefore needs a config where `walk_speed !=
   move_speed` (so the two gaits are distinguishable) plus a way to hold `&"run"` — `_step` (`:25`)
   takes only a `Vector2`, so either it gains a run-held parameter (default `false`, matching every
   other existing call site's no-run-key behavior — a dev-pass HOW choice) or this one test builds its
   own intent directly rather than routing through `_step`. **Named (readiness gate 2 note 5):
   `test_match_state.gd` also has a second shared config, `_b1_match` (`move_speed = 5.0` at `:185`,
   asserted at `:254`), which (a)'s blanket fix reaches the same way as `_stats_match` — author
   `walk_speed = 5.0` on it too; harmless because nothing in this file besides the named analog-clamp
   test needs the two gaits distinguishable.**
   This is the single largest blast-radius item in the story and is named as its own Task (Task 6)
   rather than folded silently into "update the tests."

6. **M6 — FORMAT_VERSION, both directions, on the `6-1` precedent (CORRECTED: the story's original
   Direction A rested on false history, per readiness gate 1 finding B1).**
   `RecordFile.FORMAT_VERSION` (`src/systems/record_file.gd:187`) is currently 10. The original
   claim below was that `6-1`'s `&"card_cast"` held-key addition shipped WITHOUT a bump; that is
   FALSE — `record_file.gd:158` states in the file's own history comment: "STORY 6-1 BUMPS 7 -> 8,
   AND THE SHAPE FORCED NOTHING -- the SEMANTICS did (`6-1/R4`)." The round-trip mechanism `6-1`'s
   `&"card_cast"` key and this story's `&"run"` key share — `InputIntent.held`
   (`src/state/input/input_intent.gd:36`, corrected — readiness gate 2 note 12) is a
   `Dictionary[StringName, bool]`, and `RecordFile._intent_values` /
   `_intent_from_values` iterate it as a whole dictionary rather than naming each key, so a new key
   needs no serializer edit — makes the SHAPE question free, exactly as `record_file.gd:158` says.
   It does NOT answer the VERSION question, which `record_file.gd:159-166` states is about SILENT
   DIVERGENCE, not serialization: a v7 recording of a mode ② cast carries no `card_cast` key, so
   under the `6-1` build `is_held(&"card_cast")` reads false where it was originally true and the
   chargeup replays as an instant paid feint — loaded without complaint, because a matching version
   number is the only thing the loader checks. `6-1` therefore bumped 7->8 anyway, and `6-2` (8->9,
   `test_live_reload.gd:133`) and `6-3a` (9->10, `test_record_file.gd:170-171`, "an INTENT SHAPE
   change, the tenth InputIntent field") repeat the same reasoning at their own new fields.
   **Direction A, RATIFIED (`6-7/R12`): FORMAT_VERSION BUMPS 10 -> 11.** The 6-7 case is the identical
   shape, and its divergence is a movement bug rather than a card-timing one: a v10 record carries
   no `run` held key AND no `walk_speed` value; `_rebuilt` (`record_file.gd:809-822`) sets only keys
   present in the file, so a replayed v10 record's `walk_speed` stays at the `BalanceConfig`
   zero-default (this story's AC 1, `walk_speed: float = 0.0`) and every hero in that replay moves
   at speed 0 from the tick gait selection lands — loaded without complaint, silently wrong, the
   exact case the bump exists to prevent. The dev pass bumps `FORMAT_VERSION` to 11 and adds a
   v10-refusal test on the `test_a_v9_record_without_card_activate_is_refused_with_a_reason` /
   `test_a_v8_record_without_pitch_costs_is_refused_with_a_reason` shape (both named as precedents
   at `test_record_file.gd:45-47`) — refused with a reason naming the found and current version, not
   silently migrated or replayed at speed 0.
   **Direction B — the GOLDEN DOES move, and the cause is NOT the intent shape.** The mover is the
   new HASHED `HeroState` field this story's R6 mechanism requires (Direction B, this same Fact —
   corrected, readiness gate 2 note 11: the original "Fact 6 below" self-cited from inside Fact 6) — a
   persistent
   gait-lockout latch that crosses ticks and decides an outcome (whether running may resume),
   exactly the `lock_target_slot`/`charge_window` precedent's own test at
   `test_replay_identity.gd:144-148`/`154-158`: CROSSES TICKS + DECIDES AN OUTCOME → HASHED via the
   existing `to_snapshot()` chain, no `UNHASHED_CROSS_TICK_MEMBERS` bump needed (stays at 4). Any
   new `HeroState.to_snapshot()` key changes every hash from tick 0 onward. **Prediction: golden
   MOVES, one named cause (the gait latch field), same discipline `6-1`'s own AC used** — measure
   before/after, confirm it is this one field and nothing incidental. **Guard against a SECOND,
   accidental cause (Task 6(c)):** `test_determinism.gd`'s `_golden_config()` (`:1200-1203`) must
   also author `walk_speed`, or the golden moves a second time for an unrelated reason (every
   walk-gait velocity in the golden run going to 0.0) and the one-named-cause discipline breaks.

7. **M7 — no existing gait concept.** Grepped by content: no `Gait` enum, no `is_running`/`run_state`
   member anywhere names hero locomotion mode (the many `*.is_running` hits in the repo are all
   `TimingWindow.is_running`, an unrelated boolean on a different class — confirmed false-positive
   by content). `HeroState.ActionState` (`hero_state.gd:27`) has exactly seven values, none gait-
   related, and this story does not add an eighth — gait is orthogonal to action state (a hero can
   walk or run while IDLE, and R7 says both attack/roll/deflect entry CANCEL running rather than
   gait becoming a function of action state).

8. **R7 cross-check, measured.** All three `attack_*_move_speed_multiplier` fields are authored
   `0.0` (`data/balance/balance_config.tres:100-102`) — confirmed by direct read — so the hero is
   already fully rooted (zero velocity) for the whole swing regardless of gait; a gait multiplier
   has no in-swing speed to scale, matching the prompt's note verbatim.

## Story

As a player,
I want a slower default WALK and a stamina-costed, button-held RUN,
so that closing distance competes with defending for the same stamina bar (`E6-P/R3`, the Elden
Ring reference) instead of movement being free at the current fixed speed.

## Acceptance Criteria

1. **[headless-provable]** `BalanceConfig` gains three new `@export` fields under `Hero`/`Stamina`:
   `walk_speed: float = 0.0`, `run_stamina_drain_per_second: float = 0.0`, and
   `run_resume_stamina_percent: float = 0.0` (0-100 scale, the `attack_damage_percent_of_max_hp`
   convention, `balance_config.gd:26`). The existing `move_speed` field is UNCHANGED in name and
   semantics — it becomes "the run speed" without renaming (Dev Notes: the rename-avoidance
   reasoning). `data/balance/balance_config.tres` authors `walk_speed = 2.5`,
   `run_stamina_drain_per_second = 10.0`, `run_resume_stamina_percent = 20.0`, leaving
   `move_speed = 5.0` untouched.
2. **[headless-provable]** `BalanceTicks` gains `run_stamina_drain_per_tick: float`, derived once in
   `from_config()` as `config.run_stamina_drain_per_second / TimingWindow.TICK_HZ` — the
   `stamina_regen_per_tick` precedent verbatim (`balance_ticks.gd:130`).
3. **[headless-provable]** `KeyboardController.INTENT_ACTIONS` gains `&"run"` (Fact M2's loop
   mechanism); this is what makes `p1_run`/`p2_run` writable to `intent.held`/`intent.pressed` with
   no other controller code change, but the Input Map ACTIONS THEMSELVES come only from
   `project.godot`'s `[input]` block (corrected: the original text claimed `INTENT_ACTIONS`
   "producing" the actions, which is false by content — `keyboard_controller.gd`'s loop reads
   actions that must already exist there, per readiness gate 1 finding B5). `project.godot` gains
   `p1_run` and `p2_run` — the ONLY `project.godot` edit in this story, made per the discipline now
   in Task 2 (below). **The exact key for `p1_run`/`p2_run` is RATIFIED, FINAL (`6-7/R18`, readiness
   gate 2 Blockers 4-5 superseding the earlier `6-7/R6-STRUCK` ruling below): `p1_run` = Space, `p2_run` =
   NUMPAD 0.** Measured (`project.godot`'s full `[input]` block, `godot --headless --script` for the
   engine constants): `KEY_SPACE` (physical keycode 32) and `KEY_KP_0` (physical keycode 4194438) are
   BOTH absent from every existing binding's `physical_keycode` value, on either player's side, and
   both are PHYSICALLY UNIQUE keys — Numpad 0 has no Left/Right variant the way Ctrl/Shift/Alt do, so
   the `location:0` collision that sank the `6-7/R6-STRUCK` Right-Ctrl ruling (a physical Left Ctrl also
   firing `p2_run` in the shipped two-keyboard default, readiness gate 2 Blocker 4) cannot arise here
   by construction. Shift, Ctrl, and Alt (any location) remain rejected for the reason `6-7/R6-STRUCK`
   measured: this project has no location-aware binding scheme, so any of the two-copy keys binds to
   whichever physical copy is pressed on EITHER player's keyboard. This AC authorizes the dev pass to
   author both keys in `project.godot` (Task 2).
   **Struck ruling, kept for history (`6-7/R6-STRUCK`, superseded by `6-7/R18` above):** `p1_run` = Space,
   `p2_run` = Right Ctrl, with an accepted consequence that LEFT Ctrl also fires `p2_run` under the
   shipped two-keyboard default. **Readiness gate 2 Blocker 4 found that acceptance rested on a false
   premise** — it reasoned from the DELIVERED config (P1 keyboard, P2 pad, no hand on the p2 keyboard
   cluster), but the SHIPPED DEFAULT is two keyboards (`match_runner.gd:31-34`), where P1's left hand
   sits right next to Left Ctrl and would make P2's hero run and drain P2's stamina by accident. `R18`
   removes the need to accept anything: Numpad 0 has no colliding physical twin, so there is no
   consequence to accept.
4. **[headless-provable]** `GamepadController.resolve_card_tick()` (`gamepad_controller.gd:362`) —
   the PURE function, headless samplable by calling it directly with raw bools — gains
   `"run_held": basic_raw and not cast_held` in its returned dict, on the `attack_held`/`block_held`/
   `roll_held` shape exactly (`:430-435`). Its impure caller, `sample()`, then writes
   `intent.held[&"run"] = result["run_held"]` alongside its existing `intent.held[&"attack"] = ...`
   lines (`:200-205`) — corrected: the original text's "(or its caller)" left this unresolved; the
   VALUE is computed in the headless-provable pure function and the WRITE happens in `sample()`,
   never the reverse, so joypad-read impurity (`gamepad_controller.gd:171-174`) never enters the
   provable half. Bare A drives running outside the L3 modifier; A remains the BASIC confirm inside
   `cast_held` with running suppressed there, falling out of the existing pattern rather than being
   separately authored. No new `GamepadProfile` field, no `data/gamepad_profile.tres` edit.
5. **[headless-provable]** A new `HeroState` field (the R6 hysteresis latch, Fact M6/Direction B —
   FIELD NAME is the dev pass's to pick, Open Question 1 below; that is the only part left open)
   is added to `to_snapshot()` and drives gait resolution: while the latch is set, running is
   refused regardless of the run key, even at non-zero stamina, until current stamina is
   **`>=`** `run_resume_stamina_percent` of `max_stamina` — corrected: the original text's "reaches"
   was ambiguous between `>=` and `>`; `>=` is the closed reading, matching AC 10's "at or above
   threshold" below (readiness gate 1 finding B5).
6. **[headless-provable]** `_resolve_movement` (`match_state.gd:3749`) resolves gait BEFORE its
   existing `:3838` speed read, as a new branch alongside (never inside) the ROLLING/CHARGING/
   STUNNED carve-outs: WALK uses `balance.walk_speed`, RUN uses `player.hero.move_speed` (today's
   field, unrenamed). DEAD/ROLLING/CHARGING/STUNNED keep their existing unconditional overrides
   untouched (`6-7/R9`: STUNNED is explicitly named here, corrected — the original text's branch
   list omitted it, readiness gate 1 finding B4). Asserted directly against measured
   walk (2.5) and run (5.0) velocities per state, not merely that the branch exists.
7. **[headless-provable]** Running drains `balance_ticks.run_stamina_drain_per_tick` stamina per
   tick for every tick the hero is ACTUALLY RUNNING — the single named per-tick predicate defined in
   Dev Notes below (`6-7/R13`): run key held AND `intent.move_dir` non-zero after deadzone
   (`6-7/R3` — holding run while stationary drains nothing) AND `action_state` reads movement
   normally (not ROLLING/CHARGING/STUNNED/BLOCKING, **and, corrected per readiness gate 2 Blocker 2
   / `6-7/R17`, not ATTACKING either** — the original clause omitted ATTACKING, so an attacking hero
   with run held and non-zero `move_dir` read as "actually running" and contradicted AC 11(i)/(ii)'s
   requirement that drain stop and running-suppression lift on attack entry; R7's cancel rule already
   implies this, so `6-7/R17` is a text fix, not a new design choice) AND the R6 latch is unset AND
   current stamina is NOT empty. **`6-7/R16` (readiness gate 2 Blocker 1): "not empty" means
   `not is_zero_approx(player.stamina.get_current())`, not merely "above `0.0`".** `StaminaPool.add()`
   (`stamina_pool.gd:29-31`) skips any change smaller than Godot's `is_equal_approx` tolerance, so a
   raw `> 0.0` reading of "empty" lets the pool stick at a residual on the order of `1e-13` — measured
   at the authored values (`max_stamina = 50.0`, `run_stamina_drain_per_second = 10.0`, full bar,
   `spend()` clamped every tick): the pool reaches `1.649e-13` after 300 ticks and sticks there forever,
   so the hero never actually reaches WALK (AC 9), the latch never sets (AC 10), and regen never
   resumes (AC 17). This is an IMPLEMENTATION correction, not a change to R6's feel — the drop to walk
   still happens when the bar is empty, "empty" is just defined correctly. **The AC evidence for this
   MUST drive the authored values (`max_stamina = 50.0`, `run_stamina_drain_per_second = 10.0`,
   `>=300` ticks of continuous running from a full bar) and assert the latch actually sets** — an AC
   proven only with in-test round numbers (e.g. drain `1.0`/tick reaching exact `0.0`) passes while the
   shipped build fails, which is exactly how this defect survived the create pass and readiness gate 1.
   **The drain seat, RATIFIED to deliver both R5's 0.8s release delay and an honest arrival at empty
   (readiness gate 1 finding B3, corrected — the original text left the seat open and neither
   candidate delivered both):** `player.stamina.spend(minf(balance_ticks.run_stamina_drain_per_tick,
   player.stamina.get_current()), balance_ticks.stamina_regen_delay_ticks)` each actually-running
   tick. `spend()` (`stamina_pool.gd:42-47`) restarts the regen-delay window on every successful
   call (giving the 0.8s release delay `add()` never starts) and refuses when the amount exceeds
   what remains (`:43`), so clamping the requested amount to `get_current()` (`stamina_pool.gd:74-75`)
   before the call is what lets the pool reach zero (by the `is_zero_approx` reading, `6-7/R16`)
   instead of refusing just above it — never a new pool method, exactly as AC 7's original text
   required.
8. **[headless-provable]** `MatchState._regen_stamina`'s `suppressed` boolean
   (`match_state.gd:2382-2384`) gains a fourth disjunct: regen is suppressed on any tick the hero is
   ACTUALLY RUNNING, the same predicate AC 7 names (now excluding ATTACKING too, `6-7/R17`), on the
   exact BLOCKING/DEAD/CHARGING shape already there — NOT the raw held-input alone (a
   run-held-but-forced-to-walk tick, e.g. under the R6 lockout, must not wrongly suppress regen the
   moment the design needs it running so the bar can cross the resume threshold, Fact M3).
9. **[headless-provable]** At empty stamina (`6-7/R16`: `is_zero_approx(get_current())`, not merely
   "above `0.0`"), a held run key produces WALK, not a refused/no-op tick — the hero keeps moving, just
   slower, and the R6 latch sets. The spend-clamped drain in AC 7 is what makes stamina actually reach
   the `is_zero_approx` reading of empty rather than sticking on a sub-epsilon residual, so this AC is
   reachable. **The proving test must drive the authored values named in AC 7's `6-7/R16` note
   (`max_stamina = 50.0`, drain `10.0`/s, `>=300` ticks from full) and assert BOTH `is_zero_approx`
   on `get_current()` AND the latch field reading set** — a test built on in-test round-number values
   that happen to hit exact `0.0` would pass while the shipped authored build never reaches this AC at
   all (readiness gate 2 Blocker 1).
10. **[headless-provable]** While the latch is set, RUN does not resume even with the run key held
    and stamina non-zero, until stamina is `>=` the authored `run_resume_stamina_percent` threshold.
    **`6-7/R14`, CLOSED (corrected — the original AC embedded an open question rather than a ruling,
    readiness gate 1 finding B5): resume is AUTOMATIC.** The instant stamina reaches the threshold
    while the key is still held, RUN resumes on the NEXT tick — **corrected (readiness gate 2 note 7):
    "that same tick" is impossible, because `_regen_stamina` runs LATER in `advance()`'s per-tick
    sequence than `_resolve_movement` (`match_state.gd:535/537` vs `:584-585`), so the tick that
    crosses the threshold still resolves movement (and therefore gait) BEFORE regen applies; the
    earliest a crossing can be observed as RUN is the following tick** — no fresh press required, the
    same shape as AC 11's action-cancel resume below (which resumes on the first IDLE tick AFTER the
    action ends, an analogous next-tick shape). A held-but-below-threshold run key produces WALK every
    tick until the threshold is crossed; releasing and re-holding the key while below threshold
    changes nothing (the latch, not the press, gates resume).
11. **[headless-provable]** Entering ATTACKING, ROLLING, or BLOCKING's deflect entry while running
    CANCELS the run for that tick. **Asserted as observable outcomes, not as "enters the action's
    own root" (corrected — readiness gate 1 finding B4: all three attack-phase multipliers are
    authored 0.0, so an attacking hero is already rooted regardless of gait, making "enters its own
    root" true but unfalsifiable):** (i) the per-tick drain (AC 7) stops for the duration of the
    action, (ii) **corrected (readiness gate 2 note 9, self-contradictory as originally worded) — the
    running-specific regen-suppression disjunct (AC 8) genuinely LIFTS for ATTACKING and ROLLING
    (neither carries any other suppression reason, so regen may resume there once the running-specific
    disjunct no longer applies); for BLOCKING the running-specific disjunct is moot rather than
    "lifting" — BLOCKING is suppressed anyway by its own, independent disjunct, so nothing observably
    changes at the suppression boolean when a blocking hero's running-suppression clause turns off**,
    and (iii) for BLOCKING
    specifically, speed visibly changes (AC 16 below: BLOCKING moves at walk speed regardless of the
    run key, so entering it while running is itself a speed-drop, observable without touching the
    zero-multiplier swing). On exit back to a state where movement is read normally, RUN RESUMES BY
    ITSELF if the run key is still held — observable as a same-tick jump from walk-speed (2.5) to
    run-speed (5.0) velocity magnitude on the first IDLE tick after the action ends — no re-press, no
    latch set merely by the cancel (the latch is a stamina-emptiness fact only, per R6, not an
    action-entry fact).
12. **[headless-provable]** Open decision (c) is formally retired: `GamepadProfile.
    normalize_move_magnitude`, `resolve_move_dir`'s third parameter and false-branch, the debug
    panel's "Normalize analog magnitude" switch and its handler, `data/gamepad_profile.tres:13`, and
    every test named in Fact M4 are deleted or updated (the two `test_gamepad_controller.gd` tests
    removed outright — they test a retired behavior, not a renamed one — and
    `test_record_save_control.gd:177`'s name list trimmed to three). `resolve_move_dir` reverts to
    ALWAYS normalizing above the deadzone (the pre-2-6 behavior), matching keyboard parity again.
    Stick magnitude is NOT repurposed for gait — gait stays the discrete run-key choice R8 rules.
13. **[headless-provable]** `test_data_resources.gd`'s `E1_BALANCE_FIELDS` list and
    `test_balance_authoring.gd`'s non-negativity/authoring audits are extended to cover the three
    new fields (Fact: this list is hand-maintained and silently unaudited fields have shipped before
    — `attack_stamina_cost`/`block_facing_arc_degrees`, named in that file's own history at
    `test_data_resources.gd:38-43`). **What the audits must assert, named (readiness gate 1 note 5 /
    readiness gate 2 note 9, the original AC never said):** `walk_speed > 0.0` (a zero walk speed
    freezes the hero at empty stamina with no gait to fall back to); `walk_speed <= move_speed` (walk
    is never faster than run, the whole premise of the two-gait system); and
    `0.0 < run_resume_stamina_percent <= 100.0` (a zero or negative threshold would make the latch
    resume before it can ever be observed set, and a value over 100 would make it never resume).
14. **[smoke-only]** Live smoke per the Live Smoke section below.
15. **[headless-provable]** Full suite green before and after; golden hash measured in both
    directions with the ONE predicted cause (Fact M6, Direction B) confirmed as the actual and only
    cause. **`FORMAT_VERSION` confirmed BUMPED to 11 (corrected — the original text required
    confirming it unmoved, an assertion that could not fail; readiness gate 1 finding B1), plus a
    headless test confirming a v10 record is refused with a reason** on the
    `test_a_v9_record_without_card_activate_is_refused_with_a_reason` shape — **corrected (readiness
    gate 2 note 2): only that test's VERSION-REFUSAL half transfers as precedent, not its field-strip
    half.** The v9 precedent's second half (relabel the stripped body at the CURRENT version, get
    refused instead for the missing field BY NAME) relies on `REQUIRED_INTENT_FIELDS`
    (`record_file.gd:269`), which does not and should not cover `&"run"` (a `held` dictionary key,
    round-tripped as a whole dictionary per Fact M6) or `walk_speed` (a config value `_rebuilt` sets
    only if present, `record_file.gd:809-822`) — a v11-labelled body missing either one LOADS without
    complaint under today's field-presence checks. This story's v10-refusal test proves only that a
    body correctly labelled v10 is refused for its VERSION; it does not need to, and must not, also
    prove a field-strip refusal that `REQUIRED_INTENT_FIELDS` was never asked to cover.
16. **[headless-provable]** `6-7/R10`, NAMED SEPARATELY (not folded into AC 6, per the prompt's
    ruling that this is a player-facing speed change and must be its own AC plus its own Live Smoke
    step, readiness gate 1 finding B4): while `action_state == BLOCKING`, the hero moves at
    `balance.walk_speed` REGARDLESS of whether the run key is held — today a blocking hero falls
    through to the generic `else` branch and moves at full `move_speed` (5.0); after this story it
    moves at `walk_speed` (2.5) unconditionally. Reason (Dev Notes carries the full reasoning, this
    AC states only the rule): BLOCKING already suppresses regen (`match_state.gd:2382-2384`), so
    letting it also run at full speed would put two different stamina policies on one action state.
17. **[headless-provable]** Named separately for the regen-delay seat (`6-7/R15`, readiness gate 1
    finding B3): after the last actually-running tick (AC 7's predicate — now excluding ATTACKING too,
    `6-7/R17` — going false), stamina regen stays suppressed for the standard post-spend delay window.
    **Corrected, off-by-one (readiness gate 2 note 8): NOT "exactly `stamina_regen_delay_ticks` ticks"
    — the window counts the spend tick itself** (`stamina_pool.gd:57-62`, `timing_window.gd:35-40`),
    so regen stays at `0.0` for the last running tick plus `stamina_regen_delay_ticks - 1` further
    ticks (47 further ticks at the authored 48-tick window) before resuming on the tick that follows.
    Assert that exact count, not the AC's original off-by-one phrasing — the same felt pause as after a
    roll/attack/deflect spend, delivered by AC 7's `spend()`-based drain seat restarting the
    regen-delay window on every running tick.

## What this story supersedes

- **The `5-3/R6(d)` retune entry** (locomotion speed / walk-as-default / sprint-costs-stamina) —
  same ground, closed by `E6-P/R3`'s ruling rather than left deferred. No further action needed on
  it; it should be struck from `deferred-work.md`'s live E5-residue list by whichever story or pass
  next touches that file (not this one's file list — this story does not edit `deferred-work.md`).
- **Open decision (c)** — variable analog magnitude at partial stick deflection (`2-2/R5`, carried
  through `2-6`/`3-0b` without adoption, confirmed moot for DEBT E purposes at
  `epic-3-retro-2026-08-06.md:276`). R8's ruling: "two gaits are the answer to the question (c) was
  asking" — gait is now a discrete, authored, player-chosen state (walk/run), never a function of
  how far the stick is pushed. `normalize_move_magnitude` and its toggle die with it (AC 12, Fact
  M4). **DEBT E registry note:** decision (c) was never formally admitted to the DEBT E
  animation-gate registry (`1-10/R4`) — it was tracked as an open decision with `2-6` as forcing
  point, and the E2 retrospective's own admission question was answered "moot" once `3-0b` shipped
  its KEEP verdict without adopting variable magnitude. This story's retirement is therefore closing
  an open DECISION, not discharging a DEBT E member; DEBT E's own registry is unaffected and should
  not list this story as a closure.

## Non-Goals

- Zero presentation work. No `UnitAnimationController` or hero animation path touched — that is
  `6-7b`, gated on the Mixamo walk clips (`E6-P/R10`).
- No camera work (`6-8`).
- No change to roll, attack, or deflect SEMANTICS beyond the cancel/resume rule (AC 11) **and the
  BLOCKING-forces-walk rule (AC 16, `6-7/R10`)** — corrected (readiness gate 2 note 15): AC 16 changes
  what speed BLOCKING moves at, which is a movement-policy change, not a deflect-timing or
  defense-window change; this exemption keeps that distinction explicit so AC 16 is never mistaken for
  a forbidden deflect-semantics change.
- Mode ② hold-to-charge stays on B, unblockable_raw read bare
  (`gamepad_controller.gd:436-438`) — running is not added to that chord and B is not touched.
- No `deferred-work.md` edit (see "What this story supersedes" above — named, not performed here).

## Deferred

- ~~The exact keyboard binding for `p1_run`/`p2_run`~~ — CLOSED, FINAL by `6-7/R18`: `p1_run` = Space,
  `p2_run` = NUMPAD 0 (superseding the intermediate `6-7/R6-STRUCK` Right-Ctrl ruling, struck per readiness
  gate 2 Blocker 4's false-premise finding). No longer deferred; struck here on the same pattern as the
  two items below. See AC 3.
- ~~Whether the resume-at-threshold rule needs a fresh press or resumes automatically~~ — CLOSED by
  `6-7/R14`: automatic, no re-press (resuming on the next tick after the threshold crossing —
  corrected, readiness gate 2 note 7, see AC 10). No longer deferred; struck here per readiness gate 1
  finding B5, see AC 10.
- ~~Whether `run_stamina_drain_per_second` should gate on affordability via the `StaminaPool.add()`
  floor~~ — CLOSED by AC 7's ratified drain seat (readiness gate 1 finding B3): `add()` never starts
  the regen-delay window, so it cannot deliver R5's release delay; the seat is `spend()` with the
  requested amount clamped to `get_current()`, which reaches an honest empty reading (`6-7/R16`,
  `is_zero_approx`) without ever needing a separate affordability pre-check. No longer deferred, and
  the dev pass must NOT use the `add()` floor this item originally pointed at.
- **A future melee/playtest retune pass** inherits nothing new from this story — R4's numbers are
  explicitly "judged at playtest like the pitch timer," so both `walk_speed` and
  `run_stamina_drain_per_second` are provisional exactly as the pitch timer was at `E6-P/R5`.

## Golden Prediction

**FORMAT_VERSION: RATIFIED to bump 10 -> 11** (`6-7/R12`, Fact M6 Direction A — corrected: the
story's original prediction rested on the false claim that `6-1`'s `&"card_cast"` held-key addition
shipped without a bump; `record_file.gd:158` states directly that it bumped 7->8 on SEMANTICS, and
this story's `&"run"` key is the same silent-divergence shape, now doubled by the co-arriving
`walk_speed` field a v10 record would silently default to `0.0`, readiness gate 1 finding B1). The
dev pass bumps the constant, adds the v10-refusal test named in AC 15, and measures
`record_file.gd:187` / `test_record_file.gd`'s pinned assertion directly before and after to confirm
the bump landed exactly once and to the intended value.

**Golden hash: predicted TO MOVE, with ONE named cause.** The new `HeroState` gait-lockout latch
(AC 5) is a genuinely new hashed member reaching `to_snapshot()` through the existing chain — every
tick's hash changes the moment it exists, on the `lock_target_slot`/`charge_window` precedent
(`test_replay_identity.gd:144-165`: crosses ticks, decides an outcome, therefore HASHED, no
`UNHASHED_CROSS_TICK_MEMBERS` bump). `walk_speed`/`run_stamina_drain_per_second`/
`run_resume_stamina_percent` themselves are authored balance VALUES, not new state members — per
the standing `BC/R3` isolation (memory: authored balance is isolated from both the golden and the
unit suite), they alone would NOT move the golden; the latch field is the one and only mover. The
dev pass must measure before/after and confirm this is the actual, sole cause (the `E3-RG/R2`
discipline every prior golden-moving E6 story has followed).

## Live Smoke

**Binding-flip safety procedure, REPLACED WHOLESALE (`6-7/R19`, readiness gate 2 Blocker 3): the
smoke runs on TWO GAMEPADS, not the `KEYBOARD_P2`-equivalent flip the story originally described.**
Gate 2 measured that the original text was unexecutable as written: `main.tscn` carries no
`slot_controller_kinds` line at all today (grep-confirmed), the shipped default lives purely in
`match_runner.gd:31-34`'s `@export` default (`[KEYBOARD_P1, KEYBOARD_P2]`), and a "`KEYBOARD_P2`
flip" is a no-op regardless — pad steps need slot 1 (and, under this ruling, slot 0 too) actually set
to `ControllerKind.GAMEPAD` (`match_runner.gd:29`'s enum: `KEYBOARD_P1=0, KEYBOARD_P2=1, NULL=2,
GAMEPAD=3`), the `6-1c` flip's actual shape (`6-1c-unblockable-tracking-and-reach.md:192,199`: flip
`[0,3]` textually, editor closed, `git diff` immediately after). The operator plays this smoke on two
physical controllers, so **both runner slots flip to GAMEPAD** — `slot_controller_kinds = [3, 3]` —
rather than the single-slot `[0,3]` shape 6-1c used, and every step below (including the ones a
keyboard would otherwise cover) is performed on a pad. **No keyboard step is required at all.**

Procedure, on the `2-1/R2`-amended per-file-sorting form (readiness gate 1 finding B7 — the verbatim
`6-1c` blanket revert is still forbidden here, for the reason below):
1. With the Godot editor CLOSED, TEXT-EDIT `main.tscn` to ADD a `slot_controller_kinds = [3, 3]` line
   on the `MatchRunner`/`Main` node's property block (there is none today, so this is an addition, not
   an edit-in-place — confirm by grep before editing that no such line exists, matching gate 2's
   measurement).
2. `git diff -- src/main/main.tscn` immediately after, and report it verbatim in chat.
3. Run the smoke steps below with two pads connected, pad 1 driving P1's hero and pad 2 driving P2's.
4. Revert `main.tscn`: this story makes no other intentional change to it, so it MAY be reverted
   wholesale (`git checkout -- src/main/main.tscn`) once the smoke is done.
5. `project.godot` MAY NOT be reverted wholesale under any circumstance this story — it carries the
   INTENTIONAL `p1_run`/`p2_run` edit from Task 2, and a blanket `git checkout -- project.godot` would
   destroy it alongside any flip collateral. It must be sorted per-diff, keeping the `p1_run`/`p2_run`
   hunks and discarding only genuine collateral (there should be none, since the flip in this smoke
   lives entirely in `main.tscn`).
6. Before Step 0 of any commit chain following this smoke, confirm no Godot editor process is running
   (`Get-Process *godot*`) per the standing rule adopted after the 2-1 incident, and confirm by direct
   read that `main.tscn` no longer carries the `slot_controller_kinds` line.

Cover, in order (all steps on pad, per `6-7/R19`):

1. Walking is the default with no run key held (visibly slower than the pre-story speed, if a prior
   build is available for comparison; otherwise judge against the authored 2.5 vs. 5.0 ratio).
2. Holding A on either pad produces the faster, familiar speed on that hero — today's speed,
   unchanged. **Corrected (readiness gate 2 Blocker 3): the keyboard half of this step is DELETED, not
   rewritten — `6-7/R19` replaces the whole flip with a two-pad smoke, so there is no keyboard leg to
   cover.**
3. The stamina bar visibly drains while running and does not regenerate while held (watch it hold
   flat or fall, never rise, for the whole hold).
4. Releasing run: the bar sits for ~0.8 s (the standard delay) before regenerating, same felt pause
   as after an attack/roll/deflect — reachable now that AC 7's `spend()`-based drain seat restarts
   the delay window on every running tick (readiness gate 1 finding B3; the story's original text
   pointed at a mechanism, `StaminaPool.add()`, that never starts this delay).
5. Draining the bar to empty while running: the hero visibly drops to walk pace WITHOUT letting go
   of the run key, and re-holding/continuing to hold produces no speed-up until the bar visibly
   refills to roughly a fifth full — resume is automatic per `6-7/R14` (AC 10), on the next tick after
   the threshold is crossed, no re-press needed.
6. Attacking and rolling while running: the swing/roll plays exactly as it does at rest (no visible
   change — the multipliers are already 0.0 / the roll speed is unchanged), and releasing back to
   IDLE with run still held resumes running immediately, no extra press.
7. **Blocking while holding run (`6-7/R10`, AC 16 — NAMED STEP, corrected: the original Live Smoke
   omitted BLOCKING entirely, readiness gate 1 finding B4):** hold block with the run key also held;
   the hero moves at walk pace (2.5), never the full run speed (5.0), for the whole hold.
8. On either pad, holding L3 (the cast modifier) and pressing A: a BASIC card confirms and the hero
   does NOT run, confirming R1's fallout is honoured (bare A only drives running OUTSIDE `cast_held`).
9. FPS/feel sanity: no stutter or visible pop switching gaits.

## Tasks / Subtasks

- [x] Task 1 — Author `walk_speed`, `run_stamina_drain_per_second`, `run_resume_stamina_percent` on
      `BalanceConfig` + the derived `run_stamina_drain_per_tick` on `BalanceTicks`; author the
      `.tres` values (AC 1, AC 2).
- [x] Task 2 — Add `&"run"` to `INTENT_ACTIONS`; author `p1_run` = Space, `p2_run` = NUMPAD 0 in
      `project.godot`, RATIFIED, FINAL by `6-7/R18` (AC 3; supersedes the earlier `6-7/R6-STRUCK` Right-Ctrl
      ruling, struck per readiness gate 2 Blocker 4). The `project.godot` edit discipline, moved here
      as explicit steps from AC 3's prose (readiness gate 1 finding G11, corrected — the original
      text carried this only as process prose inside a headless-tagged AC, which is not
      delivered-software evidence):
      (a) edit `project.godot` in a TEXT EDITOR, with the Godot editor CLOSED for the whole edit;
      (b) run `git diff project.godot` IMMEDIATELY after, and report it verbatim in chat;
      (c) confirm by direct read that `common/physics_ticks_per_second=60` at `project.godot:187`
          survived the edit — known editor-collateral signatures to check for: key reordering,
          dropped duration pins, added `uid` attributes;
      (d) confirm the diff contains ONLY the two new `p1_run`/`p2_run` blocks — nothing else moved.
- [x] Task 3 — Gamepad: `resolve_card_tick()` returns `run_held = basic_raw and not cast_held` on
      the existing pattern; `sample()` writes it to `intent.held[&"run"]` (AC 4).
- [x] Task 4 — `HeroState`: add and snapshot the gait-lockout latch; resolve gait in
      `_resolve_movement` before the existing speed read, including the BLOCKING-forces-walk case
      (AC 16); wire the stamina drain via the clamped `spend()` seat and the `_regen_stamina`
      suppression disjunct, both driven by the single "actually running" predicate (Dev Notes); wire
      the cancel/resume rule for attack/roll/deflect entry, asserted by observable outcome (AC 11);
      add the headless regen-delay assertion (AC 17) (AC 5-11, AC 16, AC 17).
- [x] Task 5 — Retire `normalize_move_magnitude` end to end: field, call site, panel switch and
      handler, `.tres` line, both `test_gamepad_controller.gd` tests, `test_debug_instruments.gd`'s
      `_magnitude_ok` block (declared `:64`, checked `:184-192`, folded into the composite `ok` at
      `:139-144`), `test_record_save_control.gd:177-181`'s name list AND its message text; note in
      Completion Notes that `match_runner.gd:462`'s `panel.gamepad_profile = load(...)` becomes a
      dead assignment (its only reader is gone) but is left in place rather than deleted, since the
      panel still needs constructing for its other controls; revert `resolve_move_dir` to
      always-normalize (AC 12, Fact M4). **Restored (readiness gate 1's own dropped item, re-flagged
      by readiness gate 2 Part A, B6): retiring the "Switch 1" `CheckButton` (`:171-176`) leaves the
      `Switches` `VBoxContainer` (`debug_instrument_panel.gd:164-169`) EMPTY — it was built to hold
      that one switch and no other. Also fix the layout comment at `:214-220`, which still describes
      "the two-row Switches column" for sizing the neighboring `RecordControls` column — that
      description becomes stale once Switches holds nothing. Whether `_check_panel_layout`
      (`test_debug_instruments.gd:117`) survives an empty column is UNMEASURED (readiness gate 1 note
      6(g)) and must be checked by the dev pass: either the empty `VBoxContainer` collapses to
      zero-size cleanly and the geometry assertion still passes, or the column needs an explicit
      minimum-size fix named here rather than discovered as a test failure.**
- [x] Task 6 — **(AC 14, AC 15)** Named separately per Fact M5's blast-radius finding, corrected per readiness gate 1
      finding B2 (the original Task 6 prescribed `&"run": true` everywhere, which would drain
      stamina in files that assert it).** File-by-file, not a shared utility (none exists):
      (a) In the 8 `test/state/*.gd` files named in Fact M5(a), author `walk_speed` EQUAL TO THAT
          FILE'S OWN `move_speed` (not a literal `5.0` — per-file values listed in M5(c)), making
          gait a no-op so existing velocity assertions hold with no `&"run"` key pressed.
      (b) Retune `walk_speed` alongside every mid-run `move_speed` retune, named individually in
          M5(d): `test_replay_identity.gd:780`, `test_record_file.gd:1216`, `test_live_reload.gd:327`.
      (c) Author `walk_speed` in `test_determinism.gd`'s `_golden_config()` (`:1200-1203`), so the
          golden moves for exactly the one named cause (Fact M6 Direction B) and not a second.
      (d) Fix `test/integration/test_hero_movement.gd:25,52` (reads the authored `.tres`, so the
          local-config substitution cannot reach it) to either press `p1_run` or assert against
          `walk_speed`; **fix `test_unit_approach_live.gd`'s walk-window sizing (`_hero_speed` set from
          `balance.move_speed` at `:147`, consumed by `_derive_walk_frames` at `:369-374`) — corrected
          (readiness gate 2 note 6): this is CONFIRMED LIKELY TO FAIL at the authored 2.5 walk speed,
          not merely an unmeasured risk, since `_hero_speed` reads the RUN speed while the hero
          actually walks during this window. Re-derive `_hero_speed` (or the window it feeds) from the
          walk-gated speed the hero actually uses during the approach's walk phase, and confirm the
          test passes at the authored values before calling Task 6 done.**
      (e) Give `test_match_state.gd`'s `test_analog_input_clamped_to_move_speed` (`:56-59`) its own
          config (`walk_speed != move_speed`) and a run-held path, per Fact M5(g) — do not fold it
          into the blanket (a) fix; also author `walk_speed` on `test_match_state.gd`'s second shared
          config, `_b1_match` (`:185`, asserted `:254`), per Fact M5(g)'s note (gate 2 note 5).
      `test_lock_on.gd`, `test_totem_accelerators.gd`, `test_visible_facing.gd`, `test_lock_on_live.gd`
      and `test_block_deflect.gd` are NOT in scope for this task (Fact M5(a), corrected).
- [x] Task 7 — Extend `test_data_resources.gd`'s `E1_BALANCE_FIELDS` and
      `test_balance_authoring.gd`'s audits for the three new fields (AC 13).
- [x] Task 8 — Bump `RecordFile.FORMAT_VERSION` 10 -> 11 (`src/systems/record_file.gd:187`), update
      `test_record_file.gd:170-171`'s pinned assertion to 11, **and its SECOND pin at
      `test_record_file.gd:832` (5-1a's test) — corrected (readiness gate 2 note 1): the story's
      original text named only `:170-171` and missed this second pin, which also asserts
      `FORMAT_VERSION == 10` and also fails the moment the bump lands.** Add a v10-refusal test on the
      `test_a_v9_record_without_card_activate_is_refused_with_a_reason` shape, **proving ONLY the
      VERSION-REFUSAL half of that precedent (AC 15's correction) — do not also assert a field-strip
      refusal for a missing `run`/`walk_speed` key, since `REQUIRED_INTENT_FIELDS` was never asked to
      cover either one and a v11-labelled body missing them loads without complaint today.** Golden
      hash measured both directions with the gait-lockout latch confirmed as the ONE cause (AC 15).
- [x] Task 9 — **(AC 14, AC 15)** Named breakage surfaces, each its own fix (readiness gate 1 finding B6, corrected —
      the story's original text did not name these): `test_deck_and_hand.gd:478-491`'s
      `SHIPPED_INPUT_ACTIONS` pin gains `p1_run`/`p2_run`; `test_debug_window_countdown.gd:107-109`'s
      pinned hero-snapshot key list gains the latch field's name; `test_replay_identity.gd:245-248`'s
      `HASHED` list gains the latch field, on the `lock_target_slot` entry's exact shape (Fact M6
      Direction B).
- [x] Task 10 — **New (readiness gate 2 Blocker 5, `6-7/R20`).** Godot's built-in `ui_accept`/
      `ui_select` actions are bound to Space by engine default, and `project.godot` does not rebind
      them (measured). The debug panel's `Button`/`CheckButton` nodes — `SaveRecord`
      (`debug_instrument_panel.gd:226`), `ReloadBalance` (`:231`), `RevealOpponentHand` (`:256`) — are
      built with the engine's default focus mode, and nothing in `src/` sets `focus_mode` or calls
      `grab_focus` on them (measured, grep). **The dev pass MEASURES FIRST, live, whether a
      mouse-focused panel button actually re-fires when `p1_run` (Space) is pressed during play** — the
      concrete worry is a live RELOAD click leaving RELOAD focused, after which every Space press
      (i.e. every P1 run-key press) re-fires a live balance reload, refilling stamina to max
      (`test_live_reload.gd` AC 9) and polluting whatever the operator is testing. **If it reproduces:**
      set `focus_mode = FOCUS_NONE` on all three buttons — a debug panel button has no business holding
      keyboard focus. **If it does not reproduce:** change nothing, and report the negative result.
      Either way this is a named, bounded item, not a rebind of `p1_run`. **No AC number: the review
      checks this by the same measurement, not by re-deriving one — that the focus behaviour was
      measured live, and that `focus_mode` was changed if and only if the defect reproduced.**
      **RESOLVED via the Live Smoke (operator, 2026-09-16, see Live Smoke result below): REPRODUCES,
      and WIDER than predicted — any last-clicked debug-panel button (not only `ReloadBalance`)
      retains keyboard focus and re-fires on Space. Fix applied per the story's own ruling:
      `focus_mode = Control.FOCUS_NONE` set on all three panel buttons at their construction sites in
      `src/ui/debug/debug_instrument_panel.gd` — `save` (`:225`), `reload` (`:231`), `toggle`
      (`:258`). See Debug Log.**
- [x] Task 11a — Full suite green before and after (AC 14, AC 15).
- [x] Task 11b — Live smoke per the amended procedure above (AC 14). **Split from the original
      single Task 11 checkbox by the fix pass, per review finding 3: the suite half is evidenced
      (foreground runs, both directions), the live-smoke half has not happened — no smoke record,
      no `main.tscn` flip diff and no step-by-step result exist anywhere in this story. Stays
      unchecked until the smoke actually runs.**
      **DONE — smoke record (operator, 2026-09-16), config `[0, 3]` — P1 keyboard, P2 pad —
      DEVIATING from `6-7/R19`'s two-gamepad procedure above; reason given: single operator, every
      pad step is coverable on one pad, and the keyboard half gave the `p1_run` Space binding
      (AC 3) a live check a two-pad run would not have. Steps 1-7 and 9 ALL PASS, including the
      keyboard walk/run split on Space (AC 3 live), the ~20% resume threshold engaging and
      resuming without a re-press (AC 10), the 0.8s release delay (AC 7), cancel/resume across
      attack and roll (AC 11), BLOCKING at walk with no drain (AC 16), and the L3+A card confirm
      with no running. FPS stable. Step 8 / TASK 10: REPRODUCES, and WIDER than predicted — any
      last-clicked debug-panel button retains keyboard focus and re-fires on Space, not only
      `ReloadBalance`. Fixed per Task 10 above — see there and the Debug Log.**

## Dev Notes

### Reuse and precedent map (do not re-derive these)

- Held-key addition: `INTENT_ACTIONS` loop, `keyboard_controller.gd:13-97` (M2). Pad-side
  equivalent: the `attack_held`/`block_held`/`roll_held` triple already computed at
  `gamepad_controller.gd:430-435`, and the `&"card_cast"` held-key-on-an-existing-dictionary
  precedent at `gamepad_controller.gd:206-210` (`6-1` AC 1/2/5) for why this is a dictionary entry,
  not a new `InputIntent` field.
- Suppression-seat extension: `_regen_stamina`'s `suppressed` OR-chain, `match_state.gd:2382-2384`
  (`5-2/R4` added CHARGING the same way).
- Seconds→ticks derivation: `BalanceTicks.from_config()`, `balance_ticks.gd:127-131`
  (`stamina_regen_per_tick` is the exact shape to copy for `run_stamina_drain_per_tick`).
- Percent-of-max authoring convention: `attack_damage_percent_of_max_hp`, `balance_config.gd:26`
  (0-100 scale).
- Cross-tick hashed-vs-unhashed classification test: `test_replay_identity.gd:126-165` (`pitch_
  state._orb_costs` is the one UNHASHED_CROSS_TICK example; `lock_target_slot`/`charge_window`/
  `defense window` are the HASHED examples this story's new latch matches).
- Retirement precedent (delete-with-a-name, not silent): `6-3b`'s retirement of the `2-6`
  pitch-placement switch (`debug_instrument_panel.gd`'s own header, "RETIRED by story 6-3b (AC 7)")
  is the exact shape AC 12 follows for `normalize_move_magnitude`.

### Why `move_speed` is not renamed to `run_speed`

Renaming would touch every one of the ~40+ non-test and test sites that already read/write
`BalanceConfig.move_speed`/`HeroState.move_speed` (`_apply_balance_to_player`, `_resolve_movement`,
`to_snapshot()`, and dozens of test fixtures), none of which need to change meaning — they all
already mean "the hero's move speed while not doing anything special," which after this story is
exactly "the run speed." Adding `walk_speed` alongside is strictly additive and keeps the blast
radius to the tests Task 6 already has to touch for a different reason (the default-gait flip, Fact
M5) rather than doubling it with a pure rename. This is a HOW decision under CLAUDE.md's autonomy
test (an implementation choice, not a new public API or a player-facing semantic change) and is
made here rather than escalated; if a future reviewer disagrees, `move_speed` can be renamed in a
follow-up with no design implication either way.

### "Actually running" — the one named per-tick predicate (`6-7/R13`)

Added per readiness gate 1 finding B4: every AC that reads "actually running" (AC 7, AC 8, AC 9,
AC 17) means EXACTLY this, stated once rather than re-derived per site. **Amended per readiness gate
2 (Blockers 1-2, `6-7/R16`/`6-7/R17`): clause (3) now also excludes ATTACKING, and clause (5) is
restated in terms of `is_zero_approx` rather than a raw `> 0.0` comparison:**

> A hero is ACTUALLY RUNNING on a tick iff ALL of: (1) the run key is held (`intent.held[&"run"]`);
> (2) `intent.move_dir` is non-zero after deadzone (`6-7/R3` — holding run while stationary drains
> and suppresses nothing); (3) `action_state` reads movement normally, i.e. is none of
> ATTACKING/ROLLING/CHARGING/STUNNED/BLOCKING (`6-7/R9`/`R10`/`R17` — BLOCKING is forced to walk, the
> other three are hard-rooted, ATTACKING is added because AC 11(i)/(ii) require its drain and
> running-suppression to stop, and none of the five is "running" regardless of the key); (4) the R6
> gait-lockout latch is unset; (5) `not is_zero_approx(player.stamina.get_current())` — **corrected,
> `6-7/R16` (readiness gate 2 Blocker 1): NOT "stamina is above `0.0`".** `StaminaPool.add()`
> (`stamina_pool.gd:29-31`) skips any delta smaller than Godot's `is_equal_approx` tolerance, so a raw
> `> 0.0` reading of clause (5) lets the pool stick on a sub-epsilon residual (measured: `1.649e-13`
> after 300 ticks of continuous running at the authored values) and never actually reach the state AC
> 9/10/17 require. `is_zero_approx` is the reading that matches how the pool itself decides "did this
> change actually happen."

Its natural seat is the generic `else` branch of `_resolve_movement` (`match_state.gd:3830-3843`,
alongside the existing gait-selection branch from AC 6), which is exactly where AC 7's drain and
AC 6's speed selection already have to read it. The SAME fact must reach `_regen_stamina`
(`match_state.gd:2382-2425`) for AC 8's suppression disjunct — a later step of `advance()` than
`_resolve_movement` — either via a per-tick carrier field (Open Question 5 below) or by recomputing
the identical predicate at both sites from the same inputs; the two must never diverge.

### Struck: the Right-Ctrl consequence this story no longer accepts (`6-7/R6-STRUCK`, superseded by `6-7/R18`)

Kept for history, not solved-and-carried-forward. The prior pass accepted LEFT Ctrl also firing
`p2_run` because every binding in this project uses `"location":0` (no binding anywhere distinguishes
Left/Right key variants — measured, AC 3) and Right Ctrl's binding therefore fires on EITHER physical
Ctrl key, including P1's left one. **That acceptance rested on a false premise (readiness gate 2
Blocker 4): it reasoned from the DELIVERED config (P1 keyboard, P2 pad, "no human hand is ever on the
p2 keyboard cluster"), but the SHIPPED DEFAULT before any config change is two keyboards
(`match_runner.gd:31-34`), where P1's left hand sits directly next to Left Ctrl — pressing it would
make P2's hero run and drain P2's stamina, an actual accident in the shipped default, not merely a
theoretical one.** `6-7/R18` replaces `p2_run`'s key with NUMPAD 0, which has no Left/Right variant at
all — there is no consequence left to accept. This project still has no location-aware binding scheme
anywhere, and this story still does not introduce one; `6-7/R18` sidesteps the whole class of
consequence instead by picking a key that cannot collide.

### Open Questions for the dev pass (named, not pre-ruled)

Corrected per readiness gate 1: items 2 and 3 below were ruled by the operator (`6-7/R14`, `6-7/R6-STRUCK`,
the latter now superseded by `6-7/R18`) and are no longer open to the dev pass; struck and replaced
with the narrower questions that remain.

1. **The exact gait-latch field name** — AC 5/AC 7 name the seat (`spend()`, clamped) and the
   mechanics; only the FIELD NAME is left to the dev pass. Whichever name is picked, it must never
   introduce a second stamina-mutation seat outside the ones `StaminaPool` already exposes.
2. ~~Resume-on-threshold timing~~ — CLOSED, `6-7/R14`: automatic, resuming on the next tick after the
   threshold crossing (corrected, readiness gate 2 note 7). See AC 10.
3. ~~`p2_run`'s exact key~~ — CLOSED, FINAL, `6-7/R18`: `p1_run` = Space, `p2_run` = NUMPAD 0. See
   AC 3.
4. **Whether the gait computation belongs in `_resolve_movement` directly or as a small extracted
   pure helper** (the `_attack_phase_multiplier` precedent, its definition at `match_state.gd:3910`
   — corrected citation, gate finding B4) — a style choice, not a correctness one.
5. **Where the single "actually running" predicate (Dev Notes above — corrected, readiness gate 2
   note 11: the predicate section precedes this one, not "below") is computed and how the same fact
   reaches `_regen_stamina`** — a per-tick carrier written in `_resolve_movement` and read back in
   `_regen_stamina` (needing a PER_TICK classification entry in `test_replay_identity.gd`), or a
   recompute of the identical predicate at both call sites. Either is acceptable; the two call sites
   must never derive the fact independently in a way that could disagree.

### Project Context Rules

- **F1**: no new `_physics_process` — this story's per-tick work lands inside the existing
  `advance()`/`_resolve_movement`/`_regen_stamina` call chain.
- **D3(a)**: the two new held-input reads (`p1_run`/`p2_run`, bare A on pad) live entirely in
  `src/controllers/` — `test_input_only_in_controllers` (`test_architecture_invariants.gd:21-30`)
  must stay green with no new exemption.
- **D3(b)/A2**: no RNG/Time/OS/Engine reads are introduced by any of this story's `src/state/`
  changes — the gait computation is a pure function of `intent.held`, `player.hero`, `balance`, and
  `balance_ticks`.
- **CLAUDE.md commit conventions**: docs and code in separate commits; `git commit -F <tempfile
  outside the repo>`; PowerShell (no `&&`); pure ASCII; trailer
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` per this session's attribution override.
- **Git discipline**: full diff shown before staging; `git add`/`git commit` as separate, explicit-path
  commands; no push until the operator confirms the log in chat.
- **Story tiers**: Tier A confirmed above — full gate + review + live smoke ritual required before
  `done`.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:9318-9327 —
  `E6-P/R3`, the ratified two-gait ruling]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:9367-9369 —
  `E6-P/R8` amendment (ii), 6-7b is the presentation half, not a deferred item]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:226-230, :291 — board
  entry text and the `5-3/R6(d)` supersession]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md:139, :158 — stamina
  spend list already includes Run; controls list already reads "move (walk by default), run (hold)"]
- [Source: src/state/match_state.gd:3749-3920 — `_resolve_movement`, the one movement seat]
- [Source: src/state/match_state.gd:2382-2425 — `_regen_stamina`, the D6 suppression policy seat]
- [Source: src/state/pools/stamina_pool.gd:61-64 — `advance_regen`'s `suppressed` mechanism]
- [Source: src/state/timing/balance_ticks.gd:127-131 — `from_config()`'s seconds→ticks derivation]
- [Source: src/controllers/keyboard_controller.gd:13-97 — `INTENT_ACTIONS` held-key precedent]
- [Source: src/controllers/gamepad_controller.gd:206-210, :430-489 — the `card_cast` held-key
  precedent and the confirm/held resolution block `run_held` follows]
- [Source: test/state/test_replay_identity.gd:126-165 — hashed vs. unhashed cross-tick
  classification test]
- [Source: test/state/test_record_file.gd:170-171 — the pinned `FORMAT_VERSION == 10` assertion]

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-09-15 | 0.1 | Story authored (backlog, awaiting operator review): two-gait system per `E6-P/R3`, walk/run balance fields, keyboard+pad input wiring, stamina drain/suppression via the existing D6 seat, cancel/resume across attack/roll, the normalize_move_magnitude retirement (open decision (c) close-out), and the M5 test-migration obligation named as its own task. Golden predicted to move (one cause: the new gait-lockout latch); FORMAT_VERSION predicted unmoved at 10. | Claude Sonnet 5 |
| 2026-09-15 | 0.2 | Docs-only fix pass against readiness gate 1 (`C:\dev\_6-7-gate.md`, verdict NOT READY, 7 blockers). Operator rulings R1-R7 folded in. FORMAT_VERSION reversed to RATIFIED BUMP 10 -> 11 (B1, the story's `6-1` history claim was false) with a v10-refusal test named. Fact M5 and Task 6 rewritten: wrong file list corrected, the blanket `&"run": true` fix replaced with the ratified "walk_speed = that file's own move_speed" rule plus five named sub-items (B2). The stamina drain seat picked (`spend()`, clamped to `get_current()`) to deliver both the 0.8s release delay and an honest arrival at zero, with a new headless AC (AC 17) proving the delay (B3). A single named "actually running" per-tick predicate added to Dev Notes, referenced by every AC that used the phrase; STUNNED named in Fact M1/AC 6; a new AC 16 gives BLOCKING-forces-walk its own criterion and Live Smoke step (R2); AC 11 rewritten to assert observable outcomes instead of "enters the action's own root" (B4). AC 5's `>=`/`>` ambiguity closed; AC 10 closed to automatic resume, no re-press (R4); AC 3 corrected (INTENT_ACTIONS does not produce Input Map actions) and `p2_run`'s key left explicitly awaiting the operator's `6-7/R6` ruling, with the keyboard cluster measured and one proposal offered, Task 2 marked blocked on it (B5, R6). Named breakage surfaces added as Task 9 (`test_deck_and_hand.gd`, `test_debug_window_countdown.gd`, `test_replay_identity.gd` HASHED list, `match_runner.gd:462`); wrong line citations in `test_debug_instruments.gd`/`debug_instrument_panel.gd` corrected (B6). Live Smoke section gained the restated, `2-1/R2`-amended pad-swap safety procedure (project.godot may never be blanket-reverted once it carries the run-key edit) and a BLOCKING+run step (B7); Task 2 gained explicit `project.godot`-discipline steps (G11). No split (declined per the fix-pass operator instruction — corrected, readiness gate 2 note 10: the original text's "R7 declined it" collided with Fact M7's own bare "R7" cancel-rule citation); Status stays `authored`, board stays `backlog`, not promoted. | Claude Sonnet 5 |
| 2026-09-15 | 0.3 | Docs-only amendment landing operator ruling `6-7/R6`: `p1_run` = Space, `p2_run` = Right Ctrl, Shift rejected for the `location:0` collision measured in 0.2. AC 3 now authorizes Task 2 (the "awaiting the operator's ruling" gate removed); Task 2's `project.godot` discipline steps (a)-(d) unchanged; Deferred and Open Questions item 3 struck with the ratified keys named, matching the other two closed items; Live Smoke step 2 updated to Space with the "unreachable" clause dropped; a new Dev Notes section records the accepted, unsolved consequence that LEFT Ctrl also fires `p2_run` under this project's location:0-only binding convention, harmless because Ctrl is unbound on `p1` and the delivered config puts no human hand on the p2 keyboard. Status stays `authored`, board stays `backlog`, not promoted. | Claude Sonnet 5 |
| 2026-09-15 | 0.4 | Docs-only amendment against readiness gate 2 (`C:\dev\_6-7-gate2.md`, verdict NOT READY, 5 blockers, 15 non-blocking notes), landing operator rulings `6-7/R16`-`R21`. R16: "empty" means `is_zero_approx(get_current())`, not raw `> 0.0` — fixes clause (5) of the "actually running" predicate and the AC 9/10/17 latch-set chain, which at the authored values (`max_stamina=50.0`, drain `10.0`/s) stuck the pool on a ~`1e-13` residual forever (Blocker 1); the AC 7/9 evidence now must drive the authored values, not in-test round numbers. R17: clause (3) of the predicate now also excludes ATTACKING, resolving its contradiction with AC 11(i)/(ii) (Blocker 2). R18: `p2_run`'s key is FINAL — NUMPAD 0, not Right Ctrl — because Right Ctrl's acceptance rested on a false premise (the shipped default is two keyboards, not the delivered P1-keyboard/P2-pad config, Blocker 4); Numpad 0 has no Left/Right variant, so no consequence needs accepting. R19: Live Smoke's binding-flip procedure is replaced wholesale with a two-gamepad smoke (both runner slots to GAMEPAD via an ADDED `main.tscn` `slot_controller_kinds` line), since `main.tscn` carries no such line today and the prior "KEYBOARD_P2 flip" was a no-op (Blocker 3); the keyboard half of smoke step 2 is deleted. R20: a new Task 10 has the dev pass measure, live, whether a mouse-focused debug-panel button re-fires on Space (`p1_run`, which collides with the engine's `ui_accept` default) and set `focus_mode = FOCUS_NONE` only if it reproduces (Blocker 5). R21: this docs-only amendment plus a narrow re-check of the items it touches replaces a third gate. Rule-ID collision cleanup (gate 2 note 10, MANDATORY): the fix pass's `6-7/R1,R2,R4,R5,R6,R-B2,R-B3,R-B4` reused numbers already carrying different meanings in the create pass's own bare `R1`/`R4`/`R5`/`R6`/`R7`/`R8` citations; renumbered in order of first appearance to `6-7/R9`-`R15` (STUNNED carve-out -> R9, BLOCKING-forces-walk -> R10, the per-file `walk_speed` test-migration rule -> R11, the FORMAT_VERSION bump -> R12, the "actually running" predicate -> R13, auto-resume -> R14, the regen-delay seat -> R15); the superseded key-binding ruling is left at `6-7/R6`, marked struck, rather than folded into the new range. Also fixed, all against readiness gate 2's non-blocking notes: AC 10's "resumes that same tick" corrected to "next tick" (`_regen_stamina` runs after `_resolve_movement` in `advance()`, note 7); AC 17's off-by-one restated as "spend tick plus N-1 further ticks" (note 8); AC 15 restated to transfer only the v9 precedent's version-refusal half, not its field-strip half (note 2); Task 8 gained the second `FORMAT_VERSION` pin at `test_record_file.gd:832` (note 1); Task 6(d) restated `test_unit_approach_live.gd` as a confirmed likely failure with a fix obligation, not an unmeasured risk (note 6); Task 5 restored the dropped empty-`Switches`-VBox item and its stale layout comment (note re-flagged from gate 1); M5(a)'s `test_replay_identity.gd:487` corrected from "weakens" to "fails" (note 3); M5(b)'s "13 `_intent(` definitions" corrected to "5 of 13 are movers" (note 4); M5(g) named `test_match_state.gd`'s second config `_b1_match` (note 5); AC 11(ii)'s self-contradictory BLOCKING wording rewritten (note 9); AC 13 given concrete audit assertions (note 9); the Non-Goals cancel/resume bullet extended to name AC 16 alongside AC 11 (note 15); M3's two misdirected "(Fact 6)" citations, M5(e)'s "above" (should be "below"), M6's self-referential "Fact 6 below", M5(a)'s wrong "covered by item (c)" claim, and Open Question 5's "Dev Notes below" (should be "above") all corrected (note 11); four stale `keyboard_controller.gd`/`input_intent.gd` line citations in Fact M2 and the Dev Notes reuse/reference lists corrected (note 12). Findings judged WRONG, with the measurement, are recorded in the dev-pass report this amendment was written alongside, not restated here. No third gate (R21); Status stays `authored`, board stays `backlog`, not promoted. | Claude Sonnet 5 |
| 2026-09-15 | 0.5 | Promotion pass, docs-only, against the narrow re-check (`C:\dev\_6-7-recheck.md`, verdict READY FOR DEV) that replaced gate 3 per `6-7/R21`. Status `authored` -> `ready-for-dev`; board `backlog` -> `ready-for-dev`. Folded in the re-check's four carries: Carry B1, `:251` "Task 6(b)" corrected to "Task 6(c)" (the `_golden_config()` guard is 6(c)); Carry B2, `:30`'s dangling "`:3900-3920` cited below" forward reference repointed to the real cite (`:838`, `:3749-3920`); Carry C, "(AC 14, AC 15)" added to Tasks 6 and 9, and Task 10 given its own one-line acceptance criterion (no AC number exists to cite: the review checks that the focus behaviour was measured live and that `focus_mode` was changed if and only if the defect reproduced); Carry A, the struck Right-Ctrl binding ruling renamed `6-7/R6` -> `6-7/R6-STRUCK` everywhere it appears in the story body (AC 3, the Deferred item, Task 2, the Struck section heading and Open Questions intro), leaving every bare `R6` (the hysteresis latch) untouched — grep-confirmed. Change Log rows 0.1-0.4 left unedited. | Claude Sonnet 5 |
| 2026-09-16 | 0.6 | Dev pass, code+tests, Tasks 1-9 complete and checked; Task 10 and Task 11 left unchecked (see Completion Notes). Two-gait system landed: `walk_speed`/`run_stamina_drain_per_second`/`run_resume_stamina_percent` authored, `&"run"` wired on both controllers, the R6 gait-lockout latch (`HeroState.run_locked_out`) added and snapshotted, gait resolution + drain + suppression wired through a single per-tick "actually running" predicate computed once in `_resolve_movement` and threaded into `_regen_stamina` (Open Question 5 resolved this way), `normalize_move_magnitude` retired end to end, all 8 named `test/state/*.gd` fixtures plus 2 named integration fixtures migrated per Fact M5, balance audits extended (AC 13), `FORMAT_VERSION` bumped 10->11 with both pins and a new v10-refusal test, three named breakage surfaces fixed. State suite: 842/0/6909 (was 842/1/6909 before the golden re-baseline — the one failure being the predicted golden move). Golden re-baselined `9ed4c903...` -> `71a7b45f...`, single cause (the new hashed `run_locked_out` field) proven in both directions by a temporary removal-and-restore experiment, documented inline above `const GOLDEN`. A missed direct call site (`test_stamina_economy.gd:512`, one-arg `_regen_stamina` call, outside Fact M5's scope since it drives no movement) crashed the state suite on the first pass; found by grepping every call site of every changed signature and fixed. Task 10 (the mouse-focus/Space-reactivation measurement) attempted but INCONCLUSIVE — this headless environment's GUI input pipeline does not fire button `pressed` signals for ANY synthetic input method tried, including a direct mouse click bypassing focus entirely, so neither of the story's two branches can be answered here; `focus_mode` left unchanged, question moves to the Live Smoke (real window, real pads). Integration suite: 59/61 PASS — two NEW failures discovered, diagnosed but NOT fixed per instruction (`test_unit_corpse_walkthrough_live.gd` and `test_replay_verifier_tool.gd`, both the same walk-as-default root cause landing on fixtures outside Fact M5's named scope, not a contradiction of any ruling). `test_match_state.gd`'s four direct `_resolve_movement` callers discard the new `bool` return (legal, unfixed, flagged for review). Status stays `ready-for-dev`, board stays `ready-for-dev` — not promoted: Task 10 is genuinely incomplete and the integration suite is not green. No commits, no staging, no push. | Claude Sonnet 5 |
| 2026-09-16 | 0.7 | Follow-up dev pass: fixed both integration failures 0.6 left diagnosed-but-unfixed, per the ratified `6-7/R11` no-op shape verbatim. `test_replay_verifier_tool.gd`'s `_config(move_speed)` now authors `walk_speed = move_speed` (the Task 6(a) shape), restoring the move_dir-sign divergence its two fixtures exist to prove. `test_unit_corpse_walkthrough_live.gd` now presses `p1_run` alongside `p1_move_up` in both stage 1 and stage 2's drive windows (the `test_hero_movement.gd` shape, chosen over re-deriving `DRIVE_FRAMES` since both stages share one constant sized against the authored 5.0 RUN speed) — no assertion tolerance or margin touched. Completion Notes extended (not the Facts section) to name why Fact M5's grep pattern (velocity-literal assertions in `test/state/*.gd`) could not see either file: one asserts POSITION in `test/integration/`, the other asserts HASH DIVERGENCE between two replayed records, neither a velocity literal. Both suites re-run in the foreground: state 842/0/6909 (unchanged), integration 61/61 PASS (was 59/61). Task 11 checked. Task 10 stays UNCHECKED, carried explicitly to the Live Smoke (its headless measurement remains genuinely inconclusive, not negative). Status `ready-for-dev` -> `review`; board `ready-for-dev` -> `review` (`sprint-status.yaml`). No commits, no staging, no push. | Claude Sonnet 5 |
| 2026-09-16 | 0.8 | Review-continuation fix pass against the Senior Developer Review's CHANGES REQUESTED verdict (Claude Opus 5, 2026-09-16), operator rulings: Finding 2 is a defect (fix it, with the latch also setting immediately after the drain `spend()` reads empty); the `E5-R/R2` sidecar report stays unwritten this story. Finding 1 [High]: new `test/state/test_locomotion_gaits.gd` (12 tests, all mutation-provable) covers every named-untested `[headless-provable]` AC — 6, 7/9 (the authored-value MUST test), 8, 10, 11, 16, 17, 4's pad half, and 2's derivation. Finding 2 [Med]: `_resolve_movement` (`match_state.gd`) now sets `run_locked_out` immediately after the drain's own `spend()` reads `is_zero_approx`, closing the pulse-running exploit; the predicate comment's stale "tick-301" reading corrected to the one-tick-earlier set; `hero_state.gd:99`'s field doc widened to match (finding 8, addressed together). Red-green proof recorded in the Debug Log: with the fix removed, the state suite showed 2 new failures (854/2/6963); restored, 854/0/6963. Finding 3 [Med]: Task 11 split into 11a (suite, checked) / 11b (live smoke, unchecked). Finding 4 [Med]: the Debug Log's golden-isolation counts corrected to "golden passed, snapshot-key pin failed in the removal run," not invented exact counts. Findings 5/8/10/11 [Low]: stale retirement comments fixed (`gamepad_profile.gd`, `debug_instrument_panel.gd`, `test_record_save_control.gd` x2), the missing match_runner.gd:462 Completion Notes line added, the Debug Log's missing final 61/61 integration run added, the File List's self-contradictory docs bullet corrected, Task 5's `_check_panel_layout` measurement recorded as PASS, and the garbled `test_replay_verifier_tool.gd:213-214` comment repaired. Finding 6 [Low, advisory]: one doc line added at `balance_config.gd`'s attack-phase-multiplier block. Findings 7/9: no change (both dismissed/ruled acceptable by the review itself). Suites after: state 854/0/6963 (was 842/0/6909 — the new file's 12 tests plus their assertions, no regression), integration 61/61 PASS (unchanged). Review Follow-ups checked: Findings 1, 2, 5, 11 (the four checkbox items). Status STAYS `review` per the operator's explicit constraint — the reviewer re-verdicts, not this pass. No commits, no staging, no push. | Claude Sonnet 5 |
| 2026-09-16 | 0.9 | Re-review closure pass against the Senior Developer Re-Review's three Low findings (R1-R3, `APPROVE WITH FINDINGS` verdict, 2026-09-16). R1: `test_locomotion_gaits.gd:130-132`'s MUTATION line corrected from the non-failing `> 0.0` reading to the mutation that actually kills the test (removing the post-drain latch set). R2: the red-green narrative at `:151-156` restated to match the Debug Log — the pre-fix failure is the `run_locked_out` assert immediately after the emptying tick, not the velocity assert, since the PRE-drain latch set already catches the still-`0.0` re-hold. R3: `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` EXTENDED (not a new sibling) through the regen-delay window to a non-zero, below-threshold bar before re-holding run — the exploit's actual untested payload tick — and asserted WALK at the velocity level; red-green proved with the post-drain latch-set lines temporarily stripped (foreground, once each direction, `match_state.gd` backed up by SHA256 first and confirmed restored). Suites after: state `854/0/6965` (was 854/0/6963 — two new asserted ticks, no regression), integration `61/61 PASS` (unchanged). No code changed outside the verification's temporary removal/restore. Status stays `review`. No commits, no staging. | Claude Sonnet 5 |
| 2026-09-16 | 0.10 | Live Smoke closure pass: Task 10 and Task 11b, the story's last two open items, closed against the operator's live smoke (config `[0, 3]`, P1 keyboard/P2 pad, a stated single-operator deviation from `6-7/R19`'s two-gamepad procedure). Steps 1-7 and 9 ALL PASS (keyboard walk/run split on Space live, the ~20% auto-resume, the 0.8s release delay, cancel/resume across attack/roll, BLOCKING-forces-walk with no drain, L3+A card confirm with no running, FPS stable). Step 8 / Task 10 REPRODUCES, wider than predicted: any last-clicked debug-panel button, not only `ReloadBalance`, retains keyboard focus and re-fires on Space. Fixed per Task 10's own bounded ruling: `focus_mode = Control.FOCUS_NONE` set on all three panel buttons at their construction sites in `src/ui/debug/debug_instrument_panel.gd` (`save` `:225`, `reload` `:231`, `toggle` `:258`) — nothing else in the panel touched. Full suite re-run foreground, both halves: state `854/0/6965` (unchanged), integration `61/61 PASS` (unchanged — the integration panel tests click buttons programmatically via signals, not focus-mediated input). Task 10 and Task 11b both checked; every task and follow-up box in the story is now checked. Status stays `review`. No commits, no staging. | Claude Sonnet 5 |

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

- Golden isolation experiment: `HeroState.to_snapshot()`'s `"run_locked_out"` key temporarily
  removed, state suite re-run, `test_state_matches_golden` reproduced the pre-story hash
  `9ed4c9035a89b3219623dc129d73693e6871049bc9c48f672bc5554d49f5d5b2` exactly; line restored
  immediately after. Proves the latch field is the single golden-moving cause. **Corrected by the
  fix pass (review finding 4): the original record's "842/0/6909 during the isolation removal"
  count below cannot be true — `test_debug_window_countdown.gd`'s hero-snapshot key-list pin
  (Task 9) already named `"run_locked_out"` at the time of that experiment, so removing the key
  from `to_snapshot()` must have FAILED that pin even as it made the golden pass. The record is
  corrected to: the golden passed and the snapshot-key pin failed in the removal run — the exact
  counts that run actually produced were not captured and are not reconstructed here, rather than
  invented. The reproduced pre-story hash itself is not in doubt (only reviewed, not re-run, by
  the Senior Developer Review, and unaffected by which OTHER test failed alongside the golden).**
- Task 10 live-focus measurement: a scratch script (`test/manual_measure_focus_6_7.gd`, never
  committed — copied into the tree, run, then deleted) instantiated `main.tscn` headless,
  `grab_focus()`'d the RELOAD button, then tried three escalating input-synthesis methods
  (`Input.action_press`, a real `InputEventKey` via `Input.parse_input_event`, and
  `Window.push_input`) to fire a Space press while the button held focus — all three read zero
  `pressed` signals. A fourth check (a synthetic mouse click at the button's own screen rect,
  bypassing focus/keyboard entirely) ALSO fired zero `pressed` signals, proving headless mode's
  GUI input pipeline does not reach `BaseButton`'s press handling on this machine at all — the
  result is inconclusive, not a negative measurement of the real defect. See Completion Notes.
- Foreground state suite (three runs, none backgrounded): 842/1/6909 before the golden
  re-baseline (the one failure being `test_state_matches_golden`), 842/0/6909 after restoring the
  field and re-baselining `GOLDEN`. The isolation-removal run's own counts are corrected above
  (finding 4) rather than restated here.
- Foreground integration suite, FIRST pass (61 files, none backgrounded): 59 PASS, 2 FAIL
  (`test_replay_verifier_tool.gd`, `test_unit_corpse_walkthrough_live.gd` — see Completion Notes;
  neither touched this pass).
- Foreground integration suite, FOLLOW-UP pass, after both failures above were fixed: 61 PASS, 0
  FAIL. This is the FINAL integration result the story ships with (review finding 10: the
  0.6-pass run above was the only integration run this Debug Log recorded; the real final state,
  previously visible only in the Change Log and Completion Notes, is recorded here too).
- Fix pass (review-continuation, this entry): red-green evidence for
  `test_locomotion_gaits.gd::test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` and
  `::test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick` (finding 1's AC 7/AC 9 MUST
  test) — with `match_state.gd`'s post-drain latch-set line (finding 2's fix) temporarily removed,
  a foreground state-suite run showed both tests FAILING (`assert_true` on `run_locked_out`/the
  latch-timing text), 854 tests, 2 failed, 6963 assertions; the line was restored and the SAME
  foreground run showed 854 tests, 0 failed, 6963 assertions. Full suite re-run after: state
  854/0/6963, integration 61/61 PASS (unchanged from the follow-up pass above — the fix touches
  only `src/state/match_state.gd` and `src/state/hero_state.gd`'s doc comment, neither read by
  any integration fixture's assertions).
- Re-review closure pass (findings R1-R3, Senior Developer Re-Review 2026-09-16): the MUTATION
  line and red-green narrative in `test_locomotion_gaits.gd`'s two Finding-2 docstrings corrected
  to match what the code and the Debug Log actually prove (R1, R2 — documentation only, no
  assertion changed), and
  `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` EXTENDED (ticks 12-14 added,
  not a new sibling test) to drive the bar through the regen-delay window to a non-zero,
  below-threshold amount before re-holding run — the exact payload tick the original Finding 2
  exploit turns on and the R2 correction shows the pre-extension test never reached (R3). Backed
  up `src/state/match_state.gd` to the scratchpad first (SHA256
  `13f901128fac025a18ddf75447618c26c58715ec680b4b876c580be0d657e686`), matched after restore.
  Red run (post-drain latch-set lines `:3916-3921` removed), foreground, one run: `854 tests, 2
  failed, 6965 assertions` — `test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick`
  failed its `run_locked_out` assert; `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch`
  failed on THREE asserts, the third being `assert_almost_eq: got 5.0, expected 2.5 +/- 0.0001`
  on the new tick-14 payload assertion — a velocity failure, not a latch assert, proving the
  extension is load-bearing independent of the two earlier latch checks. Restored (SHA256
  matched), green run, foreground, one run: `854 tests, 0 failed, 6965 assertions`. Full suite
  re-run after, foreground, both halves, no background tasks: state `854/0/6965`, integration
  `61/61 PASS` (unchanged — the two new asserted ticks touch no integration fixture).
- Live smoke closure pass (Task 10 / Task 11b): the operator ran the Live Smoke procedure live
  (config `[0, 3]`, P1 keyboard/P2 pad, deviating from `6-7/R19`'s two-gamepad shape for the
  stated single-operator reason) and reported Step 8's Task 10 measurement as REPRODUCES, wider
  than predicted — ANY last-clicked debug-panel button, not only `ReloadBalance`, retains keyboard
  focus and re-fires on Space. Fix applied per the story's own bounded ruling: `focus_mode =
  Control.FOCUS_NONE` set on all three panel buttons at their construction sites in
  `src/ui/debug/debug_instrument_panel.gd` (`save` `:225`, `reload` `:231`, `toggle` `:258`) — no
  other line in the panel touched. Full suite re-run after, foreground, both halves: state
  `854/0/6965` (unchanged), integration `61/61 PASS` (unchanged — the integration panel tests
  click buttons programmatically via `pressed`/`toggled` signals and `button_pressed`, not via
  focus-mediated input, so `FOCUS_NONE` does not disturb them). All other Live Smoke steps
  (1-7, 9) PASS per the operator's report; recorded verbatim at Task 11b.

### Completion Notes List

**What was built.** The two-gait system per `E6-P/R3`: `BalanceConfig`/`BalanceTicks` gain
`walk_speed`/`run_stamina_drain_per_second`/`run_resume_stamina_percent`/
`run_stamina_drain_per_tick` (Task 1); `&"run"` joins the keyboard `INTENT_ACTIONS` loop and
`project.godot` gains `p1_run`=Space/`p2_run`=NUMPAD 0 per `6-7/R18` (Task 2); the gamepad's
`resolve_card_tick()` gains `run_held` on the `attack_held`/`block_held`/`roll_held` shape (Task
3); `HeroState` gains the `run_locked_out` R6 hysteresis latch, snapshotted; `_resolve_movement`
resolves gait (WALK/RUN/BLOCKING-forced-walk) before its speed read via a single `_run_pursuit_
active` clause-(1)-(3) helper plus latch/stamina clauses (4)/(5) computed once per tick and
returned as `actually_running`, which `advance()` threads into `_regen_stamina`'s new fourth
suppression disjunct — the two seats can never derive the fact independently (Task 4, Dev Notes
Open Question 5 resolved this way: computed once, not recomputed); `normalize_move_magnitude`
retired end to end — field, call site, panel switch/handler, `.tres` line, both retired
`test_gamepad_controller.gd` tests, the `test_debug_instruments.gd` `_magnitude_ok` block, and
`test_record_save_control.gd`'s name list/message (Task 5). **Missing from the original
Completion Notes, added by the fix pass (review finding 5):** Task 5 explicitly required noting
that `match_runner.gd:462`'s `panel.gamepad_profile = load(...)` becomes a DEAD ASSIGNMENT once
`normalize_move_magnitude` retires — its only reader (`debug_instrument_panel.gd:63`'s
`gamepad_profile` member) is gone — and is LEFT IN PLACE deliberately: the panel still needs
constructing for its other controls, so removing the line buys nothing. **Also added (review
finding 10):** Task 5's required check of `_check_panel_layout`
(`test/integration/test_debug_instruments.gd:117`) against the now-empty `Switches` column was
performed and the test PASSES — the empty `VBoxContainer` collapses to zero-size cleanly, so no
minimum-size fix was needed; this was previously true but never recorded as measured. The 8 named
`test/state/*.gd` fixtures
plus `test_hero_movement.gd`/`test_unit_approach_live.gd` migrated per Fact M5 (Task 6);
`test_data_resources.gd`/`test_balance_authoring.gd` audits extended for the three new fields,
including the two directional bounds AC 13 names (Task 7); `FORMAT_VERSION` bumped 10->11 with
both pins updated and a new `test_a_v10_record_is_refused_with_a_reason` (version-refusal half
only, per AC 15's correction) (Task 8); the three named breakage surfaces fixed
(`test_deck_and_hand.gd`, `test_debug_window_countdown.gd`, `test_replay_identity.gd`'s HASHED
list) (Task 9).

**The missed `_regen_stamina` call site, and how it was found.** The operator ran the state suite
in the background after my first pass and reported it as HUNG; it had actually CRASHED —
`test_stamina_economy.gd:512` called `ms._regen_stamina(ms.p1)` with the OLD one-argument
signature (a direct test call, bypassing `advance()`, to pin the DEAD-suppression contract on a
hand-constructed corpse with `_round_over` false). It was not on Fact M5's list because it drives
no movement. Found by grepping by content for every call site of every signature changed this
pass (`_regen_stamina`, `_resolve_movement`, `resolve_move_dir`, `resolve_card_tick`) across
`src/` and `test/` before touching anything, per the operator's explicit instruction. Fixed by
passing `false` (the hero is forced DEAD, never "actually running" under the AC 7 predicate).
Every other direct caller of a changed signature (`test_match_state.gd`'s four
`ms._resolve_movement(...)` calls) kept the same arity — only the return type changed from `void`
to `bool` — which is legal GDScript when the return value is unused, so those needed no fix.

**Task 10 — NOT DONE, left unchecked.** The dev pass attempted the live measurement Task 10
requires but could not obtain a valid answer in this sandboxed, headless-only environment: every
input-synthesis method tried (action-press, a real `InputEventKey`, `Window.push_input`, and even
a synthetic mouse click bypassing keyboard/focus entirely) failed to fire the RELOAD button's
`pressed` signal, proving headless mode's GUI dispatch pipeline is itself inert here rather than
proving the Space-reactivation defect does not reproduce. The story's two branches ("if it
reproduces, set `focus_mode`" / "if it does not reproduce, change nothing") both require a real
answer this environment cannot give. `focus_mode` is UNCHANGED. This question moves to the Live
Smoke, which runs in a real window on two physical pads (`6-7/R19`) — the first environment in
this story's own procedure where a real Space press is actually possible. The scratch measurement
script was never committed (copied in, run, deleted).

**Noted for review, not fixed this pass (per explicit operator instruction):**
`test_match_state.gd:158,162,185,188` call `ms._resolve_movement(...)` directly and discard its
new `bool` return — legal, but these are movement tests that now silently ignore the "actually
running" predicate this story exists to deliver. Left as-is; flagged for the reviewer.

**Two NEW integration failures discovered this pass, neither in the two files Task 6(d) named —
diagnosed AND FIXED in the follow-up pass (both green now, see the suite results below):**
- `test_unit_corpse_walkthrough_live.gd` (stage 2, "hero_did_not_pass_corpse(dx=0.300)"): this
  fixture pressed only `p1_move_up`, never `p1_run`. Its `DRIVE_FRAMES` (40) window was sized
  against the OLD default speed (`move_speed` 5.0); at the new WALK default (`walk_speed` 2.5) the
  hero covers roughly half the distance in the same window and fell short of `PAST_MARGIN` (0.4).
  FIXED by pressing `p1_run` alongside `p1_move_up` in BOTH stage 1 (blocked-by-live) and stage 2
  (walk-through-corpse)'s drive windows (`test_unit_corpse_walkthrough_live.gd:228-233,257-260`) —
  the `test_hero_movement.gd` shape, chosen over re-deriving `DRIVE_FRAMES` because both stages
  share one constant and one comment ("~3.3 units of travel" at the authored 5.0), and holding
  `p1_run` restores that exact sizing without touching any numeric constant or margin.
- `test_replay_verifier_tool.gd` ("TWO RECORDS THAT DIFFER ONLY IN THEIR RECORDED INTENTS PRINT
  DIFFERENT HASHES" — FAILED, both hashes identical): its `_config(move_speed)` fixture never
  authored `walk_speed` (stayed at the unauthored 0.0 default) and neither recorded fixture
  presses `&"run"`. The two fixtures' ONLY designed difference is `move_dir`'s sign (`3-0d/R25`) —
  but at `walk_speed = 0.0` both directions produced IDENTICAL (zero) velocity, so the intended
  divergence never reached the hash. FIXED by authoring `walk_speed = move_speed` in `_config()`
  (`test_replay_verifier_tool.gd:211-215`) — the `6-7/R11` no-op shape verbatim, same one-line
  addition and comment style as every Task 6(a) fixture.

**Why Fact M5's audit missed both, named for the record (M5 is not a permitted edit area — this
note extends it without touching the Facts section):** M5's file list was built by grepping
`test/state/*.gd` for `move_dir = ` / `Vector2(1, 0)` / `MOVES[` and narrowing to files with a
velocity-DEPENDENT assertion — a pattern scoped to `test/state/` and to assertions that read
`.hero.velocity` or an equivalent instantaneous-speed value directly. Neither broken file fits
that shape: `test_unit_corpse_walkthrough_live.gd` lives in `test/integration/` (M5(a) explicitly
scoped Task 6 to `test/state/*.gd` plus two NAMED integration files) and asserts POSITION —
`hero.global_position.x` sampled before and after a drive window — never `.velocity` directly, so
a velocity-literal grep could not see it. `test_replay_verifier_tool.gd` also lives in
`test/integration/` and asserts neither velocity nor position but HASH DIVERGENCE between two
replayed records — the walk-speed freeze is invisible to any single-run assertion (both runs
"pass" their own internal consistency; only comparing the two hashes reveals nothing diverged).
Both are legitimate consequences of AC 1/AC 6 (walk-as-default) landing on fixtures outside Fact
M5's named scope, not contradictions of any ratified ruling — the `6-7/R11` fix rule applies to
both verbatim once found.

**Status:** `ready-for-dev` -> `review` (board matches). Both integration failures above were
diagnosed AND FIXED in the follow-up pass (`test_replay_verifier_tool.gd`,
`test_unit_corpse_walkthrough_live.gd`); the state suite stayed 842/0/6909 and the integration
suite is now 61/61 PASS, both read from foreground runs. Task 10 STAYS UNCHECKED and carries to
the Live Smoke — its measurement was genuinely inconclusive in this headless environment (see
above), not a completed item, and the story goes to review with that fact explicit rather than
silently checked.

**Fix pass (review-continuation), against the Senior Developer Review's CHANGES REQUESTED
verdict.** Findings closed, in the review's own priority order:

- **Finding 1 [High]:** one new file, `test/state/test_locomotion_gaits.gd` (12 tests), covers
  every previously-untested `[headless-provable]` AC the review named: AC 6 (walk/run per state
  plus the STUNNED/ROLLING/CHARGING carve-outs, via direct `_resolve_movement` calls on the
  DEAD-branch precedent), AC 7/AC 9 (the authored-value MUST test — `max_stamina = 50.0`,
  `run_stamina_drain_per_second = 10.0`, 300 ticks from full, asserting `is_zero_approx` AND the
  latch), AC 8 (regen suppressed while actually running, NOT suppressed while locked-out-and-
  walking), AC 10 (automatic next-tick resume at `>=` threshold, no re-press), AC 11 (attack AND
  roll entry cancel the drain, running resumes on the first IDLE tick after, no re-press), AC 16
  (BLOCKING forced to walk, no drain, no latch, run held or not), AC 17 (regen resumes exactly at
  last-running-tick + 47 further ticks, one tick earlier still zero), AC 4's pad half
  (`resolve_card_tick`'s `run_held`: true on bare A, false under `cast_held`), and AC 2's
  `run_stamina_drain_per_tick` derivation (the `stamina_regen_per_tick` audit shape,
  `test_balance_config.gd:155-157`'s precedent).
- **Finding 2 [Med]:** the latch bypass closed exactly as ruled — `_resolve_movement`
  (`match_state.gd:3912-3921`) now ALSO sets `run_locked_out` immediately after the drain
  `spend()`, on the same tick, if the pool then reads `is_zero_approx`. The predicate comment
  above it (previously citing "AC 9's measured tick-301 latch-set timing") is corrected to
  describe the one-tick-earlier set. `hero_state.gd:99`'s field doc is widened to match (review
  finding 8, addressed together since it names the same fix). **Red-green evidence:** with the
  fix's six lines temporarily removed, a foreground state-suite run showed
  `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` AND
  `test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick` both FAILING (854 tests, 2
  failed, 6963 assertions); with the fix restored, the SAME run showed 854 tests, 0 failed, 6963
  assertions. See Debug Log.
- **Finding 3 [Med]:** Task 11 split into Task 11a (suite, checked) and Task 11b (live smoke,
  left UNCHECKED — it has not run).
- **Finding 4 [Med]:** the Debug Log's golden-isolation counts corrected — the recorded
  "842/0/6909 during the isolation removal" cannot be true against the already-landed
  `test_debug_window_countdown.gd` snapshot-key pin (Task 9); corrected to "the golden passed and
  the snapshot-key pin failed in the removal run," without inventing the exact counts that run
  actually produced. See Debug Log.
- **Findings 5, 8, 10, 11 [Low]:** stale retirement comments fixed
  (`gamepad_profile.gd:49`, `debug_instrument_panel.gd:56`, `test_record_save_control.gd:18-19`
  and `:146-147`); the missing Completion Notes line about `match_runner.gd:462`'s dead
  assignment added above; `hero_state.gd:99`'s latch doc widened (finding 8, with finding 2); the
  Debug Log gained the missing final (61/61) integration run (finding 10); the File List's
  self-contradictory docs bullet corrected below (finding 10); Task 5's `_check_panel_layout`
  measurement recorded as PASS above (finding 10); the garbled comment at
  `test_replay_verifier_tool.gd:213-214` repaired (finding 11).
- **Finding 6 [Low, advisory]:** a one-line doc note added at
  `balance_config.gd`'s attack-phase-multiplier block, naming that ATTACKING now scales
  `walk_speed`, not `move_speed` (inert today at the authored 0.0 multipliers; no code change,
  no AC rules it).
- **Finding 7 [Low, advisory]:** not a defect (dismissed by the review itself) — no change.
- **Finding 9 [Low, advisory]:** ruled acceptable by the review itself — no follow-up task, no
  change.
- **Not written, per the operator's explicit ruling for this pass:** the `E5-R/R2` sidecar
  report at `C:\dev\_6-7-review.md` stays unwritten; this close-out note (and the original
  review section's own note) record why.

**Suites after the fix pass, foreground:** state `854 tests, 0 failed, 6963 assertions` (was
842/0/6909 — the 12 new tests plus their assertions, no regression); integration `61/61 PASS`
(unchanged). Status stays `review` per the operator's instruction — the reviewer re-verdicts,
not this pass.

**Re-review closure pass, against the Senior Developer Re-Review's three Low findings (R1-R3).**
Narrow pass: `test_locomotion_gaits.gd`'s docstrings and one assertion block only, no code touched
outside the verification's temporary removal/restore. Closed:

- **R1:** the MUTATION line at `:130-132` (the AC 7/AC 9 authored-value test) claimed a
  `> 0.0` reading for clause (5) fails the test; it does not — the pool's sub-epsilon residual
  (`1.649e-13`) still reads `is_zero_approx` true, so that mutation passes both assertions.
  Corrected to name the mutation the test actually kills: removing the post-drain latch set
  (`match_state.gd:3916-3921`, Finding 2's fix).
- **R2:** the red-green narrative at `:151-156` claimed the pre-fix failure was the velocity
  assertion (re-holding run produced RUN, not WALK); the PRE-drain latch set (unchanged by the
  fix) already catches that tick, so the actual pre-fix failure is the `run_locked_out` assert
  immediately after the emptying tick — matching the Debug Log. Restated to match.
- **R3:** the exploit's own payload tick (re-holding run at a non-zero, below-threshold bar, as
  opposed to the still-`0.0` bar the pre-drain set already covers) was untested. EXTENDED
  `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` (ticks 12-14 added) rather than
  adding a sibling test — the payload is a direct continuation of the same drain-then-release
  scenario the existing test already sets up (same config, same latch state at tick 11), so
  extending kept one coherent narrative instead of duplicating the setup in a second test. Proved
  by red-green: with the post-drain latch-set lines stripped, the new tick-14 assertion failed as
  `got 5.0, expected 2.5` (a velocity failure, distinct from the two earlier latch asserts, which
  also failed); restored, all green. See Debug Log for the exact counts (both directions run
  foreground, once each, no background tasks).

**Suites after the re-review closure pass, foreground, both halves:** state `854 tests, 0 failed,
6965 assertions` (was 854/0/6963 — the two new asserted ticks in the extended test, no
regression); integration `61/61 PASS` (unchanged). Status stays `review`.

### File List

Reconciled against `git status --porcelain` (source of truth); no disagreement — every changed
file below is tracked in that output, and every entry in that output appears below.

**Source:**
- `data/balance/balance_config.tres`
- `data/gamepad_profile.tres`
- `project.godot`
- `src/controllers/gamepad_controller.gd`
- `src/controllers/gamepad_profile.gd`
- `src/controllers/keyboard_controller.gd`
- `src/state/hero_state.gd`
- `src/state/match_state.gd`
- `src/state/resources/balance_config.gd`
- `src/state/timing/balance_ticks.gd`
- `src/systems/record_file.gd`
- `src/ui/debug/debug_instrument_panel.gd`

**Tests:**
- `test/integration/test_debug_instruments.gd`
- `test/integration/test_hero_movement.gd`
- `test/integration/test_record_save_control.gd`
- `test/integration/test_replay_verifier_tool.gd`
- `test/integration/test_unit_approach_live.gd`
- `test/integration/test_unit_corpse_walkthrough_live.gd`
- `test/state/test_action_state.gd`
- `test/state/test_balance_authoring.gd`
- `test/state/test_camera_basis.gd`
- `test/state/test_contact_resolution.gd`
- `test/state/test_data_resources.gd`
- `test/state/test_debug_window_countdown.gd`
- `test/state/test_deck_and_hand.gd`
- `test/state/test_determinism.gd`
- `test/state/test_gamepad_controller.gd`
- `test/state/test_live_reload.gd`
- `test/state/test_locomotion_gaits.gd` (NEW, fix pass, review finding 1 — 12 tests)
- `test/state/test_match_state.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_roll_iframes.gd`
- `test/state/test_stamina_economy.gd`
- `test/state/test_unblockable_hold.gd`

**Docs (this file):**
- `docs/implementation-artifacts/6-7-locomotion-gaits.md` (fix pass: Tasks 1-9 checked, Task 10
  stays unchecked, Task 11 split into 11a checked / 11b unchecked, per the review's own findings
  3 and 10 — corrected from the original bullet's self-contradictory "Tasks 1-11 checked, Task 10
  stays unchecked"; Status stays `review`; Dev Agent Record and Review Follow-ups updated)
- `docs/implementation-artifacts/sprint-status.yaml` (unchanged this pass — Status stays `review`,
  the operator's review-only constraint per the original review section)

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 5, 2026-09-16. Run with the `gds-code-review` skill's three layers (Blind
Hunter, Edge Case Hunter, Acceptance Auditor). Every finding below was measured against the repo by
content in THIS session -- a prior session's review section at the same baseline was re-verified
claim by claim, not carried on trust; one finding was added (11) and the mandatory
`LAYER-COMPLETION:` line supplied.

`LAYER-COMPLETION:` Blind Hunter = COMPLETE (findings 2, 6, 7, 8) | Edge Case Hunter = COMPLETE
(findings 2, 7, 8, plus the nine dismissals below) | Acceptance Auditor = COMPLETE, inline
(findings 1, 3, 4, 5, 9, 10, 11; Dev Agent Record evidence audit included, falsified claims
annotated in place at findings 1, 3, 4).

**Baseline:** `git diff 86b7d11`.
- 36 modified paths: 12 source, 22 test, 2 docs. No untracked files.
- The File List matches `git status --porcelain` exactly, in both directions.

**Suite, re-run by the reviewer** (foreground, `bash test/run_all.sh`, exit 0; PROC/R1 disclosure:
this is a review-verification run, stated and reported, not absorbed):
- State: `842 tests, 0 failed, 6909 assertions`.
- Integration: `ALL TESTS PASSED`.
- The green claim holds.

### Verdict: CHANGES REQUESTED

The implementation matches the rulings on every seat audited (P1-P4 below) -- the predicate seam,
the drain seat, BLOCKING-forces-walk and the retirement are all correct by reading. Two things
block it:
- Nine `[headless-provable]` ACs have no test at all, including the authored-value evidence AC 7
  and AC 9 explicitly mandate with "MUST", and a checked task claims one of them.
- There is one real hole that lets a player skip the R6 latch entirely.

### Priority audit results (P1-P6)

**P1 -- predicate seam: SOUND.**
- `p1_actually_running` / `p2_actually_running` are per-tick locals (`match_state.gd:535,537`),
  passed straight into step 5 (`:584-585`). No field, no carrier, nothing to go stale between ticks.
- Every route to `_regen_stamina` audited:
  - The step-1b round-over early return (`:454-457`) returns before BOTH `_resolve_movement` and
    `_regen_stamina`, so a frozen tick cannot pair a stale flag with a live regen.
  - The DEAD branch returns `false` (`:3789`) before the predicate is ever evaluated.
  - `balance == null` takes the pre-injection fallback and leaves the flag `false` (`:3866-3867`).
  - The drain reads `balance_ticks` under a `balance != null` guard; the two are assigned together
    in `apply_balance` (`:674-675`), so that read cannot be null.
- A hero whose `action_state` changes between step 3 and step 5 (e.g. stunned at contact) still
  carries the step-3 value into `_regen_stamina`. Harmless: that same tick's `spend()` already
  restarted the delay window, so regen is suppressed on that tick regardless of the disjunct.
- The latch has exactly ONE set site (`:3879-3880`) and ONE clear site (`:2436-2438`). The set
  re-asserts on every tick the hero pursues at empty -- idempotent, not literally "once" -- and the
  clear is likewise idempotent. Neither can run twice with different effect.

**P2 -- drain call: SOUND.**
- `spend()` refuses only on `amount > _current` (`stamina_pool.gd:43`); a spend of exactly
  `get_current()` is therefore a SUCCESS, not a refusal.
- `add(-amount)` then clamps to exactly `0.0` -- so the clamped drain reaches honest zero and the
  `1.649e-13` residual `6-7/R16` was written against cannot arise on this path at all.
- The tick that reaches zero IS a successful spend, so it DOES restart the delay window.
- Delay count, traced: the window starts on spend tick N at step 3, AFTER step 2's `tick_timers`.
  `advance_regen` reads it as running through tick N+47; regen resumes at N+48. That is exactly
  AC 17's corrected "last running tick plus 47 further ticks". Correct by reading, untested
  (finding 1).

**P3 -- BLOCKING-forces-walk (AC 16 / `6-7/R10`): SOUND, and the exclusion is complete.**
- `_run_pursuit_active` returns `false` for BLOCKING (`:3772`), so `actually_running` is false on
  every blocking tick. A blocking hero therefore gets no drain, no running suppression disjunct and
  no latch set -- R2's exclusion prevents DRAIN, not merely speed, which is what P3 asked.
- The walk-speed assignment is ordered BEFORE the `actually_running` speed choice (`:3882-3886`),
  so a held run key cannot reach the run branch while BLOCKING.

**P4 -- the retirement (AC 12): CLEAN in code.**
- No survivor by content of `normalize_move_magnitude`, `NormalizeMagnitude`,
  `_on_normalize_toggled`, `normalize_magnitude` or `_magnitude_ok` anywhere in `src/`, `test/`,
  `data/` or `project.godot`.
- `resolve_move_dir` reverted to always-normalize above the deadzone, 2-arg signature, both retired
  tests gone, the `.tres` line gone, the control-name list down to three.
- Comment-only survivors are finding 5.
- The empty `Switches` column is left in place and documented (`debug_instrument_panel.gd:16-23`,
  `:165-166`, `:212-215`). That is Task 5's "collapses cleanly" branch; `_check_panel_layout` passes
  in the reviewer's own run.
- `project.godot` hygiene re-measured: the diff contains ONLY the two new blocks, no other line
  moved, `common/physics_ticks_per_second=60` intact (now `:197`, shifted by the ten added lines),
  and both physical keycodes (32 = Space, 4194438 = KP 0) occur exactly once each in the whole file.

**P5 -- test honesty: every NEW test CAN fail; the problem is ABSENCE, not vacuity.**
- Gait authoring audit (`test_balance_authoring.gd:111-135`): reads the authored `.tres`, so a
  mis-authored value bites.
- v10 refusal (`test_record_file.gd:547-576`): without the bump the relabel-to-10 file would load
  and `assert_null` would fail; the restore-and-reload half is the real bite.
- Analog clamp (`test_match_state.gd:64-75`): its own config, walk 2.0 vs run 5.0, run held -- it
  now distinguishes the two gaits as M5(g) required.
- The three pins (`SHIPPED_INPUT_ACTIONS`, the hero-snapshot key list, the `HASHED` entry) and the
  golden can all fail.
- No new test whose failure is impossible was found.
- `test_match_state.gd:158,162,185,188` discarding the new bool: ACCEPTABLE as-is, ruled at
  finding 9. No follow-up task.

**P6 -- story-file accuracy:** findings 3, 4, 5 and 10.
- Task 10's record is ACCURATE and is not reported as a finding: the scratch script is absent from
  the tree, no `focus_mode` or `grab_focus` call exists anywhere in `src/`, and the result is
  reported as inconclusive rather than negative. The synthetic-mouse-click control is precisely what
  makes "inconclusive" the honest reading, and carrying the question to the Live Smoke is the right
  call.

### Findings (most severe first)

1. **[High] No behavioural test exists for the gait system, and a checked task claims one.**
   - **Scope:** ACs 4, 5, 6, 7, 8, 9, 10, 11, 16 and 17 are all tagged `[headless-provable]`, plus
     AC 2's derivation. None has a test.
   - **Evidence, by content grep over `test/`:**
     - `run_locked_out` appears only in two key pins (`test_debug_window_countdown.gd:112`,
       `test_replay_identity.gd:255`) and one golden comment.
     - `run_held`, `run_stamina_drain_per_tick` and `_run_pursuit_active` have ZERO hits.
     - The only state test that holds `&"run"` at all is the analog clamp
       (`test_match_state.gd:64-75`), which proves clamping, not gait behaviour.
     - The three integration files that press `p1_run` do so only to restore the pre-story speed so
       an unrelated assertion keeps holding.
   - **Untested, item by item:**
     - Walk 2.5 / run 5.0 per state (AC 6).
     - The per-tick drain amount (AC 7).
     - The running suppression disjunct (AC 8).
     - The authored-value, `>=300`-tick latch-set test asserting `is_zero_approx` AND the latch --
       which AC 7's `6-7/R16` note and AC 9 both word as a MUST.
     - Automatic resume on the next tick at `>=` threshold, no re-press (AC 10).
     - Cancel/resume around attack/roll/block entry and exit (AC 11).
     - BLOCKING forced to walk with run held (AC 16).
     - Regen resuming at last-running-tick + 47 (AC 17).
     - `resolve_card_tick`'s `run_held`, including its suppression under `cast_held` (AC 4).
     - `run_stamina_drain_per_tick`'s derivation (AC 2).
   - **Why the golden cannot stand in:** every Task 6 fixture authors `walk_speed == move_speed` to
     make gait a NO-OP (`6-7/R11`), and no golden intent builder presses `&"run"`. There is
     therefore no committed path anywhere that exercises drain, latch or suppression even
     incidentally.
   - **Claims the repo contradicts (falsified-record annotations):**
     - Task 4 is CHECKED and its text includes "add the headless regen-delay assertion (AC 17)".
       No such assertion exists.
     - `match_state.gd:3872-3876` cites "AC 9's measured tick-301 latch-set timing". No committed
       test measures it.
   - **Why it matters here specifically:** this story's own AC 7/AC 9 name the failure mode -- "an
     AC proven only with in-test round numbers passes while the shipped build fails". The delivered
     pass reproduces it one level up: nothing proves the AC at all, in-test numbers or otherwise.
     The two gates caught evidence that could not fail; this is evidence that does not exist.

2. **[Med] The R6 latch can be skipped by releasing run on the tick the drain empties the pool.**
   `src/state/match_state.gd:3877-3881`
   - **Cause:** the latch is set only from the PRE-drain stamina read, and only on a tick that is
     still pursuing. The tick that actually empties the pool reads stamina as non-empty, so it does
     not set the latch; the NEXT tick sets it only if the hero is still pursuing.
   - **Failure scenario:**
     1. Tick N: hero actually running; `spend()` takes the pool to exactly `0.0`.
     2. Tick N+1: the player releases run (or the stick, or enters BLOCKING/ATTACKING). `pursuing`
        is false, so the latch never sets.
     3. The 48-tick delay elapses; regen adds 0.25/tick.
     4. The player re-holds run. `stamina_empty` is false and `run_locked_out` is false, so the hero
        RUNS -- from 0.25 stamina -- and empties the bar again about two ticks later.
     5. Repeat. The player pulse-runs at the bottom of the bar and the
        `run_resume_stamina_percent` hysteresis never engages once.
   - **What it contradicts:** AC 5 / R6 ("while the latch is set, running is refused ... until
     current stamina is `>=` threshold") and the field's own contract at `hero_state.gd:99-100`
     ("set when a held run key drains stamina to empty") -- the implementation sets it when a held
     run key is STILL held one tick after empty, which is a different rule.
   - **Suggested fix direction:** also set `run_locked_out` immediately after the drain `spend()`
     when the pool then reads `is_zero_approx`.
   - **Consequence of that fix, named:** the latch-set tick moves one tick earlier than the
     "tick-301" reading recorded in the code comment, so AC 9's timing text needs to agree. If the
     operator reads the current shape as a deliberate design choice rather than a defect, it is his
     to rule -- but as written the code and the field's own doc disagree.

3. **[Med] Task 11 is checked, but its live-smoke half has not happened.**
   - Task 11 reads "Full suite green before and after; live smoke per the amended procedure above
     (AC 14)". Only the suite half is evidenced.
   - The Completion Notes themselves carry Task 10 TO the Live Smoke, and no smoke record, no
     `main.tscn` flip diff and no step-by-step result exists anywhere in the story.
   - Either split the checkbox (suite / smoke) or leave it unchecked until the smoke runs. This is a
     story-file correction, not a code change.

4. **[Med] The golden isolation record's suite counts cannot all be true.**
   - **What the Debug Log records:** 842/1/6909 before the re-baseline with the golden as the only
     failure; 842/0/6909 with `"run_locked_out"` removed from `to_snapshot()` and "nothing else
     changed"; 842/0/6909 after restoring.
   - **The conflict, measured:** `test_debug_window_countdown.gd:107-114` reads
     `to_snapshot()["p1"]["hero"].keys()` and pins the exact sorted list INCLUDING `"run_locked_out"`.
     - If that pin was already updated when the removal run happened, the removal run must have
       FAILED it -- 842/1, not 842/0.
     - If it was updated afterwards, the pre-re-baseline run must have shown TWO failures, not one.
   - `test_replay_identity.gd`'s classification test is NOT affected (it scans declared members of
     `src/state/*.gd` by source text, not snapshot keys), so the pin above is the sole conflict --
     but one is enough.
   - The reproduced pre-story hash `9ed4c903...` may well still be true; the reviewer did not re-run
     a mutation (review-only). What is wrong is the RECORD. Correct it, or re-measure and record the
     counts the experiment actually produced.

5. **[Low] Stale comments survived the AC 12 retirement, and a required Completion Notes line is
   missing.**
   - Stale comments (all naming a now-deleted thing as live):
     - `src/controllers/gamepad_profile.gd:49` -- `flick_threshold`'s doc still cites
       "`deadzone` and `normalize_move_magnitude`" as its live siblings.
     - `src/ui/debug/debug_instrument_panel.gd:56` -- "story 6-3b's retirement of the pitch
       placement switch brings it back to four". It is now three.
     - `test/integration/test_record_save_control.gd:18-19` and `:146-147` -- both still describe
       the pinned set as "the one shipped 2-6 switch plus ...". Only the assertion MESSAGE at
       `:177-181` was updated, not the two doc blocks that explain it.
   - **Missing Completion Notes line:** Task 5 explicitly required noting that
     `match_runner.gd:462`'s `panel.gamepad_profile = load(...)` becomes a dead assignment, kept
     deliberately. That note is absent from the Completion Notes. Confirmed dead by content: the
     member `debug_instrument_panel.gd:63` now has no reader anywhere in `src/`.

6. **[Low, advisory] Attack-phase steering now scales `walk_speed`, not `move_speed`.**
   `src/state/match_state.gd:3886-3899`
   - ATTACKING is excluded from the predicate (`6-7/R17`), so an attacking hero takes the WALK
     branch and `_attack_phase_multiplier` then scales 2.5 rather than 5.0.
   - Inert today: all three multipliers are authored `0.0`, so the product is zero either way.
   - A future non-zero retune would get half the in-swing steering the 3-0b documentation implies
     (`balance_config.gd:50-63`). Worth one doc line where the multipliers are authored; no code
     change required, and no AC rules it either way.

7. **[Low, advisory] A mid-match balance reload leaves one tick of walk at full stamina.**
   - `_apply_balance_to_player` refills stamina (`match_state.gd:4196`) but does not touch
     `run_locked_out`.
   - The next tick's `_resolve_movement` still reads the latch as set, so the hero walks for that
     one tick; that same tick's `_regen_stamina` then clears it (stamina is at max, well above the
     threshold).
   - Debug-reload path only, one tick, self-healing. Named, not a defect.

8. **[Low, advisory] The latch sets on empty stamina from ANY source, not only run drain.**
   `src/state/match_state.gd:3879`
   - A roll or attack that empties the bar, followed by holding run while moving, sets the latch.
   - This MATCHES AC 9's own text ("At empty stamina, a held run key produces WALK ... and the R6
     latch sets"), so it is not a defect against the ACs.
   - It is the field doc at `hero_state.gd:99` ("set when a held run key drains stamina to empty")
     that is narrower than the shipped behaviour. Worth widening when finding 2 is addressed.

9. **[Low, advisory -- ruling on P5's named item] `test_match_state.gd:158,162,185,188` discarding
   the bool is ACCEPTABLE; no follow-up task.**
   - All four calls are DEAD-branch contract tests (`test_dead_hero_velocity_zeroed_every_tick`,
     `test_dead_hero_facing_frozen`). `_resolve_movement` returns `false` at `:3789` before the
     predicate is ever evaluated, so there is no "actually running" fact for them to ignore.
   - The Completion Notes overstate them as "movement tests that now silently ignore the 'actually
     running' predicate this story exists to deliver". They are corpse-contract tests.
   - An optional `assert_false(ms._resolve_movement(...))` would pin DEAD -> false for free, but
     nothing requires it and the discarded return is legal GDScript.

10. **[Low] Story-record hygiene.**
    - The Debug Log's last recorded integration run is "59 PASS, 2 FAIL ... neither touched this
      pass". True of the 0.6 pass, but it is the ONLY integration run in the Debug Log, and the
      final state is 61/61 with both files touched. The final run is recorded only in the Change Log
      and Completion Notes, never in the Debug Log the evidence audit reads.
    - The File List's docs bullet contradicts itself in one line: "(Tasks 1-11 checked, Task 10
      stays unchecked...)".
    - Task 5 said the dev pass "must check" `_check_panel_layout` against the now-empty `Switches`
      column and name either outcome. The check is not recorded as measured anywhere, though the
      test does pass (reviewer-verified).
    - `test_a_v10_record_is_refused_with_a_reason` asserts `error.contains("10")`, a loose match
      (any error text containing the digits would satisfy it). The version-restore half immediately
      below is the real bite, so the test is not vacuous -- but the `contains` pair is weaker than
      it looks.

11. **[Low] A garbled comment shipped in a committed test fixture.**
    `test/integration/test_replay_verifier_tool.gd:213-214`
    - The comment reads "...so gait is a no-op and the move_dir-sign divergence [IT HASHES THE
      REPLAY] needs still reaches a non-zero, direction-dependent velocity...". The bracketed phrase
      and the stray "needs" are an editing artifact -- the sentence does not parse.
    - The FIX itself (`c.walk_speed = move_speed`) is correct and is the `6-7/R11` shape verbatim;
      only the comment is damaged. Not caught by any gate because comments are not asserted on.

**Dismissed after verification (not findings):**
- `balance_ticks` null while `balance` is set: impossible, they are assigned together at
  `match_state.gd:674-675`.
- The latch clear comparing against `balance.max_stamina` instead of the pool's own maximum:
  `_apply_balance_to_player`'s `set_maximum(config.max_stamina)` keeps the two equal by construction.
- The round reset not clearing the latch: `_reset_player` does not reset stamina either, so the
  latch stays coherent with the pool it describes.
- BLOCKING's speed change from 5.0 to 2.5: ratified by `6-7/R10` / AC 16, not a regression.
- The `walk_speed` 0.0 default, and the version bump not guarding a field strip: both ratified by
  AC 1 and AC 15's correction respectively.
- Drain while pushing into a wall (moving with zero displacement): `6-7/R3` defines the predicate on
  `move_dir`, not on displacement.
- The empty `Switches` column and its retained `VBoxContainer`: ruled in Task 5.
- Keyboard running during keyboard cast mode: AC 4's suppression is pad-scoped, and keyboard cast
  mode uses distinct keys, so there is no equivalent collision to close.
- No `run_stamina_drain_per_second > 0.0` audit: not in AC 13's named list, and
  `E1_BALANCE_FIELDS` already covers non-negativity.
- Task 10's unchecked box: unchecked BY DESIGN per the operator's instruction; its record was
  audited instead and is accurate (P6).

**Not changed by this review, deliberately:** Status stays `review` and `sprint-status.yaml` is
untouched. The operator's review-only constraint overrides the skill's status-sync step. No sidecar
report was written to `C:\dev\_6-7-review.md` (the standing `E5-R/R2` artifact rule) for the same
reason -- the operator's constraint scoped findings to this file; flagged in chat rather than done
silently.

### Review Follow-ups (AI)

- [x] [AI-Review][High] Add headless behavioural tests for ACs 4, 5, 6, 7, 8, 9, 10, 11, 16 and 17,
  plus AC 2's `run_stamina_drain_per_tick` derivation. Every test mutation-proven. At minimum:
  - The authored-value test (`max_stamina = 50.0`, drain `10.0`/s, `>=300` ticks from full),
    asserting `is_zero_approx(get_current())` AND `run_locked_out` -- the evidence AC 7/AC 9 word as
    a MUST.
  - Walk 2.5 / run 5.0 velocity per action state, and BLOCKING + run held at walk speed.
  - The per-tick drain amount.
  - Regen suppressed while running, and NOT suppressed while latched and walking.
  - Resume on the next tick at `>=` threshold, with no re-press.
  - Attack/roll entry stops the drain, and running resumes on the first IDLE tick after exit.
  - Regen resuming at last-running-tick + 47.
  - `resolve_card_tick`'s `run_held`: true on bare A, false under `cast_held`.
  - Code sites: `match_state.gd:3862-3911`, `:2436-2438`; `gamepad_controller.gd:443`;
    `balance_ticks.gd:135`. (Finding 1.)
- [x] [AI-Review][Med] Close the latch bypass: when the drain `spend()` leaves the pool at
  `is_zero_approx`, set `run_locked_out` on that same tick, so releasing run on the next tick cannot
  skip the resume threshold. Reconcile AC 9's tick-301 timing text and the `hero_state.gd:99` field
  doc, and cover the case with a release-at-empty test.
  (Finding 2; `match_state.gd:3877-3881`, `:3907-3911`.)
- [x] [AI-Review][Low] Fix the stale retirement comments: `gamepad_profile.gd:49`,
  `debug_instrument_panel.gd:56` ("four" should read three), and
  `test_record_save_control.gd:18-19` and `:146-147` ("the one 2-6 switch"). (Finding 5.)
- [x] [AI-Review][Low] Repair the garbled comment at `test_replay_verifier_tool.gd:213-214` (the
  stray "[IT HASHES THE REPLAY] needs" fragment). (Finding 11.)

## Senior Developer Re-Review (AI) — 2026-09-16 (fix-pass verification)

**Reviewer:** Claude Opus 5, 2026-09-16. NARROW VERIFICATION RE-REVIEW, stated as such: the
`gds-code-review` skill has no re-review path, so this is not a second three-layer pass over the
whole story. Scope is the fix pass's closures only — finding 2's code fix, finding 1's new test
file, and the record corrections (findings 3, 4, 5, 10, 11) — plus the one P-audit whose code the
fix pass touched. The original review section above is untouched and still stands as the record of
the first pass.

**Baseline:** `git diff 86b7d11` — 36 modified paths plus 1 untracked
(`test/state/test_locomotion_gaits.gd`), exactly as expected. No edits made outside this section.

**Suite, re-run by the reviewer** (foreground `bash test/run_all.sh`, exit 0; PROC/R1 disclosure:
one review-verification run, stated and reported, not absorbed into the dev pass's budget):
- State: `854 tests, 0 failed, 6963 assertions` — the predicted count exactly.
- Integration: `ALL TESTS PASSED` (61 files).
- `GOLDEN` is unchanged by the fix pass (`71a7b45f…`, the dev pass's single re-baseline) and
  `test_state_matches_golden` is green: the one-tick-earlier latch set is golden-NEUTRAL, which is
  expected — every golden fixture authors `walk_speed == move_speed` and no golden intent builder
  presses `&"run"` (`6-7/R11`), so no golden path reaches the latch at all.

### Verdict: APPROVE WITH FINDINGS

Finding 2's fix is CORRECT and the exploit is genuinely closed. Finding 1's absence is closed: 12
real tests, none of them in the cannot-fail class as tests. Every record correction (3, 4, 5, 10,
11) landed as described and introduced no new contradiction. Three Low findings remain, all of them
in the DOCUMENTATION AND COVERAGE of the new test file — two false claims in its docstrings, and
one assertion that cannot fail against the fix it is attributed to. None blocks; the fix itself is
proven by the Debug Log's red-green run and by reading. One correction to the ORIGINAL review's own
P2 reasoning is recorded below.

### 1. Finding 2's fix — VERIFIED CLOSED

The fix is the six lines at `match_state.gd:3907-3921` (drain `spend()`, then a post-drain
`is_zero_approx` latch set), with the pre-drain set at `:3897-3898` unchanged.

**(a) It sets the latch only when the drain's own spend leaves the pool empty — YES, provably.**
The post-drain check sits inside `if actually_running:`, and `actually_running` is
`pursuing and not run_locked_out and not stamina_empty` where `stamina_empty` is the PRE-drain
read. So on any tick that reaches the post-drain check the pool was non-empty BEFORE the spend; if
it reads `is_zero_approx` AFTER, the only write between the two reads is this line's own
`spend()`. The attribution is structural, not inferred.

**(b) It cannot set the latch on a non-running tick — YES.** Same guard. `_run_pursuit_active`
already excludes ATTACKING / ROLLING / CHARGING / STUNNED / BLOCKING and requires
`intent.is_held(&"run")` and a non-zero `move_dir`, and the whole block is inside the `else` arm
below the ROLLING/CHARGING/STUNNED velocity carve-outs, under `balance != null`, after the DEAD
early return.

**(c) The original 5-step scenario, walked against the new code — closed at step 1.**
1. Tick N: hero actually running, `spend()` takes the pool to empty. **NEW: the post-drain check
   fires on this tick and `run_locked_out` is already true when tick N ends.**
2. Tick N+1: the player releases run (or the stick, or enters BLOCKING/ATTACKING). `pursuing` is
   false, so the pre-drain set does not fire — but there is nothing left to set. The latch is
   already held.
3. The delay elapses; regen adds 0.25/tick. Regen is NOT suppressed (the AC 8 disjunct reads
   `actually_running`, which is false on a latched walk) — by design, Fact M3.
4. The player re-holds run. `run_locked_out` is true, so `actually_running` is false regardless of
   the stamina read: WALK.
5. The latch clears only in `_regen_stamina` at `>=` `run_resume_stamina_percent` of
   `max_stamina`. The hysteresis engages on the first cycle. Exploit closed.

**(d) No new hole opened.**
- A roll/attack spend that empties the bar while run is held mid-action: `pursuing` is false for
  ROLLING/ATTACKING/CHARGING/STUNNED/BLOCKING, so neither set site fires DURING the action. The
  latch lands on the first tick the hero reads movement normally again while still empty, via the
  pre-drain set. That is the same outcome one tick-class later, and it is the behaviour AC 9's own
  text asks for.
- `hero_state.gd`'s widened doc MATCHES the code. Its "SAME tick" clause is scoped to the run
  drain's own spend (true, post-drain set); its "fires from ANY source that empties the bar while a
  pursuing run key is held" is true of the pre-drain set, which re-evaluates `pursuing` every tick
  and does not care who emptied the pool. The only nuance the sentence leaves implicit — a foreign
  spend's latch lands on the next PURSUING tick, not on the spend tick — is consistent with both
  the text and AC 9. No finding.
- `spend()` can no longer be refused on this path: the `minf` clamp guarantees
  `amount <= _current`, so every running tick is a SUCCESSFUL spend and the AC 17 delay window
  restarts unconditionally. Confirmed against `stamina_pool.gd:42-47`.
- `balance_ticks` cannot be null where the drain reads it: `apply_balance` assigns `balance` and
  `balance_ticks` together (`:674-675`). Unchanged from P1.
- The latch still has exactly ONE clear site (`:2436-2438`); the set now has TWO sites, both
  idempotent and both reachable only under `pursuing`.

**CORRECTION to the original review's P2 (measured this pass, review-only — no mutation applied).**
P2 above says "`add(-amount)` then clamps to exactly `0.0` — so the clamped drain reaches honest
zero and the `1.649e-13` residual `6-7/R16` was written against cannot arise on this path at all."
**That reason is FALSE.** `StaminaPool.add()` early-returns on
`is_equal_approx(v, _current)` (`stamina_pool.gd:28-30`), so the residual spend is a NO-OP, not a
clamp to zero. Simulating the authored path (`max_stamina = 50.0`, drain `10.0/60.0` per tick, the
`minf` clamp, and `add()`'s early-out) gives, at tick 300, `1.64923630308067e-13` — the exact
residual `6-7/R16` names — and it sticks there forever. P2's VERDICT (drain seat SOUND) is
unaffected, because clause (5) and the post-drain check both read `is_zero_approx`, which is TRUE
of that residual; what is wrong is the stated reason. The new test file's own header
(`test_locomotion_gaits.gd:122-127`) describes the residual correctly — it is P2 that was wrong,
not the test.

### 2. Finding 1's tests — all 12 CAN fail; two docstring claims cannot be true

Every test was read end to end and its failure mode traced. None is in the cannot-fail class AS A
TEST. The authored-value MUST test uses `max_stamina = 50.0`, `run_stamina_drain_per_second = 10.0`
and exactly 300 ticks, all three verbatim from `data/balance/balance_config.tres:87-96`, and
asserts BOTH `is_zero_approx(get_current())` and `run_locked_out` — AC 9's MUST satisfied as
worded. Per-test failure modes, in brief: gait speeds (2.5 vs 5.0) flip on any predicate error; the
carve-out test bites if gait ever reaches ROLLING/CHARGING/STUNNED; the AC 8 pair distinguishes
39.9 / 41.0 (drain-only vs regen-only) and fails if suppression keyed on the run key instead of
`actually_running`; the AC 10 test fails on a `>` instead of `>=` clear; the AC 11 pair fails if the
drain survives the action or if resume needed a re-press; AC 16 fails on the stamina assertion if
BLOCKING left the exclusion list (the redundant walk-speed branch would mask the SPEED half, not
the drain half); AC 17's 46/47/48 triple fails if the drain stopped restarting the delay window;
the pad and derivation tests are pure-function pins with exact values.

The direct `_resolve_movement` calls follow the established precedent (`test_match_state.gd:158,
162,185,188`, the DEAD-branch contract tests ruled acceptable at finding 9) and do not test a seam
`advance()` would contradict: under `advance()` a continuously-running hero has regen suppressed
every tick by the AC 8 disjunct anyway, so the 300-tick drain trajectory is identical; the
carve-out calls assert only the velocity those states produce inside `advance()` too.

The Debug Log's red-green claim is COHERENT and names the right two tests: with the post-drain
latch line removed, `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` and
`test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick` are exactly the two that fail,
both on their `assert_true(... run_locked_out ...)`, and the identical `6963` assertion count across
both directions is consistent with `TestCase`'s continue-on-failure asserts. That is the claim the
Debug Log makes, and it holds.

Two claims in the new file's docstrings do not.

**Finding R1 [Low] The named mutation at `test_locomotion_gaits.gd:130-132` does not fail the
test.** The line reads: "read `player.stamina.get_current() > 0.0` instead of `is_zero_approx(...)`
for clause (5) and this test's `is_zero_approx` assertion fails — the pool sticks at a sub-epsilon
residual forever". The premise is right and the conclusion is wrong: the pool does stick at
`1.649e-13` (measured above), and `is_zero_approx(1.649e-13)` is TRUE, so the assertion PASSES.
Under that mutation `actually_running` stays true at the residual, the drain keeps calling
`spend()` (a no-op through `add()`'s early-out), and the post-drain check — unmutated, and also
`is_zero_approx` — still sets the latch, so the second assertion passes too. The test's real bite
is the post-drain latch line, which the Debug Log's red-green run proves directly. **Fix: correct
the MUTATION line to name the mutation that actually kills the test (removing the post-drain latch
set), or state what the `> 0.0` mutation really breaks (the hero never leaves the run branch) and
assert that instead.** Documentation only; the test stands.

**Finding R2 [Low] The red-green narrative at `test_locomotion_gaits.gd:151-156` misattributes the
pre-fix failure, and contradicts the Debug Log.** It claims that pre-fix "re-holding run one tick
later (stamina still at 0.0 …) produced RUN (`velocity.length() == 5.0`), not WALK". It cannot
have: the PRE-drain set (`if pursuing and stamina_empty: run_locked_out = true`, present both
before and after the fix, and the very line finding 8 was written against) fires on that tick —
stamina is exactly `0.0` and the hero is pursuing — so tick 12 WALKS with or without the fix. The
pre-fix failure is the `assert_true(run_locked_out)` at `:167` (and again at `:170`), which is
precisely what the Debug Log records ("`assert_true` on `run_locked_out`"). The Debug Log is right;
this docstring is not. **Fix: restate the narrative to match the Debug Log.**

**Finding R3 [Low] The exploit's own payload tick is untested, and `:173` cannot fail against this
fix.** As a consequence of R2, the assertion that reads as the regression guard — "pulse-running
exploit closed: re-holding run below threshold WALKS, never RUNS" — passes identically in both
directions, because the test re-holds run while the bar is still at exactly `0.0`, the one state
the pre-drain set already covered. The step the original finding 2 scenario actually turns on is
step 3-4: let the regen delay elapse so the bar holds a NON-ZERO, sub-threshold amount, THEN
re-hold run. Pre-fix that produced RUN (both `stamina_empty` and `run_locked_out` false); post-fix
the latch is already held and it produces WALK. **Fix: extend the test past the delay window (or
add a sibling) so it re-holds run at a non-zero, below-threshold bar and asserts WALK — that
assertion is the one that distinguishes the two builds at the velocity level.** The fix is already
proven by the latch assertions, so this is a coverage completion, not a re-opening of finding 2.

### 3. The record corrections — all five landed, no new contradiction

- **Finding 3 (Task 11 split):** VERIFIED. Task 11a (suite) checked, Task 11b (live smoke)
  unchecked with the reason stated inline. The File List's docs bullet, the Change Log 0.8 row and
  the Completion Notes all say the same thing. `sprint-status.yaml` still reads
  `6-7-locomotion-gaits: review`.
- **Finding 4 (golden isolation):** VERIFIED and now HONEST. The Debug Log records that the golden
  passed and the snapshot-key pin failed in the removal run, and explicitly declines to
  reconstruct the counts that run produced rather than inventing them. The surviving three-run
  bullet no longer restates the impossible 842/0/6909 removal figure. The reproduced pre-story hash
  is left standing with its provenance stated.
- **Finding 5 (stale comments + missing note):** VERIFIED at all four cited sites —
  `gamepad_profile.gd:47-49` (now "its former live sibling, was retired by story 6-7 AC 12"),
  `debug_instrument_panel.gd:54-57` ("brings it down again to three"),
  `test_record_save_control.gd:17-19` and `:144-146` (both name the 6-7 retirement). The
  `match_runner.gd:462` dead-assignment note is present in the Completion Notes with the
  keep-it-deliberately reason.
- **Finding 10 (record hygiene):** VERIFIED. The final 61/61 integration run is now in the Debug
  Log; the File List's self-contradictory docs bullet is corrected and names what it replaced;
  Task 5's `_check_panel_layout` check is recorded as measured PASS. The `contains("10")` note
  needed no change (the review did not ask for one).
- **Finding 11 (garbled comment):** VERIFIED. `test_replay_verifier_tool.gd:212-214` now parses:
  "so gait is a no-op and the move_dir-sign divergence this tool hashes the replay to detect still
  reaches a non-zero, direction-dependent velocity…". The `c.walk_speed = move_speed` fix itself is
  unchanged and still the `6-7/R11` shape.
- **Finding 6 (advisory):** the doc line landed at `balance_config.gd:56-63`, naming that the three
  attack-phase multipliers now scale `walk_speed`. Accurate.

### 4. Nits, not findings

- `test_locomotion_gaits.gd:14-19` says the test balance uses "readable round numbers … NOT the
  authored `.tres` values", but `_config()`'s `move_speed = 5.0`, `walk_speed = 2.5`,
  `max_stamina = 50.0` and `run_resume_stamina_percent = 20.0` ARE the authored values. Harmless —
  the AC 9 test re-asserts the authored numbers explicitly anyway, so the evidence AC 9 demands is
  not weakened — but the sentence is looser than it reads.
- `if state == HeroState.ActionState.BLOCKING: speed = balance.walk_speed` (`:3901-3906`) is now
  redundant with the `else` arm, since `_run_pursuit_active` already excludes BLOCKING. Keeping it
  is defensible (it makes `6-7/R10` explicit at the speed seat and is what AC 16's speed half reads
  against), and it was already SOUND in P3. Named only so a later reader does not mistake it for
  the load-bearing exclusion.

### Re-Review Follow-ups (AI)

- [x] [AI-Review][Low] Correct the MUTATION line at `test_locomotion_gaits.gd:130-132` — the named
  `> 0.0` mutation leaves `is_zero_approx` true on the `1.649e-13` residual and fails neither
  assertion. (Finding R1.) Corrected to name the mutation that actually kills the test: removing
  the post-drain latch set.
- [x] [AI-Review][Low] Restate the red-green narrative at `test_locomotion_gaits.gd:151-156` to
  match the Debug Log: the pre-fix failure is the `run_locked_out` assertion at `:167`, not the
  velocity assertion at `:173`. (Finding R2.) Restated.
- [x] [AI-Review][Low] Extend `test_release_run_on_the_emptying_tick_cannot_bypass_the_latch` (or
  add a sibling) to re-hold run AFTER the regen delay has put a non-zero, sub-threshold amount in
  the bar, and assert WALK — the pulse-run payload the original finding 2 scenario turns on.
  (Finding R3.) Extended the existing test (ticks 12-14) rather than adding a sibling; red-green
  proved (see Debug Log).
- [x] [AI-Review][Low] Correct the original review's P2 reasoning, or let this section's correction
  stand as the record: the clamped drain does NOT reach exact `0.0`; it reaches and sticks at
  `1.649e-13`, which is why `is_zero_approx` is load-bearing at both latch-set sites.
  **Second branch taken: the "CORRECTION to the original review's P2" section above (:1613-1623)
  already states the corrected reasoning and names P2, not the new test, as wrong — no further
  edit needed; checked as satisfied by the existing record.**

**Not changed by this re-review, deliberately:** Status stays `review`, `sprint-status.yaml`
untouched, no sidecar report written, nothing staged and nothing committed — the operator's
review-only constraint, same as the original pass. Task 11b (live smoke) remained the one
outstanding non-review obligation before close-out; closed by the 0.10 live-smoke pass above.
