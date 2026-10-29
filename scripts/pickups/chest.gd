class_name Chest
extends Area2D

@export var is_opened: bool = false
var glow_time: float = 0.0

func _ready() -> void:
	add_to_group("chests")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not is_opened:
		glow_time += delta * 3.0
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if is_opened or not body.is_in_group("player"):
		return

	var player = body as PlayerController
	open_chest(player)

func open_chest(player: PlayerController) -> void:
	if is_opened:
		return
	is_opened = true

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 120.0, Color(1.0, 0.85, 0.2, 0.95))
	CombatEffects.spawn_text_popup(container, global_position, "СУНДУК СОКРОВИЩ!", Color(1.0, 0.9, 0.3, 1.0))

	# Award artifact or bonus
	var rewarded_item_name = ""
	if player and player.inventory:
		var unowned: Array[String] = []
		for art_id in InventoryState.ALL_ARTIFACTS.keys():
			if not player.inventory.has_artifact(art_id):
				unowned.append(art_id)

		if not unowned.is_empty():
			unowned.shuffle()
			var picked_id = unowned[0]
			player.inventory.add_artifact(picked_id)
			rewarded_item_name = InventoryState.ALL_ARTIFACTS[picked_id]["name"]
		else:
			# If all artifacts are collected: huge XP and heal
			player.heal(50.0)
			var exp_managers = get_tree().get_nodes_in_group("experience_manager")
			if exp_managers.size() > 0:
				exp_managers[0].add_experience(150)
			rewarded_item_name = "+150 XP и Лечение"

	# Notify HUD
	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0 and huds[0].has_method("show_chest_notification"):
		huds[0].show_chest_notification(rewarded_item_name)

	# Fade out chest
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var pulse = 1.0 + sin(glow_time) * 0.12

	# Golden aura
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(1.0, 0.8, 0.2, 0.25))

	# Chest base
	var base_rect = Rect2(-14, -10, 28, 20)
	draw_rect(base_rect, Color(0.18, 0.12, 0.08, 1.0), true) # Dark wood
	draw_rect(base_rect, Color(0.95, 0.75, 0.2, 1.0), false, 2.0) # Gold trim

	# Chest lock / core
	draw_circle(Vector2(0, 0), 4.5, Color(1.0, 0.85, 0.3, 1.0))
	draw_circle(Vector2(0, 0), 2.0, Color.WHITE)
