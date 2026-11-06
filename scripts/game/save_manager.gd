class_name SaveManager
extends RefCounted

const CURRENT_VERSION = 3
const SAVE_PATH = "user://save_data.json"
const TMP_SAVE_PATH = "user://save_data.json.tmp"

static func get_default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"save_revision": 1,
		"total_runs": 0,
		"best_survival_time": 0.0,
		"bosses_defeated": 0,
		"total_kills": 0,
		"fx_intensity": "standard",
		"master_volume": 1.0,
		"sfx_volume": 0.8,
		"screen_shake": true,
		"damage_numbers": true,
		"vsync": true,
		"language": "ru",
		"user_selected_language": "",
		"unlocked_arenas": ["forgotten_forest", "frost_necropolis"],
		"arena_stats": {
			"forgotten_forest": {"runs": 0, "wins": 0, "best_time": 0.0, "kills": 0},
			"frost_necropolis": {"runs": 0, "wins": 0, "best_time": 0.0, "kills": 0}
		},
		"run_history": [],
		"tutorial_completed": false,
		"discovered_spells": ["magic_bolt"],
		"discovered_synergies": [],
		"discovered_evolutions": [],
		"discovered_artifacts": [],
		"completed_atlas_goals": [],
		"gold": 0,
		"lifetime_gold_earned": 0,
		"lifetime_gold_spent": 0,
		"processed_run_ids": [],
		"selected_character": "wizard",
		"characters": {
			"wizard": {
				"level": 1,
				"xp": 0,
				"total_xp": 0
			}
		},
		"shop_upgrades": {}
	}

static func load_data() -> Dictionary:
	var default_data = get_default_data()

	if not FileAccess.file_exists(SAVE_PATH):
		return default_data

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return default_data

	var json_str = file.get_as_text().strip_edges()
	file.close()

	if json_str.is_empty():
		return default_data

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return default_data

	return sanitize_data(json.data)

static func sanitize_data(raw: Dictionary) -> Dictionary:
	var clean = get_default_data()

	# Version handling & migration
	clean["version"] = CURRENT_VERSION
	var rev = raw.get("save_revision", 1)
	if (rev is int or rev is float) and rev >= 1:
		clean["save_revision"] = int(rev)

	# Total runs
	var runs = raw.get("total_runs", null)
	if (runs is int or runs is float) and runs >= 0:
		clean["total_runs"] = int(runs)

	# Best survival time
	var best_time = raw.get("best_survival_time", null)
	if (best_time is int or best_time is float) and best_time >= 0.0:
		clean["best_survival_time"] = float(best_time)

	# Bosses defeated
	var bosses = raw.get("bosses_defeated", null)
	if (bosses is int or bosses is float) and bosses >= 0:
		clean["bosses_defeated"] = int(bosses)

	# Total kills
	var kills = raw.get("total_kills", null)
	if (kills is int or kills is float) and kills >= 0:
		clean["total_kills"] = int(kills)

	# Audio & FX Settings
	var fx = raw.get("fx_intensity", "standard")
	clean["fx_intensity"] = str(fx) if fx in ["standard", "reduced"] else "standard"

	var m_vol = raw.get("master_volume", 1.0)
	if m_vol is int or m_vol is float:
		clean["master_volume"] = clampf(float(m_vol), 0.0, 1.0)

	var s_vol = raw.get("sfx_volume", 0.8)
	if s_vol is int or s_vol is float:
		clean["sfx_volume"] = clampf(float(s_vol), 0.0, 1.0)

	var shake = raw.get("screen_shake", true)
	if shake is bool:
		clean["screen_shake"] = shake

	var dmg_num = raw.get("damage_numbers", true)
	if dmg_num is bool:
		clean["damage_numbers"] = dmg_num

	var vsync = raw.get("vsync", true)
	if vsync is bool:
		clean["vsync"] = vsync

	var lang = raw.get("language", "ru")
	if lang in ["ru", "en"]:
		clean["language"] = str(lang)

	var u_lang = raw.get("user_selected_language", "")
	if u_lang is String:
		clean["user_selected_language"] = u_lang

	# Unlocked arenas
	if raw.has("unlocked_arenas") and raw["unlocked_arenas"] is Array:
		var valid_arenas: Array = []
		for a in raw["unlocked_arenas"]:
			if a is String and not valid_arenas.has(a):
				valid_arenas.append(a)
		if not valid_arenas.has("forgotten_forest"):
			valid_arenas.append("forgotten_forest")
		if not valid_arenas.has("frost_necropolis"):
			valid_arenas.append("frost_necropolis")
		clean["unlocked_arenas"] = valid_arenas

	# Arena stats
	if raw.has("arena_stats") and raw["arena_stats"] is Dictionary:
		var astats = clean["arena_stats"]
		for k in raw["arena_stats"].keys():
			var entry = raw["arena_stats"][k]
			if entry is Dictionary:
				astats[str(k)] = {
					"runs": max(0, int(entry.get("runs", 0))),
					"wins": max(0, int(entry.get("wins", 0))),
					"best_time": max(0.0, float(entry.get("best_time", 0.0))),
					"kills": max(0, int(entry.get("kills", 0)))
				}
		clean["arena_stats"] = astats

	# Run history
	if raw.has("run_history") and raw["run_history"] is Array:
		var history: Array = []
		for h in raw["run_history"]:
			if h is Dictionary:
				history.append(h)
		if history.size() > 10:
			history = history.slice(0, 10)
		clean["run_history"] = history

	# Discoveries & Atlas goals
	var array_keys = [
		"discovered_spells",
		"discovered_synergies",
		"discovered_evolutions",
		"discovered_artifacts",
		"completed_atlas_goals"
	]
	for ak in array_keys:
		if raw.has(ak) and raw[ak] is Array:
			var arr: Array = []
			for item in raw[ak]:
				if item is String and not arr.has(item):
					arr.append(item)
			clean[ak] = arr

	if not clean["discovered_spells"].has("magic_bolt"):
		clean["discovered_spells"].append("magic_bolt")

	# Permanent shop upgrades
	var upgrades: Dictionary = {}
	if raw.has("shop_upgrades") and raw["shop_upgrades"] is Dictionary:
		for up_id in raw["shop_upgrades"].keys():
			var up_lvl = raw["shop_upgrades"][up_id]
			if (up_lvl is int or up_lvl is float) and up_lvl > 0:
				upgrades[str(up_id)] = int(up_lvl)
	clean["shop_upgrades"] = upgrades

	# Gold & Lifetime Economy
	var g = raw.get("gold", 0)
	var earned = raw.get("lifetime_gold_earned", -1)
	var spent = raw.get("lifetime_gold_spent", -1)

	var safe_gold = int(g) if ((g is int or g is float) and g >= 0) else 0

	# Calculate spent from shop_upgrades if missing
	var shop_cfg = load("res://scripts/progression/meta_shop_config.gd")
	var calculated_spent = shop_cfg.get_total_spent_for_upgrades(upgrades) if shop_cfg else 0

	var safe_spent = int(spent) if ((spent is int or spent is float) and spent >= 0) else calculated_spent
	safe_spent = max(safe_spent, calculated_spent)

	var safe_earned = int(earned) if ((earned is int or earned is float) and earned >= 0) else (safe_gold + safe_spent)
	safe_earned = max(safe_earned, safe_gold + safe_spent)

	clean["gold"] = safe_gold
	clean["lifetime_gold_spent"] = safe_spent
	clean["lifetime_gold_earned"] = safe_earned

	# Processed Run IDs (for reward deduplication)
	var processed_runs: Array = []
	if raw.has("processed_run_ids") and raw["processed_run_ids"] is Array:
		for rid in raw["processed_run_ids"]:
			if rid is String and not rid.is_empty() and not processed_runs.has(rid):
				processed_runs.append(rid)
		if processed_runs.size() > 50:
			processed_runs = processed_runs.slice(processed_runs.size() - 50)
	clean["processed_run_ids"] = processed_runs

	# Selected character
	var sel_char = str(raw.get("selected_character", "wizard"))
	clean["selected_character"] = sel_char if not sel_char.is_empty() else "wizard"

	# Characters permanent progression (unified via total_xp)
	var chars = clean["characters"]
	var char_mgr = load("res://scripts/progression/character_progression_manager.gd")

	if raw.has("characters") and raw["characters"] is Dictionary:
		for char_id in raw["characters"].keys():
			var c_entry = raw["characters"][char_id]
			if c_entry is Dictionary:
				var lvl = max(1, int(c_entry.get("level", 1)))
				var xp = max(0, int(c_entry.get("xp", 0)))
				var tot_xp = int(c_entry.get("total_xp", 0))

				if tot_xp <= 0 and (lvl > 1 or xp > 0) and char_mgr:
					tot_xp = char_mgr.calc_total_xp_for_level_and_residual(lvl, xp)

				if char_mgr and tot_xp > 0:
					var rec = char_mgr.calc_level_and_residual_from_total(tot_xp)
					chars[char_id] = {
						"level": rec.level,
						"xp": rec.xp,
						"total_xp": tot_xp
					}
				else:
					chars[char_id] = {
						"level": lvl,
						"xp": xp,
						"total_xp": tot_xp
					}

	if not chars.has("wizard"):
		chars["wizard"] = {"level": 1, "xp": 0, "total_xp": 0}
	clean["characters"] = chars

	return clean

static func save_data(data: Dictionary) -> bool:
	return save_custom_data(data, true)

static func save_custom_data(data: Dictionary, trigger_cloud_sync: bool = true) -> bool:
	var clean = sanitize_data(data)
	var json_str = JSON.stringify(clean, "\t")

	var tmp_file = FileAccess.open(TMP_SAVE_PATH, FileAccess.WRITE)
	if not tmp_file:
		return false

	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file.close()

	var da = DirAccess.open("user://")
	if not da:
		return false

	if FileAccess.file_exists(SAVE_PATH):
		da.remove(SAVE_PATH)

	var err = da.rename(TMP_SAVE_PATH, SAVE_PATH)
	if err != OK:
		return false

	if trigger_cloud_sync:
		_notify_cloud_save(clean)

	return true

static func _notify_cloud_save(clean_data: Dictionary) -> void:
	var pm = Engine.get_singleton("PlatformManager") if Engine.has_singleton("PlatformManager") else null
	if not pm and Engine.get_main_loop() and Engine.get_main_loop().root:
		pm = Engine.get_main_loop().root.get_node_or_null("PlatformManager")

	if pm and pm.has_method("push_cloud_save"):
		pm.push_cloud_save(clean_data)
	else:
		var yb = Engine.get_main_loop().root.get_node_or_null("YandexGamesBridge") if Engine.get_main_loop() and Engine.get_main_loop().root else null
		if yb and yb.has_method("push_cloud_save"):
			yb.push_cloud_save(clean_data)

static func record_run(time_survived: float, kills: int, defeated_boss: bool, run_summary: Dictionary = {}) -> Dictionary:
	var data = load_data()
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	data["total_kills"] = int(data.get("total_kills", 0)) + max(0, kills)

	if defeated_boss:
		data["bosses_defeated"] = int(data.get("bosses_defeated", 0)) + 1

	var best = float(data.get("best_survival_time", 0.0))
	if time_survived > best:
		data["best_survival_time"] = max(0.0, time_survived)

	# Update per-arena stats
	var arena_id = run_summary.get("arena_id", "forgotten_forest")
	var a_stats = data.get("arena_stats", {})
	if not a_stats.has(arena_id):
		a_stats[arena_id] = {"runs": 0, "wins": 0, "best_time": 0.0, "kills": 0}

	var cur_a = a_stats[arena_id]
	cur_a["runs"] = int(cur_a.get("runs", 0)) + 1
	cur_a["kills"] = int(cur_a.get("kills", 0)) + max(0, kills)
	if defeated_boss:
		cur_a["wins"] = int(cur_a.get("wins", 0)) + 1
	if time_survived > float(cur_a.get("best_time", 0.0)):
		cur_a["best_time"] = time_survived
	a_stats[arena_id] = cur_a
	data["arena_stats"] = a_stats

	# Record run in history
	var history = data.get("run_history", [])
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"survival_time": time_survived,
		"kills": kills,
		"defeated_boss": defeated_boss,
		"arena_id": arena_id,
		"summary": run_summary
	}
	history.push_front(entry)
	if history.size() > 10:
		history = history.slice(0, 10)
	data["run_history"] = history
	data["save_revision"] = int(data.get("save_revision", 0)) + 1

	save_custom_data(data)
	return data

static func is_arena_unlocked(arena_id: String) -> bool:
	var data = load_data()
	var unlocked = data.get("unlocked_arenas", ["forgotten_forest"])
	return unlocked.has(arena_id)

static func unlock_arena(arena_id: String) -> void:
	var data = load_data()
	var unlocked = data.get("unlocked_arenas", ["forgotten_forest"])
	if not unlocked.has(arena_id):
		unlocked.append(arena_id)
		data["unlocked_arenas"] = unlocked
		save_custom_data(data)

static func merge_with_cloud(cloud_raw: Dictionary, base_local_data: Dictionary = {}) -> Dictionary:
	var local_data = base_local_data if not base_local_data.is_empty() else load_data()
	var cloud_data = sanitize_data(cloud_raw)

	var merged = get_default_data()

	# Increment revision for the merged result
	merged["save_revision"] = max(int(local_data.get("save_revision", 1)), int(cloud_data.get("save_revision", 1))) + 1
	merged["version"] = CURRENT_VERSION
	merged["total_runs"] = max(int(local_data.get("total_runs", 0)), int(cloud_data.get("total_runs", 0)))
	merged["best_survival_time"] = max(float(local_data.get("best_survival_time", 0.0)), float(cloud_data.get("best_survival_time", 0.0)))
	merged["bosses_defeated"] = max(int(local_data.get("bosses_defeated", 0)), int(cloud_data.get("bosses_defeated", 0)))
	merged["total_kills"] = max(int(local_data.get("total_kills", 0)), int(cloud_data.get("total_kills", 0)))

	# Local settings take precedence
	merged["fx_intensity"] = local_data.get("fx_intensity", cloud_data.get("fx_intensity", "standard"))
	merged["master_volume"] = local_data.get("master_volume", cloud_data.get("master_volume", 1.0))
	merged["sfx_volume"] = local_data.get("sfx_volume", cloud_data.get("sfx_volume", 0.8))
	merged["screen_shake"] = local_data.get("screen_shake", cloud_data.get("screen_shake", true))
	merged["damage_numbers"] = local_data.get("damage_numbers", cloud_data.get("damage_numbers", true))
	merged["vsync"] = local_data.get("vsync", cloud_data.get("vsync", true))
	merged["language"] = local_data.get("language", cloud_data.get("language", "ru"))
	merged["user_selected_language"] = local_data.get("user_selected_language", cloud_data.get("user_selected_language", ""))
	merged["tutorial_completed"] = bool(local_data.get("tutorial_completed", false)) or bool(cloud_data.get("tutorial_completed", false))

	# Unlocked arenas union
	var arenas: Array = []
	for a in local_data.get("unlocked_arenas", []):
		if not arenas.has(a): arenas.append(a)
	for a in cloud_data.get("unlocked_arenas", []):
		if not arenas.has(a): arenas.append(a)
	if not arenas.has("forgotten_forest"): arenas.append("forgotten_forest")
	if not arenas.has("frost_necropolis"): arenas.append("frost_necropolis")
	merged["unlocked_arenas"] = arenas

	# Arena stats (max values)
	var merged_astats: Dictionary = {}
	var all_arena_keys: Array = []
	for k in local_data.get("arena_stats", {}).keys():
		if not all_arena_keys.has(k): all_arena_keys.append(k)
	for k in cloud_data.get("arena_stats", {}).keys():
		if not all_arena_keys.has(k): all_arena_keys.append(k)

	for k in all_arena_keys:
		var loc_a = local_data.get("arena_stats", {}).get(k, {})
		var cld_a = cloud_data.get("arena_stats", {}).get(k, {})
		merged_astats[k] = {
			"runs": max(loc_a.get("runs", 0), cld_a.get("runs", 0)),
			"wins": max(loc_a.get("wins", 0), cld_a.get("wins", 0)),
			"best_time": max(loc_a.get("best_time", 0.0), cld_a.get("best_time", 0.0)),
			"kills": max(loc_a.get("kills", 0), cld_a.get("kills", 0))
		}
	merged["arena_stats"] = merged_astats

	# Discoveries & Atlas goals
	var array_keys = [
		"discovered_spells",
		"discovered_synergies",
		"discovered_evolutions",
		"discovered_artifacts",
		"completed_atlas_goals"
	]
	for ak in array_keys:
		var union_items: Array = []
		for item in local_data.get(ak, []):
			if not union_items.has(item): union_items.append(item)
		for item in cloud_data.get(ak, []):
			if not union_items.has(item): union_items.append(item)
		merged[ak] = union_items

	# Run history
	var history: Array = []
	for h in local_data.get("run_history", []):
		history.append(h)
	for h in cloud_data.get("run_history", []):
		var is_dup = false
		for existing in history:
			if existing.get("timestamp", 0) == h.get("timestamp", -1) and existing.get("survival_time", 0) == h.get("survival_time", -1):
				is_dup = true
				break
		if not is_dup:
			history.append(h)
	if history.size() > 10:
		history = history.slice(0, 10)
	merged["run_history"] = history

	# Processed Run IDs union (deduplication)
	var merged_p_runs: Array = []
	for rid in local_data.get("processed_run_ids", []):
		if not merged_p_runs.has(rid): merged_p_runs.append(rid)
	for rid in cloud_data.get("processed_run_ids", []):
		if not merged_p_runs.has(rid): merged_p_runs.append(rid)
	if merged_p_runs.size() > 50:
		merged_p_runs = merged_p_runs.slice(merged_p_runs.size() - 50)
	merged["processed_run_ids"] = merged_p_runs

	# Selected character (local choice respected)
	merged["selected_character"] = local_data.get("selected_character", "wizard")

	# Shop upgrades: highest purchased level preserved
	var merged_upgrades: Dictionary = {}
	var all_up_keys: Array = []
	for uk in local_data.get("shop_upgrades", {}).keys():
		if not all_up_keys.has(uk): all_up_keys.append(uk)
	for uk in cloud_data.get("shop_upgrades", {}).keys():
		if not all_up_keys.has(uk): all_up_keys.append(uk)
	for uk in all_up_keys:
		var loc_u = int(local_data.get("shop_upgrades", {}).get(uk, 0))
		var cld_u = int(cloud_data.get("shop_upgrades", {}).get(uk, 0))
		var max_u = max(loc_u, cld_u)
		if max_u > 0:
			merged_upgrades[uk] = max_u
	merged["shop_upgrades"] = merged_upgrades

	# Currency Synchronization Strategy:
	# Spent gold can NEVER be restored!
	var shop_cfg = load("res://scripts/progression/meta_shop_config.gd")
	var upgrades_spent_cost = shop_cfg.get_total_spent_for_upgrades(merged_upgrades) if shop_cfg else 0

	var loc_spent = int(local_data.get("lifetime_gold_spent", 0))
	var cld_spent = int(cloud_data.get("lifetime_gold_spent", 0))
	var merged_spent = max(loc_spent, max(cld_spent, upgrades_spent_cost))

	var loc_earned = int(local_data.get("lifetime_gold_earned", 0))
	var cld_earned = int(cloud_data.get("lifetime_gold_earned", 0))
	var merged_earned = max(loc_earned, max(cld_earned, merged_spent))

	merged["lifetime_gold_spent"] = merged_spent
	merged["lifetime_gold_earned"] = merged_earned
	merged["gold"] = max(0, merged_earned - merged_spent)

	# Characters permanent progression (merged via total_xp)
	var merged_chars: Dictionary = {}
	var all_char_keys: Array = []
	for ck in local_data.get("characters", {}).keys():
		if not all_char_keys.has(ck): all_char_keys.append(ck)
	for ck in cloud_data.get("characters", {}).keys():
		if not all_char_keys.has(ck): all_char_keys.append(ck)
	if not all_char_keys.has("wizard"): all_char_keys.append("wizard")

	var char_mgr = load("res://scripts/progression/character_progression_manager.gd")
	for ck in all_char_keys:
		var loc_c = local_data.get("characters", {}).get(ck, {})
		var cld_c = cloud_data.get("characters", {}).get(ck, {})

		var loc_tot = int(loc_c.get("total_xp", 0))
		if loc_tot <= 0 and char_mgr:
			loc_tot = char_mgr.calc_total_xp_for_level_and_residual(int(loc_c.get("level", 1)), int(loc_c.get("xp", 0)))

		var cld_tot = int(cld_c.get("total_xp", 0))
		if cld_tot <= 0 and char_mgr:
			cld_tot = char_mgr.calc_total_xp_for_level_and_residual(int(cld_c.get("level", 1)), int(cld_c.get("xp", 0)))

		var max_tot = max(loc_tot, cld_tot)
		if char_mgr and max_tot > 0:
			var rec = char_mgr.calc_level_and_residual_from_total(max_tot)
			merged_chars[ck] = {
				"level": rec.level,
				"xp": rec.xp,
				"total_xp": max_tot
			}
		else:
			merged_chars[ck] = {
				"level": max(int(loc_c.get("level", 1)), int(cld_c.get("level", 1))),
				"xp": max(int(loc_c.get("xp", 0)), int(cld_c.get("xp", 0))),
				"total_xp": max_tot
			}
	merged["characters"] = merged_chars

	if base_local_data.is_empty():
		save_custom_data(merged, false)
	return merged

static func get_setting(key: String, default_value: Variant = null) -> Variant:
	var data = load_data()
	return data.get(key, default_value)

static func set_setting(key: String, value: Variant) -> void:
	var data = load_data()
	data[key] = value
	save_custom_data(data)

# --- Economy & Atomic Transactions ---

static func get_gold() -> int:
	var data = load_data()
	return int(data.get("gold", 0))

static func add_gold(amount: int) -> int:
	if amount <= 0:
		return get_gold()
	var data = load_data()
	data["gold"] = int(data.get("gold", 0)) + amount
	data["lifetime_gold_earned"] = int(data.get("lifetime_gold_earned", 0)) + amount
	data["save_revision"] = int(data.get("save_revision", 0)) + 1
	save_custom_data(data)
	return data["gold"]

static func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	var data = load_data()
	var current = int(data.get("gold", 0))
	if current < amount:
		return false
	data["gold"] = current - amount
	data["lifetime_gold_spent"] = int(data.get("lifetime_gold_spent", 0)) + amount
	data["save_revision"] = int(data.get("save_revision", 0)) + 1
	save_custom_data(data)
	return true

static func atomic_purchase_upgrade(upgrade_id: String, cost: int, new_level: int) -> bool:
	var data = load_data()
	var current_gold = int(data.get("gold", 0))
	var upgrades = data.get("shop_upgrades", {})
	var current_level = int(upgrades.get(upgrade_id, 0))

	# Strict atomic validation
	if current_gold < cost:
		return false
	if current_level + 1 != new_level:
		return false

	# Atomic commit
	data["gold"] = current_gold - cost
	data["lifetime_gold_spent"] = int(data.get("lifetime_gold_spent", 0)) + cost
	upgrades[upgrade_id] = new_level
	data["shop_upgrades"] = upgrades
	data["save_revision"] = int(data.get("save_revision", 0)) + 1

	return save_custom_data(data, true)

# --- Run Rewards Deduplication & Claiming ---

static func is_run_processed(run_id: String) -> bool:
	if run_id.is_empty():
		return false
	var data = load_data()
	var runs: Array = data.get("processed_run_ids", [])
	return runs.has(run_id)

static func claim_run_rewards(run_id: String, char_id: String, earned_xp: int, earned_gold: int) -> Dictionary:
	var result = {
		"success": false,
		"already_processed": false,
		"char_id": char_id,
		"gained_xp": earned_xp,
		"gained_gold": earned_gold,
		"new_level": 1,
		"current_xp": 0,
		"leveled_up": false
	}

	if run_id.is_empty():
		return result

	var data = load_data()
	var processed_runs: Array = data.get("processed_run_ids", [])
	if processed_runs.has(run_id):
		result["already_processed"] = true
		var c_data = get_character_data(char_id)
		var c_lvl = int(c_data.get("level", 1))
		result["new_level"] = c_lvl
		result["current_xp"] = int(c_data.get("xp", 0))
		var char_mgr = load("res://scripts/progression/character_progression_manager.gd")
		result["required_xp"] = char_mgr.get_required_xp(c_lvl) if char_mgr else 100
		return result

	# Add run ID to deduplication journal
	processed_runs.append(run_id)
	if processed_runs.size() > 50:
		processed_runs = processed_runs.slice(processed_runs.size() - 50)
	data["processed_run_ids"] = processed_runs

	# Apply Gold
	if earned_gold > 0:
		data["gold"] = int(data.get("gold", 0)) + earned_gold
		data["lifetime_gold_earned"] = int(data.get("lifetime_gold_earned", 0)) + earned_gold

	# Apply Character XP
	var chars = data.get("characters", {})
	var c_entry = chars.get(char_id, {"level": 1, "xp": 0, "total_xp": 0})
	var old_lvl = int(c_entry.get("level", 1))

	var char_mgr = load("res://scripts/progression/character_progression_manager.gd")
	var old_total = int(c_entry.get("total_xp", 0))
	if old_total <= 0 and (old_lvl > 1 or int(c_entry.get("xp", 0)) > 0) and char_mgr:
		old_total = char_mgr.calc_total_xp_for_level_and_residual(old_lvl, int(c_entry.get("xp", 0)))

	var new_total = old_total + max(0, earned_xp)
	var reconstructed = char_mgr.calc_level_and_residual_from_total(new_total) if char_mgr else {"level": old_lvl, "xp": 0}

	c_entry["level"] = reconstructed.level
	c_entry["xp"] = reconstructed.xp
	c_entry["total_xp"] = new_total
	chars[char_id] = c_entry
	data["characters"] = chars

	data["save_revision"] = int(data.get("save_revision", 0)) + 1

	var saved = save_custom_data(data, true)
	if saved:
		result["success"] = true
		result["new_level"] = reconstructed.level
		result["current_xp"] = reconstructed.xp
		result["required_xp"] = reconstructed.required_xp
		result["leveled_up"] = (reconstructed.level > old_lvl)

	return result

# --- Character & Upgrades Accessors ---

static func get_selected_character() -> String:
	var data = load_data()
	return str(data.get("selected_character", "wizard"))

static func set_selected_character(char_id: String) -> void:
	if char_id.is_empty():
		return
	var data = load_data()
	data["selected_character"] = char_id
	save_custom_data(data)

static func get_character_data(char_id: String = "wizard") -> Dictionary:
	var data = load_data()
	var chars = data.get("characters", {})
	if chars.has(char_id):
		return chars[char_id]
	return {"level": 1, "xp": 0, "total_xp": 0}

static func save_character_data(char_id: String, level: int, xp: int, total_xp: int = 0) -> void:
	var data = load_data()
	var chars = data.get("characters", {})

	var char_mgr = load("res://scripts/progression/character_progression_manager.gd")
	var safe_tot = total_xp
	if safe_tot <= 0 and char_mgr:
		safe_tot = char_mgr.calc_total_xp_for_level_and_residual(level, xp)

	chars[char_id] = {
		"level": max(1, level),
		"xp": max(0, xp),
		"total_xp": max(0, safe_tot)
	}
	data["characters"] = chars
	data["save_revision"] = int(data.get("save_revision", 0)) + 1
	save_custom_data(data)

static func get_shop_upgrades() -> Dictionary:
	var data = load_data()
	return data.get("shop_upgrades", {})

static func get_upgrade_level(upgrade_id: String) -> int:
	var upgrades = get_shop_upgrades()
	return int(upgrades.get(upgrade_id, 0))

static func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var data = load_data()
	var upgrades = data.get("shop_upgrades", {})
	if level > 0:
		upgrades[upgrade_id] = level
	else:
		upgrades.erase(upgrade_id)
	data["shop_upgrades"] = upgrades
	data["save_revision"] = int(data.get("save_revision", 0)) + 1
	save_custom_data(data)
