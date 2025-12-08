@tool
extends EditorPlugin

const MENU_TEXT = "Check Interface Defines"
const VALIDATOR = preload("uid://b4t2yue08ojax")
# ショートカットアクション名
const CHECK_ALL_ACTION = "check_interface_all"
const CHECK_RESULT = preload("uid://ck862o06krlja")
const ERROR = preload("uid://c4n13cyd88clu")


## @brief プラグイン有効化処理
## @details プラグインが有効化された際に呼び出される処理
func _enable_plugin() -> void:
	pass


## @brief プラグイン無効化処理
## @details プラグインが無効化された際に呼び出される処理
func _disable_plugin() -> void:
	pass


## @brief ツリー進入処理
## @details エディタツリーに入った際にメニュー項目を追加する処理
func _enter_tree() -> void:
	add_tool_menu_item(MENU_TEXT, Callable(self, "_check_interface_define_all"))
	_register_shortcut()


## @brief ツリー退出処理
## @details エディタツリーから出た際にメニュー項目を削除する処理
func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)
	_unregister_shortcut()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(CHECK_ALL_ACTION):
		_check_interface_define_all()
		get_tree().root.set_input_as_handled()


func _register_shortcut() -> void:
	# 入力マップにアクションを追加（プロジェクト設定ではなく一時的に利用）
	if not InputMap.has_action(CHECK_ALL_ACTION):
		InputMap.add_action(CHECK_ALL_ACTION)

	var ev := InputEventKey.new()
	ev.keycode = KEY_L
	ev.shift_pressed = true
	ev.ctrl_pressed = true

	InputMap.action_erase_events(CHECK_ALL_ACTION)
	InputMap.action_add_event(CHECK_ALL_ACTION, ev)
	# プロジェクト設定への保存は行わない


func _unregister_shortcut() -> void:
	if InputMap.has_action(CHECK_ALL_ACTION):
		InputMap.erase_action(CHECK_ALL_ACTION)


func _check_interface_define_all() -> void:
	print("----------------- begin interface defines check -----------------")
	_check_interface_define_at("res://")


func _check_interface_define_at(dir_str: String) -> void:
	var dir := DirAccess.open(dir_str)
	if dir:
		var err_count := 0
		var scripts := _list_gd_files_recursive(dir, ["addons"])
		for path in scripts:
			var res := load(path)
			if res is GDScript:
				var scr: GDScript = res
				var chk_res := _check_interface_define(scr.new())
				if chk_res.is_checked:
					print("Interface Check... {0}".format([path]))
					if chk_res.has_error():
						err_count += 1
						for e in chk_res.errors:
							push_error(e.as_string())
		if err_count > 0:
			print("{0} error(s) found.".format([err_count]))
		else:
			print("OK")


## @brief インターフェース定義検証処理
## @param obj 検証対象オブジェクト
## @return エラーメッセージ配列(エラーが無ければ空配列)
## @details インターフェース定義が正しく実装されているかを検証する処理
static func _check_interface_define(obj: Object) -> CHECK_RESULT:
	var res := CHECK_RESULT.new()
	if not obj.has_method(Interface.IMPL_LIST_NAME):
		# Interfaceは何も実装していない
		return res

	res.set_checked()
	var if_a := obj.call(Interface.IMPL_LIST_NAME)
	for interface_gdscr in if_a:
		if not is_instance_of(interface_gdscr, GDScript):
			res.add_error(ERROR.InvalidInterface.new(interface_gdscr))
		VALIDATOR.validate(res, obj, interface_gdscr)
	return res


## @brief GDScriptファイル探索処理
## @param dir 探索対象ディレクトリ
## @param excluded_dirs 除外ディレクトリ配列
## @return 探索されたGDScriptファイルパス配列
## @details 指定ディレクトリ以下のGDScriptファイルを再帰的に探索する処理
static func _list_gd_files_recursive(dir: DirAccess, excluded_dirs: Array[String]) -> Array[String]:
	var ret: Array[String]
	var path := dir.get_current_dir()
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				# 除外ディレクトリをチェック
				if excluded_dirs.has(file_name):
					file_name = dir.get_next()
					continue
				var sub_path := path + "/" + file_name
				var sub_dir := DirAccess.open(sub_path)
				if sub_dir:
					# 再帰呼び出しの結果を蓄積する
					ret.append_array(_list_gd_files_recursive(sub_dir, excluded_dirs))
		else:
			if file_name.ends_with(".gd"):
				ret.append(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ret
