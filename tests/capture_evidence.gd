extends SceneTree

const MainScene = preload("res://scenes/main/main.tscn")
const BasicEnemyScene = preload("res://scenes/enemies/basic_enemy.tscn")
const FastEnemyScene = preload("res://scenes/enemies/fast_enemy.tscn")
const HeavyEnemyScene = preload("res://scenes/enemies/heavy_enemy.tscn")

func _init() -> void:
	print("[EVIDENCE] Starting Wizard Character Visual Evidence Capture...")
	
	var main_node = MainScene.instantiate()
	root.add_child(main_node)
	
	# Disable normal spawn manager during scripted capture
	var spawn_mgr = main_node.get_node_or_null("SpawnManager") as SpawnManager
	if spawn_mgr:
		spawn_mgr.is_spawning_active = false
	
	# Prevent level up modal from popping up over screenshots
	var exp_mgr = main_node.get_node_or_null("ExperienceManager") as ExperienceManager
	if exp_mgr:
		exp_mgr.required_xp = 99999999
	
	var hud = main_node.get_node_or_null("HUD") as HUDController
	if hud and hud.level_up_panel:
		hud.level_up_panel.visible = false
	
	var player = main_node.get_node_or_null("Player") as PlayerController
	if not player:
		print("[ERROR] Player not found in Main scene!")
		quit()
		return
	
	player.invulnerable_timer = 999.0
	
	DirAccess.make_dir_recursive_absolute("res://evidence/wizard_prototype/gif_frames")
	var gif_frame_idx = 0
	
	# --- 1. IDLE ANIMATION CAPTURE ---
	print("[EVIDENCE] 1. Capturing Wizard Idle Animation...")
	for f in range(12):
		await process_frame
	
	var img_idle = root.get_texture().get_image()
	img_idle.save_png("res://evidence/wizard_prototype/01_wizard_idle.png")
	print("[EVIDENCE] Saved 01_wizard_idle.png")
	
	# Record idle frames for GIF
	for f in range(14):
		await process_frame
		var img = root.get_texture().get_image()
		img.save_png("res://evidence/wizard_prototype/gif_frames/frame_%03d.png" % gif_frame_idx)
		gif_frame_idx += 1
	
	# --- 2. MOVEMENT CAPTURE ---
	print("[EVIDENCE] 2. Capturing Wizard Movement in Multiple Directions...")
	# Distinct directions: E, NE, N, NW, W, SW, S, SE
	var test_dirs = [
		{"dir": Vector2(1, 0), "name": "E", "steps": 12},
		{"dir": Vector2(1, -1).normalized(), "name": "NE", "steps": 10},
		{"dir": Vector2(0, -1), "name": "N", "steps": 10},
		{"dir": Vector2(-1, 0), "name": "W", "steps": 12},
		{"dir": Vector2(0, 1), "name": "S", "steps": 10},
		{"dir": Vector2(1, 1).normalized(), "name": "SE", "steps": 10}
	]
	
	var saved_moving = false
	for item in test_dirs:
		var md: Vector2 = item["dir"]
		_set_simulated_input(md)
		
		for f in range(item["steps"]):
			await process_frame
			
			if not saved_moving and item["name"] == "E" and f == 6:
				var img_mov = root.get_texture().get_image()
				img_mov.save_png("res://evidence/wizard_prototype/02_wizard_moving.png")
				saved_moving = true
				print("[EVIDENCE] Saved 02_wizard_moving.png (Direction: East, Frame: %d)" % player.visual_node.sprite_node.frame)
			
			var img = root.get_texture().get_image()
			img.save_png("res://evidence/wizard_prototype/gif_frames/frame_%03d.png" % gif_frame_idx)
			gif_frame_idx += 1
	
	_set_simulated_input(Vector2.ZERO)
	for f in range(8):
		await process_frame
	
	# --- 3. SURROUNDED BY ENEMIES CAPTURE ---
	print("[EVIDENCE] 3. Capturing Wizard Surrounded by Enemies...")
	for i in range(26):
		var angle = (float(i) / 26.0) * TAU
		var dist = randf_range(60.0, 100.0)
		var scn = BasicEnemyScene if (i % 3 != 0) else (FastEnemyScene if i % 2 == 0 else HeavyEnemyScene)
		var e = scn.instantiate() as EnemyController
		e.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		main_node.add_child(e)
		if spawn_mgr:
			spawn_mgr.active_enemies.append(e)
	
	for f in range(10):
		await process_frame
	
	var img_surrounded = root.get_texture().get_image()
	img_surrounded.save_png("res://evidence/wizard_prototype/03_wizard_surrounded.png")
	print("[EVIDENCE] Saved 03_wizard_surrounded.png")
	
	# --- 4. COMBAT WITH SPELL EFFECTS CAPTURE ---
	print("[EVIDENCE] 4. Capturing Wizard Combat with Active Spell Effects...")
	var ab_ctrl = player.ability_controller
	if ab_ctrl:
		ab_ctrl.unlock_ability("magic_bolt")
		ab_ctrl.unlock_ability("fireball")
		ab_ctrl.unlock_ability("ice_storm")
		ab_ctrl.unlock_ability("magic_barrier")
		ab_ctrl.unlock_ability("runic_blade")
		
		for ab in ab_ctrl.get_active_abilities():
			ab.current_level = 3
			if ab.has_method("apply_level_modifiers"):
				ab.apply_level_modifiers()
	
	# Keep LevelUpPanel hidden if triggered
	if hud and hud.level_up_panel:
		hud.level_up_panel.visible = false
	
	for f in range(28):
		# Enforce panel hidden during combat screenshot
		if hud and hud.level_up_panel and hud.level_up_panel.visible:
			hud.level_up_panel.visible = false
		
		await process_frame
		
		if f == 12:
			var img_combat = root.get_texture().get_image()
			img_combat.save_png("res://evidence/wizard_prototype/04_wizard_combat_spells.png")
			print("[EVIDENCE] Saved 04_wizard_combat_spells.png")
		
		if f % 2 == 0:
			var img = root.get_texture().get_image()
			img.save_png("res://evidence/wizard_prototype/gif_frames/frame_%03d.png" % gif_frame_idx)
			gif_frame_idx += 1
	
	print("[EVIDENCE] All evidence frames captured successfully (%d GIF frames)!" % gif_frame_idx)
	quit()

func _set_simulated_input(dir: Vector2) -> void:
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	if dir.x > 0.3:
		Input.action_press("ui_right")
	elif dir.x < -0.3:
		Input.action_press("ui_left")
	if dir.y > 0.3:
		Input.action_press("ui_down")
	elif dir.y < -0.3:
		Input.action_press("ui_up")
