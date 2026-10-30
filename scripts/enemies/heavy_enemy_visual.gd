extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0
var active_statuses: Array = []
var hp_ratio: float = 1.0

func _process(delta: float) -> void:
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE
	queue_redraw()

func trigger_hit_flash(duration: float = 0.12) -> void:
	is_flashing = true
	flash_timer = duration
	modulate = Color(2.5, 2.5, 2.5, 1.0)

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func set_statuses(statuses: Array) -> void:
	active_statuses = statuses

func update_health_display(current_hp: float, max_hp: float) -> void:
	hp_ratio = clamp(current_hp / max(1.0, max_hp), 0.0, 1.0)

func _draw() -> void:
	# Heavy Golem silhouette
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.06, 0.08, 0.35))

	# Heavy stone body
	var body_pts = PackedVector2Array([
		Vector2(-14, -14),
		Vector2(14, -14),
		Vector2(18, 6),
		Vector2(10, 18),
		Vector2(-10, 18),
		Vector2(-18, 6)
	])
	draw_colored_polygon(body_pts, Color(0.12, 0.09, 0.12, 1.0))
	draw_polyline(body_pts, Color(0.35, 0.2, 0.25, 0.9), 2.5)

	# Fissure / Core lines
	draw_line(Vector2(-6, -4), Vector2(4, 2), Color(0.9, 0.2, 0.1, 0.9), 2.5)
	draw_line(Vector2(4, 2), Vector2(0, 10), Color(1.0, 0.4, 0.1, 0.9), 2.0)

	# Eye
	var eye_center = Vector2.ZERO + facing_direction * 6.0
	draw_circle(eye_center, 4.0, Color(1.0, 0.2, 0.1, 1.0))
	draw_circle(eye_center, 1.5, Color.WHITE)

	# Status icons / dots (y=-30, elevated above health bar)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 5.0
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 10.0, -30.0)
			draw_circle(dot_pos, 2.8, col)
			draw_circle(dot_pos, 1.2, Color.WHITE)

	# Mini Health Bar (y=-22 when damaged)
	if hp_ratio < 1.0:
		var bar_w = 30.0
		var bar_h = 4.0
		var bar_pos = Vector2(-bar_w * 0.5, -22.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.12, 0.85), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), Color(0.85, 0.2, 0.25, 0.95), true)

