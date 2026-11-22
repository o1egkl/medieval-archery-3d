extends Node3D

const ArrowScript := preload("res://scripts/gameplay/arrow.gd")
const TargetScript := preload("res://scripts/gameplay/target.gd")
const BowControllerScript := preload("res://scripts/gameplay/bow_controller.gd")
const ProcTex := preload("res://scripts/gameplay/procedural_textures.gd")

signal hud_updated(state: Dictionary)
signal hit_feedback(kind: String, points: int)
signal level_finished(result: Dictionary)

var camera: Camera3D
var _env_root: Node3D
var _targets_root: Node3D
var _arrows_root: Node3D
var _flags: Array[MeshInstance3D] = []
var _windmill_blades: Node3D

var level_cfg: Dictionary = {}
var score: int = 0
var arrows_left: int = 0
var arrows_total: int = 0
var wind_speed: float = 0.0
var wind_dir: float = 1.0
var time_left: float = 0.0
var combo_streak: int = 0
var bullseye_streak: int = 0
var max_bullseye_streak: int = 0
var active_arrows: int = 0
var level_active: bool = false
var _wind_timer: float = 0.0

func _ready() -> void:
	camera = BowControllerScript.new()
	add_child(camera)
	camera.shot_fired.connect(_on_shot_fired)

	_env_root = Node3D.new()
	add_child(_env_root)
	_targets_root = Node3D.new()
	add_child(_targets_root)
	_arrows_root = Node3D.new()
	add_child(_arrows_root)

	# Show scenic tournament showcase behind the Main Menu right away
	show_menu_backdrop()

func show_menu_backdrop() -> void:
	stop_level()
	_clear_scene()
	wind_speed = 3.5
	_build_biome("tournament")
	for tcfg in [
		{"type": "static", "x": -4.2, "y": 1.6, "z": -16.0, "radius": 0.9, "speed": 0.0, "amplitude": 0.0},
		{"type": "rail", "x": 0.0, "y": 1.7, "z": -26.0, "radius": 0.85, "speed": 0.7, "amplitude": 2.4},
		{"type": "static", "x": 4.4, "y": 1.6, "z": -22.0, "radius": 0.85, "speed": 0.0, "amplitude": 0.0}
	]:
		var t := TargetScript.new()
		_targets_root.add_child(t)
		t.setup(tcfg)
	camera.reset_aim()

func start_level(level_id: int) -> void:
	_clear_scene()
	level_cfg = GameConfig.get_level(level_id)
	score = 0
	arrows_total = int(level_cfg.get("arrows", 6))
	arrows_left = arrows_total
	time_left = float(level_cfg.get("time_limit_sec", 0))
	combo_streak = 0
	bullseye_streak = 0
	max_bullseye_streak = 0
	active_arrows = 0
	level_active = true

	wind_dir = -1.0 if randf() < 0.5 else 1.0
	wind_speed = randf_range(float(level_cfg.get("wind_min", 0.0)), float(level_cfg.get("wind_max", 0.0))) * wind_dir

	_build_biome(str(level_cfg.get("biome", "village")))
	for tcfg in level_cfg.get("targets", []):
		var t := TargetScript.new()
		_targets_root.add_child(t)
		t.setup(tcfg)

	camera.reset_aim()
	camera.input_enabled = true
	_emit_hud()

func stop_level() -> void:
	level_active = false
	camera.input_enabled = false
	camera.cancel_draw()

func _clear_scene() -> void:
	_flags.clear()
	_windmill_blades = null
	for n in _env_root.get_children():
		n.queue_free()
	for n in _targets_root.get_children():
		n.queue_free()
	for n in _arrows_root.get_children():
		n.queue_free()

func _build_biome(biome: String) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34.0, 32.0, 0.0)
	var quality := str(SaveManager.get_setting("graphics_quality", "medium"))
	light.shadow_enabled = (quality != "low")

	var ground_tint := Color(1.0, 1.0, 1.0)
	match biome:
		"village":
			sky_mat.sky_top_color = Color(0.24, 0.56, 0.92)
			sky_mat.sky_horizon_color = Color(0.76, 0.88, 0.98)
			sky_mat.ground_bottom_color = Color(0.22, 0.36, 0.16)
			sky_mat.ground_horizon_color = Color(0.55, 0.68, 0.50)
			light.light_color = Color(1.0, 0.96, 0.86)
			light.light_energy = 1.35
		"tournament":
			sky_mat.sky_top_color = Color(0.18, 0.52, 0.94)
			sky_mat.sky_horizon_color = Color(0.78, 0.90, 1.0)
			sky_mat.ground_bottom_color = Color(0.20, 0.38, 0.14)
			sky_mat.ground_horizon_color = Color(0.52, 0.70, 0.48)
			light.light_color = Color(1.0, 0.95, 0.82)
			light.light_energy = 1.45
		"forest":
			sky_mat.sky_top_color = Color(0.26, 0.24, 0.42)
			sky_mat.sky_horizon_color = Color(0.88, 0.50, 0.30)
			sky_mat.ground_bottom_color = Color(0.14, 0.18, 0.12)
			sky_mat.ground_horizon_color = Color(0.44, 0.32, 0.24)
			env.fog_enabled = true
			env.fog_light_color = Color(0.72, 0.48, 0.36)
			env.fog_density = 0.008
			light.light_color = Color(1.0, 0.72, 0.48)
			light.light_energy = 1.05
			ground_tint = Color(0.72, 0.74, 0.62)
		"fortress":
			sky_mat.sky_top_color = Color(0.04, 0.07, 0.16)
			sky_mat.sky_horizon_color = Color(0.12, 0.16, 0.28)
			sky_mat.ground_bottom_color = Color(0.06, 0.07, 0.10)
			sky_mat.ground_horizon_color = Color(0.14, 0.16, 0.24)
			env.fog_enabled = true
			env.fog_light_color = Color(0.12, 0.15, 0.26)
			env.fog_density = 0.008
			light.light_color = Color(0.68, 0.78, 1.0)
			light.light_energy = 0.65
			ground_tint = Color(0.45, 0.48, 0.52)

	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65 if biome != "fortress" else 0.45
	world_env.environment = env
	_env_root.add_child(world_env)
	_env_root.add_child(light)

	# Textured sunlit grass arena + sandy dirt shooting lanes
	var ground := StaticBody3D.new()
	var gmesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140.0, 180.0)
	gmesh.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = ProcTex.get_grass_texture()
	gmat.albedo_color = ground_tint
	gmat.uv1_scale = Vector3(26.0, 26.0, 1.0)
	gmat.roughness = 0.92
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(140.0, 0.5, 180.0)
	gcol.shape = gshape
	gcol.position.y = -0.25
	ground.add_child(gcol)
	ground.position = Vector3(0.0, 0.0, -55.0)
	_env_root.add_child(ground)

	# Worn dirt path strip downrange
	var dirt := MeshInstance3D.new()
	var dpm := PlaneMesh.new()
	dpm.size = Vector2(6.5, 82.0)
	dirt.mesh = dpm
	dirt.position = Vector3(0.0, 0.015, -42.0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.68, 0.58, 0.38) * ground_tint
	dmat.roughness = 0.96
	dirt.material_override = dmat
	_env_root.add_child(dirt)

	# Rolling medieval green hills on the horizon
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.28, 0.50, 0.22) * ground_tint
	hill_mat.roughness = 0.95
	for hspec in [
		{"pos": Vector3(-36.0, -4.0, -98.0), "scale": Vector3(48.0, 14.0, 24.0)},
		{"pos": Vector3(34.0, -4.5, -104.0), "scale": Vector3(52.0, 16.0, 26.0)},
		{"pos": Vector3(0.0, -6.0, -118.0), "scale": Vector3(72.0, 18.0, 28.0)}
	]:
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		hill.mesh = sm
		hill.position = hspec["pos"]
		hill.scale = hspec["scale"]
		hill.material_override = hill_mat
		_env_root.add_child(hill)

	# Wooden medieval fences enclosing the left & right sides
	_build_fences()
	# Heraldic wind flags along both edges
	_build_wind_flags()

	# Biome-specific medieval landmarks
	match biome:
		"tournament":
			_build_castle(Vector3(6.0, 0.0, -86.0))
			_build_pavilion(Vector3(-12.5, 0.0, -18.0), Color(0.84, 0.20, 0.18), Color(0.95, 0.92, 0.85), "tent_rw")
			_build_pavilion(Vector3(-14.5, 0.0, -34.0), Color(0.18, 0.42, 0.82), Color(0.95, 0.82, 0.22), "tent_by")
			_build_pavilion(Vector3(12.5, 0.0, -20.0), Color(0.18, 0.42, 0.82), Color(0.95, 0.82, 0.22), "tent_by")
			_build_pavilion(Vector3(14.0, 0.0, -38.0), Color(0.84, 0.20, 0.18), Color(0.95, 0.92, 0.85), "tent_rw")
		"village":
			_build_windmill(Vector3(-14.0, 0.0, -48.0))
			_build_castle(Vector3(16.0, 0.0, -96.0))
			_build_trees(10, ground_tint)
		"forest":
			_build_trees(26, ground_tint)
			_build_torch(Vector3(-6.0, 0.0, -18.0))
			_build_torch(Vector3(6.0, 0.0, -22.0))
		"fortress":
			_build_castle(Vector3(0.0, 0.0, -78.0))
			for tx in [-7.0, 7.0]:
				for tz in [-18.0, -38.0, -56.0]:
					_build_torch(Vector3(tx, 0.0, tz))
			if quality != "low":
				var rain := CPUParticles3D.new()
				rain.amount = 140 if quality == "high" else 70
				rain.lifetime = 1.4
				rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				rain.emission_box_extents = Vector3(18.0, 1.0, 28.0)
				rain.direction = Vector3(0.15 * signf(wind_speed), -1.0, 0.0)
				rain.initial_velocity_min = 14.0
				rain.initial_velocity_max = 18.0
				rain.position = Vector3(0.0, 12.0, -28.0)
				var rmesh := BoxMesh.new()
				rmesh.size = Vector3(0.02, 0.35, 0.02)
				rain.mesh = rmesh
				_env_root.add_child(rain)

func _build_fences() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = ProcTex.get_wood_texture()
	wood_mat.roughness = 0.88
	for side in [-1.0, 1.0]:
		var x := side * 9.5
		for i in range(14):
			var z := -8.0 - float(i) * 4.8
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.18, 1.25, 0.18)
			post.mesh = pm
			post.position = Vector3(x, 0.62, z)
			post.material_override = wood_mat
			_env_root.add_child(post)
			for ry in [0.42, 0.96]:
				var rail := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.10, 0.12, 4.8)
				rail.mesh = rm
				rail.position = Vector3(x, ry, z - 2.4)
				rail.material_override = wood_mat
				_env_root.add_child(rail)

func _build_wind_flags() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = ProcTex.get_wood_texture()
	var colors := [Color(0.82, 0.18, 0.16), Color(0.16, 0.40, 0.82), Color(0.92, 0.76, 0.18)]
	var idx := 0
	for side in [-1.0, 1.0]:
		for dist in [16.0, 32.0, 48.0]:
			var pole := MeshInstance3D.new()
			var pcyl := CylinderMesh.new()
			pcyl.top_radius = 0.06
			pcyl.bottom_radius = 0.08
			pcyl.height = 5.4
			pole.mesh = pcyl
			pole.position = Vector3(side * 9.0, 2.7, -dist)
			pole.material_override = wood_mat
			_env_root.add_child(pole)

			var flag := MeshInstance3D.new()
			var fbox := BoxMesh.new()
			fbox.size = Vector3(2.2, 0.68, 0.05)
			flag.mesh = fbox
			flag.position = Vector3(side * 9.0, 4.95, -dist)
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = colors[idx % colors.size()]
			flag.material_override = fmat
			_env_root.add_child(flag)
			_flags.append(flag)
			idx += 1

func _build_pavilion(pos: Vector3, col_a: Color, col_b: Color, tex_key: String) -> void:
	var root := Node3D.new()
	root.position = pos
	_env_root.add_child(root)

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_texture = ProcTex.get_tent_stripes(col_a, col_b, tex_key)
	tent_mat.roughness = 0.85

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.6
	bm.bottom_radius = 2.9
	bm.height = 3.2
	bm.radial_segments = 16
	base.mesh = bm
	base.position.y = 1.6
	base.material_override = tent_mat
	root.add_child(base)

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.08
	rm.bottom_radius = 3.1
	rm.height = 2.6
	rm.radial_segments = 16
	roof.mesh = rm
	roof.position.y = 4.45
	roof.material_override = tent_mat
	root.add_child(roof)

	var pennant := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.4, 0.32, 0.04)
	pennant.mesh = pm
	pennant.position = Vector3(0.0, 5.9, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = col_a
	pennant.material_override = pmat
	root.add_child(pennant)
	_flags.append(pennant)

func _build_castle(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	_env_root.add_child(root)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_texture = ProcTex.get_stone_texture()
	stone_mat.uv1_scale = Vector3(6.0, 3.0, 1.0)
	stone_mat.roughness = 0.92

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.66, 0.22, 0.18)
	roof_mat.roughness = 0.78

	# Main curtain wall
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(32.0, 10.5, 4.0)
	wall.mesh = wm
	wall.position = Vector3(0.0, 5.25, 0.0)
	wall.material_override = stone_mat
	root.add_child(wall)

	# Arched dark gate
	var gate := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(4.6, 6.2, 4.3)
	gate.mesh = gm
	gate.position = Vector3(0.0, 3.1, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.24, 0.16, 0.10)
	gate.material_override = gmat
	root.add_child(gate)

	# 4 medieval stone towers with conical roofs
	for tx in [-15.0, -5.5, 5.5, 15.0]:
		var h := 16.5 if absf(tx) < 10.0 else 14.0
		var tower := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 2.6
		tm.bottom_radius = 2.8
		tm.height = h
		tm.radial_segments = 14
		tower.mesh = tm
		tower.position = Vector3(tx, h * 0.5, 0.8)
		tower.material_override = stone_mat
		root.add_child(tower)

		var spire := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.05
		sm.bottom_radius = 3.0
		sm.height = 4.6
		sm.radial_segments = 14
		spire.mesh = sm
		spire.position = Vector3(tx, h + 2.3, 0.8)
		spire.material_override = roof_mat
		root.add_child(spire)

func _build_windmill(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	_env_root.add_child(root)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_texture = ProcTex.get_stone_texture()
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.0
	bm.bottom_radius = 3.0
	bm.height = 10.0
	body.mesh = bm
	body.position.y = 5.0
	body.material_override = stone_mat
	root.add_child(body)

	_windmill_blades = Node3D.new()
	_windmill_blades.position = Vector3(0.0, 8.2, 2.3)
	root.add_child(_windmill_blades)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = ProcTex.get_wood_texture()
	for ang in [0.0, 90.0]:
		var blade := MeshInstance3D.new()
		var blm := BoxMesh.new()
		blm.size = Vector3(0.65, 9.2, 0.14)
		blade.mesh = blm
		blade.rotation_degrees.z = ang
		blade.material_override = wood_mat
		_windmill_blades.add_child(blade)

func _build_trees(count: int, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_texture = ProcTex.get_wood_texture()
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.14, 0.34, 0.14) * tint
	for i in range(count):
		var side := -1.0 if (i % 2 == 0) else 1.0
		var tx := side * rng.randf_range(11.0, 26.0)
		var tz := -rng.randf_range(14.0, 72.0)
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.22
		tm.bottom_radius = 0.32
		tm.height = 3.2
		trunk.mesh = tm
		trunk.position = Vector3(tx, 1.6, tz)
		trunk.material_override = trunk_mat
		_env_root.add_child(trunk)

		var crown := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 2.1
		cm.height = 5.4
		crown.mesh = cm
		crown.position = Vector3(tx, 5.2, tz)
		crown.material_override = leaf_mat
		_env_root.add_child(crown)

func _build_torch(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.10
	pm.height = 2.6
	pole.mesh = pm
	pole.position = pos + Vector3(0.0, 1.3, 0.0)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = ProcTex.get_wood_texture()
	pole.material_override = wood_mat
	_env_root.add_child(pole)

	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.22
	fm.height = 0.44
	flame.mesh = fm
	flame.position = pos + Vector3(0.0, 2.75, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.62, 0.12)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.55, 0.10)
	fmat.emission_energy_multiplier = 3.0
	flame.material_override = fmat
	_env_root.add_child(flame)

	var omni := OmniLight3D.new()
	omni.position = pos + Vector3(0.0, 2.9, 0.0)
	omni.light_color = Color(1.0, 0.64, 0.24)
	omni.light_energy = 2.5
	omni.omni_range = 16.0
	_env_root.add_child(omni)

func _on_shot_fired(origin: Vector3, velocity: Vector3) -> void:
	if not level_active or arrows_left <= 0:
		return
	arrows_left -= 1
	active_arrows += 1
	var arrow := ArrowScript.new()
	_arrows_root.add_child(arrow)
	arrow.arrow_resolved.connect(_on_arrow_resolved)
	arrow.launch(origin, velocity, wind_speed)
	_emit_hud()

func _on_arrow_resolved(hit_info: Dictionary) -> void:
	active_arrows = maxi(0, active_arrows - 1)
	var pts := int(hit_info.get("points", 0))
	var kind := str(hit_info.get("kind", "miss"))

	if bool(hit_info.get("hit", false)) and pts > 0:
		combo_streak += 1
		var mult := 1.0
		if combo_streak >= 4:
			mult = 3.0
		elif combo_streak >= 2:
			mult = 1.5
		var final_pts := int(round(pts * mult))
		score += final_pts
		if bool(hit_info.get("bullseye", false)):
			bullseye_streak += 1
			max_bullseye_streak = maxi(max_bullseye_streak, bullseye_streak)
			AudioManager.play_sfx("hit_bullseye")
			AudioManager.vibrate(45)
		else:
			bullseye_streak = 0
			AudioManager.play_sfx("hit_target")
			AudioManager.vibrate(25)
		emit_signal("hit_feedback", kind, final_pts)
	else:
		combo_streak = 0
		bullseye_streak = 0
		if pts < 0:
			score = maxi(0, score + pts)
			AudioManager.play_sfx("hit_penalty")
			emit_signal("hit_feedback", kind, pts)

	_emit_hud()
	_check_end_condition()

func _process(delta: float) -> void:
	# Animate wind flags & windmill even on menu backdrop
	var w_abs: float = absf(wind_speed)
	for f in _flags:
		f.rotation.y = sin(Time.get_ticks_msec() * 0.006 * maxf(w_abs, 1.0)) * 0.18 + (0.0 if wind_speed >= 0.0 else PI)
	if _windmill_blades != null:
		_windmill_blades.rotation.z -= delta * 0.8

	if not level_active:
		return

	if bool(level_cfg.get("wind_gusty", false)):
		_wind_timer += delta
		if _wind_timer >= 4.5:
			_wind_timer = 0.0
			wind_speed = randf_range(float(level_cfg.get("wind_min", 0.0)), float(level_cfg.get("wind_max", 0.0))) * wind_dir
			_emit_hud()

	if float(level_cfg.get("time_limit_sec", 0)) > 0.0:
		time_left = maxf(0.0, time_left - delta)
		_emit_hud()
		if time_left <= 0.0:
			_finish_level()

func _check_end_condition() -> void:
	if not level_active:
		return
	var target_score := int(level_cfg.get("target_score", 150))
	if arrows_left <= 0 and active_arrows <= 0:
		_finish_level()
	elif score >= int(level_cfg.get("star3_score", target_score * 2)) and active_arrows <= 0:
		_finish_level()

func _finish_level() -> void:
	level_active = false
	camera.input_enabled = false
	camera.cancel_draw()

	var target_score := int(level_cfg.get("target_score", 150))
	var won := score >= target_score
	if won and arrows_left > 0:
		score += arrows_left * 25

	var stars := 0
	if won:
		stars = 1
		if score >= int(level_cfg.get("star2_score", target_score + 100)):
			stars = 2
		if score >= int(level_cfg.get("star3_score", target_score + 200)):
			stars = 3

	var level_id := int(level_cfg.get("id", 1))
	var bonuses: Array[String] = []
	if won:
		SaveManager.record_level_win(level_id, score, stars)
		bonuses = AttemptsManager.evaluate_win_bonuses(
			level_id, stars, max_bullseye_streak, arrows_left, bool(level_cfg.get("is_biome_boss", false))
		)
		AudioManager.play_sfx("win")
	else:
		AttemptsManager.consume_on_fail()
		AudioManager.play_sfx("fail")

	emit_signal("level_finished", {
		"level_id": level_id,
		"won": won,
		"score": score,
		"target_score": target_score,
		"stars": stars,
		"bonuses": bonuses
	})

func _emit_hud() -> void:
	emit_signal("hud_updated", {
		"level_id": int(level_cfg.get("id", 1)),
		"score": score,
		"target_score": int(level_cfg.get("target_score", 150)),
		"arrows_left": arrows_left,
		"arrows_total": arrows_total,
		"wind_speed": wind_speed,
		"time_left": int(ceil(time_left)),
		"has_timer": float(level_cfg.get("time_limit_sec", 0)) > 0.0,
		"combo": combo_streak
	})
