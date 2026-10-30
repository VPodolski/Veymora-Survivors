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
	modulate = Color(2.2, 0.5, 0.5, 1.0) # Hit flash

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func _draw() -> void:
	var bobbing = sin(anim_time) * 1.4

	# 1. Floor Magic Rune Circle
	var aura_scale = 1.0 + sin(anim_time * 0.8) * 0.07
	draw_arc(Vector2(0, 11), 18.0 * aura_scale, 0, TAU, 32, Color(0.2, 0.65, 1.0, 0.35), 1.6)
	draw_circle(Vector2(0, 11), 14.0 * aura_scale, Color(0.1, 0.35, 0.8, 0.10))

	# 2. Lower Robe (Flared skirt) & Hem
	var robe_pts = PackedVector2Array([
		Vector2(-10, 4 + bobbing),
		Vector2(10, 4 + bobbing),
		Vector2(14, 11 + bobbing),
		Vector2(0, 13 + bobbing),
		Vector2(-14, 11 + bobbing)
	])
	draw_colored_polygon(robe_pts, Color(0.11, 0.09, 0.22, 1.0)) # Deep indigo robe
	# Cyan hem trim
	draw_polyline(PackedVector2Array([
		Vector2(-14, 11 + bobbing),
		Vector2(0, 13 + bobbing),
		Vector2(14, 11 + bobbing)
	]), Color(0.3, 0.85, 1.0, 0.85), 2.0)

	# Boots peeking out
	draw_rect(Rect2(-6, 12 + bobbing, 4, 3), Color(0.18, 0.12, 0.1, 1.0), true)
	draw_rect(Rect2(2, 12 + bobbing, 4, 3), Color(0.18, 0.12, 0.1, 1.0), true)

	# 3. Humanoid Torso & Shoulders
	var torso_pts = PackedVector2Array([
		Vector2(-12, -2 + bobbing),
		Vector2(12, -2 + bobbing),
		Vector2(10, 5 + bobbing),
		Vector2(-10, 5 + bobbing)
	])
	draw_colored_polygon(torso_pts, Color(0.14, 0.11, 0.26, 1.0))

	# Shoulder mantle & lapels
	var mantle_pts = PackedVector2Array([
		Vector2(-14, -2 + bobbing),
		Vector2(14, -2 + bobbing),
		Vector2(9, 2 + bobbing),
		Vector2(0, 4 + bobbing),
		Vector2(-9, 2 + bobbing)
	])
	draw_colored_polygon(mantle_pts, Color(0.18, 0.14, 0.32, 1.0))
	draw_line(Vector2(-13, -1 + bobbing), Vector2(0, 4 + bobbing), Color(0.35, 0.8, 1.0, 0.7), 1.5)
	draw_line(Vector2(13, -1 + bobbing), Vector2(0, 4 + bobbing), Color(0.35, 0.8, 1.0, 0.7), 1.5)

	# 4. Arms & Visible Hand with Focus Catalyst
	# Left and Right sleeve silhouettes
	draw_line(Vector2(-12, -1 + bobbing), Vector2(-11, 6 + bobbing), Color(0.12, 0.09, 0.22, 1.0), 3.0)
	draw_line(Vector2(12, -1 + bobbing), Vector2(11, 6 + bobbing), Color(0.12, 0.09, 0.22, 1.0), 3.0)

	# Casting hand holding focus orb
	var hand_x = facing_direction.x * 9.0
	var hand_pos = Vector2(hand_x, 3.0 + bobbing)
	# Hand skin
	draw_circle(hand_pos, 2.2, Color(0.88, 0.76, 0.68, 1.0))

	# Floating mana crystal / focus orb in hand
	var core_color = Color(0.3, 0.9, 1.0, 0.95)
	if is_flashing:
		core_color = Color(1.0, 0.25, 0.25, 1.0)
	var orb_pos = hand_pos + Vector2(facing_direction.x * 3.0, -1.0)
	draw_circle(orb_pos, 3.2, core_color)
	draw_circle(orb_pos, 1.4, Color.WHITE)

	# 5. High Collar & Neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4 + bobbing),
		Vector2(6, -4 + bobbing),
		Vector2(4, -1 + bobbing),
		Vector2(-4, -1 + bobbing)
	]), Color(0.1, 0.08, 0.2, 1.0))

	# 6. Anthropomorphic Head & Face
	# Hair background framing
	draw_circle(Vector2(0, -7 + bobbing), 6.5, Color(0.2, 0.16, 0.28, 1.0))

	# Face oval (warm stylized skin tone under brim shadow)
	var face_pos = Vector2(facing_direction.x * 1.5, -6.5 + bobbing)
	draw_circle(face_pos, 5.0, Color(0.86, 0.75, 0.66, 1.0))

	# Subtle facial profile / nose bridge
	var nose_dir = facing_direction.normalized()
	var nose_start = face_pos + Vector2(nose_dir.x * 2.0, -0.5)
	var nose_tip = face_pos + Vector2(nose_dir.x * 3.8, 0.5)
	draw_line(nose_start, nose_tip, Color(0.68, 0.55, 0.46, 0.85), 1.2)

	# Focused humanoid eyes with pupils (compact, natural proportions)
	var eye_center_x = face_pos.x + nose_dir.x * 1.2
	var eye_y = -7.0 + bobbing
	var eye_sep = 2.2

	var left_eye = Vector2(eye_center_x - eye_sep, eye_y)
	var right_eye = Vector2(eye_center_x + eye_sep, eye_y)

	# Eye whites/sockets
	draw_circle(left_eye, 1.4, Color(0.95, 0.96, 1.0, 0.95))
	draw_circle(right_eye, 1.4, Color(0.95, 0.96, 1.0, 0.95))
	# Cyan magical irises
	var pupil_offset = nose_dir * 0.5
	draw_circle(left_eye + pupil_offset, 0.9, Color(0.25, 0.85, 1.0, 1.0))
	draw_circle(right_eye + pupil_offset, 0.9, Color(0.25, 0.85, 1.0, 1.0))

	# 7. Iconic Wizard Hat (Pointed with tilt and star)
	# Hat Brim
	var brim_y = -9.0 + bobbing
	var hat_brim_left = Vector2(-15, brim_y)
	var hat_brim_right = Vector2(15, brim_y)
	var hat_brim_center = Vector2(0, brim_y + 2.0)
	draw_colored_polygon(PackedVector2Array([hat_brim_left, hat_brim_right, hat_brim_center]), Color(0.12, 0.08, 0.22, 1.0))
	# Cyan hat band
	draw_line(hat_brim_left, hat_brim_right, Color(0.35, 0.82, 1.0, 0.9), 2.0)

	# Hat Cone (Tapering cone leaning opposite facing direction)
	var hat_tip = Vector2(-facing_direction.x * 4.5, -24.0 + bobbing)
	var hat_cone = PackedVector2Array([
		Vector2(-9, brim_y),
		Vector2(9, brim_y),
		hat_tip
	])
	draw_colored_polygon(hat_cone, Color(0.15, 0.11, 0.28, 1.0))

	# Glowing 4-pointed golden wizard star at tip
	draw_line(hat_tip + Vector2(-3, 0), hat_tip + Vector2(3, 0), Color(1.0, 0.88, 0.35, 1.0), 1.6)
	draw_line(hat_tip + Vector2(0, -3), hat_tip + Vector2(0, 3), Color(1.0, 0.88, 0.35, 1.0), 1.6)
	draw_circle(hat_tip, 1.5, Color(1.0, 1.0, 0.8, 1.0))
