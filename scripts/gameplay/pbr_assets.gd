extends RefCounted

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_tex_cache[path] = res
			return res
	return null

static func get_sky_texture(biome: String) -> Texture2D:
	var fname := "sky_day.jpg"
	match biome:
		"forest":
			fname = "sky_dusk.jpg"
		"fortress":
			fname = "sky_night.jpg"
	return _load_tex("res://assets/sky/" + fname)

static func get_pbr_material(name_key: String, uv_scale: Vector3 = Vector3.ONE, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var cache_id := "%s_%s_%s" % [name_key, str(uv_scale), tint.to_html()]
	if _mat_cache.has(cache_id):
		return _mat_cache[cache_id]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.uv1_scale = uv_scale

	var alb := _load_tex("res://assets/textures/%s_albedo.jpg" % name_key)
	if alb != null:
		mat.albedo_texture = alb
	var nrm := _load_tex("res://assets/textures/%s_normal.jpg" % name_key)
	if nrm != null:
		mat.normal_enabled = true
		mat.normal_texture = nrm
		mat.normal_scale = 0.9
	var rgh := _load_tex("res://assets/textures/%s_roughness.jpg" % name_key)
	if rgh != null:
		mat.roughness_texture = rgh
	else:
		mat.roughness = 0.85

	_mat_cache[cache_id] = mat
	return mat

static func make_ground_shader_material(biome_tint: Color) -> ShaderMaterial:
	var sh: Shader = load("res://assets/shaders/ground_blend.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("grass_albedo", _load_tex("res://assets/textures/grass_albedo.jpg"))
	mat.set_shader_parameter("grass_normal", _load_tex("res://assets/textures/grass_normal.jpg"))
	mat.set_shader_parameter("grass_roughness", _load_tex("res://assets/textures/grass_roughness.jpg"))
	mat.set_shader_parameter("dirt_albedo", _load_tex("res://assets/textures/dirt_albedo.jpg"))
	mat.set_shader_parameter("dirt_normal", _load_tex("res://assets/textures/dirt_normal.jpg"))
	mat.set_shader_parameter("dirt_roughness", _load_tex("res://assets/textures/dirt_roughness.jpg"))
	mat.set_shader_parameter("grass_tint", Color(0.76, 1.06, 0.62) * biome_tint)
	mat.set_shader_parameter("dirt_tint", Color(1.05, 0.94, 0.78) * biome_tint)
	mat.set_shader_parameter("uv_scale", 30.0)
	return mat

static func make_flag_shader_material(flag_col: Color, stripe_col: Color, wind_spd: float) -> ShaderMaterial:
	var sh: Shader = load("res://assets/shaders/flag_wind.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("flag_color", flag_col)
	mat.set_shader_parameter("stripe_color", stripe_col)
	mat.set_shader_parameter("wind_strength", maxf(absf(wind_spd), 1.5))
	return mat
