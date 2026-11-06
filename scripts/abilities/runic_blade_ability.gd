class_name RunicBladeAbility
extends AbilityBase

const DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

@export var blade_count: int = 1
@export var orbit_radius: float = 90.0
@export var orbit_speed: float = 3.2 # Radians per second
@export var hit_interval_per_enemy: float = 0.45
@export var tags: Array = ["arcane", "melee", "orbit"]

var current_angle: float = 0.0
var enemy_hit_timers: Dictionary = {} # enemy_id: float
var blade_nodes: Array[Area2D] = []

func _init() -> void:
	ability_id = "runic_blade"
	ability_name = "Рунический клинок"
	description = "Призывает рунические клинки, вращающиеся вокруг мага, рассекающие врагов и сбивающие вражеские снаряды."
	category = "melee"
	current_level = 1
	max_level = 5
	base_cooldown = 0.0
	base_damage = 18.0
	orbit_radius = 90.0
	orbit_speed = 3.2
	blade_count = 1

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
	var eff_radius = get_effective_orbit_radius()
	for i in range(count):
		var blade = blade_nodes[i]
		if is_instance_valid(blade):
			var angle = current_angle + (float(i) * TAU / float(count))
			var offset = Vector2(cos(angle), sin(angle)) * eff_radius
			blade.position = offset
			blade.rotation = angle + PI * 0.5

func get_effective_orbit_radius() -> float:
	var area_mult = 1.0
	if player_owner:
		if player_owner.has_meta("spell_area_mult"):
			area_mult = player_owner.get_meta("spell_area_mult")
		elif "stats" in player_owner and player_owner.stats and "spell_area_mult" in player_owner.stats:
			area_mult = player_owner.stats.spell_area_mult
	return orbit_radius * area_mult

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
	area.collision_mask = 4 | 8 # Layer 3 (Enemies) and Layer 4 (Projectiles)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	area.add_child(shape)

	var visual = RunicBladeVisual.new()
	area.add_child(visual)

	area.body_entered.connect(func(body: Node2D): _on_blade_hit(body))
	area.area_entered.connect(func(other_area: Area2D): _on_blade_area_entered(other_area))
	return area

func _on_blade_area_entered(other_area: Area2D) -> void:
	if other_area is Projectile and other_area.faction == Projectile.Faction.ENEMY:
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		CombatEffects.spawn_impact_sparks(container, other_area.global_position, Color(0.3, 0.85, 1.0), 6)
		CombatEffects.spawn_hit_flash(container, other_area.global_position, Color(0.6, 0.9, 1.0), 12.0)
		CombatEffects.spawn_ring(container, other_area.global_position, 4.0, 20.0, Color(0.4, 0.8, 1.0, 0.8), 0.15, 1.5)
		if AudioManager.instance:
			AudioManager.instance.play_spell("magic_bolt")
		var prevented_dmg = other_area.damage if "damage" in other_area else 12.0
		var rs = RunStats.active_stats
		if rs and rs.has_method("record_projectile_intercepted"):
			rs.record_projectile_intercepted(prevented_dmg)
		other_area.destroy()

func _on_blade_hit(body: Node2D) -> void:
	if body is EnemyController and not body.is_dead:
		var id = body.get_instance_id()
		if not enemy_hit_timers.has(id):
			enemy_hit_timers[id] = hit_interval_per_enemy
			var dmg = get_effective_damage()
			var hit_tags = tags.duplicate()

			var has_fire = player_owner and (player_owner.has_meta("has_blazing_blades") or (player_owner.ability_controller and player_owner.ability_controller.has_ability("fireball")))
			if has_fire:
				if not hit_tags.has("fire"):
					hit_tags.append("fire")

			var ctx = DamageContext.new(self, body, dmg, hit_tags, "runic_blade", body.global_position, false, 0, "", true)
			DamageResolver.apply_damage(ctx)

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_damage = 25.0
			orbit_radius = 96.0
			orbit_speed = 3.4
		3:
			blade_count = 2
			base_damage = 25.0
			orbit_radius = 96.0
			orbit_speed = 3.8
			rebuild_blades()
		4:
			blade_count = 2
			base_damage = 34.0
			orbit_radius = 105.0
			orbit_speed = 4.0
		5:
			blade_count = 3
			base_damage = 42.0
			orbit_radius = 105.0
			orbit_speed = 4.4
			rebuild_blades()

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон (25) и радиус орбиты 96px"
		3: return "+1 Клинок (2 клинка) и ускорение вращения"
		4: return "+Урон (34) и радиус орбиты 105px"
		5: return "Вихрь стали: 3 клинка, урон 42, плотный щит"
		_: return "Максимальный уровень"

# Visual sub-node for drawing runic blade
class RunicBladeVisual extends Node2D:
	func _draw() -> void:
		var is_blazing = false
		var parent = get_parent()
		if parent and parent.get_parent() is RunicBladeAbility:
			var rb = parent.get_parent() as RunicBladeAbility
			if rb.player_owner and (rb.player_owner.has_meta("has_blazing_blades") or (rb.player_owner.ability_controller and rb.player_owner.ability_controller.has_ability("fireball"))):
				is_blazing = true

		if is_blazing:
			# Flaming aura
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.45, 0.1, 0.35))
			var tip = Vector2(0, -20)
			var left_edge = Vector2(-8, 2)
			var right_edge = Vector2(8, 2)
			var pommel = Vector2(0, 10)
			var pts = PackedVector2Array([tip, right_edge, pommel, left_edge])
			draw_colored_polygon(pts, Color(0.9, 0.3, 0.05, 0.95))
			draw_line(Vector2(0, -14), Vector2(0, 4), Color(1.0, 0.9, 0.3, 1.0), 2.5)
			draw_line(Vector2(-10, 2), Vector2(10, 2), Color(0.6, 0.1, 0.0, 1.0), 3.0)
		else:
			# Glowing arcane aura
			draw_circle(Vector2.ZERO, 14.0, Color(0.7, 0.2, 1.0, 0.25))
			var tip = Vector2(0, -18)
			var left_edge = Vector2(-7, 2)
			var right_edge = Vector2(7, 2)
			var pommel = Vector2(0, 10)
			var pts = PackedVector2Array([tip, right_edge, pommel, left_edge])
			draw_colored_polygon(pts, Color(0.5, 0.15, 0.85, 0.95))
			draw_line(Vector2(0, -12), Vector2(0, 4), Color(0.9, 0.7, 1.0, 1.0), 2.0)
			draw_line(Vector2(-9, 2), Vector2(9, 2), Color(0.3, 0.1, 0.5, 1.0), 3.0)
