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
	# Hooded cultist
	draw_circle(Vector2.ZERO, 13.0, Color(0.2, 0.06, 0.25, 0.35))

	# Dark violet robe
	var robe_pts = PackedVector2Array([
		Vector2(-9, 10),
		Vector2(-7, -4),
		Vector2(7, -4),
		Vector2(9, 10)
	])
	draw_colored_polygon(robe_pts, Color(0.14, 0.08, 0.2, 1.0))

	# Hood
	draw_circle(Vector2(0, -5), 7.5, Color(0.18, 0.1, 0.28, 1.0))

	# Glowing purple orb in hand
	var hand_pos = facing_direction * 11.0 + Vector2(0, 2)
	draw_circle(hand_pos, 3.5, Color(0.85, 0.25, 0.95, 0.9))
	draw_circle(hand_pos, 1.5, Color.WHITE)

	# Eyes
	var eye_pos = facing_direction * 4.0 + Vector2(0, -5)
	draw_circle(eye_pos, 1.8, Color(0.9, 0.2, 0.9, 1.0))
