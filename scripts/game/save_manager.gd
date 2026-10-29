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
		"total_kills": 0
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

	return clean

static func record_run(time_survived: float, kills: int, defeated_boss: bool) -> Dictionary:
	var data = load_data()
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	data["total_kills"] = int(data.get("total_kills", 0)) + max(0, kills)

	if defeated_boss:
		data["bosses_defeated"] = int(data.get("bosses_defeated", 0)) + 1

	var best = float(data.get("best_survival_time", 0.0))
	if time_survived > best:
		data["best_survival_time"] = max(0.0, time_survived)

	# Atomic write: write to temp file first, then overwrite target
	var tmp_file = FileAccess.open(TMP_SAVE_PATH, FileAccess.WRITE)
	if tmp_file:
		tmp_file.store_string(JSON.stringify(data, "  "))
		tmp_file.close()

		var dir = DirAccess.open("user://")
		if dir:
			if FileAccess.file_exists(SAVE_PATH):
				dir.remove(SAVE_PATH.replace("user://", ""))
			dir.rename(TMP_SAVE_PATH.replace("user://", ""), SAVE_PATH.replace("user://", ""))

	return data
