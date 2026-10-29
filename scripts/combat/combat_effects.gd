class_name CombatEffects
extends RefCounted

static var active_damage_numbers: int = 0
const MAX_DAMAGE_NUMBERS = 24

static func spawn_shockwave(parent: Node, pos: Vector2, max_radius: float = 85.0, col: Color = Color(0.4, 0.7, 1.0, 0.9)) -> void:
	if not parent:
		return
	var wave = ShockwaveEffect.new(max_radius, col)
	wave.global_position = pos
	parent.add_child(wave)

static func spawn_lightning_arc(parent: Node, from_pos: Vector2, to_pos: Vector2, col: Color = Color(0.5, 0.85, 1.0, 1.0)) -> void:
	if not parent:
		return
	var arc = LightningArcEffect.new(from_pos, to_pos, col)
	parent.add_child(arc)

static func spawn_text_popup(parent: Node, pos: Vector2, text: String, col: Color) -> void:
	if not parent:
		return
	var popup = FloatingTextEffect.new(text, col)
	popup.global_position = pos
	parent.add_child(popup)

static func spawn_damage_number(parent: Node, pos: Vector2, amount: float, col: Color = Color(1.0, 0.92, 0.5, 1.0)) -> void:
	if not parent:
		return
	if active_damage_numbers >= MAX_DAMAGE_NUMBERS and amount < 20.0:
		return # Throttle low damage spam during dense combat
	active_damage_numbers += 1
	var dmg_num = DamageNumberEffect.new(int(round(amount)), col)
	dmg_num.tree_exited.connect(func(): active_damage_numbers = max(0, active_damage_numbers - 1))
	dmg_num.global_position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-14.0, -6.0))
	parent.add_child(dmg_num)

static func spawn_impact_sparks(parent: Node, pos: Vector2, col: Color = Color(0.4, 0.9, 1.0, 1.0), count: int = 4) -> void:
	if not parent:
		return
	var sparks = ImpactSparksEffect.new(col, count)
	sparks.global_position = pos
	parent.add_child(sparks)

static func spawn_death_burst(parent: Node, pos: Vector2) -> void:
	if not parent:
		return
	var burst = DeathBurstEffect.new()
	burst.global_position = pos
	parent.add_child(burst)

# 1. Shockwave circle effect
class ShockwaveEffect extends Node2D:
	var target_radius: float
	var current_radius: float = 4.0
	var wave_color: Color

	func _init(p_radius: float, p_color: Color) -> void:
		target_radius = p_radius
		wave_color = p_color

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "current_radius", target_radius, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, wave_color, 3.0)
		draw_circle(Vector2.ZERO, current_radius * 0.6, Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * 0.15))

# 2. Lightning arc line effect
class LightningArcEffect extends Node2D:
	var start_pos: Vector2
	var end_pos: Vector2
	var arc_color: Color
	var segments: PackedVector2Array = []

	func _init(p_start: Vector2, p_end: Vector2, p_color: Color) -> void:
		start_pos = p_start
		end_pos = p_end
		arc_color = p_color
		generate_jagged_line()

	func generate_jagged_line() -> void:
		segments.append(start_pos)
		var diff = end_pos - start_pos
		var count = 4
		for i in range(1, count):
			var t = float(i) / float(count)
			var base = start_pos + diff * t
			var perp = Vector2(-diff.y, diff.x).normalized() * randf_range(-14.0, 14.0)
			segments.append(base + perp)
		segments.append(end_pos)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.18)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		if segments.size() >= 2:
			draw_polyline(segments, arc_color, 2.5)
			draw_polyline(segments, Color.WHITE, 1.0)

# 3. Floating reaction text popup
class FloatingTextEffect extends Node2D:
	var label: Label

	func _init(text: String, col: Color) -> void:
		label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", col)
		label.add_theme_font_size_override("font_size", 13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-50, -10)
		label.custom_minimum_size = Vector2(100, 20)
		add_child(label)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 28.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)

# 4. Floating damage number
class DamageNumberEffect extends Node2D:
	var label: Label

	func _init(dmg_value: int, col: Color) -> void:
		label = Label.new()
		label.text = str(dmg_value)
		label.add_theme_color_override("font_color", col)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-20, -10)
		label.custom_minimum_size = Vector2(40, 18)
		add_child(label)

	func _ready() -> void:
		var target_y = position.y - randf_range(18.0, 26.0)
		var tween = create_tween()
		tween.tween_property(self, "position:y", target_y, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.38)
		tween.tween_callback(queue_free)

# 5. Impact Sparks
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
			var spd = randf_range(60.0, 160.0)
			spark_vels.append(Vector2(cos(angle), sin(angle)) * spd)

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.22)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		for i in range(spark_count):
			spark_offsets[i] += spark_vels[i] * delta
			spark_vels[i] *= 0.9
		queue_redraw()

	func _draw() -> void:
		for i in range(spark_count):
			draw_circle(spark_offsets[i], 1.8, spark_color)

# 6. Death Burst
class DeathBurstEffect extends Node2D:
	var radius: float = 4.0

	func _ready() -> void:
		var tween = create_tween()
		tween.tween_property(self, "radius", 26.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.4, 0.08, 0.18, 0.4))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color(0.7, 0.15, 0.25, 0.8), 2.0)
