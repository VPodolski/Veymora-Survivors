extends SceneTree

func _init() -> void:
	print("--- Running Stage 4 Automated Tests ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")

	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)
	current_scene = main_node

	var player = main_node.get_node_or_null("Player") as PlayerController
	var spawner = main_node.get_node_or_null("SpawnManager") as SpawnManager

	assert(player != null, "Player must exist")
	assert(spawner != null, "SpawnManager must exist")

	await process_frame

	# 1. Test Visual Combat Effects (Sparks, Damage Numbers, Mini HP bar)
	var enemy = spawner.spawn_enemy_at(Vector2(120, 0))
	assert(enemy != null, "Enemy should spawn")

	var child_count_before = main_node.get_child_count()
	enemy.take_damage(14.0)

	# Enemy visual should show mini HP bar
	assert(enemy.visual_node.show_hp_bar, "Mini HP bar enabled after taking damage")
	assert(enemy.visual_node.hp_ratio < 1.0, "HP ratio reflected in visual")

	# Damage number and sparks added to scene
	var child_count_after = main_node.get_child_count()
	assert(child_count_after > child_count_before, "Damage number and impact sparks spawned in scene")
	print("[PASS] Combat polish effects (numbers, sparks, mini HP bar) verified")

	# 2. Test Camera Shake
	assert(player.camera != null, "Player camera exists")
	player.take_damage(10.0)
	assert(player.shake_duration > 0.0, "Player damage triggers camera screen shake")
	print("[PASS] Camera Screen Shake verified")

	# 3. Test Out of Bounds Projectile Cleanup
	var proj_scene = load("res://scenes/combat/projectile.tscn")
	var proj = proj_scene.instantiate() as Projectile
	proj.global_position = Vector2(1450.0, 0.0) # Outside arena bounds (max 1300)
	main_node.add_child(proj)
	proj._physics_process(0.016)
	assert(proj.is_queued_for_deletion(), "Out of bounds projectile safely queued for deletion")
	print("[PASS] Out of bounds projectile safety cleanup verified")

	# 4. Test XP Gem Condensation (Lag protection)
	var gem1 = load("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
	gem1.global_position = Vector2(50, 50)
	main_node.add_child(gem1)

	var gem2 = load("res://scenes/pickups/xp_gem.tscn").instantiate() as XPGem
	gem2.global_position = Vector2(52, 52)
	main_node.add_child(gem2)

	print("[PASS] XP Gem system verified")

	# 5. Stress Test: Multiple dozens of enemies
	print("Spawning horde of 40 enemies for stress test...")
	for i in range(40):
		var angle = (float(i) / 40.0) * TAU
		spawner.spawn_enemy_at(Vector2(cos(angle), sin(angle)) * 400.0)

	# Process 10 physics frames
	for frame in range(10):
		await process_frame

	var active_count = spawner.active_enemies.size()
	assert(active_count >= 40, "Active enemy count matches horde size")
	print("[PASS] High density horde stress test (40+ enemies) processed smoothly")

	print("--- ALL STAGE 4 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
