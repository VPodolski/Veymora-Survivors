class_name RewardGenerator
extends RefCounted

class UpgradeOption:
	var id: String = ""
	var type: String = "" # "new_ability", "upgrade_ability", "passive"
	var title: String = ""
	var description: String = ""
	var level_badge: String = ""
	var category_badge: String = ""

static func generate_choices(player: PlayerController, count: int = 3) -> Array[UpgradeOption]:
	var candidates: Array[UpgradeOption] = []

	if not player or not player.ability_controller:
		return candidates

	var ac = player.ability_controller

	# 1. New abilities to unlock
	for ability_id in ac.available_scenes.keys():
		if not ac.has_ability(ability_id) and ac.active_abilities.size() < ac.max_abilities:
			var opt = UpgradeOption.new()
			opt.id = ability_id
			opt.type = "new_ability"
			if ability_id == "runic_blade":
				opt.title = "Рунический клинок"
				opt.description = "Вращающиеся рунические клинки ближней защиты."
				opt.category_badge = "НОВОЕ ЗАКЛИНАНИЕ"
				opt.level_badge = "Ур. 1"
			elif ability_id == "magic_bolt":
				opt.title = "Магическая стрела"
				opt.description = "Сгустки чародейской энергии в дальних врагов."
				opt.category_badge = "НОВОЕ ЗАКЛИНАНИЕ"
				opt.level_badge = "Ур. 1"
			candidates.append(opt)

	# 2. Upgrades for active abilities
	for ability in ac.get_active_abilities():
		if ability.current_level < ability.max_level:
			var opt = UpgradeOption.new()
			opt.id = ability.ability_id
			opt.type = "upgrade_ability"
			opt.title = ability.ability_name
			opt.description = ability.get_next_upgrade_description()
			opt.category_badge = "УЛУЧШЕНИЕ"
			opt.level_badge = "Ур. %d → %d" % [ability.current_level, ability.current_level + 1]
			candidates.append(opt)

	# 3. Passive upgrades
	var passives = [
		{
			"id": "passive_spell_power",
			"title": "Чародейская мощь",
			"desc": "+15% к урону всех заклинаний мага",
			"badge": "ПАССИВНОЕ"
		},
		{
			"id": "passive_cooldown",
			"title": "Ускорение плетения",
			"desc": "-12% к времени перезарядки способностей",
			"badge": "ПАССИВНОЕ"
		},
		{
			"id": "passive_move_speed",
			"title": "Лёгкая поступь",
			"desc": "+12% к скорости передвижения мага",
			"badge": "ПАССИВНОЕ"
		},
		{
			"id": "passive_max_health",
			"title": "Жизненный исток",
			"desc": "+25 к максимальному здоровью и исцеление",
			"badge": "ПАССИВНОЕ"
		}
	]

	for p in passives:
		var opt = UpgradeOption.new()
		opt.id = p["id"]
		opt.type = "passive"
		opt.title = p["title"]
		opt.description = p["desc"]
		opt.category_badge = p["badge"]
		opt.level_badge = "+БОНУС"
		candidates.append(opt)

	# Shuffle candidates
	candidates.shuffle()

	# Select up to 'count' options
	var selected: Array[UpgradeOption] = []
	for i in range(min(count, candidates.size())):
		selected.append(candidates[i])

	return selected

static func apply_upgrade(player: PlayerController, option: UpgradeOption) -> void:
	if not player:
		return

	match option.type:
		"new_ability":
			if player.ability_controller:
				player.ability_controller.unlock_ability(option.id)
		"upgrade_ability":
			if player.ability_controller:
				player.ability_controller.upgrade_ability(option.id)
		"passive":
			match option.id:
				"passive_spell_power":
					player.increase_spell_power(0.15)
				"passive_cooldown":
					player.reduce_cooldown(0.12)
				"passive_move_speed":
					player.increase_move_speed(0.12)
				"passive_max_health":
					player.increase_max_health(25.0)
