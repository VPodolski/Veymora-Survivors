class_name ArenaConfig
extends Resource

@export var id: String = "forgotten_forest"
@export var name: String = "Забытый лес"
@export var description: String = "Забытое пространство, в котором природа постепенно поглощается энергией Разлома."
@export var difficulty: String = "Обычная"
@export var features: Array = ["Сбалансированные волны врагов", "Рунические источники усиления", "Умеренная динамика"]
@export var threats: Array = ["Обычные и быстрые тени", "Элитные крушители"]
@export var is_unlocked: bool = true
@export var unlock_condition: String = "Доступно с самого начала"
@export var floor_color: Color = Color(0.04, 0.08, 0.07, 1.0)
@export var grid_color: Color = Color(0.08, 0.16, 0.13, 0.4)
@export var border_color: Color = Color(0.18, 0.65, 0.45, 0.85)
@export var ambient_color: Color = Color(0.3, 0.9, 0.6, 0.6)
@export var arena_size: Vector2 = Vector2(2400, 1600)
@export var special_mechanic: String = "rune_hotspots"

static func _create_item() -> Resource:
	var script = load("res://scripts/arena/arena_config.gd") as GDScript
	return script.new()

static func get_catalog() -> Dictionary:
	var catalog: Dictionary = {}

	# 1. Forgotten Forest (Starter arena, unlocked by default)
	var forest = _create_item()
	forest.id = "forgotten_forest"
	forest.name = "Забытый лес"
	forest.description = "Забытое пространство, в котором первозданная природа постепенно поглощается чародейской энергией Разлома."
	forest.difficulty = "Обычная"
	forest.features = ["Рунические источники усиления", "Умеренные опасные зоны", "Стабильный темп появления врагов"]
	forest.threats = ["Быстрые стаи теней", "Часовые разлома", "Колосс пустоты"]
	forest.is_unlocked = true
	forest.unlock_condition = "Доступно по умолчанию"
	forest.floor_color = Color(0.04, 0.07, 0.06, 1.0)
	forest.grid_color = Color(0.08, 0.15, 0.12, 0.35)
	forest.border_color = Color(0.2, 0.65, 0.45, 0.85)
	forest.ambient_color = Color(0.35, 0.9, 0.6, 0.5)
	forest.arena_size = Vector2(2400, 1600)
	forest.special_mechanic = "rune_hotspots"
	catalog["forgotten_forest"] = forest

	# 2. Frost Necropolis (Second playable arena in v0.3)
	var necro = _create_item()
	necro.id = "frost_necropolis"
	necro.name = "Ледяной некрополь"
	necro.description = "Древний склеп, где остаточная магия превратила землю в вечную мерзлоту с ледяными ловушками."
	necro.difficulty = "Повышенная"
	necro.features = ["Периодические зоны замерзания", "Ледяные кристаллы-препятствия", "Сопротивление холоду у врагов"]
	necro.threats = ["Морозные ползуны", "Ледяные лучники", "Оковы абсолютного холода"]
	necro.is_unlocked = true
	necro.unlock_condition = "Завершить 1 забег или выжить 5 минут в Забытом лесу"
	necro.floor_color = Color(0.04, 0.05, 0.1, 1.0)
	necro.grid_color = Color(0.09, 0.14, 0.22, 0.4)
	necro.border_color = Color(0.35, 0.75, 1.0, 0.85)
	necro.ambient_color = Color(0.5, 0.85, 1.0, 0.6)
	necro.arena_size = Vector2(2600, 1700)
	necro.special_mechanic = "frost_zones"
	catalog["frost_necropolis"] = necro

	# 3. Ash Citadel (Locked preview in v0.3)
	var citadel = _create_item()
	citadel.id = "ash_citadel"
	citadel.name = "Пепельная цитадель"
	citadel.description = "Разрушенная крепость, поглощённая вечным бушующим пламенем и раскалённой магмой."
	citadel.difficulty = "Смертельная"
	citadel.features = ["Лавовые гейзеры", "Волны огненных всплесков", "Бронированные пепельные монстры"]
	citadel.threats = ["Магматические стражи", "Инфернальные споры"]
	citadel.is_unlocked = false
	citadel.unlock_condition = "Откроется в версии 0.4 (победить босса в Ледяном некрополе)"
	citadel.floor_color = Color(0.09, 0.04, 0.04, 1.0)
	citadel.grid_color = Color(0.18, 0.08, 0.07, 0.4)
	citadel.border_color = Color(1.0, 0.4, 0.15, 0.85)
	citadel.ambient_color = Color(1.0, 0.5, 0.2, 0.6)
	citadel.arena_size = Vector2(2500, 1600)
	citadel.special_mechanic = "ash_eruptions"
	catalog["ash_citadel"] = citadel

	# 4. Void Rift (Locked preview in v0.3)
	var void_rift = _create_item()
	void_rift.id = "void_rift"
	void_rift.name = "Разлом Бездны"
	void_rift.description = "Нестабильное сверхпространство с нарушенной геометрией, где реальность распадается на части."
	void_rift.difficulty = "Кошмарная"
	void_rift.features = ["Гравитационные аномалии", "Искажения времени", "Непредсказуемые разломы"]
	void_rift.threats = ["Фантомы Бездны", "Пожиратели сущности"]
	void_rift.is_unlocked = false
	void_rift.unlock_condition = "Откроется в версии 0.4 (исследовать все синергии и реликвии)"
	void_rift.floor_color = Color(0.06, 0.03, 0.09, 1.0)
	void_rift.grid_color = Color(0.14, 0.07, 0.22, 0.4)
	void_rift.border_color = Color(0.85, 0.3, 1.0, 0.85)
	void_rift.ambient_color = Color(0.8, 0.35, 1.0, 0.6)
	void_rift.arena_size = Vector2(2800, 1800)
	void_rift.special_mechanic = "void_anomalies"
	catalog["void_rift"] = void_rift

	return catalog

static func get_arena_config(arena_id: String) -> Resource:
	var catalog = get_catalog()
	if catalog.has(arena_id):
		return catalog[arena_id]
	return catalog["forgotten_forest"]
