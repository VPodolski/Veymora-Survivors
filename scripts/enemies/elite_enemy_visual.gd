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
	# Golden Elite Ring
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.6), 2.5)
	draw_circle(Vector2.ZERO, 24.0, Color(0.4, 0.05, 0.1, 0.35))

	# Heavy armored body
	draw_circle(Vector2.ZERO, 18.0, Color(0.14, 0.1, 0.12, 1.0))
	# Metallic plates
	draw_arc(Vector2.ZERO, 16.0, -PI * 0.7, PI * 0.7, 16, Color(0.7, 0.55, 0.2, 1.0), 3.0)

	# Massive spiked pauldrons
	draw_line(Vector2(-12, -12), Vector2(-22, -22), Color(0.85, 0.7, 0.25, 1.0), 4.5)
	draw_line(Vector2(12, -12), Vector2(22, -22), Color(0.85, 0.7, 0.25, 1.0), 4.5)

	# Glowing Ruby Eye / Core
	var eye_center = Vector2.ZERO + facing_direction * 6.0
	draw_circle(eye_center, 6.0, Color(1.0, 0.15, 0.25, 1.0))
	draw_circle(eye_center, 2.5, Color.WHITE)

	# Always visible Elite HP bar
	var bar_w = 36.0
	var bar_h = 4.0
	var bar_pos = Vector2(-bar_w * 0.5, -26.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.12, 0.9), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), Color(1.0, 0.25, 0.3, 1.0), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(1.0, 0.8, 0.2, 0.8), false, 1.0)

	# Status icons / dots (y=-34, elevated above health bar)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 5.0
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 10.0, -34.0)
			draw_circle(dot_pos, 2.8, col)
			draw_circle(dot_pos, 1.2, Color.WHITE)

