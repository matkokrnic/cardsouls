---
baseline_commit: bca08ac52366b7689e0463894b3ce53af4ef3c06
---

# Story 6.5g: Counterspell -- Timed and In-Flight

Status: done

<!-- Tier A. The seventh and last of the 6-5 sub-stories, closing E6's R-SPELL forcing point in
`6-5f-counterspell`'s place (that story's own close-out record). `6-5f` shipped the Counterspell
framework plus six INSTANT-reversal cards (Vanguard, Culling, Grave Ward, Raise Dead, Drain, Boom) and an
INTERIM RULE (`6-5f/R37`, AC 13): a Counterspell targeting a resolution one of the seven TIMED/in-flight
cards produced (Vampiric Aura, Bloodhound Step, Rocksling, Fireball, Honed Bolt, Frostbite, Corpse Bomb) is
refused as "no target". This story implements the reversal of those seven cards and removes the interim
rule. Scope locked in the 2026-09-29 browser scope talk. Repo values cited were read at this authoring
pass: golden `941958c52605abbcd1edf972e002543601325e5a9f98dfce569628c12f75871f`, `RecordFile.FORMAT_VERSION`
18, the per-player snapshot key set 45 (`test_draw_delay_and_reshuffle.gd`'s
`EXPECTED_PLAYER_SNAPSHOT_KEYS`), the STUNNED entry-point census 4
(`test_action_state.gd:test_stunned_has_exactly_three_authored_non_table_entry_points`, itself already
past its own literal name -- read at `res://src/state/match_state.gd x4`). Re-measure every one of these
at the dev pass; nothing in this file is a claim about the repo after any edit. -->

## Story

As the operator (and later the friends playtest),
I want Counterspell to reach back and undo ANY of the opponent's last resolved cards -- including the
seven that resolve over time or through a projectile in flight, not only the six instant ones `6-5f`
shipped -- so that a well-timed counter punishes a cast Honed Bolt, an armed Frostbite, a Rocksling burst
still in the air, or a Bloodhound-boosted roll exactly as it punishes a Vanguard summon or a Boom
detonation, and Deck 1's whole spell family closes with one uniform rule rather than an exception list.

## Board note

`sprint-status.yaml` key `6-5g-counterspell-timed-and-in-flight` moves `backlog -> ready-for-dev` by this
pass (recorded here; the project's `gds-create-story` override then corrects the file-level `Status:` to
`authored` and the board entry back to `backlog` with a `story_notes` line -- see the closing line of this
file). Depends on `6-5f-counterspell` (done): the framework, the per-player reversal packet
(`reversal_kind`/`reversal_indices`/`reversal_a`/`reversal_b`/`reversal_flags`/`reversal_amount`), the
board-gate no-target refusal (`_board_refusal_reason`'s `NEEDS_COUNTER_TARGET` arm, `_counter_target_is_live`,
`_reversal_has_anything_left`), the teardown seats, the golden-isolation method and the placeholder cue are
all `6-5f`'s and are reused unchanged. This is the LAST of the 6-5 sub-stories; the playtest / retune block
sits after it.

## Repo-verified facts this story is authored against

Content citations (grep the quoted string / path); re-verify every one at the dev pass.

- **The reversal packet is ONE per-player record, extended by kind, not redefined.**
  `player_state.gd:775-816`: `REVERSAL_NONE := 0` through `REVERSAL_BOOM := 6`, five generic columns
  (`reversal_indices`/`reversal_a`/`reversal_b`/`reversal_flags`/`reversal_amount`) plus `reversal_kind`,
  each kind giving the columns its own per-kind meaning (`rule_a`/`rule_b`'s own convention, extended to a
  record). `record_resolved_card()` (`:828-832`) IS the clear (`clear_reversal()`); at the basic seat it is
  written BEFORE the cast fork, gated on `not clears_cover` (`if not clears_cover:
  player.record_resolved_card(played, Enums.ModeKind.BASIC, _tick)`); at the pitch seat it likewise precedes
  `start_cast` (`:5401`/`:5404`) -- so a cast card's packet is already cleared and its target already named
  at the PRESS, before the cast frame begins (`6-5g/R6`). **This is the mechanism this story's Class 2
  "target at cast START" clause already rides on -- no new write-timing plumbing is needed for WHEN the
  target is named,** only for WHAT the packet records as the cast progresses (Open Question below).
- **The no-target gate is a closed four-clause predicate, and the seven cards leave `REVERSAL_NONE` today
  only because nothing writes any other kind for them -- but admitting them is NOT a zero-gate-code change.**
  `_counter_target_is_live` (`match_state.gd:5040-5050`) reads `reversal_kind` and nothing else in its
  `REVERSAL_NONE` clause, which needs no change; there is no card-id list anywhere in it.
  `_reversal_has_anything_left` is different: it is a per-kind `match` that falls through to `return false`
  for any kind with no arm, and at cast start `reversal_amount` is still `0.0` (nothing has landed yet) -- so
  a freshly-written `REVERSAL_HONED_BOLT`/`_FIREBALL`/`_ROCKSLING`/`_FROSTBITE`/`_BLOODHOUND`/`_VAMPIRIC_AURA`/
  `_CORPSE_BOMB` packet is judged "nothing left" and refused unless this story adds ONE new arm per new kind,
  each naming what survives for that card (`6-5g/R13`, AC 31). Removing `6-5f/R37`'s interim rule deletes the
  ONE arm that intercepted these seven cards before the gate is reached; it does not by itself make the gate
  admit them.
- **The interim rule is EMERGENT, not a separate code arm -- `6-5g/R1` rules on this exactly.**
  `REVERSAL_NONE` is the whole no-target rule (`player_state.gd`'s own `reversal_kind` header); there is no
  explicit refusal arm anywhere in `src/state` wired for these seven cards specifically -- they are refused
  today only because nothing ever writes them a non-`NONE` kind. "Removing the interim rule" therefore deletes
  exactly THREE textual artifacts, nothing in `src/`: `test/state/test_counterspell.gd:240`
  `test_a_6_5g_card_is_refused_through_the_same_no_target_path` (the only test of the interim rule);
  `docs/implementation-artifacts/6-5f-counterspell.md` AC 13's own text; and `6-5f`'s Live Smoke point 6
  ("Interim refusal on a Honed Bolt").
- **The cast-interrupt seat is `_resolve_cast_strikes`, and it is already the seat this story's Class 2
  cast-cards reuse.** `match_state.gd:6003-6005`: `if _cast_is_interrupted(player): player.clear_cast();
  continue`. `_cast_is_interrupted` (`:6106-6109`) tests `not is_alive() or action_state == STUNNED or
  action_state == DEAD` -- it has NO external-input parameter, so nothing outside a hero's own liveness/stun
  state can call it true. **A Counterspell interrupting a cast in progress does not and structurally cannot
  call `_cast_is_interrupted` true** (the caster is neither dead nor stunned by being countered) -- the
  behaviour this story needs (cast interrupted, caster freed, no STUNNED) is "reach the same OUTCOME
  `clear_cast()` reaches", via whatever call `_apply_counterspell`'s Honed Bolt/Rocksling arms make directly,
  never a literal call to that predicate.
- **The burst schedule (Rocksling) is per-player state independent of the cast, and `_advance_bursts`
  (`match_state.gd:6319-6336`) is its only advancer.** `has_pending_burst()`, `burst_effect_id`,
  `burst_remaining`, `burst_target_slot`, `burst_target_index`, `burst_damage`, `burst_window` are the fields
  (`player_state.gd`, grep `burst_`); `clear_burst()` has FIVE call sites in `src/` today: `_advance_bursts`
  (twice -- the schedule's own exhaustion clears), `_end_round` (twice, `p1`/`p2`), `_reset_player` (once),
  plus `PlayerState.start_burst`'s internal reset. A countered Rocksling cancelling its unfired stones is
  `clear_burst()` called from Counterspell's own arm -- a new call site beside the schedule's own two
  exhaustion clears and the two teardown seats, the SIXTH call site / fourth distinct seat, `6-5f/R30`'s
  prediction realised.
- **Projectile "in flight" has one existing consumption seat, `ProjectileBoard.consume_at(index)`
  (`projectile_board.gd:365`), and one liveness read, `is_alive_at`.** The contact ladder already calls it to
  end a landed/blocked/deflected shot; "vanish" for a countered in-flight Fireball, Rocksling stone or Corpse
  Bomb skull is this same call on the matching living index, not a new removal mechanism. `living_indices()`
  and the per-index accessors (`target_slot_at`, `target_index_at`, `effect_id_at`, `damage_at`,
  `is_hero_sourced_at`) are how a caller finds "this player's projectiles still in flight from this
  resolution" -- the packet needs enough to narrow that search to the ones THIS Counterspell's target
  actually threw (Open Question below; a shared-effect-id board could hold shots from a DIFFERENT
  resolution of the same card if two copies are in flight, `duplicate landed-Rocksling-burst` case).
- **Bloodhound Step's boost is LATCHED at roll ENTRY, not read per tick, and the armed trigger is already
  gone the instant a roll actually starts.** `match_state.gd:1952-1967` (the roll entry arm): if
  `RULE_BLOODHOUND_ARMED` is active, the roll's i-frame count is computed ONCE here, `RULE_ROLL_BOOST` is
  started with the armed rule's OWN `rule_a`/`rule_b` copied in as a fresh, independent, fixed-duration rule
  (`balance_ticks.roll_duration_ticks` -- the ROLL's duration, not whatever was left of the original Bloodhound
  window), and `RULE_BLOODHOUND_ARMED` is cancelled in the SAME branch. The roll's velocity
  (`match_state.gd:6954-6957`, `_resolve_movement`) then reads `RULE_ROLL_BOOST`'s `rule_a` every tick of the
  roll -- but that value was FROZEN at entry and `RULE_ROLL_BOOST` is a wholly separate rule slot from
  `RULE_BLOODHOUND_ARMED`, cancellable or not, that the roll's own fixed timer runs out on its own. **MEASURED
  FINDING (stated fully in Dev Notes below): a natural expiry of the ORIGINAL Bloodhound window while a roll
  is already in progress has ZERO observable effect on that roll**, because the window that would expire
  (`RULE_BLOODHOUND_ARMED`) was already cancelled at roll entry and the roll's own boost
  (`RULE_ROLL_BOOST`) does not read it. This fixes what "counter mid-roll" must do (AC 7 below): nothing to
  the roll already running, by the same construction, whether the packet is cleared by natural expiry or by
  Counterspell.
- **Frostbite has exactly two phases, both ordinary `cancel_rule`-stoppable rules, and `_consume_frostbite`
  (`match_state.gd:3248-3258`) is the one transition between them.** `RULE_FROSTBITE_ARMED` (waiting on the
  caster for a confirmed hero melee hit) is cancelled and `RULE_FROSTBITE_SLOW` (on the struck target) is
  started, in that one function, on the hit. `cancel_rule` on either, while it is the one running, ends it
  immediately with no residual (`is_rule_active` gates every reader) -- the general TIMED-buff behaviour
  `6-5f/R13` already describes, applied to whichever of the two phases the packet's target resolution left
  running.
- **The Honed Bolt landing seat (`_apply_bolt_landing`, `match_state.gd:6374-6390`) is the fourth authored
  `STUNNED` entry point** (`test_action_state.gd`'s own census, currently **4**, `res://src/state/match_state.gd
  x4`) -- a countered Honed Bolt's stun/root end-now clause reads and clears `target.hero.stun`/
  `target.root_window` directly; it does not call `_apply_bolt_landing` again and must not add a FIFTH
  `set_action_state(STUNNED)` site anywhere. The census test is regression-only for this story (re-verify the
  count stays 4 after the dev pass, the same posture `6-5f/R33` recorded for its own break table).
- **`unit_board.gd`'s death seat has exactly six callers today** (`test_corpses.gd`, the "six callers, no
  rival corpse writer" pin, `kill_at(` occurrences 2 in the board / 5 in `match_state.gd`), and 6-5f's own
  close-out already reasoned through the case this story repeats: Corpse Bomb's reversal RESTORES minions
  through the SAME general-restore helper Culling/Drain use (`hp_at_death_at`, `restore_corpse_at`,
  `consume_corpse_at` -- read, not `kill_at`), so it adds no new `kill_at` caller. The seven 6-5g cards
  between them never VANISH a live minion the way `_reverse_summon`/`_reverse_raise_dead` do (no summon
  effect is among them), so this count is regression-only for this story too -- confirm it stays 6.

## Discrepancies found against the prompt (repo wins)

None found. Every mechanism cited above matches the prompt's own description of it; the one thing the
prompt asks to be MEASURED rather than assumed (Bloodhound's latched-vs-per-tick boost) is measured above,
under "Repo-verified facts", and the finding is folded into AC 7 rather than left as an open question.

## Scope carried from `6-5f-counterspell` and the browser talk (unchanged, cited, not restated)

Everything `6-5f` shipped keeps working exactly as it does today and is this story's regression surface,
not its own scope: target = opponent's `last_resolved_card` `[id, mode, tick]`; window from
`counter_window_seconds` (`0` = no limit); the reversal packet overwritten in lockstep with
`last_resolved_card`; `REVERSAL_NONE` is the entire no-target rule; refusal happens before the orb, silently,
the card stays staged; nothing is ever returned to the countered player (mana, orb, card stay spent);
Counterspell is never a target of itself (`6-5f/R8`); Boulder clear does not write `last_resolved_card`
(`6-5f/R7`); the cue is the existing `counterspell_resolved` signal, queued only on a real reversal.

## Acceptance Criteria

### Framework carry-over and interim-rule removal

1. Every `6-5f` behaviour named above (target selection, window, refusal-before-orb, `REVERSAL_NONE`,
   Counterspell-never-a-target, Boulder-clear-never-overwrites, the placeholder cue, the two teardown seats)
   is unchanged and still exercised by `6-5f`'s own tests, none of which this story edits except where named
   below.
2. The `6-5f/R37` interim rule (AC 13 of `6-5f`) is REMOVED. It is EMERGENT, not a code arm (`6-5g/R1`):
   removal deletes ONE textual artifact directly -- the test
   `test_a_6_5g_card_is_refused_through_the_same_no_target_path` -- and nothing in `src/`. `6-5f` AC 13's own
   text and `6-5f`'s Live Smoke point 6 are SUPERSEDED BY RECORD (this story and its close-out ruling,
   `6-5g/R24`), not by an edit to `6-5f`'s own file: a closed, pushed story file is not edited by a later
   story (`E5-R/R7`). A Counterspell targeting a resolution of any of the seven cards now reaches the SAME
   no-target gate every `6-5f` card already reaches, with no card-id list anywhere; admitting the seven cards
   through that gate is AC 31's own requirement, not a consequence of this deletion.
3. The reversal packet's shape (`reversal_kind`, `reversal_indices`, `reversal_a`, `reversal_b`,
   `reversal_flags`, `reversal_amount`) is EXTENDED with new `REVERSAL_*` kinds for the seven cards, never
   redefined for the six `6-5f` already ships; every `6-5f` kind's own reading of the five generic columns is
   unchanged.

### Class 1 -- timed buffs (Vampiric Aura, Bloodhound Step, Frostbite)

4. Countering a resolved Vampiric Aura ends its running rule immediately; hp it has already healed stays
   healed (nothing is clawed back for a timed buff, unlike an instant heal).
5. Countering a resolved Frostbite when its trigger is still ARMED (waiting for a confirmed hit) disarms it:
   the caster's next hero melee hit no longer applies a slow.
6. Countering a resolved Frostbite when its trigger has already been CONSUMED (the slow is running on the
   struck target) ends the running slow immediately; movement speed returns to normal that same tick.
7. Countering a resolved Bloodhound Step ends its armed trigger if a roll has not yet consumed it (the
   player's next roll is unboosted). If a roll IS already in progress when the counter resolves, the counter
   has NO effect on that roll -- proven equal to natural window expiry mid-roll, per the measured finding
   above (Dev Notes): both leave the already-latched `RULE_ROLL_BOOST` untouched and the roll finishes at its
   already-committed boosted distance and i-frames.
8. Countering a resolved timed buff whose rule has ALREADY ended naturally by the time Counterspell resolves
   (the window ran out, or Frostbite's trigger both armed-and-expired with no hit) counts as "no target" and
   is refused through the standing gate -- proven for at least one buff whose window has already elapsed.

### Class 2 -- cast cards, target at cast start (Honed Bolt, Fireball, Rocksling)

9. The reversal target for Honed Bolt, Fireball and Rocksling is named at CAST START -- the press that
   begins the cast, the existing `record_resolved_card` write already reached before `start_cast` runs (no
   new write-timing code; see Dev Notes) -- and the window (AC 6/AC 7 of `6-5f`) is measured from that same
   tick, not from the strike.
10. The packet for a Class 2 card is a LIVING RECORD: what a Counterspell against it does depends on how far
    the cast has progressed at the moment Counterspell resolves (still casting, struck/launched-and-landed,
    struck/launched-and-in-flight, or whiffed with nothing left), proven with at least one case per state for
    at least one Class 2 card.
11. Countering a Class 2 card while its cast is still running reaches the same outcome the existing
    cast-interrupt seat (`_resolve_cast_strikes`'s `_cast_is_interrupted` arm) reaches for the caster: the
    cast ends immediately, the caster is free to act that same tick, no damage lands and no projectile is
    ever created. This is proven as "the equivalent seat is reached from Counterspell's own resolution", not
    as a call to `_cast_is_interrupted` (that predicate has no external input and is never made to answer
    true by a counter).
12. The interrupted caster is NOT sent to `STUNNED`: `test_action_state.gd`'s STUNNED entry-point census
    (currently **4**, `res://src/state/match_state.gd x4` -- re-measured, not assumed, at the dev pass) does
    not move. A new test asserts this directly: "Counterspell interrupt does not put the caster into
    STUNNED."
13. The interrupted caster's card and mana stay lost (`6-5f/R9`'s "countered player gets nothing back",
    applied to the CASTER here since the caster is the one whose resolution is being countered) -- no
    refund of either on an interrupted cast.
14. Countering a landed Honed Bolt refunds hp equal to the amount ACTUALLY REMOVED by that strike (`6-5f/R12`,
    never the nominal `damage_amount` or the funnel's pre-application return), clamped as AC 21 below; any
    stun and root the strike placed on the target end immediately, whether or not the target has since been
    struck again.
15. Countering a landed Fireball refunds hp equal to the amount ACTUALLY REMOVED by that hit, clamped as
    AC 21.
16. Countering a Fireball or a Rocksling stone still IN FLIGHT vanishes it (the existing `consume_at` seat);
    no damage lands from it and nothing further happens on its account.
17. Countering a resolved Rocksling: every stone not yet launched is cancelled (the pending burst is cleared
    -- a new call site beside the schedule's own two exhaustion clears and the two teardown seats,
    `6-5f/R30`'s prediction realised); every stone already in
    flight vanishes (AC 16); every stone that already landed refunds hp equal to what it ACTUALLY removed,
    summed across stones, clamped once as AC 21; every Boulder THIS cast planted that is still covering a
    slot in the struck player's hand is removed (the covered card is immediately playable again, and the
    per-Boulder movement slow drops by the removed count) -- a Boulder from this cast already cleared,
    detonated or otherwise gone is left alone (`6-5f/R15`'s "reverse what is left"); mana already paid to
    clear a Boulder is NOT refunded by this reversal (Boulder-clearing is its own separate spend, untouched).
18. A Class 2 card that WHIFFED entirely (the bolt was dodged, the ball was deflected, every stone in a
    Rocksling burst missed with no Boulder ever planted, or the cast was itself interrupted by a stun before
    it struck) leaves nothing to reverse: Counterspell against it is "no target" and refused through the
    standing gate, exactly as a fully-expired instant effect is (`6-5f/R11`'s fourth clause, `6-5f` AC 12's
    own precedent) -- Counterspell keeps waiting for the opponent's next resolved card.

### Class 3 -- Corpse Bomb (instant, no cast)

19. Countering a resolved Corpse Bomb: every skull still IN FLIGHT vanishes (AC 16's same mechanism, applied
    to a minion-sourced shot); every skull that already landed refunds hp equal to what it ACTUALLY removed,
    summed, clamped once as AC 21.
20. Every minion Corpse Bomb converted into a skull rises again from its own corpse at its pre-death hp,
    through `6-5f`'s general restore rule (AC 23 of `6-5f`: `hp_at_death_at`, `restore_corpse_at`,
    `consume_corpse_at`) -- proven for at least one converted minion whose corpse is still present. A
    converted minion whose corpse has already naturally expired is NOT restored (the same rule's own
    exception, `6-5f/R29`).

### Cross-class

21. Clamps match `6-5f` exactly, at the same three seats generalised to this story's new refund paths: HP
    claw-back (none of this story's cases claw back HP; listed for completeness -- this story only refunds)
    is not exercised here; HP refund is clamped at the caster's current max hp (never overheals); mana
    claw-back (not exercised by any of the seven cards) is clamped at 0. Proven with at least one HP-refund
    case that would otherwise overheal (a Honed Bolt or Fireball refund landing on a hero already near max).
22. A minion killed by a countered Honed Bolt or Fireball (a hero-sourced strike that killed an opposing
    minion -- reachable: `_resolve_cast_strikes`'s bolt arm has an explicit non-hero branch,
    `if target_index != TargetingService.HERO_INDEX:` -> `_funnel_damage` -> `target.units.apply_damage_at(...)`
    -> `unit_dedupe.discard`, `6-5g/R11`) comes back from its own
    corpse at its pre-death hp through the SAME general restore rule AC 20 uses; a totem killed by a
    countered spell (no corpse, `6-5b`'s own corpse rule for totems) stays dead, while a SURVIVING totem that
    was merely damaged gets its hp back through the ordinary hp-refund path (AC 14/15/19), not through the
    restore rule.

### Regression, determinism, replay, format

23. Every `6-5f` instant-card reversal (Vanguard, Culling, Grave Ward, Raise Dead, Drain, Boom) and every
    ordinary (un-countered) resolution of all thirteen Deck-1-spell-family cards is unaffected by this
    story's additions.
24. Nothing in this story adds a second `_physics_process`, reads `Input.*` outside `src/controllers/`, or
    introduces a nondeterministic source inside `src/state/` (`test_architecture_invariants.gd` stays green);
    none of this story's seven reversal arms consumes RNG (the Boulder-removal arm re-covers nothing and
    draws no eligible slot, `6-5f`'s own `_restore_boulders` posture; a burst cancellation reads no random
    state).
25. `test_action_state.gd`'s STUNNED entry-point census does not move from its measured count (AC 12);
    `test_corpses.gd`'s death-seat six-caller pin does not move (Repo-verified facts, above) unless the dev
    pass's chosen mechanism for a restored minion opens a genuinely new caller, in which case the pin is
    updated and the cause argued in Dev Notes, the same posture `6-5f`'s own close-out used for its two new
    callers.
26. Every new cross-tick fact this story adds (whatever the reversal packet's widened columns need for the
    seven new kinds, and any per-kind state a living Class 2 record needs beyond the packet itself) is
    snapshotted and hashed, or is a pure function of already-hashed facts (argued in Dev Notes if so).
27. `RecordFile.FORMAT_VERSION` PREDICTED to move 18 -> 19 (the packet's shape widens for the new kinds); a
    v18 record is HARD-REFUSED with a reason, the per-bump fixture `6-5f`'s own review restored
    (`test_a_v17_record_is_refused_with_a_reason`'s shape, extended to the new version) -- measured, not
    assumed, and corrected if wrong.
28. A recorded match containing a Counterspell that reverses each of the seven new kinds at least once (a
    timed buff ended mid-window, a cast interrupted, a landed strike refunded, an in-flight shot vanished,
    and Corpse Bomb's restore) replays to the identical final hash and the identical record
    (`test_replay_identity.gd`'s standing discipline, `6-5f`'s own AC 30 extended to the new kinds).
29. No new `MatchState` direct-connect signal is added: `counterspell_resolved` (already `6-5f`'s own second
    instance of the pattern) is the cue for every reversal this story adds, real or refused-nothing -- a
    third such signal would open the seam-family question this story does not scope. `6-5f`'s close-out flagged
    `RAW_MATCH_STATE_CONNECTS` gaining `counterspell_resolved`:inline as the SECOND inline direct-connect and
    noted a third instance would open the seam-family question "to be resolved before 6-5g" -- this AC is
    that resolution: the count stays two, so the question is not forced by this story (`6-5g/R15`).
30. Visuals stay placeholder-only, `6-5f`'s own cue and standard: real art, VFX or audio for any of these
    seven reversals is owed to the Tier B presentation story scheduled after this one closes E6.
31. The gate's `_counter_target_is_live` admission is not automatic: `_reversal_has_anything_left` gains ONE
    new arm per new `REVERSAL_*` kind this story adds, each naming what survives for that card (a running
    rule; a cast still in its window; a living projectile index; an unfired burst; a still-covering Boulder
    slot; a restorable corpse) -- without an arm, that kind falls through to the predicate's existing
    `return false` and stays refused regardless of AC 2's interim-rule deletion (`6-5g/R13`).

## Deferred (NOT in scope) -- also amended into `deck-1-spec.md`

- **Counter-on-counter.** Counterspell as a valid target of a second Counterspell, with the countered
  player's state restored as if that first Counterspell had never resolved (a "redo from the packet" of
  whatever it reversed) -- its own story after the playtest/retune block. `6-5f/R8` ("Counterspell is never
  a valid target of itself") stays exactly as `6-5f` shipped it until that story, if adopted, supersedes it.
  This story makes NO change toward that mechanism; a reversal packet's own reversal is not designed here.
  `6-5g/R17`; also amended into `deck-1-spec.md`'s 29.9. amendment.

**Carry-over close-out note:** `6-5f/R45`'s review finding m4 (the seven-card parametric interim-refusal
loop, proven for only one of seven) is discharged by AC 2's deletion of the interim rule, not by
implementing the loop -- there is no loop left to prove once the rule it drove is gone (`6-5g/R19`).

**Deferred at close-out:**

- **AC 14's stun half.** Implemented, but structurally unobservable in a two-player match (review T9
  confirmed; mutation M8 GREEN, disclosed and accepted): the bolt's target is the only player who could
  counter it, and a bolt-stunned hero's own Counterspell is refused at both presses (`REASON_STUNNED`), so no
  reachable state has a bolt stun running when a counter resolves. The root half IS proven.
- **All visuals stay placeholder.** Real art, VFX or audio for any of the seven reversals this story adds is
  owed to a Tier B presentation story after 6-5g, covering all fourteen Deck 1 effects in one pass.
- **Corpse lifetime (20 s).** Bounds every corpse restore this story adds, including Corpse Bomb's -- a
  playtest knob, not a defect (`6-5g/R27`, observed live at Live Smoke point 9).
- **Counter-on-counter** stays deferred (`6-5g/R17`, above).

## Non-Goals

- Any redo mechanism or counter-on-counter (see Deferred, above).
- Any change to the six `6-5f` instant-card reversals, or to any card's cost, targeting or normal-mode
  behaviour beyond what countering it reverses.
- Any new orb rule, any new `MatchState` direct-connect signal, any change to melee, unblockables, the
  colour counter, stamina, Deck 2, hand size, deck size, or `max_mana`.
- Real art, VFX, clips or audio for any of these seven reversals -- placeholder only, owed to the Tier B
  presentation story after this one closes E6.

## Golden Prediction (predictions to MEASURE, not claims)

Baseline to measure and save outside the repo BEFORE any edit: golden
`941958c52605abbcd1edf972e002543601325e5a9f98dfce569628c12f75871f`, `RecordFile.FORMAT_VERSION` 18,
per-player snapshot keys 45, the reversal-packet shape, suite (state + integration counts) -- re-measure at
the dev pass; do not trust any figure in this file.

**PREDICTED to MOVE.** Causes to be separated and measured each in isolation (the `6-5a`..`6-5f` method:
erase the new content from `to_snapshot()` with every other change in place; the hash must return to the
baseline exactly):

1. **The reversal packet's widened shape** for the seven new `REVERSAL_*` kinds. If the existing five
   generic columns are sufficient for every one of the seven (an id-free, index/count/flag/amount shape,
   `6-5f`'s own "no card-id list anywhere" discipline extended), this may be a ZERO-KEY-COUNT-MOVE cause --
   measure the resting-empty case and the per-kind filled case separately, the same as `6-5f`'s own cause 2.
2. **Whatever new hashed field a Class 2 "living record" needs** beyond the packet's existing columns, if the
   dev pass's chosen mechanism needs one (e.g. distinguishing "still casting" from "struck" from "in flight"
   for the SAME `reversal_kind` across ticks) -- its own isolable cause, argued and measured separately from
   cause 1.
3. **Which pins move**: `EXPECTED_PLAYER_SNAPSHOT_KEYS` (45) in `test_draw_delay_and_reshuffle.gd` and
   `test_card_observation.gd`'s copy, IF cause 1 or 2 is a new key rather than an extension of the existing
   `reversal` key.
4. **The interim rule's removal** (AC 2): a BEHAVIOUR mover -- a resolution of one of the seven cards was
   previously always refused and now sometimes is not -- worth its own isolation pass even though the
   golden's own recorded sequence may or may not press it (confirm as cause or non-cause, `6-5f`'s own
   cause-3 method for its `not clears_cover` gate).
5. **`FORMAT_VERSION` PREDICTED 18 -> 19** (AC 27). Measured, not assumed.
6. **Non-causes to confirm (`BC/R3`):** no `.tres` value this story introduces (none is introduced; every
   number the seven cards use is already authored on `card_effect.gd`) is expected to move the hash.
7. **Intake:** none predicted -- as with `6-5f`, Counterspell's target is derived state, not a new intent
   field; no new controller-read channel.

**Measure, do not assume:** full suite before any edit and after, golden hash / key counts / FORMAT_VERSION
in both runs, files saved outside the repo. The number of re-baselines is NOT predicted in advance; report
the actual count and separate every cause exactly as done above.

## Live Smoke (operator, two pads, flip config `[3,3]`)

Flip `slot_controller_kinds = Array[int]([3, 3])` (two gamepads: two killable, human-driven slots). Several
of these points change live-observable state (hp, minion count, a running slow, a hero freed mid-cast) and
one (a countered Corpse Bomb restore) restores minions to the board, so **R-D6 is RE-INVOKED for this story**
(decision-log `R-D6` entries, `2-1/R2`, `6-1c/R4`, most recently `6-5f`'s own re-invocation). The binding
editor-collateral procedure (`6-1c/R4`), restated verbatim as `6-5b`..`6-5f` each did:

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins -- not earlier in
  the session.

1. **Counter a Vampiric Aura.** Let it heal at least once, then counter it before its window ends: the rule
   stops (no further healing on subsequent hits), and the hp already healed stays.
2. **Counter a Bloodhound Step before a roll.** Counter it while armed: the next roll is unboosted (normal
   distance and i-frames).
3. **Counter an armed Frostbite.** Counter it before it lands a hit: the next hero melee hit from that
   player applies no slow.
4. **Counter a running Frostbite slow.** Let Frostbite land and its slow start running, then counter it: the
   slowed hero's movement speed returns to normal immediately.
5. **Counter a casting Honed Bolt.** Counter it mid-cast: the caster is freed immediately (no stun), no bolt
   strikes, no damage lands.
6. **Counter a landed Honed Bolt.** Counter it after it struck: hp is refunded, and any running stun/root on
   the target ends immediately.
7. **Counter an in-flight Fireball.** Counter it while the ball is still travelling: it vanishes before it
   would have landed.
8. **Counter a Rocksling mid-burst.** Counter it with at least one stone already landed and at least one
   still owed: the landed stone's damage is refunded, the unfired stone(s) never launch, and any Boulder that
   cast planted is removed from the covered hand.
9. **Counter a Corpse Bomb with skulls in flight.** Counter it before every skull lands: the in-flight
   skull(s) vanish, any already-landed skull's damage is refunded, and the converted minion(s) rise again at
   their pre-death hp.
10. **Refusal on a whiffed cast.** With a dodged Honed Bolt (or a deflected Fireball, or a fully-missed
    Rocksling burst with no Boulder planted) as the opponent's last resolved card, activation is refused as
    no-target: the card stays staged, its countdown continues.
11. **Refusal on an expired timed buff.** With a Vampiric Aura (or Bloodhound Step, or an armed-then-expired
    Frostbite trigger) whose window has already run out as the opponent's last resolved card, activation is
    refused as no-target.
12. **R-D6 re-invocation.** A round ends normally after each of the reversals above (whether the countered
    player or someone else takes the killing blow): no leftover reversal-record, burst or in-flight-projectile
    state carries into the next round.
13. **Regression.** Every `6-5f` behaviour (the six instant reversals, the placeholder cue, every ordinary
    un-countered resolution of all thirteen Deck-1-spell-family cards) is unaffected; no crash, no assert.

**Target: report actual PASS/FAIL counts on two pads, flip config `[3, 3]`, R-D6 result -- not run by this
create pass.**

### Live Smoke Results (operator, 2026-09-30, two gamepads, flip `[3, 3]`)

**13/13 PASS.** R-D6 re-invoked and passed (a round ended by a kill; no leftover reversal-record, burst or
in-flight-projectile state carried into the next round). fps stable throughout. The placeholder cue fired on
both heroes on every real counter and never on a refusal.

1. Vampiric Aura -- countered mid-window: the rule stopped, hp already healed stayed healed. PASS.
2. Bloodhound Step -- countered while armed: the next roll came out plain (unboosted). PASS.
3. Frostbite armed -- countered before it landed a hit: disarmed, no slow applied. PASS.
4. Frostbite running slow -- countered after landing: the slow ended, movement speed returned to normal
   immediately. PASS.
5. Honed Bolt mid-cast -- countered while casting: caster freed immediately, not stunned, card and mana lost.
   PASS.
6. Honed Bolt landed -- countered after it struck: hp refunded, the running stun/root ended immediately. PASS.
7. Fireball in flight -- countered while travelling: vanished before it would have landed. PASS.
8. Rocksling mid-burst -- countered with one stone landed and stones still owed: the in-flight stone vanished,
   the third stone never fired, the planted Boulder was lifted (card back, its slow contribution gone), the
   landed stone's hit was refunded. PASS.
9. Corpse Bomb, countered AFTER the 20 s corpse lifetime had already run out on the converted minion: the
   skull's damage was refunded, the converted minion was NOT restored -- exactly `6-5g/R12`'s rule (corpse
   gone, no restore). The live corpse-restore path itself was proven on a separate point: a minion killed by a
   bolt rose again from its own corpse at its pre-death hp. Both halves of AC 20/22 observed live. PASS.
10. Whiffed cast refusal -- activation against a dodged/deflected/fully-missed cast was refused silently: card
    stayed staged, orb kept, next card still counterable. PASS.
11. Expired timed-buff refusal -- activation against an already-expired buff was refused silently. PASS.
12. R-D6 re-invocation -- see above. PASS.
13. Regression -- every `6-5f` behaviour (the six instant reversals, the placeholder cue, ordinary
    un-countered resolution of all thirteen Deck-1-spell-family cards) unaffected; no crash, no assert. PASS.

**Corpse lifetime (20 s) is a playtest knob, not a defect** (`6-5g/R27`): it bounds every corpse restore this
story adds, including Corpse Bomb's, exactly as it already bounded `6-5f`'s restores.

## Tasks / Subtasks

- [x] **Task 1: Baseline (before any edit).** Save outside the repo: suite counts, golden, FORMAT_VERSION,
  per-player key count (45), the reversal-packet snapshot shape, `git rev-parse HEAD`. (AC 26-28)
- [x] **Task 2: Delete the interim rule.** Remove `6-5f/R37`'s refusal arm, its test
  (`test_a_6_5g_card_is_refused_through_the_same_no_target_path`) and its smoke point. Confirm the gate
  (`_counter_target_is_live`) needs no other change to admit the seven cards once they write a real
  `reversal_kind`. (AC 2)
- [x] **Task 3: Reversal-record shape for the seven cards (Open Question 1 for this story -- the dev pass's
  own mechanism decision, on the same "behaviour fixed, mechanism open" discipline `6-5f`'s own Open
  Question 1 used).** FIRST OUTPUT, before any code: name the predicted per-player snapshot key-set N and
  the new key name(s), if any (`6-5g/R14`; see Golden Prediction cause 3). Then extend `REVERSAL_*` with the
  seven new kinds; decide, and argue in Dev Notes, whether the existing five generic columns are sufficient
  for all seven or whether a Class 2 "living record" needs one more hashed field to distinguish
  cast-in-progress / struck / in-flight / whiffed for the same kind across ticks. Must be ADDITIVE to
  `hand_covered`, `burst`, `corpse_bomb` and the packet's own six existing kinds -- never a redefinition of
  any of them.
  - [x] **Sub-bullet: `_reversal_has_anything_left` gets ONE new arm per new kind** (AC 31, `6-5g/R13`), each
    naming what survives for that card: a running rule (Class 1); a cast still in its window (Class 2,
    pre-strike); a living projectile index (Class 2/3, in-flight); an unfired burst (Rocksling); a
    still-covering Boulder slot (Rocksling); a restorable corpse (Honed Bolt/Fireball/Corpse Bomb minion
    kills). Without these arms the per-kind `match` falls through to `return false` and all seven cards stay
    refused even after Task 2 deletes the interim rule.
- [x] **Task 4: Class 1 (timed buffs).** Vampiric Aura (`cancel_rule(RULE_VAMPIRIC_AURA)`), Bloodhound Step
  (`cancel_rule(RULE_BLOODHOUND_ARMED)` if still armed; no-op if a roll already consumed it, per the measured
  finding), Frostbite (`cancel_rule` on whichever of `RULE_FROSTBITE_ARMED` (on the CASTER) or
  `RULE_FROSTBITE_SLOW` (on the STRUCK target) is running -- a cross-player read, `REVERSAL_BOOM`'s
  `boom_victim` derivation (`victim == p1`) is the precedent for reaching the other player's rule slot,
  `6-5g/R4`). Each writes its own reversal record at the SAME seat `_apply_card_effect`'s existing `start_rule` calls
  already sit at (`6-5f`'s own "wiring the undo packet at the same write site as `record_resolved_card`"
  leaning, applied here to `start_rule` instead). (AC 4-8)
- [x] **Task 5: Class 2 (cast cards).** Honed Bolt and Fireball's cast-interrupt arm (reach `clear_cast()`'s
  outcome from Counterspell's own resolution, never `_cast_is_interrupted`); Honed Bolt's and Fireball's
  landed-hp-refund arm (measure the actually-removed delta, `6-5f`'s AC 14 discipline); Honed Bolt's
  stun/root end-now clause; Fireball's in-flight vanish (`consume_at`); Rocksling's full set (cast-interrupt,
  `clear_burst()` for unfired stones, in-flight vanish per stone, landed-damage refund summed per stone,
  same-cast Boulder removal via the existing uncover seat, no mana refund for Boulders already cleared).
  (AC 9-18)
- [x] **Task 6: Class 3 (Corpse Bomb).** In-flight skull vanish (`consume_at`, minion-sourced); landed-skull
  damage refund summed; converted-minion restore through `6-5f`'s existing general restore rule (no new
  `kill_at`/death-seat caller). (AC 19-20)
- [x] **Task 7: Cross-class clamps and restore.** HP-refund ceiling at max hp reused at every new refund seat;
  a minion-vs-totem restore split matching `6-5f`'s own rule (AC 22).
- [x] **Task 8: Teardown.** Whatever new hashed state Task 3-6 introduce is cleared at the SAME two existing
  per-round teardown seats (`_end_round`, `_reset_player`) `6-5f`'s reversal packet already clears at, plus
  per-resolution the instant a Counterspell reverses it -- no new seat.
- [x] **Task 9: Tests.** Extend `test_counterspell.gd` with the seven cards' reversal cases (AC 4-20), the
  clamp case (AC 21), the minion/totem restore split (AC 22), the not-STUNNED test (AC 12), the deleted
  interim-rule test's removal, and replay identity (AC 28) on the real record path. Update every file in the
  table below with actual outcomes. Mutation proofs restore from a copy outside the repo, SHA256-verified
  first.
- [x] **Task 10: Golden.** Isolate causes 1-5 (and any the dev pass finds) by erasing new keys/fields with
  every other change in place; confirm non-causes; record the actual re-baseline count; `FORMAT_VERSION` 19
  predicted, confirm or correct.
- [x] **Task 11: Close.** Second full suite run, invariants green, `git diff --stat`, Dev Agent Record. The
  decision-log close-out (a new session, `6-5g/R1..`) and the board promotion to `done` are the operator's
  gate, after live smoke.

## Tests expected to break or need updating

Found by reading the named files at authoring; the dev pass confirms and updates this table with actual
outcomes. (`6-5f` listed 14; this table is re-derived from the current repo, not copied.) `6-5g/R20` adds the
MUST-MOVE / MUST-NOT-MOVE column (eight of the rows below are regression-only pins that must NOT move; the
gate found the table's own title read as if all fifteen rows were expected to break) and the two rows this
story's readiness gate found missing.

| Test | MUST-MOVE / MUST-NOT-MOVE | Why |
|---|---|---|
| `test_counterspell.gd` | MUST-MOVE | the seven new reversal cases, the deleted interim-rule test, the not-STUNNED test, the whiff-refusal and expired-buff-refusal cases |
| `test_spell_framework.gd` | MUST-MOVE | Bloodhound/Frostbite/Vampiric Aura's own new reversal paths; confirm no change to `start_rule`'s own non-Counterspell behaviour |
| `test_hero_cast.gd` | MUST-MOVE | Honed Bolt's cast-interrupt and landed-refund reversal; the not-STUNNED assertion may land here or in `test_counterspell.gd` (dev pass's choice, stated in Dev Notes) |
| `test_fireball.gd` | MUST-MOVE | Fireball's cast-interrupt, in-flight vanish and landed-refund reversal |
| `test_rocksling_and_boulder.gd` | MUST-MOVE | Rocksling's full reversal set: burst cancellation, in-flight vanish, landed refund, same-cast Boulder removal; Boom's own reversal (`6-5f`'s) stays regression-only here |
| `test_action_state.gd` | MUST-NOT-MOVE | the STUNNED entry-point census -- regression-only, stays 4 |
| `test_corpses.gd` | MUST-NOT-MOVE | the death-seat six-caller pin -- regression-only, unless Corpse Bomb's restore mechanism opens a genuinely new caller (argued in Dev Notes if so) |
| `test_draw_delay_and_reshuffle.gd` (`EXPECTED_PLAYER_SNAPSHOT_KEYS`) and `test_card_observation.gd`'s copy | CONDITIONAL | predicted to move 45 -> N only if the widened packet (Golden Prediction cause 1/2) is a new key rather than an extension of the existing `reversal` key; Task 3's first output names N before any code |
| `test_determinism.gd` | MUST-MOVE | golden re-baseline (count not predicted in advance); its own `:1824` resting-packet literal assertion (`assert_eq(p2["reversal"], [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0], ...)`) and `test_counterspell.gd`'s two copies of the same literal (`:225`, `:563`) move if the packet gains a sixth column |
| `test_record_file.gd` | MUST-MOVE | `FORMAT_VERSION` 18 -> 19 predicted; the per-bump v18-refusal fixture |
| `test_replay_identity.gd` | MUST-UPDATE (not regression-only) | new content round-trip (each of the seven new reversal cases) through the real record path (AC 28); its own HASHED-MEMBER CENSUS naming the six `player_state.reversal_*` members by name must gain any sixth-plus column this story's packet widening adds, or a new `PlayerState` field a Class 2 living record needs -- missed by this story's authoring pass, closed by `6-5g/R20` |
| `test_card_effect_resolution.gd` | CONDITIONAL | its counts-only `for path: String in PlayerState.SNAPSHOT_ID_PATHS:` scan moves the moment a new column carries a `String`/`StringName` (e.g. a naive "which effect launched this stone" column); `6-5f`'s own break table carried this file, this story's authoring pass omitted it -- closed by `6-5g/R20` |
| `test_spell_targeting.gd` | MUST-NOT-MOVE | regression-only: confirm the Fireball/Honed Bolt/Rocksling target capture used by their own reversal is undisturbed by the shared spell-targeting machinery |
| `test_own_minion_spells.gd` | MUST-NOT-MOVE | regression-only: Culling/Drain/Raise Dead/Grave Ward's own `6-5f` reversal paths are untouched by this story |
| `test_pitch_staging.gd`, `test_pitch_changed.gd` | MUST-NOT-MOVE | regression-only: the interim refusal's removal does not disturb staging/fizzle behaviour for any of the seven cards' own normal activation |
| `test_intent_recorder.gd` | MUST-NOT-MOVE (predicted) | only if a new intake channel is added (predicted: none) |
| `test_architecture_invariants.gd` | MUST-NOT-MOVE | regression-only: confirm F1/D3/A2 still hold |

## Dev Notes

- **Open Question 1 (the reversal record's shape for the seven new kinds) is this story's own central
  mechanism decision, on `6-5f`'s own Open Question 1 discipline: behaviour is fully fixed by AC 4-22, HOW
  the packet or a small additional field records "which phase" a Class 2 card is in when Counterspell
  resolves is not.** The deliberate leaning to try first, on the same footing `6-5f`'s own leaning argued:
  reuse the packet's existing five generic columns (index/count lists, flags, one amount) before adding any
  new hashed field, since every one of the seven cards' reversal needs -- which rule to cancel, which board
  indices to touch, an hp sum, a count of unfired stones -- is already a shape one of those columns already
  expresses for a `6-5f` kind. Add a new column or key only if a genuine case (a cast still in progress vs.
  already struck vs. in flight, all needing to be told apart for the SAME `reversal_kind` at different
  Counterspell-resolution ticks) proves the five insufficient.
- **Why Bloodhound Step's mid-roll case is "no new behaviour" rather than a designed outcome:** the measured
  finding above (`RULE_ROLL_BOOST` is a fixed-duration, independently-cancellable rule whose value was
  FROZEN from `RULE_BLOODHOUND_ARMED` at roll entry, and `RULE_BLOODHOUND_ARMED` is already cancelled by
  that same entry) means a roll in progress is, by construction, no longer reading the rule Counterspell's
  target resolution armed. Ending "the running rule" therefore ends nothing observable for a roll already
  under way -- exactly what a natural window expiry mid-roll already does today, with no code path in
  `_resolve_movement` or the roll-entry arm needing to change. State the measurement's confirmation (or
  correction, if a re-read of the current code disagrees) explicitly in the dev pass's own notes.
- **Why the cast-interrupt reuse must not call `_cast_is_interrupted`:** that predicate answers "is this
  caster dead or stunned", and a Counterspell interrupting a cast changes neither fact about the caster --
  calling it here would either always answer false (doing nothing) or require giving it a fourth condition
  that lets an external caller force it true, which would then also make a Counterspell-adjacent STUNNED
  entry point exist where the census (AC 12) must prove none does. The correct shape reaches the SAME
  outcome (`clear_cast()`, freeing the caster) through Counterspell's own arm calling it (or an equivalent)
  directly -- a second call site to an existing effect, not a new condition on an existing predicate.
- **Why Corpse Bomb's restore must not add a `kill_at` caller:** the death-seat caller-count pin
  (`test_corpses.gd`) treats a new caller as a new corpse-creation MECHANISM even when it reuses `kill_at`
  with a familiar argument shape (that is exactly what `6-5f`'s own two new callers were, and why the pin
  moved 4 -> 6 for them). Corpse Bomb's reversal RESTORES a minion rather than killing one, so it belongs on
  the RESTORE side of the seat (`restore_corpse_at`/`consume_corpse_at`/`hp_at_death_at`) `6-5f`'s Culling and
  Drain restoration already uses, which is why this story predicts NO caller-count move -- confirm this by
  reading `_restore_killed_minions` (or its equivalent) before writing Corpse Bomb's arm, and reuse it rather
  than writing a parallel restore.
- **Order at activation** stays the `6-2`/`6-3a`/`6-5d`/`6-5e`/`6-5f` precedent: gates -> board gate (the
  no-target refusal) -> orb spend -> discard -> `pitch.clear` -> apply (the reversal) -> resolved-card record
  (which now names Counterspell itself) -> replacement owed at activation. Nothing in this story changes that
  order; every new arm is a new case inside the existing apply step.
- **Read first** (UPDATE files): `match_state.gd` (`_apply_card_effect`'s buff arms, `_apply_counterspell`,
  `_resolve_cast_strikes`, `_cast_is_interrupted`, `_apply_fireball`, `_apply_rocksling`, `_launch_stone`,
  `_advance_bursts`, `_apply_bolt_landing`, `_consume_frostbite`, `_resolve_movement`'s roll-boost read,
  `_apply_corpse_bomb`, `_end_round`, `_reset_player`, the snapshot), `player_state.gd` (`reversal_kind` and
  every sibling column, `record_reversal`, `clear_reversal`, `start_rule`/`cancel_rule`/`is_rule_active`, the
  `burst_*` fields and `clear_burst`, `root_window`/`arm_root`), `projectile_board.gd` (`consume_at`,
  `is_alive_at`, `living_indices`, the per-index accessors), `unit_board.gd` (`hp_at_death_at`,
  `restore_corpse_at`, `consume_corpse_at`, the death seat's caller count), `hand.gd` (`uncover_at`,
  `covered_indices`), `card_effect_resolver.gd` (confirm no new outcome row is needed -- the seven cards
  already resolve through existing `OUTCOME_*` arms; only `_apply_counterspell`'s own `match` widens),
  `src/systems/record_file.gd`.
- **Suite:** `bash test/run_all.sh` with `GODOT=/c/Godot/godot.exe` via the Bash tool (WSL is broken).

### Project Structure Notes

- No new file is predicted; every change lands in the six `.gd` files `6-5f` already touched plus
  `projectile_board.gd` (a new reader, `consume_at`/`is_alive_at`/`living_indices`, no new field). A new
  public API or `src/` folder for any part of this story's mechanism is a design decision: stop and ask, per
  the project's Agent Autonomy rule, if the natural shape reaches beyond these files.

### Project Context Rules (extracted from `docs/project-context.md`)

- State / visual separation; integer-tick timing (A1: every new duration converted once at application);
  every number a `.tres` field -- this story introduces no new `.tres` field (every number the seven cards
  use is already authored on `card_effect.gd` by `6-5a`-`6-5e`).
- Golden isolation (`BC/R3`): `data/balance/*.tres` is isolated from the golden; a NEW seat or a pressed
  action made refusable is not covered by that isolation and must be measured (Golden Prediction cause 4).
- Mutation proofs restore from a copy taken outside the repo (SHA256 first), never `git checkout --`; full
  suite at open and close, mutation proofs run only the affected file.
- Edit tool only (line-index splice as fallback; `python` byte-replace allowed after the first Edit miss,
  never PowerShell `-join`).
- Docs and code never share a commit; ASCII messages via `git commit -F`; never push before the operator
  confirms the log.
- Single rolling backlog, no sprint timeboxes; per-story holds live in `story_notes`, never as an extra board
  status (`STATUS DEFINITIONS` stays locked to `backlog -> ready-for-dev -> done`).

### References

- `docs/planning-artifacts/deck-1-spec.md` (this pass's own amendment; the 2026-09-29 "delivery split"
  amendment this pass supersedes for the seven cards' own status).
- `docs/implementation-artifacts/6-5f-counterspell.md` (the framework, the packet, the gate, the teardown,
  the golden-isolation method -- everything this story reuses).
- `docs/implementation-artifacts/6-5e-rocksling-boom-and-corpse-bomb.md` (Boulder cover mechanism, burst
  schedule, Corpse Bomb conversion record), `6-5d-fireball-and-spell-targeting.md` (hero-projectile
  machinery, cast-interrupt precedent), `6-5c-hero-cast-honed-bolt.md` (the cast lock itself, `6-5c/R3`'s
  "lost, not refunded"), `6-5a-spell-framework-and-buffs.md` (`last_resolved_card`, the timed-rule seat).
- `docs/game-architecture.md` (D3, A1, A2, F1, D5); `docs/project-context.md`.
- GDD decision-log `R-D6`, `6-1c/R4`, `SC/R6`, `BC/R3`, `6-5f/R1`-`R45` (the whole framework and the cut this
  story completes).

## Open Questions

1. **The reversal record's shape for the seven new kinds (Task 3/Dev Notes above).** Fully behaviour-fixed
   (AC 4-22), mechanism-open: whether the packet's five existing generic columns suffice for all seven cards,
   or whether a Class 2 living record needs one additional hashed field to distinguish cast-phase across
   ticks. The dev pass owns this, argues its choice, and records it, the same discipline `6-5e`'s Boulder
   cover mechanism and `6-5f`'s own reversal-packet shape each followed. Every other question this story's
   scope talk raised (the interim rule's removal, the cast-interrupt seat, the STUNNED census, the
   Bloodhound latching question, the Corpse Bomb caller-count question) is resolved above, in the Acceptance
   Criteria and Dev Notes, and is not reopened here.

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context)

### Debug Log References

- `C:\dev\_65g-dev.md` -- the full dev record: baseline, Task 3's first output, the mechanism argument, the
  golden cause table, the mutation table, the break-table outcomes and every deviation. Written as the pass
  ran.
- `C:\dev\_65g-suite-before.txt` -- before-baseline (opened 2026-09-29T23:56:35+02:00).
- `C:\dev\_65g-suite-after.txt` -- after (closed 2026-09-30T00:41:37+02:00). TWO full runs, the default; no
  extra run was needed.
- Restore copies kept OUTSIDE the repo for every mutated file: `_65g-match_state.gd.bak`,
  `_65g-player_state.gd.bak`, `_65g-unit_board.gd.bak`; SHA256s in `_65g-mutation-checksums.txt`, verified
  again after the last restore (all three back to their pre-mutation hashes).

### Completion Notes List

**Open Question 1 RESOLVED -- the reversal record's shape for the seven new kinds: A TAGGED PART LIST IN THE
FIVE EXISTING COLUMNS. NO new column, NO new `PlayerState` field, NO new snapshot key.** The story's own
"deliberate leaning" (reuse the five generic columns before adding a hashed field), tried first and found
sufficient. The columns are read ELEMENT-WISE as a list of PARTS rather than column-wise: `indices[i]` is the
part's address (a projectile index, a unit board index, a hand slot, or `-1`), `a[i]` is the PART TAG
(`PART_PROJECTILE`/`PART_DAMAGE`/`PART_CONVERTED`/`PART_BOULDER`/`PART_BURST`/`PART_STUN`), `b[i]` is the slot
the address belongs to, `flags` is left EMPTY for every new kind, and `amount` is the hp actually removed,
summed -- `REVERSAL_BOOM`'s own convention extended. ONE scalar `amount` suffices because every damaging kind
here damages exactly ONE address (the captured target: the bolt resolves against it, the ball flies at it,
every stone copies it onto the burst, every skull shares it), so hero-versus-unit is a READ of the single
`PART_DAMAGE` element rather than a second scalar.

**The Class 2 "which phase" question needed NO hashed field -- Golden Prediction cause 2 measured as a
non-existent cause.** Still casting = `is_casting()` (a cast cannot start without the packet being written at
that same press, and the step-3 cast lock makes a second resolution mid-cast unreachable); in flight = a
`PART_PROJECTILE` whose index is still `projectiles.is_alive_at`; landed = `amount != 0.0` or a `PART_DAMAGE`
unit address with a corpse; unfired = a `PART_BURST` plus `has_pending_burst()`; whiffed = none of those, so
the standing gate refuses (AC 18). A stored phase would have been a second copy of facts already hashed.

**Copy discrimination (`6-5g/R10`) is the RECORDED PROJECTILE INDEX**, which `ProjectileBoard` never reuses
(`4-3a/R9`: both add seats append unconditionally). Every living-record update is additionally gated on the
packet still naming the writer's own kind, so an orphaned shot from an earlier resolution charges nothing to
the packet that replaced it (own test, mutation-proven). `PART_BURST` is noted at the STRIKE rather than at
the press for the same reason, which is what keeps a counter against a SECOND Rocksling still casting from
cancelling the FIRST cast's pending stones.

**GOLDEN: NOT MOVED. ZERO re-baselines -- `941958c5...` before and after, and it is a MEASURED non-cause
rather than an absence of news.** All five predicted movers are non-causes, and the measurement is a probe
rather than an argument: an `Invariant.check(kind <= REVERSAL_BOOM)` was temporarily added to
`PlayerState.record_reversal` and the suites re-run -- it fired **74 times in `test_counterspell.gd`** (so the
probe is live and the new kinds really are written) and **ZERO times in `test_determinism.gd`**, i.e. the
golden's recorded sequence never writes a 6-5g kind. The reason is the fixture's own: `_golden_effects()`
authors EVERY id as `summon_<id>`, so none of the seven cards exists in it, and the fixture never stages
Counterspell (`test_determinism.gd`'s own 6-5f cause-5 note already recorded that). Probe removed; the file's
SHA256 verified back. Cause by cause: (1) the widened packet shape -- non-cause, no new kind is ever written
there; (2) a living-record field -- non-cause, none exists; (3) the two key-set pins -- UNMOVED at **45**, no
new key name, so the CONDITIONAL break-table row did not move; (4) the interim rule's removal -- non-cause,
the golden never stages Counterspell, so no pressed action became refusable (`SC/R6`'s boundary untouched);
(5) `FORMAT_VERSION` -- a record-file concern, never a hash cause. Non-causes 6 (no new `.tres` value; none
is introduced) and 7 (no intake channel) confirmed as predicted.

**`FORMAT_VERSION` 18 -> 19 with a v18 record HARD-REFUSED (AC 27), and the prediction was right for a
CORRECTED reason.** The recorded SHAPE does not move at all this story (no new `CardEffect` export, no
`BalanceConfig` field, no channel), so the bump rests entirely on the BEHAVIOUR change: a v18 record can
contain a Counterspell activation that was refused as no-target and did nothing, and the same intent stream
replayed here ACTIVATES. `test_a_v18_record_is_refused_with_a_reason` ships in the SAME pass as the bump
(`6-5f`'s review finding M1 discharged by not repeating it).

**AC 12 / AC 25: both censuses held, re-measured rather than assumed.** `test_action_state.gd`'s STUNNED
entry-point census is still **4** and `test_corpses.gd`'s death-seat caller pin is still **6** -- no
`set_action_state(STUNNED)` and no `kill_at` call appears anywhere on this story's paths; every restore goes
through `hp_at_death_at` / `restore_corpse_at` / `consume_corpse_at` via ONE shared helper
(`_restore_killed_minion_at`, extracted from `_restore_killed_minions` so the Corpse Bomb, bolt and Fireball
restores address a single index on either player's board without a parallel implementation).

**Bloodhound's measured finding CONFIRMED at this pass (`6-5g/R5`), and proven as an EQUALITY rather than
asserted:** the mid-roll test runs two identical fixtures and ends one window by Counterspell and the other by
natural expiry, then compares `RULE_ROLL_BOOST`'s liveness, the roll's velocity and its remaining i-frames.
All three agree. The reversal arm deliberately never names `RULE_ROLL_BOOST`.

**Mutations: 8 applied, 6 KILLED, 2 GREEN (both disclosed with their reason), 1 further attempt mis-aimed and
reported rather than counted.** Full table in `C:\dev\_65g-dev.md`. The two GREENs are honest findings, not
gaps: (a) `restore_hp_at`'s own liveness guard is unreachable defence-in-depth, because the calling arm
already branches on `is_alive_at` -- kept on `_restore_boulders`' own "defence in depth, not a reachable
case" precedent; (b) `PART_STUN`'s `start_stun(0, false)` is STRUCTURALLY unobservable in a two-player match:
the bolt's target is the only player who could counter it, and a bolt-STUNNED hero's Counterspell is refused
at both presses (`REASON_STUNNED`), so no reachable state has a bolt stun running when a counter resolves.
AC 14's ROOT half IS proven (the root outlives the stun, 25 ticks against 14); the stun half is implemented
and reported unprovable here rather than claimed. **This is the one AC clause this pass could not prove and
it is a deviation the operator should read.**

**AC 14's stun exit uses the stun's ONE exit seat.** The counter stops the stun WINDOW on its own tick and the
`STUNNED` action state leaves at step 3 of the next tick -- the same arm every naturally expired stun exits
through -- rather than a second `set_action_state` write here that would duplicate that arm's discriminator
and get-up reasoning (and would have put a state write next to the census AC 12 protects).

**Break-table outcomes (the table itself was NOT edited -- see the deviation below).** MUST-MOVE and moved:
`test_counterspell.gd` (+22 tests: the seven cards, the four cast phases, the clamp, the minion/totem split,
the not-STUNNED assertion, the deleted interim-rule test), `test_record_file.gd` (FORMAT 19 + the v18
fixture + a second stale version pin at `:1362`), `test_replay_identity.gd` (a THIRD full-content recorded
run for AC 28 + three FORMAT pins). MUST-MOVE and did NOT move, measured: `test_spell_framework.gd`,
`test_hero_cast.gd`, `test_fireball.gd`, `test_rocksling_and_boulder.gd` -- all four green UNEDITED, because
every new write is additive and no card's ordinary behaviour changed (the not-STUNNED assertion landed in
`test_counterspell.gd`, the dev pass's stated choice); `test_determinism.gd` -- no re-baseline, so the row's
predicted move did not happen. MUST-NOT-MOVE and did not move: `test_action_state.gd`, `test_corpses.gd`,
`test_spell_targeting.gd`, `test_own_minion_spells.gd`, `test_pitch_staging.gd`, `test_pitch_changed.gd`,
`test_intent_recorder.gd`, `test_architecture_invariants.gd`. CONDITIONAL and did NOT move:
`test_draw_delay_and_reshuffle.gd` / `test_card_observation.gd` (key set stays 45),
`test_card_effect_resolution.gd` (no new `String`/`StringName` column). `test_replay_identity.gd`'s
HASHED-MEMBER CENSUS also did NOT move: the packet gained no seventh column and `PlayerState` gained no
field, which is exactly the condition `6-5g/R20` attached to it.

**AC 2's three textual artifacts are all removed:** the test is deleted (a stated marker stands where it was),
`6-5f` AC 13's text is struck with the retirement recorded in place (the AC NUMBER is kept so a shipped
story's numbering stays stable), and `6-5f`'s Live Smoke point 6 is marked RETIRED -- do not re-run. `6-5f`'s
smoke RESULT line for point 6 is kept as a historical reading with a note, because it records what the
operator actually observed on 2026-09-29.

**Suite.** State **1218/0/11503 -> 1242/0/11678** (+24 tests, +175 assertions); integration **72/72 PASS**
both ways. TWO full runs, the default; every other run was a targeted single-file filter.

**Deviations, reported not silent.**
1. **AC 14's stun half is not provable in a two-player match** (see the mutation note above). Implemented,
   mutation-GREEN, disclosed.
2. **The break table was not edited.** Task 9 says to update it with actual outcomes, but the skill's
   `<critical>` limits story-file edits to the frontmatter `baseline_commit`, the Tasks checkboxes, the Dev
   Agent Record, the File List, the Change Log and the Status. The outcomes are recorded above and in
   `C:\dev\_65g-dev.md` instead; the table's own text is untouched.
3. **The board was never written to `in-progress`.** `sprint-status.yaml`'s STATUS DEFINITIONS are locked to
   `backlog -> ready-for-dev -> done` (project-context, and the skill's own `on_complete` restores
   `ready-for-dev`), so the skill's step-4 write would have invented a fourth status. The board entry stayed
   `ready-for-dev  # Tier A` throughout and carries a `story_notes` line instead.
4. **Golden Prediction causes 1-4 are corrected from "predicted to move" to MEASURED NON-CAUSES** and the
   re-baseline count is ZERO -- the first 6-5 sub-story whose golden did not move.
5. **`UnitBoard` gains one mutator, `restore_hp_at`** (AC 22's "a surviving totem gets its hp back"), and
   `_place_boulder` now RETURNS the slot it planted on. Both are implementation choices inside files `6-5f`
   already touched; neither is a new file, a new folder or a new cross-layer seam. `_apply_corpse_bomb` takes
   the caster's slot (threaded, `_apply_drain`'s precedent).
6. **Not done here, by design:** the live smoke (operator, two pads, flip config `[3,3]`, R-D6 re-invoked),
   the decision-log close-out and the board promotion. Nothing was committed, staged or pushed;
   `project.godot` is untouched and no new `class_name` ships, so no editor scan was run and the new-file
   `.uid` question does not arise (no new file).

### Review fix (2026-09-30, Claude Sonnet 5, commit nothing)

Closes `C:\dev\_65g-review.md`'s 1 blocker / 1 major / 5 minor. Full record: `C:\dev\_65g-dev.md` (appended).

- **B1 + M1, one mechanism (`6-5g/R21`).** `flags` (`Array[bool]`) is now genuinely used: `reversal_note_part`
  takes a `flag` parameter and appends it alongside every part, index-aligned; `_note_reversal_damage` sets
  the `PART_DAMAGE` element's flag `true` only when THIS resolution's own hit is what left the struck unit
  dead (measured right at the hit, before any other cause could kill it). `_reverse_recorded_parts`'
  `PART_DAMAGE` arm restores a dead unit only when `reversal_flags[i]` is true AND its corpse survives --
  never on "dead" alone. `_reversal_has_anything_left` no longer admits the four part-list kinds
  (`REVERSAL_HONED_BOLT`/`_FIREBALL`/`_ROCKSLING`/`_CORPSE_BOMB`) on the blanket `reversal_amount != 0.0`
  clause; their own arm decides per part, splitting the old combined `PART_DAMAGE, PART_CONVERTED` case into
  its own flag-gated `PART_DAMAGE` read (hero/alive-unit on the amount, dead-unit on the flag) and an
  unconditional `PART_CONVERTED` read (a Corpse Bomb conversion is always this resolution's own kill).
  `record_reversal`'s invariant already permitted both an empty and an index-aligned `flags` column, so no
  change was needed there. Three new tests: a minion that survived a stone and was later killed by an
  unrelated cause is not restored and its corpse is untouched (MUTATION-PROVEN: removing the flag check in
  the `PART_DAMAGE` else-branch let it go RED, restored from an outside-the-repo copy with SHA256 verified,
  green again); a bolt kill whose corpse has since expired is refused before the orb, silently, card staged;
  the flag is visible in the snapshot's `reversal` key (index 4).
- **m2 Frostbite (`6-5g/R22`).** A new part tag, `PlayerState.PART_SLOW` (no address, `b` = the struck slot),
  is noted by `_consume_frostbite` into the attacker's own packet, through `reversal_note_part`'s existing
  kind-agreement guard (a stale attacker packet writes nothing). The reversal and gate arms for
  `REVERSAL_FROSTBITE` now cancel `RULE_FROSTBITE_SLOW` only when the packet holds that part, so a victim who
  resolved Frostbite twice keeps the FIRST resolution's running slow when a counter disarms the SECOND, still
  ARMED resolution. New test proves exactly that sequence.
- **m3 Rocksling copies (`6-5g/R10`).** A second `ID_SLING` copy added to the fixture deck; new test: the
  victim casts Rocksling #1 (one stone lands and plants a Boulder, one is in flight, one still owed), casts
  Rocksling #2 and is countered mid-cast of #2 -- #2's cast is interrupted, and #1's pending burst, in-flight
  stone and planted Boulder are all untouched (the fresh packet #2 opens at its own press holds none of #1's
  parts).
- **m1 Bloodhound docstring (`6-5g/R23`).** Restated, in the test's own docstring and its assert message, that
  the mid-roll equality holds BY CONSTRUCTION (the armed trigger is already cancelled at roll entry, so there
  is no window left to expire mid-roll) rather than by a measured comparison, and that the `expired` fixture
  is an untouched comparison arm, not a natural expiry actually happening. Assertions unchanged.
  Deliberately NOT logged as a decision-log ruling of its own (`6-5g/R23` used above only to keep this
  section's numbering scheme; it is a wording fix, not a rule).
- **m5 (`test_a_v18_record_is_refused_with_a_reason`).** Given its own path constant, `PRE_6_5G_PATH`, instead
  of reusing `PRE_6_5C_PATH`.
- **m4 / policy (E5-R/R7).** `docs/implementation-artifacts/6-5f-counterspell.md` REVERTED to HEAD
  (`git checkout --`, confirmed by `git diff --stat` first that no other file was touched by the command) --
  a closed, pushed story file is not edited by a later story's dev or review-fix pass. The supersession of
  6-5f AC 13 and its Live Smoke point 6 by this story's own AC 2 is recorded here and is owed to the
  decision-log at this story's close-out, not to 6-5f's file. AC 2's wording ("interim-rule removal deletes
  exactly three textual artifacts") is therefore understood as satisfied by RECORD (this section, and the
  close-out ruling to come), not by an edited 6-5f doc; AC 2's own text is left as authored and is to be
  aligned with this reading at close-out.
- **Suite (MEASURED).** Fix-state run: **1247 tests, 0 failed, 11713 assertions**, PASS
  (`C:\dev\_65g-suite-fix-state.txt`); integration **72/72 PASS** (`C:\dev\_65g-suite-fix-integ.txt`). +5 tests
  over the dev pass's 1242 (the three B1/M1 tests, m2's, m3's). Golden re-measured, independently, through a
  filtered `test_determinism.gd` run: `test_state_matches_golden` green, UNMOVED (`941958c5...`) -- predicted,
  since the flag write happens only inside kinds the golden fixture never writes (it stages no Counterspell
  and authors every id as `summon_<id>`, `6-5g/R1`'s own non-cause reasoning, unchanged by this fix). FORMAT
  stays 19; per-player snapshot key set stays 45 (no new column, no new key). STUNNED census 4 and the
  death-seat caller pin 6 both re-confirmed unmoved by the fix-state run.
- **Mutation (MEASURED).** 1 applied for this pass (B1's own, above): the `PART_DAMAGE` else-branch's flag
  check removed -> KILLED by the redesigned test (a Rocksling fixture, not Honed Bolt: a lone `PART_DAMAGE`
  packet is refused entirely at the gate once its own flag is false, so the mutated line in
  `_reverse_recorded_parts` is unreachable from that fixture -- Rocksling's still-pending burst is a genuinely
  surviving SECOND part that keeps the gate open and actually exercises the reversal arm). Restored from
  `C:\dev\_65g-fix-match_state.gd.bak`, SHA256 verified back to the pre-mutation hash both before and after.
- **Git.** Commit nothing, no push; `docs/implementation-artifacts/6-5f-counterspell.md`'s revert is the only
  change to a file outside the original nine, and it is a revert, not an edit -- `git status --short` after
  this pass shows the SAME NINE files the dev pass left, nothing staged, nothing untracked.

### File List

Modified -- source:
- `src/state/match_state.gd`
- `src/state/player_state.gd`
- `src/state/unit_board.gd`
- `src/systems/record_file.gd`

Modified -- tests:
- `test/state/test_counterspell.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`

Modified -- docs:
- `docs/implementation-artifacts/6-5g-counterspell-timed-and-in-flight.md` (this file: frontmatter, Tasks,
  Dev Agent Record, Status)
- `docs/implementation-artifacts/sprint-status.yaml`

REVIEW FIX: `docs/implementation-artifacts/6-5f-counterspell.md` is NO LONGER in this list -- reverted to
HEAD (m4 / E5-R/R7), a closed, pushed story file is not edited here.

No new file. `project.godot` UNTOUCHED.

### Change Log

| Date | Change |
|---|---|
| 2026-09-29 | Story authored (`gds-create-story`), scoped from `6-5f-counterspell`'s cut and the 2026-09-29 browser scope talk. No code, no suite run. |
| 2026-09-29 | Readiness gate fix pass: 2 blockers / 3 major / 7 minor findings (`C:\dev\_65g-gate.md`), all textual, closed by `6-5g/R1`-`R20` (decision-log). AC count 30 -> 31 (new AC 31, `_reversal_has_anything_left` per-kind arms). Status `authored -> ready-for-dev`. No code, no suite run. |
| 2026-09-30 | Dev pass. Seven new `REVERSAL_*` kinds; Open Question 1 resolved as a TAGGED PART LIST inside the five existing generic columns (no new column, no new field, no new snapshot key, key set stays 45). Class 1 buff reversals via `cancel_rule`; Class 2 living record opened at the cast press and grown by the strike, the burst, the contact ladder and the Boulder plant; cast interrupt via `clear_cast()` from Counterspell's own arm (never `_cast_is_interrupted`, caster never STUNNED); in-flight vanish via `ProjectileBoard.consume_at`; unfired stones via `clear_burst()` (sixth call site, fourth seat); Boulder lift via the existing uncover seat; Corpse Bomb restore + bolt/Fireball minion restore through ONE extracted `_restore_killed_minion_at`. New `UnitBoard.restore_hp_at`; `_place_boulder` returns its planted slot. `_reversal_has_anything_left` gains one arm per new kind (AC 31). `FORMAT_VERSION` 18 -> 19 with a v18 hard refusal. GOLDEN UNMOVED (`941958c5...`), ZERO re-baselines, all five predicted movers measured as non-causes by a live probe. Suite 1218 -> 1242 state (0 failed), integration 72/72. Status -> review. Nothing committed. |
| 2026-09-30 | Review-fix pass (Claude Sonnet 5, commit nothing). Closed B1 (fabricated resurrection of a unit the countered spell never killed) and M1 (the four part-list kinds admitted a pure no-op past the gate) with one mechanism -- the `flags` column now carries a per-part "this resolution killed it" fact. Closed m2 (Frostbite's cross-resolution slow cancel), m3 (Rocksling copy discrimination, untested), m1 (Bloodhound docstring overclaim), m5 (v18 fixture's borrowed path constant). Reverted 6-5f's doc file to HEAD (m4/E5-R/R7). +5 tests (1242 -> 1247 state, 0 failed); integration 72/72. Golden re-confirmed UNMOVED. One mutation proof (B1), KILLED, restored and SHA256-verified. Nothing committed. |
| 2026-09-30 | Close-out. C1 committed the code and tests (`d6aec96`). Status -> done. AC 2's wording aligned: the interim rule's removal is one code-side deletion (the test) plus a RECORD supersession of `6-5f` AC 13 and its Live Smoke point 6 (`6-5g/R24`) -- `6-5f`'s own file stays untouched (`E5-R/R7`). Live Smoke Results added: operator, two gamepads, flip `[3,3]`, 13/13 PASS, R-D6 re-invoked and passed. Deferred section gains AC 14's stun half (structurally unobservable, mutation M8 GREEN accepted), the Tier B presentation story for all fourteen Deck 1 effects' visuals, and the 20 s corpse lifetime as a playtest knob (`6-5g/R27`). |
