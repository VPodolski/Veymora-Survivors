class_name FrostHazardZone
extends Area2D

signal activated
signal expired

const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")

var warning_duration: float = 1.5
var active_duration: float = 7.0
var radius: float = 90.0

var is_active: bool = false
var lifetime: float = 0.0
var anim_time: float = 0.0

var collision_shape: CollisionShape2D

func _ready() -> void:
	add_to_group("frost_hazard_zones")
	collision_layer = 0
	collision_mask = 3 # Player (1) and Enemies (2)

	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	# Collision disabled during warning telegraph
	collision_shape.disabled = true
	add_child(collision_shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Telegraph warning popup
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_text_popup(container, global_position, "ОЧАГ ХОЛОДА!", Color(0.4, 0.85, 1.0, 0.9), false)

func _process(delta: float) -> void:
	lifetime += delta
	anim_time += delta

	if not is_active:
		if lifetime >= warning_duration:
			_activate_zone()
	else:
		# Periodic status refresh for overlapping enemies
		_apply_frost_to_overlapping()
		if lifetime >= (warning_duration + active_duration):
			_expire_zone()

	queue_redraw()

func _activate_zone() -> void:
	is_active = true
	if collision_shape:
		collision_shape.disabled = false
	activated.emit()

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, radius * 1.1, Color(0.3, 0.8, 1.0, 0.8), 0.28)
	CombatEffects.spawn_geometric_shards(container, global_position, Color(0.4, 0.9, 1.0, 1.0), 6, 120.0)

	# Immediately check bodies already inside when activating
	for body in get_overlapping_bodies():
		_handle_enter(body)

func _apply_frost_to_overlapping() -> void:
	for body in get_overlapping_bodies():
		if body is EnemyController and not body.is_dead:
			body.apply_status(StatusEffects.STATUS_SLOWED, 1.2)

func _handle_enter(body: Node2D) -> void:
	if not is_active:
		return
	if body is PlayerController and body.has_method("enter_frost_zone"):
		body.enter_frost_zone()
	elif body is EnemyController and not body.is_dead:
		body.apply_status(StatusEffects.STATUS_SLOWED, 2.5)

func _handle_exit(body: Node2D) -> void:
	if body is PlayerController and body.has_method("exit_frost_zone"):
		body.exit_frost_zone()

func _on_body_entered(body: Node2D) -> void:
	_handle_enter(body)

func _on_body_exited(body: Node2D) -> void:
	_handle_exit(body)

func _expire_zone() -> void:
	# Release any bodies inside before removal
	for body in get_overlapping_bodies():
		_handle_exit(body)
	expired.emit()

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if not is_active:
		# 1. Telegraph Warning Mode: pulsating dashed ring
		var warn_progress = clampf(lifetime / warning_duration, 0.0, 1.0)
		var warn_color = Color(0.35, 0.8, 1.0, 0.25 + 0.45 * sin(anim_time * 8.0))
		draw_arc(Vector2.ZERO, radius * warn_progress, 0, TAU, 32, warn_color, 2.0)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(0.4, 0.85, 1.0, 0.3), 1.5)
		# Warning runes
		for i in range(4):
			var ang = anim_time * 1.5 + float(i) * (TAU / 4.0)
			var p = Vector2(cos(ang), sin(ang)) * radius
			draw_circle(p, 3.0, Color(0.4, 0.85, 1.0, 0.7))
	else:
		# 2. Active Freezing Field
		var pulse_a = 0.16 + 0.08 * sin(anim_time * 3.5)
		# Frosted ground circle
		draw_circle(Vector2.ZERO, radius, Color(0.2, 0.65, 0.95, pulse_a))
		# Outer crystalline boundary ring
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.4, 0.88, 1.0, 0.85), 2.2)
		draw_arc(Vector2.ZERO, radius * 0.5, 0, TAU, 32, Color(0.5, 0.9, 1.0, 0.4), 1.5)

		# Crystalline hex spokes
		for i in range(6):
			var ang = float(i) * (TAU / 6.0)
			var p1 = Vector2(cos(ang), sin(ang)) * (radius * 0.3)
			var p2 = Vector2(cos(ang), sin(ang)) * (radius * 0.9)
			draw_line(p1, p2, Color(0.6, 0.95, 1.0, 0.6), 1.5)

