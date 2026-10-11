@tool
extends EditorScenePostImport

## Story 7-3 (AC 17): `SK_Hellhound.fbx` is ONE file holding the mesh, the skeleton and every take.
## One of those takes, `T_Pose`, is the bind pose and not an animation; it is removed here, at
## import time, so no scene or library built from this model can ever select it.
##
## LOCALIZED TO THIS ONE FBX, on the `assets/characters/skeletonzombie/strip_model_anim.gd`
## precedent (an import script lives beside its source asset; a shared hook would couple two
## characters' import pipelines). THE DIFFERENCE FROM THAT HOOK IS DELIBERATE: the zombie's model
## carries one throwaway Mixamo take and its clips come from separate FBXs, so its hook frees the
## whole AnimationPlayer. This pack's takes ARE the clips, so the player stays and only the one
## named take goes. `tools/build_hellhound_anims.gd` then lifts the takes the hound uses into
## `hellhound_anims.res`.
##
## MATCHED BY NORMALIZED NAME, not by one spelling: the importer sanitizes take names, so the
## comparison drops case, underscores, spaces and dashes ("T_Pose", "T-Pose", "TPose" all match).
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for clip in library.get_animation_list():
				if _is_t_pose(clip):
					library.remove_animation(clip)
	return scene


static func _is_t_pose(clip: StringName) -> bool:
	var plain := String(clip).to_lower().replace("_", "").replace(" ", "").replace("-", "")
	return plain == "tpose" or plain.ends_with("|tpose")
