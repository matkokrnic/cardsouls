# Telegraph legibility protocol

A repeatable procedure for judging whether a CardSouls action **reads** — whether a naive
observer can identify what is happening from the telegraph (shape + sound) **before the action
resolves**. Authored for story 2-6 (AC 7). It exists and is rehearsed now, against E1's melee
telegraphs, so it is trusted before E5's colour telegraphs need it.

This file is written and maintained by agents. It is **not** `docs/playtest-log.md` — that log is
written by the operator's own hand, and no agent writes into it (2-6/R11). When a run of this
protocol produces a finding worth logging, the operator records it in the playtest log; the
protocol file only holds the procedure and the rehearsal setup.

## Why this exists

The GDD Legibility Principle: a telegraph is **shape + sound, never hue alone** (colourblind-safe),
and it must be identifiable in **under half a second** — before the action it announces resolves.
A cue that cannot be named before it lands is not a telegraph; it is a surprise. This protocol is
the repeatable test that a cue clears that bar.

## The procedure

Run per telegraph, or per set of telegraphs being compared:

1. **Half width.** Play in the shipped split-screen layout (each viewport is half the window
   width). A cue must read at the size it will actually be seen, not full-screen.
2. **Sound on.** The `CombatCues` audio bus is audible. Shape and sting are judged **together** —
   the principle is shape + sound, so neither is muted for the test.
3. **A naive observer.** The person judging does **not** know in advance which action is coming.
   Ideally someone who has not memorised the cue set; at minimum, the actions are triggered in an
   order the observer cannot predict. (The player triggering the actions and the observer judging
   them should not be the same person for the strongest reading.)
4. **Identify before it resolves.** For each triggered action the observer calls out what they
   think it is **while the telegraph is still playing** — before the swing lands, the block
   connects, or the roll's i-frames end. Record whether the call was made in time and whether it
   was correct.
5. **Record the result** in the table below (or a copy of it for the cue set under test): for each
   action, `identified-before-resolve? (Y/N)` and `correct? (Y/N)`, plus a one-line note on what
   carried the read (shape, sound, both) or what confused it. A cue passes only when a naive
   observer names it correctly, in time, reliably.

A cue that fails is a finding: note it, and the operator logs it in `docs/playtest-log.md`.

### Result template

| Action | Cue under test | Identified before resolve? | Correct? | Carried by (shape / sound / both) | Note |
|--------|----------------|---------------------------|----------|-----------------------------------|------|
|        |                |                           |          |                                   |      |

## Rehearsal — E1 melee telegraphs (story 1-10)

The protocol's first run, against the three melee cues already shipped. These are the
`TelegraphController` profiles authored in story 1-10 (`data/telegraphs/*.tres`), driven off the
`connect_hero_action_state_changed` seam when a hero enters the action state — each a distinct
shape **and** a distinct sting on the `CombatCues` bus (never hue alone):

| Action | Shape (`shape_id`) | Sting (`sting_id`) | Tint | Where it reads |
|--------|--------------------|--------------------|------|----------------|
| Attack | `AttackCone` — a cone pointing where the swing lands | `StingAttack` | red-orange | overhead |
| Block  | `BlockShield` — a flat shield slab | `StingBlock` | blue | overhead |
| Roll / dodge | `RollDisc` — a flat disc underfoot | `StingRoll` | yellow | underfoot |

Notes for the rehearsal run:

- The three shapes are deliberately different primitives at different anchors (attack/block
  overhead, roll underfoot), and the three stings are distinct audio — so the set is designed to be
  distinguishable by ear alone as well as by eye. Story 2-6 (AC 3) confirmed and pinned the
  roll/dodge cue's distinctness (`test/state/test_telegraph_profiles.gd`).
- A successful **dodge** (the roll's i-frames negating a hit) intentionally produces **no** extra
  cue — the roll cue is driven by entering `ActionState.ROLLING`, never by whether a hit was
  actually negated (2-6/AC 3, 1-9/R5). The correct observation of a successful dodge is the
  **absence** of a hit reaction on the roller, not a new sound.
- Exercising every E1 cue: attack/roll cues and a self-drained rejection cue come from P1 alone;
  the hit reaction shows on whichever hero is struck; the deflect spark and the block chip need P2
  to swing and block. Since story 2-3 the shipped default is `[KEYBOARD_P1, KEYBOARD_P2]` (two live
  keyboards) — **P2 acts with no flip and no `.tscn` edit.** (The story-1-10 two-phase setup, which
  temporarily flipped slot 1 to `KEYBOARD_P2`, is obsolete: that flip is now the shipped default.)
- **A SOLO run cannot satisfy the naive-observer requirement.** One person driving the actions and
  judging them already knows what is coming, so a solo pass is a DRY RUN of the PROCEDURE (does the
  rig produce the cues, are the steps runnable) — NOT a verdict on whether the cues read. The
  definitive legibility judgement (identify-before-resolve, reliably, by someone who does not know
  the cue set) is animation-gated and belongs to the future rig story — the DEBT E "legibility
  under 0.5 s" member.
- **Deviation requirement:** any run performed WITHOUT a naive observer must SAY SO in its result
  table (e.g. a "naive observer: NO — dry run" note), so a procedure dry run is never mistaken for a
  legibility verdict.

**Rehearsal outcome:** run by the operator during the story 2-6 live smoke (AC 8), using the table
above. The outcome (each melee cue identifiable, in time, by a naive observer) is recorded by the
operator; any cue that fails to read is logged by hand in `docs/playtest-log.md`. This protocol
file is not an agent's place to assert an empirical reading it did not observe.
