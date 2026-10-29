class_name LightningAbility
extends AbilityBase

var tags: Array = ["lightning", "chain"]

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

	# Primary strike
	CombatEffects.spawn_lightning_arc(container, player_owner.global_position, pos, Color(0.4, 0.85, 1.0, 1.0))
	CombatEffects.spawn_text_popup(container, pos, "МОЛНИЯ!", Color(0.45, 0.85, 1.0, 1.0))
	target.take_damage(dmg)
	target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# Trigger synergy on primary target
	var engines = get_tree().get_nodes_in_group("synergy_engine")
	if engines.size() > 0:
		var ctx = ReactionContext.new(self, target, tags, pos, dmg, 0)
		engines[0].on_hit_landed(ctx)

	# Chain jumps
	var max_jumps = min(4, 1 + current_level)
	var chained_targets = [target]
	var current_pos = pos

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 160.0)
	for next_enemy in nearby:
		if chained_targets.size() >= max_jumps:
			break
		if not chained_targets.has(next_enemy) and is_instance_valid(next_enemy) and not next_enemy.is_dead:
			chained_targets.append(next_enemy)
			CombatEffects.spawn_lightning_arc(container, current_pos, next_enemy.global_position, Color(0.5, 0.9, 1.0, 0.95))
			next_enemy.take_damage(dmg * 0.75)
			next_enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.5)
			current_pos = next_enemy.global_position

func apply_level_modifiers() -> void:
	base_damage += 5.0
	base_cooldown = max(1.5, base_cooldown - 0.25)
