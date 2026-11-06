class_name MetaShopConfig
extends RefCounted

const CATEGORIES = {
	"vitality": {
		"id": "vitality",
		"name": "Жизненная сила",
		"icon": "❤",
		"color": Color(0.95, 0.35, 0.45, 1.0)
	},
	"defense": {
		"id": "defense",
		"name": "Защита",
		"icon": "🛡",
		"color": Color(0.35, 0.75, 1.0, 1.0)
	},
	"magic_mastery": {
		"id": "magic_mastery",
		"name": "Мастерство",
		"icon": "✦",
		"color": Color(0.85, 0.45, 1.0, 1.0)
	},
	"synergies": {
		"id": "synergies",
		"name": "Синергии",
		"icon": "⚡",
		"color": Color(1.0, 0.85, 0.25, 1.0)
	},
	"treasures": {
		"id": "treasures",
		"name": "Сокровища",
		"icon": "🪙",
		"color": Color(1.0, 0.75, 0.2, 1.0)
	}
}

const UPGRADES = {
	"vitality_health": {
		"id": "vitality_health",
		"category": "vitality",
		"name": "Живучесть",
		"description": "Увеличивает максимальный запас здоровья мага на +10 HP за каждый уровень.",
		"max_level": 5,
		"costs": [50, 100, 200, 350, 600],
		"format_effect": "+%d HP"
	},
	"vitality_regen": {
		"id": "vitality_regen",
		"category": "vitality",
		"name": "Регенерация",
		"description": "Постоянно восстанавливает +0.4 здоровья в секунду за каждый уровень.",
		"max_level": 5,
		"costs": [75, 150, 300, 500, 800],
		"format_effect": "+%.1f HP/с"
	},
	"defense_armor": {
		"id": "defense_armor",
		"category": "defense",
		"name": "Закалённый панцирь",
		"description": "Снижает весь входящий урон по магу на 3% за каждый уровень.",
		"max_level": 5,
		"costs": [80, 160, 320, 550, 900],
		"format_effect": "-%d%% урона"
	},
	"defense_barrier": {
		"id": "defense_barrier",
		"category": "defense",
		"name": "Плотность барьера",
		"description": "Увеличивает прочность Магического барьера на +15% за каждый уровень.",
		"max_level": 5,
		"costs": [70, 140, 280, 480, 750],
		"format_effect": "+%d%% барьера"
	},
	"magic_power": {
		"id": "magic_power",
		"category": "magic_mastery",
		"name": "Тайное могущество",
		"description": "Увеличивает базовую силу всех заклинаний на +4% за каждый уровень.",
		"max_level": 5,
		"costs": [100, 200, 400, 700, 1100],
		"format_effect": "+%d%% силы"
	},
	"magic_cooldown": {
		"id": "magic_cooldown",
		"category": "magic_mastery",
		"name": "Быстрота плетения",
		"description": "Сокращает время перезарядки всех способностей на 3% за каждый уровень.",
		"max_level": 5,
		"costs": [100, 200, 400, 700, 1100],
		"format_effect": "-%d%% отката"
	},
	"magic_area": {
		"id": "magic_area",
		"category": "magic_mastery",
		"name": "Радиус катализа",
		"description": "Увеличивает радиус действия заклинаний и зон на +5% за каждый уровень.",
		"max_level": 5,
		"costs": [60, 120, 240, 420, 680],
		"format_effect": "+%d%% площади"
	},
	"synergy_potency": {
		"id": "synergy_potency",
		"category": "synergies",
		"name": "Резонансная мощь",
		"description": "Увеличивает урон всех элементальных реакций и синергий на +6% за каждый уровень.",
		"max_level": 5,
		"costs": [90, 180, 360, 620, 1000],
		"format_effect": "+%d%% урона реакций"
	},
	"synergy_energy": {
		"id": "synergy_energy",
		"category": "synergies",
		"name": "Грозовой накопитель",
		"description": "Ускоряет накопление заряда Громового щита на +10% за каждый уровень.",
		"max_level": 5,
		"costs": [75, 150, 300, 500, 800],
		"format_effect": "+%d%% энергии"
	},
	"treasure_greed": {
		"id": "treasure_greed",
		"category": "treasures",
		"name": "Золотая лихорадка",
		"description": "Повышает шанс выпадения золотых монет с противников на +3% за каждый уровень.",
		"max_level": 5,
		"costs": [60, 120, 250, 450, 750],
		"format_effect": "+%d%% шанса монет"
	},
	"treasure_bounty": {
		"id": "treasure_bounty",
		"category": "treasures",
		"name": "Щедрая добыча",
		"description": "Увеличивает добычу золота из сундуков и за завершение арены на +20% за каждый уровень.",
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

static func get_upgrades_by_category(category_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for u_id in UPGRADES.keys():
		var u = UPGRADES[u_id]
		if u["category"] == category_id:
			list.append(u)
	return list

static func get_effect_summary(upgrade_id: String, level: int) -> String:
	match upgrade_id:
		"vitality_health":
			return "+%d HP" % (level * 10)
		"vitality_regen":
			return "+%.1f HP/с" % (level * 0.4)
		"defense_armor":
			return "-%d%% урона" % (level * 3)
		"defense_barrier":
			return "+%d%% барьера" % (level * 15)
		"magic_power":
			return "+%d%% силы" % (level * 4)
		"magic_cooldown":
			return "-%d%% отката" % (level * 3)
		"magic_area":
			return "+%d%% площади" % (level * 5)
		"synergy_potency":
			return "+%d%% урона реакций" % (level * 6)
		"synergy_energy":
			return "+%d%% накопления" % (level * 10)
		"treasure_greed":
			return "+%d%% шанса монет" % (level * 3)
		"treasure_bounty":
			return "+%d%% золота" % (level * 20)
		_:
			return "Ур. %d" % level

