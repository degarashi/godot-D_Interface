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
const SET_IMPLEMENTER_NAME = &"set_implementer"

## インタフェース実装マーカー (# implements ...) の正規表現
const IMPLEMENTS_MARKER_RE = "(?m)^\\s*#+\\s*implements\\s+(?<names>[\\w\\s,]+?)(?=\\r?$|\\n|$)"

# --- 自動注入用ブロックマーカー ---
const TAG_LIST_START = "# --- INTERFACE LIST (AUTO-GENERATED) ---"
const TAG_LIST_END = "# --- END INTERFACE LIST ---"
const TAG_IMPL_START = "# --- INTERFACE IMPLEMENTER (AUTO-GENERATED) ---"
const TAG_IMPL_END = "# --- END INTERFACE IMPLEMENTER ---"
const TAG_VAR_START = "# --- INTERFACE VARIABLES (STUBS) ---"
const TAG_VAR_END = "# --- END INTERFACE VARIABLES ---"
const TAG_STUB_START = "# --- INTERFACE METHODS (STUBS) ---"
const TAG_STUB_END = "# --- END INTERFACE METHODS ---"


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
	if implementer == obj:
		return obj
	assert(
		is_instance_valid(implementer),
		"_get_implementer: 'implementer' is not a valid instance — check get_implementer implementation"
	)
	# 連鎖的な委譲の解決
	return _get_implementer(implementer, t_if)


static func is_base_of(base_scr: Script, scr: Script) -> bool:
	if scr == null:
		return false
	if scr == base_scr:
		return true
	return is_base_of(base_scr, scr.get_base_script())


## @brief 指定されたオブジェクトが与えられたインターフェースを実装しているか判定する関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @param detailed 詳細判定を行うかどうかのフラグ
## @return 実装判定結果
static func implemented(obj: Object, t_if: Script, detailed: bool = false) -> bool:
	if not obj:
		return false
	assert(t_if != null, "implemented: 't_if' is null — pass a valid Script")
	obj = _get_implementer(obj, t_if)
	# インタフェース実装リストを参照
	if not obj.has_method(IMPL_LIST_NAME):
		return false
	var impls = obj.call(IMPL_LIST_NAME)
	assert(
		impls is Array[Script],
		"The property '%s' must be an Array[Script], but got %s" % [IMPL_LIST_NAME, typeof(impls)]
	)
	var found: Script = null
	for impl in impls:
		if is_base_of(t_if, impl):
			found = impl
	if not found:
		return false
	if not detailed:
		return true

	# 詳細判定
	var res := CHECK_RESULT.new()
	VALIDATOR.validate(res, obj.get_script(), t_if)
	return not res.has_error()


static func is_ancestor_of(scr_base: Script, scr: Script) -> bool:
	if scr == null:
		return false
	if scr == scr_base:
		return true
	return is_ancestor_of(scr_base, scr.get_base_script())


## @brief 指定されたオブジェクトをインターフェースとしてラップする関数
## @param obj 対象オブジェクト
## @param t_if インタフェーススクリプト
## @param warn_on_failure キャスト失敗時に警告を表示するかどうか
## @return インターフェースラッパーオブジェクト
static func as_interface(
	source: Object, t_if: Script, warn_on_failure: bool = false
) -> InterfaceBase:
	assert(t_if != null, "as_interface: 't_if' is null — pass a valid Script")
	if not source:
		return null

	var valid_source: Object = null
	var failure_reason: String = ""

	if is_instance_of(source, InterfaceBase):
		# source is Interface
		var i_base: InterfaceBase = source
		if is_ancestor_of(t_if, source.get_script()):
			valid_source = i_base._impl
		else:
			# _implが既に解放されている可能性を考慮
			if is_instance_valid(i_base._impl):
				valid_source = as_interface(i_base._impl, t_if, false)  # ネスト時は内側で警告を出さない

			if not valid_source:
				failure_reason = (
					"Source is an interface wrapper, but its underlying object does not implement %s."
					% t_if.get_global_name()
				)
	else:
		# source is Object instance
		var implementer = _get_implementer(source, t_if)
		if implemented(implementer, t_if):
			valid_source = implementer
		else:
			failure_reason = (
				"Object does not implement interface %s (missing from implements_list)."
				% t_if.get_global_name()
			)

	if valid_source:
		# キャッシュの確認
		var cache_key := &"__ifc_cache_" + String.num_uint64(t_if.get_instance_id())
		if valid_source.has_meta(cache_key):
			var cached_wrapper = valid_source.get_meta(cache_key)
			if is_instance_valid(cached_wrapper):
				return cached_wrapper

		# 新規生成
		var ret: InterfaceBase = t_if.new()
		assert(ret is InterfaceBase, "as_interface: interface instance must extend InterfaceBase")
		ret.setup_interface(valid_source)

		# キャッシュへの保存
		valid_source.set_meta(cache_key, ret)

		return ret

	# キャスト失敗時の詳細警告
	if warn_on_failure:
		var if_name := t_if.get_global_name()
		if if_name == "":
			if_name = t_if.resource_path.get_file()

		var msg := "[Interface] Cast failed: %s -> %s\n" % [source.get_class(), if_name]
		msg += "Reason: %s\n" % failure_reason

		# 詳細な不一致項目を検証
		var res := CHECK_RESULT.new()
		VALIDATOR.validate(res, source, t_if)
		if res.has_error():
			msg += "Validation errors:\n"
			for err_ifc in res.errors:
				for e in res.get_errors(err_ifc):
					msg += "  - %s\n" % e.as_string()

		push_warning(msg)

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
	var ifc := as_interface(obj, t_if)
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
