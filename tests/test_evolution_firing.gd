extends SceneTree

func _init() -> void:
	print("--- Running Evolution Firing Regression Test ---")
	call_deferred("run_test")

func run_test() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)

	var player = main_node.get_node_or_null("Player") as PlayerController
	assert(player != null, "Player must exist")

	await process_frame

	var bolt = player.ability_controller.get_ability("magic_bolt") as MagicBoltAbility
	assert(bolt != null, "Magic Bolt exists")

	# Give player Hourglass and evolve
	player.inventory.add_artifact("hourglass")
	bolt.current_level = 5
	bolt.evolve()
	assert(bolt.is_evolved, "Bolt is evolved")

	# Test actual firing of evolved projectiles
	bolt.fire_projectiles(Vector2.RIGHT)
	print("[PASS] Evolved projectile fired without any tag assignment errors!")

	# Simulate 5 physics frames
	for i in range(5):
		await process_frame

	print("--- EVOLUTION FIRING TEST PASSED! ---")
	quit(0)

