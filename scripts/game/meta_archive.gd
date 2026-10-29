class_name MetaArchive
extends RefCounted

const ATLAS_GOALS = [
	{
		"id": "first_blood",
		"title": "Первая кровь",
		"desc": "Уничтожить хотя бы одного врага Разлома.",
		"reward": "Открывает артефакт [Компас разломов]"
	},
	{
		"id": "first_resonance",
		"title": "Чародейский отклик",
		"desc": "Вызвать боевую реакцию [Чародейский резонанс].",
		"reward": "Открывает заклинание [Грозовой разряд]"
	},
	{
		"id": "first_steam_rift",
		"title": "Огонь и лёд",
		"desc": "Вызвать реакцию [Паровой разлом], поразив огнём замедленного врага.",
		"reward": "Открывает артефакт [Ледяное ядро]"
	},
	{
		"id": "discover_evolution",
		"title": "Высшая трансмутация",
		"desc": "Совершить эволюцию любого заклинания 5-го уровня.",
		"reward": "Открывает артефакт [Громоотвод]"
	},
	{
		"id": "survive_5_min",
		"title": "Стойкий адепт",
		"desc": "Выжить более 5 минут (300 сек) в одном забеге.",
		"reward": "Открывает артефакт [Фолиант учёного]"
	},
	{
		"id": "defeat_colossus",
		"title": "Убийца гигантов",
		"desc": "Одолеть босса [Повелитель Разлома].",
		"reward": "Открывает легендарный артефакт [Перо феникса]"
	}
]

static func record_discovery(category: String, id: String) -> void:
	var data = SaveManager.load_data()
	var key = "discovered_" + category
	var list: Array = data.get(key, [])
	if not list.has(id):
		list.append(id)
		data[key] = list
		SaveManager.save_custom_data(data)

static func check_and_complete_goal(goal_id: String) -> bool:
	var data = SaveManager.load_data()
	var completed: Array = data.get("completed_atlas_goals", [])
	if not completed.has(goal_id):
		completed.append(goal_id)
		data["completed_atlas_goals"] = completed
		SaveManager.save_custom_data(data)
		return true
	return false

static func is_goal_completed(goal_id: String) -> bool:
	var data = SaveManager.load_data()
	var completed: Array = data.get("completed_atlas_goals", [])
	return completed.has(goal_id)

static func get_archive_data() -> Dictionary:
	var data = SaveManager.load_data()
	return {
		"spells": data.get("discovered_spells", ["magic_bolt"]),
		"synergies": data.get("discovered_synergies", []),
		"evolutions": data.get("discovered_evolutions", []),
		"artifacts": data.get("discovered_artifacts", []),
		"completed_goals": data.get("completed_atlas_goals", [])
	}
