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
		glow_time += delta * 3.5
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
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var container = get_tree().current_scene if get_tree().current_scene else get_tree().root
	CombatEffects.spawn_shockwave(container, global_position, 110.0, Color(1.0, 0.85, 0.25, 0.95))
	if AudioManager.instance:
		AudioManager.instance.play_chest()

	# Request reward modal via HUDController
	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0 and huds[0].has_method("request_chest_reward"):
		huds[0].request_chest_reward(player)
	else:
		# Fallback if HUD not found
		_fallback_reward(player)

	# Fade out chest
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _fallback_reward(player: PlayerController) -> void:
	if not player or not player.inventory:
		return
	var unowned = player.inventory.get_unowned_artifacts()
	if not unowned.is_empty() and not player.inventory.is_full():
		player.inventory.add_artifact(unowned[0])
	else:
		player.heal(40.0)

func _draw() -> void:
	var pulse = 1.0 + sin(glow_time) * 0.12

	# 1. Arcane beacon ground ring
	draw_arc(Vector2(0, 8), 24.0 * pulse, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.35), 1.8)
	draw_circle(Vector2(0, 8), 18.0 * pulse, Color(1.0, 0.8, 0.15, 0.12))

	# 2. Chest Base (Wood body)
	var body_rect = Rect2(-15, -4, 30, 16)
	draw_rect(body_rect, Color(0.18, 0.12, 0.08, 1.0), true) # Dark walnut
	draw_rect(body_rect, Color(0.9, 0.7, 0.2, 1.0), false, 2.0) # Gold rim

	# 3. Chest Curved Lid
	var lid_points = PackedVector2Array([
		Vector2(-16, -4),
		Vector2(-14, -13),
		Vector2(14, -13),
		Vector2(16, -4)
	])
	draw_colored_polygon(lid_points, Color(0.24, 0.15, 0.1, 1.0))
	draw_polyline(lid_points, Color(1.0, 0.8, 0.25, 1.0), 2.0)

	# 4. Vertical Gold Straps
	draw_line(Vector2(-7, -13), Vector2(-7, 12), Color(1.0, 0.85, 0.3, 1.0), 2.0)
	draw_line(Vector2(7, -13), Vector2(7, 12), Color(1.0, 0.85, 0.3, 1.0), 2.0)

	# 5. Glowing Lock Keyhole / Arcane Seal
	draw_circle(Vector2(0, 2), 4.5, Color(1.0, 0.85, 0.2, 1.0))
	draw_circle(Vector2(0, 2), 2.0, Color.WHITE)
