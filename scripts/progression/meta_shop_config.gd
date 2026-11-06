class_name MetaShopConfig
extends RefCounted

const CATEGORIES = {
	"vitality": {
		"id": "vitality",
		"name": "Жизненная сила",
		"name_en": "Vitality",
		"icon": "❤",
		"color": Color(0.95, 0.35, 0.45, 1.0)
	},
	"defense": {
		"id": "defense",
		"name": "Защита",
		"name_en": "Defense",
		"icon": "🛡",
		"color": Color(0.35, 0.75, 1.0, 1.0)
	},
	"magic_mastery": {
		"id": "magic_mastery",
		"name": "Мастерство",
		"name_en": "Mastery",
		"icon": "✦",
		"color": Color(0.85, 0.45, 1.0, 1.0)
	},
	"synergies": {
		"id": "synergies",
		"name": "Синергии",
		"name_en": "Synergies",
		"icon": "⚡",
		"color": Color(1.0, 0.85, 0.25, 1.0)
	},
	"treasures": {
		"id": "treasures",
		"name": "Сокровища",
		"name_en": "Treasures",
		"icon": "🪙",
		"color": Color(1.0, 0.75, 0.2, 1.0)
	}
}

const UPGRADES = {
	"vitality_health": {
		"id": "vitality_health",
		"category": "vitality",
		"name": "Живучесть",
		"name_en": "Endurance",
		"description": "Увеличивает максимальный запас здоровья мага на +10 HP за каждый уровень.",
		"description_en": "Increases max player health by +10 HP per level.",
		"max_level": 5,
		"costs": [50, 100, 200, 350, 600],
		"format_effect": "+%d HP"
	},
	"vitality_regen": {
		"id": "vitality_regen",
		"category": "vitality",
		"name": "Регенерация",
		"name_en": "Regeneration",
		"description": "Постоянно восстанавливает +0.4 здоровья в секунду за каждый уровень.",
		"description_en": "Continuously regenerates +0.4 health per second per level.",
		"max_level": 5,
		"costs": [75, 150, 300, 500, 800],
		"format_effect": "+%.1f HP/с"
	},
	"defense_armor": {
		"id": "defense_armor",
		"category": "defense",
		"name": "Закалённый панцирь",
		"name_en": "Hardened Carapace",
		"description": "Снижает весь входящий урон по магу на 3% за каждый уровень.",
		"description_en": "Reduces all incoming damage to player by 3% per level.",
		"max_level": 5,
		"costs": [80, 160, 320, 550, 900],
		"format_effect": "-%d%% урона"
	},
	"defense_barrier": {
		"id": "defense_barrier",
		"category": "defense",
		"name": "Плотность барьера",
		"name_en": "Barrier Density",
		"description": "Увеличивает прочность Магического барьера на +15% за каждый уровень.",
		"description_en": "Increases Magic Barrier shield durability by +15% per level.",
		"max_level": 5,
		"costs": [70, 140, 280, 480, 750],
		"format_effect": "+%d%% барьера"
	},
	"magic_power": {
		"id": "magic_power",
		"category": "magic_mastery",
		"name": "Тайное могущество",
		"name_en": "Arcane Might",
		"description": "Увеличивает базовую силу всех заклинаний на +4% за каждый уровень.",
		"description_en": "Increases spell damage multiplier by +4% per level.",
		"max_level": 5,
		"costs": [100, 200, 400, 700, 1100],
		"format_effect": "+%d%% силы"
	},
	"magic_cooldown": {
		"id": "magic_cooldown",
		"category": "magic_mastery",
		"name": "Быстрота плетения",
		"name_en": "Swift Weaving",
		"description": "Сокращает время перезарядки всех способностей на 3% за каждый уровень.",
		"description_en": "Reduces cooldown of all spells by 3% per level.",
		"max_level": 5,
		"costs": [100, 200, 400, 700, 1100],
		"format_effect": "-%d%% отката"
	},
	"magic_area": {
		"id": "magic_area",
		"category": "magic_mastery",
		"name": "Радиус катализа",
		"name_en": "Catalytic Radius",
		"description": "Увеличивает радиус действия заклинаний и зон на +5% за каждый уровень.",
		"description_en": "Increases area radius of spells and zones by +5% per level.",
		"max_level": 5,
		"costs": [60, 120, 240, 420, 680],
		"format_effect": "+%d%% площади"
	},
	"synergy_potency": {
		"id": "synergy_potency",
		"category": "synergies",
		"name": "Резонансная мощь",
		"name_en": "Resonance Power",
		"description": "Увеличивает урон всех элементальных реакций и синергий на +6% за каждый уровень.",
		"description_en": "Increases damage of all elemental synergy reactions by +6% per level.",
		"max_level": 5,
		"costs": [90, 180, 360, 620, 1000],
		"format_effect": "+%d%% урона реакций"
	},
	"synergy_energy": {
		"id": "synergy_energy",
		"category": "synergies",
		"name": "Грозовой накопитель",
		"name_en": "Thunder Battery",
		"description": "Ускоряет накопление заряда Громового щита на +10% за каждый уровень.",
		"description_en": "Accelerates Thunder Shield energy accumulation by +10% per level.",
		"max_level": 5,
		"costs": [75, 150, 300, 500, 800],
		"format_effect": "+%d%% энергии"
	},
	"treasure_greed": {
		"id": "treasure_greed",
		"category": "treasures",
		"name": "Золотая лихорадка",
		"name_en": "Gold Rush",
		"description": "Повышает шанс выпадения золотых монет с противников на +3% за каждый уровень.",
		"description_en": "Increases enemy gold coin drop chance by +3% per level.",
		"max_level": 5,
		"costs": [60, 120, 250, 450, 750],
		"format_effect": "+%d%% шанса монет"
	},
	"treasure_bounty": {
		"id": "treasure_bounty",
		"category": "treasures",
		"name": "Щедрая добыча",
		"name_en": "Generous Bounty",
		"description": "Увеличивает добычу золота из сундуков и за завершение арены на +20% за каждый уровень.",
		"description_en": "Increases gold awarded from chests and arena completion by +20% per level.",
		"max_level": 5,
		"costs": [70, 140, 280, 500, 850],
		"format_effect": "+%d%% золота"
	}
}

static func get_upgrade_cost(upgrade_id: String, current_level: int) -> int:
	if not UPGRADES.has(upgrade_id):
		return 999999
	var costs: Array = UPGRADES[upgrade_id]["costs"]
	if current_level < costs.size():
		return costs[current_level]
	return 999999

static func get_total_spent_for_upgrades(shop_upgrades: Dictionary) -> int:
	var total_spent = 0
	for u_id in shop_upgrades.keys():
		if not UPGRADES.has(u_id):
			continue
		var lvl = int(shop_upgrades[u_id])
		var costs: Array = UPGRADES[u_id]["costs"]
		for i in range(min(lvl, costs.size())):
			total_spent += costs[i]
	return total_spent

static func get_total_available_levels() -> int:
	var total = 0
	for u in UPGRADES.values():
		total += int(u.get("max_level", 5))
	return total

static func get_total_available_upgrades() -> int:
	return UPGRADES.size()

static func get_total_levels_purchased(shop_upgrades: Dictionary) -> int:
	var count = 0
	for u_id in UPGRADES.keys():
		count += int(shop_upgrades.get(u_id, 0))
	return count

static func get_maxed_upgrades_count(shop_upgrades: Dictionary) -> int:
	var count = 0
	for u_id in UPGRADES.keys():
		var max_lvl = int(UPGRADES[u_id].get("max_level", 5))
		if int(shop_upgrades.get(u_id, 0)) >= max_lvl:
			count += 1
	return count

static func get_category_levels_purchased(cat_id: String, shop_upgrades: Dictionary) -> int:
	var count = 0
	for u_id in UPGRADES.keys():
		if UPGRADES[u_id]["category"] == cat_id:
			count += int(shop_upgrades.get(u_id, 0))
	return count

static func get_category_max_levels(cat_id: String) -> int:
	var total = 0
	for u in UPGRADES.values():
		if u["category"] == cat_id:
			total += int(u.get("max_level", 5))
	return total

static func is_category_maxed(cat_id: String, shop_upgrades: Dictionary) -> bool:
	var purchased = get_category_levels_purchased(cat_id, shop_upgrades)
	var max_l = get_category_max_levels(cat_id)
	return max_l > 0 and purchased >= max_l

static func get_upgrades_by_category(category_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for u_id in UPGRADES.keys():
		var u = UPGRADES[u_id]
		if u["category"] == category_id:
			list.append(u)
	return list

static func get_effect_summary(upgrade_id: String, level: int, lang: String = "ru") -> String:
	var is_en = lang == "en"
	match upgrade_id:
		"vitality_health":
			return "+%d HP" % (level * 10)
		"vitality_regen":
			return ("+%.1f HP/s" if is_en else "+%.1f HP/с") % (level * 0.4)
		"defense_armor":
			return ("-%d%% Damage" if is_en else "-%d%% урона") % (level * 3)
		"defense_barrier":
			return ("+%d%% Barrier" if is_en else "+%d%% барьера") % (level * 15)
		"magic_power":
			return ("+%d%% Spell Power" if is_en else "+%d%% силы") % (level * 4)
		"magic_cooldown":
			return ("-%d%% Cooldown" if is_en else "-%d%% отката") % (level * 3)
		"magic_area":
			return ("+%d%% Spell Area" if is_en else "+%d%% площади") % (level * 5)
		"synergy_potency":
			return ("+%d%% Reaction Dmg" if is_en else "+%d%% урона реакций") % (level * 6)
		"synergy_energy":
			return ("+%d%% Energy Gain" if is_en else "+%d%% накопления") % (level * 10)
		"treasure_greed":
			return ("+%d%% Coin Chance" if is_en else "+%d%% шанса монет") % (level * 3)
		"treasure_bounty":
			return ("+%d%% Gold Bounty" if is_en else "+%d%% золота") % (level * 20)
		_:
			return ("Lv. %d" if is_en else "Ур. %d") % level
