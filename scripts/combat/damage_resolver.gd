class_name DamageResolver
extends RefCounted

const StatusEffects = preload("res://scripts/combat/status_effects.gd")
const CombatEffects = preload("res://scripts/combat/combat_effects.gd")
const DamageContext = preload("res://scripts/combat/damage_context.gd")
const ReactionContext = preload("res://scripts/synergies/reaction_context.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

static func apply_damage(ctx: DamageContext) -> Dictionary:
	var result = {
		"applied": false,
		"damage_dealt": 0.0,
		"killed": false,
		"absorbed": 0.0
	}

	if not ctx or not is_instance_valid(ctx.target):
		return result

	if ctx.target is EnemyController:
		return _apply_enemy_damage(ctx)
	elif ctx.target is PlayerController:
		return _apply_player_damage(ctx)

	return result

static func _apply_enemy_damage(ctx: DamageContext) -> Dictionary:
	var enemy = ctx.target as EnemyController
	var res = {"applied": false, "damage_dealt": 0.0, "killed": false, "absorbed": 0.0}

	if not is_instance_valid(enemy) or enemy.is_dead:
		return res

	var final_dmg = ctx.amount

	# 1. Death Mark Amplification
	var is_marked = enemy.has_status(StatusEffects.STATUS_MARKED)
	if is_marked:
		var amp = enemy.get_meta("death_mark_amp", 0.40)
		final_dmg *= (1.0 + amp)

	# 2. Frost Core artifact vulnerability (+25% damage to slowed/frozen)
	if enemy.has_status(StatusEffects.STATUS_SLOWED):
		var players = enemy.get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			if p and p.has_meta("has_frost_core"):
				final_dmg *= 1.25

	# 3. Execution / Cull check for Marked target
	var max_hp = enemy.stats.max_health if enemy.stats else 30.0
	var execute_ratio = enemy.get_meta("death_mark_execute_ratio", 0.0)
	var would_execute = false
	if is_marked and execute_ratio > 0.0:
		var projected_ratio = (enemy.current_health - final_dmg) / max(1.0, max_hp)
		if projected_ratio > 0.0 and projected_ratio <= execute_ratio:
			final_dmg = enemy.current_health
			would_execute = true

	# 4. Actual damage dealt calculation (capped at current health)
	var actual_dmg = min(final_dmg, enemy.current_health)
	enemy.current_health = max(0.0, enemy.current_health - final_dmg)
	var is_killed = enemy.current_health <= 0.0

	enemy.damage_taken.emit(actual_dmg)
	res["applied"] = true
	res["damage_dealt"] = actual_dmg
	res["killed"] = is_killed

	var container = enemy.get_tree().current_scene if enemy.get_tree().current_scene else enemy.get_tree().root

	# 5. Visual hit feedback
	if enemy.visual_node:
		if enemy.visual_node.has_method("trigger_hit_flash"):
			enemy.visual_node.trigger_hit_flash()
		if enemy.visual_node.has_method("update_health_display"):
			enemy.visual_node.update_health_display(enemy.current_health, max_hp)

	# 6. Damage numbers & popups
	var num_col = Color(1.0, 0.92, 0.5, 1.0)
	if would_execute:
		num_col = Color(1.0, 0.15, 0.25, 1.0)
		CombatEffects.spawn_text_popup(container, enemy.global_position, "КАЗНЬ!", Color(1.0, 0.2, 0.35, 1.0), true)
	elif is_marked:
		num_col = Color(1.0, 0.3, 0.4, 1.0)
	elif ctx.has_tag("fire"):
		num_col = Color(1.0, 0.55, 0.1, 1.0)
	elif ctx.has_tag("ice") or ctx.has_tag("chill"):
		num_col = Color(0.3, 0.85, 1.0, 1.0)
	elif ctx.has_tag("lightning"):
		num_col = Color(0.45, 0.9, 1.0, 1.0)
	elif ctx.has_tag("arcane"):
		num_col = Color(0.85, 0.5, 1.0, 1.0)

	CombatEffects.spawn_damage_number(container, enemy.global_position, actual_dmg, num_col)
	CombatEffects.spawn_impact_sparks(container, enemy.global_position)

	# 7. Telemetry recording
	_record_telemetry_damage(ctx.source_id, actual_dmg, enemy, ctx.has_tag("dot"))

	# 8. Process on-hit reactions BEFORE death handling (Lethal hit processing)
	# Target still exists and had the statuses at the moment of the hit!
	if ctx.allow_reactions and not ctx.tags.is_empty():
		var engines = enemy.get_tree().get_nodes_in_group("synergy_engine")
		if engines.size() > 0:
			var react_ctx = ReactionContext.new(
				ctx.source,
				enemy,
				ctx.tags,
				enemy.global_position,
				actual_dmg,
				ctx.depth,
				ctx.allow_reactions,
				ctx.excluded_targets,
				ctx.cascade_id,
				ctx.is_secondary
			)
			engines[0].on_hit_landed(react_ctx)

	# 9. Handle death if killed - EnemyController.die() handles death reactions once
	if is_killed and not enemy.is_dead:
		enemy.die()

	return res

static func _apply_player_damage(ctx: DamageContext) -> Dictionary:
	var player = ctx.target as PlayerController
	var res = {"applied": false, "damage_dealt": 0.0, "killed": false, "absorbed": 0.0}

	if not is_instance_valid(player) or not player.is_alive or player.invulnerable_timer > 0.0:
		return res

	var incoming = ctx.amount
	var absorbed = 0.0

	# 1. Check Magic Barrier absorption
	var barrier = player.get_node_or_null("MagicBarrier")
	if not barrier and player.has_node("Abilities"):
		barrier = player.get_node("Abilities").get_node_or_null("MagicBarrier")
		if not barrier and player.get_node("Abilities").has_method("get_ability"):
			barrier = player.get_node("Abilities").get_ability("magic_barrier")

	if barrier and barrier.has_method("absorb_damage"):
		absorbed = barrier.absorb_damage(incoming)
		incoming = max(0.0, incoming - absorbed)
		res["absorbed"] = absorbed
		_record_barrier_absorbed(absorbed)

	# 2. If barrier absorbed 100% of the damage
	if incoming <= 0.0:
		res["applied"] = true
		var container = player.get_tree().current_scene if player.get_tree().current_scene else player.get_tree().root
		CombatEffects.spawn_shockwave(container, player.global_position, 55.0, Color(0.3, 0.75, 1.0, 0.7))
		return res

	# Overheal armor resistance (temporary buff from Font of Life)
	if player.has_meta("font_overheal_armor"):
		var armor_bonus = clampf(player.get_meta("font_overheal_armor", 0.0), 0.0, 0.50)
		incoming *= max(0.0, 1.0 - armor_bonus)

	# 3. Apply remaining damage to player health
	player.current_health = max(0.0, player.current_health - incoming)
	player.invulnerable_timer = player.stats.invulnerability_duration if player.stats else 0.85

	player.trigger_camera_shake(7.0, 0.22)

	if player.visual_node and player.visual_node.has_method("trigger_hit_flash"):
		player.visual_node.trigger_hit_flash()

	# Obsidian heart defensive pulse on health damage
	if player.has_meta("has_obsidian_heart"):
		player.trigger_obsidian_pulse()

	player.health_changed.emit(player.current_health, player.stats.max_health if player.stats else 100.0)
	res["applied"] = true
	res["damage_dealt"] = incoming

	# 4. Check death or revives
	if player.current_health <= 0.0:
		if player.phoenix_revives_remaining > 0:
			player.phoenix_revives_remaining -= 1
			player.current_health = (player.stats.max_health if player.stats else 100.0) * 0.5
			player.invulnerable_timer = 2.0
			player.trigger_camera_shake(12.0, 0.35)
			var container = player.get_tree().current_scene if player.get_tree().current_scene else player.get_tree().root
			CombatEffects.spawn_shockwave(container, player.global_position, 220.0, Color(1.0, 0.45, 0.1, 0.95))
			CombatEffects.spawn_text_popup(container, player.global_position, "ВОЗРОЖДЕНИЕ ФЕНИКСА!", Color(1.0, 0.7, 0.2, 1.0))
			player.health_changed.emit(player.current_health, player.stats.max_health if player.stats else 100.0)
			return res

		res["killed"] = true
		player.die()

	return res

static func _record_telemetry_damage(source_id: String, amount: float, enemy: EnemyController = null, is_dot: bool = false) -> void:
	var stats = RunStats.active_stats
	if not stats and Engine.get_main_loop() and Engine.get_main_loop().root:
		var root = Engine.get_main_loop().root
		var gf = root.get_node_or_null("GameFlow")
		if gf and "run_stats" in gf and gf.run_stats:
			stats = gf.run_stats
		elif root.get_node_or_null("Main") and "run_stats" in root.get_node_or_null("Main"):
			stats = root.get_node_or_null("Main").run_stats

	if stats:
		stats.record_hit(source_id, amount, enemy, is_dot)

static func _record_barrier_absorbed(amount: float) -> void:
	var stats = RunStats.active_stats
	if not stats and Engine.get_main_loop() and Engine.get_main_loop().root:
		var root = Engine.get_main_loop().root
		var gf = root.get_node_or_null("GameFlow")
		if gf and "run_stats" in gf and gf.run_stats:
			stats = gf.run_stats
		elif root.get_node_or_null("Main") and "run_stats" in root.get_node_or_null("Main"):
			stats = root.get_node_or_null("Main").run_stats

	if stats and stats.has_method("record_damage_absorbed"):
		stats.record_damage_absorbed(amount)
