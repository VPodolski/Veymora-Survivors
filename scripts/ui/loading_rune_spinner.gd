class_name LoadingRuneSpinner
extends Node2D

func _draw() -> void:
	var r = 36.0
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.3, 0.75, 1.0, 0.4), 2.0)
	draw_arc(Vector2.ZERO, r * 0.65, 0, TAU, 24, Color(0.6, 0.35, 1.0, 0.5), 2.0)

	for i in range(6):
		var ang = (float(i) / 6.0) * TAU
		var p1 = Vector2(cos(ang), sin(ang)) * (r - 6.0)
		var p2 = Vector2(cos(ang), sin(ang)) * (r + 6.0)
		draw_line(p1, p2, Color(0.4, 0.85, 1.0, 0.85), 2.5)

	draw_circle(Vector2.ZERO, 5.0, Color(0.85, 0.95, 1.0, 0.9))
