class_name SynergyRegistry
extends RefCounted

const SynergyDefinitionClass = preload("res://scripts/synergies/synergy_definition.gd")

static var _definitions: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized and not _definitions.is_empty():
		return
	_definitions.clear()

	# =========================================================================
	# 10 CORE V0.5 SYNERGIES
	# =========================================================================

	# --- 1. Steam Rift (Ice + Fire) ---
	_register(SynergyDefinitionClass.new(
		"steam_rift",
		"Паровой разлом",
		"Огненный удар по замедленной цели мгновенно испаряет лёд, создавая плотное облако пара, наносящее урон и повторно замедляющее врагов.",
		"Лёд + Огонь",
		["fire"],
		["slowed"],
		["slowed"],
		"hit",
		60,
		0.35,
		30.0,
		90.0,
		"slowed",
		3.5,
		Color(0.8, 0.92, 1.0, 1.0),
		"steam_rift"
	))

	# --- 2. Cryogenic Shock (Ice + Lightning) ---
	_register(SynergyDefinitionClass.new(
		"cryogenic_shock",
		"Криогенный шок",
		"Электрический разряд по замедленной цели разрушает лёд и испускает сверхпроводящие дуги с заморозкой соседних врагов.",
		"Лёд + Молния",
		["lightning"],
		["slowed"],
		["slowed"],
		"hit",
		45,
		0.35,
		32.0,
		130.0,
		"slowed",
		2.0,
		Color(0.35, 0.85, 1.0, 1.0),
		"cryogenic_shock"
	))

	# --- 3. Frost Shatter (Ice + Runic Blade) ---
	_register(SynergyDefinitionClass.new(
		"frost_shatter",
		"Ледяные осколки",
		"Удар клинка по замедленной цели раскалывает лёд, выпуская веер из 5 пробивающих хрустальных осколков.",
		"Лёд + Рунический клинок",
		["melee", "orbit", "ice_impact"],
		["slowed"],
		["slowed"],
		"hit",
		30,
		0.35,
		18.0,
		190.0,
		"",
		0.0,
		Color(0.3, 0.9, 1.0, 1.0),
		"frost_shatter"
	))

	# --- 4. Conflagration Execution (Fire + Death Mark) ---
	_register(SynergyDefinitionClass.new(
		"conflagration_execution",
		"Казнь пламенем",
		"Огненная атака по помеченной цели вызывает взрыв пламени, распространяя горение и метку на соседние цели.",
		"Огонь + Клеймо смерти",
		["fire"],
		["marked"],
		["marked"],
		"hit",
		90,
		0.35,
		45.0,
		110.0,
		"burning",
		3.5,
		Color(1.0, 0.3, 0.15, 1.0),
		"thermal_conflagration"
	))

	# --- 5. Charged Bolt (Lightning + Magic Bolt) ---
	_register(SynergyDefinitionClass.new(
		"charged_bolt",
		"Заряженная стрела",
		"Магическая стрела по заряженной цели электризуется, нанося повышенный урон и испуская цепные дуги.",
		"Молния + Магическая стрела",
		["arcane"],
		["charged"],
		["charged"],
		"hit",
		40,
		0.35,
		24.0,
		120.0,
		"charged",
		3.0,
		Color(0.4, 0.85, 1.0, 1.0),
		"resonance"
	))

	# --- 6. Thunder Shield (Magic Barrier + Lightning) ---
	_register(SynergyDefinitionClass.new(
		"thunder_shield",
		"Грозовой щит",
		"При поглощении входящего урона барьер выпускает ответный электрический импульс по атакующему врагу.",
		"Магический барьер + Молния",
		["barrier", "lightning"],
		[],
		[],
		"defense",
		50,
		0.5,
		30.0,
		180.0,
		"charged",
		3.5,
		Color(0.4, 0.9, 1.0, 1.0),
		"lightning_chain"
	))

	# --- 7. Glacial Ward (Magic Barrier + Ice) ---
	_register(SynergyDefinitionClass.new(
		"glacial_ward",
		"Ледяная защита",
		"В момент разрушения барьер испускает абсолютную волну холода, замораживая окружающих монстров.",
		"Магический барьер + Ледяной шторм",
		["barrier", "ice"],
		[],
		[],
		"defense",
		50,
		0.5,
		25.0,
		160.0,
		"slowed",
		2.5,
		Color(0.3, 0.9, 1.0, 1.0),
		"frost_shatter"
	))

	# --- 8. Life Harvest (Font of Life + Death Mark) ---
	_register(SynergyDefinitionClass.new(
		"life_harvest",
		"Жатва жизни",
		"Гибель помеченного врага испускает целебные эссенции, мгновенно восстанавливающие здоровье мага.",
		"Источник жизни + Клеймо смерти",
		["marked", "healing"],
		["marked"],
		["marked"],
		"death",
		30,
		0.0,
		0.0,
		140.0,
		"",
		0.0,
		Color(0.25, 0.95, 0.45, 1.0),
		"soul_harvest"
	))

	# --- 9. Blazing Blades (Runic Blade + Fireball) ---
	_register(SynergyDefinitionClass.new(
		"blazing_blades",
		"Пылающие клинки",
		"Рунические клинки воспламеняются, наносят +30% урона и поджигают всех задетых врагов.",
		"Рунический клинок + Огненная сфера",
		["melee", "fire"],
		[],
		[],
		"mutation",
		20,
		0.0,
		0.0,
		0.0,
		"burning",
		3.0,
		Color(1.0, 0.45, 0.1, 1.0),
		"thermal_conflagration"
	))

	# --- 10. Piercing Frost (Ice Storm + Magic Bolt) ---
	_register(SynergyDefinitionClass.new(
		"piercing_frost",
		"Ледяное пронзание",
		"Магические стрелы прошивают замедленных врагов насквозь и наносят им критический урон.",
		"Ледяной шторм + Магическая стрела",
		["arcane"],
		["slowed"],
		[],
		"hit",
		35,
		0.3,
		15.0,
		0.0,
		"slowed",
		2.0,
		Color(0.35, 0.9, 1.0, 1.0),
		"frost_shatter"
	))

	# =========================================================================
	# LEGACY / EXTENDED SYNERGIES (FOR 100% RETRO-COMPATIBILITY)
	# =========================================================================

	# Resonance
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

	# Lightning Chain
	_register(SynergyDefinitionClass.new(
		"lightning_chain",
		"Грозовая дуга",
		"Молния по уже заряженной цели высвобождает вторичный разряд, поражающий новые цели без повторного урона по уже задетым.",
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

	# Thermal Conflagration
	_register(SynergyDefinitionClass.new(
		"thermal_conflagration",
		"Термодинамическая перегрузка",
		"Огненная атака по заряженной цели вызывает разрушительный плазменный взрыв и поджигает всех врагов в области.",
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

	# Unstable Explosion
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

	# Soul Harvest
	_register(SynergyDefinitionClass.new(
		"soul_harvest",
		"Жатва душ",
		"Гибель помеченного Клеймом смерти врага высвобождает багровую жатву душ, наносящую урон окружающим теням.",
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

	# Returning Pierce
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

	# Spatial Collapse
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

	# Chain of Doom
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

	# Runic Conductor
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
