extends SceneTree

const ArenaConfig = preload("res://scripts/arena/arena_config.gd")
const TexturePath = "res://Assets/Arenas/1/enchanted_ground_single_micro_1793704431717.jpg"

func _init():
	print("Testing arena texture loading...")
	assert(ResourceLoader.exists(TexturePath), "Texture file must exist!")
	var tex = load(TexturePath) as Texture2D
	assert(tex != null, "Texture must load as Texture2D!")
	print("Texture loaded successfully: ", tex.get_size())
	
	var arena_scn = preload("res://scenes/arena/arena.tscn")
	var arena = arena_scn.instantiate() as Arena
	root.add_child(arena)
	arena.ground_texture = tex
	arena.queue_redraw()
	print("Arena instantiated and ground_texture assigned.")
	quit()
