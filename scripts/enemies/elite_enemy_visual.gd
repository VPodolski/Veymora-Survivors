extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0
var active_statuses: Array = []
var hp_ratio: float = 1.0
var aura_pulse: float = 0.0

func _process(delta: float) -> void:
	aura_pulse += delta * 3.5
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE
	queue_redraw()

func trigger_hit_flash(duration: float = 0.12) -> void:
	is_flashing = true
	flash_timer = duration
	modulate = Color(2.8, 2.5, 1.5, 1.0)
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, global_position, 28.0, 48.0, Color(1.0, 0.85, 0.3, 0.6), 0.15, 2.0)

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func set_statuses(statuses: Array) -> void:
	active_statuses = statuses

func update_health_display(current_hp: float, max_hp: float) -> void:
	hp_ratio = clamp(current_hp / max(1.0, max_hp), 0.0, 1.0)

func _draw() -> void:
	var pulse = 1.0 + sin(aura_pulse) * 0.08

	# Golden Elite Ring & Outer Glow
	draw_circle(Vector2.ZERO, 38.0 * pulse, Color(0.8, 0.6, 0.1, 0.22))
	draw_arc(Vector2.ZERO, 36.0 * pulse, 0, TAU, 32, Color(1.0, 0.85, 0.25, 0.85), 3.0)

	# Heavy armored body
	draw_circle(Vector2.ZERO, 28.0, Color(0.14, 0.10, 0.12, 1.0))
	draw_circle(Vector2.ZERO, 22.0, Color(0.25, 0.18, 0.20, 1.0))

	# Metallic plates and gilded crest
	draw_arc(Vector2.ZERO, 25.0, -PI * 0.75, PI * 0.75, 20, Color(0.85, 0.70, 0.25, 1.0), 4.0)

	# Massive spiked pauldrons (4 prominent horn spikes)
	draw_line(Vector2(-18, -16), Vector2(-34, -30), Color(0.95, 0.80, 0.30, 1.0), 5.5)
	draw_line(Vector2(18, -16), Vector2(34, -30), Color(0.95, 0.80, 0.30, 1.0), 5.5)
	draw_line(Vector2(-20, 10), Vector2(-32, 18), Color(0.75, 0.60, 0.20, 1.0), 4.5)
	draw_line(Vector2(20, 10), Vector2(32, 18), Color(0.75, 0.60, 0.20, 1.0), 4.5)

	# Glowing Ruby Core / Eye
	var eye_center = Vector2.ZERO + facing_direction * 9.0
	draw_circle(eye_center, 9.0, Color(1.0, 0.15, 0.25, 1.0))
	draw_circle(eye_center, 4.5, Color(1.0, 0.8, 0.3, 1.0))
	draw_circle(eye_center, 2.0, Color.WHITE)

	# Enlarged Elite HP bar (width 54, height 5)
	var bar_w = 54.0
	var bar_h = 5.0
	var bar_pos = Vector2(-bar_w * 0.5, -42.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.12, 0.9), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), Color(1.0, 0.25, 0.3, 1.0), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(1.0, 0.85, 0.3, 0.9), false, 1.2)

	# Status icons / dots (y=-52, elevated above health bar)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 6.0
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 12.0, -52.0)
			draw_circle(dot_pos, 3.2, col)
			draw_circle(dot_pos, 1.5, Color.WHITE)

