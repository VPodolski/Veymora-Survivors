class_name RewardGenerator
extends RefCounted

const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const MetaArchive = preload("res://scripts/game/meta_archive.gd")

class UpgradeOption:
	var id: String = ""
	var type: String = "" # "new_ability", "upgrade_ability", "passive", "artifact", "evolution"
	var title: String = ""
	var description: String = ""
	var level_badge: String = ""
	var category_badge: String = ""

static func generate_choices(player: PlayerController, count: int = 3) -> Array[UpgradeOption]:
	var candidates: Array[UpgradeOption] = []
	var priority_choices: Array[UpgradeOption] = []

	if not player or not player.ability_controller:
		return candidates

	var ac = player.ability_controller
	var inv = player.inventory

	# 0. Check for EVOLUTIONS (Top priority!)
	# 0.1 Magic Bolt + Hourglass -> Returning Rift
	var bolt = ac.get_ability("magic_bolt") as MagicBoltAbility
	if bolt and bolt.current_level >= 5 and not bolt.is_evolved:
		if inv and inv.has_artifact("hourglass"):
			var evo = UpgradeOption.new()
			evo.id = "evolve_magic_bolt"
			evo.type = "evolution"
			evo.title = "Возвращающийся разлом"
			evo.description = "★ ЭВОЛЮЦИЯ! Снаряды преобразуются в призматические разломы с бесконечным пробиванием и уроном 55."
			evo.category_badge = "★ ЭВОЛЮЦИЯ ★"
			evo.level_badge = "ЛЕГЕНДАРНОЕ"
			priority_choices.append(evo)

	# 0.2 Ice Storm + Frost Core -> Blizzard Cataclysm
	var storm = ac.get_ability("ice_storm") as IceStormAbility
	if storm and storm.current_level >= 5 and not storm.is_evolved:
		if inv and inv.has_artifact("frost_core"):
			var evo = UpgradeOption.new()
			evo.id = "evolve_ice_storm"
			evo.type = "evolution"
			evo.title = "Абсолютный буран"
			evo.description = "★ ЭВОЛЮЦИЯ! Радиус бури 230px, урон 32/тик, перманентное замораживание и ледяной шквал."
			evo.category_badge = "★ ЭВОЛЮЦИЯ ★"
			evo.level_badge = "ЛЕГЕНДАРНОЕ"
			priority_choices.append(evo)

	# 0.3 Fireball + Obsidian Heart -> Infernal Supernova
	var fireball = ac.get_ability("fireball") as FireballAbility
	if fireball and fireball.current_level >= 5 and not fireball.is_evolved:
		if inv and inv.has_artifact("obsidian_heart"):
			var evo = UpgradeOption.new()
			evo.id = "evolve_fireball"
			evo.type = "evolution"
			evo.title = "Инфернальная сверхновая"
			evo.description = "★ ЭВОЛЮЦИЯ! Гигантская пробивающая сфера с уроном 50, испускающая волны огненных взрывов."
			evo.category_badge = "★ ЭВОЛЮЦИЯ ★"
			evo.level_badge = "ЛЕГЕНДАРНОЕ"
			priority_choices.append(evo)

	# 1. New abilities to unlock
	for ability_id in ac.available_scenes.keys():
		if not ac.has_ability(ability_id) and ac.active_abilities.size() < ac.max_abilities:
			var opt = UpgradeOption.new()
			opt.id = ability_id
			opt.type = "new_ability"
			opt.category_badge = "НОВОЕ ЗАКЛИНАНИЕ"
			opt.level_badge = "Ур. 1"
			match ability_id:
				"runic_blade":
					opt.title = "Рунический клинок"
					opt.description = "Вращающиеся рунические клинки ближней защиты."
				"magic_bolt":
					opt.title = "Магическая стрела"
					opt.description = "Сгустки чародейской энергии в дальних врагов."
				"ice_storm":
					opt.title = "Ледяной шторм"
					opt.description = "Область вьюги с периодическим уроном и замедлением."
				"death_mark":
					opt.title = "Клеймо смерти"
					opt.description = "Помечает сильнейших врагов, увеличивая получаемый ими урон."
				"fireball":
					opt.title = "Огненная сфера"
					opt.description = "Взрывающийся шар магмы, наносящий урон по площади и поджигающий врагов."
				"lightning_strike":
					opt.title = "Грозовой разряд"
					opt.description = "Бьёт молнией из небес, перескакивающей между ближайшими врагами."
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

	# 3. Artifacts (if inventory has space)
	if inv and inv.artifacts.size() < inv.max_artifacts:
		for art_id in InventoryState.ALL_ARTIFACTS.keys():
			if not inv.has_artifact(art_id):
				var art_data = InventoryState.ALL_ARTIFACTS[art_id]
				var opt = UpgradeOption.new()
				opt.id = art_id
				opt.type = "artifact"
				opt.title = art_data["name"]
				opt.description = art_data["desc"]
				opt.category_badge = "АРТЕФАКТ"
				opt.level_badge = "РЕДКОЕ"
				candidates.append(opt)

	# 4. Passive upgrades
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

	candidates.shuffle()

	var selected: Array[UpgradeOption] = []
	for p_opt in priority_choices:
		selected.append(p_opt)

	for c in candidates:
		if selected.size() >= count:
			break
		selected.append(c)

	return selected

static func apply_upgrade(player: PlayerController, option: UpgradeOption) -> void:
	if not player:
		return

	match option.type:
		"evolution":
			var container = player.get_tree().current_scene if player.get_tree().current_scene else player.get_tree().root
			MetaArchive.record_discovery("evolutions", option.id)
			MetaArchive.check_and_complete_goal("discover_evolution")
			if option.id == "evolve_magic_bolt" and player.ability_controller:
				var bolt = player.ability_controller.get_ability("magic_bolt") as MagicBoltAbility
				if bolt:
					bolt.evolve()
					CombatEffects.spawn_shockwave(container, player.global_position, 160.0, Color(1.0, 0.85, 0.3, 0.95))
					CombatEffects.spawn_text_popup(container, player.global_position + Vector2(0, -35), "ЭВОЛЮЦИЯ: ВОЗВРАЩАЮЩИЙСЯ РАЗЛОМ!", Color(1.0, 0.9, 0.3, 1.0))
			elif option.id == "evolve_ice_storm" and player.ability_controller:
				var storm = player.ability_controller.get_ability("ice_storm") as IceStormAbility
				if storm:
					storm.evolve()
					CombatEffects.spawn_shockwave(container, player.global_position, 180.0, Color(0.3, 0.9, 1.0, 0.95))
					CombatEffects.spawn_text_popup(container, player.global_position + Vector2(0, -35), "ЭВОЛЮЦИЯ: АБСОЛЮТНЫЙ БУРАН!", Color(0.4, 0.95, 1.0, 1.0))
			elif option.id == "evolve_fireball" and player.ability_controller:
				var fireball = player.ability_controller.get_ability("fireball") as FireballAbility
				if fireball:
					fireball.evolve()
					CombatEffects.spawn_shockwave(container, player.global_position, 180.0, Color(1.0, 0.45, 0.1, 0.95))
					CombatEffects.spawn_text_popup(container, player.global_position + Vector2(0, -35), "ЭВОЛЮЦИЯ: ИНФЕРНАЛЬНАЯ СВЕРХНОВАЯ!", Color(1.0, 0.55, 0.15, 1.0))

		"artifact":
			if player.inventory:
				player.inventory.add_artifact(option.id)
				MetaArchive.record_discovery("artifacts", option.id)
		"new_ability":
			if player.ability_controller:
				player.ability_controller.unlock_ability(option.id)
				MetaArchive.record_discovery("spells", option.id)
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
