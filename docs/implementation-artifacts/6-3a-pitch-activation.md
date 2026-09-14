---
baseline_commit: 5d7084709df6c6928363fd35f22d9ae6585013e7
---

# Story 6.3a: Pitch Activation

Status: ready-for-dev

> **Scope note.** E6 planning pass, board order item 5 (decision-log Session 2026-09-08, `E6-P/R2`;
> renumbered by the 2026-09-14 split, `6-3-split/R-SPLIT`). Tier A by the golden clause (`E4-P/R9`).
> This story is HALF of the merged `6-3-pitch-hud-and-activation`, which failed its readiness gate
> (14 blocking findings) on a premise the gate disproved: activation is smoke-visible TODAY through
> surfaces that already ship (orb counters, the in-flight caption, the mana bar, the existing
> rejection cue, the existing cast-success cue) — no HUD is needed to judge it. `6-3b-pitch-hud`
> (the tenth observation seam, both pitch zones, the hand ghost) is driven live by this story's Y and
> comes next, but owns none of this story's scope.

## Measured Facts

1. **The arming mechanism is `GamepadController.resolve_card_tick()`, a pure function, and it is the
   ONLY place a mode-select scheme may live (`test_card_scheme_only_in_controllers`,
   `test_architecture_invariants.gd:505-534`).** `_armed_slot` (`gamepad_controller.gd:89`) persists
   across ticks while the arming modifier (`cast_held`, the `cast_button`/L3 field,
   `data/gamepad_profile.tres:14`) stays held: L2/L1(block)/R1(attack)/R2 arm slots 0/1/2/3 in that
   physical left-to-right order, last-press-wins on a same-tick chord
   (`gamepad_controller.gd:358-366`). Three confirm buttons — X (DEFENSE), A (BASIC), B
   (UNBLOCKABLE) — each commit the armed slot on their own press EDGE, `card_slot = armed_slot`
   **even when `armed_slot == -1`** (`gamepad_controller.gd:368-379`, comment `:294-298`): a commit
   with nothing armed is NOT swallowed by the controller, it reaches state and lands on the existing
   `empty_slot` refusal there. Releasing the modifier resets `armed_slot = -1`
   (`gamepad_controller.gd:380-381`). **Y is read on no line of this file** — no `GamepadProfile`
   field carries `JOY_BUTTON_Y` (`gamepad_profile.gd`, `data/gamepad_profile.tres`) — which is what
   keeps mode ④ PITCH structurally unreachable from the pad today, machine-pinned by
   `test_no_authored_button_maps_to_y_so_pitch_is_structurally_unreachable`
   (`test_gamepad_controller.gd:358-382`).

   **How a fourth arm fits, and the four `6-3-split/R-Y` cases mapped to DISTINCT state outcomes:**
   Y's press edge must be read on BOTH sides of the existing `if cast_held: ... else: armed_slot =
   -1` split (`gamepad_controller.gd:358-381`), because R-Y's four cases split on exactly that
   condition — the other three confirms only ever fire inside the `if cast_held:` arm, but Y must
   also fire in the `else` arm:
   - **modifier held + Y + a slot armed:** `card_commit=true`, `card_mode=PITCH`,
     `card_slot=armed_slot`, a NEW field `card_activate=false` (AC 4) → state's EXISTING
     `_resolve_pitch_stage` runs, landing on either the STAGE outcome (own zone empty, AC 3 of
     `6-2`) or the `REASON_PITCH_ZONE_OCCUPIED` refusal (own zone occupied, `6-2`'s AC 6) — see Fact
     2 for which of these two the guard sequence actually reaches first.
   - **modifier held + Y + NO slot armed:** identical fields with `card_slot=-1` → `_resolve_pitch_
     stage`'s existing `player.hand.is_slot_empty(hand_slot)` guard (`match_state.gd:2822-2824`)
     already treats -1 as empty (the Basic/Unblockable/Defense precedent, `gamepad_controller.gd:
     294-298`) → `CastEvaluator.REASON_EMPTY_SLOT`, reused verbatim, NOT an activation. No new code
     needed for this case beyond Y reaching the dispatch at all.
   - **modifier NOT held + Y:** `card_commit=true`, `card_mode=PITCH`, `card_slot=-1` (irrelevant —
     no hand slot is addressed), `card_activate=true` → a NEW `_resolve_pitch_activate(player, slot)`
     arm (AC 5-9 below), addressing the player's OWN zone: activates if `pitch.is_ready(slot, ...)`
     (already exists, `pitch_state.gd:100-101`), otherwise refused with nothing consumed.

   These are four DISTINCT, separately reachable outcomes in state (stage-success,
   zone-occupied-refusal, empty-slot-refusal, activate-success-or-activate-refusal), matching R-Y
   exactly. No chord, no new binding shape beyond the one new `GamepadProfile.cast_pitch_button`
   field (AC 1) and the one new `InputIntent.card_activate` field (AC 4).

2. **The armed slot is NOT held for a second press after a successful stage — but "REASON_EMPTY_
   SLOT vs. REASON_PITCH_ZONE_OCCUPIED" is decided by GUARD ORDER, not by whether the slot re-arms.**
   `_resolve_pitch_stage`'s guard sequence is LAYER FLAG → STATE GATE (CHARGING/STUNNED) → EMPTY
   HAND SLOT → OCCUPIED ZONE → PITCH-COST LOOKUP → FLAG+MANA (`match_state.gd:2810-2845`, comment
   block `:2782-2809`). A held-modifier Y-press with a slot ARMED and that hand slot's card already
   spent reaches the EMPTY-SLOT refusal (the hand slot itself is now a hole — matching `6-2`'s own
   decision-log close-out candidate, unlabelled in that entry: "a staged slot is an empty slot with
   no replacement owed"), never the
   occupied-zone reason — that is a DIFFERENT slot's hole reached through the EMPTY-SLOT guard, not
   the OCCUPIED-ZONE guard. The occupied-zone reason (`REASON_PITCH_ZONE_OCCUPIED`) is reached only
   when the ARMED HAND SLOT still holds a (different, still-in-hand) card AND that player's zone
   already holds a staged card — e.g. arming a second, still-full slot while a first card is already
   staged. **In order against R-Y's cases:** case 1 (own zone empty, armed slot non-empty) reaches
   neither refusal — it stages. Case 2 with the SAME slot re-armed after its own successful stage
   reaches EMPTY-SLOT (the vacated hole), not OCCUPIED-ZONE. Case 2 with a DIFFERENT, still-occupied
   hand slot armed reaches OCCUPIED-ZONE. This story adds no new guard to this sequence — activation
   is a wholly separate arm (Fact 1's third case) with its own guard order (AC 5-6).

3. **The staging guard order (Fact 2's list) is unchanged by this story; activation's guard order is
   NEW and separately reachable for the first time.** Nothing in `_resolve_pitch_stage` is touched.
   `_resolve_pitch_activate` (new) reads: LAYER FLAG (`flags.pitch_zone`, the same gate) → OWN ZONE
   EMPTY (`not pitch.is_staged(slot)`) → NOT READY (`not pitch.is_ready(slot, player.orbs, flags)`).
   No CHARGING/STUNNED gate on this path (Fact 9). Both new refusal reasons are reachable from a
   live Y press with the modifier not held, for the first time — Y was previously unreachable in
   full (Fact 1).

4. **Dispatch seat: a NEW `InputIntent.card_activate: bool` field, defaulting `false`.** `InputIntent`
   documents its card half as "exactly three things about a cast" (`input_intent.gd:32-36`) — reusing
   the existing triple alone is AMBIGUOUS: both "modifier held, Y, no slot armed" (an empty-slot
   refusal, NOT an activation) and "modifier not held, Y" (an activation addressing the own zone)
   would otherwise both read `card_mode=PITCH, card_slot=-1`, indistinguishable at the state layer.
   Collapsing them onto `card_slot`'s existing resting value (`-1`) would also be a SEMANTICS bump
   under the precedent `test_record_file.gd:162-186` names for `6-1/R4`: FORMAT_VERSION 7→8 was a
   PURE SEMANTICS bump (no shape change) because an old recording's existing meaning would silently
   diverge under new code — reinterpreting a pre-6-3a `card_slot=-1` PITCH commit (always an
   empty-slot stage-refusal, since Y was unreachable) as sometimes-an-activation would be exactly
   that failure mode. A genuinely ADDITIVE new field avoids it.

   **Serializer seats — a dropped field must be measured to fail loudly, not asserted to (three
   safeguards, each named):**
   - `IntentRecorder.copy_intent` (`intent_recorder.gd:563-576`): "All NINE InputIntent fields,
     verbatim... Written as explicit field assignments... so that adding a tenth field... leaves this
     function visibly incomplete instead of silently widening the contract." Needs
     `out.card_activate = src.card_activate`.
   - `RecordFile._intent_values` (`record_file.gd:578-589`) and its rebuild counterpart
     `_intent_from_values` (`record_file.gd:738-751`) both need the `card_activate` key added, on
     the same "written out rather than derived" discipline the file's other per-tick fields use.
   - `RecordFile.REQUIRED_INTENT_FIELDS` (`record_file.gd:258-260`) gains `"card_activate":
     TYPE_BOOL`, validated by `_intent_fields_refusal` (`:458-465`) before the rebuild — the SAME
     seat `retarget_slot`/`retarget_index` sit in today. This is a genuine widening of that list's
     documented scope (its own comment, `:250-256`, names `card_slot`/`card_mode`/`card_commit` as
     "deliberately NOT validated here," finding L8's exact boundary, `5-1a/R6`) — stated here rather
     than left to be discovered, because `card_activate` gates a real state mutation
     (`_resolve_pitch_activate` dispatches on it) the way `retarget_slot`/`retarget_index` gate a
     real retarget, and a dropped bool defaulting silently to `false` on this one field would make
     every replayed activation replay as a stage attempt instead — the exact silent-divergence
     failure mode `REQUIRED_INTENT_FIELDS` exists to catch.
   - **Proof the round trip actually catches a dropped field**, not merely asserted to: BOTH
     `test_the_round_trip_carries_every_channel_verbatim` (`test/state/test_record_file.gd:243`, the
     field-enumerated comparison, `fields += 9` → `fields += 10`, `TICKS * 2 * 9` → `TICKS * 2 *
     10`, and the driven fixture stages a `card_activate = true` NON-DEFAULT tick so the new field's
     comparison is load-bearing, not vacuously `false == false`) AND
     `test_a_saved_record_reloads_and_re_saves_to_the_identical_BYTES`
     (`test/state/test_record_file.gd:371`, the byte-identity round trip, format-agnostic — a
     writer-emits/rebuild-drops mismatch shortens the re-saved file regardless of whether anything
     names the field) move to ten fields. Naming only one of the two would leave the other's
     "everything the writer emits survived, named or not" guarantee unexercised for this field.
   - The recorder captures fields directly off each tick's `InputIntent` inside `capture_advance`
     (`intent_recorder.gd:322`) — no separate capture call is needed (unlike the injected-content
     channels), since intents are captured whole, per tick, already.

   **FORMAT_VERSION consequence, measured against the repo's actual bump doctrine (not assumed):**
   `test_record_file.gd:162-186` states the doctrine explicitly, citing three precedents in one
   place — a bump fires for EITHER a shape change (`4-6`'s AC 14: `aim` deleted, `retarget_slot`/
   `retarget_index` added, 5→6) OR a pure semantics change with zero serialization edits (`6-1/R4`:
   7→8, "the first one in this file's history that the SHAPE did not force" — a v7 recording of a
   mode ② cast would silently replay wrong under the new held-key semantics). This story's new field
   is a SHAPE change (a tenth `InputIntent` field, absent from every pre-6-3a record) — the more
   direct of the two, and the doctrine's own AC-14 precedent is the closer analogue.
   **`FORMAT_VERSION` moves 9 → 10.** A v9 record is refused with a reason, no shim, the
   `test_a_v8_record_without_pitch_costs_is_refused_with_a_reason`
   (`test/state/test_record_file.gd:469`) shape exactly: a real v9-shaped body (no
   `card_activate` key in any intent, the FORMAT_VERSION field naming 9) is refused naming both the
   version found and the version this build speaks, and the SAME body relabelled at v10 is refused a
   second time for the missing key specifically — a new
   `test_a_v9_record_without_card_activate_is_refused_with_a_reason` test, on that precedent's own
   shape. A fifth `Enums.ModeKind` value is NOT used instead: `test_every_declared_mode_has_its_own_
   dispatch_arm` (`test_card_play.gd:253-286`) pins "the pinned list is the whole of `Enums.ModeKind`,
   in declaration order" as EXACTLY four names, and the GDD's four-mode table (`gdd.md:179`) is
   authoritative on there being four modes — a fifth mode value would falsify both, so it is
   rejected here rather than left to be discovered by a broken test.

5. **The expiry-tick edge is real, measured, and RULED (operator ruling `6-3a-gate/R-EXPIRY`).**
   `advance()`'s per-tick order (`match_state.gd:403-627`): step 2 ticks `pitch.tick()`
   (`:490`, BEFORE card resolution); step 6 runs `_deal_pending_decks()` → `_resolve_card_action`
   (`:577-579`, where activation dispatches) → **then** `_resolve_pitch_expiry`
   (`:586-587`, the fizzle exit) → `_deliver_pending_draw` (`:598-599`). `PitchState.is_ready()`
   (`pitch_state.gd:97-101`) reads the orb price against the live pool with NO reference to whether
   the fizzle window is still running; `is_expired()` (`:85-86`) is a wholly separate query nothing
   in the activation path consults. **Consequence: on the exact tick a staged card's countdown
   reaches zero, a same-tick activation attempt is dispatched (step 6, card resolution) BEFORE the
   expiry exit runs (step 6, later in the same step) — `is_ready()` can read true and the card can
   activate on the tick its window has already run out, one tick before the fizzle exit would have
   discarded it.** This mirrors an EXISTING precedent in the opposite direction
   (`match_state.gd:580-585`'s own comment: "a card staged THIS tick against a zero-tick countdown
   fizzles on its own staging tick rather than one late" — the ordering was chosen so staging and
   expiry share the tightest possible loop). **RULED, in the player's favour (`6-3a-gate/R-EXPIRY`):
   a press landing on the exact tick the countdown reaches zero ACTIVATES; it does not fizzle.** No
   guard against the expiry query is added to the activation path — `pitch.is_expired(slot)` is
   consulted nowhere in `_resolve_pitch_activate`.

   **Fizzle and activation share their visible OUTCOME on this boundary tick (card discarded, zone
   cleared, refill owed), and a test written only to that shared outcome would PASS regardless of
   which path actually ran — it proves nothing about whether the press was honoured.** The three
   observables that actually pin ACTIVATION as the path taken: the priced orbs are spent (a fizzle
   spends none), the success signal (`card_cast_resolved`) is queued (a fizzle never queues it,
   Fact 6), and no `card_cast` rejection fires (a refused activation would reject; this press does
   not). AC 10 requires a test asserting all three, on the boundary tick specifically, alongside a
   control run with no press that still fizzles on that same tick — so the test proves the press
   was honoured, not merely that the zone ended up empty either way.

6. **Activation's consequence, measured against what `6-2` shipped.** Precedent is
   `_resolve_pitch_expiry` (`match_state.gd:2860-2868`): `discard.add(card_id)` →
   `pitch.clear(slot)` → `pending_draw_owed.append(hand_slot)` → `pending_draw.start(balance_ticks.
   draw_replacement_delay_ticks)` → `notify_cards_changed()`. Activation reuses this exact shape:
   the card's destination pile is `player.discard` (the SAME pile a cast, and a fizzle, both use —
   no new pile), the hand slot's owed refill is a FRESH `pending_draw_owed.append` at the normal
   delay (this DOES restart the delay window, exactly as fizzle's own append does — there is no
   "resume a partial delay" mechanism anywhere in this codebase, `pending_draw`/`TimingWindow.start`
   always restarts from the full duration). **Mana is not re-spent** — `_resolve_pitch_stage`
   (`match_state.gd:2838`) already spent it at staging; activation's dispatch touches
   `player.mana` on no line. **Unlike `_resolve_pitch_stage`/`_resolve_pitch_expiry`, activation
   DOES queue `card_cast_resolved`** (`match_state.gd:2737`'s pattern, `_resolve_basic_cast`'s own
   seat) — `6-2`'s AC discipline explicitly withheld it at staging ("nothing resolved — the card is
   waiting, not played"); activation IS a resolution (a `spell_*` no-op cast already queues this
   signal today per the `4-1/R3`/`4-1/R10` "a no-op is still a successful cast" ruling this story
   inherits unchanged) and this signal is the exact seat the shipped cast-success cue already
   consumes (Fact 6's smoke-surface citation below).

   **Orb layer disabled, measured:** `CastEvaluator.orb_costs_affordable` (`cast_evaluator.gd:124-
   137`) reads `true` whenever `flags == null or not flags.orbs` REGARDLESS of the priced orbs or
   the pool's actual contents (the graceful-degrade rule, `:98-106`) — so `is_ready()` can read true
   with the orb layer off even if the priced orbs were never banked. `OrbPool.add(color, amount)`
   (`orb_pool.gd:67-78`) floors at 0 on a negative amount when unbounded (`maxi(0, updated)`,
   `:70`) — a spend against an empty or partially-empty pool with the layer off is a SILENT FLOOR,
   not a crash and not a negative excursion. **This story's spend therefore uses NO
   `Invariant.check` on the orb subtraction** (unlike `ManaPool.spend()`'s asserted pairing,
   `match_state.gd:2838`) — the floor is legal, expected behavior under the graceful-degrade rule,
   not a disagreement between an evaluator's verdict and a pool's state.

7. **The affordability primitive: `CastEvaluator.orb_costs_affordable(orb_costs, orbs, flags)`
   (`cast_evaluator.gd:124-137`) is the ONE seat with the sorted-colour iteration
   (`colors.sort()` over plain `Enums.CardColor` ints, never StringNames — the pointer-ordering
   hazard this repo avoids everywhere, the same file's own header comment `:108-113`).** It is
   already public and already the seat `PitchState.is_ready()` calls (`pitch_state.gd:100-101`), so
   the READY check needs no new code. The SPEND, however, is a mutation (`OrbPool.add` calls),
   which `CastEvaluator` may never perform — its own header states "PURE means it COMPUTES, it does
   not APPLY... the mutation happens in `MatchState.advance()`'s ordered dispatch"
   (`cast_evaluator.gd:14-18`). **One ORDERING seat, TWO CONSUMERS — not one shared loop.** Extract
   the sorted-keys derivation (`orb_costs.keys(); colors.sort()`) as its own small public static,
   `CastEvaluator.sorted_orb_colors(orb_costs: Dictionary) -> Array`. This is the ONE place the
   sort-and-order decision lives, but it has two SEPARATE call sites, honestly: the EXISTING read
   loop inside `orb_costs_affordable` (refactored to consume it) and a NEW write loop inside
   `_resolve_pitch_activate`'s spend (`player.orbs.add(color, -int(orb_costs[color]))` per colour,
   inline in `match_state.gd`, the `ManaPool.spend()`-in-dispatch pattern, never inside
   `CastEvaluator`). Two loops, one ordering function between them — not the single loop the
   extraction might otherwise suggest.

   **The price source, named (closes the gate's "no named source" finding).** `PitchState` gains
   ONE public read accessor, `staged_orb_costs(slot: int) -> Dictionary`, returning `_orb_costs[slot]`
   by value (the `stage()`/`clear()` by-value discipline already in this file). `is_ready()` is
   refactored to call it (`staged_orb_costs(slot)` in place of the private field read it uses today)
   and the activation spend calls the SAME accessor — so the readiness check and the spend read the
   priced orbs off the identical seat, and a dev cannot re-derive the price from `CardData` a second
   time without visibly bypassing this accessor. This is an ACCESSOR, not a new hashed member:
   `PitchState.to_snapshot()` gains no field (AC 11 still holds).

   **Orb layer disabled, measured, and now pinned.** `CastEvaluator.orb_costs_affordable`
   (`cast_evaluator.gd:124-137`) reads `true` whenever `flags == null or not flags.orbs` REGARDLESS
   of the priced orbs or the pool's actual contents (the graceful-degrade rule, `:98-106`) — so
   `is_ready()` can read true with the orb layer off even if the priced orbs were never banked.
   `OrbPool.add(color, amount)` (`orb_pool.gd:67-78`) floors at 0 on a negative amount
   (`maxi(0, updated)`, `:70`) and, when the floored result equals the pool's already-0 count,
   returns WITHOUT emitting `orbs_changed` (`:75-76`, "if updated == current: return") — so a spend
   against an empty pool with the layer off is a SILENT NO-OP: no crash, no negative excursion, and
   no change signal at all. AC 7 requires a test that stages a card with the orbs layer off, never
   banks the priced colour, activates, and asserts the pool stays at 0 with no `orbs_changed` signal
   observed — the graceful-degrade rule made concrete on the one path this story adds that spends
   orbs.

8. **The Y-guard and its two open items.** `test_no_authored_button_maps_to_y_so_pitch_is_
   structurally_unreachable` (`test_gamepad_controller.gd:358-382`) asserts, by content, that no
   `GamepadProfile` button field carries `JOY_BUTTON_Y` and that `gamepad_controller.gd` contains no
   inline `JOY_BUTTON_Y` literal — its own doc names this "the ONE face button left unwired," and
   its name literally asserts PITCH's continued unreachability. `5-7/R7` (cited by `epics.md:273-278`)
   kept the guard's two open items — its untested evasion forms and its blanket ban on any future Y
   binding — alive explicitly "until the E6 story that actually wires Y forces the question." **This
   story IS that story, and it owes the answer: the guard is RETIRED, not narrowed.** Unlike the
   `6-2/R9` mode-reachability guard (which had three other modes' history of being NARROWED in
   turn before finally retiring), this Y-specific guard has never been narrowed once — it exists
   for exactly one fact (no button maps to Y) and this story makes that fact false by construction
   the moment `cast_pitch_button` is authored (AC 1). Narrowing it further has no target: there is
   no other button left to assert unmapped. It is retired in the SAME change that adds the field,
   not left asserting a premise this story breaks. Its two "kept
   open" items (evasion forms, the blanket ban) are retired WITH it — both were reasons to keep the
   guard alive, not separate obligations once the guard itself is gone.

9. **Hero-state legality, measured, and its dependence on the AC 4 dispatch choice.** `_resolve_
   card_action`'s ONE hero-state gate applies to EVERY mode, unconditionally, before the `match
   intent.card_mode:` block: `if player.hero.action_state == HeroState.ActionState.DEAD: return`
   (`match_state.gd:2563-2564`). The round-over freeze is `advance()`'s own step 1b
   (`:432-435`), also mode-agnostic and unconditional. Both apply to `_resolve_pitch_activate`
   automatically, with NO code added — activation needs no DEAD or round-over guard of its own.
   Unlike `_resolve_pitch_stage`, which adds its OWN CHARGING/STUNNED gates
   (`match_state.gd:2816-2821`, mirroring `_resolve_basic_cast`'s `5-6/AC16` pair), activation adds
   only ONE of the two. `HeroState.ActionState` has exactly seven values (`hero_state.gd:27`:
   `IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING, DEAD`).

   **RULED (operator ruling `6-3a-gate/R-HERO-STATE`): activation is REFUSED while STUNNED and
   ALLOWED while CHARGING.** Reason: stun is a punishment, and a punishment a player can step around
   with a button press is not one; charging is the player's own choice, not a penalty imposed on
   them. Legality is therefore: refused when DEAD (the existing top-of-function gate, unconditional
   for every mode), refused during a frozen round-over tick (`advance()`'s step 1b, also
   unconditional), refused while STUNNED (a NEW gate this story adds, reusing the existing
   `REASON_STUNNED` constant `_resolve_pitch_stage` already uses at `match_state.gd:2819`, no new
   reason token), and legal in every OTHER state — IDLE, ATTACKING, BLOCKING, ROLLING, and CHARGING
   included. This settles the finding that had no recorded source before this session: it was an
   assumption carried in an earlier draft, not a ruling, until `6-3a-gate/R-HERO-STATE`. **This claim
   depends on the AC 4 dispatch choice**: because `card_activate` is read only inside the existing
   `Enums.ModeKind.PITCH:` arm (`match_state.gd:2586-2587`), which the top-of-function DEAD guard and
   `advance()`'s freeze already gate identically for every mode, activation's DEAD/frozen-tick
   legality is a CONSEQUENCE of reusing that arm rather than a fact needing separate proof under a
   different dispatch shape (e.g. a standalone intent field read outside `_resolve_card_action`
   entirely would have needed its own DEAD/freeze guards restated); the STUNNED gate and the CHARGING
   pass-through are this story's own new code, not inherited for free the way DEAD/frozen-tick are.

10. **Golden and suite.** `PitchState.to_snapshot()` (`pitch_state.gd:108-117`) is the ONLY thing
    that moved the golden at `6-2`, and this story adds NOTHING to it — `_resolve_pitch_activate`
    reads `is_ready()`/`staged_hand_slot()`/`staged_card_id()` (all existing) and calls the existing
    `clear(slot)`, which already zeroes `_card_ids`/`_hand_slots`/`_orb_costs`/`_fizzle` to their
    resting values (`pitch_state.gd:67-71`) — the SAME resting values a fizzle already produces
    today. No new `PitchState` member, no new hashed field. `InputIntent` is explicitly excluded
    from the determinism hash by its own header ("deliberately excluded from the to_snapshot()
    contract," `input_intent.gd:14`), so the new `card_activate` field cannot move the golden either,
    regardless of the FORMAT_VERSION bump. **Prediction: golden UNMOVED.** `test_determinism.gd:944,
    983` measures, twice, that the golden's own fixed input sequence "still never commits
    `card_mode == PITCH`" — confirmed by direct read of those lines — so this story's new Y-triggered
    paths (stage-via-Y, activate) are not reachable by the golden's own sequence at all; nothing
    here is expected to move even indirectly. **Obligation to measure both directions stands
    regardless**: run the full suite before this story's changes and after, confirm the golden hash
    is byte-identical in both, and if it is NOT, that is a real, unpredicted regression, not a
    confirmation of the "certain by construction" shape `6-2`'s own moves were. `UNHASHED_CROSS_
    TICK_MEMBERS` (`test_replay_identity.gd`) stays at its current value (4, per `6-2`'s fix pass) —
    no new cross-tick member is added; the orb price cache `_orb_costs` this story reads already
    exists and is already classified. Observation seam count stays at nine (Fact 9's citation,
    unaffected — no `connect_*` ships here, per Non-Goals).

## Story

As the player who has already staged a threat in my own Pitch Zone,
I want to spend a bare press of the fourth card button — with the arming modifier released — to
detonate it the instant its orb price is banked, spending only what it cost and letting my opponent
watch the countdown run out on nothing but a public price and a public clock,
so that the payoff half of the pitch's open-information bluff (`P3`) exists in the state layer,
completing the loop `6-2` began — while the same modifier-held press, on a slot with a card still in
hand, keeps doing exactly what it did before: staging.

## Acceptance Criteria

**The Y button (discharges `epics.md`'s Y-guard obligation, `6-3-split/R-Y`).**

1. `GamepadProfile` gains a `cast_pitch_button: JoyButton` field, defaulting `JOY_BUTTON_Y` — the
   `cast_basic_button`/`cast_unblockable_button`/`cast_defense_button` shape exactly
   (`gamepad_profile.gd:78,98-99`). `data/gamepad_profile.tres` authors the same value explicitly
   (not left to the script default), the shipped-`.tres` half of every sibling field's own pin.
2. `GamepadController.resolve_card_tick()` reads Y's press edge on BOTH sides of the existing
   `cast_held` branch (Fact 1): inside it, Y joins X/A/B as a fourth confirm committing the armed
   slot with `card_mode = Enums.ModeKind.PITCH` and `card_activate = false` (AC 4) — the
   `basic_pressed`/`unblockable_pressed`/`defense_pressed` shape, including the same "a fresh press
   ALWAYS raises the commit even with `armed_slot == -1`" rule (`gamepad_controller.gd:294-298`).
   Outside it (the `else` arm, modifier not held), a fresh Y press raises a commit with
   `card_mode = Enums.ModeKind.PITCH`, `card_slot = -1` (irrelevant — no hand slot is addressed),
   and `card_activate = true`. A same-tick chord between Y and any of X/A/B (unreachable on real
   hardware, reachable from a test) resolves by the SAME "checked in physical order, last write
   wins" rule the other three already share (`gamepad_controller.gd:321-328`) — Y's physical
   position in the checked order is a dev-pass choice, stated and tested, not left implicit.
   `resolve_card_tick()`'s returned `Dictionary` gains a `"card_activate"` key alongside
   `"card_commit"`/`"card_slot"`/`"card_mode"` — the pure function's own output.

   **The caller path — the pure resolver's output only reaches state if `sample()` is wired to carry
   it, which the pure-function AC above does not by itself guarantee.** `sample()`
   (`gamepad_controller.gd:117-217`) reads `resolve_card_tick()`'s returned dict and assigns
   `intent.card_slot`/`intent.card_mode`/`intent.card_commit` under `if result["card_commit"]:`
   (`gamepad_controller.gd:200-206`) — this gains a fourth assignment, `intent.card_activate =
   result["card_activate"]`, inside the same block; without it the pure function computes the right
   value and `sample()` never carries it into the `InputIntent` at all, and activation never reaches
   state regardless of how correct `resolve_card_tick()` is. Y's raw read
   (`Input.is_joy_button_pressed(_device, _profile.cast_pitch_button)`) joins the other three
   confirm reads (`gamepad_controller.gd:161-166`) and needs its OWN previous-held key —
   `_CAST_PITCH_KEY`, on the `_CAST_BASIC_KEY`/`_CAST_UNBLOCKABLE_KEY`/`_CAST_DEFENSE_KEY` shape
   (`gamepad_controller.gd:46,57-58`) — read into `resolve_card_tick()`'s `pitch_raw`/`prev_pitch_raw`
   pair and written back after, the identical `_prev_held[_CAST_*_KEY] = *_raw` pattern the other
   three confirms use. **Y joins the reconnect-priming set.** The `NO_DEVICE`/disconnected branch
   primes `_prev_held[_CAST_BASIC_KEY] = true` / `_CAST_UNBLOCKABLE_KEY` / `_CAST_DEFENSE_KEY`
   (`gamepad_controller.gd:138-140`) so a replug with a confirm already held cannot fire a commit
   with no fresh press; `_prev_held[_CAST_PITCH_KEY] = true` joins that same block, for the
   identical reason — a replugged pad with Y already held must not fire an activation (or a stage)
   with no new press. A new test drives a reconnect with Y held and asserts no commit fires on the
   reconnect tick, the `5-7/R7` reconnect-priming precedent applied to the fourth confirm.
3. `test_no_authored_button_maps_to_y_so_pitch_is_structurally_unreachable`
   (`test_gamepad_controller.gd:358-382`) is RETIRED in the SAME change that authors AC 1 (Fact 8)
   — not narrowed, since no other button is left to assert unmapped. A new test in its place
   confirms `cast_pitch_button` reads `JOY_BUTTON_Y` on both the default profile and the shipped
   `.tres` (the `cast_basic_button`-family pin every other confirm button already has), carrying
   forward the retired guard's own field-count floor (`button_fields.size() >= 8`, the sanity check
   that the scan really found the authored button fields rather than passing vacuously on an empty
   list) into the replacement test's own scan.

**The dispatch seat (discharges `epics.md`'s "activation itself has no dispatch at all yet").**

4. `InputIntent` gains a tenth field, `card_activate: bool`, defaulting `false`, prefix-free and
   meaningful only under `card_mode == PITCH` (Fact 4). `IntentRecorder.copy_intent`,
   `RecordFile._intent_values`, `RecordFile._intent_from_values`, and
   `RecordFile._intent_fields_refusal` all gain the tenth field, each at its own cited seat (Fact 4).
   `RecordFile.FORMAT_VERSION` moves 9 → 10; a v9 record is refused with a reason, no shim, the
   `6-2`/`6-1`/`4-6` shape (Fact 4). `Enums.ModeKind` gains no fifth value (Fact 4's rejection,
   stated so a future reader does not "fix" this into a fifth mode).
5. `_resolve_card_action`'s existing `Enums.ModeKind.PITCH:` arm (`match_state.gd:2586-2587`)
   branches on `intent.card_activate`: `false` (the default, and every pre-6-3a recorded commit)
   calls the EXISTING, UNCHANGED `_resolve_pitch_stage`; `true` calls a NEW
   `_resolve_pitch_activate(player, slot)`. No other line of `_resolve_card_action` changes.

**Activation (`6-3-split/R-Y`'s fourth case).**

6. `_resolve_pitch_activate` refuses, via the existing `HeroState.reject_action("card_cast",
   <reason>)` seam (no crash, no silent no-op, nothing consumed): STUNNED (the existing
   `REASON_STUNNED` constant, reused — `6-3a-gate/R-HERO-STATE`, Fact 9), the layer closed
   (`CastEvaluator.REASON_FLAG_CLOSED`, the same gate `_resolve_pitch_stage` uses), an EMPTY own
   zone (a NEW module-level reason, e.g. `REASON_EMPTY_PITCH_ZONE`, the `REASON_PITCH_ZONE_OCCUPIED`
   token-convention precedent — Y-without-modifier addressing nothing staged is a real, reachable,
   player-visible fact distinct from an empty HAND slot, so it does not reuse
   `CastEvaluator.REASON_EMPTY_SLOT`), or a staged card that is NOT READY (a second NEW reason, e.g.
   `REASON_PITCH_NOT_READY`). **No CHARGING gate** (Fact 9, `6-3a-gate/R-HERO-STATE`) — CHARGING is
   the one non-DEAD, non-STUNNED state `_resolve_pitch_stage` also gates and activation deliberately
   does not: activation is legal in every hero state except DEAD (already gated at the top of
   `_resolve_card_action`, unconditionally for every mode) and STUNNED (this story's own new gate) —
   a frozen round-over tick is also refused (already gated at `advance()`'s step 1b, unconditionally)
   — neither DEAD nor the frozen-tick case needs restating here. Tests pin activation SUCCEEDING
   while CHARGING and REFUSED while STUNNED, with nothing consumed on the STUNNED refusal (no orbs
   spent, zone untouched, no signal queued).
7. On success: only the orbs the staged card's own price required are spent —
   `player.orbs.add(color, -int(orb_costs[color]))` per priced colour, in
   `CastEvaluator.sorted_orb_colors()`'s order, reading the price off `PitchState.staged_orb_costs
   (slot)` (Fact 7's named accessor — the SAME seat `is_ready()` reads, so the spend and the
   readiness check can never read two different prices) — with surplus, and every unpriced colour,
   untouched (`6-3-split/R-SPEND`). No `Invariant.check` wraps the spend (Fact 6's orbs-off/floor
   measurement) — unlike the mana spend at staging, a floored subtraction under the orbs-off
   graceful-degrade rule is expected, not a programming error. A test with the orbs layer off and
   the priced colour never banked confirms the spend floors silently at 0 with no `orbs_changed`
   signal fired (Fact 7). Mana is NOT touched on this path (it was already spent at staging, AC
   discharged by `6-2`).
8. On success: the staged card moves to the staging player's `discard` pile (the SAME pile
   `_resolve_basic_cast` and the fizzle exit both use — no new pile), the Pitch Zone clears via the
   existing `PitchState.clear(slot)`, and the vacated hand slot's replacement is owed through a FRESH
   `pending_draw_owed.append(hand_slot)` at the normal `balance_ticks.draw_replacement_delay_ticks`
   delay (Fact 6) — the identical FIFO mechanism the fizzle exit already uses. **This RESTARTS the
   shared `pending_draw` delay window rather than resuming it** (`player_state.gd:123`,
   `match_state.gd:3402-3424`: `pending_draw` is ONE `TimingWindow` per player, shared by the whole
   FIFO, and every append calls `.start()` at the full duration again) — there is no partial-delay-
   resume mechanism anywhere in this codebase. Consequence, stated rather than left implicit: if a
   DIFFERENT slot's replacement was already counting down when this activation fires, the restart
   pushes that already-in-flight refill back to the full delay too, not just this card's own. This
   is the SAME restart behaviour every other pile-vacating path (`4-B1`'s own append/start pattern)
   already has — not a new regression, but not previously stated in a pitch-adjacent story either.
9. On success: `notify_cards_changed()` fires (the hand's owed-draw state changed) AND
   `card_cast_resolved.emit.bind(slot, card_id)` is queued through the SAME `_queue.push` seat
   `_resolve_basic_cast` uses (`match_state.gd:2737`) — UNLIKE staging, which deliberately withholds
   this signal (`6-2`'s own AC: "nothing resolved — the card is waiting, not played"). Activation IS
   a resolution, matching the existing "a `spell_*` no-op is still a successful cast" ruling
   (`4-1/R3`/`4-1/R10`) this story inherits unchanged — no per-card spell effect resolves here
   (Non-Goals), only the consequence (zone clear, spend, discard, refill, the cast-success signal)
   that makes the resolution real and observable. **Every refusal test in AC 6 also asserts the
   staged card's fizzle countdown is UNCHANGED** — no timer restart, no elapsed-tick reset — on a
   refused activation attempt, alongside the existing mana/orbs/hand/discard/owed no-op assertions,
   since a refusal must leave the zone's own clock untouched as well as everything else. **The
   five-term conservation identity `test_the_five_term_conservation_identity_holds_across_stage_
   wait_and_fizzle` (`6-2`'s own AC, `test/state/test_pitch_staging.gd:186`) asserts must ALSO hold
   across an activation** — the identity gains no new term for activation (the staged card still
   moves hand→zone→discard, the same three piles the identity already counts), and a new test
   extends the existing stage/wait/fizzle sequence with a stage/wait/activate sequence, asserting the
   same identity holds at every point along it.
10. **The expiry-tick edge (Fact 5) ACTIVATES on the boundary tick, ruled in the player's favour
    (`6-3a-gate/R-EXPIRY`).** `_resolve_pitch_activate` adds NO guard on `pitch.is_expired(slot)` —
    the query is not read anywhere on the activation path; `advance()`'s existing per-tick ordering
    (step 6 dispatches card resolution before the fizzle exit) is unchanged. A headless test presses
    activation on the exact tick `test_a_ready_card_still_fizzles_and_consumes_no_orbs`
    (`test/state/test_pitch_staging.gd`) already measures fizzling on — staged with orbs already
    banked, ticked forward `TIMER_TICKS` — and asserts the three observables Fact 5 names: the
    priced orbs are spent, `card_cast_resolved` is queued, and no `card_cast` rejection fires. A
    CONTROL run with no press on that same tick — the existing fizzle test itself, unmodified — is
    the alongside comparison: it fizzles (no orb spend, no cast-resolved signal), so the two tests
    together prove the boundary tick genuinely branches on the press rather than always landing on
    one outcome.

**Determinism and regressions.**

11. `PitchState.to_snapshot()` gains no new field and no new HASHED member (Fact 10) — `PitchState`
    gains one new PUBLIC ACCESSOR, `staged_orb_costs(slot)` (Fact 7), reading the existing unhashed
    `_orb_costs` cache; an accessor is a function, not a member, and it changes nothing about what
    `to_snapshot()` returns. `_resolve_pitch_activate` mutates only `player.orbs`, `player.discard`,
    `player.pending_draw_owed`, `player.pending_draw`, and calls the existing `PitchState.clear
    (slot)`. **Golden: predicted UNMOVED**, measured in both directions regardless (Fact 10) — this
    is not a substitute for the measurement. `UNHASHED_CROSS_TICK_MEMBERS` stays at its post-`6-2`
    value; observation seam count stays at nine.
12. The full suite passes (`bash test/run_all.sh`).

## Non-Goals

- Any HUD or visual presentation of the zone, cost, timer, activation, or refusal — `6-3b`'s
  (Non-Goal inherited from `6-2`, restated: the pitch zones, the hand ghost, and the tenth
  observation seam are `6-3b`'s scope, driven live by this story's Y but not built by it).
- The cancel exit path — no owning story (`epics.md`'s explicit OUT ruling, `6-3-split/R-SPLIT`);
  neither `6-3a` nor `6-3b` picks it up.
- Any per-card spell effect or resolution of Mode ④'s actual payoff — `6-5`'s (the E6 close-out
  story, `R-SPELL`). Activation delivers the consequence (zone clear, spend, discard, refill,
  cast-success signal) only; what the card's own effect DOES stays the named no-op every mode ①
  cast already resolves through (`4-1/R3`/`4-1/R10`).
- Any keyboard pitch path. `KeyboardController` gets no fourth confirm key and no `card_activate`
  wiring — consistent with modes ②/③, which are ALSO gamepad-only today (`5-7`'s scope; no
  `KeyboardController` change shipped there either). Stated explicitly rather than left unsaid.
- A new observation seam (Fact 10) — `6-3b`'s scope talk owns the tenth member.
- Retune of any existing authored number (pitch costs, the stage timer, the orb-clear switch) — all
  `6-2`'s, untouched here.
- An activation-time all-colour orb reset. `6-3-split/R-SPEND` rules the opposite: activation spends
  only the priced orbs (AC 7); there is no all-colour clear anywhere on this path.
- `OrbPool.reset_all()`'s class-doc comment ("Activating a Pitch Effect resets ALL three colors to
  0... TDD 8.2") misdescribes the method under `6-3-split/R-SPEND` and cites the legacy TDD as a
  behavior source, which CLAUDE.md forbids. The dev pass corrects this comment in the same change
  that authors AC 7, since leaving it would misdescribe the method to the next reader who reaches
  for it. This is a doc correction alongside the code change, not new scope.

## Golden Prediction

**Measure both directions — this is not a substitute for the measurement (Fact 10).**

- Predicted UNMOVED. `PitchState.to_snapshot()` gains no new field; `InputIntent` (where the one new
  field, `card_activate`, actually lives) is explicitly excluded from the determinism hash by its
  own header. The golden's fixed input sequence has never committed `card_mode == PITCH`
  (`test_determinism.gd:944,983`, confirmed by direct read), so even if some future story's fixture
  changed that, this story's new paths (Y-triggered stage, activation) still touch no hashed field
  activation itself would move.
- If ANY snapshot field the golden's fixed sequence actually exercises reads differently after this
  story, that is a real regression, not an artifact of a predicted-safe schema change — unlike
  `6-2`, this story predicts NO cause for a re-baseline at all, so any difference found is
  unexplained by design and must be root-caused, not waved through.
- Snapshot key SET: unchanged — no top-level `MatchState` key is added or removed, confirmed by
  measurement against `test_card_observation.gd` and the top-level key-set pin
  (`test_debug_window_countdown.gd`'s citation in `6-2`'s own Golden Prediction section).
- `RecordFile.FORMAT_VERSION` 9 → 10 (AC 4) CANNOT itself move the golden — `test_determinism.gd`'s
  golden path never saves or loads a record file; the version constant governs `RecordFile`'s own
  round-trip refusal, a channel `test_determinism.gd` does not exercise.

## Live Smoke

**Required — built entirely on shipped surfaces, no HUD work (the gate's own disproven-premise
finding).**

**Controller configuration, named.** The shipped default is TWO KEYBOARD slots
(`match_runner.gd:31`'s `slot_controller_kinds` export default; `src/main/main.tscn` carries no
override), and this story authors NO keyboard path (Non-Goals) — Y is unreachable from either
default slot. A gamepad slot requires a MANUAL textual edit to `src/main/main.tscn` (flipping one
slot's `slot_controller_kinds` entry to `GAMEPAD`), made with the editor CLOSED (a running editor
can silently re-save scene state around a hand edit) and REVERTED after the session with a `git
diff` check confirming `main.tscn` is byte-identical to its pre-smoke state — the same discipline
this repo already uses for the Pitch Zone A/B switch and the magnitude switch (both in-memory
resource flips, not scene edits; this one touches the committed scene file, so the diff check is
load-bearing here in a way it is not there).

**The rejection cue is IDENTICAL for every refusal reason** — occupied-zone, empty-slot, empty-own-
zone, and not-ready all sound the same. The four outcomes are told apart by the REASON TEXT in the
debug inspector (`connect_hero_action_rejected(slot, inspector.on_action_rejected)`, already wired
per-slot, `match_runner.gd:447`), never by ear — every item below that cites "the rejection cue"
also requires reading the inspector's reason string to confirm WHICH refusal actually fired, not
just that some refusal did.

State per item whether it is headless-provable (the state suite already proves it) or requires a
live pad (a real press, timing, or perceptual judgment call).

1. **Stage-via-Y (case 1, modifier held, slot armed, own zone empty).** Arm a slot (hold L3, press
   L2/block/attack/R2), press Y. EXPECT: the mana bar drops by the staged card's mana price, and the
   hand slot goes BLANK — no card face, and no in-flight caption, since staging alone owes no
   replacement draw (the caption is activation's own surface, item 6 below, not staging's — do not
   conflate the two: a blank slot here means only "nothing is drawn yet," never "a replacement is
   coming"). The orb counters do NOT move (staging spends no orbs). Headless-provable (state
   suite) for the transition itself; the smoke confirms the SAME shipped surfaces a Basic cast
   already proves live.
2. **Occupied-zone refusal (case 1's sibling, modifier held, a second slot armed while a card is
   already staged).** With a card already staged, arm a DIFFERENT, still-occupied hand slot and
   press Y. EXPECT: the rejection cue plays, the debug inspector names the occupied-zone reason,
   nothing is spent, the already-staged card is untouched. Smoke-only for the AUDIBLE/inspector
   judgment; headless-provable for the state-side refusal itself.
3. **Empty-slot refusal (case 2, modifier held, no slot armed).** Hold L3 alone, press Y with no
   prior L2/block/attack/R2 press this hold. EXPECT: the rejection cue plays, the debug inspector
   names the empty-slot reason, nothing is spent, no zone changes. Smoke-only for the cue/inspector
   read; headless-provable for the refusal.
4. **Activation, empty own zone (bare Y with nothing staged, refused — the case the gate found
   missing).** Release the modifier (or never hold it), with the player's own zone empty, press Y
   alone. EXPECT: the rejection cue plays, the debug inspector names the empty-own-zone reason
   (`REASON_EMPTY_PITCH_ZONE`, AC 6), distinct from the empty-slot reason in item 3 — nothing
   is spent, no zone changes. Smoke-only for the cue/inspector read; headless-provable for the
   refusal.
5. **Activation, not ready (own zone staged, orb price NOT yet banked).** Stage a card, release the
   modifier without banking its orb price, press Y. EXPECT: the rejection cue plays, the debug
   inspector names the not-ready reason, nothing is spent, the card stays staged, its countdown
   keeps running (unchanged — AC 9's fizzle-countdown-unchanged assertion, smoke-observable as "the
   card is still there afterward," not a numeric read). Smoke-only for the cue/inspector read;
   headless-provable for the refusal.
6. **Activation, ready (own zone staged and orb-affordable), scripted for the surplus claim.**
   `R-SPEND`'s claim — only the priced orbs are spent, surplus survives — is invisible with exactly
   the priced amount banked (spend-to-zero looks identical to "nothing was tracked"). Orbs bank ONE
   per landed unblockable in the priced colour, so seeing surplus survive requires landing TWO
   unblockables of the priced colour before staging (banking 2 against a 1-orb price, the common
   authored cost) — land both, THEN stage the card, release the modifier, press Y alone. EXPECT: the
   cast-success cue plays (the ONE cue this story adds that is NOT the shared rejection cue — it is
   already distinguishable by sound, no inspector read needed for this one), the orb counter drops
   by exactly the priced amount and the SURPLUS orb remains visibly on the counter, the debug
   inspector shows the card moved to discard, and a new in-flight caption appears in the now-vacated
   hand slot once the replacement draw is owed (this is the FIRST point in this sequence the caption
   legitimately appears — contrast item 1). Smoke-only for the cue and the visible orb-counter
   delta/surplus; headless-provable for the state transition and the exact spend amount.
7. **The expiry-tick edge (AC 10) is NOT live-observable and is declared headless-only.** The match
   runs at 60Hz with no rendered countdown, and stepping samples only the tick it lands on — a real
   pad press cannot reliably be timed to a single tick boundary, so this case is excluded from the
   required live observations entirely. Its pin is AC 10's headless test (pressing on the exact tick
   `test_a_ready_card_still_fizzles_and_consumes_no_orbs` already measures fizzling on, asserting the
   three activation-specific observables against a no-press control on the same tick) — that test,
   not this smoke session, is where the boundary tick is proven.

## Dev Notes

### Reuse and precedent map (do not re-derive these)

- `_resolve_pitch_expiry` (`match_state.gd:2860-2868`) is the shape for `_resolve_pitch_activate`'s
  success path: clear the zone, discard the card, owe the replacement at the normal delay — Fact 6.
- `CastEvaluator.orb_costs_affordable` (`cast_evaluator.gd:124-137`) is the ONE seat with the
  sorted-colour order; extract its sort step as `CastEvaluator.sorted_orb_colors()` and have the
  activation spend loop (in `match_state.gd`, NOT on `CastEvaluator` — that file never mutates,
  Fact 7) consume the same order. This is one ordering function with TWO call sites (the existing
  read loop and the new write loop), not one shared loop (Fact 7).
- `PitchState.staged_orb_costs(slot)` (Fact 7) is the ONE read accessor for the priced orbs;
  `is_ready()` and the activation spend both read through it, never through a second re-derivation
  off `CardData`/`_pitch_costs`.
- New rejection reason constants follow `REASON_PITCH_ZONE_OCCUPIED`'s own precedent
  (`match_state.gd:2771-2775`): module-level `const ... := &"..."` beside `_resolve_pitch_activate`,
  not on `CastEvaluator` (a state-side occupancy/readiness fact the evaluator never sees).
- `GamepadController.resolve_card_tick`'s existing confirm-button triple
  (`gamepad_controller.gd:333-411`) is the shape for wiring Y; its own extensive header comments
  document the exact edge/suppression/chord rules a fourth confirm (and Y's own doubled read, inside
  AND outside the `cast_held` branch) must follow.
- **Call-site cost of the signature change.** `resolve_card_tick()` is a long, entirely POSITIONAL
  static parameter list (`gamepad_controller.gd:333-346`, nineteen params today) with exactly ONE
  call site, `sample()`'s own call (`gamepad_controller.gd:177-188`) — adding `pitch_raw`/
  `prev_pitch_raw` grows both the signature and that one call site by a matched pair, and because
  every argument is positional (no named args in GDScript static calls), the two new args must land
  in the SAME relative position in both places or the call silently mismatches types with no error
  until a test catches the wrong value flowing through. One call site keeps the blast radius small,
  but it is also the whole reason a positional mismatch here would be easy to miss without a test
  exercising Y specifically.
- `IntentRecorder.copy_intent`, `RecordFile._intent_values`/`_intent_from_values`/`_intent_fields_
  refusal` (Fact 4's citations) are the three seats the new `card_activate` field must reach; each
  is documented, in its own file, as deliberately written to fail loudly on an incomplete field list
  — trust that documented discipline rather than searching for a fourth seat.

### Project Context Rules

- `D3(a)`/`D3(b)`/`A2`/`F1` (CLAUDE.md load-bearing invariants) are machine-checked by
  `test_architecture_invariants.gd`. This story's `Input.*` read (Y's button state) lives entirely
  under `src/controllers/gamepad_controller.gd`, exactly where the existing three confirms already
  live — no new `Input.*` site, no global RNG/`Time`/`OS`/`Engine` in `src/state/`, and no new
  `_physics_process`.
- Commit discipline: docs and code never share a commit; PowerShell has no `&&`; commit messages are
  pure ASCII via `git commit -F <tempfile outside the repo>`; trailer `Co-Authored-By: Claude Sonnet
  5 <noreply@anthropic.com>` — confirm against the live system reminder at commit time, since this
  has changed between stories before (`6-2`'s own Dev Notes note the same caveat).
- Tier A: full gate + review + live-smoke ritual applies. Live Smoke is REQUIRED for this story
  (unlike `6-2`, which deferred it) — see the Live Smoke section above for the exact surfaces and
  the required controller configuration.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md:179,207,221,255,256,322,415 — Mode ④ table, the priced-orb-spend correction, Orbs economy layer]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:206-296 — E6 key stories, Y-guard obligation, cancel OUT ruling]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — Session 2026-09-14, `6-3-split/R-SPLIT`, `R-Y`, `R-SPEND`, `R-INFO`, `R-REFUSE`; Session 2026-09-14, `6-3a-pitch-activation` readiness gate outcome, `6-3a-gate/R-EXPIRY`, `6-3a-gate/R-HERO-STATE`]
- [Source: docs/implementation-artifacts/6-2-pitch-staging.md — staging's full guard order, reuse map, and the (unlabelled) close-out candidate "a staged slot is an empty slot"]
- [Source: src/controllers/gamepad_controller.gd:1-448 — arming mechanism, resolve_card_tick, sample(), the reconnect-priming block, the Y-omission doc block]
- [Source: src/controllers/gamepad_profile.gd:78-99 — confirm-button field shape]
- [Source: data/gamepad_profile.tres — shipped button bindings]
- [Source: src/state/input/input_intent.gd — the "exactly three things about a cast" doc, the determinism-exclusion header]
- [Source: src/state/match_state.gd:403-627 — advance()'s per-tick order, the expiry-tick edge]
- [Source: src/state/match_state.gd:2560-2868 — _resolve_card_action, _resolve_pitch_stage, _resolve_pitch_expiry, REASON_STUNNED, the existing reason constants]
- [Source: src/state/pitch/pitch_state.gd — is_ready, is_staged, is_expired, clear, to_snapshot, the new staged_orb_costs accessor]
- [Source: src/state/economy/cast_evaluator.gd — orb_costs_affordable, the pure/no-mutation header]
- [Source: src/state/pools/orb_pool.gd:67-78 — add()'s floor behavior and its silent no-signal return, reset_all()'s stale class-doc]
- [Source: src/state/hero_state.gd:27 — ActionState enum, the seven-state list]
- [Source: src/state/player_state.gd:123-124 — pending_draw / pending_draw_owed, the shared-timer restart]
- [Source: src/systems/intent_recorder.gd:556-577 — copy_intent's "all nine fields, verbatim" discipline]
- [Source: src/systems/record_file.gd:180,250-260,431-458,578-589,738-751 — FORMAT_VERSION, REQUIRED_INTENT_FIELDS, per-tick intent serialization seats]
- [Source: src/main/match_runner.gd:31 — slot_controller_kinds' default two-keyboard-slot shape]
- [Source: src/main/main.tscn — the scene file the Live Smoke's manual gamepad flip touches]
- [Source: src/main/match_runner.gd:447,502,531-533 — the shipped observation seams the Live Smoke rides (debug inspector rejection reason, rejection cue, cast-success cue)]
- [Source: test/state/test_gamepad_controller.gd:358-382 — the Y-guard test this story retires]
- [Source: test/state/test_card_play.gd:253-286 — test_every_declared_mode_has_its_own_dispatch_arm, the four-mode pin]
- [Source: test/state/test_record_file.gd:243,371,469 — the field-enumerated round trip, the byte-identity round trip, the v8-refusal precedent this story's v9-refusal test follows]
- [Source: test/state/test_pitch_staging.gd:186,264,295 — the five-term conservation identity, the fizzle-at-deadline test, the boundary-tick fizzle test AC 10's test presses activation on]
- [Source: test/state/test_determinism.gd:944,983 — the golden's PITCH-mode-never-committed measurement]

## Change Log

- 2026-09-14: Story authored (`gds-create-story`), split from the merged `6-3-pitch-hud-and-
  activation` at that story's 2026-09-14 readiness gate (`6-3-split/R-SPLIT`). All content measured
  against the repo at baseline `5d70847`. NOT cleared for a dev pass.
- 2026-09-14: Readiness-gate fix pass. Seven blocking findings closed: the expiry-tick edge ruled
  (`6-3a-gate/R-EXPIRY`, AC 10 rewritten to a settled AC with the three-observable test); the price
  source named (`PitchState.staged_orb_costs(slot)`, AC 7/AC 11); the sorted-colour extraction
  corrected from "one seat" to one ordering function with two consumers, plus an orbs-disabled test
  (AC 7); serializer safety closed (both round-trip tests named and moved to ten fields,
  `REQUIRED_INTENT_FIELDS` gains the new key, `FORMAT_VERSION` 10, a v9-refusal test, AC 4); hero-
  state legality ruled (`6-3a-gate/R-HERO-STATE`: refused while STUNNED, allowed while CHARGING, AC
  6/Fact 9); the controller path closed (`sample()`'s write of `intent.card_activate`, Y's own
  previous-held key, the reconnect-priming set, AC 2); Live Smoke rewritten (the scene-file gamepad
  flip named, the missing bare-Y-nothing-staged case added, the rejection-cue/inspector distinction
  stated, the discard-count HUD read dropped, the blank-slot/in-flight-caption conflation fixed, the
  two-landing orb script added, the expiry tick declared headless-only). Docs-only; no code or test
  file touched — the ACs below describe what the dev pass builds. Promoted `authored` ->
  `ready-for-dev`.
