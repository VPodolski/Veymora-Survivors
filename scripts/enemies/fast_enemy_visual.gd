extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0
var active_statuses: Array = []
var hp_ratio: float = 1.0
var anim_wing: float = 0.0

func _process(delta: float) -> void:
	anim_wing += delta * 16.0
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE
	queue_redraw()

func trigger_hit_flash(duration: float = 0.10) -> void:
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
	# Nimble shadow bat / stalker silhouette
	var wing_flap = sin(anim_wing) * 5.0

	# Shadow trail
	draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.05, 0.3, 0.3))

	# Wings
	var left_wing = PackedVector2Array([
		Vector2(0, 0),
		Vector2(-14, -8 + wing_flap),
		Vector2(-8, 4)
	])
	var right_wing = PackedVector2Array([
		Vector2(0, 0),
		Vector2(14, -8 - wing_flap),
		Vector2(8, 4)
	])
	draw_colored_polygon(left_wing, Color(0.18, 0.08, 0.28, 0.95))
	draw_colored_polygon(right_wing, Color(0.18, 0.08, 0.28, 0.95))

	# Small sleek core
	draw_circle(Vector2.ZERO, 6.0, Color(0.12, 0.04, 0.18, 1.0))

	# Glowing Violet Eyes
	var eye_pos = facing_direction * 3.5
	draw_circle(eye_pos + Vector2(-1.5, -1), 1.5, Color(0.9, 0.3, 1.0, 1.0))
	draw_circle(eye_pos + Vector2(1.5, -1), 1.5, Color(0.9, 0.3, 1.0, 1.0))

	# Status icons / dots (y=-19, elevated above health bar)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 4.5
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 9.0, -19.0)
			draw_circle(dot_pos, 2.0, col)
			draw_circle(dot_pos, 0.8, Color.WHITE)

	# Mini Health Bar (y=-13 when damaged)
	if hp_ratio < 1.0:
		var bar_w = 18.0
		var bar_h = 2.5
		var bar_pos = Vector2(-bar_w * 0.5, -13.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.12, 0.85), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), Color(0.9, 0.25, 0.3, 0.95), true)

