extends SceneTree

const MainScene = preload("res://scenes/main/main.tscn")
const BasicEnemyScene = preload("res://scenes/enemies/basic_enemy.tscn")

func _init() -> void:
	print("[EVIDENCE] Starting Arena Ground Texture Verification Capture...")
	
	var main_node = MainScene.instantiate()
	root.add_child(main_node)
	
	var spawn_mgr = main_node.get_node_or_null("SpawnManager") as SpawnManager
	if spawn_mgr:
		spawn_mgr.is_spawning_active = false
	
	var exp_mgr = main_node.get_node_or_null("ExperienceManager") as ExperienceManager
	if exp_mgr:
		exp_mgr.required_xp = 99999999
	
	var hud = main_node.get_node_or_null("HUD") as HUDController
	if hud and hud.level_up_panel:
		hud.level_up_panel.visible = false
	
	var player = main_node.get_node_or_null("Player") as PlayerController
	if not player:
		print("[ERROR] Player not found!")
		quit()
		return
	
	player.invulnerable_timer = 999.0
	
	# Wait for rendering to settle
	for f in range(15):
		await process_frame
	
	var img_gameplay = root.get_texture().get_image()
	img_gameplay.save_png("res://evidence/arena_ground_texture/01_ingame_arena_ground.png")
	print("[EVIDENCE] Saved 01_ingame_arena_ground.png")
	
	# Add surrounding enemies and spells
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		var dist = randf_range(80.0, 140.0)
		var e = BasicEnemyScene.instantiate() as EnemyController
		e.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		main_node.add_child(e)
	
	for f in range(12):
		await process_frame
	
	var img_combat = root.get_texture().get_image()
	img_combat.save_png("res://evidence/arena_ground_texture/02_ingame_combat_arena.png")
	print("[EVIDENCE] Saved 02_ingame_combat_arena.png")
	
	print("[EVIDENCE] Arena capture completed successfully!")
	quit()
