class_name SynergyEngine
extends Node

signal reaction_triggered(reaction_name: String, position: Vector2)
signal reaction_damage_dealt(reaction_name: String, damage: float)

const MAX_REACTION_DEPTH = 2

var reaction_cooldowns: Dictionary = {} # "target_id_reaction_name": float_time
var registered_cleanups: Dictionary = {} # target_id: true

func _ready() -> void:
	add_to_group("synergy_engine")

func on_hit_landed(context: ReactionContext) -> void:
	if not context or not context.allow_reactions or not is_instance_valid(context.target) or context.target.is_dead:
		return

	if context.depth >= MAX_REACTION_DEPTH:
		return

	var target = context.target

	# 1. Arcane Resonance (Arcane attacks on Charged target only)
	if context.has_tag("arcane"):
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "resonance"):
				trigger_arcane_resonance(context)

	# 2. Frost Shatter (Ice/Melee/Orbit on Slowed target)
	if (context.has_tag("melee") or context.has_tag("orbit") or context.has_tag("ice")) and target.has_status(StatusEffects.STATUS_SLOWED):
		if can_trigger_reaction(target, "frost_shatter"):
			trigger_frost_shatter(context)

	# 3. Fire reactions (Rule of Elemental Precedence: Thermal Conflagration takes priority over Steam Rift)
	if context.has_tag("fire"):
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "thermal_conflagration"):
				trigger_thermal_conflagration(context)
		elif target.has_status(StatusEffects.STATUS_SLOWED):
			if can_trigger_reaction(target, "steam_rift"):
				trigger_steam_rift(context)

	# 4. Lightning Chain (Lightning on Charged target triggers chain; on uncharged target applies charge only)
	if context.has_tag("lightning"):
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "lightning_chain"):
				trigger_lightning_chain(context)
		else:
			target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

func trigger_arcane_resonance(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "resonance")
	reaction_triggered.emit("resonance", pos)

	# Visuals matching exactly 85.0 px damage area
	CombatEffects.spawn_hit_flash(container, pos, Color(0.8, 0.4, 1.0, 1.0), 16.0)
	CombatEffects.spawn_ring(container, pos, 8.0, 85.0, Color(0.65, 0.35, 1.0, 0.95), 0.26, 2.5)
	CombatEffects.spawn_shockwave(container, pos, 85.0, Color(0.5, 0.25, 0.9, 0.5), 0.24)
	CombatEffects.spawn_target_highlight(target, Color(0.7, 0.4, 1.0, 0.95), 24.0)
	CombatEffects.spawn_text_popup(container, pos, "РЕЗОНАНС!", Color(0.85, 0.5, 1.0, 1.0), true)

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 85.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy != target:
				CombatEffects.spawn_lightning_arc(container, pos, enemy.global_position, Color(0.7, 0.45, 1.0, 0.8), 1.5)
			var sub_context = ReactionContext.new(self, enemy, ["arcane_impulse"], enemy.global_position, 18.0, context.depth + 1, false)
			enemy.take_damage(18.0)
			reaction_damage_dealt.emit("resonance", 18.0)
			if is_instance_valid(enemy) and not enemy.is_dead:
				if enemy != target and not enemy.has_status(StatusEffects.STATUS_CHARGED):
					enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)

func trigger_frost_shatter(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	record_reaction(target, "frost_shatter")
	reaction_triggered.emit("frost_shatter", pos)

	CombatEffects.spawn_hit_flash(container, pos, Color(0.4, 0.95, 1.0, 1.0), 14.0)
	CombatEffects.spawn_geometric_shards(container, pos, Color(0.3, 0.9, 1.0, 1.0), 6, 190.0)
	CombatEffects.spawn_shockwave(container, pos, 65.0, Color(0.2, 0.85, 1.0, 0.85), 0.22)
	CombatEffects.spawn_text_popup(container, pos, "РАСКОЛ!", Color(0.35, 0.95, 1.0, 1.0), true)

	var base_angle = randf() * TAU
	for i in range(3):
		var angle = base_angle + float(i) * (TAU / 3.0)
		var dir = Vector2(cos(angle), sin(angle))
		var proj_scene = preload("res://scenes/combat/projectile.tscn")
		var proj = proj_scene.instantiate() as Projectile
		proj.faction = Projectile.Faction.PLAYER
		proj.global_position = pos + dir * 10.0
		proj.direction = dir
		proj.damage = 14.0
		proj.projectile_color = Color(0.3, 0.9, 1.0, 1.0)
		container.add_child(proj)

func trigger_lightning_chain(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "lightning_chain")
	reaction_triggered.emit("lightning_chain", pos)

	CombatEffects.spawn_hit_flash(container, pos, Color.WHITE, 14.0)
	CombatEffects.spawn_ring(container, pos, 6.0, 75.0, Color(0.4, 0.85, 1.0, 0.9), 0.22, 2.0)
	CombatEffects.spawn_text_popup(container, pos, "РАЗРЯД!", Color(0.45, 0.85, 1.0, 1.0), true)

	var excluded = context.excluded_targets
	if not excluded.has(target):
		excluded.append(target)

	var max_hops = 2
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.get_meta("has_lightning_rod", false):
		max_hops += 1

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 150.0)
	var chained_count = 0
	var cur_pos = pos
	var current_width = 2.4

	for enemy in nearby:
		if chained_count >= max_hops:
			break
		if not is_instance_valid(enemy) or enemy.is_dead or excluded.has(enemy):
			continue

		excluded.append(enemy)
		CombatEffects.spawn_lightning_arc(container, cur_pos, enemy.global_position, Color(0.45, 0.85, 1.0, 0.95), current_width)
		CombatEffects.spawn_hit_flash(container, enemy.global_position, Color(0.6, 0.9, 1.0), 9.0)
		current_width = max(1.2, current_width * 0.75)
		cur_pos = enemy.global_position

		var sub_context = ReactionContext.new(self, enemy, ["lightning_impulse"], enemy.global_position, 14.0, context.depth + 1, false, excluded)
		enemy.take_damage(14.0)
		reaction_damage_dealt.emit("lightning_chain", 14.0)
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)
		chained_count += 1

func trigger_steam_rift(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_SLOWED)
	record_reaction(target, "steam_rift")
	reaction_triggered.emit("steam_rift", pos)

	# Visuals matching exactly 90.0 px damage area
	CombatEffects.spawn_hit_flash(container, pos, Color(1.0, 0.95, 0.85, 1.0), 16.0)
	CombatEffects.spawn_ring(container, pos, 8.0, 90.0, Color(0.75, 0.9, 1.0, 0.65), 0.35, 3.5)
	CombatEffects.spawn_shockwave(container, pos, 90.0, Color(0.8, 0.92, 1.0, 0.4), 0.32)
	CombatEffects.spawn_text_popup(container, pos, "ПАРОВОЙ РАЗЛОМ!", Color(0.8, 0.92, 1.0, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(20.0)
			reaction_damage_dealt.emit("steam_rift", 20.0)
			if is_instance_valid(enemy) and not enemy.is_dead:
				if enemy != target:
					enemy.apply_status(StatusEffects.STATUS_SLOWED, 2.5)

func trigger_thermal_conflagration(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "thermal_conflagration")
	reaction_triggered.emit("thermal_conflagration", pos)

	# Visuals matching exactly 95.0 px damage area
	CombatEffects.spawn_hit_flash(container, pos, Color(1.0, 0.9, 0.4, 1.0), 22.0)
	CombatEffects.spawn_ring(container, pos, 6.0, 70.0, Color(1.0, 0.45, 0.1, 0.9), 0.28, 3.0)
	CombatEffects.spawn_ring(container, pos, 12.0, 95.0, Color(0.3, 0.8, 1.0, 0.85), 0.32, 2.0)
	CombatEffects.spawn_impact_sparks(container, pos, Color(1.0, 0.55, 0.1, 1.0), 8)
	CombatEffects.spawn_text_popup(container, pos, "ПЕРЕГРУЗКА!", Color(1.0, 0.5, 0.1, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 95.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(38.0)
			reaction_damage_dealt.emit("thermal_conflagration", 38.0)
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.apply_status(StatusEffects.STATUS_BURNING, 3.5)

func trigger_unstable_explosion(pos: Vector2) -> void:
	var container = get_effects_container()
	reaction_triggered.emit("unstable_explosion", pos)

	CombatEffects.spawn_ring(container, pos, 35.0, 4.0, Color(0.7, 0.2, 1.0, 0.9), 0.12, 2.2)
	CombatEffects.spawn_rift_fracture(container, pos, 42.0, Color(0.85, 0.25, 1.0, 0.95))
	CombatEffects.spawn_shockwave(container, pos, 90.0, Color(0.85, 0.25, 1.0, 0.85), 0.26)
	CombatEffects.spawn_text_popup(container, pos, "РАЗЛОМ!", Color(0.9, 0.35, 1.0, 1.0), true)

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(25.0)
			reaction_damage_dealt.emit("unstable_explosion", 25.0)

func trigger_soul_harvest(pos: Vector2, burst_dmg: float = 35.0) -> void:
	var container = get_effects_container()
	reaction_triggered.emit("soul_harvest", pos)

	CombatEffects.spawn_rift_fracture(container, pos, 40.0, Color(0.95, 0.1, 0.25, 0.95))
	CombatEffects.spawn_shockwave(container, pos, 90.0, Color(0.95, 0.1, 0.25, 0.85))
	CombatEffects.spawn_text_popup(container, pos, "ЖАТВА ДУШ!", Color(1.0, 0.3, 0.4, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(burst_dmg)
			reaction_damage_dealt.emit("soul_harvest", burst_dmg)

func on_enemy_death(target: EnemyController) -> void:
	if not is_instance_valid(target):
		return

	if target.has_status(StatusEffects.STATUS_MARKED):
		var burst_dmg = target.get_meta("death_mark_burst_dmg", 35.0)
		trigger_soul_harvest(target.global_position, burst_dmg)

	if target.has_status(StatusEffects.STATUS_UNSTABLE):
		trigger_unstable_explosion(target.global_position)

func can_trigger_reaction(target: EnemyController, reaction_name: String) -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	var key = str(target.get_instance_id()) + "_" + reaction_name
	if not reaction_cooldowns.has(key):
		return true
	var now = Time.get_ticks_msec() / 1000.0
	var last_time = reaction_cooldowns[key]
	return (now - last_time) >= 0.35

func record_reaction(target: EnemyController, reaction_name: String) -> void:
	if not is_instance_valid(target):
		return
	var target_id = target.get_instance_id()
	var key = str(target_id) + "_" + reaction_name
	reaction_cooldowns[key] = Time.get_ticks_msec() / 1000.0

	if not registered_cleanups.has(target_id):
		registered_cleanups[target_id] = true
		target.tree_exited.connect(func(): _clean_id_cooldowns(target_id))

func clear_target_cooldowns(target: EnemyController) -> void:
	if not target:
		return
	_clean_id_cooldowns(target.get_instance_id())

func _clean_id_cooldowns(target_id: int) -> void:
	registered_cleanups.erase(target_id)
	var prefix = str(target_id) + "_"
	var keys_to_remove: Array = []
	for k in reaction_cooldowns.keys():
		if k.begins_with(prefix):
			keys_to_remove.append(k)
	for k in keys_to_remove:
		reaction_cooldowns.erase(k)

func prune_stale_cooldowns(max_age_seconds: float = 2.0) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array = []
	for k in reaction_cooldowns.keys():
		if (now - reaction_cooldowns[k]) > max_age_seconds:
			keys_to_remove.append(k)
	for k in keys_to_remove:
		reaction_cooldowns.erase(k)

func reset() -> void:
	reaction_cooldowns.clear()
	registered_cleanups.clear()

func get_effects_container() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root
