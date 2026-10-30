class_name Arena
extends Node2D

const RuneZone = preload("res://scripts/arena/rune_zone.gd")

@export var arena_size: Vector2 = Vector2(2400, 1600)
@export var border_color: Color = Color(0.25, 0.45, 0.75, 0.8)
@export var floor_color: Color = Color(0.06, 0.07, 0.1, 1.0)
@export var grid_color: Color = Color(0.1, 0.13, 0.18, 0.4)

var rune_zone_timer: float = 25.0

func _ready() -> void:
	setup_boundary_colliders()
	queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	rune_zone_timer -= delta
	if rune_zone_timer <= 0.0:
		rune_zone_timer = 50.0
		var existing = get_tree().get_nodes_in_group("rune_zones")
		if existing.is_empty():
			spawn_rune_zone()

func spawn_rune_zone() -> void:
	var rz = RuneZone.new()
	var half_w = arena_size.x * 0.32
	var half_h = arena_size.y * 0.32
	rz.global_position = Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))
	add_child(rz)

func setup_boundary_colliders() -> void:
	var walls_body = $Walls as StaticBody2D
	if not walls_body:
		return

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

	# 1. Dark floor
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
	draw_arc(Vector2.ZERO, 160.0, 0, TAU, 64, Color(0.2, 0.35, 0.55, 0.2), 2.0)
	draw_arc(Vector2.ZERO, 320.0, 0, TAU, 64, Color(0.2, 0.35, 0.55, 0.12), 2.0)

	# 4. Arena boundaries
	draw_rect(rect, border_color, false, 4.0)
	# Inner glowing accent border
	var inner_rect = Rect2(-half_w + 6, -half_h + 6, arena_size.x - 12, arena_size.y - 12)
	draw_rect(inner_rect, Color(0.4, 0.65, 1.0, 0.25), false, 1.5)

