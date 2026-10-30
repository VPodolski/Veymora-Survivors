class_name LoadingScreen
extends Control

const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const TIPS = [
	"Совет: Сочетайте разные школы магии — огонь по замедленной цели создаёт смертоносный паровой разлом.",
	"Совет: Развейте заклинание до 5 уровня и найдите парный артефакт, чтобы пробудить его истинную эволюцию.",
	"Совет: В Ледяном некрополе избегайте морозных очагов вечной мерзлоты, чтобы сохранять мобильность.",
	"Совет: Рунические круги на земле повышают силу ваших заклинаний, пока вы стоите внутри.",
	"Совет: Огонь по заряженному статикой врагу вызывает мощнейшую термодинамическую перегрузку.",
	"Совет: Фолиант мудрости увеличивает радиус притяжения сфер маны и повышает опыт.",
	"Совет: Сферы опыта конденсируются в более крупные кристаллы, если их становится слишком много."
]

@onready var arena_title_label: Label = $Center/VBox/ArenaTitleLabel
@onready var arena_subtitle_label: Label = $Center/VBox/ArenaSubtitleLabel
@onready var tip_label: Label = $Center/VBox/TipContainer/Margin/TipLabel
@onready var progress_bar: ProgressBar = $Center/VBox/ProgressBar
@onready var rune_spinner: Node2D = $Center/VBox/RuneCenter/RuneSpinner

var anim_time: float = 0.0
var load_progress: float = 0.0
var target_arena_cfg: ArenaConfig = null

func _ready() -> void:
	var arena_id = "forgotten_forest"
	if GameFlowController.instance:
		arena_id = GameFlowController.instance.get_run_config().arena_id

	target_arena_cfg = ArenaConfig.get_arena_config(arena_id)

	if arena_title_label:
		arena_title_label.text = target_arena_cfg.name.to_upper()
		arena_title_label.add_theme_color_override("font_color", target_arena_cfg.border_color)

	if arena_subtitle_label:
		arena_subtitle_label.text = "Сложность: %s   •   %s" % [target_arena_cfg.difficulty, target_arena_cfg.features[0]]

	if tip_label:
		tip_label.text = TIPS[randi() % TIPS.size()]

	# Smooth loading animation
	var tween = create_tween()
	tween.tween_property(self, "load_progress", 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.2)
	tween.tween_callback(_on_loading_complete)

func _process(delta: float) -> void:
	anim_time += delta
	if progress_bar:
		progress_bar.value = load_progress * 100.0

	if rune_spinner:
		rune_spinner.rotation = anim_time * 2.5
		rune_spinner.queue_redraw()

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if load_progress >= 0.7:
			_on_loading_complete()

func _on_loading_complete() -> void:
	set_process(false)
	if GameFlowController.instance:
		GameFlowController.instance.launch_game_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
