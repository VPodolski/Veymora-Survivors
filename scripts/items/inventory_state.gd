class_name InventoryState
extends Node

signal artifact_added(item: ItemDefinition)

@export var max_artifacts: int = 4

var artifacts: Dictionary = {} # id: ItemDefinition
var player_owner: PlayerController = null

static var ALL_ARTIFACTS: Dictionary = {
	"hourglass": {
		"name": "Песочные часы",
		"desc": "-15% к перезарядке заклинаний. Снаряды пробивают врагов и летят назад. Катализатор эволюции Магической стрелы.",
		"color": Color(0.3, 0.9, 1.0, 1.0),
		"tags": ["utility", "cooldown", "catalyst"],
		"icon_symbol": "hourglass",
		"rarity": "РЕДКОЕ"
	},
	"obsidian_heart": {
		"name": "Обсидиановое сердце",
		"desc": "Потерянное HP увеличивает силу магии (до +80%). Волна отталкивания при ранении. Катализатор Огненной сферы.",
		"color": Color(0.95, 0.22, 0.32, 1.0),
		"tags": ["defense", "damage", "catalyst"],
		"icon_symbol": "heart",
		"rarity": "РЕДКОЕ"
	},
	"frost_core": {
		"name": "Ледяное ядро",
		"desc": "+35% к урону холодом и +50% к длительности замедления. Катализатор эволюции Ледяного шторма.",
		"color": Color(0.2, 0.85, 1.0, 1.0),
		"tags": ["damage", "ice", "catalyst"],
		"icon_symbol": "ice",
		"rarity": "РЕДКОЕ"
	},
	"rift_compass": {
		"name": "Компас разломов",
		"desc": "Поражённые враги становятся нестабильными и при гибели взрываются пространственным разломом.",
		"color": Color(0.85, 0.35, 1.0, 1.0),
		"tags": ["damage", "spatial", "offensive"],
		"icon_symbol": "compass",
		"rarity": "РЕДКОЕ"
	},
	"phoenix_feather": {
		"name": "Перо феникса",
		"desc": "Легендарное перо: при смертельном ударе воскрешает мага с 50% HP и испускает термо-волну (1 раз за забег).",
		"color": Color(1.0, 0.45, 0.1, 1.0),
		"tags": ["defense", "survival", "legendary"],
		"icon_symbol": "feather",
		"rarity": "ЛЕГЕНДАРНОЕ"
	},
	"lightning_rod": {
		"name": "Громоотвод",
		"desc": "Все заклинания выпускают +1 снаряд, а цепные разряды совершают +1 дополнительный скачок.",
		"color": Color(0.45, 0.9, 1.0, 1.0),
		"tags": ["offensive", "lightning", "projectiles"],
		"icon_symbol": "lightning",
		"rarity": "РЕДКОЕ"
	},
	"amulet_of_haste": {
		"name": "Амулет спешки",
		"desc": "+18% к скорости передвижения мага.",
		"color": Color(0.3, 1.0, 0.7, 1.0),
		"tags": ["utility", "mobility"],
		"icon_symbol": "wing",
		"rarity": "ОБЫЧНОЕ"
	},
	"scholars_tome": {
		"name": "Фолиант учёного",
		"desc": "+50% к радиусу сбора сфер опыта и +20% к получаемому опыту.",
		"color": Color(1.0, 0.85, 0.25, 1.0),
		"tags": ["utility", "experience"],
		"icon_symbol": "book",
		"rarity": "ОБЫЧНОЕ"
	}
}

func _ready() -> void:
	var parent = get_parent()
	if parent is PlayerController:
		player_owner = parent

func _process(_delta: float) -> void:
	if not player_owner:
		return

	if has_artifact("obsidian_heart") and player_owner.stats:
		var missing_ratio = 1.0 - (player_owner.current_health / player_owner.stats.max_health)
		var bonus = missing_ratio * 0.8
		player_owner.set_meta("obsidian_heart_bonus", bonus)

func has_artifact(id: String) -> bool:
	return artifacts.has(id)

func is_full() -> bool:
	return artifacts.size() >= max_artifacts

func get_unowned_artifacts() -> Array[String]:
	var list: Array[String] = []
	for id in ALL_ARTIFACTS.keys():
		if not has_artifact(id):
			list.append(id)
	return list

func add_artifact(id: String) -> bool:
	if has_artifact(id) or is_full():
		return false

	if ALL_ARTIFACTS.has(id):
		var data = ALL_ARTIFACTS[id]
		var item = ItemDefinition.new(
			id,
			data["name"],
			data["desc"],
			data["color"],
			data.get("tags", []),
			data.get("icon_symbol", "gem"),
			data.get("rarity", "РЕДКОЕ")
		)
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
		"amulet_of_haste":
			player_owner.increase_move_speed(0.18)
			player_owner.set_meta("has_amulet_of_haste", true)
		"scholars_tome":
			player_owner.set_meta("has_scholars_tome", true)
