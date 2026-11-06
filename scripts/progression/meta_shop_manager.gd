class_name MetaShopManager
extends RefCounted

const SaveManager = preload("res://scripts/game/save_manager.gd")
const MetaShopConfig = preload("res://scripts/progression/meta_shop_config.gd")

static func get_upgrade_level(upgrade_id: String) -> int:
	return SaveManager.get_upgrade_level(upgrade_id)

static func can_purchase(upgrade_id: String) -> bool:
	if not MetaShopConfig.UPGRADES.has(upgrade_id):
		return false

	var current_lvl = get_upgrade_level(upgrade_id)
	var max_lvl = int(MetaShopConfig.UPGRADES[upgrade_id].get("max_level", 5))
	if current_lvl >= max_lvl:
		return false

	var cost = MetaShopConfig.get_upgrade_cost(upgrade_id, current_lvl)
	return SaveManager.get_gold() >= cost

static func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false

	var current_lvl = get_upgrade_level(upgrade_id)
	var cost = MetaShopConfig.get_upgrade_cost(upgrade_id, current_lvl)

	if not SaveManager.spend_gold(cost):
		return false

	SaveManager.set_upgrade_level(upgrade_id, current_lvl + 1)
	return true

static func apply_shop_upgrades_to_player(player: Node2D) -> void:
	if not player or not ("stats" in player) or not player.stats:
		return

	var stats: PlayerStats = player.stats
	var upgrades = SaveManager.get_shop_upgrades()

	for u_id in upgrades.keys():
		var lvl = int(upgrades[u_id])
		if lvl <= 0:
			continue

		match u_id:
			"vitality_health":
				stats.max_health += float(lvl * 10)
				if "current_health" in player:
					player.current_health = stats.max_health
			"vitality_regen":
				stats.hp_regen += float(lvl) * 0.4
			"defense_armor":
				stats.damage_reduction += float(lvl) * 0.03
			"defense_barrier":
				stats.barrier_durability_mult += float(lvl) * 0.15
			"magic_power":
				stats.spell_power_mult += float(lvl) * 0.04
			"magic_cooldown":
				stats.cooldown_mult = max(0.25, stats.cooldown_mult - float(lvl) * 0.03)
			"magic_area":
				stats.spell_area_mult += float(lvl) * 0.05
			"synergy_potency":
				stats.synergy_damage_mult += float(lvl) * 0.06
			"synergy_energy":
				stats.synergy_energy_mult += float(lvl) * 0.10
			"treasure_greed":
				stats.gold_drop_chance_bonus += float(lvl) * 0.03
			"treasure_bounty":
				stats.gold_reward_mult += float(lvl) * 0.20

	if player.has_method("update_modifiers_meta"):
		player.update_modifiers_meta()
	if player.has_signal("health_changed") and "current_health" in player:
		player.health_changed.emit(player.current_health, stats.max_health)
