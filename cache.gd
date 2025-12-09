extends Object

# ------------- [Private Variable] -------------
@warning_ignore("unused_private_class_variable")
static var _base_interface_instance: InterfaceBase

# Resourceに元々存在しているメソッドなどを省いたもの
static var _base_method: Dictionary[Script, Array] = {}
static var _base_property: Dictionary[Script, Array] = {}
static var _base_signal: Dictionary[Script, Array] = {}


# ------------- [Private Static Method] -------------
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
	cache_dic: Dictionary[Script, Array],
	interface_type: Script,
	getter_func: Callable,
	filter_func: Callable = func(_a: Dictionary): return true
) -> Array:
	if interface_type not in cache_dic:
		var tmp_obj: Object = interface_type.new()
		assert(tmp_obj != null, "interface_type.new() returned null")
		var base_inst := _prepare_base_instance()
		var ar := _array_subtract(
			# 対象ObjectからGetした物
			getter_func.call(tmp_obj),
			# InterfaceBaseからGetした物
			getter_func.call(base_inst)
		)
		# フィルタリングした結果を残す
		cache_dic[interface_type] = ar.filter(filter_func)
	return cache_dic[interface_type]


static func _prepare_base_instance() -> InterfaceBase:
	if not _base_interface_instance:
		_base_interface_instance = InterfaceBase.new()
	return _base_interface_instance


# ------------- [Public Static Method] -------------
static func clear_base_cache() -> void:
	_base_method.clear()
	_base_property.clear()
	_base_signal.clear()
	_base_interface_instance = null


static func prepare_base_method(interface_type: Script) -> Array:
	return _prepare_base(
		_base_method,
		interface_type,
		func(obj: Object): return obj.get_method_list(),
		func(m: Dictionary): return not m.name.begins_with("@")
	)


## ベースプロパティ一覧の準備
## @param interface_type インタフェーススクリプト型
## @return 準備済みプロパティ配列
static func prepare_base_property(interface_type: Script) -> Array:
	return _prepare_base(
		_base_property,
		interface_type,
		func(obj: Object): return obj.get_property_list(),
		func(p: Dictionary): return not p.name.ends_with(".gd")
	)


## ベースシグナル一覧の準備
## @param interface_type インタフェーススクリプト型
## @return 準備済みシグナル配列
static func prepare_base_signal(interface_type: Script) -> Array:
	return _prepare_base(
		_base_signal, interface_type, func(obj: Object): return obj.get_signal_list()
	)
