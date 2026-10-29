class_name XPGem
extends Area2D

@export var xp_value: int = 10
@export var pickup_distance: float = 16.0
@export var magnet_radius: float = 120.0
@export var base_fly_speed: float = 180.0

var target_player: Node2D = null
var current_speed: float = 0.0
var is_collected: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU
	call_deferred("check_gem_condensation")

func check_gem_condensation() -> void:
	var pickups = get_tree().get_nodes_in_group("pickups")
	# If floor has more than 65 active gems, merge with a nearby gem
	if pickups.size() > 65:
		for node in pickups:
			if node != self and is_instance_valid(node) and not node.is_collected:
				var other = node as XPGem
				if other and global_position.distance_squared_to(other.global_position) < 14400.0: # within 120px
					other.xp_value += xp_value
					other.scale = Vector2(1.3, 1.3) # Slightly larger visual
					queue_free()
					return

func _process(delta: float) -> void:
	if is_collected:
		return

	pulse_time += delta * 4.0
	queue_redraw()

	if not is_instance_valid(target_player):
		find_player()
		return

	var dist = global_position.distance_to(target_player.global_position)

	# If within magnet radius, fly towards player
	if dist <= magnet_radius:
		current_speed += 420.0 * delta
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * (base_fly_speed + current_speed) * delta

		if dist <= pickup_distance:
			collect()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as Node2D

func _on_body_entered(body: Node2D) -> void:
	if not is_collected and body.is_in_group("player"):
		collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true

	# Notify ExperienceManager
	var exp_managers = get_tree().get_nodes_in_group("experience_manager")
	if exp_managers.size() > 0:
		exp_managers[0].add_experience(xp_value)

	# Small collection shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var is_greater = xp_value > 15
	var scale_factor = (1.2 if is_greater else 1.0) + sin(pulse_time) * 0.15
	var r = 6.0 * scale_factor

	# Outer glowing halo
	var halo_col = Color(0.9, 0.7, 0.1, 0.3) if is_greater else Color(0.1, 0.7, 1.0, 0.2)
	draw_circle(Vector2.ZERO, r * 1.8, halo_col)

	# Arcane diamond points
	var points = PackedVector2Array([
		Vector2(0, -r * 1.4),
		Vector2(r, 0),
		Vector2(0, r * 1.4),
		Vector2(-r, 0)
	])
	var body_col = Color(1.0, 0.85, 0.2, 0.95) if is_greater else Color(0.2, 0.85, 1.0, 0.95)
	draw_colored_polygon(points, body_col)

	# Inner crystal highlight
	var inner_points = PackedVector2Array([
		Vector2(0, -r * 0.7),
		Vector2(r * 0.5, 0),
		Vector2(0, r * 0.7),
		Vector2(-r * 0.5, 0)
	])
	draw_colored_polygon(inner_points, Color.WHITE)
