class_name SynergyRegistry
extends RefCounted

const SynergyDefinitionClass = preload("res://scripts/synergies/synergy_definition.gd")

static var _definitions: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized and not _definitions.is_empty():
		return
	_definitions.clear()

	# --- 1. Arcane Resonance ---
	_register(SynergyDefinitionClass.new(
		"resonance",
		"Чародейский резонанс",
		"Арканный удар по заряженной цели снимает заряд и вызывает резонансный импульс, наносящий урон по площади и заряжающий вторичные цели.",
		"Аркан + Статический заряд",
		["arcane"],
		["charged"],
		["charged"],
		"hit",
		40,
		0.35,
		18.0,
		85.0,
		"charged",
		3.0,
		Color(0.75, 0.45, 1.0, 1.0),
		"resonance"
	))

	# --- 2. Frost Shatter ---
	_register(SynergyDefinitionClass.new(
		"frost_shatter",
		"Ледяные осколки",
		"Сокрушительный контактный удар по замедленной цели раскалывает ледяную корку, выпускает веер пробивающих осколков и снимает замедление.",
		"Ближний бой / Удар + Замедление",
		["melee", "orbit", "ice_impact"],
		["slowed"],
		["slowed"],
		"hit",
		30,
		0.35,
		14.0,
		190.0,
		"",
		0.0,
		Color(0.3, 0.9, 1.0, 1.0),
		"frost_shatter"
	))

	# --- 3. Lightning Chain ---
	_register(SynergyDefinitionClass.new(
		"lightning_chain",
		"Грозовая дуга",
		"Молния по уже заряженной цели высвобождает вторичный разряд, поражающий новые цели без повторного урона по уже задетым базовой молнией.",
		"Молния + Статический заряд",
		["lightning"],
		["charged"],
		["charged"],
		"hit",
		50,
		0.35,
		14.0,
		150.0,
		"charged",
		3.0,
		Color(0.45, 0.85, 1.0, 1.0),
		"lightning_chain"
	))

	# --- 4. Thermal Conflagration ---
	_register(SynergyDefinitionClass.new(
		"thermal_conflagration",
		"Термодинамическая перегрузка",
		"Огненная атака по заряженной цели вызывает разрушительный плазменный взрыв и поджигает всех врагов в области. Обладает наивысшим приоритетом.",
		"Огонь + Статический заряд",
		["fire"],
		["charged"],
		["charged"],
		"hit",
		100,
		0.35,
		38.0,
		95.0,
		"burning",
		3.5,
		Color(1.0, 0.55, 0.1, 1.0),
		"thermal_conflagration"
	))

	# --- 5. Steam Rift ---
	_register(SynergyDefinitionClass.new(
		"steam_rift",
		"Паровой разлом",
		"Огненный удар по замедленной цели мгновенно испаряет лед, создавая плотное облако пара, наносящее урон и повторно замедляющее врагов.",
		"Огонь + Замедление",
		["fire"],
		["slowed"],
		["slowed"],
		"hit",
		60,
		0.35,
		20.0,
		90.0,
		"slowed",
		2.5,
		Color(0.8, 0.92, 1.0, 1.0),
		"steam_rift"
	))

	# --- 6. Unstable Explosion ---
	_register(SynergyDefinitionClass.new(
		"unstable_explosion",
		"Взрыв нестабильности",
		"Гибель цели с меткой нестабильности детонирует пространственный разлом, наносящий урон окружающим врагам.",
		"Метка нестабильности + Гибель",
		["spatial", "void"],
		["unstable"],
		["unstable"],
		"death",
		20,
		0.0,
		25.0,
		90.0,
		"",
		0.0,
		Color(0.85, 0.25, 1.0, 1.0),
		"unstable_explosion"
	))

	# --- 7. Soul Harvest ---
	_register(SynergyDefinitionClass.new(
		"soul_harvest",
		"Жатва душ",
		"Гибель помеченного Клеймом смерти врага высвобождает багровую жатву душ, наносящую тяжелый урон окружающим теням.",
		"Клеймо смерти + Гибель",
		["marked", "void"],
		["marked"],
		["marked"],
		"death",
		25,
		0.0,
		35.0,
		90.0,
		"",
		0.0,
		Color(1.0, 0.25, 0.35, 1.0),
		"soul_harvest"
	))

	# --- 8. Returning Pierce ---
	_register(SynergyDefinitionClass.new(
		"returning_pierce",
		"Возвратный разлом",
		"Снаряды Магической стрелы бесконечно пробивают врагов, замедляются на дистанции и летят обратно к магу.",
		"Магическая стрела + Песочные часы",
		["arcane", "spatial"],
		[],
		[],
		"mutation",
		10,
		0.0,
		0.0,
		0.0,
		"",
		0.0,
		Color(0.4, 0.85, 1.0, 1.0),
		"returning_pierce"
	))

	# --- 9. Spatial Collapse (P2) ---
	_register(SynergyDefinitionClass.new(
		"spatial_collapse",
		"Пространственный коллапс",
		"Арканный удар по нестабильной цели стягивает окружающих врагов в сингулярность и вызывает компактный вакуумный взрыв.",
		"Аркан + Нестабильность",
		["arcane"],
		["unstable"],
		["unstable"],
		"hit",
		70,
		0.5,
		30.0,
		110.0,
		"",
		0.0,
		Color(0.7, 0.2, 0.95, 1.0),
		"spatial_collapse"
	))

	# --- 10. Cryogenic Shock (P2) ---
	_register(SynergyDefinitionClass.new(
		"cryogenic_shock",
		"Криогенный шок",
		"Электрический разряд по замороженной цели разрушает лед и испускает криогенные сверхпроводящие дуги к соседним теням.",
		"Молния + Замедление",
		["lightning"],
		["slowed"],
		["slowed"],
		"hit",
		45,
		0.35,
		24.0,
		130.0,
		"slowed",
		2.0,
		Color(0.35, 0.85, 1.0, 1.0),
		"cryogenic_shock"
	))

	# --- 11. Chain of Doom (P2) ---
	_register(SynergyDefinitionClass.new(
		"chain_of_doom",
		"Цепь погибели",
		"Гибель помеченного врага передает печать Клейма смерти ближайшей живой цели в радиусе 120px.",
		"Клеймо смерти + Гибель цели",
		["marked"],
		["marked"],
		[],
		"death",
		15,
		0.2,
		0.0,
		120.0,
		"marked",
		5.0,
		Color(0.95, 0.15, 0.25, 1.0),
		"chain_of_doom"
	))

	# --- 12. Runic Conductor (P2) ---
	_register(SynergyDefinitionClass.new(
		"runic_conductor",
		"Рунический проводник",
		"Удары молнии во время нахождения мага в Рунической зоне усиливаются и вызывают радиальный электрический разряд из центра руны.",
		"Молния + Руническая зона",
		["lightning"],
		[],
		[],
		"hit",
		80,
		0.4,
		20.0,
		140.0,
		"charged",
		3.0,
		Color(0.5, 0.9, 1.0, 1.0),
		"runic_conductor"
	))

	_initialized = true

static func _register(defn: SynergyDefinitionClass) -> void:
	_definitions[defn.id] = defn

static func get_definition(id: String) -> SynergyDefinitionClass:
	_ensure_initialized()
	return _definitions.get(id, null)

static func has_definition(id: String) -> bool:
	_ensure_initialized()
	return _definitions.has(id)

static func get_all() -> Array:
	_ensure_initialized()
	var list: Array = []
	for k in _definitions.keys():
		list.append(_definitions[k])
	return list

static func get_all_ids() -> Array[String]:
	_ensure_initialized()
	var ids: Array[String] = []
	for k in _definitions.keys():
		ids.append(k)
	return ids

static func get_hit_synergies() -> Array:
	_ensure_initialized()
	var list: Array = []
	for k in _definitions.keys():
		var defn = _definitions[k]
		if defn.trigger_event == "hit":
			list.append(defn)
	list.sort_custom(func(a, b): return a.priority > b.priority)
	return list

static func get_death_synergies() -> Array:
	_ensure_initialized()
	var list: Array = []
	for k in _definitions.keys():
		var defn = _definitions[k]
		if defn.trigger_event == "death":
			list.append(defn)
	list.sort_custom(func(a, b): return a.priority > b.priority)
	return list

