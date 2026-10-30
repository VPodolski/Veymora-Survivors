class_name SynergyEngine
extends Node

const SynergyRegistry = preload("res://scripts/synergies/synergy_registry.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const SteamCloudArea = preload("res://scripts/combat/steam_cloud_area.gd")

signal reaction_triggered(reaction_name: String, position: Vector2)
signal reaction_activated(reaction_name: String, position: Vector2, targets_count: int)
signal reaction_damage_dealt(reaction_name: String, damage: float)
signal reaction_damage_detailed(reaction_name: String, damage: float, is_kill: bool, is_dot: bool)

const MAX_REACTION_DEPTH = 2

var reaction_cooldowns: Dictionary = {} # "target_id_reaction_name": float_time
var registered_cleanups: Dictionary = {} # target_id: true
var cascade_hit_targets: Dictionary = {} # "cascade_id_target_id": true

func _ready() -> void:
	add_to_group("synergy_engine")

func on_hit_landed(context: ReactionContext) -> void:
	if not context or not context.allow_reactions or not is_instance_valid(context.target) or context.target.is_dead:
		return

	if context.depth >= MAX_REACTION_DEPTH:
		return

	var target = context.target

	# 1. Fire reactions (Rule of Elemental Precedence: Thermal Conflagration takes priority over Steam Rift)
	if context.has_tag("fire"):
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "thermal_conflagration"):
				trigger_thermal_conflagration(context)
				return
		elif target.has_status(StatusEffects.STATUS_SLOWED):
			if can_trigger_reaction(target, "steam_rift"):
				trigger_steam_rift(context)
				return

	# 2. Lightning reactions
	if context.has_tag("lightning"):
		# Check Runic Conductor (Player standing in active Rune Zone)
		if is_player_in_rune_zone() and can_trigger_reaction(target, "runic_conductor"):
			trigger_runic_conductor(context)

		# Cryogenic Shock (Lightning on Slowed target)
		if target.has_status(StatusEffects.STATUS_SLOWED) and not target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "cryogenic_shock"):
				trigger_cryogenic_shock(context)
				return

		# Lightning Chain (Lightning on Charged target triggers chain; uncharged receives charge only)
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "lightning_chain"):
				trigger_lightning_chain(context)
				return
		else:
			target.apply_status(StatusEffects.STATUS_CHARGED, 4.0)

	# 3. Arcane reactions
	if context.has_tag("arcane"):
		# Spatial Collapse (Arcane on Unstable target)
		if target.has_status(StatusEffects.STATUS_UNSTABLE):
			if can_trigger_reaction(target, "spatial_collapse"):
				trigger_spatial_collapse(context)
				return

		# Arcane Resonance (Arcane on Charged target)
		if target.has_status(StatusEffects.STATUS_CHARGED):
			if can_trigger_reaction(target, "resonance"):
				trigger_arcane_resonance(context)
				return

	# 4. Frost Shatter (Melee/Orbit or physical impact on Slowed target; Ice Storm zone tick is explicitly excluded)
	var can_shatter_impact = context.has_tag("melee") or context.has_tag("orbit") or context.has_tag("ice_impact") or (context.has_tag("ice") and not context.has_tag("ice_zone"))
	if can_shatter_impact and target.has_status(StatusEffects.STATUS_SLOWED):
		if can_trigger_reaction(target, "frost_shatter"):
			trigger_frost_shatter(context)
			return

# --- 1. Arcane Resonance ---
func trigger_arcane_resonance(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "resonance")

	var defn = SynergyRegistry.get_definition("resonance")
	var radius = defn.area_radius if defn else 85.0
	var dmg = defn.base_damage if defn else 18.0

	# Find secondary targets in exact 85.0 px radius
	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var secondary_targets: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy != target:
			secondary_targets.append(enemy)

	# Visuals matching exactly 85.0 px damage area with connecting arcs
	CombatEffects.spawn_resonance_visuals(container, pos, radius, secondary_targets)
	CombatEffects.spawn_target_highlight(target, Color(0.7, 0.4, 1.0, 0.95), 24.0)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("resonance")

	reaction_triggered.emit("resonance", pos)
	reaction_activated.emit("resonance", pos, secondary_targets.size() + 1)

	# Secondary targets take damage and receive charge status
	for enemy in secondary_targets:
		var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["arcane_impulse"], false)
		apply_reaction_damage(enemy, dmg, "resonance", sub_ctx)
		if is_instance_valid(enemy) and not enemy.is_dead:
			if not enemy.has_status(StatusEffects.STATUS_CHARGED):
				enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)

# --- 2. Frost Shatter ---
func trigger_frost_shatter(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	# Shatter destroys the ice crust (consumes slowed status)
	target.remove_status(StatusEffects.STATUS_SLOWED)
	record_reaction(target, "frost_shatter")

	var player_node = get_tree().get_first_node_in_group("player")
	var has_frost_core = player_node and player_node.has_meta("has_frost_core")

	var shard_count = 5 if has_frost_core else 3
	var shard_speed = 230.0 if has_frost_core else 190.0
	var defn = SynergyRegistry.get_definition("frost_shatter")
	var shard_damage = defn.base_damage if defn else 14.0

	# Visual shards match the exact number of physical projectiles launched
	CombatEffects.spawn_frost_shatter_visuals(container, pos, shard_count, shard_speed)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("frost_shatter")

	reaction_triggered.emit("frost_shatter", pos)
	reaction_activated.emit("frost_shatter", pos, shard_count)

	# Launch aligned physical crystalline projectile shards
	var base_angle = randf() * TAU
	for i in range(shard_count):
		var angle = base_angle + float(i) * (TAU / float(shard_count))
		var dir = Vector2(cos(angle), sin(angle))
		var proj_scene = preload("res://scenes/combat/projectile.tscn")
		var proj = proj_scene.instantiate() as Projectile
		proj.faction = Projectile.Faction.PLAYER
		proj.global_position = pos + dir * 10.0
		proj.direction = dir
		proj.damage = shard_damage
		proj.speed = shard_speed
		proj.lifetime = 0.7 if has_frost_core else 0.55
		proj.projectile_color = Color(0.3, 0.9, 1.0, 1.0)
		proj.tags = ["ice", "shard", "reaction_frost_shatter"]
		container.add_child(proj)

# --- 3. Lightning Chain ---
func trigger_lightning_chain(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "lightning_chain")

	var player_node = get_tree().get_first_node_in_group("player")
	var has_rod = player_node and player_node.get_meta("has_lightning_rod", false)

	var max_hops = 3 if has_rod else 2
	var search_radius = 180.0 if has_rod else 150.0
	var defn = SynergyRegistry.get_definition("lightning_chain")
	var dmg = defn.base_damage if defn else 14.0

	var excluded = context.excluded_targets
	if not excluded.has(target):
		excluded.append(target)

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, search_radius)
	var chained_positions: Array = []
	var hit_count = 0

	for enemy in nearby:
		if hit_count >= max_hops:
			break
		if not is_instance_valid(enemy) or enemy.is_dead or excluded.has(enemy):
			continue

		excluded.append(enemy)
		chained_positions.append(enemy.global_position)
		hit_count += 1

		var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["lightning_impulse"], false)
		apply_reaction_damage(enemy, dmg, "lightning_chain", sub_ctx)
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)

	CombatEffects.spawn_lightning_chain_visuals(container, pos, chained_positions)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("lightning_chain")

	reaction_triggered.emit("lightning_chain", pos)
	reaction_activated.emit("lightning_chain", pos, hit_count)

# --- 4. Steam Rift ---
func trigger_steam_rift(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_SLOWED)
	record_reaction(target, "steam_rift")

	var defn = SynergyRegistry.get_definition("steam_rift")
	var radius = defn.area_radius if defn else 90.0
	var blast_dmg = defn.base_damage if defn else 20.0

	CombatEffects.spawn_steam_rift_visuals(container, pos, radius)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("steam_rift")

	# Spawn lingering steam cloud zone (lingers 2.8s, dealing DoT and condensation slow)
	var cloud = SteamCloudArea.new()
	cloud.global_position = pos
	cloud.radius = radius
	container.add_child(cloud)

	# Initial vapor shock blast
	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			var sub_ctx = context.create_sub_context(enemy, enemy.global_position, blast_dmg, ["steam_blast"], false)
			apply_reaction_damage(enemy, blast_dmg, "steam_rift", sub_ctx)
			if is_instance_valid(enemy) and not enemy.is_dead:
				if enemy != target:
					enemy.apply_status(StatusEffects.STATUS_SLOWED, 2.5)

	reaction_triggered.emit("steam_rift", pos)
	reaction_activated.emit("steam_rift", pos, hit_count)

# --- 5. Thermal Conflagration ---
func trigger_thermal_conflagration(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_CHARGED)
	record_reaction(target, "thermal_conflagration")

	var player_node = get_tree().get_first_node_in_group("player")
	var has_heart = player_node and player_node.has_meta("has_obsidian_heart")

	var defn = SynergyRegistry.get_definition("thermal_conflagration")
	var base_dmg = defn.base_damage if defn else 38.0
	var dmg = base_dmg * (1.35 if has_heart else 1.0)
	var radius = (defn.area_radius if defn else 95.0) * (1.2 if has_heart else 1.0)
	var burn_duration = 5.0 if has_heart else 3.5

	CombatEffects.spawn_thermal_conflagration_visuals(container, pos, radius, has_heart)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("thermal_conflagration")

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["plasma_blast"], false)
			apply_reaction_damage(enemy, dmg, "thermal_conflagration", sub_ctx)
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.apply_status(StatusEffects.STATUS_BURNING, burn_duration)
				enemy.set_meta("burning_source", "thermal_conflagration")

	reaction_triggered.emit("thermal_conflagration", pos)
	reaction_activated.emit("thermal_conflagration", pos, hit_count)

# --- 6. Unstable Explosion ---
func trigger_unstable_explosion(pos: Vector2) -> void:
	var container = get_effects_container()
	var player_node = get_tree().get_first_node_in_group("player")
	var has_compass = player_node and player_node.has_meta("has_rift_compass")

	var defn = SynergyRegistry.get_definition("unstable_explosion")
	var radius = (defn.area_radius if defn else 90.0) * (1.35 if has_compass else 1.0)
	var dmg = defn.base_damage if defn else 25.0

	CombatEffects.spawn_unstable_explosion_visuals(container, pos, radius)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("unstable_explosion")

	var enemies = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			apply_reaction_damage(enemy, dmg, "unstable_explosion", null)

	reaction_triggered.emit("unstable_explosion", pos)
	reaction_activated.emit("unstable_explosion", pos, hit_count)

# --- 7. Soul Harvest ---
func trigger_soul_harvest(pos: Vector2, burst_dmg: float = 35.0) -> void:
	var container = get_effects_container()
	var defn = SynergyRegistry.get_definition("soul_harvest")
	var radius = defn.area_radius if defn else 90.0

	CombatEffects.spawn_soul_harvest_visuals(container, pos, radius)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("soul_harvest")

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			apply_reaction_damage(enemy, burst_dmg, "soul_harvest", null)

	reaction_triggered.emit("soul_harvest", pos)
	reaction_activated.emit("soul_harvest", pos, hit_count)

# --- 8. Spatial Collapse (P2) ---
func trigger_spatial_collapse(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_UNSTABLE)
	record_reaction(target, "spatial_collapse")

	var defn = SynergyRegistry.get_definition("spatial_collapse")
	var radius = defn.area_radius if defn else 110.0
	var dmg = defn.base_damage if defn else 30.0

	CombatEffects.spawn_spatial_collapse_visuals(container, pos, radius)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("spatial_collapse")

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			# Pull enemies toward epicenter (clamped knockback, skip boss)
			if not (enemy is BossController):
				var pull_dir = (pos - enemy.global_position).normalized()
				enemy.knockback_velocity = pull_dir * 320.0
			var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["spatial_implosion"], false)
			apply_reaction_damage(enemy, dmg, "spatial_collapse", sub_ctx)

	reaction_triggered.emit("spatial_collapse", pos)
	reaction_activated.emit("spatial_collapse", pos, hit_count)

# --- 9. Cryogenic Shock (P2) ---
func trigger_cryogenic_shock(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()

	target.remove_status(StatusEffects.STATUS_SLOWED)
	record_reaction(target, "cryogenic_shock")

	var defn = SynergyRegistry.get_definition("cryogenic_shock")
	var radius = defn.area_radius if defn else 130.0
	var dmg = defn.base_damage if defn else 24.0

	CombatEffects.spawn_hit_flash(container, pos, Color(0.4, 0.9, 1.0, 1.0), 16.0)
	CombatEffects.spawn_ring(container, pos, 6.0, radius, Color(0.3, 0.85, 1.0, 0.9), 0.24, 2.4)
	CombatEffects.spawn_text_popup(container, pos, "КРИО-ШОК!", Color(0.4, 0.85, 1.0, 1.0), true)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("lightning_chain")

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy != target:
			hit_count += 1
			CombatEffects.spawn_lightning_arc(container, pos, enemy.global_position, Color(0.35, 0.85, 1.0, 0.9), 1.8)
			var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["cryo_shock"], false)
			apply_reaction_damage(enemy, dmg, "cryogenic_shock", sub_ctx)
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.apply_status(StatusEffects.STATUS_SLOWED, 2.0)

	reaction_triggered.emit("cryogenic_shock", pos)
	reaction_activated.emit("cryogenic_shock", pos, hit_count)

# --- 10. Runic Conductor (P2) ---
func trigger_runic_conductor(context: ReactionContext) -> void:
	var target = context.target
	var pos = context.hit_position
	var container = get_effects_container()
	var player_node = get_tree().get_first_node_in_group("player")
	var p_pos = player_node.global_position if player_node else pos

	record_reaction(target, "runic_conductor")

	var defn = SynergyRegistry.get_definition("runic_conductor")
	var radius = defn.area_radius if defn else 140.0
	var dmg = defn.base_damage if defn else 20.0

	CombatEffects.spawn_ring(container, p_pos, 12.0, radius, Color(0.45, 0.9, 1.0, 0.9), 0.28, 3.0)
	CombatEffects.spawn_lightning_arc(container, p_pos, pos, Color(0.8, 0.95, 1.0, 1.0), 3.2)
	CombatEffects.spawn_text_popup(container, p_pos, "ПРОВОДНИК!", Color(0.5, 0.9, 1.0, 1.0), true)

	if AudioManager.instance:
		AudioManager.instance.play_synergy("lightning_chain")

	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), p_pos, radius)
	var hit_count = 0
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead:
			hit_count += 1
			var sub_ctx = context.create_sub_context(enemy, enemy.global_position, dmg, ["runic_discharge"], false)
			apply_reaction_damage(enemy, dmg, "runic_conductor", sub_ctx)
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.apply_status(StatusEffects.STATUS_CHARGED, 3.0)

	reaction_triggered.emit("runic_conductor", pos)
	reaction_activated.emit("runic_conductor", pos, hit_count)

# --- 11. Chain of Doom (P2) ---
func trigger_chain_of_doom(pos: Vector2, hops_remaining: int = 2) -> void:
	if hops_remaining <= 0:
		return
	var container = get_effects_container()
	var nearby = TargetSelector.find_enemies_in_radius(get_tree(), pos, 120.0)
	for enemy in nearby:
		if is_instance_valid(enemy) and not enemy.is_dead and not enemy.has_status(StatusEffects.STATUS_MARKED):
			enemy.apply_status(StatusEffects.STATUS_MARKED, 5.0)
			enemy.set_meta("chain_of_doom_enabled", true)
			enemy.set_meta("chain_of_doom_hops", hops_remaining - 1)
			CombatEffects.spawn_lightning_arc(container, pos, enemy.global_position, Color(0.95, 0.15, 0.25, 0.9), 2.0)
			CombatEffects.spawn_text_popup(container, enemy.global_position, "ЦЕПЬ ПОГИБЕЛИ!", Color(1.0, 0.25, 0.35, 1.0))
			reaction_triggered.emit("chain_of_doom", enemy.global_position)
			reaction_activated.emit("chain_of_doom", enemy.global_position, 1)
			break

func on_enemy_death(target: EnemyController) -> void:
	if not is_instance_valid(target):
		return

	var pos = target.global_position

	if target.has_status(StatusEffects.STATUS_MARKED):
		var burst_dmg = target.get_meta("death_mark_burst_dmg", 35.0)
		trigger_soul_harvest(pos, burst_dmg)
		# Chain of Doom check (only if enabled on marked target)
		if target.get_meta("chain_of_doom_enabled", false):
			trigger_chain_of_doom(pos, target.get_meta("chain_of_doom_hops", 2))

	if target.has_status(StatusEffects.STATUS_UNSTABLE):
		trigger_unstable_explosion(pos)

func apply_reaction_damage(target: EnemyController, amount: float, reaction_id: String, context: ReactionContext = null, is_dot: bool = false) -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false

	var target_id = target.get_instance_id()

	# Cascade protection: prevent duplicate damage on the same target in the same cascade
	if context:
		var cascade_key = context.cascade_id + "_" + str(target_id)
		if cascade_hit_targets.has(cascade_key):
			return false
		cascade_hit_targets[cascade_key] = true
		if not context.excluded_targets.has(target):
			context.excluded_targets.append(target)

	var hp_before = target.current_health
	target.take_damage(amount)
	var was_killed = (target.is_dead or target.current_health <= 0.0)

	# Emit backward-compatible 2-param signal and rich detailed signal
	reaction_damage_dealt.emit(reaction_id, amount)
	reaction_damage_detailed.emit(reaction_id, amount, was_killed, is_dot)
	return true

func is_player_in_rune_zone() -> bool:
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return false
	return player_node.has_meta("in_rune_zone") and bool(player_node.get_meta("in_rune_zone"))

func can_trigger_reaction(target: EnemyController, reaction_name: String) -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	var key = str(target.get_instance_id()) + "_" + reaction_name
	if not reaction_cooldowns.has(key):
		return true
	var now = Time.get_ticks_msec() / 1000.0
	var last_time = reaction_cooldowns[key]
	var defn = SynergyRegistry.get_definition(reaction_name)
	var cd = defn.cooldown if defn else 0.35
	return (now - last_time) >= cd

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

	# Clean stale cascade records
	if cascade_hit_targets.size() > 200:
		cascade_hit_targets.clear()

func reset() -> void:
	reaction_cooldowns.clear()
	registered_cleanups.clear()
	cascade_hit_targets.clear()

func get_effects_container() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root
