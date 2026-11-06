class_name CharacterProgressionManager
extends RefCounted

const SaveManager = preload("res://scripts/game/save_manager.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

# Character registry definitions
const CHARACTERS = {
	"wizard": {
		"id": "wizard",
		"name": "Маг Разлома",
		"name_en": "Rift Wizard",
		"title": "Хранитель Первородной Магии",
		"title_en": "Keeper of Primal Weaving",
		"description": "Властитель чародейской энергии и тайных плетений.",
		"description_en": "Master of raw arcane power and celestial weavers.",
		"starting_spell_id": "magic_bolt",
		"starting_spell_name": "Чародейская стрела",
		"starting_spell_name_en": "Arcane Bolt",
		"damage_bonus_per_level": 0.01 # +1% base damage per level above 1
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

static func calc_total_xp_for_level_and_residual(level: int, residual_xp: int) -> int:
	var total = max(0, residual_xp)
	for l in range(1, max(1, level)):
		total += get_required_xp(l)
	return total

static func calc_level_and_residual_from_total(total_xp: int) -> Dictionary:
	var lvl = 1
	var rem = max(0, total_xp)
	var req = get_required_xp(lvl)
	while rem >= req:
		rem -= req
		lvl += 1
		req = get_required_xp(lvl)
	return {
		"level": lvl,
		"xp": rem,
		"total_xp": max(0, total_xp),
		"required_xp": req
	}

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
	var safe_char_id = char_id if CHARACTERS.has(char_id) else "wizard"
	var data = SaveManager.get_character_data(safe_char_id)
	var old_level = int(data.get("level", 1))
	var old_residual = int(data.get("xp", 0))

	# Compute total XP accurately
	var old_total_xp = int(data.get("total_xp", 0))
	if old_total_xp <= 0 and (old_level > 1 or old_residual > 0):
		old_total_xp = calc_total_xp_for_level_and_residual(old_level, old_residual)

	var new_total_xp = old_total_xp + max(0, xp_amount)
	var reconstructed = calc_level_and_residual_from_total(new_total_xp)
	var new_level = reconstructed.level
	var new_residual = reconstructed.xp

	SaveManager.save_character_data(safe_char_id, new_level, new_residual, new_total_xp)

	return {
		"char_id": safe_char_id,
		"old_level": old_level,
		"new_level": new_level,
		"gained_xp": xp_amount,
		"current_xp": new_residual,
		"total_xp": new_total_xp,
		"required_xp": reconstructed.required_xp,
		"leveled_up": new_level > old_level
	}

static func get_character_bonuses(char_id: String = "wizard") -> Dictionary:
	var safe_char_id = char_id if CHARACTERS.has(char_id) else "wizard"
	var data = SaveManager.get_character_data(safe_char_id)
	var lvl = int(data.get("level", 1))
	var defn = get_character_def(safe_char_id)

	var bonus_levels = max(0, lvl - 1)
	# +1% base damage to starting spell per level above 1
	var pct_per_lvl = float(defn.get("damage_bonus_per_level", 0.01))
	var damage_mult_bonus = float(bonus_levels) * pct_per_lvl

	return {
		"level": lvl,
		"char_id": safe_char_id,
		"starting_spell_id": defn.get("starting_spell_id", "magic_bolt"),
		"damage_mult_bonus": damage_mult_bonus, # e.g. 0.09 for level 10 (+9%)
		"damage_percent_text": "+%d%%" % int(round(damage_mult_bonus * 100.0))
	}

static func apply_character_progression_to_player(player: Node2D, char_id: String = "wizard") -> void:
	if not player:
		return

	var safe_char_id = char_id if CHARACTERS.has(char_id) else "wizard"
	var bonuses = get_character_bonuses(safe_char_id)

	player.set_meta("character_id", safe_char_id)
	player.set_meta("character_level", bonuses.level)
	player.set_meta("char_starting_spell_id", bonuses.starting_spell_id)
	player.set_meta("char_spell_damage_mult_bonus", bonuses.damage_mult_bonus)
