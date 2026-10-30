class_name LightningAbility
extends AbilityBase

var tags: Array = ["lightning", "chain"]
@export var is_evolved: bool = false

func _init() -> void:
	ability_id = "lightning_strike"
	ability_name = "Грозовой разряд"
	description = "Призывает цепную молнию, поражающую нескольких врагов зарядом статического электричества."
	category = "chain"
	current_level = 1
	max_level = 5
	base_cooldown = 2.8
	base_damage = 22.0

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
	if not tree:
		return false

	var enemy = TargetSelector.find_nearest_enemy(tree, player_owner.global_position, 650.0)
	if not enemy or not is_instance_valid(enemy):
		return false

	cast_lightning(enemy)
	return true

func cast_lightning(target: EnemyController) -> void:
	if not is_instance_valid(target) or not player_owner:
		return

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var dmg = get_effective_damage()
	var pos = target.global_position
	var chained_targets: Array = [target]

	# Primary strike visuals & damage
	var arc_col = Color(0.8, 0.95, 1.0, 1.0) if is_evolved else Color(0.4, 0.85, 1.0, 1.0)
	var arc_w = 3.8 if is_evolved else 2.4
	CombatEffects.spawn_lightning_arc(container, player_owner.global_position, pos, arc_col, arc_w)
	CombatEffects.spawn_hit_flash(container, pos, arc_col, 16.0 if is_evolved else 12.0)
	target.take_damage(dmg)

	# Trigger synergy on primary target (before setting base charge to ensure accurate condition)
	var engines = get_tree().get_nodes_in_group("synergy_engine")
	if engines.size() > 0:
		var ctx = ReactionContext.new(self, target, tags, pos, dmg, 0, true, chained_targets)
		engines[0].on_hit_landed(ctx)
	else:
		if is_instance_valid(target) and not target.is_dead:
			target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# Calculate max jumps including Lightning Rod artifact bonus
	var extra_jumps = 1 if (player_owner and player_owner.get_meta("has_lightning_rod", false)) else 0
	var max_jumps = (7 if is_evolved else min(5, 1 + current_level)) + extra_jumps
	var current_pos = pos

	var search_radius = 220.0 if is_evolved else 160.0
	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, search_radius)
	for next_enemy in nearby:
		if chained_targets.size() >= max_jumps:
			break
		if not chained_targets.has(next_enemy) and is_instance_valid(next_enemy) and not next_enemy.is_dead:
			chained_targets.append(next_enemy)
			var sub_w = max(1.2, arc_w * (1.0 - float(chained_targets.size()) * 0.08))
			CombatEffects.spawn_lightning_arc(container, current_pos, next_enemy.global_position, arc_col, sub_w)
			CombatEffects.spawn_hit_flash(container, next_enemy.global_position, arc_col, 10.0)
			next_enemy.take_damage(dmg * (0.9 if is_evolved else 0.75))
			if is_instance_valid(next_enemy) and not next_enemy.is_dead:
				next_enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.5)
			current_pos = next_enemy.global_position

func apply_level_modifiers() -> void:
	base_damage += 5.0
	base_cooldown = max(1.5, base_cooldown - 0.25)

func evolve() -> void:
	is_evolved = true
	ability_name = "Ярость Небес"
	description = "★ ЭВОЛЮЦИЯ! Штормовой каскад небесных молний (до 7 скачков, урон 45, интервал 1.4 сек)."
	base_damage = 45.0
	base_cooldown = 1.4
