class_name CharacterProgressionManager
extends RefCounted

const SaveManager = preload("res://scripts/game/save_manager.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

# Character registry definitions
const CHARACTERS = {
	"wizard": {
		"id": "wizard",
		"name": "Маг Разлома",
		"title": "Хранитель Первородной Магии",
		"description": "Властитель чародейской энергии и тайных плетений.",
		"starting_spell_id": "magic_bolt",
		"starting_spell_name": "Чародейская стрела",
		"damage_per_level": 2.5,
		"speed_per_level": 20.0
	}
}

static func get_character_def(char_id: String = "wizard") -> Dictionary:
	if CHARACTERS.has(char_id):
		return CHARACTERS[char_id]
	return CHARACTERS["wizard"]

static func get_required_xp(level: int) -> int:
	var safe_lvl = max(1, level)
	# Smooth scaling curve: L1: 100, L2: 273, L3: 494, L4: 752, L5: 1041...
	return int(round(100.0 * pow(float(safe_lvl), 1.45)))

static func calculate_run_character_xp(run_stats: RunStats) -> int:
	if not run_stats:
		return 0

	var earned_xp = 0
	# Kills give 1 XP each
	earned_xp += run_stats.total_kills * 1

	# Chests give 25 XP each
	var chests = run_stats.chests_opened if "chests_opened" in run_stats else run_stats.artifacts_collected
	earned_xp += chests * 25

	# Defeating boss gives 150 XP
	if run_stats.defeated_boss or run_stats.boss_kills > 0:
		earned_xp += 150

	# Survival time gives 0.2 XP per second
	earned_xp += int(run_stats.survival_time * 0.2)

	# Victory / completing arena bonus gives 200 XP
	if ("is_victory" in run_stats and run_stats.is_victory) or run_stats.defeated_boss:
		earned_xp += 200

	return max(10, earned_xp)

static func add_character_xp(char_id: String, xp_amount: int) -> Dictionary:
	var data = SaveManager.get_character_data(char_id)
	var current_level = int(data.get("level", 1))
	var current_xp = int(data.get("xp", 0))
	var old_level = current_level

	if xp_amount > 0:
		current_xp += xp_amount

		var req_xp = get_required_xp(current_level)
		while current_xp >= req_xp:
			current_xp -= req_xp
			current_level += 1
			req_xp = get_required_xp(current_level)

		SaveManager.save_character_data(char_id, current_level, current_xp)

	return {
		"char_id": char_id,
		"old_level": old_level,
		"new_level": current_level,
		"gained_xp": xp_amount,
		"current_xp": current_xp,
		"required_xp": get_required_xp(current_level),
		"leveled_up": current_level > old_level
	}

static func get_character_bonuses(char_id: String = "wizard") -> Dictionary:
	var data = SaveManager.get_character_data(char_id)
	var lvl = int(data.get("level", 1))
	var defn = get_character_def(char_id)

	var bonus_levels = max(0, lvl - 1)
	var dmg_bonus = float(bonus_levels) * float(defn.get("damage_per_level", 2.5))
	var spd_bonus = float(bonus_levels) * float(defn.get("speed_per_level", 20.0))

	return {
		"level": lvl,
		"damage_bonus": dmg_bonus,
		"speed_bonus": spd_bonus
	}

static func apply_character_progression_to_player(player: Node2D, char_id: String = "wizard") -> void:
	if not player:
		return

	var bonuses = get_character_bonuses(char_id)
	player.set_meta("character_id", char_id)
	player.set_meta("character_level", bonuses.level)
	player.set_meta("char_spell_damage_bonus", bonuses.damage_bonus)
	player.set_meta("char_projectile_speed_bonus", bonuses.speed_bonus)

