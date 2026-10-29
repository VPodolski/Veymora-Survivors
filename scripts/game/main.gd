class_name MainGame
extends Node2D

@onready var arena: Arena = $Arena
@onready var player: PlayerController = $Player
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var hud: HUDController = $HUD

func _ready() -> void:
	ensure_input_mappings()

	if player and hud:
		player.health_changed.connect(hud.update_health)
		player.died.connect(_on_player_died)
		# Initialize HUD with initial player stats
		hud.update_health(player.current_health, player.stats.max_health)

	if hud:
		hud.restart_requested.connect(_on_restart_game)

func _on_player_died() -> void:
	if spawn_manager:
		spawn_manager.stop_spawning()
	if hud:
		hud.show_death_screen()

func _on_restart_game() -> void:
	get_tree().reload_current_scene()

func ensure_input_mappings() -> void:
	# Guarantee input actions exist at runtime
	_add_action_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("move_up", [KEY_W, KEY_UP])
	_add_action_if_missing("move_down", [KEY_S, KEY_DOWN])
	_add_action_if_missing("restart", [KEY_R])

func _add_action_if_missing(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for code in keycodes:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action_name, event)

