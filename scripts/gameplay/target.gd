extends Node3D

const PbrAssets := preload("res://scripts/gameplay/pbr_assets.gd")
const ModelLoader := preload("res://scripts/gameplay/model_loader.gd")

signal target_knocked_down(target_node: Node3D)

var target_type: String = "static"
var radius: float = 0.75
var move_speed: float = 0.0
var amplitude: float = 0.0
var base_pos: Vector3 = Vector3.ZERO
var _time: float = 0.0
var max_hits: int = 0
var current_hits: int = 0
var is_knocked_down: bool = false
var _pivot: Node3D
var _col_shape: CollisionShape3D
var _rail_beam: Node3D

func setup(cfg: Dictionary) -> void:
	target_type = str(cfg.get("type", "static"))
	radius = float(cfg.get("radius", 0.75))
	move_speed = float(cfg.get("speed", 0.0))
	amplitude = float(cfg.get("amplitude", 0.0))
	max_hits = int(cfg.get("max_hits", 0))
	current_hits = 0
	is_knocked_down = false
	base_pos = Vector3(float(cfg.get("x", 0.0)), float(cfg.get("y", 1.7)), float(cfg.get("z", -25.0)))
	position = base_pos
	_build_mesh()

func _make_wood_mat() -> StandardMaterial3D:
	return PbrAssets.get_pbr_material("wood", Vector3(1.0, 2.0, 1.0), Color(0.86, 0.76, 0.66))

func _build_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	var body := StaticBody3D.new()
	_pivot.add_child(body)
	_col_shape = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.28
	_col_shape.shape = shape
	_col_shape.rotation_degrees.x = 90.0
	body.add_child(_col_shape)

	var wood_mat := _make_wood_mat()

	if target_type == "barrel_bonus":
		var glb_barrel := ModelLoader.instantiate_glb("res://assets/models/barrel.glb")
		# Bright golden-red band so players instantly recognize the optional bonus barrel
		var halo := MeshInstance3D.new()
		var hm := TorusMesh.new()
		hm.inner_radius = radius * 0.72
		hm.outer_radius = radius * 0.94
		halo.mesh = hm
		halo.position.y = 0.05
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(1.0, 0.78, 0.12)
		hmat.emission_enabled = true
		hmat.emission = Color(1.0, 0.65, 0.10)
		hmat.emission_energy_multiplier = 1.4
		halo.material_override = hmat
		_pivot.add_child(halo)
		if glb_barrel != null:
			glb_barrel.scale = Vector3.ONE * (radius * 5.8)
			glb_barrel.position.y = -radius * 0.87
			_pivot.add_child(glb_barrel)
			return
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius * 0.82
		mesh.bottom_radius = radius * 0.88
		mesh.height = radius * 1.9
		barrel.mesh = mesh
		barrel.material_override = wood_mat
		_pivot.add_child(barrel)
		for band_y: float in [-radius * 0.55, radius * 0.55]:
			var band := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = radius * 0.88
			bm.bottom_radius = radius * 0.88
			bm.height = 0.08
			band.mesh = bm
			band.position.y = band_y
			var imat := StandardMaterial3D.new()
			imat.albedo_color = Color(0.28, 0.28, 0.32)
			imat.metallic = 0.75
			band.material_override = imat
			_pivot.add_child(band)
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
		smat.albedo_color = Color(0.66, 0.11, 0.11)
		smat.metallic = 0.55
		smat.roughness = 0.35
		shield.material_override = smat
		_pivot.add_child(shield)
		var boss := MeshInstance3D.new()
		var bsm := SphereMesh.new()
		bsm.radius = radius * 0.25
		bsm.height = radius * 0.5
		boss.mesh = bsm
		boss.position.z = 0.08
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.82, 0.72, 0.32)
		bmat.metallic = 0.8
		boss.material_override = bmat
		_pivot.add_child(boss)
		return

	# Braided straw drum body
	var drum := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.26
	cm.radial_segments = 32
	drum.mesh = cm
	drum.rotation_degrees.x = 90.0
	var straw_mat := PbrAssets.get_pbr_material("straw", Vector3(2.5, 2.5, 1.0), Color(1.08, 0.96, 0.72))
	drum.material_override = straw_mat
	_pivot.add_child(drum)

	# Mathematically centered concentric rings with dark separators for sharp distance readability
	var ring_specs := [
		{"scale": 0.875, "z": 0.131, "col": Color(0.18, 0.14, 0.10)},
		{"scale": 0.855, "z": 0.135, "col": Color(0.96, 0.95, 0.92)},
		{"scale": 0.695, "z": 0.139, "col": Color(0.16, 0.16, 0.18)},
		{"scale": 0.675, "z": 0.143, "col": Color(0.16, 0.52, 0.88)},
		{"scale": 0.495, "z": 0.147, "col": Color(0.16, 0.16, 0.18)},
		{"scale": 0.475, "z": 0.151, "col": Color(0.88, 0.20, 0.16)},
		{"scale": 0.275, "z": 0.155, "col": Color(0.18, 0.12, 0.06)},
		{"scale": 0.258, "z": 0.159, "col": Color(0.99, 0.82, 0.12)},
		{"scale": 0.065, "z": 0.163, "col": Color(0.84, 0.58, 0.04)}
	]
	for rs in ring_specs:
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = radius * float(rs["scale"])
		rm.bottom_radius = radius * float(rs["scale"])
		rm.height = 0.012
		rm.radial_segments = 32
		ring.mesh = rm
		ring.rotation_degrees.x = 90.0
		ring.position.z = float(rs["z"])
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = rs["col"]
		rmat.roughness = 0.78
		ring.material_override = rmat
		_pivot.add_child(ring)

	# Wooden A-frame tripod stand (like the concept art)
	if target_type != "pendulum":
		var leg_h: float = maxf(base_pos.y + 0.35, 1.5)
		var leg_specs := [
			{"pos": Vector3(-radius * 0.55, -base_pos.y * 0.45, -0.14), "rot": Vector3(6.0, 0.0, -14.0)},
			{"pos": Vector3(radius * 0.55, -base_pos.y * 0.45, -0.14), "rot": Vector3(6.0, 0.0, 14.0)},
			{"pos": Vector3(0.0, -base_pos.y * 0.45, -0.45), "rot": Vector3(-22.0, 0.0, 0.0)}
		]
		for ls in leg_specs:
			var leg := MeshInstance3D.new()
			var lbox := BoxMesh.new()
			lbox.size = Vector3(0.11, leg_h, 0.11)
			leg.mesh = lbox
			leg.position = ls["pos"]
			leg.rotation_degrees = ls["rot"]
			leg.material_override = wood_mat
			_pivot.add_child(leg)
	else:
		# Hanging rope for pendulum targets
		var rope := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.025
		rm.bottom_radius = 0.025
		rm.height = 2.4
		rope.mesh = rm
		rope.position = Vector3(0.0, radius + 1.15, 0.0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.68, 0.56, 0.36)
		rope.material_override = rmat
		_pivot.add_child(rope)

	# Wooden horizontal rail beam placed in world space for rail targets
	if target_type == "rail" and get_parent() != null:
		_rail_beam = Node3D.new()
		_rail_beam.position = Vector3(base_pos.x, 0.42, base_pos.z + 0.45)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(amplitude * 2.0 + 1.8, 0.18, 0.18)
		beam.mesh = bm
		beam.material_override = wood_mat
		_rail_beam.add_child(beam)
		for side: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.24, 0.84, 0.24)
			post.mesh = pm
			post.position = Vector3(side * (amplitude + 0.85), -0.05, 0.0)
			post.material_override = wood_mat
			_rail_beam.add_child(post)
		get_parent().add_child(_rail_beam)

func get_stick_parent() -> Node:
	return _pivot if _pivot != null else self

func _process(delta: float) -> void:
	if is_knocked_down:
		return
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

func _spawn_hit_burst(local_hit: Vector3, is_bullseye: bool) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 18 if is_bullseye else 10
	burst.lifetime = 0.45
	burst.direction = Vector3(0.0, 0.3, 1.0)
	burst.spread = 55.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.position = local_hit + Vector3(0.0, 0.0, 0.08)
	var pm := SphereMesh.new()
	pm.radius = 0.035 if is_bullseye else 0.025
	pm.height = 0.07 if is_bullseye else 0.05
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(1.0, 0.88, 0.20) if is_bullseye else Color(1.0, 0.96, 0.86)
	pmat.emission_enabled = true
	pmat.emission = pmat.albedo_color
	pmat.emission_energy_multiplier = 2.5
	pm.material = pmat
	burst.mesh = pm
	_pivot.add_child(burst)
	burst.emitting = true
	var cleanup_tw := burst.create_tween()
	cleanup_tw.tween_interval(0.6)
	cleanup_tw.tween_callback(burst.queue_free)

func evaluate_hit(world_hit_pos: Vector3) -> Dictionary:
	if is_knocked_down:
		return {"hit": false, "points": 0, "kind": "miss", "bullseye": false, "norm_pos": Vector2.ZERO}
	var local_pos := _pivot.to_local(world_hit_pos)
	if target_type == "barrel_bonus":
		_spawn_hit_burst(local_pos, true)
		_apply_damage(1)
		return {"hit": true, "points": 75, "kind": "barrel", "bullseye": false, "norm_pos": Vector2.ZERO, "knocked_down": is_knocked_down}
	if target_type == "shield_penalty":
		_spawn_hit_burst(local_pos, false)
		return {"hit": true, "points": -50, "kind": "penalty", "bullseye": false, "norm_pos": Vector2.ZERO}

	var safe_r: float = maxf(radius, 0.01)
	var norm_vec := Vector2(local_pos.x / safe_r, -local_pos.y / safe_r)
	var norm: float = norm_vec.length()

	var res: Dictionary
	if norm <= 0.28:
		_spawn_hit_burst(local_pos, true)
		res = {"hit": true, "points": 100, "kind": "bullseye", "bullseye": true, "norm_pos": norm_vec}
	elif norm <= 0.50:
		_spawn_hit_burst(local_pos, false)
		res = {"hit": true, "points": 60, "kind": "ring", "bullseye": false, "norm_pos": norm_vec}
	elif norm <= 0.74:
		_spawn_hit_burst(local_pos, false)
		res = {"hit": true, "points": 30, "kind": "ring", "bullseye": false, "norm_pos": norm_vec}
	else:
		_spawn_hit_burst(local_pos, false)
		res = {"hit": true, "points": 10, "kind": "ring", "bullseye": false, "norm_pos": norm_vec}
	_apply_damage(2 if bool(res["bullseye"]) else 1)
	res["knocked_down"] = is_knocked_down
	return res

func _apply_damage(dmg: int) -> void:
	if max_hits <= 0 or is_knocked_down:
		return
	current_hits += dmg
	if current_hits >= max_hits:
		_knock_down()
	else:
		_tilt_damaged()

func _tilt_damaged() -> void:
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation_degrees:x", -20.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivot, "rotation_degrees:x", -12.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _knock_down() -> void:
	is_knocked_down = true
	if _col_shape != null:
		_col_shape.set_deferred("disabled", true)
	AudioManager.play_sfx("target_fall")
	var tw := create_tween().set_parallel(true)
	if target_type == "pendulum":
		tw.tween_property(_pivot, "rotation_degrees:x", -78.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_pivot, "position:y", -1.4, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif target_type == "popup":
		tw.tween_property(_pivot, "rotation_degrees:x", -84.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:y", base_pos.y - maxf(amplitude, 1.4), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(_pivot, "rotation_degrees:x", -84.0, 0.48).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_pivot, "position:y", -base_pos.y * 0.42, 0.48).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	emit_signal("target_knocked_down", self)
