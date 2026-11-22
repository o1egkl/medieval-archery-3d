extends Camera3D

signal draw_changed(draw_ratio: float, is_drawing: bool)
signal shot_fired(origin: Vector3, velocity: Vector3)

const MAX_DRAW_TIME := 0.85
const FATIGUE_START_SEC := 3.5
const MIN_LAUNCH_SPEED := 18.0
const MAX_LAUNCH_SPEED := 46.0

var input_enabled: bool = false
var is_drawing: bool = false
var draw_ratio: float = 0.0
var _hold_time: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.04
var _bow_node: Node3D
var _nocked_arrow: Node3D
var _active_touch_idx: int = -1

func _ready() -> void:
	fov = 62.0
	position = Vector3(0.0, 1.65, 0.0)
	_build_first_person_bow()

func _build_first_person_bow() -> void:
	_bow_node = Node3D.new()
	_bow_node.position = Vector3(0.32, -0.22, -0.62)
	add_child(_bow_node)

	var limb := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.022
	cm.height = 0.92
	limb.mesh = cm
	limb.rotation_degrees.z = 12.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.25, 0.12)
	limb.material_override = mat
	_bow_node.add_child(limb)

	_nocked_arrow = Node3D.new()
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.009
	sm.bottom_radius = 0.009
	sm.height = 0.65
	shaft.mesh = sm
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = mat
	_nocked_arrow.add_child(shaft)
	_nocked_arrow.position = Vector3(-0.08, 0.02, -0.08)
	_bow_node.add_child(_nocked_arrow)

func reset_aim() -> void:
	_yaw = 0.0
	_pitch = 0.05
	is_drawing = false
	draw_ratio = 0.0
	_hold_time = 0.0
	rotation = Vector3(_pitch, _yaw, 0.0)
	emit_signal("draw_changed", 0.0, false)

func cancel_draw() -> void:
	if is_drawing:
		is_drawing = false
		draw_ratio = 0.0
		_hold_time = 0.0
		_active_touch_idx = -1
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
		emit_signal("draw_changed", 0.0, false)
		return
	var speed := lerpf(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED, draw_ratio)
	var dir := -global_transform.basis.z.normalized()
	var spawn_pos := global_position + dir * 0.8 + Vector3(0.0, -0.08, 0.0)
	draw_ratio = 0.0
	_hold_time = 0.0
	AudioManager.play_sfx("arrow_release")
	AudioManager.vibrate(20)
	emit_signal("draw_changed", 0.0, false)
	emit_signal("shot_fired", spawn_pos, dir * speed)

func _process(delta: float) -> void:
	var sway_x := 0.0
	var sway_y := 0.0

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

	rotation = Vector3(_pitch + sway_y, _yaw + sway_x, 0.0)
	fov = lerpf(fov, 54.0 if is_drawing else 62.0, delta * 8.0)
	if _nocked_arrow != null:
		_nocked_arrow.position.z = lerpf(-0.08, 0.14, draw_ratio)
