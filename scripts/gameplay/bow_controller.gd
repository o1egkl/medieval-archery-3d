extends Camera3D

const ProcTex := preload("res://scripts/gameplay/procedural_textures.gd")

signal draw_changed(draw_ratio: float, is_drawing: bool)
signal shot_fired(origin: Vector3, velocity: Vector3)

const MAX_DRAW_TIME := 0.85
const FATIGUE_START_SEC := 3.5
const MIN_LAUNCH_SPEED := 19.0
const MAX_LAUNCH_SPEED := 47.0

var input_enabled: bool = false
var is_drawing: bool = false
var draw_ratio: float = 0.0
var _hold_time: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.04
var _bow_node: Node3D
var _nocked_arrow: Node3D
var _string_top: MeshInstance3D
var _string_bot: MeshInstance3D
var _top_tip := Vector3(0.0, 0.56, 0.14)
var _bot_tip := Vector3(0.0, -0.56, 0.14)
var _active_touch_idx: int = -1
var _recoil: float = 0.0

func _ready() -> void:
	fov = 60.0
	position = Vector3(0.0, 1.68, 0.0)
	_build_first_person_bow()

func _build_first_person_bow() -> void:
	_bow_node = Node3D.new()
	_bow_node.position = Vector3(0.20, -0.12, -0.56)
	_bow_node.rotation_degrees = Vector3(2.0, 10.0, -14.0)
	add_child(_bow_node)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = ProcTex.get_wood_texture()
	wood_mat.roughness = 0.65

	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.26, 0.17, 0.11)
	leather_mat.roughness = 0.85

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.74, 0.77, 0.82)
	iron_mat.metallic = 0.8
	iron_mat.roughness = 0.25

	# Smooth 9-segment curved wooden recurve bow
	var pts: Array[Vector3] = []
	for i in range(10):
		var t := float(i) / 9.0
		var y := lerpf(-0.56, 0.56, t)
		var norm_y := y / 0.56
		var z := norm_y * norm_y * 0.14
		pts.append(Vector3(0.0, y, z))

	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var mid_t := absf(float(i) - 4.0) / 4.5
		var thick := lerpf(0.025, 0.013, mid_t)
		cm.top_radius = thick
		cm.bottom_radius = thick
		cm.height = p0.distance_to(p1) + 0.01
		seg.mesh = cm
		seg.position = (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		seg.basis = Basis(Vector3.RIGHT, dir, Vector3.RIGHT.cross(dir).normalized())
		seg.material_override = leather_mat if (i == 4) else wood_mat
		_bow_node.add_child(seg)

	# Stylized leather-gloved left hand gripping the bow handle
	var glove := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.055
	gm.height = 0.11
	glove.mesh = gm
	glove.scale = Vector3(1.1, 0.95, 1.25)
	glove.position = Vector3(-0.02, -0.02, 0.01)
	glove.material_override = leather_mat
	_bow_node.add_child(glove)

	var forearm := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.042
	fm.bottom_radius = 0.052
	fm.height = 0.36
	forearm.mesh = fm
	forearm.position = Vector3(-0.10, -0.14, 0.14)
	forearm.rotation_degrees = Vector3(58.0, 22.0, -24.0)
	forearm.material_override = leather_mat
	_bow_node.add_child(forearm)

	# Dynamic 2-segment taut bowstring
	var str_mat := StandardMaterial3D.new()
	str_mat.albedo_color = Color(0.88, 0.84, 0.74)
	_string_top = MeshInstance3D.new()
	_string_bot = MeshInstance3D.new()
	for s in [_string_top, _string_bot]:
		var sc := CylinderMesh.new()
		sc.top_radius = 0.003
		sc.bottom_radius = 0.003
		sc.height = 1.0
		s.mesh = sc
		s.material_override = str_mat
		_bow_node.add_child(s)

	# Nocked feathered wooden arrow
	_nocked_arrow = Node3D.new()
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.008
	sm.height = 0.78
	shaft.mesh = sm
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = wood_mat
	_nocked_arrow.add_child(shaft)

	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.001
	hm.bottom_radius = 0.020
	hm.height = 0.09
	head.mesh = hm
	head.rotation_degrees.x = -90.0
	head.position = Vector3(0.0, 0.0, -0.43)
	head.material_override = iron_mat
	_nocked_arrow.add_child(head)

	var fletch_mat := StandardMaterial3D.new()
	fletch_mat.albedo_color = Color(0.92, 0.86, 0.76)
	for ang: float in [0.0, 60.0, -60.0]:
		var vane := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.055, 0.004, 0.12)
		vane.mesh = vm
		vane.position = Vector3(0.0, 0.0, 0.31)
		vane.rotation_degrees.z = ang
		vane.material_override = fletch_mat
		_nocked_arrow.add_child(vane)

	_nocked_arrow.position = Vector3(-0.04, 0.04, -0.18)
	_bow_node.add_child(_nocked_arrow)
	_update_bowstring(0.0)

func _update_bowstring(ratio: float) -> void:
	var nock := Vector3(-0.04, 0.04, lerpf(0.14, 0.44, ratio))
	_place_segment(_string_top, _top_tip, nock)
	_place_segment(_string_bot, _bot_tip, nock)
	if _nocked_arrow != null:
		_nocked_arrow.position = Vector3(-0.04, 0.04, nock.z - 0.36)

func _place_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dist := a.distance_to(b)
	if dist < 0.001:
		return
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up_ref := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var side := up_ref.cross(dir).normalized()
	var fwd := dir.cross(side).normalized()
	mi.basis = Basis(side, dir, fwd)
	mi.scale = Vector3(1.0, dist, 1.0)

func reset_aim() -> void:
	_yaw = 0.0
	_pitch = 0.04
	is_drawing = false
	draw_ratio = 0.0
	_hold_time = 0.0
	_recoil = 0.0
	rotation = Vector3(_pitch, _yaw, 0.0)
	_update_bowstring(0.0)
	emit_signal("draw_changed", 0.0, false)

func cancel_draw() -> void:
	if is_drawing:
		is_drawing = false
		draw_ratio = 0.0
		_hold_time = 0.0
		_active_touch_idx = -1
		_update_bowstring(0.0)
		emit_signal("draw_changed", 0.0, false)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var sens := float(SaveManager.get_setting("aim_sensitivity", 1.0)) * 0.0032

	if event is InputEventScreenTouch:
		if event.pressed and not is_drawing:
			_active_touch_idx = event.index
			is_drawing = true
			draw_ratio = 0.0
			_hold_time = 0.0
			AudioManager.play_sfx("bow_draw")
		elif not event.pressed and is_drawing and event.index == _active_touch_idx:
			_release_shot()
			_active_touch_idx = -1
	elif event is InputEventScreenDrag and is_drawing and event.index == _active_touch_idx:
		_yaw = clampf(_yaw - event.relative.x * sens, -0.65, 0.65)
		_pitch = clampf(_pitch - event.relative.y * sens, -0.25, 0.45)

func _release_shot() -> void:
	is_drawing = false
	if draw_ratio < 0.18:
		draw_ratio = 0.0
		_update_bowstring(0.0)
		emit_signal("draw_changed", 0.0, false)
		return
	var speed := lerpf(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED, draw_ratio)
	var dir := -global_transform.basis.z.normalized()
	var spawn_pos := global_position + dir * 0.85 + Vector3(0.0, -0.06, 0.0)
	draw_ratio = 0.0
	_hold_time = 0.0
	_recoil = 1.0
	_update_bowstring(0.0)
	AudioManager.play_sfx("arrow_release")
	AudioManager.vibrate(20)
	emit_signal("draw_changed", 0.0, false)
	emit_signal("shot_fired", spawn_pos, dir * speed)

func _process(delta: float) -> void:
	var sway_x := 0.0
	var sway_y := 0.0
	_recoil = maxf(0.0, _recoil - delta * 5.0)

	if is_drawing:
		_hold_time += delta
		draw_ratio = minf(1.0, _hold_time / MAX_DRAW_TIME)
		emit_signal("draw_changed", draw_ratio, true)
		if _hold_time > FATIGUE_START_SEC:
			var fatigue := minf(1.0, (_hold_time - FATIGUE_START_SEC) * 0.55)
			sway_x = sin(_hold_time * 5.2) * 0.018 * fatigue
			sway_y = cos(_hold_time * 4.1) * 0.015 * fatigue
		if bool(SaveManager.get_setting("gyro_enabled", false)):
			var gyro := Input.get_gyroscope()
			_yaw = clampf(_yaw + gyro.y * delta * 0.45, -0.65, 0.65)
			_pitch = clampf(_pitch + gyro.x * delta * 0.45, -0.25, 0.45)

	rotation = Vector3(_pitch + sway_y + _recoil * 0.015, _yaw + sway_x, 0.0)
	fov = lerpf(fov, 50.0 if is_drawing else 60.0, delta * 8.0)
	_update_bowstring(draw_ratio)
	if _bow_node != null:
		var idle_bob := sin(Time.get_ticks_msec() * 0.002) * 0.008
		_bow_node.position = Vector3(0.20, -0.12 + idle_bob - _recoil * 0.03, -0.56 + _recoil * 0.04)
