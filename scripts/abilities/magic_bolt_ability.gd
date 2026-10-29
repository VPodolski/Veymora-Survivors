class_name MagicBoltAbility
extends AbilityBase

@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")
@export var projectile_count: int = 1
@export var spread_angle: float = 0.25 # Radians

func _init() -> void:
	ability_id = "magic_bolt"
	ability_name = "Магическая стрела"
	description = "Выпускает сгустки чародейской энергии в ближайших врагов."
	category = "ranged"
	current_level = 1
	max_level = 5
	base_cooldown = 1.2
	base_damage = 18.0

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
	var nearest_enemy = TargetSelector.find_nearest_enemy(tree, player_owner.global_position, 850.0)

	var target_dir = Vector2.RIGHT
	if nearest_enemy:
		target_dir = (nearest_enemy.global_position - player_owner.global_position).normalized()
	elif player_owner.velocity.length_squared() > 0.01:
		target_dir = player_owner.velocity.normalized()
	else:
		return false # Don't waste shots if no enemy in range and not moving

	fire_projectiles(target_dir)
	return true

func fire_projectiles(base_dir: Vector2) -> void:
	var count = projectile_count
	var base_angle = base_dir.angle()

	for i in range(count):
		var angle = base_angle
		if count > 1:
			var offset = (float(i) - (float(count - 1) * 0.5)) * spread_angle
			angle += offset

		var proj = projectile_scene.instantiate() as Projectile
		proj.global_position = player_owner.global_position
		proj.direction = Vector2(cos(angle), sin(angle))
		proj.damage = get_effective_damage()
		var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
		container.add_child(proj)

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_damage = 26.0
			base_cooldown = 1.05
		3:
			projectile_count = 2
			base_damage = 26.0
		4:
			base_damage = 34.0
			base_cooldown = 0.9
		5:
			projectile_count = 3
			base_damage = 42.0
			base_cooldown = 0.8

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон (26) и быстрее перезарядка (1.05с)"
		3: return "+1 Снаряд (2 стрелы веером)"
		4: return "+Урон (34) и быстрее перезарядка (0.9с)"
		5: return "+1 Снаряд (3 стрелы веером), урон 42"
		_: return "Максимальный уровень"
