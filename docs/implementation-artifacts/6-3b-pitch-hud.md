---
baseline_commit: 5c34e1bb547b66e20d87040d544fb8aa9b33f540
---

# Story 6.3b: Pitch HUD

Status: ready-for-dev

> **Scope note.** E6 planning pass, board order item 6 (decision-log Session 2026-09-08,
> `E6-P/R2`; renumbered by the 2026-09-14 split, `6-3-split/R-SPLIT`). Tier A by the golden clause
> (`E4-P/R9`). This story is the OTHER HALF of the merged `6-3-pitch-hud-and-activation`, which
> failed its readiness gate (14 blocking findings) on a premise the gate disproved: activation is
> smoke-visible without a HUD, and the gate's own base-rate tally has been stale since `4-0`
> (decision-log Session 2026-09-14, `6-3-split/R-SPLIT`). This story is driven live by `6-3a`'s Y
> (`6-3a-pitch-activation`, done) and needs no scaffolding of its own — staging and activation
> already mutate `PitchState` in shipped code before this story adds a single line.
>
> **Information scope (operator ruling, 2026-09-15).** Both pitch zones — own and opponent — show
> exactly the same three things: the card, the countdown, and whether it is READY. NEITHER zone
> shows how many orbs are missing, for either player. A player reads shortfall by eye from the orb
> counters (5-4, already shipped) against the card's public price. `6-3-split/R-INFO` is unchanged:
> its purpose — never reveal the opponent's exact held orb count — is satisfied here BY
> CONSTRUCTION, because no shortfall or per-colour orb number exists anywhere in the pitch HUD, so
> there is no number that could reach the wrong player. This story lands strictly inside `R-INFO`;
> it does not amend it.

## Measured Facts

1. **Every existing HUD channel is a `connect_*` wrapper on `match_runner.gd`, called once per slot
   in the two-slot HudRoot construction loop (`match_runner.gd:389-439`), and the observation-seam
   family is machine-frozen at NINE by `test_runner_observation_seams_are_exactly_nine`
   (`test/state/test_architecture_invariants.gd:309-332`).** The guard regex-scans every
   `func connect_*(` DECLARATION under `res://src/main/` and diffs the sorted list against
   `OBSERVATION_SEAMS` (`:291-307`); it does not count call sites, so it is silent about HOW MANY
   consumers wire a seam, only about how many DIFFERENT seam functions exist. A tenth declaration
   anywhere under `src/main/` fails the final assertion (`:328-332`) — the guard is proven falling
   by its own two non-vacuity asserts at `:312-315` (a real declaration matches; a call site does
   not). The nine declarations are `match_runner.gd:992, :1006, :1014, :1024, :1659, :1669, :1681,
   :1711, :1749`. **Five of the nine PRIME ON CONNECT** — `connect_hero_hp_changed`,
   `connect_stamina_changed`, `connect_mana_changed`, `connect_cards_changed`, `connect_orbs_changed`
   (`match_runner.gd:1656-1755`, each doc-commented "PRIMES ON CONNECT (2-4/R2)") — invoking the
   callback once, immediately, with the live value. The other four —
   `connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`,
   `connect_deflect_landed` (`:992-1027`) — do not prime; they are bare `.connect(callback)` calls
   with no immediate invocation.

2. **The one MATCH-LEVEL precedent (no slot argument in the `connect_*` signature) is
   `connect_hit_landed`, and the slot(s) ride the PAYLOAD, never the binding.**
   `signal hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)`
   (`src/state/match_state.gd:30`); `func connect_hit_landed(callback: Callable) -> void:
   _match_state.hit_landed.connect(callback)` (`match_runner.gd:1006-1007`, doc `:1001-1005`,
   "Match-level (attacker AND target ride the payload), so there is no slot argument"). Every
   OTHER seam that needs slot identity puts it in the `connect_*` call's own `slot: int` parameter
   and does the identity check with `Invariant.check` inside the wrapper
   (`connect_hero_action_state_changed`, `match_runner.gd:992-998`) — the opposite shape. A
   match-level consumer that needs to know "is this payload mine" gets its own slot BOUND at wiring:
   `connect_hit_landed(cues.on_hit_landed.bind(slot))` (`match_runner.gd:503`); HudRoot already
   uses the same bind for the ownerless bus (`EventBus.round_ended.connect(hud.on_round_ended
   .bind(slot))`, `match_runner.gd:429`; `on_round_ended(loser_index, my_slot)`, `hud_root.gd:316`).
   `E6-P/R8`(2) (decision-log Session 2026-09-08) rules that the pitch HUD gets a NEW MEMBER of the
   observation-seam family, never a second `MatchState` direct-connect.

3. **`PitchState` (`src/state/pitch/pitch_state.gd`) has NO signal today and is owned solely by
   `MatchState.pitch` (`match_state.gd:173`).** Its public read surface: `is_staged(slot)`,
   `is_expired(slot)`, `staged_card_id(slot) -> StringName`, `staged_hand_slot(slot) -> int`,
   `is_ready(slot, orbs, flags) -> bool` (`:100-101`, derived live, never latched — "THERE IS NO
   READY FLAG", `:27-29`), `staged_orb_costs(slot) -> Dictionary` (`:108-109`), and `to_snapshot()`
   (`:116-125`). **`PitchState` cannot compute READY by itself:** `is_ready` takes the pool and the
   flags as ARGUMENTS, and the class "reads no balance" (`:31-32`) and holds no orb pool —
   `MatchState` is the one object holding the zone, both players' `OrbPool`s, the injected `flags`
   and `balance_ticks` together. **No remaining-time accessor exists on `PitchState`:** the fizzle
   window's `remaining_ticks()` lives on `TimingWindow` (`src/state/timing/timing_window.gd:50-51`),
   and `PitchState` exposes it only through `to_snapshot()`'s per-zone `"fizzle"` dict
   (`duration_ticks`/`elapsed_ticks`/`is_running`, `pitch_state.gd:120-125`,
   `timing_window.gd:54-59`). **`MatchState` has no public tick accessor** (`func
   get_tick|tick_count|current_tick`: 0 hits); `_tick` (`match_state.gd:192`) is read in-class by the
   existing state-layer `_tick % interval` throttles (Fact 6).

4. **Orb presentation (5-4) is three per-colour count LABELS, own-slot only, written from a
   PRIMING seam.** `_build_orb_counters()` (`hud_root.gd:690-716`) builds three `Panel`+`Label`
   pairs top-right (`anchor 1,1,0,0`, `offset_left -134` to `offset_right -10`,
   `offset_top 10` to `offset_bottom 46` — 124×36); `on_orbs_changed(red, blue, green)`
   (`:210-213`) writes `str(count)` into each label, own-slot-only because the payload carries no
   slot index (`:203-206`). These counters are how a player reads their own orb position against a
   staged card's price; this story adds no other orb read.

5. **`cards_changed`'s payload carries no explicit `hand_slot` field — the array INDEX is the slot.**
   `func on_cards_changed(hand_ids: Array, deck_count: int, _discard_count: int,
   pending_draw_owed: Array = [], card_colors: Dictionary = {}) -> void:` (`hud_root.gd:243-245`)
   iterates `for i in _own_card_labels.size()` and reads `hand_ids[i]`; `i` IS the hand slot, and
   EVERY call rewrites ALL four slots (`:246-259`). **Three distinct looks exist today, enumerated
   exhaustively by the function's own branches:** (a) real card id → tinted caption + colour swatch;
   (b) `pending_draw_owed.has(i)` → the literal string `"..."` (`IN_FLIGHT_CAPTION`, `:145`), no
   swatch; (c) neither → blank `""`, no swatch — and (c) is the ONE look shared by BOTH the ordinary
   empty slot and 4-0 AC 8's PERMANENT hole (`:234-236`). **A STAGED card's vacated slot is look (c)
   today:** staging empties it (`hand.remove_at`, `match_state.gd:2845`) and deliberately does NOT
   append it to `pending_draw_owed` (doc `:2799-2803`); the slot is appended only when the card
   leaves the zone — activation (`:2915`) or expiry (`:2938`). So today a staged slot renders
   IDENTICALLY to the permanent hole. The staged-card ghost this story adds (AC 6) is a FOURTH,
   dimmed look, distinguishable from all three — most load-bearingly from (c). `cards_changed` is
   queued with its payload bound at push (`player_state.gd:279-280`) and arrives as a separate
   drained callback from any other signal queued on the same tick.

6. **One F2 press is exactly one tick, by the runner's own gate.** `_physics_process`
   (`match_runner.gd:2492`): `if _debug_input.pause_pressed(): _paused = not _paused` then
   `var ticking := not _paused or _debug_input.step_pressed()`; both reads are EDGES ("one tick per
   press", comment `:2493-2498`), and gather/advance/drive run only when `ticking`. The
   armed-card-selection push (`_huds[0/1].set_card_selection(...)`, `:2514-2515`) runs OUTSIDE the
   `ticking` gate every frame. **The tick-modulo throttle precedent exists in both layers:** the
   runner-owned probe throttle `_probe_counter % minion_retarget_interval_ticks == 0`
   (`match_runner.gd:1882`, `_probe_counter` declared `:111`, reset `:1054`), and the state-layer
   twin `_tick % balance_ticks.minion_retarget_interval_ticks != 0` (`match_state.gd:3625`, doc
   `:3585-3588`, "NO NEW STATE and NO NEW HASH KEY for the counter itself. `_tick` is already
   hashed"). `MatchState._tick` (`:192`) is incremented once per `advance()` (`:406`) and rides
   `to_snapshot()`'s `"tick"` key (`:996`). **`minion_retarget_interval_ticks` is a minion-AI knob
   read by three minion seats** — state retarget cadence `match_state.gd:3625`, runner probe
   throttle `match_runner.gd:1882`, target-confirmation expiry `match_state.gd:1913`
   (`interval + 1`) — and is documented as shared-by-ruling across minion kinds
   (`balance_config.gd:137-158`). **Authored numbers:** `pitch_stage_timer_seconds = 20.0`
   (`data/balance/balance_config.tres:147`) → 1200 ticks (`timing_window.gd:20-23`; seated
   `balance_ticks.gd:106`, derived `:191`, started `match_state.gd:2850`);
   `minion_retarget_interval_seconds = 0.2` (`balance_config.tres:111`) → 12 ticks
   (`balance_ticks.gd:133-134`). **The seconds→ticks authoring pattern for a MODULO DIVISOR** is the
   `minion_retarget_interval_seconds` / `mana_accelerator_interval_seconds` pair: an `@export` float
   on `BalanceConfig` (`balance_config.gd:158`, `:236`); a `var …_ticks: int` on `BalanceTicks`
   (`balance_ticks.gd:45`, `:66`) derived in `from_config()` as `maxi(1,
   TimingWindow.seconds_to_ticks(...))` (`:133-134`, `:138-139`), so an authored 0 means "every
   tick" rather than a divide-by-zero; the authored value in `balance_config.tres`; an
   `E1_BALANCE_FIELDS` entry in `test/state/test_data_resources.gd` (reflection half (a); half (b)
   independently demands the stem-matched `_ticks` member, doc `:156-161`); a conversion test in
   `test/state/test_balance_config.gd` (`:172-199`); and a bespoke authored `> 0` bound in
   `test/state/test_balance_authoring.gd` (`:394-404`).

7. **The 2-6 placeholder pitch zone is `HudRoot._build_pitch_zone()` (`hud_root.gd:402-416`, node
   name `"PitchZone"`), moved between two anchors by `HudRoot.set_pitch_zone_placement(bool)`
   (`:427-448`)** — anchor A (dead-centre, `offset_left -70/right 70/top -110/bottom -22`, the shipped
   default) and anchor B (left of the vitals bars, `offset_left -286/right -186/top -196/bottom
   -108`, a 100×88 panel). The shared A/B switch is `DebugInstrumentPanel`'s `"PitchZoneLeftOfBars"`
   `CheckButton` (`debug_instrument_panel.gd:182-188`), wired to `_on_pitch_placement_toggled`
   (`:333-335`), which calls `hud.set_pitch_zone_placement(left_of_bars)` on BOTH `huds`. **Exactly
   two test files reference the placeholder or its switch by name:**
   `test/integration/test_debug_instruments.gd:173-176` (`_pitch_ab_ok` — reads
   `p1_hud.get_node("PitchZone")` / `p2_hud.get_node("PitchZone")`, flips
   `panel.find_child("PitchZoneLeftOfBars", true, false)`, asserts `offset_left` moves -70 ↔ -286 on
   both viewports together; header doc `:17-18`) and `test/integration/test_record_save_control.gd:176`
   (`_check_control_set` — asserts the panel's exact `BaseButton` name set is
   `["NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance", "RevealOpponentHand",
   "SaveRecord"]`). The other `test/` files a bare `grep -i pitch` matches reference
   `PitchState`/pitch card costs, never the placeholder. The NAME grep is exhaustive; the retirement
   FALLOUT is wider than the name grep — AC 7 enumerates it.

8. **Layout geometry, both from `HudRoot`, both bottom-centre, stacked:** the vitals column
   (`_build_vitals`, `hud_root.gd:340-352`) spans `anchor 0.5,0.5,1,1`, `offset_left -180/right
   180/top -196/bottom -116` — centre ± 180, 80 tall, directly above the hand row
   (`_build_hand_row`, `:469-480`), which spans `offset_left -184/right 184/top -112/bottom -20`.
   `project.godot` sets no window size and no stretch mode, so the window is Godot's default
   1152×648 (the integration tests force the same, `test_debug_instruments.gd:110`), and
   `main.tscn:93-113` splits it 50/50 with `stretch = true` — each SubViewport is **576×648**, centre
   x 288. In viewport pixels: vitals x 108..468, y 452..532; hand strip x 104..472, y 536..628; the
   anchor-B panel x 2..102, y 452..540; its mirror (`offset_left 186/right 286`) x 474..574, y
   452..540. Both gutters are 108 px wide, leaving 2 px to the strip and 2 px to the viewport edge.
   **The debug `InstrumentBox`** (`debug_instrument_panel.gd:146-153`: anchors 0.5, x ±340, y
   32..126) sits at screen y 356..450, and `test_debug_instruments.gd:_check_panel_layout`
   (`:287-299`, via `_hud_screen_rects` `:303-319`) fails if it intersects ANY HudRoot child Control
   in either viewport. A panel whose top is at `offset_top -196` (y 452) clears it by 2 px; any
   `offset_top` above -198 (y < 450) intersects it.

9. **The golden fixture never commits a PITCH cast.** The ONLY `card_mode =` assignment in
   `test_determinism.gd` is `:1994` (`BASIC`); `card_activate` appears 0 times; the golden builds its
   own flags (`_golden_flags()`, `:1415`) and its own config (`_golden_config()`, the BC/R3
   isolation), and `:944`/`:983` confirm both zones hash empty every tick. No `PitchState.stage` or
   `_resolve_pitch_activate` call is reachable from the recorded golden intent stream, so no pitch
   emission site this story adds (AC 1) is reached during the golden run.

## Story

As a player watching the split-screen match,
I want both pitch zones — my own and my opponent's — rendered on my half, each showing the staged
card, its countdown, and whether it is READY,
so that the buildup→bluff→payoff loop `6-2` and `6-3a` already built in state is finally visible,
without either player being able to read the other's exact orb count.

## Acceptance Criteria

1. **A tenth observation seam, `connect_pitch_changed(callback: Callable)`, is added to
   `match_runner.gd` and to `OBSERVATION_SEAMS` in `test_architecture_invariants.gd` in the same
   commit** (`3-6/R2`/`5-4 AC 15` amendment shape; `E6-P/R8`(2) sanctions this tenth member).
   `test_runner_observation_seams_are_exactly_nine` is renamed and re-asserted at TEN in that commit.
   - **Shape: MATCH-LEVEL**, mirroring `connect_hit_landed` exactly (Fact 2): no `slot` parameter,
     body `_match_state.pitch_changed.connect(callback)`, and it does NOT prime (the `hit_landed`
     family does not; both zones are empty when the HUDs are wired in `_ready`, before the first
     `advance()`, so the empty render is the construction default).
   - **Signal home: `MatchState`.** `signal pitch_changed(slot: int, card_id: StringName,
     hand_slot: int, ready: bool, remaining_ticks: int, duration_ticks: int)` is declared on
     `MatchState` beside `hit_landed`, NOT on `PitchState`: READY needs the zone, the owner's
     `OrbPool` and the injected `flags` together, and only `MatchState` holds all three (Fact 3).
     `PitchState` stays a signal-free pure container.
   - **Payload, closed:** the OWNER slot; the staged card id (`PitchState.NO_CARD` when empty); its
     origin hand slot (`PitchState.NO_HAND_SLOT` when empty); `ready` = `pitch.is_ready(slot,
     owner.orbs, flags)` read at the emission instant, never latched; `remaining_ticks` =
     `duration_ticks - elapsed_ticks` and `duration_ticks`, both read from that zone's `"fizzle"`
     entry of `pitch.to_snapshot()` (Fact 3 — no new `PitchState` or `MatchState` accessor is added;
     both 0 when empty). **NO orb cost, NO shortfall, NO per-colour orb number** rides the payload.
   - **Emission: queued via `_queue.push(pitch_changed.emit.bind(...))`** (the `card_cast_resolved`
     shape, `match_state.gd:2918`), from ONE private helper, at exactly these sites:
     (a) STAGE — after `pitch.stage(...)`, `match_state.gd:2850`;
     (b) ACTIVATE — after `pitch.clear(slot)`, `:2913`;
     (c) EXPIRY — after `pitch.clear(slot)`, `:2937`;
     (d) DEBUG RESET — after `pitch.clear(reset_slot)`, `:4242`;
     (e) ORB GRANT — after `player.orbs.add(...)` in `_grant_landing_orbs` (`:3454`), only when that
     player's zone is staged. This is the one seat where orbs grow inside a staged window (the
     staging clear `:2849` and the activation spend `:2909` each precede their own emission (a)/(b);
     the reset clear `:4296` rides the reset), so READY flips on the tick it becomes true, not up to
     one throttle interval late;
     (f) COUNTDOWN THROTTLE — at the tail of step 6, immediately after `_resolve_pitch_expiry(p2, 1)`
     (`:587`), for each slot whose zone is staged, when
     `_tick % balance_ticks.pitch_countdown_push_interval_ticks == 0` (AC 5). This site carries the
     moving countdown; it also refreshes READY, which covers the one READY-moving event with no site
     of its own — a mid-window balance reload lowering `max_orbs_per_color` (`OrbPool.set_maximum`,
     `:4078`) — within one interval.
     A round-over tick returns at step 1b (`:432-435`) before step 6, so nothing emits while the
     countdown is frozen. No emission site reads or writes a new member (AC 5, AC 9).
   Headless-provable: state tests stage / activate / expire / reset / grant / step across a throttle
   boundary and assert the drained `pitch_changed` payloads at each site, including that a
   non-boundary tick with a staged zone and no event emits nothing.

2. **A NEW machine guard pins the raw `_match_state.<signal>.connect(` sites in `res://src/main/`
   by SHAPE, so a second presentation-to-`MatchState` direct-connect (`E6-P/R8`(2)) fails the
   suite.** Measured at baseline there are SIX such source sites, in three sanctioned shapes:
   - **wrapper body** (callback token `callback`): `hit_landed` (`match_runner.gd:1007`),
     `deflect_landed` (`:1025`) — the match-level seams themselves;
   - **EventBus relay** (callback token begins `_relay_`): `round_ended` (`:356`), `round_started`
     (`:360`), `reshuffle_vulnerable_window_opened` (`:365-366`, callback on the NEXT line) — the
     runner relaying state onto the ownerless bus, a sanctioned runner-relay shape
     (`game-architecture.md:366`), not a presentation consumer;
   - **inline presentation consumer** (callback token `func`): `card_cast_resolved` (`:531`) — the
     ONE sanctioned direct consumer (`E5-C/R2`). It sits inside `for slot: int in 2`, so this one
     SITE makes TWO live connections; the guard counts SOURCE SITES, not live connections, and its
     failure message says so.
   **How the regex tells them apart:** join each file's `_code_lines()` (comment-stripped,
   `test_architecture_invariants.gd:565-576`) with `"\n"` and apply
   `_match_state\.([A-Za-z0-9_.]+)\.connect\(\s*([A-Za-z_][A-Za-z0-9_.]*)` to the whole text, so
   `\s*` spans the line break at `:365-366` and a nested receiver (`_match_state.pitch.x.connect(`)
   is still caught. Each match yields `"<signal>:<shape>"`, where shape is `wrapper` if the token is
   exactly `callback`, `relay` if it starts with `_relay_`, `inline` if it is exactly `func`, and
   `UNCLASSIFIED:<token>` otherwise. The sorted list is asserted EQUAL to a pinned list — at baseline
   `["card_cast_resolved:inline", "deflect_landed:wrapper", "hit_landed:wrapper",
   "reshuffle_vulnerable_window_opened:relay", "round_ended:relay", "round_started:relay"]`, and in
   this story's commit the same plus `"pitch_changed:wrapper"` (AC 1). A named-method consumer
   (`_match_state.pitch_changed.connect(hud.on_pitch_changed)`) yields an UNCLASSIFIED entry and
   fails; a second inline lambda, a second relay, or a removed site each change the list and fail.
   **Stated limitation:** the scan sees only the literal `_match_state.` receiver; an aliased
   receiver (`var ms := _match_state`) evades it — the same class of limit the declaration guard
   has. **Non-vacuity:** the pattern must match a one-line relay sample, a two-line relay sample, an
   inline-`func` sample and a wrapper-body sample, and must NOT match
   `connect_hit_landed(cues.on_hit_landed.bind(slot))` or `EventBus.round_ended.connect(`; the scan
   must visit at least one file. Headless-provable, and TRUE of unmodified code at baseline
   `5c34e1b` (the six sites above).

3. **A live-scene test proves each HudRoot renders ITS OWN zone and the opponent's zone correctly
   and never crosses them, through the one new delivery path — the match-level seam (AC 1).** The
   seam is wired identically into BOTH HudRoots by design, so the cross-wire risk is HudRoot's
   own-slot filter: the payload owner against the slot BOUND at wiring,
   `connect_pitch_changed(hud.on_pitch_changed.bind(slot))` (the Fact 2 bind shape). The
   `test_hud_viewports.gd` stamina method does not transfer: the shipped keyboard controllers have no
   PITCH path (`keyboard_controller.gd`: 0 `PITCH`/`card_activate` hits), and the only PITCH
   producer, `GamepadController` (`gamepad_controller.gd:389-429`), goes neutral without a connected
   joypad (`:109-126`), which no integration test drives. **The route is a synthetic replay record,
   measured reachable:**
   - **Probe phase.** Instantiate `main.tscn` live (default controllers, no input), let it tick past
     the deal (the deal runs in step 6 of the first `advance()`, `match_state.gd:577`, before card
     dispatch), read `debug_hand_contents()` (`match_runner.gd:932-933`) and `recorded_stream()`
     (`:853`), tear down — the `test_replay_contacts.gd:152-157` phase shape. Choose P1 hand slot `a`
     holding id `X` and P2 hand slot `b` holding an id `Y != X`; if no such pair exists in the probed
     deal, the test FAILS with that message (never skips).
   - **Record.** Build a new `IntentRecorder` channel by channel as `_without_contacts` does
     (`test_replay_contacts.gd:108-127`): seed, balance event #0, flags, deck, card costs, effects
     and colours copied from the probe record; the PITCH-COST channel AUTHORED IN-TEST through
     `capture_inject_pitch_costs` (`:123`) — without an entry for the staged id, staging refuses with
     `REASON_NO_PITCH_COST` (`match_state.gd:2838-2840`): `X` → `mana_cost 0`, `orb_costs {}` (READY
     at staging); `Y` → `mana_cost 0`, `orb_costs {RED: 1}` (NOT READY; orbs start at 0).
     `mana_cost 0` removes the mana wait: `flag_and_mana_refusal_reason` refuses only when
     `mana_cost > mana_current` (`cast_evaluator.gd:79`), and `inject_pitch_costs` checks nothing
     against the composition (`match_state.gd:770-782`). The same seed and deck replay the same deal
     (`inject_pitch_costs` consumes no RNG), so the probe's hand read holds. Intents: neutral on every
     tick except tick 2, where P1 carries `card_slot = a, card_mode = PITCH, card_commit = true,
     card_activate = false` and P2 the same with `card_slot = b`. Assign the record to
     `scene.replay_record` BEFORE `add_child` (`test_replay_contacts.gd:74-81`); HUD wiring is not
     replay-gated (`match_runner.gd:389-439`).
   - **Non-vacuity precondition, asserted FIRST:** the test's own listener on `connect_pitch_changed`
     has received a payload with owner 0 and card `X` and one with owner 1 and card `Y`, with
     `X != Y`, WITH THE TWO PAYLOADS' `ready` VALUES DIFFERENT (true for `X`, false for `Y` — this
     requires the record's `flags` to carry `orbs = true`, as the probe-copied flags do; a test that
     built flags in-test instead, where `FeatureFlags.new()` defaults `orbs` to `false`, would pass
     every id assertion below with both payloads READY, vacuously), and `debug_hand_contents()` shows
     P1's slot `a` and P2's slot `b` EMPTY. Only then:
   - **Assertions, both directions:** P1's HudRoot own zone shows `X` and READY, its opponent zone
     shows `Y` and NOT READY, its hand slot `a` shows the ghost of `X`, and no slot of its hand row
     shows a ghost captioned `Y`; P2's HudRoot own zone shows `Y` / NOT READY, opponent zone `X` /
     READY, hand slot `b` the ghost of `Y`, and no ghost captioned `X`. No Label inside either zone
     of either HudRoot has text containing a digit (authored card ids contain none,
     `data/cards/*.tres`) — the headless form of "no orb count is shown" (AC 4). A HudRoot bound to
     the wrong slot, or a filter comparing the wrong value, fails at least one of these.
   The end-to-end run is UNMEASURED (not built); every step names the shipped surface it uses.
   Headless-provable (integration).

4. **Both pitch zones render on each half, each showing exactly the same three facts — the card id
   caption, the countdown as a horizontal bar, and a READY indicator — and NEITHER shows an orb
   count or shortfall.** OWN zone at the shipped anchor-B geometry, LEFT of the vitals bars
   (`offset_left -286/right -186/top -196/bottom -108`); OPPONENT zone at its mirror, RIGHT of the
   bars (`offset_left 186/right 286/top -196/bottom -108`), both `anchor 0.5,0.5,1,1` (Fact 8). An
   empty zone renders blank (no caption, empty bar, no READY). **Geometry constraint:** neither
   zone's `offset_top` may be above -196 — above -198 it intersects the debug `InstrumentBox` and
   `_check_panel_layout` fails (Fact 8); all content fits the 100×88 panel, and the bar spans about
   80 px so one throttle move is about 2 px (AC 5). Headless-provable for the anchors (node offsets)
   and for the no-number property (AC 3's digit check); smoke-only for legibility and the anchor
   verdict. **If the operator rejects anchor B at smoke**, this story still closes with the verdict
   recorded; the replacement placement is a follow-up geometry change (offsets only, under the same
   `offset_top` constraint), tiered by its own measured before/after — not a re-gate of this story.

5. **The countdown moves on an AUTHORED throttle of N = 30 ticks, not every tick** (`2-6/R7`: no
   per-tick timing-window firehose to presentation). N is RULED here (operator, 2026-09-15); the dev
   pass does not choose it. It is its OWN balance field, `pitch_countdown_push_interval_seconds =
   0.5`, derived to `BalanceTicks.pitch_countdown_push_interval_ticks` = 30 — NOT a reuse of
   `minion_retarget_interval_ticks`, which feeds three minion-AI seats (Fact 6), so reuse would make
   a minion retune silently re-pace the pitch bar and vice versa. It follows the modulo-divisor
   authoring pattern (Fact 6) at exactly these seats:
   - `src/state/resources/balance_config.gd`: `@export var pitch_countdown_push_interval_seconds:
     float = 0.0` in the `"Pitch"` group beside `pitch_stage_timer_seconds` (`:481`), doc in the
     `mana_accelerator_interval_seconds` shape (`:225-236`);
   - `src/state/timing/balance_ticks.gd`: `var pitch_countdown_push_interval_ticks: int` beside
     `pitch_stage_timer_ticks` (`:106`), derived in `from_config()` with the `maxi(1, …)` clamp (the
     `:133-134` / `:138-139` shape, NOT the plain `:191` conversion);
   - `data/balance/balance_config.tres`: `pitch_countdown_push_interval_seconds = 0.5` beside `:147`;
   - `test/state/test_data_resources.gd`: an `E1_BALANCE_FIELDS` entry;
   - `test/state/test_balance_config.gd`: a conversion test (0.5 s → 30, 0.0 → 1);
   - `test/state/test_balance_authoring.gd`: a bespoke authored `> 0` bound.
   The modulo is evaluated INSIDE `MatchState` at AC 1 site (f), where `_tick` lives — the
   `match_state.gd:3625` precedent — so no tick accessor is added. At 60 ticks/s and the authored
   1200-tick window: twice a second, 40 moves per window, ~2 px per move on an ~80 px bar. The first
   move lands 1..30 ticks after staging (the phase is `_tick`, not staging-relative). No new state
   member, no new `UNHASHED_CROSS_TICK_MEMBERS` entry (`test_replay_identity.gd:133` stays 4), no
   latching (every emission reads live values). Headless-provable (the throttle boundary in AC 1's
   state tests, the conversion and authoring tests) plus smoke (visible cadence).

6. **The staged card's hand slot shows a dimmed ghost of that same card while staged — a NEW look,
   distinguishable from all three Fact 5 looks (full card, in-flight `"..."`, blank).** HudRoot
   keeps HUD-local memory of its OWN last pitch payload (card id, hand slot) and its own last
   `cards_changed` payload (the `_reshuffle_token` precedent for HUD-local memory, `hud_root.gd:102`;
   no state is added), and both `on_cards_changed` and `on_pitch_changed` render the hand row from
   that memory through one shared path. A slot renders the ghost iff it is EMPTY in the last hand
   payload, NOT in `pending_draw_owed`, and equals the own staged hand slot; a real card and the
   `"..."` caption both outrank the ghost. `on_pitch_changed` compares the payload owner with the
   BOUND `my_slot` (AC 3) and updates ghost memory ONLY for its own payload — an opponent payload
   drives the opponent zone and never touches the hand row. The ghost clears when an own payload
   arrives with `NO_CARD` — activation, expiry, debug reset (AC 1 sites (b), (c), (d)). A test (the
   `test_card_hud.gd:122-140` shape — direct calls on the live-scene HudRoot) proves: (i) the ghost
   is distinguishable from all three existing looks; (ii) an OPPONENT payload naming a hand slot
   never ghosts this HudRoot's hand row; (iii) **the ghost SURVIVES a later unrelated
   `cards_changed`** that rewrites all four slots (e.g. the other slot's refill delivery,
   `match_state.gd:3494`) — the real failure mode, because `on_cards_changed` rewrites every slot on
   every call (Fact 5); (iv) the rendered row is identical whichever of the two callbacks arrives
   first, on a staging tick and on an activation tick (where the slot then shows `"..."`); (v) an own
   `NO_CARD` payload after a debug reset clears the ghost. Headless-provable.

7. **The 2-6 placeholder pitch zone and its shared A/B switch are retired by name, and the dev pass
   runs a CLOSING GREP over the whole fallout surface rather than relying on a closed list.** Deleted,
   not deprecated: `HudRoot._build_pitch_zone()`, `_pitch_panel`, `_pitch_timer`,
   `set_pitch_zone_placement` (`hud_root.gd:402-448`, members `:63-64`); `DebugInstrumentPanel`'s
   `"PitchZoneLeftOfBars"` `CheckButton` (`debug_instrument_panel.gd:182-188`) and
   `_on_pitch_placement_toggled` (`:333-335`). Fallout, each item FIXED IN THIS STORY:
   - `test_debug_instruments.gd`: the `_pitch_ab_ok` block (`:173-176`) is replaced by a check of the
     two real zones' fixed offsets on both HudRoots; `_pitch_ab_ok` leaves the result expression
     (`:136`) and the print (`:141`); the header's A/B paragraph (`:17-18`) is rewritten.
     `_check_panel_layout` (`:287-299`) needs no edit but now covers both new zones and passes only
     under AC 4's `offset_top` constraint.
   - `test_record_save_control.gd`: the expected name set (`:176`) drops `"PitchZoneLeftOfBars"`, and
     the failure message (`:177-178`, "the two switches plus SAVE, RELOAD and REVEAL") is corrected
     to one switch.
   - Stale source comments describing the deleted switch: `match_runner.gd:455-456`;
     `debug_instrument_panel.gd:23-25`, `:35-36` (its pinned control-name list), `:63` — rewritten.
   - Seam-count prose. Rule: a line stating the family count as a PRESENT fact is fixed; a line dated
     to the story that shipped it ("nine as of 5-4/R4", "at eight when this line shipped, nine since
     5-4") is a true historical record and is left. Fixed in this story's CODE commit:
     `match_runner.gd:425`, `:2510`, `:2677`, `:2701`, `:2719`, `:2771`; `match_state.gd:43`;
     `test_architecture_invariants.gd:309`, `:329-330` (renamed and re-messaged by AC 1). Fixed in
     this story's separate DOCS commit: `docs/game-architecture.md:372`, `:537`. Left as historical:
     `telegraph_controller.gd:148-149`, `:156`; `match_runner.gd:363`, `:401`, `:434`, `:491`,
     `:505`, `:517-518`, `:846`, `:922-923`, `:1718`, `:1747`; `match_state.gd:63`, `:80`;
     `unit_board.gd:407`; `debug_instrument_panel.gd:55`. Not seam counts (card-, clip- and
     sibling-count "nine" the gate's broad grep also caught; no action): `test_card_authoring.gd`,
     `test_rig_clips.gd:3-4`, `match_runner.gd:555`, `:605`, `unit_board.gd:177`, `:300`.
     `match_state.gd:1013` reads "the same discipline the nine seams already follow" — it IS a seam
     count, misfiled above in an earlier pass; fixed in this story's code commit alongside the rest.
   - **Closing grep, run once by the dev pass after the above edits land, before this story is
     promoted:** `nine|ninth|PitchZone|placeholder|A/B|exactly_nine` (case-insensitive) over
     `src/`, `test/`, and `docs/game-architecture.md`. Classify every hit in the Dev Notes /
     Completion Notes as either FIXED (this story's code or docs commit) or LEFT AS HISTORICAL (a
     dated record of a past state, true when written and still true). Known hits this grep must
     account for, beyond the bullets above: `hud_root.gd:32-34`, `:40`, `:48-49` (class-doc prose
     naming the placeholder), `:400-401` and the `_build_pitch_zone()` call site `:163`;
     `debug_instrument_panel.gd:181`, `:330-332` (doc/comment adjacent to the deleted CheckButton),
     `:56-57` ("amended to five names" becomes four); `state_inspector.gd:40-41` (stale "clear of
     the centre pitch/telegraph focal band" comment); `game-architecture.md:538` ("the nine D5
     connect seams"); `test_architecture_invariants.gd:273` (stale "a NINTH … must make this FAIL"),
     `:608` ("`OBSERVATION_SEAMS` above stays at NINE"); and five sites that cite the renamed test
     (`test_runner_observation_seams_are_exactly_nine`, AC 1) BY NAME rather than by count —
     `telegraph_controller.gd:148`, `match_runner.gd:517`, `:922`, `unit_board.gd:407`,
     `debug_instrument_panel.gd:55` — each of which must be updated to the new name (not left
     historical, since after this story they would otherwise cite a function that no longer exists).
     Also fix `match_runner.gd:926-929`'s doc comment claiming `debug_hand_contents()`'s "only
     caller is the panel's CheckButton handler", which AC 3's test caller makes false.
   Headless-provable for the deletions and the two rewritten test files; the closing grep and its
   classification are a dev-pass record, not a headless assertion.

8. **No `action_rejected` HUD consumer is added** (`6-3-split/R-REFUSE`), and a guard that can fall
   proves it. The declaration guard (AC 1) cannot see this — it counts `func connect_*(`
   declarations, not calls — and AC 2 counts only raw `_match_state.` connects. The new guard scans
   comment-stripped `res://src/**/*.gd` for CALLS matching
   `(?<!func )connect_hero_action_rejected\(\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*([A-Za-z_][A-Za-z0-9_.]*)`
   and asserts the sorted captured consumer tokens EQUAL `["cues.on_action_rejected",
   "inspector.on_action_rejected"]` (`match_runner.gd:502`, `:447` — the telegraph and the debug
   inspector); and it scans for `action_rejected\.connect\(` and asserts the only site is the wrapper
   body (`match_runner.gd:1017`). A HudRoot consumer (`hud.on_…`), a lambda (`func`), or a raw
   connect each change a list and fail. Non-vacuity: the call pattern matches
   `connect_hero_action_rejected(slot, cues.on_action_rejected)` and does NOT match the declaration
   `func connect_hero_action_rejected(slot: int, callback: Callable) -> void:`; each scan visits at
   least one file. Headless-provable, and true of unmodified code at baseline.

9. **`FORMAT_VERSION` stays 10 and no snapshot key changes** — `PitchState.to_snapshot()` and
   `MatchState.to_snapshot()` are untouched (`FORMAT_VERSION := 10`, `record_file.gd:187`; top-level
   keys pinned at `test_debug_window_countdown.gd:103`). The new signal is presentation-facing only;
   its emission sites (AC 1) READ the fizzle entry and the live pool and add no member, so the `^var`
   scan behind `UNHASHED_CROSS_TICK_MEMBERS` (`test_replay_identity.gd:549`, `:853`) finds nothing
   new. Headless-provable.

## Non-Goals

- Zero input, zero activation logic, zero state mutation of WHEN a card stages or activates — `6-3a`
  delivered Y and it is live; this story only observes what `6-2`/`6-3a` already built. The
  `src/state/` additions are the `pitch_changed` signal with its queued emissions (AC 1) and the
  authored interval (AC 5); neither changes a hashed value.
- **No shortfall and no orb count in either pitch zone** (operator ruling 2026-09-15, Scope note) —
  not the opponent's and not your own. No shortfall reader is added to `CastEvaluator` or anywhere
  else, and no runner-owned push into HudRoot is added.
- Cancel does not exist and is not in scope (`epics.md`'s E6 committed-obligations list: cancel has
  no owning story, `6-3-split/R-SPLIT`).
- `FORMAT_VERSION` stays 10. No snapshot key changes (AC 9).
- No per-card spell effects, no art beyond plain `Label`/`Panel`/bar presentation, matching every
  other HUD element this story touches.
- No keyboard PITCH path (the `6-3a` Non-Goal stands); P1's own zone is therefore not smoke-drivable
  and is proven headlessly (AC 3).
- Does not touch the E6 close-out list: stale `6-4` comments in `match_state.gd`, the stale gate
  base-rate counter (`6-3-split` session note), the GDD cancel description, or the inherited
  LOW-A/C/F/C5 and L1/L2/L3 findings from earlier gates.
- Does not revisit the `pitch_zone` feature flag's default (`data/feature_flags.tres` already ships
  `pitch_zone = true`). This story is presentation-only and does not gate on `pitch_zone` beyond
  what `6-2`/`6-3a` already do.

## Golden Prediction

**UNMOVED.** Fact 9: the golden fixture never stages or activates a pitch card, so AC 1's emission
sites (a)-(d) are never reached, site (e) fires only for a staged zone, and site (f) is guarded by
"zone is staged", which is never true in the golden run. The signal and its queued emissions add no
hashed value and no `var` (AC 9). `_golden_config()` does not set the new balance field; its 0.0
default derives 1 tick (the clamp), which matters only at site (f) and so never fires. The dev pass
must still measure the golden hash in BOTH directions (before this story's changes and after) and
record both hashes — an unmoved PREDICTION is not a substitute for the measurement. The dev pass also
measures, rather than assumes, whether any existing state test that stages a card asserts an exact
drained-signal set that the new emissions would change.

## Live Smoke

**Required — this story ships the HUD that makes `6-3a`'s already-live Y visible for the first
time.** One operator at one split screen: P1 on keyboard (left half), P2 on gamepad (right half).

**Controller configuration, named** (the `6-3a` precedent): add `slot_controller_kinds =
Array[int]([0, 3])` under `[node name="Main"]` in `src/main/main.tscn` (no such line exists there
today; the shipped scene relies on the export's default) with the Godot editor CLOSED, connect one
pad, smoke, then revert and confirm with `git diff` that `main.tscn` is byte-identical to its
pre-smoke state.
Only P2 can stage (no keyboard PITCH path, Non-Goals), so every step drives P2 and reads BOTH halves.
On the pad: stage = hold L3, arm a slot (L2 / block / attack / R2), press Y; activate = bare Y
(`gamepad_controller.gd:389-429`).

1. **Framing, empty.** Launch. On EACH half, confirm two empty pitch zones: one left of that half's
   vitals bars (own), one right of them (opponent). No dead-centre `"PITCH ZONE"` placeholder on
   either half. Smoke-only.
2. **Framing, staged, and no number in any zone.** Mana starts at 0 and every pitch price is 2-5
   mana, so before staging, wait for P2's mana to regenerate enough to cover the card P2 will
   stage — 8-20 seconds, depending which card — or bare Y is refused (silently, aside from the
   rejection cue) and this step cannot proceed. With P2's orb counters at zero, stage a card on P2.
   On the RIGHT half (P2's screen), P2's OWN zone (left of bars) shows the card id, a full countdown
   bar, and NOT READY. On the LEFT half (P1's screen), the OPPONENT zone (right of bars) shows the
   same card, bar and NOT READY, and P1's own zone stays empty. Confirm by eye that no zone on
   either half shows any number. Smoke-only.
3. **READY flips live on both halves.** Before staging in step 2, pick a card to stage whose price
   is 1 orb of its own colour AND whose colour appears on at least one OTHER card in P2's hand
   (with four cards in hand, some colour repeats, but not necessarily the staged card's — check by
   eye and choose accordingly) — this keeps the operator inside the 20-second fizzle window with a
   single landing. While the card is staged, land one Mode ② unblockable of that colour on P2 until
   P2's own orb counter (top-right of the right half) reaches the price. On that tick, P2's own zone
   and P1's opponent zone both switch to READY. Press bare Y on the pad: both zones empty on the
   same tick. Smoke-only.
4. **The ANCHOR A/B VERDICT, open since the 2-6 smoke (finding S4, `2-6/R19`).** Stage again and look
   at the delivered placement on both halves. The operator RULES on legibility — the decision
   `epics.md`'s E6 committed-obligations list says this story "owes." Record the verdict in this
   story's Dev Notes and the decision-log. A rejection takes AC 4's follow-up path.
5. **Countdown cadence.** With a card staged on P2, press F1 to pause, then press F2 one press at a
   time and count presses between visible movements of the bar in P2's own zone: one move every 30
   presses, and P1's opponent zone moves on the same press. Unpause (F1). Smoke-only.
6. **The ghost.** With a card staged on P2, look at P2's hand row on the right half: the vacated slot
   shows a dimmed ghost of the staged card — not blank, not `"..."`, not a full-brightness card. P1's
   hand row on the left half shows no ghost. Let the card fizzle (20 s): the slot shows `"..."`, then
   the refill. Smoke-only for the look; P1's own ghost is headless-only (AC 3, AC 6).
7. **Retirement.** Look at the debug instrument panel: no `"Pitch Zone: left of bars"` checkbox.
   Smoke-only.

## Dev Notes

### Reuse and precedent map (do not re-derive these)

- Seam shape: mirror `connect_hit_landed`/`connect_deflect_landed` exactly (match-level, slot in
  payload, no per-connect slot argument, no priming) — Fact 2, AC 1. Do NOT mirror
  `connect_orbs_changed`'s per-slot shape; `E6-P/R8`(2) names `connect_orbs_changed` as the
  PRECEDENT for a new observation-seam member (`E5-C/R3`) but rules nothing about shape — the
  match-level shape here stands on Fact 2 (READY needs `MatchState`'s pool and flags) on its own.
- Signal home is `MatchState`, and the emission sites are the six AC 1 enumerates — ruled in this
  story, not dev-pass seats.
- HudRoot binding: `connect_pitch_changed(hud.on_pitch_changed.bind(slot))` inside the existing
  construction loop (`match_runner.gd:389-439`), the `on_round_ended.bind(slot)` shape (`:429`).
- Countdown throttle: `_tick % balance_ticks.pitch_countdown_push_interval_ticks == 0`, evaluated
  inside `MatchState` at AC 1 site (f); N = 30 ticks, authored per AC 5. No runner-side counter, no
  tick accessor.
- Ghost rendering: HUD-local memory of the last own pitch payload and last `cards_changed` payload,
  one shared hand-row render path (AC 6); the `test_card_hud.gd:122-140` direct-call precedent for
  its test.
- Retirement: deleted, not deprecated — no dead code, no unused parameter (AC 7 lists every site).

### Named deferral — own-slot shortfall (no owner)

Showing a player their OWN orb shortfall in their own pitch zone was cut from this story on
2026-09-15 by operator ruling. Its only delivery shape was a runner-owned push of player-private,
state-derived data into one HudRoot outside any observation seam — a first-of-its-kind, unguarded
channel that neither the declaration guard nor a direct-connect guard can see. It returns, if at all,
as its own small story after playtest. No owner.

### Project Context Rules

- `docs/game-architecture.md` is authoritative on HOW this is built; this story's seam/emission/
  throttle design is derived from it via the precedents cited in Measured Facts and must not diverge
  without an equivalent citation.
- `test/state/test_architecture_invariants.gd` is the executable form of F1/D3(a)/D3(b)/A2 — this
  story touches none of those directly (no new `_physics_process`, no `Input.*` outside
  `src/controllers/`, no global RNG/Time/OS/Engine in `src/state/`), but it DOES touch the seam-count
  invariant and adds the direct-connect-shape and rejection-consumer guards (AC 1, AC 2, AC 8), all
  in that file.
- Commit discipline: docs and code never share a commit; commit messages pure ASCII via
  `git commit -F <tempfile outside the repo>`; PowerShell has no `&&`; trailer
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` (this session's attribution — confirm
  against whatever the dev-pass session's own system reminder specifies at that time, since this
  field has changed between sessions on this project before).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md#E6 — Pitch Zone (Vision
  Complete), item 6 and the E6 committed-obligations list]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md, Session
  2026-09-08 `E6-P/R2`/`E6-P/R5`/`E6-P/R8`, Session 2026-09-14 `6-3-split/R-SPLIT`/`R-Y`/`R-SPEND`/
  `R-INFO`/`R-REFUSE`; `2-6/R7`, `2-6/R19`, `E5-C/R2`]
- [Source: C:\dev\_6-3b-gate.md — readiness gate report, baseline `5c34e1b` (outside the repo)]
- [Source: src/state/pitch/pitch_state.gd; src/state/timing/timing_window.gd;
  src/state/match_state.gd:403-627 (advance), :2782-2940 (staging/activation/expiry), :3443-3455
  (orb grant), :4154-4300 (debug reset)]
- [Source: src/state/resources/balance_config.gd:130-158/:225-236/:465-481;
  src/state/timing/balance_ticks.gd:40-110/:122-192; data/balance/balance_config.tres]
- [Source: src/main/match_runner.gd:340-540 (relays + HudRoot construction), :853/:932
  (recorded_stream, debug_hand_contents), :992-1027/:1656-1755 (connect_* family), :2488-2525
  (pause/step gate), :1882 (runner throttle precedent)]
- [Source: src/controllers/gamepad_controller.gd:109-126/:375-432 (PITCH gesture, joypad gating)]
- [Source: src/ui/hud/hud_root.gd:243-266/:316/:340-480/:690-716]
- [Source: src/ui/debug/debug_instrument_panel.gd:20-65/:146-188/:333-335]
- [Source: test/state/test_architecture_invariants.gd:285-332/:565-576]
- [Source: test/integration/test_replay_contacts.gd:60-135; test_card_hud.gd:122-140;
  test_debug_instruments.gd:10-20/:130-180/:283-320; test_record_save_control.gd:170-180]
- [Source: test/state/test_data_resources.gd:40-165; test_balance_config.gd:172-199;
  test_balance_authoring.gd:394-404/:942-948]
- [Source: test/state/test_determinism.gd:944/:983/:1415/:1994 (golden never casts PITCH)]
- [Source: test/state/test_replay_identity.gd:133/:549/:853 (UNHASHED_CROSS_TICK_MEMBERS := 4)]

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-09-15 | Story authored from measurement (baseline `5c34e1b`), split from `6-3-pitch-hud-and-activation` per `6-3-split/R-SPLIT`. Not yet cleared for a dev pass. | Claude Sonnet 5 |
| 2026-09-15 | Docs-only fix pass: added the cross-slot HUD bind guard as its own AC (now ten total), corrected the ghost AC/Dev Notes to test against the three existing looks (Fact 5) rather than an unimplementable "four looks" distinction, moved Open Questions to a top-level section holding only the genuinely open throttle-interval question, and moved the signal-placement seat to Dev Notes. | Claude Sonnet 5 |
| 2026-09-15 | Docs-only gate-fix pass against the readiness gate report (`C:\dev\_6-3b-gate.md`, verdict NOT READY). Operator rulings folded in: orb shortfall removed from both zones and from the story entirely (no shortfall reader, no runner-owned HUD push; named deferral in Dev Notes); the countdown interval ruled at 30 ticks as its own authored balance field, and the Open Questions section removed. Gate blockers fixed: the direct-connect guard rewritten to pin the six measured raw-connect sites by shape; the cross-slot test rewritten onto a synthetic replay record with a stated non-vacuity precondition; undefined ruling labels replaced by their content; signal home fixed on MatchState with every emission site enumerated; the rejection-consumer criterion given a guard that can fall; the Live Smoke sequence rewritten for one operator at a split screen. Gate notes folded in: ghost own-slot binding and survive-a-later-rewrite case, retirement fallout enumerated, anchor-B rejection path, corrected line citations. Criteria renumbered; this row cites none by number. Reversal from the pre-fix draft, not previously named here: the old AC (numbered 10 pre-fix) said the pitch signal's payload is "never added to or read from the snapshot"; the no-new-accessor fix to Ruling A/B4 means AC 1 and AC 9 now have every emission READ `pitch.to_snapshot()`'s `"fizzle"` entry instead — a deliberate consequence of that fix, harmless to determinism (a pure read), but an inversion of the earlier sentence. Not yet cleared for a dev pass. | Claude Opus 5 |
| 2026-09-15 | Docs-only fix pass against readiness gate 2 (`C:\dev\_6-3b-gate-2.md`, verdict READY, 0 blockers, 14 notes). Folded in: AC 7's closed "nothing is queued" claim replaced with a mandatory closing grep the dev pass runs and records, classifying every hit as fixed or left historical (N8); Live Smoke steps 2 and 3 now state the mana-regen wait and the same-colour/price-1 hand precondition the operator must arrange before staging, in the operator's own terms (N10); the false `E6-P/R8`(2) citation in Dev Notes corrected — it names `connect_orbs_changed` as the precedent, not a ruling on shape (N14); the dropped Non-Goal clause restored ("presentation-only, does not gate on `pitch_zone` beyond what `6-2`/`6-3a` already do", N12); the unnamed reversal from old AC 10 to the current fizzle-entry read named above in this same row's predecessor entry (N13); the Live Smoke controller-configuration step corrected from "set" to "add … under `[node name="Main"]`" (N11); AC 3's non-vacuity precondition now also asserts the two payloads' READY values differ, not just their card ids (N1). Status stays authored; still not cleared for a dev pass. | Claude Sonnet 5 |

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

Cleared for a dev pass
