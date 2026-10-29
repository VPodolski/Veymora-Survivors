class_name IceStormAbility
extends AbilityBase

@export var zone_radius: float = 120.0
@export var storm_duration: float = 3.5

var is_evolved: bool = false

func _init() -> void:
	ability_id = "ice_storm"
	ability_name = "Ледяной шторм"
	description = "Призывает морозную бурю, непрерывно наносящую урон и замедляющую врагов в области."
	category = "area"
	current_level = 1
	max_level = 5
	base_cooldown = 3.2
	base_damage = 8.0 # Per tick

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		return

	if try_cast():
		cooldown_timer = get_effective_cooldown()

func try_cast() -> bool:
	if not player_owner:
		return false

	var tree = get_tree()
	var nearest_enemy = TargetSelector.find_nearest_enemy(tree, player_owner.global_position, 650.0)
	var spawn_pos = player_owner.global_position

	if nearest_enemy:
		spawn_pos = nearest_enemy.global_position
	elif player_owner.velocity.length_squared() > 0.01:
		spawn_pos = player_owner.global_position + player_owner.velocity.normalized() * 140.0
	else:
		return false

	var zone = IceStormZone.new()
	zone.global_position = spawn_pos
	zone.radius = zone_radius
	zone.damage_per_tick = get_effective_damage()
	zone.duration = storm_duration

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	container.add_child(zone)
	return true

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_damage = 11.0
			zone_radius = 135.0
		3:
			base_cooldown = 2.7
			zone_radius = 150.0
		4:
			base_damage = 15.0
			storm_duration = 4.2
		5:
			base_damage = 20.0
			zone_radius = 175.0
			base_cooldown = 2.2

func evolve() -> void:
	is_evolved = true
	ability_name = "Абсолютный буран"
	base_damage = 32.0
	zone_radius = 230.0
	storm_duration = 6.0
	base_cooldown = 1.8

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон тика (11) и расширенный радиус бури"
		3: return "Быстрее перезарядка (2.7с) и радиус 150px"
		4: return "+Урон тика (15) и длительность 4.2с"
		5: return "Великая вьюга: радиус 175px, урон 20, кд 2.2с"
		_: return "Максимальный уровень"

