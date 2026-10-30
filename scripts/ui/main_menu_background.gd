class_name MainMenuBackground
extends Node2D

var anim_time: float = 0.0
var particles: Array[Dictionary] = []
const NUM_PARTICLES = 35

func _ready() -> void:
	# Initialize ambient floaty particles
	for i in range(NUM_PARTICLES):
		particles.append({
			"pos": Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0)),
			"vel": Vector2(randf_range(-10.0, 10.0), randf_range(-18.0, -38.0)),
			"size": randf_range(1.5, 3.5),
			"alpha": randf_range(0.2, 0.7),
			"phase": randf_range(0.0, TAU),
			"color": Color(0.35, 0.7, 1.0) if randf() > 0.4 else Color(0.75, 0.4, 1.0)
		})

func _process(delta: float) -> void:
	anim_time += delta
	for p in particles:
		p["pos"] += p["vel"] * delta
		if p["pos"].y < -20.0:
			p["pos"].y = 740.0
			p["pos"].x = randf_range(0.0, 1280.0)
		if p["pos"].x < -20.0:
			p["pos"].x = 1300.0
		elif p["pos"].x > 1300.0:
			p["pos"].x = -20.0
	queue_redraw()

func _draw() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1280, 720)

	var center = viewport_size * 0.5

	# 1. Background radial gradient simulation
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.03, 0.04, 0.07, 1.0))
	draw_circle(center, 420.0, Color(0.05, 0.12, 0.22, 0.25))
	draw_circle(center, 220.0, Color(0.12, 0.18, 0.38, 0.22))

	# 2. Ambient floating magical particles
	for p in particles:
		var pulse_a = p["alpha"] * (0.6 + 0.4 * sin(anim_time * 2.0 + p["phase"]))
		var c = Color(p["color"].r, p["color"].g, p["color"].b, pulse_a)
		draw_circle(p["pos"], p["size"], c)

	# 3. Rotating Rune Circles
	var rot_speed_1 = anim_time * 0.25
	var rot_speed_2 = -anim_time * 0.15

	# Outer dashed ring
	var r_outer = 260.0
	draw_arc(center, r_outer, 0, TAU, 64, Color(0.2, 0.5, 0.85, 0.18), 1.5)
	for i in range(12):
		var ang = rot_speed_1 + (float(i) / 12.0) * TAU
		var p1 = center + Vector2(cos(ang), sin(ang)) * (r_outer - 8.0)
		var p2 = center + Vector2(cos(ang), sin(ang)) * (r_outer + 8.0)
		draw_line(p1, p2, Color(0.3, 0.7, 1.0, 0.35), 2.0)

	# Middle ring
	var r_mid = 180.0
	draw_arc(center, r_mid, 0, TAU, 48, Color(0.5, 0.3, 0.9, 0.25), 2.0)
	for i in range(8):
		var ang = rot_speed_2 + (float(i) / 8.0) * TAU
		var p1 = center + Vector2(cos(ang), sin(ang)) * (r_mid - 6.0)
		var p2 = center + Vector2(cos(ang), sin(ang)) * (r_mid + 6.0)
		draw_line(p1, p2, Color(0.6, 0.4, 1.0, 0.4), 2.0)

	# Inner pulsing ring
	var pulse_inner = 110.0 + sin(anim_time * 1.8) * 4.0
	draw_arc(center, pulse_inner, 0, TAU, 36, Color(0.4, 0.85, 1.0, 0.35), 1.8)

	# 4. Stylized Mage Silhouette
	var float_y = sin(anim_time * 2.2) * 5.0
	var mage_pos = center + Vector2(0.0, 40.0 + float_y)

	# Dais / Aura beneath mage
	draw_circle(mage_pos + Vector2(0, 36), 46.0, Color(0.25, 0.6, 1.0, 0.15))
	draw_arc(mage_pos + Vector2(0, 36), 48.0, 0, TAU, 32, Color(0.4, 0.75, 1.0, 0.3), 1.5)

	# Robe / Body
	var robe_points = PackedVector2Array([
		mage_pos + Vector2(-16, 32),
		mage_pos + Vector2(-7, -4),
		mage_pos + Vector2(7, -4),
		mage_pos + Vector2(16, 32)
	])
	draw_colored_polygon(robe_points, Color(0.07, 0.1, 0.18, 0.95))
	draw_polyline(robe_points, Color(0.3, 0.6, 0.9, 0.5), 1.5)

	# Head / Shadow
	draw_circle(mage_pos + Vector2(0, -10), 9.0, Color(0.08, 0.12, 0.22, 1.0))

	# Pointed Hat
	var hat_points = PackedVector2Array([
		mage_pos + Vector2(-16, -11),
		mage_pos + Vector2(16, -11),
		mage_pos + Vector2(2, -34),
		mage_pos + Vector2(0, -34)
	])
	draw_colored_polygon(hat_points, Color(0.05, 0.08, 0.15, 1.0))
	draw_polyline(hat_points, Color(0.4, 0.7, 1.0, 0.7), 1.5)
	# Hat rim line
	draw_line(mage_pos + Vector2(-18, -10), mage_pos + Vector2(18, -10), Color(0.4, 0.75, 1.0, 0.85), 2.0)

	# Glowing Mage Eyes / Core
	var glow_intensity = 0.7 + 0.3 * sin(anim_time * 3.5)
	draw_circle(mage_pos + Vector2(-3, -9), 1.6, Color(0.4, 0.95, 1.0, glow_intensity))
	draw_circle(mage_pos + Vector2(3, -9), 1.6, Color(0.4, 0.95, 1.0, glow_intensity))

	# Magic Staff & Glowing Orb
	var staff_bottom = mage_pos + Vector2(22, 34)
	var staff_top = mage_pos + Vector2(22, -26)
	draw_line(staff_bottom, staff_top, Color(0.2, 0.35, 0.5, 0.9), 2.2)

	var orb_pos = staff_top + Vector2(0, -6)
	var orb_pulse = 5.5 + sin(anim_time * 4.0) * 1.5
	draw_circle(orb_pos, orb_pulse + 4.0, Color(0.3, 0.8, 1.0, 0.2))
	draw_circle(orb_pos, orb_pulse, Color(0.4, 0.9, 1.0, 0.85))
	draw_circle(orb_pos, 2.0, Color.WHITE)
