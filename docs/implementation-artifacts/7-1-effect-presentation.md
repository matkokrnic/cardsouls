---
baseline_commit: e93dbeeb2a8203105d32dd3f678fa95eafe8e824
---

# Story 7-1: Effect Presentation

Status: ready-for-dev

> **Scope note.** Second `epic-7` story (`E6-C/R11` board order), **Tier B** (`E4-P/R9`): presentation,
> data and tooling only. `src/state/` stays byte-identical and the golden and the per-player snapshot
> key set are predicted UNMOVED, measured before and after, never assumed. The scope was locked with
> the operator in the browser on 2026-10-01 and exists nowhere else in the repo; the **Scope** table
> below is its only written record and is authoritative for this story. It discharges the `7-1`
> share of the presentation debt `E6-C/R9` consolidated (`deferred-work.md:558-566`).

## What this story supersedes

Measured against the code at `e93dbee`.

1. **The invisible Grave Ward tint** (`6-5b` AC 24, visual half, FAILED at smoke —
   `6-5b-corpses-and-own-minions.md:401`). Today `_free_dead_unit_actors` tints a child named `Mesh`
   with `UnitActor.EXTENDED_CORPSE_TINT` (`src/main/match_runner.gd:2086-2096`); the rigged minion
   scene may have no such child, so nothing shows. Replaced by the Grave Ward row below (glow +
   circling ghosts). The state-side mark is correct and untouched.
2. **The placeholder Honed Bolt shaft** — `BoltActor`, an unshaded blue cylinder rising to a 9 m
   apex and falling onto the target (`src/actors/props/bolt_actor.gd:27-58`). Replaced by branching
   sky lightning. Its timing contract stays: the visible strike lands on the state's strike tick
   (`6-5c` AC 25, `bolt_actor.gd:73-89`, pinned by `test/integration/test_cast_presentation_live.gd`).
3. **The placeholder hero-spell projectile look.** Every projectile — totem shots, Fireball,
   Rocksling stones, Corpse Bomb skulls — instantiates the one `projectile_actor.tscn`: an orange
   emissive sphere, mesh radius 0.25 (`src/actors/projectiles/projectile_actor.tscn:8-16`,
   `match_runner.gd:2711-2723`). Fireball, Rocksling and Corpse Bomb get their own looks below.
   **The totem shot's look is out of scope and stays as `5-0c` shipped it.**
4. **One cast clip for every cast.** `AnimationController.on_cast_started` always plays `&"cast"`
   (`src/actors/hero/animation_controller.gd:1032-1040`, `:1036`), so Fireball and Rocksling borrow
   Honed Bolt's sword raise today. Fireball and Rocksling get their own clips; Honed Bolt keeps
   `cast`.
5. **The Counterspell placeholder** — a violet sign and a stub sound on both heroes (`6-5f` AC 26,
   `telegraph_controller.gd:76-88`, `:257-264`). Replaced by the blue rune circle and the
   "returned" flash below (blue = the card's colour).
6. **Eleven of the fourteen Deck 1 effects show only the generic cast-success cue**
   (`telegraph_controller.gd:234-235`; `deferred-work.md:564`). Every row of the Scope table gets its
   own look and sound.

## Story

As a player in a Deck 1 match,
I want every card effect — mine and my opponent's — to have its own readable look and sound,
so that I can tell at a glance and by ear what was just cast, what is still running, and what is
about to hit me.

## Scope (operator, 2026-10-01 — authoritative)

Every Deck 1 effect gets visuals and sound. Presentation only. Colour follows the card colour.
Persistent effects are visible to the opponent too.

| effect | what the player sees | sound slots (filename keywords) |
|---|---|---|
| Vanguard | green crack in the ground where the minion emerges, dust and sparks | summon (earth burst, bone crack) |
| Culling | each culled minion flares in green fire; one soul per minion flies to the caster (makes the mana gain visible) | cull (dark magic impact), soul (synth) |
| Grave Ward | corpses glow green with ghosts circling above while the extension lasts (replaces today's invisible tint) | ward (ghost, whisper) |
| Raise Dead | green pillar rises from the corpse, the minion appears inside it | raise (zombie groan, rumble) |
| Drain | green thread minion -> hero for ~0.4 s, minion crumbles, hero flashes (`7-1/R1`: was red) | drain (suck, reverse whoosh) |
| Vampiric Aura | green aura on the body for its 15 s; each heal = droplets flowing into the hero (`7-1/R1`: was dark-red) | aura (dark magic, heartbeat), heal (synth, optional) |
| Rocksling | real rock models with a dust trail, debris on hit | rock_throw (throw whoosh), rock_hit (rock impact, debris) |
| Boulder slow | stone crust on the slowed hero's legs; more Boulders = more stone | -- |
| Boom | one rock explosion on the opponent per Boulder, in a short sequence | boom (rock explosion) |
| Bloodhound Step | red mist behind the hero while the window lasts; the extended roll leaves a trail | hound (dog growl, snarl) |
| Fireball | VFX only, no model: glowing core with moving noise, particle flame trail, sparks, small light on the ground; grows with mana invested; impact = explosion, deflect scatters it | fire_launch, fire_loop, fire_hit |
| Honed Bolt | branching lightning from the sky with a flash; the existing target marker during the cast stays and is refined | bolt_charge (electric crackle), bolt_strike (thunder crack) |
| Counterspell | blue rune circle on both heroes; whatever gets returned (minion, HP) flashes blue | counter (magic shatter, reverse) |
| Frostbite | weapon frosted while armed; on hit the target's legs freeze while the slow lasts | frost_arm (ice shimmer), frost_hit (ice shatter) |
| Corpse Bomb | minions glow blue, a skull in blue flame flies out of each; impact = bone explosion | skull_launch (ghost scream), skull_hit (bone explosion) |
| stun / root | existing dizzy stays plus sparks above the head; root = blue electric shackles around the legs | -- |

Card colours (authored, `data/cards/*.tres` `color`): GREEN — Ruin Vanguard/Culling, Grave
Ward/Raise Dead, Drain/Vampiric Aura; RED — Rocksling/Boom, Bloodhound Step/Fireball; BLUE — Honed
Bolt/Counterspell, Frostbite/Corpse Bomb. Boulder is colourless (`6-5e/R26`).

**Cast clips (operator).** Fireball gets its own clip, `cast_fireball.fbx` (hash-confirmed distinct
from `cast.fbx`, below). Rocksling gets two: lift (`cast_rocksling_lift.fbx`, Mixamo "Standing 2H
Cast Spell 01") and throw (`cast_rocksling_throw.fbx`, "Standing 2H Magic Attack 01"). **Option A:**
rock 1 leaves on the throw; rocks 2 and 3 of the burst fly without a swing until `7-2`. Honed Bolt
keeps the shared `cast` clip. Timing is authored and the animation serves it: the release frame lands
on the launch tick (the `4-3d` strike-alignment precedent). The hero stands and cannot cancel during a
cast (`6-5c`), so the full-body clips must not slide.

## Measured for this story (create pass, 2026-10-02)

### Trigger map — the existing hook presentation can listen to or poll, per row

"Poll" means a per-tick read by the runner of a public field or pure query, the shape
`_root_in_force` (`match_runner.gd:1332`) and `_push_cast_presentation` (`:1244`) already use.
"Signal" means an existing seam or one of the two sanctioned direct connects (`E6-C/R2`).

| row | existing hook(s) | presentation today |
|---|---|---|
| Vanguard | `MatchState.card_cast_resolved(slot, card_id, mode)` (`match_state.gd:99`, emitted `:4071`; wired `match_runner.gd:644`); the new actor appears in `_spawn_missing_unit_actors` (`match_runner.gd:1733`), a summon being a record with `UnitBoard.raised_from_at == NO_RAISE_SOURCE` (`unit_board.gd:631`) | generic cast-success sound only |
| Culling | `card_cast_resolved` (PITCH of `ruin_vanguard`); the culled board indices are `PlayerState.reversal_indices` under `reversal_kind == REVERSAL_CULLING` (`player_state.gd:855`, `:884`, `:788`), the same tick those records turn dead (`unit_board.gd:514`, observed at `match_runner.gd:2075`); mana gain on `connect_mana_changed` | generic sound; minions simply die |
| Grave Ward | poll: `UnitBoard.is_corpse_extended_at` + `corpse_ticks_at` (`unit_board.gd:623`, `:618`), already read every tick at `match_runner.gd:2091-2092` | invisible tint (supersedes 1). The mark is LATCHED for the corpse's whole remaining life (`6-5b/R7`, `unit_actor.gd:143-145`), so "while the extension lasts" = until that corpse leaves state |
| Raise Dead | `card_cast_resolved` (PITCH of `grave_ward`); each raised record has `raised_from_at != NO_RAISE_SOURCE` and is placed on its corpse at `match_runner.gd:1777`/`_raised_spot` `:1788` | generic sound; minion pops in on the corpse |
| Drain | `card_cast_resolved` (BASIC of `drain`); sacrificed index = `reversal_indices[0]` under `REVERSAL_DRAIN`, also the runner's own pushed target (`_gather_drain_target`, `match_runner.gd:3096`); the heal arrives on `connect_hero_hp_changed` (`match_runner.gd:2389`) | generic sound only |
| Vampiric Aura | poll: `PlayerState.is_rule_active(RULE_VAMPIRIC_AURA)` (`player_state.gd:725`, `:604`); each lifesteal heal is `HeroState.heal` (`match_state.gd:3209`) → `hp_changed` on the caster's seam | generic sound only |
| Rocksling | cast: rising edge of `PlayerState.is_casting()` with `MatchState.cast_outcome(player) == OUTCOME_ROCKSLING` (`match_runner.gd:1263-1284`, `match_state.gd:6469`); stones: projectile board growth (`_spawn_missing_projectile_actors`, `match_runner.gd:2711`) with `ProjectileBoard.effect_id_at == "rocksling"` (`projectile_board.gd:320`); rock 1 at the strike, rocks 2-3 from the burst (`has_pending_burst`, `player_state.gd:418`); hit: shot ends (`is_alive_at` false, `_free_dead_projectile_actors` `match_runner.gd:2881`) plus the opponent's Boulder count rising | `cast` clip (Honed Bolt's), orange sphere stones |
| Boulder slow | poll: `opponent.hand.cover_count()` (`hand.gd:301`) — see "Boulder read path" | none |
| Boom | `card_cast_resolved` (PITCH of `rocksling`), preceded in the SAME drain by one `hit_landed` per detonated Boulder (`_apply_boom`, `match_state.gd:4521-4531`); the count is also the opponent's `cover_count` on the previous tick | generic sound + hit flashes |
| Bloodhound Step | poll: `is_rule_active(RULE_BLOODHOUND_ARMED)` for the window, `RULE_ROLL_BOOST` for the boosted roll (`player_state.gd:605-606`; consumed at `match_state.gd:1959-1965`) | generic sound only |
| Fireball | cast: `cast_outcome == OUTCOME_FIREBALL` on the rising edge (`match_runner.gd:1284`); ball: board growth with `effect_id_at == "fireball"`, size input `ProjectileBoard.damage_at` (locked damage = `damage_per_mana × X`, `projectile_board.gd:126-136`, `:328`); flight: `_drive_projectiles` (`match_runner.gd:2796`); end: `is_alive_at` false; consumed vs expired is `travelled_at < travel_budget` (`projectile_board.gd:340`, `:381-389`); a deflect fires `deflect_landed` (`match_state.gd:2546`, seam `match_runner.gd:1655`) — **per-shot hit-vs-deflect is not exposed; see OQ 2** | `cast` clip, orange sphere |
| Honed Bolt | `_push_cast_presentation` (`match_runner.gd:1244-1321`): launch tick `:1256-1257`, `BoltActor` flight/arrival (`:1352`), target warning `on_cast_warning_started` (`telegraph_controller.gd:167`) or `TargetConeActor` for a unit target (`:1293-1297`) | `cast` clip, blue shaft, amber marker + looping alarm, cone |
| Counterspell | `MatchState.counterspell_resolved(caster, countered)` (`match_state.gd:117`, wired `match_runner.gd:662`); returned HP arrives on `hp_changed`; revived minions are records turning alive again — **the returned-item set is NOT readable at the signal: `clear_reversal()` runs before the emit (`match_state.gd:4723`, `:4727`); see OQ 3** | violet sign + stub sound on both heroes |
| Frostbite | poll: `is_rule_active(RULE_FROSTBITE_ARMED)` on the caster (weapon), `RULE_FROSTBITE_SLOW` on the target (legs), started at the hit (`match_state.gd:3272-3281`) | generic sound only |
| Corpse Bomb | `card_cast_resolved` (PITCH of `frostbite`); converted indices `PlayerState.corpse_bomb_indices` (`player_state.gd:481`); skulls = board growth with `effect_id_at == "corpse_bomb"`, launched from each minion's actor (`add_minion_shot`, `projectile_board.gd:216`; `match_runner.gd:2746-2754`); impact = shot ends (same OQ 2 gap) | generic sound, orange spheres |
| stun / root | stun: `connect_hero_action_state_changed` → STUNNED with `_stun_flavor_for_slot == STUN_FLAVOR_BOLT` (`match_runner.gd:1572`, `animation_controller.gd:182`, `_play_dizzy` `:996`); root: per-tick `set_root_marker(_root_in_force(player))` (`match_runner.gd:1321`, `telegraph_controller.gd:184`) | dizzy clip; blue disc at the feet |

**Rows with no existing hook: none.** Two rows carry a partial gap — the per-shot impact kind
(Fireball/Rocksling/Corpse Bomb, OQ 2) and Counterspell's returned-item set (OQ 3). No seam is
designed here and `src/state/` is not touched.

### Fireball — hit radius

- **The hit radius is not in state at all.** It is the `Hitbox` sphere of the shared
  `projectile_actor.tscn`: `SphereShape3D` radius **0.35 m**, centred **+0.7 m** in y
  (`projectile_actor.tscn:5-6`, `:28-30`). The visible mesh is radius 0.25 at the same offset
  (`:8-10`, `:33-35`). State only decides what a reported overlap means.
- **It does not change with mana.** Mana invested changes only the locked damage
  (`damage_per_mana` 1.5 × X, `data/effects/fireball.tres:9-10`; X from the card's staging price up to
  `mana_cap` 10, `deck-1-spec.md:87-90`). Every Fireball, at every X, hits with the same 0.35 m sphere.
- **Consequence for the growth rule:** the visible ball (the glowing core — not the trail, sparks or
  ground light) can grow with X and still never read larger than what hits, as long as its largest
  size (at `mana_cap`) stays inside the 0.35 m sphere and concentric with it. Satisfiable without a
  state change, so no Open Question is raised. Changing the hitbox radius is out of scope: it would
  change which contacts are reported, i.e. gameplay.

### Boulder — read path

`PlayerState.hand.cover_count()` (`src/state/hand.gd:301-306`), a pure fold over the cover layer. It
is the same read the state's Boulder slow takes (`match_state.gd:7586-7604`) and Boom's gate takes
(`:5283`). The runner can poll it per tick for each player (the `_root_in_force` shape). The
`cards_changed` payload also carries covers (`Hand.visible_array`, `hand.gd:290`), but that channel is
own-slot only (`connect_cards_changed`, `match_runner.gd:2441`) and cannot drive a look the opponent
sees. Showing the count is fine: it reveals no hand content (`6-5e/R28`, `deck-1-spec.md:152-154`).

### Assets (staged outside the repo, read-only here)

- **Cast clips** (`C:\dev\_assets-71\anims\`): `cast_fireball.fbx` 364,960 B, sha256 `a9b3534b…`;
  `cast_rocksling_lift.fbx` 516,832 B, `14dda3fc…`; `cast_rocksling_throw.fbx` 572,176 B, `5bccf88d…`.
  The repo's `assets/characters/paladin/cast.fbx` is `1a3078cd…`, so the Fireball clip is distinct.
- **Skull** (`models\skull\source\hornman_skull.obj`, 14,564,430 B): **213,812 face lines, all
  triangles → 213,812 triangles**, 106,926 vertices. Untextured.
- **Rock** (`models\rock\`): `Rock-Mesh.fbx` 43,356 B; four PNGs, **all 4096 × 4096** —
  `Rock_MAT_BaseColor` (RGB, 11.8 MB), `Rock_MAT_Normal` (RGB, 14.6 MB), `Rock_MAT_Roughness`
  (grey, 6.5 MB), `Rock_MAT_Metallic` (grey, 16 KB). `internal_ground_ao_texture.jpeg` (19.5 KB) is the
  Sketchfab ground shadow and is not used.
- **Kenney** (`vfx\`, CC0): `kenney_particle-pack` — **193 PNGs**: 80 + 16 rotated on black
  background, the same 80 + 16 transparent, 1 preview. `kenney_smoke-particles` — **79 PNGs**: Black
  smoke 25, White puff 25, Explosion 9, Flash 9, Fart 9, plus 2 previews.
- **Credits** (`models\credits.txt`): rock — "Rock Game Asset" by Agustin Honnun, Sketchfab; skull —
  "Hornman Skull", Sketchfab. Treated as CC-BY, so credits ship in the repo.
- **Sonniss** (`C:\dev\_sonniss\part1\`): 85 files = 82 `.wav` + filelist `.xlsx` + license `.pdf` +
  `Readme.txt`. The filelist is titled "Part 9", not "part 1" — informational only.

### Sound slots — first pick by filename (part 1)

Paths are relative to `C:\dev\_sonniss\part1\`; every directory starts `344 Audio - `. "Fit" is a
filename judgement only; the operator judges by ear at smoke (sound rule below).

| slot | first pick | fit |
|---|---|---|
| summon | `Cinematic Fight Vol. 1/FGHTImpt_4 x Punch, Body 02…` | weak (body impact, no earth/bone) |
| cull | `Haunting Ambiences Vol. 3/WOODImpt_Wooden Hit, Dark, Heavy Hit, Vampire's Prison…` | plausible |
| soul | — synthesize | — |
| ward | `Ghostly Presences Vol. 1/AMBDsgn_Evil Spell Ambience…` | plausible |
| raise | `Bass Drops & Downers Vol. 3/DSGNBass_Rattling Downer 3…` | plausible (rumble; no groan) |
| drain | `Elemental Palette Designed Vol. 1/WINDDsgn_Wind, Rush, Whoosh, Long x5 01…` (reversed) | plausible |
| aura | `Bass Drops & Downers Vol. 1/DSGNBass_Bass Drop & Downer Slow 10…` | plausible (no heartbeat) |
| heal | — synthesize (optional) | — |
| rock_throw | same file as drain, forward, other pitch | plausible |
| rock_hit | `Historical Weapons Vol. 2/WEAPBlnt_Spear And Stick Impact, Wooden MKH 2…` | weak (no rock impact in part 1) |
| boom | `Bass Drops & Downers Vol. 1/DSGNBass_Bass Drop & Downer Fast 16…` | weak (no explosion in part 1) |
| hound | `Dog Vocalisations Vol. 1/ANMLDog_Dog Barks, Multiple, Indoors, Perspective,…_02` | plausible (barks, not growl) |
| fire_launch | `Air Designed/AEROJet_Blast Off Clean…` | plausible |
| fire_loop | `Haunting Ambiences Vol. 5/FIRECrkl_Fire Crackling, Popping, Witch's Cauldron…` | good |
| fire_hit | `Bass Drops & Downers Vol. 2/DSGNBass_Bass Drop & Downer Fast 12…` | weak |
| bolt_charge | `East Coast America Vol. 1/AMBSubn_Electricity Hum, Lightbulb, Coil Pickup 01…` | good |
| bolt_strike | **none** in part 1 — synthesize (`7-1/R5`) | synth |
| counter | `Bass Drops & Downers Vol. 3/DSGNBass_Tone Downer (Reverb)…` (reversed) | plausible |
| frost_arm | `Christmas Vol. 1/MAGMisc_Magic Christmas Bells 2…` | plausible |
| frost_hit | **none** in part 1 — synthesize (`7-1/R5`) | synth |
| skull_launch | `Air Designed/AEROJet_Unidentified Encounter…` | weak |
| skull_hit | same file as summon, other pitch | weak |

### Hero clip library

- Honed Bolt's clip is `cast`, sourced from `assets/characters/paladin/cast.fbx` and baked into the
  shared library `assets/characters/paladin/paladin_anims.res` by `tools/add_paladin_cast_clips.gd`
  (which loads the library, asserts the 27 already there, adds `cast`/`dizzy`, saves —
  `:39-59`, `:70-125`). Its raise frame is measured by `tools/measure_cast_clip_frames.gd` and
  consumed as `CAST_CLIP_SECONDS`/`CAST_RAISE_SECONDS` (`animation_controller.gd:196-213`).
- **The clip count is pinned by `test/integration/test_rig_clips.gd`**: `EXPECTED_LOOP`
  (`:28-54`, 29 entries) — the count assertion is derived from it (`:79-81`). Three new one-shot clips
  take it from **29 to 32. This is a named deviation** of this story, not a regression.

## Acceptance Criteria

**Structure — Tier B holds**

1. `git diff --stat -- src/state/` is empty at the before-measurement and at the end of the pass.
2. The golden (`test/state/test_determinism.gd:1307`, `941958c5…871f`) and the per-player snapshot
   key set (45 keys, `test/state/test_card_observation.gd:361`) are measured unmoved before and after.
   If either moves, the story is Tier A by the golden clause: stop and report, do not re-baseline.
3. No new `connect_*` seam (`test_runner_observation_seams_are_exactly_ten` unedited) and no new raw
   `_match_state.<signal>.connect(` site (`test_raw_match_state_connects_are_pinned_by_shape`
   unedited). If an effect cannot be shown without one, that is a design question raised with the
   operator before it is built.
4. Visuals and sounds never decide anything: no contact, timing window, outcome or replay record
   depends on them. Every collision shape is unchanged — in particular the projectile `Hitbox`
   (radius 0.35, +0.7 y). `FORMAT_VERSION` stays 19; `project.godot` is byte-identical.
5. No state handle (`PlayerState`, `MatchState`, a board) is stored on, or passed into, any actor,
   VFX node or controller. They receive plain values, as `UnitActor.on_corpse_state` does
   (`unit_actor.gd:160-165`).

**Per effect — each one shows and sounds as its Scope row says, triggered by the hook in the
trigger map**

6. **Vanguard:** a summoned minion emerges from a green ground crack with dust and sparks; the
   `summon` sound plays. A Raise Dead minion does NOT get this (it has its own row).
7. **Culling:** each culled minion flares in green fire; one soul per culled minion flies from it to
   the caster and arrives no later than the mana gain shows on the HUD. `cull` plays once; `soul`
   plays per soul.
8. **Grave Ward:** every corpse the caster's Grave Ward extended glows green with ghosts circling
   above it, from the resolution until that corpse leaves state (`6-5b/R7`). A Counterspell that
   removes the extension removes the glow. `ward` plays at resolution. The `6-5b` AC 24 visual half is
   discharged by this AC. A live integration test proves the glow is present on an extended corpse
   of the SHIPPED minion scene — the `6-5b` tint failed at smoke because nothing checked it on the
   real rig (suspected: no `Mesh` child, `6-5b-corpses-and-own-minions.md:401`).
9. **Raise Dead:** a green pillar rises from each consumed corpse and the raised minion appears
   inside it. `raise` plays.
10. **Drain:** a green thread runs from the sacrificed minion to the caster for ~0.4 s (a knob), the
    minion crumbles, the caster flashes. `drain` plays.
11. **Vampiric Aura:** a green aura is on the caster's body for exactly as long as the rule runs,
    including when a Counterspell ends it early. Each lifesteal heal shows droplets flowing into the
    hero; `aura` plays at the start, `heal` (if shipped) per heal.
12. **Rocksling:** each stone is the rock model with a dust trail, and a stone that ends on a hit
    throws debris. `rock_throw` plays per stone, `rock_hit` per hit.
13. **Boulder slow:** a hero holding Boulders shows a stone crust on the legs. The crust's amount
    follows the live Boulder count, rising and falling on the same tick the count changes, and is
    gone at 0.
14. **Boom:** the opponent shows one rock explosion per detonated Boulder, as a short sequence (the
    spacing is a knob). `boom` plays per explosion.
15. **Bloodhound Step:** red mist trails the hero while the armed window runs; a roll that consumes
    it leaves a trail for that roll only. `hound` plays at resolution.
16. **Fireball:** no model. A glowing core with moving noise, a particle flame trail, sparks and a
    small light on the ground. The core grows with mana invested. The shot's ending look is read
    per `7-1/R2` (applies to every hero-spell shot): `deflect_landed` for the target -> scatter; HP
    loss on the target -> impact; `counterspell_resolved` against the owner -> vanish; budget spent
    -> fizzle; several shots ending on one target in one tick are paired by count. A deflected shot
    that state keeps alive flies on with no scatter. `fire_launch` at launch, `fire_loop` while in flight (stops
    when the shot ends by any route), `fire_hit` on impact.
17. **Fireball size honesty (`6-1d` precedent):** at every mana value from the minimum staging price
    to `mana_cap`, the visible SOLID core (trail, sparks and light may extend beyond, `7-1/R9`) never
    reads larger than the hit sphere — its largest extent stays
    inside radius 0.35 and is concentric with it (+0.7 y). A test pins the core extent against the
    `Hitbox` shape read from the scene, at the minimum and at `mana_cap`, so a retune of either knob
    that breaks the rule fails the suite.
18. **Honed Bolt:** branching lightning strikes from the sky with a flash. The existing target warning
    (the marker and alarm on a hero target, the cone on a unit target) stays and is refined. The
    visible strike still lands on the state's strike tick (`test_cast_presentation_live.gd` stays
    green). `bolt_charge` during the cast, `bolt_strike` on the strike.
19. **Counterspell:** a blue rune circle appears on both heroes on a real reversal and never on a
    refusal; whatever the reversal returned (a revived minion, refunded HP) flashes blue, read from
    the runner's own previous-tick copy of the countered player's reversal record (`7-1/R3`). `counter`
    plays. The violet `6-5f` placeholder is retired.
20. **Frostbite:** the caster's weapon is frosted while the trigger is armed; on the consuming hit
    the target's legs freeze for as long as the slow runs, including an early end by Counterspell.
    `frost_arm` at resolution, `frost_hit` on the consuming hit.
21. **Corpse Bomb:** each converted minion glows blue and a skull in blue flame flies out of it; a
    skull impact is a bone explosion. `skull_launch` per skull, `skull_hit` per impact.
22. **Stun / root:** a bolt stun keeps the dizzy clip and adds sparks above the head; a root shows
    blue electric shackles around the legs for as long as `_root_in_force` holds (not on a corpse,
    not during the stun).

**Cast clips**

23. A Fireball cast plays `cast_fireball`; a Rocksling cast plays the lift then the throw; a Honed
    Bolt cast plays `cast` exactly as today. Each new clip's release frame is measured (the
    `tools/measure_cast_clip_frames.gd` precedent) and lands on the tick the shot launches, at any
    authored `cast_seconds` — a retune of `cast_seconds` retimes the show with no code edit (the
    `6-5c` AC 25 rule).
24. Rocksling, option A: stone 1 leaves on the throw's release frame; stones 2 and 3 fly with no
    swing.
25. No new clip moves the hero: each clip's Hips planar travel is measured and stays inside the
    `3-0b/R27` ceiling (0.25 m), or the clip is pinned in place (the `add_paladin_cast_clips.gd`
    refusal precedent). The hero visibly stands through every cast.
26. `test_rig_clips.gd`'s `EXPECTED_LOOP` gains the three new clips, all one-shot (LOOP_NONE),
    29 → 32. The change is named in the Completion Notes as a deviation of this story.

**Colour, visibility, knobs**

27. Each effect is drawn in its card's colour, taken from the existing authored colour vocabulary
    (the charge `TelegraphProfile`s, the `on_orbs_changed` precedent — no second colour table),
    with no exceptions (`7-1/R1`).
28. Every persistent effect (Grave Ward glow, Vampiric Aura, Boulder crust, Bloodhound mist, frosted
    weapon, frozen legs, root shackles, stun sparks) is world-space on the actor and visible in BOTH
    split-screen viewports.
29. Every size, colour, duration and volume knob of every row is adjustable without a code change
    (authored resource or exported scene property), so the post-smoke polish round changes values
    only. A test fails if a Scope row has no authored knob set. Knobs live in a presentation-only
    `Resource` class and folder (or an existing presentation home if one fits), never under
    `data/effects` or any path `src/state/` loads (`7-1/R6`); the Dev Agent Record names the choice.

**Sound**

30. Every non-empty slot ships one trimmed clip: the first variant of a multi-variant file, split on
    silence, leading silence trimmed so the sound lands on its impact frame; the measured onset is
    recorded per file. `soul` and `heal` are synthesized on the `tools/gen_counterspell_audio.gd`
    precedent, and so are `bolt_strike` and `frost_hit` (`7-1/R5`). One file may serve two slots at
    different pitch. The weak first picks ship as picked; only slots smoke rejects go to other
    Sonniss parts or Freesound (`7-1/R5`). An effect with its own resolution sound does not also play
    the generic cast-success sound, which stays the fallback for cards without one (`7-1/R4`).

**Ingest — raw sources never enter the repo**

31. Only processed assets are committed: rock textures at most 1024 × 1024; the skull decimated to a
    few thousand triangles as `.glb`, triangle count recorded (automatic decimation first; if it
    fails the dev pass stops and reports, and the operator decimates in Blender — `7-1/R8`); only the Kenney textures actually referenced; the
    trimmed sound clips; a credits file naming the rock and skull authors/sources and the Kenney
    licence. No `.obj`, no 4K PNG, no AO jpeg, no untrimmed `.wav`, no unused Kenney PNG is committed.

**Lifecycle and regression**

32. Every effect node and sound is stopped and freed on round end, debug reset, death, an
    interrupted cast and a Counterspell vanish; nothing lingers on a corpse or into the round-over
    freeze (the `_root_in_force` "a corpse shows nothing" rule).
33. The full suite passes (`bash test/run_all.sh`). The existing presentation tests
    (`test_cast_presentation_live.gd`, `test_cast_success_cue_live.gd`, `test_fireball_live.gd`,
    `test_boulder_and_skull_live.gd`, `test_cast_interrupt_live.gd`) pass; any edit to one is named
    with its reason.
34. Live Smoke (below) is run and reported per item (`E6-R/R9`).
35. **Hit shapes pinned per kind (`7-1/R9`).** For each projectile kind — totem shot, Fireball,
    Rocksling stone, Corpse Bomb skull — a test asserts the hit shape (sphere, radius 0.35), its
    offset (+0.7 y) and the `Hitbox` collision layer/mask/monitorable values are identical to
    `e93dbee`'s `projectile_actor.tscn`, whatever scene or skin the kind now uses.

## Deferred (named, not in this story)

- **`7-2-animation-polish`:** upper/lower body split; buff gestures; swings for Rocksling stones 2-3.
- **`7-3-minion-rework`:** minion clips. This story's minion-side effects must not assume today's
  minion model beyond a world position.
- **`7-6-hud-and-card-presentation`:** HUD-side per-effect cast feedback and hand icons; Boulder
  cosmetics in the hand HUD (`7-1/R7`). 7-1 covers only the in-world leg crust.
- **The totem projectile's look** stays as `5-0c` shipped it.
- **Sonniss parts 2-5 / Freesound** only for slots smoke rejects (`7-1/R5`).

## Golden Prediction

**PREDICTED UNMOVED — measured before and after, both directions.** This story has no `src/state/`
diff (AC 1): every new behaviour reads public fields and pure queries the runner already reads, plus
`data/` and scene changes outside the hashed path. No `to_snapshot()` changes shape, so the 45-key set
cannot move, and no consumer of the seeded RNG is added. If the golden moves, the cause is not
presentation by construction — find it (most likely an accidental `src/state/` edit or a `data/effects`
edit that reaches the effect injection channel) and report it rather than re-baseline (AC 2).
`data/effects/*.tres` and `data/cards/*.tres` are injected into `MatchState` and captured by the
recorder (`intent_recorder.gd:227`); if the dev pass wants to author `CardEffect.visual_id`
(`card_effect.gd:286-289`) there, it measures the golden and a replay round-trip first.

## Tasks / Subtasks

- [ ] Before-measurement: suite, golden, 45-key set, `git diff --stat -- src/state/` (AC 1, 2)
- [ ] Ingest: process the staged assets per the ingest rule; record skull triangle count, texture
      sizes, the Kenney files kept, per-sound-slot file and measured onset (AC 30, 31)
- [ ] Add the three cast clips to `paladin_anims.res` on the `add_paladin_cast_clips.gd` route;
      measure Hips travel and release frames; extend `test_rig_clips.gd` (AC 23-26)
- [ ] Wire the cast clip choice and release timing for Fireball/Rocksling; keep Honed Bolt (AC 18, 23, 24)
- [ ] Build each Scope row against its trigger-map hook (AC 6-22)
- [ ] Knob set per row + its test (AC 29); colour from the existing vocabulary (AC 27)
- [ ] Fireball size test against the scene's `Hitbox` (AC 17)
- [ ] Teardown on every exit path (AC 32)
- [ ] After-measurement + full suite (AC 1, 2, 33); record suite-output timestamps
- [ ] Live Smoke handed to the operator (AC 34)

## Live Smoke

Two players or a solo with the `6-D1` keys; a single-operator run is named as a deviation. Verdict
per item, headline = worst item (`E6-R/R9`).

1-16. **Look and sound of every Scope row**, one item each, in the Scope table's order. For each:
      the look matches its row, the sound plays at the right moment, and a persistent effect is
      also visible in the OTHER player's viewport. Sound items are judged by ear: "X bad" → next
      variant or file in the polish round.
17. **Rocksling swing:** the throw plays on stone 1 only; stones 2 and 3 fly with no swing; the hero
    does not slide during lift or throw.
18. **Fireball cast and growth:** `cast_fireball` plays, the ball leaves on the release frame; a
    minimum-mana and a max-mana Fireball read visibly different in size, and neither reads larger
    than what hits.
19. **fps** stable while Corpse Bomb fires from the fullest minion board the operator can field
    (minion count recorded, frame time recorded).
20. **Regression, enumerated:** melee, block, deflect, roll, a mode-2 unblockable, a mode-3 defence,
    a pitch activation, the Honed Bolt timing and the totem projectile look are unchanged.

## Dev Notes

### Open Questions — all answered at operator review (2026-10-02)

1. **Drain and Vampiric Aura colour.** Both are on a GREEN card, but their rows say red thread and
   dark-red aura. AC 27 follows the rows; the operator confirms these two exceptions to "colour
   follows the card colour". **ANSWERED `7-1/R1`: no exceptions — both are green.**
2. **Per-shot impact kind.** A projectile's end is visible (`is_alive_at` false) and hit/deflect
   versus budget expiry is derivable (`travelled_at` vs budget). Hit versus deflect versus
   Counterspell vanish is not exposed per shot: `hit_landed`/`deflect_landed`/`counterspell_resolved`
   name slots, not shots. Is a same-drain correlation by slot acceptable for "impact = explosion,
   deflect scatters it" (it can mislabel two shots of one slot ending on one tick), or does it need
   a state-side fact — which would be a seam and Tier A? **ANSWERED `7-1/R2`: no state fact; read
   per AC 16, pair by count, which shot gets which look is arbitrary; misreads only a state fact
   could fix go to a later Tier A story.**
3. **Counterspell's returned-item flash.** `clear_reversal()` runs before `counterspell_resolved` is
   queued (`match_state.gd:4723`, `:4727`), so the set of returned things cannot be read at the
   signal. Is a runner-local previous-tick copy of the countered player's public reversal packet
   acceptable, or is the flash limited to what is visible anyway (refunded HP on `hp_changed`,
   minions turning alive)? **ANSWERED `7-1/R3`: yes, the runner-local copy.**
4. **The generic cast-success cue** (`5-3` AC 13): keep it alongside each effect's own sound, or
   silence it for effects that now have one? **ANSWERED `7-1/R4`: silenced; generic stays the
   fallback; smoke may reverse.**
5. **Empty sound slots:** `bolt_strike` and `frost_hit` have no plausible part-1 file. Synthesize,
   use Sonniss parts 2-5, or ship silent until smoke? **ANSWERED `7-1/R5`: synthesize both.**
6. **Where the knob sets live (AC 29).** Exported scene properties need no new shape; a new
   `Resource` class or a new `data/` subfolder is a codebase-shape decision for the operator.
   Asset folders: `assets/models/`, `assets/audio/`, `assets/art/` exist; any other new folder is
   the same question. **ANSWERED `7-1/R6`: a new presentation-only class and folder are allowed.**
   Measured: `6-1b`'s chargeup knobs are code constants (`_CHARGE_HOLD_KNOBS`,
   `animation_controller.gd:368`) and `TelegraphProfile` lives under `src/state/resources/`, so
   neither is a fitting home under R6.
7. **Boulder mode-cycle cosmetic suppression** (`deferred-work.md:529-531`, listed under `7-1` at
   `:566`) is not in the Scope table. In this story or `7-6`? **ANSWERED `7-1/R7`: `7-6`.**
8. **Skull decimation fallback:** if headless decimation to a few thousand triangles fails, the
   operator decimates in Blender (AC 31). **ANSWERED `7-1/R8`: confirmed; stop and report.**

### Guardrails (measured)

- **One tick loop (F1).** No `_physics_process` outside `match_runner.gd`. Effect timing rides
  tweens, particles or `_process` on actor-side nodes; `_process` is banned under `src/ui/`
  (`test_ui_layer_never_polls_per_frame`).
- **Read through the runner.** Every poll in the trigger map is a runner read handing plain values to
  a presentation node. `TelegraphController` stays under the cues-layer mutator ban
  (`test_cues_layer_never_calls_state_mutators`).
- **The bolt timing is a pinned contract** (`test_cast_presentation_live.gd`, `6-5c` AC 25): the new
  lightning must still arrive on the strike tick, and an interrupted cast still takes its bolt with it
  (`match_runner.gd:1309-1319`).
- **Fireball/Rocksling launch at the strike tick** (cast end), unlike Honed Bolt, whose bolt leaves at
  the raise (`cast_launch_seconds`, `animation_controller.gd:1020`). The new clips' release frames
  must land on cast end, not on the raise.
- **Audio today is non-positional:** every cue is an `AudioStreamPlayer` on the `CombatCues` bus
  (`default_bus_layout.tres:4`). Positional audio under split-screen is unproven in this repo.
- **Performance** (`project-context.md`, Performance Rules): no per-frame allocation in hot paths;
  `4-5` measured headroom (avg 4.14 / p95 7.52 ms) is the baseline, not a promise.
- **`.gitattributes`** marks only `*.fbx` and `*.png` binary; `.glb`, `.wav`, `.ogg`, `.jpg` rely on
  `text=auto` detection.
- **Reuse, do not re-invent:** `_tint_mesh_recursive` (`match_runner.gd:1868`, duplicates materials
  per instance), `TelegraphController._flat_material`, `_target_world_position`
  (`match_runner.gd:2343`), `_projectile_launch_position` (`:2746`), the existing `CastWarning` /
  `TargetConeActor` warning, the `on_orbs_changed` colour lookup (`telegraph_controller.gd:296-300`).
- **The `6-5b/R24` flake is still open** ("resources still in use at exit", `deferred-work.md:578-582`).
  New particle/texture resources in integration tests can widen it; `run_all.sh` prints full `-v`
  output when it appears (`7-T1/R3`) — report any occurrence, do not absorb it.

### Previous story (`7-T1`)

Tooling only, no presentation overlap. Carried: the flake above, and the reflection-derived guard
style (`7-T1/R4`) — a knob-set test (AC 29) should derive its row list from one source, not a second
hand-kept list.

### Files expected to change

- `src/main/match_runner.gd` — reads and pushes for each row; clip choice at the cast rising edge.
- `src/actors/hero/animation_controller.gd`, `telegraph_controller.gd`, `hero.tscn` — cast clips,
  hero-anchored effects and sounds.
- `src/actors/projectiles/*` and/or new actor scenes for the rock, fireball and skull looks;
  `src/actors/props/bolt_actor.gd` (lightning); `src/actors/minions/*` for minion-anchored effects
  (`unit_actor.tscn` and `totem_actor.tscn` collision unchanged).
- `assets/` — processed assets, credits; `assets/characters/paladin/paladin_anims.res`.
- `tools/` — clip-add and measurement tools on the existing precedents; audio trimming/synthesis.
- `test/integration/test_rig_clips.gd` (AC 26) and new tests (AC 17, 29).
- **NOT changed:** anything under `src/state/`, `project.godot`, `docs/playtest-log.md`.

### Project Context Rules

- HARD RULE state/visual separation — presentation reads, never decides (AC 4).
- No hardcoded tuning: knobs authored (AC 29); `cast_seconds` stays the authored source (AC 23).
- Text fit / legibility is the operator's at smoke, never machine-asserted (`PROC/R8`).
- Suite runs twice per pass (open, close), as two foreground calls with an explicit timeout; no
  backgrounding, no wakeups (`E6-R/R4`, `E6-R/R5`); one engine launch per tool call (`E6-C/R12`).
- Mutation proofs restore from an out-of-repo SHA256-verified copy, never `git checkout`.
- Edit tool first; on a failed match, python byte-replace or line-index splice, never PowerShell
  `-join`; invoke `python`, not `python3` (`E6-R/R6`).
- `docs/playtest-log.md` is the operator's alone (`E6-R/R7`).
- Docs and code never share a commit; ASCII commit messages via `git commit -F`.

### References

- Scope: operator browser session 2026-10-01 (recorded first in this story).
- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:330-360` (E7);
  `decision-log.md:12078-12094` (`E6-C/R9`-`R11`); `deferred-work.md:529-531`, `:558-571`.
- `docs/planning-artifacts/deck-1-spec.md` (card rules and amendments, esp. `:87-96`, `:100-155`,
  `:206-207`).
- `6-5b-corpses-and-own-minions.md:401` (tint failure); `6-5c` (cast, bolt timing);
  `6-5d` (Fireball, spell targeting); `6-5e` (Rocksling, Boom, Corpse Bomb, Boulder slow);
  `6-5f`/`6-5g` (Counterspell); `6-1d` (honest geometry); `4-3d` (strike alignment); `5-0c`
  (projectile look); `4-5` (frame-time baseline).
- Code: as cited inline in the trigger map, the Fireball and Boulder findings and the clip library.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| date | change |
|---|---|
| 2026-10-02 | Operator review: rulings `7-1/R1`-`R9` applied in place (Drain/Aura green, shot-ending reads, returned-flash copy, generic-cue fallback, two synthesized slots, knob home, Boulder HUD to 7-6, decimation fallback, AC 35 hit-shape pin); promoted `authored` -> `ready-for-dev` (`CFG/R4`, operator-authorized). |
| 2026-10-02 | Authored by `gds-create-story` against `e93dbee`: scope from the operator's 2026-10-01 browser session; trigger map, Fireball radius, Boulder read path, asset numbers, sound first-picks and clip library measured. Status `authored`; not promoted. |
