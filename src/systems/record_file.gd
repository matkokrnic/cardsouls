class_name RecordFile
extends RefCounted

## Story 3-0d (X5, AC 4 / AC 5): `user://` PERSISTENCE FOR AN IntentRecorder RECORD — the half
## `3-0c` deliberately did not ship ("Serialisation, `user://` persistence and the operator
## surface are `3-0d`'s", intent_recorder.gd:32-33).
##
## A SIBLING, NOT A RECORDER METHOD, AND THAT IS STRUCTURAL. IntentRecorder is CLOCK-FREE AND
## CONTENT-BLIND BY CONSTRUCTION — no `user://` path, no ResourceLoader, no service — and that
## property is machine-checked by test_intent_recorder.gd::
## test_no_recorder_behaviour_is_gated_behind_a_flag_or_a_live_service. File I/O therefore lands
## HERE. The recorder gains no new capture channel (AC 3) and no knowledge that files exist.
##
## IT TOUCHES ONLY THE RECORDER'S PUBLIC API — the replay-side reads to serialise, the capture
## channels to rebuild. That is the `_without_contacts` pattern of
## test/integration/test_replay_contacts.gd generalised to every channel, and it is what makes a
## loaded record a GENUINE record: it was built by the same capture calls a live match makes, so
## nothing can round-trip into a shape live play could not have produced.
##
## THE FORMAT IS DELIBERATELY UNPINNED EXCEPT FOR ITS VERSION INT (`3-0d/R7`). Byte layout, key
## naming and extension are free to change under a story that needs them; what IS pinned is the
## ROUND TRIP (AC 4) and FORMAT_VERSION with a REFUSAL CARRYING A REASON when it does not match
## (AC 5) — which is what makes schema evolution safe without freezing a shape that has exactly
## one consumer today.
##
## EVERY REFUSAL CARRIES A REASON ~~, AND THAT IS NOW TRUE OF EVERY PATH~~ (`3-0d/R15`). **THE
## STRUCK CLAUSE IS FALSE AND IS RETIRED AT `3-0d/R25`** — five inputs still refuse with an EMPTY
## reason; see THE RESIDUE at the end of this block, which is now where this class's actual
## boundary is written down. The review of
## this story found the one path where it was not: a file carrying a matching version but a
## TRUNCATED body reached the rebuild, failed inside it, and came back as
## `{"record": null, "error": ""}` — a refusal with an EMPTY reason, which a caller testing
## `error != ""` reads as SUCCESS. The required keys are validated BEFORE anything is rebuilt.
##
## ...AND THAT FIX WAS ITSELF INCOMPLETE, CLOSED AT `3-0d/R21`. Presence is not enough:
## `Dictionary.has()` is TRUE for a key whose value is `null` and says nothing about type, so three
## more inputs still reached the rebuild and still came back with an empty reason — required keys
## present but carrying WRONG TYPES, `null` under `reload_events`, `null` under `intents`. Each
## required key's TYPE is now validated before the rebuild, and the refusal names the key and what
## was found in it. See REQUIRED_KEYS, which is a key -> type map for exactly this reason.
##
## THE RESIDUE, STATED RATHER THAN PRETENDED AWAY (`3-0d/R25`). Twice now this docstring has
## claimed TOTALITY over refusal reasons and twice a narrower set of files has falsified it. It
## stops claiming totality. **WHAT THE CODE CARRIES:** each required key's TOP-LEVEL TYPE is
## validated before the rebuild (REQUIRED_KEYS, a key -> type map), and a file failing that is
## refused with a reason naming the key and what was found in it. **WHAT IT DOES NOT CARRY:**
## NESTED and CROSS-KEY consistency. Element types INSIDE the required containers, and array
## lengths measured AGAINST `tick_count`, are not validated at all — such a file still reaches
## `_from_dictionary()`, still dies inside it, and still comes back as
## `{"record": null, "error": ""}`. FIVE MEASURED at `3-0d/R25`, every one returning an empty
## reason: `intents` as an Array of DICTIONARIES; `intents` SHORTER than `tick_count`;
## `camera_pushes` values that are INTS; `contacts` values that are ARRAYS OF INTS; `tick_count`
## INFLATED past the intents array.
##
## NESTED VALIDATION IS DELIBERATELY NOT BUILT (`3-0d/R25`), and that is the ruling rather than an
## omission: it is a third round of the same widening for marginal benefit on a format with
## exactly one writer, and the lesson `3-0d/R20` already paid for is that the boundary gets WRITTEN
## DOWN instead of chased. **CONSEQUENCE FOR CALLERS, stated once so it is not re-derived:** test
## `result["record"] == null`, NEVER `error != ""` — the reason is a message for a human, not the
## verdict. MEASURED at `3-0d/R25` — all three shipped callers already do: `replay_file.gd:43` and
## `test_record_save_control.gd:191` branch on `result["record"] == null`, and
## `test/state/test_record_file.gd` asserts the record before it reads any reason.
##
## RECORDS GO UNDER `user://`, AND THE API SAYS SO (`3-0d/R16`), BY NORMALISATION (`3-0d/R22`).
## That claim used to be true only of `path_for()`; `save_record` accepted any path and would
## happily write into the repo tree. The first fix was a bare `begins_with("user://")`, which
## `user://../../…` satisfies while escaping the directory entirely — proven by writing a record
## into the project root. The path is now RESOLVED and required to land inside the `user://`
## directory; see `_outside_user_directory`.
##
## BINARY `store_var`, NOT JSON. The stream carries Basis, Vector2 and StringName values and the
## int/float distinction, none of which JSON round-trips. MEASURED on Godot 4.6.3 at this pass:
## store_var/get_var returns Basis and Vector2 equal, StringName keys still TYPE_STRING_NAME, and
## ints still ints. A text format would have needed a per-type re-parse for no gain — the file is
## an operator artefact handed to the AC 8 verifier, never something a human edits.

## AC 5: bump this the moment the shape below changes in a way an older file cannot satisfy. A
## file carrying any other value is REFUSED with a reason, never replayed on a guess.
## STORY 4-1 (`4-1/R1`): BUMPED 1 -> 2. The shape below gained a required `effects` key (the third
## content channel), and a v1 file cannot satisfy it -- it carries no effects at all, so replaying
## one would summon nothing where the recorded match summoned units. That is exactly the "an older
## file cannot satisfy it" condition this constant exists for.
##
## NO MIGRATION SHIM IS BUILT, AND THAT IS THE RULING RATHER THAN AN OMISSION (`4-1/R1`). A v1
## record is REFUSED WITH A REASON by the version check in load_record(), which is this class's
## own documented contract for every non-matching version. Records are DEBUG ARTEFACTS with exactly
## one writer; a shim that back-filled an empty effects map would be speculative machinery whose
## only output is a replay that silently diverges from the match it claims to reproduce.
## STORY 4-3a (`4-3a/R10`) BUMPS THIS TO 3, and the reason is a payload SHAPE change rather than a
## new channel. The contact fact's target widened from a bare slot to a `[slot, index]` ADDRESS
## (AC 3), so the recorded contact row grew from four positional elements to five. A v2 file carries
## no target-index element; rebuilding one by assuming -1 would silently replay a UNIT hit as a HERO
## hit -- a replay that diverges from the match it claims to reproduce, which is exactly what the
## version check exists to refuse. No migration shim, for the `4-1/R1` reason directly above: a v2
## record is REFUSED WITH A REASON, and that refusal is this class's documented contract.
##
## The channel SET is unchanged -- no new capture channel, `push_contact` still the sole intake --
## so REQUIRED_KEYS below does not move and `_resource_values` is untouched.
## STORY 4-3b (`4-3b/R21`) BUMPS THIS TO 4, and it is again a payload SHAPE change rather than a new
## channel -- the third bump in the same family, for the third time on the contact row. The fact's
## ATTACKER widened from a bare slot to a `[slot, index]` ADDRESS (AC 3) and the fact gained a KIND
## marker separating a REACH PROBE from a STRIKE (AC 13), so the recorded row grew from five
## positional elements to seven. A v3 file carries neither: rebuilding the attacker index by assuming
## -1 would silently replay a MINION's swing as its owner HERO's, and rebuilding the marker by
## assuming STRIKE would replay a harmless reach probe as a landed hit that deals damage. Both are
## replays that diverge from the match they claim to reproduce, which is exactly what the version
## check exists to refuse. HARD REJECTION, NO SHIM, for the `4-1/R1` reason above.
##
## The channel SET is unchanged and this story MEASURED it rather than assuming (its own Open
## Question 2 left the bump conditional on the answer): the marker RIDES THE EXISTING ROW and
## `push_contact` gained a parameter rather than a sibling method, so REQUIRED_KEYS below does not
## move and `_resource_values` is untouched.
##
## STORY 4-4 (`4-4/R15`) BUMPS THIS TO 5, and this one is neither a new channel nor a contact-row
## shape change -- it is the RECORDED BALANCE CONFIG's own shape. `4-4` gave `BalanceConfig` an
## `Array[UnitKindProfile] unit_kinds`, and `_resource_values` below was a ONE-LEVEL capture: it
## read the property by value and handed the live `Resource` references straight to `store_var`,
## which encodes each of them as an `EncodedObjectAsID` because `full_objects` defaults to false.
## On load, assigning that untyped array of ids into the typed `Array[UnitKindProfile]` property
## is REJECTED BY THE ENGINE WITH NOTHING PRINTED, so the field stayed at its `[]` default --
## MEASURED, not theorised: `rebuilt unit_kinds size = 0` against the shipped `.tres`.
##
## The consequence is the exact condition every bump above exists to refuse, in its worst form: a
## record loaded from disk replays with NO UNIT KINDS AT ALL -- `kind_at()` null everywhere,
## `kind_index_of()` -> `NO_KIND_INDEX`, so every summon puts a unit on the board with no speed, no
## hp, no damage, no attack and no priority. `_resource_values` / `_rebuilt` now RECURSE (see
## NESTED_CLASS_KEY), which fixes the post-4-4 half; the bump fixes the PRE-4-4 half. A v4 record
## carries the retired flat keys (`unit_max_hp`, `unit_damage_per_hit`) and no `unit_kinds` at all,
## so rebuilding one would set dead keys onto nothing and replay every unit as kindless. HARD
## REJECTION, NO SHIM, for the `4-1/R1` reason above.
## STORY 4-6 BUMPS 5 -> 6 (AC 14), and the bump is a MEASUREMENT rather than a habit: AC 14 asks
## whether the retarget result fits inside the existing `InputIntent` / recorded-fact channels, and
## it does not. The only unoccupied intent field was `aim`, whose resting `Vector2.ZERO` is a VALID
## `[slot, index]` address (slot 0's unit 0) -- so repurposing it has no "no retarget" sentinel
## without moving its resting value, and moving that makes every v5 record decode a resting `aim`
## as a live retarget onto `[0, 0]`. A new element is needed, so the format bumps, and it carries
## THREE shape changes at once: `aim` DELETED, `retarget_slot`/`retarget_index` ADDED, and the new
## per-tick `lock_pushes` channel required beside `camera_pushes`. A v5 record has none of them,
## and replaying one against target-derived facing would leave every hero facing its construction
## default while the recording's heroes tracked their targets. HARD REJECTION, NO SHIM, the
## `4-3a/R10` / `4-3b/R21` / `4-4/R15` discipline unbroken.
## STORY 5-2 BUMPS 6 -> 7, and it is a NEW CAPTURE CHANNEL rather than a payload shape change -- the
## `4-1/R1` shape of bump, not the three contact-row ones. `inject_card_colors` is MatchState's
## TENTH intake and the FOURTH content channel (`5-2/R1`), and it ships with its
## `capture_inject_card_colors` channel and its `colors` key below. A v6 file carries neither: it
## has no colours at all, and rebuilding them by assuming one would replay every unblockable
## telegraph in the wrong colour -- a value that reaches the HASHED per-player `telegraph` key
## (`player_state.gd`), so the replay diverges from the match it claims to reproduce. HARD
## REJECTION, NO SHIM, the `4-1/R1` discipline unbroken.
##
## THE OTHER HALF OF 5-2 FORCES NOTHING, and the story asked for that to be MEASURED rather than
## assumed (its AC 23). The two new CHARGE-REACH contact kinds ride the EXISTING seven-element
## contact row as new VALUES of the `kind` element `4-3b` already added, so the row shape is
## untouched, `capture_push_contact` is untouched, and `REQUIRED_KEYS`'s `contacts` entry does not
## move. Had the reach answer needed an eighth row element, THAT would have been the bump; it did
## not, and the channel is what did.
##
## STORY 6-1 BUMPS 7 -> 8, AND THE SHAPE FORCED NOTHING -- the SEMANTICS did (`6-1/R4`). The new
## `card_cast` held key round-trips with ZERO serialization edits, because `copy_intent`
## (intent_recorder.gd) and `_intent_from_values` below both walk `held`/`pressed` by whatever keys
## are present, with no enumerated action list to extend. MEASURED: the round-trip test alone says
## "no bump needed", and that answer is not the question.
##
## THE QUESTION IS SILENT DIVERGENCE. A v7 recording of a mode ② cast carries no `card_cast` held
## key, so under the build of the day the release arm read that key false on the tick after the commit
## and the chargeup that ORIGINALLY LANDED replayed as an instant paid feint -- loaded without complaint,
## because a matching version number is the only thing the loader checks. That is exactly the
## silently-wrong replay the exact-match refusal at `:365-368` exists to make impossible, so v7 is
## rejected HARD rather than migrated: an unloadable record is a correct answer, a divergent one is
## not. (The `5 -> 6` bump directly above took this same reasoning from the resting-`aim` case.)
##
## STORY 6-2 BUMPS 8 -> 9, and it is a NEW CAPTURE CHANNEL -- the `5-2` shape of bump, not `6-1`'s
## semantics one. `inject_pitch_costs` is MatchState's ELEVENTH intake and the FIFTH content channel
## (AC 16), shipping with its `capture_inject_pitch_costs` channel and its `pitch_costs` key below. A v8
## file carries neither: replaying one would find no pitch cost for any card, so every staging the
## recorded match performed would REFUSE on replay -- no mana spent, nothing in the zone -- diverging on
## the hashed `"pitch"` key and the staging player's mana. HARD REJECTION, NO SHIM, the `4-1/R1`
## discipline unbroken. The intent SHAPE forced nothing: a stage is `card_mode == PITCH` on the existing
## card fields.
##
## STORY 6-3a BUMPS 9 -> 10, and it is an INTENT SHAPE change -- the `4-6` (AC 14) shape of bump.
## `InputIntent` gains a tenth field, `card_activate`, which no v9 record carries in any intent. A v9 file
## is REFUSED rather than defaulted: it cannot hold an activation, so defaulting would be harmless for
## that file today, but the per-intent field check (`REQUIRED_INTENT_FIELDS`) exists precisely so a
## dropped field is never silently read as its resting value -- here that would replay every recorded
## activation as a stage attempt. HARD REJECTION, NO SHIM.
##
## STORY 6-7 BUMPS 10 -> 11, on the `6-1` SILENT-DIVERGENCE reasoning verbatim, not an intent-shape
## bump (`&"run"` round-trips with zero serialization edits, exactly as `card_cast` did -- `held` is
## walked by whatever keys are present, `6-7/R12`). A v10 recording carries no `run` held key AND no
## `walk_speed` value; `_rebuilt` (below) sets only keys present in the file, so a replayed v10
## record's `walk_speed` stays at `BalanceConfig`'s zero default and every hero in that replay moves
## at speed 0 from the tick gait selection lands -- loaded without complaint, silently wrong, exactly
## the case this constant exists to prevent. v10 is refused HARD rather than migrated.
##
## STORY 6-9 BUMPS 11 -> 12, on the `6-1` SILENT-DIVERGENCE reasoning once more -- and this story
## REMOVES a held key rather than adding one, so it forces even less of the shape than `6-7` did.
## Mode ② became CLICK-TO-COMMIT: the press spends the card and the stamina and the attack carries
## to its landing, the `card_cast` held key is written by no controller any more, and the
## early-release arm that read it is deleted. Nothing in the serialization changed at all.
##
## THE SEMANTICS DID. A v11 recording of a mode ② cast whose `card_cast` held key went false
## mid-chargeup recorded a FEINT: an attack that resolved no landing, dealt no damage and left the
## defender's window unanswered. Under this build no arm reads that key, so the identical intent
## stream replays as a full attack carried to its landing -- damage the recorded match never dealt,
## a knockdown it never suffered, loaded without complaint because a matching version number is all
## the loader checks. That is the silently-wrong replay the exact-match refusal at `:365-368` exists
## to make impossible, so v11 is rejected HARD rather than migrated: an unloadable record is a
## correct answer, a divergent one is not.
##
## STORY 6-5a BUMPS 12 -> 13 (AC 6), for TWO causes named separately. (1) A NEW REQUIRED KEY: the sixth
## content channel, `pitch_effects` -- a v12 file carries no pitch effects, so every activation it
## recorded would replay as a no-op. (2) CHANGED RESOLUTION SEMANTICS: buff ids now APPLY, so a v12
## recording whose card effects happened to carry one of those ids would replay a buff the recorded match
## never applied. Either alone is the silently-wrong replay the exact-match refusal exists to prevent.
## Not the `card_cast_resolved` arity (a signal is not recorded) and not the new hashed state (a record
## carries no hash). v12 is refused HARD, no migration.
##
## STORY 6-5b BUMPS 13 -> 14 (AC 26), for ONE MEASURED CAUSE: a NEW REQUIRED KEY, `drain_pushes` --
## the seventh capture channel, carrying the board index Drain's facing rule selected on each tick.
## A v13 file carries no drain channel at all, so every Drain it recorded would replay through
## `MatchState._apply_drain`'s no-fact degrade and sacrifice the board's LOWEST living minion instead
## of the one the player was facing -- a different minion dead, a different `unit_hp` /
## `unit_corpse_ticks` hash on that tick, and a different board for every later Raise Dead. Loaded
## without complaint, silently wrong: the exact case this constant exists to prevent.
##
## THE CORPSE STATE IS NOT A SECOND CAUSE, and that is measured rather than waved past: a record
## carries INPUTS and CONTENT, never a hash and never a snapshot, so three new hashed board keys force
## nothing here. Neither does the effect authoring -- the four newly-authored numbers ride the EXISTING
## `effects` / `pitch_effects` channels as flat exports (`_card_effects` rebuilds every script property
## generically), so no row shape and no key set moves for them. v13 is refused HARD, no migration.
##
## STORY 6-5c BUMPS 14 -> 15 (AC 23), for TWO MEASURED CAUSES, and the SECOND is the one that makes
## a migration unsafe.
##
## (1) THE RECORDED PER-EFFECT ROW SHAPE MOVES. `CardEffect` gains SEVEN flat exports, and
## `_resource_values` captures EVERY script variable off `get_property_list()` regardless of
## whether it holds its default -- so every row in the `effects` and `pitch_effects` channels
## gains seven keys. THIS CORRECTS 6-5b's NOTE DIRECTLY ABOVE, which said new flat exports move `no
## row shape`: that was true of `REQUIRED_KEYS` (the CHANNEL key set, which is again unmoved here)
## and false of the row inside it. Measured, not inherited.
##
## (2) CHANGED RESOLUTION SEMANTICS, the 6-5a cause repeated and the reason v14 is refused rather
## than migrated. `honed_bolt` has left `DEFERRED_EFFECT_OWNERS` and now CASTS. A v14 file's
## effect rows carry no `cast_seconds`, `damage_amount`, `stun_seconds` or `root_seconds`, so
## `_rebuilt` would leave a rebuilt Honed Bolt at its constructor defaults -- and this build would
## then start a real 0.8 s cast that strikes for `damage_amount` 0.0 and writes no stun and no root,
## where the recorded match resolved a pure no-op. Different hp, a different hash from that tick on,
## loaded without complaint. Filling the gap with defaults is exactly the silently-wrong replay the
## exact-match refusal exists to prevent, so v14 is refused HARD, no migration.
##
## THE NEW HASHED STATE IS NOT A THIRD CAUSE, on 6-5b's own measured reasoning: a record carries
## INPUTS and CONTENT, never a hash and never a snapshot, so the `cast` / `root` / `stun_is_bolt`
## keys force nothing here. Neither is a new intake -- this story pushes no new runner fact.
##
## STORY 6-5d BUMPS 15 -> 16 (AC 31), FOR ONE MEASURED CAUSE, AND THE STORY'S OWN STATED CAUSE IS
## CORRECTED RATHER THAN REPEATED.
##
## (1) THE RECORDED PER-EFFECT ROW SHAPE MOVES, which is 6-5c's cause (1) recurring for the same
## mechanism: `CardEffect` gains EIGHT flat exports (`mana_cap`, `damage_per_mana` and the five
## `ProjectileProfile` mirror fields), and `_resource_values` captures EVERY script variable off
## `get_property_list()` regardless of whether it holds its default -- so every row in the `effects` and
## `pitch_effects` channels gains eight keys. `REQUIRED_KEYS` (the CHANNEL key set) is again unmoved.
## MEASURED, not inherited: pinned by `test_record_file.gd`'s row-shape assertion, which reads the new
## field names out of an actually-saved record rather than asserting the count.
##
## (2) AC 31'S STATED REASON DOES NOT APPLY, AND SAYING SO IS THE HONEST RECORD. The AC reads "recorded
## content gains fields whose defaults would replay a Fireball as a no-op". A v15 file CANNOT CONTAIN A
## FIREBALL -- the effect did not exist and no card referenced it -- so there is no recorded Fireball for
## a default to misresolve. Nor does the PAIRING SWAP create one: a record carries its own injected
## content, so a v15 file replays Bloodhound Step's pitch as the `bloodlust` BUFF it was recorded with,
## self-consistently, and the new build's variable-cost staging reads `mana_cap` 0.0 off that rebuilt
## buff and takes the unchanged fixed-price path. The bump rests on cause (1) alone, which is sufficient
## on its own and is the same cause that carried 14 -> 15.
##
## v15 IS REFUSED HARD, NO MIGRATION AND NO SHIM, for the reason the exact-match refusal exists: filling
## eight absent keys with constructor defaults is precisely the silently-wrong replay this constant
## prevents, and a shim would have to guess which absent field meant "not authored" and which meant "the
## authoring predates the field".
## Story 6-5e (AC 39): 16 -> 17, WITH THE HARD REFUSAL OF A v16 FILE UNCHANGED.
##
## WHAT CHANGES IN THE RECORDED SHAPE: `_resource_values` captures every script property off
## `get_property_list()`, so the two new `CardEffect` exports (`boulders_per_cast`,
## `boulder_interval_seconds`) and the new `BalanceConfig` export (`boulder_slow_per_boulder`) all ride the
## `effects` / `pitch_effects` / `balance` channels for free -- which is exactly the problem. A v16 file
## CARRIES NONE OF THEM, so a replay of it would rebuild `rocksling` with `boulders_per_cast = 0` and replay
## every Rocksling cast as a cast that fires NOTHING: no stones, no Boulders, and therefore no Boom worth
## activating and a silently different final hash. That is a silent divergence, which is what this constant
## exists to refuse loudly -- the `6-5a` 12 -> 13 and `6-5b` 13 -> 14 argument verbatim, third time.
##
## Story 6-5f (AC 29): 17 -> 18, WITH THE HARD REFUSAL OF A v17 FILE UNCHANGED.
##
## WHAT CHANGES IN THE RECORDED SHAPE, and the new `CardEffect` export is NOT the reason. `_resource_values`
## captures every script property, so `counter_window_seconds` rides the `effects` / `pitch_effects` channels
## for free -- and its default is 0.0 ("no limit"), which is also the authored value, so a v17 file rebuilt
## without it would get the identical window. That half of the usual argument does not apply here.
##
## THE DIVERGENCE IS BEHAVIOURAL, IN TWO PLACES, AND BOTH ARE SILENT. (1) `counterspell` was a DEFERRED NO-OP
## through v17: a recorded match in which a player activated Honed Bolt's pitch spent the orbs and did
## nothing, and replaying that same intent stream against this code REVERSES a card -- different hp, different
## board, different hand, different final hash, with nothing in the file to warn anyone. (2) A Mode ① press on
## a Boulder used to overwrite `last_resolved_card` and no longer does (AC 8, `6-5f/R7`), so a v17 record whose
## sequence contains a Boulder clear replays with a different Counterspell target from the one it was recorded
## with. Either is exactly the class of silent divergence this constant exists to refuse loudly -- the
## `6-5a` 12 -> 13, `6-5b` 13 -> 14 and `6-5e` 16 -> 17 argument, fourth time, and the first time the cause is
## a behaviour change rather than a missing authored field.
##
## Story 6-5g (AC 27): 18 -> 19, WITH THE HARD REFUSAL OF A v18 FILE UNCHANGED.
##
## THE CAUSE IS BEHAVIOURAL AGAIN, AND IT IS THE SAME CLASS AS 17 -> 18's FIRST HALF: through v18 a
## Counterspell against a resolution of any of the SEVEN timed/in-flight cards (Vampiric Aura, Bloodhound
## Step, Frostbite, Honed Bolt, Fireball, Rocksling, Corpse Bomb) was REFUSED as no-target -- the `6-5f/R37`
## interim rule -- and that refusal left the card staged, the orbs unspent and the match otherwise untouched.
## The SAME recorded intent stream replayed against this build ACTIVATES: the orbs go, the card leaves the
## zone, a running buff ends or a cast is interrupted or hp is refunded, and the final hash differs. Nothing
## in a v18 file warns anyone, which is precisely the silent divergence this constant exists to refuse
## loudly -- the `6-5a` 12 -> 13, `6-5b` 13 -> 14, `6-5e` 16 -> 17 and `6-5f` 17 -> 18 argument, fifth time.
##
## NO NEW RECORDED SHAPE IS PART OF IT, and saying so is the honest record: this story adds no `CardEffect`
## export, no `BalanceConfig` field and no intake channel, so the `effects` / `pitch_effects` / `balance`
## channels are bit-identical in shape to v18's. The bump rests on the behaviour change alone, which is
## sufficient on its own.
##
## NOR IS THE GOLDEN A REASON. The golden hash did NOT move for this story (MEASURED -- the golden fixture
## authors every effect id as a `summon_*` and never stages Counterspell, so no new reversal kind is ever
## written in its recorded sequence), and a record carries INPUTS and CONTENT, never a hash: the two are
## independent, exactly as `6-5c`'s NON-MOVER note says from the other direction.
##
## NO SHIM, on this file's standing posture: older records are refused with a reason, never migrated.
const FORMAT_VERSION := 19

## AC 7: the `user://` naming the SAVE control writes to. INDEXED rather than timestamped, and
## that is deliberate on both sides: the index makes the path a test can NAME in advance
## (`path_for(1)`), and two presses leave two files side by side, so "the second save is longer
## than the first" is directly observable rather than a remembered file size. **`3-0d/R30`: THAT
## GUARANTEE USED TO HOLD ONLY WITHIN ONE SESSION**, because the caller's own index started at 0
## every session and `path_for` alone names a path without checking whether it is occupied — a
## fresh session's first SAVE silently overwrote whatever a PRIOR session had already written at
## `path_for(1)`. See `first_free_index`, which is what makes the guarantee hold ACROSS sessions
## too, by asking the filesystem rather than trusting a counter that has no memory of a prior run.
const PATH_PREFIX := "user://cardsouls_record_"
const PATH_SUFFIX := ".rec"

## AC 5 / `3-0d/R15`: the keys `_to_dictionary` writes BESIDE the version, and therefore the keys
## `_from_dictionary` may read. Validated BEFORE any rebuild so a truncated or foreign file is
## REFUSED WITH A REASON NAMING WHAT IS MISSING, instead of dying inside the rebuild and returning
## a null record with an EMPTY error — which a caller testing `error != ""` reads as SUCCESS, the
## exact contradiction of this class's own documented contract that the review found.
##
## `format_version` is deliberately NOT a member: it is validated FIRST and on its own, because
## the version is what decides which key set is even expected. A future version 2 is free to carry
## a different set; it is refused by the version check long before it reaches here.
##
## DERIVED, NOT TRANSCRIBED: test_record_file.gd asserts this key set equals the key set an actual
## saved file carries minus `format_version`, so the two cannot drift apart.
##
## KEY -> EXPECTED TYPE, NOT A BARE KEY LIST (`3-0d/R21`). The presence check alone was not enough,
## and the reason is a property of `Dictionary.has()` rather than an oversight: **`has(key)` is TRUE
## for a key whose value is `null`, and says nothing whatever about type.** Three inputs therefore
## reached `_from_dictionary()` and came back as `{"record": null, "error": ""}` — the exact
## empty-reason refusal `3-0d/R15` was raised to close, still open on a narrower set of files:
## required keys present but carrying the WRONG TYPES, `null` under `reload_events`, and `null`
## under `intents`. Each key's type is checked here, before anything is rebuilt, and the refusal
## names the key and what was found in it.
const REQUIRED_KEYS: Dictionary[String, int] = {
	"seed": TYPE_INT,
	"reload_events": TYPE_ARRAY,
	"flags": TYPE_DICTIONARY,
	"content_order": TYPE_ARRAY,
	"deck": TYPE_ARRAY,
	"costs": TYPE_DICTIONARY,
	"tick_count": TYPE_INT,
	"intents": TYPE_ARRAY,
	"camera_pushes": TYPE_DICTIONARY,
	"contacts": TYPE_DICTIONARY,
	# Story 4-6 (AC 2/AC 14): the per-tick LOCK-DIRECTION channel, required from FORMAT_VERSION 6
	# onward. Its arrival IS half the version bump -- a v5 file lacks this key, and is refused by
	# the version check long before this map is consulted, exactly as `effects` was at v2.
	"lock_pushes": TYPE_DICTIONARY,
	# Story 6-5b (AC 18/AC 26): the per-tick DRAIN-TARGET channel, required from FORMAT_VERSION 14
	# onward. Its arrival IS the version bump -- a v13 file lacks this key and is refused by the version
	# check long before this map is consulted, exactly as `lock_pushes` was at v6.
	"drain_pushes": TYPE_DICTIONARY,
	# Story 4-1 (`4-1/R1`): the third content channel, required from FORMAT_VERSION 2 onward. Its
	# arrival IS the version bump -- a v1 file lacks this key, and is refused by the version check
	# long before this map is consulted.
	"effects": TYPE_DICTIONARY,
	# Story 5-2 (`5-2/R1`): the FOURTH content channel, required from FORMAT_VERSION 7 onward. Its
	# arrival IS the version bump -- a v6 file lacks this key, and is refused by the version check
	# long before this map is consulted, exactly as `effects` was at v2 and `lock_pushes` at v6.
	"colors": TYPE_DICTIONARY,
	# Story 6-2 (AC 16): the FIFTH content channel, required from FORMAT_VERSION 9 onward. Its arrival IS
	# the version bump -- a v8 file lacks this key, and is refused by the version check long before this
	# map is consulted, exactly as `colors` was at v7.
	"pitch_costs": TYPE_DICTIONARY,
	# Story 6-5a (AC 6): the SIXTH content channel, required from FORMAT_VERSION 13 onward -- a v12 file
	# lacks this key and is refused by the version check first, exactly as `pitch_costs` was at v9.
	"pitch_effects": TYPE_DICTIONARY,
}

## Story 5-1a (AC 4): the POSITIONAL type signature of one `lock_pushes` entry, in the order
## `_from_dictionary` dereferences it — `int(push[0])`, `push[1] as Vector2`. A list rather than
## two named constants so the arity and the types come from ONE place: a third element added to
## the pair changes this line and the check follows.
const LOCK_PUSH_TYPES: Array[int] = [TYPE_INT, TYPE_VECTOR2]

## Story 5-1a (AC 5, `5-1a/R12`): the per-intent fields validated before the rebuild, keyed to the
## type each is read back as. NOT part of `REQUIRED_KEYS` and deliberately not added to it — these
## live INSIDE each `intents` array element (`_intent_values`), not at the top level, so
## `REQUIRED_KEYS` is neither widened nor consulted for them and AC 7 holds.
##
## The scope was exactly finding L8's two fields (`5-1a/R6`). `move_dir`, `pressed`, `held`,
## `debug_reset`, `card_slot`, `card_mode` and `card_commit` carry the identical unguarded access
## and are deliberately NOT validated here.
##
## Story 6-3a (AC 4) WIDENS THAT SCOPE BY ONE FIELD, deliberately: `card_activate` decides which state
## mutation a PITCH commit performs (activate or stage), the way the retarget pair decides a retarget,
## and a dropped bool read back as its resting `false` would replay every activation as a stage.
const REQUIRED_INTENT_FIELDS: Dictionary[String, int] = {
	"retarget_slot": TYPE_INT,
	"retarget_index": TYPE_INT,
	"card_activate": TYPE_BOOL,
}

## `3-0d/R16`: the ONE thing a save path must be. The class's own docstring and AC 7 both assert
## records go to `user://`; before this guard that was true only of `path_for()`, and the API
## accepted any path — proven at the review by writing a record into the repo root. Now the API
## carries the claim.
const REQUIRED_PATH_PREFIX := "user://"


static func path_for(index: int) -> String:
	return "%s%d%s" % [PATH_PREFIX, index, PATH_SUFFIX]


## `3-0d/R30`: THE INDEX A CALLER SHOULD ACTUALLY WRITE TO, NOT MERELY NAME. `path_for(index)`
## alone names a path; it says nothing about whether that path is already occupied, and a caller
## that increments its own counter from 0 EVERY SESSION collides with whatever a PRIOR session
## already wrote at `path_for(1)` — **this happened live, to the operator**: a new session's first
## SAVE wrote `cardsouls_record_1.rec` again and silently destroyed the only recording in which
## the contact channel had ever been exercised live. Returns the first index >= `start` whose
## `path_for(index)` does not already exist on disk, so a caller that always asks before writing
## can never clobber a file that is there — not within a session, not across sessions, not after a
## crash, because the answer comes from the FILESYSTEM, never from in-memory counter state.
static func first_free_index(start: int) -> int:
	var index := start
	while FileAccess.file_exists(path_for(index)):
		index += 1
	return index


## Writes `record` to `path`. Returns "" on success, or the REASON it was refused — never an
## Invariant.check: a save is an operator action on whatever state the session happens to be in,
## and the two ways it can legitimately have nothing to write (no record, or a replay's
## deliberately empty tap) are conditions to report, not programming errors.
static func save_record(record: IntentRecorder, path: String) -> String:
	if record == null:
		return "there is no record to save"
	var outside := _outside_user_directory(path)
	if outside != "":
		return outside
	if not record.has_complete_match_start():
		return ("refusing to save a malformed record — missing %s"
				% ", ".join(record.missing_match_start_channels()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
	file.store_var(_to_dictionary(record))
	file.close()
	return ""


## Loads a record from `path`. Returns {"record": IntentRecorder, "error": ""} on success, or
## {"record": null, "error": <reason>} — the REFUSAL half of AC 5. A Dictionary result rather
## than a null-plus-last_error() pair so the reason travels WITH the failure and the loader keeps
## no static state between calls.
static func load_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _refused("no record file at %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused("cannot open %s for reading (error %d)" % [path, FileAccess.get_open_error()])
	var raw: Variant = file.get_var()
	file.close()
	if typeof(raw) != TYPE_DICTIONARY:
		return _refused("%s is not a CardSouls record (expected a Dictionary, found %s)"
				% [path, type_string(typeof(raw))])
	var data: Dictionary = raw
	if not data.has("format_version"):
		return _refused("%s carries no format version — it is not a CardSouls record" % path)
	var version := int(data["format_version"])
	if version != FORMAT_VERSION:
		return _refused(("record format version %d does not match this build's %d — refusing to "
				+ "replay %s rather than guessing at a shape it may not carry")
						% [version, FORMAT_VERSION, path])
	# `3-0d/R15`: EVERY key the rebuild reads is checked BEFORE the rebuild runs. A file carrying a
	# matching version but a truncated body used to reach _from_dictionary(), fail inside it, and
	# come back as {"record": null, "error": ""} — a refusal with NO reason, which a caller testing
	# `error != ""` reads as success. A refusal always carries its reason now, naming the keys.
	var missing: Array[String] = []
	for key in REQUIRED_KEYS:
		if not data.has(key):
			missing.append(key)
	if not missing.is_empty():
		return _refused(("%s carries format version %d but is missing %s — it is truncated or was "
				+ "not written by this class") % [path, version, ", ".join(missing)])
	# `3-0d/R21`: PRESENCE IS NOT ENOUGH, and the gap is `has()`'s own semantics —
	# it is TRUE for a key whose value is `null` and says nothing about type. A file with the right
	# keys carrying the wrong values got past the loop above, died inside the rebuild, and came back
	# as a refusal with an EMPTY error, which is the very thing `3-0d/R15` was raised to close.
	var wrong: Array[String] = []
	for key in REQUIRED_KEYS:
		var found := typeof(data[key])
		if found != REQUIRED_KEYS[key]:
			wrong.append("%s (expected %s, found %s)"
					% [key, type_string(REQUIRED_KEYS[key]), type_string(found)])
	if not wrong.is_empty():
		return _refused(("%s carries format version %d but %s — it was not written by this class, "
				+ "or was written by a build whose shape this one cannot read")
						% [path, version, ", ".join(wrong)])
	# Story 5-1a (AC 4/AC 5, `5-1a/R1`/`5-1a/R10`): the same discipline ONE LEVEL DEEPER. The two
	# loops above check the top-level keys and stop there, so a record with a well-typed
	# `lock_pushes` Dictionary carrying a TRUNCATED pair inside it, or an `intents` array whose
	# per-tick dictionaries have lost `retarget_slot`, got all the way into `_from_dictionary`'s
	# rebuild loop and either died there or coerced silently and replayed WRONG (findings L7/L8).
	# It runs HERE and not inside the rebuild because `_from_dictionary` returns an IntentRecorder
	# and has no refusal channel, and by the time its loop reaches a tick the record under
	# construction is already partway built — refusing there would be the partial replay
	# `5-1a/R2` forbids.
	var contents := _contents_refusal(data)
	if contents != "":
		return _refused("%s carries format version %d but %s — it is corrupt or was hand-edited"
				% [path, version, contents])
	return {"record": _from_dictionary(data), "error": ""}


## Story 5-1a: "" if every CONTENT the rebuild loop dereferences is the shape it dereferences it
## as, or the REASON it is not. WHOLE-RECORD (`5-1a/R2`): the first malformed thing found anywhere
## refuses the entire load, so no partial replay is ever produced.
##
## Scoped to `lock_pushes` and the two retarget fields BY RULING (`5-1a/R6`), not by oversight:
## `camera_pushes` carries the identical unguarded dereference (`int(push[0])`, `push[1] as Basis`)
## and is deliberately left open here, recorded as its own close-out line.
static func _contents_refusal(data: Dictionary) -> String:
	var locks := _lock_pushes_refusal(data["lock_pushes"])
	if locks != "":
		return locks
	return _intents_refusal(data["intents"])


## Story 5-1a (AC 4, finding L7): every PRESENT `lock_pushes` entry is the `[slot, direction]` pair
## `_from_dictionary` reads it as.
##
## A TICK ABSENT FROM THE DICTIONARY IS NOT CHECKED AND IS NOT MALFORMED (`5-1a/R11`). The writer
## (`_to_dictionary`, the `if not locks.is_empty()` line) omits every empty tick by design, so
## sparseness is the only shape this channel ever produces — the golden fixture included — and
## `.get(tick, [])` already handles it. L7's filed word "sparse" was a misreading; this validates
## the shape of entries that ARE present and says nothing about which ticks appear.
static func _lock_pushes_refusal(pushes: Dictionary) -> String:
	for tick: Variant in pushes:
		var entries: Variant = pushes[tick]
		if typeof(entries) != TYPE_ARRAY:
			return ("its lock_pushes channel holds %s at tick %s, not the Array of "
					+ "[slot, direction] pairs the rebuild reads there") % [
							type_string(typeof(entries)), str(tick)]
		var index := 0
		for entry: Variant in (entries as Array):
			var reason := _lock_push_entry_refusal(entry)
			if reason != "":
				return "its lock_pushes entry %d at tick %s %s" % [index, str(tick), reason]
			index += 1
	return ""


## One `[slot, direction]` pair, or the reason it is not one. Shape THEN types, in that order:
## `pair[1]` cannot be type-checked until the pair is known to have a second element.
static func _lock_push_entry_refusal(entry: Variant) -> String:
	if typeof(entry) != TYPE_ARRAY:
		return "is %s, not a [slot, direction] pair" % type_string(typeof(entry))
	var pair: Array = entry
	if pair.size() != LOCK_PUSH_TYPES.size():
		return ("carries %d values, not the %d a [slot, direction] pair carries"
				% [pair.size(), LOCK_PUSH_TYPES.size()])
	for half in LOCK_PUSH_TYPES.size():
		var found := typeof(pair[half])
		if found != LOCK_PUSH_TYPES[half]:
			return "carries %s at position %d (expected %s)" % [
					type_string(found), half, type_string(LOCK_PUSH_TYPES[half])]
	return ""


## Story 5-1a (AC 5, finding L8): `retarget_slot` and `retarget_index` are PRESENT and are ints in
## every per-tick, per-player intent dictionary, checked before `_intent_from_values` reaches its
## direct `values["retarget_slot"]` access.
##
## The container checks come first because they are what makes the field check well-defined —
## `has()` cannot be asked of something that is not a Dictionary — not because this story widened
## into validating the intents channel generally: the other seven fields are untouched (`5-1a/R6`).
## Story 6-3a adds `card_activate` to the checked set (see `REQUIRED_INTENT_FIELDS`); the same seven
## stay unchecked.
static func _intents_refusal(intents: Array) -> String:
	for index in intents.size():
		var tick := index + 1
		var pair: Variant = intents[index]
		if typeof(pair) != TYPE_ARRAY:
			return ("its intents channel holds %s at tick %d, not the Array of per-player intent "
					+ "dictionaries the rebuild reads there") % [type_string(typeof(pair)), tick]
		var slot := 0
		for values: Variant in (pair as Array):
			if typeof(values) != TYPE_DICTIONARY:
				return "its intent for tick %d slot %d is %s, not a Dictionary" % [
						tick, slot, type_string(typeof(values))]
			var reason := _intent_fields_refusal(values as Dictionary)
			if reason != "":
				return "its intent for tick %d slot %d %s" % [tick, slot, reason]
			slot += 1
	return ""


## `3-0d/R21` again, one level down: `has()` is TRUE for a key whose value is `null` and says
## nothing about type, so presence and type are both checked and the reason names the field.
static func _intent_fields_refusal(values: Dictionary) -> String:
	for field: String in REQUIRED_INTENT_FIELDS:
		if not values.has(field):
			return "is missing %s" % field
		var found := typeof(values[field])
		if found != REQUIRED_INTENT_FIELDS[field]:
			return "carries %s as %s (expected %s)" % [
					field, type_string(found), type_string(REQUIRED_INTENT_FIELDS[field])]
	return ""


static func _refused(reason: String) -> Dictionary:
	return {"record": null, "error": reason}


## `3-0d/R22`: THE SAVE-PATH GUARD, BY NORMALISATION RATHER THAN BY PREFIX. Returns "" if `path`
## lands inside the `user://` directory, or the REASON it does not.
##
## The prefix test this replaces was `path.begins_with("user://")` and nothing else, which a
## `user://../../…` path satisfies while writing wherever it likes — MEASURED, not theorised:
## `user://../../escape.rec` globalises to `…/Roaming/Godot/escape.rec`, two directories above the
## app's user data, and the review had already used exactly that shape to drop a record in the
## project root. A prefix test on a string that can contain `..` is not a containment test.
##
## So the path is RESOLVED — globalised to a native path, then `simplify_path()`d, which is what
## collapses `..` — and required to sit under the equally-resolved user root. The trailing "/" on
## the comparison is load-bearing and is its own measured trap: `user://../CardSoulsEvil/x.rec`
## resolves to `…/app_userdata/CardSoulsEvil/x.rec`, which HAS `…/app_userdata/CardSouls` as a
## string prefix and is a different directory. Comparing against the root plus its separator is
## what refuses it.
static func _outside_user_directory(path: String) -> String:
	var user_root := ProjectSettings.globalize_path(REQUIRED_PATH_PREFIX).simplify_path()
	var resolved := ProjectSettings.globalize_path(path).simplify_path()
	if resolved.begins_with(user_root + "/"):
		return ""
	return ("refusing to write %s — it resolves to %s, which is not inside the %s directory (%s). "
			+ "Records go under %s, never into the project tree (`3-0d/R16`, normalised at "
			+ "`3-0d/R22`); use RecordFile.path_for()") % [
					path, resolved, REQUIRED_PATH_PREFIX, user_root, REQUIRED_PATH_PREFIX]


# ---------------------------------------------------------------- serialise

static func _to_dictionary(record: IntentRecorder) -> Dictionary:
	var reload_events: Array = []
	for index in record.reload_event_count():
		reload_events.append({
			"tick": record.reload_event_tick(index),
			"values": _resource_values(record.replay_balance_config(index)),
		})
	var costs: Dictionary = {}
	var recorded_costs := record.replay_card_costs()
	for id: StringName in recorded_costs:
		costs[id] = _resource_values(recorded_costs[id])
	# Story 4-1 (`4-1/R1`): the third content channel, serialised through the recorder's PUBLIC
	# replay-side read exactly as the costs directly above are -- this class touches only that API,
	# which is what makes a loaded record a genuine one.
	var effects: Dictionary = {}
	var recorded_effects := record.replay_card_effects()
	for id: StringName in recorded_effects:
		effects[id] = _resource_values(recorded_effects[id])
	# Story 5-2 (AC 4): the colour map goes to disk as plain INTS. `_resource_values` is deliberately
	# NOT used and is untouched by this story: it serialises RESOURCES (balance, flags, costs,
	# effects), and a colour is an enum value, not one.
	var colors: Dictionary = {}
	var recorded_colors := record.replay_card_colors()
	for id: StringName in recorded_colors:
		colors[id] = int(recorded_colors[id])
	# Story 6-2 (AC 16): the pitch-cost map, serialised exactly as the Mode ① costs above are -- through
	# the recorder's PUBLIC replay-side read, each condition by value. An EMPTY map is written as an empty
	# dictionary: empty is legal content for this channel (AC 2), so the key is always present.
	var pitch_costs: Dictionary = {}
	var recorded_pitch_costs := record.replay_pitch_costs()
	for id: StringName in recorded_pitch_costs:
		pitch_costs[id] = _resource_values(recorded_pitch_costs[id])
	# Story 6-5a (AC 6): the pitch-effect map, serialised exactly as the Mode ① effects above are. An
	# EMPTY map is written as an empty dictionary, the pitch-cost rule: the key is always present.
	var pitch_effects: Dictionary = {}
	var recorded_pitch_effects := record.replay_pitch_effects()
	for id: StringName in recorded_pitch_effects:
		pitch_effects[id] = _resource_values(recorded_pitch_effects[id])
	var intents: Array = []
	var camera_pushes: Dictionary = {}
	var contacts: Dictionary = {}
	var lock_pushes: Dictionary = {}
	var drain_pushes: Dictionary = {}
	for tick in range(1, record.tick_count() + 1):
		var pair: Array = []
		for intent: InputIntent in record.intents_at(tick):
			pair.append(_intent_values(intent))
		intents.append(pair)
		var pushes := record.camera_pushes_at(tick)
		if not pushes.is_empty():
			camera_pushes[tick] = pushes
		var facts := record.contacts_at(tick)
		if not facts.is_empty():
			contacts[tick] = facts
		# Story 4-6 (AC 2): the lock channel rides the same loop, the same sparse
		# only-if-non-empty rule and the same tick keying as its `camera_pushes` sibling.
		var locks := record.lock_pushes_at(tick)
		if not locks.is_empty():
			lock_pushes[tick] = locks
		# Story 6-5b (AC 18): the drain channel rides the same loop, the same sparse
		# only-if-non-empty rule and the same tick keying as its `lock_pushes` sibling.
		var drains := record.drain_pushes_at(tick)
		if not drains.is_empty():
			drain_pushes[tick] = drains
	return {
		"format_version": FORMAT_VERSION,
		"seed": record.replay_seed(),
		"reload_events": reload_events,
		"flags": _resource_values(record.replay_feature_flags()),
		"content_order": record.content_order(),
		"deck": record.replay_deck_contents(),
		"costs": costs,
		"effects": effects,
		"colors": colors,
		"pitch_costs": pitch_costs,
		"pitch_effects": pitch_effects,
		"tick_count": record.tick_count(),
		"intents": intents,
		"camera_pushes": camera_pushes,
		"contacts": contacts,
		"lock_pushes": lock_pushes,
		"drain_pushes": drain_pushes,
	}


## All TEN InputIntent fields, verbatim — written as explicit field reads for the same reason
## IntentRecorder.copy_intent is: an eleventh field leaves this visibly incomplete instead of silently
## narrowing what survives a save. (Story 6-3a added the tenth, `card_activate`: FORMAT_VERSION 10.)
##
## Story 4-6 (AC 8/AC 11/AC 14): `aim` is GONE and the two retarget-address fields replace it —
## half of the FORMAT_VERSION 5 -> 6 bump (see the constant's own block).
static func _intent_values(intent: InputIntent) -> Dictionary:
	return {
		"move_dir": intent.move_dir,
		"pressed": intent.pressed.duplicate(),
		"held": intent.held.duplicate(),
		"debug_reset": intent.debug_reset,
		"card_slot": intent.card_slot,
		"card_mode": int(intent.card_mode),
		"card_commit": intent.card_commit,
		"card_activate": intent.card_activate,
		"retarget_slot": intent.retarget_slot,
		"retarget_index": intent.retarget_index,
	}


## Every SCRIPT-DECLARED property of a Resource, by value — the recorder's own by-value discipline
## (intent_recorder.gd:345-356) applied on the way to disk, so a record on disk carries numbers
## and never a path back to an authored resource that can be re-tuned under it.
##
## STORY 4-4 (`4-4/R15`): BY VALUE IS NOW RECURSIVE, and the reason is that "by value" was never
## true of a Resource-valued property. It used to read the property and hand whatever came back to
## `store_var`, which is exactly right for a float and silently wrong for a `Resource`: with
## `full_objects` false, a live reference is encoded as an `EncodedObjectAsID` — an int in a
## trenchcoat — and rebuilding from it produces nothing. `BalanceConfig.unit_kinds` was the first
## property to have that shape, and it lost its entire contents on every save. See `_captured`.
static func _resource_values(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in res.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		out[prop["name"]] = _captured(res.get(prop["name"]))
	return out


## The two keys a NESTED resource rides under, and the reason they are two rather than one: the
## rebuild has to know WHICH class to construct before it can set anything, and a plain values dict
## carries no class. Prefixed so they cannot collide with a script property name — GDScript
## identifiers cannot begin with a digit, but they CAN begin with `_`, so the names below are
## deliberately shapes no `@export` would ever take.
const NESTED_CLASS_KEY := "__resource_class"
const NESTED_VALUES_KEY := "__resource_values"

## Every script class a saved record can carry NESTED inside another resource, tag -> constructor.
## WRITTEN OUT RATHER THAN DERIVED, for `_intent_values`'s reason one function up: a fourth nesting
## level added to `BalanceConfig` leaves this VISIBLY incomplete (the value comes back null and the
## round-trip test fails loudly) instead of silently narrowing what survives a save.
##
## RESIDUE, on `3-0d/R25`'s footing: an unknown tag rebuilds as `null` rather than as a named
## refusal. A v5 file can only carry these three, because this build's writer is the only thing
## that writes v5 and it emits exactly what it can read; a file carrying a foreign tag is corrupt
## input of the same family as the five cases `3-0d/R25` writes down.
static func _fresh_nested(tag: String) -> Resource:
	match tag:
		"UnitKindProfile":
			return UnitKindProfile.new()
		"UnitAttackProfile":
			return UnitAttackProfile.new()
		"ProjectileProfile":
			return ProjectileProfile.new()
	return null


## One property value, captured by value all the way down: a Resource becomes a tagged dict, a
## container is rebuilt element by element (which is also what makes the old `duplicate(true)`
## unnecessary — nothing here shares a reference with the live object), everything else is already
## a value and rides as itself.
static func _captured(value: Variant) -> Variant:
	if value is Resource:
		return {
			NESTED_CLASS_KEY: _class_tag(value as Resource),
			NESTED_VALUES_KEY: _resource_values(value as Resource),
		}
	if value is Array:
		var elements: Array = []
		for element: Variant in (value as Array):
			elements.append(_captured(element))
		return elements
	if value is Dictionary:
		var entries: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			entries[key] = _captured(source[key])
		return entries
	return value


## The script class name a nested resource is tagged with. `get_global_name()` is the `class_name`
## line itself, which is the same string `_fresh_nested` matches on; a Resource with no script (none
## reachable from a record today) falls back to its engine class so the tag is never empty.
static func _class_tag(res: Resource) -> String:
	var script := res.get_script() as Script
	if script != null and String(script.get_global_name()) != "":
		return String(script.get_global_name())
	return res.get_class()


# ---------------------------------------------------------------- rebuild

## THE REBUILD RUNS THROUGH THE CAPTURE API IN LIVE ORDER, which is what makes reload-event TICKS
## come back right: capture_apply_balance() stamps an event with the recorder's CURRENT tick, so
## an event recorded after N ticks has to be re-captured after N capture_advance() calls. Match
## start is every tick-0 event; each later event is re-captured immediately after its tick.
static func _from_dictionary(data: Dictionary) -> IntentRecorder:
	var record := IntentRecorder.new()
	var reload_events: Array = data["reload_events"]
	record.capture_seed(int(data["seed"]))
	_capture_reloads_at(record, reload_events, 0)
	record.capture_inject_feature_flags(_rebuilt(FeatureFlags.new(), data["flags"]) as FeatureFlags)
	# The recorded ORDER, not the sound one: a record whose content order is unsound must survive
	# the round trip AS UNSOUND, so replay_inject_content() can still refuse it (`3-0c/R11`).
	for channel: StringName in data["content_order"]:
		match channel:
			IntentRecorder.CHANNEL_DECK:
				record.capture_inject_deck(_deck_ids(data["deck"]))
			IntentRecorder.CHANNEL_COSTS:
				record.capture_inject_card_costs(_card_costs(data["costs"]))
			IntentRecorder.CHANNEL_EFFECTS:
				record.capture_inject_card_effects(_card_effects(data["effects"]))
			IntentRecorder.CHANNEL_COLORS:
				record.capture_inject_card_colors(_card_colors(data["colors"]))
			IntentRecorder.CHANNEL_PITCH_COSTS:
				# Story 6-2: the same by-value rebuild as the Mode ① costs -- `_card_costs` builds fresh
				# CardCastConditions, `orb_costs` assigned onto its typed dictionary by `_rebuilt`.
				record.capture_inject_pitch_costs(_card_costs(data["pitch_costs"]))
			IntentRecorder.CHANNEL_PITCH_EFFECTS:
				# Story 6-5a (AC 6): the same by-value rebuild as the Mode ① effects -- `_card_effects`
				# builds fresh `CardEffect.new()`s and repopulates every flat export generically (AC 2).
				record.capture_inject_pitch_effects(_card_effects(data["pitch_effects"]))
	var intents: Array = data["intents"]
	var camera_pushes: Dictionary = data["camera_pushes"]
	var contacts: Dictionary = data["contacts"]
	var lock_pushes: Dictionary = data["lock_pushes"]
	var drain_pushes: Dictionary = data["drain_pushes"]
	for tick in range(1, int(data["tick_count"]) + 1):
		for push: Array in camera_pushes.get(tick, []):
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
		# Story 4-6 (AC 2): the lock channel is re-captured in the SAME per-tick seat and the same
		# order relative to `capture_advance` as the bases above -- both are pushed before a tick
		# advances, live and on rebuild alike.
		for push: Array in lock_pushes.get(tick, []):
			record.capture_set_lock_direction(int(push[0]), push[1] as Vector2)
		# Story 6-5b (AC 18): the drain channel is re-captured in the SAME per-tick seat and the same
		# order relative to `capture_advance` as its two pushed-fact siblings above.
		for push: Array in drain_pushes.get(tick, []):
			record.capture_push_drain_target(int(push[0]), int(push[1]))
		for fact: Array in contacts.get(tick, []):
			# Story 4-3a / 4-3b: the SEVEN-element row (attacker slot, attacker index, target slot,
			# target index, attack index, dir, kind) rebuilt into the recorder's pair-shaped seam.
			# Guaranteed seven here by the format_version check above -- a five-element v3 row
			# never reaches this line.
			record.capture_push_contact([int(fact[0]), int(fact[1])],
					[int(fact[2]), int(fact[3])], int(fact[4]), fact[5] as Vector2, int(fact[6]))
		record.capture_advance(_intent_pair(intents[tick - 1]))
		_capture_reloads_at(record, reload_events, tick)
	return record


static func _capture_reloads_at(record: IntentRecorder, reload_events: Array, tick: int) -> void:
	for event: Dictionary in reload_events:
		if int(event["tick"]) == tick:
			record.capture_apply_balance(_rebuilt(BalanceConfig.new(), event["values"]) as BalanceConfig)


static func _intent_pair(raw: Array) -> Array[InputIntent]:
	var out: Array[InputIntent] = []
	for values: Dictionary in raw:
		out.append(_intent_from_values(values))
	return out


static func _intent_from_values(values: Dictionary) -> InputIntent:
	var intent := InputIntent.new()
	intent.move_dir = values["move_dir"]
	for key: StringName in values["pressed"]:
		intent.pressed[key] = bool(values["pressed"][key])
	for key: StringName in values["held"]:
		intent.held[key] = bool(values["held"][key])
	intent.debug_reset = bool(values["debug_reset"])
	intent.card_slot = int(values["card_slot"])
	intent.card_mode = int(values["card_mode"]) as Enums.ModeKind
	intent.card_commit = bool(values["card_commit"])
	intent.card_activate = bool(values["card_activate"])
	intent.retarget_slot = int(values["retarget_slot"])
	intent.retarget_index = int(values["retarget_index"])
	return intent


static func _deck_ids(raw: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in raw:
		out.append(StringName(id))
	return out


## Story 5-2 (AC 4): the colour map rebuilt from the file. No `_rebuilt` call and no Resource
## construction -- the round trip is int in, int out, which is the whole reason this channel could
## be added without touching `_resource_values` or the nesting machinery.
static func _card_colors(raw: Dictionary) -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in raw:
		out[id] = int(raw[id]) as Enums.CardColor
	return out


static func _card_costs(raw: Dictionary) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in raw:
		out[id] = _rebuilt(CardCastCondition.new(), raw[id]) as CardCastCondition
	return out


## Story 4-1 (`4-1/R1`): the effects half of _card_costs directly above, same shape, same reason.
static func _card_effects(raw: Dictionary) -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in raw:
		out[id] = _rebuilt(CardEffect.new(), raw[id]) as CardEffect
	return out


## `_resource_values`'s inverse. TYPED ARRAYS ARE ASSIGNED, NOT SET, and that is the half of
## `4-4/R15` that is easy to get wrong twice: `res.set("unit_kinds", <untyped Array>)` is REJECTED
## WITH NOTHING PRINTED even when every element is the right class, so a rebuild that recursed
## correctly and then `set()` the result would still have landed an empty array. MEASURED both ways
## on Godot 4.6.3 — `set()` leaves size 0, `Array.assign()` onto the property's own typed array
## converts in place and reads back size 1. The array `get()` returns IS the property's array
## (arrays are reference values), so assigning into it is assigning into the resource.
static func _rebuilt(res: Resource, values: Dictionary) -> Resource:
	for name: String in values:
		var value: Variant = _restored(values[name])
		var existing: Variant = res.get(name)
		if value is Array and existing is Array:
			(existing as Array).assign(value as Array)
			continue
		# The same trap on the other container: `orb_costs` is a `Dictionary[CardColor, int]`, and
		# an untyped Dictionary `set()` onto it is refused as quietly as the array case.
		if value is Dictionary and existing is Dictionary:
			(existing as Dictionary).assign(value as Dictionary)
			continue
		res.set(name, value)
	return res


## `_captured`'s inverse, one value at a time: a tagged dict becomes a fresh resource rebuilt
## through this same function, a container is restored element by element, everything else is
## already the value it was written as.
static func _restored(value: Variant) -> Variant:
	if value is Dictionary and (value as Dictionary).has(NESTED_CLASS_KEY):
		var entry: Dictionary = value
		var fresh := _fresh_nested(String(entry[NESTED_CLASS_KEY]))
		if fresh == null:
			return null
		return _rebuilt(fresh, entry[NESTED_VALUES_KEY])
	if value is Array:
		var elements: Array = []
		for element: Variant in (value as Array):
			elements.append(_restored(element))
		return elements
	if value is Dictionary:
		var entries: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			entries[key] = _restored(source[key])
		return entries
	return value
