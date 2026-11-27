extends RefCounted

const PbrAssets := preload("res://scripts/gameplay/pbr_assets.gd")

static var _scene_cache: Dictionary = {}
static var _palette_mat_cache: Dictionary = {}

static func _get_palette_for_model(res_path: String) -> String:
	var fname := res_path.get_file()
	if fname.begins_with("castle_") or fname.begins_with("siege_") or fname.begins_with("rock_"):
		return "res://assets/models/textures/colormap_castle.png"
	if fname in ["fence.glb", "cart.glb", "lantern.glb", "stall.glb", "windmill_blade.glb"]:
		return "res://assets/models/textures/colormap_town.png"
	if fname == "barrel.glb":
		return "res://assets/models/textures/barrel_tex.png"
	return ""

static func _get_palette_material(tex_path: String) -> StandardMaterial3D:
	if _palette_mat_cache.has(tex_path):
		return _palette_mat_cache[tex_path]
	var tex := PbrAssets._load_tex(tex_path)
	if tex == null:
		return null
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_palette_mat_cache[tex_path] = mat
	return mat

static func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

static func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	if node != owner_node:
		node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)

static func instantiate_glb(res_path: String) -> Node3D:
	var instance: Node3D = null
	if _scene_cache.has(res_path):
		var cached = _scene_cache[res_path]
		if cached is PackedScene:
			instance = cached.instantiate() as Node3D

	if instance == null and ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is PackedScene:
			_scene_cache[res_path] = res
			instance = res.instantiate() as Node3D

	if instance == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(abs_path, state) == OK:
				var node := doc.generate_scene(state)
				if node is Node3D:
					var pal_path := _get_palette_for_model(res_path)
					if pal_path != "":
						var pmat := _get_palette_material(pal_path)
						if pmat != null:
							_apply_material_recursive(node, pmat)
					_set_owner_recursive(node, node)
					var ps := PackedScene.new()
					if ps.pack(node) == OK:
						_scene_cache[res_path] = ps
						node.free()
						return ps.instantiate() as Node3D
					return node as Node3D

	if instance != null:
		var pal_path := _get_palette_for_model(res_path)
		if pal_path != "":
			var pmat := _get_palette_material(pal_path)
			if pmat != null:
				_apply_material_recursive(instance, pmat)
	return instance
