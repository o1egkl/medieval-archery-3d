extends Camera3D

const PbrAssets := preload("res://scripts/gameplay/pbr_assets.gd")

signal draw_changed(draw_ratio: float, is_drawing: bool)
signal shot_fired(origin: Vector3, velocity: Vector3)
signal input_mode_changed(is_touch: bool)

const MAX_DRAW_TIME := 0.85
const FATIGUE_START_SEC := 3.5
const MIN_LAUNCH_SPEED := 32.0
const MAX_LAUNCH_SPEED := 68.0

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
var _top_tip := Vector3(0.0, 0.58, 0.12)
var _bot_tip := Vector3(0.0, -0.58, 0.12)
var _active_touch_idx: int = -1
var _draw_source: String = "" # "" | "mouse" | "touch"
var _recoil: float = 0.0
var is_touch_mode: bool = false
var cancel_zone_rect: Rect2 = Rect2()

func _ready() -> void:
	fov = 60.0
	position = Vector3(0.0, 1.68, 0.0)
	is_touch_mode = DisplayServer.is_touchscreen_available()
	_build_first_person_bow()

func _build_first_person_bow() -> void:
	_bow_node = Node3D.new()
	_bow_node.position = Vector3(0.24, -0.14, -0.56)
	_bow_node.rotation_degrees = Vector3(2.0, 9.0, -13.0)
	add_child(_bow_node)

	var wood_mat := PbrAssets.get_pbr_material("wood", Vector3(1.0, 2.0, 1.0), Color(0.76, 0.58, 0.40))

	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.24, 0.15, 0.09)
	leather_mat.roughness = 0.78

	var bronze_mat := StandardMaterial3D.new()
	bronze_mat.albedo_color = Color(0.76, 0.58, 0.24)
	bronze_mat.metallic = 0.78
	bronze_mat.roughness = 0.32

	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.18, 0.15, 0.12)
	horn_mat.roughness = 0.42

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.76, 0.80, 0.85)
	iron_mat.metallic = 0.85
	iron_mat.roughness = 0.24

	# Smooth 18-segment S-curved medieval recurve bow
	var seg_count := 18
	var pts: Array[Vector3] = []
	for i in range(seg_count + 1):
		var t := float(i) / float(seg_count)
		var y := lerpf(-0.58, 0.58, t)
		var ny := absf(y) / 0.58
		# Graceful recurve S-profile: curves back through mid-limb, sweeps slightly forward at tips
		var z := pow(ny, 1.8) * 0.16 - pow(maxf(0.0, ny - 0.72) / 0.28, 2.0) * 0.045
		pts.append(Vector3(0.0, y, z))

	_bot_tip = pts[0]
	_top_tip = pts[pts.size() - 1]

	for i in range(seg_count):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var mid_ny := absf((p0.y + p1.y) * 0.5) / 0.58
		var thick := lerpf(0.020, 0.009, mid_ny)
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = thick
		cm.bottom_radius = thick
		cm.height = p0.distance_to(p1) + 0.008
		cm.radial_segments = 14
		seg.mesh = cm
		seg.position = (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		seg.basis = Basis(Vector3.RIGHT, dir, Vector3.RIGHT.cross(dir).normalized())
		if mid_ny < 0.14:
			seg.material_override = leather_mat
		elif mid_ny > 0.90:
			seg.material_override = horn_mat
		else:
			seg.material_override = wood_mat
		_bow_node.add_child(seg)

	# Bronze decorative collar rings framing the leather grip
	for ry: float in [-0.085, 0.085]:
		var ring := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.018
		rm.outer_radius = 0.025
		ring.mesh = rm
		ring.position = Vector3(0.0, ry, 0.004)
		ring.material_override = bronze_mat
		_bow_node.add_child(ring)

	# Sleek contoured leather archer's fingers wrapping the bow grip (compact, zero screen clutter)
	for fi in range(4):
		var finger := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.011
		fm.height = 0.068
		finger.mesh = fm
		finger.position = Vector3(-0.006, -0.045 + float(fi) * 0.024, 0.004)
		finger.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		finger.material_override = leather_mat
		_bow_node.add_child(finger)

	var thumb := MeshInstance3D.new()
	var thm := CapsuleMesh.new()
	thm.radius = 0.012
	thm.height = 0.062
	thumb.mesh = thm
	thumb.position = Vector3(-0.026, 0.036, 0.018)
	thumb.rotation_degrees = Vector3(32.0, 12.0, 18.0)
	thumb.material_override = leather_mat
	_bow_node.add_child(thumb)

	# Dynamic 2-segment taut bowstring
	var str_mat := StandardMaterial3D.new()
	str_mat.albedo_color = Color(0.86, 0.82, 0.72)
	_string_top = MeshInstance3D.new()
	_string_bot = MeshInstance3D.new()
	for s in [_string_top, _string_bot]:
		var sc := CylinderMesh.new()
		sc.top_radius = 0.0024
		sc.bottom_radius = 0.0024
		sc.height = 1.0
		s.mesh = sc
		s.material_override = str_mat
		_bow_node.add_child(s)

	# Sleek feathered wooden arrow with forged steel broadhead
	_nocked_arrow = Node3D.new()
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.006
	sm.bottom_radius = 0.006
	sm.height = 0.78
	shaft.mesh = sm
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = wood_mat
	_nocked_arrow.add_child(shaft)

	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.001
	hm.bottom_radius = 0.016
	hm.height = 0.085
	head.mesh = hm
	head.rotation_degrees.x = -90.0
	head.position = Vector3(0.0, 0.0, -0.43)
	head.material_override = iron_mat
	_nocked_arrow.add_child(head)

	var fletch_red := StandardMaterial3D.new()
	fletch_red.albedo_color = Color(0.82, 0.18, 0.14)
	fletch_red.roughness = 0.85
	var fletch_white := StandardMaterial3D.new()
	fletch_white.albedo_color = Color(0.92, 0.89, 0.82)
	fletch_white.roughness = 0.85
	for idx in range(3):
		var ang: float = float(idx) * 120.0
		var vane := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.036, 0.003, 0.11)
		vane.mesh = vm
		vane.position = Vector3(0.0, 0.0, 0.31)
		vane.rotation_degrees.z = ang
		vane.material_override = fletch_red if idx == 0 else fletch_white
		_nocked_arrow.add_child(vane)

	_nocked_arrow.position = Vector3(-0.032, 0.055, -0.18)
	_bow_node.add_child(_nocked_arrow)
	_update_bowstring(0.0)

func _update_bowstring(ratio: float) -> void:
	var flex := ratio * 0.03
	var top := _top_tip + Vector3(0.0, -flex * 0.4, flex)
	var bot := _bot_tip + Vector3(0.0, flex * 0.4, flex)
	var nock := Vector3(-0.032, 0.055, lerpf(0.12, 0.42, ratio))
	_place_segment(_string_top, top, nock)
	_place_segment(_string_bot, bot, nock)
	if _nocked_arrow != null:
		_nocked_arrow.position = Vector3(-0.032, 0.055, nock.z - 0.36)

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
	_draw_source = ""
	draw_ratio = 0.0
	_hold_time = 0.0
	_recoil = 0.0
	rotation = Vector3(_pitch, _yaw, 0.0)
	_update_bowstring(0.0)
	emit_signal("draw_changed", 0.0, false)

func set_aim_active(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif not is_touch_mode and not DisplayServer.is_touchscreen_available():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func cancel_draw() -> void:
	if is_drawing:
		is_drawing = false
		_draw_source = ""
		draw_ratio = 0.0
		_hold_time = 0.0
		_active_touch_idx = -1
		_update_bowstring(0.0)
		emit_signal("draw_changed", 0.0, false)

func _set_touch_mode(touch: bool) -> void:
	if is_touch_mode != touch:
		is_touch_mode = touch
		if is_touch_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		emit_signal("input_mode_changed", is_touch_mode)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var sens := float(SaveManager.get_setting("aim_sensitivity", 1.0)) * 0.0032

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_set_touch_mode(false)
		if is_drawing:
			cancel_draw()
			AudioManager.play_sfx("ui_click")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		_set_touch_mode(false)
		if event.pressed and not is_drawing:
			if not DisplayServer.is_touchscreen_available() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_draw_source = "mouse"
			is_drawing = true
			draw_ratio = 0.0
			_hold_time = 0.0
			AudioManager.play_sfx("bow_draw")
		elif not event.pressed and is_drawing and _draw_source == "mouse":
			_release_shot()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_R:
			_set_touch_mode(false)
			if is_drawing:
				cancel_draw()
				AudioManager.play_sfx("ui_click")
			return

	if event is InputEventScreenTouch:
		if event.pressed and not is_drawing and _draw_source == "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_set_touch_mode(true)
			_draw_source = "touch"
			_active_touch_idx = event.index
			is_drawing = true
			draw_ratio = 0.0
			_hold_time = 0.0
			AudioManager.play_sfx("bow_draw")
		elif not event.pressed and is_drawing and _draw_source == "touch" and event.index == _active_touch_idx:
			if cancel_zone_rect.size.x > 0.0 and cancel_zone_rect.has_point(event.position):
				cancel_draw()
				AudioManager.play_sfx("ui_click")
			else:
				_release_shot()
			_active_touch_idx = -1
	elif event is InputEventScreenDrag:
		if _draw_source == "touch" and event.index == _active_touch_idx:
			_yaw = clampf(_yaw - event.relative.x * sens, -0.65, 0.65)
			_pitch = clampf(_pitch - event.relative.y * sens, -0.25, 0.45)
	elif event is InputEventMouseMotion:
		if _draw_source != "touch":
			_set_touch_mode(false)
			_yaw = clampf(_yaw - event.relative.x * sens, -0.65, 0.65)
			_pitch = clampf(_pitch - event.relative.y * sens, -0.25, 0.45)

func _release_shot() -> void:
	is_drawing = false
	_draw_source = ""
	if draw_ratio < 0.18:
		draw_ratio = 0.0
		_update_bowstring(0.0)
		emit_signal("draw_changed", 0.0, false)
		return
	var speed := lerpf(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED, draw_ratio)
	var dir := -global_transform.basis.z.normalized()
	var up := global_transform.basis.y.normalized()
	var spawn_pos := global_position + dir * 0.85
	var launch_vel := dir * speed + up * (0.956 * draw_ratio)
	draw_ratio = 0.0
	_hold_time = 0.0
	_recoil = 1.0
	_update_bowstring(0.0)
	AudioManager.play_sfx("arrow_release")
	AudioManager.vibrate(20)
	emit_signal("draw_changed", 0.0, false)
	emit_signal("shot_fired", spawn_pos, launch_vel)

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

	if input_enabled and bool(SaveManager.get_setting("gyro_enabled", false)):
		var gyro := Input.get_gyroscope()
		_yaw = clampf(_yaw + gyro.y * delta * 0.45, -0.65, 0.65)
		_pitch = clampf(_pitch + gyro.x * delta * 0.45, -0.25, 0.45)

	rotation = Vector3(_pitch + sway_y + _recoil * 0.015, _yaw + sway_x, 0.0)
	var target_fov := lerpf(60.0, 39.0, draw_ratio) if is_drawing else 60.0
	fov = lerpf(fov, target_fov, delta * 8.0)
	_update_bowstring(draw_ratio)
	if _bow_node != null:
		var idle_bob := sin(Time.get_ticks_msec() * 0.002) * 0.006
		_bow_node.position = Vector3(0.24, -0.14 + idle_bob - _recoil * 0.025, -0.56 + _recoil * 0.035)
