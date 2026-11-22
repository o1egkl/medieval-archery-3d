extends RefCounted

static var _cache: Dictionary = {}

static func get_grass_texture() -> ImageTexture:
	if _cache.has("grass"):
		return _cache["grass"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(128):
		for x in range(128):
			var n := rng.randf_range(-0.06, 0.06)
			var wave := sin(float(x) * 0.14) * cos(float(y) * 0.14) * 0.04
			var c := Color(
				clampf(0.32 + n + wave, 0.0, 1.0),
				clampf(0.56 + n * 1.2 + wave, 0.0, 1.0),
				clampf(0.18 + n * 0.5, 0.0, 1.0),
				1.0
			)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache["grass"] = tex
	return tex

static func get_wood_texture() -> ImageTexture:
	if _cache.has("wood"):
		return _cache["wood"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var grain := sin(float(x) * 0.55 + sin(float(y) * 0.12) * 1.8) * 0.06
			var c := Color(
				clampf(0.42 + grain, 0.0, 1.0),
				clampf(0.26 + grain * 0.7, 0.0, 1.0),
				clampf(0.13 + grain * 0.4, 0.0, 1.0),
				1.0
			)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache["wood"] = tex
	return tex

static func get_stone_texture() -> ImageTexture:
	if _cache.has("stone"):
		return _cache["stone"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var row := int(y / 16)
			var ox := (x + (row % 2) * 16) % 32
			var oy := y % 16
			var mortar := (ox < 2 or oy < 2)
			var base_v := 0.42 if mortar else (0.58 + float((row * 7 + int((x + row * 16) / 32) * 13) % 7) * 0.02)
			img.set_pixel(x, y, Color(base_v, base_v * 0.99, base_v * 0.96, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_cache["stone"] = tex
	return tex

static func get_tent_stripes(col_a: Color, col_b: Color, key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(64):
			var stripe := int(x / 8) % 2 == 0
			img.set_pixel(x, y, col_a if stripe else col_b)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func get_target_face_texture() -> ImageTexture:
	if _cache.has("target_face"):
		return _cache["target_face"]
	var sz := 256
	var half := float(sz) * 0.5
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var dx := (float(x) - half) / half
			var dy := (float(y) - half) / half
			var r := sqrt(dx * dx + dy * dy)
			var c := Color(0.78, 0.64, 0.36) # braided straw rim
			if r > 0.86:
				var weave := sin(atan2(dy, dx) * 32.0 + r * 24.0) * 0.05
				c = Color(0.80 + weave, 0.66 + weave, 0.36 + weave * 0.5)
			elif r > 0.72:
				c = Color(0.95, 0.94, 0.91) # white ring
			elif r > 0.52:
				c = Color(0.16, 0.54, 0.86) # blue ring
			elif r > 0.30:
				c = Color(0.88, 0.22, 0.16) # red ring
			else:
				c = Color(0.98, 0.82, 0.12) # golden bullseye
			# Thin dark ring separators for crisp mobile readability
			if absf(r - 0.86) < 0.015 or absf(r - 0.72) < 0.012 or absf(r - 0.52) < 0.012 or absf(r - 0.30) < 0.012 or absf(r - 0.12) < 0.010:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache["target_face"] = tex
	return tex
