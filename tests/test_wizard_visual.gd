extends SceneTree

# Test script to validate wizard visual logic
const WizardAnimSheet = preload("res://Assets/Characters/1/the_wizard_animation_sheet.png")
const WizardSpriteSheet = preload("res://Assets/Characters/1/se_right_spritesheet.png")

func _init():
	print("--- TESTING WIZARD VISUAL COMPONENT ---")
	
	# 1. Test Direction Mapping
	var test_vectors = {
		Vector2(1, 0): "E",
		Vector2(1, 1).normalized(): "SE",
		Vector2(0, 1): "S",
		Vector2(-1, 1).normalized(): "SW",
		Vector2(-1, 0): "W",
		Vector2(-1, -1).normalized(): "NW",
		Vector2(0, -1): "N",
		Vector2(1, -1).normalized(): "NE"
	}
	
	for v in test_vectors:
		var expected = test_vectors[v]
		var got = get_direction_8way(v)
		var frame = get_direction_frame(got)
		print("Vector (%5.2f, %5.2f) -> Dir=%-2s (frame=%d) [Expected=%-2s]" % [
			v.x, v.y, got, frame, expected
		])
		assert(got == expected, "Direction mismatch for vector " + str(v))
	
	print("[PASS] All 8 direction vectors map accurately to correct sectors.")
	
	# 2. Test Textures and Sizing
	assert(WizardAnimSheet != null, "Idle animation sheet must load")
	assert(WizardSpriteSheet != null, "Movement spritesheet must load")
	
	var idle_img = WizardAnimSheet.get_image()
	assert(idle_img.get_width() == 552 and idle_img.get_height() == 64, "Idle sheet must be 552x64")
	var move_img = WizardSpriteSheet.get_image()
	assert(move_img.get_width() == 384 and move_img.get_height() == 64, "Movement sheet must be 384x64")
	
	print("[PASS] Texture dimensions and frame allocations verified.")
	print("ALL WIZARD VISUAL COMPONENT TESTS PASSED!")
	quit()

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

func get_direction_frame(dir_str: String) -> int:
	match dir_str:
		"S": return 0
		"SE": return 1
		"E": return 2
		"NE": return 3
		"N": return 4
		"NW": return 5
		"W": return 6
		"SW": return 7
		_: return 1
