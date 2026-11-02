@tool
extends EditorExportPlugin
class_name HTMLExportPlugin


var plugin_path: String = get_script().resource_path.get_base_dir()
var export_path: String
var _features: Array


func _get_name() -> String:
	return "Game Push"


func _export_begin(features: PackedStringArray,
		_is_debug: bool, path: String, _flags: int) -> void:
	export_path = path
	_features = features


func _export_end() -> void:
	if "web" in _features:
		var project_id := str(ProjectSettings.get_setting("game_push/config/project_id"))
		var public_token := ProjectSettings.get_setting("game_push/config/token")
		var is_archive := ProjectSettings.get_setting("game_push/config/is_archive", false)
		var archive_name := ProjectSettings.get_setting(
				"game_push/config/archive_name", "veymora_survivors_pikabu.zip"
				)
		var file := FileAccess.open(export_path, FileAccess.READ)
		if file:
			var html := file.get_as_text()
			file.close()
			if not html.contains("setGpInitCallback"):
				var pos = html.find('</head>')
				if pos != -1:
					html = html.insert(pos,
							'<script>\n' +
							'function setGpInitCallback(callback) {\n' +
							'	window.onGPInit = callback;\n' +
							'};\n' +
							'</script>\n')
					file = FileAccess.open(export_path, FileAccess.WRITE)
					if file:
						file.store_string(html)
						file.close()
		if is_archive:
			if !archive_name.ends_with(".zip"):
				archive_name = archive_name + ".zip"
			zip_export(archive_name)


func zip_export(name_file: String) -> void:
	var writer := ZIPPacker.new()
	var base_dir := export_path.get_base_dir()
	var archive_path: String = base_dir + "/" + name_file
	var err := writer.open(archive_path)
	if err != OK:
		push_error("Error open zip file: " + str(err))
		return
	var dir := DirAccess.open(base_dir)
	if not dir:
		push_error("Cannot open dir for zip: " + base_dir)
		writer.close()
		return
	var all_files = dir.get_files()
	for f in all_files:
		if f == name_file or f.ends_with(".zip") or f.ends_with(".import"):
			continue
		var file_path = base_dir + '/' + f
		var file_object = FileAccess.open(file_path, FileAccess.READ)
		if file_object:
			var file_content = file_object.get_buffer(file_object.get_length())
			file_object.close()
			writer.start_file(f)
			writer.write_file(file_content)
			writer.close_file()
	writer.close()

	# Also mirror to root build folder so paths in build/ and build/web_pikabu/ are consistent
	var parent_dir := base_dir.get_base_dir()
	if parent_dir and parent_dir != base_dir and DirAccess.dir_exists_absolute(parent_dir):
		var root_archive_path = parent_dir + "/" + name_file
		DirAccess.copy_absolute(archive_path, root_archive_path)
