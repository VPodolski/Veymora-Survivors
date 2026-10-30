class_name SteamCloudArea
extends Area2D

@export var radius: float = 90.0
@export var damage_per_tick: float = 5.0
@export var duration: float = 2.8
@export var tick_interval: float = 0.5

var elapsed_time: float = 0.0
var tick_timer: float = 0.0
var steam_rot: float = 0.0
var steam_puffs: Array[Vector2] = []
var puff_scales: Array[float] = []

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

	for i in range(12):
		var ang = randf() * TAU
		var dist = randf_range(12.0, radius * 0.8)
		steam_puffs.append(Vector2(cos(ang), sin(ang)) * dist)
		puff_scales.append(randf_range(6.0, 14.0))

func _process(delta: float) -> void:
	elapsed_time += delta
	steam_rot += 1.2 * delta
	tick_timer += delta

	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_apply_steam_tick()

	if elapsed_time >= duration:
		set_physics_process(false)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

	queue_redraw()

func _apply_steam_tick() -> void:
	var overlapping = get_overlapping_bodies()
	var targets: Array = []
	for b in overlapping:
		if b is EnemyController and not b.is_dead:
			targets.append(b)

	if targets.is_empty():
		var nearby = TargetSelector.find_enemies_in_radius(get_tree(), global_position, radius)
		for e in nearby:
			if e is EnemyController and not e.is_dead:
				targets.append(e)

	var engines = get_tree().get_nodes_in_group("synergy_engine")
	var engine = engines[0] if engines.size() > 0 else null

	for body in targets:
		body.take_damage(damage_per_tick)
		body.apply_status(StatusEffects.STATUS_SLOWED, 2.0)
		var was_killed = (body.is_dead or body.current_health <= 0.0)
		if engine and engine.has_signal("reaction_damage_dealt"):
			engine.reaction_damage_dealt.emit("steam_rift", damage_per_tick)

func _draw() -> void:
	# 1. Diffuse steam cloud volume
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.95, 1.0, 0.15))
	# 2. Outer visible condensation boundary
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.8, 0.95, 1.0, 0.35), 2.0)

	# 3. Rotating swirling steam puffs
	var count = steam_puffs.size()
	for i in range(count):
		var pos = steam_puffs[i].rotated(steam_rot)
		var sz = puff_scales[i]
		draw_circle(pos, sz, Color(0.92, 0.96, 1.0, 0.18))
