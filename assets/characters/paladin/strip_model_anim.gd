@tool
extends EditorScenePostImport

## Story 3-0a: the paladin MODEL (paladin.fbx) embeds a single Mixamo take, "mixamo.com"
## (Godot sanitizes it to "mixamo_com"). The hero's six clips come from six SEPARATE
## animation FBXs assembled into one AnimationPlayer; the model must contribute mesh +
## skeleton ONLY. The importer's own `animation/import=false` does NOT strip the embedded
## take in this Godot build (the AnimationPlayer + mixamo_com survive reimport), so this
## post-import hook removes any AnimationPlayer the model import produced. Result: the model
## scene is Skeleton3D + meshes with no AnimationPlayer and no mixamo_com clip.
func _post_import(scene: Node) -> Object:
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	return scene
