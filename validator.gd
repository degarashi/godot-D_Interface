extends Object

const CHECK_RESULT = preload("uid://ck862o06krlja")
const ERROR = preload("uid://c4n13cyd88clu")


# ------------- [Defines] -------------
class ValidateResult:
	var ok: bool
	var error: PackedStringArray


# ------------- [Private Variable] -------------
@warning_ignore("unused_private_class_variable")
static var _base_interface_instance: InterfaceBase

# Resourceに元々存在しているメソッドなどを省いたもの
static var _base_method: Dictionary[GDScript, Array] = {}
static var _base_property: Dictionary[GDScript, Array] = {}
static var _base_signal: Dictionary[GDScript, Array] = {}


# ------------- [Private Static Method] -------------
## 期待するプロパティと実プロパティの比較検証
## @param expected_prop 期待するプロパティ
## @param actual_prop 実プロパティ
## @param skip_name_check 名前一致検証の省略可否
## @return 差分エラー一覧
static func _validate_prop(
	expected_prop: Variant, actual_prop: Variant, skip_name_check: bool
) -> Array[ERROR.Error]:
	var ret: Array[ERROR.Error] = []
	# 名前チェック
	if not skip_name_check and expected_prop.name != actual_prop.name:
		ret.append(ERROR.ErrorPropertyNameDiffer.new(expected_prop.name, actual_prop.name))

	# 型チェック
	if expected_prop.type != actual_prop.type:
		ret.append(
			ERROR.ErrorPropertyTypeDiffer.new(
				expected_prop.name, expected_prop.type, actual_prop.type
			)
		)
	return ret


## メソッド定義の詳細比較検証
## @param expected_method 期待するメソッド定義
## @param actual_method 実メソッド定義
## @param skip_default_arg デフォルト引数チェックをスキップするフラグ
## @return 差分エラー一覧
static func _validate_method(
	expected_method: Variant, actual_method: Variant, skip_arg_name: bool, skip_default_arg: bool
) -> Array[ERROR.Error]:
	var err: Array[ERROR.Error] = []
	# 引数の数
	var expected_arg_count: int = expected_method.args.size()
	var actual_arg_count: int = actual_method.args.size()
	if expected_arg_count != actual_arg_count:
		err.append(ERROR.ErrorDifferMethodArgumentNum.new(expected_arg_count, actual_arg_count))
	else:
		# 各引数のプロパティ（名前、型）を比較
		for i in range(expected_arg_count):
			var arg_expected = expected_method.args[i]
			var arg_actual = actual_method.args[i]
			# 名前差分（参考情報としてメッセージ化）
			if not skip_arg_name:
				if arg_expected.name != arg_actual.name:
					err.append(
						ERROR.ErrorMethodArgPropertyDiffer.new(
							expected_method.name,
							i,
							(
								"name differs: expected='%s', actual='%s'"
								% [arg_expected.name, arg_actual.name]
							)
						)
					)
			# 型差分は型不一致エラー
			if arg_expected.type != arg_actual.type:
				err.append(
					ERROR.ErrorInvalidMethodArgumentType.new(arg_expected.type, arg_actual.type)
				)

	if not skip_default_arg:
		# デフォルト引数の数（もし指定されていれば）
		var expected_default_count: int = expected_method.default_args.size()
		var actual_default_count: int = actual_method.default_args.size()
		if expected_default_count != actual_default_count:
			err.append(
				ERROR.ErrorMethodDefaultArgCountMismatch.new(
					expected_method.name, expected_default_count, actual_default_count
				)
			)
		else:
			# それぞれのデフォルト引数の値を比較し、違っていればエラーを追加
			for i in range(expected_default_count):
				var expected_val = expected_method.default_args[i]
				var actual_val = actual_method.default_args[i]
				if expected_val != actual_val:
					err.append(
						ERROR.ErrorMethodDefaultArgValueMismatch.new(
							expected_method.name, i, expected_val, actual_val
						)
					)

	# 戻り値の型を Property 経由で比較（名前は比較しない）
	var expected_ret = expected_method.return
	var actual_ret = actual_method.return
	if expected_ret.type != actual_ret.type:
		err.append(
			ERROR.ErrorMethodReturnTypeDiffer.new(
				expected_method.name, expected_ret.type, actual_ret.type
			)
		)
	return err


## ベース情報の準備とキャッシュ構築
## @param cache_dic タイプ別キャッシュ辞書
## @param interface_type インタフェーススクリプト型
## @param getter 対象情報取得コールバック
## @param checker フィルタリング用チェックコールバック
## @return キャッシュ配列
static func _prepare_base(
	cache_dic: Dictionary[GDScript, Array],
	interface_type: GDScript,
	getter_func: Callable,
	filter_func: Callable = func(_a: Dictionary): return true
) -> Array:
	if interface_type not in cache_dic:
		var tmp_obj: Object = interface_type.new()
		assert(tmp_obj != null, "interface_type.new() returned null")
		var ar := _array_subtract(
			# 対象ObjectからGetした物
			getter_func.call(tmp_obj),
			# InterfaceBaseからGetした物
			getter_func.call(_base_interface_instance)
		)
		# フィルタリングした結果を残す
		cache_dic[interface_type] = ar.filter(filter_func)
	return cache_dic[interface_type]


## Objectに元々備わっている以外のメソッド一覧を準備
## @param interface_type インタフェーススクリプト型
## @return 準備済みメソッド配列
static func _prepare_base_method(interface_type: GDScript) -> Array:
	return _prepare_base(
		_base_method,
		interface_type,
		func(obj: Object): return obj.get_method_list(),
		func(m: Dictionary): return not m.name.begins_with("@")
	)


## ベースプロパティ一覧の準備
## @param interface_type インタフェーススクリプト型
## @return 準備済みプロパティ配列
static func _prepare_base_property(interface_type: GDScript) -> Array:
	return _prepare_base(
		_base_property,
		interface_type,
		func(obj: Object): return obj.get_property_list(),
		func(p: Dictionary): return not p.name.ends_with(".gd")
	)


## ベースシグナル一覧の準備
## @param interface_type インタフェーススクリプト型
## @return 準備済みシグナル配列
static func _prepare_base_signal(interface_type: GDScript) -> Array:
	return _prepare_base(
		_base_signal, interface_type, func(obj: Object): return obj.get_signal_list()
	)


# ------------- [Public Method] -------------
## オブジェクトのメソッド・シグナル・プロパティ総合検証
## @param target_obj 検証対象オブジェクト
## @param interface_type インタフェーススクリプト型
## @return 検証結果オブジェクト
static func validate(res: CHECK_RESULT, target_obj: Object, interface_type: GDScript) -> void:
	if not _base_interface_instance:
		_base_interface_instance = InterfaceBase.new()

	res.add_errors(validate_method(target_obj, interface_type))
	res.add_errors(validate_signal(target_obj, interface_type))
	res.add_errors(validate_property(target_obj, interface_type))


## 配列差分作成
## @param source_array 対象配列
## @param subtract_array 差し引き配列
## @return 差分要素配列
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


## シグナル定義の検証
## @param target_obj 検証対象オブジェクト
## @param interface_type インタフェーススクリプト型
## @return エラー一覧
static func validate_signal(target_obj: Object, interface_type: GDScript) -> Array[ERROR.Error]:
	# オブジェクトのシグナル一覧を辞書化
	# キーにシグナル名、値にシグナル情報を保持(検索用)
	var obj_signal_map: Dictionary[String, Dictionary] = {}
	for signal_info in target_obj.get_signal_list():
		obj_signal_map[signal_info.name] = signal_info

	var err: Array[ERROR.Error] = []
	# インタフェース型に基づく期待シグナル一覧を走査
	for expected_signal in _prepare_base_signal(interface_type):
		if expected_signal.name not in obj_signal_map:
			err.append(ERROR.ErrorSignalNotFound.new(expected_signal.name))
			continue

		var actual_signal := obj_signal_map[expected_signal.name]
		# 引数数
		var expected_arg_count: int = expected_signal.args.size()
		var actual_arg_count: int = actual_signal.args.size()
		if expected_arg_count != actual_arg_count:
			err.append(ERROR.ErrorDifferSignalArgumentNum.new(expected_arg_count, actual_arg_count))
		else:
			for i in range(expected_arg_count):
				var arg_expected = expected_signal.args[i]
				var arg_actual = actual_signal.args[i]
				if arg_expected.name != arg_actual.name:
					err.append(
						ERROR.ErrorSignalArgPropertyDiffer.new(
							expected_signal.name,
							i,
							(
								"name differs: expected='%s', actual='%s'"
								% [arg_expected.name, arg_actual.name]
							)
						)
					)
				if arg_expected.type != arg_actual.type:
					err.append(
						ERROR.ErrorInvalidSignalArgumentType.new(arg_expected.type, arg_actual.type)
					)

		# 戻り値型（シグナルの場合は通常 void だが、辞書にあれば比較）
		if "return" in expected_signal and "return" in actual_signal:
			var expected_ret = expected_signal.return
			var actual_ret = actual_signal.return
			if expected_ret.type != actual_ret.type:
				err.append(
					ERROR.ErrorSignalReturnTypeDiffer.new(
						expected_signal.name, expected_ret.type, actual_ret.type
					)
				)
	return err


## プロパティ定義の検証
## @param target_obj 検証対象オブジェクト
## @param interface_type インタフェーススクリプト型
## @return エラー一覧
static func validate_property(target_obj: Object, interface_type: GDScript) -> Array[ERROR.Error]:
	# オブジェクトのプロパティ一覧を辞書化
	# キーにプロパティ名、値にプロパティ情報を保持(検索用)
	var obj_property_map: Dictionary[String, Dictionary] = {}
	for prop_info in target_obj.get_property_list():
		obj_property_map[prop_info.name] = prop_info

	var err: Array[ERROR.Error] = []
	# インタフェース型に基づく期待プロパティ一覧を走査
	for expected_prop in _prepare_base_property(interface_type):
		if expected_prop.name not in obj_property_map:
			err.append(ERROR.ErrorPropertyNotFound.new(expected_prop.name))
			continue

		var actual_prop := obj_property_map[expected_prop.name]
		err.append_array(_validate_prop(expected_prop, actual_prop, true))

	return err


## メソッド定義の検証
## @param target_obj 検証対象オブジェクト
## @param interface_type インタフェーススクリプト型
## @return エラー一覧
static func validate_method(target_obj: Object, interface_type: GDScript) -> Array[ERROR.Error]:
	# オブジェクトのメソッド一覧を辞書化
	# キーにメソッド名、値にメソッド情報を保持(検索用)
	var obj_method_map: Dictionary[String, Dictionary] = {}
	for method_info in target_obj.get_method_list():
		obj_method_map[method_info.name] = method_info

	var err: Array[ERROR.Error] = []
	# インタフェース型に基づく期待メソッド一覧を走査
	for expected_method in _prepare_base_method(interface_type):
		# 期待メソッドが対象オブジェクトに存在しない場合
		if expected_method.name not in obj_method_map:
			err.append(ERROR.ErrorMethodNotFound.new(expected_method.name))
			continue

		# 実際のメソッド情報を取得
		var actual_method := obj_method_map[expected_method.name]
		# 詳細比較検証を実施し、差分エラーを追加
		err.append_array(_validate_method(expected_method, actual_method, true, true))
	return err
