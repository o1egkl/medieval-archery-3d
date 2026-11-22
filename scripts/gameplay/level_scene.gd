extends Node3D

signal hud_updated(state: Dictionary)
signal hit_feedback(kind: String, points: int)
signal level_finished(result: Dictionary)

const ArrowScript := preload("res://scripts/gameplay/arrow.gd")
const TargetScript := preload("res://scripts/gameplay/target.gd")
const BowControllerScript := preload("res://scripts/gameplay/bow_controller.gd")

var camera: Camera3D
var _env_root: Node3D
var _targets_root: Node3D
var _arrows_root: Node3D
var _flags: Array[MeshInstance3D] = []

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
	for n in _env_root.get_children():
		n.queue_free()
	for n in _targets_root.get_children():
		n.queue_free()
	for n in _arrows_root.get_children():
		n.queue_free()

func _build_biome(biome: String) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	var quality := str(SaveManager.get_setting("graphics_quality", "medium"))
	light.shadow_enabled = (quality != "low")

	var ground_color := Color(0.28, 0.50, 0.22)
	match biome:
		"village":
			env.background_color = Color(0.52, 0.76, 0.96)
			light.light_energy = 1.2
			ground_color = Color(0.30, 0.54, 0.22)
		"tournament":
			env.background_color = Color(0.44, 0.72, 0.98)
			light.light_energy = 1.3
			ground_color = Color(0.26, 0.52, 0.20)
		"forest":
			env.background_color = Color(0.58, 0.42, 0.34)
			env.fog_enabled = true
			env.fog_light_color = Color(0.62, 0.48, 0.40)
			env.fog_density = 0.012
			light.light_energy = 0.85
			ground_color = Color(0.18, 0.32, 0.16)
		"fortress":
			env.background_color = Color(0.08, 0.10, 0.18)
			env.fog_enabled = true
			env.fog_light_color = Color(0.10, 0.12, 0.22)
			env.fog_density = 0.01
			light.light_energy = 0.55
			ground_color = Color(0.20, 0.21, 0.24)

	world_env.environment = env
	_env_root.add_child(world_env)
	_env_root.add_child(light)

	# Ground plane with collision so missed arrows stick cleanly
	var ground := StaticBody3D.new()
	var gmesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90.0, 140.0)
	gmesh.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = ground_color
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(90.0, 0.5, 140.0)
	gcol.shape = gshape
	gcol.position.y = -0.25
	ground.add_child(gcol)
	ground.position = Vector3(0.0, 0.0, -45.0)
	_env_root.add_child(ground)

	# Wind flags flanking the range
	for side in [-1.0, 1.0]:
		for dist in [18.0, 36.0, 54.0]:
			var pole := MeshInstance3D.new()
			var pcyl := CylinderMesh.new()
			pcyl.top_radius = 0.06
			pcyl.bottom_radius = 0.08
			pcyl.height = 4.5
			pole.mesh = pcyl
			pole.position = Vector3(side * 8.5, 2.25, -dist)
			_env_root.add_child(pole)

			var flag := MeshInstance3D.new()
			var fbox := BoxMesh.new()
			fbox.size = Vector3(1.6, 0.65, 0.05)
			flag.mesh = fbox
			flag.position = Vector3(side * 8.5, 4.1, -dist)
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(0.78, 0.16, 0.14) if side < 0 else Color(0.16, 0.36, 0.78)
			flag.material_override = fmat
			_env_root.add_child(flag)
			_flags.append(flag)

	# Night Fortress rain using CPUParticles3D (100% OpenGL ES 3.0 / Compatibility safe)
	if biome == "fortress" and quality != "low":
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
	active_arrows = max(0, active_arrows - 1)
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
			max_bullseye_streak = max(max_bullseye_streak, bullseye_streak)
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
			score = max(0, score + pts)
			AudioManager.play_sfx("hit_penalty")
			emit_signal("hit_feedback", kind, pts)

	_emit_hud()
	_check_end_condition()

func _process(delta: float) -> void:
	if not level_active:
		return
	# Animate wind flags
	var w_abs := absf(wind_speed)
	for f in _flags:
		f.rotation.y = sin(Time.get_ticks_msec() * 0.006 * max(w_abs, 1.0)) * 0.18 + (0.0 if wind_speed >= 0.0 else PI)

	if bool(level_cfg.get("wind_gusty", false)):
		_wind_timer += delta
		if _wind_timer >= 4.5:
			_wind_timer = 0.0
			wind_speed = randf_range(float(level_cfg.get("wind_min", 0.0)), float(level_cfg.get("wind_max", 0.0))) * wind_dir
			_emit_hud()

	if float(level_cfg.get("time_limit_sec", 0)) > 0.0:
		time_left = max(0.0, time_left - delta)
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
	# Unused arrows bonus on win
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
