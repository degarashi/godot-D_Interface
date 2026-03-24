@tool
extends EditorImportPlugin


func _get_importer_name() -> String:
	return "d_interface.ifc_importer"


func _get_visible_name() -> String:
	return "Interface Definition"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["ifc"])


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 0


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _get_save_extension() -> String:
	return "res"  # 拡張子だけ定義


func _import(source_file, save_path, _opt, _var, _gen) -> Error:
	# 空のリソースを保存して「インポート済み」という体裁だけ整える
	# (外部エディタの邪魔をしない)
	ResourceSaver.save(Resource.new(), "%s.%s" % [save_path, _get_save_extension()])
	return OK
