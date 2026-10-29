extends Node2D

var facing_direction: Vector2 = Vector2.RIGHT
var is_flashing: bool = false
var flash_timer: float = 0.0

func _process(delta: float) -> void:
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE
	queue_redraw()

func trigger_hit_flash(duration: float = 0.15) -> void:
	is_flashing = true
	flash_timer = duration
	modulate = Color(2.5, 0.4, 0.4, 1.0) # Bright red-white flash

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func _draw() -> void:
	# 1. Arcane aura under feet
	draw_circle(Vector2.ZERO, 18.0, Color(0.15, 0.4, 0.9, 0.25))
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color(0.3, 0.7, 1.0, 0.5), 1.5)

	# 2. Mage robe body (Dark indigo / obsidian)
	draw_circle(Vector2(0, 1), 14.0, Color(0.12, 0.1, 0.22, 1.0))

	# 3. Hood / inner cloak
	draw_circle(Vector2(0, -2), 10.0, Color(0.2, 0.16, 0.35, 1.0))

	# 4. Arcane Glowing Core / Gem
	var core_color = Color(0.3, 0.9, 1.0, 0.95)
	if is_flashing:
		core_color = Color(1.0, 0.2, 0.2, 1.0)
	draw_circle(Vector2(0, -2), 5.0, core_color)
	draw_circle(Vector2(0, -2), 2.5, Color.WHITE)

	# 5. Facing gaze / pointer
	var eye_pos = Vector2(0, -2) + facing_direction * 4.0
	draw_circle(eye_pos, 2.0, Color(0.8, 1.0, 1.0, 0.9))

