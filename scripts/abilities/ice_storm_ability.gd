class_name IceStormAbility
extends AbilityBase

@export var zone_radius: float = 110.0
@export var storm_duration: float = 3.0
@export var slow_ratio: float = 0.40
@export var max_active_zones: int = 2

var is_evolved: bool = false
var active_zones: Array[IceStormZone] = []

func _init() -> void:
	ability_id = "ice_storm"
	ability_name = "Ледяной шторм"
	description = "Призывает морозную бурю, непрерывно наносящую урон и замедляющую врагов в области (макс. 2 зоны)."
	category = "area"
	current_level = 1
	max_level = 5
	base_cooldown = 3.5
	base_damage = 5.0 # Per tick
	zone_radius = 110.0
	storm_duration = 3.0
	slow_ratio = 0.40

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

	# Clean up invalid zones
	var valid_zones: Array[IceStormZone] = []
	for z in active_zones:
		if is_instance_valid(z) and not z.is_queued_for_deletion():
			valid_zones.append(z)
	active_zones = valid_zones

	# Enforce cap of 2 active zones
	while active_zones.size() >= max_active_zones:
		var oldest = active_zones.pop_front()
		if is_instance_valid(oldest) and oldest.has_method("fade_out"):
			oldest.fade_out()

	var area_mult = 1.0
	if player_owner:
		if player_owner.has_meta("spell_area_mult"):
			area_mult = player_owner.get_meta("spell_area_mult")
		elif "stats" in player_owner and player_owner.stats and "spell_area_mult" in player_owner.stats:
			area_mult = player_owner.stats.spell_area_mult

	var zone = IceStormZone.new()
	zone.global_position = spawn_pos
	zone.radius = zone_radius * area_mult
	zone.damage_per_tick = get_effective_damage()
	zone.duration = storm_duration
	zone.slow_ratio = slow_ratio

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	container.add_child(zone)
	active_zones.append(zone)
	return true

func apply_level_modifiers() -> void:
	match current_level:
		2:
			base_cooldown = 3.5
			base_damage = 6.5
			zone_radius = 125.0
			storm_duration = 3.0
		3:
			base_cooldown = 3.0
			base_damage = 8.0
			zone_radius = 125.0
			storm_duration = 3.5
		4:
			base_cooldown = 3.0
			base_damage = 10.0
			zone_radius = 145.0
			storm_duration = 3.5
			slow_ratio = 0.50
		5:
			base_cooldown = 2.6
			base_damage = 12.0
			zone_radius = 160.0
			storm_duration = 4.0
			slow_ratio = 0.50

func evolve() -> void:
	is_evolved = true
	ability_name = "Абсолютный буран"
	description = "★ ЭВОЛЮЦИЯ! Радиус бури 195px, урон 18/тик, перманентное замораживание и ледяной шквал."
	base_damage = 18.0
	zone_radius = 195.0
	storm_duration = 4.5
	base_cooldown = 2.2
	max_active_zones = 2
	slow_ratio = 0.60

func get_next_upgrade_description() -> String:
	match current_level + 1:
		2: return "+Урон тика (6.5) и радиус 125px"
		3: return "Быстрее перезарядка (3.0с), урон тика 8, длительность 3.5с"
		4: return "+Урон тика (10.0), радиус 145px, замедление -50%"
		5: return "Великая вьюга: радиус 160px, урон 12/тик, кд 2.6с, длит. 4.0с"
		_: return "Максимальный уровень"
