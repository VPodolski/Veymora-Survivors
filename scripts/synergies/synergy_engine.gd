class_name SynergyEngine
extends Node

signal reaction_triggered(reaction_name: String, position: Vector2)

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

	# 4. Steam Rift (Fire on Slowed)
	if context.has_tag("fire") and target.has_status(StatusEffects.STATUS_SLOWED):
		if can_trigger_reaction(target, "steam_rift"):
			trigger_steam_rift(context)

	# 5. Thermal Conflagration (Fire on Charged)
	if context.has_tag("fire") and target.has_status(StatusEffects.STATUS_CHARGED):
		if can_trigger_reaction(target, "thermal_conflagration"):
			trigger_thermal_conflagration(context)

func trigger_arcane_resonance(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "resonance")
	reaction_triggered.emit("resonance", pos)

	# 1. Contact flash
	CombatEffects.spawn_hit_flash(container, pos, Color(0.8, 0.4, 1.0, 1.0), 16.0)
	# 2. Expanding arcane ring
	CombatEffects.spawn_ring(container, pos, 8.0, 85.0, Color(0.65, 0.35, 1.0, 0.95), 0.26, 2.5)
	# 3. Soft inner shockwave
	CombatEffects.spawn_shockwave(container, pos, 80.0, Color(0.5, 0.25, 0.9, 0.5), 0.24)
	# 4. Highlight target
	CombatEffects.spawn_target_highlight(target, Color(0.7, 0.4, 1.0, 0.95), 24.0)
	# 5. Priority text popup
	CombatEffects.spawn_text_popup(container, pos, "РЕЗОНАНС!", Color(0.85, 0.5, 1.0, 1.0), true)

	# AoE burst damage to nearby enemies + connecting arcane impulse lines
	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 85.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy != target:
				CombatEffects.spawn_lightning_arc(container, pos, enemy.global_position, Color(0.7, 0.45, 1.0, 0.8), 1.5)
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
	reaction_triggered.emit("frost_shatter", pos)

	# 1. Contact frost flash
	CombatEffects.spawn_hit_flash(container, pos, Color(0.4, 0.95, 1.0, 1.0), 14.0)
	# 2. Geometric crystalline shards explosion (visual)
	CombatEffects.spawn_geometric_shards(container, pos, Color(0.3, 0.9, 1.0, 1.0), 6, 190.0)
	# 3. Shockwave with sharp border
	CombatEffects.spawn_shockwave(container, pos, 65.0, Color(0.2, 0.85, 1.0, 0.85), 0.22)
	# 4. Priority text popup
	CombatEffects.spawn_text_popup(container, pos, "РАСКОЛ!", Color(0.35, 0.95, 1.0, 1.0), true)

	# 3 frost shards fly out
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

	record_reaction(target, "lightning_chain")
	reaction_triggered.emit("lightning_chain", pos)
	CombatEffects.spawn_hit_flash(container, pos, Color.WHITE, 12.0)
	CombatEffects.spawn_text_popup(container, pos, "РАЗРЯД!", Color(0.45, 0.85, 1.0, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 150.0)
	var chained_count = 0
	var cur_pos = pos
	var current_width = 2.4

	for enemy in nearby:
		if enemy != target and is_instance_valid(enemy) and not enemy.is_dead:
			CombatEffects.spawn_lightning_arc(container, cur_pos, enemy.global_position, Color(0.45, 0.85, 1.0, 0.95), current_width)
			CombatEffects.spawn_hit_flash(container, enemy.global_position, Color(0.6, 0.9, 1.0), 9.0)
			current_width = max(1.2, current_width * 0.75)
			cur_pos = enemy.global_position

			var sub_context = ReactionContext.new(self, enemy, ["lightning"], enemy.global_position, 14.0, context.depth + 1)
			enemy.take_damage(14.0)
			enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)
			chained_count += 1
			if chained_count >= 2:
				break

func trigger_steam_rift(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_SLOWED)
	record_reaction(target, "steam_rift")
	reaction_triggered.emit("steam_rift", pos)

	# 1. Thermal evaporation flash
	CombatEffects.spawn_hit_flash(container, pos, Color(1.0, 0.95, 0.85, 1.0), 16.0)
	# 2. Expanding steam ring (semi-transparent soft vapor, no harsh fire)
	CombatEffects.spawn_ring(container, pos, 8.0, 90.0, Color(0.75, 0.9, 1.0, 0.65), 0.35, 3.5)
	# 3. Soft vapor shockwave
	CombatEffects.spawn_shockwave(container, pos, 85.0, Color(0.8, 0.92, 1.0, 0.4), 0.32)
	# 4. Priority text popup
	CombatEffects.spawn_text_popup(container, pos, "ПАРОВОЙ РАЗЛОМ!", Color(0.8, 0.92, 1.0, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(20.0)
			enemy.apply_status(StatusEffects.STATUS_SLOWED, 2.5)

func trigger_thermal_conflagration(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "thermal_conflagration")
	reaction_triggered.emit("thermal_conflagration", pos)

	# 1. Brilliant plasma flash
	CombatEffects.spawn_hit_flash(container, pos, Color(1.0, 0.9, 0.4, 1.0), 22.0)
	# 2. Double ring (inner fire amber, outer electric cyan)
	CombatEffects.spawn_ring(container, pos, 6.0, 70.0, Color(1.0, 0.45, 0.1, 0.9), 0.28, 3.0)
	CombatEffects.spawn_ring(container, pos, 12.0, 100.0, Color(0.3, 0.8, 1.0, 0.85), 0.32, 2.0)
	# 3. Plasma sparks burst
	CombatEffects.spawn_impact_sparks(container, pos, Color(1.0, 0.55, 0.1, 1.0), 8)
	# 4. Priority text popup
	CombatEffects.spawn_text_popup(container, pos, "ПЕРЕГРУЗКА!", Color(1.0, 0.5, 0.1, 1.0), true)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 95.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(38.0)
			enemy.apply_status(StatusEffects.STATUS_BURNING, 3.5)

func trigger_unstable_explosion(pos: Vector2) -> void:
	var container = get_effects_container()
	reaction_triggered.emit("unstable_explosion", pos)

	# 1. Contracting void ring (implosion before explosion)
	CombatEffects.spawn_ring(container, pos, 35.0, 4.0, Color(0.7, 0.2, 1.0, 0.9), 0.12, 2.2)
	# 2. Geometric rift fracture (purple/void tear)
	CombatEffects.spawn_rift_fracture(container, pos, 42.0, Color(0.85, 0.25, 1.0, 0.95))
	# 3. Expanding perimeter shockwave matching exact 90px damage radius
	CombatEffects.spawn_shockwave(container, pos, 90.0, Color(0.85, 0.25, 1.0, 0.85), 0.26)
	# 4. Priority text popup
	CombatEffects.spawn_text_popup(container, pos, "РАЗЛОМ!", Color(0.9, 0.35, 1.0, 1.0), true)

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, 90.0)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(25.0)

func can_trigger_reaction(target: EnemyController, reaction_name: String) -> bool:
	if not is_instance_valid(target):
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

	# Auto-clean on enemy tree_exited
	if not target.is_connected("tree_exited", Callable(self, "_on_target_tree_exited")):
		target.tree_exited.connect(Callable(self, "_on_target_tree_exited").bind(target_id))

func clear_target_cooldowns(target: EnemyController) -> void:
	if not target:
		return
	_clean_id_cooldowns(target.get_instance_id())

func _on_target_tree_exited(target_id: int) -> void:
	_clean_id_cooldowns(target_id)

func _clean_id_cooldowns(target_id: int) -> void:
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

func get_effects_container() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root
