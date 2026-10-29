class_name SynergyEngine
extends Node

const MAX_REACTION_DEPTH = 2

var reaction_cooldowns: Dictionary = {} # "target_id_reaction_name": float_time

func _ready() -> void:
	add_to_group("synergy_engine")

func on_hit_landed(context: ReactionContext) -> void:
	if not context or not is_instance_valid(context.target) or context.target.is_dead:
		return

	if context.depth >= MAX_REACTION_DEPTH:
		return

	var target = context.target

	# 1. Arcane Resonance
	if context.has_tag("arcane") or context.has_tag("lightning"):
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "resonance"):
				trigger_arcane_resonance(context)
		else:
			target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# 2. Frost Shatter
	if (context.has_tag("melee") or context.has_tag("orbit") or context.has_tag("ice")) and target.has_status(StatusEffects.STATUS_SLOWED):
		if can_trigger_reaction(target, "frost_shatter"):
			trigger_frost_shatter(context)

	# 3. Lightning Chain
	if context.has_tag("lightning"):
		if can_trigger_reaction(target, "lightning_chain"):
			trigger_lightning_chain(context)

func trigger_arcane_resonance(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "resonance")

	CombatEffects.spawn_shockwave(container, pos, 80.0, Color(0.65, 0.3, 1.0, 0.95))
	CombatEffects.spawn_text_popup(container, pos, "РЕЗОНАНС!", Color(0.8, 0.45, 1.0, 1.0))

	# AoE burst damage to nearby enemies
	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 85.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var sub_context = ReactionContext.new(self, enemy, ["arcane", "resonance"], enemy.global_position, 18.0, context.depth + 1)
			enemy.take_damage(18.0)
			# Chain reaction chance on neighboring enemies
			if enemy != target and not enemy.has_status(StatusEffects.STATUS_CHARGED):
				enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)

func trigger_frost_shatter(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	record_reaction(target, "frost_shatter")

	CombatEffects.spawn_shockwave(container, pos, 65.0, Color(0.2, 0.85, 1.0, 0.9))
	CombatEffects.spawn_text_popup(container, pos, "РАСКОЛ!", Color(0.3, 0.9, 1.0, 1.0))

	# 3 frost shards fly out
	var base_angle = randf() * TAU
	for i in range(3):
		var angle = base_angle + float(i) * (TAU / 3.0)
		var dir = Vector2(cos(angle), sin(angle))
		var proj_scene = preload("res://scenes/combat/projectile.tscn")
		var proj = proj_scene.instantiate() as Projectile
		proj.global_position = pos + dir * 10.0
		proj.direction = dir
		proj.damage = 14.0
		proj.projectile_color = Color(0.3, 0.9, 1.0, 1.0)
		container.add_child(proj)

func trigger_lightning_chain(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	record_reaction(target, "lightning_chain")
	CombatEffects.spawn_text_popup(container, pos, "РАЗРЯД!", Color(0.4, 0.8, 1.0, 1.0))

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 150.0)
	var chained_count = 0
	for enemy in nearby:
		if enemy != target and is_instance_valid(enemy) and not enemy.is_dead:
			CombatEffects.spawn_lightning_arc(container, pos, enemy.global_position, Color(0.4, 0.8, 1.0, 1.0))
			var sub_context = ReactionContext.new(self, enemy, ["lightning"], enemy.global_position, 14.0, context.depth + 1)
			enemy.take_damage(14.0)
			enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)
			chained_count += 1
			if chained_count >= 2:
				break

func trigger_unstable_explosion(pos: Vector2) -> void:
	var container = get_effects_container()
	CombatEffects.spawn_shockwave(container, pos, 90.0, Color(0.85, 0.25, 1.0, 0.95))
	CombatEffects.spawn_text_popup(container, pos, "РАЗЛОМ!", Color(0.9, 0.35, 1.0, 1.0))

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(25.0)

func can_trigger_reaction(target: EnemyController, reaction_name: String) -> bool:
	var key = str(target.get_instance_id()) + "_" + reaction_name
	if not reaction_cooldowns.has(key):
		return true
	var now = Time.get_ticks_msec() / 1000.0
	var last_time = reaction_cooldowns[key]
	return (now - last_time) >= 0.35

func record_reaction(target: EnemyController, reaction_name: String) -> void:
	var key = str(target.get_instance_id()) + "_" + reaction_name
	reaction_cooldowns[key] = Time.get_ticks_msec() / 1000.0

func get_effects_container() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root
