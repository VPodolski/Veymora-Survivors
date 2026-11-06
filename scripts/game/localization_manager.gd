class_name LocalizationManager
extends Node

signal language_changed(lang: String)

const SaveManager = preload("res://scripts/game/save_manager.gd")

static var instance: LocalizationManager = null

var current_language: String = "ru"

const STRINGS = {
	"ru": {
		# Common
		"app_title": "VEYMORA SURVIVORS",
		"app_subtitle": "Магические синергии • Разломы стихий • Версия 0.5.2",
		"version_tag": "v0.5.2 WebGL2",
		"btn_back": "← Назад",
		"btn_close": "✕",
		"btn_apply": "Готово",
		"btn_menu": "Главное меню",
		"btn_retry": "Повторить забег",
		"btn_codex": "Кодекс и Атлас",

		# Main Menu
		"menu_start": "⚔ ВЫБОР АРЕНЫ",
		"menu_codex": "📖 КОДЕКС И АТЛАС",
		"menu_settings": "⚙ НАСТРОЙКИ",
		"menu_controls": "✦ УПРАВЛЕНИЕ И ПРАВИЛА",
		"menu_stats": "Всего забегов: %d   |   Рекорд: %02d:%02d   |   Повержено боссов: %d   |   Доступно арен: %d",
		"auth_guest": "Гость",
		"auth_login_btn": "👤 Войти",
		"auth_logged_in": "👤 %s",
		"controls_heading": "УПРАВЛЕНИЕ И ОСНОВЫ БОЯ",
		"controls_body": "• Движение: [W, A, S, D], [Стрелки] или виртуальный джойстик на мобильных устройствах\n• Атака: заклинания применяются АВТОМАТИЧЕСКИ по ближайшим целям\n• Синергии: комбинируйте эффекты разных стихий (Огонь, Лёд, Молния, Аркан, Метка), чтобы вызывать стихийные взрывы и разломы\n• Эволюция: развивайте базовое заклинание до 5 уровня и найдите парный артефакт\n• Пауза / Кодекс: клавиша [ESC] или кнопка паузы\n• Быстрый перезапуск: клавиша [R] после завершения забега",
		"btn_understood": "Понятно",

		# Arena Select
		"arena_select_title": "ВЫБОР ПРОСТРАНСТВЕННОГО РАЗЛОМА",
		"arena_select_sub": "Каждая арена обладает уникальной опасной средой, модификаторами и стихийными угрозами",
		"arena_unlocked": "[ ДОСТУПНО ]",
		"arena_locked": "[ ЗАБЛОКИРОВАНО ]",
		"arena_diff": "Сложность: %s",
		"arena_btn_enter": "⚔ ВОЙТИ В РАЗЛОМ",
		"arena_btn_locked": "🔒 ЗАБЛОКИРОВАНО",
		"arena_stats_header": "Статистика арены:\n• Забегов: %d\n• Побед: %d\n• Рекорд: %02d:%02d\n• Уничтожено врагов: %d",
		"arena_features": "Особенности: ",
		"arena_threats": "Угрозы: ",

		# Arenas
		"arena_forest_name": "Забытый лес",
		"arena_forest_desc": "Забытое пространство, в котором первозданная природа постепенно поглощается чародейской энергией Разлома.",
		"arena_necro_name": "Ледяной некрополь",
		"arena_necro_desc": "Древний склеп, где остаточная магия превратила землю в вечную мерзлоту с ледяными ловушками.",
		"arena_citadel_name": "Пепельная цитадель",
		"arena_citadel_desc": "Разрушенная крепость, поглощённая вечным бушующим пламенем и раскалённой магмой.",
		"arena_void_name": "Разлом Бездны",
		"arena_void_desc": "Нестабильное сверхпространство с нарушенной геометрией, где реальность распадается на части.",

		# Loading Screen
		"loading_tip_prefix": "Совет: ",
		"loading_tips": [
			"Сочетайте разные школы магии — огонь по замедленной цели создаёт смертоносный паровой разлом.",
			"Развейте заклинание до 5 уровня и найдите парный артефакт, чтобы пробудить его истинную эволюцию.",
			"В Ледяном некрополе избегайте морозных очагов вечной мерзлоты, чтобы сохранять мобильность.",
			"Рунические круги на земле повышают силу ваших заклинаний, пока вы стоите внутри.",
			"Огонь по заряженному статикой врагу вызывает мощнейшую термодинамическую перегрузку.",
			"Фолиант мудрости увеличивает радиус притяжения сфер маны и повышает опыт.",
			"Сферы опыта конденсируются в более крупные кристаллы, если их становится слишком много."
		],

		# Settings
		"settings_title": "⚙ НАСТРОЙКИ",
		"settings_lang": "Язык (Language):",
		"settings_master": "Общая громкость:",
		"settings_sfx": "Эффекты (SFX):",
		"settings_fx": "Визуальные эффекты:",
		"settings_fx_full": "Стандартные (Full)",
		"settings_fx_reduced": "Сниженные (Reduced)",
		"settings_shake": "Тряска экрана:",
		"settings_shake_on": "Включена",
		"settings_dmg_num": "Числа урона:",
		"settings_dmg_num_on": "Показывать",
		"settings_vsync": "Вертикальная синхр.:",
		"settings_vsync_on": "Включена (VSync)",

		# Pause
		"pause_title": "ПАУЗА",
		"pause_resume": "Продолжить",
		"pause_archive": "📖 Кодекс и Атлас",
		"pause_restart": "Начать заново",
		"pause_menu": "В главное меню",

		# HUD & Level Up
		"lvl_up_title": "ПОВЫШЕНИЕ УРОВНЯ!",
		"lvl_up_sub": "Выберите одно магическое улучшение",
		"chest_title": "АРТЕФАКТ ИЗ СУНДУКА",
		"chest_sub": "Выберите один из трёх древних артефактов",
		"toast_acquired": "Получено: [%s]",
		"starter_tutorial": "✦ Движение: [W, A, S, D] или Джойстик • Заклинания срабатывают автоматически",

		# Results Screen
		"results_victory": "РАЗЛОМ ЗАКРЫТ! ПОБЕДА",
		"results_defeat": "МАГ ПОГИБ",
		"results_space": "Пространство: %s",
		"metric_time": "Время выживания:",
		"metric_lvl": "Достигнутый уровень:",
		"metric_kills": "Уничтожено теней:",
		"metric_elites": "Элитные монстры:",
		"metric_bosses": "Повержено боссов:",
		"metric_damage": "Общий нанесённый урон:",
		"metric_xp": "Собрано маны (XP):",
		"metric_artifacts": "Артефакты в сумке:",
		"metric_score": "Итоговые очки:",
		"metric_barrier_absorbed": "Поглощено барьером:",
		"metric_healing_done": "Восстановлено здоровья:",
		"btn_reward_bonus": "✦ ПОЛУЧИТЬ БОНУС К ОЧКАМ (+25%) ЗА ПРОСМОТР",
		"btn_reward_bonus_claimed": "✓ БОНУС ПОЛУЧЕН (+25%)",
		"synergy_share": "✦ Вклад синергий в общий урон: %d%%",
		"synergy_star": "   |   Ключевая синергия: %s",
		"synergy_empty": "В этом забеге магические реакции не были активированы.\nКомбинируйте школы магии для активации мощных стихийных резонансов!",
		"synergy_activations": "Активаций: %d",
		"synergy_dmg": "Урон: %d",
		"synergy_impact": "Целей: %d | Убийств: %d",
		"toast_synergy_unlocked": "✦ Открыта синергия: [%s]!",

		# Second Chance
		"second_chance_title": "ВТОРОЙ ШАНС",
		"second_chance_prompt": "Маг пал в бою, но древний Разлом дарует шанс восстать!\nПосмотрите короткую рекламу и продолжите текущий забег с 50% здоровья.",
		"second_chance_btn_watch": "✦ ВОСКРЕСНУТЬ ЗА ПРОСМОТР",
		"second_chance_btn_decline": "Завершить забег",

		# Level formats
		"lvl_format": "Ур. %d",
		"lvl_prefix": "УР. %d",

		# Synergies
		"syn_resonance_name": "Чародейский резонанс",
		"syn_resonance_desc": "Удар арканом по заряженной цели вызывает взрывной резонанс",
		"syn_frost_shatter_name": "Ледяные осколки",
		"syn_frost_shatter_desc": "Удар льдом по замедленной цели раскалывает её на осколки",
		"syn_lightning_chain_name": "Грозовая дуга",
		"syn_lightning_chain_desc": "Цепной разряд молнии между заряженными целями",
		"syn_unstable_explosion_name": "Взрыв нестабильности",
		"syn_unstable_explosion_desc": "Гибель помеченного врага взрывает область вокруг него",
		"syn_steam_rift_name": "Паровой разлом",
		"syn_steam_rift_desc": "Огненный урон по замедленной цели образует облако пара",
		"syn_thermal_conflagration_name": "Термодинамическая перегрузка",
		"syn_thermal_conflagration_desc": "Огонь по заряженному статикой врагу вызывает детонацию",
		"syn_soul_harvest_name": "Жатва душ",
		"syn_soul_harvest_desc": "Поглощение жизненной силы павших врагов",
		"syn_returning_pierce_name": "Возвратный разлом",
		"syn_returning_pierce_desc": "Снаряды пронзают врагов и возвращаются к магу",
		"syn_spatial_collapse_name": "Пространственный коллапс",
		"syn_spatial_collapse_desc": "Арканный удар по нестабильной цели стягивает врагов в сингулярность и взрывается",
		"syn_cryogenic_shock_name": "Криогенный шок",
		"syn_cryogenic_shock_desc": "Разряд молнии по замедленной цели раскалывает лед и испускает крио-дуги",
		"syn_chain_of_doom_name": "Цепь погибели",
		"syn_chain_of_doom_desc": "Гибель помеченного врага переносит клеймо смерти на ближайшую цель",
		"syn_runic_conductor_name": "Рунический проводник",
		"syn_runic_conductor_desc": "Молния во время нахождения в Рунической зоне высвобождает радиальный разряд",
		"syn_conflagration_execution_name": "Казнь пламенем",
		"syn_conflagration_execution_desc": "Огненная атака по помеченной цели вызывает взрыв пламени, распространяя горение и метку",
		"syn_charged_bolt_name": "Заряженная стрела",
		"syn_charged_bolt_desc": "Магическая стрела по заряженной цели электризуется, нанося повышенный урон и испуская дуги",
		"syn_thunder_shield_name": "Грозовой щит",
		"syn_thunder_shield_desc": "При поглощении урона барьер выпускает ответный электрический разряд по атакующему",
		"syn_glacial_ward_name": "Ледяная защита",
		"syn_glacial_ward_desc": "В момент разрушения барьер испускает абсолютную волну холода, замораживая окружающих врагов",
		"syn_life_harvest_name": "Жатва жизни",
		"syn_life_harvest_desc": "Гибель помеченного врага испускает целебные эссенции, мгновенно восстанавливающие здоровье",
		"syn_blazing_blades_name": "Пылающие клинки",
		"syn_blazing_blades_desc": "Рунические клинки воспламеняются, наносят +30% урона и поджигают всех задетых врагов",
		"syn_piercing_frost_name": "Ледяное пронзание",
		"syn_piercing_frost_desc": "Магические стрелы прошивают замедленных врагов насквозь и наносят им критический урон",

		# Spells & Artifacts
		"spell_magic_barrier_name": "Магический барьер",
		"spell_magic_barrier_desc": "Автоматический рунический щит, поглощающий удары и взрывающийся волной отталкивания при разрушении",
		"spell_font_of_life_name": "Источник жизни",
		"spell_font_of_life_desc": "Постепенная регенерация здоровья и целебные импульсы каждые 20 убийств",
		"art_life_crystal_name": "Кристалл жизни",
		"art_life_crystal_desc": "+35 к максимальному здоровью мага и +20% к эффективности любого исцеления и регенерации",
		"art_warding_rune_name": "Рунический щиток",
		"art_warding_rune_desc": "+20% к прочности Магического барьера и -1.0 секунду к времени его перезарядки",

		# Codex / Archive
		"codex_sec_spells": "БАЗОВЫЕ ЗАКЛИНАНИЯ (%d/%d)",
		"codex_sec_evolutions": "ВЫСШИЕ ЭВОЛЮЦИИ (%d/%d)",
		"codex_sec_synergies": "МАГИЧЕСКИЕ СИНЕРГИИ И РЕАКЦИИ (%d/%d)",
		"codex_sec_artifacts": "АРТЕФАКТЫ И РЕЛИКВИИ (%d/%d)",
		"codex_sec_atlas": "АТЛАС РАЗЛОМОВ: ИСПЫТАНИЯ И НАГРАДЫ (%d/%d)",
		"codex_unknown_spell": "??? Неизведанное заклинание",
		"codex_unknown_spell_desc": "Используйте свитки и повышайте уровень, чтобы открыть эту школу магии.",
		"codex_unknown_evo": "??? Скрытая трансмутация",
		"codex_unknown_evo_desc": "Требуется заклинание 5-го уровня и резонирующий артефакт.",
		"codex_unknown_syn": "??? Скрытая комбинация стихий",
		"codex_unknown_syn_desc": "Комбинируйте эффекты разных стихий в бою, чтобы раскрыть резонанс.",
		"codex_unknown_art": "??? Запечатанный артефакт",
		"codex_unknown_art_desc": "Побеждайте элитных врагов и находите сокровищницы Разлома.",
		"codex_badge_evo": "★ ЭВОЛЮЦИЯ ★",
		"codex_badge_syn": "СИНЕРГИЯ",
		"codex_badge_art": "АРТЕФАКТ",
		"codex_badge_done": "[✓ ВЫПОЛНЕНО]",
		"codex_badge_progress": "[✕ В ПРОЦЕССЕ]",
		"codex_school_prefix": "[Школа: %s]",
		"codex_req_prefix": "Условие: %s\n%s",
		"codex_formula_prefix": "Формула: %s\n%s",
		"codex_reward_prefix": "%s\nНаграда: %s",

		# Orientation warning
		"rotate_device_warning": "Пожалуйста, поверните устройство горизонтально для комфортной игры.",

		# Meta Shop & Progression
		"shop_title": "МАГАЗИН РАЗЛОМА: ПОСТОЯННЫЕ УЛУЧШЕНИЯ",
		"shop_progress_fmt": "Общий прогресс: %d / %d (%d%%) • Завершено: %d / %d",
		"shop_cat_progress_fmt": "%s (%d/%d)",
		"shop_buy_btn": "КУПИТЬ\n🪙 %d",
		"shop_btn_maxed": "ИЗУЧЕНО",
		"shop_btn_locked": "ЗАКРЫТО",
		"shop_insufficient_gold": "Недостаточно золота",
		"shop_effect_fmt": "Текущий бонус: %s  ➜  Следующий: %s",
		"shop_effect_max_fmt": "Эффект: %s (МАКСИМУМ)",
		"shop_effect_none": "Нет",
		"menu_shop": "🏛 МАГАЗИН УЛУЧШЕНИЙ",
		"menu_char_card_title": "🧙 Маг Разлома",
		"menu_char_lvl_fmt": "Ур. %d",
		"menu_char_xp_fmt": "Опыт мага: %d / %d XP",
		"menu_char_bonus_fmt": "Магическая стрела: %s к базовому урону",
		"menu_char_bonus_base": "Магическая стрела: базовая форма"
	},
	"en": {
		# Common
		"app_title": "VEYMORA SURVIVORS",
		"app_subtitle": "Elemental Synergies • Dimensional Rifts • Version 0.5.2",
		"version_tag": "v0.5.2 WebGL2",
		"btn_back": "← Back",
		"btn_close": "✕",
		"btn_apply": "Done",
		"btn_menu": "Main Menu",
		"btn_retry": "Play Again",
		"btn_codex": "Codex & Atlas",

		# Main Menu
		"menu_start": "⚔ SELECT ARENA",
		"menu_codex": "📖 CODEX & ATLAS",
		"menu_settings": "⚙ SETTINGS",
		"menu_controls": "✦ CONTROLS & RULES",
		"menu_stats": "Total Runs: %d   |   Record: %02d:%02d   |   Bosses Slain: %d   |   Arenas: %d",
		"auth_guest": "Guest",
		"auth_login_btn": "👤 Sign In",
		"auth_logged_in": "👤 %s",
		"controls_heading": "CONTROLS & COMBAT BASICS",
		"controls_body": "• Movement: [W, A, S, D], [Arrow Keys] or Virtual Touch Joystick on mobile\n• Attack: Spells cast AUTOMATICALLY at nearby targets\n• Synergies: Combine different elemental schools (Fire, Ice, Lightning, Arcane, Mark) to trigger explosive reactions\n• Evolution: Upgrade a base spell to Lv 5 and acquire its paired artifact\n• Pause / Codex: [ESC] key or Pause button\n• Quick Restart: [R] key on results screen",
		"btn_understood": "Got it",

		# Arena Select
		"arena_select_title": "SELECT DIMENSIONAL RIFT",
		"arena_select_sub": "Each arena features distinct hazards, environmental modifiers, and threats",
		"arena_unlocked": "[ UNLOCKED ]",
		"arena_locked": "[ LOCKED ]",
		"arena_diff": "Difficulty: %s",
		"arena_btn_enter": "⚔ ENTER THE RIFT",
		"arena_btn_locked": "🔒 LOCKED",
		"arena_stats_header": "Arena Statistics:\n• Runs: %d\n• Wins: %d\n• Best Time: %02d:%02d\n• Enemies Slain: %d",
		"arena_features": "Features: ",
		"arena_threats": "Threats: ",

		# Arenas
		"arena_forest_name": "Forgotten Forest",
		"arena_forest_desc": "An ancient woodland slowly consumed by raw arcane rift energy.",
		"arena_necro_name": "Frost Necropolis",
		"arena_necro_desc": "An ancient crypt where residual cryogenic magic forged permanent permafrost with freezing hazards.",
		"arena_citadel_name": "Ash Citadel",
		"arena_citadel_desc": "A ruined fortress submerged in perpetual raging inferno and molten magma.",
		"arena_void_name": "Void Rift",
		"arena_void_desc": "An unstable hyperspace with broken geometry where reality unravels.",

		# Loading Screen
		"loading_tip_prefix": "Tip: ",
		"loading_tips": [
			"Combine elemental schools — fire upon a slowed target triggers a deadly steam rift.",
			"Level a spell to 5 and acquire its paired artifact to awaken its true evolution.",
			"In the Frost Necropolis, steer clear of permafrost patches to maintain your movement speed.",
			"Runic circles inscribed on the floor empower your spells while you remain inside.",
			"Fire cast upon static-charged enemies causes a catastrophic thermodynamic overload.",
			"Tome of Wisdom increases your XP pickup attraction radius and boosts experience gained.",
			"XP gems automatically condense into larger crystals when screen density grows high."
		],

		# Settings
		"settings_title": "⚙ SETTINGS",
		"settings_lang": "Language (Язык):",
		"settings_master": "Master Volume:",
		"settings_sfx": "SFX Volume:",
		"settings_fx": "Visual FX:",
		"settings_fx_full": "Standard (Full)",
		"settings_fx_reduced": "Reduced FX",
		"settings_shake": "Screen Shake:",
		"settings_shake_on": "Enabled",
		"settings_dmg_num": "Damage Numbers:",
		"settings_dmg_num_on": "Visible",
		"settings_vsync": "VSync:",
		"settings_vsync_on": "Enabled",

		# Pause
		"pause_title": "PAUSED",
		"pause_resume": "Resume",
		"pause_archive": "📖 Codex & Atlas",
		"pause_restart": "Restart Run",
		"pause_menu": "Main Menu",

		# HUD & Level Up
		"lvl_up_title": "LEVEL UP!",
		"lvl_up_sub": "Select one magical enhancement",
		"chest_title": "CHEST ARTIFACT",
		"chest_sub": "Choose one of three ancient relics",
		"toast_acquired": "Acquired: [%s]",
		"starter_tutorial": "✦ Move: [W, A, S, D] or Touch Joystick • Spells cast automatically",

		# Results Screen
		"results_victory": "RIFT SEALED! VICTORY",
		"results_defeat": "MAGE SLAIN",
		"results_space": "Realm: %s",
		"metric_time": "Survival Time:",
		"metric_lvl": "Level Reached:",
		"metric_kills": "Shadows Slain:",
		"metric_elites": "Elite Foes:",
		"metric_bosses": "Bosses Defeated:",
		"metric_damage": "Total Damage Dealt:",
		"metric_xp": "Mana Collected (XP):",
		"metric_artifacts": "Artifacts Held:",
		"metric_score": "Total Run Score:",
		"metric_barrier_absorbed": "Barrier Absorbed:",
		"metric_healing_done": "Health Restored:",
		"btn_reward_bonus": "✦ CLAIM +25% SCORE BONUS (WATCH AD)",
		"btn_reward_bonus_claimed": "✓ BONUS CLAIMED (+25%)",
		"synergy_share": "✦ Synergy Damage Contribution: %d%%",
		"synergy_star": "   |   Star Synergy: %s",
		"synergy_empty": "No elemental synergies were triggered during this run.\nCombine schools of magic to unleash devastating reactions!",
		"synergy_activations": "Activations: %d",
		"synergy_dmg": "Damage: %d",
		"synergy_impact": "Targets: %d | Kills: %d",
		"toast_synergy_unlocked": "✦ Synergy Discovered: [%s]!",

		# Second Chance
		"second_chance_title": "SECOND CHANCE",
		"second_chance_prompt": "The mage has fallen, but the ancient Rift offers resurrection!\nWatch a short ad to revive and continue this run with 50% health.",
		"second_chance_btn_watch": "✦ REVIVE VIA AD",
		"second_chance_btn_decline": "End Run",

		# Level formats
		"lvl_format": "Lv. %d",
		"lvl_prefix": "LV. %d",

		# Synergies
		"syn_resonance_name": "Arcane Resonance",
		"syn_resonance_desc": "Arcane strike on charged target creates resonance pulse",
		"syn_frost_shatter_name": "Frost Shatter",
		"syn_frost_shatter_desc": "Ice damage to slowed enemy shatters into sharp ice shards",
		"syn_lightning_chain_name": "Lightning Arc",
		"syn_lightning_chain_desc": "Chain lightning jumping between charged targets",
		"syn_unstable_explosion_name": "Unstable Explosion",
		"syn_unstable_explosion_desc": "Death of marked target triggers area explosion",
		"syn_steam_rift_name": "Steam Rift",
		"syn_steam_rift_desc": "Fire damage to slowed enemy spawns damaging steam cloud",
		"syn_thermal_conflagration_name": "Thermal Conflagration",
		"syn_thermal_conflagration_desc": "Fire damage to static-charged enemy triggers massive detonation",
		"syn_soul_harvest_name": "Soul Harvest",
		"syn_soul_harvest_desc": "Harvesting vitality from fallen enemies",
		"syn_returning_pierce_name": "Returning Rift",
		"syn_returning_pierce_desc": "Projectiles pierce enemies and return back to the caster",
		"syn_spatial_collapse_name": "Spatial Collapse",
		"syn_spatial_collapse_desc": "Arcane strike on unstable target collapses foes into a singularity implosion",
		"syn_cryogenic_shock_name": "Cryogenic Shock",
		"syn_cryogenic_shock_desc": "Lightning strike on slowed target shatters ice into conductive cryo-arcs",
		"syn_chain_of_doom_name": "Chain of Doom",
		"syn_chain_of_doom_desc": "Death of marked target transfers death mark to nearest enemy",
		"syn_runic_conductor_name": "Runic Conductor",
		"syn_runic_conductor_desc": "Lightning while standing in Rune Zone triggers radial electrical discharge",
		"syn_conflagration_execution_name": "Conflagration Execution",
		"syn_conflagration_execution_desc": "Fire attack on marked target triggers flame detonation, spreading burn and mark",
		"syn_charged_bolt_name": "Charged Bolt",
		"syn_charged_bolt_desc": "Magic bolt on charged target energizes, dealing amplified damage and chain arcs",
		"syn_thunder_shield_name": "Thunder Shield",
		"syn_thunder_shield_desc": "When barrier absorbs incoming hit, discharges retaliatory lightning zap at attacker",
		"syn_glacial_ward_name": "Glacial Ward",
		"syn_glacial_ward_desc": "When barrier shatters, unleashes absolute wave of frost freezing nearby enemies",
		"syn_life_harvest_name": "Life Harvest",
		"syn_life_harvest_desc": "Death of marked foe releases healing essences that restore player health",
		"syn_blazing_blades_name": "Blazing Blades",
		"syn_blazing_blades_desc": "Runic blades ignite with magma, dealing +30% damage and setting enemies ablaze",
		"syn_piercing_frost_name": "Piercing Frost",
		"syn_piercing_frost_desc": "Magic bolts pierce slowed enemies cleanly and inflict critical bonus damage",

		# Spells & Artifacts
		"spell_magic_barrier_name": "Magic Barrier",
		"spell_magic_barrier_desc": "Passive runic shield absorbing incoming damage and detonating shockwave on break",
		"spell_font_of_life_name": "Font of Life",
		"spell_font_of_life_desc": "Gradual health regeneration and healing shockwave pulse every 20 kills",
		"art_life_crystal_name": "Life Crystal",
		"art_life_crystal_desc": "+35 max health and +20% to all healing and regeneration efficiency",
		"art_warding_rune_name": "Warding Rune",
		"art_warding_rune_desc": "+20% Magic Barrier shield health and -1.0s to barrier recharge cooldown",

		# Codex / Archive
		"codex_sec_spells": "BASE SPELLS (%d/%d)",
		"codex_sec_evolutions": "SUPREME EVOLUTIONS (%d/%d)",
		"codex_sec_synergies": "ELEMENTAL SYNERGIES & REACTIONS (%d/%d)",
		"codex_sec_artifacts": "ARTIFACTS & RELICS (%d/%d)",
		"codex_sec_atlas": "RIFT ATLAS: CHALLENGES & REWARDS (%d/%d)",
		"codex_unknown_spell": "??? Unknown Spell",
		"codex_unknown_spell_desc": "Level up and discover scrolls to unlock this magical school.",
		"codex_unknown_evo": "??? Hidden Transmutation",
		"codex_unknown_evo_desc": "Requires a Lv 5 spell and a resonant artifact.",
		"codex_unknown_syn": "??? Hidden Synergy",
		"codex_unknown_syn_desc": "Combine different elemental schools in battle to discover.",
		"codex_unknown_art": "??? Sealed Artifact",
		"codex_unknown_art_desc": "Defeat elite foes and discover rift treasure chests.",
		"codex_badge_evo": "★ EVOLUTION ★",
		"codex_badge_syn": "SYNERGY",
		"codex_badge_art": "ARTIFACT",
		"codex_badge_done": "[✓ COMPLETED]",
		"codex_badge_progress": "[✕ IN PROGRESS]",
		"codex_school_prefix": "[School: %s]",
		"codex_req_prefix": "Requirement: %s\n%s",
		"codex_formula_prefix": "Formula: %s\n%s",
		"codex_reward_prefix": "%s\nReward: %s",

		# Orientation warning
		"rotate_device_warning": "Please rotate your device to landscape mode for optimal gameplay.",

		# Meta Shop & Progression
		"shop_title": "RIFT SHOP: PERMANENT UPGRADES",
		"shop_progress_fmt": "Overall Progress: %d / %d (%d%%) • Maxed: %d / %d",
		"shop_cat_progress_fmt": "%s (%d/%d)",
		"shop_buy_btn": "UPGRADE\n🪙 %d",
		"shop_btn_maxed": "MAXED",
		"shop_btn_locked": "LOCKED",
		"shop_insufficient_gold": "Not enough gold",
		"shop_effect_fmt": "Current bonus: %s  ➜  Next: %s",
		"shop_effect_max_fmt": "Effect: %s (MAXIMUM)",
		"shop_effect_none": "None",
		"menu_shop": "🏛 UPGRADE SHOP",
		"menu_char_card_title": "🧙 Rift Wizard",
		"menu_char_lvl_fmt": "Lv. %d",
		"menu_char_xp_fmt": "Wizard XP: %d / %d XP",
		"menu_char_bonus_fmt": "Magic Bolt: %s to base damage",
		"menu_char_bonus_base": "Magic Bolt: base form"
	}
}

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Priority 1: Explicit user-selected setting
	var user_choice = SaveManager.get_setting("user_selected_language", "")
	if user_choice is String and not user_choice.is_empty() and user_choice in ["ru", "en"]:
		current_language = user_choice
		return

	# Priority 2: Saved language setting in save file
	var saved_lang = SaveManager.get_setting("language", "")
	if saved_lang is String and not saved_lang.is_empty() and saved_lang in ["ru", "en"]:
		current_language = saved_lang
		return

	# Priority 3: System language (CIS -> ru, else en)
	var sys_lang = OS.get_locale_language().to_lower()
	current_language = "ru" if sys_lang in ["ru", "be", "uk", "kk", "ky", "uz"] else "en"

func set_language(lang: String, is_user_action: bool = true) -> void:
	var clean = "ru" if lang.to_lower().begins_with("ru") else "en"
	current_language = clean
	SaveManager.set_setting("language", clean)
	if is_user_action:
		SaveManager.set_setting("user_selected_language", clean)
	language_changed.emit(clean)

func get_text(key: String, fallback: String = "") -> String:
	var dict = STRINGS.get(current_language, STRINGS["ru"])
	if dict.has(key):
		return dict[key]
	var ru_dict = STRINGS["ru"]
	if ru_dict.has(key):
		return ru_dict[key]
	return fallback if not fallback.is_empty() else key

func get_random_tip() -> String:
	var dict = STRINGS.get(current_language, STRINGS["ru"])
	var tips = dict.get("loading_tips", STRINGS["ru"]["loading_tips"])
	var prefix = dict.get("loading_tip_prefix", "Совет: ")
	return prefix + tips[randi() % tips.size()]
