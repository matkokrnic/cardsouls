@tool
extends EditorScenePostImport

## Story 7-5b (AC 9): the Healer MODEL (healer.fbx, Mixamo "Knight D Pelegrini") embeds the Mixamo take
## the importer names `mixamo_com`; its five clips come from five SEPARATE animation FBXs assembled into
## one AnimationLibrary by `tools/build_healer_anims.gd`, so the model must contribute mesh + skeleton ONLY.
##
## The `4-3c` route verbatim (`3-0a/R10`): the importer's own `animation/import=false` does not strip the
## embedded take on this engine build (4.6.3); it is still set on the model's .import for intent, and THIS
## hook is what removes the AnimationPlayer the model import produces.
##
## A COUNTERPART of assets/characters/skeletonzombie/strip_model_anim.gd, copied rather than shared: an
## import script lives beside its source asset, and a shared hook would couple two characters' import
## pipelines for no gain. Localised to healer.fbx: the five clip imports carry `import_script/path=""`.
func _post_import(scene: Node) -> Object:
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	return scene
