class_name Interface
extends Object

# 使い方の概要
# [インタフェース実装クラス]
# IMPL_LIST_NAMEに対応するimplements_listメソッドの定義
#	static func implements_list() -> Array[GDScript]
#		実装済みインタフェースをGDScript配列で返却
# 実装の委譲オブジェクト定義(optional)
#	func get_implementer(t_if: GDScript) -> Object
#		return self

# [インタフェース]
# InterfaceBaseの継承
# 必要なプロパティとメソッドの宣言
# メソッド引数と戻り値に対する_implアダプタの用意
# プロパティはsetterとgetterで_implへの委譲

const VALIDATOR = preload("uid://b4t2yue08ojax")
const IMPL_LIST_NAME = &"implements_list"
const CHECK_RESULT = preload("uid://ck862o06krlja")


## @brief 実装委譲先のオブジェクトを取得する関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @return 実装委譲先オブジェクト
static func _get_implementer(obj: Object, t_if: GDScript) -> Object:
	if not obj.has_method("get_implementer"):
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
static func implemented(obj: Object, t_if: GDScript, detailed: bool = false) -> bool:
	obj = _get_implementer(obj, t_if)
	if not obj.has_method(IMPL_LIST_NAME):
		return false
	var impls = obj.call(IMPL_LIST_NAME)
	assert(
		impls is Array[GDScript],
		"The property '%s' must be an Array[GDScript], but got %s" % [IMPL_LIST_NAME, typeof(impls)]
	)
	if t_if not in impls:
		return false
	if not detailed:
		return true

	# 詳細判定
	var res := CHECK_RESULT.new()
	VALIDATOR.validate(res, obj, t_if)
	return res.has_error()


## @brief 指定されたオブジェクトをインターフェースとしてラップする関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @return インターフェースラッパーオブジェクト
static func as_interface(obj: Object, t_if: GDScript) -> InterfaceBase:
	obj = _get_implementer(obj, t_if)
	if implemented(obj, t_if):
		var ret = t_if.new()
		ret._impl = obj
		return ret
	return null
