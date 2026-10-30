class_name CombatEffects
extends RefCounted

# FX Intensity settings: "standard" or "reduced"
static var fx_intensity: String = "standard"

# Centralized Effect Concurrency Limits
# Categories:
# - Critical: Hazard telegraphs, boss warnings (never suppressed by decorative cap)
# - Gameplay: Status marks, projectile trails, lightning chains
# - Decorative: Hit flashes, rings, shockwaves, geometric shards, fractures, impact sparks
# - UI: Damage numbers, text popups
static var active_decorative_effects: int = 0
static var active_damage_numbers: int = 0
static var active_text_popups: int = 0
static var active_priority_popups: int = 0
static var active_chains: int = 0

const MAX_DECORATIVE_STANDARD = 36
const MAX_DECORATIVE_REDUCED = 16
const MAX_DAMAGE_NUMBERS = 24
const MAX_TEXT_POPUPS = 5
const MAX_PRIORITY_POPUPS = 3
const MAX_CHAINS = 12

# Cooldown per target for decorative hit flashes (avoids blinding whiteout in dense horde)
static var target_flash_timestamps: Dictionary = {}
static var recent_text_popups: Dictionary = {}

static func set_fx_intensity(mode: String) -> void:
	if mode in ["standard", "reduced"]:
		fx_intensity = mode

static func get_max_decorative() -> int:
	return MAX_DECORATIVE_STANDARD if fx_intensity == "standard" else MAX_DECORATIVE_REDUCED

static func get_particle_multiplier() -> float:
	return 1.0 if fx_intensity == "standard" else 0.5

static func can_spawn_decorative() -> bool:
	return active_decorative_effects < get_max_decorative()

static func reset() -> void:
	active_decorative_effects = 0
	active_damage_numbers = 0
	active_text_popups = 0
	active_priority_popups = 0
	active_chains = 0
	target_flash_timestamps.clear()
	recent_text_popups.clear()

# --- 1. Hit Flash Primitive ---
static func spawn_hit_flash(parent: Node, pos: Vector2, col: Color = Color.WHITE, max_radius: float = 14.0) -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var flash = HitFlashEffect.new(col, max_radius)
	flash.global_position = pos
	flash.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(flash)

# --- 2. Ring Primitive (Expanding or Contracting) ---
static func spawn_ring(parent: Node, pos: Vector2, r_start: float, r_end: float, col: Color, duration: float = 0.25, line_w: float = 2.0) -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var ring = RingEffect.new(r_start, r_end, col, duration, line_w)
	ring.global_position = pos
	ring.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(ring)

# --- 3. Shockwave Primitive ---
static func spawn_shockwave(parent: Node, pos: Vector2, max_radius: float = 85.0, col: Color = Color(0.4, 0.7, 1.0, 0.9), duration: float = 0.25) -> void:
	if not parent:
		return
	if not can_spawn_decorative() and max_radius < 100.0:
		return
	active_decorative_effects += 1
	var wave = ShockwaveEffect.new(max_radius, col, duration)
	wave.global_position = pos
	wave.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(wave)

# --- 4. Directional Trail Primitive ---
static func spawn_projectile_trail(parent: Node, pos: Vector2, dir: Vector2, length: float, col: Color) -> void:
	if not parent or not can_spawn_decorative():
		return
	if fx_intensity == "reduced":
		length *= 0.6
	active_decorative_effects += 1
	var trail = TrailEffect.new(dir, length, col)
	trail.global_position = pos
	trail.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(trail)

# --- 5. Lightning Arc / Multi-Chain Primitive ---
static func spawn_lightning_arc(parent: Node, from_pos: Vector2, to_pos: Vector2, col: Color = Color(0.5, 0.85, 1.0, 1.0), line_width: float = 2.4) -> void:
	if not parent or active_chains >= MAX_CHAINS:
		return
	active_chains += 1
	var arc = LightningArcEffect.new(from_pos, to_pos, col, line_width)
	arc.tree_exited.connect(func(): active_chains = max(0, active_chains - 1))
	parent.add_child(arc)

# --- 6. Geometric Shards Primitive ---
static func spawn_geometric_shards(parent: Node, pos: Vector2, col: Color = Color(0.3, 0.9, 1.0, 1.0), count: int = 5, speed: float = 180.0) -> void:
	if not parent or not can_spawn_decorative():
		return
	var final_count = int(ceil(float(count) * get_particle_multiplier()))
	if final_count <= 0:
		return
	active_decorative_effects += 1
	var shards = GeometricShardsEffect.new(col, final_count, speed)
	shards.global_position = pos
	shards.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(shards)

# --- 7. Status Mark Primitive ---
static func spawn_status_mark(parent: Node, pos: Vector2, col: Color, mark_glyph: String = "◆") -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var mark = StatusMarkEffect.new(col, mark_glyph)
	mark.global_position = pos
	mark.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(mark)

# --- 8. Magic Rift Fracture Primitive ---
static func spawn_rift_fracture(parent: Node, pos: Vector2, radius: float = 40.0, col: Color = Color(0.85, 0.3, 1.0, 0.95)) -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var rift = RiftFractureEffect.new(radius, col)
	rift.global_position = pos
	rift.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(rift)

# --- 9. AoE Indicator Primitive ---
static func spawn_aoe_indicator(parent: Node, pos: Vector2, radius: float, col: Color, duration: float = 0.5) -> Node2D:
	if not parent or not can_spawn_decorative():
		return null
	active_decorative_effects += 1
	var aoe = AoEIndicatorEffect.new(radius, col, duration)
	aoe.global_position = pos
	aoe.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(aoe)
	return aoe

# --- 10. Target Highlight / Silhouette Pulse Primitive ---
static func spawn_target_highlight(target: Node2D, col: Color = Color(1.0, 0.85, 0.4, 0.9), radius: float = 22.0) -> void:
	if not target or not is_instance_valid(target) or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var hl = TargetHighlightEffect.new(radius, col)
	hl.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	target.add_child(hl)

# --- 11. Hazard Telegraph Primitive (Critical Category: High Priority, ignores decorative cap) ---
static func spawn_hazard_telegraph(parent: Node, pos: Vector2, dir: Vector2, length: float, width: float, duration: float = 0.6) -> Node2D:
	if not parent:
		return null
	var telegraph = HazardTelegraphEffect.new(dir, length, width, duration)
	telegraph.global_position = pos
	parent.add_child(telegraph)
	return telegraph

# --- 12. Reward Pickup Pulse Primitive ---
static func spawn_reward_pickup(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.85, 0.25, 1.0)) -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var pickup = RewardPickupEffect.new(col)
	pickup.global_position = pos
	pickup.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	parent.add_child(pickup)

# --- Floating Text & Damage Numbers (UI Category) ---
static func spawn_text_popup(parent: Node, pos: Vector2, text: String, col: Color, is_priority: bool = false) -> void:
	if not parent:
		return

	var now = Time.get_ticks_msec()
	# Suppress duplicate identical notifications within 350ms to prevent visual clutter
	if recent_text_popups.has(text) and (now - recent_text_popups[text]) < 350:
		return

	if is_priority:
		if active_priority_popups >= MAX_PRIORITY_POPUPS:
			return
		active_priority_popups += 1
		recent_text_popups[text] = now
		var popup = FloatingTextEffect.new(text, col)
		popup.tree_exited.connect(func(): active_priority_popups = max(0, active_priority_popups - 1))
		popup.global_position = pos
		parent.add_child(popup)
	else:
		if active_text_popups >= MAX_TEXT_POPUPS:
			return
		active_text_popups += 1
		recent_text_popups[text] = now
		var popup = FloatingTextEffect.new(text, col)
		popup.tree_exited.connect(func(): active_text_popups = max(0, active_text_popups - 1))
		popup.global_position = pos
		parent.add_child(popup)

static func spawn_damage_number(parent: Node, pos: Vector2, amount: float, col: Color = Color(1.0, 0.92, 0.5, 1.0)) -> void:
	if not parent:
		return
	var threshold = 25.0 if fx_intensity == "reduced" else 15.0
	if active_damage_numbers >= MAX_DAMAGE_NUMBERS and amount < threshold:
		return
	active_damage_numbers += 1
	var dmg_num = DamageNumberEffect.new(int(round(amount)), col)
	dmg_num.tree_exited.connect(func(): active_damage_numbers = max(0, active_damage_numbers - 1))
	dmg_num.global_position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-14.0, -6.0))
	parent.add_child(dmg_num)

static func spawn_impact_sparks(parent: Node, pos: Vector2, col: Color = Color(0.4, 0.9, 1.0, 1.0), count: int = 4) -> void:
	if not parent or not can_spawn_decorative():
		return
	var final_count = int(ceil(float(count) * get_particle_multiplier()))
	if final_count <= 0:
		return
	active_decorative_effects += 1
	var sparks = ImpactSparksEffect.new(col, final_count)
	sparks.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	sparks.global_position = pos
	parent.add_child(sparks)

static func spawn_death_burst(parent: Node, pos: Vector2) -> void:
	if not parent or not can_spawn_decorative():
		return
	active_decorative_effects += 1
	var burst = DeathBurstEffect.new()
	burst.tree_exited.connect(func(): active_decorative_effects = max(0, active_decorative_effects - 1))
	burst.global_position = pos
	parent.add_child(burst)


# ==============================================================================
# SUBCLASSES — Visual Primitive Implementations
# ==============================================================================

# 1. Hit Flash Effect
class HitFlashEffect extends Node2D:
	var flash_color: Color
	var max_radius: float
	var cur_radius: float = 2.0

	func _init(col: Color, p_radius: float) -> void:
		flash_color = col
		max_radius = p_radius

	func _ready() -> void:
		var dur = 0.12 if CombatEffects.fx_intensity == "standard" else 0.09
		var tween = create_tween()
		tween.tween_property(self, "cur_radius", max_radius, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, dur)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, cur_radius * 0.45, Color.WHITE)
		draw_circle(Vector2.ZERO, cur_radius, Color(flash_color.r, flash_color.g, flash_color.b, flash_color.a * 0.55))

# 2. Ring Effect (Expanding or Contracting)
class RingEffect extends Node2D:
	var r_start: float
	var r_end: float
	var cur_radius: float
	var ring_color: Color
	var line_w: float
	var duration: float

	func _init(p_start: float, p_end: float, col: Color, dur: float, width: float) -> void:
		r_start = p_start
		r_end = p_end
		cur_radius = r_start
		ring_color = col
		duration = dur
		line_w = width

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "cur_radius", r_end, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, max(1.0, cur_radius), 0, TAU, 28, ring_color, line_w)

# 3. Shockwave Effect
class ShockwaveEffect extends Node2D:
	var target_radius: float
	var current_radius: float = 4.0
	var wave_color: Color
	var duration: float

	func _init(p_radius: float, p_color: Color, p_dur: float = 0.25) -> void:
		target_radius = p_radius
		wave_color = p_color
		duration = p_dur

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "current_radius", target_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, wave_color, 2.8)
		draw_circle(Vector2.ZERO, current_radius * 0.65, Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * 0.12))

# 4. Projectile Trail Effect
class TrailEffect extends Node2D:
	var dir: Vector2
	var length: float
	var trail_color: Color

	func _init(p_dir: Vector2, p_len: float, col: Color) -> void:
		dir = p_dir.normalized()
		length = p_len
		trail_color = col

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		var start = Vector2.ZERO
		var end = -dir * length
		draw_line(start, end, trail_color, 2.0)
		draw_line(start, end * 0.5, Color.WHITE, 1.2)

# 5. Lightning Arc Effect
class LightningArcEffect extends Node2D:
	var start_pos: Vector2
	var end_pos: Vector2
	var arc_color: Color
	var line_width: float
	var segments: PackedVector2Array = []

	func _init(p_start: Vector2, p_end: Vector2, p_color: Color, width: float = 2.4) -> void:
		start_pos = p_start
		end_pos = p_end
		arc_color = p_color
		line_width = width
		generate_jagged_line()

	func generate_jagged_line() -> void:
		segments.append(start_pos)
		var diff = end_pos - start_pos
		var count = 4 if CombatEffects.fx_intensity == "standard" else 3
		for i in range(1, count):
			var t = float(i) / float(count)
			var base = start_pos + diff * t
			var perp = Vector2(-diff.y, diff.x).normalized() * randf_range(-12.0, 12.0)
			segments.append(base + perp)
		segments.append(end_pos)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.18)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		if segments.size() >= 2:
			draw_polyline(segments, arc_color, line_width)
			draw_polyline(segments, Color.WHITE, max(1.0, line_width * 0.4))

# 6. Geometric Shards Effect (Ice / Crystal shatter)
class GeometricShardsEffect extends Node2D:
	var shard_color: Color
	var shard_count: int
	var shard_positions: Array[Vector2] = []
	var shard_vels: Array[Vector2] = []
	var shard_angles: Array[float] = []
	var shard_rot_speeds: Array[float] = []

	func _init(col: Color, count: int, speed: float) -> void:
		shard_color = col
		shard_count = count
		for i in range(count):
			shard_positions.append(Vector2.ZERO)
			var angle = randf() * TAU
			var spd = randf_range(speed * 0.7, speed * 1.3)
			shard_vels.append(Vector2(cos(angle), sin(angle)) * spd)
			shard_angles.append(randf() * TAU)
			shard_rot_speeds.append(randf_range(-10.0, 10.0))

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		for i in range(shard_count):
			shard_positions[i] += shard_vels[i] * delta
			shard_vels[i] *= 0.91
			shard_angles[i] += shard_rot_speeds[i] * delta
		queue_redraw()

	func _draw() -> void:
		for i in range(shard_count):
			var pos = shard_positions[i]
			var ang = shard_angles[i]
			var pts = PackedVector2Array([
				pos + Vector2(cos(ang), sin(ang)) * 6.0,
				pos + Vector2(cos(ang + 2.2), sin(ang + 2.2)) * 3.5,
				pos + Vector2(cos(ang + 4.1), sin(ang + 4.1)) * 3.5
			])
			draw_colored_polygon(pts, shard_color)
			draw_polyline(pts, Color.WHITE, 1.0)

# 7. Status Mark Effect (Hovering symbol above target)
class StatusMarkEffect extends Node2D:
	var mark_color: Color
	var glyph: String
	var label: Label

	func _init(col: Color, p_glyph: String) -> void:
		mark_color = col
		glyph = p_glyph
		label = Label.new()
		label.text = glyph
		label.add_theme_color_override("font_color", mark_color)
		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-15, -28)
		label.custom_minimum_size = Vector2(30, 20)
		add_child(label)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 12.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)

# 8. Magic Rift Fracture Effect (Void / Instability)
class RiftFractureEffect extends Node2D:
	var radius: float
	var rift_color: Color
	var crack_pts: PackedVector2Array = []

	func _init(r: float, col: Color) -> void:
		radius = r
		rift_color = col
		generate_crack()

	func generate_crack() -> void:
		crack_pts.append(Vector2(-radius, randf_range(-4, 4)))
		crack_pts.append(Vector2(-radius * 0.4, randf_range(-8, 8)))
		crack_pts.append(Vector2(0, 0))
		crack_pts.append(Vector2(radius * 0.4, randf_range(-8, 8)))
		crack_pts.append(Vector2(radius, randf_range(-4, 4)))

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.28)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius * 0.4, Color(rift_color.r, rift_color.g, rift_color.b, 0.25))
		if crack_pts.size() >= 2:
			draw_polyline(crack_pts, rift_color, 2.5)
			draw_polyline(crack_pts, Color.WHITE, 1.0)

# 9. AoE Indicator Effect
class AoEIndicatorEffect extends Node2D:
	var radius: float
	var aoe_color: Color
	var duration: float

	func _init(r: float, col: Color, dur: float) -> void:
		radius = r
		aoe_color = col
		duration = dur

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(aoe_color.r, aoe_color.g, aoe_color.b, 0.12))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 36, aoe_color, 1.8)

# 10. Target Highlight Effect (Silhouette Pulse)
class TargetHighlightEffect extends Node2D:
	var radius: float
	var hl_color: Color

	func _init(r: float, col: Color) -> void:
		radius = r
		hl_color = col

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, hl_color, 2.2)

# 11. Hazard Telegraph Effect (Dangerous Enemy Attack Warning)
class HazardTelegraphEffect extends Node2D:
	var dir: Vector2
	var length: float
	var width: float
	var duration: float

	func _init(p_dir: Vector2, p_len: float, p_width: float, dur: float) -> void:
		dir = p_dir.normalized()
		length = p_len
		width = p_width
		duration = dur

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.25, duration * 0.75)
		tween.tween_property(self, "modulate:a", 1.0, duration * 0.25)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		var p_end = dir * length
		var perp = Vector2(-dir.y, dir.x) * (width * 0.5)
		var pts = PackedVector2Array([
			-perp,
			perp,
			p_end + perp,
			p_end - perp
		])
		draw_colored_polygon(pts, Color(0.9, 0.1, 0.2, 0.2))
		draw_polyline(PackedVector2Array([-perp, p_end - perp, p_end + perp, perp, -perp]), Color(1.0, 0.2, 0.3, 0.85), 1.6)

# 12. Reward Pickup Effect
class RewardPickupEffect extends Node2D:
	var star_color: Color
	var cur_scale: float = 0.5

	func _init(col: Color) -> void:
		star_color = col

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 24.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "cur_scale", 1.4, 0.35)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s = 8.0 * cur_scale
		# 4-point star
		var pts = PackedVector2Array([
			Vector2(0, -s), Vector2(s * 0.25, -s * 0.25),
			Vector2(s, 0), Vector2(s * 0.25, s * 0.25),
			Vector2(0, s), Vector2(-s * 0.25, s * 0.25),
			Vector2(-s, 0), Vector2(-s * 0.25, -s * 0.25)
		])
		draw_colored_polygon(pts, star_color)
		draw_circle(Vector2.ZERO, s * 0.4, Color.WHITE)

# Floating Text Effect
class FloatingTextEffect extends Node2D:
	var label: Label

	func _init(text: String, col: Color) -> void:
		label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", col)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-50, -10)
		label.custom_minimum_size = Vector2(100, 20)
		add_child(label)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 28.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
		tween.tween_callback(queue_free)

# Floating Damage Number
class DamageNumberEffect extends Node2D:
	var label: Label

	func _init(dmg_value: int, col: Color) -> void:
		label = Label.new()
		label.text = str(dmg_value)
		label.add_theme_color_override("font_color", col)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-20, -10)
		label.custom_minimum_size = Vector2(40, 18)
		add_child(label)

	func _ready() -> void:
		var target_y = position.y - randf_range(16.0, 24.0)
		var tween = create_tween()
		tween.tween_property(self, "position:y", target_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)

# Impact Sparks
class ImpactSparksEffect extends Node2D:
	var spark_color: Color
	var spark_count: int
	var spark_offsets: Array[Vector2] = []
	var spark_vels: Array[Vector2] = []

	func _init(col: Color, count: int) -> void:
		spark_color = col
		spark_count = count
		for i in range(count):
			spark_offsets.append(Vector2.ZERO)
			var angle = randf() * TAU
			var spd = randf_range(50.0, 140.0)
			spark_vels.append(Vector2(cos(angle), sin(angle)) * spd)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		for i in range(spark_count):
			spark_offsets[i] += spark_vels[i] * delta
			spark_vels[i] *= 0.88
		queue_redraw()

	func _draw() -> void:
		for i in range(spark_count):
			draw_circle(spark_offsets[i], 1.6, spark_color)

# Death Burst
class DeathBurstEffect extends Node2D:
	var radius: float = 4.0

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "radius", 24.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.4, 0.08, 0.18, 0.35))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color(0.7, 0.15, 0.25, 0.75), 1.8)
