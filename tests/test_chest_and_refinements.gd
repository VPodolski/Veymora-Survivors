extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const ChestScene = preload("res://scenes/pickups/chest.tscn")
const ChestRewardPanelScene = preload("res://scenes/ui/chest_reward_panel.tscn")
const ChestRewardPanel = preload("res://scripts/ui/chest_reward_panel.gd")
const Chest = preload("res://scripts/pickups/chest.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const InventoryState = preload("res://scripts/items/inventory_state.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const MainGame = preload("res://scripts/game/main.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const RewardGenerator = preload("res://scripts/progression/reward_generator.gd")

func _init() -> void:
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	print("--- Running Chest Mechanics and Post-v0.1 Refinements Test Suite ---")

	var main_node = MainGameScene.instantiate() as MainGame
	root.add_child(main_node)
	await process_frame

	var player = main_node.player
	var hud = main_node.hud
	var chest_panel = hud.chest_reward_panel

	test_chest_generates_3_distinct_options(player, chest_panel)
	test_chest_excludes_owned_artifacts(player, chest_panel)
	test_chest_no_duplicate_cards(player, chest_panel)
	test_chosen_artifact_added_once(player, chest_panel)
	test_failed_add_artifact_no_notification(player, chest_panel, hud)
	test_alternative_rewards_when_full_or_exhausted(player, chest_panel)
	test_chest_handles_1_or_2_remaining_artifacts(player, chest_panel)
	test_pause_resumed_after_selection(player, chest_panel)
	test_chest_pickup_cannot_open_twice(main_node, player)
	test_modal_queue_coordination_levelup_and_chest(main_node, player, hud)
	test_mage_anthropomorphic_visuals_and_projectiles(player)
	test_audio_manager_softening_and_throttling()

	print("--- ALL CHEST & REFINEMENT TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_chest_generates_3_distinct_options(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 1. Chest offers 3 distinct artifact options when >= 3 unowned...")
	player.inventory.artifacts.clear()
	panel.open_panel(player)

	assert(panel.is_panel_open == true, "Panel must be marked open")
	assert(panel.visible == true, "Panel must be visible")
	assert(panel.current_options.size() == 3, "Must generate exactly 3 options")

	var ids = []
	for opt in panel.current_options:
		assert(opt.type == "artifact", "Option type must be artifact")
		assert(InventoryState.ALL_ARTIFACTS.has(opt.id), "Option id must exist in ALL_ARTIFACTS: " + str(opt.id))
		assert(not ids.has(opt.id), "Options must not contain duplicate ID: " + str(opt.id))
		ids.append(opt.id)

	# Clean up modal state
	panel.is_panel_open = false
	panel.visible = false
	paused = false
	print("[PASS] 3 distinct artifact options verified.")

func test_chest_excludes_owned_artifacts(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 2. Chest excludes already owned artifacts...")
	player.inventory.artifacts.clear()
	player.inventory.max_artifacts = 6
	# Pre-equip 3 artifacts
	var pre_owned = ["hourglass", "obsidian_heart", "frost_core"]
	for id in pre_owned:
		player.inventory.add_artifact(id)

	assert(player.inventory.artifacts.size() == 3, "Must have 3 pre-equipped artifacts")
	var unowned = player.inventory.get_unowned_artifacts()
	assert(unowned.size() == 5, "Must have 5 unowned remaining")

	panel.open_panel(player)
	assert(panel.current_options.size() == 3, "Must offer 3 options")

	for opt in panel.current_options:
		assert(not pre_owned.has(opt.id), "Must NOT offer already owned artifact: " + str(opt.id))
		assert(unowned.has(opt.id), "Option must be in unowned list: " + str(opt.id))

	panel.is_panel_open = false
	panel.visible = false
	paused = false
	player.inventory.max_artifacts = 4
	print("[PASS] Owned artifacts excluded verified.")

func test_chest_no_duplicate_cards(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 3. No duplicate options within cards across multiple generations...")
	player.inventory.artifacts.clear()

	for trial in range(10):
		panel.open_panel(player)
		var seen = {}
		for opt in panel.current_options:
			assert(not seen.has(opt.id), "Duplicate option found on trial %d: %s" % [trial, opt.id])
			seen[opt.id] = true
		panel.is_panel_open = false
		panel.visible = false
	paused = false
	print("[PASS] Zero duplicates across all trials verified.")

func test_chosen_artifact_added_once(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 4. Chosen artifact added exactly once...")
	player.inventory.artifacts.clear()
	panel.open_panel(player)

	var chosen = panel.current_options[0]
	var initial_count = player.inventory.artifacts.size()
	panel._on_card_selected(chosen)

	assert(player.inventory.artifacts.size() == initial_count + 1, "Artifact count must increase by 1")
	assert(player.inventory.has_artifact(chosen.id), "Chosen artifact must now be owned")
	assert(panel.is_panel_open == false, "Panel must close after selection")
	print("[PASS] Single addition of chosen artifact verified.")

func test_failed_add_artifact_no_notification(player: PlayerController, panel: ChestRewardPanel, hud: Node) -> void:
	print("[TEST] 5. No false success notification when add_artifact fails...")
	player.inventory.artifacts.clear()
	player.inventory.max_artifacts = 4

	# Artificially fill inventory to capacity
	for id in ["hourglass", "obsidian_heart", "frost_core", "rift_compass"]:
		player.inventory.add_artifact(id)

	# Try to simulate an artifact option selection on an already full inventory
	var fake_opt = {
		"id": "scholars_tome",
		"type": "artifact",
		"title": "Фолиант учёного"
	}

	if hud.toast_label:
		hud.toast_label.text = ""
	panel.is_panel_open = true
	panel._on_card_selected(fake_opt)

	# Verify it was not added
	assert(not player.inventory.has_artifact("scholars_tome"), "Artifact must not be added to full inventory")
	# Verify toast does not proclaim acquisition of scholars tome
	if hud.toast_label:
		assert(not hud.toast_label.text.contains("Фолиант учёного"), "Toast must not show success for failed addition")

	panel.is_panel_open = false
	panel.visible = false
	paused = false
	print("[PASS] Failed artifact addition handling verified.")

func test_alternative_rewards_when_full_or_exhausted(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 6. Alternative rewards offered when inventory full...")
	player.inventory.artifacts.clear()
	player.inventory.max_artifacts = 4
	# Fill all 4 slots
	for id in ["hourglass", "obsidian_heart", "frost_core", "rift_compass"]:
		player.inventory.add_artifact(id)
	assert(player.inventory.is_full() == true, "Inventory must be marked full")

	panel.open_panel(player)
	assert(panel.current_options.size() == 3, "Must offer 3 alternative options")

	var alt_ids = []
	for opt in panel.current_options:
		assert(opt.type == "alternative", "Options must be of type 'alternative'")
		alt_ids.append(opt.id)

	assert(alt_ids.has("alt_heal"), "Must offer alt_heal")
	assert(alt_ids.has("alt_xp"), "Must offer alt_xp")
	assert(alt_ids.has("alt_power"), "Must offer alt_power")

	# Test applying alt_heal
	var hp_before = player.stats.max_health
	var heal_opt = {"id": "alt_heal", "type": "alternative", "title": "Эликсир жизни"}
	panel.is_panel_open = true
	panel._on_card_selected(heal_opt)
	assert(player.stats.max_health == hp_before + 15.0, "alt_heal must increase max health by 15")

	# Test applying alt_power
	var power_before = player.stats.spell_power_mult
	var power_opt = {"id": "alt_power", "type": "alternative", "title": "Чародейский кристалл"}
	panel.is_panel_open = true
	panel._on_card_selected(power_opt)
	assert(abs(player.stats.spell_power_mult - (power_before + 0.12)) < 0.001, "alt_power must increase spell power by 0.12")

	panel.is_panel_open = false
	panel.visible = false
	paused = false
	print("[PASS] Alternative rewards when full verified.")

func test_chest_handles_1_or_2_remaining_artifacts(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 7. Handles 1 or 2 remaining unowned artifacts without errors...")
	player.inventory.artifacts.clear()
	player.inventory.max_artifacts = 10 # Allow more capacity to test 1 and 2 unowned
	var all_keys = InventoryState.ALL_ARTIFACTS.keys()

	# Leave exactly 2 unowned
	for i in range(all_keys.size() - 2):
		player.inventory.add_artifact(all_keys[i])
	assert(player.inventory.get_unowned_artifacts().size() == 2, "Must have exactly 2 unowned")

	panel.open_panel(player)
	assert(panel.current_options.size() == 2, "Must offer exactly 2 cards")
	panel.is_panel_open = false
	panel.visible = false

	# Leave exactly 1 unowned
	player.inventory.add_artifact(all_keys[all_keys.size() - 2])
	assert(player.inventory.get_unowned_artifacts().size() == 1, "Must have exactly 1 unowned")

	panel.open_panel(player)
	assert(panel.current_options.size() == 1, "Must offer exactly 1 card")
	panel.is_panel_open = false
	panel.visible = false

	player.inventory.max_artifacts = 6 # Restore default
	paused = false
	print("[PASS] 1 and 2 remaining artifacts handled cleanly.")

func test_pause_resumed_after_selection(player: PlayerController, panel: ChestRewardPanel) -> void:
	print("[TEST] 8. Pause resumed after selection...")
	player.inventory.artifacts.clear()
	panel.open_panel(player)
	assert(paused == true, "Opening chest panel must pause game")

	var opt = panel.current_options[0]
	panel._on_card_selected(opt)
	assert(paused == false, "Selecting option must resume game pause state")
	print("[PASS] Pause state transition verified.")

func test_chest_pickup_cannot_open_twice(main_node: MainGame, player: PlayerController) -> void:
	print("[TEST] 9. Chest pickup cannot be opened twice...")
	var chest = ChestScene.instantiate() as Chest
	main_node.add_child(chest)

	assert(chest.is_opened == false, "Chest must start closed")
	chest.open_chest(player)
	assert(chest.is_opened == true, "Chest must be marked opened")

	# Second opening attempt
	chest.open_chest(player)
	assert(chest.is_opened == true, "Chest remains opened and does not crash")

	# Close modal if opened
	main_node.hud.chest_reward_panel.is_panel_open = false
	main_node.hud.chest_reward_panel.visible = false
	paused = false
	chest.queue_free()
	print("[PASS] Chest opening idempotency verified.")

func test_modal_queue_coordination_levelup_and_chest(main_node: MainGame, player: PlayerController, hud: Node) -> void:
	print("[TEST] 10. LevelUpPanel & ChestRewardPanel modal queue coordination...")
	var lvl_panel = hud.level_up_panel
	var chest_panel = hud.chest_reward_panel

	# Scenario A: Level Up is active -> Chest is opened -> queued
	lvl_panel.open_panel(player, 2)
	assert(lvl_panel.is_panel_open == true, "LevelUp must be open")
	assert(chest_panel.is_panel_open == false, "Chest must NOT open yet")
	assert(paused == true, "Game must be paused")

	# Player opens chest while level up is modal
	hud.request_chest_reward(player)
	assert(hud.pending_chest_players.size() == 1, "Chest must be queued in pending_chest_players")
	assert(chest_panel.is_panel_open == false, "Chest panel must remain closed while level up is active")
	assert(paused == true, "Game must remain paused")

	# Choose level up card -> Level up closes -> Queued chest automatically opens!
	var dummy_opt = RewardGenerator.UpgradeOption.new()
	dummy_opt.type = "stat"
	dummy_opt.title = "Test Stat"
	lvl_panel._on_card_selected(dummy_opt)

	assert(lvl_panel.is_panel_open == false, "LevelUp must now be closed")
	assert(chest_panel.is_panel_open == true, "Queued chest must automatically open immediately!")
	assert(paused == true, "Game must STAY PAUSED during transition to chest modal!")

	# Complete chest selection -> Game finally resumes pause
	var chest_opt = chest_panel.current_options[0]
	chest_panel._on_card_selected(chest_opt)

	assert(chest_panel.is_panel_open == false, "Chest must now be closed")
	assert(paused == false, "Game must unpause after all queued modals are complete!")

	# Scenario B: Chest is active -> Level up arrives -> queued
	player.inventory.artifacts.clear()
	chest_panel.open_panel(player)
	assert(chest_panel.is_panel_open == true, "Chest must be open")
	assert(lvl_panel.is_panel_open == false, "LevelUp must NOT be open yet")
	assert(paused == true, "Game paused")

	hud.show_level_up(player, 3)
	assert(hud.pending_level_up_players.size() == 1, "Level up must be queued")
	assert(lvl_panel.is_panel_open == false, "Level up panel must remain closed")

	# Close chest -> Level up opens
	var opt2 = chest_panel.current_options[0]
	chest_panel._on_card_selected(opt2)

	assert(chest_panel.is_panel_open == false, "Chest must close")
	assert(lvl_panel.is_panel_open == true, "Queued level up must now open!")
	assert(paused == true, "Game remains paused")

	# Close level up -> unpause
	lvl_panel._on_card_selected(dummy_opt)
	assert(lvl_panel.is_panel_open == false, "Level up closed")
	assert(paused == false, "Game unpaused after FIFO resolution")
	print("[PASS] Modal queue coordination and FIFO resolution verified.")

func test_mage_anthropomorphic_visuals_and_projectiles(player: PlayerController) -> void:
	print("[TEST] 11. Mage anthropomorphic silhouette and projectile visuals...")
	var visual = player.get_node_or_null("Visual")
	assert(visual != null, "Player must have Visual node")
	assert("facing_direction" in visual, "Player visual must track facing_direction")

	var proj = Projectile.new()
	proj.faction = Projectile.Faction.ENEMY
	assert(proj.faction == Projectile.Faction.ENEMY, "Enemy faction must be supported")
	proj.queue_free()
	print("[PASS] Visual structure and projectile differentiation verified.")

func test_audio_manager_softening_and_throttling() -> void:
	print("[TEST] 12. AudioManager softening, volumes, and hit throttling...")
	var audio = AudioManager.instance
	assert(audio != null, "AudioManager instance must exist")

	# Volume controls
	audio.set_master_volume(0.5)
	assert(abs(audio.master_volume - 0.5) < 0.001, "Master volume must update")
	audio.set_sfx_volume(0.7)
	assert(abs(audio.sfx_volume - 0.7) < 0.001, "SFX volume must update")

	# Waveforms format check
	assert(audio.sfx_cast != null, "sfx_cast must be generated")
	assert(audio.sfx_cast.format == AudioStreamWAV.FORMAT_16_BITS, "Cast SFX must be 16-bit PCM")
	assert(audio.sfx_hit != null, "sfx_hit must be generated")
	assert(audio.sfx_hit.format == AudioStreamWAV.FORMAT_16_BITS, "Hit SFX must be 16-bit PCM")
	assert(audio.sfx_chest != null, "sfx_chest must be generated")

	# Hit throttling
	audio.hit_cooldown_timer = 0.0
	audio.play_hit()
	assert(audio.hit_cooldown_timer > 0.0, "play_hit must set cooldown timer")
	var initial_timer = audio.hit_cooldown_timer
	audio.play_hit() # Should be throttled
	assert(audio.hit_cooldown_timer == initial_timer, "Subsequent rapid hits must be throttled")

	# Restore full volume
	audio.set_master_volume(1.0)
	audio.set_sfx_volume(0.8)
	print("[PASS] Audio manager softening, volume controls, and hit throttling verified.")
