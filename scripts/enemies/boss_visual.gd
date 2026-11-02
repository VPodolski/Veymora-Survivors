extends Node2D

var facing_direction: Vector2 = Vector2.LEFT
var is_flashing: bool = false
var flash_timer: float = 0.0
var active_statuses: Array = []
var hp_ratio: float = 1.0
var aura_pulse: float = 0.0
var current_phase: int = 1

func _process(delta: float) -> void:
	var pulse_speed = 5.5 if current_phase == 3 else (4.2 if current_phase == 2 else 3.2)
	aura_pulse += delta * pulse_speed
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE
	queue_redraw()

func set_phase(phase: int) -> void:
	current_phase = phase

func trigger_hit_flash(duration: float = 0.12) -> void:
	is_flashing = true
	flash_timer = duration
	modulate = Color(2.8, 2.5, 2.5, 1.0)
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, global_position, 55.0, 75.0, Color(0.9, 0.2, 0.5, 0.6), 0.15, 2.5)

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func set_statuses(statuses: Array) -> void:
	active_statuses = statuses

func update_health_display(current_hp: float, max_hp: float) -> void:
	hp_ratio = clamp(current_hp / max(1.0, max_hp), 0.0, 1.0)

func _draw() -> void:
	var pulse_amp = 0.14 if current_phase == 3 else 0.08
	var pulse_scale = 1.0 + sin(aura_pulse) * pulse_amp

	# Color palette based on phase
	var aura_col = Color(0.28, 0.04, 0.38, 0.45)
	var ring_col = Color(0.80, 0.22, 0.95, 0.75)
	var shard_col = Color(0.85, 0.30, 1.0, 0.95)
	var eye_col = Color(0.90, 0.10, 0.30, 1.0)

	if current_phase == 2: # Rift Phase
		aura_col = Color(0.12, 0.08, 0.45, 0.55)
		ring_col = Color(0.40, 0.65, 1.0, 0.85)
		shard_col = Color(0.50, 0.80, 1.0, 0.95)
		eye_col = Color(0.30, 0.85, 1.0, 1.0)
	elif current_phase == 3: # Enrage Phase
		aura_col = Color(0.55, 0.05, 0.15, 0.65)
		ring_col = Color(1.0, 0.15, 0.25, 0.95)
		shard_col = Color(1.0, 0.30, 0.20, 1.0)
		eye_col = Color(1.0, 0.05, 0.15, 1.0)

	# 1. Ground Shadow (Dark Void Pool underneath)
	var shadow_pts = PackedVector2Array([
		Vector2(-68, 42), Vector2(0, 52), Vector2(68, 42), Vector2(0, 32)
	])
	draw_colored_polygon(shadow_pts, Color(0.05, 0.02, 0.08, 0.55))

	# 2. Outer Dark Rift Aura
	draw_circle(Vector2.ZERO, 65.0 * pulse_scale, aura_col)
	draw_arc(Vector2.ZERO, 58.0 * pulse_scale, 0, TAU, 40, ring_col, 3.5)

	# 3. Massive Monolithic Core
	draw_circle(Vector2.ZERO, 46.0, Color(0.10, 0.07, 0.14, 1.0))
	draw_circle(Vector2.ZERO, 34.0, Color(0.18, 0.12, 0.26, 1.0))

	# 4. Floating Runic Shards around Boss
	var shard_count = 8 if current_phase == 3 else (6 if current_phase == 2 else 4)
	for i in range(shard_count):
		var ang = aura_pulse + float(i) * (TAU / float(shard_count))
		var shard_dist = 62.0 * pulse_scale
		var shard_pos = Vector2(cos(ang), sin(ang)) * shard_dist
		draw_circle(shard_pos, 6.0, shard_col)
		draw_circle(shard_pos, 2.5, Color.WHITE)

	# 5. Fiery Eye of the Rift
	var eye_center = Vector2.ZERO + facing_direction * 14.0
	draw_circle(eye_center, 15.0, eye_col)
	draw_circle(eye_center, 7.5, Color(1.0, 0.85, 0.3, 1.0))
	draw_circle(eye_center, 3.5, Color.WHITE)

	# 6. Status icons / dots (y=-74 above boss aura)
	if not active_statuses.is_empty():
		var status_offset_x = -float(active_statuses.size() - 1) * 8.0
		for i in range(active_statuses.size()):
			var s_name = active_statuses[i]
			var col = StatusEffects.get_status_color(s_name)
			var dot_pos = Vector2(status_offset_x + float(i) * 16.0, -74.0)
			draw_circle(dot_pos, 4.0, col)
			draw_circle(dot_pos, 1.8, Color.WHITE)

