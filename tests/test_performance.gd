extends SceneTree

func _init() -> void:
	print("--- Running Veymora Survivors Performance Benchmark ---")
	call_deferred("run_benchmark")

func run_benchmark() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)
	current_scene = main_node
	await process_frame

	var spawner = main_node.spawn_manager
	spawner.is_spawning_active = false # manual control for benchmarking
	var enemy_scene = load("res://scenes/enemies/basic_enemy.tscn")

	var counts = [30, 60, 90, 120]
	for count in counts:
		# Clear existing
		for e in spawner.active_enemies:
			if is_instance_valid(e):
				e.queue_free()
		spawner.active_enemies.clear()
		await process_frame

		# Spawn batch
		for i in range(count):
			var angle = (float(i) / float(count)) * TAU
			var e = enemy_scene.instantiate() as EnemyController
			e.global_position = Vector2(cos(angle), sin(angle)) * randf_range(300.0, 600.0)
			main_node.add_child(e)
			spawner.active_enemies.append(e)

		# Warm up 5 frames
		for f in range(5):
			await process_frame

		# Measure 30 frames
		var start_time = Time.get_ticks_usec()
		var frames_measured = 30
		for f in range(frames_measured):
			await process_frame
		var elapsed_usec = Time.get_ticks_usec() - start_time

		var avg_frame_ms = (elapsed_usec / float(frames_measured)) / 1000.0
		var est_fps = 1000.0 / max(0.001, avg_frame_ms)

		var gem_count = root.get_tree().get_nodes_in_group("pickups").size()
		var proj_count = 0
		for child in main_node.get_children():
			if child is Projectile:
				proj_count += 1

		print("[BENCHMARK] Enemies: %3d | Frame Time: %6.2f ms | Est. FPS: %6.1f | Active Projectiles: %d | Gems: %d" % [
			count, avg_frame_ms, est_fps, proj_count, gem_count
		])

	# Size of Web export artifacts
	var wasm_file = FileAccess.open("res://build/web/index.wasm", FileAccess.READ)
	var wasm_size = wasm_file.get_length() if wasm_file else 0
	if wasm_file: wasm_file.close()

	var pck_file = FileAccess.open("res://build/web/index.pck", FileAccess.READ)
	var pck_size = pck_file.get_length() if pck_file else 0
	if pck_file: pck_file.close()

	print("[BENCHMARK] Web Build Size: WASM = %.2f MB, PCK = %.2f KB" % [
		wasm_size / (1024.0 * 1024.0), pck_size / 1024.0
	])

	print("--- PERFORMANCE BENCHMARK COMPLETE ---")
	quit(0)
