class_name FireballAbility
extends AbilityBase

@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")
@export var fireball_count: int = 1
@export var explosion_radius: float = 85.0
@export var burn_dps: float = 6.0
@export var burn_duration: float = 3.5
@export var is_evolved: bool = false

func _init() -> void:
	ability_id = "fireball"
	ability_name = "Огненная сфера"
	description = "Запускает пылающую сферу, детонирующую при столкновении и поджигающую врагов в области."
	category = "projectile"
	current_level = 1
	max_level = 5
	base_cooldown = 2.2
	base_damage = 35.0
	explosion_radius = 85.0
	burn_dps = 6.0
	fireball_count = 1

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		return

	if try_cast():
		cooldown_timer = get_effective_cooldown()

func try_cast() -> bool:
	if not projectile_scene or not player_owner:
		return false

	var tree = get_tree()
	if not tree:
		return false

	var enemy = TargetSelector.find_nearest_enemy(tree, player_owner.global_position, 650.0)
	if not enemy or not is_instance_valid(enemy):
		return false

	cast_fireball(enemy)
	return true

func cast_fireball(target: EnemyController) -> void:
	if not projectile_scene or not is_instance_valid(target) or not player_owner:
		return

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var base_dir = (target.global_position - player_owner.global_position).normalized()
	var base_angle = base_dir.angle()
	var count = fireball_count
	var spread_angle = 0.22 # Radians

	var area_mult = 1.0
	if player_owner:
		if player_owner.has_meta("spell_area_mult"):
			area_mult = player_owner.get_meta("spell_area_mult")
		elif "stats" in player_owner and player_owner.stats and "spell_area_mult" in player_owner.stats:
			area_mult = player_owner.stats.spell_area_mult

	for i in range(count):
		var angle = base_angle
		if count > 1:
			var offset = (float(i) - (float(count - 1) * 0.5)) * spread_angle
			angle += offset

		var dir = Vector2(cos(angle), sin(angle))
		var proj = projectile_scene.instantiate() as Projectile
		proj.faction = Projectile.Faction.PLAYER
		proj.global_position = player_owner.global_position + dir * 20.0
		proj.direction = dir
		proj.speed = 420.0
		proj.damage = get_effective_damage()
		proj.tags = ["fire", "projectile", "area"]
		proj.projectile_color = Color(1.0, 0.45, 0.1, 1.0)
		proj.is_evolved = is_evolved
		proj.is_area = true
		proj.area_radius = explosion_radius * area_mult
		proj.status_to_apply = StatusEffects.STATUS_BURNING
		proj.status_duration = burn_duration
		proj.ability_source_id = "fireball"

		if is_evolved:
			proj.damage *= 1.8
			proj.speed = 520.0
			proj.area_radius = 160.0 * area_mult
			proj.pierce_count = 999
			proj.scale = Vector2(1.6, 1.6)

		container.add_child(proj)

	CombatEffects.spawn_shockwave(container, player_owner.global_position, 45.0, Color(1.0, 0.4, 0.1, 0.7))

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_cooldown = 2.0
			base_damage = 44.0
			explosion_radius = 95.0
			burn_dps = 6.0
		3:
			base_cooldown = 2.0
			fireball_count = 2
			base_damage = 48.0
			explosion_radius = 95.0
			burn_dps = 7.5
		4:
			base_cooldown = 1.8
			fireball_count = 2
			base_damage = 54.0
			explosion_radius = 110.0
			burn_dps = 9.0
		5:
			base_cooldown = 1.8
			fireball_count = 2
			base_damage = 62.0
			explosion_radius = 120.0
			burn_dps = 12.0

func evolve() -> void:
	is_evolved = true
	ability_name = "Инфернальная сверхновая"
	description = "★ ЭВОЛЮЦИЯ! Гигантская сфера с радиусом взрыва 160px и уроном 110."
	base_damage = 50.0
	base_cooldown = 1.6
	explosion_radius = 160.0

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон взрыва (44), радиус 95px, кд 2.0с"
		3: return "+1 Сфера (2 огненных шара веером), урон 48"
		4: return "+Радиус взрыва (110px), горение 9/с, кд 1.8с"
		5: return "Инферно: 2 сферы, урон 62, радиус 120px, горение 12/с"
		_: return "Максимальный уровень"
