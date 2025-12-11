class_name Interface
extends Object

# 使い方の概要
# [インタフェース実装クラス]
# IMPL_LIST_NAMEに対応するimplements_listメソッドの定義
#	static func implements_list() -> Array[Script]
#		実装済みインタフェースをScript配列で返却
# 実装の委譲オブジェクト定義(optional)
#	func get_implementer(t_if: Script) -> Object
#		return self

# [インタフェース]
# InterfaceBaseの継承
# 必要なプロパティとメソッドの宣言
# メソッド引数と戻り値に対する_implアダプタの用意
# プロパティはsetterとgetterで_implへの委譲

const VALIDATOR = preload("uid://b4t2yue08ojax")
const IMPL_LIST_NAME = &"implements_list"
const CHECK_RESULT = preload("uid://ck862o06krlja")
const GET_IMPLEMENTER_NAME = &"get_implementer"


## @brief 実装委譲先のオブジェクトを取得する関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @return 実装委譲先オブジェクト
static func _get_implementer(obj: Object, t_if: Script) -> Object:
	assert(obj != null, "_get_implementer: 'obj' is null — pass a valid Object")
	assert(t_if != null, "_get_implementer: 't_if' is null — pass a valid Script")
	if not obj.has_method(GET_IMPLEMENTER_NAME):
		return obj
	# 指定インタフェースに対する実装オブジェクトの取得
	var implementer = obj.get_implementer(t_if)
	if implementer == obj or implementer is not Object:
		return obj
	# 連鎖的な委譲の解決
	return _get_implementer(implementer, t_if)


## @brief 指定されたオブジェクトが与えられたインターフェースを実装しているか判定する関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @param detailed 詳細判定を行うかどうかのフラグ
## @return 実装判定結果
static func implemented(obj: Object, t_if: Script, detailed: bool = false) -> bool:
	assert(obj != null, "implemented: 'obj' is null — pass a valid Object")
	assert(t_if != null, "implemented: 't_if' is null — pass a valid Script")
	obj = _get_implementer(obj, t_if)
	if not obj.has_method(IMPL_LIST_NAME):
		return false
	var impls = obj.call(IMPL_LIST_NAME)
	assert(
		impls is Array[Script],
		"The property '%s' must be an Array[Script], but got %s" % [IMPL_LIST_NAME, typeof(impls)]
	)
	if t_if not in impls:
		return false
	if not detailed:
		return true

	# 詳細判定
	var res := CHECK_RESULT.new()
	VALIDATOR.validate(res, obj.get_script(), t_if)
	return not res.has_error()


## @brief 指定されたオブジェクトをインターフェースとしてラップする関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @return インターフェースラッパーオブジェクト
static func as_interface(obj: Object, t_if: Script) -> InterfaceBase:
	assert(obj != null, "as_interface: 'obj' is null — pass a valid Object")
	assert(t_if != null, "as_interface: 't_if' is null — pass a valid Script")

	obj = _get_implementer(obj, t_if)
	if implemented(obj, t_if):
		var ret = t_if.new()
		assert(ret is InterfaceBase, "as_interface: interface instance must extend InterfaceBase")
		ret._impl = obj
		return ret
	return null


## @brief インターフェースを介して処理を実行する関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @param proc 実行するCallable
## @param warn_if_invalid インタフェース未実装時に警告を出すかどうか
## @return なし
static func proc_interface(
	obj: Object, t_if: Script, proc: Callable, warn_if_invalid: bool = false
) -> void:
	assert(obj != null, "proc_interface: 'obj' is null — pass a valid Object")
	assert(t_if != null, "proc_interface: 't_if' is null — pass a valid Script")
	var ifc = as_interface(obj, t_if)
	if ifc != null:
		proc.call(ifc)
	else:
		if warn_if_invalid:
			var if_name := t_if.resource_path if t_if.resource_path != "" else str(t_if)
			push_warning(
				(
					"proc_interface: target does not implement interface, skipping call: object=%s, interface=%s"
					% [str(obj), if_name]
				)
			)
