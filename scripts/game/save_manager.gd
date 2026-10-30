class_name SaveManager
extends RefCounted

const CURRENT_VERSION = 2
const SAVE_PATH = "user://save_data.json"
const TMP_SAVE_PATH = "user://save_data.json.tmp"

static func get_default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
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
		"completed_atlas_goals": []
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

	# Version handling & migration (v1 -> v2)
	var v = raw.get("version", 1)
	clean["version"] = CURRENT_VERSION

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

	# Graphic Settings
	clean["screen_shake"] = bool(raw.get("screen_shake", true))
	clean["damage_numbers"] = bool(raw.get("damage_numbers", true))
	clean["vsync"] = bool(raw.get("vsync", true))

	# Language Settings
	var lang = raw.get("language", "ru")
	clean["language"] = str(lang).to_lower() if str(lang).to_lower() in ["ru", "en"] else "ru"
	var user_sel_lang = raw.get("user_selected_language", "")
	clean["user_selected_language"] = str(user_sel_lang).to_lower() if str(user_sel_lang).to_lower() in ["ru", "en"] else ""

	# Tutorial flag
	clean["tutorial_completed"] = bool(raw.get("tutorial_completed", false))

	# Arenas
	if raw.has("unlocked_arenas") and raw["unlocked_arenas"] is Array:
		var arenas: Array = []
		for a in raw["unlocked_arenas"]:
			if a is String and not arenas.has(a):
				arenas.append(a)
		if not arenas.has("forgotten_forest"):
			arenas.append("forgotten_forest")
		clean["unlocked_arenas"] = arenas

	# Arena Stats
	if raw.has("arena_stats") and raw["arena_stats"] is Dictionary:
		var a_stats = clean["arena_stats"]
		for k in raw["arena_stats"].keys():
			if raw["arena_stats"][k] is Dictionary:
				a_stats[k] = raw["arena_stats"][k]
		clean["arena_stats"] = a_stats

	# Run History (limit to 10 latest)
	if raw.has("run_history") and raw["run_history"] is Array:
		var history: Array = []
		for item in raw["run_history"]:
			if item is Dictionary:
				history.append(item)
		if history.size() > 10:
			history = history.slice(history.size() - 10)
		clean["run_history"] = history

	# Horizontal discoveries & meta unlocks
	var array_keys = [
		"discovered_spells",
		"discovered_synergies",
		"discovered_evolutions",
		"discovered_artifacts",
		"completed_atlas_goals"
	]
	for k in array_keys:
		if raw.has(k) and raw[k] is Array:
			var clean_items: Array = []
			for item in raw[k]:
				if item is String and not item.is_empty():
					if not clean_items.has(item):
						clean_items.append(item)
			clean[k] = clean_items

	# Ensure base spell is always discovered
	if not clean["discovered_spells"].has("magic_bolt"):
		clean["discovered_spells"].append("magic_bolt")

	return clean

static func save_custom_data(data: Dictionary) -> bool:
	var sanitized = sanitize_data(data)
	var tmp_file = FileAccess.open(TMP_SAVE_PATH, FileAccess.WRITE)
	if not tmp_file:
		return false

	tmp_file.store_string(JSON.stringify(sanitized, "  "))
	tmp_file.close()

	var dir = DirAccess.open("user://")
	if dir:
		if FileAccess.file_exists(SAVE_PATH):
			dir.remove(SAVE_PATH.replace("user://", ""))
		var err = dir.rename(TMP_SAVE_PATH.replace("user://", ""), SAVE_PATH.replace("user://", ""))
		return err == OK
	return false

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
	cur_a["kills"] = int(cur_a.get("kills", 0)) + kills
	if defeated_boss:
		cur_a["wins"] = int(cur_a.get("wins", 0)) + 1
	if time_survived > float(cur_a.get("best_time", 0.0)):
		cur_a["best_time"] = time_survived
	a_stats[arena_id] = cur_a
	data["arena_stats"] = a_stats

	# Record in run history
	if not run_summary.is_empty():
		var history: Array = data.get("run_history", [])
		history.push_front(run_summary)
		if history.size() > 10:
			history = history.slice(0, 10)
		data["run_history"] = history

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
	if cloud_raw.is_empty():
		return local_data

	var cloud_data = sanitize_data(cloud_raw)
	var merged = get_default_data()
	merged["version"] = CURRENT_VERSION

	# Max numerical metrics
	merged["total_runs"] = max(local_data.get("total_runs", 0), cloud_data.get("total_runs", 0))
	merged["best_survival_time"] = max(local_data.get("best_survival_time", 0.0), cloud_data.get("best_survival_time", 0.0))
	merged["bosses_defeated"] = max(local_data.get("bosses_defeated", 0), cloud_data.get("bosses_defeated", 0))
	merged["total_kills"] = max(local_data.get("total_kills", 0), cloud_data.get("total_kills", 0))

	# Settings: prioritize local if set, else cloud
	merged["fx_intensity"] = local_data.get("fx_intensity", cloud_data.get("fx_intensity", "standard"))
	merged["master_volume"] = local_data.get("master_volume", cloud_data.get("master_volume", 1.0))
	merged["sfx_volume"] = local_data.get("sfx_volume", cloud_data.get("sfx_volume", 0.8))
	merged["screen_shake"] = local_data.get("screen_shake", cloud_data.get("screen_shake", true))
	merged["damage_numbers"] = local_data.get("damage_numbers", cloud_data.get("damage_numbers", true))
	merged["vsync"] = local_data.get("vsync", cloud_data.get("vsync", true))
	merged["tutorial_completed"] = local_data.get("tutorial_completed", false) or cloud_data.get("tutorial_completed", false)

	# Language setting: prioritize explicit local user choice, else cloud
	var user_sel = local_data.get("user_selected_language", "")
	if not user_sel.is_empty():
		merged["user_selected_language"] = user_sel
		merged["language"] = user_sel
	elif not str(cloud_data.get("user_selected_language", "")).is_empty():
		merged["user_selected_language"] = cloud_data["user_selected_language"]
		merged["language"] = cloud_data["user_selected_language"]
	else:
		merged["language"] = local_data.get("language", cloud_data.get("language", "ru"))
		merged["user_selected_language"] = ""

	# Union of unlocked arenas
	var arenas: Array = []
	for a in local_data.get("unlocked_arenas", ["forgotten_forest"]):
		if not arenas.has(a): arenas.append(a)
	for a in cloud_data.get("unlocked_arenas", []):
		if not arenas.has(a): arenas.append(a)
	merged["unlocked_arenas"] = arenas

	# Merge arena stats
	var merged_astats: Dictionary = {}
	var all_arena_keys = []
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

	# Union of discoveries & atlas goals
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

	# Merge history (deduplicated by timestamp or survival_time, up to 10 latest)
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

	if base_local_data.is_empty():
		save_custom_data(merged)
	return merged

static func get_setting(key: String, default_value: Variant = null) -> Variant:
	var data = load_data()
	return data.get(key, default_value)

static func set_setting(key: String, value: Variant) -> void:
	var data = load_data()
	data[key] = value
	save_custom_data(data)
