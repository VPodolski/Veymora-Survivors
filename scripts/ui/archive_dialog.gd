class_name ArchiveDialog
extends Control

signal closed

const MetaArchive = preload("res://scripts/game/meta_archive.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const InventoryState = preload("res://scripts/items/inventory_state.gd")
const LocalizationManager = preload("res://scripts/game/localization_manager.gd")

@onready var tab_spells_btn: Button = $Panel/VBox/TabButtons/SpellsTab
@onready var tab_synergies_btn: Button = $Panel/VBox/TabButtons/SynergiesTab
@onready var tab_artifacts_btn: Button = $Panel/VBox/TabButtons/ArtifactsTab
@onready var tab_atlas_btn: Button = $Panel/VBox/TabButtons/AtlasTab
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var content_container: VBoxContainer = $Panel/VBox/Scroll/Content

var current_tab: String = "spells"

const SPELLS_DATA = [
	{"id": "magic_bolt", "name": "Магическая стрела", "school": "Аркан", "desc": "Выпускает сгустки чародейской энергии в ближайших врагов."},
	{"id": "runic_blade", "name": "Рунический клинок", "school": "Аркан", "desc": "Вращающиеся клинки маны, создающие защитный периметр."},
	{"id": "ice_storm", "name": "Ледяной шторм", "school": "Лёд", "desc": "Морозная буря, замедляющая врагов и наносящая непрерывный урон."},
	{"id": "death_mark", "name": "Клеймо смерти", "school": "Нестабильность", "desc": "Помечает сильных врагов, усиливая получаемый урон и вызывая детонацию."},
	{"id": "fireball", "name": "Огненная сфера", "school": "Огонь", "desc": "Разрушительный шар пламени, поджигающий цели и создающий взрывную волну."},
	{"id": "lightning_strike", "name": "Грозовой разряд", "school": "Молния", "desc": "Небесная цепная молния, накладывающая статический заряд на группу врагов."}
]

const EVOLUTIONS_DATA = [
	{"id": "evolve_magic_bolt", "name": "Возвращающийся разлом", "req": "Магическая стрела 5 + Песочные часы", "desc": "Снаряды разлома пробивают всех врагов насквозь и возвращаются к магу."},
	{"id": "evolve_ice_storm", "name": "Абсолютный буран", "req": "Ледяной шторм 5 + Ледяное ядро", "desc": "Колоссальная снежная буря с увеличенным радиусом 230px и постоянной заморозкой."},
	{"id": "evolve_fireball", "name": "Инфернальная сверхновая", "req": "Огненная сфера 5 + Обсидиановое сердце", "desc": "Гигантская огненная звезда с бесконечным пробиванием и уроном 50."},
	{"id": "evolve_lightning", "name": "Ярость Небес", "req": "Грозовой разряд 5 + Громоотвод", "desc": "Штормовой каскад небесных молний (до 7 скачков, урон 45, интервал 1.4 сек)."}
]

const SYNERGIES_DATA = [
	{"id": "resonance", "name": "Чародейский резонанс", "formula": "Аркан + Статический заряд", "desc": "Удар арканом по заряженному врагу высвобождает дугу 25 урона."},
	{"id": "frost_shatter", "name": "Ледяные осколки", "formula": "Лёд + Замедленный враг", "desc": "Удар льдом по замедленной цели раскалывает её на 3 осколка."},
	{"id": "lightning_chain", "name": "Грозовая дуга", "formula": "Молния + Заряженный враг", "desc": "Цепной импульс перегружает цель электричеством."},
	{"id": "unstable_explosion", "name": "Взрыв нестабильности", "formula": "Метка смерти + Гибель цели", "desc": "Гибель помеченного врага вызывает взрыв по площади."},
	{"id": "steam_rift", "name": "Паровой разлом", "formula": "Огонь + Замедленный враг", "desc": "Огненный удар испаряет мороз, создавая густое облако пара с 20 урона/сек."},
	{"id": "thermal_conflagration", "name": "Термодинамическая перегрузка", "formula": "Огонь + Статический заряд", "desc": "Огонь по заряду вызывает мощнейшую тепловую вспышку 38 урона."},
	{"id": "returning_pierce", "name": "Возвратный разлом", "formula": "Магическая стрела + Песочные часы", "desc": "Чародейские снаряды пробивают врагов и летят обратно к магу, нанося повторные удары."}
]

const ARTIFACTS_DATA = [
	{"id": "amulet_of_haste", "name": "Амулет спешки", "desc": "+15% к скорости передвижения мага."},
	{"id": "obsidian_heart", "name": "Обсидиановое сердце", "desc": "+25% к урону всех заклинаний, ударная волна при получении урона."},
	{"id": "tome_of_wisdom", "name": "Фолиант мудрости", "desc": "+20% к радиусу сбора сфер опыта и +15% к получаемому XP."},
	{"id": "hourglass", "name": "Песочные часы", "desc": "-15% к перезарядке всех заклинаний. Ключ к эволюции Стрелы."},
	{"id": "frost_core", "name": "Ледяное ядро", "desc": "+25% к урону холода и длительности заморозки. Ключ к Бурану."},
	{"id": "phoenix_feather", "name": "Перо феникса", "desc": "Легендарное перо: один раз воскрешает мага с 60% HP при смертельном уроне."},
	{"id": "lightning_rod", "name": "Громоотвод", "desc": "+20% к шансу и урону цепных молний."},
	{"id": "scholars_tome", "name": "Фолиант учёного", "desc": "+1 дополнительный вариант выбора при повышении уровня."}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if tab_spells_btn:
		tab_spells_btn.pressed.connect(func(): _switch_tab("spells"))
	if tab_synergies_btn:
		tab_synergies_btn.pressed.connect(func(): _switch_tab("synergies"))
	if tab_artifacts_btn:
		tab_artifacts_btn.pressed.connect(func(): _switch_tab("artifacts"))
	if tab_atlas_btn:
		tab_atlas_btn.pressed.connect(func(): _switch_tab("atlas"))
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

	_refresh_current_tab()

func open_codex() -> void:
	visible = true
	_refresh_current_tab()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _switch_tab(tab: String) -> void:
	current_tab = tab
	_refresh_current_tab()

func _refresh_current_tab() -> void:
	if not content_container:
		return

	# Clear previous entries
	for child in content_container.get_children():
		child.queue_free()

	var archive = MetaArchive.get_archive_data()

	match current_tab:
		"spells":
			_render_spells_tab(archive)
		"synergies":
			_render_synergies_tab(archive)
		"artifacts":
			_render_artifacts_tab(archive)
		"atlas":
			_render_atlas_tab(archive)

func _render_spells_tab(archive: Dictionary) -> void:
	var loc = LocalizationManager.instance
	var spells = archive.get("spells", [])
	var evolutions = archive.get("evolutions", [])

	var sec_spells_fmt = loc.get_text("codex_sec_spells", "БАЗОВЫЕ ЗАКЛИНАНИЯ (%d/%d)") if loc else "БАЗОВЫЕ ЗАКЛИНАНИЯ (%d/%d)"
	_add_section_header(sec_spells_fmt % [spells.size(), SPELLS_DATA.size()])
	for s in SPELLS_DATA:
		var is_known = spells.has(s["id"])
		var unk_name = loc.get_text("codex_unknown_spell", "??? Неизведанное заклинание") if loc else "??? Неизведанное заклинание"
		var unk_desc = loc.get_text("codex_unknown_spell_desc", "Используйте свитки и повышайте уровень, чтобы открыть эту школу магии.") if loc else "Используйте свитки и повышайте уровень, чтобы открыть эту школу магии."
		var title = s["name"] if is_known else unk_name
		var desc = s["desc"] if is_known else unk_desc
		var color = Color(0.3, 0.8, 1.0) if is_known else Color(0.5, 0.5, 0.5)
		var school_fmt = loc.get_text("codex_school_prefix", "[Школа: %s]") if loc else "[Школа: %s]"
		_add_card(title, desc, school_fmt % s["school"], color, is_known)

	var sec_evo_fmt = loc.get_text("codex_sec_evolutions", "ВЫСШИЕ ЭВОЛЮЦИИ (%d/%d)") if loc else "ВЫСШИЕ ЭВОЛЮЦИИ (%d/%d)"
	_add_section_header(sec_evo_fmt % [evolutions.size(), EVOLUTIONS_DATA.size()])
	for e in EVOLUTIONS_DATA:
		var is_known = evolutions.has(e["id"])
		var unk_name = loc.get_text("codex_unknown_evo", "??? Скрытая трансмутация") if loc else "??? Скрытая трансмутация"
		var unk_desc = loc.get_text("codex_unknown_evo_desc", "Требуется заклинание 5-го уровня и резонирующий артефакт.") if loc else "Требуется заклинание 5-го уровня и резонирующий артефакт."
		var title = e["name"] if is_known else unk_name
		var req_fmt = loc.get_text("codex_req_prefix", "Условие: %s\n%s") if loc else "Условие: %s\n%s"
		var desc = (req_fmt % [e["req"], e["desc"]]) if is_known else unk_desc
		var color = Color(1.0, 0.85, 0.3) if is_known else Color(0.5, 0.5, 0.5)
		var evo_badge = loc.get_text("codex_badge_evo", "★ ЭВОЛЮЦИЯ ★") if loc else "★ ЭВОЛЮЦИЯ ★"
		_add_card(title, desc, evo_badge, color, is_known)

func _render_synergies_tab(archive: Dictionary) -> void:
	var loc = LocalizationManager.instance
	var discovered = archive.get("synergies", [])
	var sec_syn_fmt = loc.get_text("codex_sec_synergies", "МАГИЧЕСКИЕ СИНЕРГИИ И РЕАКЦИИ (%d/%d)") if loc else "МАГИЧЕСКИЕ СИНЕРГИИ И РЕАКЦИИ (%d/%d)"
	_add_section_header(sec_syn_fmt % [discovered.size(), SYNERGIES_DATA.size()])

	for syn in SYNERGIES_DATA:
		var is_known = discovered.has(syn["id"]) or discovered.has(syn["name"])
		var unk_name = loc.get_text("codex_unknown_syn", "??? Скрытая комбинация стихий") if loc else "??? Скрытая комбинация стихий"
		var unk_desc = loc.get_text("codex_unknown_syn_desc", "Комбинируйте эффекты разных стихий в бою, чтобы раскрыть резонанс.") if loc else "Комбинируйте эффекты разных стихий в бою, чтобы раскрыть резонанс."
		var title = syn["name"] if is_known else unk_name
		var formula_fmt = loc.get_text("codex_formula_prefix", "Формула: %s\n%s") if loc else "Формула: %s\n%s"
		var desc = (formula_fmt % [syn["formula"], syn["desc"]]) if is_known else unk_desc
		var color = Color(0.85, 0.45, 1.0) if is_known else Color(0.5, 0.5, 0.5)
		var syn_badge = loc.get_text("codex_badge_syn", "СИНЕРГИЯ") if loc else "СИНЕРГИЯ"
		_add_card(title, desc, syn_badge, color, is_known)

func _render_artifacts_tab(archive: Dictionary) -> void:
	var loc = LocalizationManager.instance
	var discovered = archive.get("artifacts", [])
	var all_arts = InventoryState.ALL_ARTIFACTS
	var sec_art_fmt = loc.get_text("codex_sec_artifacts", "АРТЕФАКТЫ И РЕЛИКВИИ (%d/%d)") if loc else "АРТЕФАКТЫ И РЕЛИКВИИ (%d/%d)"
	_add_section_header(sec_art_fmt % [discovered.size(), all_arts.size()])

	for art_id in all_arts.keys():
		var art = all_arts[art_id]
		var is_known = discovered.has(art_id)
		var unk_name = loc.get_text("codex_unknown_art", "??? Запечатанный артефакт") if loc else "??? Запечатанный артефакт"
		var unk_desc = loc.get_text("codex_unknown_art_desc", "Побеждайте элитных врагов и находите сокровищницы Разлома.") if loc else "Побеждайте элитных врагов и находите сокровищницы Разлома."
		var title = art["name"] if is_known else unk_name
		var desc = art["desc"] if is_known else unk_desc
		var color = art["color"] if is_known else Color(0.5, 0.5, 0.5)
		var art_badge = loc.get_text("codex_badge_art", "АРТЕФАКТ") if loc else "АРТЕФАКТ"
		var badge = art.get("rarity", art_badge) if is_known else art_badge
		_add_card(title, desc, badge, color, is_known)

func _render_atlas_tab(archive: Dictionary) -> void:
	var loc = LocalizationManager.instance
	var completed = archive.get("completed_goals", [])
	var sec_atlas_fmt = loc.get_text("codex_sec_atlas", "АТЛАС РАЗЛОМОВ: ИСПЫТАНИЯ И НАГРАДЫ (%d/%d)") if loc else "АТЛАС РАЗЛОМОВ: ИСПЫТАНИЯ И НАГРАДЫ (%d/%d)"
	_add_section_header(sec_atlas_fmt % [completed.size(), MetaArchive.ATLAS_GOALS.size()])

	for goal in MetaArchive.ATLAS_GOALS:
		var is_done = completed.has(goal["id"])
		var done_badge = loc.get_text("codex_badge_done", "[✓ ВЫПОЛНЕНО]") if loc else "[✓ ВЫПОЛНЕНО]"
		var prog_badge = loc.get_text("codex_badge_progress", "[✕ В ПРОЦЕССЕ]") if loc else "[✕ В ПРОЦЕССЕ]"
		var badge = done_badge if is_done else prog_badge
		var color = Color(1.0, 0.85, 0.2) if is_done else Color(0.7, 0.7, 0.7)
		var reward_fmt = loc.get_text("codex_reward_prefix", "%s\nНаграда: %s") if loc else "%s\nНаграда: %s"
		var desc = reward_fmt % [goal["desc"], goal["reward"]]
		_add_card(goal["title"], desc, badge, color, true)

func _add_section_header(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	content_container.add_child(label)

func _add_card(title: String, description: String, badge: String, color: Color, is_revealed: bool) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.15, 0.92) if is_revealed else Color(0.04, 0.05, 0.08, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color * 0.75
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var t_label = Label.new()
	t_label.text = title
	t_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_label.add_theme_font_size_override("font_size", 15)
	t_label.add_theme_color_override("font_color", color)
	hbox.add_child(t_label)

	var b_label = Label.new()
	b_label.text = badge
	b_label.add_theme_font_size_override("font_size", 12)
	b_label.add_theme_color_override("font_color", color)
	hbox.add_child(b_label)

	var d_label = Label.new()
	d_label.text = description
	d_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_label.add_theme_font_size_override("font_size", 13)
	d_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92) if is_revealed else Color(0.5, 0.5, 0.5))
	vbox.add_child(d_label)

	content_container.add_child(panel)
