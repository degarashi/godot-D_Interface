extends Object

# ------------- [Constants] -------------
const CHECK_RESULT = preload("uid://ck862o06krlja")
const C = preload("uid://beur775onkfdv")
const CACHE = preload("uid://bgl5faa3wfm4d")
const ERROR = preload("uid://c4n13cyd88clu")


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

	# 型チェック：期待側が Variant(0) でなければ厳密に比較
	if expected_prop.type != TYPE_NIL and expected_prop.type != actual_prop.type:
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

			# 引数名の比較 (オプション)
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

			# 引数型の比較: 期待側が Variant(TYPE_NIL) でない場合のみ厳密にチェック
			if arg_expected.type != TYPE_NIL and arg_expected.type != arg_actual.type:
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

	# 戻り値の比較
	var expected_ret = expected_method.return
	var actual_ret = actual_method.return

	var is_ok := false
	if expected_ret.type == actual_ret.type:
		if expected_ret.type == TYPE_OBJECT:
			var e_cls: StringName = expected_ret.get("class_name", &"")
			var a_cls: StringName = actual_ret.get("class_name", &"")
			is_ok = (
				e_cls == &""
				or a_cls == e_cls
				or ClassDB.is_parent_class(a_cls, e_cls)
				or _is_custom_class_parent(a_cls, e_cls)
			)
		else:
			is_ok = true
	elif expected_ret.type == TYPE_NIL:
		is_ok = true

	# 判定結果をエラー配列に反映させる
	if not is_ok:
		err.append(
			ERROR.ErrorMethodReturnTypeDiffer.new(
				expected_method.name, expected_ret.type, actual_ret.type
			)
		)

	return err
	return err


# ------------- [Public Method] -------------
## オブジェクトのメソッド・シグナル・プロパティ総合検証
## @param res 検証結果を格納するオブジェクト
## @param target_obj 検証対象のインスタンス
## @param interface_type インタフェーススクリプト型
static func validate(res: CHECK_RESULT, target_obj: Object, interface_type: Script) -> void:
	# 実装を保持している「真の対象」を取得する
	var implementer: Object = target_obj
	if target_obj.has_method("get_implementer"):
		var delegated = target_obj.get_implementer(interface_type)
		if delegated:
			implementer = delegated

	# スクリプトを持たない組み込みクラス（CharacterBody2D等）への対応のため
	# スクリプトResourceではなくObjectインスタンスを直接渡して検証を行う
	validate_method(res, implementer, interface_type)
	validate_property(res, implementer, interface_type)
	validate_signal(res, implementer, interface_type)


## オブジェクトのシグナル定義がインタフェースと一致するか検証
## @param res 検証結果を格納するオブジェクト
## @param target 検証対象のインスタンス
## @param interface_type 期待する構造を定義したインタフェーススクリプト
static func validate_signal(res: CHECK_RESULT, target: Object, interface_type: Script) -> void:
	# インタフェース型に基づく期待シグナル一覧を走査
	for expected_signal in CACHE.prepare_cache(interface_type).signal_a:
		var actual_signal = C.get_signal(target, expected_signal.name)
		if actual_signal == null:
			res.add_error(interface_type, ERROR.ErrorSignalNotFound.new(expected_signal.name))
			continue

		# 引数の数
		var expected_arg_count: int = expected_signal.args.size()
		var actual_arg_count: int = actual_signal.args.size()
		if expected_arg_count != actual_arg_count:
			res.add_error(
				interface_type,
				ERROR.ErrorDifferSignalArgumentNum.new(expected_arg_count, actual_arg_count)
			)
		else:
			for i in range(expected_arg_count):
				var arg_expected = expected_signal.args[i]
				var arg_actual = actual_signal.args[i]
				if arg_expected.name != arg_actual.name:
					res.add_error(
						interface_type,
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
					res.add_error(
						interface_type,
						ERROR.ErrorInvalidSignalArgumentType.new(arg_expected.type, arg_actual.type)
					)

		# 戻り値型（シグナルの場合は通常 void だが、辞書にあれば比較）
		if "return" in expected_signal and "return" in actual_signal:
			var expected_ret = expected_signal.return
			var actual_ret = actual_signal.return
			if expected_ret.type != actual_ret.type:
				res.add_error(
					interface_type,
					ERROR.ErrorSignalReturnTypeDiffer.new(
						expected_signal.name, expected_ret.type, actual_ret.type
					)
				)


## オブジェクトのプロパティ定義がインタフェースと一致するか検証
static func validate_property(res: CHECK_RESULT, target: Object, interface_type: Script) -> void:
	# インタフェース型に基づく期待プロパティ一覧を走査
	for expected_prop in CACHE.prepare_cache(interface_type).property_a:
		var actual_prop = C.get_property(target, expected_prop.name)
		if actual_prop == null:
			res.add_error(interface_type, ERROR.ErrorPropertyNotFound.new(expected_prop.name))
			continue

		res.add_errors(interface_type, _validate_prop(expected_prop, actual_prop, true))


## オブジェクトのメソッド定義がインタフェースと一致するか検証
static func validate_method(res: CHECK_RESULT, target: Object, interface_type: Script) -> void:
	# インタフェース型に基づく期待メソッド一覧を走査
	for expected_method in CACHE.prepare_cache(interface_type).method_a:
		var actual_method = C.get_method(target, expected_method.name)
		if actual_method == null:
			res.add_error(interface_type, ERROR.ErrorMethodNotFound.new(expected_method.name))
			continue

		res.add_errors(interface_type, _validate_method(expected_method, actual_method, true, true))


## @brief 型の互換性を検証する (共変性のサポート)
## @param expected_type 期待される Variant.Type
## @param actual_type 実装されている Variant.Type
## @param expected_class 期待されるクラス名 (StringName)
## @param actual_class 実装されているクラス名 (StringName)
static func _is_type_compatible(
	expected_type: int,
	actual_type: int,
	expected_class: StringName = &"",
	actual_class: StringName = &""
) -> bool:
	# 1. 期待側が Variant(0) なら無条件でパス
	if expected_type == TYPE_NIL:
		return true

	# 2. 基本型の一致チェック
	if expected_type != actual_type:
		return false

	# 3. Object型の場合、クラスの継承関係を深掘りする
	if expected_type == TYPE_OBJECT:
		# 両方空なら、少なくとも Object 同士なのでパス
		if expected_class == &"":
			return true
		# 実装側が空なのに期待側がクラス指定ありならエラー
		if actual_class == &"":
			return false
		# 同一クラスならパス
		if expected_class == actual_class:
			return true

		# 継承関係のチェック (実体が期待のサブクラスか)
		# ClassDB はエンジン標準クラス (Node, Resource等) を判定
		if ClassDB.is_parent_class(actual_class, expected_class):
			return true

		# カスタムクラス (class_name) の継承関係を判定
		if _is_custom_class_parent(actual_class, expected_class):
			return true

		return false

	return true


## @brief カスタムクラス (class_name) の継承関係を再帰的にチェック
static func _is_custom_class_parent(actual: StringName, expected: StringName) -> bool:
	if actual == &"" or expected == &"":
		return false

	var current := actual
	var global_classes := ProjectSettings.get_global_class_list()

	# 無限ループ防止用のカウンター（念のため）
	var safety_limit := 100

	while current != &"" and safety_limit > 0:
		safety_limit -= 1
		var found := false

		for c in global_classes:
			if c["class"] == current:
				var base: String = c["base"]
				if base == expected:
					return true
				current = base
				found = true
				break

		# global_class_list に見つからない、またはベースがなくなった
		if not found:
			break

	return false
