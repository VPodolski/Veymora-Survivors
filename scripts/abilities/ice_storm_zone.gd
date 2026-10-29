class_name IceStormZone
extends Area2D

@export var radius: float = 120.0
@export var damage_per_tick: float = 8.0
@export var duration: float = 3.5
@export var tick_interval: float = 0.5

var elapsed_time: float = 0.0
var tick_timer: float = 0.0
var swirl_angle: float = 0.0
var flake_offsets: Array[Vector2] = []

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

	for i in range(16):
		var ang = randf() * TAU
		var dist = randf_range(10.0, radius * 0.9)
		flake_offsets.append(Vector2(cos(ang), sin(ang)) * dist)

func _process(delta: float) -> void:
	elapsed_time += delta
	swirl_angle += 2.8 * delta
	tick_timer += delta

	if tick_timer >= tick_interval:
		tick_timer = 0.0
		apply_storm_tick()

	if elapsed_time >= duration:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)

	queue_redraw()

func apply_storm_tick() -> void:
	var overlapping = get_overlapping_bodies()
	var engines = get_tree().get_nodes_in_group("synergy_engine")

	for body in overlapping:
		if body is EnemyController and not body.is_dead:
			body.take_damage(damage_per_tick)
			body.apply_status(StatusEffects.STATUS_SLOWED, 2.5)

			if engines.size() > 0:
				var ctx = ReactionContext.new(self, body, ["ice", "area"], body.global_position, damage_per_tick, 0)
				engines[0].on_hit_landed(ctx)

func _draw() -> void:
	# Frost zone ground circle
	draw_circle(Vector2.ZERO, radius, Color(0.1, 0.5, 0.85, 0.16))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.4), 2.0)

	# Rotating snowflake particles
	var count = flake_offsets.size()
	for i in range(count):
		var base_pos = flake_offsets[i]
		var rotated = base_pos.rotated(swirl_angle)
		draw_circle(rotated, 2.2, Color(0.85, 0.95, 1.0, 0.85))

