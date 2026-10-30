class_name Arena
extends Node2D

const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const RuneZone = preload("res://scripts/arena/rune_zone.gd")
const FrostHazardZone = preload("res://scripts/arena/frost_hazard_zone.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")

@export var arena_config: ArenaConfig = null
@export var arena_size: Vector2 = Vector2(2400, 1600)
@export var border_color: Color = Color(0.25, 0.45, 0.75, 0.8)
@export var floor_color: Color = Color(0.06, 0.07, 0.1, 1.0)
@export var grid_color: Color = Color(0.1, 0.13, 0.18, 0.4)
@export var ambient_color: Color = Color(0.3, 0.7, 1.0, 0.5)

var current_arena_id: String = "forgotten_forest"
var hazard_timer: float = 18.0

func _ready() -> void:
	add_to_group("arena")
	if arena_config == null:
		var target_id = "forgotten_forest"
		if GameFlowController.instance:
			target_id = GameFlowController.instance.get_run_config().arena_id
		arena_config = ArenaConfig.get_arena_config(target_id)

	apply_arena_config(arena_config)
	setup_boundary_colliders()
	queue_redraw()

func apply_arena_config(cfg: ArenaConfig) -> void:
	if not cfg:
		return
	arena_config = cfg
	current_arena_id = cfg.id
	arena_size = cfg.arena_size
	floor_color = cfg.floor_color
	grid_color = cfg.grid_color
	border_color = cfg.border_color
	ambient_color = cfg.ambient_color
	hazard_timer = 12.0 if cfg.special_mechanic == "frost_zones" else 25.0

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	hazard_timer -= delta
	if hazard_timer <= 0.0:
		if arena_config and arena_config.special_mechanic == "frost_zones":
			hazard_timer = randf_range(16.0, 22.0)
			spawn_frost_zone()
		else:
			hazard_timer = 50.0
			var existing = get_tree().get_nodes_in_group("rune_zones")
			if existing.is_empty():
				spawn_rune_zone()

func spawn_rune_zone() -> void:
	var rz = RuneZone.new()
	var half_w = arena_size.x * 0.32
	var half_h = arena_size.y * 0.32
	rz.global_position = Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))
	add_child(rz)

func spawn_frost_zone() -> void:
	var fz = FrostHazardZone.new()
	var target_pos = Vector2.ZERO
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0] as Node2D
		var offset = Vector2(randf_range(-260.0, 260.0), randf_range(-200.0, 200.0))
		target_pos = p.global_position + offset
	else:
		var half_w = arena_size.x * 0.3
		var half_h = arena_size.y * 0.3
		target_pos = Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))

	var half_w = arena_size.x * 0.45
	var half_h = arena_size.y * 0.45
	target_pos.x = clampf(target_pos.x, -half_w, half_w)
	target_pos.y = clampf(target_pos.y, -half_h, half_h)

	fz.global_position = target_pos
	add_child(fz)

func setup_boundary_colliders() -> void:
	var walls_body = $Walls as StaticBody2D
	if not walls_body:
		return

	# Remove any existing collider children to avoid overlapping bounds on re-config
	for child in walls_body.get_children():
		child.queue_free()

	var half_w = arena_size.x * 0.5
	var half_h = arena_size.y * 0.5
	var thickness = 64.0

	# Top wall
	create_wall_shape(walls_body, Vector2(0, -half_h - thickness * 0.5), Vector2(arena_size.x + thickness * 2, thickness))
	# Bottom wall
	create_wall_shape(walls_body, Vector2(0, half_h + thickness * 0.5), Vector2(arena_size.x + thickness * 2, thickness))
	# Left wall
	create_wall_shape(walls_body, Vector2(-half_w - thickness * 0.5, 0), Vector2(thickness, arena_size.y + thickness * 2))
	# Right wall
	create_wall_shape(walls_body, Vector2(half_w + thickness * 0.5, 0), Vector2(thickness, arena_size.y + thickness * 2))

func create_wall_shape(parent_body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	col.shape = rect_shape
	col.position = pos
	parent_body.add_child(col)

func _draw() -> void:
	var half_w = arena_size.x * 0.5
	var half_h = arena_size.y * 0.5
	var rect = Rect2(-half_w, -half_h, arena_size.x, arena_size.y)

	# 1. Dark arena floor
	draw_rect(rect, floor_color, true)

	# 2. Subtle floor grid
	var grid_step = 120.0
	var x = -half_w
	while x <= half_w:
		draw_line(Vector2(x, -half_h), Vector2(x, half_h), grid_color, 1.0)
		x += grid_step

	var y = -half_h
	while y <= half_h:
		draw_line(Vector2(-half_w, y), Vector2(half_w, y), grid_color, 1.0)
		y += grid_step

	# 3. Central arcane ring
	var ring_col = Color(ambient_color.r, ambient_color.g, ambient_color.b, 0.22)
	draw_arc(Vector2.ZERO, 160.0, 0, TAU, 64, ring_col, 2.0)
	draw_arc(Vector2.ZERO, 320.0, 0, TAU, 64, Color(ambient_color.r, ambient_color.g, ambient_color.b, 0.12), 2.0)

	# 4. Arena boundaries
	draw_rect(rect, border_color, false, 4.0)
	# Inner glowing accent border
	var inner_rect = Rect2(-half_w + 6, -half_h + 6, arena_size.x - 12, arena_size.y - 12)
	draw_rect(inner_rect, Color(border_color.r, border_color.g, border_color.b, 0.28), false, 1.5)
