## チェック結果を保持するクラス
##
## チェック済み状態の管理とエラー情報の蓄積
## 単一または複数のエラー追加と有無判定の提供
## 内部処理による一貫したチェック状態更新とエラー管理
extends RefCounted

const ERROR = preload("uid://c4n13cyd88clu")

var is_checked: bool
var errors: Array[ERROR.Error]


func _init() -> void:
	is_checked = false
	errors.clear()


## チェック済み状態に設定
func set_checked() -> void:
	is_checked = true


## エラーが存在するか判定
func has_error() -> bool:
	return not errors.is_empty()


## 単一エラーを追加
func add_error(e: ERROR.Error) -> void:
	_mark_checked_with_error([e])


## 複数エラーを追加
func add_errors(e: Array[ERROR.Error]) -> void:
	if not e.is_empty():
		_mark_checked_with_error(e)


## 内部処理: チェック済み設定とエラー追加
func _mark_checked_with_error(e: Array[ERROR.Error]) -> void:
	set_checked()
	errors.append_array(e)
