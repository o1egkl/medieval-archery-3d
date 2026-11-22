extends Node3D

var target_type: String = "static"
var radius: float = 0.75
var move_speed: float = 0.0
var amplitude: float = 0.0
var base_pos: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _pivot: Node3D

func setup(cfg: Dictionary) -> void:
	target_type = str(cfg.get("type", "static"))
	radius = float(cfg.get("radius", 0.75))
	move_speed = float(cfg.get("speed", 0.0))
	amplitude = float(cfg.get("amplitude", 0.0))
	base_pos = Vector3(float(cfg.get("x", 0.0)), float(cfg.get("y", 1.7)), float(cfg.get("z", -25.0)))
	position = base_pos
	_build_mesh()

func _build_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	var body := StaticBody3D.new()
	_pivot.add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.24
	col.shape = shape
	col.rotation_degrees.x = 90.0
	body.add_child(col)

	if target_type == "barrel_bonus":
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius * 0.85
		mesh.bottom_radius = radius * 0.9
		mesh.height = radius * 1.8
		barrel.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.34, 0.14)
		barrel.material_override = mat
		_pivot.add_child(barrel)
		return

	if target_type == "shield_penalty":
		var shield := MeshInstance3D.new()
		var smesh := CylinderMesh.new()
		smesh.top_radius = radius
		smesh.bottom_radius = radius
		smesh.height = 0.14
		shield.mesh = smesh
		shield.rotation_degrees.x = 90.0
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.68, 0.12, 0.12)
		smat.metallic = 0.45
		shield.material_override = smat
		_pivot.add_child(shield)
		return

	# Concentric medieval straw archery target
	var rings := [
		{"scale": 1.00, "z": 0.00, "color": Color(0.82, 0.70, 0.44)},
		{"scale": 0.86, "z": 0.03, "color": Color(0.95, 0.95, 0.95)},
		{"scale": 0.66, "z": 0.05, "color": Color(0.18, 0.48, 0.85)},
		{"scale": 0.44, "z": 0.07, "color": Color(0.86, 0.20, 0.18)},
		{"scale": 0.22, "z": 0.09, "color": Color(0.96, 0.78, 0.10)}
	]
	for r in rings:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius * r["scale"]
		cm.bottom_radius = radius * r["scale"]
		cm.height = 0.14
		mi.mesh = cm
		mi.rotation_degrees.x = 90.0
		mi.position.z = r["z"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = r["color"]
		mi.material_override = mat
		_pivot.add_child(mi)

	# Wooden stand legs (for non-pendulum targets)
	if target_type != "pendulum":
		var leg := MeshInstance3D.new()
		var lbox := BoxMesh.new()
		lbox.size = Vector3(0.14, max(base_pos.y, 1.2), 0.14)
		leg.mesh = lbox
		leg.position = Vector3(0.0, -base_pos.y * 0.5, -0.14)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.38, 0.24, 0.12)
		leg.material_override = lmat
		_pivot.add_child(leg)

func _process(delta: float) -> void:
	_time += delta
	match target_type:
		"rail":
			position.x = base_pos.x + sin(_time * move_speed) * amplitude
		"pendulum":
			var angle := sin(_time * move_speed) * 0.65
			position.x = base_pos.x + sin(angle) * amplitude
			position.y = base_pos.y - (1.0 - cos(angle)) * amplitude * 0.6
		"popup":
			var wave := sin(_time * move_speed * TAU)
			var lift := clampf((wave + 0.25) * 1.4, 0.0, 1.0)
			position.y = base_pos.y - (1.0 - lift) * amplitude
		"shield_penalty":
			position.x = base_pos.x + sin(_time * move_speed) * amplitude

func evaluate_hit(world_hit_pos: Vector3) -> Dictionary:
	if target_type == "barrel_bonus":
		return {"hit": true, "points": 75, "kind": "barrel", "bullseye": false}
	if target_type == "shield_penalty":
		return {"hit": true, "points": -50, "kind": "penalty", "bullseye": false}

	var local_pos := _pivot.to_local(world_hit_pos)
	var dist := Vector2(local_pos.x, local_pos.y).length()
	var norm: float = dist / maxf(radius, 0.01)

	if norm <= 0.24:
		return {"hit": true, "points": 100, "kind": "bullseye", "bullseye": true}
	elif norm <= 0.48:
		return {"hit": true, "points": 60, "kind": "ring", "bullseye": false}
	elif norm <= 0.72:
		return {"hit": true, "points": 30, "kind": "ring", "bullseye": false}
	else:
		return {"hit": true, "points": 10, "kind": "ring", "bullseye": false}
