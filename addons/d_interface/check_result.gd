## チェック結果を保持するクラス
##
## チェック済み状態の管理とエラー情報の蓄積
## 単一または複数のエラー追加と有無判定の提供
## 内部処理による一貫したチェック状態更新とエラー管理
extends RefCounted

# ------------- [Constants] -------------
const ERROR = preload("uid://c4n13cyd88clu")

# ------------- [Public Variable] -------------
var is_checked: bool = false
## 期待される型: Dictionary[Script, Array[ERROR.Error]]
var errors: Dictionary[Script, Array] = {}


# ------------- [Private Method] -------------
## 内部処理: チェック済み設定とエラー追加
func _mark_checked_with_error(ifc: Script, e: Array[ERROR.Error]) -> void:
	set_checked()
	if ifc not in errors:
		errors[ifc] = []
	errors[ifc].append_array(e)


# ------------- [Public Method] -------------
func set_checked() -> void:
	is_checked = true


## エラーが存在するか判定
func has_error() -> bool:
	return not errors.is_empty()


## 単一エラーを追加
func add_error(ifc: Script, e: ERROR.Error) -> void:
	_mark_checked_with_error(ifc, [e])


## 複数エラーを追加
func add_errors(ifc: Script, e: Array[ERROR.Error]) -> void:
	if not e.is_empty():
		_mark_checked_with_error(ifc, e)
