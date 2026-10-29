class_name SaveManager
extends RefCounted

const SAVE_PATH = "user://save_data.json"

static func load_data() -> Dictionary:
	var default_data = {
		"total_runs": 0,
		"best_survival_time": 0.0,
		"bosses_defeated": 0,
		"total_kills": 0
	}

	if not FileAccess.file_exists(SAVE_PATH):
		return default_data

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return default_data

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK and json.data is Dictionary:
		return json.data

	return default_data

static func record_run(time_survived: float, kills: int, defeated_boss: bool) -> Dictionary:
	var data = load_data()
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	data["total_kills"] = int(data.get("total_kills", 0)) + kills

	if defeated_boss:
		data["bosses_defeated"] = int(data.get("bosses_defeated", 0)) + 1

	var best = float(data.get("best_survival_time", 0.0))
	if time_survived > best:
		data["best_survival_time"] = time_survived

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

	return data

