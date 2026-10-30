class_name FireballAbility
extends AbilityBase

@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")
@export var is_evolved: bool = false

func _init() -> void:
	ability_id = "fireball"
	ability_name = "Огненная сфера"
	description = "Запускает пылающую сферу, наносящую огненный урон и поджигающую врагов."
	category = "projectile"
	current_level = 1
	max_level = 5
	base_cooldown = 2.4
	base_damage = 26.0

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
	var dir = (target.global_position - player_owner.global_position).normalized()
	var proj = projectile_scene.instantiate() as Projectile
	proj.faction = Projectile.Faction.PLAYER
	proj.global_position = player_owner.global_position + dir * 20.0
	proj.direction = dir
	proj.speed = 420.0
	proj.damage = get_effective_damage()
	proj.tags = ["fire", "projectile", "area"]
	proj.projectile_color = Color(1.0, 0.45, 0.1, 1.0)
	proj.is_evolved = is_evolved

	if is_evolved:
		proj.damage *= 1.8
		proj.speed = 520.0
		proj.pierce_count = 999
		proj.scale = Vector2(1.6, 1.6)

	container.add_child(proj)
	CombatEffects.spawn_shockwave(container, player_owner.global_position, 45.0, Color(1.0, 0.4, 0.1, 0.7))

func apply_level_modifiers() -> void:
	base_damage += 6.0
	base_cooldown = max(1.2, base_cooldown - 0.2)

func evolve() -> void:
	is_evolved = true
	ability_name = "Инфернальная сверхновая"
	description = "★ ЭВОЛЮЦИЯ! Гигантская пробивающая сфера с уроном 50, испускающая волны огненных взрывов."
	base_damage = 50.0
	base_cooldown = 1.8
