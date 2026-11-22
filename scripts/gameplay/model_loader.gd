extends RefCounted

static var _scene_cache: Dictionary = {}

static func instantiate_glb(res_path: String) -> Node3D:
	if _scene_cache.has(res_path):
		var cached = _scene_cache[res_path]
		if cached is PackedScene:
			return cached.instantiate() as Node3D

	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is PackedScene:
			_scene_cache[res_path] = res
			return res.instantiate() as Node3D

	# Runtime fallback for direct Windows CLI execution before Godot Editor import
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(abs_path, state) == OK:
			var node := doc.generate_scene(state)
			if node is Node3D:
				return node
	return null
