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
var is_merging: bool = false
var merge_center: Vector2 = Vector2.ZERO
var merge_lines: Array[Vector2] = []
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU

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
			return Color(0.25, 0.75, 1.0, 1.0) # Sapphire Azure

func get_tier_halo_color() -> Color:
	match get_tier():
		GemTier.RARE:
			return Color(0.85, 0.35, 1.0, 0.35)
		GemTier.GREATER:
			return Color(1.0, 0.82, 0.18, 0.30)
		GemTier.ENHANCED:
			return Color(0.20, 0.95, 0.45, 0.25)
		_:
			return Color(0.25, 0.75, 1.0, 0.20)

static func condense_gems(tree: SceneTree, _max_threshold: int = 0) -> void:
	if not tree:
		return

	var raw_pickups = tree.get_nodes_in_group("pickups")
	var gems: Array[XPGem] = []
	for p in raw_pickups:
		var g = p as XPGem
		if is_instance_valid(g) and not g.is_collected and not g.is_merging:
			gems.append(g)

	if gems.size() < 2:
		return

	# Fast spatial bucketing with 120px grid
	const CELL_SIZE = 120.0
	const MERGE_RADIUS_SQ = 14400.0 # 120px squared
	var grid: Dictionary = {}

	for g in gems:
		var cx = int(floor(g.global_position.x / CELL_SIZE))
		var cy = int(floor(g.global_position.y / CELL_SIZE))
		var key = "%d_%d" % [cx, cy]
		if not grid.has(key):
			grid[key] = []
		grid[key].append(g)

	var processed: Dictionary = {}

	for key in grid.keys():
		var cell_gems = grid[key]
		for gem_a in cell_gems:
			if processed.has(gem_a.get_instance_id()) or gem_a.is_collected or gem_a.is_merging:
				continue

			var cluster: Array[XPGem] = [gem_a]
			var cx = int(floor(gem_a.global_position.x / CELL_SIZE))
			var cy = int(floor(gem_a.global_position.y / CELL_SIZE))

			# Check neighboring 3x3 cells
			for nx in range(cx - 1, cx + 2):
				for ny in range(cy - 1, cy + 2):
					var nkey = "%d_%d" % [nx, ny]
					if grid.has(nkey):
						for gem_b in grid[nkey]:
							if gem_b == gem_a or processed.has(gem_b.get_instance_id()):
								continue
							if not is_instance_valid(gem_b) or gem_b.is_collected or gem_b.is_merging:
								continue
							if gem_a.global_position.distance_squared_to(gem_b.global_position) <= MERGE_RADIUS_SQ:
								cluster.append(gem_b)

			if cluster.size() >= 2:
				for g in cluster:
					processed[g.get_instance_id()] = true
				_execute_merge_cluster(tree, cluster)

static func _execute_merge_cluster(tree: SceneTree, cluster: Array[XPGem]) -> void:
	if cluster.is_empty():
		return

	# Calculate cluster centroid
	var center = Vector2.ZERO
	var total_xp = 0
	for g in cluster:
		center += g.global_position
		total_xp += g.xp_value
	center /= float(cluster.size())

	var container = tree.current_scene if tree.current_scene else tree.root

	# Atomic lock: source gems are locked against magnet and collection
	for g in cluster:
		g.is_merging = true
		g.set_deferred("monitoring", false)
		g.set_deferred("monitorable", false)
		g.merge_center = center
		g.merge_lines = [center]

		# Animate smooth movement toward cluster center
		var tween = g.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(g, "global_position", center, 0.32)
		tween.parallel().tween_property(g, "modulate:a", 0.4, 0.32)

	# After animation finishes, spawn merged gem at centroid
	var timer = tree.create_timer(0.32)
	timer.timeout.connect(func():
		if not is_instance_valid(container):
			return

		# Clean up old source gems
		for g in cluster:
			if is_instance_valid(g):
				g.queue_free()

		# Instantiate new consolidated gem
		var new_gem = preload("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
		new_gem.xp_value = total_xp
		new_gem.global_position = center
		container.add_child(new_gem)

		# Visual impulse and flash
		var col = new_gem.get_tier_color()
		CombatEffects.spawn_shockwave(container, center, 32.0, col, 0.22)
		CombatEffects.spawn_ring(container, center, 8.0, 30.0, Color(col.r, col.g, col.b, 0.8), 0.18, 2.0)
	)

func check_gem_condensation() -> void:
	# Retained for backwards compatibility with existing unit tests
	var pickups = get_tree().get_nodes_in_group("pickups") if get_tree() else []
	var cluster: Array[XPGem] = [self]
	for node in pickups:
		var other = node as XPGem
		if other != self and is_instance_valid(other) and not other.is_collected and not other.is_merging:
			if global_position.distance_squared_to(other.global_position) <= 14400.0:
				cluster.append(other)

	if cluster.size() >= 2:
		_execute_merge_cluster(get_tree(), cluster)

func _process(delta: float) -> void:
	if is_collected:
		return

	pulse_time += delta * 4.0
	rotation += 1.2 * delta
	queue_redraw()

	if is_merging:
		# During merge animation, gem cannot fly to player or be collected
		return

	if not is_instance_valid(target_player):
		find_player()
		return

	var dist = global_position.distance_to(target_player.global_position)

	# If within magnet radius, fly towards player with accelerating velocity
	if dist <= magnet_radius:
		current_speed += 480.0 * delta
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * (base_fly_speed + current_speed) * delta
		rotation += 6.0 * delta # Faster rotation when attracted

		if dist <= pickup_distance:
			collect()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.size() > 0:
		target_player = players[0] as Node2D

func _on_body_entered(body: Node2D) -> void:
	if not is_collected and not is_merging and body.is_in_group("player"):
		collect()

func collect() -> void:
	if is_collected or is_merging:
		return
	is_collected = true

	# Notify ExperienceManager
	var exp_managers = get_tree().get_nodes_in_group("experience_manager") if get_tree() else []
	if exp_managers.size() > 0:
		exp_managers[0].add_experience(xp_value)

	# Collection shrink animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.10)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Draw energy lines to merge center during merge animation
	if is_merging and merge_center != Vector2.ZERO:
		var local_target = to_local(merge_center)
		var line_col = get_tier_color()
		line_col.a = 0.75
		draw_line(Vector2.ZERO, local_target, line_col, 2.0)
		draw_circle(local_target, 3.0, Color.WHITE)

	var tier = get_tier()
	# Compact base radius: 3.8px (reduced by 37% from 6.0px)
	var tier_scale = clamp(1.0 + float(tier - 1) * 0.08, 1.0, 1.25)
	var pulse = 1.0 + sin(pulse_time) * 0.12
	var r = 3.8 * tier_scale * pulse

	var halo_col = get_tier_halo_color()
	var body_col = get_tier_color()

	# 1. Outer glowing halo
	draw_circle(Vector2.ZERO, r * 1.6, halo_col)

	# 2. Arcane diamond polygon points
	var points = PackedVector2Array([
		Vector2(0, -r * 1.4),
		Vector2(r, 0),
		Vector2(0, r * 1.4),
		Vector2(-r, 0)
	])
	draw_colored_polygon(points, body_col)

	# 3. Inner crystal highlight & distinct Tier symbols
	match tier:
		GemTier.COMMON: # Small glint
			var inner_pts = PackedVector2Array([
				Vector2(0, -r * 0.6),
				Vector2(r * 0.4, 0),
				Vector2(0, r * 0.6),
				Vector2(-r * 0.4, 0)
			])
			draw_colored_polygon(inner_pts, Color.WHITE)

		GemTier.ENHANCED: # Emerald cross star
			draw_line(Vector2(-r * 0.65, 0), Vector2(r * 0.65, 0), Color.WHITE, 1.2)
			draw_line(Vector2(0, -r * 0.9), Vector2(0, r * 0.9), Color.WHITE, 1.2)
			draw_circle(Vector2.ZERO, r * 0.35, Color(1.0, 1.0, 1.0, 0.9))

		GemTier.GREATER: # Amber sunburst ring
			draw_arc(Vector2.ZERO, r * 0.6, 0, TAU, 12, Color.WHITE, 1.2)
			draw_circle(Vector2.ZERO, r * 0.35, Color(1.0, 0.95, 0.6, 1.0))

		GemTier.RARE: # Crown star & prismatic core
			draw_arc(Vector2.ZERO, r * 0.75, 0, TAU, 16, Color(1.0, 0.85, 1.0, 0.9), 1.4)
			draw_line(Vector2(-r * 0.7, 0), Vector2(r * 0.7, 0), Color.WHITE, 1.4)
			draw_line(Vector2(0, -r * 1.0), Vector2(0, r * 1.0), Color.WHITE, 1.4)
			draw_circle(Vector2.ZERO, r * 0.4, Color.WHITE)
