extends Node2D

var facing_direction: Vector2 = Vector2.RIGHT
var is_flashing: bool = false
var flash_timer: float = 0.0
var anim_time: float = 0.0

func _process(delta: float) -> void:
	anim_time += delta * 4.0
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
	var bobbing = sin(anim_time) * 1.5

	# 1. Runic aura ring on floor
	var aura_scale = 1.0 + sin(anim_time * 0.8) * 0.08
	draw_arc(Vector2(0, 10), 19.0 * aura_scale, 0, TAU, 32, Color(0.2, 0.7, 1.0, 0.45), 1.8)
	draw_circle(Vector2(0, 10), 16.0 * aura_scale, Color(0.1, 0.4, 0.9, 0.18))

	# 2. Flowing Wizard Robe
	var robe_pts = PackedVector2Array([
		Vector2(-14, 10 + bobbing),
		Vector2(-9, -2 + bobbing),
		Vector2(9, -2 + bobbing),
		Vector2(14, 10 + bobbing),
		Vector2(0, 13 + bobbing)
	])
	# Dark indigo robe
	draw_colored_polygon(robe_pts, Color(0.12, 0.1, 0.24, 1.0))
	# Cyan hem trim
	draw_polyline(PackedVector2Array([Vector2(-14, 10 + bobbing), Vector2(0, 13 + bobbing), Vector2(14, 10 + bobbing)]), Color(0.3, 0.85, 1.0, 0.8), 2.0)

	# 3. Wizard Hood & Shoulders
	draw_circle(Vector2(0, -3 + bobbing), 9.0, Color(0.18, 0.14, 0.32, 1.0))

	# 4. Pointed Wizard Hat (Iconic silhouette!)
	var hat_brim_left = Vector2(-15, -6 + bobbing)
	var hat_brim_right = Vector2(15, -6 + bobbing)
	var hat_brim_center = Vector2(0, -4 + bobbing)
	draw_colored_polygon(PackedVector2Array([hat_brim_left, hat_brim_right, hat_brim_center]), Color(0.1, 0.08, 0.2, 1.0))
	draw_line(hat_brim_left, hat_brim_right, Color(0.4, 0.85, 1.0, 0.85), 2.0)

	# Hat cone leaning slightly opposite facing
	var hat_tip = Vector2(-facing_direction.x * 4.0, -22 + bobbing)
	var hat_cone = PackedVector2Array([
		Vector2(-9, -6 + bobbing),
		Vector2(9, -6 + bobbing),
		hat_tip
	])
	draw_colored_polygon(hat_cone, Color(0.15, 0.11, 0.28, 1.0))

	# Glowing Star / Gem on Hat Tip
	draw_circle(hat_tip, 2.5, Color(1.0, 0.85, 0.3, 0.95))

	# 5. Glowing Mana Core in Chest
	var core_color = Color(0.3, 0.9, 1.0, 0.95)
	if is_flashing:
		core_color = Color(1.0, 0.2, 0.2, 1.0)
	draw_circle(Vector2(0, 2 + bobbing), 4.5, core_color)
	draw_circle(Vector2(0, 2 + bobbing), 2.0, Color.WHITE)

	# 6. Glowing Gaze / Eyes looking towards facing direction
	var eye_offset = facing_direction * 4.0 + Vector2(0, -3 + bobbing)
	draw_circle(eye_offset + Vector2(-2, 0), 1.8, Color(0.85, 1.0, 1.0, 0.95))
	draw_circle(eye_offset + Vector2(2, 0), 1.8, Color(0.85, 1.0, 1.0, 0.95))
