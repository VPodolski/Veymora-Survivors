class_name XPGem
extends Area2D

enum GemTier { COMMON = 1, ENHANCED = 2, GREATER = 3, RARE = 4 }

@export var xp_value: int = 10
@export var pickup_distance: float = 12.0
@export var magnet_radius: float = 120.0
@export var base_fly_speed: float = 180.0

var target_player: Node2D = null
var current_speed: float = 0.0
var is_collected: bool = false
var pulse_time: float = 0.0

# Backwards compatibility flags
var is_merging: bool = false
var merge_center: Vector2 = Vector2.ZERO

static var _cached_player_ref: Node2D = null

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("xp_gems")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU
	queue_redraw()

func get_tier() -> int:
	if xp_value >= 200:
		return GemTier.RARE
	elif xp_value >= 50:
		return GemTier.GREATER
	elif xp_value >= 10:
		return GemTier.ENHANCED
	else:
		return GemTier.COMMON

func get_tier_color() -> Color:
	match get_tier():
		GemTier.RARE:
			return Color(0.85, 0.35, 1.0, 1.0) # Amethyst Royal Violet
		GemTier.GREATER:
			return Color(1.0, 0.82, 0.18, 1.0) # Amber Gold
		GemTier.ENHANCED:
			return Color(0.20, 0.95, 0.45, 1.0) # Emerald Jade
		_:
			return Color(0.25, 0.72, 1.0, 1.0) # Sapphire Azure

func get_tier_halo_color() -> Color:
	match get_tier():
		GemTier.RARE:
			return Color(0.85, 0.35, 1.0, 0.32)
		GemTier.GREATER:
			return Color(1.0, 0.82, 0.18, 0.28)
		GemTier.ENHANCED:
			return Color(0.20, 0.95, 0.45, 0.22)
		_:
			return Color(0.25, 0.72, 1.0, 0.20)

# Backward compatibility stubs (merging has been replaced by independent gems)
static func condense_gems(_tree: SceneTree, _max_threshold: int = 0) -> void:
	pass

func check_gem_condensation() -> void:
	pass

func _process(delta: float) -> void:
	if is_collected:
		return

	pulse_time += delta * 4.0
	rotation += 1.2 * delta
	var pulse = 1.0 + sin(pulse_time) * 0.10
	scale = Vector2(pulse, pulse)

	if not is_instance_valid(target_player):
		find_player()
		return

	var dist = global_position.distance_to(target_player.global_position)
	if dist <= magnet_radius:
		current_speed += 480.0 * delta
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * (base_fly_speed + current_speed) * delta
		rotation += 6.0 * delta

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

	# Notify ExperienceManager
	var exp_managers = get_tree().get_nodes_in_group("experience_manager") if get_tree() else []
	if exp_managers.size() > 0:
		exp_managers[0].add_experience(xp_value)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.10)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var tier = get_tier()
	# Compact micro-scale radius: 3.5 px
	var tier_scale = clamp(1.0 + float(tier - 1) * 0.08, 1.0, 1.25)
	var r = 3.5 * tier_scale

	var halo_col = get_tier_halo_color()
	var body_col = get_tier_color()

	# 1. Subtle glowing halo
	draw_circle(Vector2.ZERO, r * 1.5, halo_col)

	# 2. Sapphire diamond polygon
	var points = PackedVector2Array([
		Vector2(0, -r * 1.35),
		Vector2(r, 0),
		Vector2(0, r * 1.35),
		Vector2(-r, 0)
	])
	draw_colored_polygon(points, body_col)

	# 3. Inner crystal glint
	var inner_pts = PackedVector2Array([
		Vector2(0, -r * 0.55),
		Vector2(r * 0.4, 0),
		Vector2(0, r * 0.55),
		Vector2(-r * 0.4, 0)
	])
	draw_colored_polygon(inner_pts, Color(1.0, 1.0, 1.0, 0.85))
