extends SceneTree

const ICON_SIZE = Vector2i(1024, 1024)
const COVER_SIZE = Vector2i(1920, 1080)
const SCREENSHOT_SIZE = Vector2i(1280, 720)

func _init() -> void:
	print("--- Generating Promo Materials for Pikabu / GamePush ---")
	call_deferred("generate_all_materials")

func generate_all_materials() -> void:
	DirAccess.make_dir_recursive_absolute("res://media/store")

	_generate_icon()
	_generate_cover()
	_generate_screenshot_gameplay()
	_generate_screenshot_synergies()
	_generate_screenshot_boss()
	_generate_screenshot_artifacts()

	print("--- ALL PROMO MATERIALS GENERATED SUCCESSFULLY IN media/store/ ---")
	quit(0)

func _generate_icon() -> void:
	var img = Image.create(ICON_SIZE.x, ICON_SIZE.y, false, Image.FORMAT_RGBA8)
	var center = Vector2(ICON_SIZE.x * 0.5, ICON_SIZE.y * 0.5)

	# Radial gradient dark mystical background
	for y in range(ICON_SIZE.y):
		for x in range(ICON_SIZE.x):
			var dist = Vector2(x, y).distance_to(center)
			var t = clampf(dist / (ICON_SIZE.x * 0.7), 0.0, 1.0)
			var bg_col = Color(0.05, 0.04, 0.12).lerp(Color(0.015, 0.015, 0.04), t)
			img.set_pixel(x, y, bg_col)

	# Draw glowing rune rings and wizard silhouette
	_draw_circle_aa(img, center, 380, Color(0.2, 0.5, 0.9, 0.25), 8)
	_draw_circle_aa(img, center, 320, Color(0.4, 0.2, 0.8, 0.35), 6)
	_draw_circle_aa(img, center, 240, Color(0.2, 0.8, 1.0, 0.5), 10)
	_draw_circle_aa(img, center, 140, Color(0.7, 0.3, 1.0, 0.6), 5)

	# Central glowing magic core
	for r in range(80, 0, -1):
		var alpha = (1.0 - float(r) / 80.0) * 0.8
		_draw_circle_aa(img, center, r, Color(0.4, 0.85, 1.0, alpha), 2)

	# Wizard Hat silhouette in center
	for dy in range(-120, 120):
		var py = center.y + dy
		var width = max(0.0, float(dy + 120) * 0.75)
		if dy > 60:
			width = 160.0 - float(dy - 60) * 1.5 # Brim
		for dx in range(-int(width), int(width)):
			var px = center.x + dx
			if px >= 0 and px < ICON_SIZE.x and py >= 0 and py < ICON_SIZE.y:
				var col = Color(0.08, 0.08, 0.16, 0.95)
				if dy > 20 and dy < 40:
					col = Color(0.3, 0.8, 1.0, 0.9) # Hat band
				img.set_pixel(int(px), int(py), col)

	img.save_png("res://media/store/icon_1024x1024.png")
	print("[PROMO] Saved media/store/icon_1024x1024.png")

func _generate_cover() -> void:
	var img = Image.create(COVER_SIZE.x, COVER_SIZE.y, false, Image.FORMAT_RGBA8)
	var center = Vector2(COVER_SIZE.x * 0.5, COVER_SIZE.y * 0.5)

	for y in range(COVER_SIZE.y):
		for x in range(COVER_SIZE.x):
			var dist = Vector2(x, y).distance_to(center)
			var t = clampf(dist / (COVER_SIZE.x * 0.6), 0.0, 1.0)
			var bg_col = Color(0.06, 0.04, 0.14).lerp(Color(0.015, 0.01, 0.03), t)
			img.set_pixel(x, y, bg_col)

	# Left & right magical energy vortex
	_draw_circle_aa(img, Vector2(COVER_SIZE.x * 0.25, center.y), 300, Color(0.2, 0.7, 1.0, 0.2), 6)
	_draw_circle_aa(img, Vector2(COVER_SIZE.x * 0.75, center.y), 300, Color(0.8, 0.25, 0.4, 0.2), 6)
	_draw_circle_aa(img, center, 420, Color(0.5, 0.3, 0.9, 0.25), 8)

	img.save_png("res://media/store/cover_1920x1080.png")
	print("[PROMO] Saved media/store/cover_1920x1080.png")

func _generate_screenshot_gameplay() -> void:
	var img = Image.create(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, false, Image.FORMAT_RGBA8)
	_fill_arena_background(img, SCREENSHOT_SIZE)

	# Player in center
	var p_pos = Vector2(SCREENSHOT_SIZE.x * 0.5, SCREENSHOT_SIZE.y * 0.5)
	_draw_player(img, p_pos)

	# Magic bolt projectiles firing toward enemies
	for i in range(4):
		var angle = i * (PI * 0.5) + 0.3
		var proj_pos = p_pos + Vector2(cos(angle), sin(angle)) * 140.0
		_draw_circle_aa(img, proj_pos, 10, Color(0.3, 0.85, 1.0, 0.9), 4)

	# Swarm of basic and fast enemies closing in
	for i in range(16):
		var ang = i * (TAU / 16.0)
		var dist = 280.0 + (i % 3) * 60.0
		var e_pos = p_pos + Vector2(cos(ang), sin(ang)) * dist
		var col = Color(0.8, 0.2, 0.25, 0.9) if (i % 2 == 0) else Color(0.6, 0.2, 0.7, 0.9)
		_draw_circle_aa(img, e_pos, 14, col, 3)

	# Scattered XP gems
	for i in range(25):
		var gx = randf_range(100, SCREENSHOT_SIZE.x - 100)
		var gy = randf_range(100, SCREENSHOT_SIZE.y - 100)
		_draw_circle_aa(img, Vector2(gx, gy), 5, Color(0.3, 1.0, 0.7, 0.85), 2)

	_draw_hud_overlay(img, SCREENSHOT_SIZE, "LV 7", "04:32")
	img.save_png("res://media/store/screenshot_1_gameplay.png")
	print("[PROMO] Saved media/store/screenshot_1_gameplay.png")

func _generate_screenshot_synergies() -> void:
	var img = Image.create(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, false, Image.FORMAT_RGBA8)
	_fill_arena_background(img, SCREENSHOT_SIZE)
	var p_pos = Vector2(SCREENSHOT_SIZE.x * 0.45, SCREENSHOT_SIZE.y * 0.5)
	_draw_player(img, p_pos)

	# Synergy 1: Steam Rift vapor cloud
	var rift_pos = p_pos + Vector2(160, -80)
	_draw_circle_aa(img, rift_pos, 90, Color(0.8, 0.9, 1.0, 0.35), 6)
	_draw_circle_aa(img, rift_pos, 60, Color(1.0, 0.6, 0.3, 0.45), 4)

	# Synergy 2: Frost Shatter physical shards
	for k in range(7):
		var shard_ang = k * (TAU / 7.0)
		var s_pos = (p_pos + Vector2(-120, 80)) + Vector2(cos(shard_ang), sin(shard_ang)) * 70.0
		_draw_circle_aa(img, s_pos, 8, Color(0.4, 0.85, 1.0, 0.95), 3)

	# Synergy 3: Lightning Chain electric arcs
	var arc_p1 = p_pos + Vector2(-150, -120)
	var arc_p2 = p_pos + Vector2(-240, -60)
	_draw_line(img, arc_p1, arc_p2, Color(1.0, 0.9, 0.3, 0.95), 3)

	_draw_hud_overlay(img, SCREENSHOT_SIZE, "LV 12", "08:15")
	img.save_png("res://media/store/screenshot_2_synergies.png")
	print("[PROMO] Saved media/store/screenshot_2_synergies.png")

func _generate_screenshot_boss() -> void:
	var img = Image.create(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, false, Image.FORMAT_RGBA8)
	_fill_arena_background(img, SCREENSHOT_SIZE)
	var p_pos = Vector2(250, SCREENSHOT_SIZE.y * 0.5)
	_draw_player(img, p_pos)

	# Boss entity on right
	var boss_pos = Vector2(SCREENSHOT_SIZE.x - 300, SCREENSHOT_SIZE.y * 0.5)
	_draw_circle_aa(img, boss_pos, 80, Color(0.9, 0.15, 0.25, 0.9), 10)
	_draw_circle_aa(img, boss_pos, 110, Color(0.6, 0.1, 0.3, 0.4), 6)

	# Boss telegraph circles
	_draw_circle_aa(img, p_pos + Vector2(100, -80), 90, Color(1.0, 0.2, 0.2, 0.5), 3)
	_draw_circle_aa(img, p_pos + Vector2(60, 100), 75, Color(1.0, 0.2, 0.2, 0.5), 3)

	# Boss health bar top center
	var bar_w = 400
	var bar_h = 16
	var bar_x = (SCREENSHOT_SIZE.x - bar_w) / 2
	var bar_y = 50
	for by in range(bar_y, bar_y + bar_h):
		for bx in range(bar_x, bar_x + bar_w):
			var filled = (bx - bar_x) < int(bar_w * 0.68)
			var col = Color(0.9, 0.2, 0.25, 1.0) if filled else Color(0.2, 0.1, 0.1, 0.8)
			img.set_pixel(bx, by, col)

	_draw_hud_overlay(img, SCREENSHOT_SIZE, "LV 15", "11:42")
	img.save_png("res://media/store/screenshot_3_boss.png")
	print("[PROMO] Saved media/store/screenshot_3_boss.png")

func _generate_screenshot_artifacts() -> void:
	var img = Image.create(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, false, Image.FORMAT_RGBA8)
	_fill_arena_background(img, SCREENSHOT_SIZE)

	# Dark modal overlay
	for y in range(SCREENSHOT_SIZE.y):
		for x in range(SCREENSHOT_SIZE.x):
			var cur = img.get_pixel(x, y)
			img.set_pixel(x, y, cur.lerp(Color(0, 0, 0, 1), 0.65))

	# 3 Artifact cards
	var card_w = 260
	var card_h = 360
	var gap = 40
	var total_w = 3 * card_w + 2 * gap
	var start_x = (SCREENSHOT_SIZE.x - total_w) / 2
	var card_y = (SCREENSHOT_SIZE.y - card_h) / 2 + 30

	var card_colors = [
		Color(0.2, 0.6, 0.9), # Frost Core
		Color(0.9, 0.8, 0.2), # Lightning Rod
		Color(0.9, 0.3, 0.2)  # Obsidian Heart
	]

	for i in range(3):
		var cx = start_x + i * (card_w + gap)
		var accent = card_colors[i]
		for cy in range(card_y, card_y + card_h):
			for px in range(cx, cx + card_w):
				var border = (px == cx or px == cx + card_w - 1 or cy == card_y or cy == card_y + card_h - 1)
				var col = accent if border else Color(0.08, 0.08, 0.14, 0.95)
				img.set_pixel(px, cy, col)
		# Card icon circle
		_draw_circle_aa(img, Vector2(cx + card_w * 0.5, card_y + 90), 45, accent, 4)

	img.save_png("res://media/store/screenshot_4_artifacts.png")
	print("[PROMO] Saved media/store/screenshot_4_artifacts.png")

func _fill_arena_background(img: Image, size: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			var noise_val = (sin(x * 0.02) + cos(y * 0.02)) * 0.02
			var bg = Color(0.04 + noise_val, 0.04 + noise_val, 0.09 + noise_val, 1.0)
			img.set_pixel(x, y, bg)

func _draw_player(img: Image, pos: Vector2) -> void:
	_draw_circle_aa(img, pos, 22, Color(0.3, 0.7, 1.0, 0.9), 3)
	_draw_circle_aa(img, pos, 12, Color(0.8, 0.95, 1.0, 1.0), 2)

func _draw_hud_overlay(img: Image, size: Vector2i, _lvl: String, _timer: String) -> void:
	# Top bar
	for y in range(0, 36):
		for x in range(size.x):
			var cur = img.get_pixel(x, y)
			img.set_pixel(x, y, cur.lerp(Color(0.02, 0.02, 0.05, 1.0), 0.8))

func _draw_circle_aa(img: Image, center: Vector2, radius: float, color: Color, thickness: float) -> void:
	var r_min = radius - thickness * 0.5
	var r_max = radius + thickness * 0.5
	var min_x = clampi(int(center.x - r_max - 1), 0, img.get_width() - 1)
	var max_x = clampi(int(center.x + r_max + 1), 0, img.get_width() - 1)
	var min_y = clampi(int(center.y - r_max - 1), 0, img.get_height() - 1)
	var max_y = clampi(int(center.y + r_max + 1), 0, img.get_height() - 1)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d = Vector2(x, y).distance_to(center)
			if d >= r_min and d <= r_max:
				var edge_fade = 1.0 - absf(d - radius) / (thickness * 0.5)
				var cur = img.get_pixel(x, y)
				var out = cur.lerp(color, color.a * edge_fade)
				img.set_pixel(x, y, out)

func _draw_line(img: Image, p1: Vector2, p2: Vector2, color: Color, thickness: float) -> void:
	var steps = int(p1.distance_to(p2))
	for i in range(steps):
		var t = float(i) / float(steps)
		var pt = p1.lerp(p2, t)
		_draw_circle_aa(img, pt, thickness * 0.5, color, thickness)
