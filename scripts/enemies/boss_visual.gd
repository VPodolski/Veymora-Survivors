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
	modulate = Color(2.5, 2.5, 2.5, 1.0)

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func set_statuses(statuses: Array) -> void:
	active_statuses = statuses

func update_health_display(current_hp: float, max_hp: float) -> void:
	hp_ratio = clamp(current_hp / max(1.0, max_hp), 0.0, 1.0)

func _draw() -> void:
	var pulse_scale = 1.0 + sin(aura_pulse) * 0.1

	# Outer Dark Rift Aura
	draw_circle(Vector2.ZERO, 38.0 * pulse_scale, Color(0.3, 0.05, 0.4, 0.35))
	draw_arc(Vector2.ZERO, 34.0, 0, TAU, 32, Color(0.8, 0.2, 0.9, 0.6), 3.0)

	# Massive Monolithic Core
	draw_circle(Vector2.ZERO, 28.0, Color(0.1, 0.08, 0.14, 1.0))
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.12, 0.25, 1.0))

	# Floating Runic Shards around Boss
	for i in range(4):
		var ang = aura_pulse + float(i) * (TAU / 4.0)
		var shard_pos = Vector2(cos(ang), sin(ang)) * 36.0
		draw_circle(shard_pos, 4.0, Color(0.85, 0.3, 1.0, 0.9))

	# Fiery Eye of the Rift
	var eye_center = Vector2.ZERO + facing_direction * 8.0
	draw_circle(eye_center, 9.0, Color(0.9, 0.1, 0.3, 1.0))
	draw_circle(eye_center, 4.5, Color(1.0, 0.85, 0.3, 1.0))
	draw_circle(eye_center, 2.0, Color.WHITE)

	# Status icons / dots (y=-44 above boss aura)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 6.0
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 12.0, -44.0)
			draw_circle(dot_pos, 3.5, col)
			draw_circle(dot_pos, 1.5, Color.WHITE)

