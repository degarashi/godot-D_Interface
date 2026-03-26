@tool
extends EditorPlugin

# ------------- [Constants] -------------
const MENU_TEXT = "Check Interface Defines"
const VALIDATOR = preload("uid://b4t2yue08ojax")
const CHECK_RESULT = preload("uid://ck862o06krlja")
const ERROR = preload("uid://c4n13cyd88clu")
const C = preload("uid://beur775onkfdv")
const GENERATOR = preload("uid://dknhe70ukestb")

# Settings Paths
const EDITOR_SETTING_PATH = "d_interface/check/auto_check_on_reload"
const AUTO_GENERATE_SETTING_PATH = "d_interface/check/auto_generate_bridge_on_save"
const AUTO_INJECT_SETTING_PATH = "d_interface/check/auto_inject_boilerplate_on_reload"

const BRIDGE_MENU_TEXT = "Create Bridge Script from Selected"

var ifc_importer: EditorImportPlugin = null


func _enter_tree() -> void:
	# 設定の準備
	_prepare_editor_settings()

	# インポーターの登録
	if ifc_importer == null:
		ifc_importer = preload("res://addons/d_interface/ifc_importer.gd").new()
		add_import_plugin(ifc_importer)

	# メニュー登録
	add_tool_menu_item(MENU_TEXT, Callable(self, "_check_interface_define_all"))
	add_tool_menu_item(BRIDGE_MENU_TEXT, Callable(self, "_create_bridge_from_selected"))

	# ファイルシステムの変更（保存や削除、移動）を監視
	var efs := get_editor_interface().get_resource_filesystem()
	efs.resources_reload.connect(_on_resources_reload)
	efs.resources_reimported.connect(_auto_generate)


func _exit_tree() -> void:
	# 終了時は確実に解除
	if ifc_importer != null:
		remove_import_plugin(ifc_importer)
		ifc_importer = null

	remove_tool_menu_item(MENU_TEXT)
	remove_tool_menu_item(BRIDGE_MENU_TEXT)

	# シグナルの接続解除
	var efs := get_editor_interface().get_resource_filesystem()
	if efs.resources_reload.is_connected(_on_resources_reload):
		efs.resources_reload.disconnect(_on_resources_reload)
	if efs.resources_reimported.is_connected(_auto_generate):
		efs.resources_reimported.disconnect(_auto_generate)


## @brief エディタ設定の準備
func _prepare_editor_settings() -> void:
	var settings := get_editor_interface().get_editor_settings()

	# 自動検証設定
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

	# 自動生成設定 (.ifc -> .gd)
	if not settings.has_setting(AUTO_GENERATE_SETTING_PATH):
		settings.set_setting(AUTO_GENERATE_SETTING_PATH, true)

	settings.add_property_info(
		{
			"name": AUTO_GENERATE_SETTING_PATH,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Automatically generate bridge .gd file when .ifc file is updated."
		}
	)

	# 自動注入設定 (implements boilerplate)
	if not settings.has_setting(AUTO_INJECT_SETTING_PATH):
		settings.set_setting(AUTO_INJECT_SETTING_PATH, true)
	settings.add_property_info(
		{
			"name": AUTO_INJECT_SETTING_PATH,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string":
			"Automatically inject interface boilerplate based on # implements marker."
		}
	)

	settings.set_initial_value(EDITOR_SETTING_PATH, true, false)
	settings.set_initial_value(AUTO_GENERATE_SETTING_PATH, true, false)
	settings.set_initial_value(AUTO_INJECT_SETTING_PATH, true, false)


# ------------- [Editor Handling] -------------
func _handles(object: Object) -> bool:
	return object is Resource and object.resource_path.ends_with(".ifc")


func _edit(object: Object) -> void:
	if not object is Resource:
		return

	var global_path: String = ProjectSettings.globalize_path(object.resource_path)
	if not global_path.ends_with(".ifc"):
		return

	var settings := get_editor_interface().get_editor_settings()
	var use_external: bool = (
		settings.get_setting("text_editor/external/use_external_editor")
		if settings.has_setting("text_editor/external/use_external_editor")
		else false
	)
	var exec_path: String = (
		settings.get_setting("text_editor/external/exec_path")
		if settings.has_setting("text_editor/external/exec_path")
		else ""
	)
	var exec_flags: String = (
		settings.get_setting("text_editor/external/exec_flags")
		if settings.has_setting("text_editor/external/exec_flags")
		else "{file}"
	)

	if use_external and not exec_path.is_empty():
		# プレースホルダ置換
		var command_line := (
			exec_flags.replace("{file}", global_path).replace("{line}", "1").replace("{col}", "1")
		)

		# 正規表現で「引用符内を保護しつつスペースで分割」する
		# パターン解説:
		#  "[^"]*"  -> 引用符で囲まれた文字列
		#  |        -> または
		#  \S+      -> 空白以外の連続した文字
		var regex = RegEx.new()
		regex.compile('"[^"]*"|\\S+')

		var args: PackedStringArray = []
		for result in regex.search_all(command_line):
			var arg = result.get_string()
			# 外部プロセスに渡す際、OS側で再度クォートされることがあるため、
			# 自前で付けた引用符は外しておく（必要に応じて）
			if arg.begins_with('"') and arg.ends_with('"'):
				arg = arg.substr(1, arg.length() - 2)
			args.append(arg)

		OS.create_process(exec_path, args)
		print("[Interface] Launched External: ", args)
	else:
		OS.shell_open(global_path)


func _auto_generate(resources: PackedStringArray) -> void:
	var settings := get_editor_interface().get_editor_settings()
	if not settings.get_setting(AUTO_GENERATE_SETTING_PATH):
		return

	var needs_rescan := false
	print("[Interface] Checking for .ifc changes in reimported resources...")
	for path in resources:
		if path.ends_with(".ifc"):
			print("[Interface] Detected change in: ", path)
			_generate_bridge_file(path)
			needs_rescan = true

	if needs_rescan:
		print("[Interface] Requesting filesystem scan after bridge generation.")
		get_editor_interface().get_resource_filesystem().scan()


func _inject_block(path: String) -> void:
	GENERATOR.update_implements_boilerplate(path)


## @brief リソースのリロード時に自動検証を実行
func _on_resources_reload(resources: PackedStringArray) -> void:
	# エディタ設定がオフならスキップ
	var settings := get_editor_interface().get_editor_settings()
	var auto_check: bool = settings.get_setting(EDITOR_SETTING_PATH)
	var auto_inject: bool = settings.get_setting(AUTO_INJECT_SETTING_PATH)

	# どちらの設定もオフなら何もしない
	if not auto_check and not auto_inject:
		return

	# リロードされたリソースの中にスクリプトがあれば処理
	for path in resources:
		if not path.ends_with(".gd") or path.begins_with("res://addons/"):
			continue

		# ボイラープレートの注入（検証前に行う）
		if auto_inject:
			_inject_block(path)

		# 検証処理
		if auto_check:
			var res := load(path)
			if not res is Script:
				continue

			var chk_res := _check_interface_define(res)
			if chk_res.is_checked:
				if chk_res.has_error():
					printerr("[InterfaceCheck] ❌ Error in: ", path.get_file())
					for ifc in chk_res.errors:
						var err_list := chk_res.get_errors(ifc)
						for e in err_list:
							push_error(e.as_string())
				else:
					print("[InterfaceCheck] ✅ OK: ", path.get_file())


## @brief 指定したパスの.ifcから.gdを生成する内部処理
func _generate_bridge_file(path: String) -> void:
	var file_read := FileAccess.open(path, FileAccess.READ)
	if not file_read:
		return

	var source_text := file_read.get_as_text()
	file_read.close()

	var base_name := path.get_file().get_basename()
	var generated_code := GENERATOR.generate_from_ifc(source_text, base_name)
	var new_path := path.get_base_dir() + "/" + base_name + ".gd"

	# 既存ファイルと内容が同じなら書き込まない（無限ループ防止）
	if FileAccess.file_exists(new_path):
		var existing_file := FileAccess.open(new_path, FileAccess.READ)
		if existing_file and existing_file.get_as_text() == generated_code:
			existing_file.close()
			return
		if existing_file:
			existing_file.close()

	var file_write := FileAccess.open(new_path, FileAccess.WRITE)
	if file_write:
		file_write.store_string(generated_code)
		file_write.close()
		print("[Interface] ⚡ Auto-generated bridge: ", new_path.get_file())


func _create_bridge_from_selected() -> void:
	var selected_paths := get_editor_interface().get_selected_paths()
	for path in selected_paths:
		if path.ends_with(".ifc"):
			_generate_bridge_file(path)

	get_editor_interface().get_resource_filesystem().scan()


## @brief エディタ上での入力を直接ハンドリングする
func _shortcut_input(event: InputEvent) -> void:
	# 例: Ctrl + Shift + I (InterfaceのI) で実行
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I and event.ctrl_pressed and event.shift_pressed:
			_check_interface_define_all()
			# 入力を消費したことを伝えて、他の処理に流さないようにする
			get_viewport().set_input_as_handled()


# ------------- [Private Method] -------------
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
