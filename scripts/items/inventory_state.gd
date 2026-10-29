class_name InventoryState
extends Node

signal artifact_added(item: ItemDefinition)

@export var max_artifacts: int = 4

var artifacts: Dictionary = {} # id: ItemDefinition
var player_owner: PlayerController = null

static var ALL_ARTIFACTS: Dictionary = {
	"hourglass": {
		"name": "Песочные часы обратного течения",
		"desc": "Снаряды мага пробивают врагов и устремляются назад. Открывает эволюцию Магической стрелы.",
		"color": Color(0.3, 0.9, 1.0, 1.0),
		"tags": ["returning", "piercing", "catalyst"]
	},
	"obsidian_heart": {
		"name": "Обсидиановое сердце",
		"desc": "Потерянное здоровье увеличивает силу магии (до +80%). При ранении выпускает волну отталкивания. Катализатор Огненной сферы.",
		"color": Color(0.9, 0.2, 0.3, 1.0),
		"tags": ["blood_magic", "defense", "catalyst"]
	},
	"rift_compass": {
		"name": "Компас разломов",
		"desc": "Поражённые враги становятся нестабильными и при гибели взрываются пространственным разломом.",
		"color": Color(0.85, 0.35, 1.0, 1.0),
		"tags": ["spatial", "explosive"]
	},
	"frost_core": {
		"name": "Ледяное ядро",
		"desc": "Увеличивает длительность замедления на +50% и урон льдом на +35%. Катализатор эволюции Ледяного шторма.",
		"color": Color(0.2, 0.85, 1.0, 1.0),
		"tags": ["ice", "catalyst", "control"]
	},
	"phoenix_feather": {
		"name": "Перо феникса",
		"desc": "При смертельном ударе воскрешает мага с 50% HP и испускает термо-волну (1 раз за забег).",
		"color": Color(1.0, 0.45, 0.1, 1.0),
		"tags": ["revival", "fire", "survival"]
	},
	"lightning_rod": {
		"name": "Громоотвод",
		"desc": "Все снаряды выпускают +1 снаряд, а цепные разряды совершают +1 дополнительный скачок.",
		"color": Color(0.45, 0.9, 1.0, 1.0),
		"tags": ["lightning", "projectiles"]
	},
	"scholars_tome": {
		"name": "Фолиант учёного",
		"desc": "Увеличивает радиус сбора опыта на +60% и ускоряет набор уровней на +25%.",
		"color": Color(1.0, 0.85, 0.25, 1.0),
		"tags": ["utility", "experience"]
	}
}

func _ready() -> void:
	var parent = get_parent()
	if parent is PlayerController:
		player_owner = parent

func _process(delta: float) -> void:
	if not player_owner:
		return

	if has_artifact("obsidian_heart") and player_owner.stats:
		var missing_ratio = 1.0 - (player_owner.current_health / player_owner.stats.max_health)
		var bonus = missing_ratio * 0.8
		player_owner.set_meta("obsidian_heart_bonus", bonus)

func has_artifact(id: String) -> bool:
	return artifacts.has(id)

func add_artifact(id: String) -> bool:
	if has_artifact(id) or artifacts.size() >= max_artifacts:
		return false

	if ALL_ARTIFACTS.has(id):
		var data = ALL_ARTIFACTS[id]
		var item = ItemDefinition.new(id, data["name"], data["desc"], data["color"], data["tags"])
		artifacts[id] = item
		artifact_added.emit(item)
		apply_artifact_effect(id)
		return true

	return false

func apply_artifact_effect(id: String) -> void:
	if not player_owner:
		return

	match id:
		"hourglass":
			player_owner.set_meta("has_hourglass", true)
		"obsidian_heart":
			player_owner.set_meta("has_obsidian_heart", true)
		"rift_compass":
			player_owner.set_meta("has_rift_compass", true)
		"frost_core":
			player_owner.set_meta("has_frost_core", true)
		"phoenix_feather":
			player_owner.phoenix_revives_remaining += 1
		"lightning_rod":
			player_owner.set_meta("has_lightning_rod", true)
		"scholars_tome":
			player_owner.set_meta("has_scholars_tome", true)
