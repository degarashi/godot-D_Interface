@tool
extends EditorPlugin

# ------------- [Constants] -------------
const MENU_TEXT = "Check Interface Defines"
const VALIDATOR = preload("uid://b4t2yue08ojax")
# ショートカットアクション名
const CHECK_ALL_ACTION = "check_interface_all"
const CHECK_RESULT = preload("uid://ck862o06krlja")
const ERROR = preload("uid://c4n13cyd88clu")
const C = preload("uid://beur775onkfdv")
const EDITOR_SETTING_PATH = "d_interface/check/auto_check_on_reload"


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
	_prepare_editor_settings()

	add_tool_menu_item(MENU_TEXT, Callable(self, "_check_interface_define_all"))
	_register_shortcut()

	# ファイルシステムの変更（保存や削除、移動）を監視
	var efs := get_editor_interface().get_resource_filesystem()
	efs.resources_reload.connect(_on_resources_reload)


## @brief エディタ設定の準備
func _prepare_editor_settings() -> void:
	var settings := get_editor_interface().get_editor_settings()

	if not settings.has_setting(EDITOR_SETTING_PATH):
		settings.set_setting(EDITOR_SETTING_PATH, true)

	# 設定画面で型や初期値を正しく認識させるためのヒント
	settings.add_property_info(
		{
			"name": EDITOR_SETTING_PATH,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Enable automatic interface validation when resources are reloaded."
		}
	)
	settings.set_initial_value(EDITOR_SETTING_PATH, true, false)


func _on_resources_reload(resources: PackedStringArray) -> void:
	var settings := get_editor_interface().get_editor_settings()
	if not settings.get_setting(EDITOR_SETTING_PATH):
		return

	# リロードされたリソースの中にスクリプトがあれば検証
	for path in resources:
		if not path.ends_with(".gd"):
			continue

		# addonsフォルダ内は無視
		if path.begins_with("res://addons/"):
			continue

		var res := load(path)
		if not res is Script:
			continue

		var scr: Script = res

		# 検品実行
		var chk_res := _check_interface_define(scr)

		if chk_res.is_checked:
			if chk_res.has_error():
				# エラーがある場合は目立つように
				printerr("[InterfaceCheck] ❌ Error in: ", path.get_file())
				for ifc in chk_res.errors:
					for e in chk_res.get_errors(ifc):
						push_error(e.as_string())
			else:
				# 成功時は控えめに通知
				print("[InterfaceCheck] ✅ OK: ", path.get_file())


## @brief ツリー退出処理
## @details エディタツリーから出た際にメニュー項目を削除する処理
func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)
	_unregister_shortcut()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(CHECK_ALL_ACTION):
		_check_interface_define_all()
		get_tree().root.set_input_as_handled()


# ------------- [Private Method] -------------
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
		var total_err_count: int = 0
		var scripts := _list_gd_files_recursive(dir, ["addons"])

		for path in scripts:
			var res := load(path)
			if res is Script:
				var scr: Script = res
				var chk_res := _check_interface_define(scr)
				if chk_res.is_checked:
					print("{0}".format([path]))
					if chk_res.has_error():
						total_err_count += 1
						for ifc in chk_res.errors:
							var err_list := chk_res.get_errors(ifc)
							for e in err_list:
								push_error(e.as_string())
					else:
						print("\tNo Error")

		if total_err_count > 0:
			print("{0} script(s) with errors found.".format([total_err_count]))
		else:
			print("----------------- All OK -----------------")


## @brief インターフェース定義検証処理
## @param scr 検証対象のスクリプト
## @return 検証結果オブジェクト
static func _check_interface_define(scr: Script) -> CHECK_RESULT:
	print("Checking Script: {0}".format([scr.resource_path.get_file()]))
	var res := CHECK_RESULT.new()

	if scr == null:
		print("Error: Script is null.")
		return res

	# エンジン由来クラス継承したスクリプトなどは can_instantiate()がfalse になる場合があるため
	# 直接new()が可能か、あるいは特定のベースクラスを持っているかを確認する
	var can_create := scr.can_instantiate()

	# NodeやResourceを継承した通常のスクリプトであれば、
	# class_nameの有無に関わらず本来は new() 可能。
	# 失敗する場合は抽象クラスか、ツールモードでの初期化エラー。
	if not can_create:
		# 補足: InterfaceBaseを継承しているリソース型スクリプトの場合のフォールバック
		if not scr.get_instance_base_type() == "":
			can_create = true

	if not can_create:
		print("Skip: Script cannot be instantiated. (Path: %s)" % scr.resource_path)
		return res

	if C.get_method(scr, Interface.IMPL_LIST_NAME) == null:
		print("Skip: Interface implementation list method not found.")
		return res

	var init_info := C.get_method(scr, "_init")
	if init_info:
		var required_args: int = init_info.args.size() - init_info.default_args.size()
		if required_args > 0:
			print("Skip: _init requires %d arguments." % required_args)
			return res

	# 実際に生成を試みる
	var obj: Object = scr.new()
	if not obj:
		print("Error: Failed to create instance via new().")
		return res

	res.set_checked()

	var if_a: Array = scr.call(Interface.IMPL_LIST_NAME)
	for interface_scr in if_a:
		if interface_scr is Script:
			# グローバル名がない場合はリソースパスを表示
			var if_name: String = interface_scr.get_global_name()
			if if_name == "":
				if_name = interface_scr.resource_path.get_file()

			print("Checking [{0}]".format([if_name]))
			VALIDATOR.validate(res, obj, interface_scr)

	# インスタンスの解放
	if not obj is RefCounted:
		obj.free()

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
