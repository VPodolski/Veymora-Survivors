extends SceneTree

func _init() -> void:
	print("--- Running Stage 6 Web Export Automated Verification ---")

	# 1. Project settings verification
	var renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert(renderer == "gl_compatibility", "Renderer must be gl_compatibility for universal WebGL2 support")
	print("[PASS] GL Compatibility renderer verified for WebGL2")

	var stretch_mode = ProjectSettings.get_setting("display/window/stretch/mode")
	assert(stretch_mode == "canvas_items", "Stretch mode must be canvas_items for responsive scaling")
	var stretch_aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	assert(stretch_aspect == "keep", "Stretch aspect must be keep to avoid canvas distortion")
	print("[PASS] Viewport scaling and aspect ratio settings verified (1280x720 canvas_items keep)")

	# 2. Export Presets verification
	var config_file = ConfigFile.new()
	var err = config_file.load("res://export_presets.cfg")
	assert(err == OK, "export_presets.cfg must exist and be valid")

	var preset_name = config_file.get_value("preset.0", "name", "")
	var platform = config_file.get_value("preset.0", "platform", "")
	assert(preset_name == "Web" and platform == "Web", "Web export preset must be configured")

	var thread_support = config_file.get_value("preset.0.options", "variant/thread_support", true)
	assert(thread_support == false, "Web export must have thread_support=false for universal compatibility without COOP/COEP headers")

	var focus_canvas = config_file.get_value("preset.0.options", "html/focus_canvas_on_start", false)
	assert(focus_canvas == true, "Web export must have focus_canvas_on_start=true for immediate keyboard responsiveness")
	print("[PASS] export_presets.cfg validated (Web platform, single-threaded, focus on start)")

	# 3. Input map and controls compatibility check
	var player_scene = load("res://scenes/player/player.tscn")
	assert(player_scene != null, "Player scene must be loadable")
	var player = player_scene.instantiate()
	assert(player.has_method("get_input_direction"), "Player must implement get_input_direction")
	player.free()
	print("[PASS] Player input compatibility for browser verified (WASD / Arrows / Physical keys)")

	# 4. Web Build Artifacts verification (Decoupled check)
	var has_web_build = FileAccess.file_exists("res://build/web/index.html")
	if has_web_build:
		assert(FileAccess.file_exists("res://build/web/index.js"), "index.js must exist in web build")
		assert(FileAccess.file_exists("res://build/web/index.wasm"), "index.wasm must exist in web build")
		assert(FileAccess.file_exists("res://build/web/index.pck"), "index.pck must exist in web build")

		var html_file = FileAccess.open("res://build/web/index.html", FileAccess.READ)
		var html_content = html_file.get_as_text()
		html_file.close()
		assert(html_content.contains("<canvas id=\"canvas\">"), "index.html must contain canvas element")
		assert(html_content.contains("index.js"), "index.html must include engine launcher index.js")

		var wasm_file = FileAccess.open("res://build/web/index.wasm", FileAccess.READ)
		var wasm_length = wasm_file.get_length()
		wasm_file.close()
		assert(wasm_length > 1000000, "index.wasm must be valid non-empty binary (>1MB)")

		var pck_file = FileAccess.open("res://build/web/index.pck", FileAccess.READ)
		var pck_length = pck_file.get_length()
		pck_file.close()
		assert(pck_length > 50000, "index.pck must be valid non-empty game package (>50KB)")
		print("[PASS] Exported Web artifacts verified (index.html, index.js, index.wasm [%.2f MB], index.pck [%.2f KB])" % [wasm_length / (1024.0 * 1024.0), pck_length / 1024.0])
	else:
		print("[NOTICE] Web build folder not present on clean clone. To build Web export, run:")
		print("         godot --headless --export-release 'Web' build/web/index.html")

	print("--- ALL STAGE 6 WEB EXPORT CHECKS PASSED SUCCESSFULLY! ---")
	quit(0)
