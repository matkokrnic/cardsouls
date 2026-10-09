extends SceneTree

## Story 7-1 (AC 8, plus the runner's hook wiring for AC 6/11/16/20/22/28/32): THE EFFECT LOOKS APPEAR ON THE REAL
## RIG, DRIVEN BY THE REAL RUNNER, FROM STATE.
##
## AC 8 IS THE REASON THIS FILE EXISTS. `6-5b`'s Grave Ward tint failed at smoke because nothing checked it on the
## SHIPPED minion scene (it tinted a child named `Mesh` the rigged minion does not have). So: a minion record is
## put on P1's board, the runner spawns the shipped `unit_actor.tscn` for it, the record is killed and its corpse
## extended -- and the corpse ACTOR must then carry the `GraveWardGlow` look AND a green overlay on a real body mesh
## of that scene. Clearing the mark (what a Counterspell's `_reverse_grave_ward` does, through the same
## `restore_corpse_at`) must remove both.
##
## STATE IS POKED DIRECTLY, the `test_cast_success_cue_live.gd` / AC 21 "right-sized poke" rationale: what is
## under test is the runner's read of state and the presenter's look, not the card plumbing that produces the
## state (pinned by its own stories). Also exercised, the same way: the Vanguard summon sound on a non-raised
## spawn; the Vampiric Aura look switching on and OFF with its rule (AC 11/AC 32 -- a Counterspell ends the rule
## through `cancel_rule`); root shackles (AC 22); the frozen legs and `frost_hit` on the slow's rising edge
## (AC 20); and a Fireball record dressed as the core look, flying, and ending on the idle hero as an IMPACT with
## `fire_hit` (AC 16).
##
## Review fix F1 (AC 9/AC 19), on P2's board so it never touches the P1 sequence: a record raised from a corpse
## with NO Counterspell is Raise Dead and gets the pillar; a Counterspell that restores a Culled minion re-adds it
## as a NEW record with the same raise marker, and that one gets NO pillar and the blue "returned" flash on its
## NEW actor.
##
## 7-1 polish round (operator smoke, 2026-10-04), `_polish`:
##   BUG 1 -- a Drain resolves on P2 (the packet written by it), then an UNBLOCKABLE resolution of the same slot
##   arrives with NO `record_resolved_card` (the real mode-2 path): the Drain look must NOT replay.
##   COUNTERSPELL -- the countered hero shows its ground circle at once; the caster swings `cast_counterspell`, and at
##   the beat the burst starts from the sword (well above the ground) and the circle settles to the caster's feet.
##   GRAVE WARD -- the look follows the corpse's HIPS bone, not the actor root.
##   BOULDER CRUST -- the pieces ride the LEG bones, at unit scale, on the legs.
##
## Run: godot --headless --path . --script res://test/integration/test_effect_presentation_live.gd

const MAX_FRAMES := 900

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _failures: Array[String] = []
var _shot_index := -1
var _shot_dead_frame := -1
var _drains_after_resolution := 0
var _rune_seen_settled := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	var runner := scene.instantiate()
	# Story 7-4 (`7-4/R15`): this test reads or acts on the DEALT hand, so it fixes the deal at the seed the
	# runner shipped as a constant before 7-4 -- set BEFORE the runner enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_effects = _runner._effects if _runner != null else null
		if _runner == null or _state == null or _effects == null:
			return _finish("missing: runner=%s state=%s effects=%s" % [_runner, _state, _effects])
		return false
	_raise_and_restore()
	_polish()
	match _frames:
		2:
			var kind := _state.balance.kind_index_of(CardEffectResolver.KIND_MINION)
			_state.p1.units.add(_state.balance.kind_at(kind).max_hp, kind)
		4:
			_check(_corpse() != null, "the runner spawned the shipped minion actor")
			_check(_effects.played.has(&"vanguard/summon"), "a non-raised minion spawn plays `summon` (AC 6)")
			_state.p1.units.kill_at(0, 600)
		5:
			_state.p1.units.extend_corpse_at(0, 60)
		8:
			var corpse := _corpse()
			_check(corpse != null and corpse.get_node_or_null(NodePath(EffectPresenter.GRAVE_WARD_NODE)) != null,
				"the extended corpse carries the Grave Ward look (AC 8)")
			_check(_overlay_meshes(corpse) > 0, "a real body mesh of the shipped minion scene glows (AC 8)")
			_check_hips_anchor(corpse)
			_state.p1.units.restore_corpse_at(0, _state.p1.units.corpse_ticks_at(0), false)
		11:
			var corpse := _corpse()
			_check(corpse != null and corpse.get_node_or_null(NodePath(EffectPresenter.GRAVE_WARD_NODE)) == null,
				"clearing the mark removes the Grave Ward look (AC 8, a Counterspell's path)")
			_check(_overlay_meshes(corpse) == 0, "and its overlay")
			_state.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 300, 0.5, 0.0)
			_state.p2.arm_root(120, true, true)
			_state.p2.start_rule(PlayerState.RULE_FROSTBITE_SLOW, 120, 0.5, 0.0)
		13:
			_check(_effects.hero_look(0, &"Aura") != null, "Vampiric Aura's look is on while the rule runs (AC 11)")
			_check(_effects.hero_look(1, &"Shackles") != null, "a root in force shows shackles (AC 22)")
			_check(_effects.hero_look(1, &"FrozenLegs") != null, "a Frostbite slow freezes the legs (AC 20)")
			_check(_effects.played.has(&"frostbite/frost_hit"), "the slow's rising edge plays `frost_hit` (AC 20)")
			_state.p1.cancel_rule(PlayerState.RULE_VAMPIRIC_AURA)
		16:
			_check(_effects.hero_look(0, &"Aura") == null, "the aura look ends with its rule (AC 11/AC 32)")
			_state.p1.projectiles.add_hero_shot(1, TargetingService.HERO_INDEX, &"fireball", 15.0)
			_shot_index = _state.p1.projectiles.size() - 1
			# AC 21: a Corpse Bomb skull leaving the minion at board index 0 (the corpse above).
			_state.p1.projectiles.add_minion_shot(1, TargetingService.HERO_INDEX, &"corpse_bomb", 5.0, 0)
		18:
			var shot := _shot_actor()
			_check(shot != null and shot.find_child("FireballCore", true, false) != null,
				"a Fireball record is dressed as the core look (AC 16)")
			_check(_effects.played.has(&"fireball/fire_launch"), "and plays `fire_launch`")
			var skull := _actor_of_shot(_shot_index + 1)
			_check(skull != null and skull.get_node_or_null(NodePath(EffectPresenter.DRESS_NODE)) != null,
				"a Corpse Bomb record is dressed as the skull look (AC 21)")
			_check(_effects.played.has(&"corpse_bomb/skull_launch"), "and plays `skull_launch` (AC 21)")
			_check(_overlay_meshes(_corpse()) > 0, "the minion the skull left glows (AC 21)")
	if _frames > 18 and _shot_index >= 0 and _shot_dead_frame < 0 \
			and not _state.p1.projectiles.is_alive_at(_shot_index):
		_shot_dead_frame = _frames
	if _shot_dead_frame > 0 and _frames == _shot_dead_frame + 2:
		_check(_effects.played.has(&"fireball/fire_hit"),
			"the Fireball ending on the idle hero is an IMPACT with `fire_hit` (AC 16, 7-1/R2)")
		return _finish("")
	if _frames >= MAX_FRAMES:
		return _finish("the Fireball record never ended within %d frames" % MAX_FRAMES)
	return false


## Review fix F1: the two raised-from branches, on P2's board (indices 0 = the culled minion, 1 = a Raise Dead
## record on its corpse, 2 = the Counterspell restore of index 0).
func _raise_and_restore() -> void:
	var kind := _state.balance.kind_index_of(CardEffectResolver.KIND_MINION)
	match _frames:
		3:
			_state.p2.units.add(_state.balance.kind_at(kind).max_hp, kind)
		5:
			# A Culling of P2's minion, as the resolver records it: the kill and the reversal packet.
			_state.p2.units.kill_at(0, 600)
			_state.p2.record_reversal(PlayerState.REVERSAL_CULLING, [0] as Array[int], [] as Array[int],
					[] as Array[int], [] as Array[bool], 0.0)
		7:
			# Raise Dead's shape: a new record carrying its corpse's index as the raise source.
			_state.p2.units.add(_state.balance.kind_at(kind).max_hp, kind, 0)
		8:
			# 7-1 polish round: the green strike hits the corpse first; the pillar rises `strike_lead` later.
			_check(_effects.find_child("LightningStrike", false, false) != null,
				"a green lightning strike hits the corpse before the pillar (Raise Dead, polish 11)")
		9:
			# P1's Counterspell reverses P2's Culling: the killed minion comes back as a NEW record (raised from 0).
			_state._apply_counterspell(_state.p1, 0)
		10:
			_check(_state.p2.units.size() == 3 and _state.p2.units.raised_from_at(2) == 0,
				"the Counterspell restored the culled minion as a new record raised from its corpse")
			_check(_overlay_meshes(_actor_of_unit(1, 2)) > 0,
				"the restored minion's NEW actor flashes blue (F1, AC 19)")
			_check(_effects.played.has(&"counterspell/counter"), "and `counter` plays (AC 19)")
			_check(_rune_of(_runner._p2_hero) != null, "the COUNTERED hero shows its ground rune circle at once (AC 19)")
			var caster_anim: AnimationPlayer = _runner._p1_hero.animation_controller.animation_player
			_check(caster_anim.current_animation == &"cast_counterspell",
				"the standing caster swings cast_counterspell (polish 2; got %s)" % caster_anim.current_animation)
		22:
			# The pillar rose after the strike's lead: exactly ONE -- Raise Dead's, none for the restore (F1, AC 9).
			_check(_pillar_count() == 1, "one Raise Dead pillar, none for the Counterspell restore (F1, AC 9; got %d)"
					% _pillar_count())
		12:
			# Done with them: two live P2 minions would walk into P1's hero and swing for the rest of the file, and a
			# hero `CueHit` still playing at quit is "resources still in use at exit" (measured: `cue_hit.wav`).
			_state.p2.units.kill_at(1, 600)
			_state.p2.units.kill_at(2, 600)


## The 7-1 polish round's checks (header). P2's board index 3 is the Drain's minion; P1 holds the Boulders and is the
## Counterspell caster of `_raise_and_restore`'s frame 9.
func _polish() -> void:
	match _frames:
		20:
			var kind := _state.balance.kind_index_of(CardEffectResolver.KIND_MINION)
			_state.p2.units.add(_state.balance.kind_at(kind).max_hp, kind)
			_state.p1.hand.cover_at(0, &"boulder")
			_state.p1.hand.cover_at(1, &"boulder")
		22:
			# The burst at the beat (0.15 s after frame 9's Counterspell) is from the SWORD at the swing's peak.
			var burst := _effects.find_child("CounterBurst", false, false) as Node3D
			_check(burst != null, "the caster's rune circle bursts at the swing's peak (polish 2)")
			if burst != null:
				_check(burst.global_position.y > 1.2,
					"...from the raised sword, not the ground (y %.2f)" % burst.global_position.y)
		23:
			# BUG 1, part one: a Drain that WROTE its packet this resolution shows (the real BASIC path).
			_state.p2.record_resolved_card(&"drain", Enums.ModeKind.BASIC, _state._tick)
			_state.p2.record_reversal(PlayerState.REVERSAL_DRAIN, [3] as Array[int], [] as Array[int],
					[] as Array[int], [] as Array[bool], 0.0)
			_state.card_cast_resolved.emit(1, &"drain", Enums.ModeKind.BASIC)
			_drains_after_resolution = _effects.played.count(&"drain/drain")
			_check(_drains_after_resolution == 1, "a Drain resolution shows its look once (got %d)"
					% _drains_after_resolution)
			_check_leg_crust()
		26:
			# BUG 1, part two: an unblockable resolution writes no packet (no `record_resolved_card`), so the Drain's
			# packet is still live -- and must not be shown again.
			_state.card_cast_resolved.emit(1, &"drain", Enums.ModeKind.UNBLOCKABLE)
			_check(_effects.played.count(&"drain/drain") == _drains_after_resolution,
				"an unblockable initiation after a Drain does NOT replay the Drain look (bug 1; %d -> %d)"
						% [_drains_after_resolution, _effects.played.count(&"drain/drain")])
			_state.p2.units.kill_at(3, 600)
			_state.p1.hand.clear_covers()
		30:
			_check(_effects.hero_look(0, &"BoulderCrust") == null, "the crust is gone with the Boulders (AC 13)")
	# The caster's circle settles to the feet (0.15 s beat + 0.2 s settle after frame 9).
	if _frames >= 34 and _frames <= 50 and not _rune_seen_settled:
		var rune := _rune_of(_runner._p1_hero)
		if rune != null and absf(rune.position.y - (EffectPresenter.HERO_FEET_Y + 0.04)) < 0.01:
			_rune_seen_settled = true
	if _frames == 50:
		_check(_rune_seen_settled, "the caster's rune circle settles on the ground at its feet (polish 2)")


## 7-1 polish round (9): the Grave Ward look follows the corpse's hips bone.
func _check_hips_anchor(corpse: Node3D) -> void:
	var anchor := corpse.get_node_or_null(NodePath("%s/HipsAnchor" % EffectPresenter.GRAVE_WARD_NODE)) as Node3D
	var skeletons := corpse.find_children("*", "Skeleton3D", true, false)
	_check(anchor != null and not skeletons.is_empty(), "the Grave Ward look has a hips anchor on a rigged corpse")
	if anchor == null or skeletons.is_empty():
		return
	var skel := skeletons[0] as Skeleton3D
	var bone := skel.find_bone(EffectPresenter.HIPS_BONE)
	_check(bone >= 0, "the minion rig has the %s bone" % EffectPresenter.HIPS_BONE)
	if bone < 0:
		return
	var hips := skel.global_transform * skel.get_bone_global_pose(bone).origin
	var off := Vector2(anchor.global_position.x - hips.x, anchor.global_position.z - hips.z).length()
	_check(off < 0.05 and absf(anchor.global_position.y - hips.y) < 0.05,
		"the Grave Ward look sits on the corpse's hips (off by %.3f m planar, anchor %s, hips %s)"
				% [off, anchor.global_position, hips])


## 7-1 polish round (10): two Boulders show their pieces ON the leg bones, at unit scale, below the hips.
func _check_leg_crust() -> void:
	var crust := _effects.hero_look(0, &"BoulderCrust")
	_check(crust != null, "P1's Boulders show a crust")
	if crust == null:
		return
	var pieces: Array[Node3D] = crust.get_meta(&"crust_pieces")
	var shown := 0
	var hero: Node3D = _runner._p1_hero
	for piece: Node3D in pieces:
		if not piece.visible:
			continue
		shown += 1
		var attach := piece.get_parent() as BoneAttachment3D
		_check(attach != null and EffectPresenter.LEG_BONES.has(attach.bone_name),
			"a crust piece rides a leg bone (parent %s)" % piece.get_parent())
		if attach == null:
			continue
		var scale := piece.global_transform.basis.get_scale()
		_check(absf(scale.x - 1.0) < 0.05, "a crust piece is at unit scale on its bone (%s)" % scale)
		_check(piece.global_position.distance_to(attach.global_position) < 0.5,
			"a crust piece sits on its bone (%.2f m away)" % piece.global_position.distance_to(attach.global_position))
		var height := piece.global_position.y - (hero.global_position.y + EffectPresenter.HERO_FEET_Y)
		_check(height > 0.0 and height < 1.0, "a crust piece is on the legs (%.2f m above the feet)" % height)
	_check(shown == 6, "two Boulders show six pieces (got %d)" % shown)


func _rune_of(hero: Node3D) -> Node3D:
	if hero == null:
		return null
	for child: Node in hero.get_children():
		if String(child.name).begins_with("CounterRune") and not child.is_queued_for_deletion():
			return child as Node3D
	return null


## Raise Dead's pillar is the presenter's one CYLINDER look (`show_raise`). Counted by mesh, not by node name: a
## second pillar added beside a live first one is renamed by the engine.
func _pillar_count() -> int:
	var count := 0
	for child: Node in _effects.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh \
				and not child.is_queued_for_deletion():
			count += 1
	return count


func _actor_of_unit(slot: int, index: int) -> Node3D:
	var actors: Array = _runner._unit_actors[slot]
	if index < 0 or index >= actors.size() or not is_instance_valid(actors[index]):
		return null
	return actors[index] as Node3D


func _corpse() -> Node3D:
	var actors: Array = _runner._unit_actors[0]
	if actors.is_empty() or not is_instance_valid(actors[0]):
		return null
	return actors[0] as Node3D


func _shot_actor() -> Node3D:
	return _actor_of_shot(_shot_index)


func _actor_of_shot(index: int) -> Node3D:
	var actors: Array = _runner._projectile_actors[0]
	if index < 0 or index >= actors.size() or not is_instance_valid(actors[index]):
		return null
	return actors[index] as Node3D


func _overlay_meshes(actor: Node3D) -> int:
	if actor == null:
		return 0
	var count := 0
	for node: Node in actor.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).material_overlay != null:
			count += 1
	return count


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	# Effect sounds still playing must be retired before quit (`EffectPresenter.stop_all_sounds`).
	if _effects != null:
		_effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
	return true
