extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0

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

func _draw() -> void:
	# 1. Shadow / Void aura
	draw_circle(Vector2.ZERO, 15.0, Color(0.3, 0.05, 0.08, 0.35))

	# 2. Jagged fiend silhouette
	var body_color = Color(0.18, 0.06, 0.1, 1.0)
	draw_circle(Vector2.ZERO, 12.0, body_color)

	# 3. Spiky horns / shoulders
	var horn_left = Vector2(-8, -10)
	var horn_right = Vector2(8, -10)
	draw_line(Vector2(-4, -6), horn_left, Color(0.4, 0.1, 0.15, 1.0), 3.0)
	draw_line(Vector2(4, -6), horn_right, Color(0.4, 0.1, 0.15, 1.0), 3.0)

	# 4. Glowing Red/Amber Eye
	var eye_center = Vector2.ZERO + facing_direction * 4.0
	draw_circle(eye_center, 4.0, Color(1.0, 0.25, 0.1, 1.0))
	draw_circle(eye_center, 1.8, Color(1.0, 0.9, 0.3, 1.0))

