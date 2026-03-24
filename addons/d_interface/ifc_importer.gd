@tool
extends EditorImportPlugin


func _get_importer_name() -> String:
	return "d_interface.ifc_importer"


func _get_visible_name() -> String:
	return "Interface Definition"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["ifc"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 0


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array,
	_gen_files: Array
) -> Error:
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var text := file.get_as_text()

	# TextFileの代わりに標準のResourceを使用
	var resource := Resource.new()
	# メタデータとしてテキストを保持（エディタで開く際の参照用）
	resource.set_meta("content", text)
	# ソースパスを保持
	resource.resource_path = source_file

	return ResourceSaver.save(resource, "%s.%s" % [save_path, _get_save_extension()])
