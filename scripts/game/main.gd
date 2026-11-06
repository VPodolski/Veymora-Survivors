class_name MainGame
extends Node2D

const RunStats = preload("res://scripts/game/run_stats.gd")
const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const MetaArchive = preload("res://scripts/game/meta_archive.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFlowController = preload("res://scripts/game/game_flow_controller.gd")
const MetaShopManager = preload("res://scripts/progression/meta_shop_manager.gd")

@onready var arena: Arena = $Arena
@onready var player: PlayerController = $Player
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var hud: HUDController = $HUD
@onready var experience_manager: ExperienceManager = $ExperienceManager
@onready var synergy_engine: SynergyEngine = $SynergyEngine

var run_stats: RunStats = RunStats.new()

func _ready() -> void:
	CombatEffects.set_fx_intensity(SaveManager.get_setting("fx_intensity", "standard"))
	ensure_audio_manager()
	ensure_input_mappings()

	var target_arena_id = "forgotten_forest"
	if GameFlowController.instance:
		target_arena_id = GameFlowController.instance.get_run_config().arena_id
	var cfg = ArenaConfig.get_arena_config(target_arena_id)
	run_stats.arena_id = target_arena_id
	run_stats.arena_name = cfg.name
	RunStats.active_stats = run_stats

	if arena:
		arena.apply_arena_config(cfg)

	if hud:
		hud.set_run_stats(run_stats)
		hud.restart_requested.connect(_on_restart_game)

	if player and hud:
		MetaShopManager.apply_shop_upgrades_to_player(player)
		player.health_changed.connect(hud.update_health)
		player.died.connect(_on_player_died)
		if hud.virtual_joystick:
			player.set_virtual_joystick(hud.virtual_joystick)
		if player.inventory:
			player.inventory.artifact_added.connect(hud.add_artifact_icon)
			player.inventory.artifact_added.connect(func(_art): run_stats.artifacts_collected += 1)
		hud.update_health(player.current_health, player.stats.max_health)
		if player.ability_controller:
			call_deferred("_sync_hud_spells")

	if experience_manager and hud:
		experience_manager.experience_changed.connect(hud.update_experience)
		experience_manager.experience_collected.connect(func(amt): run_stats.record_xp(amt))
		experience_manager.level_up.connect(_on_player_level_up)

	if spawn_manager:
		if hud:
			spawn_manager.boss_spawned.connect(hud.setup_boss_bar)
		spawn_manager.enemy_killed.connect(_on_enemy_killed)
		spawn_manager.enemy_spawned.connect(_on_enemy_spawned)
		for e in spawn_manager.active_enemies:
			_on_enemy_spawned(e)

	if synergy_engine:
		synergy_engine.reaction_triggered.connect(_on_reaction_triggered)
		synergy_engine.reaction_activated.connect(func(r_name, _pos, targets_count):
			run_stats.record_synergy_activation(r_name, targets_count)
		)
		synergy_engine.reaction_damage_detailed.connect(func(r_name, dmg, is_kill, is_dot):
			run_stats.record_synergy_damage(r_name, dmg, is_kill, is_dot)
		)

	call_deferred("_check_web_benchmark")

func _check_web_benchmark() -> void:
	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search")
		if search and ("benchmark=1" in str(search) or "benchmark=true" in str(search)):
			_run_web_benchmark()

func _run_web_benchmark() -> void:
	print("[BENCHMARK_WEB] Starting automated web benchmark in browser...")
	spawn_manager.is_spawning_active = false
	var benchmark_results: Dictionary = {}

	# Scenario 1: Start (0:00)
	print("[BENCHMARK_WEB] Running Scenario 1: Start of Run...")
	benchmark_results["scenario_1_start"] = await _exec_benchmark_scenario(1)

	# Scenario 2: Mid (~5:00)
	print("[BENCHMARK_WEB] Running Scenario 2: Mid-Game...")
	benchmark_results["scenario_2_mid"] = await _exec_benchmark_scenario(2)

	# Scenario 3: Late (~10-12:00)
	print("[BENCHMARK_WEB] Running Scenario 3: Late-Game...")
	benchmark_results["scenario_3_late"] = await _exec_benchmark_scenario(3)

	var json_str = JSON.stringify(benchmark_results)
	print("[BENCHMARK_BROWSER_DATA] " + json_str)
	JavaScriptBridge.eval("window.__BENCHMARK_RESULTS__ = " + json_str + "; window.__BENCHMARK_DONE__ = true;")

func _clear_benchmark_entities() -> void:
	for e in spawn_manager.active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	spawn_manager.active_enemies.clear()

	var pickups = get_tree().get_nodes_in_group("pickups")
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()

	for child in get_children():
		if child is Projectile:
			child.queue_free()

	for f in range(3):
		await get_tree().process_frame

func _exec_benchmark_scenario(scenario_id: int) -> Dictionary:
	await _clear_benchmark_entities()

	var basic_scene = load("res://scenes/enemies/basic_enemy.tscn")
	var fast_scene = load("res://scenes/enemies/fast_enemy.tscn")
	var heavy_scene = load("res://scenes/enemies/heavy_enemy.tscn")
	var ranged_scene = load("res://scenes/enemies/ranged_enemy.tscn")
	var elite_scene = load("res://scenes/enemies/elite_enemy.tscn")
	var boss_scene = load("res://scenes/enemies/boss_enemy.tscn")
	var gem_scene = load("res://scenes/pickups/xp_gem.tscn")

	if scenario_id == 1:
		player.current_health = 100.0
		_spawn_benchmark_enemy_ring(basic_scene, 12, 350.0, 500.0)
		_spawn_benchmark_gems(gem_scene, 5, 200.0)

	elif scenario_id == 2:
		player.current_health = 100.0
		_ensure_benchmark_ability("magic_bolt", 3)
		_ensure_benchmark_ability("fireball", 2)
		_ensure_benchmark_ability("magic_barrier", 2)
		_ensure_benchmark_ability("runic_blade", 2)
		_spawn_benchmark_enemy_ring(basic_scene, 30, 300.0, 550.0)
		_spawn_benchmark_enemy_ring(fast_scene, 10, 320.0, 580.0)
		_spawn_benchmark_enemy_ring(heavy_scene, 5, 280.0, 480.0)
		_spawn_benchmark_enemy_ring(ranged_scene, 5, 380.0, 600.0)
		var elite = elite_scene.instantiate() as EnemyController
		elite.global_position = Vector2(400, 0)
		add_child(elite)
		spawn_manager.active_enemies.append(elite)
		_spawn_benchmark_gems(gem_scene, 40, 350.0)

	elif scenario_id == 3:
		player.current_health = 100.0
		_ensure_benchmark_ability("magic_bolt", 5)
		_ensure_benchmark_ability("fireball", 4)
		_ensure_benchmark_ability("ice_storm", 3)
		_ensure_benchmark_ability("chain_lightning", 4)
		_ensure_benchmark_ability("font_of_life", 3)
		_ensure_benchmark_ability("magic_barrier", 4)
		_ensure_benchmark_ability("runic_blade", 4)

		_spawn_benchmark_enemy_ring(basic_scene, 55, 280.0, 620.0)
		_spawn_benchmark_enemy_ring(fast_scene, 20, 300.0, 650.0)
		_spawn_benchmark_enemy_ring(heavy_scene, 10, 260.0, 520.0)
		_spawn_benchmark_enemy_ring(ranged_scene, 10, 360.0, 640.0)

		for pos in [Vector2(450, 200), Vector2(-450, -200)]:
			var elite = elite_scene.instantiate() as EnemyController
			elite.global_position = pos
			add_child(elite)
			spawn_manager.active_enemies.append(elite)

		var boss = boss_scene.instantiate() as BossController
		boss.global_position = Vector2(0, -420)
		add_child(boss)
		spawn_manager.active_enemies.append(boss)
		spawn_manager.is_boss_alive = true

		_spawn_benchmark_gems(gem_scene, 100, 480.0)

	# 60 frames warmup
	for f in range(60):
		await get_tree().process_frame

	# 180 frames measurement
	var frame_times: Array[float] = []
	var process_times: Array[float] = []
	var physics_times: Array[float] = []
	var draw_calls: Array[float] = []
	var total_frames = 180

	for f in range(total_frames):
		var t_start = Time.get_ticks_usec()
		await get_tree().process_frame
		var frame_dur_ms = (Time.get_ticks_usec() - t_start) / 1000.0
		frame_times.append(frame_dur_ms)

		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	frame_times.sort()
	var sum_ft = 0.0
	for ft in frame_times:
		sum_ft += ft
	var avg_ft = sum_ft / float(frame_times.size())
	var peak_ft = frame_times[frame_times.size() - 1]
	var p99_idx = int(floor(float(frame_times.size()) * 0.99))
	var p99_ft = frame_times[clamp(p99_idx, 0, frame_times.size() - 1)]

	var avg_fps = 1000.0 / max(0.001, avg_ft)
	var p99_fps = 1000.0 / max(0.001, p99_ft)

	var avg_proc = 0.0
	for p in process_times: avg_proc += p
	avg_proc /= float(process_times.size())

	var avg_phys = 0.0
	for ph in physics_times: avg_phys += ph
	avg_phys /= float(physics_times.size())

	var avg_dc = 0.0
	for d in draw_calls: avg_dc += d
	avg_dc /= float(draw_calls.size())

	var active_enemies = spawn_manager.active_enemies.size()
	var active_gems = get_tree().get_nodes_in_group("pickups").size()
	var active_projectiles = 0
	for child in get_children():
		if child is Projectile:
			active_projectiles += 1

	var active_fx = CombatEffects.active_decorative_effects
	var total_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	return {
		"scenario_id": scenario_id,
		"avg_fps": avg_fps,
		"low_1pct_fps": p99_fps,
		"avg_frame_time_ms": avg_ft,
		"p99_frame_time_ms": p99_ft,
		"peak_frame_time_ms": peak_ft,
		"script_process_ms": avg_proc,
		"physics_process_ms": avg_phys,
		"avg_draw_calls": avg_dc,
		"active_enemies": active_enemies,
		"active_projectiles": active_projectiles,
		"active_gems": active_gems,
		"active_fx": active_fx,
		"total_nodes": total_nodes,
		"memory_mb": memory_mb
	}

func _ensure_benchmark_ability(ability_id: String, level: int) -> void:
	if not player or not player.ability_controller:
		return
	var ctrl = player.ability_controller
	var ab = ctrl.get_ability(ability_id)
	if not ab:
		ctrl.unlock_ability(ability_id)
		ab = ctrl.get_ability(ability_id)
	if ab:
		ab.current_level = level
		if ab.has_method("apply_level_modifiers"):
			ab.apply_level_modifiers()
		if level >= 5 and ab.has_method("apply_evolution"):
			ab.apply_evolution()

func _spawn_benchmark_enemy_ring(scene: PackedScene, count: int, r_min: float, r_max: float) -> void:
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var dist = randf_range(r_min, r_max)
		var e = scene.instantiate() as EnemyController
		e.global_position = Vector2(cos(angle), sin(angle)) * dist
		add_child(e)
		spawn_manager.active_enemies.append(e)

func _spawn_benchmark_gems(scene: PackedScene, count: int, radius: float) -> void:
	for i in range(count):
		var angle = randf() * TAU
		var dist = randf_range(60.0, radius)
		var g = scene.instantiate() as XPGem
		g.global_position = Vector2(cos(angle), sin(angle)) * dist
		g.xp_value = 10
		add_child(g)

func ensure_audio_manager() -> void:
	if not AudioManager.instance:
		var am = AudioManager.new()
		am.name = "AudioManager"
		add_child(am)

func _process(delta: float) -> void:
	if not get_tree().paused:
		if hud:
			run_stats.survival_time = hud.elapsed_time
		else:
			run_stats.survival_time += delta

		if run_stats.survival_time >= 300.0:
			MetaArchive.check_and_complete_goal("survive_5_min")
			# Unlock next arena (Frost Necropolis)
			SaveManager.unlock_arena("frost_necropolis")

func _on_enemy_spawned(_enemy: EnemyController) -> void:
	pass

func _on_reaction_triggered(reaction_name: String, _pos: Vector2) -> void:
	MetaArchive.record_discovery("synergies", reaction_name)
	if reaction_name == "Чародейский резонанс" or reaction_name == "resonance":
		MetaArchive.check_and_complete_goal("first_resonance")
	elif reaction_name == "Паровой разлом" or reaction_name == "steam_rift":
		MetaArchive.check_and_complete_goal("first_steam_rift")

	if hud and hud.has_method("notify_synergy"):
		hud.notify_synergy(reaction_name)

	if AudioManager.instance:
		AudioManager.instance.play_synergy(reaction_name)

func _on_enemy_killed(enemy: EnemyController) -> void:
	run_stats.record_kill(enemy)
	if hud:
		hud.register_kill(enemy)

	if run_stats.total_kills >= 1:
		MetaArchive.check_and_complete_goal("first_blood")

	if (enemy is BossController) or enemy.name.to_lower().contains("boss"):
		MetaArchive.check_and_complete_goal("defeat_colossus")
		SaveManager.unlock_arena("frost_necropolis")

func _sync_hud_spells() -> void:
	if hud and player and player.ability_controller:
		hud.update_active_spells(player.ability_controller)

func _on_player_level_up(new_level: int) -> void:
	run_stats.level_reached = new_level
	if hud and player:
		hud.show_level_up(player, new_level)
		_sync_hud_spells()

func _on_player_died() -> void:
	if spawn_manager:
		spawn_manager.stop_spawning()
	if hud:
		hud.trigger_player_death_flow(player)

func _on_restart_game() -> void:
	if GameFlowController.instance:
		GameFlowController.instance.restart_run()
	else:
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
