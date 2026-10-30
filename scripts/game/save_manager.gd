class_name SaveManager
extends RefCounted

const CURRENT_VERSION = 1
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

	# Version handling & backwards compatibility
	var v = raw.get("version", 1)
	clean["version"] = int(v) if (v is int or v is float) else CURRENT_VERSION

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

	# Settings
	var fx = raw.get("fx_intensity", "standard")
	clean["fx_intensity"] = str(fx) if fx in ["standard", "reduced"] else "standard"

	var m_vol = raw.get("master_volume", 1.0)
	if m_vol is int or m_vol is float:
		clean["master_volume"] = clampf(float(m_vol), 0.0, 1.0)

	var s_vol = raw.get("sfx_volume", 0.8)
	if s_vol is int or s_vol is float:
		clean["sfx_volume"] = clampf(float(s_vol), 0.0, 1.0)

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

static func record_run(time_survived: float, kills: int, defeated_boss: bool) -> Dictionary:
	var data = load_data()
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	data["total_kills"] = int(data.get("total_kills", 0)) + max(0, kills)

	if defeated_boss:
		data["bosses_defeated"] = int(data.get("bosses_defeated", 0)) + 1

	var best = float(data.get("best_survival_time", 0.0))
	if time_survived > best:
		data["best_survival_time"] = max(0.0, time_survived)

	save_custom_data(data)
	return data

static func get_setting(key: String, default_value: Variant = null) -> Variant:
	var data = load_data()
	return data.get(key, default_value)

static func set_setting(key: String, value: Variant) -> void:
	var data = load_data()
	data[key] = value
	save_custom_data(data)
