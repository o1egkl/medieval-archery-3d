extends Node3D

signal arrow_resolved(hit_info: Dictionary)

const GRAVITY := 9.81
const WIND_FACTOR := 0.38
const MAX_FLIGHT_TIME := 5.5

var velocity: Vector3 = Vector3.ZERO
var wind_x: float = 0.0
var is_flying: bool = false
var _flight_time: float = 0.0

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.014
	cyl.height = 0.85
	shaft.mesh = cyl
	shaft.rotation_degrees.x = 90.0
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.48, 0.30, 0.16)
	shaft.material_override = mat_wood
	add_child(shaft)

	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.002
	cone.bottom_radius = 0.028
	cone.height = 0.12
	tip.mesh = cone
	tip.rotation_degrees.x = -90.0
	tip.position = Vector3(0.0, 0.0, -0.46)
	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.75, 0.78, 0.82)
	mat_iron.metallic = 0.7
	tip.material_override = mat_iron
	add_child(tip)

	var fletch := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(0.09, 0.01, 0.14)
	fletch.mesh = fbox
	fletch.position = Vector3(0.0, 0.0, 0.36)
	var mat_red := StandardMaterial3D.new()
	mat_red.albedo_color = Color(0.85, 0.18, 0.16)
	fletch.material_override = mat_red
	add_child(fletch)

func launch(start_pos: Vector3, initial_velocity: Vector3, wind_speed_x: float) -> void:
	global_position = start_pos
	velocity = initial_velocity
	wind_x = wind_speed_x
	is_flying = true
	_flight_time = 0.0
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not is_flying:
		return
	_flight_time += delta
	if _flight_time >= MAX_FLIGHT_TIME:
		is_flying = false
		emit_signal("arrow_resolved", {"hit": false, "points": 0, "kind": "miss"})
		queue_free()
		return

	var prev_pos := global_position
	velocity.y -= GRAVITY * delta
	velocity.x += wind_x * WIND_FACTOR * delta
	var next_pos := prev_pos + velocity * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(prev_pos, next_pos)
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		global_position = hit["position"]
		is_flying = false
		var collider: Node = hit["collider"]
		var target_node: Node = collider.get_parent()
		if target_node != null and target_node.has_method("evaluate_hit"):
			var res: Dictionary = target_node.evaluate_hit(hit["position"])
			# Stick arrow to moving or static target
			var saved_global := global_transform
			reparent(target_node)
			global_transform = saved_global
			emit_signal("arrow_resolved", res)
		else:
			emit_signal("arrow_resolved", {"hit": false, "points": 0, "kind": "miss"})
		return

	global_position = next_pos
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
