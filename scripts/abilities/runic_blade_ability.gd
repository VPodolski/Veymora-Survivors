class_name RunicBladeAbility
extends AbilityBase

@export var blade_count: int = 1
@export var orbit_radius: float = 92.0
@export var orbit_speed: float = 3.4 # Radians per second
@export var hit_interval_per_enemy: float = 0.45

var current_angle: float = 0.0
var enemy_hit_timers: Dictionary = {} # enemy_id: float
var blade_nodes: Array[Area2D] = []

func _init() -> void:
	ability_id = "runic_blade"
	ability_name = "Рунический клинок"
	description = "Призывает древние рунические клинки, вращающиеся вокруг мага и рассекающие врагов."
	category = "melee"
	current_level = 1
	max_level = 5
	base_cooldown = 0.0
	base_damage = 15.0

func _ready() -> void:
	super._ready()
	rebuild_blades()

func _physics_process(delta: float) -> void:
	current_angle += orbit_speed * delta
	if current_angle > TAU:
		current_angle -= TAU

	# Update hit timers
	for id in enemy_hit_timers.keys():
		enemy_hit_timers[id] -= delta
		if enemy_hit_timers[id] <= 0.0:
			enemy_hit_timers.erase(id)

	# Position blades around player
	var count = blade_nodes.size()
	for i in range(count):
		var blade = blade_nodes[i]
		var angle = current_angle + (float(i) * TAU / float(count))
		var offset = Vector2(cos(angle), sin(angle)) * orbit_radius
		blade.position = offset
		blade.rotation = angle + PI * 0.5

func rebuild_blades() -> void:
	# Clear old blades
	for b in blade_nodes:
		if is_instance_valid(b):
			b.queue_free()
	blade_nodes.clear()

	for i in range(blade_count):
		var blade = create_blade_node()
		add_child(blade)
		blade_nodes.append(blade)

func create_blade_node() -> Area2D:
	var area = Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 4

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	area.add_child(shape)

	var visual = RunicBladeVisual.new()
	area.add_child(visual)

	area.body_entered.connect(func(body: Node2D): _on_blade_hit(body))
	return area

func _on_blade_hit(body: Node2D) -> void:
	if body is EnemyController and not body.is_dead:
		var id = body.get_instance_id()
		if not enemy_hit_timers.has(id):
			enemy_hit_timers[id] = hit_interval_per_enemy
			body.take_damage(get_effective_damage())

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_damage = 22.0
			orbit_radius = 98.0
		3:
			blade_count = 2
			base_damage = 22.0
			rebuild_blades()
		4:
			base_damage = 30.0
			orbit_speed = 4.2
		5:
			blade_count = 3
			base_damage = 38.0
			orbit_speed = 4.8
			rebuild_blades()

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон (22) и увеличенный радиус орбиты"
		3: return "+1 Клинок (2 вращающихся клинка)"
		4: return "+Урон (30) и ускоренное вращение"
		5: return "+1 Клинок (3 клинка) и урон 38"
		_: return "Максимальный уровень"

# Visual sub-node for drawing runic blade
class RunicBladeVisual extends Node2D:
	func _draw() -> void:
		# Glowing aura
		draw_circle(Vector2.ZERO, 14.0, Color(0.7, 0.2, 1.0, 0.25))

		# Dagger / blade silhouette
		var tip = Vector2(0, -18)
		var left_edge = Vector2(-7, 2)
		var right_edge = Vector2(7, 2)
		var pommel = Vector2(0, 10)
		var pts = PackedVector2Array([tip, right_edge, pommel, left_edge])
		draw_colored_polygon(pts, Color(0.5, 0.15, 0.85, 0.95))

		# Glowing runic center line
		draw_line(Vector2(0, -12), Vector2(0, 4), Color(0.9, 0.7, 1.0, 1.0), 2.0)
		# Arcane crossguard
		draw_line(Vector2(-9, 2), Vector2(9, 2), Color(0.3, 0.1, 0.5, 1.0), 3.0)
