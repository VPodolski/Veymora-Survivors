class_name PlayerVisual
extends Node2D

@export var use_wizard_sprite: bool = true:
	set(val):
		use_wizard_sprite = val
		if sprite_node:
			sprite_node.visible = val
		queue_redraw()

# Textures from Assets/Characters/1/
const IDLE_SHEET = preload("res://Assets/Characters/1/the_wizard_animation_sheet.png")
const MOVE_SHEET = preload("res://Assets/Characters/1/se_right_spritesheet.png")

# 8 Direction frame indices in se_right_spritesheet (S=0, SE=1, E=2, NE=3, N=4, NW=5, W=6, SW=7)
const DIR_FRAMES: Dictionary = {
	"S": 0,
	"SE": 1,
	"E": 2,
	"NE": 3,
	"N": 4,
	"NW": 5,
	"W": 6,
	"SW": 7
}

var facing_direction: Vector2 = Vector2.RIGHT
var is_flashing: bool = false
var flash_timer: float = 0.0
var anim_time: float = 0.0

var idle_frame_timer: float = 0.0
var idle_fps: float = 10.0
var walk_anim_timer: float = 0.0
var current_dir_name: String = "SE"
var is_moving: bool = false

var sprite_node: Sprite2D = null

func _ready() -> void:
	if use_wizard_sprite:
		_setup_wizard_sprite()

func _setup_wizard_sprite() -> void:
	if sprite_node == null:
		sprite_node = Sprite2D.new()
		sprite_node.name = "WizardSprite"
		sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_node.centered = true
		# Align feet (sprite y=62) with collision circle ground contact (world y=+12)
		sprite_node.position = Vector2(0, -18)
		add_child(sprite_node)
	_update_sprite_display(0.0)

func _process(delta: float) -> void:
	anim_time += delta * 4.0
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			modulate = Color.WHITE

	if use_wizard_sprite:
		_update_sprite_display(delta)
	
	queue_redraw()

func _update_sprite_display(delta: float) -> void:
	if not sprite_node:
		return
	
	# Determine if moving from parent CharacterBody2D velocity
	var parent_body = get_parent() as CharacterBody2D
	if parent_body:
		is_moving = parent_body.velocity.length_squared() > 4.0
	
	if is_moving:
		# Moving state: 8-directional sprite from movement sheet
		walk_anim_timer += delta * 12.0
		var walk_bob = sin(walk_anim_timer) * 1.5
		sprite_node.position = Vector2(0, -18 + walk_bob)
		
		sprite_node.texture = MOVE_SHEET
		sprite_node.hframes = 8
		sprite_node.vframes = 1
		sprite_node.flip_h = false # 8-way directional sprites are explicitly oriented
		
		current_dir_name = get_direction_8way(facing_direction)
		sprite_node.frame = DIR_FRAMES.get(current_dir_name, 1)
	else:
		# Idle state: 12-frame breathing animation loop
		idle_frame_timer += delta * idle_fps
		var frame_idx = int(floor(idle_frame_timer)) % 12
		sprite_node.position = Vector2(0, -18)
		
		sprite_node.texture = IDLE_SHEET
		sprite_node.hframes = 12
		sprite_node.vframes = 1
		sprite_node.frame = frame_idx
		# Face left (SW) if last moved left, otherwise face right (SE)
		sprite_node.flip_h = (facing_direction.x < -0.1)

func update_facing(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		facing_direction = dir.normalized()

func trigger_hit_flash(duration: float = 0.15) -> void:
	is_flashing = true
	flash_timer = duration
	modulate = Color(2.2, 0.5, 0.5, 1.0) # Hit flash

func get_direction_8way(dir: Vector2) -> String:
	var angle = fposmod(dir.angle(), TAU)
	var sector = int(floor((angle + (PI / 8.0)) / (PI / 4.0))) % 8
	match sector:
		0: return "E"
		1: return "SE"
		2: return "S"
		3: return "SW"
		4: return "W"
		5: return "NW"
		6: return "N"
		7: return "NE"
		_: return "SE"

func _draw() -> void:
	if use_wizard_sprite:
		# Draw subtle grounding shadow and magic rune floor circle under wizard's feet
		var aura_scale = 1.0 + sin(anim_time * 0.8) * 0.06
		# Soft dark ground shadow
		draw_circle(Vector2(0, 11), 13.0, Color(0.04, 0.05, 0.08, 0.40))
		# Glowing magic floor circle
		draw_arc(Vector2(0, 11), 16.0 * aura_scale, 0, TAU, 32, Color(0.25, 0.75, 1.0, 0.35), 1.6)
		draw_circle(Vector2(0, 11), 12.0 * aura_scale, Color(0.1, 0.35, 0.8, 0.10))
		return

	# --- PROCEDURAL FALLBACK (Original v0.3-v0.5 vector wizard) ---
	var bobbing = sin(anim_time) * 1.4

	# 1. Floor Magic Rune Circle
	var aura_scale = 1.0 + sin(anim_time * 0.8) * 0.07
	draw_arc(Vector2(0, 11), 18.0 * aura_scale, 0, TAU, 32, Color(0.2, 0.65, 1.0, 0.35), 1.6)
	draw_circle(Vector2(0, 11), 14.0 * aura_scale, Color(0.1, 0.35, 0.8, 0.10))

	# 2. Lower Robe (Flared skirt) & Hem
	var robe_pts = PackedVector2Array([
		Vector2(-10, 4 + bobbing),
		Vector2(10, 4 + bobbing),
		Vector2(14, 11 + bobbing),
		Vector2(0, 13 + bobbing),
		Vector2(-14, 11 + bobbing)
	])
	draw_colored_polygon(robe_pts, Color(0.11, 0.09, 0.22, 1.0))
	draw_polyline(PackedVector2Array([
		Vector2(-14, 11 + bobbing),
		Vector2(0, 13 + bobbing),
		Vector2(14, 11 + bobbing)
	]), Color(0.3, 0.85, 1.0, 0.85), 2.0)

	# Boots peeking out
	draw_rect(Rect2(-6, 12 + bobbing, 4, 3), Color(0.18, 0.12, 0.1, 1.0), true)
	draw_rect(Rect2(2, 12 + bobbing, 4, 3), Color(0.18, 0.12, 0.1, 1.0), true)

	# 3. Humanoid Torso & Shoulders
	var torso_pts = PackedVector2Array([
		Vector2(-12, -2 + bobbing),
		Vector2(12, -2 + bobbing),
		Vector2(10, 5 + bobbing),
		Vector2(-10, 5 + bobbing)
	])
	draw_colored_polygon(torso_pts, Color(0.14, 0.11, 0.26, 1.0))

	# Shoulder mantle & lapels
	var mantle_pts = PackedVector2Array([
		Vector2(-14, -2 + bobbing),
		Vector2(14, -2 + bobbing),
		Vector2(9, 2 + bobbing),
		Vector2(0, 4 + bobbing),
		Vector2(-9, 2 + bobbing)
	])
	draw_colored_polygon(mantle_pts, Color(0.18, 0.14, 0.32, 1.0))
	draw_line(Vector2(-13, -1 + bobbing), Vector2(0, 4 + bobbing), Color(0.35, 0.8, 1.0, 0.7), 1.5)
	draw_line(Vector2(13, -1 + bobbing), Vector2(0, 4 + bobbing), Color(0.35, 0.8, 1.0, 0.7), 1.5)

	# 4. Arms & Visible Hand with Focus Catalyst
	draw_line(Vector2(-12, -1 + bobbing), Vector2(-11, 6 + bobbing), Color(0.12, 0.09, 0.22, 1.0), 3.0)
	draw_line(Vector2(12, -1 + bobbing), Vector2(11, 6 + bobbing), Color(0.12, 0.09, 0.22, 1.0), 3.0)

	var hand_x = facing_direction.x * 9.0
	var hand_pos = Vector2(hand_x, 3.0 + bobbing)
	draw_circle(hand_pos, 2.2, Color(0.88, 0.76, 0.68, 1.0))

	var core_color = Color(0.3, 0.9, 1.0, 0.95)
	if is_flashing:
		core_color = Color(1.0, 0.25, 0.25, 1.0)
	var orb_pos = hand_pos + Vector2(facing_direction.x * 3.0, -1.0)
	draw_circle(orb_pos, 3.2, core_color)
	draw_circle(orb_pos, 1.4, Color.WHITE)

	# 5. High Collar & Neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4 + bobbing),
		Vector2(6, -4 + bobbing),
		Vector2(4, -1 + bobbing),
		Vector2(-4, -1 + bobbing)
	]), Color(0.1, 0.08, 0.2, 1.0))

	# 6. Anthropomorphic Head & Face
	draw_circle(Vector2(0, -7 + bobbing), 6.5, Color(0.2, 0.16, 0.28, 1.0))

	var face_pos = Vector2(facing_direction.x * 1.5, -6.5 + bobbing)
	draw_circle(face_pos, 5.0, Color(0.86, 0.75, 0.66, 1.0))

	var nose_dir = facing_direction.normalized()
	var nose_start = face_pos + Vector2(nose_dir.x * 2.0, -0.5)
	var nose_tip = face_pos + Vector2(nose_dir.x * 3.8, 0.5)
	draw_line(nose_start, nose_tip, Color(0.68, 0.55, 0.46, 0.85), 1.2)

	var eye_center_x = face_pos.x + nose_dir.x * 1.2
	var eye_y = -7.0 + bobbing
	var eye_sep = 2.2

	var left_eye = Vector2(eye_center_x - eye_sep, eye_y)
	var right_eye = Vector2(eye_center_x + eye_sep, eye_y)

	draw_circle(left_eye, 1.4, Color(0.95, 0.96, 1.0, 0.95))
	draw_circle(right_eye, 1.4, Color(0.95, 0.96, 1.0, 0.95))
	var pupil_offset = nose_dir * 0.5
	draw_circle(left_eye + pupil_offset, 0.9, Color(0.25, 0.85, 1.0, 1.0))
	draw_circle(right_eye + pupil_offset, 0.9, Color(0.25, 0.85, 1.0, 1.0))

	# 7. Iconic Wizard Hat
	var brim_y = -9.0 + bobbing
	var hat_brim_left = Vector2(-15, brim_y)
	var hat_brim_right = Vector2(15, brim_y)
	var hat_brim_center = Vector2(0, brim_y + 2.0)
	draw_colored_polygon(PackedVector2Array([hat_brim_left, hat_brim_right, hat_brim_center]), Color(0.12, 0.08, 0.22, 1.0))
	draw_line(hat_brim_left, hat_brim_right, Color(0.35, 0.82, 1.0, 0.9), 2.0)

	var hat_tip = Vector2(-facing_direction.x * 4.5, -24.0 + bobbing)
	var hat_cone = PackedVector2Array([
		Vector2(-9, brim_y),
		Vector2(9, brim_y),
		hat_tip
	])
	draw_colored_polygon(hat_cone, Color(0.15, 0.11, 0.28, 1.0))

	draw_line(hat_tip + Vector2(-3, 0), hat_tip + Vector2(3, 0), Color(1.0, 0.88, 0.35, 1.0), 1.6)
	draw_line(hat_tip + Vector2(0, -3), hat_tip + Vector2(0, 3), Color(1.0, 0.88, 0.35, 1.0), 1.6)
	draw_circle(hat_tip, 1.5, Color(1.0, 1.0, 0.8, 1.0))
