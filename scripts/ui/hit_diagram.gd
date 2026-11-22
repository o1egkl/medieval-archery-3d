extends Control

var hits: Array[Vector2] = []
var last_points: int = 0
var last_kind: String = ""
var _visible_timer: float = 0.0

func reset_hits() -> void:
	hits.clear()
	last_points = 0
	last_kind = ""
	visible = false
	queue_redraw()

func add_hit(norm_pos: Vector2, kind: String, points: int) -> void:
	last_kind = kind
	last_points = points
	if kind == "bullseye" or kind == "ring":
		hits.append(norm_pos)
		if hits.size() > 6:
			hits.pop_front()
	visible = true
	_visible_timer = 4.5
	queue_redraw()

func _process(delta: float) -> void:
	if visible and _visible_timer > 0.0:
		_visible_timer -= delta
		if _visible_timer <= 0.0:
			visible = false

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44

	# Dark medieval backing circle + bronze rim
	draw_circle(c, r + 8.0, Color(0.14, 0.10, 0.07, 0.88))
	draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(0.78, 0.60, 0.30, 0.95), 2.5, true)

	# Concentric target rings matching 3D target proportions
	draw_circle(c, r * 1.00, Color(0.80, 0.66, 0.36))
	draw_circle(c, r * 0.86, Color(0.95, 0.94, 0.90))
	draw_circle(c, r * 0.68, Color(0.16, 0.50, 0.84))
	draw_circle(c, r * 0.48, Color(0.86, 0.20, 0.16))
	draw_circle(c, r * 0.28, Color(0.98, 0.80, 0.10))

	# Subtle crosshair guides
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(0.0, 0.0, 0.0, 0.18), 1.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0.0, 0.0, 0.0, 0.18), 1.0)

	# Draw previous hits as dim dots, latest hit as bright glowing crosshair pin
	for i in range(hits.size()):
		var p := hits[i]
		var clamped := p if p.length() <= 1.02 else p.normalized() * 1.02
		var pos := c + clamped * r
		var is_last := (i == hits.size() - 1)
		if is_last:
			draw_circle(pos, 7.5, Color(0.0, 0.0, 0.0, 0.85))
			draw_circle(pos, 5.0, Color(0.18, 1.0, 0.35, 1.0))
			draw_arc(pos, 10.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.95), 2.0, true)
		else:
			draw_circle(pos, 4.0, Color(0.1, 0.1, 0.1, 0.65))
			draw_circle(pos, 2.5, Color(1.0, 1.0, 1.0, 0.75))
