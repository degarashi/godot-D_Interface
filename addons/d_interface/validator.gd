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
