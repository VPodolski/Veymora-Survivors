class_name GoldCoin
extends Area2D

const RunStats = preload("res://scripts/game/run_stats.gd")

@export var gold_value: int = 1
@export var pickup_distance: float = 12.0
@export var magnet_radius: float = 120.0
@export var base_fly_speed: float = 190.0

var target_player: Node2D = null
var current_speed: float = 0.0
var is_collected: bool = false
var pulse_time: float = 0.0

static var _cached_player_ref: Node2D = null

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("gold_coins")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU
	queue_redraw()

func _process(delta: float) -> void:
	if is_collected:
		return

	pulse_time += delta * 5.0
	rotation += 1.8 * delta
	var pulse = 1.0 + sin(pulse_time) * 0.10
	scale = Vector2(pulse, pulse)

	if not is_instance_valid(target_player):
		find_player()
		return

	var dist = global_position.distance_to(target_player.global_position)
	if dist <= magnet_radius:
		current_speed += 500.0 * delta
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * (base_fly_speed + current_speed) * delta
		rotation += 8.0 * delta

		if dist <= pickup_distance:
			collect()

func find_player() -> void:
	if is_instance_valid(_cached_player_ref):
		target_player = _cached_player_ref
		return
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.size() > 0:
		_cached_player_ref = players[0] as Node2D
		target_player = _cached_player_ref

func _on_body_entered(body: Node2D) -> void:
	if not is_collected and body.is_in_group("player"):
		collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true

	# Batch optimization: record in active run stats without disk I/O
	if RunStats.active_stats:
		RunStats.active_stats.record_gold(gold_value)

	var tree = get_tree() if is_inside_tree() else null
	var container = (tree.current_scene if tree and tree.current_scene else (tree.root if tree else null))
	if CombatEffects and container:
		CombatEffects.spawn_impact_sparks(container, global_position, Color(1.0, 0.85, 0.2, 0.95), 3)

	if tree:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.10)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _draw() -> void:
	var r = 3.5
	var halo_col = Color(1.0, 0.85, 0.2, 0.22)
	var rim_col = Color(0.85, 0.65, 0.1, 1.0)
	var body_col = Color(1.0, 0.85, 0.2, 1.0)
	var shine_col = Color(1.0, 1.0, 0.85, 0.9)

	# 1. Subtle golden glow halo
	draw_circle(Vector2.ZERO, r * 1.5, halo_col)

	# 2. Outer gold coin body & rim
	draw_circle(Vector2.ZERO, r, rim_col)
	draw_circle(Vector2.ZERO, r * 0.80, body_col)

	# 3. Inner engraved emblem
	var pts = PackedVector2Array([
		Vector2(0, -r * 0.45),
		Vector2(r * 0.45, 0),
		Vector2(0, r * 0.45),
		Vector2(-r * 0.45, 0)
	])
	draw_colored_polygon(pts, shine_col)
