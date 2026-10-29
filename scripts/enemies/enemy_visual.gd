extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0
var active_statuses: Array[String] = []

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
	modulate = Color(2.5, 2.5, 2.5, 1.0) # White hit flash

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func set_statuses(statuses: Array[String]) -> void:
	active_statuses = statuses

func _draw() -> void:
	# 1. Shadow / Void aura
	draw_circle(Vector2.ZERO, 15.0, Color(0.3, 0.05, 0.08, 0.35))

	# Status auras
	if active_statuses.has(StatusEffects.STATUS_SLOWED):
		draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.8, 1.0, 0.25))
	if active_statuses.has(StatusEffects.STATUS_CHARGED):
		draw_circle(Vector2.ZERO, 17.0, Color(0.5, 0.6, 1.0, 0.3))
	if active_statuses.has(StatusEffects.STATUS_UNSTABLE):
		draw_circle(Vector2.ZERO, 18.0, Color(0.8, 0.2, 1.0, 0.3))

	# 2. Jagged fiend silhouette
	var body_color = Color(0.18, 0.06, 0.1, 1.0)
	if active_statuses.has(StatusEffects.STATUS_SLOWED):
		body_color = Color(0.12, 0.18, 0.25, 1.0) # Frost-tinted
	draw_circle(Vector2.ZERO, 12.0, body_color)

	# 3. Spiky horns / shoulders
	var horn_left = Vector2(-8, -10)
	var horn_right = Vector2(8, -10)
	draw_line(Vector2(-4, -6), horn_left, Color(0.4, 0.1, 0.15, 1.0), 3.0)
	draw_line(Vector2(4, -6), horn_right, Color(0.4, 0.1, 0.15, 1.0), 3.0)

	# 4. Glowing Eye
	var eye_center = Vector2.ZERO + facing_direction * 4.0
	draw_circle(eye_center, 4.0, Color(1.0, 0.25, 0.1, 1.0))
	draw_circle(eye_center, 1.8, Color(1.0, 0.9, 0.3, 1.0))

	# 5. Status icons / gems above head
	var status_offset_x = -float(active_statuses.size() - 1) * 5.0
	for i in range(active_statuses.size()):
		var s_name = active_statuses[i]
		var col = StatusEffects.get_status_color(s_name)
		var dot_pos = Vector2(status_offset_x + float(i) * 10.0, -18.0)
		draw_circle(dot_pos, 3.0, col)
		draw_circle(dot_pos, 1.2, Color.WHITE)
