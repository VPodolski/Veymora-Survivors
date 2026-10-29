extends SceneTree

func _init() -> void:
	print("--- Running Stage 1 Automated Tests ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "Main scene must load")
	
	var main_node = main_scene.instantiate() as MainGame
	root.add_child(main_node)

	# 1. Test Player
	var player = main_node.get_node_or_null("Player") as PlayerController
	assert(player != null, "Player must exist in main scene")
	assert(player.is_in_group("player"), "Player must be in 'player' group")
	assert(player.current_health == 100.0, "Player should start with 100 HP")
	assert(player.stats != null, "Player stats should be assigned")
	assert(player.stats.move_speed > 0, "Player move speed should be > 0")
	print("[PASS] Player initialized correctly")

	# 2. Test Arena
	var arena = main_node.get_node_or_null("Arena") as Arena
	assert(arena != null, "Arena must exist in main scene")
	var walls = arena.get_node_or_null("Walls") as StaticBody2D
	assert(walls != null, "Arena walls must exist")
	print("[PASS] Arena and walls initialized correctly")

	# 3. Test HUD
	var hud = main_node.get_node_or_null("HUD") as HUDController
	assert(hud != null, "HUD must exist in main scene")
	assert(hud.hp_bar != null, "HUD HP Bar must exist")
	assert(hud.timer_label != null, "HUD Timer Label must exist")
	assert(hud.death_screen != null, "HUD Death Screen must exist")
	assert(!hud.death_screen.visible, "Death screen should be hidden initially")
	print("[PASS] HUD initialized correctly")

	# 4. Test Enemy Spawn & Chase Logic
	var spawner = main_node.get_node_or_null("SpawnManager") as SpawnManager
	assert(spawner != null, "SpawnManager must exist")
	
	# Spawn a test enemy at (100, 0)
	var enemy = spawner.spawn_enemy_at(Vector2(100, 0))
	assert(enemy != null, "Enemy should spawn")
	assert(enemy.is_in_group("enemies"), "Enemy must be in 'enemies' group")
	assert(enemy.stats != null, "Enemy stats must be loaded")
	assert(enemy.current_health == enemy.stats.max_health, "Enemy current HP must match max HP")

	# Simulate 1 frame of enemy AI
	enemy._physics_process(0.016)
	assert(enemy.velocity.x < 0, "Enemy should move towards player at (0,0)")
	print("[PASS] Enemy spawn and chase logic verified")

	# 5. Test Damage & Invulnerability & Death
	var initial_hp = player.current_health
	player.take_damage(20.0)
	assert(player.current_health == initial_hp - 20.0, "Player took 20 damage")
	assert(player.invulnerable_timer > 0.0, "Player has i-frames")

	# Taking damage while invulnerable should be ignored
	player.take_damage(20.0)
	assert(player.current_health == initial_hp - 20.0, "Player didn't take damage during i-frames")

	# Clear invulnerability and apply fatal damage
	player.invulnerable_timer = 0.0
	player.take_damage(100.0)
	assert(player.current_health == 0.0, "Player health reduced to 0")
	assert(!player.is_alive, "Player is marked dead")
	assert(hud.death_screen.visible, "Death screen became visible on death")
	print("[PASS] Damage, i-frames, and death lifecycle verified")

	print("--- ALL STAGE 1 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

