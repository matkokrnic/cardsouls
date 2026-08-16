@tool
extends EditorScenePostImport

## Story 4-3c (AC 3): the skeleton-zombie MODEL (skeletonzombie.fbx) embeds a single Mixamo
## take, "mixamo.com" (Godot sanitizes it to "mixamo_com") -- measured, not assumed: the
## dev pass probed the imported scene and found exactly one AnimationPlayer holding exactly
## that clip. The minion's four clips come from four SEPARATE animation FBXs assembled into
## one AnimationLibrary; the model must contribute mesh + skeleton ONLY.
##
## THE NAMED-BROKEN ROUTE IS NOT RE-ATTEMPTED (3-0a/R10, carried forward by 4-3c AC 3). The
## importer's own `animation/import=false` does NOT strip the embedded take on this engine
## build (4.6.3) -- 3-0a already measured it broken and that finding travels forward rather
## than being re-discovered. `animation/import=false` is still set on the model's .import for
## intent, and THIS hook is what actually removes the AnimationPlayer the model import
## produces. Result: the model scene is Skeleton3D + meshes with no AnimationPlayer and no
## mixamo_com clip.
##
## A VERBATIM COUNTERPART of assets/characters/paladin/strip_model_anim.gd, copied rather
## than shared: an import script lives beside its source asset (the artifact shape 3-0a
## established and game-architecture.md's Directory Tree already itemizes generically), and
## a single shared hook would couple two characters' import pipelines for no gain.
func _post_import(scene: Node) -> Object:
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	return scene
