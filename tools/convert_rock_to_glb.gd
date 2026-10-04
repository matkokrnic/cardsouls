extends SceneTree

## Story 7-1 review fix (P5): CONVERTS the staged rock FBX into the MATERIAL-LESS `assets/models/rock/rock.glb`.
##
## WHY: the staged `Rock-Mesh.fbx` references its four 4096 px source PNGs by path (`Rock_MAT_*.png`), which are
## raw sources and never enter the repo (AC 31). Shipped as an FBX, every fresh import of it logged eight
## "Can't open file" / "Resource file not found" errors and four FBX warnings. The presenter overrides the rock's
## material with the 1024 px textures anyway (`EffectPresenter._rock_material`), so the mesh needs no material
## at all: this tool loads the FBX at RUNTIME (`FBXDocument`, no editor import), strips every material, and
## writes the geometry out as glTF binary. The texture-path errors this run prints are the conversion reading the
## staged file; the written `.glb` names no texture.
##
## ONE-SHOT. Reads the staged source (outside the repo, `tools/ingest_effect_assets.py`'s `--assets` tree) and
## writes only the `.glb`; the `.glb.import` sidecar comes from the next `--headless --editor --quit` scan.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/convert_rock_to_glb.gd -- C:/dev/_assets-71/models/rock/source/Rock-Mesh.fbx

const DEFAULT_SOURCE := "C:/dev/_assets-71/models/rock/source/Rock-Mesh.fbx"
const OUT_PATH := "res://assets/models/rock/rock.glb"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if not args.is_empty() else DEFAULT_SOURCE
	var fbx := FBXDocument.new()
	var fbx_state := FBXState.new()
	var err := fbx.append_from_file(source, fbx_state)
	if err != OK:
		push_error("convert_rock_to_glb: cannot read %s (error %d)" % [source, err])
		quit(1)
		return
	var scene := fbx.generate_scene(fbx_state)
	if scene == null:
		push_error("convert_rock_to_glb: no scene generated from %s" % source)
		quit(1)
		return
	var meshes := 0
	var surfaces := 0
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = null
		for i in mesh_instance.get_surface_override_material_count():
			mesh_instance.set_surface_override_material(i, null)
		var mesh := mesh_instance.mesh
		if mesh != null:
			mesh = mesh.duplicate()
			for i in mesh.get_surface_count():
				mesh.surface_set_material(i, null)
				surfaces += 1
			mesh_instance.mesh = mesh
		meshes += 1
	var gltf := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	err = gltf.append_from_scene(scene, gltf_state)
	if err == OK:
		err = gltf.write_to_filesystem(gltf_state, OUT_PATH)
	scene.free()
	if err != OK:
		push_error("convert_rock_to_glb: cannot write %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("convert_rock_to_glb: %d mesh(es), %d surface(s), materials stripped -> %s (%d B)" % [
		meshes, surfaces, OUT_PATH, FileAccess.get_file_as_bytes(OUT_PATH).size()])
	quit(0)
