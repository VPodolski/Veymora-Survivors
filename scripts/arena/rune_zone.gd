class_name RuneZone
extends Area2D

@export var radius: float = 130.0
@export var duration: float = 18.0

var elapsed: float = 0.0
var is_player_inside: bool = false
var player_ref: PlayerController = null
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("rune_zones")
	collision_layer = 0
	collision_mask = 1 # Player layer

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Spawn activation ring
	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_ring(container, global_position, 10.0, radius, Color(0.3, 0.8, 1.0, 0.9), 0.4, 3.0)
	CombatEffects.spawn_text_popup(container, global_position, "ЧАРОДЕЙСКИЙ ИСТОЧНИК!", Color(0.4, 0.85, 1.0, 1.0), true)

func _process(delta: float) -> void:
	elapsed += delta
	pulse_time += delta * 2.8

	if is_player_inside and is_instance_valid(player_ref) and player_ref.is_alive:
		# Apply temporary hotspot boost
		player_ref.set_meta("in_rune_zone", true)

	if elapsed >= duration:
		_expire()
		return

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController and body.is_alive:
		is_player_inside = true
		player_ref = body
		player_ref.set_meta("in_rune_zone", true)
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		CombatEffects.spawn_hit_flash(container, player_ref.global_position, Color(0.4, 0.9, 1.0), 18.0)

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		is_player_inside = false
		if is_instance_valid(player_ref):
			player_ref.set_meta("in_rune_zone", false)
		player_ref = null

func _expire() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(player_ref):
		player_ref.set_meta("in_rune_zone", false)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, radius, Color(0.3, 0.7, 1.0, 0.6), 0.3)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var remaining_ratio = clamp(1.0 - (elapsed / duration), 0.0, 1.0)
	var pulse = 1.0 + sin(pulse_time) * 0.08

	# Soft area floor fill
	draw_circle(Vector2.ZERO, radius * pulse, Color(0.2, 0.6, 1.0, 0.09 if not is_player_inside else 0.16))

	# Outer perimeter ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.3, 0.75, 1.0, 0.55), 2.0)

	# Inner rotating rune circles
	var inner_r = radius * 0.65
	draw_arc(Vector2.ZERO, inner_r, 0, TAU, 32, Color(0.4, 0.85, 1.0, 0.35), 1.4)

	# 4 Cardinal rune notches
	for i in range(4):
		var ang = pulse_time * 0.3 + float(i) * (TAU / 4.0)
		var notch_pos = Vector2(cos(ang), sin(ang)) * inner_r
		draw_circle(notch_pos, 3.0, Color(0.7, 0.9, 1.0, 0.8))

	# Duration countdown ring along perimeter
	var end_angle = -PI * 0.5 + TAU * remaining_ratio
	draw_arc(Vector2.ZERO, radius + 3.0, -PI * 0.5, end_angle, 48, Color(1.0, 0.85, 0.3, 0.85), 2.5)
