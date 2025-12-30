extends Object


class InterfaceBaseInst:
	@warning_ignore("unused_private_class_variable")
	static var _base_interface_instance: InterfaceBase

	static func clear_cache() -> void:
		_base_interface_instance = null

	static func _get_base_instance() -> InterfaceBase:
		if not _base_interface_instance:
			_base_interface_instance = InterfaceBase.new()
		return _base_interface_instance


class ScriptEnt:
	# scr_sourceの更新時刻(unix-time)
	var file_time: int = 0

	# Resourceに元々存在しているメソッドなどを省いたもの
	var method_a: Array = []
	var property_a: Array = []
	var signal_a: Array = []

	static func _get_file_time(res: Resource) -> int:
		var path := res.resource_path
		if path.is_empty():
			return 0
		return FileAccess.get_modified_time(path)

	static func _array_subtract(source_array: Array, subtract_array: Array) -> Array:
		var ret: Array = []
		for src in source_array:
			var found := false
			for sub in subtract_array:
				if src.name == sub.name:
					found = true
					break
			if not found:
				ret.append(src)
		return ret

	## ベース情報の準備とキャッシュ構築
	## @param cache_dic タイプ別キャッシュ辞書
	## @param interface_type インタフェーススクリプト型
	## @param getter 対象情報取得コールバック
	## @param checker フィルタリング用チェックコールバック
	## @return キャッシュ配列
	static func _prepare_base(
		interface_type: Script,
		getter_func: Callable,
		filter_func: Callable = func(_a: Dictionary): return true
	) -> Array:
		var tmp_obj: Object = interface_type.new()
		assert(tmp_obj != null, "interface_type.new() returned null")
		var base_inst := InterfaceBaseInst._get_base_instance()
		var ar := _array_subtract(
			# 対象ObjectからGetした物
			getter_func.call(tmp_obj),
			# InterfaceBaseからGetした物
			getter_func.call(base_inst)
		)
		# フィルタリングした結果を返す
		return ar.filter(filter_func)

	func _update(scr: Script) -> void:
		method_a = _prepare_base(
			scr,
			func(obj: Object): return obj.get_method_list(),
			func(m: Dictionary): return not m.name.begins_with("@"),
		)
		property_a = _prepare_base(
			scr,
			func(obj: Object): return obj.get_property_list(),
			func(p: Dictionary): return not p.name.ends_with(".gd"),
		)
		signal_a = _prepare_base(
			scr,
			func(obj: Object): return obj.get_signal_list(),
		)

	func check_update(scr: Script) -> void:
		var cur_time := _get_file_time(scr)
		if file_time < cur_time:
			file_time = cur_time
			_update(scr)


static var _cache: Dictionary[Script, ScriptEnt] = {}


# ------------- [Public Static Method] -------------
static func clear_cache() -> void:
	_cache.clear()
	InterfaceBaseInst.clear_cache()


static func prepare_cache(interface_type: Script) -> ScriptEnt:
	if not interface_type in _cache:
		_cache[interface_type] = ScriptEnt.new()
	var ent := _cache[interface_type]
	ent.check_update(interface_type)
	return ent
