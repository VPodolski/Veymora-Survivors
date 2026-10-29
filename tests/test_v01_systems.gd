extends SceneTree

const MainGameScene = preload("res://scenes/main/main.tscn")
const FastEnemyScene = preload("res://scenes/enemies/fast_enemy.tscn")
const HeavyEnemyScene = preload("res://scenes/enemies/heavy_enemy.tscn")
const RangedEnemyScene = preload("res://scenes/enemies/ranged_enemy.tscn")
const FireballScene = preload("res://scenes/abilities/fireball.tscn")
const LightningScene = preload("res://scenes/abilities/lightning_strike.tscn")
const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")
const ArchiveDialogScene = preload("res://scenes/ui/archive_dialog.tscn")

const FastEnemyController = preload("res://scripts/enemies/fast_enemy_controller.gd")
const HeavyEnemyController = preload("res://scripts/enemies/heavy_enemy_controller.gd")
const RangedEnemyController = preload("res://scripts/enemies/ranged_enemy_controller.gd")
const FireballAbility = preload("res://scripts/abilities/fireball_ability.gd")
const LightningAbility = preload("res://scripts/abilities/lightning_ability.gd")
const IceStormAbility = preload("res://scripts/abilities/ice_storm_ability.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const ArchiveDialog = preload("res://scripts/ui/archive_dialog.gd")
const SpawnConfig = preload("res://scripts/resources/spawn_config.gd")

const MetaArchive = preload("res://scripts/game/meta_archive.gd")
const SaveManager = preload("res://scripts/game/save_manager.gd")
const StatusEffects = preload("res://scripts/combat/status_effects.gd")

func _init() -> void:
	call_deferred("run_all_v01_tests")

func run_all_v01_tests() -> void:
	print("--- Running Version 0.1 Full Systems Automated Verification Suite ---")

	test_enemy_taxonomy()
	test_new_spells_and_upgrades()
	test_burning_status_and_new_synergies()
	test_evolutions_and_artifacts()
	test_phoenix_feather_revival()
	test_meta_archive_and_atlas()
	test_menus_and_archive_dialog()

	print("--- ALL VERSION 0.1 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_enemy_taxonomy() -> void:
	print("[TEST] 1. Enemy taxonomy & archetypes verification...")

	# Fast enemy
	var fast = FastEnemyScene.instantiate() as FastEnemyController
	assert(fast != null, "Fast enemy must instantiate")
	self.root.add_child(fast)
	assert(fast.stats != null, "Fast enemy stats must be initialized on ready")
	assert(fast.stats.move_speed > 130.0, "Fast enemy should have high speed (>130)")
	assert(fast.stats.max_health < 25.0, "Fast enemy should be fragile (<25 HP)")
	fast.queue_free()

	# Heavy enemy
	var heavy = HeavyEnemyScene.instantiate() as HeavyEnemyController
	assert(heavy != null, "Heavy enemy must instantiate")
	self.root.add_child(heavy)
	assert(heavy.stats != null, "Heavy enemy stats must be initialized on ready")
	assert(heavy.stats.move_speed < 60.0, "Heavy enemy should be slow (<60)")
	assert(heavy.stats.max_health >= 70.0, "Heavy enemy should be durable (>=70 HP)")
	heavy.queue_free()

	# Ranged enemy
	var ranged = RangedEnemyScene.instantiate() as RangedEnemyController
	assert(ranged != null, "Ranged enemy must instantiate")
	self.root.add_child(ranged)
	assert(ranged.stats != null, "Ranged enemy stats must be initialized on ready")
	assert(ranged.shoot_cooldown > 0.0, "Ranged enemy must have shoot cooldown")
	ranged.queue_free()

	# Dynamic composition based on elapsed run time
	var sm = SpawnManager.new()
	sm.enemy_scene = preload("res://scenes/enemies/basic_enemy.tscn")
	sm.fast_enemy_scene = FastEnemyScene
	sm.heavy_enemy_scene = HeavyEnemyScene
	sm.ranged_enemy_scene = RangedEnemyScene
	var early_scene = sm.get_enemy_scene_for_time(60.0)
	var mid_scene = sm.get_enemy_scene_for_time(200.0)
	var late_scene = sm.get_enemy_scene_for_time(400.0)
	assert(early_scene != null and mid_scene != null and late_scene != null, "SpawnManager must resolve enemy scenes for all phases")
	sm.free()

	print("[PASS] Enemy taxonomy (Fast, Heavy, Ranged, Dynamic Spawning) verified.")

func test_new_spells_and_upgrades() -> void:
	print("[TEST] 2. New spells (Fireball, Lightning Strike) verification...")

	var main = MainGameScene.instantiate() as MainGame
	self.root.add_child(main)

	var ac = main.player.ability_controller
	assert(ac != null, "Ability controller must exist")

	# Unlock Fireball
	var fireball = ac.unlock_ability("fireball") as FireballAbility
	assert(fireball != null, "Fireball ability must unlock")
	assert(fireball.ability_id == "fireball", "Fireball ID verified")
	var base_dmg = fireball.base_damage
	fireball.upgrade()
	assert(fireball.current_level == 2, "Fireball level upgrade verified")
	assert(fireball.base_damage > base_dmg, "Fireball damage must increase with upgrade")

	# Unlock Lightning Strike
	var lightning = ac.unlock_ability("lightning_strike") as LightningAbility
	assert(lightning != null, "Lightning ability must unlock")
	assert(lightning.ability_id == "lightning_strike", "Lightning ID verified")
	assert(lightning.tags.has("lightning"), "Lightning tags verified")
	lightning.upgrade()
	assert(lightning.current_level == 2, "Lightning level upgrade verified")

	main.queue_free()
	print("[PASS] Spells unlocking and upgrading verified.")

func test_burning_status_and_new_synergies() -> void:
	print("[TEST] 3. Burning status and Steam Rift / Thermal Conflagration synergies...")

	var enemy = FastEnemyScene.instantiate() as FastEnemyController
	self.root.add_child(enemy)

	# Test Burning DoT
	assert(StatusEffects.STATUS_BURNING == "burning", "Burning status constant defined")
	enemy.apply_status(StatusEffects.STATUS_BURNING, 3.0)
	assert(enemy.has_status(StatusEffects.STATUS_BURNING), "Enemy must have burning status")
	var hp_before = enemy.current_health
	enemy.update_statuses(0.55)
	assert(enemy.current_health < hp_before, "Burning status must inflict damage over time")

	# Test Steam Rift Synergy: Fire hits slowed enemy
	var syn_engine = SynergyEngine.new()
	self.root.add_child(syn_engine)

	var reaction_box = {"name": ""}
	syn_engine.reaction_triggered.connect(func(name, _pos): reaction_box["name"] = name)

	enemy.apply_status(StatusEffects.STATUS_SLOWED, 3.0)
	var ctx = ReactionContext.new(null, enemy, ["fire", "projectile"], enemy.global_position, 20.0, 0)
	syn_engine.on_hit_landed(ctx)

	assert(reaction_box["name"] == "steam_rift", "Steam Rift reaction must trigger on Fire + Slowed (Got: %s)" % reaction_box["name"])

	# Test Thermal Conflagration Synergy: Fire hits charged enemy
	var enemy2 = HeavyEnemyScene.instantiate() as HeavyEnemyController
	self.root.add_child(enemy2)
	reaction_box["name"] = ""
	enemy2.apply_status(StatusEffects.STATUS_CHARGED, 3.0)
	var ctx2 = ReactionContext.new(null, enemy2, ["fire", "projectile"], enemy2.global_position, 20.0, 0)
	syn_engine.on_hit_landed(ctx2)

	assert(reaction_box["name"] == "thermal_conflagration", "Thermal Conflagration must trigger on Fire + Charged (Got: %s)" % reaction_box["name"])

	syn_engine.queue_free()
	enemy.queue_free()
	enemy2.queue_free()
	print("[PASS] Burning status and new synergies verified.")

func test_evolutions_and_artifacts() -> void:
	print("[TEST] 4. Spell evolutions and artifact mechanics...")

	var main = MainGameScene.instantiate() as MainGame
	self.root.add_child(main)
	var p = main.player
	var ac = p.ability_controller
	var inv = p.inventory

	# Test Evolution 2: Ice Storm (Lv 5) + Frost Core -> Blizzard Cataclysm
	var storm = ac.unlock_ability("ice_storm") as IceStormAbility
	for i in range(4): storm.upgrade()
	assert(storm.current_level == 5, "Ice Storm must be level 5")
	inv.add_artifact("frost_core")
	assert(inv.has_artifact("frost_core"), "Inventory must contain Frost Core")

	var choices = RewardGenerator.generate_choices(p, 3)
	var has_storm_evo = false
	for opt in choices:
		if opt.id == "evolve_ice_storm":
			has_storm_evo = true
			RewardGenerator.apply_upgrade(p, opt)
			break
	assert(has_storm_evo, "RewardGenerator must offer Blizzard Cataclysm evolution")
	assert(storm.is_evolved, "Ice Storm must be marked evolved")
	assert(storm.zone_radius >= 200.0, "Evolved storm must have expanded radius")

	# Test Evolution 3: Fireball (Lv 5) + Obsidian Heart -> Infernal Supernova
	var fireball = ac.unlock_ability("fireball") as FireballAbility
	for i in range(4): fireball.upgrade()
	assert(fireball.current_level == 5, "Fireball must be level 5")
	inv.add_artifact("obsidian_heart")
	assert(inv.has_artifact("obsidian_heart"), "Inventory must contain Obsidian Heart")

	var choices2 = RewardGenerator.generate_choices(p, 3)
	var has_fireball_evo = false
	for opt in choices2:
		if opt.id == "evolve_fireball":
			has_fireball_evo = true
			RewardGenerator.apply_upgrade(p, opt)
			break
	assert(has_fireball_evo, "RewardGenerator must offer Infernal Supernova evolution")
	assert(fireball.is_evolved, "Fireball must be marked evolved")
	assert(fireball.base_damage >= 50.0, "Evolved fireball must have boosted base damage (>=50)")

	main.queue_free()
	print("[PASS] Spell evolutions and artifact synergy prerequisites verified.")

func test_phoenix_feather_revival() -> void:
	print("[TEST] 5. Phoenix Feather revival artifact verification...")

	var p_scene = preload("res://scenes/player/player.tscn")
	var player = p_scene.instantiate() as PlayerController
	self.root.add_child(player)

	assert(player.inventory != null, "Player inventory must be initialized")
	player.inventory.add_artifact("phoenix_feather")
	assert(player.phoenix_revives_remaining == 1, "Phoenix feather should grant 1 revive")

	var death_state = {"emitted": false}
	player.died.connect(func(): death_state["emitted"] = true)

	# Inflict lethal damage
	player.take_damage(500.0)

	assert(player.is_alive, "Player must remain alive after Phoenix Feather triggers")
	assert(!death_state["emitted"], "died signal must NOT be emitted on Phoenix Feather revival")
	assert(player.phoenix_revives_remaining == 0, "Phoenix revive count must consume to 0")
	assert(player.current_health > 30.0, "Player HP should be restored after revival")

	# Next lethal hit must kill player
	player.invulnerable_timer = 0.0
	player.take_damage(500.0)
	assert(!player.is_alive, "Player must die after revives are exhausted")
	assert(death_state["emitted"], "died signal must emit on true death")

	player.queue_free()
	print("[PASS] Phoenix Feather revival and death prevention verified.")

func test_meta_archive_and_atlas() -> void:
	print("[TEST] 6. MetaArchive discoveries & Rift Atlas goals...")

	# Clear or set clean test state
	var data = SaveManager.get_default_data()
	SaveManager.save_custom_data(data)

	# Record discovery
	MetaArchive.record_discovery("spells", "fireball")
	MetaArchive.record_discovery("synergies", "Паровой разлом")
	MetaArchive.record_discovery("artifacts", "frost_core")

	var archive = MetaArchive.get_archive_data()
	assert(archive["spells"].has("fireball"), "Fireball discovery recorded")
	assert(archive["synergies"].has("Паровой разлом"), "Steam Rift discovery recorded")
	assert(archive["artifacts"].has("frost_core"), "Frost Core discovery recorded")

	# Test Goal completion
	assert(!MetaArchive.is_goal_completed("first_blood"), "Goal initially incomplete")
	var completed = MetaArchive.check_and_complete_goal("first_blood")
	assert(completed, "Goal completion should return true on first achievement")
	assert(MetaArchive.is_goal_completed("first_blood"), "Goal is now marked completed")

	# Re-completing should return false
	var re_completed = MetaArchive.check_and_complete_goal("first_blood")
	assert(!re_completed, "Re-completing goal should return false (idempotent)")

	print("[PASS] MetaArchive discoveries and Rift Atlas persistence verified.")

func test_menus_and_archive_dialog() -> void:
	print("[TEST] 7. Main Menu, Pause Menu & Archive Dialog UI...")

	# Main Menu
	var menu = MainMenuScene.instantiate() as MainMenu
	assert(menu != null, "MainMenu scene must instantiate cleanly")
	self.root.add_child(menu)
	assert(menu.start_btn != null, "Start button must exist in MainMenu")
	assert(menu.archive_btn != null, "Archive button must exist in MainMenu")
	assert(menu.controls_btn != null, "Controls button must exist in MainMenu")
	menu.queue_free()

	# Archive Dialog
	var archive_dlg = ArchiveDialogScene.instantiate() as ArchiveDialog
	assert(archive_dlg != null, "ArchiveDialog scene must instantiate cleanly")
	self.root.add_child(archive_dlg)
	archive_dlg.open_codex()
	assert(archive_dlg.visible, "ArchiveDialog must become visible on open_codex()")

	# Switch tabs and verify no errors
	archive_dlg._switch_tab("spells")
	assert(archive_dlg.content_container.get_child_count() > 0, "Spells tab must populate cards")
	archive_dlg._switch_tab("synergies")
	assert(archive_dlg.content_container.get_child_count() > 0, "Synergies tab must populate cards")
	archive_dlg._switch_tab("artifacts")
	assert(archive_dlg.content_container.get_child_count() > 0, "Artifacts tab must populate cards")
	archive_dlg._switch_tab("atlas")
	assert(archive_dlg.content_container.get_child_count() > 0, "Atlas tab must populate cards")

	archive_dlg.queue_free()
	print("[PASS] Main Menu and Archive Dialog UI verified.")
