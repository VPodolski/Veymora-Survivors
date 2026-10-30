class_name GameFlowController
extends Node

const RunConfig = preload("res://scripts/game/run_config.gd")
const RunStats = preload("res://scripts/game/run_stats.gd")

signal state_changed(new_state: String)

const STATE_MAIN_MENU = "main_menu"
const STATE_ARENA_SELECT = "arena_select"
const STATE_LOADING = "loading"
const STATE_PLAYING = "playing"
const STATE_PAUSED = "paused"
const STATE_RESULTS = "results"

var current_state: String = STATE_MAIN_MENU
var current_run_config: RunConfig = null
var last_run_stats: RunStats = null

static var instance: GameFlowController = null

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if current_run_config == null:
		current_run_config = RunConfig.new()

func get_run_config() -> RunConfig:
	if current_run_config == null:
		current_run_config = RunConfig.new()
	return current_run_config

func open_arena_select() -> void:
	get_tree().paused = false
	current_state = STATE_ARENA_SELECT
	state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/ui/arena_select.tscn")

func start_run_with_config(config: RunConfig) -> void:
	get_tree().paused = false
	current_run_config = config
	current_state = STATE_LOADING
	state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

func launch_game_scene() -> void:
	get_tree().paused = false
	current_state = STATE_PLAYING
	state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func open_results_screen(stats: RunStats) -> void:
	get_tree().paused = false
	last_run_stats = stats
	current_state = STATE_RESULTS
	state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/ui/results_screen.tscn")

func restart_run() -> void:
	get_tree().paused = false
	var next_config = current_run_config.duplicate_config() if current_run_config else RunConfig.new()
	start_run_with_config(next_config)

func go_to_main_menu() -> void:
	get_tree().paused = false
	current_state = STATE_MAIN_MENU
	state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
