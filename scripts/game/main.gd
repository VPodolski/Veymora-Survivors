class_name MainGame
extends Node2D

const RunStats = preload("res://scripts/game/run_stats.gd")
const MetaArchive = preload("res://scripts/game/meta_archive.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")

@onready var arena: Arena = $Arena
@onready var player: PlayerController = $Player
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var hud: HUDController = $HUD
@onready var experience_manager: ExperienceManager = $ExperienceManager
@onready var synergy_engine: SynergyEngine = $SynergyEngine

var run_stats: RunStats = RunStats.new()
var condensation_timer: float = 0.0

func _ready() -> void:
	ensure_audio_manager()
	ensure_input_mappings()

	if hud:
		hud.set_run_stats(run_stats)
		hud.restart_requested.connect(_on_restart_game)

	if player and hud:
		player.health_changed.connect(hud.update_health)
		player.died.connect(_on_player_died)
		if player.inventory:
			player.inventory.artifact_added.connect(hud.add_artifact_icon)
		hud.update_health(player.current_health, player.stats.max_health)

	if experience_manager and hud:
		experience_manager.experience_changed.connect(hud.update_experience)
		experience_manager.level_up.connect(_on_player_level_up)

	if spawn_manager:
		if hud:
			spawn_manager.boss_spawned.connect(hud.setup_boss_bar)
		spawn_manager.enemy_killed.connect(_on_enemy_killed)

	if synergy_engine:
		synergy_engine.reaction_triggered.connect(_on_reaction_triggered)

func ensure_audio_manager() -> void:
	if not AudioManager.instance:
		var am = AudioManager.new()
		am.name = "AudioManager"
		add_child(am)

func _process(delta: float) -> void:
	if not get_tree().paused:
		condensation_timer += delta
		if condensation_timer >= 2.0:
			condensation_timer = 0.0
			XPGem.condense_gems(get_tree(), 65)

		if run_stats.survival_time >= 300.0:
			MetaArchive.check_and_complete_goal("survive_5_min")

func _on_reaction_triggered(reaction_name: String, _pos: Vector2) -> void:
	MetaArchive.record_discovery("synergies", reaction_name)
	if reaction_name == "Чародейский резонанс" or reaction_name == "resonance":
		MetaArchive.check_and_complete_goal("first_resonance")
	elif reaction_name == "Паровой разлом" or reaction_name == "steam_rift":
		MetaArchive.check_and_complete_goal("first_steam_rift")

	if AudioManager.instance:
		AudioManager.instance.play_synergy()

func _on_enemy_killed(enemy: EnemyController) -> void:
	run_stats.record_kill(enemy)
	if hud:
		hud.register_kill(enemy)

	if run_stats.total_kills >= 1:
		MetaArchive.check_and_complete_goal("first_blood")

	if (enemy is BossController) or enemy.name.to_lower().contains("boss"):
		MetaArchive.check_and_complete_goal("defeat_colossus")

func _on_player_level_up(new_level: int) -> void:
	run_stats.level_reached = new_level
	if hud and player:
		hud.show_level_up(player, new_level)

func _on_player_died() -> void:
	if spawn_manager:
		spawn_manager.stop_spawning()
	if hud:
		hud.show_death_screen()

func _on_restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func ensure_input_mappings() -> void:
	_add_action_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("move_up", [KEY_W, KEY_UP])
	_add_action_if_missing("move_down", [KEY_S, KEY_DOWN])
	_add_action_if_missing("restart", [KEY_R])
	_add_action_if_missing("ui_cancel", [KEY_ESCAPE])

func _add_action_if_missing(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for code in keycodes:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action_name, event)
