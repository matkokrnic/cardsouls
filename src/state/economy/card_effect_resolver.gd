class_name CardEffectResolver
extends RefCounted

## D6 pure evaluator (story 4-1, AC 1) — THE one place `CardEffect.effect_id` strings are
## matched against gameplay meaning. `effect_id` has been authored on all nine fixture cards
## since 3-2 and read by NOTHING until this file; card_effect.gd's own header promised "the
## resolver that turns an effect_id into gameplay lands with the card-play story", and this is
## it.
##
## A SIBLING OF CastEvaluator AND EconomyEvaluator, NOT A BRANCH INSIDE EITHER. Each of those
## files opens by declaring itself "THE one place" its kind of data is read — ResourceGeneration
## Rules for one, CardCastConditions for the other — and a card-EFFECT read folded into either
## would contradict that identity. Costs, faucets and effects are three different questions asked
## of three different resources, and each gets one file.
##
## Fully STATIC and stateless, exactly like both siblings: there is no instance to hold a
## reference in, so CONSTRAINT C (never cache `balance` / `balance_ticks` / an injected value)
## holds BY CONSTRUCTION. Nothing is retained between calls.
##
## PURE means it COMPUTES, it does not APPLY (D6). `outcome()` returns a StringName and touches
## NO board, NO pool and NO container — appending the unit record happens in
## MatchState.advance()'s ordered dispatch, through UnitBoard.add(), so the mutation stays where
## every other mutation lives (D2).
##
## NO CARD LIBRARY REACHES THIS FILE. It never names CardDatabase, CARDS_DIR or data/cards — the
## effect arrives as an ARGUMENT, resolved by MatchState from the one-shot injected map (AC 2).
## Both architecture guards in test_architecture_invariants.gd scan src/state/ and cover this
## file for free.
##
## THE VERDICT IS A RETURNED VALUE AND NOTHING ELSE (`4-1/R3`, `4-1/R10`). No branch here or at
## the call site reaches HeroState.reject_action: every outcome below is a SUCCESSFUL cast —
## CastEvaluator has already allowed it, the mana is spent and the card is discarded — so
## rendering any of them as a player-facing refusal would be a lie about what happened. The
## reasons are asserted in unit tests, which is the whole of their contract.

## The recognized `effect_id` PREFIXES, and the entire vocabulary this story understands. The
## nine authored ids are exactly six `summon_*` and three `spell_*`; test_card_authoring.gd
## asserts that every authored id carries one of these two prefixes, which is the machine half
## of AC 3's golden-discipline ruling (`4-1/R4`).
##
## STORY 4-4 (AC 1): THE WHOLE-ID TABLE THIS COMMENT NAMED IN ADVANCE NOW EXISTS, directly below.
## The paragraph this replaces read: "Matched as a PREFIX, never as a whole-id table ... A whole-id
## table would be the place `4-4`'s totem/minion split has to land, and writing it now would
## pre-commit that shape." This is 4-4; the shape is chosen here, by the story that has to live with
## it, exactly as that note intended.
##
## THE PREFIXES SURVIVE AND STILL DO THEIR OWN JOB. They classify an id as a summon or a spell — the
## question `outcome()` asks — and `test_card_authoring.gd` still asserts every authored id carries
## one of the two, which is the machine half of `4-1/R4`'s golden-discipline ruling. What the table
## adds is a SECOND, finer question the prefix cannot answer: WHICH kind a summon puts on the board.
## Two questions, two mechanisms, neither replacing the other.
const PREFIX_SUMMON := "summon_"
const PREFIX_SPELL := "spell_"

## AC 1: the `summon_*` id -> UNIT KIND NAME table — the differentiation the ratified TOTEM CLAUSE
## withheld until this story. The three totem fixture cards named in AC 1 (`hellforge_totem` /
## `summon_combat_totem`, `tidal_wardstone` / `summon_mana_accelerator`, `verdant_wardstone` /
## `summon_stamina_accelerator`) each resolve to a DISTINCT kind here, which is what makes them "no
## longer uniform `summon_*` handling indistinguishable from a minion or from one another".
##
## A `Dictionary`, AND ITS ITERATION ORDER DECIDES NOTHING. It is only ever `get()`-ed by a single
## known key — never iterated, never sorted, never hashed — so the standing prohibition on
## Dictionary iteration order and on StringNames reaching a hash is untouched. The VALUE that leaves
## this file is a kind NAME, and `BalanceConfig.kind_index_of()` turns it into the plain int that
## actually crosses into the record and the snapshot.
##
## AN UNMAPPED `summon_*` ID FALLS TO THE MINION KIND, and that is a DELIBERATE default rather than
## an oversight: `summon_imp` and the two other minion fixture ids are not listed, so the shipped
## minion verdict is untouched by this table's arrival and a future minion card needs no edit here.
## Only a kind that DIFFERS earns a row. The failure this cannot hide is the one that matters — a
## row naming a kind `BalanceConfig` does not author reaches `NO_KIND_INDEX` at the cast seat and
## puts NOTHING on the board, loudly, rather than silently summoning a minion.
##
## THE KIND NAMES ARE NAMED CONSTANTS, not literals repeated at the table and again at every reader.
## Story 4-4's accelerator seats (`MatchState._generate_mana`'s third call site and
## `_regen_stamina`) each have to ask "is a live totem of THIS kind on this player's board", and a
## StringName literal at those seats would be a second spelling of a name only this file owns — a
## typo would silently make a faucet permanently dry with nothing failing. This is the same
## constant-vocabulary discipline `CastEvaluator.REASON_*` and `EconomyEvaluator.SOURCE_*` already
## carry, applied to the kind names.
const KIND_MINION := &"minion"
const KIND_COMBAT_TOTEM := &"combat_totem"
const KIND_MANA_ACCELERATOR := &"mana_accelerator"
const KIND_STAMINA_ACCELERATOR := &"stamina_accelerator"
const SUMMON_KINDS: Dictionary[StringName, StringName] = {
	&"summon_combat_totem": KIND_COMBAT_TOTEM,
	&"summon_mana_accelerator": KIND_MANA_ACCELERATOR,
	&"summon_stamina_accelerator": KIND_STAMINA_ACCELERATOR,
}

## AC 1: the three ids above are TOTEMS and gate on `FeatureFlags.totems`; every other `summon_*` id
## is a minion and gates on `FeatureFlags.minions`. Derived from the table rather than listed a
## second time, so the two can never disagree — see `_is_totem()` below.

## FOUR NAMED OUTCOMES, EXACTLY ONE OF WHICH MUTATES THE BOARD. Named as constants rather than
## repeated StringName literals so a typo at a call site fails to compile-match instead of
## silently producing an unrecognised verdict — the CastEvaluator.REASON_* /
## EconomyEvaluator.SOURCE_* precedent.
##
## DELIBERATELY NOT CastEvaluator's `ALLOWED := &""` CONVENTION, and the divergence is the point.
## There, EMPTY MEANS ALLOWED works because the question is binary — a cast either proceeds or
## carries a reason. Here there is no such binary: three of the four outcomes are non-mutating and
## all three are successful casts, so an empty "success" value would have to stand for one of them
## and read as failure for the other two. Every outcome is named.
const OUTCOME_SUMMON := &"summon"

## AC 5, `E4-P/R10`: a `spell_*` id is a NAMED NO-OP, never a rejection. The cast has already
## passed CastEvaluator; mana is spent and the card discarded exactly as today. `bramble_snare`,
## `frost_dart` and `ember_lash` are the three fixture cards that land here. Real spell resolution
## acquires an owner at the E4 close-out at the latest — this is not a partial implementation of
## any spell's actual effect, which is why the reason says NOT YET rather than NOTHING.
const REASON_SPELL_NOT_YET_RESOLVED := &"spell_not_yet_resolved"

## AC 6(i), the MISSING-ENTRY HONEST DEFAULT — no injected effect entry for the cast id. The
## `CastEvaluator.refusal_reason` null-branch precedent verbatim, including its rationale: a total
## function's honest default rather than a crash. UNLIKE that branch it IS naturally reachable and
## IS mutation-proven, because injection is state-side OPTIONAL by ruling (`4-1/R3`) — every
## existing MatchState-building fixture in the suite injects a deck and costs but no effects, and
## every cast in those fixtures lands here.
const REASON_NO_EFFECT_ENTRY := &"no_effect_entry"

## AC 6(ii), the UNKNOWN-PREFIX REFUSAL — an entry exists but its `effect_id` is neither
## `summon_*` nor `spell_*`. NO FIXTURE CARD PRODUCES THIS TODAY (the nine authored ids are
## exactly six and three, confirmed by reading every data/cards/*.tres, and test_card_authoring.gd
## now fails if a tenth arrives with a third prefix), so it is proven with a SYNTHETIC map entry
## in a unit test and is declared NOT naturally reachable — never a claim of live reachability.
const REASON_UNKNOWN_EFFECT_PREFIX := &"unknown_effect_prefix"

## The project-context HARD RULE on feature flags, made concrete for the E4 minion layer:
## `FeatureFlags.minions` is one of the seven named toggleable layers, so summon resolution
## CHECKS it and DEGRADES GRACEFULLY when it is off. Degrading gracefully here means the cast
## still resolves exactly as it does today — mana spent, card discarded, replacement owed — and
## no unit reaches the board, which is precisely the `spell_*` branch's shape. It gets its OWN
## name rather than reusing REASON_SPELL_NOT_YET_RESOLVED because "the layer is switched off" and
## "this effect has no owner yet" are different facts about the match.
##
## The story left flag-gating as "an implementation choice against the project-context HARD RULE,
## not decided here" (Dev Notes). The HARD RULE decides it: "NEVER hardcode a gameplay layer on.
## Any of {..., minions, totems, ...} must check the injected FeatureFlags resource and degrade
## gracefully when off." The authored data/feature_flags.tres turns `minions` ON with this story,
## which is the rule working as intended — toggling the layer is a checkbox, not a code edit.
const REASON_MINIONS_FLAG_CLOSED := &"minions_flag_closed"

## Story 4-4 (story Dev Notes, the B11(b) correction): the TOTEM twin of the reason directly above.
## Both `minions` and `totems` bools have existed on `FeatureFlags` since 1-5, but only
## `flags.minions` was ever read in `src/` — `flags.totems` was UNREAD, while `epics.md`'s E4 goal
## commits `FeatureFlags: minions, totems`. This story discharges that commitment by giving the
## totem layer its own gate, read the same way `minions` already is.
##
## ITS OWN NAME RATHER THAN A REUSE OF `REASON_MINIONS_FLAG_CLOSED`, on that constant's own stated
## reasoning: "the layer is switched off" is a different fact about the match per LAYER, and a
## playtester isolating cognitive overload needs to know WHICH switch closed the cast. Degrading
## gracefully means the identical thing it means for minions — the cast still resolves (mana spent,
## card discarded, replacement owed) and no totem reaches the board.
const REASON_TOTEMS_FLAG_CLOSED := &"totems_flag_closed"

## Story 6-5a (AC 4, AC 15): THE FIRST WHOLE-ID FAMILY THAT IS NOT A SUMMON. Deck 1's effect ids carry
## no `summon_`/`spell_` prefix -- they are matched here as WHOLE ids, one table row each, which is what
## AC 4 means by dispatching "on the WHOLE `effect_id`, not a prefix". Ruin Vanguard is the exception by
## design: `summon_ruin_vanguard` takes the unchanged `summon_*` path above (an unmapped summon is a
## minion), because it is a summon rather than a new effect family.
##
## THE FOUR BUFF OUTCOMES. Each names what `MatchState` must APPLY (D6: this file computes, the ordered
## dispatch applies -- the `OUTCOME_SUMMON` discipline, unchanged). None of them mutates anything here.
const OUTCOME_BLOODLUST := &"bloodlust"
const OUTCOME_VAMPIRIC_AURA := &"vampiric_aura"
const OUTCOME_BLOODHOUND_STEP := &"bloodhound_step"
const OUTCOME_FROSTBITE := &"frostbite"

## The authored effect id -> buff outcome table. A `Dictionary` only ever `get()`-ed by one known key --
## never iterated, never sorted, never hashed -- the `SUMMON_KINDS` posture verbatim.
const BUFF_OUTCOMES: Dictionary[StringName, StringName] = {
	&"bloodlust": OUTCOME_BLOODLUST,
	&"vampiric_aura": OUTCOME_VAMPIRIC_AURA,
	&"bloodhound_step": OUTCOME_BLOODHOUND_STEP,
	&"frostbite": OUTCOME_FROSTBITE,
}

## Story 6-5a (AC 15): the NINE Deck 1 effects that are authored but not yet built resolve as ONE named
## no-op -- `REASON_SPELL_NOT_YET_RESOLVED`'s shape and reasoning: a SUCCESSFUL cast (mana/orbs spent,
## card discarded, replacement owed, no `reject_action`), NOT YET rather than NOTHING. The card that
## was cast stays distinguishable through its own id; the owning story is machine-readable below.
const REASON_DECK1_NOT_YET_RESOLVED := &"deck1_not_yet_resolved"

## Each deferred Deck 1 effect id -> the board key of the story that owns building it (AC 15,
## `6-5a/R19`). A constant rather than a comment because a comment is not machine-checkable; a unit test
## asserts all nine rows. Only ever `get()`-ed, never iterated.
##
## STORY 6-5b: FOUR ROWS LEAVE, NINE -> FIVE. `culling`, `grave_ward`, `raise_dead` and `drain` named
## THIS story as their owner and this story builds them, so they become real outcomes below rather
## than staying rows here. The table is the mechanism working as designed -- a deferred effect's row
## is retired by the story the row names, and the count assertion in `test_spell_framework.gd` moves
## with it deliberately.
## STORY 6-5c: ONE MORE ROW LEAVES, FIVE -> FOUR. `honed_bolt` named THIS story as its owner and this
## story builds it, so it becomes a real outcome below rather than staying a row here -- the same
## mechanism working as designed that retired 6-5b's four, and the count assertion in
## `test_spell_framework.gd` moves with it deliberately. `rocksling`, `boom`, `counterspell` and
## `corpse_bomb` stay deferred and their no-op behaviour is untouched (AC 21).
## STORY 6-5d: NO ROW LEAVES AND NO ROW ARRIVES -- but THREE ROWS ARE RE-POINTED (AC 35, `6-5d/R14`).
## The board reshuffle renamed `6-5d-hero-and-corpse-projectiles` to
## `6-5d-fireball-and-spell-targeting` and `6-5e-boulder-injection` to
## `6-5e-rocksling-boom-and-corpse-bomb`, and the three rows that named the OLD keys named stories that
## no longer exist. All three move to the 6-5e key, which is the story that actually builds them --
## `fireball` is what 6-5d builds, and it was never a row here (Bloodhound Step's pitch was
## `bloodlust`, a buff, until this story). The pin in `test_spell_framework.gd` moves with them.
## STORY 6-5e: THREE ROWS LEAVE, FOUR -> ONE (AC 43). `rocksling`, `boom` and `corpse_bomb` all named
## THIS story as their owner and this story builds all three, so each becomes a real outcome below rather
## than staying a row here -- the same mechanism working as designed that retired 6-5b's four and 6-5c's
## one, and the count assertion in `test_spell_framework.gd` moves with it deliberately. ONLY
## `counterspell` REMAINS DEFERRED, owned by `6-5f`, which is the last of the six 6-5 sub-stories.
## STORY 6-5f: THE LAST ROW LEAVES, ONE -> ZERO (AC 27). `counterspell` named THIS story as its owner and
## this story builds it, so it becomes a real outcome below rather than staying a row here -- the same
## mechanism working as designed that retired 6-5b's four, 6-5c's one and 6-5e's three, for the FOURTH and
## final time, and the count assertion in `test_spell_framework.gd` moves 1 -> 0 with it deliberately.
##
## THE TABLE IS NOW EMPTY AND STAYS, rather than being deleted along with its last row. It is the
## MECHANISM, not the data: `owner_story_for()` is read by `outcome()` on every unrecognised id, and an
## empty table answers "this id is owned by nobody" exactly as correctly as a full one. Deleting it would
## delete the seat the NEXT deferred effect (Deck 2's, whenever it arrives) declares itself at, and the
## story that needed it would have to rebuild both the table and the `REASON_DECK1_NOT_YET_RESOLVED` arm
## from this file's history. An empty table with its pin at zero is the honest resting state of a
## mechanism with nothing deferred.
const DEFERRED_EFFECT_OWNERS: Dictionary[StringName, StringName] = {}

## Story 6-5a (AC 16): the SPELL layer's closed-gate reason, the `REASON_TOTEMS_FLAG_CLOSED` twin. The
## four buffs gate on `FeatureFlags.spells`; off, the cast still resolves and the buff does not apply.
const REASON_SPELLS_FLAG_CLOSED := &"spells_flag_closed"

## ------------------------------------------------------------------------------------------
## STORY 6-5b: THE FOUR OWN-MINION / CORPSE OUTCOMES -- the four rows that just left
## `DEFERRED_EFFECT_OWNERS`. `BUFF_OUTCOMES`' posture verbatim: whole-id rows in a `Dictionary` only
## ever `get()`-ed by one known key, never iterated, never sorted, never hashed.
## ------------------------------------------------------------------------------------------
## THEY GET THEIR OWN TABLE RATHER THAN FOUR MORE `BUFF_OUTCOMES` ROWS, and the reason is that table's
## own NAME: none of these four is a buff. Not one of them starts a timed rule (`6-5b/R7` keeps Grave
## Ward off `PlayerState`'s rule seat entirely), and three of them mutate the BOARD -- which is the
## `OUTCOME_SUMMON` family, not the buff family. One table per family keeps the apply seat's `match`
## readable as "what kind of thing is this".
##
## ALL FOUR GATE ON `FeatureFlags.spells`, exactly as the four buffs do and through the same
## `_spells_open` reading: a layer that cannot be verified open stays shut. Degrading gracefully means
## what it means everywhere else here -- the cast still RESOLVES (mana/orbs spent, card discarded,
## replacement owed) and nothing is killed, extended, raised or healed.
const OUTCOME_CULLING := &"culling"
const OUTCOME_GRAVE_WARD := &"grave_ward"
const OUTCOME_RAISE_DEAD := &"raise_dead"
const OUTCOME_DRAIN := &"drain"

## STORY 6-5e (AC 29-33): CORPSE BOMB JOINS THIS FAMILY rather than starting a sixth table, and the
## family's own name is the argument: it kills every one of the caster's OWN LIVING MINIONS and leaves a
## normal corpse for each (ruling 11), which is Culling's shape with a skull attached. It shares the
## family's `FeatureFlags.spells` gate and -- the half that matters -- the family's
## `NEEDS_OWN_LIVING_MINION` precondition, unchanged and not re-spelled (AC 33).
const OUTCOME_CORPSE_BOMB := &"corpse_bomb"

const OWN_MINION_OUTCOMES: Dictionary[StringName, StringName] = {
	&"culling": OUTCOME_CULLING,
	&"grave_ward": OUTCOME_GRAVE_WARD,
	&"raise_dead": OUTCOME_RAISE_DEAD,
	&"drain": OUTCOME_DRAIN,
	&"corpse_bomb": OUTCOME_CORPSE_BOMB,
}


## ------------------------------------------------------------------------------------------
## STORY 6-5e (AC 25-28): THE OPPOSING-HAND FAMILY -- the first effect that reads the OTHER player's hand.
## `BUFF_OUTCOMES`' posture verbatim: whole-id rows in a `Dictionary` only ever `get()`-ed by one known
## key, never iterated, never sorted, never hashed.
## ------------------------------------------------------------------------------------------
## ITS OWN TABLE RATHER THAN A ROW IN THE FAMILY ABOVE, on that family's own stated reason ("one table per
## family keeps the apply seat's `match` readable as 'what kind of thing is this'") and a sharper one:
## every other table here describes an effect acting on the CASTER's own side -- its buffs, its board, its
## corpses, its cast. Boom acts on the OPPONENT's hand, which is a different question asked of a different
## party, and it is the ONLY effect in the game that asks it.
##
## STORY 6-5f CORRECTS THIS BLOCK'S LAST SENTENCE rather than leaving it to lie. It read: "`6-5f`'s
## Counterspell is the candidate second row; nothing is written here for it." Counterspell did NOT become
## that row -- it reads the opposing player's LAST RESOLVED CARD, never their hand, so this table stays at
## one member and `COUNTERSPELL_OUTCOMES` below is its own family. The candidacy is resolved, negatively,
## and the reasoning is at that table.
##
## ONE ROW IS THE HONEST SIZE OF A FAMILY WITH ONE MEMBER. `CAST_OUTCOMES` shipped at 6-5c with one row
## and grew to two at 6-5d, which is the precedent for starting a family at its first member rather than
## folding it into a table whose name would then be a lie.
const OUTCOME_BOOM := &"boom"

const OPPOSING_HAND_OUTCOMES: Dictionary[StringName, StringName] = {
	&"boom": OUTCOME_BOOM,
}


## ------------------------------------------------------------------------------------------
## STORY 6-5f (AC 4-23): THE RETROACTIVE FAMILY -- the first and only effect that acts on something that
## ALREADY HAPPENED. `BUFF_OUTCOMES`' posture verbatim: whole-id rows in a `Dictionary` only ever
## `get()`-ed by one known key, never iterated, never sorted, never hashed.
## ------------------------------------------------------------------------------------------
## ITS OWN TABLE, AND THE FILE ALREADY ARGUED WHY IT IS NOT THE ROW ABOVE. `OPPOSING_HAND_OUTCOMES`' own
## header names Counterspell as "the candidate second row; nothing is written here for it" -- a candidate,
## not a decision, and the decision goes the other way on that table's own naming rule ("one table per
## family keeps the apply seat's `match` readable as 'what kind of thing is this'", plus `CAST_OUTCOMES`'
## precedent of "starting a family at its first member rather than folding it into a table whose name would
## then be a lie"). Counterspell does not read the opposing HAND at all: it reads the opposing player's
## LAST RESOLVED CARD and the record of what that resolution actually did. Filing it under the hand would
## make the hand table's name false for half its rows, which is precisely the failure that rule forbids.
##
## THE CANDIDATE NOTE AT `OPPOSING_HAND_OUTCOMES` IS CORRECTED AT ITS OWN SEAT rather than left to lie
## (the `_resolve_pitch_activate` / `6-5d` precedent for a superseded comment).
const OUTCOME_COUNTERSPELL := &"counterspell"

const COUNTERSPELL_OUTCOMES: Dictionary[StringName, StringName] = {
	&"counterspell": OUTCOME_COUNTERSPELL,
}


## ------------------------------------------------------------------------------------------
## STORY 6-5e (AC 20-21a, AC 28a): THE COVER-CLEARING FAMILY -- Boulder's one legal action.
## ------------------------------------------------------------------------------------------
## Playing a Boulder (Mode ①, 2 mana authored) LIFTS IT OFF the slot it covers and hands the card beneath
## back, immediately playable, in that same slot (ruling 7). It is the FIRST basic effect whose resolution
## is not "apply something to a board or a pool" but "undo a piece of hand state", which is why it is its
## own family rather than a row in any table above.
##
## THE MEMBERSHIP IS ITSELF GAMEPLAY, exactly as `CAST_OUTCOMES`' is: `clears_cover()` below reads this
## table to tell `MatchState`'s Mode ① dispatch that THIS press takes the cover rather than the card --
## so the card is not removed, nothing reaches the discard (AC 22: a Boulder is never discarded) and no
## replacement is owed (AC 21: there is nothing to replace). One table, two questions, the
## `CAST_OUTCOMES` shape.
const OUTCOME_BOULDER_CLEAR := &"boulder_clear"

const BOULDER_OUTCOMES: Dictionary[StringName, StringName] = {
	&"boulder_discard": OUTCOME_BOULDER_CLEAR,
}


## Story 6-5e (AC 21/AC 21a, AC 28a): DOES PRESSING THIS EFFECT'S CARD LIFT A COVER instead of playing the
## card in the slot?
##
## IT COMPUTES, IT DOES NOT APPLY (D6), and it is the ONE question `MatchState._resolve_basic_cast` asks
## about this family -- the `starts_cast()` / `spends_variable_mana()` shape verbatim, one classification
## per press, so no card is named at the seat.
##
## NO FLAG IS READ, unlike `starts_cast`. A Boulder is not a spell the player chose to cast: it was put in
## their hand by the opponent, and `FeatureFlags.spells` closing must not leave it unremovable. The layer
## that produced it is the one that is switched off; the cleanup stays available.
##
## A NULL EFFECT CLEARS NOTHING, the `starts_cast` null branch's own honest default.
static func clears_cover(effect: CardEffect) -> bool:
	return effect != null and BOULDER_OUTCOMES.has(effect.effect_id)


## ------------------------------------------------------------------------------------------
## STORY 6-5c: THE CAST FAMILY -- the first family of effects that does NOT apply at the press.
## `BUFF_OUTCOMES`' posture verbatim: whole-id rows in a `Dictionary` only ever `get()`-ed by one
## known key, never iterated, never sorted, never hashed.
## ------------------------------------------------------------------------------------------
## ITS OWN TABLE RATHER THAN MORE `BUFF_OUTCOMES` ROWS, on that table's own stated reason and a
## stronger one: a cast is not a buff, and unlike every other family here the table's MEMBERSHIP is
## itself gameplay -- `starts_cast()` below reads it to decide whether the press starts a commitment
## window at all. One table per family, and this family's table answers two questions.
##
## THE FRAMEWORK NAMES NO CARD (AC 1). `honed_bolt` appears HERE, in the one file whose whole job is
## matching `effect_id` strings against gameplay meaning (D6), and NOWHERE in `MatchState`: the cast
## seat asks `starts_cast()`, the strike seat asks `outcome()`. Rocksling, Fireball and Corpse Bomb
## adopt the framework by adding a row here plus their own apply arm, with no edit to the window,
## the commitment locks or the strike seat.
const OUTCOME_HONED_BOLT := &"honed_bolt"

## STORY 6-5d (AC 10-13): THE SECOND MEMBER OF THE CAST FAMILY, and the FIRST cast id that is a card's
## PITCH effect rather than its BASIC one. `6-5c`'s note that "Rocksling, Fireball and Corpse Bomb adopt
## the framework by adding a row here plus their own apply arm, with no edit to the window, the
## commitment locks or the strike seat" is discharged exactly as written: this row plus
## `MatchState._apply_fireball`, and the window, the three commitment locks and the strike ladder are
## untouched. What DID have to change is which MAP the strike seat looks the effect up in -- see
## `PlayerState.cast_effect_mode`.
const OUTCOME_FIREBALL := &"fireball"

## STORY 6-5e (AC 7-11a): THE THIRD MEMBER OF THE CAST FAMILY, and the FIRST cast whose strike places
## MORE THAN ONE projectile. `6-5c`'s note that "Rocksling, Fireball and Corpse Bomb adopt the framework by
## adding a row here plus their own apply arm, with no edit to the window, the commitment locks or the
## strike seat" is discharged for the second of the three exactly as written: this row plus
## `MatchState._apply_rocksling`, and the window, the three commitment locks and the strike ladder are
## untouched. Corpse Bomb, the third name in that note, turned out NOT to be a cast at all -- `6-5e/R17`
## rules it resolves entirely on its activation tick -- so it is an own-minion outcome instead, and the
## note's prediction is corrected rather than forced.
##
## IT IS A BASIC (Mode ①) CAST, unlike Fireball: `rocksling` is `rocksling.tres`'s `basic_effect`, so the
## strike seat resolves it through `_card_effects` on the `Enums.ModeKind.BASIC` arm of `_cast_effect_of`.
## That is what makes it the first Mode ① effect ever to fire a hero projectile, and the reason
## `inject_pitch_effects`' flight-profile mirror had to be widened to cover the basic map too (AC 1a).
const OUTCOME_ROCKSLING := &"rocksling"

const CAST_OUTCOMES: Dictionary[StringName, StringName] = {
	&"honed_bolt": OUTCOME_HONED_BOLT,
	&"fireball": OUTCOME_FIREBALL,
	&"rocksling": OUTCOME_ROCKSLING,
}


## Story 6-5d (AC 5, `6-5d/R1`, Open Question 1): DOES STAGING THIS EFFECT'S CARD SPEND THE WHOLE POOL
## (capped) RATHER THAN ITS FIXED PITCH PRICE?
##
## IT COMPUTES, IT DOES NOT APPLY (D6), and it is the ONE question `MatchState._resolve_pitch_stage`
## asks about cost classification -- the `starts_cast()` shape verbatim, one seat up the same card's
## life.
##
## THE AUTHORED NUMBER ANSWERS IT, NOT AN ID TABLE. Every other family in this file dispatches on the
## `effect_id` string because "what does this effect DO" is not derivable from a magnitude; this
## question IS a magnitude -- `mana_cap` is the ceiling on a variable spend, and a card with no ceiling
## has no variable spend to cap. So there is no `fireball` row to keep in agreement with
## `card_effect.gd`'s default, and a second variable-cost card needs no edit here. The cost of that
## choice is that the field's default MUST stay neutral zero, which `card_effect.gd` records in as many
## words at the field.
##
## A NULL EFFECT IS FIXED-COST, the `starts_cast` null branch's own honest default: an effect with no
## injected entry authors no cap, so the existing fixed-price path is what a staging with no effect
## entry gets -- which is every pitch staging in every fixture that injects costs but no pitch effects.
static func spends_variable_mana(effect: CardEffect) -> bool:
	return effect != null and effect.mana_cap > 0.0


## Story 6-5c (AC 1/AC 2/AC 6): does pressing this effect's card start a CAST -- a commitment window
## between the press and the effect -- rather than applying at the press?
##
## IT COMPUTES, IT DOES NOT APPLY (D6), and it is the ONE question `MatchState`'s cast seat asks about
## classification. A false answer means the press behaves exactly as every press behaved before this
## story: the effect applies at the press through `_apply_card_effect` and nothing is committed.
##
## THE FLAG IS READ HERE, AND THAT IS AC 6's WHOLE MECHANISM. With `FeatureFlags.spells` closed the
## card still RESOLVES -- mana spent, card discarded, replacement owed, `_spells_open`'s standing
## degrade -- but no cast starts, nothing applies and presentation is never told to show one. Routing
## the closed layer through this one answer is what makes that degrade structural rather than a
## second check at the seat. `_spells_open`'s direction is unchanged: a layer that cannot be verified
## open stays shut.
##
## A NULL EFFECT NEVER CASTS, the `REASON_NO_EFFECT_ENTRY` null branch's own honest default: a cast
## with no injected entry has no duration to commit for.
static func starts_cast(effect: CardEffect, flags: FeatureFlags) -> bool:
	if effect == null:
		return false
	return CAST_OUTCOMES.has(effect.effect_id) and _spells_open(flags)


## Story 6-5b (AC 9/AC 13/AC 15/AC 21, `6-5b/R14`): does this effect REFUSE when the caster has
## nothing to act on -- and if so, which board fact does it need?
##
## IT IS ANSWERED HERE, ON THE RESOLVER, AND THAT IS DELIBERATE. The pre-spend gates live in
## `MatchState` (they have to -- they read a board and they call `reject_action`), but WHICH cards
## have a precondition at all is a property of the EFFECT, and this file is "THE one place
## `CardEffect.effect_id` strings are matched against gameplay meaning". A literal id list at the two
## gate sites would be that vocabulary spelled a third and fourth time.
##
## STILL COMPUTES, STILL DOES NOT APPLY (D6): it returns one of the two requirement names below, or
## `&""` for every effect with no board precondition. It touches no board and reads no flags -- a
## CLOSED spell layer is not a refusal (the cast resolves and applies nothing), so the flag has no
## business in this answer.
const NEEDS_NOTHING := &""

## `culling` / `drain`: at least one of the caster's own LIVING minions must exist.
const NEEDS_OWN_LIVING_MINION := &"own_living_minion"

## `grave_ward` / `raise_dead`: at least one of the caster's own CORPSES must exist.
const NEEDS_OWN_CORPSE := &"own_corpse"

## Story 6-5e (AC 33): `corpse_bomb` joins the family's FIRST requirement unchanged -- "at least one of
## the caster's own LIVING minions" is literally what it needs, and reusing the row rather than naming a
## `needs_own_minion_to_bomb` twin is what makes AC 33's "the same 6-5b no-target path" true of the token
## as well as of the seat.
const OWN_MINION_REQUIREMENTS: Dictionary[StringName, StringName] = {
	&"culling": NEEDS_OWN_LIVING_MINION,
	&"drain": NEEDS_OWN_LIVING_MINION,
	&"grave_ward": NEEDS_OWN_CORPSE,
	&"raise_dead": NEEDS_OWN_CORPSE,
	&"corpse_bomb": NEEDS_OWN_LIVING_MINION,
}


## Story 6-5e (AC 28, `6-5e/R27`/G8 -- CORRECTED AT THE GATE, blocker B12): BOOM's precondition -- AT
## LEAST ONE BOULDER IN THE OPPOSING PLAYER'S HAND at the activation instant.
##
## IT IS A NEW ARM AND EXPLICITLY NOT A REUSE OF `NEEDS_ENEMY_HERO`, which is the gate's own ruling. The
## three existing requirements each read either THIS player's board (`NEEDS_OWN_LIVING_MINION`,
## `NEEDS_OWN_CORPSE`) or the caster's CAPTURED LOCK TARGET (`NEEDS_ENEMY_HERO`); none of them can express
## "the opposing hand's Boulder count", and reusing the lock-target arm would silently route Boom through
## lock-on -- a Boom pressed while locked on a minion would then refuse for the wrong reason.
##
## UNLIKE EVERY OTHER REQUIREMENT HERE IT IS REACHABLE IN LIVE PLAY, and that is worth saying because the
## two cast requirements are documented as structurally unreachable: a player can stage Boom before any
## Rocksling stone has landed and press it with the opposing hand clean, which is smoke item 6.
const NEEDS_OPPOSING_BOULDER := &"opposing_boulder"

const OPPOSING_HAND_REQUIREMENTS: Dictionary[StringName, StringName] = {
	&"boom": NEEDS_OPPOSING_BOULDER,
}

## Story 6-5f (AC 11-13, `6-5f/R10`/`R11`/`R37`): COUNTERSPELL's precondition -- A REVERSIBLE TARGET: the
## opposing player must have resolved a card this round whose effects this story knows how to undo, still
## inside the authored window, with something actually left to undo.
##
## A FIFTH ARM AND EXPLICITLY NOT A REUSE OF `NEEDS_OPPOSING_BOULDER`, on that constant's own reasoning one
## family up: the four existing requirements read this player's board, the caster's captured lock target, or
## the opposing HAND, and none of them can express "the opposing player's last resolved card is one of the
## six this story reverses". Reusing the Boulder arm would refuse a Counterspell for the wrong reason
## whenever the opponent happened to hold no Boulder.
##
## IT IS THE MOST REACHABLE REQUIREMENT IN THIS FILE, and that is worth saying because the two cast
## requirements are documented as structurally unreachable and Boom's as merely reachable: the OPENING tick
## of every round satisfies it for nobody (neither player has resolved anything), so the no-target refusal
## is the DEFAULT state of the match rather than an edge case -- smoke item 4.
##
## ONE REASON COVERS EVERY NO-TARGET CLAUSE, which is `6-5f/R37`/AC 13 exactly ("no new refusal reason").
## `6-5f/R11`'s four clauses and the interim rule for the seven `6-5g` cards are five ways for the same
## player-visible fact to be true -- there is nothing to counter -- and naming them apart would tell the
## player about this story's internal split between the six it built and the seven it deferred.
const NEEDS_COUNTER_TARGET := &"counter_target"

const COUNTERSPELL_REQUIREMENTS: Dictionary[StringName, StringName] = {
	&"counterspell": NEEDS_COUNTER_TARGET,
}

## Story 6-5c (AC 4, Discrepancy 3): `honed_bolt`'s target -- A LIVING ENEMY HERO. The requirement is
## EVALUATED AT THE SAME PRE-SPEND SEAT as the four above (`MatchState._board_refusal_reason`), which
## is what AC 4 means by "the target requirement is evaluated at the same pre-spend seat".
##
## IT HAS NO REACHABLE PLAYER-FACING CASE TODAY, AND THAT IS RECORDED RATHER THAN HIDDEN. The bolt's
## only target is the enemy hero, which exists and is alive on every tick a card can resolve at all --
## a dead hero ends the round and `advance()`'s step-1b freeze returns before step 6. So this row is
## STRUCTURALLY present and proven with a synthetic fixture, never claimed live-reachable, the
## `REASON_UNKNOWN_EFFECT_PREFIX` posture verbatim. It exists for the later cast effects (6-5d/6-5e)
## whose target the board genuinely may lack.
## STORY 6-5d (AC 27) WIDENS WHAT THIS ROW MEANS WITHOUT RENAMING IT. The requirement is now A LIVING
## CAPTURED TARGET -- the caster's lock-on target, which is the opposing hero, a minion or a totem
## (`6-5d/R6`/`R7`) -- and `MatchState._board_refusal_reason` is where that widened reading lives. The
## NAME is kept because AC 27 cites it by name as the thing that "keeps working", and because the
## RESTING lock IS the enemy hero: an unlocked caster and a caster locked on the hero both get exactly
## the pre-6-5d answer, so the widening adds cases rather than changing any existing one.
##
## STILL NO PLAYER-REACHABLE CASE (AC 27 says so): a locked unit's death snaps the lock back to a live
## hero, and a dead hero ends the round before step 6. Proven with a synthetic fixture, never claimed
## live-reachable -- the `REASON_UNKNOWN_EFFECT_PREFIX` posture, unchanged.
const NEEDS_ENEMY_HERO := &"enemy_hero"

## STORY 6-5e: `rocksling` TAKES THE ROW TOO, on its two siblings' reasoning and with their posture: a
## cast whose captured target cannot exist is refused before any spend, and it stays STRUCTURALLY
## unreachable in live play (a locked unit's death snaps the lock back to a live hero, and a dead hero ends
## the round before step 6), proven with a synthetic fixture and never claimed reachable.
##
## IT DOES NOT CONTRADICT RULING 3's DEAD-TARGET CLAUSE, and the distinction is the TICK. This row is read
## at the PRESS; ruling 3/AC 10 is about a target that dies BETWEEN the strike and a later stone's own
## launch, which is a different tick, a different seat (`_advance_bursts`) and a positive decision to
## launch anyway. Nothing here can refuse a burst already committed.
const CAST_REQUIREMENTS: Dictionary[StringName, StringName] = {
	&"honed_bolt": NEEDS_ENEMY_HERO,
	&"fireball": NEEDS_ENEMY_HERO,
	&"rocksling": NEEDS_ENEMY_HERO,
}


## The board fact `effect` cannot resolve without, or `NEEDS_NOTHING`. A null effect needs nothing:
## a cast with no injected entry resolves as `REASON_NO_EFFECT_ENTRY` and has no precondition to fail.
##
## Story 6-5c: TWO TABLES, ONE ANSWER. The cast requirements are consulted after the own-minion ones;
## the two tables share no id, so the order decides nothing today and is fixed only so a future id in
## both has one defined answer rather than an accidental one.
## Story 6-5e: THREE TABLES, STILL ONE ANSWER, on the identical reasoning -- the three share no id, so the
## order still decides nothing, and it is still fixed so a future id in two of them has one defined answer.
## Story 6-5f: FOUR TABLES, STILL ONE ANSWER, on the identical reasoning -- all four share no id, so the
## order still decides nothing, and it is still fixed so a future id in two of them has one defined answer.
static func board_requirement_for(effect: CardEffect) -> StringName:
	if effect == null:
		return NEEDS_NOTHING
	var own_minion: StringName = OWN_MINION_REQUIREMENTS.get(effect.effect_id, NEEDS_NOTHING)
	if own_minion != NEEDS_NOTHING:
		return own_minion
	var cast_requirement: StringName = CAST_REQUIREMENTS.get(effect.effect_id, NEEDS_NOTHING)
	if cast_requirement != NEEDS_NOTHING:
		return cast_requirement
	var opposing_hand: StringName = OPPOSING_HAND_REQUIREMENTS.get(effect.effect_id, NEEDS_NOTHING)
	if opposing_hand != NEEDS_NOTHING:
		return opposing_hand
	return COUNTERSPELL_REQUIREMENTS.get(effect.effect_id, NEEDS_NOTHING)


## What this cast's effect does, as one of the four named outcomes above. `effect` is the injected
## per-card CardEffect for the id just cast — null when no entry was injected for it; `flags` is
## the injected FeatureFlags, dereferenced within this call and never retained.
##
## ORDER IS LOAD-BEARING between the last two branches: the flag is consulted only AFTER the id
## has been recognised as a summon, so an UNKNOWN prefix reports itself as unknown whether the
## minion layer is on or off. Reading the flag first would make an authoring error invisible
## behind a switch.
##
## STORY 4-4 (AC 1): THE FLAG CONSULTED IS NOW THE ONE THAT OWNS THIS ID'S LAYER. The ordering
## argument this docstring already makes is UNCHANGED and now does more work: the id is recognised
## as a summon first, then classified as totem or minion, and only THEN is the owning flag read — so
## an unknown prefix still reports itself as unknown whether either layer is on or off, and a totem
## id whose kind `BalanceConfig` does not author still resolves as a summon here (the missing kind is
## the CAST SEAT's problem, not the resolver's — this file computes, it does not apply).
static func outcome(effect: CardEffect, flags: FeatureFlags) -> StringName:
	if effect == null:
		return REASON_NO_EFFECT_ENTRY
	var id := String(effect.effect_id)
	if id.begins_with(PREFIX_SUMMON):
		if _is_totem(effect.effect_id):
			return OUTCOME_SUMMON if _totems_open(flags) else REASON_TOTEMS_FLAG_CLOSED
		return OUTCOME_SUMMON if _minions_open(flags) else REASON_MINIONS_FLAG_CLOSED
	# Story 6-5a (AC 4): the WHOLE-ID matches, AFTER the summon prefix (a summon id is never a table
	# row) and BEFORE the `spell_*` prefix. The id is recognised first and the flag read only after, the
	# ordering argument this docstring already makes for the summon branch.
	var buff: StringName = BUFF_OUTCOMES.get(effect.effect_id, &"")
	if buff != &"":
		return buff if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	# Story 6-5b: the four OWN-MINION / CORPSE outcomes, in the buff lookup's own seat and order --
	# after the summon prefix, before the deferred table (their four rows just left it) and before the
	# `spell_*` prefix. The id is recognised first and the flag read only after, this docstring's
	# standing ordering argument.
	var own_minion: StringName = OWN_MINION_OUTCOMES.get(effect.effect_id, &"")
	if own_minion != &"":
		return own_minion if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	# Story 6-5c: the CAST family, in the own-minion lookup's own seat and order -- after the summon
	# prefix, before the deferred table (`honed_bolt`'s row just left it) and before the `spell_*`
	# prefix. The id is recognised first and the flag read only after, this docstring's standing
	# ordering argument. A CLOSED spell layer returns the shared closed reason here exactly as it does
	# two lines up, which is the half of AC 6 that keeps a flag-closed cast a successful, empty cast.
	var cast: StringName = CAST_OUTCOMES.get(effect.effect_id, &"")
	if cast != &"":
		return cast if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	# Story 6-5e (AC 25-28): the OPPOSING-HAND family, in the cast lookup's own seat and order -- after
	# the summon prefix, before the deferred table (`boom`'s row just left it) and before the `spell_*`
	# prefix. The id is recognised first and the flag read only after, this docstring's standing
	# ordering argument.
	var opposing_hand: StringName = OPPOSING_HAND_OUTCOMES.get(effect.effect_id, &"")
	if opposing_hand != &"":
		return opposing_hand if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	# Story 6-5f (AC 4-23/AC 27): the RETROACTIVE family, in the opposing-hand lookup's own seat and order
	# -- after the summon prefix, before the deferred table (`counterspell`'s row just left it, taking the
	# table to EMPTY) and before the `spell_*` prefix. The id is recognised first and the flag read only
	# after, this docstring's standing ordering argument.
	var retroactive: StringName = COUNTERSPELL_OUTCOMES.get(effect.effect_id, &"")
	if retroactive != &"":
		return retroactive if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	# Story 6-5e (AC 20/AC 28a): BOULDER'S OWN ACTION, in the same seat and order -- with ONE DELIBERATE
	# DIFFERENCE from every family above it: IT DOES NOT GATE ON `FeatureFlags.spells`. `clears_cover()`
	# records the reason at its own seat -- a Boulder is not a spell the holder chose to cast, and a
	# closed spell layer must not leave one stuck in a hand forever. Nothing can PLANT a Boulder while
	# the layer is closed (Rocksling never starts a cast), so the asymmetry can only ever help a player
	# clear what a previously-open layer left behind.
	var boulder: StringName = BOULDER_OUTCOMES.get(effect.effect_id, &"")
	if boulder != &"":
		return boulder
	if owner_story_for(effect.effect_id) != &"":
		return REASON_DECK1_NOT_YET_RESOLVED
	if id.begins_with(PREFIX_SPELL):
		return REASON_SPELL_NOT_YET_RESOLVED
	return REASON_UNKNOWN_EFFECT_PREFIX


## Story 6-5a (AC 15): the board key of the story that owns a deferred Deck 1 effect id, or `&""` when
## the id is not one of the nine.
static func owner_story_for(effect_id: StringName) -> StringName:
	return DEFERRED_EFFECT_OWNERS.get(effect_id, &"")


## Story 4-4 (AC 1): the UNIT KIND NAME this cast puts on the board — the second, finer question the
## prefix cannot answer (see `SUMMON_KINDS`).
##
## TOTAL OVER EVERY `summon_*` ID, by construction: a mapped id returns its own kind, an unmapped one
## returns `KIND_MINION`. That default is what keeps the three minion fixture cards' behaviour
## bit-for-bit unmoved by this story and what stops a future minion card from needing an edit here.
##
## IT COMPUTES, IT DOES NOT APPLY (D6). The returned NAME is turned into the plain int index the
## record actually stores by `BalanceConfig.kind_index_of()`, at the cast seat inside `advance()`'s
## ordered dispatch — this file never touches a board, a pool or a `BalanceConfig`.
##
## A NON-SUMMON EFFECT IS A PROGRAMMING ERROR AT THE CALL SITE, not a case handled here: the one
## caller reaches this only after `outcome()` returned `OUTCOME_SUMMON`. It still answers total
## rather than crashing — `KIND_MINION` — because a total function's honest default is this file's
## standing posture (the `REASON_NO_EFFECT_ENTRY` null branch, `CastEvaluator.refusal_reason`).
static func kind_for(effect: CardEffect) -> StringName:
	if effect == null:
		return KIND_MINION
	return SUMMON_KINDS.get(effect.effect_id, KIND_MINION)


## Whether this `summon_*` id belongs to the TOTEM layer. DERIVED FROM `SUMMON_KINDS` rather than
## listed a second time, which is the whole reason it is a function: a second literal list of totem
## ids would be a second thing to keep in agreement with the first, and the failure mode is silent
## (an id in one list and not the other gates on the wrong flag).
static func _is_totem(effect_id: StringName) -> bool:
	return SUMMON_KINDS.has(effect_id)


## NO FLAGS INJECTED READS AS CLOSED — CastEvaluator._flag_open's own reading, in the same
## direction and for the same reason: a layer that cannot be verified open stays shut. Every
## MatchState in the shipped path is handed flags at match start; a fixture that injects none is
## exercising a state that live play cannot reach, and it gets the safe answer.
static func _minions_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.minions


## Story 4-4: the TOTEM twin, in the same direction and for the same reason.
static func _totems_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.totems


## Story 6-5a (AC 16): the SPELL twin, in the same direction and for the same reason.
static func _spells_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.spells
