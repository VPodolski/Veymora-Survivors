class_name CombatEffects
extends RefCounted

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

