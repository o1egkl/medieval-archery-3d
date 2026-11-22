extends Control

var draw_ratio: float = 0.0
var is_drawing: bool = false

func set_draw_state(ratio: float, drawing: bool) -> void:
	draw_ratio = clampf(ratio, 0.0, 1.0)
	is_drawing = drawing
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var ring_r := lerpf(56.0, 34.0, draw_ratio)
	# Crisp white aiming circle + center dot (like concept art)
	draw_arc(c, ring_r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.78), 3.0, true)
	draw_circle(c, 3.5, Color(1.0, 0.92, 0.35, 0.95))

	# Curved golden draw-tension arc on the right side
	if is_drawing or draw_ratio > 0.01:
		var arc_r := ring_r + 16.0
		var start_a := -0.68
		var end_a := 0.68
		draw_arc(c, arc_r, start_a, end_a, 24, Color(0.15, 0.12, 0.10, 0.65), 8.0, true)
		var fill_end := lerpf(end_a, start_a, draw_ratio)
		var col := Color(0.96, 0.78, 0.18, 0.95) if draw_ratio < 0.95 else Color(1.0, 0.88, 0.32, 1.0)
		draw_arc(c, arc_r, fill_end, end_a, 24, col, 6.0, true)
